//! Linera Threshold Multisig Contract
//!
//! Contrato Wasm simplificado que usa threshold signatures en lugar de proposal state machine.
//! Diseñado para evitar opcode 252 causado por async-graphql y operaciones complejas.
//!
//! ## Arquitectura Self-Custodial
//!
//! - Private keys: Frontend (nunca salen del navegador)
//! - Backend: Solo transmite operaciones firmadas
//! - Wasm Contract: Verifica threshold signatures on-chain
//!
//! ## Flujo
//!
//! 1. Owners firman mensaje off-chain (en frontend)
//! 2. Cuando se alcanza threshold, se agrega firma threshold
//! 3. Backend transmite operación con firma threshold
//! 4. Wasm contract verifica firma criptográficamente
//! 5. Si válida, ejecuta transferencia

pub mod state;
pub mod operations;

use linera_sdk::{
    Contract, ContractRuntime, LogLevel,
    ViewStorageContext,
};
use state::MultisigState;
use operations::{MultisigOperation, ThresholdMessage};
use ed25519_dalek::{Verifier, PublicKey, Signature};
use linera_views::types::Owner;

/// Estructura principal del contrato
pub struct ThresholdMultisigContract {
    runtime: ContractRuntime<Self>,
    state: MultisigState,
}

/// Mensaje del contrato
#[derive(Debug, Clone, serde::Serialize, serde::Deserialize)]
pub enum Message {
    /// Mensaje vacío - no usamos cross-chain messaging en esta versión
    Empty,
}

/// Parámetros de inicialización
#[derive(Debug, Clone, serde::Serialize, serde::Deserialize)]
pub struct InitParameters {
    pub owners: Vec<Owner>,
    pub threshold: u64,
    pub aggregate_public_key: Vec<u8>,
}

/// Parámetros de la instancia
#[derive(Debug, Clone, serde::Serialize, serde::Deserialize)]
pub struct InstantiationArgument {}

impl Contract for ThresholdMultisigContract {
    type Message = Message;
    type InstantiationArgument = InstantiationArgument;
    type Parameters = InitParameters;

    async fn load(runtime: ContractRuntime<Self>) -> Self {
        // Cargar o crear estado inicial
        let state = MultisigState::load(runtime.storage())
            .await
            .unwrap_or_else(|_| {
                // Si no existe, crear estado por defecto
                // Nota: Esto solo se usa en tests, el real se crea en initialize
                MultisigState::new(Vec::new(), 1, Vec::new())
            });

        Self { runtime, state }
    }

    async fn initialize(&mut self, params: InitParameters) {
        // Crear estado inicial con los parámetros
        self.state = MultisigState::new(
            params.owners,
            params.threshold,
            params.aggregate_public_key,
        );

        self.runtime.log(LogLevel::Info, "Threshold multisig contract initialized");
    }

    async fn execute_operation(&mut self, operation: MultisigOperation) {
        match operation {
            MultisigOperation::ExecuteWithThresholdSignature {
                to,
                amount,
                nonce,
                threshold_signature,
                message,
            } => {
                self.runtime.log(LogLevel::Info, "Executing threshold signature operation");

                // 1. Verificar nonce (replay protection)
                if nonce != self.state.nonce() {
                    self.runtime.log(
                        LogLevel::Error,
                        &format!("Invalid nonce: expected {}, got {}", self.state.nonce(), nonce)
                    );
                    return;
                }

                // 2. Verificar threshold signature
                let is_valid = self.verify_threshold_signature(&message, &threshold_signature);

                if !is_valid {
                    self.runtime.log(LogLevel::Error, "Invalid threshold signature");
                    return;
                }

                // 3. Ejecutar transferencia
                self.runtime.transfer(
                    self.runtime.authenticated_signer().unwrap(),
                    to,
                    amount
                ).expect("Transfer failed");

                // 4. Incrementar nonce
                self.state.increment_nonce();

                self.runtime.log(
                    LogLevel::Info,
                    &format!("Transferred {} units to {}", amount, to)
                );
            }

            MultisigOperation::ChangeConfig {
                new_owners,
                new_threshold,
                new_aggregate_key,
                nonce,
                threshold_signature,
            } => {
                self.runtime.log(LogLevel::Info, "Executing config change operation");

                // 1. Verificar nonce
                if nonce != self.state.nonce() {
                    self.runtime.log(
                        LogLevel::Error,
                        &format!("Invalid nonce: expected {}, got {}", self.state.nonce(), nonce)
                    );
                    return;
                }

                // 2. Verificar threshold signature
                let message_data = ThresholdMessage::config_change(
                    nonce,
                    &new_owners,
                    new_threshold
                ).to_bytes();

                let is_valid = self.verify_threshold_signature(&message_data, &threshold_signature);

                if !is_valid {
                    self.runtime.log(LogLevel::Error, "Invalid threshold signature for config change");
                    return;
                }

                // 3. Actualizar configuración
                *self.state.owners.get_mut() = new_owners;
                *self.state.threshold.get_mut() = new_threshold;
                *self.state.aggregate_public_key.get_mut() = new_aggregate_key;
                self.state.increment_nonce();

                self.runtime.log(LogLevel::Info, "Configuration updated successfully");
            }
        }
    }

    async fn execute_message(&mut self, _context: (), _message: Self::Message) {
        // No implementamos cross-chain messaging en esta versión simplificada
    }

    fn runtime(&self) -> &ContractRuntime<Self> {
        &self.runtime
    }
}

impl ThresholdMultisigContract {
    /// Verificar una firma threshold usando Ed25519
    ///
    /// NOTA: Esta es una implementación simplificada.
    /// En producción, necesitarías usar un esquema real de threshold signatures
    /// como FROST (Frost Robust Threshold Schnorr) o similar.
    fn verify_threshold_signature(&self, message: &[u8], signature: &[u8]) -> bool {
        // En un sistema real de threshold signatures:
        // 1. La aggregate_public_key se genera durante la setup phase
        // 2. Cada owner tiene su share de la private key
        // 3. Los owners colaboran para generar la firma threshold
        // 4. Cualquiera puede verificar con la aggregate_public_key

        // Para este experimento, usamos Ed25519 estándar como placeholder
        let public_key_bytes = self.state.aggregate_public_key.get();

        if public_key_bytes.len() != 32 {
            self.runtime.log(LogLevel::Error, "Invalid public key length");
            return false;
        }

        // Intentar parsear la public key
        let public_key = match PublicKey::from_bytes(&public_key_bytes[..32]) {
            Ok(key) => key,
            Err(e) => {
                self.runtime.log(
                    LogLevel::Error,
                    &format!("Failed to parse public key: {}", e)
                );
                return false;
            }
        };

        // Intentar parsear la firma
        let signature_obj = match Signature::from_bytes(signature) {
            Ok(sig) => sig,
            Err(e) => {
                self.runtime.log(
                    LogLevel::Error,
                    &format!("Failed to parse signature: {}", e)
                );
                return false;
            }
        };

        // Verificar la firma
        match public_key.verify(message, &signature_obj) {
            Ok(()) => true,
            Err(e) => {
                self.runtime.log(
                    LogLevel::Error,
                    &format!("Signature verification failed: {}", e)
                );
                false
            }
        }
    }
}
