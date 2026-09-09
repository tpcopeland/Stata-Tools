*! test_documentation_examples Version 1.0.0  2026/09/09
*! Runnable checks for the README binary quickstart and multi-group recipe
*! Author: Timothy P Copeland, Karolinska Institutet

clear all
version 16.0
set more off
set varabbrev off

capture log close _all
log using "test_documentation_examples.log", replace nomsg

do "`c(pwd)'/_psdash_bootstrap.do"
discard

global PSDASH_DE_TESTS = 0
global PSDASH_DE_PASS = 0
global PSDASH_DE_FAIL = 0
global PSDASH_DE_FAILED ""

capture program drop _de_result
program define _de_result
    args id rc
    global PSDASH_DE_TESTS = $PSDASH_DE_TESTS + 1
    if `rc' == 0 {
        display as result "PASS: `id'"
        global PSDASH_DE_PASS = $PSDASH_DE_PASS + 1
    }
    else {
        display as error "FAIL: `id' (rc=`rc')"
        global PSDASH_DE_FAIL = $PSDASH_DE_FAIL + 1
        global PSDASH_DE_FAILED "$PSDASH_DE_FAILED `id'"
    }
end

**# README binary quickstart

capture noisily {
    sysuse auto, clear
    logit foreign mpg weight length
    assert e(converged) == 1
    predict double ps, pr
    psdash combined foreign ps, covariates(mpg weight length)
    return list

    assert r(N_requested) == 74
    assert r(N_analysis) == 74
    assert r(n_common_excluded) == 0
    assert r(n_panels) == 4
    assert "`r(treatment)'" == "foreign"
    assert "`r(psvar)'" == "ps"
    assert "`r(source)'" == "manual"
    assert inlist("`r(verdict)'", "PASS", "FAIL")
    assert inrange(ps, 0, 1) if e(sample)
    capture graph drop _all
}
_de_result readme_binary_quickstart `=_rc'

**# README multi-group generalized-propensity-score recipe

capture noisily {
    clear
    set obs 300
    set seed 20260506
    gen double age = rnormal(60, 10)
    gen byte female = runiform() > .5
    gen double bmi = rnormal(27, 4)
    gen double eta1 = -0.2 + 0.03*(age-60) + 0.25*female - 0.04*(bmi-27)
    gen double eta2 = 0.1 - 0.02*(age-60) + 0.02*(bmi-27)
    gen double den = 1 + exp(eta1) + exp(eta2)
    gen double p0 = 1/den
    gen double p1 = exp(eta1)/den
    gen double u = runiform()
    gen byte arm = cond(u < p0, 0, cond(u < p0 + p1, 1, 2))

    mlogit arm age female bmi
    assert e(converged) == 1
    predict double ps0 ps1 ps2, pr
    assert inrange(ps0, 0, 1) & inrange(ps1, 0, 1) & inrange(ps2, 0, 1)
    assert abs(ps0 + ps1 + ps2 - 1) < 1e-6

    psdash overlap arm, psvars(ps0 ps1 ps2)
    assert r(K) == 3 & r(N) == 300
    assert rowsof(r(gps_means)) == 3 & colsof(r(gps_means)) == 3

    psdash balance arm, psvars(ps0 ps1 ps2) covariates(age female bmi) loveplot
    assert r(K) == 3 & r(N) == 300
    assert rowsof(r(balance)) > 0

    psdash weights arm, psvars(ps0 ps1 ps2) detail
    assert r(K) == 3 & r(N) == 300
    assert !missing(r(ess)) & r(ess) > 0 & r(ess) <= r(N)

    psdash support arm, psvars(ps0 ps1 ps2) threshold(0.1) nograph
    assert r(K) == 3 & r(N) == 300
    assert rowsof(r(gps_means)) == 3 & colsof(r(gps_means)) == 3

    psdash balance arm, psvars(ps0 ps1 ps2) ///
        covariates(age female bmi) reference(1)
    assert r(K) == 3 & r(N) == 300
    assert "`r(reference)'" == "1"
    capture graph drop _all
}
_de_result readme_multigroup_recipe `=_rc'

display as text _n ///
    "RESULT: test_documentation_examples tests=$PSDASH_DE_TESTS pass=$PSDASH_DE_PASS fail=$PSDASH_DE_FAIL skip=0"

local final_fail = $PSDASH_DE_FAIL
local final_failed "$PSDASH_DE_FAILED"
_psdash_qa_cleanup
capture log close _all
macro drop PSDASH_DE_TESTS PSDASH_DE_PASS PSDASH_DE_FAIL PSDASH_DE_FAILED

if `final_fail' > 0 {
    display as error "Failed tests:`final_failed'"
    exit 9
}
