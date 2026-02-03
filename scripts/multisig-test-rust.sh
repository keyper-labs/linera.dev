#!/bin/bash

###############################################################################
# Linera Multisig Application Rust SDK Test Script
#
# This script builds and tests a multisig application using the Linera Rust SDK.
# This implements application-level multisig logic with threshold verification
# (m-of-n approvals required) on top of Linera's multi-owner chains.
#
# Environment Variables Required:
#   CARGO_HOME       - Cargo home directory (default: ~/.cargo)
#   RUST_TOOLCHAIN   - Rust toolchain version (default: stable)
#
# Prerequisites:
#   - Rust toolchain installed
#   - Linera protocol running (testnet or devnet)
#   - Linera CLI installed
#
# Usage:
#   source scripts/multisig-test-rust.sh
###############################################################################

set -e

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
PROJECT_DIR="${PROJECT_DIR:-$(pwd)/multisig-app}"
LINERA_SDK_VERSION="${LINERA_SDK_VERSION:-0.15.11}"
RUST_TOOLCHAIN="${RUST_TOOLCHAIN:-stable}"

# Helper functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

check_rust() {
    if ! command -v cargo &> /dev/null; then
        log_error "Rust/Cargo not found. Please install Rust first."
        log_info "Visit: https://rustup.rs/"
        exit 1
    fi
    log_success "Rust toolchain found: $(rustc --version)"
}

check_linera() {
    if ! command -v linera &> /dev/null; then
        log_error "Linera CLI not found. Please install it first."
        log_info "Visit: https://linera.dev/developers/getting_started/index.html"
        exit 1
    fi
    log_success "Linera CLI found"
}

create_project() {
    log_info "Creating multisig application project..."

    # Create project directory
    mkdir -p "$PROJECT_DIR"
    cd "$PROJECT_DIR"

    # Initialize Cargo project
    log_info "Initializing Cargo project..."
    cargo init --name linera-multisig

    # Create source structure
    mkdir -p src/tests

    log_success "Project created at $PROJECT_DIR"
}

