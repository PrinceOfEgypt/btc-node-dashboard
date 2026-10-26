# syntax=docker/dockerfile:1@sha256:4edf897a3ffa55b89f906fc8cc78afdb3f1834cc9c7083565e611a8a7d5fe99e
# ----------------------------------------------------------------------
# Stage 1: Builder - compile and create the Quarkus fast-jar archive
# ----------------------------------------------------------------------
FROM maven:3.10.0-eclipse-temurin-25@sha256:9b5f82b7166db6112eb123ba310a9e010ec3fe95022ac0728f491121563dfbab AS builder

WORKDIR /build

# Copy POM first for better layer caching
COPY pom.xml .

# Download Maven dependencies
RUN --mount=type=cache,target=/root/.m2 \
    mvn dependency:go-offline -B -ntp
# Copy source code
COPY src /build/src

# Build the app (Quinoa builds the frontend with npm during packaging).
# Tests are skipped to keep builds fast on the Pi; run them with `mvn verify`.
RUN --mount=type=cache,target=/root/.m2 \
    mvn package -DskipTests -DskipFrontendTests=true -B -ntp

# ----------------------------------------------------------------------
# Stage 2: Runner - execute the application
# ----------------------------------------------------------------------
FROM eclipse-temurin:25-jre AS runner

# Install curl and clean up apt cache to keep image small
RUN apt-get update && \
    apt-get install -y --no-install-recommends curl && \
    rm -rf /var/lib/apt/lists/*

RUN groupadd -r appgroup && useradd -r -g appgroup appuser
WORKDIR /app

COPY --from=builder --chown=appuser:appgroup /build/target/quarkus-app /app

USER appuser

# Health check using curl (port follows QUARKUS_HTTP_PORT, set to 8081 in compose.yml)
HEALTHCHECK --interval=30s --timeout=3s --start-period=20s --retries=3 \
  CMD curl -fsS "http://localhost:${QUARKUS_HTTP_PORT:-8080}/q/health" || exit 1

EXPOSE 8080

ENV QUARKUS_HTTP_HOST=0.0.0.0

# Advanced JVM tuning for production containers
# G1GC is optimal for containers with 1-4GB heap
# String deduplication saves significant memory for long-running services
# UseContainerSupport enables cgroup-aware memory detection
# JAVA_TOOL_OPTIONS is picked up by the JVM directly, so no shell wrapper is needed
ENV JAVA_TOOL_OPTIONS="\
    -XX:+UseG1GC \
    -XX:MaxGCPauseMillis=75 \
    -XX:InitiatingHeapOccupancyPercent=35 \
    -XX:G1HeapRegionSize=16m \
    -XX:+UseStringDeduplication \
    -XX:+UnlockDiagnosticVMOptions \
    -XX:G1SummarizeRSetStatsPeriod=86400 \
    -XX:+UseContainerSupport \
    -XX:+ExitOnOutOfMemoryError \
    -XX:+PerfDisableSharedMem \
    -Dfile.encoding=UTF-8 \
    -Djava.awt.headless=true \
    -Djava.util.logging.manager=org.jboss.logmanager.LogManager"

ENTRYPOINT ["java", "-jar", "/app/quarkus-run.jar"]
