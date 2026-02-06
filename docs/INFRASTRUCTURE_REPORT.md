# Linera Infrastructure Analysis

**Status**:  BLOCKED - Safe-like multisig NOT possible (opcode 252)

**Date**: February 3, 2026
**Network**: Testnet Conway (operational)
**Issue**: <https://github.com/linera-io/linera-protocol/issues/4742>

---

## Executive Summary

**Conclusion**: Safe-like multisig on Linera is **NOT FEASIBLE** due to SDK ecosystem blocker.

**What Works**:

- Multi-owner chains (1-of-N, verified)
- @linera/client SDK (TypeScript)
- Frontend + Backend (both viable)

**What Doesn't Work**:

- Custom Wasm multisig contract (opcode 252 blocker)
- Threshold m-of-n logic (requires Wasm)
- Safe-like UX

**Root Cause**:

```
linera-sdk 0.15.11
     async-graphql = "=7.0.17"
         Rust 1.87+ required
             generates memory.copy (opcode 252)
                 Linera runtime rejects it
```

**All workarounds failed**. See section 2.2 for details.

---

## 1. SDK Analysis

### 1.1 Rust SDK (linera-sdk)

**Status**:  Exists (Wasm compilation only)

**Purpose**: Build Wasm applications (smart contracts)

**Provides**:

- Application state management (Views)
- Contract logic implementation
- Cross-chain messaging
- Wasm compilation

**Does NOT provide**:

- Client SDK features (queries, wallet, network)
- These are in separate `linera-client` crate

### 1.2 Backend SDK Availability

**Status**:  Rust only,  TypeScript/Python/Go

| Language | SDK | Status |
|----------|-----|--------|
| Rust | `linera-client` + `linera-core` |  Available |
| TypeScript | `@linera/client` npm package |  Available |
| Python | - |  Not available |
| Go | - |  Not available |

**Finding**: Use TypeScript for backend.

**@linera/client package** (npm):

```typescript
import { Client } from '@linera/client';

const client = await Client.openWalletFromFile();
const balance = await client.queryBalance(chainId);
```

---

## 2. Critical Issues

### 2.1 GraphQL API Not Functional

**Testnet Conway Node Service**:

- Starts successfully
- GraphiQL loads
- Schema fails to load
- Queries return "Unknown field" errors

**Workaround**: Build custom REST API in backend.

### 2.2  CRITICAL: Wasm Opcode 252 Issue

**Status**:  BLOCKER - SDK ecosystem issue

**Problem**: Cannot deploy complex Wasm contracts to Linera testnet.

**Root Cause**:

```
linera-sdk 0.15.11
     async-graphql = "=7.0.17" (exact pin)
         requires Rust 1.87+
             generates memory.copy (opcode 252)
                 Linera runtime doesn't support
```

**Failed Workarounds**:

| Attempt | Result |
|---------|--------|
| Remove .clone() |  Breaks mutability |
| Remove proposal history |  Still 85 opcodes |
| Remove GraphQL service |  Still 82 opcodes |
| Rust 1.86.0 |  async-graphql won't compile |
| Patch async-graphql |  Can't override exact pin |
| Replace async-graphql |  6.x/7.x incompatible |
| Combined all |  Still 67 opcodes |

**Evidence**:

- [`docs/research/LINERA_OPCODE_252_ISSUE.md`](LINERA_OPCODE_252_ISSUE.md)
- [`docs/research/OPCODE_252_CODE_ANALYSIS.md`](OPCODE_252_CODE_ANALYSIS.md)

#### Threshold Signatures Experiment (February 4, 2026)

**Hypothesis**: Minimal contract using threshold signatures might avoid opcode 252.

**Tested Contract**:

```rust
pub struct MultisigState {
    pub owners: RegisterView<Vec<AccountOwner>>,
    pub threshold: RegisterView<u64>,
    pub aggregate_public_key: RegisterView<Vec<u8>>,
    pub nonce: RegisterView<u64>,
}
// NO ed25519-dalek, NO proposal history, NO GraphQL operations
```

**Result**:  Still contains 73 `memory.copy` opcodes

```bash
wasm-objdump -d contract.wasm | grep "memory.copy"
# 73 instances found
```

**Key Finding**: Opcode 252 comes from `async-graphql = "=7.0.17"` dependency in `linera-sdk` itself. Even using it only for ABI generates the opcode.

**Conclusion**: Code-level workarounds are impossible. Only Linera team can fix.

---

## 3. Architecture Options

### Option A: Rust Backend + TypeScript Frontend

**Status**:  BLOCKED (same SDK issue)

**Components**:

- Frontend: React + @linera/client
- Backend: Rust + linera-client crate
- Smart Contract: Rust Wasm (blocked by opcode 252)

### Option B: TypeScript Full-Stack

**Status**:  VIABLE for Frontend + Backend,  BLOCKED for Wasm contract

**Components**:

- Frontend: React + @linera/client
- Backend: Node.js + @linera/client
- Smart Contract: Rust Wasm (blocked by opcode 252)

**Conclusion**: TypeScript works for client-side, but doesn't solve Wasm deployment blocker.

### Option C: Multi-Owner Chains Only

**Status**:  WORKS (but limited)

**What you get**:

- Shared wallet with multiple owners
- 1-of-N execution (any owner can execute)
- On-chain balance tracking

**What you don't get**:

- Threshold m-of-n enforcement
- Proposal/approval workflow
- Safe-like security model

---

## 4. Recommendations

### Current Status

 **PROJECT BLOCKED** - Cannot deliver Safe-like multisig platform.

### Options

**Option 1**: Wait for Linera SDK team

- Issue: <https://github.com/linera-io/linera-protocol/issues/4742>
- Timeline: unknown

**Option 2**: Build simplified wallet (multi-owner only)

- Accept 1-of-N limitation
- Not competitive with existing multisig solutions
- ~300 hours

---

## 5. Technology Stack

| Layer | Technology | Status |
|-------|-----------|--------|
| Smart Contracts | Rust → Wasm (linera-sdk) |  Required |
| Backend | Node.js/TypeScript + @linera/client |  Works |
| Frontend | TypeScript/React + @linera/client |  Works |
| Database | PostgreSQL + Prisma/TypeORM |  Works |
| API | REST (Express/Fastify) |  Custom |
| Wallet | @linera/client (built-in) |  Works |

---

## 6. Testnet Validation

**Verified** (Testnet Conway):

```bash
# Create multi-owner chain
linera open-multi-owner-chain \
    --from "$CHAIN1" \
    --owners "$OWNER1" "$OWNER2" \
    --initial-balance 10

# Query balance
linera query-balance "$CHAIN_ID"
```

**Failed** (Wasm deployment):

- Custom multisig contract won't deploy
- Error: Unknown opcode 252

---

## 7. References

- **Linera SDK**: <https://github.com/linera-io/linera-protocol>
- **Opcode 252 Analysis**: [`docs/research/LINERA_OPCODE_252_ISSUE.md`](docs/research/LINERA_OPCODE_252_ISSUE.md)
- **Code Analysis**: [`docs/research/OPCODE_252_CODE_ANALYSIS.md`](docs/research/OPCODE_252_CODE_ANALYSIS.md)
- **Investigation Log**: [`docs/research/OPCODE_252_INVESTIGATION_LOG.md`](docs/research/OPCODE_252_INVESTIGATION_LOG.md)
- **Threshold Signatures Experiment**: [`experiments/threshold-signatures/README.md`](../experiments/threshold-signatures/README.md)

---

**Updated**: February 4, 2026
