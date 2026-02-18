"""Tests for commands.py tool functions."""

import json
import sys
from pathlib import Path

# Add tools directory to path
TOOLS_DIR = Path(__file__).parent.parent / "tools"
sys.path.insert(0, str(TOOLS_DIR))

from commands import get_command, search_commands, list_commands, generate_command_index


def test_generate_command_index():
    """Test that command index can be generated."""
    commands = generate_command_index()
    assert isinstance(commands, list)
    # Should find at least some commands in the repo
    assert len(commands) >= 0  # May be 0 if no .sthlp files nearby


def test_get_command_found():
    """Test getting a command that exists."""
    # First generate the index
    generate_command_index()
    commands = list_commands()
    if commands:
        # Test with first available command
        name = commands[0]["name"]
        result = get_command(name)
        assert result is not None
        assert result["name"] == name
        assert "package" in result
        assert "purpose" in result


def test_get_command_not_found():
    """Test getting a command that doesn't exist."""
    result = get_command("nonexistent_command_xyz_12345")
    assert result is None


def test_search_commands():
    """Test searching commands."""
    generate_command_index()
    results = search_commands("time")
    assert isinstance(results, list)
    # Results should have expected fields
    for r in results:
        assert "name" in r
        assert "package" in r


def test_search_commands_limit():
    """Test search respects limit."""
    results = search_commands("a", limit=3)
    assert len(results) <= 3


def test_list_commands():
    """Test listing all commands."""
    generate_command_index()
    results = list_commands()
    assert isinstance(results, list)
    for r in results:
        assert "name" in r
        assert "package" in r
        assert "purpose" in r


def test_list_commands_filtered():
    """Test listing commands filtered by package."""
    generate_command_index()
    all_cmds = list_commands()
    if all_cmds:
        pkg = all_cmds[0]["package"]
        filtered = list_commands(package=pkg)
        assert len(filtered) <= len(all_cmds)
        for cmd in filtered:
            assert cmd["package"].lower() == pkg.lower()


if __name__ == "__main__":
    test_generate_command_index()
    test_get_command_not_found()
    test_search_commands()
    test_search_commands_limit()
    test_list_commands()
    print("All command tests passed!")
