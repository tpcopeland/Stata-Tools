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

* Remove any installed rangematch copy so the per-suite `adopath ++` resolves to
* the local dev directory. `adopath ++` appends at lowest priority, so a copy in
* PLUS (SSC/GitHub or a stale net install) would otherwise silently shadow the
* package under test. Uninstall by index until none remain (uninstall-by-name
* fails rc=111 when multiple copies are present).
forvalues _i = 1/20 {
    capture ado uninstall rangematch
    if _rc != 0 continue, break
}

local suites ///
    test_install.do ///
    test_rangematch_basic.do ///
    test_rangematch_by.do ///
    test_rangematch_overlap.do ///
    test_rangematch_missing.do ///
    test_rangematch_v110.do ///
    test_rangematch_v120.do ///
    test_rangematch_v130.do ///
    test_rangematch_v140.do ///
    test_rangematch_v141.do ///
    test_rangematch_v144.do ///
    test_rangematch_v145.do ///
    test_rangematch_v147.do ///
    test_rangematch_v148.do ///
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
    test_rangematch_edge_topup.do ///
    test_rangematch_saving_matrix.do ///
    test_rangematch_labels.do ///
    test_rangematch_v16compat.do ///
    test_documentation_examples.do ///
    test_release_integrity.do

if "`mode'" == "full" {
    local suites `suites' validation_rangematch_oracle.do
    local suites `suites' validation_rangematch_manual.do
    local suites `suites' validation_rangematch_nearest.do
    local suites `suites' validation_rangematch_known_answers.do
}

local suite_count = 0
local pass_count = 0
local fail_count = 0
local failed_suites ""

foreach suite of local suites {
    local ++suite_count
    display as text _newline "Running `suite'"
    clear all
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

display as result _newline "RANGEMATCH QA SUMMARY"
display as result "Suites: `suite_count'"
display as result "Passed: `pass_count'"
display as result "Failed: `fail_count'"

if `fail_count' > 0 {
    display as error "Failed suites:`failed_suites'"
    display "RESULT: run_all suites=`suite_count' pass=`pass_count' fail=`fail_count'"
    log close _all
    exit 9
}

display as result "ALL RANGEMATCH QA SUITES PASSED"
display "RESULT: run_all suites=`suite_count' pass=`pass_count' fail=`fail_count'"
log close _all
