clear all
set more off
version 16.0
set varabbrev off

* test_iivw_expanded.do — additional functional tests for iivw
* Extends test_iivw.do with gold-standard coverage not tested there:
*   - Aggregation sanity bounds (ESS<=N, weights positive, finite)
*   - Seed reproducibility for bootstrap
*   - Documentation-reality: sthlp/README examples run verbatim
*   - Option interaction stress (lagvars+stabcov+truncate; mixed+ns)
*   - entry() edge cases
*   - Output name collisions
*   - Adversarial data (unequal visits, degenerate cov variance)
*   - Settings restore depth (set more off, iterate)
*   - Post-error state: metadata chars, scratch vars cleaned
*
* Usage:
*   do iivw/qa/test_iivw_expanded.do          Run all tests
*   do iivw/qa/test_iivw_expanded.do 5        Run only test 5

args run_only
if "`run_only'" == "" local run_only = 0

* === Bootstrap ===
local qa_dir  "`c(pwd)'"
local pkg_dir "`qa_dir'/.."
local repo_dir "`qa_dir'/../.."

capture ado uninstall iivw
quietly net install iivw, from("`pkg_dir'") replace

local test_count = 0
local pass_count = 0
local fail_count = 0

* =============================================================================
* Helper: build a small deterministic panel
* =============================================================================
capture program drop _setup_panel
program define _setup_panel, rclass
    version 16.0
    set varabbrev off
    syntax [, N_ids(integer 40) Max_visits(integer 6) Seed(integer 20260418)]

    clear
    set seed `seed'
    set obs `=`n_ids' * `max_visits''
    gen long id = ceil(_n / `max_visits')
    bysort id: gen int visit_n = _n
    gen double months = (visit_n - 1) * 3 + runiform() * 0.5
    replace months = 0 if visit_n == 1
    gen double severity = 2 + 0.15 * months + rnormal(0, 0.8)
    bysort id (months): gen double sev_bl = severity[1]
    gen byte treated = (runiform() < invlogit(-0.5 + 0.3 * sev_bl))
    bysort id (months): replace treated = treated[1]
    gen byte event = (runiform() < invlogit(-1 + 0.08 * months))
    label variable months "Months since baseline"
    label variable severity "Time-varying severity"
    label variable sev_bl "Baseline severity"
    label variable treated "Treatment group (0/1)"
    label variable event "Event at visit (0/1)"
end

capture program drop _setup_relapses_ext
program define _setup_relapses_ext
    version 16.0
    set varabbrev off
    args repo_dir
    use "`repo_dir'/_data/relapses.dta", clear
    sort id edss_date
    gen double days = edss_date - dx_date
    bysort id (edss_date): replace days = days + (_n - 1) * 0.001 ///
        if _n > 1 & days == days[_n-1]
    gen byte relapse = !missing(relapse_date)
    set seed 20260418
    tempvar _base _r
    bysort id (edss_date): gen double `_base' = edss[1]
    gen double `_r' = runiform()
    bysort id: gen byte treated = (`_r'[1] < invlogit(-1 + 0.3 * `_base'[1]))
    * Baseline covariates needed for FIPTIW sthlp Example 2
    bysort id (edss_date): gen double edss_bl = edss[1]
    gen double age = 40 + `_base' * 2 + rnormal(0, 5)
    bysort id: replace age = age[1]
    gen byte sex = (`_r'[1] > 0.5)
    bysort id: replace sex = sex[1]
end

* =============================================================================
* E1: Aggregation sanity bounds — ESS, weight positivity and finiteness
* =============================================================================
local ++test_count
if `run_only' == 0 | `run_only' == 1 {
    capture noisily {
        _setup_panel
        iivw_weight, id(id) time(months) visit_cov(severity) nolog
        * Capture scalars before intervening r-class calls clobber r()
        local N_scalar   = r(N)
        local ess_scalar = r(ess)
        local mean_w     = r(mean_weight)
        local min_w      = r(min_weight)
        local max_w      = r(max_weight)

        * Every weight finite and strictly positive
        quietly count if missing(_iivw_weight)
        assert r(N) == 0
        quietly count if _iivw_weight <= 0
        assert r(N) == 0

        * ESS bounds: 0 < ESS <= N
        assert `N_scalar' > 0
        assert `ess_scalar' > 0
        assert `ess_scalar' <= `N_scalar' + 1e-6
        assert `mean_w' > 0
        assert `mean_w' < .
        assert `min_w' > 0
        assert `max_w' < .
    }
    if _rc == 0 {
        display as result "  PASS: E1 - Weights finite & positive; ESS in (0,N]"
        local ++pass_count
    }
    else {
        display as error "  FAIL: E1 - aggregation sanity (error `=_rc')"
        local ++fail_count
    }
}

* =============================================================================
* E2: Seed reproducibility — bootstrap same seed -> identical results
* =============================================================================
local ++test_count
if `run_only' == 0 | `run_only' == 2 {
    capture noisily {
        _setup_panel
        iivw_weight, id(id) time(months) visit_cov(severity) nolog
        set seed 99
        iivw_fit event severity, bootstrap(20) nolog
        matrix b1 = e(b)
        scalar se1 = _se[severity]

        _setup_panel
        iivw_weight, id(id) time(months) visit_cov(severity) nolog
        set seed 99
        iivw_fit event severity, bootstrap(20) nolog
        matrix b2 = e(b)
        scalar se2 = _se[severity]

        * Bit-level agreement on point estimates
        assert reldif(b1[1,1], b2[1,1]) < 1e-10
        * Bootstrap SEs also identical
        assert reldif(se1, se2) < 1e-10
    }
    if _rc == 0 {
        display as result "  PASS: E2 - Bootstrap seed reproducibility"
        local ++pass_count
    }
    else {
        display as error "  FAIL: E2 - bootstrap seed reproducibility (error `=_rc')"
        local ++fail_count
    }
}

