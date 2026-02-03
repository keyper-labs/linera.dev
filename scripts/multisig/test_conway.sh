#!/bin/bash
# Simple test script for Conway testnet multi-owner chain creation

set -e

# Create working directory
WORK_DIR="/tmp/linera-conway-test-$(date +%s)"
mkdir -p "$WORK_DIR"
export LINERA_WALLET="$WORK_DIR/wallet.json"
export LINERA_KEYSTORE="$WORK_DIR/keystore.json"
export LINERA_STORAGE="rocksdb:$WORK_DIR/client.db:runtime:default"

echo "📁 Working directory: $WORK_DIR"

# Step 1: Initialize wallet
echo "🔧 Initializing wallet..."
linera wallet init --faucet https://faucet.testnet-conway.linera.net

# Step 2: Request second chain
echo "🔧 Requesting second chain..."
linera wallet request-chain --faucet https://faucet.testnet-conway.linera.net

# Step 3: Show wallet
echo ""
echo "📊 Wallet state:"
linera wallet show

# Step 4: Query balance
echo ""
echo "💰 Querying balance..."
CHAIN_ID=$(linera wallet show | grep 'Chain ID:' | head -1 | awk '{print $3}')
echo "Chain ID: $CHAIN_ID"
linera query-balance "$CHAIN_ID"

echo ""
echo "✅ Test completed!"
echo "📁 Working directory: $WORK_DIR"
