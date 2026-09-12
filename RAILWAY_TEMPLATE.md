# Railway template configuration

The published template. Reproduce it from this file if it ever has to be rebuilt.

| | |
|---|---|
| Name | wanderer |
| Code | `wanderer` |
| Template id | `ea86feb2-e300-4fec-836e-644673d0d25c` |
| Deploy URL | https://railway.com/deploy/wanderer |
| Overview markdown | `marketplace/OVERVIEW.md` (Railway enforces its section headings) |
| Category | Other |
| Image (public service) | `ghcr.io/youssefsiam38/wanderer-railway:<version>` |
| Icon | `assets/icon.png` |

## Services

### `wanderer` — public

| Field | Value |
|---|---|
| Source | `ghcr.io/youssefsiam38/wanderer-railway:<version>` |
| Port | 3000 |
| Domain | generated |
| Healthcheck | `/` |
| Volume | none |

| Variable | Value |
|---|---|
| `ORIGIN` | `https://${{RAILWAY_PUBLIC_DOMAIN}}` |
| `PUBLIC_POCKETBASE_URL` | `http://${{db.RAILWAY_PRIVATE_DOMAIN}}:8090` |
| `POCKETBASE_PROXY_SECRET` | `${{db.POCKETBASE_PROXY_SECRET}}` |
| `MEILI_URL` | `http://${{search.RAILWAY_PRIVATE_DOMAIN}}:7700` |
| `MEILI_MASTER_KEY` | `${{search.MEILI_MASTER_KEY}}` |
| `PUBLIC_DISABLE_SIGNUP` | `true` |
| `PUBLIC_PRIVATE_INSTANCE` | `true` |
| `BODY_SIZE_LIMIT` | `Infinity` |
| `WANDERER_OWNER_USERNAME` | `owner` |
| `WANDERER_OWNER_EMAIL` | `owner@example.com` |
| `WANDERER_OWNER_PASSWORD` | `${{secret(24)}}` |
| `APP_READY_TIMEOUT` | `300` |
| `PORT` | `3000` |
| `HOST` | `::` |

### `db` — private

| Field | Value |
|---|---|
| Source | `flomp/wanderer-db:v0.20.0` |
| Domain | none |
| Volume | `/pb_data` |
| Start command | `/pocketbase serve --http=[::]:8090 --dir=/pb_data` |

| Variable | Value |
|---|---|
| `MEILI_URL` | `http://${{search.RAILWAY_PRIVATE_DOMAIN}}:7700` |
| `MEILI_MASTER_KEY` | `${{search.MEILI_MASTER_KEY}}` |
| `POCKETBASE_ENCRYPTION_KEY` | `${{secret(32, "abcdefghijklmnopqrstuvwxyz0123456789")}}` |
| `POCKETBASE_PROXY_SECRET` | `${{secret(48)}}` |
| `ORIGIN` | `https://${{wanderer.RAILWAY_PUBLIC_DOMAIN}}` |

PocketBase requires the encryption key to be exactly 32 characters.

### `search` — private

| Field | Value |
|---|---|
| Source | `getmeili/meilisearch:v1.36.0` |
| Domain | none |
| Volume | `/meili_data` |

| Variable | Value |
|---|---|
| `MEILI_MASTER_KEY` | `${{secret(48)}}` |
| `MEILI_NO_ANALYTICS` | `true` |
| `MEILI_HTTP_ADDR` | `[::]:7700` |

## Notes

- **Every service listens on `::`.** Railway's private network is dual-stack and the images are not:
  PocketBase's image hard-codes `--http=0.0.0.0:8090`, so the template overrides its start command;
  Meilisearch takes `MEILI_HTTP_ADDR`; the wrapper passes `HOST` through to SvelteKit. The
  PocketBase image has no shell, and Railway execs a custom start command directly, so overriding it
  works there too.
- `PORT=3000` is set explicitly on `wanderer`. Without it Railway injects 8080 while the generated
  domain still points at 3000, and every request returns 502.
- `db`'s `ORIGIN` references the public service's domain. Set it after that domain exists: an empty
  reference yields the literal `https://`, which PocketBase rejects with
  `meta: (appURL: must be a valid URL.)` and then crash-loops.
- Every variable has a value or a generator, so `railway deploy -t wanderer` works without a TTY.
- Secrets are defined once on the service that owns them and referenced from the others, so all
  three services always agree.
- `db` and `search` get no domain. Exposing either defeats `PUBLIC_DISABLE_SIGNUP`; see
  [SECURITY.md](SECURITY.md).
- The image reference uses a version tag. Railway's template generator rejects `@sha256:` digests.
- One volume per service is a Railway limit, and services with volumes cannot be scaled to more
  than one replica.
