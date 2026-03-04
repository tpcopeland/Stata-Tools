*! tte_weight Version 1.0.2  2026/02/28
*! Inverse probability weights for target trial emulation
*! Author: Timothy P Copeland
*! Author: Tania F Reza
*! Department of Clinical Neuroscience, Karolinska Institutet
*! Department of Global Public Health, Karolinska Institutet
*! Program class: rclass (returns results in r())

/*
Basic syntax:
  tte_weight, switch_d_cov(varlist) [options]

Description:
  Calculates stabilized inverse probability weights for treatment
  switching (IPTW) and optionally for informative censoring (IPCW).
  Weights account for the artificial censoring introduced by tte_expand.

Options:
  switch_d_cov(varlist)   - Covariates for switch denominator model (required for PP/AT)
  switch_n_cov(varlist)   - Covariates for switch numerator model (stabilized)
  censor_d_cov(varlist)   - Covariates for censoring denominator model
  censor_n_cov(varlist)   - Covariates for censoring numerator model
  pool_switch             - Pool switch models across arms (vs stratified)
  pool_censor             - Pool censor models across arms
  truncate(# #)           - Truncate at percentiles (e.g., truncate(1 99))
  stabilized              - Use stabilized weights (default)
  generate(name)          - Weight variable name (default: _tte_weight)
  replace                 - Replace existing weight variable
  nolog                   - Suppress model iteration log

See help tte_weight for complete documentation
*/

