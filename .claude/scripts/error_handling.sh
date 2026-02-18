#!/bin/bash
# .claude/scripts/error_handling.sh
# Unified Error Handling for Hook Scripts
# Provides consistent error reporting, logging, and recovery

# === CONFIGURATION ===
ERROR_LOG_DIR="${ERROR_LOG_DIR:-/home/tpcopeland/Stata-Tools/.claude/logs}"
ERROR_LOG_FILE="${ERROR_LOG_DIR}/hook_errors.log"
MAX_LOG_SIZE=10485760  # 10MB

# === COLORS ===
ERR_RED='\033[0;31m'
ERR_YELLOW='\033[0;33m'
ERR_GREEN='\033[0;32m'
ERR_CYAN='\033[0;36m'
ERR_RESET='\033[0m'

# === INITIALIZATION ===
init_error_handling() {
    # Ensure log directory exists
    mkdir -p "$ERROR_LOG_DIR" 2>/dev/null

    # Rotate log if too large
    if [ -f "$ERROR_LOG_FILE" ] && [ "$(stat -c%s "$ERROR_LOG_FILE" 2>/dev/null || stat -f%z "$ERROR_LOG_FILE" 2>/dev/null || echo 0)" -gt "$MAX_LOG_SIZE" ]; then
        mv "$ERROR_LOG_FILE" "${ERROR_LOG_FILE}.old"
    fi
}

# === LOGGING ===
log_error() {
    local level="$1"
    local source="$2"
    local message="$3"
    local timestamp
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')

    # Log to file
    echo "[$timestamp] [$level] [$source] $message" >> "$ERROR_LOG_FILE" 2>/dev/null

    # Output to stderr based on level
    case "$level" in
        ERROR)
            echo -e "${ERR_RED}[$source] ERROR: $message${ERR_RESET}" >&2
            ;;
        WARN)
            echo -e "${ERR_YELLOW}[$source] WARNING: $message${ERR_RESET}" >&2
            ;;
        INFO)
            echo -e "${ERR_CYAN}[$source] INFO: $message${ERR_RESET}" >&2
            ;;
    esac
}

# === ERROR HANDLERS ===

# Handle tool validation errors
handle_validation_error() {
    local tool="$1"
    local reason="$2"
    log_error "ERROR" "validation" "Tool '$tool' blocked: $reason"
    echo "BLOCKED: $reason"
    exit 2  # Signal blocked to Claude
}

# Handle file operation errors
handle_file_error() {
    local operation="$1"
    local path="$2"
    local reason="$3"
    log_error "ERROR" "file_op" "Failed to $operation '$path': $reason"
    return 1
}

# Handle external tool errors (stata, etc.)
handle_external_tool_error() {
    local tool="$1"
    local exit_code="$2"
    local output="$3"

    case "$exit_code" in
        124)
            log_error "WARN" "$tool" "Timeout after configured duration"
            echo "TIMEOUT"
            return 124
            ;;
        127)
            log_error "ERROR" "$tool" "Command not found"
            echo "NOT_INSTALLED"
            return 127
            ;;
    esac

    log_error "ERROR" "$tool" "Unknown error (exit code: $exit_code)"
    echo "UNKNOWN_ERROR"
    return "$exit_code"
}

# === RECOVERY ===

# Attempt graceful recovery from common errors
attempt_recovery() {
    local error_type="$1"

    case "$error_type" in
        TIMEOUT)
            log_error "INFO" "recovery" "Timeout recovery: Returning partial results if available"
            return 0
            ;;
        NOT_INSTALLED)
            log_error "ERROR" "recovery" "Cannot recover: Required tool not installed"
            return 1
            ;;
        *)
            log_error "WARN" "recovery" "No recovery strategy for: $error_type"
            return 1
            ;;
    esac
}

# === CLEANUP ===

# Register cleanup handler
register_cleanup() {
    local cleanup_func="$1"
    trap "$cleanup_func" EXIT INT TERM
}

# Standard cleanup function
standard_cleanup() {
    rm -f /tmp/hook_*.tmp 2>/dev/null
}

# === VALIDATION HELPERS ===

# Validate file path is safe
validate_path() {
    local path="$1"
    local operation="$2"

    # Check for path traversal attempts
    if echo "$path" | grep -q '\.\.'; then
        handle_validation_error "$operation" "Path traversal detected: $path"
    fi

    # Check for sensitive files
    local sensitive_patterns=(".env" "credentials" "secrets" ".ssh" ".gnupg")
    for pattern in "${sensitive_patterns[@]}"; do
        if echo "$path" | grep -qi "$pattern"; then
            handle_validation_error "$operation" "Sensitive file access blocked: $path"
        fi
    done

    return 0
}

# Validate command is safe
validate_command() {
    local command="$1"

    # Block dangerous commands
    local dangerous=("rm -rf /" "mkfs" "dd if=" ":(){:|:&};:" "chmod -R 777 /" "chown -R")
    for pattern in "${dangerous[@]}"; do
        if echo "$command" | grep -qi "$pattern"; then
            handle_validation_error "Bash" "Dangerous command blocked: $command"
        fi
    done

    return 0
}

# Initialize on source
init_error_handling
