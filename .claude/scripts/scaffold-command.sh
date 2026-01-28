#!/bin/bash
#
# scaffold-command.sh - Create a new Stata command package from templates
# Version: 1.1.0
#
# Usage: scaffold-command.sh [-h|--help] COMMAND_NAME "Brief description" [AUTHOR]
#
# Examples:
#   ./scaffold-command.sh mycommand "Process time-varying data"
#   ./scaffold-command.sh mycommand "Process time-varying data" "John Smith"
#
# This script:
#   1. Creates the package directory
#   2. Copies all templates from _devkit/_templates/
#   3. Replaces TEMPLATE placeholders with command name
#   4. Updates dates to current date
#   5. Creates test and validation files
#   6. Creates stata.toc file
#
# Exit codes:
#   0 - Success
#   1 - Error (invalid args, package exists, template missing)
#   3 - Configuration error
#

set -o pipefail

# Source common library (required)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [[ ! -f "$SCRIPT_DIR/../lib/common.sh" ]]; then
    echo "[ERROR] common.sh not found. Run from repository root." >&2
    exit 3
fi
source "$SCRIPT_DIR/../lib/common.sh"

# Source config if available
if [[ -f "$SCRIPT_DIR/../lib/config.sh" ]]; then
    source "$SCRIPT_DIR/../lib/config.sh"
else
    readonly REPO_ROOT="$(get_repo_root)"
    readonly TEMPLATES_DIR="${REPO_ROOT}/_devkit/_templates"
    readonly TESTING_DIR="${REPO_ROOT}/_devkit/_testing"
    readonly VALIDATION_DIR="${REPO_ROOT}/_devkit/_validation"
    readonly DEFAULT_AUTHOR="${DEFAULT_AUTHOR:-Timothy P Copeland}"
fi

# Help function
show_help() {
    echo "Usage: $0 [-h|--help] COMMAND_NAME \"Brief description\" [AUTHOR]"
    echo ""
    echo "Create a new Stata command package from templates."
    echo ""
    echo "Arguments:"
    echo "  COMMAND_NAME    Name of the new command (lowercase, letters/numbers/underscores)"
    echo "  DESCRIPTION     Brief description of the command"
    echo "  AUTHOR          Author name (optional, default: $DEFAULT_AUTHOR)"
    echo ""
    echo "Options:"
    echo "  -h, --help      Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0 mycommand \"Process time-varying data\""
    echo "  $0 mycommand \"Process data\" \"John Smith\""
}

# Check for help flag
case "${1:-}" in
    -h|--help)
        show_help
        exit 0
        ;;
esac

