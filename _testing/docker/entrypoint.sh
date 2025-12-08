#!/bin/bash
set -e

echo "=========================================="
echo "  Stata Linux Docker Environment"
echo "=========================================="

# Check for Stata installation
if [ -f "/usr/local/stata18/stata-mp" ]; then
    echo "✓ Stata MP found"
elif [ -f "/usr/local/stata18/stata-se" ]; then
    echo "✓ Stata SE found"
elif [ -f "/usr/local/stata18/stata" ]; then
    echo "✓ Stata BE found"
else
    echo "✗ Stata not found in /usr/local/stata18"
    echo ""
    echo "Check that STATA_PATH in .env points to your Stata Linux installation"
fi

# Check for license
if [ -f "/usr/local/stata18/stata.lic" ]; then
    echo "✓ Stata license found"
else
    echo "✗ License file not found"
    echo "  Create stata.lic in your Stata Linux directory"
fi

# Check workspace
if [ -d "/workspace" ] && [ "$(ls -A /workspace 2>/dev/null)" ]; then
    echo "✓ Workspace mounted"
else
    echo "○ Workspace empty"
fi

echo ""
echo "=========================================="

exec "$@"
