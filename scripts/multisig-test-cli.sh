#!/bin/bash

###############################################################################
# Linera Multisig Wallet CLI Test Script
#
# This script tests the creation of a multi-owner chain using the Linera CLI.
# Note: Linera doesn't have native threshold multisig (m-of-n). Multi-owner
# chains allow all owners to propose blocks independently. Application-level
# logic is required for traditional multisig functionality.
#
# Environment Variables Required:
#   LINERA_WALLET    - Path to wallet file (default: wallet.json)
#   LINERA_STORAGE   - Path to wallet storage (default: rocksdb:wallet.db:runtime:default)
#   LINERA_KEYSTORE  - Path to keystore (default: keystore.db)
#   FAUCET_URL       - Faucet URL for testnet (default: http://localhost:8080)
#
# Usage:
#   source scripts/multisig-test-cli.sh
###############################################################################

set -e

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
WALLET_DIR="${WALLET_DIR:-$(pwd)/test-wallets}"
FAUCET_URL="${FAUCET_URL:-http://localhost:8080}"

# Helper functions
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

check_linera() {
    if ! command -v linera &> /dev/null; then
        log_error "Linera CLI not found. Please install it first."
        log_info "Visit: https://linera.dev/developers/getting_started/index.html"
        exit 1
    fi
    log_success "Linera CLI found"
}

init_wallets() {
    log_info "Initializing test wallets..."

    # Create wallet directory
    mkdir -p "$WALLET_DIR"
    cd "$WALLET_DIR"

    # Initialize Owner 1 wallet
    log_info "Creating wallet for Owner 1..."
    LINERA_WALLET=owner1_wallet.json \
    LINERA_STORAGE=rocksdb:owner1.db:runtime:default \
    LINERA_KEYSTORE=owner1_keystore.db \
    linera wallet init --faucet "$FAUCET_URL" >/dev/null 2>&1 || true

    # Initialize Owner 2 wallet
    log_info "Creating wallet for Owner 2..."
    LINERA_WALLET=owner2_wallet.json \
    LINERA_STORAGE=rocksdb:owner2.db:runtime:default \
    LINERA_KEYSTORE=owner2_keystore.db \
    linera wallet init --faucet "$FAUCET_URL" >/dev/null 2>&1 || true

    # Initialize Owner 3 wallet
    log_info "Creating wallet for Owner 3..."
    LINERA_WALLET=owner3_wallet.json \
    LINERA_STORAGE=rocksdb:owner3.db:runtime:default \
    LINERA_KEYSTORE=owner3_keystore.db \
    linera wallet init --faucet "$FAUCET_URL" >/dev/null 2>&1 || true

    log_success "3 test wallets initialized"
}

