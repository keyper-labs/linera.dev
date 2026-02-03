# Linera SDK API

Rust SDK for building Linera applications.

## Overview

The `linera-sdk` provides the runtime environment and APIs for building WebAssembly applications on Linera.

## Crate Structure

| Crate | Purpose | Version |
|-------|---------|---------|
| `linera-sdk` | Application development | 0.15.11 |
| `linera-sdk-derive` | Procedural macros | 0.15.11 |
| `linera-views` | State management | 0.15.11 |
| `linera-views-derive` | View macros | 0.15.11 |

## Cargo.toml

```toml
[package]
name = "my-app"
version = "0.1.0"
edition = "2021"

[dependencies]
linera-sdk = "0.15.11"
linera-views = "0.15.11"
serde = { version = "1.0", features = ["derive"] }
async-trait = "0.1"

[dev-dependencies]
linera-sdk = { version = "0.15.11", features = ["test"] }

[[bin]]
name = "contract"
path = "src/contract.rs"

[[bin]]
name = "service"
path = "src/service.rs"
```

## Contract Runtime

### Contract Trait

```rust
use async_trait::async_trait;
use linera_sdk::{Contract, ContractRuntime};

pub struct MyContract {
    state: MyState,
    runtime: ContractRuntime<Self>,
}

#[async_trait]
impl Contract for MyContract {
    type Message = MyMessage;
    type Parameters = MyParameters;
    type InstantiationArgument = MyInitArgs;

    async fn load(runtime: ContractRuntime<Self>) -> Self {
        let state = MyState::load(runtime.root_view_storage_context())
            .await
            .expect("Failed to load state");
        Self { state, runtime }
    }

    async fn instantiate(&mut self, argument: MyInitArgs) {
        // Initialize contract
        self.state.value.set(argument.initial_value);
    }

    async fn execute_operation(&mut self, operation: MyOperation) -> Self::Response {
        match operation {
            MyOperation::Increment => {
                let value = self.state.value.get() + 1;
                self.state.value.set(value);
                value
            }
        }
    }

    async fn execute_message(&mut self, message: MyMessage) {
        // Handle cross-chain message
    }

    async fn store(mut self) {
        self.state.save().await.expect("Failed to save state");
    }
}
```

### ContractRuntime API

```rust
// Read chain ID
let chain_id = self.runtime.chain_id();

// Read application ID
let app_id = self.runtime.application_id();

// Read authenticated signer
let signer = self.runtime.authenticated_signer();

// Get current block height
let height = self.runtime.block_height();

// Get current timestamp
let timestamp = self.runtime.system_time();

// Query another application
let response: Response = self.runtime
    .call_application(true, app_id, &query)
    .await;

// Send cross-chain message
self.runtime
    .prepare_message(message)
    .with_authentication()
    .send_to(destination_chain);

// Open a new chain
let (chain_id, cert) = self.runtime
    .open_chain(ownership, permissions, balance)
    .await;

// Close current chain
self.runtime.close_chain().await;

// Assert before deadline
self.runtime.assert_before(deadline);
```

## Service Runtime

### Service Trait

```rust
use async_trait::async_trait;
use linera_sdk::{Service, ServiceRuntime};

pub struct MyService {
    state: MyState,
    runtime: ServiceRuntime<Self>,
}

#[async_trait]
impl Service for MyService {
    type Parameters = MyParameters;
    type Query = MyQuery;
    type QueryResponse = MyResponse;

    async fn new(runtime: ServiceRuntime<Self>) -> Self {
        let state = MyState::load(runtime.root_view_storage_context())
            .await
            .expect("Failed to load state");
        Self { state, runtime }
    }

    async fn handle_query(&self, query: MyQuery) -> MyResponse {
        match query {
            MyQuery::GetValue => {
                MyResponse::Value(*self.state.value.get())
            }
        }
    }
}
```

### ServiceRuntime API

```rust
// Read chain ID
let chain_id = self.runtime.chain_id();

// Read application ID
let app_id = self.runtime.application_id();

// Query application state
let state = self.runtime.query_application(app_id, &query).await;

// Check if application is authorized
let authorized = self.runtime.is_authorized_app(app_id);
```

## State Management

### Views

```rust
use linera_sdk::views::{RegisterView, MapView, QueueView, LogView};
use linera_views::views::RootView;

#[derive(RootView)]
pub struct MyState {
    // Single value
    pub counter: RegisterView<u64>,
    
    // Key-value map
    pub balances: MapView<AccountOwner, Amount>,
    
    // FIFO queue
    pub pending: QueueView<Operation>,
    
    // Append-only log
    pub history: LogView<Event>,
    
    // Set
    pub owners: SetView<AccountOwner>,
    
    // Collection
    pub proposals: MapView<u64, Proposal>,
}
```

### View Operations

```rust
// RegisterView
let value = *self.state.counter.get();
self.state.counter.set(value + 1);

// MapView
let balance = self.state.balances.get(&owner).await.unwrap_or(0);
self.state.balances.insert(&owner, balance + amount).await;
self.state.balances.remove(&owner).await;

// QueueView
self.state.pending.push_back(operation).await;
let op = self.state.pending.pop_front().await;

// LogView
self.state.history.append(event).await;
let events = self.state.history.read(0..10).await;

// SetView
self.state.owners.insert(&owner).await;
let is_member = self.state.owners.contains(&owner).await;
```

