*! desctab Version 1.9.3  2026/07/03
*! Format descriptive table collects with per-statistic formats and composite cells
*! Author: Timothy P Copeland, Karolinska Institutet
*! Program class: rclass

program define desctab, rclass
    version 17.0
    local _orig_varabbrev = c(varabbrev)
    set varabbrev off
    local _preserved 0

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

    syntax , [XLSX(string) EXCEL(string) SHEET(string) TITLE(string) ///
        FOOTnote(string) COMPOSE(string asis) NFORMATS(string asis) ///
        DIGITS(integer -1) PCTDIGITS(integer -1) NINTEGERFMT(string) ///
        PCTSCALE(string) PCTSIGN ROWTOTALS COLTOTALS NOTOTALS ///
        KEEP(string asis) DROP(string asis) ///
        STATORDER(string) STATLABELS(string asis) NOMISsing zebra ///
        HEADERShade HEADERColor(string) ZEBRAColor(string) ///
        BORDERstyle(string) THEme(string) open csv(string) MARKdown(string) MDAPPend ///
        FRAme(string) HIGHlight(real -1) HLStat(string)]

    if "`xlsx'" == "" & "`excel'" != "" local xlsx "`excel'"
    local title : subinstr local title `"""' "", all
    local footnote : subinstr local footnote `"""' "", all
    local nformats : subinstr local nformats `"""' "", all
    local statlabels : subinstr local statlabels `"""' "", all
    local _has_xlsx = "`xlsx'" != ""
    if "`sheet'" == "" local sheet "Descriptive"

    if `digits' == -1 {
        if "$TABTOOLS_DIGITS" != "" local digits = $TABTOOLS_DIGITS
        else local digits = 2
    }
    if `pctdigits' == -1 local pctdigits = 1
    if "`nintegerfmt'" == "" local nintegerfmt "%12.0fc"
    if "`pctscale'" == "" local pctscale "auto"
    local pctscale = lower("`pctscale'")
    if !inlist("`pctscale'", "auto", "0to1", "0to100") {
        display as error "pctscale() must be auto, 0to1, or 0to100"
        exit 198
    }
    if `digits' < 0 | `digits' > 6 {
        display as error "digits() must be between 0 and 6"
        exit 198
    }
    if `pctdigits' < 0 | `pctdigits' > 6 {
        display as error "pctdigits() must be between 0 and 6"
        exit 198
    }
    if "`keep'" != "" & "`drop'" != "" {
        display as error "keep() and drop() cannot be combined"
        exit 198
    }
    if "`open'" != "" & !`_has_xlsx' {
        display as error "open requires xlsx() or excel()"
        exit 198
    }
    if `_has_xlsx' {
        if !strmatch(lower("`xlsx'"), "*.xlsx") {
            display as error "xlsx()/excel() must specify a .xlsx file"
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

    local _requested_headershade "`headershade'"
    local _requested_zebra "`zebra'"
    _tabtools_resolve_format, theme(`theme') borderstyle(`borderstyle') ///
        headershade(`headershade') zebra(`zebra')
    local headershade "`_requested_headershade'"
    local zebra "`_requested_zebra'"

    _tabtools_resolve_colors, headercolor(`"`headercolor'"') zebracolor(`"`zebracolor'"')

    capture quietly collect query row
    if _rc {
        display as error "No active collect table found"
        display as error "Run a table command first, for example:"
        display as error "    collect clear"
        display as error "    collect: table group, statistic(count x) statistic(mean x)"
        exit 119
    }

    quietly collect layout
    local _rowspec "`s(rows)'"
    local _colspec "`s(columns)'"
    local _tabspec "`s(tables)'"
    local _ktables = real("`s(k_tables)'")
    if `_ktables' > 1 {
        display as error "desctab supports one table at a time"
        display as error "Loop over the third table dimension and call desctab once per sheet"
        exit 459
    }

    _desctab_parse_layout `"`_rowspec'"' `"`_colspec'"'
    local rowdim "`r(rowdim)'"
    local coldim "`r(coldim)'"
    if "`rowdim'" == "" {
        display as error "No active table-shaped collect found"
        display as error "Run collect: table ... before desctab"
        exit 119
    }

    quietly collect label list result
    local stats_available ""
    forvalues _i = 1/`=real("`s(k)'")' {
        local stats_available "`stats_available' `s(level`_i')'"
    }
    local stats_available = strtrim("`stats_available'")
    if "`stats_available'" == "" {
        collect levelsof result
        local stats_available "`s(levels)'"
        local stats_available : subinstr local stats_available "N" "", word all
        local stats_available = strtrim("`stats_available'")
    }
    if "`stats_available'" == "" {
        display as error "No table statistics found in the active collect"
        display as error "Run collect: table ... statistic(...) before desctab"
        exit 459
    }

    local compose_mode = lower(strtrim(`"`compose'"'))

    if `"`compose_mode'"' != "" {
        _desctab_resolve_compose, compose("`compose'") stats("`stats_available'")
        local compose_resolved `"`r(compose)'"'
        local required_stats "`r(required)'"
        local is_custom = `r(custom)'
    }
    else {
        local compose_resolved ""
        local required_stats ""
        local is_custom 0
    }

    local _pct_compose = inlist("`compose_resolved'", "events_n_pct", "n_pct")
    if "`pctscale'" == "auto" {
        if `_pct_compose' local pctscale "0to100"
        else local pctscale "0to1"
    }
    if `_pct_compose' & "`pctsign'" == "" local pctsign "pctsign"

    if `"`compose_mode'"' != "" {
        foreach _need of local required_stats {
            _desctab_has_stat "`_need'" "`stats_available'"
            if !`r(found)' {
                display as error "compose(`compose') requires statistic(`_need' ...)"
                display as error "Available result statistics: `stats_available'"
                exit 459
            }
        }
        local stats_layout "`required_stats'"
    }
    else if "`statorder'" != "" {
        local stats_layout ""
        foreach _stat of local statorder {
            _desctab_has_stat "`_stat'" "`stats_available'"
            if `r(found)' local stats_layout "`stats_layout' `_stat'"
            else display as text "statorder: statistic '`_stat'' not in collect, ignoring"
        }
        foreach _stat of local stats_available {
            _desctab_has_stat "`_stat'" "`stats_layout'"
            if !`r(found)' local stats_layout "`stats_layout' `_stat'"
        }
        local stats_layout = strtrim("`stats_layout'")
    }
    else {
        local stats_layout "`stats_available'"
    }

    if "`stats_layout'" == "" {
        display as error "No statistics selected for display"
        exit 459
    }
    local n_stats : word count `stats_layout'

    local _source_vars ""
    capture collect levelsof var
    if !_rc {
        local _source_vars "`s(levels)'"
        local _source_vars : subinstr local _source_vars "_hide" "", word all
        local _source_vars = strtrim("`_source_vars'")
    }
    local _source_nvars : word count `_source_vars'
    local _single_source_var ""
    if `_source_nvars' == 1 {
        local _single_source_var : word 1 of `_source_vars'
    }

    local _sum_integer 1
    local _mean_binary 0
    if "`_single_source_var'" != "" {
        capture confirm numeric variable `_single_source_var'
        if _rc {
            local _sum_integer 0
            display as text "desctab: source variable `_single_source_var' not in memory; formatting sums with digits()"
        }
        else {
            quietly count if !missing(`_single_source_var') ///
                & `_single_source_var' != round(`_single_source_var')
            if r(N) > 0 local _sum_integer 0
            quietly count if !missing(`_single_source_var') ///
                & !inlist(`_single_source_var', 0, 1)
            if r(N) == 0 local _mean_binary 1
        }
    }
    else if `_source_nvars' > 1 {
        local _sum_integer 0
    }

    foreach _stat of local stats_layout {
        _tabtools_resolve_stat_format `_stat', digits(`digits') ///
            pctdigits(`pctdigits') nintegerfmt("`nintegerfmt'")
        local fmt_`_stat' "`r(fmt)'"
        local class_`_stat' "`r(class)'"
        if inlist("`_stat'", "sum", "sum_w", "total") & !`_sum_integer' {
            local fmt_`_stat' "%5.`digits'f"
            local class_`_stat' "continuous"
        }
    }

    if `"`nformats'"' != "" {
        local _nf_clean = subinstr(`"`nformats'"', "=", " ", .)
        local _nf_n : word count `_nf_clean'
        if mod(`_nf_n', 2) != 0 {
            display as error "nformats() must contain stat=format or stat format pairs"
            exit 198
        }
        forvalues _nf_i = 1(2)`_nf_n' {
            local _nf_stat : word `_nf_i' of `_nf_clean'
            local _nf_fmt : word `=`_nf_i' + 1' of `_nf_clean'
            _desctab_has_stat "`_nf_stat'" "`stats_available'"
            if `r(found)' local fmt_`_nf_stat' "`_nf_fmt'"
            else display as text "nformats: statistic '`_nf_stat'' not in collect, ignoring"
        }
    }

    if `"`statlabels'"' != "" {
        _desctab_parse_statlabels, spec("`statlabels'") stats("`stats_available'")
        foreach _stat of local stats_available {
            if `"`r(label_`_stat')'"' != "" local statlabel_`_stat' `"`r(label_`_stat')'"'
        }
    }

    foreach _stat of local stats_layout {
        capture collect style cell result[`_stat'], warn nformat(`fmt_`_stat'') ///
            halign(center) valign(center)
    }
    collect style column, dups(center)
    collect style row stack, nodelimiter nospacer indent length(.) wrapon(word) ///
        noabbreviate wrap(.) truncate(tail)

    tempfile _desctab_export
    local _temp_xlsx "`_desctab_export'.xlsx"
    if "`coldim'" != "" {
        quietly collect layout (`rowdim') (`coldim'#result[`stats_layout']) ()
        local raw_stat_row 3
        local raw_col_row 2
        local raw_dim_row 4
        local raw_data_start 5
    }
    else {
        quietly collect layout (`rowdim') (result[`stats_layout']) ()
        local raw_stat_row 1
        local raw_col_row 0
        local raw_dim_row 2
        local raw_data_start 3
    }

    preserve
    local _preserved 1
    if "`coldim'" != "" {
        capture _tabtools_collect_render, type(desctab) rowdim(`rowdim') ///
            coldim(`coldim') results(`stats_layout')
    }
    else {
        capture _tabtools_collect_render, type(desctab) rowdim(`rowdim') ///
            results(`stats_layout')
    }
    local _collect_render_rc = _rc
    if `_collect_render_rc' {
        restore
        local _preserved 0
        capture collect export "`_temp_xlsx'", replace
        if _rc {
            display as error "Failed to export the active collect to a temporary workbook"
            exit _rc
        }
        preserve
        local _preserved 1
        capture _tabtools_xlsx_read using "`_temp_xlsx'", sheet("Sheet1")
        if _rc {
            display as error "Failed to import the temporary collect workbook"
            exit _rc
        }
    }
    capture erase "`_temp_xlsx'"

    unab _allvars : _all
    local data_vars ""
    foreach _v of local _allvars {
        if "`_v'" != "A" local data_vars "`data_vars' `_v'"
    }
    local data_vars = strtrim("`data_vars'")
    if "`data_vars'" == "" {
        display as error "The active collect exported no data cells"
        exit 2000
    }

    if "`coldim'" != "" & `raw_dim_row' <= _N {
        local _raw_dim_has_data 0
        foreach _v of local data_vars {
            if strtrim(`_v'[`raw_dim_row']) != "" local _raw_dim_has_data 1
        }
        if `_raw_dim_has_data' {
            local raw_data_start = `raw_dim_row'
            local raw_dim_row 0
        }
    }

    local drop_row_totals = ("`nototals'" != "" & "`rowtotals'" == "")
    local drop_col_totals = ("`nototals'" != "" & "`coltotals'" == "")

    if `drop_col_totals' & "`coldim'" != "" {
        foreach _v of local data_vars {
            if strtrim(`_v'[`raw_col_row']) == "Total" {
                drop `_v'
            }
        }
        unab _allvars : _all
        local data_vars ""
        foreach _v of local _allvars {
            if "`_v'" != "A" local data_vars "`data_vars' `_v'"
        }
        local data_vars = strtrim("`data_vars'")
    }

    tempvar _desctab_drop
    quietly gen byte `_desctab_drop' = 0
    if `drop_row_totals' {
        quietly replace `_desctab_drop' = 1 if _n >= `raw_data_start' ///
            & lower(strtrim(A)) == "total"
    }
    if "`nomissing'" != "" {
        quietly replace `_desctab_drop' = 1 if _n >= `raw_data_start' ///
            & inlist(lower(strtrim(A)), "missing", ".", ".m")
    }
    if `"`keep'"' != "" {
        quietly replace `_desctab_drop' = 1 if _n >= `raw_data_start' ///
            & strpos(" `keep' ", " " + strtrim(A) + " ") == 0
    }
    if `"`drop'"' != "" {
        quietly replace `_desctab_drop' = 1 if _n >= `raw_data_start' ///
            & strpos(" `drop' ", " " + strtrim(A) + " ") > 0
    }
    quietly drop if `_desctab_drop'
    drop `_desctab_drop'

    local n_data_vars : word count `data_vars'
    if `n_data_vars' == 0 {
        display as error "No data columns remain after filtering"
        exit 2000
    }
    if mod(`n_data_vars', `n_stats') != 0 {
        display as error "The active collect table shape is not supported by desctab"
        display as error "Expected one row dimension and zero or one column dimension"
        exit 459
    }
    local n_groups = `n_data_vars' / `n_stats'

    local highlight_rows ""
    local _merge_group_headers 0
    local _merge_row_header 0

    if `"`compose_resolved'"' == "" {
        local _j = 0
        foreach _v of local data_vars {
            local ++_j
            local _sidx = mod(`_j' - 1, `n_stats') + 1
            local _stat : word `_sidx' of `stats_layout'
            local _fmt "`fmt_`_stat''"
            local _class "`class_`_stat''"
            local _scale = 1
            local _add_pctsign = inlist("`_class'", "percent", "proportion")
            if "`_class'" == "proportion" & "`pctscale'" == "0to100" {
                local _scale = 100
                local _fmt "%5.`pctdigits'f"
            }
            else if "`_stat'" == "mean" & "`pctscale'" == "0to100" & `_mean_binary' {
                local _scale = 100
                local _fmt "%5.`pctdigits'f"
                local _add_pctsign = 1
            }
            quietly replace `_v' = strtrim(string(real(subinstr(`_v', ",", "", .)) * `_scale', "`_fmt'")) ///
                if _n >= `raw_data_start' & strtrim(`_v') != "" ///
                & real(subinstr(`_v', ",", "", .)) < .
            if "`pctsign'" != "" & `_add_pctsign' {
                quietly replace `_v' = `_v' + "%" if _n >= `raw_data_start' ///
                    & strtrim(`_v') != "" & strpos(`_v', "%") == 0
            }
            if "`hlstat'" == "" local hlstat "mean"
            if `highlight' != -1 & "`_stat'" == "`hlstat'" {
                forvalues _r = `raw_data_start'/`=_N' {
                    local _hraw = subinstr(strtrim(`_v'[`_r']), ",", "", .)
                    local _hnum = real("`_hraw'")
                    if `_hnum' < . & `_hnum' < `highlight' {
                        local highlight_rows "`highlight_rows' `_r'"
                    }
                }
            }
            if `"`statlabel_`_stat''"' != "" {
                quietly replace `_v' = `"`statlabel_`_stat''"' in `raw_stat_row'
            }
            rename `_v' c`_j'
        }
        local n_display_cols = `n_data_vars'
        * Capture per-group header labels for later border / grouping logic.
        if "`coldim'" != "" {
            forvalues _g = 1/`n_groups' {
                local _first = (`_g' - 1) * `n_stats' + 1
                local _glabel_`_g' = strtrim(c`_first'[`raw_col_row'])
            }
        }
        if "`coldim'" != "" & `n_stats' > 1 {
            local _merge_group_headers 1
            forvalues _g = 1/`n_groups' {
                local _first = (`_g' - 1) * `n_stats' + 1
                local _firstvar c`_first'
                local _glabel = strtrim(`_firstvar'[`raw_col_row'])
                forvalues _s = 1/`n_stats' {
                    local _j = (`_g' - 1) * `n_stats' + `_s'
                    if `_s' == 1 {
                        quietly replace c`_j' = `"`_glabel'"' in `raw_col_row'
                    }
                    else {
                        quietly replace c`_j' = "" in `raw_col_row'
                    }
                }
            }
            local _row_label ""
            local _dim_row_is_label 0
            if `raw_dim_row' > 0 {
                local _row_label = strtrim(A[`raw_dim_row'])
                if `"`_row_label'"' != "" local _dim_row_is_label 1
                forvalues _j = 1/`n_display_cols' {
                    if strtrim(c`_j'[`raw_dim_row']) != "" local _dim_row_is_label 0
                }
            }
            quietly replace A = `"`_row_label'"' in `raw_col_row'
            quietly replace A = "" in `raw_stat_row'
            if `_dim_row_is_label' {
                quietly drop in `raw_dim_row'
                local raw_data_start = `raw_data_start' - 1
                local raw_dim_row 0
                local _merge_row_header 1
            }
            local _top_header_row = `raw_col_row' - 1
            local _drop_top_header 0
            if `_top_header_row' > 0 {
                local _top_label = strtrim(A[`_top_header_row'])
                local _first_header ""
                local _same_header 1
                local _nonblank_header 0
                forvalues _j = 1/`n_display_cols' {
                    local _hdr = strtrim(c`_j'[`_top_header_row'])
                    if `"`_hdr'"' != "" {
                        local _nonblank_header 1
                        if `"`_first_header'"' == "" local _first_header `"`_hdr'"'
                        else if `"`_hdr'"' != `"`_first_header'"' local _same_header 0
                    }
                }
                if `"`_top_label'"' == "" & `_nonblank_header' & `_same_header' {
                    local _drop_top_header 1
                }
            }
            if `_drop_top_header' {
                quietly drop in `_top_header_row'
                local raw_col_row = `raw_col_row' - 1
                local raw_stat_row = `raw_stat_row' - 1
                local raw_data_start = `raw_data_start' - 1
            }
        }
    }
    else {
        forvalues _g = 1/`n_groups' {
            quietly gen strL _new`_g' = ""
            local _first = (`_g' - 1) * `n_stats' + 1
            local _firstvar : word `_first' of `data_vars'
            if "`coldim'" != "" {
                local _glabel_`_g' = strtrim(`_firstvar'[`raw_col_row'])
                quietly replace _new`_g' = `"`_glabel_`_g''"' in `raw_col_row'
            }
            else {
                local _glabel_`_g' ""
                quietly replace _new`_g' = "Value" in `raw_stat_row'
            }
        }

        forvalues _r = `raw_data_start'/`=_N' {
            forvalues _g = 1/`n_groups' {
                foreach _alias in count frequency fvfrequency total sum sum_w ///
                    percent fvpercent prop propc propr mean sd semean median ///
                    p50 p25 p75 min max {
                    local _raw_`_alias' ""
                    local _f_`_alias' ""
                }
                foreach _stat of local stats_layout {
                    local _pos : list posof "`_stat'" in stats_layout
                    local _vpos = (`_g' - 1) * `n_stats' + `_pos'
                    local _v : word `_vpos' of `data_vars'
                    local _raw_`_stat' = strtrim(`_v'[`_r'])
                    local _scale = 1
                    local _sign ""
                    local _fmt "`fmt_`_stat''"
                    if inlist("`_stat'", "mean", "prop", "propc", "propr", "percent", "fvpercent") {
                        if inlist("`_stat'", "mean", "prop", "propc", "propr") & "`pctscale'" == "0to100" {
                            local _scale = 100
                            local _fmt "%5.`pctdigits'f"
                        }
                        if "`pctsign'" != "" & inlist("`_stat'", "mean", "prop", "propc", "propr", "percent", "fvpercent") {
                            local _sign "pctsign"
                        }
                    }
                    _desctab_format_local, value("`_raw_`_stat''") ///
                        format("`_fmt'") scale(`_scale') `_sign'
                    local _f_`_stat' `"`r(value)'"'
                }
                if `"`_f_total'"' != "" local _f_sum `"`_f_total'"'
                if `"`_raw_total'"' != "" local _raw_sum `"`_raw_total'"'
                if `"`_f_frequency'"' != "" local _f_count `"`_f_frequency'"'
                if `"`_f_fvfrequency'"' != "" local _f_count `"`_f_fvfrequency'"'
                if `"`_raw_frequency'"' != "" local _raw_count `"`_raw_frequency'"'
                if `"`_raw_fvfrequency'"' != "" local _raw_count `"`_raw_fvfrequency'"'
                if `"`_f_fvpercent'"' != "" local _f_percent `"`_f_fvpercent'"'
                if `"`_f_prop'"' != "" local _f_percent `"`_f_prop'"'
                if `"`_f_propc'"' != "" local _f_percent `"`_f_propc'"'
                if `"`_f_propr'"' != "" local _f_percent `"`_f_propr'"'
                if `"`_f_mean'"' != "" & `"`_f_percent'"' == "" local _f_percent `"`_f_mean'"'
                if `"`_f_median'"' != "" local _f_p50 `"`_f_median'"'
                if `"`_raw_median'"' != "" local _raw_p50 `"`_raw_median'"'

                if "`hlstat'" == "" local hlstat "mean"
                if `highlight' != -1 {
                    capture local _hraw = subinstr(strtrim(`"`_raw_`hlstat''"'), ",", "", .)
                    if !_rc {
                        local _hnum = real("`_hraw'")
                        if `_hnum' < . & `_hnum' < `highlight' {
                            local highlight_rows "`highlight_rows' `_r'"
                        }
                    }
                }

                if "`compose_resolved'" == "events_n_pct" {
                    local _cell `"`_f_sum' / `_f_count' (`_f_mean')"'
                }
                else if "`compose_resolved'" == "events_n" {
                    local _cell `"`_f_sum' / `_f_count'"'
                }
                else if "`compose_resolved'" == "n_pct" {
                    local _cell `"`_f_count' (`_f_percent')"'
                }
                else if "`compose_resolved'" == "mean_sd" {
                    local _cell `"`_f_mean' (`_f_sd')"'
                }
                else if "`compose_resolved'" == "mean_semean" {
                    local _cell `"`_f_mean' (`_f_semean')"'
                }
                else if "`compose_resolved'" == "median_iqr" {
                    local _cell `"`_f_p50' (`_f_p25'-`_f_p75')"'
                }
                else if "`compose_resolved'" == "median_range" {
                    local _cell `"`_f_p50' (`_f_min'-`_f_max')"'
                }
                else if "`compose_resolved'" == "mean_ci" {
                    local _mean = real(subinstr(`"`_raw_mean'"', ",", "", .))
                    local _count = real(subinstr(`"`_raw_count'"', ",", "", .))
                    local _se = .
                    if `"`_raw_semean'"' != "" {
                        local _se = real(subinstr(`"`_raw_semean'"', ",", "", .))
                    }
                    else if `"`_raw_sd'"' != "" & `_count' > 0 {
                        local _sd = real(subinstr(`"`_raw_sd'"', ",", "", .))
                        local _se = `_sd' / sqrt(`_count')
                    }
                    if `_mean' < . & `_se' < . & `_count' > 1 {
                        local _crit = invttail(`_count' - 1, 0.025)
                        local _lo = `_mean' - `_crit' * `_se'
                        local _hi = `_mean' + `_crit' * `_se'
                        local _lo_s = strtrim(string(`_lo', "`fmt_mean'"))
                        local _hi_s = strtrim(string(`_hi', "`fmt_mean'"))
                        local _cell `"`_f_mean' (`_lo_s'-`_hi_s')"'
                    }
                    else local _cell ""
                }
                else {
                    local _cell `"`compose_resolved'"'
                    foreach _stat of local stats_layout {
                        local _cell : subinstr local _cell "{`_stat'}" `"`_f_`_stat''"', all
                    }
                }
                quietly replace _new`_g' = `"`_cell'"' in `_r'
            }
        }

        drop `data_vars'
        if "`coldim'" != "" {
            quietly drop in `raw_stat_row'
            quietly drop in 1
            local raw_data_start = `raw_data_start' - 2
            local raw_dim_row = `raw_dim_row' - 2
        }
        local _j = 0
        forvalues _g = 1/`n_groups' {
            local ++_j
            rename _new`_g' c`_j'
        }
        local n_display_cols = `n_groups'

        * Collapse residual dim-label row in compose path. After the drops above,
        * raw_dim_row may still hold a dimension label (e.g. "Education level")
        * in column A with no data in the c1..cN cells. Move the label up to the
        * header row (so column B gets a "what these rows are levels of" header)
        * and drop the residual row so the header sits on row 2 with no spacer.
        * Post-drops the header row is row 1 in both the coldim and no-coldim
        * branches (coldim: drops in 1 and `raw_stat_row' shifted col headers up;
        * no-coldim: "Value" was written at `raw_stat_row' = 1).
        if `raw_dim_row' > 0 & `raw_dim_row' < `raw_data_start' & `raw_dim_row' <= _N {
            local _dim_row_is_label 0
            local _dim_label = strtrim(A[`raw_dim_row'])
            if `"`_dim_label'"' != "" local _dim_row_is_label 1
            forvalues _j = 1/`n_display_cols' {
                if strtrim(c`_j'[`raw_dim_row']) != "" local _dim_row_is_label 0
            }
            if `_dim_row_is_label' {
                quietly replace A = `"`_dim_label'"' in 1
                quietly drop in `raw_dim_row'
                local raw_data_start = `raw_data_start' - 1
                local raw_dim_row 0
            }
        }
    }

    * Add title row/column so Excel and Markdown output follows the suite convention:
    * title in A1, row labels in B, table body starting at B2/C2.
    tempvar _desctab_id
    quietly gen long `_desctab_id' = _n
    local _oldN = _N
    quietly set obs `=`_oldN' + 1'
    quietly replace `_desctab_id' = 0 if missing(`_desctab_id')
    quietly sort `_desctab_id'
    drop `_desctab_id'
    foreach _v of varlist A c* {
        quietly replace `_v' = "" in 1
    }
    quietly gen strL title = ""
    order title A c*
    quietly replace title = `"`title'"' in 1

    local data_start = `raw_data_start' + 1
    local header_start = 2
    local num_rows = _N
    local num_cols = c(k)
    local _label_width = 8
    forvalues _r = 2/`num_rows' {
        local _len = strlen(A[`_r'])
        if `_len' > `_label_width' local _label_width = `_len'
    }
    local _label_width = min(max(`_label_width' + 2, 8), 32)
    forvalues _c = 1/`n_display_cols' {
        local _data_width_`_c' = 10
        forvalues _r = 2/`num_rows' {
            local _len = strlen(c`_c'[`_r'])
            if `_len' > `_data_width_`_c'' local _data_width_`_c' = `_len'
        }
        local _data_width_`_c' = min(max(`_data_width_`_c'' + 2, 10), 28)
    }
    local n_cells = 0
    forvalues _r = `data_start'/`num_rows' {
        forvalues _c = 1/`n_display_cols' {
            if strtrim(c`_c'[`_r']) != "" local ++n_cells
        }
    }
    local body_rows = max(`num_rows' - `data_start' + 1, 1)
    tempname _rtable
    matrix `_rtable' = J(`body_rows', `n_display_cols', .)
    forvalues _rr = 1/`body_rows' {
        local _drow = `data_start' + `_rr' - 1
        forvalues _cc = 1/`n_display_cols' {
            if `_drow' <= `num_rows' {
                local _v = subinstr(strtrim(c`_cc'[`_drow']), ",", "", .)
                local _v = subinstr("`_v'", "%", "", .)
                local _num = real("`_v'")
                if `_num' < . matrix `_rtable'[`_rr', `_cc'] = `_num'
            }
        }
    }

    local _methods "Formatted descriptive statistics from a Stata collect table using per-statistic formats."
    if `"`compose_resolved'"' != "" {
        local _methods "`_methods' Composite cells were rendered with compose(`compose_resolved')."
    }
    local _methods "`_methods' Analysis performed in Stata `c(stata_version)' (StataCorp, College Station, TX)."

    return matrix table = `_rtable'
    return scalar N_cells = `n_cells'
    return scalar N_rows = `=`num_rows' - 1'
    * Derive version from this file's *! header so it cannot drift on a bump.
    local _dt_version "unknown"
    capture findfile desctab.ado
    if !_rc {
        tempname _dt_vfh
        capture file open `_dt_vfh' using "`r(fn)'", read text
        if !_rc {
            file read `_dt_vfh' _dt_vheader
            file close `_dt_vfh'
            if regexm(`"`_dt_vheader'"', "Version ([0-9.]+)") ///
                local _dt_version = regexs(1)
        }
    }
    return local version "`_dt_version'"
    return local rowvar "`rowdim'"
    return local colvar "`coldim'"
    return local stats "`stats_layout'"
    return local compose `"`compose_resolved'"'
    return local methods "`_methods'"
    if `_has_xlsx' {
        return local xlsx "`xlsx'"
        return local sheet "`sheet'"
    }

    if "`csv'" != "" {
        _tabtools_csv_write using "`csv'", labelvar(A)
    }

    local _ret_markdown ""
    local _ret_markdown_rows .
    local _ret_markdown_cols .
    if `"`markdown'"' != "" {
        local _mdappend_opt ""
        if "`mdappend'" != "" local _mdappend_opt "append"
        capture noisily _tabtools_markdown_write using `"`markdown'"', ///
            `_mdappend_opt' labelvar(A) headerstart(`header_start') ///
            datastart(`data_start') title(`"`title'"') footnote(`"`footnote'"') strictheaders
        if _rc {
            local _md_rc = _rc
            display as error "Failed to export Markdown to `markdown'"
            error `_md_rc'
        }
        local _ret_markdown `"`markdown'"'
        local _ret_markdown_rows = r(n_rows)
        local _ret_markdown_cols = r(n_cols)
        return local markdown `"`_ret_markdown'"'
        return scalar markdown_rows = `_ret_markdown_rows'
        return scalar markdown_cols = `_ret_markdown_cols'
    }

    if `"`frame'"' != "" {
        _tabtools_frame_put `"`frame'"'
        local frame "`_frame_name'"
        return local frame "`frame'"
    }

    noisily _tabtools_console_display `n_display_cols' `"`title'"', ///
        labelvar(A) datastart(`data_start') headerstart(`header_start')

    if `_has_xlsx' {
        capture noisily _tabtools_xlsx_write using "`xlsx'", sheet("`sheet'") book(b)
        if _rc {
            local _export_rc = _rc
            display as error "Failed to export to `xlsx', sheet `sheet'"
            display as error "Check file permissions and that the workbook is not open"
            error `_export_rc'
        }

        local _fn_text `"`footnote'"'
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
            local _style_rule_rows ""
            local _style_rule_rows `"`_style_rule_rows' | 13, 1, 1, 1, 1, 1, 0, 0, 0"'
            local _style_rule_rows `"`_style_rule_rows' | 13, 1, 1, 2, 2, `_label_width', 0, 0, 0"'
            forvalues _c = 3/`num_cols' {
                local _dc = `_c' - 2
                local _style_rule_rows `"`_style_rule_rows' | 13, 1, 1, `_c', `_c', `_data_width_`_dc'', 0, 0, 0"'
            }
            local _style_rule_rows `"`_style_rule_rows' | 12, 1, 1, 1, 1, 30, 0, 0, 0"'
            local _style_rule_rows `"`_style_rule_rows' | 1, 1, `num_rows', 1, `num_cols', `_fontsize', 1, 0, 0"'
            local _style_rule_rows `"`_style_rule_rows' | 1, 1, 1, 1, `num_cols', `=`_fontsize' + 2', 1, 0, 0"'
            local _style_rule_rows `"`_style_rule_rows' | 14, 1, 1, 1, `num_cols', 0, 0, 0, 0"'
            local _style_rule_rows `"`_style_rule_rows' | 4, 1, 1, 1, 1, 0, 1, 0, 0"'
            local _style_rule_rows `"`_style_rule_rows' | 5, 1, 1, 1, 1, 0, 1, 0, 0"'
            local _style_rule_rows `"`_style_rule_rows' | 6, 1, 1, 1, 1, 0, 2, 0, 0"'
            local _style_rule_rows `"`_style_rule_rows' | 2, 1, 1, 1, 1, 0, 1, 0, 0"'
            if `_merge_group_headers' {
                if `_merge_row_header' & `data_start' > 3 {
                    local _style_rule_rows `"`_style_rule_rows' | 14, 2, `=`data_start' - 1', 2, 2, 0, 0, 0, 0"'
                    local _style_rule_rows `"`_style_rule_rows' | 6, 2, `=`data_start' - 1', 2, 2, 0, 2, 0, 0"'
                }
                forvalues _g = 1/`n_groups' {
                    local _merge_start = 3 + (`_g' - 1) * `n_stats'
                    local _merge_end = `_merge_start' + `n_stats' - 1
                    if `_merge_end' > `_merge_start' {
                        local _style_rule_rows `"`_style_rule_rows' | 14, 2, 2, `_merge_start', `_merge_end', 0, 0, 0, 0"'
                    }
                }
            }
            local _style_rule_rows `"`_style_rule_rows' | 2, 2, `=`data_start' - 1', 2, `num_cols', 0, 1, 0, 0"'
            local _style_rule_rows `"`_style_rule_rows' | 5, 2, `=`data_start' - 1', 3, `num_cols', 0, 2, 0, 0"'
            if "`headershade'" != "" {
                local _style_rule_rows `"`_style_rule_rows' | 7, 2, `=`data_start' - 1', 2, `num_cols', 0, -1, 0, 0"'
            }
            local _style_rule_rows `"`_style_rule_rows' | 8, 2, 2, 2, `num_cols', 0, `_hborder_code', 0, 0"'
            local _style_rule_rows `"`_style_rule_rows' | 9, `=`data_start' - 1', `=`data_start' - 1', 2, `num_cols', 0, `_hborder_code', 0, 0"'
            local _style_rule_rows `"`_style_rule_rows' | 9, `num_rows', `num_rows', 2, `num_cols', 0, `_hborder_code', 0, 0"'
            if "`borderstyle'" != "academic" {
                local _style_rule_rows `"`_style_rule_rows' | 10, 2, `num_rows', 2, 2, 0, `_vborder_code', 0, 0"'
                local _style_rule_rows `"`_style_rule_rows' | 11, 2, `num_rows', `num_cols', `num_cols', 0, `_vborder_code', 0, 0"'
                local _style_rule_rows `"`_style_rule_rows' | 11, 2, `num_rows', 2, 2, 0, `_vborder_code', 0, 0"'
                if `n_groups' > 1 {
                    local _cols_per_group = `n_display_cols' / `n_groups'
                    forvalues _g = 1/`=`n_groups' - 1' {
                        local _next_g = `_g' + 1
                        local _curr_label "`_glabel_`_g''"
                        local _next_label "`_glabel_`_next_g''"
                        local _draw = (`_cols_per_group' > 1) ///
                            | ("`_next_label'" == "Total") ///
                            | ("`_curr_label'" == "Total")
                        if `_draw' {
                            local _gcol_end = 2 + `_g' * `_cols_per_group'
                            local _style_rule_rows `"`_style_rule_rows' | 11, 2, `num_rows', `_gcol_end', `_gcol_end', 0, `_vborder_code', 0, 0"'
                        }
                    }
                }
            }
            if "`zebra'" != "" {
                forvalues _zr = `=`data_start' + 1'(2)`num_rows' {
                    local _style_rule_rows `"`_style_rule_rows' | 7, `_zr', `_zr', 2, `num_cols', 0, -2, 0, 0"'
                }
            }
            if `highlight' != -1 {
                local _hl_rows : list uniq highlight_rows
                foreach _hr of local _hl_rows {
                    local _excel_hr = `_hr' + 1
                    if `"`compose_resolved'"' != "" & "`coldim'" != "" {
                        local _excel_hr = `_hr' - 1
                    }
                    if `_excel_hr' >= `data_start' & `_excel_hr' <= `num_rows' {
                        local _style_rule_rows `"`_style_rule_rows' | 7, `_excel_hr', `_excel_hr', 2, `num_cols', 0, -3, 0, 0"'
                    }
                }
            }
            local _style_rule_rows `"`_style_rule_rows' | 5, `data_start', `num_rows', 3, `num_cols', 0, 2, 0, 0"'
            if `"`_fn_text'"' != "" {
                local _fn_row = `num_rows' + 1
                local _fn_fontsize = max(`_fontsize' - 2, 6)
                mata: b.put_string(`_fn_row', 2, `"`_fn_text'"')
                local _style_rule_rows `"`_style_rule_rows' | 14, `_fn_row', `_fn_row', 2, `num_cols', 0, 0, 0, 0"'
                local _style_rule_rows `"`_style_rule_rows' | 4, `_fn_row', `_fn_row', 2, 2, 0, 1, 0, 0"'
                local _style_rule_rows `"`_style_rule_rows' | 1, `_fn_row', `_fn_row', 2, 2, `_fn_fontsize', 1, 0, 0"'
                local _style_rule_rows `"`_style_rule_rows' | 3, `_fn_row', `_fn_row', 2, 2, 0, 1, 0, 0"'
            }

            _tabtools_xlsx_build_styles, matrix(`_style_rules') ///
                rules(`"`_style_rule_rows'"') cols(9)
            _tabtools_xlsx_apply_styles, book(b) sheet("`sheet'") ///
                rules(`_style_rules') font("`_font'") ///
                color1("`_headercolor'") color2("`_zebracolor'") ///
                color3("255 255 204")
            mata: b.close_book()
        }
        if _rc {
            local _fmt_rc = _rc
            capture mata: b.close_book()
            capture mata: mata drop b
            display as error "Excel and Markdown formatting failed with error `_fmt_rc'"
            error `_fmt_rc'
        }
        capture mata: mata drop b
        capture confirm file "`xlsx'"
        if _rc {
            display as error "Export command succeeded but file not found"
            exit 601
        }
        display as text "Exported " as result "`=`num_rows' - 1'" ///
            as text " rows x " as result "`=`num_cols' - 1'" ///
            as text " cols to " as result `"`xlsx'"' ///
            as text ", sheet " as result `"`sheet'"'
        if "`open'" != "" _tabtools_open_file "`xlsx'"
    }

    restore
    local _preserved 0

    }
    local rc = _rc
    capture putexcel close
    if `_preserved' {
        capture restore
    }
    set varabbrev `_orig_varabbrev'
    if `rc' exit `rc'
end

capture program drop _desctab_parse_layout
program define _desctab_parse_layout, rclass
    version 17.0
    args rowspec colspec

    local rowspec = ustrregexra(`"`rowspec'"', "\[[^\]]*\]", "")
    local colspec = ustrregexra(`"`colspec'"', "\[[^\]]*\]", "")
    local rowdim ""
    local coldim ""
    foreach _tok in `=subinstr("`rowspec'", "#", " ", .)' {
        local _dim = regexr("`_tok'", "\[.*", "")
        if "`_dim'" != "" & "`_dim'" != "result" & "`rowdim'" == "" {
            local rowdim "`_dim'"
        }
        else if "`_dim'" != "" & "`_dim'" != "result" & "`rowdim'" != "" {
            local rowdim "`rowdim'#`_dim'"
        }
    }
    foreach _tok in `=subinstr("`colspec'", "#", " ", .)' {
        local _dim = regexr("`_tok'", "\[.*", "")
        if "`_dim'" != "" & "`_dim'" != "result" & "`coldim'" == "" {
            local coldim "`_dim'"
        }
        else if "`_dim'" != "" & "`_dim'" != "result" & "`coldim'" != "" {
            local coldim "`coldim'#`_dim'"
        }
    }
    return local rowdim "`rowdim'"
    return local coldim "`coldim'"
end

capture program drop _desctab_has_stat
program define _desctab_has_stat, rclass
    version 17.0
    args stat stats
    local found 0
    foreach _s of local stats {
        if "`_s'" == "`stat'" local found 1
    }
    return scalar found = `found'
end

capture program drop _desctab_pick_stat
program define _desctab_pick_stat, rclass
    version 17.0
    syntax , CANDIDATES(string) STATS(string)
    local picked ""
    foreach _cand of local candidates {
        foreach _s of local stats {
            if "`_s'" == "`_cand'" & "`picked'" == "" local picked "`_cand'"
        }
    }
    return local stat "`picked'"
