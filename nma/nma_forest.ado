*! nma_forest Version 1.0.3  2026/02/28
*! Forest plot for network meta-analysis
*! Author: Timothy P Copeland
*! Department of Clinical Neuroscience, Karolinska Institutet
*! Program class: rclass (returns results in r())

/*
Basic syntax:
  nma_forest [, eform level(cilevel) xlabel(numlist)
      scheme(string) saving(filename) replace]

Description:
  Generates a forest plot showing network meta-analysis treatment effect
  estimates with confidence intervals, comparing each treatment to the
  reference.

See help nma_forest for complete documentation
*/

program define nma_forest, rclass
    version 16.0
    set varabbrev off
    set more off

    syntax [, EFORM Level(cilevel) ///
        XLAbel(numlist) SCHeme(string) SAVing(string) REPLACE ///
        TItle(string) COLors(string)]

    * =======================================================================
    * CHECK PREREQUISITES
    * =======================================================================

    _nma_check_setup
    _nma_check_fitted
    _nma_get_settings

    local ref         "`_nma_ref'"
    local treatments  "`_nma_treatments'"
    local n_treatments = `_nma_n_treatments'
    local measure     "`_nma_measure'"
    local ref_code    : char _dta[_nma_ref_code]

    if "`scheme'" == "" local scheme "plotplainblind"
    if "`level'" == "" local level 95

    * Determine if eform is appropriate
    local use_eform = 0
    if "`eform'" != "" & inlist("`measure'", "or", "rr", "irr", "hr") {
        local use_eform = 1
    }

    * =======================================================================
    * EXTRACT ESTIMATES
    * =======================================================================

    tempname b V
    matrix `b' = e(b)
    matrix `V' = e(V)

    local p = colsof(`b')
    local z_crit = invnormal(1 - (1 - `level'/100) / 2)

    preserve

    quietly {
        clear
        set obs `p'

        gen str80 treatment = ""
        gen double coef = .
        gen double se = .
        gen double ci_lo = .
        gen double ci_hi = .
        gen double ypos = .
        gen str20 evidence = ""
    }

    * Get parameter treatment codes and save labels before clear
    local param_trts ""
    forvalues t = 1/`n_treatments' {
        if `t' != `ref_code' {
            local param_trts "`param_trts' `t'"
            local trtlbl_`t' : word `t' of `treatments'
        }
    }

    local col = 0
    foreach t of local param_trts {
        local ++col
        local lbl "`trtlbl_`t''"
        local coef = `b'[1, `col']
        local se = sqrt(`V'[`col', `col'])

        if `use_eform' {
            local disp_coef = exp(`coef')
            local disp_lo = exp(`coef' - `z_crit' * `se')
            local disp_hi = exp(`coef' + `z_crit' * `se')
        }
        else {
            local disp_coef = `coef'
            local disp_lo = `coef' - `z_crit' * `se'
            local disp_hi = `coef' + `z_crit' * `se'
        }

        * Evidence type
        local ev_code = _nma_evidence[`t', `ref_code']
        if `ev_code' == 1 local ev_lbl "Direct"
        else if `ev_code' == 2 local ev_lbl "Indirect"
        else if `ev_code' == 3 local ev_lbl "Mixed"
        else local ev_lbl ""

        quietly replace treatment = "`lbl'" in `col'
        quietly replace coef = `disp_coef' in `col'
        quietly replace ci_lo = `disp_lo' in `col'
        quietly replace ci_hi = `disp_hi' in `col'
        quietly replace ypos = `p' - `col' + 1 in `col'
        quietly replace evidence = "`ev_lbl'" in `col'
    }

    * =======================================================================
    * DRAW FOREST PLOT
    * =======================================================================

    * Reference line
    local null_val = 0
    if `use_eform' local null_val = 1

    * Axis label
    if `use_eform' {
        if "`measure'" == "or" local xlab "Odds Ratio"
        else if "`measure'" == "rr" local xlab "Risk Ratio"
        else if "`measure'" == "irr" local xlab "Incidence Rate Ratio"
        else if "`measure'" == "hr" local xlab "Hazard Ratio"
        else local xlab "Effect Size"
    }
    else {
        if "`measure'" == "or" local xlab "Log Odds Ratio"
        else if "`measure'" == "rr" local xlab "Log Risk Ratio"
        else if "`measure'" == "md" local xlab "Mean Difference"
        else if "`measure'" == "smd" local xlab "Standardized Mean Difference"
        else local xlab "Effect Size"
    }

    if "`title'" == "" local title "Network Meta-Analysis: Forest Plot (vs `ref')"

    * Y-axis labels via value labels (compound quoting approach fails)
    capture label drop _ypos_lbl
    forvalues i = 1/`p' {
        local yval = ypos[`i']
        local lbl = treatment[`i']
        label define _ypos_lbl `yval' "`lbl'", add
    }
    label values ypos _ypos_lbl

    * Marker colors by evidence type
    if "`colors'" == "" local colors "navy"

    * Construct saving() option for twoway
    local save_opt ""
    if "`saving'" != "" {
        local save_opt `"saving("`saving'", `replace')"'
    }

    twoway ///
        (rcap ci_lo ci_hi ypos, horizontal lcolor(`colors') lwidth(medthick)) ///
        (scatter ypos coef, msymbol(D) mcolor(`colors') msize(medium)), ///
        xline(`null_val', lcolor(gs10) lpattern(dash)) ///
        ylabel(1(1)`p', valuelabel angle(0) labsize(small) nogrid) ///
        ytitle("") xtitle("`xlab'") ///
        title("`title'") ///
        legend(off) ///
        scheme(`scheme') ///
        `save_opt'

    restore

    display as text "Forest plot created: `p' comparisons vs `ref'"

    return scalar n_comparisons = `p'
    return local ref "`ref'"
end
