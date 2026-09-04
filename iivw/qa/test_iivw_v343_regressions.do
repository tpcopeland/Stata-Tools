* test_iivw_v343_regressions.do
* Regression coverage for the end-of-follow-up boundary defect fixed in 3.4.3:
*   T1  a float censor() equal to a double last visit time does not abort
*   T2  the boundary case takes the `alreadythere' branch (no censoring row)
*   T3  positive control: a genuine censor()-before-last-visit still errors
*   T4  a visit landing exactly on maxfu() does not abort
*   T5  positive control: a genuine visit after maxfu() still errors
*   T6  iivw_exogtest accepts the same boundary data iivw_weight accepts
*   T7  positive control: iivw_exogtest still rejects a genuine violation
*   T8  iivw_balance rebuilds exactly the risk set iivw_weight built
*
* T1, T2, and T4 fail on the released 3.4.2 files. T3 and T5 are the positive
* controls: widening a guard must not retire it.
*
* T6 and T8 guard the OTHER TWO COPIES of this code. iivw_weight,
* iivw_exogtest and iivw_balance each build the same Andersen-Gill risk set
* from their own copy of the guard and the terminal-interval test, and the
* first pass of this fix reached only iivw_weight. Measured on the fixture
* below at that point: iivw_weight returned rc=0 where iivw_exogtest returned
* rc=198 on identical data, and iivw_weight reported r(n_censor_rows)=0 where
* iivw_balance built 151 terminal intervals of length ~5e-07 and printed them
* as "incl. 151 terminal at-risk interval(s)". These two tests are what makes
* the three copies fail together instead of drifting apart again.
*
* THE DEFECT
* ----------
* censor() and time() usually descend from the same calendar dates, so a visit
* falling ON the end of follow-up makes them the same instant. They reach it by
* different expressions and often at different storage types: float(d/365.25)
* sits below double(d/365.25) for about half of all day counts d, by up to one
* float epsilon (~6e-08 relative). 3.4.2 compared them with an exact `<' and
* read that gap as a subject still visiting after censoring.
*
* The fixture below is NOT tuned to the fix. Day counts are taken from a fixed
* arithmetic sequence and the float/double gap is measured, not asserted into
* existence, so the suite reports how many subjects actually sit on the wrong
* side of an exact comparison.

clear all
set varabbrev off
version 16.0

capture log close _all
tempfile test_log
log using "`test_log'", replace nomsg

local test_count = 0
local pass_count = 0
local fail_count = 0

local qa_dir "`c(pwd)'"
do "`qa_dir'/_iivw_qa_common.do"
iivw_qa_bootstrap
local pkg_dir "`r(pkg_dir)'"

