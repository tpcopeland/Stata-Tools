* test_iivw_audit_2026_10_05_weight.do
* Regressions for the 2026-10-05 audit, weight-method track (WM01-WM04).
*
*   W1  WM01 a run under a new prefix keeps caller columns named like its scores
*   W2  WM01 same prefix: an unowned column under a stale score name is refused
*   W3  WM01 a stale score column that is a current input is refused, unchanged
*   W4  WM01 owned stale score columns are still cleared (shorter layout, no scores)
*   W5  WM02 origin shift: every terminal interval kept, Cox fit unchanged
*   W6  WM02 small time unit: every terminal interval kept, Cox fit unchanged
*   W7  WM02 baseline(event) with explicit entry: origin shift changes nothing
*   W8  WM02 exact encoded endpoints: adjacent doubles/floats and tiny intervals
*   W9  WM02 float precision: same instant at float resolution, no interval
*   W10 WM02 maxfu() token: exact storage, accepted forms, refusals, replay
*   W11 WM03 treat_cov() exclusions: zero treatment scores, full nuisance union
*   W12 WM03 separation exclusions: zero treatment scores outside e(sample)
*   W13 WM04 raw component snapshots are bound into the weighting signature
*   W14 WM02 a float-resolved gap holding another subject's visit is refused
*   W15 WM04 a narrower earlier-version stamp: 459 names the version cause
*   W16 the weighting signature does not depend on set processors
*
* Expected terminal-interval counts are computed from the data in each block
* (one interval per subject whose end of follow-up is strictly later than its
* last visit), never copied from the package's own branch.
*
* Usage:
*   cd iivw/qa
*   stata-mp -b do test_iivw_audit_2026_10_05_weight.do [case#]

clear all
set varabbrev off
version 16.0

capture log close _all
tempfile test_log
log using "`test_log'", replace nomsg

local test_count = 0
local pass_count = 0
local fail_count = 0
local failed ""

local qa_dir "`c(pwd)'"
do "`qa_dir'/_iivw_qa_common.do"
iivw_qa_bootstrap
local pkg_dir "`r(pkg_dir)'"

iivw_qa_selector `1'
local run_only = r(run_only)

* One row per subject, IPTW, one treatment covariate.
capture program drop _wm_iptw
program define _wm_iptw
    version 16.0
    clear
    set seed 87131
    quietly set obs 200
    gen long id = _n
    gen double t = 0
    gen double x = rnormal()
    gen double x2 = rnormal()
    gen byte a = runiform() < invlogit(.2*x + .3*x2)
end

* Recurrent visits on (0, 5), 400 subjects, every subject followed past its
* last visit.
capture program drop _wm_visits
program define _wm_visits
    version 16.0
    clear
    set seed 77701
    quietly set obs 400
    gen long id = _n
    gen double z = rnormal()
    gen double t = 0
    quietly expand 8
    bysort id: gen byte visit = _n
    bysort id (visit): replace t = sum(-ln(runiform())/exp(.8*z))
    quietly replace t = 0 if visit == 1
    quietly keep if t < 5
end

* Independent count: subjects whose stated end is strictly after their last
* visit, on the stored values.
capture program drop _wm_expected
program define _wm_expected, rclass
    version 16.0
    args endvar
    tempvar last tag
    bysort id: egen double `last' = max(t)
    egen byte `tag' = tag(id)
    quietly count if `tag' & `endvar' > `last'
    return scalar n = r(N)
end

* Two visits per subject, 120 subjects, the second at time 1.
capture program drop _wm_pair
program define _wm_pair
    version 16.0
    clear
    set seed 22141
    quietly set obs 120
    gen long id = _n
    gen double z = rnormal()
    quietly expand 2
    bysort id: gen byte visit = _n
    gen double t = cond(visit == 1, 0, 1)
end

**# W1: WM01 a new prefix keeps caller columns named like its scores

local ++test_count
if `run_only' == 0 | `run_only' == 1 {
capture noisily {
    _wm_iptw
    quietly iivw_weight, id(id) time(t) treat(a) treat_cov(x) wtype(iptw) ///
        scores generate(old_) nolog
    gen double old_keep = old_ns1
    gen double new_nd1 = 987654
    gen double new_ns2 = 765432
    capture quietly iivw_weight, id(id) time(t) treat(a) treat_cov(x) ///
        wtype(iptw) generate(new_) nolog
    local rc = _rc
    display as text "  unscored rerun under new_ -> rc = `rc'"
    assert `rc' == 0
    confirm variable new_nd1 new_ns2 old_nd1 old_ns1, exact
    assert new_nd1 == 987654
    assert new_ns2 == 765432
    assert old_ns1 == old_keep
    confirm variable new_weight, exact
    display as result "W1 PASS: caller columns and the old prefix's scores survive"
}
if _rc == 0 local ++pass_count
else {
    local ++fail_count
    local failed "`failed' W1"
    display as error "W1 FAIL"
}
}

**# W2: WM01 same prefix, unowned column under a stale score name
*
* The recreated name is ns2, so nd1, ns1 and nd2 are already backed up when
* the refusal fires: the rollback must put every one of them back.

local ++test_count
if `run_only' == 0 | `run_only' == 2 {
capture noisily {
    _wm_iptw
    quietly iivw_weight, id(id) time(t) treat(a) treat_cov(x) wtype(iptw) ///
        scores nolog
    gen double w_before = _iivw_weight
    gen double nd1_before = _iivw_nd1
    gen double ns1_before = _iivw_ns1
    gen double nd2_before = _iivw_nd2
    local sig_before : char _dta[_iivw_wsig]
    drop _iivw_ns2
    gen double _iivw_ns2 = 90909
    char _iivw_ns2[_iivw_owner] ""
    capture iivw_weight, id(id) time(t) treat(a) treat_cov(x) wtype(iptw) ///
        replace nolog
    local rc = _rc
    display as text "  rerun over a caller-recreated _iivw_ns2 -> rc = `rc'"
    assert `rc' == 110
    confirm variable _iivw_ns2, exact
    assert _iivw_ns2 == 90909
    * The rollback restored the prior owned outputs and the contract.
    assert _iivw_weight == w_before
    assert _iivw_nd1 == nd1_before
    assert _iivw_ns1 == ns1_before
    assert _iivw_nd2 == nd2_before
    local sig_after : char _dta[_iivw_wsig]
    assert `"`sig_after'"' == `"`sig_before'"'
    display as result "W2 PASS: an unowned stale-score name is refused, not deleted"
}
if _rc == 0 local ++pass_count
else {
    local ++fail_count
    local failed "`failed' W2"
    display as error "W2 FAIL"
}
}

