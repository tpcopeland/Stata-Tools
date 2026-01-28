#!/bin/bash
# .claude/scripts/post-tool-dispatcher.sh
# Unified PostToolUse dispatcher - consolidates hook scripts into single entry point
#
# Consolidates:
#   - suggest-skill-on-read.sh (Read)
#   - format-markdown.sh (Edit|Write)
#   - Auto-validate .ado files after write (new)
#
# Benefits: Single entry point, cleaner settings.json, proper routing by tool type

TOOL_NAME="$CLAUDE_TOOL_NAME"
FILE_PATH="$CLAUDE_TOOL_INPUT_FILE_PATH"
SCRIPT_DIR="$(dirname "$0")"

# Source shared library if available
[ -f "$SCRIPT_DIR/../lib/common.sh" ] && source "$SCRIPT_DIR/../lib/common.sh"

# Exit early if no tool name
[ -z "$TOOL_NAME" ] && exit 0

case "$TOOL_NAME" in
    Read)
        # Suggest skills based on file type
        source "$SCRIPT_DIR/suggest-skill-on-read.sh"
        ;;

    Edit|Write)
        # Format markdown files
        source "$SCRIPT_DIR/format-markdown.sh"

        # Auto-validate .ado files after write
        if [[ -n "$FILE_PATH" && "$FILE_PATH" == *.ado && -f "$FILE_PATH" ]]; then
            VALIDATOR="$SCRIPT_DIR/../validators/validate-ado.sh"
            if [ -x "$VALIDATOR" ]; then
                echo ""
                echo "[Auto-Validate] Running validate-ado.sh on $(basename "$FILE_PATH")..."
                "$VALIDATOR" "$FILE_PATH" 2>&1 | head -20
            fi
        fi
        ;;

    Bash)
        # Check for Stata errors in command output
        COMMAND="$CLAUDE_TOOL_INPUT_COMMAND"
        if [[ -n "$COMMAND" && "$COMMAND" == *"stata-mp"* ]]; then
            # Stata command was run - check for common error patterns
            # Note: We can't access output directly, but we can remind about logs
            if [[ "$COMMAND" == *"-b do"* ]]; then
                # Batch mode - there's a log file
                LOG_FILE=$(echo "$COMMAND" | grep -oP '(?<=-b do\s+)[^\s]+' | sed 's/\.do$/.log/')
                if [ -n "$LOG_FILE" ]; then
                    echo ""
                    echo "[Stata] Check log for errors: grep -E '^r\\([0-9]+' $LOG_FILE"
                fi
            fi
        fi
        ;;

    *)
        # Unknown tool - no action
        exit 0
        ;;
esac

exit 0
