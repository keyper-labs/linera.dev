# Linera SDK: Quick Reference

**Date**: February 3, 2026
**Companion to**: [Capabilities Analysis](./linera-sdk-capabilities-and-limitations-comprehensive-analysis.md)

---

## Contract Runtime API

### Chain Information
```rust
// Application info
runtime.application_id() -> ApplicationId
runtime.application_parameters() -> Parameters
runtime.application_creator_chain_id() -> ChainId

// Chain info
runtime.chain_id() -> ChainId
runtime.chain_balance() -> Amount
runtime.chain_ownership() -> ChainOwnership

// Block info
runtime.block_height() -> BlockHeight
runtime.system_time() -> Timestamp
```

### Authentication
```rust
// Authenticated owner
runtime.authenticated_owner() -> Option<AccountOwner>

// Check permissions
runtime.check_account_permission(owner) -> Result<(), Error>

// Message authentication
runtime.message_is_bouncing() -> Option<bool>
runtime.message_origin_chain_id() -> Option<ChainId>

// Cross-application caller
runtime.authenticated_caller_id() -> Option<ApplicationId>
```

### Messaging
```rust
// Prepare message
runtime.prepare_message(message)
    .with_authentication()
    .with_tracking()
    .with_grant(resources)
    .send_to(chain_id);

// Cross-application call (same chain)
runtime.call_application(authenticated, app_id, operation) -> Response
```

### Chain Management
```rust
// Open new chain
runtime.open_chain(ownership, permissions, balance) -> ChainId

// Close current chain
runtime.close_chain() -> Result<(), Error>

// Change permissions
runtime.change_application_permissions(permissions) -> Result<(), Error>
```

### Application Management
```rust
// Create application
runtime.create_application(module_id, parameters, argument, deps) -> ApplicationId

// Publish module
runtime.publish_module(contract_wasm, service_wasm, vm_runtime) -> ModuleId
```

### Event Streams
```rust
// Emit event
runtime.emit(stream_name, event_value) -> u32

// Read event
runtime.read_event(chain_id, stream_name, index) -> EventValue

// Subscribe to events
runtime.subscribe_to_events(chain_id, app_id, stream_name)

// Unsubscribe from events
runtime.unsubscribe_from_events(chain_id, app_id, stream_name)
```

### Oracle & Time
```rust
// HTTP request (oracle)
runtime.http_request(request) -> Response

// Time assertion
runtime.assert_before(timestamp)
```

### Storage
```rust
// Data blobs
runtime.create_data_blob(bytes) -> DataBlobHash
runtime.read_data_blob(hash) -> Vec<u8>
runtime.assert_data_blob_exists(hash)
```

### Account Balances
```rust
// Owner balance
runtime.owner_balance(owner) -> Amount

// Multiple balances (service only)
service_runtime.owner_balances() -> Vec<(AccountOwner, Amount)>
service_runtime.balance_owners() -> Vec<AccountOwner>
```

---

## Service Runtime API

### Chain Information
```rust
// Same as contract runtime
service_runtime.application_id() -> ApplicationId
service_runtime.chain_id() -> ChainId
service_runtime.next_block_height() -> BlockHeight
service_runtime.system_time() -> Timestamp
service_runtime.chain_balance() -> Amount
```

### Query & Schedule
```rust
// Query another application
service_runtime.query_application(app_id, query) -> QueryResponse

// Schedule operation
service_runtime.schedule_operation(operation)
```

### Oracle & Storage
```rust
// HTTP request (same as contract)
service_runtime.http_request(request) -> Response

// Data blobs (same as contract)
service_runtime.read_data_blob(hash) -> Vec<u8>
service_runtime.assert_data_blob_exists(hash)
```

---

## View System

### RegisterView (Single Value)
```rust
struct MyState {
    value: RegisterView<u64>,
}

// Get
let value = state.value.get();

// Set
state.value.set(42);

// Modify
state.value.modify(|v| *v += 1);
```

