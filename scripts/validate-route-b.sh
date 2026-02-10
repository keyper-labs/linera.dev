#!/usr/bin/env bash
# Route B validation:
# Keep contract on linera-sdk 0.15.11 and run full validation on matching Linera protocol.
#
# Flow:
# 1) Verify SDK version in scripts/multisig-app/Cargo.toml
# 2) Verify selected Linera binary protocol matches SDK version
# 3) Optionally start local net+faucet with that same Linera binary
# 4) Run opcode + create-application smoke validation

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
APP_CARGO_TOML="$REPO_ROOT/scripts/multisig-app/Cargo.toml"
BASE_VALIDATOR="$REPO_ROOT/scripts/validate-sdk-workaround.sh"

CHECK_ONLY=0
USE_LOCALNET="${USE_LOCALNET:-1}"
LOCALNET_BIND="${LOCALNET_BIND:-127.0.0.1}"
LOCALNET_FAUCET_PORT="${LOCALNET_FAUCET_PORT:-}"
LINERA_BIN="${LINERA_BIN:-$(command -v linera || true)}"
FAUCET_URL_OVERRIDE="${FAUCET_URL:-}"

TMP_ROOT=""
PATH_SHIM_DIR=""
LOCALNET_PID=""
LOCALNET_LOG=""
SDK_VERSION=""
PROTOCOL_VERSION=""
KEEP_TMP_ON_FAILURE="${KEEP_TMP_ON_FAILURE:-1}"
ACTIVE_FAUCET_PORT=""

usage() {
  cat <<EOF
Usage: bash scripts/validate-route-b.sh [options]

Options:
  --check-only         Only verify SDK/protocol alignment; do not run tests.
  --no-localnet        Do not start local net; use FAUCET_URL if provided.
  --linera-bin <path>  Explicit Linera binary path to use.
  -h, --help           Show this help.

Environment:
  LINERA_BIN           Same as --linera-bin.
  USE_LOCALNET         1 (default) to run with local net/faucet, 0 to skip.
  LOCALNET_BIND        Local bind address for faucet (default: 127.0.0.1).
  LOCALNET_FAUCET_PORT Local faucet port (optional). If unset, a random high port is used.
  FAUCET_URL           Used only when USE_LOCALNET=0.
EOF
}

require_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    log_err "Missing required command: $1"
    exit 1
  fi
}

extract_sdk_version() {
  awk -F'"' '/^linera-sdk =/ { print $2; exit }' "$APP_CARGO_TOML"
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
      log_warn "Validation failed; preserving temp dir for debugging: $TMP_ROOT"
      if [[ -n "$LOCALNET_LOG" && -f "$LOCALNET_LOG" ]]; then
        log_warn "Localnet log: $LOCALNET_LOG"
      fi
    else
      rm -rf "$TMP_ROOT"
    fi
  fi
  exit $code
}

prepare_path_shim() {
  PATH_SHIM_DIR="$TMP_ROOT/bin"
  mkdir -p "$PATH_SHIM_DIR"
  ln -sf "$LINERA_BIN" "$PATH_SHIM_DIR/linera"

  local bin_root
  bin_root="$(dirname "$LINERA_BIN")"
  for name in linera-server linera-proxy linera-storage-server; do
    if [[ -x "$bin_root/$name" ]]; then
      ln -sf "$bin_root/$name" "$PATH_SHIM_DIR/$name"
    fi
  done

  export PATH="$PATH_SHIM_DIR:$PATH"
}

start_localnet() {
  local net_dir requested_port attempt
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

    log_info "Starting local net/faucet with $LINERA_BIN (port=$ACTIVE_FAUCET_PORT, attempt=$attempt)"
    linera net up --with-faucet --faucet-port "$ACTIVE_FAUCET_PORT" --path "$net_dir" >"$LOCALNET_LOG" 2>&1 &
    LOCALNET_PID=$!
    sleep 2

    if kill -0 "$LOCALNET_PID" >/dev/null 2>&1; then
      log_info "Local net pid: $LOCALNET_PID (log: $LOCALNET_LOG)"
      return 0
    fi

    if rg -q "Failed to obtain a port" "$LOCALNET_LOG"; then
      log_warn "Port allocation failed on attempt $attempt; retrying with a new port."
      LOCALNET_PID=""
      requested_port=""
      continue
    fi

    log_err "Local net failed to start. Log tail:"
    tail -n 80 "$LOCALNET_LOG" || true
    return 1
  done

  log_err "Unable to start local net after multiple attempts."
  tail -n 80 "$LOCALNET_LOG" || true
  return 1
}

