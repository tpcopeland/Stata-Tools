*! tte_fit Version 1.2.0  2026/03/15
*! Outcome model fitting for target trial emulation
*! Author: Timothy P Copeland
*! Author: Tania F Reza
*! Department of Clinical Neuroscience, Karolinska Institutet
*! Department of Global Public Health, Karolinska Institutet
*! Program class: eclass (returns results in e())

/*
Basic syntax:
  tte_fit, outcome_cov(varlist) [options]

Description:
  Fits the marginal structural model for the target trial emulation.
  Supports pooled logistic regression (default) and weighted Cox
  proportional hazards model.

Options:
  outcome_cov(varlist)      - Covariates for outcome model
  model(string)             - logistic (default) | cox
  model_var(string)         - Treatment variable in model (default: assigned arm)
  trial_period_spec(string) - Trial period specification: linear | quadratic | cubic | ns(#) | none
  followup_spec(string)     - Follow-up specification: same options (default: quadratic)
  robust                    - Robust/sandwich SEs (default: on)
  cluster(varname)          - Cluster variable (default: patient ID)
  level(#)                  - Confidence level (default: 95)
  nolog                     - Suppress iteration log

See help tte_fit for complete documentation
*/

program define tte_fit, eclass
    version 16.0
    local _vaset = c(varabbrev)
    set varabbrev off
    set more off

    * =========================================================================
    * SYNTAX PARSING
    * =========================================================================

    syntax , [OUTcome_cov(string) ///
        MODel(string) MODel_var(string) ///
        TRIal_period_spec(string) FOLLowup_spec(string) ///
        CLuster(varname) ///
        Level(cilevel) noLOG]

    * =========================================================================
    * CHECK PREREQUISITES
    * =========================================================================

    _tte_check_expanded
    _tte_get_settings

    local id         "`_tte_id'"
    local period     "`_tte_period'"
    local treatment  "`_tte_treatment'"
    local outcome    "`_tte_outcome'"
    local estimand   "`_tte_estimand'"
    local prefix     "`_tte_prefix'"

    * =========================================================================
    * DEFAULTS
    * =========================================================================

    if "`model'" == "" local model "logistic"
    if "`model_var'" == "" local model_var "`prefix'arm"

    * Warn if model_var overrides the default treatment variable
    if "`model_var'" != "`prefix'arm" {
        display as error "{bf:Warning:} model_var(`model_var') overrides the"
        display as error "default treatment variable ({cmd:`prefix'arm})."
        display as error "IP weights from {cmd:tte_weight} were estimated for"
        display as error "{cmd:`prefix'arm}. Using a different variable"
        display as error "invalidates the causal interpretation of the weights."
        display as text ""
    }

    if "`trial_period_spec'" == "" local trial_period_spec "quadratic"
    if "`followup_spec'" == "" local followup_spec "quadratic"
    if "`cluster'" == "" local cluster "`id'"
    if "`level'" == "" local level 95

    * Validate model type
    if !inlist("`model'", "logistic", "cox") {
        display as error "model() must be logistic or cox"
        exit 198
    }

    * Validate specs
    foreach spec_name in trial_period_spec followup_spec {
        local spec_val "``spec_name''"
        * Check for ns(#)
        if regexm("`spec_val'", "^ns\(([0-9]+)\)$") {
            * Natural spline - valid
        }
        else if !inlist("`spec_val'", "linear", "quadratic", "cubic", "none") {
            display as error "`spec_name'() must be linear, quadratic, cubic, ns(#), or none"
            exit 198
        }
    }

    * =========================================================================
    * FACTOR VARIABLE EXPANSION
    * =========================================================================

    if "`outcome_cov'" != "" {
        * Check if any token uses factor notation
        * Matches: i.var, ib#.var, ibn.var, i(list).var
        local has_factors = 0
        foreach _tok of local outcome_cov {
            if regexm("`_tok'", "^i(\.|\(|b[0-9]*\.|bn\.)") {
                local has_factors = 1
            }
        }

        if `has_factors' {
            * Auto-load _tte_expand_factors
            capture program list _tte_expand_factors
            if _rc {
                capture findfile _tte_expand_factors.ado
                if _rc == 0 {
                    run "`r(fn)'"
                }
                else {
                    display as error "_tte_expand_factors.ado not found; reinstall tte"
                    exit 111
                }
            }

            _tte_expand_factors, input(`outcome_cov') expanded(outcome_cov)
            display as text "Factor variables expanded: " as result "`outcome_cov'"
        }
        else {
            * Validate as numeric varlist
            foreach _v of local outcome_cov {
                capture confirm numeric variable `_v'
                if _rc != 0 {
                    display as error "variable `_v' not found or not numeric"
                    set varabbrev `_vaset'
                    exit 111
                }
            }
        }
    }

    * =========================================================================
    * CHECK REQUIRED VARIABLES EXIST
    * =========================================================================

    foreach var in `prefix'arm `prefix'followup `prefix'trial `prefix'outcome_obs {
        capture confirm variable `var'
        if _rc != 0 {
            display as error "variable `var' not found; run tte_expand first"
            exit 111
        }
    }

    * Check weight variable (resolve custom name from metadata, fall back to default)
    local weight_var ""
    local _wvar_meta : char _dta[_tte_weight_var]
    if "`_wvar_meta'" != "" {
        capture confirm variable `_wvar_meta'
        if _rc == 0 {
            local weight_var "`_wvar_meta'"
        }
    }
    if "`weight_var'" == "" {
        capture confirm variable `prefix'weight
        if _rc == 0 {
            local weight_var "`prefix'weight"
        }
    }
    if "`weight_var'" == "" {
        * Check if ITT (weights not needed)
        if "`estimand'" != "ITT" {
            display as text "{p}"
            display as text "{bf:Warning:} no weight variable found for `estimand' estimand."
            display as text "Unweighted `estimand' analysis is generally biased."
            display as text "Run {cmd:tte_weight} first, or use {cmd:estimand(ITT)} if intended."
            display as text "{p_end}"
        }
    }

    * =========================================================================
    * BUILD TIME SPECIFICATION VARIABLES
    * =========================================================================

    display as text ""
    display as text "{hline 70}"
    display as result "tte_fit" as text " - Outcome Model"
    display as text "{hline 70}"
    display as text ""

    local time_vars ""
    local time_vars_created ""

    * Follow-up time specification
    local fu_var "`prefix'followup"
    if "`followup_spec'" != "none" {
        local time_vars "`fu_var'"

        if inlist("`followup_spec'", "quadratic", "cubic") {
            capture drop `prefix'followup_sq
            gen double `prefix'followup_sq = `fu_var'^2
            label variable `prefix'followup_sq "Follow-up squared"
            local time_vars "`time_vars' `prefix'followup_sq"
            local time_vars_created "`time_vars_created' `prefix'followup_sq"
        }
        if "`followup_spec'" == "cubic" {
            capture drop `prefix'followup_cu
            gen double `prefix'followup_cu = `fu_var'^3
            label variable `prefix'followup_cu "Follow-up cubed"
            local time_vars "`time_vars' `prefix'followup_cu"
            local time_vars_created "`time_vars_created' `prefix'followup_cu"
        }
        if regexm("`followup_spec'", "^ns\(([0-9]+)\)$") {
            local ns_df = regexs(1)
            _tte_natural_spline `fu_var', df(`ns_df') prefix(`prefix'fu_ns)
            local time_vars "`_tte_spline_vars'"
            local time_vars_created "`time_vars_created' `_tte_spline_vars'"
            local fu_ns_knots "`_tte_spline_knots'"
            local fu_ns_df "`_tte_spline_df'"
        }
    }

    * Trial period specification
    local trial_var "`prefix'trial"
    if "`trial_period_spec'" != "none" {
        local time_vars "`time_vars' `trial_var'"

        if inlist("`trial_period_spec'", "quadratic", "cubic") {
            capture drop `prefix'trial_sq
            gen double `prefix'trial_sq = `trial_var'^2
            label variable `prefix'trial_sq "Trial period squared"
            local time_vars "`time_vars' `prefix'trial_sq"
            local time_vars_created "`time_vars_created' `prefix'trial_sq"
        }
        if "`trial_period_spec'" == "cubic" {
            capture drop `prefix'trial_cu
            gen double `prefix'trial_cu = `trial_var'^3
            label variable `prefix'trial_cu "Trial period cubed"
            local time_vars "`time_vars' `prefix'trial_cu"
            local time_vars_created "`time_vars_created' `prefix'trial_cu"
        }
        if regexm("`trial_period_spec'", "^ns\(([0-9]+)\)$") {
            local ns_df = regexs(1)
            _tte_natural_spline `trial_var', df(`ns_df') prefix(`prefix'tr_ns)
            * Replace trial_var with spline basis (avoid collinearity)
            local time_vars : subinstr local time_vars "`trial_var'" ""
            local time_vars "`time_vars' `_tte_spline_vars'"
            local time_vars_created "`time_vars_created' `_tte_spline_vars'"
            local tr_ns_knots "`_tte_spline_knots'"
            local tr_ns_df "`_tte_spline_df'"
        }
    }

    * =========================================================================
    * FIT MODEL
    * =========================================================================

    * Build covariate list
    local all_covars "`model_var'"
    if "`time_vars'" != "" {
        local all_covars "`all_covars' `time_vars'"
    }
    if "`outcome_cov'" != "" {
        local all_covars "`all_covars' `outcome_cov'"
    }

    * Outcome variable
    local depvar "`prefix'outcome_obs"

    * Display model info
    display as text "Model type:       " as result "`model'"
    display as text "Estimand:         " as result "`estimand'"
    display as text "Outcome:          " as result "`depvar'"
    display as text "Treatment var:    " as result "`model_var'"
    display as text "Follow-up spec:   " as result "`followup_spec'"
    display as text "Trial spec:       " as result "`trial_period_spec'"
    if "`outcome_cov'" != "" {
        display as text "Covariates:       " as result "`outcome_cov'"
    }
    if "`weight_var'" != "" {
        display as text "Weight var:       " as result "`weight_var'"
    }
    display as text "Cluster var:      " as result "`cluster'"
    display as text ""

    local log_opt ""
    if "`log'" == "nolog" local log_opt "nolog"

    if "`model'" == "logistic" {
        * Pooled logistic regression via GLM
        * glm outcome treatment covariates [pw=weight], family(binomial) link(logit) vce(cluster id)
        local weight_spec ""
        if "`weight_var'" != "" {
            local weight_spec "[pw=`weight_var']"
        }

        display as text "Fitting pooled logistic regression..."
        display as text ""

        * Exclude artificially censored observations from outcome model
        * Censored individuals' outcomes are unobserved; IP weights handle
        * the selection bias from their removal
        glm `depvar' `all_covars' `weight_spec' if `prefix'censored == 0, ///
            family(binomial) link(logit) ///
            vce(cluster `cluster') level(`level') `log_opt'
    }
    else if "`model'" == "cox" {
        * Weighted Cox model
        * Need to stset first
        display as text "Setting up survival data..."

        * Create interval (counting process) survival data
        * Each person-period row defines an interval (enter, exit]
        tempvar _time_enter _time_exit _failure _stset_id
        gen double `_time_enter' = `fu_var'
        gen double `_time_exit' = `fu_var' + 1
        gen byte `_failure' = `depvar'

        * Unique person-trial-arm ID for stset
        egen long `_stset_id' = group(`id' `prefix'trial `prefix'arm)

        if "`weight_var'" != "" {
            * With time-varying IP weights, cannot use id() since stset
            * requires weights constant within id. Use enter/exit only.
            stset `_time_exit' [pw=`weight_var'], ///
                enter(`_time_enter') failure(`_failure')
        }
        else {
            stset `_time_exit', id(`_stset_id') ///
                enter(`_time_enter') failure(`_failure')
        }

        display as text ""
        display as text "Fitting Cox proportional hazards model..."
        display as text ""

        * Remove followup time vars from covariates for Cox (time is the outcome)
        * Keep trial period terms (including NS) as covariates
        local cox_covars "`model_var'"
        if "`trial_period_spec'" != "none" {
            if regexm("`trial_period_spec'", "^ns\(([0-9]+)\)$") {
                * NS: use spline basis (includes linear), skip trial_var
                * to avoid collinearity (mirrors logistic fix at line 185)
                if "`tr_ns_df'" != "" {
                    forvalues _j = 1/`tr_ns_df' {
                        local cox_covars "`cox_covars' `prefix'tr_ns`_j'"
                    }
                }
            }
            else {
                local cox_covars "`cox_covars' `trial_var'"
                if inlist("`trial_period_spec'", "quadratic", "cubic") {
                    local cox_covars "`cox_covars' `prefix'trial_sq"
                }
                if "`trial_period_spec'" == "cubic" {
                    local cox_covars "`cox_covars' `prefix'trial_cu"
                }
            }
        }
        if "`outcome_cov'" != "" {
            local cox_covars "`cox_covars' `outcome_cov'"
        }

        * Exclude censored observations from outcome model
        stcox `cox_covars' if `prefix'censored == 0, ///
            vce(cluster `cluster') level(`level') `log_opt'
    }

    * =========================================================================
    * STORE METADATA
    * =========================================================================

    * Store estimation sample indicator for tte_predict
    capture drop `prefix'esample
    gen byte `prefix'esample = e(sample)
    label variable `prefix'esample "In estimation sample"

    char _dta[_tte_fitted] "1"
    char _dta[_tte_model] "`model'"
    char _dta[_tte_model_var] "`model_var'"
    char _dta[_tte_followup_spec] "`followup_spec'"
    char _dta[_tte_trial_spec] "`trial_period_spec'"
    char _dta[_tte_outcome_cov] "`outcome_cov'"
    char _dta[_tte_fu_ns_knots] "`fu_ns_knots'"
    char _dta[_tte_fu_ns_df] "`fu_ns_df'"
    char _dta[_tte_tr_ns_knots] "`tr_ns_knots'"
    char _dta[_tte_tr_ns_df] "`tr_ns_df'"
    char _dta[_tte_cluster] "`cluster'"
    char _dta[_tte_time_vars] "`time_vars'"

    * =========================================================================
    * DISPLAY SUMMARY
    * =========================================================================

    display as text ""
    display as text "{hline 70}"

    * Treatment effect
    local b_treat = _b[`model_var']
    local se_treat = _se[`model_var']
    local z_treat = `b_treat' / `se_treat'
    local p_treat = 2 * normal(-abs(`z_treat'))

    if "`model'" == "logistic" {
        local or = exp(`b_treat')
        local or_lo = exp(`b_treat' - invnormal((100+`level')/200) * `se_treat')
        local or_hi = exp(`b_treat' + invnormal((100+`level')/200) * `se_treat')

        display as text "Treatment effect (assigned arm):"
        display as text "  Log-odds:   " as result %9.4f `b_treat' as text " (SE: " as result %7.4f `se_treat' as text ")"
        display as text "  Odds ratio: " as result %9.4f `or' as text " (`level'% CI: " as result %7.4f `or_lo' as text " - " as result %7.4f `or_hi' as text ")"
        display as text "  p-value:    " as result %9.4f `p_treat'
    }
    else {
        local hr = exp(`b_treat')
        local hr_lo = exp(`b_treat' - invnormal((100+`level')/200) * `se_treat')
        local hr_hi = exp(`b_treat' + invnormal((100+`level')/200) * `se_treat')

        display as text "Treatment effect (assigned arm):"
        display as text "  Log-HR:      " as result %9.4f `b_treat' as text " (SE: " as result %7.4f `se_treat' as text ")"
        display as text "  Hazard ratio: " as result %9.4f `hr' as text " (`level'% CI: " as result %7.4f `hr_lo' as text " - " as result %7.4f `hr_hi' as text ")"
        display as text "  p-value:     " as result %9.4f `p_treat'
    }

    display as text ""
    display as text "Next step: {cmd:tte_predict} for marginal predictions"
    display as text "{hline 70}"

    * eclass results are stored by glm/stcox automatically
    * Add custom e() entries
    ereturn local tte_cmd "tte_fit"
    ereturn local tte_model "`model'"
    ereturn local tte_estimand "`estimand'"
    ereturn local tte_model_var "`model_var'"
    ereturn local tte_followup_spec "`followup_spec'"
    ereturn local tte_trial_spec "`trial_period_spec'"

    set varabbrev `_vaset'
end
