*! tte_weight Version 1.2.0  2026/03/15
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
  generate(name)          - Weight variable name (default: _tte_weight)
  replace                 - Replace existing weight variable
  nolog                   - Suppress model iteration log
  save_ps                 - Save propensity scores as permanent variable
  trim_ps(#)              - Trim observations with extreme PS (percentile from each tail)

See help tte_weight for complete documentation
*/

program define tte_weight, rclass
    version 16.0
    local _vaset = c(varabbrev)
    set varabbrev off
    set more off

    * =========================================================================
    * SYNTAX PARSING
    * =========================================================================

    syntax , [SWITCH_d_cov(varlist numeric) SWITCH_n_cov(varlist numeric) ///
        CENsor_d_cov(varlist numeric) CENsor_n_cov(varlist numeric) ///
        POOL_switch POOL_censor ///
        STRata(string) ///
        TRUNCate(numlist min=2 max=2) ///
        GENerate(name) REPLACE noLOG ///
        SAVE_ps TRIM_ps(real 0)]

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

        char _dta[_tte_weighted] "1"
        char _dta[_tte_weight_var] "`generate'"

        return scalar mean_weight = 1
        return scalar sd_weight = 0
        return scalar min_weight = 1
        return scalar max_weight = 1
        return scalar ess = _N
        return local generate "`generate'"
        set varabbrev `_vaset'
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

    * Validate PS trimming
    if `trim_ps' < 0 | `trim_ps' >= 50 {
        display as error "trim_ps() must be between 0 and 50"
        exit 198
    }

    * Validate strata
    if "`strata'" == "" local strata "arm"
    if !inlist("`strata'", "arm", "arm_lag") {
        display as error "strata() must be arm (default) or arm_lag"
        exit 198
    }

    * strata(arm_lag) and pool_switch are contradictory
    if "`strata'" == "arm_lag" & "`pool_switch'" != "" {
        display as error "strata(arm_lag) and pool_switch cannot be combined"
        exit 198
    }

    * =========================================================================
    * PREPARE PS VARIABLE (if save_ps or trim_ps)
    * =========================================================================

    local need_ps = ("`save_ps'" != "" | `trim_ps' > 0)
    local ps_var ""

    if `need_ps' {
        if "`save_ps'" != "" {
            local ps_var "`prefix'pscore"
            capture confirm variable `ps_var'
            if _rc == 0 {
                if "`replace'" == "" {
                    display as error "variable `ps_var' already exists; use replace option"
                    exit 110
                }
                quietly drop `ps_var'
            }
            gen double `ps_var' = .
        }
        else {
            tempvar ps_var
            gen double `ps_var' = .
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
    if "`strata'" == "arm_lag" {
        display as text "Strata:           " as result "arm x lagged treatment (4 models)"
    }
    else {
        display as text "Strata:           " as result "arm (2 models)"
    }
    display as text "Switch denom:     " as result "`switch_d_cov'"
    if "`switch_n_cov'" != "" {
        display as text "Switch numer:     " as result "`switch_n_cov'"
    }
    if "`censor_d_cov'" != "" {
        display as text "Censor denom:     " as result "`censor_d_cov'"
    }
    if "`truncate'" != "" {
        display as text "Truncation:       " as result "`trunc_lo'th - `trunc_hi'th percentile"
    }
    if "`save_ps'" != "" {
        display as text "Save PS:          " as result "Yes (`ps_var')"
    }
    if `trim_ps' > 0 {
        display as text "PS trimming:      " as result "`trim_ps'th percentile from each tail"
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

    local ps_opt ""
    if `need_ps' local ps_opt "pscore(`ps_var')"

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
            weight(`generate') `log_opt' `ps_opt'
    }
    else if "`strata'" == "arm_lag" {
        * 4-stratum models: separate for each (arm, lagged treatment) combination
        * Create lagged treatment variable once
        tempvar _lag_treat_strat
        quietly bysort `id' `prefix'trial `prefix'arm (`prefix'followup): ///
            gen byte `_lag_treat_strat' = `treatment'[_n-1]

        forvalues a = 0/1 {
            forvalues l = 0/1 {
                display as text "  Switch model for arm `a', lag `l'..."
                _tte_weight_switch_stratum, id(`id') treatment(`treatment') ///
                    arm_var(`prefix'arm) arm_val(`a') ///
                    lag_var(`_lag_treat_strat') lag_val(`l') ///
                    followup(`prefix'followup) trial(`prefix'trial) ///
                    d_cov(`switch_d_cov') n_cov(`switch_n_cov') ///
                    weight(`generate') `log_opt' `ps_opt'
            }
        }

        * Convert per-period weights to cumulative product across all strata.
        * Each observation currently holds its per-period factor from its stratum.
        * Compute running product within each person-trial-arm.
        quietly {
            tempvar _log_ppw _cum_log_ppw _miss_ppw
            gen double `_log_ppw' = ln(`generate') if !missing(`generate')
            * First period (missing lag): weight=1, ln(1)=0
            replace `_log_ppw' = 0 if missing(`_lag_treat_strat') & missing(`_log_ppw')

            bysort `id' `prefix'trial `prefix'arm (`prefix'followup): ///
                gen double `_cum_log_ppw' = sum(`_log_ppw')

            * Propagate missing: if any non-first-period weight is missing,
            * all subsequent cumulative weights are undefined
            bysort `id' `prefix'trial `prefix'arm (`prefix'followup): ///
                gen byte `_miss_ppw' = sum(missing(`_log_ppw') & !missing(`_lag_treat_strat'))
            replace `_cum_log_ppw' = . if `_miss_ppw' > 0

            replace `generate' = exp(`_cum_log_ppw') if !missing(`_cum_log_ppw')
            replace `generate' = . if missing(`_cum_log_ppw') & !missing(`_lag_treat_strat')

            drop `_log_ppw' `_cum_log_ppw' `_miss_ppw'
        }

        drop `_lag_treat_strat'
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
                weight(`generate') `log_opt' `ps_opt'
        }
    }

    * -----------------------------------------------------------------
    * PS TRIMMING (before censoring weights and truncation)
    * -----------------------------------------------------------------

    local n_ps_trimmed = 0
    if `trim_ps' > 0 {
        display as text ""
        display as text "Trimming observations with extreme propensity scores..."

        quietly {
            local trim_hi = 100 - `trim_ps'
            _pctile `ps_var' if !missing(`ps_var'), percentiles(`trim_ps' `trim_hi')
            local ps_lo_cut = r(r1)
            local ps_hi_cut = r(r2)

            count if `ps_var' < `ps_lo_cut' & !missing(`ps_var')
            local n_lo_trim = r(N)
            count if `ps_var' > `ps_hi_cut' & !missing(`ps_var')
            local n_hi_trim = r(N)
            local n_ps_trimmed = `n_lo_trim' + `n_hi_trim'

            drop if `ps_var' < `ps_lo_cut' & !missing(`ps_var')
            drop if `ps_var' > `ps_hi_cut' & !missing(`ps_var')
        }

        display as text "  Trimmed `n_ps_trimmed' observations"
        display as text "    Below " as result %7.4f `ps_lo_cut' as text " (`trim_ps'th pctile): " as result `n_lo_trim'
        display as text "    Above " as result %7.4f `ps_hi_cut' as text " (`trim_hi'th pctile): " as result `n_hi_trim'
        display as text ""
        display as text "  {bf:Caution:} In sequential trials, PS trimming at person-period"
        display as text "  level may introduce selection bias. Weight truncation"
        display as text "  ({cmd:truncate()}) is generally preferred."
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
    char _dta[_tte_weight_strata] "`strata'"

    * Store PS metadata if saved
    if "`save_ps'" != "" {
        label variable `ps_var' "Propensity score (switch denominator model)"
        char _dta[_tte_pscore_var] "`ps_var'"
    }

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

    * PS summary if saved
    if "`save_ps'" != "" {
        quietly summarize `ps_var' if !missing(`ps_var')
        local ps_mean = r(mean)
        local ps_sd = r(sd)
        local ps_min = r(min)
        local ps_max = r(max)

        display as text ""
        display as text "Propensity score summary (`ps_var'):"
        display as text "  Mean:     " as result %9.4f `ps_mean'
        display as text "  SD:       " as result %9.4f `ps_sd'
        display as text "  Range:    " as result %9.4f `ps_min' as text " - " as result %9.4f `ps_max'
    }

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

    if `trim_ps' > 0 {
        return scalar n_ps_trimmed = `n_ps_trimmed'
        return scalar ps_lo_cut = `ps_lo_cut'
        return scalar ps_hi_cut = `ps_hi_cut'
    }

    if "`save_ps'" != "" {
        return scalar mean_ps = `ps_mean'
        return scalar sd_ps = `ps_sd'
        return scalar min_ps = `ps_min'
        return scalar max_ps = `ps_max'
    }

    return local generate "`generate'"
    return local estimand "`estimand'"
    return local strata "`strata'"

    set varabbrev `_vaset'
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
        weight(varname) [nolog pscore(varname)]

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
        capture logit `treatment' `_lag_treat' `d_cov' `followup' if `_in_arm' & !missing(`_lag_treat'), `log_opt'
        if _rc != 0 {
            * Model failed - set weights to 1
            noisily display as text "  Warning: switch denominator model for arm `arm_val' did not converge; weights set to 1"
            gen double `_denom_pr' = 0.5 if `_in_arm'
        }
        else {
            predict double `_denom_pr' if `_in_arm' & !missing(`_lag_treat'), pr
        }

        * Save propensity score if requested
        if "`pscore'" != "" {
            replace `pscore' = `_denom_pr' if `_in_arm' & !missing(`_denom_pr')
        }

        * Numerator model: P(A_t | A_{t-1}) or P(A_t | A_{t-1}, baseline)
        if "`n_cov'" != "" {
            capture logit `treatment' `_lag_treat' `n_cov' if `_in_arm' & !missing(`_lag_treat'), `log_opt'
        }
        else {
            capture logit `treatment' `_lag_treat' if `_in_arm' & !missing(`_lag_treat'), `log_opt'
        }
        if _rc != 0 {
            noisily display as text "  Warning: switch numerator model for arm `arm_val' did not converge; weights set to 1"
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
        * Only set log=0 for first follow-up (no prior treatment)
        tempvar _log_sw _cum_log_sw _any_miss_sw
        gen double `_log_sw' = ln(`_sw_t') if `_in_arm' & !missing(`_sw_t') & `_sw_t' > 0
        replace `_log_sw' = 0 if missing(`_log_sw') & `_in_arm' & missing(`_lag_treat')

        bysort `id' `trial' `arm_var' (`followup'): gen double `_cum_log_sw' = sum(`_log_sw') if `_in_arm'

        * Propagate missing: if any non-first-period log_sw is missing,
        * the cumulative weight is undefined — set to missing
        bysort `id' `trial' `arm_var' (`followup'): gen byte `_any_miss_sw' = ///
            sum(missing(`_log_sw') & !missing(`_lag_treat')) if `_in_arm'
        replace `_cum_log_sw' = . if `_any_miss_sw' > 0 & `_in_arm'

        * Update weight
        replace `weight' = `weight' * exp(`_cum_log_sw') if `_in_arm' & !missing(`_cum_log_sw')

        drop `_in_arm' `_lag_treat' `_denom_pr' `_numer_pr' `_sw_t' `_log_sw' `_cum_log_sw' `_any_miss_sw'
    }
end

* =========================================================================
* _tte_weight_switch_stratum: Fit switch weight model for one (arm, lag) stratum
*   4-stratum approach matching R TrialEmulation. Within each stratum,
*   lagged treatment is constant, so the logistic model omits it.
* =========================================================================
program define _tte_weight_switch_stratum
    version 16.0
    set varabbrev off
    set more off

    syntax , id(varname) treatment(varname) ///
        arm_var(varname) arm_val(integer) ///
        lag_var(varname) lag_val(integer) ///
        followup(varname) trial(varname) ///
        d_cov(varlist) [n_cov(varlist)] ///
        weight(varname) [nolog pscore(varname)]

    local log_opt ""
    if "`nolog'" != "" local log_opt "nolog"

    quietly {
        tempvar _in_stratum _denom_pr _numer_pr _sw_t

        * Flag rows in this (arm, lagged treatment) stratum
        gen byte `_in_stratum' = (`arm_var' == `arm_val' & `lag_var' == `lag_val')

        * Check for empty stratum
        count if `_in_stratum'
        if r(N) == 0 {
            noisily display as text "  Note: stratum (arm=`arm_val', lag=`lag_val') is empty; skipping"
            drop `_in_stratum'
            exit
        }

        * Denominator model: P(A_t | L) — no lagged treatment (constant within stratum)
        capture logit `treatment' `d_cov' `followup' if `_in_stratum', `log_opt'
        if _rc != 0 {
            noisily display as text "  Warning: switch denominator for (arm=`arm_val', lag=`lag_val') did not converge; weights set to 1"
            gen double `_denom_pr' = 0.5 if `_in_stratum'
        }
        else {
            predict double `_denom_pr' if `_in_stratum', pr
        }

        * Save propensity score if requested
        if "`pscore'" != "" {
            replace `pscore' = `_denom_pr' if `_in_stratum' & !missing(`_denom_pr')
        }

        * Numerator model
        if "`n_cov'" != "" {
            capture logit `treatment' `n_cov' if `_in_stratum', `log_opt'
        }
        else {
            capture logit `treatment' if `_in_stratum', `log_opt'
        }
        if _rc != 0 {
            noisily display as text "  Warning: switch numerator for (arm=`arm_val', lag=`lag_val') did not converge; weights set to 1"
            gen double `_numer_pr' = 0.5 if `_in_stratum'
        }
        else {
            predict double `_numer_pr' if `_in_stratum', pr
        }

        * Stabilized weight contribution at each time:
        gen double `_sw_t' = 1 if `_in_stratum'

        replace `_sw_t' = `_numer_pr' / `_denom_pr' ///
            if `treatment' == 1 & `_in_stratum' & !missing(`_denom_pr') & `_denom_pr' > 0.001

        replace `_sw_t' = (1 - `_numer_pr') / (1 - `_denom_pr') ///
            if `treatment' == 0 & `_in_stratum' & !missing(`_denom_pr') & `_denom_pr' < 0.999

        * Warn about missing predictions
        count if missing(`_sw_t') & `_in_stratum'
        if r(N) > 0 {
            noisily display as text "  Warning: " as result r(N) as text ///
                " obs in (arm=`arm_val', lag=`lag_val') have missing switch weight covariates"
        }

        * Store per-period weight contribution
        * (Cumulative product computed by caller after all strata are done)
        replace `weight' = `weight' * `_sw_t' if `_in_stratum' & !missing(`_sw_t')

        * Propagate missing: mark weight for downstream cumulation
        replace `weight' = . if `_in_stratum' & missing(`_sw_t')

        drop `_in_stratum' `_denom_pr' `_numer_pr' `_sw_t'
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
        weight(varname) [nolog pscore(varname)]

    * Pooled: include arm as covariate in the model
    local log_opt ""
    if "`nolog'" != "" local log_opt "nolog"

    quietly {
        tempvar _lag_treat _denom_pr _numer_pr _sw_t

        bysort `id' `trial' `arm' (`followup'): gen byte `_lag_treat' = `treatment'[_n-1]

        * Denominator: P(A_t | A_{t-1}, L, arm)
        capture logit `treatment' `_lag_treat' `arm' `d_cov' `followup' if !missing(`_lag_treat'), `log_opt'
        if _rc != 0 {
            noisily display as text "  Warning: pooled switch denominator model did not converge; weights set to 1"
            gen double `_denom_pr' = 0.5
        }
        else {
            predict double `_denom_pr' if !missing(`_lag_treat'), pr
        }

        * Save propensity score if requested
        if "`pscore'" != "" {
            replace `pscore' = `_denom_pr' if !missing(`_denom_pr')
        }

        * Numerator: P(A_t | A_{t-1}, arm)
        if "`n_cov'" != "" {
            capture logit `treatment' `_lag_treat' `arm' `n_cov' if !missing(`_lag_treat'), `log_opt'
        }
        else {
            capture logit `treatment' `_lag_treat' `arm' if !missing(`_lag_treat'), `log_opt'
        }
        if _rc != 0 {
            noisily display as text "  Warning: pooled switch numerator model did not converge; weights set to 1"
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

        tempvar _log_sw _cum_log_sw _any_miss_sw
        gen double `_log_sw' = ln(`_sw_t') if !missing(`_sw_t') & `_sw_t' > 0
        replace `_log_sw' = 0 if missing(`_log_sw') & missing(`_lag_treat')

        bysort `id' `trial' `arm' (`followup'): gen double `_cum_log_sw' = sum(`_log_sw')

        * Propagate missing weights
        bysort `id' `trial' `arm' (`followup'): gen byte `_any_miss_sw' = ///
            sum(missing(`_log_sw') & !missing(`_lag_treat'))
        replace `_cum_log_sw' = . if `_any_miss_sw' > 0

        replace `weight' = `weight' * exp(`_cum_log_sw') if !missing(`_cum_log_sw')

        drop `_lag_treat' `_denom_pr' `_numer_pr' `_sw_t' `_log_sw' `_cum_log_sw' `_any_miss_sw'
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
        capture logit `censor' `d_cov' `followup' if `_in_arm', `log_opt'
        if _rc != 0 {
            noisily display as text "  Warning: censor denominator model for arm `arm_val' did not converge; weights set to 1"
            gen double `_denom_pr' = 0.05 if `_in_arm'
        }
        else {
            predict double `_denom_pr' if `_in_arm', pr
        }

        * Numerator
        if "`n_cov'" != "" {
            capture logit `censor' `n_cov' if `_in_arm', `log_opt'
        }
        else {
            capture logit `censor' if `_in_arm', `log_opt'
        }
        if _rc != 0 {
            noisily display as text "  Warning: censor numerator model for arm `arm_val' did not converge; weights set to 1"
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

        tempvar _log_cw _cum_log_cw _any_miss_cw
        gen double `_log_cw' = ln(`_cw_t') if `_in_arm' & !missing(`_cw_t')
        replace `_log_cw' = 0 if missing(`_log_cw') & `_in_arm' & missing(`_denom_pr')
        bysort `id' `trial' `arm_var' (`followup'): gen double `_cum_log_cw' = sum(`_log_cw') if `_in_arm'

        * Propagate missing censor weights
        bysort `id' `trial' `arm_var' (`followup'): gen byte `_any_miss_cw' = ///
            sum(missing(`_log_cw') & !missing(`_denom_pr')) if `_in_arm'
        replace `_cum_log_cw' = . if `_any_miss_cw' > 0 & `_in_arm'

        replace `weight' = `weight' * exp(`_cum_log_cw') if `_in_arm' & !missing(`_cum_log_cw')

        drop `_in_arm' `_denom_pr' `_numer_pr' `_cw_t' `_log_cw' `_cum_log_cw' `_any_miss_cw'
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

        capture logit `censor' `arm' `d_cov' `followup', `log_opt'
        if _rc != 0 {
            noisily display as text "  Warning: pooled censor denominator model did not converge; weights set to 1"
            gen double `_denom_pr' = 0.05
        }
        else {
            predict double `_denom_pr', pr
        }

        if "`n_cov'" != "" {
            capture logit `censor' `arm' `n_cov', `log_opt'
        }
        else {
            capture logit `censor' `arm', `log_opt'
        }
        if _rc != 0 {
            noisily display as text "  Warning: pooled censor numerator model did not converge; weights set to 1"
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

        tempvar _log_cw _cum_log_cw _any_miss_cw
        gen double `_log_cw' = ln(`_cw_t') if !missing(`_cw_t')
        replace `_log_cw' = 0 if missing(`_log_cw') & missing(`_denom_pr')
        bysort `id' `trial' `arm' (`followup'): gen double `_cum_log_cw' = sum(`_log_cw')

        * Propagate missing censor weights
        bysort `id' `trial' `arm' (`followup'): gen byte `_any_miss_cw' = ///
            sum(missing(`_log_cw') & !missing(`_denom_pr'))
        replace `_cum_log_cw' = . if `_any_miss_cw' > 0

        replace `weight' = `weight' * exp(`_cum_log_cw') if !missing(`_cum_log_cw')

        drop `_denom_pr' `_numer_pr' `_cw_t' `_log_cw' `_cum_log_cw' `_any_miss_cw'
    }
end
