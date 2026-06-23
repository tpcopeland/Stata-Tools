*! _tabtools_xlsx_write Version 1.8.4  2026/06/23
*! Write the current dataset to an Excel sheet through Mata xl()
*! Author: Timothy P Copeland, Karolinska Institutet
*! Program class: rclass

program define _tabtools_xlsx_write, rclass
    version 16.0
    local _orig_varabbrev = c(varabbrev)
    set varabbrev off
    capture noisily {
        syntax using/ , SHEET(string) [BOOK(name)]

        if "`book'" == "" local book "_tabtools_xlsx_book"

        quietly ds
        local _vars `r(varlist)'
        if "`_vars'" == "" {
            noisily display as error "No variables available for Excel export"
            exit 111
        }
        quietly count
        if r(N) == 0 {
            noisily display as error "No observations available for Excel export"
            exit 2000
        }

        mata: `book' = _tt_xlsx_write_mata(`"`using'"', `"`sheet'"', `"`_vars'"')

        return scalar n_rows = _N
        return scalar n_cols = `: word count `_vars''
        return local book "`book'"
        return local sheet `"`sheet'"'
        return local xlsx `"`using'"'
    }
    local rc = _rc
    set varabbrev `_orig_varabbrev'
    if `rc' {
        capture mata: `book'.close_book()
        capture mata: mata drop `book'
        if `rc' == 603 | `rc' == 608 | `rc' == 610 {
            noisily display as error "Hint: ensure the xlsx file is not open in another application"
        }
        exit `rc'
    }
end

version 16.0
capture mata: mata drop _tt_xlsx_write_mata()
capture mata: mata drop _tt_cur_strmat()

mata:
mata set matastrict on

class xl scalar _tt_xlsx_write_mata(
    string scalar filepath,
    string scalar sheet,
    string scalar varlist)
{
    class xl scalar b
    string rowvector sheets
    string matrix table
    real scalar i, found

    b = xl()

    if (!fileexists(filepath)) {
        b.create_book(filepath, sheet, "xlsx")
    }
    else {
        b.load_book(filepath)
        sheets = b.get_sheets()
        found = 0
        for (i = 1; i <= length(sheets); i++) {
            if (sheets[i] == sheet) {
                found = 1
                break
            }
        }
        if (found) {
            b.clear_sheet(sheet)
        }
        else {
            b.add_sheet(sheet)
        }
        b.set_sheet(sheet)
    }

    b.set_mode("open")
    table = _tt_cur_strmat(varlist)
    b.put_string(1, 1, table)

    return(b)
}

string matrix _tt_cur_strmat(string scalar varlist)
{
    string rowvector vars
    string matrix out
    string colvector scol
    real colvector ncol
    string scalar fmt
    real scalar i, j, N, K

    vars = tokens(varlist)
    N = st_nobs()
    K = cols(vars)
    out = J(N, K, "")

    for (j = 1; j <= K; j++) {
        if (st_isstrvar(vars[j])) {
            out[, j] = st_sdata(., vars[j])
        }
        else {
            ncol = st_data(., vars[j])
            scol = J(N, 1, "")
            fmt = st_varformat(vars[j])
            for (i = 1; i <= N; i++) {
                if (ncol[i] < .) {
                    scol[i] = strtrim(strofreal(ncol[i], fmt))
                }
            }
            out[, j] = scol
        }
    }

    return(out)
}

end
