* test_msm_state_identity.do
*
* Phase 1 regression suite for the msm audit (2026-07-12), findings A01-A06.
*
* Encodes the Phase 1 exit gate as executable assertions:
*   "no downstream command can operate on a mismatched, stale, partial,
*    or foreign artifact."
*
* THIS SUITE IS EXPECTED TO FAIL ON PRE-PHASE-1 CODE. It is written first,
* deliberately, so that each Phase 1 repair has an observed red-to-green
* transition rather than an assertion authored after the fix.
*
* Coverage map:
*   A01 anonymous global artifacts    -> S1, S2, S3
*   A02 no input-data freshness check -> S4, S5
*   A03 stale downstream authorized   -> S6, S7, S8
*   A04 non-transactional stages      -> S9, S10
*   A05 deletes user-owned variables  -> S11, S12
*   A06 permanent caller reordering   -> S13
*
* Run: cd <pkg>/qa && stata-mp -b do test_msm_state_identity.do

version 16.0
clear all
set varabbrev off
set more off

capture log close _all
log using "test_msm_state_identity.log", replace text nomsg

local test_count = 0
local pass_count = 0
local fail_count = 0

* Relocatable bootstrap (never hardcode a home path).
local qa_dir "`c(pwd)'"
local pkg_dir = subinstr("`qa_dir'", "/qa", "", 1)

capture ado uninstall msm
quietly net install msm, from("`pkg_dir'") replace
discard

