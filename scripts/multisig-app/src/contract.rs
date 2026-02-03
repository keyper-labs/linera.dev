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
