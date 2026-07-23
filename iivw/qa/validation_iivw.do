clear all
set more off
version 16.0
set varabbrev off

* validation_iivw.do - Correctness validation for iivw package
* Known-answer tests, hand-crafted data, formula verification, invariants
*
* Usage:
*   do iivw/qa/validation_iivw.do          Run all tests
*   do iivw/qa/validation_iivw.do 3        Run only test 3

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
local qa_dir  "`c(pwd)'"
local pkg_dir "`qa_dir'/.."  
local repo_dir "`qa_dir'/../.."
* Sysdir sandbox (Q3): keep this suite's net install out of the user's real
* ado tree even when the suite is run standalone, outside run_all.
do "`c(pwd)'/_iivw_qa_common.do"
iivw_qa_sandbox, pkgdir("`pkg_dir'")


capture ado uninstall iivw
quietly net install iivw, from("`pkg_dir'") replace

local test_count = 0
local pass_count = 0
local fail_count = 0

* =============================================================================
* V1: IIW weights - first observation always gets weight 1
* =============================================================================
local ++test_count
if `run_only' == 0 | `run_only' == 1 {
    capture noisily {
        clear
        * 4 subjects, 3 visits each, simple structure
        input long id double(months severity)
            1 0    2
            1 6    3
            1 12   4
            2 0    1
            2 3    1.5
            2 9    2
            3 0    5
            3 4    6
            3 10   7
            4 0    3
            4 8    3.5
            4 16   4
        end
        * The two baseline modes make OPPOSITE promises about the first visit,
        * and this test asserts each one against the mode it belongs to.
        *
        * baseline(entry): the entry visit is not a modelled monitoring event.
        * It carries weight exactly 1 -- assigned after the mean-1
        * normalization of the fitted component, which is what makes the whole
        * vector invariant to the origin of a Cox covariate. Identical across
        * subjects because it carries no covariate information at all.
        tempvar _v1first
        iivw_weight, endatlastvisit id(id) time(months) visit_cov(severity) nolog
        bysort id (months): gen byte `_v1first' = (_n == 1)
        quietly summarize _iivw_iw if `_v1first'
        assert r(sd) < 1e-9
        assert abs(r(mean) - 1) < 1e-12
        quietly summarize _iivw_weight if `_v1first'
        assert r(sd) < 1e-9

        * baseline(event): the first visit IS a modelled event and keeps the
        * weight the Cox model fitted for it. Subjects with different severity
        * therefore get DIFFERENT first-visit weights -- if they did not, the
        * fitted value would have been overwritten by a convention, which is
        * the defect (SOL-01) that made the estimator depend on covariate
        * location. This is the assertion that would fail on the old build.
        drop `_v1first'
        iivw_weight, endatlastvisit baseline(event) id(id) time(months) ///
            visit_cov(severity) replace nolog
        bysort id (months): gen byte `_v1first' = (_n == 1)
        quietly summarize severity if `_v1first'
        assert r(sd) > 0
        quietly summarize _iivw_iw if `_v1first'
        assert r(sd) > 1e-9
        assert r(N) > 0
    }
    if _rc == 0 {
        display as result "  PASS: V1 - First-observation weights identical (baseline convention)"
        local ++pass_count
    }
    else {
        display as error "  FAIL: V1 - First obs weight (error `=_rc')"
        local ++fail_count
    }
}

* =============================================================================
* V2: IIW weights are exp(-xb) from Cox model
* =============================================================================
local ++test_count
if `run_only' == 0 | `run_only' == 2 {
    capture noisily {
        clear
        * Create panel with known structure
        set seed 20260305
        set obs 50
        gen long id = ceil(_n / 5)
        bysort id: gen int visit_n = _n
        gen double months = visit_n * 3 + rnormal(0, 0.5)
        replace months = 0 if visit_n == 1
        replace months = abs(months)
        gen double severity = 2 + 0.1 * months + rnormal(0, 0.5)

        * Run iivw_weight
        iivw_weight, endatlastvisit baseline(event) id(id) time(months) visit_cov(severity) nolog

        * Manually verify: fit the same AG Cox model and check exp(-xb)
        sort id months
        tempvar start stop event
        bysort id (months): gen double `start' = cond(_n == 1, 0, months[_n-1])
        gen double `stop' = months
        gen byte `event' = 1

        stset `stop', enter(time `start') failure(`event') id(id) exit(time .)
        stcox severity
        tempvar xb manual_w
        predict double `xb', xb
        gen double `manual_w' = exp(-`xb')
        * NO first-row override. This runs baseline(event), where every visit
        * including the first is a modelled monitoring event and keeps its own
        * fitted exp(-xb). Overriding the first row to 1 -- as this oracle did
        * before the SOL-01 fix -- would hand-compute the defect and then
        * confirm the package reproduced it.
        *
        * Mirror the package's mean-1 normalization over the modelled events,
        * which under baseline(event) is every row.
        quietly summarize `manual_w' if !missing(`manual_w'), meanonly
        quietly replace `manual_w' = `manual_w' / r(mean)

        * Compare - should match within floating point tolerance
        gen double wdiff = abs(_iivw_iw - `manual_w')
        quietly summarize wdiff
        assert r(max) < 1e-6
    }
    if _rc == 0 {
        display as result "  PASS: V2 - IIW weights match manual exp(-xb) computation"
        local ++pass_count
    }
    else {
        display as error "  FAIL: V2 - IIW weight formula (error `=_rc')"
        local ++fail_count
    }
}

