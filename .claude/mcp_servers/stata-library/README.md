# Stata Command Library MCP Server

MCP server for Stata package development — commands, snippets, validation, and pitfalls.

## Architecture

Uses the low-level `mcp.server.Server` API with:
- **3 consolidated tools** (down from 8)
- **MCP Resources** — static catalogs available without tool calls
- **MCP Prompts** — structured templates for common workflows
- **ToolAnnotations** — all tools marked `readOnlyHint=True`

## Tools

### `stata_lib`

Access command docs, code snippets, and search. Provide one of:

| Parameter | Description |
|-----------|-------------|
| `command` | Get docs for a command (e.g., `"tvexpose"`) |
| `snippet` | Get a code snippet (e.g., `"marksample_basic"`) |
| `query` | Search commands, snippets, and pitfalls |
| `package` | Filter by package name |
| `limit` | Max search results (default 10) |

### `validate`

Validate Stata .ado code. Provide one of:

| Parameter | Description |
|-----------|-------------|
| `code` | Stata code string to validate |
| `file` | Path to .ado file (runs validate-ado.sh) |
| `versions` | Package name to check version consistency |
| `pattern` | Get info about a validation pattern ID |

### `extended_tool`

Gateway for less-common operations:

| Action | Filter | Description |
|--------|--------|-------------|
| `list_commands` | package name | List all commands |
| `list_snippets` | category | List all snippets |
| `list_patterns` | category | List validation patterns |
| `pitfall` | pitfall id | Get a specific pitfall |
| `search_pitfalls` | query | Search pitfalls |
| `list_pitfalls` | category | List pitfalls |

## Resources

| URI | Description |
|-----|-------------|
| `stata://commands` | All commands with package and purpose |
| `stata://snippets` | All snippet names with purposes and keywords |

## Prompts

| Name | Description |
|------|-------------|
| `validate-ado` | Validate code and return structured results |
| `new-command` | Scaffold template for a new .ado command |

## Validation Patterns

Static analysis checks (operate on code strings, no file I/O):

| Pattern | Severity | Description |
|---------|----------|-------------|
| `missing_version` | error | Missing `version 16.0` statement |
| `missing_varabbrev` | warning | Missing `set varabbrev off` |
| `missing_marksample` | warning | Syntax has [if]/[in] but no marksample |
| `long_macro_name` | error | Macro name > 31 chars (silent truncation) |
| `float_precision` | warning | `gen` without `double` keyword |
| `bysort_abs` | error | Function in bysort sort spec |
| `cls_batch` | warning | `cls` not valid in batch mode |
| `string_multiply` | error | `"str" * N` not supported in Stata |
| `nogen_merge` | warning | nogenerate then referencing _merge |
| `global_in_program` | warning | Globals inside program define |
| `hardcoded_path` | warning | Literal paths in .ado code |
| `capture_no_rc` | warning | capture without checking _rc |

## Setup

```bash
bash setup.sh
```

## Testing

```bash
.venv/bin/python -m pytest tests/ -v
```

## Data Files

- `data/commands.json` — auto-generated command index from .sthlp files
- `data/pitfalls.json` — Stata programming pitfalls catalog

---

*Part of the Stata-Tools development infrastructure*
