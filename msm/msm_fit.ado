*! msm_fit Version 1.0.0  2026/03/03
*! Weighted outcome model for marginal structural models
*! Author: Timothy P Copeland
*! Department of Clinical Neuroscience, Karolinska Institutet
*! Program class: eclass (returns results in e())

/*
Basic syntax:
  msm_fit [, options]

Description:
  Fits the weighted outcome model for the MSM. Supports pooled logistic
  regression (GLM with binomial family), linear regression, or Cox
  proportional hazards. Robust/sandwich SEs clustered at individual
  level by default.

Options:
  model(string)           - logistic (default) | linear | cox
  outcome_cov(varlist)    - Additional covariates for outcome model
  period_spec(string)     - Period specification: linear | quadratic | cubic | ns(#) | none
                            (default: quadratic)
  cluster(varname)        - Cluster variable (default: id variable)
  bootstrap(#)            - Bootstrap replicates (0 = no bootstrap, default)
  level(#)                - Confidence level (default: 95)
  nolog                   - Suppress iteration log

See help msm_fit for complete documentation
*/

program define msm_fit, eclass
    version 16.0
    set varabbrev off
    set more off

    * =========================================================================
    * SYNTAX PARSING
    * =========================================================================

    syntax , [MODel(string) OUTcome_cov(varlist numeric) ///
        PERiod_spec(string) CLuster(varname) ///
        BOOTstrap(integer 0) Level(cilevel) noLOG]

    * =========================================================================
    * CHECK PREREQUISITES
    * =========================================================================

    _msm_check_prepared
    _msm_check_weighted
    _msm_get_settings

    local id         "`_msm_id'"
    local period     "`_msm_period'"
    local treatment  "`_msm_treatment'"
    local outcome    "`_msm_outcome'"
    local censor     "`_msm_censor'"

    * =========================================================================
    * DEFAULTS
    * =========================================================================

    if "`model'" == "" local model "logistic"
    if "`period_spec'" == "" local period_spec "quadratic"
    if "`cluster'" == "" local cluster "`id'"
    if "`level'" == "" local level 95

    * Validate model type
    if !inlist("`model'", "logistic", "linear", "cox") {
        display as error "model() must be logistic, linear, or cox"
        exit 198
    }

    * Validate period spec
    if regexm("`period_spec'", "^ns\(([0-9]+)\)$") {
        * Natural spline - valid
    }
    else if !inlist("`period_spec'", "linear", "quadratic", "cubic", "none") {
        display as error "period_spec() must be linear, quadratic, cubic, ns(#), or none"
        exit 198
    }

    * =========================================================================
    * BUILD PERIOD SPECIFICATION VARIABLES
    * =========================================================================

    display as text ""
    display as text "{hline 70}"
    display as result "msm_fit" as text " - Weighted Outcome Model"
    display as text "{hline 70}"
    display as text ""

    local time_vars ""
    local time_vars_created ""

    if "`period_spec'" != "none" {
        local time_vars "`period'"

        if inlist("`period_spec'", "quadratic", "cubic") {
            capture drop _msm_period_sq
            gen double _msm_period_sq = `period'^2
            label variable _msm_period_sq "Period squared"
            local time_vars "`time_vars' _msm_period_sq"
            local time_vars_created "`time_vars_created' _msm_period_sq"
        }
        if "`period_spec'" == "cubic" {
            capture drop _msm_period_cu
            gen double _msm_period_cu = `period'^3
            label variable _msm_period_cu "Period cubed"
            local time_vars "`time_vars' _msm_period_cu"
            local time_vars_created "`time_vars_created' _msm_period_cu"
        }
        if regexm("`period_spec'", "^ns\(([0-9]+)\)$") {
            local ns_df = regexs(1)
            _msm_natural_spline `period', df(`ns_df') prefix(_msm_per_ns)
            local time_vars "`_msm_spline_vars'"
            local time_vars_created "`time_vars_created' `_msm_spline_vars'"
            local per_ns_knots "`_msm_spline_knots'"
            local per_ns_df "`_msm_spline_df'"
        }
    }

    * =========================================================================
    * BUILD COVARIATE LIST
    * =========================================================================

    local all_covars "`treatment'"
    if "`time_vars'" != "" {
        local all_covars "`all_covars' `time_vars'"
    }
    if "`outcome_cov'" != "" {
        local all_covars "`all_covars' `outcome_cov'"
    }

    * =========================================================================
    * DISPLAY MODEL INFO
    * =========================================================================

    display as text "Model type:       " as result "`model'"
    display as text "Outcome:          " as result "`outcome'"
    display as text "Treatment var:    " as result "`treatment'"
    display as text "Period spec:      " as result "`period_spec'"
    if "`outcome_cov'" != "" {
        display as text "Covariates:       " as result "`outcome_cov'"
    }
    display as text "Weight var:       " as result "_msm_weight"
    display as text "Cluster var:      " as result "`cluster'"
    if `bootstrap' > 0 {
        display as text "Bootstrap reps:   " as result "`bootstrap'"
    }
    display as text ""

    local log_opt ""
    if "`log'" == "nolog" local log_opt "nolog"

    * =========================================================================
    * MARK ESTIMATION SAMPLE
    * =========================================================================

    * Exclude censored observations if censoring exists
    tempvar _esample
    if "`censor'" != "" {
        gen byte `_esample' = (`censor' == 0 & !missing(_msm_weight))
    }
    else {
        gen byte `_esample' = !missing(_msm_weight)
    }

    * =========================================================================
    * FIT MODEL
    * =========================================================================

    if "`model'" == "logistic" {
        display as text "Fitting pooled logistic regression..."
        display as text ""

        if `bootstrap' > 0 {
            bootstrap, reps(`bootstrap') cluster(`cluster') `log_opt': ///
                glm `outcome' `all_covars' [pw=_msm_weight] if `_esample', ///
                family(binomial) link(logit)
        }
        else {
            glm `outcome' `all_covars' [pw=_msm_weight] if `_esample', ///
                family(binomial) link(logit) ///
                vce(cluster `cluster') level(`level') `log_opt'
        }
    }
    else if "`model'" == "linear" {
        display as text "Fitting weighted linear regression..."
        display as text ""

        if `bootstrap' > 0 {
            bootstrap, reps(`bootstrap') cluster(`cluster') `log_opt': ///
                regress `outcome' `all_covars' [pw=_msm_weight] if `_esample'
        }
        else {
            regress `outcome' `all_covars' [pw=_msm_weight] if `_esample', ///
                vce(cluster `cluster') level(`level')
        }
    }
    else if "`model'" == "cox" {
        display as text "Setting up survival data..."

        * Create interval survival data
        tempvar _time_enter _time_exit _failure
        gen double `_time_enter' = `period'
        gen double `_time_exit' = `period' + 1
        gen byte `_failure' = `outcome'

        stset `_time_exit' [pw=_msm_weight] if `_esample', ///
            enter(`_time_enter') failure(`_failure')

        display as text ""
        display as text "Fitting weighted Cox proportional hazards model..."
        display as text ""

        * Remove period from covariates for Cox (time is the outcome)
        local cox_covars "`treatment'"
        if "`outcome_cov'" != "" {
            local cox_covars "`cox_covars' `outcome_cov'"
        }

        if `bootstrap' > 0 {
            bootstrap, reps(`bootstrap') cluster(`cluster') `log_opt': ///
                stcox `cox_covars'
        }
        else {
            stcox `cox_covars', ///
                vce(cluster `cluster') level(`level') `log_opt'
        }
    }

    * =========================================================================
    * STORE METADATA
    * =========================================================================

    capture drop _msm_esample
    gen byte _msm_esample = e(sample)
    label variable _msm_esample "In estimation sample"

    char _dta[_msm_fitted] "1"
    char _dta[_msm_model] "`model'"
    char _dta[_msm_period_spec] "`period_spec'"
    char _dta[_msm_outcome_cov] "`outcome_cov'"
    char _dta[_msm_per_ns_knots] "`per_ns_knots'"
    char _dta[_msm_per_ns_df] "`per_ns_df'"
    char _dta[_msm_cluster] "`cluster'"
    char _dta[_msm_time_vars] "`time_vars'"

    * =========================================================================
    * DISPLAY SUMMARY
    * =========================================================================

    display as text ""
    display as text "{hline 70}"

    * Treatment effect
    local b_treat = _b[`treatment']
    local se_treat = _se[`treatment']
    local z_treat = `b_treat' / `se_treat'
    local p_treat = 2 * normal(-abs(`z_treat'))

    if "`model'" == "logistic" {
        local or = exp(`b_treat')
        local or_lo = exp(`b_treat' - invnormal((100+`level')/200) * `se_treat')
        local or_hi = exp(`b_treat' + invnormal((100+`level')/200) * `se_treat')

        display as text "Treatment effect (MSM causal estimate):"
        display as text "  Log-odds:   " as result %9.4f `b_treat' ///
            as text " (SE: " as result %7.4f `se_treat' as text ")"
        display as text "  Odds ratio: " as result %9.4f `or' ///
            as text " (`level'% CI: " as result %7.4f `or_lo' ///
            as text " - " as result %7.4f `or_hi' as text ")"
        display as text "  p-value:    " as result %9.4f `p_treat'
    }
    else if "`model'" == "linear" {
        local ci_lo = `b_treat' - invnormal((100+`level')/200) * `se_treat'
        local ci_hi = `b_treat' + invnormal((100+`level')/200) * `se_treat'

        display as text "Treatment effect (MSM causal estimate):"
        display as text "  Coefficient: " as result %9.6f `b_treat' ///
            as text " (SE: " as result %7.6f `se_treat' as text ")"
        display as text "  `level'% CI: " as result %9.6f `ci_lo' ///
            as text " - " as result %9.6f `ci_hi'
        display as text "  p-value:     " as result %9.4f `p_treat'
    }
    else {
        local hr = exp(`b_treat')
        local hr_lo = exp(`b_treat' - invnormal((100+`level')/200) * `se_treat')
        local hr_hi = exp(`b_treat' + invnormal((100+`level')/200) * `se_treat')

        display as text "Treatment effect (MSM causal estimate):"
        display as text "  Log-HR:       " as result %9.4f `b_treat' ///
            as text " (SE: " as result %7.4f `se_treat' as text ")"
        display as text "  Hazard ratio: " as result %9.4f `hr' ///
            as text " (`level'% CI: " as result %7.4f `hr_lo' ///
            as text " - " as result %7.4f `hr_hi' as text ")"
        display as text "  p-value:      " as result %9.4f `p_treat'
    }

    display as text ""
    display as text "Next step: {cmd:msm_predict} for counterfactual predictions"
    display as text "{hline 70}"

    * eclass results stored by glm/regress/stcox automatically
    ereturn local msm_cmd "msm_fit"
    ereturn local msm_model "`model'"
    ereturn local msm_treatment "`treatment'"
    ereturn local msm_period_spec "`period_spec'"
end