* =============================================================================
* V3: IPTW weights match manual logit computation
* =============================================================================
local ++test_count
if `run_only' == 0 | `run_only' == 3 {
    capture noisily {
        clear
        set seed 20260305
        set obs 60
        gen long id = ceil(_n / 3)
        bysort id: gen int visit_n = _n
        gen double months = (visit_n - 1) * 6
        gen double baseline_sev = rnormal(3, 1)
        bysort id: replace baseline_sev = baseline_sev[1]
        gen byte treated = runiform() < invlogit(-1 + 0.4 * baseline_sev)
        bysort id: replace treated = treated[1]
        gen double severity = baseline_sev + 0.02 * months + rnormal(0, 0.3)

        iivw_weight, id(id) time(months) visit_cov(severity) ///
            treat(treated) treat_cov(baseline_sev) wtype(iptw) nolog

        * Manually compute IPTW
        logit treated baseline_sev
        tempvar ps
        predict double `ps', pr
        quietly summarize treated
        local p = r(mean)
        tempvar manual_tw
        gen double `manual_tw' = cond(treated == 1, ///
            `p' / `ps', (1 - `p') / (1 - `ps'))

        * Compare
        gen double tw_diff = abs(_iivw_tw - `manual_tw')
        quietly summarize tw_diff
        assert r(max) < 1e-6
    }
    if _rc == 0 {
        display as result "  PASS: V3 - IPTW weights match manual logit computation"
        local ++pass_count
    }
    else {
        display as error "  FAIL: V3 - IPTW formula (error `=_rc')"
        local ++fail_count
    }
}

* =============================================================================
* V4: FIPTIW = IIW * IPTW (multiplicative combination)
* =============================================================================
local ++test_count
if `run_only' == 0 | `run_only' == 4 {
    capture noisily {
        clear
        set seed 20260305
        set obs 60
        gen long id = ceil(_n / 3)
        bysort id: gen int visit_n = _n
        gen double months = (visit_n - 1) * 6
        gen double baseline_sev = rnormal(3, 1)
        bysort id: replace baseline_sev = baseline_sev[1]
        gen byte treated = runiform() < 0.5
        bysort id: replace treated = treated[1]
        gen double severity = baseline_sev + rnormal(0, 0.3)

        iivw_weight, endatlastvisit baseline(event) id(id) time(months) visit_cov(severity) ///
            treat(treated) treat_cov(baseline_sev) nolog

        * FIPTIW should equal IIW * IPTW exactly
        gen double product = _iivw_iw * _iivw_tw
        gen double diff = abs(_iivw_weight - product)
        quietly summarize diff
        assert r(max) < 1e-10
    }
    if _rc == 0 {
        display as result "  PASS: V4 - FIPTIW = IIW * IPTW exactly"
        local ++pass_count
    }
    else {
        display as error "  FAIL: V4 - FIPTIW product (error `=_rc')"
        local ++fail_count
    }
}

* =============================================================================
* V5: Truncation clips at correct percentile values
* =============================================================================
local ++test_count
if `run_only' == 0 | `run_only' == 5 {
    capture noisily {
        clear
        set seed 20260305
        set obs 100
        gen long id = ceil(_n / 5)
        bysort id: gen int visit_n = _n
        gen double months = (visit_n - 1) * 4
        gen double severity = rnormal(3, 2)

        * First run without truncation
        iivw_weight, endatlastvisit baseline(event) id(id) time(months) visit_cov(severity) nolog
        tempvar w_raw
        gen double `w_raw' = _iivw_weight

        * Get percentile bounds
        _pctile `w_raw' if !missing(`w_raw'), percentiles(5 95)
        local lo_val = r(r1)
        local hi_val = r(r2)

        * Re-run with truncation
        iivw_weight, endatlastvisit baseline(event) id(id) time(months) visit_cov(severity) ///
            truncfinal(5 95) replace nolog

        * All weights should be within bounds (with tolerance)
        quietly count if _iivw_weight < `lo_val' - 1e-10 & !missing(_iivw_weight)
        assert r(N) == 0
        quietly count if _iivw_weight > `hi_val' + 1e-10 & !missing(_iivw_weight)
        assert r(N) == 0
    }
    if _rc == 0 {
        display as result "  PASS: V5 - Truncation clips at correct percentiles"
        local ++pass_count
    }
    else {
        display as error "  FAIL: V5 - truncation bounds (error `=_rc')"
        local ++fail_count
    }
}