### MapView (Key-Value)
```rust
struct MyState {
    balances: MapView<AccountOwner, Amount>,
}

// Get
let balance = state.balances.get(&owner).await;

// Insert
state.balances.insert(&owner, &amount).await;

// Remove
state.balances.remove(&owner).await;

// Iterate
state.balances.for_each_key_value(|key, value| {
    // Process key-value
    Ok(())
}).await;
```

### SetView (Unique Keys)
```rust
struct MyState {
    owners: SetView<AccountOwner>,
}

// Insert
state.owners.insert(&owner).await;

// Remove
state.owners.remove(&owner).await;

// Contains
let exists = state.owners.contains(&owner).await;

// Iterate
state.owners.for_each_key(|key| {
    // Process key
    Ok(())
}).await;
```

### LogView (Append-Only Log)
```rust
struct MyState {
    events: LogView<Event>,
}

// Push
state.events.push(&event);

// Get
state.events.get(index);

// Length
state.events.len();

// Iterate
state.events.for_each(|event| {
    // Process event
    Ok(())
}).await;
```

### QueueView (FIFO Queue)
`````rust
struct MyState {
    tasks: QueueView<Task>,
}

// Push back
state.tasks.push_back(&task);

// Pop front
state.tasks.pop_front();

// Front
state.tasks.front();
````

### CollectionView (Nested Views)
```rust
struct MyState {
    users: CollectionView<UserId, UserState>,
}

struct UserState<C> {
    balance: RegisterView<Amount>,
    approvals: SetView<AccountOwner>,
}

impl<C> View for UserState<C> where C: Context {
    // ...
}

// Access nested
let mut user = state.users.get_mut(&user_id).await.unwrap();
user.balance.set(amount);
```

### ReentrantCollectionView (Concurrent Access)
```rust
struct MyState {
    accounts: ReentrantCollectionView<AccountId, AccountState>,
}

// Can access different keys concurrently
let mut account1 = state.accounts.get_mut(&id1).await.unwrap();
let mut account2 = state.accounts.get_mut(&id2).await.unwrap();

// Both can be modified independently
account1.balance.set(100);
account2.balance.set(200);
```

---

## Contract Trait

```rust
#[allow(async_fn_in_trait)]
pub trait Contract: WithContractAbi + ContractAbi + Sized {
    // Associated types
    type Message: Serialize + DeserializeOwned + Debug;
    type Parameters: Serialize + DeserializeOwned + Clone + Debug;
    type InstantiationArgument: Serialize + DeserializeOwned + Debug;
    type EventValue: Serialize + DeserializeOwned + Debug;
    type Operation: Serialize + DeserializeOwned + Debug;
    type Response: Serialize + DeserializeOwned + Debug;

    // Lifecycle
    async fn load(runtime: ContractRuntime<Self>) -> Self;
    async fn instantiate(&mut self, argument: Self::InstantiationArgument);
    async fn store(self);

    // Execution
    async fn execute_operation(&mut self, operation: Self::Operation) -> Self::Response;
    async fn execute_message(&mut self, message: Self::Message);
    async fn process_streams(&mut self, updates: Vec<StreamUpdate>);
}
```

---

## Service Trait

```rust
#[allow(async_fn_in_trait)]
pub trait Service: WithServiceAbi + ServiceAbi + Sized {
    // Associated types
    type Parameters: Serialize + DeserializeOwned + Send + Sync + Clone + Debug;
    type Query: Serialize + DeserializeOwned;
    type QueryResponse: Serialize + DeserializeOwned;

    // Lifecycle
    async fn new(runtime: ServiceRuntime<Self>) -> Self;

    // Query
    async fn handle_query(&self, query: Self::Query) -> Self::QueryResponse;
}
```

---

## Macros

### Contract Macro
```rust
linera_sdk::contract!(MyContract);
```

### Service Macro
```rust
linera_sdk::service!(MyService);
```

---

## Chain Ownership

### Create Single Owner
```rust
// Single super owner (fast blocks)
let ownership = ChainOwnership::single_super(owner);

