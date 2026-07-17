* test_msm_abbrev_reload.do - Regression guards for option-abbreviation
* contracts and bundled-subprogram reload safety.
*
* Guards defect classes surfaced in the 2026-06 deep review:
*   A/B. Option min-abbreviations must match the documented .sthlp contract.
*      - msm_predict: {opt extra:polate}  (min "extra", not "extrap")
*      - msm_weight:  {opt tru:ncate}     (min "tru",   not "trunc"/"trun")
*      A regressed CAPS prefix makes the documented short form fail rc=198.
*      These sections DISCRIMINATE the bug: revert the CAPS prefix and they fail.
*   C. Re-invocation idempotency: each public command must succeed and return
*      consistent results when called twice in one session. Guards the
*      r()-clobber / unreset-state class (a stale r() consumed by the next
*      call's option-evaluation silently breaks the second run).
*
* Note: the bundled sub-programs in msm/msm_predict/msm_weight now carry
* `cap program drop` guards (house convention + lint compliance). For
* top-level bundled helpers with an unguarded main, Stata's autoloader
* tolerates redefinition, so that fix is defensive rather than crash-fixing;
* it is not separately asserted here because no scenario discriminates it.
*
* Location: msm/qa/

version 16.0
clear all
set more off
set varabbrev off

* === Bootstrap ===
local qa_dir  "`c(pwd)'"
local pkg_dir "`qa_dir'/.."

do "`qa_dir'/_install_msm_isolated.do" "`pkg_dir'"

local pass_count = 0
local fail_count = 0
local test_count = 0
local failed_tests ""

capture program drop _setup_pipeline
program define _setup_pipeline
    version 16.0
    local qa_dir  "`c(pwd)'"
    local pkg_dir "`qa_dir'/.."
    use "`pkg_dir'/msm_example.dta", clear
    msm_prepare, id(id) period(period) treatment(treatment) ///
        outcome(outcome) censor(censored) ///
        covariates(biomarker comorbidity) ///
        baseline_covariates(age sex)
end

**# A. Abbreviation contract: msm_weight truncate (min "tru")

* A1: documented minimum "tru()" must parse and behave as truncate()
local ++test_count
capture noisily {
    _setup_pipeline
    msm_weight, treat_n_cov(age sex) tru(1 99) nolog
    assert _rc == 0
    assert r(truncate) == "1 99"
}
if _rc == 0 {
    display as result "  PASS A1: msm_weight accepts documented 'tru()' abbreviation"
    local ++pass_count
}
else {
    display as error "  FAIL A1: 'tru()' rejected (rc=`=_rc') -- abbrev contract broken"
    local ++fail_count
    local failed_tests "`failed_tests' A1"
}

* A2: intermediate "trunc()" and full "truncate()" also parse identically
local ++test_count
capture noisily {
    _setup_pipeline
    msm_weight, treat_n_cov(age sex) trunc(1 99) nolog
    assert r(truncate) == "1 99"
    _setup_pipeline
    msm_weight, treat_n_cov(age sex) truncate(1 99) nolog
    assert r(truncate) == "1 99"
}
if _rc == 0 {
    display as result "  PASS A2: 'trunc()' and 'truncate()' parse consistently"
    local ++pass_count
}
else {
    display as error "  FAIL A2: trunc/truncate inconsistency (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' A2"
}

**# B. Abbreviation contract: msm_predict extrapolate (min "extra")

* Build a fitted pipeline once for the predict tests
capture noisily {
    _setup_pipeline
    msm_weight, treat_n_cov(age sex) truncate(1 99) nolog
    msm_fit, outcome_cov(age sex) model(logistic)
}
quietly summarize period
local max_period = r(max)
local beyond = `max_period' + 5

* B1: documented minimum "extra" must parse (no rc=198) and allow
*     prediction beyond the observed follow-up range
local ++test_count
capture noisily {
    msm_predict, times(`beyond') extra
    assert _rc == 0
}
if _rc == 0 {
    display as result "  PASS B1: msm_predict accepts documented 'extra' abbreviation"
    local ++pass_count
}
else {
    display as error "  FAIL B1: 'extra' rejected (rc=`=_rc') -- abbrev contract broken"
    local ++fail_count
    local failed_tests "`failed_tests' B1"
}

