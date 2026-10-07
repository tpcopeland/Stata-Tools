* test_iivw_audit_2026_10_05_diag.do
* Regressions for the 2026-10-05 audit, diagnostics/exogeneity track
* (DX01-DX06) and the downstream WM02 endpoint instances in iivw_balance and
* iivw_exogtest.
*
*   D1  DX01 a suffix restriction keeps every selected terminal interval and
*       matches an independent native stset/stcox oracle on the selected rows
*   D2  DX01 middle-window and noncontiguous restrictions use only selected
*       history: equal to the physically subset data; lags missing outside
*   D3  DX02 a sparse Efron tie (multiplicity just over 1) withholds the
*       verdict; untied Efron and tied Breslow still receive one
*   D4  DX03 an extreme extra covariate cannot move the modeled verdict;
*       its own target SMD is returned in r(target)
*   D5  DX04 xtreg fe/be twins are refused; force withholds eligibility and
*       shares; an fe/fe trio stays decomposable
*   D6  DX05 estimand(contrast) returns r(decomposable) = 0
*   D7  DX06 tie statistics count only fitted models and per-model clocks
*   D8  WM02 balance and exogtest keep every terminal interval under a large
*       clock origin and a tiny clock unit, matching iivw_weight
*   D9  WM02 maxfu() is one exact numeric token in iivw_exogtest
*   D10 WM02 encoded endpoints: positive sub-ulp intervals kept, equality adds
*       none, float-equal mixed precision resolved as in iivw_weight
*   D11 WM02 balance replays a stored full-precision maxfu() token exactly
*   D12 DX03 follow-up: a misspecified visit model (true intensity in z^2, or
*       a strong omitted u) is flagged by r(extra_flag) while r(balance_flag)
*       stays modeled-only; a correctly specified model is not flagged
*   D13 DX03 follow-up: a listed model covariate is modeled, counted once;
*       no extras gives an empty r(extra_flag)
*   D14 DX03 follow-up: a degenerate modeled covariate leaves the primary
*       verdict unavailable while the extra verdict is still reported
*
* Usage:
*   cd iivw/qa
*   stata-mp -b do test_iivw_audit_2026_10_05_diag.do [case#]

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

**# Fixtures

* 60 subjects x 5 visits, jittered (untied) times.
capture program drop _dx_panel5
program define _dx_panel5
    version 16.0
    clear
    set seed 8675309
    set obs 60
    gen long id = _n
    gen double z = rnormal()
    expand 5
    bysort id: gen byte visit = _n
    gen double t = visit + runiform() * .1
    gen double y = z + .2 * visit + rnormal()
end

* Independent oracle for the selected-row exogeneity model: lag at the previous
* selected visit, (start, stop] event intervals with the first selected visit
* dropped, and one (last visit, endpoint] event-0 interval carrying the last
* observed outcome. Built and fitted with native stset/stcox.
capture program drop _dx_oracle
program define _dx_oracle, rclass
    version 16.0
    syntax , ENDpoint(real)
    sort id t
    by id: gen double lag = y[_n-1]
    by id: gen double start = t[_n-1]
    gen double stop = t
    gen byte ev = 1
    by id: gen byte last = _n == _N
    expand 2 if last, gen(term)
    replace start = stop if term
    replace stop = `endpoint' if term
    replace ev = 0 if term
    replace lag = y if term
    drop if missing(lag, start)
    stset stop, id(id) time0(start) failure(ev) exit(time .)
    stcox lag, efron vce(cluster id) nolog
    return scalar b = _b[lag]
    return scalar N = e(N)
    return scalar nev = e(N_fail)
end

* 120 subjects x 3 visits, saturated stabilization: every visit weight is 1.
capture program drop _dx_balpanel
program define _dx_balpanel
    version 16.0
    clear
    set seed 4455
    set obs 120
    gen long id = _n
    gen double z = rnormal()
    expand 3
    bysort id: gen byte visit = _n
    gen double t = cond(visit == 1, 0, visit - 1 + runiform() * .8)
    gen double extra = cond(visit == 3, 1000, 0)
end

* Covariate-driven gap process, subject-specific variable visit counts, every
* subject with a positive terminal interval before endpoint 5.
capture program drop _dx_gap
program define _dx_gap
    version 16.0
    clear
    set seed 77701
    set obs 200
    gen long id = _n
    gen double z = rnormal()
    expand 8
    bysort id: gen byte visit = _n
    bysort id (visit): gen double t = sum(-ln(runiform()) / exp(.8 * z))
    replace t = 0 if visit == 1
    keep if t < 5
    gen double y = z + .1 * visit + rnormal()
end

* 120 subjects x 3 visits, last visit at exactly .2 (encoded per mode).
capture program drop _dx_endpanel
program define _dx_endpanel
    version 16.0
    clear
    set seed 22141
    set obs 120
    gen long id = _n
    gen double y = rnormal()
    expand 3
    bysort id: gen byte visit = _n
    replace y = y + .1 * visit + rnormal() * .1
    gen double t = cond(visit == 1, 0, cond(visit == 2, .05 + runiform() * .05, .2))
    gen double endpoint = .2
end

**# D1: DX01 suffix restriction keeps selected terminal intervals
local ++test_count
if `run_only' == 0 | `run_only' == 1 {
capture noisily {
    _dx_panel5
    * 4.7 lies after every selected fourth visit and before every excluded
    * fifth visit: 60 x 3 modeled events + 60 terminal intervals.
    iivw_exogtest y if visit <= 4, id(id) time(t) maxfu(4.7) nolog
    assert r(N) == 240
    assert r(n_modeled_events) == 180
    matrix R = r(results)
    local b_if = R[1, 3]
    * Generated lag: missing on the first selected and on every excluded row,
    * and equal to the previous selected visit's outcome elsewhere.
    sort id t
    quietly count if visit == 5 & !missing(_iivw_exog_y_lag1)
    assert r(N) == 0
    quietly count if visit == 1 & !missing(_iivw_exog_y_lag1)
    assert r(N) == 0
    assert !missing(_iivw_exog_y_lag1) if inrange(visit, 2, 4)
    by id: assert reldif(_iivw_exog_y_lag1, y[_n-1]) < 1e-15 if inrange(visit, 2, 4)

    keep if visit <= 4
    keep id t y
    _dx_oracle, endpoint(4.7)
    display as text "  D1: if-restricted b = " %12.9f `b_if' "  oracle b = " %12.9f r(b) ///
        "  oracle N = " r(N)
    assert r(N) == 240
    assert !missing(`b_if') & !missing(r(b))
    assert reldif(`b_if', r(b)) < 1e-10

    * Full-data positive control.
    _dx_panel5
    iivw_exogtest y, id(id) time(t) maxfu(6) nolog
    assert r(N) == 300
    assert r(n_modeled_events) == 240
}
if _rc == 0 {
    display as result "  PASS: D1 - selected suffix matches the native oracle"
    local ++pass_count
}
else {
    display as error "  FAIL: D1 (error `=_rc')"
    local ++fail_count
    local failed "`failed' D1"
}
}

**# D2: DX01 middle window and noncontiguous selection use selected history
local ++test_count
if `run_only' == 0 | `run_only' == 2 {
capture noisily {
    _dx_panel5
    iivw_exogtest y if inrange(visit, 2, 4), id(id) time(t) maxfu(4.7) nolog
    local n_if = r(N)
    matrix R = r(results)
    local b_if = R[1, 3]
    * The first SELECTED visit (visit 2) has no selected prior history.
    quietly count if visit == 2 & !missing(_iivw_exog_y_lag1)
    assert r(N) == 0
    quietly count if inlist(visit, 1, 5) & !missing(_iivw_exog_y_lag1)
    assert r(N) == 0

    _dx_panel5
    keep if inrange(visit, 2, 4)
    iivw_exogtest y, id(id) time(t) maxfu(4.7) nolog
    matrix K = r(results)
    display as text "  D2: window if b = " %12.9f `b_if' "  kept b = " %12.9f K[1, 3]
    assert `n_if' == r(N)
    assert `n_if' == 180
    assert !missing(`b_if') & !missing(K[1, 3])
    assert reldif(`b_if', K[1, 3]) < 1e-12

    * Noncontiguous: drop visit 3 in the middle. The visit-4 lag is visit 2.
    _dx_panel5
    iivw_exogtest y if visit != 3, id(id) time(t) maxfu(6) nolog
    local n_if = r(N)
    matrix R = r(results)
    local b_if = R[1, 3]
    sort id t
    assert !missing(_iivw_exog_y_lag1) if visit == 4
    by id: assert reldif(_iivw_exog_y_lag1, y[_n-2]) < 1e-15 if visit == 4
    _dx_panel5
    drop if visit == 3
    iivw_exogtest y, id(id) time(t) maxfu(6) nolog
    matrix K = r(results)
    assert `n_if' == r(N)
    assert !missing(`b_if') & !missing(K[1, 3])
    assert reldif(`b_if', K[1, 3]) < 1e-12

    * A missing or inconsistent end of follow-up on an excluded row is not an
    * input; the same value on a selected row is still refused.
    _dx_panel5
    gen double fu = 5.5
    replace fu = . if visit == 5 & id == 1
    replace fu = 1 if visit == 5 & id == 2
    iivw_exogtest y if visit <= 4, id(id) time(t) censor(fu) nolog
    assert r(N) == 240
    capture noisily iivw_exogtest y if visit != 1, id(id) time(t) censor(fu) ///
        generate(g2_) nolog
    assert _rc == 198
}
if _rc == 0 {
    display as result "  PASS: D2 - window/noncontiguous restrictions use selected history only"
    local ++pass_count
}
else {
    display as error "  FAIL: D2 (error `=_rc')"
    local ++fail_count
    local failed "`failed' D2"
}
}

**# D3: DX02 any Efron tie withholds the target verdict
local ++test_count
if `run_only' == 0 | `run_only' == 3 {
capture noisily {
    _dx_balpanel
    quietly iivw_weight, id(id) time(t) visit_cov(z) stabcov(z) maxfu(4) nolog
    quietly summarize _iivw_iw
    assert !missing(r(min), r(max))
    assert reldif(r(min), 1) < 1e-12 & reldif(r(max), 1) < 1e-12
    iivw_balance, balcut(.000001)
    * Untied Efron: verdict issued.
    assert "`r(target_status)'" == "identified"
    assert "`r(balance_flag)'" == "within_rule"

    * Twenty final visits share one time; all other event times are unique.
    replace t = 2.5 if visit == 3 & id <= 20
    quietly iivw_weight, id(id) time(t) visit_cov(z) stabcov(z) maxfu(4) nolog replace
    local mult = r(tie_multiplicity)
    display as text "  D3: sparse tie multiplicity = " %9.7f `mult'
    assert `mult' > 1 & `mult' < 1.1
    iivw_balance, balcut(.000001)
    assert "`r(target_status)'" == "tie_method_efron"
    assert "`r(balance_flag)'" == "not_assessed"
    * The numerical contrast is still returned.
    assert r(balance_max_tsmd) > 0 & r(balance_max_tsmd) < .
    assert r(ess) < .

    * Same tied panel under Breslow: verdict available.
    quietly iivw_weight, id(id) time(t) visit_cov(z) stabcov(z) maxfu(4) nolog replace breslow
    iivw_balance, balcut(.000001)
    assert "`r(target_status)'" == "identified"
    assert "`r(balance_flag)'" == "within_rule"
}
if _rc == 0 {
    display as result "  PASS: D3 - sparse Efron ties withhold the verdict"
    local ++pass_count
}
else {
    display as error "  FAIL: D3 (error `=_rc')"
    local ++fail_count
    local failed "`failed' D3"
}
}

**# D4: DX03 extra covariates are descriptive only
local ++test_count
if `run_only' == 0 | `run_only' == 4 {
capture noisily {
    _dx_balpanel
    quietly iivw_weight, id(id) time(t) visit_cov(z) stabcov(z) maxfu(4) nolog
    iivw_balance, balcut(.000001)
    local base_max = r(balance_max_tsmd)
    local base_flag "`r(balance_flag)'"
    iivw_balance extra, balcut(.000001)
    matrix B = r(balance)
    display as text "  D4: modeled max = " %12.4e `base_max' ///
        "  with extra = " %12.4e r(balance_max_tsmd)
    assert r(balance_max_tsmd) == `base_max'
    assert "`r(balance_flag)'" == "`base_flag'"
    assert "`r(balance_flag)'" == "within_rule"
    * The extra row is still reported, marked not modeled.
    assert rowsof(B) == 2
    assert B[1, 8] == 1 & B[2, 8] == 0
    assert "`r(extra_covars)'" == "extra"
    * r(target) still reports the extra row's own target SMD (descriptive),
    * and the verdict maximum is exactly the modeled row's.
    matrix T = r(target)
    assert rowsof(T) == 2 & colsof(T) == 4
    assert T[1, 4] == 1 & T[2, 4] == 0
    assert !missing(T[2, 3])
    assert abs(T[2, 3]) > .5
    assert abs(T[1, 3]) == r(balance_max_tsmd)
    * ...and its own verdict.
    assert r(extra_max_tsmd) == abs(T[2, 3])
    assert "`r(extra_flag)'" == "exceeds_rule"
}
if _rc == 0 {
    display as result "  PASS: D4 - extra covariates do not move the modeled verdict"
    local ++pass_count
}
else {
    display as error "  FAIL: D4 (error `=_rc')"
    local ++fail_count
    local failed "`failed' D4"
}
}

**# D5: DX04 xtreg within/between twins are not the same estimand
local ++test_count
if `run_only' == 0 | `run_only' == 5 {
capture noisily {
    clear
    set seed 333
    set obs 80
    gen long id = _n
    gen double bx = rnormal()
    expand 4
    bysort id: gen byte t = _n
    gen double x = bx + rnormal()
    gen double y = -2 * bx + 3 * (x - bx) + rnormal() * .1
    xtset id t
    quietly xtreg y x, fe
    estimates store FE
    quietly xtreg y x, be
    estimates store BE
    assert "`e(cmd)'" == "xtreg"

    capture noisily iivw_diagnose x, unweighted(FE) weighted(BE) adjusted(BE)
    assert _rc == 198

    iivw_diagnose x, unweighted(FE) weighted(BE) adjusted(BE) force
    matrix D = r(decomp)
    assert r(decomposable) == 0
    assert missing(D[4, 1]) & missing(D[5, 1])
    * Descriptive gaps remain.
    assert !missing(D[1, 1])

    iivw_diagnose x, unweighted(FE) weighted(FE) adjusted(FE)
    assert r(decomposable) == 1
}
if _rc == 0 {
    display as result "  PASS: D5 - xtreg fe/be twins refused"
    local ++pass_count
}
else {
    display as error "  FAIL: D5 (error `=_rc')"
    local ++fail_count
    local failed "`failed' D5"
}
}

