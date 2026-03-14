*! tte_plot Version 1.1.1  2026/03/14
*! Visualization for target trial emulation
*! Author: Timothy P Copeland
*! Author: Tania F Reza
*! Department of Clinical Neuroscience, Karolinska Institutet
*! Department of Global Public Health, Karolinska Institutet
*! Program class: rclass (returns results in r())

/*
Basic syntax:
  tte_plot [, type(km|cumhaz|weights|balance|pscore|equipoise) options]

Description:
  Produces diagnostic and results plots for target trial emulation.

Plot types:
  km        - Kaplan-Meier curves by treatment arm (weighted)
  cumhaz    - Cumulative incidence with CIs from tte_predict
  weights   - Weight distribution histograms by arm
  balance   - Love plot (SMD before/after weighting)
  pscore    - Propensity score overlap density plot
  equipoise - Preference score density plot with equipoise zone

Options:
  ci                  - Show confidence intervals
  scheme(string)      - Graph scheme (default: plotplainblind)
  title(string)       - Graph title
  export(filename)    - Export graph to file
  replace             - Replace existing file
  top(#)              - Show top N covariates in balance plot (by |SMD|)

See help tte_plot for complete documentation
*/

program define tte_plot, rclass
    version 16.0
    local _vaset = c(varabbrev)
    set varabbrev off
    set more off

    syntax [, TYPe(string) CI ///
        SCHeme(string) TItle(string) ///
        EXPort(string) REPLACE ///
        BALance_covariates(varlist numeric) ///
        TOP(integer 0)]

    * =========================================================================
    * DEFAULTS
    * =========================================================================

    if "`type'" == "" local type "km"
    if "`scheme'" == "" local scheme "plotplainblind"

    if !inlist("`type'", "km", "cumhaz", "weights", "balance", "pscore", "equipoise") {
        display as error "type() must be km, cumhaz, weights, balance, pscore, or equipoise"
        exit 198
    }

    _tte_check_expanded
    _tte_get_settings

    local prefix "`_tte_prefix'"
    local id "`_tte_id'"

    * =========================================================================
    * KM CURVES
    * =========================================================================

    if "`type'" == "km" {
        if "`title'" == "" local title "Kaplan-Meier Curves by Treatment Arm"

        * Check for weight variable (resolve custom name, fall back to default)
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

        preserve

        * For KM: we need survival time = max follow-up per person-trial-arm
        * and failure indicator
        tempvar _maxfu _event _survtime
        bysort `id' `prefix'trial `prefix'arm: egen int `_maxfu' = max(`prefix'followup)
        bysort `id' `prefix'trial `prefix'arm: egen byte `_event' = max(`prefix'outcome_obs)

        * Keep one row per person-trial-arm
        bysort `id' `prefix'trial `prefix'arm: keep if _n == _N

        gen double `_survtime' = `_maxfu' + 1

        * stset
        if "`weight_var'" != "" {
            stset `_survtime' [pw=`weight_var'], failure(`_event')
        }
        else {
            stset `_survtime', failure(`_event')
        }

        * KM plot
        sts graph, by(`prefix'arm) ///
            title("`title'") ///
            ytitle("Survival probability") ///
            xtitle("Follow-up period") ///
            legend(order(1 "Control (arm=0)" 2 "Treated (arm=1)")) ///
            scheme(`scheme') `ci'

        if "`export'" != "" {
            graph export "`export'", `replace'
            display as text "Graph saved to: " as result "`export'"
        }

        restore
    }

    * =========================================================================
    * CUMULATIVE INCIDENCE
    * =========================================================================

    else if "`type'" == "cumhaz" {
        if "`title'" == "" local title "Cumulative Incidence by Treatment Arm"

        * Need predictions from tte_predict stored in r(predictions)
        * Check if predictions matrix exists
        capture matrix list r(predictions)
        if _rc != 0 {
            display as error "no predictions found; run tte_predict first"
            exit 198
        }

        tempname pred_mat
        matrix `pred_mat' = r(predictions)
        local n_rows = rowsof(`pred_mat')
        local n_cols = colsof(`pred_mat')

        preserve

        * Create dataset from predictions matrix
        clear
        quietly set obs `n_rows'

        quietly gen double time = .
        quietly gen double ci_0 = .
        quietly gen double ci_lo_0 = .
        quietly gen double ci_hi_0 = .
        quietly gen double ci_1 = .
        quietly gen double ci_lo_1 = .
        quietly gen double ci_hi_1 = .

        forvalues i = 1/`n_rows' {
            quietly replace time = `pred_mat'[`i', 1] in `i'
            quietly replace ci_0 = `pred_mat'[`i', 2] in `i'
            quietly replace ci_lo_0 = `pred_mat'[`i', 3] in `i'
            quietly replace ci_hi_0 = `pred_mat'[`i', 4] in `i'
            quietly replace ci_1 = `pred_mat'[`i', 5] in `i'
            quietly replace ci_lo_1 = `pred_mat'[`i', 6] in `i'
            quietly replace ci_hi_1 = `pred_mat'[`i', 7] in `i'
        }

        if "`ci'" != "" {
            twoway (rarea ci_lo_0 ci_hi_0 time, fcolor(navy%20) lwidth(none)) ///
                   (rarea ci_lo_1 ci_hi_1 time, fcolor(cranberry%20) lwidth(none)) ///
                   (line ci_0 time, lcolor(navy) lwidth(medthick)) ///
                   (line ci_1 time, lcolor(cranberry) lwidth(medthick)), ///
                title("`title'") ///
                ytitle("Cumulative incidence") ///
                xtitle("Follow-up period") ///
                legend(order(3 "Control" 4 "Treated") rows(1)) ///
                scheme(`scheme')
        }
        else {
            twoway (line ci_0 time, lcolor(navy) lwidth(medthick)) ///
                   (line ci_1 time, lcolor(cranberry) lwidth(medthick)), ///
                title("`title'") ///
                ytitle("Cumulative incidence") ///
                xtitle("Follow-up period") ///
                legend(order(1 "Control" 2 "Treated") rows(1)) ///
                scheme(`scheme')
        }

        if "`export'" != "" {
            graph export "`export'", `replace'
            display as text "Graph saved to: " as result "`export'"
        }

        restore
    }

    * =========================================================================
    * WEIGHT DISTRIBUTION
    * =========================================================================

    else if "`type'" == "weights" {
        if "`title'" == "" local title "Weight Distribution by Treatment Arm"

        * Resolve weight variable (custom name, then default)
        local weight_var ""
        local _wvar_meta : char _dta[_tte_weight_var]
        if "`_wvar_meta'" != "" {
            capture confirm variable `_wvar_meta'
            if _rc == 0 {
                local weight_var "`_wvar_meta'"
            }
        }
        if "`weight_var'" == "" {
            local weight_var "`prefix'weight"
            capture confirm variable `weight_var'
            if _rc != 0 {
                display as error "no weight variable found; run tte_weight first"
                exit 111
            }
        }

        twoway (kdensity `weight_var' if `prefix'arm == 0, lcolor(navy) lwidth(medthick)) ///
               (kdensity `weight_var' if `prefix'arm == 1, lcolor(cranberry) lwidth(medthick)), ///
            title("`title'") ///
            xtitle("IP Weight") ///
            ytitle("Density") ///
            legend(order(1 "Control" 2 "Treated") rows(1)) ///
            scheme(`scheme')

        if "`export'" != "" {
            graph export "`export'", `replace'
            display as text "Graph saved to: " as result "`export'"
        }
    }

    * =========================================================================
    * LOVE PLOT (Balance)
    * =========================================================================

    else if "`type'" == "balance" {
        if "`title'" == "" local title "Covariate Balance (Love Plot)"

        * Need balance matrix from tte_diagnose
        capture matrix list r(balance)
        if _rc != 0 {
            display as error "no balance matrix found; run tte_diagnose with balance_covariates() first"
            exit 198
        }

        tempname bal_mat
        matrix `bal_mat' = r(balance)
        local n_covs = rowsof(`bal_mat')
        local cov_names: rownames `bal_mat'

        * Top-N filtering: sort by |unweighted SMD| and keep top N
        local n_show = `n_covs'
        if `top' > 0 & `top' < `n_covs' {
            local n_show = `top'
        }

        preserve
        clear
        quietly set obs `n_covs'

        quietly gen str40 covariate = ""
        quietly gen double smd_unwt = .
        quietly gen double smd_wt = .
        gen int orig_order = .

        forvalues i = 1/`n_covs' {
            local cname: word `i' of `cov_names'
            quietly replace covariate = "`cname'" in `i'
            quietly replace smd_unwt = `bal_mat'[`i', 1] in `i'
            quietly replace smd_wt = `bal_mat'[`i', 2] in `i'
            quietly replace orig_order = `i' in `i'
        }

        * Sort by absolute unweighted SMD (descending) and keep top N
        if `top' > 0 & `top' < `n_covs' {
            gsort -smd_unwt
            quietly keep in 1/`n_show'
        }

        * Create y-positions
        gen int ypos = .
        forvalues i = 1/`n_show' {
            quietly replace ypos = `n_show' - `i' + 1 in `i'
        }

        * Label y-axis with covariate names
        forvalues i = 1/`n_show' {
            local yval = `n_show' - `i' + 1
            local cname = covariate[`i']
            label define ypos_lbl `yval' "`cname'", add
        }
        label values ypos ypos_lbl

        twoway (scatter ypos smd_unwt, msymbol(Oh) mcolor(navy) msize(large)) ///
               (scatter ypos smd_wt, msymbol(O) mcolor(cranberry) msize(large)), ///
            title("`title'") ///
            xtitle("Absolute Standardized Mean Difference") ///
            ytitle("") ///
            ylabel(1(1)`n_show', valuelabel angle(0) labsize(small)) ///
            xline(0.1, lpattern(dash) lcolor(gs8)) ///
            legend(order(1 "Unweighted" 2 "Weighted") rows(1)) ///
            scheme(`scheme')

        if "`export'" != "" {
            graph export "`export'", `replace'
            display as text "Graph saved to: " as result "`export'"
        }

        restore
    }

    * =========================================================================
    * PROPENSITY SCORE OVERLAP
    * =========================================================================

    else if "`type'" == "pscore" {
        if "`title'" == "" local title "Propensity Score Distribution by Treatment Arm"

        * Check for PS variable
        local ps_var : char _dta[_tte_pscore_var]
        if "`ps_var'" == "" {
            display as error "no propensity score variable found"
            display as error "run {cmd:tte_weight, save_ps} first"
            exit 198
        }

        capture confirm variable `ps_var'
        if _rc != 0 {
            display as error "propensity score variable `ps_var' not found in dataset"
            exit 111
        }

        twoway (kdensity `ps_var' if `prefix'arm == 0 & !missing(`ps_var'), ///
                    lcolor(navy) lwidth(medthick)) ///
               (kdensity `ps_var' if `prefix'arm == 1 & !missing(`ps_var'), ///
                    lcolor(cranberry) lwidth(medthick)), ///
            title("`title'") ///
            xtitle("Propensity Score") ///
            ytitle("Density") ///
            xline(0.1 0.9, lpattern(dash) lcolor(gs10)) ///
            legend(order(1 "Control" 2 "Treated") rows(1)) ///
            scheme(`scheme')

        if "`export'" != "" {
            graph export "`export'", `replace'
            display as text "Graph saved to: " as result "`export'"
        }
    }

    * =========================================================================
    * EQUIPOISE (Preference Score) PLOT
    * =========================================================================

    else if "`type'" == "equipoise" {
        if "`title'" == "" local title "Preference Score Distribution (Equipoise)"

        * Check for PS variable
        local ps_var : char _dta[_tte_pscore_var]
        if "`ps_var'" == "" {
            display as error "no propensity score variable found"
            display as error "run {cmd:tte_weight, save_ps} first"
            exit 198
        }

        capture confirm variable `ps_var'
        if _rc != 0 {
            display as error "propensity score variable `ps_var' not found in dataset"
            exit 111
        }

        * Compute treatment prevalence
        quietly summarize `prefix'arm if `prefix'followup == 0
        local prevalence = r(mean)
        local logit_prev = ln(`prevalence' / (1 - `prevalence'))

        * Compute preference scores
        preserve
        quietly keep if !missing(`ps_var') & `ps_var' > 0.001 & `ps_var' < 0.999
        tempvar _pref
        quietly gen double `_pref' = invlogit(ln(`ps_var' / (1 - `ps_var')) - `logit_prev')

        twoway (kdensity `_pref' if `prefix'arm == 0, lcolor(navy) lwidth(medthick)) ///
               (kdensity `_pref' if `prefix'arm == 1, lcolor(cranberry) lwidth(medthick)), ///
            title("`title'") ///
            xtitle("Preference Score") ///
            ytitle("Density") ///
            xlabel(0(0.1)1) ///
            xline(0.3 0.7, lpattern(dash) lcolor(gs10)) ///
            legend(order(1 "Control" 2 "Treated") rows(1)) ///
            note("Equipoise zone: [0.3, 0.7]") ///
            scheme(`scheme')

        if "`export'" != "" {
            graph export "`export'", `replace'
            display as text "Graph saved to: " as result "`export'"
        }

        restore
    }

    return local type "`type'"
    return local scheme "`scheme'"

    set varabbrev `_vaset'
end
