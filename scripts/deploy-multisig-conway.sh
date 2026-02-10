#!/usr/bin/env bash
# Deploy the custom multisig app to Conway testnet (publish + create-application).

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_ok() { echo -e "${GREEN}[OK]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_err() { echo -e "${RED}[ERR]${NC} $1"; }

require_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    log_err "Missing required command: $1"
    exit 1
  fi
}

extract_sdk_version() {
  awk -F'"' '/^linera-sdk =/ { print $2; exit }' "$APP_DIR/Cargo.toml"
}

extract_protocol_version() {
  "$LINERA_BIN" --version 2>/dev/null | awk '/Linera protocol:/ { gsub(/^v/, "", $3); print $3; exit }'
}

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
APP_DIR="$REPO_ROOT/scripts/multisig-app"
PINNED_LINERA_BIN="$REPO_ROOT/.tools/linera-0.15.11/bin/linera"
if [[ -x "$PINNED_LINERA_BIN" ]]; then
  DEFAULT_LINERA_BIN="$PINNED_LINERA_BIN"
else
  DEFAULT_LINERA_BIN="$(command -v linera || true)"
fi

LINERA_BIN="${LINERA_BIN:-$DEFAULT_LINERA_BIN}"
FAUCET_URL="${FAUCET_URL:-https://faucet.testnet-conway.linera.net}"
RUST_TOOLCHAIN="${RUST_TOOLCHAIN:-1.86.0}"
SKIP_BUILD="${SKIP_BUILD:-0}"
REQUIRE_ALIGNED_PROTOCOL="${REQUIRE_ALIGNED_PROTOCOL:-1}"

THRESHOLD="${THRESHOLD:-1}"
PROPOSAL_LIFETIME="${PROPOSAL_LIFETIME:-604800}"
TIME_DELAY="${TIME_DELAY:-0}"
# Comma-separated additional owners. Example:
# ADDITIONAL_OWNERS="User:abc...,User:def..."
ADDITIONAL_OWNERS="${ADDITIONAL_OWNERS:-}"

DEPLOY_DIR="${DEPLOY_DIR:-$REPO_ROOT/.linera-deploy}"
TIMESTAMP="$(date -u +%Y%m%d_%H%M%S)"
DEPLOY_ENV_FILE="${DEPLOY_ENV_FILE:-$DEPLOY_DIR/deploy_conway_${TIMESTAMP}.env}"

CONTRACT_WASM="$APP_DIR/target/wasm32-unknown-unknown/release/multisig_contract.wasm"
SERVICE_WASM="$APP_DIR/target/wasm32-unknown-unknown/release/multisig_service.wasm"

mkdir -p "$DEPLOY_DIR"

if [[ -z "$LINERA_BIN" || ! -x "$LINERA_BIN" ]]; then
  log_err "Invalid LINERA_BIN: $LINERA_BIN"
  exit 1
fi
log_info "Using linera binary: $LINERA_BIN"

SDK_VERSION="$(extract_sdk_version)"
PROTOCOL_VERSION="$(extract_protocol_version)"
if [[ -n "$SDK_VERSION" && -n "$PROTOCOL_VERSION" && "$SDK_VERSION" != "$PROTOCOL_VERSION" ]]; then
  if [[ "$REQUIRE_ALIGNED_PROTOCOL" == "1" ]]; then
    log_err "SDK/protocol mismatch: linera-sdk=$SDK_VERSION protocol=$PROTOCOL_VERSION"
    log_info "Use LINERA_BIN=$PINNED_LINERA_BIN or set REQUIRE_ALIGNED_PROTOCOL=0 to bypass."
    exit 2
  fi
  log_warn "Proceeding despite SDK/protocol mismatch: sdk=$SDK_VERSION protocol=$PROTOCOL_VERSION"
else
  log_ok "SDK/protocol alignment: sdk=${SDK_VERSION:-unknown} protocol=${PROTOCOL_VERSION:-unknown}"
fi

require_cmd awk
require_cmd mktemp
require_cmd rustup

if [[ "$SKIP_BUILD" != "1" ]]; then
  RUSTUP_CARGO="$(rustup which --toolchain "$RUST_TOOLCHAIN" cargo)"
  RUSTUP_RUSTC="$(rustup which --toolchain "$RUST_TOOLCHAIN" rustc)"
  if [[ ! -x "$RUSTUP_CARGO" || ! -x "$RUSTUP_RUSTC" ]]; then
    log_err "Toolchain binaries not found for $RUST_TOOLCHAIN"
    exit 1
  fi

  log_info "Building multisig Wasm binaries with Rust $RUST_TOOLCHAIN..."
  (cd "$APP_DIR" && RUSTC="$RUSTUP_RUSTC" "$RUSTUP_CARGO" build --locked --release --target wasm32-unknown-unknown)
fi

if [[ ! -f "$CONTRACT_WASM" || ! -f "$SERVICE_WASM" ]]; then
  log_err "Wasm outputs not found. Build first or set SKIP_BUILD=0."
  exit 1
