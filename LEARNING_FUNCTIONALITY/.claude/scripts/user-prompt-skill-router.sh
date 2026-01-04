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
    # Code review skill
    ["code-reviewer"]="review.*code|check.*ado|validate.*code|code.*review|review.*ado|check.*syntax|bug.*fix|debug|review.*command|audit.*code|style.*check"

    # Code generation skill
    ["stata-code-generator"]="generate.*code|create.*command|new.*ado|write.*ado|create.*ado|implement.*command|stata.*code|add.*option|add.*feature|extend.*command"

    # Package testing skill
    ["package-tester"]="test.*package|run.*test|validate.*package|test.*command|check.*test|certify|test.*ado|run.*ado|execute.*test|integration.*test"

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
    echo "╔════════════════════════════════════════════════════════════╗"
    echo "║ 🎯 SKILL ROUTING DETECTED                                   ║"
    echo "╠════════════════════════════════════════════════════════════╣"
    echo "║ Recommended skill(s) for this task:                        ║"
    for skill in $MATCHED_SKILLS; do
        printf "║   → %-52s ║\n" "$skill"
    done
    echo "╠════════════════════════════════════════════════════════════╣"
    echo "║ USE: Skill tool with skill=\"<skill-name>\" BEFORE writing  ║"
    echo "║ This ensures proper templates, quality gates, and output.  ║"
    echo "╚════════════════════════════════════════════════════════════╝"
fi

exit 0
