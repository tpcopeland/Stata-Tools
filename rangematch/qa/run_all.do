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

* Remove every installed rangematch copy so the per-suite install resolves to
* the local dev directory, and so test_install.do's bare `net install' (no
* replace) does not fail r(602) against a stale PLUS copy.
*
* The previous version of this block claimed to "uninstall by index until none
* remain (uninstall-by-name fails rc=111 when multiple copies are present)" but
* then called `ado uninstall rangematch' -- by NAME -- inside
* `if _rc != 0 continue, break'. So in the very situation the comment describes
* it broke on its first pass and removed NOTHING, while reading as if it had.
*
* Uninstalling by index does not work either: measured on stata-mp 17, `ado
* uninstall <n>' returns r(111) "package not found" even for a single, freshly
* installed package whose index `ado dir' printed one line earlier. The index
* form is not a usable API here, so do not reintroduce it.
*
* What works is `ado uninstall <name>' (verified rc=0 for one copy, and for two
* copies installed from different source directories). It is not guaranteed
* against a stata.trk carrying duplicate orphan entries for one package name,
* which is why the sweep is VERIFIED below rather than assumed.
forvalues _i = 1/20 {
    capture ado uninstall rangematch
    if _rc != 0 continue, break
}

* Prove the sweep actually happened. A surviving PLUS copy shadows the package
* under test and makes test_install.do's bare `net install' fail r(602); both
* are silent-wrong-result modes for the lane, so fail loudly and early rather
* than report a green (or confusingly red) lane for the wrong reason.
capture which rangematch
if _rc == 0 {
    display as error ///
        "an installed rangematch copy survived the uninstall sweep; lane aborted"
    display as error ///
        "run {bf:ado dir} to list the copies; if {bf:ado uninstall rangematch}"
    display as error ///
        "fails r(111), stata.trk holds duplicate entries for this package and"
    display as error ///
        "needs repair before the lane can prove which code it tested"
    exit 459
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
