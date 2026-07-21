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
* Q5: a bad selector must be an error, not a silent zero-test pass.
* `do this.do 999' used to execute nothing and print "ALL TESTS PASSED".
do "`c(pwd)'/_iivw_qa_common.do"
iivw_qa_selector "`run_only'"
local run_only = `r(run_only)'

* ============================================================
* Setup
* ============================================================


* === Bootstrap ===
local here "`c(pwd)'"
local basename = substr("`here'", strrpos("`here'", "/") + 1, .)
if "`basename'" == "qa" {
    local qa_dir "`here'"
}
else {
    capture confirm file "`here'/phenobarb_prepared.csv"
    if _rc == 0 {
        local qa_dir "`here'"
    }
    else {
        capture confirm file "`here'/qa/phenobarb_prepared.csv"
        if _rc == 0 {
            local qa_dir "`here'/qa"
        }
        else {
            capture confirm file "`here'/iivw/qa/phenobarb_prepared.csv"
            if _rc == 0 {
                local qa_dir "`here'/iivw/qa"
            }
            else {
                local qa_dir "`here'"
            }
        }
    }
}
local pkg_dir "`qa_dir'/.."
global IIVW_QA_DIR "`qa_dir'"

capture ado uninstall iivw
quietly net install iivw, from("`pkg_dir'") replace

local test_count = 0
local pass_count = 0
local fail_count = 0