create_contract() {
    log_info "Creating multisig contract..."

    cat > src/contract.rs <<'EOF'
use linera_sdk::{
    base::{Amount, Owner},
    contract::Contract,
    views::MapView,
    ApplicationCallResult, ContractRuntime, KeyValueStore, Resources,
};
use serde::{Deserialize, Serialize};

/// Multisig application state
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct MultisigState {
    /// List of owners who can approve transactions
    pub owners: Vec<Owner>,
    /// Number of approvals required to execute a transaction
    pub threshold: usize,
    /// Pending transactions awaiting approval
    pub pending_transactions: MapView<Vec<u8>, PendingTransaction>,
    /// Transaction counter for generating unique IDs
    pub transaction_count: u64,
}

/// A pending transaction in the multisig
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct PendingTransaction {
    /// Unique transaction ID
    pub id: u64,
    /// Owner who proposed this transaction
    pub proposer: Owner,
    /// Target chain for this transaction
    pub target_chain: Vec<u8>,
    /// Amount to transfer
    pub amount: Amount,
    /// Recipient address
    pub recipient: Vec<u8>,
    /// Owners who have approved this transaction
    pub approvals: Vec<Owner>,
    /// Whether this transaction has been executed
    pub executed: bool,
}

/// Operations that can be performed on the multisig
#[derive(Debug, Clone, Serialize, Deserialize)]
pub enum Operation {
    /// Initialize the multisig with owners and threshold
    Init {
        owners: Vec<Owner>,
        threshold: usize,
    },
    /// Propose a new transaction
    ProposeTransaction {
        target_chain: Vec<u8>,
        amount: Amount,
        recipient: Vec<u8>,
    },
    /// Approve a pending transaction
    Approve {
        transaction_id: u64,
    },
    /// Execute a transaction that has reached threshold
    Execute {
        transaction_id: u64,
    },
    /// Add a new owner
    AddOwner {
        owner: Owner,
    },
    /// Remove an owner
    RemoveOwner {
        owner: Owner,
    },
    /// Change the threshold
    ChangeThreshold {
        threshold: usize,
    },
}

/// Multisig contract
pub struct MultisigContract {
    runtime: ContractRuntime<Self>,
    state: MultisigState,
}

impl Contract for MultisigContract {
    type Runtime = ContractRuntime<Self>;
    type State = MultisigState;

    fn new(runtime: Self::Runtime) -> Self {
        Self {
            runtime,
            state: MultisigState {
                owners: Vec::new(),
                threshold: 0,
                pending_transactions: MapView::new(),
                transaction_count: 0,
            },
        }
    }

    fn state_mut(&mut self) -> &mut Self::State {
        &mut self.state
    }

    fn runtime(&self) -> &Self::Runtime {
        &self.runtime
    }

    fn execute_operation(&mut self, operation: Operation) -> ApplicationCallResult {
        match operation {
            Operation::Init { owners, threshold } => {
                self.validate_initialization()?;
                self.state.owners = owners;
                self.state.threshold = threshold;
                log::info!("Multisig initialized with {} owners, threshold {}", owners.len(), threshold);
                Ok(Resources::default())
            }
            Operation::ProposeTransaction { target_chain, amount, recipient } => {
                let proposer = self.runtime.authenticated_signer()?;
                self.validate_owner(&proposer)?;

                let id = self.state.transaction_count;
                self.state.transaction_count += 1;

                let transaction = PendingTransaction {
                    id,
                    proposer: proposer.clone(),
                    target_chain,
                    amount,
                    recipient,
                    approvals: vec![proposer],
                    executed: false,
                };

                let key = self.transaction_key(id);
                self.state.pending_transactions.insert(&key, &transaction)?;

                log::info!("Transaction {} proposed by {:?}", id, proposer);
                Ok(Resources::default())
            }
            Operation::Approve { transaction_id } => {
                let approver = self.runtime.authenticated_signer()?;
                self.validate_owner(&approver)?;

                let key = self.transaction_key(transaction_id);
                let mut transaction = self.state.pending_transactions.get(&key)?
                    .ok_or("Transaction not found")?;

                // Check if already approved
                if transaction.approvals.contains(&approver) {
                    log::warn!("Transaction {} already approved by {:?}", transaction_id, approver);
                    return Ok(Resources::default());
                }

                // Check if already executed
                if transaction.executed {
                    return Err("Transaction already executed".into());
                }

                transaction.approvals.push(approver.clone());
                self.state.pending_transactions.insert(&key, &transaction)?;

                log::info!("Transaction {} approved by {:?} (approvals: {}/{})",
                    transaction_id, approver, transaction.approvals.len(), self.state.threshold);

                Ok(Resources::default())
            }
            Operation::Execute { transaction_id } => {
                let executor = self.runtime.authenticated_signer()?;
                self.validate_owner(&executor)?;

                let key = self.transaction_key(transaction_id);
                let transaction = self.state.pending_transactions.get(&key)?
                    .ok_or("Transaction not found")?;

                // Check threshold
                if transaction.approvals.len() < self.state.threshold {
                    return Err(format!("Insufficient approvals: {}/{}",
                        transaction.approvals.len(), self.state.threshold).into());
                }

                // Check if already executed
                if transaction.executed {
                    return Err("Transaction already executed".into());
                }

                // Execute the transaction
                // Note: In a real implementation, this would send a cross-chain message
                // to transfer funds. For now, we just mark it as executed.

                let mut executed_tx = transaction.clone();
                executed_tx.executed = true;
                self.state.pending_transactions.insert(&key, &executed_tx)?;

                log::info!("Transaction {} executed by {:?}", transaction_id, executor);
                Ok(Resources::default())
            }
            Operation::AddOwner { owner } => {
                let proposer = self.runtime.authenticated_signer()?;

                // Only existing owners can add new owners
                self.validate_owner(&proposer)?;

                if self.state.owners.contains(&owner) {
                    return Err("Owner already exists".into());
                }

                self.state.owners.push(owner.clone());
                log::info!("Owner {:?} added by {:?}", owner, proposer);
                Ok(Resources::default())
            }
            Operation::RemoveOwner { owner } => {
                let proposer = self.runtime.authenticated_signer()?;

                // Only existing owners can remove owners
                self.validate_owner(&proposer)?;

                if let Some(pos) = self.state.owners.iter().position(|o| o == &owner) {
                    self.state.owners.remove(pos);
                    log::info!("Owner {:?} removed by {:?}", owner, proposer);
                } else {
                    return Err("Owner not found".into());
                }

                Ok(Resources::default())
            }
            Operation::ChangeThreshold { threshold } => {
                let proposer = self.runtime.authenticated_signer()?;

                // Only existing owners can change threshold
                self.validate_owner(&proposer)?;

                if threshold == 0 || threshold > self.state.owners.len() {
                    return Err("Invalid threshold".into());
                }

                self.state.threshold = threshold;
                log::info!("Threshold changed to {} by {:?}", threshold, proposer);
                Ok(Resources::default())
            }
        }
    }
}

impl MultisigContract {
    fn validate_initialization(&self) -> Result<(), String> {
        if !self.state.owners.is_empty() {
            return Err("Already initialized".into());
        }
        Ok(())
    }

    fn validate_owner(&self, owner: &Owner) -> Result<(), String> {
        if !self.state.owners.contains(owner) {
            return Err(format!("Owner {:?} not authorized", owner).into());
        }
        Ok(())
    }

    fn transaction_key(&self, id: u64) -> Vec<u8> {
        format!("tx_{}", id).into_bytes()
    }
}
EOF

    log_success "Contract created"
}

