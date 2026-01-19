#!/usr/bin/env bash
# InferaDB Documentation - Structure Validation Script
# Validates file naming, directory structure, and frontmatter requirements

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Counters
ERRORS=0
WARNINGS=0

# Logging functions
log_error() {
    echo -e "${RED}ERROR${NC}: $1"
    ((ERRORS++))
}

log_warning() {
    echo -e "${YELLOW}WARNING${NC}: $1"
    ((WARNINGS++))
}

log_success() {
    echo -e "${GREEN}PASS${NC}: $1"
}

log_info() {
    echo "INFO: $1"
}

# ============================================================================
# File Naming Validation
# ============================================================================

validate_file_naming() {
    log_info "Validating file naming conventions..."

    # Product names that are exceptions to kebab-case
    local product_names="InferaDB|OpenFGA|SpiceDB|AuthZed|Tailscale|PostgreSQL|CockroachDB|GitHub|README|CHANGELOG|LICENSE|CONTRIBUTING|SECURITY|CODEOWNERS"

    # Find all markdown files
    while IFS= read -r -d '' file; do
        local filename
        filename=$(basename "$file" .md)

        # Skip files in templates directory (they may have placeholders)
        if [[ "$file" == *"/templates/"* ]]; then
            continue
        fi

        # Skip files that are product names or standard files
        if [[ "$filename" =~ ^($product_names)$ ]]; then
            continue
        fi

        # Skip uppercase standard files
        if [[ "$filename" =~ ^[A-Z_]+$ ]]; then
            continue
        fi

        # Check for kebab-case (lowercase with hyphens only)
        if [[ ! "$filename" =~ ^[a-z0-9]+(-[a-z0-9]+)*$ ]]; then
            # Check if it's a product name file like "InferaDB.md"
            if [[ ! "$filename" =~ ^($product_names)$ ]]; then
                log_error "File '$file' does not follow kebab-case naming convention"
            fi
        fi
    done < <(find . -name "*.md" -type f -print0 2>/dev/null)

    # Check for files with spaces
    while IFS= read -r -d '' file; do
        if [[ "$file" == *" "* ]]; then
            log_error "File '$file' contains spaces in filename"
        fi
    done < <(find . -name "*.md" -type f -print0 2>/dev/null)
}

# ============================================================================
# Directory Structure Validation
# ============================================================================

validate_directory_structure() {
    log_info "Validating directory structure..."

    # Required directories
    local required_dirs=("templates")

    for dir in "${required_dirs[@]}"; do
        if [[ ! -d "$dir" ]]; then
            log_warning "Expected directory '$dir' not found"
        fi
    done

    # Check for orphan directories (directories with no content)
    while IFS= read -r -d '' dir; do
        # Skip hidden directories and common non-content dirs
        if [[ "$dir" == *"/."* ]] || [[ "$dir" == "./node_modules"* ]]; then
            continue
        fi

        # Count files in directory
        local file_count
        file_count=$(find "$dir" -maxdepth 1 -type f -name "*.md" 2>/dev/null | wc -l | tr -d ' ')

        if [[ "$file_count" -eq 0 ]]; then
            # Check for subdirectories with content
            local subdir_count
            subdir_count=$(find "$dir" -mindepth 1 -type d 2>/dev/null | wc -l | tr -d ' ')

            if [[ "$subdir_count" -eq 0 ]]; then
                log_warning "Directory '$dir' appears to be empty"
            fi
        fi
    done < <(find . -type d -print0 2>/dev/null)

    # Check for README or index in major directories
    local major_dirs=("guides" "whitepapers" "rfcs" "architecture")

    for dir in "${major_dirs[@]}"; do
        if [[ -d "$dir" ]]; then
            if [[ ! -f "$dir/README.md" ]] && [[ ! -f "$dir/index.md" ]]; then
                log_warning "Directory '$dir' lacks a README.md or index.md"
            fi
        fi
    done
}

# ============================================================================
# Frontmatter Validation
# ============================================================================