program define tte_weight, rclass
    version 16.0
    set varabbrev off
    set more off

    * =========================================================================
    * SYNTAX PARSING
    * =========================================================================

    syntax , [SWITCH_d_cov(varlist numeric) SWITCH_n_cov(varlist numeric) ///
        CENsor_d_cov(varlist numeric) CENsor_n_cov(varlist numeric) ///
        POOL_switch POOL_censor ///
        TRUNCate(numlist min=2 max=2) STABilized ///
        GENerate(name) REPLACE noLOG]

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
    * DEFAULTS AND VALIDATION
    * =========================================================================

    if "`generate'" == "" local generate "`prefix'weight"
    if "`stabilized'" == "" local stabilized "stabilized"

    * For ITT, weights are not needed (all weights = 1)
    if "`estimand'" == "ITT" {
        display as text "Note: ITT estimand - all weights set to 1 (no artificial censoring)"
        capture confirm variable `generate'
        if _rc == 0 {
            if "`replace'" == "" {
                display as error "variable `generate' already exists; use replace option"
                exit 110
            }
            quietly drop `generate'
        }
        gen double `generate' = 1
        label variable `generate' "Weight (ITT = 1)"

        return scalar mean_weight = 1
        return scalar sd_weight = 0
        return scalar min_weight = 1
        return scalar max_weight = 1
        return scalar ess = _N
        return local generate "`generate'"
        exit
    }

    * PP/AT require switch covariates
    if "`switch_d_cov'" == "" {
        display as error "switch_d_cov() required for `estimand' estimand"
        exit 198
    }

    * Check weight variable
    capture confirm variable `generate'
    if _rc == 0 {
        if "`replace'" == "" {
            display as error "variable `generate' already exists; use replace option"
            exit 110
        }
        quietly drop `generate'
    }

    * Validate truncation
    if "`truncate'" != "" {
        local trunc_lo: word 1 of `truncate'
        local trunc_hi: word 2 of `truncate'
        if `trunc_lo' >= `trunc_hi' {
            display as error "truncate() lower bound must be less than upper bound"
            exit 198
        }
    }

    * =========================================================================
    * DISPLAY HEADER
    * =========================================================================

    display as text ""
    display as text "{hline 70}"
    display as result "tte_weight" as text " - Inverse Probability Weights"
    display as text "{hline 70}"
    display as text ""
    display as text "Estimand:         " as result "`estimand'"
    display as text "Switch denom:     " as result "`switch_d_cov'"
    if "`switch_n_cov'" != "" {
        display as text "Switch numer:     " as result "`switch_n_cov'"
    }
    if "`censor_d_cov'" != "" {
        display as text "Censor denom:     " as result "`censor_d_cov'"
    }
    display as text "Stabilized:       " as result "Yes"
    if "`truncate'" != "" {
        display as text "Truncation:       " as result "`trunc_lo'th - `trunc_hi'th percentile"
    }
    display as text ""

    * =========================================================================
    * WEIGHT CALCULATION
    * =========================================================================

    * We need observations that are NOT censored and NOT events in prior period
    * Work within the expanded data: for each person-trial-arm, compute
    * cumulative weights across follow-up periods

    * Generate the weight variable
    gen double `generate' = 1

    local log_opt ""
    if "`log'" == "nolog" local log_opt "nolog"

    * -----------------------------------------------------------------
    * TREATMENT SWITCH WEIGHTS
    * -----------------------------------------------------------------

    display as text "Fitting treatment switch models..."

    if "`pool_switch'" != "" {
        * Pooled model: single model across arms
        _tte_weight_switch_pooled, id(`id') treatment(`treatment') ///
            arm(`prefix'arm) followup(`prefix'followup) ///
            trial(`prefix'trial) censored(`prefix'censored) ///
            d_cov(`switch_d_cov') n_cov(`switch_n_cov') ///
            weight(`generate') `log_opt'
    }
    else {
        * Stratified models: separate for each arm
        forvalues a = 0/1 {
            display as text "  Switch model for arm `a'..."
            _tte_weight_switch_arm, id(`id') treatment(`treatment') ///
                arm_var(`prefix'arm) arm_val(`a') ///
                followup(`prefix'followup) trial(`prefix'trial) ///
                censored(`prefix'censored) ///
                d_cov(`switch_d_cov') n_cov(`switch_n_cov') ///
                weight(`generate') `log_opt'
        }
    }

    * -----------------------------------------------------------------
    * CENSORING WEIGHTS (optional)
    * -----------------------------------------------------------------

    if "`censor_d_cov'" != "" {
        display as text ""
        display as text "Fitting censoring models..."

        local censor_indicator "`_tte_censor'"
        if "`censor_indicator'" == "" {
            * Use the artificial censoring variable
            local censor_indicator "`prefix'censored"
        }

        if "`pool_censor'" != "" {
            _tte_weight_censor_pooled, id(`id') ///
                censor(`censor_indicator') ///
                arm(`prefix'arm) followup(`prefix'followup) ///
                trial(`prefix'trial) ///
                d_cov(`censor_d_cov') n_cov(`censor_n_cov') ///
                weight(`generate') `log_opt'
        }
        else {
            forvalues a = 0/1 {
                display as text "  Censor model for arm `a'..."
                _tte_weight_censor_arm, id(`id') ///
                    censor(`censor_indicator') ///
                    arm_var(`prefix'arm) arm_val(`a') ///
                    followup(`prefix'followup) trial(`prefix'trial) ///
                    d_cov(`censor_d_cov') n_cov(`censor_n_cov') ///
                    weight(`generate') `log_opt'
            }
        }
    }

    * =========================================================================
    * TRUNCATION
    * =========================================================================

    local n_truncated = 0
    if "`truncate'" != "" {
        display as text ""
        display as text "Truncating weights at `trunc_lo'th and `trunc_hi'th percentiles..."

        quietly {
            _pctile `generate' if !missing(`generate'), percentiles(`trunc_lo' `trunc_hi')
            local lo_val = r(r1)
            local hi_val = r(r2)

            count if `generate' < `lo_val' & !missing(`generate')
            local n_lo = r(N)
            count if `generate' > `hi_val' & !missing(`generate')
            local n_hi = r(N)
            local n_truncated = `n_lo' + `n_hi'

            replace `generate' = `lo_val' if `generate' < `lo_val' & !missing(`generate')
            replace `generate' = `hi_val' if `generate' > `hi_val' & !missing(`generate')
        }

        display as text "  Truncated `n_truncated' observations (`n_lo' low, `n_hi' high)"
    }

    * =========================================================================
    * DIAGNOSTICS
    * =========================================================================

    quietly summarize `generate', detail
    local w_mean = r(mean)
    local w_sd   = r(sd)
    local w_min  = r(min)
    local w_max  = r(max)
    local w_p1   = r(p1)
    local w_p50  = r(p50)
    local w_p99  = r(p99)

    * Effective sample size
    quietly {
        summarize `generate'
        local sum_w = r(sum)
        tempvar _w2
        gen double `_w2' = `generate'^2
        summarize `_w2'
        local sum_w2 = r(sum)
        drop `_w2'
    }
    local ess = (`sum_w'^2) / `sum_w2'

    label variable `generate' "IP weight (`estimand')"

    * Store metadata
    char _dta[_tte_weighted] "1"
    char _dta[_tte_weight_var] "`generate'"

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
    display as text "Effective sample size: " as result %9.1f `ess'
    display as text ""
    display as text "Next step: {cmd:tte_diagnose} or {cmd:tte_fit}"
    display as text "{hline 70}"

    * =========================================================================
    * RETURN RESULTS
    * =========================================================================

    return scalar mean_weight = `w_mean'
    return scalar sd_weight = `w_sd'
    return scalar min_weight = `w_min'
    return scalar max_weight = `w_max'
    return scalar p1_weight = `w_p1'
    return scalar p99_weight = `w_p99'
    return scalar ess = `ess'
    return scalar n_truncated = `n_truncated'

    return local generate "`generate'"
    return local estimand "`estimand'"
end

* =========================================================================
* _tte_weight_switch_arm: Fit switch weight model for one arm
*   Computes stabilized IP weights for treatment switching within an arm
* =========================================================================
program define _tte_weight_switch_arm
    version 16.0
    set varabbrev off
    set more off

    syntax , id(varname) treatment(varname) ///
        arm_var(varname) arm_val(integer) ///
        followup(varname) trial(varname) ///
        censored(varname) ///
        d_cov(varlist) [n_cov(varlist)] ///
        weight(varname) [nolog]

    local log_opt ""
    if "`nolog'" != "" local log_opt "nolog"

    quietly {
        * Work only with observations in this arm, not yet censored
        * We model P(treatment_t | treatment_{t-1}, covariates) at each follow-up
        * Need: current treatment and lagged treatment

        tempvar _lag_treat _in_arm _denom_pr _numer_pr _sw_t

        * Flag rows in this arm
        gen byte `_in_arm' = (`arm_var' == `arm_val')

        * Lagged treatment within person-trial-arm
        bysort `id' `trial' `arm_var' (`followup'): gen byte `_lag_treat' = `treatment'[_n-1] if `_in_arm'

        * Skip first follow-up period (no prior treatment to condition on)
        * Denominator model: P(A_t | A_{t-1}, L)
        capture `log_opt' logit `treatment' `_lag_treat' `d_cov' `followup' if `_in_arm' & !missing(`_lag_treat')
        if _rc != 0 {
            * Model failed - set weights to 1
            gen double `_denom_pr' = 0.5 if `_in_arm'
        }
        else {
            predict double `_denom_pr' if `_in_arm' & !missing(`_lag_treat'), pr
        }

        * Numerator model: P(A_t | A_{t-1}) or P(A_t | A_{t-1}, baseline)
        if "`n_cov'" != "" {
            capture `log_opt' logit `treatment' `_lag_treat' `n_cov' if `_in_arm' & !missing(`_lag_treat')
        }
        else {
            capture `log_opt' logit `treatment' `_lag_treat' if `_in_arm' & !missing(`_lag_treat')
        }
        if _rc != 0 {
            gen double `_numer_pr' = 0.5 if `_in_arm'
        }
        else {
            predict double `_numer_pr' if `_in_arm' & !missing(`_lag_treat'), pr
        }

        * Stabilized weight contribution at each time:
        * If observed treatment = 1: numer/denom
        * If observed treatment = 0: (1-numer)/(1-denom)
        gen double `_sw_t' = 1 if `_in_arm'

        replace `_sw_t' = `_numer_pr' / `_denom_pr' ///
            if `treatment' == 1 & `_in_arm' & !missing(`_denom_pr') & `_denom_pr' > 0.001

        replace `_sw_t' = (1 - `_numer_pr') / (1 - `_denom_pr') ///
            if `treatment' == 0 & `_in_arm' & !missing(`_denom_pr') & `_denom_pr' < 0.999

        * Warn about missing predictions (from missing covariates)
        count if missing(`_sw_t') & `_in_arm' & !missing(`_lag_treat')
        if r(N) > 0 {
            noisily display as text "  Warning: " as result r(N) as text ///
                " obs in arm `arm_val' have missing switch weight covariates"
        }

        * Cumulative product within person-trial
        * Use log-sum approach to avoid numerical issues
        * Only set log=0 for first follow-up (no prior treatment); let
        * truly missing predictions propagate as missing weights
        tempvar _log_sw _cum_log_sw
        gen double `_log_sw' = ln(`_sw_t') if `_in_arm' & !missing(`_sw_t') & `_sw_t' > 0
        replace `_log_sw' = 0 if missing(`_log_sw') & `_in_arm' & missing(`_lag_treat')

        bysort `id' `trial' `arm_var' (`followup'): gen double `_cum_log_sw' = sum(`_log_sw') if `_in_arm'

        * Update weight
        replace `weight' = `weight' * exp(`_cum_log_sw') if `_in_arm' & !missing(`_cum_log_sw')

        drop `_in_arm' `_lag_treat' `_denom_pr' `_numer_pr' `_sw_t' `_log_sw' `_cum_log_sw'
    }
end

* =========================================================================
* _tte_weight_switch_pooled: Fit pooled switch weight model
* =========================================================================
program define _tte_weight_switch_pooled
    version 16.0
    set varabbrev off
    set more off

    syntax , id(varname) treatment(varname) ///
        arm(varname) followup(varname) trial(varname) ///
        censored(varname) ///
        d_cov(varlist) [n_cov(varlist)] ///
        weight(varname) [nolog]

    * Pooled: include arm as covariate in the model
    local log_opt ""
    if "`nolog'" != "" local log_opt "nolog"

    quietly {
        tempvar _lag_treat _denom_pr _numer_pr _sw_t

        bysort `id' `trial' `arm' (`followup'): gen byte `_lag_treat' = `treatment'[_n-1]

        * Denominator: P(A_t | A_{t-1}, L, arm)
        capture `log_opt' logit `treatment' `_lag_treat' `arm' `d_cov' `followup' if !missing(`_lag_treat')
        if _rc != 0 {
            gen double `_denom_pr' = 0.5
        }
        else {
            predict double `_denom_pr' if !missing(`_lag_treat'), pr
        }

        * Numerator: P(A_t | A_{t-1}, arm)
        if "`n_cov'" != "" {
            capture `log_opt' logit `treatment' `_lag_treat' `arm' `n_cov' if !missing(`_lag_treat')
        }
        else {
            capture `log_opt' logit `treatment' `_lag_treat' `arm' if !missing(`_lag_treat')
        }
        if _rc != 0 {
            gen double `_numer_pr' = 0.5
        }
        else {
            predict double `_numer_pr' if !missing(`_lag_treat'), pr
        }

        gen double `_sw_t' = 1
        replace `_sw_t' = `_numer_pr' / `_denom_pr' ///
            if `treatment' == 1 & !missing(`_denom_pr') & `_denom_pr' > 0.001
        replace `_sw_t' = (1 - `_numer_pr') / (1 - `_denom_pr') ///
            if `treatment' == 0 & !missing(`_denom_pr') & `_denom_pr' < 0.999

        * Warn about missing predictions
        count if missing(`_sw_t') & !missing(`_lag_treat')
        if r(N) > 0 {
            noisily display as text "  Warning: " as result r(N) as text ///
                " obs have missing switch weight covariates (pooled model)"
        }

        tempvar _log_sw _cum_log_sw
        gen double `_log_sw' = ln(`_sw_t') if !missing(`_sw_t') & `_sw_t' > 0
        replace `_log_sw' = 0 if missing(`_log_sw') & missing(`_lag_treat')

        bysort `id' `trial' `arm' (`followup'): gen double `_cum_log_sw' = sum(`_log_sw')
        replace `weight' = `weight' * exp(`_cum_log_sw') if !missing(`_cum_log_sw')

        drop `_lag_treat' `_denom_pr' `_numer_pr' `_sw_t' `_log_sw' `_cum_log_sw'
    }
end

* =========================================================================
* _tte_weight_censor_arm: Fit censoring weight model for one arm
* =========================================================================
program define _tte_weight_censor_arm
    version 16.0
    set varabbrev off
    set more off

    syntax , id(varname) censor(varname) ///
        arm_var(varname) arm_val(integer) ///
        followup(varname) trial(varname) ///
        d_cov(varlist) [n_cov(varlist)] ///
        weight(varname) [nolog]

    local log_opt ""
    if "`nolog'" != "" local log_opt "nolog"

    quietly {
        tempvar _in_arm _denom_pr _numer_pr _cw_t
        gen byte `_in_arm' = (`arm_var' == `arm_val')

        * Denominator: P(C_t=0 | L)
        capture `log_opt' logit `censor' `d_cov' `followup' if `_in_arm'
        if _rc != 0 {
            gen double `_denom_pr' = 0.05 if `_in_arm'
        }
        else {
            predict double `_denom_pr' if `_in_arm', pr
        }

        * Numerator
        if "`n_cov'" != "" {
            capture `log_opt' logit `censor' `n_cov' if `_in_arm'
        }
        else {
            capture `log_opt' logit `censor' if `_in_arm'
        }
        if _rc != 0 {
            gen double `_numer_pr' = 0.05 if `_in_arm'
        }
        else {
            predict double `_numer_pr' if `_in_arm', pr
        }

        * Weight for remaining uncensored: (1-numer_cens)/(1-denom_cens)
        gen double `_cw_t' = (1 - `_numer_pr') / (1 - `_denom_pr') if `_in_arm' & `_denom_pr' < 0.999

        * Warn about missing predictions
        count if missing(`_cw_t') & `_in_arm' & !missing(`_denom_pr')
        if r(N) > 0 {
            noisily display as text "  Warning: " as result r(N) as text ///
                " obs in arm `arm_val' have missing censor weight covariates"
        }
        * Only default to 1 when denom_pr >= 0.999 (near-certain censoring)
        replace `_cw_t' = 1 if `_in_arm' & `_denom_pr' >= 0.999 & !missing(`_denom_pr')

        tempvar _log_cw _cum_log_cw
        gen double `_log_cw' = ln(`_cw_t') if `_in_arm' & !missing(`_cw_t')
        replace `_log_cw' = 0 if missing(`_log_cw') & `_in_arm' & missing(`_denom_pr')
        bysort `id' `trial' `arm_var' (`followup'): gen double `_cum_log_cw' = sum(`_log_cw') if `_in_arm'

        replace `weight' = `weight' * exp(`_cum_log_cw') if `_in_arm' & !missing(`_cum_log_cw')

        drop `_in_arm' `_denom_pr' `_numer_pr' `_cw_t' `_log_cw' `_cum_log_cw'
    }
end

* =========================================================================
* _tte_weight_censor_pooled: Fit pooled censoring weight model
* =========================================================================
program define _tte_weight_censor_pooled
    version 16.0
    set varabbrev off
    set more off

    syntax , id(varname) censor(varname) ///
        arm(varname) followup(varname) trial(varname) ///
        d_cov(varlist) [n_cov(varlist)] ///
        weight(varname) [nolog]

    local log_opt ""
    if "`nolog'" != "" local log_opt "nolog"

    quietly {
        tempvar _denom_pr _numer_pr _cw_t

        capture `log_opt' logit `censor' `arm' `d_cov' `followup'
        if _rc != 0 {
            gen double `_denom_pr' = 0.05
        }
        else {
            predict double `_denom_pr', pr
        }

        if "`n_cov'" != "" {
            capture `log_opt' logit `censor' `arm' `n_cov'
        }
        else {
            capture `log_opt' logit `censor' `arm'
        }
        if _rc != 0 {
            gen double `_numer_pr' = 0.05
        }
        else {
            predict double `_numer_pr', pr
        }

        gen double `_cw_t' = (1 - `_numer_pr') / (1 - `_denom_pr') if `_denom_pr' < 0.999

        * Warn about missing predictions
        count if missing(`_cw_t') & !missing(`_denom_pr')
        if r(N) > 0 {
            noisily display as text "  Warning: " as result r(N) as text ///
                " obs have missing censor weight covariates (pooled model)"
        }
        * Only default to 1 when denom_pr >= 0.999 (near-certain censoring)
        replace `_cw_t' = 1 if `_denom_pr' >= 0.999 & !missing(`_denom_pr')

        tempvar _log_cw _cum_log_cw
        gen double `_log_cw' = ln(`_cw_t') if !missing(`_cw_t')
        replace `_log_cw' = 0 if missing(`_log_cw') & missing(`_denom_pr')
        bysort `id' `trial' `arm' (`followup'): gen double `_cum_log_cw' = sum(`_log_cw')

        replace `weight' = `weight' * exp(`_cum_log_cw') if !missing(`_cum_log_cw')

        drop `_denom_pr' `_numer_pr' `_cw_t' `_log_cw' `_cum_log_cw'
    }
end
