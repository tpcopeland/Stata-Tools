"""Tests for MCP server configuration."""

import sys
from pathlib import Path

# Add server directory to path
SERVER_DIR = Path(__file__).parent.parent
sys.path.insert(0, str(SERVER_DIR))
sys.path.insert(0, str(SERVER_DIR / "tools"))


def test_server_imports():
    """Test that server module can be imported."""
    import server
    assert hasattr(server, 'mcp')


def test_tools_registered():
    """Test that expected tools exist as functions."""
    import server
    # Check that the decorated functions exist
    assert callable(server.get_stata_command)
    assert callable(server.search_stata_commands)
    assert callable(server.list_stata_commands)
    assert callable(server.get_snippet)
    assert callable(server.search_snippets)
    assert callable(server.list_snippet_categories)
    assert callable(server.validate_ado)
    assert callable(server.check_versions)


def test_tool_functions_return_json():
    """Test that tool functions return valid JSON strings."""
    import server
    import json

    # Test get_stata_command with non-existent command
    result = server.get_stata_command("nonexistent_xyz")
    parsed = json.loads(result)
    assert "error" in parsed

    # Test get_snippet with non-existent snippet
    result = server.get_snippet("nonexistent_xyz")
    parsed = json.loads(result)
    assert "error" in parsed

    # Test search returns array
    result = server.search_snippets("loop")
    parsed = json.loads(result)
    assert isinstance(parsed, list)


def test_commands_module():
    """Test that commands module works."""
    from commands import get_command, search_commands, list_commands
    assert callable(get_command)
    assert callable(search_commands)
    assert callable(list_commands)


def test_snippets_module():
    """Test that snippets module works."""
    from snippets import get_snippet, search_snippets, list_snippets
    assert callable(get_snippet)
    assert callable(search_snippets)
    assert callable(list_snippets)


if __name__ == "__main__":
    test_server_imports()
    test_tools_registered()
    test_tool_functions_return_json()
    test_commands_module()
    test_snippets_module()
    print("All server tests passed!")
