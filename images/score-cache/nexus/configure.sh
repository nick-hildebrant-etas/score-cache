#!/usr/bin/env bash
# configure.sh — Provision Nexus proxy and hosted repositories for score-cache.
#
# Idempotent: each repo is created only if it does not already exist.
#
# Called by nexus-init.sh after Nexus is ready and the admin password is set.
#
# Environment variables:
#   NEXUS_URL    http://127.0.0.1:8081   (direct, not via nginx)
#   NEXUS_USER   admin
#   NEXUS_PASS   admin123

set -euo pipefail

NEXUS_URL="${NEXUS_URL:-http://127.0.0.1:8081}"
NEXUS_USER="${NEXUS_USER:-admin}"
NEXUS_PASS="${NEXUS_PASS:-admin123}"

info() { echo "[configure] $*"; }
ok()   { echo "[configure] OK  $*"; }

nexus_api() {
    local method="$1" path="$2"; shift 2
    curl -sf -u "${NEXUS_USER}:${NEXUS_PASS}" \
         -X "${method}" \
         -H "Content-Type: application/json" \
         "${NEXUS_URL}/service/rest/${path}" "$@"
}

repo_exists() {
    nexus_api GET "v1/repositories" 2>/dev/null | grep -q "\"name\":\"${1}\""
}

# ── Enable anonymous access (allows unauthenticated reads from proxy repos) ───
info "Enabling anonymous access …"
nexus_api PUT "v1/security/anonymous" \
    -d '{"enabled":true,"userId":"anonymous","realmName":"NexusAuthorizingRealm"}' \
    >/dev/null 2>&1 || true

# ── Cargo proxy ───────────────────────────────────────────────────────────────
if repo_exists "cargo-proxy"; then
    info "cargo-proxy already exists"
else
    info "Creating cargo-proxy …"
    nexus_api POST "beta/repositories/cargo/proxy" -d '{
      "name": "cargo-proxy",
      "online": true,
      "storage": {"blobStoreName":"default","strictContentTypeValidation":true},
      "proxy": {"remoteUrl":"https://static.crates.io","contentMaxAge":1440,"metadataMaxAge":1440},
      "negativeCache": {"enabled":true,"timeToLive":1440},
      "httpClient": {"blocked":false,"autoBlock":true}
    }' >/dev/null && ok "cargo-proxy created"
fi

# ── PyPI proxy ────────────────────────────────────────────────────────────────
if repo_exists "pypi-proxy"; then
    info "pypi-proxy already exists"
else
    info "Creating pypi-proxy …"
    nexus_api POST "v1/repositories/pypi/proxy" -d '{
      "name": "pypi-proxy",
      "online": true,
      "storage": {"blobStoreName":"default","strictContentTypeValidation":true},
      "proxy": {"remoteUrl":"https://pypi.org","contentMaxAge":1440,"metadataMaxAge":1440},
      "negativeCache": {"enabled":true,"timeToLive":1440},
      "httpClient": {"blocked":false,"autoBlock":true}
    }' >/dev/null && ok "pypi-proxy created"
fi

# ── OCI / Docker registry proxy ───────────────────────────────────────────────
if repo_exists "oci-proxy"; then
    info "oci-proxy already exists"
else
    info "Creating oci-proxy …"
    nexus_api POST "v1/repositories/docker/proxy" -d '{
      "name": "oci-proxy",
      "online": true,
      "storage": {"blobStoreName":"default","strictContentTypeValidation":true},
      "docker": {"v1Enabled":false,"forceBasicAuth":false},
      "dockerProxy": {"indexType":"HUB","cacheForeignLayers":true},
      "proxy": {"remoteUrl":"https://registry-1.docker.io","contentMaxAge":1440,"metadataMaxAge":1440},
      "negativeCache": {"enabled":true,"timeToLive":1440},
      "httpClient": {"blocked":false,"autoBlock":true}
    }' >/dev/null && ok "oci-proxy created"
fi

# ── Rules raw proxy (Bazel HTTP archive downloads) ───────────────────────────
if repo_exists "rules-proxy"; then
    info "rules-proxy already exists"
else
    info "Creating rules-proxy …"
    nexus_api POST "v1/repositories/raw/proxy" -d '{
      "name": "rules-proxy",
      "online": true,
      "storage": {"blobStoreName":"default","strictContentTypeValidation":false},
      "proxy": {"remoteUrl":"https://github.com","contentMaxAge":1440,"metadataMaxAge":1440},
      "negativeCache": {"enabled":true,"timeToLive":1440},
      "httpClient": {"blocked":false,"autoBlock":true}
    }' >/dev/null && ok "rules-proxy created"
fi

# ── Raw hosted repo (general push / pull — no upstream needed) ────────────────
if repo_exists "raw-hosted"; then
    info "raw-hosted already exists"
else
    info "Creating raw-hosted …"
    nexus_api POST "v1/repositories/raw/hosted" -d '{
      "name": "raw-hosted",
      "online": true,
      "storage": {"blobStoreName":"default","strictContentTypeValidation":false,"writePolicy":"allow"}
    }' >/dev/null && ok "raw-hosted created"
fi

ok "Repository provisioning complete"
