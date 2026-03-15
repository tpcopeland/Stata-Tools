*! aft_split Version 1.1.0  2026/03/15
*! Piecewise AFT: episode splitting and per-interval fitting
*! Author: Timothy P Copeland
*! Department of Clinical Neuroscience, Karolinska Institutet
*! Program class: rclass (returns results in r())

/*
Basic syntax:
  aft_split varlist [if] [in] , CUTpoints(numlist) [options]

Description:
  Splits survival data into time intervals using stsplit, fits separate
  AFT models in each interval, and stores per-interval results in dataset
  characteristics. Designed for time-varying covariate effects.

See help aft_split for complete documentation
*/

program define aft_split, rclass
    version 16.0
    local _vaset = c(varabbrev)
    set varabbrev off
    set more off

    * =========================================================================
    * SYNTAX PARSING
    * =========================================================================
    syntax varlist(numeric fv) [if] [in] , ///
        [CUTpoints(numlist ascending >0) QUANTiles(integer 0) ///
         DISTribution(string) ///
         STRata(varname) FRAILty(string) SHAred(varname) ///
         vce(passthru) ANCovariate(varlist fv) ///
         Level(cilevel) noLOG noTABle SAVing(string)]

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

    * cutpoints and quantiles are mutually exclusive; at least one required
    if "`cutpoints'" == "" & `quantiles' == 0 {
        display as error "must specify {bf:cutpoints()} or {bf:quantiles()}"
        display as error ""
        display as error "Examples:"
        display as error "  {cmd:aft_split x1 x2, cutpoints(6 12 24)}"
        display as error "  {cmd:aft_split x1 x2, quantiles(3)}"
        exit 198
    }
    if "`cutpoints'" != "" & `quantiles' > 0 {
        display as error "cutpoints() and quantiles() are mutually exclusive"
        exit 198
    }

    * Validate quantiles range
    if `quantiles' > 0 & `quantiles' < 2 {
        display as error "quantiles() must be >= 2"
        exit 198
    }

    * Resolve distribution
    if "`distribution'" != "" {
        local dist = lower("`distribution'")
        if !inlist("`dist'", "exponential", "weibull", "lognormal", "loglogistic", "ggamma") {
            display as error "unknown distribution: `dist'"
            display as error "valid: exponential weibull lognormal loglogistic ggamma"
            exit 198
        }
    }
    else {
        * Try characteristics
        local dist : char _dta[_aft_best_dist]
        if "`dist'" == "" {
            local dist : char _dta[_aft_fit_dist]
        }
        if "`dist'" == "" {
            display as error "no distribution specified"
            display as error ""
            display as error "Either run {bf:aft_select} first, or specify"
            display as error "  {cmd:aft_split `varlist', cutpoints(...) distribution(weibull)}"
            exit 198
        }
    }

    * Validate frailty
    if "`frailty'" != "" {
        if !inlist("`frailty'", "gamma", "invgaussian") {
            display as error "frailty() must be gamma or invgaussian"
            exit 198
        }
    }

    * =========================================================================
    * COMPUTE QUANTILE-BASED CUTPOINTS
    * =========================================================================

    if `quantiles' > 0 {
        * Compute quantile cutpoints from failure time distribution
        local cutpoints ""
        forvalues q = 1/`=`quantiles'-1' {
            local pct = 100 * `q' / `quantiles'
            quietly centile _t if `touse' & _d == 1, centile(`pct')
            local cp = r(c_1)
            if !missing(`cp') & `cp' > 0 {
                local cutpoints "`cutpoints' `cp'"
            }
        }
        local cutpoints = strtrim("`cutpoints'")
        if "`cutpoints'" == "" {
            display as error "could not compute quantile cutpoints"
            exit 198
        }
    }

    * =========================================================================
    * BUILD STREG OPTIONS
    * =========================================================================

    local dist_opts "distribution(`dist')"
    if inlist("`dist'", "exponential", "weibull") {
        local dist_opts "`dist_opts' time"
    }

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
    _aft_display_header "aft_split" "Piecewise AFT: Episode Splitting"

    display as text "Observations:     " as result %10.0fc `N'
    display as text "Failures:         " as result %10.0fc `n_fail'
    display as text "Distribution:     " as result "`dist'"
    display as text "Covariates:       " as result "`varlist'"
    display as text "Cutpoints:        " as result "`cutpoints'"
    display as text ""

    * =========================================================================
    * EPISODE SPLITTING AND PER-INTERVAL FITTING
    * =========================================================================

    * Count pieces
    local n_pieces : word count `cutpoints'
    local ++n_pieces

    * Build interval boundaries list (0, cutpoints, .)
    local bounds "0 `cutpoints'"

    * Build interval labels
    local labels ""
    local prev = 0
    local piece = 0
    foreach cp of local cutpoints {
        local ++piece
        local labels "`labels' `prev'-`cp'"
        local prev = `cp'
    }
    local ++piece
    local labels "`labels' `prev'+"
    local labels = strtrim("`labels'")

    * Count variables for matrix dimensions
    local n_vars : word count `varlist'

    * Initialize results matrices
    tempname coef_mat se_mat fit_mat
    matrix `coef_mat' = J(`n_vars', `n_pieces', .)
    matrix `se_mat' = J(`n_vars', `n_pieces', .)
    matrix `fit_mat' = J(`n_pieces', 5, .)

    * Column/row names
    local col_names ""
    forvalues k = 1/`n_pieces' {
        local lab : word `k' of `labels'
        local col_names "`col_names' interval_`k'"
    }

    * Get variable names for row names (strip fv operators)
    local var_names ""
    foreach v of local varlist {
        * Strip factor variable operators (i., c., etc.)
        local vclean = regexr("`v'", "^[icob]+\.", "")
        local var_names "`var_names' `vclean'"
    }

    matrix colnames `coef_mat' = `col_names'
    matrix rownames `coef_mat' = `var_names'
    matrix colnames `se_mat' = `col_names'
    matrix rownames `se_mat' = `var_names'
    matrix colnames `fit_mat' = N n_fail ll AIC BIC
    matrix rownames `fit_mat' = `col_names'

    * Preserve data for splitting
    preserve

    * stsplit requires an id() variable in stset; create one if missing
    local st_id : char _dta[st_id]
    if "`st_id'" == "" {
        tempvar _aft_id
        quietly gen long `_aft_id' = _n
        quietly streset, id(`_aft_id')
    }

    * Split episodes at cutpoints
    display as text "Splitting episodes at cutpoints: `cutpoints'"
    quietly stsplit _aft_interval, at(`cutpoints')
    display as result "  Episodes created successfully"
    display as text ""

    * Get the actual cutpoint values for interval matching
    * stsplit creates _aft_interval with values = left endpoint of each interval
    * Interval 1: _aft_interval == 0
    * Interval k: _aft_interval == cutpoint_{k-1}

    local n_converged = 0
    local n_skipped = 0

    local prev = 0
    local k = 0
    foreach cp of local cutpoints {
        local ++k
        local lab : word `k' of `labels'

        display as text "Interval `k' (`lab'): " _continue

        * Count observations and failures in this interval
        quietly count if _aft_interval == `prev' & `touse'
        local n_k = r(N)
        quietly count if _aft_interval == `prev' & _d == 1 & `touse'
        local nf_k = r(N)

        if `nf_k' < 2 {
            display as error "skipped (< 2 failures)"
            local ++n_skipped
            matrix `fit_mat'[`k', 1] = `n_k'
            matrix `fit_mat'[`k', 2] = `nf_k'
            local prev = `cp'
            continue
        }

        * Fit streg for this interval
        capture noisily quietly streg `varlist' ///
            if _aft_interval == `prev' & `touse', ///
            `dist_opts' `streg_opts'

        if _rc == 0 {
            local ++n_converged
            local ll_k = e(ll)
            local aic_k = -2 * e(ll) + 2 * e(rank)
            local bic_k = -2 * e(ll) + e(rank) * ln(e(N))

            matrix `fit_mat'[`k', 1] = e(N)
            matrix `fit_mat'[`k', 2] = `nf_k'
            matrix `fit_mat'[`k', 3] = `ll_k'
            matrix `fit_mat'[`k', 4] = `aic_k'
            matrix `fit_mat'[`k', 5] = `bic_k'

            * Extract coefficients and SEs
            tempname b_k V_k
            matrix `b_k' = e(b)
            matrix `V_k' = e(V)

            local j = 0
            foreach v of local varlist {
                local ++j
                capture local coef_kj = `b_k'[1, `j']
                if _rc == 0 {
                    matrix `coef_mat'[`j', `k'] = `coef_kj'
                    local se_kj = sqrt(`V_k'[`j', `j'])
                    matrix `se_mat'[`j', `k'] = `se_kj'
                }
            }

            display as result "converged" ///
                as text " (N=" as result `n_k' ///
                as text ", failures=" as result `nf_k' ///
                as text ", ll=" as result %8.2f `ll_k' as text ")"
        }
        else {
            display as error "failed to converge"
            local ++n_skipped
            matrix `fit_mat'[`k', 1] = `n_k'
            matrix `fit_mat'[`k', 2] = `nf_k'
        }

        local prev = `cp'
    }

    * Last interval (beyond last cutpoint)
    local ++k
    local lab : word `k' of `labels'
    local last_cp : word `=`k'-1' of `cutpoints'

    display as text "Interval `k' (`lab'): " _continue

    quietly count if _aft_interval == `last_cp' & `touse'
    local n_k = r(N)
    quietly count if _aft_interval == `last_cp' & _d == 1 & `touse'
    local nf_k = r(N)

    if `nf_k' < 2 {
        display as error "skipped (< 2 failures)"
        local ++n_skipped
        matrix `fit_mat'[`k', 1] = `n_k'
        matrix `fit_mat'[`k', 2] = `nf_k'
    }
    else {
        capture noisily quietly streg `varlist' ///
            if _aft_interval == `last_cp' & `touse', ///
            `dist_opts' `streg_opts'

        if _rc == 0 {
            local ++n_converged
            local ll_k = e(ll)
            local aic_k = -2 * e(ll) + 2 * e(rank)
            local bic_k = -2 * e(ll) + e(rank) * ln(e(N))

            matrix `fit_mat'[`k', 1] = e(N)
            matrix `fit_mat'[`k', 2] = `nf_k'
            matrix `fit_mat'[`k', 3] = `ll_k'
            matrix `fit_mat'[`k', 4] = `aic_k'
            matrix `fit_mat'[`k', 5] = `bic_k'

            tempname b_k V_k
            matrix `b_k' = e(b)
            matrix `V_k' = e(V)

            local j = 0
            foreach v of local varlist {
                local ++j
                capture local coef_kj = `b_k'[1, `j']
                if _rc == 0 {
                    matrix `coef_mat'[`j', `k'] = `coef_kj'
                    local se_kj = sqrt(`V_k'[`j', `j'])
                    matrix `se_mat'[`j', `k'] = `se_kj'
                }
            }

            display as result "converged" ///
                as text " (N=" as result `n_k' ///
                as text ", failures=" as result `nf_k' ///
                as text ", ll=" as result %8.2f `ll_k' as text ")"
        }
        else {
            display as error "failed to converge"
            local ++n_skipped
            matrix `fit_mat'[`k', 1] = `n_k'
            matrix `fit_mat'[`k', 2] = `nf_k'
        }
    }

    * Restore original data
    restore

    * =========================================================================
    * DISPLAY RESULTS TABLE
    * =========================================================================

    if "`table'" != "notable" {
        display as text ""
        display as text "{hline 70}"
        display as text "{bf:Piecewise AFT Results: Time Ratios by Interval}"
        display as text "{hline 70}"
        display as text ""

        * Header row
        display as text %16s "Variable" _continue
        forvalues k = 1/`n_pieces' {
            local lab : word `k' of `labels'
            display as text %12s "`lab'" _continue
        }
        display as text ""
        display as text "{hline `=16 + `n_pieces' * 12'}"

        * Data rows: show time ratios (exp(coef))
        local j = 0
        foreach v of local varlist {
            local ++j
            local vname : word `j' of `var_names'
            display as text %16s "`vname'" _continue
            forvalues k = 1/`n_pieces' {
                local c = `coef_mat'[`j', `k']
                if !missing(`c') {
                    local tr = exp(`c')
                    display as result %12.4f `tr' _continue
                }
                else {
                    display as text %12s "." _continue
                }
            }
            display as text ""

            * SE row
            display as text %16s "" _continue
            forvalues k = 1/`n_pieces' {
                local s = `se_mat'[`j', `k']
                if !missing(`s') {
                    display as text "  (" %7.4f `s' ")" _continue
                }
                else {
                    display as text %12s "" _continue
                }
            }
            display as text ""
        }

        display as text "{hline `=16 + `n_pieces' * 12'}"

        * Fit statistics rows
        display as text %16s "N" _continue
        forvalues k = 1/`n_pieces' {
            local n_k = `fit_mat'[`k', 1]
            if !missing(`n_k') {
                display as result %12.0fc `n_k' _continue
            }
            else {
                display as text %12s "." _continue
            }
        }
        display as text ""

        display as text %16s "Failures" _continue
        forvalues k = 1/`n_pieces' {
            local nf_k = `fit_mat'[`k', 2]
            if !missing(`nf_k') {
                display as result %12.0fc `nf_k' _continue
            }
            else {
                display as text %12s "." _continue
            }
        }
        display as text ""

        display as text %16s "AIC" _continue
        forvalues k = 1/`n_pieces' {
            local a_k = `fit_mat'[`k', 4]
            if !missing(`a_k') {
                display as result %12.2f `a_k' _continue
            }
            else {
                display as text %12s "." _continue
            }
        }
        display as text ""

        display as text "{hline `=16 + `n_pieces' * 12'}"
    }

    * =========================================================================
    * STORE CHARACTERISTICS
    * =========================================================================

    char _dta[_aft_piecewise] "1"
    char _dta[_aft_pw_n_pieces] "`n_pieces'"
    char _dta[_aft_pw_cutpoints] "`cutpoints'"
    char _dta[_aft_pw_dist] "`dist'"
    char _dta[_aft_pw_varlist] "`varlist'"

    * Per-interval characteristics
    local j = 0
    foreach v of local varlist {
        local ++j
        forvalues k = 1/`n_pieces' {
            local c = `coef_mat'[`j', `k']
            local s = `se_mat'[`j', `k']
            char _dta[_aft_pw_coef_`k'_`j'] "`c'"
            char _dta[_aft_pw_se_`k'_`j'] "`s'"
        }
    }

    forvalues k = 1/`n_pieces' {
        local ll_k = `fit_mat'[`k', 3]
        local n_k = `fit_mat'[`k', 1]
        local nf_k = `fit_mat'[`k', 2]
        char _dta[_aft_pw_ll_`k'] "`ll_k'"
        char _dta[_aft_pw_n_`k'] "`n_k'"
        char _dta[_aft_pw_nfail_`k'] "`nf_k'"
    }

    * =========================================================================
    * DISPLAY SUMMARY
    * =========================================================================

    display as text ""
    display as text "Intervals:  " as result "`n_pieces'"
    display as text "Converged:  " as result "`n_converged'"
    if `n_skipped' > 0 {
        display as text "Skipped:    " as result "`n_skipped'" ///
            as text " (insufficient failures or convergence failure)"
    }

    display as text ""
    display as text "Next step: {cmd:aft_pool} to compute pooled estimates"
    display as text "{hline 70}"

    * =========================================================================
    * SAVE RESULTS
    * =========================================================================

    if "`saving'" != "" {
        preserve
        clear
        local n_rows = `n_vars' * `n_pieces'
        quietly set obs `n_rows'
        quietly gen str32 variable = ""
        quietly gen int interval = .
        quietly gen str20 interval_label = ""
        quietly gen double coef = .
        quietly gen double se = .
        quietly gen double tr = .

        local row = 0
        local j = 0
        foreach v of local varlist {
            local ++j
            local vname : word `j' of `var_names'
            forvalues k = 1/`n_pieces' {
                local ++row
                local lab : word `k' of `labels'
                quietly replace variable = "`vname'" in `row'
                quietly replace interval = `k' in `row'
                quietly replace interval_label = "`lab'" in `row'
                local c = `coef_mat'[`j', `k']
                local s = `se_mat'[`j', `k']
                quietly replace coef = `c' in `row'
                quietly replace se = `s' in `row'
                if !missing(`c') {
                    quietly replace tr = exp(`c') in `row'
                }
            }
        }

        quietly save `saving'
        restore
    }

    * =========================================================================
    * RETURN RESULTS
    * =========================================================================

    return scalar n_pieces = `n_pieces'
    return scalar n_converged = `n_converged'
    return scalar n_skipped = `n_skipped'
    return local cutpoints "`cutpoints'"
    return local dist "`dist'"
    return local varlist "`varlist'"
    return local labels "`labels'"
    return matrix coefs = `coef_mat'
    return matrix ses = `se_mat'
    return matrix table = `fit_mat'

    set varabbrev `_vaset'
end
