clear all
set more off
version 16.0
set varabbrev off

* crossval_iivw.do - Cross-validation of iivw against R IrregLong and FIPTIW
*
* Compares iivw_weight output to reference weights computed by:
*   1. IrregLong (Pullenayegum) - Phenobarb dataset, IIW weights
*   2. FIPTIW (Tompkins et al.) - Simulated data, FIPTIW weights
*
* Companion R scripts (run first to generate reference data):
*   Rscript iivw/qa/crossval_irreglong.R
*   Rscript iivw/qa/crossval_fiptiw.R
*
* Equivalences:
*   iivw_weight (IIW)   ≈ IrregLong::iiw.weights() (CRAN)
*   iivw_weight (FIPTIW) ≈ Tompkins et al. (2025) R implementation
*
* Usage:
*   do iivw/qa/crossval_iivw.do          Run all tests
*   do iivw/qa/crossval_iivw.do 3        Run only test 3

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

* --- Check reference data exists ---
capture confirm file "iivw/qa/phenobarb_prepared.csv"
if _rc != 0 {
    display as error "Reference data not found. Run R scripts first:"
    display as error "  Rscript iivw/qa/crossval_irreglong.R"
    display as error "  Rscript iivw/qa/crossval_fiptiw.R"
    exit 601
}

* ============================================================
* PART A: IrregLong / Phenobarb Cross-Validation
* ============================================================

* =============================================================================
* XV1: Cox model coefficients match IrregLong
* =============================================================================
*
* IrregLong fits Cox on counting-process data including censoring rows at
* maxfu=384. We load that same data and verify stcox matches coxph.
* =============================================================================
local ++test_count
if `run_only' == 0 | `run_only' == 1 {
    capture noisily {
        import delimited "iivw/qa/phenobarb_cox_data.csv", clear
        * CSV has "time.lag" which Stata imports as "timelag"
        capture rename timelag time_lag
        * If import already cleaned it:
        capture rename v3 time_lag
        * Rename subject to id
        rename subject id
        rename conclag conc_lag

        gen byte conc_low = (conc_lag > 0 & conc_lag <= 20)
        gen byte conc_mid = (conc_lag > 20 & conc_lag <= 30)
        gen byte conc_high = (conc_lag > 30)

        stset time, enter(time time_lag) failure(event) id(id) exit(time .)
        * Use efron to match R's coxph default (Stata defaults to Breslow)
        stcox conc_low conc_mid conc_high, nohr efron

        * Load R reference coefficients
        preserve
        import delimited "iivw/qa/phenobarb_cox_coefs.csv", clear
        local r_coef1 = estimate[1]
        local r_coef2 = estimate[2]
        local r_coef3 = estimate[3]
        restore

        local s_coef1 = _b[conc_low]
        local s_coef2 = _b[conc_mid]
        local s_coef3 = _b[conc_high]

        display as text "  R coefs:     " %9.6f `r_coef1' "  " %9.6f `r_coef2' "  " %9.6f `r_coef3'
        display as text "  Stata coefs: " %9.6f `s_coef1' "  " %9.6f `s_coef2' "  " %9.6f `s_coef3'

        * Tolerance: 0.001 for cross-implementation Cox coefficients
        assert abs(`s_coef1' - `r_coef1') < 0.001
        assert abs(`s_coef2' - `r_coef2') < 0.001
        assert abs(`s_coef3' - `r_coef3') < 0.001
    }
    if _rc == 0 {
        display as result "  PASS: XV1 - Cox coefficients match R coxph (Phenobarb)"
        local ++pass_count
    }
    else {
        display as error "  FAIL: XV1 - Cox coefficients (error `=_rc')"
        local ++fail_count
    }
}

* =============================================================================
* XV2: IIW weights match IrregLong exp(-xb) on observed data
* =============================================================================
*
* We fit stcox on IrregLong's Cox data (with censoring rows), predict xb on
* observed rows, compute exp(-xb), and compare to IrregLong's weights.
* =============================================================================
local ++test_count
if `run_only' == 0 | `run_only' == 2 {
    capture noisily {
        import delimited "iivw/qa/phenobarb_cox_data.csv", clear
        capture rename timelag time_lag
        rename subject id
        rename conclag conc_lag

        gen byte conc_low = (conc_lag > 0 & conc_lag <= 20)
        gen byte conc_mid = (conc_lag > 20 & conc_lag <= 30)
        gen byte conc_high = (conc_lag > 30)

        stset time, enter(time time_lag) failure(event) id(id) exit(time .)
        * Use efron to match R's coxph default
        stcox conc_low conc_mid conc_high, efron

        predict double xb_full, xb
        gen double stata_weight = exp(-xb_full)

        * Keep only observed rows (event==1)
        keep if event == 1
        sort id time

        * Load R reference weights
        preserve
        import delimited "iivw/qa/phenobarb_prepared.csv", clear
        sort id time
        keep id time iiw_weight
        tempfile r_weights
        save `r_weights'
        restore

        merge 1:1 id time using `r_weights', nogenerate

        gen double wdiff = abs(stata_weight - iiw_weight)
        quietly summarize wdiff, detail
        local max_diff = r(max)
        local mean_diff = r(mean)

        display as text "  Max weight difference:  " %12.8f `max_diff'
        display as text "  Mean weight difference: " %12.8f `mean_diff'

        * Tolerance: 0.01 for cross-implementation IIW weights
        assert `max_diff' < 0.01
    }
    if _rc == 0 {
        display as result "  PASS: XV2 - IIW weights match IrregLong (max diff < 0.01)"
        local ++pass_count
    }
    else {
        display as error "  FAIL: XV2 - IIW weight comparison (error `=_rc')"
        local ++fail_count
    }
}

* =============================================================================
* XV3: iivw_weight on Phenobarb produces valid IIW weights
* =============================================================================
*
* iivw_weight does NOT add censoring rows (unlike IrregLong), so the exact
* weights will differ. We verify: positive weights, first obs = 1, sane mean.
* =============================================================================
local ++test_count
if `run_only' == 0 | `run_only' == 3 {
    capture noisily {
        import delimited "iivw/qa/phenobarb_prepared.csv", clear
        sort id time

        gen byte conc_low = (conc_lag > 0 & conc_lag <= 20)
        gen byte conc_mid = (conc_lag > 20 & conc_lag <= 30)
        gen byte conc_high = (conc_lag > 30)

        * Drop subjects with only 1 visit (iivw requires >= 2)
        bysort id: gen int _nv = _N
        drop if _nv < 2
        drop _nv
        local N_kept = _N
        quietly bysort id: gen byte _f = (_n == 1)
        quietly count if _f == 1
        local n_ids_kept = r(N)
        drop _f

        iivw_weight, id(id) time(time) ///
            visit_cov(conc_low conc_mid conc_high) nolog

        assert r(N) == `N_kept'
        assert r(n_ids) == `n_ids_kept'
        quietly count if _iivw_weight <= 0 & !missing(_iivw_weight)
        assert r(N) == 0
        bysort id (time): assert _iivw_iw == 1 if _n == 1
        assert r(mean_weight) > 0
    }
    if _rc == 0 {
        display as result "  PASS: XV3 - iivw_weight on Phenobarb produces valid weights"
        local ++pass_count
    }
    else {
        display as error "  FAIL: XV3 - iivw_weight Phenobarb (error `=_rc')"
        local ++fail_count
    }
}

