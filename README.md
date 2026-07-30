# Z-CMS — official Docker images

**English** | [Tiếng Việt](readme/README.vi.md) | [日本語](readme/README.ja.md)

Run [Z-CMS](https://github.com/zscontributor/z-cms) — a multi-tenant CMS with a
theme engine and a signed plugin marketplace — from prebuilt Docker images. This
repository is the fast path to a running instance: the official images, a full
`docker compose` stack, ready-made reverse-proxy setups (Traefik, Caddy, Nginx,
Apache, Portainer), and the guide to operate them.

- **Source code:** [github.com/zscontributor/z-cms](https://github.com/zscontributor/z-cms)
- **Images:** [`zcms`](https://hub.docker.com/u/zcms) on Docker Hub
- **Docs:** [docs.z-cms.org](https://docs.z-cms.org) · **Site:** [z-cms.org](https://z-cms.org)

---

## Contents

- [What you get](#what-you-get)
- [Requirements](#requirements)
- [Quickstart (5 minutes, localhost)](#quickstart-5-minutes-localhost)
- [Production with a domain + HTTPS](#production-with-a-domain--https)
  - [Traefik](#traefik-automatic-https-docker-native)
  - [Caddy](#caddy-simplest-automatic-https)
  - [Nginx](#nginx)
  - [Apache](#apache-httpd)
  - [Portainer](#portainer)
- [The images](#the-images)
- [Configuration](#configuration)
- [Day-2 operations](#day-2-operations)
- [Troubleshooting](#troubleshooting)
- [Building & publishing the images](#building--publishing-the-images)
- [Security model](#security-model)

---

## What you get

A single Z-CMS deployment runs **any number of independent sites** — each with its
own domain, content, theme and settings — on one shared stack. The stack is a
handful of small services rather than one monolith, because some of it runs
third-party code (themes, marketplace plugins) and that code is deliberately kept
away from your credentials.

| Layer | Service | Image | Port |
| --- | --- | --- | --- |
| Public site | `site-runtime` | `zcms/site-runtime` | 3000 |
| Admin UI | `admin-web` | `zcms/admin-web` | 3001 |
| Core API | `cms-api` | `zcms/cms-api` | 4100 |
| Background jobs | `worker` | `zcms/worker` | — |
| Plugin sandbox | `plugin-runtime` | `zcms/plugin-runtime` | 4200 |
| DB migration/seed | `migrate` | `zcms/migrate` | — (one-shot) |
| Database | `postgres` | `postgres:17-alpine` | 5432 |
| Cache / queue | `redis` | `redis:8-alpine` | 6379 |
| Object storage | `rustfs` | `rustfs/rustfs` | 9000/9001 |
| Dev mail | `mailpit` | `axllent/mailpit` | 8025 |

Images are published **multi-arch** (`linux/amd64` + `linux/arm64`), so they run on
ordinary x86 servers and on ARM (Apple Silicon, AWS Graviton) alike.

See [docs/architecture.md](docs/architecture.md) for how the pieces fit and why the
split exists.

---

## Requirements

- **Docker Engine 24+** with the **Compose v2** plugin (`docker compose version`).
- A host with ~**2 vCPU / 4 GB RAM** to start comfortably (it runs on less).
- For a public deployment: a **domain name** pointed at the host and ports **80 +
  443** reachable from the internet.

---

## Quickstart (5 minutes, localhost)

No domain, no TLS — just to see it running on your machine.

```bash
git clone https://github.com/zscontributor/z-cms-docker-offical-image.git zcms
cd zcms

# 1. Create .env with fresh random secrets
cp .env.example .env
./scripts/generate-secrets.sh --write     # fills the change-me placeholders

# 2. Start the stack (pulls the official images)
docker compose up -d

# 3. Create the first admin user + a demo site (run once)
./scripts/first-run-seed.sh
```

Then open:

- **Public site** → <http://localhost:3000>
- **Admin** → <http://localhost:3001/admin> — log in with `SEED_ADMIN_EMAIL` /
  `SEED_ADMIN_PASSWORD` from your `.env`
- **API docs** → <http://localhost:4100/api/v1/docs>
- **Captured email** (Mailpit) → <http://localhost:8025>

> The app ports are published on `127.0.0.1` only. For anything public, put it
> behind one of the reverse proxies below.

> **Ports `3000` / `3001`, not `3100` / `3101`.** These images run Z-CMS in
> production mode (`next start`), which binds the standard `3000` (site) and
> `3001` (admin). The [source](https://github.com/zscontributor/z-cms) dev
> servers (`next dev`) are deliberately remapped to `3100` / `3101` so they don't
> clash with ports commonly already taken on a developer's machine. The API
> (`4100`) is the same in both. The upshot: you can run the source dev stack
> (`3100` / `3101`) **and** this Docker stack (`3000` / `3001`) on the same
> machine at once without a port conflict.

Stop it with `docker compose down` (add `-v` to also wipe the data volumes).

---

## Production with a domain + HTTPS

The pattern is always the same: the base `docker-compose.yml` runs the stack, and a
small **overlay** file adds a reverse proxy that terminates TLS and routes by path
on your domain:

| Path on your domain | Goes to |
| --- | --- |
| `/api/v1/…` | `cms-api` (its only prefix — other `/api/*` paths belong to `site-runtime`, e.g. public form submits) |
| `/admin/…` | `admin-web` (admin UI) |
| `/zcms-media/…` | `rustfs` (public media reads) |
| everything else | `site-runtime` (the public site) |

First, in `.env`, switch the public values to your domain and HTTPS:

```dotenv
DOMAIN=your-domain.com
PUBLIC_SCHEME=https
ROOT_DOMAIN=your-domain.com
ACME_EMAIL=you@your-domain.com

CMS_API_URL=https://your-domain.com
ADMIN_WEB_URL=https://your-domain.com
SITE_RUNTIME_URL=https://your-domain.com
S3_PUBLIC_URL=https://your-domain.com/zcms-media
```

Point an `A`/`AAAA` DNS record for `your-domain.com` at the host, then pick a proxy.

### Traefik (automatic HTTPS, Docker-native)

```bash
docker compose -f docker-compose.yml -f compose/traefik.yml up -d
./scripts/first-run-seed.sh -f docker-compose.yml -f compose/traefik.yml
```

Traefik obtains and renews the Let's Encrypt certificate itself over TLS-ALPN-01.
Details and per-service routing labels: [compose/traefik.yml](compose/traefik.yml).

### Caddy (simplest automatic HTTPS)

```bash
docker compose -f docker-compose.yml -f compose/caddy.yml up -d
./scripts/first-run-seed.sh -f docker-compose.yml -f compose/caddy.yml
```

Caddy fetches and renews TLS with zero extra config. Routing lives in
[compose/caddy/Caddyfile](compose/caddy/Caddyfile).

### Nginx

```bash
docker compose -f docker-compose.yml -f compose/nginx.yml up -d
./scripts/first-run-seed.sh -f docker-compose.yml -f compose/nginx.yml
```

Works on HTTP `:80` immediately (use it when TLS is terminated upstream — a load
balancer or Cloudflare). To terminate TLS at Nginx itself, enable the commented
HTTPS server block in
[compose/nginx/zcms.conf.template](compose/nginx/zcms.conf.template) and mount your
certificates — see the file's header for the exact steps.

### Apache (httpd)

```bash
docker compose -f docker-compose.yml -f compose/apache.yml up -d
./scripts/first-run-seed.sh -f docker-compose.yml -f compose/apache.yml
```

A self-contained `mod_proxy` config with all the right modules loaded, HTTP `:80`
by default and a ready-to-enable SSL virtual host:
[compose/apache/httpd.conf](compose/apache/httpd.conf).

### Portainer

A single self-contained stack file with an inline Caddy for automatic HTTPS — no
host files to mount, so you can paste it straight into Portainer's web editor:
[compose/portainer.stack.yml](compose/portainer.stack.yml). The file's header lists
the environment variables to set and the one-time seed step.

---

## The images

All images live under **`zcms`** on Docker Hub and are tagged by release version
(`0.1.0`, `0.1`) plus `latest`. Pin an exact version in production (`ZCMS_VERSION`
in `.env`); `latest` tracks the newest release.

```
zcms/cms-api          the NestJS core API (holds the DB/S3 credentials)
zcms/site-runtime     the public Next.js site (runs theme code — hardened)
zcms/admin-web        the Next.js admin UI (no credentials)
zcms/worker           BullMQ background jobs
zcms/plugin-runtime   the untrusted-plugin sandbox (credential-free)
zcms/migrate          one-shot: migrations + register signed built-ins
```

`postgres`, `redis`, `rustfs`, `mailpit` are stock upstream images.

---

## Configuration

Everything is driven by `.env` (start from `.env.example`, which documents every
variable inline). The essentials:

- **Secrets** — run `./scripts/generate-secrets.sh` to produce strong values for
  all of them. Some can **never be rotated without data loss**
  (`TOTP_ENCRYPTION_KEY` invalidates every enrolled 2FA device; `JWT_SECRET`,
  `MAIL_ENCRYPTION_KEY` matter too). Set once, back them up.
- **Public URLs** — `DOMAIN`, `PUBLIC_SCHEME`, and the `*_URL` / `S3_PUBLIC_URL`
  values must match how a browser reaches you, or CSP will block assets.
- **`FIRST_PARTY_PUBLIC_KEY`** — the key the official images are signed with. The
  default in `.env.example` matches the published images; leave it unless you build
  and sign your own.
- **Marketplace** — the official Z-CMS marketplace is enabled by default, so the
  admin lists its themes and plugins out of the box. Blank both `MARKETPLACE_URL`
  and `MARKETPLACE_PUBLIC_KEY` to run fully offline, or repoint them at a private
  marketplace (the key, not the hostname, is the trust boundary).

Full reference: [docs/configuration.md](docs/configuration.md).

---

## Day-2 operations

| Task | Command |
| --- | --- |
| View logs | `docker compose logs -f cms-api` |
| Update to a new release | set `ZCMS_VERSION`, then `docker compose pull && docker compose up -d` |
| Re-run migrations | happens automatically on every `up` (the `migrate` job) |
| Back up the database | `docker compose exec postgres pg_dump -U zcms zcms > backup.sql` |
| Reset the admin password | set `SEED_ADMIN_PASSWORD`, then `./scripts/first-run-seed.sh` |
| Stop | `docker compose down` (keep data) / `down -v` (delete data) |

Upgrades: [docs/upgrading.md](docs/upgrading.md) ·
Backup & restore: [docs/backup-restore.md](docs/backup-restore.md) ·
Going live: [docs/production-checklist.md](docs/production-checklist.md).

---

## Troubleshooting

**The public site shows nothing / a fallback.**
`first-run-seed.sh` binds the demo site to the host from your `.env` — `DOMAIN`
for a real deployment, or `localhost:<SITE_RUNTIME_PORT>` for the quickstart. If
you change `DOMAIN` afterwards, or front it with a different hostname, update the
primary domain under **Sites** in the admin: the public site resolves by the
exact `Host` header. (If you seed by hand — e.g. the Portainer console — set the
domain in the admin, since only the script auto-binds it.)

**A service keeps restarting on boot.** Check `docker compose logs <service>`.
Most first-boot failures are a missing/weak env value — the stack refuses to start
with an unset `POSTGRES_PASSWORD`, `REDIS_PASSWORD`, `S3_*`,
`FIRST_PARTY_PUBLIC_KEY`, or a `SITE_RUNTIME_INTERNAL_TOKEN` equal to
`CMS_INTERNAL_TOKEN` (they must differ).

**Images or thumbnails 403 / don't load.** `S3_PUBLIC_URL` doesn't match the origin
the browser actually uses. It must be the public URL of your media path
(`https://your-domain.com/zcms-media`), and it feeds the admin/site CSP `img-src`.

**Built-in themes/plugins won't load.** `FIRST_PARTY_PUBLIC_KEY` doesn't match the
key the images were signed with. Use the default from `.env.example` with the
official images.

**Login fails right after install.** You haven't run the seed yet
(`./scripts/first-run-seed.sh`), or `NODE_ENV=production` refused to seed a
weak/empty `SEED_ADMIN_PASSWORD` — set a strong one and re-run.

More: [docs/configuration.md](docs/configuration.md).

---

## Building & publishing the images

You do **not** need this to run Z-CMS — the images are on Docker Hub. It's here for
maintainers and for anyone running a fork.

- **CI:** [`.github/workflows/publish.yml`](.github/workflows/publish.yml) checks out
  the source repo at a chosen ref and pushes all six images multi-arch to
  `zcms/*`. It needs the `DOCKERHUB_USERNAME` / `DOCKERHUB_TOKEN` secrets.
- **Local:** `NAMESPACE=zcms TAG=0.1.0 SRC=/path/to/z-cms
  ./scripts/build-and-push.sh` (requires `docker login` and QEMU for the arm64 leg).

A fork that changes built-in themes/plugins must sign them with its **own** key and
set `FIRST_PARTY_PUBLIC_KEY` to the matching public half everywhere.

---

## Security model

The stack is split along a trust boundary, and it is worth understanding before you
expose it:

- **`site-runtime`** renders themes in-process (a theme is *not* sandboxed) and
  **`plugin-runtime`** runs marketplace plugins. Neither is ever handed the database,
  Redis or S3 credentials — only the few values it needs. `plugin-runtime` lives on
  an `internal` Docker network with **no route off the host**, so escaped plugin code
  still can't reach your cloud metadata service or the internet.
- **Postgres uses two roles.** The app connects as a non-owner role that RLS always
  applies to, so a tenant can never read another tenant's rows.
- **Every built-in and every marketplace package is signature-verified** against a
  pinned public key before a byte of it runs.

Details: [docs/architecture.md](docs/architecture.md) and
[docs/production-checklist.md](docs/production-checklist.md).

---

## License

MIT — see [LICENSE](LICENSE). Z-CMS is © Z-SOFT Co., Ltd.