* --- Check reference data exists ---
foreach ref in ///
    phenobarb_prepared.csv ///
    phenobarb_cox_coefs.csv ///
    phenobarb_cox_data.csv ///
    phenobarb_parity_entry_coefs.csv ///
    phenobarb_parity_entry_weights.csv ///
    fiptiw_simdata.csv ///
    fiptiw_coefs.csv ///
    fiptiw_outcome_geeglm.csv {
    capture confirm file "`qa_dir'/`ref'"
    if _rc != 0 {
        display as error "Reference data not found. Run R scripts first:"
        display as error "  Rscript `qa_dir'/crossval_irreglong.R"
        display as error "  Rscript `qa_dir'/crossval_fiptiw.R"
        display as error "missing: `ref'"
        exit 601
    }
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
        import delimited "`qa_dir'/phenobarb_cox_data.csv", clear
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
        stcox conc_low conc_mid conc_high, nohr efron vce(cluster id)

        * Load R reference coefficients
        preserve
        import delimited "`qa_dir'/phenobarb_cox_coefs.csv", clear
        local r_coef1 = estimate[1]
        local r_coef2 = estimate[2]
        local r_coef3 = estimate[3]
        local r_se1 = se[1]
        local r_se2 = se[2]
        local r_se3 = se[3]
        restore

        local s_coef1 = _b[conc_low]
        local s_coef2 = _b[conc_mid]
        local s_coef3 = _b[conc_high]
        local s_se1 = _se[conc_low]
        local s_se2 = _se[conc_mid]
        local s_se3 = _se[conc_high]

        display as text "  R coefs:     " %9.6f `r_coef1' "  " %9.6f `r_coef2' "  " %9.6f `r_coef3'
        display as text "  Stata coefs: " %9.6f `s_coef1' "  " %9.6f `s_coef2' "  " %9.6f `s_coef3'
        display as text "  R robust SEs:     " %9.6f `r_se1' "  " %9.6f `r_se2' "  " %9.6f `r_se3'
        display as text "  Stata robust SEs: " %9.6f `s_se1' "  " %9.6f `s_se2' "  " %9.6f `s_se3'

        * Tolerance: 0.001 for cross-implementation Cox coefficients
        assert abs(`s_coef1' - `r_coef1') < 0.001
        assert abs(`s_coef2' - `r_coef2') < 0.001
        assert abs(`s_coef3' - `r_coef3') < 0.001
        assert abs(`s_se1' - `r_se1') / `r_se1' < 0.05
        assert abs(`s_se2' - `r_se2') / `r_se2' < 0.05
        assert abs(`s_se3' - `r_se3') / `r_se3' < 0.05
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
        import delimited "`qa_dir'/phenobarb_cox_data.csv", clear
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
        import delimited "`qa_dir'/phenobarb_prepared.csv", clear
        sort id time
        keep id time iiw_weight
        tempfile r_weights
        save `r_weights'
        restore

        merge 1:1 id time using `r_weights', nogenerate

        * Compare IIW weights up to scale: the package normalizes _iivw_iw to
        * mean 1, so normalize both series to mean 1 before differencing.
        foreach wv in stata_weight iiw_weight {
            quietly summarize `wv' if !missing(`wv'), meanonly
            quietly replace `wv' = `wv' / r(mean)
        }
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
* Structural checks on the legacy (endatlastvisit) risk set. Exact parity with
* IrregLong is asserted separately, in XV4b.
* =============================================================================
local ++test_count
if `run_only' == 0 | `run_only' == 3 {
    capture noisily {
        import delimited "`qa_dir'/phenobarb_prepared.csv", clear
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

        iivw_weight, endatlastvisit baseline(event) id(id) time(time) ///
            visit_cov(conc_low conc_mid conc_high) nolog

        assert r(N) == `N_kept'
        assert r(n_ids) == `n_ids_kept'
        quietly count if _iivw_weight <= 0 & !missing(_iivw_weight)
        assert r(N) == 0
        * First-obs IIW weights identical across subjects (mean-1 normalized)
        tempvar _xv3first
        bysort id (time): gen byte `_xv3first' = (_n == 1)
        quietly summarize _iivw_iw if `_xv3first'
        assert r(sd) < 1e-9
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
        import delimited "`qa_dir'/phenobarb_prepared.csv", clear
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

        iivw_weight, endatlastvisit baseline(event) id(id) time(time) ///
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
    import delimited "${IIVW_QA_DIR}/fiptiw_simdata.csv", clear
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
* XV4b: EXACT parity with IrregLong on the Phenobarb visit-intensity model
* =============================================================================
*
* This is the test the lane was missing, and its absence is why the censoring
* defect survived so long: XV3 and XV4 settled for "positive, sane, correlated"
* precisely BECAUSE iivw built a different risk set than IrregLong, and a
* correlation of 0.997 hid a 26% attenuation of the coefficient.
*
* Both sides now build the identical Cox data:
*   - one interval per visit, plus a (last visit, 384] interval with no event
*   - conc lagged by one visit, rebuilt AFTER the censoring row is appended, so
*     that row carries conc at the last visit (never conc from the visit before
*     it -- which is what a pre-computed lag would give, and is exactly the trap
*     the binned XV3/XV4 model falls into)
*   - the first visit as study entry rather than a modeled event, which is also
*     what makes the two implementations' differing first-row lag conventions
*     (IrregLong: lagfirst=0; iivw: missing) irrelevant
*   - Efron ties, which is coxph's default and stcox's efron option
*
* With the risk set right, the coefficients must MATCH, not correlate.
* =============================================================================
local ++test_count
if `run_only' == 0 | `run_only' == 45 {
    capture noisily {
        import delimited "`qa_dir'/phenobarb_prepared.csv", clear
        keep id time conc
        sort id time

        iivw_weight, id(id) time(time) lagvars(conc) maxfu(384) efron nolog
        matrix b = r(visit_b)
        scalar st_b = b[1, 1]
        local st_n = r(visit_N)
        local st_c = r(n_censor_rows)

        preserve
        import delimited "`qa_dir'/phenobarb_parity_entry_coefs.csv", ///
            clear varnames(1)
        scalar r_b = estimate[1]
        scalar r_n = n[1]
        restore

        display as text "  IrregLong coxph : " %20.16f r_b "   (`=r_n' intervals)"
        display as text "  iivw_weight     : " %20.16f st_b "   (`st_n' intervals, `st_c' censoring rows)"
        display as text "  abs difference  : " %12.3e abs(st_b - r_b)

        * Identical risk set, to the interval.
        assert `st_n' == r_n

        * Identical coefficient, to convergence tolerance. A measured run gave
        * 3.4e-10. Anything at 1e-3 or worse means the two are fitting different
        * data again, and the tolerance must not be widened to accommodate it.
        assert abs(st_b - r_b) < 1e-7
    }
    if _rc == 0 {
        display as result "  PASS: XV4b - iivw_weight EXACTLY matches IrregLong (coefficient, not correlation)"
        local ++pass_count
    }
    else {
        display as error "  FAIL: XV4b - IrregLong exact parity (error `=_rc')"
        local ++fail_count
    }
}

* =============================================================================
* XV4c: EXACT parity with IrregLong on the WEIGHTS, not just the coefficient
* =============================================================================
*
* XV4b proves the two implementations fit the same Cox model. It does not prove
* they turn that model into the same weight -- the exponent sign, the centering
* convention and the first-visit rule all sit downstream of the coefficient and
* a bug in any of them leaves the coefficient exactly right. The lane needs both
* halves, and the audit asked for both by name.
*
* The oracle is exp(-xb) from IrregLong's own parity model, evaluated at each
* observed visit with reference="zero" (uncentered, matching stcox's `predict,
* xb'). Every non-first visit must match to the digit -- no correlation, no
* tolerance wide enough to hide a uniform rescaling, which is precisely how the
* centered-vs-uncentered class of error escapes a correlation check.
* =============================================================================
local ++test_count
if `run_only' == 0 | `run_only' == 46 {
    capture noisily {
        * asdouble on BOTH imports, and it is load-bearing. import delimited
        * defaults to FLOAT, which carries ~7 significant digits: the R oracle is
        * written with 15, so reading it as float injects a ~1e-7 relative error
        * into the comparison and the parity check cannot see anything finer than
        * that. A measured run went from a 1.4e-07 spread to 4e-15 on this one
        * word. Any "exact parity" test that omits it is checking float noise.
        import delimited "`qa_dir'/phenobarb_prepared.csv", clear asdouble
        keep id time conc
        sort id time

        iivw_weight, id(id) time(time) lagvars(conc) maxfu(384) efron nolog

        preserve
        import delimited "`qa_dir'/phenobarb_parity_entry_weights.csv", ///
            clear varnames(1) asdouble
        tempfile rw
        quietly save "`rw'"
        local r_rows = _N
        restore

        * Merge on the visit key. IrregLong's parity frame drops each subject's
        * first visit (it is study entry, not a modeled event) and its censoring
        * rows, so it carries exactly the visits that have an IIW weight.
        merge 1:1 id time using "`rw'", keep(master match) generate(_mrg)

        * Every R weight row must find its Stata visit. A _merge==2 would mean
        * the two sides disagree about which rows are visits at all.
        quietly count if _mrg == 3
        local n_match = r(N)
        assert `n_match' == `r_rows'

        * The unmatched master rows must be exactly the first visits -- nothing
        * else. If iivw were silently dropping or adding visits, the arithmetic
        * would land here rather than in a weight comparison.
        bysort id (time): gen byte _isfirst = (_n == 1)
        quietly count if _mrg == 1 & !_isfirst
        assert r(N) == 0

        * The two sides are on different scales BY DESIGN: iivw normalizes
        * _iivw_iw to mean 1 (see "Mean-1 normalization" in iivw_weight.sthlp),
        * while R's oracle is the raw exp(-xb). So the comparison has two parts,
        * and doing only the second would be worthless.
        *
        * (a) SHAPE. The ratio w_iivw / w_R must be the SAME CONSTANT on every
        *     row. This is the assertion that actually has teeth: it catches a
        *     per-row misalignment, a permuted weight column, a wrong sign in the
        *     exponent, and a centering error -- none of which survive a constant
        *     ratio, and all of which survive the rescale in (b).
        gen double ratio = _iivw_iw / r_w if _mrg == 3
        quietly summarize ratio, meanonly
        local rmin = r(min)
        local rmax = r(max)
        local rmean = r(mean)
        local spread = (`rmax' - `rmin') / `rmean'
        display as text "  matched visits    : `n_match'"
        display as text "  w_iivw / w_R      : " %20.16f `rmean'
        display as text "  relative spread   : " %12.3e `spread'
        * A measured run gives ~4e-15, i.e. floating-point noise. 1e-9 is orders
        * of magnitude looser and still far tighter than any real defect.
        assert `spread' < 1e-9

        * (b) SCALE. The constant must be exactly the documented normalizer, and
        *     that normalizer is derivable from the oracle -- so derive it rather
        *     than rescale both sides and call whatever is left a match.
        *
        *     iivw rescales the raw weights to mean 1 over the MODELLED EVENTS.
        *     Those rows are exactly the matched visits: the first visit per
        *     subject is study entry, not a modelled event, so it is excluded
        *     from the Cox fit AND from this mean, and takes weight 1 afterwards.
        *     So
        *
        *         mean_raw = sum(w_R) / n_match
        *         ratio    = 1 / mean_raw
        *
        *     This ties (b) to the normalization scope documented under
        *     "Mean-1 normalization" in iivw_weight.sthlp. If the normalization
        *     set ever changes, this fires -- which a bare "rescale both to mean
        *     1" check could never do, because that divides out the very
        *     quantity under test.
        *
        *     Before the SOL-01 fix the normalizer ran over the matched visits
        *     PLUS the first visits at a hard-coded raw 1, i.e.
        *     (n_first + sum(w_R)) / (n_first + n_match). That pooled mean is
        *     what made the weights depend on the origin of a Cox covariate:
        *     shifting one scales sum(w_R) but not the 1s, so the ratio moved.
        *     IrregLong's own first1 convention has the same property, which is
        *     why parity here is asserted on the modelled component and the
        *     entry rows are checked separately below.
        quietly count if _mrg == 1
        local n_first = r(N)
        quietly summarize r_w if _mrg == 3, meanonly
        local sum_rw = r(sum)
        local mean_raw = `sum_rw' / `n_match'
        local expected = 1 / `mean_raw'
        display as text "  first visits      : `n_first'"
        display as text "  predicted ratio   : " %20.16f `expected'
        assert abs(`rmean' - `expected') / `expected' < 1e-9

        * (c) ENTRY ROWS. Under the current convention the study-entry visits
        *     carry weight exactly 1 -- not 1/mean_raw. That is an assertion the
        *     old pooled normalization could not make at all, and it is what
        *     makes the whole vector invariant to a covariate shift.
        quietly summarize _iivw_iw if _mrg == 1
        assert r(N) == `n_first'
        assert abs(r(min) - 1) < 1e-12
        assert abs(r(max) - 1) < 1e-12

        * Guard the guard. If the merge had matched nothing, `ratio' would be all
        * missing, summarize would return r(N)==0, and `spread' would be missing
        * -- which is NOT < 1e-9, so the assert would fire. But make the count
        * explicit anyway: a verdict computed over zero comparisons is the single
        * most common way a parity test passes while proving nothing.
        quietly count if !missing(ratio)
        assert r(N) == `r_rows'
    }
    if _rc == 0 {
        display as result "  PASS: XV4c - iivw IIW weights EXACTLY match IrregLong exp(-xb)"
        local ++pass_count
    }
    else {
        display as error "  FAIL: XV4c - IrregLong exact weight parity (error `=_rc')"
        local ++fail_count
    }
}

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
        * The oracle is iiw_unstab -- R's raw exp(-xb) on EVERY row -- not
        * iiw_unstab_first1, which overrides the first observation to 1.
        *
        * baseline(event) declares every visit including the first to be a
        * modelled monitoring event, so every row carries its own fitted
        * rate-ratio weight and the whole vector is normalized together. The
        * matching oracle is therefore the unmodified exp(-xb).
        *
        * Comparing against first1 here would be comparing against a different
        * estimand: it hard-codes the first row to 1 while the rest are fitted,
        * which is precisely the mixed-scale construction that made the weights
        * depend on the origin of a Cox covariate (SOL-01). iivw's own
        * baseline(entry) mode is the one that matches a first1-style
        * convention, and XV4c is where that comparison is made.
        rename iiw_unstab r_iiw_weight

        iivw_weight, endatlastvisit baseline(event) id(id) time(time) ///
            visit_cov(treated wt_cov z_cov) nolog

        * Both sides carry an arbitrary common scale (the Cox model has no
        * intercept), so normalize each to mean 1 before differencing. The
        * shape comparison below is what has teeth; the rescale only removes
        * the scale that neither implementation pins down.
        quietly summarize r_iiw_weight if !missing(r_iiw_weight), meanonly
        quietly replace r_iiw_weight = r_iiw_weight / r(mean)
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

        preserve
        bysort id (time): keep if _n == 1
        logit treated w, nolog
        local s_ps_cons = _b[_cons]
        local s_ps_w = _b[w]
        quietly summarize treated
        local s_prD = r(mean)
        restore

        preserve
        import delimited "`qa_dir'/fiptiw_coefs.csv", clear
        local r_ps_cons = estimate[5]
        local r_ps_w = estimate[6]
        local r_prD = estimate[7]
        restore

        assert abs(`s_ps_cons' - `r_ps_cons') < 1e-7
        assert abs(`s_ps_w' - `r_ps_w') < 1e-7
        assert abs(`s_prD' - `r_prD') < 1e-7

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
        stcox d, nohr efron
        local s_marginal_d = _b[d]

        stcox d wt z, nohr efron

        local s_d = _b[d]
        local s_wt = _b[wt]
        local s_z = _b[z]
        local s_se_d = _se[d]
        local s_se_wt = _se[wt]
        local s_se_z = _se[z]

        preserve
        import delimited "`qa_dir'/fiptiw_coefs.csv", clear
        quietly summarize estimate if model == "marginal_cox", meanonly
        local r_marginal_d = r(mean)
        keep if model == "conditional_cox"
        local r_d = estimate[1]
        local r_wt = estimate[2]
        local r_z = estimate[3]
        local r_se_d = se[1]
        local r_se_wt = se[2]
        local r_se_z = se[3]
        restore

        display as text "  Conditional Cox (D + Wt + Z):"
        display as text "    R:     D=" %8.4f `r_d' "  Wt=" %8.4f `r_wt' "  Z=" %8.4f `r_z'
        display as text "    Stata: D=" %8.4f `s_d' "  Wt=" %8.4f `s_wt' "  Z=" %8.4f `s_z'
        display as text "    R SE:     D=" %8.4f `r_se_d' "  Wt=" %8.4f `r_se_wt' "  Z=" %8.4f `r_se_z'
        display as text "    Stata SE: D=" %8.4f `s_se_d' "  Wt=" %8.4f `s_se_wt' "  Z=" %8.4f `s_se_z'

        assert abs(`s_marginal_d' - `r_marginal_d') < 0.01
        * Tolerance: 0.01 for cross-implementation Cox coefficients
        assert abs(`s_d' - `r_d') < 0.01
        assert abs(`s_wt' - `r_wt') < 0.01
        assert abs(`s_z' - `r_z') < 0.01
        assert abs(`s_se_d' - `r_se_d') / `r_se_d' < 0.05
        assert abs(`s_se_wt' - `r_se_wt') / `r_se_wt' < 0.05
        assert abs(`s_se_z' - `r_se_z') / `r_se_z' < 0.05
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
        iivw_weight, endatlastvisit baseline(event) id(id) time(time) ///
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
* XV9: FIPTIW inferential coverage of the true treatment effect (reference draw)
* =============================================================================
*
* True beta1 = 0.5. This is ONE fixed simulated draw, so the FIPTIW point
* estimate carries sampling error (SE ~= 0.26 here) and legitimately lands away
* from 0.5 even when the estimator is unbiased: iivw reproduces the independent
* R geepack estimate on this draw to 3 decimals (XV10 asserts that parity), so
* the ~0.80 point value is the correct answer for this dataset, not a defect.
* A hard point-bias bound on a single estimated draw is therefore NOT a valid
* test -- it false-fails on sampling noise (see _shared: a fixed tolerance on an
* estimated quantity false-reds). Point recovery IN EXPECTATION is gated
* rigorously and multi-draw in validation_iivw_fiptiw_recovery.do
* (|bias| < 3*MCSE across replications). The valid single-draw check here is
* INFERENTIAL: the 95% Wald CI for the FIPTIW effect must cover the truth 0.5.
* The vce(fixed) SE treats the weights as known, so this CI is if anything too
* NARROW -- a conservative (stricter) coverage gate, not a lenient one.
* =============================================================================
local ++test_count
if `run_only' == 0 | `run_only' == 9 {
    capture noisily {
        _load_fiptiw

        rename d treated
        rename wt wt_cov
        rename z z_cov

        iivw_weight, endatlastvisit baseline(event) id(id) time(time) ///
            visit_cov(wt_cov z_cov) ///
            treat(treated) treat_cov(w) nolog

        * Unweighted GEE (reported only: one draw cannot rank two estimators by
        * bias, so this is context, not a gate)
        quietly glm y treated time, vce(cluster id) nolog
        local b_unwt = _b[treated]

        * FIPTIW-weighted GEE
        iivw_fit y treated, vce(fixed) timespec(linear) nolog
        local b_fiptiw = _b[treated]
        local se_fiptiw = _se[treated]

        * 95% Wald CI for the FIPTIW treatment effect
        local ci_lo = `b_fiptiw' - invnormal(0.975)*`se_fiptiw'
        local ci_hi = `b_fiptiw' + invnormal(0.975)*`se_fiptiw'

        display as text "  True beta1 = 0.5"
        display as text "  Unweighted (reported): " %8.4f `b_unwt'
        display as text "  FIPTIW: " %8.4f `b_fiptiw' "  SE = " %7.4f `se_fiptiw'
        display as text "  95% CI = [" %7.4f `ci_lo' ", " %7.4f `ci_hi' "]  (must cover 0.5)"

        * The estimator's 95% CI must cover the true effect on this reference draw.
        assert `ci_lo' < 0.5 & 0.5 < `ci_hi'
    }
    if _rc == 0 {
        display as result "  PASS: XV9 - FIPTIW 95% CI covers the true effect (0.5)"
        local ++pass_count
    }
    else {
        display as error "  FAIL: XV9 - treatment effect coverage (error `=_rc')"
        local ++fail_count
    }
}

* =============================================================================
* XV10: FIPTIW outcome coefficients and robust SEs match geepack
* =============================================================================
local ++test_count
if `run_only' == 0 | `run_only' == 10 {
    capture noisily {
        _load_fiptiw

        rename d treated
        rename wt wt_cov
        rename z z_cov

        iivw_weight, endatlastvisit baseline(event) id(id) time(time) ///
            visit_cov(treated wt_cov z_cov) ///
            treat(treated) treat_cov(w) nolog

        iivw_fit y treated, vce(fixed) timespec(linear) nolog

        local s_cons = _b[_cons]
        local s_treated = _b[treated]
        local s_time = _b[time]
        local s_se_cons = _se[_cons]
        local s_se_treated = _se[treated]
        local s_se_time = _se[time]

        preserve
        import delimited "`qa_dir'/fiptiw_outcome_geeglm.csv", clear
        local r_cons = intercept[1]
        local r_treated = d[1]
        local r_time = time[1]
        local r_se_cons = se_intercept[1]
        local r_se_treated = se_d[1]
        local r_se_time = se_time[1]
        restore

        display as text "  Stata-equivalent FIPTIW GEE vs geepack:"
        display as text "    coef treated diff = " %12.9f (`s_treated' - `r_treated')
        display as text "    se treated rel diff = " ///
            %12.9f abs(`s_se_treated' - `r_se_treated') / `r_se_treated'

        assert abs(`s_cons' - `r_cons') < 0.001
        assert abs(`s_treated' - `r_treated') < 0.001
        assert abs(`s_time' - `r_time') < 0.001
        assert abs(`s_se_cons' - `r_se_cons') / `r_se_cons' < 0.05
        assert abs(`s_se_treated' - `r_se_treated') / `r_se_treated' < 0.05
        assert abs(`s_se_time' - `r_se_time') / `r_se_time' < 0.05
    }
    if _rc == 0 {
        display as result "  PASS: XV10 - FIPTIW outcome coefficients/SEs match geepack"
        local ++pass_count
    }
    else {
        display as error "  FAIL: XV10 - FIPTIW outcome GEE comparison (error `=_rc')"
        local ++fail_count
    }
}

* ============================================================
* Summary
* ============================================================
display as text "  Part A (IrregLong/Phenobarb):  XV1-XV4"
display as text "  Part B (FIPTIW simulation):    XV5-XV10"
iivw_qa_summary, name(crossval_iivw) tests(`test_count') pass(`pass_count') ///
    fail(`fail_count') runonly(`run_only')


clear
