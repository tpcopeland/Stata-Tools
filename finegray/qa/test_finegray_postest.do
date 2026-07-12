* test_finegray_postest.do
* Phases 5-7: post-estimation data contract, CIF/predict output, PH test.
*
* Every test here targets a path that returned rc 0 with a WRONG answer, not a
* crash. That is the common thread: none of these defects could be found by
* running the suite and checking for errors.
*
*   FG-H02  factor terms were re-expanded on the CURRENT data and paired with
*           e(b) POSITIONALLY. Fit on i.grp over {1,2,3}, shift the data to
*           {2,3,4}: fvexpand yields three terms again, so the level-2
*           coefficient was applied to level 3 -- rc 0. And plain `predict xb'
*           never validated the data at all (only ci/schoenfeld did).
*   FG-H03  the estimation-data signature covered the raw variables but not the
*           package-owned _fg_* design columns that post-estimation reads back.
*           Flipping _fg_grp_2 moved the CIF from 0.18367237 to 0.18251435 at rc 0.
*   FG-H11  a confidence limit that could not be computed was replaced by the
*           POINT ESTIMATE -- a zero-width interval presented as a real one. And
*           r(table) carried lci = uci = cif even when ci was never requested.
*   FG-M01  e(basehaz) emitted one row per cause EVENT, not per unique event
*           TIME: 50 tied events -> 50 rows, 1 unique time.
*   FG-M02  the CIF grid stride stepped OVER the final basehaz row whenever the
*           row count had the wrong parity (402 rows, step 2 -> last point 401),
*           silently dropping the terminal time -- the CIF's plateau.
*   FG-M03  every cause event at one time -> constant time function -> missing
*           rho -> missing chi2 and p, reported at rc 0 as a completed test.

clear all
set varabbrev off
version 16.0

capture log close _all
log using "test_finegray_postest.log", replace name(_pe)

local qa_dir "`c(pwd)'"
local pkg_dir = subinstr("`qa_dir'", "/qa", "", 1)
capture ado uninstall finegray
quietly net install finegray, from("`pkg_dir'") replace

local test_count = 0
local pass_count = 0
local fail_count = 0

* Factor-variable competing-risks data with grp support {1,2,3}.
capture program drop _mk_fv_pe
program define _mk_fv_pe
    clear
    set seed 5150
    quietly set obs 600
    gen long id = _n
    gen byte grp = 1 + mod(_n, 3)
    gen double x = rnormal()
    gen double t = ceil(8 * runiform())
    gen byte ev = cond(runiform() < .45, 1, cond(runiform() < .5, 2, 0))
    quietly stset t, failure(ev) id(id)
end

**# 1. FG-H02: a factor level shift must ERROR, not remap positionally
local ++test_count
capture noisily {
    _mk_fv_pe
    quietly finegray i.grp x, compete(ev) cause(1) nolog

    * shift support {1,2,3} -> {2,3,4}: same NUMBER of terms, different levels
    quietly replace grp = grp + 1
    capture finegray_predict h02xb, xb
    display as text "  predict xb after level shift rc = `=_rc' (v1.1.4: 0)"
    assert _rc == 459
}
if _rc == 0 {
    display as result "  PASS: FG-H02 level shift on estimation data errors"
    local ++pass_count
}
else {
    display as error "  FAIL: FG-H02 level shift (rc=`=_rc')"
    local ++fail_count
}

**# 2. FG-H02: an unfitted level on NEW data must ERROR, not collapse to base
* This is the sharper half. Plain `predict xb' is documented to work on new data,
* so there is no estimation sample to compare against. An observation at a level
* the fit never saw has NO coefficient; scoring it sets every dummy to zero,
* which silently treats it as the base category and returns a fabricated number.
local ++test_count
capture noisily {
    _mk_fv_pe
    quietly finegray i.grp x, compete(ev) cause(1) nolog

    preserve
    clear
    set obs 6
    gen byte grp = 2 + mod(_n, 3)      // levels {2,3,4}; 4 was never fitted
    gen double x = 0
    capture finegray_predict newxb, xb
    display as text "  predict xb on new data with unfitted level rc = `=_rc' (v1.1.4: 0)"
    assert _rc == 459
    restore
}
if _rc == 0 {
    display as result "  PASS: FG-H02 unfitted level on new data errors"
    local ++pass_count
}
else {
    display as error "  FAIL: FG-H02 unfitted level on new data (rc=`=_rc')"
    local ++fail_count
}

