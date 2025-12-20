#!/bin/bash
# Rocket Pool Configuration Extractor
# Run this after upgrades to refresh my-config.md with current state

set -e

echo "=== Gathering Rocket Pool Configuration ==="
echo ""

# Check if rocketpool CLI is available
if ! command -v rocketpool &> /dev/null; then
    echo "Error: rocketpool command not found"
    exit 1
fi

echo "--- Rocket Pool Node Info ---"
rocketpool node status

echo ""
echo "--- Service Version ---"
rocketpool service version

echo ""
echo "--- Client Status ---"
rocketpool service status

echo ""
echo "--- Minipool Status ---"
rocketpool minipool status

echo ""
echo "--- Network Config ---"
rocketpool service config

echo ""
echo "=== System Information ==="
echo "OS: $(lsb_release -d | cut -f2)"
echo "Kernel: $(uname -r)"
echo "Architecture: $(uname -m)"

echo ""
echo "=== Manual Update Needed ==="
echo "Copy relevant output above into my-config.md"
echo "Or review the sections that need updating."
echo ""
echo "TIP: You can redirect this output to a temp file:"
echo "  ./update-config.sh > config-snapshot.txt"
echo "  Then manually copy sections into my-config.md"