// Single regular owner
let ownership = ChainOwnership::single(owner);
```

### Create Multi-Owner
```rust
// Multiple owners with weights
let ownership = ChainOwnership::multiple(
    vec![
        (owner1, 100),
        (owner2, 100),
        (owner3, 50),
    ],
    2,  // multi_leader_rounds
    TimeoutConfig::default(),
);
```

### Timeout Config
```rust
pub struct TimeoutConfig {
    pub fast_round_duration: Option<TimeDelta>,
    pub base_timeout: TimeDelta,
    pub timeout_increment: TimeDelta,
    pub fallback_duration: TimeDelta,
}
```

---

## Messaging Patterns

### Simple Message
```rust
runtime.prepare_message(MyMessage::Credit { amount, recipient })
    .send_to(target_chain);
```

### Authenticated Message
```rust
runtime.prepare_message(MyMessage::Transfer { amount })
    .with_authentication()
    .send_to(target_chain);
```

### Tracked Message (with bounce)
```rust
runtime.prepare_message(MyMessage::Payment { amount })
    .with_authentication()
    .with_tracking()
    .send_to(target_chain);
```

### Message with Resource Grant
```rust
runtime.prepare_message(MyMessage::Call { data })
    .with_authentication()
    .with_grant(Resources {
        fuel: 100_000,
        ..Default::default()
    })
    .send_to(target_chain);
```

---

## Common Patterns

### Pattern 1: Balance Check
```rust
let balance = runtime.owner_balance(owner);
assert!(balance >= amount, "Insufficient balance");
```

### Pattern 2: Transfer to Same Chain
```rust
if target_chain == runtime.chain_id() {
    // Local transfer
    self.state.credit(recipient, amount).await;
} else {
    // Cross-chain message
    runtime.prepare_message(Message::Credit { amount, recipient })
        .with_authentication()
        .with_tracking()
        .send_to(target_chain);
}
```

### Pattern 3: Cross-Application Call
```rust
let response = runtime.call_application(
    true,  // authenticated
    fungible_app_id,
    &FungibleOperation::Transfer {
        owner,
        amount,
        target_account,
    }
);
```

### Pattern 4: Permission Check
```rust
let authenticated = runtime.authenticated_owner()
    .expect("Operation must be authenticated");

runtime.check_account_permission(authenticated)
    .expect("Not authorized");
```

### Pattern 5: Event Emission
```rust
// Emit event
runtime.emit("transfers", &TransferEvent {
    from,
    to,
    amount,
    timestamp: runtime.system_time(),
});
```

### Pattern 6: Proposal Pattern
```rust
// Create proposal
let proposal_id = self.next_proposal_id();
self.state.proposals.insert(&proposal_id, &proposal).await;

// Approve
let mut approvals = self.state.approvals.get_mut(&proposal_id).await.unwrap();
approvals.insert(&approver).await;

// Check threshold
let approval_count = self.count_approvals(&proposal_id).await;
if approval_count >= threshold {
    self.execute_proposal(proposal_id).await;
}
```

---

## CLI Commands

### Chain Management
```bash
# Open single-owner chain
linera open-chain --from $PARENT --initial-balance 1000

# Open multi-owner chain
linera open-multi-owner-chain --from $PARENT --owners OWNER1,OWNER2,OWNER3

# Change ownership
linera change-ownership --chain-id $CHAIN --owners NEW_OWNER1,NEW_OWNER2
```

### Application Management
```bash
# Publish application
linera publish --contract contract.wasm --service service.wasm

# Create application
linera create-application --module-id $MODULE --params "$PARAMS"

# Query application
linera query --application-id $APP_ID --query "$QUERY"
```

### Resource Control
```bash
# View resource policy
linera resource-control-policy

# Update policy (admin only)
linera resource-control-policy --wasm-fuel-unit 1000
```

---

## Type Aliases

```rust
// Common types
use linera_sdk::linera_base_types::{
    Account, AccountOwner, Amount, ChainId, ApplicationId,
    Timestamp, BlockHeight, Resources,
};

// Views
use linera_sdk::views::{
    RegisterView, MapView, SetView, LogView, QueueView,
    CollectionView, ReentrantCollectionView,
    RootView, View, ViewStorageContext,
};

// Runtime
use linera_sdk::{Contract, ContractRuntime, Service, ServiceRuntime};

