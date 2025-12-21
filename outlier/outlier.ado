*! outlier Version 1.0.0  2025/12/21
*! Outlier detection toolkit with multiple methods
*! Author: Timothy P Copeland
*! Program class: rclass (returns results in r())

/*
DESCRIPTION:
    Comprehensive outlier detection toolkit supporting multiple methods:
    IQR-based, standard deviation, Mahalanobis distance, and influence-based.
    Can flag, winsorize, or exclude outliers with detailed reporting.

SYNTAX:
    outlier varlist [if] [in], [options]

Options:
    method(string)      - Detection method: iqr (default), sd, mahal, influence
    multiplier(real)    - IQR/SD multiplier (default: 1.5 for IQR, 3 for SD)
    maha_p(real)        - Mahalanobis p-value threshold (default: 0.001)
    action(string)      - Action: flag (default), winsorize, exclude
    generate(name)      - Variable prefix for flags/modified values
    replace             - Allow replacing existing variables
    by(varname)         - Detect outliers within groups
    report              - Display detailed report
    xlsx(string)        - Export report to Excel
    sheet(string)       - Excel sheet name

EXAMPLES:
    * Basic IQR outlier detection
    outlier income age bmi

    * SD-based with 2.5 SD threshold
    outlier income, method(sd) multiplier(2.5)

    * Multivariate Mahalanobis distance
    outlier income age bmi, method(mahal) generate(out_)

    * Winsorize outliers
    outlier income, action(winsorize) generate(income_w)

    * Detect within groups
    outlier income, by(region) report

STORED RESULTS:
    r(N)            - Number of observations
    r(n_outliers)   - Number of outliers detected
    r(pct_outliers) - Percentage of outliers
    r(method)       - Detection method used
    r(lower)        - Lower bound (if applicable)
    r(upper)        - Upper bound (if applicable)
*/

