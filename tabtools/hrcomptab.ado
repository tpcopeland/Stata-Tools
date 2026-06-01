*! hrcomptab Version 1.3.1  2026/05/27
*! Compose stratetab and regtab frames into Table 2-style survival tables
*! Author: Timothy P Copeland, Karolinska Institutet
*! Program class: rclass

program define hrcomptab, rclass
    version 17.0
    local _orig_varabbrev = c(varabbrev)
    set varabbrev off

    tempfile _userdata_outer
    local _userdata_path "`_userdata_outer'"

    quietly save "`_userdata_path'", emptyok

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

        syntax anything(name=rateframe) , MODELFRAMES(string asis) ///
            [rows(string asis) ROWNames(string asis) ///
            XLSX(string) EXCEL(string) SHEET(string) ///
            TITLE(string) FOOTnote(string) ///
            EFFect(string) REFLabel(string) ///
            BORDERstyle(string) THEme(string) ///
            open zebra HEADERShade ///
            HEADERColor(string) ZEBRAColor(string) ///
            CSV(string) FRAme(string) DISplay]

        * rows() xor rownames()
        if `"`rows'"' == "" & `"`rownames'"' == "" {
            display as error "One of rows() or rownames() is required"
            exit 198
        }
        if `"`rows'"' != "" & `"`rownames'"' != "" {
            display as error "rows() and rownames() may not be combined"
            exit 198
        }
        local _use_rownames = (`"`rownames'"' != "")

        * Resolve core options
        if "`xlsx'" == "" & "`excel'" != "" local xlsx "`excel'"
        local _has_xlsx = (`"`xlsx'"' != "")
        if "`sheet'" == "" local sheet "Composite"
        if "`effect'" == "" local effect "aHR"
        if "`reflabel'" == "" local reflabel "Reference"

        if "`open'" != "" & !`_has_xlsx' {
            display as error "open requires xlsx() or excel()"
            exit 198
        }

        if `_has_xlsx' {
            if !strmatch("`xlsx'", "*.xlsx") {
                display as error "xlsx() must have .xlsx extension"
                exit 198
            }
            _tabtools_validate_path "`xlsx'" "xlsx()"
        }
        if "`csv'" != "" _tabtools_validate_path "`csv'" "csv()"
        _tabtools_validate_sheet "`sheet'" "sheet()"

        * Resolve formatting
        _tabtools_resolve_format, theme(`theme') borderstyle(`borderstyle') ///
            headershade(`headershade') zebra(`zebra')

        _tabtools_resolve_colors, headercolor(`"`headercolor'"') zebracolor(`"`zebracolor'"')

        * Validate rate frame
        capture frame `rateframe': quietly count
        if _rc {
            display as error "Rate frame '`rateframe'' not found"
            display as error "Hint: create it with stratetab, frame(name)"
            exit 111
        }

        frame `rateframe' {
            quietly ds c*
            local _rate_cvars `r(varlist)'
            local _rate_cols : word count `r(varlist)'
            local _rate_rows = _N
            capture confirm variable title
            local _rate_has_title = (_rc == 0)
            if `_rate_has_title' {
                local _rate_title = title[1]
            }
            else {
                local _rate_title ""
            }
        }

        if `_rate_cols' < 4 {
            display as error "Rate frame '`rateframe'' is too narrow to be stratetab output"
            exit 198
        }
        if mod(`_rate_cols' - 1, 3) != 0 {
            display as error "Rate frame '`rateframe'' must come from stratetab without rateratio"
            display as error "Expected 1 label column plus 3 columns per outcome"
            exit 198
        }

        local outcomes = (`_rate_cols' - 1) / 3
        if `outcomes' < 1 {
            display as error "Rate frame '`rateframe'' contains no outcome columns"
            exit 198
        }
        if `_rate_rows' < 5 {
            display as error "Rate frame '`rateframe'' has too few rows"
            exit 198
        }

        * Detect section rows and infer reference rows from the stratetab scaffold
        local section_rows ""
        local ref_rows ""
        local nonref_rows ""
        local _seen_ref = 0

        forvalues _r = 4/`_rate_rows' {
            frame `rateframe' {
                local _rate_lab = c1[`_r']
                local _rate_c2 = c2[`_r']
            }

            local _rate_lab_trim = strtrim(`"`_rate_lab'"')
            if `"`_rate_lab_trim'"' == "" continue

            if !strmatch(`"`_rate_lab'"', "   *") & `"`_rate_c2'"' == "" {
                local section_rows "`section_rows' `_r'"
                local _seen_ref = 0
                continue
            }

            if strmatch(`"`_rate_lab'"', "   *") {
                if !`_seen_ref' {
                    local ref_rows "`ref_rows' `_r'"
                    local _seen_ref = 1
                }
                else {
                    local nonref_rows "`nonref_rows' `_r'"
                }
            }
        }

        local n_sections : word count `section_rows'
        local n_nonref : word count `nonref_rows'
        if `n_sections' == 0 {
            display as error "Rate frame '`rateframe'' has no section header rows"
            exit 198
        }
        if `n_nonref' == 0 {
            display as error "Rate frame '`rateframe'' has no non-reference rows to fill"
            exit 198
        }

        * Validate model frames
        local n_frames : word count `modelframes'
        if `n_frames' == 0 {
            display as error "modelframes() requires at least one frame"
            exit 198
        }

        forvalues _f = 1/`n_frames' {
            local _fname : word `_f' of `modelframes'
            capture frame `_fname': quietly count
            if _rc {
                display as error "Model frame '`_fname'' not found"
                display as error "Hint: create it with regtab, frame(name)"
                exit 111
            }
            capture frame `_fname': confirm variable A
            if _rc {
                display as error "Model frame '`_fname'' is missing variable A"
                display as error "Hint: source frames must come from regtab"
                exit 111
            }
        }

        local _fname1 : word 1 of `modelframes'
        frame `_fname1' {
            quietly ds c*
            local _model_cvars `r(varlist)'
            local _model_cols : word count `r(varlist)'
        }

        local model_mode ""
        local _cols_per_model = .
        local n_models = .
        local _looks_standard = 0
        local _looks_compact = 0
        if mod(`_model_cols', 3) == 0 {
            local _looks_standard = 1
            forvalues _c = 1(3)`_model_cols' {
                local _ci_var c`=`_c'+1'
                local _p_var c`=`_c'+2'
                frame `_fname1' {
                    local _hdr_ci = lower(strtrim(`_ci_var'[3]))
                    local _hdr_p = lower(strtrim(`_p_var'[3]))
                }
                if strpos(`"`_hdr_ci'"', "ci") == 0 | substr(`"`_hdr_p'"', 1, 1) != "p" {
                    local _looks_standard = 0
                }
            }
        }
        if mod(`_model_cols', 2) == 0 {
            local _looks_compact = 1
            forvalues _c = 1(2)`_model_cols' {
                local _p_var c`=`_c'+1'
                frame `_fname1' {
                    local _hdr_est = lower(strtrim(c`_c'[3]))
                    local _hdr_p = lower(strtrim(`_p_var'[3]))
                }
                if strpos(`"`_hdr_est'"', "ci") == 0 | substr(`"`_hdr_p'"', 1, 1) != "p" {
                    local _looks_compact = 0
                }
            }
        }

        if `_looks_standard' & !`_looks_compact' {
            local model_mode "standard"
            local _cols_per_model = 3
            local n_models = `_model_cols' / 3
        }
        else if `_looks_compact' & !`_looks_standard' {
            local model_mode "compact"
            local _cols_per_model = 2
            local n_models = `_model_cols' / 2
        }
        else {
            display as error "Model frame '`_fname1'' has unsupported column structure"
            display as error "Expected 2 or 3 columns per model block from regtab"
            exit 198
        }

        if `n_models' != `outcomes' {
            display as error "Model columns (`n_models') must match rate outcomes (`outcomes')"
            exit 198
        }

        forvalues _f = 2/`n_frames' {
            local _fname : word `_f' of `modelframes'
            frame `_fname' {
                quietly ds c*
                local _model_cvars_f `r(varlist)'
                local _model_cols_f : word count `r(varlist)'
            }

            local model_mode_f ""
            local n_models_f = .
            local _looks_standard_f = 0
            local _looks_compact_f = 0
            if mod(`_model_cols_f', 3) == 0 {
                local _looks_standard_f = 1
                forvalues _c = 1(3)`_model_cols_f' {
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
            if mod(`_model_cols_f', 2) == 0 {
                local _looks_compact_f = 1
                forvalues _c = 1(2)`_model_cols_f' {
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
                local model_mode_f "standard"
                local n_models_f = `_model_cols_f' / 3
            }
            else if `_looks_compact_f' & !`_looks_standard_f' {
                local model_mode_f "compact"
                local n_models_f = `_model_cols_f' / 2
            }
            else {
                display as error "Model frame '`_fname'' has unsupported column structure"
                display as error "Expected 2 or 3 columns per model block from regtab"
                exit 198
            }

            if "`model_mode_f'" != "`model_mode'" | `n_models_f' != `n_models' {
                display as error "All model frames must share the same layout"
                display as error "Frame '`_fname1'' is `model_mode' with `n_models' model(s); '`_fname'' is `model_mode_f' with `n_models_f' model(s)"
                exit 198
            }
            if `n_models_f' != `outcomes' {
                display as error "Model frame '`_fname'' contributes `n_models_f' model(s), but rate frame requires `outcomes' outcome(s)"
                exit 198
            }
        }

        * Parse rows() or rownames() for model frames
        if `_use_rownames' {
            local rownames : subinstr local rownames " \ " "\", all
            local rownames : subinstr local rownames "\  " "\", all
            local rownames : subinstr local rownames "  \" "\", all
            tokenize `"`rownames'"', parse("\")

            local _ridx = 1
            local _fidx = 0
            while `"``_ridx''"' != "" {
                if `"``_ridx''"' != "\" {
                    local _fidx = `_fidx' + 1
                    local _rnspec`_fidx' `"``_ridx''"'
                }
                local _ridx = `_ridx' + 1
            }

            if `_fidx' != `n_frames' {
                display as error "rownames() requires `n_frames' specifications separated by \"
                exit 198
            }

            forvalues _f = 1/`n_frames' {
                local _fname : word `_f' of `modelframes'
                frame `_fname' {
                    local _fn = _N
                }
                local _max_dr = `_fn' - 3
                if `_max_dr' < 1 {
                    display as error "Model frame '`_fname'' has no data rows"
                    exit 198
                }

                local expanded`_f' ""
                local _patterns `"`_rnspec`_f''"'
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
                                if strpos(" `expanded`_f'' ", " `_row' ") {
                                    display as error `"rownames(): pattern "`_pat'" duplicates row `_row' in frame '`_fname''"'
                                    display as error "rownames() patterns must select each model-frame row at most once"
                                    exit 198
                                }
                                local expanded`_f' "`expanded`_f'' `_row'"
                                local _matched = 1
                            }
                        }
                    }
                    if !`_matched' {
                        display as error `"rownames(): pattern "`_pat'" not found in frame '`_fname''"'
                        display as error "rownames() matches rendered model-frame labels in column A"
                        exit 198
                    }
                }
                local expanded`_f' : list clean expanded`_f'
            }
        }
        else {
            local rows : subinstr local rows " \ " "\", all
            local rows : subinstr local rows "\  " "\", all
            local rows : subinstr local rows "  \" "\", all
            tokenize `"`rows'"', parse("\")

            local _ridx = 1
            local _fidx = 0
            while `"``_ridx''"' != "" {
                if `"``_ridx''"' != "\" {
                    local _fidx = `_fidx' + 1
                    local _rowspec`_fidx' `"``_ridx''"'
                }
                local _ridx = `_ridx' + 1
            }

            if `_fidx' != `n_frames' {
                display as error "rows() requires `n_frames' specifications separated by \"
                exit 198
            }

            forvalues _f = 1/`n_frames' {
                local _fname : word `_f' of `modelframes'
                numlist `"`_rowspec`_f''"'
                local expanded`_f' `r(numlist)'

                frame `_fname' {
                    local _fn = _N
                }
                local _max_dr = `_fn' - 3
                if `_max_dr' < 1 {
                    display as error "Model frame '`_fname'' has no data rows"
                    exit 198
                }

                foreach _rr of local expanded`_f' {
                    if `_rr' < 1 | `_rr' > `_max_dr' {
                        display as error "Row `_rr' out of range for frame '`_fname'' (valid: 1-`_max_dr')"
                        exit 198
                    }
                }
            }
        }

        local _selected_total = 0
        local _map_i = 0
        forvalues _f = 1/`n_frames' {
            local _fname : word `_f' of `modelframes'
            local _spec_rows `"`expanded`_f''"'
            foreach _rr of local _spec_rows {
                local ++_selected_total
                local ++_map_i
                local _map_frame`_map_i' "`_fname'"
                local _map_row`_map_i' = `_rr' + 3
            }
        }

        if `_selected_total' != `n_nonref' {
            display as error "Selected model rows (`_selected_total') must match non-reference scaffold rows (`n_nonref')"
            display as error "Hint: select one model row for each non-reference row in the stratetab frame"
            exit 198
        }

        * Build output table
        local ncols = 1 + 5 * `outcomes'
        local _out_title `"`title'"'
        if `"`_out_title'"' == "" local _out_title `"`_rate_title'"'

        clear
        quietly set obs `_rate_rows'
        quietly gen str244 title = ""
        forvalues _c = 1/`ncols' {
            quietly gen str244 c`_c' = ""
        }
        quietly replace title = `"`_out_title'"' in 1

        * Header rows
        frame `rateframe' {
            local _exp_header = c1[2]
        }
        quietly replace c1 = `"`_exp_header'"' in 2
        quietly replace c1 = "" in 3

        forvalues _o = 1/`outcomes' {
            local _rate_s = 2 + (`_o' - 1) * 3
            local _out_s = 2 + (`_o' - 1) * 5
            local _rate_s2 = `_rate_s' + 1
            local _rate_s3 = `_rate_s' + 2
            local _out_s2 = `_out_s' + 1
            local _out_s3 = `_out_s' + 2
            local _out_s4 = `_out_s' + 3

            frame `rateframe' {
                local _outcome_header = c`_rate_s'[2]
                local _hdr_events = c`_rate_s'[3]
                local _hdr_py = c`_rate_s2'[3]
                local _hdr_rate = c`_rate_s3'[3]
            }

            quietly replace c`_out_s' = `"`_outcome_header'"' in 2
            quietly replace c`_out_s' = `"`_hdr_events'"' in 3
            quietly replace c`_out_s2' = `"`_hdr_py'"' in 3
            quietly replace c`_out_s3' = `"`_hdr_rate'"' in 3
            quietly replace c`_out_s4' = `"`effect' (95% CI)"' in 3
            quietly replace c`=`_out_s4'+1' = "p-value" in 3
        }

        * Data rows follow the stratetab scaffold exactly
        local _section_rows_sp " `section_rows' "
        local _ref_rows_sp " `ref_rows' "
        local _next_model = 0

        forvalues _r = 4/`_rate_rows' {
            frame `rateframe' {
                local _rate_lab = c1[`_r']
            }
            quietly replace c1 = `"`_rate_lab'"' in `_r'

            forvalues _o = 1/`outcomes' {
                local _rate_s = 2 + (`_o' - 1) * 3
                local _out_s = 2 + (`_o' - 1) * 5
                local _rate_s2 = `_rate_s' + 1
                local _rate_s3 = `_rate_s' + 2
                local _out_s2 = `_out_s' + 1
                local _out_s3 = `_out_s' + 2
                local _out_s4 = `_out_s' + 3

                frame `rateframe' {
                    local _rate_events = c`_rate_s'[`_r']
                    local _rate_py = c`_rate_s2'[`_r']
                    local _rate_rate = c`_rate_s3'[`_r']
                }

                quietly replace c`_out_s' = `"`_rate_events'"' in `_r'
                quietly replace c`_out_s2' = `"`_rate_py'"' in `_r'
                quietly replace c`_out_s3' = `"`_rate_rate'"' in `_r'
            }

            if strpos("`_section_rows_sp'", " `_r' ") {
                continue
            }

            if strpos("`_ref_rows_sp'", " `_r' ") {
                forvalues _o = 1/`outcomes' {
                    local _out_s = 2 + (`_o' - 1) * 5
                    local _out_s4 = `_out_s' + 3
                    quietly replace c`_out_s4' = `"`reflabel'"' in `_r'
                    quietly replace c`=`_out_s4'+1' = "" in `_r'
                }
                continue
            }

            local ++_next_model
            local _mfname "`_map_frame`_next_model''"
            local _mrow = `_map_row`_next_model''

            forvalues _o = 1/`outcomes' {
                local _out_s = 2 + (`_o' - 1) * 5
                local _out_s4 = `_out_s' + 3

                if "`model_mode'" == "standard" {
                    local _model_s = 1 + (`_o' - 1) * 3
                    frame `_mfname' {
                        local _eff_main = c`_model_s'[`_mrow']
                        local _eff_ci = c`=`_model_s'+1'[`_mrow']
                        local _eff_p = c`=`_model_s'+2'[`_mrow']
                    }
                    local _eff_main = strtrim(`"`_eff_main'"')
                    local _eff_ci = strtrim(`"`_eff_ci'"')
                    if `"`_eff_main'"' == "" {
                        local _eff_text `"`_eff_ci'"'
                    }
                    else if `"`_eff_ci'"' == "" {
                        local _eff_text `"`_eff_main'"'
                    }
                    else {
                        local _eff_text `"`_eff_main' `_eff_ci'"'
                    }
                }
                else {
                    local _model_s = 1 + (`_o' - 1) * 2
                    frame `_mfname' {
                        local _eff_text = c`_model_s'[`_mrow']
                        local _eff_p = c`=`_model_s'+1'[`_mrow']
                    }
                    local _eff_text = strtrim(`"`_eff_text'"')
                }

                local _eff_p = strtrim(`"`_eff_p'"')
                if lower(`"`_eff_text'"') == "reference" local _eff_text `"`reflabel'"'

                quietly replace c`_out_s4' = `"`_eff_text'"' in `_r'
                quietly replace c`=`_out_s4'+1' = `"`_eff_p'"' in `_r'
            }
        }

        local lastrow = _N
        local exp_rows "`section_rows'"

        * Console display
        noisily _tabtools_console_display `ncols' `"`_out_title'"', datastart(4) headerstart(2)
        if `"`footnote'"' != "" {
            noisily display as text `"`footnote'"'
            noisily display as text ""
        }

        * CSV export
        if "`csv'" != "" {
            order title c*
            export delimited using "`csv'", replace
            capture confirm file "`csv'"
            if _rc {
                display as error "CSV export completed but file was not created"
                exit 601
            }
        }

        * Frame output
        if `"`frame'"' != "" {
            _tabtools_frame_put `"`frame'"'
            local frame "`_frame_name'"
            return local frame "`frame'"
        }

        return scalar N_rows = `lastrow'
        return scalar N_outcomes = `outcomes'
        return scalar N_sections = `n_sections'
        return scalar N_modelrows = `_selected_total'
        return scalar N_modelframes = `n_frames'
        return local rateframe "`rateframe'"
        return local modelframes "`modelframes'"
        return local effect "`effect'"
        if "`csv'" != "" return local csv "`csv'"

        * Excel export
        local _xlsx_ok 0
        if `_has_xlsx' {
            * Compute column widths before export
            tempvar _hrc_len
            quietly generate long `_hrc_len' = length(c1)
            quietly summarize `_hrc_len' if _n >= 4, meanonly
            local _label_width = ceil(r(max) * 0.90)
            if `_label_width' < 14 local _label_width = 14
            if `_label_width' > 30 local _label_width = 30
            drop `_hrc_len'

            forvalues _c = 2/`ncols' {
                local _block_pos = mod(`_c' - 2, 5)
                tempvar _hrc_len
                quietly generate long `_hrc_len' = length(c`_c')
                * Row 2 holds merged outcome headers; size each display column from
                * its own subheader/data content instead of the merged label text.
                quietly summarize `_hrc_len' if _n >= 3, meanonly

                if `_block_pos' == 0 {
                    local _cw`_c' = ceil(r(max))
                    if `_cw`_c'' < 7 local _cw`_c' = 7
                    if `_cw`_c'' > 10 local _cw`_c' = 10
                }
                else if `_block_pos' == 1 {
                    local _cw`_c' = ceil(r(max) * 0.90)
                    if `_cw`_c'' < 12 local _cw`_c' = 12
                    if `_cw`_c'' > 18 local _cw`_c' = 18
                }
                else if `_block_pos' == 2 {
                    local _cw`_c' = ceil(r(max) * 0.88)
                    if `_cw`_c'' < 14 local _cw`_c' = 14
                    if `_cw`_c'' > 22 local _cw`_c' = 22
                }
                else if `_block_pos' == 3 {
                    local _cw`_c' = ceil(r(max) * 0.88)
                    if `_cw`_c'' < 13 local _cw`_c' = 13
                    if `_cw`_c'' > 20 local _cw`_c' = 20
                }
                else {
                    local _cw`_c' = ceil(r(max))
                    if `_cw`_c'' < 7 local _cw`_c' = 7
                    if `_cw`_c'' > 10 local _cw`_c' = 10
                }
                drop `_hrc_len'
            }

            order title c*
            capture noisily _tabtools_xlsx_write_current using "`xlsx'", sheet("`sheet'") book(b)
            if _rc {
                local _export_rc = _rc
                display as error "Failed to export to `xlsx'"
                display as error "Hint: ensure the xlsx file is not open in another application"
                exit `_export_rc'
            }
            capture confirm file "`xlsx'"
            if _rc {
                display as error "Excel export completed but file was not created"
                exit 601
            }

            local _total_cols = `ncols' + 1
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
                local _style_rule_spec "12 1 1 1 1 30 0 0 0 | 13 1 1 1 1 1 0 0 0 | 13 1 1 2 2 `_label_width' 0 0 0"
                forvalues _c = 2/`ncols' {
                    local _excel_col = `_c' + 1
                    local _style_rule_spec `"`_style_rule_spec' | 13 1 1 `_excel_col' `_excel_col' `_cw`_c'' 0 0 0"'
                }

                local _style_rule_spec `"`_style_rule_spec' | 1 1 `lastrow' 1 `_total_cols' `_fontsize' 1 0 0 | 1 1 1 1 `_total_cols' `=`_fontsize'+2' 1 0 0 | 14 1 1 1 `_total_cols' 0 0 0 0 | 2 1 1 1 1 0 1 0 0 | 4 1 1 1 1 0 1 0 0 | 5 1 1 1 1 0 1 0 0 | 6 1 1 1 1 0 2 0 0 | 8 2 2 2 `_total_cols' 0 `_hborder_code' 0 0 | 9 3 3 2 `_total_cols' 0 `_hborder_code' 0 0"'

                local _merge_col = 3
                forvalues _o = 1/`outcomes' {
                    local _col_end = `_merge_col' + 4
                    local _style_rule_spec `"`_style_rule_spec' | 14 2 2 `_merge_col' `_col_end' 0 0 0 0 | 2 2 2 `_merge_col' `_merge_col' 0 1 0 0 | 5 2 2 `_merge_col' `_merge_col' 0 2 0 0 | 6 2 2 `_merge_col' `_merge_col' 0 3 0 0 | 9 2 2 `_merge_col' `_col_end' 0 `_hborder_code' 0 0"'
                    local _merge_col = `_merge_col' + 5
                }

                local _style_rule_spec `"`_style_rule_spec' | 14 2 3 2 2 0 0 0 0 | 2 2 3 2 2 0 1 0 0 | 5 2 3 2 2 0 2 0 0 | 6 2 3 2 2 0 2 0 0 | 9 3 3 2 2 0 `_hborder_code' 0 0 | 2 3 3 3 `_total_cols' 0 1 0 0 | 5 3 3 3 `_total_cols' 0 2 0 0 | 6 3 3 3 `_total_cols' 0 2 0 0"'

                if "`headershade'" != "" {
                    local _style_rule_spec `"`_style_rule_spec' | 7 2 3 2 `_total_cols' 0 -1 0 0"'
                }
                if "`zebra'" != "" {
                    forvalues _zr = 5(2)`lastrow' {
                        local _style_rule_spec `"`_style_rule_spec' | 7 `_zr' `_zr' 2 `_total_cols' 0 -2 0 0"'
                    }
                }
                if `lastrow' >= 4 & `_total_cols' >= 3 {
                    local _style_rule_spec `"`_style_rule_spec' | 5 4 `lastrow' 3 `_total_cols' 0 2 0 0"'
                }
                if "`borderstyle'" != "academic" {
                    local _style_rule_spec `"`_style_rule_spec' | 10 2 `lastrow' 2 2 0 `_vborder_code' 0 0 | 11 2 `lastrow' 2 2 0 `_vborder_code' 0 0"'
                    local _vcol = 3
                    forvalues _o = 1/`outcomes' {
                        local _col_end = `_vcol' + 4
                        local _style_rule_spec `"`_style_rule_spec' | 11 2 `lastrow' `_col_end' `_col_end' 0 `_vborder_code' 0 0"'
                        local _vcol = `_vcol' + 5
                    }
                }
                foreach _sr of local exp_rows {
                    local _border_row = `_sr' - 1
                    if `_border_row' > 3 {
                        local _style_rule_spec `"`_style_rule_spec' | 9 `_border_row' `_border_row' 2 `_total_cols' 0 `_hborder_code' 0 0"'
                    }
                }
                local _style_rule_spec `"`_style_rule_spec' | 9 `lastrow' `lastrow' 2 `_total_cols' 0 `_hborder_code' 0 0"'

                if `"`footnote'"' != "" {
                    local _fn_row = `lastrow' + 1
                    local _fn_fontsize = max(`_fontsize' - 2, 6)
                    mata: b.put_string(`_fn_row', 2, `"`footnote'"')
                    local _style_rule_spec `"`_style_rule_spec' | 14 `_fn_row' `_fn_row' 2 `_total_cols' 0 0 0 0 | 5 `_fn_row' `_fn_row' 2 2 0 1 0 0 | 6 `_fn_row' `_fn_row' 2 2 0 2 0 0 | 4 `_fn_row' `_fn_row' 2 2 0 1 0 0 | 1 `_fn_row' `_fn_row' 2 2 `_fn_fontsize' 1 0 0 | 3 `_fn_row' `_fn_row' 2 2 0 1 0 0"'
                }

                _tabtools_xlsx_build_styles, matrix(`_style_rules') ///
                    rules(`_style_rule_spec') cols(9)
                _tabtools_xlsx_apply_styles, book(b) sheet("`sheet'") ///
                    rules(`_style_rules') font("`_font'") ///
                    color1("`_headercolor'") color2("`_zebracolor'")
                mata: b.close_book()
            }
            if _rc {
                local _fmt_rc = _rc
                capture mata: b.close_book()
                capture mata: mata drop b
                display as error "Excel formatting failed with error `_fmt_rc'"
                exit `_fmt_rc'
            }
            capture mata: mata drop b

            capture confirm file "`xlsx'"
            if _rc {
                display as error "Excel export completed but file was not created"
                exit 601
            }
            local _xlsx_ok 1
            display as text "Exported " as result "`lastrow'" as text " rows × " as result "`ncols'" as text " cols to " as result `"`xlsx'"' as text ", sheet " as result `"`sheet'"'
        }

        if `_xlsx_ok' {
            return local xlsx "`xlsx'"
            return local sheet "`sheet'"
        }
        if `_xlsx_ok' & "`open'" != "" _tabtools_open_file "`xlsx'"
    }

    local _rc = _rc
    quietly use "`_userdata_path'", clear
    set varabbrev `_orig_varabbrev'
    if `_rc' exit `_rc'
end
