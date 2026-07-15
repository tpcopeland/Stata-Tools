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
    * basehaz: this test asserts properties OF e(basehaz), so it must ask for it
    quietly finegray x, compete(ev) cause(1) nolog basehaz

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
        * basehaz: the terminal-time assertion is read off the matrix itself
        quietly finegray x, compete(ev) cause(1) nolog basehaz

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

**# FG-B01: postestimation is unchanged when e(basehaz) is not posted
* e(basehaz) is opt-in because materialising its K ~ n/2 rows as a Stata matrix
* is O(K^2).  The claim that makes that safe is that postestimation never needed
* the MATRIX, only the VALUES -- finegray_cif and finegray_predict rebuild the
* same curve in Mata.  This asserts that claim directly: fit twice, once with the
* matrix and once without, and require the CIF and the predictions to agree
* EXACTLY.  A rebuild that drifted (wrong weights, wrong strata, a stale e(b))
* would show up here and nowhere else -- the default path posts no matrix to
* compare against, so nothing else in the suite can see it.
local ++test_count
capture noisily {
    clear
    set seed 55501
    quietly set obs 2500
    gen long id = _n
    gen byte z1 = runiform() < 0.5
    gen double z2 = rnormal()
    gen double t0 = 0.2 * runiform()
    gen double t  = t0 + rexponential(1)
    gen byte ev = cond(runiform() < .5, 1, cond(runiform() < .5, 2, 0))
    gen int wg = 1 + floor(2 * runiform())
    quietly stset t, failure(ev) id(id) enter(time t0)

    * with the matrix
    quietly finegray z1 z2, compete(ev) cause(1) truncstrata(wg) nolog basehaz
    confirm matrix e(basehaz)
    quietly finegray_predict cif_m, cif
    quietly finegray_predict bch_m, basecshazard
    quietly finegray_cif, at(z1=1 z2=0) attime(1 2 3)
    matrix Cm = r(table)

    * without it (the default): every number must be identical
    quietly finegray z1 z2, compete(ev) cause(1) truncstrata(wg) nolog
    capture confirm matrix e(basehaz)
    assert _rc != 0
    quietly finegray_predict cif_r, cif
    quietly finegray_predict bch_r, basecshazard
    quietly finegray_cif, at(z1=1 z2=0) attime(1 2 3)
    matrix Cr = r(table)

    gen double _dcif = abs(cif_m - cif_r)
    gen double _dbch = abs(bch_m - bch_r)
    quietly summarize _dcif
    assert r(max) == 0
    quietly summarize _dbch
    assert r(max) == 0
    forvalues i = 1/`=rowsof(Cm)' {
        forvalues j = 1/`=colsof(Cm)' {
            assert Cm[`i',`j'] == Cr[`i',`j'] | ///
                (missing(Cm[`i',`j']) & missing(Cr[`i',`j']))
        }
    }
    display as text "  rebuilt baseline reproduces cif/predict exactly (no e(basehaz))"
}
if _rc == 0 {
    display as result "  PASS: FG-B01 postestimation identical without e(basehaz)"
    local ++pass_count
}
else {
    display as error "  FAIL: FG-B01 postestimation without e(basehaz) (rc=`=_rc')"
    local ++fail_count
}

**# FG-B02: predict, basecshazard IS the baseline cumulative subhazard
* stcrreg posts no baseline matrix and hands the curve over as a variable
* (predict newvar, basecshazard).  finegray now offers the same idiom.  Pin it to
* the definition rather than to itself: step e(basehaz) onto each observation's
* analysis time by hand and require an exact match, and require the curve to be
* a valid cumulative hazard (nonnegative, nondecreasing in t).
local ++test_count
capture noisily {
    clear
    set seed 55502
    quietly set obs 1200
    gen long id = _n
    gen double x = rnormal()
    gen double t = runiform()
    gen byte ev = cond(runiform() < .5, 1, cond(runiform() < .5, 2, 0))
    quietly stset t, failure(ev) id(id)
    quietly finegray x, compete(ev) cause(1) nolog basehaz

    * double, not the float that `syntax newvarname' defaults to via set type:
    * a float result carries ~5e-8 of storage noise (this is why T126 in
    * test_finegray tolerates 1e-6), which would hide a real step-function bug of
    * the same size.  Ask for double and hold the reconstruction to 1e-12.
    quietly finegray_predict double bch, basecshazard

    * independent reconstruction: largest cumhazard among basehaz times <= _t
    matrix bh = e(basehaz)
    local nbh = rowsof(bh)
    gen double bch_ref = 0
    forvalues r = 1/`nbh' {
        quietly replace bch_ref = bh[`r', 2] if _t >= bh[`r', 1]
    }
    gen double _bdiff = abs(bch - bch_ref)
    quietly summarize _bdiff
    assert r(max) < 1e-12

    * a cumulative hazard: nonnegative and nondecreasing in time
    quietly summarize bch
    assert r(min) >= 0
    sort _t
    quietly gen double _lag = bch[_n-1]
    * guard the missings: an obs outside the predict sample has bch = ., and
    * `. >= . - 1e-12' is FALSE, so an unguarded assert fails on a curve that is
    * perfectly monotone
    assert bch >= _lag - 1e-12 if _n > 1 & !missing(bch) & !missing(_lag)
    display as text "  basecshazard matches the e(basehaz) step function exactly"
}
if _rc == 0 {
    display as result "  PASS: FG-B02 predict, basecshazard = baseline cum. subhazard"
    local ++pass_count
}
else {
    display as error "  FAIL: FG-B02 basecshazard (rc=`=_rc')"
    local ++fail_count
}

