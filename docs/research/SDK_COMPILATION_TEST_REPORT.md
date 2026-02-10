# SDK Compilation Test Report

**Status**: WORKAROUND FOUND - Contradicts previous "no solution" conclusion
**Date**: 2026-02-06
**Environment**: macOS ARM64 (Darwin 24.6.0)
**Affects**: linera-sdk 0.15.11 Wasm compilation

---

## Executive Summary

Four test scenarios were run to validate the documented opcode 252 blocker (see [LINERA_OPCODE_252_ISSUE.md](LINERA_OPCODE_252_ISSUE.md)). The results **contradict** the previous conclusion that "no working combination exists."

**Key finding**: The compilation failure attributed to `async-graphql 7.0.17` is actually caused by Cargo resolving the sub-dependency `async-graphql-value` to version **7.2.1**, which requires Rust 1.89+. When sub-crates are pinned to `=7.0.17`, linera-sdk 0.15.11 compiles cleanly on **Rust 1.86.0** with zero `memory.copy` opcodes.

---

## Test Environment

| Component | Value |
|-----------|-------|
| OS | macOS ARM64 (Darwin 24.6.0) |
| Rust stable | 1.87.0 (17067e9ac 2025-05-09) |
| Rust pinned | 1.86.0 (05f9846f8 2025-03-31) |
| Cargo | 1.87.0 (99624be96 2025-05-06) |
| linera-sdk | 0.15.11 |
| Wasm target | wasm32-unknown-unknown |
| Test date | 2026-02-06 |

---

## Test Scenarios

### Summary Table

| # | Rust | Sub-crates pinned? | Compiles? | memory.copy | memory.fill |
|---|------|--------------------|-----------|-------------|-------------|
| 1 | 1.87.0 | No | FAIL | N/A | N/A |
| 2 | 1.87.0 | Yes (`=7.0.17`) | OK | **25** | **17** |
| 3 | 1.86.0 | Yes (`=7.0.17`) | OK | **0** | **0** |
| 4 | 1.86.0 | No | FAIL | N/A | N/A |

### Scenario 1: Rust 1.87.0 without pinned sub-crates

**Cargo.toml**:

```toml
[dependencies]
linera-sdk = "0.15.11"
```

**Command**:

```bash
cargo build --target wasm32-unknown-unknown --release
```

**Result**: FAIL

Cargo resolved `async-graphql-value` to 7.2.1, which uses `let`-chain syntax (`&& let`) stabilized in Rust 1.89:

```
error[E0658]: `let` expressions in this position are unstable
  --> async-graphql-value-7.2.1/src/value_serde.rs:32:24
   |
32 |     && let Some(ConstValue::String(v)) = v.get(RAW_VALUE_TOKEN)
   |        ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
```

Cargo lock output confirmed the resolution:

```
Adding async-graphql v7.0.17 (available: v7.2.1, requires Rust 1.89.0)
Adding async-graphql-parser v7.2.1
Adding async-graphql-value v7.2.1
```

### Scenario 2: Rust 1.87.0 WITH pinned sub-crates

**Cargo.toml**:

```toml
[dependencies]
linera-sdk = "0.15.11"
async-graphql-value = "=7.0.17"
async-graphql-parser = "=7.0.17"
```

**Command**:

```bash
cargo build --target wasm32-unknown-unknown --release
```

**Result**: Compiles successfully (33.48s)

**Binary analysis** (149,532 bytes):

```
Opcode 0xFC (bulk-memory prefix): 165
memory.copy (0xFC 0x0A):          25
memory.fill (0xFC 0x0B):          17
TARGET FEATURE: bulk-memory DECLARED
Compiled with: rustc 1.87.0
```

Conclusion: Compiles, but binary contains opcode 252. Would fail at Linera runtime deployment.

### Scenario 3: Rust 1.86.0 WITH pinned sub-crates

**Cargo.toml**: Same as Scenario 2.

**Command**:

```bash
cargo +1.86.0 build --target wasm32-unknown-unknown --release
```

**Result**: Compiles successfully (33.70s)

**Binary analysis** (149,872 bytes):

```
Opcode 0xFC (bulk-memory prefix): 123
memory.copy (0xFC 0x0A):          0
memory.fill (0xFC 0x0B):          0
TARGET FEATURE: bulk-memory NOT declared
Compiled with: rustc 1.86.0
```

Conclusion: Clean Wasm. No opcode 252. Deployable to Linera runtime.

### Scenario 4: Rust 1.86.0 without pinned sub-crates

**Cargo.toml**: Same as Scenario 1.

**Command**:

```bash
cargo +1.86.0 build --target wasm32-unknown-unknown --release
```

**Result**: FAIL - identical error to Scenario 1 (`async-graphql-value 7.2.1` uses `let`-chains).

---

## Corrected Dependency Chain

### Previous understanding (INCORRECT)

```
linera-sdk 0.15.11
  -> async-graphql = "=7.0.17"
      -> REQUIRES Rust 1.87+ (for let-chain syntax)   <-- WRONG
```

### Actual dependency chain