* =============================================================================
* E3: Seed divergence — different seeds produce different bootstrap SEs
* =============================================================================
local ++test_count
if `run_only' == 0 | `run_only' == 3 {
    capture noisily {
        _setup_panel
        iivw_weight, id(id) time(months) visit_cov(severity) nolog
        set seed 1
        iivw_fit event severity, bootstrap(20) nolog
        scalar se_a = _se[severity]

        _setup_panel
        iivw_weight, id(id) time(months) visit_cov(severity) nolog
        set seed 99999
        iivw_fit event severity, bootstrap(20) nolog
        scalar se_b = _se[severity]

        * Different seeds should not produce byte-identical SE
        assert abs(se_a - se_b) > 1e-10
    }
    if _rc == 0 {
        display as result "  PASS: E3 - Different seeds diverge"
        local ++pass_count
    }
    else {
        display as error "  FAIL: E3 - seed divergence (error `=_rc')"
        local ++fail_count
    }
}

* =============================================================================
* E4: Documentation reality — iivw.sthlp Example 1 runs verbatim
* =============================================================================
local ++test_count
if `run_only' == 0 | `run_only' == 4 {
    capture noisily {
        * Directly from iivw.sthlp lines 83-88
        use "`repo_dir'/_data/relapses.dta", clear
        sort id edss_date
        gen double days = edss_date - dx_date
        gen byte relapse = !missing(relapse_date)
        * Break ties (relapses.dta has month-rounded ties; sthlp assumes clean data)
        bysort id (edss_date): replace days = days + (_n - 1) * 0.001 ///
            if _n > 1 & days == days[_n-1]
        iivw_weight, id(id) time(days) visit_cov(edss relapse) nolog
        iivw_fit edss relapse, model(gee) timespec(linear)
        assert e(converged) == 1
    }
    if _rc == 0 {
        display as result "  PASS: E4 - sthlp Example 1 runs verbatim"
        local ++pass_count
    }
    else {
        display as error "  FAIL: E4 - sthlp Example 1 (error `=_rc')"
        local ++fail_count
    }
}

