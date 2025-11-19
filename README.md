# Luma Monorepo

This repo contains:

- `backend/` – Go HTTP API (config, docs, and tooling moved here). See `backend/README.md`.
- `frontend-mac/` – SwiftUI macOS client.
- `docs/` – shared PRD/TD.

### Running

- Backend: `cd backend && make run` (see README for env vars).
- Frontend: `cd frontend-mac && swift run LumaMac`.

### Repo layout

```
backend/        # Go API
frontend-mac/   # SwiftUI mac app
docs/           # Product/technical documents shared by both sides
```
