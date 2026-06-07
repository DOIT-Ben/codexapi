#!/usr/bin/env sh
set -eu

ROOT="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
cd "$ROOT"

if [ ! -f ".env" ]; then
  echo "Missing .env." >&2
  exit 1
fi

set -a
. "$ROOT/.env"
set +a

mkdir -p "$ROOT/backups"
STAMP="$(date +%Y%m%d-%H%M%S)"
OUT="$ROOT/backups/sub2api-postgres-$STAMP.sql.gz"

docker compose --env-file .env exec -T postgres \
  pg_dump -U "${POSTGRES_USER:-sub2api}" "${POSTGRES_DB:-sub2api}" | gzip > "$OUT"

echo "Backup written: $OUT"
