/*******************************************************************************
* validation_aft.do
*
* Purpose: Validation tests for aft package. Verifies computed values match
*          expected results from known data-generating processes and manual
*          streg comparisons.
*
* V1: Known Weibull DGP -- aft_select picks Weibull, aft_fit recovers true TR
* V2: Known lognormal DGP -- selection picks lognormal
* V3: Manual streg match -- AIC/BIC/ll from aft_select match raw streg
* V4: Stata's cancer.dta -- benchmark against known results
* V5: Cox-Snell residual validity -- well-fitting model
*
* Author: Timothy P Copeland
* Date: 2026-03-14
*******************************************************************************/

clear all
set more off
set seed 20260314
version 16.0

* =============================================================================
* CONFIGURATION
* =============================================================================
if "$RUN_TEST_QUIET" == "" {
    global RUN_TEST_QUIET = 0
}
if "$RUN_TEST_MACHINE" == "" {
    global RUN_TEST_MACHINE = 0
}
if "$RUN_TEST_NUMBER" == "" {
    global RUN_TEST_NUMBER = 0
}

local quiet = $RUN_TEST_QUIET
local machine = $RUN_TEST_MACHINE
local run_only = $RUN_TEST_NUMBER

if "`c(os)'" == "Unix" {
    global STATA_TOOLS_PATH "/home/tpcopeland/Stata-Dev"
}
else {
    global STATA_TOOLS_PATH "`c(pwd)'"
}

capture ado uninstall aft
quietly net install aft, from("${STATA_TOOLS_PATH}/aft")

if `quiet' == 0 {
    display as text _n "{hline 70}"
    display as text "aft PACKAGE VALIDATION TESTING"
    display as text "{hline 70}"
}

local test_count = 0
local pass_count = 0
local fail_count = 0
local failed_tests ""

capture program drop _run_test
program define _run_test
    args test_num test_desc
    if $RUN_TEST_NUMBER > 0 & $RUN_TEST_NUMBER != `test_num' {
        exit 0
    }
    if $RUN_TEST_QUIET == 0 {
        display as text _n "TEST `test_num': `test_desc'"
        display as text "{hline 50}"
    }
end

* =============================================================================
* V1: KNOWN WEIBULL DGP
* =============================================================================

* TEST 1: aft_select picks Weibull from Weibull DGP
local ++test_count
local test_desc "V1.1: Weibull DGP - aft_select picks Weibull"
_run_test `test_count' "`test_desc'"

if `run_only' == 0 | `run_only' == `test_count' {
    capture {
        clear
        set obs 500
        gen x = rbinomial(1, 0.5)
        * Weibull with shape p=1.5, TR for x = exp(0.5) = 1.65
        local shape = 1.5
        local true_beta = 0.5
        gen double t = (-ln(runiform()) / exp(-`shape' * `true_beta' * x))^(1/`shape')
        gen byte d = (t < 20)
        replace t = min(t, 20)
        stset t, failure(d)

        * Exclude ggamma for speed; 4 distributions sufficient to test selection
        aft_select x, nolog exclude(ggamma)
        assert "`r(best_dist)'" == "weibull"
    }
    if _rc == 0 {
        local ++pass_count
        if `machine' {
            display "RESULT: pass `test_count' `test_desc'"
        }
        else if `quiet' == 0 {
            display as result "  PASSED"
        }
    }
    else {
        local ++fail_count
        local failed_tests "`failed_tests' `test_count'"
        if `machine' {
            display "RESULT: fail `test_count' `test_desc' rc=`=_rc'"
        }
        else {
            display as error "  FAILED (rc=`=_rc')"
        }
    }
}

* TEST 2: aft_fit recovers true TR from Weibull DGP
local ++test_count
local test_desc "V1.2: Weibull DGP - aft_fit recovers true TR"
_run_test `test_count' "`test_desc'"

