*! _psdash_export_kv Version 1.4.0  2026/07/01
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
    local _preserved = 0
    capture noisily {
        syntax , XLSX(string) SHEET(string) Keys(string asis) Vals(string asis) ///
            [TItle(string)]

        local nk : word count `keys'
        local nv : word count `vals'
        if `nk' != `nv' {
            display as error "internal error: export key/value count mismatch (`nk' vs `nv')"
            exit 498
        }

        preserve
        local _preserved = 1
        quietly {
            clear
            set obs `=`nk' + 2'
            gen str244 A = ""
            gen str244 B = ""
            replace A = `"`title'"' in 1
            replace A = "Metric" in 2
            replace B = "Value" in 2
            forvalues i = 1/`nk' {
                local k : word `i' of `keys'
                local v : word `i' of `vals'
                local row = `i' + 2
                replace A = `"`k'"' in `row'
                replace B = `"`v'"' in `row'
            }
            export excel using "`xlsx'", sheet("`sheet'") sheetreplace
        }
    }
    local rc = _rc
    if `_preserved' capture restore
    set varabbrev `_vao'
    if `rc' exit `rc'
end