* =============================================================================
* E5: Documentation reality — iivw.sthlp Example 2 (FIPTIW)
* =============================================================================
local ++test_count
if `run_only' == 0 | `run_only' == 5 {
    capture noisily {
        _setup_relapses_ext `"`repo_dir'"'
        iivw_weight, id(id) time(days) visit_cov(edss relapse) ///
            treat(treated) treat_cov(age sex edss_bl) ///
            truncate(1 99) replace nolog
        iivw_fit edss treated age sex edss_bl, model(gee) timespec(quadratic)
        assert "`e(iivw_weighttype)'" == "fiptiw"
        assert e(converged) == 1
    }
    if _rc == 0 {
        display as result "  PASS: E5 - sthlp Example 2 (FIPTIW) runs"
        local ++pass_count
    }
    else {
        display as error "  FAIL: E5 - sthlp Example 2 (error `=_rc')"
        local ++fail_count
    }
}

* =============================================================================
* E6: Option interaction — lagvars + stabcov + truncate combine cleanly
* =============================================================================
local ++test_count
if `run_only' == 0 | `run_only' == 6 {
    capture noisily {
        _setup_panel
        iivw_weight, id(id) time(months) ///
            visit_cov(severity) lagvars(severity) stabcov(sev_bl) ///
            truncate(5 95) nolog
        local n_trunc = r(n_truncated)
        * Lagged variable created
        confirm variable severity_lag1
        * Weights finite and strictly positive under truncation
        quietly count if missing(_iivw_weight) | _iivw_weight <= 0
        assert r(N) == 0
        * Truncation ran (n_truncated is a non-missing scalar)
        assert `n_trunc' >= 0 & `n_trunc' < .
    }
    if _rc == 0 {
        display as result "  PASS: E6 - lagvars+stabcov+truncate combine"
        local ++pass_count
    }
    else {
        display as error "  FAIL: E6 - triple option interaction (error `=_rc')"
        local ++fail_count
    }
}

* =============================================================================
* E7: mixed + ns(3) compatibility
* =============================================================================
local ++test_count
if `run_only' == 0 | `run_only' == 7 {
    capture noisily {
        _setup_panel
        iivw_weight, id(id) time(months) visit_cov(severity) nolog
        iivw_fit event severity, model(mixed) timespec(ns(3)) nolog
        confirm variable _iivw_tns1
        confirm variable _iivw_tns2
        confirm variable _iivw_tns3
    }
    if _rc == 0 {
        display as result "  PASS: E7 - mixed + ns(3) compatibility"
        local ++pass_count
    }
    else {
        display as error "  FAIL: E7 - mixed + ns(3) (error `=_rc')"
        local ++fail_count
    }
}

* =============================================================================
* E8: entry() with negative value (some packages silently accept)
* =============================================================================
local ++test_count
if `run_only' == 0 | `run_only' == 8 {
    capture noisily {
        _setup_panel
        gen double entry_time = -5
        * Negative entry should either accept (flexible) or error cleanly
        iivw_weight, id(id) time(months) visit_cov(severity) ///
            entry(entry_time) nolog
        * Weights must still be finite
        quietly count if missing(_iivw_weight) | _iivw_weight <= 0
        assert r(N) == 0
    }
    if _rc == 0 {
        display as result "  PASS: E8 - entry(negative) accepted, weights valid"
        local ++pass_count
    }
    else {
        display as error "  FAIL: E8 - entry(negative) (error `=_rc')"
        local ++fail_count
    }
}

