#!/bin/bash
# .claude/scripts/hooks/post-bash.sh
# PostToolUse hook for Bash - Stata error detection
# Matcher: Bash

set +e  # Prevent inherited error settings from causing hook errors

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Source shared utilities
source "$SCRIPT_DIR/_read-hook-input.sh"
source "$SCRIPT_DIR/_output-helpers.sh"
source "$SCRIPT_DIR/error_handling.sh"

# Stata error detection
source "$SCRIPT_DIR/stata-error-detector.sh"
