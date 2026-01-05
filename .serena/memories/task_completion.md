# Task Completion Checklist for InferaDB Documentation

## Before Completing a Documentation Task

### 1. Run Blocking Checks (Required)
These checks must pass for CI to succeed:

```bash
# Markdown linting
markdownlint-cli2 "**/*.md" "#node_modules" "#.git" "#.vale"

# Structure validation
.github/scripts/validate-structure.sh
```

### 2. Run Non-Blocking Checks (Recommended)
These produce warnings but don't fail CI:

```bash
# Spell check
cspell --config .cspell/cspell.yaml "**/*.md"

# Prose linting
vale sync  # First time only
vale --output=line --minAlertLevel=warning .
```

### 3. Verify Style Compliance
- [ ] File uses kebab-case naming (unless product name)
- [ ] Headers use plain Title Case (no bold, no numbers)
- [ ] Code blocks have language tags
- [ ] Diagrams use Mermaid (not ASCII art)
- [ ] Internal links use relative paths
- [ ] Branding is correct (InferaDB, not inferadb)

### 4. For RFC Documents
- [ ] Has required frontmatter (Author, Status, Created)
- [ ] Includes Summary, Motivation, Design Overview, Technical Specification
- [ ] File placed in `rfcs/` directory with pattern `XXXX-title.md`

### 5. Final Checks
- [ ] File ends with single newline (POSIX compliance)
- [ ] No trailing spaces on lines
- [ ] Tables have leading/trailing pipes
- [ ] Images have alt text

## CI Validation Jobs

| Job | Status | Description |
|-----|--------|-------------|
| markdown-lint | Blocking | Markdown style enforcement |
| link-internal | Blocking | Internal link validation |
| structure | Blocking | File naming, frontmatter |
| spell-check | Non-blocking | Spelling errors |
| prose-lint | Non-blocking | Writing quality |

## Adding Words to Spell Check Dictionary
If cspell flags a legitimate technical term:
1. Add to `.cspell/inferadb.txt` for InferaDB-specific terms
2. Add to `.cspell/tech-terms.txt` for general tech terms
