#!/usr/bin/env bash
set -e

# This script installs Terraform and related tools

# Versions
TERRAFORM_VERSION=${1:-"1.14.6"}
TERRAFORM_DOCS_VERSION=${2:-"0.21.0"}
TFLINT_VERSION=${3:-"0.60.0"}
TFLINT_AWS_RULESET_VERSION=${4:-"0.45.0"}
TFLINT_AZURE_RULESET_VERSION=${5:-"0.30.0"}
TFLINT_GCP_RULESET_VERSION=${6:-"0.38.0"}
INFRACOST_VERSION=${7:-"0.10.43"}
CHECKOV_VERSION=${8:-"3.2.504"}
VAULT_RADAR_VERSION=${9:-"0.43.0"}
INSTALL_VAULT_RADAR=${10:-"false"}

# Detect architecture
ARCH=$(uname -m)
if [ "$ARCH" = "aarch64" ] || [ "$ARCH" = "arm64" ]; then
    TERRAFORM_ARCH="arm64"
    TFLINT_ARCH="arm64"
    INFRACOST_ARCH="arm64"
    VAULT_RADAR_ARCH="arm64"
    TERRAFORM_DOCS_ARCH="arm64"
else
    TERRAFORM_ARCH="amd64"
    TFLINT_ARCH="amd64"
    INFRACOST_ARCH="amd64"
    VAULT_RADAR_ARCH="amd64"
    TERRAFORM_DOCS_ARCH="amd64"
fi

echo "Detected architecture: $ARCH (using ${TERRAFORM_ARCH})"

echo "Installing Terraform v${TERRAFORM_VERSION}..."
curl -sSL -o /tmp/terraform.zip "https://releases.hashicorp.com/terraform/${TERRAFORM_VERSION}/terraform_${TERRAFORM_VERSION}_linux_${TERRAFORM_ARCH}.zip"
unzip -qq /tmp/terraform.zip -d /tmp
sudo mv /tmp/terraform /usr/local/bin/
rm -f /tmp/terraform.zip

# Vault Radar installation (optional)
if [ "${INSTALL_VAULT_RADAR}" = "true" ]; then
    echo "Installing Vault Radar v${VAULT_RADAR_VERSION}..."
    #https://releases.hashicorp.com/vault-radar/0.36.0/
    curl -sSL -o /tmp/vault-radar.zip "https://releases.hashicorp.com/vault-radar/${VAULT_RADAR_VERSION}/vault-radar_${VAULT_RADAR_VERSION}_linux_${VAULT_RADAR_ARCH}.zip"
    unzip -qq /tmp/vault-radar.zip -d /tmp
    sudo mv /tmp/vault-radar /usr/local/bin/
    rm -f /tmp/vault-radar.zip
else
    echo "Skipping Vault Radar installation (INSTALL_VAULT_RADAR=${INSTALL_VAULT_RADAR})"
fi

echo "Installing terraform-docs v${TERRAFORM_DOCS_VERSION}..."
curl -sSLo /tmp/terraform-docs.tar.gz "https://github.com/terraform-docs/terraform-docs/releases/download/v${TERRAFORM_DOCS_VERSION}/terraform-docs-v${TERRAFORM_DOCS_VERSION}-linux-${TERRAFORM_DOCS_ARCH}.tar.gz"
tar -xzf /tmp/terraform-docs.tar.gz -C /tmp
sudo mv /tmp/terraform-docs /usr/local/bin/
rm -f /tmp/terraform-docs.tar.gz

echo "Installing tflint v${TFLINT_VERSION}..."
curl -sSLo /tmp/tflint.zip "https://github.com/terraform-linters/tflint/releases/download/v${TFLINT_VERSION}/tflint_linux_${TFLINT_ARCH}.zip"
unzip -qq /tmp/tflint.zip -d /tmp
sudo mv /tmp/tflint /usr/local/bin/
rm -f /tmp/tflint.zip

