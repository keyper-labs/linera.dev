#!/usr/bin/env bash
# =============================================================================
# E2E Multisig Verification on Conway Testnet
# =============================================================================
#
# This script deploys a fresh 2-of-3 multisig contract to Conway testnet and
# exercises every core operation, capturing full GraphQL responses for each
# transaction. Anyone can run it to reproduce the proof of execution.
#
# What it tests:
#   1. Fresh deployment (build → wallet → multi-owner chain → publish → create app)
#   2. ChangeThreshold (2→1) via multi-owner confirmation flow
#   3. Transfer (1 token from chain balance to Owner2)
#   4. ChangeThreshold (1→2, restore)
#   5. RevokeConfirmation
#   6. AddOwner via multi-owner confirmation flow
#
# Prerequisites:
#   - linera CLI installed (v0.15.11 recommended)
#   - Rust 1.86.0 with wasm32-unknown-unknown target
#   - Internet access to Conway testnet faucet
#
# Usage:
#   ./scripts/e2e-multisig-conway.sh                      # full run
#   SKIP_BUILD=1 ./scripts/e2e-multisig-conway.sh         # skip wasm build
#   DEPLOY_ENV=path/to/deploy.env ./scripts/e2e-multisig-conway.sh  # reuse existing deployment
#
# Output:
#   Results are saved to .linera-deploy/e2e_verify_<timestamp>/
#   A summary report is printed at the end and saved to results.md
#
# =============================================================================

set -euo pipefail

# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
APP_DIR="$REPO_ROOT/scripts/multisig-app"
FAUCET_URL="${FAUCET_URL:-https://faucet.testnet-conway.linera.net}"
RUST_TOOLCHAIN="${RUST_TOOLCHAIN:-1.86.0}"
SKIP_BUILD="${SKIP_BUILD:-0}"
DEPLOY_ENV="${DEPLOY_ENV:-}"
SERVICE_PORT="${SERVICE_PORT:-8120}"
SERVICE_WAIT_SECS="${SERVICE_WAIT_SECS:-8}"
CURL_TIMEOUT="${CURL_TIMEOUT:-120}"

# Retry configuration for transient network errors
MAX_RETRIES="${MAX_RETRIES:-8}"
RETRY_DELAY="${RETRY_DELAY:-3}"

TIMESTAMP="$(date -u +%Y%m%d_%H%M%S)"
SESSION_DIR="$REPO_ROOT/.linera-deploy/e2e_verify_${TIMESTAMP}"
RESULTS_LOG="$SESSION_DIR/results.log"
RESULTS_MD="$SESSION_DIR/results.md"
SERVICE_LOG="$SESSION_DIR/service.log"

# Resolve linera binary
PINNED_LINERA_BIN="$REPO_ROOT/.tools/linera-0.15.11/bin/linera"
if [[ -x "$PINNED_LINERA_BIN" ]]; then
  LINERA_BIN="${LINERA_BIN:-$PINNED_LINERA_BIN}"
else
  LINERA_BIN="${LINERA_BIN:-$(command -v linera 2>/dev/null || true)}"
fi

CONTRACT_WASM="$APP_DIR/target/wasm32-unknown-unknown/release/multisig_contract.wasm"
SERVICE_WASM="$APP_DIR/target/wasm32-unknown-unknown/release/multisig_service.wasm"

# ---------------------------------------------------------------------------
# Colors and logging
# ---------------------------------------------------------------------------
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

log_step()  { echo -e "\n${BOLD}${BLUE}=== $1 ===${NC}"; echo "=== $1 ===" >> "$RESULTS_LOG"; }
log_info()  { echo -e "${CYAN}[INFO]${NC} $1"; echo "[INFO] $1" >> "$RESULTS_LOG"; }
log_ok()    { echo -e "${GREEN}[PASS]${NC} $1"; echo "[PASS] $1" >> "$RESULTS_LOG"; }
log_warn()  { echo -e "${YELLOW}[WARN]${NC} $1"; echo "[WARN] $1" >> "$RESULTS_LOG"; }
log_err()   { echo -e "${RED}[FAIL]${NC} $1"; echo "[FAIL] $1" >> "$RESULTS_LOG"; }
log_tx()    { echo -e "${GREEN}[TX]${NC} $1"; echo "[TX] $1" >> "$RESULTS_LOG"; }

# ---------------------------------------------------------------------------
# Counters for summary
# ---------------------------------------------------------------------------
TOTAL_TESTS=0
PASSED_TESTS=0
FAILED_TESTS=0
TX_COUNT=0

assert_pass() {
  TOTAL_TESTS=$((TOTAL_TESTS + 1))
  local label="$1"
  local condition="$2"
  if eval "$condition"; then
    PASSED_TESTS=$((PASSED_TESTS + 1))
    log_ok "$label"
  else
    FAILED_TESTS=$((FAILED_TESTS + 1))
    log_err "$label"
  fi
}

