*! _msm_timefixed Version 1.2.3  2026/07/17
*! Identify variables that are not exactly time-fixed within identifier
*! Author: Timothy P Copeland, Karolinska Institutet
*! Program class: rclass (returns results in r())

/*
Syntax:
  _msm_timefixed varlist, id(varname)

Unlike min/max screens, exact row-to-first-row comparison detects intermittent
missingness. A covariate observed at baseline but missing later is not a fixed
covariate for model-contract purposes even when all of its nonmissing values are
identical.

Returns:
  r(varying) - variables that differ within at least one identifier
*/

program define _msm_timefixed, rclass sortpreserve
    version 16.0
    local _orig_varabbrev = c(varabbrev)
    set varabbrev off
    capture noisily {
        syntax varlist(numeric), ID(varname)

        local varying ""
        foreach var of local varlist {
            tempvar differs
            quietly bysort `id': gen byte `differs' = (`var' != `var'[1])
            quietly count if `differs'
            if r(N) > 0 {
                local varying "`varying' `var'"
            }
            drop `differs'
        }
        local varying : list retokenize varying
        return local varying "`varying'"
    }
    local rc = _rc
    set varabbrev `_orig_varabbrev'
    if `rc' exit `rc'
end
