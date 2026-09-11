# Security

## Reporting

Problems in **this wrapper** (entrypoint, bootstrap, template configuration): open an issue at
https://github.com/youssefsiam38/wanderer-railway/issues. If the problem is exploitable, use
GitHub's private vulnerability reporting on that repository instead of a public issue.

Problems in **wanderer itself**: report upstream at https://github.com/Flomp/wanderer/security.

## What the template exposes

| Service | Reachable from | Notes |
|---|---|---|
| `wanderer` | the internet, HTTPS | the only public service |
| `db` (PocketBase) | Railway private network | **keep it private** |
| `search` (Meilisearch) | Railway private network | **keep it private** |

PocketBase's users collection accepts unauthenticated record creation — that is how wanderer's own
signup works. Closing registration in the frontend does not close that API. If you give the `db`
service a public domain, anyone can create an account regardless of `PUBLIC_DISABLE_SIGNUP`. Do not
expose `db` or `search`.

## First-run account claim

A fresh wanderer instance has open registration and no privileged first account. The wrapper closes
this window by creating your account inside the container before the public listener starts, and
the template ships with `PUBLIC_DISABLE_SIGNUP=true`. The wrapper refuses to start if registration
is disabled and no owner account is configured, because that combination is unrecoverable through
the UI.

Change the generated password in the app after the first sign-in. The bootstrap is idempotent: once
the account exists it never touches it again, so `WANDERER_OWNER_PASSWORD` becomes a stale variable
that is read but not applied.

## Secrets

- `MEILI_MASTER_KEY`, `POCKETBASE_ENCRYPTION_KEY`, `POCKETBASE_PROXY_SECRET` and
  `WANDERER_OWNER_PASSWORD` are generated per deployment by the template.
- The wrapper prints variable **names**, lengths and pass/fail results — never values. The test
  suite asserts that none of the configured secrets appear in container logs.
- The wrapper refuses to start with the `MEILI_MASTER_KEY` published in upstream's example
  `docker-compose.yml`, which is otherwise an easy copy-paste mistake.
- Rotating `POCKETBASE_ENCRYPTION_KEY` after first boot makes existing encrypted PocketBase
  settings unreadable. Rotating `MEILI_MASTER_KEY` requires updating all three services together.
- The values in `compose.yaml` are labelled local-test-only and exist so the suite can assert they
  never appear in logs. They are not secrets and must not be reused.

## Transport

Railway terminates TLS at the edge and forwards over the private network. PocketBase and
Meilisearch speak plain HTTP inside that network, which is why they must not be exposed publicly.
`ORIGIN` must be the `https://` public URL; wanderer compares it against the `Origin` header and
rejects mismatched writes.

## Third-party calls made by the application

- Default user avatars are rendered by `api.dicebear.com` (upstream behaviour, requests come from
  the browser).
- Map tiles, geocoding, routing and POI lookups go to whatever providers upstream is configured
  with (`PUBLIC_OVERPASS_API_URL`, `PUBLIC_VALHALLA_URL` and upstream's tile defaults).

## Updates

The base image is pinned by tag **and** digest; the workflow publishes multi-arch images and the
release notes record the digest. See [MAINTENANCE.md](MAINTENANCE.md).
