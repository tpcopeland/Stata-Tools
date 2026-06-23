*! stacktab Version 1.8.4  2026/06/23
*! Assemble multi-sheet composite Excel tables from source blocks
*! Author: Timothy P Copeland, Karolinska Institutet
*! Program class: rclass

/*
Imports row/column blocks from specified sheets in a source workbook,
stacks them, applies column-merge and label transforms, then exports the
composite with tabtools-style Excel geometry and formatting.

Syntax:
  stacktab using OUTBOOK.xlsx,
    blocks(BLOCKSPEC) sheet("Sheet Name")
    [layout(vstack|hstack)] [title(STRING)] [note(STRING)|footnote(STRING)]
    [columnmerge(MERGESPEC)] [style(STYLESPEC)] [borders(BORDERSPEC)]
    [frame(NAME[, replace])] [csv(FILE)] [append|sheetreplace]
*/

program define stacktab, rclass
    version 16.0
    local _vao = c(varabbrev)
    set varabbrev off
    local _restore_needed = 0
    capture noisily {

        syntax using/ , ///
            BLocks(string asis) ///
            SHeet(string) ///
            [LAYout(string) ///
             TItle(string asis) ///
             NOte(string asis) ///
             FOOTnote(string asis) ///
             COLumnmerge(string asis) ///
             STyle(string asis) ///
             BOrders(string asis) ///
             SPacing(integer 0) ///
             CSV(string asis) ///
             MARKdown(string asis) ///
             MDAPPend ///
             FRAme(string asis) ///
             DISplay ///
             APPend ///
             SHEetreplace]

        capture _tabtools_helpers_ready
        if _rc {
            capture findfile _tabtools_common.ado
            if _rc == 0 {
                run "`r(fn)'"
            }
        }
        _tabtools_require_helpers

        if !strmatch(lower(`"`using'"'), "*.xlsx") {
            display as error "using file must have a .xlsx extension"
            exit 198
        }
        _tabtools_validate_path `"`using'"' "using"
        confirm file `"`using'"'
        _tabtools_validate_sheet `"`sheet'"' "sheet()"

        if "`layout'" == "" local layout "vstack"
        local layout = lower("`layout'")
        if !inlist("`layout'", "vstack", "hstack") {
            display as error "layout() must be vstack or hstack"
            exit 198
        }
        if "`append'" != "" & "`sheetreplace'" != "" {
            display as error "append and sheetreplace may not be combined"
            exit 198
        }
        if `"`note'"' != "" & `"`footnote'"' != "" {
            display as error "note() and footnote() may not be combined"
            exit 198
        }
        if `"`note'"' == "" & `"`footnote'"' != "" {
            local note `"`footnote'"'
        }
        if `spacing' < 0 {
            display as error "spacing() must be nonnegative"
            exit 198
        }
        local q = char(34)
        foreach opt in title note csv markdown {
            if substr(`"``opt''"', 1, 1) == `"`q'"' & ///
                substr(`"``opt''"', -1, 1) == `"`q'"' {
                local `opt' = substr(`"``opt''"', 2, strlen(`"``opt''"') - 2)
            }
        }
        local csv = subinstr(`"`csv'"', `"""', "", .)
        local csv = subinstr(`"`csv'"', char(96), "", .)
        local csv = subinstr(`"`csv'"', char(39), "", .)
        if `"`csv'"' != "" & !strmatch(lower(`"`csv'"'), "*.csv") {
            display as error "csv() must have .csv extension"
            exit 198
        }
        if `"`csv'"' != "" _tabtools_validate_path `"`csv'"' "csv()"
        if "`mdappend'" != "" & `"`markdown'"' == "" {
            display as error "mdappend requires markdown()"
            exit 198
        }
        if `"`markdown'"' != "" {
            _tabtools_validate_path `"`markdown'"' "markdown()"
            local _md_lower = lower(`"`markdown'"')
            if !(strmatch(`"`_md_lower'"', "*.md") | ///
                 strmatch(`"`_md_lower'"', "*.markdown") | ///
                 strmatch(`"`_md_lower'"', "*.qmd") | ///
                 strmatch(`"`_md_lower'"', "*.rmd")) {
                display as error "markdown() must specify a .md, .markdown, .qmd, or .rmd file"
                exit 198
            }
        }

        * ================================================================
        * PARSE BLOCKSPEC: split on \ and parse each block
        * ================================================================
        local n_blocks = 0
        local remaining `"`blocks'"'

        while `"`remaining'"' != "" {
            * Extract one block (delimited by \ outside parentheses)
            local piece ""
            local depth = 0
            local n_chars = strlen(`"`remaining'"')
            local found_sep = 0
            local scan_k = 0

            while `scan_k' < `n_chars' & !`found_sep' {
                local ++scan_k
                local ch = substr(`"`remaining'"', `scan_k', 1)
                if "`ch'" == "(" local depth = `depth' + 1
                if "`ch'" == ")" local depth = `depth' - 1
                if "`ch'" == "\" & `depth' == 0 {
                    local found_sep = 1
                    local piece = strtrim(substr(`"`remaining'"', 1, `scan_k' - 1))
                    local remaining = strtrim(substr(`"`remaining'"', `scan_k' + 1, .))
                }
            }
            if !`found_sep' {
                local piece = strtrim(`"`remaining'"')
                local remaining ""
            }
            if `"`piece'"' == "" continue

            local ++n_blocks
            local b = `n_blocks'

            * Parse block sub-options
            local bsheet_`b'  ""
            local brows_`b'   ""
            local bcols_`b'   ""
            local blabel_`b'  ""
            local bskip_`b'   ""
            local bpostfix_`b' ""

            _stacktab_get_subopt sheet, text(`"`piece'"')
            local bsheet_`b' `"`r(value)'"'
            _stacktab_get_subopt rows, text(`"`piece'"')
            local brows_`b' `"`r(value)'"'
            _stacktab_get_subopt cols, text(`"`piece'"')
            local bcols_`b' `"`r(value)'"'
            _stacktab_get_subopt label, text(`"`piece'"')
            local blabel_`b' `"`r(value)'"'
            _stacktab_get_subopt skip, text(`"`piece'"')
            local bskip_`b' `"`r(value)'"'
            _stacktab_get_subopt postfix, text(`"`piece'"')
            local bpostfix_`b' `"`r(value)'"'
        }

        if `n_blocks' == 0 {
            display as error "stacktab: blocks() parsed no valid blocks"
            exit 198
        }

        * ================================================================
        * IMPORT AND STACK BLOCKS
        * ================================================================
        preserve
        local _restore_needed = 1

        clear
        local composite_n = 0
        local composite_ncols = 0
        local hstack_rows = .
        local hstack_next_col = 1

        forvalues b = 1/`n_blocks' {
            local bsh  `"`bsheet_`b''"'
            local brow `"`brows_`b''"'
            local bcol `"`bcols_`b''"'

            if `"`bsh'"' == "" {
                display as error "stacktab: block `b' missing sheet()"
                exit 198
            }

            * Build cellrange from rows() and cols()
            local cellrange ""
            local row_lo ""
            local row_hi ""
            local col_s ""
            local col_e ""
            if `"`brow'"' != "" {
                _stacktab_parse_rows `"`brow'"'
                local row_lo = r(first)
                local row_hi = r(last)
            }
            if `"`bcol'"' != "" {
                _stacktab_parse_cols `"`bcol'"'
                local col_s `"`r(first)'"'
                local col_e `"`r(last)'"'
            }
            if `"`bcol'"' != "" & `"`brow'"' != "" {
                local cellrange "`col_s'`row_lo':`col_e'`row_hi'"
            }

            * Import block from source workbook
            capture {
                if `"`cellrange'"' != "" {
                    import excel `"`using'"', ///
                        sheet(`"`bsh'"') cellrange(`"`cellrange'"') clear allstring
                }
                else {
                    import excel `"`using'"', sheet(`"`bsh'"') clear allstring
                }
            }
            if _rc {
                display as error `"stacktab: could not import block `b' from sheet "`bsh'""'
                exit _rc
            }

            * Apply row range filter if rows given but no cellrange
            if `"`brow'"' != "" & `"`bcol'"' == "" {
                quietly keep if inrange(_n, `row_lo', `row_hi')
            }
            if `"`bcol'"' != "" & `"`brow'"' == "" {
                capture unab _col_keep : `col_s'-`col_e'
                if _rc {
                    display as error `"stacktab: cols(`bcol') not found in sheet "`bsh'""'
                    exit 111
                }
                keep `_col_keep'
            }

            * Skip specified row (within imported block, 1-indexed)
            if `"`bskip_`b''"' != "" {
                quietly drop if _n == `bskip_`b''
            }

            quietly count
            if r(N) == 0 {
                display as error "stacktab: block `b' (sheet `bsh') imported 0 rows"
                exit 198
            }

            quietly ds
            local block_vars `r(varlist)'
            local first_var : word 1 of `block_vars'

            * Apply label to first column value of first row
            if `"`blabel_`b''"' != "" {
                quietly replace `first_var' = `"`blabel_`b''"' in 1
            }

            * Apply postfix to first column of all rows
            if `"`bpostfix_`b''"' != "" {
                quietly replace `first_var' = `first_var' + `" `bpostfix_`b''"'
            }

            quietly count
            local block_rows = r(N)

            local nvars = 0
            foreach v of varlist _all {
                local ++nvars
            }

            if "`layout'" == "vstack" {
                local vnum = 0
                foreach v of varlist _all {
                    local ++vnum
                    rename `v' _xcol`vnum'
                }
                quietly gen long _xblock = `b'
                quietly gen long _xorder = _n

                if `spacing' > 0 & `b' < `n_blocks' {
                    local old_n = _N
                    quietly set obs `=`old_n' + `spacing''
                    quietly replace _xblock = `b' if missing(_xblock)
                    quietly replace _xorder = _n if missing(_xorder)
                    forvalues si = `=`old_n' + 1'/`=_N' {
                        forvalues cn = 1/`nvars' {
                            quietly replace _xcol`cn' = "" in `si'
                        }
                    }
                }

                if `composite_n' == 0 {
                    tempfile composite
                    quietly save `"`composite'"', replace
                    local composite_ncols = `nvars'
                }
                else {
                    if `nvars' > `composite_ncols' local composite_ncols = `nvars'
                    quietly append using `"`composite'"'
                    quietly save `"`composite'"', replace
                }
            }
            else {
                if `composite_n' == 0 {
                    local hstack_rows = `block_rows'
                }
                else if `block_rows' != `hstack_rows' {
                    display as error "stacktab: hstack blocks must have the same row count"
                    exit 459
                }
                quietly gen long _rowid = _n
                local vnum = 0
                foreach v of local block_vars {
                    local ++vnum
                    local new_col = `hstack_next_col' + `vnum' - 1
                    rename `v' _xcol`new_col'
                }
                local hstack_next_col = `hstack_next_col' + `nvars'

                if `composite_n' == 0 {
                    tempfile composite
                    quietly save `"`composite'"', replace
                }
                else {
                    quietly merge 1:1 _rowid using `"`composite'"', nogen
                    quietly save `"`composite'"', replace
                }
                local composite_ncols = `hstack_next_col' - 1
            }
            local composite_n = `composite_n' + 1
        }

        quietly use `"`composite'"', clear
        if "`layout'" == "vstack" {
            sort _xblock _xorder
            drop _xblock _xorder
        }
        else {
            sort _rowid
            drop _rowid
        }
        capture confirm variable _xblock
        if !_rc drop _xblock
        forvalues cn = 1/`composite_ncols' {
            capture confirm variable _xcol`cn'
            if _rc == 0 {
                order _xcol`cn', last
            }
        }

        * ================================================================
        * APPLY COLUMNMERGE
        * ================================================================
        if `"`columnmerge'"' != "" {
            * Parse: "C+D as 'header' \ F+G as 'header2'"
            * (using column position names _xcol1, etc. is hard; use user-supplied letter names)
            local cm_remain `"`columnmerge'"'
            while `"`cm_remain'"' != "" {
                local cm_piece ""
                local cm_n = strlen(`"`cm_remain'"')
                local cm_sep = 0
                local cm_k = 0
                while `cm_k' < `cm_n' & !`cm_sep' {
                    local ++cm_k
                    if substr(`"`cm_remain'"', `cm_k', 1) == "\" {
                        local cm_sep = 1
                        local cm_piece = strtrim(substr(`"`cm_remain'"', 1, `cm_k' - 1))
                        local cm_remain = strtrim(substr(`"`cm_remain'"', `cm_k' + 1, .))
                    }
                }
                if !`cm_sep' {
                    local cm_piece = strtrim(`"`cm_remain'"')
                    local cm_remain ""
                }
                if `"`cm_piece'"' == "" continue

                * Parse: "colA+colB as 'header'"
                * e.g. "_xcol3+_xcol4 as 'aHR (95% CI)'"
                local as_pos = strpos(`"`cm_piece'"', " as ")
                if `as_pos' == 0 {
                    display as error `"stacktab: malformed columnmerge() piece "`cm_piece'""'
                    display as error `"Expected syntax like B+C as "Header""'
                    exit 198
                }
                local pair_str = strtrim(substr(`"`cm_piece'"', 1, `as_pos' - 1))
                local hdr = strtrim(substr(`"`cm_piece'"', `as_pos' + 4, .))
                local hdr = subinstr(`"`hdr'"', `"""', "", .)
                if `"`hdr'"' == "" {
                    display as error "stacktab: columnmerge() header may not be empty"
                    exit 198
                }

                local col_a : word 1 of `: subinstr local pair_str "+" " "'
                local col_b : word 2 of `: subinstr local pair_str "+" " "'
                local col_extra : word 3 of `: subinstr local pair_str "+" " "'
                if `"`col_a'"' == "" | `"`col_b'"' == "" | `"`col_extra'"' != "" {
                    display as error `"stacktab: columnmerge() requires exactly two columns in "`pair_str'""'
                    exit 198
                }
                _stacktab_resolve_col `"`col_a'"'
                local col_a `"`r(name)'"'
                _stacktab_resolve_col `"`col_b'"'
                local col_b `"`r(name)'"'
                if "`col_a'" == "`col_b'" {
                    display as error "stacktab: columnmerge() cannot merge a column with itself"
                    exit 198
                }
                confirm variable `col_a'
                confirm variable `col_b'
                * Concatenate the two columns
                quietly replace `col_a' = `col_a' + " " + `col_b' ///
                    if `col_b' != "" & `col_b' != "."
                * Apply header to row 1 (if it's a header row)
                quietly replace `col_a' = `"`hdr'"' in 1
                drop `col_b'
            }
        }

        quietly ds
        local final_vars `r(varlist)'
        local final_ncols : word count `final_vars'
        quietly count
        local logical_rows = r(N)

        local width_values ""
        foreach v of local final_vars {
            tempvar _xlen
            quietly gen int `_xlen' = length(`v')
            quietly summarize `_xlen', meanonly
            local _w = ceil(r(max) * .95) + 2
            if "`v'" == "`: word 1 of `final_vars''" {
                if `_w' < 14 local _w = 14
                if `_w' > 45 local _w = 45
            }
            else {
                if `_w' < 10 local _w = 10
                if `_w' > 24 local _w = 24
            }
            local width_values "`width_values' `_w'"
            drop `_xlen'
        }
        local width_values = strtrim("`width_values'")
        local title_height = 30
        local note_height = 45
        local _style_clean : subinstr local style `"""' "", all
        local trh_pos = strpos(lower(`"`_style_clean'"'), "titlerowheight(")
        if `trh_pos' > 0 {
            local trh_tail = substr(`"`_style_clean'"', `trh_pos' + 15, .)
            local trh_end = strpos(`"`trh_tail'"', ")")
            if `trh_end' > 0 local title_height = real(substr(`"`trh_tail'"', 1, `trh_end' - 1))
        }
        local nrh_pos = strpos(lower(`"`_style_clean'"'), "noterowheight(")
        if `nrh_pos' > 0 {
            local nrh_tail = substr(`"`_style_clean'"', `nrh_pos' + 14, .)
            local nrh_end = strpos(`"`nrh_tail'"', ")")
            if `nrh_end' > 0 local note_height = real(substr(`"`nrh_tail'"', 1, `nrh_end' - 1))
        }

        if "`display'" != "" {
            list, noobs abbreviate(24)
        }

        * ================================================================
        * OPTIONAL DATASET OUTPUTS
        * ================================================================
        tempfile finaldata
        quietly save `"`finaldata'"', replace

        local frame_name ""
        if `"`frame'"' != "" {
            _stacktab_parse_frame, frame(`frame')
            local frame_name `"`r(name)'"'
            local frame_replace `"`r(replace)'"'

            capture frame `frame_name': quietly count
            if !_rc & "`frame_replace'" == "" {
                display as error `"frame "`frame_name'" already exists; specify frame(`frame_name', replace)"'
                exit 110
            }
            if !_rc {
                capture frame drop `frame_name'
            }
            frame put _all, into(`frame_name')
        }

        if `"`csv'"' != "" {
            quietly export delimited using `"`csv'"', replace
        }

        local _ret_markdown ""
        local _ret_markdown_rows .
        local _ret_markdown_cols .
        if `"`markdown'"' != "" {
            local _mdappend_opt ""
            if "`mdappend'" != "" local _mdappend_opt "append"
            capture noisily _tabtools_markdown_write using `"`markdown'"', ///
                `_mdappend_opt' title(`"`title'"') footnote(`"`note'"')
            if _rc {
                local _md_rc = _rc
                display as error "Failed to export Markdown to `markdown'"
                exit `_md_rc'
            }
            local _ret_markdown `"`markdown'"'
            local _ret_markdown_rows = r(n_rows)
            local _ret_markdown_cols = r(n_cols)
        }

        * ================================================================
        * EXPORT TO SHEET
        * ================================================================

        local existing_rows = 0
        local export_title_row = 1
        local export_start_row = 2
        local export_start_col = 2
        if "`append'" == "" & "`sheetreplace'" == "" {
            capture _stacktab_xlsx_sheet_bounds using `"`using'"', ///
                sheet(`"`sheet'"')
            if _rc == 0 {
                display as error `"stacktab: sheet "`sheet'" already exists; specify append or sheetreplace"'
                exit 602
            }
            quietly use `"`finaldata'"', clear
        }
        if "`append'" != "" {
            capture _stacktab_xlsx_sheet_bounds using `"`using'"', ///
                sheet(`"`sheet'"')
            if _rc {
                local existing_rows = 0
                local export_title_row = 1
                local export_start_row = 2
                quietly use `"`finaldata'"', clear
            }
            else {
                local existing_rows = r(rows)
                if `existing_rows' == 0 {
                    local export_title_row = 1
                    local export_start_row = 2
                }
                else {
                    local export_title_row = r(rows) + 1
                    local export_start_row = r(rows) + 1
                    if `"`title'"' != "" local export_start_row = r(rows) + 2
                }
                quietly use `"`finaldata'"', clear
            }
        }
        if "`append'" == "" {
            local export_title_row = 1
            local export_start_row = 2
        }

        _stacktab_xlsx_write using `"`using'"', sheet(`"`sheet'"') ///
            startrow(`export_start_row') startcol(`export_start_col') ///
            `sheetreplace'

        quietly count
        local rows_written = r(N)
        local rows_out = `export_start_row' + `rows_written' - 1
        local note_row = .
        if `"`note'"' != "" local note_row = `rows_out' + 1

        * ================================================================
        * APPLY TABTOOLS-STYLE EXCEL FORMATTING
        * ================================================================
            local _styleopt ""
            if `"`style'"' != "" local _styleopt `"style(`style')"'
            local _bordersopt ""
            if `"`borders'"' != "" local _bordersopt `"borders(`borders')"'
            _stacktab_apply_style, book(`"`using'"') sheet(`"`sheet'"') ///
                `_styleopt' `_bordersopt' widths(`"`width_values'"') ///
                rows(`rows_written') cols(`final_ncols') ///
                startrow(`export_start_row') startcol(`export_start_col')

        local last_sheet_col = `export_start_col' + `final_ncols' - 1
        if `"`title'"' != "" & `export_title_row' > 0 {
            mata: _stacktab_xlsx_put_text_mata(`"`using'"', `"`sheet'"', ///
                `export_title_row', 1, 1, `last_sheet_col', `"`title'"', ///
                12, `title_height', 1, 0)
        }
        if `"`note'"' != "" {
            mata: _stacktab_xlsx_put_text_mata(`"`using'"', `"`sheet'"', ///
                `note_row', `export_start_col', `export_start_col', ///
                `last_sheet_col', `"`note'"', 8, `note_height', 0, 1)
        }

        local _ret_blocks_loaded = `n_blocks'
        local _ret_rows_written = `rows_written'
        local _ret_rows_out = `rows_out'
        local _ret_cols_out = `final_ncols'
        local _ret_append_start = `export_start_row'
        local _ret_table_start "B`export_start_row'"
        local _ret_title_cell ""
        if `"`title'"' != "" & `export_title_row' > 0 local _ret_title_cell "A`export_title_row'"
        local _ret_note_row = `note_row'
        local _ret_sheet `"`sheet'"'
        local _ret_book `"`using'"'
        local _ret_layout "`layout'"
        local _ret_frame `"`frame_name'"'
        local _ret_csv `"`csv'"'
    }
    local rc = _rc
    if `_restore_needed' {
        capture restore
    }
    set varabbrev `_vao'
    if `rc' exit `rc'

    return scalar blocks_loaded = `_ret_blocks_loaded'
    return scalar rows_written  = `_ret_rows_written'
    return scalar rows_out      = `_ret_rows_out'
    return scalar cols_out      = `_ret_cols_out'
    return scalar append_start  = `_ret_append_start'
    if `_ret_note_row' < . return scalar note_row = `_ret_note_row'
    return local  layout        `"`_ret_layout'"'
    return local  sheet         `"`_ret_sheet'"'
    return local  book          `"`_ret_book'"'
    return local  table_start   `"`_ret_table_start'"'
    if `"`_ret_title_cell'"' != "" return local title_cell `"`_ret_title_cell'"'
    if `"`_ret_frame'"' != "" return local frame `"`_ret_frame'"'
    if `"`_ret_csv'"' != "" return local csv `"`_ret_csv'"'
    if `"`_ret_markdown'"' != "" {
        return local markdown `"`_ret_markdown'"'
        return scalar markdown_rows = `_ret_markdown_rows'
        return scalar markdown_cols = `_ret_markdown_cols'
    }

    display as text "stacktab: `_ret_blocks_loaded' blocks -> `_ret_rows_written' rows written -> sheet `_ret_sheet'"
