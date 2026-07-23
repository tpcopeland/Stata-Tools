*! _msm_xlsx_put_number Version 1.2.4  2026/07/23
*! Write a numeric Excel cell and optional number format
*! Author: Timothy P Copeland, Karolinska Institutet

program define _msm_xlsx_put_number, nclass
    version 16.0
    local _orig_varabbrev = c(varabbrev)
    set varabbrev off

    capture noisily {
        syntax , OBJect(name) ROW(integer) COL(integer) VALUE(real) ///
            [NFORmat(string)]

        mata: `object'.put_number(`row', `col', `value')
        if `"`nformat'"' != "" {
            mata: `object'.set_number_format(`row', `col', "`nformat'")
        }
    }
    local _rc = _rc
    set varabbrev `_orig_varabbrev'
    if `_rc' exit `_rc'
end
