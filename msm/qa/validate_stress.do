* validate_stress.do - V11: Stress and Boundary Testing
* Tests package behavior under extreme conditions:
*   - Near-positivity violation (rare treatment)
*   - Strong confounding
*   - Many covariates
*   - Unbalanced panels
*   - Large N performance
*   - Extreme event rates
*   - Single-period data
*   - All-treated / all-untreated individuals

version 16.0
set more off
set varabbrev off

local qa_dir "/home/tpcopeland/Stata-Tools/msm/qa"
adopath ++ "/home/tpcopeland/Stata-Tools/msm"

local test_count = 0
local pass_count = 0
local fail_count = 0
local failed_tests ""

display "V11: STRESS AND BOUNDARY TESTING"
display "Date: $S_DATE $S_TIME"
display ""

* =============================================================================
* Test 11.1: Near-positivity violation (rare treatment ~5%)
*   Treatment prevalence ~5%. The weight model should still converge
*   and produce finite weights.
* =============================================================================
local ++test_count
capture {
    clear
    set seed 11101
    set obs 10000
    gen long id = ceil(_n / 5)
    bysort id: gen int period = _n - 1
    gen double L = rnormal()
    bysort id: replace L = 0.5 * L[_n-1] + rnormal(0, 0.3) if _n > 1

    * Rare treatment: ~5% prevalence
    gen byte treatment = runiform() < invlogit(-3 + 0.3 * L)
    gen byte outcome = runiform() < invlogit(-5 - 0.3 * treatment + 0.2 * L)
    gen double bl = .
    bysort id (period): replace bl = L[1]

    quietly count if treatment == 1
    local treat_pct = 100 * r(N) / _N
    display "  Treatment prevalence: " %5.1f `treat_pct' "%"

    msm_prepare, id(id) period(period) treatment(treatment) ///
        outcome(outcome) covariates(L) baseline_covariates(bl)
    msm_weight, treat_d_cov(L bl) treat_n_cov(bl) truncate(1 99) nolog

    * Weights should be finite and positive
    quietly summarize _msm_weight
    assert r(min) > 0
    assert r(max) < .
    assert r(mean) > 0

    msm_fit, model(logistic) outcome_cov(bl) period_spec(linear) nolog
    assert _b[treatment] != .
    display "  Treatment coeff: " %9.4f _b[treatment]
}
if _rc == 0 {
    display as result "  PASS 11.1: Near-positivity violation handled"
    local ++pass_count
}
else {
    display as error "  FAIL 11.1: Near-positivity (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 11.1"
}

* =============================================================================
* Test 11.2: Strong confounding (high confounding strength)
*   L has a very strong effect on both A and Y.
*   Weights may be extreme but pipeline should complete.
* =============================================================================
local ++test_count
capture {
    clear
    set seed 11201
    set obs 10000
    gen long id = ceil(_n / 5)
    bysort id: gen int period = _n - 1
    gen double L = rnormal()
    bysort id: replace L = 0.3 * L[_n-1] + rnormal(0, 0.5) if _n > 1

    * Strong confounding: coefficient 2.0 on L in treatment model
    gen byte treatment = runiform() < invlogit(-1 + 2.0 * L)
    gen byte outcome = runiform() < invlogit(-4 - 0.5 * treatment + 2.0 * L)
    gen double bl = .
    bysort id (period): replace bl = L[1]

    msm_prepare, id(id) period(period) treatment(treatment) ///
        outcome(outcome) covariates(L) baseline_covariates(bl)
    msm_weight, treat_d_cov(L bl) treat_n_cov(bl) truncate(1 99) nolog

    quietly summarize _msm_weight, detail
    display "  Weight range: [" %9.4f r(min) ", " %9.4f r(max) "]"
    display "  Weight SD: " %9.4f r(sd)

    * With strong confounding, weight SD should be large
    assert r(sd) > 0.1

    msm_fit, model(logistic) outcome_cov(bl) period_spec(linear) nolog
    assert _b[treatment] != .
    display "  Treatment coeff: " %9.4f _b[treatment]
}
if _rc == 0 {
    display as result "  PASS 11.2: Strong confounding handled"
    local ++pass_count
}
else {
    display as error "  FAIL 11.2: Strong confounding (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 11.2"
}

* =============================================================================
* Test 11.3: Many covariates (10 covariates in weight model)
*   The weight models should converge with many covariates.
* =============================================================================
local ++test_count
capture {
    clear
    set seed 11301
    set obs 5000
    gen long id = ceil(_n / 10)
    bysort id: gen int period = _n - 1

    * Generate 10 covariates
    forvalues j = 1/10 {
        gen double x`j' = rnormal()
    }

    * Treatment depends on first 3 covariates
    gen double xb = -1 + 0.3 * x1 + 0.2 * x2 + 0.1 * x3
    gen byte treatment = runiform() < invlogit(xb)
    gen byte outcome = runiform() < invlogit(-4 + 0.2 * x1 + 0.1 * x2)
    gen double bl_x1 = .
    bysort id (period): replace bl_x1 = x1[1]
    drop xb

    msm_prepare, id(id) period(period) treatment(treatment) ///
        outcome(outcome) ///
        covariates(x1 x2 x3 x4 x5 x6 x7 x8 x9 x10)

    msm_weight, treat_d_cov(x1 x2 x3 x4 x5 x6 x7 x8 x9 x10) ///
        treat_n_cov(x1 x2) truncate(1 99) nolog

    quietly summarize _msm_weight
    assert r(min) > 0
    assert r(max) < .
    display "  10-covariate weight mean: " %9.4f r(mean)

    msm_fit, model(logistic) outcome_cov(x1 x2) period_spec(linear) nolog
    assert _b[treatment] != .
}
if _rc == 0 {
    display as result "  PASS 11.3: Many covariates (10) handled"
    local ++pass_count
}
else {
    display as error "  FAIL 11.3: Many covariates (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 11.3"
}

