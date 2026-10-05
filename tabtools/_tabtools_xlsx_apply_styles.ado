*! _tabtools_xlsx_apply_styles Version 2.4.0  2026/10/05
*! Apply compact Excel style rules to an open Mata xl() workbook
*! Author: Timothy P Copeland, Karolinska Institutet
*! Program class: rclass

program define _tabtools_xlsx_apply_styles, rclass
    version 17.0
    local _orig_varabbrev = c(varabbrev)
    set varabbrev off
    capture noisily {
        syntax , BOOK(name) RULES(name) SHEET(string) ///
            [FONT(string) ALTFONT(string) ///
             COLOR1(string) COLOR2(string) ///
             COLOR3(string) COLOR4(string) DEFER]

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

        * defer: cell-level rules are validated here but written straight into
        * the workbook XML by _tabtools_xlsx_compact_styles after close_book(),
        * so xl() never appends a style record per styled cell (the reason a
        * large table used to run for minutes and then hit the style-record
        * ceiling).  Row heights, column widths and merges still go through xl().
        mata: _tt_xlsx_apply_styles(`book', `"`macval(sheet)'"', st_matrix("`rules'"), ///
            `"`font'"', `"`altfont'"', `"`color1'"', `"`color2'"', `"`color3'"', ///
            `"`color4'"', "`defer'" != "")

        return scalar n_rules = `_n_rules'
        return scalar n_cols = `_n_cols'
        return local rules "`rules'"
        return scalar deferred = ("`defer'" != "")
        return local sheet `"`macval(sheet)'"'
    }
    local rc = _rc
    set varabbrev `_orig_varabbrev'
    if `rc' exit `rc'
end

version 17.0
capture mata: mata drop _tt_xlsx_apply_styles()
capture mata: mata drop _tt_xlsx_apply_one()
capture mata: mata drop _tt_xlsx_pend_add()
capture mata: mata drop _tt_xlsx_style_font()
capture mata: mata drop _tt_xlsx_style_onoff()
capture mata: mata drop _tt_xlsx_style_halign()
capture mata: mata drop _tt_xlsx_style_valign()
capture mata: mata drop _tt_xlsx_style_border()
capture mata: mata drop _tt_xlsx_style_rgb()
capture mata: mata drop _tt_xlsx_style_validate()
capture mata: mata drop _tt_xlsx_style_validate_range()
capture mata: mata drop _tt_xlsx_style_validate_code()
capture mata: mata drop _tt_xlsx_style_validate_positive()
capture mata: mata drop _tt_xlsx_style_validate_rgb()
capture mata: mata drop _tt_xlsx_style_error()
capture mata: mata drop _tt_xlsx_fn_paragraphs()
capture mata: mata drop _tt_xlsx_fn_paras()

* matastrict is a session setting: save the caller's value here and
* restore it after the block, so loading this file never leaks it.
local _tt_ms0 = c(matastrict)
mata:
mata set matastrict on

void _tt_xlsx_apply_styles(
    class xl scalar b,
    string scalar sheet,
    real matrix rules,
    string scalar font,
    string scalar altfont,
    string scalar color1,
    string scalar color2,
    string scalar color3,
    string scalar color4,
    real scalar defer)
{
    real scalar i, op
    real colvector qsel
    string rowvector colors, sheets
    string scalar fname

    colors = (color1, color2, color3, color4)
    sheets = b.get_sheets()
    for (i = 1; i <= length(sheets); i++) {
        if (strlower(sheets[i]) == strlower(sheet)) {
            sheet = sheets[i]
            break
        }
    }

    // Multi-paragraph footnotes (" \ " separates paragraphs): one row per
    // paragraph, each carrying the footnote row's own styling.
    rules = _tt_xlsx_fn_paragraphs(b, rules)

    // Validate every rule before any is applied or queued, so an invalid
    // rule leaves nothing half-applied and nothing queued.
    for (i = 1; i <= rows(rules); i++) _tt_xlsx_style_validate(rules, i, colors)

    fname = defer ? b.query("filename") : ""
    qsel = J(rows(rules), 1, 0)
    for (i = 1; i <= rows(rules); i++) {
        op = rules[i, 1]
        if (defer & op != 12 & op != 13 & op != 14) qsel[i] = 1
        else _tt_xlsx_apply_one(b, sheet, rules[i, (1..9)], font, altfont, colors)
    }
    // one append for the whole batch: per-rule appends are quadratic in the
    // rule count, and zebra striping emits one rule per striped row
    if (any(qsel)) _tt_xlsx_pend_add(fname, sheet,
        select(rules[., (1..9)], qsel), (font, altfont, colors))
}

