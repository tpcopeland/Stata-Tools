---
name: package
description: Run tests, validate package structure, parse logs, and check test coverage
metadata:
  version: "2.0.0"
  argument-hint: "[package-name]"
allowed-tools:
  - Read
  - Write
  - Edit
  - Glob
  - Grep
  - Bash
# NOTE: Task tool is NOT allowed - do NOT use subagents
---

# Package Testing & Validation

Run tests, validate package structure, parse test logs, and check coverage.

**IMPORTANT:** Always use `stata-mp` when running Stata commands.

## Testing Workflow

### Step 1: Find Test Files
```bash
# Functional tests
ls _devkit/_testing/test_*.do

# Validation tests
ls _devkit/_validation/validation_*.do
```

### Step 2: Run Tests
```bash
# Run single test
stata-mp -b do _devkit/_testing/test_command.do

# Check log for errors
grep -E "^r\([0-9]+" _devkit/_testing/test_command.log

# Run all functional tests
for f in _devkit/_testing/test_*.do; do
    echo "Running $f..."
    stata-mp -b do "$f"
done
```

### Step 3: Parse Results

Check each log for:
- `^r(XXX)` - Stata error codes
- `PASS` / `FAIL` counts
- `ALL TESTS PASSED` - Complete success

### Step 4: Validate Package Structure

Required files per command:
- `command.ado` - Implementation
- `command.sthlp` - Help file

Required files per package:
- `stata.toc` - Package index
- `packagename.pkg` - Package definition
- `README.md` - Documentation

### Step 5: Check Version Consistency
```bash
.claude/scripts/check-versions.sh [package_name]
```

### Step 6: Check Test Coverage
```bash
.claude/scripts/check-test-coverage.sh
```

## Output Format

```
## TEST RESULTS SUMMARY

**Package:** [name]
**Tests Run:** [N]
**Passed:** [N]
**Failed:** [N]

### Test Results

| Test File | Status | Notes |
|-----------|--------|-------|
| test_command.do | Pass | |
| validation_command.do | Fail | r(111) line 45 |

### Package Structure

| Check | Status |
|-------|--------|
| stata.toc exists | Y/N |
| .pkg files valid | Y/N |
| All .ado have .sthlp | Y/N |
| Versions synchronized | Y/N |

### Recommendation
[ ] **All tests passed** - Package ready
[ ] **Minor issues** - Fix and re-test
[ ] **Major issues** - Significant problems
```

## Log Parsing Patterns

| Pattern | Meaning |
|---------|---------|
| `^r(###);` | Stata error code |
| `assertion is false` | Failed assert |
| `PASS:` | Test passed |
| `FAIL:` | Test failed |
| `ALL TESTS PASSED` | Complete success |

## Common Error Codes

| Code | Meaning | Common Cause |
|------|---------|--------------|
| r(111) | Variable not found | Wrong variable name |
| r(198) | Invalid syntax | Syntax error |
| r(199) | Unrecognized command | Not installed |
| r(601) | File not found | Wrong path |
| r(2000) | No observations | Empty dataset |

## Delegation

| When | Use |
|------|-----|
| Tests fail, code needs fixing | `/develop` then `/reviewer` |
| Writing new tests | `/test` |
