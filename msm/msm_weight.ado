*! msm_weight Version 1.2.2  2026/07/02
*! Inverse probability of treatment weights for marginal structural models
*! Author: Timothy P Copeland
*! Department of Clinical Neuroscience, Karolinska Institutet
*! Program class: rclass (returns results in r())

/*
Basic syntax:
  msm_weight [, treat_d_cov(varlist) options]

Description:
  Calculates stabilized inverse probability of treatment weights (IPTW)
  and optionally inverse probability of censoring weights (IPCW) for
  marginal structural model estimation.

  For each person-period, fits logistic models for treatment:
    Denominator: P(A_t | A_{t-1}, L_t, V)  (full history + confounders)
    Numerator:   P(A_t | A_{t-1}, V)        (baseline only, for stability)

  Period-specific weight ratios are accumulated via cumulative product
  within individuals using log-sum for numerical stability.

Options:
  treat_d_cov(varlist)   - Covariates for treatment denominator model
  treat_n_cov(varlist)   - Covariates for treatment numerator model (stabilized)
  censor_d_cov(varlist)  - Covariates for censoring denominator model
  censor_n_cov(varlist)  - Covariates for censoring numerator model
  truncate(# [#])        - Truncate at percentiles (e.g., truncate(1) or truncate(1 99))
  preview                - Resolve and display model specs without fitting
  fitfailure(policy)     - Model-failure policy: error (default) or marginal
  replace                - Replace existing weight variables
  nolog                  - Suppress model iteration log

See help msm_weight for complete documentation
*/

