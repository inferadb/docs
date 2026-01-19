# InferaDB Documentation Project Overview

## Purpose
This repository contains technical specifications, deployment guides, design proposals, and whitepapers for InferaDB - a database project currently under active development (not production-ready).

## Tech Stack
- **Documentation Format**: Markdown (.md, .mdx)
- **Linting Tools**:
  - **markdownlint-cli2** (v0.20.0) - Markdown style enforcement
  - **Vale** (v3.9.4) - Prose linting with Google, write-good, proselint styles
  - **cspell** (v8.17.0) - Spell checking
  - **lychee** (v0.18.0) - External link validation
  - **markdown-link-check** - Internal link validation
- **CI/CD**: GitHub Actions (docs-validate.yml workflow)

## Repository Structure
```
docs/
├── whitepapers/       # Technical publications (InferaDB.md)
├── templates/         # RFC template and style guide
│   ├── rfc-template.md
│   └── style-guide.md
├── rfcs/             # Feature proposals (use template)
├── architecture/     # Architecture documentation
├── guides/           # How-to guides
├── designs/          # Design documents
├── diagrams/         # Diagram files
├── .vale/            # Vale prose linting configuration
│   └── styles/       # Custom InferaDB rules + Google/proselint/write-good
├── .cspell/          # Spell check configuration and dictionaries
└── .github/          # GitHub workflows, templates, and scripts
```

## Related Repositories
Component documentation lives in respective repositories:
- **engine/docs/** - Engine docs (API, IPL, architecture)
- **control/docs/** - Control docs (authentication, entities)
- **deploy/docs/** - Deployment guides

## Key Technologies Mentioned
- Rust (primary language for InferaDB)
- Praxis (Infera Policy Language - IPL)
- PostgreSQL (database comparisons)
- Kubernetes, Docker (deployment)
- Mermaid (diagrams)
