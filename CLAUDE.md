# Stata Coding Guide for Claude

**Purpose**: Quick reference for developing Stata packages, auditing .do files, and writing Stata commands.

---

## Stata Executable

**Always use `stata-mp`** when running Stata commands or do-files. This machine has a local Stata installation - **always use it directly** to test and run code rather than simulating or describing what would happen.

---

## CRITICAL: No Subagents

**NEVER use the Task tool to spawn subagents.** Always do the work directly in this session. Subagents waste tokens, lose context, and slow down development. This is enforced by a hook that will block Task tool calls.

---

## Critical Rules (Always Follow)

1. **Always set**: `version 16.0`, `set varabbrev off`, `set more off`
2. **Use `marksample touse`** for if/in conditions in programs
3. **Return results** via `return` (rclass) or `ereturn` (eclass)
4. **Use temp objects**: `tempvar`, `tempfile`, `tempname`
5. **Validate inputs** before processing, provide clear error messages
6. **Never abbreviate** variable names in production code
7. **Read before editing**: ALWAYS use Read tool before modifying any files
8. **Check syntax twice**: Verify backticks, quotes, and macro references
9. **Macro name limit**: ≤31 characters (Stata silently truncates longer names!)
10. **Use `double` precision**: Always use `gen double` for numeric variables
11. **Avoid SSC dependencies**: Minimize external dependencies

---

## Development Resources

| Directory | Contents |
|-----------|----------|
| `_devkit/_templates/` | Templates for .ado, .sthlp, .pkg, .dlg, test files |
| `_devkit/_testing/` | Functional tests (`test_*.do`) |
| `_devkit/_validation/` | Validation tests (`validation_*.do`) |
| `_devkit/docs/` | Detailed reference documentation |

### Detailed Documentation

| Document | Contents |
|----------|----------|
| `_devkit/docs/syntax-reference.md` | Macros, syntax patterns, loops, error handling |
| `_devkit/docs/template-guide.md` | Complete .ado, .sthlp, .pkg templates |
| `_devkit/docs/dialog-guide.md` | Dialog file (.dlg) development |
| `_devkit/docs/error-codes.md` | Error code reference |

### Skills (Slash Commands)

| Skill | Purpose |
|-------|---------|
| `/stata-develop` | Development guidance for creating/modifying commands |
| `/stata-test` | Functional testing workflow |
| `/stata-validate` | Known-answer validation guidance |
| `/stata-audit` | Code review and error detection |
| `/code-reviewer` | Detailed code review with scoring |
| `/stata-code-generator` | Generate code from requirements |
| `/package-tester` | Run tests and validate packages |

### Automation

| Script | Usage |
|--------|-------|
| `scaffold-command.sh` | `.claude/scripts/scaffold-command.sh COMMAND "Description"` |
| `check-versions.sh` | `.claude/scripts/check-versions.sh [PACKAGE]` |
| `validate-ado.sh` | `.claude/validators/validate-ado.sh mycommand.ado` |

---

## Package Structure

```
mypackage/
├── mypackage.ado       # Main command
├── mypackage.sthlp     # Help file
├── mypackage.pkg       # Package metadata
├── stata.toc           # Table of contents
└── README.md           # Documentation
```

---

## Essential Patterns

### Syntax Parsing

```stata
syntax varlist(numeric) [if] [in] , REQuired_opt(varname) [optional GENerate(name)]
```

### Sample Marking

```stata
marksample touse                    // Main varlist + if/in
markout `touse' `byvar'             // Option variables (after marksample)

quietly count if `touse'
if r(N) == 0 error 2000
```

### Program Structure

```stata
program define mycommand, rclass
    version 16.0
    set varabbrev off
    syntax varlist [if] [in] , REQuired(varname) [options]
    marksample touse
    quietly count if `touse'
    if r(N) == 0 error 2000
    // ... computation ...
    return scalar N = r(N)
end
```

---

## CRITICAL: Package Updates

**When modifying any package, you MUST update:**

1. **Distribution-Date in .pkg** (YYYYMMDD) - How Stata detects updates
2. **Version in .ado** (X.Y.Z format, never X.Y)
3. **Version in .sthlp** to match .ado
4. **Version in README.md**

**Version number rules:**
- `v 3` in .pkg/.toc = file format version (NEVER change)
- `1.0.0` = semantic version (increment with changes)

Run: `.claude/scripts/check-versions.sh [package]`

---

## Quick Reference

| Task | Command |
|------|---------|
| Mark sample | `marksample touse` |
| Mark option vars | `markout \`touse' varname` |
| Validate variable | `confirm variable var` |
| Temp objects | `tempvar/tempfile/tempname` |
| Debug | `set trace on` |
| Character repeat | `di _dup(60) "="` |
| Word count | `local n: word count \`list'` |
| Parse tokens | `gettoken first rest : list` |

---

## Common Error Codes

| Code | Meaning |
|------|---------|
| 109 | type mismatch |
| 111 | variable not found |
| 198 | invalid syntax |
| 601 | file not found |
| 2000 | no observations |

---

## Common Pitfalls

1. **Macro names >31 characters** - silently truncated, causes collision bugs
2. **Using `preserve`/`restore` with generate()** - variables lost on restore
3. **Using `float` instead of `double`** - precision loss
4. **Not updating Distribution-Date in .pkg** - Stata won't detect updates
5. **Changing `v 3` in .pkg/.toc** - breaks package format
6. **Missing backticks in macros** - references fail silently
7. **Testing only single-obs data** - misses row-level bugs
8. **Validating aggregates not rows** - masks calculation errors

---

## Policies

Quality enforcement policies in `.claude/policies/`:

- **mandatory-code-review.md** - Run `/code-reviewer` after code generation
- **test-before-commit.md** - Tests must pass before committing
- **version-consistency.md** - Versions must match across files

---

**For detailed documentation, see `_devkit/docs/`**
