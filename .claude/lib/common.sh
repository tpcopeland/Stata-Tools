#!/bin/bash
#
# common.sh - Shared functions for Stata-Tools automation scripts
#
# This library provides standardized functions for:
#   - Color-coded output
#   - Error handling and reporting
#   - Path resolution
#   - Cleanup on exit
#
# Usage: source "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"
#
# Exit codes (standardized across all scripts):
#   0 - Success / all checks passed
#   1 - Errors found / operation failed
#   2 - Warnings found (but no errors)
#   3 - Configuration error / missing requirements
#

# Prevent multiple sourcing
[[ -n "$_COMMON_SH_LOADED" ]] && return 0
_COMMON_SH_LOADED=1

# =============================================================================
# COLOR DEFINITIONS
# =============================================================================

# Check if stdout is a terminal for color support
if [[ -t 1 ]]; then
    RED='\033[0;31m'
    GREEN='\033[0;32m'
    YELLOW='\033[1;33m'
    BLUE='\033[0;34m'
    CYAN='\033[0;36m'
    BOLD='\033[1m'
    NC='\033[0m'  # No Color
else
    RED=''
    GREEN=''
    YELLOW=''
    BLUE=''
    CYAN=''
    BOLD=''
    NC=''
fi

# =============================================================================
# OUTPUT FUNCTIONS
# =============================================================================

# Error message (red) - increments ERRORS counter if defined
error() {
    echo -e "${RED}[ERROR]${NC} $1" >&2
    [[ -n "$ERRORS" ]] && ERRORS=$((ERRORS + 1))
}

# Warning message (yellow) - increments WARNINGS counter if defined
warn() {
    echo -e "${YELLOW}[WARN]${NC} $1" >&2
    [[ -n "$WARNINGS" ]] && WARNINGS=$((WARNINGS + 1))
}

# Success/pass message (green)
pass() {
    echo -e "${GREEN}[OK]${NC} $1"
}

# Info message (blue)
info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

# Debug message (cyan) - only shown if DEBUG=1
debug() {
    [[ "$DEBUG" == "1" ]] && echo -e "${CYAN}[DEBUG]${NC} $1" >&2
}

# Section header (bold)
header() {
    echo -e "\n${BOLD}$1${NC}"
    echo "$(echo "$1" | sed 's/./-/g')"
}

# =============================================================================
# PATH FUNCTIONS
# =============================================================================

# Get the repository root directory
# Falls back to current directory if not in a git repo
get_repo_root() {
    git rev-parse --show-toplevel 2>/dev/null || pwd
}

# Get the directory containing the calling script
get_script_dir() {
    cd "$(dirname "${BASH_SOURCE[1]}")" && pwd
}

