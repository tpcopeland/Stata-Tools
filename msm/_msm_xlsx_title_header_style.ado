*! _msm_xlsx_title_header_style Version 1.2.4  2026/07/23
*! Apply common Excel title and one-row header styling
*! Author: Timothy P Copeland, Karolinska Institutet

program define _msm_xlsx_title_header_style, nclass
    version 16.0
    local _orig_varabbrev = c(varabbrev)
    set varabbrev off

    capture noisily {
        syntax , OBJect(name) SHEET(string) NROWS(integer) NCOLS(integer) ///
            Font(string) FONTSize(integer) HEADERrow(integer) ///
            HBORDER(string) BORDERstyle(string) [TITLErow(integer 1)]

        local _title_fontsize = `fontsize' + 2

        mata: `object'.set_font((1,`nrows'), (1,`ncols'), "`font'", `fontsize')
        mata: `object'.set_font((`titlerow',`titlerow'), (1,`ncols'), "`font'", `_title_fontsize')
        mata: `object'.set_sheet_merge("`sheet'", (`titlerow',`titlerow'), (1,`ncols'))
        mata: `object'.set_text_wrap(`titlerow', 1, "on")
        mata: `object'.set_horizontal_align(`titlerow', 1, "left")
        mata: `object'.set_vertical_align(`titlerow', 1, "center")
        mata: `object'.set_font_bold(`titlerow', 1, "on")

        mata: `object'.set_font_bold(`headerrow', (1,`ncols'), "on")
        mata: `object'.set_horizontal_align(`headerrow', (1,`ncols'), "center")
        mata: `object'.set_vertical_align(`headerrow', (1,`ncols'), "center")
        mata: `object'.set_text_wrap(`headerrow', (1,`ncols'), "on")
        mata: `object'.set_fill_pattern(`headerrow', (1,`ncols'), "solid", "219 229 241")
        mata: `object'.set_top_border(`headerrow', (1,`ncols'), "`hborder'")
        mata: `object'.set_bottom_border(`headerrow', (1,`ncols'), "`hborder'")

        if "`borderstyle'" != "academic" {
            mata: `object'.set_left_border((`headerrow',`nrows'), 1, "`borderstyle'")
            mata: `object'.set_right_border((`headerrow',`nrows'), `ncols', "`borderstyle'")
        }
    }
    local _rc = _rc
    set varabbrev `_orig_varabbrev'
    if `_rc' exit `_rc'
end
