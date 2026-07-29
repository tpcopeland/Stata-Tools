*! _psdash_balance_multigroup Version 1.6.1  2026/07/29
*! Multi-group covariate balance statistics
*! Author: Timothy P Copeland, Karolinska Institutet
*! Program class: rclass
*! Internal helper

program define _psdash_balance_multigroup, rclass
    version 16.0
    local _vao = c(varabbrev)
    set varabbrev off

    capture noisily {
        syntax varlist(numeric), TREATment(varname numeric) SAMPLEvar(varname) ///
            LEVELS(string asis) REFerence(string) THReshold(real) ///
            [Wvar(varname numeric) VRLo(real 0.5) VRHi(real 2) LABels(string asis)]

        return clear
        local nvars : word count `varlist'
        local has_adj = ("`wvar'" != "")

        * Readable row labels for factor-variable design columns (RB-03); see the
        * binary helper. Falls back to the varlist tokens when labels() is absent.
        if `"`labels'"' == "" local labels `"`varlist'"'

        local contrasts ""
        local n_contrasts = 0
        foreach lev of local levels {
            if "`lev'" != "`reference'" {
                local contrasts "`contrasts' `lev'"
                local n_contrasts = `n_contrasts' + 1
            }
        }
        local contrasts = strtrim("`contrasts'")

        local ncols_raw = 5 * `n_contrasts'
        local ncols_adj = 0
        if `has_adj' {
            local ncols_adj = 5 * `n_contrasts'
        }
        local ncols = `ncols_raw' + `ncols_adj'

        preserve
        quietly keep if `samplevar'

        foreach lev of local levels {
            quietly count if `treatment' == `lev'
            local n_group_`lev' = r(N)
            if `n_group_`lev'' < 2 {
                display as error "group `lev' must have at least 2 observations"
                exit 2001
            }
        }

        tempname balance_mat
        matrix `balance_mat' = J(`nvars', `ncols', .)

        local colnames ""
        foreach clev of local contrasts {
            local colnames "`colnames' Mean_`clev' Mean_`reference' SMD_`clev'v`reference' VR_`clev'v`reference' KS_`clev'v`reference'"
        }
        if `has_adj' {
            foreach clev of local contrasts {
                local colnames "`colnames' MnAdj_`clev' MnAdj_`reference' SMDAdj_`clev'v`reference' VRAdj_`clev'v`reference' KSAdj_`clev'v`reference'"
            }
        }
        matrix colnames `balance_mat' = `colnames'
        local rownames ""

        * RB-12: see the binary helper. Covariates are not marked out of the panel
        * sample, so rows can rest on different N; count and name the incomplete
        * ones so the caller can footnote them.
        local n_cov_incomplete = 0
        local cov_miss_vars ""
        quietly count
        local _n_panel = r(N)
        local n_cov_min = `_n_panel'

        if `has_adj' {
            tempvar _wt_sq_all
            quietly gen double `_wt_sq_all' = `wvar'^2
        }

        local i = 1
        foreach var of local varlist {
            local rownames `"`rownames' `: word `i' of `labels''"'

            quietly count if missing(`var')
            if r(N) > 0 {
                local ++n_cov_incomplete
                local cov_miss_vars `"`cov_miss_vars' `: word `i' of `labels''"'
                local _n_this = `_n_panel' - r(N)
                if `_n_this' < `n_cov_min' local n_cov_min = `_n_this'
            }

            * Flag binary/indicator covariates (VR uninformative; see binary helper)
            quietly summarize `var'
            local _vmin = r(min)
            local _vmax = r(max)
            quietly count if `var' != `_vmin' & `var' != `_vmax' & !missing(`var')
            local _isbin_`i' = (r(N) == 0 & `_vmin' != `_vmax')
            local _vrange = `_vmax' - `_vmin'

            quietly summarize `var' if `treatment' == `reference'
            local _n_ref_var = r(N)
            local mean_ref = r(mean)
            local var_ref = r(Var)

            if `_isbin_`i'' & !missing(`mean_ref') {
                local _p_ref = (`mean_ref' - `_vmin') / `_vrange'
                local var_ref = (`_vrange'^2) * `_p_ref' * (1 - `_p_ref')
            }

            if `has_adj' {
                quietly summarize `var' [aw=`wvar'] if `treatment' == `reference'
                local _n_ref_adj = r(N)
                local _wt_ref = r(sum_w)
                local mean_ref_adj = r(mean)
                local _awvar_ref = r(Var)
                local var_ref_adj = .

                if `_isbin_`i'' {
                    if !missing(`mean_ref_adj') {
                        local _p_ref_adj = (`mean_ref_adj' - `_vmin') / `_vrange'
                        local var_ref_adj = ///
                            (`_vrange'^2) * `_p_ref_adj' * (1 - `_p_ref_adj')
                    }
                }
                else {
                    quietly summarize `_wt_sq_all' ///
                        if `treatment' == `reference' & !missing(`var'), meanonly
                    local _wt2_ref = r(sum)
                    if `_n_ref_adj' > 1 & `_wt_ref'^2 > `_wt2_ref' & ///
                            !missing(`_awvar_ref') {
                        local var_ref_adj = `_awvar_ref' * ///
                            ((`_n_ref_adj' - 1) / `_n_ref_adj') * ///
                            (`_wt_ref'^2 / (`_wt_ref'^2 - `_wt2_ref'))
                    }
                }
            }

            * All pairwise KS contrasts share this covariate order and reference
            * empirical CDF. Build each once instead of re-sorting and rebuilding
            * the reference distribution for every treatment contrast.
            sort `var'
            tempvar _last _cfref_raw
            quietly by `var': gen byte `_last' = (_n == _N)
            if `_n_ref_var' > 0 {
                quietly gen double `_cfref_raw' = ///
                    sum(cond(`treatment' == `reference' & !missing(`var'), 1, 0)) / ///
                    `_n_ref_var'
            }
            if `has_adj' {
                tempvar _cfref_adj
                if `_wt_ref' > 0 {
                    quietly gen double `_cfref_adj' = ///
                        sum(cond(`treatment' == `reference' & !missing(`var'), ///
                        `wvar', 0)) / `_wt_ref'
                }
            }

            local cnum = 0
            foreach clev of local contrasts {
                local cnum = `cnum' + 1
                local col_base = (`cnum' - 1) * 5

                quietly summarize `var' if `treatment' == `clev'
                local _n_a_var = r(N)
                local mean_a = r(mean)
                local var_a = r(Var)

                if `_isbin_`i'' & !missing(`mean_a') {
                    local _p_a = (`mean_a' - `_vmin') / `_vrange'
                    local var_a = (`_vrange'^2) * `_p_a' * (1 - `_p_a')
                }

                local sd_pooled = sqrt((`var_a' + `var_ref') / 2)
                if `sd_pooled' > 0 {
                    local smd_raw = (`mean_a' - `mean_ref') / `sd_pooled'
                }
                else if `mean_a' != `mean_ref' {
                    local smd_raw = .
                }
                else {
                    local smd_raw = 0
                }

                if `var_a' > 0 & `var_ref' > 0 {
                    local vr_raw = `var_a' / `var_ref'
                }
                else {
                    local vr_raw = .
                }

                local ks_raw = .
                if `_n_a_var' > 0 & `_n_ref_var' > 0 {
                    tempvar _cfa_raw _ksd_raw
                    quietly gen double `_cfa_raw' = ///
                        sum(cond(`treatment' == `clev' & !missing(`var'), 1, 0)) / ///
                        `_n_a_var'
                    quietly gen double `_ksd_raw' = ///
                        abs(`_cfa_raw' - `_cfref_raw') ///
                        if `_last' & !missing(`var')
                    quietly summarize `_ksd_raw', meanonly
                    if r(N) > 0 local ks_raw = r(max)
                    drop `_cfa_raw' `_ksd_raw'
                }

                matrix `balance_mat'[`i', `col_base' + 1] = `mean_a'
                matrix `balance_mat'[`i', `col_base' + 2] = `mean_ref'
                matrix `balance_mat'[`i', `col_base' + 3] = `smd_raw'
                matrix `balance_mat'[`i', `col_base' + 4] = `vr_raw'
                matrix `balance_mat'[`i', `col_base' + 5] = `ks_raw'

                if `has_adj' {
                    local adj_base = `ncols_raw' + (`cnum' - 1) * 5

                    quietly summarize `var' [aw=`wvar'] if `treatment' == `clev'
                    local _n_a_adj = r(N)
                    local _wt_a = r(sum_w)
                    local mean_a_adj = r(mean)
                    local _awvar_a = r(Var)

                    local var_a_adj = .
                    if `_isbin_`i'' {
                        if !missing(`mean_a_adj') {
                            local _p_a_adj = (`mean_a_adj' - `_vmin') / `_vrange'
                            local var_a_adj = ///
                                (`_vrange'^2) * `_p_a_adj' * (1 - `_p_a_adj')
                        }
                    }
                    else {
                        quietly summarize `_wt_sq_all' ///
                            if `treatment' == `clev' & !missing(`var'), meanonly
                        local _wt2_a = r(sum)
                        if `_n_a_adj' > 1 & `_wt_a'^2 > `_wt2_a' & ///
                                !missing(`_awvar_a') {
                            local var_a_adj = `_awvar_a' * ///
                                ((`_n_a_adj' - 1) / `_n_a_adj') * ///
                                (`_wt_a'^2 / (`_wt_a'^2 - `_wt2_a'))
                        }
                    }

                    * RB-12: unweighted pooled SD reused for the adjusted column
                    * (cobalt convention), NOT the Austin & Stuart (2015) 4.1.1
                    * weighted variance. See the binary helper for the full note.
                    if `sd_pooled' > 0 {
                        local smd_adj = (`mean_a_adj' - `mean_ref_adj') / `sd_pooled'
                    }
                    else if `mean_a_adj' != `mean_ref_adj' {
                        local smd_adj = .
                    }
                    else {
                        local smd_adj = 0
                    }

                    if `var_a_adj' > 0 & `var_ref_adj' > 0 {
                        local vr_adj = `var_a_adj' / `var_ref_adj'
                    }
                    else {
                        local vr_adj = .
                    }

                    * Weighted Kolmogorov-Smirnov (contrast group vs reference)
                    local ks_adj = .
                    if `_wt_a' > 0 & `_wt_ref' > 0 {
                        tempvar _cfa _ksd
                        quietly gen double `_cfa' = ///
                            sum(cond(`treatment' == `clev' & !missing(`var'), `wvar', 0)) / `_wt_a'
                        quietly gen double `_ksd' = ///
                            abs(`_cfa' - `_cfref_adj') if `_last' & !missing(`var')
                        quietly summarize `_ksd', meanonly
                        if r(N) > 0 local ks_adj = r(max)
                        drop `_cfa' `_ksd'
                    }

                    matrix `balance_mat'[`i', `adj_base' + 1] = `mean_a_adj'
                    matrix `balance_mat'[`i', `adj_base' + 2] = `mean_ref_adj'
                    matrix `balance_mat'[`i', `adj_base' + 3] = `smd_adj'
                    matrix `balance_mat'[`i', `adj_base' + 4] = `vr_adj'
                    matrix `balance_mat'[`i', `adj_base' + 5] = `ks_adj'
                }
            }
            if `_n_ref_var' > 0 drop `_cfref_raw'
            if `has_adj' {
                if `_wt_ref' > 0 drop `_cfref_adj'
            }
            drop `_last'

            local i = `i' + 1
        }
        matrix rownames `balance_mat' = `rownames'

        restore

        local max_smd_raw = 0
        local max_smd_adj = 0
        local max_vr_raw = 1
        local max_vr_adj = 1
        local max_vr_raw_dev = 0
        local max_vr_adj_dev = 0
        local max_ks_raw = 0
        local max_ks_adj = 0
        local n_imbalanced = 0
        * RB-08: count imbalanced COVARIATES (the documented unit), not pairwise
        * contrasts. A single covariate with two out-of-bounds contrasts is one
        * imbalanced covariate; the contrast tally is returned separately. Raw and
        * adjusted are counted independently so the weighted verdict judges the
        * adjusted VR.
        local n_vr_imbalanced_raw = 0
        local n_vr_imbalanced_adj = 0
        local n_vr_contrasts_raw = 0
        local n_vr_contrasts_adj = 0
        local n_binary_vr = 0
        local vr_na_vars ""

        forvalues i = 1/`nvars' {
            local worst_smd_raw_i = 0
            local worst_smd_adj_i = 0
            local cov_imbalanced = 0
            local cov_vr_raw_i = 0
            local cov_vr_adj_i = 0

            if `_isbin_`i'' {
                local n_binary_vr = `n_binary_vr' + 1
                local vr_na_vars "`vr_na_vars' `: word `i' of `rownames''"
            }

            local cnum = 0
            foreach clev of local contrasts {
                local cnum = `cnum' + 1
                local col_smd_raw = (`cnum' - 1) * 5 + 3
                local col_vr_raw = (`cnum' - 1) * 5 + 4
                local col_ks_raw = (`cnum' - 1) * 5 + 5

                if !missing(`balance_mat'[`i', `col_smd_raw']) {
                    local abs_smd = abs(`balance_mat'[`i', `col_smd_raw'])
                    if `abs_smd' > `worst_smd_raw_i' local worst_smd_raw_i = `abs_smd'
                    if `abs_smd' > `max_smd_raw' local max_smd_raw = `abs_smd'
                }

                if !`_isbin_`i'' & !missing(`balance_mat'[`i', `col_vr_raw']) {
                    local vr_i = `balance_mat'[`i', `col_vr_raw']
                    local dev_raw = max(abs(`vr_i' - 1), abs(1/`vr_i' - 1))
                    if `dev_raw' > `max_vr_raw_dev' {
                        local max_vr_raw = `vr_i'
                        local max_vr_raw_dev = `dev_raw'
                    }
                    if `vr_i' < `vrlo' | `vr_i' > `vrhi' {
                        local cov_vr_raw_i = 1
                        local n_vr_contrasts_raw = `n_vr_contrasts_raw' + 1
                    }
                }

                if !missing(`balance_mat'[`i', `col_ks_raw']) {
                    local ks_i = `balance_mat'[`i', `col_ks_raw']
                    if `ks_i' > `max_ks_raw' local max_ks_raw = `ks_i'
                }

                if `has_adj' {
                    local col_ks_adj = `ncols_raw' + (`cnum' - 1) * 5 + 5
                    if !missing(`balance_mat'[`i', `col_ks_adj']) {
                        local ks_a_i = `balance_mat'[`i', `col_ks_adj']
                        if `ks_a_i' > `max_ks_adj' local max_ks_adj = `ks_a_i'
                    }
                    local col_smd_adj = `ncols_raw' + (`cnum' - 1) * 5 + 3
                    if !missing(`balance_mat'[`i', `col_smd_adj']) {
                        local abs_smd_a = abs(`balance_mat'[`i', `col_smd_adj'])
                        if `abs_smd_a' > `worst_smd_adj_i' local worst_smd_adj_i = `abs_smd_a'
                        if `abs_smd_a' > `max_smd_adj' local max_smd_adj = `abs_smd_a'
                        if `abs_smd_a' > `threshold' local cov_imbalanced = 1
                    }
                    else {
                        local cov_imbalanced = 1
                    }
                    * RB-08: read the ADJUSTED VR contrast (weighted verdict scale).
                    local col_vr_adj = `ncols_raw' + (`cnum' - 1) * 5 + 4
                    if !`_isbin_`i'' & !missing(`balance_mat'[`i', `col_vr_adj']) {
                        local vr_a_i = `balance_mat'[`i', `col_vr_adj']
                        local dev_adj = max(abs(`vr_a_i' - 1), abs(1/`vr_a_i' - 1))
                        if `dev_adj' > `max_vr_adj_dev' {
                            local max_vr_adj = `vr_a_i'
                            local max_vr_adj_dev = `dev_adj'
                        }
                        if `vr_a_i' < `vrlo' | `vr_a_i' > `vrhi' {
                            local cov_vr_adj_i = 1
                            local n_vr_contrasts_adj = `n_vr_contrasts_adj' + 1
                        }
                    }
                }
                else {
                    if !missing(`balance_mat'[`i', `col_smd_raw']) {
                        if abs(`balance_mat'[`i', `col_smd_raw']) > `threshold' {
                            local cov_imbalanced = 1
                        }
                    }
                    else {
                        local cov_imbalanced = 1
                    }
                }
            }

            if `cov_imbalanced' local n_imbalanced = `n_imbalanced' + 1
            if `cov_vr_raw_i' local n_vr_imbalanced_raw = `n_vr_imbalanced_raw' + 1
            if `cov_vr_adj_i' local n_vr_imbalanced_adj = `n_vr_imbalanced_adj' + 1
        }

        * RB-08: verdict-scale VR counts (adjusted when weighted, raw otherwise);
        * n_vr_imbalanced counts covariates, n_vr_contrasts_imbalanced counts the
        * pairwise contrasts underneath them.
        local n_vr_imbalanced = cond(`has_adj', `n_vr_imbalanced_adj', `n_vr_imbalanced_raw')
        local n_vr_contrasts_imbalanced = cond(`has_adj', `n_vr_contrasts_adj', `n_vr_contrasts_raw')

        foreach lev of local levels {
            return scalar n_group_`lev' = `n_group_`lev''
        }
        return scalar n_contrasts = `n_contrasts'
        return scalar ncols_raw = `ncols_raw'
        return scalar ncols = `ncols'
        return scalar max_smd_raw = `max_smd_raw'
        return scalar max_smd_adj = `max_smd_adj'
        return scalar max_vr_raw = `max_vr_raw'
        return scalar max_vr_adj = `max_vr_adj'
        return scalar max_ks_raw = `max_ks_raw'
        return scalar max_ks_adj = `max_ks_adj'
        return scalar n_imbalanced = `n_imbalanced'
        return scalar n_vr_imbalanced = `n_vr_imbalanced'
        return scalar n_vr_imbalanced_raw = `n_vr_imbalanced_raw'
        return scalar n_vr_imbalanced_adj = `n_vr_imbalanced_adj'
        return scalar n_vr_contrasts_imbalanced = `n_vr_contrasts_imbalanced'
        return scalar n_vr_contrasts_raw = `n_vr_contrasts_raw'
        return scalar n_vr_contrasts_adj = `n_vr_contrasts_adj'
        return scalar n_binary_vr = `n_binary_vr'
        return local vr_na_vars = strtrim("`vr_na_vars'")
        return local contrasts "`contrasts'"
        * RB-12: per-covariate completeness of the balance table
        return scalar n_cov_incomplete = `n_cov_incomplete'
        return scalar n_cov_min = `n_cov_min'
        return local cov_miss_vars = strtrim(`"`cov_miss_vars'"')
        return matrix balance = `balance_mat'
    }
    local rc = _rc
    capture restore
    set varabbrev `_vao'
    if `rc' exit `rc'
end
