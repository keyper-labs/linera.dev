# Linera SDK: Architecture Decision Records

**Date**: February 3, 2026
**Companion to**: [Capabilities Analysis](./linera-sdk-capabilities-and-limitations-comprehensive-analysis.md)

---

## Decision 1: Dual Binary Model (Contract + Service)

### Context

Linera applications need to handle both state-changing operations and read-only queries efficiently.

### Decision

Use **two separate Wasm binaries**: Contract (write) and Service (read).

### Rationale

| Aspect | Contract | Service |
|--------|----------|---------|
| **Access** | Read + Write | Read Only |
| **Gas** | Metered | Not Metered |
| **Trigger** | Block execution | User queries |
| **Interface** | Operations/Messages | GraphQL |

**Benefits**:

- Separation of concerns
- Efficient queries (no gas cost)
- Clear security boundaries
- Optimized execution paths

**Trade-offs**:

- More complex deployment (2 binaries)
- Must keep state in sync

### Consequences

✅ **Positive**: Clear security model, efficient queries
⚠️ **Negative**: More complex development workflow

---

## Decision 2: View System for State Management

### Context

Applications need efficient state management with lazy loading and partial updates.

### Decision

Use **linera-views** system with key-value store abstraction.

### Rationale

**Supported Databases**:

- MemoryStore (testing)
- RocksDbStore (disk)
- DynamoDbDatabase (AWS)
- ScyllaDbDatabase (cloud)
- StorageServiceStore (gRPC)

**View Types**:

- `RegisterView`: Single value
- `MapView`: Key-value mapping
- `SetView`: Unique keys
- `LogView`: Append-only log
- `QueueView`: FIFO queue
- `CollectionView`: Nested views
- `ReentrantCollectionView`: Concurrent access

**Benefits**:

- Lazy loading (only load what you need)
- Efficient updates (only write what changed)
- Database agnostic
- Nested state support

### Consequences

✅ **Positive**: Efficient state management, scalable
⚠️ **Negative**: Learning curve for view system

---

## Decision 3: Multi-Owner Chains for Consensus

### Context

Multiple owners need to collectively propose and validate blocks.

### Decision

Use **native multi-owner chain support** with weighted owners.

### Rationale

```rust
pub struct ChainOwnership {
    pub super_owners: BTreeSet<AccountOwner>,  // Fast blocks
    pub owners: BTreeMap<AccountOwner, u64>,    // Weighted
    pub multi_leader_rounds: u32,               // Consensus rounds
    pub timeout_config: TimeoutConfig,          // Timeouts
}
```

**Consensus Rounds**:

1. **Fast Round**: Super owners only (instant)
2. **Multi-Leader Round**: All owners can propose (parallel)
3. **Single-Leader Round**: Weighted round-robin (sequential)
4. **Validator Round**: Fallback for liveness

**Benefits**:

- Native multisig at chain level
- Flexible consensus
- Fast finality for super owners
- Liveness guarantees

### Consequences

✅ **Positive**: Native multisig support
⚠️ **Negative**: Complex consensus configuration

---

## Decision 4: Cross-Chain Messaging Model

### Context

Applications need to communicate across different microchains.

### Decision

Use **asynchronous messaging** with tracking and authentication.

### Rationale

**Message Types**:

1. **Single-Sender → Single-Receiver**: Point-to-point
2. **Single-Sender → Multiple-Receivers**: Broadcast channels

**Message Guarantees**:

- ✅ Exactly-once delivery
- ✅ Ordered delivery (per channel)
- ✅ No duplicates
- ✅ No reordering

**Message Builder Pattern**:

```rust
runtime.prepare_message(message)
    .with_authentication()    // Forward owner
    .with_tracking()          // Notification if rejected
    .with_grant(resources)    // Pay for receiver
    .send_to(chain_id);
```

**Benefits**:

- Secure cross-chain communication
- Bouncing (rejected message notification)
- Resource grants for receiver
- Authentication forwarding

### Consequences

✅ **Positive**: Secure, reliable cross-chain communication
⚠️ **Negative**: Asynchronous (not immediate), latency

---

## Decision 5: Cross-Application Calls (Same Chain Only)