program define outlier, rclass
    version 16.0
    set varabbrev off

    * =========================================================================
    * SYNTAX PARSING
    * =========================================================================
    syntax varlist(numeric) [if] [in], ///
        [METHod(string) ///
         MULTiplier(real 0) ///
         MAha_p(real 0.001) ///
         ACTion(string) ///
         GENerate(name) ///
         replace ///
         BY(varname) ///
         REPort ///
         xlsx(string) ///
         sheet(string)]

    * =========================================================================
    * MARK SAMPLE
    * =========================================================================
    marksample touse, novarlist
    if "`by'" != "" markout `touse' `by'

    quietly count if `touse'
    if r(N) == 0 {
        display as error "no observations"
        exit 2000
    }
    local N = r(N)

    * =========================================================================
    * VALIDATE INPUTS AND SET DEFAULTS
    * =========================================================================
    * Set default method
    if "`method'" == "" local method "iqr"

    * Validate method
    if !inlist("`method'", "iqr", "sd", "mahal", "influence") {
        display as error "method() must be: iqr, sd, mahal, or influence"
        exit 198
    }

    * Set default multiplier based on method
    if `multiplier' == 0 {
        if "`method'" == "iqr" local multiplier = 1.5
        else if "`method'" == "sd" local multiplier = 3
        else local multiplier = 1.5
    }

    * Validate multiplier
    if `multiplier' <= 0 {
        display as error "multiplier() must be positive"
        exit 198
    }

    * Set default action
    if "`action'" == "" local action "flag"

    * Validate action
    if !inlist("`action'", "flag", "winsorize", "exclude") {
        display as error "action() must be: flag, winsorize, or exclude"
        exit 198
    }

    * Validate generate for certain actions
    if "`action'" != "flag" & "`generate'" == "" {
        display as error "generate() required with action(`action')"
        exit 198
    }

    * Mahalanobis requires multiple variables
    if "`method'" == "mahal" {
        local nvars : word count `varlist'
        if `nvars' < 2 {
            display as error "mahal method requires at least 2 variables"
            exit 198
        }
    }

    * Validate Excel options
    if "`xlsx'" != "" {
        if !strmatch("`xlsx'", "*.xlsx") {
            display as error "Excel filename must have .xlsx extension"
            exit 198
        }
    }

    if "`sheet'" == "" local sheet "Outliers"

    * Count variables
    local nvars : word count `varlist'

    * =========================================================================
    * INITIALIZE RESULTS
    * =========================================================================
    local total_outliers = 0
    tempname results_mat
    matrix `results_mat' = J(`nvars', 7, .)
    matrix colnames `results_mat' = "N" "Mean" "SD" "Lower" "Upper" "N_Out" "Pct_Out"
    local rownames ""

    * =========================================================================
    * MAIN PROCESSING
    * =========================================================================
    if "`method'" == "mahal" {
        * -----------------------------------------------------------------
        * MAHALANOBIS DISTANCE (multivariate)
        * -----------------------------------------------------------------
        quietly {
            preserve
            keep if `touse'

            * Keep only complete cases
            foreach var of local varlist {
                drop if missing(`var')
            }

            local N_complete = _N

            * Calculate Mahalanobis distance
            tempvar mahal_d
            mahascore `varlist', gen(`mahal_d') unsquared

            * Calculate p-value from chi-square distribution
            tempvar pval
            gen double `pval' = 1 - chi2(`nvars', `mahal_d'^2)

            * Flag outliers
            tempvar is_outlier
            gen byte `is_outlier' = (`pval' < `maha_p')

            count if `is_outlier' == 1
            local n_outliers = r(N)
            local pct_outliers = 100 * `n_outliers' / `N_complete'

            * Get summary stats
            summarize `mahal_d' if `is_outlier' == 1, detail
            local max_mahal = r(max)

            restore
        }

        * Generate flag variable if requested
        if "`generate'" != "" {
            quietly {
                if "`replace'" != "" capture drop `generate'_mahal

                * Re-calculate for full dataset
                preserve
                tempvar mahal_d pval
                mahascore `varlist' if `touse', gen(`mahal_d') unsquared
                gen double `pval' = 1 - chi2(`nvars', `mahal_d'^2) if `touse'
                gen byte `generate'_mahal = (`pval' < `maha_p') if `touse'
                label variable `generate'_mahal "Mahalanobis outlier (p<`maha_p')"
                restore, not
            }
        }

        * Display results
        display as text _n "{hline 60}"
        display as text "Outlier Detection: Mahalanobis Distance"
        display as text "{hline 60}"
        display as text "Variables:         " as result "`varlist'"
        display as text "P-value threshold: " as result %6.4f `maha_p'
        display as text "Observations:      " as result %10.0fc `N'
        display as text "Outliers detected: " as result %10.0fc `n_outliers' ///
            as text " (" as result %5.2f `pct_outliers' as text "%)"
        display as text "{hline 60}"

        * Return results
        return scalar N = `N'
        return scalar n_outliers = `n_outliers'
        return scalar pct_outliers = `pct_outliers'
        return scalar maha_p = `maha_p'
        return local method "mahal"
        return local varlist "`varlist'"
    }
    else if "`method'" == "influence" {
        * -----------------------------------------------------------------
        * INFLUENCE-BASED (Cook's D, leverage, DFBETAS)
        * -----------------------------------------------------------------
        * This requires a regression model - use first var as outcome
        local depvar : word 1 of `varlist'
        local indvars : list varlist - depvar

        if "`indvars'" == "" {
            display as error "influence method requires at least 2 variables (1 outcome, 1+ predictors)"
            exit 198
        }

        quietly {
            preserve
            keep if `touse'

            * Run regression
            regress `depvar' `indvars'
            local N_reg = e(N)
            local k = e(df_m) + 1

            * Calculate influence measures
            tempvar cooksd leverage rstudent
            predict double `cooksd', cooksd
            predict double `leverage', leverage
            predict double `rstudent', rstudent

            * Flag outliers using common cutoffs
            * Cook's D > 4/n
            * Leverage > 2k/n
            * |Studentized residual| > 3
            local cooksd_cut = 4 / `N_reg'
            local lev_cut = 2 * `k' / `N_reg'

            tempvar is_outlier
            gen byte `is_outlier' = (`cooksd' > `cooksd_cut' | ///
                                     `leverage' > `lev_cut' | ///
                                     abs(`rstudent') > 3)

            count if `is_outlier' == 1
            local n_outliers = r(N)
            local pct_outliers = 100 * `n_outliers' / `N_reg'

            * Count by type
            count if `cooksd' > `cooksd_cut'
            local n_cooksd = r(N)
            count if `leverage' > `lev_cut'
            local n_leverage = r(N)
            count if abs(`rstudent') > 3
            local n_rstudent = r(N)

            restore
        }

        * Generate flags if requested
        if "`generate'" != "" {
            quietly {
                if "`replace'" != "" {
                    capture drop `generate'_infl
                    capture drop `generate'_cooksd
                    capture drop `generate'_lev
                }

                regress `depvar' `indvars' if `touse'
                predict double `generate'_cooksd if `touse', cooksd
                predict double `generate'_lev if `touse', leverage

                gen byte `generate'_infl = (`generate'_cooksd > `cooksd_cut' | ///
                                            `generate'_lev > `lev_cut') if `touse'
                label variable `generate'_infl "Influential observation"
                label variable `generate'_cooksd "Cook's D"
                label variable `generate'_lev "Leverage"
            }
        }

        * Display results
        display as text _n "{hline 60}"
        display as text "Outlier Detection: Regression Influence"
        display as text "{hline 60}"
        display as text "Outcome:           " as result "`depvar'"
        display as text "Predictors:        " as result "`indvars'"
        display as text "Observations:      " as result %10.0fc `N'
        display as text "{hline 60}"
        display as text "Cook's D > " %6.4f `cooksd_cut' ": " ///
            as result %10.0fc `n_cooksd'
        display as text "Leverage > " %6.4f `lev_cut' ":  " ///
            as result %10.0fc `n_leverage'
        display as text "|Studentized| > 3:    " ///
            as result %10.0fc `n_rstudent'
        display as text "{hline 60}"
        display as text "Any influential:     " as result %10.0fc `n_outliers' ///
            as text " (" as result %5.2f `pct_outliers' as text "%)"
        display as text "{hline 60}"

        * Return results
        return scalar N = `N'
        return scalar n_outliers = `n_outliers'
        return scalar pct_outliers = `pct_outliers'
        return scalar n_cooksd = `n_cooksd'
        return scalar n_leverage = `n_leverage'
        return scalar n_rstudent = `n_rstudent'
        return local method "influence"
    }
    else {
        * -----------------------------------------------------------------
        * IQR or SD-based (univariate)
        * -----------------------------------------------------------------
        display as text _n "{hline 75}"
        display as text "Outlier Detection: " ///
            cond("`method'" == "iqr", "IQR Method", "Standard Deviation Method")
        display as text "Multiplier: " as result `multiplier'
        display as text "Action: " as result "`action'"
        display as text "{hline 75}"

        * Process by groups if specified
        if "`by'" != "" {
            display as text "By group: " as result "`by'"
        }
        display ""

        * Header
        display as text "{hline 75}"
        display as text %15s "Variable" " {c |}" ///
            %10s "N" %12s "Lower" %12s "Upper" %10s "N Out" %10s "% Out"
        display as text "{hline 75}"

        * Process each variable
        local varnum = 1
        foreach var of local varlist {
            local rownames "`rownames' `var'"

            quietly {
                if "`by'" != "" {
                    * Group-specific bounds
                    tempvar lower upper is_outlier newvar
                    gen double `lower' = .
                    gen double `upper' = .

                    levelsof `by' if `touse', local(groups)
                    foreach g of local groups {
                        if "`method'" == "iqr" {
                            summarize `var' if `touse' & `by' == `g', detail
                            local iqr = r(p75) - r(p25)
                            local lb = r(p25) - `multiplier' * `iqr'
                            local ub = r(p75) + `multiplier' * `iqr'
                        }
                        else {
                            summarize `var' if `touse' & `by' == `g'
                            local lb = r(mean) - `multiplier' * r(sd)
                            local ub = r(mean) + `multiplier' * r(sd)
                        }
                        replace `lower' = `lb' if `by' == `g' & `touse'
                        replace `upper' = `ub' if `by' == `g' & `touse'
                    }
                }
                else {
                    * Overall bounds
                    if "`method'" == "iqr" {
                        summarize `var' if `touse', detail
                        local iqr = r(p75) - r(p25)
                        local lower = r(p25) - `multiplier' * `iqr'
                        local upper = r(p75) + `multiplier' * `iqr'
                    }
                    else {
                        summarize `var' if `touse'
                        local lower = r(mean) - `multiplier' * r(sd)
                        local upper = r(mean) + `multiplier' * r(sd)
                    }
                }

                * Get stats for matrix
                summarize `var' if `touse'
                local var_n = r(N)
                local var_mean = r(mean)
                local var_sd = r(sd)

                * Count outliers
                if "`by'" != "" {
                    count if (`var' < `lower' | `var' > `upper') & `touse' & !missing(`var')
                }
                else {
                    count if (`var' < `lower' | `var' > `upper') & `touse' & !missing(`var')
                }
                local var_nout = r(N)
                local var_pctout = 100 * `var_nout' / `var_n'

                * Store in matrix
                matrix `results_mat'[`varnum', 1] = `var_n'
                matrix `results_mat'[`varnum', 2] = `var_mean'
                matrix `results_mat'[`varnum', 3] = `var_sd'
                if "`by'" == "" {
                    matrix `results_mat'[`varnum', 4] = `lower'
                    matrix `results_mat'[`varnum', 5] = `upper'
                }
                matrix `results_mat'[`varnum', 6] = `var_nout'
                matrix `results_mat'[`varnum', 7] = `var_pctout'

                * Perform action
                if "`action'" == "flag" {
                    if "`generate'" != "" {
                        if "`replace'" != "" capture drop `generate'_`var'

                        if "`by'" != "" {
                            gen byte `generate'_`var' = (`var' < `lower' | `var' > `upper') ///
                                if `touse' & !missing(`var')
                        }
                        else {
                            gen byte `generate'_`var' = (`var' < `lower' | `var' > `upper') ///
                                if `touse' & !missing(`var')
                        }
                        label variable `generate'_`var' "`var' outlier flag"
                    }
                }
                else if "`action'" == "winsorize" {
                    if "`replace'" != "" capture drop `generate'_`var'

                    if "`by'" != "" {
                        gen double `generate'_`var' = ///
                            cond(`var' < `lower', `lower', ///
                                 cond(`var' > `upper', `upper', `var')) if `touse'
                    }
                    else {
                        gen double `generate'_`var' = ///
                            cond(`var' < `lower', `lower', ///
                                 cond(`var' > `upper', `upper', `var')) if `touse'
                    }
                    label variable `generate'_`var' "`var' winsorized"
                }
                else if "`action'" == "exclude" {
                    if "`replace'" != "" capture drop `generate'_`var'

                    if "`by'" != "" {
                        gen double `generate'_`var' = `var' if `touse' & ///
                            !(`var' < `lower' | `var' > `upper')
                    }
                    else {
                        gen double `generate'_`var' = `var' if `touse' & ///
                            !(`var' < `lower' | `var' > `upper')
                    }
                    label variable `generate'_`var' "`var' excl outliers"
                }

                if "`by'" != "" {
                    drop `lower' `upper'
                }
            }

            * Display row
            local varname = abbrev("`var'", 15)
            if "`by'" == "" {
                display as text %15s "`varname'" " {c |}" ///
                    as result %10.0fc `var_n' ///
                    %12.2f `lower' %12.2f `upper' ///
                    %10.0fc `var_nout' %9.2f `var_pctout' "%"
            }
            else {
                display as text %15s "`varname'" " {c |}" ///
                    as result %10.0fc `var_n' ///
                    %12s "(by group)" %12s "(by group)" ///
                    %10.0fc `var_nout' %9.2f `var_pctout' "%"
            }

            local total_outliers = `total_outliers' + `var_nout'
            local varnum = `varnum' + 1
        }

        display as text "{hline 75}"

        * Store row names
        matrix rownames `results_mat' = `rownames'

        * Return results
        return scalar N = `N'
        return scalar n_outliers = `total_outliers'
        return scalar multiplier = `multiplier'
        if "`by'" == "" & `nvars' == 1 {
            return scalar lower = `lower'
            return scalar upper = `upper'
        }
        return matrix results = `results_mat'
        return local method "`method'"
        return local action "`action'"
        return local varlist "`varlist'"
    }

    * =========================================================================
    * EXPORT TO EXCEL
    * =========================================================================
    if "`xlsx'" != "" & "`method'" != "mahal" & "`method'" != "influence" {
        quietly {
            preserve

            * Create export dataset
            clear
            set obs `=`nvars' + 2'

            gen str40 A = ""
            gen str15 B = ""
            gen str15 C = ""
            gen str15 D = ""
            gen str15 E = ""
            gen str15 F = ""
            gen str15 G = ""

            * Title
            replace A = "Outlier Detection Report" in 1

            * Header
            replace A = "Variable" in 2
            replace B = "N" in 2
            replace C = "Mean" in 2
            replace D = "SD" in 2
            replace E = "Lower" in 2
            replace F = "Upper" in 2
            replace G = "N Outliers" in 2

            * Data rows
            local i = 1
            foreach var of local varlist {
                local row = `i' + 2
                replace A = "`var'" in `row'
                replace B = string(`results_mat'[`i', 1], "%10.0fc") in `row'
                replace C = string(`results_mat'[`i', 2], "%10.3f") in `row'
                replace D = string(`results_mat'[`i', 3], "%10.3f") in `row'
                replace E = string(`results_mat'[`i', 4], "%10.3f") in `row'
                replace F = string(`results_mat'[`i', 5], "%10.3f") in `row'
                replace G = string(`results_mat'[`i', 6], "%10.0fc") in `row'
                local i = `i' + 1
            }

            export excel using "`xlsx'", sheet("`sheet'") sheetreplace

            restore

            display as text _n "Report exported to: " as result "`xlsx'"
        }
    }

end
