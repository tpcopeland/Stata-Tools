* validation_msm_expanded.do — Expanded validation tests for msm package
* Known-answer, invariance, consistency, and stored results validation.
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
do "`qa_dir'/_msm_qa_common.do"

local pass_count = 0
local fail_count = 0
local test_count = 0
local failed_tests ""


timer clear
timer on 99

* Reusable pipeline setup
capture program drop _setup_pipeline
program define _setup_pipeline
    version 16.0
    syntax [, NOLOG]

    local qa_dir "`c(pwd)'"
    local pkg_dir "`qa_dir'/.."
    use "`pkg_dir'/msm_example.dta", clear
    msm_prepare, id(id) period(period) treatment(treatment) ///
        outcome(outcome) covariates(biomarker comorbidity) ///
        baseline_covariates(age sex)

    msm_weight, treat_d_cov(biomarker comorbidity age sex) ///
        treat_n_cov(age sex) truncate(1 99) nolog
end

* =============================================================================
* V1: KNOWN-ANSWER E-VALUE TESTS
* =============================================================================

* --- V1.1: E-value for OR=2.0 ---
* E-value = RR + sqrt(RR * (RR - 1)) = 2 + sqrt(2*1) = 2 + sqrt(2) ≈ 3.4142
local ++test_count
capture noisily {
    * Create simple data to get OR≈2.0 from logistic model
    clear
    set seed 20260321
    local N = 500
    local T = 5
    set obs `=`N' * `T''
    gen id = ceil(_n / `T')
    bysort id: gen period = _n - 1
    gen double bl = .
    bysort id: replace bl = rnormal() if _n == 1
    bysort id: replace bl = bl[1]
    bysort id: gen treatment = (runiform() < invlogit(-0.5 + 0.3 * bl))
    * Outcome with known effect: log-OR = ln(2) ≈ 0.693
    bysort id: gen outcome = (runiform() < invlogit(-4 + 0.693 * treatment + 0.3 * bl))

    msm_prepare, id(id) period(period) treatment(treatment) ///
        outcome(outcome) baseline_covariates(bl)
    msm_weight, treat_d_cov(bl) nolog
    msm_fit, model(logistic) period_spec(linear) nolog

    * Get OR
    local or = exp(_b[treatment])

    * Now test sensitivity E-value formula directly
    msm_sensitivity, evalue

    * The E-value should satisfy: E = RR + sqrt(RR*(RR-1))
    * where RR = r(effect) (the OR in this case)
    local rr = r(effect)
    if `rr' < 1 {
        local rr_use = 1 / `rr'
    }
    else {
        local rr_use = `rr'
    }
    local expected_evalue = `rr_use' + sqrt(`rr_use' * (`rr_use' - 1))
    local actual_evalue = r(evalue_point)

    display "  OR = " %7.4f r(effect) ", E-value = " %7.4f `actual_evalue' ///
        ", expected = " %7.4f `expected_evalue'
    assert abs(`actual_evalue' - `expected_evalue') < 0.001
}
if _rc == 0 {
    display as result "  PASS V1.1: E-value formula verified"
    local ++pass_count
}
else {
    display as error "  FAIL V1.1: E-value formula (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' V1.1"
}

* --- V1.2: E-value for protective effect (OR<1) ---
* If OR=0.5, then 1/OR=2.0, E-value = 2 + sqrt(2) ≈ 3.4142
local ++test_count
capture noisily {
    clear
    set seed 20260322
    local N = 500
    local T = 5
    set obs `=`N' * `T''
    gen id = ceil(_n / `T')
    bysort id: gen period = _n - 1
    gen double bl = .
    bysort id: replace bl = rnormal() if _n == 1
    bysort id: replace bl = bl[1]
    bysort id: gen treatment = (runiform() < invlogit(-0.5 + 0.3 * bl))
    * Protective effect: log-OR = ln(0.5) ≈ -0.693
    bysort id: gen outcome = (runiform() < invlogit(-3 - 0.693 * treatment + 0.3 * bl))

    msm_prepare, id(id) period(period) treatment(treatment) ///
        outcome(outcome) baseline_covariates(bl)
    msm_weight, treat_d_cov(bl) nolog
    msm_fit, model(logistic) period_spec(linear) nolog
    msm_sensitivity, evalue

    * E-value should use 1/OR when OR < 1
    local rr = r(effect)
    if `rr' < 1 {
        local rr_use = 1 / `rr'
    }
    else {
        local rr_use = `rr'
    }
    local expected = `rr_use' + sqrt(`rr_use' * (`rr_use' - 1))
    assert abs(r(evalue_point) - `expected') < 0.001
}
if _rc == 0 {
    display as result "  PASS V1.2: E-value for protective effect"
    local ++pass_count
}
else {
    display as error "  FAIL V1.2: E-value protective (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' V1.2"
}

* --- V1.3: E-value is always >= 1 ---
local ++test_count
capture noisily {
    _setup_pipeline, nolog
    msm_fit, outcome_cov(age sex) model(logistic) nolog
    msm_sensitivity, evalue
    assert r(evalue_point) >= 1
    assert r(evalue_ci) >= 1
}
if _rc == 0 {
    display as result "  PASS V1.3: E-value >= 1"
    local ++pass_count
}
else {
    display as error "  FAIL V1.3: E-value >= 1 (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' V1.3"
}

* =============================================================================
* V2: KNOWN-ANSWER BIAS FACTOR
* =============================================================================

* --- V2.1: bias_factor = (RR_UD * RR_UY) / (RR_UD + RR_UY - 1) ---
* RR_UD=2, RR_UY=3 → (2*3)/(2+3-1) = 6/4 = 1.5
local ++test_count
capture noisily {
    _setup_pipeline, nolog
    msm_fit, outcome_cov(age sex) model(logistic) nolog
    msm_sensitivity, confounding_strength(2 3)
    local expected_bf = (2 * 3) / (2 + 3 - 1)
    assert abs(r(bias_factor) - `expected_bf') < 0.0001
    display "  Bias factor: " %7.4f r(bias_factor) " (expected: " %7.4f `expected_bf' ")"
}
if _rc == 0 {
    display as result "  PASS V2.1: Bias factor = 1.5000"
    local ++pass_count
}
else {
    display as error "  FAIL V2.1: Bias factor (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' V2.1"
}

* --- V2.2: bias_factor with RR_UD=RR_UY=2 → (2*2)/(2+2-1) = 4/3 ---
local ++test_count
capture noisily {
    _setup_pipeline, nolog
    msm_fit, outcome_cov(age sex) model(logistic) nolog
    msm_sensitivity, confounding_strength(2 2)
    local expected_bf = (2 * 2) / (2 + 2 - 1)
    assert abs(r(bias_factor) - `expected_bf') < 0.0001
}
if _rc == 0 {
    display as result "  PASS V2.2: Bias factor (2,2) = 1.3333"
    local ++pass_count
}
else {
    display as error "  FAIL V2.2: Bias factor (2,2) (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' V2.2"
}

