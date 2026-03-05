* test_iivw.do - Functional tests for iivw package
* Tests: basic functionality, options, error handling, return values
*
* Usage:
*   do iivw/qa/test_iivw.do          Run all tests
*   do iivw/qa/test_iivw.do 5        Run only test 5

version 16.0
set more off
set varabbrev off

args run_only
if "`run_only'" == "" local run_only = 0

* --- Load commands ---
capture program drop iivw
quietly run iivw/iivw.ado
capture program drop iivw_weight
quietly run iivw/iivw_weight.ado
capture program drop iivw_fit
quietly run iivw/iivw_fit.ado
capture program drop _iivw_check_weighted
quietly run iivw/_iivw_check_weighted.ado
capture program drop _iivw_get_settings
quietly run iivw/_iivw_get_settings.ado

local test_count = 0
local pass_count = 0
local fail_count = 0

* =============================================================================
* Helper: prepare relapses.dta for iivw
* =============================================================================
capture program drop _setup_relapses
program define _setup_relapses
    version 16.0
    set varabbrev off
    use "/home/tpcopeland/Stata-Tools/_data/relapses.dta", clear
    sort id edss_date
    * Use days since diagnosis as time variable (avoids month-rounding ties)
    gen double days = edss_date - dx_date
    * Break any remaining ties with small jitter
    bysort id (edss_date): replace days = days + (_n - 1) * 0.001 ///
        if _n > 1 & days == days[_n-1]
    * Binary relapse indicator at each visit
    gen byte relapse = !missing(relapse_date)
    * Simulated time-invariant treatment (confounded by baseline EDSS)
    set seed 20260305
    tempvar _base_edss _rand
    bysort id (edss_date): gen double `_base_edss' = edss[1]
    gen double `_rand' = runiform()
    bysort id: gen byte treated = (`_rand'[1] < invlogit(-1 + 0.3 * `_base_edss'[1]))
    label variable days "Days since diagnosis"
    label variable relapse "Relapse at visit (0/1)"
    label variable treated "Treatment group (0/1)"
end

* =============================================================================
* TEST 1: iivw overview command runs
* =============================================================================
local ++test_count
if `run_only' == 0 | `run_only' == 1 {
    capture noisily {
        iivw
        assert r(n_commands) == 2
        assert "`r(version)'" == "1.0.0"
    }
    if _rc == 0 {
        display as result "  PASS: Test 1 - iivw overview runs and returns metadata"
        local ++pass_count
    }
    else {
        display as error "  FAIL: Test 1 - iivw overview (error `=_rc')"
        local ++fail_count
    }
}

* =============================================================================
* TEST 2: Basic IIW with relapses.dta
* =============================================================================
local ++test_count
if `run_only' == 0 | `run_only' == 2 {
    capture noisily {
        _setup_relapses
        iivw_weight, id(id) time(days) visit_cov(edss relapse) nolog
        assert r(N) == _N
        assert r(n_ids) == 500
        assert r(mean_weight) > 0
        assert "`r(weighttype)'" == "iivw"
        confirm variable _iivw_weight
        confirm variable _iivw_iw
    }
    if _rc == 0 {
        display as result "  PASS: Test 2 - IIW with relapses.dta"
        local ++pass_count
    }
    else {
        display as error "  FAIL: Test 2 - IIW with relapses.dta (error `=_rc')"
        local ++fail_count
    }
}

* =============================================================================
* TEST 3: FIPTIW with relapses.dta
* =============================================================================
local ++test_count
if `run_only' == 0 | `run_only' == 3 {
    capture noisily {
        _setup_relapses
        bysort id (days): gen double edss_bl = edss[1]
        iivw_weight, id(id) time(days) visit_cov(edss relapse) ///
            treat(treated) treat_cov(edss_bl) truncate(1 99) nolog
        assert "`r(weighttype)'" == "fiptiw"
        assert r(n_truncated) >= 0
        confirm variable _iivw_iw
        confirm variable _iivw_tw
        confirm variable _iivw_weight
    }
    if _rc == 0 {
        display as result "  PASS: Test 3 - FIPTIW with relapses.dta"
        local ++pass_count
    }
    else {
        display as error "  FAIL: Test 3 - FIPTIW with relapses.dta (error `=_rc')"
        local ++fail_count
    }
}

