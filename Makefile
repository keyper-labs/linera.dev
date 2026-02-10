# =============================================================================
# Linera Multisig Platform - Quick Reference
# =============================================================================
#
# This Makefile provides quick access to the main testing commands.
# For full E2E testing on Conway testnet, use scripts/Makefile.
#
# Status: PoC Complete - Contract operational on Conway testnet
# Version: 4.0.0
# Date: 2026-02-10
#
# =============================================================================

.PHONY: help init all test clean validate-env summary

# =============================================================================
# Configuration
# =============================================================================

PROJECT_ROOT := $(shell pwd)
SCRIPTS_DIR := $(PROJECT_ROOT)/scripts
MULTISIG_APP_DIR := $(SCRIPTS_DIR)/multisig-app

RUST_VERSION := $(shell rustc --version 2>/dev/null || echo "not installed")
CARGO_VERSION := $(shell cargo --version 2>/dev/null || echo "not installed")
LINERA_VERSION := $(shell linera --version 2>/dev/null | head -1 || echo "not installed")

BLUE := \033[0;34m
GREEN := \033[0;32m
YELLOW := \033[1;33m
CYAN := \033[0;36m
BOLD := \033[1m
NC := \033[0m

# =============================================================================
# Help Target
# =============================================================================

help:
	@echo "$(BOLD)$(BLUE)=======================================================================$(NC)"
	@echo "$(BOLD)  LINERA MULTISIG PLATFORM$(NC)"
	@echo "$(BOLD)  Status: PoC VERIFIED on Conway testnet$(NC)"
	@echo "$(BOLD)$(BLUE)=======================================================================$(NC)"
	@echo ""
	@echo "$(BOLD)$(CYAN)QUICK START:$(NC)"
	@echo "  $(GREEN)cd scripts && make e2e-verify$(NC) - Full E2E test on Conway"
	@echo ""
	@echo "$(BOLD)$(CYAN)SETUP:$(NC)"
	@echo "  $(GREEN)make init$(NC)         - Initialize environment"
	@echo "  $(GREEN)make validate-env$(NC) - Validate environment"
	@echo ""
	@echo "$(BOLD)$(CYAN)TESTING:$(NC)"
	@echo "  $(GREEN)make all$(NC)          - Run all validation tests"
	@echo "  $(GREEN)make test$(NC)         - Alias for 'all'"
	@echo ""
	@echo "$(BOLD)$(CYAN)MAINTENANCE:$(NC)"
	@echo "  $(GREEN)make clean$(NC)        - Clean build artifacts"
	@echo "  $(GREEN)make summary$(NC)      - Show verified capabilities"
	@echo ""
	@echo "$(BOLD)$(CYAN)DOCUMENTATION:$(NC)"
	@echo "  See README.md for complete documentation"
	@echo "  See docs/e2e-results/ for test results"

# =============================================================================
# Setup
# =============================================================================

init:
	@echo "$(CYAN)Initializing environment via scripts/Makefile...$(NC)"
	@$(MAKE) -C $(SCRIPTS_DIR) init

# =============================================================================
# Environment Validation
# =============================================================================

validate-env:
	@echo ""
	@echo "$(BOLD)$(BLUE)=======================================================================$(NC)"
	@echo "$(BOLD)$(BLUE)  ENVIRONMENT VALIDATION$(NC)"
	@echo "$(BOLD)$(BLUE)=======================================================================$(NC)"
	@echo ""
	@if command -v rustc &> /dev/null; then \
		echo "  [OK] Rust: $(RUST_VERSION)"; \
	else \
		echo "  [FAIL] Rust not installed"; exit 1; \
	fi
	@if command -v cargo &> /dev/null; then \
		echo "  [OK] Cargo: $(CARGO_VERSION)"; \
	else \
		echo "  [FAIL] Cargo not found"; exit 1; \
	fi
	@if rustup target list --installed 2>/dev/null | grep -q "wasm32-unknown-unknown"; then \
		echo "  [OK] Target wasm32-unknown-unknown installed"; \
	else \
		echo "  [FAIL] Target wasm32 not installed. Run: rustup target add wasm32-unknown-unknown"; exit 1; \
	fi
	@if command -v linera &> /dev/null; then \
		echo "  [OK] Linera CLI: $(LINERA_VERSION)"; \
	else \
		echo "  [WARN] Linera CLI not installed"; \
	fi
	@if command -v wasm-objdump &> /dev/null; then \
		echo "  [OK] wasm-objdump installed"; \
	else \
		echo "  [WARN] wasm-objdump not installed (install: brew install wabt)"; \
	fi
	@echo ""
	@echo "$(GREEN)Environment ready.$(NC)"

# =============================================================================
# Testing Targets
# =============================================================================

all: validate-env summary
	@echo ""
	@echo "$(CYAN)For full E2E testing, run:$(NC)"
	@echo "  $(GREEN)cd scripts && make e2e-verify$(NC)"
	@echo ""

test: all

# =============================================================================
# Summary
# =============================================================================

summary:
	@echo ""
	@echo "$(BOLD)$(BLUE)=======================================================================$(NC)"
	@echo "$(BOLD)$(BLUE)  PROOF OF CONCEPT COMPLETE$(NC)"
	@echo "$(BOLD)$(BLUE)=======================================================================$(NC)"
	@echo ""
	@echo "$(GREEN)Multisig contract operational on Conway testnet$(NC)"
	@echo ""
	@echo "$(CYAN)Verified Operations:$(NC)"
	@echo "  - ChangeThreshold (2->1->2)"
	@echo "  - Transfer tokens"
	@echo "  - AddOwner (3->4 owners)"
	@echo "  - RevokeConfirmation"
	@echo "  - Multi-owner workflows"
	@echo ""
	@echo "$(CYAN)Solution:$(NC)"
	@echo "  - Rust 1.86.0 with pinned dependencies"
	@echo "  - Zero bulk-memory opcodes"
	@echo "  - Full Safe-like functionality"
	@echo ""
	@echo "$(CYAN)Documentation:$(NC)"
	@echo "  - docs/e2e-results/        - Test results"
	@echo "  - docs/reports/            - Comprehensive reports"
	@echo "  - docs/research/           - Technical research"
	@echo "  - docs/PROPOSAL/           - Implementation proposal"
	@echo ""

# =============================================================================
# Maintenance
# =============================================================================

clean:
	@echo "$(YELLOW)Cleaning...$(NC)"
	@cd $(MULTISIG_APP_DIR) && cargo clean 2>/dev/null || true
	@find . -name "*.bak" -delete 2>/dev/null || true
	@echo "[OK] Cleaned"
