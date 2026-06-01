*! _qba_flag_misclass_pair Version 1.0.0  2026/06/02
*! Internal helper: flag nonidentifiable Se/Sp draw pairs
*! Author: Timothy P Copeland, Karolinska Institutet
*! Program class: rclass

capture program drop _qba_flag_misclass_pair
local _drop_rc = _rc
program define _qba_flag_misclass_pair, rclass
    version 16.0
    local _saved_varabbrev = c(varabbrev)
    set varabbrev off
    capture noisily {

        syntax , SE(varname numeric) SP(varname numeric) INVALID(name)

        capture confirm variable `invalid'
        if _rc {
            quietly gen byte `invalid' = 0
        }
        quietly replace `invalid' = 1 if `se' + `sp' <= 1

        quietly count if `invalid' == 1
        return scalar n_invalid = r(N)

    }
    local rc = _rc
    set varabbrev `_saved_varabbrev'
    if `rc' exit `rc'
end
