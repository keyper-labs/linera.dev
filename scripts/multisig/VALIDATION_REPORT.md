# Validation Report: create_multisig.sh

**Date**: February 3, 2026
**Linera CLI Version**: v0.15.8
**Testnet**: Conway
**Status**: ✅ VALIDATED AND WORKING

---

## Executive Summary

The `create_multisig.sh` script has been successfully validated against Linera CLI v0.15.8. All commands are syntactically correct and the script successfully creates multi-owner chains on Conway testnet.

### Key Findings

- ✅ All Linera CLI commands are correct for v0.15.8
- ✅ Script successfully creates multi-owner chains
- ✅ Ownership configuration is properly validated
- ✅ Balance transfers work correctly
- ✅ Sync functionality operates normally

---

## Detailed Validation Results

### Test Execution

```bash
$ ./create_multisig.sh
```

**Output Summary**:
- Step 1: Requirements verified ✅
- Step 2: Wallet initialized from faucet ✅
- Step 3: Second chain requested ✅
- Step 4: Initial state queried ✅
- Step 5: Multi-owner chain created ✅
- Step 6: Synced with validators ✅
- Step 7: Results validated ✅

**Performance Metrics**:
- Multi-owner chain creation: ~815ms
- Sync time: ~772ms
- Total chains created: 3 (DEFAULT, ADMIN, Multi-Owner)

### Chain Ownership Validation

The script correctly configures ownership:

```json
{
  "super_owners": [],
  "owners": {
    "0x82e1f0e4f86233074063abd02483515cad244edd5b0349f5bea79107ca99490e": 100
  },
  "multi_leader_rounds": 4294967295,
  "open_multi_leader_rounds": false,
  "timeout_config": {
    "fast_round_duration": null,
    "base_timeout": 10000000,
    "timeout_increment": 1000000,
    "fallback_duration": 86400000000
  }
}
```

### Balance Validation

- Initial source balance: 100 tokens
- Transferred to multi-owner chain: 10 tokens
- Final source balance: ~89.999973 tokens (accounting for fees)
- Multi-owner chain balance: 10 tokens ✅

---

## Command Syntax Validation

### Verified Commands

All critical commands were verified against Linera CLI v0.15.8:

| Command | Syntax | Status |
|---------|--------|--------|
| `linera wallet init` | `linera wallet init --faucet <URL>` | ✅ Correct |
| `linera wallet request-chain` | `linera wallet request-chain --faucet <URL>` | ✅ Correct |
| `linera wallet show` | `linera wallet show` | ✅ Correct |
| `linera open-multi-owner-chain` | `linera open-multi-owner-chain --from <CHAIN> --owners <OWNER> --initial-balance <AMT>` | ✅ Correct |
| `linera sync` | `linera sync` | ✅ Correct |
| `linera query-balance` | `linera query-balance <CHAIN_ID>` | ✅ Correct |
| `linera show-ownership` | `linera show-ownership --chain-id <CHAIN_ID>` | ✅ Correct |

### Key Findings

1. **No Breaking Changes**: All command syntax from the original script works correctly in v0.15.8
2. **Output Format**: The wallet show output format matches the parsing logic
3. **Chain ID Format**: Chain IDs are correctly extracted and used
4. **Balance Queries**: Work correctly with full 64-character hex chain IDs

---

## Improvements Made

### Enhanced Validation (Step 7)

Added comprehensive validation showing:
- Total chain count verification
- Multi-owner chain identification
- Ownership configuration (JSON format)
- Individual chain balances
- Ownership timeout parameters

### Example Output

```
═══════════════════════════════════════════════════════
           MULTI-OWNER CHAIN DETAILS
═══════════════════════════════════════════════════════
Multi-owner chain ID: adfa95db00dc66a915064ee83e1042ece510e964a8cb61d2637c84a16345be45

Ownership configuration:
{
  "super_owners": [],
  "owners": {
    "0x82e1f0e4f86233074063abd02483515cad244edd5b0349f5bea79107ca99490e": 100
  },
  "multi_leader_rounds": 4294967295,
  "open_multi_leader_rounds": false,
  "timeout_config": { ... }
}

Multi-owner chain balance: 10 tokens
═══════════════════════════════════════════════════════
```

---

## Known Limitations

### Single-Owner Setup

Current implementation creates a single-owner multi-owner chain for testing purposes:

```bash
linera open-multi-owner-chain \
    --from "$CHAIN1" \
    --owners "$OWNER" \
    --initial-balance "$INITIAL_BALANCE"
```

**For true multi-signature**, add multiple owners:

```bash
linera open-multi-owner-chain \
    --from "$CHAIN1" \
    --owners "$OWNER1" "$OWNER2" "$OWNER3" \
    --owner-weights 100 100 100 \
    --initial-balance "$INITIAL_BALANCE"
```

### Warnings During Execution

Expected warnings appear during chain creation:
```
WARN handle_chain_info_query: error=Blobs not found: [BlobId ...]
WARN handle_block_proposal: error=Blobs not found: [BlobId ...]
```

These are **normal** and occur because validators haven't yet seen the new chain description. The script succeeds despite these warnings.

---

## Recommendations

### For Testing

1. ✅ **Use current script** for single-owner testing
2. ✅ **Review ownership output** to verify configuration
3. ✅ **Check balances** before and after creation

### For Production

1. **Add multiple owners** for true multi-signature
2. **Configure thresholds** (e.g., 2-of-3)
3. **Test fallback scenarios** (owner unavailability)
4. **Document recovery procedures**

### For Development

1. **Parameterize owner count**: Allow variable number of owners
2. **Add threshold configuration**: Support M-of-N signatures
3. **Implement rollback**: Cleanup on failure
4. **Add retry logic**: Handle transient network errors

---

## Conclusion

The `create_multisig.sh` script is **fully functional** and **validated** for Linera CLI v0.15.8. It successfully:

- Creates multi-owner chains on Conway testnet
- Validates ownership configuration
- Transfers balances correctly
- Provides comprehensive output

**No critical issues found**. The script is ready for use in testing and development workflows.

---

## Test Evidence

### Test 1: Basic Execution
- **Date**: 2026-02-03 17:26:19
- **Result**: ✅ Success
- **Chains Created**: 3
- **Multi-Owner Chain**: `fa1bb76646ec9fa3b65f9afd056b2f8c45173d584ef94cbc023c6af75e92e60b`
- **Sync Time**: 696ms

### Test 2: Enhanced Validation
- **Date**: 2026-02-03 17:28:17
- **Result**: ✅ Success
- **Chains Created**: 3
- **Multi-Owner Chain**: `adfa95db00dc66a915064ee83e1042ece510e964a8cb61d2637c84a16345be45`
- **Sync Time**: 772ms
- **Ownership Validated**: ✅
- **Balance Validated**: ✅

---

**Validator**: Claude Code (Anthropic)
**Validation Method**: Automated execution + manual inspection
**Confidence Level**: High
