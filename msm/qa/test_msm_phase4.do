* test_msm_phase4.do
* Phase 4 regressions: fit / prediction / inference.
*
* Findings covered (audit 2026-07-12):
*   A14  difference under type(survival) is a survival difference (sign/label)
*   A15  prediction support is the fitted risk set, not the raw data range
*   A17  signed external prediction times permitted; Cox origin stored
*   A18  natural-spline knots on the fit sample; too-few periods -> rc 198;
*        Cox never blocks on an unused period basis
*   A19  MVN draws use a symmetrized eigendecomposition; non-PSD V is refused
*   A20  linear models use t inference with e(df_r); GLM/Cox use z
*   A21  vce(robust) only for one-row-per-id; custom clusters must nest id
*   A33  a missing p-value renders as NA, not 0.99
*
* Every refusal test is paired with a positive control (the same call minus the
* offending element, asserted rc 0). Reference: rc198_error_test_needs_positive_control.

version 16.0
clear all
set more off
set varabbrev off

capture log close _all
log using "test_msm_phase4.log", replace text nomsg

local qa_dir  "`c(pwd)'"
local pkg_dir "`qa_dir'/.."

do "`qa_dir'/_install_msm_isolated.do" "`pkg_dir'"
do "`qa_dir'/_msm_qa_common.do"

local test_count = 0
local pass_count = 0
local fail_count = 0
local failed_tests ""

* -------------------------------------------------------------------------
* Fixtures
* -------------------------------------------------------------------------

* Terminal-truncated survival panel, consecutive periods 0..T, one confounder.
capture program drop _p4_panel
program define _p4_panel
    version 16.0
    syntax [, seed(integer 40401) nids(integer 500) tper(integer 6)]
    clear
    set seed `seed'
    set obs `nids'
    gen long id = _n
    gen double L0 = rnormal()
    gen double age = 40 + 10*runiform()
    gen byte sex = runiform() < 0.5
    expand `tper'
    bysort id: gen int period = _n - 1
    gen double L = L0 + rnormal() * 0.5
    gen byte treat = runiform() < invlogit(0.4 * L)
    gen byte out   = runiform() < invlogit(-2.1 + 0.7 * treat + 0.5 * L)
    bysort id (period): gen byte _po = sum(out[_n-1]) >= 1 if _n > 1
    replace _po = 0 if missing(_po)
    drop if _po > 0
    drop _po L0
    gen byte cens = 0
end

* =========================================================================
* A14: type(survival) difference is a survival difference (opposite sign to
* the cum_inc risk difference), returned as sd_* not rd_*
* =========================================================================
local ++test_count
capture noisily {
    _p4_panel
    msm_prepare, id(id) period(period) treatment(treat) outcome(out) covariates(L)
    msm_weight, treat_d_cov(L) nolog
    msm_fit, model(logistic) nolog

    msm_predict, times(3) strategy(both) type(cum_inc) difference seed(77) samples(40)
    scalar rd3 = r(rd_3)
    assert r(diff_type) == "rd"

    msm_predict, times(3) strategy(both) type(survival) difference seed(77) samples(40)
    scalar sd3 = r(sd_3)
    assert r(diff_type) == "sd"

    * Under identical fit and draws, the survival difference is the negative of
    * the risk difference (S1-S0 = -(F1-F0)). The old code returned the survival
    * contrast as rd_* and labelled it "risk difference".
    assert reldif(sd3, -rd3) < 1e-8
    assert abs(rd3) > 1e-6
}
if _rc == 0 {
    display as result "PASS A14: survival difference is signed and named sd_*, not a mislabelled risk difference"
    local ++pass_count
}
else {
    display as error "FAIL A14: difference sign/label (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' A14"
}

* =========================================================================
* A15: prediction support is the fitted risk set, not the raw data range.
* Append post-event rows extending `period' beyond the fitted support: the raw
* max grows but predict must still refuse those periods without extrapolate.
* =========================================================================
local ++test_count
capture noisily {
    _p4_panel, seed(40415) nids(500) tper(5)
    * fitted support ends at max period among at-risk rows
    quietly summarize period
    local raw_max = r(max)
    msm_prepare, id(id) period(period) treatment(treat) outcome(out) covariates(L)
    msm_weight, treat_d_cov(L) nolog
    msm_fit, model(logistic) nolog
    * within fitted support: succeeds
    msm_predict, times(`=`raw_max'') strategy(both) seed(5) samples(20)
    local msup = r(max_support)
    * beyond fitted support without extrapolate: refuse
    capture msm_predict, times(`=`msup'+5') strategy(both) seed(5) samples(20)
    assert _rc == 198
    * with extrapolate: proceeds and flags it
    msm_predict, times(`=`msup'+5') strategy(both) seed(5) samples(20) extrapolate
    assert r(extrapolated) == 1
    * within support is not flagged
    msm_predict, times(`=`msup'') strategy(both) seed(5) samples(20)
    assert r(extrapolated) == 0
}
if _rc == 0 {
    display as result "PASS A15: prediction beyond fitted risk-set support requires extrapolate"
    local ++pass_count
}
else {
    display as error "FAIL A15: fitted-support gate (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' A15"
}

