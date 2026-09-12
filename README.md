# wanderer on Railway

Keep every hike, ride and ski tour in one place. **wanderer** is a self-hosted trail database:
upload GPX/GeoJSON/TCX/KML tracks, get distance, elevation profile and an interactive map, add
waypoints, photos, summit logs and comments, organise trails into lists, and search everything.
It speaks ActivityPub, so instances can follow each other. This repository is a
**community-maintained Railway template** for [wanderer](https://github.com/Flomp/wanderer). It is
**not affiliated with the wanderer project**.

<!-- DEPLOY_BUTTON_START -->
[![Deploy on Railway](https://railway.com/button.svg)](https://railway.com/deploy/wanderer)

Template page: https://railway.com/deploy/wanderer
<!-- DEPLOY_BUTTON_END -->

> **Licence.** wanderer is **AGPL-3.0**. This template deploys the upstream release unmodified.
> If you let other people use your deployment over a network you are a distributor under AGPL §13
> and must be able to offer them the corresponding source; see
> [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md), which links the exact upstream tag. The wrapper
> code in this repository is MIT.

## What you get

| Service | Source | Public | Volume |
|---|---|---|---|
| `wanderer` | `ghcr.io/youssefsiam38/wanderer-railway:<version>` wrapping `flomp/wanderer-web:v0.20.0` | yes, port 3000 | none |
| `db` | `flomp/wanderer-db:v0.20.0` (PocketBase + wanderer's schema) | no | `/pb_data` — database, uploaded photos and GPX files |
| `search` | `getmeili/meilisearch:v1.36.0` | no | `/meili_data` — search index |

| Component | Version |
|---|---|
| wanderer | v0.20.0 |
| Wrapper | v1.0.0 — `ghcr.io/youssefsiam38/wanderer-railway:1.0.0` ([releases](https://github.com/youssefsiam38/wanderer-railway/releases)) |

Why a wrapper and why three services: [ARCHITECTURE.md](ARCHITECTURE.md). In one sentence: wanderer
has open registration by default, so the wrapper creates your account in PocketBase **before** the
public frontend starts, which lets the template ship with registration switched off.

## First run

1. Click **Deploy on Railway**. Nothing has to be filled in: the Meilisearch key, the PocketBase
   encryption key, the proxy secret and your account password are all generated.
2. Open the `wanderer` service's public URL and sign in as `owner` with the value of the service
   variable `WANDERER_OWNER_PASSWORD` (Railway dashboard → `wanderer` → Variables → click to
   reveal). Change the password in the app under Settings → Account.
3. Upload a GPX file with **New Trail → Upload**, or draw a route on the map. Trails are private
   until you mark them public.
4. Optional: invite other people by setting `PUBLIC_DISABLE_SIGNUP=false` on the `wanderer` service,
   or keep registration closed and stay a single-user instance.
5. Optional: turn on federation (Settings → Profile) to follow people on other wanderer instances.

## Environment variables (`wanderer` service)

| Variable | Required | Set by template | Description |
|---|---|---|---|
| `ORIGIN` | yes | `https://${{RAILWAY_PUBLIC_DOMAIN}}` | Full public URL. wanderer rejects form posts from any other origin, so a wrong value breaks every write. |
| `PUBLIC_POCKETBASE_URL` | yes | `http://${{db.RAILWAY_PRIVATE_DOMAIN}}:8090` | Where the frontend reaches PocketBase. Private networking only; the browser never calls it. |
| `POCKETBASE_PROXY_SECRET` | yes | generated `${{secret(48)}}` | Shared secret between the frontend and PocketBase. Must match the `db` service. |
| `MEILI_URL` | yes | `http://${{search.RAILWAY_PRIVATE_DOMAIN}}:7700` | Meilisearch endpoint. |
| `MEILI_MASTER_KEY` | yes | generated `${{secret(48)}}` | Meilisearch API key. Must match the `search` service. The wrapper refuses to start with upstream's published example key. |
| `WANDERER_OWNER_USERNAME` | yes | `owner` | Wrapper: the account created on first start. |
| `WANDERER_OWNER_EMAIL` | yes | `owner@example.com` | Wrapper: that account's e-mail. Change it if you want password resets to work. |
| `WANDERER_OWNER_PASSWORD` | yes | generated `${{secret(24)}}` | Wrapper: that account's password. Ignored once the account exists, so changing it in the app is safe. |
| `PUBLIC_DISABLE_SIGNUP` | no | `true` | Closes registration. The wrapper refuses to start if this is `true` and no owner account is configured, which would lock everyone out. |
| `PUBLIC_PRIVATE_INSTANCE` | no | `true` | Requires a session for every page, including trail pages. Set `false` to publish trails to anonymous visitors. |
| `BODY_SIZE_LIMIT` | no | `Infinity` | SvelteKit upload limit. Photos and GPX archives exceed the default quickly. |
| `PUBLIC_OVERPASS_API_URL`, `PUBLIC_VALHALLA_URL` | no | unset | Optional third-party routing/POI services; see upstream docs. |
| `APP_READY_TIMEOUT` | no | `300` | Wrapper: seconds to wait for PocketBase before giving up. |
| `PORT` | no | `3000` | Port the frontend listens on. Must match the service's domain target port. |
| `HOST` | no | `::` | Listen address. `::` covers both IPv4 and IPv6 on Railway's network. |
| `SMTP_*` | no | unset | Outgoing mail for password resets and notifications. Without it, password reset does not work. |

The `db` service needs `MEILI_URL`, `MEILI_MASTER_KEY`, `POCKETBASE_ENCRYPTION_KEY`,
`POCKETBASE_PROXY_SECRET` and `ORIGIN`, plus a start command that binds PocketBase to `[::]`; the
`search` service needs `MEILI_MASTER_KEY` and `MEILI_HTTP_ADDR=[::]:7700`. The template wires all of
them; [RAILWAY_TEMPLATE.md](RAILWAY_TEMPLATE.md) has the exact values.

## Persistent paths

| Path | Service | Contents | Backup |
|---|---|---|---|
| `/pb_data` | `db` | SQLite database, uploaded photos, GPX files | `railway volume files download` |
| `/meili_data` | `search` | search index (rebuildable from `/pb_data`) | not required |

## Local development

```bash
docker compose build
docker compose up -d
```

Then open http://localhost:3000 and sign in as `owner`. The compose file uses obvious
local-test-only secrets; do not reuse them anywhere.

Tests:

```bash
tests/static.sh       # syntax, shellcheck, pinning, no tracked secrets
tests/smoke.sh        # cold start, first-run safety, full trail workflow, fail-fast checks
tests/persistence.sh  # state survives recreating every container
tests/railway-smoke.sh https://your-app.up.railway.app   # against a deployment
```

## Documentation

| File | Contents |
|---|---|
| [ARCHITECTURE.md](ARCHITECTURE.md) | service graph, why the wrapper exists, boot sequence |
| [RAILWAY_TEMPLATE.md](RAILWAY_TEMPLATE.md) | exact template configuration |
| [SECURITY.md](SECURITY.md) | threat model, what is exposed, reporting |
| [UPSTREAM.md](UPSTREAM.md) | upstream provenance and how to bump it |
| [MAINTENANCE.md](MAINTENANCE.md) | release process and update checklist |
| [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md) | licences of everything shipped |
| [MARKETPLACE_AUDIT.md](MARKETPLACE_AUDIT.md) | why this template was built |

## Licence

Wrapper code in this repository: MIT ([LICENSE](LICENSE)). The application it deploys is AGPL-3.0
and stays under its own licence; see [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md).
