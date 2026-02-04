// Operaciones simplificadas para evitar opcode 252
// Solo una operación principal: ExecuteWithThresholdSignature

use serde::{Deserialize, Serialize};
use linera_views::types::Owner;

/// Operación principal del contrato
/// En lugar de Proposal + Approvals, usamos threshold signatures
#[derive(Debug, Clone, Serialize, Deserialize)]
pub enum MultisigOperation {
    /// Ejecutar transacción con firma threshold
    /// La firma threshold se genera off-chain cuando m owners firman
    ExecuteWithThresholdSignature {
        /// Destinatario de la transferencia
        to: Owner,
        /// Monto a transferir
        amount: u64,
        /// Nonce para evitar replay attacks
        nonce: u64,
        /// Firma threshold (agregada off-chain)
        /// Contiene las firmas de m owners agrupadas
        threshold_signature: Vec<u8>,
        /// Mensaje que fue firmado (para verificación)
        message: Vec<u8>,
    },

    /// Cambiar configuración (requiere threshold signature)
    /// Opcional: permite cambiar owners/threshold
    ChangeConfig {
        /// Nuevos owners
        new_owners: Vec<Owner>,
        /// Nuevo threshold
        new_threshold: u64,
        /// Nueva clave pública agregada
        new_aggregate_key: Vec<u8>,
        /// Nonce
        nonce: u64,
        /// Firma threshold de la configuración actual
        threshold_signature: Vec<u8>,
    },
}

/// Mensaje que los owners firman off-chain
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ThresholdMessage {
    /// Nonce actual del contrato
    pub nonce: u64,

    /// Tipo de operación
    pub operation_type: String,

    /// Datos de la operación
    pub operation_data: Vec<u8>,
}

impl ThresholdMessage {
    /// Crear mensaje para transferencia
    pub fn transfer(nonce: u64, to: &Owner, amount: u64) -> Self {
        Self {
            nonce,
            operation_type: "transfer".to_string(),
            operation_data: format!("{}:{}", to.to_string(), amount).into_bytes(),
        }
    }

    /// Crear mensaje para cambio de configuración
    pub fn config_change(nonce: u64, owners: &[Owner], threshold: u64) -> Self {
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

    /// Serializar mensaje para firmar
    pub fn to_bytes(&self) -> Vec<u8> {
        // Serialización simple para evitar operaciones complejas
        let mut bytes = Vec::new();
        bytes.extend_from_slice(&self.nonce.to_be_bytes());
        bytes.extend_from_slice(self.operation_type.as_bytes());
        bytes.extend_from_slice(&(self.operation_data.len() as u64).to_be_bytes());
        bytes.extend_from_slice(&self.operation_data);
        bytes
    }
}