**# D6: DX05 contrast mode is never decomposable
local ++test_count
if `run_only' == 0 | `run_only' == 6 {
capture noisily {
    clear
    set seed 334
    set obs 200
    gen long id = _n
    gen double x = rnormal()
    gen double y = 1 + .5 * x + rnormal()
    regress y x, vce(cluster id)
    estimates store M0
    iivw_diagnose x, unweighted(M0) weighted(M0) adjusted(M0) estimand(contrast)
    matrix D = r(decomp)
    assert r(decomposable) == 0
    assert "`r(conclusion)'" == "movement_only"
    assert missing(D[4, 1]) & missing(D[5, 1])
    assert r(sample_identical) == 1
    iivw_diagnose x, unweighted(M0) weighted(M0) adjusted(M0)
    assert r(decomposable) == 1
}
if _rc == 0 {
    display as result "  PASS: D6 - contrast is movement only in r(decomposable) too"
    local ++pass_count
}
else {
    display as error "  FAIL: D6 (error `=_rc')"
    local ++fail_count
    local failed "`failed' D6"
}
}

**# D7: DX06 tie statistics describe the fitted models only
local ++test_count
if `run_only' == 0 | `run_only' == 7 {
capture noisily {
    * Skipped group: 3 subjects with a constant outcome are never fitted.
    clear
    set seed 2222
    set obs 33
    gen long id = _n
    gen byte arm = id > 30
    expand 4
    bysort id: gen byte visit = _n
    gen double t = visit + runiform() * .1
    gen double y = rnormal() + .1 * visit
    preserve
    replace y = 1 if arm == 1
    iivw_exogtest y, id(id) time(t) by(arm) maxfu(5) nolog
    assert r(n_models) == 1 & r(n_skipped) == 1
    assert r(N) == 120
    * 30 fitted subjects x 3 modeled events.
    assert r(n_modeled_events) == 90
    assert r(n_event_times) == 90
    assert r(tie_multiplicity) == 1
    restore
    * Positive control: the second group fits and its 9 events count.
    iivw_exogtest y, id(id) time(t) by(arm) maxfu(5) nolog
    assert r(n_models) == 2
    assert r(n_modeled_events) == 99

    * Independent clocks: two groups, each untied, sharing clock values.
    clear
    set seed 2222
    set obs 60
    gen long id = _n
    gen byte arm = id > 30
    expand 4
    bysort id: gen byte visit = _n
    gen double t = visit + mod(id - 1, 30) * .001
    gen double y = rnormal() + .1 * visit
    iivw_exogtest y, id(id) time(t) by(arm) maxfu(5) nolog breslow
    assert r(n_modeled_events) == 180
    assert r(n_event_times) == 180
    assert r(tie_multiplicity) == 1

    * Positive control: real within-model ties are still counted. Times on
    * a coarse grid tie within each model; the expected count of distinct
    * event times is taken per (model, time) from the fixture itself.
    replace t = round(visit + runiform() * .9, .25)
    bysort id (t): replace t = t + .001 * (_n - 1) if t == t[_n-1]
    egen byte _tag = tag(arm t) if visit >= 2
    quietly count if _tag == 1
    local want_times = r(N)
    egen byte _tagall = tag(t) if visit >= 2
    quietly count if _tagall == 1
    local want_global = r(N)
    drop _tag _tagall
    display as text "  D7: per-model distinct times = `want_times', global = `want_global'"
    assert `want_times' < 180
    iivw_exogtest y, id(id) time(t) by(arm) maxfu(5) nolog breslow replace
    assert r(n_models) == 2
    assert r(n_modeled_events) == 180
    assert r(n_event_times) == `want_times'
    assert !missing(r(tie_multiplicity)) & !missing(180 / `want_times')
    assert reldif(r(tie_multiplicity), 180 / `want_times') < 1e-12
}
if _rc == 0 {
    display as result "  PASS: D7 - tie statistics count fitted models and per-model clocks"
    local ++pass_count
}
else {
    display as error "  FAIL: D7 (error `=_rc')"
    local ++fail_count
    local failed "`failed' D7"
}
}

