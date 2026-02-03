# Multisig Flow

Application-level multisig proposal, approval, and execution flow.

## Architecture Overview

```mermaid
flowchart TB
    subgraph Chain["Multi-Owner Chain"]
        subgraph Contract["Multisig Contract"]
            State["State: proposals{}, approvals{}"]
            OpCreate["operation: create_proposal"]
            OpApprove["operation: approve_proposal"]
            OpExecute["operation: execute_proposal"]
        end
        
        subgraph Service["Multisig Service"]
            Query["query: get_proposal(id)"]
        end
    end
    
    subgraph Actors["Actors"]
        Owner1["Owner 1"]
        Owner2["Owner 2"]
        Owner3["Owner 3"]
    end
    
    subgraph Target["Target"]
        CrossChain["Cross-Chain Transfer"]
        ContractCall["Contract Call"]
        ConfigChange["Config Change"]
    end
    
    Owner1 -->|create_proposal| OpCreate
    Owner2 -->|approve_proposal| OpApprove
    Owner3 -->|approve_proposal| OpApprove
    
    OpCreate --> State
    OpApprove --> State
    OpExecute -->|threshold reached| State
    
    OpExecute --> CrossChain
    OpExecute --> ContractCall
    OpExecute --> ConfigChange
    
    Query -.->|read state| Owner1
    Query -.->|read state| Owner2
    Query -.->|read state| Owner3
```

## Proposal Lifecycle

```
┌─────────────────────────────────────────────────────────────────────────┐
│                        PROPOSAL LIFECYCLE                               │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                         │
│  1. CREATE PROPOSAL                                                     │
│  ┌─────────────┐                                                        │
│  │   Owner     │                                                        │
│  │  (any of    │                                                        │
│  │   N owners) │                                                        │
│  └──────┬──────┘                                                        │
│         │                                                               │
│         ▼                                                               │
│  ┌─────────────────────────────────────────────────────────────────┐   │
│  │ Proposal Structure:                                             │   │
│  │ {                                                               │   │
│  │   id: u64,                                                      │   │
│  │   proposer: Owner,                                              │   │
│  │   action: Action,      // transfer, call, config                │   │
│  │   description: String,                                          │   │
│  │   created_at: Timestamp,                                        │   │
│  │   expires_at: Timestamp,                                        │   │
│  │   approvals: Vec<Owner>  // starts with [proposer]              │   │
│  │ }                                                               │   │
│  └─────────────────────────────────────────────────────────────────┘   │
│         │                                                               │
│         ▼                                                               │
│  ┌─────────────┐                                                        │
│  │   PENDING   │  ←─ Current state: waiting for approvals              │
│  │   STATE     │                                                        │
│  └──────┬──────┘                                                        │
│         │                                                               │
│         │  2. APPROVE PROPOSAL (repeated m-1 times)                     │
│         │                                                               │
│         ▼                                                               │
│  ┌─────────────┐                                                        │
│  │   Owners    │                                                        │
│  │  (distinct  │  Each approval is a separate operation               │
│  │   from      │  on the multi-owner chain                             │
│  │   proposer) │                                                        │
│  └──────┬──────┘                                                        │
│         │                                                               │
│         ▼                                                               │
│  ┌─────────────────────────────────────────────────────────────────┐   │
│  │ Update: approvals.push(owner)                                   │   │
│  │ Validation:                                                     │   │
│  │   - Not already approved                                        │   │
│  │   - Is valid owner                                              │   │
│  │   - Proposal not expired                                        │   │
│  │   - Not already executed                                        │   │
│  └─────────────────────────────────────────────────────────────────┘   │
│         │                                                               │
│         ▼                                                               │
│  ┌─────────────────┐                                                    │
│  │ Check threshold │  approvals.len() >= m?                              │
│  └───────┬─────────┘                                                    │
│          │                                                              │
│    ┌─────┴─────┐                                                        │
│    │           │                                                        │
│    ▼           ▼                                                        │
│  ┌──────┐  ┌────────┐                                                   │
│  │ YES  │  │  NO    │  ←─ Continue waiting for more approvals           │
│  └──┬───┘  └────────┘                                                   │
│     │                                                                   │
│     │  3. EXECUTE PROPOSAL                                              │
│     │                                                                   │
│     ▼                                                                   │
│  ┌─────────────────────────────────────────────────────────────────┐   │
│  │ Execute action:                                                 │   │
│  │   - Transfer: emit message to target chain                      │   │
│  │   - Call: execute contract operation                            │   │
│  │   - Config: update local state                                  │   │
│  │ Mark: executed = true                                           │   │
│  └─────────────────────────────────────────────────────────────────┘   │
│     │                                                                   │
│     ▼                                                                   │
│  ┌─────────────┐                                                        │
│  │  EXECUTED   │  ←─ Final state                                        │
│  │   STATE     │                                                        │
│  └─────────────┘                                                        │
│                                                                         │
│  ALTERNATIVE PATHS:                                                     │
│  ┌─────────────────────────────────────────────────────────────────┐   │
│  │ CANCEL: Proposal creator can cancel before execution             │   │
│  │ EXPIRE: After expires_at, anyone can mark as expired             │   │
│  │ REJECT: Not implemented (implicit via non-approval)              │   │
│  └─────────────────────────────────────────────────────────────────┘   │
│                                                                         │
└─────────────────────────────────────────────────────────────────────────┘
```

