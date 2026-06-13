*! _psdash_balance_multigroup Version 1.2.0  2026/06/14
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
            [Wvar(varname numeric)]

        return clear
        local nvars : word count `varlist'
        local has_adj = ("`wvar'" != "")

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
            local rownames "`rownames' `var'"

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

                    local ks_adj = .

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
        local max_ks_raw = 0
        local n_imbalanced = 0
        local n_vr_imbalanced = 0

        forvalues i = 1/`nvars' {
            local worst_smd_raw_i = 0
            local worst_smd_adj_i = 0
            local cov_imbalanced = 0

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

                if !missing(`balance_mat'[`i', `col_vr_raw']) {
                    local vr_i = `balance_mat'[`i', `col_vr_raw']
                    if `vr_i' < 0.5 | `vr_i' > 2 {
                        local n_vr_imbalanced = `n_vr_imbalanced' + 1
                    }
                }

                if !missing(`balance_mat'[`i', `col_ks_raw']) {
                    local ks_i = `balance_mat'[`i', `col_ks_raw']
                    if `ks_i' > `max_ks_raw' local max_ks_raw = `ks_i'
                }

                if `has_adj' {
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
        }

        foreach lev of local levels {
            return scalar n_group_`lev' = `n_group_`lev''
        }
        return scalar n_contrasts = `n_contrasts'
        return scalar ncols_raw = `ncols_raw'
        return scalar ncols = `ncols'
        return scalar max_smd_raw = `max_smd_raw'
        return scalar max_smd_adj = `max_smd_adj'
        return scalar max_ks_raw = `max_ks_raw'
        return scalar n_imbalanced = `n_imbalanced'
        return scalar n_vr_imbalanced = `n_vr_imbalanced'
        return local contrasts "`contrasts'"
        return matrix balance = `balance_mat'
    }
    local rc = _rc
    capture restore
    set varabbrev `_vao'
    if `rc' exit `rc'
end