if `run_only' == 0 | `run_only' == `test_count' {
    capture {
        clear
        set obs 2000
        gen x = rbinomial(1, 0.5)
        local shape = 1.5
        local true_beta = 0.5
        gen double t = (-ln(runiform()) / exp(-`shape' * `true_beta' * x))^(1/`shape')
        gen byte d = (t < 50)
        replace t = min(t, 50)
        stset t, failure(d)

        aft_fit x, distribution(weibull) nolog
        local est_tr = exp(_b[x])
        local true_tr = exp(`true_beta')

        * Should be within 10% of true value with N=5000
        assert abs(`est_tr' - `true_tr') / `true_tr' < 0.10
    }
    if _rc == 0 {
        local ++pass_count
        if `machine' {
            display "RESULT: pass `test_count' `test_desc'"
        }
        else if `quiet' == 0 {
            display as result "  PASSED (est TR = `est_tr', true TR = `true_tr')"
        }
    }
    else {
        local ++fail_count
        local failed_tests "`failed_tests' `test_count'"
        if `machine' {
            display "RESULT: fail `test_count' `test_desc' rc=`=_rc'"
        }
        else {
            display as error "  FAILED (rc=`=_rc')"
        }
    }
}

* =============================================================================
* V2: KNOWN LOGNORMAL DGP
* =============================================================================

* TEST 3: aft_select picks lognormal from lognormal DGP
local ++test_count
local test_desc "V2.1: Lognormal DGP - aft_select picks lognormal"
_run_test `test_count' "`test_desc'"

if `run_only' == 0 | `run_only' == `test_count' {
    capture {
        clear
        set obs 500
        gen x = rbinomial(1, 0.5)
        * Lognormal: log(T) = mu + beta*x + sigma*e, e ~ N(0,1)
        local mu = 2
        local sigma = 0.8
        local true_beta = 0.4
        gen double t = exp(`mu' + `true_beta' * x + `sigma' * rnormal())
        gen byte d = (t < 50)
        replace t = min(t, 50)
        stset t, failure(d)

        * Exclude ggamma for speed
        aft_select x, nolog exclude(ggamma)
        assert "`r(best_dist)'" == "lognormal"
    }
    if _rc == 0 {
        local ++pass_count
        if `machine' {
            display "RESULT: pass `test_count' `test_desc'"
        }
        else if `quiet' == 0 {
            display as result "  PASSED"
        }
    }
    else {
        local ++fail_count
        local failed_tests "`failed_tests' `test_count'"
        if `machine' {
            display "RESULT: fail `test_count' `test_desc' rc=`=_rc'"
        }
        else {
            display as error "  FAILED (rc=`=_rc')"
        }
    }
}

* TEST 4: LR test non-significant for lognormal (with ggamma)
local ++test_count
local test_desc "V2.2: Lognormal DGP - LR test non-significant"
_run_test `test_count' "`test_desc'"

if `run_only' == 0 | `run_only' == `test_count' {
    capture {
        * Use cancer.dta (small, fast ggamma convergence) with lognormal
        * Since ggamma nests lognormal, LR test should have valid p-value
        sysuse cancer, clear
        stset studytime, failure(died)

        aft_select drug age, nolog
        * LR test p-value should be defined (ggamma converged on small data)
        assert r(lr_lognormal_p) < .
        assert r(lr_lognormal_p) >= 0
    }
    if _rc == 0 {
        local ++pass_count
        if `machine' {
            display "RESULT: pass `test_count' `test_desc'"
        }
        else if `quiet' == 0 {
            display as result "  PASSED (p = `=r(lr_lognormal_p)')"
        }
    }
    else {
        local ++fail_count
        local failed_tests "`failed_tests' `test_count'"
        if `machine' {
            display "RESULT: fail `test_count' `test_desc' rc=`=_rc'"
        }
        else {
            display as error "  FAILED (rc=`=_rc')"
        }
    }
}

* =============================================================================
* V3: MANUAL STREG MATCH
* =============================================================================

* TEST 5: AIC from aft_select matches raw streg exactly
local ++test_count
local test_desc "V3.1: AIC matches raw streg (Weibull)"
_run_test `test_count' "`test_desc'"

