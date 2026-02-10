# SDK Opcode 252 Workaround - E2E Validation (2026-02-09)

## Scope

This validation was executed after merging `fix/sdk-opcode-252-workaround` to determine:

1. Whether the opcode workaround fully resolves `opcode 252` compilation/deployment blockers.
2. Whether the custom multisig contract is deployable end-to-end (`publish-module` + `create-application`).
3. Whether current test assets provide reliable evidence.

Per request, the following files were not edited:

- `docs/research/SDK_COMPILATION_TEST_REPORT.md`
- `docs/research/SDK_FIX_GUIDE.md`

## Codebase Layout Clarification (PoC vs Canonical)

- Canonical custom contract (current integration target):
  - `scripts/multisig-app/`
- PoC moved to isolated folder:
  - `experiments/poc-sdk-opcode-252/multisig-app/`

This separation removes ambiguity between production-integration code and experimental workaround code.

## Executed Validations

### 1) Opcode and Build Validation (canonical app)

Command:

```bash
bash scripts/validate-sdk-workaround.sh
```

Result:

- Build succeeded with Rust `1.86.0`.
- `multisig_contract.wasm`: `memory.copy=0`, `memory.fill=0`
- `multisig_service.wasm`: `memory.copy=0`, `memory.fill=0`

Conclusion: opcode workaround is effective for Wasm generation (no bulk-memory opcodes).

---

### 2) Makefile Integration Validation

Command:

```bash
make -C scripts validate-workaround
```

Result:

- Toolchain gate passed.
- Build passed.
- Opcode gate passed.

Conclusion: workaround is integrated in the script-level build flow.

---

### 3) Network Publish Validation

Command:

```bash
RUN_TESTNET_DEPLOY=1 bash scripts/validate-sdk-workaround.sh
```

Result:

- `publish-module` succeeded.

Conclusion: bytecode can be published to the network.

---

### 4) Create-Application Smoke Validation (new e2e gate)

Command:

```bash
RUN_CREATE_APP_SMOKE=1 bash scripts/validate-sdk-workaround.sh
```

Result:

- `create-application` failed with:

```text
Execution error: Failed to execute Wasm module: RuntimeError: unreachable during Operation(0)
```

Conclusion: deployment is only partially successful. Publish works; instantiation currently fails.

---

### 5) Existing Rust Test Suite Status

Command:

```bash
cd scripts/multisig-app
cargo test --locked
```

Result:

- Fails with multiple compile/runtime issues in `tests/multisig_tests.rs`:
  - invalid `include!` usage with inner attributes
  - outdated imports/types for current SDK API
  - private field access (`contract.state`)
  - missing struct fields in test instantiation
  - old chain/type helpers

Conclusion: current tests are not executable evidence for runtime correctness.

## Critical Observations

1. The opcode workaround resolves the specific compilation-level opcode issue.
2. It does **not** by itself guarantee full deployability.
3. Current environment shows version skew:
   - `linera-sdk` in app: `0.15.11`
   - local Linera protocol/CLI: `0.15.8`
4. Existing scripts can produce false confidence:
   - `scripts/multisig/validate-multisig-complete.sh` can report "passed" even when runtime deployment is skipped or wallet/faucet step fails.

## Final Verdict

- Opcode-252 workaround status: **Resolved** (for Wasm build artifact compliance).
- Full multisig deployment status: **Not fully resolved**.
  - `publish-module`: ✅
  - `create-application`: ❌ (`unreachable during Operation(0)`)

Therefore, the workaround solves the opcode blocker **partially** in the full lifecycle.

## Recommended Integration Plan (to close the remaining gap)

### Phase 1 - Runtime Compatibility Alignment

Choose one and standardize:

- Option A: align app dependency to protocol runtime (`linera-sdk` matching deployed protocol).
- Option B: run against an environment matching app SDK version.

Exit criterion:

- `create-application` succeeds with canonical app and valid instantiation args.

### Phase 2 - Test Suite Rehabilitation

Fix `scripts/multisig-app/tests/multisig_tests.rs` to current SDK/contracts:

- remove invalid `include!` pattern for contract file with inner attributes
- update imports/types to current `linera-sdk` API
- avoid private state field access (public test helpers or query-level assertions)
- update instantiation args to include all required fields

Exit criterion:

- `cargo test` passes in a supported target strategy.

### Phase 3 - E2E Multisig Flow Proof

After successful create:

1. Submit proposal
2. Confirm proposal with additional owner(s)
3. Execute proposal after threshold
4. Query state via service

Exit criterion:

- deterministic pass of full `propose -> confirm -> execute` flow on target environment.

## Script/Tooling Enhancements Added During Validation

- `scripts/validate-sdk-workaround.sh` now includes:
  - SDK/protocol mismatch warning.
  - optional `RUN_CREATE_APP_SMOKE=1` gate.
- `scripts/Makefile` includes:
  - `validate-workaround-e2e` target.

These additions make partial-vs-complete resolution measurable in one command path.
