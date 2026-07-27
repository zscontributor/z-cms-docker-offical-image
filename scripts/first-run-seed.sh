#!/usr/bin/env bash
# Create the first admin user + a demo site. Run ONCE, after the stack is up and
# the migrate job has completed (schema + built-in themes/plugins registered).
#
#   ./scripts/first-run-seed.sh
#   ./scripts/first-run-seed.sh -f docker-compose.yml -f compose/traefik.yml
#
# It runs the database seed inside a throwaway `migrate` container, which carries
# the full toolchain. The admin credentials come from SEED_ADMIN_EMAIL /
# SEED_ADMIN_PASSWORD in your .env. The seed is idempotent; re-running it with
# SEED_ADMIN_PASSWORD set resets the admin password.
#
# The seed ships a demo site bound to a localhost hostname. After it runs, log in
# at https://<your-domain>/admin and, under Sites, set the primary domain to your
# real hostname so the public site resolves there.
set -euo pipefail
cd "$(dirname "$0")/.."

# Pass through any -f flags so this works with any reverse-proxy overlay.
COMPOSE_ARGS=("$@")
if [[ ${#COMPOSE_ARGS[@]} -eq 0 ]]; then
  COMPOSE_ARGS=(-f docker-compose.yml)
fi

echo "Seeding the first admin user and demo site…"
docker compose "${COMPOSE_ARGS[@]}" run --rm --no-deps \
  migrate pnpm --filter @zcmsorg/database seed

cat <<'EOF'

Done. Next:
  1. Log in at  https://<your-domain>/admin  (SEED_ADMIN_EMAIL / SEED_ADMIN_PASSWORD)
  2. Under Sites, set the primary domain to your real hostname.
EOF
