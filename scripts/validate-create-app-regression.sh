#!/usr/bin/env bash
# Regression validator for create-application on aligned SDK/protocol versions.
# Runs a deterministic localnet flow and tries multiple JSON argument encodings.

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

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
APP_DIR="$REPO_ROOT/scripts/multisig-app"
PINNED_LINERA_BIN="$REPO_ROOT/.tools/linera-0.15.11/bin/linera"
if [[ -x "$PINNED_LINERA_BIN" ]]; then
  DEFAULT_LINERA_BIN="$PINNED_LINERA_BIN"
else
  DEFAULT_LINERA_BIN="$(command -v linera || true)"
fi
RUST_TOOLCHAIN="${RUST_TOOLCHAIN:-1.86.0}"
LOCALNET_BIND="${LOCALNET_BIND:-127.0.0.1}"
LOCALNET_FAUCET_PORT="${LOCALNET_FAUCET_PORT:-}"
KEEP_TMP_ON_FAILURE="${KEEP_TMP_ON_FAILURE:-1}"
LINERA_BIN="${LINERA_BIN:-$DEFAULT_LINERA_BIN}"

TMP_ROOT=""
LOCALNET_PID=""
LOCALNET_LOG=""
ACTIVE_FAUCET_PORT=""

CONTRACT_WASM="$APP_DIR/target/wasm32-unknown-unknown/release/multisig_contract.wasm"
SERVICE_WASM="$APP_DIR/target/wasm32-unknown-unknown/release/multisig_service.wasm"

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

cleanup() {
  local code=$?
  if [[ -n "$LOCALNET_PID" ]] && kill -0 "$LOCALNET_PID" >/dev/null 2>&1; then
    log_info "Stopping local net (pid=$LOCALNET_PID)"
    kill "$LOCALNET_PID" >/dev/null 2>&1 || true
    wait "$LOCALNET_PID" >/dev/null 2>&1 || true
  fi
  if [[ -n "$TMP_ROOT" && -d "$TMP_ROOT" ]]; then
    if [[ $code -ne 0 && "$KEEP_TMP_ON_FAILURE" == "1" ]]; then
      log_warn "Regression failed; preserving temp dir: $TMP_ROOT"
      [[ -f "$LOCALNET_LOG" ]] && log_warn "Localnet log: $LOCALNET_LOG"
    else
      rm -rf "$TMP_ROOT"
    fi
  fi
  exit $code
}

start_localnet() {
  local net_dir attempt requested_port
  net_dir="$TMP_ROOT/localnet"
  mkdir -p "$net_dir"
  LOCALNET_LOG="$TMP_ROOT/localnet.log"
  requested_port="$LOCALNET_FAUCET_PORT"

  for attempt in $(seq 1 8); do
    : > "$LOCALNET_LOG"
    if [[ -n "$requested_port" ]]; then
      ACTIVE_FAUCET_PORT="$requested_port"
    else
      ACTIVE_FAUCET_PORT="$((30000 + (RANDOM % 20000)))"
    fi

    log_info "Starting localnet (port=$ACTIVE_FAUCET_PORT, attempt=$attempt)"
    "$LINERA_BIN" net up --with-faucet --faucet-port "$ACTIVE_FAUCET_PORT" --path "$net_dir" >"$LOCALNET_LOG" 2>&1 &
    LOCALNET_PID=$!
    sleep 2

    if kill -0 "$LOCALNET_PID" >/dev/null 2>&1; then
      return 0
    fi
    if rg -q "Failed to obtain a port" "$LOCALNET_LOG"; then
      log_warn "Port allocation failed; retrying..."
      LOCALNET_PID=""
      requested_port=""
      continue
    fi

    log_err "Localnet failed to start:"
    tail -n 80 "$LOCALNET_LOG" || true
    return 1
  done

  log_err "Could not start localnet after retries."
  tail -n 80 "$LOCALNET_LOG" || true
  return 1
}

wait_for_faucet() {
  local faucet_url i
  faucet_url="http://${LOCALNET_BIND}:${ACTIVE_FAUCET_PORT}"
  for i in $(seq 1 60); do
    if ! kill -0 "$LOCALNET_PID" >/dev/null 2>&1; then
      log_err "Localnet exited while waiting for faucet."
      tail -n 80 "$LOCALNET_LOG" || true
      return 1
    fi
    if curl -s --max-time 1 "$faucet_url" >/dev/null 2>&1; then
      echo "$faucet_url"
      return 0
    fi
    sleep 1
  done
  log_err "Timeout waiting for local faucet."
  tail -n 80 "$LOCALNET_LOG" || true
  return 1
}