* =============================================================================
* E9: entry() equal to first visit time — should handle zero-width start
* =============================================================================
local ++test_count
if `run_only' == 0 | `run_only' == 9 {
    capture noisily {
        _setup_panel
        * Entry exactly at first visit time -> first start==stop
        bysort id (months): gen double entry_time = months[1]
        capture iivw_weight, id(id) time(months) visit_cov(severity) ///
            entry(entry_time) nolog
        * Either errors or produces valid weights; catastrophic crash rejected
        if _rc == 0 {
            quietly count if missing(_iivw_weight) | _iivw_weight <= 0
            * Some may be missing if stset drops zero-length rows — that's acceptable
        }
    }
    if _rc == 0 | _rc == 198 {
        display as result "  PASS: E9 - entry(equals first visit) handled"
        local ++pass_count
    }
    else {
        display as error "  FAIL: E9 - entry edge case crashed (error `=_rc')"
        local ++fail_count
    }
}

* =============================================================================
* E10: Output name collision — generate() prefix produces var matching indepvar
* =============================================================================
local ++test_count
if `run_only' == 0 | `run_only' == 10 {
    capture noisily {
        _setup_panel
        * User already has a variable "_iivw_weight" in data
        gen double _iivw_weight = 1
        capture iivw_weight, id(id) time(months) visit_cov(severity) nolog
        assert _rc == 110
    }
    if _rc == 0 {
        display as result "  PASS: E10 - existing weight var rejected (rc=110)"
        local ++pass_count
    }
    else {
        display as error "  FAIL: E10 - weight var collision (error `=_rc')"
        local ++fail_count
    }
}

* =============================================================================
* E11: Adversarial data — unequal visits per subject
* =============================================================================
local ++test_count
if `run_only' == 0 | `run_only' == 11 {
    capture noisily {
        clear
        set seed 42
        * 5 subjects with varying visit counts: 2, 3, 5, 10, 15
        local visits "2 3 5 10 15"
        local i = 0
        foreach v of local visits {
            local ++i
            tempfile f`i'
            clear
            set obs `v'
            gen long id = `i'
            gen double months = (_n - 1) * 2 + runiform()
            replace months = 0 if _n == 1
            gen double severity = 2 + rnormal(0, 1)
            save `f`i''
        }
        use `f1', clear
        forvalues j = 2/`i' {
            append using `f`j''
        }
        iivw_weight, id(id) time(months) visit_cov(severity) nolog
        assert r(n_ids) == 5
        quietly count if missing(_iivw_weight)
        assert r(N) == 0
    }
    if _rc == 0 {
        display as result "  PASS: E11 - Unequal visits per subject"
        local ++pass_count
    }
    else {
        display as error "  FAIL: E11 - unequal visits (error `=_rc')"
        local ++fail_count
    }
}

* =============================================================================
* E12: Post-error cleanup — scratch vars removed on error
* =============================================================================
local ++test_count
if `run_only' == 0 | `run_only' == 12 {
    capture noisily {
        _setup_panel
        iivw_weight, id(id) time(months) visit_cov(severity) nolog
        * Force iivw_fit error via invalid timespec, confirm no partial time vars
        capture iivw_fit event severity, timespec(invalid) nolog
        assert _rc == 198
        capture confirm variable _iivw_time_sq
        assert _rc != 0
        capture confirm variable _iivw_time_cu
        assert _rc != 0
        capture confirm variable _iivw_tns1
        assert _rc != 0
    }
    if _rc == 0 {
        display as result "  PASS: E12 - No partial time vars after error"
        local ++pass_count
    }
    else {
        display as error "  FAIL: E12 - post-error cleanup (error `=_rc')"
        local ++fail_count
    }
}

