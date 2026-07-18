* test_finegray_fvgrammar.do
* Regression tests for the shared factor-variable grammar and out-of-sample
* missing-value handling in finegray prediction.
*
*   FG-05: valid Stata factor syntax ibn. (base-none) failed with r(198)
*          "_fg_1bn.grpXx invalid name".  ibn.grp keeps a coefficient for EVERY
*          level (no reference), so the first level 1bn.grp is a real term whose
*          generated name must be legal.  These tests fail on the pre-fix code,
*          where the bn. operator was copied verbatim into a variable name.
*
*   FG-01: scoring a row whose underlying factor variable is missing (system .
*          or extended .a-.z) silently set every dummy to zero, collapsing the
*          row onto the fitted base category and returning a fabricated xb/CIF
*          at rc 0.  These tests fail on the pre-fix code, where the missing
*          rows equalled the base row instead of returning missing.
clear all
set varabbrev off
version 16.0

capture log close _all
log using "test_finegray_fvgrammar.log", replace name(_fvg)

local qa_dir "`c(pwd)'"
local pkg_dir = subinstr("`qa_dir'", "/qa", "", 1)
capture ado uninstall finegray
quietly net install finegray, from("`pkg_dir'") replace

local test_count = 0
local pass_count = 0
local fail_count = 0

capture program drop _mk_fvg
program define _mk_fvg
    clear
    set seed 5150
    quietly set obs 600
    gen long id = _n
    gen byte grp = 1 + mod(_n, 3)
    label define _gl 1 "A" 2 "B" 3 "C", replace
    label values grp _gl
    gen double x = rnormal()
    gen double t = ceil(8 * runiform())
    gen byte ev = cond(runiform() < .45, 1, cond(runiform() < .5, 2, 0))
    quietly stset t, failure(ev) id(id)
end

**# 1. FG-05: ibn.grp#c.x fits with a coefficient for EVERY level (no reference)
* ibn. omits no base, so a 3-level factor interacted with a continuous term
* yields exactly 3 coefficients.  stcrreg accepts the identical specification
* (verified during the audit); the pre-fix finegray errored at r(198) with the
* invalid generated name _fg_1bn.grpXx, so this block fails on the old code.
local ++test_count
capture noisily {
    _mk_fvg
    finegray ibn.grp#c.x, compete(ev) cause(1) nolog
    assert colsof(e(b)) == 3
    * one column per level, all present, none dropped as a reference
    local cn : colnames e(b)
    assert `: word count `cn'' == 3
}
if _rc == 0 {
    display as result "  PASS: FVG-1 ibn. fits with 3 coefficients (no reference)"
    local ++pass_count
}
else {
    display as error "  FAIL: FVG-1 ibn. fit (rc=`=_rc')"
    local ++fail_count
}

