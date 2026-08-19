*! _diagtab_xlsx_write Version 2.0.0  2026/08/19
*! Write the current dataset to an Excel sheet through Mata xl()
*! Author: Timothy P Copeland, Karolinska Institutet
*! Program class: rclass

capture program drop _diagtab_xlsx_write
program define _diagtab_xlsx_write, rclass
    version 17.0
    local _orig_varabbrev = c(varabbrev)
    set varabbrev off
    capture noisily {
        syntax using/ , SHEET(string) [BOOK(name)]

        if "`book'" == "" local book "_diagtab_xlsx_book"

        * A closed xl() object left in Mata under this name is not reset by
        * assigning a fresh one over it: the next create_book() on the same
        * name fails with r(16111).  Drop it first so an interrupted export,
        * or a user object that happens to share the name, cannot poison the
        * next write.
        capture mata: mata drop `book'

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

        mata: `book' = _dt_xlsx_write_mata(`"`using'"', `"`sheet'"', `"`_vars'"')

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

version 17.0
capture mata: mata drop _dt_xlsx_write_mata()
capture mata: mata drop _dt_cur_strmat()

mata:
mata set matastrict on

class xl scalar _dt_xlsx_write_mata(
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
            if (strlower(sheets[i]) == strlower(sheet)) {
                sheet = sheets[i]
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
    table = _dt_cur_strmat(varlist)
    b.put_string(1, 1, table)

    return(b)
}

string matrix _dt_cur_strmat(string scalar varlist)
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
capture program drop _diagtab_xlsx_apply_styles
program define _diagtab_xlsx_apply_styles, rclass
    version 17.0
    local _orig_varabbrev = c(varabbrev)
    set varabbrev off
    capture noisily {
        syntax , BOOK(name) RULES(name) SHEET(string) ///
            [FONT(string) ALTFONT(string) ///
             COLOR1(string) COLOR2(string) ///
             COLOR3(string) COLOR4(string)]

        capture confirm matrix `rules'
        if _rc {
            noisily display as error "rules() must name an existing Stata matrix"
            exit 111
        }

        local _n_rules = rowsof(`rules')
        local _n_cols = colsof(`rules')
        if `_n_rules' < 1 {
            noisily display as error "rules() matrix must contain at least one row"
            exit 198
        }
        if `_n_cols' < 9 {
            noisily display as error "rules() matrix must have at least 9 columns"
            exit 198
        }

        if `"`font'"' == "" local font "Arial"
        if `"`altfont'"' == "" local altfont "Times New Roman"

        mata: _dt_xlsx_apply_styles(`book', `"`sheet'"', st_matrix("`rules'"), ///
            `"`font'"', `"`altfont'"', `"`color1'"', `"`color2'"', `"`color3'"', ///
            `"`color4'"')

        return scalar n_rules = `_n_rules'
        return scalar n_cols = `_n_cols'
        return local rules "`rules'"
        return local sheet `"`sheet'"'
    }
    local rc = _rc
    set varabbrev `_orig_varabbrev'
    if `rc' exit `rc'
end

version 17.0
capture mata: mata drop _dt_xlsx_apply_styles()
capture mata: mata drop _dt_xlsx_style_font()
capture mata: mata drop _dt_xlsx_style_onoff()
capture mata: mata drop _dt_xlsx_style_halign()
capture mata: mata drop _dt_xlsx_style_valign()
capture mata: mata drop _dt_xlsx_style_border()
capture mata: mata drop _dt_xlsx_style_rgb()
capture mata: mata drop _dt_xlsx_style_validate()
capture mata: mata drop _dt_xlsx_style_validate_range()
capture mata: mata drop _dt_xlsx_style_validate_code()
capture mata: mata drop _dt_xlsx_style_validate_positive()
capture mata: mata drop _dt_xlsx_style_validate_rgb()
capture mata: mata drop _dt_xlsx_style_error()

mata:
mata set matastrict on

void _dt_xlsx_apply_styles(
    class xl scalar b,
    string scalar sheet,
    real matrix rules,
    string scalar font,
    string scalar altfont,
    string scalar color1,
    string scalar color2,
    string scalar color3,
    string scalar color4)
{
    real scalar i, op, r1, r2, c1, c2
    string rowvector colors, sheets

    colors = (color1, color2, color3, color4)
    sheets = b.get_sheets()
    for (i = 1; i <= length(sheets); i++) {
        if (strlower(sheets[i]) == strlower(sheet)) {
            sheet = sheets[i]
            break
        }
    }

    for (i = 1; i <= rows(rules); i++) {
        _dt_xlsx_style_validate(rules, i, colors)

        op = rules[i, 1]
        r1 = rules[i, 2]
        r2 = rules[i, 3]
        c1 = rules[i, 4]
        c2 = rules[i, 5]

        if (op == 1) {
            b.set_font((r1, r2), (c1, c2),
                _dt_xlsx_style_font(rules[i, 7], font, altfont), rules[i, 6])
        }
        else if (op == 2) {
            b.set_font_bold((r1, r2), (c1, c2),
                _dt_xlsx_style_onoff(rules[i, 7]))
        }
        else if (op == 3) {
            b.set_font_italic((r1, r2), (c1, c2),
                _dt_xlsx_style_onoff(rules[i, 7]))
        }
        else if (op == 4) {
            b.set_text_wrap((r1, r2), (c1, c2),
                _dt_xlsx_style_onoff(rules[i, 7]))
        }
        else if (op == 5) {
            b.set_horizontal_align((r1, r2), (c1, c2),
                _dt_xlsx_style_halign(rules[i, 7]))
        }
        else if (op == 6) {
            b.set_vertical_align((r1, r2), (c1, c2),
                _dt_xlsx_style_valign(rules[i, 7]))
        }
        else if (op == 7) {
            b.set_fill_pattern((r1, r2), (c1, c2), "solid",
                _dt_xlsx_style_rgb(rules[i, (7..9)], colors))
        }
        else if (op == 8) {
            b.set_top_border((r1, r2), (c1, c2),
                _dt_xlsx_style_border(rules[i, 7]))
        }
        else if (op == 9) {
            b.set_bottom_border((r1, r2), (c1, c2),
                _dt_xlsx_style_border(rules[i, 7]))
        }
        else if (op == 10) {
            b.set_left_border((r1, r2), (c1, c2),
                _dt_xlsx_style_border(rules[i, 7]))
        }
        else if (op == 11) {
            b.set_right_border((r1, r2), (c1, c2),
                _dt_xlsx_style_border(rules[i, 7]))
        }
        else if (op == 12) {
            b.set_row_height(r1, r2, rules[i, 6])
        }
        else if (op == 13) {
            b.set_column_width(c1, c2, rules[i, 6])
        }
        else if (op == 14) {
            b.set_sheet_merge(sheet, (r1, r2), (c1, c2))
        }
        else if (op == 15) {
            b.set_font((r1, r2), (c1, c2), font, rules[i, 6],
                _dt_xlsx_style_rgb(rules[i, (7..9)], colors))
        }
    }
}

string scalar _dt_xlsx_style_font(
    real scalar code,
    string scalar font,
    string scalar altfont)
{
    if (code == 2) return("Calibri")
    if (code == 3) return("Times New Roman")
    if (code == 4) return("Helvetica")
    if (code == 5) return(altfont)
    return(font)
}

string scalar _dt_xlsx_style_onoff(real scalar code)
{
    return(code == 0 ? "off" : "on")
}

string scalar _dt_xlsx_style_halign(real scalar code)
{
    if (code == 2) return("center")
    if (code == 3) return("right")
    return("left")
}

string scalar _dt_xlsx_style_valign(real scalar code)
{
    if (code == 2) return("center")
    if (code == 3) return("top")
    return("bottom")
}

string scalar _dt_xlsx_style_border(real scalar code)
{
    if (code == 2) return("medium")
    if (code == 3) return("thick")
    if (code == 4) return("none")
    return("thin")
}

string scalar _dt_xlsx_style_rgb(real rowvector rgb, string rowvector colors)
{
    real scalar color_code

    if (rgb[1] < 0) {
        color_code = -rgb[1]
        return(colors[color_code])
    }

    return(strtrim(strofreal(rgb[1], "%9.0f")) + " " +
        strtrim(strofreal(rgb[2], "%9.0f")) + " " +
        strtrim(strofreal(rgb[3], "%9.0f")))
}

void _dt_xlsx_style_validate(
    real matrix rules,
    real scalar row,
    string rowvector colors)
{
    real scalar op

    op = rules[row, 1]
    _dt_xlsx_style_validate_code(op, row, "operation", 1, 15)

    if (op == 12) {
        _dt_xlsx_style_validate_range(rules[row, 2], rules[row, 3],
            row, "row")
        _dt_xlsx_style_validate_positive(rules[row, 6], row, "height")
    }
    else if (op == 13) {
        _dt_xlsx_style_validate_range(rules[row, 4], rules[row, 5],
            row, "column")
        _dt_xlsx_style_validate_positive(rules[row, 6], row, "width")
    }
    else {
        _dt_xlsx_style_validate_range(rules[row, 2], rules[row, 3],
            row, "row")
        _dt_xlsx_style_validate_range(rules[row, 4], rules[row, 5],
            row, "column")

        if (op == 1) {
            _dt_xlsx_style_validate_positive(rules[row, 6], row, "font size")
            _dt_xlsx_style_validate_code(rules[row, 7], row, "font code", -1, 5)
        }
        else if (op >= 2 & op <= 4) {
            _dt_xlsx_style_validate_code(rules[row, 7], row, "on/off code", 0, 1)
        }
        else if (op == 5) {
            _dt_xlsx_style_validate_code(rules[row, 7], row,
                "horizontal alignment code", 1, 3)
        }
        else if (op == 6) {
            _dt_xlsx_style_validate_code(rules[row, 7], row,
                "vertical alignment code", 1, 3)
        }
        else if (op == 7) {
            _dt_xlsx_style_validate_rgb(rules[row, (7..9)], row, colors)
        }
        else if (op >= 8 & op <= 11) {
            _dt_xlsx_style_validate_code(rules[row, 7], row, "border code", 1, 4)
        }
        else if (op == 15) {
            _dt_xlsx_style_validate_positive(rules[row, 6], row, "font size")
            _dt_xlsx_style_validate_rgb(rules[row, (7..9)], row, colors)
        }
    }
}

void _dt_xlsx_style_validate_range(
    real scalar first,
    real scalar last,
    real scalar row,
    string scalar name)
{
    if (first >= . | first != floor(first) | first < 1) {
        _dt_xlsx_style_error(row, name + " start must be a positive integer")
    }
    if (last >= . | last != floor(last) | last < 1) {
        _dt_xlsx_style_error(row, name + " end must be a positive integer")
    }
    if (last < first) {
        _dt_xlsx_style_error(row, name + " end must be >= start")
    }
}

void _dt_xlsx_style_validate_code(
    real scalar code,
    real scalar row,
    string scalar name,
    real scalar minval,
    real scalar maxval)
{
    if (code >= . | code != floor(code) | code < minval | code > maxval) {
        _dt_xlsx_style_error(row, name + " out of range")
    }
}

void _dt_xlsx_style_validate_positive(
    real scalar value,
    real scalar row,
    string scalar name)
{
    if (value >= . | value <= 0) {
        _dt_xlsx_style_error(row, name + " must be positive")
    }
}

void _dt_xlsx_style_validate_rgb(
    real rowvector rgb,
    real scalar row,
    string rowvector colors)
{
    real scalar i, color_code

    if (rgb[1] < 0) {
        color_code = -rgb[1]
        if (color_code != floor(color_code) | color_code < 1 | color_code > 4) {
            _dt_xlsx_style_error(row, "color alias code out of range")
        }
        if (colors[color_code] == "") {
            _dt_xlsx_style_error(row, "color alias option is empty")
        }
        return
    }

    for (i = 1; i <= 3; i++) {
        if (rgb[i] >= . | rgb[i] != floor(rgb[i]) | rgb[i] < 0 | rgb[i] > 255) {
            _dt_xlsx_style_error(row, "RGB values must be integers in [0,255]")
        }
    }
}

void _dt_xlsx_style_error(real scalar row, string scalar message)
{
    errprintf("invalid style rule in row " +
        strtrim(strofreal(row, "%9.0f")) + ": " + message + "\n")
    _error(198)
}

end
* Stata's xl() class never reuses a style record.  A ranged set_font() appends
* two <font> entries for every cell it touches, and every other cell-level
* operation (bold, italic, wrap, align, fill, border) appends one, so the
* pools grow with the number of styled cells rather than with the number of
* distinct formats.  A workbook crosses the 65,536-record font ceiling after a
* few dozen styled sheets, and the next set_font() then fails with the
* misleading "<name>: invalid font name" r(16147).  The cell format pool
* (cellXfs) reaches its own 65,490 ceiling just behind it.
*
* Collapsing those pools once the book is closed is format-preserving: only
* the indices change, so every cell keeps the identical resolved font, fill,
* border and alignment.  Compacting after each sheet write keeps the pools
* proportional to the number of distinct formats for the life of the workbook.
*
* Scope: fonts, fills, borders and cellXfs.  numFmts is deliberately NOT
* handled, because nothing in diagtab calls set_number_format() and that pool
* is empty in every workbook the package writes -- every cell ships as a
* string.  If a number-format call is ever added, this helper must learn to
* dedupe numFmts and remap numFmtId as well: left alone that pool would grow
* per styled cell exactly like the others, and worse, a distinct numFmtId on
* every <xf> would make the cellXfs records all differ and defeat the cellXfs
* dedupe below entirely.

capture program drop _diagtab_xlsx_compact_styles
program define _diagtab_xlsx_compact_styles, rclass
    version 17.0
    local _orig_varabbrev = c(varabbrev)
    set varabbrev off
    capture noisily {
        syntax using/ [, noWARNing]

        confirm file `"`using'"'

        * Best effort from here down.  This is an optimization applied to a
        * workbook that has already been written, so anything that goes wrong
        * leaves the file exactly as xl() wrote it instead of failing an
        * export that has otherwise succeeded.
        * Quiet on purpose: a failed rebuild is reported by the note below
        * and by r(compacted), not by dumping a Mata traceback into the
        * middle of a table export.
        capture _diagtab_xlsx_compact_engine using `"`using'"'
        local _engine_rc = _rc

        if `_engine_rc' == 0 {
            return scalar compacted = 1
            return scalar fonts_before = r(fonts_before)
            return scalar fonts_after = r(fonts_after)
            return scalar fills_before = r(fills_before)
            return scalar fills_after = r(fills_after)
            return scalar borders_before = r(borders_before)
            return scalar borders_after = r(borders_after)
            return scalar formats_before = r(formats_before)
            return scalar formats_after = r(formats_after)
        }
        else {
            return scalar compacted = 0
            if "`warning'" == "" {
                noisily display as text "note: could not compact Excel style records (rc `_engine_rc'); the workbook is unchanged but may reach Stata's style-record limit as sheets are added"
            }
        }
    }
    local rc = _rc
    set varabbrev `_orig_varabbrev'
    if `rc' exit `rc'
