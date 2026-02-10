# Technical Status Report (Post-Merge)

- Date: 2026-02-10
- Branch: `feat/fix_opcode_252`
- Merge commit: `63bb6ec`
- Integrated branch: `fix/sdk-opcode-252-workaround`

## 1) Baseline at Merge

The merge introduced the opcode-252 workaround path to unblock contract build/deploy under aligned versions.

Commit references:

- `769355e`: workaround implementation (`Rust 1.86 + pinned deps`)
- `63bb6ec`: merge into working branch

## 2) Progress After Merge

### 2.1 Revalidation of the deployment lifecycle

Observed status in aligned Route B conditions (`linera-sdk 0.15.11`, protocol `0.15.11`):

1. `build` passes.
2. `publish-module` passes.
3. `create-application` passes when owner argument uses accepted raw owner format.

Primary evidence:

- `docs/research/SDK_OPCODE252_WORKAROUND_E2E_VALIDATION_2026-02-09.md`
- `docs/research/CREATE_APP_STATUS_REVALIDATION_2026-02-10.md`
- `docs/research/SDK_ROUTE_B_DEPLOYMENT_VALIDATION_2026-02-09.md`

### 2.2 Script-level hardening completed in current working branch

Updated scripts:

- `scripts/deploy-multisig-conway.sh`
- `scripts/validate-conway-safe-e2e.sh`

Key improvements:

1. Multi-owner chain opening and targeting before publish/create.
2. Explicit deployment on the selected chain (`publish-module` and `create-application` include chain id).
3. GraphQL assertion hardening:
   - HTTP 200 with GraphQL `errors` no longer counts as success.
4. Owner/signer alignment:
   - ownership checks and owner rotation consistency during E2E.
5. RocksDB lock mitigation:
   - retry wrapper for transient lock contention in CLI operations.

Related remediation note:

- `docs/research/CONWAY_SAFE_LIKE_E2E_REMEDIATION_2026-02-10.md`

## 3) What Is Corrected

1. Original opcode-252 blocker in validated build/deploy flow: **corrected**.
2. Create-app deployability uncertainty: **clarified and corrected** under aligned runtime and owner encoding.
3. False-positive validation cases (HTTP 200 + GraphQL errors): **corrected**.
4. Part of owner execution path fragility in E2E scripts: **partially corrected** with ownership and retry improvements.

## 4) What Still Fails / Open Problems

### 4.1 Conway long-run instability in E2E

Intermittent issues still observed during long runs:

1. Round timeout churn.
2. Intermittent DNS/unavailable validator responses.
3. Blob retrieval retries.

Effect:

- Full E2E completion can become slow or non-deterministic.
- Failures are now primarily operational/network-driven, not the original compile/runtime opcode issue.

### 4.2 Full “Safe-like platform” closure still partial

Current validated scope is strongest at contract/deploy path and core on-chain operations.  
Complete product closure (frontend/backend/observability/operational resilience) remains pending.

## 5) Current Status Matrix

1. Wasm build without opcode 252: **PASS**
2. `publish-module` on Conway: **PASS**
3. `create-application` on Conway (aligned runtime + accepted owner format): **PASS**
4. Deterministic full Safe-like E2E in current Conway conditions: **PARTIAL**
5. Full platform completeness beyond contract flow: **PARTIAL**

## 6) Recommended Technical Next Steps

1. Add network-health preflight and fail-fast conditions in E2E entrypoint.
2. Add bounded retries/timeouts for validator-side transient failures.
3. Execute repeated stability campaign (N runs) and publish deterministic pass criteria.
4. Freeze and document canonical deploy input format (owner encoding and version pair).
5. Finalize closure report mapping contract-level validation vs platform-level validation.