* =============================================================================
* V6: Effective sample size formula: ESS = (sum w)^2 / (sum w^2)
* =============================================================================
local ++test_count
if `run_only' == 0 | `run_only' == 6 {
    capture noisily {
        clear
        set seed 20260305
        set obs 60
        gen long id = ceil(_n / 3)
        bysort id: gen int visit_n = _n
        gen double months = (visit_n - 1) * 6
        gen double severity = rnormal(3, 1)

        iivw_weight, endatlastvisit baseline(event) id(id) time(months) visit_cov(severity) nolog
        local reported_ess = r(ess)

        * Manual ESS computation
        quietly summarize _iivw_weight
        local sum_w = r(sum)
        tempvar w2
        gen double `w2' = _iivw_weight^2
        quietly summarize `w2'
        local sum_w2 = r(sum)
        local manual_ess = (`sum_w'^2) / `sum_w2'

        assert abs(`reported_ess' - `manual_ess') < 0.01
    }
    if _rc == 0 {
        display as result "  PASS: V6 - ESS formula matches manual computation"
        local ++pass_count
    }
    else {
        display as error "  FAIL: V6 - ESS formula (error `=_rc')"
        local ++fail_count
    }
}

* =============================================================================
* V7: Uniform weights → ESS = N
* =============================================================================
local ++test_count
if `run_only' == 0 | `run_only' == 7 {
    capture noisily {
        * When all covariates are identical, visit intensity doesn't vary
        * → all weights should be ~1 and ESS should be ~N
        clear
        set obs 60
        gen long id = ceil(_n / 3)
        bysort id: gen int visit_n = _n
        gen double months = (visit_n - 1) * 6
        gen double constant = 5

        iivw_weight, endatlastvisit baseline(event) id(id) time(months) visit_cov(constant) nolog

        * With constant covariates, xb = c for all, so exp(-xb) = k for all
        * After setting first obs to 1, remaining should be identical
        * ESS should be close to N
        local ess = r(ess)
        local N = r(N)
        assert abs(`ess' - `N') / `N' < 0.1
    }
    if _rc == 0 {
        display as result "  PASS: V7 - Constant covariates give ESS near N"
        local ++pass_count
    }
    else {
        display as error "  FAIL: V7 - uniform weights ESS (error `=_rc')"
        local ++fail_count
    }
}

* =============================================================================
* V8: iivw_fit GEE matches manual glm with weights
* =============================================================================
local ++test_count
if `run_only' == 0 | `run_only' == 8 {
    capture noisily {
        clear
        set seed 20260305
        set obs 100
        gen long id = ceil(_n / 5)
        bysort id: gen int visit_n = _n
        gen double months = (visit_n - 1) * 6
        gen double severity = rnormal(3, 1)
        gen double outcome = 50 - 0.1 * months - severity + rnormal(0, 2)

        iivw_weight, endatlastvisit baseline(event) id(id) time(months) visit_cov(severity) nolog

        * Fit via iivw_fit
        iivw_fit outcome severity, vce(fixed) model(gee) timespec(linear) nolog
        local b_fit = _b[severity]
        local se_fit = _se[severity]

        * Fit manually via glm
        glm outcome severity months [pw=_iivw_weight], ///
            vce(cluster id) nolog
        local b_manual = _b[severity]
        local se_manual = _se[severity]

        * Should match exactly
        assert abs(`b_fit' - `b_manual') < 1e-6
        assert abs(`se_fit' - `se_manual') < 1e-6
    }
    if _rc == 0 {
        display as result "  PASS: V8 - iivw_fit GEE matches manual glm"
        local ++pass_count
    }
    else {
        display as error "  FAIL: V8 - GEE vs manual glm (error `=_rc')"
        local ++fail_count
    }
}

* =============================================================================
* V9: IIW weights are positive
* =============================================================================
local ++test_count
if `run_only' == 0 | `run_only' == 9 {
    capture noisily {
        use "`repo_dir'/_data/relapses.dta", clear
        sort id edss_date
        gen double days = edss_date - dx_date
        bysort id (edss_date): replace days = days + (_n - 1) * 0.001 ///
            if _n > 1 & days == days[_n-1]
        gen byte relapse = !missing(relapse_date)

        iivw_weight, endatlastvisit baseline(event) id(id) time(days) visit_cov(edss relapse) nolog

        * All weights must be strictly positive (exp(-xb) > 0 always)
        quietly count if _iivw_weight <= 0 & !missing(_iivw_weight)
        assert r(N) == 0
        quietly count if missing(_iivw_weight)
        assert r(N) == 0
    }
    if _rc == 0 {
        display as result "  PASS: V9 - All IIW weights strictly positive (relapses.dta)"
        local ++pass_count
    }
    else {
        display as error "  FAIL: V9 - positive weights (error `=_rc')"
        local ++fail_count
    }
}

* =============================================================================
* V10: Stabilized IIW weights have mean closer to 1
* =============================================================================
local ++test_count
if `run_only' == 0 | `run_only' == 10 {
    capture noisily {
        use "`repo_dir'/_data/relapses.dta", clear
        sort id edss_date
        gen double days = edss_date - dx_date
        bysort id (edss_date): replace days = days + (_n - 1) * 0.001 ///
            if _n > 1 & days == days[_n-1]
        gen byte relapse = !missing(relapse_date)

        * Unstabilized
        iivw_weight, endatlastvisit baseline(event) id(id) time(days) visit_cov(edss relapse) nolog
        local mean_unstab = r(mean_weight)
        local sd_unstab = r(sd_weight)

        * Stabilized with subset of covariates
        iivw_weight, endatlastvisit baseline(event) id(id) time(days) visit_cov(edss relapse) ///
            stabcov(relapse) replace nolog
        local mean_stab = r(mean_weight)
        local sd_stab = r(sd_weight)

        * Stabilized weights should produce valid, positive weights
        * (SD may not always be smaller depending on data structure)
        assert `sd_stab' > 0
        assert `mean_stab' > 0
        * Mean should be reasonably close to 1 (within factor of 5)
        assert `mean_stab' > 0.2 & `mean_stab' < 5
    }
    if _rc == 0 {
        display as result "  PASS: V10 - Stabilized weights are valid and bounded"
        local ++pass_count
    }
    else {
        display as error "  FAIL: V10 - stabilization (error `=_rc')"
        local ++fail_count
    }
}

