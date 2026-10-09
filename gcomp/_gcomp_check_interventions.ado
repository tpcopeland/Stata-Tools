*! _gcomp_check_interventions Version 2.0.3  2026/10/09
*! Stage an intervention arm without changing the working analytic data
*! Author: Timothy P Copeland, Karolinska Institutet
*! Program class: nclass

capture program drop _gcomp_check_interventions
program define _gcomp_check_interventions
    version 16.0
    tempname caller_r stage
    _return hold `caller_r'
    local original_varabbrev = c(varabbrev)
    local original_frame "`c(frame)'"
    local original_rng `"`c(rngstate)'"'
    local stage_created = 0
    set varabbrev off
    capture noisily {
        syntax, CATEGORICAL(varlist numeric) RULES(string) CONTEXT(string)
        local index = 0
        foreach variable of local categorical {
            local ++index
            quietly levelsof `variable', local(levels`index') hexadecimal
        }
        frame copy `original_frame' `stage'
        local stage_created = 1
        frame change `stage'
        tokenize `"`macval(rules)'"', parse("\")
        while `"`macval(1)'"' != "" {
            if `"`macval(1)'"' != "\" {
                _gcomp_apply_rule, rule(`"`macval(1)'"') context(`"`context'"')
            }
            mac shift
        }
        local index = 0
        foreach variable of local categorical {
            local ++index
            _gcomp_check_categorical `variable', levels(`"`levels`index''"') context(`"`context'"')
        }
    }
    local rc = _rc
    capture frame change `original_frame'
    if `stage_created' capture frame drop `stage'
    set rngstate `original_rng'
    set varabbrev `original_varabbrev'
    _return restore `caller_r'
    if `rc' exit `rc'
end