## Operations and Messages

### Defining Operations

```rust
use serde::{Deserialize, Serialize};

#[derive(Debug, Serialize, Deserialize)]
pub enum Operation {
    Transfer {
        recipient: Account,
        amount: Amount,
    },
    Approve {
        spender: AccountOwner,
        amount: Amount,
    },
    ExecuteProposal {
        proposal_id: u64,
    },
}
```

### Defining Messages

```rust
#[derive(Debug, Serialize, Deserialize)]
pub enum Message {
    Credit {
        owner: AccountOwner,
        amount: Amount,
    },
    ProposalApproved {
        proposal_id: u64,
        approver: AccountOwner,
    },
}
```

## Cross-Chain Messaging

### Sending Messages

```rust
// Simple message
self.runtime
    .prepare_message(Message::Credit { owner, amount })
    .send_to(destination_chain);

// Authenticated message
self.runtime
    .prepare_message(Message::ProposalApproved { proposal_id, approver })
    .with_authentication()
    .send_to(destination_chain);

// Tracked message (bounce on failure)
self.runtime
    .prepare_message(Message::Transfer { to, amount })
    .with_authentication()
    .track_message()
    .send_to(destination_chain);
```

### Receiving Messages

```rust
async fn execute_message(&mut self, message: Message) {
    match message {
        Message::Credit { owner, amount } => {
            let balance = self.state.balances.get(&owner).await.unwrap_or(0);
            self.state.balances.insert(&owner, balance + amount).await;
        }
        Message::ProposalApproved { proposal_id, approver } => {
            // Handle approval
        }
    }
}
```

## Cross-Application Calls

### Same-Chain Calls

```rust
// Call another application on the same chain
let response: Response = self.runtime
    .call_application(
        /* authenticated */ true,
        /* app_id */ target_app_id,
        /* operation */ &operation,
    )
    .await;
```

### Query Applications

```rust
// Query another application's service
let state: AppState = self.runtime
    .query_application(app_id, &query)
    .await;
```

## Testing

### Unit Tests

```rust
#[cfg(test)]
mod tests {
    use linera_sdk::test::*;

    #[tokio::test]
    async fn test_increment() {
        let mut contract = create_contract().await;
        
        let result = contract
            .execute_operation(Operation::Increment)
            .await;
        
        assert_eq!(result, 1);
    }

    fn create_contract() -> MyContract {
        let runtime = ContractRuntime::new();
        MyContract::load(runtime).await
    }
}
```

### Integration Tests

```rust
#[tokio::test]
async fn test_cross_chain_message() {
    let (validator, chains) = TestValidator::new().await;
    let chain1 = chains[0];
    let chain2 = chains[1];
    
    // Publish application
    let app = validator
        .publish_application(contract, service, init_args)
        .await;
    
    // Send message
    app.on_chain(chain1)
        .execute_operation(Operation::SendMessage {
            to: chain2,
            amount: 100,
        })
        .await;
    
    // Process message on destination
    app.on_chain(chain2)
        .process_inbox()
        .await;
}
```

## Common Patterns

### Access Control

```rust
fn ensure_owner(&self) {
    let signer = self.runtime.authenticated_signer()
        .expect("No authenticated signer");
    assert!(
        self.state.owners.contains(&signer).await,
        "Not an owner"
    );
}
```

### Timelock

```rust
async fn execute_with_timelock(&mut self, proposal_id: u64) {
    let proposal = self.state.proposals.get(&proposal_id).await
        .expect("Proposal not found");
    
    // Check deadline
    self.runtime.assert_before(proposal.deadline);
    
    // Execute
    self.execute_proposal(proposal_id).await;
}
```

### Event Logging

```rust
async fn log_event(&mut self, event_type: EventType, data: Value) {
    let event = Event {
        timestamp: self.runtime.system_time(),
        block_height: self.runtime.block_height(),
        event_type,
        data,
    };
    self.state.events.append(event).await;
}
```

## Error Handling

```rust
use linera_sdk::base::ContractError;

pub enum MyError {
    NotOwner,
    InsufficientBalance,
    ProposalNotFound,
    AlreadyExecuted,
}

impl From<MyError> for ContractError {
    fn from(err: MyError) -> Self {
        match err {
            MyError::NotOwner => ContractError::Unauthorized,
            MyError::InsufficientBalance => ContractError::InsufficientFunds,
            _ => ContractError::ExecutionError(err.to_string()),
        }
    }
}
```

## Build Configuration

```toml
# Cargo.toml (project)
[profile.release]
opt-level = 'z'
lto = true
panic = 'abort'
codegen-units = 1

# .cargo/config.toml
[build]
target = "wasm32-unknown-unknown"

[target.wasm32-unknown-unknown]
runner = "wasmtime"
```

## See Also

- [linera-sdk docs](https://docs.rs/linera-sdk/)
- [linera-views docs](https://docs.rs/linera-views/)
- [Example Applications](https://github.com/linera-io/linera-protocol/tree/main/examples)
