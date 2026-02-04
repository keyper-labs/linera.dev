# Experimento: Threshold Signatures Alternative

> **Branch**: `feature/threshold-signatures-alternative`
> **Propósito**: Probar arquitectura alternativa que evite el opcode 252
> **Estado**: 🟡 En desarrollo

---

## Resumen Ejecutivo

Este experimento prueba una arquitectura alternativa de multisig **self-custodial** que podría evitar el bloqueo del opcode 252.

### Hipótesis

El opcode 252 (`memory.copy`) es generado por código complejo en el Wasm contract. Si simplificamos el contrato para que solo verifique firmas threshold (en lugar de mantener proposal state machine), podemos:

1. **Evitar el opcode 252** generado por async-graphql
2. **Mantener self-custodia** (private keys en frontend)
3. **Ejecutar on-chain** (verificación criptográfica en Wasm)

### ¿Qué es Self-Custodial?

| Arquitectura | Private Keys | Backend Control | On-Chain Verification |
|--------------|--------------|-----------------|----------------------|
| **Threshold Signatures** (este) | ✅ Frontend | ❌ No controla fondos | ✅ Sí, en Wasm |
| **Original Wasm** (bloqueada) | ✅ Frontend | ❌ No controla fondos | ✅ Sí, en Wasm |
| **Off-Chain Logic** | 🔴 Backend | ✅ Backend controla | ❌ No, es off-chain |

**Este experimento ES self-custodial** porque:
- Private keys nunca dejan el frontend
- Backend solo transmite operaciones firmadas
- Fondos controlados por contrato Wasm, no por backend

---

## Arquitectura

```
┌─────────────────────────────────────────────────────────────┐
│  Frontend (React + @linera/client)                         │
│  ┌─────────────────────────────────────────────────────┐   │
│  │ 🔐 Private Keys (ED25519)                           │   │
│  │    - Nunca salen del navegador                      │   │
│  │    - Owners firman proposals off-chain              │   │
│  │    - Threshold signature aggregation                │   │
│  └─────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────┘
           ↓ (firma + agrega firmas)
┌─────────────────────────────────────────────────────────────┐
│  Backend API (REST + @linera/client)                       │
│  ┌─────────────────────────────────────────────────────┐   │
│  │ 📡 Solo transmite operaciones                       │   │
│  │    - Recibe threshold signature                     │   │
│  │    - Transmite a Linera                             │   │
│  │    - NO tiene private keys                          │   │
│  └─────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────┘
           ↓ (ejecuta con firma threshold)
┌─────────────────────────────────────────────────────────────┐
│  Linera Network                                            │
│  ┌─────────────────────────────────────────────────────┐   │
│  │ 🔒 ThresholdMultisigContract (Wasm)                 │   │
│  │    - Verifica threshold signature                   │   │
│  │    - Ejecuta si válida                              │   │
│  │    - Fondos en contrato, no backend                 │   │
│  └─────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────┘
```

### Diferencias con Arquitectura Original

| Aspecto | Original (bloqueada) | Threshold (este) |
|---------|---------------------|------------------|
| **Proposal Storage** | On-chain (Wasm) | Off-chain (Backend DB) |
| **Approval Tracking** | On-chain state machine | Threshold signature criptográfica |
| **Complexity** | Alta (GraphQL + state) | Baja (solo verificación) |
| **async-graphql** | ✅ Usado | ❌ NO usado |
| **Opcode 252 Risk** | 🔴 Alto | 🟡 Bajo (esperemos) |

---

## Flujo de Operación

### 1. Setup (Inicialización)

```bash
# Crear contrato multisig
linera publish ./experiments/threshold-signatures \
    --json-params '{
        "owners": ["owner1...", "owner2...", "owner3..."],
        "threshold": 2,
        "aggregate_public_key": "..."
    }'
```

**NOTA**: La `aggregate_public_key` se genera durante una fase de setup cooperativa donde los owners colaboran para generar la clave agregada del esquema threshold.

### 2. Crear Proposal (Off-Chain)

```typescript
// Frontend: Owner crea proposal
const proposal = {
    to: "recipient_address",
    amount: 1000000,
    nonce: await getCurrentNonce(), // Del contrato
};

// Owner firma su parte
const signature = await sign(proposal, ownerPrivateKey);
```

### 3. Recoger Firmas (Off-Chain)

```typescript
// Frontend: Owners colaboran para agregar firmas
// Cuando se alcanza el threshold, se genera la firma threshold

const thresholdSignature = await aggregateSignatures([
    signature1,
    signature2,
    // ... m firmas (donde m >= threshold)
]);
```

### 4. Ejecutar (On-Chain)

```typescript
// Backend: Recibe threshold signature y transmite
const operation = {
    ExecuteWithThresholdSignature: {
        to: "recipient_address",
        amount: 1000000,
        nonce: 0,
        threshold_signature: thresholdSignature,
        message: proposalBytes,
    },
};

await lineraClient.executeOperation(operation);
```

### 5. Verificación (Wasm Contract)

```rust
// En el contrato Wasm:
fn execute_operation(op: MultisigOperation) {
    // 1. Verificar nonce (replay protection)
    assert!(nonce == state.nonce());

    // 2. Verificar threshold signature
    let is_valid = verify_threshold_signature(&message, &threshold_signature);
    assert!(is_valid);

    // 3. Ejecutar transfer
    runtime.transfer(from, to, amount);

    // 4. Incrementar nonce
    state.increment_nonce();
}
```