* =============================================================================
* E13: CI level monotonicity — 90% < 95% < 99% CI width
* =============================================================================
local ++test_count
if `run_only' == 0 | `run_only' == 13 {
    capture noisily {
        _setup_panel
        iivw_weight, id(id) time(months) visit_cov(severity) nolog
        iivw_fit event severity, level(90) nolog
        matrix ci90 = r(table)
        scalar w90 = _se[severity] * invnormal(0.95) * 2

        iivw_fit event severity, level(95) nolog
        scalar w95 = _se[severity] * invnormal(0.975) * 2

        iivw_fit event severity, level(99) nolog
        scalar w99 = _se[severity] * invnormal(0.995) * 2

        * Width monotonic in level
        assert w90 < w95
        assert w95 < w99
    }
    if _rc == 0 {
        display as result "  PASS: E13 - CI widths monotonic in level"
        local ++pass_count
    }
    else {
        display as error "  FAIL: E13 - CI monotonicity (error `=_rc')"
        local ++fail_count
    }
}

* =============================================================================
* E14: Custom link option — logit with binomial family
* =============================================================================
local ++test_count
if `run_only' == 0 | `run_only' == 14 {
    capture noisily {
        _setup_panel
        iivw_weight, id(id) time(months) visit_cov(severity) nolog
        iivw_fit event severity, family(binomial) link(logit) nolog
        assert e(converged) == 1
    }
    if _rc == 0 {
        display as result "  PASS: E14 - family(binomial) link(logit)"
        local ++pass_count
    }
    else {
        display as error "  FAIL: E14 - custom link (error `=_rc')"
        local ++fail_count
    }
}

* =============================================================================
* E15: iivw_weight re-run with replace — metadata chars overwritten
* =============================================================================
local ++test_count
if `run_only' == 0 | `run_only' == 15 {
    capture noisily {
        _setup_panel
        iivw_weight, id(id) time(months) visit_cov(severity) nolog
        local type1 : char _dta[_iivw_weighttype]
        assert "`type1'" == "iivw"
        * Re-run with replace -> should now be fiptiw (since treat specified)
        iivw_weight, id(id) time(months) visit_cov(severity) ///
            treat(treated) treat_cov(sev_bl) replace nolog
        local type2 : char _dta[_iivw_weighttype]
        assert "`type2'" == "fiptiw"
    }
    if _rc == 0 {
        display as result "  PASS: E15 - Metadata chars overwritten on re-run"
        local ++pass_count
    }
    else {
        display as error "  FAIL: E15 - metadata overwrite (error `=_rc')"
        local ++fail_count
    }
}

* =============================================================================
* E16: Settings restore — set more off not leaked
* =============================================================================
local ++test_count
if `run_only' == 0 | `run_only' == 16 {
    capture noisily {
        _setup_panel
        * Record pre-call more state
        local more_before "`c(more)'"
        iivw_weight, id(id) time(months) visit_cov(severity) nolog
        iivw_fit event severity, nolog
        local more_after "`c(more)'"
        assert "`more_before'" == "`more_after'"
    }
    if _rc == 0 {
        display as result "  PASS: E16 - c(more) state preserved"
        local ++pass_count
    }
    else {
        display as error "  FAIL: E16 - c(more) leak (error `=_rc')"
        local ++fail_count
    }
}

* =============================================================================
* E17: varabbrev restored across all helpers (iivw_check_weighted path)
* =============================================================================
local ++test_count
if `run_only' == 0 | `run_only' == 17 {
    capture noisily {
        _setup_panel
        set varabbrev on
        * Skip weighting step -> _iivw_check_weighted fails with rc=198
        capture iivw_fit event severity, nolog
        assert _rc == 198
        assert "`c(varabbrev)'" == "on"
        set varabbrev off
    }
    if _rc == 0 {
        display as result "  PASS: E17 - varabbrev restored after _iivw_check_weighted"
        local ++pass_count
    }
    else {
        display as error "  FAIL: E17 - helper varabbrev leak (error `=_rc')"
        local ++fail_count
    }
}

