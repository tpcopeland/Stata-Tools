#!/bin/bash
# Entrypoint script for Stata-MCP Testing Environment

set -e

echo "=========================================="
echo "Stata-MCP Testing Environment"
echo "=========================================="
echo ""
echo "Available directories:"
echo "  - Stata-Tools:   $STATA_TOOLS_DIR"
echo "  - Stata-MCP:     $STATA_MCP_DIR"
echo "  - Test Output:   $TEST_OUTPUT_DIR"
echo ""
echo "=========================================="

# Check if Stata is available (via MCP)
if [ -n "$STATA_PATH" ]; then
    echo "Stata path configured: $STATA_PATH"
else
    echo "Note: STATA_PATH not set. Stata-MCP server should handle Stata execution."
fi

# Check if Stata-MCP is mounted
if [ -d "$STATA_MCP_DIR" ] && [ "$(ls -A $STATA_MCP_DIR 2>/dev/null)" ]; then
    echo "Stata-MCP directory is mounted and contains files."
else
    echo "Warning: Stata-MCP directory is empty or not mounted."
    echo "  Mount your Stata-MCP installation to: $STATA_MCP_DIR"
fi

# Check if Stata-Tools is mounted
if [ -d "$STATA_TOOLS_DIR" ] && [ "$(ls -A $STATA_TOOLS_DIR 2>/dev/null)" ]; then
    echo "Stata-Tools directory is mounted and contains files."
else
    echo "Warning: Stata-Tools directory is empty or not mounted."
    echo "  Mount your Stata-Tools repository to: $STATA_TOOLS_DIR"
fi

echo ""
echo "Starting container..."
echo ""

# Execute the command passed to docker run
exec "$@"
