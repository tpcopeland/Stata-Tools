#!/bin/bash
#
# test_mcp.sh - Tests for MCP server
# Version: 2.0.0
#
# Tests that the MCP server files exist, Python syntax is valid,
# and the tool modules work correctly.
#
# Usage: bash test_mcp.sh [-v|--verbose]

set -o pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
MCP_DIR="$REPO_ROOT/.claude/mcp_servers/stata-library"

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

echo "MCP Server File Tests"
echo "---------------------"

# Test: Required files exist
for file in "server.py" "requirements.txt" "setup.sh" "tools/__init__.py" "tools/commands.py" "tools/snippets.py"; do
    test_start "$file exists"
    if [[ -f "$MCP_DIR/$file" ]]; then test_pass; else test_fail "$file not found"; fi
done

# Test: Test files exist
for file in "tests/__init__.py" "tests/test_commands.py" "tests/test_snippets.py" "tests/test_server.py"; do
    test_start "$file exists"
    if [[ -f "$MCP_DIR/$file" ]]; then test_pass; else test_fail "$file not found"; fi
done

# Test: setup.sh is executable
test_start "setup.sh is executable"
if [[ -x "$MCP_DIR/setup.sh" ]]; then test_pass; else test_fail "setup.sh not executable"; fi

echo ""
echo "Python Syntax Tests"
echo "-------------------"

# Test: Python files have valid syntax
for pyfile in "$MCP_DIR/server.py" "$MCP_DIR/tools/commands.py" "$MCP_DIR/tools/snippets.py"; do
    name=$(basename "$pyfile")
    test_start "$name has valid Python syntax"
    if python3 -c "import py_compile; py_compile.compile('$pyfile', doraise=True)" 2>/dev/null; then
        test_pass
    else
        test_fail "$name has syntax errors"
    fi
done

echo ""
echo "Module Import Tests"
echo "-------------------"

# Test: Tool modules can be imported
test_start "commands.py importable"
if python3 -c "import sys; sys.path.insert(0, '$MCP_DIR/tools'); import commands" 2>/dev/null; then
    test_pass
else
    test_fail "Cannot import commands"
fi

test_start "snippets.py importable"
if python3 -c "import sys; sys.path.insert(0, '$MCP_DIR/tools'); import snippets" 2>/dev/null; then
    test_pass
else
    test_fail "Cannot import snippets"
fi

# Test: Snippet tests pass directly
test_start "snippet tests pass"
if python3 "$MCP_DIR/tests/test_snippets.py" >/dev/null 2>&1; then
    test_pass
else
    test_fail "Snippet tests failed"
fi

# Test: requirements.txt has mcp dependency
test_start "requirements.txt has mcp dependency"
if grep -q "mcp" "$MCP_DIR/requirements.txt"; then test_pass; else test_fail "Missing mcp dependency"; fi

# Test: server.py uses FastMCP
test_start "server.py uses FastMCP"
if grep -q "FastMCP" "$MCP_DIR/server.py"; then test_pass; else test_fail "Not using FastMCP"; fi

# Test: server.py has @mcp.tool decorators
test_start "server.py has @mcp.tool decorators"
TOOL_COUNT=$(grep -c "@mcp.tool" "$MCP_DIR/server.py")
if [[ $TOOL_COUNT -ge 6 ]]; then
    test_pass
else
    test_fail "Expected >= 6 tools, found $TOOL_COUNT"
fi

# =============================================================================
# Summary
# =============================================================================
echo ""
echo "================================"
echo "MCP Tests Summary"
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
