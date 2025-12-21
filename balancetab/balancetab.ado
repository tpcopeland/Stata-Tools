*! balancetab Version 1.0.0  2025/12/21
*! Propensity score balance diagnostics with standardized mean differences
*! Author: Timothy P Copeland
*! Program class: rclass (returns results in r())

/*
DESCRIPTION:
    Calculates and displays covariate balance diagnostics for propensity score
    analysis. Computes standardized mean differences (SMD) before and after
    matching/weighting, generates Love plots, and exports balance tables.

SYNTAX:
    balancetab varlist [if] [in], TREATment(varname) [options]

Required:
    varlist             - Covariates to assess balance for
    treatment(varname)  - Binary treatment indicator (0/1)

Options:
    wvar(varname)       - Weight variable (e.g., IPTW weights)
    strata(varname)     - Strata variable for stratified analysis
    matched             - Indicates data has been matched (use with matched data)
    threshold(real)     - SMD threshold for imbalance (default: 0.1)
    xlsx(string)        - Export balance table to Excel
    sheet(string)       - Excel sheet name (default: "Balance")
    loveplot            - Generate Love plot
    saving(string)      - Save Love plot to file
    format(string)      - Display format for SMD (default: %6.3f)
    title(string)       - Title for output/plot

EXAMPLES:
    * Basic balance check (unadjusted)
    balancetab age male bmi, treatment(treated)

    * With IPTW weights
    balancetab age male bmi, treatment(treated) wvar(ipw)

    * With matched data
    balancetab age male bmi, treatment(treated) matched

    * Export to Excel with Love plot
    balancetab age male bmi, treatment(treated) wvar(ipw) ///
        xlsx(balance.xlsx) loveplot saving(loveplot.png)

STORED RESULTS:
    r(N_treated)    - Number in treatment group
    r(N_control)    - Number in control group
    r(max_smd_raw)  - Maximum SMD before adjustment
    r(max_smd_adj)  - Maximum SMD after adjustment (if applicable)
    r(n_imbalanced) - Number of covariates exceeding threshold
    r(balance)      - Matrix of balance statistics
*/

