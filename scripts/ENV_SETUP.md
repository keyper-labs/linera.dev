# Linera Multisig Testing - Environment Setup Quick Reference

## Prerequisites Installation

### 1. Install Rust Toolchain

```bash
# Install rustup (Rust toolchain installer)
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh

# Source the environment
source $HOME/.cargo/env

# Verify installation
rustc --version
cargo --version
```

### 2. Install Linera CLI

```bash
# From Linera documentation
# Visit: https://linera.dev/developers/getting_started/index.html

# Example installation (check docs for latest method)
cargo install linera-service

# Verify installation
linera --version
```

### 3. Start Linera Testnet

```bash
# Start a development testnet
linera-server --dev

# In another terminal, verify it's running
curl http://localhost:8080/health
```

## Environment Variables

### Required Variables

```bash
# Faucet URL (for requesting test tokens)
export FAUCET_URL=http://localhost:8080

# Wallet configuration
export LINERA_WALLET=wallet.json
export LINERA_STORAGE=rocksdb:wallet.db:runtime:default
export LINERA_KEYSTORE=keystore.db

# Optional: Rust toolchain
export RUST_TOOLCHAIN=stable

# Optional: Project directories
export WALLET_DIR=$(pwd)/test-wallets
export PROJECT_DIR=$(pwd)/multisig-app
export LINERA_SDK_VERSION=0.12.0
```

### Persistent Configuration

Add to your shell profile (`~/.zshrc` or `~/.bashrc`):

```bash
# Linera configuration
export FAUCET_URL=http://localhost:8080
export LINERA_WALLET=$HOME/.linera/wallet.json
export LINERA_STORAGE=rocksdb:$HOME/.linera/wallet.db:runtime:default
export LINERA_KEYSTORE=$HOME/.linera/keystore.db
```

Then reload:
```bash
source ~/.zshrc  # or source ~/.bashrc
```

## Quick Start Commands

### Initial Setup

```bash
# Navigate to project
cd /Users/alfredolopez/Documents/GitHub/PalmeraDAO/linera.dev

# Run initialization
make init

# Or manually:
mkdir -p test-wallets multisig-app
```

### Run Tests

```bash
# Run all tests
make all

# CLI tests only
make cli-test

# SDK tests only
make rust-test

# View results
make cli-show
```

### Clean Up

```bash
# Clean everything
make clean

# Clean CLI wallets
make cli-clean

# Clean Rust build
make rust-clean
```

## Verification Steps

### 1. Verify Linera Installation

```bash
# Check Linera CLI
linera --version

# Check linera-server
linera-server --version

# Start testnet
linera-server --dev &

# Wait a few seconds, then check
curl http://localhost:8080/health
```

### 2. Verify Wallet Creation

```bash
# Initialize a test wallet
linera wallet init --faucet $FAUCET_URL

# Request a chain
linera wallet request-chain --faucet $FAUCET_URL

# Show wallet state
linera wallet show
```

### 3. Verify Rust Installation

```bash
# Check Rust version
rustc --version
cargo --version

# Add Wasm target (required for Linera)
rustup target add wasm32-unknown-unknown

# Verify target
rustup target list | grep wasm32
```

### 4. Verify Script Execution

```bash
# Test CLI script (dry run)
bash -n scripts/multisig-test-cli.sh

# Test SDK script (dry run)
bash -n scripts/multisig-test-rust.sh

# If no errors, scripts are syntactically correct
```

## Troubleshooting

### Issue: `linera: command not found`

**Solution**:
```bash
# Install Linera CLI
cargo install linera-service

# Or add to PATH if installed elsewhere
export PATH=$HOME/.cargo/bin:$PATH
```

### Issue: `Failed to connect to faucet`

**Solution**:
```bash
# Start Linera testnet
linera-server --dev

# In another terminal, test connection
curl http://localhost:8080/health

# If port different, update FAUCET_URL
export FAUCET_URL=http://localhost:8081  # example
```

### Issue: Rust build errors

**Solution**:
```bash
# Update Rust toolchain
rustup update stable

# Add Wasm target
rustup target add wasm32-unknown-unknown

# Clean and rebuild
cd multisig-app
cargo clean
cargo build --release
```