echo "Installing TFLint AWS ruleset v${TFLINT_AWS_RULESET_VERSION}..."
mkdir -p ~/.tflint.d/plugins
curl -sSLo /tmp/tflint-aws-ruleset.zip "https://github.com/terraform-linters/tflint-ruleset-aws/releases/download/v${TFLINT_AWS_RULESET_VERSION}/tflint-ruleset-aws_linux_${TFLINT_ARCH}.zip"
unzip -qq /tmp/tflint-aws-ruleset.zip -d ~/.tflint.d/plugins
rm -f /tmp/tflint-aws-ruleset.zip

echo "Installing TFLint Azure ruleset v${TFLINT_AZURE_RULESET_VERSION}..."
curl -sSLo /tmp/tflint-azure-ruleset.zip "https://github.com/terraform-linters/tflint-ruleset-azurerm/releases/download/v${TFLINT_AZURE_RULESET_VERSION}/tflint-ruleset-azurerm_linux_${TFLINT_ARCH}.zip"
unzip -qq /tmp/tflint-azure-ruleset.zip -d ~/.tflint.d/plugins
rm -f /tmp/tflint-azure-ruleset.zip

echo "Installing TFLint GCP ruleset v${TFLINT_GCP_RULESET_VERSION}..."
curl -sSLo /tmp/tflint-gcp-ruleset.zip "https://github.com/terraform-linters/tflint-ruleset-google/releases/download/v${TFLINT_GCP_RULESET_VERSION}/tflint-ruleset-google_linux_${TFLINT_ARCH}.zip"
unzip -qq /tmp/tflint-gcp-ruleset.zip -d ~/.tflint.d/plugins
rm -f /tmp/tflint-gcp-ruleset.zip

echo "Installing Infracost v${INFRACOST_VERSION}..."
curl -sSLo /tmp/infracost.tar.gz "https://github.com/infracost/infracost/releases/download/v${INFRACOST_VERSION}/infracost-linux-${INFRACOST_ARCH}.tar.gz"
tar -xzf /tmp/infracost.tar.gz -C /tmp
sudo mv /tmp/infracost-linux-${INFRACOST_ARCH} /usr/local/bin/infracost
rm -f /tmp/infracost.tar.gz

# echo "Installing pre-commit..."
# # Install pre-commit system-wide using uv
# export UV_TOOL_BIN_DIR=/usr/local/bin
# uv tool install pre-commit --with pre-commit-uv
# uv tool install specify-cli --from git+https://github.com/github/spec-kit.git

# Create a symlink so it's available system-wide
# sudo ln -sf ~/.local/bin/pre-commit /usr/local/bin/pre-commit

# Also make sure it's available to the node user by installing it for them too
# First ensure the node user's .local directory exists
# sudo -u node mkdir -p /home/node/.local/bin

# Install pre-commit for the node user (this will work after uv is installed for node user)
# We'll do this in the Dockerfile after switching to node user

echo "Installing Trivy..."
sudo apt-get update
sudo apt-get install -y wget apt-transport-https gnupg lsb-release
wget -qO - https://aquasecurity.github.io/trivy-repo/deb/public.key | sudo apt-key add -
echo deb https://aquasecurity.github.io/trivy-repo/deb $(lsb_release -sc) main | sudo tee -a /etc/apt/sources.list.d/trivy.list
sudo apt-get update
sudo apt-get install -y trivy

echo "Installing Checkov v${CHECKOV_VERSION} in virtual environment..."
# Install python3-venv if not already installed
sudo apt-get update && sudo apt-get install -y python3-venv

# Create a virtual environment for Checkov
VENV_DIR="/opt/checkov-venv"
sudo python3 -m venv ${VENV_DIR}

# Install Checkov in the virtual environment
sudo ${VENV_DIR}/bin/pip install checkov==${CHECKOV_VERSION}


# Create a wrapper script for Checkov
sudo tee /usr/local/bin/checkov > /dev/null << EOL
#!/bin/bash
${VENV_DIR}/bin/checkov \$@
EOL

# Make the wrapper executable
sudo chmod +x /usr/local/bin/checkov

# Create .tflint.hcl config file
mkdir -p /home/node/.tflint.d
cat > /home/node/.tflint.hcl << EOF
plugin "aws" {
  enabled = true
}

plugin "azurerm" {
  enabled = true
}

plugin "google" {
  enabled = true
}
EOF

# Set ownership for the config file
chown -R node:node /home/node/.tflint.d

echo "Terraform tools installation complete!"
