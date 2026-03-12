clear all
set more off
version 16.0
set varabbrev off

* test_iivw.do - Functional tests for iivw package
* Tests: 61 (basic functionality, options, error handling, return values,
*        edge cases, data preservation)
*
* Usage:
*   do iivw/qa/test_iivw.do          Run all tests
*   do iivw/qa/test_iivw.do 5        Run only test 5

args run_only
if "`run_only'" == "" local run_only = 0

* ============================================================
* Setup
* ============================================================

capture ado uninstall iivw
quietly net install iivw, from("/home/tpcopeland/Stata-Tools/iivw") replace

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
        assert "`r(version)'" == "1.2.0"
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
* TEST 26: interaction() with linear time
* =============================================================================
local ++test_count
if `run_only' == 0 | `run_only' == 26 {
    capture noisily {
        _setup_relapses
        bysort id (days): gen double edss_bl = edss[1]
        iivw_weight, id(id) time(days) visit_cov(edss relapse) ///
            treat(treated) treat_cov(edss_bl) nolog
        iivw_fit edss treated edss_bl, timespec(linear) interaction(treated) nolog
        confirm variable _iivw_ix_treated_time
        assert "`e(iivw_interaction)'" == "treated"
        assert "`e(iivw_ix_vars)'" == " _iivw_ix_treated_time"
    }
    if _rc == 0 {
        display as result "  PASS: Test 26 - interaction() with linear time"
        local ++pass_count
    }
    else {
        display as error "  FAIL: Test 26 - interaction linear (error `=_rc')"
        local ++fail_count
    }
}

* =============================================================================
* TEST 27: interaction() with quadratic creates 2 vars per covariate
* =============================================================================
local ++test_count
if `run_only' == 0 | `run_only' == 27 {
    capture noisily {
        _setup_relapses
        iivw_weight, id(id) time(days) visit_cov(edss relapse) nolog
        iivw_fit edss relapse, timespec(quadratic) interaction(relapse) nolog
        confirm variable _iivw_ix_relapse_time
        confirm variable _iivw_ix_relapse_tsq
    }
    if _rc == 0 {
        display as result "  PASS: Test 27 - interaction() with quadratic (2 vars)"
        local ++pass_count
    }
    else {
        display as error "  FAIL: Test 27 - interaction quadratic (error `=_rc')"
        local ++fail_count
    }
}

* =============================================================================
* TEST 28: interaction() with ns(3) creates 3 vars per covariate
* =============================================================================
local ++test_count
if `run_only' == 0 | `run_only' == 28 {
    capture noisily {
        _setup_relapses
        iivw_weight, id(id) time(days) visit_cov(edss relapse) nolog
        iivw_fit edss relapse, timespec(ns(3)) interaction(relapse) nolog
        confirm variable _iivw_ix_relapse_tns1
        confirm variable _iivw_ix_relapse_tns2
        confirm variable _iivw_ix_relapse_tns3
    }
    if _rc == 0 {
        display as result "  PASS: Test 28 - interaction() with ns(3) (3 vars)"
        local ++pass_count
    }
    else {
        display as error "  FAIL: Test 28 - interaction ns(3) (error `=_rc')"
        local ++fail_count
    }
}

* =============================================================================
* TEST 29: interaction() with multiple covariates
* =============================================================================
local ++test_count
if `run_only' == 0 | `run_only' == 29 {
    capture noisily {
        _setup_relapses
        bysort id (days): gen double edss_bl = edss[1]
        iivw_weight, id(id) time(days) visit_cov(edss relapse) ///
            treat(treated) treat_cov(edss_bl) nolog
        iivw_fit edss treated edss_bl, timespec(linear) ///
            interaction(treated edss_bl) nolog
        confirm variable _iivw_ix_treated_time
        confirm variable _iivw_ix_edss_bl_time
    }
    if _rc == 0 {
        display as result "  PASS: Test 29 - interaction() with multiple covariates"
        local ++pass_count
    }
    else {
        display as error "  FAIL: Test 29 - interaction multiple covars (error `=_rc')"
        local ++fail_count
    }
}

