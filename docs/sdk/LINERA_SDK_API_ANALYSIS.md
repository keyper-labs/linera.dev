# Linera SDK API Analysis - v0.15.11 → v0.16.0

**Date**: February 3, 2026
**Repository**: <https://github.com/linera-io/linera-protocol>
**Analyzed By**: Claude Code (Zai GLM-4.7)

---

## Executive Summary

This report analyzes the current Linera SDK API (v0.16.0) by examining official examples from the `linera-protocol` repository. The analysis reveals significant architectural changes from v0.12.0, including a new trait-based system, simplified imports, and WIT-based WebAssembly integration.

**Key Findings**:

- New `Contract` and `Service` traits with `async fn` methods
- Simplified imports: `linera_sdk::*` instead of module-specific paths
- Macro-based exports: `contract!()` and `service!()`
- Views system for state management
- GraphQL integration via `async_graphql`
- Wasm32 target: `wasm32-unknown-unknown`

---

## 1. New Import Patterns

### v0.12.0 (OLD)

```rust
use linera_sdk::contract::Contract;
use linera_sdk::service::Service;
use linera_sdk::base::*;
```

### v0.16.0 (NEW)

```rust
// All from linera_sdk root
use linera_sdk::{
    Contract, ContractRuntime,
    Service, ServiceRuntime,
    linera_base_types::{WithContractAbi, WithServiceAbi, AccountOwner, Amount},
    views::{RootView, View, RegisterView, MapView, ViewStorageContext},
};
```

### Import Categories

| Category | Imports |
|----------|---------|
| **Core Traits** | `Contract`, `Service` |
| **Runtime** | `ContractRuntime`, `ServiceRuntime` |
| **ABI** | `WithContractAbi`, `WithServiceAbi` |
| **Base Types** | `linera_base_types::*` |
| **Views** | `views::{RootView, View, RegisterView, MapView}` |
| **GraphQL** | `graphql::GraphQLMutationRoot` |

---

## 2. Contract Trait Structure

### 2.1 Contract Trait Definition

```rust
#[allow(async_fn_in_trait)]
pub trait Contract: WithContractAbi + ContractAbi + Sized {
    /// Message type for cross-chain communication
    type Message: Serialize + DeserializeOwned + Debug;

    /// Immutable application parameters (e.g., token name)
    type Parameters: Serialize + DeserializeOwned + Clone + Debug;

    /// Instantiation argument (e.g., initial token amount)
    type InstantiationArgument: Serialize + DeserializeOwned + Debug;

    /// Event values for streams
    type EventValue: Serialize + DeserializeOwned + Debug;

    /// Load contract state
    async fn load(runtime: ContractRuntime<Self>) -> Self;

    /// Instantiate application (only on creator chain)
    async fn instantiate(&mut self, argument: Self::InstantiationArgument);

    /// Execute user operation
    async fn execute_operation(&mut self, operation: Self::Operation) -> Self::Response;

    /// Handle cross-chain message
    async fn execute_message(&mut self, message: Self::Message);

    /// React to stream events (optional)
    async fn process_streams(&mut self, _updates: Vec<StreamUpdate>) {}

    /// Persist state
    async fn store(self);
}
```

### 2.2 Example: Counter Contract

**File**: `examples/counter/src/contract.rs`

```rust
#![cfg_attr(target_arch = "wasm32", no_main)]

mod state;

use counter::{CounterAbi, CounterOperation};
use linera_sdk::{
    linera_base_types::WithContractAbi,
    views::{RootView, View},
    Contract, ContractRuntime,
};

use self::state::CounterState;

pub struct CounterContract {
    state: CounterState,
    runtime: ContractRuntime<Self>,
}

// Export the contract
linera_sdk::contract!(CounterContract);

impl WithContractAbi for CounterContract {
    type Abi = CounterAbi;
}

impl Contract for CounterContract {
    type Message = ();
    type InstantiationArgument = u64;
    type Parameters = ();
    type EventValue = ();

    async fn load(runtime: ContractRuntime<Self>) -> Self {
        let state = CounterState::load(runtime.root_view_storage_context())
            .await
            .expect("Failed to load state");
        CounterContract { state, runtime }
    }

    async fn instantiate(&mut self, value: u64) {
        self.runtime.application_parameters(); // Validate params
        self.state.value.set(value);
    }

    async fn execute_operation(&mut self, operation: CounterOperation) -> u64 {
        let CounterOperation::Increment { value } = operation;
        let new_value = self.state.value.get() + value;
        self.state.value.set(new_value);
        new_value
    }

    async fn execute_message(&mut self, _message: ()) {
        panic!("Counter application doesn't support any cross-chain messages");
    }

    async fn store(mut self) {
        self.state.save().await.expect("Failed to save state");
    }
}
```

