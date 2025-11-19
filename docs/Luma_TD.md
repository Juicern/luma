# Luma – Technical Design Document (TD)

## 1. Overview

This document describes the technical design for **Luma**, a local-first voice-to-text-to-AI-rewrite assistant.

The system consists of:

- A **local backend** (Golang) exposing HTTP APIs.
- A **local database** (SQLite for MVP; schema compatible with Postgres).
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
Speech-to-Text  LLM Service    Local DB (SQLite)
(Whisper API)   (OpenAI/       (migrations for
                Gemini/...)    SQLite/Postgres)
```

- The backend is stateless except for DB storage.
- Audio is uploaded via `multipart/form-data`.
- Clipboard context is provided by the frontend as plain text, not accessed directly from the backend.

---

## 3. Technology Stack

### Backend

- Language: **Golang 1.22+**
- HTTP router: Chi, Fiber, or standard `net/http` with middleware.
- Database:
  - MVP: **SQLite** (file-based, e.g. `./data/luma.db`)
  - Future: Postgres (same schema, with minimal changes).
- Migrations: `golang-migrate` or similar tool (SQL-based migrations).
- Config: Viper or a minimal custom loader for `config.yaml`.
- Logging: `zap` or standard library logger.
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

- `system_prompts`
- `user_prompt_presets`
- `api_keys`
- `sessions`
- `messages`

MVP assumes a single local user, but schema supports multiple users if needed later.

---

### 4.2 Tables

#### 4.2.1 `system_prompts`

Stores the global system prompt text.

```sql
CREATE TABLE system_prompts (
    id           TEXT PRIMARY KEY,          -- UUID
    prompt_text  TEXT NOT NULL,
    active       BOOLEAN NOT NULL DEFAULT 1,
    created_at   TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at   TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);
```

Business rules:
- At most one row has `active = 1`.
- If multiple exist, backend should select the latest active, or enforce constraints via code.

---

#### 4.2.2 `user_prompt_presets`

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

#### 4.2.3 `api_keys`

Stores encrypted API keys for each provider.

```sql
CREATE TABLE api_keys (
    id           TEXT PRIMARY KEY,        -- UUID
    provider     TEXT NOT NULL,           -- "openai", "gemini", "anthropic", etc.
    display_name TEXT NOT NULL,           -- user-readable label
    encrypted_key TEXT NOT NULL,          -- encrypted API key string
    created_at   TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at   TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE UNIQUE INDEX idx_api_keys_provider
    ON api_keys (provider);
```

- For MVP, assume one key per provider.
- `encrypted_key` is stored using local symmetric encryption (see Security section).

---

#### 4.2.4 `sessions`

Represents a single rewrite flow (temp prompt + content + result + optional clipboard context).

```sql
CREATE TABLE sessions (
    id                TEXT PRIMARY KEY,      -- UUID
    user_id           TEXT NOT NULL,
    preset_id         TEXT NOT NULL,         -- FK to user_prompt_presets(id)
    temporary_prompt  TEXT,                  -- optional, derived from voice or text
    context_text      TEXT,                  -- clipboard context if provided
    device            TEXT,                  -- "macos", "ios", "windows", etc.
    created_at        TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_sessions_user_id
    ON sessions (user_id);

CREATE INDEX idx_sessions_preset_id
    ON sessions (preset_id);
```

---

#### 4.2.5 `messages`

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

The HTTP layer defines routes, parses requests, and returns responses. It delegates business logic to services.

Key endpoints (simplified):

#### Prompt Presets

- `GET /v1/prompts/presets`
  - Returns list of presets for the (local) user.

- `POST /v1/prompts/presets`
  - Creates a new preset.
  - Body: `{ "name": "...", "prompt_text": "..." }`

- `PUT /v1/prompts/presets/{id}`
  - Updates name or prompt text.

- `DELETE /v1/prompts/presets/{id}`
  - Deletes the preset.

#### System Prompt

- `GET /v1/prompts/system`
  - Returns the currently active system prompt.

- `PUT /v1/prompts/system`
  - Updates the active system prompt text.

#### API Keys

- `GET /v1/keys`
  - Returns list of providers and metadata (no raw keys).

- `POST /v1/keys`
  - Adds or updates a key for a provider.
  - Body: `{ "provider": "openai", "display_name": "...", "api_key": "..." }`

- `DELETE /v1/keys/{id}`
  - Deletes a key.

#### Sessions

- `POST /v1/sessions`
  - Creates a session.
  - Body:
    ```json
    {
      "preset_id": "preset-uuid",
      "device": "macos",
      "context_text": "optional clipboard content"
    }
    ```
  - Returns: `{ "session_id": "..." }`

- `POST /v1/sessions/{id}/temporary_prompt`
  - Uploads audio or text for temporary prompt.
  - `multipart/form-data` with:
    - `audio`: file (optional)
    - `text`: string (optional; used when frontend already transcribed)
  - Backend transcribes audio if provided and stores the result in `temporary_prompt`.

- `POST /v1/sessions/{id}/content`
  - Uploads audio for main content and triggers a full rewrite.
  - `multipart/form-data` with:
    - `audio`: file (required)
  - Backend:
    1. Transcribes audio to `raw_text`.
    2. Reads system prompt.
    3. Reads preset prompt using `preset_id`.
    4. Reads `temporary_prompt` and `context_text` from session.
    5. Composes final prompt.
    6. Selects provider/model (from request or default).
    7. Calls LLM.
    8. Stores:
       - content message
       - rewrite message
    9. Returns:
       ```json
       {
         "raw_text": "...",
         "transformed_text": "..."
       }
       ```

- `GET /v1/sessions/{id}`
  - Returns full session details and messages.

---

### 5.2 Service Layer

Core services:

#### `PromptService`

- Responsibilities:
  - Fetch active system prompt.
  - Fetch preset prompt by `preset_id`.
  - Build final prompt string given:
    - system prompt
    - preset prompt
    - temporary prompt
    - clipboard context (if present)

#### `TranscriptionService`

- `TranscribeAudio(audioBytes []byte, mimeType string) (string, error)`
- Uses Whisper (OpenAI) or another configurable provider.
- Handles API calls and error mapping.

#### `LLMService`

- Top-level interface for rewriting text via various providers.
- Interface:

```go
type LLMService interface {
    Rewrite(ctx context.Context, opts RewriteOptions) (string, error)
}

type RewriteOptions struct {
    Provider      string
    Model         string
    ApiKey        string
    Prompt        string  // fully composed prompt
    Content       string  // user content
}
```

- Implementation uses provider-specific adapters.

#### Provider Adapters

Each provider implements:

```go
type LLMProvider interface {
    Rewrite(ctx context.Context, apiKey string, model string, prompt string, content string) (string, error)
}
```

Providers:

- `OpenAIProvider`
- `GeminiProvider`
- (others later)

#### `APIKeyService`

- Responsibilities:
  - Store and retrieve encrypted API keys.
  - Decrypt keys when needed.
  - Enforce one key per provider for MVP.

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

Repositories should be implemented in a way that the DB driver (SQLite vs Postgres) can be swapped with minimal changes (e.g., using standard SQL and avoiding vendor-specific extensions).

---

## 6. Clipboard Context Handling

### 6.1 Frontend Responsibility

- Backend **must not** access the OS clipboard directly.
- The frontend:
  - Reads clipboard content when user enables the **“Use clipboard context”** toggle.
  - Sends this text to backend as `context_text` when creating a session (`POST /v1/sessions`).
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
  driver: sqlite
  dsn: ./data/luma.db

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
