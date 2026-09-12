*! test_finegray_v133 Version 1.0.0  2026/09/12
*! Regression tests for the 2026-09-12 finegray review (1.3.3)
*! Author: Timothy P Copeland, Karolinska Institutet
*
* Two findings, both fixed in 1.3.3:
*
*   G  finegray_cif's graph extended EVERY grid's last value out to the end of
*      follow-up as a flat tail.  That is a fact of the estimator only past the
*      curve's last cause event; a timepoints() grid that stops earlier was
*      drawn with a terminal plateau the fit never produced, understating the
*      CIF by every later jump (15 points on the review fixture).  r(table)
*      and saving() were right all along -- the bad row was display-only and
*      removed before export -- so the checks here read the LIVE GRAPH SERSET,
*      the axis the user looks at, not the numeric table.
*
*   V  With strata(), the psi term of `nuisance' dropped the cross-group
*      censoring-influence terms (a censoring group with competing events but
*      no cause events contributed an identically zero psi).  The exact oracle
*      is validation_nuisance_strata_numeric.do (core lane); this quick-lane
*      arm pins e(V) on the review fixture to the value that oracle certifies
*      and refuses the pre-fix value, so the quick lane cannot go green on the
*      old form.

clear all
set varabbrev off
version 16.0

capture log close _all
log using "test_finegray_v133.log", replace name(_fg133)

local qa_dir "`c(pwd)'"
local pkg_dir = regexr("`qa_dir'", "/qa$", "")
capture ado uninstall finegray
quietly net install finegray, from("`pkg_dir'") replace

local test_count = 0
local pass_count = 0
local fail_count = 0

capture program drop _fg133_result
program define _fg133_result, rclass
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

* Review fixture for G: 600 subjects on three exit times (.5, 1, 1.5), every
* status at every time, so the CIF jumps at 1.5 -- after a grid that stops at
* 1.  Forty censored subjects at t = 2 put follow-up PAST the last cause event,
* so the legitimate flat tail (1.5 -> 2) is also exercised.
capture program drop _fg133_griddata
program define _fg133_griddata
    version 16.0
    clear
    set seed 12092026
    quietly set obs 640
    gen long id = _n
    gen double x = rnormal()
    gen byte status = mod(_n, 3)
    gen double t = cond(_n <= 200, .5, cond(_n <= 400, 1, 1.5))
    quietly replace status = 0 if _n > 600
    quietly replace t = 2 if _n > 600
    gen byte ev = status > 0
    quietly stset t, failure(ev) id(id)
end

* The live graph's sersets: twoway keeps one per curve (over()) and, with
* ci, the band variables alongside time and cif.  Enumerate every serset
* that carries a `time' variable and report, per serset k: r(n) sersets,
* r(maxt_k) the last plotted time, r(cif_k) the CIF there, r(nvar_k) the
* variable count.  This reads what twoway was handed -- the axis the user
* looks at -- not what r(table) holds.
capture program drop _fg133_sersets
program define _fg133_sersets, rclass
    version 16.0
    local n = 0
    forvalues k = 0/19 {
        capture serset set `k'
        if _rc continue
        preserve
        serset use, clear
        capture confirm numeric variable time cif
        if _rc {
            restore
            continue
        }
        local ++n
        quietly summarize time, meanonly
        local maxt = r(max)
        quietly summarize cif if time == `maxt', meanonly
        return scalar cif_`n' = r(mean)
        return scalar maxt_`n' = `maxt'
        return scalar nvar_`n' = c(k)
        restore
    }
    return scalar n = `n'
end

