# MCP Tools Reference Policy

**Status:** ADVISORY
**Reference:** MCP server at `.claude/mcp_servers/stata-library/`

---

## Rule

When the MCP server is available, prefer MCP tools over direct file reads for command documentation and code snippets.

## Available MCP Tools

| Tool | Purpose | Use When |
|------|---------|----------|
| `get_stata_command(name)` | Get command documentation | Looking up a specific command |
| `search_stata_commands(query)` | Search commands by keyword | Finding relevant commands |
| `list_stata_commands(package)` | List available commands | Browsing commands |
| `get_snippet(name)` | Get code snippet | Need a code pattern |
| `search_snippets(query)` | Search snippets | Finding patterns |
| `list_snippet_categories(category)` | List snippets | Browsing patterns |
| `validate_ado(file_path)` | Validate .ado file | After writing .ado code |
| `check_versions(package)` | Check version consistency | Before committing |

## When to Use MCP vs File Reads

| Scenario | Use |
|----------|-----|
| Need command syntax/options | MCP: `get_stata_command()` |
| Need a code pattern | MCP: `get_snippet()` |
| Need to read actual .ado code | `Read` tool directly |
| Need to search for patterns in code | `Grep` / `Glob` tools |
| Need to validate a file | MCP: `validate_ado()` or bash script |

## Setup

If the MCP server is not configured, run:
```bash
bash .claude/mcp_servers/stata-library/setup.sh
```
