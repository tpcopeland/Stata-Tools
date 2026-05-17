*! _psdash_ltmle_diagnostics Version 1.0.2  2026/05/18
*! Longitudinal propensity score diagnostics for LTMLE contract state
*! Author: Timothy P Copeland, Karolinska Institutet
*! Program class: rclass

program define _psdash_ltmle_diagnostics, rclass
    version 16.0
    local _vao = c(varabbrev)
    set varabbrev off
    capture noisily {

        syntax , TREATment(varname numeric) PERiod(varname numeric) ///
            PSVAR(string) WVAR(string) SAMPLEvar(varname) ///
            [ID(string) ESTIMand(string) REGime(string) METHOD(string) ///
             CONTRACT(string) TItle(string)]

        local psvar = strtrim("`psvar'")
        local wvar = strtrim("`wvar'")
        local id = strtrim("`id'")

        if "`psvar'" == "" {
            display as error "ltmle contract does not identify a propensity score variable"
            display as error "  psdash combined requires e(ps_var) or _dta[_ltmle_ps_var]"
            exit 198
        }
        if "`wvar'" == "" {
            display as error "ltmle contract does not identify a weight variable"
            display as error "  psdash combined requires e(weight_var) or _dta[_ltmle_weight_var]"
            exit 198
        }

        confirm variable `psvar'
        confirm numeric variable `psvar'
        confirm variable `wvar'
        confirm numeric variable `wvar'
        if "`id'" != "" {
            confirm variable `id'
        }

        markout `samplevar' `treatment' `period' `psvar' `wvar'

        quietly count if `samplevar'
        if r(N) == 0 {
            display as error "no observations in LTMLE diagnostic sample"
            exit 2000
        }
        local N = r(N)

        capture assert inlist(`treatment', 0, 1) if `samplevar'
        if _rc {
            display as error "ltmle treatment variable must be binary (0/1)"
            exit 198
        }

        quietly count if `samplevar' & (`psvar' < 0 | `psvar' > 1)
        if r(N) > 0 {
            display as error "ltmle propensity scores must be in [0,1]"
            exit 198
        }

        quietly levelsof `period' if `samplevar', local(period_values)
        local n_periods : word count `period_values'
        if `n_periods' == 0 {
            display as error "no period values in LTMLE diagnostic sample"
            exit 2000
        }

        tempname overlap wtperiod
        matrix `overlap' = J(`n_periods', 12, .)
        matrix colnames `overlap' = N N_treated N_control mean_treated ///
            mean_control min_treated max_treated min_control max_control ///
            overlap_lower overlap_upper pct_outside

        matrix `wtperiod' = J(`n_periods', 7, .)
        matrix colnames `wtperiod' = N mean sd p95 p99 max ess_pct

        tempvar wt_sq
        quietly gen double `wt_sq' = `wvar'^2 if `samplevar'

        local rownames ""
        local max_pct_outside = 0
        local max_weight_p99 = .
        local i = 0
        foreach p of local period_values {
            local ++i
            local rownames "`rownames' p`i'"

            quietly count if `samplevar' & `period' == `p'
            local p_N = r(N)
            quietly count if `samplevar' & `period' == `p' & `treatment' == 1
            local p_Nt = r(N)
            quietly count if `samplevar' & `period' == `p' & `treatment' == 0
            local p_Nc = r(N)

            local mean_t = .
            local min_t = .
            local max_t = .
            if `p_Nt' > 0 {
                quietly summarize `psvar' ///
                    if `samplevar' & `period' == `p' & `treatment' == 1, meanonly
                local mean_t = r(mean)
                local min_t = r(min)
                local max_t = r(max)
            }

            local mean_c = .
            local min_c = .
            local max_c = .
            if `p_Nc' > 0 {
                quietly summarize `psvar' ///
                    if `samplevar' & `period' == `p' & `treatment' == 0, meanonly
                local mean_c = r(mean)
                local min_c = r(min)
                local max_c = r(max)
            }

            local overlap_lower = .
            local overlap_upper = .
            local pct_outside = .
            if `p_Nt' > 0 & `p_Nc' > 0 {
                local overlap_lower = max(`min_t', `min_c')
                local overlap_upper = min(`max_t', `max_c')
                quietly count if `samplevar' & `period' == `p' ///
                    & (`psvar' < `overlap_lower' | `psvar' > `overlap_upper')
                local n_outside = r(N)
                local pct_outside = 100 * `n_outside' / `p_N'
                if `pct_outside' > `max_pct_outside' {
                    local max_pct_outside = `pct_outside'
                }
            }

            matrix `overlap'[`i', 1] = `p_N'
            matrix `overlap'[`i', 2] = `p_Nt'
            matrix `overlap'[`i', 3] = `p_Nc'
            matrix `overlap'[`i', 4] = `mean_t'
            matrix `overlap'[`i', 5] = `mean_c'
            matrix `overlap'[`i', 6] = `min_t'
            matrix `overlap'[`i', 7] = `max_t'
            matrix `overlap'[`i', 8] = `min_c'
            matrix `overlap'[`i', 9] = `max_c'
            matrix `overlap'[`i', 10] = `overlap_lower'
            matrix `overlap'[`i', 11] = `overlap_upper'
            matrix `overlap'[`i', 12] = `pct_outside'

            quietly summarize `wvar' if `samplevar' & `period' == `p', detail
            local wt_mean = r(mean)
            local wt_sd = r(sd)
            local wt_p95 = r(p95)
            local wt_p99 = r(p99)
            local wt_max = r(max)
            if missing(`max_weight_p99') | `wt_p99' > `max_weight_p99' {
                local max_weight_p99 = `wt_p99'
            }

            quietly summarize `wvar' if `samplevar' & `period' == `p', meanonly
            local sum_wt = r(sum)
            quietly summarize `wt_sq' if `samplevar' & `period' == `p', meanonly
            local sum_wt_sq = r(sum)
            local ess_pct = .
            if `sum_wt_sq' > 0 & `p_N' > 0 {
                local ess = (`sum_wt'^2) / `sum_wt_sq'
                local ess_pct = 100 * `ess' / `p_N'
            }

            matrix `wtperiod'[`i', 1] = `p_N'
            matrix `wtperiod'[`i', 2] = `wt_mean'
            matrix `wtperiod'[`i', 3] = `wt_sd'
            matrix `wtperiod'[`i', 4] = `wt_p95'
            matrix `wtperiod'[`i', 5] = `wt_p99'
            matrix `wtperiod'[`i', 6] = `wt_max'
            matrix `wtperiod'[`i', 7] = `ess_pct'
        }
        matrix rownames `overlap' = `rownames'
        matrix rownames `wtperiod' = `rownames'

        _psdash_weights_stats, wvar(`wvar') treatment(`treatment') ///
            samplevar(`samplevar') n(`N')
        local mean_wt = r(mean_wt)
        local sd_wt = r(sd_wt)
        local min_wt = r(min_wt)
        local max_wt = r(max_wt)
        local cv = r(cv)
        local ess = r(ess)
        local ess_pct = r(ess_pct)
        local p1 = r(p1)
        local p5 = r(p5)
        local p50 = r(p50)
        local p95 = r(p95)
        local p99 = r(p99)
        local n_extreme = r(n_extreme)
        local pct_extreme = r(pct_extreme)

        if "`title'" == "" {
            local title "Longitudinal Propensity Score Diagnostics"
        }

        display as text _n as result `"`title'"'
        display as text "Source:        " as result "ltmle"
        if "`method'" != "" {
            display as text "Method:        " as result "`method'"
        }
        if "`contract'" != "" {
            display as text "Contract:      " as result "`contract'"
        }
        if "`id'" != "" {
            display as text "ID variable:   " as result "`id'"
        }
        display as text "Period:        " as result "`period'"
        display as text "Treatment:     " as result "`treatment'"
        display as text "PS variable:   " as result "`psvar'"
        display as text "Weight var:    " as result "`wvar'"
        if "`estimand'" != "" {
            display as text "Estimand:      " as result strupper("`estimand'")
        }
        if "`regime'" != "" {
            display as text "Regime:        " as result "`regime'"
        }
        display as text "Obs:           " as result %10.0fc `N'
        display as text "Periods:       " as result %10.0fc `n_periods'

        display as text _n "{hline 91}"
        display as text "Per-Period Propensity Score Overlap"
        display as text "{hline 91}"
        display as text %10s "Period" %9s "N" %9s "Treated" %9s "Control" ///
            %11s "Mean T" %11s "Mean C" %11s "Lower" %11s "Upper" %10s "% out"
        display as text "{hline 91}"
        local i = 0
        foreach p of local period_values {
            local ++i
            local p_N = `overlap'[`i', 1]
            local p_Nt = `overlap'[`i', 2]
            local p_Nc = `overlap'[`i', 3]
            local mean_t = `overlap'[`i', 4]
            local mean_c = `overlap'[`i', 5]
            local overlap_lower = `overlap'[`i', 10]
            local overlap_upper = `overlap'[`i', 11]
            local pct_outside = `overlap'[`i', 12]
            display as result %10.0g `p' %9.0fc `p_N' %9.0fc `p_Nt' ///
                %9.0fc `p_Nc' %11.4f `mean_t' %11.4f `mean_c' ///
                %11.4f `overlap_lower' %11.4f `overlap_upper' ///
                %10.2f `pct_outside'
        }
        display as text "{hline 91}"

        display as text _n "{hline 82}"
        display as text "Contract Weight Distribution by Period"
        display as text "{hline 82}"
        display as text %10s "Period" %9s "N" %11s "Mean" %11s "SD" ///
            %11s "P95" %11s "P99" %11s "Max" %9s "ESS%"
        display as text "{hline 82}"
        local i = 0
        foreach p of local period_values {
            local ++i
            local p_N = `wtperiod'[`i', 1]
            local wt_mean = `wtperiod'[`i', 2]
            local wt_sd = `wtperiod'[`i', 3]
            local wt_p95 = `wtperiod'[`i', 4]
            local wt_p99 = `wtperiod'[`i', 5]
            local wt_max = `wtperiod'[`i', 6]
            local ess_pct_p = `wtperiod'[`i', 7]
            display as result %10.0g `p' %9.0fc `p_N' %11.4f `wt_mean' ///
                %11.4f `wt_sd' %11.4f `wt_p95' %11.4f `wt_p99' ///
                %11.4f `wt_max' %9.2f `ess_pct_p'
        }
        display as text "{hline 82}"

        display as text _n "{hline 55}"
        display as text "Overall Contract Weight Summary"
        display as text "{hline 55}"
        display as text "Mean:          " as result %10.4f `mean_wt'
        display as text "SD:            " as result %10.4f `sd_wt'
        display as text "Min/Max:       " as result %10.4f `min_wt' ///
            as text " / " as result %10.4f `max_wt'
        display as text "P1/P5:         " as result %10.4f `p1' ///
            as text " / " as result %10.4f `p5'
        display as text "P50/P95/P99:   " as result %10.4f `p50' ///
            as text " / " as result %10.4f `p95' ///
            as text " / " as result %10.4f `p99'
        display as text "CV:            " as result %10.4f `cv'
        display as text "ESS:           " as result %10.1fc `ess' ///
            as text " (" as result %5.1f `ess_pct' as text "%)"
        display as text "Weights >10:   " as result %10.0fc `n_extreme' ///
            as text " (" as result %5.1f `pct_extreme' as text "%)"
        display as text "{hline 55}"

        if `max_pct_outside' > 10 {
            display as error "Warning: at least one period has >10% outside common support."
        }
        if `ess_pct' < 50 {
            display as error "Warning: overall ESS is below 50% of rows in the diagnostic sample."
        }

        return clear
        return scalar N = `N'
        return scalar N_periods = `n_periods'
        return scalar max_pct_outside = `max_pct_outside'
        return scalar mean_wt = `mean_wt'
        return scalar sd_wt = `sd_wt'
        return scalar min_wt = `min_wt'
        return scalar max_wt = `max_wt'
        return scalar cv = `cv'
        return scalar ess = `ess'
        return scalar ess_pct = `ess_pct'
        return scalar p1 = `p1'
        return scalar p5 = `p5'
        return scalar p50 = `p50'
        return scalar p95 = `p95'
        return scalar p99 = `p99'
        return scalar n_extreme = `n_extreme'
        return scalar pct_extreme = `pct_extreme'
        return scalar longitudinal = 1
        return local periods "`period_values'"
        return local treatment "`treatment'"
        return local psvar "`psvar'"
        return local wvar "`wvar'"
        return local period "`period'"
        return local id "`id'"
        return local estimand "`estimand'"
        return local regime "`regime'"
        return local method "`method'"
        return local contract_version "`contract'"
        return local source "ltmle"
        return matrix weights_by_period = `wtperiod'
        return matrix overlap_by_period = `overlap'
    }
    local rc = _rc
    set varabbrev `_vao'
    if `rc' exit `rc'
end
