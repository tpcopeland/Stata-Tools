clear all
set more off
version 16.0
set varabbrev off

* test_iivw.do - Functional tests for iivw package
* Tests: 122 (basic functionality, options, error handling, return values,
*        edge cases, data preservation, expanded coverage,
*        regtab integration + console summary + install/settings)
*
* Usage:
*   do iivw/qa/test_iivw.do          Run all tests
*   do iivw/qa/test_iivw.do 5        Run only test 5

args run_only
if "`run_only'" == "" local run_only = 0

* ============================================================
* Setup
* ============================================================


* === Bootstrap ===
local qa_dir  "`c(pwd)'"
local pkg_dir "`qa_dir'/.."
local repo_dir "`qa_dir'/../.."

* Expose repo root to programs defined below (locals are not visible in programs)
global IIVW_QA_REPO_DIR "`repo_dir'"

capture ado uninstall iivw
quietly net install iivw, from("`pkg_dir'") replace

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
    * Resolve repo root from global (set in the caller's bootstrap)
    local rd "$IIVW_QA_REPO_DIR"
    use "`rd'/_data/relapses.dta", clear
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
        assert r(n_commands) == 5
        assert "`r(version)'" == "1.5.1"
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
* Bootstrap calls _iivw_bs_estimate wrapper which applies pw internally,
* avoiding Stata's bootstrap prefix stripping pweights.
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
        iivw_fit outcome severity, model(gee) timespec(linear) ///
            bootstrap(10) nolog
        assert e(N_reps) == 10
        assert "`e(vce)'" == "bootstrap"
    }
    if _rc == 0 {
        display as result "  PASS: Test 51 - Bootstrap with pweights via wrapper"
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
* TEST 55: Error - FIPTIW requires explicit treat_cov()
* =============================================================================
local ++test_count
if `run_only' == 0 | `run_only' == 55 {
    capture noisily {
        _setup_relapses
        capture iivw_weight, id(id) time(days) visit_cov(edss relapse) ///
            treat(treated) nolog
        assert _rc == 198
    }
    if _rc == 0 {
        display as result "  PASS: Test 55 - Error: FIPTIW requires treat_cov()"
        local ++pass_count
    }
    else {
        display as error "  FAIL: Test 55 - FIPTIW treat_cov requirement (error `=_rc')"
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

* =============================================================================
* TEST 62: Bootstrap with mixed model
* =============================================================================
local ++test_count
if `run_only' == 0 | `run_only' == 62 {
    capture noisily {
        clear
        set seed 20260312
        set obs 200
        gen long id = ceil(_n / 5)
        bysort id: gen int visit_n = _n
        gen double months = (visit_n - 1) * 6
        gen double severity = rnormal(3, 1)
        gen double outcome = 50 - 0.1 * months - severity + rnormal(0, 2)
        iivw_weight, id(id) time(months) visit_cov(severity) nolog
        iivw_fit outcome severity, model(mixed) timespec(linear) ///
            bootstrap(10) nolog
        assert e(N_reps) == 10
        assert "`e(vce)'" == "bootstrap"
    }
    if _rc == 0 {
        display as result "  PASS: Test 62 - Bootstrap with mixed model"
        local ++pass_count
    }
    else {
        display as error "  FAIL: Test 62 - bootstrap mixed (error `=_rc')"
        local ++fail_count
    }
}

* =============================================================================
* TEST 63: Bootstrap with quadratic timespec
* =============================================================================
local ++test_count
if `run_only' == 0 | `run_only' == 63 {
    capture noisily {
        clear
        set seed 20260312
        set obs 100
        gen long id = ceil(_n / 5)
        bysort id: gen int visit_n = _n
        gen double months = (visit_n - 1) * 6
        gen double severity = rnormal(3, 1)
        gen double outcome = 50 - 0.1 * months - severity + rnormal(0, 2)
        iivw_weight, id(id) time(months) visit_cov(severity) nolog
        iivw_fit outcome severity, model(gee) timespec(quadratic) ///
            bootstrap(10) nolog
        assert e(N_reps) == 10
        assert "`e(vce)'" == "bootstrap"
    }
    if _rc == 0 {
        display as result "  PASS: Test 63 - Bootstrap with quadratic timespec"
        local ++pass_count
    }
    else {
        display as error "  FAIL: Test 63 - bootstrap quadratic (error `=_rc')"
        local ++fail_count
    }
}

* =============================================================================
* TEST 64: Bootstrap with categorical variables
* =============================================================================
local ++test_count
if `run_only' == 0 | `run_only' == 64 {
    capture noisily {
        clear
        set seed 20260312
        set obs 150
        gen long id = ceil(_n / 5)
        bysort id: gen int visit_n = _n
        gen double months = (visit_n - 1) * 6
        gen double severity = rnormal(3, 1)
        gen int group = mod(id, 3)
        gen double outcome = 50 - 0.1 * months - severity + group + rnormal(0, 2)
        iivw_weight, id(id) time(months) visit_cov(severity) nolog
        iivw_fit outcome severity group, model(gee) timespec(linear) ///
            categorical(group) bootstrap(10) nolog
        assert e(N_reps) == 10
        assert "`e(vce)'" == "bootstrap"
    }
    if _rc == 0 {
        display as result "  PASS: Test 64 - Bootstrap with categorical"
        local ++pass_count
    }
    else {
        display as error "  FAIL: Test 64 - bootstrap categorical (error `=_rc')"
        local ++fail_count
    }
}

* =============================================================================
* TEST 65: Bootstrap with interaction
* =============================================================================
local ++test_count
if `run_only' == 0 | `run_only' == 65 {
    capture noisily {
        clear
        set seed 20260312
        set obs 100
        gen long id = ceil(_n / 5)
        bysort id: gen int visit_n = _n
        gen double months = (visit_n - 1) * 6
        gen double severity = rnormal(3, 1)
        gen double outcome = 50 - 0.1 * months - severity + rnormal(0, 2)
        iivw_weight, id(id) time(months) visit_cov(severity) nolog
        iivw_fit outcome severity, model(gee) timespec(linear) ///
            interaction(severity) bootstrap(10) nolog
        assert e(N_reps) == 10
        assert "`e(vce)'" == "bootstrap"
    }
    if _rc == 0 {
        display as result "  PASS: Test 65 - Bootstrap with interaction"
        local ++pass_count
    }
    else {
        display as error "  FAIL: Test 65 - bootstrap interaction (error `=_rc')"
        local ++fail_count
    }
}

