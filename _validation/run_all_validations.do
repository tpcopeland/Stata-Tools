/*******************************************************************************
* run_all_validations.do
*
* Purpose: Run all validation tests and report summary
*
* Author: Claude Code
* Date: 2025-12-18
*******************************************************************************/

clear all
set more off
version 16.0

display _n "{hline 70}"
display "RUNNING ALL VALIDATION TESTS"
display "{hline 70}"
display "Start time: `c(current_date)' `c(current_time)'"
display "{hline 70}"

local validation_files "validation_tvtools_boundary validation_tvevent validation_tvexpose validation_tvmerge"

local total_pass = 0
local total_fail = 0
local failed_files ""

foreach vfile of local validation_files {
    display _n "{hline 70}"
    display "Running: `vfile'.do"
    display "{hline 70}"

    capture noisily do `vfile'.do

    if _rc == 0 {
        display as result "  `vfile': PASSED"
        local ++total_pass
    }
    else {
        display as error "  `vfile': FAILED (error `=_rc')"
        local ++total_fail
        local failed_files "`failed_files' `vfile'"
    }
}

display _n "{hline 70}"
display "VALIDATION SUMMARY"
display "{hline 70}"
display "Files passed: `total_pass'"
if `total_fail' > 0 {
    display as error "Files failed: `total_fail'"
    display as error "Failed files:`failed_files'"
}
else {
    display "Files failed: `total_fail'"
}
display "{hline 70}"
display "End time: `c(current_date)' `c(current_time)'"
display "{hline 70}"

if `total_fail' > 0 {
    exit 1
}