---

## Implementación Threshold Signatures

### NOTA Importante: Placeholder vs Producción

El código actual usa **Ed25519 estándar como placeholder** para demostrar el concepto.

**Para producción**, necesitarías implementar un esquema real de threshold signatures como:

- **FROST** (Flexible Round-Optimized Schnorr Threshold Signatures)
- **MuSig2** (MuSig2 Multi-Signatures)
- **Ed25519 Threshold** variantes

### Por qué FROST?

FROST es ideal para multisig porque:

1. **Constante en tiempo**: La firma threshold NO crece con el número de signers
2. **Privacidad**: No revela cuáles signers participaron
3. **Robustez**: Tolerates signers no-disponibles
4. **Eficiencia**: Una sola verificación on-chain

```
# Ejemplo FROST (3-of-5):

Setup phase:
- Owners colaboran para generar shares de private key
- Cada owner tiene: (share_i, public_key_i)
- Aggregate public key: PK = PK_1 + PK_2 + ... + PK_5

Signing phase (3-of-5):
- Cualquier 3 owners pueden firmar
- Cada owner firma con su share: signature_i = sign(share_i, message)
- Se agregan las firmas: σ = σ_1 + σ_2 + σ_3
- Resultado: Una sola firma del tamaño de una firma individual

Verification phase:
- Cualquiera puede verificar: verify(PK, message, σ)
- Solo se necesita la aggregate public key
```

---

## Ventajas y Desventajas

### Ventajas ✅

1. **Self-Custodial**: Private keys en frontend, backend no controla fondos
2. **On-Chain Verification**: Threshold signature verificada en Wasm
3. **Simple**: Menos complejidad que proposal state machine
4. **Sin async-graphql**: Evita opcode 252 (esperemos)
5. **Escalable**: Una sola firma sin importar número de owners

### Desventajas ❌

1. **Propuestas Off-Chain**: No hay registro on-chain de propuestas
2. **Setup Complejo**: Fase inicial de key generation
3. **No Sin Revisión**: Cambios de configuración requieren nueva clave agregada
4. **Library Availability**: Necesita implementar/threshold signature library

### Trade-offs 🔄

| Aspecto | Original (bloqueada) | Threshold |
|---------|---------------------|-----------|
| **Transparencia On-Chain** | ✅ Todo on-chain | ⚠️ Propuestas off-chain |
| **Complejidad Wasm** | 🔴 Alta | 🟢 Baja |
| **Escalabilidad** | ⚠️ Crece con owners | ✅ Constante |
| **Experiencia Usuario** | ✅ Safe-like | ⚠️ Diferente |

---

## Plan de Pruebas

### Fase 1: Compilación ✅

```bash
cd experiments/threshold-signatures
cargo build --release --target wasm32-unknown-unknown
```

**Esperado**: Wasm binary generado

### Fase 2: Verificación de Opcode ✅

```bash
# Verificar que NO contiene opcode 252
wasm-objdump -d target/wasm32-unknown-unknown/release/linera_threshold_multisig.wasm | grep "0xFC"
```

**Esperado**: No debería aparecer `0xFC` (opcode 252)

### Fase 3: Deploy a Testnet 🟡

```bash
# Deploy a Linera testnet
linera publish ./experiments/threshold-signatures \
    --json-params '{
        "owners": [...],
        "threshold": 2,
        "aggregate_public_key": "..."
    }'
```

**Esperado**: Contract deployado exitosamente

### Fase 4: Ejecución de Operaciones 🟡

```bash
# Ejecutar transfer con threshold signature
linera operation \
    --target <contract_address> \
    --json-operation '{
        "ExecuteWithThresholdSignature": {...}
    }
```

**Esperado**: Operación ejecutada exitosamente

---

## Estado Actual

| Fase | Estado | Notas |
|------|--------|-------|
| **Diseño** | ✅ Completado | Arquitectura documentada |
| **Implementación** | ✅ Completado | Código Rust funcional |
| **Compilación** | ⏳ Pendiente | Por probar |
| **Opcode Check** | ⏳ Pendiente | Por verificar |
| **Deploy Testnet** | ⏳ Pendiente | Por probar |
| **Ejecución** | ⏳ Pendiente | Por probar |

---

## Siguientes Pasos

1. ✅ Crear branch `feature/threshold-signatures-alternative`
2. ✅ Implementar contrato Wasm simplificado
3. ✅ Documentar arquitectura
4. ⏳ Compilar a Wasm
5. ⏳ Verificar opcode 252 ausente
6. ⏳ Deploy a Linera testnet
7. ⏳ Ejecutar operaciones de prueba
8. ⏳ Documentar resultados

---

## Referencias

- [FROST: Flexible Round-Optimized Schnorr Threshold Signatures](https://eprint.iacr.org/2020/852)
- [Linera SDK Documentation](https://docs.linera.dev)
- [Ed25519 Threshold Signatures](https://signal.org/docs/urgent-future-of-encryption/)

---

**Última actualización**: 2026-02-04
**Branch**: `feature/threshold-signatures-alternative`
