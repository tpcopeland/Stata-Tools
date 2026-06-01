*! _qba_mc_summary Version 1.0.0  2026/06/02
*! Internal helper: Monte Carlo summary statistics
*! Author: Timothy P Copeland, Karolinska Institutet
*! Program class: rclass

capture program drop _qba_mc_summary
local _drop_rc = _rc
program define _qba_mc_summary, rclass
    version 16.0
    local _saved_varabbrev = c(varabbrev)
    set varabbrev off
    capture noisily {

        syntax varname(numeric), Level(cilevel)

        quietly summarize `varlist', detail
        return scalar mean = r(mean)
        return scalar median = r(p50)
        return scalar sd = r(sd)

        local alpha = (100 - `level') / 2
        quietly _pctile `varlist', percentiles(`alpha' `=100-`alpha'')
        return scalar ci_lower = r(r1)
        return scalar ci_upper = r(r2)

    }
    local rc = _rc
    set varabbrev `_saved_varabbrev'
    if `rc' exit `rc'
end
