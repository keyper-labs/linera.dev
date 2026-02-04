# Arquitectura Detallada: Threshold Signatures Multisig

Este documento explica la arquitectura técnica del sistema de threshold signatures para Linera multisig.

---

## Tabla de Contenidos

1. [Conceptos Fundamentales](#conceptos-fundamentales)
2. [Arquitectura del Sistema](#arquitectura-del-sistema)
3. [Flujo Completo](#flujo-completo)
4. [Especificaciones Técnicas](#especificaciones-técnicas)
5. [Implementación FROST](#implementación-frost)
6. [Seguridad y Validación](#seguridad-y-validación)

---

## Conceptos Fundamentales

### ¿Qué es una Threshold Signature?

Una **threshold signature** es una firma criptográfica que requiere que **m** de **n** participantes colaboren para producir una firma válida, pero que **se verifica como una sola firma**.

```
Firma Tradicional (Multisig Bitcoin):
- Cada owner firma individualmente: σ₁, σ₂, σ₃
- On-chain se verifican TODAS las firmas
- Costo de gas: Crece con número de firmas

Threshold Signature (FROST):
- Owners colaboran offline: σ₁, σ₂, σ₃ → σ_threshold
- On-chain se verifica UNA sola firma
- Costo de gas: Constante (como una sola firma)
```

### Ventajas Clave

| Aspecto | Multisig Tradicional | Threshold Signatures |
|---------|---------------------|---------------------|
| **Tamaño de firma** | O(m) firmas individuales | O(1) firma agregada |
| **Costo verificación** | O(m) verificaciones | O(1) verificación |
| **Privacidad** | Revela quién firmó | No revela signers |
| **Escalabilidad** | Empeora con más owners | Constante |

---

## Arquitectura del Sistema

### Componentes

```
┌─────────────────────────────────────────────────────────────────┐
│                      Frontend Layer                             │
│  ┌────────────────┐  ┌────────────────┐  ┌────────────────┐   │
│  │  Owner 1 App   │  │  Owner 2 App   │  │  Owner 3 App   │   │
│  │                │  │                │  │                │   │
│  │  Private Key 1 │  │  Private Key 2 │  │  Private Key 3 │   │
│  │  Key Share 1   │  │  Key Share 2   │  │  Key Share 3   │   │
│  └────────────────┘  └────────────────┘  └────────────────┘   │
└─────────────────────────────────────────────────────────────────┘
                              ↓
                    [Coordination Protocol]
                              ↓
┌─────────────────────────────────────────────────────────────────┐
│                      Backend Layer                              │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │  REST API + WebSocket                                   │   │
│  │  - Propuesta de transacción                            │   │
│  │  - Coordinación de firmas                              │   │
│  │  - Agregación de firmas (threshold)                    │   │
│  │  - Transmisión a Linera                                │   │
│  └─────────────────────────────────────────────────────────┘   │
│                     ↓ NO private keys                          │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │  PostgreSQL + Redis                                     │   │
│  │  - Propuestas pendientes                               │   │
│  │  - Estado de firmas                                    │   │
│  │  - Nonces                                              │   │
│  └─────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────────┐
│                    Linera Network                               │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │  ThresholdMultisigContract (Wasm)                       │   │
│  │  - Verifica threshold signature                        │   │
│  │  - Ejecuta transfer                                    │   │
│  │  - Mantiene nonce                                      │   │
│  └─────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────┘
```

### Self-Custodia Explícita

```typescript
// ❌ LO QUE EL BACKEND NO TIENE:
interface BackendState {
  // NO tiene private keys
  privateKeys: Map<UserId, Uint8Array]; // ❌ NUNCA

  // NO tiene key shares de FROST
  keyShares: Map<UserId, FrostShare>; // ❌ NUNCA

  // NO puede firmar por usuarios
  signingService: ThresholdSigning; // ❌ NUNCA
}

// ✅ LO QUE EL BACKEND SÍ TIENE:
interface BackendState {
  // Solo metadata de propuestas
  proposals: Map<ProposalId, {
    id: string;
    creator: string; // Solo public address
    created_at: Date;
    threshold_signatures: SignatureShare[]; // Solo shares públicas
    is_complete: boolean;
  }>;

  // Coordinación, no custodia
  websocket: WebSocket; // Para coordinar signers
}
```

---

## Flujo Completo

### Fase 1: Setup (DKG - Distributed Key Generation)

Antes de crear el multisig, los owners ejecutan una fase de setup cooperativa:

```typescript
// Paso 1: Cada owner genera su key share
// Owner 1:
const share1 = Frost.generateKeyShare();
// -> { secret_share: s1, public_share: P1 }

// Owner 2:
const share2 = Frost.generateKeyShare();
// -> { secret_share: s2, public_share: P2 }

// Owner 3:
const share3 = Frost.generateKeyShare();
// -> { secret_share: s3, public_share: P3 }

// Paso 2: Cada owner comparte su public_share con los demás
// Esto se puede hacer off-band (email, messaging, etc.)

// Paso 3: Cada owner calcula la aggregate public key
const aggregatePublicKey = share1.public_share
  .add(share2.public_share)
  .add(share3.public_share);

// NOTA: La aggregate public key es la misma para todos los owners
// Esta es la key que se usará en el contrato Wasm
```

### Fase 2: Crear Multisig

```typescript
// Cualquier owner (o todos coordinados) crea el contrato
const params = {
  owners: [address1, address2, address3],
  threshold: 2, // 2-of-3
  aggregate_public_key: aggregatePublicKey.toBytes(),
};

await linera.publish("./contract", params);
```

### Fase 3: Crear Proposal

```typescript
// Owner 1 crea propuesta de transferencia
const proposal = {
  to: "recipient_address",
  amount: 1000000,
  nonce: await contract.getNonce(),
  message: createMessage({
    nonce: 0,
    operation: "transfer",
    to: "recipient_address",
    amount: 1000000,
  }),
};

// Propuesta se guarda en backend (off-chain)
await backend.createProposal(proposal);
```

### Fase 4: Recoger Firmas

```typescript
// Owner 1 firma con su key share
const signature1 = Frost.sign(share1.secret_share, proposal.message);

// Enviar signature al backend
await backend.addSignature(proposalId, signature1);

// Owner 2 firma
const signature2 = Frost.sign(share2.secret_share, proposal.message);

await backend.addSignature(proposalId, signature2);

// Backend detecta que se alcanzó el threshold
if (signatures.length >= threshold) {
  // Agregar las firmas en una sola threshold signature
  const thresholdSignature = Frost.aggregate([
    signature1,
    signature2,
  ]);

  // Ejecutar on-chain
  await executeOnChain(proposal, thresholdSignature);
}
```

### Fase 5: Ejecutar On-Chain

```typescript
// Backend transmite la operación con threshold signature
const operation = {
  ExecuteWithThresholdSignature: {
    to: proposal.to,
    amount: proposal.amount,
    nonce: proposal.nonce,
    threshold_signature: thresholdSignature.toBytes(),
    message: proposal.message,
  },
};

await linera.executeOperation(contractAddress, operation);
```

### Fase 6: Verificación On-Chain

```rust
// En el contrato Wasm
fn execute_operation(op: MultisigOperation) {
    // 1. Verificar nonce
    assert!(op.nonce == state.nonce(), "Invalid nonce");

    // 2. Verificar threshold signature
    // La aggregate public key está en el estado del contrato
    let is_valid = ed25519::verify(
        &state.aggregate_public_key,
        &op.message,
        &op.threshold_signature,
    );
    assert!(is_valid, "Invalid threshold signature");

    // 3. Ejecutar transfer
    runtime.transfer(from, op.to, op.amount);

    // 4. Incrementar nonce
    state.increment_nonce();
}
```

---

## Especificaciones Técnicas

### Mensaje a Firmar

```rust
pub struct ThresholdMessage {
    pub nonce: u64,
    pub operation_type: String,
    pub operation_data: Vec<u8>,
}

impl ThresholdMessage {
    pub fn to_bytes(&self) -> Vec<u8> {
        // Codificación simple para evitar complejidad
        let mut bytes = Vec::new();
        bytes.extend_from_slice(&self.nonce.to_be_bytes());
        bytes.extend_from_slice(self.operation_type.as_bytes());
        bytes.extend_from_slice(&(self.operation_data.len() as u64).to_be_bytes());
        bytes.extend_from_slice(&self.operation_data);
        bytes
    }
}
```

### Operación On-Chain

```rust
pub enum MultisigOperation {
    ExecuteWithThresholdSignature {
        to: Owner,
        amount: u64,
        nonce: u64,
        threshold_signature: Vec<u8>, // 64 bytes para Ed25519
        message: Vec<u8>,
    },
}
```

### Estado del Contrato

```rust
pub struct MultisigState {
    pub owners: Vec<Owner>,           // Listado de owners (para info)
    pub threshold: u64,                // m-of-n
    pub aggregate_public_key: Vec<u8>, // 32 bytes para Ed25519
    pub nonce: u64,                    // Replay protection
}
```

---

## Implementación FROST

### Bibliotecas Rust Disponibles

```toml
[dependencies]
# Opción 1: frost-ed25519 (experimental)
frost-ed25519 = "0.1"

# Opción 2: Implementar desde cero siguiendo RFC
# Ver: https://datatracker.ietf.org/doc/html/rfc9591

# Opción 3: Usar libsodium bindings
libsodium-sys = "0.2"
```

### Estructura Básica FROST

```rust
use frost_ed25519::{
    Participant, Identifier,
    keys::{KeyPackage, SecretShare, PublicKeyPackage},
    round1::{SigningCommitments, SigningNonces},
    round2::{SignatureShare, AggregateSignature},
};

/// Fase de DKG (Distributed Key Generation)
async fn dkg_phase(
    participants: Vec<Participant>,
) -> (Vec<SecretShare>, PublicKeyPackage) {
    // Cada participante genera su share
    let secret_shares: Vec<SecretShare> = participants
        .iter()
        .map(|p| KeyPackage::generate_participant_share(p.identifier))
        .collect();

    // Compartir public shares
    let public_package = PublicKeyPackage::aggregate_all(
        secret_shares.iter().map(|s| s.public_share()),
    );

    (secret_shares, public_package)
}

/// Firmar con threshold scheme
fn threshold_sign(
    secret_share: &SecretShare,
    message: &[u8],
    signer_identifier: Identifier,
) -> SignatureShare {
    // Round 1: Generar commitment
    let nonces = SigningNonces::generate(signer_identifier);

    // Round 1: Compartir commitment
    let commitments = SigningCommitments::new(nonces.clone());

    // Round 2: Recibir commitments de otros signers
    // ...

    // Round 2: Generar signature share
    let signature_share = secret_share.sign(
        message,
        nonces,
        commitments,
        // ... commitments de otros signers
    );

    signature_share
}

/// Agregar firmas en threshold signature
fn aggregate_signatures(
    signature_shares: Vec<SignatureShare>,
) -> AggregateSignature {
    AggregateSignature::aggregate(signature_shares)
}

/// Verificar threshold signature
fn verify_threshold(
    public_key: &PublicKey,
    message: &[u8],
    signature: &AggregateSignature,
) -> bool {
    public_key.verify(message, signature).is_ok()
}
```

---

## Seguridad y Validación

### Propiedades de Seguridad

✅ **Self-Custodial**:
- Private keys nunca dejan el frontend
- Backend solo coordina, nunca firma
- Fondos controlados por contrato Wasm

✅ **Threshold Enforcement**:
- Criptográficamente imposible firmar sin m participantes
- No hay backdoor o bypass posible

✅ **Replay Protection**:
- Nonce incrementa con cada operación
- Cada firma solo puede usarse una vez

✅ **On-Chain Verification**:
- Cualquiera puede verificar en blockchain
- No se confía en servidor para validación

### Validaciones On-Chain

```rust
fn validate_operation(op: &MultisigOperation, state: &MultisigState) -> Result<(), Error> {
    // 1. Validar nonce
    if op.nonce != state.nonce {
        return Err(Error::InvalidNonce);
    }

    // 2. Validar formato de firma
    if op.threshold_signature.len() != 64 {
        return Err(Error::InvalidSignatureFormat);
    }

    // 3. Validar firma threshold
    let public_key = PublicKey::from_bytes(&state.aggregate_public_key)?;
    let signature = Signature::from_bytes(&op.threshold_signature)?;

    if !public_key.verify(&op.message, &signature) {
        return Err(Error::InvalidSignature);
    }

    // 4. Validar monto (opcional: límites)
    if op.amount > MAX_AMOUNT {
        return Err(Error::AmountTooHigh);
    }

    Ok(())
}
```

### Manejo de Errores

```rust
pub enum MultisigError {
    InvalidNonce,
    InvalidSignature,
    InvalidSignatureFormat,
    AmountTooHigh,
    InvalidRecipient,
    ContractPaused,
}

impl MultisigError {
    pub fn log_message(&self) -> &str {
        match self {
            Self::InvalidNonce => "Nonce inválido: posible replay attack",
            Self::InvalidSignature => "Firma threshold inválida",
            Self::InvalidSignatureFormat => "Formato de firma incorrecto",
            Self::AmountTooHigh => "Monto excede máximo permitido",
            Self::InvalidRecipient => "Destinatario inválido",
            Self::ContractPaused => "Contract en pausa de emergencia",
        }
    }
}
```

---

## Comparación con Otros Sistemas

### vs Safe (Ethereum)

| Aspecto | Safe (Ethereum) | Threshold (Linera) |
|---------|----------------|-------------------|
| **Modelo** | m-of-n confirmaciones on-chain | m-of-n firma threshold off-chain |
| **Proposals** | On-chain | Off-chain (backend DB) |
| **Gas Cost** | Crece con confirmaciones | Constante |
| **Privacidad** | Pública (quién confirmó) | Privada (no revela signers) |

### vs Gnosis Safe

| Aspecto | Gnosis Safe | Threshold (Linera) |
|---------|-------------|-------------------|
| **UX** | Muy similar | Diferente (menos transacciones on-chain) |
| **Flexibilidad** | Alta (modular) | Media (fija en Wasm) |
| **Seguridad** | Auditada | Por auditar |

---

## Roadmap de Implementación

### Fase 1: Prueba de Concepto ✅
- [x] Diseño de arquitectura
- [x] Contrato Wasm simplificado
- [x] Documentación

### Fase 2: Implementación Básica ⏳
- [ ] Compilar contrato Wasm
- [ ] Verificar ausencia de opcode 252
- [ ] Deploy a testnet
- [ ] Prueba de transfer básica

### Fase 3: FROST Implementation ⏳
- [ ] Integrar biblioteca FROST
- [ ] Implementar DKG phase
- [ ] Implementar signing phase
- [ ] Probar threshold signatures

### Fase 4: Frontend Integration ⏳
- [ ] Wallet con key shares
- [ ] UI para propuestas
- [ ] UI para firmas
- [ ] Coordinación real-time

### Fase 5: Backend Integration ⏳
- [ ] REST API
- [ ] WebSocket para coordinación
- [ ] PostgreSQL para propuestas
- [ ] Integración con @linera/client

---

## Conclusión

La arquitectura de threshold signatures ofrece un camino viable para implementar multisig self-custodial en Linera mientras se resuelve el problema del opcode 252.

**Próximos pasos**:
1. Compilar y verificar opcode 252 ausente
2. Deploy a testnet
3. Probar funcionalidad básica
4. Evaluar si requiere FROST o basta con placeholder

---

**Última actualización**: 2026-02-04
**Autor**: Experimento alternativo para linera.dev
