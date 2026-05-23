*! _tabtools_collect_render_current Version 1.3.0  2026/05/24
*! Render selected collect layouts from collect save .stjson into current dataset
*! Author: Timothy P Copeland, Karolinska Institutet
*! Program class: rclass

program define _tabtools_collect_render_current, rclass
    version 17.0
    local _orig_varabbrev = c(varabbrev)
    set varabbrev off
    tempfile _collect_json
    local _json "`_collect_json'.stjson"
    capture noisily {
        syntax , TYPE(string) ROWDIM(string) RESULTS(string) ///
            [ROWLevels(string) COLDIM(string) COLLevels(string) SEP(string) DROPEmpty FACTORParents]

        local type = lower(strtrim("`type'"))
        if !inlist("`type'", "meta", "stats", "main", "icc", "desctab") {
            noisily display as error "type() must be meta, stats, main, icc, or desctab"
            exit 198
        }
        if `"`sep'"' == "" local sep ", "

        quietly collect save "`_json'", replace

        _tt_collect_dim_locals `"`rowdim'"' _tt_row, levels(`"`rowlevels'"')
        local _row_n = r(n)
        if `_row_n' == 0 {
            noisily display as error "collect dimension `rowdim' has no levels"
            exit 459
        }
        local _tt_rowdim_label `"`r(dimlabel)'"'
        forvalues _i = 1/`_row_n' {
            local _tt_row_level_`_i' `"`r(level_`_i')'"'
            local _tt_row_label_`_i' `"`r(label_`_i')'"'
        }

        local _col_n = 0
        local _tt_coldim_label ""
        if `"`coldim'"' != "" {
            _tt_collect_dim_locals `"`coldim'"' _tt_col, levels(`"`collevels'"')
            local _col_n = r(n)
            if `_col_n' == 0 {
                noisily display as error "collect dimension `coldim' has no levels"
                exit 459
            }
            local _tt_coldim_label `"`r(dimlabel)'"'
            forvalues _i = 1/`_col_n' {
                local _tt_col_level_`_i' `"`r(level_`_i')'"'
                local _tt_col_label_`_i' `"`r(label_`_i')'"'
            }
        }

        _tt_collect_result_locals, results(`"`results'"') prefix(_tt_res)
        local _res_n = r(n)
        if `_res_n' == 0 {
            noisily display as error "no result levels specified"
            exit 198
        }
        forvalues _i = 1/`_res_n' {
            local _tt_res_level_`_i' `"`r(level_`_i')'"'
            local _tt_res_label_`_i' `"`r(label_`_i')'"'
        }

        local _dropempty = ("`dropempty'" != "")
        local _factorparents = ("`factorparents'" != "")
        mata: _tt_collect_render_mata(`"`_json'"', `"`type'"', `"`rowdim'"', ///
            `"`coldim'"', `"`sep'"', `_row_n', `_col_n', `_res_n', `_dropempty', ///
            `_factorparents')

        quietly ds
        local _vars `r(varlist)'
        return scalar N = _N
        return scalar k = c(k)
        return scalar n_rows = _N
        return scalar n_cols = c(k)
        return local varlist "`_vars'"
        return local source "collect_stjson"
    }
    local rc = _rc
    capture erase "`_json'"
    set varabbrev `_orig_varabbrev'
    if `rc' exit `rc'
end

program define _tt_collect_dim_locals, rclass
    version 17.0
    syntax anything(name=args) [, LEVELS(string)]
    gettoken dim args : args
    gettoken prefix args : args
    if `"`dim'"' == "" | `"`prefix'"' == "" | strtrim(`"`args'"') != "" {
        exit 198
    }

    if `"`levels'"' == "" {
        quietly collect levelsof `dim'
        local levels `s(levels)'
    }
    else {
        local levels `"`levels'"'
    }
    local _ordered_levels ""
    local _total_levels ""
    foreach _lev of local levels {
        if "`_lev'" == ".m" local _total_levels "`_total_levels' `_lev'"
        else local _ordered_levels "`_ordered_levels' `_lev'"
    }
    local levels = strtrim("`_ordered_levels' `_total_levels'")

    local dimlabel "`dim'"
    local k = 0
    capture quietly collect label list `dim'
    if _rc == 0 {
        if `"`s(label)'"' != "" local dimlabel `"`s(label)'"'
        local k = real("`s(k)'")
        forvalues i = 1/`k' {
            local _map_level_`i' `"`s(level`i')'"'
            local _map_label_`i' `"`s(label`i')'"'
        }
    }

    local n : word count `levels'
    forvalues i = 1/`n' {
        local lev : word `i' of `levels'
        local lab ""
        forvalues j = 1/`k' {
            if `"`_map_level_`j''"' == `"`lev'"' local lab `"`_map_label_`j''"'
        }
        if `"`lab'"' == "" local lab `"`lev'"'
        return local level_`i' `"`lev'"'
        return local label_`i' `"`lab'"'
    }

    return scalar n = `n'
    return local levels `"`levels'"'
    return local dimlabel `"`dimlabel'"'
