# Linera Multisig Platform - Research & Proposal

> **⚠️ CRITICAL**: Before reviewing anything, read **[`docs/REALITY_CHECK.md`](docs/REALITY_CHECK.md)**. It contains findings from real Testnet Conway testing that invalidate several assumptions in earlier documentation.

---

## Quick Start

### For Developers

1. **Start Here**: [`docs/REALITY_CHECK.md`](docs/REALITY_CHECK.md) - Critical findings from Testnet Conway
2. **Infrastructure Analysis**: [`docs/INFRASTRUCTURE_ANALYSIS.md`](docs/INFRASTRUCTURE_ANALYSIS.md) - Updated with test results
3. **Implementation Proposal**: [`docs/PROPOSAL/linera-multisig-platform-proposal.md`](docs/PROPOSAL/linera-multisig-platform-proposal.md) - Complete development plan

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

## Critical Reality Check

> **This is the most important section** - read before making any technical decisions.

### What We Thought vs. What Reality Is

| Assumption | Reality (Tested on Testnet Conway) | Impact |
|------------|-----------------------------------|--------|
| GraphQL API works | ❌ Schema doesn't load in Node Service | Must use REST + CLI wrapper |
| Linera SDK is ready-to-use | ⚠️ Only for Wasm compilation, not client | Must build CLI wrapper from scratch |
| MetaMask integration available | ⚠️ Package exists but NOT verified for multisig | Must build custom wallet |
| Testnet Archimedes | ✅ Testnet Conway (#3) is current | Different URLs/commands |
| Timeline: 610 hours | ⚠️ 790-850 hours (+30-40%) | +4-5 weeks development time |

### What Actually Works (Verified)

```bash
# ✅ Multi-owner chain creation (TESTED & WORKING)
linera open-multi-owner-chain \
    --from "$CHAIN1" \
    --owners "$OWNER1" "$OWNER2" \
    --initial-balance 10

# ✅ On-chain verification (TESTED & WORKING)
linera sync
linera query-balance "$CHAIN_ID"
```

### What Doesn't Work (Tested & Failed)

```bash
# ❌ GraphQL queries (SCHEMA DOESN'T LOAD)
query { chains { chainId } }
# Result: "Unknown field chainId"
```

**Read [`docs/REALITY_CHECK.md`](docs/REALITY_CHECK.md) for complete technical findings.**

---

## Documentation Structure

```
linera.dev/
├── README.md                    # THIS FILE - Project overview
├── CLAUDE.md                    # Instructions for Claude Code AI
│
├── docs/                        # All research and analysis
│   ├── CLAUDE.md               # Documentation index (start here for docs)
│   ├── REALITY_CHECK.md        # ⚠️ CRITICAL - Testnet Conway findings
│   ├── INFRASTRUCTURE_ANALYSIS.md  # Updated with test results
│   │
│   ├── fundamentals/           # Basic Linera concepts
│   ├── technical/              # Deep technical analysis
│   ├── api/                    # API and SDK research
│   ├── research/               # Research reports
│   ├── diagrams/               # Architecture diagrams
│   │
│   └── PROPOSAL/               # Implementation proposal
│       ├── CLAUDE.md           # Proposal-specific guide
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
| **Backend** | Rust (Actix-web) + CLI Wrapper | ⚠️ Must build wrapper |
| **Frontend** | TypeScript/React | ⚠️ Custom wallet required |
| **Database** | PostgreSQL + Diesel/SeaORM | ✅ Rust ecosystem |
| **API** | REST (Custom) | ❌ GraphQL doesn't work |
| **Wallet** | Custom Implementation | ⚠️ No connector verified |

---

## Development Timeline (Adjusted)

| Milestone | Original | Adjusted | Change |
|-----------|----------|----------|--------|
| M1: Project Setup | 40h | 40h | 0% |
| M2: Multisig Contract | 120h | 170h | +42% |
| M3: Backend Core | 150h | 200h | +33% |
| M4: Frontend Core | 120h | 180h | +50% |
| M5-M7: Integration & QA | 180h | 200h | +11% |
| **TOTAL** | **~610h** | **~790h** | **+30%** |

**New Estimate**: 18-20 weeks (4.5-5 months)

**Rationale**: CLI wrapper + custom wallet + no GraphQL = more complex than originally estimated.

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

### High Risks (Mitigation Required)

| Risk | Impact | Mitigation |
|------|--------|------------|
| **GraphQL doesn't work** | High | Use REST + CLI wrapper (+40% backend time) |
| **No wallet connector** | High | Build custom wallet (+50% frontend time) |
| **CLI wrapper required** | High | Document patterns, build abstraction layer |
| **Fee model unknown** | Medium | Measure costs during PoC, budget optimization |

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
| Infrastructure Analysis | ✅ Complete | Updated with test results |
| Reality Check | ✅ Complete | Critical findings documented |
| Proposal | ✅ Complete | Timeline adjusted +30% |
| Development | ⏳ Not Started | Awaiting approval to proceed |

---

## Next Steps

1. ✅ Review [`docs/REALITY_CHECK.md`](docs/REALITY_CHECK.md) - **MANDATORY FIRST STEP**
2. ✅ Read [`docs/INFRASTRUCTURE_ANALYSIS.md`](docs/INFRASTRUCTURE_ANALYSIS.md)
3. ✅ Review [`docs/PROPOSAL/linera-multisig-platform-proposal.md`](docs/PROPOSAL/linera-multisig-platform-proposal.md)
4. ⏳ Approve adjusted timeline (790-850 hours)
5. ⏳ Begin M1: Project Setup

---

## Contributing

This is a research repository. When making changes:

1. Update documentation to reflect reality, not assumptions
2. Test on Testnet Conway before claiming something works
3. Document both successes AND failures
4. Cross-reference with [`docs/REALITY_CHECK.md`](docs/REALITY_CHECK.md)

---

## License

[Your License Here]

---

**Last Updated**: February 2, 2026
**Based On**: Real testing on Testnet Conway + documentation analysis
**Contact**: [Your Contact Information]