end


capture program drop _stacktab_xlsx_write
program define _stacktab_xlsx_write, rclass
    version 16.0
    local _vao = c(varabbrev)
    set varabbrev off
    local _book_name "_stacktab_write_book"
    capture noisily {
        syntax using/ , SHEET(string) STARTRow(integer) STARTCol(integer) ///
            [SHEETreplace]

        if `startrow' < 1 {
            display as error "startrow() must be positive"
            exit 198
        }
        if `startcol' < 1 {
            display as error "startcol() must be positive"
            exit 198
        }

        quietly ds
        local _vars `r(varlist)'
        if "`_vars'" == "" {
            display as error "No variables available for Excel export"
            exit 111
        }
        quietly count
        if r(N) == 0 {
            display as error "No observations available for Excel export"
            exit 2000
        }

        local _replace = ("`sheetreplace'" != "")
        mata: _stacktab_xlsx_write_mata(`"`using'"', `"`sheet'"', ///
            `"`_vars'"', `startrow', `startcol', `_replace')

        return scalar n_rows = _N
        return scalar n_cols = `: word count `_vars''
        return scalar startrow = `startrow'
        return scalar startcol = `startcol'
        return local sheet `"`sheet'"'
        return local xlsx `"`using'"'
    }
    local rc = _rc
    capture mata: `_book_name'.close_book()
    capture mata: mata drop `_book_name'
    set varabbrev `_vao'
    if `rc' exit `rc'
