# Linera Multisig Testing Suite

**Status**: PoC Complete - Contract operational on Conway testnet

Complete E2E testing infrastructure for validating multisig functionality on Linera blockchain.

---

## Quick Start

```bash
cd scripts
make e2e-verify
```

This will:
1. Build the multisig contract with Rust 1.86.0
2. Publish to Conway testnet
3. Create a 2-of-3 multisig application
4. Execute all Safe-like operations
5. Generate detailed test report

**Expected**: 20/20 tests pass when network is stable (17-19/20 during congestion)

---

## Makefile Commands

| Command | Description |
|---------|-------------|
| `make e2e-verify` | Full E2E verification on Conway (deploy + test) |
| `make validate-conway-safe-e2e` | Safe-like E2E validation |
| `make deploy-conway` | Deploy to Conway testnet |
| `make validate-conway-74` | Validate 74-test suite |
| `make rust-build` | Build Wasm contract |
| `make clean` | Clean all generated files |

---

## Directory Structure

```
scripts/
├── Makefile                    # Main orchestration
├── e2e-multisig-conway.sh      # ⭐ Main E2E test script
├── deploy-multisig-conway.sh   # Deployment script
├── validate-conway-safe-e2e.sh # Safe-like validation
├── validate-conway-deployed-74.sh # 74-test suite
├── multisig-app/               # Rust contract source
└── multisig/                   # ⚠️ LEGACY - Development scripts
```

---

## Verified Operations

All core Safe-like multisig operations verified on Conway testnet:

| Operation | Description | Status |
|-----------|-------------|--------|
| ChangeThreshold | Modify approval threshold (2-of-3 to 1-of-3 and back) | ✅ PASS |
| Transfer | Move tokens between addresses | ✅ PASS |
| AddOwner | Add new owners to multisig (3 to 4 owners) | ✅ PASS |
| RevokeConfirmation | Revoke pending confirmations | ✅ PASS |
| Multi-owner confirmation | Threshold-based approval workflows | ✅ PASS |

---

## Documentation

| Document | Description |
|----------|-------------|
| [E2E Test Results](../docs/e2e-results/) | Tracked test results |
| [Comprehensive Report](../docs/reports/COMPREHENSIVE_TEST_REPORT.md) | Complete test report |
| [Proof of Execution](../docs/research/CONWAY_TESTNET_PROOF_OF_EXECUTION.md) | Full E2E validation |
| [Platform Proposal](../docs/PROPOSAL/linera-multisig-platform-proposal.md) | Implementation proposal |

---

## Legacy Scripts

The `scripts/multisig/` directory contains intermediate development scripts used during research. These have been superseded by the main E2E testing suite.

See [`scripts/multisig/README.md`](./multisig/README.md) for details.

---

## Prerequisites

```bash
# Rust 1.86.0 (required for opcode 252 workaround)
rustup install 1.86.0
rustup default 1.86.0

# Linera CLI
# Visit: https://linera.dev/developers/getting_started/index.html
```

---

## Troubleshooting

| Issue | Solution |
|-------|----------|
| `linera: command not found` | Install Linera CLI from https://linera.dev |
| Rust build errors | Ensure Rust 1.86.0 is installed |
| Network timeouts | Conway testnet congestion - re-run test |
| `wasm32-unknown-unknown` missing | Run: `rustup target add wasm32-unknown-unknown` |

---

## References

- [Linera Documentation](https://linera.dev/developers/core_concepts/index.html)
- [Conway Testnet Faucet](https://faucet.testnet-conway.linera.net)
- [Project README](../README.md)

---

**Last Updated**: February 10, 2026
**Status**: PoC Verified on Conway Testnet
