#!/bin/bash
# .claude/scripts/stop-hook-validation.sh
# Stop hook - provides end-of-session validation and reminders
# ADAPTED FOR: Stata package development

# Get all git info in one call
UNCOMMITTED=$(git status --porcelain 2>/dev/null)
UNCOMMITTED_COUNT=$(echo "$UNCOMMITTED" | grep -c '^' 2>/dev/null || echo 0)

echo ""
echo "=== SESSION VALIDATION ==="
echo ""

# Show uncommitted changes section
if [ "$UNCOMMITTED_COUNT" -gt 0 ] && [ -n "$UNCOMMITTED" ]; then
    echo "📝 Uncommitted Changes: $UNCOMMITTED_COUNT file(s)"

    # Filter and display .ado/.do changes
    ADO_CHANGES=$(echo "$UNCOMMITTED" | grep -E "\.(ado|do|sthlp)$" | awk '{print $2}')
    if [ -n "$ADO_CHANGES" ]; then
        echo ""
        echo "Modified Stata Files:"
        echo "$ADO_CHANGES" | head -10 | while read -r file; do
            echo "  • $file"
        done
    fi

    # Check for new test failures
    NEW_LOGS=$(echo "$UNCOMMITTED" | grep "\.log$" | awk '{print $2}')
    if [ -n "$NEW_LOGS" ]; then
        echo ""
        echo "Test Logs Modified:"
        echo "$NEW_LOGS" | while read -r file; do
            if grep -qE "^r\([0-9]+" "$file" 2>/dev/null; then
                echo "  • $file (⚠️ has errors)"
            else
                echo "  • $file"
            fi
        done
    fi
else
    echo "✓ All changes committed"
fi

# Check if development log should be created
RECENT_ERRORS=$(find . -name "*.log" -mmin -60 -exec grep -l "^r([0-9]" {} \; 2>/dev/null | head -1)
if [ -n "$RECENT_ERRORS" ]; then
    echo ""
    echo "📋 Consider creating development log for recent test errors"
    echo "   Template: _resources/templates/logs/development-log.md"
fi

# Reminder about workflow
echo ""
echo "─────────────────────────────────"
echo "Next session: Review any failed tests and create development logs"
echo ""

exit 0
