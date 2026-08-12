clear all
version 16.0
set more off

* Package uninstall is handled inside _swimlane_qa_bootstrap after PLUS and
* PERSONAL are sandboxed for each suite. Each suite runs ado dir,
* capture ado uninstall swimlane, and net install from the local package path.

args mode
if "`mode'" == "" local mode "full"
if !inlist("`mode'", "quick", "core", "full") {
    display as error "mode must be quick, core, or full"
    exit 198
}

local quick "test_basic.do test_return_values.do test_errors.do test_data_preservation.do test_regressions.do"
local core "`quick' validation_canonical_tables.do test_export.do test_options.do test_features.do test_density.do test_documentation_examples.do"
local full "`core'"
local suites "``mode''"

local suite_count = 0
local suite_pass = 0
local suite_fail = 0

foreach suite of local suites {
    local ++suite_count
    display as text "Running `suite'"
    capture noisily do "`suite'"
    if _rc == 0 {
        local ++suite_pass
        display as result "  PASS: `suite'"
    }
    else {
        local ++suite_fail
        display as error "  FAIL: `suite' (error `=_rc')"
    }
}

display as result "Suites: `suite_pass'/`suite_count' passed, `suite_fail' failed"
display "RESULT: run_all tests=`suite_count' pass=`suite_pass' fail=`suite_fail'"
if `suite_fail' > 0 exit 1
