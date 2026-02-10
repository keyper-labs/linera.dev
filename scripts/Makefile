.PHONY: help init cli-test cli-show cli-clean rust-test rust-build rust-clean rust-check-toolchain deploy-conway validate-conway-74 validate-conway-safe-e2e e2e-verify clean all test readme

# Linera Multisig Testing Makefile
# This Makefile orchestrates E2E testing on Conway testnet
# Status: PoC Complete - Contract operational on Conway testnet
# Version: 2.0.0
# Date: 2026-02-10

# Configuration
SCRIPT_DIR := $(abspath $(dir $(lastword $(MAKEFILE_LIST))))
WALLET_DIR ?= $(SCRIPT_DIR)/test-wallets
MULTISIG_APP_PROJECT_DIR ?= $(SCRIPT_DIR)/multisig-app
FAUCET_URL ?= http://localhost:8080
LINERA_SDK_VERSION ?= 0.15.11
RUST_TOOLCHAIN ?= 1.86.0
RUSTUP_CARGO := $(shell rustup which --toolchain $(RUST_TOOLCHAIN) cargo 2>/dev/null || echo cargo)
RUSTUP_RUSTC := $(shell rustup which --toolchain $(RUST_TOOLCHAIN) rustc 2>/dev/null || echo rustc)
CARGO_RUN := RUSTC=$(RUSTUP_RUSTC) $(RUSTUP_CARGO)

