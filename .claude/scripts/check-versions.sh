#!/bin/bash
#
# check-versions.sh - Check version consistency across package files
#
# Verifies that version numbers match across .ado, .sthlp, .pkg, and README.md
# Also checks header format compliance.
#
# Usage: check-versions.sh [PACKAGE_NAME]
#        check-versions.sh           # Check all packages
#        check-versions.sh balancetab # Check specific package
#
# Exit codes:
#   0 - All checks passed
#   1 - Inconsistencies found
#

REPO_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || echo "/home/tpcopeland/Stata-Tools")

# Colors
RED='\033[0;31m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

ERRORS=0
WARNINGS=0

error() { echo -e "${RED}[ERROR]${NC} $1"; ERRORS=$((ERRORS + 1)); }
warn() { echo -e "${YELLOW}[WARN]${NC} $1"; WARNINGS=$((WARNINGS + 1)); }
pass() { echo -e "${GREEN}[OK]${NC} $1"; }
info() { echo -e "${BLUE}[INFO]${NC} $1"; }

# Get list of packages to check
if [ -n "$1" ]; then
    PACKAGES="$1"
else
    # Find all packages (directories with .pkg files, excluding _templates)
    PACKAGES=$(find "$REPO_ROOT" -maxdepth 2 -name "*.pkg" ! -path "*/_templates/*" | \
               sed 's|.*/||; s|\.pkg||' | sort)
fi

echo "Version Consistency Check"
echo "========================="
echo ""

for pkg in $PACKAGES; do
    PKG_DIR="$REPO_ROOT/$pkg"

    # Skip if directory doesn't exist
    if [ ! -d "$PKG_DIR" ]; then
        warn "Package directory not found: $pkg"
        continue
    fi

    echo -e "${BLUE}Package: $pkg${NC}"
    echo "---"

    ADO_FILE="$PKG_DIR/$pkg.ado"
    STHLP_FILE="$PKG_DIR/$pkg.sthlp"
    PKG_FILE="$PKG_DIR/$pkg.pkg"
    README_FILE="$PKG_DIR/README.md"

    # Extract versions
    ADO_VERSION=""
    ADO_DATE=""
    STHLP_VERSION=""
    STHLP_DATE=""
    PKG_DATE=""
    README_VERSION=""

    # .ado version (line 1: *! command Version X.Y.Z  YYYY/MM/DD)
    if [ -f "$ADO_FILE" ]; then
        ADO_LINE=$(head -1 "$ADO_FILE")
        ADO_VERSION=$(echo "$ADO_LINE" | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1 || true)
        ADO_DATE=$(echo "$ADO_LINE" | grep -oE '[0-9]{4}/[0-9]{2}/[0-9]{2}' | head -1 || true)

        # Check header format
        if ! echo "$ADO_LINE" | grep -qE '^\*! \w+ Version [0-9]+\.[0-9]+\.[0-9]+'; then
            warn "$pkg.ado: Non-standard header format"
            echo "    Found: $ADO_LINE"
            echo "    Expected: *! $pkg Version X.Y.Z  YYYY/MM/DD"
        fi
    else
        error "$pkg.ado not found"
    fi

    # .sthlp version (line 2: {* *! version X.Y.Z  DDmonYYYY})
    if [ -f "$STHLP_FILE" ]; then
        STHLP_LINE=$(sed -n '2p' "$STHLP_FILE")
        STHLP_VERSION=$(echo "$STHLP_LINE" | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1 || true)
        STHLP_DATE=$(echo "$STHLP_LINE" | grep -oE '[0-9]{1,2}[a-z]{3}[0-9]{4}' | head -1 || true)

        # Check header format (should be DDmonYYYY, not YYYY/MM/DD)
        if echo "$STHLP_LINE" | grep -qE '[0-9]{4}/[0-9]{2}/[0-9]{2}'; then
            warn "$pkg.sthlp: Uses YYYY/MM/DD format instead of DDmonYYYY"
        fi
    else
        error "$pkg.sthlp not found"
    fi

    # .pkg Distribution-Date (YYYYMMDD)
    if [ -f "$PKG_FILE" ]; then
        PKG_DATE=$(grep -E 'Distribution-Date:' "$PKG_FILE" 2>/dev/null | grep -oE '[0-9]{8}' | head -1 || true)

        if [ -z "$PKG_DATE" ] || [ "$PKG_DATE" = "YYYYMMDD" ]; then
            error "$pkg.pkg: Missing or placeholder Distribution-Date"
        fi
    else
        error "$pkg.pkg not found"
    fi

    # README.md version (get first match - most recent in version history)
    if [ -f "$README_FILE" ]; then
        README_VERSION=$(grep -iE 'Version [0-9]+\.[0-9]+\.[0-9]+' "$README_FILE" 2>/dev/null | \
                        grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1 || true)
    else
        warn "$pkg/README.md not found"
    fi

    # Display extracted versions
    echo "  .ado version:    ${ADO_VERSION:-NOT FOUND} (${ADO_DATE:-no date})"
    echo "  .sthlp version:  ${STHLP_VERSION:-NOT FOUND} (${STHLP_DATE:-no date})"
    echo "  .pkg date:       ${PKG_DATE:-NOT FOUND}"
    echo "  README version:  ${README_VERSION:-NOT FOUND}"

    # Compare versions
    if [ -n "$ADO_VERSION" ] && [ -n "$STHLP_VERSION" ]; then
        if [ "$ADO_VERSION" != "$STHLP_VERSION" ]; then
            error "Version mismatch: .ado ($ADO_VERSION) != .sthlp ($STHLP_VERSION)"
        fi
    fi

    if [ -n "$ADO_VERSION" ] && [ -n "$README_VERSION" ]; then
        if [ "$ADO_VERSION" != "$README_VERSION" ]; then
            warn "Version mismatch: .ado ($ADO_VERSION) != README ($README_VERSION)"
        fi
    fi

    # Convert dates and compare (approximate check)
    if [ -n "$ADO_DATE" ] && [ -n "$PKG_DATE" ]; then
        ADO_DATE_NORMALIZED=$(echo "$ADO_DATE" | tr -d '/')
        if [ "$ADO_DATE_NORMALIZED" != "$PKG_DATE" ]; then
            warn "Date mismatch: .ado ($ADO_DATE) != .pkg ($PKG_DATE)"
        fi
    fi

    echo ""
done

# Summary
echo "========================="
echo "Summary"
echo "========================="
echo "Packages checked: $(echo "$PACKAGES" | wc -w)"
echo -e "Errors: ${RED}$ERRORS${NC}"
echo -e "Warnings: ${YELLOW}$WARNINGS${NC}"

if [ $ERRORS -gt 0 ]; then
    echo ""
    echo -e "${RED}FAILED${NC}: Fix errors before release."
    exit 1
elif [ $WARNINGS -gt 0 ]; then
    echo ""
    echo -e "${YELLOW}PASSED WITH WARNINGS${NC}"
    exit 0
else
    echo ""
    echo -e "${GREEN}PASSED${NC}: All versions consistent."
    exit 0
fi
