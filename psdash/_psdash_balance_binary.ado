*! _psdash_balance_binary Version 1.2.1  2026/06/14
*! Binary covariate balance statistics
*! Author: Timothy P Copeland, Karolinska Institutet
*! Program class: rclass
*! Internal helper

program define _psdash_balance_binary, rclass
    version 16.0
    local _vao = c(varabbrev)
    set varabbrev off

    capture noisily {
        syntax varlist(numeric), TREATment(varname numeric) SAMPLEvar(varname) ///
            THReshold(real) [Wvar(varname numeric)]

        return clear
        local nvars : word count `varlist'
        local has_adj = ("`wvar'" != "")

        preserve
        quietly keep if `samplevar'

        quietly count if `treatment' == 1
        local n_treated = r(N)
        quietly count if `treatment' == 0
        local n_control = r(N)

        if `n_treated' < 2 | `n_control' < 2 {
            display as error "each treatment group must have at least 2 observations"
            exit 2001
        }

        tempname balance_mat
        matrix `balance_mat' = J(`nvars', 10, .)
        matrix colnames `balance_mat' = "Mean_T" "Mean_C" "SMD_Raw" "VR_Raw" "KS_Raw" "Mean_T_Adj" "Mean_C_Adj" "SMD_Adj" "VR_Adj" "KS_Adj"
        local rownames ""

        local i = 1
        foreach var of local varlist {
            local rownames "`rownames' `var'"

            quietly summarize `var' if `treatment' == 1
            local mean_t = r(mean)
            local var_t = r(Var)

            quietly summarize `var' if `treatment' == 0
            local mean_c = r(mean)
            local var_c = r(Var)

            local sd_pooled = sqrt((`var_t' + `var_c') / 2)
            if `sd_pooled' > 0 {
                local smd_raw = (`mean_t' - `mean_c') / `sd_pooled'
            }
            else if `mean_t' != `mean_c' {
                local smd_raw = .
            }
            else {
                local smd_raw = 0
            }

            if `var_t' > 0 & `var_c' > 0 {
                local vr_raw = `var_t' / `var_c'
            }
            else {
                local vr_raw = .
            }

            matrix `balance_mat'[`i', 1] = `mean_t'
            matrix `balance_mat'[`i', 2] = `mean_c'
            matrix `balance_mat'[`i', 3] = `smd_raw'
            matrix `balance_mat'[`i', 4] = `vr_raw'

            capture quietly ksmirnov `var', by(`treatment')
            if _rc == 0 {
                local ks_raw = r(D)
            }
            else {
                local ks_raw = .
            }
            matrix `balance_mat'[`i', 5] = `ks_raw'

            if `has_adj' {
                quietly summarize `var' [aw=`wvar'] if `treatment' == 1
                local mean_t_adj = r(mean)
                local var_t_adj = r(Var)

                quietly summarize `var' [aw=`wvar'] if `treatment' == 0
                local mean_c_adj = r(mean)
                local var_c_adj = r(Var)

                if `sd_pooled' > 0 {
                    local smd_adj = (`mean_t_adj' - `mean_c_adj') / `sd_pooled'
                }
                else if `mean_t_adj' != `mean_c_adj' {
                    local smd_adj = .
                }
                else {
                    local smd_adj = 0
                }

                if `var_t_adj' > 0 & `var_c_adj' > 0 {
                    local vr_adj = `var_t_adj' / `var_c_adj'
                }
                else {
                    local vr_adj = .
                }

                matrix `balance_mat'[`i', 6] = `mean_t_adj'
                matrix `balance_mat'[`i', 7] = `mean_c_adj'
                matrix `balance_mat'[`i', 8] = `smd_adj'
                matrix `balance_mat'[`i', 9] = `vr_adj'
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
        local n_imbalanced = 0
        local n_vr_imbalanced = 0

        forvalues i = 1/`nvars' {
            if !missing(`balance_mat'[`i', 3]) {
                local abs_smd_raw = abs(`balance_mat'[`i', 3])
                if `abs_smd_raw' > `max_smd_raw' local max_smd_raw = `abs_smd_raw'
            }

            if !missing(`balance_mat'[`i', 4]) {
                local vr_i = `balance_mat'[`i', 4]
                local dev_from_1 = max(abs(`vr_i' - 1), abs(1/`vr_i' - 1))
                if `dev_from_1' > `max_vr_raw_dev' {
                    local max_vr_raw = `vr_i'
                    local max_vr_raw_dev = `dev_from_1'
                }
                if `vr_i' < 0.5 | `vr_i' > 2 {
                    local n_vr_imbalanced = `n_vr_imbalanced' + 1
                }
            }

            if !missing(`balance_mat'[`i', 5]) {
                local ks_i = `balance_mat'[`i', 5]
                if `ks_i' > `max_ks_raw' local max_ks_raw = `ks_i'
            }

            if `has_adj' {
                if !missing(`balance_mat'[`i', 8]) {
                    local abs_smd_adj = abs(`balance_mat'[`i', 8])
                    if `abs_smd_adj' > `max_smd_adj' local max_smd_adj = `abs_smd_adj'
                    if `abs_smd_adj' > `threshold' local n_imbalanced = `n_imbalanced' + 1
                }
                else {
                    local n_imbalanced = `n_imbalanced' + 1
                }

                if !missing(`balance_mat'[`i', 9]) {
                    local vr_adj_i = `balance_mat'[`i', 9]
                    local dev_adj = max(abs(`vr_adj_i' - 1), abs(1/`vr_adj_i' - 1))
                    if `dev_adj' > `max_vr_adj_dev' {
                        local max_vr_adj = `vr_adj_i'
                        local max_vr_adj_dev = `dev_adj'
                    }
                }
            }
            else {
                if !missing(`balance_mat'[`i', 3]) {
                    if abs(`balance_mat'[`i', 3]) > `threshold' {
                        local n_imbalanced = `n_imbalanced' + 1
                    }
                }
                else {
                    local n_imbalanced = `n_imbalanced' + 1
                }
            }
        }

        return scalar n_treated = `n_treated'
        return scalar n_control = `n_control'
        return scalar max_smd_raw = `max_smd_raw'
        return scalar max_smd_adj = `max_smd_adj'
        return scalar max_vr_raw = `max_vr_raw'
        return scalar max_vr_adj = `max_vr_adj'
        return scalar max_ks_raw = `max_ks_raw'
        return scalar n_imbalanced = `n_imbalanced'
        return scalar n_vr_imbalanced = `n_vr_imbalanced'
        return matrix balance = `balance_mat'
    }
    local rc = _rc
    capture restore
    set varabbrev `_vao'
    if `rc' exit `rc'
end
