"""Tests for MCP server configuration."""

import asyncio
import json
import sys
from pathlib import Path

# Add server directory to path
SERVER_DIR = Path(__file__).parent.parent
sys.path.insert(0, str(SERVER_DIR))
sys.path.insert(0, str(SERVER_DIR / "tools"))


def test_server_imports():
    """Test that server module can be imported."""
    import server
    assert hasattr(server, 'server')


def test_tool_handlers_exist():
    """Test that tool handler functions are defined."""
    import server
    assert callable(server.handle_list_tools)
    assert callable(server.handle_call_tool)


def test_resource_handlers_exist():
    """Test that resource handler functions are defined."""
    import server
    assert callable(server.handle_list_resources)
    assert callable(server.handle_read_resource)


def test_prompt_handlers_exist():
    """Test that prompt handler functions are defined."""
    import server
    assert callable(server.handle_list_prompts)
    assert callable(server.handle_get_prompt)


def test_list_tools():
    """Test that list_tools returns expected tool definitions."""
    import server
    tools = asyncio.run(server.handle_list_tools())
    tool_names = {t.name for t in tools}
    assert "stata_lib" in tool_names
    assert "validate" in tool_names
    assert "extended_tool" in tool_names
    assert len(tools) == 3


def test_tool_annotations():
    """Test that all tools have annotations."""
    import server
    tools = asyncio.run(server.handle_list_tools())
    for tool in tools:
        assert tool.annotations is not None
        assert tool.annotations.readOnlyHint is True


def test_stata_lib_command():
    """Test stata_lib with a command lookup."""
    import server
    result = asyncio.run(server.handle_call_tool("stata_lib", {"command": "nonexistent_xyz"}))
    parsed = json.loads(result[0].text)
    assert "error" in parsed


def test_stata_lib_snippet():
    """Test stata_lib with a snippet lookup."""
    import server
    result = asyncio.run(server.handle_call_tool("stata_lib", {"snippet": "nonexistent_xyz"}))
    parsed = json.loads(result[0].text)
    assert "error" in parsed


def test_stata_lib_query():
    """Test stata_lib with a search query."""
    import server
    result = asyncio.run(server.handle_call_tool("stata_lib", {"query": "loop"}))
    parsed = json.loads(result[0].text)
    assert "commands" in parsed
    assert "snippets" in parsed
    assert "pitfalls" in parsed


def test_validate_code():
    """Test validate with a code string."""
    import server
    code = '''program define test, rclass
    syntax varlist [if] [in]
end'''
    result = asyncio.run(server.handle_call_tool("validate", {"code": code}))
    parsed = json.loads(result[0].text)
    assert "issues" in parsed
    assert "summary" in parsed
    assert "clean" in parsed


def test_validate_pattern_info():
    """Test validate with pattern info request."""
    import server
    result = asyncio.run(server.handle_call_tool("validate", {"pattern": "missing_version"}))
    parsed = json.loads(result[0].text)
    assert parsed["id"] == "missing_version"
    assert "description" in parsed


def test_extended_list_pitfalls():
    """Test extended_tool list_pitfalls action."""
    import server
    result = asyncio.run(server.handle_call_tool("extended_tool", {"action": "list_pitfalls"}))
    parsed = json.loads(result[0].text)
    assert isinstance(parsed, list)
    assert len(parsed) > 0


def test_extended_pitfall():
    """Test extended_tool pitfall action."""
    import server
    result = asyncio.run(server.handle_call_tool("extended_tool", {"action": "pitfall", "filter": "macro_name_truncation"}))
    parsed = json.loads(result[0].text)
    assert parsed["id"] == "macro_name_truncation"


def test_extended_unknown_action():
    """Test extended_tool with unknown action."""
    import server
    result = asyncio.run(server.handle_call_tool("extended_tool", {"action": "bogus"}))
    parsed = json.loads(result[0].text)
    assert "error" in parsed


def test_list_resources():
    """Test that list_resources returns expected resources."""
    import server
    resources = asyncio.run(server.handle_list_resources())
    uris = {str(r.uri) for r in resources}
    assert "stata://commands" in uris
    assert "stata://snippets" in uris


def test_read_resource_commands():
    """Test reading the commands resource."""
    import server
    content = asyncio.run(server.handle_read_resource("stata://commands"))
    parsed = json.loads(content)
    assert isinstance(parsed, list)


def test_read_resource_snippets():
    """Test reading the snippets resource."""
    import server
    content = asyncio.run(server.handle_read_resource("stata://snippets"))
    parsed = json.loads(content)
    assert isinstance(parsed, list)
    assert len(parsed) > 0


def test_list_prompts():
    """Test that list_prompts returns expected prompts."""
    import server
    prompts = asyncio.run(server.handle_list_prompts())
    names = {p.name for p in prompts}
    assert "validate-ado" in names
    assert "new-command" in names


def test_prompt_validate_ado():
    """Test validate-ado prompt generation."""
    import server
    result = asyncio.run(server.handle_get_prompt("validate-ado", {"code": "program define test\nend"}))
    assert result.description is not None
    assert len(result.messages) > 0
    assert "Validation Results" in result.messages[0].content.text


def test_prompt_new_command():
    """Test new-command prompt generation."""
    import server
    result = asyncio.run(server.handle_get_prompt("new-command", {"name": "mytest"}))
    assert "mytest" in result.messages[0].content.text
    assert "program define mytest" in result.messages[0].content.text


def test_prompt_new_command_eclass():
    """Test new-command prompt with eclass."""
    import server
    result = asyncio.run(server.handle_get_prompt("new-command", {"name": "myest", "class": "eclass"}))
    assert "eclass" in result.messages[0].content.text
    assert "ereturn" in result.messages[0].content.text


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
    test_tool_handlers_exist()
    test_resource_handlers_exist()
    test_prompt_handlers_exist()
    test_list_tools()
    test_tool_annotations()
    test_stata_lib_command()
    test_stata_lib_snippet()
    test_stata_lib_query()
    test_validate_code()
    test_validate_pattern_info()
    test_extended_list_pitfalls()
    test_extended_pitfall()
    test_extended_unknown_action()
    test_list_resources()
    test_read_resource_commands()
    test_read_resource_snippets()
    test_list_prompts()
    test_prompt_validate_ado()
    test_prompt_new_command()
    test_prompt_new_command_eclass()
    test_commands_module()
    test_snippets_module()
    print("All server tests passed!")
