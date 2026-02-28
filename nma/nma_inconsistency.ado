*! nma_inconsistency Version 1.0.3  2026/02/28
*! Inconsistency testing for network meta-analysis
*! Author: Timothy P Copeland
*! Department of Clinical Neuroscience, Karolinska Institutet
*! Program class: rclass (returns results in r())

/*
Basic syntax:
  nma_inconsistency [, method(global|nodesplit|both) level(cilevel)]

Description:
  Tests for inconsistency in the network meta-analysis. Global test
  compares consistency vs inconsistency model. Node-splitting separates
  direct and indirect evidence for mixed-evidence comparisons.

See help nma_inconsistency for complete documentation
*/

program define nma_inconsistency, rclass
    version 16.0
    set varabbrev off
    set more off

    syntax [, METHod(string) Level(cilevel)]

    if "`method'" == "" local method "both"
    if !inlist("`method'", "global", "nodesplit", "both") {
        display as error "method() must be global, nodesplit, or both"
        exit 198
    }
    if "`level'" == "" local level 95

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
    local n_studies   = `_nma_n_studies'
    local ref_code    : char _dta[_nma_ref_code]
    local measure     "`_nma_measure'"

    _nma_display_header, command("nma_inconsistency") ///
        description("Inconsistency assessment")

    local z_crit = invnormal(1 - (1 - `level'/100) / 2)

    * =======================================================================
    * GLOBAL INCONSISTENCY TEST
    * =======================================================================

    * Check once whether _nma_base_trt variable exists
    local has_base_trt = 0
    capture confirm variable _nma_base_trt
    if _rc == 0 local has_base_trt = 1

    if "`method'" == "global" | "`method'" == "both" {
        * Compare consistency model (fitted) vs inconsistency model
        * Inconsistency model: separate parameter for each direct comparison
        * This is equivalent to a standard pairwise MA for each comparison

        * Consistency model log-likelihood (already fitted)
        local ll_con : char _dta[_nma_tau2]
        tempname b_con V_con
        matrix `b_con' = e(b)
        matrix `V_con' = e(V)
        local ll_consistency = e(ll)
        local df_con = colsof(`b_con')

        * Fit inconsistency model: one parameter per direct comparison
        * For now, compute via design-by-treatment interaction
        * df_incon = number of direct comparisons
        * chi2 = 2 * (ll_incon - ll_con), df = df_incon - df_con

        * Count direct comparisons for df
        local n_direct_pairs = 0
        forvalues i = 1/`k' {
            forvalues j = `=`i'+1'/`k' {
                if _nma_adj[`i', `j'] > 0 local ++n_direct_pairs
            }
        }

        * Inconsistency model: fit separate MA for each comparison
        * Log-likelihood = sum of individual comparison log-likelihoods
        local ll_incon = 0
        local df_incon = `n_direct_pairs'

        * For each direct comparison, compute within-comparison MA
        quietly {
        forvalues i = 1/`k' {
            forvalues j = `=`i'+1'/`k' {
                if _nma_adj[`i', `j'] > 0 {
                    * Get studies comparing i and j
                    * Compute simple random-effects MA for this pair
                    tempvar is_pair
                    gen byte `is_pair' = 0
                    forvalues obs = 1/`=_N' {
                        local t1 = _nma_trt[`obs']
                        if `has_base_trt' {
                            local t2 = _nma_base_trt[`obs']
                        }
                        else {
                            local t2 = `ref_code'
                        }
                        if (`t1' == `i' & `t2' == `j') | (`t1' == `j' & `t2' == `i') {
                            replace `is_pair' = 1 in `obs'
                        }
                    }

                    * Simple MA: weighted mean with DerSimonian-Laird tau2
                    count if `is_pair'
                    if r(N) > 0 {
                        tempvar w_fe
                        gen double `w_fe' = 1 / _nma_se^2 if `is_pair'
                        summarize `w_fe' if `is_pair'
                        local sum_w = r(sum)
                        tempvar wy
                        gen double `wy' = `w_fe' * _nma_y if `is_pair'
                        summarize `wy' if `is_pair'
                        local sum_wy = r(sum)
                        local theta_fe = `sum_wy' / `sum_w'

                        * Q statistic for this comparison
                        tempvar qi
                        gen double `qi' = `w_fe' * (_nma_y - `theta_fe')^2 if `is_pair'
                        summarize `qi' if `is_pair'
                        local Q_i = r(sum)

                        * Approximate contribution to log-likelihood
                        * ll = -0.5 * Q_i (under fixed effect)
                        local ll_incon = `ll_incon' - 0.5 * `Q_i'

                        drop `w_fe' `wy' `qi'
                    }

                    drop `is_pair'
                }
            }
        }
        }

        * Chi-squared test
        local chi2_df = `df_incon' - `df_con'
        if `chi2_df' > 0 {
            local chi2 = max(0, 2 * (`ll_incon' - `ll_consistency'))
            local chi2_p = chi2tail(`chi2_df', `chi2')
        }
        else {
            local chi2 = 0
            local chi2_p = 1
            local chi2_df = 0
        }

        display as text "Global inconsistency test:"
        display as text "  chi2(" as result "`chi2_df'" as text ") = " ///
            as result %7.2f `chi2' ///
            as text ", p = " as result %6.3f `chi2_p'
        display as text ""

        return scalar chi2 = `chi2'
        return scalar chi2_df = `chi2_df'
        return scalar chi2_p = `chi2_p'
    }

    * =======================================================================
    * NODE-SPLITTING
    * =======================================================================

    if "`method'" == "nodesplit" | "`method'" == "both" {
        display as text "Node-splitting results (mixed-evidence comparisons only):"
        display as text "{hline 70}"
        display as text %-20s "Comparison" _col(22) %~9s "Direct" ///
            _col(33) %~9s "Indirect" _col(44) %~9s "Diff" ///
            _col(55) %~8s "SE" _col(65) %~8s "P-value"
        display as text "{hline 70}"

        * Collect skipped comparisons
        local skip_direct ""
        local skip_indirect ""
        local n_split = 0

        tempname b_fit V_fit
        matrix `b_fit' = e(b)
        matrix `V_fit' = e(V)
        local p = colsof(`b_fit')

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

        * Node-split on mixed-evidence comparisons only
        forvalues i = 1/`k' {
            forvalues j = `=`i'+1'/`k' {
                local ev = _nma_evidence[`i', `j']
                local lbl_i : word `i' of `treatments'
                local lbl_j : word `j' of `treatments'

                if `ev' == 1 {
                    local skip_direct "`skip_direct' `lbl_i' vs `lbl_j',"
                }
                else if `ev' == 2 {
                    local skip_indirect "`skip_indirect' `lbl_i' vs `lbl_j',"
                }
                else if `ev' == 3 {
                    local ++n_split

                    * Direct estimate: weighted average of studies directly comparing i and j
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
                        if (`t_obs' == `i' & `b_obs' == `j') | (`t_obs' == `j' & `b_obs' == `i') {
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

                    local d_direct = `sum_wy' / `sum_w'
                    local se_direct = sqrt(1 / `sum_w')

                    * Indirect estimate: NMA estimate minus direct contribution
                    * Use the consistency model estimate for i vs j
                    local d_iR = 0
                    local d_jR = 0
                    if `i' != `ref_code' local d_iR = `b_fit'[1, `pcol_`i'']
                    if `j' != `ref_code' local d_jR = `b_fit'[1, `pcol_`j'']
                    local d_nma = `d_iR' - `d_jR'

                    * Indirect = back-calculated from NMA and direct
                    * Using Bucher method: d_indirect from network excluding direct
                    * Simplified: d_indirect = (d_nma * v_direct - d_direct * v_nma) / (v_direct - v_nma)
                    * Or more simply: w_nma * d_nma = w_direct * d_direct + w_indirect * d_indirect

                    local v_direct = 1 / `sum_w'
                    local v_iR = 0
                    local v_jR = 0
                    local cov_ij = 0
                    if `i' != `ref_code' local v_iR = `V_fit'[`pcol_`i'', `pcol_`i'']
                    if `j' != `ref_code' local v_jR = `V_fit'[`pcol_`j'', `pcol_`j'']
                    if `i' != `ref_code' & `j' != `ref_code' {
                        local cov_ij = `V_fit'[`pcol_`i'', `pcol_`j'']
                    }
                    local v_nma = `v_iR' + `v_jR' - 2 * `cov_ij'

                    * Back-calculate indirect
                    if `v_direct' > `v_nma' {
                        local w_nma = 1 / max(`v_nma', 1e-10)
                        local w_dir = 1 / max(`v_direct', 1e-10)
                        local w_ind = `w_nma' - `w_dir'
                        if `w_ind' > 0 {
                            local d_indirect = (`w_nma' * `d_nma' - `w_dir' * `d_direct') / `w_ind'
                            local se_indirect = sqrt(1 / `w_ind')
                        }
                        else {
                            local d_indirect = `d_nma'
                            local se_indirect = sqrt(`v_nma')
                        }
                    }
                    else {
                        local d_indirect = `d_nma'
                        local se_indirect = sqrt(max(`v_nma', `v_direct'))
                    }

                    * Inconsistency factor
                    local incon = `d_direct' - `d_indirect'
                    local se_incon = sqrt(`se_direct'^2 + `se_indirect'^2)
                    local z_incon = `incon' / `se_incon'
                    local p_incon = 2 * (1 - normal(abs(`z_incon')))

                    * Format p-value
                    if `p_incon' < 0.001 {
                        local pstr "<0.001"
                    }
                    else {
                        local pstr : display %6.3f `p_incon'
                    }

                    display as result %-20s "`lbl_i' vs `lbl_j'" ///
                        _col(22) %9.3f `d_direct' ///
                        _col(33) %9.3f `d_indirect' ///
                        _col(44) %9.3f `incon' ///
                        _col(55) %7.3f `se_incon' ///
                        _col(65) %8s "`pstr'"
                }
            }
        }

        display as text "{hline 70}"

        if "`skip_direct'" != "" {
            local skip_direct = substr("`skip_direct'", 1, length("`skip_direct'") - 1)
            display as text "Skipped (direct-only, no indirect path): `skip_direct'"
        }
        if "`skip_indirect'" != "" {
            local skip_indirect = substr("`skip_indirect'", 1, length("`skip_indirect'") - 1)
            display as text "Skipped (indirect-only, no direct studies): `skip_indirect'"
        }

        return scalar n_nodesplit = `n_split'
    }
end