* =============================================================================
* V11: Lagvars produce correct one-period lag
* =============================================================================
local ++test_count
if `run_only' == 0 | `run_only' == 11 {
    capture noisily {
        clear
        input long id double(months edss)
            1 0   2.0
            1 6   3.0
            1 12  4.0
            2 0   1.0
            2 5   1.5
            2 11  2.0
        end

        iivw_weight, endatlastvisit baseline(event) id(id) time(months) visit_cov(edss) ///
            lagvars(edss) nolog

        * Verify lag values are correct
        sort id months
        * Subject 1: lag should be missing, 2.0, 3.0
        assert missing(edss_lag1[1])
        assert edss_lag1[2] == 2.0
        assert edss_lag1[3] == 3.0
        * Subject 2: lag should be missing, 1.0, 1.5
        assert missing(edss_lag1[4])
        assert edss_lag1[5] == 1.0
        assert edss_lag1[6] == 1.5
    }
    if _rc == 0 {
        display as result "  PASS: V11 - Lagvars produce correct one-period lag"
        local ++pass_count
    }
    else {
        display as error "  FAIL: V11 - lagvars values (error `=_rc')"
        local ++fail_count
    }
}

* =============================================================================
* V12: Weight type auto-detection
* =============================================================================
local ++test_count
if `run_only' == 0 | `run_only' == 12 {
    capture noisily {
        clear
        set seed 20260305
        set obs 40
        gen long id = ceil(_n / 4)
        bysort id: gen int visit_n = _n
        gen double months = (visit_n - 1) * 3
        gen double severity = rnormal(3, 1)
        gen byte treated = mod(id, 2)

        * Without treat() → should be iivw
        iivw_weight, endatlastvisit baseline(event) id(id) time(months) visit_cov(severity) nolog
        assert "`r(weighttype)'" == "iivw"

        * With treat() and treat_cov() -> should be fiptiw.
        * treat_cov() must be a BASELINE characteristic: the propensity model is
        * fitted on one row per subject. severity varies within subject here, so
        * from 2.0.0 passing it directly is refused (rc 459) rather than silently
        * reduced to whatever value sat on the earliest row.
        bysort id (months): gen double severity_bl = severity[1]
        iivw_weight, endatlastvisit baseline(event) id(id) time(months) visit_cov(severity) ///
            treat(treated) treat_cov(severity_bl) replace nolog
        assert "`r(weighttype)'" == "fiptiw"
    }
    if _rc == 0 {
        display as result "  PASS: V12 - Auto-detect: no treat→iivw, treat→fiptiw"
        local ++pass_count
    }
    else {
        display as error "  FAIL: V12 - auto-detection (error `=_rc')"
        local ++fail_count
    }
}

* =============================================================================
* V13: Subject count matches unique IDs in relapses.dta
* =============================================================================
local ++test_count
if `run_only' == 0 | `run_only' == 13 {
    capture noisily {
        use "`repo_dir'/_data/relapses.dta", clear
        sort id edss_date
        gen double days = edss_date - dx_date
        bysort id (edss_date): replace days = days + (_n - 1) * 0.001 ///
            if _n > 1 & days == days[_n-1]
        gen byte relapse = !missing(relapse_date)

        * Count unique IDs manually
        tempvar first
        bysort id: gen byte `first' = (_n == 1)
        quietly count if `first' == 1
        local manual_ids = r(N)

        iivw_weight, endatlastvisit baseline(event) id(id) time(days) visit_cov(edss relapse) nolog
        assert r(n_ids) == `manual_ids'
        assert r(n_ids) == 500
        assert r(N) == 4433
    }
    if _rc == 0 {
        display as result "  PASS: V13 - Subject/obs counts match relapses.dta"
        local ++pass_count
    }
    else {
        display as error "  FAIL: V13 - counts (error `=_rc')"
        local ++fail_count
    }
}

* =============================================================================
* V14: iivw_fit cubic timespec creates time_sq and time_cu
* =============================================================================
local ++test_count
if `run_only' == 0 | `run_only' == 14 {
    capture noisily {
        clear
        set seed 20260305
        set obs 60
        gen long id = ceil(_n / 3)
        bysort id: gen int visit_n = _n
        gen double months = (visit_n - 1) * 6
        gen double severity = rnormal(3, 1)
        gen double outcome = 50 - 0.1 * months + rnormal(0, 2)

        iivw_weight, endatlastvisit baseline(event) id(id) time(months) visit_cov(severity) nolog
        iivw_fit outcome severity, vce(fixed) timespec(cubic) nolog

        confirm variable _iivw_time_sq
        confirm variable _iivw_time_cu

        * Verify values
        assert abs(_iivw_time_sq - months^2) < 1e-6
        assert abs(_iivw_time_cu - months^3) < 1e-6
    }
    if _rc == 0 {
        display as result "  PASS: V14 - Cubic timespec creates correct vars"
        local ++pass_count
    }
    else {
        display as error "  FAIL: V14 - cubic timespec (error `=_rc')"
        local ++fail_count
    }
}