end

program define _tt_collect_result_locals, rclass
    version 17.0
    syntax , RESULTS(string) PREFIX(name)

    local k = 0
    capture quietly collect label list result
    if _rc == 0 {
        local k = real("`s(k)'")
        forvalues i = 1/`k' {
            local _map_level_`i' `"`s(level`i')'"'
            local _map_label_`i' `"`s(label`i')'"'
        }
    }

    local n : word count `results'
    forvalues i = 1/`n' {
        local lev : word `i' of `results'
        local lab ""
        forvalues j = 1/`k' {
            if `"`_map_level_`j''"' == `"`lev'"' local lab `"`_map_label_`j''"'
        }
        if `"`lab'"' == "" local lab `"`lev'"'
        return local level_`i' `"`lev'"'
        return local label_`i' `"`lab'"'
    }

    return scalar n = `n'
    return local levels `"`results'"'
end

version 17.0
capture mata: mata drop _tt_collect_render_mata()
capture mata: mata drop _tt_collect_items()
capture mata: mata drop _tt_collect_render_meta()
capture mata: mata drop _tt_collect_render_icc()
capture mata: mata drop _tt_collect_render_main()
capture mata: mata drop _tt_collect_render_desctab()
capture mata: mata drop _tt_collect_item()
capture mata: mata drop _tt_collect_sum_items()
capture mata: mata drop _tt_collect_ci()
capture mata: mata drop _tt_collect_has_any()
capture mata: mata drop _tt_collect_factor_parent()
capture mata: mata drop _tt_collect_factor_prefix()
capture mata: mata drop _tt_collect_frag()
capture mata: mata drop _tt_collect_post()
capture mata: mata drop _tt_collect_colname()
capture mata: mata drop _tt_collect_strtype()
capture mata: mata drop _tt_json_object_body()
capture mata: mata drop _tt_json_matching()
capture mata: mata drop _tt_json_skip_ws()
capture mata: mata drop _tt_json_string_end()
capture mata: mata drop _tt_json_unescape()
capture mata: mata drop _tt_json_member_value()

mata:
mata set matastrict on

void _tt_collect_render_mata(
    string scalar filepath,
    string scalar type,
    string scalar rowdim,
    string scalar coldim,
    string scalar sep,
    real scalar row_n,
    real scalar col_n,
    real scalar res_n,
    real scalar dropempty,
    real scalar factorparents)
{
    string matrix items, out

    items = _tt_collect_items(filepath)
    if (rows(items) == 0) _error(2000)

    if (type == "meta" | type == "stats") {
        out = _tt_collect_render_meta(items, rowdim, coldim, sep, row_n,
            col_n, res_n, dropempty)
    }
    else if (type == "icc") {
        out = _tt_collect_render_icc(items, rowdim, coldim, sep, row_n, col_n)
    }
    else if (type == "main") {
        out = _tt_collect_render_main(items, rowdim, coldim, sep, row_n,
            col_n, res_n, factorparents)
    }
    else if (type == "desctab") {
        out = _tt_collect_render_desctab(items, rowdim, coldim, sep, row_n,
            col_n, res_n)
    }
    else {
        _error(198)
    }

    if (rows(out) == 0 | cols(out) == 0) _error(2000)
    _tt_collect_post(out)
}