* =============================================================================
* Test 11.4: Unbalanced panels (varying T per individual)
*   Individuals have different numbers of follow-up periods.
*   Some have 3 periods, others have 10. This is the common real-world case.
* =============================================================================
local ++test_count
capture {
    clear
    set seed 11401

    * Create unbalanced panel: 500 individuals with varying T
    local total_obs = 0
    local n_ids = 500
    forvalues i = 1/`n_ids' {
        * Each individual has 2-10 periods
        local T_i = floor(2 + 9 * runiform())
        local total_obs = `total_obs' + `T_i'
    }

    set obs `total_obs'
    gen long id = .
    gen int period = .
    local row = 1
    set seed 11401
    forvalues i = 1/`n_ids' {
        local T_i = floor(2 + 9 * runiform())
        forvalues t = 0/`=`T_i'-1' {
            replace id = `i' in `row'
            replace period = `t' in `row'
            local ++row
        }
    }

    gen double L = rnormal()
    gen byte treatment = runiform() < invlogit(-1 + 0.3 * L)
    gen byte outcome = runiform() < invlogit(-4 - 0.3 * treatment + 0.2 * L)
    gen double bl = .
    bysort id (period): replace bl = L[1]

    * Verify unbalanced structure
    tempvar t_count
    bysort id: gen int `t_count' = _N
    quietly summarize `t_count'
    display "  Panel lengths: min=" r(min) " max=" r(max) " mean=" %4.1f r(mean)
    assert r(min) < r(max)

    msm_prepare, id(id) period(period) treatment(treatment) ///
        outcome(outcome) covariates(L) baseline_covariates(bl)
    msm_weight, treat_d_cov(L bl) treat_n_cov(bl) nolog
    msm_fit, model(logistic) outcome_cov(bl) period_spec(linear) nolog

    assert _b[treatment] != .
    display "  Treatment coeff: " %9.4f _b[treatment]
}
if _rc == 0 {
    display as result "  PASS 11.4: Unbalanced panels handled"
    local ++pass_count
}
else {
    display as error "  FAIL 11.4: Unbalanced panels (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 11.4"
}