* =============================================================================
* TEST 66: Bootstrap with geeopts passthrough
* =============================================================================
local ++test_count
if `run_only' == 0 | `run_only' == 66 {
    capture noisily {
        clear
        set seed 20260312
        set obs 100
        gen long id = ceil(_n / 5)
        bysort id: gen int visit_n = _n
        gen double months = (visit_n - 1) * 6
        gen double severity = rnormal(3, 1)
        gen double outcome = 50 - 0.1 * months - severity + rnormal(0, 2)
        iivw_weight, id(id) time(months) visit_cov(severity) nolog
        iivw_fit outcome severity, model(gee) timespec(linear) ///
            geeopts(iterate(50)) bootstrap(10) nolog
        assert e(N_reps) == 10
        assert "`e(vce)'" == "bootstrap"
    }
    if _rc == 0 {
        display as result "  PASS: Test 66 - Bootstrap with geeopts passthrough"
        local ++pass_count
    }
    else {
        display as error "  FAIL: Test 66 - bootstrap geeopts (error `=_rc')"
        local ++fail_count
    }
}

* =============================================================================
* TEST 67: Bootstrap with multiple covariates
* =============================================================================
local ++test_count
if `run_only' == 0 | `run_only' == 67 {
    capture noisily {
        clear
        set seed 20260312
        set obs 100
        gen long id = ceil(_n / 5)
        bysort id: gen int visit_n = _n
        gen double months = (visit_n - 1) * 6
        gen double severity = rnormal(3, 1)
        gen double age = 40 + rnormal(0, 10)
        gen byte female = runiform() > 0.5
        gen double outcome = 50 - 0.1 * months - severity + ///
            0.2 * age + female + rnormal(0, 2)
        iivw_weight, id(id) time(months) visit_cov(severity) nolog
        iivw_fit outcome severity age female, model(gee) ///
            timespec(linear) bootstrap(10) nolog
        assert e(N_reps) == 10
        assert "`e(vce)'" == "bootstrap"
    }
    if _rc == 0 {
        display as result "  PASS: Test 67 - Bootstrap with multiple covariates"
        local ++pass_count
    }
    else {
        display as error "  FAIL: Test 67 - bootstrap multi-covar (error `=_rc')"
        local ++fail_count
    }
}

* =============================================================================
* v1.2.2 TESTS: Bugs found during review and deliberation
* =============================================================================

* TEST 68: r(median_weight) stored result
if `run_only' == 0 | `run_only' == 68 {
local ++test_count
capture noisily {
    _setup_relapses
    iivw_weight, id(id) time(days) visit_cov(edss relapse) nolog
    assert r(median_weight) < .
    assert r(median_weight) > 0
    * Median should be between min and max
    assert r(median_weight) >= r(min_weight)
    assert r(median_weight) <= r(max_weight)
}
if _rc == 0 {
    display as result "  PASS: Test 68 - r(median_weight) stored result"
    local ++pass_count
}
else {
    display as error "  FAIL: Test 68 - r(median_weight) (error `=_rc')"
    local ++fail_count
}
}

* TEST 69: e(iivw_cluster) stored result
if `run_only' == 0 | `run_only' == 69 {
local ++test_count
capture noisily {
    _setup_relapses
    iivw_weight, id(id) time(days) visit_cov(edss relapse) nolog
    iivw_fit edss treated, model(gee) timespec(linear) nolog
    assert "`e(iivw_cluster)'" == "id"
}
if _rc == 0 {
    display as result "  PASS: Test 69 - e(iivw_cluster) stored result"
    local ++pass_count
}
else {
    display as error "  FAIL: Test 69 - e(iivw_cluster) (error `=_rc')"
    local ++fail_count
}
}

* TEST 70: e(iivw_cluster) with custom cluster variable
if `run_only' == 0 | `run_only' == 70 {
local ++test_count
capture noisily {
    _setup_relapses
    iivw_weight, id(id) time(days) visit_cov(edss relapse) nolog
    gen long site = mod(id, 5)
    iivw_fit edss treated, model(gee) timespec(linear) ///
        cluster(site) nolog
    assert "`e(iivw_cluster)'" == "site"
}
if _rc == 0 {
    display as result "  PASS: Test 70 - e(iivw_cluster) custom cluster"
    local ++pass_count
}
else {
    display as error "  FAIL: Test 70 - e(iivw_cluster) custom (error `=_rc')"
    local ++fail_count
}
}

* TEST 71: Convergence check after glm (non-convergence hard to trigger,
*          but we verify the check exists by confirming success path works)
if `run_only' == 0 | `run_only' == 71 {
local ++test_count
capture noisily {
    _setup_relapses
    iivw_weight, id(id) time(days) visit_cov(edss relapse) nolog
    iivw_fit edss treated, model(gee) timespec(linear) nolog
    * Verify model converged (e(converged) should be 1)
    assert e(converged) == 1
}
if _rc == 0 {
    display as result "  PASS: Test 71 - GEE convergence check accessible"
    local ++pass_count
}
else {
    display as error "  FAIL: Test 71 - convergence check (error `=_rc')"
    local ++fail_count
}
}

* TEST 72: Natural spline duplicate knot guard exists
* (Tests the code path — knot sequence validation at iivw_fit.ado L276-288)
if `run_only' == 0 | `run_only' == 72 {
local ++test_count
capture noisily {
    _setup_relapses
    iivw_weight, id(id) time(days) visit_cov(edss relapse) nolog
    * Normal data with sufficient variation should NOT trigger the guard
    iivw_fit edss treated, model(gee) timespec(ns(3)) nolog replace
    assert e(N) > 0
    * Verify the knot validation code exists by confirming ns() works
    * The tied-knot guard fires when _pctile returns duplicate values,
    * which requires extremely concentrated time distributions.
}
if _rc == 0 {
    display as result "  PASS: Test 72 - ns(3) works with well-spread data"
    local ++pass_count
}
else {
    display as error "  FAIL: Test 72 - ns(3) basic (error `=_rc')"
    local ++fail_count
}
}

* TEST 73: Partial missing treatment within subject is rejected
if `run_only' == 0 | `run_only' == 73 {
local ++test_count
capture noisily {
    clear
    set seed 20260320
    set obs 100
    gen long id = ceil(_n / 5)
    bysort id: gen int visit = _n
    gen double months = (visit - 1) * 6
    gen double sev = rnormal(3, 1)
    gen byte treated = (id <= 10)
    * Make visit 3 of subject 5 have missing treatment (partial missing)
    replace treated = . if id == 5 & visit == 3
    capture iivw_weight, id(id) time(months) visit_cov(sev) ///
        treat(treated) treat_cov(sev) nolog
    * Should reject partial missing with rc 198
    assert _rc == 198
}
if _rc == 0 {
    display as result "  PASS: Test 73 - Partial missing treatment rejected"
    local ++pass_count
}
else {
    display as error "  FAIL: Test 73 - partial missing treat (error `=_rc')"
    local ++fail_count
}
}

* TEST 74: Error - wtype(iptw) requires explicit treat_cov()
if `run_only' == 0 | `run_only' == 74 {
local ++test_count
capture noisily {
    _setup_relapses
    capture iivw_weight, id(id) time(days) visit_cov(edss relapse) ///
        treat(treated) wtype(iptw) nolog
    assert _rc == 198
}
if _rc == 0 {
    display as result "  PASS: Test 74 - Error: wtype(iptw) requires treat_cov()"
    local ++pass_count
}
else {
    display as error "  FAIL: Test 74 - iptw treat_cov requirement (error `=_rc')"
    local ++fail_count
}
}

