# Luma – Technical Design Document (TD)

## 1. Overview

This document describes the technical design for **Luma**, a local-first voice-to-text-to-AI-rewrite assistant.

The system consists of:

- A **local backend** (Golang) exposing HTTP APIs.
- A **local database** (PostgreSQL).
- Integration with:
  - Speech-to-Text API (e.g. Whisper via OpenAI).
  - Multiple LLM providers (OpenAI, Gemini, etc.).
- Frontend clients (macOS/iOS/Windows) that:
  - Record audio and send it to the backend.
  - Optionally send **clipboard context** when the user toggles it on.
  - Display transcriptions, prompts, and rewritten results.

This TD focuses on the backend and shared data model.

---

## 2. High-Level Architecture

```text
+----------------------------+
|        Frontend Apps       |
|  (macOS / iOS / Windows)   |
+-------------+--------------+
              |
              | HTTP (JSON + multipart/form-data)
              v
+----------------------------+
|         Luma Backend       |
|          (Golang)          |
+-------------+--------------+
   |           |           |
   |           |           |
   v           v           v
Speech-to-Text  LLM Service    Local DB (Postgres)
(Whisper API)   (OpenAI/       (migrations for
                Gemini/...)    Postgres)
```

- The backend is stateless except for DB storage.
- Audio is uploaded via `multipart/form-data`.
- Clipboard context is provided by the frontend as plain text, not accessed directly from the backend.

---

## 3. Technology Stack

### Backend

- Language: **Golang 1.24+**
- HTTP router: **Gin** (structured middleware and JSON helpers).
- Database: **Postgres** via DSN (`LUMA_DB_DSN`)
- Migrations: SQL strings checked into the repo and executed on startup via the server or `cmd/migrate`.
- Config: Lightweight YAML + env loader (`internal/config`).
- Logging: standard library `slog` (JSON handler).
- HTTP client: standard `net/http` for calling external APIs (STT + LLM).

### External Services

- STT: Whisper via OpenAI API (MVP).
- LLM Providers (MVP set):
  - OpenAI (GPT-4.x, o3, etc.).
  - Gemini (Google AI).
  - Extendable to others via provider interface.

---

## 4. Data Model & Database Schema

### 4.1 Schema Overview

Tables:

- `users`
- `system_prompts`
- `user_prompt_presets`
- `api_keys`
- `sessions`
- `messages`

MVP assumes a single local user, but schema supports multiple users if needed later.

---

### 4.2 Tables

#### 4.2.1 `users`

Stores application users.

```sql
CREATE TABLE users (
    id            TEXT PRIMARY KEY,
    name          TEXT NOT NULL,
    email         TEXT NOT NULL UNIQUE,
    password_hash TEXT NOT NULL,
    created_at    TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);
```

- Backend seeds a default `local-user` for compatibility but frontends should explicitly create a user during onboarding.
- Passwords are never stored in plaintext; the service hashes them (bcrypt in the MVP).

---

#### 4.2.2 `system_prompts`

Stores the global system prompt text.

```sql
CREATE TABLE system_prompts (
    id           TEXT PRIMARY KEY,          -- UUID
    prompt_text  TEXT NOT NULL,
    active       BOOLEAN NOT NULL DEFAULT TRUE,
    created_at   TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at   TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);
```

Business rules:
- At most one row has `active = 1`.
- If multiple exist, backend should select the latest active, or enforce constraints via code.
- Startup seeds a default prompt that rewrites transcripts into concise, conversational chat messages (until updated via API).

---

#### 4.2.3 `user_prompt_presets`

Stores multiple presets per user (e.g. Professional, Casual, CN → EN).

```sql
CREATE TABLE user_prompt_presets (
    id           TEXT PRIMARY KEY,         -- UUID
    user_id      TEXT NOT NULL,            -- for future multi-user, can be a static value for now
    name         TEXT NOT NULL,
    prompt_text  TEXT NOT NULL,
    created_at   TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at   TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_user_prompt_presets_user_id
    ON user_prompt_presets (user_id);
```

---

#### 4.2.4 `api_keys`

Stores encrypted API keys for each provider.