* =============================================================================
* Test 11.5: Large N performance (N=20,000 individuals, T=5)
*   The full pipeline should complete in reasonable time.
* =============================================================================
local ++test_count
display ""
display "  Running large-N test (N=20,000, T=5)..."
capture {
    clear
    set seed 11501
    set obs 100000
    gen long id = ceil(_n / 5)
    bysort id: gen int period = _n - 1
    gen double L = rnormal()
    bysort id: replace L = 0.5 * L[_n-1] + rnormal(0, 0.3) if _n > 1
    gen byte treatment = runiform() < invlogit(-1 + 0.3 * L)
    gen byte outcome = runiform() < invlogit(-4 - 0.3 * treatment + 0.2 * L)
    gen double bl = .
    bysort id (period): replace bl = L[1]

    timer clear 1
    timer on 1
    msm_prepare, id(id) period(period) treatment(treatment) ///
        outcome(outcome) covariates(L) baseline_covariates(bl)
    msm_weight, treat_d_cov(L bl) treat_n_cov(bl) truncate(1 99) nolog
    msm_fit, model(logistic) outcome_cov(bl) period_spec(quadratic) nolog
    timer off 1
    quietly timer list 1
    display "  Pipeline time: " %5.1f r(t1) " seconds"

    assert _b[treatment] != .
    display "  Treatment coeff: " %9.4f _b[treatment]
}
if _rc == 0 {
    display as result "  PASS 11.5: Large N (100K obs) completes"
    local ++pass_count
}
else {
    display as error "  FAIL 11.5: Large N (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 11.5"
}

