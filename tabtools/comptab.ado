*! comptab Version 1.9.10  2026/07/17
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
           frame(name) csv(string)]

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

    * Console output only (no Excel output)
    comptab s1 s2, rows(1 2 \ 1 3/5)
*/

program define comptab, rclass
    version 17.0
    local _orig_varabbrev = c(varabbrev)
    set varabbrev off

    capture noisily {

    capture putexcel close

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
    _tabtools_require_helpers

    syntax anything(name=framelist), [rows(string) ROWNames(string)] ///
        [xlsx(string) excel(string) sheet(string)] ///
        [title(string) FOOTnote(string) COMPact ///
        SEParator(numlist >0 integer sort) SECtion(string asis) ///
        RELAbel(string asis) ///
        THEme(string) BORDERstyle(string) open zebra HEADERShade ///
        HIGHlight(real -1) BOLDp(real -1) ///
        HEADERColor(string) ZEBRAColor(string) ///
        csv(string) MARKdown(string) MDAPPend FRAme(string) EPLOTFrame(string asis) ///
        FOREST EPLOTOptions(string asis) LABELWidth(integer 0)]

    * Label-column width cap (0 -> default 45): keeps a lone verbose label from
    * stretching the whole column; longer labels wrap (text-wrap rule below).
    local _label_width_cap = `labelwidth'
    if `_label_width_cap' <= 0 local _label_width_cap = 45

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
    _tabtools_resolve_format, theme(`theme') borderstyle(`borderstyle') headershade(`headershade') zebra(`zebra')
    _tabtools_resolve_colors, headercolor(`"`headercolor'"') zebracolor(`"`zebracolor'"')

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
    if "`mdappend'" != "" & `"`markdown'"' == "" {
        noisily display as error "mdappend requires markdown()"
        exit 198
    }
    if `"`markdown'"' != "" {
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

    local _eplotframe_name ""
    local _eplotframe_replace 0
    local _eplotframe_temporary 0
    if `"`eplotframe'"' != "" {
        local _ep_spec = strtrim(`"`eplotframe'"')
        gettoken _eplotframe_name _ep_rest : _ep_spec, parse(",")
        local _eplotframe_name = strtrim(`"`_eplotframe_name'"')
        if `"`_eplotframe_name'"' == "" {
            noisily display as error "eplotframe() requires a frame name"
            exit 198
        }
        capture confirm name `_eplotframe_name'
        if _rc {
            noisily display as error "eplotframe() must start with a valid Stata frame name"
            exit 198
        }
        local _ep_rest : subinstr local _ep_rest "," "", all
        local _ep_rest = lower(strtrim(`"`_ep_rest'"'))
        if `"`_ep_rest'"' != "" {
            if `"`_ep_rest'"' == "replace" local _eplotframe_replace 1
            else {
                noisily display as error "eplotframe() only allows the replace suboption"
                exit 198
            }
        }
    }
    if "`forest'" != "" & `"`_eplotframe_name'"' == "" {
        tempname _forest_eplotframe
        local _eplotframe_name "`_forest_eplotframe'"
        local _eplotframe_replace 1
        local _eplotframe_temporary 1
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

    * Resolve the display-frame destination without changing it, then reject
    * every destructive source/current/output alias before any frame is
    * dropped or rebuilt.
	    local _displayframe_name ""
	    local _displayframe_replace 0
	    if `"`frame'"' != "" {
        local _fr_spec = subinstr(strtrim(`"`frame'"'), `""""', "", .)
        gettoken _displayframe_name _fr_rest : _fr_spec, parse(",")
	        local _displayframe_name = strtrim(`"`_displayframe_name'"')
	        local _fr_rest : subinstr local _fr_rest "," "", all
	        local _fr_rest = lower(strtrim(`"`_fr_rest'"'))
        capture confirm name `_displayframe_name'
        if _rc {
            noisily display as error "frame() must start with a valid Stata frame name"
	            exit 198
	        }
	        if `"`_fr_rest'"' != "" {
	            if `"`_fr_rest'"' == "replace" local _displayframe_replace 1
	            else {
	                noisily display as error "frame() only allows the replace suboption"
	                exit 198
	            }
	        }
    }
    if `"`_displayframe_name'"' != "" & ///
        `"`_eplotframe_name'"' != "" & ///
        lower(`"`_displayframe_name'"') == lower(`"`_eplotframe_name'"') {
        noisily display as error "frame() and eplotframe() must name different frames"
        exit 198
    }
    foreach _dest in _displayframe_name _eplotframe_name {
        if `"``_dest''"' != "" & ///
            lower(`"``_dest''"') == lower(`"`c(frame)'"') {
            noisily display as error "output frames cannot replace the current frame"
            exit 198
        }
    }
    forvalues f = 1/`n_frames' {
        local _fname : word `f' of `framelist'
        foreach _dest in _displayframe_name _eplotframe_name {
            if `"``_dest''"' != "" & ///
                lower(`"``_dest''"') == lower(`"`_fname'"') {
                noisily display as error "output frame ``_dest'' aliases source frame `_fname'"
                exit 198
            }
        }
	        local _source_ep_original_`f' ""
	        capture frame `_fname': local _source_ep_original_`f' : char _dta[tabtools_eplotframe]
	        if _rc local _source_ep_original_`f' ""
	        if `"`_source_ep_original_`f''"' != "" {
	            foreach _dest in _displayframe_name _eplotframe_name {
	                if `"``_dest''"' != "" & ///
	                    lower(`"``_dest''"') == lower(`"`_source_ep_original_`f''"') {
	                    noisily display as error "output frame ``_dest'' aliases source companion frame `_source_ep_original_`f''"
	                    exit 198
	                }
	            }
	        }
	    }
	    if `"`_displayframe_name'"' != "" {
	        capture confirm frame `_displayframe_name'
	        if !_rc & !`_displayframe_replace' {
	            noisily display as error "frame `_displayframe_name' already exists; specify frame(`_displayframe_name', replace)"
	            exit 110
	        }
	    }
	    if `"`_eplotframe_name'"' != "" & !`_eplotframe_temporary' {
	        capture confirm frame `_eplotframe_name'
	        if !_rc & !`_eplotframe_replace' {
	            noisily display as error "frame `_eplotframe_name' already exists; specify eplotframe(`_eplotframe_name', replace)"
	            exit 110
	        }
	    }

    * Snapshot every source before any preserve/clear operation. This makes a
    * source that happens to be current behave exactly like any other source.
    local _original_framelist `"`framelist'"'
    local framelist ""
    forvalues f = 1/`n_frames' {
        local _source_original_`f' : word `f' of `_original_framelist'
	        tempname _source_snapshot_`f'
	        frame copy `_source_original_`f'' `_source_snapshot_`f''
	        if `"`_eplotframe_name'"' != "" & `"`_source_ep_original_`f''"' == "" {
	            noisily display as error "eplotframe()/forest requires every source to have a numeric companion frame"
	            exit 459
	        }
	        if `"`_source_ep_original_`f''"' != "" {
	            capture confirm frame `_source_ep_original_`f''
	            if _rc {
	                noisily display as error "source companion frame `_source_ep_original_`f'' not found"
	                exit 111
	            }
	            tempname _source_ep_snapshot_`f'
	            frame copy `_source_ep_original_`f'' `_source_ep_snapshot_`f''
	            frame `_source_snapshot_`f'': char _dta[tabtools_eplotframe] "`_source_ep_snapshot_`f''"
	        }
	        local framelist `"`framelist' `_source_snapshot_`f''"'
	    }
	    local framelist : list clean framelist

	    local _displayframe_target "`_displayframe_name'"
	    local _eplotframe_target ""
	    local _displayframe_build ""
	    local _eplotframe_build ""
	    if `"`_displayframe_target'"' != "" {
	        tempname _displayframe_tmp
	        local _displayframe_build "`_displayframe_tmp'"
	        local frame "`_displayframe_build', replace"
	    }
	    if `"`_eplotframe_name'"' != "" {
	        if `_eplotframe_temporary' {
	            local _eplotframe_build "`_eplotframe_name'"
	        }
	        else {
	            local _eplotframe_target "`_eplotframe_name'"
	            tempname _eplotframe_tmp
	            local _eplotframe_build "`_eplotframe_tmp'"
	            local _eplotframe_name "`_eplotframe_build'"
	            local _eplotframe_replace 1
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

	    * Align model blocks by persisted analytical outcome IDs when they are
	    * unique, then by persisted explicit model labels, and finally by model
	    * command IDs. This permits different predictor rows under the same
	    * outcome while still rejecting ambiguous model attribution.
    local _source_cols_per_model = cond("`source_layout'" == "compact", 2, 3)
    frame `fname1': local _meta_n_ref : char _dta[tabtools_n_models]
    frame `fname1': local _ci_level_ref : char _dta[tabtools_ci_level]
    frame `fname1': local _stat_ids_ref : char _dta[tabtools_statistic_ids]
    if real("`_meta_n_ref'") != `n_models' | `"`_ci_level_ref'"' == "" | ///
        `"`_stat_ids_ref'"' == "" {
        noisily display as error "source frame lacks required tabtools model/CI/statistic provenance"
        exit 459
    }
	    local _can_align_outcome 1
	    local _can_align_label 1
	    local _can_align_model 1
	    forvalues _m = 1/`n_models' {
	        frame `fname1': local _model_id_ref_`_m' : char _dta[tabtools_model_id_`_m']
	        frame `fname1': local _outcome_id_ref_`_m' : char _dta[tabtools_outcome_id_`_m']
	        frame `fname1': local _model_label_ref_`_m' : char _dta[tabtools_model_label_`_m']
	        frame `fname1': local _effect_scale_ref_`_m' : char _dta[tabtools_effect_scale_`_m']
	        local _model_id_ref_`_m' = lower(strtrim(`"`_model_id_ref_`_m''"'))
	        local _outcome_id_ref_`_m' = lower(strtrim(`"`_outcome_id_ref_`_m''"'))
	        local _model_label_ref_`_m' = lower(strtrim(`"`_model_label_ref_`_m''"'))
	        if `"`_model_id_ref_`_m''"' == "" {
	            noisily display as error "source frame has a blank machine-readable model identity"
	            exit 459
	        }
	        if `"`_outcome_id_ref_`_m''"' == "" local _can_align_outcome 0
	        if `"`_model_label_ref_`_m''"' == "" local _can_align_label 0
	        if `_m' > 1 {
	            forvalues _j = 1/`=`_m'-1' {
	                if `"`_outcome_id_ref_`_m''"' == `"`_outcome_id_ref_`_j''"' local _can_align_outcome 0
	                if `"`_model_label_ref_`_m''"' == `"`_model_label_ref_`_j''"' local _can_align_label 0
	                if `"`_model_id_ref_`_m''"' == `"`_model_id_ref_`_j''"' local _can_align_model 0
	            }
	        }
	    }
	    if `_can_align_outcome' local _alignment_kind "outcome"
	    else if `_can_align_label' local _alignment_kind "label"
	    else if `_can_align_model' local _alignment_kind "model"
	    else {
	        noisily display as error "source frame has no unique model/outcome identity for alignment"
	        exit 198
	    }
	    forvalues _m = 1/`n_models' {
	        if "`_alignment_kind'" == "outcome" local _align_id_ref_`_m' `"`_outcome_id_ref_`_m''"'
	        else if "`_alignment_kind'" == "label" local _align_id_ref_`_m' `"`_model_label_ref_`_m''"'
	        else local _align_id_ref_`_m' `"`_model_id_ref_`_m''"'
	    }

    forvalues f = 2/`n_frames' {
        local _fname : word `f' of `framelist'
        frame `_fname': local _meta_n_src : char _dta[tabtools_n_models]
        frame `_fname': local _ci_level_src : char _dta[tabtools_ci_level]
        frame `_fname': local _stat_ids_src : char _dta[tabtools_statistic_ids]
        if real("`_meta_n_src'") != `n_models' | `"`_ci_level_src'"' == "" | ///
            `"`_stat_ids_src'"' == "" {
            noisily display as error "source frame lacks required tabtools model/CI/statistic provenance"
            exit 459
        }
        if abs(real("`_ci_level_src'") - real("`_ci_level_ref'")) > 1e-8 {
            noisily display as error "source frames contain mixed confidence levels"
            exit 198
        }
        if `"`_stat_ids_src'"' != `"`_stat_ids_ref'"' {
            noisily display as error "source frames contain different ordered statistic identities"
            exit 198
        }
	        forvalues _m = 1/`n_models' {
	            frame `_fname': local _model_id_src_`_m' : char _dta[tabtools_model_id_`_m']
	            frame `_fname': local _outcome_id_src_`_m' : char _dta[tabtools_outcome_id_`_m']
	            frame `_fname': local _model_label_src_`_m' : char _dta[tabtools_model_label_`_m']
	            frame `_fname': local _effect_scale_src_`_m' : char _dta[tabtools_effect_scale_`_m']
	            local _model_id_src_`_m' = lower(strtrim(`"`_model_id_src_`_m''"'))
	            local _outcome_id_src_`_m' = lower(strtrim(`"`_outcome_id_src_`_m''"'))
	            local _model_label_src_`_m' = lower(strtrim(`"`_model_label_src_`_m''"'))
	            if `"`_model_id_src_`_m''"' == "" {
	                noisily display as error "source frame has a blank machine-readable model identity"
	                exit 459
	            }
	            if "`_alignment_kind'" == "outcome" local _align_id_src_`_m' `"`_outcome_id_src_`_m''"'
	            else if "`_alignment_kind'" == "label" local _align_id_src_`_m' `"`_model_label_src_`_m''"'
	            else local _align_id_src_`_m' `"`_model_id_src_`_m''"'
	            if `"`_align_id_src_`_m''"' == "" {
	                noisily display as error "source frame lacks the selected alignment identity"
	                exit 459
	            }
	            if `_m' > 1 {
	                forvalues _j = 1/`=`_m'-1' {
	                    if `"`_align_id_src_`_m''"' == `"`_align_id_src_`_j''"' {
	                        noisily display as error `"duplicate `_alignment_kind' identity "`_align_id_src_`_m''" cannot be aligned"'
	                        exit 198
	                    }
                }
            }
        }

        forvalues _target_m = 1/`n_models' {
            local _source_m = 0
            forvalues _candidate_m = 1/`n_models' {
	                if `"`_align_id_ref_`_target_m''"' == ///
	                    `"`_align_id_src_`_candidate_m''"' {
                    local _source_m = `_candidate_m'
                }
            }
            if `_source_m' == 0 {
	                noisily display as error `"`_alignment_kind' identity "`_align_id_ref_`_target_m''" is missing from a source frame"'
                exit 198
            }
            local _model_map_`_target_m' = `_source_m'
            if `"`_outcome_id_ref_`_target_m''"' != ///
                `"`_outcome_id_src_`_source_m''"' {
                noisily display as error "source frames disagree on model outcome identity"
                exit 198
            }
            if lower(`"`_effect_scale_ref_`_target_m''"') != ///
                lower(`"`_effect_scale_src_`_source_m''"') {
                noisily display as error "source frames disagree on model effect scale"
                exit 198
            }
        }

        forvalues _c = 1/`ncols' {
            tempvar _source_copy_`f'_`_c'
            frame `_fname': clonevar `_source_copy_`f'_`_c'' = c`_c'
        }
        forvalues _target_m = 1/`n_models' {
            local _source_m = `_model_map_`_target_m''
            forvalues _stat = 1/`_source_cols_per_model' {
                local _target_c = (`_target_m' - 1) * `_source_cols_per_model' + `_stat'
                local _source_c = (`_source_m' - 1) * `_source_cols_per_model' + `_stat'
                frame `_fname': replace c`_target_c' = ///
                    `_source_copy_`f'_`_source_c''
            }
        }
        frame `_fname': drop `_source_copy_`f'_1'-`_source_copy_`f'_`ncols''

        forvalues _c = 1/`ncols' {
            frame `fname1': local _stat_ref = lower(strtrim(c`_c'[3]))
            frame `_fname': local _stat_src = lower(strtrim(c`_c'[3]))
            if `"`_stat_ref'"' != `"`_stat_src'"' {
                noisily display as error "source frames disagree on effect scale, confidence level, or statistic order"
                exit 198
            }
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
        if !strmatch(lower("`xlsx'"), "*.xlsx") {
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

    if `"`_eplotframe_name'"' != "" {
        capture frame `_eplotframe_name': quietly count
        if _rc == 0 {
            if `_eplotframe_replace' {
                frame drop `_eplotframe_name'
            }
            else {
                noisily display as error "frame `_eplotframe_name' already exists; specify eplotframe(`_eplotframe_name', replace)"
                restore
                exit 110
            }
        }
        frame create `_eplotframe_name' str244 label double estimate double ll double ul ///
            double pvalue int model str244 model_label str24 rowtype str244 section ///
            long source_row str32 source_frame
	        forvalues f = 1/`n_frames' {
	            local _fname : word `f' of `framelist'
	            local _source_label `"`_source_original_`f''"'
	            local _sec_label ""
            if `has_sections' local _sec_label `"`seclabel`f''"'

            * Resolve the source companion frame for this display frame.
            local _src_ep ""
            capture frame `_fname': local _src_ep : char _dta[tabtools_eplotframe]
            local _src_ep_ok = (_rc == 0 & `"`_src_ep'"' != "")
            if `_src_ep_ok' {
                capture frame `_src_ep': quietly count
                if _rc local _src_ep_ok = 0
            }

            * Count the plotted rows this section contributes. A section header
            * that owns exactly one row is redundant in a forest plot, so fold
            * the section label into that single row and skip the header.
            local _n_eff_f = 0
            if `_src_ep_ok' {
                foreach r of local expanded`f' {
                    frame `_src_ep' {
                        forvalues _ep_i = 1/`=_N' {
                            if source_row[`_ep_i'] == `r' local ++_n_eff_f
                        }
                    }
                }
            }
            local _fold = (`has_sections' & `_n_eff_f' == 1)
            if `has_sections' & !`_fold' {
                frame post `_eplotframe_name' (`"`_sec_label'"') (.) (.) (.) (.) ///
	                    (.) ("") ("section") (`"`_sec_label'"') (.) (`"`_source_label'"')
            }

            if `_src_ep_ok' {
                foreach r of local expanded`f' {
                    frame `_src_ep' {
                        local _ep_N = _N
                        forvalues _ep_i = 1/`_ep_N' {
                            if source_row[`_ep_i'] == `r' {
                                local _ep_label = label[`_ep_i']
                                local _ep_est = estimate[`_ep_i']
                                local _ep_ll = ll[`_ep_i']
                                local _ep_ul = ul[`_ep_i']
                                local _ep_p = pvalue[`_ep_i']
                                local _ep_model = model[`_ep_i']
                                local _ep_model_label = model_label[`_ep_i']
                                local _ep_rowtype = rowtype[`_ep_i']
                                local _post_label `"`_ep_label'"'
                                if `_fold' local _post_label `"`_sec_label'"'
                                frame post `_eplotframe_name' (`"`_post_label'"') (`_ep_est') (`_ep_ll') (`_ep_ul') ///
                                    (`_ep_p') (`_ep_model') (`"`_ep_model_label'"') (`"`_ep_rowtype'"') ///
	                                    (`"`_sec_label'"') (`r') (`"`_source_label'"')
                            }
                        }
                    }
                }
            }
        }
        frame `_eplotframe_name': char _dta[tabtools_source] "comptab"
        frame `_eplotframe_name': char _dta[tabtools_ci_level] "`_ci_level_ref'"
        frame `_eplotframe_name': char _dta[tabtools_n_models] "`n_models'"
        frame `_eplotframe_name': char _dta[tabtools_statistic_ids] "`_stat_ids_ref'"
    }

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
    qui replace title = `"`title'"' in 1

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
    if `factor_length' > `_label_width_cap' local factor_length = `_label_width_cap'

    drop A_length factor_length c*_max c*_length

    * =====================================================================
    * CSV EXPORT
    * =====================================================================
    if "`csv'" != "" {
        _tabtools_csv_write using "`csv'", labelvar(A)
    }

    * =====================================================================
    * CONSOLE DISPLAY
    * =====================================================================
    noisily _tabtools_console_display `n' `"`title'"', labelvar(A) datastart(4)

    * =====================================================================
    * MARKDOWN EXPORT
    * =====================================================================
    local _ret_markdown ""
    local _ret_markdown_rows .
    local _ret_markdown_cols .
    if `"`markdown'"' != "" {
        local _mdappend_opt ""
        if "`mdappend'" != "" local _mdappend_opt "append"
        capture noisily _tabtools_markdown_write using `"`markdown'"', ///
            `_mdappend_opt' labelvar(A) datastart(3) title(`"`title'"') footnote(`"`footnote'"') strictheaders
        if _rc {
            local _md_rc = _rc
            noisily display as error "Failed to export Markdown to `markdown'"
            restore
            exit `_md_rc'
        }
        local _ret_markdown `"`markdown'"'
        local _ret_markdown_rows = r(n_rows)
        local _ret_markdown_cols = r(n_cols)
        noisily display as text "Markdown exported to `markdown'"
    }

    * =====================================================================
    * STORE IN FRAME
    * =====================================================================
    if `"`frame'"' != "" {
        _tabtools_frame_put `"`frame'"'
        local frame "`_frame_name'"
	        if `"`_eplotframe_name'"' != "" & !`_eplotframe_temporary' {
	            frame `frame': char _dta[tabtools_eplotframe] "`_eplotframe_target'"
        }
        frame `frame': char _dta[tabtools_source] "comptab"
        frame `frame': char _dta[tabtools_ci_level] "`_ci_level_ref'"
        frame `frame': char _dta[tabtools_n_models] "`n_models'"
        frame `frame': char _dta[tabtools_statistic_ids] "`_stat_ids_ref'"
        forvalues _meta_m = 1/`n_models' {
            frame `frame': char _dta[tabtools_model_id_`_meta_m'] `"`_model_id_ref_`_meta_m''"'
            frame `frame': char _dta[tabtools_outcome_id_`_meta_m'] `"`_outcome_id_ref_`_meta_m''"'
            frame `frame': char _dta[tabtools_effect_scale_`_meta_m'] `"`_effect_scale_ref_`_meta_m''"'
        }
	        return local frame "`frame'"
	    }
	    if `"$TABTOOLS_QA_COMP_STAGE_FAIL"' == "1" {
	        restore
	        error 459
	    }
	    if `"`_ret_markdown'"' != "" {
        return local markdown `"`_ret_markdown'"'
        return scalar markdown_rows = `_ret_markdown_rows'
        return scalar markdown_cols = `_ret_markdown_cols'
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
    return scalar ci_level = real("`_ci_level_ref'")
    if `"`_eplotframe_name'"' != "" & !`_eplotframe_temporary' return local eplotframe "`_eplotframe_name'"

    if `_has_xlsx' {
        capture noisily _tabtools_xlsx_write using "`xlsx'", sheet("`sheet'") book(b)
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

    local _xlsx_widths "1 `factor_length'"
    if `_compact_output' {
        forvalues i = 3(2)`=`num_cols'-1' {
            local _xlsx_widths "`_xlsx_widths' `est_width'"
            local _xlsx_widths "`_xlsx_widths' `p_width'"
        }
    }
    else {
        forvalues i = 3(3)`=`num_cols'-2' {
            local _xlsx_widths "`_xlsx_widths' `est_width'"
            local _xlsx_widths "`_xlsx_widths' `ci_width'"
            local _xlsx_widths "`_xlsx_widths' `p_width'"
        }
    }

    * Auto-adjust header row height for long model names.
    local _headerht = 0
    local _data_width = 0
    if `_compact_output' {
        local _data_width = `n_models' * (`est_width' + `p_width')
    }
    else {
        local _data_width = `n_models' * (`est_width' + `ci_width' + `p_width')
    }
    if `_data_width' > 0 & `max_header_length' * 0.9 > `_data_width' {
        local _headerht = ceil(`max_header_length' * 0.9 / `_data_width')
    }

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
        local _hborder_code = 1
        if "`_hborder'" == "medium" local _hborder_code = 2
        if "`_hborder'" == "thick" local _hborder_code = 3
        if "`_hborder'" == "none" local _hborder_code = 4
        local _vborder_code = 1
        if "`borderstyle'" == "medium" local _vborder_code = 2
        if "`borderstyle'" == "thick" local _vborder_code = 3
        if "`borderstyle'" == "none" local _vborder_code = 4

        tempname _style_rules
        local _style_rule_spec "12 1 1 1 1 30 0 0 0"
        local _width_col = 1
        foreach _width of numlist `_xlsx_widths' {
            local _style_rule_spec `"`_style_rule_spec' | 13 1 1 `_width_col' `_width_col' `_width' 0 0 0"'
            local ++_width_col
        }
        if `_headerht' > 0 {
            local _style_rule_spec `"`_style_rule_spec' | 12 2 2 1 1 `=`_headerht'*15' 0 0 0"'
        }
        * Wrap + top-align the label column so labels exceeding the capped width
        * flow onto extra lines instead of being clipped by the next cell.
        if `num_rows' >= 4 {
            local _style_rule_spec `"`_style_rule_spec' | 4 4 `num_rows' 2 2 0 1 0 0 | 6 4 `num_rows' 2 2 0 3 0 0"'
        }
        local _style_rule_spec `"`_style_rule_spec' | 1 1 `num_rows' 1 `num_cols' `_fontsize' 1 0 0 | 1 1 1 1 `num_cols' `=`_fontsize'+2' 1 0 0 | 14 1 1 1 `num_cols' 0 0 0 0 | 4 1 1 1 1 0 1 0 0 | 5 1 1 1 1 0 1 0 0 | 6 1 1 1 1 0 2 0 0 | 2 1 1 1 1 0 1 0 0"'
        if "`headershade'" != "" {
            local _style_rule_spec `"`_style_rule_spec' | 7 2 3 2 `num_cols' 0 -1 0 0"'
        }
        local _style_rule_spec `"`_style_rule_spec' | 2 3 3 2 `num_cols' 0 1 0 0 | 5 3 3 2 `num_cols' 0 2 0 0 | 6 3 3 2 `num_cols' 0 2 0 0"'

        foreach row of local ref_rows {
            local col_num = 3
            while `col_num' <= `num_cols' {
                local _col_end = `col_num' + `n_cols_per_model' - 1
                local _style_rule_spec `"`_style_rule_spec' | 14 `row' `row' `col_num' `_col_end' 0 0 0 0 | 5 `row' `row' `col_num' `col_num' 0 2 0 0 | 6 `row' `row' `col_num' `col_num' 0 2 0 0 | 3 `row' `row' `col_num' `col_num' 0 1 0 0"'
                local col_num = `col_num' + `n_cols_per_model'
            }
        }

        local col_num = 3
        while `col_num' <= `num_cols' {
            local _col_end = `col_num' + `n_cols_per_model' - 1
            local _style_rule_spec `"`_style_rule_spec' | 14 2 2 `col_num' `_col_end' 0 0 0 0 | 5 2 2 `col_num' `col_num' 0 2 0 0 | 6 2 2 `col_num' `col_num' 0 2 0 0 | 2 2 2 `col_num' `col_num' 0 1 0 0 | 4 2 2 `col_num' `col_num' 0 1 0 0"'
            if "`borderstyle'" != "academic" {
                local _style_rule_spec `"`_style_rule_spec' | 11 2 `num_rows' `_col_end' `_col_end' 0 `_vborder_code' 0 0"'
            }
            local col_num = `col_num' + `n_cols_per_model'
        }

        local _style_rule_spec `"`_style_rule_spec' | 8 2 2 2 `num_cols' 0 `_hborder_code' 0 0 | 8 3 3 3 `num_cols' 0 `_hborder_code' 0 0 | 9 3 3 2 `num_cols' 0 `_hborder_code' 0 0 | 9 `num_rows' `num_rows' 2 `num_cols' 0 `_hborder_code' 0 0"'
        if "`borderstyle'" != "academic" {
            local _style_rule_spec `"`_style_rule_spec' | 11 2 `num_rows' `num_cols' `num_cols' 0 `_vborder_code' 0 0 | 10 2 `num_rows' 2 2 0 `_vborder_code' 0 0 | 11 2 `num_rows' 2 2 0 `_vborder_code' 0 0"'
        }
        if "`_section_rows'" != "" {
            foreach _sr of local _section_rows {
                local _sr_excel = `_sr' + 3
                local _style_rule_spec `"`_style_rule_spec' | 2 `_sr_excel' `_sr_excel' 2 `num_cols' 0 1 0 0 | 8 `_sr_excel' `_sr_excel' 2 `num_cols' 0 `_hborder_code' 0 0"'
            }
        }
        if "`separator'" != "" {
            foreach _sep of local separator {
                local _sep_excel = `_sep' + 3
                if `_sep_excel' >= 4 & `_sep_excel' <= `num_rows' {
                    local _style_rule_spec `"`_style_rule_spec' | 8 `_sep_excel' `_sep_excel' 2 `num_cols' 0 `_hborder_code' 0 0"'
                }
            }
        }
        if "`zebra'" != "" {
            forvalues _zr = 5(2)`num_rows' {
                local _style_rule_spec `"`_style_rule_spec' | 7 `_zr' `_zr' 2 `num_cols' 0 -2 0 0"'
            }
        }
        if `num_rows' >= 4 {
            local _style_rule_spec `"`_style_rule_spec' | 5 4 `num_rows' 3 `num_cols' 0 2 0 0"'
        }
        if `has_boldp' | `has_highlight' {
            forvalues _m = 1/`n_models' {
                local _pcol_excel = `_m' * `n_cols_per_model' + 2
                forvalues _dr = 4/`num_rows' {
                    local _pnum = `_bp_m`_m'_r`_dr''
                    if `_pnum' < . {
                        if `has_boldp' & `_pnum' < `boldp' {
                            local _style_rule_spec `"`_style_rule_spec' | 2 `_dr' `_dr' `_pcol_excel' `_pcol_excel' 0 1 0 0"'
                        }
                        if `has_highlight' & `_pnum' < `highlight' {
                            local _style_rule_spec `"`_style_rule_spec' | 7 `_dr' `_dr' 2 `num_cols' 0 -3 0 0"'
                        }
                    }
                }
            }
        }
        if `"`footnote'"' != "" {
            local _fn_row = `num_rows' + 1
            local _fn_fontsize = max(`_fontsize' - 2, 6)
            mata: b.put_string(`_fn_row', 2, `"`footnote'"')
            local _style_rule_spec `"`_style_rule_spec' | 14 `_fn_row' `_fn_row' 2 `num_cols' 0 0 0 0 | 5 `_fn_row' `_fn_row' 2 2 0 1 0 0 | 6 `_fn_row' `_fn_row' 2 2 0 2 0 0 | 4 `_fn_row' `_fn_row' 2 2 0 1 0 0 | 1 `_fn_row' `_fn_row' 2 2 `_fn_fontsize' 1 0 0 | 3 `_fn_row' `_fn_row' 2 2 0 1 0 0"'
        }

        _tabtools_xlsx_build_styles, matrix(`_style_rules') ///
            rules(`_style_rule_spec') cols(9)
        _tabtools_xlsx_apply_styles, book(b) sheet("`sheet'") ///
            rules(`_style_rules') font("`_font'") ///
            color1("`_headercolor'") color2("`_zebracolor'") ///
            color3("255 255 204")
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

    local _methods "Composite table assembled from `n_frames' source frame(s) with `n_models' model column(s)."
    if `num_rows' > 0 {
        local _methods "`_methods' The final table contains `num_rows' rows and `num_cols' columns."
    }
    return local methods "`_methods'"

    if "`forest'" != "" {
        capture which eplot
        local _which_eplot_rc = _rc
        if `_which_eplot_rc' {
            noisily display as error "forest requires eplot"
            noisily display as error `"Install with: net install eplot, from("https://raw.githubusercontent.com/tpcopeland/Stata-Tools/main/eplot") replace"'
            if `_eplotframe_temporary' capture frame drop `_eplotframe_name'
            exit 111
        }
        else {
            local _eplotoptions_clean = strtrim(`"`eplotoptions'"')
            if substr(`"`_eplotoptions_clean'"', 1, 1) == "," {
                local _eplotoptions_clean = strtrim(substr(`"`_eplotoptions_clean'"', 2, .))
            }
            frame `_eplotframe_name': quietly count if rowtype == "effect"
            if r(N) == 0 {
                noisily display as error "forest requires an eplotframe with effect rows"
                if `_eplotframe_temporary' capture frame drop `_eplotframe_name'
                exit 2000
            }
            capture noisily eplot, frame(`_eplotframe_name') labels(label) rowtype(rowtype) ///
                style(forest) effect("Effect estimate") values `_eplotoptions_clean'
            local _forest_rc = _rc
            if `_forest_rc' {
                if `_eplotframe_temporary' capture frame drop `_eplotframe_name'
                exit `_forest_rc'
            }
        }
        if `_eplotframe_temporary' capture frame drop `_eplotframe_name'
    }

	    * Open file if requested
	    if `_xlsx_ok' & "`open'" != "" _tabtools_open_file "`xlsx'"

	    * Commit staged caller-visible frames only after forest/file outputs pass.
	    if `"`_eplotframe_build'"' != "" & !`_eplotframe_temporary' {
	        capture confirm frame `_eplotframe_target'
	        if !_rc frame drop `_eplotframe_target'
	        frame rename `_eplotframe_build' `_eplotframe_target'
	        local _eplotframe_build ""
	    }
	    if `"`_displayframe_build'"' != "" {
	        capture confirm frame `_displayframe_target'
	        if !_rc frame drop `_displayframe_target'
	        frame rename `_displayframe_build' `_displayframe_target'
	        local _displayframe_build ""
	    }

	    return clear
	    if `"`_displayframe_target'"' != "" return local frame "`_displayframe_target'"
    if `"`_ret_markdown'"' != "" {
        return local markdown `"`_ret_markdown'"'
        return scalar markdown_rows = `_ret_markdown_rows'
        return scalar markdown_cols = `_ret_markdown_cols'
    }
    return scalar N_rows = `num_rows'
    return scalar N_cols = `num_cols'
    return scalar N_models = `n_models'
    return scalar N_frames = `n_frames'
    return scalar ci_level = real("`_ci_level_ref'")
	    if `"`_eplotframe_target'"' != "" & !`_eplotframe_temporary' return local eplotframe "`_eplotframe_target'"
    if `_xlsx_ok' {
        return local xlsx "`xlsx'"
        return local sheet "`sheet'"
    }
    return local methods "`_methods'"

    } // end quietly

	    } // end capture noisily
	    local _rc = _rc
	    if `_rc' {
	        if `"`_displayframe_build'"' != "" capture frame drop `_displayframe_build'
	        if `"`_eplotframe_build'"' != "" capture frame drop `_eplotframe_build'
	    }
    set varabbrev `_orig_varabbrev'
    if `_rc' exit `_rc'
end
