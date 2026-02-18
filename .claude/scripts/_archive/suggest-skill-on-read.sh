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
        SUGGESTION="stata-audit"
        CONTEXT="Stata command file detected - use /stata-audit for systematic review or /code-reviewer for detailed scoring"
        ;;

    # Stata do files (scripts/tests)
    *.do)
        if [[ "$FILE_PATH" == *test_* ]]; then
            SUGGESTION="stata-test"
            CONTEXT="Functional test file detected - use /stata-test for test workflow or /package-tester to run tests"
        elif [[ "$FILE_PATH" == *validation_* ]]; then
            SUGGESTION="stata-validate"
            CONTEXT="Validation test file detected - use /stata-validate for validation workflow"
        else
            SUGGESTION="code-reviewer"
            CONTEXT="Stata do-file detected - consider reviewing code"
        fi
        ;;

    # Stata help files
    *.sthlp|*.hlp)
        SUGGESTION="code-reviewer"
        CONTEXT="Help file detected - use /code-reviewer for documentation review"
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
