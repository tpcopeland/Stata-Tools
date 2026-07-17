*! hrcomptab Version 1.9.10  2026/07/17
*! Compose stratetab and regtab frames into Table 2-style survival tables
*! Author: Timothy P Copeland, Karolinska Institutet
*! Program class: rclass

program define hrcomptab, rclass
    version 17.0
    local _orig_varabbrev = c(varabbrev)
    set varabbrev off
    local _userdata_saved 0

    tempfile _userdata_outer
    local _userdata_path "`_userdata_outer'"

    capture noisily {

        quietly save "`_userdata_path'", emptyok
        local _userdata_saved 1

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
	            EFFect(string) REFLabel(string) OUTCOMEMap(string asis) ///
            BORDERstyle(string) THEme(string) ///
            open zebra HEADERShade ///
            HEADERColor(string) ZEBRAColor(string) ///
            CSV(string) MARKdown(string) MDAPPend FRAme(string) EPLOTFrame(string asis) ///
            FOREST EPLOTOptions(string asis)]

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

        local _eplotframe_name ""
        local _eplotframe_replace 0
        local _eplotframe_temporary 0
        if `"`eplotframe'"' != "" {
            local _ep_spec = strtrim(`"`eplotframe'"')
            gettoken _eplotframe_name _ep_rest : _ep_spec, parse(",")
            local _eplotframe_name = strtrim(`"`_eplotframe_name'"')
            if `"`_eplotframe_name'"' == "" {
                display as error "eplotframe() requires a frame name"
                exit 198
            }
            capture confirm name `_eplotframe_name'
            if _rc {
                display as error "eplotframe() must start with a valid Stata frame name"
                exit 198
            }
            local _ep_rest : subinstr local _ep_rest "," "", all
            local _ep_rest = lower(strtrim(`"`_ep_rest'"'))
            if `"`_ep_rest'"' != "" {
                if `"`_ep_rest'"' == "replace" local _eplotframe_replace 1
                else {
                    display as error "eplotframe() only allows the replace suboption"
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

	        * Resolve the complete frame-name graph before any frame can be
	        * cleared, dropped, or rebuilt.
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
	                display as error "frame() must start with a valid Stata frame name"
	                exit 198
	            }
	            if `"`_fr_rest'"' != "" {
	                if `"`_fr_rest'"' == "replace" local _displayframe_replace 1
	                else {
	                    display as error "frame() only allows the replace suboption"
	                    exit 198
	                }
	            }
	        }
	        if `"`_displayframe_name'"' != "" & `"`_eplotframe_name'"' != "" & ///
	            lower(`"`_displayframe_name'"') == lower(`"`_eplotframe_name'"') {
	            display as error "frame() and eplotframe() must name different frames"
	            exit 198
	        }
	        foreach _dest in _displayframe_name _eplotframe_name {
	            if `"``_dest''"' != "" & lower(`"``_dest''"') == lower(`"`c(frame)'"') {
	                display as error "output frames cannot replace the current frame"
	                exit 198
	            }
	        }
	        local _rateframe_original `"`rateframe'"'
	        local _modelframes_original `"`modelframes'"'
	        foreach _dest in _displayframe_name _eplotframe_name {
	            if `"``_dest''"' != "" & lower(`"``_dest''"') == lower(`"`_rateframe_original'"') {
	                display as error "output frame ``_dest'' aliases rate source frame `_rateframe_original'"
	                exit 198
	            }
	        }
	        forvalues _f = 1/`n_frames' {
	            local _source_original_`_f' : word `_f' of `_modelframes_original'
	            if `_f' > 1 {
	                forvalues _j = 1/`=`_f'-1' {
	                    if lower(`"`_source_original_`_f''"') == lower(`"`_source_original_`_j''"') {
	                        display as error "modelframes() contains a duplicate source frame"
	                        exit 198
	                    }
	                }
	            }
	            foreach _dest in _displayframe_name _eplotframe_name {
	                if `"``_dest''"' != "" & lower(`"``_dest''"') == lower(`"`_source_original_`_f''"') {
	                    display as error "output frame ``_dest'' aliases model source frame `_source_original_`_f''"
	                    exit 198
	                }
	            }
	            local _source_ep_original_`_f' ""
	            capture frame `_source_original_`_f'': local _source_ep_original_`_f' : char _dta[tabtools_eplotframe]
	            if _rc local _source_ep_original_`_f' ""
	            if `"`_eplotframe_name'"' != "" & `"`_source_ep_original_`_f''"' == "" {
	                display as error "eplotframe()/forest requires every model source to have a numeric companion frame"
	                exit 459
	            }
	            if `"`_source_ep_original_`_f''"' != "" {
	                foreach _dest in _displayframe_name _eplotframe_name {
	                    if `"``_dest''"' != "" & lower(`"``_dest''"') == lower(`"`_source_ep_original_`_f''"') {
	                        display as error "output frame ``_dest'' aliases model companion frame `_source_ep_original_`_f''"
	                        exit 198
	                    }
	                }
	            }
	        }
	        if `"`_displayframe_name'"' != "" {
	            capture confirm frame `_displayframe_name'
	            if !_rc & !`_displayframe_replace' {
	                display as error "frame `_displayframe_name' already exists; specify frame(`_displayframe_name', replace)"
	                exit 110
	            }
	        }
	        if `"`_eplotframe_name'"' != "" & !`_eplotframe_temporary' {
	            capture confirm frame `_eplotframe_name'
	            if !_rc & !`_eplotframe_replace' {
	                display as error "frame `_eplotframe_name' already exists; specify eplotframe(`_eplotframe_name', replace)"
	                exit 110
	            }
	        }

	        * Snapshot every analytical source and every numeric companion before
	        * touching the current frame. All subsequent reads use only snapshots.
	        tempname _rate_snapshot
	        frame copy `_rateframe_original' `_rate_snapshot'
	        local rateframe "`_rate_snapshot'"
	        local modelframes ""
	        forvalues _f = 1/`n_frames' {
	            tempname _model_snapshot_`_f'
	            frame copy `_source_original_`_f'' `_model_snapshot_`_f''
	            if `"`_source_ep_original_`_f''"' != "" {
	                capture confirm frame `_source_ep_original_`_f''
	                if _rc {
	                    display as error "model companion frame `_source_ep_original_`_f'' not found"
	                    exit 111
	                }
	                tempname _ep_snapshot_`_f'
	                frame copy `_source_ep_original_`_f'' `_ep_snapshot_`_f''
	                frame `_model_snapshot_`_f'': char _dta[tabtools_eplotframe] "`_ep_snapshot_`_f''"
	            }
	            local modelframes `"`modelframes' `_model_snapshot_`_f''"'
	        }
	        local modelframes : list clean modelframes

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

	        * Validate rate provenance and establish stable outcome identities.
	        frame `rateframe': local _rate_source : char _dta[tabtools_source]
	        frame `rateframe': local _rate_ci_char : char _dta[tabtools_ci_level]
	        frame `rateframe': local _rate_n_outcomes : char _dta[tabtools_n_outcomes]
	        frame `rateframe': local _rate_stat_ids : char _dta[tabtools_statistic_ids]
	        if lower(strtrim(`"`_rate_source'"')) != "stratetab" | ///
	            real(`"`_rate_n_outcomes'"') != `outcomes' | ///
	            `"`_rate_stat_ids'"' != "events person_years rate_ci" {
	            display as error "rate frame lacks required stratetab outcome/statistic provenance"
	            exit 459
	        }
	        local _ci_level = real(`"`_rate_ci_char'"')
	        if missing(`_ci_level') | `_ci_level' <= 0 | `_ci_level' >= 100 {
	            display as error "rate frame has unknown confidence-level provenance"
	            exit 459
	        }
	        local _ci_level_label : display %9.0g `_ci_level'
	        local _ci_level_label = strtrim("`_ci_level_label'")
	        forvalues _o = 1/`outcomes' {
	            frame `rateframe': local _rate_outcome_id_`_o' : char _dta[tabtools_outcome_id_`_o']
	            local _rate_header_col = 2 + (`_o' - 1) * 3
	            frame `rateframe': local _rate_display_label_`_o' = c`_rate_header_col'[2]
	            local _rate_outcome_id_`_o' = lower(strtrim(`"`_rate_outcome_id_`_o''"'))
	            if `"`_rate_outcome_id_`_o''"' == "" {
	                display as error "rate frame contains a blank outcome identity"
	                exit 459
	            }
	            if `_o' > 1 {
	                forvalues _j = 1/`=`_o'-1' {
	                    if `"`_rate_outcome_id_`_o''"' == `"`_rate_outcome_id_`_j''"' {
	                        display as error "rate frame contains duplicate outcome identities"
	                        exit 198
	                    }
	                }
	            }
	        }

	        * outcomeMap() explicitly names, in rate-outcome order, a model ID,
	        * model outcome ID, or persisted model label. Without it, matching is
	        * allowed only by the analytical outcome ID.
	        local _explicit_outcome_map = (`"`outcomemap'"' != "")
	        if `_explicit_outcome_map' {
	            local outcomemap : subinstr local outcomemap " \ " "\", all
	            local outcomemap : subinstr local outcomemap "\  " "\", all
	            local outcomemap : subinstr local outcomemap "  \" "\", all
	            tokenize `"`outcomemap'"', parse("\")
	            local _map_n = 0
	            forvalues _i = 1/100 {
	                local _j = (`_i' - 1) * 2 + 1
	                if `"``_j''"' == "" continue, break
	                local ++_map_n
	                local _map_key_`_map_n' = lower(strtrim(`"``_j''"'))
	            }
	            if `_map_n' != `outcomes' {
	                display as error "outcomemap() requires `outcomes' identities separated by \"
	                exit 198
	            }
	        }
	        else {
	            forvalues _o = 1/`outcomes' {
	                local _map_key_`_o' `"`_rate_outcome_id_`_o''"'
	            }
	        }

	        local _effect_norm = lower(strtrim(`"`effect'"'))
	        foreach _punct in " " "-" "_" "." "/" {
	            local _effect_norm : subinstr local _effect_norm `"`_punct'"' "", all
	        }
	        if !inlist(`"`_effect_norm'"', "hr", "ahr", "hazardratio", "adjustedhazardratio") {
	            display as error "effect() must truthfully describe a hazard-ratio scale"
	            exit 198
	        }

	        local _expected_model_stats = cond("`model_mode'" == "standard", ///
	            "estimate ci pvalue", "estimate_ci pvalue")
	        forvalues _f = 1/`n_frames' {
	            local _fname : word `_f' of `modelframes'
	            frame `_fname': local _meta_n : char _dta[tabtools_n_models]
	            frame `_fname': local _meta_ci : char _dta[tabtools_ci_level]
	            frame `_fname': local _meta_stats : char _dta[tabtools_statistic_ids]
	            if real(`"`_meta_n'"') != `n_models' | `"`_meta_stats'"' != `"`_expected_model_stats'"' {
	                display as error "model frame lacks required model/statistic provenance"
	                exit 459
	            }
	            if missing(real(`"`_meta_ci'"')) | abs(real(`"`_meta_ci'"') - `_ci_level') > 1e-8 {
	                display as error "rate and model frames contain mixed or unknown confidence levels"
	                exit 198
	            }
	            forvalues _m = 1/`n_models' {
	                frame `_fname': local _mid_`_m' : char _dta[tabtools_model_id_`_m']
	                frame `_fname': local _oid_`_m' : char _dta[tabtools_outcome_id_`_m']
	                frame `_fname': local _mlabel_`_m' : char _dta[tabtools_model_label_`_m']
	                frame `_fname': local _scale_`_m' : char _dta[tabtools_effect_scale_`_m']
	                local _mid_`_m' = lower(strtrim(`"`_mid_`_m''"'))
	                local _oid_`_m' = lower(strtrim(`"`_oid_`_m''"'))
	                local _mlabel_`_m' = lower(strtrim(`"`_mlabel_`_m''"'))
	                local _scale_norm = lower(strtrim(`"`_scale_`_m''"'))
	                foreach _punct in " " "-" "_" "." "/" {
	                    local _scale_norm : subinstr local _scale_norm `"`_punct'"' "", all
	                }
	                if !inlist(`"`_scale_norm'"', "hr", "ahr", "hazardratio", "adjustedhazardratio") {
	                    display as error "model frame contains a non-hazard-ratio effect scale"
	                    exit 198
	                }
	            }

	            local _used_model_indices ""
	            forvalues _o = 1/`outcomes' {
	                local _key `"`_map_key_`_o''"'
	                local _matched_index = 0
	                local _matched_count = 0
	                forvalues _m = 1/`n_models' {
	                    local _matches = 0
	                    if `_explicit_outcome_map' {
	                        if `"`_key'"' == `"`_mid_`_m''"' | ///
	                            `"`_key'"' == `"`_oid_`_m''"' | ///
	                            `"`_key'"' == `"`_mlabel_`_m''"' local _matches = 1
	                    }
	                    else if `"`_key'"' == `"`_oid_`_m''"' local _matches = 1
	                    if `_matches' {
	                        local ++_matched_count
	                        local _matched_index = `_m'
	                    }
	                }
	                if `_matched_count' != 1 {
	                    if `_explicit_outcome_map' display as error `"outcomemap identity "`_key'" matched `_matched_count' model blocks"'
	                    else display as error `"rate outcome "`_key'" could not be matched uniquely; specify outcomemap()"'
	                    exit 198
	                }
	                if strpos(" `_used_model_indices' ", " `_matched_index' ") {
	                    display as error "outcomemap() maps more than one rate outcome to the same model block"
	                    exit 198
	                }
	                local _used_model_indices "`_used_model_indices' `_matched_index'"
	                local _model_map_`_f'_`_o' = `_matched_index'
	                if `_f' == 1 {
	                    local _output_model_id_`_o' `"`_mid_`_matched_index''"'
	                    local _output_model_label_`_o' `"`_mlabel_`_matched_index''"'
	                }
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
	                local _map_f`_map_i' = `_f'
	                local _map_source`_map_i' "`_source_original_`_f''"
	                local _map_row`_map_i' = `_rr' + 3
            }
        }

        if `_selected_total' != `n_nonref' {
            display as error "Selected model rows (`_selected_total') must match non-reference scaffold rows (`n_nonref')"
            display as error "Hint: select one model row for each non-reference row in the stratetab frame"
            exit 198
        }

	        local _eplot_build_name ""
	        if `"`_eplotframe_name'"' != "" {
	            tempname _eplot_build
	            local _eplot_build_name "`_eplot_build'"
	            frame create `_eplot_build_name' str244 label double estimate double ll double ul ///
	                double pvalue int model str244 model_label str24 rowtype str244 section ///
	                long source_row str32 source_frame

            local _section_rows_sp " `section_rows' "
            local _ref_rows_sp " `ref_rows' "

            * A section header that owns exactly one plotted row is redundant in
            * a forest plot. Pre-scan the scaffold: for each section row, count
            * the rows up to the next section (or end); mark single-child sections
            * so their label is folded into that one row instead of a header.
            local _fold_sections " "
            foreach _sr of local section_rows {
                local _cnt = 0
                local _rr = `_sr' + 1
                local _stop = 0
                while `_rr' <= `_rate_rows' & !`_stop' {
                    if strpos("`_section_rows_sp'", " `_rr' ") {
                        local _stop = 1
                    }
                    else {
                        local ++_cnt
                        local ++_rr
                    }
                }
                if `_cnt' == 1 local _fold_sections "`_fold_sections'`_sr' "
            }

            local _next_model_ep = 0
            local _current_section ""
            local _pending_fold_label ""
            forvalues _r = 4/`_rate_rows' {
                frame `rateframe' {
                    local _rate_lab_ep = c1[`_r']
                }
                if strpos("`_section_rows_sp'", " `_r' ") {
                    local _current_section = strtrim(`"`_rate_lab_ep'"')
                    if strpos("`_fold_sections'", " `_r' ") {
                        local _pending_fold_label `"`_current_section'"'
                    }
                    else {
                        local _pending_fold_label ""
	                        frame post `_eplot_build_name' (`"`_current_section'"') (.) (.) (.) (.) ///
	                            (.) ("") ("section") (`"`_current_section'"') (.) (`"`_rateframe_original'"')
                    }
                    continue
                }
                if strpos("`_ref_rows_sp'", " `_r' ") {
                    local _ref_post_label `"`_rate_lab_ep'"'
                    if `"`_pending_fold_label'"' != "" {
                        local _ref_post_label `"`_pending_fold_label'"'
                        local _pending_fold_label ""
                    }
	                    frame post `_eplot_build_name' (`"`_ref_post_label'"') (.) (.) (.) (.) ///
	                        (.) ("") ("reference") (`"`_current_section'"') (.) (`"`_rateframe_original'"')
                    continue
                }

	                local ++_next_model_ep
	                local _mfname_ep "`_map_frame`_next_model_ep''"
	                local _mfindex_ep = `_map_f`_next_model_ep''
	                local _mfsource_ep "`_map_source`_next_model_ep''"
	                local _src_row_ep = `_map_row`_next_model_ep'' - 3
                local _src_ep ""
                capture frame `_mfname_ep': local _src_ep : char _dta[tabtools_eplotframe]
                local _src_ep_rc = _rc
                if `_src_ep_rc' == 0 & `"`_src_ep'"' != "" {
                    capture frame `_src_ep': quietly count
                    local _src_ep_rc = _rc
                    if `_src_ep_rc' == 0 {
	                        forvalues _o = 1/`outcomes' {
	                            local _source_model_ep = `_model_map_`_mfindex_ep'_`_o''
	                            local _found_ep = 0
	                            frame `_src_ep' {
	                                local _ep_N = _N
	                                forvalues _ep_i = 1/`_ep_N' {
	                                    if source_row[`_ep_i'] == `_src_row_ep' & model[`_ep_i'] == `_source_model_ep' {
	                                        local ++_found_ep
	                                    local _ep_label = label[`_ep_i']
	                                    local _ep_est = estimate[`_ep_i']
                                    local _ep_ll = ll[`_ep_i']
                                    local _ep_ul = ul[`_ep_i']
                                    local _ep_p = pvalue[`_ep_i']
	                                    local _ep_model = `_o'
	                                    local _ep_model_label `"`_rate_display_label_`_o''"'
                                    local _ep_rowtype = rowtype[`_ep_i']
                                    local _ep_post_label `"`_ep_label'"'
                                    if `"`_pending_fold_label'"' != "" {
                                        local _ep_post_label `"`_pending_fold_label'"'
                                        local _pending_fold_label ""
                                    }
	                                    frame post `_eplot_build_name' (`"`_ep_post_label'"') (`_ep_est') (`_ep_ll') (`_ep_ul') ///
	                                        (`_ep_p') (`_ep_model') (`"`_ep_model_label'"') (`"`_ep_rowtype'"') ///
	                                        (`"`_current_section'"') (`_src_row_ep') (`"`_mfsource_ep'"')
	                                    }
	                                }
	                            }
	                            if `_found_ep' != 1 {
	                                display as error "model companion frame does not uniquely identify the selected row/outcome"
	                                exit 459
	                            }
	                        }
                    }
                }
            }
	            frame `_eplot_build_name': char _dta[tabtools_source] "hrcomptab"
	            frame `_eplot_build_name': char _dta[tabtools_ci_level] "`_ci_level'"
	            frame `_eplot_build_name': char _dta[tabtools_n_models] "`outcomes'"
	            frame `_eplot_build_name': char _dta[tabtools_statistic_ids] "estimate ci pvalue"
	            forvalues _o = 1/`outcomes' {
	                frame `_eplot_build_name': char _dta[tabtools_model_id_`_o'] `"`_output_model_id_`_o''"'
	                frame `_eplot_build_name': char _dta[tabtools_outcome_id_`_o'] `"`_rate_outcome_id_`_o''"'
	                frame `_eplot_build_name': char _dta[tabtools_effect_scale_`_o'] "HR"
	            }
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
	            quietly replace c`_out_s4' = `"`effect' (`_ci_level_label'% CI)"' in 3
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
	            local _mfindex = `_map_f`_next_model''
	            local _mrow = `_map_row`_next_model''

	            forvalues _o = 1/`outcomes' {
	                local _out_s = 2 + (`_o' - 1) * 5
	                local _out_s4 = `_out_s' + 3
	                local _source_model = `_model_map_`_mfindex'_`_o''

	                if "`model_mode'" == "standard" {
	                    local _model_s = 1 + (`_source_model' - 1) * 3
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
	                    local _model_s = 1 + (`_source_model' - 1) * 2
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
            _tabtools_csv_write using "`csv'"
            capture confirm file "`csv'"
            if _rc {
                display as error "CSV export completed but file was not created"
                exit 601
            }
        }

        local _ret_markdown ""
        local _ret_markdown_rows .
        local _ret_markdown_cols .
        if `"`markdown'"' != "" {
            local _mdappend_opt ""
            if "`mdappend'" != "" local _mdappend_opt "append"
            capture noisily _tabtools_markdown_write using `"`markdown'"', ///
                `_mdappend_opt' title(`"`_out_title'"') footnote(`"`footnote'"') strictheaders
            if _rc {
                local _md_rc = _rc
                display as error "Failed to export Markdown to `markdown'"
                exit `_md_rc'
            }
            local _ret_markdown `"`markdown'"'
            local _ret_markdown_rows = r(n_rows)
            local _ret_markdown_cols = r(n_cols)
            display as text "Markdown exported to `markdown'"
        }

	        * Stage display-frame output. The caller-visible destination is not
	        * changed until every requested export and forest plot has succeeded.
	        local _display_build_name ""
	        if `"`_displayframe_name'"' != "" {
	            tempname _display_build
	            local _display_build_name "`_display_build'"
	            frame put *, into(`_display_build_name')
	            frame `_display_build_name': char _dta[tabtools_source] "hrcomptab"
	            frame `_display_build_name': char _dta[tabtools_ci_level] "`_ci_level'"
	            frame `_display_build_name': char _dta[tabtools_n_outcomes] "`outcomes'"
	            frame `_display_build_name': char _dta[tabtools_statistic_ids] "events person_years rate_ci estimate_ci pvalue"
	            if `"`_eplotframe_name'"' != "" & !`_eplotframe_temporary' {
	                frame `_display_build_name': char _dta[tabtools_eplotframe] "`_eplotframe_name'"
	            }
	            forvalues _o = 1/`outcomes' {
	                frame `_display_build_name': char _dta[tabtools_model_id_`_o'] `"`_output_model_id_`_o''"'
	                frame `_display_build_name': char _dta[tabtools_outcome_id_`_o'] `"`_rate_outcome_id_`_o''"'
	                frame `_display_build_name': char _dta[tabtools_effect_scale_`_o'] "HR"
	            }
	            local frame "`_displayframe_name'"
	        }
	        if `"$TABTOOLS_QA_HRC_STAGE_FAIL"' == "1" error 459

	        return scalar N_rows = `lastrow'
        return scalar N_outcomes = `outcomes'
        return scalar N_sections = `n_sections'
        return scalar N_modelrows = `_selected_total'
        return scalar N_modelframes = `n_frames'
	        return scalar ci_level = `_ci_level'
	        return local rateframe "`_rateframe_original'"
	        return local modelframes "`_modelframes_original'"
        return local effect "`effect'"
        if `"`_eplotframe_name'"' != "" & !`_eplotframe_temporary' return local eplotframe "`_eplotframe_name'"
        if "`csv'" != "" return local csv "`csv'"
        if `"`_ret_markdown'"' != "" {
            return local markdown `"`_ret_markdown'"'
            return scalar markdown_rows = `_ret_markdown_rows'
            return scalar markdown_cols = `_ret_markdown_cols'
        }

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
            capture noisily _tabtools_xlsx_write using "`xlsx'", sheet("`sheet'") book(b)
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
	    if `_rc' {
	        if `"`_display_build_name'"' != "" capture frame drop `_display_build_name'
	        if `"`_eplot_build_name'"' != "" capture frame drop `_eplot_build_name'
	        if `_userdata_saved' capture quietly use "`_userdata_path'", clear
        set varabbrev `_orig_varabbrev'
        exit `_rc'
    }

    local _forest_rc_hold 0
    if "`forest'" != "" {
        capture which eplot
        local _which_eplot_rc = _rc
        if `_which_eplot_rc' {
            display as error "forest requires eplot"
            display as error `"Install with: net install eplot, from("https://raw.githubusercontent.com/tpcopeland/Stata-Tools/main/eplot") replace"'
	            local _forest_rc_hold 111
        }
        else {
            local _eplotoptions_clean = strtrim(`"`eplotoptions'"')
            if substr(`"`_eplotoptions_clean'"', 1, 1) == "," {
                local _eplotoptions_clean = strtrim(substr(`"`_eplotoptions_clean'"', 2, .))
            }
	            frame `_eplot_build_name': quietly count if rowtype == "effect"
            if r(N) == 0 {
                display as error "forest requires an eplotframe with effect rows"
	                local _forest_rc_hold 2000
            }
            else {
	                capture noisily eplot, frame(`_eplot_build_name') labels(label) rowtype(rowtype) ///
                    style(forest) effect("`effect'") values `_eplotoptions_clean'
                local _eplot_rc = _rc
                if `_eplot_rc' local _forest_rc_hold = `_eplot_rc'
            }
        }
	    }

	    if `_forest_rc_hold' != 0 local _rc = `_forest_rc_hold'
	    if `_rc' {
	        if `"`_display_build_name'"' != "" capture frame drop `_display_build_name'
	        if `"`_eplot_build_name'"' != "" capture frame drop `_eplot_build_name'
	        quietly use "`_userdata_path'", clear
	        set varabbrev `_orig_varabbrev'
	        exit `_rc'
	    }

	    * Final frame commit: validate both staged schemas, then replace caller
	    * destinations only after every preceding operation has succeeded.
	    if `"`_display_build_name'"' != "" {
	        frame `_display_build_name': confirm variable title
	        frame `_display_build_name': confirm variable c1
	    }
	    if `"`_eplot_build_name'"' != "" {
	        foreach _v in label estimate ll ul pvalue model model_label rowtype source_row source_frame {
	            frame `_eplot_build_name': confirm variable `_v'
	        }
	    }
	    if `"`_eplot_build_name'"' != "" & !`_eplotframe_temporary' {
	        capture confirm frame `_eplotframe_name'
	        if !_rc frame drop `_eplotframe_name'
	        frame rename `_eplot_build_name' `_eplotframe_name'
	        local _eplot_build_name ""
	    }
	    if `"`_display_build_name'"' != "" {
	        capture confirm frame `_displayframe_name'
	        if !_rc frame drop `_displayframe_name'
	        frame rename `_display_build_name' `_displayframe_name'
	        local _display_build_name ""
	    }
	    if `_eplotframe_temporary' & `"`_eplot_build_name'"' != "" {
	        capture frame drop `_eplot_build_name'
	        local _eplot_build_name ""
	    }
	    quietly use "`_userdata_path'", clear
	    set varabbrev `_orig_varabbrev'
	    return clear
	    if `"`_displayframe_name'"' != "" return local frame "`_displayframe_name'"
    return scalar N_rows = `lastrow'
    return scalar N_outcomes = `outcomes'
    return scalar N_sections = `n_sections'
    return scalar N_modelrows = `_selected_total'
    return scalar N_modelframes = `n_frames'
	    return scalar ci_level = `_ci_level'
	    return local rateframe "`_rateframe_original'"
	    return local modelframes "`_modelframes_original'"
    return local effect "`effect'"
    if `"`_eplotframe_name'"' != "" & !`_eplotframe_temporary' return local eplotframe "`_eplotframe_name'"
    if "`csv'" != "" return local csv "`csv'"
    if `"`_ret_markdown'"' != "" {
        return local markdown `"`_ret_markdown'"'
        return scalar markdown_rows = `_ret_markdown_rows'
        return scalar markdown_cols = `_ret_markdown_cols'
    }
    if `_xlsx_ok' {
        return local xlsx "`xlsx'"
        return local sheet "`sheet'"
    }
end
