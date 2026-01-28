# Stata Error Codes Reference

Comprehensive reference for Stata error codes encountered in package development.

---

## Common Error Codes

### Input/Syntax Errors (100-199)

| Code | Message | Cause | Fix |
|------|---------|-------|-----|
| 100 | varlist required | Missing required varlist | Check syntax statement, ensure variables provided |
| 101 | varlist not allowed | varlist provided when not expected | Remove varlist from command call |
| 102 | too few variables specified | varlist has fewer than required | Check `min=` constraint in syntax |
| 103 | too many variables specified | varlist has more than allowed | Check `max=` constraint in syntax |
| 104 | nothing to input | No data to input | Check data source |
| 109 | type mismatch | Wrong variable type | Use `confirm numeric variable` before use |
| 110 | already defined | Variable/program already exists | Use `capture drop` or `replace` option |
| 111 | not found | Variable/file doesn't exist | Check spelling, use `confirm variable` |
| 119 | statement out of context | Command used in wrong context | Check program flow |
| 198 | invalid syntax | General syntax error | Review command syntax carefully |
| 199 | unrecognized command | Command not installed | Install package, check spelling |

### Option Errors (190-199)

| Code | Message | Cause | Fix |
|------|---------|-------|-----|
| 191 | option X not allowed | Invalid option provided | Check available options in help |
| 192 | option X required | Missing required option | Add required option |
| 197 | invalid number | Non-numeric where number expected | Check numlist/integer options |
| 198 | invalid name | Invalid Stata name | Use valid naming (starts with letter, no spaces) |

### Data/Observation Errors (2000-2099)

| Code | Message | Cause | Fix |
|------|---------|-------|-----|
| 2000 | no observations | Empty data or if excludes all | Check if condition, marksample |
| 2001 | insufficient observations | Not enough obs for operation | Relax constraints or get more data |

### File Errors (600-699)

| Code | Message | Cause | Fix |
|------|---------|-------|-----|
| 601 | file not found | Path incorrect or file missing | Check path, use `confirm file` |
| 602 | file already exists | Attempting to overwrite | Add `replace` option |
| 603 | file could not be opened | Permission or format issue | Check permissions, file integrity |
| 610 | too many files open | File handle limit reached | Close unused files |
| 680 | unable to save | Disk full or permission issue | Check disk space, permissions |

### Expression/Calculation Errors (400-499)

| Code | Message | Cause | Fix |
|------|---------|-------|-----|
| 402 | no room to add variables | Memory limit | Compress data, increase memory |
| 411 | noninteger where integer required | Float used where int needed | Use `int()` or `round()` |
| 450 | conformability error | Matrix dimension mismatch | Check matrix operations |
| 459 | something that should be true is false | Assertion failed | Debug assertion logic |
| 480 | matrix not found | Referenced undefined matrix | Check matrix creation |
| 498 | not possible | Impossible operation | Review logic |
| 499 | cannot allocate memory | Out of memory | Reduce data size, increase memory |

### Matrix Errors (500-599)

| Code | Message | Cause | Fix |
|------|---------|-------|-----|
| 503 | matrix not symmetric | Matrix should be symmetric | Check matrix creation |
| 504 | matrix not positive definite | Invalid covariance matrix | Check data, consider regularization |
| 506 | conformability error | Incompatible matrix dimensions | Verify matrix sizes |

---

## Error Handling Patterns

### Basic Error Check

```stata
capture mycommand args
if _rc != 0 {
    display as error "Command failed with error `_rc'"
    exit _rc
}
```

### Show Output on Error

```stata
capture noisily mycommand args
if _rc != 0 {
    display as error "See output above for details"
    exit _rc
}
```

### Specific Error Handling

```stata
capture confirm variable myvar
if _rc == 111 {
    display as error "Variable myvar not found"
    exit 111
}
else if _rc != 0 {
    display as error "Unexpected error: `_rc'"
    exit _rc
}
```

### Graceful Fallback

```stata
capture some_command
if _rc != 0 {
    display as text "Note: some_command not available, using fallback"
    fallback_command
}
```

---

## Input Validation Patterns

### Variable Exists

```stata
capture confirm variable `varname'
if _rc != 0 {
    display as error "Variable `varname' not found"
    exit 111
}
```

### Variable is Numeric

```stata
capture confirm numeric variable `varname'
if _rc != 0 {
    display as error "Variable `varname' must be numeric"
    exit 109
}
```

### Variable is New

```stata
if "`generate'" != "" {
    capture confirm new variable `generate'
    if _rc != 0 {
        display as error "Variable `generate' already exists"
        exit 110
    }
}
```

### File Exists

```stata
capture confirm file "`filename'"
if _rc != 0 {
    display as error "File `filename' not found"
    exit 601
}
```

### No Observations

```stata
quietly count if `touse'
if r(N) == 0 {
    display as error "no observations"
    exit 2000
}
```

### Insufficient Observations

```stata
quietly count if `touse'
if r(N) < 10 {
    display as error "at least 10 observations required"
    exit 2001
}
```

---

## Custom Error Messages

### Standard Format

```stata
display as error "mycommand: specific error message"
display as error "  additional details on second line"
exit 198
```

### With Context

```stata
display as error "mycommand: variable `varname' must be numeric"
display as error "  found type: `:type `varname''"
exit 109
```

### Warning (Non-Fatal)

```stata
display as text "Warning: some condition detected"
display as text "  proceeding with caution..."
```

---

## Testing Error Conditions

```stata
* Test that error is correctly caught
capture mycommand with_invalid_args
if _rc == 0 {
    display as error "FAIL: Should have produced error"
    exit 1
}
if _rc != 198 {
    display as error "FAIL: Expected r(198), got r(`_rc')"
    exit 1
}
display as result "PASS: Correctly caught invalid syntax"
```

---

## Debugging Tips

### Get More Information

```stata
set trace on
set tracedepth 2
mycommand args
set trace off
```

### Check Variable Details

```stata
describe `varname'
codebook `varname', compact
```

### Check Return Values

```stata
mycommand args
return list
ereturn list
```

---

*See also: `_devkit/docs/syntax-reference.md` for error handling patterns*