void _tt_xlsx_apply_one(
    class xl scalar b,
    string scalar sheet,
    real rowvector rule,
    string scalar font,
    string scalar altfont,
    string rowvector colors)
{
    real scalar op, r1, r2, c1, c2

    op = rule[1]
    r1 = rule[2]
    r2 = rule[3]
    c1 = rule[4]
    c2 = rule[5]

    if (op == 1) {
        b.set_font((r1, r2), (c1, c2),
            _tt_xlsx_style_font(rule[7], font, altfont), rule[6])
    }
    else if (op == 2) {
        b.set_font_bold((r1, r2), (c1, c2), _tt_xlsx_style_onoff(rule[7]))
    }
    else if (op == 3) {
        b.set_font_italic((r1, r2), (c1, c2), _tt_xlsx_style_onoff(rule[7]))
    }
    else if (op == 4) {
        b.set_text_wrap((r1, r2), (c1, c2), _tt_xlsx_style_onoff(rule[7]))
    }
    else if (op == 5) {
        b.set_horizontal_align((r1, r2), (c1, c2), _tt_xlsx_style_halign(rule[7]))
    }
    else if (op == 6) {
        b.set_vertical_align((r1, r2), (c1, c2), _tt_xlsx_style_valign(rule[7]))
    }
    else if (op == 7) {
        b.set_fill_pattern((r1, r2), (c1, c2), "solid",
            _tt_xlsx_style_rgb(rule[(7..9)], colors))
    }
    else if (op == 8) {
        b.set_top_border((r1, r2), (c1, c2), _tt_xlsx_style_border(rule[7]))
    }
    else if (op == 9) {
        b.set_bottom_border((r1, r2), (c1, c2), _tt_xlsx_style_border(rule[7]))
    }
    else if (op == 10) {
        b.set_left_border((r1, r2), (c1, c2), _tt_xlsx_style_border(rule[7]))
    }
    else if (op == 11) {
        b.set_right_border((r1, r2), (c1, c2), _tt_xlsx_style_border(rule[7]))
    }
    else if (op == 12) {
        b.set_row_height(r1, r2, rule[6])
    }
    else if (op == 13) {
        b.set_column_width(c1, c2, rule[6])
    }
    else if (op == 14) {
        b.set_sheet_merge(sheet, (r1, r2), (c1, c2))
    }
    else if (op == 15) {
        b.set_font((r1, r2), (c1, c2), font, rule[6],
            _tt_xlsx_style_rgb(rule[(7..9)], colors))
    }
}

// ---- deferred-style queue (option defer) --------------------------------
// Rules are queued in two Mata externals shared with
// _tabtools_xlsx_deferred_styles.ado.  Font names and colors are resolved
// here, where the style helpers live, so the XML pass never needs them.
// meta columns: file, sheet, font, altfont, color1..color4, font name, color
void _tt_xlsx_pend_add(string scalar file, string scalar sheet,
    real matrix rules, string rowvector strs)
{
    pointer(real matrix) scalar rp
    pointer(string matrix) scalar mp
    string matrix meta
    real scalar i, op

    if ((rp = findexternal("_tt_xp_rules")) == NULL) {
        rp = crexternal("_tt_xp_rules")
        *rp = J(0, 9, .)
    }
    if ((mp = findexternal("_tt_xp_meta")) == NULL) {
        mp = crexternal("_tt_xp_meta")
        *mp = J(0, 10, "")
    }
    meta = J(rows(rules), 1, (file, sheet, strs, "", ""))
    for (i = 1; i <= rows(rules); i++) {
        op = rules[i, 1]
        if (op == 1) meta[i, 9] = _tt_xlsx_style_font(rules[i, 7], strs[1], strs[2])
        if (op == 15) meta[i, 9] = strs[1]
        if (op == 7 | op == 15) meta[i, 10] = _tt_xlsx_style_rgb(rules[i, (7..9)], strs[(3..6)])
    }
    *rp = *rp \ rules
    *mp = *mp \ meta
}

