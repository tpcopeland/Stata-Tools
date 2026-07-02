* validation_msm_sensitivity.do
* Dedicated validation for msm_sensitivity rare-outcome handling

version 16.0
clear all
set more off
set varabbrev off

local qa_dir "`c(pwd)'"
local pkg_dir "`qa_dir'/.."

do "`qa_dir'/_install_msm_isolated.do" "`pkg_dir'"

local test_count = 0
local pass_count = 0
local fail_count = 0
local failed_tests ""

capture program drop _setup_example_logistic
program define _setup_example_logistic
    version 16.0
    clear
    set seed 20260423
    local N = 700
    local T = 5
    set obs `=`N' * `T''
    gen id = ceil(_n / `T')
    bysort id: gen period = _n - 1
    gen double bl = .
    bysort id: replace bl = rnormal() if _n == 1
    bysort id: replace bl = bl[1]
    bysort id: gen treatment = (runiform() < invlogit(-0.50 + 0.35 * bl))
    bysort id: gen outcome = ///
        (runiform() < invlogit(-4.00 + 0.65 * treatment + 0.30 * bl))

    msm_prepare, id(id) period(period) treatment(treatment) ///
        outcome(outcome) baseline_covariates(bl)
    msm_weight, treat_d_cov(bl) nolog
    msm_fit, model(logistic) period_spec(linear) nolog
end

capture program drop _setup_common_logistic
program define _setup_common_logistic
    version 16.0

    clear
    set seed 20260422
    local N = 500
    local T = 4
    set obs `=`N' * `T''
    gen id = ceil(_n / `T')
    bysort id: gen period = _n - 1
    gen double bl = .
    bysort id: replace bl = rnormal() if _n == 1
    bysort id: replace bl = bl[1]
    bysort id: gen treatment = (runiform() < invlogit(0.10 + 0.35 * bl))
    bysort id: gen outcome = ///
        (runiform() < invlogit(-0.15 + 0.55 * treatment + 0.35 * bl))

    msm_prepare, id(id) period(period) treatment(treatment) ///
        outcome(outcome) baseline_covariates(bl)
    msm_weight, treat_d_cov(bl) nolog
    msm_fit, model(logistic) period_spec(linear) nolog
end

display as text ""
display as text "=== validation_msm_sensitivity.do ==="
display as text ""

* --- S1: rare logistic outcome computes E-value by default ---
local ++test_count
capture noisily {
    _setup_example_logistic
    msm_sensitivity, evalue

    local rr = r(effect)
    if `rr' < 1 {
        local rr_use = 1 / `rr'
    }
    else {
        local rr_use = `rr'
    }
    local expected_evalue = `rr_use' + sqrt(`rr_use' * (`rr_use' - 1))

    assert r(evalue_point) > 1
    assert abs(r(evalue_point) - `expected_evalue') < 1e-6
    assert r(outcome_prevalence) <= r(rare_threshold)
    assert "`r(approximation)'" == "rare-outcome auto"
    assert "`r(effect_label)'" == "OR"
}
if _rc == 0 {
    display as result "  PASS S1: rare logistic default E-value"
    local ++pass_count
}
else {
    display as error "  FAIL S1: rare logistic default E-value (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' S1"
}

* --- S2: common logistic outcome refuses default E-value ---
local ++test_count
capture noisily {
    _setup_common_logistic
    local before_varabbrev = c(varabbrev)
    capture noisily msm_sensitivity, evalue
    local sens_rc = _rc
    assert `sens_rc' == 498
    assert c(varabbrev) == "`before_varabbrev'"
}
if _rc == 0 {
    display as result "  PASS S2: common logistic default refusal"
    local ++pass_count
}
else {
    display as error "  FAIL S2: common logistic default refusal (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' S2"
}

* --- S3: common logistic outcome refuses default bias-factor correction ---
local ++test_count
capture noisily {
    _setup_common_logistic
    capture noisily msm_sensitivity, confounding_strength(2 3)
    assert _rc == 498
}
if _rc == 0 {
    display as result "  PASS S3: common logistic default bias-factor refusal"
    local ++pass_count
}
else {
    display as error "  FAIL S3: common logistic default bias-factor refusal (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' S3"
}

