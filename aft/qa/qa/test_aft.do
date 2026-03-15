/*******************************************************************************
* test_aft.do
*
* Purpose: Functional tests for aft package -- verifies all commands run
*          without errors across various scenarios and options.
*
* Commands tested: aft, aft_select, aft_fit, aft_diagnose, aft_compare,
*                  aft_split, aft_pool, aft_rpsftm, aft_counterfactual
*
* Author: Timothy P Copeland
* Date: 2026-03-14
*******************************************************************************/

clear all
set more off
set seed 12345
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

* Path config
if "`c(os)'" == "Unix" {
    global STATA_TOOLS_PATH "/home/tpcopeland/Stata-Dev"
}
else {
    global STATA_TOOLS_PATH "`c(pwd)'"
}

* Install package
capture ado uninstall aft
quietly net install aft, from("${STATA_TOOLS_PATH}/aft")

* =============================================================================
* HEADER
* =============================================================================
if `quiet' == 0 {
    display as text _n "{hline 70}"
    display as text "aft PACKAGE FUNCTIONAL TESTING"
    display as text "{hline 70}"
}

* =============================================================================
* TEST COUNTERS
* =============================================================================
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
* TEST 1: Router displays version and commands
* =============================================================================
local ++test_count
local test_desc "aft router displays version and commands"
_run_test `test_count' "`test_desc'"