# ---------------------------------------------------------------------------
# Transient error detection and retry
# ---------------------------------------------------------------------------
is_transient_network_error() {
  local text="$1"
  [[ "$text" == *"Blobs not found"* ]] \
    || [[ "$text" == *"Round number should be Fast"* ]] \
    || [[ "$text" == *"Not signing timeout certificate"* ]] \
    || [[ "$text" == *"The service is currently unavailable"* ]] \
    || [[ "$text" == *"tcp connect error"* ]] \
    || [[ "$text" == *"received fatal alert: InternalError"* ]] \
    || [[ "$text" == *"SubscriptionFailed"* ]] \
    || [[ "$text" == *"timed out"* ]] \
    || [[ "$text" == *"connection reset"* ]]
}

run_with_retry() {
  local label="$1"; shift
  local attempt=1
  local output="" rc=0 delay=0

  while [[ "$attempt" -le "$MAX_RETRIES" ]]; do
    set +e
    output="$("$@" 2>&1)"
    rc=$?
    set -e

    if [[ "$rc" -eq 0 ]]; then
      printf '%s' "$output"
      return 0
    fi

    if ! is_transient_network_error "$output"; then
      printf '%s\n' "$output" >&2
      return "$rc"
    fi

    if [[ "$attempt" -ge "$MAX_RETRIES" ]]; then
      printf '%s\n' "$output" >&2
      return "$rc"
    fi

    delay=$((RETRY_DELAY * attempt))
    [[ "$delay" -gt 20 ]] && delay=20
    log_warn "$label: transient failure (attempt $attempt/$MAX_RETRIES). Retrying in ${delay}s..."
    sleep "$delay"
    attempt=$((attempt + 1))
  done

  printf '%s\n' "$output" >&2
  return 1
}

# ---------------------------------------------------------------------------
# Service lifecycle helpers
# ---------------------------------------------------------------------------
GQL_URL=""

stop_service() {
  pkill -f "linera service" 2>/dev/null || true
  # Wait for process to terminate
  for _ in $(seq 1 20); do
    if ! pgrep -f "linera service" >/dev/null 2>&1; then
      break
    fi
    sleep 0.5
  done
  sleep 2  # let RocksDB lock release
}

start_service() {
  local owner="$1"
  stop_service

  "$LINERA_BIN" set-preferred-owner --chain-id "$CHAIN_ID" --owner "$owner" 2>/dev/null || true

  "$LINERA_BIN" service --port "$SERVICE_PORT" >> "$SERVICE_LOG" 2>&1 &
  disown

  log_info "Waiting ${SERVICE_WAIT_SECS}s for service startup..."
  sleep "$SERVICE_WAIT_SECS"

  GQL_URL="http://localhost:${SERVICE_PORT}/chains/${CHAIN_ID}/applications/${APPLICATION_ID}"
  log_info "Service ready: $GQL_URL"
}

switch_owner() {
  local new_owner="$1"
  local label="$2"
  log_info "Switching preferred owner → $label"
  start_service "$new_owner"
}

# ---------------------------------------------------------------------------
# GraphQL helpers
# ---------------------------------------------------------------------------
gql_query() {
  local query="$1"
  local label="${2:-query}"
  TX_COUNT=$((TX_COUNT + 1))

  local payload
  payload=$(printf '{"query":"%s"}' "$query")

  local response
  response=$(curl -s --max-time "$CURL_TIMEOUT" \
    -X POST "$GQL_URL" \
    -H "Content-Type: application/json" \
    -d "$payload" 2>&1) || true

  echo "$response" >> "$RESULTS_LOG"
  echo "$response"
}

gql_mutate() {
  local mutation="$1"
  local label="${2:-mutation}"
  TX_COUNT=$((TX_COUNT + 1))

  local payload
  payload=$(printf '{"query":"mutation { %s }"}' "$mutation")

  local response
  response=$(curl -s --max-time "$CURL_TIMEOUT" \
    -X POST "$GQL_URL" \
    -H "Content-Type: application/json" \
    -d "$payload" 2>&1) || true

  echo "$response" >> "$RESULTS_LOG"
  echo "$response"
}

# Extract a JSON field value (simple jq-like for portability)
json_field() {
  local json="$1"
  local field="$2"
  # Use python3 if available, else basic grep
  if command -v python3 >/dev/null 2>&1; then
    echo "$json" | python3 -c "
import sys, json
try:
    d = json.load(sys.stdin)
    keys = '$field'.split('.')
    v = d
    for k in keys:
        if isinstance(v, dict):
            v = v.get(k)
        else:
            v = None
            break
    if v is not None:
        print(v)
except:
    pass
" 2>/dev/null || true
  else
    echo "$json" | grep -o "\"$field\":[^,}]*" | head -1 | sed 's/.*://' | tr -d ' "' || true
  fi
}

# Cleanup on exit
cleanup() {
  stop_service
  if [[ -f "$RESULTS_MD" ]]; then
    echo ""
    echo -e "${BOLD}Results saved to:${NC} $RESULTS_MD"
  fi
}
trap cleanup EXIT

# =============================================================================
# PHASE 1: DEPLOYMENT
# =============================================================================
mkdir -p "$SESSION_DIR"
touch "$RESULTS_LOG"

