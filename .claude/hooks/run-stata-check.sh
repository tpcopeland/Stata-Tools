#!/bin/bash
#
# run-stata-check.sh - Run Stata syntax check on .ado file
#
# This hook requires Stata to be installed and available as 'stata-mp'.
# It compiles the .ado file to check for syntax errors.
#
# Usage: run-stata-check.sh FILE.ado
#
# Environment:
#   STATA_EXEC - Path to Stata executable (default: stata-mp)
#
# Exit codes:
#   0 - Syntax valid
#   1 - Syntax errors found
#   2 - Stata not available

set -e

STATA_EXEC="${STATA_EXEC:-stata-mp}"

if [ $# -lt 1 ]; then
    echo "Usage: $0 FILE.ado"
    exit 1
fi

FILE="$1"
BASENAME=$(basename "$FILE" .ado)
DIRPATH=$(dirname "$FILE")

if [ ! -f "$FILE" ]; then
    echo "Error: File not found: $FILE"
    exit 1
fi

# Check if Stata is available
if ! command -v "$STATA_EXEC" &> /dev/null; then
    echo "Warning: Stata not found ($STATA_EXEC). Skipping syntax check."
    echo "Set STATA_EXEC environment variable to Stata path."
    exit 2
fi

echo "Running Stata syntax check on: $FILE"
echo "================================"

# Create temporary do file for syntax check
TEMP_DO=$(mktemp /tmp/stata_check_XXXXXX.do)
TEMP_LOG=$(mktemp /tmp/stata_check_XXXXXX.log)

cat > "$TEMP_DO" << EOF
* Syntax check for $FILE
version 18.0
set more off
set varabbrev off

* Attempt to run the program definition to check syntax
capture noisily run "$FILE"
if _rc != 0 {
    display as error "Syntax error in $FILE"
    exit _rc
}

* Try to describe the program
capture noisily program list $BASENAME
if _rc == 0 {
    display as result "Program $BASENAME compiled successfully"
}
else {
    display as error "Program $BASENAME not found after compilation"
    exit 111
}

display as result "Syntax check passed"
exit 0
EOF

# Run Stata in batch mode
"$STATA_EXEC" -b do "$TEMP_DO" 2>&1 | tee "$TEMP_LOG"

# Check for errors in log
if grep -q "^r([0-9]\+);$" "$TEMP_LOG"; then
    ERROR_CODE=$(grep -oE "^r\([0-9]+\);" "$TEMP_LOG" | head -1 | grep -oE "[0-9]+")
    echo ""
    echo "================================"
    echo "FAILED: Stata returned error $ERROR_CODE"
    rm -f "$TEMP_DO" "$TEMP_LOG"
    exit 1
fi

if grep -q "Syntax check passed" "$TEMP_LOG"; then
    echo ""
    echo "================================"
    echo "PASSED: Stata syntax check successful"
    rm -f "$TEMP_DO" "$TEMP_LOG"
    exit 0
else
    echo ""
    echo "================================"
    echo "WARNING: Could not verify syntax check result"
    rm -f "$TEMP_DO" "$TEMP_LOG"
    exit 2
fi
