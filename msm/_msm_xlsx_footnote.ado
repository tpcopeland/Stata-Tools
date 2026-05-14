*! _msm_xlsx_footnote Version 1.0.3  2026/05/06
*! Apply merged Excel footnote styling to an open xl() workbook object
*! Author: Timothy P Copeland

program define _msm_xlsx_footnote, nclass
    version 16.0
    local _orig_varabbrev = c(varabbrev)
    set varabbrev off

    capture noisily {
        syntax , OBJect(name) SHEET(string) ROW(integer) NCOLS(integer) ///
            FOOTnote(string) Font(string) FONTSize(integer)

        mata: `object'.put_string(`row', 1, `"`footnote'"')
        mata: `object'.set_sheet_merge("`sheet'", (`row',`row'), (1,`ncols'))
        mata: `object'.set_font_italic(`row', 1, "on")
        mata: `object'.set_text_wrap(`row', 1, "on")
        mata: `object'.set_horizontal_align(`row', 1, "left")
        mata: `object'.set_font(`row', 1, "`font'", `fontsize')
    }
    local _rc = _rc
    set varabbrev `_orig_varabbrev'
    if `_rc' exit `_rc'
end