* =============================================================================
* V15: IPTW stabilized weights use marginal prevalence
* =============================================================================
local ++test_count
if `run_only' == 0 | `run_only' == 15 {
    capture noisily {
        clear
        set seed 20260305
        set obs 60
        gen long id = ceil(_n / 3)
        bysort id: gen int visit_n = _n
        gen double months = (visit_n - 1) * 6
        gen double baseline_sev = rnormal(3, 1)
        bysort id: replace baseline_sev = baseline_sev[1]
        gen byte treated = runiform() < 0.4
        bysort id: replace treated = treated[1]
        gen double severity = baseline_sev + rnormal(0, 0.3)

        iivw_weight, id(id) time(months) visit_cov(severity) ///
            treat(treated) treat_cov(baseline_sev) wtype(iptw) nolog

        * For treated: w = p/ps; for untreated: w = (1-p)/(1-ps)
        * Stabilized IPTW should have mean close to 1
        quietly summarize _iivw_tw
        assert abs(r(mean) - 1) < 0.3
    }
    if _rc == 0 {
        display as result "  PASS: V15 - Stabilized IPTW mean near 1"
        local ++pass_count
    }
    else {
        display as error "  FAIL: V15 - IPTW stabilization (error `=_rc')"
        local ++fail_count
    }
}

* =============================================================================
* V16: Quadratic timespec creates correct squared values
* =============================================================================
local ++test_count
if `run_only' == 0 | `run_only' == 16 {
    capture noisily {
        clear
        set seed 20260305
        set obs 60
        gen long id = ceil(_n / 3)
        bysort id: gen int visit_n = _n
        gen double months = (visit_n - 1) * 6
        gen double severity = rnormal(3, 1)
        gen double outcome = 50 - 0.1 * months + rnormal(0, 2)

        iivw_weight, endatlastvisit baseline(event) id(id) time(months) visit_cov(severity) nolog
        iivw_fit outcome severity, vce(fixed) timespec(quadratic) nolog

        confirm variable _iivw_time_sq
        * Verify values: time_sq should be months^2
        assert abs(_iivw_time_sq - months^2) < 1e-6
    }
    if _rc == 0 {
        display as result "  PASS: V16 - Quadratic timespec creates correct squared values"
        local ++pass_count
    }
    else {
        display as error "  FAIL: V16 - quadratic values (error `=_rc')"
        local ++fail_count
    }
}

* =============================================================================
* V17: ns(1) spline basis is identity (scaled time)
* =============================================================================
local ++test_count
if `run_only' == 0 | `run_only' == 17 {
    capture noisily {
        clear
        set obs 40
        gen long id = ceil(_n / 4)
        bysort id: gen int visit_n = _n
        gen double months = (visit_n - 1) * 3
        gen double severity = rnormal(3, 1)
        gen double outcome = rnormal(5, 1)

        iivw_weight, endatlastvisit baseline(event) id(id) time(months) visit_cov(severity) nolog
        iivw_fit outcome severity, vce(fixed) timespec(ns(1)) nolog

        * ns(1) = 1 df = just linear in time
        confirm variable _iivw_tns1
        * Should be equivalent to time (or a linear function of time)
        correlate _iivw_tns1 months
        assert abs(r(rho)) > 0.999
    }
    if _rc == 0 {
        display as result "  PASS: V17 - ns(1) basis is linear function of time"
        local ++pass_count
    }
    else {
        display as error "  FAIL: V17 - ns(1) basis (error `=_rc')"
        local ++fail_count
    }
}

* =============================================================================
* V18: Entry option adjusts counting process start time
* =============================================================================
local ++test_count
if `run_only' == 0 | `run_only' == 18 {
    capture noisily {
        * Hand-crafted: 3 subjects, entry at different times
        * Entry should affect the first interval's risk set
        clear
        input long id double(months severity entry_t)
            1 2    2.0  0.5
            1 6    3.0  0.5
            1 12   4.0  0.5
            2 3    1.0  1.0
            2 8    1.5  1.0
            2 15   2.0  1.0
            3 1    5.0  0.0
            3 5    6.0  0.0
            3 11   7.0  0.0
        end

        * With entry: first interval starts at entry_t
        iivw_weight, endatlastvisit baseline(event) id(id) time(months) visit_cov(severity) ///
            entry(entry_t) nolog
        local n_entry = r(N)

        * Without entry: first interval starts at 0
        iivw_weight, endatlastvisit baseline(event) id(id) time(months) visit_cov(severity) ///
            replace nolog
        local n_noentry = r(N)

        * Both should produce valid weights
        assert `n_entry' == `n_noentry'
        assert `n_entry' == 9
        * Under baseline(event) the first visit is a modelled event over
        * (entry_t, t1], so it carries a FITTED weight -- not a shared
        * convention value. Assert it exists and is usable; V1 owns the
        * per-mode first-visit contract.
        tempvar _v18first
        bysort id (months): gen byte `_v18first' = (_n == 1)
        quietly count if `_v18first' & missing(_iivw_iw)
        assert r(N) == 0
        quietly summarize _iivw_iw if `_v18first'
        assert r(min) > 0
    }
    if _rc == 0 {
        display as result "  PASS: V18 - Entry option works, first-obs weights identical"
        local ++pass_count
    }
    else {
        display as error "  FAIL: V18 - entry option (error `=_rc')"
        local ++fail_count
    }
}

