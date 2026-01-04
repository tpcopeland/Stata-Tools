#!/bin/bash
# .claude/scripts/suggest-skill-on-read.sh
# PostToolUse hook for Read - suggests relevant skills based on file type
# ADAPTED FOR: Stata package development

FILE_PATH="$CLAUDE_TOOL_INPUT_FILE_PATH"

# Exit early if no file path
[ -z "$FILE_PATH" ] && exit 0
[ ! -f "$FILE_PATH" ] && exit 0

# Determine file type and suggest appropriate skill
SUGGESTION=""

case "$FILE_PATH" in
    # Stata ado files (commands)
    *.ado)
        SUGGESTION="code-reviewer"
        CONTEXT="Stata command file detected - consider reviewing for bugs and style"
        ;;

    # Stata do files (scripts/tests)
    *.do)
        if [[ "$FILE_PATH" == *test* ]]; then
            SUGGESTION="package-tester"
            CONTEXT="Test file detected - consider running tests"
        else
            SUGGESTION="code-reviewer"
            CONTEXT="Stata do-file detected - consider reviewing code"
        fi
        ;;

    # Stata help files
    *.sthlp|*.hlp)
        SUGGESTION="help-file-reviewer"
        CONTEXT="Help file detected - consider reviewing documentation"
        ;;

    # Package definition files
    *.pkg)
        SUGGESTION=""
        CONTEXT="Package definition file - check stata.toc consistency"
        echo ""
        echo "[Package] Package file detected: check stata.toc is updated"
        ;;

    # Log files (test output)
    *.log)
        SUGGESTION=""
        # Check if log has errors
        if grep -qE "^r\([0-9]+" "$FILE_PATH" 2>/dev/null; then
            echo ""
            echo "[Warning] Test log with errors detected"
            echo "   Review errors and create development log if novel patterns"
        fi
        ;;

    # Common errors reference
    *stata-common-errors.md)
        SUGGESTION=""  # Reference file, no specific skill
        ;;

    # Development logs
    *_resources/logs/*.md)
        SUGGESTION=""  # Historical reference
        ;;
esac

# Output skill suggestion if applicable (compact format)
if [ -n "$SUGGESTION" ]; then
    echo ""
    echo "[Skill] Suggestion: $SUGGESTION"
    echo "   $CONTEXT"
fi

exit 0