**# W3: WM01 a stale score column that is a current input

local ++test_count
if `run_only' == 0 | `run_only' == 3 {
capture noisily {
    _wm_iptw
    quietly iivw_weight, id(id) time(t) treat(a) treat_cov(x) wtype(iptw) ///
        scores nolog
    gen double saved_input = _iivw_nd1
    capture iivw_weight, id(id) time(t) treat(a) treat_cov(_iivw_nd1) ///
        wtype(iptw) replace nolog
    local rc = _rc
    display as text "  treat_cov(_iivw_nd1) on a same-prefix rerun -> rc = `rc'"
    assert `rc' == 110
    confirm variable _iivw_nd1, exact
    assert _iivw_nd1 == saved_input
    display as result "W3 PASS: a current input is never swept as a stale score"
}
if _rc == 0 local ++pass_count
else {
    local ++fail_count
    local failed "`failed' W3"
    display as error "W3 FAIL"
}
}

**# W4: WM01 owned stale score columns are still cleared

local ++test_count
if `run_only' == 0 | `run_only' == 4 {
capture noisily {
    _wm_iptw
    quietly iivw_weight, id(id) time(t) treat(a) treat_cov(x x2) wtype(iptw) ///
        scores nolog
    confirm variable _iivw_nd4 _iivw_ns4, exact
    quietly iivw_weight, id(id) time(t) treat(a) treat_cov(x) wtype(iptw) ///
        scores replace nolog
    local terms : char _dta[_iivw_score_terms]
    display as text "  shorter layout terms: `terms'"
    assert `"`terms'"' == "a:x a:_cons p:_cons"
    confirm variable _iivw_nd3 _iivw_ns3, exact
    capture confirm variable _iivw_nd4, exact
    assert _rc == 111
    capture confirm variable _iivw_ns4, exact
    assert _rc == 111
    quietly iivw_weight, id(id) time(t) treat(a) treat_cov(x) wtype(iptw) ///
        replace nolog
    capture confirm variable _iivw_nd1, exact
    assert _rc == 111
    capture confirm variable _iivw_ns3, exact
    assert _rc == 111
    _iivw_check_weighted
    display as result "W4 PASS: owned stale score columns are cleared as before"
}
if _rc == 0 local ++pass_count
else {
    local ++fail_count
    local failed "`failed' W4"
    display as error "W4 FAIL"
}
}