echo -e "${BOLD}${CYAN}"
echo "╔═══════════════════════════════════════════════════════════════╗"
echo "║   PalmeraDAO Multisig - Conway Testnet E2E Verification     ║"
echo "║   $(date -u '+%Y-%m-%d %H:%M:%S UTC')                                   ║"
echo "╚═══════════════════════════════════════════════════════════════╝"
echo -e "${NC}"

# Check prerequisites
if [[ -z "$LINERA_BIN" || ! -x "$LINERA_BIN" ]]; then
  log_err "linera binary not found. Install linera CLI or set LINERA_BIN."
  exit 1
fi
log_info "Using linera: $LINERA_BIN ($($LINERA_BIN --version 2>/dev/null | head -1))"

if [[ -n "$DEPLOY_ENV" && -f "$DEPLOY_ENV" ]]; then
  # ------- Reuse existing deployment -------
  log_step "Reusing Existing Deployment"
  # shellcheck disable=SC1090
  source "$DEPLOY_ENV"
  log_info "Loaded deployment from: $DEPLOY_ENV"
  log_info "Chain: $CHAIN_ID"
  log_info "Application: $APPLICATION_ID"

  # We still need owner keys from the env
  OWNER1="${OWNER1:-$DEFAULT_OWNER}"
  if [[ -z "${OWNER2:-}" || -z "${OWNER3:-}" ]]; then
    log_err "DEPLOY_ENV must export OWNER1, OWNER2, OWNER3 for E2E tests."
    exit 1
  fi
