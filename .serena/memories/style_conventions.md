# Style and Conventions for InferaDB Documentation

## File Naming
- **Use kebab-case** for all documentation files: `getting-started.md`, `audit-logs.md`
- **Exceptions**: Product names and proper nouns retain original casing: `InferaDB.md`, `OpenFGA.md`
- **No spaces** in filenames

## Headers
- Use **plain text Title Case** for all headers
- Use ATX-style headings (# syntax)
- **Avoid**:
  - Bold formatting in headers: `## **Wrong**`
  - Numbering in headers: `## 1. Wrong`
- Headers must be surrounded by blank lines

## Document Structure (RFCs)
Required sections for RFCs:
1. **Summary** - Brief overview
2. **Motivation** - Problem being solved
3. **Design Overview** - High-level approach
4. **Technical Specification** - Detailed implementation

Optional sections:
- Alternatives Considered
- Drawbacks
- Security and Privacy Considerations
- Rollout and Adoption Plan
- References

## RFC Frontmatter (Required)
```markdown
# RFC-XXXX: [Short Title]

**Author(s):** [Name(s)]
**Status:** Draft / Accepted / Implemented
**Created:** YYYY-MM-DD
**Updated:** YYYY-MM-DD
**Version:** 1.0

---
```

## Code Blocks
- **Always specify language** for syntax highlighting
- Common languages: `rust`, `praxis` (IPL), `bash`, `json`, `yaml`, `markdown`, `mermaid`

## Diagrams
- **Prefer Mermaid** diagrams over ASCII art
- Use plaintext only for directory trees
- Mermaid types: `flowchart`, `graph`, `sequenceDiagram`, `erDiagram`, `classDiagram`

## Links
- **Internal links**: Use relative paths: `[Getting Started](getting-started.md)`
- **External links**: Use full URLs: `[OpenFGA](https://openfga.dev/docs)`

## Lists
- Use **dashes** for unordered lists
- Use **2-space indent** for nested lists
- Use **ordered numbers** (1., 2., 3.) for ordered lists

## Markdown Style
- Line length: 120 characters (200 for code blocks)
- Use asterisks for emphasis (*italic*) and strong (**bold**)
- Use backticks for fenced code blocks
- Files must end with single newline

## Branding
Always capitalize correctly:
- InferaDB (not inferadb, Inferadb)
- GitHub, Kubernetes, Docker, Rust, TypeScript, JavaScript
- WebAssembly, WASM, FoundationDB, PostgreSQL, Tailscale

## Allowed HTML Elements
- `div`, `p`, `a`, `img`, `br`, `h1`, `details`, `summary`, `kbd`, `sub`, `sup`