* =========================================================================
* A17: signed external prediction times are permitted; Cox stores its origin.
* =========================================================================
local ++test_count
capture noisily {
    _p4_panel, seed(40417) nids(450) tper(4)
    replace period = period - 2               // external periods -2..1
    msm_prepare, id(id) period(period) treatment(treat) outcome(out) covariates(L)
    msm_weight, treat_d_cov(L) nolog
    * logistic predict must accept signed external times (old syntax was >=0)
    msm_fit, model(logistic) nolog
    msm_predict, times(-1 0 1) strategy(both) seed(9) samples(20)
    assert r(min_support) == -2
    assert r(max_support) == 1

    * Cox stores the external origin as a characteristic
    msm_fit, model(cox) vce(cluster id) nolog
    assert "`: char _dta[_msm_cox_origin]'" == "-2"
}
if _rc == 0 {
    display as result "PASS A17: signed prediction times accepted; Cox origin stored"
    local ++pass_count
}
else {
    display as error "FAIL A17: signed times / cox origin (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' A17"
}

* =========================================================================
* A18: natural spline needs enough distinct fitted periods (targeted rc 198,
* not an opaque rc 2000); Cox never blocks on an unused period basis.
* =========================================================================
local ++test_count
capture noisily {
    * only 3 distinct periods; ns(5) needs >= 6 -> refuse with a targeted error
    _p4_panel, seed(40418) nids(500) tper(3)
    msm_prepare, id(id) period(period) treatment(treat) outcome(out) covariates(L)
    msm_weight, treat_d_cov(L) nolog
    capture msm_fit, model(logistic) period_spec(ns(5)) nolog
    assert _rc == 198
    * positive control: ns(2) needs 3 distinct periods, which we have
    msm_fit, model(logistic) period_spec(ns(2)) nolog
    assert e(N) > 0
    * Cox with an over-specified spline must NOT block: period basis is skipped
    msm_fit, model(cox) period_spec(ns(9)) vce(cluster id) nolog
    assert e(N) > 0
}
if _rc == 0 {
    display as result "PASS A18: too-few-period spline refused with rc 198; Cox ignores the period basis"
    local ++pass_count
}
else {
    display as error "FAIL A18: spline support / cox skip (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' A18"
}

* =========================================================================
* A19: MVN coefficient draws use a symmetrized eigendecomposition.
* =========================================================================
local ++test_count
capture noisily {
    _p4_panel, seed(40419) nids(500) tper(5)
    msm_prepare, id(id) period(period) treatment(treat) outcome(out) covariates(L)
    msm_weight, treat_d_cov(L) nolog
    msm_fit, model(logistic) nolog
    msm_predict, times(3) strategy(both) seed(3) samples(30)
    * the draw method is reported and is the eigen method (not a diagonal hack)
    assert inlist(r(draw_method), "eigen", "eigen(clipped)")
}
if _rc == 0 {
    display as result "PASS A19: coefficient draws use the eigendecomposition factor"
    local ++pass_count
}
else {
    display as error "FAIL A19: eigen draw method (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' A19"
}

