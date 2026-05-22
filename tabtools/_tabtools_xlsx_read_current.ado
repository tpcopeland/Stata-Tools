*! _tabtools_xlsx_read_current Version 1.3.0  2026/05/23
*! Read an Excel sheet into the current dataset through Mata xl()
*! Author: Timothy P Copeland, Karolinska Institutet
*! Program class: rclass

program define _tabtools_xlsx_read_current, rclass
    version 17.0
    local _orig_varabbrev = c(varabbrev)
    set varabbrev off
    capture noisily {
        syntax using/ , SHEET(string) [MAXRows(integer 5000) MAXCols(integer 100)]

        if `maxrows' < 1 {
            noisily display as error "maxrows() must be positive"
            exit 198
        }
        if `maxcols' < 1 | `maxcols' > 702 {
            noisily display as error "maxcols() must be between 1 and 702"
            exit 198
        }

        drop _all
        mata: _tt_xlsx_read_mata(`"`using'"', `"`sheet'"', `maxrows', `maxcols')

        return scalar n_rows = _N
        return scalar n_cols = c(k)
        return local sheet `"`sheet'"'
        return local xlsx `"`using'"'
    }
    local rc = _rc
    set varabbrev `_orig_varabbrev'
    if `rc' exit `rc'
end

version 17.0
capture mata: mata drop _tt_xlsx_read_mata()
capture mata: mata drop _tt_excel_colname()

mata:
mata set matastrict on

void _tt_xlsx_read_mata(
    string scalar filepath,
    string scalar sheet,
    real scalar maxrows,
    real scalar maxcols)
{
    class xl scalar b
    string matrix raw, out
    string rowvector vnames
    real scalar i, j, lastrow, lastcol

    b = xl()
    b.load_book(filepath)
    b.set_sheet(sheet)
    raw = b.get_string((1, maxrows + 1), (1, maxcols + 1))
    b.close_book()

    lastrow = 0
    lastcol = 0
    for (i = 1; i <= rows(raw); i++) {
        for (j = 1; j <= cols(raw); j++) {
            if (strtrim(raw[i, j]) != "") {
                if (i > lastrow) lastrow = i
                if (j > lastcol) lastcol = j
            }
        }
    }

    if (lastrow == 0 | lastcol == 0) {
        _error(2000)
    }
    if (lastrow > maxrows | lastcol > maxcols) {
        _error(908)
    }

    out = raw[|1, 1 \ lastrow, lastcol|]
    vnames = J(1, lastcol, "")
    for (j = 1; j <= lastcol; j++) {
        vnames[j] = _tt_excel_colname(j)
    }

    (void) st_addvar("strL", vnames)
    st_addobs(lastrow)
    for (j = 1; j <= lastcol; j++) {
        st_sstore(., vnames[j], out[, j])
    }
}

string scalar _tt_excel_colname(real scalar colnum)
{
    string scalar out
    real scalar n, rem

    out = ""
    n = colnum
    while (n > 0) {
        rem = mod(n - 1, 26)
        out = char(rem + 65) + out
        n = floor((n - 1) / 26)
    }

    return(out)
}

end