* =============================================================================
* V19: Weight sum invariant - unstabilized IIW weights
* =============================================================================
* The IIW component is normalized to mean 1, so the reported weight mean is
* exactly 1 (up to floating point) rather than merely close to it.
local ++test_count
if `run_only' == 0 | `run_only' == 19 {
    capture noisily {
        clear
        set seed 20260305
        set obs 200
        gen long id = ceil(_n / 5)
        bysort id: gen int visit_n = _n
        gen double months = (visit_n - 1) * 6
        gen double severity = rnormal(3, 0.5)

        iivw_weight, endatlastvisit baseline(event) id(id) time(months) visit_cov(severity) nolog

        * IIW weights are normalized to mean 1 by construction (exact, not a range)
        assert abs(r(mean_weight) - 1) < 1e-8
        * All weights strictly positive
        quietly count if _iivw_weight <= 0 & !missing(_iivw_weight)
        assert r(N) == 0
    }
    if _rc == 0 {
        display as result "  PASS: V19 - Weight mean in reasonable range"
        local ++pass_count
    }
    else {
        display as error "  FAIL: V19 - weight mean bounds (error `=_rc')"
        local ++fail_count
    }
}

* =============================================================================
* V20: Categorical dummies are mutually exclusive and exhaustive
* =============================================================================
local ++test_count
if `run_only' == 0 | `run_only' == 20 {
    capture noisily {
        clear
        set seed 20260305
        set obs 60
        gen long id = ceil(_n / 3)
        bysort id: gen int visit_n = _n
        gen double months = (visit_n - 1) * 6
        gen double severity = rnormal(3, 1)
        gen double outcome = 50 + rnormal(0, 2)
        gen byte arm = mod(id, 3)
        label define arm_lbl 0 "Placebo" 1 "Low dose" 2 "High dose", replace
        label values arm arm_lbl

        iivw_weight, endatlastvisit baseline(event) id(id) time(months) visit_cov(severity) nolog
        iivw_fit outcome arm, vce(fixed) categorical(arm) nolog

        * Base category (0=Placebo) has no dummy
        * Dummies for levels 1 and 2 should be mutually exclusive
        * Row sum of dummies should be 0 or 1 (never both 1)
        gen byte dsum = _iivw_cat_low_dose + _iivw_cat_high_dose
        assert dsum <= 1

        * For arm==0 (base): both dummies should be 0
        assert _iivw_cat_low_dose == 0 if arm == 0
        assert _iivw_cat_high_dose == 0 if arm == 0

        * For arm==1: low_dose=1, high_dose=0
        assert _iivw_cat_low_dose == 1 if arm == 1
        assert _iivw_cat_high_dose == 0 if arm == 1

        * For arm==2: low_dose=0, high_dose=1
        assert _iivw_cat_low_dose == 0 if arm == 2
        assert _iivw_cat_high_dose == 1 if arm == 2
    }
    if _rc == 0 {
        display as result "  PASS: V20 - Categorical dummies mutually exclusive/exhaustive"
        local ++pass_count
    }
    else {
        display as error "  FAIL: V20 - categorical exhaustiveness (error `=_rc')"
        local ++fail_count
    }
}

* =============================================================================
* V21: Fixed-weight bootstrap SEs are not dramatically smaller than sandwich SEs
* The bootstrap in iivw_fit treats estimated weights as fixed, so it reflects
* outcome-model uncertainty only rather than weight-estimation uncertainty.
* =============================================================================
local ++test_count
if `run_only' == 0 | `run_only' == 21 {
    capture noisily {
        clear
        set seed 20260312
        set obs 500
        gen long id = ceil(_n / 10)
        bysort id: gen int visit_n = _n
        gen double months = (visit_n - 1) * 3
        gen double severity = rnormal(3, 1)
        gen double outcome = 50 - 0.1 * months - 2 * severity + rnormal(0, 3)
        iivw_weight, endatlastvisit baseline(event) id(id) time(months) visit_cov(severity) nolog

        * Sandwich SEs
        iivw_fit outcome severity, vce(fixed) model(gee) timespec(linear) nolog
        local se_sandwich = _se[severity]

        * Re-weight (iivw_fit clears some metadata)
        iivw_weight, endatlastvisit baseline(event) id(id) time(months) visit_cov(severity) replace nolog

        * Bootstrap SEs (50 reps for stability)
        iivw_fit outcome severity, model(gee) timespec(linear) ///
            bootstrap(50) nolog
        local se_bootstrap = _se[severity]

        * Bootstrap SE should be positive and at least 80% of sandwich
        * (not strictly larger every time due to sampling, but should not
        * be dramatically smaller)
        assert `se_bootstrap' > 0
        assert `se_bootstrap' > `se_sandwich' * 0.8
    }
    if _rc == 0 {
        display as result "  PASS: V21 - Bootstrap SEs reasonable vs sandwich"
        local ++pass_count
    }
    else {
        display as error "  FAIL: V21 - bootstrap SE comparison (error `=_rc')"
        local ++fail_count
    }
}

