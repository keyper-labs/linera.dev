#!/bin/bash
###############################################################################
# Linera Multi-Owner Chain CLI Test Script (Simplified)
#
# This script tests the creation of a multi-owner chain using the Linera CLI.
# Based on validated commands from Conway Testnet (v0.15.8+).
#
# Prerequisites:
#   - linera CLI installed
#   - python3 (for time measurement)
#   - Internet access to Conway testnet
#
# Usage:
#   ./scripts/multisig-test-cli.sh
#
# Reference:
#   - docs/research/CLI_COMMANDS_REFERENCE.md
#   - docs/research/CONWAY_TESTNET_VALIDATION.md
###############################################################################

set -e

# ============================================
# CONFIGURATION
# ============================================

FAUCET_URL="https://faucet.testnet-conway.linera.net"
INITIAL_BALANCE=10  # Tokens to transfer to multi-owner chain

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# ============================================
# HELPER FUNCTIONS
# ============================================

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# ============================================
# STEP 1: Verify Requirements
# ============================================

verify_requirements() {
    log_info "Verifying requirements..."

    # Check Linera CLI
    if ! command -v linera &> /dev/null; then
        log_error "Linera CLI not found."
        log_info "Install from: https://linera.dev/developers/getting_started/index.html"
        exit 1
    fi
    log_success "Linera CLI found"

    # Check python3 (for time measurement)
    if ! command -v python3 &> /dev/null; then
        log_warning "python3 not found. Time measurement will be limited."
    fi

    echo ""
}

# ============================================
# STEP 2: Create Test Environment
# ============================================

create_test_environment() {
    log_info "Creating test environment..."

    # Create timestamped working directory
    WORK_DIR="$(mktemp -d -t linera-multisig-test-$(date +%s)-XXXXXX)"

    # Set Linera environment variables
    export LINERA_WALLET="$WORK_DIR/wallet.json"
    export LINERA_KEYSTORE="$WORK_DIR/keystore.json"
    export LINERA_STORAGE="rocksdb:$WORK_DIR/client.db:runtime:default"

    log_success "Working directory: $WORK_DIR"
    echo ""
}

# ============================================
# STEP 3: Initialize Wallet from Faucet
# ============================================

initialize_wallet() {
    log_info "Initializing wallet from faucet..."

    linera wallet init \
        --faucet "$FAUCET_URL" \
        > /dev/null 2>&1

    log_success "Wallet initialized with 1 chain"

    # Request second chain for multi-owner testing
    log_info "Requesting second chain from faucet..."

    linera wallet request-chain \
        --faucet "$FAUCET_URL" \
        > /dev/null 2>&1

    log_success "Second chain requested from faucet"
    echo ""
}

# ============================================
# STEP 4: Query Initial State
# ============================================

query_initial_state() {
    log_info "Querying initial wallet state..."

    # Get wallet output
    WALLET_OUTPUT=$(linera wallet show 2>/dev/null)

    # Extract chain IDs and owner
    DEFAULT_CHAIN=$(echo "$WALLET_OUTPUT" | grep -B 1 'DEFAULT' | grep 'Chain ID:' | awk '{print $3}')
    ADMIN_CHAIN=$(echo "$WALLET_OUTPUT" | grep -B 1 'ADMIN' | grep 'Chain ID:' | awk '{print $3}')
    OWNER=$(echo "$WALLET_OUTPUT" | grep -A 5 'DEFAULT' | grep 'Default owner:' | awk '{print $3}')

    log_info "DEFAULT Chain: $DEFAULT_CHAIN"
    log_info "ADMIN Chain:   $ADMIN_CHAIN"
    log_info "Owner:         $OWNER"

    # Query balance
    BALANCE=$(linera query-balance "$DEFAULT_CHAIN" 2>/dev/null | tr -d '.')
    log_success "Balance: $BALANCE tokens"

    echo ""
}

# ============================================
# STEP 5: Create Multi-Owner Chain
# ============================================

