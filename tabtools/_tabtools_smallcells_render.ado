*! _tabtools_smallcells_render Version 1.15.0  2026/08/13
*! Render safe disclosure-control strings and numeric extended missings
*! Author: Timothy P Copeland, Karolinska Institutet
*! Program class: rclass

program define _tabtools_smallcells_render, rclass
    version 16.0
    local _orig_varabbrev = c(varabbrev)
    set varabbrev off

    capture noisily {
        syntax, VALUE(real) MASK(integer) SMALLCells(integer) [Format(string)]

        if `smallcells' < 3 {
            display as error "smallcells() must be an integer greater than or equal to 3"
            exit 198
        }
        if !inlist(`mask', 0, 1, 2, 3) {
            display as error "mask() must be 0, 1, 2, or 3"
            exit 198
        }
        if "`format'" == "" local format "%12.0fc"

        if `mask' == 0 {
            local rendered = string(`value', "`format'")
            return local display "`rendered'"
            return scalar value = `value'
        }
        else if `mask' == 1 {
            return local display "<`smallcells'"
            return scalar value = .p
        }
        else if `mask' == 2 {
            return local display "≥`smallcells'"
            return scalar value = .s
        }
        else {
            return local display "Suppressed"
            return scalar value = .d
        }
    }
    local rc = _rc
    set varabbrev `_orig_varabbrev'
    if `rc' exit `rc'
end
