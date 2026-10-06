*! comptab Version 2.5.1  2026/10/06
*! Compose vertical model tables or rate-interlocked Table 2 layouts
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
           font(string) fontsize(integer) borderstyle(string) open zebra
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
    font/fontsize: Explicit workbook typography
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
        xlsx(results.xlsx) sheet("Summary") font("Arial") fontsize(10) borderstyle(academic)

    * Console output only (no Excel output)
    comptab s1 s2, rows(1 2 \ 1 3/5)
*/

program define comptab, rclass
    version 17.0
    local _orig_varabbrev = c(varabbrev)
    set varabbrev off

    capture noisily {
        syntax [anything(name=framelist)] , ///
            [ROWS(string asis) ROWNames(string asis) ///
            RATEFrame(string asis) MODELFrames(string asis) ///
            EFFect(string) REFLabel(string) OUTCOMEMap(string asis) ///
            XLSX(string) EXCEL(string) SHEET(string) ///
            TITLE(string) FOOTnote(string) COMPact ///
            SEParator(numlist >0 integer sort) SECtion(string asis) ///
            RELAbel(string asis) FONT(string) FONTSIZE(integer -1) BORDERstyle(string) ///
            OPEN ZEBRA HEADERShade HIGHlight(real -1) BOLDp(real -1) ///
            HEADERColor(string) ZEBRAColor(string) CSV(string) ///
            MARKdown(string) MDAPPend FRAme(string asis) ///
            EPLOTFrame(string asis) FOREST EPLOTOptions(string asis) ///
            LABELWidth(integer 0) CFormat(string) CISep(string) ///
            KEYed MODELOnly ALLModels *]

        local _common_opts ""
        if `"`rows'"' != "" {
            local _common_opts `"`macval(_common_opts)' rows(`macval(rows)')"'
        }
        if `"`rownames'"' != "" {
            local _common_opts `"`macval(_common_opts)' rownames(`macval(rownames)')"'
        }
        if `"`xlsx'"' != "" {
            local _common_opts `"`macval(_common_opts)' xlsx(`"`xlsx'"')"'
        }
        if `"`excel'"' != "" {
            local _common_opts `"`macval(_common_opts)' excel(`"`excel'"')"'
        }
        if `"`macval(sheet)'"' != "" {
            local _common_opts `"`macval(_common_opts)' sheet(`"`macval(sheet)'"')"'
        }
        if `"`macval(title)'"' != "" {
            local _common_opts `"`macval(_common_opts)' title(`"`macval(title)'"')"'
        }
        if `"`macval(footnote)'"' != "" {
            local _common_opts `"`macval(_common_opts)' footnote(`"`macval(footnote)'"')"'
        }
        if `"`font'"' != "" {
            local _common_opts `"`macval(_common_opts)' font(`"`font'"')"'
        }
        if `fontsize' != -1 {
            local _common_opts `"`macval(_common_opts)' fontsize(`fontsize')"'
        }
        if `"`borderstyle'"' != "" {
            local _common_opts `"`macval(_common_opts)' borderstyle(`"`borderstyle'"')"'
        }
        if "`open'" != "" {
            local _common_opts `"`macval(_common_opts)' open"'
        }
        if "`zebra'" != "" {
            local _common_opts `"`macval(_common_opts)' zebra"'
        }
        if "`headershade'" != "" {
            local _common_opts `"`macval(_common_opts)' headershade"'
        }
        if `"`headercolor'"' != "" {
            local _common_opts `"`macval(_common_opts)' headercolor(`"`headercolor'"')"'
        }
        if `"`zebracolor'"' != "" {
            local _common_opts `"`macval(_common_opts)' zebracolor(`"`zebracolor'"')"'
        }
        if `"`csv'"' != "" {
            local _common_opts `"`macval(_common_opts)' csv(`"`csv'"')"'
        }
        if `"`markdown'"' != "" {
            local _common_opts `"`macval(_common_opts)' markdown(`"`markdown'"')"'
        }
        if "`mdappend'" != "" {
            local _common_opts `"`macval(_common_opts)' mdappend"'
        }
        if `"`frame'"' != "" {
            local _common_opts `"`macval(_common_opts)' frame(`macval(frame)')"'
        }
        if `"`eplotframe'"' != "" {
            local _common_opts `"`macval(_common_opts)' eplotframe(`macval(eplotframe)')"'
        }
        if "`forest'" != "" {
            local _common_opts `"`macval(_common_opts)' forest"'
        }
        if `"`eplotoptions'"' != "" {
            local _common_opts `"`macval(_common_opts)' eplotoptions(`macval(eplotoptions)')"'
        }

        * cformat() and cisep() (O1) apply in both modes; keyed, modelonly
        * and allmodels (F4) belong to rate mode.
        if `"`cformat'"' != "" {
            local _common_opts `"`macval(_common_opts)' cformat(`cformat')"'
        }
        * cisep() is data (help tabtools##sep): appended in Mata and spliced
        * with macval(), never re-expanded
        mata: st_local("_common_opts", st_local("_common_opts") + (st_local("cisep") == "" ? "" : " cisep(" + (strpos(st_local("cisep"), char(34)) ? char(96) + char(34) + st_local("cisep") + char(34) + char(39) : char(34) + st_local("cisep") + char(34)) + ")"))

        local _rate_mode = (`"`rateframe'"' != "" | `"`modelframes'"' != "")
        if `_rate_mode' {
            if "`compact'" != "" | `"`separator'"' != "" | ///
                `"`macval(section)'"' != "" | `"`relabel'"' != "" | ///
                `highlight' != -1 | `boldp' != -1 | `labelwidth' != 0 {
                noisily display as error "compact, separator(), section(), relabel(), highlight(), boldp(), and labelwidth() are not allowed with rateframe()"
                exit 198
            }
            if `"`rateframe'"' != "" {
                if `"`framelist'"' != "" & `"`modelframes'"' != "" {
                    noisily display as error "Specify model frames either before the comma or in modelframes(), not both"
                    exit 198
                }
                if `"`modelframes'"' == "" local modelframes `"`framelist'"'
            }
            else {
                local _n_rateframes : word count `framelist'
                if `_n_rateframes' != 1 {
                    noisily display as error "rateframe() is required when model frames precede the comma"
                    exit 198
                }
                local rateframe `"`framelist'"'
            }

            local rateframe = subinstr(strtrim(`"`rateframe'"'), char(34), "", .)
            capture confirm name `rateframe'
            if _rc {
                noisily display as error "rateframe() must name one Stata frame"
                exit 198
            }
            if strtrim(`"`modelframes'"') == "" {
                noisily display as error "modelframes() requires at least one frame"
                exit 198
            }

            capture noisily _comptab_rates `rateframe', ///
                modelframes(`modelframes') effect(`"`effect'"') ///
                reflabel(`"`reflabel'"') outcomemap(`macval(outcomemap)') ///
                `keyed' `modelonly' `allmodels' ///
                `macval(_common_opts)' `macval(options)'
            local _sub_rc = _rc
            return add
            if `_sub_rc' exit `_sub_rc'
        }
        else {
            if `"`effect'"' != "" | `"`reflabel'"' != "" | `"`outcomemap'"' != "" {
                noisily display as error "effect(), reflabel(), and outcomemap() require rateframe()"
                exit 198
            }
            if "`keyed'`modelonly'`allmodels'" != "" {
                noisily display as error "keyed, modelonly, and allmodels require rateframe()"
                exit 198
            }
            local _vertical_opts `"`macval(_common_opts)'"'
            if "`compact'" != "" {
                local _vertical_opts `"`macval(_vertical_opts)' compact"'
            }
            if `"`separator'"' != "" {
                local _vertical_opts `"`macval(_vertical_opts)' separator(`separator')"'
            }
            if `"`macval(section)'"' != "" {
                local _vertical_opts `"`macval(_vertical_opts)' section(`macval(section)')"'
            }
            if `"`relabel'"' != "" {
                local _vertical_opts `"`macval(_vertical_opts)' relabel(`macval(relabel)')"'
            }
            if `highlight' != -1 {
                local _vertical_opts `"`macval(_vertical_opts)' highlight(`highlight')"'
            }
            if `boldp' != -1 {
                local _vertical_opts `"`macval(_vertical_opts)' boldp(`boldp')"'
            }
            if `labelwidth' != 0 {
                local _vertical_opts `"`macval(_vertical_opts)' labelwidth(`labelwidth')"'
            }
            capture noisily _comptab_vertical `framelist', `macval(_vertical_opts)' `macval(options)'
            local _sub_rc = _rc
            return add
            if `_sub_rc' exit `_sub_rc'
        }
    }
    local rc = _rc
    set varabbrev `_orig_varabbrev'
    if `rc' exit `rc'
end