* --- V2.3: corrected effect moves toward the null by the bias factor ---
* VanderWeele & Ding (2017): effect / B when effect > 1, effect * B when < 1.
local ++test_count
capture noisily {
    _setup_pipeline, nolog
    msm_fit, outcome_cov(age sex) model(logistic) nolog
    msm_sensitivity, confounding_strength(2 3)
    if r(effect) < 1 {
        local expected_corrected = r(effect) * r(bias_factor)
        assert r(corrected_effect) > r(effect)
    }
    else {
        local expected_corrected = r(effect) / r(bias_factor)
        assert r(corrected_effect) < r(effect)
    }
    assert abs(r(corrected_effect) - `expected_corrected') < 0.0001
}
if _rc == 0 {
    display as result "  PASS V2.3: Corrected effect moves toward null by bias factor"
    local ++pass_count
}
else {
    display as error "  FAIL V2.3: Corrected effect (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' V2.3"
}

* =============================================================================
* V3: KNOWN-ANSWER SMD
* =============================================================================

* --- V3.1: SMD = (mean1 - mean0) / pooled_sd ---
* Create data: treated mean=10, SD=2; untreated mean=8, SD=2
* SMD = (10-8)/sqrt((4+4)/2) = 2/2 = 1.0
local ++test_count
capture noisily {
    clear
    set seed 20260323
    set obs 200
    gen id = _n
    gen period = 0
    gen treatment = (_n > 100)
    gen outcome = 0
    * Covariate: treated mean=10 SD=2, untreated mean=8 SD=2
    gen x = cond(treatment == 1, 10 + 2 * rnormal(), 8 + 2 * rnormal())

    msm_prepare, id(id) period(period) treatment(treatment) ///
        outcome(outcome) covariates(x)
    * Unit weights, registered through the package's own artifact contract.
    gen double _msm_weight = 1
    gen double _msm_tw_weight = 1
    _msm_qa_register_weights

    msm_diagnose, balance_covariates(x)

    * Unweighted SMD should be near 1.0
    tempname bal
    matrix `bal' = r(balance)
    local raw_smd = `bal'[1, 1]
    display "  Raw SMD = " %7.4f `raw_smd' " (expected ~1.0)"
    assert abs(abs(`raw_smd') - 1.0) < 0.30
}
if _rc == 0 {
    display as result "  PASS V3.1: SMD known-answer ~1.0"
    local ++pass_count
}
else {
    display as error "  FAIL V3.1: SMD known-answer (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' V3.1"
}

* --- V3.2: SMD = 0 when treatment groups have identical means ---
local ++test_count
capture noisily {
    clear
    set seed 20260324
    set obs 200
    gen id = _n
    gen period = 0
    gen treatment = (_n > 100)
    gen outcome = 0
    * Same distribution for both groups
    gen x = 5 + 2 * rnormal()

    msm_prepare, id(id) period(period) treatment(treatment) ///
        outcome(outcome) covariates(x)
    gen double _msm_weight = 1
    gen double _msm_tw_weight = 1
    _msm_qa_register_weights

    msm_diagnose, balance_covariates(x)
    tempname bal
    matrix `bal' = r(balance)
    local raw_smd = `bal'[1, 1]
    display "  Raw SMD = " %7.4f `raw_smd' " (expected ~0)"
    assert abs(`raw_smd') < 0.30
}
if _rc == 0 {
    display as result "  PASS V3.2: SMD near 0 for identical groups"
    local ++pass_count
}
else {
    display as error "  FAIL V3.2: SMD zero (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' V3.2"
}

* =============================================================================
* V4: WEIGHT CONSISTENCY
* =============================================================================

* --- V4.1: Same data → same weights ---
local ++test_count
capture noisily {
    use "`pkg_dir'/msm_example.dta", clear
    msm_prepare, id(id) period(period) treatment(treatment) ///
        outcome(outcome) covariates(biomarker comorbidity) ///
        baseline_covariates(age sex)
    msm_weight, treat_d_cov(biomarker comorbidity age sex) nolog
    local mean1 = r(mean_weight)
    local sd1 = r(sd_weight)

    * Run again
    use "`pkg_dir'/msm_example.dta", clear
    msm_prepare, id(id) period(period) treatment(treatment) ///
        outcome(outcome) covariates(biomarker comorbidity) ///
        baseline_covariates(age sex)
    msm_weight, treat_d_cov(biomarker comorbidity age sex) nolog
    local mean2 = r(mean_weight)
    local sd2 = r(sd_weight)

    display "  Run 1: mean=" %9.6f `mean1' " sd=" %9.6f `sd1'
    display "  Run 2: mean=" %9.6f `mean2' " sd=" %9.6f `sd2'
    assert abs(`mean1' - `mean2') < 0.0001
    assert abs(`sd1' - `sd2') < 0.0001
}
if _rc == 0 {
    display as result "  PASS V4.1: Weight consistency (same data → same weights)"
    local ++pass_count
}
else {
    display as error "  FAIL V4.1: Weight consistency (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' V4.1"
}

* =============================================================================
* V5: ESS FORMULA
* =============================================================================

* --- V5.1: ESS = (sum w)^2 / sum(w^2) ---
local ++test_count
capture noisily {
    _setup_pipeline, nolog

    * Compute ESS by hand
    quietly summarize _msm_weight
    local sum_w = r(sum)
    tempvar w2
    gen double `w2' = _msm_weight^2
    quietly summarize `w2'
    local sum_w2 = r(sum)
    local expected_ess = (`sum_w'^2) / `sum_w2'

    msm_diagnose
    local actual_ess = r(ess)

    display "  ESS hand-calc = " %9.2f `expected_ess' ///
        ", msm_diagnose = " %9.2f `actual_ess'
    assert abs(`actual_ess' - `expected_ess') < 0.01
}
if _rc == 0 {
    display as result "  PASS V5.1: ESS formula verified"
    local ++pass_count
}
else {
    display as error "  FAIL V5.1: ESS formula (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' V5.1"
}

* --- V5.2: ESS with uniform weights = N ---
local ++test_count
capture noisily {
    clear
    set obs 100
    gen id = _n
    gen period = 0
    gen treatment = mod(_n, 2)
    gen outcome = 0

    msm_prepare, id(id) period(period) treatment(treatment) ///
        outcome(outcome)
    * Uniform weights, registered through the package's own artifact contract.
    gen double _msm_weight = 1
    gen double _msm_tw_weight = 1
    _msm_qa_register_weights

    msm_diagnose
    * ESS with all weights = 1 should equal N
    display "  ESS = " %9.2f r(ess) " (N = 100)"
    assert abs(r(ess) - 100) < 0.01
}
if _rc == 0 {
    display as result "  PASS V5.2: ESS = N for uniform weights"
    local ++pass_count
}
else {
    display as error "  FAIL V5.2: ESS uniform (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' V5.2"
}

* =============================================================================
* V6: PREDICTION REPRODUCIBILITY
* =============================================================================

* --- V6.1: Same seed → same predictions ---
local ++test_count
capture noisily {
    _setup_pipeline, nolog
    msm_fit, outcome_cov(age sex) model(logistic) nolog

    msm_predict, times(1 3 5) samples(30) seed(77777)
    tempname p1
    matrix `p1' = r(predictions)

    * Re-run with same seed (need re-fit due to char changes)
    _setup_pipeline, nolog
    msm_fit, outcome_cov(age sex) model(logistic) nolog

    msm_predict, times(1 3 5) samples(30) seed(77777)
    tempname p2
    matrix `p2' = r(predictions)

    * All point estimates should match
    forvalues i = 1/3 {
        forvalues j = 2/7 {
            local diff = abs(`p1'[`i', `j'] - `p2'[`i', `j'])
            assert `diff' < 0.0001
        }
    }
}
if _rc == 0 {
    display as result "  PASS V6.1: Prediction reproducibility with same seed"
    local ++pass_count
}
else {
    display as error "  FAIL V6.1: Prediction reproducibility (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' V6.1"
}

* --- V6.2: cum_inc + survival = 1 ---
local ++test_count
capture noisily {
    _setup_pipeline, nolog
    msm_fit, outcome_cov(age sex) model(logistic) nolog

    msm_predict, times(1 3 5) type(cum_inc) samples(20) seed(42)
    tempname ci
    matrix `ci' = r(predictions)

    _setup_pipeline, nolog
    msm_fit, outcome_cov(age sex) model(logistic) nolog

    msm_predict, times(1 3 5) type(survival) samples(20) seed(42)
    tempname sv
    matrix `sv' = r(predictions)

    * For each time point and strategy: cum_inc + survival ≈ 1
    forvalues i = 1/3 {
        * Never-treated
        local sum_0 = `ci'[`i', 2] + `sv'[`i', 2]
        display "  t=" `ci'[`i', 1] " never: ci=" %6.4f `ci'[`i', 2] ///
            " + surv=" %6.4f `sv'[`i', 2] " = " %6.4f `sum_0'
        assert abs(`sum_0' - 1.0) < 0.001

        * Always-treated
        local sum_1 = `ci'[`i', 5] + `sv'[`i', 5]
        assert abs(`sum_1' - 1.0) < 0.001
    }
}
if _rc == 0 {
    display as result "  PASS V6.2: cum_inc + survival = 1"
    local ++pass_count
}
else {
    display as error "  FAIL V6.2: cum_inc + survival (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' V6.2"
}

* --- V6.3: predictions monotonically increasing for cum_inc ---
local ++test_count
capture noisily {
    _setup_pipeline, nolog
    msm_fit, outcome_cov(age sex) model(logistic) nolog
    msm_predict, times(1 2 3 4 5) type(cum_inc) samples(20) seed(42)
    tempname p
    matrix `p' = r(predictions)

    * Cumulative incidence should be non-decreasing
    forvalues i = 2/5 {
        local prev = `i' - 1
        * Never-treated
        assert `p'[`i', 2] >= `p'[`prev', 2] - 0.001
        * Always-treated
        assert `p'[`i', 5] >= `p'[`prev', 5] - 0.001
    }
}
if _rc == 0 {
    display as result "  PASS V6.3: Cumulative incidence monotonically increasing"
    local ++pass_count
}
else {
    display as error "  FAIL V6.3: Monotonicity (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' V6.3"
}

* --- V6.4: difference = always - never ---
local ++test_count
capture noisily {
    _setup_pipeline, nolog
    msm_fit, outcome_cov(age sex) model(logistic) nolog
    msm_predict, times(1 3 5) difference samples(20) seed(42)
    tempname p
    matrix `p' = r(predictions)

    * diff column (8) = always column (5) - never column (2)
    forvalues i = 1/3 {
        local expected_diff = `p'[`i', 5] - `p'[`i', 2]
        local actual_diff = `p'[`i', 8]
        display "  t=" `p'[`i', 1] ": diff=" %7.4f `actual_diff' ///
            " expected=" %7.4f `expected_diff'
        assert abs(`actual_diff' - `expected_diff') < 0.0001
    }
}
if _rc == 0 {
    display as result "  PASS V6.4: Difference = always - never"
    local ++pass_count
}
else {
    display as error "  FAIL V6.4: Difference (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' V6.4"
}

* =============================================================================
* V7: NULL TREATMENT EFFECT
* =============================================================================

* --- V7.1: No treatment effect → coefficient near 0, OR near 1 ---
local ++test_count
capture noisily {
    clear
    set seed 20260325
    local N = 2000
    local T = 5
    set obs `=`N' * `T''
    gen id = ceil(_n / `T')
    bysort id: gen period = _n - 1
    gen double bl = .
    bysort id: replace bl = rnormal() if _n == 1
    bysort id: replace bl = bl[1]
    bysort id: gen treatment = (runiform() < invlogit(-0.5 + 0.3 * bl))
    * NO treatment effect on outcome
    bysort id: gen outcome = (runiform() < invlogit(-4 + 0 * treatment + 0.5 * bl))

    msm_prepare, id(id) period(period) treatment(treatment) ///
        outcome(outcome) baseline_covariates(bl)
    msm_weight, treat_d_cov(bl) nolog
    msm_fit, model(logistic) period_spec(linear) nolog

    local b = _b[treatment]
    local or = exp(`b')
    display "  Null effect: coef = " %7.4f `b' ", OR = " %7.4f `or'
    * Coefficient should be near 0, OR near 1
    assert abs(`b') < 0.50
    assert abs(`or' - 1.0) < 0.50
}
if _rc == 0 {
    display as result "  PASS V7.1: Null treatment effect → OR near 1"
    local ++pass_count
}
else {
    display as error "  FAIL V7.1: Null effect (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' V7.1"
}

* --- V7.2: Null effect → E-value near 1 ---
local ++test_count
capture noisily {
    * Continuing from V7.1 data (need to re-run)
    clear
    set seed 20260325
    local N = 2000
    local T = 5
    set obs `=`N' * `T''
    gen id = ceil(_n / `T')
    bysort id: gen period = _n - 1
    gen double bl = .
    bysort id: replace bl = rnormal() if _n == 1
    bysort id: replace bl = bl[1]
    bysort id: gen treatment = (runiform() < invlogit(-0.5 + 0.3 * bl))
    bysort id: gen outcome = (runiform() < invlogit(-4 + 0 * treatment + 0.5 * bl))

    msm_prepare, id(id) period(period) treatment(treatment) ///
        outcome(outcome) baseline_covariates(bl)
    msm_weight, treat_d_cov(bl) nolog
    msm_fit, model(logistic) period_spec(linear) nolog
    msm_sensitivity, evalue

    * E-value should be small (close to 1) for null effect
    display "  E-value = " %7.4f r(evalue_point) " (expected near 1)"
    assert r(evalue_point) < 3.0
}
if _rc == 0 {
    display as result "  PASS V7.2: Null effect → low E-value"
    local ++pass_count
}
else {
    display as error "  FAIL V7.2: Null E-value (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' V7.2"
}

* =============================================================================
* V8: NATURAL SPLINE VALIDATION
* =============================================================================

* --- V8.1: ns(1) = linear (single basis variable) ---
local ++test_count
capture noisily {
    _setup_pipeline, nolog
    msm_fit, outcome_cov(age sex) period_spec(ns(1)) nolog
    confirm variable _msm_per_ns1
    * Should NOT have _msm_per_ns2
    capture confirm variable _msm_per_ns2
    assert _rc != 0
}
if _rc == 0 {
    display as result "  PASS V8.1: ns(1) creates 1 basis variable"
    local ++pass_count
}
else {
    display as error "  FAIL V8.1: ns(1) (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' V8.1"
}

* --- V8.2: ns(2) creates 2 basis variables ---
local ++test_count
capture noisily {
    _setup_pipeline, nolog
    msm_fit, outcome_cov(age sex) period_spec(ns(2)) nolog
    confirm variable _msm_per_ns1
    confirm variable _msm_per_ns2
    capture confirm variable _msm_per_ns3
    assert _rc != 0
}
if _rc == 0 {
    display as result "  PASS V8.2: ns(2) creates 2 basis variables"
    local ++pass_count
}
else {
    display as error "  FAIL V8.2: ns(2) (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' V8.2"
}

* --- V8.3: ns(3) creates 3 basis variables ---
local ++test_count
capture noisily {
    _setup_pipeline, nolog
    msm_fit, outcome_cov(age sex) period_spec(ns(3)) nolog
    confirm variable _msm_per_ns1
    confirm variable _msm_per_ns2
    confirm variable _msm_per_ns3
    capture confirm variable _msm_per_ns4
    assert _rc != 0
}
if _rc == 0 {
    display as result "  PASS V8.3: ns(3) creates 3 basis variables"
    local ++pass_count
}
else {
    display as error "  FAIL V8.3: ns(3) (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' V8.3"
}

* --- V8.4: ns(2) nonlinear basis follows the natural-spline formula ---
* Natural cubic spline basis (ESL 5.4/Harrell): basis2 = d_0 - d_pen with
* d_j(x) = ((x - t_j)+^3 - (x - t_K)+^3) / (t_K - t_j). With x = 0..10 the
* knots are {0, 5, 10}, so basis2 at x = 8 must be 8^3/10 - 3^3/5 = 45.8.
* The pre-1.2.2 special case emitted d_pen alone (5.4), which is not linear
* beyond the boundary knot.
local ++test_count
capture noisily {
    clear
    set obs 11
    gen double x = _n - 1
    _msm_natural_spline x, df(2) prefix(_qa_ns)
    assert "`_msm_spline_vars'" == "_qa_ns1 _qa_ns2"
    assert "`_msm_spline_knots'" == "0 5 10"
    assert abs(_qa_ns2[9] - 45.8) < 1e-9
    assert _qa_ns2[1] == 0
    drop _qa_ns1 _qa_ns2
}
if _rc == 0 {
    display as result "  PASS V8.4: ns(2) natural-spline basis formula"
    local ++pass_count
}
else {
    display as error "  FAIL V8.4: ns(2) basis formula (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' V8.4"
}

* =============================================================================
* V9: SORT INVARIANCE
* =============================================================================

* --- V9.1: Random reorder → same treatment coefficient ---
local ++test_count
capture noisily {
    * Run on original sort order
    use "`pkg_dir'/msm_example.dta", clear
    msm_prepare, id(id) period(period) treatment(treatment) ///
        outcome(outcome) covariates(biomarker comorbidity) ///
        baseline_covariates(age sex)
    msm_weight, treat_d_cov(biomarker comorbidity age sex) nolog
    msm_fit, model(logistic) period_spec(linear) nolog
    local b_orig = _b[treatment]

    * Run on randomly sorted data
    use "`pkg_dir'/msm_example.dta", clear
    set seed 99999
    gen _rand = runiform()
    sort _rand
    drop _rand
    msm_prepare, id(id) period(period) treatment(treatment) ///
        outcome(outcome) covariates(biomarker comorbidity) ///
        baseline_covariates(age sex)
    msm_weight, treat_d_cov(biomarker comorbidity age sex) nolog
    msm_fit, model(logistic) period_spec(linear) nolog
    local b_rand = _b[treatment]

    display "  Original: " %9.6f `b_orig' "  Random: " %9.6f `b_rand'
    assert abs(`b_orig' - `b_rand') < 0.0001
}
if _rc == 0 {
    display as result "  PASS V9.1: Sort invariance"
    local ++pass_count
}
else {
    display as error "  FAIL V9.1: Sort invariance (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' V9.1"
}

* =============================================================================
* V10: METADATA PERSISTENCE
* =============================================================================

* --- V10.1: msm_prepare stores all characteristics ---
local ++test_count
capture noisily {
    use "`pkg_dir'/msm_example.dta", clear
    msm_prepare, id(id) period(period) treatment(treatment) ///
        outcome(outcome) censor(censored) ///
        covariates(biomarker comorbidity) ///
        baseline_covariates(age sex)

    local prep : char _dta[_msm_prepared]
    assert "`prep'" == "1"
    assert "`: char _dta[_msm_id]'" == "id"
    assert "`: char _dta[_msm_period]'" == "period"
    assert "`: char _dta[_msm_treatment]'" == "treatment"
    assert "`: char _dta[_msm_outcome]'" == "outcome"
    assert "`: char _dta[_msm_censor]'" == "censored"
    assert "`: char _dta[_msm_covariates]'" == "biomarker comorbidity"
    assert "`: char _dta[_msm_bl_covariates]'" == "age sex"
}
if _rc == 0 {
    display as result "  PASS V10.1: msm_prepare characteristics stored"
    local ++pass_count
}
else {
    display as error "  FAIL V10.1: prepare chars (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' V10.1"
}

* --- V10.2: msm_weight sets weighted characteristic ---
local ++test_count
capture noisily {
    _setup_pipeline, nolog
    assert "`: char _dta[_msm_weighted]'" == "1"
    assert "`: char _dta[_msm_weight_var]'" == "_msm_weight"
}
if _rc == 0 {
    display as result "  PASS V10.2: msm_weight characteristics stored"
    local ++pass_count
}
else {
    display as error "  FAIL V10.2: weight chars (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' V10.2"
}

* --- V10.3: msm_fit sets fitted characteristic and matrices ---
local ++test_count
capture noisily {
    _setup_pipeline, nolog
    msm_fit, model(logistic) outcome_cov(age sex) nolog
    assert "`: char _dta[_msm_fitted]'" == "1"
    assert "`: char _dta[_msm_model]'" == "logistic"
    assert "`: char _dta[_msm_period_spec]'" == "quadratic"
    assert "`: char _dta[_msm_outcome_cov]'" == "age sex"
    matrix list _msm_fit_b
    matrix list _msm_fit_V
}
if _rc == 0 {
    display as result "  PASS V10.3: msm_fit characteristics and matrices stored"
    local ++pass_count
}
else {
    display as error "  FAIL V10.3: fit chars (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' V10.3"
}

* --- V10.4: msm_diagnose persists balance data ---
local ++test_count
capture noisily {
    _setup_pipeline, nolog
    msm_diagnose, balance_covariates(biomarker comorbidity age sex)
    assert "`: char _dta[_msm_diag_saved]'" == "1"
    assert "`: char _dta[_msm_bal_saved]'" == "1"
    assert "`: char _dta[_msm_diag_mean]'" != ""
    assert "`: char _dta[_msm_diag_ess]'" != ""
    matrix list _msm_bal_matrix
}
if _rc == 0 {
    display as result "  PASS V10.4: msm_diagnose persistence"
    local ++pass_count
}
else {
    display as error "  FAIL V10.4: diagnose persistence (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' V10.4"
}

* --- V10.5: msm_sensitivity persists E-value ---
local ++test_count
capture noisily {
    _setup_pipeline, nolog
    msm_fit, outcome_cov(age sex) model(logistic) nolog
    msm_sensitivity, evalue
    assert "`: char _dta[_msm_sens_saved]'" == "1"
    assert "`: char _dta[_msm_sens_effect]'" != ""
    assert "`: char _dta[_msm_sens_evalue_point]'" != ""
}
if _rc == 0 {
    display as result "  PASS V10.5: msm_sensitivity persistence"
    local ++pass_count
}
else {
    display as error "  FAIL V10.5: sensitivity persistence (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' V10.5"
}

* --- V10.6: msm_predict persists prediction matrix ---
local ++test_count
capture noisily {
    _setup_pipeline, nolog
    msm_fit, outcome_cov(age sex) model(logistic) nolog
    msm_predict, times(1 3 5) samples(20) seed(42)
    assert "`: char _dta[_msm_pred_saved]'" == "1"
    assert "`: char _dta[_msm_pred_type]'" == "cum_inc"
    assert "`: char _dta[_msm_pred_strategy]'" == "both"
    matrix list _msm_pred_matrix
}
if _rc == 0 {
    display as result "  PASS V10.6: msm_predict persistence"
    local ++pass_count
}
else {
    display as error "  FAIL V10.6: predict persistence (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' V10.6"
}

* =============================================================================
* V11: STORED RESULTS COMPLETENESS
* =============================================================================

* --- V11.1: msm_weight r() values are positive/reasonable ---
local ++test_count
capture noisily {
    _setup_pipeline, nolog
    * Re-access stored results from pipeline
    msm_weight, treat_d_cov(biomarker comorbidity age sex) ///
        treat_n_cov(age sex) truncate(1 99) nolog replace
    assert r(mean_weight) > 0
    assert r(sd_weight) > 0
    assert r(min_weight) > 0
    assert r(max_weight) > r(min_weight)
    assert r(p1_weight) >= r(min_weight)
    assert r(p99_weight) <= r(max_weight)
    assert r(median_weight) >= r(min_weight) & r(median_weight) <= r(max_weight)
    assert r(ess) > 0
    assert r(ess) <= _N
}
if _rc == 0 {
    display as result "  PASS V11.1: msm_weight r() values reasonable"
    local ++pass_count
}
else {
    display as error "  FAIL V11.1: weight r() values (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' V11.1"
}

* --- V11.2: msm_diagnose r() values ---
local ++test_count
capture noisily {
    _setup_pipeline, nolog
    msm_diagnose, balance_covariates(biomarker comorbidity age sex)
    assert r(mean_weight) > 0
    assert r(sd_weight) > 0
    assert r(ess) > 0
    assert r(ess_pct) > 0 & r(ess_pct) <= 100
    assert r(n_extreme) >= 0
    assert rowsof(r(balance)) == 4
    assert colsof(r(balance)) == 3
}
if _rc == 0 {
    display as result "  PASS V11.2: msm_diagnose r() values reasonable"
    local ++pass_count
}
else {
    display as error "  FAIL V11.2: diagnose r() values (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' V11.2"
}

* --- V11.3: msm_sensitivity r() values ---
local ++test_count
capture noisily {
    _setup_pipeline, nolog
    msm_fit, outcome_cov(age sex) model(logistic) nolog
    msm_sensitivity, evalue confounding_strength(2 3)
    assert r(effect) > 0
    assert r(effect_lo) > 0
    assert r(effect_hi) > 0
    assert r(effect_hi) > r(effect_lo)
    assert r(evalue_point) >= 1
    assert r(evalue_ci) >= 1
    assert r(bias_factor) > 0
    assert r(corrected_effect) > 0
}
if _rc == 0 {
    display as result "  PASS V11.3: msm_sensitivity r() values reasonable"
    local ++pass_count
}
else {
    display as error "  FAIL V11.3: sensitivity r() values (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' V11.3"
}

* --- V11.4: msm_predict r() values ---
local ++test_count
capture noisily {
    _setup_pipeline, nolog
    msm_fit, outcome_cov(age sex) model(logistic) nolog
    msm_predict, times(1 3 5) samples(20) seed(42)
    assert r(n_times) == 3
    assert r(n_ref) > 0
    assert r(samples) == 20
    assert r(level) == 95
    * All prediction values should be in [0,1] for cum_inc
    tempname pp
    matrix `pp' = r(predictions)
    forvalues i = 1/3 {
        assert `pp'[`i', 2] >= 0 & `pp'[`i', 2] <= 1
        assert `pp'[`i', 5] >= 0 & `pp'[`i', 5] <= 1
        * CIs should bracket point estimate
        assert `pp'[`i', 3] <= `pp'[`i', 2]
        assert `pp'[`i', 4] >= `pp'[`i', 2]
        assert `pp'[`i', 6] <= `pp'[`i', 5]
        assert `pp'[`i', 7] >= `pp'[`i', 5]
    }
}
if _rc == 0 {
    display as result "  PASS V11.4: msm_predict r() values reasonable"
    local ++pass_count
}
else {
    display as error "  FAIL V11.4: predict r() values (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' V11.4"
}

* =============================================================================
* V12: WEIGHT PROPERTIES
* =============================================================================

* --- V12.1: Stabilized weights should have mean near 1 ---
local ++test_count
capture noisily {
    _setup_pipeline, nolog
    quietly summarize _msm_weight
    local w_mean = r(mean)
    display "  Stabilized weight mean = " %7.4f `w_mean' " (expected ~1)"
    assert abs(`w_mean' - 1.0) < 0.15
}
if _rc == 0 {
    display as result "  PASS V12.1: Stabilized weight mean near 1"
    local ++pass_count
}
else {
    display as error "  FAIL V12.1: Stabilized weight mean (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' V12.1"
}

* --- V12.2: All weights positive ---
local ++test_count
capture noisily {
    _setup_pipeline, nolog
    quietly count if _msm_weight <= 0
    assert r(N) == 0
    quietly count if missing(_msm_weight)
    assert r(N) == 0
}
if _rc == 0 {
    display as result "  PASS V12.2: All weights positive"
    local ++pass_count
}
else {
    display as error "  FAIL V12.2: Positive weights (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' V12.2"
}

* --- V12.3: Truncation reduces max weight ---
local ++test_count
capture noisily {
    use "`pkg_dir'/msm_example.dta", clear
    msm_prepare, id(id) period(period) treatment(treatment) ///
        outcome(outcome) covariates(biomarker comorbidity) ///
        baseline_covariates(age sex)
    msm_weight, treat_d_cov(biomarker comorbidity age sex) nolog
    local max_untrunc = r(max_weight)

    * Re-run with truncation
    use "`pkg_dir'/msm_example.dta", clear
    msm_prepare, id(id) period(period) treatment(treatment) ///
        outcome(outcome) covariates(biomarker comorbidity) ///
        baseline_covariates(age sex)
    msm_weight, treat_d_cov(biomarker comorbidity age sex) ///
        truncate(1 99) nolog
    local max_trunc = r(max_weight)

    display "  Max untruncated: " %9.4f `max_untrunc' ///
        "  Max truncated: " %9.4f `max_trunc'
    assert `max_trunc' <= `max_untrunc'
}
if _rc == 0 {
    display as result "  PASS V12.3: Truncation reduces max weight"
    local ++pass_count
}
else {
    display as error "  FAIL V12.3: Truncation effect (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' V12.3"
}

* =============================================================================
* V13: LINEAR MODEL VALIDATION
* =============================================================================

* --- V13.1: Linear model returns coefficient in expected range ---
local ++test_count
capture noisily {
    clear
    set seed 20260506
    local N = 1000
    local T = 1
    set obs `=`N' * `T''
    gen id = ceil(_n / `T')
    bysort id: gen period = _n - 1
    gen double bl = runiform()
    gen byte treatment = (_n <= `N' / 2)
    gen byte outcome = 0
    replace outcome = 1 if treatment == 1 & _n <= 150
    replace outcome = 1 if treatment == 0 & inrange(_n, `N' / 2 + 1, `N' / 2 + 50)

    msm_prepare, id(id) period(period) treatment(treatment) ///
        outcome(outcome) baseline_covariates(bl)
    msm_weight, treat_d_cov(bl) nolog

    msm_fit, model(linear) period_spec(none) nolog
    local b = _b[treatment]
    display "  Linear probability coefficient = " %7.4f `b' " (target RD = 0.20)"
    assert abs(`b' - 0.20) < 0.06
}
if _rc == 0 {
    display as result "  PASS V13.1: Linear probability coefficient reasonable"
    local ++pass_count
}
else {
    display as error "  FAIL V13.1: Linear model (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' V13.1"
}

* =============================================================================
* V14: COX MODEL VALIDATION
* =============================================================================

* --- V14.1: Cox model stores HR-related e() ---
local ++test_count
capture noisily {
    _setup_pipeline, nolog
    msm_fit, outcome_cov(age sex) model(cox) nolog
    assert "`e(msm_model)'" == "cox"
    assert e(N) > 0
    assert _b[treatment] != .
}
if _rc == 0 {
    display as result "  PASS V14.1: Cox model e() stored"
    local ++pass_count
}
else {
    display as error "  FAIL V14.1: Cox model e() (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' V14.1"
}

* --- V14.2: Cox sensitivity uses HR label ---
local ++test_count
capture noisily {
    _setup_pipeline, nolog
    msm_fit, outcome_cov(age sex) model(cox) nolog
    msm_sensitivity, evalue
    assert "`r(effect_label)'" == "HR"
    assert r(effect) > 0
}
if _rc == 0 {
    display as result "  PASS V14.2: Cox sensitivity uses HR"
    local ++pass_count
}
else {
    display as error "  FAIL V14.2: Cox sensitivity HR (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' V14.2"
}

* =============================================================================
* V15: PREPARE CLEARS DOWNSTREAM ARTIFACTS
* =============================================================================

* --- V15.1: Re-running prepare clears weighted/fitted flags ---
local ++test_count
capture noisily {
    _setup_pipeline, nolog
    msm_fit, outcome_cov(age sex) model(logistic) nolog
    assert "`: char _dta[_msm_fitted]'" == "1"

    * Re-run prepare - should clear fitted flag
    msm_prepare, id(id) period(period) treatment(treatment) ///
        outcome(outcome) covariates(biomarker comorbidity) ///
        baseline_covariates(age sex)
    assert "`: char _dta[_msm_fitted]'" == ""
    assert "`: char _dta[_msm_weighted]'" == ""
}
if _rc == 0 {
    display as result "  PASS V15.1: Re-prepare clears downstream flags"
    local ++pass_count
}
else {
    display as error "  FAIL V15.1: Prepare clears flags (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' V15.1"
}

* =============================================================================
* V16: PROTOCOL STORED RESULTS
* =============================================================================

* --- V16.1: All 8 r() macros stored ---
local ++test_count
capture noisily {
    msm_protocol, population("Pop") treatment("Treat") ///
        confounders("Conf") outcome("Out") ///
        causal_contrast("CC") weight_spec("WS") ///
        analysis("Anal") format(display)
    assert "`r(population)'" == "Pop"
    assert "`r(treatment)'" == "Treat"
    assert "`r(confounders)'" == "Conf"
    assert "`r(outcome)'" == "Out"
    assert "`r(causal_contrast)'" == "CC"
    assert "`r(weight_spec)'" == "WS"
    assert "`r(analysis)'" == "Anal"
    assert "`r(format)'" == "display"
}
if _rc == 0 {
    display as result "  PASS V16.1: msm_protocol all r() stored"
    local ++pass_count
}
else {
    display as error "  FAIL V16.1: protocol r() (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' V16.1"
}

* =============================================================================
* SUMMARY
* =============================================================================

timer off 99
quietly timer list 99

display as text ""
display as result "Expanded Validation Results: `pass_count'/`test_count' passed, `fail_count' failed"

if `fail_count' > 0 {
    display as error "SOME VALIDATIONS FAILED"
    display as error "Failed:`failed_tests'"
}
else {
    display as result "ALL VALIDATIONS PASSED"
}

display ""
display "RESULT: VALIDATION tests=`test_count' pass=`pass_count' fail=`fail_count' status=" cond(`fail_count' > 0, "FAIL", "PASS")

if `fail_count' > 0 {
    exit 1
}