* TEST 75: markout handles missing cluster variable
if `run_only' == 0 | `run_only' == 75 {
local ++test_count
capture noisily {
    _setup_relapses
    iivw_weight, id(id) time(days) visit_cov(edss relapse) nolog
    gen long site = mod(id, 5)
    * Set half the site values to missing
    replace site = . if mod(id, 2) == 0
    quietly count if !missing(site)
    local N_nonmiss = r(N)
    iivw_fit edss treated, model(gee) timespec(linear) ///
        cluster(site) nolog replace
    * e(N) should equal the non-missing cluster count
    assert e(N) == `N_nonmiss'
    * Dataset row count unchanged
    assert _N > e(N)
}
if _rc == 0 {
    display as result "  PASS: Test 75 - markout handles missing cluster"
    local ++pass_count
}
else {
    display as error "  FAIL: Test 75 - markout cluster (error `=_rc')"
    local ++fail_count
}
}

* TEST 76: iivw_fit replace option for existing time variables
if `run_only' == 0 | `run_only' == 76 {
local ++test_count
capture noisily {
    _setup_relapses
    iivw_weight, id(id) time(days) visit_cov(edss relapse) nolog
    * First fit creates _iivw_time_sq
    iivw_fit edss treated, model(gee) timespec(quadratic) nolog replace
    assert e(N) > 0
    * Second fit with replace should succeed (overwrites _iivw_time_sq)
    iivw_fit edss treated, model(gee) timespec(quadratic) nolog replace
    assert e(N) > 0
}
if _rc == 0 {
    display as result "  PASS: Test 76 - iivw_fit replace option"
    local ++pass_count
}
else {
    display as error "  FAIL: Test 76 - replace option (error `=_rc')"
    local ++fail_count
}
}

* TEST 77: iivw_fit without replace errors on existing vars
if `run_only' == 0 | `run_only' == 77 {
local ++test_count
capture noisily {
    _setup_relapses
    iivw_weight, id(id) time(days) visit_cov(edss relapse) nolog
    * First fit creates _iivw_time_sq
    iivw_fit edss treated, model(gee) timespec(quadratic) nolog replace
    * Second fit WITHOUT replace should error
    capture iivw_fit edss treated, model(gee) timespec(quadratic) nolog
    assert _rc == 110
}
if _rc == 0 {
    display as result "  PASS: Test 77 - iivw_fit errors without replace"
    local ++pass_count
}
else {
    display as error "  FAIL: Test 77 - no replace error (error `=_rc')"
    local ++fail_count
}
}

* =============================================================================
* v1.2.4 TESTS: Expanded coverage — error paths, options, edge cases
* =============================================================================

* TEST 78: Error - invalid wtype value
if `run_only' == 0 | `run_only' == 78 {
local ++test_count
capture noisily {
    _setup_relapses
    capture iivw_weight, id(id) time(days) visit_cov(edss) wtype(badval) nolog
    assert _rc == 198
}
if _rc == 0 {
    display as result "  PASS: Test 78 - Error on invalid wtype value"
    local ++pass_count
}
else {
    display as error "  FAIL: Test 78 - invalid wtype (error `=_rc')"
    local ++fail_count
}
}

* TEST 79: Error - wtype(iptw) without treat()
if `run_only' == 0 | `run_only' == 79 {
local ++test_count
capture noisily {
    _setup_relapses
    capture iivw_weight, id(id) time(days) visit_cov(edss) wtype(iptw) nolog
    assert _rc == 198
}
if _rc == 0 {
    display as result "  PASS: Test 79 - Error: wtype(iptw) without treat()"
    local ++pass_count
}
else {
    display as error "  FAIL: Test 79 - iptw no treat (error `=_rc')"
    local ++fail_count
}
}

* TEST 80: Error - wtype(iivw) explicit without visit_cov()
if `run_only' == 0 | `run_only' == 80 {
local ++test_count
capture noisily {
    _setup_relapses
    capture iivw_weight, id(id) time(days) wtype(iivw) nolog
    assert _rc == 198
}
if _rc == 0 {
    display as result "  PASS: Test 80 - Error: wtype(iivw) without visit_cov()"
    local ++pass_count
}
else {
    display as error "  FAIL: Test 80 - iivw no visit_cov (error `=_rc')"
    local ++fail_count
}
}

* TEST 81: Error - invalid model type in iivw_fit
if `run_only' == 0 | `run_only' == 81 {
local ++test_count
capture noisily {
    _setup_relapses
    iivw_weight, id(id) time(days) visit_cov(edss relapse) nolog
    capture iivw_fit edss relapse, model(badval) nolog
    assert _rc == 198
}
if _rc == 0 {
    display as result "  PASS: Test 81 - Error on invalid model type"
    local ++pass_count
}
else {
    display as error "  FAIL: Test 81 - invalid model (error `=_rc')"
    local ++fail_count
}
}

* TEST 82: Error - invalid timespec in iivw_fit
if `run_only' == 0 | `run_only' == 82 {
local ++test_count
capture noisily {
    _setup_relapses
    iivw_weight, id(id) time(days) visit_cov(edss relapse) nolog
    capture iivw_fit edss relapse, timespec(badval) nolog
    assert _rc == 198
}
if _rc == 0 {
    display as result "  PASS: Test 82 - Error on invalid timespec"
    local ++pass_count
}
else {
    display as error "  FAIL: Test 82 - invalid timespec (error `=_rc')"
    local ++fail_count
}
}

* TEST 83: Error - basecat() without categorical()
if `run_only' == 0 | `run_only' == 83 {
local ++test_count
capture noisily {
    _setup_relapses
    iivw_weight, id(id) time(days) visit_cov(edss relapse) nolog
    capture iivw_fit edss relapse, basecat(1) nolog
    assert _rc == 198
}
if _rc == 0 {
    display as result "  PASS: Test 83 - Error: basecat() without categorical()"
    local ++pass_count
}
else {
    display as error "  FAIL: Test 83 - basecat no categorical (error `=_rc')"
    local ++fail_count
}
}

* TEST 84: Error - basecat non-integer
if `run_only' == 0 | `run_only' == 84 {
local ++test_count
capture noisily {
    _setup_relapses
    gen byte arm = mod(id, 3)
    iivw_weight, id(id) time(days) visit_cov(edss relapse) nolog
    capture iivw_fit edss arm, categorical(arm) basecat(1.5) nolog
    assert _rc == 198
}
if _rc == 0 {
    display as result "  PASS: Test 84 - Error: basecat non-integer"
    local ++pass_count
}
else {
    display as error "  FAIL: Test 84 - basecat non-integer (error `=_rc')"
    local ++fail_count
}
}

