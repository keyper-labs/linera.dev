#!/usr/bin/env bash
# Validate Linera SDK opcode-252 workaround on the canonical custom contract.
# - Builds scripts/multisig-app with rustup toolchain 1.86.0
# - Verifies contract/service Wasm contain no memory.copy/memory.fill
# - Optionally tries publish-module if RUN_TESTNET_DEPLOY=1
# - Optionally runs create-application smoke test if RUN_CREATE_APP_SMOKE=1
# - Enforces SDK/protocol alignment by default and uses raw owner JSON format

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
LINERA_BIN="${LINERA_BIN:-$DEFAULT_LINERA_BIN}"
REQUIRE_ALIGNED_PROTOCOL="${REQUIRE_ALIGNED_PROTOCOL:-1}"
RUST_TOOLCHAIN="${RUST_TOOLCHAIN:-1.86.0}"
FAUCET_URL="${FAUCET_URL:-https://faucet.testnet-conway.linera.net}"
RUSTUP_CARGO=""
RUSTUP_RUSTC=""

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

run_create_application_smoke() {
  local work_dir owner_raw publish_output module_id create_output json_arg

  work_dir="$(mktemp -d /tmp/linera-multisig-smoke-XXXXXX)"
  log_info "RUN_CREATE_APP_SMOKE=1 -> create-application smoke test using $work_dir"
  export LINERA_WALLET="$work_dir/wallet.json"
  export LINERA_KEYSTORE="$work_dir/keystore.json"
  export LINERA_STORAGE="rocksdb:$work_dir/client.db:runtime:default"

  "$LINERA_BIN" wallet init --faucet "$FAUCET_URL" >/dev/null
  "$LINERA_BIN" wallet request-chain --faucet "$FAUCET_URL" >/dev/null

  owner_raw="$("$LINERA_BIN" wallet show | awk '/Default owner:/ { print $3; exit }')"
  if [[ -z "${owner_raw}" || "${owner_raw}" == "No" ]]; then
    log_err "Could not resolve default owner after wallet initialization."
    return 1
  fi

  publish_output="$("$LINERA_BIN" publish-module "$CONTRACT_WASM" "$SERVICE_WASM")"
  module_id="$(printf '%s\n' "$publish_output" | tail -n 1 | tr -d '\r')"
  if [[ -z "$module_id" ]]; then
    log_err "publish-module did not return a module id."
    return 1
  fi

  # Canonical format in aligned Route B / Conway flow.
  json_arg="$(printf '{"owners":["%s"],"threshold":1,"proposal_lifetime":604800,"time_delay":0}' "$owner_raw")"
  create_output="$("$LINERA_BIN" create-application "$module_id" --json-argument "$json_arg" 2>&1)" || {
    log_err "create-application failed with canonical raw owner format."
    printf '%s\n' "$create_output" >&2
    return 1
  }

  log_ok "create-application smoke test succeeded (raw owner format)."
  printf '%s\n' "$create_output"
}

wasm_opcode_count() {
  local wasm="$1"
  local op="$2"
  local out
  out="$(wasm-objdump -d "$wasm" 2>/dev/null | rg -c "$op" || true)"
  echo "${out:-0}"
}

log_info "Validating SDK workaround in canonical contract: $APP_DIR"

require_cmd rustup
require_cmd wasm-objdump
require_cmd rg
if [[ -z "$LINERA_BIN" || ! -x "$LINERA_BIN" ]]; then
  log_err "Invalid LINERA_BIN: $LINERA_BIN"
  exit 1
fi