## Cross-Chain Transfer Example

```
SCENARIO: 3-of-3 multisig transferring 100 tokens to Chain B

Chain A (Multisig Contract)              Network                Chain B
────────────────────────────             ───────                ───────

Step 1: Create Proposal
┌─────────┐
│ Owner A │  Creates proposal:
│(proposer)│   "Transfer 100 to B"
└────┬────┘
     │
     ▼
┌─────────────┐
│ Store in    │  State.proposals[id] = proposal
│ contract    │  State.approvals[id] = [A]
│ state       │
└──────┬──────┘
       │
       │  Proposal created
       │  Awaiting 2 more approvals

Step 2: Owner B Approves
┌─────────┐
│ Owner B │  Calls approve_proposal(id)
└────┬────┘
     │
     ▼
┌─────────────┐
│ Add to      │  State.approvals[id] = [A, B]
│ approvals   │  Count: 2/3 (need 1 more)
└─────────────┘

Step 3: Owner C Approves
┌─────────┐
│ Owner C │  Calls approve_proposal(id)
└────┬────┘
     │
     ▼
┌─────────────┐
│ Add to      │  State.approvals[id] = [A, B, C]
│ approvals   │  Count: 3/3 ✓ THRESHOLD REACHED
└──────┬──────┘
       │
       │  Auto-trigger OR
       │  explicit execute call
       ▼

Step 4: Execute Transfer
┌─────────────┐
│ Emit        │  Message {
│ message     │    destination: Chain B,
└──────┬──────┘    amount: 100,
       │           authenticated_signer: Chain A
       │         }
       │
       │  Cross-chain message
       └───────────────────────▶  Validators route
                                  message
                                    │
                                    ▼
                           ┌─────────────┐
                           │  Chain B    │
                           │  Inbox      │
                           └──────┬──────┘
                                  │
                                  ▼
                           ┌─────────────┐
                           │  Process    │
                           │  Transfer   │
                           │  Credit 100 │
                           └─────────────┘

Total operations: 4 (create + 3 approvals)
Each operation = 1 on-chain transaction
```

## Contract State Structure

