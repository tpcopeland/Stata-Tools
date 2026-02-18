#!/bin/bash
# .claude/scripts/hooks/pre-write-edit.sh
# PreToolUse hook for Write|Edit tools - validates file operations
# Matcher: Write|Edit

set +e  # Prevent inherited error settings from causing hook errors

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Source shared utilities
source "$SCRIPT_DIR/_read-hook-input.sh"
source "$SCRIPT_DIR/_output-helpers.sh"
source "$SCRIPT_DIR/error_handling.sh"

# Run validation for write operations (protected files, .pkg warnings)
source "$SCRIPT_DIR/validate-operation.sh"