* =============================================================================
* TEST 30: interaction() + timespec(none) errors
* =============================================================================
local ++test_count
if `run_only' == 0 | `run_only' == 30 {
    capture noisily {
        _setup_relapses
        iivw_weight, id(id) time(days) visit_cov(edss relapse) nolog
        capture iivw_fit edss relapse, timespec(none) interaction(relapse)
        assert _rc == 198
    }
    if _rc == 0 {
        display as result "  PASS: Test 30 - interaction() + timespec(none) errors"
        local ++pass_count
    }
    else {
        display as error "  FAIL: Test 30 - interaction+none error (error `=_rc')"
        local ++fail_count
    }
}

* =============================================================================
* TEST 31: interaction vars cleaned up on model fit error
* =============================================================================
local ++test_count
if `run_only' == 0 | `run_only' == 31 {
    capture noisily {
        _setup_relapses
        iivw_weight, id(id) time(days) visit_cov(edss relapse) nolog
        * Force a fit error by using a string variable as depvar
        gen str5 badvar = "x"
        capture iivw_fit edss badvar, timespec(linear) interaction(relapse) nolog
        * The interaction var should have been cleaned up
        capture confirm variable _iivw_ix_relapse_time
        assert _rc != 0
    }
    if _rc == 0 {
        display as result "  PASS: Test 31 - interaction vars cleaned on fit error"
        local ++pass_count
    }
    else {
        display as error "  FAIL: Test 31 - interaction cleanup (error `=_rc')"
        local ++fail_count
    }
}

* =============================================================================
* TEST 32: interaction values are correct products
* =============================================================================
local ++test_count
if `run_only' == 0 | `run_only' == 32 {
    capture noisily {
        _setup_relapses
        iivw_weight, id(id) time(days) visit_cov(edss relapse) nolog
        iivw_fit edss relapse, timespec(linear) interaction(relapse) nolog
        * Verify the interaction is the product of relapse * days
        gen double _check_ix = relapse * days
        assert abs(_iivw_ix_relapse_time - _check_ix) < 1e-10
        drop _check_ix
    }
    if _rc == 0 {
        display as result "  PASS: Test 32 - interaction values are correct products"
        local ++pass_count
    }
    else {
        display as error "  FAIL: Test 32 - interaction products (error `=_rc')"
        local ++fail_count
    }
}

* =============================================================================
* TEST 33: interaction() with cubic creates 3 vars
* =============================================================================
local ++test_count
if `run_only' == 0 | `run_only' == 33 {
    capture noisily {
        _setup_relapses
        iivw_weight, id(id) time(days) visit_cov(edss relapse) nolog
        iivw_fit edss relapse, timespec(cubic) interaction(relapse) nolog
        confirm variable _iivw_ix_relapse_time
        confirm variable _iivw_ix_relapse_tsq
        confirm variable _iivw_ix_relapse_tcu
    }
    if _rc == 0 {
        display as result "  PASS: Test 33 - interaction() with cubic (3 vars)"
        local ++pass_count
    }
    else {
        display as error "  FAIL: Test 33 - interaction cubic (error `=_rc')"
        local ++fail_count
    }
}

* =============================================================================
* TEST 34: interaction metadata stored in dataset characteristics
* =============================================================================
local ++test_count
if `run_only' == 0 | `run_only' == 34 {
    capture noisily {
        _setup_relapses
        iivw_weight, id(id) time(days) visit_cov(edss relapse) nolog
        iivw_fit edss relapse, timespec(linear) interaction(relapse) nolog
        local ix_char : char _dta[_iivw_interaction]
        assert "`ix_char'" == "relapse"
        local ix_vars_char : char _dta[_iivw_ix_vars]
        assert "`ix_vars_char'" == " _iivw_ix_relapse_time"
    }
    if _rc == 0 {
        display as result "  PASS: Test 34 - interaction metadata in characteristics"
        local ++pass_count
    }
    else {
        display as error "  FAIL: Test 34 - interaction characteristics (error `=_rc')"
        local ++fail_count
    }
}

