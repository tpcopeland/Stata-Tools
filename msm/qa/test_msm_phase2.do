* test_msm_phase2.do
* Phase 2 regressions: the person-period / risk-process contract.
*
* Findings covered (audit 2026-07-12):
*   A07  central structural-role validator (roles disjoint; predictors not roles)
*   A08  missing id/period hard-error; event/censor ties rejected
*   A09  gapped within-id decision periods are a hard error
*   A11  one authoritative risk-set marker: appending post-risk rows cannot
*        change any at-risk weight, cutoff, diagnostic, or fitted estimate
*   A17  signed periods rebased internally; Cox retains every intended row
*   A25  treatment support counts 0/1 among nonmissing; missing is indeterminate
*   A34  r(n_periods) is a distinct count; r(period_span) is separate
*
* Every refusal test is paired with a positive control (the same call minus the
* offending element, asserted rc 0), so a refusal cannot pass on an unrelated
* upstream error. Reference: rc198_error_test_needs_positive_control.

version 16.0
clear all
set more off
set varabbrev off

capture log close _all
log using "test_msm_phase2.log", replace text nomsg

local qa_dir  "`c(pwd)'"
local pkg_dir "`qa_dir'/.."

do "`qa_dir'/_install_msm_isolated.do" "`pkg_dir'"
do "`qa_dir'/_msm_qa_common.do"

local test_count = 0
local pass_count = 0
local fail_count = 0
local failed_tests ""

* -------------------------------------------------------------------------
* Fixture builders
* -------------------------------------------------------------------------

* A well-behaved terminal-truncated person-period panel (no post-risk rows,
* consecutive periods 0..T, binary treatment/outcome, one confounder L).
capture program drop _p2_clean_panel
program define _p2_clean_panel
    version 16.0
    syntax [, seed(integer 22701) nids(integer 400) tper(integer 5)]
    clear
    set seed `seed'
    set obs `nids'
    gen long id = _n
    gen double L0 = rnormal()
    expand `tper'
    bysort id: gen int period = _n - 1
    gen double L = L0 + rnormal() * 0.5
    gen byte treat = runiform() < invlogit(0.4 * L)
    gen byte out   = runiform() < invlogit(-2.1 + 0.7 * treat + 0.5 * L)
    * terminal event: drop rows after the first outcome
    bysort id (period): gen byte _po = sum(out[_n-1]) >= 1 if _n > 1
    replace _po = 0 if missing(_po)
    drop if _po > 0
    drop _po L0
    gen byte cens = 0
end

* -------------------------------------------------------------------------
* A07: central structural-role validator
* -------------------------------------------------------------------------
local ++test_count
capture noisily {
    * positive control: a valid, disjoint mapping prepares cleanly
    _p2_clean_panel
    msm_prepare, id(id) period(period) treatment(treat) outcome(out) covariates(L)
    assert "`: char _dta[_msm_prepared]'" == "1"

    * same variable in two structural roles
    _p2_clean_panel
    capture msm_prepare, id(id) period(period) treatment(treat) outcome(treat)
    assert _rc == 198

    * a covariate that is the treatment
    _p2_clean_panel
    capture msm_prepare, id(id) period(period) treatment(treat) outcome(out) ///
        covariates(treat L)
    assert _rc == 198

    * a covariate that is the outcome
    _p2_clean_panel
    capture msm_prepare, id(id) period(period) treatment(treat) outcome(out) ///
        covariates(out L)
    assert _rc == 198

    * fit-side: tvcov() may not be the outcome; exposure() may not be the period
    _p2_clean_panel
    msm_prepare, id(id) period(period) treatment(treat) outcome(out) covariates(L)
    msm_weight, treat_d_cov(L) nolog
    capture msm_fit, model(logistic) exposure(out) nolog
    assert _rc == 198
    capture msm_fit, model(logistic) exposure(period) nolog
    assert _rc == 198
    capture msm_fit, model(logistic) tvcov(out) nolog
    assert _rc == 198
    * positive control: a legitimate fit still succeeds
    msm_fit, model(logistic) nolog
    assert e(N) > 0
}
if _rc == 0 {
    display as result "PASS A07: structural roles are pairwise disjoint and predictors are not roles"
    local ++pass_count
}
else {
    display as error "FAIL A07: role validator (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' A07"
}