// Macros
use linera_sdk::{contract, service};

// Serialization
use linera_sdk::{bcs, serde_json, Serialize, Deserialize};
```

---

## Testing

### Mock Contract Runtime
```rust
use linera_sdk::test::MockContractRuntime;

#[tokio::test]
async fn test_operation() {
    let runtime = MockContractRuntime::new();
    let mut contract = MyContract::load(runtime).await;

    // Test
    let response = contract.execute_operation(operation).await;

    // Assert
    assert!(matches!(response, MyResponse::Ok));
}
```

### Mock Service Runtime
```rust
use linera_sdk::test::MockServiceRuntime;

#[tokio::test]
async fn test_query() {
    let runtime = MockServiceRuntime::new();
    let service = MyService::new(runtime).await;

    // Test
    let response = service.handle_query(query).await;

    // Assert
    assert_eq!(response, expected_response);
}
```

---

## Common Errors

### Error: Not Permitted
```rust
// Cause: Permission check failed
// Solution: Check authenticated owner
let owner = runtime.authenticated_owner()
    .expect("Must be authenticated");
```

### Error: Proposal Not Found
```rust
// Cause: Proposal doesn't exist
// Solution: Check existence before access
let proposal = self.state.proposals.get(&proposal_id).await
    .ok_or("Proposal not found")?;
```

### Error: Threshold Not Reached
```rust
// Cause: Insufficient approvals
// Solution: Check approval count
let approvals = self.count_approvals(&proposal_id).await;
assert!(approvals >= threshold, "Threshold not reached");
```

### Error: Chain Ownership Mismatch
```rust
// Cause: Wrong chain ownership
// Solution: Verify chain ownership
let ownership = runtime.chain_ownership();
assert!(ownership.verify_owner(&owner), "Not an owner");
```

---

## Performance Tips

1. **Use Views for Large State**: Lazy loading reduces memory
2. **Batch Storage Operations**: Minimize individual reads/writes
3. **Avoid Unbounded Loops**: Gas metering limits computation
4. **Use ReentrantCollectionView**: For concurrent access
5. **Minimize Cross-Chain Messages**: Use same-chain calls when possible
6. **Use Event Streams**: For off-chain indexing
7. **Cache Runtime Values**: Runtime calls have overhead

---

## Security Checklist

- ✅ Always check `authenticated_owner()` for state changes
- ✅ Use `check_account_permission()` for authorization
- ✅ Validate all external inputs
- ✅ Use `with_tracking()` for important messages
- ✅ Handle message bouncing properly
- ✅ Check proposal expiry
- ✅ Verify threshold before execution
- ✅ Use time assertions carefully (not in fast blocks)
- ✅ Be cautious with HTTP oracles (deterministic only)

---

## Quick Reference Card

```
┌─────────────────────────────────────────────────────────────┐
│                     Contract Runtime                        │
├─────────────────────────────────────────────────────────────┤
│ State:     runtime.key_value_store()                        │
│ Chain:     runtime.chain_id(), balance, ownership           │
│ Auth:      runtime.authenticated_owner()                   │
│ Message:   runtime.prepare_message(msg).send_to(chain)     │
│ Call:      runtime.call_application(auth, app, op)         │
│ Oracle:    runtime.http_request(req)                       │
│ Events:    runtime.emit(name, value)                       │
│ Chain:     runtime.open_chain(ownership, perm, bal)        │
│ App:       runtime.create_application(...)                 │
└─────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────┐
│                      View System                            │
├─────────────────────────────────────────────────────────────┤
│ Register:  value.get(), value.set(x)                        │
│ Map:       map.get(&k), map.insert(&k, &v)                  │
│ Set:       set.insert(&k), set.remove(&k)                   │
│ Log:       log.push(&v), log.get(i)                         │
│ Queue:     queue.push_back(&v), queue.pop_front()           │
│ Collection: col.get(&k), col.get_mut(&k)                    │
└─────────────────────────────────────────────────────────────┘
```

---

**Status**: ✅ Complete
**Purpose**: Quick API reference for developers