# Check arguments
if [[ $# -lt 2 ]]; then
    echo "Usage: $0 COMMAND_NAME \"Brief description\" [AUTHOR]"
    echo ""
    echo "Examples:"
    echo "  $0 mycommand \"Process time-varying data\""
    echo "  $0 mycommand \"Process time-varying data\" \"John Smith\""
    exit 1
fi

COMMAND_NAME="$1"
DESCRIPTION="$2"
AUTHOR="${3:-$DEFAULT_AUTHOR}"

# Validate command name (lowercase, letters/numbers/underscores only)
if [[ ! "$COMMAND_NAME" =~ ^[a-z][a-z0-9_]*$ ]]; then
    error "Command name must start with lowercase letter and contain only lowercase letters, numbers, and underscores"
fi

# Check if templates directory exists
if [[ ! -d "$TEMPLATES_DIR" ]]; then
    error "Templates directory not found: ${TEMPLATES_DIR}"
fi

# Check if package already exists
PACKAGE_DIR="${REPO_ROOT}/${COMMAND_NAME}"
if [[ -d "$PACKAGE_DIR" ]]; then
    error "Package directory already exists: ${PACKAGE_DIR}"
fi

# Get current date in various formats
DATE_ADO=$(date +"%Y/%m/%d")        # 2025/01/15
# For STHLP: DDmonYYYY format (e.g., 15jan2025) - portable version without GNU %-d
DATE_STHLP=$(date +"%d%b%Y" | sed 's/^0//' | tr '[:upper:]' '[:lower:]')
DATE_PKG=$(date +"%Y%m%d")          # 20250115
DATE_README=$(date +"%Y-%m-%d")     # 2025-01-15

info "Creating package: ${COMMAND_NAME}"
info "Description: ${DESCRIPTION}"
info "Author: ${AUTHOR}"

# Create package directory
mkdir -p "$PACKAGE_DIR" || error "Failed to create directory: ${PACKAGE_DIR}"
info "Created directory: ${PACKAGE_DIR}"

# Copy and transform .ado file
if [[ -f "${TEMPLATES_DIR}/TEMPLATE.ado" ]]; then
    info "Creating ${COMMAND_NAME}.ado..."
    sed -e "s|TEMPLATE|${COMMAND_NAME}|g" \
        -e "s|YYYY/MM/DD|${DATE_ADO}|g" \
        -e "s|Brief description of what the command does|${DESCRIPTION}|g" \
        -e "s|Your Name|${AUTHOR}|g" \
        "${TEMPLATES_DIR}/TEMPLATE.ado" > "${PACKAGE_DIR}/${COMMAND_NAME}.ado"
else
    warn "Template TEMPLATE.ado not found, skipping"
fi

# Copy and transform .sthlp file
if [[ -f "${TEMPLATES_DIR}/TEMPLATE.sthlp" ]]; then
    info "Creating ${COMMAND_NAME}.sthlp..."
    sed -e "s|TEMPLATE|${COMMAND_NAME}|g" \
        -e "s|DDmonYYYY|${DATE_STHLP}|g" \
        -e "s|Brief description|${DESCRIPTION}|g" \
        -e "s|Your Name|${AUTHOR}|g" \
        -e "s|Department/Institution|Department|g" \
        -e "s|Affiliation|Institution|g" \
        -e "s|your@email.com|email@example.com|g" \
        -e "s|YYYY-MM-DD|${DATE_README}|g" \
        "${TEMPLATES_DIR}/TEMPLATE.sthlp" > "${PACKAGE_DIR}/${COMMAND_NAME}.sthlp"
else
    warn "Template TEMPLATE.sthlp not found, skipping"
fi

# Copy and transform .pkg file
if [[ -f "${TEMPLATES_DIR}/TEMPLATE.pkg" ]]; then
    info "Creating ${COMMAND_NAME}.pkg..."
    COMMAND_UPPER=$(echo "$COMMAND_NAME" | tr '[:lower:]' '[:upper:]')
    sed -e "s|TEMPLATE|${COMMAND_UPPER}|g" \
        -e "s|Brief description of what the package does|${DESCRIPTION}|g" \
        -e "s|YYYYMMDD|${DATE_PKG}|g" \
        -e "s|Your Name|${AUTHOR}|g" \
        -e "s|Department/Institution||g" \
        -e "s|Email: your@email.com||g" \
        "${TEMPLATES_DIR}/TEMPLATE.pkg" > "${PACKAGE_DIR}/${COMMAND_NAME}.pkg"

    # Fix the .pkg file for correct filename references
    sed_inplace "s|${COMMAND_UPPER}\.ado|${COMMAND_NAME}.ado|g" "${PACKAGE_DIR}/${COMMAND_NAME}.pkg"
    sed_inplace "s|${COMMAND_UPPER}\.sthlp|${COMMAND_NAME}.sthlp|g" "${PACKAGE_DIR}/${COMMAND_NAME}.pkg"
    sed_inplace "s|${COMMAND_UPPER}\.dlg|${COMMAND_NAME}.dlg|g" "${PACKAGE_DIR}/${COMMAND_NAME}.pkg"
else
    warn "Template TEMPLATE.pkg not found, skipping"
fi

# Copy and transform .dlg file
if [[ -f "${TEMPLATES_DIR}/TEMPLATE.dlg" ]]; then
    info "Creating ${COMMAND_NAME}.dlg..."
    sed -e "s|TEMPLATE|${COMMAND_NAME}|g" \
        -e "s|Brief description|${DESCRIPTION}|g" \
        "${TEMPLATES_DIR}/TEMPLATE.dlg" > "${PACKAGE_DIR}/${COMMAND_NAME}.dlg"
else
    warn "Template TEMPLATE.dlg not found, skipping"
fi

# Copy and transform README.md
if [[ -f "${TEMPLATES_DIR}/TEMPLATE_README.md" ]]; then
    info "Creating README.md..."
    sed -e "s|TEMPLATE|${COMMAND_NAME}|g" \
        -e "s|Brief one-line description of what the command does\.|${DESCRIPTION}|g" \
        -e "s|DD Month YYYY|$(date +"%d %B %Y")|g" \
        "${TEMPLATES_DIR}/TEMPLATE_README.md" > "${PACKAGE_DIR}/README.md"
else
    warn "Template TEMPLATE_README.md not found, skipping"
fi

# Create stata.toc file
info "Creating stata.toc..."
cat > "${PACKAGE_DIR}/stata.toc" << EOF
v 3
d Stata-Tools: ${COMMAND_NAME}
d ${AUTHOR}
d https://github.com/tpcopeland/Stata-Tools
p ${COMMAND_NAME}
EOF

# Create test file in _devkit/_testing/
if [[ -f "${TEMPLATES_DIR}/testing_TEMPLATE.do" ]]; then
    info "Creating test file..."
    mkdir -p "$TESTING_DIR"
    sed -e "s|TEMPLATE|${COMMAND_NAME}|g" \
        -e "s|YYYY-MM-DD|${DATE_README}|g" \
        -e "s|Your Name|${AUTHOR}|g" \
        "${TEMPLATES_DIR}/testing_TEMPLATE.do" > "${TESTING_DIR}/test_${COMMAND_NAME}.do"
else
    warn "Template testing_TEMPLATE.do not found, skipping"
fi

# Create validation file in _devkit/_validation/
if [[ -f "${TEMPLATES_DIR}/validation_TEMPLATE.do" ]]; then
    info "Creating validation file..."
    mkdir -p "$VALIDATION_DIR"
    sed -e "s|TEMPLATE|${COMMAND_NAME}|g" \
        -e "s|YYYY-MM-DD|${DATE_README}|g" \
        -e "s|Your Name|${AUTHOR}|g" \
        "${TEMPLATES_DIR}/validation_TEMPLATE.do" > "${VALIDATION_DIR}/validation_${COMMAND_NAME}.do"
else
    warn "Template validation_TEMPLATE.do not found, skipping"
fi

# Summary
echo ""
info "Package created successfully!"
echo ""
echo "Files created:"
echo "  ${PACKAGE_DIR}/"
echo "  ├── ${COMMAND_NAME}.ado"
echo "  ├── ${COMMAND_NAME}.sthlp"
echo "  ├── ${COMMAND_NAME}.pkg"
echo "  ├── ${COMMAND_NAME}.dlg"
echo "  ├── stata.toc"
echo "  └── README.md"
echo ""
echo "  ${TESTING_DIR}/test_${COMMAND_NAME}.do"
echo "  ${VALIDATION_DIR}/validation_${COMMAND_NAME}.do"
echo ""
echo "Next steps:"
echo "  1. Edit ${COMMAND_NAME}.ado to implement your command logic"
echo "  2. Update ${COMMAND_NAME}.sthlp with accurate option descriptions"
echo "  3. Customize test_${COMMAND_NAME}.do with actual test cases"
echo "  4. Create validation_${COMMAND_NAME}.do with known-answer tests"
echo "  5. Run tests on VM with Stata: stata-mp -b do _devkit/_testing/test_${COMMAND_NAME}.do"
echo "  6. Add package to root README.md table"
echo ""
echo "Ask Claude for help with natural language:"
echo "  'help me implement this command'  - Development guidance"
echo "  'write tests for ${COMMAND_NAME}'       - Testing guidance"
echo "  'validate the command output'     - Validation guidance"
echo "  'review the ado file'             - Code review"
