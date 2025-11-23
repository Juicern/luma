# Luma Monorepo

Backend (Go) + macOS frontend (SwiftUI) for capturing audio, transcribing, rewriting with LLMs, and pasting results. Product and technical docs live in `docs/`.

## What’s inside

- `backend/` – Go HTTP API (PostgreSQL, AES‑encrypted API keys, OpenAI/Gemini adapters, async rewrite pipeline). See `backend/README.md`.
- `frontend-mac/` – SwiftUI app (global shortcuts, recording HUD, history, prompts, Keychain login, UserDefaults persistence). See `frontend-mac/README.md`.
- `docs/` – PRD/TD references shared by both sides.

## Quick start

### Prereqs
- Go 1.21+ and PostgreSQL (local or AWS)
- Swift 5.9+ / Xcode 15+ on macOS 13+

### Backend (local)
```bash
cd backend
export LUMA_SECRET_KEY="local-dev-secret"
export DATABASE_DSN="postgres://postgres:postgres@localhost:5432/luma?sslmode=disable"
go run ./cmd/migrate    # one-time schema
make run                # or go run ./cmd/server
```
Health check: `curl http://localhost:8080/healthz`

### Frontend (local)
```bash
cd frontend-mac
make run-local   # uses http://localhost:8080
```
The distributed DMG is baked to hit `https://luma-api.juicernchu.store`; override with `LUMA_BACKEND_URL=... make run` if needed.

## Deploying backend to AWS (high level)
1. Run server on EC2/ECS (listening on 8080) with Postgres (RDS or EC2).  
2. Put an ALB in front, listener 443 → target group port 8080.  
3. Issue ACM cert for your domain (e.g., `luma-api.juicernchu.store`) and attach to ALB.  
4. Add DNS CNAME `luma-api -> <alb_dns_name>`.  
5. Set env vars (`DATABASE_DSN`, `LUMA_SECRET_KEY`, etc.) on the instance/task.  
6. Verify: `curl https://luma-api.yourdomain/healthz`.

## CI/CD
- GitHub Actions: `backend-ci.yml` runs `go test ./...`; `frontend-dmg.yml` builds and uploads a DMG artifact on macOS runners.

## Frontend highlights
- Global shortcuts (customizable; stored in UserDefaults)
- Recording HUD + async “transcribed / generating rewrite” states
- History with detail sheet (raw vs transformed, copy)
- Prompts (templates + user presets), persistence across launches
- Login via backend session cookies; Keychain helper to save/fill credentials

## Backend highlights
- PostgreSQL schema auto-created/migrated via `cmd/migrate`
- Encrypted API keys (AES‑GCM with `LUMA_SECRET_KEY`)
- Pluggable LLM providers (OpenAI client live; Gemini placeholder echo)
- Async rewrite pipeline: Whisper transcription → LLM rewrite → stored history
- REST API under `/api/v1` (see `backend/README.md` for endpoints)

## Handy commands
- Backend: `make run`, `make db`, `make test`, `make release`
- Frontend: `make run` (uses baked AWS URL), `make run-local` (localhost), `make dmg`

## Repo layout
```
backend/        # Go API + Makefile + config.yaml
frontend-mac/   # SwiftUI mac app
docs/           # PRD/TD
dist/           # DMG/app artifacts (ignored by Git except example)
```
