#!/bin/bash
#
# test_all.sh - Master test runner for .claude infrastructure
# Version: 2.0.0
#
# Runs all test suites and reports overall results.
#
# Usage: bash test_all.sh [-v|--verbose]

set -o pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BOLD='\033[1m'
NC='\033[0m'

VERBOSE=""
[[ "$1" == "-v" || "$1" == "--verbose" ]] && VERBOSE="-v"

echo -e "${BOLD}================================${NC}"
echo -e "${BOLD}Claude Integration Test Suite${NC}"
echo -e "${BOLD}================================${NC}"
echo ""

SUITES_PASSED=0
SUITES_FAILED=0
SUITES=()

run_suite() {
    local name="$1"
    local script="$2"

    echo -e "${BOLD}--- $name ---${NC}"

    if [[ ! -f "$script" ]]; then
        echo -e "  ${RED}SKIP${NC}: $script not found"
        SUITES_FAILED=$((SUITES_FAILED + 1))
        SUITES+=("$name: MISSING")
        echo ""
        return
    fi

    if bash "$script" $VERBOSE; then
        SUITES_PASSED=$((SUITES_PASSED + 1))
        SUITES+=("$name: PASS")
    else
        SUITES_FAILED=$((SUITES_FAILED + 1))
        SUITES+=("$name: FAIL")
    fi
    echo ""
}

# Run all test suites
run_suite "Hook Tests" "$SCRIPT_DIR/test_hooks.sh"
run_suite "Skill Tests" "$SCRIPT_DIR/test_skills.sh"
run_suite "Consistency Tests" "$SCRIPT_DIR/test_consistency.sh"
run_suite "MCP Tests" "$SCRIPT_DIR/test_mcp.sh"
run_suite "Integration Tests" "$SCRIPT_DIR/run-tests.sh"

# Overall summary
echo -e "${BOLD}================================${NC}"
echo -e "${BOLD}Overall Summary${NC}"
echo -e "${BOLD}================================${NC}"
echo ""

for suite in "${SUITES[@]}"; do
    name="${suite%%:*}"
    status="${suite##*: }"
    if [[ "$status" == "PASS" ]]; then
        echo -e "  ${GREEN}PASS${NC}  $name"
    else
        echo -e "  ${RED}$status${NC}  $name"
    fi
done

echo ""
echo -e "Suites passed: ${GREEN}$SUITES_PASSED${NC}"
echo -e "Suites failed: ${RED}$SUITES_FAILED${NC}"
echo ""

if [[ $SUITES_FAILED -gt 0 ]]; then
    echo -e "${RED}SOME SUITES FAILED${NC}"
    exit 1
else
    echo -e "${GREEN}ALL SUITES PASSED${NC}"
    exit 0
fi
