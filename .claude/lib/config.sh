#!/bin/bash
#
# config.sh - Centralized configuration for Stata-Tools automation
# Version: 1.0.0
#
# This file provides centralized configuration that can be overridden
# via environment variables.
#
# Usage: source "$(dirname "${BASH_SOURCE[0]}")/config.sh"
#
# Environment variables (override defaults):
#   STATA_EXEC       - Path to Stata executable
#   STATA_TIMEOUT    - Timeout for Stata commands (seconds)
#   DEFAULT_AUTHOR   - Default author for new packages
#   STATA_VERSION    - Default Stata version for code
#

# Require common.sh first
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [[ ! -f "$SCRIPT_DIR/common.sh" ]]; then
    echo "[ERROR] common.sh not found in $SCRIPT_DIR" >&2
    return 3 2>/dev/null || exit 3
fi
source "$SCRIPT_DIR/common.sh"

# Prevent multiple sourcing
[[ -n "$_CONFIG_SH_LOADED" ]] && return 0
_CONFIG_SH_LOADED=1
readonly _CONFIG_SH_VERSION="1.0.0"

# =============================================================================
# REPOSITORY PATHS
# =============================================================================

# Get repository root (readonly after set)
declare -r REPO_ROOT="$(get_repo_root)"
declare -r CLAUDE_DIR="$REPO_ROOT/.claude"
declare -r TEMPLATES_DIR="$REPO_ROOT/_templates"
declare -r TESTING_DIR="$REPO_ROOT/_testing"
declare -r VALIDATION_DIR="$REPO_ROOT/_validation"

# =============================================================================
# STATA CONFIGURATION
# =============================================================================

# Stata executable (can be overridden via env var)
declare -r STATA_EXEC="${STATA_EXEC:-stata-mp}"

# Timeout for Stata commands in seconds
declare -r STATA_TIMEOUT="${STATA_TIMEOUT:-60}"

# Default Stata version for generated code
declare -r STATA_VERSION="${STATA_VERSION:-18.0}"

# =============================================================================
# AUTHOR CONFIGURATION
# =============================================================================

# Default author for new packages
declare -r DEFAULT_AUTHOR="${DEFAULT_AUTHOR:-Timothy P Copeland}"

# Default institution
declare -r DEFAULT_INSTITUTION="${DEFAULT_INSTITUTION:-Department of Clinical Neuroscience, Karolinska Institutet}"

# =============================================================================
# SCRIPT CONFIGURATION
# =============================================================================

# Enable debug output (set DEBUG=1 to enable)
declare -r DEBUG="${DEBUG:-0}"

# Enable strict mode in scripts (set STRICT_MODE=0 to disable)
declare -r STRICT_MODE="${STRICT_MODE:-1}"

# =============================================================================
# VALIDATION FUNCTIONS
# =============================================================================

# Validate that Stata is available
check_stata_available() {
    if ! command -v "$STATA_EXEC" &>/dev/null; then
        warn "Stata not found ($STATA_EXEC)"
        info "Set STATA_EXEC environment variable to Stata path"
        return 1
    fi
    return 0
}

# Validate repository structure
check_repo_structure() {
    local missing=0

    for dir in "$TEMPLATES_DIR" "$TESTING_DIR" "$VALIDATION_DIR"; do
        if [[ ! -d "$dir" ]]; then
            warn "Directory not found: $dir"
            missing=$((missing + 1))
        fi
    done

    return $missing
}

# =============================================================================
# UTILITY FUNCTIONS
# =============================================================================

# Get script version from header
get_script_version() {
    local script="$1"
    if [[ -f "$script" ]]; then
        grep -m1 'Version:' "$script" 2>/dev/null | sed 's/.*Version:[[:space:]]*//' || echo "unknown"
    else
        echo "unknown"
    fi
}

# Print configuration summary
print_config() {
    echo "Configuration Summary"
    echo "====================="
    echo "REPO_ROOT:      $REPO_ROOT"
    echo "STATA_EXEC:     $STATA_EXEC"
    echo "STATA_TIMEOUT:  ${STATA_TIMEOUT}s"
    echo "STATA_VERSION:  $STATA_VERSION"
    echo "DEFAULT_AUTHOR: $DEFAULT_AUTHOR"
    echo "DEBUG:          $DEBUG"
    echo "STRICT_MODE:    $STRICT_MODE"
    echo ""
}