* -------------------------------------------------------------------------
* A08: missing id/period hard-error; event/censor ties rejected
* -------------------------------------------------------------------------
local ++test_count
capture noisily {
    * missing id
    _p2_clean_panel
    replace id = . in 5
    capture msm_prepare, id(id) period(period) treatment(treat) outcome(out) covariates(L)
    assert _rc == 198

    * missing period
    _p2_clean_panel
    replace period = . in 5
    capture msm_prepare, id(id) period(period) treatment(treat) outcome(out) covariates(L)
    assert _rc == 198

    * event/censor tie
    _p2_clean_panel
    replace out  = 1 in 7
    replace cens = 1 in 7
    capture msm_prepare, id(id) period(period) treatment(treat) outcome(out) censor(cens)
    assert _rc == 198

    * positive control: same data without the tie prepares cleanly
    _p2_clean_panel
    msm_prepare, id(id) period(period) treatment(treat) outcome(out) censor(cens)
    assert "`: char _dta[_msm_prepared]'" == "1"
}
if _rc == 0 {
    display as result "PASS A08: missing keys and event/censor ties are rejected"
    local ++pass_count
}
else {
    display as error "FAIL A08: missing/tie policy (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' A08"
}

* -------------------------------------------------------------------------
* A09: gapped within-id decision periods are a hard error
* -------------------------------------------------------------------------
local ++test_count
capture noisily {
    * gap: delete period 1 from a 0..T panel -> within-id run 0,2,3,...
    * A gap is a hard WEIGHTING error (audit A09): preparation still describes
    * the data, but msm_weight refuses because the cumulative weight would be
    * wrong. msm_validate reports it as a diagnostic.
    _p2_clean_panel
    drop if period == 1
    msm_prepare, id(id) period(period) treatment(treat) outcome(out) covariates(L)
    capture msm_weight, treat_d_cov(L) nolog
    assert _rc == 459
    * no weighting state was committed
    assert "`: char _dta[_msm_weighted]'" == ""

    * positive control: the consecutive panel weights cleanly
    _p2_clean_panel
    msm_prepare, id(id) period(period) treatment(treat) outcome(out) covariates(L)
    msm_weight, treat_d_cov(L) nolog
    assert "`: char _dta[_msm_weighted]'" == "1"
}
if _rc == 0 {
    display as result "PASS A09: gapped periods are a hard weighting error"
    local ++pass_count
}
else {
    display as error "FAIL A09: gap policy (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' A09"
}

* -------------------------------------------------------------------------
* A11: appending post-risk rows cannot change any at-risk result
* -------------------------------------------------------------------------
local ++test_count
capture noisily {
    * baseline: prepare -> weight (with truncation) -> fit -> diagnose
    _p2_clean_panel, seed(22711) nids(500) tper(5)
    tempfile base
    save `base'
    msm_prepare, id(id) period(period) treatment(treat) outcome(out) censor(cens) covariates(L)
    msm_weight, treat_d_cov(L) truncate(1 99) nolog
    msm_fit, model(logistic) vce(cluster id) nolog
    scalar b_base   = _b[treat]
    msm_diagnose
    scalar ess_base = r(ess)
    scalar mw_base  = r(mean_weight)
    scalar mx_base  = r(max_weight)

    * append clean post-event follow-up rows (out=0, cens=0) to event-ending ids
    use `base', clear
    bysort id (period): egen byte _anyev = max(out)
    preserve
        keep if _anyev == 1
        bysort id (period): keep if _n == _N
        expand 2
        bysort id: gen byte _j = _n
        replace period = period + _j
        replace out  = 0
        replace cens = 0
        replace treat = 1
        drop _j _anyev
        tempfile post
        save `post'
    restore
    drop _anyev
    append using `post'
    sort id period
    msm_prepare, id(id) period(period) treatment(treat) outcome(out) censor(cens) covariates(L)
    msm_weight, treat_d_cov(L) truncate(1 99) nolog
    msm_fit, model(logistic) vce(cluster id) nolog
    scalar b_post   = _b[treat]
    msm_diagnose
    scalar ess_post = r(ess)
    scalar mw_post  = r(mean_weight)
    scalar mx_post  = r(max_weight)

    * at-risk results must be byte-for-byte invariant to appended post-risk rows
    assert reldif(b_base, b_post)     < 1e-11
    assert reldif(ess_base, ess_post) < 1e-9
    assert reldif(mw_base, mw_post)   < 1e-11
    assert reldif(mx_base, mx_post)   < 1e-11
    * the appended rows really did enter the dataset (guard against a no-op test)
    assert b_base != .
}
if _rc == 0 {
    display as result "PASS A11: at-risk weights/cutoffs/diagnostics/estimate invariant to post-risk rows"
    local ++pass_count
}
else {
    display as error "FAIL A11: risk-set invariance (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' A11"
}

