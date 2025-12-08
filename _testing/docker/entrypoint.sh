#!/bin/bash
set -e

STATA_DIR="/usr/local/stata"

echo "=========================================="
echo "  Stata Linux Docker Environment"
echo "=========================================="

# Check if Stata directory is mounted and has content
if [ ! -d "$STATA_DIR" ] || [ -z "$(ls -A $STATA_DIR 2>/dev/null)" ]; then
    echo "✗ Stata directory not mounted or empty"
    echo ""
    echo "  The STATA_PATH in your .env file should point to a directory"
    echo "  containing your Stata Linux installation files."
    echo ""
    echo "  Expected contents: stata-mp (or stata-se/stata), ado/, etc."
    echo ""
    echo "  Common issues:"
    echo "  1. STATA_PATH points to wrong directory"
    echo "  2. Stata Linux not extracted yet"
    echo "  3. Using macOS Stata instead of Linux Stata"
    echo ""
else
    # Check for Stata executables
    if [ -f "$STATA_DIR/stata-mp" ]; then
        echo "✓ Stata MP found"
        chmod +x "$STATA_DIR/stata-mp" 2>/dev/null || true
    elif [ -f "$STATA_DIR/stata-se" ]; then
        echo "✓ Stata SE found"
        chmod +x "$STATA_DIR/stata-se" 2>/dev/null || true
    elif [ -f "$STATA_DIR/stata" ]; then
        echo "✓ Stata BE found"
        chmod +x "$STATA_DIR/stata" 2>/dev/null || true
    else
        echo "✗ No Stata executable found in $STATA_DIR"
        echo ""
        echo "  Directory contents:"
        ls -la "$STATA_DIR" 2>/dev/null | head -20 || echo "  (unable to list)"
        echo ""
        echo "  Expected: stata-mp, stata-se, or stata"
        echo ""
        echo "  If you see .app files, you have macOS Stata."
        echo "  Download Stata for Linux from stata.com/customer-service/"
        echo ""
    fi

    # Check for license
    if [ -f "$STATA_DIR/stata.lic" ]; then
        echo "✓ Stata license found"
    else
        echo "✗ License file not found"
        echo ""
        echo "  Create stata.lic in your Stata Linux directory with:"
        echo "    Your Name"
        echo "    Your Institution"
        echo "    Serial Number"
        echo "    Authorization Code"
        echo "    License Lines..."
        echo ""
        echo "  Find your license info in Stata: Help > About Stata"
        echo ""
    fi
fi

# Check workspace
if [ -d "/workspace" ] && [ "$(ls -A /workspace 2>/dev/null)" ]; then
    echo "✓ Workspace mounted"
else
    echo "○ Workspace empty or not mounted"
fi

echo ""
echo "=========================================="
echo ""
echo "Run Stata with: stata-mp (or stata-se, stata)"
echo ""

exec "$@"
