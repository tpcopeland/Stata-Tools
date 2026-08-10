clear all
set more off
version 16.0

* run_all.do — complete QA suite for iivw
*
* Works whether invoked from package root or from qa/ directly:
*   stata-mp -b do iivw/qa/run_all.do   (from Stata-Tools root)
*   stata-mp -b do run_all.do           (from iivw/qa/)
*   stata-mp -b do run_all.do quick     (fast contract/release smoke)
*   stata-mp -b do run_all.do core      (all supported Stata gates)
*   stata-mp -b do run_all.do full      (core plus fresh R parity)
*   stata-mp -b do run_all.do legacy    (legacy estimator constructions)
*   stata-mp -b do run_all.do sensitivity (post-hoc simulation envelopes)
*   stata-mp -b do run_all.do sim       (backward-compatible sensitivity alias)
*
* READING THE RESULT (important)
* ------------------------------
* `stata-mp -b do' returns process exit status 0 unconditionally on this
* platform -- verified: `exit 1', `error 198', a failed command and a failed
* `assert' all yield shell rc 0. The shell exit code is therefore NOT a usable
* signal and no caller may gate on it. This runner writes an unambiguous
* machine-readable verdict to BOTH:
*   - the log, as a final line: "RUNALL: status=PASS|FAIL suites=N pass=N fail=N"
*   - a status file, qa/run_all_status.txt, whose first line is PASS or FAIL
* CI and humans must read one of those two, never `$?'.

args mode
if "`mode'" == "" local mode "full"
if !inlist("`mode'", "full", "core", "quick", "legacy", ///
    "sensitivity", "sim") {
    display as error ///
        "mode must be quick, core, full, legacy, sensitivity, or sim"
    exit 198
}

* -----------------------------------------------------------------------------
* Resolve the qa directory from the invocation's cwd.
* Strip the known suffix by LENGTH, never with first-occurrence subinstr(): a
* path such as /tmp/qa-audit-42/iivw/qa contains "/qa" early, and
* subinstr(...,"/qa","",1) strips that first hit and derives a package directory
* that does not exist.
* -----------------------------------------------------------------------------
local here "`c(pwd)'"
local basename = substr("`here'", strrpos("`here'", "/") + 1, .)
if "`basename'" == "qa" {
    local qa_dir "`here'"
}
else {
    local qa_dir "`here'/iivw/qa"
}
capture confirm file "`qa_dir'/run_all.do"
if _rc {
    display as error "could not locate the iivw qa directory (tried `qa_dir')"
    exit 601
}
local pkg_dir  = substr("`qa_dir'",  1, strlen("`qa_dir'")  - strlen("/qa"))
local repo_dir = substr("`pkg_dir'", 1, strlen("`pkg_dir'") - strlen("/iivw"))

* Explicit release-only exclusion. This file is intentionally not appended to
* any ordinary lane: its preregistered release mode is a multi-day simulation.
local release_only_suites validation_iivw_inference

* Each sub-suite's bootstrap uses `c(pwd)' to find the package — run from qa
cd "`qa_dir'"

* -----------------------------------------------------------------------------
* SYSDIR SANDBOX
* -----------------------------------------------------------------------------
* Most suites `net install' iivw, and several uninstall/replace tabtools.
* Run against the default sysdirs, that mutates the user's real ado tree: an
* audit run left the tracker pointing iivw at /tmp and removed tabtools outright.
* Redirect PLUS and PERSONAL into a scratch tree for the whole run and restore
* them on every exit path, so QA can never touch the user's installation.
local orig_plus     "`c(sysdir_plus)'"
local orig_personal "`c(sysdir_personal)'"

tempfile _sbstub
local sandbox "`_sbstub'_sysdir"
capture mkdir "`sandbox'"
capture mkdir "`sandbox'/plus"
capture mkdir "`sandbox'/personal"
capture confirm file "`sandbox'/plus"
if _rc {
    display as error "could not create the QA sysdir sandbox at `sandbox'"
    exit 603
}
sysdir set PLUS     "`sandbox'/plus"
sysdir set PERSONAL "`sandbox'/personal"
display as text "QA sysdir sandbox: `sandbox'"
display as text "  the user's PLUS/PERSONAL are untouched and restored on exit"

ado dir
capture ado uninstall iivw