* TEST 85: Error - iivw_fit if/in filtering to 0 observations
if `run_only' == 0 | `run_only' == 85 {
local ++test_count
capture noisily {
    _setup_relapses
    iivw_weight, id(id) time(days) visit_cov(edss relapse) nolog
    capture iivw_fit edss relapse if edss > 999, model(gee) nolog
    assert _rc == 2000
}
if _rc == 0 {
    display as result "  PASS: Test 85 - Error: if filtering to 0 obs"
    local ++pass_count
}
else {
    display as error "  FAIL: Test 85 - zero obs if (error `=_rc')"
    local ++fail_count
}
}

* TEST 86: Error - truncate out of range
if `run_only' == 0 | `run_only' == 86 {
local ++test_count
capture noisily {
    _setup_relapses
    capture iivw_weight, id(id) time(days) visit_cov(edss) truncate(-1 101) nolog
    assert _rc == 198
}
if _rc == 0 {
    display as result "  PASS: Test 86 - Error: truncate out of range"
    local ++pass_count
}
else {
    display as error "  FAIL: Test 86 - truncate range (error `=_rc')"
    local ++fail_count
}
}

* TEST 87: iivw_fit cubic timespec creates all 3 time vars
if `run_only' == 0 | `run_only' == 87 {
local ++test_count
capture noisily {
    _setup_relapses
    iivw_weight, id(id) time(days) visit_cov(edss relapse) nolog
    iivw_fit edss relapse, model(gee) timespec(cubic) nolog
    assert "`e(iivw_timespec)'" == "cubic"
    confirm variable _iivw_time_sq
    confirm variable _iivw_time_cu
    * Verify cubic values are correct
    assert abs(_iivw_time_cu - days^3) < 1e-2
}
if _rc == 0 {
    display as result "  PASS: Test 87 - Cubic timespec creates all 3 vars"
    local ++pass_count
}
else {
    display as error "  FAIL: Test 87 - cubic timespec (error `=_rc')"
    local ++fail_count
}
}

* TEST 88: iivw_fit with ns(2) works
if `run_only' == 0 | `run_only' == 88 {
local ++test_count
capture noisily {
    _setup_relapses
    iivw_weight, id(id) time(days) visit_cov(edss relapse) nolog
    iivw_fit edss relapse, model(gee) timespec(ns(2)) nolog
    assert "`e(iivw_timespec)'" == "ns(2)"
    confirm variable _iivw_tns1
    confirm variable _iivw_tns2
    assert e(N) > 0
}
if _rc == 0 {
    display as result "  PASS: Test 88 - ns(2) timespec works"
    local ++pass_count
}
else {
    display as error "  FAIL: Test 88 - ns(2) (error `=_rc')"
    local ++fail_count
}
}

* TEST 89: iivw_fit with ns(4) works
if `run_only' == 0 | `run_only' == 89 {
local ++test_count
capture noisily {
    _setup_relapses
    iivw_weight, id(id) time(days) visit_cov(edss relapse) nolog
    iivw_fit edss relapse, model(gee) timespec(ns(4)) nolog
    assert "`e(iivw_timespec)'" == "ns(4)"
    confirm variable _iivw_tns1
    confirm variable _iivw_tns4
    assert e(N) > 0
}
if _rc == 0 {
    display as result "  PASS: Test 89 - ns(4) timespec works"
    local ++pass_count
}
else {
    display as error "  FAIL: Test 89 - ns(4) (error `=_rc')"
    local ++fail_count
}
}

* TEST 90: iivw_fit with poisson family for count outcome
if `run_only' == 0 | `run_only' == 90 {
local ++test_count
capture noisily {
    _setup_relapses
    * Create a count outcome
    gen int n_visits = ceil(abs(edss)) + 1
    iivw_weight, id(id) time(days) visit_cov(edss relapse) nolog
    iivw_fit n_visits relapse, family(poisson) link(log) ///
        timespec(linear) nolog
    assert e(N) > 0
    assert "`e(iivw_model)'" == "gee"
}
if _rc == 0 {
    display as result "  PASS: Test 90 - Poisson family for count outcome"
    local ++pass_count
}
else {
    display as error "  FAIL: Test 90 - poisson family (error `=_rc')"
    local ++fail_count
}
}

* TEST 91: iivw_fit with if/in subsets data correctly
if `run_only' == 0 | `run_only' == 91 {
local ++test_count
capture noisily {
    _setup_relapses
    iivw_weight, id(id) time(days) visit_cov(edss relapse) nolog
    local N_full = _N
    iivw_fit edss relapse if edss > 3, model(gee) timespec(linear) nolog
    assert e(N) < `N_full'
    assert e(N) > 0
    * Dataset should be unchanged
    assert _N == `N_full'
}
if _rc == 0 {
    display as result "  PASS: Test 91 - if/in subsets correctly"
    local ++pass_count
}
else {
    display as error "  FAIL: Test 91 - if/in subset (error `=_rc')"
    local ++fail_count
}
}

* TEST 92: Multiple lagvars creates both _lag1 variables
if `run_only' == 0 | `run_only' == 92 {
local ++test_count
capture noisily {
    _setup_relapses
    iivw_weight, id(id) time(days) visit_cov(edss relapse) ///
        lagvars(edss relapse) nolog
    confirm variable edss_lag1
    confirm variable relapse_lag1
    * First obs per subject should be missing for both
    bysort id (days): assert missing(edss_lag1) if _n == 1
    bysort id (days): assert missing(relapse_lag1) if _n == 1
}
if _rc == 0 {
    display as result "  PASS: Test 92 - Multiple lagvars create both _lag1 vars"
    local ++pass_count
}
else {
    display as error "  FAIL: Test 92 - multiple lagvars (error `=_rc')"
    local ++fail_count
}
}

* TEST 93: Sort preservation - data order unchanged after iivw_weight
if `run_only' == 0 | `run_only' == 93 {
local ++test_count
capture noisily {
    _setup_relapses
    * Shuffle data into non-standard order
    gen double _sort_key = runiform()
    sort _sort_key
    gen long _orig_order = _n
    * Save original id/time order for comparison
    tempvar orig_id orig_time
    gen long `orig_id' = id
    gen double `orig_time' = days
    iivw_weight, id(id) time(days) visit_cov(edss relapse) nolog
    * Verify data is back in original shuffled order
    assert id == `orig_id'
    assert days == `orig_time'
    drop _sort_key _orig_order
}
if _rc == 0 {
    display as result "  PASS: Test 93 - Sort preserved after iivw_weight"
    local ++pass_count
}
else {
    display as error "  FAIL: Test 93 - sort preservation (error `=_rc')"
    local ++fail_count
}
}

