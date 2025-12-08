#!/bin/bash
set -e

STATA_DIR="/usr/local/stata17"

echo "=========================================="
echo "  Stata Linux Docker Environment"
echo "=========================================="

# Check if Stata directory is mounted and has content
if [ ! -d "$STATA_DIR" ] || [ -z "$(ls -A $STATA_DIR 2>/dev/null)" ]; then
    echo "✗ Stata directory not mounted or empty"
    echo ""
    echo "  The STATA_PATH in your .env file should point to a directory"
    echo "  containing your extracted Stata Linux files."
    echo ""
    echo "  To set up Stata Linux:"
    echo "  1. Download Stata for Linux from stata.com/customer-service/"
    echo "  2. Extract: tar -xzf Stata17Linux64.tar.gz -C ~/stata17-linux"
    echo "  3. Set STATA_PATH=~/stata17-linux in your .env file"
    echo ""
else
    # Check for Stata executables
    STATA_EXEC=""
    if [ -f "$STATA_DIR/stata-mp" ]; then
        echo "✓ Stata MP found"
        STATA_EXEC="stata-mp"
        chmod +x "$STATA_DIR/stata-mp" 2>/dev/null || true
    elif [ -f "$STATA_DIR/stata-se" ]; then
        echo "✓ Stata SE found"
        STATA_EXEC="stata-se"
        chmod +x "$STATA_DIR/stata-se" 2>/dev/null || true
    elif [ -f "$STATA_DIR/stata" ]; then
        echo "✓ Stata BE found"
        STATA_EXEC="stata"
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

    # Check for license - look for stata.lic or check if stinit was run
    if [ -f "$STATA_DIR/stata.lic" ]; then
        echo "✓ Stata license found"
    elif [ -f "$STATA_DIR/stinit" ]; then
        echo "⚠ License not initialized"
        echo ""
        echo "  Run the license initialization inside this container:"
        echo "    cd /usr/local/stata17"
        echo "    ./stinit"
        echo ""
        echo "  You'll need your:"
        echo "    - Serial number"
        echo "    - Code (authorization code)"
        echo "    - License info from your Stata purchase email"
        echo ""
        echo "  Find license info: stata.com/customer-service/ or"
        echo "  macOS Stata: Help > About Stata"
        echo ""
    else
        echo "✗ No license file or stinit found"
        echo ""
        echo "  Your Stata installation appears incomplete."
        echo "  Re-extract the Stata Linux tarball."
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
if [ -n "$STATA_EXEC" ]; then
    echo "Run Stata with: $STATA_EXEC"
else
    echo "Run Stata with: stata-mp (or stata-se, stata)"
fi
echo ""

exec "$@"
