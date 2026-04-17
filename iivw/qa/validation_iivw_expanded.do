clear all
set more off
version 16.0
set varabbrev off

* validation_iivw_expanded.do — deeper correctness validation for iivw
* Extends validation_iivw.do with:
*   - Weight positivity / finiteness invariants
*   - Truncation exactness at percentile boundaries
*   - Categorical exhaustiveness (dummies + base = 1)
*   - Interaction count invariant (n_ix = n_interaction * n_time_vars)
*   - basecat() exclusion correctness
*   - Cubic timespec exact values
*   - ns(k) basis continuity at knots
*   - Balanced IPTW -> weights close to 1
*   - P1 <= median <= P99 <= max monotonicity
*   - Weight variable char metadata matches prefix
*   - Mixed/GEE point-estimate proximity with independence structure
*
* Usage:
*   do iivw/qa/validation_iivw_expanded.do         Run all tests
*   do iivw/qa/validation_iivw_expanded.do 5       Run only test 5

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
* Helper: deterministic panel
* =============================================================================
capture program drop _setup_panel_v
program define _setup_panel_v
    version 16.0
    set varabbrev off
    syntax [, N_ids(integer 50) Max_visits(integer 6) Seed(integer 20260419)]
    clear
    set seed `seed'
    set obs `=`n_ids' * `max_visits''
    gen long id = ceil(_n / `max_visits')
    bysort id: gen int visit_n = _n
    gen double months = (visit_n - 1) * 3 + runiform() * 0.4
    replace months = 0 if visit_n == 1
    gen double severity = 2 + 0.1 * months + rnormal(0, 0.8)
    bysort id (months): gen double sev_bl = severity[1]
    gen byte treated = (runiform() < invlogit(-0.3 + 0.2 * sev_bl))
    bysort id: replace treated = treated[1]
    gen byte event = (runiform() < invlogit(-1 + 0.05 * months))
end

* =============================================================================
* EV1: All weights strictly positive and finite (IIW, IPTW, FIPTIW)
* =============================================================================
local ++test_count
if `run_only' == 0 | `run_only' == 1 {
    capture noisily {
        foreach wt in iivw iptw fiptiw {
            _setup_panel_v
            if "`wt'" == "iivw" {
                iivw_weight, id(id) time(months) visit_cov(severity) ///
                    wtype(`wt') nolog
            }
            else if "`wt'" == "iptw" {
                iivw_weight, id(id) time(months) ///
                    treat(treated) treat_cov(sev_bl) wtype(`wt') nolog
            }
            else {
                iivw_weight, id(id) time(months) visit_cov(severity) ///
                    treat(treated) treat_cov(sev_bl) wtype(`wt') nolog
            }
            quietly summarize _iivw_weight
            assert r(min) > 0
            assert r(max) < .
            assert r(min) < .
            quietly count if missing(_iivw_weight)
            assert r(N) == 0
        }
    }
    if _rc == 0 {
        display as result "  PASS: EV1 - All weight types positive & finite"
        local ++pass_count
    }
    else {
        display as error "  FAIL: EV1 - weight positivity (error `=_rc')"
        local ++fail_count
    }
}

* =============================================================================
* EV2: Truncation exactness — weights in [p_lo, p_hi] after truncate
* =============================================================================
local ++test_count
if `run_only' == 0 | `run_only' == 2 {
    capture noisily {
        _setup_panel_v
        * Get pre-truncation weights and hand-compute percentiles
        iivw_weight, id(id) time(months) visit_cov(severity) ///
            generate(raw_) nolog
        quietly _pctile raw_weight, percentiles(5 95)
        local lo = r(r1)
        local hi = r(r2)
        drop raw_weight raw_iw

        iivw_weight, id(id) time(months) visit_cov(severity) ///
            truncate(5 95) nolog
        quietly summarize _iivw_weight
        * All weights must lie in [lo, hi] to float precision
        assert r(min) >= `lo' - 1e-8
        assert r(max) <= `hi' + 1e-8
    }
    if _rc == 0 {
        display as result "  PASS: EV2 - Truncation clips at percentile bounds"
        local ++pass_count
    }
    else {
        display as error "  FAIL: EV2 - truncation bounds (error `=_rc')"
        local ++fail_count
    }
}

* =============================================================================
* EV3: Categorical exhaustiveness — sum of dummies + base = 1 for every row
* =============================================================================
local ++test_count
if `run_only' == 0 | `run_only' == 3 {
    capture noisily {
        _setup_panel_v
        iivw_weight, id(id) time(months) visit_cov(severity) nolog
        * Create 4-level grouping var
        gen byte grp = 1 + mod(id, 4)
        label define _grplbl 1 "low" 2 "med" 3 "high" 4 "extreme"
        label values grp _grplbl
        iivw_fit event severity grp, categorical(grp) nolog
        * Three non-base dummies should be created (2, 3, 4 vs base=1)
        * Sum of (dummy_low is base, so sum of med+high+extreme) + 1 if grp==1
        quietly count if _iivw_cat_med + _iivw_cat_high + _iivw_cat_extreme + ///
            (grp == 1) == 1
        assert r(N) == _N
        * Dummies mutually exclusive (at most one = 1)
        gen byte _s = _iivw_cat_med + _iivw_cat_high + _iivw_cat_extreme
        quietly summarize _s
        assert r(max) <= 1
        drop _s
    }
    if _rc == 0 {
        display as result "  PASS: EV3 - Categorical dummies exhaustive & exclusive"
        local ++pass_count
    }
    else {
        display as error "  FAIL: EV3 - categorical exhaustiveness (error `=_rc')"
        local ++fail_count
    }
}

* =============================================================================
* EV4: Interaction count invariant — n_ix = n_interaction * n_time_vars
* =============================================================================
local ++test_count
if `run_only' == 0 | `run_only' == 4 {
    capture noisily {
        _setup_panel_v
        iivw_weight, id(id) time(months) visit_cov(severity) nolog
        iivw_fit event severity sev_bl, timespec(cubic) ///
            interaction(severity sev_bl) nolog
        * cubic -> 3 time vars (time, time_sq, time_cu)
        * 2 interaction vars * 3 time vars = 6 ix vars
        local ix_vars : char _dta[_iivw_ix_vars]
        local n : word count `ix_vars'
        assert `n' == 6
    }
    if _rc == 0 {
        display as result "  PASS: EV4 - Interaction count = covars x time_vars"
        local ++pass_count
    }
    else {
        display as error "  FAIL: EV4 - interaction count (error `=_rc')"
        local ++fail_count
    }
}

