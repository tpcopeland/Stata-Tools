* test_msm_phase5.do
* Phase 5 regressions: sensitivity / diagnostics / output.
*
* Findings covered (audit 2026-07-12):
*   A26  SMD threshold must be finite/nonnegative; a missing weighted SMD is
*        UNAVAILABLE, not imbalanced; percent change is missing (not 0) when the
*        unweighted SMD denominator is ~0
*   A28  linear-model sensitivity refuses rather than exiting rc 0 with
*        _msm_sens_saved=1 and no computed measure
*   A29  confounding_strength() persists the bias factor and the bound
*   A30  a report/protocol write error is surfaced, not swallowed by the
*        capture-file-close cleanup
*
* Every refusal test is paired with a positive control. Reference:
* rc198_error_test_needs_positive_control.

version 16.0
clear all
set more off
set varabbrev off

capture log close _all
log using "test_msm_phase5.log", replace text nomsg

local qa_dir  "`c(pwd)'"
local pkg_dir "`qa_dir'/.."

do "`qa_dir'/_install_msm_isolated.do" "`pkg_dir'"
do "`qa_dir'/_msm_qa_common.do"

local test_count = 0
local pass_count = 0
local fail_count = 0
local failed_tests ""

capture program drop _p5_panel
program define _p5_panel
    version 16.0
    syntax [, seed(integer 50501) nids(integer 500) tper(integer 5)]
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
    * rare outcome so the logistic E-value's rare-outcome approximation applies
    gen byte out   = runiform() < invlogit(-3.6 + 0.7 * treat + 0.5 * L)
    bysort id (period): gen byte _po = sum(out[_n-1]) >= 1 if _n > 1
    replace _po = 0 if missing(_po)
    drop if _po > 0
    drop _po L0
end

* =========================================================================
* A28: linear-model sensitivity refuses instead of a false success
* =========================================================================
local ++test_count
capture noisily {
    _p5_panel
    msm_prepare, id(id) period(period) treatment(treat) outcome(out) covariates(L) baseline_covariates(age sex)
    msm_weight, treat_d_cov(L age sex) nolog
    msm_fit, model(linear) outcome_cov(age sex) vce(cluster id) nolog
    * default (E-value) on a linear model produces NO sensitivity measure, so it
    * must NOT set the saved flag (old code set saved=1 with a missing E-value).
    * The effect estimate is still returned for information, without erroring.
    msm_sensitivity
    assert r(metric_produced) == 0
    assert "`: char _dta[_msm_sens_saved]'" != "1"
    assert r(effect) != .

    * positive control: E-value on a logistic model produces a metric and saves
    _p5_panel
    msm_prepare, id(id) period(period) treatment(treat) outcome(out) covariates(L) baseline_covariates(age sex)
    msm_weight, treat_d_cov(L age sex) nolog
    msm_fit, model(logistic) outcome_cov(age sex) vce(cluster id) nolog
    msm_sensitivity
    assert r(evalue_point) != .
    assert r(metric_produced) == 1
    assert "`: char _dta[_msm_sens_saved]'" == "1"
}
if _rc == 0 {
    display as result "PASS A28: linear sensitivity refuses; logistic E-value saves"
    local ++pass_count
}
else {
    display as error "FAIL A28: linear sensitivity contract (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' A28"
}

* =========================================================================
* A29: confounding_strength() persists the bias factor and the bound
* =========================================================================
local ++test_count
capture noisily {
    _p5_panel
    msm_prepare, id(id) period(period) treatment(treat) outcome(out) covariates(L) baseline_covariates(age sex)
    msm_weight, treat_d_cov(L age sex) nolog
    msm_fit, model(logistic) outcome_cov(age sex) vce(cluster id) nolog
    msm_sensitivity, confounding_strength(2 2)
    assert r(bias_factor) != .
    assert r(bound) != .
    * the bias factor and bound are persisted for the table
    assert "`: char _dta[_msm_sens_bias_factor]'" != ""
    assert "`: char _dta[_msm_sens_bound]'" != ""
    * bias factor for RR_UD=RR_UY=2 is (2*2)/(2+2-1) = 4/3
    assert reldif(r(bias_factor), 4/3) < 1e-10
}
if _rc == 0 {
    display as result "PASS A29: bias factor and bound are returned and persisted"
    local ++pass_count
}
else {
    display as error "FAIL A29: sensitivity persistence (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' A29"
}

