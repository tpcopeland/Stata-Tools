* validation_msm_known_answers.do
* Focused known-answer validation for exact and near-exact MSM formulas.
*
* Coverage:
*   - stabilized weight identities
*   - exact multi-period cumulative treatment weights
*   - exact censoring-weight identities
*   - exact logistic and linear fit identities under unit weights
*   - Cox wrapper equivalence to direct stcox
*   - exact prediction math for cum_inc and survival outputs
*   - exact null-effect prediction branch
*   - sensitivity known answers for logistic, cox, and linear branches,
*     including protective and CI-crossing edge cases

version 16.0
clear all
set more off
set varabbrev off

local qa_dir "`c(pwd)'"
local pkg_dir "`qa_dir'/.."

capture ado uninstall msm
quietly net install msm, from("`pkg_dir'") replace
adopath ++ "`pkg_dir'"

local test_count = 0
local pass_count = 0
local fail_count = 0
local failed_tests ""

capture program drop _ka_set_unit_weights
program define _ka_set_unit_weights
    version 16.0

    capture drop _msm_weight
    capture drop _msm_tw_weight
    gen double _msm_weight = 1
    gen double _msm_tw_weight = 1

    char _dta[_msm_weighted] "1"
    char _dta[_msm_weight_var] "_msm_weight"

    label variable _msm_weight "MSM cumulative IP weight"
    label variable _msm_tw_weight "MSM treatment weight (cumulative)"
end

capture program drop _ka_store_manual_fit
program define _ka_store_manual_fit
    version 16.0
    syntax , MODEL(string) B(name) V(name) ///
        [PERiod_spec(string) OUTcome_cov(string) Level(real 95)]

    local id : char _dta[_msm_id]
    if "`id'" == "" local id "id"
    if "`period_spec'" == "" local period_spec "none"

    capture matrix drop _msm_fit_b
    capture matrix drop _msm_fit_V
    matrix _msm_fit_b = `b'
    matrix _msm_fit_V = `v'

    capture drop _msm_esample
    gen byte _msm_esample = 1

    char _dta[_msm_fitted] "1"
    char _dta[_msm_model] "`model'"
    char _dta[_msm_period_spec] "`period_spec'"
    char _dta[_msm_outcome_cov] "`outcome_cov'"
    char _dta[_msm_per_ns_knots] ""
    char _dta[_msm_per_ns_df] ""
    char _dta[_msm_cluster] "`id'"
    char _dta[_msm_time_vars] ""
    char _dta[_msm_fit_level] "`level'"
end

display as text ""
display as text "=== validation_msm_known_answers.do ==="
display as text ""

* --- KA1: exact stabilized weights in a one-period binary-covariate design ---
* x=0: P(A=1|x)=0.25, x=1: P(A=1|x)=0.75, marginal P(A=1)=0.50
* Expected weights:
*   treated, x=0    => 0.50 / 0.25 = 2.0
*   untreated, x=0  => 0.50 / 0.75 = 2/3
*   treated, x=1    => 0.50 / 0.75 = 2/3
*   untreated, x=1  => 0.50 / 0.25 = 2.0
* ESS = (sum w)^2 / sum(w^2) = 160^2 / (40*4 + 120*(4/9)) = 120
local ++test_count
capture noisily {
    clear
    set obs 160
    gen long id = _n
    gen int period = 0
    gen byte x = (_n > 80)
    gen byte treatment = 0
    gen byte outcome = 0

    replace treatment = 1 if inrange(_n, 1, 20)
    replace treatment = 1 if inrange(_n, 81, 140)

    msm_prepare, id(id) period(period) treatment(treatment) ///
        outcome(outcome) covariates(x)
    msm_weight, treat_d_cov(x) nolog

    quietly summarize _msm_weight if x == 0 & treatment == 1, meanonly
    assert abs(r(mean) - 2) < 1e-10
    quietly summarize _msm_weight if x == 0 & treatment == 0, meanonly
    assert abs(r(mean) - (2/3)) < 1e-10
    quietly summarize _msm_weight if x == 1 & treatment == 1, meanonly
    assert abs(r(mean) - (2/3)) < 1e-10
    quietly summarize _msm_weight if x == 1 & treatment == 0, meanonly
    assert abs(r(mean) - 2) < 1e-10

    assert abs(r(mean_weight) - 1) < 1e-10
    assert abs(r(ess) - 120) < 1e-8
}
if _rc == 0 {
    display as result "  PASS KA1: exact stabilized weights and ESS"
    local ++pass_count
}
else {
    display as error "  FAIL KA1: exact stabilized weights and ESS (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' KA1"
}