**# W5: WM02 origin shift keeps every terminal interval

local ++test_count
if `run_only' == 0 | `run_only' == 5 {
capture noisily {
    local g0 = .
    foreach origin in 0 1000000000 {
        _wm_visits
        quietly replace t = t + `origin'
        gen double endpoint = 5 + `origin'
        _wm_expected endpoint
        local exp = r(n)
        quietly iivw_weight, id(id) time(t) visit_cov(z) censor(endpoint) nolog
        local obs = r(n_censor_rows)
        local g = r(visit_b)[1,1]
        display as text "  origin `origin': expected `exp', observed `obs', gamma " %20.16g `g'
        assert `exp' == 400
        assert `obs' == `exp'
        if `origin' == 0 {
            local g0 = `g'
            gen double w0 = _iivw_weight
            keep id visit w0
            tempfile wref
            quietly save `wref'
        }
        else {
            assert reldif(`g', `g0') < 1e-10
            quietly merge 1:1 id visit using `wref', assert(match) nogenerate
            gen double wd = reldif(_iivw_weight, w0)
            quietly summarize wd, meanonly
            display as text "  max weight reldif across origins " %10.3e r(max)
            assert r(max) < 1e-8
        }
    }
    display as result "W5 PASS: a change of origin keeps the risk set and the weights"
}
if _rc == 0 local ++pass_count
else {
    local ++fail_count
    local failed "`failed' W5"
    display as error "W5 FAIL"
}
}

**# W6: WM02 small time unit keeps every terminal interval

local ++test_count
if `run_only' == 0 | `run_only' == 6 {
capture noisily {
    _wm_visits
    gen double endpoint = 5
    quietly iivw_weight, id(id) time(t) visit_cov(z) censor(endpoint) nolog
    local g0 = r(visit_b)[1,1]
    _wm_visits
    quietly replace t = t * 1e-9
    gen double endpoint = 5e-9
    _wm_expected endpoint
    local exp = r(n)
    quietly iivw_weight, id(id) time(t) visit_cov(z) censor(endpoint) nolog
    local obs = r(n_censor_rows)
    local g = r(visit_b)[1,1]
    display as text "  unit 1e-9: expected `exp', observed `obs', gamma " ///
        %20.16g `g' " vs " %20.16g `g0'
    assert `exp' == 400
    assert `obs' == `exp'
    assert reldif(`g', `g0') < 1e-10
    display as result "W6 PASS: a change of unit keeps the risk set"
}
if _rc == 0 local ++pass_count
else {
    local ++fail_count
    local failed "`failed' W6"
    display as error "W6 FAIL"
}
}

**# W7: WM02 baseline(event) with explicit entry, origin shift