### 2.3 Key Patterns

1. **Wasm Attribute**: `#![cfg_attr(target_arch = "wasm32", no_main)]`
2. **Macro Export**: `linera_sdk::contract!(ContractName)`
3. **State Management**: Using Views system
4. **Runtime Access**: `self.runtime.*` methods
5. **Async Methods**: All trait methods are `async`

---

## 3. Service Trait Structure

### 3.1 Service Trait Definition

```rust
#[allow(async_fn_in_trait)]
pub trait Service: WithServiceAbi + ServiceAbi + Sized {
    /// Immutable application parameters
    type Parameters: Serialize + DeserializeOwned + Send + Sync + Clone + Debug + 'static;

    /// Create service instance
    async fn new(runtime: ServiceRuntime<Self>) -> Self;

    /// Handle read-only query
    async fn handle_query(&self, query: Self::Query) -> Self::QueryResponse;
}
```

### 3.2 Example: Counter Service

**File**: `examples/counter/src/service.rs`

```rust
#![cfg_attr(target_arch = "wasm32", no_main)]

mod state;

use std::sync::Arc;

use async_graphql::{EmptySubscription, Object, Request, Response, Schema};
use counter::CounterOperation;
use linera_sdk::{linera_base_types::WithServiceAbi, views::View, Service, ServiceRuntime};

use self::state::CounterState;

pub struct CounterService {
    state: Arc<CounterState>,
    runtime: Arc<ServiceRuntime<Self>>,
}

// Export the service
linera_sdk::service!(CounterService);

impl WithServiceAbi for CounterService {
    type Abi = counter::CounterAbi;
}

impl Service for CounterService {
    type Parameters = ();

    async fn new(runtime: ServiceRuntime<Self>) -> Self {
        let state = CounterState::load(runtime.root_view_storage_context())
            .await
            .expect("Failed to load state");
        CounterService {
            state: Arc::new(state),
            runtime: Arc::new(runtime),
        }
    }

    async fn handle_query(&self, request: Request) -> Response {
        let schema = Schema::build(
            self.state.clone(),
            MutationRoot {
                runtime: self.runtime.clone(),
            },
            EmptySubscription,
        )
        .finish();
        schema.execute(request).await
    }
}

// GraphQL Mutation Root
struct MutationRoot {
    runtime: Arc<ServiceRuntime<CounterService>>,
}

#[Object]
impl MutationRoot {
    async fn increment(&self, value: u64) -> [u8; 0] {
        let operation = CounterOperation::Increment { value };
        self.runtime.schedule_operation(&operation);
        []
    }
}
```

### 3.3 Key Patterns

1. **Arc Wrapping**: State and runtime wrapped in `Arc` for thread safety
2. **GraphQL Integration**: Using `async_graphql`
3. **Query/Response**: Using `Request` and `Response` from `async_graphql`
4. **Read-Only**: Service cannot modify state
5. **Operation Scheduling**: `runtime.schedule_operation()`

---

## 4. ABI Definition

### 4.1 ABI Structure (lib.rs)

**File**: `examples/counter/src/lib.rs`

```rust
use async_graphql::{Request, Response};
use linera_sdk::linera_base_types::{ContractAbi, ServiceAbi};
use serde::{Deserialize, Serialize};

pub struct CounterAbi;

#[derive(Debug, Deserialize, Serialize)]
pub enum CounterOperation {
    Increment { value: u64 },
}

impl ContractAbi for CounterAbi {
    type Operation = CounterOperation;
    type Response = u64;
}

impl ServiceAbi for CounterAbi {
    type Query = Request;
    type QueryResponse = Response;
}
```