**# 1. G: a timepoints() grid that stops before the last cause event ends there
local ++test_count
capture noisily {
    capture restore
    capture graph drop _all
    capture serset drop _all
    _fg133_griddata
    quietly finegray x, compete(status) cause(1) nolog
    quietly finegray_cif, attime(.5 1 1.5)
    matrix T = r(table)
    local cif_1  = T[2, 2]
    local cif_15 = T[3, 2]
    * the fixture can see the defect: the CIF jumps after t = 1
    assert `cif_15' > `cif_1' + 0.05
    quietly finegray_cif, timepoints(.5 1) name(_fg133_g1, replace)
    _fg133_sersets
    assert r(n) == 1
    * no display row beyond the requested grid: the curve stops at t = 1
    assert r(maxt_1) == 1
    assert !missing(r(cif_1), `cif_1')
    assert reldif(r(cif_1), `cif_1') < 1e-10
    graph drop _all
}
local _rc = _rc
_fg133_result `_rc' "G1 timepoints() grid ending before the last cause event is not extended"
local pass_count = `pass_count' + r(pass)
local fail_count = `fail_count' + r(fail)

**# 2. G: the same grid with ci: the bands stop with the curve
local ++test_count
capture noisily {
    capture restore
    capture graph drop _all
    capture serset drop _all
    _fg133_griddata
    quietly finegray x, compete(status) cause(1) nolog
    quietly finegray_cif, timepoints(.5 1) ci name(_fg133_g2, replace)
    _fg133_sersets
    assert r(n) == 1
    * the band variables ride in the same serset, so they end where it ends
    assert r(nvar_1) == 4
    assert r(maxt_1) == 1
    graph drop _all
}
local _rc = _rc
_fg133_result `_rc' "G2 with ci the bands end at the last requested time too"
local pass_count = `pass_count' + r(pass)
local fail_count = `fail_count' + r(fail)

**# 3. G no-regression: a grid that REACHES the last cause event keeps its flat tail
local ++test_count
capture noisily {
    capture restore
    capture graph drop _all
    capture serset drop _all
    _fg133_griddata
    quietly finegray x, compete(status) cause(1) nolog
    quietly finegray_cif, attime(1.5)
    matrix T = r(table)
    local cif_15 = T[1, 2]
    quietly finegray_cif, timepoints(.5 1 1.5) name(_fg133_g3, replace)
    _fg133_sersets
    assert r(n) == 1
    * follow-up runs to t = 2 (censored), the CIF is flat there: extended
    assert r(maxt_1) == 2
    assert !missing(r(cif_1), `cif_15')
    assert reldif(r(cif_1), `cif_15') < 1e-10
    graph drop _all
    capture serset drop _all
    * ...and the default grid (curve mode) is extended the same way
    quietly finegray_cif, name(_fg133_g3b, replace)
    _fg133_sersets
    assert r(n) == 1
    assert r(maxt_1) == 2
    assert !missing(r(cif_1), `cif_15')
    assert reldif(r(cif_1), `cif_15') < 1e-10
    graph drop _all
}
local _rc = _rc
_fg133_result `_rc' "G3 grids reaching the last cause event still draw the flat tail to end of follow-up"
local pass_count = `pass_count' + r(pass)
local fail_count = `fail_count' + r(fail)

**# 4. G: saving() and r(table) are untouched by the display decision
local ++test_count
capture noisily {
    capture restore
    capture graph drop _all
    capture serset drop _all
    _fg133_griddata
    quietly finegray x, compete(status) cause(1) nolog
    tempfile sv
    quietly finegray_cif, timepoints(.5 1) saving("`sv'", replace) name(_fg133_g4, replace)
    matrix T = r(table)
    assert rowsof(T) == 2
    preserve
    use "`sv'", clear
    assert _N == 2
    quietly summarize time, meanonly
    assert r(max) == 1
    restore
    graph drop _all
}
local _rc = _rc
_fg133_result `_rc' "G4 saving() and r(table) carry only the requested grid"
local pass_count = `pass_count' + r(pass)
local fail_count = `fail_count' + r(fail)

**# 5. G: under over(bstrata) the decision is per curve
local ++test_count
capture noisily {
    capture restore
    capture graph drop _all
    capture serset drop _all
    _fg133_griddata
    * stratum 2's cause events end at t = 1, stratum 1's at t = 1.5
    gen byte bs = 1 + mod(_n, 2)
    quietly replace status = 2 if bs == 2 & status == 1 & t == 1.5
    quietly stset t, failure(ev) id(id)
    quietly finegray x, compete(status) cause(1) bstrata(bs) nolog
    quietly finegray_cif, over(bs) timepoints(.5 1) name(_fg133_g5, replace)
    * one serset per curve: stratum 1's grid stops before its last cause
    * event (curve ends at 1); stratum 2's cause events end at 1, which the
    * grid reaches, so its flat tail runs to the end of follow-up (2)
    _fg133_sersets
    assert r(n) == 2
    local n_ext = 0
    local n_cut = 0
    forvalues k = 1/2 {
        if r(maxt_`k') == 2 local ++n_ext
        if r(maxt_`k') == 1 local ++n_cut
    }
    assert `n_ext' == 1
    assert `n_cut' == 1
    graph drop _all
}
local _rc = _rc
_fg133_result `_rc' "G5 over(bstrata): the tail decision is made per curve"
local pass_count = `pass_count' + r(pass)
local fail_count = `fail_count' + r(fail)

**# 6. V: e(V) under strata() nuisance on the review fixture
* The fixture is the review's: n = 200, two censoring groups, group 2 with
* competing events and censorings and NO cause events.  The certified value
* comes from validation_nuisance_strata_numeric.do (score-derivative sandwich,
* matched at 1e-11); the pre-fix value is what the group-restricted psi
* posted.  Both are pinned so the arm fails on either drift or reversion.
local ++test_count
capture noisily {
    capture restore
    capture graph drop _all
    capture serset drop _all
    clear
    set seed 39127
    quietly set obs 200
    gen long id = _n
    gen double x = rnormal()
    gen byte cg = 1 + mod(_n, 2)
    gen double t1 = -ln(runiform()) / exp(.4 * x)
    gen double t2 = -ln(runiform()) / exp(-.4 * x)
    gen double tc = -ln(runiform()) / exp(1.5 * (cg - 1))
    gen double t = min(t1, t2, tc)
    gen byte status = cond(t == t1, 1, cond(t == t2, 2, 0))
    quietly replace status = 2 if cg == 2 & status == 1
    gen byte ev = status > 0
    quietly stset t, failure(ev) id(id)
    quietly count if cg == 2 & status == 1
    assert r(N) == 0
    quietly finegray x, compete(status) cause(1) strata(cg) nuisance nolog
    assert e(converged) == 1
    assert "`e(vce_meat)'" == "nuisance_adjusted"
    local v = e(V)[1, 1]
    display as text "    e(V)[1,1] = " %14.10f `v'
    * Stata's reldif() divides by |y| + 1, so spell the relative error out
    assert abs(`v' - .043300223) / .043300223 < 1e-6
    * the pre-1.3.3 value: group 2 contributed no psi at all
    assert abs(`v' - .043285622) / .043285622 > 1e-4
}
local _rc = _rc
_fg133_result `_rc' "V1 e(V) under strata() nuisance carries the cross-group psi (pinned)"
local pass_count = `pass_count' + r(pass)
local fail_count = `fail_count' + r(fail)

**# Summary
display as text _newline ///
    "RESULT: test_finegray_v133 tests=`test_count' pass=`pass_count' fail=`fail_count'"
if `fail_count' > 0 {
    display as error "SOME TESTS FAILED"
    log close _fg133
    exit 1
}
display as result "ALL TESTS PASSED"
log close _fg133