* =============================================================================
* TEST 4: IPTW-only mode
* =============================================================================
local ++test_count
if `run_only' == 0 | `run_only' == 4 {
    capture noisily {
        _setup_relapses
        bysort id (days): gen double edss_bl = edss[1]
        iivw_weight, id(id) time(days) visit_cov(edss) ///
            treat(treated) treat_cov(edss_bl) wtype(iptw) nolog
        assert "`r(weighttype)'" == "iptw"
        confirm variable _iivw_tw
        confirm variable _iivw_weight
    }
    if _rc == 0 {
        display as result "  PASS: Test 4 - IPTW-only mode"
        local ++pass_count
    }
    else {
        display as error "  FAIL: Test 4 - IPTW-only mode (error `=_rc')"
        local ++fail_count
    }
}

* =============================================================================
* TEST 5: iivw_fit after iivw_weight (GEE)
* =============================================================================
local ++test_count
if `run_only' == 0 | `run_only' == 5 {
    capture noisily {
        _setup_relapses
        bysort id (days): gen double edss_bl = edss[1]
        iivw_weight, id(id) time(days) visit_cov(edss relapse) ///
            treat(treated) treat_cov(edss_bl) nolog
        iivw_fit edss treated edss_bl, model(gee) timespec(linear) nolog
        assert e(N) > 0
        assert "`e(iivw_cmd)'" == "iivw_fit"
        assert "`e(iivw_model)'" == "gee"
        assert "`e(iivw_weighttype)'" == "fiptiw"
    }
    if _rc == 0 {
        display as result "  PASS: Test 5 - iivw_fit GEE after weighting"
        local ++pass_count
    }
    else {
        display as error "  FAIL: Test 5 - iivw_fit GEE (error `=_rc')"
        local ++fail_count
    }
}

* =============================================================================
* TEST 6: iivw_fit with quadratic time specification
* =============================================================================
local ++test_count
if `run_only' == 0 | `run_only' == 6 {
    capture noisily {
        _setup_relapses
        iivw_weight, id(id) time(days) visit_cov(edss relapse) nolog
        iivw_fit edss relapse, model(gee) timespec(quadratic) nolog
        assert "`e(iivw_timespec)'" == "quadratic"
        confirm variable _iivw_time_sq
    }
    if _rc == 0 {
        display as result "  PASS: Test 6 - iivw_fit with quadratic time"
        local ++pass_count
    }
    else {
        display as error "  FAIL: Test 6 - iivw_fit quadratic (error `=_rc')"
        local ++fail_count
    }
}

* =============================================================================
* TEST 7: iivw_fit with natural spline time
* =============================================================================
local ++test_count
if `run_only' == 0 | `run_only' == 7 {
    capture noisily {
        _setup_relapses
        iivw_weight, id(id) time(days) visit_cov(edss relapse) nolog
        iivw_fit edss relapse, model(gee) timespec(ns(3)) nolog
        assert "`e(iivw_timespec)'" == "ns(3)"
        confirm variable _iivw_tns1
    }
    if _rc == 0 {
        display as result "  PASS: Test 7 - iivw_fit with ns(3) time"
        local ++pass_count
    }
    else {
        display as error "  FAIL: Test 7 - iivw_fit ns(3) (error `=_rc')"
        local ++fail_count
    }
}

* =============================================================================
* TEST 8: iivw_fit with timespec(none)
* =============================================================================
local ++test_count
if `run_only' == 0 | `run_only' == 8 {
    capture noisily {
        _setup_relapses
        iivw_weight, id(id) time(days) visit_cov(edss relapse) nolog
        iivw_fit edss relapse, model(gee) timespec(none) nolog
        assert "`e(iivw_timespec)'" == "none"
    }
    if _rc == 0 {
        display as result "  PASS: Test 8 - iivw_fit with timespec(none)"
        local ++pass_count
    }
    else {
        display as error "  FAIL: Test 8 - iivw_fit timespec none (error `=_rc')"
        local ++fail_count
    }
}

