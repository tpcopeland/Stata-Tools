*! _msm_diag_frame_check Version 1.4.8  2026/08/30
*! Validate the fixed frame schema used by msm_diagnose, accumulate()
*! Author: Timothy P Copeland, Karolinska Institutet

program define _msm_diag_frame_check, nclass
    version 16.0
    local _orig_varabbrev = c(varabbrev)
    set varabbrev off
    capture noisily {
        local _expected "contrast outcome n_obs ess ess_pct max_weight"
        local _expected "`_expected' p99_weight n_extreme n_imbalanced max_abs_smd"
        local _types "str80 str40 double double double double double double double double"

        capture unab _actual : _all
        if _rc {
            display as error "accumulation frame has an incompatible variable schema"
            exit 459
        }
        if "`_actual'" != "`_expected'" {
            display as error "accumulation frame has an incompatible variable schema"
            exit 459
        }

        local _index = 0
        foreach _var of local _expected {
            local ++_index
            local _wanted : word `_index' of `_types'
            local _actual_type : type `_var'
            if "`_actual_type'" != "`_wanted'" {
                display as error ///
                    "accumulation frame variable `_var' must have type `_wanted'"
                exit 459
            }
        }
    }
    local _rc = _rc
    set varabbrev `_orig_varabbrev'
    if `_rc' exit `_rc'
end
