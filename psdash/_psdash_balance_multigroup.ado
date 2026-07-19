*! _psdash_balance_multigroup Version 1.4.0  2026/07/01
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

        local i = 1
        foreach var of local varlist {
            local rownames `"`rownames' `: word `i' of `labels''"'

            * Flag binary/indicator covariates (VR uninformative; see binary helper)
            quietly summarize `var'
            local _vmin = r(min)
            local _vmax = r(max)
            quietly count if `var' != `_vmin' & `var' != `_vmax' & !missing(`var')
            local _isbin_`i' = (r(N) == 0 & `_vmin' != `_vmax')

            quietly summarize `var' if `treatment' == `reference'
            local mean_ref = r(mean)
            local var_ref = r(Var)

            local cnum = 0
            foreach clev of local contrasts {
                local cnum = `cnum' + 1
                local col_base = (`cnum' - 1) * 5

                quietly summarize `var' if `treatment' == `clev'
                local mean_a = r(mean)
                local var_a = r(Var)

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

                capture quietly ksmirnov `var' if `treatment' == `clev' | `treatment' == `reference', by(`treatment')
                if _rc == 0 {
                    local ks_raw = r(D)
                }
                else {
                    local ks_raw = .
                }

                matrix `balance_mat'[`i', `col_base' + 1] = `mean_a'
                matrix `balance_mat'[`i', `col_base' + 2] = `mean_ref'
                matrix `balance_mat'[`i', `col_base' + 3] = `smd_raw'
                matrix `balance_mat'[`i', `col_base' + 4] = `vr_raw'
                matrix `balance_mat'[`i', `col_base' + 5] = `ks_raw'

                if `has_adj' {
                    local adj_base = `ncols_raw' + (`cnum' - 1) * 5

                    quietly summarize `var' [aw=`wvar'] if `treatment' == `clev'
                    local mean_a_adj = r(mean)

                    quietly summarize `var' [aw=`wvar'] if `treatment' == `reference'
                    local mean_ref_adj = r(mean)

                    if `sd_pooled' > 0 {
                        local smd_adj = (`mean_a_adj' - `mean_ref_adj') / `sd_pooled'
                    }
                    else if `mean_a_adj' != `mean_ref_adj' {
                        local smd_adj = .
                    }
                    else {
                        local smd_adj = 0
                    }

                    quietly summarize `var' [aw=`wvar'] if `treatment' == `clev'
                    local var_a_adj = r(Var)
                    quietly summarize `var' [aw=`wvar'] if `treatment' == `reference'
                    local var_ref_adj = r(Var)

                    if `var_a_adj' > 0 & `var_ref_adj' > 0 {
                        local vr_adj = `var_a_adj' / `var_ref_adj'
                    }
                    else {
                        local vr_adj = .
                    }

                    * Weighted Kolmogorov-Smirnov (contrast group vs reference)
                    local ks_adj = .
                    quietly summarize `wvar' if `treatment' == `clev' & !missing(`var')
                    local _wt_a = r(sum)
                    quietly summarize `wvar' if `treatment' == `reference' & !missing(`var')
                    local _wt_r = r(sum)
                    if `_wt_a' > 0 & `_wt_r' > 0 {
                        tempvar _cfa _cfr _last _ksd
                        sort `var'
                        quietly gen double `_cfa' = ///
                            sum(cond(`treatment' == `clev' & !missing(`var'), `wvar', 0)) / `_wt_a'
                        quietly gen double `_cfr' = ///
                            sum(cond(`treatment' == `reference' & !missing(`var'), `wvar', 0)) / `_wt_r'
                        quietly by `var': gen byte `_last' = (_n == _N)
                        quietly gen double `_ksd' = ///
                            abs(`_cfa' - `_cfr') if `_last' & !missing(`var')
                        quietly summarize `_ksd'
                        if r(N) > 0 local ks_adj = r(max)
                        drop `_cfa' `_cfr' `_last' `_ksd'
                    }

                    matrix `balance_mat'[`i', `adj_base' + 1] = `mean_a_adj'
                    matrix `balance_mat'[`i', `adj_base' + 2] = `mean_ref_adj'
                    matrix `balance_mat'[`i', `adj_base' + 3] = `smd_adj'
                    matrix `balance_mat'[`i', `adj_base' + 4] = `vr_adj'
                    matrix `balance_mat'[`i', `adj_base' + 5] = `ks_adj'
                }
            }

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
        return matrix balance = `balance_mat'
    }
    local rc = _rc
    capture restore
    set varabbrev `_vao'
    if `rc' exit `rc'
end
