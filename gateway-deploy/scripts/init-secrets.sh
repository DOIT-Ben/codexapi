#!/usr/bin/env sh
set -eu

ROOT="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
ENV_FILE="$ROOT/.env"
EXAMPLE="$ROOT/.env.example"

if [ -f "$ENV_FILE" ] && [ "${1:-}" != "--force" ]; then
  echo ".env already exists. Use --force to overwrite."
  exit 0
fi

hex_secret() {
  openssl rand -hex "${1:-32}"
}

sed \
  -e "s/CHANGE_ME_ADMIN_PASSWORD/$(hex_secret 18)/g" \
  -e "s/CHANGE_ME_JWT_SECRET_HEX_32_BYTES/$(hex_secret 32)/g" \
  -e "s/CHANGE_ME_TOTP_HEX_32_BYTES/$(hex_secret 32)/g" \
  -e "s/CHANGE_ME_POSTGRES_PASSWORD/$(hex_secret 24)/g" \
  -e "s/CHANGE_ME_REDIS_PASSWORD/$(hex_secret 24)/g" \
  "$EXAMPLE" > "$ENV_FILE"

echo "Created $ENV_FILE"
echo "Local preview URL: http://localhost:18080"
echo "Before production, edit SITE_ADDRESS, APP_BASE_URL, CORS_ALLOWED_ORIGINS, and ADMIN_EMAIL."
