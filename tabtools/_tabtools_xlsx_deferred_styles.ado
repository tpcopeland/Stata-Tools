*! _tabtools_xlsx_deferred_styles Version 2.5.0  2026/10/06
*! Apply queued cell style rules directly to a closed xlsx workbook's XML
*! Author: Timothy P Copeland, Karolinska Institutet
*! Program class: nclass

* Stata's xl() never reuses a style record: every ranged set_font(),
* set_font_bold(), set_fill_pattern(), set_*_border() or alignment call appends
* records for each cell it touches.  Styling a large table therefore costs time
* in proportion to the number of cells and, past a few thousand rows, overflows
* the workbook's style pools, which xl() reports as a misleading
* "invalid alignment format" / "invalid font name" error.
*
* _tabtools_xlsx_apply_styles, defer queues the cell-level rules here instead.
* After close_book(), _tabtools_xlsx_compact_styles unpacks the workbook and
* calls _tt_xlsx_pend_apply(): each cell's final style is composed from the
* queued rules in order (later rules win per attribute, as successive xl()
* calls do), each DISTINCT style is written to styles.xml once, and each styled
* cell gets its s= index.  Row heights, column widths and merges never enter
* the queue; they are still applied through xl() at rule time.
*
*
* Mata compiled while an ado-file autoloads is private to that file, so every
* other file reaches this code through the subcommands below:
*   count  using file, local(name)   queued rule count for file -> c_local
*   apply  using file, root(dir)     write the queue into the unzipped workbook
*   legacy using file                apply the queue through xl() (fallback)
*   clear                            drop the queue

program define _tabtools_xlsx_deferred_styles, nclass
    version 17.0
    local _orig_varabbrev = c(varabbrev)
    set varabbrev off
    capture noisily {
        gettoken sub 0 : 0, parse(" ,")
        if "`sub'" == "count" {
            syntax using/ , Local(name)
            mata: st_local("_n", strofreal(_tt_xlsx_pend_count(`"`using'"')))
            c_local `local' `_n'
        }
        else if "`sub'" == "apply" {
            syntax using/ , ROOT(string)
            mata: _tt_xlsx_pend_apply(`"`root'"', `"`using'"')
        }
        else if "`sub'" == "legacy" {
            syntax using/
            mata: st_local("_n", strofreal(_tt_xlsx_pend_count(`"`using'"')))
            if `_n' > 0 {
                tempname bk mrules
                mata: _tt_xlsx_pend_groups(`"`using'"', "`mrules'")
                mata: `bk' = xl()
                capture noisily {
                    mata: `bk'.load_book(`"`using'"')
                    mata: `bk'.set_mode("open")
                    forvalues g = 1/`_ngroups' {
                        mata: `bk'.set_sheet(`"`_gsheet`g''"')
                        _tabtools_xlsx_apply_styles, book(`bk') sheet(`"`_gsheet`g''"') ///
                            rules(`mrules'`g') font(`"`_gfont`g''"') altfont(`"`_galt`g''"') ///
                            color1(`"`_gc1`g''"') color2(`"`_gc2`g''"') ///
                            color3(`"`_gc3`g''"') color4(`"`_gc4`g''"')
                    }
                }
                local rc = _rc
                capture mata: `bk'.close_book()
                capture mata: mata drop `bk'
                forvalues g = 1/`_ngroups' {
                    capture matrix drop `mrules'`g'
                }
                if `rc' exit `rc'
            }
        }
        else if "`sub'" == "clear" {
            capture mata: rmexternal("_tt_xp_rules")
            capture mata: rmexternal("_tt_xp_meta")
        }
        else {
            display as error "_tabtools_xlsx_deferred_styles: unknown subcommand `sub'"
            exit 198
        }
    }
    local rc = _rc
    set varabbrev `_orig_varabbrev'
    if `rc' exit `rc'
end

