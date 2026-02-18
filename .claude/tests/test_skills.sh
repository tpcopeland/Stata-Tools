#!/bin/bash
#
# test_skills.sh - Tests for skill files
# Version: 2.0.0
#
# Tests that all skill directories have valid SKILL.md files with
# proper YAML frontmatter and structure.
#
# Usage: bash test_skills.sh [-v|--verbose]

set -o pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
SKILLS_DIR="$REPO_ROOT/.claude/skills"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
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

# Expected skills
EXPECTED_SKILLS=("develop" "review" "test" "package")

echo "Skill Directory Tests"
echo "---------------------"

# Test: Expected skill directories exist
for skill in "${EXPECTED_SKILLS[@]}"; do
    test_start "$skill/ directory exists"
    if [[ -d "$SKILLS_DIR/$skill" ]]; then test_pass; else test_fail "$skill/ not found"; fi

    test_start "$skill/SKILL.md exists"
    SKILL_FILE="$SKILLS_DIR/$skill/SKILL.md"
    if [[ -f "$SKILL_FILE" ]]; then test_pass; else test_fail "$skill/SKILL.md not found"; continue; fi

    # Test: YAML frontmatter starts with ---
    test_start "$skill/SKILL.md has YAML frontmatter"
    if head -1 "$SKILL_FILE" | grep -q '^---$'; then test_pass; else test_fail "Missing --- at line 1"; fi

    # Test: Has name field
    test_start "$skill/SKILL.md has name field"
    if grep -q "^name: $skill" "$SKILL_FILE"; then test_pass; else test_fail "Missing name: $skill"; fi

    # Test: Has description field
    test_start "$skill/SKILL.md has description field"
    if grep -q "^description:" "$SKILL_FILE"; then test_pass; else test_fail "Missing description"; fi

    # Test: Has allowed-tools
    test_start "$skill/SKILL.md has allowed-tools"
    if grep -q "^allowed-tools:" "$SKILL_FILE"; then test_pass; else test_fail "Missing allowed-tools"; fi

    # Test: Does NOT allow Task tool
    test_start "$skill/SKILL.md blocks Task tool"
    if grep -q "Task tool is NOT allowed" "$SKILL_FILE"; then test_pass; else test_fail "Missing Task tool prohibition"; fi

    # Test: SKILL.md is under 500 lines
    test_start "$skill/SKILL.md is under 500 lines"
    LINES=$(wc -l < "$SKILL_FILE")
    if [[ $LINES -lt 500 ]]; then test_pass; else test_fail "SKILL.md has $LINES lines (max 500)"; fi
done

echo ""
echo "Shared Resources Tests"
echo "----------------------"

# Test: _shared directory exists
test_start "_shared/ directory exists"
if [[ -d "$SKILLS_DIR/_shared" ]]; then test_pass; else test_fail "_shared/ not found"; fi

# Test: delegation-rules.md exists
test_start "_shared/delegation-rules.md exists"
if [[ -f "$SKILLS_DIR/_shared/delegation-rules.md" ]]; then test_pass; else test_fail "Missing delegation-rules.md"; fi

# Test: context-loading.md exists
test_start "_shared/context-loading.md exists"
if [[ -f "$SKILLS_DIR/_shared/context-loading.md" ]]; then test_pass; else test_fail "Missing context-loading.md"; fi

# Test: README.md exists and references all 4 skills
test_start "README.md exists"
if [[ -f "$SKILLS_DIR/README.md" ]]; then test_pass; else test_fail "README.md not found"; fi

for skill in "${EXPECTED_SKILLS[@]}"; do
    test_start "README.md references $skill"
    if grep -q "$skill" "$SKILLS_DIR/README.md"; then test_pass; else test_fail "README.md missing $skill reference"; fi
done

echo ""
echo "Old Skills Removed Tests"
echo "------------------------"

# Test: Old skill directories are gone
OLD_SKILLS=("stata-develop" "stata-code-generator" "code-reviewer" "stata-audit" "stata-test" "stata-validate" "package-tester")
for old in "${OLD_SKILLS[@]}"; do
    test_start "$old/ removed"
    if [[ ! -d "$SKILLS_DIR/$old" ]]; then test_pass; else test_fail "$old/ still exists"; fi
done

# Test: metadata.version field exists
echo ""
echo "YAML Metadata Tests"
echo "-------------------"

for skill in "${EXPECTED_SKILLS[@]}"; do
    SKILL_FILE="$SKILLS_DIR/$skill/SKILL.md"
    [[ ! -f "$SKILL_FILE" ]] && continue

    test_start "$skill has metadata.version"
    if grep -q "version:" "$SKILL_FILE"; then test_pass; else test_fail "Missing version in metadata"; fi

    test_start "$skill has argument-hint"
    if grep -q "argument-hint:" "$SKILL_FILE"; then test_pass; else test_fail "Missing argument-hint"; fi
done

# =============================================================================
# Summary
# =============================================================================
echo ""
echo "================================"
echo "Skill Tests Summary"
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
