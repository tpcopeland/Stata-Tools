# Context Loading Guidelines

## Priority Order

1. **MCP tools first** - Use `get_stata_command()`, `search_commands()`, `get_snippet()` when available
2. **Direct file reads** - Use Read tool for specific files
3. **Search** - Use Glob/Grep for finding files and patterns

## Key Reference Files

| Need | File |
|------|------|
| Command docs | MCP: `get_stata_command(name)` |
| Code snippets | MCP: `get_snippet(name)` |
| Error patterns | `_devkit/docs/error-codes.md` |
| Syntax reference | `_devkit/docs/syntax-reference.md` |
| Templates | `_devkit/_templates/` |

## What NOT to Load

- Don't read all .ado files to understand patterns - use search
- Don't read the entire CLAUDE.md - it's already in context
- Don't read skills README - the skill instructions are already loaded
