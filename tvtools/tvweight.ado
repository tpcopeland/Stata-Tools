*! tvweight Version 1.0.0  2025/12/29
*! Calculate inverse probability of treatment weights (IPTW) for time-varying exposures
*! Author: Tim Copeland
*! Program class: rclass (returns results in r())

/*
Basic syntax:
  tvweight exposure, covariates(varlist) [options]

Required:
  exposure            - Binary or categorical exposure variable
  covariates(varlist) - Covariates for propensity score model

Options:
  generate(name)      - Name for weight variable (default: iptw)
  model(string)       - Model type: logit (binary) or mlogit (categorical)
  stabilized          - Calculate stabilized weights
  truncate(# #)       - Truncate at lower/upper percentiles
  tvcovariates(varlist) - Time-varying covariates (requires id and time)
  id(varname)         - Person identifier for clustering
  time(varname)       - Time variable for time-varying model
  replace             - Replace existing weight variable
  denominator(name)   - Also generate propensity score variable
  nolog               - Suppress model iteration log

Output:
  Weight variable created with IPTW values
  Diagnostic output showing weight distribution
  Stored results with ESS and weight statistics

Examples:
  * Basic IPTW for binary treatment
  tvweight treatment, covariates(age sex comorbidity) generate(iptw)

  * Stabilized weights with truncation
  tvweight treatment, covariates(age sex) stabilized truncate(1 99)

  * Multinomial for 3+ category exposure
  tvweight drug_type, covariates(age sex) model(mlogit) generate(mw)

See help tvweight for complete documentation
*/

