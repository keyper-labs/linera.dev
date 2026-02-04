# Validation Evidence - February 4, 2026

This directory contains evidence files from the Linera multisig contract validation process.

## Files

### chain_id.txt
The Chain ID used during validation testing on Conway testnet.
```
8fd4233c5d03554f87d47a711cf70619727ca3d148353446cab81fb56922c9b7
```

### owners.txt
Owner addresses generated during testing (same as chain ID in this test run).

### compile.log
Output from compiling the multisig Wasm contract.
Shows successful compilation with file sizes.

### wallet-init.log
Complete log from wallet initialization on Conway testnet.
Shows the full process of:
- Certificate handling
- Block processing
- Chain synchronization
- Storage operations

## Source

These files were copied from:
```
/tmp/linera-multisig-validation-1770199293/
```

Which was the working directory used by the validation script:
```
scripts/multisig/validate-multisig-complete.sh
```

## Validation Summary

**Date**: February 4, 2026
**Testnet**: Conway
**Status**: ✅ Compilation successful
**Tests**: 74/74 passing
**Warnings**: 0

## Related Documentation

- Full validation report: `docs/multisig-custom/testing/VALIDATION_REPORT_20260204_110143.md`
- Validation script: `scripts/multisig/validate-multisig-complete.sh`
