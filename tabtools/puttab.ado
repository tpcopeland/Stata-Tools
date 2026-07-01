*! puttab Version 1.9.0  2026/07/01
*! Style an in-memory table (current data, a frame, or a matrix) as one Excel sheet
*! Author: Timothy P Copeland, Karolinska Institutet
*! Program class: rclass

/*
DESCRIPTION:
    puttab is the first-mile styled-block producer for the tabtools suite. It
    takes a table that already lives in memory -- the current dataset, a named
    frame, or a Stata matrix (e(b), r(table), a collapse/tabulate result) -- and
    writes it as one house-styled Excel sheet with the shared tabtools geometry:
    a left-justified title in cell A1, a thin spacer column A so the table body
    is anchored at B2, a header rule, optional header shading and zebra striping,
    column widths, borders, and an italic footnote.

    It complements the rest of the suite at the raw-input end: desctab needs a
    collect: table, stacktab needs blocks already exported as sheets. puttab
    styles a raw frame/matrix/dataset, so the natural pipeline is

        emit styled blocks with puttab  ->  assemble them with stacktab

SOURCE (exactly one):
    varlist        columns of the current dataset (explicit; required for the
                   current-data source)
    frame(name)    a named frame (optionally subset by varlist)
    matrix(name)   a Stata matrix (row/column names become labels/headers)
*/

