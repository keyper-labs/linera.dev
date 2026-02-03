# Linera Multisig Wasm Binaries Validation Report

**Date**: 2026-02-03 18:33:41 UTC
**SDK Version**: 0.15.11
**Rust Toolchain**: rustc 1.92.0 (ded5c06cf 2025-12-08)

## Binary Files

| Binary | Size | Status |
|--------|------|--------|
| Contract | 347935 bytes | ✅ Valid |
| Service | 2001870 bytes | ✅ Valid |

## Validation Results

- ✅ Both binaries have valid Wasm magic number
- ✅ Files compiled successfully with linera-sdk v0.15.11
- ✅ Binaries ready for testnet deployment

## Next Steps

To publish to testnet:

```bash
# Publish contract
linera publish "/Users/alfredolopez/Documents/GitHub/PalmeraDAO/linera.dev/scripts/multisig-app/target/wasm32-unknown-unknown/release/multisig_contract.wasm" --init-application [...]

# Create application instance
linera create-application <CONTRACT> --service "/Users/alfredolopez/Documents/GitHub/PalmeraDAO/linera.dev/scripts/multisig-app/target/wasm32-unknown-unknown/release/multisig_service.wasm"
```

## ABI Operations

The contract supports the following operations:

- `SubmitTransaction`: Submit a new transaction for approval
- `ConfirmTransaction`: Confirm a pending transaction
- `ExecuteTransaction`: Execute a confirmed transaction
- `RevokeConfirmation`: Revoke a confirmation
- `AddOwner`: Add a new owner
- `RemoveOwner`: Remove an owner
- `ChangeThreshold`: Change the threshold
- `ReplaceOwner`: Replace an owner

## GraphQL Queries

The service supports these queries:

- `owners`: Get the list of current owners
- `threshold`: Get the current threshold
- `nonce`: Get the current nonce
- `transaction(id)`: Get a transaction by ID
- `hasConfirmed(owner, transactionId)`: Check if an owner has confirmed