string matrix _tt_collect_render_meta(
    string matrix items,
    string scalar rowdim,
    string scalar coldim,
    string scalar sep,
    real scalar row_n,
    real scalar col_n,
    real scalar res_n,
    real scalar dropempty)
{
    string rowvector keep
    string matrix out
    string scalar lev, lab, val, rlev, rlab
    real scalar i, j, jj, nkeep

    keep = J(1, res_n, "1")
    if (dropempty) {
        for (j = 1; j <= res_n; j++) {
            rlev = st_local("_tt_res_level_" + strofreal(j))
            keep[j] = "0"
            for (i = 1; i <= row_n; i++) {
                lev = st_local("_tt_row_level_" + strofreal(i))
                if (coldim == "") {
                    val = _tt_collect_item(items, (rowdim), (lev), rlev, sep)
                }
                else {
                    val = _tt_collect_item(items, (rowdim, coldim),
                        (lev, st_local("_tt_col_level_1")), rlev, sep)
                }
                if (val != "") {
                    keep[j] = "1"
                    break
                }
            }
        }
    }

    nkeep = 0
    for (j = 1; j <= res_n; j++) if (keep[j] == "1") nkeep++
    if (nkeep == 0) _error(2000)

    out = J(row_n + 1, nkeep + 1, "")
    jj = 1
    for (j = 1; j <= res_n; j++) {
        if (keep[j] != "1") continue
        jj++
        rlab = st_local("_tt_res_label_" + strofreal(j))
        out[1, jj] = rlab
    }

    for (i = 1; i <= row_n; i++) {
        lev = st_local("_tt_row_level_" + strofreal(i))
        out[i + 1, 1] = lev
        jj = 1
        for (j = 1; j <= res_n; j++) {
            if (keep[j] != "1") continue
            jj++
            rlev = st_local("_tt_res_level_" + strofreal(j))
            if (coldim == "") {
                val = _tt_collect_item(items, (rowdim), (lev), rlev, sep)
            }
            else {
                lab = st_local("_tt_col_level_1")
                val = _tt_collect_item(items, (rowdim, coldim), (lev, lab),
                    rlev, sep)
            }
            out[i + 1, jj] = val
        }
    }

    return(out)
}

string matrix _tt_collect_render_icc(
    string matrix items,
    string scalar rowdim,
    string scalar coldim,
    string scalar sep,
    real scalar row_n,
    real scalar col_n)
{
    string matrix out
    string scalar rowlev, clev, clab
    real scalar i, j

    if (coldim == "" | col_n == 0) _error(198)
    out = J(row_n + 1, col_n + 1, "")
    for (j = 1; j <= col_n; j++) {
        clab = st_local("_tt_col_label_" + strofreal(j))
        out[1, j + 1] = clab
    }
    for (i = 1; i <= row_n; i++) {
        rowlev = st_local("_tt_row_level_" + strofreal(i))
        out[i + 1, 1] = rowlev
        for (j = 1; j <= col_n; j++) {
            clev = st_local("_tt_col_level_" + strofreal(j))
            if (clev == "var(_cons)") {
                out[i + 1, j + 1] = _tt_collect_sum_items(items,
                    (rowdim, coldim), (rowlev, clev), "_r_b")
            }
            else {
                out[i + 1, j + 1] = _tt_collect_item(items, (rowdim, coldim),
                    (rowlev, clev), "_r_b", sep)
            }
        }
    }
    return(out)
}

