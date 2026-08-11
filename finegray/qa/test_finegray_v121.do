*! test_finegray_v121 Version 1.0.0  2026/08/11
*! Regression tests for finegray 1.2.1 review fixes
*! Author: Timothy P Copeland, Karolinska Institutet

clear all
set varabbrev off
version 16.0

capture log close _all
log using "test_finegray_v121.log", replace name(_fg121)

local qa_dir "`c(pwd)'"
local pkg_dir = regexr("`qa_dir'", "/qa$", "")
capture ado uninstall finegray
quietly net install finegray, from("`pkg_dir'") replace

local test_count = 0
local pass_count = 0
local fail_count = 0

capture program drop _fg121_result
program define _fg121_result, rclass
    args rc label
    if `rc' == 0 {
        display as result "  PASS: `label'"
        return scalar pass = 1
        return scalar fail = 0
    }
    else {
        display as error "  FAIL: `label' (rc=`rc')"
        return scalar pass = 0
        return scalar fail = 1
    }
end

capture program drop _fg121_factor_data
program define _fg121_factor_data
    clear
    set seed 8112026
    quietly set obs 800
    gen long id = _n
    gen byte abcdefghijklmnopqrstu_alpha = 1 + mod(_n, 2)
    gen byte abcdefghijklmnopqrstu_beta = ///
        cond(mod(floor((_n - 1) / 2), 2), 3, 1)
    gen double x = rnormal()
    gen double t = 1 + floor(10 * runiform())
    gen byte status = cond(runiform() < .35, 1, ///
        cond(runiform() < .45, 2, 0))
    gen byte anyev = status != 0
    quietly stset t, failure(anyev) id(id)
end

capture program drop _fg121_level_data
program define _fg121_level_data
    clear
    set seed 8113
    quietly set obs 400
    gen long id = _n
    gen double x = rnormal()
    gen double t = 1 + floor(8 * runiform())
    gen byte status = cond(runiform() < .35, 1, ///
        cond(runiform() < .45, 2, 0))
    gen byte anyev = status != 0
    quietly stset t, failure(anyev) id(id)
end

capture program drop _fg121_positivity_data
program define _fg121_positivity_data
    syntax [, RELEVANT]
    clear
    set seed 4242
    quietly set obs 120
    gen long id = _n
    gen byte z1 = mod(_n, 2)
    gen double t0 = 0.30 + runiform() * 0.2
    gen double t = t0 + 0.5 + runiform()
    gen byte status = 0

    * Two identified cause events precede a competing exit whose weight
    * denominator is zero. Without relevant(), no later cause event exists, so
    * that competing subject is never retained and its denominator is unused.
    quietly replace t0 = 0 in 1/2
    quietly replace t = 0.005 in 1
    quietly replace t = 0.007 in 2
    quietly replace status = 1 in 1/2
    quietly replace t0 = 0.001 in 3
    quietly replace t = 0.010 in 3
    quietly replace status = 2 in 3

    * Negative control: a later cause makes subject 3 part of a risk set. Its
    * zero denominator is then genuinely consulted and must remain a hard error.
    if "`relevant'" != "" {
        quietly replace t0 = 0.015 in 4
        quietly replace t = 0.020 in 4
        quietly replace status = 1 in 4
    }

    gen byte anyev = status > 0
    quietly stset t, failure(anyev == 1) id(id) enter(time t0)
end