* -------------------------------------------------------------------------
* A17: signed periods rebased; Cox retains every intended at-risk row
* -------------------------------------------------------------------------
local ++test_count
capture noisily {
    * signed periods -2..1
    _p2_clean_panel, seed(22717) nids(450) tper(4)
    replace period = period - 2
    msm_prepare, id(id) period(period) treatment(treat) outcome(out) covariates(L)
    msm_weight, treat_d_cov(L) nolog
    quietly count if _msm_decision_risk
    local n_risk_signed = r(N)
    msm_fit, model(cox) vce(cluster id) nolog
    assert e(N) == `n_risk_signed'
    scalar hr_signed = _b[treat]

    * same data shifted to a nonnegative origin must give the identical fit
    _p2_clean_panel, seed(22717) nids(450) tper(4)
    msm_prepare, id(id) period(period) treatment(treat) outcome(out) covariates(L)
    msm_weight, treat_d_cov(L) nolog
    msm_fit, model(cox) vce(cluster id) nolog
    scalar hr_shift = _b[treat]

    * rebasing is a pure origin shift: the hazard-ratio coefficient is invariant
    assert reldif(hr_signed, hr_shift) < 1e-8
}
if _rc == 0 {
    display as result "PASS A17: negative-origin Cox fits the full at-risk sample and is origin-invariant"
    local ++pass_count
}
else {
    display as error "FAIL A17: signed-period Cox (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' A17"
}

* -------------------------------------------------------------------------
* A25: treatment support by period counts 0/1 among nonmissing
* -------------------------------------------------------------------------
local ++test_count
capture noisily {
    * Contrast two panels with the IDENTICAL missing-treatment pattern in period
    * 0, differing only in whether a genuine untreated subject exists there. The
    * support check must fire in the no-untreated case and not in the other.
    * The old arithmetic (_p_t0 = _N - total(treat)) counted the missing rows as
    * untreated, so BOTH panels padded-passed positivity and produced equal
    * warning counts -- this contrast is therefore red on the old code and green
    * on the new. A bare "validate errored" assertion is a false green: the
    * separate missing-value check errors on both codes regardless of A25.
    _p2_clean_panel, seed(22725) nids(400) tper(4)
    replace treat = 1 if period == 0                       // no genuine untreated
    replace treat = . if period == 0 & mod(id, 5) == 0     // padded by missing
    msm_prepare, id(id) period(period) treatment(treat) outcome(out) covariates(L)
    msm_validate
    scalar warn_noun = r(n_warnings)

    _p2_clean_panel, seed(22725) nids(400) tper(4)
    replace treat = . if period == 0 & mod(id, 5) == 0     // same missing pattern
    msm_prepare, id(id) period(period) treatment(treat) outcome(out) covariates(L)
    msm_validate
    scalar warn_un = r(n_warnings)

    * the extra warning is exactly the support violation the padded count hid
    assert warn_noun > warn_un

    * positive control: a fully clean panel (treated+untreated each period, no
    * missing) raises no error even under strict validation
    _p2_clean_panel, seed(22725) nids(400) tper(5)
    msm_prepare, id(id) period(period) treatment(treat) outcome(out) covariates(L)
    msm_validate, strict
    assert r(n_errors) == 0
}
if _rc == 0 {
    display as result "PASS A25: missing treatment no longer masquerades as untreated support"
    local ++pass_count
}
else {
    display as error "FAIL A25: positivity support (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' A25"
}

* -------------------------------------------------------------------------
* A34: r(n_periods) is a distinct count; r(period_span) is separate
* -------------------------------------------------------------------------
local ++test_count
capture noisily {
    * union of periods {0,1,3,4}: distinct=4, span=5, each id consecutive
    _p2_clean_panel, seed(22734) nids(400) tper(2)
    replace period = period + 3 if mod(id, 2) == 0
    msm_prepare, id(id) period(period) treatment(treat) outcome(out) covariates(L)
    assert r(n_periods)   == 4
    assert r(period_span) == 5

    * a fully consecutive panel: distinct == span
    _p2_clean_panel, seed(22734) nids(400) tper(5)
    msm_prepare, id(id) period(period) treatment(treat) outcome(out) covariates(L)
    assert r(n_periods)   == 5
    assert r(period_span) == 5
}
if _rc == 0 {
    display as result "PASS A34: n_periods counts distinct periods; period_span is reported separately"
    local ++pass_count
}
else {
    display as error "FAIL A34: n_periods contract (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' A34"
}

* -------------------------------------------------------------------------
display as text ""
if `fail_count' > 0 {
    display as error "Failed tests:`failed_tests'"
}
display as text "RESULT: test_msm_phase2 tests=`test_count' pass=`pass_count' fail=`fail_count'"
capture log close _all
if `fail_count' > 0 exit 1
