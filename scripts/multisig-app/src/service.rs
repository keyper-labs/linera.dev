use linera_sdk::{
    base::Owner,
    contract::Contract,
    graphql::GraphQLMutationRoot,
    service::Service,
    views::MapView,
    ApplicationCallResult, ServiceRuntime, KeyValueStore, Resources,
};
use serde::{Deserialize, Serialize};

// Re-use contract types
use crate::contract::{MultisigState, PendingTransaction};

/// Queries for the multisig service
#[derive(Debug, Serialize, Deserialize, GraphQLMutationRoot)]
pub enum Query {
    /// Get the list of owners
    Owners,
    /// Get the current threshold
    Threshold,
    /// Get a pending transaction by ID
    Transaction {
        id: u64,
    },
    /// Get all pending transactions
    PendingTransactions,
    /// Check if an owner has approved a transaction
    HasApproved {
        transaction_id: u64,
        owner: Owner,
    },
}

/// Multisig service
pub struct MultisigService {
    runtime: ServiceRuntime<Self>,
    state: MultisigState,
}

impl Service for MultisigService {
    type Runtime = ServiceRuntime<Self>;
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

    fn handle_query(&mut self, query: Query) -> ApplicationCallResult {
        match query {
            Query::Owners => {
                let owners = self.state.owners.clone();
                let json = serde_json::to_string(&owners)?;
                self.runtime.result(json.as_bytes().to_vec())
            }
            Query::Threshold => {
                let threshold = self.state.threshold;
                let json = serde_json::to_string(&threshold)?;
                self.runtime.result(json.as_bytes().to_vec())
            }
            Query::Transaction { id } => {
                let key = format!("tx_{}", id).into_bytes();
                let transaction = self.state.pending_transactions.get(&key)?;
                let json = serde_json::to_string(&transaction)?;
                self.runtime.result(json.as_bytes().to_vec())
            }
            Query::PendingTransactions => {
                let mut transactions = Vec::new();
                for key in self.state.pending_transactions.keys()? {
                    if let Ok(tx) = self.state.pending_transactions.get(&key) {
                        transactions.push(tx);
                    }
                }
                let json = serde_json::to_string(&transactions)?;
                self.runtime.result(json.as_bytes().to_vec())
            }
            Query::HasApproved { transaction_id, owner } => {
                let key = format!("tx_{}", transaction_id).into_bytes();
                let transaction = self.state.pending_transactions.get(&key)?;
                let has_approved = transaction.map_or(false, |tx| tx.approvals.contains(&owner));
                let json = serde_json::to_string(&has_approved)?;
                self.runtime.result(json.as_bytes().to_vec())
            }
        }
    }
}