version 17.0
capture mata: mata drop _tt_xlsx_pend_count()
capture mata: mata drop _tt_xlsx_pend_groups()
capture mata: mata drop _tt_xlsx_pend_apply()
capture mata: mata drop _tt_xlsx_pend_sheet()
capture mata: mata drop _tt_xlsx_pend_part()
capture mata: mata drop _tt_xlsx_pend_attr()
capture mata: mata drop _tt_xlsx_pend_setattr()
capture mata: mata drop _tt_xlsx_pend_colnum()
capture mata: mata drop _tt_xlsx_pend_colname()
capture mata: mata drop _tt_xlsx_pend_hex()
capture mata: mata drop _tt_xlsx_pend_named()
capture mata: mata drop _tt_xlsx_pend_esc()
capture mata: mata drop _tt_xlsx_pend_unesc()
capture mata: mata drop _tt_xlsx_pend_id()
capture mata: mata drop _tt_xlsx_pend_pool()
capture mata: mata drop _tt_xlsx_pend_setpool()
capture mata: mata drop _tt_xlsx_pend_read()
capture mata: mata drop _tt_xlsx_pend_write()

local _tt_ms0 = c(matastrict)
mata:
mata set matastrict on

real scalar _tt_xlsx_pend_count(string scalar file)
{
    pointer(string matrix) scalar mp
    if ((mp = findexternal("_tt_xp_meta")) == NULL) return(0)
    if (rows(*mp) == 0) return(0)
    return(sum((*mp)[., 1] :== file))
}

// Group the queue for `file' into runs that share sheet, font and colors, and
// hand each run to Stata as a rules matrix for the xl() fallback.
void _tt_xlsx_pend_groups(string scalar file, string scalar mprefix)
{
    real matrix R
    string matrix M
    real scalar i, g, start
    string scalar gs

    R = *findexternal("_tt_xp_rules")
    M = *findexternal("_tt_xp_meta")
    R = select(R, M[., 1] :== file)
    M = select(M, M[., 1] :== file)
    g = 0
    start = 1
    for (i = 1; i <= rows(R); i++) {
        if (i < rows(R)) {
            if (M[i + 1, (2..8)] == M[i, (2..8)]) continue
        }
        g = g + 1
        gs = strofreal(g)
        st_matrix(mprefix + gs, R[(start::i), .])
        st_local("_gsheet" + gs, M[i, 2])
        st_local("_gfont" + gs, M[i, 3])
        st_local("_galt" + gs, M[i, 4])
        st_local("_gc1" + gs, M[i, 5])
        st_local("_gc2" + gs, M[i, 6])
        st_local("_gc3" + gs, M[i, 7])
        st_local("_gc4" + gs, M[i, 8])
        start = i + 1
    }
    st_local("_ngroups", strofreal(g))
}

// ---- direct XML application ---------------------------------------------

// Apply every queued rule for the file to the workbook unpacked under root.
void _tt_xlsx_pend_apply(string scalar root, string scalar file)
{
    real matrix R
    string matrix M
    string colvector sheets
    string scalar styles
    real scalar i

    if (_tt_xlsx_pend_count(file) == 0) return
    // QA hook: lets the suite prove the xl() fallback keeps the formatting.
    if (st_global("TABTOOLS_QA_FORCE_FASTSTYLE_FAIL") == "1") {
        errprintf("deferred styles: forced failure (QA)\n")
        _error(498)
    }
    R = *findexternal("_tt_xp_rules")
    M = *findexternal("_tt_xp_meta")
    R = select(R, M[., 1] :== file)
    M = select(M, M[., 1] :== file)

    styles =_tt_xlsx_pend_read(root + "/xl/styles.xml")
    sheets = uniqrows(M[., 2])
    for (i = 1; i <= rows(sheets); i++) {
        styles = _tt_xlsx_pend_sheet(root, sheets[i],
            select(R, M[., 2] :== sheets[i]),
            select(M, M[., 2] :== sheets[i]), styles)
    }
    _tt_xlsx_pend_write(root + "/xl/styles.xml", styles)
}