* =========================================================================
* A26: threshold validation; missing SMD unavailable; pct_change missing
* =========================================================================
local ++test_count
capture noisily {
    _p5_panel
    msm_prepare, id(id) period(period) treatment(treat) outcome(out) covariates(L) baseline_covariates(age sex)
    msm_weight, treat_d_cov(L age sex) nolog

    * a negative threshold is refused
    capture msm_diagnose, balance_covariates(L age sex) threshold(-1)
    assert _rc == 198
    * a missing threshold is refused
    capture msm_diagnose, balance_covariates(L age sex) threshold(.)
    assert _rc == 198
    * positive control: a valid threshold works and reports no unavailable SMDs
    msm_diagnose, balance_covariates(L age sex) threshold(0.1)
    assert r(n_unavailable) == 0

    * a covariate perfectly separated by treatment (zero variance in each arm,
    * different arm means) has an UNDEFINED (missing) SMD -> UNAVAILABLE, not
    * imbalanced. Old code counted abs(.) > threshold as imbalanced.
    gen double sepvar = treat * 5
    msm_diagnose, balance_covariates(L sepvar) threshold(0.1)
    assert r(n_unavailable) >= 1
}
if _rc == 0 {
    display as result "PASS A26: threshold validated; missing SMD is unavailable, not imbalanced"
    local ++pass_count
}
else {
    display as error "FAIL A26: diagnostic edge cases (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' A26"
}

* =========================================================================
* A30: a report write error is surfaced, not swallowed by cleanup
* =========================================================================
local ++test_count
capture noisily {
    _p5_panel
    msm_prepare, id(id) period(period) treatment(treat) outcome(out) covariates(L) baseline_covariates(age sex)
    msm_weight, treat_d_cov(L age sex) nolog
    msm_fit, model(logistic) outcome_cov(age sex) vce(cluster id) nolog

    * writing to a nonexistent directory must FAIL, not silently succeed.
    * Old code: `capture file close' reset _rc to 0, so `exit _rc' returned 0.
    capture msm_report, format(csv) export("`c(tmpdir)'/no_such_dir_msm/rep.csv")
    assert _rc != 0

    * positive control: a valid path exports and rc 0
    tempfile good
    msm_report, format(csv) export("`good'.csv")
    assert _rc == 0
    capture confirm file "`good'.csv"
    assert _rc == 0
}
if _rc == 0 {
    display as result "PASS A30: report write failure surfaces instead of being swallowed"
    local ++pass_count
}
else {
    display as error "FAIL A30: report write-error contract (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' A30"
}

* =========================================================================
* A12: E-value rarity uses the subject-level cumulative incidence by end of
*      follow-up, NOT the pooled person-period outcome mean; a common outcome
*      uses RR = sqrt(OR) (VanderWeele & Ding 2017). The fixture is built so the
*      pooled person-period mean is rare (< 0.15) while the cumulative incidence
*      is common (> 0.15): on HEAD the wrong denominator called it rare and the
*      common outcome was refused (rc 498).
* =========================================================================
capture program drop _p5_a12
program define _p5_a12
    version 16.0
    clear
    set seed 51212
    set obs 500
    gen long id = _n
    gen double bl = rnormal()
    gen double age = 40 + 10*runiform()
    gen byte sex = runiform() < 0.5
    expand 10
    bysort id: gen int period = _n - 1
    gen double L = bl + rnormal()*0.4
    gen byte treat = runiform() < invlogit(0.3*L)
    * low PER-PERIOD event probability, but 10 periods => high CUMULATIVE incidence
    gen byte out = runiform() < invlogit(-3.0 + 0.6*treat + 0.4*L)
    bysort id (period): gen byte _po = sum(out[_n-1]) >= 1 if _n > 1
    replace _po = 0 if missing(_po)
    drop if _po > 0
    drop _po bl
end