else
  # ------- Fresh deployment -------

  # --- Step 1: Build Wasm ---
  log_step "Step 1: Build Wasm Binaries"
  if [[ "$SKIP_BUILD" == "1" ]]; then
    log_info "SKIP_BUILD=1 — using existing binaries"
  else
    if ! command -v rustup >/dev/null 2>&1; then
      log_err "rustup not found. Install rustup first."
      exit 1
    fi

    RUSTUP_CARGO="$(rustup which --toolchain "$RUST_TOOLCHAIN" cargo 2>/dev/null || echo cargo)"
    RUSTUP_RUSTC="$(rustup which --toolchain "$RUST_TOOLCHAIN" rustc 2>/dev/null || echo rustc)"

    log_info "Building with Rust $RUST_TOOLCHAIN..."
    (cd "$APP_DIR" && RUSTC="$RUSTUP_RUSTC" "$RUSTUP_CARGO" build --locked --release --target wasm32-unknown-unknown 2>&1 | tail -5)
  fi

  if [[ ! -f "$CONTRACT_WASM" || ! -f "$SERVICE_WASM" ]]; then
    log_err "Wasm binaries not found. Run without SKIP_BUILD=1."
    exit 1
  fi

  CONTRACT_SIZE=$(wc -c < "$CONTRACT_WASM" | tr -d ' ')
  SERVICE_SIZE=$(wc -c < "$SERVICE_WASM" | tr -d ' ')
  log_ok "Contract: $CONTRACT_SIZE bytes, Service: $SERVICE_SIZE bytes"

  # Verify no bulk-memory opcodes
  if command -v wasm-objdump >/dev/null 2>&1; then
    OPCODES=$(wasm-objdump -d "$CONTRACT_WASM" 2>/dev/null | grep -cE 'memory\.(copy|fill)' || echo 0)
    assert_pass "Zero bulk-memory opcodes in contract" "[[ '$OPCODES' == '0' ]]"
  else
    log_warn "wasm-objdump not found — skipping opcode check"
  fi

  # --- Step 2: Create fresh wallet ---
  log_step "Step 2: Initialize Fresh Wallet"
  export LINERA_WALLET="$SESSION_DIR/wallet.json"
  export LINERA_KEYSTORE="$SESSION_DIR/keystore.json"
  export LINERA_STORAGE="rocksdb:$SESSION_DIR/client.db:runtime:default"

  "$LINERA_BIN" wallet init --faucet "$FAUCET_URL" >/dev/null 2>&1
  log_ok "Wallet initialized from faucet"

  # Request a chain with an owner key
  "$LINERA_BIN" wallet request-chain --faucet "$FAUCET_URL" >/dev/null 2>&1
  log_ok "Chain with owner key requested"

  # Get source chain and owner
  WALLET_SHOW="$($LINERA_BIN wallet show 2>/dev/null)"
  SOURCE_CHAIN_ID="$(echo "$WALLET_SHOW" | awk '/^Chain ID:/ {c=$3} /^Tags:/ {t=$2} /^Default owner:/ {o=$3; if (t=="DEFAULT" && o!="No") {print c; exit}}')"
  OWNER1="$(echo "$WALLET_SHOW" | awk '/^Tags:/ {t=$2} /^Default owner:/ {o=$3; if (t=="DEFAULT" && o!="No") {print o; exit}}')"

  if [[ -z "$SOURCE_CHAIN_ID" || -z "$OWNER1" ]]; then
    log_err "Could not resolve source chain or owner from wallet"
    exit 1
  fi
  log_info "Source chain: $SOURCE_CHAIN_ID"
  log_info "Owner1: $OWNER1"

  # --- Step 3: Generate additional owner keys ---
  log_step "Step 3: Generate Owner Keys"
  OWNER2="$($LINERA_BIN keygen 2>/dev/null | grep -Eo '0x[0-9a-f]{64}')"
  OWNER3="$($LINERA_BIN keygen 2>/dev/null | grep -Eo '0x[0-9a-f]{64}')"

  if [[ -z "$OWNER2" || -z "$OWNER3" ]]; then
    log_err "Failed to generate owner keys"
    exit 1
  fi
  log_ok "Owner2: $OWNER2"
  log_ok "Owner3: $OWNER3"

  # --- Step 4: Open multi-owner chain ---
  log_step "Step 4: Open Multi-Owner Chain (2-of-3)"
  OWNERS_JSON="[\"$OWNER1\",\"$OWNER2\",\"$OWNER3\"]"

  BEFORE_CHAINS="$(mktemp)"
  AFTER_CHAINS="$(mktemp)"
  "$LINERA_BIN" wallet show 2>/dev/null | awk '/^Chain ID:/ { print $3 }' > "$BEFORE_CHAINS"

  OPEN_OUTPUT="$(run_with_retry "open-multi-owner-chain" \
    "$LINERA_BIN" open-multi-owner-chain \
    --from "$SOURCE_CHAIN_ID" \
    --owners "$OWNERS_JSON" \
    --initial-balance 5)"

  "$LINERA_BIN" wallet show 2>/dev/null | awk '/^Chain ID:/ { print $3 }' > "$AFTER_CHAINS"
  CHAIN_ID="$(grep -Fxv -f "$BEFORE_CHAINS" "$AFTER_CHAINS" | tail -n1 || true)"
  if [[ -z "$CHAIN_ID" || "$CHAIN_ID" == "$SOURCE_CHAIN_ID" ]]; then
    CHAIN_ID="$(echo "$OPEN_OUTPUT" | grep -Eo '[0-9a-f]{64}' | awk -v src="$SOURCE_CHAIN_ID" '$0 != src { id = $0 } END { print id }')"
  fi
  rm -f "$BEFORE_CHAINS" "$AFTER_CHAINS"

  if [[ -z "$CHAIN_ID" ]]; then
    log_err "Failed to open multi-owner chain"
    exit 1
  fi

  "$LINERA_BIN" set-preferred-owner --chain-id "$CHAIN_ID" --owner "$OWNER1" >/dev/null 2>&1 || true
  "$LINERA_BIN" sync "$CHAIN_ID" >/dev/null 2>&1 || true
  log_ok "Multi-owner chain: $CHAIN_ID"

  # Verify ownership
  OWNERSHIP="$($LINERA_BIN show-ownership --chain-id "$CHAIN_ID" 2>/dev/null || echo "unavailable")"
  log_info "Ownership: $(echo "$OWNERSHIP" | head -5)"

  # --- Step 5: Publish module ---
  log_step "Step 5: Publish Module"
  PUBLISH_OUTPUT="$(run_with_retry "publish-module" "$LINERA_BIN" publish-module "$CONTRACT_WASM" "$SERVICE_WASM" "$CHAIN_ID")"
  MODULE_ID="$(echo "$PUBLISH_OUTPUT" | grep -Eo '[0-9a-f]{128,}' | tail -n1 || true)"
  if [[ -z "$MODULE_ID" ]]; then
    MODULE_ID="$(echo "$PUBLISH_OUTPUT" | grep -Eo '[0-9a-f]{64,}' | tail -n1 || true)"
  fi

  if [[ -z "$MODULE_ID" ]]; then
    log_err "Failed to publish module"
    echo "$PUBLISH_OUTPUT" >&2
    exit 1
  fi
  log_ok "Module: ${MODULE_ID:0:32}..."

  # --- Step 6: Create application ---
  log_step "Step 6: Create Application"
  JSON_ARG="{\"owners\":$OWNERS_JSON,\"threshold\":2,\"proposal_lifetime\":604800,\"time_delay\":0}"
  log_info "Instantiation: $JSON_ARG"

  CREATE_OUTPUT="$(run_with_retry "create-application" "$LINERA_BIN" create-application "$MODULE_ID" "$CHAIN_ID" --json-argument "$JSON_ARG")"
  APPLICATION_ID="$(echo "$CREATE_OUTPUT" | grep -Eo '[0-9a-f]{64}' | tail -n1 || true)"

  if [[ -z "$APPLICATION_ID" ]]; then
    log_err "Failed to create application"
    echo "$CREATE_OUTPUT" >&2
    exit 1
  fi
  log_ok "Application: $APPLICATION_ID"

  # Save deployment env for reuse
  cat > "$SESSION_DIR/deploy.env" <<EOT