### 4.2 Complex ABI Example (Fungible)

**File**: `examples/fungible/src/lib.rs`

```rust
use async_graphql::scalar;
pub use linera_sdk::abis::fungible::*;
use linera_sdk::linera_base_types::{Account, AccountOwner, Amount};
use serde::{Deserialize, Serialize};

#[derive(Debug, Deserialize, Serialize)]
pub enum Message {
    Credit {
        target: AccountOwner,
        amount: Amount,
        source: AccountOwner,
    },
    Withdraw {
        owner: AccountOwner,
        amount: Amount,
        target_account: Account,
    },
}

#[derive(Clone, Debug, Deserialize, Serialize)]
pub struct OwnerSpender {
    pub owner: AccountOwner,
    pub spender: AccountOwner,
}

scalar!(OwnerSpender);
```

### 4.3 Built-in ABIs

Linera SDK provides pre-built ABIs:

```rust
// Re-export fungible token ABI
pub use linera_sdk::abis::fungible::*;
```

This includes:

- `FungibleTokenAbi`
- `FungibleOperation`
- `FungibleResponse`
- `Parameters`
- `InitialState`

---

## 5. State Management with Views

### 5.1 Counter State

**File**: `examples/counter/src/state.rs`

```rust
use linera_sdk::views::{linera_views, RegisterView, RootView, ViewStorageContext};

/// The application state.
#[derive(RootView, async_graphql::SimpleObject)]
#[view(context = ViewStorageContext)]
pub struct CounterState {
    pub value: RegisterView<u64>,
}
```

### 5.2 Fungible Token State

**File**: `examples/fungible/src/state.rs`

```rust
use fungible::{InitialState, OwnerSpender};
use linera_sdk::{
    linera_base_types::{AccountOwner, Amount},
    views::{linera_views, MapView, RootView, ViewStorageContext},
};

/// The application state.
#[derive(RootView)]
#[view(context = ViewStorageContext)]
pub struct FungibleTokenState {
    pub accounts: MapView<AccountOwner, Amount>,
    pub allowances: MapView<OwnerSpender, Amount>,
}
```

### 5.3 View Types

| Type | Description | Use Case |
|------|-------------|----------|
| `RegisterView<T>` | Single value | Counter value, config |
| `MapView<K, V>` | Key-value map | Account balances |
| `LogView<T>` | Append-only log | Event history |
| `CollectionView<K, V>` | Ordered collection | Order books |

### 5.4 State Operations

```rust
// Reading
let value = self.state.value.get();
let balance = self.state.accounts.get(&account).await;

// Writing
self.state.value.set(new_value);
self.state.accounts.insert(&key, value).await;

// Deleting
self.state.accounts.remove(&key).await;
```

---

## 6. Cargo.toml Structure

### 6.1 Example: Counter

**File**: `examples/counter/Cargo.toml`

```toml
[package]
name = "counter"
version = "0.1.0"
authors = ["Linera <contact@linera.io>"]
edition = "2021"

[dependencies]
async-graphql.workspace = true
futures.workspace = true
linera-sdk.workspace = true
serde.workspace = true
serde_json.workspace = true

[target.'cfg(not(target_arch = "wasm32"))'.dev-dependencies]
linera-sdk = { workspace = true, features = ["test", "wasmer"] }
tokio = { workspace = true, features = ["rt", "sync"] }

[dev-dependencies]
assert_matches.workspace = true
linera-sdk = { workspace = true, features = ["test"] }

[[bin]]
name = "counter_contract"
path = "src/contract.rs"

[[bin]]
name = "counter_service"
path = "src/service.rs"
```

### 6.2 Key Dependencies

| Dependency | Version | Purpose |
|------------|---------|---------|
| `linera-sdk` | workspace | Core SDK |
| `async-graphql` | =7.0.17 | GraphQL queries |
| `serde` | 1.0.197 | Serialization |
| `bcs` | 0.1.6 | Binary serialization |