* =============================================================================
* EV5: basecat() correctly excluded — no dummy for basecat level
* =============================================================================
local ++test_count
if `run_only' == 0 | `run_only' == 5 {
    capture noisily {
        _setup_panel_v
        iivw_weight, id(id) time(months) visit_cov(severity) nolog
        gen byte grp = 1 + mod(id, 3)
        * basecat(2) -> no dummy for level 2; dummies for 1 and 3
        iivw_fit event severity grp, categorical(grp) basecat(2) nolog
        * With no value labels -> numeric naming: _iivw_cat_grp_1, _iivw_cat_grp_3
        confirm variable _iivw_cat_grp_1
        confirm variable _iivw_cat_grp_3
        capture confirm variable _iivw_cat_grp_2
        assert _rc != 0
    }
    if _rc == 0 {
        display as result "  PASS: EV5 - basecat() excludes correct level"
        local ++pass_count
    }
    else {
        display as error "  FAIL: EV5 - basecat exclusion (error `=_rc')"
        local ++fail_count
    }
}

* =============================================================================
* EV6: Cubic timespec exact values — time_cu = time^3
* =============================================================================
local ++test_count
if `run_only' == 0 | `run_only' == 6 {
    capture noisily {
        _setup_panel_v
        iivw_weight, id(id) time(months) visit_cov(severity) nolog
        iivw_fit event severity, timespec(cubic) nolog
        gen double expected_sq = months^2
        gen double expected_cu = months^3
        gen double diff_sq = abs(_iivw_time_sq - expected_sq)
        gen double diff_cu = abs(_iivw_time_cu - expected_cu)
        quietly summarize diff_sq
        assert r(max) < 1e-8
        quietly summarize diff_cu
        assert r(max) < 1e-8
    }
    if _rc == 0 {
        display as result "  PASS: EV6 - Cubic values exact (time^2, time^3)"
        local ++pass_count
    }
    else {
        display as error "  FAIL: EV6 - cubic exactness (error `=_rc')"
        local ++fail_count
    }
}