# Generated: $(date -u +"%Y-%m-%d %H:%M:%S UTC")
# E2E Verification Session
export LINERA_BIN="$LINERA_BIN"
export LINERA_WALLET="$LINERA_WALLET"
export LINERA_KEYSTORE="$LINERA_KEYSTORE"
export LINERA_STORAGE="$LINERA_STORAGE"
export FAUCET_URL="$FAUCET_URL"
export SOURCE_CHAIN_ID="$SOURCE_CHAIN_ID"
export CHAIN_ID="$CHAIN_ID"
export OWNER1="$OWNER1"
export OWNER2="$OWNER2"
export OWNER3="$OWNER3"
export MODULE_ID="$MODULE_ID"
export APPLICATION_ID="$APPLICATION_ID"
export SESSION_DIR="$SESSION_DIR"
EOT
  log_ok "Deployment env saved: $SESSION_DIR/deploy.env"
fi

# =============================================================================
# PHASE 2: E2E VERIFICATION
# =============================================================================

log_step "Starting E2E Verification"
log_info "Chain: $CHAIN_ID"
log_info "App:   $APPLICATION_ID"
log_info "Owner1: $OWNER1"
log_info "Owner2: $OWNER2"
log_info "Owner3: $OWNER3"

# Start service as Owner1
start_service "$OWNER1"

# ---- TEST 1: Query Initial State ----
log_step "Test 1: Query Initial State"
RESP=$(gql_query '{ owners threshold nonce pendingProposals { id } executedProposals { id } }' "initial-state")
log_info "Response: $RESP"

THRESHOLD=$(json_field "$RESP" "data.threshold")
NONCE=$(json_field "$RESP" "data.nonce")

assert_pass "Initial threshold = 2" "[[ '$THRESHOLD' == '2' ]]"
assert_pass "Initial nonce = 0" "[[ '$NONCE' == '0' ]]"

# ---- TEST 2: Submit ChangeThreshold(1) as Owner1 ----
log_step "Test 2: Submit ChangeThreshold(1) — Owner1"
RESP=$(gql_mutate 'submitChangeThreshold(threshold: 1)' "submit-change-threshold")
log_tx "submitChangeThreshold response: $RESP"

TX_HASH=$(json_field "$RESP" "data.submitChangeThreshold")
assert_pass "ChangeThreshold mutation accepted" "[[ -n '$TX_HASH' ]]"

# Verify proposal created
sleep 2
RESP=$(gql_query '{ nonce proposal(id: 0) { id confirmationCount executed proposalType proposer } }' "verify-proposal-0")
log_info "Proposal 0 state: $RESP"

P0_CONFIRMATIONS=$(json_field "$RESP" "data.proposal.confirmationCount")
assert_pass "Proposal 0 auto-confirmed (count=1)" "[[ '$P0_CONFIRMATIONS' == '1' ]]"

# ---- TEST 3: Confirm Proposal 0 as Owner2 (multi-owner flow) ----
log_step "Test 3: Confirm Proposal 0 — Owner2 (multi-owner)"
switch_owner "$OWNER2" "Owner2"

RESP=$(gql_mutate 'confirmProposal(proposalId: 0)' "confirm-proposal-0")
log_tx "confirmProposal response: $RESP"

TX_HASH=$(json_field "$RESP" "data.confirmProposal")
assert_pass "Confirm mutation accepted" "[[ -n '$TX_HASH' ]]"

# Verify 2 confirmations
sleep 2
RESP=$(gql_query '{ proposal(id: 0) { id confirmationCount executed } hasOwner1: hasConfirmed(owner: \"'"$OWNER1"'\", proposalId: 0) hasOwner2: hasConfirmed(owner: \"'"$OWNER2"'\", proposalId: 0) }' "verify-2-confirmations")
log_info "Multi-owner confirmation: $RESP"

P0_COUNT=$(json_field "$RESP" "data.proposal.confirmationCount")
assert_pass "Proposal 0 has 2 confirmations" "[[ '$P0_COUNT' == '2' ]]"

# ---- TEST 4: Execute ChangeThreshold(1) as Owner1 ----
log_step "Test 4: Execute ChangeThreshold(1) — Owner1"
switch_owner "$OWNER1" "Owner1"

RESP=$(gql_mutate 'executeProposal(proposalId: 0)' "execute-proposal-0")
log_tx "executeProposal response: $RESP"

# Execute may return error response but still succeed (known issue)
sleep 3
RESP=$(gql_query '{ threshold executedProposals { id executed proposalType } pendingProposals { id } }' "verify-threshold-change")
log_info "Post-execute state: $RESP"

NEW_THRESHOLD=$(json_field "$RESP" "data.threshold")
assert_pass "Threshold changed to 1" "[[ '$NEW_THRESHOLD' == '1' ]]"

# ---- TEST 5: Submit & Execute Transfer (1 token to Owner2) ----
log_step "Test 5: Transfer 1 Token to Owner2"
RESP=$(gql_mutate "submitTransfer(to: \\\"$OWNER2\\\", value: 1)" "submit-transfer")
log_tx "submitTransfer response: $RESP"

TX_HASH=$(json_field "$RESP" "data.submitTransfer")
assert_pass "Transfer mutation accepted" "[[ -n '$TX_HASH' ]]"