end


capture program drop _stacktab_xlsx_sheet_bounds
program define _stacktab_xlsx_sheet_bounds, rclass
    version 16.0
    local _vao = c(varabbrev)
    set varabbrev off
    capture noisily {
        syntax using/ , SHEET(string) [MAXRows(integer 20000) ///
            MAXCols(integer 702) PROBERows(integer 256) PROBECols(integer 64)]

        if `maxrows' < 1 {
            display as error "maxrows() must be positive"
            exit 198
        }
        if `maxcols' < 1 | `maxcols' > 702 {
            display as error "maxcols() must be between 1 and 702"
            exit 198
        }
        if `proberows' < 1 {
            display as error "proberows() must be positive"
            exit 198
        }
        if `probecols' < 1 | `probecols' > 702 {
            display as error "probecols() must be between 1 and 702"
            exit 198
        }

        mata: _stacktab_xlsx_bounds_mata(`"`using'"', `"`sheet'"', ///
            `maxrows', `maxcols', `proberows', `probecols')

        return scalar rows = r(_stacktab_lastrow)
        return scalar cols = r(_stacktab_lastcol)
        return local sheet `"`sheet'"'
        return local xlsx `"`using'"'
    }
    local rc = _rc
    set varabbrev `_vao'
    if `rc' exit `rc'
end


capture program drop _stacktab_parse_frame
program define _stacktab_parse_frame, rclass
    version 16.0
    local _vao = c(varabbrev)
    set varabbrev off
    capture noisily {
        syntax , FRAme(string asis)
        local spec `"`frame'"'
        local spec = subinstr(`"`spec'"', `"""', "", .)
        local spec = strtrim(`"`spec'"')
        if `"`spec'"' == "" {
            display as error "frame() requires a frame name"
            exit 198
        }

        local comma = strpos(`"`spec'"', ",")
        if `comma' {
            local fname = strtrim(substr(`"`spec'"', 1, `comma' - 1))
            local opts = lower(strtrim(substr(`"`spec'"', `comma' + 1, .)))
        }
        else {
            local fname `"`spec'"'
            local opts ""
        }

        capture confirm name `fname'
        if _rc {
            display as error `"frame() invalid frame name "`fname'""'
            exit 198
        }

        local replace ""
        if `"`opts'"' != "" {
            local opts : subinstr local opts "," " ", all
            foreach opt of local opts {
                if "`opt'" == "replace" {
                    local replace "replace"
                }
                else {
                    display as error `"frame() invalid option "`opt'"; only replace is allowed"'
                    exit 198
                }
            }
        }

        return local name `"`fname'"'
        return local replace "`replace'"
    }
    local rc = _rc
    set varabbrev `_vao'
    if `rc' exit `rc'
end


* ============================================================================
* HELPER: Apply style() spec via mata-xl
* ============================================================================
capture program drop _stacktab_get_subopt
program define _stacktab_get_subopt, rclass
    version 16.0
    local _vao = c(varabbrev)
    set varabbrev off
    capture noisily {
        syntax name(name=opt) , TEXT(string asis)
        local haystack `"`text'"'
        local needle = lower(`"`opt'"') + "("
        local pos = strpos(lower(`"`haystack'"'), "`needle'")
        if `pos' == 0 {
            return local value ""
        }
        else {
            local start = `pos' + strlen("`needle'")
            local depth = 1
            local inquote = 0
            local end = 0
            local q = char(34)
            forvalues i = `start'/`=strlen(`"`haystack'"')' {
                local ch = substr(`"`haystack'"', `i', 1)
                if `"`ch'"' == `"`q'"' local inquote = !`inquote'
                if !`inquote' {
                    if "`ch'" == "(" local depth = `depth' + 1
                    if "`ch'" == ")" local depth = `depth' - 1
                    if `depth' == 0 & `end' == 0 local end = `i'
                }
            }
            if `end' == 0 {
                display as error "stacktab: malformed `opt'() in blocks()"
                exit 198
            }
            local value = strtrim(substr(`"`haystack'"', `start', `end' - `start'))
            if substr(`"`value'"', 1, 1) == `"`q'"' & substr(`"`value'"', -1, 1) == `"`q'"' {
                local value = substr(`"`value'"', 2, strlen(`"`value'"') - 2)
            }
            return local value `"`value'"'
        }
    }
    local rc = _rc
    set varabbrev `_vao'
    if `rc' exit `rc'
