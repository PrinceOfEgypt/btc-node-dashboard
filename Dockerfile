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

RUN groupadd -r appgroup && useradd -r -g appgroup appuser
WORKDIR /app

COPY --from=builder --chown=appuser:appgroup /build/target/quarkus-app /app

USER appuser

EXPOSE 8080

ENV JAVA_OPTS="-XX:+UseG1GC \
    -XX:MaxGCPauseMillis=100 \
    -XX:+UseStringDeduplication \
    -XX:+ExitOnOutOfMemoryError \
    -XX:+UseContainerSupport \
    -Dfile.encoding=UTF-8 \
    -Djava.awt.headless=true"
ENTRYPOINT ["sh", "-c", "java $JAVA_OPTS -jar /app/quarkus-run.jar"]
