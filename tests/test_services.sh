#!/usr/bin/env bash
# test_services.sh — Integration tests for the score-cache container stack.
#
# Tests that every proxied service is reachable through nginx:
#   1. nginx health endpoint
#   2. Nexus UI (via /nexus/)
#   3. Cargo proxy route
#   4. PyPI proxy route
#   5. OCI /v2/ endpoint
#   6. Bazel rules (raw) proxy route
#   7. bazel-remote HTTP cache status via /cache/
#   8. gRPC port open for bazel-remote REAPI
#
# Env vars (all optional, defaults shown):
#   COMPOSE_FILE   images/score-cache/docker-compose.yml
#   HTTP_PORT      80
#   GRPC_PORT      9093
#   MAX_WAIT       120
#
# Usage (from repo root):
#   bash tests/test_services.sh

set -euo pipefail

COMPOSE_FILE="${COMPOSE_FILE:-images/score-cache/docker-compose.yml}"
HTTP_PORT="${HTTP_PORT:-80}"
GRPC_PORT="${GRPC_PORT:-9093}"
MAX_WAIT="${MAX_WAIT:-120}"
BASE_URL="http://localhost:${HTTP_PORT}"

RED='\033[0;31m'
GRN='\033[0;32m'
YLW='\033[1;33m'
NC='\033[0m'

pass() { printf "${GRN}[PASS]${NC} %s\n" "$*"; }
fail() { printf "${RED}[FAIL]${NC} %s\n" "$*" >&2; exit 1; }
info() { printf "${YLW}[INFO]${NC} %s\n" "$*"; }

# ── Start stack ───────────────────────────────────────────────────────────────

info "Starting score-cache stack …"
docker compose -f "${COMPOSE_FILE}" up -d

# ── Wait for nginx health endpoint ───────────────────────────────────────────

info "Waiting for nginx at ${BASE_URL}/health (max ${MAX_WAIT}s) …"
elapsed=0
until curl -sf "${BASE_URL}/health" > /dev/null 2>&1; do
    sleep 5
    elapsed=$((elapsed + 5))
    if [ "${elapsed}" -ge "${MAX_WAIT}" ]; then
        fail "nginx did not become ready within ${MAX_WAIT}s"
    fi
done
pass "nginx health endpoint OK"

# ── Helper: expect one of a set of HTTP status codes ─────────────────────────

expect_http() {
    local url="$1"
    local desc="$2"
    shift 2
    local allowed=("$@")
    local code
    code=$(curl -s -o /dev/null -w "%{http_code}" "${url}" 2>/dev/null || echo "000")
    for ok in "${allowed[@]}"; do
        [ "${code}" = "${ok}" ] && { pass "${desc} — HTTP ${code}"; return 0; }
    done
    fail "${desc} — unexpected HTTP ${code} (url: ${url})"
}

# ── Service tests ─────────────────────────────────────────────────────────────

# 1. Nexus UI reachable through /nexus/
expect_http "${BASE_URL}/nexus/" "Nexus UI proxy (/nexus/)" 200 301 302 307

# 2. Cargo proxy route exists
expect_http "${BASE_URL}/cargo/" "Cargo proxy (/cargo/)" 200 301 302 401 404

# 3. PyPI proxy route exists
expect_http "${BASE_URL}/pypi/" "PyPI proxy (/pypi/)" 200 301 302 404

# 4. OCI /v2/ endpoint (Docker Distribution API)
expect_http "${BASE_URL}/v2/" "OCI registry proxy (/v2/)" 200 401 404

# 5. Bazel rules raw-proxy route
expect_http "${BASE_URL}/rules/" "Rules archive proxy (/rules/)" 200 301 302 401 404

# 6. bazel-remote HTTP cache route
expect_http "${BASE_URL}/cache/" "bazel-remote HTTP cache (/cache/)" 200 404

# 7. gRPC port is open for bazel-remote
info "Checking gRPC port ${GRPC_PORT} …"
if nc -z localhost "${GRPC_PORT}" 2>/dev/null; then
    pass "gRPC port ${GRPC_PORT} is open (bazel-remote REAPI)"
else
    fail "gRPC port ${GRPC_PORT} is not reachable"
fi

info "All score-cache service tests passed."
