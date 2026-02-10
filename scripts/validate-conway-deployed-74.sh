#!/usr/bin/env bash
# Deploy to Conway testnet and validate the documented 74-test suite.

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
DEPLOY_SCRIPT="$REPO_ROOT/scripts/deploy-multisig-conway.sh"
VALIDATION_SCRIPT="$REPO_ROOT/scripts/multisig/validate-multisig-complete.sh"
REPORT_DIR="$REPO_ROOT/docs/multisig-custom/testing"
DEPLOY_DIR="${DEPLOY_DIR:-$REPO_ROOT/.linera-deploy}"

RUN_DEPLOY="${RUN_DEPLOY:-1}"
DEPLOY_ENV_FILE="${DEPLOY_ENV_FILE:-$DEPLOY_DIR/deploy_conway_latest.env}"

require_file() {
  if [[ ! -f "$1" ]]; then
    log_err "File not found: $1"
    exit 1
  fi
}

require_file "$DEPLOY_SCRIPT"
require_file "$VALIDATION_SCRIPT"
mkdir -p "$DEPLOY_DIR"

if [[ "$RUN_DEPLOY" == "1" ]]; then
  log_info "Running Conway deployment step (publish + create-application)..."
  DEPLOY_ENV_FILE="$DEPLOY_ENV_FILE" bash "$DEPLOY_SCRIPT"
else
  log_info "Skipping deployment step (RUN_DEPLOY=0)."
fi

require_file "$DEPLOY_ENV_FILE"
# shellcheck disable=SC1090
source "$DEPLOY_ENV_FILE"

if [[ -z "${APPLICATION_ID:-}" || -z "${MODULE_ID:-}" || -z "${CHAIN_ID:-}" ]]; then
  log_err "Deployment context incomplete in $DEPLOY_ENV_FILE"
  exit 1
fi

log_ok "Deployment context loaded"
log_info "  CHAIN_ID=$CHAIN_ID"
log_info "  MODULE_ID=$MODULE_ID"
log_info "  APPLICATION_ID=$APPLICATION_ID"

log_info "Running 74-test validation suite (documented) against deployed context..."
bash "$VALIDATION_SCRIPT" --skip-compile

latest_report="$(ls -1t "$REPORT_DIR"/VALIDATION_REPORT_*.md 2>/dev/null | head -1 || true)"
if [[ -z "$latest_report" ]]; then
  log_err "Could not find generated validation report in $REPORT_DIR"
  exit 1
fi

log_info "Latest validation report: $latest_report"

total_tests="$(awk -F'|' '/\|[[:space:]]*Total Tests[[:space:]]*\|/ { v=$3; gsub(/[^0-9]/, "", v); print v; exit }' "$latest_report")"
passed_tests="$(awk -F'|' '/Passed/ { v=$3; gsub(/[^0-9]/, "", v); if (v != "") { print v; exit } }' "$latest_report")"
failed_tests="$(awk -F'|' '/Failed/ { v=$3; gsub(/[^0-9]/, "", v); if (v != "") { print v; exit } }' "$latest_report")"

if [[ -z "$total_tests" || -z "$passed_tests" || -z "$failed_tests" ]]; then
  log_err "Could not parse test metrics from $latest_report"
  exit 1
fi

if [[ "$total_tests" != "74" ]]; then
  log_err "Expected 74 tests but report shows $total_tests"
  exit 1
fi

if [[ "$passed_tests" != "74" || "$failed_tests" != "0" ]]; then
  log_err "Validation suite not green: passed=$passed_tests failed=$failed_tests"
  exit 1
fi

log_ok "74/74 validation checks passed with deployed contract context."

evidence_file="$DEPLOY_DIR/validation_74_conway_$(date -u +%Y%m%d_%H%M%S).md"
cat > "$evidence_file" <<EOT
# Conway Deployed 74-Test Validation

- Date (UTC): $(date -u +"%Y-%m-%d %H:%M:%S")
- Chain ID: $CHAIN_ID
- Module ID: $MODULE_ID
- Application ID: $APPLICATION_ID
- Report: $latest_report
- Total Tests: $total_tests
- Passed: $passed_tests
- Failed: $failed_tests
- Status: PASS
EOT

log_ok "Evidence saved: $evidence_file"
