*! _tabtools_table_metadata_current Version 1.6.2  2026/06/08
*! Compute table metadata for the current output dataset
*! Author: Timothy P Copeland, Karolinska Institutet
*! Program class: rclass

program define _tabtools_table_metadata_current, rclass
    version 16.0
    local _orig_varabbrev = c(varabbrev)
    set varabbrev off
    capture noisily {
        syntax [varlist(default=none)] , [PVALUEVars(varlist) REFLabel(string)]

        quietly ds
        local _allvars `r(varlist)'
        if "`varlist'" == "" local varlist "`_allvars'"
        if "`varlist'" == "" {
            noisily display as error "No variables available for table metadata"
            exit 111
        }

        mata: _tt_table_metadata(`"`varlist'"', `"`pvaluevars'"', `"`reflabel'"')

        return scalar n_rows = _N
        return scalar n_cols = `: word count `varlist''
        return scalar nonempty = real("`_tt_meta_nonempty'")
        return scalar max_width = real("`_tt_meta_max_width'")
        return scalar max_width_row = real("`_tt_meta_max_row'")
        return scalar max_width_col = real("`_tt_meta_max_col'")
        return scalar n_pvalues = real("`_tt_meta_n_pvalues'")
        return scalar min_pvalue = real("`_tt_meta_min_pvalue'")
        return scalar n_refrows = real("`_tt_meta_n_refrows'")
        return local ref_rows "`_tt_meta_ref_rows'"
    }
    local rc = _rc
    set varabbrev `_orig_varabbrev'
    if `rc' exit `rc'
end

version 16.0
capture mata: mata drop _tt_table_metadata()
capture mata: mata drop _tt_meta_strmat()
capture mata: mata drop _tt_meta_pvalue()

mata:
mata set matastrict on

void _tt_table_metadata(
    string scalar varlist,
    string scalar pvaluevars,
    string scalar reflabel)
{
    string rowvector vars, pvars
    string matrix table
    string scalar cell, ref_rows
    real scalar i, j, nonempty, max_width, max_row, max_col
    real scalar n_pvalues, min_pvalue, pv, n_refrows, row_has_ref

    vars = tokens(varlist)
    pvars = tokens(pvaluevars)
    table = _tt_meta_strmat(vars)

    nonempty = 0
    max_width = 0
    max_row = 0
    max_col = 0
    n_refrows = 0
    ref_rows = ""

    for (i = 1; i <= rows(table); i++) {
        row_has_ref = 0
        for (j = 1; j <= cols(table); j++) {
            cell = strtrim(table[i, j])
            if (cell != "") {
                nonempty++
                if (ustrlen(cell) > max_width) {
                    max_width = ustrlen(cell)
                    max_row = i
                    max_col = j
                }
                if (reflabel != "" & cell == reflabel) {
                    row_has_ref = 1
                }
            }
        }
        if (row_has_ref) {
            n_refrows++
            ref_rows = ref_rows + " " + strofreal(i)
        }
    }

    n_pvalues = 0
    min_pvalue = .
    if (cols(pvars) > 0) {
        for (j = 1; j <= cols(pvars); j++) {
            if (_st_varindex(pvars[j]) == .) continue
            table = _tt_meta_strmat(pvars[j])
            for (i = 1; i <= rows(table); i++) {
                pv = _tt_meta_pvalue(table[i, 1])
                if (pv < .) {
                    n_pvalues++
                    if (min_pvalue >= . | pv < min_pvalue) min_pvalue = pv
                }
            }
        }
    }

    st_local("_tt_meta_nonempty", strofreal(nonempty))
    st_local("_tt_meta_max_width", strofreal(max_width))
    st_local("_tt_meta_max_row", strofreal(max_row))
    st_local("_tt_meta_max_col", strofreal(max_col))
    st_local("_tt_meta_n_pvalues", strofreal(n_pvalues))
    st_local("_tt_meta_min_pvalue", strofreal(min_pvalue))
    st_local("_tt_meta_n_refrows", strofreal(n_refrows))
    st_local("_tt_meta_ref_rows", strtrim(ref_rows))
}

string matrix _tt_meta_strmat(string rowvector vars)
{
    string matrix out
    string colvector scol
    real colvector ncol
    string scalar fmt
    real scalar i, j, N, K

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
                if (ncol[i] < .) scol[i] = strtrim(strofreal(ncol[i], fmt))
            }
            out[, j] = scol
        }
    }

    return(out)
}

real scalar _tt_meta_pvalue(string scalar text)
{
    string scalar s
    real scalar out

    s = strtrim(text)
    if (s == "") return(.)
    if (substr(s, 1, 1) == "<") {
        out = strtoreal(strtrim(substr(s, 2, .)))
        if (out < .) return(0)
        return(.)
    }

    out = strtoreal(s)
    return(out)
}

end