program define balancetab, rclass
    version 16.0
    set varabbrev off

    * =========================================================================
    * SYNTAX PARSING
    * =========================================================================
    syntax varlist(numeric) [if] [in], ///
        TREATment(varname) ///
        [Wvar(varname) ///
         STRata(varname) ///
         MATCHed ///
         THReshold(real 0.1) ///
         xlsx(string) ///
         sheet(string) ///
         LOVEplot ///
         SAVing(string) ///
         Format(string) ///
         TItle(string)]

    * =========================================================================
    * MARK SAMPLE
    * =========================================================================
    marksample touse
    markout `touse' `treatment'
    if "`wvar'" != "" markout `touse' `wvar'
    if "`strata'" != "" markout `touse' `strata'

    quietly count if `touse'
    if r(N) == 0 {
        display as error "no observations"
        exit 2000
    }
    local N = r(N)

    * =========================================================================
    * VALIDATE INPUTS
    * =========================================================================
    * Validate treatment is binary
    capture assert inlist(`treatment', 0, 1) if `touse'
    if _rc {
        display as error "treatment() must be binary (0/1)"
        exit 198
    }

    * Check for variation in treatment
    quietly tab `treatment' if `touse'
    if r(r) != 2 {
        display as error "treatment() must have exactly 2 levels"
        exit 198
    }

    * Validate weights if specified
    if "`wvar'" != "" {
        quietly summarize `wvar' if `touse'
        if r(min) < 0 {
            display as error "weights cannot be negative"
            exit 198
        }
    }

    * Validate threshold
    if `threshold' <= 0 {
        display as error "threshold() must be positive"
        exit 198
    }

    * Validate Excel options
    if "`xlsx'" != "" {
        if !strmatch("`xlsx'", "*.xlsx") {
            display as error "Excel filename must have .xlsx extension"
            exit 198
        }
        if regexm("`xlsx'", "[;&|><\$\`]") {
            display as error "Excel filename contains invalid characters"
            exit 198
        }
    }

    * =========================================================================
    * SET DEFAULTS
    * =========================================================================
    if "`format'" == "" local format "%6.3f"
    if "`sheet'" == "" local sheet "Balance"
    if "`title'" == "" local title "Covariate Balance Assessment"

    * Count covariates
    local nvars : word count `varlist'

    * =========================================================================
    * CALCULATE BALANCE STATISTICS
    * =========================================================================
    preserve
    quietly keep if `touse'

    * Get treatment/control counts
    quietly count if `treatment' == 1
    local n_treated = r(N)
    quietly count if `treatment' == 0
    local n_control = r(N)

    * Create results matrix
    tempname balance_mat
    matrix `balance_mat' = J(`nvars', 6, .)
    matrix colnames `balance_mat' = "Mean_T" "Mean_C" "SMD_Raw" "Mean_T_Adj" "Mean_C_Adj" "SMD_Adj"
    local rownames ""

    * Calculate balance for each covariate
    local i = 1
    foreach var of local varlist {
        local rownames "`rownames' `var'"

        * -----------------------------------------------------------------
        * Raw (unadjusted) statistics
        * -----------------------------------------------------------------
        quietly summarize `var' if `treatment' == 1
        local mean_t = r(mean)
        local sd_t = r(sd)
        local var_t = r(Var)

        quietly summarize `var' if `treatment' == 0
        local mean_c = r(mean)
        local sd_c = r(sd)
        local var_c = r(Var)

        * Calculate pooled SD
        local sd_pooled = sqrt((`var_t' + `var_c') / 2)

        * Calculate raw SMD
        if `sd_pooled' > 0 {
            local smd_raw = (`mean_t' - `mean_c') / `sd_pooled'
        }
        else {
            local smd_raw = 0
        }

        matrix `balance_mat'[`i', 1] = `mean_t'
        matrix `balance_mat'[`i', 2] = `mean_c'
        matrix `balance_mat'[`i', 3] = `smd_raw'

        * -----------------------------------------------------------------
        * Adjusted statistics (weighted or matched)
        * -----------------------------------------------------------------
        if "`wvar'" != "" | "`matched'" != "" {
            if "`wvar'" != "" {
                * Weighted means
                quietly summarize `var' [aw=`wvar'] if `treatment' == 1
                local mean_t_adj = r(mean)

                quietly summarize `var' [aw=`wvar'] if `treatment' == 0
                local mean_c_adj = r(mean)
            }
            else {
                * Matched data uses same means (already matched)
                local mean_t_adj = `mean_t'
                local mean_c_adj = `mean_c'
            }

            * Calculate adjusted SMD using raw pooled SD (standard practice)
            if `sd_pooled' > 0 {
                local smd_adj = (`mean_t_adj' - `mean_c_adj') / `sd_pooled'
            }
            else {
                local smd_adj = 0
            }

            matrix `balance_mat'[`i', 4] = `mean_t_adj'
            matrix `balance_mat'[`i', 5] = `mean_c_adj'
            matrix `balance_mat'[`i', 6] = `smd_adj'
        }

        local i = `i' + 1
    }
    matrix rownames `balance_mat' = `rownames'

    restore

    * =========================================================================
    * CALCULATE SUMMARY STATISTICS
    * =========================================================================
    * Maximum absolute SMD
    local max_smd_raw = 0
    local max_smd_adj = 0
    local n_imbalanced = 0

    forvalues i = 1/`nvars' {
        local abs_smd_raw = abs(`balance_mat'[`i', 3])
        if `abs_smd_raw' > `max_smd_raw' local max_smd_raw = `abs_smd_raw'

        if "`wvar'" != "" | "`matched'" != "" {
            local abs_smd_adj = abs(`balance_mat'[`i', 6])
            if `abs_smd_adj' > `max_smd_adj' local max_smd_adj = `abs_smd_adj'
            if `abs_smd_adj' > `threshold' local n_imbalanced = `n_imbalanced' + 1
        }
        else {
            if `abs_smd_raw' > `threshold' local n_imbalanced = `n_imbalanced' + 1
        }
    }

    * =========================================================================
    * DISPLAY OUTPUT
    * =========================================================================
    display as text _n "{hline 75}"
    display as text "`title'"
    display as text "{hline 75}"
    display as text "Treatment:     " as result "`treatment'"
    display as text "N (treated):   " as result %10.0fc `n_treated'
    display as text "N (control):   " as result %10.0fc `n_control'
    if "`wvar'" != "" {
        display as text "Weights:       " as result "`wvar'"
    }
    if "`matched'" != "" {
        display as text "Matched:       " as result "Yes"
    }
    display as text "Threshold:     " as result %6.3f `threshold'
    display as text "{hline 75}"
    display ""

    * Display balance table header
    if "`wvar'" != "" | "`matched'" != "" {
        display as text "{hline 75}"
        display as text %20s "Covariate" " {c |}" ///
            %12s "SMD Raw" %12s "SMD Adj" %12s "Status"
        display as text "{hline 75}"
    }
    else {
        display as text "{hline 55}"
        display as text %20s "Covariate" " {c |}" %12s "SMD Raw" %12s "Status"
        display as text "{hline 55}"
    }

    * Display each covariate
    local i = 1
    foreach var of local varlist {
        local smd_raw = `balance_mat'[`i', 3]

        if "`wvar'" != "" | "`matched'" != "" {
            local smd_adj = `balance_mat'[`i', 6]
            local abs_smd = abs(`smd_adj')
        }
        else {
            local abs_smd = abs(`smd_raw')
        }

        * Determine balance status
        if `abs_smd' <= `threshold' {
            local status "Balanced"
            local status_color "as result"
        }
        else {
            local status "IMBALANCED"
            local status_color "as error"
        }

        * Truncate variable name if too long
        local varname = abbrev("`var'", 20)

        if "`wvar'" != "" | "`matched'" != "" {
            display as text %20s "`varname'" " {c |}" ///
                as result `format' `smd_raw' ///
                as result `format' `smd_adj' ///
                `status_color' %12s "`status'"
        }
        else {
            display as text %20s "`varname'" " {c |}" ///
                as result `format' `smd_raw' ///
                `status_color' %12s "`status'"
        }

        local i = `i' + 1
    }

    if "`wvar'" != "" | "`matched'" != "" {
        display as text "{hline 75}"
    }
    else {
        display as text "{hline 55}"
    }

    * Summary
    display ""
    display as text "Maximum |SMD| (raw):      " as result `format' `max_smd_raw'
    if "`wvar'" != "" | "`matched'" != "" {
        display as text "Maximum |SMD| (adjusted): " as result `format' `max_smd_adj'
    }
    display as text "Covariates > threshold:   " as result %3.0f `n_imbalanced' " of " %3.0f `nvars'
    display as text "{hline 75}"

    * =========================================================================
    * LOVE PLOT
    * =========================================================================
    if "`loveplot'" != "" {
        quietly {
            preserve

            * Create dataset for plotting
            clear
            set obs `nvars'
            gen str40 covariate = ""
            gen smd_raw = .
            gen smd_adj = .
            gen order = _n

            local i = 1
            foreach var of local varlist {
                replace covariate = "`var'" in `i'
                replace smd_raw = `balance_mat'[`i', 3] in `i'
                if "`wvar'" != "" | "`matched'" != "" {
                    replace smd_adj = `balance_mat'[`i', 6] in `i'
                }
                local i = `i' + 1
            }

            * Sort by raw SMD for visualization
            gsort -smd_raw
            replace order = _n

            * Generate plot
            local plotopts "xline(-`threshold' `threshold', lcolor(red) lpattern(dash))"
            local plotopts "`plotopts' xline(0, lcolor(gs8) lpattern(solid))"
            local plotopts "`plotopts' ylabel(1(1)`nvars', valuelabel angle(0) labsize(small))"
            local plotopts "`plotopts' xlabel(-1(.25)1)"
            local plotopts "`plotopts' ytitle("") xtitle("Standardized Mean Difference")"
            local plotopts "`plotopts' title("`title'")"
            local plotopts "`plotopts' legend(order(1 "Unadjusted" 2 "Adjusted") rows(1))"

            encode covariate, gen(covar_num)

            if "`wvar'" != "" | "`matched'" != "" {
                twoway (scatter order smd_raw, msymbol(circle) mcolor(navy)) ///
                       (scatter order smd_adj, msymbol(diamond) mcolor(cranberry)), ///
                       `plotopts' name(loveplot, replace)
            }
            else {
                twoway (scatter order smd_raw, msymbol(circle) mcolor(navy)), ///
                       `plotopts' legend(off) name(loveplot, replace)
            }

            * Save if requested
            if "`saving'" != "" {
                graph export "`saving'", replace
            }

            restore
        }
    }

    * =========================================================================
    * EXPORT TO EXCEL
    * =========================================================================
    if "`xlsx'" != "" {
        quietly {
            preserve

            * Create export dataset
            clear
            set obs `=`nvars' + 3'

            gen str40 A = ""
            gen str15 B = ""
            gen str15 C = ""
            gen str15 D = ""
            gen str15 E = ""
            gen str15 F = ""
            gen str15 G = ""

            * Title row
            replace A = "`title'" in 1

            * Header row
            replace A = "Covariate" in 2
            replace B = "Mean (Treated)" in 2
            replace C = "Mean (Control)" in 2
            replace D = "SMD (Raw)" in 2
            if "`wvar'" != "" | "`matched'" != "" {
                replace E = "Mean (T, Adj)" in 2
                replace F = "Mean (C, Adj)" in 2
                replace G = "SMD (Adj)" in 2
            }

            * Data rows
            local i = 1
            foreach var of local varlist {
                local row = `i' + 2
                replace A = "`var'" in `row'
                replace B = string(`balance_mat'[`i', 1], "`format'") in `row'
                replace C = string(`balance_mat'[`i', 2], "`format'") in `row'
                replace D = string(`balance_mat'[`i', 3], "`format'") in `row'
                if "`wvar'" != "" | "`matched'" != "" {
                    replace E = string(`balance_mat'[`i', 4], "`format'") in `row'
                    replace F = string(`balance_mat'[`i', 5], "`format'") in `row'
                    replace G = string(`balance_mat'[`i', 6], "`format'") in `row'
                }
                local i = `i' + 1
            }

            * Summary row
            local sumrow = `nvars' + 3
            replace A = "Max |SMD|" in `sumrow'
            replace D = string(`max_smd_raw', "`format'") in `sumrow'
            if "`wvar'" != "" | "`matched'" != "" {
                replace G = string(`max_smd_adj', "`format'") in `sumrow'
            }

            * Drop empty columns if no adjustment
            if "`wvar'" == "" & "`matched'" == "" {
                drop E F G
            }

            export excel using "`xlsx'", sheet("`sheet'") sheetreplace

            restore

            display as text _n "Balance table exported to: " as result "`xlsx'"
        }
    }

    * =========================================================================
    * RETURN RESULTS
    * =========================================================================
    return scalar N = `N'
    return scalar N_treated = `n_treated'
    return scalar N_control = `n_control'
    return scalar max_smd_raw = `max_smd_raw'
    if "`wvar'" != "" | "`matched'" != "" {
        return scalar max_smd_adj = `max_smd_adj'
    }
    return scalar n_imbalanced = `n_imbalanced'
    return scalar threshold = `threshold'
    return matrix balance = `balance_mat'
    return local treatment "`treatment'"
    return local varlist "`varlist'"
    if "`wvar'" != "" return local wvar "`wvar'"

end
