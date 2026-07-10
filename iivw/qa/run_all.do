clear all
set more off
version 16.0

* run_all.do — complete QA suite for iivw
* Works whether invoked from package root or from qa/ directly:
*   stata-mp -b do iivw/qa/run_all.do   (from Stata-Tools root)
*   stata-mp -b do run_all.do           (from iivw/qa/)
*   stata-mp -b do run_all.do quick     (skip R cross-validation lanes)
*   stata-mp -b do run_all.do sim       (run simulation gates: Scenarios A-E)

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

ado dir
capture ado uninstall iivw

if "`mode'" == "sim" {
    local suites sim_scenarios_abc sim_scenario_d sim_scenario_e
}
else {
    local suites          ///
        test_iivw         ///
        test_iivw_expanded ///
        validation_iivw_recovery ///
        validation_iivw_recovery_extended ///
        validation_iivw_recovery_extended2 ///
        validation_iivw    ///
        validation_iivw_expanded ///
        validation_iivw_known_answers ///
        test_iivw_balance ///
        test_iivw_performance ///
        test_iivw_weight_validation_guards ///
        test_iivw_weight_adversarial ///
        test_iivw_psdash_contract ///
        test_iivw_fit_adversarial ///
        test_iivw_fit_unweighted ///
        test_iivw_exogtest ///
        test_iivw_diagnose ///
        test_iivw_reporting_exports ///
        test_iivw_diagnostic_workflow ///
        test_iivw_exogtest_adversarial ///
        validation_iivw_diagnostics_known_answers ///
        test_iivw_v105_regressions ///
        test_iivw_v106_regressions ///
        test_iivw_v123_regressions ///
        test_iivw_v130_regressions ///
        test_iivw_v131_regressions ///
        test_iivw_v180_regressions ///
        test_iivw_v190_regressions ///
        test_iivw_v191_regressions ///
        test_iivw_v192_regressions ///
        test_iivw_v193_regressions ///
        test_iivw_v194_regressions ///
        test_iivw_v196_regressions ///
        test_iivw_final_adversarial ///
        test_iivw_release_adversarial
}

if "`mode'" == "full" {
    * Stata's `shell` never propagates the child's exit status: _rc is 0 even when
    * the command is missing or exits nonzero. Detect R failure with a sentinel the
    * shell only creates after Rscript succeeds. Without this, a missing R or R
    * package leaves the tracked reference CSVs stale and the crossval lanes pass
    * against outdated oracles.
    foreach rsrc in crossval_irreglong crossval_fiptiw {
        display as text "Generating R references from `rsrc'.R..."
        capture erase "`qa_dir'/`rsrc'.ok"
        capture confirm file "`qa_dir'/`rsrc'.ok"
        if !_rc {
            display as error "FAILED: cannot remove stale sentinel `qa_dir'/`rsrc'.ok"
            exit 603
        }
        shell cd "`repo_dir'" && Rscript iivw/qa/`rsrc'.R && touch iivw/qa/`rsrc'.ok
        capture confirm file "`qa_dir'/`rsrc'.ok"
        if _rc {
            display as error "FAILED: `rsrc'.R did not run to completion"
            display as error "  full mode regenerates the crossval reference CSVs and requires R with"
            display as error "  the IrregLong, geepack, survival, and nlme packages installed."
            display as error "  Refusing to continue: the tracked reference CSVs would be stale."
            exit 198
        }
        capture erase "`qa_dir'/`rsrc'.ok"
    }

    local suites `suites' ///
        sim_scenarios_abc ///
        sim_scenario_d ///
        sim_scenario_e ///
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