end

capture program drop _diagtab_xlsx_compact_engine
program define _diagtab_xlsx_compact_engine, rclass
    version 17.0
    local _orig_varabbrev = c(varabbrev)
    set varabbrev off
    capture noisily {
    syntax using/

    * unzipfile always extracts into the current directory, so the workbook
    * has to round-trip through a scratch directory of its own.
    tempfile _stub
    local work "`_stub'_xlsxdir"
    capture mkdir "`work'"
    if _rc exit 693

    * Copy first, while the caller's relative path is still resolvable.
    quietly copy `"`using'"' "`work'/_dt_src.xlsx"

    foreach _p in fonts fills borders formats {
        local _dt_`_p'_before 0
        local _dt_`_p'_after 0
    }

    * Conservative default: anything that stops before the pools are examined
    * is treated as "the workbook changed", so the rebuild-and-verify path
    * still runs rather than being skipped on an unknown state.
    local _dt_changed 1

    local _home "`c(pwd)'"
    capture noisily {
        quietly cd "`work'"
        quietly unzipfile "_dt_src.xlsx"
        erase "_dt_src.xlsx"
        confirm file "xl/styles.xml"
        * The sheet names the rebuilt archive is checked against are read from
        * this part rather than by reopening the original with xl(), so its
        * absence has to stop the run before anything is rewritten.
        confirm file "xl/workbook.xml"

        mata: _dt_xlsx_compact_dir(".")

        * Every pool already holds nothing but distinct records, so rebuilding
        * the archive would write the same workbook back byte for byte.  The
        * zip, the unpack, and the xl() reopen below are the expensive part of
        * this helper -- skipping them when there is nothing to collapse is
        * what keeps a per-sheet compaction affordable across a long workbook.
        if `_dt_changed' {
            mata: st_local("_flist", _dt_xlsx_quoted_files("."))
            if `"`_flist'"' == "" exit 601
            quietly zipfile `_flist', saving("_dt_out.xlsx")
            confirm file "_dt_out.xlsx"

            * zipfile reports success while silently omitting entries it could
            * not add, so the rebuilt archive is unpacked again and matched
            * against what went in, name for name and byte count for byte
            * count.
            capture mkdir "_dt_verify"
            if _rc exit 693
            quietly cd "_dt_verify"
            quietly unzipfile "../_dt_out.xlsx"
            quietly cd ".."
            mata: _dt_xlsx_check_manifest(".", "_dt_verify", "_dt_out.xlsx")
        }
    }
    local _rc_inner = _rc
    quietly cd "`_home'"

    * Reject the rebuilt archive unless xl() still opens it and reports the
    * same sheets; a silently truncated zip must never replace a good
    * workbook.  The names it is compared against come from the workbook.xml
    * already unpacked above: reopening the original with xl() only to list
    * its sheets costs a full parse of the very style pools this helper
    * exists to shrink, and it grows with every sheet added.
    if `_rc_inner' == 0 & `_dt_changed' {
        capture mata: _dt_xlsx_verify("`work'/_dt_out.xlsx", "`work'")
        local _rc_inner = _rc
    }

    if `_rc_inner' == 0 {
        if `_dt_changed' quietly copy "`work'/_dt_out.xlsx" `"`using'"', replace
        return scalar fonts_before = `_dt_fonts_before'
        return scalar fonts_after = `_dt_fonts_after'
        return scalar fills_before = `_dt_fills_before'
        return scalar fills_after = `_dt_fills_after'
        return scalar borders_before = `_dt_borders_before'
        return scalar borders_after = `_dt_borders_after'
        return scalar formats_before = `_dt_formats_before'
        return scalar formats_after = `_dt_formats_after'
    }

    capture mata: _dt_xlsx_rmtree("`work'")
    if `_rc_inner' exit `_rc_inner'
    }
    local rc = _rc
    set varabbrev `_orig_varabbrev'
    if `rc' exit `rc'
