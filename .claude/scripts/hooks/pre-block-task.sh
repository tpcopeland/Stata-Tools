#!/bin/bash
# .claude/scripts/hooks/pre-block-task.sh
# PreToolUse hook for Task tool - blocks subagent usage
# Matcher: Task

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$SCRIPT_DIR/_read-hook-input.sh"

# Use JSON hookSpecificOutput to deny with a clear reason
REASON="Task tool usage violates no-subagent policy. CLAUDE.md prohibits: 'NEVER use the Task tool to spawn subagents.' Use instead: WebSearch/WebFetch for web, Glob/Grep/Read for codebase, Skill tool for expertise. See: .claude/policies/no-subagents.md"

echo '{"hookSpecificOutput":{"permissionDecision":"deny","permissionDecisionReason":"'"$REASON"'"}}'
exit 0
