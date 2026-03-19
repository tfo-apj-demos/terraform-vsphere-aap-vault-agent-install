#!/bin/bash
# Internal CA certificate setup for DevContainers
#
# Installs certificates from internal services into the system CA store.
# Skips cleanly when INTERNAL_CA_HOST is not set or the host is unreachable.
set -euo pipefail

# --- Configuration (from environment) ---
INTERNAL_HOST="${INTERNAL_CA_HOST:-}"
INTERNAL_IP="${INTERNAL_CA_IP:-}"
CERT_NAME="${INTERNAL_CA_CERT_NAME:-internal-ca-chain}"
ADDITIONAL_HOSTS="${INTERNAL_CA_ADDITIONAL_HOSTS:-}"  # colon-separated

CERT_DIR="/usr/local/share/ca-certificates"
CERT_PATH="${CERT_DIR}/${CERT_NAME}.crt"

# --- Guard: nothing to do if host not configured ---
if [ -z "$INTERNAL_HOST" ]; then
    echo "Skipping internal CA setup (INTERNAL_CA_HOST not set)"
    exit 0
fi

echo "=== Internal CA Certificate Setup ==="

# --- Guard: check network reachability before doing anything ---
# Use IP for the connectivity check since the hostname is internal (.local)
# and won't resolve via DNS — /etc/hosts entries are added after this check.
CHECK_TARGET="${INTERNAL_IP:-$INTERNAL_HOST}"
echo "Checking connectivity to ${INTERNAL_HOST}:443..."
if ! timeout 5 bash -c "echo >/dev/tcp/${CHECK_TARGET}/443" 2>/dev/null; then
    echo "  Result: unreachable"
    echo "  Skipping certificate setup — not on the internal network."
    echo "  This is safe to ignore. OTEL/Grafana will not work until you're on-network."
    exit 0
fi
echo "  Result: reachable"

# --- Add hostnames to /etc/hosts (if static IP provided) ---
if [ -n "$INTERNAL_IP" ]; then
    ALL_HOSTS="$INTERNAL_HOST"
    [ -n "$ADDITIONAL_HOSTS" ] && ALL_HOSTS="$ALL_HOSTS:$ADDITIONAL_HOSTS"

    IFS=':' read -ra HOST_ARRAY <<< "$ALL_HOSTS"
    for host in "${HOST_ARRAY[@]}"; do
        if ! grep -q "$host" /etc/hosts 2>/dev/null; then
            echo "$INTERNAL_IP $host" | sudo tee -a /etc/hosts > /dev/null
            echo "  Added $host -> $INTERNAL_IP to /etc/hosts"
        fi
    done
fi

# --- Extract and install certificate chain ---
EXISTING=$(find "$CERT_DIR" -name "${CERT_NAME}*.crt" 2>/dev/null | wc -l)
if [ "$EXISTING" -gt 0 ]; then
    echo "Certificates already installed ($EXISTING file(s)), skipping extraction"
else
    TEMP_CHAIN=$(mktemp)
    trap "rm -f $TEMP_CHAIN" EXIT

    echo "Extracting certificate chain from ${INTERNAL_HOST}:443..."
    openssl s_client -connect "${INTERNAL_HOST}:443" -showcerts </dev/null 2>/dev/null \
        | awk '/BEGIN CERTIFICATE/,/END CERTIFICATE/{ print }' > "$TEMP_CHAIN"

    CERT_COUNT=$(grep -c "BEGIN CERTIFICATE" "$TEMP_CHAIN" || true)
    if [ "$CERT_COUNT" -eq 0 ]; then
        echo "  No certificates returned — skipping"
        exit 0
    fi

    echo "  Extracted $CERT_COUNT certificate(s)"

    # Save full chain for NODE_EXTRA_CA_CERTS
    sudo cp "$TEMP_CHAIN" "$CERT_PATH"
    sudo chmod 644 "$CERT_PATH"

    # Split out individual CA certs (skip server cert at position 1)
    CERT_NUM=0
    CURRENT_CERT=""
    while IFS= read -r line; do
        CURRENT_CERT="${CURRENT_CERT}${line}"$'\n'
        if [[ "$line" == *"END CERTIFICATE"* ]]; then
            CERT_NUM=$((CERT_NUM + 1))
            if [ "$CERT_NUM" -gt 1 ]; then
                echo "$CURRENT_CERT" | sudo tee "${CERT_DIR}/${CERT_NAME}-ca${CERT_NUM}.crt" > /dev/null
            fi
            CURRENT_CERT=""
        fi
    done < "$TEMP_CHAIN"

    echo "  Certificate chain installed at $CERT_PATH"
fi

# --- Update system CA store ---
sudo update-ca-certificates --fresh > /dev/null 2>&1
echo "System CA store updated"

echo "=== Internal CA Setup Complete ==="
