#!/usr/bin/env python3
"""
Stata Command Documentation Tools

Provides fast access to Stata-Tools command documentation.
"""

import json
import re
from pathlib import Path
from functools import lru_cache
from typing import Optional, List, Dict, Any

# Paths
REPO_ROOT = Path(__file__).parent.parent.parent.parent.parent
DATA_DIR = Path(__file__).parent.parent / "data"
CACHE_DIR = Path(__file__).parent.parent / ".cache"


def ensure_command_index():
    """Ensure command index exists, generate if not."""
    index_file = DATA_DIR / "commands.json"
    if not index_file.exists():
        generate_command_index()
    return index_file


def generate_command_index():
    """Generate command index from .sthlp files."""
    commands = []

    # Find all packages (directories with .ado files)
    for pkg_dir in REPO_ROOT.iterdir():
        if not pkg_dir.is_dir() or pkg_dir.name.startswith(('.', '_')):
            continue

        # Look for .sthlp files
        for sthlp in pkg_dir.glob("*.sthlp"):
            cmd_name = sthlp.stem
            cmd_data = extract_command_info(sthlp, pkg_dir.name)
            if cmd_data:
                commands.append(cmd_data)

    # Save index
    DATA_DIR.mkdir(parents=True, exist_ok=True)
    with open(DATA_DIR / "commands.json", "w") as f:
        json.dump(commands, f, indent=2)

    return commands


def extract_command_info(sthlp_path: Path, package: str) -> Optional[Dict[str, Any]]:
    """Extract command information from .sthlp file."""
    try:
        content = sthlp_path.read_text(encoding='utf-8', errors='ignore')
    except Exception:
        return None

    cmd_name = sthlp_path.stem

    # Extract purpose from title section
    purpose = ""
    title_match = re.search(r'{bf:' + re.escape(cmd_name) + r'}\s*{hline[^}]*}\s*([^{]+)', content)
    if title_match:
        purpose = title_match.group(1).strip()
    else:
        # Try p2col format
        p2col_match = re.search(r'{p2col:{cmd:' + re.escape(cmd_name) + r'}[^}]*}([^{]+)', content)
        if p2col_match:
            purpose = p2col_match.group(1).strip()

    # Extract syntax
    syntax = extract_section(content, 'syntax')

    # Extract options
    options = extract_options(content)

    # Extract stored results
    results = extract_results(content)

    return {
        "name": cmd_name,
        "package": package,
        "purpose": clean_smcl(purpose),
        "syntax": clean_smcl(syntax),
        "options": options,
        "results": results,
        "file": str(sthlp_path.relative_to(REPO_ROOT))
    }


def extract_section(content: str, section: str) -> str:
    """Extract a section from SMCL content."""
    # Look for marker
    pattern = rf'{{marker {section}}}.*?{{title:[^}}]+}}(.*?)(?={{marker|$)'
    match = re.search(pattern, content, re.DOTALL | re.IGNORECASE)
    if match:
        return match.group(1).strip()
    return ""


def extract_options(content: str) -> Dict[str, str]:
    """Extract options from SMCL content."""
    options = {}

    # Find synopt entries
    synopt_pattern = r'{synopt:{opt(?:h)?\s+([^}]+)}}([^{]*)'
    for match in re.finditer(synopt_pattern, content):
        opt_name = match.group(1).strip()
        opt_desc = clean_smcl(match.group(2).strip())
        if opt_name and opt_desc:
            options[opt_name] = opt_desc

    return options


def extract_results(content: str) -> Dict[str, List[Dict[str, str]]]:
    """Extract stored results from SMCL content."""
    results = {"scalars": [], "macros": [], "matrices": []}

    # Look for results section
    results_section = extract_section(content, 'results')
    if not results_section:
        return results

    # Find scalar results
    scalar_pattern = r'{synopt:{cmd:r\(([^)]+)\)}}([^{]*)'
    for match in re.finditer(scalar_pattern, results_section):
        name = match.group(1)
        desc = clean_smcl(match.group(2).strip())
        results["scalars"].append({"name": name, "description": desc})

    return results


