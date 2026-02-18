---
name: develop
description: Create new .ado commands, add features, fix bugs, and generate Stata package code
metadata:
  version: "2.0.0"
  argument-hint: "[command-name] [description]"
allowed-tools:
  - Read
  - Write
  - Edit
  - Glob
  - Grep
  - Bash
# NOTE: Task tool is NOT allowed - do NOT use subagents
---

# Stata Command Development

Use this when creating a new Stata .ado command, adding features to existing commands, fixing bugs, or generating code from requirements.

**IMPORTANT:** Always use `stata-mp` when running Stata commands.

## Quick Start

### New Command
1. Run: `.claude/scripts/scaffold-command.sh mycommand "Brief description"`
2. Or copy templates from `_devkit/_templates/`
3. Follow mandatory code structure below

### Modify Existing Command
1. Read the existing .ado file first
2. Check related .sthlp for consistency
3. Follow version management checklist after changes

## Mandatory Code Structure

```stata
*! mycommand Version 1.0.0  2025/01/15
*! Brief description
*! Author: Name
*! Program class: rclass

program define mycommand, rclass
    version 16.0
    set varabbrev off

    syntax varlist(numeric) [if] [in] , REQuired(varname) [optional GENerate(name)]

    marksample touse
    markout `touse' `required'

    quietly count if `touse'
    if r(N) == 0 error 2000

    // ... main logic ...

    return scalar N = r(N)
end
```

## Critical Error Patterns to Avoid

| Pattern | Fix |
|---------|-----|
| Missing backticks on macro refs | Always use `` `name' `` |
| Macro name >31 chars | Shorten (Stata silently truncates!) |
| Missing markout for option vars | Add `markout` after `marksample` |
| Tempvar without backticks | `gen \`mytemp' = ...` not `gen mytemp = ...` |
| Unchecked capture | Always check `_rc` after capture |
| _rc overwritten | Save `local rc = _rc` immediately |
| `float` instead of `double` | Always use `gen double` |
| `"=" * 60` for lines | Use `_dup(60) "="` |

## Version Management Checklist

When creating/updating a command, update ALL of these:

| File | Location | Format |
|------|----------|--------|
| .ado | Line 1 | `Version 1.0.0  YYYY/MM/DD` |
| .sthlp | Line 2 | `version 1.0.0  DDmonYYYY` |
| .pkg | Distribution-Date | `YYYYMMDD` |
| README.md | Version section | `1.0.0` |

**NEVER change `v 3` in .pkg or stata.toc** - this is file format version.

Run: `.claude/scripts/check-versions.sh [package]`

## After Implementation

1. Run static validation: `.claude/validators/validate-ado.sh command/command.ado`
2. Check versions: `.claude/scripts/check-versions.sh command`
3. **Invoke `/reviewer`** (MANDATORY for new/modified .ado code)
4. Create tests with `/test`
5. Run tests with `stata-mp -b do test_file.do`

## Delegation

| When | Use |
|------|-----|
| After writing code | `/reviewer` (MANDATORY) |
| Writing tests | `/test` |
| Running tests & validating package | `/package` |

## Reference Files

- `workflows/new-command.md` - Full scaffolding workflow
- `workflows/modify-command.md` - Adding features to existing commands
- `references/syntax-patterns.md` - Syntax reference
- `references/templates.md` - Template catalog
- `_devkit/_templates/` - Actual template files
- `_devkit/docs/syntax-reference.md` - Detailed syntax reference