* -----------------------------------------------------------------------------
* CURATED SUITE LISTS
* -----------------------------------------------------------------------------
* quick is a strict subset of core, and core is a strict subset of full.
* Legacy constructions and post-hoc simulation envelopes are deliberately
* outside full so they cannot inflate the supported-estimator gate.
local quick_suites ///
    test_iivw ///
    test_iivw_expanded ///
    test_iivw_replay ///
    test_iivw_state_contract ///
    test_iivw_stale_state ///
    test_iivw_ownership ///
    test_iivw_sample_contract ///
    test_iivw_phase2_contract ///
    test_iivw_inference_contract ///
    test_iivw_v341_regressions ///
    test_iivw_balance ///
    test_iivw_performance ///
    test_iivw_weight_validation_guards ///
    test_iivw_psdash_contract ///
    test_iivw_fit_adversarial ///
    test_iivw_fit_unweighted ///
    test_iivw_exogtest ///
    test_iivw_diagnose ///
    test_iivw_reporting_exports ///
    test_iivw_literature_invariants ///
    validation_iivw_iptw_oracle ///
    validation_iivw_fiptiw_recovery ///
    test_iivw_interval_contract ///
    test_iivw_failclosed ///
    test_help_examples ///
    test_iivw_final_adversarial ///
    test_iivw_release_adversarial

local core_suites ///
    test_iivw ///
    test_iivw_expanded ///
    test_iivw_replay ///
    test_iivw_state_contract ///
    test_iivw_stale_state ///
    test_iivw_ownership ///
    test_iivw_sample_contract ///
    test_iivw_phase2_contract ///
    test_iivw_inference_contract ///
    test_iivw_invariance ///
    test_iivw_bs_frame_contract ///
    validation_iivw_recovery ///
    validation_iivw ///
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
    test_iivw_literature_invariants ///
    test_iivw_ties ///
    test_iivw_tie_default ///
    validation_iivw_iptw_oracle ///
    validation_iivw_fiptiw_recovery ///
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
    test_iivw_v200_phase0 ///
    test_iivw_v200_phase1 ///
    test_iivw_v200_phase2 ///
    test_iivw_v200_phase3 ///
    test_iivw_v200_phase3b ///
    test_iivw_v200_coverage ///
    test_iivw_v200_qagate ///
    test_iivw_v310_regressions ///
    test_iivw_v341_regressions ///
    test_iivw_interval_contract ///
    test_iivw_failclosed ///
    test_iivw_coverage_gate ///
    test_iivw_cr_ladder ///
    test_iivw_stacked ///
    test_help_examples ///
    test_iivw_final_adversarial ///
    test_iivw_release_adversarial

local legacy_suites ///
    validation_iivw_recovery_extended ///
    validation_iivw_recovery_extended2

local sensitivity_suites ///
    sim_scenarios_abc ///
    sim_scenario_d ///
    sim_scenario_e

if "`mode'" == "quick" {
    local suites `quick_suites'
}
else if inlist("`mode'", "sensitivity", "sim") {
    local suites `sensitivity_suites'
}
else if "`mode'" == "legacy" {
    local suites `legacy_suites'
}
else {
    local suites `core_suites'
}

