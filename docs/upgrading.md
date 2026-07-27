# Upgrading

Z-CMS images are versioned. Upgrading is: point `ZCMS_VERSION` at the new tag, pull,
and bring the stack back up. The one-shot `migrate` job runs first and applies any
new database migrations and built-in package registrations automatically.

## Standard upgrade

```bash
# 1. Back up first (see backup-restore.md) — always.
docker compose exec -T postgres pg_dump -U zcms -Fc zcms > pre-upgrade.dump

# 2. Pin the new version in .env
#    ZCMS_VERSION=0.2.0

# 3. Pull and restart. `migrate` runs before the app services come up.
docker compose pull
docker compose up -d
```

Behind a proxy, keep your `-f` flags on both commands:

```bash
docker compose -f docker-compose.yml -f compose/traefik.yml pull
docker compose -f docker-compose.yml -f compose/traefik.yml up -d
```

## Version pinning

- **Production:** pin an exact release (`ZCMS_VERSION=0.2.0`). Reproducible, and you
  can roll back to the previous tag.
- **`latest`:** always the newest release. Fine for a lab; risky for production
  because a `pull` can move you forward unexpectedly.
- Migrations only ever move **forward**. To roll back the code you must also restore
  a database backup taken before the upgrade — schema changes are not auto-reverted.

## Rollback

```bash
# Set ZCMS_VERSION back to the previous tag, then:
docker compose pull && docker compose up -d
# If the newer version applied migrations, also restore the pre-upgrade dump:
docker compose exec -T postgres pg_restore -U zcms -d zcms --clean --if-exists < pre-upgrade.dump
```

## Zero-ish downtime

The default compose does a rolling `up -d` (recreates changed containers). For a
brief window the site may 502 while `site-runtime`/`admin-web` restart. For true
zero-downtime you'd run multiple replicas behind the proxy (an orchestrator concern
beyond this repo). For most single-host deployments the few-seconds restart is fine —
schedule upgrades off-peak.

## After upgrading

- Check `docker compose ps` — every service `healthy`/`running`, `migrate` `exited
  (0)`.
- Check `docker compose logs migrate` — migrations applied cleanly.
- Smoke test: site loads, admin login, a media thumbnail, one content edit.
- Read the source repo's release notes for anything version-specific (new env vars,
  breaking changes): <https://github.com/zscontributor/z-cms/releases>.
