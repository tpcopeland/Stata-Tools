*! comptab Version 1.0.13  2026/04/27
*! Compose publication tables from regtab/effecttab output frames
*! Author: Timothy P Copeland, Karolinska Institutet
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
    local _orig_varabbrev = c(varabbrev)
    set varabbrev off

    capture noisily {

    * Auto-load shared helper programs if not already in memory
    capture _tabtools_helpers_ready
    if _rc {
        capture findfile _tabtools_common.ado
        if _rc == 0 {
            run "`r(fn)'"
            capture _tabtools_helpers_ready
            if _rc {
                noisily display as error "_tabtools_common.ado failed to load fully; reinstall tabtools"
                exit 111
            }
        }
        else {
            noisily display as error "_tabtools_common.ado not found; reinstall tabtools"
            exit 111
        }
    }

    syntax anything(name=framelist), [rows(string) ROWNames(string)] ///
        [xlsx(string) excel(string) sheet(string)] ///
        [title(string) FOOTnote(string) COMPact ///
        SEParator(numlist >0 integer sort) SECtion(string asis) ///
        RELAbel(string asis) ///
        THEme(string) BORDERstyle(string) open zebra ///
        HIGHlight(real -1) BOLDp(real -1) ///
        HEADERColor(string) ZEBRAColor(string) ///
        csv(string) FRAme(string) DISplay]

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
    if "`open'" != "" & !`_has_xlsx' {
        noisily display as error "open requires xlsx() or excel()"
        exit 198
    }

    * Resolve persistent defaults
    if `boldp' == -1 & "$TABTOOLS_BOLDP" != "" local boldp = $TABTOOLS_BOLDP

    * Validate sheet name for Excel constraints
    _tabtools_validate_sheet "`sheet'" "sheet()"

    * =====================================================================
    * RESOLVE FORMATTING OPTIONS
    * =====================================================================
    _tabtools_resolve_format, theme(`theme') borderstyle(`borderstyle')

    local _headercolor "219 229 241"
    local _zebracolor "237 242 249"
    if "$TABTOOLS_HEADERCOLOR" != "" local _headercolor "$TABTOOLS_HEADERCOLOR"
    if "$TABTOOLS_ZEBRACOLOR" != "" local _zebracolor "$TABTOOLS_ZEBRACOLOR"
    if "`headercolor'" != "" local _headercolor "`headercolor'"
    if "`zebracolor'" != "" local _zebracolor "`zebracolor'"
    _tabtools_validate_color "`_headercolor'" "headercolor()"
    _tabtools_validate_color "`_zebracolor'" "zebracolor()"

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
        * Parse rownames() — backslash-separated rendered-label patterns
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
                    noisily display as error "rownames() matches rendered row labels in column A, not source variable names"
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
    local source_layout ""
    local n_models = .
    local _looks_standard = 0
    local _looks_compact = 0

    if mod(`ncols', 3) == 0 {
        local _looks_standard = 1
        forvalues _c = 1(3)`ncols' {
            local _ci_var c`=`_c'+1'
            local _p_var c`=`_c'+2'
            frame `fname1' {
                local _hdr_ci = lower(strtrim(`_ci_var'[3]))
                local _hdr_p = lower(strtrim(`_p_var'[3]))
            }
            if strpos(`"`_hdr_ci'"', "ci") == 0 | substr(`"`_hdr_p'"', 1, 1) != "p" {
                local _looks_standard = 0
            }
        }
    }
    if mod(`ncols', 2) == 0 {
        local _looks_compact = 1
        forvalues _c = 1(2)`ncols' {
            local _p_var c`=`_c'+1'
            frame `fname1' {
                local _hdr_est = lower(strtrim(c`_c'[3]))
                local _hdr_p = lower(strtrim(`_p_var'[3]))
            }
            if strpos(`"`_hdr_est'"', "ci") == 0 | substr(`"`_hdr_p'"', 1, 1) != "p" {
                local _looks_compact = 0
            }
        }
    }

    if `_looks_standard' & !`_looks_compact' {
        local source_layout "standard"
        local n_models = `ncols' / 3
    }
    else if `_looks_compact' & !`_looks_standard' {
        local source_layout "compact"
        local n_models = `ncols' / 2
    }
    else {
        noisily display as error "Frame '`fname1'' has unsupported column structure"
        noisily display as error "Expected 3 columns per model (standard) or 2 columns per model (compact)"
        exit 198
    }

    forvalues f = 2/`n_frames' {
        local _fname : word `f' of `framelist'
        frame `_fname' {
            qui ds c*
            local _c_vars_f `r(varlist)'
        }
        local ncols_f : word count `_c_vars_f'
        local source_layout_f ""
        local n_models_f = .
        local _looks_standard_f = 0
        local _looks_compact_f = 0

        if mod(`ncols_f', 3) == 0 {
            local _looks_standard_f = 1
            forvalues _c = 1(3)`ncols_f' {
                local _ci_var c`=`_c'+1'
                local _p_var c`=`_c'+2'
                frame `_fname' {
                    local _hdr_ci = lower(strtrim(`_ci_var'[3]))
                    local _hdr_p = lower(strtrim(`_p_var'[3]))
                }
                if strpos(`"`_hdr_ci'"', "ci") == 0 | substr(`"`_hdr_p'"', 1, 1) != "p" {
                    local _looks_standard_f = 0
                }
            }
        }
        if mod(`ncols_f', 2) == 0 {
            local _looks_compact_f = 1
            forvalues _c = 1(2)`ncols_f' {
                local _p_var c`=`_c'+1'
                frame `_fname' {
                    local _hdr_est = lower(strtrim(c`_c'[3]))
                    local _hdr_p = lower(strtrim(`_p_var'[3]))
                }
                if strpos(`"`_hdr_est'"', "ci") == 0 | substr(`"`_hdr_p'"', 1, 1) != "p" {
                    local _looks_compact_f = 0
                }
            }
        }

        if `_looks_standard_f' & !`_looks_compact_f' {
            local source_layout_f "standard"
            local n_models_f = `ncols_f' / 3
        }
        else if `_looks_compact_f' & !`_looks_standard_f' {
            local source_layout_f "compact"
            local n_models_f = `ncols_f' / 2
        }
        else {
            noisily display as error "Frame '`_fname'' has unsupported column structure"
            noisily display as error "Expected 3 columns per model (standard) or 2 columns per model (compact)"
            exit 198
        }

        if `ncols_f' != `ncols' {
            noisily display as error "Column mismatch: '`_fname'' has `ncols_f' data columns, '`fname1'' has `ncols'"
            noisily display as error "All source frames must have the same number of models"
            exit 198
        }
        if "`source_layout_f'" != "`source_layout'" | `n_models_f' != `n_models' {
            noisily display as error "All source frames must share the same layout"
            noisily display as error "Frame '`fname1'' is `source_layout' with `n_models' model(s); '`_fname'' is `source_layout_f' with `n_models_f' model(s)"
            exit 198
        }
    }
    local _source_compact = ("`source_layout'" == "compact")
    local _compact_output = (`_source_compact' | "`compact'" != "")

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
    if !`_source_compact' & "`compact'" != "" {
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
    else if `_source_compact' {
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
                restore
                exit 198
            }
            local _rlbl `"``_ri''"'
            local _ri = `_ri' + 1

            * Data row 1 = dataset row 3 (after 2 header rows)
            local _actual_row = `_rrow' + 2
            if `_actual_row' > _N | `_actual_row' < 3 {
                noisily display as error "relabel() row `_rrow' out of range (valid: 1-`=_N-2')"
                restore
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

    * Compute direct widths from exported text length by column role
    local est_max = 0
    local ci_max = 0
    local p_max = 0
    if `_compact_output' {
        forvalues i = 1(2)`n' {
            qui sum c`i'_max, meanonly
            if `r(max)' > `est_max' local est_max = `r(max)'
        }
        forvalues i = 2(2)`n' {
            qui sum c`i'_max, meanonly
            if `r(max)' > `p_max' local p_max = `r(max)'
        }
    }
    else {
        forvalues i = 1(3)`n' {
            qui sum c`i'_max, meanonly
            if `r(max)' > `est_max' local est_max = `r(max)'
        }
        forvalues i = 2(3)`n' {
            qui sum c`i'_max, meanonly
            if `r(max)' > `ci_max' local ci_max = `r(max)'
        }
        forvalues i = 3(3)`n' {
            qui sum c`i'_max, meanonly
            if `r(max)' > `p_max' local p_max = `r(max)'
        }
    }

    local est_width = ceil(`est_max' * 0.85) + 2
    if `_compact_output' {
        if `est_width' < 16 local est_width = 16
        if `est_width' > 34 local est_width = 34
    }
    else {
        if `est_width' < 8 local est_width = 8
        if `est_width' > 22 local est_width = 22
    }

    local ci_width = 0
    if !`_compact_output' {
        local ci_width = ceil(`ci_max' * 0.85) + 2
        if `ci_width' < 16 local ci_width = 16
        if `ci_width' > 34 local ci_width = 34
    }

    local p_width = ceil(`p_max' * 0.85) + 2
    if `p_width' < 8 local p_width = 8
    if `p_width' > 12 local p_width = 12

    gen A_length = length(A)
    egen factor_length = max(A_length)
    qui sum factor_length, d
    local factor_length = ceil(r(max) * 0.95) + 2

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
        noisily _tabtools_console_display `n' `"`title'"', labelvar(A) datastart(4)
    }

    * =====================================================================
    * STORE IN FRAME
    * =====================================================================
    if `"`frame'"' != "" {
        _tabtools_frame_put `"`frame'"'
        local frame "`_frame_name'"
        return local frame "`frame'"
    }

    * =====================================================================
    * EXCEL EXPORT
    * =====================================================================
    local num_rows = _N
    local num_cols = c(k)
    local _xlsx_ok 0

    * Return results before any file-writing failure can abort the command
    return scalar N_rows = `num_rows'
    return scalar N_cols = `num_cols'
    return scalar N_models = `n_models'
    return scalar N_frames = `n_frames'

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

        if `_compact_output' {
            * Compact: 2 cols per model — est+CI and p-value
            forvalues i = 3(2)`=`num_cols'-1' {
                mata: b.set_column_width(`i',`i',`est_width')
            }
            forvalues i = 4(2)`num_cols' {
                mata: b.set_column_width(`i',`i',`p_width')
            }
        }
        else {
            * Normal: 3 cols per model — estimate, CI, p-value
            forvalues i = 3(3)`=`num_cols'-2' {
                mata: b.set_column_width(`i',`i',`est_width')
            }
            forvalues i = 4(3)`=`num_cols'-1' {
                mata: b.set_column_width(`i',`i',`ci_width')
            }
            forvalues i = 5(3)`num_cols' {
                mata: b.set_column_width(`i',`i',`p_width')
            }
        }

        * Auto-adjust header row height for long model names
        local _data_width = 0
        if `_compact_output' {
            local _data_width = `n_models' * (`est_width' + `p_width')
        }
        else {
            local _data_width = `n_models' * (`est_width' + `ci_width' + `p_width')
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
    * EXCEL FORMATTING — Mata xl()
    * =====================================================================

    * Pre-extract p-values for conditional formatting
    if `has_boldp' | `has_highlight' {
        forvalues _m = 1/`n_models' {
            local _pcol_data = `_m' * `n_cols_per_model'
            local _pcol_excel = `_pcol_data' + 2
            forvalues _dr = 4/`num_rows' {
                capture {
                    local _pstr = c`_pcol_data'[`_dr']
                    local _pstr = strtrim("`_pstr'")
                    if substr("`_pstr'", 1, 1) == "<" {
                        local _bp_m`_m'_r`_dr' = 0
                    }
                    else {
                        local _bp_m`_m'_r`_dr' = real("`_pstr'")
                    }
                }
                if _rc local _bp_m`_m'_r`_dr' = .
            }
        }
    }

    capture {
        mata: b = xl()
        mata: b.load_book("`xlsx'")
        mata: b.set_sheet("`sheet'")

        * Font
        mata: b.set_font((1,`num_rows'), (1,`num_cols'), "`_font'", `_fontsize')
        mata: b.set_font((1,1), (1,`num_cols'), "`_font'", `=`_fontsize'+2')

        * Title row
        mata: b.set_sheet_merge("`sheet'", (1,1), (1,`num_cols'))
        mata: b.set_text_wrap(1, 1, "on")
        mata: b.set_horizontal_align(1, 1, "left")
        mata: b.set_vertical_align(1, 1, "center")
        mata: b.set_font_bold(1, 1, "on")

        * Header background (rows 2-3)
        mata: b.set_fill_pattern((2,3), (2,`num_cols'), "solid", "`_headercolor'")
        mata: b.set_font_bold(3, (2,`num_cols'), "on")
        mata: b.set_horizontal_align(3, (2,`num_cols'), "center")
        mata: b.set_vertical_align(3, (2,`num_cols'), "center")

        * Reference rows
        foreach row of local ref_rows {
            local col_num = 3
            while `col_num' <= `num_cols' {
                local _col_end = `col_num' + `n_cols_per_model' - 1
                mata: b.set_sheet_merge("`sheet'", (`row',`row'), (`col_num',`_col_end'))
                mata: b.set_horizontal_align(`row', `col_num', "center")
                mata: b.set_vertical_align(`row', `col_num', "center")
                mata: b.set_font_italic(`row', `col_num', "on")
                local col_num = `col_num' + `n_cols_per_model'
            }
        }

        * Model headers (row 2)
        local col_num = 3
        while `col_num' <= `num_cols' {
            local _col_end = `col_num' + `n_cols_per_model' - 1
            mata: b.set_sheet_merge("`sheet'", (2,2), (`col_num',`_col_end'))
            mata: b.set_horizontal_align(2, `col_num', "center")
            mata: b.set_vertical_align(2, `col_num', "center")
            mata: b.set_font_bold(2, `col_num', "on")
            mata: b.set_text_wrap(2, `col_num', "on")
            if "`borderstyle'" != "academic" {
                mata: b.set_right_border((2,`num_rows'), `_col_end', "`borderstyle'")
            }
            local col_num = `col_num' + `n_cols_per_model'
        }

        * Horizontal borders
        mata: b.set_top_border(2, (2,`num_cols'), "`_hborder'")
        mata: b.set_top_border(3, (3,`num_cols'), "`_hborder'")
        mata: b.set_bottom_border(3, (2,`num_cols'), "`_hborder'")
        mata: b.set_bottom_border(`num_rows', (2,`num_cols'), "`_hborder'")

        * Vertical borders (non-academic)
        if "`borderstyle'" != "academic" {
            mata: b.set_right_border((2,`num_rows'), `num_cols', "`borderstyle'")
            mata: b.set_left_border((2,`num_rows'), 2, "`borderstyle'")
            mata: b.set_right_border((2,`num_rows'), 2, "`borderstyle'")
        }

        * Section rows
        if "`_section_rows'" != "" {
            foreach _sr of local _section_rows {
                local _sr_excel = `_sr' + 3
                mata: b.set_font_bold(`_sr_excel', (2,`num_cols'), "on")
                mata: b.set_top_border(`_sr_excel', (2,`num_cols'), "`_hborder'")
            }
        }

        * Separator borders
        if "`separator'" != "" {
            foreach _sep of local separator {
                local _sep_excel = `_sep' + 3
                if `_sep_excel' >= 4 & `_sep_excel' <= `num_rows' {
                    mata: b.set_top_border(`_sep_excel', (2,`num_cols'), "`_hborder'")
                }
            }
        }

        * Zebra striping
        if "`zebra'" != "" {
            forvalues _zr = 5(2)`num_rows' {
                mata: b.set_fill_pattern(`_zr', (2,`num_cols'), "solid", "`_zebracolor'")
            }
        }

        * Center-align data columns
        if `num_rows' >= 4 {
            mata: b.set_horizontal_align((4,`num_rows'), (3,`num_cols'), "center")
        }

        * Bold p-values / highlight
        if `has_boldp' | `has_highlight' {
            forvalues _m = 1/`n_models' {
                local _pcol_excel = `_m' * `n_cols_per_model' + 2
                forvalues _dr = 4/`num_rows' {
                    local _pnum = `_bp_m`_m'_r`_dr''
                    if `_pnum' < . {
                        if `has_boldp' & `_pnum' < `boldp' {
                            mata: b.set_font_bold(`_dr', `_pcol_excel', "on")
                        }
                        if `has_highlight' & `_pnum' < `highlight' {
                            mata: b.set_fill_pattern(`_dr', (2,`num_cols'), "solid", "255 255 204")
                        }
                    }
                }
            }
        }

        * Footnote
        if `"`footnote'"' != "" {
            local _fn_row = `num_rows' + 1
            local _fn_fontsize = max(`_fontsize' - 2, 6)
            mata: b.put_string(`_fn_row', 2, `"`footnote'"')
            mata: b.set_sheet_merge("`sheet'", (`_fn_row',`_fn_row'), (2,`num_cols'))
            mata: b.set_horizontal_align(`_fn_row', 2, "left")
            mata: b.set_vertical_align(`_fn_row', 2, "center")
            mata: b.set_text_wrap(`_fn_row', 2, "on")
            mata: b.set_font(`_fn_row', 2, "`_font'", `_fn_fontsize')
            mata: b.set_font_italic(`_fn_row', 2, "on")
        }

        mata: b.close_book()
    }
    if _rc {
        local saved_rc = _rc
        capture mata: b.close_book()
        capture mata: mata drop b
        noisily display as error "Excel formatting failed with error `saved_rc'"
        restore
        exit `saved_rc'
    }
    capture mata: mata drop b

    } // end if _has_xlsx (Excel formatting)

    clear
    restore

    * Console confirmation
    if `_has_xlsx' {
        capture confirm file "`xlsx'"
        if _rc == 0 {
            local _xlsx_ok 1
            noisily display as text "Exported " as result "`num_rows'" as text " rows × " as result "`num_cols'" as text " cols to " as result `"`xlsx'"' as text ", sheet " as result `"`sheet'"'
        }
        else {
            noisily display as error "Export command succeeded but file not found"
            exit 601
        }
    }

    if `_xlsx_ok' {
        return local xlsx "`xlsx'"
        return local sheet "`sheet'"
    }

    * Open file if requested
    if `_xlsx_ok' & "`open'" != "" _tabtools_open_file "`xlsx'"

    } // end quietly

    } // end capture noisily
    local _rc = _rc
    set varabbrev `_orig_varabbrev'
    if `_rc' exit `_rc'
end