* =============================================================================
* Test 11.6: Very rare events (outcome rate < 1%)
*   Pooled logistic should converge even with sparse events.
* =============================================================================
local ++test_count
capture {
    clear
    set seed 11601
    set obs 10000
    gen long id = ceil(_n / 5)
    bysort id: gen int period = _n - 1
    gen double L = rnormal()
    gen byte treatment = runiform() < invlogit(-1 + 0.3 * L)
    * Very rare outcome: ~0.5% per period
    gen byte outcome = runiform() < invlogit(-6 - 0.3 * treatment + 0.2 * L)
    gen double bl = .
    bysort id (period): replace bl = L[1]

    quietly count if outcome == 1
    local event_rate = 100 * r(N) / _N
    display "  Event rate: " %5.2f `event_rate' "%"

    msm_prepare, id(id) period(period) treatment(treatment) ///
        outcome(outcome) covariates(L) baseline_covariates(bl)
    msm_weight, treat_d_cov(L bl) treat_n_cov(bl) nolog
    msm_fit, model(logistic) outcome_cov(bl) period_spec(linear) nolog
    assert _b[treatment] != .
    display "  Treatment coeff: " %9.4f _b[treatment]
}
if _rc == 0 {
    display as result "  PASS 11.6: Very rare events handled"
    local ++pass_count
}
else {
    display as error "  FAIL 11.6: Rare events (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 11.6"
}

* =============================================================================
* Test 11.7: High event rate (outcome rate ~20%)
*   With many events, the model should have good power.
* =============================================================================
local ++test_count
capture {
    clear
    set seed 11701
    set obs 5000
    gen long id = ceil(_n / 5)
    bysort id: gen int period = _n - 1
    gen double L = rnormal()
    gen byte treatment = runiform() < invlogit(-1 + 0.3 * L)
    * High outcome rate: ~15-20% per period
    gen byte outcome = runiform() < invlogit(-1.5 - 0.5 * treatment + 0.3 * L)
    gen double bl = .
    bysort id (period): replace bl = L[1]

    quietly count if outcome == 1
    local event_rate = 100 * r(N) / _N
    display "  Event rate: " %5.1f `event_rate' "%"

    msm_prepare, id(id) period(period) treatment(treatment) ///
        outcome(outcome) covariates(L) baseline_covariates(bl)
    msm_weight, treat_d_cov(L bl) treat_n_cov(bl) nolog
    msm_fit, model(logistic) outcome_cov(bl) period_spec(linear) nolog

    * With high power, treatment should be significantly negative
    local b = _b[treatment]
    local se = _se[treatment]
    local z = `b' / `se'
    display "  Treatment coeff: " %9.4f `b' " (z=" %5.2f `z' ")"
    assert `b' < 0
}
if _rc == 0 {
    display as result "  PASS 11.7: High event rate handled"
    local ++pass_count
}
else {
    display as error "  FAIL 11.7: High event rate (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 11.7"
}

* =============================================================================
* Test 11.8: Short panel (T=2, minimum for lagged treatment)
*   Two periods is the minimum that allows lagged treatment modeling.
* =============================================================================
local ++test_count
capture {
    clear
    set seed 11801
    set obs 2000
    gen long id = ceil(_n / 2)
    bysort id: gen int period = _n - 1
    gen double L = rnormal()
    gen byte treatment = runiform() < invlogit(-1 + 0.3 * L)
    gen byte outcome = runiform() < invlogit(-4 - 0.3 * treatment + 0.2 * L)

    msm_prepare, id(id) period(period) treatment(treatment) ///
        outcome(outcome) covariates(L)
    msm_weight, treat_d_cov(L) nolog
    msm_fit, model(logistic) period_spec(linear) nolog
    assert _b[treatment] != .
    display "  T=2 treatment coeff: " %9.4f _b[treatment]
}
if _rc == 0 {
    display as result "  PASS 11.8: Short panel (T=2) handled"
    local ++pass_count
}
else {
    display as error "  FAIL 11.8: Short panel (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 11.8"
}

* =============================================================================
* Test 11.9: Long panel (T=50)
*   Cumulative weights via log-sum should remain stable over many periods.
* =============================================================================
local ++test_count
capture {
    clear
    set seed 11901
    set obs 25000
    gen long id = ceil(_n / 50)
    bysort id: gen int period = _n - 1
    gen double L = rnormal()
    bysort id: replace L = 0.5 * L[_n-1] + rnormal(0, 0.3) if _n > 1
    gen byte treatment = runiform() < invlogit(-1 + 0.2 * L)
    gen byte outcome = runiform() < invlogit(-5 - 0.2 * treatment + 0.1 * L)
    gen double bl = .
    bysort id (period): replace bl = L[1]

    msm_prepare, id(id) period(period) treatment(treatment) ///
        outcome(outcome) covariates(L) baseline_covariates(bl)
    msm_weight, treat_d_cov(L bl) treat_n_cov(bl) truncate(1 99) nolog

    * Weights should not explode or collapse to 0
    quietly summarize _msm_weight
    display "  T=50 weight range: [" %12.6f r(min) ", " %12.4f r(max) "]"
    assert r(min) > 0
    assert r(max) < 1000

    msm_fit, model(logistic) outcome_cov(bl) period_spec(quadratic) nolog
    assert _b[treatment] != .
    display "  T=50 treatment coeff: " %9.4f _b[treatment]
}
if _rc == 0 {
    display as result "  PASS 11.9: Long panel (T=50) handled"
    local ++pass_count
}
else {
    display as error "  FAIL 11.9: Long panel (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 11.9"
}

* =============================================================================
* Test 11.10: Dataset with always-treated and never-treated individuals
*   The pipeline should handle individuals who never switch treatment.
* =============================================================================
local ++test_count
capture {
    clear
    set seed 11100
    * 300 individuals x 5 periods
    set obs 1500
    gen long id = ceil(_n / 5)
    bysort id: gen int period = _n - 1
    gen double L = rnormal()

    * Force first 100 to always-treated, second 100 to never-treated
    * Last 100 switch randomly
    gen byte treatment = .
    replace treatment = 1 if id <= 100
    replace treatment = 0 if id > 100 & id <= 200
    replace treatment = (runiform() < invlogit(-1 + 0.3 * L)) if id > 200

    gen byte outcome = runiform() < invlogit(-4 - 0.3 * treatment + 0.2 * L)
    gen double bl = .
    bysort id (period): replace bl = L[1]

    msm_prepare, id(id) period(period) treatment(treatment) ///
        outcome(outcome) covariates(L) baseline_covariates(bl)

    * Validate should show always/never/switchers
    msm_validate
    assert r(n_errors) == 0

    msm_weight, treat_d_cov(L bl) treat_n_cov(bl) nolog
    msm_fit, model(logistic) outcome_cov(bl) period_spec(linear) nolog
    assert _b[treatment] != .
    display "  Mixed adherence coeff: " %9.4f _b[treatment]
}
if _rc == 0 {
    display as result "  PASS 11.10: Always/never/switcher mix handled"
    local ++pass_count
}
else {
    display as error "  FAIL 11.10: Mixed adherence (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 11.10"
}

* =============================================================================
* Test 11.11: Censoring rate ~40% (heavy censoring)
*   Heavy censoring should not crash the pipeline.
* =============================================================================
local ++test_count
capture {
    clear
    set seed 11111
    set obs 10000
    gen long id = ceil(_n / 10)
    bysort id: gen int period = _n - 1
    gen double L = rnormal()
    bysort id: replace L = 0.5 * L[_n-1] + rnormal(0, 0.3) if _n > 1
    gen byte treatment = runiform() < invlogit(-1 + 0.3 * L)
    gen byte outcome = runiform() < invlogit(-4 - 0.3 * treatment + 0.2 * L)
    * Heavy censoring: ~4% per period => ~40% over 10 periods
    gen byte censored = runiform() < invlogit(-3 + 0.2 * L - 0.3 * treatment)
    gen double bl = .
    bysort id (period): replace bl = L[1]

    quietly count if censored == 1
    local cens_pct = 100 * r(N) / _N
    display "  Censoring rate: " %5.1f `cens_pct' "%"

    msm_prepare, id(id) period(period) treatment(treatment) ///
        outcome(outcome) censor(censored) ///
        covariates(L) baseline_covariates(bl)
    msm_weight, treat_d_cov(L bl) treat_n_cov(bl) ///
        censor_d_cov(L bl) truncate(1 99) nolog

    confirm variable _msm_cw_weight
    quietly summarize _msm_weight
    assert r(min) > 0
    assert r(max) < .

    msm_fit, model(logistic) outcome_cov(bl) period_spec(linear) nolog
    assert _b[treatment] != .
    display "  Heavy censoring coeff: " %9.4f _b[treatment]
}
if _rc == 0 {
    display as result "  PASS 11.11: Heavy censoring (~40%) handled"
    local ++pass_count
}
else {
    display as error "  FAIL 11.11: Heavy censoring (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 11.11"
}