**# 1. Multi-record baseline rebuild survives a cleared Mata cache
local ++test_count
capture noisily {
    webuse hypoxia, clear
    gen byte status = failtype
    quietly stset dftime, failure(dfcens == 1) id(stnum)
    quietly stsplit iv, at(2 4 6 8)
    quietly finegray ifp tumsize pelnode, ///
        compete(status) cause(1) nolog
    gen double horizon5 = 5
    quietly finegray_predict cif_warm, cif timevar(horizon5)
    quietly finegray_predict bh_warm, basecshazard timevar(horizon5)
    mata: mata clear
    quietly finegray_predict cif_cold, cif timevar(horizon5)
    quietly finegray_predict bh_cold, basecshazard timevar(horizon5)

    quietly count if !missing(cif_warm)
    local n_cif = r(N)
    quietly count if !missing(cif_cold)
    assert r(N) == `n_cif' & `n_cif' > 0
    quietly count if !missing(bh_warm)
    local n_bh = r(N)
    quietly count if !missing(bh_cold)
    assert r(N) == `n_bh' & `n_bh' > 0

    gen double _dcif = abs(cif_warm - cif_cold)
    gen double _dbh = abs(bh_warm - bh_cold)
    quietly summarize _dcif, meanonly
    assert r(max) < 1e-12
    quietly summarize _dbh, meanonly
    assert r(max) < 1e-12
}
local _rc = _rc
_fg121_result `_rc' FG121-1
local pass_count = `pass_count' + r(pass)
local fail_count = `fail_count' + r(fail)

**# 2. Legal long factor names remain scoreable
local ++test_count
capture noisily {
    _fg121_factor_data
    quietly finegray i.abcdefghijklmnopqrstu_alpha ///
        i.abcdefghijklmnopqrstu_beta x, ///
        compete(status) cause(1) nolog
    finegray_predict xb_long, xb
    quietly count if !missing(xb_long)
    assert r(N) == _N
}
local _rc = _rc
_fg121_result `_rc' FG121-2
local pass_count = `pass_count' + r(pass)
local fail_count = `fail_count' + r(fail)

**# 3. Long names with a common prefix retain separate fitted-level support
local ++test_count
capture noisily {
    _fg121_factor_data
    quietly finegray i.abcdefghijklmnopqrstu_alpha ///
        i.abcdefghijklmnopqrstu_beta x, ///
        compete(status) cause(1) nolog
    preserve
    keep in 1/3
    replace abcdefghijklmnopqrstu_alpha = 3
    replace abcdefghijklmnopqrstu_beta = 1
    capture noisily finegray_predict xb_unseen, xb
    local _prc = _rc
    assert `_prc' == 459
    capture confirm variable xb_unseen
    assert _rc != 0
    restore
}
local _rc = _rc
_fg121_result `_rc' FG121-3
local pass_count = `pass_count' + r(pass)
local fail_count = `fail_count' + r(fail)

**# 4. finegray_predict enforces Stata's cilevel range
local ++test_count
capture noisily {
    _fg121_level_data
    quietly finegray x, compete(status) cause(1) nolog
    capture noisily finegray_predict cif_bad, cif ci level(1)
    assert _rc == 198
    capture confirm variable cif_bad
    assert _rc != 0
    finegray_predict cif_ok, cif ci level(10)
    assert !missing(cif_ok, cif_ok_lci, cif_ok_uci) if e(sample)
}
local _rc = _rc
_fg121_result `_rc' FG121-4
local pass_count = `pass_count' + r(pass)
local fail_count = `fail_count' + r(fail)

**# 5. finegray_cif enforces the same cilevel range
local ++test_count
capture noisily {
    _fg121_level_data
    quietly finegray x, compete(status) cause(1) nolog
    capture noisily finegray_cif, attime(5) ci level(1) nograph
    assert _rc == 198
    finegray_cif, attime(5) ci level(10) nograph
    matrix _fg121_cif = r(table)
    assert r(level) == 10
    mata: assert(!hasmissing(st_matrix("_fg121_cif")))
}
local _rc = _rc
_fg121_result `_rc' FG121-5
local pass_count = `pass_count' + r(pass)
local fail_count = `fail_count' + r(fail)

**# 6. An unused zero competing-event denominator is not a violation
local ++test_count
capture noisily {
    _fg121_positivity_data
    finegray z1, compete(status) cause(1) nolog
    assert e(converged) == 1
    assert e(N_compete) == 1
}
local _rc = _rc
_fg121_result `_rc' FG121-6
local pass_count = `pass_count' + r(pass)
local fail_count = `fail_count' + r(fail)

**# 7. The same denominator remains fatal when a later cause consults it
local ++test_count
capture noisily {
    _fg121_positivity_data, relevant
    capture noisily finegray z1, compete(status) cause(1) nolog
    assert _rc == 459
}
local _rc = _rc
_fg121_result `_rc' FG121-7
local pass_count = `pass_count' + r(pass)
local fail_count = `fail_count' + r(fail)

**# Summary
display as text _newline ///
    "RESULT: test_finegray_v121 tests=`test_count' pass=`pass_count' fail=`fail_count'"
if `fail_count' > 0 {
    display as error "SOME TESTS FAILED"
    log close _fg121
    exit 1
}
display as result "ALL TESTS PASSED"
log close _fg121