* =============================================================================
* XV4: iivw_weight Phenobarb weights correlated with IrregLong weights
* =============================================================================
*
* Despite different censoring row handling, the weights should be strongly
* correlated (both capture same visit intensity pattern).
* =============================================================================
local ++test_count
if `run_only' == 0 | `run_only' == 4 {
    capture noisily {
        import delimited "iivw/qa/phenobarb_prepared.csv", clear
        sort id time

        gen byte conc_low = (conc_lag > 0 & conc_lag <= 20)
        gen byte conc_mid = (conc_lag > 20 & conc_lag <= 30)
        gen byte conc_high = (conc_lag > 30)

        * R reference weights (first=TRUE version)
        rename iiw_weight_first1 r_weight

        * Drop subjects with only 1 visit
        bysort id: gen int _nv = _N
        drop if _nv < 2
        drop _nv

        iivw_weight, id(id) time(time) ///
            visit_cov(conc_low conc_mid conc_high) nolog

        correlate _iivw_weight r_weight
        local rho = r(rho)
        display as text "  Correlation(iivw, IrregLong): " %6.4f `rho'

        * Tolerance: correlation > 0.9 (both model same visit process)
        assert `rho' > 0.9
    }
    if _rc == 0 {
        display as result "  PASS: XV4 - iivw weights correlated with IrregLong (r > 0.9)"
        local ++pass_count
    }
    else {
        display as error "  FAIL: XV4 - weight correlation (error `=_rc')"
        local ++fail_count
    }
}

* ============================================================
* PART B: FIPTIW Simulation Cross-Validation (Tompkins et al. 2025)
* ============================================================

