* test_msm_diagnostics_output_regressions.do
* Diagnostics regressions.
*
* Findings covered (audit 2026-07-12):
*   A26  SMD threshold must be finite/nonnegative; a missing weighted SMD is
*        UNAVAILABLE, not imbalanced; percent change is missing (not 0) when the
*        unweighted SMD denominator is ~0
*   A25-op  the operational positivity floor on the observed decision
* The sensitivity (A12, A13, A20-prop, A28, A29) and report/export (A30, A31)
* findings were retired in msm 2.0.0 with msm_sensitivity and msm_report.
*
* Every refusal test is paired with a positive control. Reference:
* rc198_error_test_needs_positive_control.

version 16.0
clear all
set more off
set varabbrev off

capture log close _all
log using "test_msm_diagnostics_output_regressions.log", replace text nomsg

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
    assert !missing(r(n_unavailable))
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
    msm_diagnose, positivity(0.05)
    assert r(positivity_threshold) == 0.05
    assert !missing(r(n_positivity_violations))
    assert r(n_positivity_violations) >= 1

    * positive control: (near-)random treatment => propensity stays away from 0
    _p5_extreme_ps, assoc(0.0) seed(25012)
    msm_prepare, id(id) period(period) treatment(treat) outcome(out) covariates(L)
    msm_weight, treat_d_cov(L) nolog
    msm_diagnose, positivity(0.01)
    assert r(n_positivity_violations) == 0

    * range guard: a floor outside (0, 0.5) is refused
    capture msm_diagnose, positivity(0.6)
    assert _rc == 198
    capture msm_diagnose, positivity(-0.1)
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


* -------------------------------------------------------------------------
if `fail_count' > 0 {
    display as error "Failed tests:`failed_tests'"
}
do "`qa_dir'/_record_qa_result.do" test_msm_diagnostics_output_regressions ///
    `test_count' `pass_count' `fail_count' 0
display as text "RESULT: test_msm_diagnostics_output_regressions tests=`test_count' pass=`pass_count' fail=`fail_count' skip=0"
capture log close _all
if `fail_count' > 0 exit 1
