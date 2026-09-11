# Upstream provenance

## wanderer

| | |
|---|---|
| Project | [wanderer](https://github.com/Flomp/wanderer) |
| Version deployed | v0.20.0 |
| Licence | AGPL-3.0-only |
| Frontend image | `docker.io/flomp/wanderer-web:v0.20.0` |
| Frontend digest | `sha256:d76177573caab135e8167179c9954168b5c582a48cbef0fcb7e1571af0c84d98` |
| Database image | `docker.io/flomp/wanderer-db:v0.20.0` |
| Source for the tag | https://github.com/Flomp/wanderer/tree/v0.20.0 |

Both images are published by the upstream project. This template does not rebuild them.

## What this repository changes

Nothing in the application. The wrapper image is `FROM flomp/wanderer-web` plus:

| Added | Path | Why |
|---|---|---|
| entrypoint | `/usr/local/bin/wanderer-railway-entrypoint` | variable validation, PocketBase wait, owner bootstrap, then `exec docker-entrypoint.sh` |
| bootstrap | `/usr/local/lib/wanderer-railway/bootstrap-owner.mjs` | creates the owner account through PocketBase's REST API |
| licences | `/usr/share/licenses/wanderer-railway/` | AGPL text shipped with the binary |
| `HOST=0.0.0.0` | env | Railway needs the server bound to all interfaces |
| OCI labels | image metadata | source, revision, version, upstream version, licence |

No patches, no forks, no rebuilt assets.

## AGPL obligations

wanderer is AGPL-3.0-only. Running it as a network service makes you a distributor under §13:
anyone who uses your instance is entitled to the corresponding source of the version you run. The
version is recorded in the image label `io.wanderer-railway.upstream.version` and in the tag above,
so pointing users at the matching upstream tag satisfies it. The wrapper's own code is MIT and is
published in this repository.

## Bumping the upstream version

1. Find the new tag on https://github.com/Flomp/wanderer/releases and read it for schema or
   variable changes.
2. Resolve the new digest:
   ```bash
   docker buildx imagetools inspect flomp/wanderer-web:vX.Y.Z --format '{{.Manifest.Digest}}'
   ```
3. Update `WANDERER_IMAGE`, `WANDERER_VERSION` in `Dockerfile` and the `flomp/wanderer-db` tag in
   `compose.yaml`, plus the version tables in `README.md` and this file.
4. `tests/static.sh && tests/smoke.sh && tests/persistence.sh`.
5. Follow [MAINTENANCE.md](MAINTENANCE.md) to release and to update the template image.

Meilisearch is pinned separately (`getmeili/meilisearch:v1.36.0`); upstream's compose tracks it, so
check which version the new wanderer release expects before changing it.
