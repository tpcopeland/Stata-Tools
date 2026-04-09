*! comptab Version 1.0.1  2026/04/09
*! Compose publication tables from regtab/effecttab output frames
*! Author: Timothy P Copeland
*! Program class: rclass (returns results in r())

/*
DESCRIPTION:
    Assembles composite publication tables by selecting rows from multiple
    regtab or effecttab output frames. Eliminates the manual Excel import/
    export/format workflow for composite tables that combine results from
    different analyses (e.g., combining binary exposure, dose-response, and
    duration analyses into a single summary table).

SYNTAX:
    comptab framelist, {rows(string)|rownames(string)} [xlsx(string)
           sheet(string) title(string) footnote(string) compact
           separator(numlist) section(string asis) relabel(string asis)
           theme(string) borderstyle(string) open zebra
           highlight(real) boldp(real)
           headercolor(string) zebracolor(string)
           frame(name) display csv(string)]

    framelist:   Space-separated list of frame names created by regtab or
                 effecttab with the frame() option.
    rows:        Backslash-separated row specifications, one per frame.
                 Each specification is a numlist of data row numbers.
                 Row 1 = first covariate/exposure row after column headers.
                 Example: rows(1 2 \ 1 3/5 \ 1)
    rownames:    Alternative to rows(). Backslash-separated lists of
                 variable name or label patterns matched (case-insensitive
                 substring) against column A text. Exactly one of rows()
                 or rownames() is required.
                 Example: rownames(age sex \ age education income)
    xlsx:        Excel file name (requires .xlsx suffix)
    sheet:       Excel sheet name (default: "Composite")
    title:       Table title for cell A1
    footnote:    Footnote text below the table
    compact:     Merge estimate and CI into a single column per model.
                 Layout changes from (Est | CI | p) to (Est (CI) | p).
    separator:   Numlist of composite data row numbers where thin horizontal
                 borders are drawn above the specified rows.
    section:     Backslash-separated section labels, one per frame. Inserts
                 a bold section header row before each frame's data block.
                 Example: section("Binary Exposure" \ "Dose Categories")
    relabel:     Pairs of composite_row_number and new label.
                 Example: relabel(3 "Low dose (vs. none)" 5 "High dose")
                 Row numbers are 1-based from first data row (after headers),
                 including any section header rows.
    theme:       Journal theme: lancet, nejm, bmj, apa
    borderstyle: Border style: thin, medium, academic (default: thin)
    open:        Open the Excel file after export
    zebra:       Apply alternating row shading
    highlight:   Highlight rows where p < threshold (e.g., highlight(0.05))
    boldp:       Bold p-values below threshold (e.g., boldp(0.05))
    headercolor: RGB color for header rows (default: "219 229 241")
    zebracolor:  RGB color for zebra shading (default: "237 242 249")
    frame:       Save composite dataset to a named frame
    display:     Show console preview
    csv:         Export to CSV file path

PREREQUISITES:
    Source frames must be created by regtab or effecttab with frame():

    collect clear
    collect: stcox exposure covariates, nolog
    regtab, xlsx(results.xlsx) sheet("S1") frame(s1) coef("HR") noint

EXAMPLES:
    * Basic composite from two regtab frames
    comptab s1 s2, rows(1 \ 1 3/5) ///
        xlsx(results.xlsx) sheet("Composite") ///
        title("Table 3. Combined Results")

    * With sections and footnote
    comptab s1 s2 s3, rows(1 2 \ 1 3/5 \ 1) ///
        xlsx(manuscript.xlsx) sheet("Table 3") ///
        section("Binary Exposure" \ "Dose Categories" \ "Duration") ///
        title("Table 3. Treatment and Outcomes") ///
        footnote("Note: All models adjusted for age, sex, and comorbidities.")

    * Compact mode (merge estimate + CI into one column)
    comptab s1 s2, rows(1 \ 1 3/5) compact ///
        xlsx(results.xlsx) sheet("Summary") theme(lancet)

    * Console preview only (no Excel output)
    comptab s1 s2, rows(1 2 \ 1 3/5) display
*/

