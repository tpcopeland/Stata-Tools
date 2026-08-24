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
    tempfile interpretation_stub
    local interpretation_log "`interpretation_stub'.log"
    capture log close sensinterp
    quietly log using "`interpretation_log'", text replace name(sensinterp)
    noisily msm_sensitivity, evalue
    local got_effect = r(effect)
    local got_evalue = r(evalue_point)
    local got_cumulative_incidence = r(cumulative_incidence)
    local got_rare_threshold = r(rare_threshold)
    local got_approximation "`r(approximation)'"
    local got_effect_label "`r(effect_label)'"
    local got_rr_scale "`r(rr_scale)'"
    capture log close sensinterp

    local rr = `got_effect'
    if `rr' < 1 {
        local rr_use = 1 / `rr'
    }
    else {
        local rr_use = `rr'
    }
    local expected_evalue = `rr_use' + sqrt(`rr_use' * (`rr_use' - 1))

    assert `got_evalue' > 1
    assert abs(`got_evalue' - `expected_evalue') < 1e-6
    * Rarity is now the subject-level cumulative incidence by end of follow-up
    * (audit A12), not the old pooled person-period outcome mean.
    assert `got_cumulative_incidence' <= `got_rare_threshold'
    assert "`got_approximation'" == "rare-outcome"
    assert "`got_effect_label'" == "OR"
    assert "`got_rr_scale'" == "OR used directly (rare-outcome: RR~OR)"

    * VanderWeele & Ding explicitly decline to define universal E-value
    * cutoffs. The command must direct users to context, not label fixed ranges
    * weak/moderate/strong.
    tempname interpretation_fh
    local found_context 0
    local found_cutoff 0
    file open `interpretation_fh' using "`interpretation_log'", read text
    file read `interpretation_fh' interpretation_line
    while r(eof) == 0 {
        local interpretation_lc = lower(`"`macval(interpretation_line)'"')
        if strpos(`"`interpretation_lc'"', "no universal e-value cutoff") {
            local found_context 1
        }
        if strpos(`"`interpretation_lc'"', "weak unmeasured confounder") | ///
            strpos(`"`interpretation_lc'"', "moderately strong unmeasured confounder") | ///
            strpos(`"`interpretation_lc'"', "a strong unmeasured confounder") {
            local found_cutoff 1
        }
        file read `interpretation_fh' interpretation_line
    }
    file close `interpretation_fh'
    assert `found_context' == 1
    assert `found_cutoff' == 0
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

* --- S2: common logistic outcome uses the sqrt(OR) transform (audit A12) ---
* The old code REFUSED a common outcome (rc 498); VanderWeele & Ding (2017)
* instead approximate RR ~ sqrt(OR), so the default now computes the E-value on
* that scale. RED on HEAD (which returned 498).
local ++test_count
capture noisily {
    _setup_common_logistic
    msm_sensitivity, evalue
    assert !missing(r(cumulative_incidence))
    assert r(cumulative_incidence) > r(rare_threshold)
    assert "`r(approximation)'" == "common-outcome sqrt(OR)"
    * the E-value must be computed from RR = sqrt(OR), not the raw OR
    local rr = sqrt(r(effect))
    if `rr' < 1 local rr = 1 / `rr'
    local expected = `rr' + sqrt(`rr' * (`rr' - 1))
    assert abs(r(evalue_point) - `expected') < 1e-6
    assert !missing(r(evalue_point))
    assert r(evalue_point) > 1
}
if _rc == 0 {
    display as result "  PASS S2: common logistic uses sqrt(OR) transform"
    local ++pass_count
}
else {
    display as error "  FAIL S2: common logistic sqrt(OR) transform (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' S2"
}

* --- S3: common logistic bias-factor bound computes on the RR scale (A12) ---
local ++test_count
capture noisily {
    _setup_common_logistic
    msm_sensitivity, confounding_strength(2 3)
    assert r(bias_factor) != .
    assert r(bound) != .
    assert "`r(approximation)'" == "common-outcome sqrt(OR)"
}
if _rc == 0 {
    display as result "  PASS S3: common logistic bias-factor computes on RR scale"
    local ++pass_count
}
else {
    display as error "  FAIL S3: common logistic bias-factor (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' S3"
}

