#!/usr/bin/env bash
# Validate that a previously deployed app is actually queryable on Conway testnet.

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

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
DEPLOY_DIR="${DEPLOY_DIR:-$REPO_ROOT/.linera-deploy}"
DEPLOY_ENV_FILE="${DEPLOY_ENV_FILE:-$DEPLOY_DIR/deploy_conway_latest.env}"
PORT="${PORT:-8123}"
STARTUP_WAIT_SECS="${STARTUP_WAIT_SECS:-45}"
TIMESTAMP="$(date -u +%Y%m%d_%H%M%S)"
SERVICE_LOG="$DEPLOY_DIR/deploy_validation_service_${TIMESTAMP}.log"

require_cmd curl
require_cmd jq
require_cmd awk

if [[ ! -f "$DEPLOY_ENV_FILE" ]]; then
  log_err "DEPLOY_ENV_FILE not found: $DEPLOY_ENV_FILE"
  exit 1
fi

# shellcheck disable=SC1090
source "$DEPLOY_ENV_FILE"

for var in LINERA_BIN LINERA_WALLET LINERA_KEYSTORE LINERA_STORAGE CHAIN_ID APPLICATION_ID MODULE_ID; do
  if [[ -z "${!var:-}" ]]; then
    log_err "Missing required variable '$var' in $DEPLOY_ENV_FILE"
    exit 1
  fi
done

if [[ ! -x "$LINERA_BIN" ]]; then
  log_err "LINERA_BIN is not executable: $LINERA_BIN"
  exit 1
fi

log_info "Deployment env: $DEPLOY_ENV_FILE"
log_info "Chain: $CHAIN_ID"
log_info "Application: $APPLICATION_ID"
log_info "Module: $MODULE_ID"
log_info "Linera version: $("$LINERA_BIN" --version | tr '\n' ' ' | sed 's/[[:space:]]\\+/ /g')"

export LINERA_WALLET LINERA_KEYSTORE LINERA_STORAGE

wallet_show="$("$LINERA_BIN" wallet show 2>/dev/null || true)"
if [[ "$wallet_show" != *"$CHAIN_ID"* ]]; then
  log_err "Chain ID $CHAIN_ID is not present in current wallet state."
  exit 1
fi
log_ok "Chain ID exists in wallet state."

cleanup() {
  if [[ -n "${SERVICE_PID:-}" ]]; then
    kill "$SERVICE_PID" >/dev/null 2>&1 || true
    wait "$SERVICE_PID" >/dev/null 2>&1 || true
  fi
}
trap cleanup EXIT

log_info "Starting linera service on port $PORT ..."
"$LINERA_BIN" service --port "$PORT" >"$SERVICE_LOG" 2>&1 &
SERVICE_PID=$!

ready=0
for _ in $(seq 1 "$STARTUP_WAIT_SECS"); do
  if curl -fsS -X POST "http://127.0.0.1:$PORT" \
    -H 'content-type: application/json' \
    --data '{"query":"{ __typename }"}' >/dev/null 2>&1; then
    ready=1
    break
  fi
  sleep 1
done

if [[ "$ready" -ne 1 ]]; then
  log_err "Service did not become ready. See log: $SERVICE_LOG"
  exit 2
fi
log_ok "Service endpoint is reachable."

apps_json="$(curl -sS -X POST "http://127.0.0.1:$PORT" \
  -H 'content-type: application/json' \
  --data "{\"query\":\"{ applications(chainId:\\\"$CHAIN_ID\\\") { id description link } }\"}")"

if ! jq -e '.errors | not or (.errors | length == 0)' >/dev/null 2>&1 <<<"$apps_json"; then
  log_err "Applications query returned GraphQL errors."
  echo "$apps_json" | sed -n '1,120p'
  exit 3
fi

app_found="$(jq -r --arg app "$APPLICATION_ID" '.data.applications | map(.id) | index($app) != null' <<<"$apps_json")"
if [[ "$app_found" != "true" ]]; then
  log_err "Application ID not found in chain applications list."
  echo "$apps_json" | sed -n '1,120p'
  exit 4
fi
log_ok "Application appears in chain applications list."

app_state_json="$(curl -sS -X POST "http://127.0.0.1:$PORT/chains/$CHAIN_ID/applications/$APPLICATION_ID" \
  -H 'content-type: application/json' \
  --data '{"query":"{ owners threshold nonce pendingProposals { id } }"}')"

if ! jq -e '.errors | not or (.errors | length == 0)' >/dev/null 2>&1 <<<"$app_state_json"; then
  log_err "Application endpoint returned GraphQL errors."
  echo "$app_state_json" | sed -n '1,120p'
  exit 5
fi

owners_count="$(jq -r '.data.owners | length' <<<"$app_state_json")"
threshold="$(jq -r '.data.threshold' <<<"$app_state_json")"
nonce="$(jq -r '.data.nonce' <<<"$app_state_json")"

log_ok "Application endpoint responds correctly."
log_info "State snapshot: owners=$owners_count threshold=$threshold nonce=$nonce"

echo ""
echo "Deployment validation: PASS"
echo "  env:     $DEPLOY_ENV_FILE"
echo "  chain:   $CHAIN_ID"
echo "  app:     $APPLICATION_ID"
echo "  module:  $MODULE_ID"
echo "  log:     $SERVICE_LOG"

exit 0

