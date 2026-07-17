clear all
version 16.1

args mode
if "`mode'" == "" local mode "full"
if !inlist("`mode'", "full", "quick") {
    display as error "mode must be full or quick"
    exit 198
}

capture log close _all
log using "run_all.log", replace text nomsg

* Sandbox PLUS and PERSONAL under c(tmpdir) and install the package under test
* once, before any suite runs (RM-I17).
*
* This lane used to sweep `ado uninstall rangematch' against the caller's REAL
* PLUS tree, on the reasoning that a stale installed copy would shadow the code
* under review. The reasoning was sound and the remedy was not: running the
* documented gate silently uninstalled the user's own rangematch, and a lane
* has no business editing the environment of the person running it. Isolating
* the trees removes the shadow AND the collateral damage, so no sweep is needed.
*
* Do not reintroduce an index-based sweep here. Measured on stata-mp 17,
* `ado uninstall <n>' returns r(111) "package not found" even for a single,
* freshly installed package whose index `ado dir' printed one line earlier --
* the index form is not a usable API.
quietly do "`c(pwd)'/_rangematch_qa_common.do"
_rm_qa_bootstrap
local pkg_dir "`r(pkg_dir)'"

* Record the caller's real trees so the summary can prove they came back.
local real_plus "$RM_QA_OLD_PLUS"
local real_personal "$RM_QA_OLD_PERSONAL"

local suites ///
    test_install.do ///
    test_rangematch_basic.do ///
    test_rangematch_by.do ///
    test_rangematch_overlap.do ///
    test_rangematch_missing.do ///
    test_rangematch_v110.do ///
    test_rangematch_v120.do ///
    test_rangematch_v130.do ///
    test_rangematch_regress_options_output.do ///
    test_rangematch_regress_performance.do ///
    test_rangematch_regress_backend_selection.do ///
    test_rangematch_regress_sweep_options.do ///
    test_rangematch_regress_distance.do ///
    test_rangematch_regress_mata_surface.do ///
    test_rangematch_v132.do ///
    test_rangematch_v133.do ///
    test_rangematch_v101.do ///
    test_rangematch_missing_option.do ///
    test_rangematch_missing_option_extra.do ///
    test_rangematch_abbrev.do ///
    test_rangematch_adversarial.do ///
    test_rangematch_return_contract.do ///
    test_rangematch_display_contract.do ///
    test_rangematch_routing_contract.do ///
    test_rangematch_backend_equivalence.do ///
    test_rangematch_backend_diff.do ///
    test_rangematch_missing_using.do ///
    test_rangematch_float_warn.do ///
    test_rangematch_ties_random.do ///
    test_rangematch_overlap_inverted.do ///
    test_rangematch_provenance.do ///
    test_rangematch_interval_validity.do ///
    test_rangematch_group_types.do ///
    test_rangematch_frame_safety.do ///
    test_rangematch_internal_names.do ///
    test_rangematch_option_grammar.do ///
    test_rangematch_missing_key_labels.do ///
    test_rangematch_edge_topup.do ///
    test_rangematch_saving_matrix.do ///
    test_rangematch_labels.do ///
    test_rangematch_v16compat.do ///
    test_documentation_examples.do ///
    test_rangematch_doc_contract.do ///
    test_rangematch_demo_contract.do ///
    test_rangematch_lane_isolation.do ///
    test_rangematch_bench_smoke.do ///
    test_rangematch_sthlp_render.do ///
    test_release_integrity.do

if "`mode'" == "full" {
    local suites `suites' validation_rangematch_oracle.do
    local suites `suites' validation_rangematch_manual.do
    local suites `suites' validation_rangematch_nearest.do
    local suites `suites' validation_rangematch_known_answers.do
    local suites `suites' validation_rangematch_overlap_oracle.do
}

local suite_count = 0
local pass_count = 0
local fail_count = 0
local failed_suites ""

foreach suite of local suites {
    local ++suite_count
    display as text _newline "Running `suite'"
    clear all

    * Hand every suite the same adopath. A suite that appends the source
    * directory and never removes it changes what the NEXT suite resolves, so
    * the lane's result would depend on suite order -- which is exactly how the
    * demo-contract suite came to need a private adopath workaround.
    capture adopath - "`pkg_dir'"

    capture noisily do "`suite'"
    local rc = _rc
    if `rc' == 0 {
        local ++pass_count
        display as result "PASS: `suite'"
    }
    else {
        local ++fail_count
        local failed_suites `"`failed_suites' `suite'(`rc')"'
        display as error "FAIL: `suite' (rc=`rc')"
    }
}