* =============================================================================
* Helper: load FIPTIW simulated data
* =============================================================================
capture program drop _load_fiptiw
program define _load_fiptiw
    version 16.0
    set varabbrev off
    import delimited "iivw/qa/fiptiw_simdata.csv", clear
    sort id time

    * Break any duplicate id-time pairs
    duplicates tag id time, gen(dup)
    quietly count if dup > 0
    if r(N) > 0 {
        bysort id (time): replace time = time + (_n - 1) * 0.00001 ///
            if dup > 0
    }
    drop dup
end

* =============================================================================
* XV5: Unstabilized IIW weights match R on simulated data
* =============================================================================
*
* Both R and Stata fit Cox on counting process ~ D + Wt + Z.
* iivw_weight computes exp(-xb) with first obs = 1; we compare to R's
* iiw_unstab_first1.
* =============================================================================
local ++test_count
if `run_only' == 0 | `run_only' == 5 {
    capture noisily {
        _load_fiptiw

        rename d treated
        rename wt wt_cov
        rename z z_cov
        rename iiw_unstab_first1 r_iiw_weight

        iivw_weight, id(id) time(time) ///
            visit_cov(treated wt_cov z_cov) nolog

        gen double iiw_diff = abs(_iivw_iw - r_iiw_weight)
        quietly summarize iiw_diff, detail
        local max_diff = r(max)
        local mean_diff = r(mean)
        local p99_diff = r(p99)

        display as text "  IIW weight differences vs R:"
        display as text "    Max:  " %12.8f `max_diff'
        display as text "    Mean: " %12.8f `mean_diff'
        display as text "    P99:  " %12.8f `p99_diff'

        * Tolerance: P99 < 0.05 (small diffs from counting-process construction)
        assert `p99_diff' < 0.05
    }
    if _rc == 0 {
        display as result "  PASS: XV5 - Unstabilized IIW matches R (P99 diff < 0.05)"
        local ++pass_count
    }
    else {
        display as error "  FAIL: XV5 - IIW comparison (error `=_rc')"
        local ++fail_count
    }
}

* =============================================================================
* XV6: IPTW weights match R on simulated data
* =============================================================================
*
* Both use stabilized IPTW: P(D)/P(D|W) for treated, (1-P(D))/(1-P(D|W)).
* Both R and iivw_weight fit logit on cross-sectional data (one row per
* subject), so coefficients should match to floating-point precision.
* =============================================================================
local ++test_count
if `run_only' == 0 | `run_only' == 6 {
    capture noisily {
        _load_fiptiw

        rename d treated
        rename wt wt_cov
        rename z z_cov
        rename iptw_weight r_iptw_weight

        iivw_weight, id(id) time(time) ///
            visit_cov(wt_cov z_cov) ///
            treat(treated) treat_cov(w) ///
            wtype(iptw) nolog

        gen double tw_diff = abs(_iivw_tw - r_iptw_weight)
        quietly summarize tw_diff, detail
        local max_diff = r(max)
        local mean_diff = r(mean)

        display as text "  IPTW weight differences vs R:"
        display as text "    Max:  " %12.8f `max_diff'
        display as text "    Mean: " %12.8f `mean_diff'

        * Tolerance: 0.001 (both fit logit on cross-sectional data)
        assert `max_diff' < 0.001
    }
    if _rc == 0 {
        display as result "  PASS: XV6 - IPTW weights match R (max diff < 0.001)"
        local ++pass_count
    }
    else {
        display as error "  FAIL: XV6 - IPTW comparison (error `=_rc')"
        local ++fail_count
    }
}