* =============================================================================
* TEST 9: generate() option with custom prefix
* =============================================================================
local ++test_count
if `run_only' == 0 | `run_only' == 9 {
    capture noisily {
        _setup_relapses
        iivw_weight, id(id) time(days) visit_cov(edss relapse) ///
            generate(w_) nolog
        confirm variable w_iw
        confirm variable w_weight
        assert "`r(weight_var)'" == "w_weight"
    }
    if _rc == 0 {
        display as result "  PASS: Test 9 - generate() custom prefix"
        local ++pass_count
    }
    else {
        display as error "  FAIL: Test 9 - generate() (error `=_rc')"
        local ++fail_count
    }
}

* =============================================================================
* TEST 10: replace option
* =============================================================================
local ++test_count
if `run_only' == 0 | `run_only' == 10 {
    capture noisily {
        _setup_relapses
        iivw_weight, id(id) time(days) visit_cov(edss) nolog
        * Run again with replace
        iivw_weight, id(id) time(days) visit_cov(edss relapse) replace nolog
        confirm variable _iivw_weight
    }
    if _rc == 0 {
        display as result "  PASS: Test 10 - replace option works"
        local ++pass_count
    }
    else {
        display as error "  FAIL: Test 10 - replace (error `=_rc')"
        local ++fail_count
    }
}

* =============================================================================
* TEST 11: lagvars option
* =============================================================================
local ++test_count
if `run_only' == 0 | `run_only' == 11 {
    capture noisily {
        _setup_relapses
        iivw_weight, id(id) time(days) visit_cov(edss) lagvars(edss) nolog
        confirm variable edss_lag1
        * First obs per subject should be missing
        bysort id (days): assert missing(edss_lag1) if _n == 1
    }
    if _rc == 0 {
        display as result "  PASS: Test 11 - lagvars creates lagged variables"
        local ++pass_count
    }
    else {
        display as error "  FAIL: Test 11 - lagvars (error `=_rc')"
        local ++fail_count
    }
}

* =============================================================================
* TEST 12: stabcov option (stabilized IIW)
* =============================================================================
local ++test_count
if `run_only' == 0 | `run_only' == 12 {
    capture noisily {
        _setup_relapses
        iivw_weight, id(id) time(days) visit_cov(edss relapse) ///
            stabcov(relapse) nolog
        assert r(mean_weight) > 0
        confirm variable _iivw_weight
    }
    if _rc == 0 {
        display as result "  PASS: Test 12 - stabcov for stabilized IIW"
        local ++pass_count
    }
    else {
        display as error "  FAIL: Test 12 - stabcov (error `=_rc')"
        local ++fail_count
    }
}

* =============================================================================
* TEST 13: truncate option
* =============================================================================
local ++test_count
if `run_only' == 0 | `run_only' == 13 {
    capture noisily {
        _setup_relapses
        iivw_weight, id(id) time(days) visit_cov(edss relapse) ///
            truncate(5 95) nolog
        assert r(n_truncated) >= 0
        quietly summarize _iivw_weight
        local w_range = r(max) - r(min)
        assert `w_range' < .
    }
    if _rc == 0 {
        display as result "  PASS: Test 13 - truncate(5 95) bounds weights"
        local ++pass_count
    }
    else {
        display as error "  FAIL: Test 13 - truncate (error `=_rc')"
        local ++fail_count
    }
}

* =============================================================================
* TEST 14: Error - no observations
* =============================================================================
local ++test_count
if `run_only' == 0 | `run_only' == 14 {
    capture noisily {
        clear
        gen long id = .
        gen double t = .
        gen double v = .
        capture iivw_weight, id(id) time(t) visit_cov(v)
        assert _rc == 2000
    }
    if _rc == 0 {
        display as result "  PASS: Test 14 - Error on empty data"
        local ++pass_count
    }
    else {
        display as error "  FAIL: Test 14 - empty data error (error `=_rc')"
        local ++fail_count
    }
}