fi

# If wallet env is not configured, create an isolated deployment wallet in .linera-deploy.
if [[ -z "${LINERA_WALLET:-}" || -z "${LINERA_KEYSTORE:-}" || -z "${LINERA_STORAGE:-}" ]]; then
  SESSION_DIR="$DEPLOY_DIR/session_${TIMESTAMP}"
  mkdir -p "$SESSION_DIR"
  export LINERA_WALLET="$SESSION_DIR/wallet.json"
  export LINERA_KEYSTORE="$SESSION_DIR/keystore.json"
  export LINERA_STORAGE="rocksdb:$SESSION_DIR/client.db:runtime:default"
  log_warn "LINERA_WALLET/LINERA_KEYSTORE/LINERA_STORAGE not set. Using isolated session: $SESSION_DIR"
else
  log_info "Using existing wallet environment variables."
fi

# Initialize wallet if needed.
if [[ ! -f "$LINERA_WALLET" ]]; then
  log_info "Initializing wallet from faucet: $FAUCET_URL"
  "$LINERA_BIN" wallet init --faucet "$FAUCET_URL" >/dev/null
fi

# Resolve a usable DEFAULT chain with a valid owner key.
resolve_default_chain_owner() {
  local wallet_show="$1"
  local chain owner
  chain="$(printf '%s\n' "$wallet_show" | awk '
    /^Chain ID:/ {c=$3}
    /^Tags:/ {t=$2}
    /^Default owner:/ {o=$3; if (t=="DEFAULT" && o!="No") {print c; exit}}
  ')"
  owner="$(printf '%s\n' "$wallet_show" | awk '
    /^Tags:/ {t=$2}
    /^Default owner:/ {o=$3; if (t=="DEFAULT" && o!="No") {print o; exit}}
  ')"
  if [[ -n "$chain" && -n "$owner" ]]; then
    printf '%s;%s\n' "$chain" "$owner"
    return 0
  fi
  return 1
}

WALLET_SHOW="$($LINERA_BIN wallet show 2>/dev/null || true)"
DEFAULT_PAIR="$(resolve_default_chain_owner "$WALLET_SHOW" || true)"

if [[ -z "$DEFAULT_PAIR" ]]; then
  log_info "No DEFAULT chain with owner key found. Requesting chain from faucet..."
  "$LINERA_BIN" wallet request-chain --faucet "$FAUCET_URL" >/dev/null
  WALLET_SHOW="$($LINERA_BIN wallet show 2>/dev/null || true)"
  DEFAULT_PAIR="$(resolve_default_chain_owner "$WALLET_SHOW" || true)"
fi

if [[ -z "$DEFAULT_PAIR" ]]; then
  log_err "Could not resolve a DEFAULT chain with owner key after request-chain."
  printf '%s\n' "$WALLET_SHOW" >&2
  exit 1
fi

CHAIN_ID="${DEFAULT_PAIR%;*}"
OWNER_RAW="${DEFAULT_PAIR#*;}"

# Build owners JSON array (raw owner format is required in current aligned Route B runtime).
declare -a owners
owners+=("$OWNER_RAW")
if [[ -n "$ADDITIONAL_OWNERS" ]]; then
  IFS=',' read -r -a extra <<< "$ADDITIONAL_OWNERS"
  for o in "${extra[@]}"; do
    trimmed="$(echo "$o" | awk '{$1=$1;print}')"
    [[ -n "$trimmed" ]] && owners+=("$trimmed")
  done
fi

owner_count="${#owners[@]}"
if [[ "$owner_count" -eq 0 ]]; then
  log_err "Owners list is empty."
  exit 1
fi

if [[ "$THRESHOLD" -le 0 ]]; then
  log_warn "Invalid THRESHOLD=$THRESHOLD. Normalizing to 1."
  THRESHOLD=1
fi
if [[ "$THRESHOLD" -gt "$owner_count" ]]; then
  log_warn "THRESHOLD=$THRESHOLD exceeds owner count $owner_count. Capping threshold."
  THRESHOLD="$owner_count"
fi

owners_json="["
for o in "${owners[@]}"; do
  owners_json+="\"$o\"," 
done
owners_json="${owners_json%,}]"