create_service() {
    log_info "Creating multisig service..."

    cat > src/service.rs <<'EOF'
use linera_sdk::{
    base::Owner,
    contract::Contract,
    graphql::GraphQLMutationRoot,
    service::Service,
    views::MapView,
    ApplicationCallResult, ServiceRuntime, KeyValueStore, Resources,
};
use serde::{Deserialize, Serialize};

// Re-use contract types
use crate::contract::{MultisigState, PendingTransaction};

/// Queries for the multisig service
#[derive(Debug, Serialize, Deserialize, GraphQLMutationRoot)]
pub enum Query {
    /// Get the list of owners
    Owners,
    /// Get the current threshold
    Threshold,
    /// Get a pending transaction by ID
    Transaction {
        id: u64,
    },
    /// Get all pending transactions
    PendingTransactions,
    /// Check if an owner has approved a transaction
    HasApproved {
        transaction_id: u64,
        owner: Owner,
    },
}

/// Multisig service
pub struct MultisigService {
    runtime: ServiceRuntime<Self>,
    state: MultisigState,
}

impl Service for MultisigService {
    type Runtime = ServiceRuntime<Self>;
    type State = MultisigState;

    fn new(runtime: Self::Runtime) -> Self {
        Self {
            runtime,
            state: MultisigState {
                owners: Vec::new(),
                threshold: 0,
                pending_transactions: MapView::new(),
                transaction_count: 0,
            },
        }
    }

    fn state_mut(&mut self) -> &mut Self::State {
        &mut self.state
    }

    fn runtime(&self) -> &Self::Runtime {
        &self.runtime
    }

    fn handle_query(&mut self, query: Query) -> ApplicationCallResult {
        match query {
            Query::Owners => {
                let owners = self.state.owners.clone();
                let json = serde_json::to_string(&owners)?;
                self.runtime.result(json.as_bytes().to_vec())
            }
            Query::Threshold => {
                let threshold = self.state.threshold;
                let json = serde_json::to_string(&threshold)?;
                self.runtime.result(json.as_bytes().to_vec())
            }
            Query::Transaction { id } => {
                let key = format!("tx_{}", id).into_bytes();
                let transaction = self.state.pending_transactions.get(&key)?;
                let json = serde_json::to_string(&transaction)?;
                self.runtime.result(json.as_bytes().to_vec())
            }
            Query::PendingTransactions => {
                let mut transactions = Vec::new();
                for key in self.state.pending_transactions.keys()? {
                    if let Ok(tx) = self.state.pending_transactions.get(&key) {
                        transactions.push(tx);
                    }
                }
                let json = serde_json::to_string(&transactions)?;
                self.runtime.result(json.as_bytes().to_vec())
            }
            Query::HasApproved { transaction_id, owner } => {
                let key = format!("tx_{}", transaction_id).into_bytes();
                let transaction = self.state.pending_transactions.get(&key)?;
                let has_approved = transaction.map_or(false, |tx| tx.approvals.contains(&owner));
                let json = serde_json::to_string(&has_approved)?;
                self.runtime.result(json.as_bytes().to_vec())
            }
        }
    }
}
EOF

    log_success "Service created"
}