string matrix _tt_collect_render_main(
    string matrix items,
    string scalar rowdim,
    string scalar coldim,
    string scalar sep,
    real scalar row_n,
    real scalar col_n,
    real scalar res_n,
    real scalar factorparents)
{
    string matrix out
    string rowvector vals
    string scalar rlev, rlab, clev, clab, rowlev, rowlab, val, parent, last_parent
    real scalar i, j, k, c, rowout, kept

    if (coldim == "") col_n = 1
    out = J(row_n * 2 + 2, 1 + col_n * res_n, "")

    c = 1
    for (j = 1; j <= col_n; j++) {
        if (coldim != "") {
            clev = st_local("_tt_col_level_" + strofreal(j))
            clab = st_local("_tt_col_label_" + strofreal(j))
        }
        else {
            clev = ""
            clab = ""
        }
        for (k = 1; k <= res_n; k++) {
            c++
            rlab = st_local("_tt_res_label_" + strofreal(k))
            out[1, c] = clab
            out[2, c] = rlab
        }
    }

    rowout = 2
    last_parent = ""
    for (i = 1; i <= row_n; i++) {
        rowlev = st_local("_tt_row_level_" + strofreal(i))
        rowlab = st_local("_tt_row_label_" + strofreal(i))
        parent = ""
        if (factorparents & rowdim == "colname") parent = _tt_collect_factor_parent(rowlev)
        vals = J(1, col_n * res_n, "")
        kept = 0
        c = 1
        for (j = 1; j <= col_n; j++) {
            if (coldim != "") clev = st_local("_tt_col_level_" + strofreal(j))
            else clev = ""
            for (k = 1; k <= res_n; k++) {
                c++
                rlev = st_local("_tt_res_level_" + strofreal(k))
                if (coldim != "") {
                    val = _tt_collect_item(items, (rowdim, coldim),
                        (rowlev, clev), rlev, sep)
                }
                else {
                    val = _tt_collect_item(items, (rowdim), (rowlev), rlev, sep)
                }
                vals[c - 1] = val
                if (val != "") kept = 1
            }
        }
        if (kept) {
            if (parent != "" & parent != last_parent) {
                rowout++
                out[rowout, 1] = parent
            }
            if (parent == "") last_parent = ""
            else last_parent = parent
            rowout++
            out[rowout, 1] = rowlab
            for (c = 2; c <= cols(out); c++) out[rowout, c] = vals[c - 1]
        }
    }

    if (rowout < rows(out)) out = out[|1, 1 \ rowout, cols(out)|]
    return(out)
}

string scalar _tt_collect_factor_parent(string scalar level)
{
    real scalar p
    string scalar prefix, parent

    p = strpos(level, ".")
    if (p <= 1) return("")
    prefix = substr(level, 1, p - 1)
    if (!_tt_collect_factor_prefix(prefix)) return("")
    parent = substr(level, p + 1, .)
    if (parent == "") return("")
    return(parent)
}

real scalar _tt_collect_factor_prefix(string scalar prefix)
{
    real scalar i, hasdigit
    string scalar ch

    hasdigit = 0
    for (i = 1; i <= strlen(prefix); i++) {
        ch = substr(prefix, i, 1)
        if (ch >= "0" & ch <= "9") {
            hasdigit = 1
        }
        else if (ch != "b" & ch != "o" & ch != "n") {
            return(0)
        }
    }
    return(hasdigit)
}

string matrix _tt_collect_render_desctab(
    string matrix items,
    string scalar rowdim,
    string scalar coldim,
    string scalar sep,
    real scalar row_n,
    real scalar col_n,
    real scalar res_n)
{
    string matrix out
    string scalar rowlev, rowlab, clev, clab, rlev, rlab, val
    real scalar i, j, k, c, rowout, kept

    if (coldim == "") {
        out = J(row_n + 2, 1 + res_n, "")
        for (k = 1; k <= res_n; k++) {
            out[1, k + 1] = st_local("_tt_res_label_" + strofreal(k))
        }
        out[2, 1] = st_local("_tt_rowdim_label")
        rowout = 2
        for (i = 1; i <= row_n; i++) {
            rowlev = st_local("_tt_row_level_" + strofreal(i))
            rowlab = st_local("_tt_row_label_" + strofreal(i))
            kept = 0
            for (k = 1; k <= res_n; k++) {
                rlev = st_local("_tt_res_level_" + strofreal(k))
                val = _tt_collect_item(items, (rowdim), (rowlev), rlev, sep)
                out[rowout + 1, k + 1] = val
                if (val != "") kept = 1
            }
            if (kept) {
                rowout++
                out[rowout, 1] = rowlab
            }
        }
    }
    else {
        out = J(row_n + 4, 1 + col_n * res_n, "")
        c = 1
        for (j = 1; j <= col_n; j++) {
            clab = st_local("_tt_col_label_" + strofreal(j))
            for (k = 1; k <= res_n; k++) {
                c++
                out[1, c] = st_local("_tt_coldim_label")
                out[2, c] = clab
                out[3, c] = st_local("_tt_res_label_" + strofreal(k))
            }
        }
        out[4, 1] = st_local("_tt_rowdim_label")
        rowout = 4
        for (i = 1; i <= row_n; i++) {
            rowlev = st_local("_tt_row_level_" + strofreal(i))
            rowlab = st_local("_tt_row_label_" + strofreal(i))
            kept = 0
            c = 1
            for (j = 1; j <= col_n; j++) {
                clev = st_local("_tt_col_level_" + strofreal(j))
                for (k = 1; k <= res_n; k++) {
                    c++
                    rlev = st_local("_tt_res_level_" + strofreal(k))
                    val = _tt_collect_item(items, (rowdim, coldim),
                        (rowlev, clev), rlev, sep)
                    out[rowout + 1, c] = val
                    if (val != "") kept = 1
                }
            }
            if (kept) {
                rowout++
                out[rowout, 1] = rowlab
            }
        }
    }

    if (rowout < rows(out)) out = out[|1, 1 \ rowout, cols(out)|]
    return(out)
}

