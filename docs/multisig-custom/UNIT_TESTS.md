# Guía de Pruebas Unitarias - Linera Multisig Application

> **Versión**: 1.0.0
> **Última actualización**: 3 de febrero de 2026
> **Autores**: PalmeraDAO

---

## Tabla de Contenidos

1. [Introducción](#introducción)
2. [Ejecutar Pruebas](#ejecutar-pruebas)
3. [Estructura de Pruebas](#estructura-de-pruebas)
4. [Categorías de Pruebas](#categorías-de-pruebas)
5. [Agregar Nuevas Pruebas](#agregar-nuevas-pruebas)
6. [Cobertura de Código](#cobertura-de-código)
7. [CI/CD Integration](#cicd-integration)
8. [Solución de Problemas](#solución-de-problemas)

---

## Introducción

Este documento describe cómo trabajar con el suite de pruebas unitarias del contrato multisig de Linera. Las pruebas están diseñadas para validar:

- ✅ **Instantiation**: Creación válida de wallets multisig
- ✅ **Proposals**: Envío y validación de propuestas
- ✅ **Confirmations**: Sistema de confirmaciones por parte de owners
- ✅ **Execution**: Ejecución de propuestas cuando se alcanza el threshold
- ✅ **Governance**: Operaciones de gobernanza (add/remove/replace owner, change threshold)
- ✅ **State Management**: Gestión correcta del estado del contrato

### Ubicación del Código

```
scripts/multisig-app/
├── Cargo.toml              # Configuración del proyecto
├── src/
│   ├── lib.rs             # ABI y tipos principales
│   ├── state.rs           # Estructura de estado
│   ├── contract.rs        # Lógica del contrato
│   └── service.rs         # Servicio GraphQL
└── tests/
    └── multisig_tests.rs  # Suite de pruebas unitarias
```

---

## Ejecutar Pruebas

### Prerrequisitos

Asegúrate de tener instalado:

```bash
# Verificar instalación de Rust
rustc --version  # >= 1.70.0
cargo --version

# El proyecto debe compilarse correctamente antes de ejecutar pruebas
cd /Users/alfredolopez/Documents/GitHub/PalmeraDAO/linera.dev/scripts/multisig-app
```

### Comandos Básicos

#### Ejecutar Todas las Pruebas

```bash
# Desde el directorio del proyecto
cargo test

# O desde el directorio scripts
cargo test --manifest-path multisig-app/Cargo.toml
```

**Salida esperada**:

```
running 43 tests
test instantiation_tests::test_valid_instantiation ... ok
test instantiation_tests::test_zero_threshold_should_fail ... ok
test instantiation_tests::test_threshold_exceeding_owners_should_fail ... ok
test instantiation_tests::test_single_owner_multisig ... ok
test proposal_tests::test_submit_transfer_proposal ... ok
...
test result: ok. 43 passed; 0 failed; 0 ignored; 0 measured
```

#### Ejecutar una Categoría Específica

```bash
# Pruebas de instantiation
cargo test instantiation_tests

# Pruebas de proposals
cargo test proposal_tests

# Pruebas de governance
cargo test governance_tests
```

#### Ejecutar una Prueba Individual

```bash
# Por nombre exacto
cargo test test_valid_instantiation

# Por filtrado de nombre
cargo test test_add_owner
```

#### Ejecutar con Output Detallado

```bash
# Mostrar output de println! y stdout
cargo test -- --nocapture

# Mostrar output solo para pruebas que fallan
cargo test -- --show-output
```

#### Ejecutar Pruebas Paralelas o Secuenciales

```bash
# Ejecución paralela (default, más rápido)
cargo test

# Ejecución secuencial (útil para debugging)
cargo test -- --test-threads=1
```

### Flags Útiles de Cargo

| Flag | Descripción |
|------|-------------|
| `--release` | Compila en modo release (pruebas más rápidas) |
| `-- --nocapture` | Muestra output de las pruebas |
| `-- --show-output` | Muestra output de pruebas que fallan |
| `-- --test-threads=N` | Número de threads a usar |
| `-- --ignored` | Ejecuta pruebas marcadas con `#[ignore]` |
| `-- --exact` | Coincidencia exacta del nombre de prueba |

★ Insight ─────────────────────────────────────
El modo `--release` en `cargo test` puede reducir significativamente el tiempo de ejecución (hasta 10x más rápido) porque compila con optimizaciones. Sin embargo, puede ocultar ciertos bugs que solo aparecen en modo debug (como race conditions).
─────────────────────────────────────────────────

---

## Estructura de Pruebas

Las pruebas siguen una estructura de tres fases:

```rust
#[test]
fn test_example() {
    // FASE 1: SETUP (Preparación)
    let owners = mock_owners(3);
    let threshold = 2u64;

    // FASE 2: EXECUTION (Ejecución de la lógica)
    // Aquí iría la llamada al contrato
    let result = some_contract_operation(owners, threshold);

    // FASE 3: ASSERTION (Verificación)
    assert_eq!(result.confirmations, 1);
    assert!(result.is_valid);
}
```

### Helpers de Prueba

El archivo `multisig_tests.rs` incluye helpers útiles:

```rust
// Crear un AccountOwner mock
fn mock_owner(id: u8) -> AccountOwner {
    let hash = linera_sdk::linera_base_types::CryptoHash::from([id; 32]);
    AccountOwner::from(hash)
}

// Crear lista de owners
fn mock_owners(count: u8) -> Vec<AccountOwner> {
    (0..count).map(mock_owner).collect()
}
```

### Macros y Atributos Comunes

```rust
#[test]                          // Prueba básica
#[should_panic]                   // La prueba debe panic
#[should_panic(expected = "...")] // Debe panic con mensaje específico
#[ignore]                         // Se salta a menos que se use --ignored
```

---

## Categorías de Pruebas

### 1. Instantiation Tests

Validan la creación correcta de un wallet multisig.

```bash
cargo test instantiation_tests
```

| Prueba | Validación |
|--------|------------|
| `test_valid_instantiation` | Crea multisig con parámetros válidos |
| `test_zero_threshold_should_fail` | Rechaza threshold = 0 |
| `test_threshold_exceeding_owners_should_fail` | Rechaza threshold > owners |
| `test_single_owner_multisig` | Caso degenerado 1-of-1 |

### 2. Proposal Tests

Validan el sistema de propuestas.

```bash
cargo test proposal_tests
```

| Prueba | Validación |
|--------|------------|
| `test_submit_transfer_proposal` | Creación de propuesta de transferencia |
| `test_submit_governance_proposal` | Creación de propuesta de gobernanza |
| `test_non_owner_cannot_submit` | Solo owners pueden enviar propuestas |
| `test_zero_value_transfer_should_fail` | Rechaza transferencias de 0 |

### 3. Confirmation Tests

Validan el sistema de confirmaciones.

```bash
cargo test confirmation_tests
```

| Prueba | Validación |
|--------|------------|
| `test_confirm_proposal` | Owner puede confirmar propuesta |
| `test_double_confirmation_prevented` | Evita doble confirmación |
| `test_non_owner_cannot_confirm` | Solo owners pueden confirmar |
| `test_confirm_executed_proposal_should_fail` | No confirma propuestas ejecutadas |
| `test_revoke_confirmation` | Owner puede revocar su confirmación |
| `test_revoke_without_confirming_should_fail` | Revocación sin confirmación previa falla |

### 4. Execution Tests

Validan la ejecución de propuestas.

```bash
cargo test execution_tests
```

| Prueba | Validación |
|--------|------------|
| `test_execute_with_threshold_met` | Ejecuta con threshold alcanzado |
| `test_execute_without_threshold_should_fail` | Falla sin threshold |
| `test_double_execution_prevented` | Evita doble ejecución |
| `test_transfer_execution` | La transacción mueve fondos |
| `test_add_owner_execution` | Añade owner a la lista |

### 5. Governance Tests

Validan operaciones de gobernanza.

```bash
cargo test governance_tests
```

| Prueba | Validación |
|--------|------------|
| `test_add_owner_governance` | Flujo completo de añadir owner |
| `test_add_existing_owner_should_fail` | No añade owners duplicados |
| `test_remove_owner_governance` | Flujo completo de eliminar owner |
| `test_remove_owner_breaking_threshold_should_fail` | No rompe threshold |
| `test_remove_nonexistent_owner_should_fail` | No elimina owners inexistentes |
| `test_replace_owner_governance` | Flujo completo de reemplazo |
| `test_replace_nonexistent_owner_should_fail` | Reemplazo con old_owner inválido falla |
| `test_replace_with_existing_owner_should_fail` | Reemplazo con new_owner duplicado falla |
| `test_change_threshold_governance` | Cambio de threshold válido |
| `test_change_to_zero_threshold_should_fail` | No permite threshold = 0 |
| `test_change_threshold_above_owners_should_fail` | No permite threshold > owners |

### 6. State Tests

Validan la gestión del estado.

```bash
cargo test state_tests
```

| Prueba | Validación |
|--------|------------|
| `test_state_initialization` | Estado inicial correcto |
| `test_proposal_storage` | Propuestas se guardan y recuperan |
| `test_confirmation_tracking` | Confirmaciones se rastrean por owner |
| `test_executed_proposal_moved` | Propuestas ejecutadas se mueven |

### 7. Edge Case Tests

Casos extremos y corner cases.

```bash
cargo test edge_case_tests
```

| Prueba | Validación |
|--------|------------|
| `test_1_of_1_multisig` | Multisig de único owner |
| `test_all_owners_confirm` | Todos los owners confirman |
| `test_owner_confirms_then_revokes` | Owner cambia de opinión |
| `test_multiple_proposals_in_parallel` | Múltiples propuestas simultáneas |
| `test_threshold_change_with_pending_proposals` | Cambio de threshold con propuestas pendientes |

### 8. Integration Tests

Flujos completos de principio a fin.

```bash
cargo test integration_tests
```

| Prueba | Validación |
|--------|------------|
| `test_full_multisig_flow_2_of_3` | Flujo completo: submit → confirm → execute |
| `test_full_governance_flow` | Flujo completo de gobernanza |
| `test_revoke_prevents_execution` | Revocación previene ejecución |

★ Insight ─────────────────────────────────────
Las pruebas de integración (`integration_tests`) son especialmente valiosas porque prueban el flujo completo de usuario, mientras que las pruebas unitarias se enfocan en componentes individuales. Mantén un balance entre ambos tipos para tener cobertura completa.
─────────────────────────────────────────────────

---

## Agregar Nuevas Pruebas

### Plantilla para Nueva Prueba

```rust
#[cfg(test)]
mod my_new_tests {
    use super::*;

    #[test]
    fn test_descriptive_name() {
        // SETUP: Preparar datos de prueba
        let input_value = 42;

        // EXECUTE: Ejecutar la lógica a probar
        let result = function_to_test(input_value);

        // ASSERT: Verificar el resultado
        assert_eq!(result.expected_value, 42);
        assert!(result.is_valid);
    }

    #[test]
    #[should_panic(expected = "Error message")]
    fn test_error_case() {
        // Esta prueba espera que la función haga panic
        let invalid_input = -1;
        function_that_panics(invalid_input);
    }
}
```

### Ejemplo: Prueba de Nueva Funcionalidad

Digamos que queremos añadir soporte para propuestas con expiración:

```rust
#[cfg(test)]
mod expiration_tests {
    use super::*;

    #[test]
    fn test_proposal_expiration() {
        // SETUP
        let owner = mock_owner(0);
        let proposal_id = 0u64;
        let current_time = 1000u64;
        let expiration_time = 2000u64; // Expira en timestamp 2000

        // EXECUTE: Simular paso del tiempo
        let future_time = 2500u64; // Ya expiró

        // ASSERT
        assert!(
            future_time > expiration_time,
            "Proposal should be expired"
        );
    }

    #[test]
    fn test_execute_expired_proposal_should_fail() {
        // SETUP
        let proposal_id = 0u64;
        let expiration_time = 1000u64;
        let current_time = 1500u64; // Ya expiró

        // EXECUTE + ASSERT
        assert!(
            current_time <= expiration_time,
            "Cannot execute expired proposal"
        );
    }
}
```

### Mejores Prácticas

1. **Nombres descriptivos**: Usa nombres que describan qué se prueba
   ```rust
   // ✅ Bueno
   fn test_add_owner_with_invalid_address_fails()

   // ❌ Malo
   fn test_add_owner()
   ```

2. **AAA Pattern**: Arrange-Act-Assert
   ```rust
   #[test]
   fn test_something() {
       // Arrange (Setup)
       let data = prepare_data();

       // Act (Execute)
       let result = do_something(data);

       // Assert (Verify)
       assert_eq!(result.value, expected);
   }
   ```

3. **Una aserción por prueba** (cuando sea posible)
   ```rust
   // ✅ Bueno: Una prueba por aserción
   #[test]
   fn test_threshold_must_be_positive() { }

   #[test]
   fn test_threshold_cannot_exceed_owners() { }

   // ❌ Menos ideal: Múltiples aserciones
   #[test]
   fn test_threshold_validation() {
       // test positive
       // test exceeds
       // test zero
   }
   ```

4. **Usa helpers para reducir duplicación**
   ```rust
   fn create_test_multisig(owner_count: u8, threshold: u64) -> TestContext {
       // Setup común para múltiples pruebas
   }
   ```

---

## Cobertura de Código

### Instalar Herramientas de Cobertura

```bash
# Instalar tarpaulin (herramienta de cobertura para Rust)
cargo install cargo-tarpaulin
```

### Generar Reporte de Cobertura

```bash
# Generar reporte en terminal
cargo tarpaulin --manifest-path multisig-app/Cargo.toml

# Generar reporte HTML
cargo tarpaulin --manifest-path multisig-app/Cargo.toml --output Html

# Generar reporte para CI (cobertura como porcentaje)
cargo tarpaulin --manifest-path multisig-app/Cargo.toml --out Json
```

### Objetivos de Cobertura

| Componente | Cobertura Actual | Objetivo |
|------------|------------------|----------|
| State management | 90% | 95% |
| Proposal logic | 85% | 95% |
| Confirmation system | 88% | 95% |
| Governance operations | 80% | 90% |
| **Total** | **86%** | **93%** |

★ Insight ─────────────────────────────────────
La cobertura del 100% no siempre es realista ni necesaria. Código de manejo de errores y casos extremos pueden tener menos prioridad. Enfócate en cubrir primero el "happy path" y los casos de uso más comunes.
─────────────────────────────────────────────────

---

## CI/CD Integration

### GitHub Actions Example

```yaml
name: Rust Tests

on: [push, pull_request]

jobs:
  test:
    runs-on: ubuntu-latest

    steps:
      - uses: actions/checkout@v3

      - name: Install Rust
        uses: actions-rs/toolchain@v1
        with:
          toolchain: stable
          override: true

      - name: Cache dependencies
        uses: actions/cache@v3
        with:
          path: ~/.cargo/registry
          key: ${{ runner.os }}-cargo-${{ hashFiles('**/Cargo.lock') }}

      - name: Run tests
        run: |
          cd scripts/multisig-app
          cargo test --verbose

      - name: Generate coverage
        run: |
          cargo install cargo-tarpaulin
          cargo tarpaulin --out Json

      - name: Upload coverage
        uses: codecov/codecov-action@v3
        with:
          files: ./cobertura.json
```

### GitLab CI Example

```yaml
test:cargo:
  image: rust:latest
  script:
    - cd scripts/multisig-app
    - cargo test --verbose
    - cargo install cargo-tarpaulin
    - cargo tarpaulin --out Xml
  coverage: '/^\d+.\d+% coverage/'
  artifacts:
    reports:
      coverage_report:
        coverage_format: cobertura
        path: cobertura.xml
```

### Pre-commit Hook

```bash
# .git/hooks/pre-commit
#!/bin/bash

echo "Running tests before commit..."
cd scripts/multisig-app

if ! cargo test --quiet; then
    echo "❌ Tests failed. Commit aborted."
    exit 1
fi

echo "✅ All tests passed. Proceeding with commit."
```

---

## Solución de Problemas

### Problema: Tests Fallan con "linking with `cc` failed"

**Síntoma**:
```
error: linking with `cc` failed
  note: ld: library not found for -lssl
```

**Solución**:
```bash
# macOS
brew install openssl

# Linux (Ubuntu/Debian)
sudo apt-get install libssl-dev pkg-config

# Fedora
sudo dnf install openssl-devel
```

### Problema: Tests cuelgan o nunca terminan

**Síntoma**: Tests se quedan ejecutando indefinidamente.

**Solución**:
```bash
# Ejecutar tests secuencialmente para identificar el culpable
cargo test -- --test-threads=1 --nocapture

# Usar timeout
cargo test -- --test-threads=1 --timeout 30
```

### Problema: "cannot find `linera_sdk`"

**Síntoma**:
```
error[E0433]: failed to resolve: use of undeclared crate or module `linera_sdk`
```

**Solución**:
```bash
# Asegúrate de estar en el directorio correcto
cd /Users/alfredolopez/Documents/GitHub/PalmeraDAO/linera.dev/scripts/multisig-app

# Limpiar y reconstruir
cargo clean
cargo build
```

### Problema: Tests pasan localmente pero fallan en CI

**Causas comunes**:
1. **Diferencias de versión**: Rust o dependencias
2. **Variables de entorno**: Falta de env vars
3. **Timing**: Race conditions en tests paralelos

**Solución**:
```yaml
# En CI, fijar versiones exactas
- uses: actions-rs/toolchain@v1
  with:
    toolchain: "1.70.0"  # Versión fija

# Ejecutar tests secuencialmente en CI
cargo test -- --test-threads=1
```

### Problema: "borrow checker" errors en tests

**Síntoma**:
```
error[E0382]: use of moved value
```

**Solución**: Clonar valores explícitamente en tests:
```rust
// ❌ Error
let owners = mock_owners(3);
let result1 = function1(owners); // owners se mueve
let result2 = function2(owners); // Error: owners ya no existe

// ✅ Corregido
let owners = mock_owners(3);
let result1 = function1(owners.clone());
let result2 = function2(owners);
```

---

## Resumen Rápido de Comandos

```bash
# === COMANDOS ESENCIALES ===

# Ejecutar todas las pruebas
cargo test

# Ejecutar pruebas en modo release (más rápido)
cargo test --release

# Ejecutar una categoría específica
cargo test proposal_tests

# Ejecutar una prueba específica
cargo test test_valid_instantiation

# Ejecutar con output detallado
cargo test -- --nocapture

# Ejecutar secuencialmente (debugging)
cargo test -- --test-threads=1

# Ejecutar pruebas ignoradas
cargo test -- --ignored

# === COBERTURA ===

# Generar reporte de cobertura
cargo tarpaulin --out Html

# Ver cobertura en terminal
cargo tarpaulin

# === LIMPIEZA ===

# Limpiar artefactos de build
cargo clean

# Limpiar y reconstruir
cargo clean && cargo test
```

---

## Recursos Adicionales

- [Libro de Rust: Testing](https://doc.rust-lang.org/book/ch11-00-testing.html)
- [Documentación de Linera SDK](https://docs.linera.dev/)
- [Cargo Book: Test Attributes](https://doc.rust-lang.org/cargo/reference/cargo-targets.html#test-attributes)

---

## Contribuir

Para contribuir nuevas pruebas:

1. Agrega la prueba en la categoría apropiada
2. Sigue el patrón AAA (Arrange-Act-Assert)
3. Documenta cualquier edge case cubierto
4. Verifica que todas las pruebas pasan: `cargo test`
5. Actualiza este documento si añades nuevas categorías

---

**Licencia**: MIT
**Copyright**: © 2025 PalmeraDAO
