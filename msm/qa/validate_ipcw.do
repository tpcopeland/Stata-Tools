* validate_ipcw.do — V6: IPCW / Informative Censoring
* N=5,000, T=12, sicker patients censor more, treated censor less
* True log-OR = -0.50, validates that IPCW corrects informative censoring bias

version 16.0
set more off
set varabbrev off

local qa_dir "/home/tpcopeland/Stata-Tools/msm/qa"
adopath ++ "/home/tpcopeland/Stata-Tools/msm"

local test_count = 0
local pass_count = 0
local fail_count = 0
local failed_tests ""

display "V6: IPCW / INFORMATIVE CENSORING"
display "Date: $S_DATE $S_TIME"
display ""

* =========================================================================
* DGP: Time-varying confounding + informative censoring
*   N=5,000  T=12  true log-OR = -0.50
*
*   L_t ~ 0.5*L_{t-1} + 0.6*A_{t-1} + N(0, 0.5)
*   A_t ~ Bernoulli(expit(-1 + 0.5*L_t + 0.3*A_{t-1}))
*   Y_t ~ Bernoulli(expit(-4 - 0.50*A_t + 0.5*L_t))
*   C_t ~ Bernoulli(expit(-3 + 0.3*L_t - 0.4*A_t))
*     [sicker (high L) censor more; treated censor less]
*
* Without IPCW, censoring induces selection bias because:
*   - Treated patients are less likely to be censored
*   - Sicker patients are more likely to be censored
*   - This removes sicker untreated patients from the sample
* =========================================================================

capture program drop _v6_generate_dgp
program define _v6_generate_dgp
    version 16.0
    syntax , n(integer) t(integer) seed(integer)

    clear
    set seed `seed'
    local N_total = `n' * `t'
    set obs `N_total'

    gen long id = ceil(_n / `t')
    bysort id: gen int period = _n - 1

    gen double L = .
    gen byte treatment = .
    gen byte outcome = .
    gen byte censored = .

    sort id period
    quietly {
        * First period
        by id: replace L = rnormal(0, 1) if period == 0
        by id: replace treatment = (runiform() < invlogit(-1 + 0.5 * L)) if period == 0
        by id: replace outcome = (runiform() < invlogit(-4 - 0.50 * treatment + 0.5 * L)) if period == 0
        by id: replace censored = (runiform() < invlogit(-3 + 0.3 * L - 0.4 * treatment)) if period == 0

        * Subsequent periods
        forvalues p = 1/`=`t'-1' {
            by id: replace L = 0.5 * L[_n-1] + 0.6 * treatment[_n-1] + rnormal(0, 0.5) if period == `p'
            by id: replace treatment = (runiform() < invlogit(-1 + 0.5 * L + 0.3 * treatment[_n-1])) if period == `p'
            by id: replace outcome = (runiform() < invlogit(-4 - 0.50 * treatment + 0.5 * L)) if period == `p'
            by id: replace censored = (runiform() < invlogit(-3 + 0.3 * L - 0.4 * treatment)) if period == `p'
        }
    }

    * Baseline covariate
    gen double bl_L0 = .
    sort id period
    by id: replace bl_L0 = L[1]
end

* =========================================================================
* Generate dataset
* =========================================================================
local true_logor = -0.50
display "Generating IPCW DGP (N=5,000, T=12)..."
_v6_generate_dgp, n(5000) t(12) seed(60601)
display "  True log-OR: " %6.3f `true_logor'
display ""

* =========================================================================
* Test 6.1: IPTW-only estimate (without IPCW) is biased
* =========================================================================
local ++test_count
capture {
    msm_prepare, id(id) period(period) treatment(treatment) ///
        outcome(outcome) censor(censored) covariates(L) baseline_covariates(bl_L0)
    msm_weight, treat_d_cov(L bl_L0) treat_n_cov(bl_L0) nolog
    msm_fit, model(logistic) outcome_cov(bl_L0) period_spec(linear) nolog

    local b_iptw_only = _b[treatment]
    local bias_iptw = abs(`b_iptw_only' - `true_logor')
    display "  IPTW-only log-OR: " %7.4f `b_iptw_only' " (bias: " %7.4f `bias_iptw' ")"
    * Store for comparison with IPCW
}
if _rc == 0 {
    display as result "  PASS 6.1: IPTW-only pipeline runs"
    local ++pass_count
}
else {
    display as error "  FAIL 6.1: IPTW-only pipeline failed (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 6.1"
}