### Context

Applications need to compose functionality without messaging overhead.

### Decision

Use **synchronous cross-application calls** for same-chain composition.

### Rationale

```rust
pub fn call_application<A: ContractAbi + Send>(
    &mut self,
    authenticated: bool,
    application: ApplicationId<A>,
    call: &A::Operation,
) -> A::Response
```

**Benefits**:

- Synchronous execution
- No messaging overhead
- Direct composition
- Shared state access

**Limitations**:

- Same chain only
- Synchronous (can fail)
- No cross-chain

### Consequences

✅ **Positive**: Efficient same-chain composition
⚠️ **Negative**: Cannot use cross-chain

---

## Decision 6: Event Streams for Off-Chain Integration

### Context

Applications need to notify off-chain systems of state changes.

### Decision

Use **event streams** with publish/subscribe pattern.

### Rationale

```rust
// Emit events
runtime.emit("events", &event_value);

// Subscribe to events
runtime.subscribe_to_events(chain_id, app_id, "events");

// Process events
async fn process_streams(&mut self, updates: Vec<StreamUpdate>) {
    for update in updates {
        // Handle event
    }
}
```

**Benefits**:

- Off-chain indexing
- Event-driven architecture
- Cross-chain coordination
- No gas cost for subscriptions

### Consequences

✅ **Positive**: Rich off-chain integration
⚠️ **Negative**: Not for on-chain logic

---

## Decision 7: HTTP Oracle for External Data

### Context

Applications need to fetch external data (e.g., price oracles).

### Decision

Use **HTTP oracle calls** with deterministic query requirement.

### Rationale

```rust
pub fn http_request(&mut self, request: http::Request) -> http::Response
```

**Constraints**:

- Only deterministic queries
- All validators must get same response
- Cannot use in fast blocks

**Benefits**:

- External data access
- Price oracles
- Bridge support (with caution)

### Consequences

✅ **Positive**: External data access
⚠️ **Negative**: Limited to deterministic queries, not for fast blocks

---

## Decision 8: WebAssembly for Smart Contracts

### Context

Need secure, portable, and efficient smart contract execution.

### Decision

Use **WebAssembly (Wasm)** for contract and service binaries.

### Rationale

**Benefits**:

- **Security**: Sandboxed execution
- **Portability**: Run anywhere
- **Efficiency**: Near-native performance
- **Determinism**: Guaranteed consistent execution
- **Composability**: Easy to integrate

**Trade-offs**:

- No direct OS access
- No floating point (non-deterministic)
- No direct crypto (use host APIs)
- Gas metering overhead

### Consequences

✅ **Positive**: Secure, portable, efficient
⚠️ **Negative**: Limited access to system resources

---

## Decision 9: GraphQL for Service Queries

### Context

Services need a flexible query interface for read-only operations.

### Decision

Use **GraphQL** for service queries with auto-generated schema.

### Rationale

**Benefits**:

- Flexible queries
- Type-safe
- Auto-generated schema
- Strong typing
- Rich ecosystem

**Limitations**:

- Read-only (no mutations)
- Cannot modify state

### Consequences

✅ **Positive**: Flexible, type-safe queries
⚠️ **Negative**: Read-only only

---

## Decision 10: Gas Metering for Resource Control

### Context

Need to prevent resource exhaustion and denial of service.

### Decision

Use **fuel-based gas metering** for WASM execution.

### Rationale

**Tracked Resources**:

- WASM fuel (computation)
- Storage reads
- Storage writes
- Memory usage

**Benefits**:

- Prevents DoS
- Fair resource allocation
- Economic incentives
- Predictable costs

### Consequences

✅ **Positive**: Resource control, fairness
⚠️ **Negative**: Complexity in gas estimation

---

## Architecture Diagram

