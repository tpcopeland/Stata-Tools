# Functional Testing Workflow

## Test File Structure

```stata
clear all
set more off
version 16.0

* Configuration for test runner
if "$RUN_TEST_QUIET" == "" global RUN_TEST_QUIET = 0
if "$RUN_TEST_MACHINE" == "" global RUN_TEST_MACHINE = 0
if "$RUN_TEST_NUMBER" == "" global RUN_TEST_NUMBER = 0

local quiet = $RUN_TEST_QUIET
local machine = $RUN_TEST_MACHINE
local run_only = $RUN_TEST_NUMBER

* Path configuration
if "`c(os)'" == "Unix" {
    global STATA_TOOLS_PATH "~/Stata-Tools"
}
else {
    global STATA_TOOLS_PATH "`c(pwd)'"
}

* Install package
capture net uninstall mycommand
quietly net install mycommand, from("${STATA_TOOLS_PATH}/mycommand")

* Test counters
local test_count = 0
local pass_count = 0
local fail_count = 0

* ... tests ...

* Summary
if `fail_count' > 0 {
    exit 1
}
```

## Running Tests

```bash
# Single test file
stata-mp -b do _devkit/_testing/test_mycommand.do

# Specific test number
# Set global before running: global RUN_TEST_NUMBER = 3

# Check log for errors
grep -E "^r\([0-9]+" test_mycommand.log
```

## Checklist

- [ ] File named `test_COMMANDNAME.do`
- [ ] Standard header with run modes
- [ ] Package installation at start
- [ ] Test counters initialized
- [ ] Each test wrapped in `capture {}` block
- [ ] PASS/FAIL messages always shown
- [ ] Summary section at end
- [ ] Exit code reflects pass/fail
- [ ] Edge cases covered
