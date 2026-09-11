# Maintenance

## Release process

1. Update the pinned upstream image (see [UPSTREAM.md](UPSTREAM.md)) or the wrapper scripts.
2. Run the full local suite:
   ```bash
   tests/static.sh && docker compose build && tests/smoke.sh && tests/persistence.sh
   ```
3. Commit on `main`. CI (`test.yml`) runs the same suite on every push and pull request.
4. Tag and push:
   ```bash
   git tag -a vX.Y.Z -m "wanderer-railway vX.Y.Z" && git push origin vX.Y.Z
   ```
   `publish-image.yml` builds an amd64 candidate, runs the suite against **that** image, and only
   then pushes the multi-arch image to `ghcr.io/youssefsiam38/wanderer-railway:X.Y.Z`.
5. Note the digest from the workflow summary.
6. Point the template at the new tag:
   ```bash
   railway templates update --code wanderer
   ```
   or patch the service image through the template editor. Railway's template generator rejects
   `@sha256:` references, so templates use the version tag; the tag is immutable in practice
   because releases never re-push an existing tag.
7. Write release notes recording the wrapper version, the upstream version and the image digest.

## What to watch

| Thing | Where | Why |
|---|---|---|
| wanderer releases | https://github.com/Flomp/wanderer/releases | schema migrations, new required variables |
| Meilisearch major versions | https://github.com/meilisearch/meilisearch/releases | index format changes need a re-index |
| PocketBase inside `flomp/wanderer-db` | upstream release notes | upstream handles migrations; verify `/pb_data` still opens |
| Railway template deploys | Railway dashboard | deploy failures show up as template health |

## Breaking-change checklist

Before releasing an upstream bump:

- [ ] Does the release add a required environment variable? Add it to the template with a default.
- [ ] Does it change the PocketBase schema? Deploy the template from scratch **and** on top of an
      existing `/pb_data` volume.
- [ ] Does it change the Meilisearch version requirement? Update `compose.yaml` and the template.
- [ ] Does signup or first-run behaviour change? Re-verify the bootstrap and the fail-fast checks.
- [ ] `tests/railway-smoke.sh` green against a staging deploy, including the persistence run with
      `STATE_OUT` / `STATE_IN` across a redeploy.

## Rolling back

Templates pin a version tag, so a bad release is undone by pointing the template back at the
previous tag and redeploying. Data lives in the two volumes and is untouched by an image rollback,
provided the newer version did not migrate the PocketBase schema forward.

## If this repository is abandoned

The template is a thin wrapper: fork it, change the GHCR path in the workflow and the template, and
publish your own. Nothing here depends on this account.
