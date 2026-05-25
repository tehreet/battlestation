#!/usr/bin/env bash
# install-osquery-wsl.sh
# -----------------------------------------------------------------------------
# Install osquery on Ubuntu (WSL). Idempotent: exits cleanly if already
# installed. Uses the modern signed-by/keyrings approach — apt-key is
# deprecated on Ubuntu 24.04.
# -----------------------------------------------------------------------------

set -euo pipefail

if command -v osqueryi >/dev/null 2>&1; then
    echo "osquery already installed: $(command -v osqueryi)"
    echo "version: $(osqueryi --version)"
    exit 0
fi

KEYRING=/etc/apt/keyrings/osquery.gpg
LIST=/etc/apt/sources.list.d/osquery.list

echo "Installing osquery..."
sudo install -d -m 0755 /etc/apt/keyrings

# Fetch + dearmor the signing key
curl -fsSL https://pkg.osquery.io/deb/pubkey.gpg \
    | sudo gpg --dearmor --yes -o "$KEYRING"

# Pin the repo with signed-by so apt verifies against this keyring only
echo "deb [arch=amd64 signed-by=$KEYRING] https://pkg.osquery.io/deb deb main" \
    | sudo tee "$LIST" >/dev/null

sudo apt-get update
sudo apt-get install -y osquery

echo "osquery installed: $(command -v osqueryi)"
echo "version: $(osqueryi --version)"
