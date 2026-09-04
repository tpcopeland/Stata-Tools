*! _psdash_export_balance Version 1.7.1  2026/09/04
*! Write typed, complete balance tables to Excel
*! Author: Timothy P Copeland, Karolinska Institutet
*! Program class: nclass
*! Internal helper

program define _psdash_export_balance, nclass
    version 16.0
    local _vao = c(varabbrev)
    set varabbrev off
    local _putexcel_open = 0
    local _xl_open = 0
    tempname xlbook
    capture noisily {

    syntax , XLSX(string) SHEET(string) TItle(string) MATrix(name) ///
        LABels(string asis) [CONTRASTS(string asis) REFerence(string) HASADJ]

    local nrows = rowsof(`matrix')
    local is_multi = (`"`contrasts'"' != "")
    local headers `""Covariate""'
    local source_cols ""

    if !`is_multi' {
        local headers `"`headers' "Mean (Treated)" "Mean (Control)" "SMD (Raw)" "VR (Raw)" "KS (Raw)""'
        local source_cols "1 2 3 4 5"
        if "`hasadj'" != "" {
            local headers `"`headers' "Mean (T, Adj)" "Mean (C, Adj)" "SMD (Adj)" "VR (Adj)" "KS (Adj)""'
            local source_cols "`source_cols' 6 7 8 9 10"
        }
    }
    else {
        local ncontrasts : word count `contrasts'
        local cnum = 0
        foreach clev of local contrasts {
            local ++cnum
            local headers `"`headers' "SMD `clev'v`reference'" "VR `clev'v`reference'" "KS `clev'v`reference'""'
            local base = (`cnum' - 1) * 5
            local source_cols "`source_cols' `=`base'+3' `=`base'+4' `=`base'+5'"
        }
        if "`hasadj'" != "" {
            local nraw = 5 * `ncontrasts'
            local cnum = 0
            foreach clev of local contrasts {
                local ++cnum
                local headers `"`headers' "SMD Adj `clev'v`reference'" "VR Adj `clev'v`reference'" "KS Adj `clev'v`reference'""'
                local base = `nraw' + (`cnum' - 1) * 5
                local source_cols "`source_cols' `=`base'+3' `=`base'+4' `=`base'+5'"
            }
        }
    }

    local ncols : word count `headers'
    local last_col ""
    local q = `ncols'
    while `q' > 0 {
        local rem = mod(`q' - 1, 26)
        local last_col = char(65 + `rem') + "`last_col'"
        local q = floor((`q' - 1) / 26)
    }

    putexcel set "`xlsx'", sheet("`sheet'", replace) modify
    local _putexcel_open = 1
    putexcel A1 = (`"`title'"'), bold
    if `ncols' > 1 putexcel A1:`last_col'1, merge

    forvalues c = 1/`ncols' {
        local col ""
        local q = `c'
        while `q' > 0 {
            local rem = mod(`q' - 1, 26)
            local col = char(65 + `rem') + "`col'"
            local q = floor((`q' - 1) / 26)
        }
        local header : word `c' of `headers'
        putexcel `col'2 = (`"`header'"')
    }
    putexcel A2:`last_col'2, bold border(bottom)

    forvalues i = 1/`nrows' {
        local row = `i' + 2
        local label : word `i' of `labels'
        putexcel A`row' = (`"`label'"')
        local outcol = 1
        foreach source_col of local source_cols {
            local ++outcol
            local col ""
            local q = `outcol'
            while `q' > 0 {
                local rem = mod(`q' - 1, 26)
                local col = char(65 + `rem') + "`col'"
                local q = floor((`q' - 1) / 26)
            }
            putexcel `col'`row' = (`matrix'[`i', `source_col'])
        }
    }
    if `nrows' > 0 putexcel B3:`last_col'`=`nrows'+2', nformat(number)
    putexcel clear
    local _putexcel_open = 0

    mata: `xlbook' = xl()
    local _xl_open = 1
    mata: `xlbook'.load_book(`"`xlsx'"')
    mata: `xlbook'.set_sheet(`"`sheet'"')
    mata: `xlbook'.set_column_width(1, 1, 28)
    if `ncols' > 1 mata: `xlbook'.set_column_width(2, `ncols', 16)
    mata: `xlbook'.close_book()
    local _xl_open = 0

    capture confirm file "`xlsx'"
    if _rc {
        display as error "Excel export was not created: `xlsx'"
        exit 601
    }
    }
    local rc = _rc
    local _cleanup_rc = 0
    if `_xl_open' {
        capture mata: `xlbook'.close_book()
        if _rc local _cleanup_rc = _rc
    }
    capture mata: mata drop `xlbook'
    if _rc & `_cleanup_rc' == 0 local _cleanup_rc = _rc
    if `_putexcel_open' {
        capture putexcel clear
        if _rc & `_cleanup_rc' == 0 local _cleanup_rc = _rc
    }
    set varabbrev `_vao'
    if `rc' == 0 & `_cleanup_rc' local rc = `_cleanup_rc'
    if `rc' == 0 return clear
    if `rc' exit `rc'
end