**# 2. FG-05: the generated names for ibn. levels are legal _fg_ names
local ++test_count
capture noisily {
    _mk_fvg
    finegray ibn.grp#c.x, compete(ev) cause(1) nolog
    * legal names only: _fg_grp_1Xx _fg_grp_2Xx _fg_grp_3Xx (no "bn.")
    local cov "`e(covariates)'"
    assert strpos("`cov'", "bn.") == 0
    assert strpos("`cov'", ".") == 0
    foreach c of local cov {
        confirm name `c'
    }
}
if _rc == 0 {
    display as result "  PASS: FVG-2 ibn. generated names are legal"
    local ++pass_count
}
else {
    display as error "  FAIL: FVG-2 ibn. names (rc=`=_rc')"
    local ++fail_count
}

**# 3. FG-05: postestimation after an ibn. fit, incl. dropped-column rebuild
local ++test_count
capture noisily {
    _mk_fvg
    finegray ibn.grp#c.x, compete(ev) cause(1) nolog
    finegray_predict _xb, xb
    finegray_cif, attime(4)
    * drop persistent design columns -> each consumer rebuilds from e(fvsemantic)
    capture drop _fg_*
    finegray_cif, attime(4)
    finegray_phtest
}
if _rc == 0 {
    display as result "  PASS: FVG-3 postestimation + rebuild after ibn. fit"
    local ++pass_count
}
else {
    display as error "  FAIL: FVG-3 postestimation after ibn. (rc=`=_rc')"
    local ++fail_count
}

**# 4. FG-05: existing factor operators still fit (no regression)
local ++test_count
capture noisily {
    _mk_fvg
    foreach spec in "i.grp x" "ib2.grp x" "i.grp#c.x" "i.grp##c.x" {
        finegray `spec', compete(ev) cause(1) nolog
    }
}
if _rc == 0 {
    display as result "  PASS: FVG-4 i./ib#./#/## still fit"
    local ++pass_count
}
else {
    display as error "  FAIL: FVG-4 existing operators (rc=`=_rc')"
    local ++fail_count
}

**# 5. FG-01: a missing factor value scores as MISSING, never the base category
* On the pre-fix code xb for the missing rows equals the base-level xb (0) and
* is not missing -> both asserts below fail.
local ++test_count
capture noisily {
    _mk_fvg
    finegray i.grp x, compete(ev) cause(1) nolog
    preserve
    clear
    set obs 5
    gen byte grp = _n
    replace grp = .  in 4
    replace grp = .a in 5
    gen double x = 0
    finegray_predict xb, xb
    * base level (grp==1) scores to 0; the missing rows must NOT reproduce it
    assert xb[1] == 0
    assert missing(xb[4])
    assert missing(xb[5])
    restore
}
if _rc == 0 {
    display as result "  PASS: FVG-5 missing factor -> missing xb (not base)"
    local ++pass_count
}
else {
    display as error "  FAIL: FVG-5 missing factor xb (rc=`=_rc')"
    local ++fail_count
}

**# 6. FG-01: the same policy holds for the CIF path
local ++test_count
capture noisily {
    _mk_fvg
    finegray i.grp x, compete(ev) cause(1) nolog
    preserve
    clear
    set obs 4
    gen byte grp = _n
    replace grp = .a in 4
    gen double x = 0
    gen double horizon = 4
    finegray_predict cif4, cif timevar(horizon)
    * the base row has a real CIF; the missing row must be missing, not equal to it
    assert !missing(cif4[1])
    assert missing(cif4[4])
    restore
}
if _rc == 0 {
    display as result "  PASS: FVG-6 missing factor -> missing CIF (not base)"
    local ++pass_count
}
else {
    display as error "  FAIL: FVG-6 missing factor CIF (rc=`=_rc')"
    local ++fail_count
}

**# 7. FG-01: a missing constituent of an INTERACTION marks the row out
local ++test_count
capture noisily {
    _mk_fvg
    finegray i.grp##c.x, compete(ev) cause(1) nolog
    preserve
    clear
    set obs 3
    gen byte grp = _n
    gen double x = 0
    replace x = . in 3
    finegray_predict xbi, xb
    assert !missing(xbi[2])
    assert missing(xbi[3])
    restore
}
if _rc == 0 {
    display as result "  PASS: FVG-7 missing interaction covariate -> missing"
    local ++pass_count
}
else {
    display as error "  FAIL: FVG-7 missing interaction covariate (rc=`=_rc')"
    local ++fail_count
}

**# 8. Regression: an unseen NONMISSING level still errors r(459)
* FG-01 must not weaken the pre-existing unseen-level guard (FG-H02): a missing
* value and an unfitted nonmissing level are different failures.
local ++test_count
capture noisily {
    _mk_fvg
    finegray i.grp x, compete(ev) cause(1) nolog
    preserve
    clear
    set obs 3
    gen byte grp = 2 + mod(_n, 3)     // includes level 4, never fitted
    gen double x = 0
    capture finegray_predict xbu, xb
    assert _rc == 459
    restore
}
if _rc == 0 {
    display as result "  PASS: FVG-8 unseen nonmissing level still errors 459"
    local ++pass_count
}
else {
    display as error "  FAIL: FVG-8 unseen level guard (rc=`=_rc')"
    local ++fail_count
}

**# Summary
display as text _newline ///
    "RESULT: test_finegray_fvgrammar tests=`test_count' pass=`pass_count' fail=`fail_count'"
if `fail_count' > 0 {
    display as error "SOME TESTS FAILED"
    log close _fvg
    exit 1
}
display as result "ALL TESTS PASSED"
log close _fvg