local ++test_count
if `run_only' == 0 | `run_only' == 7 {
capture noisily {
    local g0 = .
    foreach origin in 0 1000000000 {
        _wm_visits
        quietly replace t = t + 1 + `origin'
        gen double entry = .5 + `origin'
        gen double endpoint = 6 + `origin'
        _wm_expected endpoint
        local exp = r(n)
        quietly iivw_weight, id(id) time(t) entry(entry) baseline(event) ///
            visit_cov(z) censor(endpoint) nolog
        local obs = r(n_censor_rows)
        local g = r(visit_b)[1,1]
        display as text "  origin `origin': expected `exp', observed `obs', gamma " %20.16g `g'
        assert `exp' == 400
        assert `obs' == `exp'
        if `origin' == 0 local g0 = `g'
        else assert reldif(`g', `g0') < 1e-8
    }
    display as result "W7 PASS: baseline(event) risk set is origin-invariant"
}
if _rc == 0 local ++pass_count
else {
    local ++fail_count
    local failed "`failed' W7"
    display as error "W7 FAIL"
}
}

**# W8: WM02 exact encoded endpoints

local ++test_count
if `run_only' == 0 | `run_only' == 8 {
capture noisily {
    foreach mode in double_adj float_adj double_tiny exact_equal {
        _wm_pair
        gen double endpoint = 1
        if "`mode'" == "double_adj" quietly replace endpoint = 1 + 2^-52
        if "`mode'" == "double_tiny" {
            quietly replace t = t * 1e-20
            quietly replace endpoint = 2e-20
        }
        if "`mode'" == "float_adj" {
            quietly recast float t, force
            quietly recast float endpoint
            quietly replace endpoint = 1 + 2^-23
        }
        _wm_expected endpoint
        local exp = r(n)
        quietly iivw_weight, id(id) time(t) visit_cov(z) censor(endpoint) nolog
        local obs = r(n_censor_rows)
        display as text "  `mode': expected `exp', observed `obs'"
        if "`mode'" == "exact_equal" assert `exp' == 0
        else assert `exp' == 120
        assert `obs' == `exp'
    }
    display as result "W8 PASS: every positive encoded interval is kept, equal ends add none"
}
if _rc == 0 local ++pass_count
else {
    local ++fail_count
    local failed "`failed' W8"
    display as error "W8 FAIL"
}
}

**# W9: WM02 float precision -- same instant at float resolution

local ++test_count
if `run_only' == 0 | `run_only' == 9 {
capture noisily {
    * float time() at float(.2), double censor() at .2: one instant.
    _wm_pair
    quietly replace t = cond(visit == 1, 0, .2)
    quietly recast float t, force
    gen double endpoint = .2
    quietly count if endpoint == t & visit == 2
    assert r(N) == 0
    iivw_weight, id(id) time(t) visit_cov(z) censor(endpoint) nolog
    display as text "  float time vs double censor: terminal rows " r(n_censor_rows)
    assert r(n_censor_rows) == 0

    * double time(), float censor() reached from the same day counts: the
    * 3.4.3 case. Both orderings occur; none is an interval or a violation.
    clear
    quietly set obs 300
    gen long id = _n
    gen double z = rnormal()
    gen long fu_days = 400 + 3 * _n
    quietly expand 4
    bysort id: gen byte visit = _n
    gen long vis_days = round(fu_days * visit / 4)
    gen double t = vis_days / 365.25
    gen float fu = fu_days / 365.25
    tempvar last
    bysort id: egen double `last' = max(t)
    quietly count if fu < `last'
    local nbelow = r(N)
    quietly count if fu > `last'
    local nabove = r(N)
    display as text "  float censor below/above its double last visit: `nbelow'/`nabove' rows"
    assert `nbelow' > 0 & `nabove' > 0
    drop `last'
    quietly iivw_weight, id(id) time(t) visit_cov(z) censor(fu) baseline(entry) nolog
    assert r(n_censor_rows) == 0

    * maxfu() under a float time(): the end is float(.2), so subjects last
    * seen at .1 stay at risk at the event recorded at float(.2).
    _wm_pair
    quietly replace t = cond(visit == 1, 0, cond(z > 0, .1, .2))
    quietly recast float t, force
    quietly count if visit == 2 & z > 0
    local exp = r(N)
    quietly iivw_weight, id(id) time(t) visit_cov(z) maxfu(.2) nolog
    local n1 = r(n_censor_rows)
    local g1 = r(visit_b)[1,1]
    local fend : display %21x float(.2)
    quietly iivw_weight, id(id) time(t) visit_cov(z) maxfu(`fend') replace nolog
    local g2 = r(visit_b)[1,1]
    display as text "  maxfu(.2) float time: `n1' terminal rows; gamma " ///
        %20.16g `g1' " vs maxfu(float(.2)) " %20.16g `g2'
    assert `n1' == `exp'
    assert `g1' == `g2'
    assert abs(`g1') > .01

    * Positive control: a genuinely earlier double censor() is still refused.
    _wm_pair
    gen double endpoint = 1 - 1e-12
    capture iivw_weight, id(id) time(t) visit_cov(z) censor(endpoint) nolog
    display as text "  double censor 1e-12 before the last visit -> rc = " _rc
    assert _rc == 198
    display as result "W9 PASS: float-resolution ties are one instant; real violations error"
}
if _rc == 0 local ++pass_count
else {
    local ++fail_count
    local failed "`failed' W9"
    display as error "W9 FAIL"
}
}