program define comptab, rclass
    version 17.0
    local _prev_varabbrev = c(varabbrev)
    set varabbrev off

    * Auto-load shared helper programs if not already in memory
    capture program list _tabtools_validate_path
    if _rc {
        capture findfile _tabtools_common.ado
        if _rc == 0 {
            run "`r(fn)'"
        }
        else {
            display as error "_tabtools_common.ado not found; reinstall tabtools"
            set varabbrev `_prev_varabbrev'
            exit 111
        }
    }

    capture noisily {

    syntax anything(name=framelist), [rows(string) ROWNames(string)] ///
        [xlsx(string) excel(string) sheet(string)] ///
        [title(string) SUBTitle(string) FOOTnote(string asis) COMPact ///
        SEParator(numlist >0 integer sort) SECTion(string asis) ///
        RELAbel(string asis) ///
        THEme(string) BORDERStyle(string) open zebra ///
        HIGHlight(real -1) BOLDp(real -1) ///
        HEADERColor(string) ZEBRAColor(string) ///
        csv(string) FRAme(string) DISPlay]

    * Validate: exactly one of rows() or rownames() must be specified
    if `"`rows'"' == "" & `"`rownames'"' == "" {
        noisily display as error "One of rows() or rownames() is required"
        exit 198
    }
    if `"`rows'"' != "" & `"`rownames'"' != "" {
        noisily display as error "rows() and rownames() may not be combined"
        exit 198
    }
    local _use_rownames = `"`rownames'"' != ""

    * Accept excel() as synonym for xlsx()
    if "`xlsx'" == "" & "`excel'" != "" local xlsx "`excel'"
    local _has_xlsx = "`xlsx'" != ""
    if "`sheet'" == "" local sheet "Composite"

    * Resolve persistent defaults
    if `boldp' == -1 & "$TABTOOLS_BOLDP" != "" local boldp = $TABTOOLS_BOLDP

    * Validate sheet name for Excel constraints
    _tabtools_validate_sheet "`sheet'" "sheet()"

    * =====================================================================
    * RESOLVE FORMATTING OPTIONS
    * =====================================================================
    _tabtools_resolve_format, theme(`theme') borderstyle(`borderstyle')
    if !inlist("`borderstyle'", "thin", "medium", "academic") {
        noisily display as error "borderstyle() must be thin, medium, or academic"
        exit 198
    }

    local _headercolor "219 229 241"
    local _zebracolor "237 242 249"
    if "$TABTOOLS_HEADERCOLOR" != "" local _headercolor "$TABTOOLS_HEADERCOLOR"
    if "$TABTOOLS_ZEBRACOLOR" != "" local _zebracolor "$TABTOOLS_ZEBRACOLOR"
    if "`headercolor'" != "" local _headercolor "`headercolor'"
    if "`zebracolor'" != "" local _zebracolor "`zebracolor'"

    local has_highlight = `highlight' != -1
    if `has_highlight' & (`highlight' <= 0 | `highlight' >= 1) {
        noisily display as error "highlight() must be between 0 and 1"
        exit 198
    }
    local has_boldp = `boldp' != -1
    if `has_boldp' & (`boldp' <= 0 | `boldp' >= 1) {
        noisily display as error "boldp() must be between 0 and 1"
        exit 198
    }

    * =====================================================================
    * VALIDATE FRAMES
    * =====================================================================
    local n_frames : word count `framelist'
    if `n_frames' == 0 {
        noisily display as error "At least one frame name required"
        exit 198
    }

    forvalues f = 1/`n_frames' {
        local _fname : word `f' of `framelist'
        capture frame `_fname': qui count
        if _rc {
            noisily display as error "Frame '`_fname'' not found"
            noisily display as error "Hint: use {bf:regtab} or {bf:effecttab} with {bf:frame()} to create source frames"
            exit 111
        }
    }

    * =====================================================================
    * PARSE ROWS() OR ROWNAMES() — BACKSLASH-SEPARATED SPECIFICATIONS
    * =====================================================================
    if `_use_rownames' {
        * Parse rownames() — backslash-separated name/label patterns
        local rownames : subinstr local rownames " \ " "\", all
        local rownames : subinstr local rownames "\  " "\", all
        local rownames : subinstr local rownames "  \" "\", all
        tokenize `"`rownames'"', parse("\")

        local ridx = 1
        local fidx = 0
        while `"``ridx''"' != "" {
            if `"``ridx''"' != "\" {
                local fidx = `fidx' + 1
                local rnspec`fidx' `"``ridx''"'
            }
            local ridx = `ridx' + 1
        }

        if `fidx' != `n_frames' {
            noisily display as error "rownames() requires `n_frames' specifications separated by \, found `fidx'"
            exit 198
        }

        * Match patterns against column A text in each frame to build row numbers
        forvalues f = 1/`n_frames' {
            local _fname : word `f' of `framelist'
            frame `_fname' {
                local _fn = _N
            }
            local _max_dr = `_fn' - 3
            if `_max_dr' < 1 {
                noisily display as error "Frame '`_fname'' has no data rows (only `_fn' total rows)"
                exit 198
            }

            local expanded`f' ""
            local _patterns `"`rnspec`f''"'
            foreach _pat of local _patterns {
                local _pat = strtrim(`"`_pat'"')
                local _matched = 0
                frame `_fname' {
                    forvalues _row = 1/`_max_dr' {
                        local _frame_row = `_row' + 3
                        local _cell_text = A[`_frame_row']
                        local _cell_lower = lower(`"`_cell_text'"')
                        local _pat_lower = lower(`"`_pat'"')
                        if strmatch(`"`_cell_lower'"', `"*`_pat_lower'*"') {
                            local expanded`f' "`expanded`f'' `_row'"
                            local _matched = 1
                        }
                    }
                }
                if !`_matched' {
                    noisily display as error `"rownames(): pattern "`_pat'" not found in frame '`_fname''"'
                    exit 198
                }
            }
            * Remove leading space
            local expanded`f' : list clean expanded`f'
        }
    }
    else {
        * Parse rows() — backslash-separated numlists
        local rows : subinstr local rows " \ " "\", all
        local rows : subinstr local rows "\  " "\", all
        local rows : subinstr local rows "  \" "\", all
        tokenize `"`rows'"', parse("\")

        local ridx = 1
        local fidx = 0
        while `"``ridx''"' != "" {
            if `"``ridx''"' != "\" {
                local fidx = `fidx' + 1
                local rowspec`fidx' `"``ridx''"'
            }
            local ridx = `ridx' + 1
        }

        if `fidx' != `n_frames' {
            noisily display as error "rows() requires `n_frames' specifications separated by \, found `fidx'"
            exit 198
        }

        * Expand numlists and validate row ranges
        forvalues f = 1/`n_frames' {
            local _fname : word `f' of `framelist'
            numlist "`rowspec`f''"
            local expanded`f' `r(numlist)'

            frame `_fname' {
                local _fn = _N
            }
            local _max_dr = `_fn' - 3
            if `_max_dr' < 1 {
                noisily display as error "Frame '`_fname'' has no data rows (only `_fn' total rows)"
                exit 198
            }
            foreach r of local expanded`f' {
                if `r' < 1 | `r' > `_max_dr' {
                    noisily display as error "Row `r' out of range for frame '`_fname'' (valid: 1-`_max_dr')"
                    exit 198
                }
            }
        }
    }

    * =====================================================================
    * VALIDATE COLUMN COMPATIBILITY
    * =====================================================================
    local fname1 : word 1 of `framelist'
    frame `fname1' {
        qui ds c*
        local _c_vars `r(varlist)'
    }
    local ncols : word count `_c_vars'

    forvalues f = 2/`n_frames' {
        local _fname : word `f' of `framelist'
        frame `_fname' {
            qui ds c*
            local _c_vars_f `r(varlist)'
        }
        local ncols_f : word count `_c_vars_f'
        if `ncols_f' != `ncols' {
            noisily display as error "Column mismatch: '`_fname'' has `ncols_f' data columns, '`fname1'' has `ncols'"
            noisily display as error "All source frames must have the same number of models"
            exit 198
        }
    }

    local n_models = `ncols' / 3

    if mod(`ncols', 3) != 0 {
        noisily display as error "comptab: source frame columns not in multiples of 3"
        restore
        exit 198
    }

    * =====================================================================
    * PARSE SECTION() — BACKSLASH-SEPARATED LABELS
    * =====================================================================
    local has_sections = 0
    if `"`section'"' != "" {
        local has_sections = 1
        local section : subinstr local section " \ " "\", all
        local section : subinstr local section "\  " "\", all
        local section : subinstr local section "  \" "\", all
        tokenize `"`section'"', parse("\")

        local sidx = 1
        local sfidx = 0
        while `"``sidx''"' != "" {
            if `"``sidx''"' != "\" {
                local sfidx = `sfidx' + 1
                local seclabel`sfidx' `"``sidx''"'
            }
            local sidx = `sidx' + 1
        }

        if `sfidx' != `n_frames' {
            noisily display as error "section() requires `n_frames' labels separated by \, found `sfidx'"
            exit 198
        }
    }

    * =====================================================================
    * VALIDATE FILE PATHS
    * =====================================================================
    if `_has_xlsx' {
        if !strmatch("`xlsx'", "*.xlsx") {
            noisily display as error "Excel filename must have .xlsx extension"
            exit 198
        }
        _tabtools_validate_path "`xlsx'" "xlsx()"
    }
    _tabtools_validate_path "`sheet'" "sheet()"

    quietly {

    * =====================================================================
    * BUILD COMPOSITE DATASET
    * =====================================================================
    preserve
    tempfile _build _chunk

    * Extract header rows (model labels + column headers) from first frame
    frame `fname1': qui save `_build', replace
    use `_build', clear
    keep A c*
    keep if _n == 2 | _n == 3
    qui save `_build', replace

    * Track section header row positions (1-based from first data row)
    local _section_rows ""
    local _cum_data_row = 0

    forvalues f = 1/`n_frames' {
        local _fname : word `f' of `framelist'

        * Insert section header row if sections specified
        if `has_sections' {
            local _cum_data_row = `_cum_data_row' + 1
            local _section_rows "`_section_rows' `_cum_data_row'"

            use `_build', clear
            local _nobs = _N + 1
            qui set obs `_nobs'
            qui replace A = `"`seclabel`f''"' in `_nobs'
            forvalues _ci = 1/`ncols' {
                capture qui replace c`_ci' = "" in `_nobs'
            }
            qui save `_build', replace
        }

        * Extract requested data rows from this frame
        frame `_fname': qui save `_chunk', replace
        use `_chunk', clear
        keep A c*

        gen long _orig_n = _n
        gen byte _keep = 0
        foreach r of local expanded`f' {
            local _frame_r = `r' + 3
            qui replace _keep = 1 if _n == `_frame_r'
        }
        keep if _keep
        sort _orig_n
        drop _orig_n _keep

        local _n_added = _N
        local _cum_data_row = `_cum_data_row' + `_n_added'

        qui save `_chunk', replace
        use `_build', clear
        append using `_chunk'
        qui save `_build', replace
    }

    use `_build', clear

    * =====================================================================
    * COMPACT MODE — MERGE ESTIMATE + CI INTO SINGLE COLUMN
    * =====================================================================
    if "`compact'" != "" {
        * Merge estimate (c1,c4,c7,...) + CI (c2,c5,c8,...) for data rows
        * Data rows start at dataset row 3 (rows 1-2 are headers)
        forvalues m = 1(3)`ncols' {
            local _ci_col = `m' + 1
            * Merge: "0.85" + " " + "(0.72, 1.01)" → "0.85 (0.72, 1.01)"
            qui replace c`m' = c`m' + " " + c`_ci_col' if _n >= 3 & c`_ci_col' != ""
            * Update column header to combined label
            local _hdr_est = c`m'[2]
            local _hdr_ci = c`_ci_col'[2]
            qui replace c`m' = "`_hdr_est' `_hdr_ci'" in 2
        }

        * Drop CI columns (c2, c5, c8, ...)
        local _drop_cols ""
        forvalues m = 2(3)`ncols' {
            local _drop_cols "`_drop_cols' c`m'"
        }
        drop `_drop_cols'

        * Renumber remaining c-columns sequentially
        qui ds c*
        local _remaining `r(varlist)'
        local _new_idx = 1
        foreach v of local _remaining {
            if "`v'" != "c`_new_idx'" {
                rename `v' c`_new_idx'
            }
            local _new_idx = `_new_idx' + 1
        }

        local ncols = `_new_idx' - 1
        local n_cols_per_model = 2
    }
    else {
        local n_cols_per_model = 3
    }

    local n = `ncols'

    * =====================================================================
    * APPLY RELABELING
    * =====================================================================
    if `"`relabel'"' != "" {
        tokenize `"`relabel'"'
        local _ri = 1
        while `"``_ri''"' != "" {
            local _rrow = ``_ri''
            local _ri = `_ri' + 1
            if `"``_ri''"' == "" {
                noisily display as error `"relabel() requires pairs: row_number "new label""'
                exit 198
            }
            local _rlbl `"``_ri''"'
            local _ri = `_ri' + 1

            * Data row 1 = dataset row 3 (after 2 header rows)
            local _actual_row = `_rrow' + 2
            if `_actual_row' > _N | `_actual_row' < 3 {
                noisily display as error "relabel() row `_rrow' out of range (valid: 1-`=_N-2')"
                exit 198
            }
            qui replace A = `"`_rlbl'"' in `_actual_row'
        }
    }

    * =====================================================================
    * ADD TITLE ROW
    * =====================================================================
    gen id = _n
    local _count = _N + 1
    qui set obs `_count'
    qui replace id = 0 if id == .
    sort id
    drop id
    gen str244 title = ""
    order title
    qui replace title = "`title'" in 1
    if "`subtitle'" != "" {
        qui replace title = "`title'" + char(10) + "`subtitle'" in 1
    }

    * =====================================================================
    * DETECT REFERENCE ROWS (after title insertion — row numbers = Excel rows)
    * =====================================================================
    local ref_rows ""
    forvalues i = 1(`n_cols_per_model')`n' {
        gen _ref`i' = _n if c`i' == "Reference" & _n >= 4
        levelsof _ref`i', local(_ref`i'_lvls)
        local ref_rows "`ref_rows' `_ref`i'_lvls'"
        drop _ref`i'
    }
    local ref_rows : list uniq ref_rows

    * =====================================================================
    * COLUMN WIDTH CALCULATION
    * =====================================================================
    forvalues i = 1/`n' {
        gen c`i'_length = length(c`i')
    }
    * Compute max header length from row 2 only (model labels)
    local max_header_length = 0
    forvalues i = 1/`n' {
        local _h2len = strlen(c`i'[2])
        if `_h2len' > `max_header_length' local max_header_length = `_h2len'
    }

    forvalues i = 1/`n' {
        replace c`i'_length = . if _n == 2
        egen c`i'_max = max(c`i'_length)
    }

    * Compute minimum estimate column width
    local est_max = 0
    forvalues i = 1(`n_cols_per_model')`n' {
        qui sum c`i'_max, meanonly
        if `r(max)' > `est_max' local est_max = `r(max)'
    }
    local est_min_width = (`est_max' * 3 / 8) + 2

    forvalues i = 1/`=`n'-1' {
        replace c1_max = c`=`i'+1'_max if c`=`i'+1'_max > c1_max
    }
    qui sum c1_max, d
    local max_length = (`r(max)' * 3 / 8) + 2
    if `max_length' < 8 local max_length = 8
    if `max_length' > 60 local max_length = 60

    gen A_length = length(A)
    egen factor_length = max(A_length)
    qui sum factor_length, d
    local factor_length = ceil(`r(max)' * 0.95)

    drop A_length factor_length c*_max c*_length

    * =====================================================================
    * CSV EXPORT
    * =====================================================================
    if "`csv'" != "" {
        _tabtools_validate_path "`csv'" "csv()"
        export delimited using "`csv'", replace
    }

    * =====================================================================
    * CONSOLE DISPLAY
    * =====================================================================
    if !`_has_xlsx' | "`display'" != "" {
        noisily {
            if "`subtitle'" != "" {
                if "`title'" != "" {
                    display as text ""
                    display as result "`title'"
                }
                display as text "`subtitle'"
                _tabtools_console_display `n' "", labelvar(A) datastart(4)
            }
            else {
                _tabtools_console_display `n' `"`title'"', labelvar(A) datastart(4)
            }
        }
    }

    * =====================================================================
    * STORE IN FRAME
    * =====================================================================
    if `"`frame'"' != "" {
        _tabtools_frame_put `"`frame'"'
        local frame "`_frame_name'"
    }

    * =====================================================================
    * EXCEL EXPORT
    * =====================================================================
    local num_rows = _N
    local num_cols = c(k)

    if `_has_xlsx' {
        capture export excel using "`xlsx'", sheet("`sheet'") sheetreplace
        if _rc {
            local _export_rc = _rc
            noisily display as error `"Failed to export to `xlsx', sheet `sheet'"'
            noisily display as error "Check file permissions and that file is not open in Excel"
            restore
            exit `_export_rc'
        }
    }

    * =====================================================================
    * EXCEL FORMATTING — MATA (COLUMN WIDTHS)
    * =====================================================================
    if `_has_xlsx' {

    capture {
        mata: b = xl()
        mata: b.load_book("`xlsx'")
        mata: b.set_sheet("`sheet'")
        mata: b.set_row_height(1,1,30)
        mata: b.set_column_width(1,1,1)
        mata: b.set_column_width(2,2,`factor_length')

        if "`compact'" != "" {
            * Compact: 2 cols per model — est+CI (wider) and p-value
            local _est_width = max(`max_length' * 1.5, `est_min_width')
            forvalues i = 3(2)`=`num_cols'-1' {
                mata: b.set_column_width(`i',`i',`_est_width')
            }
            forvalues i = 4(2)`num_cols' {
                mata: b.set_column_width(`i',`i',`=`max_length'*.875')
            }
        }
        else {
            * Normal: 3 cols per model — estimate, CI, p-value
            local _est_width = max(`max_length' * .55, `est_min_width')
            forvalues i = 3(3)`=`num_cols'-2' {
                mata: b.set_column_width(`i',`i',`_est_width')
            }
            forvalues i = 4(3)`=`num_cols'-1' {
                mata: b.set_column_width(`i',`i',`=`max_length'*1.3')
            }
            forvalues i = 5(3)`num_cols' {
                mata: b.set_column_width(`i',`i',`=`max_length'*.875')
            }
        }

        * Auto-adjust header row height for long model names
        local _data_width = 0
        if "`compact'" != "" {
            local _data_width = `n_models' * (`max_length' * 1.5 + `max_length' * 0.875)
        }
        else {
            local _data_width = `n_models' * (`max_length' * 0.55 + `max_length' * 1.3 + `max_length' * 0.875)
        }
        if `_data_width' > 0 & `max_header_length' * 0.9 > `_data_width' {
            local _headerht = ceil(`max_header_length' * 0.9 / `_data_width')
            mata: b.set_row_height(2,2,`=`_headerht'*15')
        }

        mata: b.close_book()
    }
    if _rc {
        local saved_rc = _rc
        capture mata: b.close_book()
        capture mata: mata drop b
        noisily display as error "Excel formatting (Mata) failed with error `saved_rc'"
        restore
        exit `saved_rc'
    }
    capture mata: mata drop b

    * =====================================================================
    * EXCEL FORMATTING — PUTEXCEL (BORDERS, FONTS, MERGES)
    * =====================================================================
    _tabtools_col_letter `num_cols'
    local letterright "`result'"

    capture {
        putexcel set "`xlsx'", sheet("`sheet'") modify
        local letterleft B
        local lettertwo C
        local n1 2
        local n2 `num_rows'
        local tl1 `letterleft'`n1'
        local tl2 `letterleft'`=1+`n1''
        local tr1 `letterright'`n1'
        local tr2 `letterright'`=1+`n1''
        local bl `letterleft'`n2'
        local br `letterright'`n2'

        * Reference row formatting (merge across model columns, italic)
        foreach row of local ref_rows {
            local col_num = 3
            while `col_num' <= `num_cols' {
                _tabtools_col_letter `col_num'
                local col_letter "`result'"
                _tabtools_col_letter `=`col_num'+`n_cols_per_model'-1'
                local col_letter_end "`result'"
                putexcel (`col_letter'`row':`col_letter_end'`row'), merge hcenter vcenter italic
                local col_num = `col_num' + `n_cols_per_model'
            }
        }

        * Merge model label headers (row 2: one merged cell per model)
        local col_num = 3
        while `col_num' <= `num_cols' {
            _tabtools_col_letter `col_num'
            local col_letter "`result'"
            _tabtools_col_letter `=`col_num'+`n_cols_per_model'-1'
            local col_letter_end "`result'"
            putexcel (`col_letter'`n1':`col_letter_end'`n1'), merge hcenter vcenter bold txtwrap
            if "`borderstyle'" != "academic" {
                putexcel (`col_letter_end'`n1':`col_letter_end'`n2'), border(right, `borderstyle')
            }
            local col_num = `col_num' + `n_cols_per_model'
        }

        * Title row
        putexcel (A1:`letterright'1), merge txtwrap left vcenter bold

        * Header background and formatting
        putexcel (`letterleft'2:`letterright'3), fpattern(solid, "`_headercolor'")
        putexcel (`letterleft'3:`letterright'3), hcenter vcenter bold

        * Top border
        putexcel (`tl1':`tr1'), border(top, `_hborder')
        * Border between model labels and column headers
        putexcel (`lettertwo'`n1':`tr2'), border(top, `_hborder')
        * Bottom of header block
        putexcel (`tl2':`tr2'), border(bottom, `_hborder')

        * Side borders (non-academic)
        if "`borderstyle'" != "academic" {
            putexcel (`tr1':`br'), border(right, `borderstyle')
            putexcel (`tl1':`bl'), border(left, `borderstyle')
            putexcel (`tl1':`bl'), border(right, `borderstyle')
        }

        * Bottom border
        putexcel (`bl':`br'), border(bottom, `_hborder')

        * Section row formatting (bold + border above)
        if "`_section_rows'" != "" {
            foreach _sr of local _section_rows {
                * Section data row _sr → Excel row = _sr + 3
                local _sr_excel = `_sr' + 3
                putexcel (`letterleft'`_sr_excel':`letterright'`_sr_excel'), bold
                putexcel (`letterleft'`_sr_excel':`letterright'`_sr_excel'), border(top, `_hborder')
            }
        }

        * User-specified separator borders
        if "`separator'" != "" {
            foreach _sep of local separator {
                local _sep_excel = `_sep' + 3
                if `_sep_excel' >= 4 & `_sep_excel' <= `num_rows' {
                    putexcel (`letterleft'`_sep_excel':`letterright'`_sep_excel'), border(top, `_hborder')
                }
            }
        }

        * Zebra striping
        if "`zebra'" != "" {
            forvalues _zr = 5(2)`num_rows' {
                putexcel (`letterleft'`_zr':`letterright'`_zr'), fpattern(solid, "`_zebracolor'")
            }
        }

        * Font
        putexcel (A1:`br'), font("`_font'", `_fontsize')
        putexcel (A1:`letterright'1), font("`_font'", `=`_fontsize'+2')

        * Center-align data columns
        putexcel (`lettertwo'4:`letterright'`num_rows'), hcenter

        * Bold significant p-values / highlight significant rows
        if `has_boldp' | `has_highlight' {
            forvalues _m = 1/`n_models' {
                * P-value is the last column in each model group
                local _pcol_data = `_m' * `n_cols_per_model'
                local _pcol_excel = `_pcol_data' + 2
                _tabtools_col_letter `_pcol_excel'
                local _p_letter "`result'"
                forvalues _dr = 4/`num_rows' {
                    capture {
                        local _pstr = c`_pcol_data'[`_dr']
                        local _pstr = strtrim("`_pstr'")
                        if substr("`_pstr'", 1, 1) == "<" {
                            local _pnum = 0
                        }
                        else {
                            local _pnum = real("`_pstr'")
                        }
                        if `_pnum' < . {
                            if `has_boldp' & `_pnum' < `boldp' {
                                putexcel (`_p_letter'`_dr'), bold
                            }
                            if `has_highlight' & `_pnum' < `highlight' {
                                putexcel (`letterleft'`_dr':`letterright'`_dr'), fpattern(solid, "255 255 204")
                            }
                        }
                    }
                }
            }
        }

        * Footnote
        if `"`footnote'"' != "" {
            _tabtools_footnote `"`footnote'"' "`letterright'" `num_rows' "`_font'" `_fontsize'
        }

        putexcel clear
    }
    if _rc {
        local saved_rc = _rc
        capture putexcel clear
        noisily display as error "Excel cell formatting failed with error `saved_rc'"
        restore
        exit `saved_rc'
    }

    } // end if _has_xlsx (Excel formatting)

    clear
    restore

    * Open file if requested
    if `_has_xlsx' & "`open'" != "" _tabtools_open_file "`xlsx'"

    * Console confirmation
    if `_has_xlsx' {
        capture confirm file "`xlsx'"
        if _rc == 0 {
            noisily display as text "Exported " as result "`num_rows'" as text " rows × " as result "`num_cols'" as text " cols to " as result `"`xlsx'"' as text ", sheet " as result `"`sheet'"'
        }
        else {
            noisily display as error "Export command succeeded but file not found"
            exit 601
        }
    }

    * Return results
    if `_has_xlsx' {
        return local xlsx "`xlsx'"
    }
    return local sheet "`sheet'"
    return scalar N_rows = `num_rows'
    return scalar N_cols = `num_cols'
    return scalar N_models = `n_models'
    return scalar N_frames = `n_frames'
    if "`frame'" != "" return local frame "`frame'"

    } // end quietly

    } // end capture noisily
    local _rc = _rc
    set varabbrev `_prev_varabbrev'
    if `_rc' exit `_rc'
end
