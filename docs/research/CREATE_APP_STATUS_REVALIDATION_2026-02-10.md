# Create-Application Status Revalidation (2026-02-10)

- Date (UTC): 2026-02-10 09:44:48 UTC
- Branch: `feat/fix_opcode_252`
- Commit: `63bb6ec`
- Scope: Phase 0 + Phase 1 baseline/reproduction for current deployability status

## Objective

Re-check the real status of the custom multisig flow (`build -> publish-module -> create-application`) without modifying prior reports.

## Environment Snapshot

- Default `linera` on PATH: protocol `v0.15.8`
- Pinned binary used for aligned checks: `.tools/linera-0.15.11/bin/linera` (protocol `v0.15.11`)
- Contract SDK version (from `scripts/multisig-app/Cargo.toml`): `0.15.11`

## Commands Executed

### 1) Baseline local workaround validation (no network steps)

Command:

```bash
bash scripts/validate-sdk-workaround.sh
```

Result:

- Build succeeded.
- Wasm opcode check passed:
  - `multisig_contract.wasm`: `memory.copy=0`, `memory.fill=0`
  - `multisig_service.wasm`: `memory.copy=0`, `memory.fill=0`
- Script warns about version mismatch (`linera-sdk=0.15.11` vs protocol `0.15.8`).

Verdict: workaround/build status remains healthy.

---

### 2) Create-application smoke (non-escalated sandbox run)

Command:

```bash
RUN_CREATE_APP_SMOKE=1 bash scripts/validate-sdk-workaround.sh
```

Observed behavior:

- Process failed before end-to-end conclusion with a runtime panic in `linera`:
  - `system-configuration ... Attempted to create a NULL object`

Interpretation:

- This was environment-dependent noise in restricted execution context, not a deterministic contract/runtime conclusion.

---

### 3) Create-application smoke (re-run outside sandbox)

Command:

```bash
RUN_CREATE_APP_SMOKE=1 bash scripts/validate-sdk-workaround.sh
```

Result:

- Build/opcode checks passed again.
- `create-application` succeeded using raw owner format.
- Script output includes:
  - `create-application smoke test succeeded (raw owner format).`

Verdict: on unrestricted run, create-app is currently deployable through this smoke path.

---

### 4) Regression validator with default PATH `linera` (0.15.8)

Command:

```bash
bash scripts/validate-create-app-regression.sh
```

Result:

- Immediate fail by guard:
  - `Version mismatch: sdk=0.15.11 protocol=0.15.8`

Verdict: regression script correctly blocks mixed-version runs.

---

### 5) Regression validator with aligned `linera` 0.15.11

Command:

```bash
LINERA_BIN="$PWD/.tools/linera-0.15.11/bin/linera" \
LOCALNET_FAUCET_PORT=38991 \
bash scripts/validate-create-app-regression.sh
```

Result:

- Versions aligned (`0.15.11`).
- Localnet started, faucet ready.
- Module publish succeeded.
- `create-application` behavior by variant:
  - `owners=User:hex + full args` -> fail
  - `owners=raw owner + full args` -> success
- Final script verdict:
  - `Regression result: create-application is deployable.`

## Current Status (as of this revalidation)

1. Opcode-252 workaround remains valid at build artifact level.
2. `create-application` is deployable in aligned runtime (`0.15.11`) when using raw owner argument format.
3. The key practical blocker is now environment/version consistency, not opcode generation.
4. Owner JSON encoding remains a compatibility nuance:
   - `User:hex` form can fail
   - raw owner form succeeds in validated runs

## Recommended Immediate Follow-up

1. Standardize execution on `.tools/linera-0.15.11/bin/linera` for validation scripts tied to SDK `0.15.11`.
2. Keep raw owner format as canonical in deployment scripts.
3. Add one explicit preflight in canonical E2E script to print active SDK/protocol pair and fail fast on mismatch.