request_chains() {
    log_info "Requesting chains from faucet..."

    # Request chain for Owner 1
    log_info "Requesting chain for Owner 1..."
    OWNER1_INFO=$(LINERA_WALLET=owner1_wallet.json \
                  LINERA_STORAGE=rocksdb:owner1.db:runtime:default \
                  LINERA_KEYSTORE=owner1_keystore.db \
                  linera wallet request-chain --faucet "$FAUCET_URL")
    OWNER1_CHAIN=$(echo "$OWNER1_INFO" | head -n1)
    OWNER1_ACCOUNT=$(echo "$OWNER1_INFO" | tail -n1)
    log_success "Owner 1 chain: $OWNER1_CHAIN"

    # Request chain for Owner 2
    log_info "Requesting chain for Owner 2..."
    OWNER2_INFO=$(LINERA_WALLET=owner2_wallet.json \
                  LINERA_STORAGE=rocksdb:owner2.db:runtime:default \
                  LINERA_KEYSTORE=owner2_keystore.db \
                  linera wallet request-chain --faucet "$FAUCET_URL")
    OWNER2_CHAIN=$(echo "$OWNER2_INFO" | head -n1)
    OWNER2_ACCOUNT=$(echo "$OWNER2_INFO" | tail -n1)
    log_success "Owner 2 chain: $OWNER2_CHAIN"

    # Request chain for Owner 3
    log_info "Requesting chain for Owner 3..."
    OWNER3_INFO=$(LINERA_WALLET=owner3_wallet.json \
                  LINERA_STORAGE=rocksdb:owner3.db:runtime:default \
                  LINERA_KEYSTORE=owner3_keystore.db \
                  linera wallet request-chain --faucet "$FAUCET_URL")
    OWNER3_CHAIN=$(echo "$OWNER3_INFO" | head -n1)
    OWNER3_ACCOUNT=$(echo "$OWNER3_INFO" | tail -n1)
    log_success "Owner 3 chain: $OWNER3_CHAIN"

    # Export chain IDs for use in tests
    export OWNER1_CHAIN OWNER1_ACCOUNT
    export OWNER2_CHAIN OWNER2_ACCOUNT
    export OWNER3_CHAIN OWNER3_ACCOUNT

    # Save to file for reference
    cat > chain_ids.txt <<EOF
OWNER1_CHAIN=$OWNER1_CHAIN
OWNER1_ACCOUNT=$OWNER1_ACCOUNT
OWNER2_CHAIN=$OWNER2_CHAIN
OWNER2_ACCOUNT=$OWNER2_ACCOUNT
OWNER3_CHAIN=$OWNER3_CHAIN
OWNER3_ACCOUNT=$OWNER3_ACCOUNT
EOF
    log_success "Chain IDs saved to chain_ids.txt"
}

generate_owner_keys() {
    log_info "Generating unassigned keypairs for each owner..."

    # Owner 2 generates key
    OWNER2_PUBLIC_KEY=$(LINERA_WALLET=owner2_wallet.json \
                        LINERA_STORAGE=rocksdb:owner2.db:runtime:default \
                        LINERA_KEYSTORE=owner2_keystore.db \
                        linera keygen)
    log_success "Owner 2 public key: $OWNER2_PUBLIC_KEY"

    # Owner 3 generates key
    OWNER3_PUBLIC_KEY=$(LINERA_WALLET=owner3_wallet.json \
                        LINERA_STORAGE=rocksdb:owner3.db:runtime:default \
                        LINERA_KEYSTORE=owner3_keystore.db \
                        linera keygen)
    log_success "Owner 3 public key: $OWNER3_PUBLIC_KEY"

    export OWNER2_PUBLIC_KEY OWNER3_PUBLIC_KEY
}

create_simple_multi_owner_chain() {
    log_info "=== Creating Simple Multi-Owner Chain ==="
    log_warning "Note: This uses 'open-chain' which creates a chain for a single owner"
    log_warning "For true multi-owner chains, use the advanced 'open-multi-owner-chain' command"

    # Create a chain for Owner 2 from Owner 1's chain
    log_info "Creating chain for Owner 2 (from Owner 1)..."
    RESULT=$(LINERA_WALLET=owner1_wallet.json \
             LINERA_STORAGE=rocksdb:owner1.db:runtime:default \
             LINERA_KEYSTORE=owner1_keystore.db \
             linera open-chain --to-public-key "$OWNER2_PUBLIC_KEY")

    MESSAGE_ID=$(echo "$RESULT" | head -n1)
    NEW_CHAIN=$(echo "$RESULT" | tail -n1)

    log_success "New chain created!"
    log_info "Message ID: $MESSAGE_ID"
    log_info "Chain ID: $NEW_CHAIN"

    export NEW_CHAIN
}

