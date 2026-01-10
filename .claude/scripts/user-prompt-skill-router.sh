#!/bin/bash
# .claude/scripts/user-prompt-skill-router.sh
# UserPromptSubmit hook - routes tasks to appropriate skills
# ADAPTED FOR: Stata package development

USER_PROMPT="$CLAUDE_USER_PROMPT"

# Lowercase for matching
PROMPT_LOWER=$(echo "$USER_PROMPT" | tr '[:upper:]' '[:lower:]')

# Skill routing patterns for Stata package development
# Format: skill-name -> patterns (pipe-separated regex)
declare -A SKILL_ROUTES=(
    # Workflow skills (formerly commands)
    ["stata-develop"]="create.*command|new.*command|fix.*bug|add.*feature|modify.*ado|develop.*ado|implement.*feature|write.*ado|scaffold.*command"

    ["stata-test"]="write.*test|create.*test|functional.*test|test.*file|test_.*\.do|testing.*workflow"

    ["stata-validate"]="validation.*test|validate.*output|verify.*correct|known.*answer|correctness.*test|validation_.*\.do"

    ["stata-audit"]="audit.*code|audit.*ado|review.*code.*systematically|check.*error.*pattern|mental.*execution"

    # Expertise skills (auto-suggested)
    ["code-reviewer"]="review.*code|check.*ado|validate.*code|code.*review|review.*ado|check.*syntax|bug.*fix|debug|review.*command|style.*check"

    ["stata-code-generator"]="generate.*code|generate.*ado|boilerplate|code.*from.*requirements|stata.*code"

    ["package-tester"]="test.*package|run.*test|validate.*package|test.*command|check.*test|certify|run.*ado|execute.*test|integration.*test"

    # Help file skill (if you have one)
    ["help-file-reviewer"]="help.*file|sthlp|documentation|write.*help|update.*help|check.*help"
)

# Check for matches and output routing instructions
MATCHED_SKILLS=""
for skill in "${!SKILL_ROUTES[@]}"; do
    pattern="${SKILL_ROUTES[$skill]}"
    if echo "$PROMPT_LOWER" | grep -qE "$pattern"; then
        MATCHED_SKILLS="$MATCHED_SKILLS $skill"
    fi
done

# Output skill routing reminder if matches found
if [ -n "$MATCHED_SKILLS" ]; then
    echo "+============================================================+"
    echo "| SKILL ROUTING DETECTED                                     |"
    echo "+============================================================+"
    echo "| Recommended skill(s) for this task:                        |"
    for skill in $MATCHED_SKILLS; do
        printf "|   -> %-52s |\n" "$skill"
    done
    echo "+------------------------------------------------------------+"
    echo "| USE: Skill tool with skill=\"<skill-name>\" BEFORE writing  |"
    echo "| This ensures proper templates, quality gates, and output.  |"
    echo "+============================================================+"
fi

exit 0