sdk_version="$(extract_sdk_version)"
if [[ -n "$sdk_version" ]]; then
  protocol_version="$(extract_protocol_version)"
  if [[ -n "$protocol_version" && "$protocol_version" != "$sdk_version" ]]; then
    if [[ "$REQUIRE_ALIGNED_PROTOCOL" == "1" ]]; then
      log_err "SDK/protocol mismatch: linera-sdk=$sdk_version vs linera protocol=$protocol_version"
      log_info "Use LINERA_BIN=$PINNED_LINERA_BIN or set REQUIRE_ALIGNED_PROTOCOL=0 to bypass."
      exit 2
    fi
    log_warn "Potential SDK/protocol mismatch: linera-sdk=$sdk_version vs linera protocol=$protocol_version"
  else
    log_ok "SDK/protocol check: linera-sdk=$sdk_version, protocol=${protocol_version:-unknown}, bin=$LINERA_BIN"
  fi
fi

if ! rustup toolchain list | grep -q "^${RUST_TOOLCHAIN}"; then
  log_err "Toolchain ${RUST_TOOLCHAIN} is not installed."
  log_info "Install with: rustup toolchain install ${RUST_TOOLCHAIN}"
  exit 1
fi

if ! rustup target list --toolchain "${RUST_TOOLCHAIN}" --installed | grep -q "^wasm32-unknown-unknown$"; then
  log_err "Target wasm32-unknown-unknown missing for toolchain ${RUST_TOOLCHAIN}."
  log_info "Install with: rustup target add wasm32-unknown-unknown --toolchain ${RUST_TOOLCHAIN}"
  exit 1
fi

RUSTUP_CARGO="$(rustup which --toolchain "${RUST_TOOLCHAIN}" cargo)"
RUSTUP_RUSTC="$(rustup which --toolchain "${RUST_TOOLCHAIN}" rustc)"
if [[ -z "$RUSTUP_CARGO" || -z "$RUSTUP_RUSTC" || ! -x "$RUSTUP_CARGO" || ! -x "$RUSTUP_RUSTC" ]]; then
  log_err "Unable to resolve cargo/rustc binaries for toolchain ${RUST_TOOLCHAIN}."
  exit 1
fi

log_ok "Toolchain: $("$RUSTUP_RUSTC" --version)"

log_info "Building Wasm binaries..."
(cd "$APP_DIR" && RUSTC="$RUSTUP_RUSTC" "$RUSTUP_CARGO" build --locked --release --target wasm32-unknown-unknown)

if [[ ! -f "$CONTRACT_WASM" || ! -f "$SERVICE_WASM" ]]; then
  log_err "Expected wasm outputs not found."
  exit 1
fi

contract_copy="$(wasm_opcode_count "$CONTRACT_WASM" "memory.copy")"
contract_fill="$(wasm_opcode_count "$CONTRACT_WASM" "memory.fill")"
service_copy="$(wasm_opcode_count "$SERVICE_WASM" "memory.copy")"
service_fill="$(wasm_opcode_count "$SERVICE_WASM" "memory.fill")"

log_info "Opcode results:"
echo "  multisig_contract.wasm: memory.copy=${contract_copy} memory.fill=${contract_fill}"
echo "  multisig_service.wasm:  memory.copy=${service_copy} memory.fill=${service_fill}"

if [[ "$contract_copy" != "0" || "$contract_fill" != "0" || "$service_copy" != "0" || "$service_fill" != "0" ]]; then
  log_err "Workaround validation FAILED: bulk-memory opcodes detected."
  exit 1
fi

log_ok "Workaround validation PASSED: no memory.copy/memory.fill opcodes detected."

if [[ "${RUN_TESTNET_DEPLOY:-0}" == "1" ]]; then
  log_info "RUN_TESTNET_DEPLOY=1 -> attempting publish-module via $LINERA_BIN"
  log_warn "This requires working wallet/storage/faucet configuration in your environment."
  "$LINERA_BIN" publish-module "$CONTRACT_WASM" "$SERVICE_WASM"
  log_ok "publish-module succeeded."
else
  log_warn "Skipping network publish test (set RUN_TESTNET_DEPLOY=1 to enable)."
fi

if [[ "${RUN_CREATE_APP_SMOKE:-0}" == "1" ]]; then
  run_create_application_smoke
else
  log_warn "Skipping create-application smoke test (set RUN_CREATE_APP_SMOKE=1 to enable)."
fi