* =============================================================================
* TEST 15: Error - single visit per subject
* =============================================================================
local ++test_count
if `run_only' == 0 | `run_only' == 15 {
    capture noisily {
        clear
        set obs 10
        gen long id = _n
        gen double months = _n
        gen double severity = rnormal()
        capture iivw_weight, id(id) time(months) visit_cov(severity) nolog
        assert _rc == 198
    }
    if _rc == 0 {
        display as result "  PASS: Test 15 - Error on single visit per subject"
        local ++pass_count
    }
    else {
        display as error "  FAIL: Test 15 - single visit error (error `=_rc')"
        local ++fail_count
    }
}

* =============================================================================
* TEST 16: Error - non-binary treatment
* =============================================================================
local ++test_count
if `run_only' == 0 | `run_only' == 16 {
    capture noisily {
        _setup_relapses
        gen byte treat3 = mod(id, 3)
        capture iivw_weight, id(id) time(days) visit_cov(edss) ///
            treat(treat3) nolog
        assert _rc == 198
    }
    if _rc == 0 {
        display as result "  PASS: Test 16 - Error on non-binary treatment"
        local ++pass_count
    }
    else {
        display as error "  FAIL: Test 16 - non-binary treat error (error `=_rc')"
        local ++fail_count
    }
}

* =============================================================================
* TEST 17: Error - duplicate id-time
* =============================================================================
local ++test_count
if `run_only' == 0 | `run_only' == 17 {
    capture noisily {
        clear
        set obs 10
        gen long id = ceil(_n / 2)
        gen double months = 1
        gen double severity = rnormal()
        capture iivw_weight, id(id) time(months) visit_cov(severity) nolog
        assert _rc == 198
    }
    if _rc == 0 {
        display as result "  PASS: Test 17 - Error on duplicate id-time"
        local ++pass_count
    }
    else {
        display as error "  FAIL: Test 17 - duplicate id-time error (error `=_rc')"
        local ++fail_count
    }
}

* =============================================================================
* TEST 18: Error - iivw_fit without prior weighting
* =============================================================================
local ++test_count
if `run_only' == 0 | `run_only' == 18 {
    capture noisily {
        sysuse auto, clear
        capture iivw_fit price mpg weight
        assert _rc == 198
    }
    if _rc == 0 {
        display as result "  PASS: Test 18 - Error: iivw_fit without iivw_weight"
        local ++pass_count
    }
    else {
        display as error "  FAIL: Test 18 - fit without weight error (error `=_rc')"
        local ++fail_count
    }
}

* =============================================================================
* TEST 19: Error - existing weight vars without replace
* =============================================================================
local ++test_count
if `run_only' == 0 | `run_only' == 19 {
    capture noisily {
        _setup_relapses
        iivw_weight, id(id) time(days) visit_cov(edss) nolog
        capture iivw_weight, id(id) time(days) visit_cov(edss) nolog
        assert _rc == 110
    }
    if _rc == 0 {
        display as result "  PASS: Test 19 - Error without replace when vars exist"
        local ++pass_count
    }
    else {
        display as error "  FAIL: Test 19 - no replace error (error `=_rc')"
        local ++fail_count
    }
}

* =============================================================================
* TEST 20: Error - truncate bounds reversed
* =============================================================================
local ++test_count
if `run_only' == 0 | `run_only' == 20 {
    capture noisily {
        _setup_relapses
        capture iivw_weight, id(id) time(days) visit_cov(edss) ///
            truncate(99 1) nolog
        assert _rc == 198
    }
    if _rc == 0 {
        display as result "  PASS: Test 20 - Error on reversed truncate bounds"
        local ++pass_count
    }
    else {
        display as error "  FAIL: Test 20 - reversed truncate (error `=_rc')"
        local ++fail_count
    }
}

* =============================================================================
* TEST 21: Return values are complete
* =============================================================================
local ++test_count
if `run_only' == 0 | `run_only' == 21 {
    capture noisily {
        _setup_relapses
        iivw_weight, id(id) time(days) visit_cov(edss relapse) nolog
        assert r(N) > 0
        assert r(n_ids) > 0
        assert r(mean_weight) > 0
        assert r(sd_weight) > 0
        assert r(min_weight) > 0
        assert r(max_weight) > 0
        assert r(p1_weight) > 0
        assert r(p99_weight) > 0
        assert r(ess) > 0
        assert r(n_truncated) == 0
        assert "`r(weighttype)'" == "iivw"
        assert "`r(weight_var)'" == "_iivw_weight"
    }
    if _rc == 0 {
        display as result "  PASS: Test 21 - All r() return values populated"
        local ++pass_count
    }
    else {
        display as error "  FAIL: Test 21 - return values (error `=_rc')"
        local ++fail_count
    }
}

