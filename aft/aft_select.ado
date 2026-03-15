*! aft_select Version 1.0.0  2026/03/14
*! AFT distribution selection and comparison
*! Author: Timothy P Copeland
*! Department of Clinical Neuroscience, Karolinska Institutet
*! Program class: rclass (returns results in r())

/*
Basic syntax:
  aft_select [varlist] [if] [in] [, options]

Description:
  Fits 5 AFT distributions (exponential, Weibull, lognormal,
  log-logistic, generalized gamma), computes AIC/BIC, runs LR
  tests for nested models, and recommends the best-fitting
  distribution. Stores selection in dataset characteristics for
  downstream use by aft_fit and aft_diagnose.

See help aft_select for complete documentation
*/

program define aft_select, rclass
    version 16.0
    local _vaset = c(varabbrev)
    set varabbrev off
    set more off

    * =========================================================================
    * SYNTAX PARSING
    * =========================================================================
    syntax [varlist(numeric fv default=none)] [if] [in] , ///
        [DISTributions(string) EXClude(string) ///
         STRata(varname) FRAILty(string) SHAred(varname) ///
         vce(passthru) ANCovariate(varlist fv) ///
         Level(cilevel) noLOG noTABle noRECommend ///
         SAVing(string)]

    * =========================================================================
    * CHECK PREREQUISITES
    * =========================================================================
    _aft_check_stset

    marksample touse
    quietly count if `touse'
    if r(N) == 0 {
        display as error "no observations"
        exit 2000
    }
    local N = r(N)

    * Count failures
    quietly count if `touse' & _d == 1
    local n_fail = r(N)

    if `n_fail' == 0 {
        display as error "no failures in sample"
        exit 2000
    }

    * =========================================================================
    * VALIDATE INPUTS
    * =========================================================================

    * Default distributions
    local all_dists "exponential weibull lognormal loglogistic ggamma"

    if "`distributions'" != "" {
        * User-specified subset
        local dist_list ""
        local distributions = lower("`distributions'")
        foreach d of local distributions {
            local matched = 0
            foreach ad of local all_dists {
                if "`d'" == "`ad'" {
                    local dist_list "`dist_list' `d'"
                    local matched = 1
                }
            }
            if `matched' == 0 {
                display as error "unknown distribution: `d'"
                display as error "valid distributions: `all_dists'"
                exit 198
            }
        }
        local dist_list = strtrim("`dist_list'")
    }
    else {
        local dist_list "`all_dists'"
    }

    * Apply exclusions
    if "`exclude'" != "" {
        local exclude = lower("`exclude'")
        foreach ex of local exclude {
            local dist_list : list dist_list - ex
        }
    }

    local n_dists : word count `dist_list'
    if `n_dists' == 0 {
        display as error "no distributions to compare after exclusions"
        exit 198
    }

    * Validate frailty
    if "`frailty'" != "" {
        if !inlist("`frailty'", "gamma", "invgaussian") {
            display as error "frailty() must be gamma or invgaussian"
            exit 198
        }
    }

    * =========================================================================
    * BUILD STREG OPTIONS
    * =========================================================================

    local streg_opts ""
    if "`strata'" != "" local streg_opts "`streg_opts' strata(`strata')"
    if "`frailty'" != "" local streg_opts "`streg_opts' frailty(`frailty')"
    if "`shared'" != "" local streg_opts "`streg_opts' shared(`shared')"
    if "`vce'" != "" local streg_opts "`streg_opts' `vce'"
    if "`ancovariate'" != "" local streg_opts "`streg_opts' ancillary(`ancovariate')"
    if "`level'" != "" local streg_opts "`streg_opts' level(`level')"
    if "`log'" == "nolog" local streg_opts "`streg_opts' nolog"

    * =========================================================================
    * DISPLAY HEADER
    * =========================================================================
    _aft_display_header "aft_select" "AFT Distribution Selection"

    display as text "Observations:     " as result %10.0fc `N'
    display as text "Failures:         " as result %10.0fc `n_fail'
    if "`varlist'" != "" {
        display as text "Covariates:       " as result "`varlist'"
    }
    display as text "Distributions:    " as result "`dist_list'"
    display as text ""

    * =========================================================================
    * FIT EACH DISTRIBUTION
    * =========================================================================

    * Initialize results storage
    local n_converged = 0
    local best_aic = .
    local best_bic = .
    local best_dist ""

    tempname results_mat
    matrix `results_mat' = J(`n_dists', 5, .)
    local row_names ""

    local i = 0
    foreach dist of local dist_list {
        local ++i

        * Distribution-specific options
        * Note: do NOT pass time option here. The time option only changes
        * coefficient display (PH vs AFT), not the log-likelihood. Omitting
        * time keeps all estimators compatible for lrtest. aft_fit handles
        * the time option for display purposes.
        local dist_opts "distribution(`dist')"

        * Fit model
        local conv_`dist' = 0
        local ll_`dist' = .
        local aic_`dist' = .
        local bic_`dist' = .
        local k_`dist' = .

        display as text "Fitting `dist'..." _continue

        capture noisily quietly streg `varlist' `if' `in', ///
            `dist_opts' `streg_opts'

        if _rc == 0 {
            local conv_`dist' = 1
            local ++n_converged

            local ll_`dist' = e(ll)
            local k_`dist' = e(rank)

            * AIC = -2*ll + 2*k
            local aic_`dist' = -2 * e(ll) + 2 * e(rank)
            * BIC = -2*ll + k*ln(N)
            local bic_`dist' = -2 * e(ll) + e(rank) * ln(e(N))

            * Store estimates for LR tests
            estimates store _aft_`dist'

            display as result " converged (ll = " %10.2f `ll_`dist'' ")"

            * Track best AIC
            if `aic_`dist'' < `best_aic' {
                local best_aic = `aic_`dist''
                local best_bic = `bic_`dist''
                local best_dist "`dist'"
            }
        }
        else {
            display as error " failed to converge"
        }

        * Fill matrix row
        matrix `results_mat'[`i', 1] = `ll_`dist''
        matrix `results_mat'[`i', 2] = `k_`dist''
        matrix `results_mat'[`i', 3] = `aic_`dist''
        matrix `results_mat'[`i', 4] = `bic_`dist''
        matrix `results_mat'[`i', 5] = `conv_`dist''

        local row_names "`row_names' `dist'"
    }

    matrix colnames `results_mat' = ll k AIC BIC converged
    matrix rownames `results_mat' = `row_names'

    * =========================================================================
    * LR TESTS (nested models within generalized gamma)
    * =========================================================================

    local lr_weibull_p = .
    local lr_lognormal_p = .
    local lr_exponential_p = .

    * conv_ggamma may not be defined if ggamma excluded
    local _has_gg = 0
    capture local _has_gg = `conv_ggamma'

    if `_has_gg' == 1 {
        display as text ""
        display as text "{bf:Likelihood ratio tests} (vs. generalized gamma):"
        display as text ""

        * Weibull nested in generalized gamma
        * force required: streg sets different e(cmd) per distribution
        local _cw = 0
        capture local _cw = `conv_weibull'
        if `_cw' == 1 {
            quietly lrtest _aft_ggamma _aft_weibull, force
            local lr_weibull_p = r(p)
            display as text "  Weibull vs gen. gamma:     " ///
                as text "chi2(" as result r(df) as text ") = " ///
                as result %8.2f r(chi2) ///
                as text "  p = " as result %6.4f r(p) ///
                _continue
            if r(p) >= 0.05 {
                display as text "  (Weibull adequate)"
            }
            else {
                display as text "  (reject Weibull)"
            }
        }

        * Lognormal nested in generalized gamma
        local _cl = 0
        capture local _cl = `conv_lognormal'
        if `_cl' == 1 {
            quietly lrtest _aft_ggamma _aft_lognormal, force
            local lr_lognormal_p = r(p)
            display as text "  Lognormal vs gen. gamma:   " ///
                as text "chi2(" as result r(df) as text ") = " ///
                as result %8.2f r(chi2) ///
                as text "  p = " as result %6.4f r(p) ///
                _continue
            if r(p) >= 0.05 {
                display as text "  (lognormal adequate)"
            }
            else {
                display as text "  (reject lognormal)"
            }
        }

        * Exponential nested in generalized gamma
        local _ce = 0
        capture local _ce = `conv_exponential'
        if `_ce' == 1 {
            quietly lrtest _aft_ggamma _aft_exponential, force
            local lr_exponential_p = r(p)
            display as text "  Exponential vs gen. gamma: " ///
                as text "chi2(" as result r(df) as text ") = " ///
                as result %8.2f r(chi2) ///
                as text "  p = " as result %6.4f r(p) ///
                _continue
            if r(p) >= 0.05 {
                display as text "  (exponential adequate)"
            }
            else {
                display as text "  (reject exponential)"
            }
        }
    }

    * Note about log-logistic
    local has_llogistic : list posof "loglogistic" in dist_list
    if `has_llogistic' > 0 & `n_dists' > 1 {
        display as text ""
        display as text "  {it:Note: log-logistic is not nested in the generalized gamma family;}"
        display as text "  {it:comparison is via AIC/BIC only.}"
    }

    * =========================================================================
    * DISPLAY COMPARISON TABLE
    * =========================================================================

    if "`table'" != "notable" {
        display as text ""
        display as text "{hline 70}"
        display as text "{bf:Distribution Comparison}"
        display as text "{hline 70}"
        display as text ""

        * Table header
        display as text %16s "Distribution" "  " ///
            %10s "Log-lik" "  " ///
            %4s "k" "  " ///
            %10s "AIC" "  " ///
            %10s "BIC" "  " ///
            %6s "dAIC"
        display as text "{hline 70}"

        * Table rows
        local i = 0
        foreach dist of local dist_list {
            local ++i
            if `conv_`dist'' == 1 {
                local delta_aic = `aic_`dist'' - `best_aic'
                local marker ""
                if "`dist'" == "`best_dist'" local marker " *"

                display as text %16s "`dist'" "  " ///
                    as result %10.2f `ll_`dist'' "  " ///
                    as result %4.0f `k_`dist'' "  " ///
                    as result %10.2f `aic_`dist'' "  " ///
                    as result %10.2f `bic_`dist'' "  " ///
                    as result %6.1f `delta_aic' ///
                    as text "`marker'"
            }
            else {
                display as text %16s "`dist'" "  " ///
                    as error %10s "(failed)" "  " ///
                    as text %4s "" "  " ///
                    as text %10s "" "  " ///
                    as text %10s "" "  " ///
                    as text %6s ""
            }
        }

        display as text "{hline 70}"
        display as text "  * = best fitting distribution by AIC"
    }

    * =========================================================================
    * RECOMMENDATION
    * =========================================================================

    if "`recommend'" != "norecommend" & "`best_dist'" != "" {
        display as text ""
        display as text "{bf:Recommendation:} " ///
            as result "`best_dist'" ///
            as text " (AIC = " as result %10.2f `best_aic' as text ")"
        display as text ""
        display as text "Next step: " ///
            as result "{cmd:aft_fit `varlist'}" ///
            as text " to fit the `best_dist' AFT model"
    }

    display as text "{hline 70}"

    * =========================================================================
    * STORE CHARACTERISTICS
    * =========================================================================

    char _dta[_aft_selected] "1"
    char _dta[_aft_best_dist] "`best_dist'"
    char _dta[_aft_varlist] "`varlist'"
    char _dta[_aft_n_obs] "`N'"
    char _dta[_aft_n_fail] "`n_fail'"
    char _dta[_aft_strata] "`strata'"
    char _dta[_aft_frailty] "`frailty'"
    char _dta[_aft_shared] "`shared'"
    char _dta[_aft_vce] "`vce'"
    char _dta[_aft_ancov] "`ancovariate'"

    * Per-distribution characteristics
    foreach dist of local dist_list {
        char _dta[_aft_aic_`dist'] "`aic_`dist''"
        char _dta[_aft_bic_`dist'] "`bic_`dist''"
        char _dta[_aft_ll_`dist'] "`ll_`dist''"
        char _dta[_aft_conv_`dist'] "`conv_`dist''"
    }

    * =========================================================================
    * SAVE RESULTS TO FILE
    * =========================================================================

    if "`saving'" != "" {
        preserve
        clear
        local n_rows : word count `dist_list'
        quietly set obs `n_rows'
        quietly gen str20 distribution = ""
        quietly gen double ll = .
        quietly gen double k = .
        quietly gen double aic = .
        quietly gen double bic = .
        quietly gen byte converged = .

        local i = 0
        foreach dist of local dist_list {
            local ++i
            quietly replace distribution = "`dist'" in `i'
            quietly replace ll = `ll_`dist'' in `i'
            quietly replace k = `k_`dist'' in `i'
            quietly replace aic = `aic_`dist'' in `i'
            quietly replace bic = `bic_`dist'' in `i'
            quietly replace converged = `conv_`dist'' in `i'
        }

        quietly save `saving'
        restore
    }

    * =========================================================================
    * CLEAN UP STORED ESTIMATES
    * =========================================================================

    foreach dist of local dist_list {
        if `conv_`dist'' == 1 {
            capture estimates drop _aft_`dist'
        }
    }

    * =========================================================================
    * RETURN RESULTS
    * =========================================================================

    return local best_dist "`best_dist'"
    return scalar best_aic = `best_aic'
    return scalar best_bic = `best_bic'
    return scalar n_converged = `n_converged'
    return scalar n_dists = `n_dists'
    return scalar N = `N'
    return scalar n_fail = `n_fail'
    return matrix table = `results_mat'
    return scalar lr_weibull_p = `lr_weibull_p'
    return scalar lr_lognormal_p = `lr_lognormal_p'
    return scalar lr_exponential_p = `lr_exponential_p'

    set varabbrev `_vaset'
end
