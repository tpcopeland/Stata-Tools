* test_msm_period_basis.do
* QA for msm_weight's period_d_spec()/period_n_spec() time basis (v1.4.0).
*
* Hernan, Brumback & Robins (2000) Epidemiology 11:561-570, p.564: the
* time-dependent intercept alpha_0(k) of each weighting logit cannot be
* estimated as a free parameter per period and must be modelled as a smooth
* function of k; the weights were robust to how it was estimated "provided
* that sufficient flexibility was allowed". Before 1.4.0 the denominators
* carried a linear period term and the numerators none, with no way to change
* either.
*
* The load-bearing tests are PB2/PB3 (all four weighting logits refit by hand
* and matched bit for bit) and PB9 (a non-monotone treatment process leaves a
* 14-percentage-point period-specific residual under the linear default and
* about 1 point under a flexible basis). PB1 is the no-regression gate: the
* defaults must reproduce a hand-refit of the pre-1.4.0 models exactly.

version 16.0
clear all
set more off
set varabbrev off

local qa_dir  "`c(pwd)'"
local pkg_dir "`qa_dir'/.."

capture log close _all
log using "test_msm_period_basis.log", replace text nomsg

do "`qa_dir'/_install_msm_isolated.do" "`pkg_dir'"

local pass_count = 0
local fail_count = 0
local test_count = 0
local failed_tests ""

* A panel whose baseline treatment log-odds rises and falls across follow-up,
* with treatment-confounder feedback. A linear period term cannot represent it.
capture program drop _pb_gen_panel
program define _pb_gen_panel
    version 16.0
    syntax [, Seed(integer 771026) N(integer 700) T(integer 8)]

    clear
    set seed `seed'
    set obs `n'
    gen long id = _n
    gen double age = rnormal(60, 10)
    gen byte sex = runiform() < 0.5
    expand `t'
    bysort id: gen int period = _n - 1
    gen double alpha0 = -0.6 + 2.0 * sin(_pi * period / (`t' - 1))
    gen double L = .
    gen byte A = .
    gen byte Y = .
    gen byte C = .
    sort id period
    by id: replace L = rnormal(0, 1) if _n == 1
    quietly {
        forvalues k = 0/`=`t'-1' {
            if `k' > 0 {
                by id: replace L = 0.5 * L[_n-1] + 0.7 * A[_n-1] + rnormal(0, 1) ///
                    if period == `k'
            }
            replace A = runiform() < ///
                invlogit(alpha0 + 0.9 * L + 0.01 * (age - 60)) if period == `k'
            replace Y = runiform() < invlogit(-3.4 - 0.7 * A + 0.5 * L) if period == `k'
            replace C = runiform() < invlogit(-3.6 + 0.3 * A + 0.2 * L) if period == `k'
            replace C = 0 if Y == 1 & period == `k'
        }
    }
    by id: gen int _cumY = sum(Y[_n-1])
    by id: gen int _cumC = sum(C[_n-1])
    replace _cumY = 0 if missing(_cumY)
    replace _cumC = 0 if missing(_cumC)
    drop if _cumY > 0 | _cumC > 0
    drop _cumY _cumC alpha0
end

* Risk-set markers and the lagged treatment the package builds internally.
capture program drop _pb_hand_markers
program define _pb_hand_markers
    version 16.0
    sort id period
    by id: gen byte pb_first = (_n == 1)
    by id: gen byte pb_lagA = A[_n-1]
    by id: gen int pb_cumY = sum(Y[_n-1])
    by id: gen int pb_cumC = sum(C[_n-1])
    quietly replace pb_cumY = 0 if missing(pb_cumY)
    quietly replace pb_cumC = 0 if missing(pb_cumC)
    gen byte pb_risk_t = (pb_cumY == 0)
    gen byte pb_risk_c = (pb_cumY == 0 & pb_cumC == 0)
end