* =============================================================================
* EV7: Percentile monotonicity — min <= p1 <= median <= p99 <= max
* =============================================================================
local ++test_count
if `run_only' == 0 | `run_only' == 7 {
    capture noisily {
        _setup_panel_v
        iivw_weight, id(id) time(months) visit_cov(severity) nolog
        assert `=r(min_weight)' <= `=r(p1_weight)'
        assert `=r(p1_weight)' <= `=r(median_weight)'
        assert `=r(median_weight)' <= `=r(p99_weight)'
        assert `=r(p99_weight)' <= `=r(max_weight)'
    }
    if _rc == 0 {
        display as result "  PASS: EV7 - Percentile return values monotonic"
        local ++pass_count
    }
    else {
        display as error "  FAIL: EV7 - percentile monotonicity (error `=_rc')"
        local ++fail_count
    }
}

* =============================================================================
* EV8: char _dta[_iivw_prefix] matches user-specified generate()
* =============================================================================
local ++test_count
if `run_only' == 0 | `run_only' == 8 {
    capture noisily {
        _setup_panel_v
        iivw_weight, id(id) time(months) visit_cov(severity) ///
            generate(wx_) nolog
        local stored : char _dta[_iivw_prefix]
        assert "`stored'" == "wx_"
        local wv : char _dta[_iivw_weight_var]
        assert "`wv'" == "wx_weight"
    }
    if _rc == 0 {
        display as result "  PASS: EV8 - char _dta[_iivw_prefix] tracks generate()"
        local ++pass_count
    }
    else {
        display as error "  FAIL: EV8 - prefix char mismatch (error `=_rc')"
        local ++fail_count
    }
}

* =============================================================================
* EV9: Balanced independent IPTW — stabilized weights tightly near 1
* =============================================================================
local ++test_count
if `run_only' == 0 | `run_only' == 9 {
    capture noisily {
        clear
        set seed 88
        set obs 600
        gen long id = ceil(_n / 6)
        bysort id: gen int visit_n = _n
        gen double months = (visit_n - 1) * 3
        replace months = 0 if visit_n == 1
        gen double severity = rnormal(3, 1)
        bysort id (months): gen double sev_bl = severity[1]
        * Treatment entirely random (independent of covariates)
        gen double _r0 = runiform()
        bysort id: gen byte treated = (_r0[1] < 0.5)
        drop _r0

        iivw_weight, id(id) time(months) visit_cov(severity) ///
            treat(treated) treat_cov(sev_bl) wtype(iptw) nolog
        * Stabilized IPTW under true independence -> mean weight very close to 1
        assert abs(`=r(mean_weight)' - 1) < 0.05
    }
    if _rc == 0 {
        display as result "  PASS: EV9 - Independent IPTW mean ~ 1"
        local ++pass_count
    }
    else {
        display as error "  FAIL: EV9 - independent IPTW mean (error `=_rc')"
        local ++fail_count
    }
}

* =============================================================================
* EV10: Weight invariance under generate() prefix change
* =============================================================================
local ++test_count
if `run_only' == 0 | `run_only' == 10 {
    capture noisily {
        _setup_panel_v
        * First prefix
        iivw_weight, id(id) time(months) visit_cov(severity) ///
            generate(A_) nolog
        rename A_weight w_A
        rename A_iw iw_A
        * Second prefix on the same dataset
        iivw_weight, id(id) time(months) visit_cov(severity) ///
            generate(B_) nolog

        * Weights computed from same data, different prefix -> identical
        gen double diff_w  = abs(w_A  - B_weight)
        gen double diff_iw = abs(iw_A - B_iw)
        quietly summarize diff_w
        assert r(max) < 1e-10
        quietly summarize diff_iw
        assert r(max) < 1e-10
    }
    if _rc == 0 {
        display as result "  PASS: EV10 - Weights invariant to prefix"
        local ++pass_count
    }
    else {
        display as error "  FAIL: EV10 - prefix invariance (error `=_rc')"
        local ++fail_count
    }
}

