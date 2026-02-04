# Linera Multisig Platform - Research & Proposal

---

## Quick Start

### For Developers

1. **Start Here**: [`docs/INFRASTRUCTURE_ANALYSIS.md`](docs/INFRASTRUCTURE_ANALYSIS.md) - Technical analysis and SDK information
2. **Implementation Proposal**: [`docs/PROPOSAL/linera-multisig-platform-proposal.md`](docs/PROPOSAL/linera-multisig-platform-proposal.md) - Complete development plan

### For Claude Code (AI Assistant)

See [`CLAUDE.md`](CLAUDE.md) for AI-specific instructions.

---

## Project Overview

This repository contains comprehensive research and implementation proposal for building a **multi-signature (multisig) platform** on the **Linera blockchain**.

### What is Linera?

Linera is a blockchain protocol where each user has their own **microchain**, enabling:

- High throughput through parallel execution
- Low latency for user operations
- Native multi-owner chain support
- Cross-chain messaging for coordination

### Project Goal

Build a platform that allows users to:

1. Create multisig wallets with configurable thresholds (m-of-n)
2. Propose, approve, and execute transactions
3. Manage multiple signers and owner sets
4. Monitor proposal status and transaction history

---

## Technical Architecture

### Key Findings

| Component | Status |
|-----------|--------|
| Multi-owner chains | ✅ Native to Linera protocol |
| @linera/client SDK | ✅ Official TypeScript SDK available |
| Wasm smart contracts | ✅ Required for custom multisig logic |
| REST API | ✅ Custom implementation required |

### Verified Operations

```bash
# Multi-owner chain creation
linera open-multi-owner-chain \
    --from "$CHAIN1" \
    --owners "$OWNER1" "$OWNER2" \
    --initial-balance 10

# On-chain verification
linera sync
linera query-balance "$CHAIN_ID"
```

---

## Documentation Structure

```
linera.dev/
├── README.md                    # THIS FILE - Project overview
├── CLAUDE.md                    # Instructions for Claude Code AI
│
├── docs/                        # All research and analysis
│   ├── INFRASTRUCTURE_ANALYSIS.md  # Technical analysis and SDK information
│   │
│   ├── fundamentals/           # Basic Linera concepts
│   ├── technical/              # Deep technical analysis
│   ├── api/                    # API and SDK research
│   ├── research/               # Research reports
│   ├── diagrams/               # Architecture diagrams
│   │
│   └── PROPOSAL/               # Implementation proposal
│       └── linera-multisig-platform-proposal.md
│
└── open-agents/                # Open Agent System (see INSTRUCTIONS.md)
```

---

## Proposed Architecture (Adjusted for Reality)

```
┌─────────────────────────────────────────────────────────────────┐
│  Frontend (React + TypeScript)                                 │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │ Custom Wallet Implementation                            │   │
│  │ - Ed25519 key generation/storage                       │   │
│  │ - NOT MetaMask (not verified for multisig)             │   │
│  └─────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────────┐
│  Backend (Rust + Actix-web)                                    │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │ REST API (NOT GraphQL - doesn't work)                   │   │
│  │ Linera CLI Wrapper (NOT SDK integration)                │   │
│  │ - Wraps linera CLI commands                            │   │
│  │ - Parses output manually                               │   │
│  └─────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────────┐
│  Linera Network (Testnet Conway)                               │
│  - Multi-owner chains (VERIFIED WORKING)                       │
│  - Wasm multisig application (to be built)                     │
│  - Cross-chain messaging                                       │
└─────────────────────────────────────────────────────────────────┘
```

---

## Technology Stack (Reality-Checked)

| Layer | Technology | Status |
|-------|-----------|--------|
| **Smart Contracts** | Rust → Wasm (linera-sdk) | ✅ Required by Linera |
| **Backend** | Node.js/TypeScript + @linera/client | ✅ Official SDK available |
| **Frontend** | TypeScript/React + @linera/client | ✅ Official SDK available |
| **Database** | PostgreSQL + Prisma/TypeORM | ✅ TypeScript ecosystem |
| **API** | REST (Express/Fastify) | ✅ Custom implementation |
| **Wallet** | @linera/client (built-in) | ✅ SDK includes wallet management |

