*! nma_compare Version 1.0.3  2026/03/01
*! League table of all pairwise comparisons
*! Author: Timothy P Copeland
*! Department of Clinical Neuroscience, Karolinska Institutet
*! Program class: rclass (returns results in r())

/*
Basic syntax:
  nma_compare [, eform digits(integer 2) saving(filename)
      format(excel|csv) replace]

Description:
  Produces a K×K league table where cell (i,j) shows the estimated
  treatment effect of treatment i vs treatment j with confidence interval.
  Upper triangle shows effects in one direction, lower triangle in reverse.

See help nma_compare for complete documentation
*/

program define nma_compare, rclass
    version 16.0
    set varabbrev off
    set more off

    syntax [, EFORM DIGits(integer 2) SAVing(string) ///
        FORmat(string) REPLACE Level(cilevel)]

    * =======================================================================
    * CHECK PREREQUISITES
    * =======================================================================

    _nma_check_setup
    _nma_check_fitted
    _nma_get_settings

    local ref         "`_nma_ref'"
    local treatments  "`_nma_treatments'"
    local n_treatments = `_nma_n_treatments'
    local k = `n_treatments'
    local measure     "`_nma_measure'"
    local ref_code    : char _dta[_nma_ref_code]

    if "`level'" == "" local level 95
    if "`format'" != "" & !inlist("`format'", "excel", "csv") {
        display as error "format() must be excel or csv"
        exit 198
    }

    local use_eform = 0
    if "`eform'" != "" & inlist("`measure'", "or", "rr", "irr", "hr") {
        local use_eform = 1
    }

    _nma_display_header, command("nma_compare") ///
        description("League table of all pairwise comparisons")

    * =======================================================================
    * COMPUTE ALL PAIRWISE COMPARISONS
    * =======================================================================

    tempname b V
    matrix `b' = e(b)
    matrix `V' = e(V)

    local z_crit = invnormal(1 - (1 - `level'/100) / 2)

    * Map treatment codes to parameter columns
    local param_trts ""
    local col = 0
    forvalues t = 1/`k' {
        if `t' != `ref_code' {
            local ++col
            local param_trts "`param_trts' `t'"
            local pcol_`t' = `col'
        }
    }

    * Compute effect of treatment i vs treatment j for all pairs
    * d_ij = d_iR - d_jR (where R = reference)
    * Var(d_ij) = Var(d_iR) + Var(d_jR) - 2*Cov(d_iR, d_jR)

    * Build k x k matrices of effects, SEs, CIs
    tempname eff_mat se_mat lo_mat hi_mat
    matrix `eff_mat' = J(`k', `k', 0)
    matrix `se_mat' = J(`k', `k', 0)
    matrix `lo_mat' = J(`k', `k', 0)
    matrix `hi_mat' = J(`k', `k', 0)

    forvalues i = 1/`k' {
        forvalues j = 1/`k' {
            if `i' == `j' continue

            * d_ij = d_iR - d_jR
            local d_iR = 0
            local d_jR = 0
            if `i' != `ref_code' local d_iR = `b'[1, `pcol_`i'']
            if `j' != `ref_code' local d_jR = `b'[1, `pcol_`j'']

            local d_ij = `d_iR' - `d_jR'

            * Variance
            local var_ij = 0
            if `i' != `ref_code' {
                local var_ij = `var_ij' + `V'[`pcol_`i'', `pcol_`i'']
            }
            if `j' != `ref_code' {
                local var_ij = `var_ij' + `V'[`pcol_`j'', `pcol_`j'']
            }
            if `i' != `ref_code' & `j' != `ref_code' {
                local var_ij = `var_ij' - 2 * `V'[`pcol_`i'', `pcol_`j'']
            }

            local se_ij = sqrt(max(`var_ij', 0))
            local lo_ij = `d_ij' - `z_crit' * `se_ij'
            local hi_ij = `d_ij' + `z_crit' * `se_ij'

            matrix `eff_mat'[`i', `j'] = `d_ij'
            matrix `se_mat'[`i', `j'] = `se_ij'
            matrix `lo_mat'[`i', `j'] = `lo_ij'
            matrix `hi_mat'[`i', `j'] = `hi_ij'
        }
    }

    * =======================================================================
    * DISPLAY LEAGUE TABLE
    * =======================================================================

    * Header row with treatment names
    * Field width per number: sign + digits before decimal + dot + digits after
    local fw = `digits' + 4
    * Cell content: 3 numbers + parens/comma + possible marker
    local cell_chars = 3 * `fw' + 6
    local col_width = max(`cell_chars' + 1, 14)

    * Shortened treatment labels (max 12 chars)
    local any_truncated = 0
    forvalues i = 1/`k' {
        local lbl : word `i' of `treatments'
        local short_`i' = substr("`lbl'", 1, 12)
        if length("`lbl'") > 12 local any_truncated = 1
    }
    if `any_truncated' {
        display as text "Note: Some treatment labels truncated to 12 characters in display"
    }

    * Print header
    display as text _newline "{hline `=`col_width' * (`k' + 1)'}"
    display as text %`col_width's "" _continue
    forvalues j = 1/`k' {
        display as text %`col_width's "`short_`j''" _continue
    }
    display ""

    * Print rows
    forvalues i = 1/`k' {
        display as result %`col_width's "`short_`i''" _continue
        forvalues j = 1/`k' {
            if `i' == `j' {
                display as result %`col_width's "`short_`i''" _continue
            }
            else {
                local d = `eff_mat'[`i', `j']
                local lo = `lo_mat'[`i', `j']
                local hi = `hi_mat'[`i', `j']

                if `use_eform' {
                    local d = exp(`d')
                    local lo = exp(`lo')
                    local hi = exp(`hi')
                }

                * Evidence type
                local ev = _nma_evidence[`i', `j']
                local marker ""
                if `ev' == 2 local marker "*"

                local cell : display %`fw'.`digits'f `d' " (" %`fw'.`digits'f `lo' "," %`fw'.`digits'f `hi' ")" "`marker'"
                display as text %`col_width's "`cell'" _continue
            }
        }
        display ""
    }

    display as text "{hline `=`col_width' * (`k' + 1)'}"
    display as text "* = indirect evidence only (no direct head-to-head studies)"
    display as text "Read: row treatment vs column treatment"

    * =======================================================================
    * EXPORT IF REQUESTED
    * =======================================================================

    if "`saving'" != "" {
        preserve

        quietly {
            clear
            set obs `k'
            gen str80 treatment = ""
            forvalues j = 1/`k' {
                local lbl : word `j' of `treatments'
                local safe_lbl = subinstr("`lbl'", " ", "_", .)
                gen str40 vs_`safe_lbl' = ""
                label variable vs_`safe_lbl' "vs `lbl'"
            }

            forvalues i = 1/`k' {
                local lbl_i : word `i' of `treatments'
                replace treatment = "`lbl_i'" in `i'
                forvalues j = 1/`k' {
                    local lbl_j : word `j' of `treatments'
                    local safe_j = subinstr("`lbl_j'", " ", "_", .)
                    if `i' == `j' {
                        replace vs_`safe_j' = "`lbl_i'" in `i'
                    }
                    else {
                        local d = `eff_mat'[`i', `j']
                        local lo = `lo_mat'[`i', `j']
                        local hi = `hi_mat'[`i', `j']
                        if `use_eform' {
                            local d = exp(`d')
                            local lo = exp(`lo')
                            local hi = exp(`hi')
                        }
                        local cell : display %`fw'.`digits'f `d' " (" %`fw'.`digits'f `lo' ", " %`fw'.`digits'f `hi' ")"
                        replace vs_`safe_j' = "`cell'" in `i'
                    }
                }
            }
        }

        if "`format'" == "excel" | "`format'" == "" {
            export excel using "`saving'", firstrow(variables) ///
                sheet("League Table") `replace'

            * Apply formatting (non-fatal)
            local n_cols = `k' + 1
            _nma_col_letter `n_cols'
            local last_col "`result'"
            local n_rows = `k' + 1

            capture noisily {
                mata: b = xl()
                mata: b.load_book("`saving'")
                mata: b.set_sheet("League Table")
                mata: b.set_column_width(1, 1, 22)
                mata: b.set_column_width(2, `n_cols', 24)
                mata: b.close_book()

                putexcel set "`saving'", sheet("League Table") modify
                putexcel (A1:`last_col'1), bold hcenter
                putexcel (A1:`last_col'1), border(top, thin)
                putexcel (A1:`last_col'1), border(bottom, thin)
                putexcel (A`n_rows':`last_col'`n_rows'), border(bottom, thin)
                putexcel (A1:`last_col'`n_rows'), font(Arial, 10)
                putexcel clear
            }
        }
        else if "`format'" == "csv" {
            export delimited using "`saving'", `replace'
        }

        restore
        display as text "League table exported to `saving'"
    }

    * =======================================================================
    * RETURNS
    * =======================================================================

    * Copy before returning (return matrix moves, not copies)
    tempname eff_c se_c lo_c hi_c
    matrix `eff_c' = `eff_mat'
    matrix `se_c' = `se_mat'
    matrix `lo_c' = `lo_mat'
    matrix `hi_c' = `hi_mat'
    return matrix effects = `eff_c'
    return matrix se = `se_c'
    return matrix ci_lo = `lo_c'
    return matrix ci_hi = `hi_c'
    return scalar k = `k'
    return local treatments "`treatments'"
    return local ref "`ref'"
end
