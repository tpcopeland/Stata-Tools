*! tte_calibrate Version 1.1.0  2026/03/15
*! Negative control outcome calibration for target trial emulation
*! Author: Timothy P Copeland
*! Author: Tania F Reza
*! Department of Clinical Neuroscience, Karolinska Institutet
*! Department of Global Public Health, Karolinska Institutet
*! Program class: rclass (returns results in r())

/*
Basic syntax:
  tte_calibrate, estimate(#) se(#) nco_estimates(matname)
      [method(normal) level(#) null(#)]

Description:
  Calibrates treatment effect estimates using negative control outcomes.
  Implements the OHDSI EmpiricalCalibration algorithm (Schuemie 2014)
  to estimate systematic error from negative controls and adjust the
  primary estimate accordingly.

Options:
  estimate(real)         - Primary log-effect estimate (log-OR or log-HR) (required)
  se(real)               - Standard error of primary estimate (required)
  nco_estimates(name)    - Nx2 matrix of (log-estimate, SE) for each NCO (required)
  method(string)         - Systematic error distribution: normal (default)
  level(cilevel)         - Confidence level (default: 95)
  null(real 0)           - Null hypothesis value (default: 0)

See help tte_calibrate for complete documentation
*/

program define tte_calibrate, rclass
    version 16.0
    local _vaset = c(varabbrev)
    set varabbrev off
    set more off

    * =========================================================================
    * SYNTAX PARSING
    * =========================================================================

    syntax , ESTimate(real) SE(real) NCO_estimates(name) ///
        [METHod(string) Level(cilevel) NULL(real 0)]

    * =========================================================================
    * DEFAULTS AND VALIDATION
    * =========================================================================

    if "`method'" == "" local method "normal"
    if "`level'" == "" local level 95

    if "`method'" != "normal" {
        display as error "method() must be normal"
        set varabbrev `_vaset'
        exit 198
    }

    if `se' <= 0 {
        display as error "se() must be positive"
        set varabbrev `_vaset'
        exit 198
    }

    * Validate nco_estimates matrix exists
    capture confirm matrix `nco_estimates'
    if _rc != 0 {
        display as error "matrix `nco_estimates' not found"
        set varabbrev `_vaset'
        exit 111
    }

    * Validate matrix dimensions: must be Nx2
    local n_nco = rowsof(`nco_estimates')
    local n_cols = colsof(`nco_estimates')

    if `n_cols' != 2 {
        display as error "nco_estimates() must be an Nx2 matrix (columns: log-estimate, SE)"
        set varabbrev `_vaset'
        exit 503
    }

    if `n_nco' < 3 {
        display as error "nco_estimates() must have at least 3 rows (negative control outcomes)"
        set varabbrev `_vaset'
        exit 198
    }

    * Validate all SEs are positive
    forvalues k = 1/`n_nco' {
        local se_k = `nco_estimates'[`k', 2]
        if `se_k' <= 0 {
            display as error "nco_estimates() row `k': SE must be positive (found `se_k')"
            set varabbrev `_vaset'
            exit 198
        }
    }

    * =========================================================================
    * FIT SYSTEMATIC ERROR DISTRIBUTION VIA MATA
    * =========================================================================

    * Call Mata function to fit (bias, sigma_sq) via profile likelihood
    tempname nco_mat
    matrix `nco_mat' = `nco_estimates'

    mata: _tte_calibrate_fit("`nco_mat'")

    * Retrieve results from Mata (stored in local macros)
    local bias = `_tte_cal_bias'
    local sigma_sq = `_tte_cal_sigma_sq'
    local sigma = sqrt(`sigma_sq')

    * =========================================================================
    * CALIBRATED ESTIMATES
    * =========================================================================

    local cal_estimate = `estimate' - `bias'
    local cal_se = sqrt(`se'^2 + `sigma_sq')

    local z_crit = invnormal((100 + `level') / 200)

    * Uncalibrated CI and p-value
    local ci_lo = `estimate' - `z_crit' * `se'
    local ci_hi = `estimate' + `z_crit' * `se'
    local z_uncal = (`estimate' - `null') / `se'
    local pvalue = 2 * normal(-abs(`z_uncal'))

    * Calibrated CI and p-value
    local cal_ci_lo = `cal_estimate' - `z_crit' * `cal_se'
    local cal_ci_hi = `cal_estimate' + `z_crit' * `cal_se'
    local z_cal = (`cal_estimate' - `null') / `cal_se'
    local cal_pvalue = 2 * normal(-abs(`z_cal'))

    * =========================================================================
    * DISPLAY RESULTS
    * =========================================================================

    display as text ""
    display as text "{hline 70}"
    display as result "tte_calibrate" as text " - Negative Control Outcome Calibration"
    display as text "{hline 70}"
    display as text ""

    display as text "Negative control outcomes: " as result `n_nco'
    display as text "Method:                    " as result "`method'"

    display as text ""
    display as text "{bf:Systematic error estimates:}"
    display as text "  Bias:            " as result %9.4f `bias'
    display as text "  Sigma:           " as result %9.4f `sigma'

    display as text ""
    display as text %20s "" "  " %12s "Uncalibrated" "  " %12s "Calibrated"
    display as text "  " _dup(48) "-"

    display as text "  Estimate       " "  " ///
        as result %12.4f `estimate' "  " %12.4f `cal_estimate'

    display as text "  SE             " "  " ///
        as result %12.4f `se' "  " %12.4f `cal_se'

    local ci_str_uncal: display %5.2f `ci_lo' " to " %5.2f `ci_hi'
    local ci_str_cal: display %5.2f `cal_ci_lo' " to " %5.2f `cal_ci_hi'
    display as text "  `level'% CI          " "  " ///
        as result %12s "`ci_str_uncal'" "  " %12s "`ci_str_cal'"

    display as text "  P-value        " "  " ///
        as result %12.4f `pvalue' "  " %12.4f `cal_pvalue'

    display as text "  " _dup(48) "-"
    display as text ""
    display as text "{hline 70}"

    * =========================================================================
    * RETURN RESULTS
    * =========================================================================

    return scalar estimate = `estimate'
    return scalar se = `se'
    return scalar ci_lo = `ci_lo'
    return scalar ci_hi = `ci_hi'
    return scalar pvalue = `pvalue'
    return scalar bias = `bias'
    return scalar sigma = `sigma'
    return scalar n_nco = `n_nco'
    return scalar cal_estimate = `cal_estimate'
    return scalar cal_se = `cal_se'
    return scalar cal_ci_lo = `cal_ci_lo'
    return scalar cal_ci_hi = `cal_ci_hi'
    return scalar cal_pvalue = `cal_pvalue'
    return local method "`method'"

    set varabbrev `_vaset'
end

* =========================================================================
* MATA: Profile likelihood estimation of systematic error parameters
* =========================================================================

mata:
void _tte_calibrate_fit(string scalar matname)
{
    real matrix nco
    real colvector b, se2
    real scalar K, bias, sigma_sq
    real scalar max_sigma_sq, best_ll, best_sigma_sq
    real scalar grid_n, step, s, ll
    real scalar a, b_gs, c, d, fa, fb, fc, fd
    real scalar tol, gr
    real scalar i

    nco = st_matrix(matname)
    K = rows(nco)

    b = nco[., 1]
    se2 = nco[., 2] :^ 2

    // Upper bound for sigma_sq search: variance of NCO point estimates
    max_sigma_sq = variance(b)
    if (max_sigma_sq < 1e-10) max_sigma_sq = 1e-10

    // ---------------------------------------------------------------
    // Grid search over sigma_sq in [0, max_sigma_sq]
    // ---------------------------------------------------------------
    grid_n = 1000
    step = max_sigma_sq / grid_n
    best_ll = .
    best_sigma_sq = 0

    for (i = 0; i <= grid_n; i++) {
        s = i * step
        ll = _tte_cal_profile_ll(b, se2, s)
        if (best_ll == . | ll > best_ll) {
            best_ll = ll
            best_sigma_sq = s
        }
    }

    // ---------------------------------------------------------------
    // Golden section refinement around the best grid point
    // ---------------------------------------------------------------
    tol = 1e-8
    gr = (sqrt(5) - 1) / 2

    a = max((0, best_sigma_sq - step))
    d = min((max_sigma_sq, best_sigma_sq + step))

    b_gs = d - gr * (d - a)
    c = a + gr * (d - a)
    fb = _tte_cal_profile_ll(b, se2, b_gs)
    fc = _tte_cal_profile_ll(b, se2, c)

    while ((d - a) > tol) {
        if (fb < fc) {
            // maximum is in [b_gs, d]
            a = b_gs
            b_gs = c
            fb = fc
            c = a + gr * (d - a)
            fc = _tte_cal_profile_ll(b, se2, c)
        }
        else {
            // maximum is in [a, c]
            d = c
            c = b_gs
            fc = fb
            b_gs = d - gr * (d - a)
            fb = _tte_cal_profile_ll(b, se2, b_gs)
        }
    }

    sigma_sq = (a + d) / 2
    if (sigma_sq < 0) sigma_sq = 0

    // Compute bias given optimal sigma_sq
    bias = _tte_cal_weighted_mean(b, se2, sigma_sq)

    // Store results back to Stata locals
    st_local("_tte_cal_bias", strofreal(bias, "%21x"))
    st_local("_tte_cal_sigma_sq", strofreal(sigma_sq, "%21x"))
}

real scalar _tte_cal_profile_ll(real colvector b, real colvector se2,
    real scalar sigma_sq)
{
    real colvector v, w
    real scalar bias, ll
    real scalar K

    K = rows(b)
    v = se2 :+ sigma_sq
    bias = _tte_cal_weighted_mean(b, se2, sigma_sq)
    ll = -0.5 * sum(ln(v) :+ (b :- bias) :^ 2 :/ v)
    return(ll)
}

real scalar _tte_cal_weighted_mean(real colvector b, real colvector se2,
    real scalar sigma_sq)
{
    real colvector w

    w = 1 :/ (se2 :+ sigma_sq)
    return(sum(w :* b) / sum(w))
}
end
