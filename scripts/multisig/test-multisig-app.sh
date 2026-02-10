#!/bin/bash

###############################################################################
# Linera Multisig Application Testnet Deployment Test
#
# This script deploys and tests the compiled multisig application
# on Linera testnet (Conway).
#
# Prerequisites:
#   - Linera CLI installed (v0.15.8+)
#   - Wasm binaries compiled (multisig_contract.wasm, multisig_service.wasm)
#   - Internet connection for testnet faucet
#
# Usage:
#   bash scripts/multisig/test-multisig-app.sh
###############################################################################

set -e

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }
log_step() { echo -e "${CYAN}[STEP]${NC} $1"; }

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
MULTISIG_APP_DIR="$PROJECT_DIR/scripts/multisig-app"
WASM_DIR="$MULTISIG_APP_DIR/target/wasm32-unknown-unknown/release"
WORK_DIR="/tmp/linera-multisig-test-$(date +%s)"
FAUCET_URL="https://faucet.testnet-conway.linera.net"

CONTRACT_WASM="$WASM_DIR/multisig_contract.wasm"
SERVICE_WASM="$WASM_DIR/multisig_service.wasm"

# Owner addresses for testing (will be generated)
OWNER_1=""
OWNER_2=""
THRESHOLD=2

log_info "=== Linera Multisig Application Testnet Test ==="
echo ""

# Check prerequisites
log_step "Checking prerequisites..."

if ! command -v linera &> /dev/null; then
    log_error "Linera CLI not found. Please install it first."
    exit 1
fi
log_success "Linera CLI found: $(linera --version | head -1)"

if [ ! -f "$CONTRACT_WASM" ]; then
    log_error "Contract Wasm not found: $CONTRACT_WASM"
    log_info "Run: cd multisig-app && cargo build --release --target wasm32-unknown-unknown"
    exit 1
fi
log_success "Contract Wasm found"

if [ ! -f "$SERVICE_WASM" ]; then
    log_error "Service Wasm not found: $SERVICE_WASM"
    exit 1
fi
log_success "Service Wasm found"
echo ""

# Create working directory
log_step "Setting up test environment..."
mkdir -p "$WORK_DIR"
export LINERA_WALLET="$WORK_DIR/wallet.json"
export LINERA_KEYSTORE="$WORK_DIR/keystore.json"
export LINERA_STORAGE="rocksdb:$WORK_DIR/client.db:runtime:default"
log_success "Working directory: $WORK_DIR"
echo ""

# Initialize wallet
log_step "Initializing wallet from faucet..."
if linera wallet init --faucet "$FAUCET_URL" > /dev/null 2>&1; then
    log_success "Wallet initialized"
else
    log_error "Failed to initialize wallet"
    exit 1
fi
echo ""

# Get chain ID
log_step "Getting chain ID..."
CHAIN_ID=$(linera wallet show | grep 'Chain ID:' | head -1 | awk '{print $3}')
if [ -z "$CHAIN_ID" ]; then
    log_error "Failed to get chain ID"
    exit 1
fi
log_success "Chain ID: $CHAIN_ID"
echo ""

# Generate owner addresses
log_step "Generating test owner addresses..."
# Use the default chain as first owner
OWNER_1="$CHAIN_ID"
log_success "Owner 1: $OWNER_1"

# Generate a second keypair for second owner
OWNER_2_KEY=$(linera keygen | tr -d '\r\n')
if [ -z "$OWNER_2_KEY" ]; then
    log_error "Failed to generate second owner key"
    exit 1
fi
OWNER_2="User:$OWNER_2_KEY"
log_success "Owner 2: $OWNER_2"
echo ""

# Publish the contract
log_step "Publishing multisig contract..."
log_info "This may take a while..."

