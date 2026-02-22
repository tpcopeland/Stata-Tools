#!/usr/bin/env python3
"""
Stata Command Library MCP Server

Consolidated tools, resources, and prompts for Stata package development.

Tools:
- stata_lib(command|snippet|query) — commands, snippets, and search
- validate(code|file) — .ado validation and version checks
- extended_tool(action, ...) — gateway for less-common operations

Resources:
- stata://commands — all commands with package and purpose
- stata://snippets — all snippet names with purposes

Prompts:
- validate-ado — run validation with structured results
- new-command — scaffold template for creating a new .ado command
"""

import asyncio
import json
import subprocess
import sys
from pathlib import Path
from typing import Optional

from mcp.server import Server
from mcp.server.stdio import stdio_server
from mcp.types import (
    GetPromptResult,
    Prompt,
    PromptArgument,
    PromptMessage,
    Resource,
    TextContent,
    Tool,
    ToolAnnotations,
)

# Paths
SCRIPT_DIR = Path(__file__).parent
TOOLS_DIR = SCRIPT_DIR / "tools"
REPO_ROOT = SCRIPT_DIR.parent.parent.parent

sys.path.insert(0, str(TOOLS_DIR))

from commands import (
    get_command,
    list_commands as _list_commands,
    search_commands as _search_commands,
)
from pitfalls import get_pitfall, list_pitfalls, search_pitfalls
from snippets import (
    get_snippet as _get_snippet,
    list_snippets as _list_snippets,
    search_snippets as _search_snippets,
)
from validate import (
    detect_patterns,
    get_pattern_info,
    list_patterns,
    validate_ado_code,
)

# --- Server setup ---

server = Server("stata-library")

READ_ONLY = ToolAnnotations(readOnlyHint=True, destructiveHint=False)
VALIDATE_ANNOTATIONS = ToolAnnotations(
    readOnlyHint=True, destructiveHint=False, idempotentHint=True
)


# --- Tools ---


@server.list_tools()
async def handle_list_tools():
    return [
        Tool(
            name="stata_lib",
            description=(
                "Access Stata-Tools command documentation, code snippets, and search. "
                "Provide exactly ONE of: command (get docs for a command), "
                "snippet (get a code snippet), or query (search commands and snippets)."
            ),
            inputSchema={
                "type": "object",
                "properties": {
                    "command": {
                        "type": "string",
                        "description": "Command name to look up (e.g. 'tvexpose', 'table1_tc')",
                    },
                    "snippet": {
                        "type": "string",
                        "description": "Snippet name to retrieve (e.g. 'marksample_basic')",
                    },
                    "query": {
                        "type": "string",
                        "description": "Search term for commands and snippets",
                    },
                    "package": {
                        "type": "string",
                        "description": "Filter by package name (with command/query)",
                    },
                    "limit": {
                        "type": "integer",
                        "description": "Max search results (default 10)",
                        "default": 10,
                    },
                },
                "required": [],
            },
            annotations=READ_ONLY,
        ),
        Tool(
            name="validate",
            description=(
                "Validate Stata .ado code. Provide 'code' to analyze a code string, "
                "or 'file' to run validate-ado.sh on a file. "
                "Use 'versions' with a package name to check version consistency."
            ),
            inputSchema={
                "type": "object",
                "properties": {
                    "code": {
                        "type": "string",
                        "description": "Stata code string to validate",
                    },
                    "file": {
                        "type": "string",
                        "description": "Path to .ado file to validate with validate-ado.sh",
                    },
                    "versions": {
                        "type": "string",
                        "description": "Package name to check version consistency (or 'all')",
                    },
                    "pattern": {
                        "type": "string",
                        "description": "Get info about a specific validation pattern ID",
                    },
                },
                "required": [],
            },
            annotations=VALIDATE_ANNOTATIONS,
        ),
        Tool(
            name="extended_tool",
            description=(
                "Gateway for less-common Stata library operations. "
                "Actions: 'list_commands' (with optional package filter), "
                "'list_snippets' (with optional category filter), "
                "'list_patterns' (validation pattern catalog), "
                "'pitfall' (get pitfall by id), "
                "'search_pitfalls' (search pitfalls by keyword), "
                "'list_pitfalls' (list pitfalls, optional category filter)."
            ),
            inputSchema={
                "type": "object",
                "properties": {
                    "action": {
                        "type": "string",
                        "description": "Operation to perform",
                        "enum": [
                            "list_commands",
                            "list_snippets",
                            "list_patterns",
                            "pitfall",
                            "search_pitfalls",
                            "list_pitfalls",
                        ],
                    },
                    "filter": {
                        "type": "string",
                        "description": "Filter value (package name, category, pitfall id, or search query depending on action)",
                    },
                },
                "required": ["action"],
            },
            annotations=READ_ONLY,
        ),
    ]