### 6.3 Binary Targets

```toml
[[bin]]
name = "counter_contract"
path = "src/contract.rs"

[[bin]]
name = "counter_service"
path = "src/service.rs"
```

Two separate binaries:

- `{name}_contract` - State-changing operations
- `{name}_service` - Read-only queries

---

## 7. Compilation to Wasm

### 7.1 Build Command

```bash
# Build WebAssembly binaries
cargo build --release --target wasm32-unknown-unknown

# Output location
# examples/target/wasm32-unknown-unknown/release/{name}_{contract,service}.wasm
```

### 7.2 Wasm Target

```bash
# Install wasm32 target
rustup target add wasm32-unknown-unknown
```

### 7.3 Build Script Integration

**File**: `linera-sdk/build.rs`

```rust
use cfg_aliases::cfg_aliases;

fn main() {
    cfg_aliases! {
        wasm32: { target_arch = "wasm32" },
        with_testing: { any(feature = "test", not(target_arch = "wasm32")) },
    }
}
```

### 7.4 WIT Interface

The SDK uses WIT (WebAssembly Interface Types) for host-guest communication:

- `linera-sdk/src/contract/wit/` - Contract WIT definitions
- `linera-sdk/src/service/wit/` - Service WIT definitions
- Generated via `wit-bindgen`

---

## 8. Operations, Messages, Queries

### 8.1 Operations (User Actions)

```rust
#[derive(Debug, Deserialize, Serialize)]
pub enum CounterOperation {
    Increment { value: u64 },
}

// In fungible token
#[derive(Debug, Deserialize, Serialize, GraphQLMutationRoot)]
pub enum FungibleOperation {
    Balance { owner: AccountOwner },
    TickerSymbol,
    Approve { owner, spender, allowance },
    Transfer { owner, amount, target_account },
    TransferFrom { owner, spender, amount, target_account },
    Claim { source_account, amount, target_account },
}
```

**GraphQL Integration**:

```rust
#[derive(Debug, Deserialize, Serialize, GraphQLMutationRoot)]
pub enum Operation {
    ExecuteOrder { order: Order },
    CloseChain,
}
```

### 8.2 Messages (Cross-Chain)

```rust
#[derive(Debug, Deserialize, Serialize)]
pub enum Message {
    Credit {
        target: AccountOwner,
        amount: Amount,
        source: AccountOwner,
    },
    Withdraw {
        owner: AccountOwner,
        amount: Amount,
        target_account: Account,
    },
}
```

### 8.3 Queries (Read-Only)

Queries use GraphQL `Request`/`Response`:

```rust
impl ServiceAbi for CounterAbi {
    type Query = Request;
    type QueryResponse = Response;
}
```

GraphQL Schema:

```graphql
query {
  value
}

mutation {
  increment(value: 42)
}
```

---

## 9. Testing Patterns

### 9.1 Unit Tests

```rust
#[cfg(test)]
mod tests {
    use linera_sdk::{util::BlockingWait, views::View, Contract, ContractRuntime};

    #[test]
    fn operation() {
        let initial_value = 72_u64;
        let mut counter = create_and_instantiate_counter(initial_value);

        let increment = 42_308_u64;
        let operation = CounterOperation::Increment { value: increment };

        let response = counter
            .execute_operation(operation)
            .now_or_never()
            .expect("Execution should not await");

        assert_eq!(response, initial_value + increment);
    }
}
```

### 9.2 Test Dependencies

```toml
[target.'cfg(not(target_arch = "wasm32"))'.dev-dependencies]
linera-sdk = { workspace = true, features = ["test", "wasmer"] }
tokio = { workspace = true, features = ["rt", "sync"] }
```

### 9.3 Test Utilities

- `BlockingWait` - Run async tests in sync context
- `MockContractRuntime` - Mock runtime for testing
- `MockServiceRuntime` - Mock service runtime
- `TestValidator` - Integration testing

---

## 10. DeFi Example: Matching Engine

### 10.1 Complex Operations

