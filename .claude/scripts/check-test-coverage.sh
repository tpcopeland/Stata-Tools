#!/bin/bash
#
# check-test-coverage.sh - Report test and validation coverage for packages
#
# Shows which packages have functional tests (test_*.do) and validation tests
# (validation_*.do), highlighting gaps in coverage.
#
# Usage: check-test-coverage.sh [--threshold N]
#        --threshold N : Exit with code 1 if coverage below N percent (default: 0)
#
# Exit codes:
#   0 - Report generated, coverage meets threshold
#   1 - Coverage below threshold
#   3 - Configuration error
#

# Source common library if available
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [[ -f "$SCRIPT_DIR/../lib/common.sh" ]]; then
    source "$SCRIPT_DIR/../lib/common.sh"
    REPO_ROOT=$(get_repo_root)
else
    # Fallback if common.sh not available
    RED='\033[0;31m'
    YELLOW='\033[1;33m'
    GREEN='\033[0;32m'
    BLUE='\033[0;34m'
    NC='\033[0m'
    REPO_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || pwd)
fi

# Parse arguments
THRESHOLD=0
while [[ $# -gt 0 ]]; do
    case "$1" in
        --threshold)
            if [[ -z "$2" ]] || [[ "$2" == -* ]]; then
                echo "Error: --threshold requires a numeric value"
                echo "Usage: $0 [--threshold N]"
                exit 3
            fi
            if ! [[ "$2" =~ ^[0-9]+$ ]]; then
                echo "Error: --threshold value must be a number (0-100)"
                exit 3
            fi
            THRESHOLD="$2"
            shift 2
            ;;
        -h|--help)
            echo "Usage: $0 [--threshold N]"
            echo ""
            echo "Options:"
            echo "  --threshold N  Exit with code 1 if coverage below N percent"
            echo "  -h, --help     Show this help message"
            exit 0
            ;;
        *)
            echo "Unknown argument: $1"
            echo "Usage: $0 [--threshold N]"
            exit 3
            ;;
    esac
done

echo "Test Coverage Report"
echo "===================="
echo ""

# Find all packages (directories with .pkg files, excluding _templates)
PACKAGES=$(find "$REPO_ROOT" -maxdepth 2 -name "*.pkg" ! -path "*/_templates/*" -exec basename -s .pkg {} \; 2>/dev/null | sort)

# Check if any packages found
if [[ -z "$PACKAGES" ]]; then
    echo "No packages found to check"
    exit 3
fi

TOTAL=0
HAS_TEST=0
HAS_VALIDATION=0
MISSING_TEST=()
MISSING_VALIDATION=()

printf "%-20s %-15s %-15s\n" "Package" "Functional" "Validation"
printf "%-20s %-15s %-15s\n" "-------" "----------" "----------"

for pkg in $PACKAGES; do
    TOTAL=$((TOTAL + 1))

    # Check for functional test
    TEST_FILE="$REPO_ROOT/_testing/test_${pkg}.do"
    if [[ -f "$TEST_FILE" ]]; then
        TEST_STATUS="${GREEN}Yes${NC}"
        HAS_TEST=$((HAS_TEST + 1))
    else
        # Also check for comprehensive test files (e.g., test_pkg_comprehensive.do)
        ALT_TEST=$(find "$REPO_ROOT/_testing" -name "test_${pkg}*.do" 2>/dev/null | head -1)
        if [[ -n "$ALT_TEST" ]]; then
            TEST_STATUS="${GREEN}Yes${NC}"
            HAS_TEST=$((HAS_TEST + 1))
        else
            TEST_STATUS="${RED}Missing${NC}"
            MISSING_TEST+=("$pkg")
        fi
    fi

    # Check for validation test
    VAL_FILE="$REPO_ROOT/_validation/validation_${pkg}.do"
    if [[ -f "$VAL_FILE" ]]; then
        VAL_STATUS="${GREEN}Yes${NC}"
        HAS_VALIDATION=$((HAS_VALIDATION + 1))
    else
        # Also check for alternative validation files
        ALT_VAL=$(find "$REPO_ROOT/_validation" -name "validation_${pkg}*.do" 2>/dev/null | head -1)
        if [[ -n "$ALT_VAL" ]]; then
            VAL_STATUS="${GREEN}Yes${NC}"
            HAS_VALIDATION=$((HAS_VALIDATION + 1))
        else
            VAL_STATUS="${YELLOW}Missing${NC}"
            MISSING_VALIDATION+=("$pkg")
        fi
    fi

    printf "%-20s " "$pkg"
    echo -e "$TEST_STATUS\t\t$VAL_STATUS"
done

echo ""
echo "===================="
echo "Summary"
echo "===================="
echo "Total packages: $TOTAL"
echo ""

# Guard against division by zero
if [[ $TOTAL -eq 0 ]]; then
    echo "No packages to analyze"
    exit 3
fi

# Functional test coverage
TEST_PCT=$((HAS_TEST * 100 / TOTAL))
echo -e "Functional tests: ${GREEN}$HAS_TEST${NC}/$TOTAL ($TEST_PCT%)"
if [[ ${#MISSING_TEST[@]} -gt 0 ]]; then
    echo -e "  ${RED}Missing:${NC} ${MISSING_TEST[*]}"
fi

# Validation test coverage
VAL_PCT=$((HAS_VALIDATION * 100 / TOTAL))
echo -e "Validation tests: ${GREEN}$HAS_VALIDATION${NC}/$TOTAL ($VAL_PCT%)"
if [[ ${#MISSING_VALIDATION[@]} -gt 0 ]]; then
    echo -e "  ${YELLOW}Missing:${NC} ${MISSING_VALIDATION[*]}"
fi

echo ""

# Additional stats
echo "Additional Test Files"
echo "---------------------"
TOTAL_TEST_FILES=$(find "$REPO_ROOT/_testing" -name "test_*.do" 2>/dev/null | wc -l | tr -d ' ')
TOTAL_VAL_FILES=$(find "$REPO_ROOT/_validation" -name "validation_*.do" 2>/dev/null | wc -l | tr -d ' ')
echo "Total functional test files: $TOTAL_TEST_FILES"
echo "Total validation test files: $TOTAL_VAL_FILES"

# Show tvtools breakdown if present
if [[ -d "$REPO_ROOT/tvtools" ]]; then
    echo ""
    echo "tvtools Commands"
    echo "----------------"
    TVTOOLS_CMDS=$(grep -l "^program define tv" "$REPO_ROOT/tvtools/"*.ado 2>/dev/null | wc -l | tr -d ' ' || echo "0")
    echo "tvtools commands: $TVTOOLS_CMDS"

    # Check for tvtools-specific tests
    TV_TESTS=$(find "$REPO_ROOT/_testing" -name "test_tv*.do" 2>/dev/null | wc -l | tr -d ' ')
    TV_VALS=$(find "$REPO_ROOT/_validation" -name "validation_tv*.do" 2>/dev/null | wc -l | tr -d ' ')
    echo "tvtools functional tests: $TV_TESTS"
    echo "tvtools validation tests: $TV_VALS"
fi

echo ""

# Check threshold
if [[ $THRESHOLD -gt 0 ]]; then
    if [[ $TEST_PCT -lt $THRESHOLD ]]; then
        echo -e "${RED}FAILED${NC}: Functional test coverage ($TEST_PCT%) below threshold ($THRESHOLD%)"
        exit 1
    fi
fi

exit 0