@server.call_tool()
async def handle_call_tool(name: str, arguments: dict | None):
    if arguments is None:
        arguments = {}

    if name == "stata_lib":
        return await _handle_stata_lib(arguments)
    elif name == "validate":
        return await _handle_validate(arguments)
    elif name == "extended_tool":
        return await _handle_extended(arguments)
    else:
        return [TextContent(type="text", text=json.dumps({"error": f"Unknown tool: {name}"}))]


async def _handle_stata_lib(args: dict):
    command = args.get("command")
    snippet = args.get("snippet")
    query = args.get("query")
    package = args.get("package")
    limit = args.get("limit", 10)

    if command:
        result = get_command(command)
        if result is None:
            return [TextContent(type="text", text=json.dumps({"error": f"Command '{command}' not found"}))]
        return [TextContent(type="text", text=json.dumps(result, indent=2))]

    if snippet:
        result = _get_snippet(snippet)
        if result is None:
            return [TextContent(type="text", text=json.dumps({"error": f"Snippet '{snippet}' not found"}))]
        return [TextContent(type="text", text=json.dumps(result, indent=2))]

    if query:
        cmd_results = _search_commands(query, limit=limit)
        snip_results = _search_snippets(query, limit=limit)
        pitfall_results = search_pitfalls(query, limit=limit)
        result = {
            "commands": cmd_results,
            "snippets": snip_results,
            "pitfalls": [{"id": p["id"], "title": p["title"]} for p in pitfall_results],
        }
        return [TextContent(type="text", text=json.dumps(result, indent=2))]

    # No specific action — list commands (with optional package filter)
    results = _list_commands(package=package)
    return [TextContent(type="text", text=json.dumps(results, indent=2))]


async def _handle_validate(args: dict):
    code = args.get("code")
    file_path = args.get("file")
    versions = args.get("versions")
    pattern = args.get("pattern")

    if pattern:
        info = get_pattern_info(pattern)
        if info is None:
            return [TextContent(type="text", text=json.dumps({"error": f"Pattern '{pattern}' not found"}))]
        return [TextContent(type="text", text=json.dumps(info, indent=2))]

    if code:
        result = validate_ado_code(code)
        return [TextContent(type="text", text=json.dumps(result, indent=2))]

    if file_path:
        validator = REPO_ROOT / ".claude" / "validators" / "validate-ado.sh"
        if not validator.exists():
            return [TextContent(type="text", text=json.dumps({"error": "validate-ado.sh not found"}))]
        try:
            proc = subprocess.run(
                [str(validator), file_path],
                capture_output=True,
                text=True,
                timeout=30,
                cwd=str(REPO_ROOT),
            )
            return [TextContent(type="text", text=json.dumps({
                "exit_code": proc.returncode,
                "output": proc.stdout,
                "errors": proc.stderr if proc.stderr else None,
            }))]
        except subprocess.TimeoutExpired:
            return [TextContent(type="text", text=json.dumps({"error": "Validation timed out after 30s"}))]
        except Exception as e:
            return [TextContent(type="text", text=json.dumps({"error": str(e)}))]

    if versions:
        checker = REPO_ROOT / ".claude" / "scripts" / "check-versions.sh"
        if not checker.exists():
            return [TextContent(type="text", text=json.dumps({"error": "check-versions.sh not found"}))]
        cmd = [str(checker)]
        if versions != "all":
            cmd.append(versions)
        try:
            proc = subprocess.run(
                cmd,
                capture_output=True,
                text=True,
                timeout=30,
                cwd=str(REPO_ROOT),
            )
            return [TextContent(type="text", text=json.dumps({
                "exit_code": proc.returncode,
                "output": proc.stdout,
                "errors": proc.stderr if proc.stderr else None,
            }))]
        except subprocess.TimeoutExpired:
            return [TextContent(type="text", text=json.dumps({"error": "Version check timed out after 30s"}))]
        except Exception as e:
            return [TextContent(type="text", text=json.dumps({"error": str(e)}))]

    # No arguments — list available patterns
    patterns = list_patterns()
    return [TextContent(type="text", text=json.dumps(patterns, indent=2))]


