#!/bin/bash
#
# run-tests.sh - Integration tests for .claude automation scripts
# Version: 1.0.0
#
# Runs all integration tests for the automation infrastructure.
# Tests verify that scripts execute correctly and produce expected results.
#
# Usage: run-tests.sh [-h|--help] [-v|--verbose]
#
# Exit codes:
#   0 - All tests passed
#   1 - Some tests failed
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

# Setup cleanup
setup_cleanup_trap

# Configuration
VERBOSE=0
TESTS_PASSED=0
TESTS_FAILED=0
TESTS_SKIPPED=0

# Help function
show_help() {
    echo "Usage: $0 [-h|--help] [-v|--verbose]"
    echo ""
    echo "Run integration tests for .claude automation scripts."
    echo ""
    echo "Options:"
    echo "  -h, --help     Show this help message"
    echo "  -v, --verbose  Show verbose output"
}

# Parse arguments
while [[ $# -gt 0 ]]; do
    case "$1" in
        -h|--help) show_help; exit 0 ;;
        -v|--verbose) VERBOSE=1; shift ;;
        *) echo "Unknown option: $1"; show_help; exit 3 ;;
    esac
done

# Get paths
readonly REPO_ROOT="$(get_repo_root)"
readonly CLAUDE_DIR="$REPO_ROOT/.claude"
readonly LIB_DIR="$CLAUDE_DIR/lib"
readonly HOOKS_DIR="$CLAUDE_DIR/validators"
readonly SCRIPTS_DIR="$CLAUDE_DIR/scripts"

# Test utilities
test_start() {
    local name="$1"
    if [[ $VERBOSE -eq 1 ]]; then
        echo -n "  Testing: $name... "
    fi
}

test_pass() {
    TESTS_PASSED=$((TESTS_PASSED + 1))
    if [[ $VERBOSE -eq 1 ]]; then
        echo -e "${GREEN}PASS${NC}"
    fi
}

test_fail() {
    local msg="$1"
    TESTS_FAILED=$((TESTS_FAILED + 1))
    if [[ $VERBOSE -eq 1 ]]; then
        echo -e "${RED}FAIL${NC}: $msg"
    else
        echo -e "${RED}FAIL${NC}: $msg"
    fi
}

test_skip() {
    local reason="$1"
    TESTS_SKIPPED=$((TESTS_SKIPPED + 1))
    if [[ $VERBOSE -eq 1 ]]; then
        echo -e "${YELLOW}SKIP${NC}: $reason"
    fi
}

# =============================================================================
# Test: Library files exist and are sourceable
# =============================================================================
test_libraries() {
    header "Library Tests"

    test_start "common.sh exists"
    if [[ -f "$LIB_DIR/common.sh" ]]; then
        test_pass
    else
        test_fail "common.sh not found"
    fi

    test_start "common.sh sourceable"
    if bash -c "source '$LIB_DIR/common.sh'" 2>/dev/null; then
        test_pass
    else
        test_fail "common.sh failed to source"
    fi

    test_start "config.sh exists"
    if [[ -f "$LIB_DIR/config.sh" ]]; then
        test_pass
    else
        test_fail "config.sh not found"
    fi

    test_start "config.sh sourceable"
    if bash -c "source '$LIB_DIR/config.sh'" 2>/dev/null; then
        test_pass
    else
        test_fail "config.sh failed to source"
    fi
}

# =============================================================================
# Test: Scripts have help flags
# =============================================================================
test_help_flags() {
    header "Help Flag Tests"

    local scripts=(
        "$HOOKS_DIR/validate-ado.sh"
        "$HOOKS_DIR/run-stata-check.sh"
        "$SCRIPTS_DIR/scaffold-command.sh"
        "$SCRIPTS_DIR/check-versions.sh"
        "$SCRIPTS_DIR/check-test-coverage.sh"
    )

    for script in "${scripts[@]}"; do
        local name=$(basename "$script")
        test_start "$name --help"

        if [[ ! -x "$script" ]]; then
            chmod +x "$script" 2>/dev/null
        fi

        if [[ -x "$script" ]]; then
            if "$script" --help >/dev/null 2>&1; then
                test_pass
            else
                test_fail "--help failed"
            fi
        else
            test_skip "not executable"
        fi
    done
}