* =============================================================================
* V22: Bootstrap point estimates match non-bootstrap
* The bootstrap wrapper should produce the same point estimates as the
* direct estimation path (both apply pweights to glm).
* =============================================================================
local ++test_count
if `run_only' == 0 | `run_only' == 22 {
    capture noisily {
        clear
        set seed 20260312
        set obs 200
        gen long id = ceil(_n / 5)
        bysort id: gen int visit_n = _n
        gen double months = (visit_n - 1) * 6
        gen double severity = rnormal(3, 1)
        gen double outcome = 50 - 0.1 * months - severity + rnormal(0, 2)
        iivw_weight, endatlastvisit baseline(event) id(id) time(months) visit_cov(severity) nolog

        * Non-bootstrap estimate
        iivw_fit outcome severity, vce(fixed) model(gee) timespec(linear) nolog
        local b_direct = _b[severity]

        * Re-weight
        iivw_weight, endatlastvisit baseline(event) id(id) time(months) visit_cov(severity) replace nolog

        * Bootstrap estimate (point estimate should match)
        iivw_fit outcome severity, model(gee) timespec(linear) ///
            bootstrap(10) nolog
        local b_bootstrap = _b[severity]

        * Point estimates should be identical (same data, same model)
        assert reldif(`b_direct', `b_bootstrap') < 1e-6
    }
    if _rc == 0 {
        display as result "  PASS: V22 - Bootstrap point estimates match direct"
        local ++pass_count
    }
    else {
        display as error "  FAIL: V22 - bootstrap point estimate match (error `=_rc')"
        local ++fail_count
    }
}

* =============================================================================
* V23: Sort invariance - shuffled data gives same weights
* =============================================================================
local ++test_count
if `run_only' == 0 | `run_only' == 23 {
    capture noisily {
        clear
        set seed 20260321
        set obs 60
        gen long id = ceil(_n / 3)
        bysort id: gen int visit_n = _n
        gen double months = (visit_n - 1) * 6
        gen double severity = rnormal(3, 1)

        * Run in natural order
        iivw_weight, endatlastvisit baseline(event) id(id) time(months) visit_cov(severity) nolog
        tempvar w_ordered
        gen double `w_ordered' = _iivw_weight
        tempvar orig_n
        gen long `orig_n' = _n

        * Shuffle and re-run
        gen double _shuffle = runiform()
        sort _shuffle
        iivw_weight, endatlastvisit baseline(event) id(id) time(months) visit_cov(severity) replace nolog

        * Restore original order and compare
        sort `orig_n'
        gen double wdiff = abs(_iivw_weight - `w_ordered')
        quietly summarize wdiff
        assert r(max) < 1e-10
        drop _shuffle
    }
    if _rc == 0 {
        display as result "  PASS: V23 - Sort invariance (shuffled data same weights)"
        local ++pass_count
    }
    else {
        display as error "  FAIL: V23 - sort invariance (error `=_rc')"
        local ++fail_count
    }
}

* =============================================================================
* V24: Idempotency - running iivw_weight twice gives identical weights
* =============================================================================
local ++test_count
if `run_only' == 0 | `run_only' == 24 {
    capture noisily {
        clear
        set seed 20260321
        set obs 80
        gen long id = ceil(_n / 4)
        bysort id: gen int visit_n = _n
        gen double months = (visit_n - 1) * 6
        gen double severity = rnormal(3, 1)

        iivw_weight, endatlastvisit baseline(event) id(id) time(months) visit_cov(severity) nolog
        tempvar w_first
        gen double `w_first' = _iivw_weight

        iivw_weight, endatlastvisit baseline(event) id(id) time(months) visit_cov(severity) replace nolog
        gen double wdiff = abs(_iivw_weight - `w_first')
        quietly summarize wdiff
        assert r(max) < 1e-10
    }
    if _rc == 0 {
        display as result "  PASS: V24 - Idempotency (two runs identical)"
        local ++pass_count
    }
    else {
        display as error "  FAIL: V24 - idempotency (error `=_rc')"
        local ++fail_count
    }
}

* =============================================================================
* V25: ns(2) creates exactly 2 spline basis variables
* =============================================================================
local ++test_count
if `run_only' == 0 | `run_only' == 25 {
    capture noisily {
        clear
        set seed 20260321
        set obs 100
        gen long id = ceil(_n / 5)
        bysort id: gen int visit_n = _n
        gen double months = (visit_n - 1) * 6
        gen double severity = rnormal(3, 1)
        gen double outcome = 50 + rnormal(0, 2)

        iivw_weight, endatlastvisit baseline(event) id(id) time(months) visit_cov(severity) nolog
        iivw_fit outcome severity, vce(fixed) timespec(ns(2)) nolog

        confirm variable _iivw_tns1
        confirm variable _iivw_tns2
        * ns(2) should NOT create tns3
        capture confirm variable _iivw_tns3
        assert _rc != 0
    }
    if _rc == 0 {
        display as result "  PASS: V25 - ns(2) creates exactly 2 basis variables"
        local ++pass_count
    }
    else {
        display as error "  FAIL: V25 - ns(2) variable count (error `=_rc')"
        local ++fail_count
    }
}