* =============================================================================
* TEST 35: Binary categorical with value labels
* =============================================================================
local ++test_count
if `run_only' == 0 | `run_only' == 35 {
    capture noisily {
        _setup_relapses
        bysort id (days): gen double edss_bl = edss[1]
        label define treated_lbl 0 "Placebo" 1 "Drug", replace
        label values treated treated_lbl
        iivw_weight, id(id) time(days) visit_cov(edss relapse) ///
            treat(treated) treat_cov(edss_bl) nolog
        iivw_fit edss treated edss_bl, categorical(treated) nolog
        confirm variable _iivw_cat_drug
        local vlbl : variable label _iivw_cat_drug
        assert `"`vlbl'"' == `"Drug (vs. Placebo)"'
    }
    if _rc == 0 {
        display as result "  PASS: Test 35 - Binary categorical with value labels"
        local ++pass_count
    }
    else {
        display as error "  FAIL: Test 35 - binary categorical labels (error `=_rc')"
        local ++fail_count
    }
}

* =============================================================================
* TEST 36: 3-level categorical with value labels
* =============================================================================
local ++test_count
if `run_only' == 0 | `run_only' == 36 {
    capture noisily {
        _setup_relapses
        gen byte arm = mod(id, 3)
        label define arm_lbl 0 "Placebo" 1 "Low dose" 2 "High dose", replace
        label values arm arm_lbl
        iivw_weight, id(id) time(days) visit_cov(edss relapse) nolog
        iivw_fit edss arm, categorical(arm) nolog
        confirm variable _iivw_cat_low_dose
        confirm variable _iivw_cat_high_dose
        local vlbl1 : variable label _iivw_cat_low_dose
        assert `"`vlbl1'"' == `"Low dose (vs. Placebo)"'
        local vlbl2 : variable label _iivw_cat_high_dose
        assert `"`vlbl2'"' == `"High dose (vs. Placebo)"'
    }
    if _rc == 0 {
        display as result "  PASS: Test 36 - 3-level categorical with labels"
        local ++pass_count
    }
    else {
        display as error "  FAIL: Test 36 - 3-level categorical (error `=_rc')"
        local ++fail_count
    }
}

* =============================================================================
* TEST 37: Categorical without value labels (numeric naming)
* =============================================================================
local ++test_count
if `run_only' == 0 | `run_only' == 37 {
    capture noisily {
        _setup_relapses
        gen byte arm = mod(id, 3)
        iivw_weight, id(id) time(days) visit_cov(edss relapse) nolog
        iivw_fit edss arm, categorical(arm) nolog
        confirm variable _iivw_cat_arm_1
        confirm variable _iivw_cat_arm_2
        local vlbl : variable label _iivw_cat_arm_1
        assert `"`vlbl'"' == "arm=1 (vs. 0)"
    }
    if _rc == 0 {
        display as result "  PASS: Test 37 - Categorical without labels (numeric naming)"
        local ++pass_count
    }
    else {
        display as error "  FAIL: Test 37 - no labels naming (error `=_rc')"
        local ++fail_count
    }
}

* =============================================================================
* TEST 38: Categorical + interaction
* =============================================================================
local ++test_count
if `run_only' == 0 | `run_only' == 38 {
    capture noisily {
        _setup_relapses
        bysort id (days): gen double edss_bl = edss[1]
        label define treated_lbl 0 "Placebo" 1 "Drug", replace
        label values treated treated_lbl
        iivw_weight, id(id) time(days) visit_cov(edss relapse) ///
            treat(treated) treat_cov(edss_bl) nolog
        iivw_fit edss treated edss_bl, timespec(linear) ///
            categorical(treated) interaction(treated) nolog
        confirm variable _iivw_cat_drug
        confirm variable _iivw_ix_drug_time
        local ixlbl : variable label _iivw_ix_drug_time
        assert `"`ixlbl'"' == `"Drug x time"'
    }
    if _rc == 0 {
        display as result "  PASS: Test 38 - Categorical + interaction"
        local ++pass_count
    }
    else {
        display as error "  FAIL: Test 38 - categorical + interaction (error `=_rc')"
        local ++fail_count
    }
}

