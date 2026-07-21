*! _msm_coef_display_name Version 1.2.3  2026/07/02
*! Display label for MSM coefficient names
*! Author: Timothy P Copeland, Karolinska Institutet

program define _msm_coef_display_name, rclass
    version 16.0
    local _orig_varabbrev = c(varabbrev)
    set varabbrev off

    capture noisily {
        syntax , NAME(string)

        local display_name `"`name'"'
        if `"`name'"' == "_cons" local display_name "Constant"
        else if `"`name'"' == "_msm_period_sq" local display_name "Period^2"
        else if `"`name'"' == "period" local display_name "Period"
        else if `"`name'"' == "treatment" local display_name "Treatment"
        else {
            capture confirm variable `name'
            if !_rc {
                local vlabel : variable label `name'
                if `"`vlabel'"' != "" local display_name `"`vlabel'"'
            }
        }

        return local display_name `"`display_name'"'
    }
    local _rc = _rc
    set varabbrev `_orig_varabbrev'
    if `_rc' exit `_rc'
end