* B2: same beyond-range prediction WITHOUT extrapolate must be refused
*     (proves B1 exercised the extrapolation path, not a within-range no-op)
local ++test_count
capture noisily msm_predict, times(`beyond')
if _rc != 0 {
    display as result "  PASS B2: beyond-range predict refused without 'extra'"
    local ++pass_count
}
else {
    display as error "  FAIL B2: beyond-range predict allowed without extrapolate"
    local ++fail_count
    local failed_tests "`failed_tests' B2"
}

* B3: intermediate "extrap" and full "extrapolate" also parse
local ++test_count
capture noisily {
    msm_predict, times(`beyond') extrap
    assert _rc == 0
    msm_predict, times(`beyond') extrapolate
    assert _rc == 0
}
if _rc == 0 {
    display as result "  PASS B3: 'extrap' and 'extrapolate' parse consistently"
    local ++pass_count
}
else {
    display as error "  FAIL B3: extrap/extrapolate inconsistency (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' B3"
}

**# C. Re-invocation idempotency: commands are safely re-runnable

* C1: msm_weight produces identical weight summaries on a second call (replace)
local ++test_count
capture noisily {
    _setup_pipeline
    msm_weight, treat_n_cov(age sex) truncate(1 99) nolog
    local mw1 = r(mean_weight)
    local ess1 = r(ess)
    msm_weight, treat_n_cov(age sex) truncate(1 99) replace nolog
    assert reldif(r(mean_weight), `mw1') < 1e-8
    assert reldif(r(ess), `ess1') < 1e-8
}
if _rc == 0 {
    display as result "  PASS C1: msm_weight re-runs with identical summaries"
    local ++pass_count
}
else {
    display as error "  FAIL C1: msm_weight not idempotent on re-run (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' C1"
}

* C2: msm_predict re-runs (same seed -> identical predictions); guards the
*     r()-clobber class where a stale r() from call 1 corrupts call 2
local ++test_count
capture noisily {
    _setup_pipeline
    msm_weight, treat_n_cov(age sex) truncate(1 99) replace nolog
    msm_fit, outcome_cov(age sex) model(logistic)
    msm_predict, times(5) seed(12345)
    matrix _p1 = r(predictions)
    msm_predict, times(5) seed(12345)
    matrix _p2 = r(predictions)
    assert mreldif(_p1, _p2) < 1e-8
}
if _rc == 0 {
    display as result "  PASS C2: msm_predict re-runs reproducibly (same seed)"
    local ++pass_count
}
else {
    display as error "  FAIL C2: msm_predict not idempotent on re-run (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' C2"
}

* C3: msm dispatcher overview is safely re-runnable
local ++test_count
capture noisily {
    quietly msm
    local v1 = r(version)
    quietly msm
    assert "`r(version)'" == "`v1'"
}
if _rc == 0 {
    display as result "  PASS C3: msm dispatcher re-runs consistently"
    local ++pass_count
}
else {
    display as error "  FAIL C3: msm dispatcher not idempotent (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' C3"
}

**# Summary

local qa_status = cond(`fail_count' > 0, "FAIL", "PASS")
display as text ""
display as result "Test Results: `pass_count'/`test_count' passed, `fail_count' failed"
display as text "RESULT: abbrev_reload tests=`test_count' pass=`pass_count' fail=`fail_count' status=`qa_status'"

if `fail_count' > 0 {
    display as error "SOME TESTS FAILED"
    display as error "Failed:`failed_tests'"
    exit 1
}
else {
    display as result "ALL TESTS PASSED"
}
