#!/usr/bin/env python3
"""
Stata Command Library MCP Server

Provides fast, cached access to Stata-Tools command documentation,
code snippets, and validation tools.

Tools:
- get_stata_command(name) - Get command documentation
- search_commands(query) - Search commands by keyword
- list_commands(package) - List available commands
- get_snippet(name) - Get code snippet
- search_snippets(query) - Search snippets by keyword
- list_snippets(category) - List available snippets
- validate_ado(file_path) - Run validate-ado.sh and return results
- check_versions(package) - Run check-versions.sh and return results
"""

import json
import subprocess
from pathlib import Path
from typing import Optional

from mcp.server.fastmcp import FastMCP

# Initialize MCP server
mcp = FastMCP("stata-library")

# Paths
SCRIPT_DIR = Path(__file__).parent
TOOLS_DIR = SCRIPT_DIR / "tools"
REPO_ROOT = SCRIPT_DIR.parent.parent.parent

import sys
sys.path.insert(0, str(TOOLS_DIR))

from commands import get_command, search_commands as _search_commands, list_commands as _list_commands
from snippets import get_snippet as _get_snippet, search_snippets as _search_snippets, list_snippets as _list_snippets


@mcp.tool()
def get_stata_command(name: str) -> str:
    """Get documentation for a Stata-Tools command.

    Args:
        name: Command name (e.g., "tvexpose", "table1_tc")

    Returns:
        JSON string with command documentation including syntax, options, and stored results.
    """
    result = get_command(name)
    if result is None:
        return json.dumps({"error": f"Command '{name}' not found"})
    return json.dumps(result, indent=2)


@mcp.tool()
def search_stata_commands(query: str, limit: int = 10) -> str:
    """Search Stata-Tools commands by keyword.

    Args:
        query: Search term (e.g., "time-varying", "exposure", "merge")
        limit: Maximum number of results (default: 10)

    Returns:
        JSON array of matching commands with name, package, and purpose.
    """
    results = _search_commands(query, limit=limit)
    return json.dumps(results, indent=2)


@mcp.tool()
def list_stata_commands(package: Optional[str] = None) -> str:
    """List available Stata-Tools commands.

    Args:
        package: Filter by package name (optional, e.g., "tvtools", "tabtools")

    Returns:
        JSON array of commands with name, package, and brief purpose.
    """
    results = _list_commands(package=package)
    return json.dumps(results, indent=2)


@mcp.tool()
def get_snippet(name: str) -> str:
    """Get a Stata code snippet.

    Args:
        name: Snippet name (e.g., "marksample_basic", "foreach_varlist", "program_rclass")

    Returns:
        JSON with snippet name, purpose, and code.
    """
    result = _get_snippet(name)
    if result is None:
        return json.dumps({"error": f"Snippet '{name}' not found"})
    return json.dumps(result, indent=2)


@mcp.tool()
def search_snippets(query: str, limit: int = 5) -> str:
    """Search Stata code snippets by keyword.

    Args:
        query: Search term (e.g., "loop", "syntax", "tempvar")
        limit: Maximum results (default: 5)

    Returns:
        JSON array of matching snippets with name, purpose, and keywords.
    """
    results = _search_snippets(query, limit=limit)
    return json.dumps(results, indent=2)


@mcp.tool()
def list_snippet_categories(category: Optional[str] = None) -> str:
    """List available Stata code snippets.

    Args:
        category: Filter by keyword category (optional, e.g., "loop", "syntax", "error")

    Returns:
        JSON array of snippets with name, purpose, and keywords.
    """
    results = _list_snippets(category=category)
    return json.dumps(results, indent=2)


@mcp.tool()
def validate_ado(file_path: str) -> str:
    """Run static validation on a .ado file.

    Checks for common errors: missing version line, missing varabbrev off,
    long macro names, batch mode incompatible commands, etc.

    Args:
        file_path: Path to the .ado file to validate

    Returns:
        Validation output with any warnings or errors found.
    """
    validator = REPO_ROOT / ".claude" / "validators" / "validate-ado.sh"
    if not validator.exists():
        return json.dumps({"error": "validate-ado.sh not found"})

    try:
        result = subprocess.run(
            [str(validator), file_path],
            capture_output=True,
            text=True,
            timeout=30,
            cwd=str(REPO_ROOT)
        )
        return json.dumps({
            "exit_code": result.returncode,
            "output": result.stdout,
            "errors": result.stderr if result.stderr else None
        })
    except subprocess.TimeoutExpired:
        return json.dumps({"error": "Validation timed out after 30s"})
    except Exception as e:
        return json.dumps({"error": str(e)})


@mcp.tool()
def check_versions(package: Optional[str] = None) -> str:
    """Check version consistency across package files.

    Verifies that .ado, .sthlp, .pkg, and README.md versions match.

    Args:
        package: Package name to check (optional, checks all if omitted)

    Returns:
        Version check results with any mismatches found.
    """
    checker = REPO_ROOT / ".claude" / "scripts" / "check-versions.sh"
    if not checker.exists():
        return json.dumps({"error": "check-versions.sh not found"})

    cmd = [str(checker)]
    if package:
        cmd.append(package)

    try:
        result = subprocess.run(
            cmd,
            capture_output=True,
            text=True,
            timeout=30,
            cwd=str(REPO_ROOT)
        )
        return json.dumps({
            "exit_code": result.returncode,
            "output": result.stdout,
            "errors": result.stderr if result.stderr else None
        })
    except subprocess.TimeoutExpired:
        return json.dumps({"error": "Version check timed out after 30s"})
    except Exception as e:
        return json.dumps({"error": str(e)})


if __name__ == "__main__":
    mcp.run()