* =============================================================================
* Test 11.12: Full pipeline with predictions under stress
*   Run predict with long time horizon and verify results are valid.
* =============================================================================
local ++test_count
capture {
    * Reuse data from 11.9 (long panel T=50, should still be fitted)
    * Rebuild for clarity
    clear
    set seed 11121
    set obs 5000
    gen long id = ceil(_n / 10)
    bysort id: gen int period = _n - 1
    gen double L = rnormal()
    bysort id: replace L = 0.5 * L[_n-1] + rnormal(0, 0.3) if _n > 1
    gen byte treatment = runiform() < invlogit(-1 + 0.3 * L)
    gen byte outcome = runiform() < invlogit(-5 - 0.3 * treatment + 0.2 * L)
    gen double bl = .
    bysort id (period): replace bl = L[1]

    msm_prepare, id(id) period(period) treatment(treatment) ///
        outcome(outcome) covariates(L) baseline_covariates(bl)
    msm_weight, treat_d_cov(L bl) treat_n_cov(bl) truncate(1 99) nolog
    msm_fit, model(logistic) outcome_cov(bl) period_spec(quadratic) nolog

    * Predict at many time points
    msm_predict, times(0 1 2 3 4 5 6 7 8 9) type(cum_inc) ///
        samples(20) seed(42) difference
    tempname pred
    matrix `pred' = r(predictions)

    * All cumulative incidence values should be in [0, 1]
    forvalues i = 1/10 {
        assert `pred'[`i', 2] >= 0 & `pred'[`i', 2] <= 1
        assert `pred'[`i', 5] >= 0 & `pred'[`i', 5] <= 1
    }

    * Cumulative incidence should be monotonically non-decreasing
    forvalues i = 2/10 {
        assert `pred'[`i', 2] >= `pred'[`=`i'-1', 2] - 0.001
        assert `pred'[`i', 5] >= `pred'[`=`i'-1', 5] - 0.001
    }

    display "  CI at t=9: never=" %6.4f `pred'[10, 2] " always=" %6.4f `pred'[10, 5]
}
if _rc == 0 {
    display as result "  PASS 11.12: Stress predictions valid"
    local ++pass_count
}
else {
    display as error "  FAIL 11.12: Stress predictions (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 11.12"
}