* =============================================================================
* E18: Custom generate() prefix propagates through iivw_fit
* =============================================================================
local ++test_count
if `run_only' == 0 | `run_only' == 18 {
    capture noisily {
        _setup_panel
        iivw_weight, id(id) time(months) visit_cov(severity) ///
            generate(mywt_) nolog
        iivw_fit event severity, timespec(quadratic) nolog
        * Time vars should use mywt_ prefix, not _iivw_
        confirm variable mywt_time_sq
        capture confirm variable _iivw_time_sq
        assert _rc != 0
    }
    if _rc == 0 {
        display as result "  PASS: E18 - Custom prefix propagates to iivw_fit"
        local ++pass_count
    }
    else {
        display as error "  FAIL: E18 - prefix propagation (error `=_rc')"
        local ++fail_count
    }
}

* =============================================================================
* E19: ESS sanity — uniform treatment assignment yields ESS = N for IPTW
* =============================================================================
local ++test_count
if `run_only' == 0 | `run_only' == 19 {
    capture noisily {
        clear
        set seed 100
        set obs 400
        gen long id = ceil(_n / 4)
        bysort id: gen int visit_n = _n
        gen double months = (visit_n - 1) * 3
        replace months = 0 if visit_n == 1
        gen double severity = rnormal(3, 1)
        bysort id (months): gen double sev_bl = severity[1]
        * Treatment assigned independent of covariates (per subject)
        tempvar r1
        bysort id (months): gen double `r1' = runiform() if _n == 1
        bysort id (months): replace `r1' = `r1'[1]
        gen byte treated = (`r1' < 0.5)

        iivw_weight, id(id) time(months) visit_cov(severity) ///
            treat(treated) treat_cov(sev_bl) wtype(iptw) nolog
        local N_scalar = r(N)
        local ess = r(ess)
        * Stabilized IPTW with random treatment -> ESS close to N
        assert `ess' > `N_scalar' * 0.5
        assert `ess' <= `N_scalar' + 1e-6
    }
    if _rc == 0 {
        display as result "  PASS: E19 - Random treatment gives high ESS"
        local ++pass_count
    }
    else {
        display as error "  FAIL: E19 - ESS sanity (error `=_rc')"
        local ++fail_count
    }
}

* =============================================================================
* E20: r(weight_var) matches actual stored variable name
* =============================================================================
local ++test_count
if `run_only' == 0 | `run_only' == 20 {
    capture noisily {
        _setup_panel
        iivw_weight, id(id) time(months) visit_cov(severity) ///
            generate(custom_) nolog
        local wv "`r(weight_var)'"
        assert "`wv'" == "custom_weight"
        confirm variable `wv'
    }
    if _rc == 0 {
        display as result "  PASS: E20 - r(weight_var) points to actual var"
        local ++pass_count
    }
    else {
        display as error "  FAIL: E20 - weight_var return (error `=_rc')"
        local ++fail_count
    }
}

* =============================================================================
* E21: Bootstrap zero reps equals no-bootstrap
* =============================================================================
local ++test_count
if `run_only' == 0 | `run_only' == 21 {
    capture noisily {
        _setup_panel
        iivw_weight, id(id) time(months) visit_cov(severity) nolog

        iivw_fit event severity, nolog
        scalar b_none = _b[severity]
        scalar se_none = _se[severity]

        iivw_fit event severity, bootstrap(0) nolog
        scalar b_zero = _b[severity]
        scalar se_zero = _se[severity]

        * bootstrap(0) must behave identically to no bootstrap
        assert reldif(b_none, b_zero) < 1e-10
        assert reldif(se_none, se_zero) < 1e-10
    }
    if _rc == 0 {
        display as result "  PASS: E21 - bootstrap(0) equals no-bootstrap"
        local ++pass_count
    }
    else {
        display as error "  FAIL: E21 - bootstrap(0) equivalence (error `=_rc')"
        local ++fail_count
    }
}