* --- S4: orapprox forces logistic approximation when prevalence is high ---
local ++test_count
capture noisily {
    _setup_common_logistic
    msm_sensitivity, evalue confounding_strength(2 3) orapprox

    assert r(outcome_prevalence) > r(rare_threshold)
    assert "`r(approximation)'" == "rare-outcome override"
    assert r(evalue_point) > 1
    assert abs(r(bias_factor) - 1.5) < 1e-6
    assert abs(r(corrected_effect) - (r(effect) / r(bias_factor))) < 1e-6
}
if _rc == 0 {
    display as result "  PASS S4: common logistic override"
    local ++pass_count
}
else {
    display as error "  FAIL S4: common logistic override (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' S4"
}

* --- S5: rarethreshold() changes the automatic approval boundary ---
local ++test_count
capture noisily {
    _setup_common_logistic
    msm_sensitivity, evalue rarethreshold(0.90)

    assert r(outcome_prevalence) < r(rare_threshold)
    assert r(rare_threshold) == 0.90
    assert "`r(approximation)'" == "rare-outcome auto"
    assert r(evalue_point) > 1
}
if _rc == 0 {
    display as result "  PASS S5: rarethreshold() controls auto-approval"
    local ++pass_count
}
else {
    display as error "  FAIL S5: rarethreshold() controls auto-approval (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' S5"
}

* --- S6: Cox branch remains available without approximation metadata ---
local ++test_count
capture noisily {
    _setup_example_logistic
    shell rm -f "`c(pwd)'/_cox_sample_map"*
    msm_fit, model(cox) nolog
    msm_sensitivity, evalue

    assert r(evalue_point) > 1
    assert "`r(effect_label)'" == "HR"
    assert "`r(approximation)'" == "none"
}
if _rc == 0 {
    display as result "  PASS S6: Cox sensitivity unaffected"
    local ++pass_count
}
else {
    display as error "  FAIL S6: Cox sensitivity unaffected (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' S6"
}

* --- S7: protective effect corrected TOWARD the null (multiply by B) ---
* VanderWeele & Ding (2017): for RR_obs < 1 the confounding-adjusted bound
* is RR_obs * B, moving the estimate toward 1 (not RR_obs / B, which would
* strengthen a protective effect).
local ++test_count
capture noisily {
    clear
    set seed 20260701
    local N = 600
    local T = 4
    set obs `=`N' * `T''
    gen id = ceil(_n / `T')
    bysort id: gen period = _n - 1
    gen double bl = .
    bysort id: replace bl = rnormal() if _n == 1
    bysort id: replace bl = bl[1]
    bysort id: gen treatment = (runiform() < invlogit(-0.20 + 0.30 * bl))
    bysort id: gen outcome = ///
        (runiform() < invlogit(-4.20 - 0.80 * treatment + 0.30 * bl))

    msm_prepare, id(id) period(period) treatment(treatment) ///
        outcome(outcome) baseline_covariates(bl)
    msm_weight, treat_d_cov(bl) nolog
    msm_fit, model(logistic) period_spec(linear) nolog

    msm_sensitivity, confounding_strength(2 2)
    assert r(effect) < 1
    assert abs(r(bias_factor) - (4/3)) < 1e-6
    assert abs(r(corrected_effect) - (r(effect) * r(bias_factor))) < 1e-6
    assert r(corrected_effect) > r(effect)
}
if _rc == 0 {
    display as result "  PASS S7: protective effect corrected toward null"
    local ++pass_count
}
else {
    display as error "  FAIL S7: protective effect corrected toward null (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' S7"
}

* --- S8: confounding_strength() values below 1 are rejected ---
local ++test_count
capture noisily {
    _setup_example_logistic
    capture msm_sensitivity, confounding_strength(0.5 2)
    assert _rc == 198
    capture msm_sensitivity, confounding_strength(2 0.8)
    assert _rc == 198
}
if _rc == 0 {
    display as result "  PASS S8: sub-1 confounding_strength rejected"
    local ++pass_count
}
else {
    display as error "  FAIL S8: sub-1 confounding_strength rejected (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' S8"
}

display as text ""
display as text "=== Sensitivity Validation Summary ==="
display as text "Tests run: `test_count'"
display as result "Passed:   `pass_count'"
display as error  "Failed:   `fail_count'"

if `fail_count' > 0 {
    display as error "Failed tests:`failed_tests'"
    exit 1
}
