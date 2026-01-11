#!/bin/bash
# .claude/scripts/session-context.sh
# SessionStart hook - provides concise, actionable project context at session start
# ADAPTED FOR: Stata package development

# Dynamically determine repo root for robustness
REPO_ROOT=$(git rev-parse --show-toplevel 2>/dev/null)
if [ -z "$REPO_ROOT" ]; then
    echo "=== Not in a git repository ==="
    exit 0
fi
cd "$REPO_ROOT" || exit 1

echo "=== STATA PACKAGE DEVELOPMENT SESSION ==="
echo ""

# Current branch and git status (combined, compact)
BRANCH=$(git branch --show-current 2>/dev/null)
STATUS=$(git status --short 2>/dev/null)
echo "Branch: ${BRANCH:-Not a git repo}"
[ -n "$STATUS" ] && echo "" && echo "Git Status:" && echo "$STATUS"
echo ""

# Recently modified .ado files - show if there are results
RECENT_ADO=$(find "$REPO_ROOT" -name "*.ado" -mtime -7 -type f 2>/dev/null | sed "s|$REPO_ROOT/||" | sort | head -5)
if [ -n "$RECENT_ADO" ]; then
    echo "Recently Modified Commands (last 7 days):"
    echo "$RECENT_ADO" | while read -r file; do
        echo "  * $file"
    done
    echo ""
fi

# Recent test activity - show if there are results
RECENT_TESTS=$(find "$REPO_ROOT" -name "test_*.do" -mtime -7 -type f 2>/dev/null | sed "s|$REPO_ROOT/||" | head -3)
if [ -n "$RECENT_TESTS" ]; then
    echo "Recent Test Files:"
    echo "$RECENT_TESTS" | while read -r file; do
        echo "  * $file"
    done
    echo ""
fi

# Check for failed test logs (logs with errors)
# Pattern ^r\([0-9]+ matches Stata error codes like r(111);
FAILED_TESTS=$(find "$REPO_ROOT" -name "*.log" -mtime -1 -type f -exec grep -l '^r([0-9]\+)' {} \; 2>/dev/null | head -3)
if [ -n "$FAILED_TESTS" ]; then
    echo "WARNING: Recent Failed Tests:"
    echo "$FAILED_TESTS" | while read -r file; do
        echo "  * $(basename "$file")"
    done
    echo ""
fi

# Count packages
PACKAGE_COUNT=$(find "$REPO_ROOT" -name "*.pkg" -type f 2>/dev/null | wc -l)
ADO_COUNT=$(find "$REPO_ROOT" -name "*.ado" -type f 2>/dev/null | wc -l)

# Compact footer
echo "Skills:   .claude/skills/ for /stata-develop, /stata-test, code review, generation"
echo "Packages: $PACKAGE_COUNT | Commands: $ADO_COUNT"
echo ""

exit 0
