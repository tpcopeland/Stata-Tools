*! _msm_xlsx_colwidths Version 1.2.1  2026/06/25
*! Apply Excel column widths to an open xl() workbook object
*! Author: Timothy P Copeland

program define _msm_xlsx_colwidths, nclass
    version 16.0
    local _orig_varabbrev = c(varabbrev)
    set varabbrev off

    capture noisily {
        syntax , OBJect(name) WIDTHS(numlist min=1)

        local _col = 0
        foreach _width of numlist `widths' {
            local ++_col
            mata: `object'.set_column_width(`_col', `_col', `_width')
        }
    }
    local _rc = _rc
    set varabbrev `_orig_varabbrev'
    if `_rc' exit `_rc'
end