async def _handle_extended(args: dict):
    action = args.get("action", "")
    filter_val = args.get("filter")

    if action == "list_commands":
        results = _list_commands(package=filter_val)
        return [TextContent(type="text", text=json.dumps(results, indent=2))]

    elif action == "list_snippets":
        results = _list_snippets(category=filter_val)
        return [TextContent(type="text", text=json.dumps(results, indent=2))]

    elif action == "list_patterns":
        results = list_patterns(category=filter_val)
        return [TextContent(type="text", text=json.dumps(results, indent=2))]

    elif action == "pitfall":
        if not filter_val:
            return [TextContent(type="text", text=json.dumps({"error": "Provide pitfall id in 'filter'"}))]
        result = get_pitfall(filter_val)
        if result is None:
            return [TextContent(type="text", text=json.dumps({"error": f"Pitfall '{filter_val}' not found"}))]
        return [TextContent(type="text", text=json.dumps(result, indent=2))]

    elif action == "search_pitfalls":
        if not filter_val:
            return [TextContent(type="text", text=json.dumps({"error": "Provide search query in 'filter'"}))]
        results = search_pitfalls(filter_val)
        return [TextContent(type="text", text=json.dumps(results, indent=2))]

    elif action == "list_pitfalls":
        results = list_pitfalls(category=filter_val)
        return [TextContent(type="text", text=json.dumps(results, indent=2))]

    else:
        return [TextContent(type="text", text=json.dumps({"error": f"Unknown action: {action}"}))]


# --- Resources ---


@server.list_resources()
async def handle_list_resources():
    return [
        Resource(
            uri="stata://commands",
            name="Stata Commands Catalog",
            description="All 59 Stata-Tools commands with package and purpose",
            mimeType="application/json",
        ),
        Resource(
            uri="stata://snippets",
            name="Stata Snippets Catalog",
            description="All code snippet names with purposes and keywords",
            mimeType="application/json",
        ),
    ]


@server.read_resource()
async def handle_read_resource(uri):
    uri_str = str(uri)

    if uri_str == "stata://commands":
        commands = _list_commands()
        return json.dumps(commands, indent=2)

    elif uri_str == "stata://snippets":
        snippets = _list_snippets()
        return json.dumps(snippets, indent=2)

    raise ValueError(f"Unknown resource: {uri_str}")


# --- Prompts ---


@server.list_prompts()
async def handle_list_prompts():
    return [
        Prompt(
            name="validate-ado",
            description="Validate a Stata .ado file and return structured results",
            arguments=[
                PromptArgument(
                    name="code",
                    description="Stata .ado code to validate",
                    required=True,
                ),
            ],
        ),
        Prompt(
            name="new-command",
            description="Scaffold template for creating a new Stata .ado command",
            arguments=[
                PromptArgument(
                    name="name",
                    description="Command name (e.g., 'mycommand')",
                    required=True,
                ),
                PromptArgument(
                    name="class",
                    description="Return class: rclass (default) or eclass",
                    required=False,
                ),
            ],
        ),
    ]