* --- KA2: exact logistic coefficient and intercept from a 2x2 table ---
* Control risk = 20/100 = 0.20  => intercept = logit(0.20)
* Treated risk = 50/100 = 0.50  => log-OR = ln(4)
local ++test_count
capture noisily {
    clear
    set obs 200
    gen long id = _n
    gen int period = 0
    gen byte treatment = (_n > 100)
    gen byte outcome = 0

    replace outcome = 1 if inrange(_n, 1, 20)
    replace outcome = 1 if inrange(_n, 101, 150)

    msm_prepare, id(id) period(period) treatment(treatment) outcome(outcome)
    _ka_set_unit_weights
    msm_fit, model(logistic) period_spec(none) nolog

    local expected_cons = ln(0.20 / 0.80)
    local expected_b = ln(4)
    tempname effects
    matrix `effects' = e(effects)

    assert abs(_b[_cons] - `expected_cons') < 1e-8
    assert abs(_b[treatment] - `expected_b') < 1e-8
    assert abs(exp(_b[treatment]) - 4) < 1e-8
    assert abs(`effects'[1, 1] - `expected_b') < 1e-8
}
if _rc == 0 {
    display as result "  PASS KA2: exact logistic coefficient and intercept"
    local ++pass_count
}
else {
    display as error "  FAIL KA2: exact logistic coefficient and intercept (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' KA2"
}

* --- KA3: exact linear coefficient and intercept under unit weights ---
* Untreated mean = 2, treated mean = 5 => treatment coefficient = 3
local ++test_count
capture noisily {
    clear
    set obs 200
    gen long id = _n
    gen int period = 0
    gen byte treatment = (_n > 100)
    gen byte outcome = 0

    msm_prepare, id(id) period(period) treatment(treatment) outcome(outcome)
    replace outcome = cond(treatment == 1, 5, 2)
    _ka_set_unit_weights
    msm_fit, model(linear) period_spec(none) nolog

    tempname effects
    matrix `effects' = e(effects)

    assert abs(_b[_cons] - 2) < 1e-12
    assert abs(_b[treatment] - 3) < 1e-12
    assert abs(`effects'[1, 1] - 3) < 1e-12
}
if _rc == 0 {
    display as result "  PASS KA3: exact linear coefficient and intercept"
    local ++pass_count
}
else {
    display as error "  FAIL KA3: exact linear coefficient and intercept (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' KA3"
}

