FROM node:25.7.0-slim

# Set all build arguments at once
ARG TZ \
    USERNAME=node \
    TERRAFORM_VERSION="1.14.6" \
    TERRAFORM_DOCS_VERSION="0.21.0" \
    TFLINT_VERSION="0.60.0" \
    TFLINT_AWS_RULESET_VERSION="0.45.0" \
    TFLINT_AZURE_RULESET_VERSION="0.30.0" \
    TFLINT_GCP_RULESET_VERSION="0.38.0" \
    INFRACOST_VERSION="0.10.43" \
    CHECKOV_VERSION="3.2.504" \
    VAULT_RADAR_VERSION="0.43.0" \
    INSTALL_VAULT_RADAR="true"

# Install uv directly from the official uv image (ensure version pinning for stability)
COPY --from=docker.io/astral/uv:latest /uv /uvx /usr/local/bin/

# Install Go from official image (using stable version for reliability)
COPY --from=docker.io/library/golang:1.24-bookworm /usr/local/go /usr/local/go

# Install packages, configure locale, set up directories, and install delta in one layer
# Note: node:20-slim requires ca-certificates for HTTPS operations
RUN apt update && apt install -y --no-install-recommends \
    ca-certificates less git procps sudo zsh man-db unzip gnupg2 gh \
    iptables ipset iproute2 dnsutils aggregate \
    python3 python3-pip python3-venv python3-full \
    jq curl locales wget && \
    # Configure locale
    sed -i 's/^# *en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /etc/locale.gen && \
    locale-gen en_US.UTF-8 && \
    update-locale LANG=en_US.UTF-8 LC_ALL=en_US.UTF-8 && \
    # Set up directories and permissions
    mkdir -p /usr/local/share/npm-global /commandhistory /workspace /home/node/.claude /home/node/.config /home/node/go && \
    touch /commandhistory/.bash_history && \
    chown -R node:node /usr/local/share /commandhistory /workspace /home/node/.claude /home/node/.config /home/node/go && \
    # Install delta
    ARCH=$(dpkg --print-architecture) && \
    wget -q "https://github.com/dandavison/delta/releases/download/0.18.2/git-delta_0.18.2_${ARCH}.deb" && \
    dpkg -i "git-delta_0.18.2_${ARCH}.deb" && \
    rm "git-delta_0.18.2_${ARCH}.deb" && \
    # Clean up apt cache
    rm -rf /var/lib/apt/lists/*

# Set all environment variables at once
ENV TZ="$TZ" \
    LANG=en_US.UTF-8 \
    LC_ALL=en_US.UTF-8 \
    LANGUAGE=en_US:en \
    DEVCONTAINER=true \
    NPM_CONFIG_PREFIX=/usr/local/share/npm-global \
    GOROOT=/usr/local/go \
    GOPATH=/home/node/go \
    PATH=/usr/local/go/bin:/home/node/go/bin:/usr/local/share/npm-global/bin:/root/.local/bin:$PATH \
    SHELL=/bin/zsh

WORKDIR /workspace

# Configure sudo
RUN groupadd -f wheel && \
    usermod -aG wheel node && \
    echo "%wheel ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers.d/wheel-group && \
    chmod 0440 /etc/sudoers.d/wheel-group

# Copy and run library scripts
COPY library-scripts/*.sh /tmp/library-scripts/
RUN chmod +x /tmp/library-scripts/*.sh && \
    /tmp/library-scripts/terraform-tools.sh \
        "${TERRAFORM_VERSION}" \
        "${TERRAFORM_DOCS_VERSION}" \
        "${TFLINT_VERSION}" \
        "${TFLINT_AWS_RULESET_VERSION}" \
        "${TFLINT_AZURE_RULESET_VERSION}" \
        "${TFLINT_GCP_RULESET_VERSION}" \
        "${INFRACOST_VERSION}" \
        "${CHECKOV_VERSION}" \
        "${VAULT_RADAR_VERSION}" \
        "${INSTALL_VAULT_RADAR}" && \
    rm -rf /tmp/library-scripts

# Switch to node user for remaining installations
USER node

# Install zsh theme, Claude, uv for user, and Python tools in one layer
RUN sh -c "$(wget -O- https://github.com/deluan/zsh-in-docker/releases/download/v1.2.1/zsh-in-docker.sh)" -- \
        -p git \
        -a "export PROMPT_COMMAND='history -a' && export HISTFILE=/commandhistory/.bash_history" \
        -x && \
    uv tool install pre-commit --with pre-commit-uv && \
    ARCH=$(uname -m) && \
    if [ "$ARCH" = "x86_64" ]; then GOLANGCI_ARCH="amd64"; else GOLANGCI_ARCH="arm64"; fi && \
    GOLANGCI_VERSION="2.10.1" && \
    mkdir -p /home/node/go/bin && \
    wget -qO- "https://github.com/golangci/golangci-lint/releases/download/v${GOLANGCI_VERSION}/golangci-lint-${GOLANGCI_VERSION}-linux-${GOLANGCI_ARCH}.tar.gz" | tar -xz -C /tmp && \
    mv "/tmp/golangci-lint-${GOLANGCI_VERSION}-linux-${GOLANGCI_ARCH}/golangci-lint" /home/node/go/bin/ && \
    rm -rf /tmp/golangci-lint-* && \
    echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.zshrc 