program define tvweight, rclass
    version 16.0
    set varabbrev off

    * Parse syntax
    syntax varname(numeric), COVariates(varlist numeric) ///
        [GENerate(name) MODEL(string) STABilized ///
         TRUNCate(numlist min=2 max=2) ///
         TVCovariates(varlist numeric) ID(varname) TIME(varname) ///
         REPLACE DENominator(name) noLOG]

    local exposure `varlist'

    * =========================================================================
    * VALIDATION
    * =========================================================================

    * Set defaults
    if "`generate'" == "" local generate "iptw"
    if "`model'" == "" local model "logit"

    * Validate model type
    if !inlist("`model'", "logit", "mlogit") {
        display as error "model() must be logit or mlogit"
        exit 198
    }

    * Check exposure levels
    quietly tab `exposure'
    local n_levels = r(r)

    if `n_levels' < 2 {
        display as error "exposure variable must have at least 2 levels"
        exit 198
    }

    if `n_levels' > 2 & "`model'" == "logit" {
        display as text "Note: exposure has `n_levels' levels; switching to mlogit model"
        local model "mlogit"
    }

    if `n_levels' == 2 & "`model'" == "mlogit" {
        display as text "Note: binary exposure; using logit model instead of mlogit"
        local model "logit"
    }

    * Validate truncation percentiles
    if "`truncate'" != "" {
        local trunc_lo: word 1 of `truncate'
        local trunc_hi: word 2 of `truncate'

        if `trunc_lo' < 0 | `trunc_lo' > 100 {
            display as error "truncate() lower bound must be between 0 and 100"
            exit 198
        }
        if `trunc_hi' < 0 | `trunc_hi' > 100 {
            display as error "truncate() upper bound must be between 0 and 100"
            exit 198
        }
        if `trunc_lo' >= `trunc_hi' {
            display as error "truncate() lower bound must be less than upper bound"
            exit 198
        }
    }

    * Time-varying covariates require id and time
    if "`tvcovariates'" != "" {
        if "`id'" == "" | "`time'" == "" {
            display as error "tvcovariates() requires id() and time() options"
            exit 198
        }
    }

    * Check if generate variable already exists
    capture confirm variable `generate'
    if _rc == 0 {
        if "`replace'" == "" {
            display as error "variable `generate' already exists; use replace option"
            exit 110
        }
        else {
            quietly drop `generate'
        }
    }

    * Check if denominator variable already exists
    if "`denominator'" != "" {
        capture confirm variable `denominator'
        if _rc == 0 {
            if "`replace'" == "" {
                display as error "variable `denominator' already exists; use replace option"
                exit 110
            }
            else {
                quietly drop `denominator'
            }
        }
    }

    * Count valid observations
    tempvar touse
    mark `touse'
    markout `touse' `exposure' `covariates' `tvcovariates'

    quietly count if `touse'
    local n_obs = r(N)
    if `n_obs' == 0 {
        display as error "no valid observations"
        exit 2000
    }

    * =========================================================================
    * PROPENSITY SCORE MODEL
    * =========================================================================

    display as text "{hline 70}"
    display as text "{bf:IPTW Weight Calculation}"
    display as text "{hline 70}"
    display as text ""
    display as text "Exposure variable: " as result "`exposure'"
    display as text "Number of levels:  " as result "`n_levels'"
    display as text "Model type:        " as result "`model'"
    display as text "Covariates:        " as result "`covariates'"
    if "`tvcovariates'" != "" {
        display as text "TV Covariates:     " as result "`tvcovariates'"
    }
    display as text "Observations:      " as result "`n_obs'"
    display as text ""

    * Get reference level (lowest value)
    quietly sum `exposure' if `touse'
    local ref_level = r(min)

    * Build full covariate list
    local all_covars "`covariates'"
    if "`tvcovariates'" != "" {
        local all_covars "`all_covars' `tvcovariates'"
    }

    * Fit propensity score model
    display as text "Fitting propensity score model..."

    tempvar ps

    if "`model'" == "logit" {
        * Binary logistic regression
        if "`log'" == "nolog" {
            quietly logit `exposure' `all_covars' if `touse', nolog
        }
        else {
            logit `exposure' `all_covars' if `touse'
        }

        * Predict propensity score (probability of being treated)
        quietly predict double `ps' if `touse', pr
    }
    else {
        * Multinomial logistic regression
        if "`log'" == "nolog" {
            quietly mlogit `exposure' `all_covars' if `touse', baseoutcome(`ref_level') nolog
        }
        else {
            mlogit `exposure' `all_covars' if `touse', baseoutcome(`ref_level')
        }
    }

    * =========================================================================
    * WEIGHT CALCULATION
    * =========================================================================

    display as text ""
    display as text "Calculating weights..."

    quietly {
        if "`model'" == "logit" {
            * Binary IPTW: 1/PS for treated, 1/(1-PS) for untreated
            * Treated is the NON-reference level (higher value)
            gen double `generate' = .

            * For treated (exposure = max level, not reference)
            replace `generate' = 1 / `ps' if `exposure' != `ref_level' & `touse'

            * For untreated (reference level)
            replace `generate' = 1 / (1 - `ps') if `exposure' == `ref_level' & `touse'

            * Save denominator (propensity score) if requested
            if "`denominator'" != "" {
                gen double `denominator' = `ps' if `touse'
                label variable `denominator' "Propensity score P(exposure=1|X)"
            }
        }
        else {
            * Multinomial IPTW: 1/P(A=a|X) for each category
            gen double `generate' = .

            * Get all exposure levels
            levelsof `exposure' if `touse', local(levels)

            foreach lev of local levels {
                * Predict probability of this level
                tempvar ps_`lev'
                predict double `ps_`lev'' if `touse', pr outcome(`lev')
                replace `generate' = 1 / `ps_`lev'' if `exposure' == `lev' & `touse'
            }

            * Save denominator if requested (probability of observed treatment)
            if "`denominator'" != "" {
                gen double `denominator' = .
                foreach lev of local levels {
                    replace `denominator' = `ps_`lev'' if `exposure' == `lev' & `touse'
                }
                label variable `denominator' "Propensity score P(exposure=a|X)"
            }
        }
    }

    * =========================================================================
    * STABILIZED WEIGHTS (optional)
    * =========================================================================

    if "`stabilized'" != "" {
        display as text "Calculating stabilized weights..."

        quietly {
            if "`model'" == "logit" {
                * Marginal probability of treatment
                sum `exposure' if `touse'
                local marg_prob = r(mean)

                * Stabilized weight = marginal prob / PS for treated
                * Stabilized weight = (1 - marginal prob) / (1 - PS) for untreated
                replace `generate' = `marg_prob' / `ps' if `exposure' != `ref_level' & `touse'
                replace `generate' = (1 - `marg_prob') / (1 - `ps') if `exposure' == `ref_level' & `touse'
            }
            else {
                * For multinomial: multiply by marginal probability of each level
                levelsof `exposure' if `touse', local(levels)
                foreach lev of local levels {
                    count if `exposure' == `lev' & `touse'
                    local n_lev = r(N)
                    local marg_`lev' = `n_lev' / `n_obs'
                    replace `generate' = `generate' * `marg_`lev'' if `exposure' == `lev' & `touse'
                }
            }
        }
    }

    * =========================================================================
    * TRUNCATION (optional)
    * =========================================================================

    local n_truncated = 0
    if "`truncate'" != "" {
        display as text "Truncating weights at `trunc_lo'th and `trunc_hi'th percentiles..."

        quietly {
            * Get percentile values
            _pctile `generate' if `touse', percentiles(`trunc_lo' `trunc_hi')
            local lo_val = r(r1)
            local hi_val = r(r2)

            * Count truncated
            count if `generate' < `lo_val' & `touse' & !missing(`generate')
            local n_lo = r(N)
            count if `generate' > `hi_val' & `touse' & !missing(`generate')
            local n_hi = r(N)
            local n_truncated = `n_lo' + `n_hi'

            * Truncate
            replace `generate' = `lo_val' if `generate' < `lo_val' & `touse' & !missing(`generate')
            replace `generate' = `hi_val' if `generate' > `hi_val' & `touse' & !missing(`generate')
        }

        display as text "  Truncated `n_truncated' observations (`n_lo' low, `n_hi' high)"
    }

    * =========================================================================
    * DIAGNOSTICS
    * =========================================================================

    display as text ""
    display as text "{hline 70}"
    display as text "Weight Diagnostics"
    display as text "{hline 70}"

    * Weight summary statistics
    quietly sum `generate' if `touse', detail
    local w_mean = r(mean)
    local w_sd = r(sd)
    local w_min = r(min)
    local w_max = r(max)
    local w_p1 = r(p1)
    local w_p5 = r(p5)
    local w_p25 = r(p25)
    local w_p50 = r(p50)
    local w_p75 = r(p75)
    local w_p95 = r(p95)
    local w_p99 = r(p99)

    display as text ""
    display as text "Weight distribution:"
    display as text "  Mean:     " as result %9.4f `w_mean'
    display as text "  SD:       " as result %9.4f `w_sd'
    display as text "  Min:      " as result %9.4f `w_min'
    display as text "  Max:      " as result %9.4f `w_max'
    display as text ""
    display as text "Percentiles:"
    display as text "  1%:       " as result %9.4f `w_p1'
    display as text "  5%:       " as result %9.4f `w_p5'
    display as text "  25%:      " as result %9.4f `w_p25'
    display as text "  50%:      " as result %9.4f `w_p50'
    display as text "  75%:      " as result %9.4f `w_p75'
    display as text "  95%:      " as result %9.4f `w_p95'
    display as text "  99%:      " as result %9.4f `w_p99'

    * Effective sample size calculation
    quietly {
        * ESS = (sum of weights)^2 / sum of squared weights
        sum `generate' if `touse'
        local sum_w = r(sum)

        tempvar w2
        gen double `w2' = `generate'^2 if `touse'
        sum `w2' if `touse'
        local sum_w2 = r(sum)
        drop `w2'
    }

    local ess = (`sum_w'^2) / `sum_w2'
    local ess_pct = 100 * `ess' / `n_obs'

    display as text ""
    display as text "Effective sample size:"
    display as text "  ESS:      " as result %9.1f `ess' as text " (of `n_obs' observations)"
    display as text "  ESS %:    " as result %9.1f `ess_pct' "%"

    * Warning for extreme weights
    if `w_max' / `w_min' > 100 {
        display as text ""
        display as error "Warning: Weight ratio (max/min) > 100. Consider truncation."
    }

    * Weight distribution by exposure group
    display as text ""
    display as text "Weights by exposure group:"
    display as text "{hline 50}"

    if "`model'" == "logit" {
        quietly sum `generate' if `exposure' == `ref_level' & `touse'
        local n0 = r(N)
        local mean0 = r(mean)
        local sd0 = r(sd)

        quietly sum `generate' if `exposure' != `ref_level' & `touse'
        local n1 = r(N)
        local mean1 = r(mean)
        local sd1 = r(sd)

        display as text "  Reference (`exposure'=`ref_level'): N=" as result `n0' ///
            as text ", Mean=" as result %7.3f `mean0' as text ", SD=" as result %7.3f `sd0'
        display as text "  Exposed (`exposure'!=`ref_level'):  N=" as result `n1' ///
            as text ", Mean=" as result %7.3f `mean1' as text ", SD=" as result %7.3f `sd1'
    }
    else {
        levelsof `exposure' if `touse', local(levels)
        foreach lev of local levels {
            quietly sum `generate' if `exposure' == `lev' & `touse'
            local n_lev = r(N)
            local mean_lev = r(mean)
            local sd_lev = r(sd)
            display as text "  Level `lev': N=" as result `n_lev' ///
                as text ", Mean=" as result %7.3f `mean_lev' as text ", SD=" as result %7.3f `sd_lev'
        }
    }

    display as text "{hline 70}"

    * Add variable label
    if "`stabilized'" != "" {
        label variable `generate' "Stabilized IPTW for `exposure'"
    }
    else {
        label variable `generate' "IPTW for `exposure'"
    }

    display as text ""
    display as result "Weight variable `generate' created successfully."
    display as text "{hline 70}"

    * =========================================================================
    * RETURN VALUES
    * =========================================================================

    return scalar N = `n_obs'
    return scalar n_levels = `n_levels'
    return scalar ess = `ess'
    return scalar ess_pct = `ess_pct'
    return scalar w_mean = `w_mean'
    return scalar w_sd = `w_sd'
    return scalar w_min = `w_min'
    return scalar w_max = `w_max'
    return scalar w_p1 = `w_p1'
    return scalar w_p5 = `w_p5'
    return scalar w_p25 = `w_p25'
    return scalar w_p50 = `w_p50'
    return scalar w_p75 = `w_p75'
    return scalar w_p95 = `w_p95'
    return scalar w_p99 = `w_p99'

    if "`truncate'" != "" {
        return scalar n_truncated = `n_truncated'
        return scalar trunc_lo = `trunc_lo'
        return scalar trunc_hi = `trunc_hi'
    }

    return local exposure "`exposure'"
    return local covariates "`covariates'"
    return local model "`model'"
    return local generate "`generate'"
    if "`stabilized'" != "" {
        return local stabilized "stabilized"
    }
    if "`denominator'" != "" {
        return local denominator "`denominator'"
    }
end
