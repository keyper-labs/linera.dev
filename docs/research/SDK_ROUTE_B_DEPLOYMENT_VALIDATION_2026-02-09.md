# SDK Route B Deployment Validation (2026-02-09)

## Scope
Validate that Route B (SDK/protocol alignment on `0.15.11`) can deploy the custom multisig application end-to-end after integrating code-level fixes.

## Fixed Inputs Applied

1. **Instantiate trap hardening** (custom contract)
- File: `scripts/multisig-app/src/contract.rs`
- `instantiate()` was made non-panicking by normalizing invalid threshold configurations instead of trapping.

2. **Create-application regression matrix**
- File: `scripts/validate-create-app-regression.sh`
- Added deterministic E2E validation that tries multiple JSON owner encodings.

3. **Smoke test alignment in canonical validator**
- File: `scripts/validate-sdk-workaround.sh`
- `run_create_application_smoke()` now tries both owner encodings:
  - `owners=["User:<hex>"]`
  - `owners=["<raw_owner>"]`

4. **Makefile integration**
- File: `scripts/Makefile`
- Added target: `validate-create-app-regression`

## Commands Executed

### 1) Route B full validation
```bash
LINERA_BIN="$PWD/.tools/linera-0.15.11/bin/linera" bash scripts/validate-route-b.sh
```

### 2) Dedicated create-application regression (Make target)
```bash
LINERA_BIN="$PWD/.tools/linera-0.15.11/bin/linera" make -C scripts validate-create-app-regression
```

## Results

### Route B full validation: **PASS**
- SDK/protocol alignment confirmed: `0.15.11` / `0.15.11`
- Wasm opcode gate passed:
  - `memory.copy=0`
  - `memory.fill=0`
- `create-application` behavior:
  - `owners=["User:<hex>"]` -> fails
  - `owners=["<raw_owner>"]` -> succeeds
- Final status: **Route B validation completed successfully**.

### Regression target: **PASS**
- Reproduced same behavior and successful deployment path.
- Final status: **create-application is deployable**.

## Key Technical Finding
The opcode-252 workaround is valid (bulk-memory opcodes removed), but deployment success in aligned Route B also depends on using the owner encoding accepted by current runtime path:

- Preferred working format:
```json
{"owners":["<raw_owner>"],"threshold":1,"proposal_lifetime":604800,"time_delay":0}
```

## Conclusion
**Yes, deployment is achievable now** under Route B after these integrations.

- Workaround status: **effective**
- Contract deployment status: **successful**
- Multisig custom contract path remains the correct closure for native protocol multisig gaps.