program define msm_weight, rclass
    version 16.0
    local _varabbrev = c(varabbrev)
    local _more = c(more)
    set varabbrev off
    set more off

    capture noisily {

    * =========================================================================
    * SYNTAX PARSING
    * =========================================================================

    syntax , [TREAT_d_cov(varlist numeric) ///
         TREAT_n_cov(varlist numeric) ///
         CENsor_d_cov(varlist numeric) CENsor_n_cov(varlist numeric) ///
         TRUncate(numlist min=1 max=2) ///
         FITFailure(string) ///
         PREVIEW REPLACE noLOG]

    * =========================================================================
    * CHECK PREREQUISITES
    * =========================================================================

    _msm_check_prepared
    _msm_get_settings

    local id         "`_msm_id'"
    local period     "`_msm_period'"
    local treatment  "`_msm_treatment'"
    local outcome    "`_msm_outcome'"
    local censor     "`_msm_censor'"
    local prepared_treat_d_cov "`_msm_covariates' `_msm_bl_covs'"
    local prepared_treat_d_cov : list retokenize prepared_treat_d_cov
    local prepared_treat_d_cov_uniq ""
    foreach var of local prepared_treat_d_cov {
        if !`: list var in prepared_treat_d_cov_uniq' {
            local prepared_treat_d_cov_uniq "`prepared_treat_d_cov_uniq' `var'"
        }
    }
    local prepared_treat_d_cov : list retokenize prepared_treat_d_cov_uniq

    * =========================================================================
    * VALIDATE OPTIONS
    * =========================================================================

    local preview_flag "0"
    if "`preview'" != "" local preview_flag "1"

    local treat_d_cov_source "explicit"
    if "`treat_d_cov'" == "" {
        if "`prepared_treat_d_cov'" == "" {
            display as error ///
                "treat_d_cov() is required unless msm_prepare stored covariates() or baseline_covariates()"
            exit 198
        }
        local treat_d_cov "`prepared_treat_d_cov'"
        local treat_d_cov_source "prepared"
        foreach var of local treat_d_cov {
            capture confirm numeric variable `var'
            if _rc {
                display as error ///
                    "prepared treatment denominator covariate `var' is not available as a numeric variable"
                exit 198
            }
        }
    }

    * Validate truncation
    local truncate_original "`truncate'"
    local truncate_source ""
    if "`truncate'" != "" {
        local n_trunc : word count `truncate'
        if `n_trunc' == 1 {
            local trunc_lo: word 1 of `truncate'
            local trunc_hi = 100 - `trunc_lo'
            local truncate_source "symmetric"
        }
        else {
            local trunc_lo: word 1 of `truncate'
            local trunc_hi: word 2 of `truncate'
            local truncate_source "explicit"
        }
        local truncate "`trunc_lo' `trunc_hi'"
        if `trunc_lo' <= 0 | `trunc_hi' >= 100 {
            display as error "truncate() values must lie strictly between 0 and 100"
            exit 198
        }
        if `trunc_lo' >= `trunc_hi' {
            display as error "truncate() lower bound must be less than upper bound"
            exit 198
        }
    }

    local fitfailure = lower(strtrim("`fitfailure'"))
    if "`fitfailure'" == "" {
        local fitfailure "error"
    }
    else if strpos("error", "`fitfailure'") == 1 {
        local fitfailure "error"
    }
    else if strpos("marginal", "`fitfailure'") == 1 {
        local fitfailure "marginal"
    }
    else {
        display as error "fitfailure() must be error or marginal"
        exit 198
    }

    * IPCW requested but no censor variable?
    if "`censor_d_cov'" != "" & "`censor'" == "" {
        display as error "censor_d_cov() specified but no censoring variable was mapped in msm_prepare"
        display as error "Re-run {bf:msm_prepare} with the {bf:censor()} option."
        exit 198
    }

    * censor_n_cov without censor_d_cov is a misspecification
    if "`censor_n_cov'" != "" & "`censor_d_cov'" == "" {
        display as error "censor_n_cov() requires censor_d_cov()"
        display as error "The censoring numerator model only applies when a denominator model is also specified."
        exit 198
    }

    local treat_d_spec_later "`treatment' ~ lagged `treatment' `treat_d_cov' `period'"
    local treat_d_spec_first "`treatment' ~ `treat_d_cov'"
    local treat_n_label "`treat_n_cov'"
    if "`treat_n_cov'" != "" {
        local treat_n_spec_later "`treatment' ~ lagged `treatment' `treat_n_cov'"
        local treat_n_spec_first "`treatment' ~ `treat_n_cov'"
    }
    else {
        local treat_n_label "(intercept + lagged treatment only)"
        local treat_n_spec_later "`treatment' ~ lagged `treatment'"
        local treat_n_spec_first "`treatment' ~ (intercept)"
    }
    local censor_n_label "`censor_n_cov'"
    if "`censor_d_cov'" != "" {
        local censor_d_spec "`censor' ~ `treatment' `censor_d_cov' `period'"
        if "`censor_n_cov'" != "" {
            local censor_n_spec "`censor' ~ `treatment' `censor_n_cov'"
        }
        else {
            local censor_n_label "(intercept + current treatment only)"
            local censor_n_spec "`censor' ~ `treatment'"
        }
    }

    * =========================================================================
    * DISPLAY HEADER
    * =========================================================================

    display as text ""
    display as text "{hline 70}"
    if "`preview'" != "" {
        display as result "msm_weight" as text " - Model Spec Preview"
    }
    else {
        display as result "msm_weight" as text " - Inverse Probability Weights"
    }
    display as text "{hline 70}"
    display as text ""
    display as text "Treatment denom:  " as result "`treat_d_cov'"
    if "`treat_d_cov_source'" == "prepared" {
        display as text "Denom source:     " as result ///
            "prepared covariates() + baseline_covariates() from msm_prepare"
    }
    if "`treat_n_cov'" != "" {
        display as text "Treatment numer:  " as result "`treat_n_cov'"
    }
    else {
        display as text "Treatment numer:  " as result "`treat_n_label'"
    }
    display as text "Treatment models:"
    display as text "  Denominator:    " as result "`treat_d_spec_later'"
    display as text "  First period:   " as result "`treat_d_spec_first'"
    display as text "  Numerator:      " as result "`treat_n_spec_later'"
    display as text "  First period:   " as result "`treat_n_spec_first'"
    if "`censor_d_cov'" != "" {
        display as text "Censoring denom:  " as result "`censor_d_cov'"
        display as text "Censoring numer:  " as result "`censor_n_label'"
        display as text "Censoring models:"
        display as text "  Denominator:    " as result "`censor_d_spec'"
        display as text "  Numerator:      " as result "`censor_n_spec'"
    }
    else if "`preview'" != "" {
        display as text "Censoring models: " as result "(not requested)"
    }
    display as text "Stabilized:       " as result "Yes"
    if "`fitfailure'" == "error" {
        display as text "Model failure:    " as result "Hard fail (default)"
    }
    else {
        display as text "Model failure:    " as result "Marginal fallback (explicit)"
    }
    if "`truncate'" != "" {
        display as text "Truncation:       " as result "`trunc_lo'th - `trunc_hi'th percentile"
        if "`truncate_source'" == "symmetric" {
            display as text "Truncate source:  " as result "symmetric shorthand from truncate(`truncate_original')"
        }
    }
    display as text ""

    if "`preview'" != "" {
        display as text "Preview only: no models fitted and no variables created."
        display as text "Next step: rerun {cmd:msm_weight} without {cmd:preview}"
        display as text "{hline 70}"

        return local preview "`preview_flag'"
        return local treat_d_cov "`treat_d_cov'"
        return local treat_d_cov_source "`treat_d_cov_source'"
        return local treat_n_cov "`treat_n_cov'"
        return local censor_d_cov "`censor_d_cov'"
        return local censor_n_cov "`censor_n_cov'"
        return local truncate "`truncate'"
        return local fitfailure_policy "`fitfailure'"
    }
    else {
        * Check weight variables
        foreach wvar in _msm_weight _msm_tw_weight _msm_cw_weight _msm_ps {
            capture confirm variable `wvar'
            if _rc == 0 {
                if "`replace'" == "" {
                    display as error "variable `wvar' already exists; use replace option"
                    exit 110
                }
                quietly drop `wvar'
            }
        }

        * This implementation assumes a common baseline period for all individuals.
        quietly summarize `period'
        local min_period = r(min)
        tempvar _first_period _id_tag
        quietly bysort `id' (`period'): gen double `_first_period' = `period'[1]
        quietly bysort `id': gen byte `_id_tag' = (_n == 1)
        quietly count if `_id_tag' & `_first_period' != `min_period'
        if r(N) > 0 {
            display as error "delayed entry is not currently supported"
            display as error as result r(N) as error ///
                " individual(s) begin after the common baseline period `min_period'"
            exit 198
        }

        local log_opt ""
        if "`log'" == "nolog" local log_opt "nolog"

        * =========================================================================
        * TREATMENT WEIGHTS (IPTW)
        * =========================================================================

        display as text "Fitting treatment models..."

        _msm_weight_treatment, id(`id') period(`period') ///
            treatment(`treatment') outcome(`outcome') ///
            censor(`censor') ///
            d_cov(`treat_d_cov') n_cov(`treat_n_cov') ///
            fitfailure(`fitfailure') `log_opt'

        local n_fitfail_fallback = r(n_fitfail_fallback)
        local n_probability_repairs = r(n_probability_repairs)
        local fitfailure_models "`r(fitfailure_models)'"

        * _msm_tw_weight now exists (cumulative treatment weight)

        * =========================================================================
        * CENSORING WEIGHTS (IPCW) - optional
        * =========================================================================

        if "`censor_d_cov'" != "" & "`censor'" != "" {
            display as text ""
            display as text "Fitting censoring models..."

            _msm_weight_censor, id(`id') period(`period') ///
                treatment(`treatment') censor(`censor') ///
                outcome(`outcome') ///
                d_cov(`censor_d_cov') n_cov(`censor_n_cov') ///
                fitfailure(`fitfailure') `log_opt'

            local n_fitfail_fallback = `n_fitfail_fallback' + r(n_fitfail_fallback)
            local n_probability_repairs = `n_probability_repairs' + r(n_probability_repairs)
            local fitfailure_models "`fitfailure_models' `r(fitfailure_models)'"

            * _msm_cw_weight now exists (cumulative censoring weight)
        }

        * =========================================================================
        * COMBINE WEIGHTS
        * =========================================================================

        quietly {
            * Combined weight = treatment weight * censoring weight
            capture confirm variable _msm_cw_weight
            if _rc == 0 {
                gen double _msm_weight = _msm_tw_weight * _msm_cw_weight
            }
            else {
                gen double _msm_weight = _msm_tw_weight
            }
        }

        quietly count if _msm_weight > 0 & _msm_weight < .
        local n_weight_valid = r(N)
        quietly summarize _msm_weight if _msm_weight > 0 & _msm_weight < .
        local sum_weight_valid = r(sum)
        if `n_weight_valid' == 0 | missing(`sum_weight_valid') | ///
            `sum_weight_valid' <= 0 {
            display as error "msm_weight did not produce any positive nonmissing weights"
            display as error "At least one treatment or censoring probability model returned only missing probabilities."
            display as error "Check complete-case availability for the weighting covariates before proceeding."
            _msm_clear_downstream_state
            exit 2000
        }

        * =========================================================================
        * TRUNCATION
        * =========================================================================

        local n_truncated = 0
        if "`truncate'" != "" {
            display as text ""
            display as text "Truncating weights at `trunc_lo'th and `trunc_hi'th percentiles..."

            quietly {
                _pctile _msm_weight if !missing(_msm_weight), ///
                    percentiles(`trunc_lo' `trunc_hi')
                local lo_val = r(r1)
                local hi_val = r(r2)

                count if _msm_weight < `lo_val' & !missing(_msm_weight)
                local n_lo = r(N)
                count if _msm_weight > `hi_val' & !missing(_msm_weight)
                local n_hi = r(N)
                local n_truncated = `n_lo' + `n_hi'

                replace _msm_weight = `lo_val' if _msm_weight < `lo_val' & !missing(_msm_weight)
                replace _msm_weight = `hi_val' if _msm_weight > `hi_val' & !missing(_msm_weight)
            }

            display as text "  Truncated `n_truncated' observations (`n_lo' low, `n_hi' high)"
        }

        quietly count if _msm_weight > 0 & _msm_weight < .
        local n_weight_valid = r(N)
        quietly summarize _msm_weight if _msm_weight > 0 & _msm_weight < .
        local sum_weight_valid = r(sum)
        if `n_weight_valid' == 0 | missing(`sum_weight_valid') | ///
            `sum_weight_valid' <= 0 {
            display as error "msm_weight did not produce a finite positive weight sum"
            display as error "Refusing to mark the dataset weighted with unusable _msm_weight values."
            _msm_clear_downstream_state
            exit 2000
        }

        * =========================================================================
        * DIAGNOSTICS
        * =========================================================================

        quietly summarize _msm_weight, detail
        local w_mean = r(mean)
        local w_sd   = r(sd)
        local w_min  = r(min)
        local w_max  = r(max)
        local w_p1   = r(p1)
        local w_p50  = r(p50)
        local w_p99  = r(p99)

        * Effective sample size: (sum w)^2 / (sum w^2)
        quietly {
            summarize _msm_weight
            local sum_w = r(sum)
            tempvar _w2
            gen double `_w2' = _msm_weight^2
            summarize `_w2'
            local sum_w2 = r(sum)
            drop `_w2'
        }
        local ess = (`sum_w'^2) / `sum_w2'

        label variable _msm_weight "MSM cumulative IP weight"
        label variable _msm_tw_weight "MSM treatment weight (cumulative)"
        capture confirm variable _msm_cw_weight
        if _rc == 0 {
            label variable _msm_cw_weight "MSM censoring weight (cumulative)"
        }

        * Store metadata
        char _dta[_msm_weighted] "1"
        char _dta[_msm_weight_var] "_msm_weight"

        * psdash contract: treatment propensity score, treatment-only weight,
        * estimand, and contract version so {cmd:psdash combined} can auto-detect
        * the treatment model after msm_weight.
        char _dta[_msm_ps_var] "_msm_ps"
        char _dta[_msm_tw_var] "_msm_tw_weight"
        char _dta[_msm_ps_covars] "`treat_d_cov'"
        char _dta[_msm_estimand] "ate"
        char _dta[_msm_contract_version] "1.0"

        * =========================================================================
        * DISPLAY RESULTS
        * =========================================================================

        display as text ""
        display as text "Weight distribution:"
        display as text "  Mean:     " as result %9.4f `w_mean'
        display as text "  SD:       " as result %9.4f `w_sd'
        display as text "  Min:      " as result %9.4f `w_min'
        display as text "  Median:   " as result %9.4f `w_p50'
        display as text "  Max:      " as result %9.4f `w_max'
        display as text "  P1:       " as result %9.4f `w_p1'
        display as text "  P99:      " as result %9.4f `w_p99'
        display as text ""
        display as text "Effective sample size: " as result %9.1f `ess' ///
            as text " (of " as result _N as text ")"

        * Check mean ~1 for stabilized weights
        if abs(`w_mean' - 1) > 0.1 {
            display as text ""
            display as text "Note: stabilized weight mean is " as result %5.3f `w_mean'
            display as text "  Expected ~1.0 for correctly specified models."
            display as text "  Check treatment model specification."
        }

        local fitfailure_models : list retokenize fitfailure_models

        if `n_fitfail_fallback' > 0 {
            display as text ""
            display as text "Requested marginal fallback used for " ///
                as result `n_fitfail_fallback' as text " model(s)."
            display as text "Affected models:  " as result "`fitfailure_models'"
        }

        if `n_probability_repairs' > 0 {
            display as text ""
            display as text "Perfect-prediction repairs: " ///
                as result `n_probability_repairs' as text ///
                " observation(s) assigned truncated observed probabilities"
        }

        display as text ""
        display as text "Variables created: " as result "_msm_weight _msm_tw_weight" ///
            cond("`censor_d_cov'" != "", " _msm_cw_weight", "") as result " _msm_ps"
        display as text "Next step: {cmd:msm_diagnose}, {cmd:msm_fit}, or {cmd:psdash combined}"
        display as text "{hline 70}"

        * =========================================================================
        * RETURN RESULTS
        * =========================================================================

        return scalar mean_weight = `w_mean'
        return scalar sd_weight = `w_sd'
        return scalar min_weight = `w_min'
        return scalar max_weight = `w_max'
        return scalar p1_weight = `w_p1'
        return scalar median_weight = `w_p50'
        return scalar p99_weight = `w_p99'
        return scalar ess = `ess'
        return scalar n_truncated = `n_truncated'
        return scalar n_fitfail_fallback = `n_fitfail_fallback'
        return scalar fitfailure_fallback = (`n_fitfail_fallback' > 0)
        return scalar n_probability_repairs = `n_probability_repairs'

        return local weight_var "_msm_weight"
        return local fitfailure_policy "`fitfailure'"
        return local fitfailure_models "`fitfailure_models'"
        return local preview "`preview_flag'"
        return local treat_d_cov "`treat_d_cov'"
        return local treat_d_cov_source "`treat_d_cov_source'"
        return local treat_n_cov "`treat_n_cov'"
        return local censor_d_cov "`censor_d_cov'"
        return local censor_n_cov "`censor_n_cov'"
        return local truncate "`truncate'"
    }

    } /* end capture noisily */
    local _rc = _rc

    set varabbrev `_varabbrev'
    set more `_more'

    if `_rc' exit `_rc'
end

* =========================================================================
* _msm_weight_treatment: Fit treatment weight models and compute
*   cumulative stabilized IPTW
* =========================================================================
cap program drop _msm_weight_treatment
program define _msm_weight_treatment, rclass
    version 16.0
    local _orig_varabbrev = c(varabbrev)
    set varabbrev off

    capture noisily {

    syntax , id(varname) period(varname) ///
        treatment(varname) outcome(varname) ///
        [censor(varname)] ///
        d_cov(varlist) [n_cov(varlist) fitfailure(string) nolog]

    local log_opt ""
    if "`nolog'" != "" local log_opt "nolog"
    local fitfailure = lower(strtrim("`fitfailure'"))
    if "`fitfailure'" == "" local fitfailure "error"
    local n_fitfail_fallback = 0
    local n_probability_repairs = 0
    local fitfailure_models ""

    * Probability truncation bounds for numerical stability
    local _pr_lo = 0.001
    local _pr_hi = 0.999

    quietly {
        * Create analysis sample marker: not yet had outcome or been censored
        * At each period t, we model treatment among those still at risk
        tempvar _at_risk _lag_treat _first_obs

        * Cumulative prior outcome (excluding current period)
        tempvar _cum_out
        bysort `id' (`period'): gen int `_cum_out' = sum(`outcome'[_n-1]) if _n > 1
        replace `_cum_out' = 0 if missing(`_cum_out')

        * Cumulative prior censoring
        if "`censor'" != "" {
            tempvar _cum_cens
            bysort `id' (`period'): gen int `_cum_cens' = sum(`censor'[_n-1]) if _n > 1
            replace `_cum_cens' = 0 if missing(`_cum_cens')
            gen byte `_at_risk' = (`_cum_out' == 0 & `_cum_cens' == 0)
            drop `_cum_cens'
        }
        else {
            gen byte `_at_risk' = (`_cum_out' == 0)
        }
        drop `_cum_out'

        * Lagged treatment
        bysort `id' (`period'): gen byte `_first_obs' = (_n == 1)
        bysort `id' (`period'): gen byte `_lag_treat' = `treatment'[_n-1]
        * First period has no lag - handle separately

        * ---------------------------------------------------------------
        * DENOMINATOR MODEL: P(A_t | A_{t-1}, L_t, V)
        * Full model with all time-varying and baseline covariates
        * ---------------------------------------------------------------
        tempvar _denom_pr _denom_complete _denom_drop
        gen byte `_denom_complete' = `_at_risk' & !`_first_obs' & ///
            !missing(`treatment') & !missing(`_lag_treat')
        foreach _v of varlist `d_cov' `period' {
            replace `_denom_complete' = 0 if missing(`_v')
        }

        noisily display as text "  Denominator model: `treatment' ~ lagged `treatment' `d_cov' `period'"
        quietly count if `_denom_complete'
        local _n_denom_complete = r(N)
        if `_n_denom_complete' == 0 {
            gen double `_denom_pr' = .
        }
        else {
            capture logit `treatment' `_lag_treat' `d_cov' `period' ///
                if `_denom_complete', `log_opt'
            local _fit_rc = _rc
            if `_fit_rc' != 0 {
                if "`fitfailure'" == "marginal" {
                    noisily display as text ///
                        "  Warning: denominator model failed; using requested marginal fallback"
                    summarize `treatment' if `_denom_complete'
                    gen double `_denom_pr' = r(mean) if `_denom_complete'
                    local ++n_fitfail_fallback
                    local fitfailure_models "`fitfailure_models' treatment_denominator"
                }
                else {
                    noisily display as error ///
                        "  Treatment denominator model failed (rc=`_fit_rc')."
                    noisily display as error ///
                        "  Refusing to substitute a marginal probability by default."
                    noisily display as error ///
                        "  Fix the weighting model or rerun with fitfailure(marginal)."
                    exit 498
                }
            }
            else if e(converged) == 0 {
                if "`fitfailure'" == "marginal" {
                    noisily display as text ///
                        "  Warning: denominator model did not converge; using requested marginal fallback"
                    summarize `treatment' if `_denom_complete'
                    gen double `_denom_pr' = r(mean) if `_denom_complete'
                    local ++n_fitfail_fallback
                    local fitfailure_models "`fitfailure_models' treatment_denominator"
                }
                else {
                    noisily display as error ///
                        "  Treatment denominator model did not converge."
                    noisily display as error ///
                        "  Refusing to substitute a marginal probability by default."
                    noisily display as error ///
                        "  Fix the weighting model or rerun with fitfailure(marginal)."
                    exit 498
                }
            }
            else {
                predict double `_denom_pr' if `_denom_complete', pr
            }
        }
        gen byte `_denom_drop' = `_denom_complete' & missing(`_denom_pr')
        quietly count if `_denom_drop'
        local _n_denom_drop = r(N)
        if `_n_denom_drop' > 0 {
            local n_probability_repairs = `n_probability_repairs' + `_n_denom_drop'
            noisily display as text "  Warning: " as result `_n_denom_drop' as text ///
                " treatment-denominator observation(s) were perfectly predicted; " ///
                "using truncated observed probabilities"
            replace `_denom_pr' = cond(`treatment' == 1, `_pr_hi', `_pr_lo') ///
                if `_denom_drop'
        }

        * For first period (no lag), use a separate simpler model
        tempvar _denom_pr0 _denom0_complete _denom0_drop
        gen byte `_denom0_complete' = `_at_risk' & `_first_obs' & ///
            !missing(`treatment')
        foreach _v of varlist `d_cov' {
            replace `_denom0_complete' = 0 if missing(`_v')
        }
        quietly count if `_denom0_complete'
        local _n_denom0_complete = r(N)
        if `_n_denom0_complete' == 0 {
            gen double `_denom_pr0' = .
        }
        else {
            capture logit `treatment' `d_cov' if `_denom0_complete', `log_opt'
            local _fit_rc = _rc
            if `_fit_rc' != 0 {
                if "`fitfailure'" == "marginal" {
                    noisily display as text ///
                        "  Warning: first-period denominator model failed; using requested marginal fallback"
                    summarize `treatment' if `_denom0_complete'
                    gen double `_denom_pr0' = r(mean) if `_denom0_complete'
                    local ++n_fitfail_fallback
                    local fitfailure_models "`fitfailure_models' treatment_denominator0"
                }
                else {
                    noisily display as error ///
                        "  First-period treatment denominator model failed (rc=`_fit_rc')."
                    noisily display as error ///
                        "  Refusing to substitute a marginal probability by default."
                    noisily display as error ///
                        "  Fix the weighting model or rerun with fitfailure(marginal)."
                    exit 498
                }
            }
            else if e(converged) == 0 {
                if "`fitfailure'" == "marginal" {
                    noisily display as text ///
                        "  Warning: first-period denominator model did not converge; using requested marginal fallback"
                    summarize `treatment' if `_denom0_complete'
                    gen double `_denom_pr0' = r(mean) if `_denom0_complete'
                    local ++n_fitfail_fallback
                    local fitfailure_models "`fitfailure_models' treatment_denominator0"
                }
                else {
                    noisily display as error ///
                        "  First-period treatment denominator model did not converge."
                    noisily display as error ///
                        "  Refusing to substitute a marginal probability by default."
                    noisily display as error ///
                        "  Fix the weighting model or rerun with fitfailure(marginal)."
                    exit 498
                }
            }
            else {
                predict double `_denom_pr0' if `_denom0_complete', pr
            }
        }
        gen byte `_denom0_drop' = `_denom0_complete' & missing(`_denom_pr0')
        quietly count if `_denom0_drop'
        local _n_denom0_drop = r(N)
        if `_n_denom0_drop' > 0 {
            local n_probability_repairs = `n_probability_repairs' + `_n_denom0_drop'
            noisily display as text "  Warning: " as result `_n_denom0_drop' as text ///
                " first-period denominator observation(s) were perfectly predicted; " ///
                "using truncated observed probabilities"
            replace `_denom_pr0' = cond(`treatment' == 1, `_pr_hi', `_pr_lo') ///
                if `_denom0_drop'
        }
        replace `_denom_pr' = `_denom_pr0' if missing(`_denom_pr') & ///
            `_at_risk' & `_first_obs'

        * Persist the per-period treatment propensity P(A_t=1|history) from the
        * denominator model so psdash can run overlap/support/balance panels on
        * the treatment model. Defined only on at-risk person-periods; missing
        * elsewhere, which psdash drops from its diagnostic sample.
        capture drop _msm_ps
        gen double _msm_ps = `_denom_pr'
        label variable _msm_ps "MSM treatment propensity P(A_t=1|history)"

        drop `_denom_pr0' `_denom_complete' `_denom_drop' `_denom0_complete' `_denom0_drop'

        * ---------------------------------------------------------------
        * NUMERATOR MODEL: P(A_t | A_{t-1}, V)
        * Baseline-only model (or simpler model) for stabilization
        * ---------------------------------------------------------------
        tempvar _numer_pr _numer_complete _numer_drop
        gen byte `_numer_complete' = `_at_risk' & !`_first_obs' & ///
            !missing(`treatment') & !missing(`_lag_treat')
        if "`n_cov'" != "" {
            foreach _v of varlist `n_cov' {
                replace `_numer_complete' = 0 if missing(`_v')
            }
        }

        if "`n_cov'" != "" {
            noisily display as text "  Numerator model:   `treatment' ~ lagged `treatment' `n_cov'"
            quietly count if `_numer_complete'
            local _n_numer_complete = r(N)
            if `_n_numer_complete' == 0 {
                gen double `_numer_pr' = .
            }
            else {
                capture logit `treatment' `_lag_treat' `n_cov' ///
                    if `_numer_complete', `log_opt'
                local _fit_rc = _rc
                if `_fit_rc' != 0 {
                    if "`fitfailure'" == "marginal" {
                        noisily display as text ///
                            "  Warning: numerator model failed; using requested marginal fallback"
                        summarize `treatment' if `_numer_complete'
                        gen double `_numer_pr' = r(mean) if `_numer_complete'
                        local ++n_fitfail_fallback
                        local fitfailure_models "`fitfailure_models' treatment_numerator"
                    }
                    else {
                        noisily display as error ///
                            "  Treatment numerator model failed (rc=`_fit_rc')."
                        noisily display as error ///
                            "  Refusing to substitute a marginal probability by default."
                        noisily display as error ///
                            "  Fix the weighting model or rerun with fitfailure(marginal)."
                        exit 498
                    }
                }
                else if e(converged) == 0 {
                    if "`fitfailure'" == "marginal" {
                        noisily display as text ///
                            "  Warning: numerator model did not converge; using requested marginal fallback"
                        summarize `treatment' if `_numer_complete'
                        gen double `_numer_pr' = r(mean) if `_numer_complete'
                        local ++n_fitfail_fallback
                        local fitfailure_models "`fitfailure_models' treatment_numerator"
                    }
                    else {
                        noisily display as error ///
                            "  Treatment numerator model did not converge."
                        noisily display as error ///
                            "  Refusing to substitute a marginal probability by default."
                        noisily display as error ///
                            "  Fix the weighting model or rerun with fitfailure(marginal)."
                        exit 498
                    }
                }
                else {
                    predict double `_numer_pr' if `_numer_complete', pr
                }
            }
        }
        else {
            noisily display as text "  Numerator model:   `treatment' ~ lagged `treatment'"
            quietly count if `_numer_complete'
            local _n_numer_complete = r(N)
            if `_n_numer_complete' == 0 {
                gen double `_numer_pr' = .
            }
            else {
                capture logit `treatment' `_lag_treat' ///
                    if `_numer_complete', `log_opt'
                local _fit_rc = _rc
                if `_fit_rc' != 0 {
                    if "`fitfailure'" == "marginal" {
                        noisily display as text ///
                            "  Warning: numerator model failed; using requested marginal fallback"
                        summarize `treatment' if `_numer_complete'
                        gen double `_numer_pr' = r(mean) if `_numer_complete'
                        local ++n_fitfail_fallback
                        local fitfailure_models "`fitfailure_models' treatment_numerator"
                    }
                    else {
                        noisily display as error ///
                            "  Treatment numerator model failed (rc=`_fit_rc')."
                        noisily display as error ///
                            "  Refusing to substitute a marginal probability by default."
                        noisily display as error ///
                            "  Fix the weighting model or rerun with fitfailure(marginal)."
                        exit 498
                    }
                }
                else if e(converged) == 0 {
                    if "`fitfailure'" == "marginal" {
                        noisily display as text ///
                            "  Warning: numerator model did not converge; using requested marginal fallback"
                        summarize `treatment' if `_numer_complete'
                        gen double `_numer_pr' = r(mean) if `_numer_complete'
                        local ++n_fitfail_fallback
                        local fitfailure_models "`fitfailure_models' treatment_numerator"
                    }
                    else {
                        noisily display as error ///
                            "  Treatment numerator model did not converge."
                        noisily display as error ///
                            "  Refusing to substitute a marginal probability by default."
                        noisily display as error ///
                            "  Fix the weighting model or rerun with fitfailure(marginal)."
                        exit 498
                    }
                }
                else {
                    predict double `_numer_pr' if `_numer_complete', pr
                }
            }
        }
        gen byte `_numer_drop' = `_numer_complete' & missing(`_numer_pr')
        quietly count if `_numer_drop'
        local _n_numer_drop = r(N)
        if `_n_numer_drop' > 0 {
            local n_probability_repairs = `n_probability_repairs' + `_n_numer_drop'
            noisily display as text "  Warning: " as result `_n_numer_drop' as text ///
                " treatment-numerator observation(s) were perfectly predicted; " ///
                "using truncated observed probabilities"
            replace `_numer_pr' = cond(`treatment' == 1, `_pr_hi', `_pr_lo') ///
                if `_numer_drop'
        }

        * First period numerator
        tempvar _numer_pr0 _numer0_complete _numer0_drop
        gen byte `_numer0_complete' = `_at_risk' & `_first_obs' & ///
            !missing(`treatment')
        if "`n_cov'" != "" {
            foreach _v of varlist `n_cov' {
                replace `_numer0_complete' = 0 if missing(`_v')
            }
        }
        if "`n_cov'" != "" {
            quietly count if `_numer0_complete'
            local _n_numer0_complete = r(N)
            if `_n_numer0_complete' == 0 {
                gen double `_numer_pr0' = .
            }
            else {
                capture logit `treatment' `n_cov' if `_numer0_complete', `log_opt'
                local _fit_rc = _rc
                if `_fit_rc' != 0 {
                    if "`fitfailure'" == "marginal" {
                        noisily display as text ///
                            "  Warning: first-period numerator model failed; using requested marginal fallback"
                        summarize `treatment' if `_numer0_complete'
                        gen double `_numer_pr0' = r(mean) if `_numer0_complete'
                        local ++n_fitfail_fallback
                        local fitfailure_models "`fitfailure_models' treatment_numerator0"
                    }
                    else {
                        noisily display as error ///
                            "  First-period treatment numerator model failed (rc=`_fit_rc')."
                        noisily display as error ///
                            "  Refusing to substitute a marginal probability by default."
                        noisily display as error ///
                            "  Fix the weighting model or rerun with fitfailure(marginal)."
                        exit 498
                    }
                }
                else if e(converged) == 0 {
                    if "`fitfailure'" == "marginal" {
                        noisily display as text ///
                            "  Warning: first-period numerator model did not converge; using requested marginal fallback"
                        summarize `treatment' if `_numer0_complete'
                        gen double `_numer_pr0' = r(mean) if `_numer0_complete'
                        local ++n_fitfail_fallback
                        local fitfailure_models "`fitfailure_models' treatment_numerator0"
                    }
                    else {
                        noisily display as error ///
                            "  First-period treatment numerator model did not converge."
                        noisily display as error ///
                            "  Refusing to substitute a marginal probability by default."
                        noisily display as error ///
                            "  Fix the weighting model or rerun with fitfailure(marginal)."
                        exit 498
                    }
                }
                else {
                    predict double `_numer_pr0' if `_numer0_complete', pr
                }
            }
        }
        else {
            quietly count if `_numer0_complete'
            local _n_numer0_complete = r(N)
            if `_n_numer0_complete' == 0 {
                gen double `_numer_pr0' = .
            }
            else {
                capture logit `treatment' if `_numer0_complete', `log_opt'
                local _fit_rc = _rc
                if `_fit_rc' != 0 {
                    if "`fitfailure'" == "marginal" {
                        noisily display as text ///
                            "  Warning: first-period numerator model failed; using requested marginal fallback"
                        summarize `treatment' if `_numer0_complete'
                        gen double `_numer_pr0' = r(mean) if `_numer0_complete'
                        local ++n_fitfail_fallback
                        local fitfailure_models "`fitfailure_models' treatment_numerator0"
                    }
                    else {
                        noisily display as error ///
                            "  First-period treatment numerator model failed (rc=`_fit_rc')."
                        noisily display as error ///
                            "  Refusing to substitute a marginal probability by default."
                        noisily display as error ///
                            "  Fix the weighting model or rerun with fitfailure(marginal)."
                        exit 498
                    }
                }
                else if e(converged) == 0 {
                    if "`fitfailure'" == "marginal" {
                        noisily display as text ///
                            "  Warning: first-period numerator model did not converge; using requested marginal fallback"
                        summarize `treatment' if `_numer0_complete'
                        gen double `_numer_pr0' = r(mean) if `_numer0_complete'
                        local ++n_fitfail_fallback
                        local fitfailure_models "`fitfailure_models' treatment_numerator0"
                    }
                    else {
                        noisily display as error ///
                            "  First-period treatment numerator model did not converge."
                        noisily display as error ///
                            "  Refusing to substitute a marginal probability by default."
                        noisily display as error ///
                            "  Fix the weighting model or rerun with fitfailure(marginal)."
                        exit 498
                    }
                }
                else {
                    predict double `_numer_pr0' if `_numer0_complete', pr
                }
            }
        }
        gen byte `_numer0_drop' = `_numer0_complete' & missing(`_numer_pr0')
        quietly count if `_numer0_drop'
        local _n_numer0_drop = r(N)
        if `_n_numer0_drop' > 0 {
            local n_probability_repairs = `n_probability_repairs' + `_n_numer0_drop'
            noisily display as text "  Warning: " as result `_n_numer0_drop' as text ///
                " first-period numerator observation(s) were perfectly predicted; " ///
                "using truncated observed probabilities"
            replace `_numer_pr0' = cond(`treatment' == 1, `_pr_hi', `_pr_lo') ///
                if `_numer0_drop'
        }
        replace `_numer_pr' = `_numer_pr0' if missing(`_numer_pr') & ///
            `_at_risk' & `_first_obs'
        drop `_numer_pr0' `_numer_complete' `_numer_drop' `_numer0_complete' `_numer0_drop'

        * ---------------------------------------------------------------
        * COMPUTE PERIOD-SPECIFIC WEIGHT RATIOS
        * ---------------------------------------------------------------
        tempvar _tw_t _miss_tw

        * Truncate extreme probabilities to avoid division by zero
        * and ensure all at-risk observations get proper weights
        count if (`_denom_pr' < `_pr_lo' | `_denom_pr' > `_pr_hi') & `_at_risk' & !missing(`_denom_pr')
        local _n_extreme_d = r(N)
        replace `_denom_pr' = max(`_denom_pr', `_pr_lo') if `_at_risk' & !missing(`_denom_pr')
        replace `_denom_pr' = min(`_denom_pr', `_pr_hi') if `_at_risk' & !missing(`_denom_pr')
        replace `_numer_pr' = max(`_numer_pr', `_pr_lo') if `_at_risk' & !missing(`_numer_pr')
        replace `_numer_pr' = min(`_numer_pr', `_pr_hi') if `_at_risk' & !missing(`_numer_pr')

        if `_n_extreme_d' > 0 {
            noisily display as text "  Warning: " as result `_n_extreme_d' as text ///
                " obs with near-deterministic treatment probability (truncated)"
        }

        * w_t = numer / denom if treated, (1-numer)/(1-denom) if untreated
        gen double `_tw_t' = 1

        * Treated observations
        replace `_tw_t' = `_numer_pr' / `_denom_pr' ///
            if `treatment' == 1 & `_at_risk' & !missing(`_denom_pr')

        * Untreated observations
        replace `_tw_t' = (1 - `_numer_pr') / (1 - `_denom_pr') ///
            if `treatment' == 0 & `_at_risk' & !missing(`_denom_pr')

        gen byte `_miss_tw' = `_at_risk' & ///
            (missing(`treatment') | missing(`_denom_pr') | missing(`_numer_pr'))
        quietly count if `_miss_tw'
        if r(N) > 0 {
            noisily display as text "  Warning: " as result r(N) as text ///
                " at-risk observation(s) had missing model probabilities; " ///
                "weights set to missing from that period forward"
        }

        * ---------------------------------------------------------------
        * CUMULATIVE PRODUCT VIA LOG-SUM
        * ---------------------------------------------------------------
        tempvar _log_tw _cum_log_tw _cum_miss_tw

        gen double `_log_tw' = ln(`_tw_t') if `_at_risk' & !`_miss_tw' & ///
            !missing(`_tw_t') & `_tw_t' > 0
        * Set weight = 1 (log = 0) for non-at-risk observations
        replace `_log_tw' = 0 if !`_at_risk'

        bysort `id' (`period'): gen byte `_cum_miss_tw' = (sum(`_miss_tw') > 0)
        bysort `id' (`period'): gen double `_cum_log_tw' = sum(`_log_tw')

        gen double _msm_tw_weight = exp(`_cum_log_tw')
        replace _msm_tw_weight = . if `_cum_miss_tw'

        * Clean up
        drop `_at_risk' `_lag_treat' `_first_obs' `_denom_pr' `_numer_pr' `_tw_t' ///
            `_miss_tw' `_log_tw' `_cum_log_tw' `_cum_miss_tw'
    }

    } /* end capture noisily */
    local _rc = _rc

    set varabbrev `_orig_varabbrev'

    if `_rc' exit `_rc'

    local fitfailure_models : list retokenize fitfailure_models
    return scalar n_fitfail_fallback = `n_fitfail_fallback'
    return scalar n_probability_repairs = `n_probability_repairs'
    return local fitfailure_models "`fitfailure_models'"
end

* =========================================================================
* _msm_weight_censor: Fit censoring weight models and compute
*   cumulative stabilized IPCW
* =========================================================================
cap program drop _msm_weight_censor
program define _msm_weight_censor, rclass
    version 16.0
    local _orig_varabbrev = c(varabbrev)
    set varabbrev off

    capture noisily {

    syntax , id(varname) period(varname) ///
        treatment(varname) censor(varname) outcome(varname) ///
        d_cov(varlist) [n_cov(varlist) fitfailure(string) nolog]

    local log_opt ""
    if "`nolog'" != "" local log_opt "nolog"
    local fitfailure = lower(strtrim("`fitfailure'"))
    if "`fitfailure'" == "" local fitfailure "error"
    local n_fitfail_fallback = 0
    local n_probability_repairs = 0
    local fitfailure_models ""

    * Probability truncation bounds for numerical stability
    local _pr_lo = 0.001
    local _pr_hi = 0.999

    quietly {
        * At-risk: not yet had outcome or been censored (prior periods)
        tempvar _cum_out _cum_cens _at_risk
        bysort `id' (`period'): gen int `_cum_out' = sum(`outcome'[_n-1]) if _n > 1
        replace `_cum_out' = 0 if missing(`_cum_out')
        bysort `id' (`period'): gen int `_cum_cens' = sum(`censor'[_n-1]) if _n > 1
        replace `_cum_cens' = 0 if missing(`_cum_cens')
        gen byte `_at_risk' = (`_cum_out' == 0 & `_cum_cens' == 0)
        drop `_cum_out' `_cum_cens'

        * ---------------------------------------------------------------
        * DENOMINATOR MODEL: P(C_t = 0 | L_t, A_t)
        * We model P(uncensored) so weight = P_num(uncens) / P_den(uncens)
        * ---------------------------------------------------------------
        tempvar _denom_pr _denom_complete _denom_drop
        gen byte `_denom_complete' = `_at_risk' & `outcome' == 0 & ///
            !missing(`censor')
        foreach _v of varlist `treatment' `d_cov' `period' {
            replace `_denom_complete' = 0 if missing(`_v')
        }

        noisily display as text "  Denominator model: `censor' ~ `treatment' `d_cov' `period'"
        quietly count if `_denom_complete'
        local _n_denom_complete = r(N)
        if `_n_denom_complete' == 0 {
            gen double `_denom_pr' = .
        }
        else {
            capture logit `censor' `treatment' `d_cov' `period' ///
                if `_denom_complete', `log_opt'
            local _fit_rc = _rc
            if `_fit_rc' != 0 {
                if "`fitfailure'" == "marginal" {
                    noisily display as text ///
                        "  Warning: censoring denominator model failed; using requested marginal fallback"
                    summarize `censor' if `_denom_complete'
                    gen double `_denom_pr' = r(mean) if `_denom_complete'
                    local ++n_fitfail_fallback
                    local fitfailure_models "`fitfailure_models' censor_denominator"
                }
                else {
                    noisily display as error ///
                        "  Censoring denominator model failed (rc=`_fit_rc')."
                    noisily display as error ///
                        "  Refusing to substitute a marginal probability by default."
                    noisily display as error ///
                        "  Fix the weighting model or rerun with fitfailure(marginal)."
                    exit 498
                }
            }
            else if e(converged) == 0 {
                if "`fitfailure'" == "marginal" {
                    noisily display as text ///
                        "  Warning: censoring denominator model did not converge; using requested marginal fallback"
                    summarize `censor' if `_denom_complete'
                    gen double `_denom_pr' = r(mean) if `_denom_complete'
                    local ++n_fitfail_fallback
                    local fitfailure_models "`fitfailure_models' censor_denominator"
                }
                else {
                    noisily display as error ///
                        "  Censoring denominator model did not converge."
                    noisily display as error ///
                        "  Refusing to substitute a marginal probability by default."
                    noisily display as error ///
                        "  Fix the weighting model or rerun with fitfailure(marginal)."
                    exit 498
                }
            }
            else {
                predict double `_denom_pr' if `_denom_complete', pr
            }
        }
        gen byte `_denom_drop' = `_denom_complete' & missing(`_denom_pr')
        quietly count if `_denom_drop'
        local _n_denom_drop = r(N)
        if `_n_denom_drop' > 0 {
            local n_probability_repairs = `n_probability_repairs' + `_n_denom_drop'
            noisily display as text "  Warning: " as result `_n_denom_drop' as text ///
                " censoring-denominator observation(s) were perfectly predicted; " ///
                "using truncated observed probabilities"
            replace `_denom_pr' = cond(`censor' == 1, `_pr_hi', `_pr_lo') ///
                if `_denom_drop'
        }

        * ---------------------------------------------------------------
        * NUMERATOR MODEL: P(C_t = 0 | A_t) or simpler
        * ---------------------------------------------------------------
        tempvar _numer_pr _numer_complete _numer_drop
        gen byte `_numer_complete' = `_at_risk' & `outcome' == 0 & ///
            !missing(`censor') & !missing(`treatment')
        if "`n_cov'" != "" {
            foreach _v of varlist `n_cov' {
                replace `_numer_complete' = 0 if missing(`_v')
            }
        }

        if "`n_cov'" != "" {
            noisily display as text "  Numerator model:   `censor' ~ `treatment' `n_cov'"
            quietly count if `_numer_complete'
            local _n_numer_complete = r(N)
            if `_n_numer_complete' == 0 {
                gen double `_numer_pr' = .
            }
            else {
                capture logit `censor' `treatment' `n_cov' ///
                    if `_numer_complete', `log_opt'
                local _fit_rc = _rc
                if `_fit_rc' != 0 {
                    if "`fitfailure'" == "marginal" {
                        noisily display as text ///
                            "  Warning: censoring numerator model failed; using requested marginal fallback"
                        summarize `censor' if `_numer_complete'
                        gen double `_numer_pr' = r(mean) if `_numer_complete'
                        local ++n_fitfail_fallback
                        local fitfailure_models "`fitfailure_models' censor_numerator"
                    }
                    else {
                        noisily display as error ///
                            "  Censoring numerator model failed (rc=`_fit_rc')."
                        noisily display as error ///
                            "  Refusing to substitute a marginal probability by default."
                        noisily display as error ///
                            "  Fix the weighting model or rerun with fitfailure(marginal)."
                        exit 498
                    }
                }
                else if e(converged) == 0 {
                    if "`fitfailure'" == "marginal" {
                        noisily display as text ///
                            "  Warning: censoring numerator model did not converge; using requested marginal fallback"
                        summarize `censor' if `_numer_complete'
                        gen double `_numer_pr' = r(mean) if `_numer_complete'
                        local ++n_fitfail_fallback
                        local fitfailure_models "`fitfailure_models' censor_numerator"
                    }
                    else {
                        noisily display as error ///
                            "  Censoring numerator model did not converge."
                        noisily display as error ///
                            "  Refusing to substitute a marginal probability by default."
                        noisily display as error ///
                            "  Fix the weighting model or rerun with fitfailure(marginal)."
                        exit 498
                    }
                }
                else {
                    predict double `_numer_pr' if `_numer_complete', pr
                }
            }
        }
        else {
            noisily display as text "  Numerator model:   `censor' ~ `treatment'"
            quietly count if `_numer_complete'
            local _n_numer_complete = r(N)
            if `_n_numer_complete' == 0 {
                gen double `_numer_pr' = .
            }
            else {
                capture logit `censor' `treatment' ///
                    if `_numer_complete', `log_opt'
                local _fit_rc = _rc
                if `_fit_rc' != 0 {
                    if "`fitfailure'" == "marginal" {
                        noisily display as text ///
                            "  Warning: censoring numerator model failed; using requested marginal fallback"
                        summarize `censor' if `_numer_complete'
                        gen double `_numer_pr' = r(mean) if `_numer_complete'
                        local ++n_fitfail_fallback
                        local fitfailure_models "`fitfailure_models' censor_numerator"
                    }
                    else {
                        noisily display as error ///
                            "  Censoring numerator model failed (rc=`_fit_rc')."
                        noisily display as error ///
                            "  Refusing to substitute a marginal probability by default."
                        noisily display as error ///
                            "  Fix the weighting model or rerun with fitfailure(marginal)."
                        exit 498
                    }
                }
                else if e(converged) == 0 {
                    if "`fitfailure'" == "marginal" {
                        noisily display as text ///
                            "  Warning: censoring numerator model did not converge; using requested marginal fallback"
                        summarize `censor' if `_numer_complete'
                        gen double `_numer_pr' = r(mean) if `_numer_complete'
                        local ++n_fitfail_fallback
                        local fitfailure_models "`fitfailure_models' censor_numerator"
                    }
                    else {
                        noisily display as error ///
                            "  Censoring numerator model did not converge."
                        noisily display as error ///
                            "  Refusing to substitute a marginal probability by default."
                        noisily display as error ///
                            "  Fix the weighting model or rerun with fitfailure(marginal)."
                        exit 498
                    }
                }
                else {
                    predict double `_numer_pr' if `_numer_complete', pr
                }
            }
        }
        gen byte `_numer_drop' = `_numer_complete' & missing(`_numer_pr')
        quietly count if `_numer_drop'
        local _n_numer_drop = r(N)
        if `_n_numer_drop' > 0 {
            local n_probability_repairs = `n_probability_repairs' + `_n_numer_drop'
            noisily display as text "  Warning: " as result `_n_numer_drop' as text ///
                " censoring-numerator observation(s) were perfectly predicted; " ///
                "using truncated observed probabilities"
            replace `_numer_pr' = cond(`censor' == 1, `_pr_hi', `_pr_lo') ///
                if `_numer_drop'
        }

        * ---------------------------------------------------------------
        * WEIGHT: P(uncensored|num) / P(uncensored|den)
        *       = (1 - P_num(cens)) / (1 - P_den(cens))
        * ---------------------------------------------------------------
        tempvar _cw_t _miss_cw

        * Truncate extreme censoring probabilities
        replace `_denom_pr' = max(`_denom_pr', `_pr_lo') if `_at_risk' & `outcome' == 0 & !missing(`_denom_pr')
        replace `_denom_pr' = min(`_denom_pr', `_pr_hi') if `_at_risk' & `outcome' == 0 & !missing(`_denom_pr')
        replace `_numer_pr' = max(`_numer_pr', `_pr_lo') if `_at_risk' & `outcome' == 0 & !missing(`_numer_pr')
        replace `_numer_pr' = min(`_numer_pr', `_pr_hi') if `_at_risk' & `outcome' == 0 & !missing(`_numer_pr')

        gen double `_cw_t' = 1
        replace `_cw_t' = (1 - `_numer_pr') / (1 - `_denom_pr') ///
            if `_at_risk' & `outcome' == 0 & !missing(`_denom_pr')

        gen byte `_miss_cw' = `_at_risk' & `outcome' == 0 & ///
            (missing(`censor') | missing(`_denom_pr') | missing(`_numer_pr'))
        quietly count if `_miss_cw'
        if r(N) > 0 {
            noisily display as text "  Warning: " as result r(N) as text ///
                " at-risk observation(s) had missing censoring probabilities; " ///
                "weights set to missing from that period forward"
        }

        * Cumulative product
        tempvar _log_cw _cum_log_cw _cum_miss_cw
        gen double `_log_cw' = ln(`_cw_t') if !`_miss_cw' & !missing(`_cw_t') & `_cw_t' > 0
        replace `_log_cw' = 0 if !`_at_risk' | `outcome' != 0

        bysort `id' (`period'): gen byte `_cum_miss_cw' = (sum(`_miss_cw') > 0)
        bysort `id' (`period'): gen double `_cum_log_cw' = sum(`_log_cw')
        gen double _msm_cw_weight = exp(`_cum_log_cw')
        replace _msm_cw_weight = . if `_cum_miss_cw'

        drop `_at_risk' `_denom_pr' `_numer_pr' `_cw_t' `_miss_cw' ///
            `_log_cw' `_cum_log_cw' `_cum_miss_cw' `_denom_complete' ///
            `_denom_drop' `_numer_complete' `_numer_drop'
    }

    } /* end capture noisily */
    local _rc = _rc

    set varabbrev `_orig_varabbrev'

    if `_rc' exit `_rc'

    local fitfailure_models : list retokenize fitfailure_models
    return scalar n_fitfail_fallback = `n_fitfail_fallback'
    return scalar n_probability_repairs = `n_probability_repairs'
    return local fitfailure_models "`fitfailure_models'"
end
