# Stata Command Library MCP Server

Fast, cached access to Stata-Tools command documentation for Claude Code.

## Purpose

Reduces token usage by 70-85% compared to loading full .sthlp files by providing:
- Indexed command documentation
- Searchable snippet library
- On-demand section retrieval

## Tools Available

### Command Documentation

| Tool | Description |
|------|-------------|
| `get_command(name)` | Get full documentation for a command |
| `search_commands(query)` | Search commands by keyword |
| `list_commands(package)` | List commands, optionally filtered by package |

### Code Snippets

| Tool | Description |
|------|-------------|
| `get_snippet(name)` | Get a specific code snippet |
| `search_snippets(query)` | Search snippets by keyword |
| `list_snippets(category)` | List snippets, optionally filtered |

## Usage

### Get Command Documentation

```python
from tools.commands import get_command

cmd = get_command("tvexpose")
# Returns:
# {
#     "name": "tvexpose",
#     "package": "tvtools",
#     "purpose": "Create time-varying exposure variables...",
#     "syntax": "tvexpose using filename, id(varname)...",
#     "options": {"id(varname)": "Person identifier", ...},
#     "results": {"scalars": [...], "macros": [...]}
# }
```

### Search Commands

```python
from tools.commands import search_commands

results = search_commands("time-varying")
# Returns list of matching commands with name, package, purpose
```

### Get Code Snippet

```python
from tools.snippets import get_snippet

snippet = get_snippet("marksample_full")
# Returns:
# {
#     "name": "marksample_full",
#     "purpose": "Full sample marking with option variables",
#     "code": "marksample touse\\nmarkout `touse' `byvar'..."
# }
```

## Command-Line Testing

```bash
# Get command info
python tools/commands.py get tvexpose

# Search commands
python tools/commands.py search exposure

# List all commands
python tools/commands.py list

# List commands in a package
python tools/commands.py list tvtools

# Regenerate index
python tools/commands.py regenerate

# Get snippet
python tools/snippets.py get marksample_full

# Search snippets
python tools/snippets.py search loop

# List all snippets
python tools/snippets.py list
```

## Data Files

- `data/commands.json` - Auto-generated command index from .sthlp files
- `.cache/` - Runtime cache for frequent lookups

## Regenerating the Index

When commands are added or updated:

```bash
python tools/commands.py regenerate
```

Or delete `data/commands.json` and it will be regenerated on next use.

## Token Savings

| Operation | Without MCP | With MCP | Savings |
|-----------|-------------|----------|---------|
| Get command syntax | ~500 tokens | ~100 tokens | 80% |
| Search for command | ~2000 tokens | ~200 tokens | 90% |
| Get code snippet | ~300 tokens | ~50 tokens | 83% |

---

*Part of the Stata-Tools optimization infrastructure*