**File**: `examples/matching-engine/src/lib.rs`

```rust
#[derive(Debug, Deserialize, Serialize, GraphQLMutationRoot)]
pub enum Operation {
    ExecuteOrder { order: Order },
    CloseChain,
}

#[derive(Clone, Debug, Serialize, Deserialize)]
pub enum Order {
    Insert {
        owner: AccountOwner,
        amount: Amount,
        nature: OrderNature,
        price: Price,
    },
    Cancel {
        owner: AccountOwner,
        order_id: OrderId,
    },
    Modify {
        owner: AccountOwner,
        order_id: OrderId,
        cancel_amount: Amount,
    },
}

#[derive(Clone, Copy, Debug, PartialEq, PartialOrd, Deserialize, Serialize)]
pub struct Price {
    pub price: u64,
}
```

### 10.2 Custom Serialization

```rust
impl CustomSerialize for PriceAsk {
    fn to_custom_bytes(&self) -> Result<Vec<u8>, ViewError> {
        let mut short_key = bcs::to_bytes(&self.price)?;
        short_key.reverse();
        Ok(short_key)
    }
}
```

### 10.3 Application Parameters

```rust
#[derive(Clone, Copy, Debug, Deserialize, Serialize)]
pub struct Parameters {
    pub tokens: [ApplicationId<FungibleTokenAbi>; 2],
}

scalar!(Parameters);
```

---

## 11. Key Differences vs v0.12.0

| Aspect | v0.12.0 | v0.16.0 |
|--------|---------|---------|
| **Traits** | `Application` trait | Separate `Contract` and `Service` traits |
| **Methods** | Sync methods | `async fn` in traits |
| **Exports** | Manual exports | `contract!()` and `service!()` macros |
| **Imports** | `linera_sdk::contract::*` | `linera_sdk::*` |
| **ABI** | Custom types | `ContractAbi` and `ServiceAbi` traits |
| **State** | Custom storage | Views system (`RootView`) |
| **GraphQL** | Optional integration | Built-in via `async_graphql` |
| **Wasm** | Custom bindings | WIT-based via `wit-bindgen` |
| **Runtime** | Direct access | `ContractRuntime`/`ServiceRuntime` |
| **Testing** | Integration tests | Mock runtimes + `BlockingWait` |

---

## 12. Multisig Implementation Guide

### 12.1 Recommended Structure

```
multisig/
├── Cargo.toml
├── src/
│   ├── lib.rs           # ABI definition
│   ├── contract.rs      # State-changing logic
│   ├── service.rs       # Query handlers
│   ├── state.rs         # State with Views
│   └── operations.rs    # Operation types
```

### 12.2 Minimal Multisig ABI

```rust
#[derive(Debug, Deserialize, Serialize)]
pub enum MultisigOperation {
    CreateProposal {
        description: String,
        calls: Vec<ContractCall>,
    },
    Approve {
        proposal_id: u64,
    },
    Execute {
        proposal_id: u64,
    },
    UpdateThreshold {
        required: u64,
    },
    AddOwner {
        owner: AccountOwner,
    },
    RemoveOwner {
        owner: AccountOwner,
    },
}

#[derive(Debug, Deserialize, Serialize)]
pub enum MultisigMessage {
    Approval {
        proposal_id: u64,
        approver: AccountOwner,
    },
}
```

### 12.3 State Structure

```rust
#[derive(RootView)]
#[view(context = ViewStorageContext)]
pub struct MultisigState {
    pub owners: MapView<AccountOwner, ()>,
    pub threshold: RegisterView<u64>,
    pub proposals: MapView<u64, Proposal>,
    pub next_proposal_id: RegisterView<u64>,
    pub approvals: MapView<(u64, AccountOwner), ()>,
}

#[derive(Clone, Debug, Deserialize, Serialize, SimpleObject)]
pub struct Proposal {
    pub id: u64,
    pub description: String,
    pub calls: Vec<ContractCall>,
    pub proposer: AccountOwner,
    pub executed: bool,
}
```

---

## 13. Best Practices

### 13.1 Error Handling

