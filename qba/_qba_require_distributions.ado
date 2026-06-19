*! _qba_require_distributions Version 1.0.1  2026/06/19
*! Internal helper: load qba distribution helpers
*! Author: Timothy P Copeland, Karolinska Institutet
*! Program class: nclass

capture program drop _qba_require_distributions
program define _qba_require_distributions
    version 16.0
    local _saved_varabbrev = c(varabbrev)
    set varabbrev off
    capture noisily {

        capture findfile _qba_distributions.ado
        if _rc == 0 {
            run "`r(fn)'"
        }
        else {
            display as error "_qba_distributions.ado not found; reinstall qba"
            exit 111
        }

        foreach _helper in _qba_parse_dist _qba_draw_one _qba_draw_scalar {
            capture program list `_helper'
            if _rc {
                display as error "_qba_distributions.ado did not load correctly; reinstall qba"
                exit 111
            }
        }

    }
    local rc = _rc
    set varabbrev `_saved_varabbrev'
    if `rc' exit `rc'
end
