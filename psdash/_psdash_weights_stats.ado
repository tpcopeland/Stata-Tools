*! _psdash_weights_stats Version 1.1.0  2026/05/29
*! IPTW weight summary and ESS statistics
*! Author: Timothy P Copeland, Karolinska Institutet
*! Internal helper

program define _psdash_weights_stats, rclass
    version 16.0
    local _vao = c(varabbrev)
    set varabbrev off
    capture noisily {
        syntax , WVar(varname numeric) TREATment(varname numeric) ///
            SAMPLEvar(varname) N(real) [LEVELS(string asis) MULTIgroup(string)]

        return clear

        quietly {
            summarize `wvar' if `samplevar', detail
            local mean_wt = r(mean)
            local sd_wt = r(sd)
            local min_wt = r(min)
            local max_wt = r(max)
            local p1 = r(p1)
            local p5 = r(p5)
            local p10 = r(p10)
            local p25 = r(p25)
            local p50 = r(p50)
            local p75 = r(p75)
            local p90 = r(p90)
            local p95 = r(p95)
            local p99 = r(p99)
            local cv = `sd_wt' / `mean_wt'

            tempvar wt_sq
            gen double `wt_sq' = `wvar'^2 if `samplevar'

            summarize `wvar' if `samplevar'
            local sum_wt = r(sum)
            summarize `wt_sq' if `samplevar'
            local sum_wt_sq = r(sum)
            local ess = (`sum_wt'^2) / `sum_wt_sq'
            local ess_pct = 100 * `ess' / `n'

            if "`multigroup'" == "" | "`multigroup'" == "0" {
                summarize `wvar' if `samplevar' & `treatment' == 1, detail
                local mean_wt_t = r(mean)
                local sd_wt_t = r(sd)
                local min_wt_t = r(min)
                local max_wt_t = r(max)
                local n_treated = r(N)

                summarize `wvar' if `samplevar' & `treatment' == 0, detail
                local mean_wt_c = r(mean)
                local sd_wt_c = r(sd)
                local min_wt_c = r(min)
                local max_wt_c = r(max)
                local n_control = r(N)

                summarize `wvar' if `samplevar' & `treatment' == 1
                local sum_wt_t = r(sum)
                summarize `wt_sq' if `samplevar' & `treatment' == 1
                local sum_wt_sq_t = r(sum)
                local ess_t = (`sum_wt_t'^2) / `sum_wt_sq_t'
                local ess_pct_t = 100 * `ess_t' / `n_treated'

                summarize `wvar' if `samplevar' & `treatment' == 0
                local sum_wt_c = r(sum)
                summarize `wt_sq' if `samplevar' & `treatment' == 0
                local sum_wt_sq_c = r(sum)
                local ess_c = (`sum_wt_c'^2) / `sum_wt_sq_c'
                local ess_pct_c = 100 * `ess_c' / `n_control'
            }
            else {
                foreach lev of local levels {
                    summarize `wvar' if `samplevar' & `treatment' == `lev', detail
                    local mean_wt_`lev' = r(mean)
                    local sd_wt_`lev' = r(sd)
                    local min_wt_`lev' = r(min)
                    local max_wt_`lev' = r(max)
                    local n_group_`lev' = r(N)

                    summarize `wvar' if `samplevar' & `treatment' == `lev'
                    local sum_wt_`lev' = r(sum)
                    summarize `wt_sq' if `samplevar' & `treatment' == `lev'
                    local sum_wtsq_`lev' = r(sum)
                    local ess_`lev' = (`sum_wt_`lev''^2) / `sum_wtsq_`lev''
                    local ess_pct_`lev' = 100 * `ess_`lev'' / `n_group_`lev''
                }
            }

            drop `wt_sq'

            count if `wvar' > 10 & `samplevar'
            local n_extreme = r(N)
            local pct_extreme = 100 * `n_extreme' / `n'

            count if `wvar' > 20 & `samplevar'
            local n_very_extreme = r(N)
        }

        return scalar mean_wt = `mean_wt'
        return scalar sd_wt = `sd_wt'
        return scalar min_wt = `min_wt'
        return scalar max_wt = `max_wt'
        return scalar p1 = `p1'
        return scalar p5 = `p5'
        return scalar p10 = `p10'
        return scalar p25 = `p25'
        return scalar p50 = `p50'
        return scalar p75 = `p75'
        return scalar p90 = `p90'
        return scalar p95 = `p95'
        return scalar p99 = `p99'
        return scalar cv = `cv'
        return scalar ess = `ess'
        return scalar ess_pct = `ess_pct'
        return scalar n_extreme = `n_extreme'
        return scalar pct_extreme = `pct_extreme'
        return scalar n_very_extreme = `n_very_extreme'

        if "`multigroup'" == "" | "`multigroup'" == "0" {
            return scalar n_treated = `n_treated'
            return scalar n_control = `n_control'
            return scalar mean_wt_t = `mean_wt_t'
            return scalar sd_wt_t = `sd_wt_t'
            return scalar min_wt_t = `min_wt_t'
            return scalar max_wt_t = `max_wt_t'
            return scalar mean_wt_c = `mean_wt_c'
            return scalar sd_wt_c = `sd_wt_c'
            return scalar min_wt_c = `min_wt_c'
            return scalar max_wt_c = `max_wt_c'
            return scalar ess_t = `ess_t'
            return scalar ess_pct_t = `ess_pct_t'
            return scalar ess_c = `ess_c'
            return scalar ess_pct_c = `ess_pct_c'
        }
        else {
            foreach lev of local levels {
                return scalar n_group_`lev' = `n_group_`lev''
                return scalar mean_wt_`lev' = `mean_wt_`lev''
                return scalar sd_wt_`lev' = `sd_wt_`lev''
                return scalar min_wt_`lev' = `min_wt_`lev''
                return scalar max_wt_`lev' = `max_wt_`lev''
                return scalar ess_`lev' = `ess_`lev''
                return scalar ess_pct_`lev' = `ess_pct_`lev''
            }
        }
    }
    local rc = _rc
    set varabbrev `_vao'
    if `rc' exit `rc'
end