```
linera-sdk 0.15.11
  -> async-graphql = "=7.0.17"        (exact pin, correct)
      -> async-graphql-value ^7.0.17   (caret = allows 7.2.1)
      -> async-graphql-parser ^7.0.17  (caret = allows 7.2.1)
          -> Cargo resolves to 7.2.1   (latest semver-compatible)
              -> Rust 1.89+ required   (let-chain syntax)
```

The confusion arose because `async-graphql 7.0.17` uses caret (`^`) dependencies for its sub-crates. Cargo's semver resolution picks the latest compatible version (7.2.1), which was published after the original investigation and requires a newer Rust.

### The fix

Pin the sub-crates explicitly:

```toml
async-graphql-value = "=7.0.17"
async-graphql-parser = "=7.0.17"
```

This forces Cargo to use the same version the SDK was developed against.

---

## Workaround

### Step 1: Pin dependencies in Cargo.toml

```toml
[dependencies]
linera-sdk = "0.15.11"
serde = { version = "1.0", features = ["derive"] }
serde_json = "1.0"
log = "0.4"

# Pin sub-crates to match linera-sdk's async-graphql version
async-graphql-value = "=7.0.17"
async-graphql-parser = "=7.0.17"
```

### Step 2: Pin Rust toolchain

Create `rust-toolchain.toml`:

```toml
[toolchain]
channel = "1.86.0"
targets = ["wasm32-unknown-unknown"]
```

### Step 3: Build

```bash
cargo build --release --target wasm32-unknown-unknown
```

---

## Additional Finding: linera-sdk Feature Flags

The existing test scripts reference `features = ["contract", "service"]` for linera-sdk. These features **do not exist** in version 0.15.11.

Actual features available in linera-sdk 0.15.11:

```
async-trait, ethereum, linera-ethereum, test, wasmer, wasmtime
```

Any script or Cargo.toml referencing `contract` or `service` features will fail with:

```
error: failed to select a version for `linera-sdk`.
the package depends on `linera-sdk`, with features: `contract`
but `linera-sdk` does not have these features.
```

---

## Corrections to Previous Documentation

| Previous claim | Status | Evidence |
|----------------|--------|----------|
| "async-graphql 7.0.17 requires Rust 1.87+" | INCORRECT | Compiles on 1.86 when sub-crates are pinned to 7.0.17 |
| "No working combination exists" | INCORRECT | Rust 1.86 + pinned sub-crates works |
| "SDK 0.15.11 incompatible with Rust 1.86" | INCORRECT | Fully compatible with pinned sub-crates |
| "Requires Linera team action" | PARTIALLY CORRECT | Workaround exists, but official fix still needed |
| "-C target-feature=-bulk-memory solves it" | INCORRECT | Flag alone does not prevent Rust 1.87 from emitting memory.copy |

---

## Binary Comparison

| Metric | Rust 1.87.0 (pinned) | Rust 1.86.0 (pinned) |
|--------|----------------------|----------------------|
| Binary size | 149,532 bytes | 149,872 bytes |
| 0xFC prefix count | 165 | 123 |
| memory.copy (0xFC 0x0A) | 25 | 0 |
| memory.fill (0xFC 0x0B) | 17 | 0 |
| bulk-memory declared | Yes | No |
| Linera deployable | No | Yes |

The 0xFC bytes in the Rust 1.86 binary are `i32.trunc_sat_f32_s` and similar non-bulk-memory opcodes that happen to share the same prefix byte but are supported by Linera's runtime.

---

## Conway Testnet Deployment Validation

The Rust 1.86 + pinned sub-crates Wasm binary was tested against Conway testnet (v0.15.11).

### CLI Tests

| Test | Result |
|------|--------|
| Wallet init from faucet | PASS |
| Request chain with owner key | PASS |
| Multi-owner chain creation | PASS |
| Validator sync | PASS |

### Wasm Deployment Tests

| Test | Result | Details |
|------|--------|---------|
| `linera publish-module` | PASS | Module accepted by all validators, published in 2102 ms |
| `linera publish-and-create` | Expected failure | Module accepted, but application creation fails because test code doesn't implement `linera:app/contract-entrypoints#instantiate` |

The `publish-module` success confirms:

- The Wasm binary contains no unsupported opcodes
- Linera validators accept Rust 1.86 compiled bytecode
- The opcode 252 blocker is resolved with this workaround

The `publish-and-create` failure is a **code completeness issue**, not a platform blocker. The test `lib.rs` exports a simple function, not the full Linera contract interface. Building the complete `scripts/multisig-app/` with its `contract.rs` and `service.rs` implementing the proper Linera entrypoints would resolve this.

---

## References

- [LINERA_OPCODE_252_ISSUE.md](LINERA_OPCODE_252_ISSUE.md) - Previous investigation (contains incorrect claims corrected above)
- [OPCODE_252_INVESTIGATION_LOG.md](OPCODE_252_INVESTIGATION_LOG.md) - Original investigation log
- [linera-protocol#4742](https://github.com/linera-io/linera-protocol/issues/4742) - Official issue
- [linera-protocol#4894](https://github.com/linera-io/linera-protocol/pull/4894) - ruzstd 0.8.1 pin (separate fix)

---

**Last Updated**: 2026-02-06
