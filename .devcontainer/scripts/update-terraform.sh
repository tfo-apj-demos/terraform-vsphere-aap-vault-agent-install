#!/bin/bash
# Update Terraform to the latest version
set -euo pipefail

echo "=== Updating Terraform ==="

# Detect architecture (same pattern as terraform-tools.sh)
ARCH=$(uname -m)
if [ "$ARCH" = "aarch64" ] || [ "$ARCH" = "arm64" ]; then
    TF_ARCH="arm64"
else
    TF_ARCH="amd64"
fi

CURRENT=$(terraform version -json 2>/dev/null | jq -r '.terraform_version' 2>/dev/null || echo "unknown")

# Get latest version from HashiCorp checkpoint API
LATEST=$(curl -sSf https://checkpoint-api.hashicorp.com/v1/check/terraform | jq -r '.current_version')

if [ -z "$LATEST" ] || [ "$LATEST" = "null" ]; then
    echo "  Could not determine latest Terraform version, skipping update"
    exit 0
fi

if [ "$CURRENT" = "$LATEST" ]; then
    echo "  Terraform already at latest (v${CURRENT})"
    exit 0
fi

echo "  Updating Terraform: v${CURRENT} -> v${LATEST}..."
curl -sSL -o /tmp/terraform.zip "https://releases.hashicorp.com/terraform/${LATEST}/terraform_${LATEST}_linux_${TF_ARCH}.zip"
unzip -qq -o /tmp/terraform.zip -d /tmp
sudo mv /tmp/terraform /usr/local/bin/terraform
rm -f /tmp/terraform.zip
echo "  Terraform updated to v${LATEST}"