**# D8: WM02 origin- and unit-invariant terminal intervals downstream
local ++test_count
if `run_only' == 0 | `run_only' == 8 {
capture noisily {
    foreach clock in regular shifted tiny {
        _dx_gap
        local scale = 1
        local origin = 0
        if "`clock'" == "shifted" local origin = 1000000000
        if "`clock'" == "tiny"    local scale = .000000001
        replace t = t * `scale' + `origin'
        gen double endpoint = 5 * `scale' + `origin'
        * Expected terminal rows from the fixture design, not the package.
        bysort id (t): gen byte want = _n == _N & t < endpoint
        quietly count if want
        local want_term = r(N)
        quietly count
        local want_exogN = r(N)

        quietly iivw_weight, id(id) time(t) visit_cov(z) censor(endpoint) nolog
        local w_ncens = r(n_censor_rows)
        quietly iivw_balance
        local nr_`clock' = r(refit_n_censrows)
        local ts_`clock' = r(balance_max_tsmd)
        local st_`clock' "`r(target_status)'"
        quietly iivw_exogtest y, id(id) time(t) censor(endpoint) nolog
        matrix X = r(results)
        local en_`clock' = r(N)
        local eb_`clock' = X[1, 3]
        display as text "  D8 `clock': want=`want_term' weight=`w_ncens' " ///
            "balance=`nr_`clock'' status=`st_`clock'' exogN=`en_`clock''"
        assert `want_term' == 200
        assert `w_ncens' == `want_term'
        assert `nr_`clock'' == `want_term'
        assert "`st_`clock''" == "identified"
        assert `en_`clock'' == `want_exogN'
    }
    foreach clock in shifted tiny {
        assert !missing(`ts_`clock'') & !missing(`ts_regular')
        assert reldif(`ts_`clock'', `ts_regular') < 1e-6
        assert !missing(`eb_`clock'') & !missing(`eb_regular')
        assert reldif(`eb_`clock'', `eb_regular') < 1e-6
    }
}
if _rc == 0 {
    display as result "  PASS: D8 - terminal intervals survive clock origin and unit"
    local ++pass_count
}
else {
    display as error "  FAIL: D8 (error `=_rc')"
    local ++fail_count
    local failed "`failed' D8"
}
}

**# D9: WM02 maxfu() is one exact numeric token in iivw_exogtest
local ++test_count
if `run_only' == 0 | `run_only' == 9 {
capture noisily {
    foreach tok in 5 5e0 +1.4000000000000X+002 {
        _dx_gap
        iivw_exogtest y, id(id) time(t) maxfu(`tok') nolog
        matrix M = r(results)
        assert r(N) == 1000
        if "`tok'" == "5" local b5 = M[1, 3]
        assert !missing(M[1, 3]) & !missing(`b5')
        assert reldif(M[1, 3], `b5') < 1e-12
    }
    foreach tok in . .a banana "1 2" "1+2" {
        _dx_gap
        capture noisily iivw_exogtest y, id(id) time(t) maxfu(`tok') nolog
        display as text "  D9: maxfu(`tok') rc = " _rc
        assert _rc == 198
    }
    * Full double precision survives: .2 + 2^-54 is a different double from
    * .2, and the sub-ulp interval after a visit at .2 is a real interval.
    _dx_endpanel
    local tok : display %21x (.2 + 2^-54)
    iivw_exogtest y, id(id) time(t) maxfu(`tok') nolog
    assert r(N) == 360
    _dx_endpanel
    iivw_exogtest y, id(id) time(t) maxfu(0.20000000000000004) nolog
    assert r(N) == 360
}
if _rc == 0 {
    display as result "  PASS: D9 - maxfu() token parsed exactly"
    local ++pass_count
}
else {
    display as error "  FAIL: D9 (error `=_rc')"
    local ++fail_count
    local failed "`failed' D9"
}
}

**# D10: WM02 encoded endpoints in iivw_exogtest
local ++test_count
if `run_only' == 0 | `run_only' == 10 {
capture noisily {
    * Adjacent double endpoint: 120 positive terminal intervals.
    _dx_endpanel
    replace endpoint = .2 + 2^-54
    iivw_exogtest y, id(id) time(t) censor(endpoint) nolog
    assert r(N) == 360
    * Two distinct floats.
    _dx_endpanel
    recast float t, force
    recast float endpoint, force
    replace endpoint = float(.2) + 2^-26
    assert endpoint > t if visit == 3
    iivw_exogtest y, id(id) time(t) censor(endpoint) nolog
    assert r(N) == 360
    * Exact equality: no terminal interval.
    _dx_endpanel
    iivw_exogtest y, id(id) time(t) censor(endpoint) nolog
    assert r(N) == 240
    * Mixed precision equal at float resolution: the same instant, resolved
    * as iivw_weight resolves it (no terminal interval, no refusal).
    _dx_endpanel
    recast float t, force
    iivw_exogtest y, id(id) time(t) censor(endpoint) nolog
    assert r(N) == 240
    quietly iivw_weight, id(id) time(t) censor(endpoint) visit_cov(y) nolog
    assert r(n_censor_rows) == 0
    _dx_endpanel
    recast float t, force
    iivw_exogtest y, id(id) time(t) maxfu(.2) nolog
    assert r(N) == 240
    * A genuine violation is still refused.
    _dx_endpanel
    replace endpoint = .2 - 1e-9
    capture noisily iivw_exogtest y, id(id) time(t) censor(endpoint) nolog
    assert _rc == 198
    _dx_endpanel
    capture noisily iivw_exogtest y, id(id) time(t) maxfu(.1999999) nolog
    assert _rc == 198
}
if _rc == 0 {
    display as result "  PASS: D10 - encoded endpoints compared exactly"
    local ++pass_count
}
else {
    display as error "  FAIL: D10 (error `=_rc')"
    local ++fail_count
    local failed "`failed' D10"
}
}

**# D11: WM02 balance replays the stored maxfu() token
local ++test_count
if `run_only' == 0 | `run_only' == 11 {
capture noisily {
    * maxfu() one representable step above the last visit on a large-origin
    * clock: iivw_weight keeps the terminal intervals, so balance must too.
    _dx_endpanel
    replace t = t + 1000000000
    quietly summarize t if visit == 3
    assert r(min) == r(max)
    local tok : display %21x (r(max) + 2^-23)
    quietly iivw_weight, id(id) time(t) visit_cov(y) maxfu(`tok') nolog
    local w_ncens = r(n_censor_rows)
    assert `w_ncens' == 120
    quietly iivw_balance
    display as text "  D11: weight n_censor_rows = `w_ncens', balance refit = " ///
        r(refit_n_censrows) " status = `r(target_status)'"
    assert r(refit_n_censrows) == `w_ncens'
    * Every visit-3 time is tied here, so the Efron contract withholds the
    * verdict; the replayed terminal intervals are what this case pins.
    assert "`r(target_status)'" == "tie_method_efron"
}
if _rc == 0 {
    display as result "  PASS: D11 - balance replays the stored maxfu() exactly"
    local ++pass_count
}
else {
    display as error "  FAIL: D11 (error `=_rc')"
    local ++fail_count
    local failed "`failed' D11"
}
}

**# D12-D14 fixture: one rate per subject, visit_cov(z) only
capture program drop _dx_misspec
program define _dx_misspec
    version 16.0
    syntax , RATE(string)
    clear
    set seed 9101
    set obs 300
    gen long id = _n
    gen double z = rnormal()
    gen double u = rnormal()
    gen byte x = runiform() < .5
    expand 15
    bysort id: gen int visit = _n
    gen double rate = `rate'
    bysort id (visit): gen double t = sum(-ln(runiform()) / rate)
    replace t = 0 if visit == 1
    keep if t < 3
    gen double fu = 3
    gen double z2 = z^2
end

**# D12: misspecification is flagged by the extra verdict
local ++test_count
if `run_only' == 0 | `run_only' == 12 {
capture noisily {
    foreach sc in z2 u {
        if "`sc'" == "z2" _dx_misspec, rate(exp(.9 * z^2))
        else              _dx_misspec, rate(exp(.3 * z + 1.2 * u))
        quietly iivw_weight, id(id) time(t) visit_cov(z) censor(fu) nolog
        iivw_balance `sc'
        matrix T = r(target)
        display as text "  D12 `sc': modeled max = " %7.4f r(balance_max_tsmd) ///
            " (`r(balance_flag)'), extra max = " %7.4f r(extra_max_tsmd) ///
            " (`r(extra_flag)')"
        assert "`r(target_status)'" == "identified"
        assert "`r(extra_flag)'" == "exceeds_rule"
        assert !missing(r(extra_max_tsmd))
        assert r(extra_max_tsmd) > .3
        * The modeled verdict stays modeled-only: it is z's row, not `sc''s.
        assert T[1, 4] == 1 & T[2, 4] == 0
        assert r(balance_max_tsmd) == abs(T[1, 3])
        assert r(extra_max_tsmd) == abs(T[2, 3])
        assert r(balance_max_tsmd) < .1
        assert "`r(balance_flag)'" == "within_rule"
    }
    * Correctly specified control: the true intensity is linear in z.
    _dx_misspec, rate(exp(.6 * z))
    quietly iivw_weight, id(id) time(t) visit_cov(z) censor(fu) nolog
    iivw_balance z2 u
    display as text "  D12 control: extra max = " %7.4f r(extra_max_tsmd) " (`r(extra_flag)')"
    assert !missing(r(extra_max_tsmd))
    assert "`r(extra_flag)'" == "within_rule"
}
if _rc == 0 {
    display as result "  PASS: D12 - misspecified visit models are flagged by r(extra_flag)"
    local ++pass_count
}
else {
    display as error "  FAIL: D12 (error `=_rc')"
    local ++fail_count
    local failed "`failed' D12"
}
}

**# D13: a listed model covariate is modeled and counted once
local ++test_count
if `run_only' == 0 | `run_only' == 13 {
capture noisily {
    _dx_misspec, rate(exp(.9 * z^2))
    quietly iivw_weight, id(id) time(t) visit_cov(z) censor(fu) nolog
    iivw_balance z2
    local m1 = r(balance_max_tsmd)
    local e1 = r(extra_max_tsmd)
    iivw_balance z z2
    matrix T = r(target)
    assert rowsof(T) == 2
    assert T[1, 4] == 1 & T[2, 4] == 0
    assert r(balance_max_tsmd) == `m1'
    assert r(extra_max_tsmd) == `e1'
    assert "`r(extra_flag)'" == "exceeds_rule"
    * Only the model covariate listed: no extra covariate, no extra verdict.
    iivw_balance z
    assert rowsof(r(target)) == 1
    assert "`r(extra_flag)'" == ""
    assert missing(r(extra_max_tsmd))
    assert r(balance_max_tsmd) == `m1'
    iivw_balance
    assert "`r(extra_flag)'" == ""
    assert missing(r(extra_max_tsmd))
}
if _rc == 0 {
    display as result "  PASS: D13 - duplicate covariates modeled once; no extras, no extra verdict"
    local ++pass_count
}
else {
    display as error "  FAIL: D13 (error `=_rc')"
    local ++fail_count
    local failed "`failed' D13"
}
}

**# D14: degenerate modeled covariate, finite extra
local ++test_count
if `run_only' == 0 | `run_only' == 14 {
capture noisily {
    * x is the only modeled covariate; restricting the report to x == 1 makes
    * it constant there, so its target SMD is undefined. u still varies.
    _dx_misspec, rate(exp(.5 * x + 1.2 * u))
    quietly iivw_weight, id(id) time(t) visit_cov(x) censor(fu) nolog
    iivw_balance u if x == 1
    matrix T = r(target)
    display as text "  D14: modeled = " r(balance_max_tsmd) " (`r(balance_flag)', " ///
        "`r(target_status)'), extra = " %7.4f r(extra_max_tsmd) " (`r(extra_flag)')"
    assert missing(T[1, 3])
    * The primary verdict is not rescued by the extra covariate.
    assert missing(r(balance_max_tsmd))
    assert "`r(target_status)'" == "unavailable"
    assert !inlist("`r(balance_flag)'", "within_rule", "exceeds_rule")
    * The extra verdict is reported separately.
    assert !missing(r(extra_max_tsmd))
    assert r(extra_max_tsmd) == abs(T[2, 3])
    assert "`r(extra_flag)'" == "exceeds_rule"
}
if _rc == 0 {
    display as result "  PASS: D14 - degenerate modeled max stays unavailable; extra verdict reported"
    local ++pass_count
}
else {
    display as error "  FAIL: D14 (error `=_rc')"
    local ++fail_count
    local failed "`failed' D14"
}
}

**# Summary
iivw_qa_summary, name(test_iivw_audit_2026_10_05_diag) tests(`test_count') ///
    pass(`pass_count') fail(`fail_count') runonly(`run_only') ///
    failedtests("`failed'")
