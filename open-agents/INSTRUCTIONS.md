# Linera.dev Research System

An Open Agent System for comprehensive research and analysis of the Linera blockchain platform, with focus on multisig platform development.

---

## How This System Works

1. **Entry points** (CLAUDE.md, AGENTS.md, GEMINI.md) point to this file
2. **This file** catalogs all agents and routing logic
3. **Agent files** load on-demand when triggered
4. **Audit agents** validate outputs from local agents

---

## Project Structure

```
linera.dev/
├── CLAUDE.md                    # Entry point for Claude Code
├── AGENTS.md                    # Entry point for Codex
├── GEMINI.md                    # Entry point for Gemini CLI
│
├── .claude/commands/linera/     # Claude commands
├── .gemini/commands/linera/     # Gemini commands
│
├── open-agents/                 # Agent system container
│   ├── README.md                # Human-readable intro
│   ├── INSTRUCTIONS.md          # This file
│   │
│   ├── agents/                  # Agent definitions
│   │   ├── web-scraper.md       # Scrapes linera.dev
│   │   ├── blockchain-researcher.md  # Protocol analysis
│   │   ├── defi-expert.md       # DeFi/multisig analysis
│   │   ├── software-architect.md     # Architecture design
│   │   ├── auditor-quality.md    # Quality auditor
│   │   ├── auditor-accuracy.md  # Accuracy auditor
│   │   └── auditor-completeness.md  # Completeness auditor
│   │
│   ├── tools/                   # Agent-created scripts
│   ├── source/                  # Raw inputs and stubs
│   ├── output-drafts/           # First-stage outputs
│   ├── output-refined/          # Reviewed content
│   └── output-final/            # Final deliverables
│
└── docs/                        # Final research documents
    ├── fundamentals/            # Basic concepts
    ├── technical/               # Technical analysis
    ├── api/                     # API and SDK research
    ├── research/                # Research reports
    ├── diagrams/                # Architecture diagrams
    └── PROPOSAL/                # Final proposal
```

---

## Available Agents

### Local Research Agents

#### 1. Web Scraper (`agents/web-scraper.md`)

**Purpose:** Scrape and organize Linera.dev documentation into structured markdown.

**When to use:**
- "Scrape linera.dev documentation"
- "Download docs from linera.dev"
- "Fetch documentation"

**Output:** Raw markdown files in `open-agents/output-drafts/scraped-docs/`

**To use:** Read `open-agents/agents/web-scraper.md`

---

#### 2. Blockchain Researcher (`agents/blockchain-researcher.md`)

**Purpose:** Analyze Linera's blockchain architecture, consensus mechanism, and protocol details.

**When to use:**
- "Research Linera consensus"
- "Analyze blockchain architecture"
- "Explain how Linera works"

**Output:** Research documents in `open-agents/output-drafts/blockchain-research/`

**To use:** Read `open-agents/agents/blockchain-researcher.md`

---

#### 3. DeFi Expert (`agents/defi-expert.md`)

**Purpose:** Analyze Linera's DeFi capabilities, focusing on multisig, wallet, and account management.

**When to use:**
- "Analyze multisig capabilities"
- "Research wallet implementations"
- "DeFi features analysis"

**Output:** Analysis in `open-agents/output-drafts/defi-analysis/`

**To use:** Read `open-agents/agents/defi-expert.md`

---

#### 4. Software Architect (`agents/software-architect.md`)

**Purpose:** Design frontend/backend architecture for a Linera multisig platform based on research findings.

**When to use:**
- "Design multisig platform architecture"
- "Create system architecture"
- "Propose technical solution"

**Output:** Architecture docs in `open-agents/output-refined/architecture/`

**To use:** Read `open-agents/agents/software-architect.md`

---

### Audit Agents (Custom)

#### 5. Quality Auditor (`agents/auditor-quality.md`)

**Purpose:** Validate the quality, clarity, and structure of research outputs.

**When to use:**
- After any local agent produces output
- "Review quality of this document"

**Output:** Audit reports in `open-agents/output-final/audits/quality/`

**To use:** Read `open-agents/agents/auditor-quality.md`

---

#### 6. Accuracy Auditor (`agents/auditor-accuracy.md`)

**Purpose:** Verify technical accuracy against official Linera documentation.

**When to use:**
- Validate technical claims
- Cross-reference with official docs

