#!/bin/bash
set -e

echo "=========================================="
echo "  Stata-MCP Full Sandbox Environment"
echo "=========================================="

# Check for Stata installation
if [ -f "/usr/local/stata17/stata-mp" ]; then
    echo "✓ Stata MP found"
    STATA_BIN="/usr/local/stata17/stata-mp"
elif [ -f "/usr/local/stata17/stata-se" ]; then
    echo "✓ Stata SE found"
    STATA_BIN="/usr/local/stata17/stata-se"
elif [ -f "/usr/local/stata17/stata" ]; then
    echo "✓ Stata found"
    STATA_BIN="/usr/local/stata17/stata"
else
    echo "✗ Stata not found in /usr/local/stata17"
    echo ""
    echo "Please mount your Stata installation:"
    echo "  -v /path/to/stata17:/usr/local/stata17"
    echo ""
    echo "Or copy Stata files into the container"
    echo ""
fi

# Check for license
if [ -f "/usr/local/stata17/stata.lic" ]; then
    echo "✓ Stata license found"
else
    echo "✗ License file not found"
    echo "  Expected: /usr/local/stata17/stata.lic"
fi

# Check Stata-MCP
if [ -d "/opt/stata-mcp" ] && [ "$(ls -A /opt/stata-mcp 2>/dev/null)" ]; then
    echo "✓ Stata-MCP directory mounted"
else
    echo "○ Stata-MCP not mounted (optional)"
fi

# Check workspace
if [ -d "/workspace/Stata-Tools" ] && [ "$(ls -A /workspace/Stata-Tools 2>/dev/null)" ]; then
    echo "✓ Stata-Tools mounted"
else
    echo "✗ Stata-Tools not mounted"
fi

echo ""
echo "Directories:"
echo "  Workspace:    /workspace/Stata-Tools"
echo "  Output:       /workspace/output"
echo "  Stata:        /usr/local/stata17"
echo ""
echo "=========================================="

# Execute the command
exec "$@"
