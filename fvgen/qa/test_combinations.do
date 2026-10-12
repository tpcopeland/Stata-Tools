*! test_combinations.do — Option-combination QA for fvgen against native fits
*! Author: Timothy P Copeland, Karolinska Institutet
*! Requires: Stata 16.0+

clear all
set varabbrev off
version 16.0

do _fvgen_qa_common.do
_fvgen_qa_bootstrap

local test_count = 0
local pass_count = 0
local fail_count = 0
local failed_tests ""

**# 1. margins store() after prefix() + vsref() + xsymbol() matches native margins
local ++test_count
capture noisily {
    sysuse auto, clear
    quietly regress price i.foreign##c.mpg
    quietly margins, dydx(mpg) at(foreign=(0 1))
    matrix nb = r(b)
    matrix nV = r(V)
    fvgen i.foreign##c.mpg, prefix(z_) vsref("(vs. @)") xsymbol(x)
    assert "`r(allvars)'" == "z_foreign_1 mpg z_foreignXmpg_1"
    assert "`: variable label z_foreign_1'" == "Foreign (vs. Domestic)"
    assert "`: variable label z_foreignXmpg_1'" == "Foreign x Mileage (mpg)"
    regress price `r(allvars)'
    local flat_cmdline `"`e(cmdline)'"'
    fvgen, margins store(m_combo)
    assert "`r(stored)'" == "m_combo"
    * the flattened fit is still active for table export
    assert `"`e(cmdline)'"' == `"`flat_cmdline'"'
    estimates restore m_combo
    quietly margins, dydx(mpg) at(foreign=(0 1))
    assert mreldif(r(b), nb) < 1e-10
    assert mreldif(r(V), nV) < 1e-10
    estimates drop m_combo
}
if _rc == 0 {
    display as result "  PASS: store() after prefix/vsref/xsymbol matches native margins"
    local ++pass_count
}
else {
    display as error "  FAIL: store() with label options (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 1"
}

**# 2. ref() + simple(): per-group slopes under a chosen base match native
local ++test_count
capture noisily {
    sysuse auto, clear
    fvgen i.rep78##c.mpg, ref(rep78 3) simple(rep78)
    assert "`r(spec)'" == "ib3.rep78 ib3.rep78#c.mpg"
    local allv `r(allvars)'
    quietly regress price `allv'
    local r2f = e(r2)
    local rkf = e(rank)
    matrix bf = e(b)
    quietly regress price ib3.rep78 ib3.rep78#c.mpg
    assert !missing(e(r2), `r2f')
    assert reldif(e(r2), `r2f') < 1e-12
    assert e(rank) == `rkf'
    * every per-group slope equals the native level#c.mpg coefficient
    foreach L in 1 2 3 4 5 {
        assert !missing(bf[1, colnumb(bf, "_rep78Xmpg_`L'")], _b[`L'.rep78#c.mpg])
        assert reldif(bf[1, colnumb(bf, "_rep78Xmpg_`L'")], _b[`L'.rep78#c.mpg]) < 1e-9
    }
}
if _rc == 0 {
    display as result "  PASS: ref() + simple() per-group slopes match native"
    local ++pass_count
}
else {
    display as error "  FAIL: ref() + simple() (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 2"
}

**# 3. ref() + center + aweight: weighted centering, native-equivalent fit
local ++test_count
capture noisily {
    sysuse auto, clear
    fvgen i.rep78##c.mpg [aw=weight], ref(rep78 4) center
    assert "`r(spec)'" == "ib4.rep78 mpg ib4.rep78#c.mpg"
    local allv `r(allvars)'
    quietly summarize mpg [aw=weight] if !missing(rep78)
    local wm = r(mean)
    assert !missing(`wm')
    assert !missing(_mpg_c, mpg - `wm')
    assert reldif(_mpg_c, mpg - `wm') < 1e-12
    quietly regress price `allv' [aw=weight]
    local r2f = e(r2)
    quietly regress price ib4.rep78##c.mpg [aw=weight]
    assert !missing(e(r2), `r2f')
    assert reldif(e(r2), `r2f') < 1e-12
    * centering leaves each interaction coefficient unchanged
    foreach L in 1 2 3 5 {
        local bn = _b[`L'.rep78#c.mpg]
        quietly regress price `allv' [aw=weight]
        assert !missing(_b[_rep78Xmpg_`L'], `bn')
        assert reldif(_b[_rep78Xmpg_`L'], `bn') < 1e-8
        quietly regress price ib4.rep78##c.mpg [aw=weight]
    }
}
if _rc == 0 {
    display as result "  PASS: ref() + center + aweight"
    local ++pass_count
}
else {
    display as error "  FAIL: ref() + center + aweight (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 3"
}

**# 4. simple() + alllevels: cell-means parameterization with noconstant
local ++test_count
capture noisily {
    sysuse auto, clear
    fvgen i.foreign##c.mpg, simple(foreign) alllevels
    assert "`r(allvars)'" == "_foreign_0 _foreign_1 _foreignXmpg_0 _foreignXmpg_1"
    assert r(k_main) == 2 & r(k_int) == 2
    quietly regress price `r(allvars)', noconstant
    matrix bf = e(b)
    local r2f = e(r2)
    quietly regress price ibn.foreign ibn.foreign#c.mpg, noconstant
    assert !missing(e(r2), `r2f')
    assert reldif(e(r2), `r2f') < 1e-12
    foreach L in 0 1 {
        assert !missing(bf[1, colnumb(bf, "_foreign_`L'")], _b[`L'.foreign])
        assert !missing(bf[1, colnumb(bf, "_foreignXmpg_`L'")], _b[`L'.foreign#c.mpg])
        assert reldif(bf[1, colnumb(bf, "_foreign_`L'")], _b[`L'.foreign]) < 1e-9
        assert reldif(bf[1, colnumb(bf, "_foreignXmpg_`L'")], _b[`L'.foreign#c.mpg]) < 1e-9
    }
}
if _rc == 0 {
    display as result "  PASS: simple() + alllevels matches native cell-means fit"
    local ++pass_count
}
else {
    display as error "  FAIL: simple() + alllevels (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 4"
}

**# Summary
display as result "Results: `pass_count'/`test_count' passed, `fail_count' failed"
if `fail_count' > 0 {
    display as error "SOME TESTS FAILED:`failed_tests'"
    display "RESULT: test_combinations tests=`test_count' pass=`pass_count' fail=`fail_count'"
    exit 1
}
display as result "ALL TESTS PASSED"
display "RESULT: test_combinations tests=`test_count' pass=`pass_count' fail=`fail_count'"
