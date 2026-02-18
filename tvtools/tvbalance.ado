*! tvbalance Version 1.0.1  2026/02/18
*! Balance diagnostics for time-varying exposure datasets
*! Author: Tim Copeland
*! Program class: rclass (returns results in r())

/*
Basic syntax:
  tvbalance varlist, exposure(varname) [options]

Required:
  varlist             - Covariates to assess balance
  exposure(varname)   - Binary or categorical exposure variable

Options:
  weights(varname)    - IPTW or other weights for weighted balance
  threshold(#)        - SMD threshold for imbalance flag (default: 0.1)
  id(varname)         - Person identifier (for person-level summary)
  loveplot            - Generate Love plot of SMD values
  saving(filename)    - Save Love plot to file
  replace             - Replace existing file

Output:
  Standardized mean differences (SMD) for each covariate
  Weighted and unweighted balance when weights provided
  Love plot visualization (optional)

Examples:
  * Basic balance check
  tvbalance age sex comorbidity, exposure(tv_exposure)

  * With IPTW weights
  tvbalance age sex, exposure(tv_exposure) weights(iptw) loveplot

See help tvbalance for complete documentation
*/

program define tvbalance, rclass
    version 16.0
    set varabbrev off

    syntax varlist(numeric), EXPosure(varname) ///
        [WEights(varname) THReshold(real 0.1) ///
         ID(varname) LOVEplot SAVing(string) REPLACE]

    * Validate exposure variable
    capture confirm numeric variable `exposure'
    if _rc != 0 {
        display as error "exposure() variable must be numeric"
        exit 109
    }

    * Check if binary exposure
    quietly tab `exposure'
    local n_levels = r(r)
    if `n_levels' > 2 {
        display as text "Note: exposure has `n_levels' levels; using pairwise comparisons with first level"
    }

    * Get reference level (lowest value)
    quietly sum `exposure'
    local ref_level = r(min)

    display as text "{hline 70}"
    display as text "{bf:Covariate Balance Diagnostics}"
    display as text "{hline 70}"
    display as text ""

    * Count observations by exposure
    quietly count if `exposure' == `ref_level'
    local n_ref = r(N)
    quietly count if `exposure' != `ref_level'
    local n_exp = r(N)

    display as text "Sample sizes:"
    display as text "  Reference (`exposure' = `ref_level'): " as result `n_ref'
    display as text "  Exposed (`exposure' != `ref_level'):  " as result `n_exp'
    display as text ""

    * Calculate SMD for each covariate
    local n_covars: word count `varlist'
    tempname results_mat
    matrix `results_mat' = J(`n_covars', 4, .)
    matrix colnames `results_mat' = "Mean_Ref" "Mean_Exp" "SMD_Unwt" "SMD_Wt"
    local rownames ""

    local i = 0
    foreach var of local varlist {
        local i = `i' + 1
        local rownames "`rownames' `var'"

        * Unweighted statistics
        quietly sum `var' if `exposure' == `ref_level'
        local mean_ref = r(mean)
        local var_ref = r(Var)

        quietly sum `var' if `exposure' != `ref_level'
        local mean_exp = r(mean)
        local var_exp = r(Var)

        * Calculate pooled SD
        local pooled_sd = sqrt((`var_ref' + `var_exp') / 2)

        * SMD (unweighted)
        if `pooled_sd' > 0 {
            local smd_unwt = (`mean_exp' - `mean_ref') / `pooled_sd'
        }
        else {
            * Zero variance: if means are equal, SMD is 0; otherwise undefined
            if abs(`mean_exp' - `mean_ref') < 1e-10 {
                local smd_unwt = 0
            }
            else {
                local smd_unwt = .
            }
        }

        matrix `results_mat'[`i', 1] = `mean_ref'
        matrix `results_mat'[`i', 2] = `mean_exp'
        matrix `results_mat'[`i', 3] = `smd_unwt'

        * Weighted SMD if weights provided
        if "`weights'" != "" {
            quietly sum `var' [aw=`weights'] if `exposure' == `ref_level'
            local wmean_ref = r(mean)

            quietly sum `var' [aw=`weights'] if `exposure' != `ref_level'
            local wmean_exp = r(mean)

            * Weighted variance (approximate)
            quietly sum `var' [aw=`weights'] if `exposure' == `ref_level'
            local wvar_ref = r(Var)

            quietly sum `var' [aw=`weights'] if `exposure' != `ref_level'
            local wvar_exp = r(Var)

            local wpooled_sd = sqrt((`wvar_ref' + `wvar_exp') / 2)

            if `wpooled_sd' > 0 {
                local smd_wt = (`wmean_exp' - `wmean_ref') / `wpooled_sd'
            }
            else {
                if abs(`wmean_exp' - `wmean_ref') < 1e-10 {
                    local smd_wt = 0
                }
                else {
                    local smd_wt = .
                }
            }

            matrix `results_mat'[`i', 4] = `smd_wt'
        }
    }

    matrix rownames `results_mat' = `rownames'

    * Display results
    display as text "{hline 70}"
    display as text "Covariate Balance (Standardized Mean Differences)"
    display as text "{hline 70}"
    display as text ""

    if "`weights'" != "" {
        display as text _col(20) "Mean" _col(30) "Mean" _col(42) "SMD" _col(52) "SMD"
        display as text "Covariate" _col(18) "(Ref)" _col(28) "(Exp)" _col(37) "(Unwt)" _col(48) "(Wt)"
        display as text "{hline 60}"

        local i = 0
        foreach var of local varlist {
            local i = `i' + 1
            local m1 = `results_mat'[`i', 1]
            local m2 = `results_mat'[`i', 2]
            local s1 = `results_mat'[`i', 3]
            local s2 = `results_mat'[`i', 4]

            * Flag imbalanced covariates (missing SMD = not imbalanced)
            local flag1 = cond(!missing(`s1') & abs(`s1') > `threshold', "*", " ")
            local flag2 = cond(!missing(`s2') & abs(`s2') > `threshold', "*", " ")

            display as text abbrev("`var'", 16) _col(17) ///
                as result %7.3f `m1' _col(27) %7.3f `m2' ///
                _col(37) %7.3f `s1' "`flag1'" ///
                _col(48) %7.3f `s2' "`flag2'"
        }
    }
    else {
        display as text _col(20) "Mean" _col(30) "Mean" _col(42) "SMD"
        display as text "Covariate" _col(18) "(Ref)" _col(28) "(Exp)" _col(37) "(Unwt)"
        display as text "{hline 50}"

        local i = 0
        foreach var of local varlist {
            local i = `i' + 1
            local m1 = `results_mat'[`i', 1]
            local m2 = `results_mat'[`i', 2]
            local s1 = `results_mat'[`i', 3]

            * Flag imbalanced covariates (missing SMD = not imbalanced)
            local flag1 = cond(!missing(`s1') & abs(`s1') > `threshold', "*", " ")

            display as text abbrev("`var'", 16) _col(17) ///
                as result %7.3f `m1' _col(27) %7.3f `m2' ///
                _col(37) %7.3f `s1' "`flag1'"
        }
    }

    display as text ""
    display as text "* indicates |SMD| > `threshold'"
    display as text "{hline 70}"

    * Summary statistics
    local n_imbalanced = 0
    forvalues i = 1/`n_covars' {
        local this_smd = `results_mat'[`i', 3]
        if !missing(`this_smd') & abs(`this_smd') > `threshold' {
            local n_imbalanced = `n_imbalanced' + 1
        }
    }

    display as text ""
    display as text "Summary:"
    display as text "  Total covariates: " as result `n_covars'
    display as text "  Imbalanced (|SMD| > `threshold'): " as result `n_imbalanced'

    if "`weights'" != "" {
        local n_imbalanced_wt = 0
        forvalues i = 1/`n_covars' {
            local this_smd_wt = `results_mat'[`i', 4]
            if !missing(`this_smd_wt') & abs(`this_smd_wt') > `threshold' {
                local n_imbalanced_wt = `n_imbalanced_wt' + 1
            }
        }
        display as text "  Imbalanced after weighting: " as result `n_imbalanced_wt'

        * Effective sample size
        quietly sum `weights' if `exposure' == `ref_level'
        local sum_w_ref = r(sum)
        local sumsq_w_ref = r(sum) * r(mean)  // Approximate

        quietly gen double __w2 = `weights'^2 if `exposure' == `ref_level'
        quietly sum __w2
        local sumsq_w_ref = r(sum)
        quietly drop __w2

        local ess_ref = (`sum_w_ref'^2) / `sumsq_w_ref'

        quietly sum `weights' if `exposure' != `ref_level'
        local sum_w_exp = r(sum)

        quietly gen double __w2 = `weights'^2 if `exposure' != `ref_level'
        quietly sum __w2
        local sumsq_w_exp = r(sum)
        quietly drop __w2

        local ess_exp = (`sum_w_exp'^2) / `sumsq_w_exp'

        display as text ""
        display as text "Effective sample sizes (weighted):"
        display as text "  Reference: " as result %9.1f `ess_ref' " (original: `n_ref')"
        display as text "  Exposed:   " as result %9.1f `ess_exp' " (original: `n_exp')"
    }

    display as text "{hline 70}"

    **************************************************************************
    * LOVE PLOT
    **************************************************************************
    if "`loveplot'" != "" {
        preserve

        * Create dataset for plot
        clear
        local n_vars: word count `varlist'
        quietly set obs `n_vars'

        quietly gen str32 covariate = ""
        quietly gen smd_unwt = .
        quietly gen smd_wt = .
        quietly gen ypos = _n

        local i = 0
        foreach var of local varlist {
            local i = `i' + 1
            quietly replace covariate = "`var'" in `i'
            quietly replace smd_unwt = `results_mat'[`i', 3] in `i'
            if "`weights'" != "" {
                quietly replace smd_wt = `results_mat'[`i', 4] in `i'
            }
        }

        * Create Love plot
        if "`weights'" != "" {
            twoway (scatter ypos smd_unwt, msymbol(O) mcolor(navy) msize(medium)) ///
                   (scatter ypos smd_wt, msymbol(D) mcolor(maroon) msize(medium)), ///
                ylabel(1(1)`n_vars', valuelabel angle(0) labsize(small)) ///
                xline(-`threshold', lcolor(gs10) lpattern(dash)) ///
                xline(`threshold', lcolor(gs10) lpattern(dash)) ///
                xline(0, lcolor(black)) ///
                xtitle("Standardized Mean Difference") ///
                ytitle("") ///
                title("Love Plot: Covariate Balance") ///
                legend(order(1 "Unweighted" 2 "Weighted") rows(1)) ///
                scheme(s2color)
        }
        else {
            twoway (scatter ypos smd_unwt, msymbol(O) mcolor(navy) msize(medium)), ///
                ylabel(1(1)`n_vars', valuelabel angle(0) labsize(small)) ///
                xline(-`threshold', lcolor(gs10) lpattern(dash)) ///
                xline(`threshold', lcolor(gs10) lpattern(dash)) ///
                xline(0, lcolor(black)) ///
                xtitle("Standardized Mean Difference") ///
                ytitle("") ///
                title("Love Plot: Covariate Balance") ///
                legend(off) ///
                scheme(s2color)
        }

        * Save if requested
        if "`saving'" != "" {
            if "`replace'" != "" {
                graph export "`saving'", replace
            }
            else {
                graph export "`saving'"
            }
            display as text "Love plot saved to: `saving'"
        }

        restore
    }

    * Return results
    return matrix balance = `results_mat'
    return scalar n_ref = `n_ref'
    return scalar n_exp = `n_exp'
    return scalar n_covariates = `n_covars'
    return scalar n_imbalanced = `n_imbalanced'
    return scalar threshold = `threshold'
    return local exposure "`exposure'"
    if "`weights'" != "" {
        return scalar n_imbalanced_wt = `n_imbalanced_wt'
        return scalar ess_ref = `ess_ref'
        return scalar ess_exp = `ess_exp'
        return local weights "`weights'"
    }
end