* =============================================================================
* Test 11.13: Identical covariates in denominator and numerator
*   When treat_n_cov equals treat_d_cov, weights should be ~1 (unstabilized
*   with same model in both => weight ratio ≈ 1).
* =============================================================================
local ++test_count
capture {
    clear
    set seed 11131
    set obs 5000
    gen long id = ceil(_n / 5)
    bysort id: gen int period = _n - 1
    gen double L = rnormal()
    gen byte treatment = runiform() < invlogit(-1 + 0.3 * L)
    gen byte outcome = runiform() < invlogit(-4 - 0.3 * treatment + 0.2 * L)

    msm_prepare, id(id) period(period) treatment(treatment) ///
        outcome(outcome) covariates(L)

    * Same covariates in numerator and denominator
    msm_weight, treat_d_cov(L) treat_n_cov(L) nolog

    * When num and denom models are identical, weight should be ~1
    quietly summarize _msm_weight
    display "  Same-model weight mean: " %9.4f r(mean)
    display "  Same-model weight SD:   " %9.4f r(sd)
    * SD should be very small (near 0)
    assert r(sd) < 0.1
    assert abs(r(mean) - 1) < 0.05
}
if _rc == 0 {
    display as result "  PASS 11.13: Same num/denom covariates => weight ~1"
    local ++pass_count
}
else {
    display as error "  FAIL 11.13: Same covariates (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 11.13"
}

* =============================================================================
* Test 11.14: Very aggressive truncation (10th/90th percentile)
*   Aggressive truncation should still produce valid estimates.
* =============================================================================
local ++test_count
capture {
    clear
    set seed 11141
    set obs 10000
    gen long id = ceil(_n / 5)
    bysort id: gen int period = _n - 1
    gen double L = rnormal()
    bysort id: replace L = 0.5 * L[_n-1] + rnormal(0, 0.3) if _n > 1
    gen byte treatment = runiform() < invlogit(-1 + 0.5 * L)
    gen byte outcome = runiform() < invlogit(-4 - 0.5 * treatment + 0.3 * L)
    gen double bl = .
    bysort id (period): replace bl = L[1]

    msm_prepare, id(id) period(period) treatment(treatment) ///
        outcome(outcome) covariates(L) baseline_covariates(bl)
    msm_weight, treat_d_cov(L bl) treat_n_cov(bl) truncate(10 90) nolog

    assert r(n_truncated) > 0
    local n_trunc = r(n_truncated)
    local trunc_pct = 100 * `n_trunc' / _N
    display "  Truncated: " `n_trunc' " obs (" %5.1f `trunc_pct' "%)"

    quietly summarize _msm_weight
    display "  Truncated weight range: [" %9.4f r(min) ", " %9.4f r(max) "]"

    msm_fit, model(logistic) outcome_cov(bl) period_spec(linear) nolog
    assert _b[treatment] != .
}
if _rc == 0 {
    display as result "  PASS 11.14: Aggressive truncation (10/90) handled"
    local ++pass_count
}
else {
    display as error "  FAIL 11.14: Aggressive truncation (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 11.14"
}

* =============================================================================
* SUMMARY
* =============================================================================
display ""
display "V11: STRESS AND BOUNDARY TESTING SUMMARY"
display "Total tests:  `test_count'"
display "Passed:       `pass_count'"
if `fail_count' > 0 {
    display as error "Failed:       `fail_count'"
    display as error "Failed tests:`failed_tests'"
}
else {
    display "Failed:       `fail_count'"
}

local v_status = cond(`fail_count' > 0, "FAIL", "PASS")
display ""
display "RESULT: V11 tests=`test_count' pass=`pass_count' fail=`fail_count' status=`v_status'"
display ""
display "Completed: $S_DATE $S_TIME"

if `fail_count' > 0 {
    exit 1
}
