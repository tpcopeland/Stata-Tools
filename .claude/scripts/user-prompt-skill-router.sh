#!/bin/bash
# .claude/scripts/user-prompt-skill-router.sh
# UserPromptSubmit hook - routes tasks to appropriate skills
# ADAPTED FOR: Stata package development (4 consolidated skills)

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/_read-hook-input.sh"

USER_PROMPT="$CLAUDE_USER_PROMPT"

# Exit early if no prompt
[ -z "$USER_PROMPT" ] && exit 0

# Lowercase for matching
PROMPT_LOWER=$(echo "$USER_PROMPT" | tr '[:upper:]' '[:lower:]')

# Skill routing patterns for Stata package development (4 consolidated skills)
declare -A SKILL_ROUTES=(
    # /develop - create/modify .ado commands, add features, fix bugs, generate code
    ["develop"]="create.*command|new.*command|fix.*bug|add.*feature|modify.*ado|develop.*ado|implement.*feature|write.*ado|scaffold.*command|generate.*code|generate.*ado|boilerplate|code.*from.*requirements|stata.*code"

    # /reviewer - code review, audit, pattern detection, scoring
    ["reviewer"]="review.*code|check.*ado|validate.*code|code.*review|review.*ado|check.*syntax|bug.*fix|debug|review.*command|style.*check|audit.*code|audit.*ado|mental.*execution|check.*error.*pattern"

    # /test - functional testing + validation testing
    ["test"]="write.*test|create.*test|functional.*test|test.*file|test_.*\.do|testing.*workflow|validation.*test|validate.*output|verify.*correct|known.*answer|correctness.*test|validation_.*\.do"

    # /package - package testing, structure validation, run tests
    ["package"]="test.*package|run.*test|validate.*package|test.*command|check.*test|certify|run.*ado|execute.*test|integration.*test|package.*structure|check.*coverage"
)

# Check for matches and output routing instructions
MATCHED_SKILLS=""
for skill in "${!SKILL_ROUTES[@]}"; do
    pattern="${SKILL_ROUTES[$skill]}"
    if echo "$PROMPT_LOWER" | grep -qE "$pattern"; then
        MATCHED_SKILLS="$MATCHED_SKILLS /$skill"
    fi
done

# Output skill routing reminder if matches found (compact format)
if [ -n "$MATCHED_SKILLS" ]; then
    echo ""
    echo "[Skill] Recommended for this task:$MATCHED_SKILLS"
fi

exit 0
