*! _gcomp_bootstrap Version 1.1.2  2026/05/06
*! Install-discoverable bootstrap entry point for gcomp
*! Author: Timothy P Copeland, Karolinska Institutet
*! Program class: rclass

capture program drop _gcomp_bootstrap
program define _gcomp_bootstrap, rclass
    version 16.0
    local _orig_varabbrev = c(varabbrev)
    set varabbrev off
    capture noisily {
        capture program list _gcomp_bootstrap_impl
        if _rc {
            capture findfile _gcomp_bootstrap_impl.ado
            if _rc {
                noisily display as error "_gcomp_bootstrap_impl.ado not found; reinstall gcomp"
                exit 111
            }
            capture noisily run "`r(fn)'"
            if _rc {
                noisily display as error "_gcomp_bootstrap_impl.ado could not be loaded; reinstall gcomp"
                exit 111
            }
        }

        capture program list _gcomp_bootstrap_impl
        if _rc {
            noisily display as error "_gcomp_bootstrap_impl not available after load; reinstall gcomp"
            exit 111
        }

        _gcomp_bootstrap_impl `0'
        return add
    }
    local rc = _rc
    set varabbrev `_orig_varabbrev'
    if `rc' exit `rc'
end
