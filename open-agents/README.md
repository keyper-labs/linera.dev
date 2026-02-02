# Open Agent System: Linera.dev Research

This folder contains an **Open Agent System** for comprehensive research and analysis of the Linera blockchain platform.

## Purpose

This system transforms AI coding assistants into specialized research agents that:
- Scrape and analyze Linera.dev documentation
- Research blockchain architecture and consensus mechanisms
- Analyze DeFi capabilities, particularly multisig solutions
- Design frontend/backend architecture proposals
- Produce comprehensive technical documentation

## Quick Start

Read `INSTRUCTIONS.md` for:
- Available agents and what they do
- How to invoke each agent
- Routing logic and workflow

## Agents Overview

| Agent | Specialization | Output |
|-------|---------------|--------|
| **Web Scraper** | Documentation scraping | Raw markdown dumps |
| **Blockchain Researcher** | Protocol analysis | Technical research |
| **DeFi Expert** | Multisig/DeFi analysis | DeFi research docs |
| **Software Architect** | System design | Architecture proposals |
| **Auditor** | Quality validation | Audit reports |

## Folder Structure

```
open-agents/
├── agents/           # Agent definition files
├── tools/            # Scripts created by agents
├── source/           # Raw inputs and stubs
├── output-drafts/    # First-stage outputs
├── output-refined/   # Reviewed content
└── output-final/     # Publication-ready materials
```

## Research Targets

- **Official Docs**: https://linera.dev
- **GitHub**: https://github.com/linera-io/linera-protocol
- **SDK**: Rust, TypeScript, Python
- **Wallet**: Wallet implementations and key management
- **Multisig**: Multi-signature capabilities

---

**Created by**: Palmera DAO Team
**Date**: February 2, 2026
**Based on**: Open Agent System specification
