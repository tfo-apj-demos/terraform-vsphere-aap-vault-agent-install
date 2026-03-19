#!/bin/bash
# Post-create setup script for Claude Code devcontainer
set -euo pipefail

echo "=== Post-Create Setup Starting ==="

# Fix permissions for Docker volumes (Docker volumes are root-owned)
sudo chown -R node:node /commandhistory
touch /commandhistory/.zsh_history
touch /commandhistory/.bash_history

sudo chown -R node:node /home/node/.claude
chmod 700 /home/node/.claude

# Configure Terraform credentials for HCP Terraform
if [ -n "${TFE_TOKEN:-}" ]; then
    mkdir -p ~/.terraform.d
    cat > ~/.terraform.d/credentials.tfrc.json << EOF
{
  "credentials": {
    "app.terraform.io": {
      "token": "${TFE_TOKEN}"
    }
  }
}
EOF
    echo "Terraform credentials configured"
else
    echo "Skipping Terraform credentials (TFE_TOKEN not set)"
fi

# Setup internal CA certificates (skips cleanly if not on network)
CERT_NAME="${INTERNAL_CA_CERT_NAME:-internal-ca-chain}"
CERT_PATH="/usr/local/share/ca-certificates/${CERT_NAME}.crt"

SCRIPT_DIR="$(dirname "$0")"
"${SCRIPT_DIR}/../../scripts/setup-internal-certs.sh"

# If certs were installed, configure Node.js and OTEL to trust them
if [ -f "$CERT_PATH" ]; then
    {
        echo ""
        echo "# Internal CA certs (added by post-create.sh)"
        echo "export NODE_EXTRA_CA_CERTS=\"$CERT_PATH\""
        echo "export OTEL_EXPORTER_OTLP_CERTIFICATE=\"$CERT_PATH\""
    } >> /home/node/.zshrc
    echo "NODE_EXTRA_CA_CERTS and OTEL_EXPORTER_OTLP_CERTIFICATE set in shell profile"
fi

echo "=== Post-Create Setup Complete ==="