create_advanced_multi_owner_chain() {
    log_info "=== Creating Advanced Multi-Owner Chain ==="
    log_warning "Note: This command gives fine-grained control over owners and rounds"

    # Get Owner 1's public key
    OWNER1_PUBLIC_KEY=$(LINERA_WALLET=owner1_wallet.json \
                        LINERA_STORAGE=rocksdb:owner1.db:runtime:default \
                        LINERA_KEYSTORE=owner1_keystore.db \
                        linera wallet show | grep "Public Key:" | head -n1 | awk '{print $3}')

    log_info "Owner 1 public key: $OWNER1_PUBLIC_KEY"

    # Create multi-owner chain with all three owners
    log_info "Creating multi-owner chain with 3 owners..."
    RESULT=$(LINERA_WALLET=owner1_wallet.json \
             LINERA_STORAGE=rocksdb:owner1.db:runtime:default \
             LINERA_KEYSTORE=owner1_keystore.db \
             linera open-multi-owner-chain \
             --owners "$OWNER1_PUBLIC_KEY,$OWNER2_PUBLIC_KEY,$OWNER3_PUBLIC_KEY" \
             --multi-leader-rounds 2)

    MESSAGE_ID=$(echo "$RESULT" | head -n1)
    MULTI_OWNER_CHAIN=$(echo "$RESULT" | tail -n1)

    log_success "Multi-owner chain created!"
    log_info "Message ID: $MESSAGE_ID"
    log_info "Chain ID: $MULTI_OWNER_CHAIN"
    log_info "Owners: Owner 1, Owner 2, Owner 3"
    log_info "Configuration: 2 multi-leader rounds, then single-leader rounds"

    export MULTI_OWNER_CHAIN
}

show_wallets() {
    log_info "=== Wallet States ==="

    echo ""
    log_info "Owner 1 Wallet:"
    LINERA_WALLET=owner1_wallet.json \
    LINERA_STORAGE=rocksdb:owner1.db:runtime:default \
    LINERA_KEYSTORE=owner1_keystore.db \
    linera wallet show || true

    echo ""
    log_info "Owner 2 Wallet:"
    LINERA_WALLET=owner2_wallet.json \
    LINERA_STORAGE=rocksdb:owner2.db:runtime:default \
    LINERA_KEYSTORE=owner2_keystore.db \
    linera wallet show || true

    echo ""
    log_info "Owner 3 Wallet:"
    LINERA_WALLET=owner3_wallet.json \
    LINERA_STORAGE=rocksdb:owner3.db:runtime:default \
    LINERA_KEYSTORE=owner3_keystore.db \
    linera wallet show || true
}

test_multi_owner_operations() {
    log_info "=== Testing Multi-Owner Chain Operations ==="
    log_warning "Each owner can independently propose blocks on the multi-owner chain"

    # Note: This would require actual operations to test
    # For now, we just demonstrate the structure

    log_info "To test operations, each owner would:"
    log_info "1. Sync their wallet: linera sync $MULTI_OWNER_CHAIN"
    log_info "2. Process inbox: linera process-inbox"
    log_info "3. Create blocks with operations"
    log_info ""
    log_warning "Note: All owners can propose blocks independently"
    log_warning "For threshold-based multisig (m-of-n), application-level logic is required"
}

cleanup() {
    log_info "Cleaning up test wallets..."
    cd /  # Leave wallet directory
    read -p "Delete test wallets in $WALLET_DIR? (y/N) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        rm -rf "$WALLET_DIR"
        log_success "Test wallets deleted"
    else
        log_info "Test wallets preserved in $WALLET_DIR"
    fi
}

# Main execution
main() {
    log_info "=== Linera Multi-Owner Chain CLI Test ==="
    log_info "Wallet directory: $WALLET_DIR"
    log_info "Faucet URL: $FAUCET_URL"
    echo ""

    check_linera
    init_wallets
    echo ""

    request_chains
    echo ""

    generate_owner_keys
    echo ""

    create_simple_multi_owner_chain
    echo ""

    create_advanced_multi_owner_chain
    echo ""

    show_wallets
    echo ""

    test_multi_owner_operations
    echo ""

    log_success "=== Test Complete ==="
    log_info "Chain IDs saved to $WALLET_DIR/chain_ids.txt"
    log_info ""
    log_warning "Important Notes:"
    log_warning "1. Linera multi-owner chains allow all owners to propose blocks independently"
    log_warning "2. There is NO native threshold scheme (m-of-n) at the protocol level"
    log_warning "3. For traditional multisig, implement application-level logic with Rust SDK"
    log_warning "4. See scripts/multisig-test-rust.sh for SDK-based multisig implementation"
}

# Run main function
main "$@"