```
┌─────────────────────────────────────────────────────────────────────┐
│                         Client Layer                                │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐             │
│  │   React UI   │  │  Mobile App  │  │   CLI Tool   │             │
│  └──────┬───────┘  └──────┬───────┘  └──────┬───────┘             │
└─────────┼──────────────────┼──────────────────┼───────────────────┘
          │                  │                  │
          └──────────────────┼──────────────────┘
                             ↓
┌─────────────────────────────────────────────────────────────────────┐
│                      Application Layer                              │
│  ┌──────────────────────────────────────────────────────────────┐  │
│  │              Multisig Application (Wasm)                     │  │
│  ├──────────────────────────────────────────────────────────────┤  │
│  │  Contract (Write)              Service (Read)                │  │
│  │  ┌──────────────────────┐    ┌──────────────────────┐       │  │
│  │  │ • execute_operation  │    │ • handle_query       │       │  │
│  │  │ • execute_message    │    │ • GraphQL API        │       │  │
│  │  │ • process_streams    │    │ • query_application  │       │  │
│  │  │ • instantiate        │    │                      │       │  │
│  │  └──────────────────────┘    └──────────────────────┘       │  │
│  └──────────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────────┘
                             ↓
┌─────────────────────────────────────────────────────────────────────┐
│                       Linera Protocol Layer                         │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐             │
│  │ Cross-Chain  │  │  Storage     │  │  Consensus   │             │
│  │  Messaging   │  │  (Views)     │  │   Engine     │             │
│  └──────────────┘  └──────────────┘  └──────────────┘             │
└─────────────────────────────────────────────────────────────────────┘
                             ↓
┌─────────────────────────────────────────────────────────────────────┐
│                      Infrastructure Layer                           │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐             │
│  │   RocksDB    │  │   ScyllaDB   │  │  DynamoDB    │             │
│  │  (Storage)   │  │  (Storage)   │  │  (Storage)   │             │
│  └──────────────┘  └──────────────┘  └──────────────┘             │
└─────────────────────────────────────────────────────────────────────┘
```

---

## Multisig Architecture Pattern

```
┌─────────────────────────────────────────────────────────────────────┐
│                        Multisig Platform                           │
├─────────────────────────────────────────────────────────────────────┤
│                                                                     │
│  ┌─────────────────────────────────────────────────────────────┐   │
│  │                    Multisig Chain                           │   │
│  │  ┌─────────────────────────────────────────────────────┐   │   │
│  │  │            Multisig Application (Wasm)              │   │   │
│  │  │  • 3-of-5 multisig logic                            │   │   │
│  │  │  • Proposal management                              │   │   │
│  │  │  • Approval aggregation                             │   │   │
│  │  │  • Threshold validation                             │   │   │
│  │  │  • Execution logic                                  │   │   │
│  │  └─────────────────────────────────────────────────────┘   │   │
│  │                                                               │   │
│  │  Owners: Owner1, Owner2, Owner3, Owner4, Owner5              │   │
│  │  Threshold: 3                                               │   │
│  └─────────────────────────────────────────────────────────────┘   │
│                              ↕ Messaging                           │
│  ┌───────────────────┐  ┌───────────────────┐  ┌───────────────┐  │
│  │   Owner Chain 1   │  │   Owner Chain 2   │  │ Owner Chain 3│  │
│  │  (Owner1 Wallet)  │  │  (Owner2 Wallet)  │  │(Owner3 Wallet)│  │
│  └───────────────────┘  └───────────────────┘  └───────────────┘  │
│                                                                     │
└─────────────────────────────────────────────────────────────────────┘
```

---

## Summary

| Decision | Rationale | Benefits | Trade-offs |
|----------|-----------|----------|------------|
| Dual Binary | Separation of concerns | Clear security model | More complex |
| View System | Efficient state management | Lazy loading, scalable | Learning curve |
| Multi-Owner | Native multisig | Built-in consensus | Complex config |
| Cross-Chain Msg | Secure communication | Reliable, tracked | Async, latency |
| Same-Chain Calls | Efficient composition | Synchronous, fast | Cross-chain only |
| Event Streams | Off-chain integration | Rich notifications | Not for on-chain |
| HTTP Oracle | External data | Price feeds | Deterministic only |
| WebAssembly | Security, portability | Safe execution | Limited access |
| GraphQL | Flexible queries | Type-safe | Read-only |
| Gas Metering | Resource control | Fairness | Complexity |

---

**Status**: ✅ Complete
**Next**: Implementation guide with code examples