* Assert a hand-fitted probability equals the package's raw fitted probability
* on every row the hand fit covers. The non-missingness counts are compared
* first: reldif(., .) is 0, so a comparison of two all-missing columns would
* pass an equality test silently. The package column legitimately covers more
* rows than the hand fit (the first-period models fill the baseline rows), so
* only "package non-missing wherever hand is" is required here; PB10 checks the
* first-period rows separately.
capture program drop _pb_assert_parity
program define _pb_assert_parity
    version 16.0
    syntax varlist(min=2 max=2), LABel(string)

    local hand : word 1 of `varlist'
    local pkg  : word 2 of `varlist'

    quietly count if !missing(`hand')
    local n_hand = r(N)
    quietly count if !missing(`pkg')
    local n_pkg = r(N)
    quietly count if !missing(`hand') & !missing(`pkg')
    local n_both = r(N)

    if `n_hand' == 0 {
        display as error "  `label': hand fit produced no probabilities"
        exit 459
    }
    if `n_hand' != `n_both' {
        display as error "  `label': package value missing where the hand fit is not " ///
            "(hand=`n_hand' pkg=`n_pkg' both=`n_both')"
        exit 459
    }

    tempvar d
    quietly gen double `d' = reldif(`hand', `pkg') if !missing(`hand')
    quietly summarize `d'
    local maxd = r(max)
    display as text "  `label': n=`n_both' (pkg n=`n_pkg') max reldif = " ///
        as result %12.10f `maxd'
    assert `maxd' < 1e-12
end

display as text ""
display as text "{hline 72}"
display as result "msm_weight period basis QA (period_d_spec / period_n_spec)"
display as text "{hline 72}"

* --- PB1: defaults reproduce the pre-1.4.0 models (linear denom, no numerator time) ---
local ++test_count
capture noisily {
    _pb_gen_panel
    quietly msm_prepare, id(id) period(period) treatment(A) outcome(Y) ///
        censor(C) covariates(L) baseline_covariates(age sex)
    quietly msm_weight, treat_d_cov(L age sex) treat_n_cov(age sex) ///
        censor_d_cov(L age sex) nolog

    assert "`r(period_d_spec)'" == "linear"
    assert "`r(period_n_spec)'" == "none"

    _pb_hand_markers
    quietly logit A pb_lagA L age sex period if pb_risk_t & !pb_first, nolog
    quietly predict double pb_den if pb_risk_t & !pb_first, pr
    quietly logit A pb_lagA age sex if pb_risk_t & !pb_first, nolog
    quietly predict double pb_num if pb_risk_t & !pb_first, pr
    quietly logit C A L age sex period if pb_risk_c, nolog
    quietly predict double pb_cden if pb_risk_c, pr
    quietly logit C A if pb_risk_c, nolog
    quietly predict double pb_cnum if pb_risk_c, pr

    _pb_assert_parity pb_den _msm_treat_den_raw, label(PB1 treatment denominator)
    _pb_assert_parity pb_num _msm_treat_num_raw, label(PB1 treatment numerator)
    _pb_assert_parity pb_cden _msm_cens_den_raw, label(PB1 censoring denominator)
    _pb_assert_parity pb_cnum _msm_cens_num_raw, label(PB1 censoring numerator)
}
if _rc == 0 {
    display as result "  PASS PB1: defaults reproduce the pre-1.4.0 weighting models"
    local ++pass_count
}
else {
    display as error "  FAIL PB1: default models changed (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' PB1"
}

* --- PB2: period_d_spec(quadratic) reaches BOTH denominator models ---
local ++test_count
capture noisily {
    _pb_gen_panel
    quietly msm_prepare, id(id) period(period) treatment(A) outcome(Y) ///
        censor(C) covariates(L) baseline_covariates(age sex)
    quietly msm_weight, treat_d_cov(L age sex) treat_n_cov(age sex) ///
        censor_d_cov(L age sex) period_d_spec(quadratic) nolog

    assert "`r(period_d_spec)'" == "quadratic"
    assert "`r(period_n_spec)'" == "none"

    _pb_hand_markers
    gen double pb_p2 = period^2
    quietly logit A pb_lagA L age sex period pb_p2 if pb_risk_t & !pb_first, nolog
    quietly predict double pb_den if pb_risk_t & !pb_first, pr
    quietly logit C A L age sex period pb_p2 if pb_risk_c, nolog
    quietly predict double pb_cden if pb_risk_c, pr
    * The numerators must be untouched by period_d_spec().
    quietly logit A pb_lagA age sex if pb_risk_t & !pb_first, nolog
    quietly predict double pb_num if pb_risk_t & !pb_first, pr

    _pb_assert_parity pb_den _msm_treat_den_raw, label(PB2 treatment denominator)
    _pb_assert_parity pb_cden _msm_cens_den_raw, label(PB2 censoring denominator)
    _pb_assert_parity pb_num _msm_treat_num_raw, label(PB2 numerator unaffected)
}
if _rc == 0 {
    display as result "  PASS PB2: period_d_spec(quadratic) enters both denominators only"
    local ++pass_count
}
else {
    display as error "  FAIL PB2: denominator basis parity (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' PB2"
}

* --- PB3: period_n_spec(quadratic) reaches BOTH numerator models ---
local ++test_count
capture noisily {
    _pb_gen_panel
    quietly msm_prepare, id(id) period(period) treatment(A) outcome(Y) ///
        censor(C) covariates(L) baseline_covariates(age sex)
    quietly msm_weight, treat_d_cov(L age sex) treat_n_cov(age sex) ///
        censor_d_cov(L age sex) period_n_spec(quadratic) nolog

    assert "`r(period_d_spec)'" == "linear"
    assert "`r(period_n_spec)'" == "quadratic"

    _pb_hand_markers
    gen double pb_p2 = period^2
    quietly logit A pb_lagA age sex period pb_p2 if pb_risk_t & !pb_first, nolog
    quietly predict double pb_num if pb_risk_t & !pb_first, pr
    quietly logit C A period pb_p2 if pb_risk_c, nolog
    quietly predict double pb_cnum if pb_risk_c, pr
    * The denominators must be untouched by period_n_spec().
    quietly logit A pb_lagA L age sex period if pb_risk_t & !pb_first, nolog
    quietly predict double pb_den if pb_risk_t & !pb_first, pr

    _pb_assert_parity pb_num _msm_treat_num_raw, label(PB3 treatment numerator)
    _pb_assert_parity pb_cnum _msm_cens_num_raw, label(PB3 censoring numerator)
    _pb_assert_parity pb_den _msm_treat_den_raw, label(PB3 denominator unaffected)
}
if _rc == 0 {
    display as result "  PASS PB3: period_n_spec(quadratic) enters both numerators only"
    local ++pass_count
}
else {
    display as error "  FAIL PB3: numerator basis parity (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' PB3"
}

* --- PB4: period_d_spec(none) drops the time term entirely ---
local ++test_count
capture noisily {
    _pb_gen_panel
    quietly msm_prepare, id(id) period(period) treatment(A) outcome(Y) ///
        covariates(L) baseline_covariates(age sex)
    quietly msm_weight, treat_d_cov(L age sex) treat_n_cov(age sex) ///
        period_d_spec(none) nolog

    assert "`r(period_d_spec)'" == "none"

    _pb_hand_markers
    quietly logit A pb_lagA L age sex if pb_risk_t & !pb_first, nolog
    quietly predict double pb_den if pb_risk_t & !pb_first, pr
    _pb_assert_parity pb_den _msm_treat_den_raw, label(PB4 denominator without period)
}
if _rc == 0 {
    display as result "  PASS PB4: period_d_spec(none) removes the period term"
    local ++pass_count
}
else {
    display as error "  FAIL PB4: none spec (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' PB4"
}

* --- PB5: cubic and ns(#) run, change the weights, and leave no basis debris ---
local ++test_count
capture noisily {
    _pb_gen_panel
    tempfile pb5_base
    quietly save "`pb5_base'"

    local prev ""
    foreach spec in linear quadratic cubic ns(3) ns(4) {
        quietly use "`pb5_base'", clear
        quietly msm_prepare, id(id) period(period) treatment(A) outcome(Y) ///
            censor(C) covariates(L) baseline_covariates(age sex)
        quietly msm_weight, treat_d_cov(L age sex) treat_n_cov(age sex) ///
            censor_d_cov(L age sex) period_d_spec(`spec') period_n_spec(`spec') nolog

        assert "`r(period_d_spec)'" == "`spec'"
        assert "`r(period_n_spec)'" == "`spec'"

        * Every generated basis column must be gone: they are internal to the
        * weighting logits and must not survive into the caller's data.
        capture ds __msm_*
        if _rc == 0 {
            display as error "  basis debris after `spec': `r(varlist)'"
            exit 459
        }
        capture confirm variable _msm_period_sq
        assert _rc != 0
        capture confirm variable _msm_per_ns1
        assert _rc != 0

        quietly summarize _msm_weight
        local this_n = r(N)
        local this_mean = r(mean)
        assert !missing(`this_mean') & `this_n' > 0

        * Consecutive specs must not produce identical weights, or the option
        * is being parsed and discarded.
        if "`prev'" != "" {
            assert reldif(`prev', `this_mean') > 1e-8
        }
        local prev = `this_mean'
    }
}
if _rc == 0 {
    display as result "  PASS PB5: every spec runs, changes the weights, and cleans up its basis"
    local ++pass_count
}
else {
    display as error "  FAIL PB5: spec sweep (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' PB5"
}

* --- PB6: invalid specs are refused with rc 198 ---
local ++test_count
capture noisily {
    _pb_gen_panel
    quietly msm_prepare, id(id) period(period) treatment(A) outcome(Y) ///
        covariates(L) baseline_covariates(age sex)

    * A valid spec must first be ACCEPTED, or the rc=198 checks below would
    * also pass on a build where the options do not exist at all.
    quietly msm_weight, treat_d_cov(L age sex) period_d_spec(cubic) ///
        period_n_spec(cubic) nolog
    assert "`r(period_d_spec)'" == "cubic"
    quietly msm_prepare, id(id) period(period) treatment(A) outcome(Y) ///
        covariates(L) baseline_covariates(age sex)

    foreach bad in "quartic" "ns" "ns()" "ns(x)" "spline(3)" "ns(0)" {
        capture quietly msm_weight, treat_d_cov(L age sex) ///
            period_d_spec(`bad') nolog
        if _rc != 198 {
            display as error "  period_d_spec(`bad') gave rc=`=_rc', expected 198"
            exit 459
        }
        capture quietly msm_weight, treat_d_cov(L age sex) ///
            period_n_spec(`bad') nolog
        if _rc != 198 {
            display as error "  period_n_spec(`bad') gave rc=`=_rc', expected 198"
            exit 459
        }
    }

    * A refused spec must not leave a weighting behind.
    local weighted : char _dta[_msm_weighted]
    assert "`weighted'" == ""
    capture confirm variable _msm_weight
    assert _rc != 0
}
if _rc == 0 {
    display as result "  PASS PB6: invalid specs exit 198 and create no weights"
    local ++pass_count
}
else {
    display as error "  FAIL PB6: spec validation (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' PB6"
}

* --- PB7: a spline with more df than distinct periods is refused, not fitted ---
local ++test_count
capture noisily {
    _pb_gen_panel, t(4)
    quietly msm_prepare, id(id) period(period) treatment(A) outcome(Y) ///
        covariates(L) baseline_covariates(age sex)

    * 4 distinct periods support ns(3): that spec must be accepted, so this
    * test cannot pass on a build without the option.
    quietly msm_weight, treat_d_cov(L age sex) period_d_spec(ns(3)) nolog
    assert "`r(period_d_spec)'" == "ns(3)"
    quietly msm_prepare, id(id) period(period) treatment(A) outcome(Y) ///
        covariates(L) baseline_covariates(age sex)

    * ns(6) needs 7 distinct periods and must refuse.
    capture quietly msm_weight, treat_d_cov(L age sex) period_d_spec(ns(6)) nolog
    local rc_ns = _rc
    if `rc_ns' != 198 {
        display as error "  ns(6) on 4 periods gave rc=`rc_ns', expected 198"
        exit 459
    }

    * The refusal rolls the whole weighting transaction back.
    capture ds __msm_*
    assert _rc != 0
    capture confirm variable _msm_weight
    assert _rc != 0
    local weighted : char _dta[_msm_weighted]
    assert "`weighted'" == ""
}
if _rc == 0 {
    display as result "  PASS PB7: unsupported spline df is refused and rolled back"
    local ++pass_count
}
else {
    display as error "  FAIL PB7: spline support guard (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' PB7"
}

* --- PB8: specs are previewed, persisted, and invalidated with the weighting ---
local ++test_count
capture noisily {
    _pb_gen_panel
    quietly msm_prepare, id(id) period(period) treatment(A) outcome(Y) ///
        covariates(L) baseline_covariates(age sex)

    quietly msm_weight, treat_d_cov(L age sex) period_d_spec(cubic) ///
        period_n_spec(ns(3)) preview
    assert "`r(preview)'" == "1"
    assert "`r(period_d_spec)'" == "cubic"
    assert "`r(period_n_spec)'" == "ns(3)"
    * preview fits nothing
    capture confirm variable _msm_weight
    assert _rc != 0

    quietly msm_weight, treat_d_cov(L age sex) period_d_spec(cubic) ///
        period_n_spec(ns(3)) nolog
    local cd : char _dta[_msm_period_d_spec]
    local cn : char _dta[_msm_period_n_spec]
    assert "`cd'" == "cubic"
    assert "`cn'" == "ns(3)"

    local spec : char _dta[_msm_wt_spec]
    assert strpos("`spec'", "pd=cubic") > 0
    assert strpos("`spec'", "pn=ns(3)") > 0

    * Re-preparing invalidates the weighting layer, including these chars.
    quietly msm_prepare, id(id) period(period) treatment(A) outcome(Y) ///
        covariates(L) baseline_covariates(age sex)
    local cd2 : char _dta[_msm_period_d_spec]
    local cn2 : char _dta[_msm_period_n_spec]
    assert "`cd2'" == ""
    assert "`cn2'" == ""
}
if _rc == 0 {
    display as result "  PASS PB8: specs preview, persist, and invalidate with the weighting"
    local ++pass_count
}
else {
    display as error "  FAIL PB8: spec state surface (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' PB8"
}

* --- PB9: the flexible basis fixes a real misspecification ---
* On a non-monotone treatment process the linear default leaves a large
* period-specific mean residual in the denominator model. This is the defect
* Hernan et al. p.564 describe; a flexible basis must remove most of it.
local ++test_count
capture noisily {
    _pb_gen_panel, n(1500)
    tempfile pb9_base
    quietly save "`pb9_base'"

    local pb_i = 0
    foreach spec in linear quadratic ns(4) {
        local ++pb_i
        quietly use "`pb9_base'", clear
        quietly msm_prepare, id(id) period(period) treatment(A) outcome(Y) ///
            covariates(L) baseline_covariates(age sex)
        quietly msm_weight, treat_d_cov(L age sex) treat_n_cov(age sex) ///
            period_d_spec(`spec') period_n_spec(`spec') nolog

        quietly gen double pb_resid = A - _msm_treat_den_p if _msm_decision_risk
        quietly count if !missing(pb_resid)
        assert r(N) > 0
        quietly levelsof period, local(pb_pers)
        local pb_max = 0
        foreach p of local pb_pers {
            quietly summarize pb_resid if period == `p' & _msm_decision_risk
            if r(N) > 0 {
                local pb_a = abs(r(mean))
                if `pb_a' > `pb_max' local pb_max = `pb_a'
            }
        }
        local resid`pb_i' = `pb_max'
        display as text "  max |period-specific residual| under `spec': " ///
            as result %7.5f `pb_max'
        drop pb_resid
    }

    * Both directions are asserted. A test that only checked "flexible is
    * small" would pass on a DGP with no time trend at all, so the linear
    * default must first be shown to fail; and a test that only checked the
    * ratio would pass if both were tiny. Observed on this seed: linear 0.14,
    * quadratic 0.03, ns(4) 0.03.
    assert `resid1' > 0.08
    assert `resid2' < 0.05 & `resid2' < `resid1' / 2
    assert `resid3' < 0.05 & `resid3' < `resid1' / 2
}
if _rc == 0 {
    display as result "  PASS PB9: flexible basis removes the period-specific misspecification"
    local ++pass_count
}
else {
    display as error "  FAIL PB9: misspecification recovery (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' PB9"
}

* --- PB10: the first-period models carry no time term ---
* msm_weight requires a shared baseline period, so a period term there would be
* collinear with the intercept. A spec must not change the first-period fits.
local ++test_count
capture noisily {
    _pb_gen_panel
    tempfile pb10_base
    quietly save "`pb10_base'"

    quietly use "`pb10_base'", clear
    quietly msm_prepare, id(id) period(period) treatment(A) outcome(Y) ///
        covariates(L) baseline_covariates(age sex)
    quietly msm_weight, treat_d_cov(L age sex) treat_n_cov(age sex) nolog
    keep id period _msm_treat_den_raw _msm_treat_num_raw
    keep if period == 0
    rename (_msm_treat_den_raw _msm_treat_num_raw) (lin_den lin_num)
    tempfile pb10_lin
    quietly save "`pb10_lin'"

    quietly use "`pb10_base'", clear
    quietly msm_prepare, id(id) period(period) treatment(A) outcome(Y) ///
        covariates(L) baseline_covariates(age sex)
    quietly msm_weight, treat_d_cov(L age sex) treat_n_cov(age sex) ///
        period_d_spec(ns(4)) period_n_spec(ns(4)) nolog
    keep id period _msm_treat_den_raw _msm_treat_num_raw
    keep if period == 0
    quietly merge 1:1 id period using "`pb10_lin'", assert(match) nogen

    _pb_assert_parity lin_den _msm_treat_den_raw, label(PB10 first-period denominator)
    _pb_assert_parity lin_num _msm_treat_num_raw, label(PB10 first-period numerator)
}
if _rc == 0 {
    display as result "  PASS PB10: the first-period models are unaffected by the time basis"
    local ++pass_count
}
else {
    display as error "  FAIL PB10: first-period invariance (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' PB10"
}

display as text ""
display as text "{hline 72}"
display as text "Tests run: " as result `test_count'
display as text "Passed:    " as result `pass_count'
display as text "Failed:    " as result `fail_count'
do "`qa_dir'/_record_qa_result.do" test_msm_period_basis ///
    `test_count' `pass_count' `fail_count' 0
display as text "RESULT: test_msm_period_basis tests=`test_count' pass=`pass_count' fail=`fail_count' skip=0"
capture log close _all
if `fail_count' > 0 {
    display as error "Failed tests:`failed_tests'"
    display as text "{hline 72}"
    exit 459
}
display as result "All msm_weight period-basis tests passed"
display as text "{hline 72}"