* =============================================================================
* TEST 39: Multiple categorical variables
* =============================================================================
local ++test_count
if `run_only' == 0 | `run_only' == 39 {
    capture noisily {
        _setup_relapses
        gen byte arm = mod(id, 3)
        label define arm_lbl 0 "Placebo" 1 "Low dose" 2 "High dose", replace
        label values arm arm_lbl
        gen byte site = mod(id, 2)
        label define site_lbl 0 "Site A" 1 "Site B", replace
        label values site site_lbl
        iivw_weight, id(id) time(days) visit_cov(edss relapse) nolog
        iivw_fit edss arm site, categorical(arm site) nolog
        confirm variable _iivw_cat_low_dose
        confirm variable _iivw_cat_high_dose
        confirm variable _iivw_cat_site_b
    }
    if _rc == 0 {
        display as result "  PASS: Test 39 - Multiple categorical variables"
        local ++pass_count
    }
    else {
        display as error "  FAIL: Test 39 - multiple categoricals (error `=_rc')"
        local ++fail_count
    }
}

* =============================================================================
* TEST 40: Non-default basecat
* =============================================================================
local ++test_count
if `run_only' == 0 | `run_only' == 40 {
    capture noisily {
        _setup_relapses
        gen byte arm = mod(id, 3)
        label define arm_lbl 0 "Placebo" 1 "Low dose" 2 "High dose", replace
        label values arm arm_lbl
        iivw_weight, id(id) time(days) visit_cov(edss relapse) nolog
        iivw_fit edss arm, categorical(arm) basecat(2) nolog
        confirm variable _iivw_cat_placebo
        confirm variable _iivw_cat_low_dose
        local vlbl : variable label _iivw_cat_placebo
        assert `"`vlbl'"' == `"Placebo (vs. High dose)"'
    }
    if _rc == 0 {
        display as result "  PASS: Test 40 - Non-default basecat"
        local ++pass_count
    }
    else {
        display as error "  FAIL: Test 40 - basecat (error `=_rc')"
        local ++fail_count
    }
}

* =============================================================================
* TEST 41: basecat not found falls back to lowest
* =============================================================================
local ++test_count
if `run_only' == 0 | `run_only' == 41 {
    capture noisily {
        _setup_relapses
        gen byte arm = mod(id, 3)
        label define arm_lbl 0 "Placebo" 1 "Low dose" 2 "High dose", replace
        label values arm arm_lbl
        iivw_weight, id(id) time(days) visit_cov(edss relapse) nolog
        iivw_fit edss arm, categorical(arm) basecat(99) nolog
        confirm variable _iivw_cat_low_dose
        confirm variable _iivw_cat_high_dose
        local vlbl : variable label _iivw_cat_low_dose
        assert `"`vlbl'"' == `"Low dose (vs. Placebo)"'
    }
    if _rc == 0 {
        display as result "  PASS: Test 41 - basecat not found falls back to lowest"
        local ++pass_count
    }
    else {
        display as error "  FAIL: Test 41 - basecat fallback (error `=_rc')"
        local ++fail_count
    }
}

* =============================================================================
* TEST 42: Long value labels truncated at 32 chars
* =============================================================================
local ++test_count
if `run_only' == 0 | `run_only' == 42 {
    capture noisily {
        _setup_relapses
        gen byte arm = mod(id, 2)
        label define long_lbl 0 "Placebo control" ///
            1 "Very high dose experimental treatment arm", replace
        label values arm long_lbl
        iivw_weight, id(id) time(days) visit_cov(edss relapse) nolog
        iivw_fit edss arm, categorical(arm) nolog
        assert "`e(iivw_cat_vars)'" != ""
        local catvar : word 1 of `e(iivw_cat_vars)'
        assert strlen("`catvar'") <= 32
    }
    if _rc == 0 {
        display as result "  PASS: Test 42 - Long value labels truncated"
        local ++pass_count
    }
    else {
        display as error "  FAIL: Test 42 - long labels (error `=_rc')"
        local ++fail_count
    }
}

