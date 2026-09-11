# Architecture

## Service graph

```
                       internet
                          │  https
                          ▼
              ┌───────────────────────┐
              │  wanderer  (public)   │   ghcr.io/youssefsiam38/wanderer-railway
              │  SvelteKit, port 3000 │   wraps flomp/wanderer-web:v0.20.0
              └───────┬───────┬───────┘
        private net   │       │   private net
                      ▼       ▼
        ┌─────────────────┐  ┌──────────────────┐
        │  db  (private)  │  │ search (private) │
        │  PocketBase     │  │ Meilisearch      │
        │  :8090  /pb_data│  │ :7700 /meili_data│
        └────────┬────────┘  └──────────────────┘
                 └─── indexes trails/actors/lists ──┘
```

Only `wanderer` has a public domain. The browser talks to that origin and nothing else: every
database read, file download and search request is proxied by the SvelteKit server through
`/api/v1/*`. `PUBLIC_POCKETBASE_URL` is exposed to the page, but the client-side PocketBase object
is only used to read the session cookie — it makes no network calls. This is what lets `db` stay on
private networking.

## Why a wrapper image

wanderer's first run is open: anybody who reaches the URL before you do can register, and the first
account is not special. Railway deployments get a public domain the moment they start, so "deploy,
then race to the signup page" is not an acceptable first-run story.

`PUBLIC_DISABLE_SIGNUP=true` closes registration, but on an empty database that locks everyone out,
including the deployer. The wrapper resolves the deadlock:

1. Validate variables. Names only are printed, never values.
2. Refuse obviously wrong configurations, each with an explanation:
   - `ORIGIN` that is not an absolute `http(s)://` URL — wanderer silently rejects every write.
   - `MEILI_MASTER_KEY` equal to the example key published in upstream's `docker-compose.yml`.
   - `PUBLIC_DISABLE_SIGNUP=true` with no owner account configured.
   - Partially configured owner credentials (username without password, and so on).
3. Wait for PocketBase's `/health`.
4. Create the owner account through PocketBase's own users collection, using the password from
   `WANDERER_OWNER_PASSWORD`. Already exists? Log that and move on — the bootstrap is idempotent
   and never resets a password you changed in the app.
5. `exec` upstream's `docker-entrypoint.sh`, which starts the unmodified application.

The public listener therefore never accepts a request before the owner account exists, and
registration is closed from the very first request.

Application code is untouched. The image adds an entrypoint, a Node bootstrap script, the licence
files and OCI labels on top of the upstream image.

## Boot sequence on Railway

```
search  ──► healthy (Meilisearch)
   │
db      ──► PocketBase applies wanderer's migrations to /pb_data, registers with Meilisearch
   │
wanderer ─► entrypoint validates variables
            waits for db /health
            creates the owner account (first boot only)
            starts SvelteKit on 0.0.0.0:$PORT
            healthcheck GET / → 200
```

Railway starts all three at once; `wanderer` and `db` retry until their dependency answers, so the
order resolves itself. A cold start with empty volumes takes about 20 seconds locally.

## Data

| What | Where |
|---|---|
| users, trails, waypoints, lists, comments, ActivityPub actors | PocketBase SQLite in `/pb_data` |
| uploaded photos and GPX files | PocketBase file storage in `/pb_data` |
| search index for trails, lists and actors | Meilisearch in `/meili_data` |

`/meili_data` is derived state: wanderer re-indexes records as they change, and PocketBase pushes
the schema on start. `/pb_data` is the thing to back up.

Each Railway service gets one volume, which matches Railway's one-volume-per-service limit. Neither
stateful service can run with replicas.

## Health and readiness

The public service's healthcheck is `GET /` on port 3000. That route is served by SvelteKit only
after the server is listening, and the wrapper does not start the server until the bootstrap has
finished, so a passing healthcheck implies a usable instance.

`db` and `search` expose `/health` on their own ports; the compose file uses them for
`depends_on: service_healthy`. Railway has no cross-service dependency ordering, so the wrapper's
own wait loop is what enforces it there.