local ++test_count
capture noisily {
    _p5_a12
    * the fixture must DISCRIMINATE: pooled person-period mean is "rare" while
    * the subject-level cumulative incidence is "common".
    quietly summarize out, meanonly
    local pp_mean = r(mean)
    bysort id: egen byte _ever = max(out == 1)
    bysort id (period): gen byte _tag = (_n == _N)
    quietly summarize _ever if _tag, meanonly
    local cuminc = r(mean)
    drop _ever _tag
    assert `pp_mean' < 0.15
    assert `cuminc'  > 0.15

    msm_prepare, id(id) period(period) treatment(treat) outcome(out) covariates(L) baseline_covariates(age sex)
    msm_weight, treat_d_cov(L age sex) nolog
    msm_fit, model(logistic) outcome_cov(age sex) vce(cluster id) nolog
    msm_sensitivity, evalue
    * subject-level cumulative incidence drives the rarity call ...
    assert abs(r(cumulative_incidence) - `cuminc') < 1e-8
    assert r(cumulative_incidence) > r(rare_threshold)
    * ... and a common outcome uses RR = sqrt(OR), not the raw OR.
    assert "`r(approximation)'" == "common-outcome sqrt(OR)"
    local rr = sqrt(r(effect))
    if `rr' < 1 local rr = 1 / `rr'
    assert abs(r(evalue_point) - (`rr' + sqrt(`rr' * (`rr' - 1)))) < 1e-6
}
if _rc == 0 {
    display as result "PASS A12: rarity is end-of-follow-up cumulative incidence; sqrt(OR) transform"
    local ++pass_count
}
else {
    display as error "FAIL A12: E-value rarity denominator / sqrt(OR) transform (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' A12"
}

* =========================================================================
* A13: a Cox MSM runs the same rarity gate; a common outcome uses the
*      HR->RR transform RR = (1-0.5^sqrt(HR))/(1-0.5^sqrt(1/HR)), not the raw
*      HR. RED on HEAD, whose Cox branch set approximation "none" and treated
*      the HR as an RR with no rarity check.
* =========================================================================
local ++test_count
capture noisily {
    _p5_a12
    msm_prepare, id(id) period(period) treatment(treat) outcome(out) covariates(L) baseline_covariates(age sex)
    msm_weight, treat_d_cov(L age sex) nolog
    * Portable removal of any stale Cox sandbox maps (Q12: no Unix-only shell).
    local _stale : dir "`c(pwd)'" files "_cox_sample_map*"
    foreach _m of local _stale {
        capture erase "`c(pwd)'/`_m'"
    }
    msm_fit, model(cox) outcome_cov(age sex) nolog
    msm_sensitivity, evalue
    assert r(cumulative_incidence) > r(rare_threshold)
    assert "`r(approximation)'" == "common-outcome HR transform"
    local hr = r(effect)
    local rr = (1 - 0.5^sqrt(`hr')) / (1 - 0.5^sqrt(1/`hr'))
    if `rr' < 1 local rr = 1 / `rr'
    assert abs(r(evalue_point) - (`rr' + sqrt(`rr' * (`rr' - 1)))) < 1e-6
}
if _rc == 0 {
    display as result "PASS A13: Cox rarity gate uses the HR->RR common-outcome transform"
    local ++pass_count
}
else {
    display as error "FAIL A13: Cox HR->RR rarity gate (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' A13"
}

* =========================================================================
* A20-propagation: a weighted linear model uses t inference (with e(df_r))
* not just on the console/e(effects) but propagated to msm_sensitivity's
* effect CI. msm_fit persists char _dta[_msm_fit_inf_dist]="t" (already on
* HEAD), but the consumers still used z; asserting the t-scale CI is RED on
* HEAD (which used invnormal) and GREEN after the propagation.
* =========================================================================
capture program drop _p5_lin
program define _p5_lin
    version 16.0
    clear
    set seed 52001
    set obs 240
    gen long id = _n
    gen byte grp = mod(id, 8) + 1          // 8 clusters => e(df_r)=7
    gen double L = rnormal()
    expand 4
    bysort id: gen int period = _n - 1
    gen byte treat = runiform() < invlogit(0.3 * L)
    gen byte out = runiform() < invlogit(-2.0 + 0.5 * treat + 0.4 * L)
    bysort id (period): gen byte _po = sum(out[_n-1]) >= 1 if _n > 1
    replace _po = 0 if missing(_po)
    drop if _po > 0
    drop _po
end

