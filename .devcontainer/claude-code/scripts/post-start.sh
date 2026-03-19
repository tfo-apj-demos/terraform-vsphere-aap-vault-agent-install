#!/bin/bash
set -euo pipefail
echo "=== Post-Start: Updating Tools ==="

# Update Claude Code CLI
echo "Updating Claude Code..."
claude update || npm update -g @anthropic-ai/claude-code 2>/dev/null || echo "  Claude update skipped"

# Update Terraform
SCRIPT_DIR="$(dirname "$0")"
"${SCRIPT_DIR}/../../scripts/update-terraform.sh"

echo "=== Post-Start Complete ==="