**# FG-B03: basecshazard refuses the CI options it cannot honour
* ci/bootstrap() are CIF-only.  Parsed-but-ignored options are the silent-no-op
* class: rc 0, a bare point estimate, and the user believing they got a band.
local ++test_count
capture noisily {
    clear
    set seed 55503
    quietly set obs 500
    gen long id = _n
    gen double x = rnormal()
    gen double t = runiform()
    gen byte ev = cond(runiform() < .5, 1, cond(runiform() < .5, 2, 0))
    quietly stset t, failure(ev) id(id)
    quietly finegray x, compete(ev) cause(1) nolog

    capture finegray_predict b1, basecshazard ci
    assert _rc == 198
    capture finegray_predict b2, basecshazard bootstrap(10)
    assert _rc == 198
    capture finegray_predict b3, basecshazard cif
    assert _rc == 198
}
if _rc == 0 {
    display as result "  PASS: FG-B03 basecshazard rejects ci/bootstrap/cif"
    local ++pass_count
}
else {
    display as error "  FAIL: FG-B03 basecshazard option guards (rc=`=_rc')"
    local ++fail_count
}

**# FG-B04: predict, cif on NEW DATA, with no e(basehaz) and no estimation sample
* This is the case that the opt-in e(basehaz) change nearly broke, and it is a
* DOCUMENTED workflow: drop the estimation data, type a fresh covariate profile,
* predict.  There is then nothing to rebuild the baseline FROM -- the old code
* only survived because it read a Stata matrix out of e(), which outlives
* `drop _all'.  The baseline is now cached in Mata (free: a Mata matrix has no
* dimension-name stripe), and this asserts the cache actually carries it across
* the data being destroyed.  Pin it to a value, not just to rc 0: an empty cache
* would give H0 = 0 and a CIF of exactly 0 at rc 0, which is the silent-wrong
* answer this whole design has to avoid.
local ++test_count
capture noisily {
    clear
    set seed 55504
    quietly set obs 2000
    gen long id = _n
    gen double x = rnormal()
    gen double t = runiform()
    gen byte ev = cond(runiform() < .5, 1, cond(runiform() < .5, 2, 0))
    quietly stset t, failure(ev) id(id)
    quietly finegray x, compete(ev) cause(1) nolog

    * the truth, computed while the estimation data are still here
    gen double t5 = 0.5
    quietly finegray_predict double cif_est, cif timevar(t5)
    local truth = cif_est[1]
    local x1 = x[1]

    * now destroy the estimation data entirely and predict on a fresh profile
    drop _all
    set obs 1
    gen double x = `x1'
    gen double t5 = 0.5
    capture noisily finegray_predict double cif_new, cif timevar(t5)
    assert _rc == 0
    assert !missing(cif_new[1])
    assert cif_new[1] > 0
    assert reldif(cif_new[1], `truth') < 1e-7
    display as text "  new-data CIF = " %9.7f cif_new[1] ///
        " reproduces the in-sample value " %9.7f `truth'
}
if _rc == 0 {
    display as result "  PASS: FG-B04 predict, cif on new data (Mata baseline cache)"
    local ++pass_count
}
else {
    display as error "  FAIL: FG-B04 predict on new data (rc=`=_rc')"
    local ++fail_count
}

