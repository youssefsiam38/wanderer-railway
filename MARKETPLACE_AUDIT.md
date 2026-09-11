# Marketplace audit

Why this template was built, recorded at the time of publication.

## Gap

Searching the Railway marketplace for the obvious terms returned nothing that deploys a self-hosted
trail or GPS-track database:

| Query | Result |
|---|---|
| `wanderer` | no template deploying Flomp/wanderer |
| `trail`, `hiking`, `gpx`, `outdoor` | no match |
| `strava`, `fitness tracking` | no self-hosted track database |

The nearest neighbours are general-purpose CMS and storage templates, which do not cover GPX
parsing, elevation profiles, maps or ActivityPub federation.

## Why wanderer

- Actively maintained, tagged releases, official multi-arch images for both services.
- AGPL-3.0: redistributable as long as the source offer is preserved, which the template documents.
- Self-contained: SQLite through PocketBase plus Meilisearch, no external managed dependency.
- Fits Railway's model: one public HTTP service, two private services with one volume each.

## Why it needs a template rather than a raw image

- Three services that must agree on two shared secrets and two private URLs.
- Open registration on first boot, on a public URL, with no privileged first account.
- `ORIGIN` must be the public domain or every write silently fails — a footgun on a platform that
  assigns the domain at deploy time.
- `BODY_SIZE_LIMIT` must be raised or photo uploads fail.

The template answers all four without asking the deployer anything.

## Category

Other — the marketplace has no outdoors/personal-data category; the template is a self-hosted
personal database with a web UI.