program define puttab, rclass
    version 17.0
    local _orig_varabbrev = c(varabbrev)
    set varabbrev off
    local _restore_needed = 0
    local _book_open = 0
    capture noisily {

        capture putexcel close

        * Auto-load shared helper programs
        capture _tabtools_helpers_ready
        if _rc {
            capture findfile _tabtools_common.ado
            if _rc == 0 {
                run "`r(fn)'"
                capture _tabtools_helpers_ready
                if _rc {
                    display as error "_tabtools_common.ado failed to load fully; reinstall tabtools"
                    exit 111
                }
            }
            else {
                display as error "_tabtools_common.ado not found; reinstall tabtools"
                exit 111
            }
        }
        _tabtools_require_helpers

        syntax [anything(name=vlist)] [if] [in] [using/] , ///
            [ FRAme(string) Matrix(name) ///
              SHeet(string) ///
              TItle(string) FOOTnote(string) ///
              THEme(string) BORDERstyle(string) ///
              HEADERColor(string) ZEBRAColor(string) ZEBra HEADERShade ///
              DIGits(integer -1) VARLabels NOHeader ///
              CSV(string) MARKdown(string) MDAPPend open ]

        * ----- output file validation -----
        local _has_using = `"`using'"' != ""
        local _has_markdown = `"`markdown'"' != ""
        if !`_has_using' & !`_has_markdown' {
            noisily display as error "specify using or markdown()"
            exit 198
        }
        if "`open'" != "" & !`_has_using' {
            noisily display as error "open requires using"
            exit 198
        }
        if `_has_using' {
            if !strmatch(lower(`"`using'"'), "*.xlsx") {
                noisily display as error "using file must have a .xlsx extension"
                exit 198
            }
            _tabtools_validate_path `"`using'"' "using"
        }
        if "`sheet'" == "" local sheet "Table"
        if `_has_using' _tabtools_validate_sheet "`sheet'" "sheet()"

        local csv = strtrim(subinstr(`"`csv'"', char(34), "", .))
        if `"`csv'"' != "" {
            if !strmatch(lower(`"`csv'"'), "*.csv") {
                noisily display as error "csv() must have a .csv extension"
                exit 198
            }
            _tabtools_validate_path `"`csv'"' "csv()"
        }
        if "`mdappend'" != "" & !`_has_markdown' {
            noisily display as error "mdappend requires markdown()"
            exit 198
        }
        if `_has_markdown' {
            _tabtools_validate_path `"`markdown'"' "markdown()"
            local _md_lower = lower(`"`markdown'"')
            if !(strmatch(`"`_md_lower'"', "*.md") | ///
                 strmatch(`"`_md_lower'"', "*.markdown") | ///
                 strmatch(`"`_md_lower'"', "*.qmd") | ///
                 strmatch(`"`_md_lower'"', "*.rmd")) {
                noisily display as error "markdown() must specify a .md, .markdown, .qmd, or .rmd file"
                exit 198
            }
        }

        * ----- digits -----
        if `digits' == -1 {
            if "$TABTOOLS_DIGITS" != "" local digits = $TABTOOLS_DIGITS
            else local digits = 2
        }
        if `digits' < 0 | `digits' > 6 {
            noisily display as error "digits() must be between 0 and 6"
            exit 198
        }

        * ----- shared formatting / colors -----
        _tabtools_resolve_format, theme(`theme') borderstyle(`borderstyle') ///
            headershade(`headershade') zebra(`zebra')
        _tabtools_resolve_colors, headercolor(`"`headercolor'"') ///
            zebracolor(`"`zebracolor'"')

        * ----- resolve source (validate BEFORE preserve) -----
        local _nsrc = 0
        if `"`matrix'"' != "" local ++_nsrc
        if `"`frame'"'  != "" local ++_nsrc
        if `_nsrc' > 1 {
            noisily display as error "matrix() and frame() may not be combined"
            exit 198
        }

        local _hasifin = (`"`if'"' != "" | `"`in'"' != "")

        local _src ""
        local _framename ""
        if `"`matrix'"' != "" {
            if `"`vlist'"' != "" {
                noisily display as error "a varlist is not allowed with matrix(); the matrix is the source"
                exit 198
            }
            if `_hasifin' {
                noisily display as error "if/in is not allowed with a matrix() source"
                exit 198
            }
            confirm matrix `matrix'
            if rowsof(`matrix') < 1 | colsof(`matrix') < 1 {
                noisily display as error "matrix(`matrix') is empty"
                exit 198
            }
            local _src "matrix"
        }
        else if `"`frame'"' != "" {
            local _framename = strtrim(subinstr(`"`frame'"', char(34), "", .))
            confirm name `_framename'
            capture confirm frame `_framename'
            if _rc {
                noisily display as error "frame `_framename' not found"
                exit 111
            }
            local _src "frame"
        }
        else {
            if `"`vlist'"' == "" {
                noisily display as error "specify a varlist, frame(), or matrix() as the table source"
                exit 198
            }
            * Validate the requested varlist against the current data now,
            * before preserve, so a typo fails without a restore.
            unab _keepvars : `vlist'
            local _src "data"
        }

        * ===== build the in-memory string table (c1..cK) =====
        preserve
        local _restore_needed = 1

        local _titlerows = (`"`title'"' != "")
        local _headerrows = ("`noheader'" == "")
        local _uselbl = ("`varlabels'" != "")

        if "`_src'" == "matrix" {
            clear
            mata: _puttab_matrix_table("`matrix'", `digits', `_titlerows', `_headerrows')
        }
        else {
            if "`_src'" == "frame" {
                tempfile _srcdata
                quietly frame `_framename': save `"`_srcdata'"', replace
                use `"`_srcdata'"', clear
            }
            * Row subset (if/in) before column subset, so the if/in condition may
            * reference columns that the varlist drops.
            if `_hasifin' {
                marksample _touse, novarlist
                quietly keep if `_touse'
                quietly drop `_touse'
            }
            if `"`vlist'"' != "" {
                unab _keepvars : `vlist'
                keep `_keepvars'
            }
            quietly ds
            local _srcvars `r(varlist)'
            if "`_srcvars'" == "" {
                noisily display as error "source contains no variables to export"
                exit 111
            }
            quietly count
            if r(N) == 0 {
                noisily display as error "source contains no observations to export"
                exit 2000
            }
            mata: _puttab_data_table("`_srcvars'", `digits', `_titlerows', ///
                `_headerrows', `_uselbl')
        }

        local K = c(k)
        if `K' < 1 {
            noisily display as error "no columns produced for export"
            exit 198
        }

        * Title text into the (blank) first row, first column
        if `_titlerows' quietly replace c1 = `"`title'"' in 1

        local _header_row = cond(`_headerrows', `_titlerows' + 1, 0)
        local _data_start = `_titlerows' + `_headerrows' + 1
        local _last_data_row = _N
        if `_last_data_row' < `_data_start' {
            noisily display as error "source produced no data rows"
            exit 2000
        }
        local _ndatarows = `_last_data_row' - `_data_start' + 1

        * Footnote as a trailing row
        local _foot_row = 0
        if `"`footnote'"' != "" {
            local _foot_row = _N + 1
            quietly set obs `_foot_row'
            quietly replace c1 = `"`footnote'"' in `_foot_row'
        }
        local _total_rows = _N

        * ----- optional CSV mirror of the assembled table -----
        if `"`csv'"' != "" {
            _tabtools_csv_write using `"`csv'"'
            capture confirm file `"`csv'"'
            if _rc {
                noisily display as error "CSV export completed but file was not created"
                exit 601
            }
        }

        local _ret_markdown ""
        local _ret_markdown_rows .
        local _ret_markdown_cols .
        if `_has_markdown' {
            local _mdappend_opt ""
            if "`mdappend'" != "" local _mdappend_opt "append"
            local _md_novarnames ""
            if "`noheader'" != "" local _md_novarnames "novarnames"
            capture noisily _tabtools_markdown_write using `"`markdown'"', ///
                `_mdappend_opt' headerstart(`_header_row') datastart(`_data_start') ///
                title(`"`title'"') footnote(`"`footnote'"') `_md_novarnames'
            if _rc {
                local _md_rc = _rc
                noisily display as error "Failed to export Markdown to `markdown'"
                exit `_md_rc'
            }
            local _ret_markdown `"`markdown'"'
            local _ret_markdown_rows = r(n_rows)
            local _ret_markdown_cols = r(n_cols)
            noisily display as text "Markdown exported to `markdown'"
        }

        * ===== Excel sheet geometry (shared house style with regtab/table1_tc) =====
        * The CSV/Markdown mirrors above use the compact in-memory table as built.
        * The Excel sheet adds the shared layout: a thin spacer column A, the title
        * spanning row 1 (cell A1, left-justified), and the table body anchored at
        * B2. Apply it to the (already-CSV/Markdown-exported) data; the dataset is
        * discarded by the restore at the end either way.
        if `_has_using' {

            tempvar _spacer _roworder

            * Reserve a blank title row when no title was supplied, so the body
            * always begins on row 2 (table top-left cell = B2).
            if !`_titlerows' {
                quietly gen long `_roworder' = _n
                quietly set obs `=_N + 1'
                quietly replace `_roworder' = 0 in L
                sort `_roworder'
                drop `_roworder'
            }
            * Prepend the spacer column (Excel column A) and carry the title text,
            * if any, into A1 so it shows from the left of the merged title row.
            local _c1type : type c1
            quietly gen `_c1type' `_spacer' = ""
            quietly replace `_spacer' = c1 in 1
            quietly replace c1 = "" in 1
            order `_spacer', first

            * Excel coordinates: content column j -> Excel column j+1; the title
            * occupies row 1, and the body shifts down by one when a title row was
            * inserted above (`_x_roff' = 1 when no title was supplied).
            local _xK = `K' + 1
            local _x_roff = 1 - `_titlerows'
            local _x_header_row = cond(`_headerrows', `_header_row' + `_x_roff', 0)
            local _x_data_start = `_data_start' + `_x_roff'
            local _x_last_data  = `_last_data_row' + `_x_roff'
            local _x_total_rows = `_total_rows' + `_x_roff'
            local _x_foot_row   = cond(`_foot_row' > 0, `_foot_row' + `_x_roff', 0)

            * ===== border code (thin=1, medium=2, thick=3, none=4) =====
            local _hbc = 1
            if "`_hborder'" == "medium" local _hbc = 2
            if "`_hborder'" == "thick"  local _hbc = 3
            if "`_hborder'" == "none"   local _hbc = 4

            * ===== spacer column width + content widths (header + data rows) =====
            tempname _rules
            matrix `_rules' = (13, 1, 1, 1, 1, 1, 0, 0, 0)
            forvalues j = 1/`K' {
                tempvar _len
                quietly gen long `_len' = length(c`j')
                quietly summarize `_len' ///
                    if c`j' != "" & inrange(_n, 2, `_x_last_data'), meanonly
                local _w = cond(r(N) > 0, ceil(r(max) * 0.95) + 2, 10)
                if `j' == 1 {
                    if `_w' < 12 local _w = 12
                    if `_w' > 50 local _w = 50
                }
                else {
                    if `_w' < 8  local _w = 8
                    if `_w' > 32 local _w = 32
                }
                drop `_len'
                local _xcol = `j' + 1
                matrix `_rules' = `_rules' \ (13, 1, 1, `_xcol', `_xcol', `_w', 0, 0, 0)
            }

            * ===== base font, wrap, vertical centering, left alignment =====
            matrix `_rules' = `_rules' \ ///
                (1, 1, `_x_total_rows', 1, `_xK', `_fontsize', 1, 0, 0) \ ///
                (4, 1, `_x_total_rows', 1, `_xK', 0, 1, 0, 0) \ ///
                (6, 1, `_x_total_rows', 1, `_xK', 0, 2, 0, 0) \ ///
                (5, 1, `_x_total_rows', 1, `_xK', 0, 1, 0, 0)

            * ===== title row (row 1, merged A1 across the width, left-justified) =====
            matrix `_rules' = `_rules' \ ///
                (12, 1, 1, 1, 1, 30, 0, 0, 0) \ ///
                (14, 1, 1, 1, `_xK', 0, 0, 0, 0) \ ///
                (1, 1, 1, 1, `_xK', `=`_fontsize' + 2', 1, 0, 0) \ ///
                (2, 1, 1, 1, `_xK', 0, 1, 0, 0) \ ///
                (4, 1, 1, 1, 1, 0, 1, 0, 0) \ ///
                (5, 1, 1, 1, `_xK', 0, 1, 0, 0) \ ///
                (6, 1, 1, 1, 1, 0, 2, 0, 0)

            * ===== header row (or top rule above first data row); columns B onward =====
            if `_headerrows' {
                matrix `_rules' = `_rules' \ ///
                    (2, `_x_header_row', `_x_header_row', 2, `_xK', 0, 1, 0, 0) \ ///
                    (5, `_x_header_row', `_x_header_row', 2, `_xK', 0, 2, 0, 0) \ ///
                    (8, `_x_header_row', `_x_header_row', 2, `_xK', 0, `_hbc', 0, 0) \ ///
                    (9, `_x_header_row', `_x_header_row', 2, `_xK', 0, `_hbc', 0, 0)
                if "`headershade'" != "" {
                    matrix `_rules' = `_rules' \ ///
                        (7, `_x_header_row', `_x_header_row', 2, `_xK', 0, -1, 0, 0)
                }
            }
            else {
                matrix `_rules' = `_rules' \ ///
                    (8, `_x_data_start', `_x_data_start', 2, `_xK', 0, `_hbc', 0, 0)
            }

            * ===== center data columns; the first (label) column stays left =====
            if `K' >= 2 {
                matrix `_rules' = `_rules' \ ///
                    (5, `_x_data_start', `_x_last_data', 3, `_xK', 0, 2, 0, 0)
            }

            * ===== bottom rule below the last data row =====
            matrix `_rules' = `_rules' \ ///
                (9, `_x_last_data', `_x_last_data', 2, `_xK', 0, `_hbc', 0, 0)

            * ===== zebra striping over data rows =====
            if "`zebra'" != "" {
                forvalues _zr = `=`_x_data_start' + 1'(2)`_x_last_data' {
                    matrix `_rules' = `_rules' \ ///
                        (7, `_zr', `_zr', 2, `_xK', 0, -2, 0, 0)
                }
            }

            * ===== footnote row (column B onward, smaller italic) =====
            if `_x_foot_row' > 0 {
                local _fn_size = max(`_fontsize' - 2, 6)
                matrix `_rules' = `_rules' \ ///
                    (14, `_x_foot_row', `_x_foot_row', 2, `_xK', 0, 0, 0, 0) \ ///
                    (1, `_x_foot_row', `_x_foot_row', 2, `_xK', `_fn_size', 1, 0, 0) \ ///
                    (3, `_x_foot_row', `_x_foot_row', 2, `_xK', 0, 1, 0, 0) \ ///
                    (5, `_x_foot_row', `_x_foot_row', 2, `_xK', 0, 1, 0, 0)
            }

            * ===== write the sheet and apply the styling =====
            _tabtools_xlsx_write using `"`using'"', sheet(`"`sheet'"') book(b)
            local _book_open = 1

            _tabtools_xlsx_apply_styles, book(b) sheet(`"`sheet'"') ///
                rules(`_rules') font("`_font'") ///
                color1("`_headercolor'") color2("`_zebracolor'")

            mata: b.close_book()
            local _book_open = 0
            capture mata: mata drop b

            capture confirm file `"`using'"'
            if _rc {
                noisily display as error "export command succeeded but file `using' was not found"
                exit 601
            }
        }

        * Stash results to post after cleanup
        local _ret_rows    = `_total_rows'
        local _ret_cols    = `K'
        local _ret_data    = `_ndatarows'
        local _ret_sheet   `"`sheet'"'
        local _ret_file    `"`using'"'
        local _ret_source  "`_src'"
        local _ret_csv     `"`csv'"'

        if `_has_using' {
            noisily display as text "puttab: wrote " as result "`_ndatarows'" ///
                as text " data rows x " as result "`K'" as text " cols (" ///
                as result "`_src'" as text " source) to sheet " ///
                as result `"`sheet'"' as text " in " as result `"`using'"'
        }
    }
    local rc = _rc
    if `_book_open' {
        capture mata: b.close_book()
    }
    capture mata: mata drop b
    if `_restore_needed' capture restore
    set varabbrev `_orig_varabbrev'
    if `rc' {
        if `rc' == 603 | `rc' == 608 | `rc' == 610 {
            noisily display as error "Hint: ensure the xlsx file is not open in another application"
        }
        exit `rc'
    }

    return scalar n_rows    = `_ret_rows'
    return scalar n_cols    = `_ret_cols'
    return scalar n_datarows = `_ret_data'
    return local  source    "`_ret_source'"
    if `"`_ret_file'"' != "" {
        return local  sheet     `"`_ret_sheet'"'
        return local  file      `"`_ret_file'"'
    }
    if `"`_ret_csv'"' != "" return local csv `"`_ret_csv'"'
    if `"`_ret_markdown'"' != "" {
        return local markdown `"`_ret_markdown'"'
        return scalar markdown_rows = `_ret_markdown_rows'
        return scalar markdown_cols = `_ret_markdown_cols'
    }

    if "`open'" != "" & `"`_ret_file'"' != "" _tabtools_open_file `"`_ret_file'"'
end


* ============================================================================
* Mata: build the c1..cK string table from a dataset or a matrix
* ============================================================================
version 17.0
capture mata: mata drop _puttab_data_table()
capture mata: mata drop _puttab_matrix_table()
capture mata: mata drop _puttab_fmt_num()
capture mata: mata drop _puttab_stripe_names()
capture mata: mata drop _puttab_emit_table()

mata:
mata set matastrict on

// Format a numeric column to strings, honouring value labels first, then
// integer-vs-fractional display at the requested number of digits.
string colvector _puttab_fmt_num(
    real colvector v,
    real scalar digits,
    string scalar vlabel)
{
    string colvector out, mapped
    real scalar i, n, allint
    string scalar ifmt, ffmt

    n = rows(v)
    out = J(n, 1, "")

    mapped = J(n, 1, "")
    if (vlabel != "") {
        if (st_vlexists(vlabel)) {
            mapped = st_vlmap(vlabel, v)
        }
    }

    allint = 1
    for (i = 1; i <= n; i++) {
        if (v[i] < . & v[i] != floor(v[i])) {
            allint = 0
            break
        }
    }
    ifmt = "%32.0f"
    ffmt = "%32." + strofreal(digits, "%9.0f") + "f"

    for (i = 1; i <= n; i++) {
        if (mapped[i] != "") {
            out[i] = mapped[i]
        }
        else if (v[i] < .) {
            out[i] = strtrim(strofreal(v[i], allint ? ifmt : ffmt))
        }
    }
    return(out)
}

// Combine a matrix stripe (eqname, name) into display labels.
string colvector _puttab_stripe_names(string matrix stripe)
{
    string colvector out
    real scalar i, n
    string scalar eq

    n = rows(stripe)
    out = J(n, 1, "")
    for (i = 1; i <= n; i++) {
        eq = stripe[i, 1]
        if (eq != "" & eq != "_") {
            out[i] = eq + ":" + stripe[i, 2]
        }
        else {
            out[i] = stripe[i, 2]
        }
    }
    return(out)
}

// Replace the current (empty) dataset with string variables c1..cK holding the
// assembled table `out'. Row `header_at' (0 = none) is the header row.
void _puttab_emit_table(string matrix out)
{
    real scalar j, i, K, N, maxlen
    string scalar vname, vtype

    N = rows(out)
    K = cols(out)

    stata("quietly drop _all")
    for (j = 1; j <= K; j++) {
        maxlen = 0
        for (i = 1; i <= N; i++) {
            if (strlen(out[i, j]) > maxlen) maxlen = strlen(out[i, j])
        }
        if (maxlen < 1) maxlen = 1
        if (maxlen <= 2045) vtype = "str" + strofreal(maxlen, "%9.0f")
        else vtype = "strL"
        vname = "c" + strofreal(j, "%9.0f")
        (void) st_addvar(vtype, vname)
    }
    st_addobs(N)
    for (j = 1; j <= K; j++) {
        st_sstore(., "c" + strofreal(j, "%9.0f"), out[, j])
    }
}

// Build the table from the current dataset's variables.
void _puttab_data_table(
    string scalar varlist,
    real scalar digits,
    real scalar titlerows,
    real scalar headerrows,
    real scalar usevarlabels)
{
    string rowvector vars
    string matrix out
    string colvector scol
    real colvector ncol
    real scalar j, K, N, total, hdr, datatop
    string scalar lbl, hdrtext

    vars = tokens(varlist)
    K = cols(vars)
    N = st_nobs()
    total = titlerows + headerrows + N
    out = J(total, K, "")

    hdr = titlerows + 1            // header row index (if headerrows)
    datatop = titlerows + headerrows + 1

    for (j = 1; j <= K; j++) {
        // header text
        if (headerrows) {
            hdrtext = vars[j]
            if (usevarlabels) {
                lbl = st_varlabel(vars[j])
                if (lbl != "") hdrtext = lbl
            }
            out[hdr, j] = hdrtext
        }
        // body
        if (st_isstrvar(vars[j])) {
            scol = st_sdata(., vars[j])
        }
        else {
            ncol = st_data(., vars[j])
            scol = _puttab_fmt_num(ncol, digits, st_varvaluelabel(vars[j]))
        }
        out[(datatop..total), j] = scol
    }

    _puttab_emit_table(out)
}

// Build the table from a Stata matrix (row/col names -> labels/header).
void _puttab_matrix_table(
    string scalar matname,
    real scalar digits,
    real scalar titlerows,
    real scalar headerrows)
{
    real matrix M
    string matrix out
    string colvector rnames
    string colvector cnames
    real scalar i, j, R, C, Kout, total, hdr, datatop

    M = st_matrix(matname)
    R = rows(M)
    C = cols(M)
    rnames = _puttab_stripe_names(st_matrixrowstripe(matname))
    cnames = _puttab_stripe_names(st_matrixcolstripe(matname))

    Kout = C + 1
    total = titlerows + headerrows + R
    out = J(total, Kout, "")

    hdr = titlerows + 1
    datatop = titlerows + headerrows + 1

    if (headerrows) {
        for (j = 1; j <= C; j++) {
            out[hdr, j + 1] = cnames[j]
        }
    }
    for (i = 1; i <= R; i++) {
        out[datatop + i - 1, 1] = rnames[i]
    }
    // Format column by column so decimals are consistent within each column.
    for (j = 1; j <= C; j++) {
        out[(datatop..(datatop + R - 1)), j + 1] =
            _puttab_fmt_num(M[., j], digits, "")
    }

    _puttab_emit_table(out)
}

end
