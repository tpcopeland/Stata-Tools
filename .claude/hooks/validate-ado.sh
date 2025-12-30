#!/bin/bash
#
# validate-ado.sh - Validate Stata .ado file syntax and structure
#
# This hook can be used to validate .ado files before committing or after editing.
# It performs static analysis without requiring Stata runtime.
#
# Usage: validate-ado.sh FILE.ado
#
# Exit codes:
#   0 - All checks passed
#   1 - Errors found
#   2 - Warnings found (but no errors)

if [ $# -lt 1 ]; then
    echo "Usage: $0 FILE.ado"
    exit 1
fi

FILE="$1"

if [ ! -f "$FILE" ]; then
    echo "Error: File not found: $FILE"
    exit 1
fi

ERRORS=0
WARNINGS=0

# Colors
RED='\033[0;31m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
NC='\033[0m'

error() { echo -e "${RED}[ERROR]${NC} $1"; ERRORS=$((ERRORS + 1)); }
warn() { echo -e "${YELLOW}[WARN]${NC} $1"; WARNINGS=$((WARNINGS + 1)); }
pass() { echo -e "${GREEN}[OK]${NC} $1"; }

echo "Validating: $FILE"
echo "================================"

# Check 1: Version line
if ! head -1 "$FILE" | grep -q '^\*! .* Version [0-9]\+\.[0-9]\+\.[0-9]\+'; then
    error "Line 1: Missing or malformed version line (expected: *! name Version X.Y.Z  YYYY/MM/DD)"
else
    pass "Version line format"
fi

# Check 2: Program class declaration
if ! grep -q 'program define .*, [rens]class' "$FILE" 2>/dev/null; then
    if grep -q 'program define' "$FILE"; then
        warn "No program class specified (rclass, eclass, sclass, nclass)"
    else
        error "No 'program define' statement found"
    fi
else
    pass "Program class declaration"
fi

# Check 3: Version statement
if ! grep -q '^\s*version 1[678]\.0' "$FILE"; then
    error "Missing 'version 16.0' or 'version 18.0' statement"
else
    pass "Version statement"
fi

# Check 4: varabbrev off
if ! grep -q 'set varabbrev off' "$FILE"; then
    warn "Missing 'set varabbrev off' - recommended for production code"
else
    pass "varabbrev off"
fi

# Check 5: marksample when if/in present
if grep -q 'syntax.*\[if\].*\[in\]' "$FILE"; then
    if ! grep -q 'marksample' "$FILE"; then
        error "Syntax has [if] [in] but no 'marksample' statement"
    else
        pass "marksample present"
    fi
fi

# Check 6: Observation count check after marksample
if grep -q 'marksample' "$FILE"; then
    if ! grep -q 'count if.*touse' "$FILE"; then
        warn "marksample without observation count check"
    else
        pass "Observation count check"
    fi
fi

# Check 7: Long macro names (>31 chars)
LONG_MACROS=$(grep -oE 'local\s+[a-zA-Z_][a-zA-Z0-9_]{30,}' "$FILE" 2>/dev/null || true)
if [ -n "$LONG_MACROS" ]; then
    error "Macro name(s) exceed 31 characters (will be silently truncated):"
    echo "$LONG_MACROS" | while read -r line; do
        echo "    $line"
    done
else
    pass "Macro name lengths"
fi

# Check 8: Tempvar usage without backticks
# This is tricky to detect perfectly, but we can check for common patterns
if grep -q 'tempvar' "$FILE"; then
    # Extract tempvar names and look for usage without backticks
    TEMPVARS=$(grep -oE 'tempvar\s+[a-zA-Z_][a-zA-Z0-9_ ]*' "$FILE" | sed 's/tempvar\s*//' | tr ' ' '\n' | grep -v '^$')
    for tv in $TEMPVARS; do
        # Check if this tempvar name appears without backticks after its declaration
        if grep -E "(gen|replace|by|egen|sort)\s+${tv}\b" "$FILE" | grep -v "\`${tv}'" >/dev/null 2>&1; then
            warn "Possible tempvar '$tv' used without backticks"
        fi
    done
fi

# Check 9: Capture without _rc check
UNCHECKED_CAPTURE=$(grep -n 'capture ' "$FILE" | grep -v 'capture noisily' | while read -r line; do
    LINE_NUM=$(echo "$line" | cut -d: -f1)
    NEXT_LINE=$((LINE_NUM + 1))
    if ! sed -n "${NEXT_LINE}p" "$FILE" | grep -q '_rc'; then
        # Check line after that
        NEXT_NEXT=$((LINE_NUM + 2))
        if ! sed -n "${NEXT_NEXT}p" "$FILE" | grep -q '_rc'; then
            echo "$line"
        fi
    fi
done)

if [ -n "$UNCHECKED_CAPTURE" ]; then
    warn "Possible capture without _rc check:"
    echo "$UNCHECKED_CAPTURE" | head -3
fi

# Check 10: Return statements match program class
PROG_CLASS=$(grep -oE 'program define .*, [rens]class' "$FILE" | grep -oE '[rens]class' | head -1)
if [ "$PROG_CLASS" = "rclass" ]; then
    if grep -q 'ereturn ' "$FILE"; then
        error "rclass program uses ereturn (should use return)"
    fi
fi
if [ "$PROG_CLASS" = "eclass" ]; then
    if grep 'return ' "$FILE" | grep -v 'ereturn\|restore' >/dev/null 2>&1; then
        warn "eclass program may be using return instead of ereturn"
    fi
fi

# Summary
echo ""
echo "================================"
if [ $ERRORS -gt 0 ]; then
    echo -e "${RED}FAILED${NC}: $ERRORS error(s), $WARNINGS warning(s)"
    exit 1
elif [ $WARNINGS -gt 0 ]; then
    echo -e "${YELLOW}PASSED WITH WARNINGS${NC}: $WARNINGS warning(s)"
    exit 2
else
    echo -e "${GREEN}PASSED${NC}: All checks passed"
    exit 0
fi