end

version 17.0
capture mata: mata drop _dt_xlsx_compact_dir()
capture mata: mata drop _dt_xlsx_compact_styles_xml()
capture mata: mata drop _dt_xlsx_slurp()
capture mata: mata drop _dt_xlsx_spit()
capture mata: mata drop _dt_xlsx_pool_items()
capture mata: mata drop _dt_xlsx_dedupe()
capture mata: mata drop _dt_xlsx_block()
capture mata: mata drop _dt_xlsx_remap_attr()
capture mata: mata drop _dt_xlsx_remap_sheet()
capture mata: mata drop _dt_xlsx_files()
capture mata: mata drop _dt_xlsx_slash()
capture mata: mata drop _dt_xlsx_quoted_files()
capture mata: mata drop _dt_xlsx_rmtree()
capture mata: mata drop _dt_xlsx_verify()
capture mata: mata drop _dt_xlsx_sheetnames_xml()
capture mata: mata drop _dt_xlsx_unescape()
capture mata: mata drop _dt_xlsx_check_manifest()
capture mata: mata drop _dt_xlsx_filesize()

mata:
mata set matastrict on

// Rewrite xl/styles.xml, and every worksheet whose cell format indices move,
// inside an unzipped workbook rooted at `root'.
void _dt_xlsx_compact_dir(string scalar root)
{
    string scalar styles, path
    string colvector sheets
    real colvector xfmap
    real scalar i, identity

    xfmap = J(0, 1, .)
    styles = _dt_xlsx_slurp(root + "/xl/styles.xml")
    styles = _dt_xlsx_compact_styles_xml(styles, xfmap)

    // _dt_xlsx_compact_styles_xml reports whether any pool actually lost a
    // record.  When none did, styles.xml is left untouched so the caller can
    // skip rebuilding the archive around an identical set of parts.
    if (st_local("_dt_changed") == "0") return

    _dt_xlsx_spit(root + "/xl/styles.xml", styles)

    if (rows(xfmap) == 0) return
    identity = 1
    for (i = 1; i <= rows(xfmap); i++) {
        if (xfmap[i] != i - 1) {
            identity = 0
            break
        }
    }
    // An identity map leaves every s="" reference in the sheets valid as written.
    if (identity) return

    sheets = _dt_xlsx_files(root + "/xl/worksheets")
    for (i = 1; i <= rows(sheets); i++) {
        path = sheets[i]
        if (substr(path, strlen(path) - 3, 4) != ".xml") continue
        _dt_xlsx_spit(path, _dt_xlsx_remap_sheet(_dt_xlsx_slurp(path), xfmap))
    }
}

