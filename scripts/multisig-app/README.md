# Linera Multisig Application

A fully-featured multisig wallet implementation for the Linera blockchain.

## Features

### Core Functionality
- ✅ **m-of-n Multisig**: Configurable threshold requiring m confirmations from n owners
- ✅ **Proposal-Based Governance**: All operations require proposal + threshold confirmations
- ✅ **Real Fund Transfers**: Execute proposals actually transfer tokens on the blockchain
- ✅ **Owner Management**: Add, remove, replace owners via governance proposals
- ✅ **Threshold Changes**: Modify required confirmations via governance

### Operations

All operations follow the same proposal flow:
1. **SubmitProposal** - Create proposal (auto-confirms submitter)
2. **ConfirmProposal** - Other owners add confirmations
3. **ExecuteProposal** - Execute when threshold reached

#### Proposal Types

| Type | Description | Parameters |
|------|-------------|------------|
| `Transfer` | Send funds to address | `to`, `value`, `data` |
| `AddOwner` | Add new owner | `owner` |
| `RemoveOwner` | Remove existing owner | `owner` |
| `ReplaceOwner` | Replace one owner with another | `old_owner`, `new_owner` |
| `ChangeThreshold` | Change required confirmations | `threshold` |

## Architecture

### Smart Contract (contract.rs)
- Implements proposal lifecycle (submit → confirm → execute)
- Validates all operations
- Executes real token transfers via `runtime.transfer()`
- Enforces m-of-n threshold for ALL operations including governance

### State (state.rs)
```rust
pub struct MultisigState {
    pub owners: RegisterView<Vec<AccountOwner>>,      // Current owners
    pub threshold: RegisterView<u64>,                  // Required confirmations
    pub nonce: RegisterView<u64>,                      // Proposal ID counter
    pub pending_proposals: MapView<u64, Proposal>,     // Pending proposals
    pub confirmations: MapView<AccountOwner, Vec<u64>>, // Owner -> confirmed proposals
    pub executed_proposals: MapView<u64, Proposal>,    // Historical record
}
```

### Service (service.rs)
GraphQL queries available:
- `owners()` - List current owners
- `threshold()` - Current threshold
- `proposal(id)` - Get proposal by ID
- `pending_proposals()` - List all pending proposals
- `executed_proposals()` - List all executed proposals
- `has_confirmed(owner, proposal_id)` - Check if owner confirmed
- `confirmation_count(proposal_id)` - Get number of confirmations
- `proposals_confirmed_by(owner)` - Get proposals confirmed by owner

## Usage Example

### Create 2-of-3 Multisig

```rust
// Instantiate with 3 owners, threshold = 2
let args = InstantiationArgs {
    owners: vec![owner1, owner2, owner3],
    threshold: 2,
};
```

### Submit Transfer Proposal

```rust
// Owner1 submits transfer proposal
let operation = MultisigOperation::SubmitProposal {
    proposal_type: ProposalType::Transfer {
        to: recipient,
        value: 100,
        data: vec![],
    },
};
// Returns: ProposalSubmitted { proposal_id: 0 }
// Auto-confirms Owner1 (count = 1)
```

### Confirm Proposal

```rust
// Owner2 confirms
let operation = MultisigOperation::ConfirmProposal {
    proposal_id: 0,
};
// Returns: ProposalConfirmed { proposal_id: 0, confirmations: 2 }
```

### Execute Proposal

```rust
// Any owner can execute when threshold met
let operation = MultisigOperation::ExecuteProposal {
    proposal_id: 0,
};
// Transfers 100 tokens to recipient
// Returns: FundsTransferred { to: recipient, value: 100 }
```

### Governance Example (Add Owner)

```rust
// Owner1 proposes adding new owner
let operation = MultisigOperation::SubmitProposal {
    proposal_type: ProposalType::AddOwner {
        owner: new_owner,
    },
};

// Owner2 confirms (count = 2, meets threshold)
let operation = MultisigOperation::ConfirmProposal { proposal_id: 1 };

// Execute - adds new owner
let operation = MultisigOperation::ExecuteProposal { proposal_id: 1 };
// Returns: OwnerAdded { owner: new_owner }
```

## Security Features

1. **Threshold Enforcement**: All operations require m-of-n confirmations
2. **Auto-Confirmation**: Submitter auto-confirms their own proposal
3. **Double-Confirmation Prevention**: Owner cannot confirm twice
4. **Revocation**: Owners can revoke confirmation before execution
5. **Owner Validation**: All operations verify caller is an owner
6. **Threshold Safety**: Cannot remove owners if it would break threshold
7. **Replay Protection**: Each proposal has unique nonce/ID

## Testing

Run unit tests:
```bash
cd scripts/multisig-app
cargo test
```

Test coverage includes:
- Instantiation validation
- Proposal submission (all types)
- Confirmation flow
- Execution with threshold
- Revocation
- Governance operations
- Edge cases and error conditions

## Building

Build contract (Wasm):
```bash
cargo build --release --target wasm32-unknown-unknown
```

## Dependencies

- `linera-sdk` 0.15.11 - Linera SDK
- `async-graphql` - GraphQL service
- `serde` - Serialization
- `log` - Logging

## License

MIT - PalmeraDAO
