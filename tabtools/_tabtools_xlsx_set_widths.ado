*! _tabtools_xlsx_set_widths Version 1.6.1  2026/06/08
*! Apply Excel column widths to an open Mata xl() workbook
*! Author: Timothy P Copeland, Karolinska Institutet
*! Program class: rclass

program define _tabtools_xlsx_set_widths, rclass
    version 16.0
    local _orig_varabbrev = c(varabbrev)
    set varabbrev off
    capture noisily {
        syntax , BOOK(name) WIDTHS(numlist min=1) [START(integer 1)]

        if `start' < 1 {
            noisily display as error "start() must be a positive column number"
            exit 198
        }
        foreach _width of numlist `widths' {
            if `_width' <= 0 {
                noisily display as error "widths() values must be positive"
                exit 198
            }
        }

        mata: _tt_xlsx_set_widths(`book', `start', strtoreal(tokens(`"`widths'"')))

        return scalar n_widths = `: word count `widths''
        return scalar start = `start'
    }
    local rc = _rc
    set varabbrev `_orig_varabbrev'
    if `rc' exit `rc'
end

version 16.0
capture mata: mata drop _tt_xlsx_set_widths()

mata:
mata set matastrict on

void _tt_xlsx_set_widths(class xl scalar b, real scalar start, real rowvector widths)
{
    real scalar i

    for (i = 1; i <= cols(widths); i++) {
        b.set_column_width(start + i - 1, start + i - 1, widths[i])
    }
}

end
