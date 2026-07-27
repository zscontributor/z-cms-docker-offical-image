#!/usr/bin/env bash
# Create the first admin user + a demo site, then point that site at the host you
# configured. Run ONCE, after the stack is up and the migrate job has completed
# (schema + built-in themes/plugins registered).
#
#   ./scripts/first-run-seed.sh
#   ./scripts/first-run-seed.sh -f docker-compose.yml -f compose/traefik.yml
#
# It runs the database seed inside a throwaway `migrate` container, which carries
# the full toolchain. The admin credentials come from SEED_ADMIN_EMAIL /
# SEED_ADMIN_PASSWORD in your .env. The seed is idempotent; re-running it with
# SEED_ADMIN_PASSWORD set resets the admin password.
#
# The seed ships the demo site bound to a development hostname (localhost:3100).
# This script then rebinds it to the host your deployment actually answers on,
# derived from .env, so the public site resolves immediately:
#   - localhost quickstart -> localhost:<SITE_RUNTIME_PORT>  (default 3000)
#   - a real DOMAIN        -> DOMAIN  (your reverse proxy terminates 80/443)
# Change it later any time under Sites in the admin.
set -euo pipefail
cd "$(dirname "$0")/.."

# Pass through any -f flags so this works with any reverse-proxy overlay.
COMPOSE_ARGS=("$@")
if [[ ${#COMPOSE_ARGS[@]} -eq 0 ]]; then
  COMPOSE_ARGS=(-f docker-compose.yml)
fi

# Read a value from .env without sourcing it (values may contain spaces/specials).
env_val() { [[ -f .env ]] && grep -E "^$1=" .env | head -1 | cut -d= -f2- || true; }

echo "Seeding the first admin user and demo site…"
docker compose "${COMPOSE_ARGS[@]}" run --rm --no-deps \
  migrate pnpm --filter @zcmsorg/database seed

# --- Point the demo site at your configured host --------------------------
DOMAIN="$(env_val DOMAIN)";            DOMAIN="${DOMAIN:-localhost}"
SITE_PORT="$(env_val SITE_RUNTIME_PORT)"; SITE_PORT="${SITE_PORT:-3000}"
PG_USER="$(env_val POSTGRES_USER)";    PG_USER="${PG_USER:-zcms}"
PG_DB="$(env_val POSTGRES_DB)";        PG_DB="${PG_DB:-zcms}"

if [[ "$DOMAIN" == "localhost" || "$DOMAIN" == 127.0.0.1* ]]; then
  TARGET_HOST="localhost:${SITE_PORT}"
else
  TARGET_HOST="$DOMAIN"
fi

echo "Binding the demo site to: ${TARGET_HOST}"
docker compose "${COMPOSE_ARGS[@]}" exec -T postgres \
  psql -U "$PG_USER" -d "$PG_DB" -v ON_ERROR_STOP=1 \
  -c "UPDATE domains SET hostname='${TARGET_HOST}' WHERE hostname='localhost:3100';" \
  || echo "  (could not auto-set the domain — set it under Sites in the admin instead)"

SCHEME="$(env_val PUBLIC_SCHEME)"; SCHEME="${SCHEME:-http}"
cat <<EOF

Done.
  Public site : ${SCHEME}://${TARGET_HOST}
  Admin       : ${SCHEME}://${TARGET_HOST}/admin   (SEED_ADMIN_EMAIL / SEED_ADMIN_PASSWORD)

Change the site's primary domain any time under Sites in the admin.
EOF
