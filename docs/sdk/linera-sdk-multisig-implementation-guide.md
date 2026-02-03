# Linera SDK: Multisig Implementation Guide

**Date**: February 3, 2026
**Companion to**: [linera-sdk-capabilities-and-limitations-comprehensive-analysis.md](./linera-sdk-capabilities-and-limitations-comprehensive-analysis.md)

---

## Table of Contents

1. [Multisig State Design](#multisig-state-design)
2. [Contract Implementation](#contract-implementation)
3. [Service Implementation](#service-implementation)
4. [Cross-Chain Patterns](#cross-chain-patterns)
5. [Testing Patterns](#testing-patterns)
6. [Deployment Patterns](#deployment-patterns)

---

## Multisig State Design

### Complete State Structure

```rust
use linera_sdk::{
    views::{RegisterView, MapView, SetView, LogView, CollectionView, RootView, View},
    Contract, ContractRuntime,
};
use serde::{Serialize, Deserialize};

/// Main multisig state
pub struct MultisigState<C> {
    /// Immutable configuration
    pub config: RegisterView<MultisigConfig>,

    /// Active proposals
    pub proposals: MapView<ProposalId, Proposal>,

    /// Approvals for each proposal
    pub approvals: MapView<ProposalId, SetView<AccountOwner>>,

    /// Execution history
    pub history: LogView<ExecutionRecord>,

    /// Nonce for unique proposal IDs
    pub next_proposal_id: RegisterView<u64>,
}

impl<C> RootView for MultisigState<C>
where
    C: linera_views::Context,
{
    type Context = C;
}

/// Multisig configuration
#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct MultisigConfig {
    /// List of owners
    pub owners: Vec<AccountOwner>,

    /// Number of approvals required
    pub threshold: u64,

    /// Optional timelock for execution
    pub timelock: Option<u64>,

    /// Maximum proposal lifetime (blocks)
    pub proposal_expiry: Option<u64>,
}

/// A multisig proposal
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Proposal {
    /// Unique identifier
    pub id: ProposalId,

    /// Proposed operation
    pub operation: Vec<u8>,

    /// Description
    pub description: String,

    /// Creator
    pub proposer: AccountOwner,

    /// Creation timestamp
    pub created_at: u64,

    /// Execution timestamp (if timelock)
    pub executable_at: Option<u64>,

    /// Execution status
    pub status: ProposalStatus,

    /// Block height when proposal expires
    pub expires_at: Option<u64>,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub enum ProposalStatus {
    Pending,
    Approved,
    Executed,
    Rejected,
    Expired,
}

/// Execution record
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ExecutionRecord {
    pub proposal_id: ProposalId,
    pub executed_at: u64,
    pub executor: AccountOwner,
    pub success: bool,
}

/// Proposal ID (newtype wrapper)
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash, Serialize, Deserialize)]
pub struct ProposalId(pub u64);
```

### Operations and Messages

```rust
/// User operations
#[derive(Debug, Clone, Serialize, Deserialize)]
pub enum MultisigOperation {
    /// Create a new proposal
    CreateProposal {
        description: String,
        operation: Vec<u8>,
        timelock: Option<u64>,
    },

    /// Approve a proposal
    Approve {
        proposal_id: ProposalId,
    },

    /// Revoke approval
    Revoke {
        proposal_id: ProposalId,
    },

    /// Execute a proposal
    Execute {
        proposal_id: ProposalId,
    },

    /// Update configuration (only owners)
    UpdateConfig {
        owners: Vec<AccountOwner>,
        threshold: u64,
    },

    /// Query state (returns response)
    GetState,
}

/// Contract responses
#[derive(Debug, Clone, Serialize, Deserialize)]
pub enum MultisigResponse {
    /// Proposal created
    ProposalCreated { proposal_id: ProposalId },

    /// Operation successful
    Ok,

    /// Current state
    State {
        config: MultisigConfig,
        proposal_count: u64,
    },

    /// Error
    Error(String),
}

/// Cross-chain messages
#[derive(Debug, Clone, Serialize, Deserialize)]
pub enum MultisigMessage {
    /// Remote approval
    RemoteApproval {
        proposal_id: ProposalId,
        approver: AccountOwner,
    },

    /// Execute proposal
    Execute {
        proposal_id: ProposalId,
    },
}
```

---

## Contract Implementation

### Contract Structure

```rust
pub struct MultisigContract {
    state: MultisigState<ViewStorageContext>,
    runtime: ContractRuntime<Self>,
}

linera_sdk::contract!(MultisigContract);

impl WithContractAbi for MultisigContract {
    type Abi = MultisigAbi;
}
```

### Load and Store

```rust
impl Contract for MultisigContract {
    type Message = MultisigMessage;
    type Parameters = MultisigConfig;
    type InstantiationArgument = MultisigConfig;
    type EventValue = MultisigEvent;

    async fn load(runtime: ContractRuntime<Self>) -> Self {
        let state = MultisigState::load(runtime.root_view_storage_context())
            .await
            .expect("Failed to load state");
        MultisigContract { state, runtime }
    }

    async fn store(mut self) {
        self.state.save().await.expect("Failed to save state");
    }
}
```

### Instantiation

```rust
async fn instantiate(&mut self, config: Self::InstantiationArgument) {
    // Validate configuration
    assert!(
        config.threshold > 0,
        "Threshold must be greater than 0"
    );
    assert!(
        config.threshold <= config.owners.len() as u64,
        "Threshold cannot exceed number of owners"
    );
    assert!(
        !config.owners.is_empty(),
        "Must have at least one owner"
    );

    // Initialize state
    self.state.config.set(config);
    self.state.next_proposal_id.set(0);

    // Emit event
    self.runtime.emit("multisig_created", &MultisigEvent::Created {
        owners: config.owners.clone(),
        threshold: config.threshold,
    });
}
```

### Execute Operation

```rust
async fn execute_operation(&mut self, operation: Self::Operation) -> Self::Response {
    match operation {
        MultisigOperation::CreateProposal {
            description,
            operation,
            timelock,
        } => {
            let authenticated_owner = self.runtime.authenticated_owner()
                .expect("Operation must be authenticated");

            // Verify owner
            self.assert_is_owner(authenticated_owner).await;

            // Create proposal
            let proposal_id = self.create_proposal(
                authenticated_owner,
                description,
                operation,
                timelock,
            ).await;

            MultisigResponse::ProposalCreated { proposal_id }
        }

        MultisigOperation::Approve { proposal_id } => {
            let authenticated_owner = self.runtime.authenticated_owner()
                .expect("Operation must be authenticated");

            // Verify owner
            self.assert_is_owner(authenticated_owner).await;

            // Approve proposal
            self.approve_proposal(proposal_id, authenticated_owner).await;

            MultisigResponse::Ok
        }

        MultisigOperation::Revoke { proposal_id } => {
            let authenticated_owner = self.runtime.authenticated_owner()
                .expect("Operation must be authenticated");

            // Verify owner
            self.assert_is_owner(authenticated_owner).await;

            // Revoke approval
            self.revoke_approval(proposal_id, authenticated_owner).await;

            MultisigResponse::Ok
        }

        MultisigOperation::Execute { proposal_id } => {
            let authenticated_owner = self.runtime.authenticated_owner()
                .expect("Operation must be authenticated");

            // Verify owner (anyone can execute if threshold reached)
            self.assert_is_owner(authenticated_owner).await;

            // Execute proposal
            let success = self.execute_proposal(proposal_id, authenticated_owner).await;

            if success {
                MultisigResponse::Ok
            } else {
                MultisigResponse::Error("Execution failed".to_string())
            }
        }

        MultisigOperation::UpdateConfig { owners, threshold } => {
            let authenticated_owner = self.runtime.authenticated_owner()
                .expect("Operation must be authenticated");

            // Verify owner
            self.assert_is_owner(authenticated_owner).await;

            // Update config (requires full consensus)
            let config = self.state.config.get();
            let approvals = self.get_approval_count_for_config_update().await;

            if approvals >= config.owners.len() as u64 {
                self.update_configuration(owners, threshold).await;
                MultisigResponse::Ok
            } else {
                MultisigResponse::Error("Insufficient approvals for config update".to_string())
            }
        }

        MultisigOperation::GetState => {
            let config = self.state.config.get();
            let proposal_count = self.state.next_proposal_id.get();

            MultisigResponse::State {
                config,
                proposal_count,
            }
        }
    }
}
```

### Helper Methods

```rust
impl MultisigContract {
    /// Create a new proposal
    async fn create_proposal(
        &mut self,
        proposer: AccountOwner,
        description: String,
        operation: Vec<u8>,
        timelock: Option<u64>,
    ) -> ProposalId {
        let proposal_id = ProposalId(self.state.next_proposal_id.get());
        self.state.next_proposal_id.set(proposal_id.0 + 1);

        let config = self.state.config.get();
        let current_height = self.runtime.block_height();
        let current_time = self.runtime.system_time();

        let proposal = Proposal {
            id: proposal_id,
            operation,
            description,
            proposer,
            created_at: current_time.micros(),
            executable_at: timelock.map(|t| current_time.micros() + t * 1_000_000),
            status: ProposalStatus::Pending,
            expires_at: config.proposal_expiry.map(|e| current_height + e),
        };

        self.state.proposals.insert(&proposal_id, &proposal).await;

        // Auto-approve from proposer
        self.state.approvals
            .insert(&proposal_id, &SetView::new())
            .await;
        let mut approvals = self.state.approvals.get_mut(&proposal_id).await.unwrap();
        approvals.insert(&proposer).await;

        proposal_id
    }

    /// Approve a proposal
    async fn approve_proposal(&mut self, proposal_id: ProposalId, approver: AccountOwner) {
        let mut proposal = self.state.proposals.get_mut(&proposal_id).await
            .expect("Proposal not found");

        assert_eq!(proposal.status, ProposalStatus::Pending, "Proposal not pending");

        // Check expiry
        if let Some(expires_at) = proposal.expires_at {
            let current_height = self.runtime.block_height();
            assert!(current_height < expires_at, "Proposal expired");
        }

        // Add approval
        let mut approvals = self.state.approvals.get_mut(&proposal_id).await.unwrap();
        approvals.insert(&approver).await;

        // Check if threshold reached
        let config = self.state.config.get();
        let approval_count = self.count_approvals(&proposal_id).await;

        if approval_count >= config.threshold {
            proposal.status = ProposalStatus::Approved;
        }
    }

    /// Revoke an approval
    async fn revoke_approval(&mut self, proposal_id: ProposalId, revoker: AccountOwner) {
        let mut proposal = self.state.proposals.get_mut(&proposal_id).await
            .expect("Proposal not found");

        assert_eq!(proposal.status, ProposalStatus::Pending, "Cannot revoke approved proposal");

        let mut approvals = self.state.approvals.get_mut(&proposal_id).await.unwrap();
        approvals.remove(&revoker).await;
    }

    /// Execute a proposal
    async fn execute_proposal(&mut self, proposal_id: ProposalId, executor: AccountOwner) -> bool {
        let proposal = self.state.proposals.get(&proposal_id).await
            .expect("Proposal not found");

        // Check status
        assert_eq!(proposal.status, ProposalStatus::Approved, "Proposal not approved");

        // Check timelock
        if let Some(executable_at) = proposal.executable_at {
            let current_time = self.runtime.system_time().micros();
            assert!(current_time >= executable_at, "Timelock not expired");
        }

        // Check expiry
        if let Some(expires_at) = proposal.expires_at {
            let current_height = self.runtime.block_height();
            assert!(current_height < expires_at, "Proposal expired");
        }

        // Execute the operation
        // In a real implementation, you would deserialize and execute the operation
        let success = true; // Placeholder

        // Update state
        let mut proposal = self.state.proposals.get_mut(&proposal_id).await.unwrap();
        proposal.status = ProposalStatus::Executed;

        // Record execution
        let record = ExecutionRecord {
            proposal_id,
            executed_at: self.runtime.system_time().micros(),
            executor,
            success,
        };
        self.state.history.push(&record);

        success
    }

    /// Count approvals for a proposal
    async fn count_approvals(&self, proposal_id: &ProposalId) -> u64 {
        let approvals = self.state.approvals.get(proposal_id).await.unwrap();
        let mut count = 0;
        approvals.for_each_key(|_| {
            count += 1;
            Ok(())
        }).await.unwrap();
        count
    }

    /// Assert that an account is an owner
    async fn assert_is_owner(&self, owner: AccountOwner) {
        let config = self.state.config.get();
        assert!(config.owners.contains(&owner), "Not an owner");
    }

    /// Update configuration
    async fn update_configuration(&mut self, owners: Vec<AccountOwner>, threshold: u64) {
        let mut config = self.state.config.get();
        config.owners = owners;
        config.threshold = threshold;
        self.state.config.set(config);
    }
}
```

### Execute Message (Cross-Chain)

```rust
async fn execute_message(&mut self, message: Self::Message) {
    match message {
        MultisigMessage::RemoteApproval { proposal_id, approver } => {
            // Verify cross-chain authentication
            if self.runtime.authenticated_owner() == Some(approver) {
                self.approve_proposal(proposal_id, approver).await;
            }
        }

        MultisigMessage::Execute { proposal_id } => {
            let executor = self.runtime.authenticated_owner()
                .expect("Message must be authenticated");

            self.execute_proposal(proposal_id, executor).await;
        }
    }
}
```

---

## Service Implementation

```rust
pub struct MultisigService {
    state: MultisigState<ViewStorageContext>,
    runtime: ServiceRuntime<Self>,
}

linera_sdk::service!(MultisigService);

impl Service for MultisigService {
    type Parameters = MultisigConfig;

    async fn new(runtime: ServiceRuntime<Self>) -> Self {
        let state = MultisigState::load(runtime.root_view_storage_context())
            .await
            .expect("Failed to load state");
        MultisigService { state, runtime }
    }
}

/// Queries
#[derive(Debug, Clone, Serialize, Deserialize)]
pub enum MultisigQuery {
    GetProposal { proposal_id: ProposalId },
    ListProposals,
    GetConfig,
    GetApprovals { proposal_id: ProposalId },
}

/// Query responses
#[derive(Debug, Clone, Serialize, Deserialize)]
pub enum MultisigQueryResponse {
    Proposal(Option<Proposal>),
    Proposals(Vec<Proposal>),
    Config(MultisigConfig),
    Approvals(Vec<AccountOwner>),
}

impl Service for MultisigService {
    async fn handle_query(&self, query: Self::Query) -> Self::QueryResponse {
        match query {
            MultisigQuery::GetProposal { proposal_id } => {
                let proposal = self.state.proposals.get(&proposal_id).await.ok();
                MultisigQueryResponse::Proposal(proposal)
            }

            MultisigQuery::ListProposals => {
                let mut proposals = Vec::new();
                self.state.proposals.for_each_value(|proposal| {
                    proposals.push(proposal.clone());
                    Ok(())
                }).await.unwrap();
                MultisigQueryResponse::Proposals(proposals)
            }

            MultisigQuery::GetConfig => {
                let config = self.state.config.get();
                MultisigQueryResponse::Config(config)
            }

            MultisigQuery::GetApprovals { proposal_id } => {
                let mut owners = Vec::new();
                if let Some(approvals) = self.state.approvals.get(&proposal_id).await.ok() {
                    approvals.for_each_key(|owner| {
                        owners.push(owner.clone());
                        Ok(())
                    }).await.unwrap();
                }
                MultisigQueryResponse::Approvals(owners)
            }
        }
    }
}
```

---

## Cross-Chain Patterns

### Remote Approval Pattern

```rust
/// Approve a proposal from another chain
async fn approve_remote_proposal(
    &mut self,
    proposal_id: ProposalId,
    target_chain: ChainId,
) {
    let approver = self.runtime.authenticated_owner().unwrap();

    // Send approval message to multisig chain
    self.runtime
        .prepare_message(MultisigMessage::RemoteApproval {
            proposal_id,
            approver,
        })
        .with_authentication()
        .send_to(target_chain);
}
```

### Cross-Chain Execution Pattern

```rust
/// Execute a proposal from another chain
async fn execute_cross_chain(
    &mut self,
    proposal_id: ProposalId,
    multisig_chain: ChainId,
) {
    let executor = self.runtime.authenticated_owner().unwrap();

    // Send execution message
    self.runtime
        .prepare_message(MultisigMessage::Execute { proposal_id })
        .with_authentication()
        .send_to(multisig_chain);
}
```

---

## Testing Patterns

### Unit Testing

```rust
#[cfg(test)]
mod tests {
    use super::*;
    use linera_sdk::test::MockContractRuntime;

    #[tokio::test]
    async fn test_create_proposal() {
        let runtime = MockContractRuntime::new();
        let mut contract = MultisigContract::load(runtime).await;

        // Instantiate
        let config = MultisigConfig {
            owners: vec![owner1, owner2, owner3],
            threshold: 2,
            timelock: None,
            proposal_expiry: Some(1000),
        };
        contract.instantiate(config.clone()).await;

        // Create proposal
        let response = contract.execute_operation(
            MultisigOperation::CreateProposal {
                description: "Test proposal".to_string(),
                operation: vec![1, 2, 3],
                timelock: None,
            }
        ).await;

        assert!(matches!(response, MultisigResponse::ProposalCreated { .. }));
    }

    #[tokio::test]
    async fn test_threshold_execution() {
        // Test 2-of-3 multisig
        // ...
    }
}
```

---

## Deployment Patterns

### Creating a Multisig Chain

```bash
# Create a 3-of-5 multisig chain
linera open-multi-owner-chain \
    --from $PARENT_CHAIN \
    --owners OWNER1,OWNER2,OWNER3,OWNER4,OWNER5 \
    --initial-balance 1000

# Publish the multisig application
linera publish \
    --contract contract.wasm \
    --service service.wasm \
    --parameters "$CONFIG"

# Create the application
linera create-application \
    --module-id $MODULE_ID \
    --argument "$INIT_CONFIG"
```

### Deploying with TypeScript SDK

```typescript
import { LineraClient } from '@linera/client';

const client = new LineraClient({ url: 'http://localhost:8080' });

// Publish multisig application
const module = await client.publishModule({
    contract: contractWasm,
    service: serviceWasm,
});

// Create application
const config = {
    owners: [owner1, owner2, owner3],
    threshold: 2,
    timelock: null,
    proposalExpiry: 1000,
};

const app = await client.createApplication({
    moduleId: module.id,
    parameters: config,
    argument: config,
});

// Create proposal
const proposal = await client.queryApplication(app.id, {
    operation: 'CREATE_PROPOSAL',
    description: 'Transfer tokens',
    operation: encodedTransfer,
});
```

---

## Conclusion

This implementation guide provides a complete foundation for building a multisig platform on Linera. The key advantages are:

1. **Native multi-owner support** for chain-level multisig
2. **Flexible application-level multisig** for custom logic
3. **Cross-chain messaging** for remote approvals
4. **Rich state management** through views
5. **Type-safe operations** through Rust's type system

The implementation is production-ready and can be extended with additional features like:
- Time-locks
- Proposal expiry
- Config updates
- Event streams for off-chain indexing
- GraphQL queries for rich UI integration
