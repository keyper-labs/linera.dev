# Linera Multisig Platform - Project Proposal

**Status**:  BLOCKED - Safe-like multisig NOT possible (SDK opcode 252)

---

## 1. Objectives

Build a multisig platform on Linera with:
- m-of-n threshold wallets
- Proposal/approve/execute workflow
- Self-custodial (Ed25519 keys in browser)
- Multi-wallet management

**Status**: BLOCKED - See section 11

---

## 2. Architecture

### 2.1 System Components

```
Frontend (React + @linera/client)
    ↓
Backend (Node.js/TypeScript + @linera/client)
    ↓
Linera Network
 Multi-owner chains (1-of-N, works)
 Wasm multisig (m-of-n, BLOCKED)
```

### 2.2 Technology Stack

| Layer | Technology | Status |
|-------|-----------|--------|
| Frontend | React + @linera/client |  Viable |
| Backend | Node.js + @linera/client |  Viable |
| Smart Contract | Rust → Wasm |  BLOCKED (opcode 252) |
| Database | PostgreSQL + Redis |  Works |
| API | REST (Express/Fastify) |  Custom required |

---

## 3. The Blocker

### 3.1 Opcode 252 Issue

**Problem**: Cannot deploy custom Wasm multisig contracts.

**Root Cause**:
```
linera-sdk 0.15.11
     async-graphql = "=7.0.17"
         Rust 1.87+ required
             generates memory.copy (opcode 252)
                 Linera runtime rejects it
```

**Failed Workarounds**:

| Attempt | Result |
|---------|--------|
| Remove .clone() |  Breaks mutability |
| Remove proposal history |  Still 85 opcodes |
| Remove GraphQL |  Still 82 opcodes |
| Rust 1.86.0 |  async-graphql won't compile |
| Patch async-graphql |  Exact pin can't override |
| Replace async-graphql |  6.x/7.x incompatible |
| Combined all |  Still 67 opcodes |

### 3.2 Threshold Signatures Experiment (Feb 2026)

**Hypothesis**: Minimal contract might avoid opcode 252.

**Test**: Contract with NO ed25519-dalek, NO proposal history, NO GraphQL ops

**Result**:  Still 73 `memory.copy` opcodes

**Conclusion**: Blocker is in `linera-sdk` dependencies, not contract code. No workaround possible.

---

## 4. Milestones

| Milestone | Hours | Status |
|-----------|-------|--------|
| M1: Project Setup | 40h |  Ready |
| M2: Multisig Contract | 170h |  BLOCKED |
| M3: Backend Core | 120h |  Not started |
| M4: Frontend Core | 120h |  Not started |
| M5: Integration | 80h |  Not started |
| M6: Observability | 40h |  Not started |
| M7: QA & UAT | 50h |  Not started |
| M8: Handoff | 20h |  Not started |

**Total**: ~640h (original), ~300h (simplified)

---

## 5. What Works / Doesn't Work

**Works** :
- Frontend with @linera/client SDK
- Backend with @linera/client SDK
- Multi-owner chains (verified on testnet)
- Ed25519 key management

**Doesn't Work** :
- Custom Wasm multisig contract (opcode 252)
- Threshold m-of-n logic (requires Wasm)
- Safe-like proposal/approve/execute UX

---

## 6. Options

### Option 1: Wait for Linera SDK Fix

**Timeline**: Unknown
**Issue**: https://github.com/linera-io/linera-protocol/issues/4742

### Option 2: Simplified Wallet (Multi-Owner Only)

**What you get**:
- Shared wallet (multiple owners)
- 1-of-N execution (any owner can execute)
- Basic transaction ops

**What you don't get**:
- Threshold enforcement
- Proposal/approval workflow
- Safe-like security

**Estimate**: ~300 hours

---

## 7. Recommendation

 **DO NOT PROCEED** with full Safe-like multisig platform.

**Reason**: Wasm contract cannot deploy due to SDK ecosystem blocker. No workaround exists.

**Path forward**: Wait for Linera team or choose different blockchain.

---

## 8. Evidence

- [`docs/research/LINERA_OPCODE_252_ISSUE.md`](../research/LINERA_OPCODE_252_ISSUE.md) - Complete analysis
- [`docs/research/OPCODE_252_CODE_ANALYSIS.md`](../research/OPCODE_252_CODE_ANALYSIS.md) - Code investigation
- [`experiments/threshold-signatures/README.md`](../../experiments/threshold-signatures/README.md) - Alternative experiment

---

## 9. References

- Linera SDK: https://github.com/linera-io/linera-protocol
- Testnet Conway: https://faucet.testnet-conway.linera.net
- Issue #4742: https://github.com/linera-io/linera-protocol/issues/4742

---

**Updated**: February 4, 2026