**# 3. FG-H02: the guard must not over-fire -- valid new data still scores, and
* the scores must be SEMANTICALLY right (level value, not position)
local ++test_count
capture noisily {
    _mk_fv_pe
    quietly finegray i.grp x, compete(ev) cause(1) nolog
    matrix b_fit = e(b)

    * independent oracle: xb built by hand from the coefficients and the level
    * VALUES. This is what "aligned by value" has to mean.
    capture noisily finegray_predict fullxb, xb
    assert _rc == 0
    gen double _oracle = b_fit[1,1] * (grp == 2) + b_fit[1,2] * (grp == 3) ///
        + b_fit[1,3] * x
    gen double _diff = abs(fullxb - _oracle)
    quietly summarize _diff
    display as text "  max |xb - hand-built oracle| = " %10.2e r(max)
    assert r(max) < 1e-6

    * new data restricted to FITTED levels must still score
    preserve
    clear
    set obs 3
    gen byte grp = _n                  // {1,2,3}: all fitted
    gen double x = 0
    capture noisily finegray_predict newxb, xb
    assert _rc == 0
    assert !missing(newxb[1]) & !missing(newxb[3])
    restore

    * a subsample of the estimation data must still score
    capture noisily finegray_predict subxb if grp == 1, xb
    assert _rc == 0
    quietly count if !missing(subxb) & grp != 1
    assert r(N) == 0                   // scored only where asked
    quietly count if !missing(subxb) & grp == 1
    assert r(N) > 0
}
if _rc == 0 {
    display as result "  PASS: FG-H02 valid predictions unaffected and semantically correct"
    local ++pass_count
}
else {
    display as error "  FAIL: FG-H02 over-fires on valid prediction (rc=`=_rc')"
    local ++fail_count
}

**# 4. FG-H03: a tampered _fg_* design column must ERROR
local ++test_count
capture noisily {
    _mk_fv_pe
    quietly finegray i.grp x, compete(ev) cause(1) nolog
    quietly finegray_cif, attime(3) nograph
    matrix t_before = r(table)

    * flip a package-owned design column: the raw data are untouched, so a
    * signature over raw variables alone cannot see this
    quietly replace _fg_grp_2 = 1 - _fg_grp_2

    * finegray_cif and finegray_phtest READ the _fg_* columns by name, so a
    * tampered column silently changes their answer. They must refuse.
    capture finegray_cif, attime(3) nograph
    display as text "  finegray_cif after _fg_ tamper rc = `=_rc' (v1.1.4: 0, CIF moved)"
    assert _rc == 459
    capture finegray_phtest
    assert _rc == 459

    * finegray_predict does NOT read them -- it rebuilds the design from the raw
    * factor variables -- so the tampered column cannot affect xb, and refusing
    * would be wrong. Assert it still runs AND still gives the right answer.
    matrix b_fit = e(b)
    capture noisily finegray_predict h03xb, xb
    assert _rc == 0
    gen double _orc3 = b_fit[1,1]*(grp==2) + b_fit[1,2]*(grp==3) + b_fit[1,3]*x
    gen double _d3 = abs(h03xb - _orc3)
    quietly summarize _d3
    display as text "  predict xb is immune to the tamper: max|xb - oracle| = " %10.2e r(max)
    assert r(max) < 1e-6
}
if _rc == 0 {
    display as result "  PASS: FG-H03 tampered _fg_* refused where it is read, immune where it is rebuilt"
    local ++pass_count
}
else {
    display as error "  FAIL: FG-H03 _fg_* tamper (rc=`=_rc')"
    local ++fail_count
}

