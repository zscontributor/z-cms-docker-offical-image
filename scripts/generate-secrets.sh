#!/usr/bin/env bash
# Generate strong random secrets for a Z-CMS .env file.
#
#   ./scripts/generate-secrets.sh            # print the secret lines
#   ./scripts/generate-secrets.sh --write    # create .env from .env.example and
#                                            # fill the secrets in place
#
# Requires openssl (present on macOS and virtually every Linux). Every value is
# freshly random; run once and keep the .env safe — some keys can never be
# rotated without data loss (see the comments in .env.example).
set -euo pipefail

cd "$(dirname "$0")/.."

rand_b64() { openssl rand -base64 "${1:-32}" | tr -d '\n'; }
rand_hex() { openssl rand -hex "${1:-16}" | tr -d '\n'; }

POSTGRES_PASSWORD="$(rand_b64 24)"
REDIS_PASSWORD="$(rand_b64 24)"
S3_ACCESS_KEY="zcms$(rand_hex 8)"
S3_SECRET_KEY="$(rand_b64 24)"
JWT_SECRET="$(rand_b64 32)"
CMS_INTERNAL_TOKEN="$(rand_b64 32)"
SITE_RUNTIME_INTERNAL_TOKEN="$(rand_b64 32)"
TOTP_ENCRYPTION_KEY="$(rand_b64 32)"
MAIL_ENCRYPTION_KEY="$(rand_b64 32)"
SEED_ADMIN_PASSWORD="$(rand_b64 18)"

emit() {
  cat <<EOF
POSTGRES_PASSWORD=$POSTGRES_PASSWORD
REDIS_PASSWORD=$REDIS_PASSWORD
S3_ACCESS_KEY=$S3_ACCESS_KEY
S3_SECRET_KEY=$S3_SECRET_KEY
JWT_SECRET=$JWT_SECRET
CMS_INTERNAL_TOKEN=$CMS_INTERNAL_TOKEN
SITE_RUNTIME_INTERNAL_TOKEN=$SITE_RUNTIME_INTERNAL_TOKEN
TOTP_ENCRYPTION_KEY=$TOTP_ENCRYPTION_KEY
MAIL_ENCRYPTION_KEY=$MAIL_ENCRYPTION_KEY
SEED_ADMIN_PASSWORD=$SEED_ADMIN_PASSWORD
EOF
}

if [[ "${1:-}" == "--write" ]]; then
  # Three cases:
  #   - no .env yet            -> create it from .env.example, then fill.
  #   - .env still has change-me placeholders (e.g. just `cp`-ed) -> fill in place.
  #   - .env has real secrets  -> refuse, so we never clobber a live config.
  if [[ -f .env ]]; then
    if ! grep -q 'change-me' .env; then
      echo "Refusing to overwrite .env: it has no change-me placeholders left (looks like a real config). Remove it first, or run without --write and paste manually." >&2
      exit 1
    fi
    echo "Filling placeholder secrets in the existing .env…"
  else
    cp .env.example .env
  fi
  # Replace each placeholder value in place (portable sed for macOS + Linux).
  while IFS='=' read -r key val; do
    [[ -z "$key" ]] && continue
    # Escape sed replacement metacharacters in the random value.
    esc=$(printf '%s' "$val" | sed -e 's/[\/&|]/\\&/g')
    sed -i.bak -E "s|^${key}=.*|${key}=${esc}|" .env
  done < <(emit)
  rm -f .env.bak
  echo "Wrote fresh secrets into .env."
  echo "Now set DOMAIN, PUBLIC_SCHEME, ACME_EMAIL, SEED_ADMIN_EMAIL and the public URLs."
else
  echo "# Paste these into your .env (they replace the change-me placeholders):"
  emit
fi
