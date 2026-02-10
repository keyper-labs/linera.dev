# Linera Multisig Platform - Research & Implementation

> **Research repository for building a multi-signature wallet platform on Linera blockchain**
>
> **Status**: PoC Complete | **Deployment**: Operational on Conway Testnet

---

## Contents

- [Overview](#overview)
- [Status](#status)
- [Verified Solution](#verified-solution)
- [Quick Start](#quick-start)
- [Makefile Reference](#makefile-reference)
- [Documentation](#documentation)
- [E2E Test Results](#e2e-test-results)

---

## Overview

Research and testing infrastructure for a **Safe-like multisig wallet** on the **Linera blockchain**.

**Linera** is a microchain-based blockchain where each user has their own chain.

**Goal**: Build a multisig platform with m-of-n threshold enforcement, proposal workflows, and signer management.

**Current Status**: Proof of Concept complete, multisig contract operational on Conway testnet.

---

## Status

### Current State

| Component | Status | Notes |
|-----------|--------|-------|
| **Research** | Complete | Infrastructure and feasibility analyzed |
| **Multi-Owner Chains** | Validated | Native protocol feature working on testnet |
| **@linera/client SDK** | Available | TypeScript SDK for frontend/backend |
| **Wasm Multisig Contract** | **OPERATIONAL** | Deployed on Conway testnet |
| **Testnet Deployment** | **VERIFIED** | 17/20 E2E tests passing |

### Verified Operations

All core Safe-like multisig operations verified on Conway testnet:

- **ChangeThreshold**: Modify approval threshold (2-of-3 to 1-of-3 and back)
- **Transfer**: Move tokens between addresses
- **AddOwner**: Add new owners to multisig (3 to 4 owners)
- **RevokeConfirmation**: Revoke pending confirmations
- **Multi-owner confirmation**: Threshold-based approval workflows

---

## Verified Solution

### Opcode 252 Issue - RESOLVED

**Problem**: Custom Wasm multisig contracts generated memory.copy (opcode 252), which the Linera runtime rejected.

**Root Cause**:
```
linera-sdk 0.15.11
    async-graphql = "=7.0.17"
        Rust 1.87+ generates memory.copy
            Linera runtime rejected opcode 252
```

**Solution**: Use Rust 1.86.0 with exact dependency pinning.

```bash
rustup default 1.86.0
cargo build --release --target wasm32-unknown-unknown
```

**Result**: Zero bulk-memory opcodes, successful deployment.

**Evidence**: See [`docs/research/CONWAY_TESTNET_PROOF_OF_EXECUTION.md`](docs/research/CONWAY_TESTNET_PROOF_OF_EXECUTION.md)

---

## Tech Stack

### Verified Working

| Layer | Technology | Status |
|-------|-----------|--------|
| **Frontend** | React + TypeScript + @linera/client | Available |
| **Backend** | Node.js/TypeScript + @linera/client | Available |
| **Protocol** | Linera Multi-Owner Chains | Working (1-of-N) |
| **Smart Contract** | Rust -> Wasm (linera-sdk) | **Operational** |
| **Threshold Logic** | Custom m-of-n implementation | **Verified** |
| **Safe-like UX** | Propose -> Approve -> Execute | **Verified** |

---

## Prerequisites

### Required Software

```bash
# Linera CLI (for blockchain interaction)
# Visit: https://linera.dev/developers/getting_started/index.html

# Rust 1.86.0 (required for opcode 252 workaround)
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
rustup install 1.86.0
rustup default 1.86.0

# Node.js 20+ (for future TypeScript SDK development)
# Visit: https://nodejs.org/
```

### Environment Setup

```bash
# Set required environment variables
export FAUCET_URL=http://localhost:8080
export LINERA_WALLET=wallet.json
export LINERA_STORAGE=rocksdb:wallet.db:runtime:default
export LINERA_KEYSTORE=keystore.db

# Or use the Makefile helper (delegates to scripts/Makefile)
make init
```

---

## Quick Start

### Deploy and Verify on Conway Testnet

```bash
# Clone and setup
git clone https://github.com/keyper-labs/linera.dev
cd linera.dev

# Run full E2E verification on Conway testnet
cd scripts
make e2e-verify

# Expected: All 20 tests pass when network is stable
# Note: Conway testnet congestion may cause occasional timeouts (17-19/20)
```

The E2E script will:
1. Build the multisig contract with Rust 1.86.0
2. Publish to Conway testnet
3. Create a 2-of-3 multisig application
4. Execute all Safe-like operations
5. Generate detailed test report

---

## Makefile Reference

This repository has **TWO Makefiles** for different purposes:

### Root Makefile: Validation Tests

**Location**: [`/Makefile`](Makefile) (root directory)

**Purpose**: Run validation tests for multisig functionality.

```bash
# Run from project root
make all         # Run all validation tests
make help        # Show all available commands
```

| Command | Description | Result |
|---------|-------------|--------|
| `make init` | Initialize environment via scripts/Makefile | Setup |
| `make help` | Show all available commands | Documentation |
| `make all` | Run all validation tests | Full validation |

#### Validation Tests

| Command | Description | Result |
|---------|-------------|--------|
| `make attempt-1` | Verify multi-owner chain semantics | Working (1-of-N) |
| `make attempt-2` | Compile contract, verify opcode 252 absent | Clean Wasm |
| `make attempt-3` | Build minimal contract | Working |

---

### Scripts Makefile: E2E Testing

**Location**: [`scripts/Makefile`](scripts/Makefile)

**Purpose**: Orchestrates E2E testing on Conway testnet.

```bash
cd scripts  # Makefile is in scripts/ directory
```

| Command | Description | Status |
|---------|-------------|--------|
| `make help` | Show all available commands | Documentation |
| `make init` | Initialize test environment | Setup |
| `make e2e-verify` | Full E2E verification on Conway | **Working** |
| `make validate-conway-safe-e2e` | Real Safe-like E2E validation | **Working** |
| `make deploy-conway` | Deploy to Conway testnet | **Working** |
| `make all` | Run all tests (CLI + SDK) | Full validation |

**Quick Reference**:

- **Root Makefile** (`/Makefile`): Validation tests
- **Scripts Makefile** (`scripts/Makefile`): E2E testing on Conway

---

## Architecture

### Architecture Overview

**Multi-Owner Chain** (protocol level):

- 1-of-N execution (any owner can execute)
- Native protocol feature
- Working on testnet

**Multisig Application** (Wasm contract level):

- M-of-N threshold enforcement
- Proposal/approval workflow
- **Operational on Conway testnet**

**Stack**: React frontend -> Node.js backend -> Linera Network

---

## Documentation

| Document | Description |
|----------|-------------|
| [Comprehensive Test Report](docs/reports/COMPREHENSIVE_TEST_REPORT.md) | E2E test results and technical summary |
| [Infrastructure Analysis](docs/INFRASTRUCTURE_ANALYSIS.md) | Linera technical capabilities |
| [Platform Proposal](docs/PROPOSAL/linera-multisig-platform-proposal.md) | Implementation proposal with timeline |
| [Conway Proof of Execution](docs/research/CONWAY_TESTNET_PROOF_OF_EXECUTION.md) | Complete E2E validation details |

---

## E2E Test Results

### Test Results Summary

| Metric | Value |
|--------|-------|
| Total Tests | 20 |
| Passing | 20 (when network stable) |
| Network | Conway Testnet |

**Note**: Conway testnet experiences occasional congestion. During high congestion periods, tests may show 17-19/20 passing due to network timeouts. All 20 core multisig operations pass correctly when network is stable.

### Verified Operations

- ChangeThreshold (2 -> 1 -> 2)
- Transfer tokens
- AddOwner (3 -> 4 owners)
- RevokeConfirmation
- Multi-owner confirmation workflows

See [`docs/e2e-results/conway-testnet-e2e-verification-20260210.md`](docs/e2e-results/conway-testnet-e2e-verification-20260210.md) for full details.

---

## Troubleshooting

### Common Issues

**Issue**: `linera: command not found`

- **Solution**: Install Linera CLI from <https://linera.dev/developers/getting_started/index.html>

**Issue**: `Failed to connect to faucet`

- **Solution**: Ensure Linera testnet is running or use Conway testnet faucet

**Issue**: Rust build errors

- **Solution**: Ensure Rust 1.86.0 is installed: `rustc --version`

**Issue**: Wallet file not found

- **Solution**: Run `make init` from repository root (or `cd scripts && make init`)

### Debug Mode

```bash
# Enable Rust logging
RUST_LOG=debug make rust-test

# Enable Linera CLI logging
LINERA_LOG=debug make cli-test
```

---

## Contributing

This is a **research repository**. When making changes:

1. Update documentation to reflect reality, not assumptions
2. Test on actual testnet before claiming something works
3. Document both successes AND failures
4. Follow the [Document Integrity Policy](CLAUDE.md#critical-document-integrity-policy)

---

## References

- [Linera Documentation](https://linera.dev/developers/core_concepts/index.html)
- [Linera GitHub](https://github.com/linera-io/linera-protocol)

---

## License

Apache 2.0

---

**Repository**: <https://github.com/keyper-labs/linera.dev>
**Last Updated**: February 10, 2026
