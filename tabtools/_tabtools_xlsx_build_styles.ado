*! _tabtools_xlsx_build_styles Version 1.9.3  2026/07/03
*! Build compact Excel style rule matrices from row specifications
*! Author: Timothy P Copeland, Karolinska Institutet
*! Program class: rclass

program define _tabtools_xlsx_build_styles, rclass
    version 16.0
    local _orig_varabbrev = c(varabbrev)
    set varabbrev off
    capture noisily {
        syntax , Matrix(name) RULES(string asis) [COLS(integer 0)]

        if `cols' < 0 {
            noisily display as error "cols() must be nonnegative"
            exit 198
        }

        mata: _tt_xlsx_build_styles("`matrix'", `"`rules'"', `cols')

        return scalar n_rules = rowsof(`matrix')
        return scalar n_cols = colsof(`matrix')
        return local rules "`matrix'"
    }
    local rc = _rc
    set varabbrev `_orig_varabbrev'
    if `rc' exit `rc'
end

version 16.0
capture mata: mata drop _tt_xlsx_build_styles()
capture mata: mata drop _tt_xlsx_build_styles_rows()
capture mata: mata drop _tt_xlsx_build_styles_values()
capture mata: mata drop _tt_xlsx_build_styles_error()

mata:
mata set matastrict on

void _tt_xlsx_build_styles(
    string scalar matrix_name,
    string scalar spec,
    real scalar requested_cols)
{
    string rowvector parts
    real matrix out
    real rowvector values
    real scalar i, j, n_rules, n_cols

    spec = subinstr(spec, char(96), "", .)
    spec = subinstr(spec, char(34), "", .)
    spec = strtrim(subinstr(spec, char(39), "", .))
    if (spec == "") {
        _tt_xlsx_build_styles_error("rules() must contain at least one row")
    }
    if (requested_cols < 0 | requested_cols != floor(requested_cols)) {
        _tt_xlsx_build_styles_error("cols() must be a nonnegative integer")
    }

    parts = _tt_xlsx_build_styles_rows(spec)
    n_rules = 0
    n_cols = requested_cols
    for (i = 1; i <= cols(parts); i++) {
        if (strtrim(parts[i]) == "") continue
        values = _tt_xlsx_build_styles_values(parts[i], n_rules + 1)
        n_rules++
        n_cols = max((n_cols, cols(values)))
    }
    if (n_rules == 0) {
        _tt_xlsx_build_styles_error("rules() must contain at least one row")
    }
    if (n_cols == 0) {
        _tt_xlsx_build_styles_error("rules() rows must contain numeric values")
    }

    out = J(n_rules, n_cols, 0)
    j = 0
    for (i = 1; i <= cols(parts); i++) {
        if (strtrim(parts[i]) == "") continue
        j++
        values = _tt_xlsx_build_styles_values(parts[i], j)
        out[j, (1..cols(values))] = values
    }

    st_matrix(matrix_name, out)
}

string rowvector _tt_xlsx_build_styles_rows(string scalar spec)
{
    string rowvector out
    string scalar piece
    real scalar p

    out = J(1, 0, "")
    spec = strtrim(spec)
    while (spec != "") {
        p = strpos(spec, "|")
        if (p == 0) {
            piece = strtrim(spec)
            spec = ""
        }
        else {
            piece = strtrim(substr(spec, 1, p - 1))
            spec = strtrim(substr(spec, p + 1, .))
        }
        if (piece != "") out = out, piece
    }
    return(out)
}

real rowvector _tt_xlsx_build_styles_values(
    string scalar row,
    real scalar row_number)
{
    string rowvector text_values
    real rowvector values
    real scalar i

    row = subinstr(row, char(96), "", .)
    row = subinstr(row, char(34), "", .)
    row = subinstr(row, char(39), "", .)
    row = subinstr(row, ",", " ", .)
    row = subinstr(row, "(", " ", .)
    row = subinstr(row, ")", " ", .)
    row = subinstr(row, "\", " ", .)
    row = strtrim(row)
    if (row == "") {
        _tt_xlsx_build_styles_error("empty row in rules()")
    }

    text_values = tokens(row)
    values = strtoreal(text_values)
    for (i = 1; i <= cols(values); i++) {
        if (values[i] >= .) {
            _tt_xlsx_build_styles_error("non-numeric value in row " +
                strtrim(strofreal(row_number, "%9.0f")))
        }
    }

    return(values)
}

void _tt_xlsx_build_styles_error(string scalar message)
{
    errprintf(message + "\n")
    _error(198)
}

end
