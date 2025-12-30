#!/bin/bash
#
# validate-ado.sh - Validate Stata .ado file syntax and structure
#
# This hook performs static analysis without requiring Stata runtime.
# It checks for common errors and best practices.
#
# Usage: validate-ado.sh FILE.ado
#
# Exit codes:
#   0 - All checks passed
#   1 - Errors found
#   2 - Warnings found (but no errors)
#   3 - Configuration error
#

# Source common library if available
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [[ -f "$SCRIPT_DIR/../lib/common.sh" ]]; then
    source "$SCRIPT_DIR/../lib/common.sh"
else
    # Fallback if common.sh not available
    RED='\033[0;31m'
    YELLOW='\033[1;33m'
    GREEN='\033[0;32m'
    NC='\033[0m'
    error() { echo -e "${RED}[ERROR]${NC} $1"; ERRORS=$((ERRORS + 1)); }
    warn() { echo -e "${YELLOW}[WARN]${NC} $1"; WARNINGS=$((WARNINGS + 1)); }
    pass() { echo -e "${GREEN}[OK]${NC} $1"; }
fi

# Initialize counters
ERRORS=0
WARNINGS=0

# Validate arguments
if [[ $# -lt 1 ]]; then
    echo "Usage: $0 FILE.ado"
    exit 3
fi

FILE="$1"

if [[ ! -f "$FILE" ]]; then
    echo "Error: File not found: $FILE"
    exit 3
fi

echo "Validating: $FILE"
echo "================================"

# =============================================================================
# Check 1: Version line format
# Expected: *! command Version X.Y.Z  YYYY/MM/DD
# =============================================================================
FIRST_LINE=$(head -1 "$FILE")
if ! echo "$FIRST_LINE" | grep -qE '^\*! .* Version [0-9]+\.[0-9]+\.[0-9]+'; then
    error "Line 1: Missing or malformed version line"
    echo "    Found: $FIRST_LINE"
    echo "    Expected: *! name Version X.Y.Z  YYYY/MM/DD"
else
    # Also check for proper semantic version (X.Y.Z not X.Y)
    if echo "$FIRST_LINE" | grep -qE 'Version [0-9]+\.[0-9]+[^.0-9]'; then
        warn "Version should use X.Y.Z format (semantic versioning)"
    else
        pass "Version line format"
    fi
fi

# =============================================================================
# Check 2: Program class declaration
# Expected: program define name, rclass|eclass|sclass|nclass
# More flexible regex that handles varying whitespace
# =============================================================================
if grep -qE 'program\s+(define\s+)?\w+\s*,\s*[rens]class' "$FILE" 2>/dev/null; then
    pass "Program class declaration"
else
    if grep -qE 'program\s+(define\s+)?\w+' "$FILE" 2>/dev/null; then
        warn "No program class specified (rclass, eclass, sclass, nclass)"
    else
        error "No 'program define' statement found"
    fi
fi

# =============================================================================
# Check 3: Version statement
# Should have: version 16.0, version 17.0, or version 18.0
# =============================================================================
if grep -qE '^\s*version\s+1[678]\.0' "$FILE" 2>/dev/null; then
    pass "Version statement"
else
    error "Missing 'version 16.0', 'version 17.0', or 'version 18.0' statement"
fi

# =============================================================================
# Check 4: varabbrev off
# Recommended for production code
# =============================================================================
if grep -q 'set varabbrev off' "$FILE" 2>/dev/null; then
    pass "varabbrev off"
else
    warn "Missing 'set varabbrev off' - recommended for production code"
fi

# =============================================================================
# Check 5: marksample when if/in present
# If syntax has [if] [in], must have marksample
# =============================================================================
if grep -qE 'syntax.*\[if\].*\[in\]' "$FILE" 2>/dev/null; then
    if grep -q 'marksample' "$FILE" 2>/dev/null; then
        pass "marksample present"
    else
        error "Syntax has [if] [in] but no 'marksample' statement"
    fi
fi

# =============================================================================
# Check 6: Observation count check after marksample
# Should verify observations exist after marking sample
# =============================================================================
if grep -q 'marksample' "$FILE" 2>/dev/null; then
    if grep -qE 'count\s+if.*touse' "$FILE" 2>/dev/null; then
        pass "Observation count check"
    else
        warn "marksample without observation count check"
    fi
fi

# =============================================================================
# Check 7: Long macro names (>31 chars)
# Stata silently truncates macro names longer than 31 characters
# Using 32+ char detection (31 chars after the first char = 32 total)
# =============================================================================
LONG_MACROS=$(grep -oE '(local|global|tempvar|tempname)\s+[a-zA-Z_][a-zA-Z0-9_]{31,}' "$FILE" 2>/dev/null || true)
if [[ -n "$LONG_MACROS" ]]; then
    error "Macro name(s) exceed 31 characters (will be silently truncated):"
    echo "$LONG_MACROS" | while read -r line; do
        MACRO_NAME=$(echo "$line" | sed 's/^[a-z]*\s*//')
        echo "    $MACRO_NAME (${#MACRO_NAME} chars)"
    done
else
    pass "Macro name lengths"
fi

# =============================================================================
# Check 8: Tempvar usage without backticks
# Tempvars must be referenced with backticks: `tempvarname'
# =============================================================================
if grep -q 'tempvar' "$FILE" 2>/dev/null; then
    # Extract tempvar names
    TEMPVARS=$(grep -oE 'tempvar\s+[a-zA-Z_][a-zA-Z0-9_ ]*' "$FILE" 2>/dev/null | \
               sed 's/tempvar\s*//' | tr ' ' '\n' | grep -v '^$' | sort -u)

    TEMPVAR_ISSUES=0
    for tv in $TEMPVARS; do
        # Look for usage patterns that suggest missing backticks
        # Check common commands where tempvars might be used incorrectly
        if grep -E "(gen|replace|egen|by|sort|sum|tab|reg|list)\s+${tv}\b" "$FILE" 2>/dev/null | \
           grep -v "\`${tv}'" >/dev/null 2>&1; then
            if [[ $TEMPVAR_ISSUES -eq 0 ]]; then
                warn "Possible tempvar(s) used without backticks:"
            fi
            echo "    $tv"
            TEMPVAR_ISSUES=$((TEMPVAR_ISSUES + 1))
        fi
    done

    if [[ $TEMPVAR_ISSUES -eq 0 ]] && [[ -n "$TEMPVARS" ]]; then
        pass "Tempvar backtick usage"
    fi
fi

# =============================================================================
# Check 9: Capture without _rc check
# capture should be followed by checking _rc within next few lines
# =============================================================================
CAPTURE_LINES=$(grep -n 'capture\s' "$FILE" 2>/dev/null | grep -v 'capture noisily' | cut -d: -f1)
UNCHECKED=0

for LINE_NUM in $CAPTURE_LINES; do
    # Check next 3 lines for _rc
    FOUND_RC=0
    for offset in 1 2 3; do
        CHECK_LINE=$((LINE_NUM + offset))
        if sed -n "${CHECK_LINE}p" "$FILE" 2>/dev/null | grep -q '_rc'; then
            FOUND_RC=1
            break
        fi
    done

    if [[ $FOUND_RC -eq 0 ]]; then
        UNCHECKED=$((UNCHECKED + 1))
        if [[ $UNCHECKED -eq 1 ]]; then
            warn "Possible capture without _rc check:"
        fi
        if [[ $UNCHECKED -le 3 ]]; then
            CAPTURE_LINE=$(sed -n "${LINE_NUM}p" "$FILE" | head -c 60)
            echo "    Line $LINE_NUM: $CAPTURE_LINE"
        fi
    fi
done

if [[ $UNCHECKED -gt 3 ]]; then
    echo "    ... and $((UNCHECKED - 3)) more"
fi

# =============================================================================
# Check 10: Return statements match program class
# rclass should use return, not ereturn
# eclass should use ereturn, not return
# =============================================================================
# Extract program class with flexible matching
PROG_CLASS=$(grep -oE 'program\s+(define\s+)?\w+\s*,\s*[rens]class' "$FILE" 2>/dev/null | \
             grep -oE '[rens]class' | head -1)

if [[ "$PROG_CLASS" == "rclass" ]]; then
    # rclass should not use ereturn (use word boundary)
    if grep -qE '\bereturn\s+(scalar|local|matrix|post)\b' "$FILE" 2>/dev/null; then
        error "rclass program uses ereturn (should use return)"
    else
        pass "Return statement type (rclass)"
    fi
fi

if [[ "$PROG_CLASS" == "eclass" ]]; then
    # eclass should primarily use ereturn
    # Check for return without e prefix (but exclude restore, preserve patterns)
    if grep -E '\breturn\s+(scalar|local|matrix)\b' "$FILE" 2>/dev/null | \
       grep -v 'ereturn' >/dev/null 2>&1; then
        warn "eclass program may be using return instead of ereturn"
    else
        pass "Return statement type (eclass)"
    fi
fi

# =============================================================================
# Check 11: Global macro usage (usually problematic)
# Globals can cause namespace pollution and side effects
# =============================================================================
GLOBAL_COUNT=$(grep -cE '^\s*global\s+[a-zA-Z_]' "$FILE" 2>/dev/null || echo 0)
if [[ $GLOBAL_COUNT -gt 0 ]]; then
    warn "Uses $GLOBAL_COUNT global macro(s) - consider using locals instead"
fi

# =============================================================================
# Check 12: Hardcoded paths
# Paths should not be hardcoded in production code
# =============================================================================
if grep -qE '(C:\\|/Users/|/home/[a-z]|/tmp/)' "$FILE" 2>/dev/null; then
    warn "Possible hardcoded path detected"
fi

# =============================================================================
# Summary
# =============================================================================
echo ""
echo "================================"
if [[ $ERRORS -gt 0 ]]; then
    echo -e "${RED}FAILED${NC}: $ERRORS error(s), $WARNINGS warning(s)"
    exit 1
elif [[ $WARNINGS -gt 0 ]]; then
    echo -e "${YELLOW}PASSED WITH WARNINGS${NC}: $WARNINGS warning(s)"
    exit 2
else
    echo -e "${GREEN}PASSED${NC}: All checks passed"
    exit 0
fi
