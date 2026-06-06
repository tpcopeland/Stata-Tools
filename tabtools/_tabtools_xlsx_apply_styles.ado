*! _tabtools_xlsx_apply_styles Version 1.5.0  2026/06/06
*! Apply compact Excel style rules to an open Mata xl() workbook
*! Author: Timothy P Copeland, Karolinska Institutet
*! Program class: rclass

program define _tabtools_xlsx_apply_styles, rclass
    version 16.0
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

        mata: _tt_xlsx_apply_styles(`book', `"`sheet'"', st_matrix("`rules'"), ///
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

version 16.0
capture mata: mata drop _tt_xlsx_apply_styles()
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
    string scalar color4)
{
    real scalar i, op, r1, r2, c1, c2
    string rowvector colors

    colors = (color1, color2, color3, color4)

    for (i = 1; i <= rows(rules); i++) {
        _tt_xlsx_style_validate(rules, i, colors)

        op = rules[i, 1]
        r1 = rules[i, 2]
        r2 = rules[i, 3]
        c1 = rules[i, 4]
        c2 = rules[i, 5]

        if (op == 1) {
            b.set_font((r1, r2), (c1, c2),
                _tt_xlsx_style_font(rules[i, 7], font, altfont), rules[i, 6])
        }
        else if (op == 2) {
            b.set_font_bold((r1, r2), (c1, c2),
                _tt_xlsx_style_onoff(rules[i, 7]))
        }
        else if (op == 3) {
            b.set_font_italic((r1, r2), (c1, c2),
                _tt_xlsx_style_onoff(rules[i, 7]))
        }
        else if (op == 4) {
            b.set_text_wrap((r1, r2), (c1, c2),
                _tt_xlsx_style_onoff(rules[i, 7]))
        }
        else if (op == 5) {
            b.set_horizontal_align((r1, r2), (c1, c2),
                _tt_xlsx_style_halign(rules[i, 7]))
        }
        else if (op == 6) {
            b.set_vertical_align((r1, r2), (c1, c2),
                _tt_xlsx_style_valign(rules[i, 7]))
        }
        else if (op == 7) {
            b.set_fill_pattern((r1, r2), (c1, c2), "solid",
                _tt_xlsx_style_rgb(rules[i, (7..9)], colors))
        }
        else if (op == 8) {
            b.set_top_border((r1, r2), (c1, c2),
                _tt_xlsx_style_border(rules[i, 7]))
        }
        else if (op == 9) {
            b.set_bottom_border((r1, r2), (c1, c2),
                _tt_xlsx_style_border(rules[i, 7]))
        }
        else if (op == 10) {
            b.set_left_border((r1, r2), (c1, c2),
                _tt_xlsx_style_border(rules[i, 7]))
        }
        else if (op == 11) {
            b.set_right_border((r1, r2), (c1, c2),
                _tt_xlsx_style_border(rules[i, 7]))
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
                _tt_xlsx_style_rgb(rules[i, (7..9)], colors))
        }
    }
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

end