try_create() {
  local label="$1"
  local module_id="$2"
  local json_arg="$3"
  local out rc
  set +e
  out="$("$LINERA_BIN" create-application "$module_id" --json-argument "$json_arg" 2>&1)"
  rc=$?
  set -e
  {
    echo "=== $label ==="
    echo "rc=$rc"
    echo "$out"
    echo
  } >> "$TMP_ROOT/create-application-attempts.log"

  if [[ $rc -eq 0 ]]; then
    log_ok "create-application succeeded ($label)"
    return 0
  fi
  log_warn "create-application failed ($label)"
  return 1
}

if [[ ! -x "$LINERA_BIN" ]]; then
  log_err "Invalid LINERA_BIN: $LINERA_BIN"
  exit 1
fi

require_cmd awk
require_cmd curl
require_cmd mktemp
require_cmd rg
require_cmd rustup

SDK_VERSION="$(extract_sdk_version)"
PROTOCOL_VERSION="$(extract_protocol_version)"
if [[ -z "$SDK_VERSION" || -z "$PROTOCOL_VERSION" ]]; then
  log_err "Could not determine SDK/protocol versions."
  exit 1
fi
if [[ "$SDK_VERSION" != "$PROTOCOL_VERSION" ]]; then
  log_err "Version mismatch: sdk=$SDK_VERSION protocol=$PROTOCOL_VERSION"
  exit 2
fi
log_ok "Aligned versions: $SDK_VERSION"

RUSTUP_CARGO="$(rustup which --toolchain "$RUST_TOOLCHAIN" cargo)"
RUSTUP_RUSTC="$(rustup which --toolchain "$RUST_TOOLCHAIN" rustc)"
if [[ ! -x "$RUSTUP_CARGO" || ! -x "$RUSTUP_RUSTC" ]]; then
  log_err "Toolchain binaries not found for $RUST_TOOLCHAIN"
  exit 1
fi

log_info "Building Wasm binaries with Rust $RUST_TOOLCHAIN..."
(cd "$APP_DIR" && RUSTC="$RUSTUP_RUSTC" "$RUSTUP_CARGO" build --locked --release --target wasm32-unknown-unknown)

if [[ ! -f "$CONTRACT_WASM" || ! -f "$SERVICE_WASM" ]]; then
  log_err "Wasm outputs not found."
  exit 1
fi

TMP_ROOT="$(mktemp -d /tmp/linera-create-app-regression-XXXXXX)"
trap cleanup EXIT INT TERM
start_localnet
FAUCET_URL="$(wait_for_faucet)"
log_ok "Faucet ready: $FAUCET_URL"

export LINERA_WALLET="$TMP_ROOT/wallet.json"
export LINERA_KEYSTORE="$TMP_ROOT/keystore.json"
export LINERA_STORAGE="rocksdb:$TMP_ROOT/client.db:runtime:default"

"$LINERA_BIN" wallet init --faucet "$FAUCET_URL" >/dev/null
"$LINERA_BIN" wallet request-chain --faucet "$FAUCET_URL" >/dev/null

OWNER_RAW="$("$LINERA_BIN" wallet show | awk '/Default owner:/ { print $3; exit }')"
if [[ -z "$OWNER_RAW" || "$OWNER_RAW" == "No" ]]; then
  log_err "Could not resolve default owner."
  exit 1
fi
OWNER_HEX="${OWNER_RAW#0x}"

PUBLISH_OUTPUT="$("$LINERA_BIN" publish-module "$CONTRACT_WASM" "$SERVICE_WASM")"
MODULE_ID="$(printf '%s\n' "$PUBLISH_OUTPUT" | tail -n 1 | tr -d '\r')"
if [[ -z "$MODULE_ID" ]]; then
  log_err "publish-module did not return module id."
  exit 1
fi
log_ok "Module published: $MODULE_ID"

ARG_USER_PREFIX="$(printf '{"owners":["User:%s"],"threshold":1,"proposal_lifetime":604800,"time_delay":0}' "$OWNER_HEX")"
ARG_RAW_OWNER="$(printf '{"owners":["%s"],"threshold":1,"proposal_lifetime":604800,"time_delay":0}' "$OWNER_RAW")"
ARG_MINIMAL="$(printf '{"owners":["User:%s"],"threshold":1}' "$OWNER_HEX")"

success=0
try_create "owners=User:hex + full args" "$MODULE_ID" "$ARG_USER_PREFIX" && success=1
if [[ $success -eq 0 ]]; then
  try_create "owners=raw owner + full args" "$MODULE_ID" "$ARG_RAW_OWNER" && success=1
fi
if [[ $success -eq 0 ]]; then
  try_create "owners=User:hex + minimal args" "$MODULE_ID" "$ARG_MINIMAL" && success=1
fi

if [[ $success -eq 1 ]]; then
  log_ok "Regression result: create-application is deployable."
  exit 0
fi

log_err "Regression result: create-application still fails across argument variants."
log_warn "See: $TMP_ROOT/create-application-attempts.log"
exit 1