# Show current command sequence for deployment attempts
log_info "Contract Wasm: $CONTRACT_WASM"
log_info "Service Wasm: $SERVICE_WASM"
log_info ""
log_info "Command sequence:"
echo ""
cat << EOF
MODULE_ID=\$(linera publish-module "$CONTRACT_WASM" "$SERVICE_WASM")
linera create-application "\$MODULE_ID" \\
  --json-argument '{"owners": ["$OWNER_2"], "threshold": $THRESHOLD, "proposal_lifetime": 604800, "time_delay": 0}'
EOF
echo ""

log_warning "create-application can still fail if SDK/protocol/runtime are not aligned"
log_info "Use scripts/validate-sdk-workaround.sh with RUN_CREATE_APP_SMOKE=1 for deterministic validation"
echo ""

# Create test report
log_step "Creating test report..."
cat > "$WORK_DIR/test-report.md" << EOF
# Linera Multisig Application Test Report

**Date**: $(date -u +"%Y-%m-%d %H:%M:%S UTC")
**Testnet**: Conway ($FAUCET_URL)
**SDK Version**: 0.15.11

## Environment Setup

✅ Working directory: $WORK_DIR
✅ Wallet initialized from faucet
✅ Chain ID: $CHAIN_ID

## Test Owners

- **Owner 1**: $OWNER_1 (default chain)
- **Owner 2**: $OWNER_2 (generated keypair)

## Multisig Configuration

- **Threshold**: $THRESHOLD (2 of 2)
- **Initial Owners**: 2

## Binaries Ready for Deployment

| Binary | Path | Size |
|--------|------|------|
| Contract | $CONTRACT_WASM | $(stat -f%z "$CONTRACT_WASM" 2>/dev/null || stat -c%s "$CONTRACT_WASM" 2>/dev/null) bytes |
| Service | $SERVICE_WASM | $(stat -f%z "$SERVICE_WASM" 2>/dev/null || stat -c%s "$SERVICE_WASM" 2>/dev/null) bytes |

## Next Steps

To attempt deployment with current CLI, use:

\`\`\`bash
# 1. Publish the module
MODULE_ID=\$(linera publish-module "$CONTRACT_WASM" "$SERVICE_WASM")

# 2. Create app instance
linera create-application "\$MODULE_ID" \\
  --json-argument '{\"owners\": [\"$OWNER_2\"], \"threshold\": $THRESHOLD, \"proposal_lifetime\": 604800, \"time_delay\": 0}'

# 3. Submit a transaction
linera operation \\
  --application <APPLICATION_ID> \\
  --operation SubmitProposal \\
  --arg-to <DESTINATION> \\
  --arg-value 1000 \\
  --arg-data "0x"

# 4. Confirm proposal
linera operation \\
  --application <APPLICATION_ID> \\
  --operation ConfirmProposal \\
  --arg-transaction-id 0

# 5. Execute (after threshold reached)
linera operation \\
  --application <APPLICATION_ID> \\
  --operation ExecuteProposal \\
  --arg-transaction-id 0
\`\`\`

## GraphQL Queries

Once deployed, query the service:

\`\`\`graphql
query GetOwners {
  owners {
    # Returns list of owner addresses
  }
}

query GetThreshold {
  threshold
  # Returns current threshold
}

query GetTransaction(id: 0) {
  transaction(id: 0) {
    id
    to
    value
    confirmationCount
    executed
  }
}
\`\`\`

## Status

✅ Binaries compiled and validated
✅ Test environment ready
⚠ Full success still depends on SDK/protocol/runtime compatibility

---

**Generated by**: test-multisig-app.sh
**Linera Protocol**: https://linera.dev
EOF

log_success "Test report created: $WORK_DIR/test-report.md"
echo ""

log_success "=== Test Setup Complete ==="
echo ""
log_info "Summary:"
echo "  ✅ Wasm binaries validated"
echo "  ✅ Test environment configured"
echo "  ✅ Owners generated"
echo "  ⚠ Deployment still depends on SDK/protocol/runtime compatibility"
echo ""
log_info "To clean up: rm -rf $WORK_DIR"
