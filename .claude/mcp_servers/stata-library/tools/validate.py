#!/usr/bin/env python3
"""
Stata .ado Code Validation

Static analysis patterns for Stata program development.
Operates on code strings so validation can happen during development
before saving files.
"""

import re
from typing import List, Dict, Any, Optional


# --- Pattern definitions ---

PATTERNS = [
    {
        "id": "missing_version",
        "severity": "error",
        "category": "structure",
        "title": "Missing version statement",
        "description": "Programs should start with `version 16.0` (or appropriate version).",
        "pattern": None,  # custom logic
    },
    {
        "id": "missing_varabbrev",
        "severity": "warning",
        "category": "structure",
        "title": "Missing set varabbrev off",
        "description": "Programs should include `set varabbrev off` to prevent abbreviation bugs.",
        "pattern": None,
    },
    {
        "id": "missing_marksample",
        "severity": "warning",
        "category": "structure",
        "title": "Missing marksample with if/in",
        "description": "Syntax accepts [if] [in] but program never calls marksample.",
        "pattern": None,
    },
    {
        "id": "long_macro_name",
        "severity": "error",
        "category": "macro",
        "title": "Macro name exceeds 31 characters",
        "description": "Stata silently truncates macro names longer than 31 characters, causing collision bugs.",
        "pattern": None,
    },
    {
        "id": "float_precision",
        "severity": "warning",
        "category": "precision",
        "title": "gen without double keyword",
        "description": "Use `gen double` to avoid floating-point precision loss.",
        "pattern": r'(?m)^\s*(?:qui(?:etly)?\s+)?gen(?:erate)?\s+(?!double\b)(?!byte\b)(?!int\b)(?!long\b)(?!str)',
    },
    {
        "id": "bysort_abs",
        "severity": "error",
        "category": "syntax",
        "title": "Function in bysort sort specification",
        "description": "Stata does not allow functions in the sort specification of bysort. Create a temp variable first.",
        "pattern": r'(?m)^\s*bysort\b.*\(\s*(?:abs|round|ceil|floor|int|real|string|strlen|lower|upper|trim)\s*\(',
    },
    {
        "id": "cls_batch",
        "severity": "warning",
        "category": "batch",
        "title": "cls in batch mode",
        "description": "`cls` is not valid in batch mode and will cause an error.",
        "pattern": r'(?m)^\s*cls\s*$',
    },
    {
        "id": "string_multiply",
        "severity": "error",
        "category": "syntax",
        "title": "String multiplication",
        "description": 'Stata does not support `"string" * N`. Use `_dup(N) "string"` instead.',
        "pattern": r'"[^"]*"\s*\*\s*\d+',
    },
    {
        "id": "nogen_merge",
        "severity": "warning",
        "category": "logic",
        "title": "nogenerate then referencing _merge",
        "description": "Merge uses nogenerate but code later references _merge.",
        "pattern": None,
    },
    {
        "id": "global_in_program",
        "severity": "warning",
        "category": "scope",
        "title": "Global macro inside program",
        "description": "Avoid globals inside `program define`. Use locals or c_local instead.",
        "pattern": None,
    },
    {
        "id": "hardcoded_path",
        "severity": "warning",
        "category": "portability",
        "title": "Hardcoded file path",
        "description": "Literal paths in .ado code reduce portability. Use arguments or c(sysdir_*) instead.",
        "pattern": r'(?m)(?:"|`")(?:/(?:home|Users|tmp|var|etc)/|[A-Z]:\\)',
    },
    {
        "id": "capture_no_rc",
        "severity": "warning",
        "category": "logic",
        "title": "capture without _rc check",
        "description": "`capture` suppresses errors. Check `_rc` afterward to handle failures.",
        "pattern": None,
    },
]


