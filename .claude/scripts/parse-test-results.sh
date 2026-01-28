#!/bin/bash
# .claude/scripts/parse-test-results.sh
# Parse Stata test log files and report results
#
# Usage: parse-test-results.sh <logfile> [--json]

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

usage() {
    echo "Usage: $(basename "$0") <logfile> [--json]"
    echo ""
    echo "Parse Stata test log file and report results."
    echo ""
    echo "Options:"
    echo "  --json    Output in JSON format"
    echo ""
    echo "Examples:"
    echo "  $(basename "$0") test_mycommand.log"
    echo "  $(basename "$0") test_mycommand.log --json"
}

# Parse arguments
if [[ $# -lt 1 ]]; then
    usage
    exit 1
fi

LOG_FILE="$1"
JSON_OUTPUT=false

if [[ "$2" == "--json" ]]; then
    JSON_OUTPUT=true
fi

if [[ ! -f "$LOG_FILE" ]]; then
    echo "Error: File not found: $LOG_FILE" >&2
    exit 1
fi

# Count results - use grep with wc for cleaner output
PASSED=$(grep -E "PASS|PASSED" "$LOG_FILE" 2>/dev/null | wc -l | tr -d ' ')
FAILED=$(grep -E "FAIL|FAILED" "$LOG_FILE" 2>/dev/null | wc -l | tr -d ' ')
ERRORS=$(grep -E "^r\([0-9]+\)" "$LOG_FILE" 2>/dev/null | wc -l | tr -d ' ')

# Ensure numeric values
PASSED=${PASSED:-0}
FAILED=${FAILED:-0}
ERRORS=${ERRORS:-0}

# Check for success message
if grep -q "ALL TESTS PASSED\|ALL VALIDATIONS PASSED" "$LOG_FILE" 2>/dev/null; then
    STATUS="success"
else
    if [[ "$FAILED" -gt 0 ]] || [[ "$ERRORS" -gt 0 ]]; then
        STATUS="failed"
    else
        STATUS="unknown"
    fi
fi

# Extract error details
ERROR_DETAILS=""
if [[ "$ERRORS" -gt 0 ]]; then
    ERROR_DETAILS=$(grep -B5 "^r([0-9]" "$LOG_FILE" 2>/dev/null | tail -20)
fi

# Extract failure details
FAILURE_DETAILS=""
if [[ "$FAILED" -gt 0 ]]; then
    FAILURE_DETAILS=$(grep -E "FAIL|FAILED" "$LOG_FILE" 2>/dev/null | head -10)
fi

# Output results
if $JSON_OUTPUT; then
    # JSON output
    cat << EOF
{
    "file": "$LOG_FILE",
    "status": "$STATUS",
    "passed": $PASSED,
    "failed": $FAILED,
    "errors": $ERRORS
}
EOF
else
    # Human-readable output
    echo ""
    echo "=== Test Results: $(basename "$LOG_FILE") ==="
    echo ""

    if [[ "$STATUS" == "success" ]]; then
        echo -e "${GREEN}Status: PASSED${NC}"
    elif [[ "$STATUS" == "failed" ]]; then
        echo -e "${RED}Status: FAILED${NC}"
    else
        echo -e "${YELLOW}Status: UNKNOWN${NC}"
    fi

    echo ""
    echo "Passed:  $PASSED"
    echo "Failed:  $FAILED"
    echo "Errors:  $ERRORS"

    if [[ "$FAILED" -gt 0 ]] && [[ -n "$FAILURE_DETAILS" ]]; then
        echo ""
        echo "=== Failures ==="
        echo "$FAILURE_DETAILS"
    fi

    if [[ "$ERRORS" -gt 0 ]] && [[ -n "$ERROR_DETAILS" ]]; then
        echo ""
        echo "=== Error Context ==="
        echo "$ERROR_DETAILS"
    fi

    echo ""
fi

# Exit with appropriate code
if [[ "$STATUS" == "success" ]]; then
    exit 0
else
    exit 1
fi