* Require a terminal sentinel from every suite the lane just called green
* (RM-I20).
*
* rc=0 alone cannot distinguish a suite that ran to completion from one whose
* log was truncated or that exited early having executed a fraction of its
* tests. Every suite emits one `RESULT: <name> tests=N pass=N fail=N' line as
* its last act, so a passing suite with no sentinel is a suite that did not
* finish -- and this lane will no longer report it as green.
*
* Close the log to read it back, scan, then reopen with append to record the
* verdict. The scan must anchor at column 0: `text' logs echo each command, so
* the ECHO of `display "RESULT: ..."' also contains the token "RESULT: " and a
* naive substring search matches the suite's own source line whether or not it
* ever executed -- the search would then confirm itself.
log close _all

mata:
string scalar _rm_missing_sentinels(string scalar logpath)
{
    real scalar fh
    string scalar line, cur, missing
    real scalar seen

    fh = fopen(logpath, "r")
    cur = ""
    seen = 0
    missing = ""
    while ((line = fget(fh)) != J(0, 0, "")) {
        // Real output starts at column 0; an echoed command starts with ". ".
        if (substr(line, 1, 8) == "Running ") {
            if (cur != "" & !seen) missing = missing + " " + cur
            cur = strtrim(substr(line, 9, .))
            seen = 0
        }
        else if (substr(line, 1, 8) == "RESULT: ") {
            seen = 1
        }
        else if (substr(line, 1, 6) == "FAIL: ") {
            // A failing suite is already reported by rc; do not double-report
            // it as a missing sentinel.
            seen = 1
        }
    }
    if (cur != "" & !seen) missing = missing + " " + cur
    fclose(fh)
    return(strtrim(missing))
}
end

mata: st_local("no_sentinel", _rm_missing_sentinels("run_all.log"))
capture mata: mata drop _rm_missing_sentinels()

log using "run_all.log", append text nomsg

* Restore the caller's real ado trees, on the pass path and the fail path
* alike, and PROVE the restore happened. A teardown that silently no-ops would
* leave the user pointed at a c(tmpdir) sandbox that the OS later deletes --
* their rangematch would simply stop resolving, with nothing to point at.
quietly do "`c(pwd)'/_rangematch_qa_common.do"
_rm_qa_teardown
capture adopath - "`pkg_dir'"

local restore_ok = 1
if "`c(sysdir_plus)'" != "`real_plus'" {
    display as error "PLUS not restored: is `c(sysdir_plus)', want `real_plus'"
    local restore_ok = 0
}
if "`c(sysdir_personal)'" != "`real_personal'" {
    display as error "PERSONAL not restored: is `c(sysdir_personal)', want `real_personal'"
    local restore_ok = 0
}

display as result _newline "RANGEMATCH QA SUMMARY"
display as result "Suites: `suite_count'"
display as result "Passed: `pass_count'"
display as result "Failed: `fail_count'"

if !`restore_ok' {
    display as error "ado-tree restore FAILED; lane result is not trustworthy"
    display "RESULT: run_all suites=`suite_count' pass=`pass_count' fail=`fail_count'"
    log close _all
    exit 459
}

if `"`no_sentinel'"' != "" {
    display as error "suites finished without a terminal RESULT: sentinel:`no_sentinel'"
    display as error "a suite that exits 0 without its sentinel did not run to completion"
    display "RESULT: run_all suites=`suite_count' pass=`pass_count' fail=`fail_count'"
    log close _all
    exit 9
}

if `fail_count' > 0 {
    display as error "Failed suites:`failed_suites'"
    display "RESULT: run_all suites=`suite_count' pass=`pass_count' fail=`fail_count'"
    log close _all
    exit 9
}

display as result "ALL RANGEMATCH QA SUITES PASSED"
display "RESULT: run_all suites=`suite_count' pass=`pass_count' fail=`fail_count'"
log close _all
