# Deploy and Host wanderer on Railway

wanderer is a self-hosted trail database. Upload GPX, GeoJSON, TCX or KML tracks and get an
interactive map, distance and elevation profile, waypoints, photos, summit logs and comments.
Organise trails into lists, search everything, and optionally federate with other instances over
ActivityPub. This is a community-maintained template; it is not affiliated with the wanderer
project.

## About Hosting wanderer

wanderer is three pieces that have to agree with each other: a SvelteKit frontend, a PocketBase
database that also stores uploaded photos and GPX files, and a Meilisearch index that every listing
page depends on. The two stateful pieces each need their own persistent volume, and all three must
share the same Meilisearch key and proxy secret. Only the frontend is exposed to the internet; the
database and the search index stay on Railway's private network, which is what keeps the deployment
safe.

The other hosting problem is the first five minutes. A fresh wanderer instance has open registration
and no privileged first account, so whoever reaches the public URL first can claim the instance.
This template runs a wrapper image that creates your account inside the container before the public
listener accepts a single request, and ships with registration switched off. The generated password
is a Railway variable you can read in the dashboard, and you change it in the app afterwards.

## Why Deploy wanderer on Railway?

Railway is a singular platform to deploy your infrastructure stack. Railway will host your
infrastructure so you don't have to deal with configuration, while allowing you to vertically and
horizontally scale it.

By deploying wanderer on Railway, you are one step closer to supporting a complete full-stack
application with minimal burden. Host your servers, databases, AI agents, and more on Railway.

Concretely, this template wires the three services together, generates every secret, attaches both
volumes, points the frontend at its own public domain and creates your account, so there is nothing
to fill in before clicking deploy.

## Common Use Cases

- Keep a private, permanent record of hikes, rides and ski tours instead of a commercial fitness
  account that can change its terms.
- Plan routes on the map, save waypoints and share a single trail link with the people coming along.
- Run a small instance for a club or family, with accounts you create yourself.
- Federate with other wanderer instances to follow friends' public trails without a central service.

## Dependencies for wanderer Hosting

- A Meilisearch service for search and for resolving user profiles.
- A PocketBase service carrying wanderer's schema, with a volume for the database and uploads.
- A public frontend service with the instance's own HTTPS domain.

### Deployment Dependencies

- wanderer upstream project and documentation: https://github.com/Flomp/wanderer
- Template repository, wrapper image and tests: https://github.com/youssefsiam38/wanderer-railway
- Published image: `ghcr.io/youssefsiam38/wanderer-railway`
- wanderer is licensed AGPL-3.0-only. Running it as a network service makes you a distributor under
  section 13, so keep the corresponding source of the version you run available.

### Implementation Details

The wrapper adds no application code. It validates the variables wanderer silently misbehaves
without, refuses configurations that would lock you out or leave the instance open, waits for
PocketBase, creates the owner account, and then hands off to the upstream start command. Every
service binds a dual-stack listener so Railway's private network can reach it.