```rust
async fn execute_operation(&mut self, operation: Operation) -> Response {
    match operation {
        Operation::Transfer { from, to, amount } => {
            self.runtime
                .check_account_permission(from)
                .expect("Permission denied");

            let balance = self.state.balance(&from).await
                .unwrap_or_default();

            if balance < amount {
                panic!("Insufficient balance");
            }

            self.state.debit(from, amount).await;
            self.state.credit(to, amount).await;

            Response::Ok
        }
    }
}
```

### 13.2 Cross-Chain Messages

```rust
// Sending
self.runtime
    .prepare_message(Message::Credit { target, amount, source })
    .with_authentication()
    .with_tracking()
    .send_to(target_chain_id);

// Handling bouncing
async fn execute_message(&mut self, message: Message) {
    match message {
        Message::Credit { target, amount, source } => {
            let is_bouncing = self
                .runtime
                .message_is_bouncing()
                .expect("Message status must be available");

            let receiver = if is_bouncing { source } else { target };
            self.state.credit(receiver, amount).await;
        }
    }
}
```

### 13.3 GraphQL Mutations

```rust
#[Object]
impl MutationRoot {
    async fn create_proposal(
        &self,
        description: String,
        calls: Vec<ContractCall>,
    ) -> u64 {
        let operation = MultisigOperation::CreateProposal {
            description,
            calls,
        };
        self.runtime.schedule_operation(&operation);
        0 // Placeholder return
    }
}
```

---

## 14. Build and Deployment

### 14.1 Build Commands

```bash
# Add wasm32 target
rustup target add wasm32-unknown-unknown

# Build release binaries
cargo build --release --target wasm32-unknown-unknown

# Output
# target/wasm32-unknown-unknown/release/multisig_contract.wasm
# target/wasm32-unknown-unknown/release/multisig_service.wasm
```

### 14.2 Publish Command

```bash
# Publish and create application
APPLICATION_ID=$(linera publish-and-create \
  target/wasm32-unknown-unknown/release/multisig_{contract,service}.wasm \
  --json-argument '{
    "owners": ["0x123...", "0x456..."],
    "threshold": 2
  }')
```

---

## 15. References

### 15.1 Official Examples

| Example | Description | Location |
|---------|-------------|----------|
| Counter | Basic counter with GraphQL | `examples/counter/` |
| Fungible | ERC20-like token | `examples/fungible/` |
| Matching Engine | DeFi order book | `examples/matching-engine/` |
| Social | Social network | `examples/social/` |
| AMM | Automated Market Maker | `examples/amm/` |

### 15.2 SDK Modules

- `linera-sdk` - Main SDK crate
- `linera-sdk-derive` - Derive macros
- `linera-views` - State management
- `linera-base` - Base types and ABI

### 15.3 Documentation

- Linera SDK Docs: <https://docs.rs/linera-sdk/latest/linera_sdk/>
- Linera Views: <https://docs.rs/linera-views/latest/linera_views/>
- Repository: <https://github.com/linera-io/linera-protocol>

---

## 16. Conclusion

The Linera SDK v0.16.0 represents a significant improvement over v0.12.0:

**Improvements**:

- Cleaner trait separation (Contract vs Service)
- Simplified imports from `linera_sdk` root
- Better async support with `async fn` in traits
- Integrated GraphQL via `async_graphql`
- Views system for efficient state management
- WIT-based WebAssembly integration

**For Multisig Development**:

1. Use `Contract` trait for state changes
2. Use `Service` trait for queries
3. Use `MapView` for owners and approvals
4. Use `RegisterView` for threshold and counters
5. Implement cross-chain messages for multi-chain operation
6. GraphQL mutations for frontend integration

**Next Steps**:

1. Implement multisig ABI following Fungible example
2. Define state structure with Views
3. Implement contract logic with proper permission checks
4. Create GraphQL schema for service queries
5. Add comprehensive tests with mock runtimes

---

**Report Generated**: February 3, 2026
**Analyzed By**: Claude Code (Zai GLM-4.7)
**Repository**: <https://github.com/linera-io/linera-protocol>
