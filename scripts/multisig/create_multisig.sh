#!/bin/bash
# Linera Multi-Owner Chain Creation Script for Conway Testnet
# Based on successful validation performed on Feb 2, 2026
# Updated for Linera CLI v0.15.8 (2026)
#
# This script creates a multi-owner chain on Linera Testnet Conway
# and validates the ownership configuration.

set -e

# ============================================
# CONFIGURATION
# ============================================

FAUCET_URL="https://faucet.testnet-conway.linera.net"
INITIAL_BALANCE=10  # Tokens to transfer to multi-owner chain

# Create timestamped working directory
WORK_DIR="$(mktemp -d -t linera-conway-$(date +%s)-XXXXXX)"
export LINERA_WALLET="$WORK_DIR/wallet.json"
export LINERA_KEYSTORE="$WORK_DIR/keystore.json"
export LINERA_STORAGE="rocksdb:$WORK_DIR/client.db:runtime:default"

echo "📁 Working directory: $WORK_DIR"

# ============================================
# STEP 1: Verify Requirements
# ============================================

step_1() {
    echo "🔍 Step 1: Verifying requirements..."

    # Check Linera CLI
    if ! command -v linera &> /dev/null; then
        echo "❌ linera CLI not found."
        echo "   Install from: https://linera.dev/developers/getting_started/index.html"
        exit 1
    fi

    # Check Python3 (for time measurement on macOS)
    if ! command -v python3 &> /dev/null; then
        echo "❌ python3 not found. Required for time measurement."
        echo "   Install with: brew install python3"
        exit 1
    fi

    echo "✅ All requirements verified"
    echo "   - linera CLI: $(linera --version 2>/dev/null | head -1 || echo 'installed')"
    echo "   - python3: $(python3 --version 2>&1)"
}

# ============================================
# STEP 2: Initialize Wallet from Faucet
# ============================================

step_2() {
    echo "💰 Step 2: Initializing wallet from faucet..."

    linera wallet init --faucet "$FAUCET_URL" > /dev/null 2>&1

    echo "✅ Wallet initialized with 1 chain"
}

# ============================================
# STEP 3: Request Second Chain from Faucet
# ============================================

step_3() {
    echo "💰 Step 3: Requesting second chain from faucet..."

    linera wallet request-chain --faucet "$FAUCET_URL" > /dev/null 2>&1

    echo "✅ Second chain requested from faucet"
}

# ============================================
# STEP 4: Query Initial State
# ============================================

step_4() {
    echo "📊 Step 4: Querying initial state..."

    # Get chain IDs using wallet show
    WALLET_OUTPUT=$(linera wallet show 2>/dev/null)

    # Extract chain IDs (look for Chain ID before DEFAULT/ADMIN tag)
    DEFAULT_CHAIN=$(echo "$WALLET_OUTPUT" | grep -B 1 'DEFAULT' | grep 'Chain ID:' | awk '{print $3}')
    ADMIN_CHAIN=$(echo "$WALLET_OUTPUT" | grep -B 1 'ADMIN' | grep 'Chain ID:' | awk '{print $3}')

    # Extract owner public key from DEFAULT chain
    OWNER=$(echo "$WALLET_OUTPUT" | grep -A 5 'DEFAULT' | grep 'Default owner:' | awk '{print $3}')

    echo "   DEFAULT Chain: $DEFAULT_CHAIN"
    echo "   ADMIN Chain:   $ADMIN_CHAIN"
    echo "   Owner: $OWNER"

    # Set variables for multi-owner chain creation
    # Use DEFAULT chain as source (it has the owner key)
    CHAIN1="$DEFAULT_CHAIN"
    CHAIN2="$ADMIN_CHAIN"

    # Query balance
    echo ""
    echo "   Querying balance for DEFAULT chain..."
    BALANCE=$(linera query-balance "$CHAIN1" 2>/dev/null | tr -d '.')
    echo "   Balance: $BALANCE tokens"
}

# ============================================
# STEP 5: Create Multi-Owner Chain
# ============================================

