.PHONY: help init cli-test rust-test clean all

# Linera Multisig Testing Makefile
# This Makefile orchestrates CLI and SDK-based multisig testing

# Configuration
WALLET_DIR ?= $(PWD)/test-wallets
PROJECT_DIR ?= $(PWD)/multisig-app
FAUCET_URL ?= http://localhost:8080
LINERA_SDK_VERSION ?= 0.12.0

# Colors for output
BLUE := \033[0;34m
GREEN := \033[0;32m
YELLOW := \033[1;33m
RED := \033[0;31m
NC := \033[0m # No Color

help:
	@echo "$(BLUE)Linera Multisig Testing - Available Commands$(NC)"
	@echo ""
	@echo "$(GREEN)Setup Commands:$(NC)"
	@echo "  make init              - Initialize environment"
	@echo "  make clean             - Clean all generated files"
	@echo ""
	@echo "$(GREEN)CLI Testing (Multi-Owner Chains):$(NC)"
	@echo "  make cli-test          - Run CLI-based multi-owner chain tests"
	@echo "  make cli-show          - Show wallet states from CLI tests"
	@echo "  make cli-clean         - Clean CLI test wallets"
	@echo ""
	@echo "$(GREEN)SDK Testing (Application-Level Multisig):$(NC)"
	@echo "  make rust-test         - Build and test Rust SDK multisig app"
	@echo "  make rust-build        - Build the Rust application"
	@echo "  make rust-clean        - Clean Rust build artifacts"
	@echo "  make rust-publish      - Publish application to testnet"
	@echo ""
	@echo "$(GREEN)Full Testing Pipeline:$(NC)"
	@echo "  make all               - Run all tests (CLI + SDK)"
	@echo "  make test              - Alias for 'all'"
	@echo ""
	@echo "$(GREEN)Documentation:$(NC)"
	@echo "  make readme            - Show detailed README"
	@echo ""
	@echo "$(YELLOW)Environment Variables:$(NC)"
	@echo "  FAUCET_URL            - Faucet URL (default: $(FAUCET_URL))"
	@echo "  WALLET_DIR            - Wallet directory (default: $(WALLET_DIR))"
	@echo "  PROJECT_DIR           - Rust project directory (default: $(PROJECT_DIR))"
	@echo "  LINERA_SDK_VERSION    - Linera SDK version (default: $(LINERA_SDK_VERSION))"
	@echo ""
	@echo "$(YELLOW)Required Environment Variables:$(NC)"
	@echo "  LINERA_WALLET         - Path to wallet.json"
	@echo "  LINERA_STORAGE        - Path to wallet DB"
	@echo "  LINERA_KEYSTORE       - Path to keystore"

init:
	@echo "$(BLUE)Initializing Linera multisig testing environment...$(NC)"
	@mkdir -p $(WALLET_DIR)
	@mkdir -p $(PROJECT_DIR)
	@echo "$(GREEN)Environment initialized$(NC)"
	@echo "$(YELLOW)Remember to set:$(NC)"
	@echo "  export FAUCET_URL=$(FAUCET_URL)"
	@echo "  export LINERA_WALLET=wallet.json"
	@echo "  export LINERA_STORAGE=rocksdb:wallet.db:runtime:default"
	@echo "  export LINERA_KEYSTORE=keystore.db"

cli-test:
	@echo "$(BLUE)=== Running CLI Multi-Owner Chain Tests ===$(NC)"
	@echo "$(YELLOW)Testing multi-owner chains using Linera CLI$(NC)"
	@echo ""
	@bash scripts/multisig-test-cli.sh

cli-show:
	@echo "$(BLUE)=== Showing CLI Wallet States ===$(NC)"
	@if [ -f "$(WALLET_DIR)/chain_ids.txt" ]; then \
		cat $(WALLET_DIR)/chain_ids.txt; \
		echo ""; \
	fi
	@for wallet in owner1 owner2 owner3; do \
		echo "$(GREEN)$$wallet Wallet:$(NC)"; \
		LINERA_WALLET=$(WALLET_DIR)/$${wallet}_wallet.json \
		LINERA_STORAGE=rocksdb:$(WALLET_DIR)/$${wallet}.db:runtime:default \
		LINERA_KEYSTORE=$(WALLET_DIR)/$${wallet}_keystore.db \
		linera wallet show 2>/dev/null || echo "Wallet not found"; \
		echo ""; \
	done

cli-clean:
	@echo "$(YELLOW)Cleaning CLI test wallets...$(NC)"
	@rm -rf $(WALLET_DIR)
	@echo "$(GREEN)CLI test wallets cleaned$(NC)"

rust-test:
	@echo "$(BLUE)=== Running Rust SDK Multisig Application Tests ===$(NC)"
	@echo "$(YELLOW)Building and testing application-level multisig$(NC)"
	@echo ""
	@bash scripts/multisig-test-rust.sh

rust-build:
	@echo "$(BLUE)=== Building Rust Multisig Application ===$(NC)"
	@if [ -d "$(PROJECT_DIR)" ]; then \
		cd $(PROJECT_DIR) && \
		cargo build --release --features contract,service; \
		echo "$(GREEN)Build complete$(NC)"; \
	else \
		echo "$(RED)Project not found. Run 'make rust-test' first.$(NC)"; \
		exit 1; \
	fi

rust-clean:
	@echo "$(YELLOW)Cleaning Rust build artifacts...$(NC)"
	@if [ -d "$(PROJECT_DIR)" ]; then \
		cd $(PROJECT_DIR) && cargo clean; \
		echo "$(GREEN)Rust build artifacts cleaned$(NC)"; \
	else \
		echo "$(YELLOW)No Rust project to clean$(NC)"; \
	fi

rust-publish: rust-build
	@echo "$(BLUE)=== Publishing Rust Multisig Application ===$(NC)"
	@echo "$(YELLOW)Publishing to testnet at $(FAUCET_URL)$(NC)"
	@if [ -d "$(PROJECT_DIR)" ]; then \
		cd $(PROJECT_DIR) && \
		linera publish \
			./target/wasm32-unknown-unknown/release/linera_multisig_contract.wasm \
			./target/wasm32-unknown-unknown/release/linera_multisig_service.wasm \
			--faucet $(FAUCET_URL); \
		echo "$(GREEN)Application published$(NC)"; \
	else \
		echo "$(RED)Project not found. Run 'make rust-test' first.$(NC)"; \
		exit 1; \
	fi

all: cli-test rust-test
	@echo "$(GREEN)=== All Tests Complete ===$(NC)"
	@echo "$(BLUE)CLI Tests:$(NC) Multi-owner chains tested"
	@echo "$(BLUE)SDK Tests:$(NC) Application-level multisig tested"
	@echo ""
	@echo "$(YELLOW)Next Steps:$(NC)"
	@echo "1. Review test results above"
	@echo "2. Check wallet states: make cli-show"
	@echo "3. Publish application: make rust-publish"
	@echo "4. Deploy to chain: linera create-application <APP_ID> --chain-id <CHAIN_ID>"

test: all

clean: cli-clean rust-clean
	@echo "$(GREEN)All cleaned$(NC)"

readme:
	@echo "$(BLUE)=== Linera Multisig Testing Documentation ===$(NC)"
	@echo ""
	@echo "This testing suite validates multisig functionality on Linera blockchain"
	@echo "using two complementary approaches:"
	@echo ""
	@echo "$(GREEN)1. CLI-Based Testing (Multi-Owner Chains)$(NC)"
	@echo "   - Tests Linera's native multi-owner chain functionality"
	@echo "   - Creates chains with multiple owners"
	@echo "   - All owners can independently propose blocks"
	@echo "   - No threshold verification (protocol limitation)"
	@echo "   - Command: make cli-test"
	@echo ""
	@echo "$(GREEN)2. SDK-Based Testing (Application-Level Multisig)$(NC)"
	@echo "   - Implements m-of-n threshold multisig"
	@echo "   - Custom Rust application with approval tracking"
	@echo "   - Transaction lifecycle: propose → approve → execute"
	@echo "   - Full threshold verification before execution"
	@echo "   - Command: make rust-test"
	@echo ""
	@echo "$(YELLOW)Key Differences:$(NC)"
	@echo "  CLI Multi-Owner:"
	@echo "    - Native Linera feature"
	@echo "    - Simple to set up"
	@echo "    - No threshold logic"
	@echo "    - All owners equal"
	@echo ""
	@echo "  SDK Multisig:"
	@echo "    - Custom application"
	@echo "    - Requires development"
	@echo "    - Full threshold verification"
	@echo "    - Flexible ownership rules"
	@echo ""
	@echo "$(YELLOW)Required Environment Variables:$(NC)"
	@echo "  export FAUCET_URL=$(FAUCET_URL)"
	@echo "  export LINERA_WALLET=wallet.json"
	@echo "  export LINERA_STORAGE=rocksdb:wallet.db:runtime:default"
	@echo "  export LINERA_KEYSTORE=keystore.db"
	@echo ""
	@echo "$(YELLOW)Quick Start:$(NC)"
	@echo "  1. Ensure Linera testnet is running"
	@echo "  2. Set environment variables (see above)"
	@echo "  3. Run: make all"
	@echo ""
	@echo "For more information, see scripts/multisig-test-cli.sh and"
	@echo "scripts/multisig-test-rust.sh"
