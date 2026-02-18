#!/bin/bash
# .claude/scripts/hooks/pre-compact.sh
# PreCompact hook - preserves Stata development context through compaction
# Outputs additionalContext to guide compaction model

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$SCRIPT_DIR/_read-hook-input.sh"

# Extract summary of conversation if available from hook input
if [ -n "$_HOOK_INPUT" ]; then
    _SUMMARY=$(echo "$_HOOK_INPUT" | jq -r '.summary // empty' 2>/dev/null)
    if [ -n "$_SUMMARY" ]; then
        echo "SESSION CONTEXT FROM TRANSCRIPT:"
        echo "$_SUMMARY"
        echo ""
    fi
fi

cat << 'EOF'
COMPACTION INSTRUCTIONS — Preserve the following across compaction:

1. CURRENT PACKAGE: If a specific .ado command or package is being worked on, preserve its name, file path, and what changes are being made.

2. CODE DECISIONS: Any decisions made this session about:
   - Syntax design (required options, optional options, abbreviations)
   - Return values (rclass/eclass, what scalars/macros to return)
   - Error handling approach
   - Algorithm or implementation choices

3. UNRESOLVED ISSUES: Any open bugs, failing tests, or known limitations being tracked.

4. ACTIVE WORKFLOW STATE: Which skill was last invoked, whether code review is pending, whether tests need to be run.

5. KEY FILE PATHS: Any .ado, .sthlp, .do file paths actively being edited.

6. VERSION STATE: Current version numbers and what needs to be updated.

Do NOT discard these even if they seem like minor details — they represent session-specific development context that cannot be reconstructed.
EOF

exit 0