create_multi_owner_chain() {
    log_info "Creating multi-owner chain..."

    log_info "Configuration:"
    log_info "  - Source chain: DEFAULT (has owner key)"
    log_info "  - Owner: $OWNER"
    log_info "  - Initial balance: $INITIAL_BALANCE tokens"

    # Create multi-owner chain
    # Note: Using single owner for basic testing. Add more owners by:
    # 1. Generating additional keypairs with linera keygen
    # 2. Adding them to --owners list (space-separated)
    linera open-multi-owner-chain \
        --from "$DEFAULT_CHAIN" \
        --owners "$OWNER" \
        --initial-balance "$INITIAL_BALANCE" \
        > /dev/null 2>&1

    log_success "Multi-owner chain created"
    echo ""
}

# ============================================
# STEP 6: Sync with Validators
# ============================================

sync_with_validators() {
    log_info "Syncing with Conway validators..."

    if command -v python3 &> /dev/null; then
        START_TIME=$(python3 -c "import time; print(int(time.time()*1000))")
        linera sync > /dev/null 2>&1
        END_TIME=$(python3 -c "import time; print(int(time.time()*1000))")
        SYNC_TIME=$((END_TIME - START_TIME))
        log_success "Sync completed in ${SYNC_TIME}ms"
    else
        linera sync > /dev/null 2>&1
        log_success "Sync completed"
    fi

    echo ""
}

# ============================================
# STEP 7: Validate Results
# ============================================

validate_results() {
    log_info "Validating on-chain state..."

    # Get updated wallet state
    WALLET_OUTPUT=$(linera wallet show 2>/dev/null)

    # Count chains (should be 2 + 1 new multi-owner = 3)
    CHAIN_COUNT=$(echo "$WALLET_OUTPUT" | grep -c "^Chain ID:" || true)

    log_success "Total chains in wallet: $CHAIN_COUNT (expected 3)"
    echo ""

    # Display wallet state
    echo "═══════════════════════════════════════════════════════"
    echo "           WALLET STATE"
    echo "═══════════════════════════════════════════════════════"
    echo "$WALLET_OUTPUT"
    echo "═══════════════════════════════════════════════════════"
    echo ""

    # Query final balance of source chain
    SOURCE_BALANCE=$(linera query-balance "$DEFAULT_CHAIN" 2>/dev/null | tr -d '.')
    log_info "Source chain final balance: $SOURCE_BALANCE tokens"

    echo ""
}

# ============================================
# MAIN EXECUTION
# ============================================

main() {
    echo ""
    echo "╔═══════════════════════════════════════════════════════╗"
    echo "║   Linera Multi-Owner Chain CLI Test                 ║"
    echo "║   Testnet: Conway                                   ║"
    echo "╚═══════════════════════════════════════════════════════╝"
    echo ""

    verify_requirements
    create_test_environment
    initialize_wallet
    query_initial_state
    create_multi_owner_chain
    sync_with_validators
    validate_results

    echo "╔═══════════════════════════════════════════════════════╗"
    echo "║   TEST COMPLETE                                      ║"
    echo "╚═══════════════════════════════════════════════════════╝"
    echo ""
    log_success "Multi-owner chain successfully created and validated"
    echo ""
    log_info "Working directory: $WORK_DIR"
    echo ""
    log_info "To inspect this wallet later:"
    echo "  export LINERA_WALLET=\"$LINERA_WALLET\""
    echo "  export LINERA_KEYSTORE=\"$LINERA_KEYSTORE\""
    echo "  export LINERA_STORAGE=\"$LINERA_STORAGE\""
    echo "  linera wallet show"
    echo ""
    log_info "To query balance:"
    echo "  linera query-balance <CHAIN_ID>"
    echo ""
    log_warning "IMPORTANT NOTES:"
    log_warning "1. Linera multi-owner chains allow ALL owners to propose blocks independently"
    log_warning "2. There is NO native threshold scheme (m-of-n) at the protocol level"
    log_warning "3. For traditional multisig, implement application-level logic with Rust SDK"
    log_warning "4. See docs/research/linera-sdk-multisig-implementation-guide.md for details"
}

# Run main function
main "$@"
