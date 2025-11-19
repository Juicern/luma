# Luma Backend

Golang backend that fulfills the requirements outlined in `docs/Luma_PRD.md` and `docs/Luma_TD.md`. It manages prompt presets, sessions, clipboard context, encrypted provider keys, and routes rewrite requests to pluggable LLM providers (Mock/Echo provider for now).

## Prerequisites

- Go 1.24+
- A running PostgreSQL instance (see `LUMA_DB_DSN`)
- Set an encryption key (for API keys) via `LUMA_SECRET_KEY`

## Configuration

Settings come from `config.yaml` (see committed example) and environment variables:

| Variable | Default | Description |
| --- | --- | --- |
| `HTTP_PORT` | `8080` | Server port |
| `HTTP_SHUTDOWN_TIMEOUT` | `10` | Graceful shutdown timeout in seconds |
| `LUMA_DB_DSN` | `postgres://postgres:postgres@localhost:5432/luma?sslmode=disable` | Postgres DSN connection string |
| `LUMA_SECRET_KEY` | _required for API keys_ | Symmetric key for AES-GCM encryption |
| `LUMA_CONFIG` | `config.yaml` | Custom config file location |

## Run

```bash
export LUMA_SECRET_KEY="local-dev-secret"
export LUMA_DB_DSN="postgres://postgres:postgres@localhost:5432/luma?sslmode=disable"
go run ./cmd/server
```

Migration SQL executes on startup (against Postgres). Default system prompt + preset store are created automatically.

## Make Targets

The `Makefile` captures common workflows:

- `make setup` – download/update modules.
- `make run` – run server in the foreground (uses `go run`).
- `make start` / `make stop` – start server in background using compiled binary and stop it via PID file.
- `make db` – run migrations only (via `cmd/migrate`).
- `make test` / `make lint` / `make fmt` – verify code health.
- `make release` – build distributable binaries under `dist/`.
- `make clean` – remove build artifacts and PID.

## HTTP API (v1)

All responses are JSON. Errors follow `{ "error": "<code>" }`.

| Endpoint | Description |
| --- | --- |
| `GET /healthz` | Health probe |
| `GET /api/v1/system-prompt` | Read active system prompt |
| `PUT /api/v1/system-prompt` | Update system prompt (`{ "prompt_text": "..." }`) |
| `GET /api/v1/presets` | List presets |
| `POST /api/v1/presets` | Create preset (`name`, `prompt_text`) |
| `PUT /api/v1/presets/:id` | Update preset |
| `DELETE /api/v1/presets/:id` | Remove preset |
| `GET /api/v1/api-keys` | List stored providers + timestamps |
| `PUT /api/v1/api-keys/:provider` | Store/update encrypted API key (`{ "api_key": "..." }`) |
| `DELETE /api/v1/api-keys/:provider` | Remove provider key |
| `POST /api/v1/transcriptions` | Simulated STT endpoint, accepts `multipart/form-data` (`audio` file) |
| `GET /api/v1/sessions` | List sessions (pass `?limit=50` etc.) |
| `POST /api/v1/sessions` | Create session (`preset_id`, `provider_name`, `model`, optional `temporary_prompt`, `context_text`, `clipboard_enabled`) |
| `GET /api/v1/sessions/:id` | Fetch session details + messages |
| `POST /api/v1/sessions/:id/messages` | Add a content message (`raw_text`) |
| `POST /api/v1/sessions/:id/rewrite` | Trigger rewrite for a content message (`message_id`) |

### Example Flow

```bash
# store a fake OpenAI key (required before rewrites)
curl -X PUT http://localhost:8080/api/v1/api-keys/openai \
  -H "Content-Type: application/json" \
  -d '{"api_key": "sk-local-dev"}'

# create a preset
curl -X POST http://localhost:8080/api/v1/presets \
  -H "Content-Type: application/json" \
  -d '{"name":"Professional","prompt_text":"Write concise professional responses."}'

# start a session
curl -X POST http://localhost:8080/api/v1/sessions \
  -H "Content-Type: application/json" \
  -d '{"preset_id":"<preset-id>","provider_name":"openai","model":"gpt-4o","context_text":"Reply to the thread below.","clipboard_enabled":true}'

# add content message and request rewrite
curl -X POST http://localhost:8080/api/v1/sessions/<session-id>/messages \
  -H "Content-Type: application/json" \
  -d '{"raw_text":"hey I cannot make it next week"}'

curl -X POST http://localhost:8080/api/v1/sessions/<session-id>/rewrite \
  -H "Content-Type: application/json" \
  -d '{"message_id":"<message-id>"}'
```

> The current LLM adapter (`providers.EchoClient`) simply echoes the composed prompts so that the wiring can be tested without calling real providers. Plug in real provider clients later by registering them in `cmd/server/main.go`.
