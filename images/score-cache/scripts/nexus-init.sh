#!/usr/bin/env bash
# nexus-init.sh — One-shot init: wait for Nexus first-boot then provision
# proxy and hosted repositories using the auto-generated admin password.
#
# The password is NOT changed here; test tasks read it dynamically from
# /nexus-data/admin.password via docker exec.
#
# Runs once per container lifetime (supervisord autorestart=false).
# Environment variables (all optional):
#   NEXUS_URL   http://127.0.0.1:8081
#   MAX_WAIT    600          (seconds to wait for Nexus to start)

set -euo pipefail

NEXUS_URL="${NEXUS_URL:-http://127.0.0.1:8081}"
MAX_WAIT="${MAX_WAIT:-600}"
PASSWORD_FILE="/nexus-data/admin.password"
DONE_MARKER="/nexus-data/.score-cache-init-done"

info() { echo "[nexus-init] $*"; }

# ── Idempotency guard ─────────────────────────────────────────────────────────
if [ -f "$DONE_MARKER" ]; then
    info "Already initialised — skipping"
    exit 0
fi

# ── Wait for Nexus to generate the first-boot admin password ─────────────────
info "Waiting for first-boot admin password file …"
elapsed=0
until [ -f "$PASSWORD_FILE" ]; do
    sleep 5; elapsed=$((elapsed+5))
    [ "$elapsed" -ge "$MAX_WAIT" ] && { info "TIMEOUT waiting for $PASSWORD_FILE"; exit 1; }
done
NEXUS_PASS=$(cat "$PASSWORD_FILE")
info "Password file found"

# ── Wait for Nexus REST API to respond ────────────────────────────────────────
info "Waiting for Nexus REST API …"
elapsed=0
until curl -sf -u "admin:${NEXUS_PASS}" "${NEXUS_URL}/service/rest/v1/status" >/dev/null 2>&1; do
    sleep 5; elapsed=$((elapsed+5))
    [ "$elapsed" -ge "$MAX_WAIT" ] && { info "TIMEOUT waiting for Nexus API"; exit 1; }
done
info "Nexus API ready"

# ── Provision repositories ────────────────────────────────────────────────────
NEXUS_URL="$NEXUS_URL" NEXUS_USER=admin NEXUS_PASS="$NEXUS_PASS" \
    bash /opt/score-cache/configure.sh

# ── Mark as done ─────────────────────────────────────────────────────────────
touch "$DONE_MARKER"
info "Initialisation complete (admin password is in $PASSWORD_FILE)"