### Issue: Wallet file not found

**Solution**:
```bash
# Set correct paths
export LINERA_WALLET=$(pwd)/wallet.json
export LINERA_STORAGE=rocksdb:$(pwd)/wallet.db:runtime:default
export LINERA_KEYSTORE=$(pwd)/keystore.db

# Or use Makefile targets which set these automatically
make init
```

### Issue: Permission denied on scripts

**Solution**:
```bash
# Make scripts executable
chmod +x scripts/*.sh

# Verify
ls -l scripts/
```

## Development Workflow

### First Time Setup

```bash
# 1. Install prerequisites
rustc --version      # Verify Rust
linera --version     # Verify Linera CLI

# 2. Start testnet
linera-server --dev &

# 3. Set environment
source scripts/ENV_SETUP.md  # Or manually set variables

# 4. Run tests
make all
```

### Daily Workflow

```bash
# 1. Start testnet (if not running)
linera-server --dev &

# 2. Run tests
make all

# 3. Review results
make cli-show

# 4. Clean up (optional)
make clean
```

### Development Workflow

```bash
# 1. Make code changes
# Edit scripts or multisig-app/ sources

# 2. Build SDK app
make rust-build

# 3. Run tests
make rust-test

# 4. If tests pass, publish
make rust-publish

# 5. Deploy to chain
linera create-application <APP_ID> --chain-id <CHAIN_ID>
```

## Useful Aliases

Add to your shell profile for convenience:

```bash
# Linera aliases
alias linera-testnet='linera-server --dev'
alias linera-init='linera wallet init --faucet $FAUCET_URL'
alias linera-show='linera wallet show'
alias linera-chain='linera wallet request-chain --faucet $FAUCET_URL'

# Testing aliases
alias test-multisig='make all'
alias test-cli='make cli-test'
alias test-rust='make rust-test'

# Cleanup aliases
alias clean-all='make clean'
alias clean-wallets='make cli-clean'
alias clean-rust='make rust-clean'
```

## File Locations Reference

```
/Users/alfredolopez/Documents/GitHub/PalmeraDAO/linera.dev/
├── scripts/
│   ├── multisig-test-cli.sh      # CLI testing script
│   ├── multisig-test-rust.sh     # SDK testing script
│   ├── Makefile                   # Orchestration
│   ├── README.md                  # Main documentation
│   ├── MULTISIG_TESTING_GUIDE.md  # This guide
│   └── ENV_SETUP.md              # Environment setup (this file)
├── test-wallets/                 # Created by CLI tests
│   ├── owner1_wallet.json
│   ├── owner2_wallet.json
│   ├── owner3_wallet.json
│   └── chain_ids.txt
└── multisig-app/                # Created by SDK tests
    ├── Cargo.toml
    ├── Makefile
    ├── README.md
    └── src/
        ├── contract.rs
        ├── service.rs
        ├── main.rs
        └── tests/
            └── multisig_tests.rs
```

## Additional Resources

### Documentation
- [Linera Developer Docs](https://linera.dev/developers/index.html)
- [Linera SDK Docs](https://docs.rs/linera-sdk/latest/linera_sdk/)
- [Project README](scripts/README.md)
- [Testing Guide](scripts/MULTISIG_TESTING_GUIDE.md)

### Research
- [Multisig Analysis](../open-agents/output-drafts/defi-analysis/research-multisig-analysis.md)
- [Architecture Overview](../open-agents/output-drafts/blockchain-research/research-architecture-overview.md)

### Community
- [Linera GitHub](https://github.com/linera-io/linera-protocol)
- [Linera Discord](https://discord.gg/linera)

## Checklist

Before running tests, verify:

- [ ] Rust toolchain installed (`rustc --version`)
- [ ] Linera CLI installed (`linera --version`)
- [ ] Linera testnet running (`linera-server --dev`)
- [ ] Environment variables set (see above)
- [ ] Scripts executable (`chmod +x scripts/*.sh`)
- [ ] Wasm target added (`rustup target add wasm32-unknown-unknown`)
- [ ] Faucet accessible (`curl $FAUCET_URL/health`)

When all checked, run:
```bash
make all
```

---

**Last Updated**: February 2, 2026
**Status**: Ready for use
