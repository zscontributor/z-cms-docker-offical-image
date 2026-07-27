# Z-CMS — Plugin sandbox

`zcms/plugin-runtime` is the **plugin sandbox** of [Z-CMS](https://github.com/zscontributor/z-cms), a multi-tenant CMS with a theme engine and a signed plugin marketplace.

> **Part of a stack.** This image runs alongside the other Z-CMS services — not on its own. Use the ready-made Compose stack below.

## Run the full stack

```bash
git clone https://github.com/zscontributor/z-cms-docker-offical-image.git zcms
cd zcms && cp .env.example .env && ./scripts/generate-secrets.sh --write
docker compose up -d && ./scripts/first-run-seed.sh
```

Reverse-proxy examples (Traefik, Caddy, Nginx, Apache, Portainer) and the full operator guide live in the **[z-cms-docker-offical-image](https://github.com/zscontributor/z-cms-docker-offical-image)** repository.

## This image

The only service that runs untrusted marketplace plugin code — inside V8 isolates, on port **4200**. Its own minimal, **credential-free** image: no database, Redis or S3 env. It runs `read_only`, `cap_drop: ALL`, non-root, on an `internal` Docker network with **no route off the host**, so escaped plugin code still cannot reach the internet or a cloud metadata endpoint. Built-in plugins ship signed inside the image and are verified against a pinned key before they run.

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