**# 4b. FG-H03: DROPPING _fg_* columns is still supported (they get rebuilt)
* The signature must distinguish "absent" from "tampered". Putting _fg_* into the
* data signature would have made a supported `drop _fg_*' a hard error.
local ++test_count
capture noisily {
    _mk_fv_pe
    quietly finegray i.grp x, compete(ev) cause(1) nolog
    cap drop _fg_*
    capture noisily finegray_predict d1, xb
    assert _rc == 0
    capture noisily finegray_phtest
    assert _rc == 0
}
if _rc == 0 {
    display as result "  PASS: FG-H03 dropped _fg_* columns are rebuilt, not rejected"
    local ++pass_count
}
else {
    display as error "  FAIL: FG-H03 dropped _fg_* rejected (rc=`=_rc')"
    local ++fail_count
}

**# 5. FG-M01: e(basehaz) has one row per unique cause-event TIME
local ++test_count
capture noisily {
    clear
    set seed 31
    quietly set obs 500
    gen long id = _n
    gen double x = rnormal()
    gen byte t = 1 + floor(5 * runiform())     // only 5 possible times: heavy ties
    gen byte ev = cond(runiform() < .5, 1, cond(runiform() < .5, 2, 0))
    quietly stset t, failure(ev) id(id)
    quietly finegray x, compete(ev) cause(1) nolog

    * there must genuinely BE ties, or this test proves nothing
    quietly count if ev == 1
    local n_events = r(N)
    quietly levelsof t if ev == 1, local(evt)
    local n_times : word count `evt'
    display as text "  `n_events' cause events across `n_times' distinct times"
    assert `n_events' > `n_times' + 10

    matrix bh = e(basehaz)
    local nrow = rowsof(bh)
    mata: st_local("nuniq", ///
        strofreal(rows(uniqrows(st_matrix("e(basehaz)")[., 1]))))
    display as text "  e(basehaz): `nrow' rows, `nuniq' unique times (v1.1.4: rows = events)"
    assert `nrow' == `nuniq'
    assert `nrow' == `n_times'

    * and it must still be a valid cumulative hazard: nondecreasing, nonnegative
    local prev = -1
    forvalues r = 1/`nrow' {
        assert bh[`r',2] >= 0
        assert bh[`r',2] >= `prev'
        local prev = bh[`r',2]
    }
}
if _rc == 0 {
    display as result "  PASS: FG-M01 e(basehaz) times are unique and monotone"
    local ++pass_count
}
else {
    display as error "  FAIL: FG-M01 e(basehaz) uniqueness (rc=`=_rc')"
    local ++fail_count
}

**# 6. FG-M02: the terminal time survives for BOTH parities of the row count
* The defect is CONDITIONAL on parity, so testing one dataset proves nothing:
* 481 basehaz rows happened to retain the terminal point while 402 dropped it.
* Both cases must be exercised.
local ++test_count
capture noisily {
    local n_even = 0
    local n_odd = 0
    foreach n in 900 901 {
        clear
        set seed 77
        quietly set obs `n'
        gen long id = _n
        gen double x = rnormal()
        gen double t = runiform()      // continuous: ~one event per time
        gen byte ev = cond(runiform() < .55, 1, cond(runiform() < .5, 2, 0))
        quietly stset t, failure(ev) id(id)
        quietly finegray x, compete(ev) cause(1) nolog

        matrix bh = e(basehaz)
        local nbh = rowsof(bh)
        local term = bh[`nbh', 1]
        local parity = mod(`nbh', 2)
        if `parity' == 0 local n_even = 1
        if `parity' == 1 local n_odd = 1

        * the thinning stride must be > 1, or the bug cannot arise
        assert `nbh' > 400

        quietly finegray_cif, nograph
        matrix T = r(table)
        local ng = rowsof(T)
        local lastgrid = T[`ng', 1]
        display as text "  nbh=`nbh' (parity `parity'): terminal=" %8.6f `term' ///
            "  last grid=" %8.6f `lastgrid'
        assert abs(`term' - `lastgrid') < 1e-12
    }
    * both parities must actually have been hit
    assert `n_even' == 1
    assert `n_odd' == 1
}
if _rc == 0 {
    display as result "  PASS: FG-M02 terminal time retained for even and odd row counts"
    local ++pass_count
}
else {
    display as error "  FAIL: FG-M02 terminal time dropped (rc=`=_rc')"
    local ++fail_count
}

**# 7. FG-H11: no zero-width confidence intervals, ever
local ++test_count
capture noisily {
    clear
    set seed 9
    quietly set obs 400
    gen long id = _n
    gen double x = rnormal()
    gen double t = runiform()
    gen byte ev = cond(runiform() < .5, 1, cond(runiform() < .5, 2, 0))
    quietly stset t, failure(ev) id(id)
    quietly finegray x, compete(ev) cause(1) nolog

    * (a) without ci, r(table) must NOT carry limits at all
    quietly finegray_cif, attime(.2 .5 .8) nograph
    matrix T0 = r(table)
    forvalues r = 1/3 {
        assert missing(T0[`r',4])
        assert missing(T0[`r',5])
    }
    display as text "  no-ci: lci/uci missing (v1.1.4: lci = uci = cif)"

    * (b) with ci, every reported interval must have real width
    quietly finegray_cif, attime(.2 .5 .8) ci nograph
    matrix T1 = r(table)
    forvalues r = 1/3 {
        local cifv = T1[`r',2]
        local lo   = T1[`r',4]
        local hi   = T1[`r',5]
        assert !missing(`lo') & !missing(`hi')
        assert `hi' > `lo'                 // strictly positive width
        assert `lo' <= `cifv' & `cifv' <= `hi'
        assert `lo' >= 0 & `hi' <= 1
    }
    display as text "  with-ci: all intervals have positive width and bracket the CIF"

    * (c) finegray_predict must not collapse a missing limit onto the point either
    quietly finegray_predict pc, cif ci
    quietly count if !missing(pc_lci) & !missing(pc_uci) & pc_lci == pc_uci
    display as text "  finegray_predict zero-width intervals = `r(N)'"
    assert r(N) == 0
}
if _rc == 0 {
    display as result "  PASS: FG-H11 no zero-width CIs; limits absent when not requested"
    local ++pass_count
}
else {
    display as error "  FAIL: FG-H11 zero-width CI (rc=`=_rc')"
    local ++fail_count
}

**# 8. FG-M03: a PH test with no time variation must ERROR
local ++test_count
capture noisily {
    clear
    set seed 12
    quietly set obs 300
    gen long id = _n
    gen double x = rnormal()
    gen double t = 5
    gen byte ev = 1
    quietly replace ev = 2 if _n > 100
    quietly replace ev = 0 if _n > 200
    * every CAUSE event sits at t = 5; competing/censored spread out after
    quietly replace t = 5 + runiform() if ev != 1
    quietly stset t, failure(ev) id(id)
    quietly finegray x, compete(ev) cause(1) nolog

    capture finegray_phtest
    display as text "  phtest, all cause events at one time rc = `=_rc' (v1.1.4: 0 + missing chi2/p)"
    assert _rc == 459
}
if _rc == 0 {
    display as result "  PASS: FG-M03 degenerate PH test errors instead of reporting blanks"
    local ++pass_count
}
else {
    display as error "  FAIL: FG-M03 degenerate PH test (rc=`=_rc')"
    local ++fail_count
}

**# 9. FG-M03: the guard is not blanket -- a well-posed PH test still runs
local ++test_count
capture noisily {
    clear
    set seed 3
    quietly set obs 400
    gen long id = _n
    gen double x = rnormal()
    gen double t = runiform()
    gen byte ev = cond(runiform() < .5, 1, cond(runiform() < .5, 2, 0))
    quietly stset t, failure(ev) id(id)
    quietly finegray x, compete(ev) cause(1) nolog

    capture noisily finegray_phtest
    assert _rc == 0
    assert !missing(r(chi2))
    assert !missing(r(p))
    assert r(chi2) >= 0
    assert r(p) >= 0 & r(p) <= 1
    display as text "  chi2 = " %8.4f r(chi2) "  p = " %6.4f r(p)
}
if _rc == 0 {
    display as result "  PASS: FG-M03 well-posed PH test still reports real statistics"
    local ++pass_count
}
else {
    display as error "  FAIL: FG-M03 well-posed PH test (rc=`=_rc')"
    local ++fail_count
}

**# Summary
display as text _newline ///
    "RESULT: test_finegray_postest tests=`test_count' pass=`pass_count' fail=`fail_count'"
if `fail_count' > 0 {
    display as error "SOME TESTS FAILED"
    log close _pe
    exit 1
}
display as result "ALL TESTS PASSED"
log close _pe
