clear all
set more off
version 16.0

* run_all.do — complete QA suite for iivw
* Works whether invoked from package root or from qa/ directly:
*   stata-mp -b do iivw/qa/run_all.do   (from Stata-Tools root)
*   stata-mp -b do run_all.do           (from iivw/qa/)

* Resolve qa directory from the invocation's cwd
local here "`c(pwd)'"
local basename = substr("`here'", strrpos("`here'", "/") + 1, .)
if "`basename'" == "qa" {
    local qa_dir "`here'"
}
else {
    * Assume Stata-Tools root or similar
    local qa_dir "`here'/iivw/qa"
}

* Each sub-suite's bootstrap uses `c(pwd)' to find the package — run from qa
cd "`qa_dir'"

local suites          ///
    test_iivw         ///
    test_iivw_expanded ///
    validation_iivw    ///
    validation_iivw_expanded

local suite_pass = 0
local suite_fail = 0
local failed_suites ""

foreach f of local suites {
    capture confirm file "`qa_dir'/`f'.do"
    if _rc {
        display as text "  SKIP: `f'.do not found"
        continue
    }
    display _newline as text "{hline 70}"
    display as result "Running: `f'.do"
    display as text "{hline 70}"
    * Run in fresh state; each suite handles its own install/uninstall
    capture noisily do "`qa_dir'/`f'.do"
    if _rc {
        local ++suite_fail
        local failed_suites "`failed_suites' `f'"
        display as error "FAILED: `f'.do (rc=`=_rc')"
    }
    else {
        local ++suite_pass
        display as result "PASSED: `f'.do"
    }
    * Restore cwd after each suite (in case one cd's away)
    cd "`qa_dir'"
}

display _newline as text "{hline 70}"
display as result "QA Summary: `suite_pass' suites passed, `suite_fail' failed"
display as text "{hline 70}"
if `suite_fail' > 0 {
    display as error "Failed suites:`failed_suites'"
    exit 1
}

* crossval_iivw.do runs separately — requires R reference CSVs staged first
display as text "Note: crossval_iivw.do must be run separately after generating R references"
