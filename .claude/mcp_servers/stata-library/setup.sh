#!/bin/bash
# Setup script for Stata Library MCP Server
# Creates virtual environment and installs dependencies

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "Setting up Stata Library MCP Server..."

# Create virtual environment
if [ ! -d "$SCRIPT_DIR/.venv" ]; then
    echo "Creating virtual environment..."
    python3 -m venv "$SCRIPT_DIR/.venv"
fi

# Activate and install
echo "Installing dependencies..."
"$SCRIPT_DIR/.venv/bin/pip" install -q -r "$SCRIPT_DIR/requirements.txt"

echo ""
echo "Setup complete!"
echo ""
echo "To add to Claude Code settings, add this to mcpServers in settings.json:"
echo ""
echo '  "stata-library": {'
echo '    "command": "'"$SCRIPT_DIR"'/.venv/bin/python",'
echo '    "args": ["'"$SCRIPT_DIR"'/server.py"]'
echo '  }'
echo ""
echo "Or run directly:"
echo "  $SCRIPT_DIR/.venv/bin/python $SCRIPT_DIR/server.py"