local ++test_count
capture noisily {
    _p5_lin
    msm_prepare, id(id) period(period) treatment(treat) outcome(out) covariates(L)
    msm_weight, treat_d_cov(L) nolog
    msm_fit, model(linear) vce(cluster grp) nolog
    local idist : char _dta[_msm_fit_inf_dist]
    local idf   : char _dta[_msm_fit_inf_df]
    assert "`idist'" == "t"
    assert `idf' == 7
    msm_sensitivity
    local tcrit = invttail(`idf', 0.025)
    local zcrit = invnormal(0.975)
    * the linear CI must use the fit's t distribution, not z (audit A20)
    assert abs(r(effect_hi) - (r(effect) + `tcrit' * r(effect_se))) < 1e-7
    assert abs(r(effect_lo) - (r(effect) - `tcrit' * r(effect_se))) < 1e-7
    * and it is genuinely wider than the z interval (t > z for finite df)
    assert (r(effect_hi) - r(effect)) > `zcrit' * r(effect_se) + 1e-6
}
if _rc == 0 {
    display as result "PASS A20-prop: linear-model sensitivity CI uses t inference"
    local ++pass_count
}
else {
    display as error "FAIL A20-prop: t-inference propagation (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' A20-prop"
}

* =========================================================================
* A25-operational: msm_diagnose flags operational positivity near-violations on
* the estimated probability of the OBSERVED treatment (support ps_min <
* positivity()), the extreme-weight cells a marginal by-period support count
* cannot see (Cole & Hernan 2008). The positivity() option is new, so on HEAD
* the strong-association call fails with rc 198 (unknown option): RED. Paired
* with a well-overlapped positive control and a range guard.
* =========================================================================
capture program drop _p5_extreme_ps
program define _p5_extreme_ps
    version 16.0
    syntax , Assoc(real) [seed(integer 25011)]
    clear
    set seed `seed'
    set obs 800
    gen long id = _n
    gen double L = rnormal()
    expand 4
    bysort id: gen int period = _n - 1
    * assoc controls how extreme the propensity gets for extreme L
    gen byte treat = runiform() < invlogit(`assoc' * L)
    gen byte out = runiform() < invlogit(-2.5 + 0.4 * treat + 0.3 * L)
    bysort id (period): gen byte _po = sum(out[_n-1]) >= 1 if _n > 1
    replace _po = 0 if missing(_po)
    drop if _po > 0
    drop _po
end

local ++test_count
capture noisily {
    * strong treatment-covariate association => extreme propensity in some cells
    _p5_extreme_ps, assoc(3.0) seed(25011)
    msm_prepare, id(id) period(period) treatment(treat) outcome(out) covariates(L)
    msm_weight, treat_d_cov(L) nolog
    msm_diagnose, by_period positivity(0.05)
    assert r(positivity_threshold) == 0.05
    assert r(n_positivity_violations) >= 1

    * positive control: (near-)random treatment => propensity stays away from 0
    _p5_extreme_ps, assoc(0.0) seed(25012)
    msm_prepare, id(id) period(period) treatment(treat) outcome(out) covariates(L)
    msm_weight, treat_d_cov(L) nolog
    msm_diagnose, by_period positivity(0.01)
    assert r(n_positivity_violations) == 0

    * range guard: a floor outside (0, 0.5) is refused
    capture msm_diagnose, by_period positivity(0.6)
    assert _rc == 198
    capture msm_diagnose, by_period positivity(-0.1)
    assert _rc == 198
}
if _rc == 0 {
    display as result "PASS A25-op: operational positivity floor flags extreme-propensity cells"
    local ++pass_count
}
else {
    display as error "FAIL A25-op: operational positivity (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' A25-op"
}

* =========================================================================
* A31: report export contract. export() with format(display) is a silent no-op
* on HEAD (the report goes to the console, nothing is written, rc 0); it is now
* rejected (RED on HEAD). A successful Excel export must leave a nonempty
* workbook, validated before success is announced.
* =========================================================================
local ++test_count
capture noisily {
    _p5_panel
    msm_prepare, id(id) period(period) treatment(treat) outcome(out) covariates(L) baseline_covariates(age sex)
    msm_weight, treat_d_cov(L age sex) nolog
    msm_fit, model(logistic) outcome_cov(age sex) vce(cluster id) nolog

    * export() + format(display): rejected (silent no-op on HEAD returned rc 0)
    capture msm_report, format(display) export("`c(pwd)'/_a31_noop.xlsx")
    assert _rc == 198
    * positive control: format(display) with no export() still runs
    capture msm_report, format(display)
    assert _rc == 0

    * a valid excel export succeeds and leaves a nonempty, reopenable workbook
    tempfile xl
    local xlf "`xl'.xlsx"
    msm_report, format(excel) export("`xlf'")
    capture confirm file "`xlf'"
    assert _rc == 0
    quietly checksum "`xlf'"
    assert r(filelen) > 0
    capture erase "`xlf'"
}
if _rc == 0 {
    display as result "PASS A31: report export rejects display+export; validates the workbook"
    local ++pass_count
}
else {
    display as error "FAIL A31: report export contract (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' A31"
}

* -------------------------------------------------------------------------
if `fail_count' > 0 {
    display as error "Failed tests:`failed_tests'"
}
display as text "RESULT: test_msm_phase5 tests=`test_count' pass=`pass_count' fail=`fail_count'"
capture log close _all
if `fail_count' > 0 exit 1