string scalar _tt_xlsx_style_font(
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

string scalar _tt_xlsx_style_onoff(real scalar code)
{
    return(code == 0 ? "off" : "on")
}

string scalar _tt_xlsx_style_halign(real scalar code)
{
    if (code == 2) return("center")
    if (code == 3) return("right")
    return("left")
}

string scalar _tt_xlsx_style_valign(real scalar code)
{
    if (code == 2) return("center")
    if (code == 3) return("top")
    return("bottom")
}

string scalar _tt_xlsx_style_border(real scalar code)
{
    if (code == 2) return("medium")
    if (code == 3) return("thick")
    if (code == 4) return("none")
    return("thin")
}

string scalar _tt_xlsx_style_rgb(real rowvector rgb, string rowvector colors)
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

void _tt_xlsx_style_validate(
    real matrix rules,
    real scalar row,
    string rowvector colors)
{
    real scalar op

    op = rules[row, 1]
    _tt_xlsx_style_validate_code(op, row, "operation", 1, 15)

    if (op == 12) {
        _tt_xlsx_style_validate_range(rules[row, 2], rules[row, 3],
            row, "row")
        _tt_xlsx_style_validate_positive(rules[row, 6], row, "height")
    }
    else if (op == 13) {
        _tt_xlsx_style_validate_range(rules[row, 4], rules[row, 5],
            row, "column")
        _tt_xlsx_style_validate_positive(rules[row, 6], row, "width")
    }
    else {
        _tt_xlsx_style_validate_range(rules[row, 2], rules[row, 3],
            row, "row")
        _tt_xlsx_style_validate_range(rules[row, 4], rules[row, 5],
            row, "column")

        if (op == 1) {
            _tt_xlsx_style_validate_positive(rules[row, 6], row, "font size")
            _tt_xlsx_style_validate_code(rules[row, 7], row, "font code", -1, 5)
        }
        else if (op >= 2 & op <= 4) {
            _tt_xlsx_style_validate_code(rules[row, 7], row, "on/off code", 0, 1)
        }
        else if (op == 5) {
            _tt_xlsx_style_validate_code(rules[row, 7], row,
                "horizontal alignment code", 1, 3)
        }
        else if (op == 6) {
            _tt_xlsx_style_validate_code(rules[row, 7], row,
                "vertical alignment code", 1, 3)
        }
        else if (op == 7) {
            _tt_xlsx_style_validate_rgb(rules[row, (7..9)], row, colors)
        }
        else if (op >= 8 & op <= 11) {
            _tt_xlsx_style_validate_code(rules[row, 7], row, "border code", 1, 4)
        }
        else if (op == 15) {
            _tt_xlsx_style_validate_positive(rules[row, 6], row, "font size")
            _tt_xlsx_style_validate_rgb(rules[row, (7..9)], row, colors)
        }
    }
}

void _tt_xlsx_style_validate_range(
    real scalar first,
    real scalar last,
    real scalar row,
    string scalar name)
{
    if (first >= . | first != floor(first) | first < 1) {
        _tt_xlsx_style_error(row, name + " start must be a positive integer")
    }
    if (last >= . | last != floor(last) | last < 1) {
        _tt_xlsx_style_error(row, name + " end must be a positive integer")
    }
    if (last < first) {
        _tt_xlsx_style_error(row, name + " end must be >= start")
    }
}

void _tt_xlsx_style_validate_code(
    real scalar code,
    real scalar row,
    string scalar name,
    real scalar minval,
    real scalar maxval)
{
    if (code >= . | code != floor(code) | code < minval | code > maxval) {
        _tt_xlsx_style_error(row, name + " out of range")
    }
}

void _tt_xlsx_style_validate_positive(
    real scalar value,
    real scalar row,
    string scalar name)
{
    if (value >= . | value <= 0) {
        _tt_xlsx_style_error(row, name + " must be positive")
    }
}

void _tt_xlsx_style_validate_rgb(
    real rowvector rgb,
    real scalar row,
    string rowvector colors)
{
    real scalar i, color_code

    if (rgb[1] < 0) {
        color_code = -rgb[1]
        if (color_code != floor(color_code) | color_code < 1 | color_code > 4) {
            _tt_xlsx_style_error(row, "color alias code out of range")
        }
        if (colors[color_code] == "") {
            _tt_xlsx_style_error(row, "color alias option is empty")
        }
        return
    }

    for (i = 1; i <= 3; i++) {
        if (rgb[i] >= . | rgb[i] != floor(rgb[i]) | rgb[i] < 0 | rgb[i] > 255) {
            _tt_xlsx_style_error(row, "RGB values must be integers in [0,255]")
        }
    }
}

void _tt_xlsx_style_error(real scalar row, string scalar message)
{
    errprintf("invalid style rule in row " +
        strtrim(strofreal(row, "%9.0f")) + ": " + message + "\n")
    _error(198)
}


// Split footnote text into paragraphs on the literal token " \ " (space,
// backslash, space). Text without the token is returned unchanged, so a
// one-paragraph footnote is written exactly as before; otherwise each piece
// is trimmed and empty pieces are dropped.
string colvector _tt_xlsx_fn_paras(string scalar s)
{
    string colvector out
    string scalar rest, piece
    real scalar pos

    if (!strpos(s, " " + char(92) + " ")) return(s)
    out = J(0, 1, "")
    rest = s
    while ((pos = strpos(rest, " " + char(92) + " ")) > 0) {
        piece = strtrim(substr(rest, 1, pos - 1))
        if (piece != "") out = out \ piece
        rest = substr(rest, pos + 3, .)
    }
    piece = strtrim(rest)
    if (piece != "") out = out \ piece
    if (rows(out) == 0) out = ""
    return(out)
}

// The footnote row of every tabtools sheet is the bottom styled row, with
// its text in column B and an italic rule (op 3, on) starting at column B.
// When that cell holds paragraph separators, write one paragraph per row
// and copy every rule that styles the footnote row (except top borders and
// column widths) onto the added rows. Any other sheet is returned as is.
real matrix _tt_xlsx_fn_paragraphs(class xl scalar b, real matrix rules)
{
    real scalar R, i, j, n, isfn
    real matrix add, src
    string colvector paras
    string matrix cell

    R = 0
    for (i = 1; i <= rows(rules); i++) {
        if (rules[i, 1] != 13 & rules[i, 3] < . & rules[i, 3] > R) R = rules[i, 3]
    }
    if (R < 2) return(rules)
    isfn = 0
    for (i = 1; i <= rows(rules); i++) {
        if (rules[i, 1] == 3 & rules[i, 2] == R & rules[i, 3] == R &
            rules[i, 4] == 2 & rules[i, 7] == 1) isfn = 1
    }
    if (!isfn) return(rules)
    cell = b.get_string(R, 2)
    if (rows(cell) != 1 | cols(cell) != 1) return(rules)
    if (!strpos(cell[1, 1], " " + char(92) + " ")) return(rules)
    paras = _tt_xlsx_fn_paras(cell[1, 1])
    n = rows(paras)
    for (j = 1; j <= n; j++) b.put_string(R + j - 1, 2, paras[j])
    if (n < 2) return(rules)
    src = J(0, cols(rules), .)
    for (i = 1; i <= rows(rules); i++) {
        if (rules[i, 1] == 13 | rules[i, 1] == 8) continue
        if (rules[i, 2] <= R & rules[i, 3] >= R) src = src \ rules[i, .]
    }
    add = J(0, cols(rules), .)
    for (j = 2; j <= n; j++) {
        for (i = 1; i <= rows(src); i++) {
            add = add \ src[i, .]
            add[rows(add), 2] = R + j - 1
            add[rows(add), 3] = R + j - 1
        }
    }
    return(rules \ add)
}
end
mata: mata set matastrict `_tt_ms0'
