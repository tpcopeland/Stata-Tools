#!/bin/bash
# .claude/scripts/pre-tool-dispatcher.sh
# Unified PreToolUse dispatcher - consolidates hook scripts into single entry point
#
# Consolidates:
#   - validate-operation.sh (Bash|Write|Edit)
#
# Benefits: Single entry point, cleaner settings.json, proper routing by tool type

TOOL_NAME="$CLAUDE_TOOL_NAME"
SCRIPT_DIR="$(dirname "$0")"

# Source shared library if available
[ -f "$SCRIPT_DIR/../lib/common.sh" ] && source "$SCRIPT_DIR/../lib/common.sh"

# Exit early if no tool name
[ -z "$TOOL_NAME" ] && exit 0

case "$TOOL_NAME" in
    Task)
        # BLOCK: Never use subagents - do work directly in main session
        echo "BLOCKED: Task tool (subagents) is disabled. Do the work directly."
        exit 2
        ;;

    Bash)
        # Validate bash commands
        source "$SCRIPT_DIR/validate-operation.sh"
        ;;

    Write|Edit)
        # Validate file operations
        source "$SCRIPT_DIR/validate-operation.sh"
        ;;

    *)
        # Unknown tool - allow through
        exit 0
        ;;
esac

# If we haven't exited by now, allow the tool call
exit 0
