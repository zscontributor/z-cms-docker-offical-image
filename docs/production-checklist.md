# Production checklist

Before you expose a Z-CMS instance to the internet.

## Secrets

- [ ] Ran `./scripts/generate-secrets.sh` — no `change-me-*` values remain in `.env`.
- [ ] `SITE_RUNTIME_INTERNAL_TOKEN` is **different** from `CMS_INTERNAL_TOKEN`.
- [ ] `SEED_ADMIN_PASSWORD` is strong (production refuses `admin123`, `password`, …).
- [ ] `TOTP_ENCRYPTION_KEY` and `MAIL_ENCRYPTION_KEY` are 32 random bytes and **backed
      up** — rotating them is destructive.
- [ ] `.env` is not committed to git and is readable only by the deploy user
      (`chmod 600 .env`).

## Network & TLS

- [ ] Behind a reverse proxy terminating **HTTPS** (Traefik / Caddy / Nginx / Apache).
- [ ] `PUBLIC_SCHEME=https` and every `*_URL` / `S3_PUBLIC_URL` uses `https://` and
      your real domain.
- [ ] `TRUST_PROXY` is the real hop count (usually `1`), not `true`.
- [ ] Postgres, Redis and RustFS are **not** published to the internet (the compose
      files keep app ports on `127.0.0.1` and never publish the datastores).
- [ ] Only `80` and `443` are open on the host firewall.

## Data & storage

- [ ] Database backups scheduled — see [backup-restore.md](backup-restore.md).
- [ ] Named volumes (`postgres-data`, `redis-data`, `rustfs-data`) are on durable
      storage you back up. Consider a managed Postgres and S3/R2 for real scale.
- [ ] `S3_PUBLIC_URL` verified: upload an image in the media library and confirm it
      renders (a wrong value fails silently at the browser, not at upload).

## First run

- [ ] `migrate` completed (schema + signed built-ins registered).
- [ ] Ran `./scripts/first-run-seed.sh` once.
- [ ] Logged in at `/admin`, set the site's **primary domain** to your real hostname.
- [ ] Enabled **2FA** on the admin account.
- [ ] Configured real mail under **Settings → Mail** (or `SMTP_*`).

## Hardening (already on by default — verify)

- [ ] `plugin-runtime` is on the `zcms-sandbox` internal network (no internet route).
- [ ] `site-runtime` / `plugin-runtime` run `read_only`, `cap_drop: ALL`,
      `no-new-privileges`, as non-root.
- [ ] `FIRST_PARTY_PUBLIC_KEY` matches your images (default = official images).
- [ ] If using a marketplace: `MARKETPLACE_PUBLIC_KEY` is pinned.
- [ ] Sideload keys (`OPERATOR_*`) left blank unless you deliberately sideload;
      `ALLOW_THEME_SIDELOAD=false` unless you mean it.

## Operations

- [ ] `ZCMS_VERSION` pinned to an exact release tag (not `latest`) for reproducible
      rollouts and rollbacks.
- [ ] `SECURITY_ALERT_WEBHOOK` set so session-theft / revoked-token / quarantine /
      dead-letter events page you.
- [ ] `restart: unless-stopped` (default) — services recover on host reboot.
- [ ] A staging copy where you test upgrades before production.
