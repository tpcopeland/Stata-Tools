#!/bin/bash
#
# test_hooks.sh - Tests for hook scripts
# Version: 2.0.0
#
# Tests that all hook scripts exist, are executable, have valid bash syntax,
# and produce expected outputs for functional tests.
#
# Usage: bash test_hooks.sh [-v|--verbose]

set -o pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
HOOKS_DIR="$REPO_ROOT/.claude/scripts/hooks"
SCRIPTS_DIR="$REPO_ROOT/.claude/scripts"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

VERBOSE=0
TESTS_PASSED=0
TESTS_FAILED=0
TESTS_SKIPPED=0

[[ "$1" == "-v" || "$1" == "--verbose" ]] && VERBOSE=1

test_start() {
    [[ $VERBOSE -eq 1 ]] && echo -n "  Testing: $1... "
}
test_pass() {
    TESTS_PASSED=$((TESTS_PASSED + 1))
    [[ $VERBOSE -eq 1 ]] && echo -e "${GREEN}PASS${NC}"
}
test_fail() {
    TESTS_FAILED=$((TESTS_FAILED + 1))
    if [[ $VERBOSE -eq 1 ]]; then echo -e "${RED}FAIL${NC}: $1"
    else echo -e "  ${RED}FAIL${NC}: $1"; fi
}
test_skip() {
    TESTS_SKIPPED=$((TESTS_SKIPPED + 1))
    [[ $VERBOSE -eq 1 ]] && echo -e "${YELLOW}SKIP${NC}: $1"
}

# =============================================================================
# Test: Hook files exist and are executable
# =============================================================================
echo "Hook File Tests"
echo "---------------"

HOOK_FILES=(
    "$HOOKS_DIR/pre-block-task.sh"
    "$HOOKS_DIR/pre-bash.sh"
    "$HOOKS_DIR/pre-write-edit.sh"
    "$HOOKS_DIR/post-bash.sh"
    "$HOOKS_DIR/post-bash-failure.sh"
    "$HOOKS_DIR/post-write-edit.sh"
    "$HOOKS_DIR/pre-compact.sh"
    "$HOOKS_DIR/session-end.sh"
)

for hook in "${HOOK_FILES[@]}"; do
    name=$(basename "$hook")

    test_start "$name exists"
    if [[ -f "$hook" ]]; then test_pass; else test_fail "$name not found"; continue; fi

    test_start "$name is executable"
    if [[ -x "$hook" ]]; then test_pass; else test_fail "$name not executable"; fi

    test_start "$name has valid bash syntax"
    if bash -n "$hook" 2>/dev/null; then test_pass; else test_fail "$name has syntax errors"; fi
done

# =============================================================================
# Test: Shared utility files exist
# =============================================================================
echo ""
echo "Shared Utility Tests"
echo "--------------------"

SHARED_FILES=(
    "$SCRIPTS_DIR/_read-hook-input.sh"
    "$SCRIPTS_DIR/_output-helpers.sh"
    "$SCRIPTS_DIR/error_handling.sh"
    "$SCRIPTS_DIR/validate-operation.sh"
    "$SCRIPTS_DIR/stata-error-detector.sh"
    "$SCRIPTS_DIR/user-prompt-skill-router.sh"
    "$SCRIPTS_DIR/session-context.sh"
    "$SCRIPTS_DIR/stop-hook-validation.sh"
)

for file in "${SHARED_FILES[@]}"; do
    name=$(basename "$file")

    test_start "$name exists"
    if [[ -f "$file" ]]; then test_pass; else test_fail "$name not found"; continue; fi

    test_start "$name has valid bash syntax"
    if bash -n "$file" 2>/dev/null; then test_pass; else test_fail "$name has syntax errors"; fi
done

# =============================================================================
# Functional Tests
# =============================================================================
echo ""
echo "Functional Tests"
echo "----------------"

# Test: pre-block-task.sh outputs JSON deny
test_start "pre-block-task.sh outputs JSON deny"
OUTPUT=$(echo '{"tool_name":"Task","tool_input":{"prompt":"test"}}' | bash "$HOOKS_DIR/pre-block-task.sh" 2>/dev/null)
if echo "$OUTPUT" | grep -q '"permissionDecision":"deny"'; then
    test_pass
else
    test_fail "Expected JSON deny output"
fi

# Test: pre-compact.sh outputs preservation instructions
test_start "pre-compact.sh outputs preservation instructions"
OUTPUT=$(echo '{}' | bash "$HOOKS_DIR/pre-compact.sh" 2>/dev/null)
if echo "$OUTPUT" | grep -q "COMPACTION INSTRUCTIONS"; then
    test_pass
else
    test_fail "Expected compaction instructions"
fi