**# W10: WM02 maxfu() token

local ++test_count
if `run_only' == 0 | `run_only' == 10 {
capture noisily {
    * The helper resolves from the installed package, not the source tree.
    capture findfile _iivw_endpoint.ado
    assert _rc == 0
    assert strpos(`"`r(fn)'"', c(sysdir_plus)) == 1

    _wm_visits
    local hex5 : display %21x 5
    local k = 0
    foreach tok in 5 5e0 `hex5' {
        local ++k
        quietly iivw_weight, id(id) time(t) visit_cov(z) maxfu(`tok') replace nolog
        local st`k' : char _dta[_iivw_maxfu]
        assert r(maxfu) == 5
        gen double w`k' = _iivw_weight
    }
    display as text "  stored tokens: `st1' | `st2' | `st3'"
    assert "`st1'" == "5" & "`st2'" == "5" & "`st3'" == "5"
    assert w1 == w2 & w2 == w3

    foreach bad in . .a banana "1 2" 1+2 {
        capture iivw_weight, id(id) time(t) visit_cov(z) maxfu(`bad') replace nolog
        display as text "  maxfu(`bad') -> rc = " _rc
        assert _rc == 198
    }

    * Full-precision token: the double clock ends exactly ON maxfu.
    _wm_pair
    quietly replace t = cond(visit == 1, 0, float(.2))
    local tok : display %24.17g float(.2)
    quietly iivw_weight, id(id) time(t) visit_cov(z) maxfu(`tok') nolog
    assert r(n_censor_rows) == 0
    local stored : char _dta[_iivw_maxfu]
    display as text "  maxfu(`tok') stored as `stored'"
    assert real("`stored'") == float(.2)
    gen double w_first = _iivw_weight
    * Replay the stored token: identical weights.
    quietly iivw_weight, id(id) time(t) visit_cov(z) maxfu(`stored') replace nolog
    assert _iivw_weight == w_first

    * A typed value just below the last visit leaves that visit outside every
    * other subject's risk set: refused, with the exact maximum shown.
    capture iivw_weight, id(id) time(t) visit_cov(z) maxfu(.2) replace nolog
    display as text "  maxfu(.2) with a double visit at float(.2) -> rc = " _rc
    assert _rc == 198
    display as result "W10 PASS: maxfu() is exact, round-trips, and refuses non-numbers"
}
if _rc == 0 local ++pass_count
else {
    local ++fail_count
    local failed "`failed' W10"
    display as error "W10 FAIL"
}
}

**# W11: WM03 treat_cov() exclusions in the combined nuisance union

local ++test_count
if `run_only' == 0 | `run_only' == 11 {
capture noisily {
    clear
    set seed 62718
    quietly set obs 200
    gen long id = _n
    gen double x = rnormal()
    gen double z = rnormal()
    gen byte a = runiform() < invlogit(.4 + .7*x)
    quietly replace x = . if id <= 40
    quietly expand 5
    bysort id: gen double t = _n - 1
    quietly drop if t > 0 & runiform() > invlogit(.5 + z + .3*a)
    gen double y = 1 + .7*a + .4*z + .3*t + .2*z*t + rnormal()
    quietly iivw_weight, id(id) time(t) visit_cov(z) treat(a) treat_cov(x) ///
        wtype(fiptiw) maxfu(5) allowmissingweights scores nolog
    local terms : char _dta[_iivw_score_terms]
    assert "`terms'" == "g:z g:a a:x a:_cons p:_cons"
    * Excluded subjects: zero (not missing) treatment and prevalence scores,
    * genuine nonzero visit-model scores.
    forvalues j = 3/5 {
        quietly count if id <= 40 & (missing(_iivw_ns`j') | _iivw_ns`j' != 0)
        assert r(N) == 0
    }
    quietly count if id <= 40 & _iivw_ns1 != 0 & !missing(_iivw_ns1)
    assert r(N) > 0
    * Included subjects keep the score formulas, checked by hand.
    tempvar first
    bysort id (t): gen byte `first' = _n == 1
    quietly summarize a if `first' & id > 40, meanonly
    local p = r(mean)
    assert reldif(_iivw_ns3, (a - _iivw_ps) * x) < 1e-10 if id > 40
    assert reldif(_iivw_ns4, a - _iivw_ps) < 1e-10 if id > 40
    assert reldif(_iivw_ns5, a - `p') < 1e-12 if id > 40
    * The weight derivative stays the derivative of the row's own weight.
    assert missing(_iivw_nd3) if id <= 40
    assert missing(_iivw_weight) if id <= 40
    quietly iivw_fit y a z, timespec(linear) vce(stacked) nolog
    display as text "  stacked fit: N=" e(N) " outcome clusters=" ///
        e(iivw_outcome_nclust) " nuisance union=" e(iivw_stacked_nclust)
    assert e(iivw_outcome_nclust) == 160
    assert e(iivw_stacked_nclust) == 200
    display as result "W11 PASS: Cox-only subjects stay in the stacked nuisance union"
}
if _rc == 0 local ++pass_count
else {
    local ++fail_count
    local failed "`failed' W11"
    display as error "W11 FAIL"
}
}

**# W12: WM03 separation exclusions

local ++test_count
if `run_only' == 0 | `run_only' == 12 {
capture noisily {
    clear
    set seed 4141
    quietly set obs 60
    gen long id = _n
    gen double t = 0
    gen double x = rnormal()
    gen byte s = id <= 10
    gen byte a = runiform() < invlogit(.5*x)
    quietly replace a = 1 if s
    * Independent e(sample): the native logit on the same one-row-per-subject data.
    quietly logit a x s
    gen byte insample = e(sample)
    quietly count if !insample
    local nout = r(N)
    display as text "  native logit excludes `nout' perfectly predicted subjects"
    assert `nout' == 10
    capture quietly iivw_weight, id(id) time(t) treat(a) treat_cov(x s) ///
        wtype(iptw) allowmissingweights scores nolog
    assert _rc == 0
    local terms : char _dta[_iivw_score_terms]
    local nterm : word count `terms'
    forvalues j = 1/`nterm' {
        quietly count if !insample & (missing(_iivw_ns`j') | _iivw_ns`j' != 0)
        assert r(N) == 0
    }
    quietly count if insample & _iivw_ns`nterm' != 0
    assert r(N) > 0
    display as result "W12 PASS: separated subjects carry zero treatment scores"
}
if _rc == 0 local ++pass_count
else {
    local ++fail_count
    local failed "`failed' W12"
    display as error "W12 FAIL"
}
}

