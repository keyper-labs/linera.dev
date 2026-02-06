# Linera Multisig Platform - Research & Implementation

> **Research repository for building a multi-signature wallet platform on Linera blockchain**
>
> **Status**: Research Complete | **Deployment**: 🔴 BLOCKED by SDK opcode 252 issue

---

## Contents

- [Overview](#overview)
- [Status](#critical-status)
- [Quick Start](#quick-start)
- [Makefile Reference](#makefile-reference)
- [Documentation](#documentation)
- [Blockers](#deployment-blockers)

---

## Overview

Research and testing infrastructure for a **Safe-like multisig wallet** on the **Linera blockchain**.

**Linera** is a microchain-based blockchain where each user has their own chain.

**Goal**: Build a multisig platform with m-of-n threshold enforcement, proposal workflows, and signer management.

**Current Status**: Implementation complete, deployment blocked by SDK issue (opcode 252).

---

## Critical Status

### Current State

| Component | Status | Notes |
|-----------|--------|-------|
| **Research** | ✅ Complete | Infrastructure and feasibility analyzed |
| **Multi-Owner Chains** | ✅ Validated | Native protocol feature working on testnet |
| **@linera/client SDK** | ✅ Available | TypeScript SDK for frontend/backend |
| **Wasm Multisig Contract** | 🔴 **BLOCKED** | Opcode 252 incompatibility (see below) |
| **Testnet Deployment** | 🔴 **BLOCKED** | Requires SDK fix from Linera team |

### The Blocker: Opcode 252

**Problem**: Cannot deploy custom Wasm multisig contracts to Linera testnet.

**Root Cause**:

```
linera-sdk 0.15.11
    └─ async-graphql = "=7.0.17" (exact version pin)
        └─ requires Rust 1.87+ (for let-chain syntax)
            └─ generates memory.copy (opcode 252)
                └─ Linera runtime rejects as unsupported
```

**Impact**: Even though the contract compiles and passes all 74 validation tests, deployment fails with:

```
Execution error: Invalid Wasm module: Unknown opcode 252 during Operation(0)
```

**Official Issue**: [linera-protocol#4742](https://github.com/linera-io/linera-protocol/issues/4742)

**Full Analysis**: See [`docs/reports/COMPREHENSIVE_TEST_REPORT.md`](docs/reports/COMPREHENSIVE_TEST_REPORT.md)

---

## Tech Stack

### What Works (Validated)

| Layer | Technology | Status |
|-------|-----------|--------|
| **Frontend** | React + TypeScript + @linera/client | ✅ Available |
| **Backend** | Node.js/TypeScript + @linera/client | ✅ Available |
| **Protocol** | Linera Multi-Owner Chains | ✅ Working (1-of-N) |
| **Wallet** | Custom Ed25519 via SDK | ✅ Available |

### What Doesn't Work (Blocked)

| Component | Technology | Blocker |
|-----------|-----------|---------|
| **Smart Contracts** | Rust → Wasm (linera-sdk) | ❌ Opcode 252 |
| **Threshold Logic** | Custom m-of-n implementation | ❌ Requires Wasm |
| **Safe-like UX** | Propose → Approve → Execute | ❌ Requires Wasm |

---

## Prerequisites

### Required Software

```bash
# Linera CLI (for blockchain interaction)
# Visit: https://linera.dev/developers/getting_started/index.html

# Rust toolchain (for SDK testing)
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh

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

### Reproduce Our Findings

```bash
# From repository root - run all 10 documented attempts
make all

# Individual attempts
make attempt-1   # Multi-owner chain validation
make attempt-2   # Compile full contract, detect opcode 252
make attempt-3   # Compile minimal contract (73 opcodes)
make attempt-4   # Remove .clone() calls
make attempt-5   # Remove proposal history
make attempt-6   # Remove GraphQL service
make attempt-7   # Try Rust 1.86.0
make attempt-8   # Patch async-graphql
make attempt-9   # Downgrade to async-graphql 6.x
make attempt-10  # Combined best effort

make summary     # Show final results
```

### Development Testing

```bash
cd scripts

make cli-test      # Test multi-owner chains
make rust-test     # Build Wasm contract
make rust-publish  # Attempt deployment (will fail)
```

---

## Testing Infrastructure

| Test Type | Command | Status |
|-----------|---------|--------|
| CLI Multi-Owner | `cd scripts && make cli-test` | ⚠️ Requires reachable faucet/testnet |
| SDK Multisig | `cd scripts && make rust-test` | ⚠️ Requires crates.io access (or cached deps); deploy still blocked |

Full test report: [`docs/reports/COMPREHENSIVE_TEST_REPORT.md`](docs/reports/COMPREHENSIVE_TEST_REPORT.md)

---

## Makefile Reference

This repository has **TWO Makefiles** for different purposes:

### Root Makefile: Reproducible Failed Attempts

**Location**: [`/Makefile`](Makefile) (root directory)

**Purpose**: Reproduces all 10 documented failed attempts from the comprehensive test report. Each `attempt-X` target executes REAL code and fails as documented.

```bash
# Run from project root - no need to cd
make all         # Run all 10 attempts (will fail as documented)
make summary     # Show final conclusion
```

| Command | Description | Attempt # | Result |
|---------|-------------|-----------|--------|
| `make init` | Initialize environment via `scripts/Makefile` | - | Setup |
| `make help` | Show all available commands | - | Documentation |
| `make all` | Run all 10 attempts | 1-10 | Full validation |

#### Blocker #1: Multi-Owner Chain (Attempt #1)

| Command | Description | Result |
|---------|-------------|--------|
| `make attempt-1` | Run multi-owner chain validation | ❌ 1-of-N, no threshold |

#### Blocker #2: Opcode 252 (Attempts #2-10)

| Command | Description | Opcode Count | Result |
|---------|-------------|--------------|--------|
| `make attempt-2` | Compile full contract, detect opcode 252 | 222 | ❌ Blocked |
| `make attempt-3` | Compile minimal contract (threshold-signatures) | 73 | ❌ Blocked |
| `make attempt-4` | Remove .clone() calls from source | N/A | ❌ Breaks mutability |
| `make attempt-5` | Remove proposal history and measure | 85 | ⚠️ Reduced, still blocked |
| `make attempt-6` | Remove GraphQL service and measure | 82 | ⚠️ Reduced, still blocked |
| `make attempt-7` | Try Rust 1.86.0 (pre-opcode 252) | N/A | ❌ async-graphql incompatible |
| `make attempt-8` | Apply patch to async-graphql version | N/A | ❌ Exact pin prevents override |
| `make attempt-9` | Downgrade to async-graphql 6.x | N/A | ❌ API incompatible |
| `make attempt-10` | Combined best effort result | 73 | ⚠️ Minimum, still blocked |

#### Technical Validation

| Command | Description |
|---------|-------------|
| `make validate-env` | Validate environment (Rust, wasm32, linera, wasm-objdump) |
| `make test-compilation` | Compile WASM and report size |
| `make test-opcode-detection` | Count opcode 252 with wasm-objdump |
| `make clean` / `make clean-all` | Clean build artifacts |

**Key Finding**: Even with ALL optimizations combined, the minimum achievable opcode 252 count is **73**. These come from linera-sdk internal code, NOT from contract implementation.

---

### Scripts Makefile: Testing Suite

**Location**: [`scripts/Makefile`](scripts/Makefile)

**Purpose**: Orchestrates CLI and SDK testing for development workflow.

```bash
cd scripts  # Makefile is in scripts/ directory
```

| Command | Description | Associated With |
|---------|-------------|-----------------|
| `make help` | Show all available commands | Documentation |
| `make init` | Initialize test environment | Setup |
| `make cli-test` | Run CLI multi-owner chain tests | **Protocol-level multisig** |
| `make rust-test` | Build and test Rust Wasm contract | **Application-level multisig** |
| `make rust-publish` | Attempt module publish to testnet | **Deployment attempt** |
| `make all` | Run all tests (CLI + SDK) | Full validation pipeline |
| `make clean` | Clean all generated artifacts |

**Behavior**: `scripts/Makefile` is fail-fast. If CLI/scripts/network prerequisites are missing, commands return non-zero.

**Key Finding**: Minimum achievable opcode 252 count is **73** (from linera-sdk internals, not contract code).

**Quick Reference**:

- **Root Makefile** (`/Makefile`): Reproduce all 10 failed attempts
- **Scripts Makefile** (`scripts/Makefile`): Development testing (CLI + SDK)

---

## Architecture

### Architecture Overview

**Multi-Owner Chain** (protocol level):

- 1-of-N execution (any owner can execute)
- Native protocol feature
- ✅ Working on testnet

**Multisig Application** (Wasm contract level):

- M-of-N threshold enforcement
- Proposal/approval workflow
- 🔴 Blocked by opcode 252

**Stack**: React frontend → Node.js backend → Linera Network

---

## Documentation

| Document | Description |
|----------|-------------|
| [Comprehensive Test Report](docs/reports/COMPREHENSIVE_TEST_REPORT.md) | Test results, blocker analysis, all 10 attempts |
| [Infrastructure Analysis](docs/INFRASTRUCTURE_ANALYSIS.md) | Linera technical capabilities |
| [Platform Proposal](docs/PROPOSAL/linera-multisig-platform-proposal.md) | Implementation proposal with timeline |
| [Conway Testnet Validation](docs/research/CONWAY_TESTNET_VALIDATION.md) | Test evidence from testnet |
| [Opcode 252 Analysis](docs/research/LINERA_OPCODE_252_ISSUE.md) | Deployment blocker technical details |

---

## Deployment Blockers

### Blocker #1: No Multisig Semantics in Multi-Owner Chains

**Problem**: Linera's native multi-owner chain operates as **1-of-N** (any owner can execute), not **M-of-N** (threshold required).

| Feature | Safe-like Multisig (Required) | Linera Multi-Owner (Actual) | Match |
|---------|------------------------------|----------------------------|-------|
| Threshold enforcement | M-of-N required | 1-of-N execution | ❌ |
| Confirmation tracking | Track approvals per owner | No confirmation counting | ❌ |
| Proposal lifecycle | Submit → Approve → Execute | Single step execution | ❌ |
| Revoke confirmations | Can revoke before execution | No confirmation to revoke | ❌ |

### Blocker #2: Opcode 252 - Wasm Deployment Failure

**Official Issue**: [linera-protocol#4742](https://github.com/linera-io/linera-protocol/issues/4742)

**Status**: Open - No workaround available at project level

**All Attempted Solutions Failed**:

1. Use multi-owner chain as-is → Doesn't provide multisig
2. Deploy custom Wasm contract → Opcode 252 error
3. Minimal threshold signatures → Still 73 opcodes
4-10. Technical workarounds → Minimum 73 opcodes achieved

**Conclusion**: This is an **SDK ecosystem issue** requiring Linera team intervention.

---

## Troubleshooting

### Common Issues

**Issue**: `linera: command not found`

- **Solution**: Install Linera CLI from <https://linera.dev/developers/getting_started/index.html>

**Issue**: `Failed to connect to faucet`

- **Solution**: Ensure Linera testnet is running or use Conway testnet faucet

**Issue**: Rust build errors

- **Solution**: Ensure Rust toolchain is installed: `rustc --version`

**Issue**: Wallet file not found

- **Solution**: Run `make init` from repository root (or `cd scripts && make init`) and set `LINERA_WALLET` if needed

**Issue**: Opcode 252 error during deployment

- **Solution**: This is expected - see [`docs/reports/COMPREHENSIVE_TEST_REPORT.md`](docs/reports/COMPREHENSIVE_TEST_REPORT.md) for full explanation

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
- [Issue #4742: Applications don't load with Rust 1.87+](https://github.com/linera-io/linera-protocol/issues/4742)

---

## License

Apache 2.0

---

**Repository**: <https://github.com/keyper-labs/linera.dev>
**Last Updated**: February 6, 2026
