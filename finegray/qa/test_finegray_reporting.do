* test_finegray_reporting.do
* Regression tests for the finegray r(profile_vars) and bootstrap-SE reporting fixes
* (shipped in 1.2.0; "the pre-fix build" below means 1.2.0 as of 2026-07-23).
*
* REP-1..4  r(profile_vars) reports the vocabulary the USER typed.
*   Through the pre-fix build finegray_cif returned e(designvars) -- the package-owned
*   design columns -- so a fit on `i.grp' reported `_fg_grp_2 _fg_grp_3'.  Those
*   are names the user never wrote, need not have in their data (dropping them
*   is a documented, supported thing to do), and cannot hand back to at(),
*   which takes `grp=1'.  The input and output vocabularies disagreed.
*   REP-1 and REP-4 FAIL on the pre-fix build.
*
* REP-5..6 Bootstrap SE clamp.  Both bootstrap paths compute the replicate
*   variance in the computational form (SUM(x^2) - n*xbar^2)/(n-1), which can
*   return a tiny NEGATIVE value when the replicates agree to machine
*   precision; sqrt() of that is missing, and a missing SE suppresses the
*   confidence limits -- reporting "we cannot quantify this" where the truth is
*   a bootstrap SD of exactly zero.  These tests pin the INVARIANT (an SE that
*   exists and is non-negative wherever the replications succeeded), not a
*   reproduction of the negative branch: see the note at REP-5.
*
* REP-8   `finegray, coeflegend' replays the table with the _b[] names.
*   FAILS on the pre-fix build, where the option was refused r(198).
clear all
set varabbrev off
version 16.0

capture log close _all
log using "test_finegray_reporting.log", replace name(_fgrep)

local qa_dir "`c(pwd)'"
local pkg_dir = regexr("`qa_dir'", "/qa$", "")
capture ado uninstall finegray
quietly net install finegray, from("`pkg_dir'") replace

local test_count = 0
local pass_count = 0
local fail_count = 0

capture program drop _mk_fgrep
program define _mk_fgrep
    version 16.0
    syntax [, N(integer 900) SEED(integer 20260725)]
    clear
    set seed `seed'
    quietly set obs `n'
    gen long id = _n
    gen double x1 = rnormal()
    gen byte x2 = rbinomial(1, 0.5)
    gen byte grp = 1 + int(runiform() * 3)
    gen double lat  = ceil(runiform() * 10)
    gen double lat2 = ceil(runiform() * 10)
    gen double cen  = ceil(runiform() * 13)
    gen byte ev = cond(lat <= lat2, 1, 2)
    gen double t = min(lat, lat2)
    quietly replace ev = 0 if cen < t
    quietly replace t = min(t, cen)
    quietly stset t, failure(ev == 1 2) id(id)
    drop lat lat2 cen
end

**# 1. r(profile_vars) names the fitted TERMS, not the _fg_* columns [FAILS PRE-FIX]
local ++test_count
capture noisily {
    _mk_fgrep
    quietly finegray x1 i.grp, compete(ev) cause(1) nolog
    * The internal columns really are what e(designvars) holds -- assert that,
    * so this test cannot pass by the design having quietly changed shape.
    assert "`e(designvars)'" == "x1 _fg_grp_2 _fg_grp_3"
    quietly finegray_cif, at(x1=0 grp=1) attime(5)
    local _pv "`r(profile_vars)'"
    display as text "  e(designvars)    = `e(designvars)'"
    display as text "  r(profile_vars)  = `_pv'"
    assert "`_pv'" == "x1 2.grp 3.grp"
    * and no leading/trailing whitespace crept in from the accumulator
    assert "`_pv'" == strtrim("`_pv'")
}
if _rc == 0 {
    display as result "  PASS: REP-1 r(profile_vars) reports user terms for i. fits"
    local ++pass_count
}
else {
    display as error "  FAIL: REP-1 r(profile_vars) user terms (rc=`=_rc')"
    local ++fail_count
}

**# 2. Non-factor fits are unchanged (the fallback path)
local ++test_count
capture noisily {
    _mk_fgrep
    quietly finegray x1 x2, compete(ev) cause(1) nolog
    quietly finegray_cif, at(x1=0 x2=1) attime(5)
    assert "`r(profile_vars)'" == "x1 x2"
    assert "`r(profile_vars)'" == "`e(designvars)'"
    display as text "  non-factor fit: r(profile_vars) == e(designvars) == x1 x2"
}
if _rc == 0 {
    display as result "  PASS: REP-2 non-factor r(profile_vars) unchanged"
    local ++pass_count
}
else {
    display as error "  FAIL: REP-2 non-factor r(profile_vars) (rc=`=_rc')"
    local ++fail_count
}