validate_frontmatter() {
    log_info "Validating frontmatter requirements..."

    # RFC files must have specific frontmatter
    if [[ -d "rfcs" ]]; then
        while IFS= read -r -d '' file; do
            # Skip template file
            if [[ "$file" == *"rfc-template"* ]]; then
                continue
            fi

            # Check for required frontmatter fields
            local has_author=false
            local has_status=false
            local has_created=false

            # Read first 20 lines to check frontmatter
            local in_frontmatter=false
            local line_count=0

            while IFS= read -r line; do
                ((line_count++))

                if [[ $line_count -eq 1 ]] && [[ "$line" != "---" ]]; then
                    # No frontmatter delimiter at start
                    break
                fi

                if [[ "$line" == "---" ]]; then
                    if [[ "$in_frontmatter" == true ]]; then
                        break
                    fi
                    in_frontmatter=true
                    continue
                fi

                if [[ "$in_frontmatter" == true ]]; then
                    if [[ "$line" =~ ^[Aa]uthor ]]; then
                        has_author=true
                    fi
                    if [[ "$line" =~ ^[Ss]tatus ]]; then
                        has_status=true
                    fi
                    if [[ "$line" =~ ^[Cc]reated ]]; then
                        has_created=true
                    fi
                fi

                if [[ $line_count -gt 20 ]]; then
                    break
                fi
            done < "$file"

            # Report missing fields for RFCs
            if [[ "$has_author" == false ]]; then
                log_error "RFC '$file' missing Author in frontmatter"
            fi
            if [[ "$has_status" == false ]]; then
                log_error "RFC '$file' missing Status in frontmatter"
            fi
            if [[ "$has_created" == false ]]; then
                log_warning "RFC '$file' missing Created date in frontmatter"
            fi
        done < <(find rfcs -name "*.md" -type f -print0 2>/dev/null)
    fi

    # Check style guide and templates have metadata header
    if [[ -d "templates" ]]; then
        while IFS= read -r -d '' file; do
            # Check first line for frontmatter or title
            local first_line
            first_line=$(head -n 1 "$file")

            if [[ "$first_line" != "---" ]] && [[ "$first_line" != "#"* ]]; then
                log_warning "Template '$file' should start with frontmatter (---) or heading (#)"
            fi
        done < <(find templates -name "*.md" -type f -print0 2>/dev/null)
    fi
}

# ============================================================================
# Internal Link Validation (Basic)
# ============================================================================

validate_internal_links() {
    log_info "Validating internal link references..."

    while IFS= read -r -d '' file; do
        # Extract markdown links [text](path)
        while IFS= read -r link; do
            # Skip external links
            if [[ "$link" =~ ^https?:// ]] || [[ "$link" =~ ^mailto: ]]; then
                continue
            fi

            # Skip anchor-only links
            if [[ "$link" =~ ^# ]]; then
                continue
            fi

            # Remove anchor from link
            local link_path="${link%%#*}"

            # Skip empty paths
            if [[ -z "$link_path" ]]; then
                continue
            fi

            # Resolve relative path
            local dir
            dir=$(dirname "$file")
            local resolved_path="$dir/$link_path"

            # Normalize path
            resolved_path=$(cd "$dir" 2>/dev/null && realpath -m "$link_path" 2>/dev/null || echo "$resolved_path")

            # Check if file exists
            if [[ ! -e "$resolved_path" ]] && [[ ! -e "./$link_path" ]]; then
                log_error "Broken internal link in '$file': '$link'"
            fi
        done < <(grep -oP '\]\(\K[^)]+' "$file" 2>/dev/null || true)
    done < <(find . -name "*.md" -type f -print0 2>/dev/null)
}

# ============================================================================
# Code Block Language Tag Validation
# ============================================================================

validate_code_blocks() {
    log_info "Validating code block language tags..."

    while IFS= read -r -d '' file; do
        local line_num=0
        local in_code_block=false

        while IFS= read -r line; do
            ((line_num++))

            # Check for code block start
            if [[ "$line" =~ ^\`\`\` ]]; then
                if [[ "$in_code_block" == false ]]; then
                    in_code_block=true

                    # Check if language is specified (``` followed by language)
                    local lang="${line#\`\`\`}"
                    lang="${lang%% *}"  # Get first word

                    if [[ -z "$lang" ]]; then
                        log_warning "Code block at $file:$line_num missing language tag"
                    fi
                else
                    in_code_block=false
                fi
            fi
        done < "$file"
    done < <(find . -name "*.md" -type f -print0 2>/dev/null)
}

# ============================================================================
# Main Execution
# ============================================================================

main() {
    echo "=============================================="
    echo "InferaDB Documentation Structure Validation"
    echo "=============================================="
    echo ""

    # Change to docs directory if needed
    if [[ -d "docs" ]]; then
        cd docs
    fi

    validate_file_naming
    echo ""
    validate_directory_structure
    echo ""
    validate_frontmatter
    echo ""
    validate_internal_links
    echo ""
    validate_code_blocks
    echo ""

    echo "=============================================="
    echo "Validation Summary"
    echo "=============================================="
    echo "Errors:   $ERRORS"
    echo "Warnings: $WARNINGS"
    echo ""

    if [[ $ERRORS -gt 0 ]]; then
        echo -e "${RED}Validation FAILED with $ERRORS error(s)${NC}"
        exit 1
    elif [[ $WARNINGS -gt 0 ]]; then
        echo -e "${YELLOW}Validation PASSED with $WARNINGS warning(s)${NC}"
        exit 0
    else
        echo -e "${GREEN}Validation PASSED${NC}"
        exit 0
    fi
}

# Run main function
main "$@"
