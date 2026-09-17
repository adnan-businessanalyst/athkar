#!/bin/bash
set -euo pipefail

COMPOSE=/srv/athkar/deploy/docker-compose.yml
ENV_FILE=/etc/athkar/athkar.env
BACKUP_DIR=/var/backups/athkar
STAMP=$(date +%Y%m%d-%H%M)
OUT="$BACKUP_DIR/athkar-$STAMP.sql.gz"

mkdir -p "$BACKUP_DIR"
docker compose -f "$COMPOSE" --env-file "$ENV_FILE" exec -T postgres \
  pg_dump -U athkar_app athkar | gzip > "$OUT"
find "$BACKUP_DIR" -name 'athkar-*.sql.gz' -mtime +14 -delete
echo "Wrote $OUT"
