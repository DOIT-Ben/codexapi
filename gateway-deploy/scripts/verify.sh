#!/usr/bin/env sh
set -eu

ROOT="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
cd "$ROOT"

if [ ! -f ".env" ]; then
  echo "Missing .env. Run ./scripts/init-secrets.sh first." >&2
  exit 1
fi

docker compose --env-file .env config --quiet
docker compose --env-file .env up -d

HEALTH_URL="http://localhost:18080/health"
END=$(( $(date +%s) + 180 ))
OK=0
while [ "$(date +%s)" -lt "$END" ]; do
  if curl -fsS "$HEALTH_URL" >/dev/null 2>&1; then
    OK=1
    break
  fi
  sleep 5
done

docker compose --env-file .env ps

if [ "$OK" -ne 1 ]; then
  docker compose --env-file .env logs --tail 80 sub2api
  echo "Health check failed: $HEALTH_URL" >&2
  exit 1
fi

echo "OK: local deployment is healthy at http://localhost:18080"