```sql
CREATE TABLE api_keys (
    id            TEXT PRIMARY KEY,
    user_id       TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    provider_name TEXT NOT NULL,
    encrypted_key TEXT NOT NULL,
    created_at    TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at    TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE UNIQUE INDEX idx_api_keys_user_provider
    ON api_keys (user_id, provider_name);
```

- Keys are unique per (user, provider).
- `encrypted_key` is stored using local symmetric encryption (see Security section).

---

#### 4.2.5 `sessions`

Represents a single rewrite flow (preset + provider/model + optional temporary prompt/context).

```sql
CREATE TABLE sessions (
    id                TEXT PRIMARY KEY,
    user_id           TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    preset_id         TEXT NOT NULL REFERENCES user_prompt_presets(id) ON DELETE CASCADE,
    provider_name     TEXT NOT NULL,
    model             TEXT NOT NULL,
    temporary_prompt  TEXT,
    context_text      TEXT,
    clipboard_enabled BOOLEAN NOT NULL DEFAULT FALSE,
    system_prompt_id  TEXT NOT NULL REFERENCES system_prompts(id),
    created_at        TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at        TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);
```

---

#### 4.2.6 `messages`

Stores both original content and rewritten result.

```sql
CREATE TABLE messages (
    id                TEXT PRIMARY KEY,     -- UUID
    session_id        TEXT NOT NULL,        -- FK to sessions(id)
    type              TEXT NOT NULL,        -- 'content' or 'rewrite'
    raw_text          TEXT NOT NULL,        -- transcribed or input text
    transformed_text  TEXT,                 -- only populated for 'rewrite'
    created_at        TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_messages_session_id
    ON messages (session_id);
```

---

## 5. Backend Components

### 5.1 HTTP API Layer

All HTTP routes live under `/api/v1` (plus `/healthz`). Gin handles middleware, body parsing, and error formatting; handlers defer business logic to services.

| Endpoint | Purpose |
| --- | --- |
| `GET /api/v1/users` | List users (MVP UI might just call once). |
| `POST /api/v1/users` | Create a user (`name`, `email`, `password`). |
| `GET /api/v1/system-prompt` | Read the active system prompt. |
| `PUT /api/v1/system-prompt` | Update system prompt (`{ "prompt_text": "..." }`). |
| `GET /api/v1/presets` | List presets. |
| `POST /api/v1/presets` | Create preset (`name`, `prompt_text`). |
| `PUT /api/v1/presets/:id` | Update preset. |
| `DELETE /api/v1/presets/:id` | Delete preset. |
| `GET /api/v1/api-keys?user_id=...` | List provider key metadata for a user. |
| `PUT /api/v1/api-keys/:provider` | Store/update provider API key (`{ "user_id": "...", "api_key": "..." }`). |
| `DELETE /api/v1/api-keys/:provider?user_id=...` | Remove stored provider key for a user. |
| `POST /api/v1/transcriptions` | Accepts `multipart/form-data` with `audio`, returns transcription text. |
| `GET /api/v1/sessions?user_id=...` | List recent sessions for a user (`?limit=`). |
| `POST /api/v1/sessions` | Create new session (`user_id`, `preset_id`, `provider_name`, `model`, optional `temporary_prompt`, `context_text`, `clipboard_enabled`). |
| `GET /api/v1/sessions/:id` | Fetch session details + messages. |
| `POST /api/v1/sessions/:id/messages` | Attach a content message (`raw_text`). |
| `POST /api/v1/sessions/:id/rewrite` | Trigger rewrite for a content message (`{ "message_id": "..." }`). |

Handlers are intentionally thin: validate payloads, translate errors, and call into the service layer.

---

### 5.2 Service Layer

Core services and responsibilities:

- **PromptService** – ensures a default system prompt exists, manages CRUD for presets, and exposes helpers for fetching prompts by ID.
- **UserService** – CRUD for users (MVP exposes create/list).
- **APIKeyService** – encrypts/decrypts provider API keys using AES-GCM and persists metadata in `api_keys`.
- **SessionService** – creates sessions, stores content/rewrite messages, orchestrates prompt composition, and delegates rewrite calls to provider clients.
- **TranscriptionService** – pluggable STT client (stubbed for now, ready for Whisper/OpenAI).
- **Provider Registry** – map of provider name → `LLMClient` implementation (Echo client today; replace with OpenAI/Gemini adapters later).
  - In code, `openai` uses the actual Chat Completions API via `github.com/sashabaranov/go-openai`, while `gemini` remains a mock until implemented.

