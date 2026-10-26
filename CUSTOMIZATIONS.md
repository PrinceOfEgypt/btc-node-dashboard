# Customizations

This fork intentionally differs from upstream `comassky/btc-node-dashboard` in a few places to fit a local Bitcoin node deployment.

## Current Differences

### `compose.yml`

- Builds the image locally from `Dockerfile` instead of pulling `ghcr.io/comassky/btc-node-dashboard:main`
- Uses `network_mode: host`
- Renames the service/container to `btc-node-dashboard`
- Disables Watchtower updates for this container with:
  - `com.centurylinklabs.watchtower.enable=false`
- Uses environment variables for runtime configuration
- Defaults Quarkus to:
  - `QUARKUS_HTTP_HOST=0.0.0.0`
  - `QUARKUS_HTTP_PORT=8081`
- Reads Bitcoin RPC credentials from local `.env`
- Enables `restart: always`

### `Dockerfile`

- Uses non-Alpine base images:
  - `maven:3-eclipse-temurin-25`
  - `eclipse-temurin:25-jre`
- Removes Maven wrapper / `.mvn` copy steps
- Builds directly with Maven in the container
- Builds with `mvn package -DskipTests -DskipFrontendTests=true` (upstream runs `mvn verify`) to keep Pi builds fast
- Keeps the Quarkus fast-jar runtime layout
- Uses `eclipse-temurin:25-jre` instead of upstream's distroless runtime, so `curl` is available for the healthcheck
- `HEALTHCHECK` hits `/q/health` on `${QUARKUS_HTTP_PORT}` (8081 here), not a hardcoded 8080
- Keeps the local G1GC tuning flags, passed via `JAVA_TOOL_OPTIONS` (upstream style) with a plain `java -jar` entrypoint

### `pom.xml`

- Adds `quarkus-smallrye-health` so `/q/health` exists for the Docker healthcheck

Upstream 2.0 replaced `frontend-maven-plugin`/pnpm with Quarkus Quinoa/npm, so the old
local removal of the pnpm `sync version` step is no longer needed. The frontend is now
built by Quinoa (which downloads its own Node into `.quinoa/`) and the app version is passed
to Vite via `APP_VERSION`.

### `.gitignore`

- Keeps `.env` ignored
- Explicitly allows `.env.example` to be committed

### `.env.example`

- Adds a safe template for:
  - Quarkus host/port
  - Bitcoin RPC host/port
  - Bitcoin RPC username/password placeholder
  - RPC scheme
  - Polling / dashboard tuning values
  - Log level

## Why These Exist

- Host networking simplified access to the local Bitcoin node
- Port `8080` was already occupied on the target host, so the dashboard moved to `8081`
- RPC credentials should stay in local `.env`, not tracked files
- Local builds are preferred over the upstream prebuilt image for this deployment

## Updating From Upstream

When pulling upstream changes, pay closest attention to merge conflicts in:

- `compose.yml`
- `Dockerfile`
- `pom.xml` (only the added health dependency; otherwise track upstream)

These are the files with intentional local divergence.
