# Stata Code Audit Skill

**Trigger**: Use when reviewing or auditing .ado files, especially when Stata runtime is not available. This skill enables systematic code review through pattern detection and mental execution.

---

## Audit Workflow

### Phase 1: Structural Scan
1. Check header format and version
2. Verify mandatory code structure
3. Scan for common error patterns

### Phase 2: Logic Analysis
1. Trace macro definitions and usage
2. Verify control flow
3. Check resource lifecycle (tempvars, frames)

### Phase 3: Cross-File Consistency
1. Compare versions across .ado/.sthlp/.pkg/README
2. Verify syntax documentation matches implementation
3. Check stored results documentation

---

## Quick Error Detection Checklist

Run through this checklist for every .ado file:

### Structure (Lines 1-20)
- [ ] Version line: `*! command Version X.Y.Z  YYYY/MM/DD`
- [ ] Description line present
- [ ] Author line present
- [ ] Program class declared
- [ ] Block comment with syntax documentation
- [ ] `program define command, rclass/eclass`
- [ ] `version 16.0` or `version 18.0`
- [ ] `set varabbrev off`

### Sample Handling
- [ ] `syntax` statement present
- [ ] `marksample touse` if syntax has `[if] [in]`
- [ ] `markout` for option variables
- [ ] `quietly count if \`touse'` with check

### Macro Usage
- [ ] All macro references use `` `name' `` format
- [ ] No macro names > 31 characters
- [ ] No spaces inside backticks
- [ ] No unclosed quotes

### Tempvars
- [ ] All tempvars declared with `tempvar`
- [ ] All tempvar references use backticks
- [ ] No unnecessary `drop \`tempvar'`

### Error Handling
- [ ] All `capture` followed by `_rc` check
- [ ] `_rc` saved immediately if subsequent commands run
- [ ] Clear error messages with codes

### Returns
- [ ] Return type matches program declaration
- [ ] All documented returns actually set
- [ ] Returns set before program end

---

## Error Pattern Catalog

### Category 1: Macro Errors