end

capture program drop _desctab_resolve_compose
program define _desctab_resolve_compose, rclass
    version 17.0
    syntax , [COMPOSE(string asis) STATS(string)]

    local clean_compose `"`compose'"'
    local clean_compose : subinstr local clean_compose `"""' "", all
    local mode = lower(strtrim(`"`clean_compose'"'))
    local required ""
    local custom 0
    if `"`mode'"' == "" {
        return local compose ""
        return local required ""
        return scalar custom = 0
        exit
    }

    _desctab_pick_stat, candidates("count frequency fvfrequency") stats("`stats'")
    local count_stat "`r(stat)'"
    _desctab_pick_stat, candidates("sum total sum_w") stats("`stats'")
    local sum_stat "`r(stat)'"
    _desctab_pick_stat, candidates("percent fvpercent prop propc propr mean") stats("`stats'")
    local pct_stat "`r(stat)'"
    _desctab_pick_stat, candidates("p50 median") stats("`stats'")
    local median_stat "`r(stat)'"
    if "`count_stat'" == "" local count_stat "count"
    if "`sum_stat'" == "" local sum_stat "sum"
    if "`pct_stat'" == "" local pct_stat "percent"
    if "`median_stat'" == "" local median_stat "p50"

    if "`mode'" == "events_n_pct" {
        local required "`sum_stat' `count_stat' mean"
        local mode "events_n_pct"
    }
    else if "`mode'" == "events_n" {
        local required "`sum_stat' `count_stat'"
    }
    else if "`mode'" == "n_pct" {
        local required "`count_stat' `pct_stat'"
        if "`pct_stat'" != "percent" & "`pct_stat'" != "" {
            local required : subinstr local required "`pct_stat'" "percent", all
            local mode "n_pct"
            if "`pct_stat'" != "percent" local required "`count_stat' `pct_stat'"
        }
    }
    else if "`mode'" == "mean_sd" {
        local required "mean sd"
    }
    else if "`mode'" == "mean_semean" {
        local required "mean semean"
    }
    else if "`mode'" == "median_iqr" {
        local required "p25 `median_stat' p75"
        if "`median_stat'" == "median" local mode "median_iqr"
    }
    else if "`mode'" == "median_range" {
        local required "`median_stat' min max"
    }
    else if "`mode'" == "mean_ci" {
        local required "mean count"
        _desctab_has_stat "semean" "`stats'"
        if `r(found)' local required "`required' semean"
        else local required "`required' sd"
    }
    else {
        local n_open = strlen(`"`clean_compose'"') - strlen(subinstr(`"`clean_compose'"', "{", "", .))
        local n_close = strlen(`"`clean_compose'"') - strlen(subinstr(`"`clean_compose'"', "}", "", .))
        if `n_open' != `n_close' {
            display as error "compose() has unbalanced braces"
            exit 198
        }
        local work `"`clean_compose'"'
        while regexm(`"`work'"', "\{([A-Za-z0-9_]+)\}") {
            local _ph = regexs(1)
            local required "`required' `_ph'"
            local work : subinstr local work "{`_ph'}" "", all
        }
        local required : list uniq required
        if "`required'" == "" {
            display as error "compose() must be a named preset or contain {stat} placeholders"
            exit 198
        }
        local mode `"`clean_compose'"'
        local custom 1
    }
    local required = strtrim("`required'")
    return local compose `"`mode'"'
    return local required "`required'"
    return scalar custom = `custom'
end

capture program drop _desctab_parse_nformats
program define _desctab_parse_nformats, rclass
    version 17.0
    syntax , [SPEC(string asis) STATS(string)]
    local clean = subinstr(`"`spec'"', "=", " ", .)
    local n : word count `clean'
    if `n' == 0 exit
    if mod(`n', 2) != 0 {
        display as error "nformats() must contain stat=format or stat format pairs"
        exit 198
    }
    forvalues _i = 1(2)`n' {
        local _stat : word `_i' of `clean'
        local _fmt : word `=`_i' + 1' of `clean'
        _desctab_has_stat "`_stat'" "`stats'"
        if `r(found)' return local fmt_`_stat' "`_fmt'"
        else display as text "nformats: statistic '`_stat'' not in collect, ignoring"
    }
