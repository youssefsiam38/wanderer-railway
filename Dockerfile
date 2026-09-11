# syntax=docker/dockerfile:1
#
# wanderer-railway: thin wrapper around the official wanderer frontend image.
# It creates the deployer's account in PocketBase before the public frontend starts, so the
# template can ship with registration disabled, and it validates the variables that wanderer
# silently misbehaves without (ORIGIN, MEILI_MASTER_KEY). Application code is unchanged.
#
# Base image is pinned by tag AND digest. Update WANDERER_IMAGE and WANDERER_VERSION together.
ARG WANDERER_IMAGE=docker.io/flomp/wanderer-web:v0.20.0@sha256:d76177573caab135e8167179c9954168b5c582a48cbef0fcb7e1571af0c84d98

FROM ${WANDERER_IMAGE}

ARG WANDERER_VERSION=0.20.0
ARG WRAPPER_VERSION=0.0.0-dev
ARG VCS_REF=unknown
ARG BUILD_DATE=1970-01-01T00:00:00Z

COPY licenses/ /usr/share/licenses/wanderer-railway/
COPY --chmod=0755 scripts/entrypoint.sh /usr/local/bin/wanderer-railway-entrypoint
COPY scripts/bootstrap-owner.mjs /usr/local/lib/wanderer-railway/bootstrap-owner.mjs
RUN chmod 755 /usr/local/lib/wanderer-railway && chmod 644 /usr/local/lib/wanderer-railway/bootstrap-owner.mjs \
    && node --check /usr/local/lib/wanderer-railway/bootstrap-owner.mjs

ENV HOST=0.0.0.0

LABEL org.opencontainers.image.title="wanderer-railway" \
      org.opencontainers.image.description="Community Railway wrapper for wanderer, the self-hosted trail database. Not affiliated with the wanderer project." \
      org.opencontainers.image.source="https://github.com/youssefsiam38/wanderer-railway" \
      org.opencontainers.image.url="https://github.com/youssefsiam38/wanderer-railway" \
      org.opencontainers.image.documentation="https://github.com/youssefsiam38/wanderer-railway#readme" \
      org.opencontainers.image.licenses="AGPL-3.0-only" \
      org.opencontainers.image.version="${WRAPPER_VERSION}" \
      org.opencontainers.image.revision="${VCS_REF}" \
      org.opencontainers.image.created="${BUILD_DATE}" \
      org.opencontainers.image.base.name="docker.io/flomp/wanderer-web:v${WANDERER_VERSION}" \
      io.wanderer-railway.upstream.version="${WANDERER_VERSION}"

EXPOSE 3000

ENTRYPOINT ["/usr/local/bin/wanderer-railway-entrypoint"]
CMD ["npm", "run", "start"]
