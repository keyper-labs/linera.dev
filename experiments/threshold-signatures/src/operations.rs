// Simplified operations to avoid opcode 252
// Only one main operation: ExecuteWithThresholdSignature

use serde::{Deserialize, Serialize};
use linera_sdk::linera_base_types::AccountOwner;

/// Main contract operation
/// Instead of Proposal + Approvals, we use threshold signatures
#[derive(Debug, Clone, Serialize, Deserialize)]
pub enum MultisigOperation {
    /// Execute transaction with threshold signature
    /// The threshold signature is generated off-chain when m owners sign
    ExecuteWithThresholdSignature {
        /// Transfer recipient
        to: AccountOwner,
        /// Amount to transfer
        amount: u64,
        /// Nonce to prevent replay attacks
        nonce: u64,
        /// Threshold signature (aggregated off-chain)
        /// Contains signatures from m owners grouped together
        threshold_signature: Vec<u8>,
        /// Message that was signed (for verification)
        message: Vec<u8>,
    },

    /// Change configuration (requires threshold signature)
    /// Optional: allows changing owners/threshold
    ChangeConfig {
        /// New owners
        new_owners: Vec<AccountOwner>,
        /// New threshold
        new_threshold: u64,
        /// New aggregate public key
        new_aggregate_key: Vec<u8>,
        /// Nonce
        nonce: u64,
        /// Threshold signature of current configuration
        threshold_signature: Vec<u8>,
    },
}

/// Message that owners sign off-chain
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ThresholdMessage {
    /// Current contract nonce
    pub nonce: u64,

    /// Operation type
    pub operation_type: String,

    /// Operation data
    pub operation_data: Vec<u8>,
}

impl ThresholdMessage {
    /// Create message for transfer
    pub fn transfer(nonce: u64, to: &AccountOwner, amount: u64) -> Self {
        Self {
            nonce,
            operation_type: "transfer".to_string(),
            operation_data: format!("{}:{}", to.to_string(), amount).into_bytes(),
        }
    }

    /// Create message for configuration change
    pub fn config_change(nonce: u64, owners: &[&AccountOwner], threshold: u64) -> Self {
        let owners_str = owners.iter()
            .map(|o| o.to_string())
            .collect::<Vec<_>>()
            .join(",");

        Self {
            nonce,
            operation_type: "config_change".to_string(),
            operation_data: format!("{}:{}", owners_str, threshold).into_bytes(),
        }
    }

    /// Serialize message for signing
    pub fn to_bytes(&self) -> Vec<u8> {
        // Simple serialization to avoid complex operations
        let mut bytes = Vec::new();
        bytes.extend_from_slice(&self.nonce.to_be_bytes());
        bytes.extend_from_slice(self.operation_type.as_bytes());
        bytes.extend_from_slice(&(self.operation_data.len() as u64).to_be_bytes());
        bytes.extend_from_slice(&self.operation_data);
        bytes
    }
}
