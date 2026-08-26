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
- Keeps the Quarkus fast-jar runtime layout

### `pom.xml`

- Removes the `sync version` `pnpm` execution from the `prepare-package` phase

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
- `pom.xml`

These are the files with intentional local divergence.