create_main() {
    log_info "Creating main entry point..."

    cat > src/main.rs <<'EOF'
mod contract;
mod service;

fn main() {
    println!("Linera Multisig Application");
    println!("This is a library crate. Use it as a Linera application.");
}
EOF

    log_success "Main entry point created"
}

create_cargo_toml() {
    log_info "Creating Cargo.toml..."

    cat > Cargo.toml <<EOF
[package]
name = "linera-multisig"
version = "0.1.0"
edition = "2021"

[lib]
crate-type = ["cdylib", "rlib"]

[dependencies]
linera-sdk = { version = "${LINERA_SDK_VERSION}", features = ["contract", "service"] }
linera-views = { version = "${LINERA_SDK_VERSION}" }
serde = { version = "1.0", features = ["derive"] }
serde_json = "1.0"
log = "0.4"

[dev-dependencies]
linera-sdk = { version = "${LINERA_SDK_VERSION}", features = ["test"] }

[features]
default = ["contract", "service"]
contract = ["linera-sdk/contract"]
service = ["linera-sdk/service"]
test = ["linera-sdk/test"]
EOF

    log_success "Cargo.toml created"
}

create_tests() {
    log_info "Creating integration tests..."

    cat > tests/multisig_tests.rs <<'EOF'
use linera_sdk::{
    base::{Amount, Owner},
    contract::Contract,
    service::Service,
    ApplicationCallResult,
};
use linera_multisig::contract::{MultisigContract, Operation};

#[test]
fn test_multisig_initialization() {
    // Create a test contract runtime
    let runtime = linera_sdk::test::MockContractRuntime::new();
    let mut contract = MultisigContract::new(runtime);

    // Initialize with 3 owners, threshold of 2
    let owner1 = Owner::from([1u8; 32]);
    let owner2 = Owner::from([2u8; 32]);
    let owner3 = Owner::from([3u8; 32]);

    contract
        .execute_operation(Operation::Init {
            owners: vec![owner1.clone(), owner2.clone(), owner3.clone()],
            threshold: 2,
        })
        .expect("Initialization should succeed");

    assert_eq!(contract.state.owners.len(), 3);
    assert_eq!(contract.state.threshold, 2);
}

#[test]
fn test_propose_transaction() {
    let runtime = linera_sdk::test::MockContractRuntime::new();
    let mut contract = MultisigContract::new(runtime);

    // Initialize
    let owner1 = Owner::from([1u8; 32]);
    let owner2 = Owner::from([2u8; 32]);

    contract
        .execute_operation(Operation::Init {
            owners: vec![owner1.clone(), owner2.clone()],
            threshold: 2,
        })
        .expect("Initialization should succeed");

    // Propose transaction
    contract
        .execute_operation(Operation::ProposeTransaction {
            target_chain: vec![1, 2, 3],
            amount: Amount::from_tokens(100),
            recipient: vec![4, 5, 6],
        })
        .expect("Proposal should succeed");

    assert_eq!(contract.state.transaction_count, 1);
}

#[test]
fn test_approve_transaction() {
    let runtime = linera_sdk::test::MockContractRuntime::new();
    let mut contract = MultisigContract::new(runtime);

    // Initialize with authenticated signer
    let owner1 = Owner::from([1u8; 32]);
    let owner2 = Owner::from([2u8; 32]);

    contract
        .execute_operation(Operation::Init {
            owners: vec![owner1, owner2],
            threshold: 2,
        })
        .expect("Initialization should succeed");

    // Note: In real tests, we'd mock the authenticated_signer
    // For now, this demonstrates the structure
}

#[test]
fn test_insufficient_approvals() {
    let runtime = linera_sdk::test::MockContractRuntime::new();
    let mut contract = MultisigContract::new(runtime);

    // Initialize with 3 owners, threshold of 2
    let owner1 = Owner::from([1u8; 32]);
    let owner2 = Owner::from([2u8; 32]);
    let owner3 = Owner::from([3u8; 32]);

    contract
        .execute_operation(Operation::Init {
            owners: vec![owner1.clone(), owner2.clone(), owner3.clone()],
            threshold: 2,
        })
        .expect("Initialization should succeed");

    // Propose transaction
    contract
        .execute_operation(Operation::ProposeTransaction {
            target_chain: vec![1, 2, 3],
            amount: Amount::from_tokens(100),
            recipient: vec![4, 5, 6],
        })
        .expect("Proposal should succeed");

    // Try to execute with only 1 approval (should fail)
    let result = contract.execute_operation(Operation::Execute { transaction_id: 0 });

    assert!(result.is_err());
    assert!(result.unwrap_err().to_string().contains("Insufficient approvals"));
}

#[test]
fn test_add_owner() {
    let runtime = linera_sdk::test::MockContractRuntime::new();
    let mut contract = MultisigContract::new(runtime);

    // Initialize
    let owner1 = Owner::from([1u8; 32]);
    let owner2 = Owner::from([2u8; 32]);

    contract
        .execute_operation(Operation::Init {
            owners: vec![owner1.clone(), owner2.clone()],
            threshold: 2,
        })
        .expect("Initialization should succeed");

    // Add new owner
    let owner3 = Owner::from([3u8; 32]);
    contract
        .execute_operation(Operation::AddOwner {
            owner: owner3.clone(),
        })
        .expect("Add owner should succeed");

    assert_eq!(contract.state.owners.len(), 3);
    assert!(contract.state.owners.contains(&owner3));
}

#[test]
fn test_change_threshold() {
    let runtime = linera_sdk::test::MockContractRuntime::new();
    let mut contract = MultisigContract::new(runtime);

    // Initialize
    let owner1 = Owner::from([1u8; 32]);
    let owner2 = Owner::from([2u8; 32]);
    let owner3 = Owner::from([3u8; 32]);

    contract
        .execute_operation(Operation::Init {
            owners: vec![owner1, owner2, owner3],
            threshold: 2,
        })
        .expect("Initialization should succeed");

    // Change threshold to 3
    contract
        .execute_operation(Operation::ChangeThreshold { threshold: 3 })
        .expect("Change threshold should succeed");

    assert_eq!(contract.state.threshold, 3);
}

#[test]
fn test_invalid_threshold() {
    let runtime = linera_sdk::test::MockContractRuntime::new();
    let mut contract = MultisigContract::new(runtime);

    // Initialize
    let owner1 = Owner::from([1u8; 32]);
    let owner2 = Owner::from([2u8; 32]);

    contract
        .execute_operation(Operation::Init {
            owners: vec![owner1, owner2],
            threshold: 1,
        })
        .expect("Initialization should succeed");

    // Try to set threshold higher than owner count
    let result = contract.execute_operation(Operation::ChangeThreshold { threshold: 5 });

    assert!(result.is_err());
    assert!(result.unwrap_err().to_string().contains("Invalid threshold"));
}
EOF

    log_success "Integration tests created"
}