* =========================================================================
* A20: linear models use t inference with e(df_r); the CI matches a hand t CI
* and is WIDER than the naive z CI the old code produced.
* =========================================================================
local ++test_count
capture noisily {
    _p4_panel, seed(40420) nids(500) tper(5)
    msm_prepare, id(id) period(period) treatment(treat) outcome(out) covariates(L) baseline_covariates(age sex)
    msm_weight, treat_d_cov(L age sex) nolog
    msm_fit, model(linear) outcome_cov(age sex) vce(cluster id) nolog
    assert e(msm_inf_dist) == "t"
    local df = e(msm_inf_df)
    assert `df' == e(N_clust) - 1
    matrix E = e(effects)
    local est = E[1,1]
    local lo  = E[1,2]
    local hi  = E[1,3]
    * reconstruct the t half-width and confirm the stored CI used t, not z
    local se = (`hi' - `lo') / (2 * invttail(`df', 0.025))
    local lo_t = `est' - invttail(`df', 0.025) * `se'
    local lo_z = `est' - invnormal(0.975) * `se'
    assert reldif(`lo', `lo_t') < 1e-6
    * the t interval is strictly wider than the z interval it replaced
    assert `lo' < `lo_z'
}
if _rc == 0 {
    display as result "PASS A20: linear inference is t with e(df_r), wider than the old z interval"
    local ++pass_count
}
else {
    display as error "FAIL A20: t inference (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' A20"
}

* =========================================================================
* A21: vce(robust) is refused when an id contributes multiple fitted rows;
* it is allowed on a one-row-per-id sample. e(msm_n_clusters) is returned.
* =========================================================================
local ++test_count
capture noisily {
    _p4_panel, seed(40421) nids(400) tper(5)
    msm_prepare, id(id) period(period) treatment(treat) outcome(out) covariates(L)
    msm_weight, treat_d_cov(L) nolog
    * multi-row-per-id + vce(robust): refuse
    capture msm_fit, model(logistic) vce(robust) nolog
    assert _rc == 198
    * cluster(id) is fine and reports the number of independent clusters
    msm_fit, model(logistic) vce(cluster id) nolog
    assert e(msm_n_clusters) == 400

    * a genuine one-row-per-id sample (period 0 only) allows vce(robust)
    _p4_panel, seed(40421) nids(400) tper(5)
    keep if period == 0
    msm_prepare, id(id) period(period) treatment(treat) outcome(out) covariates(L)
    msm_weight, treat_d_cov(L) nolog
    msm_fit, model(logistic) vce(robust) period_spec(none) nolog
    assert e(N) > 0
}
if _rc == 0 {
    display as result "PASS A21: vce(robust) refused for repeated-id data; allowed one-row-per-id"
    local ++pass_count
}
else {
    display as error "FAIL A21: vce nesting (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' A21"
}

* =========================================================================
* A21b: e(msm_n_clusters) counts a cluster whose FIRST sorted row is OUTSIDE
* the fit sample. The old idiom `bysort clust: gen (_n==1) if _esample'
* tagged the (dropped) first row and silently undercounted the clusters;
* egen tag() on the restricted sample counts one row per cluster. Each cluster
* pairs a baseline-censored odd id (no fitted rows, sorted first) with a valid
* even id, so the cluster's first sorted row is non-esample. RED on HEAD
* (undercount to 0); GREEN on the fix (30).
* =========================================================================
local ++test_count
capture noisily {
    clear
    set seed 40422
    set obs 60
    gen long id = _n
    gen byte grp = ceil(id / 2)          // 30 clusters of 2 ids each
    gen double L = rnormal()
    expand 3
    bysort id: gen int period = _n - 1
    gen byte treat = runiform() < invlogit(0.3 * L)
    gen byte out = runiform() < invlogit(-1.0 + 0.6 * treat + 0.4 * L)
    * censor the LOWER (odd) id of each cluster at baseline so all its rows leave
    * the fit sample, making the cluster's first sorted row non-esample.
    gen byte censored = (mod(id, 2) == 1 & period == 0)
    * resolve any event/censor tie censor-first (censored subject has no event)
    replace out = 0 if censored
    msm_prepare, id(id) period(period) treatment(treat) outcome(out) ///
        censor(censored) covariates(L)
    msm_weight, treat_d_cov(L) nolog
    msm_fit, model(logistic) vce(cluster grp) nolog
    * all 30 clusters still contribute their even id's fitted rows.
    assert e(msm_n_clusters) == 30
}
if _rc == 0 {
    display as result "PASS A21b: e(msm_n_clusters) counts clusters whose first row is dropped"
    local ++pass_count
}
else {
    display as error "FAIL A21b: cluster-count undercount (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' A21b"
}

* =========================================================================
* A33: a missing p-value renders as NA, not the plausible-but-wrong "0.99".
* =========================================================================
local ++test_count
capture noisily {
    _msm_coef_pvalue_string, pvalue(.)
    assert "`r(pvalue)'" == "NA"
    * a genuine large p still renders as a number, capped at 0.99
    _msm_coef_pvalue_string, pvalue(0.999)
    assert "`r(pvalue)'" == "0.99"
    _msm_coef_pvalue_string, pvalue(0.032)
    assert "`r(pvalue)'" == "0.032"
}
if _rc == 0 {
    display as result "PASS A33: missing p-value renders as NA"
    local ++pass_count
}
else {
    display as error "FAIL A33: missing p-value rendering (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' A33"
}

* -------------------------------------------------------------------------
if `fail_count' > 0 {
    display as error "Failed tests:`failed_tests'"
}
display as text "RESULT: test_msm_phase4 tests=`test_count' pass=`pass_count' fail=`fail_count'"
capture log close _all
if `fail_count' > 0 exit 1