* TEST 94: Data immutability - original variables unchanged after iivw_weight
if `run_only' == 0 | `run_only' == 94 {
local ++test_count
capture noisily {
    _setup_relapses
    * Snapshot key variables before
    tempvar pre_edss pre_days pre_id
    gen double `pre_edss' = edss
    gen double `pre_days' = days
    gen long `pre_id' = id
    iivw_weight, id(id) time(days) visit_cov(edss relapse) nolog
    * Verify nothing changed
    assert edss == `pre_edss'
    assert days == `pre_days'
    assert id == `pre_id'
}
if _rc == 0 {
    display as result "  PASS: Test 94 - Original variables unchanged"
    local ++pass_count
}
else {
    display as error "  FAIL: Test 94 - data immutability (error `=_rc')"
    local ++fail_count
}
}

* TEST 95: varabbrev restored after successful iivw_weight
if `run_only' == 0 | `run_only' == 95 {
local ++test_count
capture noisily {
    _setup_relapses
    set varabbrev on
    iivw_weight, id(id) time(days) visit_cov(edss relapse) nolog
    assert c(varabbrev) == "on"
    set varabbrev off
    iivw_weight, id(id) time(days) visit_cov(edss) replace nolog
    assert c(varabbrev) == "off"
}
if _rc == 0 {
    display as result "  PASS: Test 95 - varabbrev restored after iivw_weight"
    local ++pass_count
}
else {
    display as error "  FAIL: Test 95 - varabbrev weight (error `=_rc')"
    local ++fail_count
}
}

* TEST 96: varabbrev restored after iivw_weight error
if `run_only' == 0 | `run_only' == 96 {
local ++test_count
capture noisily {
    clear
    set obs 10
    gen long id = _n
    gen double months = _n
    gen double severity = rnormal()
    set varabbrev on
    capture iivw_weight, id(id) time(months) visit_cov(severity) nolog
    * Single visit per subject → error 198
    assert c(varabbrev) == "on"
}
if _rc == 0 {
    display as result "  PASS: Test 96 - varabbrev restored after iivw_weight error"
    local ++pass_count
}
else {
    display as error "  FAIL: Test 96 - varabbrev weight error (error `=_rc')"
    local ++fail_count
}
}

* TEST 97: varabbrev restored after successful iivw_fit
if `run_only' == 0 | `run_only' == 97 {
local ++test_count
capture noisily {
    _setup_relapses
    iivw_weight, id(id) time(days) visit_cov(edss relapse) nolog
    set varabbrev on
    iivw_fit edss relapse, model(gee) timespec(linear) nolog
    assert c(varabbrev) == "on"
}
if _rc == 0 {
    display as result "  PASS: Test 97 - varabbrev restored after iivw_fit"
    local ++pass_count
}
else {
    display as error "  FAIL: Test 97 - varabbrev fit (error `=_rc')"
    local ++fail_count
}
}

* TEST 98: varabbrev restored after iivw_fit error
if `run_only' == 0 | `run_only' == 98 {
local ++test_count
capture noisily {
    sysuse auto, clear
    set varabbrev on
    capture iivw_fit price mpg weight
    * Should error (no iivw_weight run)
    assert c(varabbrev) == "on"
}
if _rc == 0 {
    display as result "  PASS: Test 98 - varabbrev restored after iivw_fit error"
    local ++pass_count
}
else {
    display as error "  FAIL: Test 98 - varabbrev fit error (error `=_rc')"
    local ++fail_count
}
}

* TEST 99: Weight variable labels are correct
if `run_only' == 0 | `run_only' == 99 {
local ++test_count
capture noisily {
    _setup_relapses
    bysort id (days): gen double edss_bl = edss[1]
    iivw_weight, id(id) time(days) visit_cov(edss relapse) ///
        treat(treated) treat_cov(edss_bl) nolog
    local lbl_iw : variable label _iivw_iw
    assert `"`lbl_iw'"' == "Inverse intensity weight"
    local lbl_tw : variable label _iivw_tw
    assert `"`lbl_tw'"' == "Inverse probability of treatment weight"
    local lbl_wt : variable label _iivw_weight
    assert `"`lbl_wt'"' == "FIPTIW weight (IIW x IPTW)"
}
if _rc == 0 {
    display as result "  PASS: Test 99 - Weight variable labels correct"
    local ++pass_count
}
else {
    display as error "  FAIL: Test 99 - weight labels (error `=_rc')"
    local ++fail_count
}
}

* TEST 100: IIW weight label (non-FIPTIW)
if `run_only' == 0 | `run_only' == 100 {
local ++test_count
capture noisily {
    _setup_relapses
    iivw_weight, id(id) time(days) visit_cov(edss relapse) nolog
    local lbl_wt : variable label _iivw_weight
    assert `"`lbl_wt'"' == "IIW weight"
}
if _rc == 0 {
    display as result "  PASS: Test 100 - IIW weight label"
    local ++pass_count
}
else {
    display as error "  FAIL: Test 100 - IIW label (error `=_rc')"
    local ++fail_count
}
}

* TEST 101: IPTW weight label
if `run_only' == 0 | `run_only' == 101 {
local ++test_count
capture noisily {
    _setup_relapses
    bysort id (days): gen double edss_bl = edss[1]
    iivw_weight, id(id) time(days) visit_cov(edss) ///
        treat(treated) treat_cov(edss_bl) wtype(iptw) nolog
    local lbl_wt : variable label _iivw_weight
    assert `"`lbl_wt'"' == "IPTW weight"
}
if _rc == 0 {
    display as result "  PASS: Test 101 - IPTW weight label"
    local ++pass_count
}
else {
    display as error "  FAIL: Test 101 - IPTW label (error `=_rc')"
    local ++fail_count
}
}

* TEST 102: Categorical + interaction + ns() combination
if `run_only' == 0 | `run_only' == 102 {
local ++test_count
capture noisily {
    _setup_relapses
    gen byte arm = mod(id, 3)
    label define arm_lbl 0 "Placebo" 1 "Low dose" 2 "High dose", replace
    label values arm arm_lbl
    iivw_weight, id(id) time(days) visit_cov(edss relapse) nolog
    iivw_fit edss arm, timespec(ns(2)) categorical(arm) ///
        interaction(arm) nolog
    confirm variable _iivw_cat_low_dose
    confirm variable _iivw_cat_high_dose
    confirm variable _iivw_ix_low_dose_tns1
    confirm variable _iivw_ix_low_dose_tns2
    confirm variable _iivw_ix_high_dose_tns1
    confirm variable _iivw_ix_high_dose_tns2
    assert e(N) > 0
}
if _rc == 0 {
    display as result "  PASS: Test 102 - Categorical + interaction + ns(2)"
    local ++pass_count
}
else {
    display as error "  FAIL: Test 102 - cat+ix+ns (error `=_rc')"
    local ++fail_count
}
}