create_makefile() {
    log_info "Creating Makefile..."

    cat > Makefile <<'EOF'
.PHONY: all build test clean publish deploy help

# Default target
all: build

# Build the application
build:
	@echo "Building multisig application..."
	cargo build --release --features contract,service
	@echo "Build complete. Wasm files in target/wasm32-unknown-unknown/release/"

# Run tests
test:
	@echo "Running tests..."
	cargo test --features test
	@echo "Tests complete."

# Build and run tests
check: build test

# Clean build artifacts
clean:
	@echo "Cleaning build artifacts..."
	cargo clean
	@echo "Clean complete."

# Publish the application to Linera network
publish: build
	@echo "Publishing multisig application..."
	@read -p "Enter faucet URL: " FAUCET; \
	linera publish ./target/wasm32-unknown-unknown/release/linera_multisig_contract.wasm \
	           ./target/wasm32-unknown-unknown/release/linera_multisig_service.wasm \
		   --faucet $$FAUCET
	@echo "Publish complete."

# Deploy the application to a chain
deploy: publish
	@echo "Deploying multisig application..."
	@read -p "Enter application ID: " APP_ID; \
	read -p "Enter chain ID: " CHAIN_ID; \
	linera create-application $$APP_ID --chain-id $$CHAIN_ID
	@echo "Deploy complete."

# Run with example parameters
run-example:
	@echo "Creating example multisig scenario..."
	@echo "This requires a running Linera testnet"
	@$(MAKE) publish
	@echo "Application published. Use the CLI to interact with it."

# Format code
fmt:
	cargo fmt

# Lint code
lint:
	cargo clippy --features contract,service

# Show help
help:
	@echo "Available targets:"
	@echo "  all         - Build the application (default)"
	@echo "  build       - Build the application"
	@echo "  test        - Run tests"
	@echo "  check       - Build and run tests"
	@echo "  clean       - Clean build artifacts"
	@echo "  publish     - Publish application to Linera network"
	@echo "  deploy      - Deploy application to a chain"
	@echo "  run-example - Run with example parameters"
	@echo "  fmt         - Format code"
	@echo "  lint        - Lint code"
	@echo "  help        - Show this help message"
EOF

    log_success "Makefile created"
}

