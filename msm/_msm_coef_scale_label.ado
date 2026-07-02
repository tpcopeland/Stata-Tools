*! _msm_coef_scale_label Version 1.2.2  2026/07/02
*! Scale label for MSM coefficient tables
*! Author: Timothy P Copeland

program define _msm_coef_scale_label, rclass
    version 16.0
    local _orig_varabbrev = c(varabbrev)
    set varabbrev off

    capture noisily {
        syntax , MODEL(string) [EFORM REPORT]

        if "`eform'" == "" {
            local label "Coef."
        }
        else if "`model'" == "logistic" {
            local label "OR"
        }
        else if "`model'" == "cox" {
            local label "HR"
        }
        else if "`report'" != "" {
            local label "OR"
        }
        else {
            local label "exp(b)"
        }

        return local label "`label'"
    }
    local _rc = _rc
    set varabbrev `_orig_varabbrev'
    if `_rc' exit `_rc'
end
