*! _pygrid_window Version 1.0.1  2026/08/30
*! Resolve protocol and coverage bounds for pygrid
*! Author: Timothy P Copeland, Karolinska Institutet
*! Program class: rclass

program define _pygrid_window, rclass
    version 16.0
    local _orig_varabbrev = c(varabbrev)
    set varabbrev off

    capture noisily {
        syntax , START(varname numeric) END(varname numeric) ///
            WSTART(name) WEND(name) EPISODE(name) ///
            [ CLAMPLO(numlist max=1) CLAMPHI(numlist max=1) ///
              COVERAGE(varname numeric) COVERED(name) ]

        confirm new variable `wstart'
        confirm new variable `wend'
        confirm new variable `episode'
        if ("`coverage'" == "") != ("`covered'" == "") {
            display as error "coverage() and covered() must be supplied together"
            exit 198
        }
        if "`covered'" != "" confirm new variable `covered'

        quietly generate long `episode' = _n
        quietly generate double `wstart' = `start'
        quietly generate double `wend' = `end'

        if "`clamplo'" != "" quietly replace `wstart' = max(`wstart', `clamplo')
        if "`clamphi'" != "" quietly replace `wend' = min(`wend', `clamphi')

        local N_uncovered = 0
        if "`coverage'" != "" {
            quietly count if `wstart' < `coverage'
            local N_uncovered = r(N)
            quietly replace `wstart' = max(`wstart', `coverage')
            quietly generate byte `covered' = 1
            label variable `covered' "Within declared data-source coverage"
        }

        quietly count if missing(`wstart') | missing(`wend')
        if r(N) > 0 {
            display as error "internal error: resolved window contains missing bounds"
            exit 459
        }
        quietly count if `wend' < `wstart'
        local N_empty_window = r(N)
        quietly drop if `wend' < `wstart'

        return scalar N_empty_window = `N_empty_window'
        return scalar N_uncovered = `N_uncovered'
    }
    local rc = _rc
    set varabbrev `_orig_varabbrev'
    if `rc' exit `rc'
end