// Compose, register and assign the styles of one sheet; returns styles.xml.
string scalar _tt_xlsx_pend_sheet(string scalar root, string scalar sheet,
    real matrix R, string matrix M, string scalar styles)
{
    transmorphic scalar fontids, colorids
    string colvector fontnames, colorhex
    real matrix A, K, U
    real colvector idx, touched, T, o, gid, style_of, rnum, keep
    real rowvector rv, cv
    real scalar nR, nC, i, j, g, G, op, k, nfont, nfill, nborder, nxf, v
    real scalar fid, flid, bid, p, q, r, c, cnum, rowtouched, maxr, maxc, nrow
    string scalar path, sh, head, tail, body, fonts, fills, borders, xfs, x
    string scalar ha, va, cellxml, opentag, content, newrow, ref, dim
    string rowvector rparts, cparts
    string colvector rxml, cells
    real colvector ccol
    real rowvector span

    path = _tt_xlsx_pend_part(root, sheet)
    if (path == "") {
        errprintf("deferred styles: sheet %s not found in workbook\n", sheet)
        _error(198)
    }

    // --- 1. overlay the rules on an attribute grid ---
    // columns: 1 font name id, 2 size, 3 bold, 4 italic, 5 wrap, 6 halign,
    // 7 valign, 8 fill color id, 9 top, 10 bottom, 11 left, 12 right border,
    // 13 font color id.  Missing = never set by any rule.
    nR = max(R[., 3])
    nC = max(R[., 5])
    A = J(nR * nC, 13, .)
    fontids = asarray_create("string", 1)
    colorids = asarray_create("string", 1)
    fontnames = J(0, 1, "")
    colorhex = J(0, 1, "")
    for (i = 1; i <= rows(R); i++) {
        op = R[i, 1]
        rv = (R[i, 2]::R[i, 3])'
        cv = (R[i, 4]..R[i, 5])
        // cell index (r - 1) * nC + c over the rectangle, as an outer sum
        idx = vec(((rv' :- 1) * nC) * J(1, cols(cv), 1) + J(cols(rv), 1, 1) * cv)
        if (op == 1 | op == 15) {
            x = M[i, 9]
            A[idx, 1] = J(rows(idx), 1, _tt_xlsx_pend_id(fontids, fontnames, x))
            A[idx, 2] = J(rows(idx), 1, R[i, 6])
            if (op == 15) {
                x = _tt_xlsx_pend_hex(M[i, 10])
                A[idx, 13] = J(rows(idx), 1, _tt_xlsx_pend_id(colorids, colorhex, x))
            }
        }
        else if (op >= 2 & op <= 6) {
            A[idx, op + 1] = J(rows(idx), 1, R[i, 7])
        }
        else if (op == 7) {
            x = _tt_xlsx_pend_hex(M[i, 10])
            A[idx, 8] = J(rows(idx), 1, _tt_xlsx_pend_id(colorids, colorhex, x))
        }
        else if (op >= 8 & op <= 11) {
            A[idx, op + 1] = J(rows(idx), 1, R[i, 7])
        }
    }
    touched = rowmissing(A) :< 13
    T = selectindex(touched)
    if (rows(T) == 0) return(styles)

    // --- 2. distinct styles ---
    K = editmissing(A[T, .], -1)
    o = order(K, (1..13))
    gid = J(rows(T), 1, .)
    G = 0
    for (i = 1; i <= rows(o); i++) {
        if (i == 1) G = 1
        else if (K[o[i], .] != K[o[i - 1], .]) G = G + 1
        gid[o[i]] = G
    }
    U = J(G, 13, .)
    for (i = 1; i <= rows(T); i++) U[gid[i], .] = K[i, .]

    // --- 3. register one font/fill/border/xf per distinct style ---
    nfont = _tt_xlsx_pend_pool(styles, "fonts")
    nfill = _tt_xlsx_pend_pool(styles, "fills")
    nborder = _tt_xlsx_pend_pool(styles, "borders")
    nxf = _tt_xlsx_pend_pool(styles, "cellXfs")
    if (nfont < 1 | nfill < 1 | nborder < 1 | nxf < 1) {
        errprintf("deferred styles: styles.xml has no base style pools\n")
        _error(198)
    }
    fonts = fills = borders = xfs = ""
    flid = nfill
    for (g = 1; g <= G; g++) {
        // font: schema order b, i, sz, color, name
        x = "<font>"
        if (U[g, 3] == 1) x = x + "<b/>"
        if (U[g, 4] == 1) x = x + "<i/>"
        x = x + `"<sz val=""' + strofreal(U[g, 2] < 0 ? 11 : U[g, 2], "%9.0g") + `""/>"'
        if (U[g, 13] >= 1) x = x + `"<color rgb="FF"' + colorhex[U[g, 13]] + `""/>"'
        x = x + `"<name val=""' + _tt_xlsx_pend_esc(U[g, 1] < 1 ? "Calibri" : fontnames[U[g, 1]]) + `""/></font>"'
        fonts = fonts + x
        fid = nfont + g - 1

        if (U[g, 8] >= 1) {
            fills = fills + `"<fill><patternFill patternType="solid"><fgColor rgb="FF"' +
                colorhex[U[g, 8]] + `""/><bgColor indexed="64"/></patternFill></fill>"'
            v = flid
            flid = flid + 1
        }
        else v = 0

        x = "<border>"
        for (k = 1; k <= 4; k++) {
            // xml order left, right, top, bottom; grid columns 11, 12, 9, 10
            j = (11, 12, 9, 10)[k]
            ref = ("left", "right", "top", "bottom")[k]
            if (U[g, j] >= 1 & U[g, j] <= 3) {
                x = x + "<" + ref + `" style=""' + ("thin", "medium", "thick")[U[g, j]] + `""/>"'
            }
            else x = x + "<" + ref + "/>"
        }
        borders = borders + x + "<diagonal/></border>"
        bid = nborder + g - 1

        ha = U[g, 6] >= 1 ? ("left", "center", "right")[U[g, 6]] : "general"
        va = U[g, 7] >= 1 ? ("bottom", "center", "top")[U[g, 7]] : "bottom"
        xfs = xfs + `"<xf numFmtId="0" fontId=""' + strofreal(fid) +
            `"" fillId=""' + strofreal(v) + `"" borderId=""' + strofreal(bid) +
            `"" xfId="0" applyFont="1" applyFill="1" applyBorder="1" applyAlignment="1"><alignment horizontal=""' +
            ha + `"" vertical=""' + va + `"" wrapText=""' + (U[g, 5] == 1 ? "1" : "0") +
            `""/></xf>"'
    }
    styles = _tt_xlsx_pend_setpool(styles, "fonts", nfont + G, fonts)
    if (flid > nfill) styles = _tt_xlsx_pend_setpool(styles, "fills", flid, fills)
    styles = _tt_xlsx_pend_setpool(styles, "borders", nborder + G, borders)
    styles = _tt_xlsx_pend_setpool(styles, "cellXfs", nxf + G, xfs)

    // style index for every grid cell (missing = untouched)
    style_of = J(nR * nC, 1, .)
    style_of[T] = nxf :+ gid :- 1

    // --- 4. rewrite sheetData ---
    sh = _tt_xlsx_pend_read(path)
    p = strpos(sh, "<sheetData>")
    if (p == 0) {
        p = strpos(sh, "<sheetData/>")
        if (p == 0) {
            errprintf("deferred styles: sheet %s has no sheetData\n", sheet)
            _error(198)
        }
        head = substr(sh, 1, p - 1)
        tail = substr(sh, p + strlen("<sheetData/>"), .)
        body = ""
    }
    else {
        head = substr(sh, 1, p - 1)
        q = strpos(sh, "</sheetData>")
        body = substr(sh, p + strlen("<sheetData>"), q - p - strlen("<sheetData>"))
        tail = substr(sh, q + strlen("</sheetData>"), .)
    }

    rparts = ustrsplit(body, "<row ")
    rnum = J(cols(rparts) + nR, 1, .)
    rxml = J(cols(rparts) + nR, 1, "")
    nrow = 0
    keep = J(nR, 1, 0)
    for (i = 2; i <= cols(rparts); i++) {
        x = "<row " + rparts[i]
        r = strtoreal(_tt_xlsx_pend_attr(x, "r"))
        rowtouched = (r >= 1 & r <= nR)
        if (rowtouched) rowtouched = any(style_of[((r - 1) * nC + 1)::(r * nC)] :< .)
        if (!rowtouched) {
            nrow = nrow + 1
            rnum[nrow] = r
            rxml[nrow] = x
            continue
        }
        keep[r] = 1
        q = strpos(x, ">")
        if (substr(x, q - 1, 1) == "/") {
            opentag = substr(x, 1, q - 2) + ">"
            content = ""
        }
        else {
            opentag = substr(x, 1, q)
            content = substr(x, q + 1, strlen(x) - q - strlen("</row>"))
        }
        cparts = ustrsplit(content, "<c ")
        cells = J(0, 1, "")
        ccol = J(0, 1, .)
        for (j = 2; j <= cols(cparts); j++) {
            cellxml = "<c " + cparts[j]
            ref = _tt_xlsx_pend_attr(cellxml, "r")
            cnum = _tt_xlsx_pend_colnum(ref)
            if (cnum >= 1 & cnum <= nC) {
                v = style_of[(r - 1) * nC + cnum]
                if (v < .) cellxml = _tt_xlsx_pend_setattr(cellxml, "s", strofreal(v))
            }
            cells = cells \ cellxml
            ccol = ccol \ cnum
        }
        // styled cells that xl() never wrote get an empty styled cell
        for (c = 1; c <= nC; c++) {
            v = style_of[(r - 1) * nC + c]
            if (v >= .) continue
            if (any(ccol :== c)) continue
            cells = cells \ (`"<c r=""' + _tt_xlsx_pend_colname(c) + strofreal(r) + `"" s=""' + strofreal(v) + `""/>"')
            ccol = ccol \ c
        }
        o = order(ccol, 1)
        newrow = opentag + invtokens(cells[o]', "") + "</row>"
        nrow = nrow + 1
        rnum[nrow] = r
        rxml[nrow] = newrow
    }
    // styled rows that xl() never wrote
    for (r = 1; r <= nR; r++) {
        if (keep[r]) continue
        idx = style_of[((r - 1) * nC + 1)::(r * nC)]
        if (!any(idx :< .)) continue
        newrow = `"<row r=""' + strofreal(r) + `"">"'
        for (c = 1; c <= nC; c++) {
            if (idx[c] >= .) continue
            newrow = newrow + `"<c r=""' + _tt_xlsx_pend_colname(c) + strofreal(r) + `"" s=""' + strofreal(idx[c]) + `""/>"'
        }
        nrow = nrow + 1
        rnum[nrow] = r
        rxml[nrow] = newrow + "</row>"
    }
    if (nrow > 0) {
        rnum = rnum[(1::nrow)]
        rxml = rxml[(1::nrow)]
        o = order(rnum, 1)
        body = invtokens(rxml[o]', "")
    }
    else body = ""

    // keep <dimension> covering every styled cell
    maxr = nrow > 0 ? max(rnum) : 1
    maxc = nC
    span = (strpos(head, "<dimension ref="), 0)
    if (span[1] > 0) {
        dim = _tt_xlsx_pend_attr(substr(head, span[1], .), "ref")
        p = strpos(dim, ":")
        if (p > 0) {
            x = substr(dim, p + 1, .)
            c = _tt_xlsx_pend_colnum(x)
            r = strtoreal(substr(x, strlen(_tt_xlsx_pend_colname(c)) + 1, .))
            if (c > maxc) maxc = c
            if (r > maxr) maxr = r
            head = subinstr(head, `"<dimension ref=""' + dim + `"""',
                `"<dimension ref="A1:"' + _tt_xlsx_pend_colname(maxc) + strofreal(maxr) + `"""', 1)
        }
    }
    _tt_xlsx_pend_write(path, head + "<sheetData>" + body + "</sheetData>" + tail)
    return(styles)
}

// worksheet part path for a sheet name, via workbook.xml and its rels
string scalar _tt_xlsx_pend_part(string scalar root, string scalar sheet)
{
    string scalar wb, rels, rid, target
    string rowvector parts
    real scalar i

    wb = _tt_xlsx_pend_read(root + "/xl/workbook.xml")
    rels = _tt_xlsx_pend_read(root + "/xl/_rels/workbook.xml.rels")
    rid = ""
    parts = ustrsplit(wb, "<sheet ")
    for (i = 2; i <= cols(parts); i++) {
        if (strlower(_tt_xlsx_pend_unesc(_tt_xlsx_pend_attr("<sheet " + parts[i], "name"))) == strlower(sheet)) {
            rid = _tt_xlsx_pend_attr("<sheet " + parts[i], "r:id")
            break
        }
    }
    if (rid == "") return("")
    parts = ustrsplit(rels, "<Relationship ")
    for (i = 2; i <= cols(parts); i++) {
        if (_tt_xlsx_pend_attr("<Relationship " + parts[i], "Id") == rid) {
            target = _tt_xlsx_pend_attr("<Relationship " + parts[i], "Target")
            if (substr(target, 1, 1) == "/") return(root + target)
            return(root + "/xl/" + target)
        }
    }
    return("")
}

// value of attribute a in the first element of x ("" when absent)
string scalar _tt_xlsx_pend_attr(string scalar x, string scalar a)
{
    real scalar p, q, e
    string scalar key

    e = strpos(x, ">")
    if (e == 0) e = strlen(x)
    key = " " + a + "=" + char(34)
    p = strpos(substr(x, 1, e), key)
    if (p == 0) return("")
    p = p + strlen(key)
    q = strpos(substr(x, p, .), char(34))
    if (q == 0) return("")
    return(substr(x, p, q - 1))
}

// set (or add) attribute a on a cell's opening tag
string scalar _tt_xlsx_pend_setattr(string scalar x, string scalar a, string scalar v)
{
    real scalar e, p, q
    string scalar key, tagpart

    e = strpos(x, ">")
    tagpart = substr(x, 1, e)
    key = " " + a + "=" + char(34)
    p = strpos(tagpart, key)
    if (p > 0) {
        q = strpos(substr(x, p + strlen(key), .), char(34))
        return(substr(x, 1, p - 1) + key + v + char(34) + substr(x, p + strlen(key) + q, .))
    }
    // insert right after r="..."
    p = strpos(tagpart, " r=" + char(34))
    if (p == 0) return(substr(x, 1, 2) + key + v + char(34) + substr(x, 3, .))
    q = strpos(substr(x, p + 4, .), char(34))
    p = p + 4 + q
    return(substr(x, 1, p - 1) + key + v + char(34) + substr(x, p, .))
}

real scalar _tt_xlsx_pend_colnum(string scalar ref)
{
    real scalar i, n, ch

    n = 0
    for (i = 1; i <= strlen(ref); i++) {
        ch = ascii(substr(ref, i, 1))
        if (ch < 65 | ch > 90) break
        n = n * 26 + (ch - 64)
    }
    return(n)
}

string scalar _tt_xlsx_pend_colname(real scalar cin)
{
    real scalar c
    string scalar s

    c = cin
    s = ""
    while (c > 0) {
        s = char(65 + mod(c - 1, 26)) + s
        c = floor((c - 1) / 26)
    }
    return(s)
}

// "R G B" or a Stata color name -> "RRGGBB"
string scalar _tt_xlsx_pend_hex(string scalar color)
{
    string rowvector t
    real scalar i, v
    string scalar out, h

    t = tokens(color)
    if (cols(t) == 1) t = tokens(_tt_xlsx_pend_named(t[1]))
    if (cols(t) != 3) {
        errprintf("deferred styles: cannot resolve color %s\n", color)
        _error(198)
    }
    out = ""
    for (i = 1; i <= 3; i++) {
        v = strtoreal(t[i])
        if (v >= . | v < 0 | v > 255 | v != floor(v)) {
            errprintf("deferred styles: invalid color %s\n", color)
            _error(198)
        }
        h = inbase(16, v)
        if (strlen(h) == 1) h = "0" + h
        out = out + h
    }
    return(strupper(out))
}

// Color name -> "R G B".  xl() understands the CSS/HTML color names, so the
// names it accepts map to exactly the RGB xl() writes (probed 2026-09-29).
// The remaining Stata color names that tabtools' validator accepts are
// rejected by xl() with r(16136); they resolve through Stata's own
// color-<name>.style definitions instead of failing the export.
string scalar _tt_xlsx_pend_named(string scalar name)
{
    string matrix css
    string scalar fn, line, n
    real scalar fh, p, i

    css = J(23, 2, "")
    css[1, .]  = ("black", "0 0 0")
    css[2, .]  = ("blue", "0 0 255")
    css[3, .]  = ("brown", "165 42 42")
    css[4, .]  = ("cyan", "0 255 255")
    css[5, .]  = ("dimgray", "105 105 105")
    css[6, .]  = ("gold", "255 215 0")
    css[7, .]  = ("gray", "128 128 128")
    css[8, .]  = ("green", "0 128 0")
    css[9, .]  = ("khaki", "240 230 140")
    css[10, .] = ("lavender", "230 230 250")
    css[11, .] = ("lime", "0 255 0")
    css[12, .] = ("magenta", "255 0 255")
    css[13, .] = ("maroon", "128 0 0")
    css[14, .] = ("navy", "0 0 128")
    css[15, .] = ("olive", "128 128 0")
    css[16, .] = ("orange", "255 165 0")
    css[17, .] = ("pink", "255 192 203")
    css[18, .] = ("purple", "128 0 128")
    css[19, .] = ("red", "255 0 0")
    css[20, .] = ("sienna", "160 82 45")
    css[21, .] = ("teal", "0 128 128")
    css[22, .] = ("white", "255 255 255")
    css[23, .] = ("yellow", "255 255 0")
    n = strlower(name)
    for (i = 1; i <= rows(css); i++) {
        if (css[i, 1] == n) return(css[i, 2])
    }

    fn = findfile("color-" + n + ".style")
    if (fn == "") return("")
    fh = fopen(fn, "r")
    while ((line = fget(fh)) != J(0, 0, "")) {
        line = strtrim(line)
        if (substr(line, 1, 7) == "set rgb") {
            fclose(fh)
            p = strpos(line, char(34))
            line = substr(line, p + 1, .)
            return(substr(line, 1, strpos(line, char(34)) - 1))
        }
    }
    fclose(fh)
    return("")
}

string scalar _tt_xlsx_pend_esc(string scalar s)
{
    string scalar out
    out = subinstr(s, "&", "&amp;", .)
    out = subinstr(out, "<", "&lt;", .)
    out = subinstr(out, ">", "&gt;", .)
    out = subinstr(out, char(34), "&quot;", .)
    return(out)
}

string scalar _tt_xlsx_pend_unesc(string scalar s)
{
    string scalar out
    out = subinstr(s, "&quot;", char(34), .)
    out = subinstr(out, "&apos;", "'", .)
    out = subinstr(out, "&lt;", "<", .)
    out = subinstr(out, "&gt;", ">", .)
    out = subinstr(out, "&amp;", "&", .)
    return(out)
}

real scalar _tt_xlsx_pend_id(transmorphic scalar ids, string colvector names,
    string scalar key)
{
    if (asarray_contains(ids, key)) return(asarray(ids, key))
    names = names \ key
    asarray(ids, key, rows(names))
    return(rows(names))
}

// count= of a style pool (0 when absent)
real scalar _tt_xlsx_pend_pool(string scalar styles, string scalar tag)
{
    real scalar p
    string scalar x

    p = strpos(styles, "<" + tag + " ")
    if (p == 0) return(0)
    x = substr(styles, p, strpos(substr(styles, p, .), ">"))
    return(strtoreal(_tt_xlsx_pend_attr(x, "count")))
}

string scalar _tt_xlsx_pend_setpool(string scalar styles, string scalar tag,
    real scalar n, string scalar add)
{
    real scalar p, e, q
    string scalar open, close

    p = strpos(styles, "<" + tag + " ")
    e = p + strpos(substr(styles, p, .), ">") - 1
    open = substr(styles, p, e - p + 1)
    close = "</" + tag + ">"
    q = strpos(styles, close)
    if (p == 0 | q == 0 | substr(open, strlen(open) - 1, 1) == "/") {
        errprintf("deferred styles: cannot extend %s pool\n", tag)
        _error(198)
    }
    open = subinstr(open, `" count=""' + _tt_xlsx_pend_attr(open, "count") + `"""',
        `" count=""' + strofreal(n, "%18.0f") + `"""', 1)
    return(substr(styles, 1, p - 1) + open + substr(styles, e + 1, q - e - 1) +
        add + substr(styles, q, .))
}

string scalar _tt_xlsx_pend_read(string scalar path)
{
    real scalar fh, n
    string scalar s

    fh = fopen(path, "r")
    fseek(fh, 0, 1)
    n = ftell(fh)
    fseek(fh, 0, -1)
    s = n > 0 ? fread(fh, n) : ""
    fclose(fh)
    return(s)
}

void _tt_xlsx_pend_write(string scalar path, string scalar s)
{
    real scalar fh

    unlink(path)
    fh = fopen(path, "w")
    fwrite(fh, s)
    fclose(fh)
}

end
mata: mata set matastrict `_tt_ms0'
