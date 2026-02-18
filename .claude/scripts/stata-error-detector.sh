#!/bin/bash
# .claude/scripts/stata-error-detector.sh
# PostToolUse hook for Bash - Detects Stata errors in command output and log files
#
# When Stata commands fail, this hook:
# 1. Detects the error type (r(XXX) pattern)
# 2. Extracts relevant error context
# 3. Suggests checking logs for batch mode runs

# Get command and output from environment
COMMAND="$CLAUDE_TOOL_INPUT_COMMAND"
OUTPUT="$CLAUDE_TOOL_OUTPUT"

# Exit early if no command
[ -z "$COMMAND" ] && exit 0

# Check if this was a Stata command
if [[ "$COMMAND" != *"stata"* ]] && [[ "$COMMAND" != *".do"* ]]; then
    exit 0
fi

# For batch mode runs, check the log file
if [[ "$COMMAND" == *"-b do"* ]]; then
    # Extract log file path from command
    DO_FILE=$(echo "$COMMAND" | grep -oP '(?<=-b do\s+)[^\s]+')
    if [ -n "$DO_FILE" ]; then
        LOG_FILE="${DO_FILE%.do}.log"
        if [ -f "$LOG_FILE" ]; then
            # Check for Stata error codes in log
            ERRORS=$(grep -E '^r\([0-9]+\)' "$LOG_FILE" 2>/dev/null)
            if [ -n "$ERRORS" ]; then
                echo ""
                echo "🚨 STATA ERRORS in $(basename "$LOG_FILE"):"
                echo "$ERRORS" | head -5 | while read -r line; do
                    echo "   $line"
                done

                # Get context around first error
                FIRST_ERROR=$(echo "$ERRORS" | head -1)
                ERROR_CODE=$(echo "$FIRST_ERROR" | grep -oP '\d+')
                CONTEXT=$(grep -B 5 "^r($ERROR_CODE)" "$LOG_FILE" 2>/dev/null | head -8)
                if [ -n "$CONTEXT" ]; then
                    echo ""
                    echo "   Context:"
                    echo "$CONTEXT" | while read -r line; do
                        echo "     $line"
                    done
                fi
                echo ""
            else
                # Check for PASS/FAIL summary
                if grep -q "ALL TESTS PASSED\|ALL VALIDATIONS PASSED" "$LOG_FILE" 2>/dev/null; then
                    echo ""
                    echo "✓ $(basename "$LOG_FILE"): All tests passed"
                elif grep -q "FAIL" "$LOG_FILE" 2>/dev/null; then
                    FAIL_COUNT=$(grep -c "FAIL" "$LOG_FILE" 2>/dev/null)
                    echo ""
                    echo "⚠️ $(basename "$LOG_FILE"): $FAIL_COUNT test failure(s)"
                fi
            fi
        fi
    fi
fi

# Check output for Stata error patterns (interactive mode)
if [ -n "$OUTPUT" ]; then
    ERROR_PATTERN='r\(([0-9]+)\)'
    if [[ "$OUTPUT" =~ $ERROR_PATTERN ]]; then
        ERROR_CODE="${BASH_REMATCH[1]}"

        # Map error codes to messages
        case $ERROR_CODE in
            111) ERROR_MSG="variable not found" ;;
            198) ERROR_MSG="invalid syntax" ;;
            199) ERROR_MSG="unrecognized command" ;;
            601) ERROR_MSG="file not found" ;;
            2000) ERROR_MSG="no observations" ;;
            459) ERROR_MSG="not sorted" ;;
            9) ERROR_MSG="assertion is false" ;;
            100) ERROR_MSG="varlist required" ;;
            109) ERROR_MSG="type mismatch" ;;
            110) ERROR_MSG="already defined" ;;
            *) ERROR_MSG="Stata error" ;;
        esac

        echo ""
        echo "🚨 STATA ERROR: r($ERROR_CODE) - $ERROR_MSG"

        # Extract the failed command from output context
        FAILED_CMD=$(echo "$OUTPUT" | grep -B 3 "r($ERROR_CODE)" | grep -v "^>" | head -1)
        if [ -n "$FAILED_CMD" ]; then
            echo "   Failed: ${FAILED_CMD:0:80}"
        fi
        echo ""
    fi
fi

# Check for Stata warnings
if [ -n "$OUTPUT" ]; then
    if [[ "$OUTPUT" == *"Warning:"* ]] || [[ "$OUTPUT" == *"note:"* ]]; then
        WARNINGS=$(echo "$OUTPUT" | grep -i "warning:\|note:" | head -3)
        if [ -n "$WARNINGS" ]; then
            echo ""
            echo "⚠️  Stata Warnings:"
            echo "$WARNINGS" | while read -r line; do
                echo "   $line"
            done
            echo ""
        fi
    fi
fi

exit 0
