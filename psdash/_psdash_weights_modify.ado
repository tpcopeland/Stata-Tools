*! _psdash_weights_modify Version 1.0.1  2026/05/17
*! Create trimmed, truncated, or stabilized weights
*! Author: Timothy P Copeland
*! Internal helper

program define _psdash_weights_modify, rclass
    version 16.0
    local _vao = c(varabbrev)
    set varabbrev off
    capture noisily {
        syntax , WVar(varname numeric) TREATment(varname numeric) ///
            SAMPLEvar(varname) N(real) GENerate(name) WVARLabel(string asis) ///
            [TRIM(real 0) TRUNCate(real 0) STABilize replace ///
             LEVELS(string asis) MULTIgroup(string)]

        return clear

        quietly {
            if "`replace'" != "" {
                capture drop `generate'
            }

            if `trim' != 0 {
                _pctile `wvar' if `samplevar', p(`trim')
                local trim_val = r(r1)
                gen double `generate' = min(`wvar', `trim_val') if `samplevar'
                label variable `generate' `"`wvarlabel' trimmed at p`trim'"'
                local action "Trimmed at p`trim' (cutoff: `=string(`trim_val', "%6.3f")')"
            }
            else if `truncate' != 0 {
                gen double `generate' = min(`wvar', `truncate') if `samplevar'
                label variable `generate' `"`wvarlabel' truncated at `truncate'"'
                local action "Truncated at `truncate'"
            }
            else if "`stabilize'" != "" {
                if "`multigroup'" == "" | "`multigroup'" == "0" {
                    summarize `treatment' if `samplevar'
                    local p_treat = r(mean)
                    gen double `generate' = cond(`treatment' == 1, ///
                        `p_treat' * `wvar', (1 - `p_treat') * `wvar') if `samplevar'
                    label variable `generate' `"`wvarlabel' stabilized"'
                    local action "Stabilized (P(T=1) = `=string(`p_treat', "%6.3f")')"
                }
                else {
                    gen double `generate' = . if `samplevar'
                    foreach lev of local levels {
                        count if `treatment' == `lev' & `samplevar'
                        local p_`lev' = r(N) / `n'
                        replace `generate' = `p_`lev'' * `wvar' ///
                            if `treatment' == `lev' & `samplevar'
                    }
                    label variable `generate' `"`wvarlabel' stabilized"'

                    local action "Stabilized ("
                    local first = 1
                    foreach lev of local levels {
                        if `first' {
                            local action "`action'P(A=`lev') = `=string(`p_`lev'', "%6.3f")'"
                            local first = 0
                        }
                        else {
                            local action "`action', P(A=`lev') = `=string(`p_`lev'', "%6.3f")'"
                        }
                    }
                    local action "`action')"
                }
            }

            summarize `generate' if `samplevar', detail
            local new_mean = r(mean)
            local new_sd = r(sd)
            local new_min = r(min)
            local new_max = r(max)
            local new_cv = `new_sd' / `new_mean'

            tempvar new_wt_sq
            gen double `new_wt_sq' = `generate'^2 if `samplevar'
            summarize `generate' if `samplevar'
            local new_sum_wt = r(sum)
            summarize `new_wt_sq' if `samplevar'
            local new_sum_wt_sq = r(sum)
            local new_ess = (`new_sum_wt'^2) / `new_sum_wt_sq'
            local new_ess_pct = 100 * `new_ess' / `n'
            drop `new_wt_sq'
        }

        return scalar new_mean = `new_mean'
        return scalar new_sd = `new_sd'
        return scalar new_min = `new_min'
        return scalar new_max = `new_max'
        return scalar new_cv = `new_cv'
        return scalar new_ess = `new_ess'
        return scalar new_ess_pct = `new_ess_pct'
        return local action "`action'"
    }
    local rc = _rc
    set varabbrev `_vao'
    if `rc' exit `rc'
end
