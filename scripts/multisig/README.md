# ⚠️ LEGACY - Development Scripts

**Status**: SUPERSEDED by E2E testing suite
**Date**: February 10, 2026

## Purpose

This directory contains intermediate development scripts used during the research and investigation phase of the Linera multisig platform.

## Superseded By

All functionality in these scripts has been incorporated into the main E2E testing suite:

- **Main E2E Script**: [`../e2e-multisig-conway.sh`](../e2e-multisig-conway.sh)
- **Deployment Script**: [`../deploy-multisig-conway.sh`](../deploy-multisig-conway.sh)
- **Validation Script**: [`../validate-conway-safe-e2e.sh`](../validate-conway-safe-e2e.sh)

## Scripts in This Directory

| Script | Purpose | Status |
|---------|---------|--------|
| `create_multisig.sh` | Multi-owner chain creation | Superseded by E2E |
| `test_conway.sh` | Simple Conway validation | Superseded by E2E |
| `deploy-simple.sh` | Simple deployment | Superseded by deploy-conway |
| `deploy-testnet.sh` | Testnet deployment | Superseded by deploy-conway |
| `multisig-cli.sh` | CLI helper functions | Integrated into E2E |
| `test-multisig-app.sh` | App testing | Superseded by E2E |
| `validate-multisig-complete.sh` | Complete validation | Superseded by E2E |

## Current Working Directory

For production E2E testing on Conway testnet, use the parent `scripts/` directory:

```bash
cd scripts
make e2e-verify
```

## Historical Reference

These scripts are preserved for:
- Historical documentation of development process
- Reference in research documents
- Possible debugging needs

Do NOT use these scripts for new deployments or testing.

---

**Last Updated**: February 10, 2026
**Superseding Date**: February 10, 2026 (E2E completion)
