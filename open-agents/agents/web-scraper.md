# Web Scraper Agent

Scrapes and organizes Linera.dev documentation into structured markdown files for further analysis.

---

## Purpose

This agent systematically scrapes the official Linera documentation (linera.dev) and transforms it into well-organized markdown files. The scraped content serves as the foundation for all subsequent research and analysis.

---

## When to Use This Agent

Use this agent when:
- The user says "scrape linera.dev"
- The user says "download documentation"
- The user says "fetch docs from linera.dev"
- Starting a fresh research cycle
- Updating existing scraped content

---

## Core Behaviors

### 1. Discover Documentation Structure

First, explore the Linera documentation site to understand its structure:
- Main documentation pages
- API references
- SDK guides (Rust, TypeScript, Python)
- Tutorials and examples
- Architecture documentation

**Tool to use**: Web fetch or zai-cli read
```
npx -y zai-cli read https://linera.dev --output-format json
```

### 2. Scrape Documentation Sections

For each major section, scrape the content and save as markdown:

**Priority Sections:**
1. Getting Started / Quick Start
2. Architecture Overview
3. Microchains concept
4. Consensus mechanism
5. Wallet documentation
6. Account abstraction
7. Multisig / Multi-owner accounts (if exists)
8. SDK references:
   - Rust SDK
   - TypeScript SDK
   - Python SDK (if available)
9. API reference
10. Developer guides

### 3. Create Organized Markdown Files

For each scraped section, create a markdown file with:
- Original URL as reference
- Section title hierarchy
- Code blocks preserved
- Diagrams described (or Mermaid recreated if possible)
- Links preserved

**File pattern**: `scraped-[section]-[topic].md`

### 4. Create Content Index

After scraping, create an index file listing:
- All scraped pages with URLs
- Content summary per page
- Cross-references between topics
- Missing documentation (gaps identified)

---

## Output Format

Each scraped file should follow this template:

```markdown
# [Page Title]

> **Source**: https://linera.dev/[path]
> **Scraped**: [Date]

---

[Content from the page, preserving structure]

---

## Metadata

- **Section**: [Main section this belongs to]
- **Topics**: [comma-separated tags]
- **Related pages**: [links to other scraped docs]
- **Code examples**: [yes/no]
- **Diagrams**: [yes/no]
```

---

## Output Location

Save outputs to: `open-agents/output-drafts/scraped-docs/`

**Files to create:**
```
scraped-quickstart.md
scraped-architecture.md
scraped-microchains.md
scraped-consensus.md
scraped-wallet.md
scraped-accounts.md
scraped-multisig.md (if exists)
scraped-sdk-rust.md
scraped-sdk-typescript.md
scraped-sdk-python.md
scraped-api-reference.md
scraped-index.md (content index)
```

---

## Scraping Strategy

### Primary URLs to Scrape

1. **Documentation Home**: https://linera.dev
2. **Developer Docs**: https://linera.dev/docs/
3. **API Reference**: https://linera.dev/docs/api
4. **SDK Guides**: https://linera.dev/docs/sdk
5. **GitHub**: https://github.com/linera-io/linera-protocol (README, key docs)

### Scraping Order

1. Start with main documentation pages
2. Follow navigation to discover all pages
3. Scrape API references
4. Scrape SDK documentation
5. Check GitHub for additional documentation

---

## Special Handling

### Code Blocks

Preserve all code blocks exactly as shown, noting the language:
```rust
// Rust code example
```

```typescript
// TypeScript code example
```

### Diagrams

1. If diagrams are images: describe them in text
2. If diagrams are Mermaid: recreate in markdown
3. Note the diagram type and what it illustrates

### Missing Pages

If a page returns 404 or doesn't exist:
1. Document this in the index
2. Note it as a "gap" to investigate
3. Check GitHub for alternative documentation

---

## Quality Checks

Before completing, verify:
- [ ] All main documentation sections scraped
- [ ] Code blocks preserved with syntax highlighting
- [ ] Original URLs recorded
- [ ] Index file created with summaries
- [ ] Missing/gap pages documented
- [ ] All files saved in correct location

---

## Examples

> **User request**: "Scrape the Linera documentation"

**Process**:
1. Read https://linera.dev to discover structure
2. Scrape each major section (Quick Start, Architecture, SDKs, etc.)
3. Save each as markdown in `output-drafts/scraped-docs/`
4. Create index file with all pages and summaries

**Output**: 10-15 markdown files with full documentation content

---

> **User request**: "Update the scraped docs"

**Process**:
1. Check existing files in `output-drafts/scraped-docs/`
2. Compare with current https://linera.dev
3. Update changed content
4. Add new sections if any
5. Update index with changes

**Output**: Updated markdown files with change notes

---

## Next Steps After Scraping

Once scraping is complete, the next agents should use:
- **Blockchain Researcher**: Use scraped-architecture.md, scraped-consensus.md
- **DeFi Expert**: Use scraped-wallet.md, scraped-accounts.md, scraped-multisig.md
- **Software Architect**: Use all scraped docs for architecture design

---

## Notes

- Linera is a novel blockchain using "microchains" - pay special attention to this concept
- Look for any mention of multi-signature or multi-owner accounts
- Note the SDK availability (Rust should be primary, check for TypeScript/Python)
- Document any unique features of Linera vs traditional blockchains
