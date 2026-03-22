#!/usr/bin/env bash
# install-tools.sh — Install go-task and other CLI tools inside the devcontainer.
# Run headlessly; no VS Code required.
set -euo pipefail

# ── go-task ───────────────────────────────────────────────────────────────────
if ! command -v task &>/dev/null; then
    echo "Installing go-task …"
    sh -c "$(curl -fsSL https://taskfile.dev/install.sh)" -- -d -b /usr/local/bin
    echo "go-task $(task --version) installed"
else
    echo "go-task already installed: $(task --version)"
fi

# ── curl / netcat (for test_services.sh) ─────────────────────────────────────
apt-get update -qq && apt-get install -y --no-install-recommends curl netcat-openbsd > /dev/null

echo "Tool installation complete."
