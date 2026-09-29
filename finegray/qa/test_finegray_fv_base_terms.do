*! test_finegray_fv_base_terms.do - factor terms that carry a base level but are real columns
*! Author: Timothy P Copeland, Karolinska Institutet
*
* Through 1.3.7 every site that paired e(fvsemantic) or the e(b) stripe with
* the design skipped ANY term containing an `Nb.' part.  Stata omits a term
* only when a part carries an `o' marker or when it is a pure factor term
* whose every part is a base level; 1b.grp#c.x in i.grp#c.x (the group-1
* slope) and 1b.a#2.b in i.a#i.b (a real cell) are estimated by stcox and
* stcrreg.  finegray fixed those coefficients at 0 and reported them as
* "(omitted)": a constrained model at rc 0 (i.grp i.grp#c.x: ll -707.853
* against stcrreg's -707.279, Wald chi2(2) against chi2(3)).
*
* Oracle: stcrreg on the identical specification -- the stripe, Stata's own
* omission pattern (_ms_omit_info), the coefficients and the log likelihood
* must agree.  Post-estimation is checked against a linear predictor computed
* by hand from e(b) and the raw covariates, and against the rebuild path.

clear all
set more off
set varabbrev off
version 16.0

local test_count = 0
local pass_count = 0
local fail_count = 0

local qa_dir "`c(pwd)'"
capture log close _all
log using "test_finegray_fv_base_terms.log", replace text name(_test_fgfvb)
do "`qa_dir'/_finegray_qa_common.do"
quietly _finegray_qa_bootstrap

capture program drop _fgfvb_data
program define _fgfvb_data
    clear
    set seed 290926
    set obs 600
    generate long id = _n
    generate double x = rnormal()
    generate double zz = rnormal()
    generate byte a = 1 + floor(3 * runiform())
    generate byte bb = 1 + (runiform() < .5)
    generate double t1 = -ln(runiform()) / exp(.4 * x - .3 * (a == 2) + .2 * bb)
    generate double t2 = -ln(runiform()) / .6
    generate double tc = -ln(runiform()) / .3
    generate double t = min(t1, t2, tc)
    generate byte status = cond(t == t1, 1, cond(t == t2, 2, 0))
end

* stcrreg and finegray on the same specification: same stripe, same omission
* pattern, same coefficients and log likelihood.  stcrreg's point estimate is
* the same Fine-Gray estimator; its variance is the nuisance sandwich, which
* is not compared here (the default finegray variance differs by design).
capture program drop _fgfvb_parity
program define _fgfvb_parity, rclass
    args spec
    quietly stset t, failure(status == 1) id(id)
    quietly stcrreg `spec', compete(status == 2) nolog noshow
    tempname bs os
    matrix `bs' = e(b)
    local cs : colfullnames e(b)
    local cs = subinstr("`cs'", "eq1:", "", .)
    _ms_omit_info e(b)
    matrix `os' = r(omit)
    local lls = e(ll)
    quietly stset t, failure(status == 1 2) id(id)
    quietly finegray `spec', compete(status) cause(1) nolog
    assert e(converged) == 1
    local cf : colfullnames e(b)
    _ms_omit_info e(b)
    tempname of
    matrix `of' = r(omit)
    if "`cf'" != "`cs'" {
        display as error "stripe differs: finegray [`cf'] stcrreg [`cs']"
        exit 9
    }
    assert mreldif(`of', `os') == 0
    assert !missing(e(ll)) & !missing(`lls')
    assert reldif(e(ll), `lls') < 1e-7
    tempname bf
    matrix `bf' = e(b)
    matrix colnames `bf' = `: colnames `bs''
    assert mreldif(`bf', `bs') < 1e-5
    * one design column per non-omitted coefficient
    local k = 0
    forvalues j = 1/`=colsof(`of')' {
        if `of'[1, `j'] == 0 local ++k
    }
    assert `: word count `e(designvars)'' == `k'
    assert e(df_m) == `k'
    return scalar k = `k'
end

* repost a fit's e() with a narrowed design, as a 1.3.7 fit left it
capture program drop _fgfvb_stale
program define _fgfvb_stale, eclass
    args b V dv
    ereturn repost b = `b' V = `V'
    ereturn local designvars "`dv'"
end

**# FVB-1 i.a#c.x: one slope per level, the base level's included
local ++test_count
capture noisily {
    _fgfvb_data
    _fgfvb_parity "i.a#c.x"
    assert r(k) == 3
    * the group-1 slope is a real, nonzero coefficient
    assert _b[1b.a#c.x] != 0 & !missing(_b[1b.a#c.x])
    assert _se[1b.a#c.x] > 0 & !missing(_se[1b.a#c.x])
}
if _rc == 0 {
    display as result "  PASS: FVB-1 i.a#c.x matches stcrreg (3 slopes)"
    local ++pass_count
}
else {
    display as error "  FAIL: FVB-1 i.a#c.x (rc=`=_rc')"
    local ++fail_count
}

**# FVB-2 i.a i.a#c.x: separate intercepts and slopes
local ++test_count
capture noisily {
    _fgfvb_data
    _fgfvb_parity "i.a i.a#c.x"
    assert r(k) == 5
}
if _rc == 0 {
    display as result "  PASS: FVB-2 i.a i.a#c.x matches stcrreg (5 coefficients)"
    local ++pass_count
}
else {
    display as error "  FAIL: FVB-2 i.a i.a#c.x (rc=`=_rc')"
    local ++fail_count
}

**# FVB-3 i.a#i.bb: cell parameterisation, only the all-base cell omitted
local ++test_count
capture noisily {
    _fgfvb_data
    _fgfvb_parity "i.a#i.bb"
    assert r(k) == 5
    assert _b[1b.a#2.bb] != 0 & !missing(_b[1b.a#2.bb])
}
if _rc == 0 {
    display as result "  PASS: FVB-3 i.a#i.bb matches stcrreg (5 cells)"
    local ++pass_count
}
else {
    display as error "  FAIL: FVB-3 i.a#i.bb (rc=`=_rc')"
    local ++fail_count
}

**# FVB-4 three-way and mixed forms
local ++test_count
capture noisily {
    _fgfvb_data
    local nspec = 0
    foreach spec in "i.a#i.bb#c.x" "i.a i.a#i.bb" "ib2.a#i.bb" "i.a#c.x#c.zz" "ibn.a#c.x" {
        display as text "  spec: `spec'"
        _fgfvb_parity "`spec'"
        assert !missing(r(k)) & r(k) >= 3
        local ++nspec
    }
    assert `nspec' == 5
}
if _rc == 0 {
    display as result "  PASS: FVB-4 three-way, ib#., ibn. and c#c forms match stcrreg"
    local ++pass_count
}
else {
    display as error "  FAIL: FVB-4 mixed forms (rc=`=_rc')"
    local ++fail_count
}

**# FVB-5 controls that were already right stay right (o-marked terms)
local ++test_count
capture noisily {
    _fgfvb_data
    local nspec = 0
    foreach spec in "i.a" "ib2.a x" "i.a##c.x" "c.x i.a#c.x" "i.a#c.x c.x" "i.a##i.bb" "i.a##i.bb##c.x" {
        display as text "  spec: `spec'"
        _fgfvb_parity "`spec'"
        assert !missing(r(k)) & r(k) >= 2
        local ++nspec
    }
    assert `nspec' == 7
}
if _rc == 0 {
    display as result "  PASS: FVB-5 main-effect and ## forms match stcrreg"
    local ++pass_count
}
else {
    display as error "  FAIL: FVB-5 control forms (rc=`=_rc')"
    local ++fail_count
}

**# FVB-6 post-estimation on i.a#c.x: xb by hand, CIF through the rebuild, phtest rows
local ++test_count
capture noisily {
    _fgfvb_data
    quietly stset t, failure(status == 1 2) id(id)
    quietly finegray i.a#c.x, compete(status) cause(1) nolog
    assert "`e(designvars)'" == "_fg_a_1Xx _fg_a_2Xx _fg_a_3Xx"
    * independent linear predictor: every level's slope, base included
    generate double xb_hand = _b[1b.a#c.x] * (a == 1) * x + ///
        _b[2.a#c.x] * (a == 2) * x + _b[3.a#c.x] * (a == 3) * x
    finegray_predict double xb_fg, xb
    quietly count if !missing(xb_fg)
    assert r(N) == _N
    generate double dxb = abs(xb_fg - xb_hand)
    quietly summarize dxb
    assert r(N) == _N & r(max) < 1e-12
    * the design columns are what the fit used
    generate double d1 = abs(_fg_a_1Xx - (a == 1) * x)
    quietly summarize d1
    assert r(max) == 0
    * CIF at a group-1 profile moves with the group-1 slope, and the rebuild
    * path (design columns dropped) reproduces it
    finegray_cif, at(a=1 x=1) attime(1 2) nograph
    tempname C1 C0 C2
    matrix `C1' = r(table)
    finegray_cif, at(a=1 x=0) attime(1 2) nograph
    matrix `C0' = r(table)
    assert `C1'[1, 2] != `C0'[1, 2]
    drop _fg_*
    finegray_cif, at(a=1 x=1) attime(1 2) nograph
    matrix `C2' = r(table)
    assert mreldif(`C1', `C2') < 1e-12
    * CIF by hand from the baseline: F = 1 - exp(-H0(t) exp(xb)); the
    * reference profile x=0 gives F0, and x=1 in group 1 scales H0 by
    * exp(_b[1b.a#c.x])
    scalar H0 = -ln(1 - `C0'[1, 2])
    scalar Fh = 1 - exp(-H0 * exp(_b[1b.a#c.x]))
    assert !missing(Fh) & !missing(`C1'[1, 2])
    assert reldif(Fh, `C1'[1, 2]) < 1e-10
    finegray_phtest
    tempname P
    matrix `P' = r(phtest)
    assert rowsof(`P') == 3
    assert "`: rownames `P''" == "1b.a#c.x 2.a#c.x 3.a#c.x"
}
if _rc == 0 {
    display as result "  PASS: FVB-6 xb, CIF (and its rebuild) and phtest use the group-1 slope"
    local ++pass_count
}
else {
    display as error "  FAIL: FVB-6 post-estimation on i.a#c.x (rc=`=_rc')"
    local ++fail_count
}

**# FVB-7 tvc(x) on i.a#c.x frees every level's slope, the base level's included
local ++test_count
capture noisily {
    _fgfvb_data
    quietly stset t, failure(status == 1 2) id(id)
    quietly summarize t if status == 1, detail
    local cut = r(p50)
    quietly finegray i.a#c.x, compete(status) cause(1) nolog tvc(x) tsplit(`cut')
    assert e(converged) == 1
    assert colsof(e(b)) == 6
    local cn : colfullnames e(b)
    assert "`cn'" == "tvc1:1b.a#c.x tvc1:2.a#c.x tvc1:3.a#c.x tvc2:1b.a#c.x tvc2:2.a#c.x tvc2:3.a#c.x"
    assert [tvc1]_b[1b.a#c.x] != 0 & [tvc2]_b[1b.a#c.x] != 0
    assert !missing([tvc1]_se[1b.a#c.x])
    finegray_predict double xbt, xb attime(0.01)
    generate double xbt_hand = [tvc1]_b[1b.a#c.x] * (a == 1) * x + ///
        [tvc1]_b[2.a#c.x] * (a == 2) * x + [tvc1]_b[3.a#c.x] * (a == 3) * x
    generate double dt = abs(xbt - xbt_hand)
    quietly summarize dt
    assert r(N) == _N & r(max) < 1e-12
}
if _rc == 0 {
    display as result "  PASS: FVB-7 tvc(x) on i.a#c.x: 6 coefficients, xb by hand"
    local ++pass_count
}
else {
    display as error "  FAIL: FVB-7 tvc() on i.a#c.x (rc=`=_rc')"
    local ++fail_count
}

**# FVB-8 estimates saved by a fit that dropped the slope are refused, not misread
* A 1.3.7 fit of i.a#c.x posted 1b.a#c.x as a zero base column with two design
* columns; the new stripe rule counts three.  Emulate that stale result and
* require post-estimation to stop rather than pair two columns with three
* coefficients.
local ++test_count
capture noisily {
    _fgfvb_data
    quietly stset t, failure(status == 1 2) id(id)
    quietly finegray i.a#c.x, compete(status) cause(1) nolog
    tempname b V
    matrix `b' = e(b)
    matrix `V' = e(V)
    matrix `b'[1, 1] = 0
    matrix `V'[1, 1] = 0
    _fgfvb_stale `b' `V' "_fg_a_2Xx _fg_a_3Xx"
    assert "`e(designvars)'" == "_fg_a_2Xx _fg_a_3Xx" & _b[1b.a#c.x] == 0
    capture noisily finegray_predict xbs, xb
    assert _rc != 0
    capture confirm variable xbs
    assert _rc != 0
    capture noisily finegray_cif, attime(1) nograph
    assert _rc != 0
}
if _rc == 0 {
    display as result "  PASS: FVB-8 stale narrow-design results are refused"
    local ++pass_count
}
else {
    display as error "  FAIL: FVB-8 stale results (rc=`=_rc')"
    local ++fail_count
}

**# FVB-9 margins on an interaction-only fit: at() reaches the prediction
* margins re-stripes e(b) onto its own indicator columns while it computes
* dydx() at() margins.  On i.a#c.x and ibn.a#c.x that vector has as many
* columns as the design, and through 1.3.7 finegray_predict took it for the
* fitted stripe by that COUNT, scored its own design at the data's values
* and returned one number for every level at rc 0 (measured on 1.3.7 with
* ibn.a#c.x: .1246 at a = 1, 2 and 3).  Oracle: d xb / dx at a = k is the
* level-k slope, exactly.
local ++test_count
capture noisily {
    _fgfvb_data
    quietly stset t, failure(status == 1 2) id(id)
    foreach spec in "i.a#c.x zz" "ibn.a#c.x zz" {
        quietly finegray `spec', compete(status) cause(1) nolog
        local s1 = cond(substr("`spec'", 1, 2) == "i.", "1b.a#c.x", "1bn.a#c.x")
        tempname W M
        matrix `W' = (_b[`s1'], _b[2.a#c.x], _b[3.a#c.x])
        quietly margins, dydx(x) at(a=(1 2 3) zz=0)
        matrix `M' = r(b)
        assert mreldif(`M', `W') < 1e-7
        quietly margins, dydx(x) at(a=(1 2 3) zz=0) predict(xb)
        matrix `M' = r(b)
        assert mreldif(`M', `W') < 1e-7
        * the CIF cannot honour a re-striped e(b) (its baseline pairs
        * coefficients with the design by position): refused, never a
        * constant at rc 0
        capture quietly margins, dydx(x) at(a=(1 2 3) zz=0) predict(cif timevar(t))
        assert _rc == 498
    }
}
if _rc == 0 {
    display as result "  PASS: FVB-9 margins dydx(x) at(a=) returns each level's slope; re-striped CIF refused"
    local ++pass_count
}
else {
    display as error "  FAIL: FVB-9 margins on interaction-only fits (rc=`=_rc')"
    local ++fail_count
}

display "RESULT: test_finegray_fv_base_terms tests=`test_count' pass=`pass_count' fail=`fail_count'"
capture log close _test_fgfvb
if `fail_count' > 0 exit 1
exit 0