def _find_program_blocks(code: str) -> List[Dict[str, Any]]:
    """Find program define ... end blocks in code."""
    blocks = []
    lines = code.split('\n')
    in_program = False
    start_line = 0
    program_lines = []
    program_name = ""

    for i, line in enumerate(lines):
        stripped = line.strip()
        # Match program define (with optional properties like rclass, eclass)
        prog_match = re.match(
            r'program\s+(?:define\s+)?(\w+)', stripped, re.IGNORECASE
        )
        if prog_match and not in_program:
            in_program = True
            start_line = i
            program_name = prog_match.group(1)
            program_lines = [line]
        elif in_program:
            program_lines.append(line)
            if re.match(r'end\s*$', stripped, re.IGNORECASE):
                blocks.append({
                    "name": program_name,
                    "start": start_line,
                    "end": i,
                    "code": '\n'.join(program_lines),
                })
                in_program = False
                program_lines = []

    return blocks


def _check_missing_version(code: str, blocks: List[Dict]) -> List[Dict]:
    """Check for missing version statement in program blocks."""
    issues = []
    for block in blocks:
        if not re.search(r'(?m)^\s*version\s+\d', block["code"]):
            issues.append({
                "pattern": "missing_version",
                "severity": "error",
                "line": block["start"] + 1,
                "message": f"Program '{block['name']}' missing `version` statement.",
            })
    return issues


def _check_missing_varabbrev(code: str, blocks: List[Dict]) -> List[Dict]:
    """Check for missing set varabbrev off."""
    issues = []
    for block in blocks:
        if not re.search(r'(?m)^\s*set\s+varabbrev\s+off', block["code"]):
            issues.append({
                "pattern": "missing_varabbrev",
                "severity": "warning",
                "line": block["start"] + 1,
                "message": f"Program '{block['name']}' missing `set varabbrev off`.",
            })
    return issues


def _check_missing_marksample(code: str, blocks: List[Dict]) -> List[Dict]:
    """Check syntax has [if] [in] but no marksample."""
    issues = []
    for block in blocks:
        bc = block["code"]
        has_if_in = re.search(
            r'(?m)^\s*syntax\b.*\[\s*if\b', bc
        ) or re.search(
            r'(?m)^\s*syntax\b.*\[\s*in\b', bc
        )
        has_marksample = re.search(r'(?m)^\s*marksample\b', bc)
        if has_if_in and not has_marksample:
            issues.append({
                "pattern": "missing_marksample",
                "severity": "warning",
                "line": block["start"] + 1,
                "message": f"Program '{block['name']}' accepts [if]/[in] but never calls marksample.",
            })
    return issues


def _check_long_macro_name(code: str, blocks: List[Dict]) -> List[Dict]:
    """Check for macro names longer than 31 characters."""
    issues = []
    lines = code.split('\n')
    # Match local/tempvar/tempname definitions
    macro_def = re.compile(
        r'(?m)^\s*(?:local|tempvar|tempname|tempfile)\s+(\w+)'
    )
    for i, line in enumerate(lines):
        m = macro_def.match(line)
        if m:
            name = m.group(1)
            if len(name) > 31:
                issues.append({
                    "pattern": "long_macro_name",
                    "severity": "error",
                    "line": i + 1,
                    "message": f"Macro name '{name}' is {len(name)} chars (max 31). Stata will silently truncate.",
                })
    return issues


def _check_nogen_merge(code: str, blocks: List[Dict]) -> List[Dict]:
    """Check for nogenerate merge then referencing _merge."""
    issues = []
    lines = code.split('\n')
    nogen_line = None
    for i, line in enumerate(lines):
        stripped = line.strip()
        if re.search(r'\bmerge\b.*\bnogen(?:erate)?\b', stripped, re.IGNORECASE):
            nogen_line = i
        elif nogen_line is not None and re.search(r'\b_merge\b', stripped):
            issues.append({
                "pattern": "nogen_merge",
                "severity": "warning",
                "line": i + 1,
                "message": "References `_merge` after merge with nogenerate option.",
            })
            nogen_line = None
    return issues