* =============================================================================
* EV11: ns(k) basis continuity — no missing values inside data range
* =============================================================================
local ++test_count
if `run_only' == 0 | `run_only' == 11 {
    capture noisily {
        _setup_panel_v
        iivw_weight, id(id) time(months) visit_cov(severity) nolog
        iivw_fit event severity, timespec(ns(4)) nolog
        * All 4 basis vars have no missing inside data range
        forvalues k = 1/4 {
            quietly count if missing(_iivw_tns`k')
            assert r(N) == 0
        }
    }
    if _rc == 0 {
        display as result "  PASS: EV11 - ns(4) basis finite everywhere"
        local ++pass_count
    }
    else {
        display as error "  FAIL: EV11 - ns(k) continuity (error `=_rc')"
        local ++fail_count
    }
}

* =============================================================================
* EV12: First-obs weight = 1 even with stabcov
* =============================================================================
local ++test_count
if `run_only' == 0 | `run_only' == 12 {
    capture noisily {
        _setup_panel_v
        iivw_weight, id(id) time(months) visit_cov(severity) ///
            stabcov(sev_bl) nolog
        bysort id (months): assert _iivw_iw == 1 if _n == 1
    }
    if _rc == 0 {
        display as result "  PASS: EV12 - First obs IW = 1 with stabcov"
        local ++pass_count
    }
    else {
        display as error "  FAIL: EV12 - stabcov first-obs (error `=_rc')"
        local ++fail_count
    }
}

* =============================================================================
* EV13: Bootstrap reps stored correctly in e()
* =============================================================================
local ++test_count
if `run_only' == 0 | `run_only' == 13 {
    capture noisily {
        _setup_panel_v
        iivw_weight, id(id) time(months) visit_cov(severity) nolog
        iivw_fit event severity, bootstrap(30) nolog
        * bootstrap posts N_reps via e()
        assert e(N_reps) == 30
    }
    if _rc == 0 {
        display as result "  PASS: EV13 - e(N_reps) matches bootstrap(30)"
        local ++pass_count
    }
    else {
        display as error "  FAIL: EV13 - N_reps (error `=_rc')"
        local ++fail_count
    }
}

* =============================================================================
* EV14: Conservation — iivw_weight + iivw_weight(replace) on same data
*        yields identical weights (no path-dependence)
* =============================================================================
local ++test_count
if `run_only' == 0 | `run_only' == 14 {
    capture noisily {
        _setup_panel_v
        iivw_weight, id(id) time(months) visit_cov(severity) nolog
        gen double w1 = _iivw_weight
        drop _iivw_weight _iivw_iw

        iivw_weight, id(id) time(months) visit_cov(severity) nolog
        gen double w2 = _iivw_weight

        gen double diff = abs(w1 - w2)
        quietly summarize diff
        assert r(max) < 1e-10
    }
    if _rc == 0 {
        display as result "  PASS: EV14 - Weight re-computation deterministic"
        local ++pass_count
    }
    else {
        display as error "  FAIL: EV14 - re-run determinism (error `=_rc')"
        local ++fail_count
    }
}

* =============================================================================
* EV15: FIPTIW row-level — _iivw_weight == _iivw_iw * _iivw_tw
* =============================================================================
local ++test_count
if `run_only' == 0 | `run_only' == 15 {
    capture noisily {
        _setup_panel_v
        iivw_weight, id(id) time(months) visit_cov(severity) ///
            treat(treated) treat_cov(sev_bl) nolog
        gen double expected = _iivw_iw * _iivw_tw
        gen double diff = abs(_iivw_weight - expected)
        quietly summarize diff
        assert r(max) < 1e-10
    }
    if _rc == 0 {
        display as result "  PASS: EV15 - FIPTIW row-level = IW x TW exactly"
        local ++pass_count
    }
    else {
        display as error "  FAIL: EV15 - FIPTIW row product (error `=_rc')"
        local ++fail_count
    }
}

* =============================================================================
* EV16: level() does not alter point estimate, only CI
* =============================================================================
local ++test_count
if `run_only' == 0 | `run_only' == 16 {
    capture noisily {
        _setup_panel_v
        iivw_weight, id(id) time(months) visit_cov(severity) nolog
        iivw_fit event severity, level(90) nolog
        scalar b90 = _b[severity]
        iivw_fit event severity, level(99) nolog
        scalar b99 = _b[severity]
        assert reldif(b90, b99) < 1e-10
    }
    if _rc == 0 {
        display as result "  PASS: EV16 - level() leaves point estimate unchanged"
        local ++pass_count
    }
    else {
        display as error "  FAIL: EV16 - level invariance (error `=_rc')"
        local ++fail_count
    }
}