**# Fixture
*
* 300 subjects, 4 visits each on a registry-like day grid. The last visit falls
* exactly on the end of follow-up: same day count, same divisor -- so the two
* differ only in how they are stored.
*
* fu is float (the defect's trigger: the upstream do-file wrote `gen', not
* `gen double'); t is double, as a time variable should be.

capture program drop _iivw_v343_panel
program define _iivw_v343_panel
    version 16.0
    syntax [, DOUBLEfu SHORTfu TIEfu]
    clear
    set seed 20260817
    set obs 300
    gen long id = _n
    gen double z = rnormal()
    gen byte a = runiform() < invlogit(-0.2 + 0.4 * z)

    * End of follow-up in days: a spread of counts, so roughly half land on
    * each side of the float/double boundary rather than all on one.
    gen long fu_days = 400 + 3 * _n

    expand 4
    bysort id: gen byte visit = _n

    * Visits at 25%, 50%, 75% and 100% of the window. The fourth is the end of
    * follow-up itself.
    gen long vis_days = round(fu_days * visit / 4)
    bysort id (visit): replace vis_days = fu_days if visit == 4

    gen double t = vis_days / 365.25
    if "`doublefu'" != "" {
        gen double fu = fu_days / 365.25
    }
    else if "`shortfu'" != "" {
        * A real violation: follow-up ends a full day before the last visit.
        gen double fu = (fu_days - 1) / 365.25
    }
    else if "`tiefu'" != "" {
        * Same instant as the last visit, carried at float precision, but
        * never BELOW it: this isolates the appended-row branch from the
        * abort that a below-last-visit value triggers. Held in a double so
        * the lift off the floor is not re-rounded away.
        tempvar lastvis
        gen double fu = float(fu_days / 365.25)
        bysort id: egen double `lastvis' = max(t)
        replace fu = `lastvis' if fu < `lastvis'
        drop `lastvis'
    }
    else {
        gen fu = fu_days / 365.25
    }

    gen double y = 1 + 0.6 * a + 0.3 * z + rnormal()
end

* How many subjects does an exact `<' misread on this fixture? Reported, not
* assumed: a fixture that happened to produce zero would make T1 vacuous.
capture program drop _iivw_v343_gap
program define _iivw_v343_gap, rclass
    version 16.0
    _iivw_v343_panel
    tempvar lastvis
    bysort id: egen double `lastvis' = max(t)
    quietly count if fu < `lastvis'
    return scalar n_below = r(N)
    quietly count
    return scalar n_rows = r(N)
end

**# T1: a float end of follow-up equal to the last visit does not abort

local ++test_count
capture noisily {
    _iivw_v343_gap
    local n_below = r(n_below)
    local n_rows  = r(n_rows)
    display as text "  T1 fixture: `n_below' of `n_rows' rows sit below their " ///
        "own last visit under an exact comparison"
    * The fixture must actually exercise the defect.
    assert `n_below' > 0

    _iivw_v343_panel
    quietly iivw_weight, id(id) time(t) censor(fu) visit_cov(z) ///
        baseline(entry) wtype(iivw) nolog
    assert !missing(r(N))
    assert r(N) > 0
    quietly count if missing(_iivw_weight)
    assert r(N) == 0
}
if _rc == 0 {
    display as result "  PASS: T1 - float censor() at the last visit is accepted"
    local ++pass_count
}
else {
    display as error "  FAIL: T1 - float censor() at the last visit (error `=_rc')"
    local ++fail_count
    local failed "`failed' T1"
}

**# T2: the boundary case adds no censoring row
*
* (last visit, C] has zero length when the last visit IS C. Appending a row of
* length ~5e-07 puts a subject in the risk set for an instant that is really
* the visit's own instant, and inflates r(n_censor_rows).
*
* The tie fixture holds C at float precision but never below the last visit,
* so this case reaches the branch instead of aborting first -- otherwise the
* assertion would be satisfied by the T1 defect rather than by this one.

local ++test_count
capture noisily {
    _iivw_v343_panel, tie
    tempvar lastvis
    bysort id: egen double `lastvis' = max(t)
    quietly count if fu > `lastvis'
    local n_above = r(N)
    display as text "  T2 fixture: `n_above' rows sit above their own last " ///
        "visit under an exact comparison"
    assert `n_above' > 0
    drop `lastvis'

    _iivw_v343_panel, tie
    quietly iivw_weight, id(id) time(t) censor(fu) visit_cov(z) ///
        baseline(entry) wtype(iivw) nolog
    display as text "  T2: r(n_censor_rows) = " r(n_censor_rows) " (expected 0)"
    assert r(n_censor_rows) == 0
}
if _rc == 0 {
    display as result "  PASS: T2 - last visit at end of follow-up adds no censoring row"
    local ++pass_count
}
else {
    display as error "  FAIL: T2 - alreadythere branch (error `=_rc')"
    local ++fail_count
    local failed "`failed' T2"
}

**# T3: positive control -- a real violation still errors

local ++test_count
capture noisily {
    _iivw_v343_panel, short
    capture iivw_weight, id(id) time(t) censor(fu) visit_cov(z) ///
        baseline(entry) wtype(iivw) nolog
    local short_rc = _rc
    display as text "  T3: censor() one day before the last visit returns rc = `short_rc'"
    assert `short_rc' == 198
}
if _rc == 0 {
    display as result "  PASS: T3 - censor() before the last visit is still rejected"
    local ++pass_count
}
else {
    display as error "  FAIL: T3 - censor() violation no longer detected (error `=_rc')"
    local ++fail_count
    local failed "`failed' T3"
}

**# T4: a visit landing exactly on maxfu() does not abort
*
* maxfu() is a typed literal; time() is computed. The same boundary, reached
* from the other direction.

local ++test_count
capture noisily {
    _iivw_v343_panel, double
    quietly summarize t, meanonly
    local tmax = r(max)
    * A common window ending at the largest observed visit time, typed to the
    * precision a user would type rather than carried at full double width.
    local maxfu = string(`tmax', "%9.0g")
    display as text "  T4: max visit time `tmax', maxfu(`maxfu')"
    quietly iivw_weight, id(id) time(t) maxfu(`maxfu') visit_cov(z) ///
        baseline(entry) wtype(iivw) nolog
    assert !missing(r(N))
    assert r(N) > 0
}
if _rc == 0 {
    display as result "  PASS: T4 - a visit on the maxfu() boundary is accepted"
    local ++pass_count
}
else {
    display as error "  FAIL: T4 - maxfu() boundary visit (error `=_rc')"
    local ++fail_count
    local failed "`failed' T4"
}

**# T5: positive control -- a visit genuinely after maxfu() still errors

local ++test_count
capture noisily {
    _iivw_v343_panel, double
    quietly summarize t, meanonly
    local short_maxfu = r(max) - 1 / 365.25
    capture iivw_weight, id(id) time(t) maxfu(`short_maxfu') visit_cov(z) ///
        baseline(entry) wtype(iivw) nolog
    local maxfu_rc = _rc
    display as text "  T5: maxfu() one day short returns rc = `maxfu_rc'"
    assert `maxfu_rc' == 198
}
if _rc == 0 {
    display as result "  PASS: T5 - a visit after maxfu() is still rejected"
    local ++pass_count
}
else {
    display as error "  FAIL: T5 - maxfu() violation no longer detected (error `=_rc')"
    local ++fail_count
    local failed "`failed' T5"
}

**# T6: iivw_exogtest accepts the boundary data iivw_weight accepts
*
* iivw_exogtest carries its own copy of the censor() guard. It fits the same
* visit-intensity model, and its help tells the user to give it the same
* end-of-follow-up specification they gave iivw_weight -- so a specification
* iivw_weight accepts and iivw_exogtest refuses is not a usable pair.

* Both rc values are taken from an explicit `capture'. `_rc' is written only by
* `capture', so reading it after a bare `quietly' returns whatever the previous
* capture left behind and the comparison would be vacuous.
local ++test_count
capture noisily {
    _iivw_v343_panel
    capture quietly iivw_weight, id(id) time(t) censor(fu) visit_cov(z) ///
        baseline(entry) wtype(iivw) nolog
    local wt_rc = _rc
    * Content, not just rc: a weighting that committed an all-missing column
    * satisfies `wt_rc == 0' too. Counted HERE, because the panel is rebuilt
    * below and the weight column does not survive that.
    local wt_n = 0
    if `wt_rc' == 0 {
        quietly count if !missing(_iivw_weight)
        local wt_n = r(N)
    }

    _iivw_v343_panel
    capture iivw_exogtest z, id(id) time(t) censor(fu)
    local ex_rc = _rc
    * r() is read before anything else overwrites it.
    local ex_minp = r(min_p)
    local ex_nmodels = r(n_models)
    display as text "  T6: iivw_weight rc = `wt_rc' (`wt_n' weighted rows), " ///
        "iivw_exogtest rc = `ex_rc' (min_p = `ex_minp') on identical data"
    assert `wt_rc' == 0
    assert `ex_rc' == 0
    * An exogeneity test that fitted no model and returned no p-value satisfies
    * `ex_rc == 0' as happily as a real one.
    assert `wt_n' > 0
    assert !missing(`ex_minp')
    assert `ex_minp' >= 0 & `ex_minp' <= 1
    assert `ex_nmodels' > 0
}
if _rc == 0 {
    display as result "  PASS: T6 - iivw_exogtest accepts what iivw_weight accepts"
    local ++pass_count
}
else {
    display as error "  FAIL: T6 - iivw_exogtest/iivw_weight disagree (error `=_rc')"
    local ++fail_count
    local failed "`failed' T6"
}

**# T7: positive control -- iivw_exogtest still rejects a real violation

local ++test_count
capture noisily {
    _iivw_v343_panel, short
    capture iivw_exogtest z, id(id) time(t) censor(fu)
    local ex_short_rc = _rc
    display as text "  T7: iivw_exogtest with censor() one day early returns rc = `ex_short_rc'"
    assert `ex_short_rc' == 198
}
if _rc == 0 {
    display as result "  PASS: T7 - iivw_exogtest still rejects a real violation"
    local ++pass_count
}
else {
    display as error "  FAIL: T7 - iivw_exogtest violation no longer detected (error `=_rc')"
    local ++fail_count
    local failed "`failed' T7"
}

**# T8: iivw_balance rebuilds exactly the risk set iivw_weight built
*
* iivw_balance replays the stored censor() setting and reconstructs the
* terminal at-risk intervals itself. Its whole purpose is to evaluate balance
* against the person-time target the weights were built for, so its terminal
* interval count must equal the one iivw_weight reported. It is compared, not
* asserted to zero: the identity has to hold whatever the fixture produces.

local ++test_count
capture noisily {
    _iivw_v343_panel, tie
    quietly iivw_weight, id(id) time(t) censor(fu) visit_cov(z) ///
        baseline(entry) wtype(iivw) nolog
    local w_ncens = r(n_censor_rows)

    quietly iivw_balance z, nolog
    local b_ncens = r(refit_n_censrows)
    display as text "  T8: iivw_weight r(n_censor_rows) = `w_ncens', " ///
        "iivw_balance r(refit_n_censrows) = `b_ncens'"
    assert `w_ncens' == `b_ncens'
}
if _rc == 0 {
    display as result "  PASS: T8 - iivw_balance rebuilds iivw_weight's risk set"
    local ++pass_count
}
else {
    display as error "  FAIL: T8 - balance/weight terminal-interval counts differ (error `=_rc')"
    local ++fail_count
    local failed "`failed' T8"
}

**# Summary

capture log close _all
iivw_qa_summary, name(test_iivw_v343_regressions) tests(`test_count') ///
    pass(`pass_count') fail(`fail_count') failedtests("`failed'")
