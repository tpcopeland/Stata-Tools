#!/bin/bash
# .claude/scripts/stop-hook-validation.sh
# Stop hook - provides end-of-task validation and reminders
# ADAPTED FOR: Stata package development

# Get all git info in one call
UNCOMMITTED=$(git status --porcelain 2>/dev/null)
UNCOMMITTED_COUNT=$(echo "$UNCOMMITTED" | grep -c '^' 2>/dev/null || echo 0)

echo ""
echo "=== SESSION VALIDATION ==="
echo ""

# Show uncommitted changes section
if [ "$UNCOMMITTED_COUNT" -gt 0 ] && [ -n "$UNCOMMITTED" ]; then
    echo "Uncommitted Changes: $UNCOMMITTED_COUNT file(s)"

    # Filter and display .ado/.do changes
    ADO_CHANGES=$(echo "$UNCOMMITTED" | grep -E "\.(ado|do|sthlp)$" | awk '{print $2}')
    if [ -n "$ADO_CHANGES" ]; then
        echo ""
        echo "Modified Stata Files:"
        echo "$ADO_CHANGES" | head -10 | while read -r file; do
            echo "  * $file"
        done
    fi

    # Check for new test failures
    NEW_LOGS=$(echo "$UNCOMMITTED" | grep "\.log$" | awk '{print $2}')
    if [ -n "$NEW_LOGS" ]; then
        echo ""
        echo "Test Logs Modified:"
        echo "$NEW_LOGS" | while read -r file; do
            if [ -f "$file" ] && grep -qE "^r\([0-9]+" "$file" 2>/dev/null; then
                echo "  * $file (WARNING: has errors)"
            else
                echo "  * $file"
            fi
        done
    fi
else
    echo "All changes committed"
fi

echo ""

exit 0
