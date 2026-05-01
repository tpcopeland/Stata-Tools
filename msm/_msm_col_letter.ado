*! _msm_col_letter Version 1.0.1  2026/04/30
*! Convert column number to Excel letter reference
*! Author: Timothy P Copeland

* Converts 1 -> A, 2 -> B, ..., 26 -> Z, 27 -> AA, 28 -> AB, etc.
* Returns result in c_local variable 'result'
*
* Usage: _msm_col_letter 3
*        local my_letter = "`result'"   // my_letter = "C"

program define _msm_col_letter
    version 16.0
    local _orig_varabbrev = c(varabbrev)
    set varabbrev off
    capture noisily {
        args col_num

        local col_letter = ""
        local temp_num = `col_num'

        while `temp_num' > 0 {
            local remainder = mod(`temp_num' - 1, 26)
            local col_letter = char(`remainder' + 65) + "`col_letter'"
            local temp_num = floor((`temp_num' - 1) / 26)
        }

        c_local result "`col_letter'"
    }
    local rc = _rc
    set varabbrev `_orig_varabbrev'
    if `rc' exit `rc'
end