string scalar _dt_xlsx_compact_styles_xml(string scalar styles,
    real colvector xfmap)
{
    string scalar out, body
    string colvector items, uniq, xfs, xfuniq
    real colvector fontmap, fillmap, bordermap, thismap
    real rowvector span
    real scalar i, changed
    string matrix pools

    out = styles
    fontmap = J(0, 1, .)
    fillmap = J(0, 1, .)
    bordermap = J(0, 1, .)
    // Counts how many records the four pools shed in total.  Zero means the
    // workbook is already compact and does not need to be rewritten.
    changed = 0
    st_local("_dt_changed", "1")

    pools = ("fonts", "<font", "fonts") \ ("fills", "<fill", "fills") \
        ("borders", "<border", "borders")

    for (i = 1; i <= rows(pools); i++) {
        span = _dt_xlsx_block(out, pools[i, 1])
        if (span[1] == 0) continue
        body = substr(out, span[2], span[3] - span[2])
        items = _dt_xlsx_pool_items(body, pools[i, 2])
        if (rows(items) == 0) continue

        thismap = J(0, 1, .)
        uniq = _dt_xlsx_dedupe(items, thismap)
        if (i == 1) fontmap = thismap
        else if (i == 2) fillmap = thismap
        else bordermap = thismap

        st_local("_dt_" + pools[i, 3] + "_before", strofreal(rows(items), "%18.0f"))
        st_local("_dt_" + pools[i, 3] + "_after", strofreal(rows(uniq), "%18.0f"))
        changed = changed + (rows(items) - rows(uniq))

        out = substr(out, 1, span[1] - 1) +
            "<" + pools[i, 1] + " count=" + char(34) +
            strofreal(rows(uniq), "%18.0f") + char(34) + ">" +
            invtokens(uniq', "") +
            "</" + pools[i, 1] + ">" +
            substr(out, span[4], .)
    }

    // cellStyleXfs and cellXfs both index the pools just collapsed.
    span = _dt_xlsx_block(out, "cellStyleXfs")
    if (span[1] != 0) {
        body = substr(out, span[2], span[3] - span[2])
        items = _dt_xlsx_pool_items(body, "<xf")
        if (rows(items) > 0) {
            for (i = 1; i <= rows(items); i++) {
                items[i] = _dt_xlsx_remap_attr(items[i], "fontId", fontmap)
                items[i] = _dt_xlsx_remap_attr(items[i], "fillId", fillmap)
                items[i] = _dt_xlsx_remap_attr(items[i], "borderId", bordermap)
            }
            out = substr(out, 1, span[1] - 1) +
                "<cellStyleXfs count=" + char(34) +
                strofreal(rows(items), "%18.0f") + char(34) + ">" +
                invtokens(items', "") + "</cellStyleXfs>" +
                substr(out, span[4], .)
        }
    }

    span = _dt_xlsx_block(out, "cellXfs")
    if (span[1] == 0) {
        st_local("_dt_changed", changed > 0 ? "1" : "0")
        return(out)
    }
    body = substr(out, span[2], span[3] - span[2])
    xfs = _dt_xlsx_pool_items(body, "<xf")
    if (rows(xfs) == 0) {
        st_local("_dt_changed", changed > 0 ? "1" : "0")
        return(out)
    }
    for (i = 1; i <= rows(xfs); i++) {
        xfs[i] = _dt_xlsx_remap_attr(xfs[i], "fontId", fontmap)
        xfs[i] = _dt_xlsx_remap_attr(xfs[i], "fillId", fillmap)
        xfs[i] = _dt_xlsx_remap_attr(xfs[i], "borderId", bordermap)
    }
    xfuniq = _dt_xlsx_dedupe(xfs, xfmap)
    st_local("_dt_formats_before", strofreal(rows(xfs), "%18.0f"))
    st_local("_dt_formats_after", strofreal(rows(xfuniq), "%18.0f"))
    changed = changed + (rows(xfs) - rows(xfuniq))
    st_local("_dt_changed", changed > 0 ? "1" : "0")

    out = substr(out, 1, span[1] - 1) +
        "<cellXfs count=" + char(34) + strofreal(rows(xfuniq), "%18.0f") +
        char(34) + ">" + invtokens(xfuniq', "") + "</cellXfs>" +
        substr(out, span[4], .)

    return(out)
}

// Locate <tag ...> ... </tag>.  Returns (open_start, body_start, close_start,
// after_close) as 1-based byte positions, or all zeros when absent.
real rowvector _dt_xlsx_block(string scalar s, string scalar tag)
{
    real scalar p, bodystart, closepos
    string scalar close

    p = strpos(s, "<" + tag + " ")
    if (p == 0) p = strpos(s, "<" + tag + ">")
    if (p == 0) return((0, 0, 0, 0))

    bodystart = strpos(substr(s, p, .), ">")
    if (bodystart == 0) return((0, 0, 0, 0))
    bodystart = p + bodystart

    close = "</" + tag + ">"
    closepos = strpos(substr(s, bodystart, .), close)
    if (closepos == 0) return((0, 0, 0, 0))
    closepos = bodystart + closepos - 1

    return((p, bodystart, closepos, closepos + strlen(close)))
}

// Split a style pool body into its records.  Splitting on the opening tag
// handles both the <xf .../> and <xf ...>...</xf> forms that xl() emits.
string colvector _dt_xlsx_pool_items(string scalar body, string scalar opentag)
{
    string rowvector parts
    string colvector out
    real scalar i, n

    if (body == "") return(J(0, 1, ""))
    parts = ustrsplit(body, opentag)
    n = cols(parts)
    if (n < 2) return(J(0, 1, ""))
    out = J(n - 1, 1, "")
    for (i = 2; i <= n; i++) out[i - 1] = opentag + parts[i]
    return(out)
}

// Collapse duplicates, preserving first-seen order.  `map' comes back as the
// old-index to new-index translation, both 0 based as OOXML numbers them.
string colvector _dt_xlsx_dedupe(string colvector items, real colvector map)
{
    transmorphic scalar seen
    string colvector uniq
    real scalar i, n, k

    n = rows(items)
    map = J(n, 1, .)
    uniq = J(n, 1, "")
    seen = asarray_create("string", 1)
    k = 0
    for (i = 1; i <= n; i++) {
        if (asarray_contains(seen, items[i])) {
            map[i] = asarray(seen, items[i])
        }
        else {
            k = k + 1
            uniq[k] = items[i]
            asarray(seen, items[i], k - 1)
            map[i] = k - 1
        }
    }
    if (k == 0) return(J(0, 1, ""))
    return(uniq[(1::k)])
}

// Rewrite one numeric attribute of a single record through `map'.
string scalar _dt_xlsx_remap_attr(string scalar item, string scalar attr,
    real colvector map)
{
    real scalar p, q, v
    string scalar key

    if (rows(map) == 0) return(item)
    key = " " + attr + "=" + char(34)
    p = strpos(item, key)
    if (p == 0) return(item)
    p = p + strlen(key)
    q = strpos(substr(item, p, .), char(34))
    if (q == 0) return(item)
    q = p + q - 1
    v = strtoreal(substr(item, p, q - p))
    if (v >= . | v < 0 | v != floor(v) | v + 1 > rows(map)) return(item)

    return(substr(item, 1, p - 1) + strofreal(map[v + 1], "%18.0f") +
        substr(item, q, .))
}

// Rewrite every cell format reference in one worksheet part.  Splitting on
// "<" isolates each element's attributes in its own piece, so a value that
// happens to contain s=" is never touched.
string scalar _dt_xlsx_remap_sheet(string scalar sheet, real colvector xfmap)
{
    string rowvector parts
    real scalar i

    parts = ustrsplit(sheet, "<")
    for (i = 1; i <= cols(parts); i++) {
        if (substr(parts[i], 1, 2) == "c ") {
            parts[i] = _dt_xlsx_remap_attr(parts[i], "s", xfmap)
        }
        else if (substr(parts[i], 1, 4) == "row ") {
            parts[i] = _dt_xlsx_remap_attr(parts[i], "s", xfmap)
        }
        else if (substr(parts[i], 1, 4) == "col ") {
            parts[i] = _dt_xlsx_remap_attr(parts[i], "style", xfmap)
        }
    }
    return(invtokens(parts, "<"))
}

string scalar _dt_xlsx_slurp(string scalar path)
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

void _dt_xlsx_spit(string scalar path, string scalar s)
{
    real scalar fh

    // Mata's fopen() refuses to open an existing file for writing.
    unlink(path)
    fh = fopen(path, "w")
    fwrite(fh, s)
    fclose(fh)
}

// Every file below `base', depth first, as paths relative to `base'.
//
// dir() prefixes each entry with the platform separator, so on Windows the
// results come back as ".\xl\styles.xml" while every caller below builds its
// comparison strings with "/".  Left alone, _dt_xlsx_check_manifest() then
// matches neither its `prefix' nor its `skip' guard, counts the verify tree
// and the rebuilt archive as original parts, and rejects a perfectly good
// rebuild with r(459) -- which silently disables compaction on Windows and
// lets the style pools grow to the 65,536-record ceiling.  Normalizing here
// covers every caller at once and is a no-op on Unix.  It also keeps the file
// list handed to zipfile free of backslash entry names, which Excel and
// xl() both refuse to read back.
string colvector _dt_xlsx_files(string scalar base)
{
    string colvector out, subdirs
    real scalar i

    out = _dt_xlsx_slash(dir(base, "files", "*", 1))
    subdirs = _dt_xlsx_slash(dir(base, "dirs", "*", 1))
    for (i = 1; i <= rows(subdirs); i++) {
        out = out \ _dt_xlsx_files(subdirs[i])
    }
    return(out)
}

// subinstr() raises r(3200) on the J(0,1,"") that dir() returns for an empty
// match, and a leaf directory produces one on every recursion, so the empty
// case has to short-circuit rather than fall through to the replacement.
string colvector _dt_xlsx_slash(string colvector paths)
{
    if (rows(paths) == 0) return(paths)
    return(subinstr(paths, "\", "/", .))
}

string scalar _dt_xlsx_quoted_files(string scalar base)
{
    string colvector files

    files = _dt_xlsx_files(base)
    if (rows(files) == 0) return("")
    return(char(34) + invtokens(files', char(34) + " " + char(34)) + char(34))
}

void _dt_xlsx_rmtree(string scalar base)
{
    string colvector files, subdirs
    real scalar i

    files = dir(base, "files", "*", 1)
    for (i = 1; i <= rows(files); i++) unlink(files[i])
    subdirs = dir(base, "dirs", "*", 1)
    for (i = 1; i <= rows(subdirs); i++) _dt_xlsx_rmtree(subdirs[i])
    rmdir(base)
}

real scalar _dt_xlsx_filesize(string scalar path)
{
    real scalar fh, n

    fh = fopen(path, "r")
    fseek(fh, 0, 1)
    n = ftell(fh)
    fclose(fh)
    return(n)
}

// Compare what was handed to zipfile against what comes back out of the
// archive it wrote.  `sub' holds the unpacked rebuild and is excluded from
// the input side along with the archive itself.
void _dt_xlsx_check_manifest(string scalar root, string scalar sub,
    string scalar archive)
{
    string colvector orig, copy, oname, cname
    string scalar prefix, skip
    real scalar i, k

    prefix = root + "/" + sub + "/"
    skip = root + "/" + archive

    orig = _dt_xlsx_files(root)
    oname = J(0, 1, "")
    for (i = 1; i <= rows(orig); i++) {
        if (orig[i] == skip) continue
        if (substr(orig[i], 1, strlen(prefix)) == prefix) continue
        oname = oname \ substr(orig[i], strlen(root) + 2, .)
    }

    copy = _dt_xlsx_files(root + "/" + sub)
    cname = J(0, 1, "")
    for (i = 1; i <= rows(copy); i++) {
        cname = cname \ substr(copy[i], strlen(prefix) + 1, .)
    }

    if (rows(oname) != rows(cname)) {
        errprintf("rebuilt archive holds %f of %f parts\n", rows(cname),
            rows(oname))
        _error(459)
    }

    oname = sort(oname, 1)
    cname = sort(cname, 1)
    for (i = 1; i <= rows(oname); i++) {
        if (oname[i] != cname[i]) {
            errprintf("rebuilt archive is missing %s\n", oname[i])
            _error(459)
        }
        k = _dt_xlsx_filesize(root + "/" + oname[i])
        if (k != _dt_xlsx_filesize(prefix + cname[i])) {
            errprintf("rebuilt archive truncated %s\n", oname[i])
            _error(459)
        }
    }
}

// Sheet names, in tab order, read from an unpacked workbook.xml.  These are
// the names the original book would report, obtained without paying for an
// xl() load_book() of a workbook whose style pools are still uncollapsed.
//
// Returned as a COLUMN vector, because that is the shape get_sheets() hands
// back and the two are compared directly; a row vector compares unequal
// against every multi-sheet book and would silently disable compaction.
string colvector _dt_xlsx_sheetnames_xml(string scalar root)
{
    string scalar wb
    string rowvector parts
    string colvector out
    string scalar key
    real scalar i, p, q

    wb = _dt_xlsx_slurp(root + "/xl/workbook.xml")
    // ustrsplit() takes a regular expression; this literal has no
    // metacharacters in it, so it splits on the tag as written.
    parts = ustrsplit(wb, "<sheet ")
    out = J(0, 1, "")
    key = "name=" + char(34)
    for (i = 2; i <= cols(parts); i++) {
        p = strpos(parts[i], key)
        if (p == 0) continue
        p = p + strlen(key)
        q = strpos(substr(parts[i], p, .), char(34))
        if (q == 0) continue
        out = out \ _dt_xlsx_unescape(substr(parts[i], p, q - 1))
    }
    return(out)
}

// workbook.xml stores the sheet name XML-escaped while get_sheets() hands
// back the decoded name, so a book with a sheet called "A&B" compares unequal
// unless the five predefined entities are resolved first.  &amp; is resolved
// last: doing it first would turn a literal "&amp;lt;" into "<".
string scalar _dt_xlsx_unescape(string scalar s)
{
    string scalar out

    out = subinstr(s, "&lt;", "<", .)
    out = subinstr(out, "&gt;", ">", .)
    out = subinstr(out, "&quot;", char(34), .)
    out = subinstr(out, "&apos;", char(39), .)
    out = subinstr(out, "&amp;", "&", .)
    return(out)
}

// A rebuilt archive is accepted only if xl() still opens it and reports the
// same sheets, in the same order, as the workbook it would replace.  Only the
// rebuilt file is opened with xl(): that is the check that matters, since it
// proves Stata can still read what zipfile produced.  `root' is the unpacked
// tree the archive was built from, and supplies the expected names.
void _dt_xlsx_verify(string scalar rebuilt, string scalar root)
{
    class xl scalar b
    string colvector sa, sb

    sa = _dt_xlsx_sheetnames_xml(root)

    b = xl()
    b.load_book(rebuilt)
    sb = b.get_sheets()
    b.close_book()

    // get_sheets() returns an N x 1 column vector, so the count lives in
    // rows(); cols() is 1 for every workbook and compares equal always.
    if (rows(sa) != rows(sb)) {
        errprintf("compacted workbook lost a sheet\n")
        _error(459)
    }
    if (rows(sa) > 0) {
        if (sa != sb) {
            errprintf("compacted workbook does not match the original sheets\n")
            _error(459)
        }
    }
}

end