* =============================================================================
* XV7: Cox coefficients match R on FIPTIW simulated data
* =============================================================================
local ++test_count
if `run_only' == 0 | `run_only' == 7 {
    capture noisily {
        _load_fiptiw

        stset time, enter(time time_lag) failure(observed) id(id) exit(time .)
        stcox d wt z, nohr

        local s_d = _b[d]
        local s_wt = _b[wt]
        local s_z = _b[z]

        preserve
        import delimited "iivw/qa/fiptiw_coefs.csv", clear
        keep if model == "conditional_cox"
        local r_d = estimate[1]
        local r_wt = estimate[2]
        local r_z = estimate[3]
        restore

        display as text "  Conditional Cox (D + Wt + Z):"
        display as text "    R:     D=" %8.4f `r_d' "  Wt=" %8.4f `r_wt' "  Z=" %8.4f `r_z'
        display as text "    Stata: D=" %8.4f `s_d' "  Wt=" %8.4f `s_wt' "  Z=" %8.4f `s_z'

        * Tolerance: 0.01 for cross-implementation Cox coefficients
        assert abs(`s_d' - `r_d') < 0.01
        assert abs(`s_wt' - `r_wt') < 0.01
        assert abs(`s_z' - `r_z') < 0.01
    }
    if _rc == 0 {
        display as result "  PASS: XV7 - Cox coefficients match R coxph (FIPTIW sim)"
        local ++pass_count
    }
    else {
        display as error "  FAIL: XV7 - Cox coefs FIPTIW (error `=_rc')"
        local ++fail_count
    }
}

* =============================================================================
* XV8: FIPTIW product property holds and weights correlated with R
* =============================================================================
*
* The Tompkins R code uses STABILIZED IIW (marginal/conditional intensity
* ratio), while iivw_weight's default is UNSTABILIZED (exp(-xb)).
* To match R's stabilized approach, we use stabcov().
* We verify: (a) product property holds, (b) weights are reasonable.
* =============================================================================
local ++test_count
if `run_only' == 0 | `run_only' == 8 {
    capture noisily {
        _load_fiptiw

        rename d treated
        rename wt wt_cov
        rename z z_cov
        rename fiptiw_weight r_fiptiw

        * FIPTIW with stabilized IIW (matching Tompkins' approach)
        * Numerator model: treated only; Denominator: treated + wt_cov + z_cov
        iivw_weight, id(id) time(time) ///
            visit_cov(treated wt_cov z_cov) ///
            stabcov(treated) ///
            treat(treated) treat_cov(w) nolog

        * Verify product property: FIPTIW = IIW * IPTW
        gen double product_diff = abs(_iivw_weight - _iivw_iw * _iivw_tw)
        quietly summarize product_diff
        assert r(max) < 1e-10

        * Correlation with R's FIPTIW
        correlate _iivw_weight r_fiptiw
        local rho = r(rho)
        display as text "  FIPTIW product property: verified (max diff < 1e-10)"
        display as text "  Correlation(Stata FIPTIW, R FIPTIW): " %6.4f `rho'

        * Tolerance: correlation > 0.75 (same DGP, cross-sectional logit)
        assert `rho' > 0.75
    }
    if _rc == 0 {
        display as result "  PASS: XV8 - FIPTIW product holds, correlated with R (r > 0.75)"
        local ++pass_count
    }
    else {
        display as error "  FAIL: XV8 - FIPTIW comparison (error `=_rc')"
        local ++fail_count
    }
}

* =============================================================================
* XV9: Treatment effect recovery under FIPTIW (bias check)
* =============================================================================
*
* True beta1 = 0.5. FIPTIW-weighted estimate should be in a reasonable range.
* =============================================================================
local ++test_count
if `run_only' == 0 | `run_only' == 9 {
    capture noisily {
        _load_fiptiw

        rename d treated
        rename wt wt_cov
        rename z z_cov

        iivw_weight, id(id) time(time) ///
            visit_cov(wt_cov z_cov) ///
            treat(treated) treat_cov(w) nolog

        * Unweighted GEE
        quietly glm y treated time, vce(cluster id) nolog
        local b_unwt = _b[treated]

        * FIPTIW-weighted GEE
        iivw_fit y treated, timespec(linear) nolog
        local b_fiptiw = _b[treated]

        local bias_unwt = abs(`b_unwt' - 0.5)
        local bias_fiptiw = abs(`b_fiptiw' - 0.5)

        display as text "  True beta1 = 0.5"
        display as text "  Unweighted: " %8.4f `b_unwt' "  (bias = " %6.4f `bias_unwt' ")"
        display as text "  FIPTIW:     " %8.4f `b_fiptiw' "  (bias = " %6.4f `bias_fiptiw' ")"

        * Tolerance: within 1.0 of truth (single simulation, wide tolerance)
        assert abs(`b_fiptiw' - 0.5) < 1.0
    }
    if _rc == 0 {
        display as result "  PASS: XV9 - FIPTIW treatment effect near truth (beta1=0.5)"
        local ++pass_count
    }
    else {
        display as error "  FAIL: XV9 - treatment effect recovery (error `=_rc')"
        local ++fail_count
    }
}

* ============================================================
* Summary
* ============================================================
display as text ""
display as result "Cross-Validation: `pass_count'/`test_count' passed, `fail_count' failed"
display as text "  Part A (IrregLong/Phenobarb):  XV1-XV4"
display as text "  Part B (FIPTIW simulation):    XV5-XV9"

if `fail_count' > 0 {
    display as error "RESULT: `fail_count' CROSS-VALIDATION TESTS FAILED"
    exit 1
}
else {
    display as result "RESULT: ALL `pass_count' CROSS-VALIDATION TESTS PASSED"
}

clear