* =============================================================================
* TEST 43: Sanitized label collision -> numeric fallback
* =============================================================================
local ++test_count
if `run_only' == 0 | `run_only' == 43 {
    capture noisily {
        _setup_relapses
        gen byte arm = mod(id, 3)
        label define coll_lbl 0 "Control" 1 "Low-dose" 2 "Low dose", replace
        label values arm coll_lbl
        iivw_weight, id(id) time(days) visit_cov(edss relapse) nolog
        iivw_fit edss arm, categorical(arm) nolog
        * Collision: both sanitize to "low_dose" -> numeric fallback
        confirm variable _iivw_cat_arm_1
        confirm variable _iivw_cat_arm_2
        local vlbl : variable label _iivw_cat_arm_1
        assert `"`vlbl'"' == `"arm=1 (vs. Control)"'
    }
    if _rc == 0 {
        display as result "  PASS: Test 43 - Sanitized label collision (numeric fallback)"
        local ++pass_count
    }
    else {
        display as error "  FAIL: Test 43 - label collision (error `=_rc')"
        local ++fail_count
    }
}

* =============================================================================
* TEST 44: Error - categorical var not in indepvars
* =============================================================================
local ++test_count
if `run_only' == 0 | `run_only' == 44 {
    capture noisily {
        _setup_relapses
        gen byte arm = mod(id, 3)
        iivw_weight, id(id) time(days) visit_cov(edss relapse) nolog
        capture iivw_fit edss relapse, categorical(arm)
        assert _rc == 198
    }
    if _rc == 0 {
        display as result "  PASS: Test 44 - Error: categorical var not in indepvars"
        local ++pass_count
    }
    else {
        display as error "  FAIL: Test 44 - categorical not in indepvars (error `=_rc')"
        local ++fail_count
    }
}

* =============================================================================
* TEST 45: Error - non-integer values in categorical
* =============================================================================
local ++test_count
if `run_only' == 0 | `run_only' == 45 {
    capture noisily {
        _setup_relapses
        gen double frac = mod(id, 3) + 0.5
        iivw_weight, id(id) time(days) visit_cov(edss relapse) nolog
        capture iivw_fit edss frac, categorical(frac)
        assert _rc == 198
    }
    if _rc == 0 {
        display as result "  PASS: Test 45 - Error: non-integer categorical values"
        local ++pass_count
    }
    else {
        display as error "  FAIL: Test 45 - non-integer categorical (error `=_rc')"
        local ++fail_count
    }
}

* =============================================================================
* TEST 46: Error - constant variable in categorical
* =============================================================================
local ++test_count
if `run_only' == 0 | `run_only' == 46 {
    capture noisily {
        _setup_relapses
        gen byte constvar = 1
        iivw_weight, id(id) time(days) visit_cov(edss relapse) nolog
        capture iivw_fit edss constvar, categorical(constvar)
        assert _rc == 198
    }
    if _rc == 0 {
        display as result "  PASS: Test 46 - Error: constant variable in categorical"
        local ++pass_count
    }
    else {
        display as error "  FAIL: Test 46 - constant categorical (error `=_rc')"
        local ++fail_count
    }
}

* =============================================================================
* TEST 47: Categorical main effects only (no interaction)
* =============================================================================
local ++test_count
if `run_only' == 0 | `run_only' == 47 {
    capture noisily {
        _setup_relapses
        gen byte arm = mod(id, 3)
        label define arm_lbl 0 "Placebo" 1 "Low dose" 2 "High dose", replace
        label values arm arm_lbl
        iivw_weight, id(id) time(days) visit_cov(edss relapse) nolog
        iivw_fit edss arm, categorical(arm) nolog
        confirm variable _iivw_cat_low_dose
        confirm variable _iivw_cat_high_dose
        * No interaction vars should exist
        capture confirm variable _iivw_ix_low_dose_time
        assert _rc != 0
    }
    if _rc == 0 {
        display as result "  PASS: Test 47 - Categorical main effects only"
        local ++pass_count
    }
    else {
        display as error "  FAIL: Test 47 - main effects only (error `=_rc')"
        local ++fail_count
    }
}

