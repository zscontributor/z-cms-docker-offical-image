# Backup & restore

Three things hold state: **PostgreSQL** (all content, users, settings),
**object storage** (uploaded media), and your **`.env`** (the keys — some
irreplaceable). Back up all three.

> Commands below assume the base stack. Behind a proxy, add your `-f` flags, e.g.
> `docker compose -f docker-compose.yml -f compose/traefik.yml exec …`.

## `.env` — first and most important

`TOTP_ENCRYPTION_KEY` and `MAIL_ENCRYPTION_KEY` cannot be regenerated without data
loss, and `JWT_SECRET` losing it logs everyone out. Store `.env` in a secret
manager or an encrypted backup. **A database backup is useless without these keys.**

## Database

### Back up

```bash
# Plain SQL dump (portable, human-readable)
docker compose exec -T postgres pg_dump -U zcms zcms > zcms-$(date +%F).sql

# Or a compressed custom-format dump (faster restore, selective)
docker compose exec -T postgres pg_dump -U zcms -Fc zcms > zcms-$(date +%F).dump
```

Automate it with cron on the host:

```cron
0 3 * * *  cd /opt/zcms && docker compose exec -T postgres pg_dump -U zcms -Fc zcms > /backups/zcms-$(date +\%F).dump
```

### Restore

Restore into a **fresh** database (the init role must already exist — it's created
on first boot of an empty `postgres-data` volume).

```bash
# From a plain SQL dump
cat zcms-2026-07-27.sql | docker compose exec -T postgres psql -U zcms -d zcms

# From a custom-format dump
docker compose exec -T postgres pg_restore -U zcms -d zcms --clean --if-exists < zcms-2026-07-27.dump
```

After a restore, run the `migrate` job once (`docker compose up -d migrate` or just
`docker compose up -d`) so schema and built-in registrations match the image.

## Object storage (media)

The bundled RustFS keeps media in the `rustfs-data` volume. Back it up either at the
volume level or over S3.

```bash
# Volume-level snapshot (tar the named volume)
docker run --rm -v z-cms_rustfs-data:/data -v "$PWD":/backup alpine \
  tar czf /backup/rustfs-$(date +%F).tgz -C /data .

# Or sync the bucket with the AWS CLI (plain S3)
docker compose run --rm storage-init /bin/sh -c \
  'aws --endpoint-url http://rustfs:9000 s3 sync s3://zcms-media /backup'
```

Restore is the reverse: `tar xzf` back into the volume (while `rustfs` is stopped),
or `aws s3 sync` the other way. If you moved to a managed provider (S3/R2), use that
provider's backup/versioning instead — nothing here changes.

## Full disaster recovery

1. Provision a new host, install Docker, clone this repo.
2. Restore `.env` from your secret backup.
3. `docker compose up -d postgres` and wait for it to be healthy (creates the roles).
4. Restore the database dump (above).
5. Restore the `rustfs-data` volume (above), then `docker compose up -d`.
6. Verify: site loads, admin login works, a media thumbnail renders, 2FA still works.
