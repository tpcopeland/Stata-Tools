*! _tabtools_collect_atmatrix Version 2.6.2  2026/10/10
*! margins at() values held in the current collection, as a matrix
*! Author: Timothy P Copeland, Karolinska Institutet
*! Program class: rclass

/*
margins, at() posts r(at): one row per at() scenario (1._at, 2._at, ...) and
one column per covariate or factor level. collect keeps it as result[at],
keyed by rowname and colname, so the scenario values survive after r() has
been replaced. This reads them back from the saved collection; r(at) itself
is never consulted, since it may belong to another command by now.

Usage: _tabtools_collect_atmatrix, matrix(name)

Returns
  r(n_at)      number of at() rows (0 when the collection holds none)
  r(atcols)    the colname of each matrix column ("age 0.female 1.female")
  r(atstats)   each scenario's r(atstats#) words (values, asobserved, mean,
               asbalanced, ...), one per matrix column, scenarios separated
               by "|"; empty when the collection holds none
  r(n_sets)    number of margins calls (cmdset levels) that posted at()
  r(single)    1 when the collection holds one unnumbered scenario (margins
               with a single at() posts its row as r1 and its margin as _cons)
  r(conflict)  1 when two margins calls in the collection posted different
               values for one cell; the matrix is then not posted
  matrix(name) n_at x k, row j = scenario j._at; "." cells are missing
               (covariates left as observed). Columns follow r(at)'s order,
               which is the order collect lists the colname levels in.
*/

capture program drop _tabtools_collect_atmatrix
program define _tabtools_collect_atmatrix, rclass
    version 17.0
    local _orig_varabbrev = c(varabbrev)
    set varabbrev off
    tempfile _atjson
    local _json "`_atjson'.stjson"
    capture noisily {
        syntax , MATrix(name)
        quietly collect save "`_json'", replace
        local _at_order ""
        capture quietly collect levelsof colname
        if _rc == 0 local _at_order `"`s(levels)'"'
        local _at_n 0
        local _at_cols ""
        local _at_conflict 0
        local _at_single 0
        local _at_stats ""
        local _at_nsets 0
        mata: _tt_collect_atmatrix(st_local("_json"), st_local("matrix"))
        return scalar n_at = `_at_n'
        return scalar n_sets = `_at_nsets'
        return local atstats `"`_at_stats'"'
        return scalar single = `_at_single'
        return scalar conflict = `_at_conflict'
        return local atcols `"`_at_cols'"'
    }
    local rc = _rc
    capture erase "`_json'"
    set varabbrev `_orig_varabbrev'
    if `rc' exit `rc'
end

capture mata: mata drop _tt_collect_atmatrix()
mata:
void _tt_collect_atmatrix(string scalar path, string scalar matname)
{
    string colvector lines
    string scalar key, val, cs, rn, cn
    string rowvector cols, sets, olev
    real matrix vals, M
    real scalar i, n, r, v, nrow, single, numbered
    real matrix c, k
    real colvector rowix, colix, setix, cellv, pos, perm
    string colvector stats
    real scalar sk

    lines = cat(path)
    n = rows(lines)
    rowix = J(0, 1, .)
    colix = J(0, 1, .)
    setix = J(0, 1, .)
    cellv = J(0, 1, .)
    cols = J(1, 0, "")
    sets = J(1, 0, "")
    stats = J(0, 1, "")
    for (i = 1; i < n; i++) {
        key = lines[i]
        // r(atstats#): how each column of scenario # was set (the first
        // margins call that posted it supplies the words)
        if (ustrregexm(key, "#result\[atstats([0-9]+)\]#result_type\[macro\]")) {
            sk = strtoreal(ustrregexs(1))
            val = strtrim(lines[i + 1])
            if (ustrregexm(val, "^" + char(34) + "s" + char(34) + ": *" + char(34) + "(.*)" + char(34) + ",?$")) {
                if (rows(stats) < sk) stats = stats \ J(sk - rows(stats), 1, "")
                if (stats[sk] == "") stats[sk] = ustrregexs(1)
            }
            continue
        }
        if (!strpos(key, "#result[at]#") | !strpos(key, "#result_type[matrix]")) continue
        if (ustrregexm(key, "rowname\[([0-9]+)\._at\]")) rn = ustrregexs(1)
        else if (ustrregexm(key, "rowname\[r1\]")) rn = "0"
        else continue
        if (!ustrregexm(key, "(^|[#" + char(34) + "])colname\[([^\]]+)\]")) continue
        cn = ustrregexs(2)
        cs = ""
        if (ustrregexm(key, "cmdset\[([^\]]+)\]")) cs = ustrregexs(1)
        val = strtrim(lines[i + 1])
        v = .
        if (ustrregexm(val, "^" + char(34) + "d" + char(34) + ": *([-+0-9.eE]+)")) {
            v = strtoreal(ustrregexs(1))
        }
        c = selectindex(cols :== cn)
        if (length(c) == 0) {
            cols = cols, cn
            c = cols(cols)
        }
        else c = c[1]
        k = selectindex(sets :== cs)
        if (length(k) == 0) {
            sets = sets, cs
            k = cols(sets)
        }
        else k = k[1]
        rowix = rowix \ strtoreal(rn)
        colix = colix \ c
        setix = setix \ k
        cellv = cellv \ v
    }
    st_local("_at_n", "0")
    st_local("_at_conflict", "0")
    if (rows(cellv) == 0) return
    st_local("_at_nsets", strofreal(cols(sets)))
    // a single at() is posted as row r1 (kept here as row 0); numbered
    // scenarios and an unnumbered one cannot both describe this collection
    numbered = any(rowix :> 0)
    single = any(rowix :== 0)
    if (numbered & single) {
        st_local("_at_conflict", "1")
        return
    }
    if (single) {
        rowix = J(rows(rowix), 1, 1)
        st_local("_at_single", "1")
    }
    nrow = max(rowix)
    M = J(nrow, cols(cols), .)
    vals = J(nrow, cols(cols), 0)
    for (i = 1; i <= rows(cellv); i++) {
        r = rowix[i]
        c = colix[i]
        if (vals[r, c]) {
            // the same scenario cell from another margins call must agree,
            // or one row label would describe two different scenarios
            if (M[r, c] != cellv[i] & !(missing(M[r, c]) & missing(cellv[i]))) {
                st_local("_at_conflict", "1")
                return
            }
        }
        else {
            M[r, c] = cellv[i]
            vals[r, c] = 1
        }
    }
    // collect lists colname levels in r(at)'s column order; the saved file
    // sorts its keys, which would put "0.female" before "age"
    olev = tokens(st_local("_at_order"))
    pos = J(cols(cols), 1, .)
    for (c = 1; c <= cols(cols); c++) {
        k = selectindex(olev :== cols[c])
        pos[c] = (length(k) ? k[1] : cols(olev) + c)
    }
    perm = order(pos, 1)
    M = M[., perm]
    cols = cols[perm']
    st_matrix(matname, M)
    st_local("_at_n", strofreal(nrow))
    st_local("_at_cols", invtokens(cols))
    // the words follow r(at)'s columns, the order cols now has; a scenario
    // whose word count does not match is dropped rather than misaligned
    for (i = 1; i <= rows(stats); i++) {
        if (cols(tokens(stats[i])) != cols(cols)) stats[i] = ""
    }
    if (rows(stats) < nrow) stats = stats \ J(nrow - rows(stats), 1, "")
    if (rows(stats)) st_local("_at_stats", invtokens(stats[|1 \ nrow|]', "|"))
}
end
