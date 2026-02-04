// Simplified state to avoid opcode 252

use linera_sdk::{
    linera_base_types::AccountOwner,
    views::{RegisterView, RootView, ViewStorageContext},
};

/// Main contract state structure
#[derive(RootView)]
#[view(context = ViewStorageContext)]
pub struct MultisigState {
    /// List of owners (public addresses)
    pub owners: RegisterView<Vec<AccountOwner>>,

    /// Required threshold (m-of-n)
    pub threshold: RegisterView<u64>,

    /// Contract public key for verifying threshold signatures
    pub aggregate_public_key: RegisterView<Vec<u8>>,

    /// Counter for nonce (prevents replay attacks)
    pub nonce: RegisterView<u64>,
}

impl MultisigState {
    /// Initialize state with parameters
    pub fn initialize(&mut self, owners: Vec<AccountOwner>, threshold: u64, aggregate_key: Vec<u8>) {
        self.owners.set(owners);
        self.threshold.set(threshold);
        self.aggregate_public_key.set(aggregate_key);
        self.nonce.set(0);
    }

    /// Update configuration
    pub fn update_config(&mut self, owners: Vec<AccountOwner>, threshold: u64, aggregate_key: Vec<u8>) {
        self.owners.set(owners);
        self.threshold.set(threshold);
        self.aggregate_public_key.set(aggregate_key);
        self.increment_nonce();
    }

    /// Get aggregate public key
    pub fn aggregate_public_key(&self) -> Vec<u8> {
        self.aggregate_public_key.get().clone()
    }

    /// Get current nonce
    pub fn nonce(&self) -> u64 {
        *self.nonce.get()
    }

    /// Increment nonce
    pub fn increment_nonce(&mut self) {
        let current = *self.nonce.get();
        self.nonce.set(current + 1);
    }

    /// Verify if an address is an owner
    pub fn is_owner(&self, address: &AccountOwner) -> bool {
        self.owners.get().contains(address)
    }

    /// Get current threshold
    pub fn threshold(&self) -> u64 {
        *self.threshold.get()
    }
}
