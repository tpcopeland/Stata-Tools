#!/bin/bash
# .claude/scripts/hooks/post-bash-failure.sh
# PostToolUseFailure hook for Bash - enhanced Stata failure diagnostics
# Matcher: Bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$SCRIPT_DIR/_read-hook-input.sh"

COMMAND="$CLAUDE_TOOL_INPUT_COMMAND"

# Exit early if not a Stata-related command
[ -z "$COMMAND" ] && exit 0
if [[ "$COMMAND" != *"stata"* ]] && [[ "$COMMAND" != *".do"* ]]; then
    exit 0
fi

# Extract error field from hook input if available
ERROR_MSG=""
if [ -n "$_HOOK_INPUT" ]; then
    ERROR_MSG=$(echo "$_HOOK_INPUT" | jq -r '.error // empty' 2>/dev/null)
fi

echo ""
echo "🚨 STATA COMMAND FAILED"
echo "   Command: ${COMMAND:0:80}"
if [ -n "$ERROR_MSG" ]; then
    echo "   Error: ${ERROR_MSG:0:200}"
fi
echo ""
echo "   Troubleshooting:"
echo "   1. Check if the .do file exists and paths are correct"
echo "   2. Check the .log file for detailed error output"
echo "   3. Verify stata-mp is available: which stata-mp"
echo ""

exit 0
