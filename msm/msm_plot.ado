*! msm_plot Version 1.0.0  2026/03/03
*! Visualization for marginal structural models
*! Author: Timothy P Copeland
*! Department of Clinical Neuroscience, Karolinska Institutet
*! Program class: rclass (returns results in r())

/*
Basic syntax:
  msm_plot, type(string) [options]

Plot types:
  weights     - Weight distribution (kdensity by treatment group)
  balance     - Love plot (SMD before/after weighting)
  survival    - Survival/cumulative incidence curves from msm_predict
  trajectory  - Treatment trajectory spaghetti plot
  positivity  - Treatment probability by period

Options:
  covariates(varlist)   - For balance plot
  threshold(#)          - SMD threshold for balance (default: 0.1)
  times(numlist)        - For survival plot
  samples(#)            - MC samples for survival (default: 50)
  seed(#)               - Random seed for survival
  n_sample(#)           - Number of individuals for trajectory (default: 50)
  title(string)         - Custom title
  saving(string)        - Save graph to file
  replace               - Replace existing file

See help msm_plot for complete documentation
*/

program define msm_plot, rclass
    version 16.0
    local _varabbrev = c(varabbrev)
    local _more = c(more)
    set varabbrev off
    set more off

    syntax , TYPe(string) ///
        [COVariates(varlist numeric) THReshold(real 0.1) ///
         TIMEs(numlist sort integer >=0) SAMPles(integer 50) SEED(integer -1) ///
         N_sample(integer 50) ///
         TITle(string) SAVing(string) REPLACE]

    _msm_check_prepared
    _msm_get_settings

    local id         "`_msm_id'"
    local period     "`_msm_period'"
    local treatment  "`_msm_treatment'"
    local outcome    "`_msm_outcome'"

    if !inlist("`type'", "weights", "balance", "survival", "trajectory", "positivity") {
        display as error "type() must be weights, balance, survival, trajectory, or positivity"
        exit 198
    }

    local save_opts ""
    if "`saving'" != "" {
        if "`replace'" != "" {
            local save_opts `"saving("`saving'", replace)"'
        }
        else {
            local save_opts `"saving("`saving'")"'
        }
    }

    * =========================================================================
    * WEIGHTS PLOT
    * =========================================================================

    if "`type'" == "weights" {
        _msm_check_weighted

        if "`title'" == "" local title "IP Weight Distribution by Treatment Group"

        twoway (kdensity _msm_weight if `treatment' == 0, ///
                lcolor(navy) lwidth(medthick)) ///
               (kdensity _msm_weight if `treatment' == 1, ///
                lcolor(cranberry) lwidth(medthick) lpattern(dash)), ///
            legend(order(1 "Untreated" 2 "Treated") ///
                position(1) ring(0) cols(1)) ///
            xtitle("IP Weight") ytitle("Density") ///
            title("`title'") ///
            scheme(plotplainblind) `save_opts'
    }

    * =========================================================================
    * BALANCE PLOT (Love Plot)
    * =========================================================================

    else if "`type'" == "balance" {
        _msm_check_weighted

        if "`covariates'" == "" {
            local covariates "`_msm_covariates' `_msm_bl_covs'"
            local covariates = strtrim("`covariates'")
        }
        if "`covariates'" == "" {
            display as error "no covariates specified for balance plot"
            exit 198
        }

        if "`title'" == "" local title "Covariate Balance (Love Plot)"

        local n_covs : word count `covariates'

        * Compute SMDs on original data (no preserve needed)
        local i = 0
        foreach var of local covariates {
            local ++i
            _msm_smd `var', treatment(`treatment')
            local uw_`i' = `_msm_smd_value'
            _msm_smd `var', treatment(`treatment') weight(_msm_weight)
            local w_`i' = `_msm_smd_value'
        }

        * Build plotting dataset
        preserve
        quietly {
            clear
            set obs `n_covs'
            gen str40 covariate = ""
            gen double smd_uw = .
            gen double smd_w = .
            gen int plot_order = _N - _n + 1
        }

        forvalues i = 1/`n_covs' {
            local var : word `i' of `covariates'
            local abbrev_var = abbrev("`var'", 20)
            quietly {
                replace covariate = "`abbrev_var'" in `i'
                replace smd_uw = abs(`uw_`i'') in `i'
                replace smd_w = abs(`w_`i'') in `i'
            }
        }

        * Build y-axis labels with covariate names
        local ylabels ""
        forvalues j = 1/`n_covs' {
            local cname : word `j' of `covariates'
            local cname = abbrev("`cname'", 15)
            local plot_pos = `n_covs' - `j' + 1
            local ylabels `"`ylabels' `plot_pos' "`cname'""'
        }

        twoway (scatter plot_order smd_uw, msymbol(Oh) mcolor(navy) msize(medium)) ///
               (scatter plot_order smd_w, msymbol(Sh) mcolor(cranberry) msize(medium)), ///
            xline(`threshold', lcolor(gs10) lpattern(dash)) ///
            ylabel(`ylabels', angle(0) labsize(small)) ///
            xlabel(0(0.1)0.5) ///
            legend(order(1 "Unweighted" 2 "Weighted") position(4) ring(0)) ///
            xtitle("Absolute Standardized Mean Difference") ///
            ytitle("") ///
            title("`title'") ///
            scheme(plotplainblind) `save_opts'

        restore
    }

    * =========================================================================
    * SURVIVAL PLOT
    * =========================================================================

    else if "`type'" == "survival" {
        _msm_check_fitted

        if "`times'" == "" {
            display as error "times() required for survival plot"
            exit 198
        }

        if "`title'" == "" local title "Counterfactual Cumulative Incidence"

        local seed_opt ""
        if `seed' >= 0 local seed_opt "seed(`seed')"

        * Run predictions
        msm_predict, times(`times') type(cum_inc) ///
            samples(`samples') `seed_opt'

        * Extract results from r(predictions)
        tempname pred_mat
        matrix `pred_mat' = r(predictions)
        local n_times = r(n_times)

        * Build plot data
        preserve
        quietly {
            clear
            set obs `n_times'
            gen double time = .
            gen double ci_never = .
            gen double ci_always = .
            gen double ci_lo_never = .
            gen double ci_hi_never = .
            gen double ci_lo_always = .
            gen double ci_hi_always = .

            forvalues i = 1/`n_times' {
                replace time = `pred_mat'[`i', 1] in `i'
                replace ci_never = `pred_mat'[`i', 2] in `i'
                replace ci_lo_never = `pred_mat'[`i', 3] in `i'
                replace ci_hi_never = `pred_mat'[`i', 4] in `i'
                replace ci_always = `pred_mat'[`i', 5] in `i'
                replace ci_lo_always = `pred_mat'[`i', 6] in `i'
                replace ci_hi_always = `pred_mat'[`i', 7] in `i'
            }
        }

        twoway (rarea ci_lo_never ci_hi_never time, ///
                color(navy%20) lwidth(none)) ///
               (rarea ci_lo_always ci_hi_always time, ///
                color(cranberry%20) lwidth(none)) ///
               (connected ci_never time, lcolor(navy) mcolor(navy) ///
                lwidth(medthick) msymbol(O)) ///
               (connected ci_always time, lcolor(cranberry) mcolor(cranberry) ///
                lwidth(medthick) msymbol(S) lpattern(dash)), ///
            legend(order(3 "Never treated" 4 "Always treated") ///
                position(11) ring(0) cols(1)) ///
            xtitle("Period") ytitle("Cumulative Incidence") ///
            title("`title'") ///
            scheme(plotplainblind) `save_opts'

        restore
    }

    * =========================================================================
    * TRAJECTORY PLOT
    * =========================================================================

    else if "`type'" == "trajectory" {
        if "`title'" == "" local title "Treatment Trajectories"

        preserve
        quietly {
            * Sample individuals
            tempvar _id_tag _rand _selected
            bysort `id': gen byte `_id_tag' = (_n == 1)
            gen double `_rand' = runiform() if `_id_tag'
            sort `_rand'
            gen byte `_selected' = (_n <= `n_sample') & `_id_tag'
            * Get selected IDs
            tempvar _sel_id
            bysort `id': egen byte `_sel_id' = max(`_selected')
            keep if `_sel_id'
            drop `_id_tag' `_rand' `_selected' `_sel_id'
        }

        twoway (line `treatment' `period', connect(ascending) ///
                by(`id', compact note("") cols(10) ///
                title("`title'") ///
                ) ///
                lcolor(navy%60) lwidth(thin)), ///
            xtitle("Period") ytitle("Treatment") ///
            ylabel(0 1) ///
            scheme(plotplainblind) `save_opts'

        restore
    }

    * =========================================================================
    * POSITIVITY PLOT
    * =========================================================================

    else if "`type'" == "positivity" {
        if "`title'" == "" local title "Treatment Probability by Period"

        preserve
        quietly {
            collapse (mean) treat_prob = `treatment' (count) n = `treatment', by(`period')
        }

        twoway (connected treat_prob `period', lcolor(navy) mcolor(navy) ///
                lwidth(medthick) msymbol(O)), ///
            yline(0.5, lcolor(gs10) lpattern(dash)) ///
            ylabel(0(0.1)1) ///
            xtitle("Period") ytitle("Treatment Probability") ///
            title("`title'") ///
            scheme(plotplainblind) `save_opts'

        restore
    }

    return local plot_type "`type'"

    set varabbrev `_varabbrev'
    set more `_more'
end
