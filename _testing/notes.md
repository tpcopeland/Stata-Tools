# Stata Interpreter Development Notes

## Current Status (December 2025)

### Tests Passing
- `test_check.do` - All tests pass
- `test_compress_tc.do` - All tests pass
- `test_today.do` - All 13 tests pass

### Tests In Progress
- **tvtools tests** (`test_tvexpose.do`, `test_tvmerge.do`, `test_tvevent.do`) - Blocked by dosecuts error

## Current Bug: tvexpose "dosecuts() requires dose option"

### Problem
When running `test_tvexpose.do`, the `tvexpose` command displays:
```
dosecuts() requires the dose option
```

Even though:
1. `dosecuts` is not specified in the test command
2. After `syntax` parsing, `dosecuts` is correctly set to empty string
3. The condition `"`dosecuts'" != "" & "`dose'" == ""` evaluates to 0 (false) in isolation

### Debugging Done

1. **Confirmed syntax parsing works**: Created `debug_dosecuts.py` which shows:
   ```python
   interp.macros.set_local('dosecuts', '')
   interp.macros.set_local('dose', '')
   result = interp.expr_eval.evaluate('"`dosecuts\'" != "" & "`dose\'" == ""')
   # Result: 0 (correct - should not trigger error)
   ```

2. **Confirmed program body capture works**: Created `debug_program_body.py` which shows all commands at indices 18-25 are present:
   ```
   idx 19: command='if'  raw_line='if "`dosecuts\'" != "" & "`dose\'" == "" {'
   idx 20: command='display'  raw_line='noisily display as error "dosecuts() requires..."'
   ```

3. **Checked using/ handling**: Added code to `_cmd_syntax` to extract `using` filename and set local macro.

### Where to Look Next

The issue is likely in one of these areas:

1. **if-block execution during program run**: The `_cmd_if_block()` method - check if the condition is being evaluated correctly during actual program execution vs manual testing.

2. **Macro state during execution**: Something may be setting `dosecuts` to a non-empty value before the if-check runs.

3. **Program body iteration**: There was an earlier observation that line 19 was skipped during body iteration, but direct index access showed it present. Check the loop in `_execute_program()` that iterates through body_lines.

### Suggested Debug Approach

Add debug print statements to `_execute_program()` to trace:
1. What `body_lines` contains
2. Each command as it's executed
3. The macro state (especially `dosecuts` and `dose`) right before the if-block at index 19

```python
# In _execute_program(), around line 1250+, add:
print(f"DEBUG: Executing idx {i}, command={cmd.command}, raw_line={cmd.raw_line[:50]}")
if cmd.command == 'if':
    print(f"DEBUG: dosecuts='{self.macros.get_local('dosecuts')}'")
    print(f"DEBUG: dose='{self.macros.get_local('dose')}'")
```

## Key Files

### Modified in This Session
- `stata_interpreter/interpreter.py` - Added `using` clause handling for program execution

### Debug Scripts
- `_testing/debug_dosecuts.py` - Tests condition evaluation in isolation
- `_testing/debug_program_body.py` - Tests program body parsing

### Symlinks Created
- `_testing/data/tvtools` -> `../../tvtools`
- `_testing/data/mvp` -> `../../mvp`
- `_testing/data/check` -> `../../check`
- `_testing/data/compress_tc` -> `../../compress_tc`
- `_testing/data/today` -> `../../today`

## Previous Fixes (This Session)

1. **Quote preservation in parser**: Raw_line now preserves quotes around STRING tokens
2. **Expression tokenizer**: Fixed `5+3` being parsed wrong (scientific notation issue)
3. **Nested macro expansion**: Added balanced quote matching with `_find_matching_close()`
4. **Increment/decrement operators**: `local ++varname` now works
5. **else-if chains**: Rewrote `_cmd_if_block()` to handle `else if` properly
6. **Comparison operators in args**: Added `!`, `<`, `>`, etc. to argument parsing
7. **using/ clause**: Added handling in `_execute_program()` and `_cmd_syntax()`

## Remaining Tests to Run
- `test_tvexpose.do` - Blocked by dosecuts bug
- `test_tvmerge.do`
- `test_tvevent.do`
- `test_datamap.do`
- `test_mvp.do`
- Any other test files in `_testing/`

## Notes on Test Approach
- Run tests one at a time
- Commit after each successful test
- Skip consort files and graph options (not MVP)
- Goal: Execute every bit of syntax in all .ado and .do files
