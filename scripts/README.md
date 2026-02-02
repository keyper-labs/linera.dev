# Linera Multisig Testing Suite

Complete testing infrastructure for validating multisig functionality on Linera blockchain.

## Overview

This testing suite provides two complementary approaches to testing multisig functionality:

1. **CLI-Based Testing**: Tests Linera's native multi-owner chains
2. **SDK-Based Testing**: Tests application-level multisig with threshold verification

## Quick Start

### Prerequisites

```bash
# Install Linera CLI
# Visit: https://linera.dev/developers/getting_started/index.html

# Install Rust (for SDK testing)
# Visit: https://rustup.rs/

# Start Linera testnet (or use existing)
linera-server --dev
```

### Environment Setup

```bash
# Set required environment variables
export FAUCET_URL=http://localhost:8080
export LINERA_WALLET=wallet.json
export LINERA_STORAGE=rocksdb:wallet.db:runtime:default
export LINERA_KEYSTORE=keystore.db

# Or use the Makefile target
make init
```

### Run All Tests

```bash
# Run both CLI and SDK tests
make all

# Or run individually
make cli-test    # CLI multi-owner chain tests
make rust-test   # SDK multisig application tests
```

## CLI Testing (Multi-Owner Chains)

### What It Tests

- **Multi-owner chain creation** using Linera's native `open-multi-owner-chain` command
- **Owner key generation** for multiple wallets
- **Chain ownership semantics** (all owners can propose blocks independently)
- **Simple and advanced multi-owner chain configurations**

### Running CLI Tests

```bash
# Run all CLI tests
make cli-test

# Or directly
bash scripts/multisig-test-cli.sh

# View wallet states after tests
make cli-show

# Clean up test wallets
make cli-clean
```

### Expected Output

The CLI test will:
1. Create 3 test wallets (Owner 1, Owner 2, Owner 3)
2. Request chains from faucet for each owner
3. Generate unassigned keypairs for Owners 2 and 3
4. Create a simple multi-owner chain
5. Create an advanced multi-owner chain with custom configuration
6. Display wallet states

### Important Notes

⚠️ **CLI multi-owner chains do NOT provide threshold-based multisig**
- All owners can propose blocks independently
- No m-of-n approval mechanism at protocol level
- Use SDK-based testing for true threshold multisig

## SDK Testing (Application-Level Multisig)

### What It Tests

- **m-of-n threshold verification** (custom implementation)
- **Transaction lifecycle**: propose → approve → execute
- **Approval tracking** with on-chain state
- **Owner management** (add/remove owners)
- **Threshold management** (change required approvals)

### Running SDK Tests

```bash
# Run SDK tests (builds project + runs tests)
make rust-test

# Or directly
bash scripts/multisig-test-rust.sh

# Build only
make rust-build

# Clean build artifacts
make rust-clean

# Publish to testnet (after building)
make rust-publish
```

### Project Structure

The SDK test creates a complete Rust project:

```
multisig-app/
├── Cargo.toml              # Project configuration
├── Makefile                # Build commands
├── README.md               # Detailed documentation
└── src/
    ├── main.rs             # Entry point
    ├── contract.rs         # Multisig contract logic
    ├── service.rs          # Query service
    └── tests/
        └── multisig_tests.rs  # Integration tests
```

### Multisig Operations

| Operation | Description | Threshold Check |
|-----------|-------------|-----------------|
| `Init` | Initialize with owners and threshold | No |
| `ProposeTransaction` | Propose a new transaction | No |
| `Approve` | Approve a pending transaction | No |
| `Execute` | Execute approved transaction | **Yes (m-of-n)** |
| `AddOwner` | Add a new owner | No |
| `RemoveOwner` | Remove an owner | No |
| `ChangeThreshold` | Change required approvals | No |

### Running Individual Tests

```bash
cd multisig-app

# Run all tests
cargo test

# Run specific test
cargo test test_multisig_initialization
cargo test test_propose_transaction
cargo test test_insufficient_approvals
cargo test test_add_owner
cargo test test_change_threshold
```

## Comparison

