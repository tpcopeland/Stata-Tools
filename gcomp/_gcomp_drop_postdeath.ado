*! _gcomp_drop_postdeath Version 2.0.1  2026/08/28
*! Drop every observation strictly after the first death within subject
*! Author: Timothy P Copeland, Karolinska Institutet
*! Program class: nclass

capture program drop _gcomp_drop_postdeath
program define _gcomp_drop_postdeath
    version 16.0
    local _orig_varabbrev = c(varabbrev)
    set varabbrev off
    capture noisily {
        syntax, IDvar(varname) TVar(varname) DEATHvar(varname numeric)

        quietly sort `idvar' `tvar'
        tempvar _gc_cumdeath
        quietly by `idvar': gen long `_gc_cumdeath' = sum(`deathvar'==1)
        quietly drop if `_gc_cumdeath' - (`deathvar'==1) > 0
        drop `_gc_cumdeath'
    }
    local rc = _rc
    set varabbrev `_orig_varabbrev'
    if `rc' exit `rc'
end
