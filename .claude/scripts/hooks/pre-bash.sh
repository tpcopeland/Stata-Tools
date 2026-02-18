#!/bin/bash
# .claude/scripts/hooks/pre-bash.sh
# PreToolUse hook for Bash tool - validates commands
# Matcher: Bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Source shared utilities
source "$SCRIPT_DIR/_read-hook-input.sh"
source "$SCRIPT_DIR/_output-helpers.sh"
source "$SCRIPT_DIR/error_handling.sh"

# Run general validation (dangerous ops, protected files, stata-mp check)
source "$SCRIPT_DIR/validate-operation.sh"