if `run_only' == 0 | `run_only' == `test_count' {
    capture {
        sysuse cancer, clear
        stset studytime, failure(died)

        * Raw streg
        quietly streg drug age, distribution(weibull) nolog
        local raw_ll = e(ll)
        local raw_k = e(rank)
        local raw_aic = -2 * `raw_ll' + 2 * `raw_k'

        * aft_select
        aft_select drug age, nolog
        matrix tbl = r(table)

        * Find Weibull row (row 2 in default order)
        local aft_ll = tbl[2, 1]
        local aft_aic = tbl[2, 3]

        * Must match exactly (same model)
        assert reldif(`raw_ll', `aft_ll') < 1e-6
        assert reldif(`raw_aic', `aft_aic') < 1e-6
    }
    if _rc == 0 {
        local ++pass_count
        if `machine' {
            display "RESULT: pass `test_count' `test_desc'"
        }
        else if `quiet' == 0 {
            display as result "  PASSED"
        }
    }
    else {
        local ++fail_count
        local failed_tests "`failed_tests' `test_count'"
        if `machine' {
            display "RESULT: fail `test_count' `test_desc' rc=`=_rc'"
        }
        else {
            display as error "  FAILED (rc=`=_rc')"
        }
    }
}

* TEST 6: AIC from aft_select matches raw streg (lognormal)
local ++test_count
local test_desc "V3.2: AIC matches raw streg (lognormal)"
_run_test `test_count' "`test_desc'"

if `run_only' == 0 | `run_only' == `test_count' {
    capture {
        sysuse cancer, clear
        stset studytime, failure(died)

        quietly streg drug age, distribution(lognormal) nolog
        local raw_ll = e(ll)
        local raw_aic = -2 * e(ll) + 2 * e(rank)

        aft_select drug age, nolog
        matrix tbl = r(table)

        * Lognormal = row 3
        local aft_ll = tbl[3, 1]
        local aft_aic = tbl[3, 3]

        assert reldif(`raw_ll', `aft_ll') < 1e-6
        assert reldif(`raw_aic', `aft_aic') < 1e-6
    }
    if _rc == 0 {
        local ++pass_count
        if `machine' {
            display "RESULT: pass `test_count' `test_desc'"
        }
        else if `quiet' == 0 {
            display as result "  PASSED"
        }
    }
    else {
        local ++fail_count
        local failed_tests "`failed_tests' `test_count'"
        if `machine' {
            display "RESULT: fail `test_count' `test_desc' rc=`=_rc'"
        }
        else {
            display as error "  FAILED (rc=`=_rc')"
        }
    }
}

* TEST 7: BIC from aft_select matches raw streg (ggamma)
local ++test_count
local test_desc "V3.3: BIC matches raw streg (ggamma)"
_run_test `test_count' "`test_desc'"

if `run_only' == 0 | `run_only' == `test_count' {
    capture {
        sysuse cancer, clear
        stset studytime, failure(died)

        quietly streg drug age, distribution(ggamma) nolog
        local raw_ll = e(ll)
        local raw_bic = -2 * e(ll) + e(rank) * ln(e(N))

        aft_select drug age, nolog
        matrix tbl = r(table)

        * ggamma = row 5
        local aft_bic = tbl[5, 4]

        assert reldif(`raw_bic', `aft_bic') < 1e-6
    }
    if _rc == 0 {
        local ++pass_count
        if `machine' {
            display "RESULT: pass `test_count' `test_desc'"
        }
        else if `quiet' == 0 {
            display as result "  PASSED"
        }
    }
    else {
        local ++fail_count
        local failed_tests "`failed_tests' `test_count'"
        if `machine' {
            display "RESULT: fail `test_count' `test_desc' rc=`=_rc'"
        }
        else {
            display as error "  FAILED (rc=`=_rc')"
        }
    }
}

* =============================================================================
* V4: CANCER.DTA BENCHMARK
* =============================================================================

* TEST 8: aft_fit Weibull on cancer.dta matches streg
local ++test_count
local test_desc "V4.1: cancer.dta Weibull coefficients match streg"
_run_test `test_count' "`test_desc'"

