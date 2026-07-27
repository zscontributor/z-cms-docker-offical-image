# Z-CMS — Database migration & seed job

`zcms/migrate` is the **database migration and built-in registration job** for [Z-CMS](https://github.com/zscontributor/z-cms), a multi-tenant CMS with a theme engine and a signed plugin marketplace.

> **Part of a stack.** This is a one-shot job image, run by the Compose stack — not a long-running service. Use the ready-made stack below.

## Run the full stack

```bash
git clone https://github.com/zscontributor/z-cms-docker-offical-image.git zcms
cd zcms && cp .env.example .env && ./scripts/generate-secrets.sh --write
docker compose up -d && ./scripts/first-run-seed.sh
```

Reverse-proxy examples (Traefik, Caddy, Nginx, Apache, Portainer) and the full operator guide live in the **[z-cms-docker-offical-image](https://github.com/zscontributor/z-cms-docker-offical-image)** repository.

## This image

A one-shot job that applies pending database migrations and registers the signed built-in themes and plugins shipped in the release. Every app service waits for it to finish, and it runs (idempotently) on each `up`. It also carries the toolchain used for the one-time first-run seed (`first-run-seed.sh`), which creates the first admin user and a demo site.

## Tags

- `X.Y.Z` — an exact, immutable release (pin this in production)
- `X.Y` — the latest patch on that minor line
- `latest` — the newest release

All tags are multi-arch: **`linux/amd64` + `linux/arm64`**.

## Links

- 📦 Deploy: [z-cms-docker-offical-image](https://github.com/zscontributor/z-cms-docker-offical-image)
- 📖 Docs: [docs.z-cms.org](https://docs.z-cms.org)
- 💻 Source: [github.com/zscontributor/z-cms](https://github.com/zscontributor/z-cms)
- 🧩 Marketplace: [marketplace.z-cms.org](https://marketplace.z-cms.org)

Licensed under MIT · © Z-SOFT Co., Ltd.
