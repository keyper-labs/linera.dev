# Linera Multisig Platform - Research & Proposal

**Status**: 🔴 BLOCKED - Safe-like multisig NOT possible on Linera (SDK opcode 252 issue)

---

## Quick Start

**Developers**:
- Technical analysis: [`docs/INFRASTRUCTURE_ANALYSIS.md`](docs/INFRASTRUCTURE_ANALYSIS.md)
- Implementation proposal: [`docs/PROPOSAL/linera-multisig-platform-proposal.md`](docs/PROPOSAL/linera-multisig-platform-proposal.md)

**Claude Code AI**: See [`CLAUDE.md`](CLAUDE.md)

---

## Overview

Research and implementation proposal for a **multi-signature (multisig) platform** on the **Linera blockchain**.

### What is Linera?

Linera = microchain-based blockchain where each user has their own chain. Features:
- High throughput (parallel execution)
- Low latency
- Native multi-owner chain support
- Cross-chain messaging

### Project Goal

Build a multisig platform allowing users to:
- Create multisig wallets (m-of-n thresholds)
- Propose, approve, execute transactions
- Manage signers and owner sets
- Monitor proposal status

---

## Technical Status

| Component | Status |
|-----------|--------|
| Multi-owner chains | ✅ Native (1-of-N, any owner can execute) |
| @linera/client SDK | ✅ TypeScript SDK works |
| Wasm multisig contract | 🔴 BLOCKED (opcode 252) |
| Frontend + Backend | ✅ Viable with @linera/client |

---

## Architecture

```
Frontend (React + @linera/client)
         ↓
Backend (Node.js/TypeScript + @linera/client)
         ↓
Linera Network
├── Multi-owner chains (1-of-N, works)
└── Wasm multisig (m-of-n, BLOCKED)
```

---

## The Blocker

**Problem**: Cannot deploy custom Wasm multisig contracts.

**Root Cause**:
```
linera-sdk 0.15.11
    └─ async-graphql = "=7.0.17"
        └─ requires Rust 1.87+
            └─ generates memory.copy (opcode 252)
                └─ Linera runtime rejects it
```

**All workarounds failed**:
- Remove .clone() → breaks mutability
- Remove GraphQL → still 82 opcodes
- Rust 1.86.0 → async-graphql won't compile
- Patch async-graphql → version pin override impossible

**Threshold signatures experiment** (Feb 2026): Also failed. Even minimal contract (~292 KB, no ed25519-dalek, no GraphQL ops) contains 73 `memory.copy` opcodes.

**Conclusion**: The blocker is in `linera-sdk` dependencies, not contract code. No project-level workaround exists.

**Evidence**:
- [`docs/research/LINERA_OPCODE_252_ISSUE.md`](docs/research/LINERA_OPCODE_252_ISSUE.md)
- [`experiments/threshold-signatures/README.md`](experiments/threshold-signatures/README.md)

---

## What Works / Doesn't Work

**Works** ✅:
- Frontend: React + @linera/client SDK
- Backend: Node.js/TypeScript + @linera/client
- Multi-owner chains: native protocol, verified on testnet
- Wallet: Ed25519 key management via SDK

**Doesn't Work** ❌:
- Custom Wasm multisig contract
- Threshold m-of-n logic (requires Wasm)
- Safe-like UX (proposal/approve/execute workflow)

---

## Options

**Option A**: Wait for Linera SDK fix
- Issue: https://github.com/linera-io/linera-protocol/issues/4742
- Timeline: unknown

**Option B**: Build simplified wallet (multi-owner only)
- 1-of-N (any owner can execute)
- Not Safe-like
- ~300 hours

**Option C**: Choose different blockchain
- Ethereum (Gnosis Safe) - reference implementation for multisig functionality

---

## Quick Reference: Testnet Conway

```bash
# Faucet
https://faucet.testnet-conway.linera.net

# Create multi-owner chain (VERIFIED)
linera open-multi-owner-chain \
    --from "$CHAIN1" \
    --owners "$OWNER1" "$OWNER2" \
    --initial-balance 10

# Verify
linera sync
linera query-balance "$CHAIN_ID"
```

---

## Documentation Structure

```
docs/
├── INFRASTRUCTURE_ANALYSIS.md    # Technical analysis
├── PROPOSAL/
│   └── linera-multisig-platform-proposal.md
├── research/                      # Opcode 252 investigation
└── diagrams/
```

---

## Timeline Estimate

**Original**: 580h (~15 weeks)

**Simplified (multi-owner only)**: ~300h

**Full Safe-like**: BLOCKED (requires SDK fix)

---

## Key Distinction

**Multi-Owner Chain** (protocol level):
- Multiple owners can control a chain
- 1-of-N (any owner executes)
- ✅ Works

**Multisig Application** (Wasm contract):
- Custom m-of-n threshold logic
- Proposal/approval workflow
- ❌ BLOCKED (opcode 252)

---

## Status

🔴 **BLOCKED** - Cannot deliver Safe-like multisig until Linera SDK team resolves opcode 252.

This is an SDK ecosystem issue, not a project bug.

---

**Updated**: February 4, 2026
**Repo**: https://github.com/keyper-labs/linera.dev