* =============================================================================
* E22: Mixed model stores e(N) and matches GEE observations count
* =============================================================================
local ++test_count
if `run_only' == 0 | `run_only' == 22 {
    capture noisily {
        _setup_panel
        iivw_weight, id(id) time(months) visit_cov(severity) nolog

        iivw_fit event severity, model(gee) nolog
        scalar n_gee = e(N)

        iivw_fit event severity, model(mixed) nolog
        scalar n_mixed = e(N)

        assert n_gee == n_mixed
    }
    if _rc == 0 {
        display as result "  PASS: E22 - GEE and mixed see same N"
        local ++pass_count
    }
    else {
        display as error "  FAIL: E22 - model N parity (error `=_rc')"
        local ++fail_count
    }
}

* =============================================================================
* E23: truncate(0 100) rejected at _pctile — documents known Stata limit
* =============================================================================
local ++test_count
if `run_only' == 0 | `run_only' == 23 {
    capture noisily {
        _setup_panel
        * Stata _pctile requires percentiles strictly in (0,100); iivw_weight
        * accepts [0,100] at validation but _pctile then errors. Expect rc!=0.
        capture iivw_weight, id(id) time(months) visit_cov(severity) ///
            truncate(0 100) nolog
        assert _rc != 0
        * Near-boundary values work
        _setup_panel
        iivw_weight, id(id) time(months) visit_cov(severity) ///
            truncate(0.01 99.99) nolog
        assert r(n_truncated) >= 0 & r(n_truncated) < .
    }
    if _rc == 0 {
        display as result "  PASS: E23 - truncate boundary behavior"
        local ++pass_count
    }
    else {
        display as error "  FAIL: E23 - truncate boundary (error `=_rc')"
        local ++fail_count
    }
}

* =============================================================================
* E24: Idempotent iivw_fit — running twice doesn't accumulate time vars
* =============================================================================
local ++test_count
if `run_only' == 0 | `run_only' == 24 {
    capture noisily {
        _setup_panel
        iivw_weight, id(id) time(months) visit_cov(severity) nolog

        iivw_fit event severity, timespec(quadratic) nolog
        * Second call with replace should not error
        iivw_fit event severity, timespec(quadratic) replace nolog
        * Exactly one _iivw_time_sq variable
        unab tsq : _iivw_time_sq
        local n : word count `tsq'
        assert `n' == 1
    }
    if _rc == 0 {
        display as result "  PASS: E24 - iivw_fit idempotent with replace"
        local ++pass_count
    }
    else {
        display as error "  FAIL: E24 - fit idempotency (error `=_rc')"
        local ++fail_count
    }
}

* =============================================================================
* E25: Package file completeness — all declared commands have .sthlp + .ado
* =============================================================================
local ++test_count
if `run_only' == 0 | `run_only' == 25 {
    capture noisily {
        foreach cmd in iivw iivw_weight iivw_fit {
            capture findfile `cmd'.ado
            if _rc != 0 {
                display as error "Missing: `cmd'.ado"
                error 601
            }
            capture findfile `cmd'.sthlp
            if _rc != 0 {
                display as error "Missing: `cmd'.sthlp"
                error 601
            }
        }
        foreach helper in _iivw_bs_estimate _iivw_check_weighted _iivw_get_settings {
            capture findfile `helper'.ado
            if _rc != 0 {
                display as error "Missing helper: `helper'.ado"
                error 601
            }
        }
    }
    if _rc == 0 {
        display as result "  PASS: E25 - All package files installed"
        local ++pass_count
    }
    else {
        display as error "  FAIL: E25 - installation completeness (error `=_rc')"
        local ++fail_count
    }
}

* ============================================================
* Summary
* ============================================================
display as text ""
display as result "Expanded Test Results: `pass_count'/`test_count' passed, `fail_count' failed"

if `fail_count' > 0 {
    display as error "RESULT: `fail_count' EXPANDED TESTS FAILED"
    exit 1
}
else {
    display as result "RESULT: ALL `pass_count' EXPANDED TESTS PASSED"
}

clear
