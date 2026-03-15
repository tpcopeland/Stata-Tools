*! _drest_trim_ps Version 1.0.0  2026/03/15
*! Trim/truncate propensity scores to specified bounds
*! Author: Timothy P Copeland

* Usage: _drest_trim_ps psvar touse lo hi
* Returns via c_local: _drest_n_trimmed

program define _drest_trim_ps
    version 16.0
    set varabbrev off
    set more off

    args psvar touse lo hi

    * Count observations that will be trimmed
    quietly count if `touse' & (`psvar' < `lo' | `psvar' > `hi')
    local n_trimmed = r(N)

    * Truncate propensity scores at bounds
    quietly replace `psvar' = `lo' if `touse' & `psvar' < `lo'
    quietly replace `psvar' = `hi' if `touse' & `psvar' > `hi'

    c_local _drest_n_trimmed "`n_trimmed'"
end