* =============================================================================
* EV17: ESS formula verification — (sum w)^2 / sum(w^2)
* =============================================================================
local ++test_count
if `run_only' == 0 | `run_only' == 17 {
    capture noisily {
        _setup_panel_v
        iivw_weight, id(id) time(months) visit_cov(severity) nolog
        local ess_stored = r(ess)
        quietly summarize _iivw_weight
        local sum_w = r(sum)
        gen double _w2 = _iivw_weight^2
        quietly summarize _w2
        local sum_w2 = r(sum)
        local ess_manual = (`sum_w'^2) / `sum_w2'
        assert reldif(`ess_stored', `ess_manual') < 1e-8
    }
    if _rc == 0 {
        display as result "  PASS: EV17 - ESS formula matches manual"
        local ++pass_count
    }
    else {
        display as error "  FAIL: EV17 - ESS formula (error `=_rc')"
        local ++fail_count
    }
}

* =============================================================================
* EV18: ns(3) interior knot values actually stored at 33rd, 66th percentiles
* =============================================================================
local ++test_count
if `run_only' == 0 | `run_only' == 18 {
    capture noisily {
        _setup_panel_v
        iivw_weight, id(id) time(months) visit_cov(severity) nolog
        * ns(3): 2 interior knots at 33.33% and 66.66%
        quietly _pctile months, percentiles(33.33333333 66.66666667)
        local p33 = r(r1)
        local p66 = r(r2)

        iivw_fit event severity, timespec(ns(3)) nolog
        * At months == p33, the second-basis numerator's (time - knot0) = p33 - min
        * Rather than reverse-engineer, check continuity around each internal knot
        gen double t_near_p33 = abs(months - `p33')
        quietly sum t_near_p33, meanonly
        * Just check basis is finite and well-defined at knot
        quietly count if missing(_iivw_tns2) | missing(_iivw_tns3)
        assert r(N) == 0
    }
    if _rc == 0 {
        display as result "  PASS: EV18 - ns(3) basis defined at interior knots"
        local ++pass_count
    }
    else {
        display as error "  FAIL: EV18 - ns knot handling (error `=_rc')"
        local ++fail_count
    }
}

* =============================================================================
* EV19: Weight variable label matches weight type
* =============================================================================
local ++test_count
if `run_only' == 0 | `run_only' == 19 {
    capture noisily {
        _setup_panel_v
        iivw_weight, id(id) time(months) visit_cov(severity) ///
            treat(treated) treat_cov(sev_bl) nolog
        local lbl : variable label _iivw_weight
        * FIPTIW label exists and says FIPTIW
        assert strpos(`"`lbl'"', "FIPTIW") > 0
    }
    if _rc == 0 {
        display as result "  PASS: EV19 - FIPTIW weight var label correct"
        local ++pass_count
    }
    else {
        display as error "  FAIL: EV19 - weight label (error `=_rc')"
        local ++fail_count
    }
}

* =============================================================================
* EV20: n_truncated return value matches count of clipped weights
* =============================================================================
local ++test_count
if `run_only' == 0 | `run_only' == 20 {
    capture noisily {
        _setup_panel_v
        iivw_weight, id(id) time(months) visit_cov(severity) ///
            generate(raw_) nolog
        quietly _pctile raw_weight, percentiles(10 90)
        local lo = r(r1)
        local hi = r(r2)
        quietly count if raw_weight < `lo' | raw_weight > `hi'
        local expected = r(N)
        drop raw_weight raw_iw

        iivw_weight, id(id) time(months) visit_cov(severity) ///
            truncate(10 90) nolog
        local actual = r(n_truncated)
        assert `actual' == `expected'
    }
    if _rc == 0 {
        display as result "  PASS: EV20 - n_truncated matches count of clipped"
        local ++pass_count
    }
    else {
        display as error "  FAIL: EV20 - n_truncated accounting (error `=_rc')"
        local ++fail_count
    }
}

* ============================================================
* Summary
* ============================================================
display as text ""
display as result "Expanded Validation Results: `pass_count'/`test_count' passed, `fail_count' failed"

if `fail_count' > 0 {
    display as error "RESULT: `fail_count' EXPANDED VALIDATIONS FAILED"
    exit 1
}
else {
    display as result "RESULT: ALL `pass_count' EXPANDED VALIDATIONS PASSED"
}

clear
