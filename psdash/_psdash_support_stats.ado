*! _psdash_support_stats Version 1.0.2  2026/05/17
*! Common support bounds and outside-count statistics
*! Author: Timothy P Copeland, Karolinska Institutet
*! Internal helper

program define _psdash_support_stats, rclass
    version 16.0
    local _vao = c(varabbrev)
    set varabbrev off
    capture noisily {
        syntax , TREATment(varname numeric) SAMPLEvar(varname) N(real) ///
            [PSVar(varname numeric) OBSps(varname numeric) ///
             LEVELS(string asis) GROUPPSVars(varlist numeric) ///
             MULTIgroup(string)]

        return clear

        if "`multigroup'" == "" | "`multigroup'" == "0" {
            quietly {
                summarize `psvar' if `treatment' == 1 & `samplevar'
                local n_treated = r(N)
                local mean_ps_t = r(mean)
                local min_ps_t = r(min)
                local max_ps_t = r(max)
                local sd_ps_t = r(sd)

                summarize `psvar' if `treatment' == 0 & `samplevar'
                local n_control = r(N)
                local mean_ps_c = r(mean)
                local min_ps_c = r(min)
                local max_ps_c = r(max)
                local sd_ps_c = r(sd)

                local lower_bound = max(`min_ps_t', `min_ps_c')
                local upper_bound = min(`max_ps_t', `max_ps_c')

                count if (`psvar' < `lower_bound' | `psvar' > `upper_bound') & `samplevar'
                local n_outside = r(N)
                local pct_outside = 100 * `n_outside' / `n'

                count if (`psvar' < `lower_bound' | `psvar' > `upper_bound') ///
                    & `treatment' == 1 & `samplevar'
                local n_outside_t = r(N)

                count if (`psvar' < `lower_bound' | `psvar' > `upper_bound') ///
                    & `treatment' == 0 & `samplevar'
                local n_outside_c = r(N)
            }

            return scalar n_treated = `n_treated'
            return scalar n_control = `n_control'
            return scalar mean_ps_t = `mean_ps_t'
            return scalar min_ps_t = `min_ps_t'
            return scalar max_ps_t = `max_ps_t'
            return scalar sd_ps_t = `sd_ps_t'
            return scalar mean_ps_c = `mean_ps_c'
            return scalar min_ps_c = `min_ps_c'
            return scalar max_ps_c = `max_ps_c'
            return scalar sd_ps_c = `sd_ps_c'
            return scalar lower_bound = `lower_bound'
            return scalar upper_bound = `upper_bound'
            return scalar overlap_lower = `lower_bound'
            return scalar overlap_upper = `upper_bound'
            return scalar n_outside = `n_outside'
            return scalar pct_outside = `pct_outside'
            return scalar n_outside_t = `n_outside_t'
            return scalar n_outside_c = `n_outside_c'
        }
        else {
            local n_levels : word count `levels'
            local n_group_ps : word count `grouppsvars'
            if `n_group_ps' != `n_levels' {
                display as error "internal error: multigroup propensity score mapping incomplete"
                exit 498
            }
            if "`obsps'" == "" {
                display as error "internal error: observed-treatment propensity score required"
                exit 498
            }

            quietly {
                local idx = 1
                foreach lev of local levels {
                    local lev_ps : word `idx' of `grouppsvars'
                    summarize `lev_ps' if `treatment' == `lev' & `samplevar'
                    local n_group_`lev' = r(N)
                    local mean_ps_`lev' = r(mean)
                    local min_ps_`lev' = r(min)
                    local max_ps_`lev' = r(max)
                    local sd_ps_`lev' = r(sd)
                    local idx = `idx' + 1
                }

                local lower_bound = 0
                local upper_bound = 1
                foreach lev of local levels {
                    if `min_ps_`lev'' > `lower_bound' local lower_bound = `min_ps_`lev''
                    if `max_ps_`lev'' < `upper_bound' local upper_bound = `max_ps_`lev''
                }

                count if (`obsps' < `lower_bound' | `obsps' > `upper_bound') & `samplevar'
                local n_outside = r(N)
                local pct_outside = 100 * `n_outside' / `n'

                foreach lev of local levels {
                    count if (`obsps' < `lower_bound' | `obsps' > `upper_bound') ///
                        & `treatment' == `lev' & `samplevar'
                    local n_outside_`lev' = r(N)
                }
            }

            foreach lev of local levels {
                return scalar n_group_`lev' = `n_group_`lev''
                return scalar mean_ps_`lev' = `mean_ps_`lev''
                return scalar min_ps_`lev' = `min_ps_`lev''
                return scalar max_ps_`lev' = `max_ps_`lev''
                return scalar sd_ps_`lev' = `sd_ps_`lev''
                return scalar n_outside_`lev' = `n_outside_`lev''
            }
            return scalar lower_bound = `lower_bound'
            return scalar upper_bound = `upper_bound'
            return scalar overlap_lower = `lower_bound'
            return scalar overlap_upper = `upper_bound'
            return scalar n_outside = `n_outside'
            return scalar pct_outside = `pct_outside'
        }
    }
    local rc = _rc
    set varabbrev `_vao'
    if `rc' exit `rc'
end