* --- S4: orapprox forces logistic approximation when prevalence is high ---
local ++test_count
capture noisily {
    _setup_common_logistic
    msm_sensitivity, evalue confounding_strength(2 3) orapprox

    assert !missing(r(cumulative_incidence))
    assert r(cumulative_incidence) > r(rare_threshold)
    assert "`r(approximation)'" == "OR-direct override"
    assert !missing(r(evalue_point))
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
    * cumulative incidence of this fixture is ~0.96, so only a threshold above
    * it reclassifies the outcome as rare and uses the OR directly.
    msm_sensitivity, evalue rarethreshold(0.99)

    assert !missing(r(rare_threshold))
    assert r(cumulative_incidence) < r(rare_threshold)
    assert r(rare_threshold) == 0.99
    assert "`r(approximation)'" == "rare-outcome"
    assert !missing(r(evalue_point))
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

* --- S6: Cox now runs the same rarity gate (audit A13) ---
* The old code treated a Cox HR as an RR with NO rarity check (approximation
* "none"). The rare example fixture (cumulative incidence ~0.10 < 0.15) now
* reports "rare-outcome" and uses the HR directly. RED on HEAD ("none").
local ++test_count
capture noisily {
    _setup_example_logistic
    * Portable removal of any stale Cox sandbox maps (Q12: no Unix-only shell).
    local _stale : dir "`c(pwd)'" files "_cox_sample_map*"
    foreach _m of local _stale {
        capture erase "`c(pwd)'/`_m'"
    }
    msm_fit, model(cox) nolog
    msm_sensitivity, evalue

    assert !missing(r(evalue_point))
    assert r(evalue_point) > 1
    assert "`r(effect_label)'" == "HR"
    assert !missing(r(rare_threshold))
    assert r(cumulative_incidence) <= r(rare_threshold)
    assert "`r(approximation)'" == "rare-outcome"
    * rare -> HR used directly as the RR scale
    local rr = r(effect)
    if `rr' < 1 local rr = 1 / `rr'
    local expected = `rr' + sqrt(`rr' * (`rr' - 1))
    assert abs(r(evalue_point) - `expected') < 1e-6
}
if _rc == 0 {
    display as result "  PASS S6: Cox rarity gate (rare-outcome)"
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
    assert !missing(r(corrected_effect))
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

* --- S9: rarity is defined on the fitted risk-set population ---
* Subjects with no row in the outcome-model estimation sample must not change
* the population or event count used to choose the E-value approximation.
local ++test_count
capture noisily {
    use "`pkg_dir'/msm_example.dta", clear
    tempvar id_group excluded fit_event fit_subject idtag
    egen long `id_group' = group(id)
    gen byte `excluded' = (`id_group' <= 50)
    quietly count if `excluded'
    assert !missing(r(N))
    assert r(N) > 0

    * These subjects have events but are excluded from the fitted MSM because
    * the outcome-model covariate is missing on every one of their rows.
    replace outcome = 0 if `excluded'
    bysort id (period): replace outcome = 1 if `excluded' & _n == 1
    replace censored = 0 if `excluded'
    gen byte fit_cov = mod(`id_group', 7)
    replace fit_cov = . if `excluded'
    msm_prepare, id(id) period(period) treatment(treatment) ///
        outcome(outcome) censor(censored) ///
        covariates(biomarker comorbidity) ///
        baseline_covariates(age sex)
    msm_weight, treat_d_cov(biomarker comorbidity age sex) ///
        treat_n_cov(age sex) censor_d_cov(biomarker age sex) nolog
    msm_fit, model(logistic) outcome_cov(age sex fit_cov) ///
        period_spec(linear) nolog

    * Independent oracle: one event indicator per subject contributing at least
    * one row to the actual fitted estimation sample.
    bysort id: egen byte `fit_event' = ///
        max(cond(_msm_esample == 1, outcome == 1, .))
    bysort id: egen byte `fit_subject' = max(_msm_esample == 1)
    bysort id (period): gen byte `idtag' = (_n == 1) if `fit_subject'
    quietly summarize `fit_event' if `idtag', meanonly
    local expected_incidence = r(mean)

    msm_sensitivity, evalue
    assert !missing(r(cumulative_incidence), `expected_incidence')
    assert reldif(r(cumulative_incidence), `expected_incidence') < 1e-10
}
if _rc == 0 {
    display as result "  PASS S9: rarity uses fitted risk-set subjects and events"
    local ++pass_count
}
else {
    display as error "  FAIL S9: excluded subjects changed rarity (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' S9"
}

* --- S10: Cox bias adjustment is labelled on the RR scale ---
* For a common outcome the HR is transformed to an approximate RR before the
* bias factor is applied. The displayed adjusted quantity must not be called HR.
local ++test_count
capture noisily {
    _setup_common_logistic
    local _stale : dir "`c(pwd)'" files "_cox_sample_map*"
    foreach _m of local _stale {
        capture erase "`c(pwd)'/`_m'"
    }
    msm_fit, model(cox) nolog

    tempfile cox_label_stub
    local cox_label_log "`cox_label_stub'.log"
    capture log close senscox
    quietly log using "`cox_label_log'", text replace name(senscox)
    noisily msm_sensitivity, confounding_strength(2 3)
    capture log close senscox

    tempname cox_label_fh
    local found_rr_label 0
    local found_hr_label 0
    file open `cox_label_fh' using "`cox_label_log'", read text
    file read `cox_label_fh' cox_label_line
    while r(eof) == 0 {
        local cox_label_lc = lower(`"`macval(cox_label_line)'"')
        if strpos(`"`cox_label_lc'"', "bias-adjusted rr bound") {
            local found_rr_label 1
        }
        if strpos(`"`cox_label_lc'"', "corrected hr") {
            local found_hr_label 1
        }
        file read `cox_label_fh' cox_label_line
    }
    file close `cox_label_fh'
    assert `found_rr_label' == 1
    assert `found_hr_label' == 0
}
if _rc == 0 {
    display as result "  PASS S10: Cox adjusted bound is labelled on the RR scale"
    local ++pass_count
}
else {
    display as error "  FAIL S10: Cox adjusted bound has the wrong scale label (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' S10"
}

display as text ""
display as text "=== Sensitivity Validation Summary ==="
display as text "Tests run: `test_count'"
display as result "Passed:   `pass_count'"
display as error  "Failed:   `fail_count'"

do "`qa_dir'/_record_qa_result.do" validation_msm_sensitivity ///
    `test_count' `pass_count' `fail_count' 0
display as text "RESULT: validation_msm_sensitivity tests=`test_count' pass=`pass_count' fail=`fail_count' skip=0"
if `fail_count' > 0 {
    display as error "Failed tests:`failed_tests'"
    exit 1
}
