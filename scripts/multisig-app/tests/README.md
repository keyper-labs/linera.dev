# Linera Multisig Application - Unit Tests

## Estado Actual

Las pruebas unitarias han sido creadas pero tienen problemas de compilación debido a:

1. **Estructura del módulo**: El contrato está definido como un binario separado en `src/contract.rs`, no como parte de la librería.
2. **Visibilidad de campos**: Los campos de `MultisigContract` son privados.
3. **Imports incorrectos**: Algunos tipos de `linera_sdk` no están siendo importados correctamente.
4. **Atributos inner attribute**: `include!` no funciona bien con inner attributes como `#![cfg_attr(target_arch = "wasm32", no_main)]`.

## Pruebas Creadas

El archivo `tests/multisig_tests.rs` contiene pruebas comprehensivas para:

### 1. **Proposal Submission Tests** (5 tests)
- `test_submit_transfer_proposal` - Verifica envío de propuesta de transferencia
- `test_submit_add_owner_proposal` - Verifica agregar owner
- `test_submit_remove_owner_proposal` - Verifica remover owner
- `test_submit_replace_owner_proposal` - Verifica reemplazar owner
- `test_submit_change_threshold_proposal` - Verifica cambio de threshold

### 2. **Proposal Validation Tests** (6 tests)
- `test_transfer_zero_amount_fails` - Valida que transferencias de 0 fallen
- `test_add_existing_owner_fails` - Valida que no se dupliquen owners
- `test_remove_nonexistent_owner_fails` - Valida que solo se remuevan owners existentes
- `test_remove_owner_below_threshold_fails` - Valida constraint de threshold
- `test_change_threshold_to_zero_fails` - Valida threshold > 0
- `test_change_threshold_above_owners_fails` - Valida threshold <= owners

### 3. **Confirmation Tests** (2 tests)
- `test_confirm_proposal_increments_count` - Verifica incremento de confirmaciones
- `test_confirm_proposal_idempotent` - Verifica idempotencia de confirmaciones

### 4. **Execution Tests** (7 tests)
- `test_execute_proposal_with_sufficient_confirmations` - Ejecución exitosa
- `test_execute_proposal_insufficient_confirmations_fails` - Falla sin threshold
- `test_execute_proposal_twice_fails` - No ejecutar dos veces
- `test_execute_transfer_proposal` - Ejecutar transferencia
- `test_execute_remove_owner_proposal` - Ejecutar remoción de owner
- `test_execute_replace_owner_proposal` - Ejecutar reemplazo de owner
- `test_execute_change_threshold_proposal` - Ejecutar cambio de threshold

### 5. **Revocation Tests** (3 tests)
- `test_revoke_confirmation_decrements_count` - Decrementa contador
- `test_revoke_confirmation_idempotent` - Idempotencia de revocación
- `test_revoke_confirmation_after_execute_fails` - No revocar después de ejecutar

### 6. **Authorization Tests** (3 tests)
- `test_non_owner_cannot_submit_proposal` - Solo owners pueden proponer
- `test_non_owner_cannot_confirm_proposal` - Solo owners pueden confirmar
- `test_non_owner_cannot_execute_proposal` - Solo owners pueden ejecutar

### 7. **Nonce Tests** (1 test)
- `test_proposal_ids_increment_with_nonce` - IDs secuenciales

### 8. **Instantiation Tests** (3 tests)
- `test_instantiate_with_zero_threshold_fails` - Threshold debe ser > 0
- `test_instantiate_threshold_exceeds_owners_fails` - Threshold <= owners
- `test_instantiate_valid_configuration` - Configuración válida

### 9. **Edge Case Tests** (4 tests)
- `test_single_owner_with_threshold_one` - Edge case: 1 owner, threshold 1
- `test_all_owners_must_confirm_for_max_threshold` - Todos deben confirmar
- `test_proposal_timestamp_is_set` - Timestamp se establece
- `test_multiple_proposals_independent` - Propuestas independientes

## Total: 34 Tests

## Próximos Pasos

Para que las pruebas funcionen, se necesita:

### Opción 1: Reestructurar el proyecto
1. Mover `MultisigContract` a `src/lib.rs` como parte de la librería
2. Hacer públicos los campos necesarios de `MultisigContract`
3. Crear métodos getter para el estado interno

### Opción 2: Usar integración tests en su lugar
1. Mantener la estructura actual
2. Usar `linera-sdk` integration testing framework
3. Probar a nivel de blockchain en lugar de unit tests

### Opción 3: Crear módulo de testing separado
1. Exportar el contract como librería con feature flag
2. Crear wrappers de testing con visibilidad pública

## Recomendación

**Opción 1** es la más apropiada para tests unitarios comprehensivos. Requiere:

1. Cambiar `src/lib.rs` para incluir el contract
2. Agregar `pub` a los campos necesarios de `MultisigContract`
3. Actualizar imports en `tests/multisig_tests.rs`
4. Corregir tipos de `linera_sdk` (Owner -> AccountOwner, ChainId::test -> ChainId::for_genesis, etc.)

## Patrones de Testing Linera SDK v0.15.11

```rust
// Para crear un test chain ID
use linera_sdk::base::ChainId;
let chain_id = ChainId::root(1);

// Para crear un owner
use linera_sdk::base::Owner;
let owner = Owner::User([0u8; 32]);

// Para crear test runtime
use linera_sdk::contract::MockContractRuntime;
let mut runtime = MockContractRuntime::<MyContract>::default();

// Para blocking wait
use futures::FutureExt;
result.blocking_wait();
```

## Archivo de Pruebas

Ubicación: `/Users/alfredolopez/Documents/GitHub/PalmeraDAO/linera.dev/scripts/multisig-app/tests/multisig_tests.rs`

El archivo está listo y solo requiere los ajustes de estructura mencionados arriba.
