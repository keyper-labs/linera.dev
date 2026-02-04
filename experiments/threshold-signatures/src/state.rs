// Estado simplificado para evitar opcode 252

use linera_sdk::{
    linera_base_types::AccountOwner,
    views::{RegisterView, RootView, ViewStorageContext},
};

/// Estructura principal del estado del contrato
#[derive(RootView)]
#[view(context = ViewStorageContext)]
pub struct MultisigState {
    /// Lista de owners (direcciones públicas)
    pub owners: RegisterView<Vec<AccountOwner>>,

    /// Threshold requerido (m-of-n)
    pub threshold: RegisterView<u64>,

    /// Public key del contrato para verificar threshold signatures
    pub aggregate_public_key: RegisterView<Vec<u8>>,

    /// Counter para nonce (evita replay attacks)
    pub nonce: RegisterView<u64>,
}

impl MultisigState {
    /// Inicializar el estado con los parámetros
    pub fn initialize(&mut self, owners: Vec<AccountOwner>, threshold: u64, aggregate_key: Vec<u8>) {
        self.owners.set(owners);
        self.threshold.set(threshold);
        self.aggregate_public_key.set(aggregate_key);
        self.nonce.set(0);
    }

    /// Actualizar configuración
    pub fn update_config(&mut self, owners: Vec<AccountOwner>, threshold: u64, aggregate_key: Vec<u8>) {
        self.owners.set(owners);
        self.threshold.set(threshold);
        self.aggregate_public_key.set(aggregate_key);
        self.increment_nonce();
    }

    /// Obtener aggregate public key
    pub fn aggregate_public_key(&self) -> Vec<u8> {
        self.aggregate_public_key.get().clone()
    }

    /// Obtener nonce actual
    pub fn nonce(&self) -> u64 {
        *self.nonce.get()
    }

    /// Incrementar nonce
    pub fn increment_nonce(&mut self) {
        let current = *self.nonce.get();
        self.nonce.set(current + 1);
    }

    /// Verificar si una address es owner
    pub fn is_owner(&self, address: &AccountOwner) -> bool {
        self.owners.get().contains(address)
    }

    /// Obtener threshold actual
    pub fn threshold(&self) -> u64 {
        *self.threshold.get()
    }
}