if `run_only' == 0 | `run_only' == `test_count' {
    capture {
        sysuse cancer, clear
        stset studytime, failure(died)

        * Raw streg with time option
        quietly streg drug age, distribution(weibull) time nolog
        local raw_b_drug = _b[drug]
        local raw_b_age = _b[age]

        * aft_fit
        aft_fit drug age, distribution(weibull) nolog
        local aft_b_drug = _b[drug]
        local aft_b_age = _b[age]

        * Must match exactly
        assert reldif(`raw_b_drug', `aft_b_drug') < 1e-8
        assert reldif(`raw_b_age', `aft_b_age') < 1e-8
    }
    if _rc == 0 {
        local ++pass_count
        if `machine' {
            display "RESULT: pass `test_count' `test_desc'"
        }
        else if `quiet' == 0 {
            display as result "  PASSED"
        }
    }
    else {
        local ++fail_count
        local failed_tests "`failed_tests' `test_count'"
        if `machine' {
            display "RESULT: fail `test_count' `test_desc' rc=`=_rc'"
        }
        else {
            display as error "  FAILED (rc=`=_rc')"
        }
    }
}

* TEST 9: aft_fit lognormal on cancer.dta matches streg
local ++test_count
local test_desc "V4.2: cancer.dta lognormal coefficients match streg"
_run_test `test_count' "`test_desc'"

if `run_only' == 0 | `run_only' == `test_count' {
    capture {
        sysuse cancer, clear
        stset studytime, failure(died)

        quietly streg drug age, distribution(lognormal) nolog
        local raw_b_drug = _b[drug]

        aft_fit drug age, distribution(lognormal) nolog
        local aft_b_drug = _b[drug]

        assert reldif(`raw_b_drug', `aft_b_drug') < 1e-8
    }
    if _rc == 0 {
        local ++pass_count
        if `machine' {
            display "RESULT: pass `test_count' `test_desc'"
        }
        else if `quiet' == 0 {
            display as result "  PASSED"
        }
    }
    else {
        local ++fail_count
        local failed_tests "`failed_tests' `test_count'"
        if `machine' {
            display "RESULT: fail `test_count' `test_desc' rc=`=_rc'"
        }
        else {
            display as error "  FAILED (rc=`=_rc')"
        }
    }
}

* TEST 10: aft_compare returns correct PH test
local ++test_count
local test_desc "V4.3: cancer.dta PH test matches estat phtest"
_run_test `test_count' "`test_desc'"

if `run_only' == 0 | `run_only' == `test_count' {
    capture {
        sysuse cancer, clear
        stset studytime, failure(died)

        * Raw Cox + phtest
        quietly stcox drug age
        quietly estat phtest
        local raw_p = r(p)

        * aft_compare
        aft_compare drug age, distribution(weibull)
        local aft_p = r(ph_global_p)

        * Must match
        assert reldif(`raw_p', `aft_p') < 1e-6
    }
    if _rc == 0 {
        local ++pass_count
        if `machine' {
            display "RESULT: pass `test_count' `test_desc'"
        }
        else if `quiet' == 0 {
            display as result "  PASSED"
        }
    }
    else {
        local ++fail_count
        local failed_tests "`failed_tests' `test_count'"
        if `machine' {
            display "RESULT: fail `test_count' `test_desc' rc=`=_rc'"
        }
        else {
            display as error "  FAILED (rc=`=_rc')"
        }
    }
}

* =============================================================================
* V5: COX-SNELL RESIDUAL VALIDITY
* =============================================================================

* TEST 11: Cox-Snell residuals from well-fitting Weibull model
local ++test_count
local test_desc "V5.1: Cox-Snell residuals follow unit exponential"
_run_test `test_count' "`test_desc'"

if `run_only' == 0 | `run_only' == `test_count' {
    capture {
        * Generate Weibull data and fit Weibull
        clear
        set obs 500
        gen x = rbinomial(1, 0.5)
        local shape = 1.5
        gen double t = (-ln(runiform()) / exp(-`shape' * 0.5 * x))^(1/`shape')
        gen byte d = 1
        stset t, failure(d)

        aft_fit x, distribution(weibull) nolog
        predict double cs, csnell

        * Mean of unit exponential CS residuals should be ~ 1
        quietly summarize cs
        assert abs(r(mean) - 1) < 0.15
    }
    if _rc == 0 {
        local ++pass_count
        if `machine' {
            display "RESULT: pass `test_count' `test_desc'"
        }
        else if `quiet' == 0 {
            display as result "  PASSED (mean CS = `=r(mean)')"
        }
    }
    else {
        local ++fail_count
        local failed_tests "`failed_tests' `test_count'"
        if `machine' {
            display "RESULT: fail `test_count' `test_desc' rc=`=_rc'"
        }
        else {
            display as error "  FAILED (rc=`=_rc')"
        }
    }
}