* Helper: build a small, well-formed person-period panel with a known
* structure. Deterministic; no reliance on shipped example data.
capture program drop _mk_panel
program define _mk_panel
    syntax [, n(integer 60) periods(integer 4) seed(integer 20260717)]
    clear
    set seed `seed'
    quietly set obs `n'
    gen long pid = _n
    gen double v = rnormal()
    quietly expand `periods'
    bysort pid: gen int per = _n - 1
    gen byte trt = runiform() < invlogit(0.3 * v)
    gen byte outc = runiform() < 0.05
    gen byte cens = 0
    bysort pid (per): replace outc = 0 if sum(outc[_n-1]) > 0
    sort pid per
end

**# S1 - A01: a fit from dataset B must never be consumed by dataset A
*
* CONTRACT NOTE (2026-07-17). S1 and S2 originally asserted that the guard
* REJECTS in these situations. That encoded the pre-Phase-1 design, in which
* coefficients lived only in session-global matrices and the only safe response
* to "the live matrix might be someone else's" was to refuse.
*
* Phase 1 implements the audit's actual A01 fix (#3): b/V are persisted into
* the dataset. Dataset A therefore reloads carrying ITS OWN coefficients and
* msm_report legitimately succeeds. Asserting rc!=0 would now fail for a good
* reason, so these probes assert the stronger property the exit gate really
* wants: A uses A's numbers, never B's. Both remain red on 1.2.3 (verified).
local ++test_count
capture noisily {
    _mk_panel, seed(101)
    msm_prepare, id(pid) period(per) treatment(trt) outcome(outc) censor(cens) covariates(v)
    msm_weight, treat_d_cov(v) nolog
    msm_fit, model(logistic) nolog
    local coefA = _msm_fit_b[1, 1]

    tempfile dsA
    quietly save "`dsA'"

    * A different dataset, independently fitted, overwrites the session globals.
    _mk_panel, seed(202)
    msm_prepare, id(pid) period(per) treatment(trt) outcome(outc) censor(cens) covariates(v)
    msm_weight, treat_d_cov(v) nolog
    msm_fit, model(logistic) nolog
    local coefB = _msm_fit_b[1, 1]

    * The two fits must genuinely differ, or this probe cannot detect anything.
    assert reldif(`coefA', `coefB') > 1e-6

    * Return to dataset A. Its characteristics say "fitted", and the live
    * session matrix currently holds B's coefficients.
    use "`dsA'", clear
    assert reldif(_msm_fit_b[1, 1], `coefB') < 1e-12

    * Consuming the fit must yield A's OWN coefficients. On pre-Phase-1 code
    * the guard passes and B's matrix is adopted silently.
    _msm_check_fitted
    assert reldif(_msm_fit_b[1, 1], `coefA') < 1e-12

    * And the reported effect must be A's, not B's.
    quietly msm_report
    assert reldif(_msm_fit_b[1, 1], `coefA') < 1e-12
}
if _rc == 0 {
    display as result "PASS: S1 dataset A uses its own fit, not dataset B's"
    local ++pass_count
}
else {
    display as error "FAIL: S1 dataset A silently consumed dataset B's fit (A01)"
    local ++fail_count
}

**# S2 - A01: a fitted dataset saved and reloaded in a fresh session must carry
**# its own coefficients, and must reject if they are not there
local ++test_count
capture noisily {
    _mk_panel, seed(303)
    msm_prepare, id(pid) period(per) treatment(trt) outcome(outc) censor(cens) covariates(v)
    msm_weight, treat_d_cov(v) nolog
    msm_fit, model(logistic) nolog
    local coef_saved = _msm_fit_b[1, 1]
    tempfile fitted_ds
    quietly save "`fitted_ds'"

    * Simulate a new session: the dataset survives, session matrices do not.
    capture matrix drop _msm_fit_b
    capture matrix drop _msm_fit_V
    use "`fitted_ds'", clear

    * S2a: the artifact travels with the .dta, so the fit is still usable and
    * still the same numbers.
    _msm_check_fitted
    assert reldif(_msm_fit_b[1, 1], `coef_saved') < 1e-12

    * S2b: a dataset flagged fitted whose stored coefficients have been removed
    * must be refused, not silently backfilled from the session.
    char _dta[_msm_fit_b_nk]
    char _dta[_msm_fit_b_d1]
    char _dta[_msm_fit_b_r]
    char _dta[_msm_fit_b_c]
    capture _msm_check_fitted
    assert _rc != 0
}
if _rc == 0 {
    display as result "PASS: S2 reloaded dataset carries its own fit; a stripped one is refused"
    local ++pass_count
}
else {
    display as error "FAIL: S2 reloaded fit did not survive, or a stripped fit was accepted (A01)"
    local ++fail_count
}

**# S3 - A01: a partial artifact (b present, V gone) must be rejected
*
* The partial state has to be created where the artifact now lives. Dropping
* the session matrix _msm_fit_V proves nothing once the guard rebuilds from
* the dataset -- it would simply be restored, and the probe would pass while
* testing nothing.
local ++test_count
capture noisily {
    _mk_panel, seed(404)
    msm_prepare, id(pid) period(per) treatment(trt) outcome(outc) censor(cens) covariates(v)
    msm_weight, treat_d_cov(v) nolog
    msm_fit, model(logistic) nolog

    * Destroy the stored variance matrix, leaving b intact and the dataset
    * still flagged fitted.
    char _dta[_msm_fit_V_nk]
    char _dta[_msm_fit_V_d1]
    char _dta[_msm_fit_V_r]
    char _dta[_msm_fit_V_c]
    capture matrix drop _msm_fit_V

    capture _msm_check_fitted
    local partial_rc = _rc
    assert `partial_rc' != 0
}
if _rc == 0 {
    display as result "PASS: S3 partial fit artifact (missing V) rejected"
    local ++pass_count
}
else {
    display as error "FAIL: S3 guard accepted a fit with no variance matrix (A01)"
    local ++fail_count
}

**# S4 - A02: editing a mapped structural input must invalidate the fit
local ++test_count
capture noisily {
    _mk_panel, seed(505)
    msm_prepare, id(pid) period(per) treatment(trt) outcome(outc) censor(cens) covariates(v)
    msm_weight, treat_d_cov(v) nolog
    msm_fit, model(logistic) nolog

    * Materially alter the treatment the model was fitted on.
    quietly replace trt = 1 - trt

    capture msm_report
    local edited_rc = _rc
    assert `edited_rc' != 0
}
if _rc == 0 {
    display as result "PASS: S4 edited treatment invalidates downstream reporting"
    local ++pass_count
}
else {
    display as error "FAIL: S4 report ran on data that no longer produced the fit (A02)"
    local ++fail_count
}

**# S5 - A02: dropping observations must invalidate the fit
local ++test_count
capture noisily {
    _mk_panel, seed(606)
    msm_prepare, id(pid) period(per) treatment(trt) outcome(outc) censor(cens) covariates(v)
    msm_weight, treat_d_cov(v) nolog
    msm_fit, model(logistic) nolog

    quietly drop if pid <= 10

    capture msm_report
    local dropped_rc = _rc
    assert `dropped_rc' != 0
}
if _rc == 0 {
    display as result "PASS: S5 dropped rows invalidate downstream reporting"
    local ++pass_count
}
else {
    display as error "FAIL: S5 report ran after the estimation rows changed (A02)"
    local ++fail_count
}

**# S6 - A03: a successful reweight must invalidate the existing fit
local ++test_count
capture noisily {
    _mk_panel, seed(707)
    msm_prepare, id(pid) period(per) treatment(trt) outcome(outc) censor(cens) covariates(v)
    msm_weight, treat_d_cov(v) nolog
    msm_fit, model(logistic) nolog

    * Re-weight with a different specification. The old fit is now incompatible.
    msm_weight, treat_d_cov(v) treat_n_cov(v) truncate(1 99) replace nolog

    local fitted_flag : char _dta[_msm_fitted]
    assert "`fitted_flag'" != "1"
}
if _rc == 0 {
    display as result "PASS: S6 reweight invalidates the fit"
    local ++pass_count
}
else {
    display as error "FAIL: S6 fit stayed authorized after reweight (A03)"
    local ++fail_count
}

**# S7 - A03: a successful refit must invalidate an existing prediction
local ++test_count
capture noisily {
    _mk_panel, seed(808)
    msm_prepare, id(pid) period(per) treatment(trt) outcome(outc) censor(cens) covariates(v)
    msm_weight, treat_d_cov(v) nolog
    msm_fit, model(logistic) nolog

    * msm_predict has NO nolog option. An earlier draft passed one, so this
    * probe died at r(198) on its own syntax and never reached the behaviour it
    * claims to test -- it was red for the wrong reason (found 2026-07-17).
    capture msm_predict, times(1)
    local pred_ok = (_rc == 0)

    if `pred_ok' {
        msm_fit, model(logistic) outcome_cov(v) nolog
        local pred_flag : char _dta[_msm_pred_saved]
        assert "`pred_flag'" != "1"
    }
    else {
        * Prediction unavailable in this configuration; do not fake a pass.
        error 2000
    }
}
if _rc == 0 {
    display as result "PASS: S7 refit invalidates the saved prediction"
    local ++pass_count
}
else {
    display as error "FAIL: S7 prediction stayed authorized after refit (A03)"
    local ++fail_count
}

**# S8 - A03: a FAILED fit must not commit fitted state
local ++test_count
capture noisily {
    _mk_panel, seed(909)
    msm_prepare, id(pid) period(per) treatment(trt) outcome(outc) censor(cens) covariates(v)
    msm_weight, treat_d_cov(v) nolog

    * A constant exposure cannot be estimated; the fit must fail.
    gen byte const_exp = 1
    capture msm_fit, model(logistic) exposure(const_exp) nolog
    local badfit_rc = _rc
    assert `badfit_rc' != 0

    * The failure must leave no fitted state behind.
    local fitted_flag : char _dta[_msm_fitted]
    assert "`fitted_flag'" != "1"
}
if _rc == 0 {
    display as result "PASS: S8 failed fit commits no fitted state"
    local ++pass_count
}
else {
    display as error "FAIL: S8 failed fit left _msm_fitted=1 with zero b/V (A03)"
    local ++fail_count
}

**# S9 - A04: a failed reweight must preserve the previous valid weights
local ++test_count
capture noisily {
    _mk_panel, seed(1010)
    msm_prepare, id(pid) period(per) treatment(trt) outcome(outc) censor(cens) covariates(v)
    msm_weight, treat_d_cov(v) nolog

    quietly summarize _msm_weight, meanonly
    local w_before = r(mean)

    * Force a LATE failure. A nonexistent covariate is useless here: it fails at
    * syntax parse, before msm_weight.ado:255-263 drops the prior weights, so the
    * bug path is never entered. An all-missing covariate parses as a varname and
    * fails inside the numerator model (~line 742), i.e. after the destructive
    * drop and after _msm_ps has already been created.
    gen double allmiss_cov = .
    capture msm_weight, treat_d_cov(v) treat_n_cov(allmiss_cov) replace nolog
    local failrc = _rc
    assert `failrc' != 0

    * The prior complete weighting stage must survive intact.
    capture confirm variable _msm_weight
    assert _rc == 0
    quietly summarize _msm_weight, meanonly
    assert reldif(r(mean), `w_before') < 1e-12
}
if _rc == 0 {
    display as result "PASS: S9 failed reweight preserves prior valid weights"
    local ++pass_count
}
else {
    display as error "FAIL: S9 failed reweight destroyed the previous weights (A04)"
    local ++fail_count
}

**# S10 - A04: a failed weight run must not leave partial intermediates behind
local ++test_count
capture noisily {
    _mk_panel, seed(1111)
    msm_prepare, id(pid) period(per) treatment(trt) outcome(outc) censor(cens) covariates(v)

    * The failure must land AFTER _msm_ps is created (msm_weight.ado:736),
    * or the partial-intermediate path is never entered. An all-missing
    * treat_n_cov() is no good: it trips an upfront sample check and exits
    * rc 2000 before _msm_ps exists (verified 2026-07-17). The censor models
    * run at ~1188, comfortably after _msm_ps, so break one of those instead.
    gen double allmiss_cov = .
    capture msm_weight, treat_d_cov(v) censor_d_cov(allmiss_cov) nolog
    assert _rc != 0

    * No half-built artifact may remain from the aborted run.
    capture confirm variable _msm_ps
    local ps_left = (_rc == 0)
    assert `ps_left' == 0
}
if _rc == 0 {
    display as result "PASS: S10 failed weight leaves no partial intermediates"
    local ++pass_count
}
else {
    display as error "FAIL: S10 failed weight left _msm_ps behind (A04)"
    local ++fail_count
}

**# S11 - A05: msm_prepare must not delete a user variable it did not create
local ++test_count
capture noisily {
    _mk_panel, seed(1212)

    * A user variable that happens to collide with a reserved name.
    gen double _msm_weight = 42
    gen double _msm_per_ns_custom = 7

    capture msm_prepare, id(pid) period(per) treatment(trt) outcome(outc) censor(cens) covariates(v)
    local prep_rc = _rc

    * Acceptable outcomes: prepare refuses (rc 110) because it cannot prove
    * ownership, OR it succeeds and leaves the unowned data untouched.
    if `prep_rc' == 0 {
        capture confirm variable _msm_weight
        assert _rc == 0
        quietly summarize _msm_weight, meanonly
        assert r(mean) == 42
        capture confirm variable _msm_per_ns_custom
        assert _rc == 0
    }
    else {
        assert `prep_rc' == 110
    }
}
if _rc == 0 {
    display as result "PASS: S11 prepare does not destroy unowned user variables"
    local ++pass_count
}
else {
    display as error "FAIL: S11 prepare silently deleted user data (A05)"
    local ++fail_count
}

**# S12 - A05: wildcard _msm_per_ns* deletion must not reach user variables
local ++test_count
capture noisily {
    _mk_panel, seed(1313)
    msm_prepare, id(pid) period(per) treatment(trt) outcome(outc) censor(cens) covariates(v)

    * Created by the user AFTER prepare; the package never generated it.
    gen double _msm_per_ns_mine = 3.14

    capture msm_prepare, id(pid) period(per) treatment(trt) outcome(outc) censor(cens) covariates(v)

    capture confirm variable _msm_per_ns_mine
    assert _rc == 0
    quietly summarize _msm_per_ns_mine, meanonly
    assert reldif(r(mean), 3.14) < 1e-10
}
if _rc == 0 {
    display as result "PASS: S12 wildcard deletion does not reach unowned variables"
    local ++pass_count
}
else {
    display as error "FAIL: S12 wildcard _msm_per_ns* deleted a user variable (A05)"
    local ++fail_count
}

**# S13 - A06: public commands must not permanently reorder caller data
local ++test_count
capture noisily {
    _mk_panel, seed(1414)

    * Establish a deliberate, non-sorted caller order and mark it.
    set seed 99
    gen double _shuffle = runiform()
    sort _shuffle
    gen long caller_row = _n

    msm_prepare, id(pid) period(per) treatment(trt) outcome(outc) censor(cens) covariates(v)
    msm_weight, treat_d_cov(v) nolog

    * After weighting, row i must still be the row the caller had at position i.
    gen long now_row = _n
    quietly count if caller_row != now_row
    local displaced = r(N)
    assert `displaced' == 0
    drop now_row

    msm_fit, model(logistic) nolog
    gen long now_row = _n
    quietly count if caller_row != now_row
    assert r(N) == 0
    drop now_row

    msm_predict, times(1) samples(10) seed(1414)
    gen long now_row = _n
    quietly count if caller_row != now_row
    assert r(N) == 0
    drop now_row

    quietly msm_report
    gen long now_row = _n
    quietly count if caller_row != now_row
    assert r(N) == 0
    drop now_row

    quietly msm_sensitivity
    gen long now_row = _n
    quietly count if caller_row != now_row
    assert r(N) == 0
}
if _rc == 0 {
    display as result "PASS: S13 weight/fit/predict/report/sensitivity preserve caller order"
    local ++pass_count
}
else {
    display as error "FAIL: S13 a public pipeline command permanently reordered caller data (A06)"
    local ++fail_count
}

**# Summary
display as text ""
display as text "test_msm_state_identity summary"
display as text "  tests:  `test_count'"
display as text "  passed: `pass_count'"
display as text "  failed: `fail_count'"

display as text "RESULT: test_msm_state_identity tests=`test_count' pass=`pass_count' fail=`fail_count'"

capture log close

if `fail_count' > 0 exit 1