* TEST 103: Cross-variable categorical collision detection
if `run_only' == 0 | `run_only' == 103 {
local ++test_count
capture noisily {
    _setup_relapses
    * Create two categorical vars whose labels sanitize to the same name
    gen byte arm = mod(id, 2)
    label define arm_lbl2 0 "Control" 1 "Active", replace
    label values arm arm_lbl2
    gen byte site = mod(id, 2)
    label define site_lbl2 0 "Control" 1 "Active", replace
    label values site site_lbl2
    iivw_weight, id(id) time(days) visit_cov(edss relapse) nolog
    iivw_fit edss arm site, categorical(arm site) nolog
    * When cross-variable collision detected, site should fall back to numeric
    * arm gets label-based: _iivw_cat_active
    * site should get numeric: _iivw_cat_site_1 (collision with arm's _iivw_cat_active)
    assert "`e(iivw_cat_vars)'" != ""
    assert e(N) > 0
}
if _rc == 0 {
    display as result "  PASS: Test 103 - Cross-variable categorical collision"
    local ++pass_count
}
else {
    display as error "  FAIL: Test 103 - cross-var collision (error `=_rc')"
    local ++fail_count
}
}

* TEST 104: Error - wtype(fiptiw) explicit without visit_cov()
if `run_only' == 0 | `run_only' == 104 {
local ++test_count
capture noisily {
    _setup_relapses
    capture iivw_weight, id(id) time(days) treat(treated) ///
        wtype(fiptiw) nolog
    assert _rc == 198
}
if _rc == 0 {
    display as result "  PASS: Test 104 - Error: wtype(fiptiw) without visit_cov()"
    local ++pass_count
}
else {
    display as error "  FAIL: Test 104 - fiptiw no visit_cov (error `=_rc')"
    local ++fail_count
}
}

* TEST 105: wtype(iptw) with treat_cov only (no visit_cov)
if `run_only' == 0 | `run_only' == 105 {
local ++test_count
capture noisily {
    _setup_relapses
    bysort id (days): gen double edss_bl = edss[1]
    iivw_weight, id(id) time(days) ///
        treat(treated) treat_cov(edss_bl) wtype(iptw) nolog
    assert "`r(weighttype)'" == "iptw"
    assert r(N) > 0
    confirm variable _iivw_tw
    confirm variable _iivw_weight
}
if _rc == 0 {
    display as result "  PASS: Test 105 - wtype(iptw) with treat_cov only"
    local ++pass_count
}
else {
    display as error "  FAIL: Test 105 - iptw treat_cov only (error `=_rc')"
    local ++fail_count
}
}

* =============================================================================
* v1.0.1 - regtab integration + console summary table
* =============================================================================

* Install tabtools for regtab integration tests (108-110)
capture ado uninstall tabtools
quietly net install tabtools, from("`repo_dir'/tabtools") replace
capture which regtab
if _rc {
    display as error "regtab is unavailable after local tabtools install"
    exit _rc
}

* TEST 106: Console summary shows all predictors (GEE)
if `run_only' == 0 | `run_only' == 106 {
local ++test_count
capture noisily {
    _setup_relapses
    bysort id (days): gen double edss_bl = edss[1]
    iivw_weight, id(id) time(days) visit_cov(edss relapse) nolog
    iivw_fit edss treated edss_bl, model(gee) timespec(linear) nolog
    * Verify e() results stored for all predictors
    assert _b[treated] != .
    assert _b[edss_bl] != .
    assert _se[treated] > 0
    assert _se[edss_bl] > 0
}
if _rc == 0 {
    display as result "  PASS: Test 106 - Console summary shows all predictors (GEE)"
    local ++pass_count
}
else {
    display as error "  FAIL: Test 106 - GEE console summary (error `=_rc')"
    local ++fail_count
}
}

* TEST 107: Console summary shows all predictors (mixed)
if `run_only' == 0 | `run_only' == 107 {
local ++test_count
capture noisily {
    _setup_relapses
    bysort id (days): gen double edss_bl = edss[1]
    iivw_weight, id(id) time(days) visit_cov(edss relapse) nolog
    iivw_fit edss treated edss_bl, model(mixed) timespec(linear) nolog
    * Verify e() results stored for all predictors
    assert _b[treated] != .
    assert _b[edss_bl] != .
    assert _se[treated] > 0
    assert _se[edss_bl] > 0
}
if _rc == 0 {
    display as result "  PASS: Test 107 - Console summary shows all predictors (mixed)"
    local ++pass_count
}
else {
    display as error "  FAIL: Test 107 - mixed console summary (error `=_rc')"
    local ++fail_count
}
}

* TEST 108: collect + regtab basic export (GEE gaussian -> Coef. auto-detect)
if `run_only' == 0 | `run_only' == 108 {
local ++test_count
capture noisily {
    _setup_relapses
    bysort id (days): gen double edss_bl = edss[1]
    iivw_weight, id(id) time(days) visit_cov(edss relapse) nolog
    collect clear
    collect: iivw_fit edss treated edss_bl, model(gee) timespec(linear) nolog
    * Export without coef() - should auto-detect "Coef." for gaussian glm
    local _xlsxfile "/tmp/_test_iivw_regtab_108.xlsx"
    capture erase "`_xlsxfile'"
    regtab, xlsx("`_xlsxfile'") sheet(Test108) title(IIW Test)
    * Verify Excel file created
    confirm file "`_xlsxfile'"
    capture erase "`_xlsxfile'"
}
if _rc == 0 {
    display as result "  PASS: Test 108 - collect + regtab basic export"
    local ++pass_count
}
else {
    display as error "  FAIL: Test 108 - collect + regtab export (error `=_rc')"
    local ++fail_count
}
}

* TEST 109: Multi-model collection (IIW vs FIPTIW)
if `run_only' == 0 | `run_only' == 109 {
local ++test_count
capture noisily {
    _setup_relapses
    bysort id (days): gen double edss_bl = edss[1]
    collect clear
    * Model 1: IIW
    iivw_weight, id(id) time(days) visit_cov(edss relapse) nolog
    collect: iivw_fit edss treated edss_bl, model(gee) timespec(linear) nolog
    * Model 2: FIPTIW
    iivw_weight, id(id) time(days) visit_cov(edss relapse) ///
        treat(treated) treat_cov(edss_bl) replace nolog
    collect: iivw_fit edss treated edss_bl, model(gee) timespec(linear) nolog
    * Export multi-model table
    local _xlsxfile "/tmp/_test_iivw_regtab_109.xlsx"
    capture erase "`_xlsxfile'"
    regtab, xlsx("`_xlsxfile'") sheet(Test109) ///
        models(IIW \ FIPTIW) title(Comparison) stats(n) noint
    confirm file "`_xlsxfile'"
    capture erase "`_xlsxfile'"
}
if _rc == 0 {
    display as result "  PASS: Test 109 - Multi-model IIW vs FIPTIW collection"
    local ++pass_count
}
else {
    display as error "  FAIL: Test 109 - multi-model collection (error `=_rc')"
    local ++fail_count
}
}

