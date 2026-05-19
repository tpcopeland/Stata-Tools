clear all
set more off
version 16.0

* run_all.do — complete QA suite for iivw
* Works whether invoked from package root or from qa/ directly:
*   stata-mp -b do iivw/qa/run_all.do   (from Stata-Tools root)
*   stata-mp -b do run_all.do           (from iivw/qa/)
*   stata-mp -b do run_all.do quick     (skip R cross-validation lanes)
*   stata-mp -b do run_all.do sim       (run simulation gates: Scenarios A-D)

args mode
if "`mode'" == "" local mode "full"
if !inlist("`mode'", "full", "quick", "sim") {
    display as error "mode must be full, quick, or sim"
    exit 198
}

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
local pkg_dir = subinstr("`qa_dir'", "/qa", "", 1)
local repo_dir = subinstr("`pkg_dir'", "/iivw", "", 1)

* Each sub-suite's bootstrap uses `c(pwd)' to find the package — run from qa
cd "`qa_dir'"

if "`mode'" == "sim" {
    local suites sim_scenarios_abc sim_scenario_d
}
else {
    local suites          ///
        test_iivw         ///
        test_iivw_expanded ///
        validation_iivw    ///
        validation_iivw_expanded ///
        validation_iivw_known_answers ///
        test_iivw_weight_validation_guards ///
        test_iivw_weight_adversarial ///
        test_iivw_fit_adversarial ///
        test_iivw_v105_regressions ///
        test_iivw_v106_regressions ///
        test_iivw_release_adversarial
}

if "`mode'" == "full" {
    display as text "Generating R references for crossval_iivw.do..."
    capture noisily shell cd "`repo_dir'" && Rscript iivw/qa/crossval_irreglong.R
    if _rc {
        display as error "FAILED: crossval_irreglong.R (rc=`=_rc')"
        exit _rc
    }
    capture noisily shell cd "`repo_dir'" && Rscript iivw/qa/crossval_fiptiw.R
    if _rc {
        display as error "FAILED: crossval_fiptiw.R (rc=`=_rc')"
        exit _rc
    }

    local suites `suites' ///
        sim_scenarios_abc ///
        sim_scenario_d ///
        crossval_iivw ///
        crossval_iivw_external
}

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
if "`mode'" == "quick" {
    display as text "Note: quick mode skipped R cross-validation lanes"
}