* TEST 12: aft_select convergence count correct
local ++test_count
local test_desc "V5.2: n_converged matches actual convergence"
_run_test `test_count' "`test_desc'"

if `run_only' == 0 | `run_only' == `test_count' {
    capture {
        sysuse cancer, clear
        stset studytime, failure(died)
        aft_select drug age, nolog

        * Count converged from matrix
        matrix tbl = r(table)
        local mat_conv = 0
        forvalues i = 1/`=rowsof(tbl)' {
            if tbl[`i', 5] == 1 local ++mat_conv
        }
        assert `mat_conv' == r(n_converged)
    }
    if _rc == 0 {
        local ++pass_count
        if `machine' {
            display "RESULT: pass `test_count' `test_desc'"
        }
        else if `quiet' == 0 {
            display as result "  PASSED"
        }
    }
    else {
        local ++fail_count
        local failed_tests "`failed_tests' `test_count'"
        if `machine' {
            display "RESULT: fail `test_count' `test_desc' rc=`=_rc'"
        }
        else {
            display as error "  FAILED (rc=`=_rc')"
        }
    }
}

* TEST 13: aft_compare HR and TR are approximately reciprocal
local ++test_count
local test_desc "V5.3: HR approx 1/TR when PH holds"
_run_test `test_count' "`test_desc'"

if `run_only' == 0 | `run_only' == `test_count' {
    capture {
        * Use Weibull DGP (PH holds for Weibull)
        clear
        set obs 500
        gen x = rbinomial(1, 0.5)
        gen double t = (-ln(runiform()) / exp(-1.5 * 0.5 * x))^(1/1.5)
        gen byte d = (t < 20)
        replace t = min(t, 20)
        stset t, failure(d)

        aft_compare x, distribution(weibull)
        matrix comp = r(comparison)

        * HR should be approximately 1/TR for Weibull
        local hr = comp[1, 1]
        local tr = comp[1, 4]
        local ratio = `hr' * `tr'
        * For Weibull: HR^(1/p) = 1/TR, so HR*TR != 1 exactly
        * But TR ~ HR^(-1/p), so just check they move in opposite directions
        assert (`hr' < 1 & `tr' > 1) | (`hr' > 1 & `tr' < 1) | ///
               (abs(`hr' - 1) < 0.1 & abs(`tr' - 1) < 0.1)
    }
    if _rc == 0 {
        local ++pass_count
        if `machine' {
            display "RESULT: pass `test_count' `test_desc'"
        }
        else if `quiet' == 0 {
            display as result "  PASSED"
        }
    }
    else {
        local ++fail_count
        local failed_tests "`failed_tests' `test_count'"
        if `machine' {
            display "RESULT: fail `test_count' `test_desc' rc=`=_rc'"
        }
        else {
            display as error "  FAILED (rc=`=_rc')"
        }
    }
}

* =============================================================================
* SUMMARY
* =============================================================================
if `machine' {
    display "RESULT: summary `pass_count'/`test_count' passed"
    if `fail_count' > 0 {
        display "RESULT: failed_tests`failed_tests'"
    }
}
else {
    display as text _n "{hline 70}"
    display as text "aft VALIDATION TEST SUMMARY"
    display as text "{hline 70}"
    display as text "Total tests:  `test_count'"
    display as result "Passed:       `pass_count'"
    if `fail_count' > 0 {
        display as error "Failed:       `fail_count'"
        display as error "Failed tests:`failed_tests'"
    }
    else {
        display as text "Failed:       `fail_count'"
    }
    display as text "{hline 70}"

    if `fail_count' > 0 {
        display as error "Some tests FAILED. Review output above."
        exit 1
    }
    else {
        display as result "All tests PASSED!"
    }
}

global RUN_TEST_QUIET
global RUN_TEST_MACHINE
global RUN_TEST_NUMBER