# Resolve a path relative to repo root
resolve_path() {
    local path="$1"
    local repo_root
    repo_root=$(get_repo_root)

    if [[ "$path" == /* ]]; then
        echo "$path"
    else
        echo "$repo_root/$path"
    fi
}

# =============================================================================
# VALIDATION FUNCTIONS
# =============================================================================

# Check if a command exists
require_command() {
    local cmd="$1"
    local msg="${2:-Required command '$cmd' not found}"

    if ! command -v "$cmd" &>/dev/null; then
        error "$msg"
        return 1
    fi
    return 0
}

# Check if a file exists and is readable
require_file() {
    local file="$1"
    local msg="${2:-Required file '$file' not found}"

    if [[ ! -r "$file" ]]; then
        error "$msg"
        return 1
    fi
    return 0
}

# Check if a directory exists
require_dir() {
    local dir="$1"
    local msg="${2:-Required directory '$dir' not found}"

    if [[ ! -d "$dir" ]]; then
        error "$msg"
        return 1
    fi
    return 0
}

# =============================================================================
# CLEANUP FUNCTIONS
# =============================================================================

# Array to hold cleanup tasks
_CLEANUP_TASKS=()

# Register a cleanup task (file or directory to remove)
register_cleanup() {
    _CLEANUP_TASKS+=("$1")
}

# Execute all registered cleanup tasks
run_cleanup() {
    local item
    for item in "${_CLEANUP_TASKS[@]}"; do
        if [[ -e "$item" ]]; then
            rm -rf "$item" 2>/dev/null
            debug "Cleaned up: $item"
        fi
    done
}

# Setup trap for cleanup on exit (call this after registering cleanup tasks)
setup_cleanup_trap() {
    trap run_cleanup EXIT INT TERM
}

# =============================================================================
# TEMP FILE FUNCTIONS
# =============================================================================

# Create a temporary file and register it for cleanup
# Usage: TEMP_FILE=$(make_temp_file "prefix")
make_temp_file() {
    local prefix="${1:-temp}"
    local temp_file

    temp_file=$(mktemp "/tmp/${prefix}_XXXXXX") || {
        error "Failed to create temporary file"
        return 1
    }

    register_cleanup "$temp_file"
    echo "$temp_file"
}

# Create a temporary directory and register it for cleanup
# Usage: TEMP_DIR=$(make_temp_dir "prefix")
make_temp_dir() {
    local prefix="${1:-temp}"
    local temp_dir

    temp_dir=$(mktemp -d "/tmp/${prefix}_XXXXXX") || {
        error "Failed to create temporary directory"
        return 1
    }

    register_cleanup "$temp_dir"
    echo "$temp_dir"
}

# =============================================================================
# COUNTER INITIALIZATION
# =============================================================================

# Initialize standard counters (call at script start if needed)
init_counters() {
    ERRORS=0
    WARNINGS=0
}

# Return appropriate exit code based on counters
get_exit_code() {
    if [[ $ERRORS -gt 0 ]]; then
        echo 1
    elif [[ $WARNINGS -gt 0 ]]; then
        echo 2
    else
        echo 0
    fi
}

# Print summary and return exit code
print_summary() {
    local label="${1:-Check}"

    echo ""
    echo "================================"
    if [[ $ERRORS -gt 0 ]]; then
        echo -e "${RED}FAILED${NC}: $ERRORS error(s), $WARNINGS warning(s)"
    elif [[ $WARNINGS -gt 0 ]]; then
        echo -e "${YELLOW}PASSED WITH WARNINGS${NC}: $WARNINGS warning(s)"
    else
        echo -e "${GREEN}PASSED${NC}: All checks passed"
    fi

    return $(get_exit_code)
}

# =============================================================================
# SEMANTIC VERSION FUNCTIONS
# =============================================================================

# Validate semantic version format (X.Y.Z)
is_valid_semver() {
    local version="$1"
    [[ "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]
}

# Compare two semantic versions
# Returns: 0 if equal, 1 if v1 > v2, 2 if v1 < v2
compare_semver() {
    local v1="$1"
    local v2="$2"

    if [[ "$v1" == "$v2" ]]; then
        return 0
    fi

    local IFS='.'
    local -a ver1=($v1) ver2=($v2)

    for i in 0 1 2; do
        if [[ ${ver1[$i]:-0} -gt ${ver2[$i]:-0} ]]; then
            return 1
        elif [[ ${ver1[$i]:-0} -lt ${ver2[$i]:-0} ]]; then
            return 2
        fi
    done

    return 0
}

# =============================================================================
# PLATFORM DETECTION
# =============================================================================

# Detect if running on macOS
is_macos() {
    [[ "$(uname -s)" == "Darwin" ]]
}

# Detect if running on Linux
is_linux() {
    [[ "$(uname -s)" == "Linux" ]]
}

# Cross-platform sed in-place edit
# Usage: sed_inplace 's/old/new/' file
sed_inplace() {
    local expression="$1"
    local file="$2"

    if is_macos; then
        sed -i '' "$expression" "$file"
    else
        sed -i "$expression" "$file"
    fi
}
