*! _gcomp_check_fit_levels Version 2.0.2  2026/09/30
*! Reject prediction levels absent from the actual component estimation sample
*! Author: Timothy P Copeland, Karolinska Institutet
*! Program class: nclass

capture program drop _gcomp_check_fit_levels
program define _gcomp_check_fit_levels
    version 16.0
    tempname caller_r
    _return hold `caller_r'
    local original_varabbrev = c(varabbrev)
    set varabbrev off
    capture noisily {
        syntax, DRAWIF(string) [CONTEXT(string)]
        local terms : colnames e(b)
        local factor_specs ""
        foreach term of local terms {
            _ms_parse_parts `term'
            if "`r(type)'" == "factor" {
                local specification "`r(name)'"
                if "`r(ts_op)'" != "" local specification "`r(ts_op)'.`specification'"
                local factor_specs "`factor_specs' `specification'"
            }
            else if inlist("`r(type)'", "interaction", "product") {
                local parts = r(k_names)
                forvalues part=1/`parts' {
                    if !missing(r(level`part')) {
                        local specification "`r(name`part')'"
                        if "`r(ts_op`part')'" != "" local specification "`r(ts_op`part')'.`specification'"
                        local factor_specs "`factor_specs' `specification'"
                    }
                }
            }
        }
        local factor_specs : list uniq factor_specs
        foreach specification of local factor_specs {
            tempvar predictor
            quietly generate double `predictor' = `specification'
            quietly levelsof `predictor' if e(sample), local(levels) hexadecimal
            _gcomp_check_categorical `predictor' if (`drawif'), levels(`"`levels'"') ///
                context(`"`context'; factor predictor `specification' in component e(sample)"')
        }
    }
    local rc = _rc
    set varabbrev `original_varabbrev'
    _return restore `caller_r'
    if `rc' exit `rc'
end
