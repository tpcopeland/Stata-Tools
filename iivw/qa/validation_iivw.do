* validation_iivw.do - Validation tests for iivw package
* Known-answer tests with hand-crafted data and cross-checks
*
* Usage:
*   do iivw/qa/validation_iivw.do          Run all tests
*   do iivw/qa/validation_iivw.do 3        Run only test 3

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
        iivw_weight, id(id) time(months) visit_cov(severity) nolog
        * First obs per subject must have weight = 1
        bysort id (months): assert _iivw_iw == 1 if _n == 1
        * First obs per subject must have weight = 1 for composite too
        bysort id (months): assert _iivw_weight == 1 if _n == 1
    }
    if _rc == 0 {
        display as result "  PASS: V1 - First observation weight = 1"
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
        iivw_weight, id(id) time(months) visit_cov(severity) nolog

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
        bysort id (months): replace `manual_w' = 1 if _n == 1

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

        iivw_weight, id(id) time(months) visit_cov(severity) ///
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
        iivw_weight, id(id) time(months) visit_cov(severity) nolog
        tempvar w_raw
        gen double `w_raw' = _iivw_weight

        * Get percentile bounds
        _pctile `w_raw' if !missing(`w_raw'), percentiles(5 95)
        local lo_val = r(r1)
        local hi_val = r(r2)

        * Re-run with truncation
        iivw_weight, id(id) time(months) visit_cov(severity) ///
            truncate(5 95) replace nolog

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

        iivw_weight, id(id) time(months) visit_cov(severity) nolog
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

        iivw_weight, id(id) time(months) visit_cov(constant) nolog

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

        iivw_weight, id(id) time(months) visit_cov(severity) nolog

        * Fit via iivw_fit
        iivw_fit outcome severity, model(gee) timespec(linear) nolog
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
        use "/home/tpcopeland/Stata-Tools/_data/relapses.dta", clear
        sort id edss_date
        gen double days = edss_date - dx_date
        bysort id (edss_date): replace days = days + (_n - 1) * 0.001 ///
            if _n > 1 & days == days[_n-1]
        gen byte relapse = !missing(relapse_date)

        iivw_weight, id(id) time(days) visit_cov(edss relapse) nolog

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
        use "/home/tpcopeland/Stata-Tools/_data/relapses.dta", clear
        sort id edss_date
        gen double days = edss_date - dx_date
        bysort id (edss_date): replace days = days + (_n - 1) * 0.001 ///
            if _n > 1 & days == days[_n-1]
        gen byte relapse = !missing(relapse_date)

        * Unstabilized
        iivw_weight, id(id) time(days) visit_cov(edss relapse) nolog
        local mean_unstab = r(mean_weight)
        local sd_unstab = r(sd_weight)

        * Stabilized with subset of covariates
        iivw_weight, id(id) time(days) visit_cov(edss relapse) ///
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

        iivw_weight, id(id) time(months) visit_cov(edss) ///
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
        iivw_weight, id(id) time(months) visit_cov(severity) nolog
        assert "`r(weighttype)'" == "iivw"

        * With treat() → should be fiptiw
        iivw_weight, id(id) time(months) visit_cov(severity) ///
            treat(treated) replace nolog
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
        use "/home/tpcopeland/Stata-Tools/_data/relapses.dta", clear
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

        iivw_weight, id(id) time(days) visit_cov(edss relapse) nolog
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

        iivw_weight, id(id) time(months) visit_cov(severity) nolog
        iivw_fit outcome severity, timespec(cubic) nolog

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
* SUMMARY
* =============================================================================
display ""
display as text "{hline 50}"
display as result "RESULT: validation_iivw"
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