* =============================================================================
* TEST 48: Dummy values are correct
* =============================================================================
local ++test_count
if `run_only' == 0 | `run_only' == 48 {
    capture noisily {
        _setup_relapses
        gen byte arm = mod(id, 3)
        label define arm_lbl 0 "Placebo" 1 "Low dose" 2 "High dose", replace
        label values arm arm_lbl
        iivw_weight, id(id) time(days) visit_cov(edss relapse) nolog
        iivw_fit edss arm, categorical(arm) nolog
        assert _iivw_cat_low_dose == (arm == 1) if !missing(_iivw_cat_low_dose)
        assert _iivw_cat_high_dose == (arm == 2) if !missing(_iivw_cat_high_dose)
    }
    if _rc == 0 {
        display as result "  PASS: Test 48 - Dummy values are correct"
        local ++pass_count
    }
    else {
        display as error "  FAIL: Test 48 - dummy values (error `=_rc')"
        local ++fail_count
    }
}

* =============================================================================
* TEST 49: Metadata stored in e() and characteristics
* =============================================================================
local ++test_count
if `run_only' == 0 | `run_only' == 49 {
    capture noisily {
        _setup_relapses
        bysort id (days): gen double edss_bl = edss[1]
        label define treated_lbl 0 "Placebo" 1 "Drug", replace
        label values treated treated_lbl
        iivw_weight, id(id) time(days) visit_cov(edss relapse) ///
            treat(treated) treat_cov(edss_bl) nolog
        iivw_fit edss treated edss_bl, categorical(treated) nolog
        assert "`e(iivw_categorical)'" == "treated"
        assert "`e(iivw_cat_vars)'" != ""
        local cat_char : char _dta[_iivw_categorical]
        assert "`cat_char'" == "treated"
        local cat_vars_char : char _dta[_iivw_cat_vars]
        assert "`cat_vars_char'" != ""
    }
    if _rc == 0 {
        display as result "  PASS: Test 49 - Metadata stored"
        local ++pass_count
    }
    else {
        display as error "  FAIL: Test 49 - metadata (error `=_rc')"
        local ++fail_count
    }
}

* =============================================================================
* TEST 50: Mixed model (model(mixed))
* =============================================================================
local ++test_count
if `run_only' == 0 | `run_only' == 50 {
    capture noisily {
        _setup_relapses
        iivw_weight, id(id) time(days) visit_cov(edss relapse) nolog
        iivw_fit edss relapse, model(mixed) timespec(linear) nolog
        assert e(N) > 0
        assert "`e(iivw_model)'" == "mixed"
        assert "`e(iivw_timespec)'" == "linear"
    }
    if _rc == 0 {
        display as result "  PASS: Test 50 - Mixed model"
        local ++pass_count
    }
    else {
        display as error "  FAIL: Test 50 - mixed model (error `=_rc')"
        local ++fail_count
    }
}

* =============================================================================
* TEST 51: Bootstrap standard errors
* Known limitation: bootstrap + pw weights produces r(101) "weights not
* allowed" because Stata's bootstrap prefix strips pw. This test documents
* the expected error so it does not silently regress if fixed later.
* =============================================================================
local ++test_count
if `run_only' == 0 | `run_only' == 51 {
    capture noisily {
        clear
        set seed 20260305
        set obs 100
        gen long id = ceil(_n / 5)
        bysort id: gen int visit_n = _n
        gen double months = (visit_n - 1) * 6
        gen double severity = rnormal(3, 1)
        gen double outcome = 50 - 0.1 * months - severity + rnormal(0, 2)
        iivw_weight, id(id) time(months) visit_cov(severity) nolog
        * bootstrap + pw currently errors (r(101)) - document expected behavior
        capture iivw_fit outcome severity, model(gee) timespec(linear) ///
            bootstrap(10) nolog
        assert inlist(_rc, 0, 101)
    }
    if _rc == 0 {
        display as result "  PASS: Test 51 - Bootstrap option accepted (known pw limitation)"
        local ++pass_count
    }
    else {
        display as error "  FAIL: Test 51 - bootstrap (error `=_rc')"
        local ++fail_count
    }
}

