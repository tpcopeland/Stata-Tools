*! validation_public_known_answers.do Version 1.0.0  2026/08/31
*! Exact additional known-answer checks for psdash diagnostics
*! Author: Timothy P Copeland, Karolinska Institutet
* Usage: cd psdash/qa && stata-mp -b do validation_public_known_answers.do

clear all
version 16.0
set more off
set varabbrev off

capture log close _all
log using "validation_public_known_answers.log", replace nomsg

do "`c(pwd)'/_psdash_bootstrap.do"
discard

global PSDASH_PKA_TESTS = 0
global PSDASH_PKA_PASS = 0
global PSDASH_PKA_FAIL = 0
global PSDASH_PKA_FAILED ""

capture program drop _psdash_pka_record
program define _psdash_pka_record
    args id rc
    global PSDASH_PKA_TESTS = $PSDASH_PKA_TESTS + 1
    if `rc' == 0 {
        display as result "PASS: `id'"
        global PSDASH_PKA_PASS = $PSDASH_PKA_PASS + 1
    }
    else {
        display as error "FAIL: `id' (rc=`rc')"
        global PSDASH_PKA_FAIL = $PSDASH_PKA_FAIL + 1
        global PSDASH_PKA_FAILED "$PSDASH_PKA_FAILED `id'"
    }
end

**# Tied propensity scores
**## Pairwise AUC gives half credit to ties

capture noisily {
    clear
    input byte treated double ps
        1 0.20
        1 0.80
        0 0.20
        0 0.50
    end

    psdash overlap treated ps, nograph
    assert !missing(r(auc))
    * Four treated-control pairs contribute 0.5, 0, 1, and 1.
    assert abs(r(auc) - (2.5 / 4)) < 1e-12
    assert abs(r(overlap_lower) - 0.20) < 1e-12
    assert abs(r(overlap_upper) - 0.50) < 1e-12
    assert r(n_outside) == 1
    assert abs(r(pct_outside) - 25) < 1e-12
}
_psdash_pka_record tied_auc_half_credit `=_rc'

**# Quantile common support
**## Tied order statistics resolve to exact p25/p75 bounds

capture noisily {
    clear
    input byte treated double ps
        1 0.10
        1 0.10
        1 0.20
        1 0.20
        1 0.80
        1 0.80
        1 0.90
        1 0.90
        0 0.05
        0 0.15
        0 0.15
        0 0.25
        0 0.75
        0 0.85
        0 0.85
        0 0.95
    end

    psdash support treated ps, qtrim(25) nograph
    assert r(qtrim) == 25
    assert abs(r(lower_bound) - 0.15) < 1e-12
    assert abs(r(upper_bound) - 0.85) < 1e-12
    assert r(n_outside_treated) == 4
    assert r(n_outside_control) == 2
    assert r(n_outside) == 6
    assert abs(r(pct_outside) - 37.5) < 1e-12
}
_psdash_pka_record tied_qtrim_exact_bounds `=_rc'

**# Uneven treatment groups
**## Overall and arm-specific ESS use the correct denominators

capture noisily {
    clear
    input byte treated double wt
        1 1
        1 4
        0 1
        0 1
        0 2
        0 3
        0 5
    end

    psdash weights treated, wvar(wt) extreme(2 4)
    assert r(N) == 7
    assert r(N_treated) == 2
    assert r(N_control) == 5
    assert abs(r(mean_wt) - (17 / 7)) < 1e-12
    assert abs(r(ess) - (289 / 57)) < 1e-12
    assert abs(r(ess_treated) - (25 / 17)) < 1e-12
    assert abs(r(ess_control) - (144 / 40)) < 1e-12
    assert abs(r(ess_pct_treated) - (100 * (25 / 17) / 2)) < 1e-10
    assert abs(r(ess_pct_control) - 72) < 1e-12
    assert r(n_extreme) == 3
    assert abs(r(pct_extreme) - (300 / 7)) < 1e-10
    assert abs(r(max_ratio) - (35 / 17)) < 1e-12
    assert r(extreme_hi) == 2
    assert r(extreme_vhi) == 4
}
_psdash_pka_record uneven_group_ess_and_extremes `=_rc'

**# Summary

display as text "RESULT: validation_public_known_answers tests=$PSDASH_PKA_TESTS pass=$PSDASH_PKA_PASS fail=$PSDASH_PKA_FAIL skip=0"

local final_fail = $PSDASH_PKA_FAIL
local failed "$PSDASH_PKA_FAILED"
macro drop PSDASH_PKA_TESTS PSDASH_PKA_PASS PSDASH_PKA_FAIL PSDASH_PKA_FAILED
_psdash_qa_cleanup
capture log close _all

if `final_fail' {
    display as error "Failed tests:`failed'"
    exit 9
}