**# W13: WM04 raw component snapshots are signature-bound

local ++test_count
if `run_only' == 0 | `run_only' == 13 {
capture noisily {
    _wm_iptw
    quietly iivw_weight, id(id) time(t) treat(a) treat_cov(x) wtype(iptw) nolog
    _iivw_check_weighted
    local raw : char _dta[_iivw_tw_raw_var]
    assert "`raw'" == ""

    _wm_iptw
    quietly iivw_weight, id(id) time(t) treat(a) treat_cov(x) wtype(iptw) ///
        trunctreat(1 90) nolog
    _iivw_check_weighted
    gen double keep_raw = _iivw_tw_raw
    quietly replace _iivw_tw_raw = _iivw_tw_raw * 1000
    capture _iivw_check_weighted
    local rc_edit = _rc
    quietly replace _iivw_tw_raw = keep_raw
    _iivw_check_weighted
    char _dta[_iivw_tw_raw_var]
    capture _iivw_check_weighted
    local rc_role = _rc
    char _dta[_iivw_tw_raw_var] "_iivw_tw_raw"
    _iivw_check_weighted
    drop _iivw_tw_raw
    capture _iivw_check_weighted
    local rc_drop = _rc
    display as text "  tw_raw edited/role removed/dropped -> `rc_edit'/`rc_role'/`rc_drop'"
    assert `rc_edit' == 459 & `rc_role' == 459 & `rc_drop' == 459

    _wm_visits
    quietly iivw_weight, id(id) time(t) visit_cov(z) maxfu(5) truncvisit(1 99) nolog
    _iivw_check_weighted
    quietly replace _iivw_iw_raw = _iivw_iw_raw + 1 in 1
    capture _iivw_check_weighted
    display as text "  iw_raw edited -> " _rc
    assert _rc == 459
    display as result "W13 PASS: edited or dropped raw snapshots break the contract"
}
if _rc == 0 local ++pass_count
else {
    local ++fail_count
    local failed "`failed' W13"
    display as error "W13 FAIL"
}
}