| Feature | CLI Multi-Owner | SDK Multisig |
|---------|----------------|--------------|
| **Threshold** | No (all owners equal) | Yes (m-of-n) |
| **Approvals** | Not tracked | Tracked on-chain |
| **Execution** | Anyone can execute | Threshold required |
| **Setup** | Simple (CLI commands) | Complex (Rust app) |
| **Gas Costs** | Lower | Higher (multiple ops) |
| **Flexibility** | Low | High |
| **Use Case** | Shared wallets | True multisig |

## Architecture

### CLI Multi-Owner Chains

```
┌─────────────────────────────────────┐
│     Multi-Owner Chain (Protocol)    │
│  ┌────────┐  ┌────────┐  ┌────────┐│
│  │Owner 1 │  │Owner 2 │  │Owner 3 ││
│  └────────┘  └────────┘  └────────┘│
│       │           │           │    │
│       └───────────┴───────────┘    │
│               ▼                    │
│      All can propose blocks        │
└─────────────────────────────────────┘
```

### SDK Multisig Application

```
┌─────────────────────────────────────────┐
│     Multi-Owner Chain (Infrastructure) │
│              ↓                          │
│  ┌──────────────────────────────────┐  │
│  │   Multisig Application (Logic)   │  │
│  │  ┌────────────────────────────┐ │  │
│  │  │ State:                     │ │  │
│  │  │  - owners: [Owner1,2,3]    │ │  │
│  │  │  - threshold: 2            │ │  │
│  │  │  - pending_txs: Map        │ │  │
│  │  └────────────────────────────┘ │  │
│  │                                  │  │
│  │  Operations:                     │  │
│  │  1. Propose → creates pending    │  │
│  │  2. Approve → adds approval      │  │
│  │  3. Execute → checks threshold  │  │
│  └──────────────────────────────────┘  │
└─────────────────────────────────────────┘
```

## Deployment

### Deploy CLI Multi-Owner Chain

```bash
# The CLI test already creates chains
# Use the chain IDs from test output

# Interact with chain
linera sync <CHAIN_ID>
linera process-inbox --chain-id <CHAIN_ID>
```

### Deploy SDK Multisig Application

```bash
# 1. Build and publish
make rust-publish

# 2. Create application instance
linera create-application <APP_ID> --chain-id <CHAIN_ID>

# 3. Initialize multisig
linera query --application-id <APP_ID> --chain-id <CHAIN_ID> \
    --json '{"Init": {"owners": [...], "threshold": 2}}'
```

## Troubleshooting

### Common Issues

**Issue**: `linera: command not found`
- **Solution**: Install Linera CLI from https://linera.dev/developers/getting_started/index.html

**Issue**: `Failed to connect to faucet`
- **Solution**: Ensure Linera testnet is running (`linera-server --dev`)

**Issue**: Rust build errors
- **Solution**: Ensure Rust toolchain is installed (`rustc --version`)

**Issue**: Wallet file not found
- **Solution**: Run `make init` or set `LINERA_WALLET` environment variable

### Debug Mode

```bash
# Enable debug logging
RUST_LOG=debug make rust-test

# Show Linera CLI debug output
LINERA_LOG=debug make cli-test
```

## Security Considerations

⚠️ **Important Security Notes**:

1. **Testnet Only**: These scripts are for testing only. Do not use with mainnet funds.
2. **Key Security**: Never commit private keys or wallet files to version control.
3. **Audit Required**: The SDK multisig implementation needs security audit before production use.
4. **Threshold Logic**: Always verify threshold logic is correct before deployment.
5. **Gas Costs**: SDK multisig operations cost more gas (multiple transactions required).

## Contributing

To add new tests or modify existing ones:

1. **CLI Tests**: Edit `scripts/multisig-test-cli.sh`
2. **SDK Tests**: Edit `scripts/multisig-test-rust.sh` (project generation logic) or test files in `multisig-app/src/tests/`
3. **Documentation**: Update this README and individual script documentation

## References

- [Linera Documentation](https://linera.dev/developers/core_concepts/index.html)
- [Linera SDK](https://docs.rs/linera-sdk/latest/linera_sdk/)
- [Linera GitHub](https://github.com/linera-io/linera-protocol)
- Project Research: `/Users/alfredolopez/Documents/GitHub/PalmeraDAO/linera.dev/docs/`

## License

Apache 2.0

---

**Last Updated**: February 2, 2026
