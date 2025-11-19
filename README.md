# Luma Backend

Simple Go backend scaffold for experimenting with API ideas described in the PRD/TD.

## Requirements

- Go 1.24+

## Running Locally

```bash
go run ./cmd/server
```

Environment variables:

| Variable | Default | Description |
| --- | --- | --- |
| `HTTP_PORT` | `8080` | Port to expose HTTP server |
| `HTTP_SHUTDOWN_TIMEOUT` | `10` | Graceful shutdown timeout in seconds |

## API

### Health Check

- `GET /healthz`

Returns basic service status.

### Documents

- `GET /api/v1/documents` – list all documents currently in memory.
- `POST /api/v1/documents` – create a new document.
- `GET /api/v1/documents/{id}` – fetch a single document.
- `PUT /api/v1/documents/{id}` – update a document.
- `DELETE /api/v1/documents/{id}` – remove a document.

Example payload:

```json
{
  "title": "Example",
  "content": "Draft requirements..."
}
```

> NOTE: Storage is in-memory only for now; persistence can be replaced with a real database once requirements are finalized.