**# W14: WM02 float-resolved gap holding a visit is refused
*
* Subject 1: double last visit 100.000005, float censor() 100.0000076 (the
* nearest float). At float precision those agree, so the end is resolved onto
* the visit. Subject 2 visits at 100.000006, inside the dropped gap: that is
* a real event, and resolving would take subject 1 out of its risk set.

capture program drop _wm_gap
program define _wm_gap
    version 16.0
    args inside
    clear
    set seed 5150
    quietly set obs 60
    gen long id = _n
    gen double z = rnormal()
    quietly expand 3
    bysort id: gen byte visit = _n
    gen double t = cond(visit == 1, 0, ///
        cond(visit == 2, 20 + id + .5, 150 + id/7 + 10*z))
    quietly replace t = 50 if id == 1 & visit == 2
    quietly replace t = 100.000005 if id == 1 & visit == 3
    quietly replace t = `inside' if id == 2 & visit == 2
    gen float fu = 250
    quietly replace fu = 100.0000076 if id == 1
end

local ++test_count
if `run_only' == 0 | `run_only' == 14 {
capture noisily {
    _wm_gap 100.000006
    * The fixture must actually create the case: resolved at float, gap
    * above the visit, subject 2 strictly inside it.
    assert float(t[3]) == fu[1] & fu[1] > t[3]
    quietly count if id == 2 & t > 100.000005 & t <= fu[1]
    assert r(N) == 1
    capture iivw_weight, id(id) time(t) visit_cov(z) censor(fu) nolog
    local rc_w = _rc
    capture iivw_exogtest z, id(id) time(t) censor(fu)
    local rc_x = _rc
    display as text "  visit inside the gap: iivw_weight rc = `rc_w', iivw_exogtest rc = `rc_x'"
    assert `rc_w' == 198 & `rc_x' == 198

    * Negative control: subject 2's visit moved above the gap. The end is
    * resolved onto subject 1's visit (no terminal row for subject 1).
    _wm_gap 100.00002
    quietly count if t > 100.000005 & t <= fu[1]
    assert r(N) == 0
    iivw_weight, id(id) time(t) visit_cov(z) censor(fu) nolog
    local ncens = r(n_censor_rows)
    display as text "  no visit inside the gap: rc 0, terminal rows `ncens' (expected 59)"
    assert `ncens' == 59
    capture iivw_exogtest z, id(id) time(t) censor(fu)
    assert _rc == 0
    display as result "W14 PASS: a gap holding a real event is refused; an empty gap resolves"
}
if _rc == 0 local ++pass_count
else {
    local ++fail_count
    local failed "`failed' W14"
    display as error "W14 FAIL"
}
}

