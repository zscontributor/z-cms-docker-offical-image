# Architecture

Z-CMS is a small set of services, not one process. The split is not incidental —
part of the platform runs code you did not write (themes, marketplace plugins), and
the boundaries below are what keep that code away from your credentials.

```
                        Internet
                           │
                    ┌──────┴───────┐
                    │ reverse proxy│  (Traefik / Caddy / Nginx / Apache)
                    │  TLS + routing│
                    └──────┬───────┘
        /admin  ┌──────────┼───────────┬──────────────┐  everything else
                │          │ /api      │ /zcms-media   │
          ┌─────▼────┐ ┌───▼────┐  ┌───▼────┐    ┌─────▼──────┐
          │admin-web │ │cms-api │  │ rustfs │    │site-runtime│
          │  :3001   │ │ :4100  │  │ :9000  │    │   :3000    │
          └──────────┘ └──┬──┬──┘  └────────┘    └─────┬──────┘
                          │  │                          │
              ┌───────────┘  └────────────┐             │ (render token only)
              │                            │            │
        ┌─────▼─────┐  ┌───────┐  ┌────────▼───────┐    │
        │ postgres  │  │ redis │  │ plugin-runtime │◄───┘  cms-api ⇄ plugin-runtime
        │  :5432    │  │ :6379 │  │  :4200 (sandbox)│      on an internal network
        └───────────┘  └───────┘  └────────────────┘      with no route out
              ▲            ▲
              └──── worker ┘   (background jobs: mail, media, scans)
```

## Services

| Service | Role | Holds credentials? | Trust |
| --- | --- | --- | --- |
| `cms-api` | The NestJS core. Auth, content, media, marketplace, plugin egress. | **Yes** — DB (owner + app roles), Redis, S3, signing pins. | First-party |
| `worker` | BullMQ jobs: mail delivery, media processing, package scans. | Yes — DB, Redis, S3. | First-party |
| `admin-web` | The Next.js admin UI. Talks to `cms-api` server-side. | No (one public value: `S3_PUBLIC_URL`). | First-party |
| `site-runtime` | The public Next.js site. **Renders theme code in-process.** | No — only a render token + public values. | Runs untrusted theme code |
| `plugin-runtime` | Executes marketplace plugins inside V8 isolates. | **No** — credential-free by design. | Runs untrusted plugin code |
| `migrate` | One-shot: apply migrations, register signed built-ins. | DB only, at deploy time. | First-party |

Backing services: **PostgreSQL** (system of record), **Redis** (cache, locks, rate
limiting, the BullMQ queue), **RustFS** (S3-compatible media storage;
swappable for AWS S3 / Cloudflare R2), **Mailpit** (captures outgoing mail in dev).

## The trust boundaries

**1. Themes and plugins never see your secrets.**
`site-runtime` renders a theme inside its own Node process — a theme is *not*
sandboxed. So it is never given the database, Redis or S3 credentials; it receives
only `SITE_RUNTIME_INTERNAL_TOKEN` (a render-only token that `cms-api` accepts on
read-only endpoints), the pinned public keys, and browser-facing values. Handing it
the full environment would turn a "theme escapes" bug into a full compromise.

**2. `plugin-runtime` has no way out.**
It runs on the `zcms-sandbox` Docker network, declared `internal: true` — Docker
gives that network no gateway. Nothing in that container can reach the internet or
your cloud's metadata endpoint (`169.254.169.254`), even if a plugin breaks out of
the V8 isolate. The only thing reachable is `cms-api`, which sits on both networks.
The container is also `read_only`, `cap_drop: ALL`, `no-new-privileges`, non-root.

**3. Postgres enforces tenant isolation at the database.**
Two roles are created on first boot (see
[`compose/postgres/init/01-app-role.sql`](../compose/postgres/init/01-app-role.sql)):
the **owner** role (`zcms`) runs migrations and cross-tenant control-plane reads; the
**app** role (`zcms_app`) owns nothing and is subject to Row-Level Security on every
query. `cms-api` runs tenant work as the app role, so even a query that forgot its
tenant filter cannot leak another tenant's rows. If the API ever connected as the
owner, isolation would silently vanish — which is why the two `DATABASE_URL` /
`APP_DATABASE_URL` values must stay distinct.

**4. Everything executable is signed.**
Built-in themes/plugins ship as signed `.zcms` packages verified against
`FIRST_PARTY_PUBLIC_KEY` before they load. Marketplace packages are verified against
`MARKETPLACE_PUBLIC_KEY`. Sideloaded files are verified against `OPERATOR_PUBLIC_KEY`.
The trust anchor is the *key*, not the hostname or the volume.

## Networks

- **`default`** — the ordinary bridge with a route to the internet. Every service
  except the plugin sandbox is here. `cms-api` needs it (marketplace calls; making a
  plugin's outbound request on its behalf, after checking the host).
- **`zcms-sandbox`** — `internal: true`, no gateway, no route. `plugin-runtime` lives
  here; `cms-api` joins it too so it remains the single reachable door.

## Media flow

Uploads are **proxied through `cms-api`** (it `PutObject`s to storage server-side) —
there is no browser-direct/presigned upload. Browsers only **read** media, by public
`GET` from `S3_PUBLIC_URL`. That is why the reverse proxy only needs to expose the
media path for reads, and why `S3_PUBLIC_URL` must be the browser-facing origin of
that path (it also becomes the `img-src` in the admin/site Content-Security-Policy).
