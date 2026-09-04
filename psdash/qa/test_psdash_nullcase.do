* test_psdash_nullcase.do -- degenerate-artifact (fail-open) contracts
*
* PSDASH-02 (2026-09-02 audit): psdash weights trusted unsigned _dta[_iivw_*]
* characteristics and let iivwcomponent() overwrite an explicit wvar(). The
* audit's reproduction returned rc 0, r(wvar)="stale_w" and r(max_wt)=25 for a
* call whose user had named explicit_w. Every block here supplies the
* degenerate artifact and requires a nonzero return code.
*
* Usage: cd psdash/qa && stata-mp -b do test_psdash_nullcase.do

clear all
version 16.0

capture log close _all
log using "test_psdash_nullcase.log", replace nomsg

do "`c(pwd)'/_psdash_bootstrap.do"
discard

local test_count = 0
global PSNC_PASS = 0
global PSNC_FAIL = 0
global PSNC_FAILED ""

capture program drop _psnc_ct
program define _psnc_ct
    args id rc
    if `rc' == 0 {
        display as result "  PASS: `id'"
        global PSNC_PASS = $PSNC_PASS + 1
    }
    else {
        display as error "  FAIL: `id' (rc=`rc')"
        global PSNC_FAIL = $PSNC_FAIL + 1
        global PSNC_FAILED "$PSNC_FAILED `id'"
    }
end

capture program drop _psnc_forged_iivw
program define _psnc_forged_iivw
    * Hand-written iivw contract metadata with no signature, plus two candidate
    * weight variables that disagree: the user's own, and the one the forged
    * characteristics point at.
    version 16.0
    clear
    set seed 20260903
    set obs 120
    gen byte trt = _n > 60
    gen double _iivw_ps = invlogit(0.3 * rnormal())
    gen double explicit_w = 1
    gen double stale_w = 1
    replace stale_w = 25 in 1
    char _dta[_iivw_weighted] "1"
    char _dta[_iivw_weighttype] "iptw"
    char _dta[_iivw_treat] "trt"
    char _dta[_iivw_ps_var] "_iivw_ps"
    char _dta[_iivw_tw_var] "stale_w"
    char _dta[_iivw_weight_var] "stale_w"
    char _dta[_iivw_treat_covars] "_iivw_ps"
end

**## P1 nullcase: conflicting explicit inputs are refused, not silently ranked
* The audit call. wvar() and iivwcomponent() both name the weight variable;
* the old code let the characteristic-selected variable win at rc 0.
local ++test_count
capture noisily {
    _psnc_forged_iivw
    capture noisily psdash weights trt, wvar(explicit_w) iivwcomponent(treatment)
    local p1_rc = _rc
    if `p1_rc' == 0 {
        display as error "  precedence: iivwcomponent() overrode explicit wvar() at rc 0"
        error 9
    }
    if `p1_rc' != 198 {
        display as error "  precedence: expected rc 198 for conflicting explicit inputs, got `p1_rc'"
        error 9
    }
    if "`r(wvar)'" == "stale_w" {
        display as error "  precedence: the stale characteristic weight still won"
        error 9
    }
}
_psnc_ct P1_conflicting_wvar_iivwcomponent `=_rc'

**## P2 nullcase: unverified producer metadata cannot select the component
* No wvar() and no positional argument, so this is the ambient auto-detect
* request: the forged, unsigned characteristics must be refused by the producer
* check rather than resolved from the raw _dta[_iivw_*] fields. This path was
* already fail-closed; the block is the regression guard that keeps it so now
* that psdash_weights no longer carries its own characteristic fallbacks.
local ++test_count
capture noisily {
    _psnc_forged_iivw
    capture noisily psdash weights, iivwcomponent(treatment)
    local p2_rc = _rc
    if `p2_rc' == 0 {
        display as error "  resolve: unsigned iivw metadata accepted at rc 0"
        error 9
    }
    if "`r(wvar)'" == "stale_w" {
        display as error "  resolve: unsigned metadata still selected stale_w"
        error 9
    }
    * The refused call must leave the user's data untouched.
    assert _N == 120
    confirm variable explicit_w stale_w
}
_psnc_ct P2_unverified_iivw_metadata `=_rc'

**## P3 nullcase: an explicit wvar() alone is still honoured
* Positive control for P1: with only one weight named, the named one is used.
local ++test_count
capture noisily {
    _psnc_forged_iivw
    psdash weights trt, wvar(explicit_w)
    assert "`r(wvar)'" == "explicit_w"
    assert abs(`r(max_wt)' - 1) < 1e-8
}
_psnc_ct P3_explicit_wvar_honoured `=_rc'

**## P4 nullcase: _psdash_require_meta helper contract
local ++test_count
capture noisily {
    capture _psdash_require_meta explicit "iivwcomponent(treatment)" "treatment weight variable="
    assert _rc == 198
    capture _psdash_require_meta explicit "iivwcomponent(treatment)" "treatment weight variable=_iivw_tw"
    assert _rc == 0
    capture _psdash_require_meta active "iivwcomponent(treatment)" "treatment weight variable="
    assert _rc == 0
    capture _psdash_require_meta explicit "label" "a=1" "b=   "
    assert _rc == 198
    capture _psdash_require_meta bogus "label" "a=1"
    assert _rc == 198
}
_psnc_ct P4_require_meta_contract `=_rc'

display as text _n "=== psdash null-case summary: $PSNC_PASS passed, $PSNC_FAIL failed ==="

local psnc_fail = $PSNC_FAIL
display "RESULT: test_psdash_nullcase tests=`test_count' pass=$PSNC_PASS fail=$PSNC_FAIL"
if `psnc_fail' > 0 {
    display as error "Failed tests:$PSNC_FAILED"
}
else {
    display as result "ALL PSDASH NULL-CASE TESTS PASSED"
}

_psdash_qa_cleanup
macro drop PSNC_PASS PSNC_FAIL PSNC_FAILED
capture log close _all
if `psnc_fail' > 0 {
    exit 9
}