**# W15: WM04 an earlier-version stamp gets a 459 that names the cause
*
* An unchanged panel trimmed under an earlier iivw carries a signature that
* did not bind the raw snapshot. That stamp is reproduced exactly by signing
* with the raw role blanked (the earlier binding), then restoring the role.

local ++test_count
if `run_only' == 0 | `run_only' == 15 {
capture noisily {
    _wm_visits
    quietly iivw_weight, id(id) time(t) visit_cov(z) maxfu(5) truncvisit(1 99) nolog
    local role : char _dta[_iivw_iw_raw_var]
    assert "`role'" == "_iivw_iw_raw"
    char _dta[_iivw_iw_raw_var]
    quietly _iivw_weight_signature
    char _dta[_iivw_wsig] "`r(signature)'"
    char _dta[_iivw_iw_raw_var] "`role'"
    tempfile msg
    log using "`msg'", text name(_wm15) replace
    capture noisily _iivw_check_weighted
    local rc = _rc
    log close _wm15
    tempname fh
    local found = 0
    file open `fh' using "`msg'", read text
    file read `fh' line
    while r(eof) == 0 {
        if strpos(`"`macval(line)'"', "earlier iivw version") local found = 1
        file read `fh' line
    }
    file close `fh'
    display as text "  earlier-version stamp: rc = `rc', version hint shown = `found'"
    assert `rc' == 459 & `found' == 1
    quietly iivw_weight, id(id) time(t) visit_cov(z) maxfu(5) truncvisit(1 99) replace nolog
    _iivw_check_weighted
    display as result "W15 PASS: the refusal tells the user an older contract may be the cause"
}
if _rc == 0 local ++pass_count
else {
    local ++fail_count
    local failed "`failed' W15"
    display as error "W15 FAIL"
}
}

**# W16: the weighting signature does not depend on set processors
*
* quadcross() reductions moved in the last bit with the processor count, so
* weights stamped at one setting were refused at another. Large enough that
* a split reduction is actually exercised.

local ++test_count
if `run_only' == 0 | `run_only' == 16 {
capture noisily {
    local p_orig = c(processors)
    local p_max = c(processors_max)
    display as text "  processors: current `p_orig', licensed maximum `p_max'"
    assert `p_max' > 1
    clear
    set seed 2718
    quietly set obs 20000
    gen long id = _n
    gen double z = rnormal() * exp(rnormal())
    gen double x = rnormal()
    gen byte a = runiform() < invlogit(.5*x)
    quietly expand 10
    bysort id: gen double t = (_n - 1) + runiform()
    set processors `p_max'
    quietly iivw_weight, id(id) time(t) visit_cov(z) treat(a) treat_cov(x) ///
        wtype(fiptiw) maxfu(10) nolog
    set processors 1
    capture _iivw_check_weighted
    local rc1 = _rc
    quietly _iivw_weight_signature
    local s1 "`r(signature)'"
    set processors `p_max'
    quietly _iivw_weight_signature
    local s2 "`r(signature)'"
    set processors `p_orig'
    display as text "  stamped at `p_max', checked at 1 -> rc = `rc1'"
    assert `rc1' == 0
    assert `"`s1'"' == `"`s2'"'
    display as result "W16 PASS: one signature at every processor count"
}
if _rc == 0 local ++pass_count
else {
    local ++fail_count
    local failed "`failed' W16"
    display as error "W16 FAIL"
}
capture set processors `p_orig'
}

iivw_qa_summary, name(test_iivw_audit_2026_10_05_weight) tests(`test_count') ///
    pass(`pass_count') fail(`fail_count') runonly(`run_only') ///
    failedtests("`failed'")
