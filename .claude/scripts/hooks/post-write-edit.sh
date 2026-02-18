#!/bin/bash
# .claude/scripts/hooks/post-write-edit.sh
# PostToolUse hook for Write|Edit - auto-validate .ado files, format markdown, version check
# Matcher: Write|Edit

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Source shared utilities
source "$SCRIPT_DIR/_read-hook-input.sh"
source "$SCRIPT_DIR/_output-helpers.sh"
source "$SCRIPT_DIR/error_handling.sh"

# Get repo root dynamically
REPO_ROOT=$(git rev-parse --show-toplevel 2>/dev/null)
[ -z "$REPO_ROOT" ] && REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

FILE_PATH="$CLAUDE_TOOL_INPUT_FILE_PATH"

# Exit early if no file path or file doesn't exist
[ -z "$FILE_PATH" ] && exit 0
[ ! -f "$FILE_PATH" ] && exit 0

# === STEP 1: Format markdown (silent, fast) ===
if [[ "$FILE_PATH" == *.md ]]; then
    # Remove Windows-style line endings
    sed -i 's/\r$//' "$FILE_PATH" 2>/dev/null

    # Ensure file ends with exactly one newline
    if [ -s "$FILE_PATH" ]; then
        if [ "$(tail -c 1 "$FILE_PATH" | wc -l)" -eq 0 ]; then
            echo "" >> "$FILE_PATH"
        fi
    fi
fi

# === STEP 2: Auto-validate .ado files ===
if [[ "$FILE_PATH" == *.ado && -f "$FILE_PATH" ]]; then
    VALIDATOR="$REPO_ROOT/.claude/validators/validate-ado.sh"
    if [ -x "$VALIDATOR" ]; then
        echo ""
        echo "[Auto-Validate] Running validate-ado.sh on $(basename "$FILE_PATH")..."
        "$VALIDATOR" "$FILE_PATH" 2>&1 | head -20
    fi

    # Check version consistency for the package
    PKG_DIR=$(dirname "$FILE_PATH")
    PKG_NAME=$(basename "$PKG_DIR")
    VERSION_CHECKER="$REPO_ROOT/.claude/scripts/check-versions.sh"
    if [ -x "$VERSION_CHECKER" ] && [ -d "$PKG_DIR" ]; then
        echo ""
        echo "[Version Check] Checking $PKG_NAME..."
        "$VERSION_CHECKER" "$PKG_NAME" 2>&1 | tail -5
    fi
fi

# === STEP 3: Warn about .pkg modifications ===
if [[ "$FILE_PATH" == *.pkg ]]; then
    echo ""
    echo "🏷️  Package file updated: $(basename "$FILE_PATH")"
    echo "   Ensure Distribution-Date is current and stata.toc is updated"
fi

# === STEP 4: CLAUDE.md sync reminder ===
if [[ "$FILE_PATH" == *"CLAUDE.md"* ]]; then
    echo ""
    echo "📝 CLAUDE.md updated - verify skill references and policy links"
fi

exit 0