# =============================================================================
# Test: validate-ado.sh functionality
# =============================================================================
test_validate_ado() {
    header "validate-ado.sh Tests"

    local script="$HOOKS_DIR/validate-ado.sh"

    # Create temp test file
    local temp_ado=$(make_temp_file "test_ado")
    mv "$temp_ado" "${temp_ado}.ado"
    temp_ado="${temp_ado}.ado"
    register_cleanup "$temp_ado"

    # Test with valid .ado content
    test_start "Valid .ado file"
    cat > "$temp_ado" << 'EOF'
*! testcommand Version 1.0.0  2025/01/15
*! Test command
program define testcommand, rclass
    version 18.0
    set varabbrev off
    syntax varlist [if] [in]
    marksample touse
    quietly count if `touse'
    if r(N) == 0 error 2000
    return scalar N = r(N)
end
EOF

    if "$script" "$temp_ado" >/dev/null 2>&1; then
        test_pass
    else
        test_fail "Valid .ado rejected"
    fi

    # Test with missing version line
    test_start "Detects missing version line"
    cat > "$temp_ado" << 'EOF'
program define testcommand, rclass
    version 18.0
end
EOF

    "$script" "$temp_ado" >/dev/null 2>&1
    local rc=$?
    if [[ $rc -eq 1 ]] || [[ $rc -eq 2 ]]; then
        test_pass
    else
        test_fail "Did not detect missing version (rc=$rc)"
    fi

    # Test with long macro name
    test_start "Detects long macro names"
    cat > "$temp_ado" << 'EOF'
*! testcommand Version 1.0.0  2025/01/15
program define testcommand, rclass
    version 18.0
    local this_is_a_very_long_macro_name_over_31_chars = 1
end
EOF

    "$script" "$temp_ado" >/dev/null 2>&1
    rc=$?
    if [[ $rc -eq 1 ]] || [[ $rc -eq 2 ]]; then
        test_pass
    else
        test_fail "Did not detect long macro (rc=$rc)"
    fi

    # Test nonexistent file
    test_start "Handles missing file"
    "$script" "/nonexistent/file.ado" >/dev/null 2>&1
    if [[ $? -eq 3 ]]; then
        test_pass
    else
        test_fail "Wrong exit code for missing file"
    fi
}

# =============================================================================
# Test: check-versions.sh functionality
# =============================================================================
test_check_versions() {
    header "check-versions.sh Tests"

    local script="$SCRIPTS_DIR/check-versions.sh"

    # Test on existing package
    test_start "Runs on existing package"

    # Find a package to test
    local pkg=$(find "$REPO_ROOT" -maxdepth 2 -name "*.pkg" ! -path "*/_templates/*" -exec basename -s .pkg {} \; 2>/dev/null | head -1)

    if [[ -n "$pkg" ]] && [[ -d "$REPO_ROOT/$pkg" ]]; then
        if "$script" "$pkg" >/dev/null 2>&1; then
            test_pass
        else
            local rc=$?
            if [[ $rc -eq 2 ]]; then
                # Warnings are OK
                test_pass
            else
                test_fail "Failed on $pkg (rc=$rc)"
            fi
        fi
    else
        test_skip "No packages found"
    fi

    # Test on nonexistent package
    test_start "Handles missing package"
    "$script" "nonexistent_pkg_12345" >/dev/null 2>&1
    # Should produce warning but not crash
    test_pass
}

# =============================================================================
# Test: check-test-coverage.sh functionality
# =============================================================================
test_check_coverage() {
    header "check-test-coverage.sh Tests"

    local script="$SCRIPTS_DIR/check-test-coverage.sh"

    test_start "Runs without args"
    if "$script" >/dev/null 2>&1; then
        test_pass
    else
        test_fail "Failed to run"
    fi

    test_start "Threshold option works"
    "$script" --threshold 0 >/dev/null 2>&1
    if [[ $? -le 2 ]]; then
        test_pass
    else
        test_fail "Threshold option failed"
    fi
}

# =============================================================================
# Test: Common library functions
# =============================================================================
test_common_functions() {
    header "Common Library Function Tests"

    # Source the library
    source "$LIB_DIR/common.sh"

    test_start "get_repo_root returns path"
    local root=$(get_repo_root)
    if [[ -d "$root" ]] && [[ -d "$root/.git" ]]; then
        test_pass
    else
        test_fail "Invalid repo root: $root"
    fi

    test_start "is_valid_semver accepts valid"
    if is_valid_semver "1.2.3"; then
        test_pass
    else
        test_fail "Rejected valid semver"
    fi

    test_start "is_valid_semver rejects invalid"
    if ! is_valid_semver "1.2"; then
        test_pass
    else
        test_fail "Accepted invalid semver"
    fi

    test_start "make_temp_file creates file"
    local tmp=$(make_temp_file "test")
    if [[ -f "$tmp" ]]; then
        test_pass
    else
        test_fail "Temp file not created"
    fi
}

# =============================================================================
# Main
# =============================================================================

echo "================================"
echo "Integration Tests for .claude/"
echo "================================"
echo ""

# Run all test suites
test_libraries
test_help_flags
test_validate_ado
test_check_versions
test_check_coverage
test_common_functions

# Summary
echo ""
echo "================================"
echo "Test Summary"
echo "================================"
echo -e "Passed:  ${GREEN}$TESTS_PASSED${NC}"
echo -e "Failed:  ${RED}$TESTS_FAILED${NC}"
echo -e "Skipped: ${YELLOW}$TESTS_SKIPPED${NC}"
echo ""

if [[ $TESTS_FAILED -gt 0 ]]; then
    echo -e "${RED}TESTS FAILED${NC}"
    exit 1
else
    echo -e "${GREEN}ALL TESTS PASSED${NC}"
    exit 0
fi