---

## Development Timeline (Adjusted)

| Milestone | Hours |
|-----------|-------|
| M1: Project Setup | 40h |
| M2: Multisig Contract | 170h |
| M3: Backend Core | 120h |
| M4: Frontend Core | 120h |
| M5: Integration | 80h |
| M6: Observability | 40h |
| M7: QA & UAT | 50h |
| M8: Handoff | 20h |
| **TOTAL** | **~580h** |

**Timeline**: ~15-16 weeks (3.5-4 months) with 1 FTE

See [`docs/PROPOSAL/linera-multisig-platform-proposal.md`](docs/PROPOSAL/linera-multisig-platform-proposal.md) for detailed breakdown.

---

## Quick Reference: Testnet Conway

### Faucet

```bash
https://faucet.testnet-conway.linera.net
```

### Validators

```
validator-1.testnet-conway.linera.net:443
validator-2.testnet-conway.linera.net:443
validator-3.testnet-conway.linera.net:443
```

### Verified Commands

```bash
# Initialize wallet
linera wallet init --faucet https://faucet.testnet-conway.linera.net

# Create multi-owner chain (VERIFIED)
linera open-multi-owner-chain \
    --from "$CHAIN1" \
    --owners "$OWNER1" "$OWNER2" \
    --initial-balance 10

# Sync with validators
linera sync

# Query balance (on-chain verification)
linera query-balance "$CHAIN_ID"
```

---

## Key Distinctions

### Multi-Owner Chain vs. Multisig Application

**Multi-Owner Chain (Protocol Level)**:

- ✅ Native to Linera
- ✅ Multiple owners can propose blocks
- ❌ NO threshold m-of-n (it's 1-of-N by default)
- ✅ Verified working on Testnet Conway

**Multisig Application (Smart Contract)**:

- ✅ Custom Wasm contract with m-of-n logic
- ✅ Thresholds, time-locks, conditions
- ❌ Requires learning linera-sdk
- ⚠️ No examples in documentation

**For this project**: We need BOTH - multi-owner chain for wallet ownership + Wasm application for threshold multisig logic.

---

## Risk Assessment

### Medium Risks

| Risk | Impact | Mitigation |
|------|--------|------------|
| **Fee model unknown** | Medium | Measure costs during PoC, budget optimization |
| **Multi-owner ≠ Multisig** | Medium | Application-level contract required |

---

## Reference Projects

- **Hathor Multisig**: `../hathor/docs/technical/hathor-multisig-platform-proposal.md`
- **Supra Multisig**: `../supra/docs/PROPOSAL/project-proposal-multisig.md`

These provide reference for proposal structure and estimation methodology.

---

## Status

| Component | Status | Notes |
|-----------|--------|-------|
| Research | ✅ Complete | Includes Testnet Conway validation |
| Infrastructure Analysis | ✅ Complete | Updated with critical blocker |
| Proposal | ✅ Complete | **BLOCKED** - See critical blocker below |
| Frontend/Backend (with @linera/client) | ✅ **VIABLE** | TypeScript SDK works for both |
| Multisig Contract (Rust) | ✅ Complete | **CANNOT DEPLOY** - 74/74 tests pass |
| Multi-Owner Chains | ✅ **VERIFIED** | Working on Testnet Conway |
| Custom Wasm Multisig | 🔴 **BLOCKED** | SDK ecosystem issue (opcode 252) |

### 🔴 CRITICAL BLOCKER: Safe-like Multisig NOT Possible

**Summary**: We CANNOT build a Safe-like multisig platform on Linera at this time.

**What Works** ✅:

- ✅ **Frontend** (React + @linera/client SDK) - **VIABLE**
- ✅ **Backend API** (Node.js/TypeScript + @linera/client) - **VIABLE**
- ✅ **Wallet Integration** (@linera/client Ed25519 keys) - **VIABLE**
- ✅ **Multi-Owner Chains** (native Linera protocol) - **VERIFIED**

**What DOES NOT Work** ❌:

- 🔴 **Custom Wasm Multisig Contract** - **CANNOT DEPLOY** (opcode 252)
- 🔴 **Threshold m-of-n Logic** - **IMPOSSIBLE** without Wasm contract
- 🔴 **Safe-like User Experience** - **CANNOT PROVIDE** (no proposal/approve/execute)

### The Problem in Detail

**Root Cause - Impossible Dependency Triangle**:

```
linera-sdk 0.15.11
    └─ async-graphql = "=7.0.17" (exact version pin)
        └─ requires: Rust 1.87+ (for let-chain syntax)
            └─ generates: memory.copy (opcode 252 / 0xFC)
                └─ blocked by: Linera runtime (no bulk memory support)
```

**All 8 Workaround Attempts FAILED**:

| Attempt | Result |
|---------|--------|
| Remove .clone() operations | ❌ Breaks mutability |
| Remove proposal history | ❌ Still 85 opcodes |
| Remove GraphQL service | ❌ Still 82 opcodes |
| Use Rust 1.86.0 | ❌ async-graphql doesn't compile |
| Patch async-graphql to 6.x | ❌ Version pin cannot be overridden |
| Replace async-graphql | ❌ 6.x/7.x incompatible |
| Hand-written Wasm | ❌ Security risk |
| Combined ALL above | ❌ Still 67 opcodes remain |

**Complete Evidence**:

- [Technical Analysis](docs/research/LINERA_OPCODE_252_ISSUE.md)
- [Code Analysis](docs/research/OPCODE_252_CODE_ANALYSIS.md)
- [Test Log (27 commands)](docs/research/OPCODE_252_INVESTIGATION_LOG.md)
- [Failed Patch Attempts](docs/research/ASYNC_GRAPHQL_DOWNGRADE_ATTEMPTS.md)

### What This Means

**WE CANNOT OFFER A SAFE-LIKE MULTISIG EXPERIENCE** because:

1. **Multi-Owner Chains** (protocol level):
   - ✅ Multiple owners can control a chain
   - ❌ But ANY owner can execute WITHOUT approval (1-of-N)
   - ❌ No threshold enforcement
   - ❌ No proposal/approval workflow

2. **Custom Wasm Contract** (required for Safe-like features):
   - ✅ Code complete (74/74 tests passing)
   - ✅ Logic correct (threshold, proposals, approvals)
   - ❌ **CANNOT DEPLOY** to Linera testnet
   - ❌ Opcode 252 causes deployment failure

### Only Viable Options

**Option A**: Build simplified wallet (multi-owner chains only)

- ✅ Shared wallet with multiple owners
- ❌ 1-of-N (any owner can execute)
- ❌ NOT a Safe-like multisig
- ~300 hours (~8 weeks)

**Option B**: Wait for Linera SDK team resolution

- Track: [Issue #4742](https://github.com/linera-io/linera-protocol/issues/4742)
- Timeline: UNKNOWN (not under project control)

**Option C**: Choose different blockchain with working multisig

- Hathor (has working multisig)
- Ethereum (Gnosis Safe)

### Official Status

🔴 **PROJECT BLOCKED** - Cannot proceed with Safe-like multisig platform until Linera SDK team resolves the opcode 252 issue.

This is a **Linera SDK ecosystem blocker**, not a project bug.

---

## Next Steps

1. ✅ Read [`docs/INFRASTRUCTURE_ANALYSIS.md`](docs/INFRASTRUCTURE_ANALYSIS.md) - Complete technical analysis
2. ✅ Review [`docs/PROPOSAL/linera-multisig-platform-proposal.md`](docs/PROPOSAL/linera-multisig-platform-proposal.md) - Updated with blocker
3. ❌ **DO NOT BEGIN M1** until Linera SDK issue is resolved OR requirements change

---

## Contributing

This is a research repository. When making changes:

1. Update documentation to reflect reality, not assumptions
2. Test on Testnet Conway before claiming something works
3. Document both successes AND failures

---

## License

[Your License Here]

---

**Last Updated**: February 4, 2026
**Contact**: [Your Contact Information]
