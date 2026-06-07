*! _tabtools_xlsx_read_current Version 1.6.0  2026/06/07
*! Read an Excel sheet into the current dataset through Mata xl()
*! Author: Timothy P Copeland, Karolinska Institutet
*! Program class: rclass

program define _tabtools_xlsx_read_current, rclass
    version 17.0
    local _orig_varabbrev = c(varabbrev)
    set varabbrev off
    capture noisily {
        syntax using/ , SHEET(string) [MAXRows(integer 20000) MAXCols(integer 702) ///
            PROBERows(integer 256) PROBECols(integer 64)]

        if `maxrows' < 1 {
            noisily display as error "maxrows() must be positive"
            exit 198
        }
        if `maxcols' < 1 | `maxcols' > 702 {
            noisily display as error "maxcols() must be between 1 and 702"
            exit 198
        }
        if `proberows' < 1 {
            noisily display as error "proberows() must be positive"
            exit 198
        }
        if `probecols' < 1 | `probecols' > 702 {
            noisily display as error "probecols() must be between 1 and 702"
            exit 198
        }
        confirm file `"`using'"'

        mata: _tt_xlsx_read_mata(`"`using'"', `"`sheet'"', `maxrows', `maxcols', `proberows', `probecols')

        quietly ds
        local _vars `r(varlist)'

        return scalar N = _N
        return scalar k = c(k)
        return scalar n_rows = _N
        return scalar n_cols = c(k)
        return local varlist "`_vars'"
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
capture mata: mata drop _tt_xlsx_bounds()
capture mata: mata drop _tt_xlsx_stata_strtype()

mata:
mata set matastrict on

void _tt_xlsx_read_mata(
    string scalar filepath,
    string scalar sheet,
    real scalar maxrows,
    real scalar maxcols,
    real scalar proberows,
    real scalar probecols)
{
    class xl scalar b
    string rowvector sheets
    string matrix raw, out
    string rowvector vnames
    real rowvector bounds
    real scalar i, j, found, lastrow, lastcol, rowcap, colcap
    real scalar nextrowcap, nextcolcap, maxlen
    string scalar vtype

    b = xl()
    b.load_book(filepath)
    sheets = b.get_sheets()
    found = 0
    for (i = 1; i <= length(sheets); i++) {
        if (sheets[i] == sheet) {
            found = 1
            break
        }
    }
    if (!found) {
        b.close_book()
        errprintf("sheet %s not found in %s\n", sheet, filepath)
        _error(111)
    }

    b.set_sheet(sheet)

    rowcap = min((maxrows + 1, max((1, proberows))))
    colcap = min((maxcols + 1, max((1, probecols))))
    while (1) {
        raw = b.get_string((1, rowcap), (1, colcap))
        bounds = _tt_xlsx_bounds(raw)
        lastrow = bounds[1]
        lastcol = bounds[2]

        nextrowcap = rowcap
        nextcolcap = colcap
        if (lastrow == rowcap & rowcap < maxrows + 1) {
            nextrowcap = min((maxrows + 1, max((rowcap + 1, rowcap * 2))))
        }
        if (lastcol == colcap & colcap < maxcols + 1) {
            nextcolcap = min((maxcols + 1, max((colcap + 1, colcap * 2))))
        }

        if (nextrowcap == rowcap & nextcolcap == colcap) {
            break
        }
        rowcap = nextrowcap
        colcap = nextcolcap
    }
    b.close_book()

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

    stata("drop _all")
    for (j = 1; j <= lastcol; j++) {
        maxlen = 0
        for (i = 1; i <= lastrow; i++) {
            if (strlen(out[i, j]) > maxlen) maxlen = strlen(out[i, j])
        }
        vtype = _tt_xlsx_stata_strtype(maxlen)
        (void) st_addvar(vtype, vnames[j])
    }
    st_addobs(lastrow)
    for (j = 1; j <= lastcol; j++) {
        st_sstore(., vnames[j], out[, j])
    }
}

real rowvector _tt_xlsx_bounds(string matrix raw)
{
    real scalar i, j, lastrow, lastcol

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

    return((lastrow, lastcol))
}

string scalar _tt_xlsx_stata_strtype(real scalar maxlen)
{
    if (maxlen < 1) return("str1")
    if (maxlen <= 2045) return("str" + strofreal(maxlen))
    return("strL")
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
