#!/usr/bin/env bash
# configure.sh — Provision Nexus proxy repositories for score-cache.
#
# Waits for Nexus to be ready, then creates:
#   • cargo-proxy   — Rust crates.io proxy
#   • pypi-proxy    — Python PyPI proxy
#   • oci-proxy     — Docker Hub / OCI registry proxy
#   • rules-proxy   — Raw HTTP proxy for Bazel rule archives
#
# Environment variables (all optional, defaults shown):
#   NEXUS_URL      http://localhost:8081
#   NEXUS_USER     admin
#   NEXUS_PASS     admin123   (Nexus default; change in production)
#
# Usage:
#   bash nexus/configure.sh
#   NEXUS_URL=http://nexus:8081 bash nexus/configure.sh

set -euo pipefail

NEXUS_URL="${NEXUS_URL:-http://localhost:8081}"
NEXUS_USER="${NEXUS_USER:-admin}"
NEXUS_PASS="${NEXUS_PASS:-admin123}"
MAX_WAIT="${MAX_WAIT:-180}"

# ── Helpers ───────────────────────────────────────────────────────────────────

info()  { echo "[INFO]  $*"; }
ok()    { echo "[OK]    $*"; }
err()   { echo "[ERROR] $*" >&2; exit 1; }

nexus_api() {
    local method="$1" path="$2"
    shift 2
    curl -sf -u "${NEXUS_USER}:${NEXUS_PASS}" \
         -X "${method}" \
         -H "Content-Type: application/json" \
         "${NEXUS_URL}/service/rest/${path}" \
         "$@"
}

repo_exists() {
    nexus_api GET "v1/repositories" | grep -q "\"name\":\"${1}\""
}

# ── Wait for Nexus ────────────────────────────────────────────────────────────

info "Waiting for Nexus at ${NEXUS_URL} …"
elapsed=0
until curl -sf "${NEXUS_URL}/service/rest/v1/status" > /dev/null 2>&1; do
    sleep 5
    elapsed=$((elapsed + 5))
    [ "${elapsed}" -ge "${MAX_WAIT}" ] && err "Nexus did not become ready within ${MAX_WAIT}s"
done
ok "Nexus is ready"

# ── Cargo proxy ───────────────────────────────────────────────────────────────

if repo_exists "cargo-proxy"; then
    info "Repository cargo-proxy already exists, skipping"
else
    info "Creating cargo-proxy …"
    nexus_api POST "beta/repositories/cargo/proxy" -d '{
      "name": "cargo-proxy",
      "online": true,
      "storage": { "blobStoreName": "default", "strictContentTypeValidation": true },
      "proxy": {
        "remoteUrl": "https://static.crates.io",
        "contentMaxAge": 1440,
        "metadataMaxAge": 1440
      },
      "negativeCache": { "enabled": true, "timeToLive": 1440 },
      "httpClient": { "blocked": false, "autoBlock": true }
    }' && ok "cargo-proxy created"
fi

# ── PyPI proxy ────────────────────────────────────────────────────────────────

if repo_exists "pypi-proxy"; then
    info "Repository pypi-proxy already exists, skipping"
else
    info "Creating pypi-proxy …"
    nexus_api POST "v1/repositories/pypi/proxy" -d '{
      "name": "pypi-proxy",
      "online": true,
      "storage": { "blobStoreName": "default", "strictContentTypeValidation": true },
      "proxy": {
        "remoteUrl": "https://pypi.org",
        "contentMaxAge": 1440,
        "metadataMaxAge": 1440
      },
      "negativeCache": { "enabled": true, "timeToLive": 1440 },
      "httpClient": { "blocked": false, "autoBlock": true }
    }' && ok "pypi-proxy created"
fi

# ── OCI / Docker registry proxy ───────────────────────────────────────────────

if repo_exists "oci-proxy"; then
    info "Repository oci-proxy already exists, skipping"
else
    info "Creating oci-proxy …"
    nexus_api POST "v1/repositories/docker/proxy" -d '{
      "name": "oci-proxy",
      "online": true,
      "storage": { "blobStoreName": "default", "strictContentTypeValidation": true },
      "docker": { "v1Enabled": false, "forceBasicAuth": false },
      "dockerProxy": { "indexType": "HUB", "cacheForeignLayers": true },
      "proxy": {
        "remoteUrl": "https://registry-1.docker.io",
        "contentMaxAge": 1440,
        "metadataMaxAge": 1440
      },
      "negativeCache": { "enabled": true, "timeToLive": 1440 },
      "httpClient": { "blocked": false, "autoBlock": true }
    }' && ok "oci-proxy created"
fi

# ── Rules (raw HTTP) proxy ────────────────────────────────────────────────────
# Proxies Bazel HTTP archive downloads for rules_go, rules_python, buildtools, etc.

if repo_exists "rules-proxy"; then
    info "Repository rules-proxy already exists, skipping"
else
    info "Creating rules-proxy …"
    nexus_api POST "v1/repositories/raw/proxy" -d '{
      "name": "rules-proxy",
      "online": true,
      "storage": { "blobStoreName": "default", "strictContentTypeValidation": false },
      "proxy": {
        "remoteUrl": "https://github.com",
        "contentMaxAge": 1440,
        "metadataMaxAge": 1440
      },
      "negativeCache": { "enabled": true, "timeToLive": 1440 },
      "httpClient": { "blocked": false, "autoBlock": true }
    }' && ok "rules-proxy created"
fi

ok "Nexus repository provisioning complete"