# Test: validate-operation.sh blocks dangerous rm
test_start "validate-operation blocks dangerous rm"
OUTPUT=$(CLAUDE_TOOL_NAME="Bash" CLAUDE_TOOL_INPUT_COMMAND="rm -rf /" bash "$SCRIPTS_DIR/validate-operation.sh" 2>/dev/null)
RC=$?
if [[ $RC -eq 2 ]] && echo "$OUTPUT" | grep -q "BLOCKED"; then
    test_pass
else
    test_fail "Expected exit 2 and BLOCKED message (got rc=$RC)"
fi

# Test: validate-operation.sh warns about non-stata-mp
test_start "validate-operation warns about non-stata-mp"
OUTPUT=$(CLAUDE_TOOL_NAME="Bash" CLAUDE_TOOL_INPUT_COMMAND="stata -b do test.do" bash "$SCRIPTS_DIR/validate-operation.sh" 2>/dev/null)
if echo "$OUTPUT" | grep -q "stata-mp"; then
    test_pass
else
    test_fail "Expected stata-mp warning"
fi

# Test: validate-operation.sh allows stata-mp
test_start "validate-operation allows stata-mp commands"
CLAUDE_TOOL_NAME="Bash" CLAUDE_TOOL_INPUT_COMMAND="stata-mp -b do test.do" bash "$SCRIPTS_DIR/validate-operation.sh" >/dev/null 2>&1
RC=$?
if [[ $RC -eq 0 ]]; then
    test_pass
else
    test_fail "Expected exit 0 for stata-mp (got rc=$RC)"
fi

# Test: validate-operation.sh warns about protected files
test_start "validate-operation warns about protected files"
OUTPUT=$(CLAUDE_TOOL_NAME="Write" CLAUDE_TOOL_INPUT_FILE_PATH="/path/to/CLAUDE.md" bash "$SCRIPTS_DIR/validate-operation.sh" 2>/dev/null)
if echo "$OUTPUT" | grep -q "Protected file"; then
    test_pass
else
    test_fail "Expected protected file warning"
fi

# Test: validate-operation.sh warns about .pkg files
test_start "validate-operation warns about .pkg files"
OUTPUT=$(CLAUDE_TOOL_NAME="Write" CLAUDE_TOOL_INPUT_FILE_PATH="/path/to/mypackage.pkg" bash "$SCRIPTS_DIR/validate-operation.sh" 2>/dev/null)
if echo "$OUTPUT" | grep -q "Package definition"; then
    test_pass
else
    test_fail "Expected .pkg warning"
fi

# Test: user-prompt-skill-router.sh routes correctly
test_start "skill router suggests /develop for 'create command'"
OUTPUT=$(echo '{"prompt":"create a new stata command"}' | bash "$SCRIPTS_DIR/user-prompt-skill-router.sh" 2>/dev/null)
if echo "$OUTPUT" | grep -q "/develop"; then
    test_pass
else
    test_fail "Expected /develop suggestion"
fi

test_start "skill router suggests /review for 'review code'"
OUTPUT=$(echo '{"prompt":"review this ado code"}' | bash "$SCRIPTS_DIR/user-prompt-skill-router.sh" 2>/dev/null)
if echo "$OUTPUT" | grep -q "/review"; then
    test_pass
else
    test_fail "Expected /review suggestion"
fi

test_start "skill router suggests /test for 'write test'"
OUTPUT=$(echo '{"prompt":"write a functional test"}' | bash "$SCRIPTS_DIR/user-prompt-skill-router.sh" 2>/dev/null)
if echo "$OUTPUT" | grep -q "/test"; then
    test_pass
else
    test_fail "Expected /test suggestion"
fi

# Test: session-context.sh produces output
test_start "session-context.sh produces output"
OUTPUT=$(bash "$SCRIPTS_DIR/session-context.sh" 2>/dev/null)
if echo "$OUTPUT" | grep -q "STATA PACKAGE DEVELOPMENT SESSION"; then
    test_pass
else
    test_fail "Expected session header"
fi

# Test: stop-hook-validation.sh produces output
test_start "stop-hook-validation.sh produces output"
OUTPUT=$(bash "$SCRIPTS_DIR/stop-hook-validation.sh" 2>/dev/null)
if echo "$OUTPUT" | grep -q "SESSION VALIDATION"; then
    test_pass
else
    test_fail "Expected validation output"
fi

# =============================================================================
# Summary
# =============================================================================
echo ""
echo "================================"
echo "Hook Tests Summary"
echo "================================"
echo -e "Passed:  ${GREEN}$TESTS_PASSED${NC}"
echo -e "Failed:  ${RED}$TESTS_FAILED${NC}"
echo -e "Skipped: ${YELLOW}$TESTS_SKIPPED${NC}"

if [[ $TESTS_FAILED -gt 0 ]]; then
    echo -e "\n${RED}TESTS FAILED${NC}"
    exit 1
else
    echo -e "\n${GREEN}ALL TESTS PASSED${NC}"
    exit 0
fi
