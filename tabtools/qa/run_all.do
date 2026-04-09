* run_all.do — Canonical full-suite QA runner for tabtools
* Usage: cd into qa/ directory, then: stata-mp -b do run_all.do

clear all
set more off

local qa_dir "`c(pwd)'"
local pkg_dir = subinstr("`qa_dir'", "/qa", "", 1)

capture ado uninstall tabtools
quietly net install tabtools, from("`pkg_dir'") replace

local n_files = 0
local n_pass = 0
local n_fail = 0
local failed_files ""

capture log close _run_all
log using "run_all.log", replace text name(_run_all)

foreach f in ///
    test_tabtools.do ///
    test_tabtools_v101.do ///
    test_regression_fixes.do ///
    test_new_commands.do ///
    test_coverage_gaps.do ///
    test_hrtab.do ///
    test_comptab.do ///
    test_effecttab_iptw.do ///
    test_effecttab_advanced.do ///
    test_regtab_mixed_stats.do ///
    test_regtab_multilevel.do ///
    test_v140_features.do ///
    test_v150_features.do ///
    test_v160_features.do ///
    test_v170_features.do ///
    test_excel_validation.do ///
    test_stress.do ///
    test_residual_risks.do ///
    validation_tabtools.do ///
    validation_calculations.do ///
    validation_hrtab.do ///
    validation_excel_accuracy.do ///
    validation_output_quality.do ///
    crossval_tabtools.do ///
{
    local ++n_files
    display _newline
    display as text "=== Running: `f' ==="
    capture noisily do "`f'"
    if _rc == 0 {
        local ++n_pass
        display as result "  PASSED: `f'"
    }
    else {
        local ++n_fail
        local failed_files "`failed_files' `f'"
        display as error "  FAILED: `f' (rc=`=_rc')"
    }
}

display _newline
display as result "=== Suite Summary: `n_pass'/`n_files' passed, `n_fail' failed ==="
if `n_fail' > 0 {
    display as error "Failed files:`failed_files'"
    exit 1
}
else {
    display as result "ALL QA FILES PASSED"
}

log close _run_all