string scalar _tt_collect_item(
    string matrix items,
    string rowvector dims,
    string rowvector levels,
    string scalar result,
    string scalar sep)
{
    string scalar key, frag
    real scalar i, j, ok

    if (result == "_r_ci") return(_tt_collect_ci(items, dims, levels, sep))

    for (i = 1; i <= rows(items); i++) {
        key = items[i, 1]
        ok = 1
        for (j = 1; j <= cols(dims); j++) {
            frag = _tt_collect_frag(dims[j], levels[j])
            if (strpos(key, frag) == 0) {
                ok = 0
                break
            }
        }
        if (result != "" & strpos(key, _tt_collect_frag("result", result)) == 0) ok = 0
        if (ok) return(items[i, 2])
    }

    return("")
}

string scalar _tt_collect_sum_items(
    string matrix items,
    string rowvector dims,
    string rowvector levels,
    string scalar result)
{
    string scalar key, frag, val
    real scalar i, j, ok, hits, total, x

    total = 0
    hits = 0
    for (i = 1; i <= rows(items); i++) {
        key = items[i, 1]
        ok = 1
        for (j = 1; j <= cols(dims); j++) {
            frag = _tt_collect_frag(dims[j], levels[j])
            if (strpos(key, frag) == 0) {
                ok = 0
                break
            }
        }
        if (result != "" & strpos(key, _tt_collect_frag("result", result)) == 0) ok = 0
        if (!ok) continue

        val = subinstr(items[i, 2], ",", "", .)
        x = strtoreal(val)
        if (x < .) {
            total = total + x
            hits++
        }
    }

    if (hits == 0) return("")
    return(strtrim(strofreal(total, "%21.16g")))
}

string scalar _tt_collect_ci(
    string matrix items,
    string rowvector dims,
    string rowvector levels,
    string scalar sep)
{
    string scalar lo, hi

    lo = _tt_collect_item(items, dims, levels, "_r_lb", sep)
    hi = _tt_collect_item(items, dims, levels, "_r_ub", sep)
    if (lo == "" | hi == "") return("")
    return("(" + lo + sep + hi + ")")
}

string scalar _tt_collect_frag(string scalar dim, string scalar level)
{
    return(dim + "[" + level + "]")
}

void _tt_collect_post(string matrix out)
{
    string rowvector vnames
    string scalar vtype
    real scalar i, j, maxlen

    vnames = J(1, cols(out), "")
    for (j = 1; j <= cols(out); j++) vnames[j] = _tt_collect_colname(j)

    stata("drop _all")
    for (j = 1; j <= cols(out); j++) {
        maxlen = 0
        for (i = 1; i <= rows(out); i++) {
            if (strlen(out[i, j]) > maxlen) maxlen = strlen(out[i, j])
        }
        vtype = _tt_collect_strtype(maxlen)
        (void) st_addvar(vtype, vnames[j])
    }
    st_addobs(rows(out))
    for (j = 1; j <= cols(out); j++) st_sstore(., vnames[j], out[, j])
}

string scalar _tt_collect_colname(real scalar colnum)
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

string scalar _tt_collect_strtype(real scalar maxlen)
{
    if (maxlen < 1) return("str1")
    if (maxlen <= 2045) return("str" + strofreal(maxlen))
    return("strL")
}