def clean_smcl(text: str) -> str:
    """Remove SMCL formatting tags."""
    if not text:
        return ""

    # Remove common SMCL tags
    text = re.sub(r'{[a-z_]+:([^}]*)}', r'\1', text)
    text = re.sub(r'{[a-z_]+}', '', text)
    text = re.sub(r'{\.\.\.[^}]*}', '', text)
    text = re.sub(r'{p_end}', '', text)
    text = re.sub(r'\s+', ' ', text)

    return text.strip()


@lru_cache(maxsize=100)
def get_command(name: str) -> Optional[Dict[str, Any]]:
    """
    Get documentation for a Stata-Tools command.

    Args:
        name: Command name (e.g., "tvexpose", "table1_tc")

    Returns:
        Dictionary with command documentation or None if not found.
        {
            "name": "tvexpose",
            "package": "tvtools",
            "purpose": "Create time-varying exposure variables...",
            "syntax": "tvexpose using filename, id(varname)...",
            "options": {"id(varname)": "Person identifier (required)", ...},
            "results": {"scalars": [...], "macros": [...]}
        }
    """
    index_file = ensure_command_index()

    try:
        with open(index_file) as f:
            commands = json.load(f)
    except Exception:
        return None

    # Find command (case-insensitive)
    name_lower = name.lower()
    for cmd in commands:
        if cmd["name"].lower() == name_lower:
            return cmd

    return None


def search_commands(query: str, limit: int = 10) -> List[Dict[str, Any]]:
    """
    Search commands by keyword.

    Args:
        query: Search term
        limit: Maximum results

    Returns:
        List of matching commands with basic info.
    """
    index_file = ensure_command_index()

    try:
        with open(index_file) as f:
            commands = json.load(f)
    except Exception:
        return []

    query_lower = query.lower()
    matches = []

    for cmd in commands:
        # Check name, purpose, package
        score = 0
        if query_lower in cmd["name"].lower():
            score += 10
        if query_lower in cmd.get("purpose", "").lower():
            score += 5
        if query_lower in cmd.get("package", "").lower():
            score += 3

        # Check options
        for opt in cmd.get("options", {}).keys():
            if query_lower in opt.lower():
                score += 2
                break

        if score > 0:
            matches.append((score, {
                "name": cmd["name"],
                "package": cmd["package"],
                "purpose": cmd.get("purpose", "")[:100]
            }))

    # Sort by score, return top matches
    matches.sort(key=lambda x: x[0], reverse=True)
    return [m[1] for m in matches[:limit]]


def list_commands(package: Optional[str] = None) -> List[Dict[str, str]]:
    """
    List available commands.

    Args:
        package: Filter by package name (optional)

    Returns:
        List of commands with name, package, and brief purpose.
    """
    index_file = ensure_command_index()

    try:
        with open(index_file) as f:
            commands = json.load(f)
    except Exception:
        return []

    result = []
    for cmd in commands:
        if package and cmd.get("package", "").lower() != package.lower():
            continue

        result.append({
            "name": cmd["name"],
            "package": cmd.get("package", ""),
            "purpose": cmd.get("purpose", "")[:80]
        })

    return sorted(result, key=lambda x: (x["package"], x["name"]))


# CLI for testing
if __name__ == "__main__":
    import sys

    if len(sys.argv) < 2:
        print("Usage: commands.py <command> [args]")
        print("Commands: get <name>, search <query>, list [package], regenerate")
        sys.exit(1)

    cmd = sys.argv[1]

    if cmd == "get" and len(sys.argv) > 2:
        result = get_command(sys.argv[2])
        print(json.dumps(result, indent=2))

    elif cmd == "search" and len(sys.argv) > 2:
        results = search_commands(sys.argv[2])
        print(json.dumps(results, indent=2))

    elif cmd == "list":
        pkg = sys.argv[2] if len(sys.argv) > 2 else None
        results = list_commands(pkg)
        print(json.dumps(results, indent=2))

    elif cmd == "regenerate":
        generate_command_index()
        print("Command index regenerated")

    else:
        print(f"Unknown command: {cmd}")
