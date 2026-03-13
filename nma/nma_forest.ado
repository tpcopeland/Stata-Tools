*! nma_forest Version 1.0.6  2026/03/13
*! Evidence decomposition forest plot for network meta-analysis
*! Author: Timothy P Copeland
*! Department of Clinical Neuroscience, Karolinska Institutet
*! Program class: rclass (returns results in r())

/*
Basic syntax:
  nma_forest [, eform level(cilevel) comparisons(all|mixed)
      xlabel(numlist) xtitle(string) title(string)
      textcol dp(integer 2) diamond
      scheme(string) saving(filename) replace
      colors(string) name(string)]

Description:
  Creates an evidence decomposition forest plot showing Direct, Indirect,
  and Network estimates grouped by comparison pair. All evidence types
  shown as circles with CI spikes by default. Option diamond renders
  Network estimates as diamond shapes instead.

  Display logic per evidence type:
    Direct only  -> Direct + Network
    Indirect only -> Indirect (= Network)
    Mixed        -> Direct + Indirect + Network

See help nma_forest for complete documentation
*/

program define nma_forest, rclass
    version 16.0
    local _varabbrev = c(varabbrev)
    set varabbrev off

    syntax [, EFORM Level(cilevel) COMParisons(string) ///
        XLAbel(numlist) XTItle(string) TItle(string) ///
        TEXTCOL DP(integer 2) DIAMOND ///
        SCHeme(string) SAVing(string) REPLACE ///
        COLors(string) NAME(string)]

    * ==================================================================
    * SETUP & VALIDATION
    * ==================================================================

    _nma_check_setup
    _nma_check_fitted
    _nma_get_settings

    local ref         "`_nma_ref'"
    local treatments  "`_nma_treatments'"
    local n_treatments = `_nma_n_treatments'
    local k = `n_treatments'
    local measure     "`_nma_measure'"
    local ref_code    : char _dta[_nma_ref_code]

    if "`scheme'" == "" local scheme "white_tableau"
    if "`level'" == "" local level 95
    if "`comparisons'" == "" local comparisons "all"
    if !inlist("`comparisons'", "all", "mixed") {
        display as error "comparisons() must be {bf:all} or {bf:mixed}"
        exit 198
    }
    if `dp' < 0 | `dp' > 6 {
        display as error "dp() must be between 0 and 6"
        exit 198
    }

    local use_eform = 0
    if "`eform'" != "" & inlist("`measure'", "or", "rr", "irr", "hr") {
        local use_eform = 1
    }

    local null_val = cond(`use_eform', 1, 0)
    local z_crit = invnormal(1 - (1 - `level'/100) / 2)

    * Parse colors: direct indirect network
    local col_direct "forest_green"
    local col_indirect "dkorange"
    local col_network "navy"
    if `"`colors'"' != "" {
        local colors_tmp `"`colors'"'
        gettoken col_direct colors_tmp : colors_tmp
        if `"`colors_tmp'"' != "" {
            gettoken col_indirect colors_tmp : colors_tmp
            if `"`colors_tmp'"' != "" {
                gettoken col_network colors_tmp : colors_tmp
            }
        }
    }

    * Check for _nma_base_trt variable
    local has_base_trt = 0
    capture confirm variable _nma_base_trt
    if _rc == 0 local has_base_trt = 1

    * Default axis title
    if `"`xtitle'"' == "" {
        if `use_eform' {
            if "`measure'" == "or" local xtitle "Odds Ratio"
            else if "`measure'" == "rr" local xtitle "Risk Ratio"
            else if "`measure'" == "irr" local xtitle "Incidence Rate Ratio"
            else if "`measure'" == "hr" local xtitle "Hazard Ratio"
            else local xtitle "Effect Size"
        }
        else {
            if "`measure'" == "or" local xtitle "Log Odds Ratio"
            else if "`measure'" == "rr" local xtitle "Log Risk Ratio"
            else if "`measure'" == "md" local xtitle "Mean Difference"
            else if "`measure'" == "smd" local xtitle "Standardized Mean Difference"
            else local xtitle "Effect Size"
        }
    }

    * Save treatment labels before preserve (clear wipes _dta chars)
    forvalues t = 1/`k' {
        local trtlbl_`t' : char _dta[_nma_trt_`t']
    }

    * ==================================================================
    * EXTRACT MODEL ESTIMATES & BUILD COLUMN MAP
    * ==================================================================

    tempname b V
    matrix `b' = e(b)
    matrix `V' = e(V)

    local col = 0
    forvalues t = 1/`k' {
        if `t' != `ref_code' {
            local ++col
            local pcol_`t' = `col'
        }
    }

    * ==================================================================
    * COMPUTE ESTIMATES FOR EACH PAIR (i < j)
    * ==================================================================

    local n_pairs = 0
    local n_ct_direct = 0
    local n_ct_indirect = 0
    local n_ct_mixed = 0

    forvalues i = 1/`k' {
        forvalues j = `=`i'+1'/`k' {
            local ev = _nma_evidence[`i', `j']
            if `ev' == 0 continue
            if "`comparisons'" == "mixed" & `ev' != 3 continue

            local ++n_pairs
            local pair_i_`n_pairs' = `i'
            local pair_j_`n_pairs' = `j'
            local pair_ev_`n_pairs' = `ev'

            if `ev' == 1 local ++n_ct_direct
            else if `ev' == 2 local ++n_ct_indirect
            else if `ev' == 3 local ++n_ct_mixed

            * --- Network estimate: d_ij = d_iR - d_jR ---
            local d_iR = 0
            local d_jR = 0
            if `i' != `ref_code' local d_iR = `b'[1, `pcol_`i'']
            if `j' != `ref_code' local d_jR = `b'[1, `pcol_`j'']
            local d_nma = `d_iR' - `d_jR'

            local v_iR = 0
            local v_jR = 0
            local cov_ij = 0
            if `i' != `ref_code' {
                local v_iR = `V'[`pcol_`i'', `pcol_`i'']
            }
            if `j' != `ref_code' {
                local v_jR = `V'[`pcol_`j'', `pcol_`j'']
            }
            if `i' != `ref_code' & `j' != `ref_code' {
                local cov_ij = `V'[`pcol_`i'', `pcol_`j'']
            }
            local v_nma = `v_iR' + `v_jR' - 2 * `cov_ij'
            local se_nma = sqrt(max(`v_nma', 0))

            local nma_est_`n_pairs' = `d_nma'
            local nma_se_`n_pairs' = `se_nma'

            * --- Direct estimate (evidence type 1 or 3) ---
            if `ev' == 1 | `ev' == 3 {
                local sum_w = 0
                local sum_wy = 0
                forvalues obs = 1/`=_N' {
                    local t_obs = _nma_trt[`obs']
                    if `has_base_trt' {
                        local b_obs = _nma_base_trt[`obs']
                    }
                    else {
                        local b_obs = `ref_code'
                    }

                    local is_ij = 0
                    local flip = 1
                    if (`t_obs' == `i' & `b_obs' == `j') | ///
                       (`t_obs' == `j' & `b_obs' == `i') {
                        local is_ij = 1
                        if `t_obs' == `j' local flip = -1
                    }

                    if `is_ij' {
                        local w = 1 / (_nma_se[`obs']^2)
                        local y_val = `flip' * _nma_y[`obs']
                        local sum_w = `sum_w' + `w'
                        local sum_wy = `sum_wy' + `w' * `y_val'
                    }
                }

                if `sum_w' > 0 {
                    local dir_est_`n_pairs' = `sum_wy' / `sum_w'
                    local dir_se_`n_pairs' = sqrt(1 / `sum_w')
                }
                else {
                    local dir_est_`n_pairs' = `d_nma'
                    local dir_se_`n_pairs' = `se_nma'
                }
            }

            * --- Indirect back-calculation (evidence type 3) ---
            if `ev' == 3 {
                local v_direct = `dir_se_`n_pairs''^2
                local w_nma = 1 / max(`v_nma', 1e-10)
                local w_dir = 1 / max(`v_direct', 1e-10)
                local w_ind = `w_nma' - `w_dir'

                if `w_ind' > 0 {
                    local ind_est_`n_pairs' = (`w_nma' * `d_nma' - ///
                        `w_dir' * `dir_est_`n_pairs'') / `w_ind'
                    local ind_se_`n_pairs' = sqrt(1 / `w_ind')
                }
                else {
                    local ind_est_`n_pairs' = `d_nma'
                    local ind_se_`n_pairs' = `se_nma'
                }
            }

            * --- Indirect-only (evidence type 2): indirect = network ---
            if `ev' == 2 {
                local ind_est_`n_pairs' = `d_nma'
                local ind_se_`n_pairs' = `se_nma'
            }
        }
    }

    * Check for empty result
    if `n_pairs' == 0 {
        if "`comparisons'" == "mixed" {
            display as text "No mixed-evidence comparisons found." _newline ///
                "Use {bf:comparisons(all)} to show all pairs."
        }
        else {
            display as text "No evidence-based comparisons available."
        }
        return scalar n_comparisons = 0
        return scalar n_direct = 0
        return scalar n_indirect = 0
        return scalar n_mixed = 0
        return local ref "`ref'"
        exit
    }

    * ==================================================================
    * BUILD PLOT DATASET
    * ==================================================================

    * Count total rows
    local total_rows = 0
    forvalues p = 1/`n_pairs' {
        local ++total_rows
        local ev = `pair_ev_`p''
        if `ev' == 1      local total_rows = `total_rows' + 2
        else if `ev' == 2  local ++total_rows
        else if `ev' == 3  local total_rows = `total_rows' + 3
        if `p' < `n_pairs' local ++total_rows
    }

    preserve

    quietly {
        clear
        set obs `total_rows'
        gen byte rowtype = .
        gen double est = .
        gen double ci_lo = .
        gen double ci_hi = .
        gen double ypos = .
        gen double diam_hi = .
        gen double diam_lo = .
        gen str40 text_col = ""
        gen double text_xpos = .
    }

    local diam_height = 0.3
    local row = 0
    local ylabels ""

    quietly {
    forvalues p = 1/`n_pairs' {
        local i = `pair_i_`p''
        local j = `pair_j_`p''
        local ev = `pair_ev_`p''
        local lbl_i "`trtlbl_`i''"
        local lbl_j "`trtlbl_`j''"

        * Header row
        local ++row
        replace rowtype = 0 in `row'
        replace ypos = `row' in `row'
        local ylabels `"`ylabels' `row' `"{bf:`lbl_i' vs `lbl_j'}"'"'

        * Direct row (evidence type 1 or 3)
        if `ev' == 1 | `ev' == 3 {
            local ++row
            local d = `dir_est_`p''
            local se = `dir_se_`p''
            local lo = `d' - `z_crit' * `se'
            local hi = `d' + `z_crit' * `se'
            if `use_eform' {
                local d = exp(`d')
                local lo = exp(`lo')
                local hi = exp(`hi')
            }
            replace rowtype = 1 in `row'
            replace ypos = `row' in `row'
            replace est = `d' in `row'
            replace ci_lo = `lo' in `row'
            replace ci_hi = `hi' in `row'
            local ylabels `"`ylabels' `row' `"  Direct"'"'
        }

        * Indirect row (evidence type 2 or 3)
        if `ev' == 2 | `ev' == 3 {
            local ++row
            local d = `ind_est_`p''
            local se = `ind_se_`p''
            local lo = `d' - `z_crit' * `se'
            local hi = `d' + `z_crit' * `se'
            if `use_eform' {
                local d = exp(`d')
                local lo = exp(`lo')
                local hi = exp(`hi')
            }
            replace rowtype = 2 in `row'
            replace ypos = `row' in `row'
            replace est = `d' in `row'
            replace ci_lo = `lo' in `row'
            replace ci_hi = `hi' in `row'
            local ylabels `"`ylabels' `row' `"  Indirect"'"'
        }

        * Network row (evidence type 1 or 3)
        if `ev' == 1 | `ev' == 3 {
            local ++row
            local d = `nma_est_`p''
            local se = `nma_se_`p''
            local lo = `d' - `z_crit' * `se'
            local hi = `d' + `z_crit' * `se'
            if `use_eform' {
                local d = exp(`d')
                local lo = exp(`lo')
                local hi = exp(`hi')
            }
            replace rowtype = 3 in `row'
            replace ypos = `row' in `row'
            replace est = `d' in `row'
            replace ci_lo = `lo' in `row'
            replace ci_hi = `hi' in `row'
            replace diam_hi = `row' + `diam_height' in `row'
            replace diam_lo = `row' - `diam_height' in `row'
            local ylabels `"`ylabels' `row' `"  Network"'"'
        }

        * Spacer row (not after last pair)
        if `p' < `n_pairs' {
            local ++row
            replace rowtype = 9 in `row'
            replace ypos = `row' in `row'
        }
    }
    }

    * Text column
    if "`textcol'" != "" {
        quietly {
            forvalues r = 1/`total_rows' {
                local rt = rowtype[`r']
                if inlist(`rt', 1, 2, 3) {
                    local e = est[`r']
                    local l = ci_lo[`r']
                    local h = ci_hi[`r']
                    local e_s : display %9.`dp'f `e'
                    local l_s : display %9.`dp'f `l'
                    local h_s : display %9.`dp'f `h'
                    local e_s = strtrim("`e_s'")
                    local l_s = strtrim("`l_s'")
                    local h_s = strtrim("`h_s'")
                    replace text_col = "`e_s' (`l_s', `h_s')" in `r'
                }
            }

            * Position text in a column to the right of all data (metan-style)
            summarize ci_hi if inlist(rowtype, 1, 2, 3)
            local x_hi = r(max)
            summarize ci_lo if inlist(rowtype, 1, 2, 3)
            local x_lo = r(min)
            local x_range = `x_hi' - `x_lo'
            local text_x = `x_hi' + `x_range' * 0.18
            replace text_xpos = `text_x' if text_col != ""
        }
    }

    * ==================================================================
    * CONSTRUCT GRAPH
    * ==================================================================

    * Adaptive legend
    local has_direct = 0
    local has_indirect = 0
    local has_network = 0
    quietly {
        count if rowtype == 1
        if r(N) > 0 local has_direct = 1
        count if rowtype == 2
        if r(N) > 0 local has_indirect = 1
        count if rowtype == 3
        if r(N) > 0 local has_network = 1
    }

    * Legend layer numbers depend on network rendering mode
    local legend_order ""
    if `has_direct' local legend_order `"`legend_order' 2 "Direct""'
    if `has_indirect' local legend_order `"`legend_order' 4 "Indirect""'
    if "`diamond'" != "" {
        * Diamond mode: network legend on layer 5 (first pcspike)
        if `has_network' local legend_order `"`legend_order' 5 "Network""'
    }
    else {
        * Dot mode: network legend on layer 6 (scatter)
        if `has_network' local legend_order `"`legend_order' 6 "Network""'
    }

    * Optional graph elements
    local save_opt ""
    if "`saving'" != "" {
        local save_opt `"saving("`saving'", `replace')"'
    }

    local name_opt ""
    if "`name'" != "" {
        local name_opt `"name(`name', replace)"'
    }

    local xlabel_opt ""
    if "`xlabel'" != "" {
        local xlabel_opt `"xlabel(`xlabel')"'
    }

    if `"`title'"' == "" {
        local title "Evidence Decomposition Forest Plot"
    }

    * Adaptive graph height: scale with number of rows
    local ysize = max(4, `total_rows' * 0.22)
    * Keep width proportional so title/content don't truncate
    local xsize = max(5.5, `ysize' * 0.55)
    * Shrink title for tall plots so it doesn't truncate on export
    local title_size "medsmall"
    if `ysize' > 8 local title_size "small"

    * Extend x-axis to accommodate text column without overlapping data
    local xscale_opt ""
    if "`textcol'" != "" {
        local xsc_right = `text_x' + `x_range' * 0.55
        local xscale_opt "xscale(range(. `xsc_right'))"
        * Keep x-axis ticks within data range only
        if "`xlabel'" == "" {
            local tick_lo = floor(`x_lo')
            local tick_hi = ceil(`x_hi')
            local tick_range = `tick_hi' - `tick_lo'
            local tick_step = cond(`tick_range' > 6, 2, 1)
            local xlabel_opt "xlabel(`tick_lo'(`tick_step')`tick_hi')"
        }
    }

    if "`diamond'" != "" {
        * Diamond mode: pcspike x4 for network
        twoway ///
            (rspike ci_lo ci_hi ypos if rowtype == 1, ///
                horizontal lcolor(`col_direct') lwidth(medthick)) ///
            (scatter ypos est if rowtype == 1, ///
                msymbol(O) mcolor(`col_direct') msize(medsmall)) ///
            (rspike ci_lo ci_hi ypos if rowtype == 2, ///
                horizontal lcolor(`col_indirect') lwidth(medthick)) ///
            (scatter ypos est if rowtype == 2, ///
                msymbol(O) mcolor(`col_indirect') msize(medsmall)) ///
            (pcspike ypos ci_lo diam_hi est if rowtype == 3, ///
                lcolor(`col_network') lwidth(medthick)) ///
            (pcspike diam_hi est ypos ci_hi if rowtype == 3, ///
                lcolor(`col_network') lwidth(medthick)) ///
            (pcspike ypos ci_hi diam_lo est if rowtype == 3, ///
                lcolor(`col_network') lwidth(medthick)) ///
            (pcspike diam_lo est ypos ci_lo if rowtype == 3, ///
                lcolor(`col_network') lwidth(medthick)) ///
            (scatter ypos text_xpos if text_col != "", ///
                msymbol(none) mlabel(text_col) mlabposition(3) ///
                mlabsize(vsmall) mlabcolor(gs5)) ///
            , ///
            ylabel(`ylabels', angle(0) labsize(vsmall) nogrid) ///
            yscale(reverse range(0 `=`total_rows' + 1')) ///
            `xscale_opt' ///
            ytitle("") ///
            xtitle(`"`xtitle'"') ///
            `xlabel_opt' ///
            xline(`null_val', lcolor(gs10) lpattern(dash)) ///
            title(`"`title'"', size(`title_size')) ///
            legend(order(`legend_order') rows(1) position(6) size(small)) ///
            scheme(`scheme') ///
            xsize(`xsize') ysize(`ysize') ///
            graphregion(margin(l+12 r+6)) ///
            `save_opt' ///
            `name_opt'
    }
    else {
        * Default: dot + CI for all evidence types
        twoway ///
            (rspike ci_lo ci_hi ypos if rowtype == 1, ///
                horizontal lcolor(`col_direct') lwidth(medthick)) ///
            (scatter ypos est if rowtype == 1, ///
                msymbol(O) mcolor(`col_direct') msize(medsmall)) ///
            (rspike ci_lo ci_hi ypos if rowtype == 2, ///
                horizontal lcolor(`col_indirect') lwidth(medthick)) ///
            (scatter ypos est if rowtype == 2, ///
                msymbol(O) mcolor(`col_indirect') msize(medsmall)) ///
            (rspike ci_lo ci_hi ypos if rowtype == 3, ///
                horizontal lcolor(`col_network') lwidth(medthick)) ///
            (scatter ypos est if rowtype == 3, ///
                msymbol(O) mcolor(`col_network') msize(medsmall)) ///
            (scatter ypos text_xpos if text_col != "", ///
                msymbol(none) mlabel(text_col) mlabposition(3) ///
                mlabsize(vsmall) mlabcolor(gs5)) ///
            , ///
            ylabel(`ylabels', angle(0) labsize(vsmall) nogrid) ///
            yscale(reverse range(0 `=`total_rows' + 1')) ///
            `xscale_opt' ///
            ytitle("") ///
            xtitle(`"`xtitle'"') ///
            `xlabel_opt' ///
            xline(`null_val', lcolor(gs10) lpattern(dash)) ///
            title(`"`title'"', size(`title_size')) ///
            legend(order(`legend_order') rows(1) position(6) size(small)) ///
            scheme(`scheme') ///
            xsize(`xsize') ysize(`ysize') ///
            graphregion(margin(l+12 r+6)) ///
            `save_opt' ///
            `name_opt'
    }

    restore

    * ==================================================================
    * RETURNS
    * ==================================================================

    local s = cond(`n_pairs' > 1, "s", "")
    display as text "Forest plot created: `n_pairs' comparison`s' (ref: `ref')"

    return scalar n_comparisons = `n_pairs'
    return scalar n_direct = `n_ct_direct'
    return scalar n_indirect = `n_ct_indirect'
    return scalar n_mixed = `n_ct_mixed'
    return local ref "`ref'"

    set varabbrev `_varabbrev'
end