if "`mode'" == "full" {
    * Stata's `shell' never propagates the child's exit status: _rc is 0 even
    * when the command is missing or exits nonzero. Detect R failure with a
    * sentinel the shell only creates after Rscript succeeds. Without this, a
    * missing R or R package leaves the tracked reference CSVs stale and the
    * crossval lanes pass against outdated oracles.
    foreach rsrc in crossval_irreglong crossval_fiptiw {
        display as text "Generating R references from `rsrc'.R..."
        capture erase "`qa_dir'/`rsrc'.ok"
        capture confirm file "`qa_dir'/`rsrc'.ok"
        if !_rc {
            display as error "FAILED: cannot remove stale sentinel `qa_dir'/`rsrc'.ok"
            sysdir set PLUS     "`orig_plus'"
            sysdir set PERSONAL "`orig_personal'"
            exit 603
        }
        * The sentinel is written by the R script's own last statement, not by a
        * shell `touch': `touch' is Unix-only, and chaining it with && only
        * proves Rscript exited 0, not that it reached the end of the script.
        shell cd "`repo_dir'" && Rscript iivw/qa/`rsrc'.R
        capture confirm file "`qa_dir'/`rsrc'.ok"
        if _rc {
            display as error "FAILED: `rsrc'.R did not run to completion"
            display as error "  full mode regenerates the crossval reference CSVs and requires R"
            display as error "  with these packages installed:"
            display as error "    IrregLong, geepack, survival, nlme, ipw, cobalt"
            display as error "  ipw and cobalt are needed by crossval_iivw_external_refs.R and were"
            display as error "  missing from this list when the external lane false-greened."
            display as error "  Refusing to continue: the reference CSVs would be stale."
            sysdir set PLUS     "`orig_plus'"
            sysdir set PERSONAL "`orig_personal'"
            exit 198
        }
        capture erase "`qa_dir'/`rsrc'.ok"
    }

    local suites `suites' crossval_iivw crossval_iivw_external
}

* -----------------------------------------------------------------------------
* PUBLISH THE CURATED LIST FOR THE SHELL-LEVEL SENTINEL GATE
* -----------------------------------------------------------------------------
* This runner grades a suite on `_rc' alone, which cannot see a suite that
* prints "RESULT: ... fail=3" and then exits 0, or one that prints no sentinel
* at all. Verifying the sentinel from inside this process is not possible: ten
* suites call `log close _all', which would close any nested capture log this
* file opened and turn a real pass into a parse failure. The check therefore
* runs at the shell boundary (run_all.sh) against the completed run_all.log,
* exactly as finegray/qa/run_all.sh does.
*
* The lane lists live here and must not be duplicated in shell, so write the
* resolved list out instead. run_all.sh requires exactly one well-formed
* sentinel per name below.
capture file close _expected
file open _expected using "`qa_dir'/run_all_expected.txt", write replace
file write _expected "lane=`mode'" _n
foreach f of local suites {
    file write _expected "`f'" _n
}
file close _expected

* -----------------------------------------------------------------------------
* RUN
* -----------------------------------------------------------------------------
local suite_pass = 0
local suite_fail = 0
local failed_suites ""
local missing_suites ""

foreach f of local suites {
    * A curated suite that is not on disk is a FAILURE, not a skip. Printing
    * "SKIP" and continuing let a typo or an accidental deletion silently shrink
    * coverage while the aggregate stayed green.
    capture confirm file "`qa_dir'/`f'.do"
    if _rc {
        local ++suite_fail
        local failed_suites "`failed_suites' `f'"
        local missing_suites "`missing_suites' `f'"
        display as error "MISSING: `qa_dir'/`f'.do is in the curated list but not on disk"
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

* -----------------------------------------------------------------------------
* RESTORE THE USER'S SYSDIRS (success and failure alike)
* -----------------------------------------------------------------------------
sysdir set PLUS     "`orig_plus'"
sysdir set PERSONAL "`orig_personal'"

* -----------------------------------------------------------------------------
* VERDICT
* -----------------------------------------------------------------------------
local n_suites : word count `suites'
local status = cond(`suite_fail' > 0, "FAIL", "PASS")

display _newline as text "{hline 70}"
display as result "QA Summary: `suite_pass' suites passed, `suite_fail' failed"
display as text "{hline 70}"
if "`missing_suites'" != "" {
    display as error "Curated suites missing from disk:`missing_suites'"
}
if `suite_fail' > 0 {
    display as error "Failed suites:`failed_suites'"
}
if "`mode'" == "quick" {
    display as text "Note: quick is the fast contract/release subset of core"
}
if inlist("`mode'", "sensitivity", "sim") {
    display as text ///
        "Note: sensitivity results are post-hoc regression envelopes, not validation gates"
}

* The shell exit code is unusable (always 0). Write the verdict where a caller
* can actually read it.
capture file close _runall
file open _runall using "`qa_dir'/run_all_status.txt", write replace
file write _runall "`status'" _n
file write _runall "mode=`mode'" _n
file write _runall "suites=`n_suites' pass=`suite_pass' fail=`suite_fail'" _n
if "`failed_suites'" != "" {
    file write _runall "failed=`failed_suites'" _n
}
file close _runall

display as text ///
    "RESULT: run_all tests=`n_suites' pass=`suite_pass' fail=`suite_fail' skip=0"
display as text ///
    "RUNALL: status=`status' suites=`n_suites' pass=`suite_pass' fail=`suite_fail'"

if `suite_fail' > 0 {
    exit 1
}
