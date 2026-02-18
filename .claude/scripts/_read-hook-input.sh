#!/bin/bash
# .claude/scripts/_read-hook-input.sh
# Shared helper: reads stdin JSON from Claude Code hooks and exports variables
# matching the legacy naming convention for backward compatibility.
#
# Usage: source "$SCRIPT_DIR/_read-hook-input.sh"
#
# Claude Code hooks receive JSON on stdin with fields like:
#   { "tool_name": "...", "tool_input": { "file_path": "...", "command": "..." }, ... }
#   { "prompt": "..." }  (for UserPromptSubmit)
#   { "tool_response": "..." }  (for PostToolUse)
#   { "session_id": "..." }  (for SessionStart)
#
# This helper exports:
#   CLAUDE_TOOL_NAME, CLAUDE_TOOL_INPUT_FILE_PATH, CLAUDE_TOOL_INPUT_COMMAND,
#   CLAUDE_USER_PROMPT, CLAUDE_TOOL_OUTPUT, CLAUDE_SESSION_ID
#
# Falls back to existing env vars if stdin is empty (backward compat).

if [ -z "$_HOOK_INPUT_LOADED" ]; then
    export _HOOK_INPUT_LOADED=1

    # Read all of stdin (non-blocking if empty)
    _HOOK_INPUT=$(cat)
    export _HOOK_INPUT

    if [ -n "$_HOOK_INPUT" ]; then
        # Parse JSON fields — only overwrite if the field exists in input
        _val=$(echo "$_HOOK_INPUT" | jq -r '.tool_name // empty' 2>/dev/null)
        [ -n "$_val" ] && export CLAUDE_TOOL_NAME="$_val"

        _val=$(echo "$_HOOK_INPUT" | jq -r '.tool_input.file_path // empty' 2>/dev/null)
        [ -n "$_val" ] && export CLAUDE_TOOL_INPUT_FILE_PATH="$_val"

        _val=$(echo "$_HOOK_INPUT" | jq -r '.tool_input.command // empty' 2>/dev/null)
        [ -n "$_val" ] && export CLAUDE_TOOL_INPUT_COMMAND="$_val"

        _val=$(echo "$_HOOK_INPUT" | jq -r '.tool_input.content // empty' 2>/dev/null)
        [ -n "$_val" ] && export CLAUDE_TOOL_INPUT_CONTENT="$_val"

        _val=$(echo "$_HOOK_INPUT" | jq -r '.tool_input.pattern // empty' 2>/dev/null)
        [ -n "$_val" ] && export CLAUDE_TOOL_INPUT_PATTERN="$_val"

        _val=$(echo "$_HOOK_INPUT" | jq -r '.tool_input.query // empty' 2>/dev/null)
        [ -n "$_val" ] && export CLAUDE_TOOL_INPUT_QUERY="$_val"

        _val=$(echo "$_HOOK_INPUT" | jq -r '.tool_input.skill // empty' 2>/dev/null)
        [ -n "$_val" ] && export CLAUDE_TOOL_INPUT_SKILL="$_val"

        _val=$(echo "$_HOOK_INPUT" | jq -r '.tool_input.old_string // empty' 2>/dev/null)
        [ -n "$_val" ] && export CLAUDE_TOOL_INPUT_OLD_STRING="$_val"

        _val=$(echo "$_HOOK_INPUT" | jq -r '.tool_input.new_string // empty' 2>/dev/null)
        [ -n "$_val" ] && export CLAUDE_TOOL_INPUT_NEW_STRING="$_val"

        _val=$(echo "$_HOOK_INPUT" | jq -r '.prompt // empty' 2>/dev/null)
        [ -n "$_val" ] && export CLAUDE_USER_PROMPT="$_val"

        _val=$(echo "$_HOOK_INPUT" | jq -r '.tool_response // empty' 2>/dev/null)
        [ -n "$_val" ] && export CLAUDE_TOOL_OUTPUT="$_val"

        _val=$(echo "$_HOOK_INPUT" | jq -r '.session_id // empty' 2>/dev/null)
        [ -n "$_val" ] && export CLAUDE_SESSION_ID="$_val"

        unset _val
    fi
    # If stdin was empty, existing env vars (legacy) are preserved as-is
fi