These services encapsulate persistence and provider logic, allowing the HTTP layer to stay declarative and simplifying future swaps (e.g., adding a new provider or database).

---

### 5.3 Repository Layer

Repositories are responsible for persistence:

- `SystemPromptRepo`
  - `GetActive()`
  - `Update(promptText string)`

- `UserPromptPresetRepo`
  - `Create`, `Update`, `Delete`, `FindByUser`, `FindByID`

- `APIKeyRepo`
  - `FindByProvider(provider string)`
  - `CreateOrUpdate`
  - `Delete`

- `SessionRepo`
  - `Create`
  - `UpdateTemporaryPrompt`
  - `FindByID`

- `MessageRepo`
  - `CreateContentMessage`
  - `CreateRewriteMessage`
  - `FindBySession`

Repositories are implemented using standard SQL to run on Postgres.

---

## 6. Clipboard Context Handling

### 6.1 Frontend Responsibility

- Backend **must not** access the OS clipboard directly.
- The frontend:
  - Reads clipboard content when user enables the **“Use clipboard context”** toggle.
- Sends this text to backend as `context_text` when creating a session (`POST /api/v1/sessions`).
  - Optionally can update context in future via a dedicated endpoint (not required in MVP).

### 6.2 Backend Usage of Context

- `context_text` is stored in the `sessions` table.
- When composing the final prompt, the `PromptService` includes this context in a structured way, e.g.:

```text
You are rewriting the user's message.

Context (from clipboard):
<clipboard text here>

User preset instructions:
<preset prompt_text>

Temporary instructions for this session:
<temporary_prompt>

Now rewrite the following content:
<raw_text>
```

- Context should not be required, and behavior must be robust when `context_text` is empty.

---

## 7. Configuration Management

Use a config file `config.yaml` and allow overrides via env vars.

Example:

```yaml
server:
  port: 8080

database:
  dsn: postgres://postgres:postgres@localhost:5432/luma?sslmode=disable

providers:
  - name: openai
    base_url: https://api.openai.com/v1
  - name: gemini
    base_url: https://generativelanguage.googleapis.com/v1beta

security:
  encryption_key_env: LUMA_SECRET_KEY

logging:
  level: info
```

- `encryption_key_env` indicates environment variable name. The actual key should not live in the config file.

The backend loads this config at startup and wires services accordingly.

---

## 8. Security Considerations

- API keys are stored encrypted:
  - Use a symmetric algorithm (e.g. AES-GCM).
  - Encryption key loaded from an environment variable (`LUMA_SECRET_KEY`).
- Logs:
  - Do not log full API keys or request bodies containing sensitive user content in production mode.
  - Debug logs can be more verbose in local/dev modes, controlled by config.
- Session content is stored as plain text in DB for history; this is acceptable for local single-user MVP, but users must be informed.

---

## 9. Error Handling

- Error categories:
  - Validation errors (e.g. missing `preset_id`).
  - External service errors (STT/LLM).
  - Configuration errors (missing API key for provider).
- API responses should:
  - Use appropriate HTTP status codes (4xx for client errors, 5xx for server or external failures).
  - Return JSON with `error_code` and `message`, e.g.:

```json
{
  "error_code": "MISSING_API_KEY",
  "message": "No API key configured for provider 'openai'."
}
```

---

## 10. Future Extensions

- Add authentication and multi-user support (using `user_id` more fully).
- Add WebSocket or SSE endpoints for streaming transcription and incremental LLM responses.
- Add offline STT via local Whisper models.
- Add more advanced prompt composition structures (e.g. roles, templates).
- Add tagging and search over sessions/messages.
- Deploy backend to cloud (containerization, load balancing, managed DB).

---

This TD defines a modular, provider-agnostic, and local-first architecture for Luma that satisfies the MVP requirements while staying ready for future cloud deployment and richer features.