* =============================================================================
* TEST 22: Data preservation - N unchanged
* =============================================================================
local ++test_count
if `run_only' == 0 | `run_only' == 22 {
    capture noisily {
        _setup_relapses
        local N_before = _N
        iivw_weight, id(id) time(days) visit_cov(edss relapse) nolog
        assert _N == `N_before'
        local N_before2 = _N
        iivw_fit edss relapse, model(gee) timespec(linear) nolog
        assert _N == `N_before2'
    }
    if _rc == 0 {
        display as result "  PASS: Test 22 - Observation count preserved"
        local ++pass_count
    }
    else {
        display as error "  FAIL: Test 22 - data preservation (error `=_rc')"
        local ++fail_count
    }
}

* =============================================================================
* TEST 23: Dataset metadata characteristics stored
* =============================================================================
local ++test_count
if `run_only' == 0 | `run_only' == 23 {
    capture noisily {
        _setup_relapses
        iivw_weight, id(id) time(days) visit_cov(edss) nolog
        local w_flag : char _dta[_iivw_weighted]
        assert "`w_flag'" == "1"
        local w_id : char _dta[_iivw_id]
        assert "`w_id'" == "id"
        local w_time : char _dta[_iivw_time]
        assert "`w_time'" == "days"
        local w_type : char _dta[_iivw_weighttype]
        assert "`w_type'" == "iivw"
    }
    if _rc == 0 {
        display as result "  PASS: Test 23 - Dataset characteristics stored"
        local ++pass_count
    }
    else {
        display as error "  FAIL: Test 23 - characteristics (error `=_rc')"
        local ++fail_count
    }
}

* =============================================================================
* TEST 24: iivw_fit with binomial family
* =============================================================================
local ++test_count
if `run_only' == 0 | `run_only' == 24 {
    capture noisily {
        _setup_relapses
        bysort id (days): gen double edss_bl = edss[1]
        iivw_weight, id(id) time(days) visit_cov(edss) ///
            treat(treated) treat_cov(edss_bl) nolog
        iivw_fit relapse treated edss_bl, ///
            family(binomial) link(logit) timespec(linear) nolog
        assert "`e(iivw_model)'" == "gee"
    }
    if _rc == 0 {
        display as result "  PASS: Test 24 - iivw_fit binomial/logit family"
        local ++pass_count
    }
    else {
        display as error "  FAIL: Test 24 - binomial family (error `=_rc')"
        local ++fail_count
    }
}

* =============================================================================
* TEST 25: Error - time-varying treatment
* =============================================================================
local ++test_count
if `run_only' == 0 | `run_only' == 25 {
    capture noisily {
        _setup_relapses
        * Make treatment time-varying (violates assumption)
        replace treated = mod(_n, 2)
        capture iivw_weight, id(id) time(days) visit_cov(edss) ///
            treat(treated) nolog
        assert _rc == 198
    }
    if _rc == 0 {
        display as result "  PASS: Test 25 - Error on time-varying treatment"
        local ++pass_count
    }
    else {
        display as error "  FAIL: Test 25 - time-varying treat (error `=_rc')"
        local ++fail_count
    }
}

* =============================================================================
* SUMMARY
* =============================================================================
display ""
display as text "{hline 50}"
display as result "RESULT: test_iivw"
display as text "  Tests:  `test_count'"
display as text "  Passed: " as result "`pass_count'"
display as text "  Failed: " _continue
if `fail_count' > 0 {
    display as error "`fail_count'"
}
else {
    display as result "`fail_count'"
}
display as text "{hline 50}"

if `fail_count' == 0 {
    display as result "RESULT: ALL `pass_count' TESTS PASSED"
}
else {
    display as error "RESULT: `fail_count' TESTS FAILED"
}

clear
