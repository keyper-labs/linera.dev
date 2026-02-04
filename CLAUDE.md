# Claude Code Instructions - Linera.dev Research Repository

> **For Human Developers**: See [`README.md`](README.md) for project overview and development guide.

---

## Purpose of This File

This `CLAUDE.md` file contains instructions specifically for **Claude Code** (the AI coding assistant).

**For humans**: Start with [`README.md`](README.md) instead.

---

## CRITICAL: Document Integrity Policy

### No Correction Trail Policy

**All documentation corrections must appear seamless.**

When fixing errors in existing documents:

1. **NO correction files in repo** - Never create `*_CORRECTION*.md`, `*_ANALYSIS*.md`, or versioned files
2. **NO git history of errors** - Amend commits or ensure corrections appear as original content
3. **NO error acknowledgments** - Documents should read as if always correct
4. **Local analysis only** - If analysis needed, use `.local-analysis/` (already in `.gitignore`)

**Correct approach**: Edit the original file directly. The document should appear as if it was always correct.

**Example**:
- ❌ WRONG: Create `BACKEND_SDK_CORRECTION_SUMMARY.md` explaining the error
- ✅ CORRECT: Simply update `INFRASTRUCTURE_ANALYSIS.md` with correct information

---

## Critical Context

This repository contains research and proposal for building a multisig platform on Linera blockchain.

**Key Technical Findings**:
- @linera/client SDK is the official TypeScript SDK for backend/frontend
- Multi-owner chains are supported natively by Linera
- TypeScript full-stack architecture is recommended
- REST API approach is preferred over GraphQL

---

## Open Agent System

This project includes an **Open Agent System** for coordinated blockchain research.

**To use the agent system**: Read [`open-agents/INSTRUCTIONS.md`](open-agents/INSTRUCTIONS.md)

### Quick Reference

| Agent | Command | Output |
|-------|---------|--------|
| Web Scraper | `/linera scrape` | Scraped docs |
| Blockchain Researcher | `/linera research-blockchain` | Technical research |
| DeFi Expert | `/linera analyze-defi` | DeFi/multisig analysis |
| Software Architect | `/linera design-architecture` | Architecture proposal |
| Quality Auditor | `/linera audit-quality [file]` | Quality reports |
| Accuracy Auditor | `/linera audit-accuracy [file]` | Accuracy reports |
| Completeness Auditor | `/linera audit-completeness [file]` | Completeness reports |

---

## Project Structure

```
linera.dev/
├── README.md              # START HERE for humans
├── CLAUDE.md              # This file - instructions for Claude Code
├── AGENTS.md              # Entry point for Codex-compatible agent system
├── open-agents/           # Agent system (see INSTRUCTIONS.md)
├── scripts/               # Testing and setup scripts
├── docs/                  # Research and documentation
│   ├── INFRASTRUCTURE_ANALYSIS.md
│   ├── PROPOSAL/
│   │   └── linera-multisig-platform-proposal.md
│   ├── fundamentals/      # Basic Linera concepts
│   ├── technical/         # Deep technical analysis
│   ├── api/               # API and SDK research
│   ├── research/          # Research reports
│   └── diagrams/          # Architecture diagrams
└── .gitignore
```

---

## Research Goals

1. **Understand Linera's Architecture**: Consensus, microchains, wallet system
2. **Analyze Multisig Capabilities**: How multi-signature works on Linera
3. **Identify SDKs and APIs**: TypeScript (@linera/client), Rust (linera-sdk), Python availability
4. **Design Platform Architecture**: Frontend/backend for multisig management
5. **Estimate Development Hours**: Based on similar Hathor/Supra projects

---

## Recommended Architecture (TypeScript Full-Stack)

```
┌─────────────────────────────────────────────────────────────────┐
│  Frontend (React + TypeScript + @linera/client)               │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │ Custom Wallet (Ed25519 key management via SDK)          │   │
│  └─────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────────┐
│  Backend (Node.js/TypeScript + @linera/client SDK)            │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │ REST API (Express/Fastify)                              │   │
│  │ @linera/client SDK for Linera integration               │   │
│  │ PostgreSQL + Redis for storage                          │   │
│  └─────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────────┐
│  Linera Network (Testnet Conway)                               │
│  - Multi-owner chains (VERIFIED WORKING)                       │
│  - Wasm multisig application (Rust → Wasm)                     │
│  - Cross-chain messaging                                       │
└─────────────────────────────────────────────────────────────────┘
```

