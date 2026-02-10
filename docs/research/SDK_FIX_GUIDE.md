# Linera SDK Opcode 252 Fix Guide

**Date**: 2026-02-06
**Affects**: linera-sdk 0.15.11, Wasm compilation, Conway testnet deployment

This document explains the three issues discovered during SDK validation testing, how each was diagnosed, and the exact code changes applied to fix them.

---

## Table of Contents

1. [Issue 1: Cargo Resolves Wrong async-graphql Sub-crate Versions](#issue-1-cargo-resolves-wrong-async-graphql-sub-crate-versions)
2. [Issue 2: Rust 1.87+ Emits Unsupported Wasm Opcodes](#issue-2-rust-187-emits-unsupported-wasm-opcodes)
3. [Issue 3: Scripts Reference Non-existent linera-sdk Features](#issue-3-scripts-reference-non-existent-linera-sdk-features)
4. [Files Changed Summary](#files-changed-summary)
5. [Configuration Reference](#configuration-reference)
6. [Verification](#verification)

---

## Issue 1: Cargo Resolves Wrong async-graphql Sub-crate Versions

### Diagnosis

`linera-sdk 0.15.11` pins `async-graphql = "=7.0.17"` (exact version). However, `async-graphql 7.0.17` declares caret dependencies on its sub-crates:

```
async-graphql 7.0.17
  -> async-graphql-value ^7.0.17   (caret = "7.0.17 or newer compatible")
  -> async-graphql-parser ^7.0.17  (caret = "7.0.17 or newer compatible")
```

Cargo's semver resolver picks the **latest compatible version**, which is `7.2.1`. That version uses `let`-chain syntax (`&& let Some(...)`) stabilized in Rust 1.89, causing a compile error on any Rust < 1.89:

```
error[E0658]: `let` expressions in this position are unstable
  --> async-graphql-value-7.2.1/src/value_serde.rs:32:24
   |
32 |     && let Some(ConstValue::String(v)) = v.get(RAW_VALUE_TOKEN)
   |        ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
```

### Fix: Pin Sub-crates in Cargo.toml

Force Cargo to use the exact versions the SDK was developed against.

#### `scripts/multisig-app/Cargo.toml`

**Before:**

```toml
[dependencies]
linera-sdk = { version = "0.15.11" }
serde = { version = "1.0", features = ["derive"] }
serde_json = "1.0"
log = "0.4"
async-graphql = "7.0"
```

**After:**

```toml
[dependencies]
linera-sdk = { version = "0.15.11" }
serde = { version = "1.0", features = ["derive"] }
serde_json = "1.0"
log = "0.4"

# Pin async-graphql sub-crates to 7.0.17 to match linera-sdk's pinned version.
# Without this, Cargo resolves to 7.2.1 which requires Rust 1.89.0+.
async-graphql-value = "=7.0.17"
async-graphql-parser = "=7.0.17"
```

**What changed**: Removed the direct `async-graphql = "7.0"` dependency (it's already pulled in transitively by linera-sdk). Added exact pins (`=7.0.17`) for the two sub-crates that Cargo was resolving incorrectly.

#### `scripts/multisig-test-rust.sh` (`create_cargo_toml` function)

**Before** (lines 485-516):

```bash
create_cargo_toml() {
    log_info "Creating Cargo.toml..."

    cat > Cargo.toml <<EOF
[package]
name = "linera-multisig"
version = "0.1.0"
edition = "2021"

[lib]
crate-type = ["cdylib", "rlib"]

[dependencies]
linera-sdk = { version = "${LINERA_SDK_VERSION}", features = ["contract", "service"] }
linera-views = { version = "${LINERA_SDK_VERSION}" }
serde = { version = "1.0", features = ["derive"] }
serde_json = "1.0"
log = "0.4"

[dev-dependencies]
linera-sdk = { version = "${LINERA_SDK_VERSION}", features = ["test"] }

[features]
default = ["contract", "service"]
contract = ["linera-sdk/contract"]
service = ["linera-sdk/service"]
test = ["linera-sdk/test"]
EOF

    log_success "Cargo.toml created"
}
```

**After** (lines 485-513):

```bash
create_cargo_toml() {
    log_info "Creating Cargo.toml..."

    cat > Cargo.toml <<EOF
[package]
name = "linera-multisig"
version = "0.1.0"
edition = "2021"

[lib]
crate-type = ["cdylib", "rlib"]

[dependencies]
linera-sdk = { version = "${LINERA_SDK_VERSION}" }
serde = { version = "1.0", features = ["derive"] }
serde_json = "1.0"
log = "0.4"

# Pin async-graphql sub-crates to 7.0.17 to match linera-sdk's pinned version.
# Without this, Cargo resolves to 7.2.1 which requires Rust 1.89.0+.
async-graphql-value = "=7.0.17"
async-graphql-parser = "=7.0.17"

[dev-dependencies]
linera-sdk = { version = "${LINERA_SDK_VERSION}", features = ["test"] }
EOF

    log_success "Cargo.toml created"
}
```

**What changed**:

- Removed `features = ["contract", "service"]` from linera-sdk (see Issue 3)
- Removed `linera-views` dependency (not needed for the test project)
- Removed entire `[features]` section (referenced non-existent features)
- Added `async-graphql-value` and `async-graphql-parser` pins

---

## Issue 2: Rust 1.87+ Emits Unsupported Wasm Opcodes

### Diagnosis

Rust 1.87.0 ships with an LLVM backend that emits `memory.copy` (opcode `0xFC 0x0A`) and `memory.fill` (opcode `0xFC 0x0B`) instructions for the `wasm32-unknown-unknown` target. These are part of the WebAssembly bulk-memory extension.

Linera's Wasm runtime (`linera-kywasmtime`) does not support bulk-memory operations and rejects any module containing opcode 252 (`0xFC`).

Binary analysis from our test:

| Metric | Rust 1.87.0 | Rust 1.86.0 |
|--------|-------------|-------------|
| Binary size | 149,532 bytes | 149,872 bytes |
| memory.copy (0xFC 0x0A) | **25** | **0** |
| memory.fill (0xFC 0x0B) | **17** | **0** |
| bulk-memory declared | Yes | No |
| Linera deployable | No | **Yes** |

The `-C target-feature=-bulk-memory` compiler flag does NOT prevent these opcodes in Rust 1.87+. Rust 1.86.0 is the last version that produces clean Wasm.

### Fix: Pin Rust 1.86.0 via rust-toolchain.toml

#### `scripts/multisig-app/rust-toolchain.toml` (new file)

This file did not exist before. When present in a project directory, `rustup` automatically selects the specified toolchain.

```toml
# Rust toolchain for Linera Wasm compilation
#
# Rust 1.86.0 is required to avoid memory.copy opcodes (opcode 252).
# Rust 1.87+ generates bulk memory operations that Linera's runtime rejects.
# See docs/research/SDK_COMPILATION_TEST_REPORT.md for details.

[toolchain]
channel = "1.86.0"
components = ["rust-src", "rustfmt", "clippy"]
targets = ["wasm32-unknown-unknown"]
profile = "minimal"
```

**Why this works**: `rustup` reads `rust-toolchain.toml` before every `cargo` invocation and switches to the specified toolchain automatically. No manual `+1.86.0` flag needed.

#### `scripts/multisig-app/.cargo/config.toml` (updated comments)

**Before:**

```toml
# Cargo config for Linera Wasm compilation
# Configured to avoid unsupported opcodes like memory.copy (0xFC 0x0A)

[build]
target = "wasm32-unknown-unknown"

[target.wasm32-unknown-unknown]
# Rust compiler flags for Wasm
# -C opt-level=s: Optimize for size while maintaining performance
# -C lto=false: Disable link-time optimization (reduces optimization passes)
# -C codegen-units=1: Single codegen unit for reproducibility
rustflags = [
    "-C", "opt-level=s",
    "-C", "lto=no",
    "-C", "codegen-units=1",
    # Avoid bulk memory operations which may not be supported by Linera
    "-C", "target-feature=-bulk-memory",
]

[profile.release]
# Release profile optimized for Linera Wasm
opt-level = "s"
lto = false
codegen-units = 1
panic = "abort"
strip = true
```

**After:**

```toml
# Cargo config for Linera Wasm compilation
# Configured to avoid unsupported opcodes like memory.copy (0xFC 0x0A)
#
# NOTE: The target-feature=-bulk-memory flag alone is NOT sufficient to prevent
# memory.copy opcodes in Rust 1.87+. You MUST use Rust 1.86.0 via
# rust-toolchain.toml. See docs/research/SDK_COMPILATION_TEST_REPORT.md.

[build]
target = "wasm32-unknown-unknown"

[target.wasm32-unknown-unknown]
# Rust compiler flags for Wasm
# -C opt-level=s: Optimize for size while maintaining performance
# -C lto=false: Disable link-time optimization (reduces optimization passes)
# -C codegen-units=1: Single codegen unit for reproducibility
# -C target-feature=-bulk-memory: Supplementary flag (requires Rust 1.86 to be effective)
rustflags = [
    "-C", "opt-level=s",
    "-C", "lto=no",
    "-C", "codegen-units=1",
    "-C", "target-feature=-bulk-memory",
]

[profile.release]
# Release profile optimized for Linera Wasm
opt-level = "s"
lto = false
codegen-units = 1
panic = "abort"
strip = true
```

**What changed**: Added `NOTE` header explaining that `target-feature=-bulk-memory` alone is insufficient. Updated inline comment for the flag from "Avoid bulk memory operations" to "Supplementary flag (requires Rust 1.86 to be effective)".

#### `scripts/multisig-test-rust.sh` (new `create_rust_toolchain` function)

**Added** after `create_cargo_toml()`:

```bash
create_rust_toolchain() {
    log_info "Creating rust-toolchain.toml (pinning Rust 1.86.0)..."

    cat > rust-toolchain.toml <<'EOF'
# Rust 1.86.0 is required to avoid memory.copy opcodes (opcode 252).
# Rust 1.87+ generates bulk memory operations that Linera's runtime rejects.
# See docs/research/SDK_COMPILATION_TEST_REPORT.md for details.

[toolchain]
channel = "1.86.0"
components = ["rust-src", "rustfmt", "clippy"]
targets = ["wasm32-unknown-unknown"]
profile = "minimal"
EOF

    log_success "rust-toolchain.toml created"
}
```

**And** in the `main()` function, added the call:

**Before:**

```bash
    create_project
    create_contract
    create_service
    create_main
    create_cargo_toml
    create_tests
    create_makefile
    create_readme
```

**After:**

```bash
    create_project
    create_contract
    create_service
    create_main
    create_cargo_toml
    create_rust_toolchain
    create_tests
    create_makefile
    create_readme
```

#### `scripts/Makefile` (new toolchain check + build fix)

**Before:**

```makefile
.PHONY: help init cli-test rust-test clean all

LINERA_SDK_VERSION ?= 0.12.0
```

**After:**

```makefile
.PHONY: help init cli-test rust-test rust-check-toolchain clean all

LINERA_SDK_VERSION ?= 0.15.11
```

**Before** (`rust-build` target):

```makefile
rust-build:
 @echo "$(BLUE)=== Building Rust Multisig Application ===$(NC)"
 @if [ -d "$(PROJECT_DIR)" ]; then \
  cd $(PROJECT_DIR) && \
  cargo build --release --features contract,service; \
  echo "$(GREEN)Build complete$(NC)"; \
 else \
  echo "$(RED)Project not found. Run 'make rust-test' first.$(NC)"; \
  exit 1; \
 fi
```

**After** (`rust-build` + `rust-check-toolchain` targets):

```makefile
rust-check-toolchain:
 @echo "$(BLUE)=== Checking Rust Toolchain ===$(NC)"
 @RUST_VERSION=$$(rustc --version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+' | head -1); \
 if [ "$$RUST_VERSION" = "1.86" ]; then \
  echo "$(GREEN)Rust 1.86 detected$(NC)"; \
 else \
  echo "$(YELLOW)Warning: Rust $$RUST_VERSION detected. Rust 1.86.0 required for Linera Wasm.$(NC)"; \
  echo "$(YELLOW)Run: rustup install 1.86.0$(NC)"; \
  echo "$(YELLOW)Projects with rust-toolchain.toml will use 1.86 automatically.$(NC)"; \
 fi

rust-build: rust-check-toolchain
 @echo "$(BLUE)=== Building Rust Multisig Application ===$(NC)"
 @if [ -d "$(PROJECT_DIR)" ]; then \
  cd $(PROJECT_DIR) && \
  cargo build --release --target wasm32-unknown-unknown; \
  echo "$(GREEN)Build complete$(NC)"; \
 else \
  echo "$(RED)Project not found. Run 'make rust-test' first.$(NC)"; \
  exit 1; \
 fi
```

**What changed**:

- `LINERA_SDK_VERSION`: `0.12.0` -> `0.15.11`
- `rust-build`: Removed `--features contract,service`, added `--target wasm32-unknown-unknown`, added `rust-check-toolchain` dependency
- New `rust-check-toolchain` target: Validates Rust version and warns if not 1.86

---

## Issue 3: Scripts Reference Non-existent linera-sdk Features

### Diagnosis

The build scripts and Cargo.toml files used `features = ["contract", "service"]` for linera-sdk. These features do **not exist** in version 0.15.11.

Actual features in linera-sdk 0.15.11 (verified via `cargo info linera-sdk`):

```
async-trait, ethereum, linera-ethereum, test, wasmer, wasmtime
```

Attempting to build with non-existent features produces:

```
error: failed to select a version for `linera-sdk`.
the package depends on `linera-sdk`, with features: `contract`
but `linera-sdk` does not have these features.
```

### Fix: Remove Non-existent Features

All references to `features = ["contract", "service"]` were removed. See the code diffs in Issue 1 (Cargo.toml) and Issue 2 (Makefile) above.

Specifically removed from:

- `scripts/multisig-app/Cargo.toml`: `async-graphql = "7.0"` (replaced with sub-crate pins)
- `scripts/multisig-test-rust.sh`: `features = ["contract", "service"]` from linera-sdk dependency, `linera-views` dependency, entire `[features]` section
- `scripts/Makefile`: `--features contract,service` from `rust-build` target

---

## Files Changed Summary

| File | Action | Changes |
|------|--------|---------|
| `scripts/multisig-app/Cargo.toml` | Modified | Replaced `async-graphql = "7.0"` with pinned sub-crates |
| `scripts/multisig-app/rust-toolchain.toml` | Created | Pins Rust 1.86.0 with wasm32 target |
| `scripts/multisig-app/.cargo/config.toml` | Modified | Added warning about `-bulk-memory` flag limitations |
| `scripts/multisig-test-rust.sh` | Modified | Fixed Cargo.toml template, added `create_rust_toolchain()`, updated `main()` |
| `scripts/Makefile` | Modified | SDK version 0.15.11, removed bad features, added toolchain check |
| `multisig-app/rust-toolchain.toml` | Created | Test project toolchain pin |
| `multisig-app/.cargo/config.toml` | Created | Test project Wasm build config |
| `.gitignore` | Modified | Added `multisig-app/Cargo.lock` |
| `docs/research/SDK_COMPILATION_TEST_REPORT.md` | Created | Full test report with 4 scenarios |

---

## Configuration Reference

### Minimum Viable Linera Wasm Project

A Linera SDK project that compiles to clean Wasm requires three configuration files:

#### 1. `Cargo.toml`

```toml
[package]
name = "my-linera-app"
version = "0.1.0"
edition = "2021"

[lib]
crate-type = ["cdylib", "rlib"]

[dependencies]
linera-sdk = { version = "0.15.11" }
serde = { version = "1.0", features = ["derive"] }

# Required: pin these to avoid Rust 1.89+ requirement
async-graphql-value = "=7.0.17"
async-graphql-parser = "=7.0.17"
```

#### 2. `rust-toolchain.toml`

```toml
[toolchain]
channel = "1.86.0"
targets = ["wasm32-unknown-unknown"]
```

#### 3. `.cargo/config.toml`

```toml
[build]
target = "wasm32-unknown-unknown"

[target.wasm32-unknown-unknown]
rustflags = [
    "-C", "opt-level=s",
    "-C", "codegen-units=1",
    "-C", "target-feature=-bulk-memory",
]

[profile.release]
opt-level = "s"
panic = "abort"
```

#### Build Command

```bash
cargo build --release --target wasm32-unknown-unknown
```

No `--features` flags needed. The `rust-toolchain.toml` ensures Rust 1.86 is used automatically.

---

## Verification

### Binary Opcode Check

After building, verify the Wasm binary contains zero `memory.copy` opcodes:

```bash
python3 -c "
data = open('target/wasm32-unknown-unknown/release/my_linera_app.wasm','rb').read()
mc = sum(1 for i in range(len(data)-1) if data[i]==0xFC and data[i+1]==0x0A)
mf = sum(1 for i in range(len(data)-1) if data[i]==0xFC and data[i+1]==0x0B)
print(f'memory.copy: {mc}')
print(f'memory.fill: {mf}')
assert mc == 0 and mf == 0, 'FAIL: bulk-memory opcodes found'
print('PASS: clean Wasm binary')
"
```

### Conway Testnet Deployment

The fix was validated end-to-end on Conway testnet (v0.15.11):

```bash
# Publish module to testnet validators
linera publish-module \
  target/wasm32-unknown-unknown/release/linera_multisig.wasm

# Result: Module accepted by all validators (2102 ms)
```

All four validators accepted the Wasm binary, confirming zero unsupported opcodes.

---

## References

- [SDK_COMPILATION_TEST_REPORT.md](SDK_COMPILATION_TEST_REPORT.md) - Full test report with 4 scenarios
- [LINERA_OPCODE_252_ISSUE.md](LINERA_OPCODE_252_ISSUE.md) - Original issue documentation
- [linera-protocol#4742](https://github.com/linera-io/linera-protocol/issues/4742) - Upstream issue

---

**Last Updated**: 2026-02-06