end


capture program drop _stacktab_resolve_col
program define _stacktab_resolve_col, rclass
    version 16.0
    local _vao = c(varabbrev)
    set varabbrev off
    capture noisily {
        args col
        local col = strtrim(`"`col'"')
        if regexm(`"`col'"', "^_xcol[0-9]+$") {
            return local name `"`col'"'
        }
        else if regexm(`"`col'"', "^[A-Za-z]+$") {
            local up = upper(`"`col'"')
            local n = 0
            forvalues i = 1/`=strlen(`"`up'"')' {
                local c = substr(`"`up'"', `i', 1)
                local n = (`n' * 26) + strpos("ABCDEFGHIJKLMNOPQRSTUVWXYZ", "`c'")
            }
            return local name "_xcol`n'"
        }
        else {
            return local name `"`col'"'
        }
    }
    local rc = _rc
    set varabbrev `_vao'
    if `rc' exit `rc'
end


capture program drop _stacktab_parse_rows
program define _stacktab_parse_rows, rclass
    version 16.0
    local _vao = c(varabbrev)
    set varabbrev off
    capture noisily {
        args spec
        local spec = strtrim(`"`spec'"')
        local pieces : subinstr local spec "/" " ", all
        local first : word 1 of `pieces'
        local last : word 2 of `pieces'
        local extra : word 3 of `pieces'
        if `"`first'"' == "" | `"`extra'"' != "" {
            display as error `"stacktab: invalid rows(`spec')"'
            exit 198
        }
        if `"`last'"' == "" local last "`first'"
        capture confirm integer number `first'
        if _rc {
            display as error "stacktab: rows() bounds must be positive integers"
            exit 198
        }
        capture confirm integer number `last'
        if _rc {
            display as error "stacktab: rows() bounds must be positive integers"
            exit 198
        }
        if `first' < 1 | `last' < 1 | `last' < `first' {
            display as error "stacktab: rows() must be a positive lo/hi range"
            exit 198
        }
        return scalar first = `first'
        return scalar last = `last'
    }
    local rc = _rc
    set varabbrev `_vao'
    if `rc' exit `rc'
end


capture program drop _stacktab_parse_cols
program define _stacktab_parse_cols, rclass
    version 16.0
    local _vao = c(varabbrev)
    set varabbrev off
    capture noisily {
        args spec
        local spec = strtrim(`"`spec'"')
        local pieces : subinstr local spec "-" " ", all
        local first : word 1 of `pieces'
        local last : word 2 of `pieces'
        local extra : word 3 of `pieces'
        if `"`first'"' == "" | `"`extra'"' != "" {
            display as error `"stacktab: invalid cols(`spec')"'
            exit 198
        }
        if `"`last'"' == "" local last "`first'"
        if !regexm(`"`first'"', "^[A-Za-z]+$") | !regexm(`"`last'"', "^[A-Za-z]+$") {
            display as error "stacktab: cols() bounds must be Excel column letters"
            exit 198
        }
        _stacktab_resolve_col `"`first'"'
        local first_idx = real(subinstr(`"`r(name)'"', "_xcol", "", 1))
        _stacktab_resolve_col `"`last'"'
        local last_idx = real(subinstr(`"`r(name)'"', "_xcol", "", 1))
        if `last_idx' < `first_idx' {
            display as error "stacktab: cols() range must be left-to-right"
            exit 198
        }
        local first = upper(`"`first'"')
        local last = upper(`"`last'"')
        return local first `"`first'"'
        return local last `"`last'"'
        return scalar first_index = `first_idx'
        return scalar last_index = `last_idx'
    }
    local rc = _rc
    set varabbrev `_vao'
    if `rc' exit `rc'
