# Linera SDK: Comprehensive Capabilities and Limitations Analysis

**Date**: February 3, 2026
**Repository**: [linera-io/linera-protocol](https://github.com/linera-io/linera-protocol/tree/main/linera-sdk)
**SDK Version**: Current main branch
**Author**: Claude Code (Research Agent)

---

## Executive Summary

The Linera SDK (`linera-sdk`) is a **Rust-based WebAssembly framework** for building blockchain applications on Linera's microchain architecture. It provides a **dual-binary model** (Contract + Service) with sophisticated cross-chain messaging, multi-owner chain support, and a powerful views system for state management.

**Key Finding**: The SDK is **extremely capable** for building complex DeFi applications including multisig wallets, but has **specific architectural constraints** that must be understood.

---

## Table of Contents

1. [Architecture Overview](#architecture-overview)
2. [What You CAN Do with the SDK](#what-you-can-do)
3. [What You CANNOT Do with the SDK](#what-you-cannot-do)
4. [Multisig-Specific Capabilities](#multisig-specific-capabilities)
5. [Storage and State Management](#storage-and-state-management)
6. [Cross-Chain Communication](#cross-chain-communication)
7. [Security and Permissions](#security-and-permissions)
8. [Performance Considerations](#performance-considerations)
9. [Critical Limitations](#critical-limitations)
10. [Recommendations for Multisig Platform](#recommendations)

---

## Architecture Overview

### Dual Binary Model

Every Linera application consists of **two separate Wasm binaries**:

```

                    Linera Application                       

         Contract (Wasm)                 Service (Wasm)      

 • Handles state changes           • Read-only queries       
 • Executes operations             • GraphQL interface       
 • Processes messages              • Cannot modify storage   
 • Gas-metered                     • Not gas-metered         
 • Write access to state           • Read access to state    

                        ↓
                
                  Shared Storage  
                  (linera-views)  
                
```

### Contract Trait

```rust
#[allow(async_fn_in_trait)]
pub trait Contract: WithContractAbi + ContractAbi + Sized {
    type Message: Serialize + DeserializeOwned + Debug;
    type Parameters: Serialize + DeserializeOwned + Clone + Debug;
    type InstantiationArgument: Serialize + DeserializeOwned + Debug;
    type EventValue: Serialize + DeserializeOwned + Debug;

    async fn load(runtime: ContractRuntime<Self>) -> Self;
    async fn instantiate(&mut self, argument: Self::InstantiationArgument);
    async fn execute_operation(&mut self, operation: Self::Operation) -> Self::Response;
    async fn execute_message(&mut self, message: Self::Message);
    async fn process_streams(&mut self, _updates: Vec<StreamUpdate>) {}
    async fn store(self);
}
```

### Service Trait

```rust
#[allow(async_fn_in_trait)]
pub trait Service: WithServiceAbi + ServiceAbi + Sized {
    type Parameters: Serialize + DeserializeOwned + Send + Sync + Clone + Debug + 'static;

    async fn new(runtime: ServiceRuntime<Self>) -> Self;
    async fn handle_query(&self, query: Self::Query) -> Self::QueryResponse;
}
```

---

## What You CAN Do with the SDK

### 1. **State Management** 

#### View System (linera-views)

The SDK provides a sophisticated view system for efficient state management:

| View Type | Description | Use Case |
|-----------|-------------|----------|
| **RegisterView** | Single value storage | Configuration, counters, flags |
| **MapView** | Key-value mapping | Account balances, user data |
| **SetView** | Unique key collection | Whitelists, unique identifiers |
| **LogView** | Append-only log | Transaction history, event logs |
| **QueueView** | FIFO queue | Pending operations, task queues |
| **CollectionView** | Nested views | Complex hierarchical state |
| **ReentrantCollectionView** | Concurrent access | Parallel access to different keys |

**Example from fungible token**:
```rust
pub struct FungibleTokenState {
    /// Balances for each owner
    balances: MapView<AccountOwner, Amount>,
    /// Approvals for spenders
    spenders: MapView<AccountOwner, MapView<AccountOwner, Amount>>,
}

impl RootView for FungibleTokenState {
    type Context = ViewStorageContext;
}
```

**Capabilities**:
- Lazy loading of large state
- Efficient partial updates
- Automatic batching
- Reentrant access patterns

### 2. **Multi-Owner Chains** 

Linera supports **native multi-owner chains** through `ChainOwnership`:

```rust
pub struct ChainOwnership {
    /// Super owners can propose fast blocks
    pub super_owners: BTreeSet<AccountOwner>,
    /// Regular owners with weights
    pub owners: BTreeMap<AccountOwner, u64>,
    /// Number of multi-leader rounds
    pub multi_leader_rounds: u32,
    /// Whether multi-leader rounds are unrestricted
    pub open_multi_leader_rounds: bool,
    /// Timeout configuration
    pub timeout_config: TimeoutConfig,
}
```

**Creation Methods**:
```rust
// Single super owner (fast execution)
ChainOwnership::single_super(owner)

// Single regular owner
ChainOwnership::single(owner)

// Multiple owners with weights
ChainOwnership::multiple(
    vec![(owner1, 100), (owner2, 100), (owner3, 50)],
    multi_leader_rounds,
    timeout_config,
)
```

**CLI Commands**:
```bash
# Open a multi-owner chain
linera open-multi-owner-chain --from <PARENT> --owners OWNER1,OWNER2,OWNER3

# Change ownership
linera change-ownership --chain-id <CHAIN> --owners NEW_OWNER1,NEW_OWNER2
```

**This is CRITICAL for multisig**: You can create a chain where N owners must collectively sign transactions.

### 3. **Cross-Application Calls** 

Contracts can call other contracts synchronously:

```rust
pub fn call_application<A: ContractAbi + Send>(
    &mut self,
    authenticated: bool,
    application: ApplicationId<A>,
    call: &A::Operation,
) -> A::Response
```

**Example from crowd-funding**:
```rust
// Call fungible token to transfer tokens
let call = FungibleOperation::Transfer {
    owner,
    amount,
    target_account,
};
let response = self.runtime
    .call_application(true, fungible_id, &call);
```

**Use Cases**:
- Compose multiple applications
- Reuse functionality (e.g., token transfers)
- Build complex DeFi protocols

### 4. **Cross-Chain Messaging** 

Asynchronous messaging between chains:

```rust
pub fn prepare_message(&mut self, message: Message) -> MessageBuilder<Message>

// Message builder pattern
self.runtime
    .prepare_message(message)
    .with_authentication()      // Forward authenticated owner
    .with_tracking()            // Get notification if rejected
    .with_grant(resources)      // Include resources for receiver
    .send_to(destination_chain);
```

**Capabilities**:
- **Single-sender to single-receiver** messaging
- **Broadcast channels** (one sender, multiple receivers)
- **Tracking**: Get notified if message is rejected
- **Authentication**: Forward owner identity
- **Resource grants**: Pay for receiver's execution

**Example from fungible token**:
```rust
// Send tokens to another chain
let message = Message::Credit {
    target: target_account.owner,
    amount,
    source,
};
self.runtime
    .prepare_message(message)
    .with_authentication()
    .with_tracking()
    .send_to(target_account.chain_id);
```

### 5. **Event Streams** 

Publish and subscribe to event streams:

```rust
// Emit events
pub fn emit(&mut self, name: StreamName, value: &Application::EventValue) -> u32

// Subscribe to events
pub fn subscribe_to_events(
    &mut self,
    chain_id: ChainId,
    application_id: ApplicationId,
    name: StreamName,
)

// Read events
pub fn read_event(
    &mut self,
    chain_id: ChainId,
    name: StreamName,
    index: u32,
) -> Application::EventValue

// Process events
async fn process_streams(&mut self, updates: Vec<StreamUpdate>)
```

**Use Cases**:
- Off-chain indexing
- Event-driven architectures
- Cross-chain coordination

### 6. **Dynamic Application Creation** 

Contracts can create new applications:

```rust
pub fn create_application<Abi, Parameters, InstantiationArgument>(
    &mut self,
    module_id: ModuleId,
    parameters: &Parameters,
    argument: &InstantiationArgument,
    required_application_ids: Vec<ApplicationId>,
) -> ApplicationId<Abi>
```

**Use Cases**:
- Factory patterns
- Dynamic deployment
- Application templates

### 7. **Module Publishing** 

Publish Wasm bytecode for contracts and services:

```rust
pub fn publish_module(
    &mut self,
    contract: Bytecode,
    service: Bytecode,
    vm_runtime: VmRuntime,
) -> ModuleId
```

**Capabilities**:
- Deploy new contract/service bytecode
- Upgrade applications
- Share modules across applications

### 8. **Chain Management** 

Contracts can open and close chains:

```rust
// Open a new chain
pub fn open_chain(
    &mut self,
    chain_ownership: ChainOwnership,
    application_permissions: ApplicationPermissions,
    balance: Amount,
) -> ChainId

// Close the current chain
pub fn close_chain(&mut self) -> Result<(), CloseChainError>

// Change application permissions
pub fn change_application_permissions(
    &mut self,
    application_permissions: ApplicationPermissions,
) -> Result<(), ChangeApplicationPermissionsError>
```

**Use Cases**:
- Dynamic chain creation
- Hierarchical chain structures
- Permission management

### 9. **HTTP Oracle Calls** 

Make HTTP requests as an oracle:

```rust
pub fn http_request(&mut self, request: http::Request) -> http::Response
```

**Constraints**:
- Only use with deterministic queries
- All validators must receive same response
- Cannot use in fast blocks (only regular owner blocks)

**Use Cases**:
- Price oracles
- External data feeds
- Cross-chain bridges (with caution)

### 10. **Time Assertions** 

Enforce time-based constraints:

```rust
pub fn assert_before(&mut self, timestamp: Timestamp)
```

**Constraints**:
- Cannot use in fast blocks
- Only regular owner blocks

**Use Cases**:
- Deadlines (e.g., voting, crowdfunding)
- Time-locked operations
- Expiration logic

### 11. **Data Blob Storage** 

Store and retrieve large data blobs:

```rust
// Create a data blob
pub fn create_data_blob(&mut self, bytes: &[u8]) -> DataBlobHash

// Read a data blob
pub fn read_data_blob(&mut self, hash: DataBlobHash) -> Vec<u8>

// Assert blob exists
pub fn assert_data_blob_exists(&mut self, hash: DataBlobHash)
```

**Use Cases**:
- Large data storage
- Metadata storage
- Cross-chain data sharing

### 12. **Permission Checks** 

Verify account permissions:

```rust
pub fn check_account_permission(
    &mut self,
    owner: AccountOwner,
) -> Result<(), AccountPermissionError>
```

**Use Cases**:
- Authorization checks
- Access control
- Multi-sig validation

### 13. **Balance Queries** 

Query chain and account balances:

```rust
// Chain balance
pub fn chain_balance(&mut self) -> Amount

// Specific owner balance
pub fn owner_balance(&mut self, owner: AccountOwner) -> Amount
```

### 14. **Chain Ownership Queries** 

```rust
pub fn chain_ownership(&mut self) -> ChainOwnership
```

### 15. **Service Queries** 

Services can query other applications:

```rust
pub fn query_application<A: ServiceAbi>(
    &self,
    application: ApplicationId<A>,
    query: &A::Query,
) -> A::QueryResponse
```

### 16. **Service Operations Scheduling** 

Services can schedule operations:

```rust
pub fn schedule_operation(&self, operation: &impl Serialize)
```

---

## What You CANNOT Do with the SDK

### 1. **Direct Database Access** 

**Limitation**: You cannot directly access databases, file systems, or external storage.

**Workaround**:
- Use the provided `linera-views` system
- All state must go through the view abstraction
- No SQL, no direct file I/O

### 2. **Network I/O (Except Oracle)** 

**Limitation**: Cannot make arbitrary network calls.

**Workaround**:
- Use `http_request()` for oracle calls
- Only deterministic queries allowed
- Cannot call arbitrary APIs

### 3. **Async/Await in Traditional Sense** 

**Limitation**: While the SDK uses `async fn`, this is for Wasm compatibility, not true async concurrency.

**Reality**:
- Execution is synchronous within a transaction
- No concurrent task spawning
- `async` is a requirement for the Wasm host interface

### 4. **Direct Access to Other Chains** 

**Limitation**: Cannot directly read or modify state on other chains.

**Workaround**:
- Use cross-chain messaging
- Use cross-application calls (same chain only)
- Queries through services are read-only

### 5. **Floating Point Arithmetic** 

**Limitation**: Wasm doesn't guarantee deterministic floating point.

**Workaround**:
- Use `Amount` type (fixed-point)
- Use integer arithmetic
- All financial calculations use fixed-point

### 6. **Random Number Generation** 

**Limitation**: Cannot generate random numbers directly (non-deterministic).

**Workaround**:
- Use commit-reveal schemes
- Use oracle-provided randomness
- Use VRFs (Verifiable Random Functions)

### 7. **Direct Cryptographic Operations** 

**Limitation**: Limited access to cryptographic primitives.

**Available**:
- Hashing through `CryptoHash`
- Ed25519 signatures through account ownership
- Verification of signatures

**Not Available**:
- Custom encryption schemes
- Arbitrary signature algorithms
- Direct keypair generation in contracts

### 8. **Unbounded Loops** 

**Limitation**: Gas metering prevents unbounded computation.

**Impact**:
- Must design algorithms with known bounds
- Large iterations will hit gas limits
- Need pagination for large datasets

### 9. **Direct Memory Access** 

**Limitation**: No direct pointer manipulation or unsafe memory access.

**Reasoning**: Wasm security model

### 10. **Operating System Calls** 

**Limitation**: No syscalls, no process spawning, no threads.

**Reasoning**: Wasm sandbox

### 11. **Dynamic Code Loading** 

**Limitation**: Cannot load arbitrary code at runtime (except through published modules).

**Workaround**:
- Use `publish_module` for bytecode
- Use `create_application` for instantiation
- No `eval()` or dynamic compilation

### 12. **GraphQL Writes** 

**Limitation**: Services (GraphQL) cannot modify state.

**Workaround**:
- Use GraphQL only for queries
- Use operations (through contracts) for writes
- Services can `schedule_operation()` but not execute

### 13. **Fast Block Restrictions** 

**Limitation**: Certain operations cannot be used in fast blocks:
- `http_request()`
- `assert_before()`
- Oracle queries

**Workaround**:
- Use regular owner blocks for these operations
- Design around fast block limitations

### 14. **Cross-Application Call Limitations** 

**Limitation**: Cross-application calls are synchronous and same-chain only.

**Impact**:
- Cannot call contracts on other chains
- Must use messaging for cross-chain
- Synchronous calls can still fail

---

## Multisig-Specific Capabilities

### Native Multi-Owner Support 

The SDK provides **native support for multi-owner chains**, which is the foundation for multisig:

```rust
// Create a 3-of-5 multisig chain
let owners = vec![
    (owner1, 1),
    (owner2, 1),
    (owner3, 1),
    (owner4, 1),
    (owner5, 1),
];
let ownership = ChainOwnership::multiple(
    owners,
    2,  // 2 multi-leader rounds
    TimeoutConfig::default(),
);

// Open the chain
let chain_id = runtime.open_chain(ownership, permissions, balance);
```

### Application-Level Multisig 

You can build **application-level multisig** on top of the SDK:

**State Design**:
```rust
struct MultisigState {
    // Required confirmations
    threshold: RegisterView<u64>,
    // List of owners
    owners: SetView<AccountOwner>,
    // Pending proposals
    proposals: MapView<ProposalId, Proposal>,
    // Confirmations per proposal
    confirmations: MapView<ProposalId, SetView<AccountOwner>>,
}

struct Proposal {
    // Proposed operation
    operation: Vec<u8>,
    // Approvals
    approvals: HashSet<AccountOwner>,
    // Executed status
    executed: bool,
}
```

**Operations**:
1. **Propose**: Create a new proposal
2. **Approve**: Add approval from owner
3. **Execute**: Execute if threshold reached
4. **Revoke**: Remove approval

### Cross-Chain Multisig 

Using messaging, you can build **cross-chain multisig**:

1. **Deploy multisig on one chain**
2. **Other chains send approval messages**
3. **Multisig chain aggregates approvals**
4. **Execute when threshold reached**

---

## Storage and State Management

### View System Deep Dive

The **linera-views** system is one of the most powerful features:

**Key Benefits**:
1. **Lazy Loading**: Only load what you need
2. **Efficient Updates**: Only write changed data
3. **Nested Views**: Complex hierarchical state
4. **Reentrant Access**: Concurrent access to different keys

**Storage Backends**:
- `MemoryStore`: In-memory (testing)
- `RocksDbStore`: Disk-based key-value store
- `DynamoDbDatabase`: AWS DynamoDB
- `ScyllaDbDatabase`: ScyllaDB (Cassandra-compatible)
- `StorageServiceStore`: gRPC-based storage service

**Example Complex State**:
```rust
struct DeFiAppState {
    // Token balances
    tokens: MapView<TokenId, MapView<AccountOwner, Amount>>,
    // Liquidity pools
    pools: MapView<PoolId, PoolState>,
    // Orders
    orders: MapView<OrderId, Order>,
    // User positions
    positions: CollectionView<AccountOwner, UserPosition>,
}

struct UserPosition<C> {
    // Nested view
    balances: MapView<TokenId, Amount>,
    approvals: MapView<Spender, Amount>,
}
```

### State Persistence

```rust
// Load state
async fn load(runtime: ContractRuntime<Self>) -> Self {
    let state = MyState::load(runtime.root_view_storage_context()).await?;
    Self { state, runtime }
}

// Save state (called automatically at end of transaction)
async fn store(mut self) {
    self.state.save().await?;
}
```

---

## Cross-Chain Communication

### Message Types

1. **Single-Sender, Single-Receiver**:
   ```rust
   runtime.prepare_message(msg).send_to(target_chain);
   ```

2. **Broadcast Channels** (Single-Sender, Multiple-Receivers):
   ```rust
   // Subscribe to a broadcast channel
   runtime.subscribe_to_events(chain_id, app_id, stream_name);

   // Process broadcast messages
   async fn process_streams(&mut self, updates: Vec<StreamUpdate>) {
       for update in updates {
           // Handle events from multiple chains
       }
   }
   ```

### Message Guarantees

 **Guaranteed**:
- Exactly-once delivery
- Ordered delivery (within a channel)
- No duplicates
- No reordering

 **Not Guaranteed**:
- Immediate delivery (depends on block inclusion)
- Low latency (cross-chain has latency)

### Message Bouncing

```rust
// Check if message is bouncing
if runtime.message_is_bouncing().unwrap_or(false) {
    // Message was rejected, handle refund
}
```

---

## Security and Permissions

### Application Permissions

```rust
pub struct ApplicationPermissions {
    // Which applications can be created
    pub ready_at: Option<BlockHeight>,
    // Which bytecode can be published
    pub bytecode: HashSet<BytecodeId>,
}
```

### Chain Ownership

```rust
pub struct ChainOwnership {
    // Super owners (fast blocks)
    pub super_owners: BTreeSet<AccountOwner>,
    // Regular owners (weighted)
    pub owners: BTreeMap<AccountOwner, u64>,
    // Consensus configuration
    pub multi_leader_rounds: u32,
    pub timeout_config: TimeoutConfig,
}
```

### Account Permissions

```rust
pub fn check_account_permission(
    &mut self,
    owner: AccountOwner,
) -> Result<(), AccountPermissionError>
```

---

## Performance Considerations

### Gas Metering

The SDK tracks:
- **WASM fuel**: Computational resources
- **Storage operations**: Read/write costs
- **Memory usage**: Memory allocation

**Best Practices**:
1. Minimize storage operations
2. Use lazy loading (views)
3. Avoid unbounded loops
4. Batch operations when possible

### Cross-Chain Optimization

**Strategies**:
1. **Minimize cross-chain messages**
2. **Batch related operations**
3. **Design for chain locality**
4. **Use broadcast channels efficiently**

### View System Optimization

**Tips**:
1. Use `RegisterView` for single values
2. Use `MapView` for key-value lookups
3. Use `CollectionView` for nested state
4. Use `ReentrantCollectionView` for concurrent access

---

## Critical Limitations

### 1. No Native Multisig Application 

**Issue**: There is no built-in multisig application in the SDK.

**Solution**: Must build it yourself using:
- Multi-owner chains (for chain-level multisig)
- Application-level logic (for flexible multisig)

### 2. Cross-Application Calls Are Same-Chain Only 

**Issue**: `call_application()` only works on the same chain.

**Solution**: Use messaging for cross-chain coordination.

### 3. GraphQL Cannot Write State 

**Issue**: Services (GraphQL) are read-only.

**Solution**: Use operations for writes, GraphQL for queries.

### 4. Fast Block Restrictions 

**Issue**: Oracle calls and time assertions don't work in fast blocks.

**Solution**: Use regular owner blocks for these operations.

### 5. No Direct Access to Other Chain State 

**Issue**: Cannot query other chain state directly.

**Solution**: Use messaging or cross-chain queries through services.

---

## Recommendations for Multisig Platform

### Architecture

```

                    Frontend (TypeScript)                    
              React + @linera/client SDK                     

                              ↓

                    Backend (Node.js)                        
              REST API + @linera/client SDK                  

                              ↓

              Linera Multisig Application (Wasm)             

  Contract:                                                  
  • Multi-owner chain (3-of-5, 2-of-3, etc.)                
  • Proposal management                                      
  • Approval aggregation                                     
  • Threshold validation                                     
  • Execution logic                                          

  Service:                                                   
  • Query proposals                                          
  • Query approvals                                          
  • Query multisig configuration                            

```

### State Design

```rust
struct MultisigState {
    // Configuration
    config: RegisterView<MultisigConfig>,
    // Proposals
    proposals: MapView<ProposalId, Proposal>,
    // Approvals
    approvals: MapView<ProposalId, SetView<AccountOwner>>,
    // Execution history
    history: LogView<ExecutionRecord>,
}

struct MultisigConfig {
    owners: Vec<AccountOwner>,
    threshold: u64,
    timelock: Option<Duration>,
}
```

### Operations

1. **Create Proposal**:
   ```rust
   Operation::CreateProposal {
       id: ProposalId,
       operation: Vec<u8>,
       description: String,
   }
   ```

2. **Approve Proposal**:
   ```rust
   Operation::Approve {
       proposal_id: ProposalId,
   }
   ```

3. **Execute Proposal**:
   ```rust
   Operation::Execute {
       proposal_id: ProposalId,
   }
   ```

4. **Revoke Approval**:
   ```rust
   Operation::Revoke {
       proposal_id: ProposalId,
   }
   ```

### Cross-Chain Considerations

**Option 1: Single Multisig Chain**
- All multisigs live on one chain
- Other chains send approval messages
- Simpler but potential centralization

**Option 2: Per-User Multisig Chains**
- Each user has their own multisig chain
- More decentralized but more complex

**Recommendation**: Start with Option 1, migrate to Option 2 if needed.

---

## Conclusion

The Linera SDK is a **powerful and capable framework** for building complex blockchain applications, including multisig platforms. While it has specific constraints (Wasm sandboxing, cross-chain messaging model), these constraints enable its unique strengths (scalability, security, composability).

### Key Takeaways

 **Strengths**:
- Native multi-owner chain support
- Sophisticated cross-chain messaging
- Powerful views system for state management
- Composable applications
- Strong security model

 **Limitations**:
- No built-in multisig application (must build custom)
- Cross-application calls are same-chain only
- GraphQL is read-only
- Fast block restrictions

### For Multisig Platform

**Feasibility**:  **HIGHLY FEASIBLE**

**Recommended Approach**:
1. Use multi-owner chains for foundation
2. Build application-level multisig logic
3. Use TypeScript SDK for frontend/backend
4. Use views for efficient state management
5. Use messaging for cross-chain coordination

**Estimated Complexity**: Medium to High (requires custom application development but SDK provides all necessary primitives)

---

## References

- [Linera SDK README](https://github.com/linera-io/linera-protocol/blob/main/linera-sdk/README.md)
- [Linera Views README](https://github.com/linera-io/linera-protocol/blob/main/linera-views/README.md)
- [Fungible Token Example](https://github.com/linera-io/linera-protocol/tree/main/examples/fungible)
- [Crowd Funding Example](https://github.com/linera-io/linera-protocol/tree/main/examples/crowd-funding)
- [Chain Ownership](https://github.com/linera-io/linera-protocol/blob/main/linera-base/src/ownership.rs)
- [Contract Runtime](https://github.com/linera-io/linera-protocol/blob/main/linera-sdk/src/contract/runtime.rs)
- [Service Runtime](https://github.com/linera-io/linera-protocol/blob/main/linera-sdk/src/service/runtime.rs)

---

**Document Status**:  Complete
**Next Review**: After testnet validation
**Maintainer**: Claude Code (Research Agent)