* TEST 110: Mixed model via collect + regtab
if `run_only' == 0 | `run_only' == 110 {
local ++test_count
capture noisily {
    _setup_relapses
    bysort id (days): gen double edss_bl = edss[1]
    iivw_weight, id(id) time(days) visit_cov(edss relapse) nolog
    collect clear
    collect: iivw_fit edss treated edss_bl, model(mixed) timespec(linear) nolog
    local _xlsxfile "/tmp/_test_iivw_regtab_110.xlsx"
    capture erase "`_xlsxfile'"
    regtab, xlsx("`_xlsxfile'") sheet(Test110) title(Mixed Model)
    confirm file "`_xlsxfile'"
    capture erase "`_xlsxfile'"
}
if _rc == 0 {
    display as result "  PASS: Test 110 - Mixed model via collect + regtab"
    local ++pass_count
}
else {
    display as error "  FAIL: Test 110 - mixed + regtab (error `=_rc')"
    local ++fail_count
}
}

* TEST 111: Console summary with categorical predictors
if `run_only' == 0 | `run_only' == 111 {
local ++test_count
capture noisily {
    _setup_relapses
    bysort id (days): gen double edss_bl = edss[1]
    * Create 3-level treatment
    gen byte arm = cond(treated == 0, 0, cond(edss_bl < 4, 1, 2))
    label define arm_t111 0 "Placebo" 1 "Low" 2 "High", replace
    label values arm arm_t111
    iivw_weight, id(id) time(days) visit_cov(edss relapse) nolog
    iivw_fit edss arm edss_bl, categorical(arm) model(gee) nolog
    * Verify dummy coefficients are accessible
    assert e(N) > 0
    assert "`e(iivw_cat_vars)'" != ""
}
if _rc == 0 {
    display as result "  PASS: Test 111 - Console summary with categorical predictors"
    local ++pass_count
}
else {
    display as error "  FAIL: Test 111 - categorical console summary (error `=_rc')"
    local ++fail_count
}
}

* =============================================================================
* TEST 112: Package installation - all commands discoverable via which
* =============================================================================
local ++test_count
if `run_only' == 0 | `run_only' == 112 {
    capture noisily {
        capture ado uninstall iivw
        quietly net install iivw, from("`pkg_dir'") replace
        which iivw
        which iivw_weight
        which iivw_fit
        which iivw_exogtest
        which iivw_diagnose
        which _iivw_bs_estimate
        which _iivw_check_weighted
        which _iivw_get_settings
    }
    if _rc == 0 {
        display as result "  PASS: Test 112 - All commands discoverable via which after net install"
        local ++pass_count
    }
    else {
        display as error "  FAIL: Test 112 - which after net install (error `=_rc')"
        local ++fail_count
    }
}

* =============================================================================
* TEST 113: Helper auto-loading after fresh install
* =============================================================================
local ++test_count
if `run_only' == 0 | `run_only' == 113 {
    capture noisily {
        capture ado uninstall iivw
        quietly net install iivw, from("`pkg_dir'") replace
        * Run iivw_fit which depends on _iivw_check_weighted and _iivw_get_settings
        _setup_relapses
        iivw_weight, id(id) time(days) visit_cov(edss relapse) nolog
        iivw_fit edss relapse, model(gee) timespec(linear) nolog
        assert e(N) > 0
    }
    if _rc == 0 {
        display as result "  PASS: Test 113 - Helper auto-loads after net install"
        local ++pass_count
    }
    else {
        display as error "  FAIL: Test 113 - Helper auto-load failed (error `=_rc')"
        display as error "        Check: are _iivw_*.ado files listed in .pkg?"
        local ++fail_count
    }
}

* =============================================================================
* TEST 114: Settings restore - commands do not leak set more off
* =============================================================================
local ++test_count
if `run_only' == 0 | `run_only' == 114 {
    capture noisily {
        _setup_relapses
        iivw_weight, id(id) time(days) visit_cov(edss relapse) nolog
        * Check iivw_weight did not change set more
        assert "`c(more)'" == "off"
        iivw_fit edss relapse, model(gee) timespec(linear) nolog
        * Check iivw_fit did not change set more
        assert "`c(more)'" == "off"
    }
    if _rc == 0 {
        display as result "  PASS: Test 114 - Commands do not leak settings"
        local ++pass_count
    }
    else {
        display as error "  FAIL: Test 114 - settings leak (error `=_rc')"
        local ++fail_count
    }
}

* =============================================================================
* TEST 115: varabbrev restored after iivw overview
* =============================================================================
local ++test_count
if `run_only' == 0 | `run_only' == 115 {
    capture noisily {
        set varabbrev on
        iivw
        assert "`c(varabbrev)'" == "on"
        set varabbrev off
    }
    if _rc == 0 {
        display as result "  PASS: Test 115 - varabbrev restored after iivw overview"
        local ++pass_count
    }
    else {
        display as error "  FAIL: Test 115 - varabbrev iivw overview (error `=_rc')"
        local ++fail_count
    }
}

* =============================================================================
* TEST 116: IPTW-only accepts one row per subject
* =============================================================================
local ++test_count
if `run_only' == 0 | `run_only' == 116 {
    capture noisily {
        clear
        set seed 20260430
        set obs 80
        gen long id = _n
        gen double days = 0
        gen double x = rnormal()
        gen byte treated = (_n <= 40)
        iivw_weight, id(id) time(days) treat(treated) treat_cov(x) ///
            wtype(iptw) nolog
        assert "`r(weighttype)'" == "iptw"
        assert r(n_ids) == 80
        confirm variable _iivw_tw
        confirm variable _iivw_weight
        capture confirm variable _iivw_iw
        assert _rc != 0
    }
    if _rc == 0 {
        display as result "  PASS: Test 116 - IPTW-only accepts one row per subject"
        local ++pass_count
    }
    else {
        display as error "  FAIL: Test 116 - IPTW single-row subjects (error `=_rc')"
        local ++fail_count
    }
}

* =============================================================================
* TEST 117: iivw_fit allows a time-only model
* =============================================================================
local ++test_count
if `run_only' == 0 | `run_only' == 117 {
    capture noisily {
        _setup_relapses
        iivw_weight, id(id) time(days) visit_cov(edss relapse) nolog
        iivw_fit edss, model(gee) timespec(linear) nolog
        assert e(N) > 0
        assert _b[days] != .
        assert "`e(iivw_display_vars)'" == "days"
    }
    if _rc == 0 {
        display as result "  PASS: Test 117 - iivw_fit time-only model"
        local ++pass_count
    }
    else {
        display as error "  FAIL: Test 117 - time-only fit (error `=_rc')"
        local ++fail_count
    }
}

* =============================================================================
* TEST 118: iivw_fit allows an intercept-only weighted model
* =============================================================================
local ++test_count
if `run_only' == 0 | `run_only' == 118 {
    capture noisily {
        _setup_relapses
        iivw_weight, id(id) time(days) visit_cov(edss relapse) nolog
        iivw_fit edss, model(gee) timespec(none) nolog
        assert e(N) > 0
        assert "`e(iivw_display_vars)'" == ""
    }
    if _rc == 0 {
        display as result "  PASS: Test 118 - iivw_fit intercept-only model"
        local ++pass_count
    }
    else {
        display as error "  FAIL: Test 118 - intercept-only fit (error `=_rc')"
        local ++fail_count
    }
}