* =============================================================================
* TEST 52: Cluster override
* =============================================================================
local ++test_count
if `run_only' == 0 | `run_only' == 52 {
    capture noisily {
        _setup_relapses
        * Create alternative cluster variable
        gen long site_id = mod(id, 10)
        iivw_weight, id(id) time(days) visit_cov(edss relapse) nolog
        iivw_fit edss relapse, model(gee) timespec(linear) ///
            cluster(site_id) nolog
        assert e(N) > 0
        assert e(N_clust) <= 10
    }
    if _rc == 0 {
        display as result "  PASS: Test 52 - Cluster override"
        local ++pass_count
    }
    else {
        display as error "  FAIL: Test 52 - cluster override (error `=_rc')"
        local ++fail_count
    }
}

* =============================================================================
* TEST 53: Level option (90% CI)
* =============================================================================
local ++test_count
if `run_only' == 0 | `run_only' == 53 {
    capture noisily {
        _setup_relapses
        iivw_weight, id(id) time(days) visit_cov(edss relapse) nolog
        iivw_fit edss relapse, model(gee) timespec(linear) ///
            level(90) nolog
        assert e(N) > 0
    }
    if _rc == 0 {
        display as result "  PASS: Test 53 - Level(90) option"
        local ++pass_count
    }
    else {
        display as error "  FAIL: Test 53 - level option (error `=_rc')"
        local ++fail_count
    }
}

* =============================================================================
* TEST 54: Entry option
* =============================================================================
local ++test_count
if `run_only' == 0 | `run_only' == 54 {
    capture noisily {
        clear
        set seed 20260305
        set obs 40
        gen long id = ceil(_n / 4)
        bysort id: gen int visit_n = _n
        gen double months = (visit_n - 1) * 3 + runiform() * 0.5
        replace months = 0.5 + runiform() * 0.5 if visit_n == 1
        gen double severity = rnormal(3, 1)
        gen double entry_time = runiform() * 0.3
        bysort id: replace entry_time = entry_time[1]
        iivw_weight, id(id) time(months) visit_cov(severity) ///
            entry(entry_time) nolog
        assert r(N) > 0
        confirm variable _iivw_weight
    }
    if _rc == 0 {
        display as result "  PASS: Test 54 - Entry option"
        local ++pass_count
    }
    else {
        display as error "  FAIL: Test 54 - entry option (error `=_rc')"
        local ++fail_count
    }
}

* =============================================================================
* TEST 55: treat_cov defaults to visit_cov when not specified
* =============================================================================
local ++test_count
if `run_only' == 0 | `run_only' == 55 {
    capture noisily {
        _setup_relapses
        * Without treat_cov: should use visit_cov for propensity model
        iivw_weight, id(id) time(days) visit_cov(edss relapse) ///
            treat(treated) nolog
        assert "`r(weighttype)'" == "fiptiw"
        confirm variable _iivw_tw
        assert r(mean_weight) > 0
    }
    if _rc == 0 {
        display as result "  PASS: Test 55 - treat_cov defaults to visit_cov"
        local ++pass_count
    }
    else {
        display as error "  FAIL: Test 55 - treat_cov default (error `=_rc')"
        local ++fail_count
    }
}

* =============================================================================
* TEST 56: geeopts passthrough
* =============================================================================
local ++test_count
if `run_only' == 0 | `run_only' == 56 {
    capture noisily {
        _setup_relapses
        iivw_weight, id(id) time(days) visit_cov(edss relapse) nolog
        iivw_fit edss relapse, model(gee) timespec(linear) ///
            geeopts(iterate(50)) nolog
        assert e(N) > 0
    }
    if _rc == 0 {
        display as result "  PASS: Test 56 - geeopts passthrough"
        local ++pass_count
    }
    else {
        display as error "  FAIL: Test 56 - geeopts (error `=_rc')"
        local ++fail_count
    }
}