def _check_global_in_program(code: str, blocks: List[Dict]) -> List[Dict]:
    """Check for global macro usage inside program define blocks."""
    issues = []
    for block in blocks:
        blines = block["code"].split('\n')
        for j, bline in enumerate(blines):
            if re.match(r'\s*global\s+\w+', bline):
                issues.append({
                    "pattern": "global_in_program",
                    "severity": "warning",
                    "line": block["start"] + j + 1,
                    "message": f"Global macro inside program '{block['name']}'. Use local or c_local instead.",
                })
    return issues


def _check_capture_no_rc(code: str, blocks: List[Dict]) -> List[Dict]:
    """Check for capture without subsequent _rc check."""
    issues = []
    lines = code.split('\n')
    for i, line in enumerate(lines):
        stripped = line.strip()
        if re.match(r'capture\s+(?!noisily\b)', stripped):
            # Look ahead up to 5 lines for _rc check
            found_rc = False
            for j in range(i + 1, min(i + 6, len(lines))):
                if re.search(r'\b_rc\b', lines[j]):
                    found_rc = True
                    break
            if not found_rc:
                issues.append({
                    "pattern": "capture_no_rc",
                    "severity": "warning",
                    "line": i + 1,
                    "message": "`capture` without checking `_rc` in following lines.",
                })
    return issues


def detect_patterns(code: str) -> List[Dict[str, Any]]:
    """
    Run all static analysis patterns against Stata code.

    Args:
        code: Stata code string to analyze.

    Returns:
        List of detected issues, each with pattern, severity, line, message.
    """
    if not code or not code.strip():
        return []

    issues: List[Dict[str, Any]] = []
    blocks = _find_program_blocks(code)
    lines = code.split('\n')

    # Custom-logic checks
    issues.extend(_check_missing_version(code, blocks))
    issues.extend(_check_missing_varabbrev(code, blocks))
    issues.extend(_check_missing_marksample(code, blocks))
    issues.extend(_check_long_macro_name(code, blocks))
    issues.extend(_check_nogen_merge(code, blocks))
    issues.extend(_check_global_in_program(code, blocks))
    issues.extend(_check_capture_no_rc(code, blocks))

    # Regex-based checks
    for pat in PATTERNS:
        if pat["pattern"] is None:
            continue
        regex = re.compile(pat["pattern"])
        for i, line in enumerate(lines):
            if regex.search(line):
                issues.append({
                    "pattern": pat["id"],
                    "severity": pat["severity"],
                    "line": i + 1,
                    "message": pat["title"],
                })

    # Sort by line number
    issues.sort(key=lambda x: x.get("line", 0))
    return issues


def validate_ado_code(code: str) -> Dict[str, Any]:
    """
    Validate Stata .ado code and return structured results.

    Args:
        code: Stata code string to validate.

    Returns:
        Dictionary with:
            issues: list of errors and warnings
            summary: counts by severity
            clean: True if no errors found
    """
    all_issues = detect_patterns(code)

    errors = [i for i in all_issues if i["severity"] == "error"]
    warnings = [i for i in all_issues if i["severity"] == "warning"]

    return {
        "issues": all_issues,
        "summary": {
            "errors": len(errors),
            "warnings": len(warnings),
            "total": len(all_issues),
        },
        "clean": len(errors) == 0,
    }


def get_pattern_info(pattern_id: str) -> Optional[Dict[str, Any]]:
    """Get details about a specific validation pattern."""
    for p in PATTERNS:
        if p["id"] == pattern_id:
            return {
                "id": p["id"],
                "severity": p["severity"],
                "category": p["category"],
                "title": p["title"],
                "description": p["description"],
            }
    return None


def list_patterns(category: Optional[str] = None) -> List[Dict[str, str]]:
    """List all validation patterns, optionally filtered by category."""
    results = []
    for p in PATTERNS:
        if category and p["category"] != category:
            continue
        results.append({
            "id": p["id"],
            "severity": p["severity"],
            "category": p["category"],
            "title": p["title"],
        })
    return results