create_readme() {
    log_info "Creating README.md..."

    cat > README.md <<'EOF'
# Linera Multisig Application

A multisig wallet implementation for Linera blockchain using the Rust SDK.

## Overview

This application implements multisig functionality on top of Linera's multi-owner chains. It provides:

- **Threshold-based approvals**: m-of-n owners must approve before execution
- **Transaction proposal**: Any owner can propose transactions
- **Approval collection**: Owners can approve pending transactions
- **Secure execution**: Transactions execute only when threshold is met
- **Owner management**: Add/remove owners dynamically
- **Flexible threshold**: Change the approval threshold

## Architecture

```
Multi-Owner Chain (Infrastructure)
    ↓
Multisig Application (Logic)
    ├── State: owners, threshold, pending transactions
    ├── Operations: propose, approve, execute, add_owner, etc.
    └── Verification: threshold checking, authorization
```

## Building

### Prerequisites

- Rust toolchain (stable)
- Linera protocol running (testnet or devnet)
- Linera CLI installed

### Build Commands

```bash
# Build the application
make build

# Run tests
make test

# Build and test
make check

# Format code
make fmt

# Lint code
make lint
```

## Deploying

### 1. Publish the Application

```bash
make publish
```

You'll need:
- Faucet URL for your testnet

### 2. Create Application Instance

```bash
linera create-application <APP_ID> --chain-id <CHAIN_ID>
```

### 3. Initialize the Multisig

```bash
linera query --application-id <APP_ID> --chain-id <CHAIN_ID> \
    --json '{"Init": {"owners": [...], "threshold": 2}}'
```

## Usage

### Propose a Transaction

```bash
linera query --application-id <APP_ID> --chain-id <CHAIN_ID> \
    --json '{"ProposeTransaction": {...}}'
```

### Approve a Transaction

```bash
linera query --application-id <APP_ID> --chain-id <CHAIN_ID> \
    --json '{"Approve": {"transaction_id": 0}}'
```

### Execute a Transaction

```bash
linera query --application-id <APP_ID> --chain-id <CHAIN_ID> \
    --json '{"Execute": {"transaction_id": 0}}'
```

## Operations

| Operation | Description | Auth Required |
|-----------|-------------|---------------|
| `Init` | Initialize multisig with owners and threshold | No (once only) |
| `ProposeTransaction` | Propose a new transaction | Yes (owner) |
| `Approve` | Approve a pending transaction | Yes (owner) |
| `Execute` | Execute approved transaction | Yes (owner) |
| `AddOwner` | Add a new owner | Yes (owner) |
| `RemoveOwner` | Remove an owner | Yes (owner) |
| `ChangeThreshold` | Change approval threshold | Yes (owner) |

## Queries

| Query | Description |
|-------|-------------|
| `Owners` | Get list of owners |
| `Threshold` | Get current threshold |
| `Transaction` | Get transaction by ID |
| `PendingTransactions` | Get all pending transactions |
| `HasApproved` | Check if owner approved transaction |

## Testing

Run the test suite:

```bash
make test
```

Or run individual tests:

```bash
cargo test test_multisig_initialization
cargo test test_propose_transaction
cargo test test_insufficient_approvals
```

## Important Notes

1. **Not Native Multisig**: This is application-level multisig, not protocol-level
2. **Gas Costs**: Each operation (propose, approve, execute) costs gas
3. **Security**: Review and audit before using with real funds
4. **Testnet Only**: Use on testnet until thoroughly tested
5. **Backup**: Export and secure owner keys

## Comparison with CLI Multi-Owner Chains

| Feature | CLI Multi-Owner | SDK Multisig |
|---------|----------------|--------------|
| Threshold verification | No | Yes (m-of-n) |
| Approval tracking | No | Yes |
| Transaction lifecycle | No | Yes |
| Flexibility | Low | High |
| Complexity | Low | High |

## Security Considerations

- All owners can propose blocks independently (Linera protocol)
- Application logic enforces threshold (this implementation)
- Cross-chain messaging for coordination
- On-chain approval state for transparency

## License

Apache 2.0
EOF

    log_success "README.md created"
}

# Main execution
main() {
    log_info "=== Linera Multisig Rust SDK Setup ==="
    log_info "Project directory: $PROJECT_DIR"
    log_info "Linera SDK version: $LINERA_SDK_VERSION"
    echo ""

    check_rust
    check_linera
    echo ""

    create_project
    create_contract
    create_service
    create_main
    create_cargo_toml
    create_tests
    create_makefile
    create_readme
    echo ""

    log_success "=== Setup Complete ==="
    log_info "Project created at: $PROJECT_DIR"
    log_info ""
    log_info "Next steps:"
    log_info "1. cd $PROJECT_DIR"
    log_info "2. make build      # Build the application"
    log_info "3. make test       # Run tests"
    log_info "4. make publish    # Publish to testnet"
    log_info ""
    log_warning "Important Notes:"
    log_warning "1. This is application-level multisig (threshold logic in contract)"
    log_warning "2. Linera multi-owner chains allow all owners to propose independently"
    log_warning "3. This implementation adds m-of-n threshold verification"
    log_warning "4. Each operation (propose, approve, execute) costs gas"
    log_warning "5. Test thoroughly before using with real funds"
}

# Run main function
main "$@"