* --- KA4: msm_fit, model(cox) matches direct stcox exactly on the same data ---
local ++test_count
capture noisily {
    clear
    input byte(id treatment fail_time)
    1 0 5
    2 0 6
    3 0 6
    4 0 7
    5 0 7
    6 0 8
    7 1 2
    8 1 3
    9 1 3
    10 1 4
    11 1 4
    12 1 5
    end

    gen int n_periods = fail_time + 1
    expand n_periods
    bysort id: gen int period = _n - 1
    bysort id: gen byte outcome = (period == fail_time[1])
    drop n_periods fail_time

    msm_prepare, id(id) period(period) treatment(treatment) outcome(outcome)
    _ka_set_unit_weights
    msm_fit, model(cox) period_spec(none) nolog

    local b_msm = _b[treatment]
    local se_msm = _se[treatment]

    preserve
    gen double t0 = period
    gen double t1 = period + 1
    stset t1 [pw=_msm_weight], enter(t0) failure(outcome)
    stcox treatment, vce(cluster id) nolog
    local b_direct = _b[treatment]
    local se_direct = _se[treatment]
    restore

    assert reldif(`b_msm', `b_direct') < 1e-10
    assert reldif(`se_msm', `se_direct') < 1e-10
    assert exp(`b_msm') > 1
}
if _rc == 0 {
    display as result "  PASS KA4: Cox wrapper equals direct stcox"
    local ++pass_count
}
else {
    display as error "  FAIL KA4: Cox wrapper equals direct stcox (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' KA4"
}

* --- KA5: exact cum_inc predictions with constant hazards and zero-variance draws ---
* Never-treated hazard = 0.20 each period
* Always-treated hazard = invlogit(logit(0.20) + ln(2)) = 1/3 each period
local ++test_count
capture noisily {
    clear
    set obs 20
    gen long id = ceil(_n / 4)
    bysort id: gen int period = _n - 1
    gen byte treatment = 0
    gen byte outcome = 0

    msm_prepare, id(id) period(period) treatment(treatment) outcome(outcome)
    _ka_set_unit_weights

    tempname b V P
    matrix `b' = (ln(0.20 / 0.80), ln(2))
    matrix colnames `b' = _cons treatment
    matrix `V' = J(2, 2, 0)
    _ka_store_manual_fit, model(logistic) b(`b') v(`V') period_spec(none)

    msm_predict, times(0 1 2 3) type(cum_inc) difference samples(10) seed(12345)
    matrix `P' = r(predictions)

    local q_never = 0.20
    local q_always = 1/3
    local row = 0
    foreach t in 0 1 2 3 {
        local ++row
        local k = `t' + 1
        local exp_never = 1 - (1 - `q_never')^`k'
        local exp_always = 1 - (1 - `q_always')^`k'
        local exp_diff = `exp_always' - `exp_never'

        assert abs(`P'[`row', 2] - `exp_never') < 1e-10
        assert abs(`P'[`row', 3] - `exp_never') < 1e-10
        assert abs(`P'[`row', 4] - `exp_never') < 1e-10
        assert abs(`P'[`row', 5] - `exp_always') < 1e-10
        assert abs(`P'[`row', 6] - `exp_always') < 1e-10
        assert abs(`P'[`row', 7] - `exp_always') < 1e-10
        assert abs(`P'[`row', 8] - `exp_diff') < 1e-10
        assert abs(`P'[`row', 9] - `exp_diff') < 1e-10
        assert abs(`P'[`row', 10] - `exp_diff') < 1e-10
        assert abs(r(rd_`t') - `exp_diff') < 1e-10
    }

    assert "`r(seed)'" == "12345"
    assert "`r(seed_source)'" == "seed()"
}
if _rc == 0 {
    display as result "  PASS KA5: exact constant-hazard cum_inc predictions"
    local ++pass_count
}
else {
    display as error "  FAIL KA5: exact constant-hazard cum_inc predictions (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' KA5"
}

* --- KA6: exact survival predictions with a linear period effect ---
local ++test_count
capture noisily {
    clear
    set obs 12
    gen long id = ceil(_n / 3)
    bysort id: gen int period = _n - 1
    gen byte treatment = 0
    gen byte outcome = 0

    msm_prepare, id(id) period(period) treatment(treatment) outcome(outcome)
    _ka_set_unit_weights

    tempname b V P
    local alpha = ln(0.10 / 0.90)
    local beta = ln(2)
    local gamma = 0.25
    matrix `b' = (`alpha', `beta', `gamma')
    matrix colnames `b' = _cons treatment period
    matrix `V' = J(3, 3, 0)
    _ka_store_manual_fit, model(logistic) b(`b') v(`V') period_spec(linear)

    msm_predict, times(0 1 2) strategy(always) type(survival) ///
        samples(10) seed(24680)
    matrix `P' = r(predictions)

    local expected_surv = 1
    local row = 0
    foreach t in 0 1 2 {
        local ++row
        local p_t = invlogit(`alpha' + `beta' + `gamma' * `t')
        local expected_surv = `expected_surv' * (1 - `p_t')

        assert abs(`P'[`row', 5] - `expected_surv') < 1e-10
        assert abs(`P'[`row', 6] - `expected_surv') < 1e-10
        assert abs(`P'[`row', 7] - `expected_surv') < 1e-10
    }

    assert "`r(strategy)'" == "always"
    assert "`r(type)'" == "survival"
}
if _rc == 0 {
    display as result "  PASS KA6: exact survival predictions with period effect"
    local ++pass_count
}
else {
    display as error "  FAIL KA6: exact survival predictions with period effect (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' KA6"
}

* --- KA7: outcome_cov() values are averaged over the baseline reference population ---
local ++test_count
capture noisily {
    clear
    set obs 6
    gen long id = ceil(_n / 3)
    bysort id: gen int period = _n - 1
    gen byte treatment = 0
    gen byte outcome = 0
    gen double x = id - 1
    bysort id: replace x = x[1]

    msm_prepare, id(id) period(period) treatment(treatment) ///
        outcome(outcome) baseline_covariates(x)
    _ka_set_unit_weights

    tempname b V P
    local alpha = ln(0.20 / 0.80)
    local gamma = ln(1.5)
    matrix `b' = (`alpha', 0, `gamma')
    matrix colnames `b' = _cons treatment x
    matrix `V' = J(3, 3, 0)
    _ka_store_manual_fit, model(logistic) b(`b') v(`V') ///
        period_spec(none) outcome_cov(x)

    msm_predict, times(0 1) strategy(never) type(cum_inc) ///
        samples(10) seed(333)
    matrix `P' = r(predictions)

    local p_x0 = 0.20
    local p_x1 = invlogit(`alpha' + `gamma')
    local row = 0
    foreach t in 0 1 {
        local ++row
        local k = `t' + 1
        local expected = 1 - (((1 - `p_x0')^`k' + (1 - `p_x1')^`k') / 2)

        assert abs(`P'[`row', 2] - `expected') < 1e-10
        assert abs(`P'[`row', 3] - `expected') < 1e-10
        assert abs(`P'[`row', 4] - `expected') < 1e-10
    }
}
if _rc == 0 {
    display as result "  PASS KA7: outcome_cov() averaging uses baseline reference values"
    local ++pass_count
}
else {
    display as error "  FAIL KA7: outcome_cov() averaging uses baseline reference values (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' KA7"
}

* --- KA8: exact logistic sensitivity values from a known OR ---
* OR = 4, prevalence = 0.35, E-value = 4 + sqrt(12), bias factor = 1.5
local ++test_count
capture noisily {
    clear
    set obs 200
    gen long id = _n
    gen int period = 0
    gen byte treatment = (_n > 100)
    gen byte outcome = 0

    replace outcome = 1 if inrange(_n, 1, 20)
    replace outcome = 1 if inrange(_n, 101, 150)

    msm_prepare, id(id) period(period) treatment(treatment) outcome(outcome)
    _ka_set_unit_weights
    msm_fit, model(logistic) period_spec(none) nolog
    msm_sensitivity, evalue confounding_strength(2 3) rarethreshold(0.40)

    local expected_evalue = 4 + sqrt(12)
    local expected_bias = 1.5
    local expected_corrected = 4 / 1.5

    assert abs(r(effect) - 4) < 1e-8
    assert abs(r(outcome_prevalence) - 0.35) < 1e-10
    assert abs(r(rare_threshold) - 0.40) < 1e-10
    assert abs(r(evalue_point) - `expected_evalue') < 1e-8
    assert abs(r(bias_factor) - `expected_bias') < 1e-10
    assert abs(r(corrected_effect) - `expected_corrected') < 1e-10
    assert "`r(effect_label)'" == "OR"
    assert "`r(model)'" == "logistic"
    assert "`r(approximation)'" == "rare-outcome auto"
}
if _rc == 0 {
    display as result "  PASS KA8: exact logistic sensitivity values"
    local ++pass_count
}
else {
    display as error "  FAIL KA8: exact logistic sensitivity values (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' KA8"
}

* --- KA9: exact Cox sensitivity values from a manual HR = 2 fit state ---
local ++test_count
capture noisily {
    clear
    set obs 4
    gen long id = _n
    gen int period = 0
    gen byte treatment = mod(_n, 2)
    gen byte outcome = 0

    msm_prepare, id(id) period(period) treatment(treatment) outcome(outcome)
    _ka_set_unit_weights

    tempname b V
    matrix `b' = (ln(2))
    matrix colnames `b' = treatment
    matrix `V' = J(1, 1, 0)
    _ka_store_manual_fit, model(cox) b(`b') v(`V') period_spec(none)

    msm_sensitivity, evalue confounding_strength(2 3)

    local expected_evalue = 2 + sqrt(2)
    assert abs(r(effect) - 2) < 1e-10
    assert abs(r(evalue_point) - `expected_evalue') < 1e-10
    assert abs(r(evalue_ci) - `expected_evalue') < 1e-10
    assert abs(r(bias_factor) - 1.5) < 1e-10
    assert abs(r(corrected_effect) - (4/3)) < 1e-10
    assert "`r(effect_label)'" == "HR"
    assert "`r(model)'" == "cox"
    assert "`r(approximation)'" == "none"
}
if _rc == 0 {
    display as result "  PASS KA9: exact Cox sensitivity values"
    local ++pass_count
}
else {
    display as error "  FAIL KA9: exact Cox sensitivity values (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' KA9"
}

* --- KA10: linear sensitivity returns exact coefficient-scale values only ---
local ++test_count
capture noisily {
    clear
    set obs 4
    gen long id = _n
    gen int period = 0
    gen byte treatment = mod(_n, 2)
    gen byte outcome = 0

    msm_prepare, id(id) period(period) treatment(treatment) outcome(outcome)
    _ka_set_unit_weights

    tempname b V
    matrix `b' = (1.5)
    matrix colnames `b' = treatment
    matrix `V' = (0.04)
    _ka_store_manual_fit, model(linear) b(`b') v(`V') period_spec(none)

    msm_sensitivity, evalue confounding_strength(2 3)

    local zcrit = invnormal(0.975)
    local expected_lo = 1.5 - `zcrit' * 0.2
    local expected_hi = 1.5 + `zcrit' * 0.2

    assert abs(r(effect) - 1.5) < 1e-10
    assert abs(r(effect_lo) - `expected_lo') < 1e-10
    assert abs(r(effect_hi) - `expected_hi') < 1e-10
    assert r(rr_ud) == 2
    assert r(rr_uy) == 3
    assert "`r(effect_label)'" == "Coef"
    assert "`r(model)'" == "linear"
    assert "`r(approximation)'" == "none"
}
if _rc == 0 {
    display as result "  PASS KA10: linear sensitivity exact coefficient-scale values"
    local ++pass_count
}
else {
    display as error "  FAIL KA10: linear sensitivity exact coefficient-scale values (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' KA10"
}

* --- KA11: exact cumulative treatment weights across two periods ---
* Period 0 treatment probabilities:
*   P(A0=1|x=0)=0.25, P(A0=1|x=1)=0.75
* Period 1 denominator probabilities:
*   P(A1=1|A0,x)=0.25 if x=0, 0.75 if x=1
* Period 1 numerator probabilities:
*   P(A1=1|A0=0)=0.375, P(A1=1|A0=1)=0.625
* Expected cumulative period-1 weights:
*   x0,A0=1,A1=1 => 5
*   x0,A0=1,A1=0 => 1
*   x0,A0=0,A1=1 => 1
*   x0,A0=0,A1=0 => 5/9
*   x1,A0=1,A1=1 => 5/9
*   x1,A0=1,A1=0 => 1
*   x1,A0=0,A1=1 => 1
*   x1,A0=0,A1=0 => 5
local ++test_count
capture noisily {
    clear
    set obs 160
    gen long id = _n
    gen byte x = (_n > 80)
    gen byte a0 = 0
    gen byte a1 = 0
    gen byte outcome = 0

    replace a0 = 1 if inrange(id, 1, 20)
    replace a0 = 1 if inrange(id, 81, 140)

    replace a1 = 1 if inrange(id, 1, 5)
    replace a1 = 1 if inrange(id, 21, 35)
    replace a1 = 1 if inrange(id, 81, 125)
    replace a1 = 1 if inrange(id, 141, 155)

    expand 2
    bysort id: gen int period = _n - 1
    gen byte treatment = cond(period == 0, a0, a1)

    msm_prepare, id(id) period(period) treatment(treatment) ///
        outcome(outcome) covariates(x)
    msm_weight, treat_d_cov(x) nolog
    local overall_mean = r(mean_weight)

    quietly summarize _msm_tw_weight if period == 0, meanonly
    assert abs(r(mean) - 1) < 1e-10
    quietly summarize _msm_tw_weight if period == 1, meanonly
    assert abs(r(mean) - 1) < 1e-10

    quietly summarize _msm_tw_weight if period == 1 & x == 0 & a0 == 1 & a1 == 1, meanonly
    assert abs(r(mean) - 5) < 1e-10
    quietly summarize _msm_tw_weight if period == 1 & x == 0 & a0 == 1 & a1 == 0, meanonly
    assert abs(r(mean) - 1) < 1e-10
    quietly summarize _msm_tw_weight if period == 1 & x == 0 & a0 == 0 & a1 == 1, meanonly
    assert abs(r(mean) - 1) < 1e-10
    quietly summarize _msm_tw_weight if period == 1 & x == 0 & a0 == 0 & a1 == 0, meanonly
    assert abs(r(mean) - (5 / 9)) < 1e-10
    quietly summarize _msm_tw_weight if period == 1 & x == 1 & a0 == 1 & a1 == 1, meanonly
    assert abs(r(mean) - (5 / 9)) < 1e-10
    quietly summarize _msm_tw_weight if period == 1 & x == 1 & a0 == 1 & a1 == 0, meanonly
    assert abs(r(mean) - 1) < 1e-10
    quietly summarize _msm_tw_weight if period == 1 & x == 1 & a0 == 0 & a1 == 1, meanonly
    assert abs(r(mean) - 1) < 1e-10
    quietly summarize _msm_tw_weight if period == 1 & x == 1 & a0 == 0 & a1 == 0, meanonly
    assert abs(r(mean) - 5) < 1e-10

    assert abs(`overall_mean' - 1) < 1e-10
}
if _rc == 0 {
    display as result "  PASS KA11: exact cumulative two-period treatment weights"
    local ++pass_count
}
else {
    display as error "  FAIL KA11: exact cumulative two-period treatment weights (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' KA11"
}

* --- KA12: exact null treatment effect gives identical predictions ---
local ++test_count
capture noisily {
    clear
    set obs 12
    gen long id = ceil(_n / 3)
    bysort id: gen int period = _n - 1
    gen byte treatment = 0
    gen byte outcome = 0

    msm_prepare, id(id) period(period) treatment(treatment) outcome(outcome)
    _ka_set_unit_weights

    tempname b V P
    local alpha = ln(0.20 / 0.80)
    matrix `b' = (`alpha', 0)
    matrix colnames `b' = _cons treatment
    matrix `V' = J(2, 2, 0)
    _ka_store_manual_fit, model(logistic) b(`b') v(`V') period_spec(none)

    msm_predict, times(0 1 2) type(cum_inc) difference samples(10) seed(20260422)
    matrix `P' = r(predictions)

    local row = 0
    foreach t in 0 1 2 {
        local ++row
        local k = `t' + 1
        local expected = 1 - (0.80^`k')

        assert abs(`P'[`row', 2] - `expected') < 1e-10
        assert abs(`P'[`row', 3] - `expected') < 1e-10
        assert abs(`P'[`row', 4] - `expected') < 1e-10
        assert abs(`P'[`row', 5] - `expected') < 1e-10
        assert abs(`P'[`row', 6] - `expected') < 1e-10
        assert abs(`P'[`row', 7] - `expected') < 1e-10
        assert abs(`P'[`row', 8]) < 1e-12
        assert abs(`P'[`row', 9]) < 1e-12
        assert abs(`P'[`row', 10]) < 1e-12
        assert abs(r(rd_`t')) < 1e-12
    }
}
if _rc == 0 {
    display as result "  PASS KA12: exact null-effect predictions and zero risk difference"
    local ++pass_count
}
else {
    display as error "  FAIL KA12: exact null-effect predictions and zero risk difference (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' KA12"
}

* --- KA13: exact logistic sensitivity values for a protective OR = 0.5 ---
local ++test_count
capture noisily {
    clear
    set obs 4
    gen long id = _n
    gen int period = 0
    gen byte treatment = mod(_n, 2)
    gen byte outcome = 0

    msm_prepare, id(id) period(period) treatment(treatment) outcome(outcome)
    _ka_set_unit_weights

    tempname b V
    matrix `b' = (ln(0.5))
    matrix colnames `b' = treatment
    matrix `V' = J(1, 1, 0)
    _ka_store_manual_fit, model(logistic) b(`b') v(`V') period_spec(none)

    msm_sensitivity, evalue confounding_strength(2 3)

    local expected_evalue = 2 + sqrt(2)
    assert abs(r(effect) - 0.5) < 1e-10
    assert abs(r(outcome_prevalence) - 0) < 1e-12
    assert abs(r(evalue_point) - `expected_evalue') < 1e-10
    assert abs(r(evalue_ci) - `expected_evalue') < 1e-10
    assert abs(r(bias_factor) - 1.5) < 1e-10
    assert abs(r(corrected_effect) - (1 / 3)) < 1e-10
    assert "`r(effect_label)'" == "OR"
    assert "`r(model)'" == "logistic"
    assert "`r(approximation)'" == "rare-outcome auto"
}
if _rc == 0 {
    display as result "  PASS KA13: exact protective logistic sensitivity values"
    local ++pass_count
}
else {
    display as error "  FAIL KA13: exact protective logistic sensitivity values (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' KA13"
}

* --- KA14: exact E-value CI behavior when the CI crosses the null ---
local ++test_count
capture noisily {
    clear
    set obs 4
    gen long id = _n
    gen int period = 0
    gen byte treatment = mod(_n, 2)
    gen byte outcome = 0

    msm_prepare, id(id) period(period) treatment(treatment) outcome(outcome)
    _ka_set_unit_weights

    tempname b V
    matrix `b' = (ln(1.5))
    matrix colnames `b' = treatment
    matrix `V' = (0.25)
    _ka_store_manual_fit, model(logistic) b(`b') v(`V') period_spec(none)

    msm_sensitivity, evalue

    local zcrit = invnormal(0.975)
    local expected_lo = exp(ln(1.5) - `zcrit' * 0.5)
    local expected_hi = exp(ln(1.5) + `zcrit' * 0.5)
    local expected_evalue = 1.5 + sqrt(1.5 * 0.5)

    assert abs(r(effect) - 1.5) < 1e-10
    assert abs(r(effect_lo) - `expected_lo') < 1e-10
    assert abs(r(effect_hi) - `expected_hi') < 1e-10
    assert r(effect_lo) < 1
    assert r(effect_hi) > 1
    assert abs(r(evalue_point) - `expected_evalue') < 1e-10
    assert abs(r(evalue_ci) - 1) < 1e-12
    assert "`r(approximation)'" == "rare-outcome auto"
}
if _rc == 0 {
    display as result "  PASS KA14: exact E-value CI null-crossing behavior"
    local ++pass_count
}
else {
    display as error "  FAIL KA14: exact E-value CI null-crossing behavior (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' KA14"
}

* --- KA15: exact stabilized censoring weights in a one-period design ---
* Treatment is independent of x, so IPTW = 1 exactly.
* Censoring probabilities by x:
*   x=0 => P(C=1|x)=0.25  => cw = (1-0.50)/(1-0.25) = 2/3
*   x=1 => P(C=1|x)=0.75  => cw = (1-0.50)/(1-0.75) = 2
* Combined weights equal censoring weights because treatment weights are 1.
* ESS = (sum w)^2 / sum(w^2) = 128
local ++test_count
capture noisily {
    clear
    set obs 160
    gen long id = _n
    gen int period = 0
    gen byte x = (_n > 80)
    gen byte treatment = 0
    gen byte outcome = 0
    gen byte censor = 0

    replace treatment = 1 if inrange(id, 1, 40)
    replace treatment = 1 if inrange(id, 81, 120)

    replace censor = 1 if inrange(id, 1, 10)
    replace censor = 1 if inrange(id, 41, 50)
    replace censor = 1 if inrange(id, 81, 110)
    replace censor = 1 if inrange(id, 121, 150)

    msm_prepare, id(id) period(period) treatment(treatment) ///
        outcome(outcome) censor(censor) covariates(x)
    msm_weight, treat_d_cov(x) censor_d_cov(x) nolog
    local mean_weight = r(mean_weight)
    local ess = r(ess)
    local n_fitfail_fallback = r(n_fitfail_fallback)
    local n_probability_repairs = r(n_probability_repairs)

    quietly summarize _msm_tw_weight, meanonly
    assert abs(r(mean) - 1) < 1e-10
    assert abs(r(min) - 1) < 1e-10
    assert abs(r(max) - 1) < 1e-10

    quietly summarize _msm_cw_weight if x == 0, meanonly
    assert abs(r(mean) - (2 / 3)) < 1e-8
    quietly summarize _msm_cw_weight if x == 1, meanonly
    assert abs(r(mean) - 2) < 1e-8

    quietly summarize _msm_weight if x == 0, meanonly
    assert abs(r(mean) - (2 / 3)) < 1e-8
    quietly summarize _msm_weight if x == 1, meanonly
    assert abs(r(mean) - 2) < 1e-8

    assert abs(`mean_weight' - (4 / 3)) < 1e-8
    assert abs(`ess' - 128) < 1e-8
    assert `n_fitfail_fallback' == 0
    assert `n_probability_repairs' == 0

    tempvar wdiff
    gen double `wdiff' = abs(_msm_weight - _msm_cw_weight)
    quietly summarize `wdiff', meanonly
    assert r(max) < 1e-12
}
if _rc == 0 {
    display as result "  PASS KA15: exact stabilized censoring weights and combined weight identity"
    local ++pass_count
}
else {
    display as error "  FAIL KA15: exact stabilized censoring weights and combined weight identity (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' KA15"
}

display as text ""
display as text "=== Known-Answer Validation Summary ==="
display as text "Tests run: `test_count'"
display as result "Passed:   `pass_count'"
display as error  "Failed:   `fail_count'"

if `fail_count' > 0 {
    display as error "Failed tests:`failed_tests'"
    exit 1
}