**Output:** Audit reports in `open-agents/output-final/audits/accuracy/`

**To use:** Read `open-agents/agents/auditor-accuracy.md`

---

#### 7. Completeness Auditor (`agents/auditor-completeness.md`)

**Purpose:** Ensure all required topics are covered for a comprehensive proposal.

**When to use:**
- Before finalizing proposal
- "Check if research is complete"

**Output:** Audit reports in `open-agents/output-final/audits/completeness/`

**To use:** Read `open-agents/agents/auditor-completeness.md`

---

## Routing Logic

| User says... | Agent to use | Notes |
|--------------|--------------|-------|
| "Scrape linera.dev" | Web Scraper | Initial data gathering |
| "Research blockchain/architecture" | Blockchain Researcher | Technical deep dive |
| "Analyze multisig/DeFi" | DeFi Expert | Focus on multisig |
| "Design architecture" | Software Architect | Synthesis of research |
| "Review quality" | Quality Auditor | Validate any output |
| "Verify accuracy" | Accuracy Auditor | Cross-reference docs |
| "Check completeness" | Completeness Auditor | Final review |

---

## Research Workflow

The recommended workflow for Linera multisig platform research:

```
Phase 1: Data Collection
└── Web Scraper → Scraped documentation

Phase 2: Technical Analysis (Parallel)
├── Blockchain Researcher → Protocol analysis
└── DeFi Expert → Multisig/wallet analysis

Phase 3: Synthesis
└── Software Architect → Architecture proposal

Phase 4: Validation (Parallel)
├── Quality Auditor → Quality check
├── Accuracy Auditor → Accuracy verification
└── Completeness Auditor → Coverage check

Phase 5: Finalization
└── Move to docs/PROPOSAL/ with hours estimate
```

---

## Reference Documentation

Study these examples from similar projects:

- **Hathor**: `/Users/alfredolopez/Documents/GitHub/PalmeraDAO/hathor/docs/technical/hathor-multisig-platform-proposal.md`
- **Supra**: `/Users/alfredolopez/Documents/GitHub/PalmeraDAO/supra/docs/PROPOSAL/project-proposal-multisig.md`

Key sections to replicate:
- Objectives
- In-Scope / Out-of-Scope
- Architecture (with Mermaid diagrams)
- Key Flow (Propose → Approve → Execute)
- Milestones & Deliverables **with hours estimate**
- Technical Implementation
- Risks & Mitigations
- Dependencies

---

## Git Commit Protocol

After each major agent output:

```bash
git add open-agents/output-*/
git commit -m "[agent-name]: [brief description]

Agent: [agent name]
Output: [output location]
Status: [draft/refined/final]"
```

After audit validation:

```bash
git add open-agents/output-final/audits/
git commit -m "audit: [audit-type] for [target]

Auditor: [auditor name]
Target: [what was audited]
Result: [pass/fail/needs-revision]"
```

---

## File Naming Conventions

- Scraped docs: `scraped-[section]-[topic].md`
- Research: `research-[category]-[topic].md`
- Architecture: `architecture-[component].md`
- Audits: `audit-[type]-[target].md`
- Final proposal: `linera-multisig-platform-proposal.md`

---

## Managing This System

### Adding a New Agent

1. Create `open-agents/agents/{name}.md`
2. Create commands in `.claude/commands/linera/` and `.gemini/commands/linera/`
3. Add entry to "Available Agents" above
4. Add routing entry to routing table
5. Commit changes

### Editing an Agent

1. Modify `open-agents/agents/{name}.md`
2. Update commands if invocation changes
3. Update routing table if triggers change
4. Commit changes

### Removing an Agent

1. Delete agent file and command files
2. Remove from "Available Agents" and routing table
3. Commit changes

---

## Quick Start Commands

```bash
# Start research
/linera scrape                    # Scrape documentation
/linera research-blockchain       # Research blockchain
/linera analyze-defi              # Analyze DeFi/multisig
/linera design-architecture       # Design architecture

# Audit outputs
/linera audit-quality [file]      # Quality check
/linera audit-accuracy [file]     # Accuracy verification
/linera audit-completeness [file] # Completeness check
```

---

**Based on**: Open Agent System specification by @bladnman
**Created for**: Palmera DAO Linera Multisig Platform Research