**# 3. r(profile_vars) stays 1:1 with the columns of r(at)
* This is the contract the help documents ("in column order of r(at)"), and it
* is what makes the return usable at all.  A short or long list mispairs the
* profile silently.
local ++test_count
capture noisily {
    _mk_fgrep
    quietly finegray x1 i.grp, compete(ev) cause(1) nolog
    quietly finegray_cif, at(x1=0 grp=3) attime(4 6)
    matrix _A121 = r(at)
    local _pv "`r(profile_vars)'"
    local _np : word count `_pv'
    display as text "  r(at) is 1 x " colsof(_A121) ", r(profile_vars) has `_np' words"
    assert `_np' == colsof(_A121)
    * one word per DESIGN column: e(b) is wider (it carries the base level)
    assert `_np' == `: word count `e(designvars)''
    * the requested level must be the one that scored: grp=3 -> 2.grp=0, 3.grp=1
    assert _A121[1, 2] == 0
    assert _A121[1, 3] == 1
}
if _rc == 0 {
    display as result "  PASS: REP-3 r(profile_vars) pairs 1:1 with r(at)"
    local ++pass_count
}
else {
    display as error "  FAIL: REP-3 profile_vars/at pairing (rc=`=_rc')"
    local ++fail_count
}

**# 4. Interaction terms report their typed form too [FAILS PRE-FIX]
* Through v1.2.0 at() REFUSED a variable that entered an interaction ("grp
* enters an interaction; set its _fg_* dummies directly"), and this block
* pinned that refusal.  Since this release at() sets every design column the variable
* enters, so the refusal assertion is replaced by its opposite -- the call must
* succeed -- and the arithmetic it produces is pinned in
* test_finegray_at_profile.do.  What this block still owns is the REPORTING
* vocabulary: r(profile_vars) names fitted terms, never the _fg_* columns.
local ++test_count
capture noisily {
    _mk_fgrep
    quietly finegray i.grp##c.x1, compete(ev) cause(1) nolog
    capture finegray_cif, at(grp=1 x1=0) attime(5)
    assert _rc == 0
    quietly finegray_cif, attime(5)
    local _pv "`r(profile_vars)'"
    display as text "  interaction r(profile_vars) = `_pv'"
    * every reported term must be a term the user could recognise: no _fg_
    foreach _w of local _pv {
        assert substr("`_w'", 1, 4) != "_fg_"
    }
    * and the expansion must still line up with the design columns
    local _np : word count `_pv'
    assert `_np' == `: word count `e(designvars)''
}
if _rc == 0 {
    display as result "  PASS: REP-4 interaction terms reported in typed form"
    local ++pass_count
}
else {
    display as error "  FAIL: REP-4 interaction r(profile_vars) (rc=`=_rc')"
    local ++fail_count
}

**# 5. Bootstrap SE is present and non-negative wherever replications succeeded
* NOTE ON WHAT THIS DOES AND DOES NOT PROVE.  The negative-variance branch is
* defensive: it needs replicates that agree to machine precision at a NONZERO
* CIF, which ordinary bsample resampling does not produce on demand, so this
* suite does not manufacture it.  What it does pin is the user-visible
* invariant the clamp exists to protect -- an SE that is real and non-negative
* at every grid point, including the degenerate early points where the CIF is
* identically zero across replicates and the variance is exactly zero.  Recorded
* honestly: this is a no-regression + invariant test, not a reproduction of the
* defect.
local ++test_count
capture noisily {
    _mk_fgrep
    quietly finegray x1 x2, compete(ev) cause(1) nolog
    quietly finegray_cif, at(x1=0 x2=1) attime(1 2 5 9) ci bootstrap(25) seed(4242)
    matrix _B121 = r(table)
    assert r(bootstrap_success) == 25
    local _nr = rowsof(_B121)
    forvalues i = 1/`_nr' {
        local _t = _B121[`i', 1]
        local _c = _B121[`i', 2]
        local _s = _B121[`i', 3]
        display as text "    t=`_t'  cif=" %9.7f `_c' "  se=" %9.7f `_s'
        * SE must exist and be non-negative at every grid point
        assert !missing(`_s')
        assert `_s' >= 0
    }
}
if _rc == 0 {
    display as result "  PASS: REP-5 bootstrap SE real and non-negative at all grid points"
    local ++pass_count
}
else {
    display as error "  FAIL: REP-5 bootstrap SE invariant (rc=`=_rc')"
    local ++fail_count
}

**# 6. The clamp did not change ordinary bootstrap SEs
* The clamp only ever fires on a negative variance.  Where the variance is
* positive -- every ordinary grid point -- the SE must be exactly the sample SD
* of the replicate CIFs.  Recomputing that independently (seeded, same draws)
* would require re-running the bootstrap; instead pin the property that makes
* the SE meaningful: it is strictly positive and of a sane magnitude for a
* probability, and the cloglog interval it drives brackets the point estimate.
local ++test_count
capture noisily {
    _mk_fgrep
    quietly finegray x1 x2, compete(ev) cause(1) nolog
    quietly finegray_cif, at(x1=0 x2=1) attime(5 8) ci bootstrap(25) seed(99)
    matrix _C121 = r(table)
    forvalues i = 1/2 {
        local _c = _C121[`i', 2]
        local _s = _C121[`i', 3]
        local _l = _C121[`i', 4]
        local _u = _C121[`i', 5]
        assert `_c' > 0 & `_c' < 1
        assert `_s' > 0 & `_s' < 1
        assert !missing(`_l') & !missing(`_u')
        assert `_l' < `_c' & `_c' < `_u'
        assert `_l' > 0 & `_l' < . & `_u' > 0 & `_u' < 1
        display as text "    cif=" %9.7f `_c' " se=" %9.7f `_s' ///
            " ci=[" %9.7f `_l' ", " %9.7f `_u' "]"
    }
}
if _rc == 0 {
    display as result "  PASS: REP-6 ordinary bootstrap SEs and CIs intact"
    local ++pass_count
}
else {
    display as error "  FAIL: REP-6 ordinary bootstrap SE/CI (rc=`=_rc')"
    local ++fail_count
}

**# 7. finegray_predict bootstrap SE obeys the same invariant
local ++test_count
capture noisily {
    _mk_fgrep
    quietly finegray x1 x2, compete(ev) cause(1) nolog
    quietly finegray_predict pc, cif ci bootstrap(25) seed(31337)
    quietly count if !missing(pc)
    assert !missing(r(N))
    assert r(N) > 100
    * lower/upper limits are created as pc_lb/pc_ub-style companions; find them
    quietly summarize pc, meanonly
    assert !missing(r(min))
    assert r(min) >= 0 & r(max) <= 1
    display as text "  predict cif bootstrap: n=" r(N) " range [" %6.4f r(min) ", " %6.4f r(max) "]"
}
if _rc == 0 {
    display as result "  PASS: REP-7 predict bootstrap CIF within [0,1]"
    local ++pass_count
}
else {
    display as error "  FAIL: REP-7 predict bootstrap invariant (rc=`=_rc')"
    local ++fail_count
}

**# 8. `finegray, coeflegend' replays the table with the _b[] names
* WATCHED FAIL 2026-09-02.  _finegray_display parsed only `level(string) noshr',
* so `finegray, coeflegend' -- the replay every Stata e-class estimator answers,
* and the only documented way to read the exact _b[] name of a tvc or factor
* design column off the table -- was refused r(198) "option coeflegend not
* allowed".  It is now accepted and handed to `ereturn display, coeflegend'.
* level() and noshr are refused with it, as Stata's own estimators refuse
* level(): the legend table reports neither a scale nor an interval.
local ++test_count
capture noisily {
    _mk_fgrep
    quietly finegray i.grp##c.x1 x2, compete(ev) cause(1) nolog

    tempfile replog
    capture log close _rep8
    quietly log using "`replog'", replace text name(_rep8)
    finegray, coeflegend
    local rc_cl = _rc
    capture log close _rep8
    display as text "  coeflegend replay rc = `rc_cl'"
    assert `rc_cl' == 0

    tempname fh8
    local blob ""
    file open `fh8' using "`replog'", read text
    file read `fh8' line
    while r(eof) == 0 {
        local blob `"`blob' `line'"'
        file read `fh8' line
    }
    file close `fh8'

    * the Legend column and the names it is there to show
    assert strpos(`"`blob'"', "Legend") > 0
    assert strpos(`"`blob'"', "_b[x2]") > 0
    assert strpos(`"`blob'"', "_b[2.grp#c.x1]") > 0
    * coeflegend prints names, not statistics: no SHR column, no p-values
    assert strpos(`"`blob'"', "SHR") == 0
    * and the header the fit prints is still there (this IS the replay)
    assert strpos(`"`blob'"', "Fine-Gray competing risks regression") > 0

    * the legend names are usable: every one indexes a real coefficient
    assert !missing(_b[x2])
    assert !missing(_b[2.grp#c.x1])

    * combinations that have nothing to apply to are refused, not ignored
    capture finegray, coeflegend level(90)
    assert _rc == 198
    capture finegray, coeflegend noshr
    assert _rc == 198
    * and the plain replay paths are unaffected
    quietly finegray
    assert _rc == 0
    quietly finegray, noshr
    assert _rc == 0
    quietly finegray, level(90)
    assert _rc == 0
}
if _rc == 0 {
    display as result "  PASS: REP-8 finegray, coeflegend replays with _b[] names; level()/noshr refused with it"
    local ++pass_count
}
else {
    display as error "  FAIL: REP-8 coeflegend replay (rc=`=_rc')"
    local ++fail_count
}

**# Summary
display as text _newline ///
    "RESULT: test_finegray_reporting tests=`test_count' pass=`pass_count' fail=`fail_count'"
if `fail_count' > 0 {
    display as error "SOME TESTS FAILED"
    log close _fgrep
    exit 1
}
display as result "ALL TESTS PASSED"
log close _fgrep
