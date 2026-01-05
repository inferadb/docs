# Suggested Commands for InferaDB Documentation

## Linting and Validation

### Markdown Linting (Required - Blocking)
```bash
# Install markdownlint-cli2
npm install -g markdownlint-cli2@0.20.0

# Run markdown linting
markdownlint-cli2 "**/*.md" "#node_modules" "#.git" "#.vale"
```

### Spell Checking (Non-blocking)
```bash
# Install cspell
npm install -g cspell@8.17.0

# Run spell check
cspell --config .cspell/cspell.yaml "**/*.md"

# Add new words to dictionary
# Edit .cspell/inferadb.txt or .cspell/tech-terms.txt
```

### Prose Linting with Vale (Non-blocking)
```bash
# Install Vale (macOS)
brew install vale
# Or download from https://github.com/errata-ai/vale/releases

# Sync Vale packages (downloads Google, write-good, proselint styles)
vale sync

# Run prose linting
vale --output=line --minAlertLevel=warning .
```

### Internal Link Validation (Required - Blocking)
```bash
# Install markdown-link-check
npm install -g markdown-link-check@3.14.2

# Check internal links in a file
markdown-link-check <filename.md>
```

### External Link Validation (Optional)
```bash
# Install lychee (macOS)
brew install lychee
# Or download from https://github.com/lycheeverse/lychee/releases

# Check external links
lychee --config lychee.toml "**/*.md"
```

### Structure Validation (Required - Blocking)
```bash
# Run structure validation script
chmod +x .github/scripts/validate-structure.sh
.github/scripts/validate-structure.sh
```

## Complete Validation Suite
```bash
# Run all blocking checks (mimics CI)
markdownlint-cli2 "**/*.md" "#node_modules" "#.git" "#.vale"
.github/scripts/validate-structure.sh
```

## Git and Development

### Standard Git Commands
```bash
git status
git add <files>
git commit -m "message"
git push origin <branch>
git pull origin main
```

### File System (macOS/Darwin)
```bash
ls -la          # List files with details
find . -name "*.md"  # Find markdown files
grep -r "pattern" .  # Search in files
```

## Adding New Documentation

### Create a New RFC
```bash
cp templates/rfc-template.md rfcs/XXXX-title.md
# Edit the new file following style-guide.md
```
