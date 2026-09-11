# Third-party notices

This template deploys software written by other people. Their licences apply to what runs; the
wrapper code in this repository is MIT.

## Shipped inside the wrapper image

| Component | Version | Licence | Source |
|---|---|---|---|
| wanderer (frontend) | v0.20.0 | AGPL-3.0-only | https://github.com/Flomp/wanderer/tree/v0.20.0 |

The full AGPL-3.0 text is in [`licenses/WANDERER-LICENSE`](licenses/WANDERER-LICENSE) and inside the
image at `/usr/share/licenses/wanderer-railway/WANDERER-LICENSE`.

wanderer's frontend bundles its own npm dependencies (SvelteKit, MapLibre, the PocketBase JS SDK
and others) under their respective licences; they are unchanged from the upstream image and their
notices ship with it.

## Deployed alongside, as their own services

| Component | Version | Licence | Source |
|---|---|---|---|
| wanderer database image (PocketBase + wanderer schema) | v0.20.0 | AGPL-3.0-only | https://github.com/Flomp/wanderer/tree/v0.20.0 |
| PocketBase | as bundled by upstream | MIT | https://github.com/pocketbase/pocketbase |
| Meilisearch | v1.36.0 | MIT | https://github.com/meilisearch/meilisearch |

These images are pulled from their publishers at deploy time and are not redistributed by this
repository.

## AGPL §13

If other people use your deployment over a network, you must be able to offer them the
corresponding source of the version you run. The exact upstream tag is recorded above, in the image
label `io.wanderer-railway.upstream.version`, and in [UPSTREAM.md](UPSTREAM.md).

## This repository

MIT — see [LICENSE](LICENSE). It contains no upstream source code.