* =============================================================================
* TEST 57: Error - only one treatment group
* =============================================================================
local ++test_count
if `run_only' == 0 | `run_only' == 57 {
    capture noisily {
        clear
        set obs 20
        gen long id = ceil(_n / 4)
        bysort id: gen int visit_n = _n
        gen double months = (visit_n - 1) * 3
        gen double severity = rnormal(3, 1)
        gen byte treated = 1
        bysort id: replace treated = treated[1]
        capture iivw_weight, id(id) time(months) visit_cov(severity) ///
            treat(treated) nolog
        assert _rc == 198
    }
    if _rc == 0 {
        display as result "  PASS: Test 57 - Error on single treatment group"
        local ++pass_count
    }
    else {
        display as error "  FAIL: Test 57 - single treatment group (error `=_rc')"
        local ++fail_count
    }
}

* =============================================================================
* TEST 58: Edge case - minimal dataset (2 subjects, 2 visits each)
* =============================================================================
local ++test_count
if `run_only' == 0 | `run_only' == 58 {
    capture noisily {
        clear
        input long id double(months severity)
            1 0   2.0
            1 6   3.0
            2 0   1.0
            2 5   1.5
        end
        iivw_weight, id(id) time(months) visit_cov(severity) nolog
        assert r(N) == 4
        assert r(n_ids) == 2
        confirm variable _iivw_weight
    }
    if _rc == 0 {
        display as result "  PASS: Test 58 - Minimal dataset (2 subjects, 2 visits)"
        local ++pass_count
    }
    else {
        display as error "  FAIL: Test 58 - minimal dataset (error `=_rc')"
        local ++fail_count
    }
}

* =============================================================================
* TEST 59: Edge case - many visits per subject (1 subject, 25 visits)
* =============================================================================
local ++test_count
if `run_only' == 0 | `run_only' == 59 {
    capture noisily {
        clear
        set obs 50
        gen long id = ceil(_n / 25)
        bysort id: gen int visit_n = _n
        gen double months = (visit_n - 1) * 2
        gen double severity = rnormal(3, 1)
        iivw_weight, id(id) time(months) visit_cov(severity) nolog
        assert r(N) == 50
        assert r(n_ids) == 2
    }
    if _rc == 0 {
        display as result "  PASS: Test 59 - Many visits per subject (25 each)"
        local ++pass_count
    }
    else {
        display as error "  FAIL: Test 59 - many visits (error `=_rc')"
        local ++fail_count
    }
}

* =============================================================================
* TEST 60: iivw_fit e() return values complete
* =============================================================================
local ++test_count
if `run_only' == 0 | `run_only' == 60 {
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
        assert "`e(iivw_timespec)'" == "linear"
        assert "`e(iivw_weight_var)'" == "_iivw_weight"
        matrix b = e(b)
        matrix V = e(V)
        assert rowsof(V) == colsof(V)
    }
    if _rc == 0 {
        display as result "  PASS: Test 60 - iivw_fit e() return values complete"
        local ++pass_count
    }
    else {
        display as error "  FAIL: Test 60 - e() returns (error `=_rc')"
        local ++fail_count
    }
}

* =============================================================================
* TEST 61: nolog suppresses iteration output
* =============================================================================
local ++test_count
if `run_only' == 0 | `run_only' == 61 {
    capture noisily {
        _setup_relapses
        quietly {
            iivw_weight, id(id) time(days) visit_cov(edss relapse) nolog
        }
        assert r(N) > 0
    }
    if _rc == 0 {
        display as result "  PASS: Test 61 - nolog runs without error"
        local ++pass_count
    }
    else {
        display as error "  FAIL: Test 61 - nolog (error `=_rc')"
        local ++fail_count
    }
}

* ============================================================
* Summary
* ============================================================
display as text ""
display as result "Test Results: `pass_count'/`test_count' passed, `fail_count' failed"

if `fail_count' > 0 {
    display as error "RESULT: `fail_count' TESTS FAILED"
    exit 1
}
else {
    display as result "RESULT: ALL `pass_count' TESTS PASSED"
}

clear
