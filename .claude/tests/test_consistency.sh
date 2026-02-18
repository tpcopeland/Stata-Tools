#!/bin/bash
#
# test_consistency.sh - Cross-reference consistency tests
# Version: 2.0.0
#
# Tests that settings.json, skills README, CLAUDE.md, and hook scripts
# all reference consistent skill names and file paths.
#
# Usage: bash test_consistency.sh [-v|--verbose]

set -o pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
CLAUDE_DIR="$REPO_ROOT/.claude"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

VERBOSE=0
TESTS_PASSED=0
TESTS_FAILED=0

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

echo "Settings.json Consistency"
echo "-------------------------"

SETTINGS="$CLAUDE_DIR/settings.json"

# Test: settings.json is valid JSON
test_start "settings.json is valid JSON"
if jq empty "$SETTINGS" 2>/dev/null; then test_pass; else test_fail "Invalid JSON"; fi

# Test: All hook script paths in settings.json exist
test_start "All hook script paths exist"
MISSING_HOOKS=0
# Extract all command paths from settings.json
HOOK_PATHS=$(jq -r '.. | .command? // empty' "$SETTINGS" 2>/dev/null | grep -v 'notify-send' | sed 's|"$CLAUDE_PROJECT_DIR"/||' | sed 's|"||g')
while IFS= read -r path; do
    FULL_PATH="$REPO_ROOT/$path"
    if [[ ! -f "$FULL_PATH" ]]; then
        MISSING_HOOKS=$((MISSING_HOOKS + 1))
        [[ $VERBOSE -eq 1 ]] && echo -e "\n    Missing: $path"
    fi
done <<< "$HOOK_PATHS"
if [[ $MISSING_HOOKS -eq 0 ]]; then test_pass; else test_fail "$MISSING_HOOKS missing hook scripts"; fi

# Test: Required hook types present
for hook_type in "SessionStart" "PreToolUse" "PostToolUse" "PreCompact" "PostToolUseFailure" "Stop" "Notification" "SessionEnd"; do
    test_start "settings.json has $hook_type"
    if jq -e ".hooks.\"$hook_type\"" "$SETTINGS" >/dev/null 2>&1; then test_pass; else test_fail "Missing $hook_type"; fi
done

# Test: Task matcher blocks Task tool
test_start "Task tool has deny matcher"
if jq -r '.hooks.PreToolUse[] | select(.matcher == "Task")' "$SETTINGS" 2>/dev/null | grep -q "Task"; then
    test_pass
else
    test_fail "No Task matcher found"
fi

echo ""
echo "Cross-Reference Tests"
echo "---------------------"

# Test: CLAUDE.md references all 4 new skills
for skill in "develop" "review" "test" "package"; do
    test_start "CLAUDE.md references /$skill"
    if grep -q "/$skill" "$REPO_ROOT/CLAUDE.md" 2>/dev/null; then test_pass; else test_fail "CLAUDE.md missing /$skill"; fi
done

# Test: No stale old skill names in CLAUDE.md
OLD_SKILLS=("stata-develop" "stata-code-generator" "code-reviewer" "stata-audit" "stata-test" "stata-validate" "package-tester")
for old in "${OLD_SKILLS[@]}"; do
    test_start "CLAUDE.md does not reference /$old"
    if ! grep -q "/$old" "$REPO_ROOT/CLAUDE.md" 2>/dev/null; then test_pass; else test_fail "CLAUDE.md still references /$old"; fi
done

# Test: Skills README references all skills
for skill in "develop" "review" "test" "package"; do
    test_start "Skills README references $skill"
    if grep -q "$skill" "$CLAUDE_DIR/skills/README.md" 2>/dev/null; then test_pass; else test_fail "Skills README missing $skill"; fi
done

# Test: Router script references all new skill names
ROUTER="$CLAUDE_DIR/scripts/user-prompt-skill-router.sh"
for skill in "develop" "review" "test" "package"; do
    test_start "Router references $skill"
    if grep -q "\"$skill\"" "$ROUTER" 2>/dev/null; then test_pass; else test_fail "Router missing $skill"; fi
done

echo ""
echo "Policy Consistency"
echo "------------------"

# Test: Policies exist
for policy in "mandatory-code-review.md" "test-before-commit.md" "version-consistency.md" "no-subagents.md"; do
    test_start "Policy $policy exists"
    if [[ -f "$CLAUDE_DIR/policies/$policy" ]]; then test_pass; else test_fail "$policy not found"; fi
done

# =============================================================================
# Summary
# =============================================================================
echo ""
echo "================================"
echo "Consistency Tests Summary"
echo "================================"
echo -e "Passed:  ${GREEN}$TESTS_PASSED${NC}"
echo -e "Failed:  ${RED}$TESTS_FAILED${NC}"

if [[ $TESTS_FAILED -gt 0 ]]; then
    echo -e "\n${RED}TESTS FAILED${NC}"
    exit 1
else
    echo -e "\n${GREEN}ALL TESTS PASSED${NC}"
    exit 0
fi
