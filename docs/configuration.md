# Configuration reference

Every setting lives in `.env` (copy from `.env.example`). The compose files inject
these values into the containers. This page groups them by purpose; the inline
comments in `.env.example` are the authoritative per-variable notes.

## How to fill it in

```bash
cp .env.example .env
./scripts/generate-secrets.sh --write   # strong random values for every secret
# then edit DOMAIN, PUBLIC_SCHEME, ACME_EMAIL, SEED_ADMIN_EMAIL, and the *_URL values
```

## Public address

| Variable | What it is |
| --- | --- |
| `DOMAIN` | Public hostname, no scheme (e.g. `example.com`). |
| `PUBLIC_SCHEME` | `https` behind a proxy, `http` for a bare localhost test. |
| `ROOT_DOMAIN` | Primary host of the main site (usually `= DOMAIN`). |
| `ACME_EMAIL` | Let's Encrypt registration email (Traefik/Caddy). |
| `ZCMS_VERSION` | Image tag to run. Pin an exact release in prod; `latest` tracks newest. |

## Secrets — regenerate every one before going public

| Variable | Rotatable? | Notes |
| --- | --- | --- |
| `POSTGRES_PASSWORD` | yes (with care) | Owner DB role; bypasses RLS. Guard it. |
| `APP_DB_USER` / `APP_DB_PASSWORD` | first-boot only | Must match the init SQL. Network-internal role. |
| `JWT_SECRET` | rotating logs everyone out | Signs access/refresh tokens. |
| `CMS_INTERNAL_TOKEN` | yes | **Privileged** service token (worker, plugin dispatch). |
| `SITE_RUNTIME_INTERNAL_TOKEN` | yes | Render-only token. **Must differ** from `CMS_INTERNAL_TOKEN`. |
| `TOTP_ENCRYPTION_KEY` | **NO** | Rotating invalidates every enrolled 2FA device. 32 bytes. |
| `MAIL_ENCRYPTION_KEY` | rotating breaks saved SMTP creds | Encrypts SMTP password at rest. 32 bytes. |
| `REDIS_PASSWORD` | yes | Protects the render cache. |
| `S3_ACCESS_KEY` / `S3_SECRET_KEY` | yes | Object storage credentials. |
| `SEED_ADMIN_EMAIL` / `SEED_ADMIN_PASSWORD` | password re-seedable | First admin. Prod refuses weak/empty passwords. |

> Generate a 32-byte key manually with:
> `node -e "console.log(require('crypto').randomBytes(32).toString('base64'))"`
> or `openssl rand -base64 32`.

## Storage

| Variable | What it is |
| --- | --- |
| `S3_ENDPOINT` | Set by compose to `http://rustfs:9000`. Point at a managed provider to swap RustFS out. |
| `S3_PUBLIC_URL` | Browser-facing media origin, e.g. `https://example.com/zcms-media`. Feeds CSP `img-src`. |
| `S3_REGION` / `S3_BUCKET` | Defaults `us-east-1` / `zcms-media`. |

**Using a managed provider (S3 / R2) instead of the bundled RustFS:** remove the
`rustfs` + `storage-init` services, set `S3_ENDPOINT`, `S3_ACCESS_KEY`,
`S3_SECRET_KEY`, `S3_BUCKET`, `S3_REGION` for the provider, and `S3_PUBLIC_URL` to
the provider's public/CDN URL.

## Admin & site

| Variable | What it is |
| --- | --- |
| `ADMIN_BASE_PATH` | Where the admin mounts under each site origin. Default `/admin`. |
| `CMS_API_URL` / `ADMIN_WEB_URL` / `SITE_RUNTIME_URL` | Public origins for links/CORS/CSP. Set to your `https://` origin. |
| `CMS_API_PUBLIC_URL` | Only if a browser calls the API cross-origin directly. Usually blank. |
| `CMS_API_PORT` / `ADMIN_WEB_PORT` / `SITE_RUNTIME_PORT` | Host ports for the bare quickstart (127.0.0.1). Ignored behind a proxy. |

## Trust anchors (signature verification)

| Variable | What it is |
| --- | --- |
| `FIRST_PARTY_PUBLIC_KEY` | Verifies the built-in themes/plugins in the image. The `.env.example` default matches the **official images** — leave it unless you build & sign your own. |
| `MARKETPLACE_URL` | Marketplace this instance installs from. Defaults to the official Z-CMS marketplace; blank = offline (built-ins still work). |
| `MARKETPLACE_PUBLIC_KEY` | Pinned key the marketplace's packages/revocations are verified against. The key, not the URL, is the trust boundary. |
| `OPERATOR_PUBLIC_KEY` | Verifies sideloaded (install-from-file) packages. Blank = sideload disabled. |
| `OPERATOR_PRIVATE_KEY` | Only for the `.zip` convenience path (cms-api signs). Leave blank; sign offline instead. |
| `ALLOW_THEME_SIDELOAD` | A sideloaded theme runs unsandboxed. `false` until you opt in. |

## Mail

Dev default captures everything in **Mailpit** (`http://localhost:8025`). For real
delivery, either point `SMTP_*` at your provider, or — preferred — configure it in
the admin under **Settings → Mail** (encrypted at rest, per-site, no restart).

| Variable | What it is |
| --- | --- |
| `SMTP_HOST` / `SMTP_PORT` | `mailpit` / `1025` in dev. |
| `SMTP_FROM` | Envelope From. |
| `SMTP_USER` / `SMTP_PASSWORD` / `SMTP_SECURE` | Provider credentials; `SMTP_SECURE=true` only for implicit-TLS port 465. |
| `MAIL_PLUGIN_HOURLY_LIMIT` | Cap on plugin-sent mail per site per hour. |

## Tuning & ops

| Variable | What it is |
| --- | --- |
| `DB_POOL_MAX` | Connections per pool per process (real ceiling ≈ ×4). Raise with Postgres `max_connections`. |
| `WORKER_CONCURRENCY` | Parallel jobs in the worker. |
| `MFA_ISSUER` | Name shown in authenticator apps. |
| `TRUST_PROXY` | Real proxy hop count (usually `1`). Never `true` behind a proxy — it lets clients forge `X-Forwarded-For`. |
| `SWAGGER_ENABLED` | Serve OpenAPI docs at `/api/v1/docs`. Safe to leave on. |
| `SECURITY_ALERT_WEBHOOK` | POST endpoint for four security events. Blank = log only. |
| `ENABLE_SITE_LOCALES_ON_DEPLOY` / `SITE_LOCALES` | Deploy-time locale enable for a multilingual main site. Leave `0` for generic multi-site. |