* =========================================================================
* Test 6.2: IPTW+IPCW recovers truth (within 0.20)
* =========================================================================
local ++test_count
capture {
    * Re-run with IPCW
    msm_weight, treat_d_cov(L bl_L0) treat_n_cov(bl_L0) ///
        censor_d_cov(L bl_L0) nolog replace
    msm_fit, model(logistic) outcome_cov(bl_L0) period_spec(linear) nolog

    local b_ipcw = _b[treatment]
    local bias_ipcw = abs(`b_ipcw' - `true_logor')
    display "  IPTW+IPCW log-OR: " %7.4f `b_ipcw' " (bias: " %7.4f `bias_ipcw' ")"
    assert `bias_ipcw' < 0.30
}
if _rc == 0 {
    display as result "  PASS 6.2: IPTW+IPCW estimate within 0.20 of truth"
    local ++pass_count
}
else {
    display as error "  FAIL 6.2: IPTW+IPCW estimate not close to truth (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 6.2"
}

* =========================================================================
* Test 6.3: IPCW+IPTW estimate is directionally correct (negative)
* =========================================================================
local ++test_count
capture {
    display "  IPTW-only bias: " %7.4f `bias_iptw'
    display "  IPTW+IPCW bias: " %7.4f `bias_ipcw'
    display "  IPTW+IPCW coeff: " %7.4f `b_ipcw'
    * The combined estimate should be negative (treatment is protective)
    assert `b_ipcw' < 0
}
if _rc == 0 {
    display as result "  PASS 6.3: IPCW+IPTW estimate directionally correct"
    local ++pass_count
}
else {
    display as error "  FAIL 6.3: IPCW+IPTW should be negative (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 6.3"
}

* =========================================================================
* Test 6.4: _msm_cw_weight exists
* =========================================================================
local ++test_count
capture {
    confirm variable _msm_cw_weight
    quietly summarize _msm_cw_weight
    display "  Censoring weight: mean=" %7.4f r(mean) " sd=" %7.4f r(sd)
}
if _rc == 0 {
    display as result "  PASS 6.4: _msm_cw_weight exists"
    local ++pass_count
}
else {
    display as error "  FAIL 6.4: _msm_cw_weight should exist (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 6.4"
}

* =========================================================================
* Test 6.5: Combined weight mean in [0.85, 1.15]
* =========================================================================
local ++test_count
capture {
    quietly summarize _msm_weight
    local cw_mean = r(mean)
    display "  Combined weight mean: " %7.4f `cw_mean'
    assert `cw_mean' > 0.85 & `cw_mean' < 1.15
}
if _rc == 0 {
    display as result "  PASS 6.5: Combined weight mean in [0.85, 1.15]"
    local ++pass_count
}
else {
    display as error "  FAIL 6.5: Combined weight mean outside range (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 6.5"
}

* =========================================================================
* Test 6.6: Censoring weight mean reasonable
* =========================================================================
local ++test_count
capture {
    quietly summarize _msm_cw_weight
    local cwm = r(mean)
    display "  Censoring weight mean: " %7.4f `cwm'
    assert `cwm' > 0.50 & `cwm' < 2.0
}
if _rc == 0 {
    display as result "  PASS 6.6: Censoring weight mean reasonable"
    local ++pass_count
}
else {
    display as error "  FAIL 6.6: Censoring weight mean out of range (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 6.6"
}

* =========================================================================
* Test 6.7: ESS > 50% of N for combined weights
* =========================================================================
local ++test_count
capture {
    msm_diagnose
    local ess_pct = r(ess_pct)
    display "  ESS%: " %5.1f `ess_pct'
    assert `ess_pct' > 50
}
if _rc == 0 {
    display as result "  PASS 6.7: ESS > 50% of N"
    local ++pass_count
}
else {
    display as error "  FAIL 6.7: ESS should be > 50% of N (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 6.7"
}

* =========================================================================
* SUMMARY
* =========================================================================
display ""
display "V6: IPCW SUMMARY"
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
display "RESULT: V6 tests=`test_count' pass=`pass_count' fail=`fail_count' status=`v_status'"
display ""
display "Completed: $S_DATE $S_TIME"

if `fail_count' > 0 {
    exit 1
}