step_5() {
    echo "🔗 Step 5: Creating multi-owner chain..."

    echo "   Source chain: $CHAIN1 (DEFAULT, has owner key)"
    echo "   Owner: $OWNER"
    echo "   Initial balance: $INITIAL_BALANCE tokens"

    # Create multi-owner chain
    # Using simplified single-owner setup for testing
    linera open-multi-owner-chain \
        --from "$CHAIN1" \
        --owners "$OWNER" \
        --initial-balance "$INITIAL_BALANCE"

    echo "✅ Multi-owner chain created"
}

# ============================================
# STEP 6: Sync with Validators
# ============================================

step_6() {
    echo "🔄 Step 6: Syncing with validators..."

    # macOS compatible time measurement
    START_TIME=$(python3 -c "import time; print(int(time.time()*1000))")

    linera sync > /dev/null 2>&1

    END_TIME=$(python3 -c "import time; print(int(time.time()*1000))")
    SYNC_TIME=$((END_TIME - START_TIME))

    echo "✅ Sync completed in ${SYNC_TIME}ms"
}

# ============================================
# STEP 7: Validate Results
# ============================================

step_7() {
    echo "✔️  Step 7: Validating on-chain state..."

    # Get updated wallet state
    WALLET_OUTPUT=$(linera wallet show 2>/dev/null)

    # Count chains (should be 2 + 1 new multi-owner = 3)
    CHAIN_COUNT=$(echo "$WALLET_OUTPUT" | grep -c "^Chain ID:" || true)

    echo ""
    echo "═══════════════════════════════════════════════════════"
    echo "           VALIDATION RESULTS"
    echo "═══════════════════════════════════════════════════════"
    echo "Total chains in wallet: $CHAIN_COUNT (expected 3)"
    echo ""
    echo "$WALLET_OUTPUT"
    echo "═══════════════════════════════════════════════════════"
    echo ""

    # Show final balance of source chain
    SOURCE_BALANCE=$(linera query-balance "$CHAIN1" 2>/dev/null | tr -d '.')
    echo "Source chain balance: $SOURCE_BALANCE tokens"

    # Show ownership of the new multi-owner chain
    echo ""
    echo "═══════════════════════════════════════════════════════"
    echo "           MULTI-OWNER CHAIN DETAILS"
    echo "═══════════════════════════════════════════════════════"

    # Get the newly created chain ID (3rd chain in wallet)
    MULTISIG_CHAIN=$(echo "$WALLET_OUTPUT" | grep "^Chain ID:" | tail -1 | awk '{print $3}')
    echo "Multi-owner chain ID: $MULTISIG_CHAIN"
    echo ""

    # Show ownership configuration
    echo "Ownership configuration:"
    linera show-ownership --chain-id "$MULTISIG_CHAIN" 2>/dev/null || echo "  (Ownership query failed)"
    echo ""

    # Query balance of new multi-owner chain
    MULTISIG_BALANCE=$(linera query-balance "$MULTISIG_CHAIN" 2>/dev/null | tr -d '.')
    echo "Multi-owner chain balance: $MULTISIG_BALANCE tokens"
    echo "═══════════════════════════════════════════════════════"
}

# ============================================
# MAIN EXECUTION
# ============================================

main() {
    echo ""
    echo "╔═══════════════════════════════════════════════════════╗"
    echo "║   Linera Multi-Owner Chain Creation                  ║"
    echo "║   Testnet: Conway                                    ║"
    echo "╚═══════════════════════════════════════════════════════╝"
    echo ""

    step_1
    step_2
    step_3
    step_4
    step_5
    step_6
    step_7

    echo ""
    echo "🎉 Multi-owner chain creation completed!"
    echo "📁 Working directory: $WORK_DIR"
    echo ""
    echo "💡 To query this wallet later:"
    echo "   export LINERA_WALLET=\"$LINERA_WALLET\""
    echo "   export LINERA_KEYSTORE=\"$LINERA_KEYSTORE\""
    echo "   export LINERA_STORAGE=\"$LINERA_STORAGE\""
    echo "   linera wallet show"
}

main "$@"