# Find the transfer proposal ID (nonce may have jumped)
sleep 2
RESP=$(gql_query '{ nonce pendingProposals { id confirmationCount proposalType } }' "find-transfer-proposal")
log_info "Pending proposals: $RESP"

# Extract the transfer proposal ID using python3
TRANSFER_ID=""
if command -v python3 >/dev/null 2>&1; then
  TRANSFER_ID=$(echo "$RESP" | python3 -c "
import sys, json
try:
    d = json.load(sys.stdin)
    for p in d.get('data', {}).get('pendingProposals', []):
        if 'Transfer' in p.get('proposalType', ''):
            print(p['id'])
            break
except: pass
" 2>/dev/null || true)
fi

if [[ -n "$TRANSFER_ID" ]]; then
  log_info "Transfer proposal ID: $TRANSFER_ID"
  RESP=$(gql_mutate "executeProposal(proposalId: $TRANSFER_ID)" "execute-transfer")
  log_tx "executeProposal (transfer) response: $RESP"

  sleep 3
  RESP=$(gql_query "{ proposal(id: $TRANSFER_ID) { id executed proposalType } }" "verify-transfer-executed")
  log_info "Transfer execution state: $RESP"

  EXECUTED=$(json_field "$RESP" "data.proposal.executed")
  assert_pass "Transfer proposal executed" "[[ '$EXECUTED' == 'True' || '$EXECUTED' == 'true' ]]"
else
  log_warn "Could not find transfer proposal ID — skipping execute"
  FAILED_TESTS=$((FAILED_TESTS + 1))
  TOTAL_TESTS=$((TOTAL_TESTS + 1))
fi

# ---- TEST 6: ChangeThreshold back to 2 ----
log_step "Test 6: Restore Threshold to 2"
RESP=$(gql_mutate 'submitChangeThreshold(threshold: 2)' "submit-change-threshold-2")
log_tx "submitChangeThreshold(2) response: $RESP"

TX_HASH=$(json_field "$RESP" "data.submitChangeThreshold")
assert_pass "ChangeThreshold(2) mutation accepted" "[[ -n '$TX_HASH' ]]"

# Find the ChangeThreshold(2) proposal
sleep 2
RESP=$(gql_query '{ nonce pendingProposals { id confirmationCount proposalType } }' "find-threshold-2-proposal")

CT2_ID=""
if command -v python3 >/dev/null 2>&1; then
  CT2_ID=$(echo "$RESP" | python3 -c "
import sys, json
try:
    d = json.load(sys.stdin)
    for p in d.get('data', {}).get('pendingProposals', []):
        if 'ChangeThreshold { threshold: 2 }' in p.get('proposalType', ''):
            print(p['id'])
            break
except: pass
" 2>/dev/null || true)
fi

if [[ -n "$CT2_ID" ]]; then
  log_info "ChangeThreshold(2) proposal ID: $CT2_ID"

  # Threshold is still 1, so Owner1's auto-confirm is enough
  RESP=$(gql_mutate "executeProposal(proposalId: $CT2_ID)" "execute-threshold-2")
  log_tx "executeProposal (threshold 2) response: $RESP"

  sleep 3
  RESP=$(gql_query '{ threshold }' "verify-threshold-restored")
  log_info "Threshold after restore: $RESP"

  RESTORED=$(json_field "$RESP" "data.threshold")
  assert_pass "Threshold restored to 2" "[[ '$RESTORED' == '2' ]]"
else
  log_warn "Could not find ChangeThreshold(2) proposal — skipping"
  FAILED_TESTS=$((FAILED_TESTS + 1))
  TOTAL_TESTS=$((TOTAL_TESTS + 1))
fi

# ---- TEST 7: RevokeConfirmation ----
log_step "Test 7: Revoke Confirmation"
# Submit a proposal that we'll revoke our confirmation on
RESP=$(gql_mutate 'submitChangeThreshold(threshold: 3)' "submit-for-revoke")
log_tx "submitChangeThreshold(3) response: $RESP"

sleep 2
RESP=$(gql_query '{ nonce pendingProposals { id confirmationCount proposalType } }' "find-revoke-proposal")

REVOKE_ID=""
if command -v python3 >/dev/null 2>&1; then
  REVOKE_ID=$(echo "$RESP" | python3 -c "
import sys, json
try:
    d = json.load(sys.stdin)
    for p in d.get('data', {}).get('pendingProposals', []):
        if 'ChangeThreshold { threshold: 3 }' in p.get('proposalType', ''):
            print(p['id'])
            break
except: pass
" 2>/dev/null || true)
fi

if [[ -n "$REVOKE_ID" ]]; then
  log_info "Revoke target proposal ID: $REVOKE_ID"

  # Verify auto-confirmed first
  RESP=$(gql_query "{ proposal(id: $REVOKE_ID) { confirmationCount } hasOwner1: hasConfirmed(owner: \\\"$OWNER1\\\", proposalId: $REVOKE_ID) }" "verify-before-revoke")
  PRE_COUNT=$(json_field "$RESP" "data.proposal.confirmationCount")
  assert_pass "Pre-revoke confirmationCount = 1" "[[ '$PRE_COUNT' == '1' ]]"

  # Revoke
  RESP=$(gql_mutate "revokeConfirmation(proposalId: $REVOKE_ID)" "revoke-confirmation")
  log_tx "revokeConfirmation response: $RESP"

  TX_HASH=$(json_field "$RESP" "data.revokeConfirmation")
  assert_pass "Revoke mutation accepted" "[[ -n '$TX_HASH' ]]"

  # Verify revocation
  sleep 2
  RESP=$(gql_query "{ proposal(id: $REVOKE_ID) { confirmationCount } hasOwner1: hasConfirmed(owner: \\\"$OWNER1\\\", proposalId: $REVOKE_ID) }" "verify-after-revoke")
  log_info "Post-revoke state: $RESP"

  POST_COUNT=$(json_field "$RESP" "data.proposal.confirmationCount")
  assert_pass "Post-revoke confirmationCount = 0" "[[ '$POST_COUNT' == '0' ]]"
else
  log_warn "Could not find revocation target proposal"
  FAILED_TESTS=$((FAILED_TESTS + 2))
  TOTAL_TESTS=$((TOTAL_TESTS + 2))
fi

# ---- TEST 8: AddOwner via multi-owner confirmation ----
log_step "Test 8: AddOwner (multi-owner flow)"
NEW_OWNER="0x0000000000000000000000000000000000000000000000000000000000001234"

RESP=$(gql_mutate "submitAddOwner(owner: \\\"$NEW_OWNER\\\")" "submit-add-owner")
log_tx "submitAddOwner response: $RESP"

TX_HASH=$(json_field "$RESP" "data.submitAddOwner")
assert_pass "AddOwner mutation accepted" "[[ -n '$TX_HASH' ]]"

# Find AddOwner proposal
sleep 2
RESP=$(gql_query '{ nonce pendingProposals { id confirmationCount proposalType } }' "find-add-owner-proposal")

ADD_ID=""
if command -v python3 >/dev/null 2>&1; then
  ADD_ID=$(echo "$RESP" | python3 -c "
import sys, json
try:
    d = json.load(sys.stdin)
    for p in d.get('data', {}).get('pendingProposals', []):
        if 'AddOwner' in p.get('proposalType', '') and '1234' in p.get('proposalType', ''):
            print(p['id'])
            break
except: pass
" 2>/dev/null || true)
fi

if [[ -n "$ADD_ID" ]]; then
  log_info "AddOwner proposal ID: $ADD_ID"

  # Switch to Owner2 to confirm
  switch_owner "$OWNER2" "Owner2"

  RESP=$(gql_mutate "confirmProposal(proposalId: $ADD_ID)" "confirm-add-owner")
  log_tx "confirmProposal (AddOwner) response: $RESP"

  TX_HASH=$(json_field "$RESP" "data.confirmProposal")
  assert_pass "Owner2 confirm AddOwner accepted" "[[ -n '$TX_HASH' ]]"

  # Verify 2 confirmations
  sleep 2
  RESP=$(gql_query "{ proposal(id: $ADD_ID) { confirmationCount executed } }" "verify-add-owner-confirmations")
  log_info "AddOwner confirmation state: $RESP"

  ADD_COUNT=$(json_field "$RESP" "data.proposal.confirmationCount")
  assert_pass "AddOwner has 2 confirmations" "[[ '$ADD_COUNT' == '2' ]]"

  # Switch back to Owner1 to execute
  switch_owner "$OWNER1" "Owner1"

  RESP=$(gql_mutate "executeProposal(proposalId: $ADD_ID)" "execute-add-owner")
  log_tx "executeProposal (AddOwner) response: $RESP"

  # Verify 4 owners
  sleep 3
  RESP=$(gql_query '{ owners threshold }' "verify-4-owners")
  log_info "Final owners: $RESP"

  OWNER_COUNT=""
  if command -v python3 >/dev/null 2>&1; then
    OWNER_COUNT=$(echo "$RESP" | python3 -c "
import sys, json
try:
    d = json.load(sys.stdin)
    print(len(d.get('data', {}).get('owners', [])))
except: print(0)
" 2>/dev/null || echo "0")
  fi
  assert_pass "Owner count = 4 after AddOwner" "[[ '$OWNER_COUNT' == '4' ]]"
else
  log_warn "Could not find AddOwner proposal"
  FAILED_TESTS=$((FAILED_TESTS + 3))
  TOTAL_TESTS=$((TOTAL_TESTS + 3))
fi

# ---- FINAL: Query complete state ----
log_step "Final State Snapshot"
RESP=$(gql_query '{ owners threshold nonce pendingProposals { id proposalType confirmationCount executed } executedProposals { id proposalType confirmationCount executed } }' "final-state")
log_info "Final state: $RESP"

# Pretty-print if python3 available
if command -v python3 >/dev/null 2>&1; then
  echo "$RESP" | python3 -m json.tool 2>/dev/null || echo "$RESP"
fi

# Count executed proposals
EXEC_COUNT=""
if command -v python3 >/dev/null 2>&1; then
  EXEC_COUNT=$(echo "$RESP" | python3 -c "
import sys, json
try:
    d = json.load(sys.stdin)
    print(len(d.get('data', {}).get('executedProposals', [])))
except: print(0)
" 2>/dev/null || echo "0")
fi
assert_pass "At least 3 proposals executed" "[[ '${EXEC_COUNT:-0}' -ge 3 ]]"

# =============================================================================
# PHASE 3: GENERATE REPORT
# =============================================================================

log_step "Generating Report"

cat > "$RESULTS_MD" <<EOF
# E2E Multisig Verification Results

**Date**: $(date -u '+%Y-%m-%d %H:%M:%S UTC')
**Network**: Conway Testnet
**Script**: \`scripts/e2e-multisig-conway.sh\`

## Summary

| Metric | Value |
|--------|-------|
| Tests Run | $TOTAL_TESTS |
| Passed | $PASSED_TESTS |
| Failed | $FAILED_TESTS |
| GraphQL Calls | $TX_COUNT |

## Deployment

| Identifier | Value |
|-----------|-------|
| Source Chain | \`${SOURCE_CHAIN_ID:-N/A}\` |
| Multi-Owner Chain | \`$CHAIN_ID\` |
| Module ID | \`${MODULE_ID:-N/A}\` |
| Application ID | \`$APPLICATION_ID\` |
| Owner 1 | \`$OWNER1\` |
| Owner 2 | \`$OWNER2\` |
| Owner 3 | \`$OWNER3\` |

## Test Results

| Test | Description | Result |
|------|-------------|--------|
| 1 | Query initial state (3 owners, threshold=2, nonce=0) | $([ "$PASSED_TESTS" -ge 2 ] && echo "PASS" || echo "FAIL") |
| 2 | Submit ChangeThreshold(1) — auto-confirmed by Owner1 | $([ "$PASSED_TESTS" -ge 3 ] && echo "PASS" || echo "FAIL") |
| 3 | Confirm proposal as Owner2 (multi-owner confirmation) | $([ "$PASSED_TESTS" -ge 5 ] && echo "PASS" || echo "FAIL") |
| 4 | Execute ChangeThreshold — threshold 2→1 | $([ "$PASSED_TESTS" -ge 6 ] && echo "PASS" || echo "FAIL") |
| 5 | Submit & execute Transfer (1 token) | $([ "$PASSED_TESTS" -ge 8 ] && echo "PASS" || echo "FAIL") |
| 6 | Restore threshold 1→2 | $([ "$PASSED_TESTS" -ge 10 ] && echo "PASS" || echo "FAIL") |
| 7 | Revoke confirmation (count 1→0) | $([ "$PASSED_TESTS" -ge 13 ] && echo "PASS" || echo "FAIL") |
| 8 | AddOwner via multi-owner flow (3→4 owners) | $([ "$PASSED_TESTS" -ge 17 ] && echo "PASS" || echo "FAIL") |

## Session Artifacts

| Artifact | Path |
|----------|------|
| Deploy env | \`$SESSION_DIR/deploy.env\` |
| Full log | \`$SESSION_DIR/results.log\` |
| Service log | \`$SESSION_DIR/service.log\` |
| This report | \`$SESSION_DIR/results.md\` |

## Reuse This Deployment

\`\`\`bash
# Skip build + reuse existing deployment:
DEPLOY_ENV=$SESSION_DIR/deploy.env SKIP_BUILD=1 ./scripts/e2e-multisig-conway.sh
\`\`\`

---
Generated by \`e2e-multisig-conway.sh\` on $(date -u '+%Y-%m-%d %H:%M:%S UTC')
EOF

# =============================================================================
# SUMMARY
# =============================================================================

echo ""
echo -e "${BOLD}${CYAN}╔═══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BOLD}${CYAN}║                     E2E RESULTS SUMMARY                      ║${NC}"
echo -e "${BOLD}${CYAN}╠═══════════════════════════════════════════════════════════════╣${NC}"

if [[ "$FAILED_TESTS" -eq 0 ]]; then
  echo -e "${BOLD}${CYAN}║${NC}  ${GREEN}ALL $TOTAL_TESTS TESTS PASSED${NC}                                       ${BOLD}${CYAN}║${NC}"
else
  echo -e "${BOLD}${CYAN}║${NC}  ${RED}$FAILED_TESTS/$TOTAL_TESTS TESTS FAILED${NC}                                       ${BOLD}${CYAN}║${NC}"
fi

echo -e "${BOLD}${CYAN}║${NC}  GraphQL calls: $TX_COUNT                                          ${BOLD}${CYAN}║${NC}"
echo -e "${BOLD}${CYAN}║${NC}  Session: $SESSION_DIR ${BOLD}${CYAN}║${NC}"
echo -e "${BOLD}${CYAN}╚═══════════════════════════════════════════════════════════════╝${NC}"
echo ""

if [[ "$FAILED_TESTS" -gt 0 ]]; then
  log_err "Some tests failed. Check $RESULTS_LOG for details."
  exit 1
fi

log_ok "All tests passed. Full report: $RESULTS_MD"
