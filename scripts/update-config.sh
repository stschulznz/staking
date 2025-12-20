#!/bin/bash
# Rocket Pool Configuration Extractor
# Generates markdown-formatted config data for my-config.md
# Usage: ./update-config.sh [node001|node002]

set -eu

# Determine which node this is
if [ $# -eq 0 ]; then
    read -p "Which node is this? (node001/node002): " NODE_NAME
else
    NODE_NAME="$1"
fi

# Ask if this is the currently active node
read -p "Is this node currently ACTIVE (validating)? (yes/no): " IS_ACTIVE
IS_ACTIVE=$(echo "$IS_ACTIVE" | tr '[:upper:]' '[:lower:]')

if [[ "$IS_ACTIVE" == "yes" || "$IS_ACTIVE" == "y" ]]; then
    NODE_STATE="Active"
else
    NODE_STATE="Standby"
fi

# Validate node name
if [[ ! "$NODE_NAME" =~ ^node00[12]$ ]]; then
    echo "Error: Node name must be 'node001' or 'node002'" >&2
    exit 1
fi

# Check if rocketpool CLI is available
if ! command -v rocketpool &> /dev/null; then
    echo "Error: rocketpool command not found. Is Rocket Pool installed?" >&2
    exit 1
fi

# Set output file
OUTPUT_FILE="${NODE_NAME}-config.txt"

echo "Gathering configuration for $NODE_NAME..." >&2
echo "Output will be saved to: $OUTPUT_FILE" >&2
echo "" >&2

# Helper function to safely extract values from rocketpool output
extract_value() {
    grep -m 1 "$1" | sed 's/^[^:]*: *//' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//' || echo "[Not found]"
}

# Collect all data first
NODE_STATUS=$(rocketpool node status 2>&1)
SERVICE_VERSION=$(rocketpool service version 2>&1)
SERVICE_STATUS=$(rocketpool service status 2>&1)
MINIPOOL_STATUS=$(rocketpool minipool status 2>&1)

# Check if wallet is initialized
if echo "$NODE_STATUS" | grep -q "not initialized"; then
    WALLET_INITIALIZED="false"
else
    WALLET_INITIALIZED="true"
fi

# Parse key information (only if wallet is initialized)
if [ "$WALLET_INITIALIZED" = "true" ]; then
    RP_VERSION=$(echo "$SERVICE_VERSION" | grep -i "Rocket Pool" | head -1 | sed 's/.*client version: //' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
    NETWORK=$(echo "$NODE_STATUS" | grep "using the" | head -1 | sed 's/.*using the //' | sed 's/ Network.*//' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
    
    # Extract addresses directly - just get the first two hex addresses (node, then withdrawal)
    # The output format has them in order: node address, then withdrawal address
    NODE_ADDRESS=$(echo "$NODE_STATUS" | grep -oE '0x[a-fA-F0-9]{40}' | sed -n '1p')
    WITHDRAWAL_ADDRESS=$(echo "$NODE_STATUS" | grep -oE '0x[a-fA-F0-9]{40}' | sed -n '2p')
    
    PRIMARY_WITHDRAWAL="$WITHDRAWAL_ADDRESS"
    TIMEZONE=$(echo "$NODE_STATUS" | grep "timezone location of" | head -1 | sed 's/.*location of //' | sed 's/\.$//' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
    REGISTERED_TIME="[Check: rocketpool node status]"
    MINIPOOL_COUNT=$(echo "$MINIPOOL_STATUS" | grep -c "Address:" || echo "0")
else
    # Get version and network even without wallet
    RP_VERSION=$(echo "$SERVICE_VERSION" | grep -i "Rocket Pool" | head -1 | sed 's/.*client version: //' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
    NETWORK=$(echo "$NODE_STATUS" | grep "using the" | head -1 | sed 's/.*using the //' | sed 's/ Network.*//' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
    NODE_ADDRESS="[Wallet not initialized - standby mode]"
    WITHDRAWAL_ADDRESS="[Same as active node]"
    PRIMARY_WITHDRAWAL="[Same as active node]"
    TIMEZONE="[Check manually]"
    REGISTERED_TIME="N/A (standby)"
    MINIPOOL_COUNT="0 (standby)"
fi

# Extract client info from Docker service status
# Parse client names from IMAGE column (format: registry/name:version)
EC_IMAGE=$(echo "$SERVICE_STATUS" | grep "rocketpool_eth1" | awk '{print $2}')
EC_CLIENT=$(echo "$EC_IMAGE" | sed 's|.*/||' | cut -d':' -f1 | sed 's/^./\u&/')  # Extract name after last slash, capitalize
EC_VERSION=$(echo "$EC_IMAGE" | cut -d':' -f2)
EC_STATUS=$(echo "$SERVICE_STATUS" | grep "rocketpool_eth1" | awk '{for(i=1;i<=NF;i++) if($i=="Up") {for(j=i;j<=i+2;j++) if($(j)!="") printf "%s ",$(j); print ""; break}}' | sed 's/ $//')

CC_IMAGE=$(echo "$SERVICE_STATUS" | grep "rocketpool_eth2" | awk '{print $2}')
CC_CLIENT=$(echo "$CC_IMAGE" | sed 's|.*/||' | cut -d':' -f1 | sed 's/^./\u&/')  # Extract name after last slash, capitalize
CC_VERSION=$(echo "$CC_IMAGE" | cut -d':' -f2)
CC_STATUS=$(echo "$SERVICE_STATUS" | grep "rocketpool_eth2" | awk '{for(i=1;i<=NF;i++) if($i=="Up") {for(j=i;j<=i+2;j++) if($(j)!="") printf "%s ",$(j); print ""; break}}' | sed 's/ $//')

# Sync status - requires actual sync check
EC_SYNC="[Check: rocketpool service status]"
CC_SYNC="[Check: rocketpool service status]"

# MEV-Boost status (check config file directly if available)
if [ -f ~/.rocketpool/user-settings.yml ]; then
    MEV_ENABLED=$(grep "enableMevBoost:" ~/.rocketpool/user-settings.yml 2>/dev/null | awk '{print $2}' | tr -d '"' || echo "[Check manually]")
    # Also get MEV mode and relays if enabled
    if [ "$MEV_ENABLED" = "true" ]; then
        MEV_MODE=$(grep "^  mode:" ~/.rocketpool/user-settings.yml 2>/dev/null | awk '{print $2}' | tr -d '"' || echo "")
        MEV_ENABLED="${MEV_ENABLED} (${MEV_MODE:-local})"
    fi
    
    # Fallback client configuration (for HA setups)
    FALLBACK_ENABLED=$(grep "useFallbackClients:" ~/.rocketpool/user-settings.yml 2>/dev/null | awk '{print $2}' | tr -d '"' || echo "false")
    if [ "$FALLBACK_ENABLED" = "true" ]; then
        FALLBACK_EC_URL=$(grep -A2 "^fallbackNormal:" ~/.rocketpool/user-settings.yml 2>/dev/null | grep "ecHttpUrl:" | awk '{print $2}')
        FALLBACK_CC_URL=$(grep -A2 "^fallbackNormal:" ~/.rocketpool/user-settings.yml 2>/dev/null | grep "ccHttpUrl:" | awk '{print $2}')
    else
        FALLBACK_EC_URL=""
        FALLBACK_CC_URL=""
    fi
else
    MEV_ENABLED="[Check with: rocketpool service config]"
    FALLBACK_ENABLED="[Check manually]"
    FALLBACK_EC_URL=""
    FALLBACK_CC_URL=""
fi

# System info
OS_INFO=$(lsb_release -d 2>/dev/null | cut -f2 || echo "Unknown")
KERNEL=$(uname -r)
ARCH=$(uname -m)
HOSTNAME=$(hostname)
UPTIME=$(uptime -p 2>/dev/null || echo "Unknown")

# Hardware info (best effort)
CPU_INFO=$(lscpu 2>/dev/null | grep "Model name:" | sed 's/Model name: *//' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//' || echo "[Run lscpu to see]")
RAM_TOTAL=$(free -h 2>/dev/null | awk '/^Mem:/ {print $2}' || echo "[Not found]")
DISK_USAGE=$(df -h / 2>/dev/null | awk 'NR==2 {print $3 "/" $2 " (" $5 " used)"}' || echo "[Not found]")

# Generate output and save to file
{
cat << EOF

==============================================================================
COPY THE SECTION BELOW INTO my-config.md
==============================================================================

---

## ${NODE_NAME^} $([ "$NODE_NAME" = "node001" ] && echo "(Designated Primary)" || echo "(Designated Standby)") - **Currently: $NODE_STATE**

> **Last Updated:** $(date '+%Y-%m-%d %H:%M %Z') on $HOSTNAME  
> **Wallet Status:** $([ "$WALLET_INITIALIZED" = "true" ] && echo "Initialized" || echo "Not initialized (standby mode)")

### Rocket Pool
- **Version:** $RP_VERSION
- **Network:** $NETWORK
- **Node Address:** $([ "$WALLET_INITIALIZED" = "true" ] && echo "\`$NODE_ADDRESS\`" || echo "$NODE_ADDRESS")
- **Withdrawal Address:** $([ "$WALLET_INITIALIZED" = "true" ] && echo "\`$WITHDRAWAL_ADDRESS\`" || echo "$WITHDRAWAL_ADDRESS")
- **Primary Withdrawal:** $([ "$WALLET_INITIALIZED" = "true" ] && echo "\`$PRIMARY_WITHDRAWAL\`" || echo "$PRIMARY_WITHDRAWAL")
- **Registered:** $REGISTERED_TIME
- **Timezone:** $TIMEZONE

### Minipools
- **Count:** $MINIPOOL_COUNT
$(if [ "$WALLET_INITIALIZED" = "true" ] && [ "$MINIPOOL_COUNT" != "0" ]; then
    echo "- **Status:**"
    echo "$MINIPOOL_STATUS" | grep -A 10 "Address:" | sed 's/^/  /' || echo "  No details available"
else
    echo "- **Note:** Node in standby - validators managed on active node"
fi)

### Client Configuration
**Execution Client:**
- **Client:** $EC_CLIENT
- **Version:** $EC_VERSION
- **Status:** $EC_STATUS
- **Sync:** $EC_SYNC

**Consensus Client:**
- **Client:** $CC_CLIENT
- **Version:** $CC_VERSION
- **Status:** $CC_STATUS
- **Sync:** $CC_SYNC

**MEV-Boost:**
- **Enabled:** $MEV_ENABLED
- **Relays:** [Check \`rocketpool service config\` MEV section]

$(if [ "$FALLBACK_ENABLED" = "true" ]; then
cat << FALLBACK
**Fallback Clients (HA):**
- **Enabled:** Yes
- **Fallback EC:** $FALLBACK_EC_URL
- **Fallback CC:** $FALLBACK_CC_URL
FALLBACK
fi)

### System Environment
- **Distribution:** $OS_INFO
- **Kernel:** $KERNEL
- **Architecture:** $ARCH
- **Uptime:** $UPTIME
- **Hardware:**
  - CPU: $CPU_INFO
  - RAM: $RAM_TOTAL
  - Storage: $DISK_USAGE
- **Network:**
  - External IP: [Check with: curl -s ifconfig.me]
  - Firewall: [Document your rules]
  - SSH Port: [Your custom port]

---

==============================================================================
DETAILED OUTPUT FOR REFERENCE
==============================================================================

=== Full Node Status ===
$NODE_STATUS

=== Full Service Status ===
$SERVICE_STATUS

=== Full Minipool Status ===
$MINIPOOL_STATUS

==============================================================================
NOTE: For detailed configuration settings, run: rocketpool service config
      Config files location: ~/.rocketpool/
==============================================================================
EOF
} > "$OUTPUT_FILE"

# Success message to stderr (so it doesn't interfere with file output)
echo "" >&2
echo "✓ Configuration data saved to: $OUTPUT_FILE" >&2
echo "" >&2
echo "NEXT STEPS:" >&2
echo "1. Open $OUTPUT_FILE and review the content" >&2
echo "2. Copy the markdown section into my-config.md, replacing the $NODE_NAME section" >&2
echo "3. Fill in any [bracketed] placeholders manually" >&2
echo "4. Verify sensitive addresses are correct" >&2
echo "" >&2
