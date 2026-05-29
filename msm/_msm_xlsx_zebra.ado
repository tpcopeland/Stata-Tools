*! _msm_xlsx_zebra Version 1.0.4  2026/05/29
*! Apply alternating row fill to an open xl() workbook object
*! Author: Timothy P Copeland

program define _msm_xlsx_zebra, nclass
    version 16.0
    local _orig_varabbrev = c(varabbrev)
    set varabbrev off

    capture noisily {
        syntax , OBJect(name) STARTrow(integer) LASTrow(integer) NCOLS(integer)

        if `startrow' <= `lastrow' {
            forvalues _row = `startrow'(2)`lastrow' {
                mata: `object'.set_fill_pattern(`_row', (1,`ncols'), "solid", "237 242 249")
            }
        }
    }
    local _rc = _rc
    set varabbrev `_orig_varabbrev'
    if `_rc' exit `_rc'
end
