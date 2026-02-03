#![cfg_attr(target_arch = "wasm32", no_main)]

use linera_sdk::{
    Contract, ContractRuntime,
    linera_base_types::{AccountOwner, Amount, ChainId},
};
use linera_views::{RootView, View, ViewStorageContext};
use serde::{Deserialize, Serialize};

/// Multisig application state
#[derive(RootView)]
pub struct MultisigState {
    /// List of owners who can approve transactions
    pub owners: Vec<AccountOwner>,
    /// Number of approvals required to execute a transaction
    pub threshold: usize,
    /// Counter for generating unique proposal IDs
    pub next_proposal_id: u64,
}

/// Multisig operations
#[derive(Debug, Clone, Serialize, Deserialize)]
pub enum Operation {
    /// Initialize the multisig with owners and threshold
    Init {
        owners: Vec<AccountOwner>,
        threshold: usize,
    },
    /// Propose a new transaction
    Propose {
        target: ChainId,
        amount: Amount,
    },
}

/// Multisig contract
pub struct MultisigContract {
    runtime: ContractRuntime<Self>,
}

impl Contract for MultisigContract {
    type Message = ();
    type Parameters = ();
    type InstantiationArgument = Vec<AccountOwner>;
    type EventValue = ();
    type Response = ();

    async fn load(runtime: ContractRuntime<Self>) -> Self {
        Self { runtime }
    }

    async fn instantiate(&mut self, owners: Vec<AccountOwner>) {
        self.runtime.initialize_state(MultisigState {
            owners,
            threshold: owners.len(),
            next_proposal_id: 0,
        });
    }

    async fn execute_operation(&mut self, operation: Operation) {
        match operation {
            Operation::Init { owners, threshold } => {
                self.runtime.initialize_state(MultisigState {
                    owners,
                    threshold,
                    next_proposal_id: 0,
                });
            }
            Operation::Propose { target, amount } => {
                let caller = self.runtime.authenticated_signer().unwrap();
                // Simple proposal logic - in real multisig this would be more complex
                // For now, just log the proposal
                log::info!("Proposal from {:?} to send {:?} to {:?}", caller, amount, target);
            }
        }
    }

    async fn execute_message(&mut self, _message: ()) {}

    async fn store(self) {}
}

// Required export for Wasm
linera_sdk::contract!(MultisigContract);