| Pattern | Detection | Fix |
|---------|-----------|-----|
| Missing backticks | Variable name without `` `'`` after `local` | Add backticks |
| Unclosed quote | Count backticks ≠ single quotes | Close quotes |
| Name > 31 chars | Count characters | Shorten name |
| Nested macro error | Complex `` `\`var'' `` patterns | Verify nesting |

**Detection regex:**
```
# Missing backticks after local definition
local\s+(\w+)\s*=.*\n.*\b\1\b(?!['`])

# Potential long macro names
local\s+(\w{32,})
```

### Category 2: Structure Errors

| Pattern | Detection | Fix |
|---------|-----------|-----|
| No version | First 10 lines lack `version` | Add version |
| No varabbrev off | Missing after version | Add statement |
| No marksample | Has if/in but no marksample | Add marksample |
| No obs check | Has marksample but no count | Add check |

### Category 3: Tempvar Errors

| Pattern | Detection | Fix |
|---------|-----------|-----|
| No declaration | Uses `_var` pattern | Use tempvar |
| No backticks | `gen tempname` after tempvar | Add backticks |
| Unnecessary drop | `drop \`tempvar'` | Remove (auto-dropped) |

### Category 4: Error Handling

| Pattern | Detection | Fix |
|---------|-----------|-----|
| Unchecked capture | `capture` without `_rc` | Add check |
| Stale _rc | Commands between capture and if | Save _rc immediately |
| Wrong error code | Non-standard codes | Use Stata conventions |

### Category 5: Cross-File Inconsistency

| Check | Files | How |
|-------|-------|-----|
| Version number | .ado, .sthlp, .pkg, README | All must match X.Y.Z |
| Date format | .ado (YYYY/MM/DD), .sthlp (DDmonYYYY), .pkg (YYYYMMDD) | Format varies |
| Syntax | .ado syntax line vs .sthlp | Must match exactly |
| Options | .ado syntax vs .sthlp synoptset | All options documented |
| Returns | .ado return statements vs .sthlp results | All returns documented |

---

## Mental Execution Trace

For code paths that are unclear, trace execution manually:

```
MENTAL EXECUTION TRACE
======================
Command: mycommand price mpg, option(value)

LINE  ACTION                          STATE CHANGE
----  ------                          ------------
12    syntax varlist, Option(string)  varlist="price mpg", option="value"
14    marksample touse                touse created
15    markout `touse' `option'        ERROR: option is string, not varname!

FINDING: Line 15 attempts to markout a string option (should be varname)
```

### Trace Template

```
FILE: command.ado
TRACE: [normal|edge case|error path]
INPUT: [specific command and data state]

Step | Line | Code                     | Variables/State
-----|------|--------------------------|----------------
1    | 12   | syntax varlist...        | varlist = ...
2    | 14   | marksample touse         | touse created
...

RESULT: [success|failure with reason]
FINDING: [issue description or "clean"]
```

---

## Variable Lifecycle Tracking

For each variable created in the program:

```
VARIABLE LIFECYCLE: varname
===========================
Created:   Line 45: tempvar varname
Initialized: Line 46: gen `varname' = 0
Modified:  Line 50: replace `varname' = x if condition
           Line 55: replace `varname' = y if other
Used:      Line 60: summarize `varname'
           Line 65: return scalar result = `varname'[1]
Destroyed: (auto at program end - tempvar)

STATUS: OK - properly managed
```

### Lifecycle Issues to Detect

1. **Used before initialization**: Variable read before any value assigned
2. **Modified after last use**: Computation wasted
3. **Never used**: Dead code
4. **Escaped scope**: Tempvar referenced outside program
5. **Leaked resource**: Frame/file not cleaned up

---

## Audit Report Template

```markdown
# Audit Report: command.ado

**Date:** YYYY-MM-DD
**Version Audited:** X.Y.Z

## Summary

| Category | Issues | Severity |
|----------|--------|----------|
| Structure | N | Low/Med/High |
| Macros | N | Low/Med/High |
| Logic | N | Low/Med/High |
| Cross-file | N | Low/Med/High |

## Findings

### Finding 1: [Title]
- **Location:** line N
- **Severity:** High/Medium/Low
- **Description:** ...
- **Fix:** ...

### Finding 2: ...

## Recommendations

1. ...
2. ...

## Verification Checklist

- [ ] All findings addressed
- [ ] Tests pass after fixes
- [ ] Version updated
- [ ] Cross-file versions synced
```

---

## Common Stata Error Codes

| Code | Meaning | Common Cause |
|------|---------|--------------|
| 100 | varlist required | Empty varlist |
| 109 | type mismatch | Numeric/string confusion |
| 110 | variable already defined | Missing replace option |
| 111 | variable not found | Typo or wrong scope |
| 198 | invalid syntax | Syntax parsing failed |
| 601 | file not found | Wrong path |
| 2000 | no observations | if/in eliminated all obs |

---

## Audit Without Runtime

When Stata is unavailable:

1. **Pattern scan**: Use regex to find error patterns
2. **Mental trace**: Walk through code logic manually
3. **Cross-check**: Compare files for consistency
4. **Document**: Write findings in audit report format

This compensates for lack of runtime by systematic analysis.

---

## Automation Scripts

Use these scripts for automated checking:

```bash
# Static validation without Stata
.claude/hooks/validate-ado.sh command/command.ado

# Check version consistency across .ado/.sthlp/.pkg/README
.claude/scripts/check-versions.sh command

# Check all packages
.claude/scripts/check-versions.sh
```

---

## Sample Audit Commands

```bash
# Find potential macro issues (long names)
grep -E 'local\s+\w{25,}' command.ado

# Find missing backticks after local
grep -E 'local\s+(\w+)\s*=' command.ado | head -5

# Check for capture without _rc
grep -A2 'capture ' command.ado | grep -v '_rc'

# Compare versions across files
grep -h 'version\|Version' command.ado command.sthlp command.pkg
```

---

*For developing new commands, ask: "create a new command" or "help me implement"*
*For writing tests, ask: "write tests for [command]"*
*For validation tests, ask: "validate the command" or "verify correctness"*
