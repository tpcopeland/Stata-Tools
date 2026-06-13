*! _msm_coef_pvalue_string Version 1.1.0  2026/06/14
*! P-value display string for MSM coefficient tables
*! Author: Timothy P Copeland

program define _msm_coef_pvalue_string, rclass
    version 16.0
    local _orig_varabbrev = c(varabbrev)
    set varabbrev off

    capture noisily {
        syntax , PVALUE(real)

        local p_str ""
        if `pvalue' < 0.001 {
            local p_str "<0.001"
        }
        else if `pvalue' >= 0.995 {
            local p_str "0.99"
        }
        else if `pvalue' < 0.05 {
            local p_str = strtrim(string(`pvalue', "%5.3f"))
        }
        else {
            local p_str = strtrim(string(`pvalue', "%4.2f"))
        }
        if substr("`p_str'", 1, 1) == "." {
            local p_str "0`p_str'"
        }

        return local pvalue `"`p_str'"'
    }
    local _rc = _rc
    set varabbrev `_orig_varabbrev'
    if `_rc' exit `_rc'
end
