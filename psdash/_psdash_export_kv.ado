*! _psdash_export_kv Version 1.7.0  2026/09/03
*! Write a two-column (Metric, Value) summary sheet to an Excel workbook
*! Author: Timothy P Copeland, Karolinska Institutet
*! Internal helper
*!
*! keys() and vals() are parallel lists whose elements may contain spaces
*! when individually double-quoted, e.g. keys(`""Total N" "Mean PS""') .

program define _psdash_export_kv, nclass
    version 16.0
    local _vao = c(varabbrev)
    set varabbrev off
    local _putexcel_open = 0
    local _xl_open = 0
    tempname xlbook
    capture noisily {
        syntax , XLSX(string) SHEET(string) Keys(string asis) Vals(string asis) ///
            [TItle(string)]

        local nk : word count `keys'
        local nv : word count `vals'
        if `nk' != `nv' {
            display as error "internal error: export key/value count mismatch (`nk' vs `nv')"
            exit 498
        }

        putexcel set "`xlsx'", sheet("`sheet'", replace) modify
        local _putexcel_open = 1
        putexcel A1 = (`"`title'"'), bold
        putexcel A1:B1, merge
        putexcel A2 = ("Metric") B2 = ("Value"), bold border(bottom)
        forvalues i = 1/`nk' {
            local k : word `i' of `keys'
            local v : word `i' of `vals'
            local row = `i' + 2
            putexcel A`row' = (`"`k'"')
            capture confirm number `v'
            if !_rc putexcel B`row' = (`v'), nformat(number)
            else putexcel B`row' = (`"`v'"')
        }
        putexcel clear
        local _putexcel_open = 0

        mata: `xlbook' = xl()
        local _xl_open = 1
        mata: `xlbook'.load_book(`"`xlsx'"')
        mata: `xlbook'.set_sheet(`"`sheet'"')
        mata: `xlbook'.set_column_width(1, 1, 32)
        mata: `xlbook'.set_column_width(2, 2, 28)
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