end

capture program drop _desctab_parse_statlabels
program define _desctab_parse_statlabels, rclass
    version 17.0
    syntax , [SPEC(string asis) STATS(string)]
    local rest `"`spec'"'
    local rest : subinstr local rest `"""' "", all
    while `"`rest'"' != "" {
        local _slash = strpos(`"`rest'"', "\")
        if `_slash' {
            local piece = substr(`"`rest'"', 1, `_slash' - 1)
            local rest = substr(`"`rest'"', `_slash' + 1, .)
        }
        else {
            local piece `"`rest'"'
            local rest ""
        }
        local piece = strtrim(`"`piece'"')
        if `"`piece'"' == "" continue
        if regexm(`"`piece'"', "^([^= ]+)[ ]*=[ ]*(.+)$") {
            local _stat = regexs(1)
            local _label = regexs(2)
        }
        else {
            gettoken _stat _label : piece
            local _label = strtrim(`"`_label'"')
        }
        local _stat : subinstr local _stat `"""' "", all
        local _label : subinstr local _label `"""' "", all
        _desctab_has_stat "`_stat'" "`stats'"
        if `r(found)' return local label_`_stat' `"`_label'"'
        else display as text "statlabels: statistic '`_stat'' not in collect, ignoring"
    }
end

capture program drop _desctab_format_local
program define _desctab_format_local, rclass
    version 17.0
    syntax , VALUE(string asis) FORMAT(string) [SCALE(real 1) PCTSIGN]
    local clean "`value'"
    local clean : subinstr local clean `"""' "", all
    local clean = subinstr(strtrim("`clean'"), ",", "", .)
    if `"`clean'"' == "" {
        return local value ""
        exit
    }
    local num = real(`"`clean'"')
    if `num' >= . {
        return local value ""
        exit
    }
    local num = `num' * `scale'
    local out = strtrim(string(`num', "`format'"))
    if "`pctsign'" != "" local out "`out'%"
    return local value `"`out'"'
end
