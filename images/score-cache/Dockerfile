# ── Stage: nexus application files ────────────────────────────────────────────
FROM sonatype/nexus3:3.76.0 AS nexus-src

# ── Stage: bazel-remote binary (distroless, binary at /bazel-remote) ──────────
FROM buchgr/bazel-remote-cache:v2.4.4 AS bazel-remote-src

# ── Final single-container image ───────────────────────────────────────────────
FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive
# Nexus environment — must match the official image paths and variables exactly
ENV SONATYPE_DIR=/opt/sonatype
ENV NEXUS_HOME=/opt/sonatype/nexus
ENV NEXUS_DATA=/nexus-data
ENV NEXUS_CONTEXT=
ENV SONATYPE_WORK=/opt/sonatype/sonatype-work
ENV DOCKER_TYPE=rh-docker
ENV INSTALL4J_ADD_VM_PARAMS="-Xms1024m -Xmx1024m -XX:MaxDirectMemorySize=2703m \
    -Djava.util.prefs.userRoot=/nexus-data/javaprefs"
# bazel-remote
ENV BAZEL_REMOTE_MAX_SIZE_GB=10

# Install system packages.
# ca-certificates-java creates /etc/ssl/certs/java/cacerts (required by Nexus);
# update-ca-certificates must be called explicitly in Docker builds.
RUN apt-get update -qq && \
    apt-get install -y --no-install-recommends \
        nginx \
        openjdk-17-jre-headless \
        ca-certificates-java \
        supervisor \
        curl \
        ca-certificates \
        netcat-openbsd && \
    update-ca-certificates && \
    rm -rf /var/lib/apt/lists/* && \
    rm -f /etc/nginx/sites-enabled/default /etc/nginx/conf.d/default.conf && \
    mkdir -p /var/log/supervisor /var/cache/bazel-remote

# Create nexus user matching the official image (uid 200 / gid 200)
RUN groupadd -g 200 nexus && \
    useradd -r -u 200 -g nexus -d /nexus-data -s /bin/false nexus && \
    mkdir -p /nexus-data/etc && chown -R nexus:nexus /nexus-data

# Pre-configure nexus: disable setup wizard so the REST API works on first boot
# without requiring the web UI onboarding flow.
RUN printf 'nexus.onboarding.enabled=false\n' > /nexus-data/etc/nexus.properties && \
    chown nexus:nexus /nexus-data/etc/nexus.properties

# Copy Nexus application from official image.
# The official image has /opt/sonatype/sonatype-work/nexus3 → /nexus-data (symlink).
COPY --from=nexus-src --chown=nexus:nexus /opt/sonatype /opt/sonatype
RUN chown -R nexus:nexus /nexus-data /opt/sonatype

# Copy bazel-remote static binary from distroless image
COPY --from=bazel-remote-src /bazel-remote /usr/local/bin/bazel-remote
RUN chmod +x /usr/local/bin/bazel-remote

# Configure nginx
COPY nginx/nginx.conf /etc/nginx/nginx.conf
COPY nginx/conf.d/  /etc/nginx/conf.d/

# Configure supervisor
COPY supervisor/supervisord.conf /etc/supervisor/supervisord.conf
COPY supervisor/conf.d/          /etc/supervisor/conf.d/

# Operational scripts
COPY scripts/       /opt/score-cache/
COPY nexus/configure.sh /opt/score-cache/configure.sh
RUN chmod +x /opt/score-cache/*.sh

# Persistent data volumes
VOLUME ["/nexus-data", "/var/cache/bazel-remote"]

# nginx HTTP  |  nginx gRPC proxy for bazel-remote REAPI
EXPOSE 80 9093

CMD ["/usr/bin/supervisord", "-n", "-c", "/etc/supervisor/supervisord.conf"]