capture program drop _comptab_rates
program define _comptab_rates, rclass
    version 17.0
    local _orig_varabbrev = c(varabbrev)
    set varabbrev off
    local _restore_needed 0
    local _display_build_name ""
    local _eplot_build_name ""
    tempname _xlsx_book

    capture noisily {

        * preserve (not save/use): a tempfile round-trip left c(filename)
        * pointing at the deleted tempfile and c(changed) at 0, so unsaved
        * edits could be discarded later without Stata's usual prompt.
        preserve
        local _restore_needed 1

        capture putexcel close

        * Auto-load shared helper programs
        capture _tabtools_helpers_ready
        if !_rc capture mata: assert(findexternal("_tt_sep_parse()") != NULL)
        * (a session can hold an older _tabtools_common.ado's programs: run,
        * so discard keeps them; this release's Mata must be there too)
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
        _tabtools_companion_id

        syntax anything(name=rateframe) , MODELFRAMES(string asis) ///
            [rows(string asis) ROWNames(string asis) ///
            XLSX(string) EXCEL(string) SHEET(string) ///
            TITLE(string) FOOTnote(string) ///
	            EFFect(string) REFLabel(string) OUTCOMEMap(string asis) ///
            BORDERstyle(string) FONT(string) FONTSIZE(integer -1) ///
            open zebra HEADERShade ///
            HEADERColor(string) ZEBRAColor(string) ///
            CSV(string) MARKdown(string) MDAPPend FRAme(string) EPLOTFrame(string asis) ///
            FOREST EPLOTOptions(string asis) CFormat(string) CISep(string) ///
            KEYed MODELOnly ALLModels]

        * F4: keyed placement (modelonly implies it), K models per outcome.
        local _modelonly = ("`modelonly'" != "")
        local _keyed = ("`keyed'" != "" | `_modelonly')
        local _allmodels = ("`allmodels'" != "")
        * O1: cformat() re-renders model estimates from their numeric
        * companions; cisep() sets the interval separator.
        local _refmt = (`"`cformat'"' != "")
        mata: st_local("_resep", strofreal(st_local("cisep") != ""))
        if `_refmt' {
            capture confirm numeric format `cformat'
            if _rc | regexm(`"`cformat'"', "^%-?t") {
                display as error `"cformat(): "`cformat'" is not a numeric display format"'
                exit 198
            }
        }
        * a decimal-comma cformat() whose rebuilt intervals hold a comma (cisep(),
        * or its default ", "): printed as before, with a warning (regtab and
        * effecttab refuse it)
        if `_refmt' {
            mata: st_local("_sep_comma", strofreal(st_local("cisep") == "" | strpos(st_local("cisep"), ",") > 0))
            if `_sep_comma' & ustrregexm(`"`cformat'"', "^%-?0?[0-9]*,") {
                display as text "(comptab: cformat(`cformat') writes a decimal comma and the interval separator holds a comma: the two limits are hard to tell apart (help tabtools##sep))"
            }
        }

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
        * Session destinations (tabtools set workbook/markdown) apply only when
        * sheet() asks for a sheet; an explicit option wins. Without this a
        * sheet() call after tabtools set workbook wrote nothing, silently.
        if `"`macval(sheet)'"' != "" {
            _tabtools_set_sinks resolve, xlsx(`"`xlsx'"') markdown(`"`markdown'"') `mdappend'
            local xlsx `"`_ss_xlsx'"'
            local markdown `"`_ss_md'"'
            local mdappend "`_ss_mdappend'"
            if `"`xlsx'"' == "" display as text "(tabtools: sheet() ignored; no xlsx() and no session workbook)"
        }
        local _has_xlsx = (`"`xlsx'"' != "")
        if `"`macval(sheet)'"' == "" local sheet "Composite"
        if "`effect'" == "" local effect "aHR"
        if "`reflabel'" == "" local reflabel "Reference"

        local _eplotframe_name ""
        local _eplotframe_replace 0
        local _eplotframe_temporary 0
        if `"`eplotframe'"' != "" {
            local _ep_spec = subinstr(strtrim(`"`eplotframe'"'), char(34), "", .)
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
            local _eplotframe_name `"`_forest_eplotframe'"'
            local _eplotframe_replace 1
            local _eplotframe_temporary 1
        }
        if `_keyed' & `"`_eplotframe_name'"' != "" {
            display as error "eplotframe() and forest are not available with keyed or modelonly"
            exit 198
        }

        if "`open'" != "" & !`_has_xlsx' {
            display as error "open requires xlsx() or excel()"
            exit 198
        }

        if `_has_xlsx' {
            if !strmatch(lower(`"`xlsx'"'), "*.xlsx") {
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
        _tabtools_check_sinks, xlsx(`"`xlsx'"') csv(`"`csv'"') markdown(`"`markdown'"')
        _tabtools_validate_sheet `"`macval(sheet)'"' "sheet()"

        * Resolve formatting
        _tabtools_resolve_format, font(`"`font'"') fontsize(`fontsize') borderstyle(`borderstyle') ///
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

        * A rateratio table is refused by its provenance first: its width can
        * coincide with a plain table of more outcomes (3 x 4 = 4 x 3 columns).
        frame `rateframe': local _rate_stat_ids : char _dta[tabtools_statistic_ids]
        if strpos(" `_rate_stat_ids' ", " irr_ci ") {
            display as error "Rate frame '`rateframe'' must come from stratetab without rateratio"
            display as error "comptab computes model ratios itself; rerun stratetab without rateratio"
            exit 198
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
        * Category rows per section, in scaffold order; the model rows chosen
        * for a section are later placed on these rows by label.
        local _n_sec_scan = 0

        * C1 (codex audit 2026-09-26): rate-frame category labels are
        * user value labels; they are read and tested in Mata here and below,
        * and written with macval(), never expanded as macro syntax.
        forvalues _r = 4/`_rate_rows' {
            frame `rateframe' {
                mata: st_local("_rate_lab", st_sdata(`_r', "c1"))
                local _rate_c2 = c2[`_r']
            }

            mata: st_local("_rl_blank", strofreal(strtrim(st_local("_rate_lab")) == ""))
            if `_rl_blank' continue
            mata: st_local("_rl_cat", strofreal(strmatch(st_local("_rate_lab"), "   *")))

            if !`_rl_cat' & `"`_rate_c2'"' == "" {
                local section_rows `"`section_rows' `_r'"'
                local _seen_ref = 0
                local ++_n_sec_scan
                local _sec_row_`_n_sec_scan' = `_r'
                local _sec_cats_`_n_sec_scan' ""
                continue
            }

            if `_rl_cat' {
                if `_n_sec_scan' == 0 {
                    display as error "Rate frame '`rateframe'' has a category row before any section header"
                    exit 198
                }
                local _sec_cats_`_n_sec_scan' `"`_sec_cats_`_n_sec_scan'' `_r'"'
                if !`_seen_ref' {
                    local ref_rows `"`ref_rows' `_r'"'
                    local _seen_ref = 1
                }
                else {
                    local nonref_rows `"`nonref_rows' `_r'"'
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
	        local _displayframe_flat 0
	        if `"`frame'"' != "" {
	            _comptab_frame_spec `"`frame'"' "frame()"
	            local _displayframe_name "`r(name)'"
	            local _displayframe_replace = r(replace)
	            local _displayframe_flat = r(flat)
	        }
	        if `"`_displayframe_name'"' != "" & `"`_eplotframe_name'"' != "" & ///
	            `"`_displayframe_name'"' == `"`_eplotframe_name'"' {
	            display as error "frame() and eplotframe() must name different frames"
	            exit 198
	        }
	        foreach _dest in _displayframe_name _eplotframe_name {
	            if `"``_dest''"' != "" & `"``_dest''"' == `"`c(frame)'"' {
	                display as error "output frames cannot replace the current frame"
	                exit 198
	            }
	        }
	        local _rateframe_original `"`rateframe'"'
	        local _modelframes_original `"`modelframes'"'
	        foreach _dest in _displayframe_name _eplotframe_name {
	            if `"``_dest''"' != "" & `"``_dest''"' == `"`_rateframe_original'"' {
	                display as error "output frame ``_dest'' aliases rate source frame `_rateframe_original'"
	                exit 198
	            }
	        }
	        forvalues _f = 1/`n_frames' {
	            local _source_original_`_f' : word `_f' of `_modelframes_original'
	            if `_f' > 1 {
	                forvalues _j = 1/`=`_f'-1' {
	                    if `"`_source_original_`_f''"' == `"`_source_original_`_j''"' {
	                        display as error "modelframes() contains a duplicate source frame"
	                        exit 198
	                    }
	                }
	            }
	            foreach _dest in _displayframe_name _eplotframe_name {
	                if `"``_dest''"' != "" & `"``_dest''"' == `"`_source_original_`_f''"' {
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
	            if `_refmt' & `"`_source_ep_original_`_f''"' == "" {
	                display as error "cformat() requires every model source to have a numeric companion frame"
	                display as error "Hint: create each model frame with regtab, frame() eplotframe()"
	                exit 459
	            }
	            frame `_source_original_`_f'': local _src_layout : char _dta[tabtools_layout]
	            if "`_src_layout'" == "flat" {
	                display as error "Model frame '`_source_original_`_f''' is a flat frame; it is for puttab, not a comptab source"
	                exit 198
	            }
	            if `"`_source_ep_original_`_f''"' != "" {
	                foreach _dest in _displayframe_name _eplotframe_name {
	                    if `"``_dest''"' != "" & `"``_dest''"' == `"`_source_ep_original_`_f''"' {
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
	        local rateframe `"`_rate_snapshot'"'
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

        * Model-frame layout from the persisted statistic identities (F4):
        * with or without a p-value column, standard or compact.
        local _fname1 : word 1 of `modelframes'
        local model_mode ""
        forvalues _f = 1/`n_frames' {
            local _fname : word `_f' of `modelframes'
            frame `_fname' {
                quietly ds c*
                local _model_cvars_f `r(varlist)'
                local _model_cols_f : word count `r(varlist)'
            }
            frame `_fname': local _sid_f : char _dta[tabtools_statistic_ids]
            local _sid_f = strtrim(`"`_sid_f'"')
            if `"`_sid_f'"' == "estimate ci pvalue" {
                local _mode_f "standard"
                local _cpm_f 3
                local _hasp_f 1
            }
            else if `"`_sid_f'"' == "estimate_ci pvalue" {
                local _mode_f "compact"
                local _cpm_f 2
                local _hasp_f 1
            }
            else if `"`_sid_f'"' == "estimate ci" {
                local _mode_f "standardnop"
                local _cpm_f 2
                local _hasp_f 0
            }
            else if `"`_sid_f'"' == "estimate_ci" {
                local _mode_f "compactnop"
                local _cpm_f 1
                local _hasp_f 0
            }
            else {
                display as error "Model frame '`_source_original_`_f''' has unsupported column structure"
                display as error "Expected regtab frame() output (estimate, interval and optional p-value per model)"
                exit 198
            }
            if mod(`_model_cols_f', `_cpm_f') != 0 {
                display as error "Model frame '`_source_original_`_f''' has unsupported column structure"
                exit 198
            }
            local _n_models_f = `_model_cols_f' / `_cpm_f'
            if `_f' == 1 {
                local model_mode "`_mode_f'"
                local _cols_per_model = `_cpm_f'
                local _has_p = `_hasp_f'
                local n_models = `_n_models_f'
                local _model_cvars `"`_model_cvars_f'"'
            }
            else if "`_mode_f'" != "`model_mode'" | `_n_models_f' != `n_models' {
                display as error "All model frames must share the same layout"
                display as error "Frame '`_source_original_1'' is `model_mode' with `n_models' model(s); '`_source_original_`_f''' is `_mode_f' with `_n_models_f' model(s)"
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
	        * The level as shown: at most 15 significant digits, so 99.9 never
	        * prints as the double's 17-digit 99.90000000000001.
	        local _ci_level_label = strtrim(string(`_ci_level', "%21.15g"))
	        forvalues _o = 1/`outcomes' {
	            frame `rateframe': local _rate_outcome_id_`_o' : char _dta[tabtools_outcome_id_`_o']
	            local _rate_header_col = 2 + (`_o' - 1) * 3
	            frame `rateframe': mata: st_local("_rate_display_label_`_o'", st_sdata(2, "c`_rate_header_col'"))
	            * F06 (codex audit 2026-09-27): identities are case sensitive.
	            local _rate_outcome_id_`_o' = strtrim(`"`_rate_outcome_id_`_o''"')
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
	        * allowed only by the analytical outcome ID. A slot may hold several
	        * identities separated by "|": that outcome then takes one effect
	        * column per model (F4). allmodels gives one outcome every block.
	        local _explicit_outcome_map = (`"`outcomemap'"' != "")
	        local _grouped_map 0
	        if `_allmodels' {
	            if `_explicit_outcome_map' {
	                display as error "allmodels and outcomemap() may not be combined"
	                exit 198
	            }
	            if `outcomes' != 1 {
	                display as error "allmodels requires a rate frame with one outcome; use outcomemap(a | b \ c | d) for several"
	                exit 198
	            }
	            local _K = `n_models'
	        }
	        else if `_explicit_outcome_map' {
	            local outcomemap : subinstr local outcomemap " \ " "\", all
	            local outcomemap : subinstr local outcomemap "\  " "\", all
	            local outcomemap : subinstr local outcomemap "  \" "\", all
	            tokenize `"`outcomemap'"', parse("\")
	            local _map_n = 0
	            forvalues _i = 1/100 {
	                local _j = (`_i' - 1) * 2 + 1
	                if `"``_j''"' == "" continue, break
	                local ++_map_n
	                local _map_slot_`_map_n' = strtrim(`"``_j''"')
	            }
	            if `_map_n' != `outcomes' {
	                display as error "outcomemap() requires `outcomes' identities separated by \"
	                exit 198
	            }
	            local _K = .
	            forvalues _o = 1/`outcomes' {
	                local _rest `"`_map_slot_`_o''"'
	                local _k = 0
	                while `"`_rest'"' != "" {
	                    gettoken _item _rest : _rest, parse("|")
	                    if `"`_item'"' == "|" continue
	                    local _item = strtrim(`"`_item'"')
	                    if `"`_item'"' == "" continue
	                    local ++_k
	                    local _map_key_`_o'_`_k' `"`_item'"'
	                }
	                if `_k' == 0 {
	                    display as error "outcomemap() has an empty slot"
	                    exit 198
	                }
	                if missing(`_K') local _K = `_k'
	                else if `_K' != `_k' {
	                    display as error "outcomemap() must give every outcome the same number of models"
	                    exit 198
	                }
	                local _map_key_`_o' `"`_map_key_`_o'_1'"'
	            }
	            if `_K' > 1 local _grouped_map 1
	        }
	        else {
	            local _K = 1
	            forvalues _o = 1/`outcomes' {
	                local _map_key_`_o'_1 `"`_rate_outcome_id_`_o''"'
	                local _map_key_`_o' `"`_rate_outcome_id_`_o''"'
	            }
	        }
	        if !`_allmodels' & !`_grouped_map' & `n_models' != `outcomes' {
	            display as error "Model columns (`n_models') must match rate outcomes (`outcomes')"
	            display as error "Hint: with several models per outcome use allmodels or outcomemap(a | b \ ...)"
	            exit 198
	        }
	        if `_K' > 1 & `"`_eplotframe_name'"' != "" {
	            display as error "eplotframe() and forest support one model per outcome"
	            exit 198
	        }

	        * Effect scale: hazard ratios (HR family) or rate ratios (IRR family).
	        * effect() must truthfully describe the scale of every mapped model.
	        local _effect_norm = lower(strtrim(`"`effect'"'))
	        foreach _punct in " " "-" "_" "." "/" {
	            local _effect_norm : subinstr local _effect_norm `"`_punct'"' "", all
	        }
	        local _hr_names "hr ahr hazardratio adjustedhazardratio"
	        local _irr_names "irr airr rr arr rateratio adjustedrateratio incidencerateratio adjustedincidencerateratio"
	        local _effect_is_hr : list _effect_norm in _hr_names
	        local _effect_is_irr : list _effect_norm in _irr_names
	        if !`_effect_is_hr' & !`_effect_is_irr' {
	            display as error "effect() must truthfully describe a hazard-ratio or rate-ratio scale"
	            exit 198
	        }

	        local _model_stats_ok "estimate ci pvalue|estimate_ci pvalue|estimate ci|estimate_ci"
	        local _scale_family ""
	        forvalues _f = 1/`n_frames' {
	            local _fname : word `_f' of `modelframes'
	            frame `_fname': local _meta_n : char _dta[tabtools_n_models]
	            frame `_fname': local _meta_ci : char _dta[tabtools_ci_level]
	            if real(`"`_meta_n'"') != `n_models' {
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
	                * F06 (codex audit 2026-09-27): model and outcome IDs are
	                * machine identities and stay case sensitive; only the
	                * human model label is matched without regard to case.
	                local _mid_`_m' = strtrim(`"`_mid_`_m''"')
	                local _oid_`_m' = strtrim(`"`_oid_`_m''"')
	                local _mlabel_`_m' = strtrim(`"`_mlabel_`_m''"')
	                local _scale_norm = lower(strtrim(`"`_scale_`_m''"'))
	                foreach _punct in " " "-" "_" "." "/" {
	                    local _scale_norm : subinstr local _scale_norm `"`_punct'"' "", all
	                }
	                if `: list _scale_norm in _hr_names' local _fam "HR"
	                else if `: list _scale_norm in _irr_names' local _fam "IRR"
	                else {
	                    display as error "model frame contains an effect scale that is not a hazard or rate ratio"
	                    exit 198
	                }
	                if "`_scale_family'" == "" local _scale_family "`_fam'"
	                else if "`_scale_family'" != "`_fam'" {
	                    display as error "model frames mix hazard-ratio and rate-ratio scales"
	                    exit 198
	                }
	            }

	            * Each rate outcome takes K model blocks: one by default, every
	            * block with allmodels, or a "|" group per outcome in outcomemap().
	            local _used_model_indices ""
	            forvalues _o = 1/`outcomes' {
	                if `_allmodels' {
	                    forvalues _k = 1/`_K' {
	                        local _mmap_`_f'_`_o'_`_k' = `_k'
	                    }
	                }
	                else {
	                    forvalues _k = 1/`_K' {
	                        local _key `"`_map_key_`_o'_`_k''"'
	                        local _matched_index = 0
	                        local _matched_count = 0
	                        forvalues _m = 1/`n_models' {
	                            local _matches = 0
	                            if `_explicit_outcome_map' {
	                                if `"`_key'"' == `"`_mid_`_m''"' | ///
	                                    `"`_key'"' == `"`_oid_`_m''"' | ///
	                                    lower(`"`_key'"') == lower(`"`_mlabel_`_m''"') local _matches = 1
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
	                            display as error "outcomemap() maps more than one rate outcome or column to the same model block"
	                            exit 198
	                        }
	                        local _used_model_indices `"`_used_model_indices' `_matched_index'"'
	                        local _mmap_`_f'_`_o'_`_k' = `_matched_index'
	                    }
	                }
	                local _model_map_`_f'_`_o' = `_mmap_`_f'_`_o'_1'
	                if `_f' == 1 {
	                    forvalues _k = 1/`_K' {
	                        local _blk1 = `_mmap_1_`_o'_`_k''
	                        local _output_model_id_`_o'_`_k' `"`_mid_`_blk1''"'
	                        local _output_model_label_`_o'_`_k' `"`_mlabel_`_blk1''"'
	                    }
	                    local _output_model_id_`_o' `"`_output_model_id_`_o'_1'"'
	                    local _output_model_label_`_o' `"`_output_model_label_`_o'_1'"'
	                }
	            }
	        }
	        if "`_scale_family'" == "HR" & !`_effect_is_hr' & ///
	            !inlist(`"`_effect_norm'"', "rateratio", "adjustedrateratio") {
	            display as error "effect() must truthfully describe the models' hazard-ratio scale"
	            exit 198
	        }
	        if "`_scale_family'" == "IRR" & !`_effect_is_irr' {
	            display as error "effect() must truthfully describe the models' rate-ratio scale"
	            exit 198
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
                            * C1: the row label is matched in Mata, never expanded.
                            mata: st_local("_pat_hit", strofreal(strmatch(strlower(st_sdata(`_frame_row', "A")), "*" + strlower(st_local("_pat")) + "*")))
                            if `_pat_hit' {
                                if strpos(" `expanded`_f'' ", " `_row' ") {
                                    display as error `"rownames(): pattern "`_pat'" duplicates row `_row' in frame '`_source_original_`_f'''"'
                                    display as error "rownames() patterns must select each model-frame row at most once"
                                    exit 198
                                }
                                local expanded`_f' `"`expanded`_f'' `_row'"'
                                local _matched = 1
                            }
                        }
                    }
                    if !`_matched' {
                        display as error `"rownames(): pattern "`_pat'" not found in frame '`_source_original_`_f'''"'
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
                frame `_fname' {
                    local _fn = _N
                }
                local _max_dr = `_fn' - 3
                if strtrim(`"`_rowspec`_f''"') == "all" & `_keyed' & `_max_dr' >= 1 {
                    local _rowspec`_f' "1/`_max_dr'"
                }
                numlist `"`_rowspec`_f''"'
                local expanded`_f' `r(numlist)'
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

        * Every block index each model frame supplies (K per outcome).
        forvalues _f = 1/`n_frames' {
            local _all_blocks_`_f' ""
            forvalues _o = 1/`outcomes' {
                forvalues _k = 1/`_K' {
                    local _all_blocks_`_f' "`_all_blocks_`_f'' `_mmap_`_f'_`_o'_`_k''"
                }
            }
        }

        local _mo_list ""
        if `_keyed' {
            **# F4 / R1: keyed placement. A selected model row is placed on the
            * rate row whose section|category key equals its heading|level key;
            * never by position. Duplicate keys and unmatched levels are errors.
            forvalues _s = 1/`_n_sec_scan' {
                frame `rateframe': mata: st_local("_sk_`_s'", strlower(strtrim(st_sdata(`_sec_row_`_s'', "c1"))))
                if `_s' > 1 {
                    forvalues _t = 1/`=`_s' - 1' {
                        if `"`_sk_`_s''"' == `"`_sk_`_t''"' {
                            display as error `"rate frame has two sections labelled "`_sk_`_s''"; keyed placement needs unique section|category keys"'
                            exit 198
                        }
                    }
                }
                local _sec_used_`_s' 0
                local _sec_levels_`_s' ""
                local _seen ""
                foreach _cr of local _sec_cats_`_s' {
                    local _rowmap_`_cr' = 0
                    local _rowref_`_cr' = 0
                    frame `rateframe': mata: st_local("_ck_`_cr'", strlower(strtrim(st_sdata(`_cr', "c1"))))
                    foreach _cr2 of local _seen {
                        if `"`_ck_`_cr''"' == `"`_ck_`_cr2''"' {
                            display as error `"rate section "`_sk_`_s''" has two categories labelled "`_ck_`_cr''""'
                            exit 198
                        }
                    }
                    local _seen "`_seen' `_cr'"
                }
            }
            local _pos = 0
            local _mo_keys ""
            forvalues _f = 1/`n_frames' {
                local _fname : word `_f' of `modelframes'
                foreach _rr of local expanded`_f' {
                    local _mr = `_rr' + 3
                    frame `_fname': mata: st_local("_mlab_raw", st_sdata(`_mr', "A"))
                    mata: st_local("_mlab", strtrim(st_local("_mlab_raw")))
                    mata: st_local("_is_level", strofreal(substr(st_local("_mlab_raw"), 1, 2) == "  "))
                    local _all_blank = 1
                    foreach _cv of local _model_cvars {
                        * the cell's text (an interval's sep() among it) is data: tested in Mata
                        frame `_fname': mata: st_local("_mcell_set", strofreal(strtrim(st_sdata(`_mr', "`_cv'")) != ""))
                        if `_mcell_set' local _all_blank = 0
                    }
                    * a heading row carries no estimate; its levels carry the key
                    if `_all_blank' continue
                    local ++_pos
                    local _map_frame`_pos' `"`_fname'"'
                    local _map_f`_pos' = `_f'
                    local _map_source`_pos' `"`_source_original_`_f''"'
                    local _map_row`_pos' = `_mr'
                    local _is_ref = 0
                    foreach _blk of local _all_blocks_`_f' {
                        local _es = 1 + (`_blk' - 1) * `_cols_per_model'
                        capture frame `_fname': confirm numeric variable ref`_es'
                        if _rc == 0 {
                            frame `_fname': local _refv = ref`_es'[`_mr']
                            if !missing(`_refv') local _is_ref = 1
                        }
                        else {
                            frame `_fname': local _reft = lower(strtrim(c`_es'[`_mr']))
                            if `"`_reft'"' == "reference" local _is_ref = 1
                        }
                    }
                    local _blocklab ""
                    if `_is_level' {
                        local _b = `_mr' - 1
                        local _bstop = 0
                        while `_b' >= 4 & !`_bstop' {
                            frame `_fname': mata: st_local("_bl", strofreal(substr(st_sdata(`_b', "A"), 1, 2) == "  "))
                            if `_bl' local --_b
                            else local _bstop = 1
                        }
                        if `_b' >= 4 frame `_fname': mata: st_local("_blocklab", strtrim(st_sdata(`_b', "A")))
                    }
                    mata: st_local("_bk", strlower(st_local("_blocklab")))
                    mata: st_local("_lk", strlower(st_local("_mlab")))
                    local _target = 0
                    local _tsec = 0
                    if `_is_level' & `"`_blocklab'"' != "" {
                        forvalues _s = 1/`_n_sec_scan' {
                            if `"`_sk_`_s''"' == `"`_bk'"' local _tsec = `_s'
                        }
                        if `_tsec' {
                            foreach _cr of local _sec_cats_`_tsec' {
                                if `"`_ck_`_cr''"' == `"`_lk'"' local _target = `_cr'
                            }
                            if !`_target' {
                                display as error `"model row `_rr' ("`macval(_blocklab)'|`macval(_mlab)'") of frame '`_source_original_`_f''' matches no category of rate section "`macval(_blocklab)'""'
                                display as error "keyed placement needs the model's level labels to equal the rate categories"
                                exit 198
                            }
                        }
                    }
                    else if !`_is_level' {
                        * R1 exact-or-error: only a factor level (block heading
                        * plus level label) has an identity that can fill a rate
                        * category. A plain row (a 0/1 indicator or a continuous
                        * term) whose label equals a section or category label
                        * would be placed by resemblance, so it is refused.
                        local _clash ""
                        forvalues _s = 1/`_n_sec_scan' {
                            if `"`_sk_`_s''"' == `"`_lk'"' local _clash "section"
                            foreach _cr of local _sec_cats_`_s' {
                                if `"`_ck_`_cr''"' == `"`_lk'"' local _clash "category"
                            }
                        }
                        if "`_clash'" != "" {
                            display as error `"model row `_rr' ("`macval(_mlab)'") of frame '`_source_original_`_f''' is not a factor level, but its label equals a rate `_clash' label"'
                            display as error "keyed placement fills a rate category only from a factor level; fit the variable as i.varname with the rate frame's labels, or relabel the row"
                            exit 198
                        }
                    }
                    if `_target' {
                        if `_rowmap_`_target'' != 0 {
                            frame `rateframe': mata: st_local("_clab", strtrim(st_sdata(`_target', "c1")))
                            display as error `"two selected model rows have the key "`macval(_blocklab)'|`macval(_clab)'""'
                            exit 198
                        }
                        local _rowmap_`_target' = `_pos'
                        local _rowref_`_target' = `_is_ref'
                        local _sec_used_`_tsec' 1
                        if `_is_level' local _sec_levels_`_tsec' "`_sec_levels_`_tsec'' `_pos'"
                    }
                    else {
                        if !`_modelonly' {
                            display as error `"model row `_rr' ("`macval(_blocklab)'|`macval(_mlab)'") of frame '`_source_original_`_f''' has no rate row"'
                            display as error "Hint: specify modelonly to list model rows without a rate section after the table"
                            exit 198
                        }
                        mata: st_local("_mokey", strlower(st_local("_blocklab")) + "|" + strlower(st_local("_mlab")))
                        forvalues _q = 1/`_pos' {
                            if `"`_mokey_`_q''"' != "" & `"`_mokey_`_q''"' == `"`_mokey'"' {
                                display as error `"two selected model rows have the key "`macval(_mokey)'""'
                                exit 198
                            }
                        }
                        local _mokey_`_pos' `"`_mokey'"'
                        local _moblock_`_pos' `"`_blocklab'"'
                        local _molevel_`_pos' = `_is_level'
                        local _mo_list "`_mo_list' `_pos'"
                    }
                }
            }
            local _selected_total = `_pos'
            if `_pos' == 0 {
                display as error "no model rows with estimates were selected"
                exit 198
            }

            * Reference per section with model rows; sections without carry rates only.
            local ref_rows ""
            local nonref_rows ""
            forvalues _s = 1/`_n_sec_scan' {
                if !`_sec_used_`_s'' continue
                frame `rateframe': mata: st_local("_sec_label", strtrim(st_sdata(`_sec_row_`_s'', "c1")))
                local _unf ""
                local _nexp = 0
                foreach _cr of local _sec_cats_`_s' {
                    if `_rowmap_`_cr'' == 0 local _unf "`_unf' `_cr'"
                    else if `_rowref_`_cr'' {
                        local ++_nexp
                        local ref_rows "`ref_rows' `_cr'"
                    }
                    else local nonref_rows "`nonref_rows' `_cr'"
                }
                local _nunf : word count `_unf'
                if `_nexp' > 1 | (`_nexp' == 1 & `_nunf' > 0) | (`_nexp' == 0 & `_nunf' != 1) {
                    display as error `"rate section "`macval(_sec_label)'": `_nunf' categor(ies) have no model row and `_nexp' reference row(s) were selected"'
                    display as error "select every level of the model block, or every level but its reference"
                    exit 198
                }
                if `_nexp' == 1 continue
                local _ref_row = strtrim("`_unf'")
                local ref_rows "`ref_rows' `_ref_row'"
                frame `rateframe': mata: st_local("_ref_lab", strtrim(st_sdata(`_ref_row', "c1")))
                * The unfilled category is labelled as the reference, so it must
                * be the base level of every factor block that supplied a level.
                foreach _i of local _sec_levels_`_s' {
                    local _mfn `"`_map_frame`_i''"'
                    local _mff = `_map_f`_i''
                    local _mr = `_map_row`_i''
                    local _msrc `"`_source_original_`_mff''"'
                    frame `_mfn': local _mfN = _N
                    local _b0 = `_mr'
                    local _bstop = 0
                    while `_b0' > 4 & !`_bstop' {
                        frame `_mfn': local _bprev_lvl = (substr(A[`=`_b0' - 1'], 1, 2) == "  ")
                        if `_bprev_lvl' local --_b0
                        else local _bstop = 1
                    }
                    local _b1 = `_mr'
                    local _bstop = 0
                    while `_b1' < `_mfN' & !`_bstop' {
                        frame `_mfn': local _bnext_lvl = (substr(A[`=`_b1' + 1'], 1, 2) == "  ")
                        if `_bnext_lvl' local ++_b1
                        else local _bstop = 1
                    }
                    local _base_found = 0
                    forvalues _br = `_b0'/`_b1' {
                        frame `_mfn': mata: st_local("_same", strofreal(strlower(strtrim(st_sdata(`_br', "A"))) == strlower(st_local("_ref_lab"))))
                        if `_same' {
                            local _all_ref = 1
                            foreach _blk of local _all_blocks_`_mff' {
                                local _es = 1 + (`_blk' - 1) * `_cols_per_model'
                                local _br_ref = 0
                                capture frame `_mfn': confirm numeric variable ref`_es'
                                if _rc == 0 {
                                    frame `_mfn': local _refv = ref`_es'[`_br']
                                    if !missing(`_refv') local _br_ref = 1
                                }
                                else {
                                    frame `_mfn': local _reft = lower(strtrim(c`_es'[`_br']))
                                    if `"`_reft'"' == "reference" local _br_ref = 1
                                }
                                if !`_br_ref' local _all_ref = 0
                            }
                            if `_all_ref' local _base_found = 1
                        }
                    }
                    if !`_base_found' {
                        display as error `"rate category "`macval(_ref_lab)'" in section "`macval(_sec_label)'" would be shown as the reference,"'
                        display as error `"but it is not the reference category of the model in frame '`_msrc''"'
                        exit 198
                    }
                }
            }
            local ref_rows : list clean ref_rows
            local nonref_rows : list clean nonref_rows
        }
        else {
        local _selected_total = 0
        local _map_i = 0
        forvalues _f = 1/`n_frames' {
            local _fname : word `_f' of `modelframes'
            local _spec_rows `"`expanded`_f''"'
            foreach _rr of local _spec_rows {
	                local ++_selected_total
	                local ++_map_i
	                local _map_frame`_map_i' `"`_fname'"'
	                local _map_f`_map_i' = `_f'
	                local _map_source`_map_i' `"`_source_original_`_f''"'
	                local _map_row`_map_i' = `_rr' + 3
            }
        }

        if `_selected_total' != `n_nonref' {
            display as error "Selected model rows (`_selected_total') must match non-reference scaffold rows (`n_nonref')"
            display as error "Hint: select one model row for each non-reference row in the stratetab frame"
            exit 198
        }

        * Place every selected model row on the scaffold row with the same
        * category label. The selections are consumed section by section in
        * scaffold order (a section with k categories takes k-1 rows), but
        * within a section they are matched by label, never by position:
        * positional filling silently put one category's HR on another's row
        * whenever the selection order, the model's reference category, or a
        * stray heading/reference row differed from the scaffold. The one
        * category left unfilled is the reference; for factor-variable rows it
        * must be the model's own base level. The only positional case is a
        * plain (non-factor) row, such as a 0/1 indicator, whose label matches
        * no category of a two-category section: it fills the second category.
        local _pos = 0
        local ref_rows ""
        local nonref_rows ""
        forvalues _s = 1/`_n_sec_scan' {
            local _cats `"`_sec_cats_`_s''"'
            local _k : word count `_cats'
            if `_k' == 0 continue
            frame `rateframe': mata: st_local("_sec_label", strtrim(st_sdata(`_sec_row_`_s'', "c1")))
            foreach _cr of local _cats {
                local _rowmap_`_cr' = 0
            }
            local _sec_levels ""
            forvalues _j = 1/`=`_k' - 1' {
                local ++_pos
                local _mfn `"`_map_frame`_pos''"'
                local _mff = `_map_f`_pos''
                local _mr = `_map_row`_pos''
                local _mdr = `_mr' - 3
                local _msrc `"`_source_original_`_mff''"'
                frame `_mfn': mata: st_local("_mlab_raw", st_sdata(`_mr', "A"))
                mata: st_local("_mlab", strtrim(st_local("_mlab_raw")))
                mata: st_local("_is_level", strofreal(substr(st_local("_mlab_raw"), 1, 2) == "  "))

                local _all_blank = 1
                foreach _cv of local _model_cvars {
                    * the cell's text (an interval's sep() among it) is data: tested in Mata
                    frame `_mfn': mata: st_local("_mcell_set", strofreal(strtrim(st_sdata(`_mr', "`_cv'")) != ""))
                    if `_mcell_set' local _all_blank = 0
                }
                if `_all_blank' {
                    display as error `"model row `_mdr' ("`macval(_mlab)'") of frame '`_msrc'' is a heading row with no estimate"'
                    display as error "Hint: select only effect rows; rows are counted after the 3 regtab header rows"
                    exit 198
                }
                local _is_ref = 0
                foreach _blk of local _all_blocks_`_mff' {
                    local _es = 1 + (`_blk' - 1) * `_cols_per_model'
                    * regtab flags reference/omitted/empty rows in the numeric
                    * ref<estcol> variable; without it, use the default text.
                    capture frame `_mfn': confirm numeric variable ref`_es'
                    if _rc == 0 {
                        frame `_mfn': local _refv = ref`_es'[`_mr']
                        if !missing(`_refv') local _is_ref = 1
                    }
                    else {
                        frame `_mfn': local _reft = lower(strtrim(c`_es'[`_mr']))
                        if `"`_reft'"' == "reference" local _is_ref = 1
                    }
                }
                if `_is_ref' {
                    display as error `"model row `_mdr' ("`macval(_mlab)'") of frame '`_msrc'' is the model's reference (or an omitted) category"'
                    display as error "Hint: select only the non-reference rows; the reference row is filled with reflabel()"
                    exit 198
                }

                local _target = 0
                foreach _cr of local _cats {
                    frame `rateframe': mata: st_local("_same", strofreal(strlower(strtrim(st_sdata(`_cr', "c1"))) == strlower(st_local("_mlab"))))
                    if `_same' local _target = `_cr'
                }
                if `_target' == 0 {
                    if !`_is_level' & `_k' == 2 {
                        local _target : word 2 of `_cats'
                    }
                    else {
                        display as error `"model row `_mdr' ("`macval(_mlab)'") of frame '`_msrc'' matches no category of rate section "`macval(_sec_label)'""'
                        display as error "Hint: hrcomptab places model rows by label; give the model's factor variable the value labels used for strate"
                        exit 198
                    }
                }
                if `_rowmap_`_target'' != 0 {
                    frame `rateframe': mata: st_local("_clab", strtrim(st_sdata(`_target', "c1")))
                    display as error `"two selected model rows map to rate category "`macval(_clab)'" in section "`macval(_sec_label)'""'
                    exit 198
                }
                local _rowmap_`_target' = `_pos'
                if `_is_level' local _sec_levels `"`_sec_levels' `_pos'"'
            }

            local _ref_row = 0
            foreach _cr of local _cats {
                if `_rowmap_`_cr'' == 0 local _ref_row = `_cr'
                else local nonref_rows `"`nonref_rows' `_cr'"'
            }
            local ref_rows `"`ref_rows' `_ref_row'"'
            frame `rateframe': mata: st_local("_ref_lab", strtrim(st_sdata(`_ref_row', "c1")))

            * The unfilled category is labelled as the reference, so it must be
            * the base level of every factor block that supplied an estimate.
            foreach _i of local _sec_levels {
                local _mfn `"`_map_frame`_i''"'
                local _mff = `_map_f`_i''
                local _mr = `_map_row`_i''
                local _msrc `"`_source_original_`_mff''"'
                frame `_mfn': local _mfN = _N
                local _b0 = `_mr'
                local _bstop = 0
                while `_b0' > 4 & !`_bstop' {
                    frame `_mfn': local _bprev_lvl = (substr(A[`=`_b0' - 1'], 1, 2) == "  ")
                    if `_bprev_lvl' local --_b0
                    else local _bstop = 1
                }
                local _b1 = `_mr'
                local _bstop = 0
                while `_b1' < `_mfN' & !`_bstop' {
                    frame `_mfn': local _bnext_lvl = (substr(A[`=`_b1' + 1'], 1, 2) == "  ")
                    if `_bnext_lvl' local ++_b1
                    else local _bstop = 1
                }
                local _base_found = 0
                forvalues _br = `_b0'/`_b1' {
                    frame `_mfn': mata: st_local("_same", strofreal(strlower(strtrim(st_sdata(`_br', "A"))) == strlower(st_local("_ref_lab"))))
                    if `_same' {
                        local _all_ref = 1
                        foreach _blk of local _all_blocks_`_mff' {
                            local _es = 1 + (`_blk' - 1) * `_cols_per_model'
                            local _br_ref = 0
                            capture frame `_mfn': confirm numeric variable ref`_es'
                            if _rc == 0 {
                                frame `_mfn': local _refv = ref`_es'[`_br']
                                if !missing(`_refv') local _br_ref = 1
                            }
                            else {
                                frame `_mfn': local _reft = lower(strtrim(c`_es'[`_br']))
                                if `"`_reft'"' == "reference" local _br_ref = 1
                            }
                            if !`_br_ref' local _all_ref = 0
                        }
                        if `_all_ref' local _base_found = 1
                    }
                }
                if !`_base_found' {
                    display as error `"rate category "`macval(_ref_lab)'" in section "`macval(_sec_label)'" would be shown as the reference,"'
                    display as error `"but it is not the reference category of the model in frame '`_msrc''"'
                    display as error "Hint: select every non-reference level of the model, or refit it with the intended base level (ib#.)"
                    exit 198
                }
            }
        }
        local ref_rows : list clean ref_rows
        local nonref_rows : list clean nonref_rows
        } // end positional placement

	        local _eplot_build_name ""
	        if `"`_eplotframe_name'"' != "" {
	            tempname _eplot_build
	            local _eplot_build_name `"`_eplot_build'"'
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
                * C1: labels are copied in Mata and stored after each post,
                * never expanded as macro syntax.
                frame `rateframe' {
                    mata: st_local("_rate_lab_ep", st_sdata(`_r', "c1"))
                }
                if strpos("`_section_rows_sp'", " `_r' ") {
                    mata: st_local("_current_section", strtrim(st_local("_rate_lab_ep")))
                    if strpos("`_fold_sections'", " `_r' ") {
                        local _pending_fold_label : copy local _current_section
                    }
                    else {
                        local _pending_fold_label ""
	                        frame post `_eplot_build_name' ("") (.) (.) (.) (.) ///
	                            (.) ("") ("section") ("") (.) (`"`_rateframe_original'"')
	                        frame `_eplot_build_name' {
	                            mata: st_sstore(st_nobs(), "label", st_local("_current_section"))
	                            mata: st_sstore(st_nobs(), "section", st_local("_current_section"))
	                        }
                    }
                    continue
                }
                if strpos("`_ref_rows_sp'", " `_r' ") {
                    local _ref_post_label : copy local _rate_lab_ep
                    if `"`macval(_pending_fold_label)'"' != "" {
                        local _ref_post_label : copy local _pending_fold_label
                        local _pending_fold_label ""
                    }
	                    frame post `_eplot_build_name' ("") (.) (.) (.) (.) ///
	                        (.) ("") ("reference") ("") (.) (`"`_rateframe_original'"')
	                    frame `_eplot_build_name' {
	                        mata: st_sstore(st_nobs(), "label", st_local("_ref_post_label"))
	                        mata: st_sstore(st_nobs(), "section", st_local("_current_section"))
	                    }
                    continue
                }

	                local _next_model_ep = 0
	                if `"`_rowmap_`_r''"' != "" local _next_model_ep = `_rowmap_`_r''
	                if `_next_model_ep' == 0 continue
	                local _mfname_ep `"`_map_frame`_next_model_ep''"'
	                local _mfindex_ep = `_map_f`_next_model_ep''
	                local _mfsource_ep `"`_map_source`_next_model_ep''"'
	                local _src_row_ep = `_map_row`_next_model_ep'' - 3
                local _src_ep ""
                capture frame `_mfname_ep': local _src_ep : char _dta[tabtools_eplotframe]
                local _src_ep_rc = _rc
                if `_src_ep_rc' == 0 & `"`_src_ep'"' != "" {
                    capture frame `_src_ep': quietly count
                    local _src_ep_rc = _rc
                    if `_src_ep_rc' == 0 {
                        frame `_mfname_ep': local _display_pair : char _dta[tabtools_companion_id]
                        frame `_src_ep': local _numeric_pair : char _dta[tabtools_companion_id]
                        mata: st_local("_same_pair", strofreal( ///
                            st_local("_display_pair") != "" & ///
                            st_local("_display_pair") == st_local("_numeric_pair")))
                        if !`_same_pair' {
                            display as error "model display and numeric companion have missing or different tabtools_companion_id"
                            display as error "Recreate the model display and eplotframe together with regtab or effecttab"
                            exit 459
                        }
	                        forvalues _o = 1/`outcomes' {
	                            local _source_model_ep = `_model_map_`_mfindex_ep'_`_o''
	                            local _found_ep = 0
	                            frame `_src_ep' {
	                                local _ep_N = _N
	                                forvalues _ep_i = 1/`_ep_N' {
	                                    if source_row[`_ep_i'] == `_src_row_ep' & model[`_ep_i'] == `_source_model_ep' {
	                                        local ++_found_ep
	                                    mata: st_local("_ep_label", st_sdata(`_ep_i', "label"))
	                                    local _ep_est = estimate[`_ep_i']
                                    local _ep_ll = ll[`_ep_i']
                                    local _ep_ul = ul[`_ep_i']
                                    local _ep_p = pvalue[`_ep_i']
	                                    local _ep_model = `_o'
	                                    local _ep_model_label : copy local _rate_display_label_`_o'
                                    local _ep_rowtype = rowtype[`_ep_i']
                                    local _ep_post_label : copy local _ep_label
                                    if `"`macval(_pending_fold_label)'"' != "" {
                                        local _ep_post_label : copy local _pending_fold_label
                                        local _pending_fold_label ""
                                    }
	                                    frame post `_eplot_build_name' ("") (`_ep_est') (`_ep_ll') (`_ep_ul') ///
	                                        (`_ep_p') (`_ep_model') ("") (`"`_ep_rowtype'"') ///
	                                        ("") (`_src_row_ep') (`"`_mfsource_ep'"')
	                                    frame `_eplot_build_name' {
	                                        mata: st_sstore(st_nobs(), "label", st_local("_ep_post_label"))
	                                        mata: st_sstore(st_nobs(), "model_label", st_local("_ep_model_label"))
	                                        mata: st_sstore(st_nobs(), "section", st_local("_current_section"))
	                                    }
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
	            frame `_eplot_build_name': mata: st_global("_dta[tabtools_companion_id]", st_local("_companion_id"))
	            frame `_eplot_build_name': char _dta[tabtools_source] "hrcomptab"
	            frame `_eplot_build_name': char _dta[tabtools_ci_level] "`_ci_level_label'"
	            frame `_eplot_build_name': char _dta[tabtools_n_models] "`outcomes'"
	            frame `_eplot_build_name': char _dta[tabtools_statistic_ids] "estimate ci pvalue"
	            forvalues _o = 1/`outcomes' {
	                frame `_eplot_build_name': char _dta[tabtools_model_id_`_o'] `"`_output_model_id_`_o''"'
	                frame `_eplot_build_name': char _dta[tabtools_outcome_id_`_o'] `"`_rate_outcome_id_`_o''"'
	                frame `_eplot_build_name': char _dta[tabtools_effect_scale_`_o'] "`_scale_family'"
	            }
	        }

        * Build output table: per outcome events, person-time, rate, then K
        * effect columns (each with its p-value when the model frames have one).
        local _w = 1 + `_has_p'
        local _bw = 3 + `_K' * `_w'
        local ncols = 1 + `_bw' * `outcomes'
        local _out_title `"`macval(title)'"'
        if `"`macval(_out_title)'"' == "" local _out_title : copy local _rate_title

        * Model-only rows (keyed modelonly): a heading row whenever the model
        * block changes, then the rows in model-frame order.
        local _mo_seq ""
        local _mo_prev_block ""
        local _mo_first 1
        foreach _i of local _mo_list {
            if `_molevel_`_i'' & (`_mo_first' | `"`_moblock_`_i''"' != `"`_mo_prev_block'"') {
                local _mo_seq "`_mo_seq' h`_i'"
            }
            local _mo_seq "`_mo_seq' r`_i'"
            local _mo_prev_block `"`_moblock_`_i''"'
            if !`_molevel_`_i'' local _mo_prev_block ""
            local _mo_first 0
        }
        local _n_mo_rows : word count `_mo_seq'
        local _n_mo : word count `_mo_list'
        local _out_rows = `_rate_rows' + `_n_mo_rows'

        clear
        quietly set obs `_out_rows'
        quietly gen str244 title = ""
        forvalues _c = 1/`ncols' {
            quietly gen str244 c`_c' = ""
        }
        quietly replace title = `"`macval(_out_title)'"' in 1

        * Header rows
        frame `rateframe' {
            mata: st_local("_exp_header", st_sdata(2, "c1"))
        }
        quietly replace c1 = `"`macval(_exp_header)'"' in 2
        quietly replace c1 = "" in 3

        forvalues _o = 1/`outcomes' {
            local _rate_s = 2 + (`_o' - 1) * 3
            local _out_s = 2 + (`_o' - 1) * `_bw'
            frame `rateframe' {
                mata: st_local("_outcome_header", st_sdata(2, "c`_rate_s'"))
                local _hdr_events = c`_rate_s'[3]
                local _hdr_py = c`=`_rate_s' + 1'[3]
                local _hdr_rate = c`=`_rate_s' + 2'[3]
            }
            quietly replace c`_out_s' = `"`macval(_outcome_header)'"' in 2
            quietly replace c`_out_s' = `"`_hdr_events'"' in 3
            quietly replace c`=`_out_s' + 1' = `"`_hdr_py'"' in 3
            quietly replace c`=`_out_s' + 2' = `"`_hdr_rate'"' in 3
            forvalues _k = 1/`_K' {
                local _ec = `_out_s' + 3 + (`_k' - 1) * `_w'
                local _mlk `"`_output_model_label_`_o'_`_k''"'
                if `"`_mlk'"' == "" local _mlk "Model `_k'"
                if `_K' == 1 {
                    quietly replace c`_ec' = `"`effect' (`_ci_level_label'% CI)"' in 3
                    if `_has_p' quietly replace c`=`_ec' + 1' = "p-value" in 3
                }
                else {
                    quietly replace c`_ec' = `"`_mlk', `effect' (`_ci_level_label'% CI)"' in 3
                    if `_has_p' quietly replace c`=`_ec' + 1' = `"`_mlk', p-value"' in 3
                }
            }
        }

        * Data rows follow the stratetab scaffold exactly
        local _section_rows_sp " `section_rows' "
        local _ref_rows_sp " `ref_rows' "
        local _refmt_opts ""
        if `_refmt' local _refmt_opts `"cformat(`cformat')"'
        if `_resep' mata: st_local("_refmt_opts", st_local("_refmt_opts") + " " + _tt_sep_optarg("cisep", st_local("cisep")))

        forvalues _r = 4/`_rate_rows' {
            frame `rateframe' {
                mata: st_local("_rate_lab", st_sdata(`_r', "c1"))
            }
            quietly replace c1 = `"`macval(_rate_lab)'"' in `_r'

            forvalues _o = 1/`outcomes' {
                local _rate_s = 2 + (`_o' - 1) * 3
                local _out_s = 2 + (`_o' - 1) * `_bw'
                frame `rateframe' {
                    local _rate_events = c`_rate_s'[`_r']
                    local _rate_py = c`=`_rate_s' + 1'[`_r']
                    local _rate_rate = c`=`_rate_s' + 2'[`_r']
                }
                * copied as stored (a rate interval's sep() is data)
                quietly replace c`_out_s' = `"`macval(_rate_events)'"' in `_r'
                quietly replace c`=`_out_s' + 1' = `"`macval(_rate_py)'"' in `_r'
                quietly replace c`=`_out_s' + 2' = `"`macval(_rate_rate)'"' in `_r'
            }

            if strpos("`_section_rows_sp'", " `_r' ") continue

            if strpos("`_ref_rows_sp'", " `_r' ") {
                forvalues _o = 1/`outcomes' {
                    forvalues _k = 1/`_K' {
                        local _ec = 2 + (`_o' - 1) * `_bw' + 3 + (`_k' - 1) * `_w'
                        quietly replace c`_ec' = `"`reflabel'"' in `_r'
                    }
                }
                continue
            }

            local _next_model = 0
            if `"`_rowmap_`_r''"' != "" local _next_model = `_rowmap_`_r''
            if `_next_model' == 0 continue
            local _mfname `"`_map_frame`_next_model''"'
            local _mfindex = `_map_f`_next_model''
            local _mrow = `_map_row`_next_model''
            forvalues _o = 1/`outcomes' {
                forvalues _k = 1/`_K' {
                    local _ec = 2 + (`_o' - 1) * `_bw' + 3 + (`_k' - 1) * `_w'
                    _comptab_effect_cell, frame(`_mfname') row(`_mrow') ///
                        block(`_mmap_`_mfindex'_`_o'_`_k'') mode(`model_mode') ///
                        cpm(`_cols_per_model') `macval(_refmt_opts)'
                    mata: st_local("_ec_text", st_global("r(text)"))
                    quietly replace c`_ec' = `"`macval(_ec_text)'"' in `_r'
                    if `_has_p' quietly replace c`=`_ec' + 1' = `"`r(p)'"' in `_r'
                }
            }
        }

        * Model-only rows after the scaffold
        local _r = `_rate_rows'
        local _mo_head_rows ""
        foreach _e of local _mo_seq {
            local ++_r
            local _i = substr("`_e'", 2, .)
            if substr("`_e'", 1, 1) == "h" {
                quietly replace c1 = `"`_moblock_`_i''"' in `_r'
                local _mo_head_rows "`_mo_head_rows' `_r'"
                continue
            }
            local _mfname `"`_map_frame`_i''"'
            local _mfindex = `_map_f`_i''
            local _mrow = `_map_row`_i''
            frame `_mfname': mata: st_local("_mo_lab", strtrim(st_sdata(`_mrow', "A")))
            if `_molevel_`_i'' local _mo_lab `"   `_mo_lab'"'
            quietly replace c1 = `"`_mo_lab'"' in `_r'
            if `_r' == `_rate_rows' + 1 & !`_molevel_`_i'' local _mo_head_rows "`_mo_head_rows' `_r'"
            forvalues _o = 1/`outcomes' {
                forvalues _k = 1/`_K' {
                    local _ec = 2 + (`_o' - 1) * `_bw' + 3 + (`_k' - 1) * `_w'
                    _comptab_effect_cell, frame(`_mfname') row(`_mrow') ///
                        block(`_mmap_`_mfindex'_`_o'_`_k'') mode(`model_mode') ///
                        cpm(`_cols_per_model') `macval(_refmt_opts)'
                    mata: st_local("_ec_text", st_global("r(text)"))
                    quietly replace c`_ec' = `"`macval(_ec_text)'"' in `_r'
                    if `_has_p' quietly replace c`=`_ec' + 1' = `"`r(p)'"' in `_r'
                }
            }
        }

        local lastrow = _N
        local exp_rows `"`section_rows' `_mo_head_rows'"'

        * Console display
        noisily _tabtools_console_display `ncols' `"`macval(_out_title)'"', datastart(4) headerstart(2)
        if `"`macval(footnote)'"' != "" {
            noisily display as text `"`macval(footnote)'"'
            noisily display as text ""
        }

        * CSV export
        if "`csv'" != "" {
            order title c*
            _tabtools_csv_write using "`csv'", reservedrow title(`"`macval(_out_title)'"') footnote(`"`macval(footnote)'"')
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
                `_mdappend_opt' title(`"`macval(_out_title)'"') footnote(`"`macval(footnote)'"') strictheaders
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
	            local _display_build_name `"`_display_build'"'
	            frame put *, into(`_display_build_name')
	            frame `_display_build_name': mata: st_global("_dta[tabtools_companion_id]", st_local("_companion_id"))
	            frame `_display_build_name': char _dta[tabtools_source] "hrcomptab"
	            frame `_display_build_name': char _dta[tabtools_ci_level] "`_ci_level_label'"
	            frame `_display_build_name': char _dta[tabtools_n_outcomes] "`outcomes'"
	            local _disp_stats "events person_years rate_ci"
	            forvalues _k = 1/`_K' {
	                local _disp_stats "`_disp_stats' estimate_ci"
	                if `_has_p' local _disp_stats "`_disp_stats' pvalue"
	            }
	            frame `_display_build_name': char _dta[tabtools_statistic_ids] "`_disp_stats'"
	            frame `_display_build_name': char _dta[tabtools_models_per_outcome] "`_K'"
	            if `"`_eplotframe_name'"' != "" & !`_eplotframe_temporary' {
	                frame `_display_build_name': char _dta[tabtools_eplotframe] "`_eplotframe_name'"
	            }
	            forvalues _o = 1/`outcomes' {
	                frame `_display_build_name': char _dta[tabtools_model_id_`_o'] `"`_output_model_id_`_o''"'
	                frame `_display_build_name': char _dta[tabtools_outcome_id_`_o'] `"`_rate_outcome_id_`_o''"'
	                frame `_display_build_name': char _dta[tabtools_effect_scale_`_o'] "`_scale_family'"
	            }
	            if `_displayframe_flat' {
	                local _flat_cols ""
	                local _flat_starts ""
	                forvalues _fc = 2/`ncols' {
	                    local _flat_cols "`_flat_cols' c`_fc'"
	                    if mod(`_fc' - 2, `_bw') == 0 local _flat_starts "`_flat_starts' `=`_fc' - 1'"
	                }
	                frame `_display_build_name': _comptab_flatten, labelvar(c1) ///
	                    cols(`_flat_cols') blockstarts(`_flat_starts')
	            }
	            local frame `"`_displayframe_name'"'
	        }
	        if `"$TABTOOLS_QA_HRC_STAGE_FAIL"' == "1" error 459

	        return scalar N_rows = `lastrow'
        return scalar N_outcomes = `outcomes'
        return scalar N_sections = `n_sections'
        return scalar N_modelrows = `_selected_total'
        return scalar N_modelframes = `n_frames'
        return scalar N_models_per_outcome = `_K'
        return scalar N_modelonly = `_n_mo'
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
                local _block_pos = mod(`_c' - 2, `_bw')
                * positions 3+ alternate effect and p-value when there is a p
                if `_block_pos' >= 3 {
                    if `_has_p' & mod(`_block_pos' - 3, 2) == 1 local _block_pos = 4
                    else local _block_pos = 3
                }
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
            capture noisily _tabtools_xlsx_write using "`xlsx'", sheet(`"`macval(sheet)'"') book(`_xlsx_book')
            if _rc {
                local _export_rc = _rc
                display as error "Failed to export to `xlsx'"
                display as error "Hint: ensure the xlsx file is not open in another application"
                exit `_export_rc'
            }
            * Excel sheet names are case-insensitive; keep the workbook's own
            * spelling when an existing sheet was replaced.
            mata: st_local("sheet", st_global("r(sheet)"))
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
                    local _col_end = `_merge_col' + `_bw' - 1
                    local _style_rule_spec `"`_style_rule_spec' | 14 2 2 `_merge_col' `_col_end' 0 0 0 0 | 2 2 2 `_merge_col' `_merge_col' 0 1 0 0 | 5 2 2 `_merge_col' `_merge_col' 0 2 0 0 | 6 2 2 `_merge_col' `_merge_col' 0 3 0 0 | 9 2 2 `_merge_col' `_col_end' 0 `_hborder_code' 0 0"'
                    local _merge_col = `_merge_col' + `_bw'
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
                        local _col_end = `_vcol' + `_bw' - 1
                        local _style_rule_spec `"`_style_rule_spec' | 11 2 `lastrow' `_col_end' `_col_end' 0 `_vborder_code' 0 0"'
                        local _vcol = `_vcol' + `_bw'
                    }
                }
                foreach _sr of local exp_rows {
                    local _border_row = `_sr' - 1
                    if `_border_row' > 3 {
                        local _style_rule_spec `"`_style_rule_spec' | 9 `_border_row' `_border_row' 2 `_total_cols' 0 `_hborder_code' 0 0"'
                    }
                }
                local _style_rule_spec `"`_style_rule_spec' | 9 `lastrow' `lastrow' 2 `_total_cols' 0 `_hborder_code' 0 0"'

                if `"`macval(footnote)'"' != "" {
                    local _fn_fontsize = max(`_fontsize' - 2, 6)
                    * One row per paragraph; " \ " separates paragraphs.
                    local _fn_rest `"`macval(footnote)'"'
                    local _fp 0
                    while `"`macval(_fn_rest)'"' != "" {
                        local _fn_at = strpos(`"`macval(_fn_rest)'"', " \ ")
                        if `_fn_at' == 0 {
                            local _fn_piece `"`macval(_fn_rest)'"'
                            local _fn_rest ""
                        }
                        else {
                            local _fn_piece = substr(`"`macval(_fn_rest)'"', 1, `_fn_at' - 1)
                            local _fn_rest = substr(`"`macval(_fn_rest)'"', `_fn_at' + 3, .)
                        }
                        local ++_fp
                        local _fn_row = `lastrow' + `_fp'
                        mata: `_xlsx_book'.put_string(`_fn_row', 2, strtrim(st_local("_fn_piece")))
                        local _style_rule_spec `"`_style_rule_spec' | 14 `_fn_row' `_fn_row' 2 `_total_cols' 0 0 0 0 | 5 `_fn_row' `_fn_row' 2 2 0 1 0 0 | 6 `_fn_row' `_fn_row' 2 2 0 2 0 0 | 4 `_fn_row' `_fn_row' 2 2 0 1 0 0 | 1 `_fn_row' `_fn_row' 2 2 `_fn_fontsize' 1 0 0 | 3 `_fn_row' `_fn_row' 2 2 0 1 0 0"'
                    }
                }

                _tabtools_xlsx_build_styles, matrix(`_style_rules') ///
                    rules(`_style_rule_spec') cols(9)
                _tabtools_xlsx_apply_styles, defer book(`_xlsx_book') sheet(`"`macval(sheet)'"') ///
                    rules(`_style_rules') font("`_font'") ///
                    color1("`_headercolor'") color2("`_zebracolor'")
                mata: `_xlsx_book'.close_book()

                * xl() appends a style record for every styled cell instead of
                * reusing one per distinct format, so collapse the pools here;
                * a workbook that keeps growing would otherwise reach Stata's
                * 65,536-record ceiling and fail with r(16147).
                _tabtools_xlsx_compact_styles using "`xlsx'"
            }
            if _rc {
                local _fmt_rc = _rc
                capture mata: `_xlsx_book'.close_book()
                capture mata: mata drop `_xlsx_book'
                display as error "Excel formatting failed with error `_fmt_rc'"
                exit `_fmt_rc'
            }
            capture mata: mata drop `_xlsx_book'

            capture confirm file "`xlsx'"
            if _rc {
                display as error "Excel export completed but file was not created"
                exit 601
            }
            local _xlsx_ok 1
            display as text "Exported " as result "`lastrow'" as text " rows × " as result "`ncols'" as text " cols to " as result `"`xlsx'"' as text ", sheet " as result `"`macval(sheet)'"'
        }

        if `_xlsx_ok' {
            return local xlsx "`xlsx'"
            return local sheet `"`macval(sheet)'"'
        }
        if `_xlsx_ok' & "`open'" != "" _tabtools_open_file "`xlsx'"

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

        if `_forest_rc_hold' != 0 exit `_forest_rc_hold'

        * Final frame commit: validate both staged schemas, then replace caller
        * destinations only after every preceding operation has succeeded.
        if `"`_display_build_name'"' != "" {
            if `_displayframe_flat' frame `_display_build_name': confirm variable rowlabel
            else frame `_display_build_name': confirm variable title
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
        restore
        local _restore_needed 0
    } // end capture noisily
    local _rc = _rc
    if `_rc' {
        if `"`_display_build_name'"' != "" capture frame drop `_display_build_name'
        if `"`_eplot_build_name'"' != "" capture frame drop `_eplot_build_name'
    }
    if `_restore_needed' capture restore
    set varabbrev `_orig_varabbrev'
    if `_rc' exit `_rc'

    return clear
    if `"`_displayframe_name'"' != "" return local frame "`_displayframe_name'"
    return scalar N_rows = `lastrow'
    return scalar N_outcomes = `outcomes'
    return scalar N_sections = `n_sections'
    return scalar N_modelrows = `_selected_total'
    return scalar N_modelframes = `n_frames'
    return scalar N_models_per_outcome = `_K'
    return scalar N_modelonly = `_n_mo'
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
        return local sheet `"`macval(sheet)'"'
    }
end

capture program drop _comptab_vertical
program define _comptab_vertical, rclass
    version 17.0
    local _orig_varabbrev = c(varabbrev)
    set varabbrev off
    tempname _xlsx_book

    capture noisily {

    capture putexcel close

    * Auto-load shared helper programs if not already in memory
    capture _tabtools_helpers_ready
    if !_rc capture mata: assert(findexternal("_tt_sep_parse()") != NULL)
    * (a session can hold an older _tabtools_common.ado's programs: run,
    * so discard keeps them; this release's Mata must be there too)
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
    _tabtools_companion_id

    syntax anything(name=framelist), [rows(string) ROWNames(string)] ///
        [xlsx(string) excel(string) sheet(string)] ///
        [title(string) FOOTnote(string) COMPact ///
        SEParator(numlist >0 integer sort) SECtion(string asis) ///
        RELAbel(string asis) ///
        FONT(string) FONTSIZE(integer -1) BORDERstyle(string) open zebra HEADERShade ///
        HIGHlight(real -1) BOLDp(real -1) ///
        HEADERColor(string) ZEBRAColor(string) ///
        csv(string) MARKdown(string) MDAPPend FRAme(string) EPLOTFrame(string asis) ///
        FOREST EPLOTOptions(string asis) LABELWidth(integer 0) ///
        CFormat(string) CISep(string)]

    * cformat()/cisep() (O1): re-render each selected estimate and interval.
    * cformat() needs the numbers, so it reads the numeric companions;
    * cisep() alone rewrites the "(a, b)" text exactly or refuses.
    local _refmt = (`"`cformat'"' != "")
    if `_refmt' {
        capture confirm numeric format `cformat'
        if _rc | regexm(`"`cformat'"', "^%-?t") {
            noisily display as error `"cformat(): "`cformat'" is not a numeric display format"'
            exit 198
        }
    }
    mata: st_local("_resep", strofreal(st_local("cisep") != ""))
    * a decimal-comma cformat() whose rebuilt intervals hold a comma (cisep(),
    * or its default ", "): printed as before, with a warning (regtab and
    * effecttab refuse it)
    if `_refmt' {
        mata: st_local("_sep_comma", strofreal(st_local("cisep") == "" | strpos(st_local("cisep"), ",") > 0))
        if `_sep_comma' & ustrregexm(`"`cformat'"', "^%-?0?[0-9]*,") {
            noisily display as text "(comptab: cformat(`cformat') writes a decimal comma and the interval separator holds a comma: the two limits are hard to tell apart (help tabtools##sep))"
        }
    }

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
    * Session destinations (tabtools set workbook/markdown) apply only when
    * sheet() asks for a sheet; an explicit option wins. Without this a
    * sheet() call after tabtools set workbook wrote nothing, silently.
    if `"`macval(sheet)'"' != "" {
        _tabtools_set_sinks resolve, xlsx(`"`xlsx'"') markdown(`"`markdown'"') `mdappend'
        local xlsx `"`_ss_xlsx'"'
        local markdown `"`_ss_md'"'
        local mdappend "`_ss_mdappend'"
        if `"`xlsx'"' == "" display as text "(tabtools: sheet() ignored; no xlsx() and no session workbook)"
    }
    local _has_xlsx = "`xlsx'" != ""
    if `"`macval(sheet)'"' == "" local sheet "Composite"
    if "`open'" != "" & !`_has_xlsx' {
        noisily display as error "open requires xlsx() or excel()"
        exit 198
    }

    * Resolve persistent defaults
    if `boldp' == -1 & "$TABTOOLS_BOLDP" != "" local boldp = $TABTOOLS_BOLDP

    * Validate sheet name for Excel constraints
    _tabtools_validate_sheet `"`macval(sheet)'"' "sheet()"

    * =====================================================================
    * RESOLVE FORMATTING OPTIONS
    * =====================================================================
    _tabtools_resolve_format, font(`"`font'"') fontsize(`fontsize') borderstyle(`borderstyle') headershade(`headershade') zebra(`zebra')
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
        local _ep_spec = subinstr(strtrim(`"`eplotframe'"'), char(34), "", .)
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
        local _eplotframe_name `"`_forest_eplotframe'"'
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
        frame `_fname': local _src_layout : char _dta[tabtools_layout]
        if "`_src_layout'" == "flat" {
            noisily display as error "Frame '`_fname'' is a flat frame (frame(, flat)); it is for puttab, not a comptab source"
            exit 198
        }
    }

    * Resolve the display-frame destination without changing it, then reject
    * every destructive source/current/output alias before any frame is
    * dropped or rebuilt.
	    local _displayframe_name ""
	    local _displayframe_replace 0
	    local _displayframe_flat 0
	    if `"`frame'"' != "" {
	        _comptab_frame_spec `"`frame'"' "frame()"
	        local _displayframe_name "`r(name)'"
	        local _displayframe_replace = r(replace)
	        local _displayframe_flat = r(flat)
    }
    if `"`_displayframe_name'"' != "" & ///
        `"`_eplotframe_name'"' != "" & ///
        `"`_displayframe_name'"' == `"`_eplotframe_name'"' {
        noisily display as error "frame() and eplotframe() must name different frames"
        exit 198
    }
    foreach _dest in _displayframe_name _eplotframe_name {
        if `"``_dest''"' != "" & ///
            `"``_dest''"' == `"`c(frame)'"' {
            noisily display as error "output frames cannot replace the current frame"
            exit 198
        }
    }
    forvalues f = 1/`n_frames' {
        local _fname : word `f' of `framelist'
        foreach _dest in _displayframe_name _eplotframe_name {
            if `"``_dest''"' != "" & ///
                `"``_dest''"' == `"`_fname'"' {
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
	                    `"``_dest''"' == `"`_source_ep_original_`f''"' {
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
	        if `_refmt' & `"`_source_ep_original_`f''"' == "" {
	            noisily display as error "cformat() requires every source to have a numeric companion frame"
	            noisily display as error "Hint: create each source with regtab or effecttab, frame() eplotframe()"
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

	    local _displayframe_target `"`_displayframe_name'"'
	    local _eplotframe_target ""
	    local _displayframe_build ""
	    local _eplotframe_build ""
	    if `"`_displayframe_target'"' != "" {
	        tempname _displayframe_tmp
	        local _displayframe_build `"`_displayframe_tmp'"'
	        local frame "`_displayframe_build', replace"
	    }
	    if `"`_eplotframe_name'"' != "" {
	        if `_eplotframe_temporary' {
	            local _eplotframe_build `"`_eplotframe_name'"'
	        }
	        else {
	            local _eplotframe_target `"`_eplotframe_name'"'
	            tempname _eplotframe_tmp
	            local _eplotframe_build `"`_eplotframe_tmp'"'
	            local _eplotframe_name `"`_eplotframe_build'"'
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
                        * C1: the row label is matched in Mata, never expanded.
                        mata: st_local("_pat_hit", strofreal(strmatch(strlower(st_sdata(`_frame_row', "A")), "*" + strlower(st_local("_pat")) + "*")))
                        if `_pat_hit' {
                            local expanded`f' `"`expanded`f'' `_row'"'
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
    forvalues _m = 1/`n_models' {
        local _source_model_map_1_`_m' = `_m'
    }
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
	        * F06 (codex audit 2026-09-27): y and Y are different outcomes;
	        * the machine identities are compared exactly as persisted.
	        local _model_id_ref_`_m' = strtrim(`"`_model_id_ref_`_m''"')
	        local _outcome_id_ref_`_m' = strtrim(`"`_outcome_id_ref_`_m''"')
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
	            local _model_id_src_`_m' = strtrim(`"`_model_id_src_`_m''"')
	            local _outcome_id_src_`_m' = strtrim(`"`_outcome_id_src_`_m''"')
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
            local _source_model_map_`f'_`_target_m' = `_source_m'
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
            * C1 (codex audit 2026-09-26): not clonevar, which re-expands
            * the column's variable label as macro syntax.
            frame `_fname' {
                local _cv_type : type c`_c'
                quietly generate `_cv_type' `_source_copy_`f'_`_c'' = c`_c'
                mata: st_varlabel("`_source_copy_`f'_`_c''", st_varlabel("c`_c'"))
            }
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
    if `"`macval(section)'"' != "" {
        local has_sections = 1
        local section : subinstr local section " \ " "\", all
        local section : subinstr local section "\  " "\", all
        local section : subinstr local section "  \" "\", all
        tokenize `"`macval(section)'"', parse("\")

        local sidx = 1
        local sfidx = 0
        local _sectoken : copy local `sidx'
        while `"`macval(_sectoken)'"' != "" {
            if `"`macval(_sectoken)'"' != "\" {
                local sfidx = `sfidx' + 1
                local seclabel`sfidx' : copy local _sectoken
            }
            local sidx = `sidx' + 1
            local _sectoken : copy local `sidx'
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
    if "`csv'" != "" _tabtools_validate_path "`csv'" "csv()"
    _tabtools_check_sinks, xlsx(`"`xlsx'"') csv(`"`csv'"') markdown(`"`markdown'"')

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
            long source_row str32 source_frame long table_row
        local _composite_row = 0
	        forvalues f = 1/`n_frames' {
	            local _fname : word `f' of `framelist'
	            local _source_label `"`_source_original_`f''"'
	            local _sec_label ""
            if `has_sections' local _sec_label : copy local seclabel`f'

            * Resolve the source companion frame for this display frame.
            local _src_ep ""
            capture frame `_fname': local _src_ep : char _dta[tabtools_eplotframe]
            local _src_ep_ok = (_rc == 0 & `"`_src_ep'"' != "")
            if `_src_ep_ok' {
                capture frame `_src_ep': quietly count
                if _rc local _src_ep_ok = 0
            }

            * The plotted rows follow the table: each selected row once, in
            * frame order, whatever order or repetition rows() was typed in.
            local _ep_rows`f' : list uniq expanded`f'
            if `"`_ep_rows`f''"' != "" {
                numlist `"`_ep_rows`f''"', sort
                local _ep_rows`f' `"`r(numlist)'"'
            }

            * Each analytical display cell must have one numeric row for its
            * original model. Headings and model-fit/custom rows have no CI or
            * p-value and legitimately have no companion; special nonnumeric
            * rows (reference/omitted/empty) may likewise be absent. Never infer
            * a missing estimate, or multiply it, from companion row count.
            local _source_row_key source_row
            frame `_fname': local _source_kind : char _dta[tabtools_source]
            if "`_source_kind'" == "comptab" local _source_row_key table_row
            frame `_src_ep' {
                foreach _v in source_row `_source_row_key' model estimate ll ul pvalue {
                    capture confirm numeric variable `_v'
                    if _rc {
                        noisily display as error "source companion lacks numeric variable `_v'"
                        noisily display as error "Recreate the source display and eplotframe together with regtab, effecttab, or comptab"
                        exit 459
                    }
                }
                foreach _v in label model_label rowtype {
                    capture confirm string variable `_v'
                    if _rc {
                        noisily display as error "source companion lacks string variable `_v'"
                        exit 459
                    }
                }
            }
            * Only a pair created by the same producer invocation can supply
            * numeric results. Command/model metadata also matches later fits
            * on different data, so it cannot authenticate the numeric payload.
            frame `_fname': local _display_pair : char _dta[tabtools_companion_id]
            frame `_src_ep': local _numeric_pair : char _dta[tabtools_companion_id]
            mata: st_local("_same_pair", strofreal( ///
                st_local("_display_pair") != "" & ///
                st_local("_display_pair") == st_local("_numeric_pair")))
            if !`_same_pair' {
                noisily display as error "source display and numeric companion have missing or different tabtools_companion_id"
                noisily display as error "Recreate the source display and eplotframe together with regtab, effecttab, or comptab"
                exit 459
            }
            * The frame pointer and row keys do not authenticate a companion:
            * another fit can have exactly the same rows/model numbers.
            frame `_src_ep': local _ep_meta_n : char _dta[tabtools_n_models]
            frame `_src_ep': local _ep_meta_ci : char _dta[tabtools_ci_level]
            mata: st_local("_same_provenance", strofreal( ///
                strtoreal(st_local("_ep_meta_n")) == `n_models' & ///
                !missing(strtoreal(st_local("_ep_meta_ci"))) & ///
                strtoreal(st_local("_ep_meta_ci")) == strtoreal(st_local("_ci_level_ref"))))
            if !`_same_provenance' {
                noisily display as error "source companion has incompatible model-count or confidence-level provenance"
                exit 459
            }
            forvalues _source_m = 1/`n_models' {
                foreach _meta in model_id outcome_id effect_scale {
                    frame `_fname': local _display_identity : char _dta[tabtools_`_meta'_`_source_m']
                    frame `_src_ep': local _companion_identity : char _dta[tabtools_`_meta'_`_source_m']
                    mata: st_local("_same_identity", strofreal(st_local("_display_identity") == st_local("_companion_identity")))
                    if !`_same_identity' {
                        noisily display as error "source companion disagrees with display model `_source_m' (`_meta')"
                        noisily display as error "Recreate the source display and eplotframe together with regtab or effecttab"
                        exit 459
                    }
                }
            }
            local _n_eff_f = 0
            foreach r of local _ep_rows`f' {
                frame `_src_ep': quietly count if `_source_row_key' == `r' & ///
                    (missing(model) | model != floor(model) | model < 1 | model > `n_models')
                if r(N) {
                    noisily display as error "source companion contains an invalid model identity for selected row `r'"
                    exit 459
                }
                forvalues _target_m = 1/`n_models' {
                    local _source_m = `_source_model_map_`f'_`_target_m''
                    frame `_src_ep': quietly count if `_source_row_key' == `r' & model == `_source_m'
                    local _found_ep = r(N)
                    local _est_c = (`_target_m' - 1) * `_source_cols_per_model' + 1
                    local _last_c = `_est_c' + `_source_cols_per_model' - 1
                    local _needs_ep = 0
                    frame `_fname' {
                        * In compact sources the estimate cell includes the CI;
                        * a missing p-value must not erase that analytical row.
                        if `_source_compact' & regexm(c`_est_c'[`r' + 3], "[(][^)]*[)]") local _needs_ep = 1
                        forvalues _stat_c = `=`_est_c' + 1'/`_last_c' {
                            if strtrim(c`_stat_c'[`r' + 3]) != "" local _needs_ep = 1
                        }
                    }
                    if `_found_ep' > 1 | (`_needs_ep' & `_found_ep' != 1) {
                        noisily display as error "source companion does not uniquely identify selected row `r', model `_source_m'"
                        noisily display as error "Recreate the source display and eplotframe together with regtab or effecttab"
                        exit 459
                    }
                    local _n_eff_f = `_n_eff_f' + `_found_ep'
                }
            }
            local _fold = (`has_sections' & `_n_eff_f' == 1)
            if `has_sections' & !`_fold' {
                frame post `_eplotframe_name' ("") (.) (.) (.) (.) ///
                    (.) ("") ("section") ("") (.) ("") (.)
                frame `_eplotframe_name' {
                    mata: st_sstore(st_nobs(), "label", st_local("_sec_label"))
                    mata: st_sstore(st_nobs(), "section", st_local("_sec_label"))
                    mata: st_sstore(st_nobs(), "source_frame", st_local("_source_label"))
                }
            }

            if `has_sections' local _composite_row = `_composite_row' + 1
            foreach r of local _ep_rows`f' {
                local _composite_row = `_composite_row' + 1
                forvalues _target_m = 1/`n_models' {
                    local _source_m = `_source_model_map_`f'_`_target_m''
                    frame `_src_ep' {
                        local _ep_N = _N
                        forvalues _ep_i = 1/`_ep_N' {
                            if `_source_row_key'[`_ep_i'] == `r' & model[`_ep_i'] == `_source_m' {
                                mata: st_local("_ep_label", st_sdata(`_ep_i', "label"))
                                local _ep_est = estimate[`_ep_i']
                                local _ep_ll = ll[`_ep_i']
                                local _ep_ul = ul[`_ep_i']
                                local _ep_p = pvalue[`_ep_i']
                                mata: st_local("_ep_model_label", st_sdata(`_ep_i', "model_label"))
                                mata: st_local("_ep_rowtype", st_sdata(`_ep_i', "rowtype"))
                                local _post_label : copy local _ep_label
                                if `_fold' local _post_label : copy local _sec_label
                                frame post `_eplotframe_name' ("") (`_ep_est') (`_ep_ll') (`_ep_ul') ///
                                    (`_ep_p') (`_target_m') ("") ("") ///
                                    ("") (`r') ("") (`_composite_row')
                                frame `_eplotframe_name' {
                                    mata: st_sstore(st_nobs(), "label", st_local("_post_label"))
                                    mata: st_sstore(st_nobs(), "model_label", st_local("_ep_model_label"))
                                    mata: st_sstore(st_nobs(), "rowtype", st_local("_ep_rowtype"))
                                    mata: st_sstore(st_nobs(), "section", st_local("_sec_label"))
                                    mata: st_sstore(st_nobs(), "source_frame", st_local("_source_label"))
                                }
                            }
                        }
                    }
                }
            }
        }
        frame `_eplotframe_name': mata: st_global("_dta[tabtools_companion_id]", st_local("_companion_id"))
        frame `_eplotframe_name': char _dta[tabtools_source] "comptab"
        frame `_eplotframe_name': char _dta[tabtools_ci_level] "`_ci_level_ref'"
        frame `_eplotframe_name': char _dta[tabtools_n_models] "`n_models'"
        frame `_eplotframe_name': char _dta[tabtools_statistic_ids] "`_stat_ids_ref'"
        forvalues _meta_m = 1/`n_models' {
            frame `_eplotframe_name': char _dta[tabtools_model_id_`_meta_m'] `"`_model_id_ref_`_meta_m''"'
            frame `_eplotframe_name': char _dta[tabtools_outcome_id_`_meta_m'] `"`_outcome_id_ref_`_meta_m''"'
            frame `_eplotframe_name': char _dta[tabtools_effect_scale_`_meta_m'] `"`_effect_scale_ref_`_meta_m''"'
        }
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
            local _section_rows `"`_section_rows' `_cum_data_row'"'

            use `_build', clear
            local _nobs = _N + 1
            qui set obs `_nobs'
            qui replace A = `"`macval(seclabel`f')'"' in `_nobs'
            forvalues _ci = 1/`ncols' {
                capture confirm variable c`_ci'
                if !_rc qui replace c`_ci' = "" in `_nobs'
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
        gen int __srcf = `f'
        gen long __srcr = _orig_n - 3
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
    * CFORMAT()/CISEP() — RE-RENDER SELECTED ESTIMATES (O1)
    * =====================================================================
    capture confirm variable __srcf
    if _rc {
        gen int __srcf = .
        gen long __srcr = .
    }
    if `_refmt' | `_resep' {
        * cisep() is data (help tabtools##sep): the default is applied, the
        * cells are read and the intervals joined in Mata, and the results
        * are written through macval(), never re-expanded
        mata: st_local("cisep", st_local("cisep") == "" ? ", " : st_local("cisep"))
        forvalues _i = 1/`=_N' {
            if missing(__srcf[`_i']) continue
            local f = __srcf[`_i']
            local r = __srcr[`_i']
            local _fname : word `f' of `framelist'
            local _ep_key source_row
            if `_refmt' {
                frame `_fname': local _src_ep : char _dta[tabtools_eplotframe]
                frame `_fname': local _display_pair : char _dta[tabtools_companion_id]
                frame `_src_ep': local _numeric_pair : char _dta[tabtools_companion_id]
                mata: st_local("_same_pair", strofreal(st_local("_display_pair") != "" & ///
                    st_local("_display_pair") == st_local("_numeric_pair")))
                if !`_same_pair' {
                    noisily display as error "source display and numeric companion have missing or different tabtools_companion_id"
                    exit 459
                }
                frame `_fname': local _source_kind : char _dta[tabtools_source]
                if "`_source_kind'" == "comptab" local _ep_key table_row
            }
            forvalues _target_m = 1/`n_models' {
                local _source_m = `_source_model_map_`f'_`_target_m''
                local _est_c = (`_target_m' - 1) * `_source_cols_per_model' + 1
                local _ci_c = `_est_c' + 1
                mata: st_local("_cell_est", strtrim(st_sdata(`_i', "c`_est_c'")))
                local _cell_ci ""
                if !`_source_compact' mata: st_local("_cell_ci", strtrim(st_sdata(`_i', "c`_ci_c'")))
                * stars appended by regtab stay on the estimate
                local _stars ""
                mata: st_local("_stars", regexm(st_local("_cell_est"), "^[^(]*[^*(](\*+)") ? regexs(1) : "")
                if `_refmt' {
                    _comptab_ep_value, ep(`_src_ep') key(`_ep_key') row(`r') model(`_source_m')
                    if !r(found) | missing(r(est)) | missing(r(ll)) | missing(r(ul)) continue
                    local _t_est = strtrim(string(r(est), "`cformat'"))
                    local _t_lo = strtrim(string(r(ll), "`cformat'"))
                    local _t_hi = strtrim(string(r(ul), "`cformat'"))
                }
                else {
                    * cisep() alone: rewrite "(a, b)" exactly or refuse
                    if `_source_compact' local _txt : copy local _cell_est
                    else local _txt : copy local _cell_ci
                    mata: st_local("_has_ci", strofreal(st_local("_txt") != "" & strpos(st_local("_txt"), "(") > 0))
                    if !`_has_ci' continue
                    if `_source_compact' {
                        mata: st_local("_ci_ok", strofreal(regexm(st_local("_txt"), "^(.+) \(([^ ,]+(,[0-9][0-9][0-9])*), ([^ ]+)\)$")))
                        if !`_ci_ok' {
                            noisily display as error `"cisep(): the interval in "`macval(_txt)'" is not in (a, b) form"'
                            exit 198
                        }
                        mata: st_local("_t_est", regexs(1)); st_local("_t_lo", regexs(2)); st_local("_t_hi", regexs(4))
                        local _stars ""
                    }
                    else {
                        mata: st_local("_ci_ok", strofreal(regexm(st_local("_txt"), "^\(([^ ,]+(,[0-9][0-9][0-9])*), ([^ ]+)\)$")))
                        if !`_ci_ok' {
                            noisily display as error `"cisep(): the interval "`macval(_txt)'" is not in (a, b) form"'
                            exit 198
                        }
                        mata: st_local("_t_lo", regexs(1)); st_local("_t_hi", regexs(3))
                        local _t_est : copy local _cell_est
                        local _stars ""
                    }
                }
                mata: st_local("_t_ci", "(" + st_local("_t_lo") + st_local("cisep") + st_local("_t_hi") + ")")
                if `_source_compact' {
                    qui replace c`_est_c' = `"`macval(_t_est)'`macval(_stars)' `macval(_t_ci)'"' in `_i'
                }
                else {
                    qui replace c`_est_c' = `"`macval(_t_est)'`macval(_stars)'"' in `_i'
                    qui replace c`_ci_c' = `"`macval(_t_ci)'"' in `_i'
                }
            }
        }
    }
    drop __srcf __srcr

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
            qui replace c`m' = `"`_hdr_est' `_hdr_ci'"' in 2
        }

        * Drop CI columns (c2, c5, c8, ...)
        local _drop_cols ""
        forvalues m = 2(3)`ncols' {
            local _drop_cols `"`_drop_cols' c`m'"'
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
    qui replace title = `"`macval(title)'"' in 1

    * =====================================================================
    * DETECT REFERENCE ROWS (after title insertion — row numbers = Excel rows)
    * =====================================================================
    * Per model: models of one source frame can have different base levels
    * (i.rep78 beside ib3.rep78), so a union across models would merge and
    * hide the estimate, interval and p-value of a model whose row is a real
    * estimate. ref_rows_<i> holds the rows of the model starting at c<i>.
    forvalues i = 1(`n_cols_per_model')`n' {
        gen _ref`i' = _n if c`i' == "Reference" & _n >= 4
        quietly levelsof _ref`i', local(ref_rows_`i')
        drop _ref`i'
    }

    * =====================================================================
    * COLUMN WIDTH CALCULATION
    * =====================================================================
    * Widths come from the shared _tabtools_colwidth helper, PER MODEL, from
    * that model's own rendered cells (rows 3+). A single max shared across
    * models sized every model's estimate/CI/p column to the widest model. The
    * model label in row 2 is merged across its own block, so its wrap depth
    * comes from that block's width, not from the whole table.
    local _est_min = cond(`_compact_output', 16, 8)
    local _est_max = cond(`_compact_output', 34, 22)
    local _headerht = 0
    forvalues _mw = 1/`n_models' {
        local _c_est = (`_mw' - 1) * `n_cols_per_model' + 1
        _tabtools_colwidth c`_c_est', minwidth(`_est_min') maxwidth(`_est_max') headerrow(2)
        local _est_width_`_mw' = r(width)
        local _m_hdr_len = r(hlen)
        local _ci_width_`_mw' = 0
        if !`_compact_output' {
            _tabtools_colwidth c`=`_c_est' + 1', minwidth(16) maxwidth(34)
            local _ci_width_`_mw' = r(width)
        }
        _tabtools_colwidth c`=`_c_est' + `n_cols_per_model' - 1', minwidth(8) maxwidth(12)
        local _p_width_`_mw' = r(width)
        local _m_block_width = `_est_width_`_mw'' + `_ci_width_`_mw'' + `_p_width_`_mw''
        _tabtools_colwidth, hlength(`_m_hdr_len') blockwidth(`_m_block_width')
        if r(hlines) > 1 & r(hlines) > `_headerht' local _headerht = r(hlines)
    }

    gen A_length = length(A)
    egen factor_length = max(A_length)
    qui sum factor_length, d
    local factor_length = ceil(r(max) * 0.95) + 2
    if `factor_length' > `_label_width_cap' local factor_length = `_label_width_cap'

    drop A_length factor_length

    * =====================================================================
    * CSV EXPORT
    * =====================================================================
    if "`csv'" != "" {
        _tabtools_csv_write using "`csv'", labelvar(A) reservedrow ///
            title(`"`macval(title)'"') footnote(`"`macval(footnote)'"')
    }

    * =====================================================================
    * CONSOLE DISPLAY
    * =====================================================================
    noisily _tabtools_console_display `n' `"`macval(title)'"', labelvar(A) datastart(4)

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
            `_mdappend_opt' labelvar(A) datastart(3) title(`"`macval(title)'"') footnote(`"`macval(footnote)'"') strictheaders
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
        local frame `"`_frame_name'"'
	        if `"`_eplotframe_name'"' != "" & !`_eplotframe_temporary' {
	            frame `frame': char _dta[tabtools_eplotframe] "`_eplotframe_target'"
        }
        frame `frame': mata: st_global("_dta[tabtools_companion_id]", st_local("_companion_id"))
        frame `frame': char _dta[tabtools_source] "comptab"
        frame `frame': char _dta[tabtools_ci_level] "`_ci_level_ref'"
        frame `frame': char _dta[tabtools_n_models] "`n_models'"
        frame `frame': char _dta[tabtools_statistic_ids] "`_stat_ids_ref'"
        forvalues _meta_m = 1/`n_models' {
            frame `frame': char _dta[tabtools_model_id_`_meta_m'] `"`_model_id_ref_`_meta_m''"'
            frame `frame': char _dta[tabtools_outcome_id_`_meta_m'] `"`_outcome_id_ref_`_meta_m''"'
            frame `frame': char _dta[tabtools_effect_scale_`_meta_m'] `"`_effect_scale_ref_`_meta_m''"'
        }
        if `_displayframe_flat' {
            local _flat_cols ""
            local _flat_starts ""
            forvalues _fc = 1/`n' {
                local _flat_cols "`_flat_cols' c`_fc'"
                if mod(`_fc' - 1, `n_cols_per_model') == 0 local _flat_starts "`_flat_starts' `_fc'"
            }
            frame `frame': _comptab_flatten, labelvar(A) cols(`_flat_cols') blockstarts(`_flat_starts')
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
        capture noisily _tabtools_xlsx_write using "`xlsx'", sheet(`"`macval(sheet)'"') book(`_xlsx_book')
        if _rc {
            local _export_rc = _rc
            noisily display as error `"Failed to export to `xlsx', sheet `macval(sheet)'"'
            noisily display as error "Check file permissions and that file is not open in Excel"
            restore
            exit `_export_rc'
        }
        * Excel sheet names are case-insensitive; keep the workbook's own
        * spelling when an existing sheet was replaced, as rate mode does.
        mata: st_local("sheet", st_global("r(sheet)"))
    }

    * =====================================================================
    * EXCEL FORMATTING — MATA (COLUMN WIDTHS)
    * =====================================================================
    if `_has_xlsx' {

    * Per-model widths in Excel column order (column 1 spacer, 2 label, then
    * est[/CI]/p per model). _headerht was set alongside the widths above.
    local _xlsx_widths "1 `factor_length'"
    forvalues _mw = 1/`n_models' {
        local _xlsx_widths `"`_xlsx_widths' `_est_width_`_mw''"'
        if !`_compact_output' local _xlsx_widths `"`_xlsx_widths' `_ci_width_`_mw''"'
        local _xlsx_widths `"`_xlsx_widths' `_p_width_`_mw''"'
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

        forvalues i = 1(`n_cols_per_model')`n' {
            * c<i> is Excel column i + 2 (title and label columns first)
            local col_num = `i' + 2
            local _col_end = `col_num' + `n_cols_per_model' - 1
            foreach row of local ref_rows_`i' {
                local _style_rule_spec `"`_style_rule_spec' | 14 `row' `row' `col_num' `_col_end' 0 0 0 0 | 5 `row' `row' `col_num' `col_num' 0 2 0 0 | 6 `row' `row' `col_num' `col_num' 0 2 0 0 | 3 `row' `row' `col_num' `col_num' 0 1 0 0"'
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
        if `"`macval(footnote)'"' != "" {
            local _fn_fontsize = max(`_fontsize' - 2, 6)
            * One row per paragraph; " \ " separates paragraphs.
            local _fn_rest `"`macval(footnote)'"'
            local _fp 0
            while `"`macval(_fn_rest)'"' != "" {
                local _fn_at = strpos(`"`macval(_fn_rest)'"', " \ ")
                if `_fn_at' == 0 {
                    local _fn_piece `"`macval(_fn_rest)'"'
                    local _fn_rest ""
                }
                else {
                    local _fn_piece = substr(`"`macval(_fn_rest)'"', 1, `_fn_at' - 1)
                    local _fn_rest = substr(`"`macval(_fn_rest)'"', `_fn_at' + 3, .)
                }
                local ++_fp
                local _fn_row = `num_rows' + `_fp'
                mata: `_xlsx_book'.put_string(`_fn_row', 2, strtrim(st_local("_fn_piece")))
                local _style_rule_spec `"`_style_rule_spec' | 14 `_fn_row' `_fn_row' 2 `num_cols' 0 0 0 0 | 5 `_fn_row' `_fn_row' 2 2 0 1 0 0 | 6 `_fn_row' `_fn_row' 2 2 0 2 0 0 | 4 `_fn_row' `_fn_row' 2 2 0 1 0 0 | 1 `_fn_row' `_fn_row' 2 2 `_fn_fontsize' 1 0 0 | 3 `_fn_row' `_fn_row' 2 2 0 1 0 0"'
            }
        }

        _tabtools_xlsx_build_styles, matrix(`_style_rules') ///
            rules(`_style_rule_spec') cols(9)
        _tabtools_xlsx_apply_styles, defer book(`_xlsx_book') sheet(`"`macval(sheet)'"') ///
            rules(`_style_rules') font("`_font'") ///
            color1("`_headercolor'") color2("`_zebracolor'") ///
            color3("255 255 204")
        mata: `_xlsx_book'.close_book()

        * xl() appends a style record for every styled cell instead of
        * reusing one per distinct format, so collapse the pools here;
        * a workbook that keeps growing would otherwise reach Stata's
        * 65,536-record ceiling and fail with r(16147).
        _tabtools_xlsx_compact_styles using "`xlsx'"
    }
    if _rc {
        local saved_rc = _rc
        capture mata: `_xlsx_book'.close_book()
        capture mata: mata drop `_xlsx_book'
        noisily display as error "Excel formatting failed with error `saved_rc'"
        restore
        exit `saved_rc'
    }
    capture mata: mata drop `_xlsx_book'

    } // end if _has_xlsx (Excel formatting)

    clear
    restore

    * Console confirmation
    if `_has_xlsx' {
        capture confirm file "`xlsx'"
        if _rc == 0 {
            local _xlsx_ok 1
            noisily display as text "Exported " as result "`num_rows'" as text " rows × " as result "`num_cols'" as text " cols to " as result `"`xlsx'"' as text ", sheet " as result `"`macval(sheet)'"'
        }
        else {
            noisily display as error "Export command succeeded but file not found"
            exit 601
        }
    }

    if `_xlsx_ok' {
        return local xlsx "`xlsx'"
        return local sheet `"`macval(sheet)'"'
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
        return local sheet `"`macval(sheet)'"'
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

* =============================================================================
* _comptab_frame_spec: parse frame(name[, replace flat]) for both modes
* =============================================================================
capture program drop _comptab_frame_spec
program define _comptab_frame_spec, rclass
    version 17.0
    local _orig_varabbrev = c(varabbrev)
    set varabbrev off
    capture noisily {
        args spec label
        local spec = subinstr(strtrim(`"`spec'"'), char(34), "", .)
        gettoken name rest : spec, parse(",")
        local name = strtrim(`"`name'"')
        local rest : subinstr local rest "," "", all
        local rest = lower(strtrim(`"`rest'"'))
        capture confirm name `name'
        if _rc {
            display as error "`label' must start with a valid Stata frame name"
            exit 198
        }
        local replace 0
        local flat 0
        foreach w of local rest {
            if "`w'" == "replace" local replace 1
            else if "`w'" == "flat" local flat 1
            else {
                display as error "`label' only allows the replace and flat suboptions"
                exit 198
            }
        }
        return local name "`name'"
        return scalar replace = `replace'
        return scalar flat = `flat'
    }
    local rc = _rc
    set varabbrev `_orig_varabbrev'
    if `rc' exit `rc'
end

* =============================================================================
* _comptab_ep_value: one numeric companion row for (source row, model)
* =============================================================================
* The values travel as r() scalars (full double precision), never as macros.
capture program drop _comptab_ep_value
program define _comptab_ep_value, rclass
    version 17.0
    local _orig_varabbrev = c(varabbrev)
    set varabbrev off
    capture noisily {
        syntax , EP(name) KEY(name) ROW(integer) MODEL(integer)
        tempvar hit
        frame `ep' {
            quietly gen byte `hit' = (`key' == `row' & model == `model')
            quietly count if `hit'
            local found = r(N)
            if `found' > 1 {
                display as error "numeric companion has `found' rows for row `row', model `model'"
                exit 459
            }
            if `found' == 1 {
                quietly summarize estimate if `hit', meanonly
                return scalar est = r(min)
                quietly summarize ll if `hit', meanonly
                return scalar ll = r(min)
                quietly summarize ul if `hit', meanonly
                return scalar ul = r(min)
            }
            else {
                return scalar est = .
                return scalar ll = .
                return scalar ul = .
            }
            drop `hit'
        }
        return scalar found = `found'
    }
    local rc = _rc
    set varabbrev `_orig_varabbrev'
    if `rc' exit `rc'
end

* =============================================================================
* _comptab_flatten: turn a staged display frame into frame(name, flat)
* =============================================================================
* In the current frame: drops the title variable and the title/header rows
* (rows 1 to 3), renames the label column to rowlabel, renumbers the printed
* columns c1..cK in display order, and labels each with its printed header:
* "<block header>, <column header>" when the block has a row-2 header.
*   cols()        printed columns in display order (label column excluded)
*   blockstarts() 1-based positions in cols() where a header block starts
capture program drop _comptab_flatten
program define _comptab_flatten, nclass
    version 17.0
    local _orig_varabbrev = c(varabbrev)
    set varabbrev off
    capture noisily {
        syntax , LABELvar(name) COLS(string) BLOCKSTARTS(numlist integer >0)
        local k : word count `cols'
        local blk ""
        forvalues j = 1/`k' {
            local v : word `j' of `cols'
            if `: list j in blockstarts' {
                mata: st_local("blk", strtrim(st_sdata(2, "`v'")))
            }
            mata: st_local("hdr", strtrim(st_sdata(3, "`v'")))
            if `"`macval(blk)'"' != "" & `"`macval(hdr)'"' != "" local lab `"`macval(blk)', `macval(hdr)'"'
            else if `"`macval(blk)'"' != "" local lab `"`macval(blk)'"'
            else local lab `"`macval(hdr)'"'
            local lab_`j' `"`macval(lab)'"'
        }
        capture drop title
        quietly drop in 1/3
        rename `labelvar' __flat_rowlabel
        forvalues j = 1/`k' {
            local v : word `j' of `cols'
            rename `v' __flat_c`j'
        }
        rename __flat_rowlabel rowlabel
        mata: st_varlabel("rowlabel", "")
        * As regtab's _tabtools_flatframe: the full header is kept in
        * char c#[tabtools_header]; a variable label holds 80 characters.
        local _long ""
        forvalues j = 1/`k' {
            rename __flat_c`j' c`j'
            mata: st_global("c`j'[tabtools_header]", st_local("lab_`j'"))
            mata: st_varlabel("c`j'", substr(st_local("lab_`j'"), 1, 80))
            if strlen(`"`macval(lab_`j')'"') > 80 local _long "`_long' c`j'"
        }
        if "`_long'" != "" {
            noisily display as text "(frame flat: header of`_long' longer than 80 characters;" ///
                " the variable label is truncated and char c#[tabtools_header] holds it in full)"
        }
        keep rowlabel c*
        order rowlabel c*
        char _dta[tabtools_layout] "flat"
        char _dta[tabtools_eplotframe]
    }
    local rc = _rc
    set varabbrev `_orig_varabbrev'
    if `rc' exit `rc'
end

* =============================================================================
* _comptab_effect_cell: one model's effect (and p) text for one model row
* =============================================================================
* With cformat() the estimate and interval are re-rendered from the source's
* numeric companion (full precision); with cisep() alone the "(a, b)" text is
* rewritten exactly or refused. Rows the companion does not hold (model-fit
* and custom rows) keep their text.
capture program drop _comptab_effect_cell
program define _comptab_effect_cell, rclass
    version 17.0
    local _orig_varabbrev = c(varabbrev)
    set varabbrev off
    capture noisily {
        syntax , FRame(name) ROW(integer) BLOCK(integer) MODE(string) CPM(integer) ///
            [CFORMAT(string) CISEP(string)]
        local es = 1 + (`block' - 1) * `cpm'
        local p ""
        * Cell text (a source sep() among it) and cisep() are data (help
        * tabtools##sep): read, joined and returned in Mata, never re-expanded
        frame `frame' {
            if "`mode'" == "standard" | "`mode'" == "standardnop" {
                mata: st_local("main", strtrim(st_sdata(`row', "c`es'")))
                mata: st_local("ci", strtrim(st_sdata(`row', "c`=`es' + 1'")))
                mata: st_local("text", st_local("main") == "" ? st_local("ci") : (st_local("ci") == "" ? st_local("main") : st_local("main") + " " + st_local("ci")))
                if "`mode'" == "standard" local p = strtrim(c`=`es' + 2'[`row'])
            }
            else {
                mata: st_local("text", strtrim(st_sdata(`row', "c`es'")))
                if "`mode'" == "compact" local p = strtrim(c`=`es' + 1'[`row'])
            }
        }
        mata: st_local("sep", st_local("cisep") == "" ? ", " : st_local("cisep"))
        mata: st_local("_resep", strofreal(st_local("cisep") != ""))
        if `"`cformat'"' != "" {
            frame `frame': local ep : char _dta[tabtools_eplotframe]
            frame `frame': local kind : char _dta[tabtools_source]
            local key source_row
            if "`kind'" == "comptab" local key table_row
            capture confirm frame `ep'
            if _rc | `"`ep'"' == "" {
                display as error "cformat() requires every model source to have a numeric companion frame"
                exit 459
            }
            frame `frame': local dpair : char _dta[tabtools_companion_id]
            frame `ep': local npair : char _dta[tabtools_companion_id]
            mata: st_local("same", strofreal(st_local("dpair") != "" & st_local("dpair") == st_local("npair")))
            if !`same' {
                display as error "model display and numeric companion have missing or different tabtools_companion_id"
                exit 459
            }
            _comptab_ep_value, ep(`ep') key(`key') row(`=`row' - 3') model(`block')
            if r(found) & !missing(r(est)) & !missing(r(ll)) & !missing(r(ul)) {
                local stars ""
                mata: st_local("stars", regexm(st_local("text"), "^[^(]*[^*(](\*+)") ? regexs(1) : "")
                local _t_est = strtrim(string(r(est), "`cformat'"))
                local _t_lo = strtrim(string(r(ll), "`cformat'"))
                local _t_hi = strtrim(string(r(ul), "`cformat'"))
                mata: st_local("text", st_local("_t_est") + st_local("stars") + " (" + st_local("_t_lo") + st_local("sep") + st_local("_t_hi") + ")")
            }
        }
        else if `_resep' {
            mata: st_local("_has_ci", strofreal(strpos(st_local("text"), "(") > 0))
            if `_has_ci' {
                mata: st_local("_ci_ok", strofreal(regexm(st_local("text"), "^(.+) \(([^ ,]+(,[0-9][0-9][0-9])*), ([^ ]+)\)$")))
                if !`_ci_ok' {
                    display as error `"cisep(): the interval in "`macval(text)'" is not in (a, b) form"'
                    exit 198
                }
                mata: st_local("text", regexs(1) + " (" + regexs(2) + st_local("sep") + regexs(4) + ")")
            }
        }
        return local text `"`macval(text)'"'
        return local p `"`p'"'
    }
    local rc = _rc
    set varabbrev `_orig_varabbrev'
    if `rc' exit `rc'
end
