# Claude Code Instructions - Linera.dev Research Repository

> **For Human Developers**: See [`README.md`](README.md) for project overview and development guide.

> **⚠️ IMPORTANT**: Before implementing anything, read [`docs/REALITY_CHECK.md`](docs/REALITY_CHECK.md) for critical findings from Testnet Conway testing.

---

## Purpose of This File

This `CLAUDE.md` file contains instructions specifically for **Claude Code** (the AI coding assistant).

**For humans**: Start with [`README.md`](README.md) instead.

---

## Critical Context

This repository contains research and proposal for building a multisig platform on Linera blockchain.

**⚠️ CRITICAL FINDING**: [`docs/REALITY_CHECK.md`](docs/REALITY_CHECK.md) documents that several assumptions from official documentation are WRONG when tested on real Testnet Conway:
- GraphQL does NOT work (schema doesn't load)
- Linera SDK is NOT a client SDK (only for Wasm compilation)
- No wallet connector is verified for multisig use

**Always reference [`docs/REALITY_CHECK.md`](docs/REALITY_CHECK.md) when making technical decisions.**

---

## Open Agent System

This project includes an **Open Agent System** for coordinated blockchain research.

**To use the agent system**: Read `open-agents/INSTRUCTIONS.md`

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
├── open-agents/           # Agent system (see INSTRUCTIONS.md)
├── docs/                  # Research and documentation
│   ├── CLAUDE.md          # Docs index (for Claude)
│   ├── REALITY_CHECK.md   # ⚠️ CRITICAL - Testnet findings
│   ├── INFRASTRUCTURE_ANALYSIS.md
│   ├── PROPOSAL/
│   │   ├── CLAUDE.md
│   │   └── linera-multisig-platform-proposal.md
│   ├── fundamentals/
│   ├── technical/
│   ├── api/
│   ├── research/
│   └── diagrams/
└── .gitignore
```

---

## Research Goals

1. **Understand Linera's Architecture**: Consensus, microchains, wallet system
2. **Analyze Multisig Capabilities**: How multi-signature works on Linera
3. **Identify SDKs and APIs**: Rust, TypeScript, Python availability
4. **Design Platform Architecture**: Frontend/backend for multisig management
5. **Estimate Development Hours**: Based on similar Hathor/Supra projects

---

## Reference Projects

- **Hathor**: `../hathor/docs/technical/hathor-multisig-platform-proposal.md`
- **Supra**: `../supra/docs/PROPOSAL/project-proposal-multisig.md`

Study these for proposal structure and estimation methodology.

## Open Agent System

This project includes an **Open Agent System** for coordinated blockchain research.

**To use the agent system:** Read `open-agents/INSTRUCTIONS.md`

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
├── open-agents/          # Agent system (see INSTRUCTIONS.md)
├── docs/                 # Final research documents
│   ├── fundamentals/     # Basic concepts
│   ├── technical/        # Technical analysis
│   ├── api/             # API and SDK research
│   ├── research/        # Research reports
│   ├── diagrams/        # Architecture diagrams
│   └── PROPOSAL/        # Final proposal with hours estimate
└── CLAUDE.md            # This file
```

---

## Research Goals

1. **Understand Linera's Architecture**: Consensus, microchains, wallet system
2. **Analyze Multisig Capabilities**: How multi-signature works on Linera
3. **Identify SDKs and APIs**: Rust, TypeScript, Python availability
4. **Design Platform Architecture**: Frontend/backend for multisig management
5. **Estimate Development Hours**: Based on similar Hathor/Supra projects

---

## Reference Projects

- **Hathor**: `../hathor/docs/technical/hathor-multisig-platform-proposal.md`
- **Supra**: `../supra/docs/PROPOSAL/project-proposal-multisig.md`

Study these for proposal structure and estimation methodology.


<claude-mem-context>
# Recent Activity

<!-- This section is auto-generated by claude-mem. Edit content outside the tags. -->

### Feb 2, 2026

| ID | Time | T | Title | Read |
|----|------|---|-------|------|
| #20433 | 10:56 AM | 🟣 | AGENTS.md entry point created for Codex compatibility | ~225 |
| #20432 | " | 🟣 | CLAUDE.md entry point created with mandatory read directive | ~268 |
</claude-mem-context>