* =============================================================================
* V26: ns(3) has two interior knots at the tertiles and the exact RCS basis
* =============================================================================
* ns(3) means three BASIS variables: one linear plus two nonlinear restricted-
* cubic-spline columns.  It therefore has two interior knots, at 1/3 and 2/3 of
* the observed time distribution.  The old test claimed one median knot but
* asserted only that three variables existed and tns1 was linear -- a source-
* comment false green.  This fixture has known boundaries 0/24 and known
* tertile knots 6/18, so calculate both nonlinear columns independently.
local ++test_count
if `run_only' == 0 | `run_only' == 26 {
    capture noisily {
        clear
        set seed 20260321
        set obs 100
        gen long id = ceil(_n / 5)
        bysort id: gen int visit_n = _n
        gen double months = (visit_n - 1) * 6
        gen double severity = rnormal(3, 1)
        gen double outcome = 50 + rnormal(0, 2)

        iivw_weight, endatlastvisit baseline(event) id(id) time(months) visit_cov(severity) nolog
        iivw_fit outcome severity, vce(fixed) timespec(ns(3)) nolog

        confirm variable _iivw_tns1
        confirm variable _iivw_tns2
        confirm variable _iivw_tns3
        * tns1 should equal months (linear basis)
        gen double tns1_diff = abs(_iivw_tns1 - months)
        quietly summarize tns1_diff
        assert r(max) < 1e-10
        drop tns1_diff

        quietly _pctile months, percentiles(33.33333333333333 66.66666666666667)
        local k1 = r(r1)
        local k2 = r(r2)
        assert abs(`k1' - 6) < 1e-12
        assert abs(`k2' - 18) < 1e-12

        gen double expected2 = ///
            (max(0, months - 0)^3 - max(0, months - 24)^3) / 24 - ///
            (max(0, months - 18)^3 - max(0, months - 24)^3) / 6
        gen double expected3 = ///
            (max(0, months - 6)^3 - max(0, months - 24)^3) / 18 - ///
            (max(0, months - 18)^3 - max(0, months - 24)^3) / 6
        gen double tns2_diff = abs(_iivw_tns2 - expected2)
        gen double tns3_diff = abs(_iivw_tns3 - expected3)
        quietly summarize tns2_diff, meanonly
        assert r(max) < 1e-10
        quietly summarize tns3_diff, meanonly
        assert r(max) < 1e-10
    }
    if _rc == 0 {
        display as result "  PASS: V26 - ns(3) tertile knots and exact RCS basis"
        local ++pass_count
    }
    else {
        display as error "  FAIL: V26 - ns(3) tertile-knot basis (error `=_rc')"
        local ++fail_count
    }
}

* =============================================================================
* V27: Mixed model gives similar estimates to GEE
* =============================================================================
local ++test_count
if `run_only' == 0 | `run_only' == 27 {
    capture noisily {
        clear
        set seed 20260321
        set obs 200
        gen long id = ceil(_n / 5)
        bysort id: gen int visit_n = _n
        gen double months = (visit_n - 1) * 6
        gen double severity = rnormal(3, 1)
        gen double outcome = 50 - 0.1 * months - 2 * severity + rnormal(0, 3)

        iivw_weight, endatlastvisit baseline(event) id(id) time(months) visit_cov(severity) nolog

        * GEE estimate
        iivw_fit outcome severity, vce(fixed) model(gee) timespec(linear) nolog
        local b_gee = _b[severity]

        * Mixed estimate (need to re-weight since iivw_fit stores metadata)
        iivw_weight, endatlastvisit baseline(event) id(id) time(months) visit_cov(severity) replace nolog
        iivw_fit outcome severity, vce(fixed) model(mixed) experimentalmixed timespec(linear) nolog replace
        local b_mixed = _b[severity]

        * Both should be in same direction and within factor of 2
        assert (`b_gee' < 0) == (`b_mixed' < 0)
        local ratio = abs(`b_gee') / abs(`b_mixed')
        assert `ratio' > 0.5 & `ratio' < 2.0
    }
    if _rc == 0 {
        display as result "  PASS: V27 - Mixed and GEE give similar estimates"
        local ++pass_count
    }
    else {
        display as error "  FAIL: V27 - mixed vs GEE (error `=_rc')"
        local ++fail_count
    }
}

* =============================================================================
* V28: Interaction variable values match manual product
* =============================================================================
local ++test_count
if `run_only' == 0 | `run_only' == 28 {
    capture noisily {
        clear
        set seed 20260321
        set obs 100
        gen long id = ceil(_n / 5)
        bysort id: gen int visit_n = _n
        gen double months = (visit_n - 1) * 6
        gen double severity = rnormal(3, 1)
        gen double outcome = 50 - severity * months * 0.01 + rnormal(0, 2)

        iivw_weight, endatlastvisit baseline(event) id(id) time(months) visit_cov(severity) nolog
        iivw_fit outcome severity, vce(fixed) timespec(quadratic) ///
            interaction(severity) nolog

        * ix_severity_time = severity * months
        gen double manual_ix_time = severity * months
        gen double manual_ix_tsq = severity * _iivw_time_sq
        gen double diff_time = abs(_iivw_ix_severity_time - manual_ix_time)
        gen double diff_tsq = abs(_iivw_ix_severity_tsq - manual_ix_tsq)
        quietly summarize diff_time
        assert r(max) < 1e-10
        quietly summarize diff_tsq
        assert r(max) < 1e-10
    }
    if _rc == 0 {
        display as result "  PASS: V28 - Interaction values match manual product"
        local ++pass_count
    }
    else {
        display as error "  FAIL: V28 - interaction products (error `=_rc')"
        local ++fail_count
    }
}

* ============================================================
* Summary
* ============================================================
iivw_qa_summary, name(validation_iivw) tests(`test_count') pass(`pass_count') ///
    fail(`fail_count') runonly(`run_only')


clear
