*! _qba_detect_contract Version 1.0.0  2026/06/02
*! Internal helper: detect active estimator contracts consumable by qba
*! Author: Timothy P Copeland, Karolinska Institutet
*! Program class: rclass

capture program drop _qba_detect_contract
local _drop_rc = _rc
program define _qba_detect_contract, rclass
    version 16.0
    local _saved_varabbrev = c(varabbrev)
    set varabbrev off
    capture noisily {

        local has_contract = 0
        local estimate .
        local se .
        local ci_lo .
        local ci_hi .
        local source ""
        local cmd ""
        local measure ""
        local outcome ""
        local treatment ""
        local estimand ""

        local cmd "`e(cmd)'"
        local cmd_l = lower("`cmd'")

        if inlist("`cmd_l'", "tmle", "ltmle") {
            capture local estimate = e(tau)
            if _rc == 0 & !missing(`estimate') {
                local has_contract = 1
                local source "`cmd_l'"
                local measure "coefficient"

                capture local se = e(se)
                if _rc local se .
                capture local ci_lo = e(ci_lo)
                if _rc local ci_lo .
                capture local ci_hi = e(ci_hi)
                if _rc local ci_hi .

                local outcome "`e(outcome)'"
                local treatment "`e(treatment)'"
                local estimand "`e(estimand)'"

                foreach _name in measure effect_measure qba_measure {
                    local _candidate "`e(`_name')'"
                    local _candidate = upper(strtrim(`"`_candidate'"'))
                    if inlist("`_candidate'", "OR", "ODDS RATIO", "ODDS_RATIO") {
                        local measure "OR"
                    }
                    else if inlist("`_candidate'", "RR", "RISK RATIO", ///
                        "RISK_RATIO", "RELATIVE RISK", "RELATIVE_RISK") {
                        local measure "RR"
                    }
                }
            }
        }

        return scalar has_contract = `has_contract'
        return scalar estimate = `estimate'
        return scalar se = `se'
        return scalar ci_lo = `ci_lo'
        return scalar ci_hi = `ci_hi'
        return local source "`source'"
        return local cmd "`cmd'"
        return local measure "`measure'"
        return local outcome "`outcome'"
        return local treatment "`treatment'"
        return local estimand "`estimand'"

    }
    local rc = _rc
    set varabbrev `_saved_varabbrev'
    if `rc' exit `rc'
end
