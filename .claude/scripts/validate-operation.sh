#!/bin/bash
# .claude/scripts/validate-operation.sh
# PreToolUse hook - validates operations before execution
# ADAPTED FOR: Stata package development

TOOL_NAME="$CLAUDE_TOOL_NAME"
FILE_PATH="$CLAUDE_TOOL_INPUT_FILE_PATH"
COMMAND="$CLAUDE_TOOL_INPUT_COMMAND"

# Protected patterns - files that should not be overwritten without warning
PROTECTED_PATTERNS=(
    "CLAUDE.md"
    "README.md"
    "stata.toc"
    ".claude/settings.json"
    ".claude/skills/README.md"
    "_resources/context/"
)

# Check if file matches protected patterns (for Write/Edit operations)
if [[ "$TOOL_NAME" == "Write" || "$TOOL_NAME" == "Edit" ]] && [ -n "$FILE_PATH" ]; then
    for pattern in "${PROTECTED_PATTERNS[@]}"; do
        if [[ "$FILE_PATH" == *"$pattern"* ]]; then
            # Allow edits to scripts (we need to maintain these)
            if [[ "$FILE_PATH" == *".claude/scripts/"* ]]; then
                exit 0
            fi
            # Allow edits to skill SKILL.md files (maintenance)
            if [[ "$FILE_PATH" == *"/SKILL.md" ]]; then
                exit 0
            fi
            echo "WARNING: Protected file: $FILE_PATH"
            echo "    This is a core configuration file."
            exit 0  # Warning only, don't block
        fi
    done

    # Warn about .pkg file modifications
    if [[ "$FILE_PATH" == *.pkg ]]; then
        echo "WARNING: Package definition file: $FILE_PATH"
        echo "    Ensure stata.toc is also updated if needed."
        exit 0
    fi
fi

# Validate Bash commands for dangerous patterns
if [[ "$TOOL_NAME" == "Bash" ]] && [ -n "$COMMAND" ]; then
    # Block catastrophic rm commands (root, home, entire repo)
    if echo "$COMMAND" | grep -qE "rm\s+(-rf?|--force)\s+(/|~|\.\s*$)"; then
        echo "BLOCKED: Catastrophic delete command"
        exit 2
    fi

    # Block rm -rf on important directories
    if echo "$COMMAND" | grep -qE "rm\s+(-rf?|--force)\s+\.claude"; then
        echo "BLOCKED: Destructive command on .claude directory"
        echo "   Command: $COMMAND"
        exit 2  # Block the operation
    fi

    # Block rm -rf on root-level important files
    if echo "$COMMAND" | grep -qE "rm\s+(-rf?|--force)\s+(CLAUDE\.md|README\.md|stata\.toc)"; then
        echo "BLOCKED: Cannot delete core files"
        exit 2
    fi

    # Warn about git push --force
    if echo "$COMMAND" | grep -qE "git\s+push\s+.*--force"; then
        echo "WARNING: Force push detected - proceed with caution"
        exit 0  # Warning only
    fi

    # Warn about git reset --hard
    if echo "$COMMAND" | grep -qE "git\s+reset\s+--hard"; then
        echo "WARNING: Hard reset detected - this discards uncommitted changes"
        exit 0  # Warning only
    fi

    # Warn about branch deletion of main
    if echo "$COMMAND" | grep -qE "git\s+branch\s+(-d|-D)\s+main"; then
        echo "BLOCKED: Cannot delete main branch"
        exit 2
    fi

    # Warn about running Stata without stata-mp
    if echo "$COMMAND" | grep -qE '\bstata\b|\bstata-se\b' && ! echo "$COMMAND" | grep -qE '\bstata-mp\b'; then
        echo "WARNING: Use stata-mp (multiprocessor) instead of stata or stata-se"
        exit 0  # Warning only
    fi
fi

exit 0