```rust
// Simplified state structure
pub struct MultisigContract {
    // Configuration
    pub owners: Vec<Owner>,           // All owners
    pub threshold: u32,                // m-of-n threshold
    
    // Proposals
    pub proposals: Map<ProposalId, Proposal>,
    pub approvals: Map<ProposalId, Vec<Owner>>,
    pub executed: Map<ProposalId, bool>,
    
    // Counter
    pub next_proposal_id: u64,
}

pub struct Proposal {
    pub id: ProposalId,
    pub proposer: Owner,
    pub action: Action,
    pub description: String,
    pub created_at: Timestamp,
    pub expires_at: Timestamp,
}

pub enum Action {
    Transfer {
        destination: ChainId,
        amount: Amount,
        recipient: Account,
    },
    ContractCall {
        application: ApplicationId,
        operation: Vec<u8>,
    },
    ConfigChange {
        new_owners: Option<Vec<Owner>>,
        new_threshold: Option<u32>,
    },
}
```

## Sequence Diagram

```mermaid
sequenceDiagram
    participant O1 as Owner 1
    participant O2 as Owner 2
    participant O3 as Owner 3
    participant CC as Multisig Contract
    participant Chain as Chain A
    
    O1->>CC: create_proposal(action)
    CC->>Chain: Store proposal
    Chain-->>CC: Proposal ID: 42
    CC-->>O1: proposal_id: 42
    
    Note over O1,O3: Proposal state: PENDING
    
    O1->>CC: approve_proposal(42)
    CC->>CC: Record approval O1
    CC->>Chain: Update approvals
    CC-->>O1: Approval recorded
    
    Note over O1,O3: Approvals: 1/3
    
    O2->>CC: approve_proposal(42)
    CC->>CC: Record approval O2
    CC->>Chain: Update approvals
    CC-->>O2: Approval recorded
    
    Note over O1,O3: Approvals: 2/3
    
    O3->>CC: approve_proposal(42)
    CC->>CC: Record approval O3
    CC->>CC: Check threshold: 3/3 ✓
    CC->>Chain: Mark proposal executed
    CC->>CC: Execute action
    CC-->>O3: Proposal executed
    
    Note over O1,O3: Proposal state: EXECUTED
```

## Error Handling

| Error | Cause | Resolution |
|-------|-------|------------|
| `DuplicateApproval` | Owner tries to approve twice | No action needed |
| `InvalidOwner` | Non-owner tries to approve | Must be owner |
| `ProposalExpired` | Approval after expiration | Create new proposal |
| `AlreadyExecuted` | Action on executed proposal | None - already done |
| `ThresholdNotMet` | Execute before enough approvals | Wait for more approvals |
| `InsufficientBalance` | Transfer exceeds balance | Fund chain or reduce amount |

---

## Comparison: Protocol vs Application Multisig

```
┌─────────────────────────────────────────────────────────────────────┐
│                    PROTOCOL-LEVEL MULTISIG                          │
│                         (Built-in)                                  │
├─────────────────────────────────────────────────────────────────────┤
│  • Multi-owner chains: N owners, any 1 can sign                     │
│  • Consensus handles contention between owners                      │
│  • No threshold logic - always 1-of-N                               │
│  • Fast/multi-leader/single-leader rounds                           │
│  • Use case: Shared access to chain                                 │
└─────────────────────────────────────────────────────────────────────┘
                              │
                              ▼ Build on top
┌─────────────────────────────────────────────────────────────────────┐
│                   APPLICATION-LEVEL MULTISIG                        │
│                    (Custom Contract)                                │
├─────────────────────────────────────────────────────────────────────┤
│  • Deployed as application on multi-owner chain                     │
│  • Custom threshold logic: m-of-N approvals required                │
│  • Each approval = separate operation (transaction)                 │
│  • Contract tracks approvals in state                               │
│  • Use case: Treasury, governance, time-locked transfers            │
└─────────────────────────────────────────────────────────────────────┘
```

---

## Related Documentation

- [Microchain Lifecycle](./microchain-lifecycle.md)
- [Application Architecture](./application-architecture.md)
- [Message Flow](./message-flow.md)
