# ----------------------------------------------------------------------
# Stage 1: Builder - compile and create the Quarkus fast-jar archive
# ----------------------------------------------------------------------
FROM maven:3-eclipse-temurin-25 AS builder

WORKDIR /build

# Copy POM first for better layer caching
COPY pom.xml .

# Download Maven dependencies
RUN --mount=type=cache,target=/root/.m2 \
    mvn dependency:go-offline -B -ntp
# Copy source code
COPY src /build/src

# Build the app
RUN --mount=type=cache,target=/root/.m2 \
    mvn package -DskipTests -B -ntp

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

# Health check using curl
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD curl -f http://localhost:8080/q/health || exit 1

EXPOSE 8080

# Advanced JVM tuning for production containers
# G1GC is optimal for containers with 1-4GB heap
# String deduplication saves significant memory for long-running services
# UseContainerSupport enables cgroup-aware memory detection
# TieredCompilation balances startup time with long-term performance
ENV JAVA_OPTS="\
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

ENTRYPOINT ["sh", "-c", "java $JAVA_OPTS -jar /app/quarkus-run.jar"]
