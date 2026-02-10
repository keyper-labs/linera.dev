# Conway Safe-like E2E Remediation (2026-02-10)

## Scope
Hardening deploy/E2E scripts to validate a real Safe-like multisig flow on Conway testnet with real owners, real wallets, and on-chain operations.

## Changes Applied

### 1) Deploy now uses a real multi-owner chain when OWNER_COUNT > 1
- File: `scripts/deploy-multisig-conway.sh`
- Added multi-owner chain creation via `open-multi-owner-chain`.
- Added robust chain id resolution (wallet diff + output fallback).
- Uses that chain as target for:
  - `publish-module ... <CHAIN_ID>`
  - `create-application ... <CHAIN_ID>`
- Exports `SOURCE_CHAIN_ID` in deploy env.

### 2) E2E now validates GraphQL errors correctly
- File: `scripts/validate-conway-safe-e2e.sh`
- Captures GraphQL response body (`GQL_LAST_BODY`).
- `assert_http_ok` now fails if GraphQL `errors` are present.
- `assert_http_error` now passes on HTTP 4xx/5xx **or** GraphQL `errors`.

### 3) E2E owner/signer alignment improvements
- Reads chain owners from `show-ownership`.
- Asserts expected chain owner count.
- After app-level `AddOwner`, expands chain ownership via `change-ownership` to include new owner for signer-level tests.

### 4) RocksDB lock contention mitigation
- Added `run_linera_cli` retry wrapper for transient lock errors.
- Wrapped CLI calls used during service stop/start transitions:
  - `set-preferred-owner`, `change-ownership`, `show-ownership`, `keygen`, `sync`.

## Validation Status

### Confirmed fixed
- Multi-owner chain is created on Conway and selected for deployment.
- Module publish and app creation on the selected chain succeed in repeated runs.
- The previous false-positive pattern (HTTP 200 with GraphQL errors counted as success) is fixed in assertions.

### Remaining blocker (external/runtime)
- Conway testnet has intermittent instability during long E2E runs:
  - repeated round timeout warnings,
  - missing blob fetch retries,
  - occasional DNS/unavailable validator errors,
  causing E2E to become very slow or hang before full completion.

## Latest relevant artifacts
- Deploy env example: `.linera-deploy/deploy_conway_safe_e2e_20260210_120202.env`
- Service logs examples:
  - `.linera-deploy/safe_e2e_service_20260210_120038.log`
  - `.linera-deploy/safe_e2e_service_20260210_120202.log`

## Conclusion
The deployment path and signer-model alignment are materially improved and the core create/deploy path is working on Conway.
Full deterministic E2E completion is still blocked by current testnet/network instability, not by the original create-application schema mismatch.
