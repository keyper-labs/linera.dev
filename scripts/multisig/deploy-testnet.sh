#!/usr/bin/env bash
# Linera Multisig Application - Testnet Deployment Script
# Copyright (c) 2025 PalmeraDAO
# SPDX-License-Identifier: MIT

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MULTISIG_APP_DIR="$SCRIPT_DIR/../multisig-app"
WASM_CONTRACT="$MULTISIG_APP_DIR/target/wasm32-unknown-unknown/release/multisig_contract.wasm"
WASM_SERVICE="$MULTISIG_APP_DIR/target/wasm32-unknown-unknown/release/multisig_service.wasm"

# Linera configuration
LINERA_HOME="${LINERA_HOME:-$HOME/.linera}"
LINERA_WALLET="$LINERA_HOME/wallet.toml"
LINERA_STORAGE="$LINERA_HOME/storage.db"

echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}  Linera Multisig App - Testnet Deployment${NC}"
echo -e "${BLUE}  Testnet: Conway${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

# ============================================================================
# Pre-flight Checks
# ============================================================================

echo -e "${BLUE}[STEP]${NC} Pre-flight Checks"
echo "─────────────────────────────────────────────────────────"

# Check if Wasm files exist
if [[ ! -f "$WASM_CONTRACT" ]]; then
    echo -e "${RED}[ERROR]${NC} Contract Wasm not found: $WASM_CONTRACT"
    echo "Run: cd $MULTISIG_APP_DIR && cargo build --release"
    exit 1
fi
echo -e "${GREEN}[SUCCESS]${NC} Contract Wasm: $(wc -c < "$WASM_CONTRACT") bytes"

if [[ ! -f "$WASM_SERVICE" ]]; then
    echo -e "${RED}[ERROR]${NC} Service Wasm not found: $WASM_SERVICE"
    echo "Run: cd $MULTISIG_APP_DIR && cargo build --release"
    exit 1
fi
echo -e "${GREEN}[SUCCESS]${NC} Service Wasm: $(wc -c < "$WASM_SERVICE") bytes"

# Check Linera wallet
if [[ ! -f "$LINERA_WALLET" ]]; then
    echo -e "${YELLOW}[WARNING]${NC} Wallet not found, initializing from faucet..."
    linera wallet init --faucet https://faucet.conway.linera.net > /dev/null 2>&1
fi
echo -e "${GREEN}[SUCCESS]${NC} Wallet configured"

# Get chain info
CHAIN_ID=$(linera wallet show 2>/dev/null | grep 'Chain ID:' | head -1 | awk '{print $3}' || echo "")
if [[ -z "$CHAIN_ID" ]]; then
    echo -e "${RED}[ERROR]${NC} Could not get chain ID"
    exit 1
fi
echo -e "${GREEN}[SUCCESS]${NC} Chain ID: $CHAIN_ID"

echo ""

# ============================================================================
# Publish Application
# ============================================================================

echo -e "${BLUE}[STEP]${NC} Publishing Multisig Application"
echo "─────────────────────────────────────────────────────────"

# Configuration for test multisig
NUM_OWNERS=${NUM_OWNERS:-3}
THRESHOLD=${THRESHOLD:-2}
PROPOSAL_LIFETIME=${PROPOSAL_LIFETIME:-604800}  # 7 days
TIME_DELAY=${TIME_DELAY:-0}  # Disabled (Safe native)

echo -e "${BLUE}Configuration:${NC}"
echo "  Owners: $NUM_OWNERS"
echo "  Threshold: $THRESHOLD"
echo "  Proposal Lifetime: ${PROPOSAL_LIFETIME}s ($(($PROPOSAL_LIFETIME / 86400)) days)"
echo "  Time Delay: ${TIME_DELAY}s (disabled)"

# Create application parameters (JSON) with actual owners
APP_PARAMS="$SCRIPT_DIR/app_params.json"
cat > "$APP_PARAMS" << EOF
{
  "owners": [
    "$CHAIN_ID",
    "User:0000000000000000000000000000000000000000000000000000000000000001",
    "User:0000000000000000000000000000000000000000000000000000000000000002"
  ],
  "threshold": $THRESHOLD,
  "proposal_lifetime": $PROPOSAL_LIFETIME,
  "time_delay": $TIME_DELAY
}
EOF

echo ""
echo -e "${BLUE}▸${NC} Publishing application with instantiation..."
PUBLISH_OUTPUT=$(linera publish-and-create "$WASM_CONTRACT" "$WASM_SERVICE" "$APP_PARAMS" 2>&1)

if echo "$PUBLISH_OUTPUT" | grep -q "Created application"; then
    APP_ID=$(echo "$PUBLISH_OUTPUT" | grep "Created application" | awk '{print $3}')
    echo -e "${GREEN}[SUCCESS]${NC} Application published: $APP_ID"
else
    echo -e "${RED}[ERROR]${NC} Failed to publish application"
    echo "$PUBLISH_OUTPUT"
    exit 1
fi

echo ""

# ============================================================================
# Summary
# ============================================================================

echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}✅ Deployment Complete!${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo -e "${BLUE}Application ID:${NC} $APP_ID"
echo -e "${BLUE}Chain ID:${NC}     $CHAIN_ID"
echo ""
echo -e "${YELLOW}Next Steps:${NC}"
echo "  1. Test proposal submission:"
echo "     linera query \"$APP_ID\" { owners }"
echo ""
echo "  2. Submit a proposal (example):"
echo "     linera operation \"$APP_ID\" '{\"SubmitProposal\": {...}}'"
echo ""
echo "  3. Monitor logs:"
echo "     linera log-stream"
echo ""

# Cleanup temp files
rm -f "$APP_PARAMS"

exit 0
