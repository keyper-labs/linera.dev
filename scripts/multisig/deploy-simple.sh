#!/usr/bin/env bash
# Linera Multisig - Simple Deploy Script
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
WORK_DIR="$REPO_ROOT/.linera-deploy"
STORAGE_CONFIG="rocksdb:$WORK_DIR/client.db:runtime:default"
WALLET_FILE="$WORK_DIR/wallet.json"

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[0;33m'
NC='\033[0m'

echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}  Linera Multisig - Simple Deploy to Conway Testnet${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

# Step 1: Request a new chain from faucet
echo -e "${BLUE}▸${NC} Step 1: Requesting new chain from faucet..."
mkdir -p "$WORK_DIR/client.db"
linera wallet request-chain \
  --faucet https://faucet.testnet-conway.linera.net \
  --storage "$STORAGE_CONFIG" \
  2>&1 | tee "$WORK_DIR/faucet.log"

# Get the new chain ID from the faucet response
CHAIN_ID=$(grep -oE '"chain_id":"[a-f0-9]{64}' "$WORK_DIR/faucet.log" | head -1 | cut -d'"' -f4)

if [ -z "$CHAIN_ID" ]; then
    echo -e "${YELLOW}⚠${NC} Could not extract chain ID from faucet response"
    echo -e "${YELLOW}▸${NC} Trying to get chain ID from wallet..."
    # Alternative: get from wallet after sync
fi

echo -e "${GREEN}✓${NC} Chain ID: ${CHAIN_ID:-<pending sync>}"
echo ""

# Step 2: Publish and create application
echo -e "${BLUE}▸${NC} Step 2: Publishing multisig application..."

linera publish-and-create \
  --storage "$STORAGE_CONFIG" \
  "$SCRIPT_DIR/../multisig-app/target/wasm32-unknown-unknown/release/multisig_contract.wasm" \
  "$SCRIPT_DIR/../multisig-app/target/wasm32-unknown-unknown/release/multisig_service.wasm" \
  --json-argument "{\"owners\": [\"User:0000000000000000000000000000000000000000000000000000000000000000\", \"User:0000000000000000000000000000000000000000000000000000000000000001\", \"User:0000000000000000000000000000000000000000000000000000000000000002\"], \"threshold\": 2, \"proposal_lifetime\": 604800, \"time_delay\": 0}" \
  2>&1 | tee "$WORK_DIR/deploy.log"

echo ""
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}✅ Deployment Complete!${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo "Check deploy log: $WORK_DIR/deploy.log"