if `run_only' == 0 | `run_only' == `test_count' {
    capture {
        aft
        assert "`r(version)'" == "1.1.0"
        assert r(n_commands) == 8
        assert "`r(commands)'" != ""
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
* TEST 2: Router list and detail options
* =============================================================================
local ++test_count
local test_desc "aft router list and detail options"
_run_test `test_count' "`test_desc'"

if `run_only' == 0 | `run_only' == `test_count' {
    capture {
        aft, list
        aft, detail
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
* TEST 3: aft_select with all 5 distributions
* =============================================================================
local ++test_count
local test_desc "aft_select fits all 5 distributions"
_run_test `test_count' "`test_desc'"

if `run_only' == 0 | `run_only' == `test_count' {
    capture {
        sysuse cancer, clear
        stset studytime, failure(died)
        aft_select drug age, nolog
        assert "`r(best_dist)'" != ""
        assert r(n_converged) > 0
        assert r(n_dists) == 5
        assert r(best_aic) < .
        assert r(N) > 0
        assert r(n_fail) > 0

        * Check characteristics stored
        local sel : char _dta[_aft_selected]
        assert "`sel'" == "1"
        local bd : char _dta[_aft_best_dist]
        assert "`bd'" != ""
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
* TEST 4: aft_select LR tests returned
* =============================================================================
local ++test_count
local test_desc "aft_select returns LR test p-values"
_run_test `test_count' "`test_desc'"

if `run_only' == 0 | `run_only' == `test_count' {
    capture {
        sysuse cancer, clear
        stset studytime, failure(died)
        aft_select drug age, nolog

        * LR tests should be populated if ggamma converged
        local conv_gg : char _dta[_aft_conv_ggamma]
        if "`conv_gg'" == "1" {
            assert r(lr_weibull_p) < .
            assert r(lr_lognormal_p) < .
            assert r(lr_exponential_p) < .
        }
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
* TEST 5: aft_select with distribution subset
* =============================================================================
local ++test_count
local test_desc "aft_select with subset of distributions"
_run_test `test_count' "`test_desc'"

if `run_only' == 0 | `run_only' == `test_count' {
    capture {
        sysuse cancer, clear
        stset studytime, failure(died)
        aft_select drug age, distributions(weibull lognormal) nolog
        assert r(n_dists) == 2
        assert inlist("`r(best_dist)'", "weibull", "lognormal")
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
* TEST 6: aft_select with exclude
* =============================================================================
local ++test_count
local test_desc "aft_select with exclude option"
_run_test `test_count' "`test_desc'"

if `run_only' == 0 | `run_only' == `test_count' {
    capture {
        sysuse cancer, clear
        stset studytime, failure(died)
        aft_select drug age, exclude(ggamma) nolog
        assert r(n_dists) == 4
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
* TEST 7: aft_select with notable and norecommend
* =============================================================================
local ++test_count
local test_desc "aft_select notable and norecommend"
_run_test `test_count' "`test_desc'"

if `run_only' == 0 | `run_only' == `test_count' {
    capture {
        sysuse cancer, clear
        stset studytime, failure(died)
        aft_select drug age, nolog notable norecommend
        assert "`r(best_dist)'" != ""
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
* TEST 8: aft_select without covariates (null model)
* =============================================================================
local ++test_count
local test_desc "aft_select null model (no covariates)"
_run_test `test_count' "`test_desc'"

if `run_only' == 0 | `run_only' == `test_count' {
    capture {
        sysuse cancer, clear
        stset studytime, failure(died)
        aft_select, nolog
        assert r(n_converged) > 0
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
* TEST 9: aft_select error on non-stset data
* =============================================================================
local ++test_count
local test_desc "aft_select errors on non-stset data"
_run_test `test_count' "`test_desc'"

if `run_only' == 0 | `run_only' == `test_count' {
    capture {
        sysuse auto, clear
        capture aft_select price mpg
        assert _rc != 0
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
* TEST 10: aft_fit reads from aft_select
* =============================================================================
local ++test_count
local test_desc "aft_fit reads distribution from aft_select"
_run_test `test_count' "`test_desc'"

if `run_only' == 0 | `run_only' == `test_count' {
    capture {
        sysuse cancer, clear
        stset studytime, failure(died)
        aft_select drug age, nolog
        local sel_dist = r(best_dist)
        aft_fit drug age, nolog

        * Check eclass results
        assert "`e(aft_cmd)'" == "aft_fit"
        assert "`e(aft_dist)'" == "`sel_dist'"

        * Check characteristics
        local fitted : char _dta[_aft_fitted]
        assert "`fitted'" == "1"
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
* TEST 11: aft_fit with manual distribution
* =============================================================================
local ++test_count
local test_desc "aft_fit with manual distribution override"
_run_test `test_count' "`test_desc'"

if `run_only' == 0 | `run_only' == `test_count' {
    capture {
        sysuse cancer, clear
        stset studytime, failure(died)
        aft_fit drug age, distribution(weibull) nolog
        assert "`e(aft_dist)'" == "weibull"
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
* TEST 12: aft_fit each distribution
* =============================================================================
local ++test_count
local test_desc "aft_fit runs for each distribution"
_run_test `test_count' "`test_desc'"

if `run_only' == 0 | `run_only' == `test_count' {
    capture {
        foreach dist in exponential weibull lognormal loglogistic ggamma {
            sysuse cancer, clear
            stset studytime, failure(died)
            aft_fit drug age, distribution(`dist') nolog
            assert "`e(aft_dist)'" == "`dist'"
        }
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
* TEST 13: aft_fit notratio option
* =============================================================================
local ++test_count
local test_desc "aft_fit notratio displays coefficients"
_run_test `test_count' "`test_desc'"

if `run_only' == 0 | `run_only' == `test_count' {
    capture {
        sysuse cancer, clear
        stset studytime, failure(died)
        aft_fit drug age, distribution(weibull) nolog notratio
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
* TEST 14: aft_fit error without distribution
* =============================================================================
local ++test_count
local test_desc "aft_fit errors without distribution"
_run_test `test_count' "`test_desc'"

if `run_only' == 0 | `run_only' == `test_count' {
    capture {
        sysuse cancer, clear
        stset studytime, failure(died)

        * Clear any prior characteristics
        char _dta[_aft_best_dist]

        capture aft_fit drug age
        assert _rc != 0
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
* TEST 15: aft_diagnose GOF stats
* =============================================================================
local ++test_count
local test_desc "aft_diagnose gofstat"
_run_test `test_count' "`test_desc'"

if `run_only' == 0 | `run_only' == `test_count' {
    capture {
        sysuse cancer, clear
        stset studytime, failure(died)
        aft_fit drug age, distribution(weibull) nolog
        aft_diagnose, gofstat

        assert r(aic) < .
        assert r(bic) < .
        assert r(ll) < .
        assert r(k) > 0
        assert r(N) > 0
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
* TEST 16: aft_diagnose Cox-Snell residuals
* =============================================================================
local ++test_count
local test_desc "aft_diagnose coxsnell plot"
_run_test `test_count' "`test_desc'"

if `run_only' == 0 | `run_only' == `test_count' {
    capture {
        sysuse cancer, clear
        stset studytime, failure(died)
        aft_fit drug age, distribution(weibull) nolog
        aft_diagnose, coxsnell
        graph close _all
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
* TEST 17: aft_diagnose Q-Q plot
* =============================================================================
local ++test_count
local test_desc "aft_diagnose qqplot"
_run_test `test_count' "`test_desc'"

if `run_only' == 0 | `run_only' == `test_count' {
    capture {
        sysuse cancer, clear
        stset studytime, failure(died)
        aft_fit drug age, distribution(lognormal) nolog
        aft_diagnose, qqplot
        graph close _all
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
* TEST 18: aft_diagnose distribution-specific plots
* =============================================================================
local ++test_count
local test_desc "aft_diagnose distplot for each distribution"
_run_test `test_count' "`test_desc'"

if `run_only' == 0 | `run_only' == `test_count' {
    capture {
        foreach dist in weibull lognormal loglogistic exponential {
            sysuse cancer, clear
            stset studytime, failure(died)
            aft_fit drug age, distribution(`dist') nolog
            aft_diagnose, distplot
            graph close _all
        }
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
* TEST 19: aft_diagnose all option
* =============================================================================
local ++test_count
local test_desc "aft_diagnose all diagnostics"
_run_test `test_count' "`test_desc'"

if `run_only' == 0 | `run_only' == `test_count' {
    capture {
        sysuse cancer, clear
        stset studytime, failure(died)
        aft_fit drug age, distribution(weibull) nolog
        aft_diagnose, all
        graph close _all
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
* TEST 20: aft_diagnose error without aft_fit
* =============================================================================
local ++test_count
local test_desc "aft_diagnose errors without aft_fit"
_run_test `test_count' "`test_desc'"

if `run_only' == 0 | `run_only' == `test_count' {
    capture {
        sysuse cancer, clear
        stset studytime, failure(died)
        char _dta[_aft_fitted]
        capture aft_diagnose
        assert _rc != 0
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
* TEST 21: aft_compare with Weibull
* =============================================================================
local ++test_count
local test_desc "aft_compare Cox vs Weibull AFT"
_run_test `test_count' "`test_desc'"

if `run_only' == 0 | `run_only' == `test_count' {
    capture {
        sysuse cancer, clear
        stset studytime, failure(died)
        aft_compare drug age, distribution(weibull)
        assert r(ph_global_p) < .
        assert r(cox_aic) < .
        assert r(aft_aic) < .
        assert r(N) > 0
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
* TEST 22: aft_compare returns comparison matrix
* =============================================================================
local ++test_count
local test_desc "aft_compare returns comparison matrix"
_run_test `test_count' "`test_desc'"

if `run_only' == 0 | `run_only' == `test_count' {
    capture {
        sysuse cancer, clear
        stset studytime, failure(died)
        aft_compare drug age, distribution(lognormal)
        matrix comp = r(comparison)
        assert rowsof(comp) == 2
        assert colsof(comp) == 6
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
* TEST 23: aft_compare noschoenfeld
* =============================================================================
local ++test_count
local test_desc "aft_compare noschoenfeld option"
_run_test `test_count' "`test_desc'"

if `run_only' == 0 | `run_only' == `test_count' {
    capture {
        sysuse cancer, clear
        stset studytime, failure(died)
        aft_compare drug age, distribution(weibull) noschoenfeld
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
* TEST 24: aft_compare reads from aft_select
* =============================================================================
local ++test_count
local test_desc "aft_compare reads distribution from characteristics"
_run_test `test_count' "`test_desc'"

if `run_only' == 0 | `run_only' == `test_count' {
    capture {
        sysuse cancer, clear
        stset studytime, failure(died)
        aft_select drug age, nolog
        aft_compare drug age
        assert "`r(dist)'" != ""
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
* TEST 25: Full pipeline
* =============================================================================
local ++test_count
local test_desc "Full pipeline: select -> fit -> diagnose -> compare"
_run_test `test_count' "`test_desc'"

if `run_only' == 0 | `run_only' == `test_count' {
    capture {
        sysuse cancer, clear
        stset studytime, failure(died)

        aft_select drug age, nolog
        aft_fit drug age, nolog
        aft_diagnose, gofstat
        aft_compare drug age
        graph close _all
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
* TEST 26: aft_select with if condition
* =============================================================================
local ++test_count
local test_desc "aft_select with if condition"
_run_test `test_count' "`test_desc'"

if `run_only' == 0 | `run_only' == `test_count' {
    capture {
        sysuse cancer, clear
        stset studytime, failure(died)
        aft_select age if drug == 1, nolog
        assert r(N) < 48
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
* TEST 27: aft_select result matrix dimensions
* =============================================================================
local ++test_count
local test_desc "aft_select result matrix has correct dimensions"
_run_test `test_count' "`test_desc'"

if `run_only' == 0 | `run_only' == `test_count' {
    capture {
        sysuse cancer, clear
        stset studytime, failure(died)
        aft_select drug age, nolog
        matrix tbl = r(table)
        assert rowsof(tbl) == 5
        assert colsof(tbl) == 5
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
* TIER 2: PIECEWISE AFT TESTS
* =============================================================================

* =============================================================================
* TEST 28: aft_split basic cutpoints
* =============================================================================
local ++test_count
local test_desc "aft_split with fixed cutpoints"
_run_test `test_count' "`test_desc'"

if `run_only' == 0 | `run_only' == `test_count' {
    capture {
        sysuse cancer, clear
        stset studytime, failure(died)
        aft_split drug age, cutpoints(15) distribution(weibull) nolog
        assert r(n_pieces) == 2
        assert r(n_converged) > 0
        assert "`r(dist)'" == "weibull"
        assert "`r(cutpoints)'" == "15"

        * Check characteristics stored
        local pw : char _dta[_aft_piecewise]
        assert "`pw'" == "1"

        * Check matrices returned
        matrix c = r(coefs)
        assert rowsof(c) == 2
        assert colsof(c) == 2
        matrix t = r(table)
        assert rowsof(t) == 2
        assert colsof(t) == 5
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
* TEST 29: aft_split with quantiles
* =============================================================================
local ++test_count
local test_desc "aft_split with quantile-based splitting"
_run_test `test_count' "`test_desc'"

if `run_only' == 0 | `run_only' == `test_count' {
    capture {
        sysuse cancer, clear
        stset studytime, failure(died)
        aft_split drug age, quantiles(2) distribution(weibull) nolog
        assert r(n_pieces) == 2
        assert "`r(cutpoints)'" != ""
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
* TEST 30: aft_split reads distribution from characteristics
* =============================================================================
local ++test_count
local test_desc "aft_split reads distribution from aft_select"
_run_test `test_count' "`test_desc'"

if `run_only' == 0 | `run_only' == `test_count' {
    capture {
        sysuse cancer, clear
        stset studytime, failure(died)
        aft_select drug age, nolog
        local sel_dist = r(best_dist)
        aft_split drug age, cutpoints(15) nolog
        assert "`r(dist)'" == "`sel_dist'"
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
* TEST 31: aft_split error without cutpoints or quantiles
* =============================================================================
local ++test_count
local test_desc "aft_split errors without cutpoints or quantiles"
_run_test `test_count' "`test_desc'"

if `run_only' == 0 | `run_only' == `test_count' {
    capture {
        sysuse cancer, clear
        stset studytime, failure(died)
        capture aft_split drug age, distribution(weibull)
        assert _rc == 198
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
* TEST 32: aft_split error with both cutpoints and quantiles
* =============================================================================
local ++test_count
local test_desc "aft_split errors with both cutpoints and quantiles"
_run_test `test_count' "`test_desc'"

if `run_only' == 0 | `run_only' == `test_count' {
    capture {
        sysuse cancer, clear
        stset studytime, failure(died)
        capture aft_split drug age, cutpoints(10) quantiles(3) distribution(weibull)
        assert _rc == 198
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
* TEST 33: aft_split notable option
* =============================================================================
local ++test_count
local test_desc "aft_split notable option suppresses table"
_run_test `test_count' "`test_desc'"

if `run_only' == 0 | `run_only' == `test_count' {
    capture {
        sysuse cancer, clear
        stset studytime, failure(died)
        aft_split drug age, cutpoints(15) distribution(weibull) nolog notable
        assert r(n_pieces) == 2
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
* TEST 34: aft_split data preservation
* =============================================================================
local ++test_count
local test_desc "aft_split preserves original data"
_run_test `test_count' "`test_desc'"

if `run_only' == 0 | `run_only' == `test_count' {
    capture {
        sysuse cancer, clear
        stset studytime, failure(died)
        local N_before = _N
        aft_split drug age, cutpoints(15) distribution(lognormal) nolog notable
        assert _N == `N_before'

        * Verify _aft_interval does NOT exist (restore cleaned it)
        capture confirm variable _aft_interval
        assert _rc != 0
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
* TEST 35: aft_split with each distribution
* =============================================================================
local ++test_count
local test_desc "aft_split runs with each distribution"
_run_test `test_count' "`test_desc'"

if `run_only' == 0 | `run_only' == `test_count' {
    capture {
        foreach dist in exponential weibull lognormal loglogistic ggamma {
            sysuse cancer, clear
            stset studytime, failure(died)
            aft_split drug age, cutpoints(15) distribution(`dist') nolog notable
            assert "`r(dist)'" == "`dist'"
        }
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
* TEST 36: aft_pool basic fixed-effect pooling
* =============================================================================
local ++test_count
local test_desc "aft_pool fixed-effect pooling"
_run_test `test_count' "`test_desc'"

if `run_only' == 0 | `run_only' == `test_count' {
    capture {
        sysuse cancer, clear
        stset studytime, failure(died)
        aft_split drug age, cutpoints(15) distribution(lognormal) nolog notable
        aft_pool
        assert "`r(method)'" == "fixed"
        assert r(n_pieces) == 2

        * Check pooled matrix
        matrix p = r(pooled)
        assert rowsof(p) == 2
        assert colsof(p) == 5

        * Check heterogeneity matrix
        matrix h = r(heterogeneity)
        assert rowsof(h) == 2
        assert colsof(h) == 3
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
* TEST 37: aft_pool random-effects pooling
* =============================================================================
local ++test_count
local test_desc "aft_pool random-effects (DerSimonian-Laird)"
_run_test `test_count' "`test_desc'"

if `run_only' == 0 | `run_only' == `test_count' {
    capture {
        sysuse cancer, clear
        stset studytime, failure(died)
        aft_split drug age, cutpoints(15) distribution(lognormal) nolog notable
        aft_pool, method(random)
        assert "`r(method)'" == "random"

        * Pooled TR should be positive
        matrix p = r(pooled)
        assert p[1,1] > 0
        assert p[1,3] > 0
        assert p[1,4] > p[1,3]
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
* TEST 38: aft_pool error without aft_split
* =============================================================================
local ++test_count
local test_desc "aft_pool errors without aft_split"
_run_test `test_count' "`test_desc'"

if `run_only' == 0 | `run_only' == `test_count' {
    capture {
        sysuse cancer, clear
        stset studytime, failure(died)
        char _dta[_aft_piecewise]
        capture aft_pool
        assert _rc == 198
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
* TEST 39: aft_pool notable option
* =============================================================================
local ++test_count
local test_desc "aft_pool notable option"
_run_test `test_count' "`test_desc'"

if `run_only' == 0 | `run_only' == `test_count' {
    capture {
        sysuse cancer, clear
        stset studytime, failure(died)
        aft_split drug age, cutpoints(15) distribution(weibull) nolog notable
        aft_pool, notable
        assert "`r(method)'" == "fixed"
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
* TEST 40: aft_pool invalid method errors
* =============================================================================
local ++test_count
local test_desc "aft_pool invalid method errors"
_run_test `test_count' "`test_desc'"

if `run_only' == 0 | `run_only' == `test_count' {
    capture {
        sysuse cancer, clear
        stset studytime, failure(died)
        aft_split drug age, cutpoints(15) distribution(weibull) nolog notable
        capture aft_pool, method(bayesian)
        assert _rc == 198
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
* TEST 41: Piecewise pipeline: select -> split -> pool
* =============================================================================
local ++test_count
local test_desc "Piecewise pipeline: select -> split -> pool"
_run_test `test_count' "`test_desc'"

if `run_only' == 0 | `run_only' == `test_count' {
    capture {
        sysuse cancer, clear
        stset studytime, failure(died)
        aft_select drug age, nolog
        aft_split drug age, cutpoints(15) nolog
        aft_pool, method(random)
        graph close _all

        * Verify heterogeneity stats are valid
        matrix h = r(heterogeneity)
        assert h[1,1] >= 0
        assert h[1,2] >= 0 & h[1,2] <= 1
        assert h[1,3] >= 0 & h[1,3] <= 100
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
* TIER 3: RPSFTM TESTS
* =============================================================================

* =============================================================================
* TEST 42: aft_rpsftm basic estimation
* =============================================================================
local ++test_count
local test_desc "aft_rpsftm basic grid search estimation"
_run_test `test_count' "`test_desc'"

if `run_only' == 0 | `run_only' == `test_count' {
    capture {
        * Simulate RCT with treatment switching
        clear
        set seed 20260315
        set obs 200

        * Randomization arm
        gen byte arm = (_n > 100)

        * True psi = 0.5 (treatment extends survival by exp(0.5) = 1.65x)
        * Treatment: all in arm=1 get it; 30% of arm=0 switch
        gen byte treated = arm
        replace treated = 1 if arm == 0 & runiform() < 0.3

        * Generate survival times
        gen double t_latent = -ln(runiform()) * exp(0.5 * treated)
        gen double censor = runiformint(3, 10)
        gen double os_time = min(t_latent, censor)
        gen byte os_event = (t_latent <= censor)

        stset os_time, failure(os_event)

        aft_rpsftm, randomization(arm) treatment(treated) ///
            gridrange(-1 2) gridpoints(100) nolog

        * Should find a psi estimate
        assert e(psi) < .
        assert e(af) > 0
        assert e(N) == 200
        assert e(n_events) > 0
        assert "`e(cmd)'" == "aft_rpsftm"

        * Check characteristics
        local rp : char _dta[_aft_rpsftm]
        assert "`rp'" == "1"
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
* TEST 43: aft_rpsftm with re-censoring
* =============================================================================
local ++test_count
local test_desc "aft_rpsftm with recensor option"
_run_test `test_count' "`test_desc'"

if `run_only' == 0 | `run_only' == `test_count' {
    capture {
        clear
        set seed 20260315
        set obs 200
        gen byte arm = (_n > 100)
        gen byte treated = arm
        replace treated = 1 if arm == 0 & runiform() < 0.3
        gen double t_latent = -ln(runiform()) * exp(0.5 * treated)
        gen double censor = runiformint(3, 10)
        gen double os_time = min(t_latent, censor)
        gen byte os_event = (t_latent <= censor)
        stset os_time, failure(os_event)

        aft_rpsftm, randomization(arm) treatment(treated) ///
            gridrange(-1 2) gridpoints(100) recensor nolog

        assert e(psi) < .
        assert e(af) > 0
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
* TEST 44: aft_rpsftm wilcoxon test
* =============================================================================
local ++test_count
local test_desc "aft_rpsftm with wilcoxon test type"
_run_test `test_count' "`test_desc'"

if `run_only' == 0 | `run_only' == `test_count' {
    capture {
        clear
        set seed 20260315
        set obs 200
        gen byte arm = (_n > 100)
        gen byte treated = arm
        replace treated = 1 if arm == 0 & runiform() < 0.3
        gen double t_latent = -ln(runiform()) * exp(0.5 * treated)
        gen double censor = runiformint(3, 10)
        gen double os_time = min(t_latent, censor)
        gen byte os_event = (t_latent <= censor)
        stset os_time, failure(os_event)

        aft_rpsftm, randomization(arm) treatment(treated) ///
            gridrange(-1 2) gridpoints(100) testtype(wilcoxon) nolog

        assert "`e(testtype)'" == "wilcoxon"
        assert e(psi) < .
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
* TEST 45: aft_rpsftm error on non-binary randomization
* =============================================================================
local ++test_count
local test_desc "aft_rpsftm errors on non-binary randomization"
_run_test `test_count' "`test_desc'"

if `run_only' == 0 | `run_only' == `test_count' {
    capture {
        clear
        set obs 100
        gen byte arm = mod(_n, 3)
        gen byte treated = (arm > 0)
        gen double os_time = runiform() * 10
        gen byte os_event = 1
        stset os_time, failure(os_event)

        capture aft_rpsftm, randomization(arm) treatment(treated)
        assert _rc == 198
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
* TEST 46: aft_rpsftm e-class results
* =============================================================================
local ++test_count
local test_desc "aft_rpsftm stores e-class results correctly"
_run_test `test_count' "`test_desc'"

if `run_only' == 0 | `run_only' == `test_count' {
    capture {
        clear
        set seed 20260315
        set obs 200
        gen byte arm = (_n > 100)
        gen byte treated = arm
        replace treated = 1 if arm == 0 & runiform() < 0.3
        gen double t_latent = -ln(runiform()) * exp(0.5 * treated)
        gen double censor = runiformint(3, 10)
        gen double os_time = min(t_latent, censor)
        gen byte os_event = (t_latent <= censor)
        stset os_time, failure(os_event)

        aft_rpsftm, randomization(arm) treatment(treated) ///
            gridrange(-1 2) gridpoints(100) nolog

        * Check e(b) and e(V)
        matrix b = e(b)
        assert colsof(b) == 1
        matrix V = e(V)
        assert rowsof(V) == 1 & colsof(V) == 1

        * Check grid matrix
        matrix g = e(grid)
        assert rowsof(g) == 100
        assert colsof(g) == 2

        * Check macros
        assert "`e(randomization)'" == "arm"
        assert "`e(treatment)'" == "treated"

        * af should be exp(psi)
        assert abs(e(af) - exp(e(psi))) < 0.0001
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
* TEST 47: aft_rpsftm data preservation
* =============================================================================
local ++test_count
local test_desc "aft_rpsftm preserves original data"
_run_test `test_count' "`test_desc'"

if `run_only' == 0 | `run_only' == `test_count' {
    capture {
        clear
        set seed 20260315
        set obs 200
        gen byte arm = (_n > 100)
        gen byte treated = arm
        replace treated = 1 if arm == 0 & runiform() < 0.3
        gen double t_latent = -ln(runiform()) * exp(0.5 * treated)
        gen double censor = runiformint(3, 10)
        gen double os_time = min(t_latent, censor)
        gen byte os_event = (t_latent <= censor)
        stset os_time, failure(os_event)

        local N_before = _N
        aft_rpsftm, randomization(arm) treatment(treated) ///
            gridrange(-1 2) gridpoints(50) nolog
        assert _N == `N_before'

        * Verify _aft_km doesn't exist
        capture confirm variable _aft_km
        assert _rc != 0
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
* TEST 48: aft_counterfactual basic
* =============================================================================
local ++test_count
local test_desc "aft_counterfactual runs after aft_rpsftm"
_run_test `test_count' "`test_desc'"

if `run_only' == 0 | `run_only' == `test_count' {
    capture {
        clear
        set seed 20260315
        set obs 200
        gen byte arm = (_n > 100)
        gen byte treated = arm
        replace treated = 1 if arm == 0 & runiform() < 0.3
        gen double t_latent = -ln(runiform()) * exp(0.5 * treated)
        gen double censor = runiformint(3, 10)
        gen double os_time = min(t_latent, censor)
        gen byte os_event = (t_latent <= censor)
        stset os_time, failure(os_event)

        aft_rpsftm, randomization(arm) treatment(treated) ///
            gridrange(-1 2) gridpoints(100) nolog

        aft_counterfactual
        assert r(psi) < .
        assert r(af) > 0
        assert "`r(randomization)'" == "arm"
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
* TEST 49: aft_counterfactual generate option
* =============================================================================
local ++test_count
local test_desc "aft_counterfactual generates variable"
_run_test `test_count' "`test_desc'"

if `run_only' == 0 | `run_only' == `test_count' {
    capture {
        clear
        set seed 20260315
        set obs 200
        gen byte arm = (_n > 100)
        gen byte treated = arm
        replace treated = 1 if arm == 0 & runiform() < 0.3
        gen double t_latent = -ln(runiform()) * exp(0.5 * treated)
        gen double censor = runiformint(3, 10)
        gen double os_time = min(t_latent, censor)
        gen byte os_event = (t_latent <= censor)
        stset os_time, failure(os_event)

        aft_rpsftm, randomization(arm) treatment(treated) ///
            gridrange(-1 2) gridpoints(100) nolog

        aft_counterfactual, generate(cf_time)
        confirm variable cf_time
        assert cf_time > 0 if !missing(cf_time)

        * For untreated subjects, cf_time should equal os_time
        * (exposure=0, so exp(-psi*0) = 1)
        count if abs(cf_time - _t) < 0.0001 & treated == 0
        assert r(N) > 0
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
* TEST 50: aft_counterfactual error without aft_rpsftm
* =============================================================================
local ++test_count
local test_desc "aft_counterfactual errors without aft_rpsftm"
_run_test `test_count' "`test_desc'"

if `run_only' == 0 | `run_only' == `test_count' {
    capture {
        sysuse cancer, clear
        stset studytime, failure(died)
        char _dta[_aft_rpsftm]
        capture aft_counterfactual
        assert _rc == 198
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
* TEST 51: Full RPSFTM pipeline
* =============================================================================
local ++test_count
local test_desc "Full RPSFTM pipeline: rpsftm -> counterfactual"
_run_test `test_count' "`test_desc'"

if `run_only' == 0 | `run_only' == `test_count' {
    capture {
        clear
        set seed 20260315
        set obs 300
        gen byte arm = (_n > 150)
        gen byte treated = arm
        replace treated = 1 if arm == 0 & runiform() < 0.25
        gen double t_latent = -ln(runiform()) * exp(0.5 * treated)
        gen double censor = runiformint(3, 12)
        gen double os_time = min(t_latent, censor)
        gen byte os_event = (t_latent <= censor)
        stset os_time, failure(os_event)

        * Run RPSFTM
        aft_rpsftm, randomization(arm) treatment(treated) ///
            gridrange(-1 2) gridpoints(100) recensor nolog
        local psi_est = e(psi)

        * Run counterfactual
        aft_counterfactual, generate(cf_time) table timehorizons(5)
        assert r(psi) < .

        * Counterfactual time should differ from observed for treated
        count if abs(cf_time - _t) > 0.001 & treated == 1
        assert r(N) > 0
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
* TEST 52: aft_rpsftm with treattime option
* =============================================================================
local ++test_count
local test_desc "aft_rpsftm with treattime option"
_run_test `test_count' "`test_desc'"

if `run_only' == 0 | `run_only' == `test_count' {
    capture {
        clear
        set seed 20260315
        set obs 200
        gen byte arm = (_n > 100)
        gen byte treated = arm
        replace treated = 1 if arm == 0 & runiform() < 0.3
        gen double t_latent = -ln(runiform()) * exp(0.5 * treated)
        gen double censor = runiformint(3, 10)
        gen double os_time = min(t_latent, censor)
        gen byte os_event = (t_latent <= censor)

        * Create treatment time (fraction of follow-up on treatment)
        gen double tx_time = treated * os_time * (0.5 + runiform() * 0.5)

        stset os_time, failure(os_event)

        aft_rpsftm, randomization(arm) treatment(treated) ///
            treattime(tx_time) gridrange(-1 2) gridpoints(100) nolog

        assert e(psi) < .
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
    display as text "aft FUNCTIONAL TEST SUMMARY"
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
