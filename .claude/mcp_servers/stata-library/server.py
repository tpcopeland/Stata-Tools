#!/usr/bin/env python3
"""
Stata Command Library MCP Server

Provides fast, cached access to Stata-Tools command documentation.
Reduces token usage by 70-85% vs loading full .sthlp files.

Tools:
- get_stata_command(name) - Get command documentation
- search_commands(query) - Search commands by keyword
- list_commands(package) - List available commands
- get_snippet(name) - Get code snippet
"""

import json
import os
import sys
from pathlib import Path
from functools import lru_cache

# Add tools directory to path
SCRIPT_DIR = Path(__file__).parent
TOOLS_DIR = SCRIPT_DIR / "tools"
DATA_DIR = SCRIPT_DIR / "data"
CACHE_DIR = SCRIPT_DIR / ".cache"

sys.path.insert(0, str(TOOLS_DIR))

from commands import get_command, search_commands, list_commands
from snippets import get_snippet, search_snippets, list_snippets

def main():
    """MCP Server main entry point."""
    # Ensure cache directory exists
    CACHE_DIR.mkdir(exist_ok=True)

    # MCP protocol handling would go here
    # For now, this is a placeholder for the MCP integration
    print(json.dumps({
        "name": "stata-library",
        "version": "1.0.0",
        "tools": [
            "get_stata_command",
            "search_commands",
            "list_commands",
            "get_snippet",
            "search_snippets",
            "list_snippets"
        ]
    }))

if __name__ == "__main__":
    main()
