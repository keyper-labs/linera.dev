# Multisig GraphQL Service - Reference Documentation

**Status**:  **TEMPORARILY DISABLED** - Removed to allow Rust 1.86 compilation
**Backup**: `multisig_service_backup.rs`
**Reason**: async-graphql 7.0.17 requires Rust 1.87+, but Rust 1.87+ generates opcode 252
**When**: 2026-02-03

---

## Original Service Implementation

The multisig application included a GraphQL service built with async-graphql that provided:
- Query interface for contract state
- Real-time proposal tracking
- Owner confirmation status
- Transaction history

### GraphQL Queries

```graphql
type Query {
  """Get the list of current owners"""
  owners: [Owner!]!

  """Get the current threshold"""
  threshold: UInt64!

  """Get the current nonce (next proposal ID)"""
  nonce: UInt64!

  """Get a proposal by ID"""
  proposal(id: UInt64!): ProposalView

  """Get all pending proposals"""
  pendingProposals: [ProposalView!]!

  """Get all executed proposals"""
  executedProposals: [ProposalView!]!

  """Check if an owner has confirmed a proposal"""
  hasConfirmed(owner: Owner!, proposalId: UInt64!): Boolean!

  """Get the number of confirmations for a proposal"""
  confirmationCount(proposalId: UInt64!): UInt64!

  """Get proposals where an owner has confirmed"""
  proposalsConfirmedBy(owner: Owner!): [ProposalView!]!
}
```

### Types

```graphql
type ProposalView {
  id: UInt64!
  proposalType: String!  # Serialized as string for GraphQL
  proposer: Owner!
  confirmationCount: UInt64!
  executed: Boolean!
  createdAt: UInt64!
}

scalar Owner
```

---

## How to Restore GraphQL Service

When Linera SDK is updated to support Rust 1.87+ or bulk memory operations:

### Step 1: Restore Dependencies

Add to `Cargo.toml`:
```toml
[dependencies]
async-graphql = { version = "7.0", features = ["chrono"] }
```

### Step 2: Restore Binary Target

Add to `Cargo.toml`:
```toml
[[bin]]
name = "multisig_service"
path = "src/service.rs"
```

### Step 3: Restore Service File

```bash
cp docs/research/multisig_service_backup.rs src/service.rs
```

### Step 4: Rebuild

```bash
cargo build --release --target wasm32-unknown-unknown
```

---

## Current Alternative: CLI Access

Without GraphQL, use Linera CLI to query contract state:

```bash
# Query contract state
linera query-contract "$CHAIN_ID" "$APPLICATION_ID"

# Read state directly
linera read-object "$CHAIN_ID" "$APPLICATION_ID"
```

---

## Service Implementation Details

### File: `src/service.rs`

**Main Components**:
1. **Service Runtime**: Connects to Linera blockchain
2. **GraphQL Schema**: Defines queries and types
3. **State Access**: Reads from contract views
4. **Query Handlers**: Implements each GraphQL resolver

### Key Dependencies

```toml
async-graphql = "7.0"           # GraphQL framework
linera-sdk = "0.15.11"         # Linera SDK
serde = { version = "1.0", features = ["derive"] }
```

### Async Handlers

All queries are async and use `linera_views` for state access:

```rust
async fn owners(&self, ctx: &Context<'_>) -> Result<Vec<Owner>> {
    let state = ctx.data::<Arc<MultisigState>>()?;
    Ok(state.owners.get().clone())
}
```

---

## Future Considerations

### When to Restore

1. **When Linera adds bulk memory support** to runtime
2. **When Linera SDK updates** to work with Rust 1.87+ without bulk memory
3. **When alternative query layer** is implemented (REST API instead of GraphQL)

### Alternative Approaches

Instead of GraphQL, consider:
- **REST API**: Simple HTTP endpoints with JSON responses
- **gRPC**: Type-safe RPC protocol
- **Direct CLI**: Use Linera CLI scripts for queries

---

**Last Updated**: 2026-02-03
**Restorable**: Yes - see backup file for full implementation