# Colors for output
BLUE := \033[0;34m
GREEN := \033[0;32m
YELLOW := \033[1;33m
RED := \033[0;31m
CYAN := \033[0;36m
BOLD := \033[1m
NC := \033[0m # No Color

help:
	@echo "$(BOLD)$(BLUE)=======================================================================$(NC)"
	@echo "$(BOLD)  LINERA MULTISIG TESTING - E2E ON CONWAY TESTNET$(NC)"
	@echo "$(BOLD)  Status: PoC VERIFIED on Conway testnet$(NC)"
	@echo "$(BOLD)$(BLUE)=======================================================================$(NC)"
	@echo ""
	@echo "$(BOLD)$(CYAN)QUICK START:$(NC)"
	@echo "  $(GREEN)make e2e-verify$(NC)    - Full E2E verification (deploy + test)"
	@echo ""
	@echo "$(BOLD)$(CYAN)SETUP:$(NC)"
	@echo "  $(GREEN)make init$(NC)         - Initialize environment"
	@echo "  $(GREEN)make clean$(NC)        - Clean all generated files"
	@echo ""
	@echo "$(BOLD)$(CYAN)E2E TESTING ON CONWAY:$(NC)"
	@echo "  $(GREEN)make e2e-verify$(NC)              - Full E2E verification (deploy + test)"
	@echo "  $(GREEN)make validate-conway-safe-e2e$(NC) - Safe-like E2E validation"
	@echo "  $(GREEN)make deploy-conway$(NC)            - Deploy to Conway testnet"
	@echo "  $(GREEN)make validate-conway-74$(NC)       - Validate 74-test suite"
	@echo ""
	@echo "$(BOLD)$(CYAN)BUILD & VALIDATION:$(NC)"
	@echo "  $(GREEN)make rust-build$(NC)              - Build Wasm contract"
	@echo "  $(GREEN)make rust-check-toolchain$(NC)     - Verify Rust 1.86 is available"
	@echo ""
	@echo "$(BOLD)$(CYAN)DOCUMENTATION:$(NC)"
	@echo "  $(GREEN)make readme$(NC)        - Show detailed README"
	@echo ""
	@echo "$(YELLOW)Environment Variables:$(NC)"
	@echo "  FAUCET_URL            - Faucet URL (default: $(FAUCET_URL))"
	@echo "  LINERA_WALLET         - Path to wallet.json"
	@echo "  LINERA_STORAGE        - Path to wallet DB"
	@echo "  LINERA_KEYSTORE       - Path to keystore"

init:
	@echo "$(BLUE)Initializing Linera multisig testing environment...$(NC)"
	@mkdir -p $(WALLET_DIR)
	@echo "$(GREEN)Environment initialized$(NC)"
	@echo "$(YELLOW)Remember to set:$(NC)"
	@echo "  export FAUCET_URL=$(FAUCET_URL)"
	@echo "  export LINERA_WALLET=wallet.json"
	@echo "  export LINERA_STORAGE=rocksdb:wallet.db:runtime:default"
	@echo "  export LINERA_KEYSTORE=keystore.db"

rust-check-toolchain:
	@echo "$(BLUE)=== Checking Rust Toolchain ===$(NC)"
	@if ! command -v rustup >/dev/null 2>&1; then \
		echo "$(RED)Error: rustup not found. Install rustup to pin toolchain $(RUST_TOOLCHAIN).$(NC)"; \
		exit 1; \
	fi
	@if ! rustup toolchain list | grep -q "^$(RUST_TOOLCHAIN)"; then \
		echo "$(RED)Error: toolchain $(RUST_TOOLCHAIN) not installed.$(NC)"; \
		echo "$(YELLOW)Run: rustup toolchain install $(RUST_TOOLCHAIN)$(NC)"; \
		exit 1; \
	fi
	@if ! rustup target list --toolchain $(RUST_TOOLCHAIN) --installed | grep -q "^wasm32-unknown-unknown$$"; then \
		echo "$(RED)Error: wasm32-unknown-unknown target missing for $(RUST_TOOLCHAIN).$(NC)"; \
		echo "$(YELLOW)Run: rustup target add wasm32-unknown-unknown --toolchain $(RUST_TOOLCHAIN)$(NC)"; \
		exit 1; \
	fi
	@echo "$(GREEN)Using:$$($(RUSTUP_RUSTC) --version)$(NC)"

rust-build: rust-check-toolchain
	@echo "$(BLUE)=== Building Rust Multisig Application ===$(NC)"
	@if [ -d "$(MULTISIG_APP_PROJECT_DIR)" ]; then \
		cd $(MULTISIG_APP_PROJECT_DIR) && \
		$(CARGO_RUN) build --locked --release --target wasm32-unknown-unknown && \
		echo "$(GREEN)Build complete$(NC)"; \
	else \
		echo "$(RED)Project not found: $(MULTISIG_APP_PROJECT_DIR)$(NC)"; \
		exit 1; \
	fi

rust-test: rust-build
	@echo "$(GREEN)Rust multisig application built successfully$(NC)"

deploy-conway: rust-build
	@echo "$(BLUE)=== Conway Deploy (publish + create-application) ===$(NC)"
	@bash $(SCRIPT_DIR)/deploy-multisig-conway.sh

validate-conway-74: rust-build
	@echo "$(BLUE)=== Conway Deployed 74-Test Validation ===$(NC)"
	@bash $(SCRIPT_DIR)/validate-conway-deployed-74.sh

validate-conway-safe-e2e: rust-build
	@echo "$(BLUE)=== Conway Safe-Like E2E Validation ===$(NC)"
	@bash $(SCRIPT_DIR)/validate-conway-safe-e2e.sh

e2e-verify: rust-build
	@echo "$(BOLD)$(BLUE)=======================================================================$(NC)"
	@echo "$(BOLD)  FULL E2E VERIFICATION ON CONWAY TESTNET$(NC)"
	@echo "$(BOLD)$(BLUE)=======================================================================$(NC)"
	@SKIP_BUILD=1 bash $(SCRIPT_DIR)/e2e-multisig-conway.sh

clean:
	@echo "$(YELLOW)Cleaning...$(NC)"
	@rm -rf $(WALLET_DIR) 2>/dev/null || true
	@if [ -d "$(MULTISIG_APP_PROJECT_DIR)" ]; then \
		cd $(MULTISIG_APP_PROJECT_DIR) && $(CARGO_RUN) clean 2>/dev/null || true; \
	fi
	@find . -name "*.bak" -delete 2>/dev/null || true
	@echo "$(GREEN)All cleaned$(NC)"

readme:
	@echo "$(BLUE)=== Linera Multisig Testing Documentation ===$(NC)"
	@echo ""
	@echo "$(BOLD)$(GREEN)E2E Testing on Conway Testnet$(NC)"
	@echo "   - Full end-to-end validation"
	@echo "   - Deploys and tests all Safe-like operations"
	@echo "   - 20/20 tests passing (when network stable)"
	@echo "   - Command: make e2e-verify"
	@echo ""
	@echo "$(YELLOW)Quick Start:$(NC)"
	@echo "  cd scripts"
	@echo "  make e2e-verify"
	@echo ""
	@echo "$(CYAN)For more information:$(NC)"
	@echo "  - scripts/README.md"
	@echo "  - docs/e2e-results/ - Test results"
	@echo "  - docs/research/CONWAY_TESTNET_PROOF_OF_EXECUTION.md"

# Legacy targets (kept for compatibility)
cli-test:
	@echo "$(YELLOW)CLI testing deprecated - use E2E tests instead$(NC)"
	@echo "$(CYAN)Run: make e2e-verify$(NC)"

cli-show:
	@echo "$(YELLOW)CLI show deprecated - use E2E tests instead$(NC)"

cli-clean:
	@echo "$(YELLOW)Using global clean target$(NC)"
	@$(MAKE) clean

rust-publish:
	@echo "$(YELLOW)Use deploy-conway instead$(NC)"
	@$(MAKE) deploy-conway

all: e2e-verify
test: e2e-verify
