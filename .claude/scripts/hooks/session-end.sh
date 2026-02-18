#!/bin/bash
# .claude/scripts/hooks/session-end.sh
# SessionEnd hook - final session summary
# All output goes to stderr; stdout must be empty or valid JSON for hooks.

[ -n "$CLAUDE_PROJECT_DIR" ] && cd "$CLAUDE_PROJECT_DIR"

# Check if we're in a git repo
if ! git rev-parse --git-dir > /dev/null 2>&1; then
    exit 0
fi

# Get all git info
UNCOMMITTED=$(git status --porcelain 2>/dev/null)
UNCOMMITTED_COUNT=$(echo "$UNCOMMITTED" | grep -c '^' 2>/dev/null || echo 0)

echo "" >&2
echo "=== SESSION END SUMMARY ===" >&2
echo "" >&2

# Show uncommitted changes
if [ "$UNCOMMITTED_COUNT" -gt 0 ] && [ -n "$UNCOMMITTED" ]; then
    echo "Uncommitted Changes: $UNCOMMITTED_COUNT file(s)" >&2

    # Show modified Stata files
    STATA_CHANGES=$(echo "$UNCOMMITTED" | grep -E "\.(ado|do|sthlp|pkg)$" | awk '{print $2}')
    if [ -n "$STATA_CHANGES" ]; then
        echo "" >&2
        echo "Modified Stata Files:" >&2
        echo "$STATA_CHANGES" | head -10 | while read -r file; do
            echo "  - $file" >&2
        done
    fi

    # Check for new test log failures
    NEW_LOGS=$(echo "$UNCOMMITTED" | grep "\.log$" | awk '{print $2}')
    if [ -n "$NEW_LOGS" ]; then
        echo "" >&2
        echo "Test Logs Modified:" >&2
        echo "$NEW_LOGS" | while read -r file; do
            if [ -f "$file" ] && grep -qE "^r\([0-9]+" "$file" 2>/dev/null; then
                echo "  - $file (WARNING: has errors)" >&2
            else
                echo "  - $file" >&2
            fi
        done
    fi
else
    echo "All changes committed." >&2
fi

# Reminder about workflow
echo "" >&2
echo "Next session: Review any failing tests and check version consistency" >&2
echo "" >&2

exit 0
