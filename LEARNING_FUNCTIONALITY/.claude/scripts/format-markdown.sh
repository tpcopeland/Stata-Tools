#!/bin/bash
# .claude/scripts/format-markdown.sh
# PostToolUse hook - ensures consistent markdown formatting after Edit|Write operations

FILE_PATH="$CLAUDE_TOOL_INPUT_FILE_PATH"

# Exit early if no file path or not a markdown file
[ -z "$FILE_PATH" ] && exit 0
[[ "$FILE_PATH" != *.md ]] && exit 0
[ ! -f "$FILE_PATH" ] && exit 0

# Simple, reliable formatting operations only
{
    # Remove Windows-style line endings
    sed -i 's/\r$//' "$FILE_PATH"

    # Ensure file ends with exactly one newline
    if [ -s "$FILE_PATH" ]; then
        # Check if file already ends with newline
        if [ "$(tail -c 1 "$FILE_PATH" | wc -l)" -eq 0 ]; then
            # File doesn't end with newline, add one
            echo "" >> "$FILE_PATH"
        fi
    fi
} 2>/dev/null

exit 0
