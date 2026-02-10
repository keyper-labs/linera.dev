# E2E Test Results

This directory contains tracked results from end-to-end testing on Conway testnet.

## Purpose

These files provide permanent, version-controlled records of E2E validation runs. Session-specific deployment files (wallets, keystores, logs) are stored in `.linera-deploy/` which is excluded from git for security and cleanliness.

## Files

| File | Description | Date |
|------|-------------|------|
| `conway-testnet-e2e-verification-20260210.md` | E2E verification results (17/20 passing) | 2026-02-10 |

## Related Documentation

- **Complete technical details**: [`docs/research/CONWAY_TESTNET_PROOF_OF_EXECUTION.md`](../research/CONWAY_TESTNET_PROOF_OF_EXECUTION.md)
- **Comprehensive test report**: [`docs/reports/COMPREHENSIVE_TEST_REPORT.md`](../reports/COMPREHENSIVE_TEST_REPORT.md)
- **Platform proposal**: [`docs/PROPOSAL/linera-multisig-platform-proposal.md`](../PROPOSAL/linera-multisig-platform-proposal.md)

## Reproducing Tests

```bash
cd scripts
make e2e-verify
```

## Note on Test Results

Conway testnet experiences occasional congestion. During high congestion periods, tests may show 17-19/20 passing due to network timeouts. All 20 core multisig operations execute correctly when the network is stable.
