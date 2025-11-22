<!--
Guidance for AI coding assistants working on the Synology Container repository.
Keep this file short, concrete, and focused on repository-specific patterns.
-->
# Copilot / AI Assistant Instructions — synology-containers

Goal: help contributors add or modify container stacks while preserving repository conventions.

- Big picture
  - This repo collects per-service Docker Compose files under `stacks/` and a master `stacks/compose.yaml` that "extends" each service file. Look at `stacks/compose.yaml` for the canonical service order and network definitions.
  - Deployment is primarily Docker Compose (or Portainer). Networking relies on named bridge networks and a macvlan for LAN-exposed services (macvlan is created via the `adguard` stack).

- Key files to reference when making changes
  - `readme.md` — stack deploy order and network table (use this to determine startup ordering).
  - `stacks/compose.yaml` — the consolidated compose file which references per-stack files using `extends: file: <dir>/docker-compose.yaml` and `service: <name>`; modify only when you need to include a new stack in the full composition.
  - `stacks/*/docker-compose.yaml` — per-service compose fragments (edit these when changing a single service).
  - `stacks/traefik/docker-compose.yaml` — example of router labels, env var usage, external networks, and pinned image digests.

- Project-specific conventions (follow these exactly)
  - Images are typically pinned to a digest (e.g. `image: ghcr.io/…@sha256:...`). Keep that practice when updating images unless intentionally switching to a different tag.
  - Environment variables follow the pattern `${VAR:-default}` and common variables include `PUID`, `PGID`, `TZ`, `BASE_PATH`, and `DOMAIN`. When adding new secrets (tokens, API keys), follow the same inline `${VAR:?message}` pattern where appropriate.
  - Volumes are placed under `${BASE_PATH:-/volume2/docker/}`; prefer that variable rather than hardcoding `/volume2/docker/`.
  - Networks: many stacks use `external: true` networks (e.g. `frontend`, `macvlan`). Don't modify an external network here — change the defining stack (see `readme.md` and `adguard`/`portainer`).
  - Service health ordering: the master `stacks/compose.yaml` uses `depends_on` with `condition: service_healthy`; prefer adding healthchecks in the service fragment if a dependent service must wait to start.

- How to add a new service (example workflow)
  1. Create `stacks/<service>/docker-compose.yaml` with the service definition, healthcheck, and a stable image digest.
  2. Add a `volumes:` entry if persistent storage is required, using `${BASE_PATH}` for paths.
  3. Wire networks using existing network names (or add a new network only when necessary). If the service must be part of the full stack, add an `extends:` entry to `stacks/compose.yaml` referencing the new file and service name.
  4. Test locally with `docker compose -f stacks/compose.yaml up -d <service>` or deploy via Portainer in the order defined in `readme.md`.

- Common pitfalls to avoid
  - Do not assume `frontend` or `macvlan` exist — they may be external and created by other stacks (`portainer`, `adguard`). Check `readme.md` and the defining stack.
  - When changing `traefik` labels or middleware, mirror the pattern used in `stacks/traefik/docker-compose.yaml` (routers, services, and `authentik@docker` middleware are used here).
  - Respect pinned digests to avoid accidental upgrades; if updating digests, include the reason in the commit message.

- Example snippets to reference
  - Extending a service into the consolidated compose (see `stacks/compose.yaml`):
    - extends:
        file: <stack>/docker-compose.yaml
        service: <service-name>

- Helpful commands (developer workflows)
  - Start the full consolidated stack (use on a machine with proper networks defined):
```
docker compose -f stacks/compose.yaml up -d
```
  - Start or test a single service (fast feedback):
```
docker compose -f stacks/<service>/docker-compose.yaml up -d
```

If anything here is unclear or you want the instructions to tie into a different workflow (for example, Portainer-only edits or CI-driven deploys), tell me which workflow to prioritize and I will iterate. 