**# FG-B05: the cache must never answer for a DIFFERENT fit, and must fail loudly
* A cache keyed to nothing is a stale-state bug waiting to happen: predicting from
* the PREVIOUS fit's baseline at rc 0 is exactly the silent-wrong-answer class.
* Two halves: (a) after a second fit, prediction uses the SECOND fit's baseline;
* (b) when the cache is wiped (mata clear) AND the data are gone, the command
* ERRORS rather than guessing.
local ++test_count
capture noisily {
    clear
    set seed 55505
    quietly set obs 2000
    gen long id = _n
    gen double x = rnormal()
    gen double t = runiform()
    gen byte ev = cond(runiform() < .5, 1, cond(runiform() < .5, 2, 0))
    gen double t5 = 0.5
    quietly stset t, failure(ev) id(id)

    * fit A on a HALF sample, fit B on the full sample: different baselines
    quietly finegray x if id <= 1000, compete(ev) cause(1) nolog
    quietly finegray_predict double cifA, cif timevar(t5)
    local seqA `"`e(bh_seq)'"'

    quietly finegray x, compete(ev) cause(1) nolog
    quietly finegray_predict double cifB, cif timevar(t5)
    local seqB `"`e(bh_seq)'"'

    * the receipt must change, and so must the answer
    assert "`seqA'" != "`seqB'"
    quietly summarize cifA
    local mA = r(mean)
    quietly summarize cifB
    local mB = r(mean)
    assert reldif(`mA', `mB') > 1e-8
    display as text "  fit A seq=`seqA' mean CIF=" %8.6f `mA' ///
        "   fit B seq=`seqB' mean CIF=" %8.6f `mB'

    * (b) cache wiped AND estimation data gone -> must ERROR, not guess
    drop _all
    set obs 1
    gen double x = 0
    gen double t5 = 0.5
    mata: mata clear
    capture finegray_predict double cif_dead, cif timevar(t5)
    assert _rc == 459
    display as text "  cache wiped + data gone -> rc 459 (refuses to guess)"
}
if _rc == 0 {
    display as result "  PASS: FG-B05 baseline cache is fit-keyed and fails loudly"
    local ++pass_count
}
else {
    display as error "  FAIL: FG-B05 cache staleness guard (rc=`=_rc')"
    local ++fail_count
}

**# FG-M04: numerically equivalent factor levels in at() must map identically
* The parser used the literal token to build _fg_grp_<level>.  Consequently,
* at(grp=1) worked while equally valid decimal/scientific spellings were
* rejected as unobserved levels.  Compare the profile and CIF, not merely rc.
local ++test_count
capture noisily {
    _mk_fv_pe
    quietly finegray i.grp x, compete(ev) cause(1) nolog

    quietly finegray_cif, at(grp=1 x=0) attime(4) nograph
    matrix T_int = r(table)
    matrix Z_int = r(at)

    quietly finegray_cif, at(grp=1.0 x=0) attime(4) nograph
    matrix T_dec = r(table)
    matrix Z_dec = r(at)

    quietly finegray_cif, at(grp=1e0 x=0) attime(4) nograph
    matrix T_sci = r(table)
    matrix Z_sci = r(at)

    assert mreldif(T_int, T_dec) < 1e-12
    assert mreldif(Z_int, Z_dec) < 1e-12
    assert mreldif(T_int, T_sci) < 1e-12
    assert mreldif(Z_int, Z_sci) < 1e-12
}
if _rc == 0 {
    display as result "  PASS: FG-M04 decimal/scientific levels match at(grp=1)"
    local ++pass_count
}
else {
    display as error "  FAIL: FG-M04 equivalent factor syntax rejected or remapped (rc=`=_rc')"
    local ++fail_count
}

**# FG-M05: at() must use semantic levels when the internal name is truncated
* A 30-character source name plus a ten-digit level cannot fit in Stata's
* 32-character internal-variable limit.  Matching `_fg_<var>_<level>' therefore
* treated the observed nonbase level as the reference profile at rc 0.  Pin the
* profile and CIF against the explicit generated dummy, including scientific
* spelling of the large level.
local ++test_count
capture noisily {
    _mk_fv_pe
    rename grp this_is_a_very_long_group_name
    replace this_is_a_very_long_group_name = ///
        cond(this_is_a_very_long_group_name == 1, 0, 1000000000)
    quietly finegray i.this_is_a_very_long_group_name x, ///
        compete(ev) cause(1) nolog
    local _dc : word 1 of `e(covariates)'

    quietly finegray_cif, at(`_dc'=1 x=0) attime(4) nograph
    matrix T_direct = r(table)
    matrix Z_direct = r(at)

    quietly finegray_cif, ///
        at(this_is_a_very_long_group_name=1000000000 x=0) ///
        attime(4) nograph
    matrix T_long = r(table)
    matrix Z_long = r(at)

    quietly finegray_cif, ///
        at(this_is_a_very_long_group_name=1e9 x=0) ///
        attime(4) nograph
    matrix T_sci_long = r(table)
    matrix Z_sci_long = r(at)

    assert Z_direct[1,1] == 1
    assert mreldif(T_direct, T_long) < 1e-12
    assert mreldif(Z_direct, Z_long) < 1e-12
    assert mreldif(T_direct, T_sci_long) < 1e-12
    assert mreldif(Z_direct, Z_sci_long) < 1e-12
}
if _rc == 0 {
    display as result "  PASS: FG-M05 long factor name maps by semantic level"
    local ++pass_count
}
else {
    display as error "  FAIL: FG-M05 long factor name remapped at rc 0 (rc=`=_rc')"
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
