*! _psdash_balance_binary Version 1.5.0  2026/07/22
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
            THReshold(real) [Wvar(varname numeric) VRLo(real 0.5) VRHi(real 2) ///
            LABels(string asis)]

        return clear
        local nvars : word count `varlist'
        local has_adj = ("`wvar'" != "")

        * Readable row labels for factor-variable design columns (RB-03). When the
        * caller passes materialized fv tempvars, labels() carries the term names
        * (2.cat, c.x#c.z, ...) so matrix rownames and vr_na_vars stay readable.
        if `"`labels'"' == "" local labels `"`varlist'"'

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
            local rownames `"`rownames' `: word `i' of `labels''"'

            * Flag binary/indicator covariates: VR carries no information beyond
            * the SMD for a two-level covariate, so it is excluded from the VR
            * verdict and footnoted in the caller.
            quietly summarize `var'
            local _vmin = r(min)
            local _vmax = r(max)
            quietly count if `var' != `_vmin' & `var' != `_vmax' & !missing(`var')
            local _isbin_`i' = (r(N) == 0 & `_vmin' != `_vmax')

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

                * Weighted Kolmogorov-Smirnov: sup_x |F1(x) - F0(x)| using the
                * weighted empirical CDF in each group. ksmirnov takes no weights,
                * so the weighted ECDF is built directly.
                local ks_adj = .
                quietly summarize `wvar' if `treatment' == 1 & !missing(`var')
                local _wt_t = r(sum)
                quietly summarize `wvar' if `treatment' == 0 & !missing(`var')
                local _wt_c = r(sum)
                if `_wt_t' > 0 & `_wt_c' > 0 {
                    tempvar _cft _cfc _last _ksd
                    sort `var'
                    quietly gen double `_cft' = ///
                        sum(cond(`treatment' == 1 & !missing(`var'), `wvar', 0)) / `_wt_t'
                    quietly gen double `_cfc' = ///
                        sum(cond(`treatment' == 0 & !missing(`var'), `wvar', 0)) / `_wt_c'
                    quietly by `var': gen byte `_last' = (_n == _N)
                    quietly gen double `_ksd' = ///
                        abs(`_cft' - `_cfc') if `_last' & !missing(`var')
                    quietly summarize `_ksd'
                    if r(N) > 0 local ks_adj = r(max)
                    drop `_cft' `_cfc' `_last' `_ksd'
                }
                matrix `balance_mat'[`i', 10] = `ks_adj'
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
        local n_vr_imbalanced_raw = 0
        local n_vr_imbalanced_adj = 0
        local n_binary_vr = 0
        local vr_na_vars ""

        forvalues i = 1/`nvars' {
            if !missing(`balance_mat'[`i', 3]) {
                local abs_smd_raw = abs(`balance_mat'[`i', 3])
                if `abs_smd_raw' > `max_smd_raw' local max_smd_raw = `abs_smd_raw'
            }

            if `_isbin_`i'' {
                local n_binary_vr = `n_binary_vr' + 1
                local vr_na_vars "`vr_na_vars' `: word `i' of `rownames''"
            }
            else if !missing(`balance_mat'[`i', 4]) {
                local vr_i = `balance_mat'[`i', 4]
                local dev_from_1 = max(abs(`vr_i' - 1), abs(1/`vr_i' - 1))
                if `dev_from_1' > `max_vr_raw_dev' {
                    local max_vr_raw = `vr_i'
                    local max_vr_raw_dev = `dev_from_1'
                }
                if `vr_i' < `vrlo' | `vr_i' > `vrhi' {
                    local n_vr_imbalanced_raw = `n_vr_imbalanced_raw' + 1
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

                if !missing(`balance_mat'[`i', 10]) {
                    local ks_a_i = `balance_mat'[`i', 10]
                    if `ks_a_i' > `max_ks_adj' local max_ks_adj = `ks_a_i'
                }

                if !`_isbin_`i'' & !missing(`balance_mat'[`i', 9]) {
                    local vr_adj_i = `balance_mat'[`i', 9]
                    local dev_adj = max(abs(`vr_adj_i' - 1), abs(1/`vr_adj_i' - 1))
                    if `dev_adj' > `max_vr_adj_dev' {
                        local max_vr_adj = `vr_adj_i'
                        local max_vr_adj_dev = `dev_adj'
                    }
                    * RB-08: count the ADJUSTED VR imbalance separately from raw.
                    * When weights are supplied the verdict must judge the weighted
                    * (adjusted) VR, not the raw VR -- probe B2 has raw VR in bounds
                    * while the adjusted VR is far outside them, and the old code
                    * counted only the raw VR, so the adjusted failure was invisible.
                    if `vr_adj_i' < `vrlo' | `vr_adj_i' > `vrhi' {
                        local n_vr_imbalanced_adj = `n_vr_imbalanced_adj' + 1
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
        return scalar max_ks_adj = `max_ks_adj'
        return scalar n_imbalanced = `n_imbalanced'
        * RB-08: n_vr_imbalanced is the verdict-scale count of imbalanced covariates
        * (adjusted when weights are supplied, raw otherwise). Both raw and adjusted
        * counts are returned so the caller can report each unambiguously.
        local n_vr_imbalanced = cond(`has_adj', `n_vr_imbalanced_adj', `n_vr_imbalanced_raw')
        return scalar n_vr_imbalanced = `n_vr_imbalanced'
        return scalar n_vr_imbalanced_raw = `n_vr_imbalanced_raw'
        return scalar n_vr_imbalanced_adj = `n_vr_imbalanced_adj'
        return scalar n_binary_vr = `n_binary_vr'
        return local vr_na_vars = strtrim("`vr_na_vars'")
        return matrix balance = `balance_mat'
    }
    local rc = _rc
    capture restore
    set varabbrev `_vao'
    if `rc' exit `rc'
end