* =============================================================================
* TEST 119: Categorical time creates labeled time dummies
* =============================================================================
local ++test_count
if `run_only' == 0 | `run_only' == 119 {
    capture noisily {
        _setup_relapses
        bysort id (days): gen byte visit_wave = _n
        keep if visit_wave <= 4
        bysort id: gen byte _nvis = _N
        keep if _nvis >= 2
        drop _nvis
        label variable visit_wave "Visit wave"
        label define wave_t119 1 "Baseline" 2 "Second visit" ///
            3 "Third visit" 4 "Fourth visit", replace
        label values visit_wave wave_t119
        iivw_weight, id(id) time(visit_wave) visit_cov(edss relapse) nolog
        iivw_fit edss treated, model(gee) timespec(categorical) nolog
        assert "`e(iivw_timespec)'" == "categorical"
        assert "`e(iivw_time_basecat)'" == "1"
        confirm variable _iivw_tcat_1
        confirm variable _iivw_tcat_2
        confirm variable _iivw_tcat_3
        local tlbl : variable label _iivw_tcat_1
        assert `"`tlbl'"' == `"Visit wave: Second visit (vs. Baseline)"'
        assert strpos("`e(iivw_display_vars)'", "_iivw_tcat_1") > 0
        assert "`e(iivw_time_vars)'" == "_iivw_tcat_1 _iivw_tcat_2 _iivw_tcat_3"
        assert "`e(iivw_time_cat_vars)'" == "_iivw_tcat_1 _iivw_tcat_2 _iivw_tcat_3"
        local tv : char _dta[_iivw_time_cat_vars]
        assert "`tv'" == "_iivw_tcat_1 _iivw_tcat_2 _iivw_tcat_3"
    }
    if _rc == 0 {
        display as result "  PASS: Test 119 - categorical time dummies labeled"
        local ++pass_count
    }
    else {
        display as error "  FAIL: Test 119 - categorical time dummies (error `=_rc')"
        local ++fail_count
    }
}

* =============================================================================
* TEST 120: Categorical predictor x categorical time labels are table-ready
* =============================================================================
local ++test_count
if `run_only' == 0 | `run_only' == 120 {
    capture noisily {
        _setup_relapses
        bysort id (days): gen byte visit_wave = _n
        keep if visit_wave <= 4
        bysort id: gen byte _nvis = _N
        keep if _nvis >= 2
        drop _nvis
        bysort id (days): gen double edss_bl = edss[1]
        label variable visit_wave "Visit wave"
        label define wave_t120 1 "Baseline" 2 "Second visit" ///
            3 "Third visit" 4 "Fourth visit", replace
        label values visit_wave wave_t120
        label define treated_t120 0 "Placebo" 1 "Drug", replace
        label values treated treated_t120
        iivw_weight, id(id) time(visit_wave) visit_cov(edss relapse) ///
            treat(treated) treat_cov(edss_bl) nolog
        iivw_fit edss treated edss_bl, model(gee) timespec(categorical) ///
            categorical(treated) interaction(treated) nolog
        confirm variable _iivw_ix_drug_tcat_1
        local ixlbl : variable label _iivw_ix_drug_tcat_1
        assert `"`ixlbl'"' == `"Drug x Visit wave: Second visit"'
        assert strpos("`e(iivw_ix_vars)'", "_iivw_ix_drug_tcat_1") > 0
    }
    if _rc == 0 {
        display as result "  PASS: Test 120 - categorical time interaction labels"
        local ++pass_count
    }
    else {
        display as error "  FAIL: Test 120 - categorical time interactions (error `=_rc')"
        local ++fail_count
    }
}

* =============================================================================
* TEST 121: timebasecat() changes categorical-time reference
* =============================================================================
local ++test_count
if `run_only' == 0 | `run_only' == 121 {
    capture noisily {
        _setup_relapses
        bysort id (days): gen byte visit_wave = _n
        keep if visit_wave <= 4
        bysort id: gen byte _nvis = _N
        keep if _nvis >= 2
        drop _nvis
        label variable visit_wave "Visit wave"
        label define wave_t121 1 "Baseline" 2 "Second visit" ///
            3 "Third visit" 4 "Fourth visit", replace
        label values visit_wave wave_t121
        iivw_weight, id(id) time(visit_wave) visit_cov(edss relapse) nolog
        iivw_fit edss treated, model(gee) timespec(categorical) ///
            timebasecat(2) nolog
        assert "`e(iivw_time_basecat)'" == "2"
        local tlbl : variable label _iivw_tcat_1
        assert `"`tlbl'"' == `"Visit wave: Baseline (vs. Second visit)"'
        capture confirm variable _iivw_tcat_4
        assert _rc != 0
    }
    if _rc == 0 {
        display as result "  PASS: Test 121 - timebasecat sets reference"
        local ++pass_count
    }
    else {
        display as error "  FAIL: Test 121 - timebasecat reference (error `=_rc')"
        local ++fail_count
    }
}

* =============================================================================
* TEST 122: collect + regtab carries categorical-time interaction labels
* =============================================================================
local ++test_count
if `run_only' == 0 | `run_only' == 122 {
    capture noisily {
        _setup_relapses
        bysort id (days): gen byte visit_wave = _n
        keep if visit_wave <= 4
        bysort id: gen byte _nvis = _N
        keep if _nvis >= 2
        drop _nvis
        bysort id (days): gen double edss_bl = edss[1]
        label variable visit_wave "Visit wave"
        label define wave_t122 1 "Baseline" 2 "Second visit" ///
            3 "Third visit" 4 "Fourth visit", replace
        label values visit_wave wave_t122
        label define treated_t122 0 "Placebo" 1 "Drug", replace
        label values treated treated_t122
        iivw_weight, id(id) time(visit_wave) visit_cov(edss relapse) ///
            treat(treated) treat_cov(edss_bl) nolog
        collect clear
        iivw_fit edss treated edss_bl, model(gee) timespec(categorical) ///
            categorical(treated) interaction(treated) nolog collect
        local _xlsxfile "/tmp/_test_iivw_regtab_122.xlsx"
        capture erase "`_xlsxfile'"
        regtab, xlsx("`_xlsxfile'") sheet(Test122) title(Categorical Time)
        confirm file "`_xlsxfile'"
        import excel using "`_xlsxfile'", clear allstring
        local found = 0
        ds
        foreach v of varlist `r(varlist)' {
            quietly count if strpos(`v', "Drug x Visit wave: Second visit") > 0
            if r(N) > 0 local found = 1
        }
        assert `found' == 1
        capture erase "`_xlsxfile'"
    }
    if _rc == 0 {
        display as result "  PASS: Test 122 - regtab carries categorical-time labels"
        local ++pass_count
    }
    else {
        display as error "  FAIL: Test 122 - regtab categorical-time labels (error `=_rc')"
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
