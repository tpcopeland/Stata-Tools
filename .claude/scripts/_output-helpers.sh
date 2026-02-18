#!/bin/bash
# .claude/scripts/_output-helpers.sh
# Shared output formatting functions for hooks
# Source this file from other hooks: source "$(dirname "$0")/_output-helpers.sh"

# Standard icons for Stata package development
ICON_PKG="📦"
ICON_TEST="🧪"
ICON_SKILL="📋"
ICON_WRITE="📝"
ICON_WARN="⚠️"
ICON_ERROR="🚨"
ICON_SUCCESS="✓"
ICON_TARGET="🎯"
ICON_CODE="💻"
ICON_VERSION="🏷️"

# Compact single-line notification
# Usage: notify "icon" "message"
notify() {
    local icon="$1"
    local message="$2"
    echo "$icon $message"
}

# Multi-line info block (compact format)
# Usage: info_block "title" "line1" "line2" ...
info_block() {
    local title="$1"
    shift
    echo ""
    echo "$title"
    for line in "$@"; do
        echo "   $line"
    done
    echo ""
}

# XML-style structured tag for Claude parsing
# Usage: structured_tag "tag-name" "attr1=\"val1\"" "attr2=\"val2\""
structured_tag() {
    local tag="$1"
    shift
    local attrs=""
    for attr in "$@"; do
        attrs="$attrs $attr"
    done
    echo "<$tag$attrs/>"
}

# Skill routing notification
# Usage: skill_routing "skill-name" "reason"
skill_routing() {
    local skill="$1"
    local reason="$2"
    echo ""
    echo "$ICON_TARGET Skill routing: $skill"
    echo "   Detected: $reason"
    echo ""
    structured_tag "skill-routing" "skill=\"$skill\"" "reason=\"$reason\""
}

# Error notification
# Usage: error_notify "error_type" "message" "package_name"
error_notify() {
    local error_type="$1"
    local message="$2"
    local package="${3:-unknown}"
    echo ""
    echo "$ICON_ERROR $error_type"
    echo "   Message: $message"
    echo "   Package: $package"
    echo ""
}