end


* ============================================================================
* HELPER: Apply style() spec via mata-xl
* ============================================================================
capture program drop _stacktab_apply_style
program define _stacktab_apply_style
    version 16.0
    local _vao = c(varabbrev)
    set varabbrev off
    local _book_open = 0
    capture noisily {
    syntax , BOOK(string) SHEET(string) ROWS(integer) COLS(integer) ///
        [STYLE(string asis) BORDERS(string asis) WIDTHS(numlist) ///
         STARTRow(integer 2) STARTCol(integer 2)]
    if `startrow' < 1 {
        display as error "startrow() must be positive"
        exit 198
    }
    if `startcol' < 1 {
        display as error "startcol() must be positive"
        exit 198
    }
    if `rows' < 1 | `cols' < 1 {
        display as error "rows() and cols() must be positive"
        exit 198
    }
    local style : subinstr local style `"""' "", all
    local borders : subinstr local borders `"""' "", all

    * Parse titlerowheight, noterowheight, colwidth from style_str
    local trh = 30
    local nrh = 45
    local trh_pos = strpos(lower(`"`style'"'), "titlerowheight(")
    if `trh_pos' > 0 {
        local trh_tail = substr(`"`style'"', `trh_pos' + 15, .)
        local trh_end = strpos(`"`trh_tail'"', ")")
        if `trh_end' > 0 local trh = real(substr(`"`trh_tail'"', 1, `trh_end' - 1))
    }
    local nrh_pos = strpos(lower(`"`style'"'), "noterowheight(")
    if `nrh_pos' > 0 {
        local nrh_tail = substr(`"`style'"', `nrh_pos' + 14, .)
        local nrh_end = strpos(`"`nrh_tail'"', ")")
        if `nrh_end' > 0 local nrh = real(substr(`"`nrh_tail'"', 1, `nrh_end' - 1))
    }

    mata: _stacktab_book = xl()
    local _book_open = 1
    mata: _stacktab_book.load_book("`book'")
    mata: _stacktab_book.set_sheet("`sheet'")
    mata: _stacktab_book.set_mode("open")

    local endrow = `startrow' + `rows' - 1
    local endcol = `startcol' + `cols' - 1
    local last_sheet_col = max(`endcol', 1)

    mata: _stacktab_book.set_font((`startrow', `endrow'), ///
        (`startcol', `endcol'), "Arial", 10)
    mata: _stacktab_book.set_text_wrap((`startrow', `endrow'), ///
        (`startcol', `endcol'), "on")
    mata: _stacktab_book.set_vertical_align((`startrow', `endrow'), ///
        (`startcol', `endcol'), "center")
    mata: _stacktab_book.set_font_bold((`startrow', `startrow'), ///
        (`startcol', `endcol'), "on")
    mata: _stacktab_book.set_bottom_border((`startrow', `startrow'), ///
        (`startcol', `endcol'), "thin")
    mata: _stacktab_book.set_bottom_border((`endrow', `endrow'), ///
        (`startcol', `endcol'), "thin")

    local wi = 0
    if `"`widths'"' != "" {
        foreach w of numlist `widths' {
            local ++wi
            if `wi' <= `cols' {
                local wc = `startcol' + `wi' - 1
                mata: _stacktab_book.set_column_width(`wc', `wc', `w')
            }
        }
    }

    local cw_pos = strpos(`"`style'"', "colwidth(")
    if `cw_pos' > 0 {
        local cw_tail = substr(`"`style'"', `cw_pos' + 9, .)
        local cw_end = strpos(`"`cw_tail'"', ")")
        if `cw_end' > 0 {
            local cw_spec = substr(`"`cw_tail'"', 1, `cw_end' - 1)
            local cw_remain `"`cw_spec'"'
            while `"`cw_remain'"' != "" {
                local cw_piece ""
                local cw_sep = strpos(`"`cw_remain'"', char(92))
                if `cw_sep' > 0 {
                    local cw_piece = strtrim(substr(`"`cw_remain'"', 1, `cw_sep' - 1))
                    local cw_remain = strtrim(substr(`"`cw_remain'"', `cw_sep' + 1, .))
                }
                else {
                    local cw_piece = strtrim(`"`cw_remain'"')
                    local cw_remain ""
                }
                local cw_col : word 1 of `cw_piece'
                local cw_width : word 2 of `cw_piece'
                if `"`cw_col'"' != "" & `"`cw_width'"' != "" {
                    _stacktab_resolve_col `"`cw_col'"'
                    local resolved `"`r(name)'"'
                    local cw_index = real(subinstr(`"`resolved'"', "_xcol", "", 1))
                    local excel_col = `startcol' + `cw_index' - 1
                    mata: _stacktab_book.set_column_width(`excel_col', ///
                        `excel_col', `cw_width')
                }
            }
        }
    }

    if strpos(lower(`"`borders'"'), "outer(all)") {
        mata: _stacktab_book.set_top_border((`startrow', `startrow'), ///
            (`startcol', `endcol'), "thin")
        mata: _stacktab_book.set_bottom_border((`endrow', `endrow'), ///
            (`startcol', `endcol'), "thin")
        mata: _stacktab_book.set_left_border((`startrow', `endrow'), ///
            (`startcol', `startcol'), "thin")
        mata: _stacktab_book.set_right_border((`startrow', `endrow'), ///
            (`endcol', `endcol'), "thin")
    }
    if strpos(lower(`"`borders'"'), "top(row 1)") {
        mata: _stacktab_book.set_top_border((`startrow', `startrow'), ///
            (`startcol', `endcol'), "thin")
    }
    if strpos(lower(`"`borders'"'), "bottom(last)") | ///
        strpos(lower(`"`borders'"'), "bottom(row `rows')") {
        mata: _stacktab_book.set_bottom_border((`endrow', `endrow'), ///
            (`startcol', `endcol'), "thin")
    }

    mata: _stacktab_book.close_book()
    local _book_open = 0
    mata: mata drop _stacktab_book
    }
    local rc = _rc
    if `_book_open' {
        capture mata: _stacktab_book.close_book()
    }
    capture mata: mata drop _stacktab_book
    set varabbrev `_vao'
    if `rc' exit `rc'
end


version 16.0
capture mata: mata drop _stacktab_xlsx_write_mata()
capture mata: mata drop _stacktab_cur_strmat()
capture mata: mata drop _stacktab_xlsx_bounds_mata()
capture mata: mata drop _stacktab_bounds()
capture mata: mata drop _stacktab_xlsx_put_text_mata()

mata:
mata set matastrict on

void _stacktab_xlsx_write_mata(
    string scalar filepath,
    string scalar sheet,
    string scalar varlist,
    real scalar startrow,
    real scalar startcol,
    real scalar replace_sheet)
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
            if (replace_sheet) b.clear_sheet(sheet)
        }
        else {
            b.add_sheet(sheet)
        }
        b.set_sheet(sheet)
    }

    b.set_mode("open")
    table = _stacktab_cur_strmat(varlist)
    b.put_string(startrow, startcol, table)
    b.close_book()
}

string matrix _stacktab_cur_strmat(string scalar varlist)
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

void _stacktab_xlsx_bounds_mata(
    string scalar filepath,
    string scalar sheet,
    real scalar maxrows,
    real scalar maxcols,
    real scalar proberows,
    real scalar probecols)
{
    class xl scalar b
    string rowvector sheets
    string matrix raw
    real rowvector bounds
    real scalar i, found, rowcap, colcap, lastrow, lastcol
    real scalar nextrowcap, nextcolcap

    b = xl()
    b.load_book(filepath)
    sheets = b.get_sheets()
    found = 0
    for (i = 1; i <= length(sheets); i++) {
        if (sheets[i] == sheet) {
            found = 1
            break
        }
    }
    if (!found) {
        b.close_book()
        errprintf("sheet %s not found in %s\n", sheet, filepath)
        _error(111)
    }

    b.set_sheet(sheet)
    rowcap = min((maxrows, max((1, proberows))))
    colcap = min((maxcols, max((1, probecols))))
    while (1) {
        raw = b.get_string((1, rowcap), (1, colcap))
        bounds = _stacktab_bounds(raw)
        lastrow = bounds[1]
        lastcol = bounds[2]

        nextrowcap = rowcap
        nextcolcap = colcap
        if (lastrow == rowcap & rowcap < maxrows) {
            nextrowcap = min((maxrows, max((rowcap + 1, rowcap * 2))))
        }
        if (lastcol == colcap & colcap < maxcols) {
            nextcolcap = min((maxcols, max((colcap + 1, colcap * 2))))
        }
        if (nextrowcap == rowcap & nextcolcap == colcap) break
        rowcap = nextrowcap
        colcap = nextcolcap
    }
    b.close_book()

    st_numscalar("r(_stacktab_lastrow)", lastrow)
    st_numscalar("r(_stacktab_lastcol)", lastcol)
}

real rowvector _stacktab_bounds(string matrix raw)
{
    real scalar i, j, lastrow, lastcol

    lastrow = 0
    lastcol = 0
    for (i = 1; i <= rows(raw); i++) {
        for (j = 1; j <= cols(raw); j++) {
            if (strtrim(raw[i, j]) != "") {
                if (i > lastrow) lastrow = i
                if (j > lastcol) lastcol = j
            }
        }
    }

    return((lastrow, lastcol))
}

void _stacktab_xlsx_put_text_mata(
    string scalar filepath,
    string scalar sheet,
    real scalar row,
    real scalar col,
    real scalar merge_start_col,
    real scalar merge_end_col,
    string scalar text,
    real scalar fontsize,
    real scalar rowheight,
    real scalar bold,
    real scalar italic)
{
    class xl scalar b

    b = xl()
    b.load_book(filepath)
    b.set_sheet(sheet)
    b.set_mode("open")
    b.put_string(row, col, text)
    if (merge_end_col > merge_start_col) {
        b.set_sheet_merge(sheet, (row, row), (merge_start_col, merge_end_col))
    }
    b.set_font((row, row), (merge_start_col, merge_end_col), "Arial", fontsize)
    b.set_text_wrap((row, row), (merge_start_col, merge_end_col), "on")
    b.set_vertical_align((row, row), (merge_start_col, merge_end_col), "center")
    if (bold) b.set_font_bold((row, row), (merge_start_col, merge_end_col), "on")
    if (italic) b.set_font_italic((row, row), (merge_start_col, merge_end_col), "on")
    if (rowheight > 0) b.set_row_height(row, row, rowheight)
    b.close_book()
}

end
