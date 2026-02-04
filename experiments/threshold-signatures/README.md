# Experimento: Threshold Signatures Alternative

> **Branch**: `feature/threshold-signatures-alternative`
> **Estado**: 🔴 **BLOCKED** - Opcode 252 aún presente
> **Fecha**: 2026-02-04

---

## Resultado: ❌ NO EVITA OPCODE 252

### Hallazgos

```
Wasm Contract: linera_threshold_multisig.wasm
Tamaño: ~292 KB
Opcode 252 (memory.copy): 73 instancias detectadas
Compilación: Exitosa ✅
Deploy: FALLEARÍA en Linera testnet 🔴
```

### Análisis

Incluso con un contrato **extremadamente simplificado** que:

- ❌ NO verifica firmas criptográficamente (ed25519-dalek removido)
- ❌ NO tiene lógica compleja de proposals
- ❌ NO usa GraphQL para operaciones
- ✅ Solo mantiene estado básico (owners, threshold, nonce, aggregate_key)

El bytecode Wasm **AÚN CONTIENE** el opcode 252 (`memory.copy`).

### Causa Raíz

El problema **NO está en nuestro código de contrato**. El opcode 252 es generado por las dependencias del `linera-sdk`:

```
linera-sdk 0.15.11
    └─ async-graphql = "=7.0.17" (version pin)
        └─ requiere Rust 1.87+ (para let-chain syntax)
            └─ genera memory.copy (opcode 252)
                └─ Linera runtime NO lo soporta
```

**Incluso usando `async-graphql` solo para el ABI** (sin operaciones GraphQL), el bytecode generado por el linera-sdk incluye el opcode 252.

---

## Pruebas Realizadas

### 1. Compilación ✅

```bash
cargo build --release --target wasm32-unknown-unknown
```

**Resultado**: Exitoso
- Wasm generado: `linera_threshold_multisig.wasm` (~292 KB)

### 2. Verificación de Opcode 252 🔴

```bash
wasm-objdump -d linera_threshold_multisig.wasm | grep "memory.copy"
```

**Resultado**: 73 instancias de `memory.copy` encontradas

```wasm
004569: fc 0a 00 00    | memory.copy 0 0
00486a: fc 0a 00 00    | memory.copy 0 0
008171: fc 0a 00 00    | memory.copy 0 0
...
```

### 3. Análisis de Dependencias 🔴

```bash
cargo tree | grep async-graphql
```

```
linera-threshold-multisig v0.1.0
└── linera-sdk v0.15.11
    └── async-graphql v7.0.17
```

**Confirma**: `async-graphql = "=7.0.17"` es dependencia transitiva obligatoria de `linera-sdk`.

---

## Conclusiones

### ❌ Threshold Signatures NO es una Solución Viable

El enfoque de threshold signatures **NO PUEDE evitar** el opcode 252 porque:

1. **El problema no es nuestro código**: Incluso un contrato minimalista contiene el opcode
2. **El problema es el linera-sdk**: La dependencia `async-graphql = "=7.0.17"` es obligatoria
3. **No hay workaround posible**: Cualquier contrato que use `linera-sdk` tendrá el opcode 252

### Comparación con Arquitectura Original

| Aspecto | Original (bloqueada) | Threshold (este) |
|---------|---------------------|-------------------|
| **Lógica Contract** | Proposal state machine | Threshold signatures |
| **Complejidad** | Alta | Muy baja |
| **async-graphql** | ✅ Usado (operaciones) | ✅ Usado (solo ABI) |
| **Opcode 252** | 🔴 Presente | 🔴 **Presente** |
| **Resultado** | ❌ No deploya | ❌ **No deploya** |

### Misma Causa Raíz, Misma Conclusión

Ambos enfoques están **bloqueados por el mismo problema del ecosistema linera-sdk**.

---

## Implicaciones

### Para este Proyecto

1. **No existe solución de contrato Wasm** mientras `linera-sdk 0.15.x` tenga `async-graphql = "=7.0.17"`
2. **Threshold signatures NO es la respuesta** - el problema es más profundo
3. **Solución requiere acción del Linera team** - issue #4742

### Para el Desarrollo

**Opciones Restantes**:

1. **Esperar a Linera SDK** - Recomendado, pero sin timeline
   - Issue: https://github.com/linera-io/linera-protocol/issues/4742

2. **Usar solo multi-owner chains** - Self-custodial pero 1-of-N
   - Cualquier owner puede ejecutar sin aprobaciones
   - NO es un multisig tipo Safe

3. **Cambiar de blockchain** - Única alternativa viable con multisig funcionando
   - Hathor (multisig verificada)
   - Ethereum (Gnosis Safe)

---

## Archivos del Experimento

```
experiments/threshold-signatures/
├── Cargo.toml                  # Configuración
├── README.md                   # Este archivo
├── docs/
│   └── ARCHITECTURE.md         # Arquitectura técnica detallada
└── src/
    ├── lib.rs                  # Contrato Wasm simplificado
    ├── state.rs                # Estado del contrato
    └── operations.rs           # Operaciones
```

---

## Próximos Pasos

### Inmediatos

1. ✅ Documentar resultados en README.md
2. ✅ Commit al branch `feature/threshold-signatures-alternative`
3. ⏳ Reportar hallazgos al usuario

### Para el Repositorio Principal

1. ⏳ Actualizar `docs/INFRASTRUCTURE_ANALYSIS.md` con estos hallazgos
2. ⏳ Agregar sección sobre "Enfoques Alternativos Intentados"
3. ⏳ Mantener status como "BLOCKED" hasta resolución del Linera team

---

## Referencias

- **Original Opcode 252 Analysis**: `docs/research/LINERA_OPCODE_252_ISSUE.md`
- **Linera SDK Issue**: https://github.com/linera-io/linera-protocol/issues/4742
- **Branch**: `feature/threshold-signatures-alternative`

---

**Última actualización**: 2026-02-04
**Conclusión**: Threshold signatures **NO es una solución viable** para el opcode 252.