wait_for_faucet() {
  local faucet_url i
  faucet_url="http://${LOCALNET_BIND}:${ACTIVE_FAUCET_PORT}"

  for i in $(seq 1 60); do
    if ! kill -0 "$LOCALNET_PID" >/dev/null 2>&1; then
      log_err "Local net exited early. Log tail:" >&2
      tail -n 80 "$LOCALNET_LOG" || true
      return 1
    fi
    if curl -s --max-time 1 "$faucet_url" >/dev/null 2>&1; then
      log_ok "Local faucet ready: $faucet_url" >&2
      echo "$faucet_url"
      return 0
    fi
    sleep 1
  done

  log_err "Timeout waiting for local faucet." >&2
  tail -n 80 "$LOCALNET_LOG" || true
  return 1
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --check-only)
      CHECK_ONLY=1
      shift
      ;;
    --no-localnet)
      USE_LOCALNET=0
      shift
      ;;
    --linera-bin)
      if [[ $# -lt 2 ]]; then
        log_err "--linera-bin requires a path"
        exit 1
      fi
      LINERA_BIN="$2"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      log_err "Unknown option: $1"
      usage
      exit 1
      ;;
  esac
done

if [[ ! -f "$APP_CARGO_TOML" ]]; then
  log_err "Missing app Cargo.toml: $APP_CARGO_TOML"
  exit 1
fi
if [[ ! -f "$BASE_VALIDATOR" ]]; then
  log_err "Missing validator script: $BASE_VALIDATOR"
  exit 1
fi
if [[ -z "$LINERA_BIN" || ! -x "$LINERA_BIN" ]]; then
  log_err "Invalid LINERA_BIN: $LINERA_BIN"
  exit 1
fi

require_cmd awk
require_cmd bash
require_cmd mktemp
require_cmd rustup
require_cmd wasm-objdump
require_cmd rg
if [[ "$USE_LOCALNET" == "1" ]]; then
  require_cmd curl
fi

SDK_VERSION="$(extract_sdk_version)"
PROTOCOL_VERSION="$(extract_protocol_version)"

if [[ -z "$SDK_VERSION" ]]; then
  log_err "Could not parse linera-sdk version from $APP_CARGO_TOML"
  exit 1
fi
if [[ -z "$PROTOCOL_VERSION" ]]; then
  log_err "Could not parse Linera protocol version from $LINERA_BIN --version"
  exit 1
fi

log_info "Route B alignment check"
log_info "  linera-sdk (app): $SDK_VERSION"
log_info "  linera protocol  : $PROTOCOL_VERSION"
log_info "  linera binary    : $LINERA_BIN"

if [[ "$SDK_VERSION" != "$PROTOCOL_VERSION" ]]; then
  log_err "Version mismatch. Route B requires exact alignment."
  log_err "Expected protocol $SDK_VERSION but got $PROTOCOL_VERSION."
  log_info "Install/select Linera protocol $SDK_VERSION, then rerun this script."
  exit 2
fi

log_ok "SDK/protocol are aligned."

if [[ "$CHECK_ONLY" == "1" ]]; then
  log_ok "Check-only mode complete."
  exit 0
fi

TMP_ROOT="$(mktemp -d /tmp/linera-route-b-XXXXXX)"
trap cleanup EXIT INT TERM
prepare_path_shim

FAUCET_URL_TO_USE="$FAUCET_URL_OVERRIDE"
if [[ "$USE_LOCALNET" == "1" ]]; then
  localnet_ready=0
  for _ in $(seq 1 5); do
    start_localnet
    if FAUCET_URL_TO_USE="$(wait_for_faucet)"; then
      localnet_ready=1
      break
    fi

    if [[ -f "$LOCALNET_LOG" ]] && rg -q "Failed to obtain a port" "$LOCALNET_LOG"; then
      log_warn "Retrying localnet startup after port allocation failure."
      if [[ -n "$LOCALNET_PID" ]] && kill -0 "$LOCALNET_PID" >/dev/null 2>&1; then
        kill "$LOCALNET_PID" >/dev/null 2>&1 || true
        wait "$LOCALNET_PID" >/dev/null 2>&1 || true
      fi
      LOCALNET_PID=""
      continue
    fi

    break
  done

  if [[ "$localnet_ready" != "1" ]]; then
    log_err "Failed to bootstrap localnet/faucet for Route B validation."
    exit 1
  fi
else
  if [[ -z "$FAUCET_URL_TO_USE" ]]; then
    log_err "USE_LOCALNET=0 requires FAUCET_URL to be set."
    exit 1
  fi
fi

log_info "Running canonical workaround validator with Route B settings..."
log_info "  FAUCET_URL=$FAUCET_URL_TO_USE"

FAUCET_URL="$FAUCET_URL_TO_USE" RUN_CREATE_APP_SMOKE=1 bash "$BASE_VALIDATOR"

log_ok "Route B validation completed successfully."