**Key Decision**: Use TypeScript full-stack with `@linera/client` SDK instead of Rust CLI wrapper.

---

## Reference Projects

- **Hathor**: `../hathor/docs/technical/hathor-multisig-platform-proposal.md`
- **Supra**: `../supra/docs/PROPOSAL/project-proposal-multisig.md`

Study these for proposal structure and estimation methodology.

---

## Important Commands

### For Development
```bash
# Run all tests
make all

# CLI multi-owner chain test
make cli-test

# SDK multisig test
make rust-test
```

### For Documentation
- Main proposal: [`docs/PROPOSAL/linera-multisig-platform-proposal.md`](docs/PROPOSAL/linera-multisig-platform-proposal.md)
- Infrastructure analysis: [`docs/INFRASTRUCTURE_ANALYSIS.md`](docs/INFRASTRUCTURE_ANALYSIS.md)

---

## Technology Stack (Reality-Checked)

| Layer | Technology | Status |
|-------|-----------|--------|
| **Smart Contracts** | Rust → Wasm (linera-sdk) | ✅ Required by Linera |
| **Backend** | Node.js/TypeScript + @linera/client | ✅ Official SDK available |
| **Frontend** | TypeScript/React + @linera/client | ✅ Official SDK available |
| **Database** | PostgreSQL + Redis | ✅ Node.js ecosystem |
| **API** | REST (Express/Fastify) | ✅ GraphQL doesn't work reliably |
| **Wallet** | Custom Implementation | ⚠️ No connector verified |

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

---

## Testing

See [`scripts/README.md`](scripts/README.md) for comprehensive testing guide.

### Quick Test
```bash
cd /Users/alfredolopez/Documents/GitHub/PalmeraDAO/linera.dev/scripts
make all
```

---

## Status

| Component | Status | Notes |
|-----------|--------|-------|
| Research | ✅ Complete | Includes Testnet Conway validation |
| Infrastructure Analysis | ✅ Complete | Updated with test results |
| Proposal | ✅ Complete | Timeline based on TypeScript SDK |
| Multisig Contract (Rust) | ✅ Complete | Safe standard, 74/74 tests passing |
| Testnet Deployment | 🔴 **CRITICAL** | SDK ecosystem blocker |
| Backend Development | ⏳ Not Started | Blocked by Linera SDK |

### 🔴 Critical Blocker: Linera SDK Ecosystem Issue

**Problem**: No working combination of current linera-sdk + modern Rust + Linera runtime

**Dependency Chain**:
```
linera-sdk 0.15.11
  └─ async-graphql = "=7.0.17" (pinned, all 0.15.x versions)
      └─ requires Rust 1.87+ (let-chain syntax)
          └─ generates memory.copy (opcode 252)
              └─ Linera runtime doesn't support
```

**Why No Solution Exists Currently**:
- Rust 1.86 ✅ = Wasm compatible, BUT async-graphql 7.x ❌
- Rust 1.87+ ✅ = async-graphql compiles, BUT opcode 252 ❌
- ALL linera-sdk 0.15.x versions require async-graphql 7.0.17

**This requires Linera team action** - not solvable at project level.

**Official Issue**: [linera-protocol#4742](https://github.com/linera-io/linera-protocol/issues/4742)

**Full Analysis**: [`docs/research/LINERA_OPCODE_252_ISSUE.md`](docs/research/LINERA_OPCODE_252_ISSUE.md) |

---

## Next Steps

1. ✅ Read [`docs/INFRASTRUCTURE_ANALYSIS.md`](docs/INFRASTRUCTURE_ANALYSIS.md)
2. ✅ Review [`docs/PROPOSAL/linera-multisig-platform-proposal.md`](docs/PROPOSAL/linera-multisig-platform-proposal.md)
3. ⏳ Approve adjusted timeline (580 hours)
4. ⏳ Begin M1: Project Setup

---

## Contributing

This is a research repository. When making changes:

1. Update documentation to reflect reality, not assumptions
2. Test on Testnet Conway before claiming something works
3. Document both successes AND failures

---

**Last Updated**: February 3, 2026
