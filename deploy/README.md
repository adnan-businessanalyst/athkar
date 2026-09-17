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

That file must be readable by the user who runs `docker compose` (`athkar-app`), not only by root:

```bash
sudo chown athkar-app:athkar-app /etc/athkar/athkar.env
sudo chmod 600 /etc/athkar/athkar.env
```

## Phase 5 — sync

- `GET /sync?since=REVISION`
- `POST /sync` batch upsert (location, settings, counters, collections, items, daily_progress)
- Last `updated_at` wins. Soft delete. Per-user `sync_revision`.

## Phase 6 — device SQLite

Flutter uses Drift locally. No HTTP from the app yet.

See the chat reply for the exact **On your PC** / **On the VPS** commands.
