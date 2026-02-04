// Estado simplificado para evitar opcode 252
// NO contiene proposal history, solo información esencial

use linera_views::{views::View, types::Owner, register::RegisterView};
use serde::{Deserialize, Serialize};

/// Estructura principal del estado del contrato
/// Simplificada al mínimo para evitar operaciones complejas de Wasm
#[derive(View, Debug, Clone, Serialize, Deserialize)]
pub struct MultisigState {
    /// Lista de owners (direcciones públicas)
    pub owners: RegisterView<Vec<Owner>>,

    /// Threshold requerido (m-of-n)
    pub threshold: RegisterView<u64>,

    /// Public key del contrato para verificar threshold signatures
    /// Esta es la clave agregada de todos los owners
    pub aggregate_public_key: RegisterView<Vec<u8>>,

    /// Counter para nonce (evita replay attacks)
    pub nonce: RegisterView<u64>,
}

impl MultisigState {
    /// Crear nuevo estado de multisig
    pub fn new(owners: Vec<Owner>, threshold: u64, aggregate_key: Vec<u8>) -> Self {
        Self {
            owners: RegisterView::new(owners),
            threshold: RegisterView::new(threshold),
            aggregate_public_key: RegisterView::new(aggregate_key),
            nonce: RegisterView::new(0),
        }
    }

    /// Verificar si una address es owner
    pub fn is_owner(&self, address: &Owner) -> bool {
        self.owners.get().contains(address)
    }

    /// Obtener threshold actual
    pub fn threshold(&self) -> u64 {
        *self.threshold.get()
    }

    /// Incrementar nonce
    pub fn increment_nonce(&mut self) {
        let current = *self.nonce.get();
        self.nonce.set(current + 1);
    }

    /// Obtener nonce actual
    pub fn nonce(&self) -> u64 {
        *self.nonce.get()
    }
}