@server.get_prompt()
async def handle_get_prompt(name: str, arguments: dict | None):
    if arguments is None:
        arguments = {}

    if name == "validate-ado":
        return _prompt_validate_ado(arguments)
    elif name == "new-command":
        return _prompt_new_command(arguments)

    raise ValueError(f"Unknown prompt: {name}")


def _prompt_validate_ado(args: dict) -> GetPromptResult:
    code = args.get("code", "")
    result = validate_ado_code(code)

    issues_text = ""
    if result["issues"]:
        for issue in result["issues"]:
            marker = "ERROR" if issue["severity"] == "error" else "WARN"
            issues_text += f"  [{marker}] Line {issue.get('line', '?')}: {issue['message']}\n"
    else:
        issues_text = "  No issues found.\n"

    summary = result["summary"]
    body = (
        f"Validation Results\n"
        f"{'=' * 40}\n"
        f"Errors:   {summary['errors']}\n"
        f"Warnings: {summary['warnings']}\n"
        f"Clean:    {'Yes' if result['clean'] else 'No'}\n\n"
        f"Issues:\n{issues_text}\n"
        f"Code analyzed:\n```stata\n{code}\n```"
    )

    return GetPromptResult(
        description="Stata .ado validation results",
        messages=[
            PromptMessage(
                role="user",
                content=TextContent(type="text", text=body),
            )
        ],
    )


def _prompt_new_command(args: dict) -> GetPromptResult:
    cmd_name = args.get("name", "mycommand")
    ret_class = args.get("class", "rclass")

    if ret_class == "eclass":
        template = f"""\
program define {cmd_name}, eclass
    version 16.0
    set varabbrev off

    syntax varlist(min=2) [if] [in] [, Level(cilevel)]

    marksample touse
    gettoken depvar indepvars : varlist

    quietly count if `touse'
    if r(N) == 0 error 2000

    tempname b V
    // ... estimation ...

    ereturn post `b' `V', obs(`=r(N)') esample(`touse')
    ereturn local cmd "{cmd_name}"
    ereturn local depvar "`depvar'"
end"""
    else:
        template = f"""\
program define {cmd_name}, rclass
    version 16.0
    set varabbrev off

    syntax varlist [if] [in] [, ///
        by(varlist)           /// Grouping variable
        GENerate(name)        /// New variable name
        Replace               /// Overwrite existing
        ]

    marksample touse
    quietly count if `touse'
    if r(N) == 0 error 2000
    local n = r(N)

    // ... computation ...

    return scalar N = `n'
end"""

    body = (
        f"Scaffold for new Stata command: {cmd_name}\n"
        f"Return class: {ret_class}\n\n"
        f"```stata\n{template}\n```\n\n"
        f"Next steps:\n"
        f"1. Save as {cmd_name}/{cmd_name}.ado\n"
        f"2. Add syntax options for your use case\n"
        f"3. Implement computation logic\n"
        f"4. Create help file: {cmd_name}/{cmd_name}.sthlp\n"
        f"5. Create package file: {cmd_name}/{cmd_name}.pkg\n"
        f"6. Run /reviewer then /test"
    )

    return GetPromptResult(
        description=f"New {ret_class} command scaffold: {cmd_name}",
        messages=[
            PromptMessage(
                role="user",
                content=TextContent(type="text", text=body),
            )
        ],
    )


# --- Entry point ---


async def main():
    async with stdio_server() as (read_stream, write_stream):
        await server.run(
            read_stream,
            write_stream,
            server.create_initialization_options(),
        )


if __name__ == "__main__":
    asyncio.run(main())
