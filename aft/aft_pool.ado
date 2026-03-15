*! aft_pool Version 1.1.0  2026/03/15
*! Meta-analytic pooling of piecewise AFT per-interval estimates
*! Author: Timothy P Copeland
*! Department of Clinical Neuroscience, Karolinska Institutet
*! Program class: rclass (returns results in r())

/*
Basic syntax:
  aft_pool [, method(string) plot notable saving(string) scheme(passthru)]

Description:
  Reads per-interval AFT coefficients and SEs from aft_split
  characteristics and computes inverse-variance weighted pooled
  estimates. Supports fixed-effect and DerSimonian-Laird random-effects
  pooling. Optionally produces a forest plot.

See help aft_pool for complete documentation
*/

program define aft_pool, rclass
    version 16.0
    local _vaset = c(varabbrev)
    set varabbrev off
    set more off

    * =========================================================================
    * SYNTAX PARSING
    * =========================================================================
    syntax [, METHod(string) PLot noTABle SAVing(string) SCHeme(passthru)]

    * =========================================================================
    * CHECK PREREQUISITES
    * =========================================================================
    _aft_check_piecewise

    * Validate method
    if "`method'" == "" local method "fixed"
    local method = lower("`method'")
    if !inlist("`method'", "fixed", "random") {
        display as error "method() must be {bf:fixed} or {bf:random}"
        exit 198
    }

    * =========================================================================
    * READ CHARACTERISTICS
    * =========================================================================

    local n_pieces : char _dta[_aft_pw_n_pieces]
    local cutpoints : char _dta[_aft_pw_cutpoints]
    local dist : char _dta[_aft_pw_dist]
    local pw_varlist : char _dta[_aft_pw_varlist]

    local n_vars : word count `pw_varlist'

    * Get variable names (strip fv operators)
    local var_names ""
    foreach v of local pw_varlist {
        local vclean = regexr("`v'", "^[icob]+\.", "")
        local var_names "`var_names' `vclean'"
    }
    local var_names = strtrim("`var_names'")

    * Read per-interval coefficients and SEs into locals
    local j = 0
    foreach v of local pw_varlist {
        local ++j
        forvalues k = 1/`n_pieces' {
            local coef_`j'_`k' : char _dta[_aft_pw_coef_`k'_`j']
            local se_`j'_`k' : char _dta[_aft_pw_se_`k'_`j']
        }
    }

    * =========================================================================
    * DISPLAY HEADER
    * =========================================================================
    _aft_display_header "aft_pool" "Pooled Piecewise AFT Estimates"

    display as text "Method:           " as result ///
        cond("`method'" == "fixed", "Fixed-effect (inverse-variance)", ///
        "Random-effects (DerSimonian-Laird)")
    display as text "Distribution:     " as result "`dist'"
    display as text "Intervals:        " as result "`n_pieces'"
    display as text ""

    * =========================================================================
    * COMPUTE POOLED ESTIMATES
    * =========================================================================

    tempname pooled_mat hetero_mat
    matrix `pooled_mat' = J(`n_vars', 5, .)
    matrix `hetero_mat' = J(`n_vars', 3, .)
    matrix colnames `pooled_mat' = TR SE ci_lo ci_hi p
    matrix rownames `pooled_mat' = `var_names'
    matrix colnames `hetero_mat' = Q Q_p I2
    matrix rownames `hetero_mat' = `var_names'

    local z_alpha = invnormal(0.975)

    forvalues j = 1/`n_vars' {
        * Collect non-missing estimates
        local sum_w = 0
        local sum_wb = 0
        local n_est = 0

        forvalues k = 1/`n_pieces' {
            if "`coef_`j'_`k''" != "" & "`coef_`j'_`k''" != "." & ///
               "`se_`j'_`k''" != "" & "`se_`j'_`k''" != "." {
                local b_k = real("`coef_`j'_`k''")
                local s_k = real("`se_`j'_`k''")
                if !missing(`b_k') & !missing(`s_k') & `s_k' > 0 {
                    local w_k = 1 / (`s_k' * `s_k')
                    local sum_w = `sum_w' + `w_k'
                    local sum_wb = `sum_wb' + `w_k' * `b_k'
                    local ++n_est
                    * Store for heterogeneity calc
                    local w_`k'_`j' = `w_k'
                    local b_`k'_`j' = `b_k'
                }
            }
        }

        if `n_est' < 1 {
            continue
        }

        * Fixed-effect pooled estimate
        local b_pool = `sum_wb' / `sum_w'
        local se_pool = 1 / sqrt(`sum_w')

        * Cochran's Q
        local Q = 0
        forvalues k = 1/`n_pieces' {
            if "`w_`k'_`j''" != "" {
                local Q = `Q' + `w_`k'_`j'' * (`b_`k'_`j'' - `b_pool')^2
            }
        }
        local Q_df = `n_est' - 1
        local Q_p = cond(`Q_df' > 0, 1 - chi2(`Q_df', `Q'), .)
        local I2 = cond(`Q' > 0, max(0, (`Q' - `Q_df') / `Q' * 100), 0)

        * Random-effects (DerSimonian-Laird) if requested
        if "`method'" == "random" & `n_est' > 1 {
            * Compute tau^2
            local sum_w2 = 0
            forvalues k = 1/`n_pieces' {
                if "`w_`k'_`j''" != "" {
                    local sum_w2 = `sum_w2' + `w_`k'_`j'' * `w_`k'_`j''
                }
            }
            local C = `sum_w' - `sum_w2' / `sum_w'
            local tau2 = max(0, (`Q' - `Q_df') / `C')

            * Re-compute weights with tau^2
            local sum_w_re = 0
            local sum_wb_re = 0
            forvalues k = 1/`n_pieces' {
                if "`w_`k'_`j''" != "" {
                    local s_k2 = 1 / `w_`k'_`j''
                    local w_re = 1 / (`s_k2' + `tau2')
                    local sum_w_re = `sum_w_re' + `w_re'
                    local sum_wb_re = `sum_wb_re' + `w_re' * `b_`k'_`j''
                }
            }
            local b_pool = `sum_wb_re' / `sum_w_re'
            local se_pool = 1 / sqrt(`sum_w_re')
        }

        * Store results as time ratios
        local tr_pool = exp(`b_pool')
        local ci_lo = exp(`b_pool' - `z_alpha' * `se_pool')
        local ci_hi = exp(`b_pool' + `z_alpha' * `se_pool')
        local z = `b_pool' / `se_pool'
        local p_val = 2 * (1 - normal(abs(`z')))

        matrix `pooled_mat'[`j', 1] = `tr_pool'
        matrix `pooled_mat'[`j', 2] = `se_pool'
        matrix `pooled_mat'[`j', 3] = `ci_lo'
        matrix `pooled_mat'[`j', 4] = `ci_hi'
        matrix `pooled_mat'[`j', 5] = `p_val'

        matrix `hetero_mat'[`j', 1] = `Q'
        matrix `hetero_mat'[`j', 2] = `Q_p'
        matrix `hetero_mat'[`j', 3] = `I2'
    }

    * =========================================================================
    * DISPLAY RESULTS TABLE
    * =========================================================================

    if "`table'" != "notable" {
        display as text "{hline 70}"
        display as text "{bf:Pooled Time Ratios}"
        display as text "{hline 70}"
        display as text ""

        display as text %16s "Variable" "  " ///
            %10s "TR" "  " ///
            %10s "[95% CI]" "      " ///
            %8s "p" "  " ///
            %6s "I{c 178}" "  " ///
            %6s "Q_p"
        display as text "{hline 70}"

        forvalues j = 1/`n_vars' {
            local vname : word `j' of `var_names'
            local tr_j = `pooled_mat'[`j', 1]
            local ci_lo_j = `pooled_mat'[`j', 3]
            local ci_hi_j = `pooled_mat'[`j', 4]
            local p_j = `pooled_mat'[`j', 5]
            local i2_j = `hetero_mat'[`j', 3]
            local qp_j = `hetero_mat'[`j', 2]

            if !missing(`tr_j') {
                display as text %16s "`vname'" "  " ///
                    as result %10.4f `tr_j' "  " ///
                    as result "[" %7.4f `ci_lo_j' ", " %7.4f `ci_hi_j' "]" ///
                    as result %8.4f `p_j' "  " ///
                    as result %5.1f `i2_j' "%" "  " ///
                    as result %6.4f `qp_j'
            }
            else {
                display as text %16s "`vname'" "  " ///
                    as text %10s "(insufficient data)"
            }
        }

        display as text "{hline 70}"
        display as text "TR = time ratio; I{c 178} = heterogeneity (%); " ///
            "Q_p = Cochran's Q p-value"
        if "`method'" == "random" {
            display as text "Pooling: DerSimonian-Laird random-effects"
        }
        else {
            display as text "Pooling: Fixed-effect inverse-variance weighting"
        }
    }

    * =========================================================================
    * FOREST PLOT
    * =========================================================================

    if "`plot'" != "" {
        * Default scheme
        if `"`scheme'"' == "" local scheme `"scheme(plotplainblind)"'

        * Build forest plot for each variable
        forvalues j = 1/`n_vars' {
            local vname : word `j' of `var_names'

            * Collect per-interval TRs and CIs for this variable
            preserve
            clear
            quietly set obs `=`n_pieces' + 1'
            quietly gen double tr = .
            quietly gen double ci_lo = .
            quietly gen double ci_hi = .
            quietly gen int row = .
            quietly gen str32 label = ""

            local obs = 0
            forvalues k = 1/`n_pieces' {
                if "`coef_`j'_`k''" != "" & "`coef_`j'_`k''" != "." & ///
                   "`se_`j'_`k''" != "" & "`se_`j'_`k''" != "." {
                    local b_k = real("`coef_`j'_`k''")
                    local s_k = real("`se_`j'_`k''")
                    if !missing(`b_k') & !missing(`s_k') & `s_k' > 0 {
                        local ++obs
                        quietly replace row = `=`n_pieces' + 1 - `k'' in `obs'
                        quietly replace tr = exp(`b_k') in `obs'
                        quietly replace ci_lo = exp(`b_k' - `z_alpha' * `s_k') in `obs'
                        quietly replace ci_hi = exp(`b_k' + `z_alpha' * `s_k') in `obs'
                        local lab_k : word `k' of `cutpoints'
                        if `k' == 1 {
                            quietly replace label = "0-`lab_k'" in `obs'
                        }
                        else {
                            local prev_k : word `=`k'-1' of `cutpoints'
                            quietly replace label = "`prev_k'-`lab_k'" in `obs'
                        }
                    }
                }
            }

            * Add pooled estimate
            local tr_pool = `pooled_mat'[`j', 1]
            local ci_lo_pool = `pooled_mat'[`j', 3]
            local ci_hi_pool = `pooled_mat'[`j', 4]
            if !missing(`tr_pool') {
                local ++obs
                quietly replace row = 0 in `obs'
                quietly replace tr = `tr_pool' in `obs'
                quietly replace ci_lo = `ci_lo_pool' in `obs'
                quietly replace ci_hi = `ci_hi_pool' in `obs'
                quietly replace label = "Pooled" in `obs'
            }

            quietly keep if !missing(row)

            if _N > 0 {
                twoway (rspike ci_lo ci_hi row, horizontal lcolor(navy)) ///
                    (scatter row tr, mcolor(navy) msymbol(diamond)) ///
                    , xline(1, lcolor(gs10) lpattern(dash)) ///
                    ytitle("") xtitle("Time Ratio") ///
                    title("Forest Plot: `vname'") ///
                    ylabel(, valuelabel angle(0) noticks) ///
                    legend(off) `scheme' ///
                    name(_aft_forest_`vname', replace)
            }

            restore
        }
    }

    * =========================================================================
    * SAVE RESULTS
    * =========================================================================

    if "`saving'" != "" {
        preserve
        clear
        quietly set obs `n_vars'
        quietly gen str32 variable = ""
        quietly gen double tr = .
        quietly gen double se = .
        quietly gen double ci_lo = .
        quietly gen double ci_hi = .
        quietly gen double p = .
        quietly gen double Q = .
        quietly gen double Q_p = .
        quietly gen double I2 = .

        forvalues j = 1/`n_vars' {
            local vname : word `j' of `var_names'
            quietly replace variable = "`vname'" in `j'
            quietly replace tr = `pooled_mat'[`j', 1] in `j'
            quietly replace se = `pooled_mat'[`j', 2] in `j'
            quietly replace ci_lo = `pooled_mat'[`j', 3] in `j'
            quietly replace ci_hi = `pooled_mat'[`j', 4] in `j'
            quietly replace p = `pooled_mat'[`j', 5] in `j'
            quietly replace Q = `hetero_mat'[`j', 1] in `j'
            quietly replace Q_p = `hetero_mat'[`j', 2] in `j'
            quietly replace I2 = `hetero_mat'[`j', 3] in `j'
        }

        quietly save `saving'
        restore
    }

    * =========================================================================
    * DISPLAY FOOTER
    * =========================================================================

    display as text ""
    display as text "{hline 70}"

    * =========================================================================
    * RETURN RESULTS
    * =========================================================================

    return matrix pooled = `pooled_mat'
    return matrix heterogeneity = `hetero_mat'
    return local method "`method'"
    return local dist "`dist'"
    return scalar n_pieces = `n_pieces'

    set varabbrev `_vaset'
end
