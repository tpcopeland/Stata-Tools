*! _psdash_export_kv Version 1.5.0  2026/07/22
*! Write a two-column (Metric, Value) summary sheet to an Excel workbook
*! Author: Timothy P Copeland, Karolinska Institutet
*! Internal helper
*!
*! keys() and vals() are parallel lists whose elements may contain spaces
*! when individually double-quoted, e.g. keys(`""Total N" "Mean PS""') .

program define _psdash_export_kv
    version 16.0
    local _vao = c(varabbrev)
    set varabbrev off
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

        tempname xlbook
        mata: `xlbook' = xl()
        mata: `xlbook'.load_book(`"`xlsx'"')
        mata: `xlbook'.set_sheet(`"`sheet'"')
        mata: `xlbook'.set_column_width(1, 1, 32)
        mata: `xlbook'.set_column_width(2, 2, 28)
        mata: `xlbook'.close_book()
        capture mata: mata drop `xlbook'

        capture confirm file "`xlsx'"
        if _rc {
            display as error "Excel export was not created: `xlsx'"
            exit 601
        }
    }
    local rc = _rc
    set varabbrev `_vao'
    if `rc' exit `rc'
end
