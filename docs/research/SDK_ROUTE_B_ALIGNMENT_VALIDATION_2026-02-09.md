# SDK Route B Alignment Validation (2026-02-09)

## Scope

This report documents the execution of **Route B**:

- Keep contract dependencies on `linera-sdk = 0.15.11`
- Align runtime/CLI environment to Linera protocol `0.15.11`
- Re-run end-to-end validation for opcode compliance and deployment (`create-application`)

Per prior request, these files were not edited:

- `docs/research/SDK_COMPILATION_TEST_REPORT.md`
- `docs/research/SDK_FIX_GUIDE.md`

## Route B Changes Applied

### 1) Added dedicated Route B validator

- New script: `scripts/validate-route-b.sh`
  - Verifies `linera-sdk` version in `scripts/multisig-app/Cargo.toml`
  - Verifies selected `linera` binary protocol version matches SDK version
  - Supports local aligned net/faucet execution
  - Runs canonical validator (`scripts/validate-sdk-workaround.sh`) with create-app smoke gate

### 2) Makefile integration

- Updated `scripts/Makefile` with:
  - `route-b-check`
  - `validate-route-b`

### 3) Toolchain execution hardening

- Updated `scripts/validate-sdk-workaround.sh` and `scripts/Makefile` to use explicit toolchain binaries from `rustup which`:
  - fixes environment where `rustup run <toolchain> cargo` can still invoke non-toolchain `rustc`

### 4) Installed aligned local Linera binaries (workspace-local)

Installed into:

- `.tools/linera-0.15.11/bin/`

Packages installed:

- `linera-service v0.15.11`
- `linera-storage-service v0.15.11`

This enabled local Route B validation without modifying global user binaries.

## Validation Evidence

## A) Route B alignment check (PASS)

Command:

```bash
LINERA_BIN="$PWD/.tools/linera-0.15.11/bin/linera" make -C scripts route-b-check
```

Observed:

- `linera-sdk (app): 0.15.11`
- `linera protocol: 0.15.11`
- Check completed successfully

## B) Route B full validation in aligned local environment

Command:

```bash
LINERA_BIN="$PWD/.tools/linera-0.15.11/bin/linera" bash scripts/validate-route-b.sh
```

Observed (successful alignment path):

1. SDK/protocol aligned (`0.15.11`)
2. Local faucet started (`http://127.0.0.1:<port>`)
3. Build succeeded with Rust `1.86.0`
4. Opcode gate passed:
   - `multisig_contract.wasm`: `memory.copy=0`, `memory.fill=0`
   - `multisig_service.wasm`: `memory.copy=0`, `memory.fill=0`
5. `create-application` failed with:

```text
Execution error: Failed to execute Wasm module: RuntimeError: unreachable during Operation(0)
```

## C) Additional environment-side observations

- Some runs may fail before validation with:
  - `Error is Failed to obtain a port` (localnet startup race/resource issue)
- Using remote faucet from this sandbox environment may trigger:
  - `system-configuration ... Attempted to create a NULL object`

These are environmental and do not change the core Route B conclusion below.

## Final Result

Route B was **applied successfully** for version alignment:

- App SDK: `0.15.11`
- Runtime/CLI used for validation: `0.15.11`

However, the core deployment blocker is **not fully resolved**:

- Opcode-252 workaround: ✅ resolved for Wasm artifacts
- Full app instantiation (`create-application`): ❌ still failing (`unreachable during Operation(0)`) even after alignment

## Interpretation

Version mismatch (`0.15.11` vs `0.15.8`) was a real risk, but it is **not** the sole root cause of the remaining failure.

The current blocker has moved from "version skew" to "runtime trap during operation execution" in the custom contract lifecycle.

## Recommended Next Debug Batch

1. Isolate initialization trap path in `scripts/multisig-app/src/contract.rs`:
   - instrument and minimize `instantiate()` path
   - test progressively from minimal state initialization to full logic
2. Add deterministic create-app regression script that logs exact argument payload and validator-side failure context.
3. Rehabilitate contract tests in `scripts/multisig-app/tests/multisig_tests.rs` to reproduce this trap pre-deploy.