string matrix _tt_collect_items(string scalar filepath)
{
    string colvector lines
    string scalar txt, body, key, val, obj
    string matrix out
    real scalar i, p, q, e

    lines = cat(filepath)
    txt = ""
    for (i = 1; i <= rows(lines); i++) txt = txt + lines[i] + char(10)
    body = _tt_json_object_body(txt, "Items")

    out = J(0, 2, "")
    p = 1
    while (p <= strlen(body)) {
        p = _tt_json_skip_ws(body, p)
        if (p > strlen(body)) break
        if (substr(body, p, 1) == ",") {
            p++
            continue
        }
        if (substr(body, p, 1) != char(34)) break
        e = _tt_json_string_end(body, p)
        key = _tt_json_unescape(substr(body, p + 1, e - p - 1))
        p = _tt_json_skip_ws(body, e + 1)
        if (substr(body, p, 1) != ":") _error(198)
        p = _tt_json_skip_ws(body, p + 1)
        if (substr(body, p, 1) != "{") _error(198)
        q = _tt_json_matching(body, p)
        obj = substr(body, p, q - p + 1)
        val = _tt_json_member_value(obj)
        out = out \ (key, val)
        p = q + 1
    }

    return(out)
}

string scalar _tt_json_object_body(string scalar txt, string scalar key)
{
    string scalar needle
    real scalar p, b, e

    needle = char(34) + key + char(34)
    p = strpos(txt, needle)
    if (p == 0) _error(198)
    b = p + strlen(needle)
    while (b <= strlen(txt) & substr(txt, b, 1) != "{") b++
    if (b > strlen(txt)) _error(198)
    e = _tt_json_matching(txt, b)
    return(substr(txt, b + 1, e - b - 1))
}

real scalar _tt_json_matching(string scalar s, real scalar p)
{
    real scalar i, depth
    string scalar ch

    depth = 0
    i = p
    while (i <= strlen(s)) {
        ch = substr(s, i, 1)
        if (ch == char(34)) {
            i = _tt_json_string_end(s, i) + 1
            continue
        }
        if (ch == "{") depth++
        else if (ch == "}") {
            depth--
            if (depth == 0) return(i)
        }
        i++
    }
    _error(198)
    return(.)
}

real scalar _tt_json_skip_ws(string scalar s, real scalar p)
{
    while (p <= strlen(s) & strpos(" " + char(9) + char(10) + char(13), substr(s, p, 1)) > 0) p++
    return(p)
}

real scalar _tt_json_string_end(string scalar s, real scalar p)
{
    real scalar i
    string scalar ch

    i = p + 1
    while (i <= strlen(s)) {
        ch = substr(s, i, 1)
        if (ch == char(92)) {
            i = i + 2
            continue
        }
        if (ch == char(34)) return(i)
        i++
    }
    _error(198)
    return(.)
}

string scalar _tt_json_unescape(string scalar s)
{
    string scalar out, ch, esc
    real scalar i

    out = ""
    i = 1
    while (i <= strlen(s)) {
        ch = substr(s, i, 1)
        if (ch == char(92) & i < strlen(s)) {
            esc = substr(s, i + 1, 1)
            if (esc == char(34)) out = out + char(34)
            else if (esc == char(92)) out = out + char(92)
            else if (esc == "/") out = out + "/"
            else if (esc == "n") out = out + char(10)
            else if (esc == "r") out = out + char(13)
            else if (esc == "t") out = out + char(9)
            else out = out + esc
            i = i + 2
        }
        else {
            out = out + ch
            i++
        }
    }
    return(out)
}

string scalar _tt_json_member_value(string scalar obj)
{
    real scalar p, q, e
    string scalar ch, val

    p = strpos(obj, ":")
    if (p == 0) return("")
    p = _tt_json_skip_ws(obj, p + 1)
    if (p > strlen(obj)) return("")
    ch = substr(obj, p, 1)
    if (ch == char(34)) {
        e = _tt_json_string_end(obj, p)
        return(_tt_json_unescape(substr(obj, p + 1, e - p - 1)))
    }
    q = p
    while (q <= strlen(obj) & strpos(",}", substr(obj, q, 1)) == 0) q++
    val = strtrim(substr(obj, p, q - p))
    val = subinstr(val, char(10), "", .)
    val = subinstr(val, char(13), "", .)
    val = subinstr(val, char(9), "", .)
    val = strtrim(val)
    if (val == "null") val = ""
    return(val)
}

end