SOURCE_CHAIN_ID="$CHAIN_ID"
if [[ "$owner_count" -gt 1 ]]; then
  MULTI_OWNER_INITIAL_BALANCE="${MULTI_OWNER_INITIAL_BALANCE:-5}"
  log_info "Opening multi-owner chain from source chain: $SOURCE_CHAIN_ID"
  log_info "Target owners ($owner_count): $owners_json"

  before_chains_file="$(mktemp)"
  after_chains_file="$(mktemp)"
  "$LINERA_BIN" wallet show 2>/dev/null | awk '/^Chain ID:/ { print $3 }' >"$before_chains_file"

  set +e
  OPEN_OUTPUT="$("$LINERA_BIN" open-multi-owner-chain \
    --from "$SOURCE_CHAIN_ID" \
    --owners "$owners_json" \
    --initial-balance "$MULTI_OWNER_INITIAL_BALANCE" 2>&1)"
  rc=$?
  set -e
  if [[ $rc -ne 0 ]]; then
    rm -f "$before_chains_file" "$after_chains_file"
    log_err "open-multi-owner-chain failed."
    printf '%s\n' "$OPEN_OUTPUT" >&2
    exit 1
  fi

  "$LINERA_BIN" wallet show 2>/dev/null | awk '/^Chain ID:/ { print $3 }' >"$after_chains_file"
  NEW_CHAIN_ID="$(grep -Fxv -f "$before_chains_file" "$after_chains_file" | tail -n1 || true)"
  if [[ -z "$NEW_CHAIN_ID" || "$NEW_CHAIN_ID" == "$SOURCE_CHAIN_ID" ]]; then
    NEW_CHAIN_ID="$(printf '%s\n' "$OPEN_OUTPUT" | grep -Eo '[0-9a-f]{64}' | awk -v src="$SOURCE_CHAIN_ID" '$0 != src { id = $0 } END { print id }')"
  fi
  rm -f "$before_chains_file" "$after_chains_file"

  if [[ -z "$NEW_CHAIN_ID" || "$NEW_CHAIN_ID" == "$SOURCE_CHAIN_ID" ]]; then
    log_err "Could not determine newly opened multi-owner chain id."
    printf '%s\n' "$OPEN_OUTPUT" >&2
    exit 1
  fi

  CHAIN_ID="$NEW_CHAIN_ID"
  "$LINERA_BIN" set-preferred-owner --chain-id "$CHAIN_ID" --owner "$OWNER_RAW" >/dev/null
  "$LINERA_BIN" sync "$CHAIN_ID" >/dev/null 2>&1 || true
  log_ok "Using multi-owner chain: $CHAIN_ID"
fi

JSON_ARG="$(printf '{"owners":%s,"threshold":%s,"proposal_lifetime":%s,"time_delay":%s}' "$owners_json" "$THRESHOLD" "$PROPOSAL_LIFETIME" "$TIME_DELAY")"

log_info "Publishing module to Conway..."
PUBLISH_OUTPUT="$($LINERA_BIN publish-module "$CONTRACT_WASM" "$SERVICE_WASM" "$CHAIN_ID")"
MODULE_ID="$(printf '%s\n' "$PUBLISH_OUTPUT" | awk 'NF{line=$0} END{print line}' | tr -d '\r')"
if [[ -z "$MODULE_ID" ]]; then
  log_err "publish-module did not return module id."
  exit 1
fi
log_ok "Module published: $MODULE_ID"

log_info "Creating application with argument: $JSON_ARG"
set +e
CREATE_OUTPUT="$($LINERA_BIN create-application "$MODULE_ID" "$CHAIN_ID" --json-argument "$JSON_ARG" 2>&1)"
rc=$?
set -e
if [[ $rc -ne 0 ]]; then
  log_err "create-application failed."
  printf '%s\n' "$CREATE_OUTPUT" >&2
  exit 1
fi

APPLICATION_ID="$(printf '%s\n' "$CREATE_OUTPUT" | awk 'NF{line=$0} END{print line}' | tr -d '\r')"
if [[ -z "$APPLICATION_ID" ]]; then
  log_err "Could not parse application id from create-application output."
  printf '%s\n' "$CREATE_OUTPUT" >&2
  exit 1
fi

cat > "$DEPLOY_ENV_FILE" <<EOT
# Generated: $(date -u +"%Y-%m-%d %H:%M:%S UTC")
export LINERA_BIN="$LINERA_BIN"
export FAUCET_URL="$FAUCET_URL"
export LINERA_WALLET="$LINERA_WALLET"
export LINERA_KEYSTORE="$LINERA_KEYSTORE"
export LINERA_STORAGE="$LINERA_STORAGE"
export CHAIN_ID="$CHAIN_ID"
export SOURCE_CHAIN_ID="$SOURCE_CHAIN_ID"
export DEFAULT_OWNER="$OWNER_RAW"
export MODULE_ID="$MODULE_ID"
export APPLICATION_ID="$APPLICATION_ID"
export DEPLOY_JSON_ARGUMENT='$JSON_ARG'
EOT
ln -sfn "$(basename "$DEPLOY_ENV_FILE")" "$DEPLOY_DIR/deploy_conway_latest.env"

log_ok "Application created: $APPLICATION_ID"
log_ok "Deployment environment saved: $DEPLOY_ENV_FILE"
log_info "Reusable env symlink: $DEPLOY_DIR/deploy_conway_latest.env"

echo ""
echo "Next command (exact) to reuse this deployment context:"
echo "source '$DEPLOY_ENV_FILE'"
echo ""
echo "Core deployment outputs:"
echo "  CHAIN_ID=$CHAIN_ID"
echo "  MODULE_ID=$MODULE_ID"
echo "  APPLICATION_ID=$APPLICATION_ID"
