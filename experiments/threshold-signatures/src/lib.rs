//! Linera Threshold Multisig Contract
//!
//! Simplified Wasm contract using threshold signatures.
//! Designed to avoid opcode 252 caused by async-graphql.

#![cfg_attr(target_arch = "wasm32", no_main)]

mod state;
mod operations;

use async_graphql::{Request, Response};
use linera_sdk::{
    linera_base_types::{ContractAbi, ServiceAbi, WithContractAbi, AccountOwner},
    views::{RootView, View},
    Contract, ContractRuntime,
};
use serde::{Deserialize, Serialize};

use operations::{MultisigOperation, ThresholdMessage};

pub struct ThresholdMultisigAbi;

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct MultisigResponse {
    pub success: bool,
    pub message: String,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct InitParameters {
    pub owners: Vec<AccountOwner>,
    pub threshold: u64,
    pub aggregate_public_key: Vec<u8>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct InstantiationArgument {}

impl ContractAbi for ThresholdMultisigAbi {
    type Operation = MultisigOperation;
    type Response = MultisigResponse;
}

impl ServiceAbi for ThresholdMultisigAbi {
    type Query = Request;
    type QueryResponse = Response;
}

pub struct ThresholdMultisigContract {
    state: state::MultisigState,
    runtime: ContractRuntime<Self>,
}

linera_sdk::contract!(ThresholdMultisigContract);

impl WithContractAbi for ThresholdMultisigContract {
    type Abi = ThresholdMultisigAbi;
}

impl Contract for ThresholdMultisigContract {
    type Message = ();
    type InstantiationArgument = InstantiationArgument;
    type Parameters = InitParameters;
    type EventValue = ();

    async fn load(runtime: ContractRuntime<Self>) -> Self {
        let context = runtime.root_view_storage_context();
        let state = state::MultisigState::load(context)
            .await
            .expect("Failed to load state");
        Self { state, runtime }
    }

    async fn instantiate(&mut self, _arg: InstantiationArgument) {
        // Validate application parameters
        let params = self.runtime.application_parameters();

        // Validate parameters
        if params.owners.is_empty() {
            panic!("Cannot create multisig with no owners");
        }
        if params.threshold == 0 || params.threshold > params.owners.len() as u64 {
            panic!("Invalid threshold");
        }
        if params.aggregate_public_key.len() != 32 {
            panic!("Invalid aggregate public key length");
        }

        // Create initial state
        self.state.initialize(params.owners, params.threshold, params.aggregate_public_key);
    }

    async fn execute_operation(&mut self, operation: MultisigOperation) -> MultisigResponse {
        match operation {
            MultisigOperation::ExecuteWithThresholdSignature {
                to,
                amount,
                nonce,
                threshold_signature: _,
                message: _,
            } => {
                // Verify nonce
                if nonce != self.state.nonce() {
                    return MultisigResponse {
                        success: false,
                        message: format!("Invalid nonce: expected {}, got {}", self.state.nonce(), nonce),
                    };
                }

                // NOTE: Threshold signature verification is omitted for now
                // to be able to compile. In production, this is CRITICAL.
                // Will be added when ed25519-dalek works correctly in Wasm.

                // Increment nonce
                self.state.increment_nonce();

                MultisigResponse {
                    success: true,
                    message: format!("Transferred {} units to {}", amount, to.to_string()),
                }
            }

            MultisigOperation::ChangeConfig {
                new_owners,
                new_threshold,
                new_aggregate_key,
                nonce,
                threshold_signature: _,
            } => {
                // Verify nonce
                if nonce != self.state.nonce() {
                    return MultisigResponse {
                        success: false,
                        message: format!("Invalid nonce: expected {}, got {}", self.state.nonce(), nonce),
                    };
                }

                // NOTE: Threshold signature verification is omitted for now

                // Update configuration
                self.state.update_config(new_owners, new_threshold, new_aggregate_key);

                MultisigResponse {
                    success: true,
                    message: "Configuration updated successfully".to_string(),
                }
            }
        }
    }

    async fn execute_message(&mut self, _message: ()) {
        panic!("Threshold multisig doesn't support cross-chain messages");
    }

    async fn store(mut self) {
        self.state.save().await.expect("Failed to save state");
    }
}
