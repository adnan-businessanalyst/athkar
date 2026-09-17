# Athkar API

Compose services: Postgres 16, Redis 7, FastAPI on `127.0.0.1:8080`.

Public host: `https://api.athkar.ghurabi.com`

## Phase 3

`GET /health` → `{"ok":true}`

## Phase 4 — auth

- `POST /auth/register`
- `POST /auth/login`
- `POST /auth/refresh`
- `POST /auth/logout` (Bearer access + refresh token)
- `GET /auth/me` (Bearer)
- `DELETE /account` (Bearer; soft-delete)

Passwords: Argon2id. Access JWT ~15 minutes. Refresh tokens hashed (SHA-256), ~30 days, rotated on refresh.

`JWT_SECRET` must exist in `/etc/athkar/athkar.env` on the VPS.

No Flutter HTTP client yet. No `/sync` yet.

See the chat reply for the exact **On your PC** / **On the VPS** commands.
