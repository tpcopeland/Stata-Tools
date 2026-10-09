*! _iivw_fit_estat Version 4.3.6  2026/10/09
*! estat for iivw_fit: delegate to the underlying model's estat under its
*! native identity, then restore the public fit identity.
*! Author: Timothy P Copeland, Karolinska Institutet
*! Program class: eclass

* iivw_fit posts e(cmd)=iivw_fit so replay and predict go through the package.
* Native estat routines (mixed_estat, glm_estat) refuse a foreign e(cmd) with
* r(301) before reporting group sizes, variance components or information
* criteria. iivw_fit keeps the native hook in e(iivw_estat) and routes
* e(estat_cmd) here. This program installs the native e(cmd) and hook for the
* duration of one estat call -- replacing the hook as well prevents recursive
* dispatch and lets estat's own fallback subcommands (ic, vce, summarize) run --
* and restores the public cmd and hook on success or error. No estimate is
* recomputed or substituted.

program define _iivw_fit_estat, eclass
    version 16.0
    local __iivw_old_varabbrev = c(varabbrev)
    set varabbrev off
    local __iivw_cmd "`e(cmd)'"
    local __iivw_estat "`e(estat_cmd)'"
    local __iivw_swapped = 0
    capture noisily {
        if "`e(iivw_cmd)'" != "iivw_fit" | "`e(iivw_estat)'" == "" | ///
                "`e(iivw_underlying_cmd)'" == "" {
            display as error "last estimates not found"
            error 301
        }
        ereturn local cmd "`e(iivw_underlying_cmd)'"
        ereturn local estat_cmd "`e(iivw_estat)'"
        local __iivw_swapped = 1
        * Native estat parses user-typed variable names: run it under the
        * caller's own varabbrev setting.
        set varabbrev `__iivw_old_varabbrev'
        estat `0'
    }
    local rc = _rc
    if `__iivw_swapped' {
        ereturn local cmd "`__iivw_cmd'"
        ereturn local estat_cmd "`__iivw_estat'"
    }
    set varabbrev `__iivw_old_varabbrev'
    if `rc' exit `rc'
end
