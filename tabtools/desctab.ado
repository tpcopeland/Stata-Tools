*! desctab Version 2.0.0  2026/08/19 - Consolidated descriptive Table 1 engine
*! Author: Timothy P Copeland, Karolinska Institutet
*! Fork of -table1_mc- version 3.5 (2024-12-19) by Mark Chatfield
*! This program generates descriptive statistics tables with formatting options
*! and can export them to Excel with automatic column width calculation

program define desctab, rclass
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

**# Syntax Definition
    syntax [varlist] [if] [in] [fweight], ///
        [by(varname)]           /// Optional grouping variable
        [vars(string)]          /// Variables to display: varname vartype [varformat], vars delimited by \
        [Format(string)]        /// Default format for continuous normal/skewed variables
        [PERCFormat(string)]    /// Default format for categorical/binary variables
        [NFormat(string)]       /// Format for counts (n and N); default is %12.0fc
        [iqrmiddle(string asis)] /// Symbol between Q1 and Q3; default is ", "
        [sdleft(string asis)]   /// Symbol before SD; default is "+/-"
        [sdright(string asis)]  /// Symbol after SD; default is "" (none)
        [gsdleft(string asis)]  /// Symbol before GSD; default is " (×/"
        [gsdright(string asis)] /// Symbol after GSD; default is ")"
        [percent]               /// Report categorical vars just as % (no N)
        [MISsing]               /// Don't exclude missing values
        [pdp(integer 3)]        /// Max decimal places in p-value < 0.1 (1-10)
        [highpdp(integer 2)]    /// Max decimal places in p-value >= 0.1 (1-10)
        [test]                  /// Include column specifying which test was used
        [STATistic]             /// Give value of test statistic
        [excel(string)]         /// Excel file to save output
        [xlsx(string)]          /// Synonym for excel()
        [sheet(string)]         /// Excel sheet name
        [title(string)]         /// Table title
        [clear]                 /// Keep resulting table in memory
        [percent_n]             /// Display as % (n) rather than n (%)
        [percsign(string asis)] /// Percent sign; default is "" (none)
        [SPACElowpercent]       /// Report e.g. ( 3%) rather than (3%) (no-space is default)
        [extraspace]            /// Helps alignment in DOCX with non-monospaced fonts
        [slashN]                /// Report n/N instead of n
        [total(string)]         /// Include total column ("before" or "after" group columns)
        [catrowperc]            /// Report row % rather than column % for categorical vars
        [varlabplus]            /// Add data type description to variable labels
        [HEADERPerc]            /// Add percentage of total to sample size row
        [BORDERstyle(string)]   /// Border style: "default" or "thin"
        [wt(varname)]           /// Importance/probability weight variable (e.g., IPTW)
        [smd]                   /// Standardized mean differences column
        [FOOTnote(string)]      /// Footnote text below table
        [open]                  /// Open Excel file after export
        [BOLDp(real -1)]        /// Bold p-values below threshold (-1 = disabled)
        [zebra]                 /// Alternating row shading
        [HIGHlight(real -1)]    /// Highlight rows where p < threshold
        [HEADERShade]           /// Header row shading in Excel
        [FRAme(string)]         /// Store output in a named frame
        [FONT(string)]          /// Font family for Excel output
        [FONTSIZE(integer -1)]  /// Font size in points for Excel output
        [SMDThreshold(real 0.1)] /// SMD threshold for conditional formatting (0.1 default; -1 = disabled)
        [HEADERColor(string)]   /// Custom header background color (R G B)
        [ZEBRAColor(string)]    /// Custom zebra stripe color (R G B)
        [csv(string)]           /// Export data as CSV file
        [MARKdown(string)]      /// Export data as Markdown file
        [MDAPPend]              /// Append Markdown table
        [MISSINGSummary]        /// Add missing data summary row per variable
        [SMALLCells(string)]    /// Suppress counts below threshold and prevent reconstruction
        [dots]                  /// Show progress dots per variable
        [WTCompare]             /// Side-by-side crude vs weighted comparison
        [WTN]                   /// Show weighted (effective) counts in weighted columns
        [NOPvalue]              /// Suppress p-value column

**# Input Validation and Option Setup

    local _markdown_title `"`title'"'

    /* Accept xlsx() as synonym for excel() */
    if "`excel'" == "" & "`xlsx'" != "" local excel "`xlsx'"

    * Resolve persistent defaults
    if `boldp' == -1 & "$TABTOOLS_BOLDP" != "" local boldp = $TABTOOLS_BOLDP

    /* Build vars() from varlist if not specified (U1) */
    if "`vars'" == "" & "`varlist'" != "" {
        local vars ""
        local _vcount : word count `varlist'
        forvalues _vi = 1/`_vcount' {
            local _vname : word `_vi' of `varlist'
            if `_vi' > 1 local vars "`vars' \ "
            local vars "`vars'`_vname' auto"
        }
    }

    /* Validation: Check if vars() is specified */
    if "`vars'" == "" {
        display as error "vars() or varlist required"
        error 100
    }

    if "`smallcells'" != "" {
        capture confirm integer number `smallcells'
        if _rc {
            display as error "smallcells() must be an integer greater than or equal to 3"
            error 198
        }
        if `smallcells' < 3 {
            display as error "smallcells() must be an integer greater than or equal to 3"
            error 198
        }
    }

    if "`smallcells'" != "" {
        local _sc_note "Counts below `smallcells' are shown as <`smallcells'; complementary cells are shown as ≥`smallcells' to prevent exact reconstruction. Percentages are withheld for any variable carrying a suppressed count."
        if strpos(`"`footnote'"', `"`_sc_note'"') == 0 {
            if `"`footnote'"' == "" local footnote `"`_sc_note'"'
            else local footnote `"`footnote' `_sc_note'"'
        }
    }

    /* Validation: Check if by() variable exists */
    if "`by'" != "" {
        capture confirm variable `by'
        if _rc {
            display as error "by() variable `by' not found"
            error 111
        }
    }

    /* Check if by() variable will cause naming conflicts.
       The reshape pipeline below produces wide columns named N_<level>,
       m_<level>, _columna_<level>, _columnb_<level>. A by-variable whose own
       name starts with N_, m_, or _column* would alias one of those during
       reshape and silently corrupt the output. See "Reserved by() variable
       names" in help table1_tc (Technical notes). */
    if (substr("`by'",1,2) == "N_" | substr("`by'",1,2) == "m_" | inlist("`by'", "N", "m") | ///
        inlist("`by'", "_", "_c","_co","_col","_colu","_colum","_column","_columna","_columnb")) {
        display as error "by() variable name `by' collides with internal reshape columns"
        display as error "Reserved prefixes: N_, m_; reserved names: N, m, _, _c, _co, _col, _colu, _colum, _column, _columna, _columnb"
        display as error "Rename the variable (e.g. {bf:rename `by' grp}); see {help table1_tc##technical:help table1_tc}"
        error 498  // User-defined error
    }

    /* Check if Excel options are properly specified */
    local has_excel = "`excel'" != ""  // Boolean flag for Excel option
    local has_markdown = `"`markdown'"' != ""
    local has_sheet = "`sheet'" != ""  // Boolean flag for sheet option
    local has_title = "`title'" != ""  // Boolean flag for title option
    local has_open = "`open'" != ""    // Boolean flag for open option

    if "`total'" != "" & !inlist("`total'", "before", "after") {
        display as error "total() must be before or after"
        error 198
    }

    // Default sheet name when excel() is specified but sheet() is not
    if `has_excel' & !`has_sheet' {
        local sheet "Table 1"
        local has_sheet = 1
    }

    // Validate sheet name for Excel constraints
    if `has_sheet' _tabtools_validate_sheet "`sheet'" "sheet()"

    // sheet() only makes sense with excel(); title() also applies to Markdown.
    if !`has_excel' & `has_sheet' {
        display as error "sheet() is only available when using excel()"
        error 498
    }
    if !`has_excel' & !`has_markdown' & `has_title' {
        display as error "title() is only available when using excel() or markdown()"
        error 498
    }
    if `has_open' & !`has_excel' {
        display as error "open requires excel() or xlsx()"
        error 498
    }

    /* Validate Excel file path for security */
    if `has_excel' {
        if !regexm(lower(`"`excel'"'), "\.xlsx$") {
            display as error "excel()/xlsx() must specify a .xlsx file"
            error 198
        }
        _tabtools_validate_path "`excel'" "excel()"
    }
    if "`mdappend'" != "" & !`has_markdown' {
        display as error "mdappend requires markdown()"
        error 198
    }
    if `has_markdown' {
        _tabtools_validate_path `"`markdown'"' "markdown()"
        local _md_lower = lower(`"`markdown'"')
        if !(strmatch(`"`_md_lower'"', "*.md") | ///
             strmatch(`"`_md_lower'"', "*.markdown") | ///
             strmatch(`"`_md_lower'"', "*.qmd") | ///
             strmatch(`"`_md_lower'"', "*.rmd")) {
            display as error "markdown() must specify a .md, .markdown, .qmd, or .rmd file"
            error 198
        }
    }

    /* Validate pdp and highpdp options */
    if `pdp' < 1 | `pdp' > 10 {
        display as error "pdp() must be between 1 and 10"
        error 198
    }
    if `highpdp' < 1 | `highpdp' > 10 {
        display as error "highpdp() must be between 1 and 10"
        error 198
    }

    /* Validate borderstyle option */
    local has_borderstyle = "`borderstyle'" != ""

    // borderstyle only makes sense with excel()
    if `has_borderstyle' & !`has_excel' {
        display as error "borderstyle() is only available when using excel()"
        error 498
    }

    // borderstyle must be a valid value
    if `has_borderstyle' & !inlist("`borderstyle'", "default", "thin", "medium", "academic") {
        display as error "borderstyle() must be default, thin, medium, or academic"
        error 498
    }

    /* Validate weight option metadata */
    if "`wt'" != "" {
        confirm numeric variable `wt'
        if "`weight'" == "fweight" {
            display as error "wt() and fweight cannot be used together"
            error 198
        }
    }
    local has_wt = "`wt'" != ""
    local _suppress_p = `has_wt' | "`nopvalue'" == "nopvalue"

    /* Weighted display policy. The recommended weighted table reports
       percentages (plus SMD for balance), not counts: once weighted, the
       displayed count is a function of the percentage and N (effective
       n = % × N), so "n (%)" prints the same number twice and dresses a
       synthetic quantity up as a real frequency. Counts are therefore shown
       only on request, via wtn (or percent_n):
         - standalone weighted: percent-only by default; wtn restores the
           effective count as n (%), percent_n as % (n).
         - wtcompare: crude columns always keep n (%); weighted columns are
           percent-only by default, with wtn/percent_n restoring weighted n.
       See the weighted-data Technical note in help table1_tc. */
    if "`wtn'" != "" & !`has_wt' {
        display as error "wtn requires wt() to be specified"
        exit 198
    }
    if "`wtn'" != "" & "`percent'" != "" {
        display as error "wtn and percent are incompatible (percent suppresses all counts)"
        exit 198
    }
    local _show_wtn = ("`percent_n'" != "" | "`wtn'" != "")
    if `has_wt' & !`_show_wtn' & "`wtcompare'" == "" {
        local percent "percent"
    }

    /* A percent-only cell publishes nothing BUT the percentage, and a published
       percentage releases its own denominator (the per-variable non-missing
       count). A protected block has to withhold that percentage, which would
       leave the block empty, so the combination cannot be protected and is
       refused rather than shipped as a reconstructable table. This check sits
       after the weighted default above so it catches an implicitly set
       percent, not only an explicitly requested one. */
    if "`smallcells'" != "" & "`percent'" != "" {
        display as error "smallcells() cannot be combined with percent-only display"
        display as error "Hint: use percent_n, wtn, or the default n (%); percentages are withheld for any variable that carries a suppressed count"
        exit 198
    }

    /* Validate new options */

    * SMD requires by() with 2+ groups
    local has_smd = "`smd'" != ""
    if `has_smd' & "`by'" == "" {
        display as error "smd option requires by() to be specified"
        exit 198
    }

    * wtcompare requires both wt() and by()
    local has_wtcompare = "`wtcompare'" != ""
    if `has_wtcompare' & !`has_wt' {
        display as error "wtcompare requires wt() to be specified"
        exit 198
    }
    if `has_wtcompare' & "`by'" == "" {
        display as error "wtcompare requires by() to be specified"
        exit 198
    }

    * Validate boldp
    local has_boldp = `boldp' != -1
    if `has_boldp' & (`boldp' <= 0 | `boldp' >= 1) {
        display as error "boldp() must be between 0 and 1"
        exit 198
    }

    * Validate highlight
    local has_highlight = `highlight' != -1
    if `has_highlight' & (`highlight' <= 0 | `highlight' >= 1) {
        display as error "highlight() must be between 0 and 1"
        exit 198
    }

    * Validate smdthreshold
    if `smdthreshold' != -1 & `smdthreshold' <= 0 {
        display as error "smdthreshold() must be positive or -1 to disable highlighting"
        exit 198
    }

    * Resolve formatting
    _tabtools_resolve_format, font(`"`font'"') fontsize(`fontsize') borderstyle(`borderstyle') headershade(`headershade')

    _tabtools_resolve_colors, headercolor(`"`headercolor'"') zebracolor(`"`zebracolor'"')

    * Initialize test tracking for methods paragraph (C5)
    local _used_ttest 0
    local _used_anova 0
    local _used_wilcoxon 0
    local _used_kw 0
    local _used_chi2 0
    local _used_fisher 0

    /* Set default formats if not specified */
    if `"`nformat'"' == "" local nformat "%12.0fc"        // Default format for counts
    if `"`format'"' == "" local format "%2.0f"            // Default format for continuous vars
    if `"`percformat'"' == "" local percformat "%5.0f"    // Default format for percentages
    local percsign = subinstr(strtrim(`"`percsign'"'), char(34), "", .)  // strip quotes from asis
    if `"`iqrmiddle'"' == "" local iqrmiddle `"", ""'     // Default separator for IQR
    if `"`sdleft'"' == "" local sdleft `""±""'            // Default symbol before SD
    if `"`sdright'"' == "" local sdright `""""'           // Default symbol after SD (none)
    local meanSD : display "mean"`sdleft'"SD"`sdright'    // Create mean±SD format string

    if `"`gsdleft'"' == "" local gsdleft `"" (×/""'       // Default format before GSD
    if `"`gsdright'"' == "" local gsdright `"")""'        // Default format after GSD
    local gmeanSD : display "geometric mean"`gsdleft'"GSD"`gsdright'  // Create geometric mean×/GSD format string

    /* Configure display formats for different variable types */
    local n "No."  // Column header for count (updated from just "n")
    if "`slashN'" == "slashN" local n "`n'/total"  // Modified for slashN option
    local percentage "%"  // Default percentage label

    // Handle row percentage display for categorical variables
    if "`catrowperc'" != "" {
        local percentage2 `"`percentage'"'
        local percentage2 "column `percentage'"  // Column percentage label

        // Format footnote based on options
        if "`percent_n'" == "percent_n" & "`percent'"=="" local percfootnote2 "`percentage2' (`n')"
        if "`percent_n'" != "percent_n" & "`percent'"=="" local percfootnote2 "`n' (`percentage2')"
        if "`percent'"=="percent" local percfootnote2 "`percentage2'"

        local percentage "row `percentage'"  // Row percentage label
    }

    // Standard format for percentage display
    if "`percent_n'" == "percent_n" & "`percent'"=="" local percfootnote "`percentage' (`n')"
    if "`percent_n'" != "percent_n" & "`percent'"=="" local percfootnote "`n' (`percentage')"
    if "`percent'"=="percent" local percfootnote "`percentage'"

    // Use percfootnote as default for percfootnote2 if not set
    if `"`percfootnote2'"' == "" local percfootnote2 "`percfootnote'"

**# Data Preparation

    /* Save by-variable label before any preserve (for methods paragraph) */
    local _bylab ""
    if "`by'" != "" {
        local _bylab : variable label `by'
        if "`_bylab'" == "" local _bylab "`by'"
    }

    /* Mark observations to include in analysis before sample-dependent validation */
    marksample touse, novarlist  // Creates indicator variable for observations that satisfy if/in conditions
    if `has_wt' markout `touse' `wt'  // Exclude observations with missing weights

    /* Validate wt() only within the analysis sample */
    if `has_wt' {
        quietly count if `touse' & `wt' < 0
        if r(N) > 0 {
            display as error "wt() variable must be non-negative"
            error 498
        }
        quietly replace `touse' = 0 if `touse' & `wt' <= 0
    }

    /* Validate that observations remain after if/in conditions */
    quietly count if `touse'
    if r(N) == 0 {
        display as error "no observations"
        error 2000
    }

    /* Stage the analytical table in frames; no intermediate .dta files. */
    tempname _result_frame _wtc_crude_table
    local _caller_frame = c(frame)

    /* Initialize row order counter */
    local sortorder=1  // Counter to maintain the order of variables in the final table

    /* Create numeric group variable */
    tempvar groupnum  // Temporary variable for numeric group codes
    if "`by'"=="" {
        gen byte `groupnum'=1  // Create single placeholder group if no by() variable
        local total ""         // No total column needed
    }
    else {
        // Convert string by() variable to numeric if needed
        capture confirm numeric variable `by'
        if !_rc qui clonevar `groupnum'=`by'  // If by() is already numeric
        else qui encode `by', gen(`groupnum')  // If by() is string, encode to numeric
        // Validate non-integer / non-negative values BEFORE recast long, force,
        // because that recast silently truncates non-integer values.
        qui levelsof `groupnum' if `touse', local(_pre_levels)
        foreach _pl of local _pre_levels {
            capture confirm integer number `_pl'
            if _rc!=0 {
                display as error "by() variable must be either (i) string, or (ii) numeric and contain only non-negative integers, whether or not a value label is attached"
                error 498
            }
        }
        // Ensure long storage so total sentinel value is exact
        qui recast long `groupnum', force
    }

    /* Validate the grouping variable */
    qui su `groupnum' if `touse', meanonly
    // Check that grouping variable values are non-negative
    if `r(min)' < 0 {
        display as error "by() variable must be either (i) string, or (ii) numeric and contain only non-negative integers, whether or not a value label is attached"
        error 498
    }

    /* Sentinel value for total column (replaces hardcoded 919) */
    local _total_code = c(maxlong)

    // Check if grouping variable contains the reserved sentinel value (used for totals)
    qui count if `groupnum' == `_total_code' & `touse'
    if `r(N)' > 0 {
        display as error "by() variable not allowed to take the value `_total_code' due to internal coding. Please recode to any other non-negative integer."
        error 498
    }

    // Get unique values of the grouping variable
    qui levelsof `groupnum' if `touse', local(levels)
    local _group_levels "`levels'"  // Save group levels for wtcompare merge

    /* Check that all group values are integers (re-check after recast) */
    foreach l of local levels {
        capture confirm integer number `l'
        if _rc!=0 {
            display as error "by() variable must be either (i) string, or (ii) numeric and contain only non-negative integers, whether or not a value label is attached"
            error 498
        }
    }

    /* Determine number of groups and validate */
    local groupcount: word count `levels'  // Count number of unique groups
    // Check that by() has at least 2 groups if specified
    if `groupcount'<2 & "`by'"!="" {
        display as error "by() variable must have at least 2 levels"
        error 498
    }

    /* Store group level values for SMD comparisons */
    tokenize `levels'
    local level1 `1'
    local level2 `2'
    local level3 `3'

    * SMD >2 groups warning (R3)
    if `has_smd' & `groupcount' > 2 {
        local _l1lab : label (`groupnum') `level1'
        local _l2lab : label (`groupnum') `level2'
        display as text "{bf:Note:} SMD computed for first two groups only (`_l1lab' vs `_l2lab')"
    }

    /* Create placeholder group variable if not specified */
    if "`by'"=="" local group `groupnum'

    /* wtcompare: two-pass loop setup */
    if `has_wtcompare' {
        local _wtc_passes "crude weighted"
    }
    else {
        local _wtc_passes "single"
    }
    local _wtc_save_sortorder = `sortorder'
    local _wtc_save_has_wt = `has_wt'
    local _wtc_save_has_smd = `has_smd'

**# Fast Aggregation
    local _fast_weight ""
    if "`weight'" != "" local _fast_weight "[`weight'`exp']"

    local _fast_common_opts `"replace stub(`groupnum') totalcode(`_total_code')"'
    if "`total'" != "" local _fast_common_opts `"`_fast_common_opts' total(`total')"'
    if "`missing'" != "" local _fast_common_opts `"`_fast_common_opts' missing"'
    if "`missingsummary'" != "" local _fast_common_opts `"`_fast_common_opts' missingsummary"'
    if "`smallcells'" != "" local _fast_common_opts `"`_fast_common_opts' smallcells(`smallcells')"'
    if "`percent'" != "" local _fast_common_opts `"`_fast_common_opts' percent"'
    if "`percent_n'" != "" local _fast_common_opts `"`_fast_common_opts' percent_n"'
    if "`slashN'" != "" local _fast_common_opts `"`_fast_common_opts' slashN"'
    if "`catrowperc'" != "" local _fast_common_opts `"`_fast_common_opts' catrowperc"'
    if "`varlabplus'" != "" local _fast_common_opts `"`_fast_common_opts' varlabplus"'
    if "`spacelowpercent'" == "" local _fast_common_opts `"`_fast_common_opts' nospacelowpercent"'
    if "`extraspace'" != "" local _fast_common_opts `"`_fast_common_opts' extraspace"'
    if `"`format'"' != "" local _fast_common_opts `"`_fast_common_opts' format(`"`format'"')"'
    if `"`percformat'"' != "" local _fast_common_opts `"`_fast_common_opts' percformat(`"`percformat'"')"'
    if `"`nformat'"' != "" local _fast_common_opts `"`_fast_common_opts' nformat(`"`nformat'"')"'
    if `"`iqrmiddle'"' != "" local _fast_common_opts `"`_fast_common_opts' iqrmiddle(`iqrmiddle')"'
    if `"`sdleft'"' != "" local _fast_common_opts `"`_fast_common_opts' sdleft(`sdleft')"'
    if `"`sdright'"' != "" local _fast_common_opts `"`_fast_common_opts' sdright(`sdright')"'
    if `"`gsdleft'"' != "" local _fast_common_opts `"`_fast_common_opts' gsdleft(`gsdleft')"'
    if `"`gsdright'"' != "" local _fast_common_opts `"`_fast_common_opts' gsdright(`gsdright')"'
    if `"`percsign'"' != "" local _fast_common_opts `"`_fast_common_opts' percsign(`percsign')"'

    local _fast_analysis_opts ""
    if "`smd'" != "" local _fast_analysis_opts `"`_fast_analysis_opts' smd"'
    if "`test'" != "" local _fast_analysis_opts `"`_fast_analysis_opts' test"'
    if "`statistic'" != "" local _fast_analysis_opts `"`_fast_analysis_opts' statistic"'
    if "`nopvalue'" != "" local _fast_analysis_opts `"`_fast_analysis_opts' nopvalue"'

    * Progress dots (opt-in): one dot per analysis variable about to be
    * processed. Help documents this; it was declared but unwired before.
    if "`dots'" != "" {
        local _ndelim = length(`"`vars'"') - length(subinstr(`"`vars'"', "\", "", .))
        local _nspec = `_ndelim' + 1
        display as text "Processing `_nspec' variable(s): " _continue
        forvalues _d = 1/`_nspec' {
            display as text "." _continue
        }
        display as text ""
    }

    if !`has_wtcompare' {
        local _fast_single_opts `"`_fast_common_opts' `_fast_analysis_opts'"'
        if `has_wt' local _fast_single_opts `"`_fast_single_opts' wt(`wt')"'
        _desctab_collect `_fast_weight' if `touse', ///
            by(`groupnum') vars(`vars') frame(`_result_frame') ///
            `_fast_single_opts'

        local _processed_varlist = strtrim("`r(varlist)'")
        local _resolved_has_bin = r(has_bin)
        local _resolved_has_cat = r(has_cat)
        local _resolved_has_contn = r(has_contn)
        local _resolved_has_contln = r(has_contln)
        local _resolved_has_conts = r(has_conts)
        local _used_ttest = r(used_ttest)
        local _used_anova = r(used_anova)
        local _used_wilcoxon = r(used_wilcoxon)
        local _used_kw = r(used_kwallis)
        local _used_chi2 = r(used_chi2)
        local _used_fisher = r(used_fisher)
    }
    else {
        _desctab_collect if `touse', ///
            by(`groupnum') vars(`vars') frame(`_wtc_crude_table') ///
            `_fast_common_opts' nopvalue

        local _fast_weighted_opts `"`_fast_common_opts' `_fast_analysis_opts' wt(`wt') wtcompare"'
        /* Recommended default: weighted columns are percent-only. wtn/percent_n
           (captured in _show_wtn) restore the weighted effective count. The
           crude pass above always keeps n (%). */
        if !`_show_wtn' local _fast_weighted_opts `"`_fast_weighted_opts' percent"'
        _desctab_collect if `touse', ///
            by(`groupnum') vars(`vars') frame(`_result_frame') ///
            `_fast_weighted_opts'

        local _processed_varlist = strtrim("`r(varlist)'")
        local _resolved_has_bin = r(has_bin)
        local _resolved_has_cat = r(has_cat)
        local _resolved_has_contn = r(has_contn)
        local _resolved_has_contln = r(has_contln)
        local _resolved_has_conts = r(has_conts)
        local _used_ttest = r(used_ttest)
        local _used_anova = r(used_anova)
        local _used_wilcoxon = r(used_wilcoxon)
        local _used_kw = r(used_kwallis)
        local _used_chi2 = r(used_chi2)
        local _used_fisher = r(used_fisher)

        frame `_wtc_crude_table' {
            capture confirm variable sort1
            if !_rc replace sort1 = sort1 + 1 if sort1 >= 2

            local _wtc_merge_levels `"`_group_levels'"'
            if "`total'" != "" local _wtc_merge_levels "`_wtc_merge_levels' `_total_code'"

            foreach lv of local _wtc_merge_levels {
                capture rename `groupnum'`lv' _cr_`lv'
                capture rename _columna_`lv' _cr_columna_`lv'
                capture rename _columnb_`lv' _cr_columnb_`lv'
                capture rename N_`lv' _cr_N_`lv'
                capture rename _scmask_`lv' _cr_scmask_`lv'
                capture rename _scmiss_`lv' _cr_scmiss_`lv'
            }
            capture rename _sc_derived _cr_sc_derived
            capture confirm variable sort2
            if _rc gen sort2 = 0
            keep sort1 sort2 _cr_*
            * Stata 17 frget omits underscore-prefixed variables and cannot
            * copy strL. Use a temporary legal prefix and bounded strings.
            rename _cr_* crtmp_*
            foreach _crv of varlist crtmp_* {
                capture confirm string variable `_crv'
                if !_rc recast str2045 `_crv'
            }
        }

        frame `_result_frame' {
            capture confirm variable sort2
            if _rc gen sort2 = 0
            frlink 1:1 sort1 sort2, frame(`_wtc_crude_table') generate(_wtc_link)
            frget crtmp_*, from(_wtc_link)
            rename crtmp_* _cr_*
            drop _wtc_link
        }
    }


**# Finalize Results Table

    /* Get value labels for group if available */
    local vallab: value label `groupnum'
    if "`vallab'"!="" {
        tempfile labels
        qui label save `vallab' using "`labels'"  // Save value labels to temporary file
    }

    /* Get levels of group variable for subsequent labelling */
    qui levelsof `groupnum' if `touse', local(levels)

    /* Load results table */
    preserve
    frame copy `_result_frame' `_caller_frame', replace
    if `_suppress_p' {
        capture drop p
        capture drop test
        capture drop statistic
    }
    if "`test'" != "test" capture drop test
    if "`statistic'" != "statistic" capture drop statistic
    if !`has_smd' capture drop smd_val

    /* Restore value labels if available */
    if "`vallab'" != "" quietly do "`labels'"

    /* Set up total column label */
    if "`total'" != "" {
        // If no value label exists, generate a unique tempname to avoid
        // mutating any user label of the same arbitrary name.
        if "`vallab'"=="" {
            tempname _t1tc_vallab
            local vallab `"`_t1tc_vallab'"'
        }
        label define `vallab' `_total_code' `"Total"', modify  // Add "Total" label for sentinel
        local levels "`levels' `_total_code'"  // Add sentinel to levels list
    }

    /* Apply labels to each group column */
    foreach level of local levels {
        if "`vallab'"=="" {
            // If no value label, use by-variable name and value
            lab var `groupnum'`level' "`by' = `level'"
            if `has_wtcompare' {
                capture lab var _cr_`level' "Crude `by' = `level'"
            }
        }
        else {
            // Use value label if available
            local lab: label `vallab' `level'
            lab var `groupnum'`level' "`lab'"
            if `has_wtcompare' {
                capture lab var _cr_`level' "Crude `lab'"
            }
        }
    }

    /* Calculate missing counts */
    foreach i of local levels {
        cap gen cat_not_top_row = .  // Create indicator for categorical variables
        qui recode N_`i' .=0 if cat_not_top_row !=1  // Use N=0 for categorical vars
        qui su N_`i'  // Get maximum sample size for this group
        local _max_n_`i' = r(max)
        qui gen m_`i' = `_max_n_`i'' - N_`i'  // Calculate missing as max - observed
        label var m_`i' "`i' m"  // Label missing count columns
    }

    /* Add missing data summary rows when missingsummary specified */
    if "`missingsummary'" != "" {
        local _nobs_before = _N
        forvalues _obs = 1/`_nobs_before' {
            local _fval = factor[`_obs']
            if "`_fval'" == " " | "`_fval'" == "" | "`_fval'" == "N" | "`_fval'" == "Effective sample size" continue
            * Check if any group has missing values for this variable
            local _any_miss 0
            foreach _lv of local levels {
                local _mval = m_`_lv'[`_obs']
                if !missing(`_mval') & `_mval' > 0 local _any_miss 1
            }
            if `_any_miss' {
                local _new = _N + 1
                qui set obs `_new'
                qui replace factor = "   Missing" in `_new'
                qui replace factor_sep = factor_sep[`_obs'] in `_new'
                capture confirm variable sort1
                if !_rc replace sort1 = sort1[`_obs'] in `_new'
                capture confirm variable sort2
                * Extended missing sorts after both numbered category levels
                * and the plain missing sort key used by continuous rows.
                if !_rc replace sort2 = .a in `_new'
                foreach _lv of local levels {
                    local _mval = m_`_lv'[`_obs']
                    if !missing(`_mval') & `_mval' > 0 {
                        local _sc_mcode 0
                        if "`smallcells'" != "" local _sc_mcode = _scmiss_`_lv'[`_obs']
                        if `_sc_mcode' > 0 {
                            _tabtools_smallcells_render, value(`_mval') mask(`_sc_mcode') ///
                                smallcells(`smallcells') format(`nformat')
                            local _mstr `"`r(display)'"'
                        }
                        else {
                            local _mpct = string(`_mval' / `_max_n_`_lv'' * 100, "`percformat'")
                            local _mstr = string(`_mval', "`nformat'") + " (" + "`_mpct'" + "`percsign'" + ")"
                        }
                        qui replace `groupnum'`_lv' = "`_mstr'" in `_new'
                        if "`smallcells'" != "" qui replace _scmask_`_lv' = `_sc_mcode' in `_new'
                    }
                    else {
                        qui replace `groupnum'`_lv' = "0" in `_new'
                    }

                    if `has_wtcompare' {
                        local _cr_mcode 0
                        if "`smallcells'" != "" local _cr_mcode = _cr_scmiss_`_lv'[`_obs']
                        if !missing(`_mval') & `_mval' > 0 & `_cr_mcode' > 0 {
                            _tabtools_smallcells_render, value(`_mval') mask(`_cr_mcode') ///
                                smallcells(`smallcells') format(`nformat')
                            qui replace _cr_`_lv' = `"`r(display)'"' in `_new'
                        }
                        else if !missing(`_mval') & `_mval' > 0 {
                            local _mpct = string(`_mval' / `_max_n_`_lv'' * 100, "`percformat'")
                            local _mstr = string(`_mval', "`nformat'") + " (" + "`_mpct'" + "`percsign'" + ")"
                            qui replace _cr_`_lv' = "`_mstr'" in `_new'
                        }
                        else qui replace _cr_`_lv' = "0" in `_new'
                        if "`smallcells'" != "" qui replace _cr_scmask_`_lv' = `_cr_mcode' in `_new'
                    }
                }
            }
        }
    }

    /* Apply variable labels */
    lab var factor "Factor "
    capture lab var level "Level"
    capture lab var test "Test"
    capture lab var statistic "Statistic"
    if `groupcount'==1 lab var `groupnum'1 "Total"  // Simplify single group label
    capture lab var _columna_`_total_code' "T _columna_"  // Label total column components
    capture lab var _columnb_`_total_code' "T _columnb_"
    capture lab var N_`_total_code' "T N_"
    capture lab var m_`_total_code' "T m_"

    tempvar _sc_anyderived
    if "`smallcells'" != "" {
        quietly gen byte `_sc_anyderived' = _sc_derived == 1
        if `has_wtcompare' quietly replace `_sc_anyderived' = 1 if _cr_sc_derived == 1
        capture confirm variable p
        if !_rc quietly replace p = .d if `_sc_anyderived'
        capture confirm variable smd_val
        if !_rc quietly replace smd_val = .d if `_sc_anyderived'
        capture confirm variable test
        if !_rc quietly replace test = "Suppressed" if `_sc_anyderived'
        capture confirm variable statistic
        if !_rc quietly replace statistic = "Suppressed" if `_sc_anyderived'
    }

    /* Format p-values (skipped when wt() or nopvalue specified) */
    if `groupcount'>1 & !`_suppress_p' {
        cap gen p = .  // Create p-value variable if it doesn't exist

        // Format p-values according to their magnitude and specified decimal places
        qui gen pvalue=string(p, "%`=`highpdp'+2'.`highpdp'f") if !missing(p)  // Standard format for high p-values
        qui replace pvalue=string(p, "%`=`pdp'+2'.`pdp'f") if p<0.10  // More decimal places for low p-values

        // Preserve direction when rounding would otherwise understate p.
        local pmax = 1 - 10^(-`highpdp')
        qui replace pvalue=">" + string(`pmax', "%`=`highpdp'+2'.`highpdp'f") ///
            if p>`pmax' & p<1 & !missing(p)

        // Handle very small p-values
        local pmin=10^-`pdp'  // Minimum p-value to show numerically
        qui replace pvalue="<" + string(`pmin', "%`=`pdp'+2'.`pdp'f") if p<`pmin'  // Show as <0.001 etc.

        lab var pvalue "p-value"  // Label p-value column
        if "`smallcells'" != "" quietly replace pvalue = "Suppressed" if `_sc_anyderived'
    }

    /* Format SMD column if present */
    if `has_smd' {
        capture confirm variable smd_val
        if !_rc {
            qui gen smd_str = string(abs(smd_val), "%5.3f") if !missing(smd_val)
            if "`smallcells'" != "" quietly replace smd_str = "Suppressed" if `_sc_anyderived'
            lab var smd_str "SMD"
        }
    }

    /* Create a header row with variable labels */
    qui count
    local newN=r(N) + 1
    qui set obs `newN'  // Add new row for headers
    qui desc, varlist
    foreach var of varlist `r(varlist)' {
        // Add variable label as header for each column
        if "`var'" != "level" {
            capture confirm string variable `var'
            if !_rc qui replace `var'="`: var lab `var''" in `newN'
        }
    }
    qui replace sort1=0 in `newN'  // Set sort order to ensure header is first

    /* Sort rows and drop unneeded variables */
    sort sort*  // Sort by primary and secondary sort variables

    drop sort*  // Remove sort variables
    * Preserve raw numeric p-values for boldp/highlight formatting. Use tempvars
    * so a user column literally named _p_raw/_smd_raw can never be clobbered.
    tempvar p_raw smd_raw
    capture confirm variable p
    if !_rc qui gen double `p_raw' = p
    capture drop p  // Drop raw p-value variable
    * Preserve raw SMD values for conditional formatting (O2)
    capture confirm variable smd_val
    if !_rc qui gen double `smd_raw' = abs(smd_val)
    capture drop smd_val  // Drop raw SMD values

    /* Left-justify strings except p-value */
    qui desc, varlist
    foreach var in `r(varlist)' {
        format `var' %-`=substr("`: format `var''", 2, .)'  // Set left alignment
    }
    capture format %`=`pdp'+3's _columna_*  // Format column components

    /* Reorganize columns for display */
    order N_*, seq  // Group N columns together
    order `groupnum'*, seq  // Group data columns together
    order factor `groupnum'* N_* m_*  // Set main column order
    capture order factor `groupnum'* pvalue  // Add p-value if exists
    capture order test, before(pvalue)  // Add test column if exists
    capture order statistic, before(pvalue)  // Add statistic column if exists
    * Add SMD column after pvalue
    capture order smd_str, after(pvalue)
    capture order level, after(factor)  // Add level column for categorical variables

    /* Rename placeholder group variable or add group prefix */
    if `groupcount'==1 rename `groupnum'1 Total  // Simplify single group name
    else rename `groupnum'* `by'*  // Add by-variable name prefix to group columns

    if "`by'" !="" rename `by'* `by'_*  // Add underscore for clarity
    capture rename *_`_total_code' *_T  // Rename total columns to _T
    capture rename _*_`_total_code' _*_T  // Rename total column components

    /* wtcompare: rename crude columns and reorder for side-by-side display */
    if `has_wtcompare' {
        * Build list of column suffixes (group levels, already renamed for total)
        * levels may include the total sentinel which was renamed to T
        local _wtc_suffixes ""
        foreach lv of local levels {
            if "`lv'" == "`_total_code'" {
                local _wtc_suffixes "`_wtc_suffixes' T"
            }
            else {
                local _wtc_suffixes `"`_wtc_suffixes' `lv'"'
            }
        }

        * Rename weighted columns: by_X -> Wt_X
        * Rename crude columns: _cr_X -> Cr_X
        foreach sfx of local _wtc_suffixes {
            * Get label for this column
            if "`sfx'" == "T" {
                local _wtc_lab "Total"
            }
            else if "`vallab'" != "" {
                local _wtc_lab : label `vallab' `sfx'
            }
            else {
                local _wtc_lab `"`by' = `sfx'"'
            }

            * Rename weighted group column and set label
            capture rename `by'_`sfx' Wt_`sfx'
            capture lab var Wt_`sfx' "Weighted `_wtc_lab'"

            * Rename crude group column (already renamed _T by standard rename)
            capture rename _cr_`sfx' Cr_`sfx'
            capture lab var Cr_`sfx' "Crude `_wtc_lab'"

            * Drop crude helper columns (not needed for display)
            capture drop _cr_columna_`sfx'
            capture drop _cr_columnb_`sfx'
            capture drop _cr_N_`sfx'
            * Also try original sentinel names (in case standard rename missed them)
            if "`sfx'" == "T" {
                capture drop _cr_columna_`_total_code'
                capture drop _cr_columnb_`_total_code'
                capture drop _cr_N_`_total_code'
            }
        }

        * Reorder: factor, Crude columns, Weighted columns, SMD
        capture order factor Cr_* Wt_*
        capture confirm variable smd_str
        if !_rc order smd_str, last

        * Update header row values to match new labels
        foreach sfx of local _wtc_suffixes {
            capture confirm string variable Cr_`sfx'
            if !_rc qui replace Cr_`sfx' = "`: var lab Cr_`sfx''" if _n == 1
            capture confirm string variable Wt_`sfx'
            if !_rc qui replace Wt_`sfx' = "`: var lab Wt_`sfx''" if _n == 1
        }
    }

    /* Position total column if requested */
    if "`total'" == "before" {
        tokenize `levels'
        local first `1'
        if `has_wtcompare' {
            cap order Cr_T, before(Cr_`first')  // Move crude total before first crude group
            cap order Wt_T, before(Wt_`first')  // Move weighted total before first weighted group
        }
        else {
            cap order `by'_T, before(`by'_`first')  // Move total before first group
        }
        order N_T, before(N_`first')  // Reorder N columns
        order m_T, before(m_`first')  // Reorder missing columns
        order _columna_T _columnb_T, before(_columna_`first')  // Reorder column components
    }

    if "`total'" == "after" {
        tokenize `levels'
        local first `1'
        cap order `by'_T, before(pvalue)  // Move total before p-value
        cap order N_T, before(m_`first')  // Reorder N columns
        cap order m_T, before(_columna_`first')  // Reorder missing columns
        cap order _columna_T _columnb_T, last  // Move column components to end
    }

    /* Snapshot the public suppression map before internal mask variables are
       discarded. Counts refer to display cells, so a shared logical margin is
       counted once for each cell in which the user can see its marker. */
    tempname _sc_return
    local _sc_nprimary 0
    local _sc_nsecondary 0
    local _sc_nderived 0
    if "`smallcells'" != "" {
        local _sc_public_vars ""
        local _sc_mask_vars ""
        local _sc_suffixes ""
        foreach _lv of local levels {
            if "`_lv'" == "`_total_code'" local _sc_sfx "T"
            else local _sc_sfx "`_lv'"
            local _sc_suffixes "`_sc_suffixes' `_sc_sfx'"
        }

        if `has_wtcompare' {
            foreach _sc_sfx of local _sc_suffixes {
                capture confirm variable Cr_`_sc_sfx'
                if !_rc {
                    local _sc_public_vars "`_sc_public_vars' Cr_`_sc_sfx'"
                    local _sc_mask_vars "`_sc_mask_vars' _cr_scmask_`_sc_sfx'"
                }
                capture confirm variable Wt_`_sc_sfx'
                if !_rc {
                    local _sc_public_vars "`_sc_public_vars' Wt_`_sc_sfx'"
                    local _sc_mask_vars "`_sc_mask_vars' _scmask_`_sc_sfx'"
                }
            }
        }
        else if "`by'" == "" {
            local _sc_first : word 1 of `_sc_suffixes'
            local _sc_public_vars "Total"
            local _sc_mask_vars "_scmask_`_sc_first'"
        }
        else {
            foreach _sc_sfx of local _sc_suffixes {
                local _sc_public_vars "`_sc_public_vars' `by'_`_sc_sfx'"
                local _sc_mask_vars "`_sc_mask_vars' _scmask_`_sc_sfx'"
            }
        }

        local _sc_stat_vars ""
        foreach _sc_stat in pvalue test statistic smd_str {
            capture confirm variable `_sc_stat'
            if !_rc local _sc_stat_vars "`_sc_stat_vars' `_sc_stat'"
        }
        local _sc_all_vars "`_sc_public_vars' `_sc_stat_vars'"
        local _sc_ncols : word count `_sc_all_vars'
        matrix `_sc_return' = J(`=_N', `_sc_ncols', 0)

        local _sc_col 0
        local _sc_nmasks : word count `_sc_mask_vars'
        forvalues _sc_j = 1/`_sc_nmasks' {
            local ++_sc_col
            local _sc_mv : word `_sc_j' of `_sc_mask_vars'
            forvalues _sc_obs = 1/`=_N' {
                local _sc_code = `_sc_mv'[`_sc_obs']
                if missing(`_sc_code') local _sc_code 0
                matrix `_sc_return'[`_sc_obs', `_sc_col'] = `_sc_code'
                if `_sc_code' == 1 local ++_sc_nprimary
                else if `_sc_code' == 2 local ++_sc_nsecondary
                else if `_sc_code' == 3 local ++_sc_nderived
            }
        }
        foreach _sc_stat of local _sc_stat_vars {
            local ++_sc_col
            forvalues _sc_obs = 1/`=_N' {
                local _sc_code 0
                if `_sc_anyderived'[`_sc_obs'] == 1 local _sc_code 3
                matrix `_sc_return'[`_sc_obs', `_sc_col'] = `_sc_code'
                if `_sc_code' == 3 local ++_sc_nderived
            }
        }
        matrix colnames `_sc_return' = `_sc_all_vars'
    }

    /* Format N and missing counts */
    format `nformat' N_* m_*  // Apply count format to N and m columns
    cap drop cat_not_top_row  // Remove helper variable
    qui replace factor = "" if factor == "N"  // Clean up factor labels
    qui replace factor = " " if factor == "Factor "  // Clean up header

    /* Add percentages to header if requested */
    if "`headerperc'" != "" {
        qui {
            // Build list of visible sample-size columns after all renaming.
            local hperc_cols ""
            if `has_wtcompare' {
                foreach _pfx in Cr Wt {
                    foreach gl of local levels {
                        if "`gl'" == "`_total_code'" local _hgl "T"
                        else local _hgl "`gl'"
                        capture confirm variable `_pfx'_`_hgl'
                        if !_rc local hperc_cols "`hperc_cols' `_pfx'_`_hgl'"
                    }
                }
            }
            else if "`by'" == "" {
                capture confirm variable Total
                if !_rc local hperc_cols "Total"
            }
            else {
                foreach gl of local levels {
                    if "`gl'" == "`_total_code'" local _hgl "T"
                    else local _hgl "`gl'"
                    capture confirm variable `by'_`_hgl'
                    if !_rc local hperc_cols "`hperc_cols' `by'_`_hgl'"
                }
            }

            if "`hperc_cols'" == "" {
                noisily display as error "headerperc could not identify sample-size columns"
                exit 111
            }

            // Process each sample-size column and build numeric scratch columns.
            // Use a unique prefix (__hp_) for the scratch names so we never
            // collide with user-level group columns like by_12 produced by a
            // by-variable level == 12 — the prior `<col>2` suffix scheme could
            // alias real data columns.
            local hperc_scratch ""
            local hperc_cr_scratch ""
            local hperc_wt_scratch ""
            local hperc_main_scratch ""
            local _hpn = 0
            foreach _hcol of local hperc_cols {
                local ++_hpn
                tempvar _hp_var
                replace `_hcol' = subinstr(`_hcol', "N=", "", .)
                gen double `_hp_var' = real(subinstr(`_hcol', ",", "", .)) if inlist(_n, 2)
                local hperc_scratch `"`hperc_scratch' `_hp_var'"'
                local hperc_scratch_for_`_hcol' `"`_hp_var'"'
                if `has_wtcompare' & substr("`_hcol'", 1, 3) == "Cr_" {
                    local hperc_cr_scratch `"`hperc_cr_scratch' `_hp_var'"'
                }
                else if `has_wtcompare' & substr("`_hcol'", 1, 3) == "Wt_" {
                    local hperc_wt_scratch `"`hperc_wt_scratch' `_hp_var'"'
                }
                else {
                    local hperc_main_scratch `"`hperc_main_scratch' `_hp_var'"'
                }
            }

            // Build denominator variables from total columns when present,
            // otherwise sum across the scratch columns we just built. The Cr_T
            // / Wt_T / by_T total columns were renamed to Cr_T / Wt_T / by_T
            // already; their scratch versions live under the __hp_ prefix.
            tempvar hperc_den hperc_crden hperc_wtden hperc_nmiss hperc_crnmiss hperc_wtnmiss
            if `has_wtcompare' {
                local _cr_tot_scratch ""
                local _wt_tot_scratch ""
                foreach _hcol of local hperc_cols {
                    if "`_hcol'" == "Cr_T" local _cr_tot_scratch "`hperc_scratch_for_`_hcol''"
                    if "`_hcol'" == "Wt_T" local _wt_tot_scratch "`hperc_scratch_for_`_hcol''"
                }
                if "`_cr_tot_scratch'" != "" gen double `hperc_crden' = `_cr_tot_scratch' if inlist(_n, 2)
                else {
                    egen `hperc_crden' = rowtotal(`hperc_cr_scratch') if inlist(_n, 2)
                    egen `hperc_crnmiss' = rowmiss(`hperc_cr_scratch') if inlist(_n, 2)
                    replace `hperc_crden' = . if `hperc_crnmiss' > 0
                }

                if "`_wt_tot_scratch'" != "" gen double `hperc_wtden' = `_wt_tot_scratch' if inlist(_n, 2)
                else {
                    egen `hperc_wtden' = rowtotal(`hperc_wt_scratch') if inlist(_n, 2)
                    egen `hperc_wtnmiss' = rowmiss(`hperc_wt_scratch') if inlist(_n, 2)
                    replace `hperc_wtden' = . if `hperc_wtnmiss' > 0
                }
            }
            else if "`by'" == "" {
                local _tot_scratch `"`hperc_scratch_for_Total'"'
                if "`_tot_scratch'" != "" gen double `hperc_den' = `_tot_scratch' if inlist(_n, 2)
                else {
                    egen `hperc_den' = rowtotal(`hperc_main_scratch') if inlist(_n, 2)
                    egen `hperc_nmiss' = rowmiss(`hperc_main_scratch') if inlist(_n, 2)
                    replace `hperc_den' = . if `hperc_nmiss' > 0
                }
            }
            else {
                local _by_t "`by'_T"
                local _tot_scratch `"`hperc_scratch_for_`_by_t''"'
                if "`_tot_scratch'" != "" gen double `hperc_den' = `_tot_scratch' if inlist(_n, 2)
                else {
                    egen `hperc_den' = rowtotal(`hperc_main_scratch') if inlist(_n, 2)
                    egen `hperc_nmiss' = rowmiss(`hperc_main_scratch') if inlist(_n, 2)
                    replace `hperc_den' = . if `hperc_nmiss' > 0
                }
            }

            // Add percentage of total to each sample-size label.
            foreach _hcol of local hperc_cols {
                local _hden `"`hperc_den'"'
                if `has_wtcompare' & substr("`_hcol'", 1, 3) == "Cr_" local _hden "`hperc_crden'"
                if `has_wtcompare' & substr("`_hcol'", 1, 3) == "Wt_" local _hden "`hperc_wtden'"
                local _hp_var `"`hperc_scratch_for_`_hcol''"'
                replace `_hcol' = `_hcol' + " " + "(" + ///
                    string(round(`_hp_var' / `_hden', 0.001) * 100, "%9.1f") + ///
                    "`percsign'" + ")" if inlist(_n, 2) & `_hden' > 0 & !missing(`_hp_var')
            }

            foreach _htmp of local hperc_scratch {
                capture drop `_htmp'
            }
            capture drop `hperc_den'
            capture drop `hperc_crden'
            capture drop `hperc_wtden'
            capture drop `hperc_nmiss'
            capture drop `hperc_crnmiss'
            capture drop `hperc_wtnmiss'

        }
    }

    /* Create header description with proper Oxford comma usage */
    qui {
        /* Build header parts */
        local header_parts = ""
        local part_count = 0

        /* Add categorical description */
        if `_resolved_has_cat' {
            if "`percent'" == "percent" {
                if "`catrowperc'" != "" local header_parts = "Row %"
                else local header_parts = "Column %"
            }
            else if "`catrowperc'" != "" {
                if "`percent_n'" == "percent_n" {
                    local header_parts = "Row % (No.)"
                }
                else {
                    local header_parts = "No. (Row %)"
                }
            }
            else {
                if "`percent_n'" == "percent_n" {
                    local header_parts = "Column % (No.)"
                }
                else {
                    local header_parts = "No. (Column %)"
                }
            }
            local part_count = 1
        }

        /* Add binary description if different from categorical */
        if `_resolved_has_bin' & (!`_resolved_has_cat' | "`catrowperc'" != "") {
            if `part_count' > 0 local header_parts = "`header_parts' or "

            if "`percent'" == "percent" {
                local header_parts = "`header_parts'Column %"
            }
            else if "`percent_n'" == "percent_n" {
                local header_parts = "`header_parts'Column % (No.)"
            }
            else {
                local header_parts = "`header_parts'No. (Column %)"
            }
            local part_count = `part_count' + 1
        }

        /* Build continuous measure descriptions */
        local cont_parts = ""
        local cont_count = 0

        /* Clean up the iqrmiddle value for display */
        local iqrmiddle_clean = substr(`"`iqrmiddle'"', 2, length(`"`iqrmiddle'"') - 2)

        /* Describe the mean/SD cell using the ACTIVE sdleft()/sdright()
           notation. The header used to be hardcoded "Mean (SD)" while the
           default notation renders 58.3+/-13.4, so the column caption
           contradicted every cell beneath it. Defaults give "Mean+/-SD";
           sdleft(" (") sdright(")") gives "Mean (SD)". */
        local sdleft_clean = substr(`"`sdleft'"', 2, length(`"`sdleft'"') - 2)
        local sdright_clean = substr(`"`sdright'"', 2, length(`"`sdright'"') - 2)
        local meansd_label `"Mean`sdleft_clean'SD`sdright_clean'"'

        if `_resolved_has_contn' {
            local cont_parts `"`meansd_label'"'
            local cont_count = 1
        }

        if `_resolved_has_contln' {
            if `cont_count' > 0 {
                if `cont_count' == 1 {
                    local cont_parts = "`cont_parts' or "
                }
                else {
                    local cont_parts = "`cont_parts', "
                }
            }
            local cont_parts = "`cont_parts'Geometric mean (×/GSD)"
            local cont_count = `cont_count' + 1
        }

        if `_resolved_has_conts' {
            if `cont_count' > 0 {
                if `cont_count' == 1 {
                    local cont_parts = "`cont_parts' or "
                }
                else {
                    /* Add Oxford comma for 3+ items */
                    local cont_parts = "`cont_parts', "
                    if `cont_count' > 1 {
                        local cont_parts = "`cont_parts'and "
                    }
                }
            }
            local cont_parts = "`cont_parts'Median (Q1`iqrmiddle_clean'Q3)"
            local cont_count = `cont_count' + 1
        }

        /* Combine categorical and continuous parts with proper grammar */
        if `cont_count' > 0 {
            if `part_count' > 0 {
                if `part_count' + `cont_count' > 2 {
                    local header_parts = "`header_parts', and `cont_parts'"  // Use comma and 'and' for 3+ parts
                }
                else {
                    local header_parts = "`header_parts' or `cont_parts'"  // Use 'or' for 2 parts
                }
            }
            else {
                local header_parts = "`cont_parts'"  // Just use continuous parts
            }
        }

        /* Apply header description */
        replace factor = `"`header_parts'"' if _n == 2
    }
    local _descriptor_row_text `"`header_parts'"'

    /* Display the table */
    qui ds factor_sep _* N_* m_*, not
    list `r(varlist)', sepby(factor_sep) noobs noheader table  // Show table with separators between variables
    if "`smallcells'" != "" display as text "`_sc_note'"
    drop factor_sep  // Clean up

    /* Generate data description string */
    qui {
        // Check which variable types are present
        local ybin `_resolved_has_bin'  // Binary variables
        local ycat `_resolved_has_cat'  // Categorical variables
        if "`ycat'" == "1" | "`ybin'" == "1" local ycatbin "1"  // Flag if any categorical/binary

        local ycontn `_resolved_has_contn'  // Normal continuous
        local ycontln `_resolved_has_contln'  // Log-normal continuous
        local yconts `_resolved_has_conts'  // Skewed continuous

        /* Build description for continuous variables */
        if "`ycontn'" == "1" & "`ycontln'" == "1" & "`yconts'" == "1" {
            local ycont "`meanSD', `gmeanSD', and median (Q1, Q3)"
        }
        else if "`ycontn'" == "1" & "`ycontln'" == "1" & "`yconts'" != "1" {
            local ycont `"`meanSD' or `gmeanSD'"'
        }
        else if "`ycontn'" == "1" & "`ycontln'" != "1" & "`yconts'" == "1" {
            local ycont "`meanSD' or median (Q1, Q3)"
        }
        else if "`ycontn'" != "1" & "`ycontln'" == "1" & "`yconts'" == "1" {
            local ycont "`gmeanSD' or median (Q1, Q3)"
        }
        else if "`ycontn'" == "1" & "`ycontln'" != "1" & "`yconts'" != "1" {
            local ycont `"`meanSD'"'
        }
        else if "`ycontn'" != "1" & "`ycontln'" == "1" & "`yconts'" != "1" {
            local ycont `"`gmeanSD'"'
        }
        else if "`ycontn'" != "1" & "`ycontln'" != "1" & "`yconts'" == "1" {
            local ycont "median (Q1, Q3)"
        }

        /* Build complete description with both continuous and categorical */
        if "`ycont'" != "" & "`ycatbin'" !="" {
            local ymix "`ycont' for continuous measures, and `percfootnote' for categorical measures"
        }
        else if "`ycont'" != "" & "`ycatbin'" =="" {
            local ymix `"`ycont'"'
        }
        else if "`ycont'" == "" & "`ycatbin'" !="" {
            local ymix `"`percfootnote'"'
        }

        /* Add separate note for binary measures with row percentages */
        if "`catrowperc'" != "" & "`ycat'" == "1" & "`ybin'" == "1" {
            local ymix "`ymix' and `percfootnote2' for binary measures"
        }

        if `has_wtcompare' {
            local Dapa "Crude and weighted data are presented as `ymix'. P-values suppressed. SMD reflects weighted comparison."
        }
        else if `has_wt' {
            local Dapa "Weighted data are presented as `ymix'. P-values suppressed."
            if `has_smd' local Dapa "`Dapa' SMD reflects weighted comparison."
        }
        else if "`nopvalue'" == "nopvalue" {
            local Dapa "Data are presented as `ymix'. P-values suppressed."
        }
        else {
            local Dapa "Data are presented as `ymix'."
        }
        if `"`varlabplus'"' == "" {
            display "`Dapa'"
        }
        return local Dapa "`Dapa'"
        display " "

        /* Build extended methods paragraph (C5) */
        if "`by'" != "" & !`_suppress_p' {

            * Build test list
            local _test_list ""
            if `_used_ttest' local _test_list "independent t-test"
            if `_used_anova' {
                if "`_test_list'" != "" local _test_list "`_test_list', "
                local _test_list "`_test_list'one-way ANOVA"
            }
            if `_used_wilcoxon' {
                if "`_test_list'" != "" local _test_list "`_test_list', "
                local _test_list "`_test_list'Wilcoxon rank-sum test"
            }
            if `_used_kw' {
                if "`_test_list'" != "" local _test_list "`_test_list', "
                local _test_list "`_test_list'Kruskal-Wallis test"
            }
            if `_used_chi2' {
                if "`_test_list'" != "" local _test_list "`_test_list', "
                local _test_list "`_test_list'Pearson's chi-squared test"
            }
            if `_used_fisher' {
                if "`_test_list'" != "" local _test_list "`_test_list', "
                local _test_list "`_test_list'Fisher's exact test"
            }

            local _methods "Baseline characteristics were compared between groups defined by `_bylab'."
            local _methods `"`_methods' `Dapa'"'
            if "`_test_list'" != "" {
                local _methods "`_methods' P-values were calculated using `_test_list'."
            }
            local _methods "`_methods' A two-sided p-value < 0.05 was considered statistically significant."
            local _methods "`_methods' Analysis performed in Stata `c(stata_version)' (StataCorp, College Station, TX)."

            return local methods "`_methods'"
        }
    }

    /* Add extra space for alignment if requested */
    if `"`extraspace'"' != "" {
        // Add extra space before p-values for alignment
        qui cap replace pvalue=" " + pvalue if substr(pvalue,1,1) != "<"

    }

    /* Format N and missing count columns as strings */
    qui ds N_* m_*
    foreach v of varlist `r(varlist)' {
        // Convert numeric counts to formatted strings
        qui gen z`v' = string(`v', "`nformat'") if !missing(`v'), after(`v')
        qui drop `v'
        qui rename z`v' `v'
    }

    /* Set nice labels in row 1 for N_* and m_* */
    local levels "`levels' T"
    foreach l of local levels {
        // Copy group headers to N and m columns in the first row
        qui cap replace N_`l' = `by'_`l' if factor == " "
        qui cap replace m_`l' = `by'_`l' if factor == " "
        qui cap replace _columna_`l' = `by'_`l' if factor == " "
        qui cap replace _columnb_`l' = `by'_`l' if factor == " "
    }

    if `groupcount'==1 {
        // Format for single group - use string literal
        qui replace N_1 = "Total" if factor == " "
        qui replace m_1 = "Total" if factor == " "
        qui replace _columna_1 = "Total" if factor == " "
        qui replace _columnb_1 = "Total" if factor == " "
    }

    qui drop N_* m_* _columna_* _columnb_*  // Remove unused columns

**# Build r(table) return matrix
    * Build numeric matrix from p-values and SMD values for programmatic access
    tempname _rtable
    local _rt_nrows 0
    local _rt_rnames ""
    local _rt_ncols 0
    capture confirm variable `p_raw'
    local _has_praw = !_rc
    capture confirm variable `smd_raw'
    local _has_smdraw = !_rc
    if `_has_praw' | `_has_smdraw' {
        * Count data rows (skip descriptor/header rows and category sub-rows)
        qui count if factor != " " & factor != "" & factor != "N" & ///
            factor != "Effective sample size" & factor != `"`_descriptor_row_text'"'
        local _rt_nrows = r(N)
        if `_rt_nrows' > 0 & `_rt_nrows' <= 200 {
            local _rt_ncols = `_has_praw' + `_has_smdraw'
            matrix `_rtable' = J(`_rt_nrows', `_rt_ncols', .)
            local _rt_r = 0
            forvalues _obs = 1/`=_N' {
                local _fval = factor[`_obs']
                if "`_fval'" != " " & "`_fval'" != "" & "`_fval'" != "N" & ///
                    "`_fval'" != "Effective sample size" & "`_fval'" != `"`_descriptor_row_text'"' {
                    local _rt_r = `_rt_r' + 1
                    local _rt_c = 0
                    if `_has_praw' {
                        local _rt_c = `_rt_c' + 1
                        local _pval = `p_raw'[`_obs']
                        if `_pval' < . | `_pval' == .d ///
                            matrix `_rtable'[`_rt_r', `_rt_c'] = `_pval'
                    }
                    if `_has_smdraw' {
                        local _rt_c = `_rt_c' + 1
                        local _sval = `smd_raw'[`_obs']
                        if `_sval' < . | `_sval' == .d ///
                            matrix `_rtable'[`_rt_r', `_rt_c'] = `_sval'
                    }
                    * Clean variable name for row label
                    local _rname = subinstr("`_fval'", ".", "_", .)
                    local _rname = subinstr("`_rname'", " ", "_", .)
                    local _rname = subinstr("`_rname'", ",", "", .)
                    local _rname = substr("`_rname'", 1, 32)
                    if "`_rname'" == "" local _rname "row`_rt_r'"
                    local _rt_rnames `"`_rt_rnames' `_rname'"'
                }
            }
            local _rt_cnames ""
            if `_has_praw' local _rt_cnames "p_value"
            if `_has_smdraw' local _rt_cnames "`_rt_cnames' smd"
            capture matrix rownames `_rtable' = `_rt_rnames'
            capture matrix colnames `_rtable' = `_rt_cnames'
        }
    }

**# Export to Excel if Requested
    local _processed_varlist = strtrim("`_processed_varlist'")
    return local varlist "`_processed_varlist'"
    if `_rt_nrows' > 0 & `_rt_nrows' <= 200 {
        capture return matrix table = `_rtable'
    }

    * The finalized sink-neutral table now passes through one Stata 17
    * collection and the shared JSON renderer. The round trip is deliberately
    * lossless: row order, variable types, formats, and labels are restored
    * before disclosure characteristics or any output sink is populated.
    _desctab_collect_roundtrip

    if "`smallcells'" != "" {
        capture drop _scmask_* _scmiss_* _sc_derived
        capture drop _cr_scmask_* _cr_scmiss_* _cr_sc_derived
        capture drop `_sc_anyderived'
        char _dta[tabtools_smallcells] "`smallcells'"
        char _dta[tabtools_suppression_codes] "0 visible; 1 primary; 2 complementary; 3 derived"
        char _dta[tabtools_suppression_scope] "exact disclosure; single invocation; all sinks"
        return scalar smallcells = `smallcells'
        return scalar N_primary_suppressed = `_sc_nprimary'
        return scalar N_secondary_suppressed = `_sc_nsecondary'
        return scalar N_derived_suppressed = `_sc_nderived'
        return matrix suppression = `_sc_return'
    }

    local _xlsx_ok 0
    if "`excel'" != "" {
        * The Excel branch reshapes the table in place: it prepends a title row
        * and a title column and drops internal columns. csv(), markdown(), and
        * frame() run AFTER this branch, so without a snapshot the same call
        * produced a different CSV/Markdown table merely because xlsx() was
        * also requested. Snapshot the sink-neutral table here and reload it
        * once the workbook is written.
        tempfile _t1_sink_snapshot
        quietly save `"`_t1_sink_snapshot'"', replace
        quietly {
            /* Add ID for sorting and prepare for export */
            gen id = _n  // Row identifier
            count
            local count `=`r(N)'+1'
            set obs `count'  // Add a row for title
            replace id = 0 if id == .  // Set ID for title row
            sort id  // Sort with title first
            drop id  // Remove ID variable

            /* Add title row */
            gen title = ""  // Title column
            order title  // Make title the first column
            replace title = `"`title'"' if _n == 1  // Set title text

            /* Add p-value header */
            capture confirm string variable pvalue
            if !_rc {
                replace pvalue = "p-value" if _n == 2  // Label p-value column
                replace pvalue = "" if _n == 3  // Clear row 3
            }

			/* The header descriptor is built ONCE, before any sink runs (see
			   _descriptor_row_text above), and is reused verbatim here. The Excel
			   path used to REBUILD it with a different join (", " instead of
			   " or "), a hardcoded "Mean (SD)" that ignored sdleft()/sdright(),
			   and a binary branch that never incremented part_count -- so a
			   binary+continuous table wrote "No. (Column %)Mean (SD)" into row 2
			   while row 3 still carried the real descriptor. Both survived into
			   the workbook; only the B2:B3 merge hid the contradiction.
			   Inserting the title row moved the descriptor from row 2 to row 3,
			   so move it back to row 2 (the merge anchor) and clear row 3. */
			replace factor = `"`_descriptor_row_text'"' if _n == 2
			replace factor = "" if _n == 3

	            /* Export to Excel — exclude internal columns */
	            local _had_p_raw = 0
	            capture confirm variable `p_raw'
	            if !_rc {
	                local _had_p_raw = 1
	                mata: _p_raw_save = st_data(., "`p_raw'")
	                drop `p_raw'
	            }
	            local _had_smd_raw = 0
	            capture confirm variable `smd_raw'
	            if !_rc {
	                local _had_smd_raw = 1
	                mata: _smd_raw_save = st_data(., "`smd_raw'")
	                drop `smd_raw'
	            }
            * Safety: drop any surviving internal variables before export
            * (catrowperc + slashN can leave N_* or _uwn* columns)
	            capture drop N_*
	            capture drop _columna_*
	            capture drop _columnb_*
	            capture drop m_*
	            capture drop _uwn*
		            capture noisily _tabtools_xlsx_write using "`excel'", sheet("`sheet'") book(b)
		            local _xlsx_write_rc = _rc
		            if `_had_p_raw' {
		                gen double `p_raw' = .
		                mata: st_store(., "`p_raw'", _p_raw_save)
		                mata: mata drop _p_raw_save
		            }
		            if `_had_smd_raw' {
		                gen double `smd_raw' = .
		                mata: st_store(., "`smd_raw'", _smd_raw_save)
		                mata: mata drop _smd_raw_save
		            }
		            if `_xlsx_write_rc' {
			                local saved_rc = `_xlsx_write_rc'
			                capture mata: b.close_book()
			                local _xlsx_close_cleanup_rc = _rc
			                capture mata: mata drop b
			                local _xlsx_drop_cleanup_rc = _rc
			                noisily display as error "Failed to export to `excel'"
	                noisily display as error "Hint: ensure the xlsx file is not open in another application"
	                restore
	                exit `saved_rc'
	            }

**# Calculate column widths based on content length

			/* Calculate column widths based on content */
			gen factor_length = length(factor)
			egen max_factor_length = max(factor_length) if !inrange(_n,2,3)
			egen max_factor2_length = max(factor_length) if inrange(_n,2,3)
			sum max_factor_length, d
			local factorwidth = `=ceil(`r(max)'*0.85)+2'  // Factor column width based on content
			sum max_factor2_length, d
			local factor2width = `=ceil(`r(max)'*0.85)+2'  // Factor column width based on content
			if `factor2width' > `=`factorwidth'*2' local factorwidth = `=`factorwidth'+((`factor2width'-`factorwidth')/2.5)'

			/* Ensure reasonable min/max bounds */
			if `factorwidth' < 15 local factorwidth = 15  // Minimum width
			if `factorwidth' > 60 local factorwidth = 60  // Maximum width

			/* Calculate data column width */
			local datawidth = 0
			if `groupcount' == 1 {
				local _data_cols "Total"
			}
			else {
				local _data_cols ""
				if `has_wtcompare' {
					foreach var of varlist Cr_* Wt_* {
						local _data_cols `"`_data_cols' `var'"'
					}
				}
				else {
					foreach var of varlist `by'_* {
						local _data_cols `"`_data_cols' `var'"'
					}
				}
			}
			foreach var of local _data_cols {
				gen `var'_length = length(`var')
				egen `var'_max = max(`var'_length)
				sum `var'_max, d
				if `r(max)' > `datawidth' local datawidth = `r(max)'
			}
			local datawidth = `=ceil(`datawidth'*0.85)+2'  // Data column width with adjustment factor

			/* Ensure reasonable min/max bounds */
			if `datawidth' < 12 local datawidth = 12  // Minimum width
			if `datawidth' > 30 local datawidth = 30  // Maximum width

			/* Clean up temporary variables */
			cap drop *_length *_max

            /*****************************************************************
            * Build Excel column position references
            *****************************************************************/
			qui desc
			local num_cols = `r(k)'  // Number of columns
			* Exclude internal columns from column count (not exported to Excel)
			capture confirm variable `p_raw'
			if !_rc local num_cols = `num_cols' - 1
			capture confirm variable `smd_raw'
			if !_rc local num_cols = `num_cols' - 1
			qui count
			local num_rows = `r(N)'  // Number of rows

            /* Find column position of level and data */
            local level_pos = 0
            local i = 1
            foreach var of varlist * {
                if "`var'" == "level" {
                    local level_pos = `i'  // Position of level column
                    continue, break
                }
                local i = `i' + 1
            }

            /* Find p-value column position if it exists */
            local pvalue_pos = 0
            local i = 1
            foreach var of varlist * {
                if "`var'" == "pvalue" {
                    local pvalue_pos = `i'  // Position of p-value column
                    continue, break
                }
                local i = `i' + 1
            }

            /* Find test column position if it exists */
            local test_pos = 0
            local i = 1
            foreach var of varlist * {
                if "`var'" == "test" {
                    local test_pos = `i'
                    continue, break
                }
                local i = `i' + 1
            }

            /* Find statistic column position if it exists */
            local statistic_pos = 0
            local i = 1
            foreach var of varlist * {
                if "`var'" == "statistic" {
                    local statistic_pos = `i'
                    continue, break
                }
                local i = `i' + 1
            }

            /* Find SMD column position if it exists */
            local smd_pos = 0
            local i = 1
            foreach var of varlist * {
                if "`var'" == "smd_str" {
                    local smd_pos = `i'
                    continue, break
                }
                local i = `i' + 1
            }

			local data_start_pos = 3

            /*****************************************************************
            * Apply all Excel formatting in a single Mata xl() session
            *****************************************************************/

            * Pre-extract p-value and SMD data for conditional formatting
            if `has_boldp' | `has_highlight' {
                if `pvalue_pos' > 0 {
                    forvalues _br = 4/`num_rows' {
                        capture local _pval_`_br' = `p_raw'[`_br']
                        if _rc local _pval_`_br' = .
                    }
                }
            }
            if `smd_pos' > 0 & `smdthreshold' > 0 {
                forvalues _sr = 4/`num_rows' {
                    capture local _sval_`_sr' = `smd_raw'[`_sr']
                    if _rc local _sval_`_sr' = .
                }
            }

            * Find total column position before entering Mata
            local total_col_pos = 0
            if "`total'" != "" & "`borderstyle'" != "academic" {
                local i = 1
                foreach var of varlist * {
                    if "`var'" == "`by'_T" {
                        local total_col_pos = `i'
                        continue, break
                    }
                    local i = `i' + 1
                }
            }

            * Dynamic column width calculations
            if `test_pos' > 0 {
                local _test_maxlen = 12
                forvalues _tw = 1/`=_N' {
                    local _tstr = test[`_tw']
                    local _tlen = strlen("`_tstr'")
                    if `_tlen' > `_test_maxlen' local _test_maxlen = `_tlen'
                }
                local _test_width = max(12, ceil(`_test_maxlen' * 0.85) + 2)
            }
            if `statistic_pos' > 0 {
                local _stat_maxlen = 14
                forvalues _sw = 1/`=_N' {
                    local _sstr = statistic[`_sw']
                    local _slen = strlen("`_sstr'")
                    if `_slen' > `_stat_maxlen' local _stat_maxlen = `_slen'
                }
                local _stat_width = max(14, ceil(`_stat_maxlen' * 0.85) + 2)
            }

	            capture {
	                * Column widths, row heights, and styles are dispatched
	                * through the shared Mata style engine. Rule columns are:
	                * op r1 r2 c1 c2 value code r g b.
	                tempname _xlsx_style_rules
	                local _font_code = -1
	                local _border_code = 1
	                if "`_hborder'" == "medium" local _border_code = 2
	                if "`_hborder'" == "thick" local _border_code = 3

	                * Column widths and row heights
	                local _xlsx_style_rule_spec "12 1 1 1 1 30 0 0 0 0"
                * Row 2 is the B2:B3 merge anchor that carries the descriptor.
                local _hdr_len = strlen(`"`_descriptor_row_text'"')
                if `_hdr_len' > `factorwidth' * 1.2 {
                    local _hdr_lines = ceil(`_hdr_len' / (`factorwidth' * 1.2))
                    local _hdr_height = `_hdr_lines' * 15
	                    local _xlsx_style_rule_spec `"`_xlsx_style_rule_spec' | 12 2 2 1 1 `_hdr_height' 0 0 0 0"'
                }
	                local _xlsx_style_rule_spec `"`_xlsx_style_rule_spec' | 13 1 1 1 1 1 0 0 0 0 | 13 1 1 2 2 `factorwidth' 0 0 0 0"'
	                foreach _dc of local _data_cols {
	                    capture confirm variable `_dc'
	                    if !_rc {
	                        local _dc_pos = 0
	                        local _dc_i = 1
	                        foreach _dv of varlist * {
	                            if "`_dv'" == "`_dc'" {
	                                local _dc_pos = `_dc_i'
	                                continue, break
	                            }
	                            local _dc_i = `_dc_i' + 1
	                        }
	                        if `_dc_pos' > 0 & `_dc_pos' <= `num_cols' {
	                            local _xlsx_style_rule_spec `"`_xlsx_style_rule_spec' | 13 1 1 `_dc_pos' `_dc_pos' `datawidth' 0 0 0 0"'
	                        }
	                    }
	                }
                if `pvalue_pos' > 0 {
	                    local _xlsx_style_rule_spec `"`_xlsx_style_rule_spec' | 13 1 1 `pvalue_pos' `pvalue_pos' 10 0 0 0 0"'
                }
                if `test_pos' > 0 {
	                    local _xlsx_style_rule_spec `"`_xlsx_style_rule_spec' | 13 1 1 `test_pos' `test_pos' `_test_width' 0 0 0 0"'
                }
                if `statistic_pos' > 0 {
	                    local _xlsx_style_rule_spec `"`_xlsx_style_rule_spec' | 13 1 1 `statistic_pos' `statistic_pos' `_stat_width' 0 0 0 0"'
                }
                if `smd_pos' > 0 {
	                    local _xlsx_style_rule_spec `"`_xlsx_style_rule_spec' | 13 1 1 `smd_pos' `smd_pos' 8 0 0 0 0"'
                }

                * Font for entire table (single row-range call)
	                local _xlsx_style_rule_spec `"`_xlsx_style_rule_spec' | 1 1 `num_rows' 1 `num_cols' `_fontsize' `_font_code' 0 0 0 | 1 1 1 1 `num_cols' `=`_fontsize'+2' `_font_code' 0 0 0"'

                * Title row: merge + format
	                local _xlsx_style_rule_spec `"`_xlsx_style_rule_spec' | 14 1 1 1 `num_cols' 0 0 0 0 0 | 4 1 1 1 1 0 1 0 0 0 | 5 1 1 1 1 0 1 0 0 0 | 6 1 1 1 1 0 2 0 0 0 | 2 1 1 1 1 0 1 0 0 0"'

                * Header rows: merge factor column across rows 2-3
	                local _xlsx_style_rule_spec `"`_xlsx_style_rule_spec' | 14 2 3 2 2 0 0 0 0 0 | 5 2 3 2 2 0 2 0 0 0 | 6 2 3 2 2 0 2 0 0 0 | 4 2 3 2 2 0 1 0 0 0 | 2 2 3 2 2 0 1 0 0 0"'

                * Level column header merge (if exists)
                if `level_pos' > 0 {
	                    local _xlsx_style_rule_spec `"`_xlsx_style_rule_spec' | 14 2 3 `level_pos' `level_pos' 0 0 0 0 0 | 5 2 3 `level_pos' `level_pos' 0 2 0 0 0 | 6 2 3 `level_pos' `level_pos' 0 2 0 0 0 | 4 2 3 `level_pos' `level_pos' 0 1 0 0 0 | 2 2 3 `level_pos' `level_pos' 0 1 0 0 0"'
                }

                * Group data column headers (skip special columns)
                local data_col = `data_start_pos'
                while `data_col' <= `num_cols' {
                    local _skip = 0
                    if `data_col' == `pvalue_pos' local _skip = 1
                    if `data_col' == `test_pos' local _skip = 1
                    if `data_col' == `statistic_pos' local _skip = 1
                    if `data_col' == `smd_pos' local _skip = 1
                    if !`_skip' {
	                        local _xlsx_style_rule_spec `"`_xlsx_style_rule_spec' | 5 2 3 `data_col' `data_col' 0 2 0 0 0 | 6 2 3 `data_col' `data_col' 0 2 0 0 0 | 4 2 3 `data_col' `data_col' 0 1 0 0 0 | 2 2 3 `data_col' `data_col' 0 1 0 0 0"'
                    }
                    local data_col = `data_col' + 1
                }

                * P-value column header merge
                if `pvalue_pos' > 0 {
	                    local _xlsx_style_rule_spec `"`_xlsx_style_rule_spec' | 14 2 3 `pvalue_pos' `pvalue_pos' 0 0 0 0 0 | 5 2 3 `pvalue_pos' `pvalue_pos' 0 2 0 0 0 | 6 2 3 `pvalue_pos' `pvalue_pos' 0 2 0 0 0 | 4 2 3 `pvalue_pos' `pvalue_pos' 0 1 0 0 0 | 2 2 3 `pvalue_pos' `pvalue_pos' 0 1 0 0 0"'
                }

                * Test, statistic, SMD column header merges
                if `test_pos' > 0 {
	                    local _xlsx_style_rule_spec `"`_xlsx_style_rule_spec' | 14 2 3 `test_pos' `test_pos' 0 0 0 0 0 | 5 2 3 `test_pos' `test_pos' 0 2 0 0 0 | 6 2 3 `test_pos' `test_pos' 0 2 0 0 0 | 4 2 3 `test_pos' `test_pos' 0 1 0 0 0 | 2 2 3 `test_pos' `test_pos' 0 1 0 0 0"'
                }
                if `statistic_pos' > 0 {
	                    local _xlsx_style_rule_spec `"`_xlsx_style_rule_spec' | 14 2 3 `statistic_pos' `statistic_pos' 0 0 0 0 0 | 5 2 3 `statistic_pos' `statistic_pos' 0 2 0 0 0 | 6 2 3 `statistic_pos' `statistic_pos' 0 2 0 0 0 | 4 2 3 `statistic_pos' `statistic_pos' 0 1 0 0 0 | 2 2 3 `statistic_pos' `statistic_pos' 0 1 0 0 0"'
                }
                if `smd_pos' > 0 {
	                    local _xlsx_style_rule_spec `"`_xlsx_style_rule_spec' | 14 2 3 `smd_pos' `smd_pos' 0 0 0 0 0 | 5 2 3 `smd_pos' `smd_pos' 0 2 0 0 0 | 6 2 3 `smd_pos' `smd_pos' 0 2 0 0 0 | 4 2 3 `smd_pos' `smd_pos' 0 1 0 0 0 | 2 2 3 `smd_pos' `smd_pos' 0 1 0 0 0"'
                }

                * Horizontal borders
	                local _xlsx_style_rule_spec `"`_xlsx_style_rule_spec' | 8 2 2 2 `num_cols' 0 `_border_code' 0 0 0 | 8 4 4 2 `num_cols' 0 `_border_code' 0 0 0 | 9 `num_rows' `num_rows' 2 `num_cols' 0 `_border_code' 0 0 0"'

                * Vertical borders (skip for academic)
                if "`borderstyle'" != "academic" {
	                    local _xlsx_style_rule_spec `"`_xlsx_style_rule_spec' | 10 2 `num_rows' 2 2 0 `_border_code' 0 0 0 | 11 2 `num_rows' 2 2 0 `_border_code' 0 0 0 | 11 2 `num_rows' `num_cols' `num_cols' 0 `_border_code' 0 0 0"'
                }

                * Total column borders
                if `total_col_pos' > 0 {
	                    local _xlsx_style_rule_spec `"`_xlsx_style_rule_spec' | 10 2 `num_rows' `total_col_pos' `total_col_pos' 0 `_border_code' 0 0 0 | 11 2 `num_rows' `total_col_pos' `total_col_pos' 0 `_border_code' 0 0 0"'
                }

                * P-value column left border
                if `pvalue_pos' > 0 & "`borderstyle'" != "academic" {
	                    local _xlsx_style_rule_spec `"`_xlsx_style_rule_spec' | 10 2 `num_rows' `pvalue_pos' `pvalue_pos' 0 `_border_code' 0 0 0"'
                }

                * Test/statistic/SMD column left borders
                if `test_pos' > 0 & "`borderstyle'" != "academic" {
	                    local _xlsx_style_rule_spec `"`_xlsx_style_rule_spec' | 10 2 `num_rows' `test_pos' `test_pos' 0 `_border_code' 0 0 0"'
                }
                if `statistic_pos' > 0 & "`borderstyle'" != "academic" {
	                    local _xlsx_style_rule_spec `"`_xlsx_style_rule_spec' | 10 2 `num_rows' `statistic_pos' `statistic_pos' 0 `_border_code' 0 0 0"'
                }
                if `smd_pos' > 0 & "`borderstyle'" != "academic" {
	                    local _xlsx_style_rule_spec `"`_xlsx_style_rule_spec' | 10 2 `num_rows' `smd_pos' `smd_pos' 0 `_border_code' 0 0 0"'
                }

                * Header background
                if "`headershade'" != "" {
	                    local _xlsx_style_rule_spec `"`_xlsx_style_rule_spec' | 7 2 3 2 `num_cols' 0 -1 0 0 0"'
                }

                * Center-align data columns
                if `num_rows' >= 4 {
	                    local _xlsx_style_rule_spec `"`_xlsx_style_rule_spec' | 5 4 `num_rows' `data_start_pos' `num_cols' 0 2 0 0 0"'
                }

                * Zebra striping
                if "`zebra'" != "" {
                    forvalues _zr = 5(2)`num_rows' {
	                        local _xlsx_style_rule_spec `"`_xlsx_style_rule_spec' | 7 `_zr' `_zr' 2 `num_cols' 0 -2 0 0 0"'
                    }
                }

                * Bold significant p-values
                if `has_boldp' & `pvalue_pos' > 0 {
                    forvalues _br = 4/`num_rows' {
                        if `_pval_`_br'' < . & `_pval_`_br'' < `boldp' {
	                            local _xlsx_style_rule_spec `"`_xlsx_style_rule_spec' | 2 `_br' `_br' `pvalue_pos' `pvalue_pos' 0 1 0 0 0"'
                        }
                    }
                }

                * Highlight significant rows
                if `has_highlight' & `pvalue_pos' > 0 {
                    forvalues _hr = 4/`num_rows' {
                        if `_pval_`_hr'' < . & `_pval_`_hr'' < `highlight' {
	                            local _xlsx_style_rule_spec `"`_xlsx_style_rule_spec' | 7 `_hr' `_hr' 2 `num_cols' 0 -3 0 0 0"'
                        }
                    }
                }

                * SMD conditional formatting
                if `smd_pos' > 0 & `smdthreshold' > 0 {
                    forvalues _sr = 4/`num_rows' {
                        if `_sval_`_sr'' < . & `_sval_`_sr'' > `smdthreshold' {
	                            local _xlsx_style_rule_spec `"`_xlsx_style_rule_spec' | 2 `_sr' `_sr' `smd_pos' `smd_pos' 0 1 0 0 0 | 7 `_sr' `_sr' `smd_pos' `smd_pos' 0 -4 0 0 0"'
                        }
                    }
                }

                * Footnote
                if `"`footnote'"' != "" {
                    local _fn_row = `num_rows' + 1
                    local _fn_fontsize = max(`_fontsize' - 2, 6)
                    mata: b.put_string(`_fn_row', 2, `"`footnote'"')
	                    local _xlsx_style_rule_spec `"`_xlsx_style_rule_spec' | 14 `_fn_row' `_fn_row' 2 `num_cols' 0 0 0 0 0 | 5 `_fn_row' `_fn_row' 2 2 0 1 0 0 0 | 6 `_fn_row' `_fn_row' 2 2 0 2 0 0 0 | 4 `_fn_row' `_fn_row' 2 2 0 1 0 0 0 | 1 `_fn_row' `_fn_row' 2 2 `_fn_fontsize' `_font_code' 0 0 0 | 3 `_fn_row' `_fn_row' 2 2 0 1 0 0 0"'
                }

	                _tabtools_xlsx_build_styles, matrix(`_xlsx_style_rules') ///
	                    rules(`_xlsx_style_rule_spec') cols(10)
	                _tabtools_xlsx_apply_styles, book(b) sheet("`sheet'") ///
	                    rules(`_xlsx_style_rules') font("`_font'") ///
	                    color1("`_headercolor'") color2("`_zebracolor'") ///
	                    color3("255 255 204") color4("255 235 205")
                mata: b.close_book()

                * xl() appends a style record for every styled cell instead of
                * reusing one per distinct format, so collapse the pools here;
                * a workbook that keeps growing would otherwise reach Stata's
                * 65,536-record ceiling and fail with r(16147).
                _tabtools_xlsx_compact_styles using "`excel'"
            }
	            if _rc {
	                local saved_rc = _rc
	                capture mata: b.close_book()
	                local _style_close_cleanup_rc = _rc
	                capture mata: mata drop b
	                local _style_drop_b_cleanup_rc = _rc
	                * Drop the saved-state Mata vectors so a failed Excel write
	                * does not leak _p_raw_save / _smd_raw_save into the user's
	                * Mata workspace. Without this, a retry on a different table
	                * size would hit a stale-vector error.
	                capture mata: mata drop _p_raw_save
	                local _style_drop_p_cleanup_rc = _rc
	                capture mata: mata drop _smd_raw_save
	                local _style_drop_s_cleanup_rc = _rc
                noisily display as error "Excel formatting failed with error `saved_rc'"
                restore
                exit `saved_rc'
            }
            capture mata: mata drop b

            /* Clean up temporary p-value and SMD variables */
            capture drop `p_raw'
            capture drop `smd_raw'

            capture confirm file "`excel'"
            if _rc {
                noisily display as error "Export command succeeded but file not found"
                restore
                exit 601
            }
            local _xlsx_ok 1

            * Restore the sink-neutral table so csv(), markdown(), and frame()
            * see the same shape they would without xlsx().
            use `"`_t1_sink_snapshot'"', clear
        }
    }

    /* Keep internal raw columns out of public outputs */
    capture drop `p_raw'
    capture drop `smd_raw'

    * CSV export (F2)
    if "`csv'" != "" {
        _tabtools_csv_write using "`csv'", reservedrow title(`"`title'"') footnote(`"`footnote'"')
        display as text "CSV exported to `csv'"
    }

    local _ret_markdown ""
    local _ret_markdown_rows .
    local _ret_markdown_cols .
    if `has_markdown' {
        local _mdappend_opt ""
        if "`mdappend'" != "" local _mdappend_opt "append"
        * The Markdown writer reads its header from row 2 (headerstart) and, under
        * strictheaders, does NOT fall back to variable labels. Two things have to
        * happen before it is called.
        *
        * First, GFM allows one header row while this table has two semantic
        * header levels: row 1 carries the group labels and row 2 the descriptor
        * plus each group's N. Writing row 2 alone left the reader unable to tell
        * which column is which group, so flatten both into row 2 -- "Domestic
        * (N=52)". Second, the stat columns (p-value, SMD) carry their header only
        * as a variable label (set ~l.740); if the flatten leaves their row-2 cell
        * empty, fill it in explicitly. Body rows start at row 3 (datastart), so
        * neither step can overwrite a real value.
        *
        * Snapshot first: the flatten must not reach frame().
        tempfile _t1_md_snapshot
        quietly save `"`_t1_md_snapshot'"', replace
        if _N >= 2 {
            _tabtools_visible_vars, labelvar(A)
            foreach _mdv of local _tabtools_visible_vars {
                capture confirm string variable `_mdv'
                if !_rc {
                    local _mdh1 = strtrim(`_mdv'[1])
                    local _mdh2 = strtrim(`_mdv'[2])
                    if `"`_mdh1'"' == `"`_mdh2'"' local _mdh2 ""
                    if `"`_mdh1'"' != "" & `"`_mdh2'"' != "" {
                        quietly replace `_mdv' = `"`_mdh1' (`_mdh2')"' in 2
                    }
                    else if `"`_mdh1'"' != "" {
                        quietly replace `_mdv' = `"`_mdh1'"' in 2
                    }
                }
            }
        }
        capture replace pvalue = "p-value" if _n == 2 & strtrim(pvalue) == ""
        capture replace smd_str = "SMD" if _n == 2 & strtrim(smd_str) == ""
        capture noisily _tabtools_markdown_write using `"`markdown'"', ///
            `_mdappend_opt' labelvar(A) title(`"`_markdown_title'"') footnote(`"`footnote'"') strictheaders
        if _rc {
            local _md_rc = _rc
            display as error "Failed to export Markdown to `markdown'"
            restore
            exit `_md_rc'
        }
        local _ret_markdown `"`markdown'"'
        local _ret_markdown_rows = r(n_rows)
        local _ret_markdown_cols = r(n_cols)
        quietly use `"`_t1_md_snapshot'"', clear
        display as text "Markdown exported to `markdown'"
    }

**#  Store output in frame if requested (I5)
    if `"`frame'"' != "" {
        _tabtools_frame_put `"`frame'"'
        local frame `"`_frame_name'"'
        if "`smallcells'" != "" {
            frame `frame': char _dta[tabtools_smallcells] "`smallcells'"
            frame `frame': char _dta[tabtools_suppression_codes] "0 visible; 1 primary; 2 complementary; 3 derived"
            frame `frame': char _dta[tabtools_suppression_scope] "exact disclosure; single invocation; all sinks"
        }
        return local frame "`frame'"
    }

**#  Restore original data unless told not to
{
    if "`clear'"=="clear" restore, not
    else restore
}

    if `_xlsx_ok' {
        return local xlsx "`excel'"
        return local sheet "`sheet'"
    }
    if `"`_ret_markdown'"' != "" {
        return local markdown `"`_ret_markdown'"'
        return scalar markdown_rows = `_ret_markdown_rows'
        return scalar markdown_cols = `_ret_markdown_cols'
    }

    /* Open file if requested (W3) */
    if "`open'" != "" & `_xlsx_ok' {
        _tabtools_open_file "`excel'"
    }

    } // end capture noisily
    local _rc = _rc
    * Unconditional Mata cleanup — runs on success AND on any error path so a
    * failure mid-Excel-write cannot leak _p_raw_save / _smd_raw_save into the
    * user's Mata workspace.
    capture mata: mata drop _p_raw_save
    capture mata: mata drop _smd_raw_save
    capture frame change `_caller_frame'
    capture frame drop `_result_frame'
    capture frame drop `_wtc_crude_table'
    set varabbrev `_orig_varabbrev'
    if `_rc' exit `_rc'
    * The Mata cleanup above runs on the success path too, where those objects
    * exist only in the Excel branch, so both captures fail with r(111) and the
    * caller was left reading _rc == 111 after every successful call. _rc is
    * written by `capture' alone -- never by a program's exit code, so neither
    * falling off `end' nor `exit 0' clears it -- so restore it with a capture
    * that cannot fail. Guarded by test_synthesis_review.do A1 (bare call).
    capture version 17.0
    local _success_rc = _rc
end

capture program drop _desctab_collect_roundtrip
program define _desctab_collect_roundtrip, nclass
    version 17.0
    local _orig_varabbrev = c(varabbrev)
    set varabbrev off
    tempname _collection
    local _old_collection ""
    local _collection_created 0
    local _preserved 0

    capture noisily {
        capture quietly collect dir
        if !_rc local _old_collection `"`s(current)'"'

        unab _source_vars : _all
        local _nvars : word count `_source_vars'
        local _nobs = _N
        if `_nvars' == 0 | `_nobs' == 0 error 2000

        local _row_levels ""
        forvalues _i = 1/`_nobs' {
            local _row_levels "`_row_levels' r`_i'"
        }
        local _col_levels ""
        forvalues _j = 1/`_nvars' {
            local _col_levels "`_col_levels' c`_j'"
        }

        * The collect renderer is an internal serialization check.  Keep the
        * public table dataset byte-for-byte intact: collect string results do
        * not preserve leading indentation, which is part of table1_tc's frame
        * and workbook contract.
        preserve
        local _preserved 1
        quietly collect create `_collection'
        local _collection_created 1
        forvalues _i = 1/`_nobs' {
            forvalues _j = 1/`_nvars' {
                local _v : word `_j' of `_source_vars'
                quietly collect get cell = `_v'[`_i'], ///
                    tags(_ttrow[r`_i'] _ttcol[c`_j'])
            }
        }
        quietly collect layout (_ttrow) (_ttcol#result[cell])
        quietly collect style cell result[cell], nformat(%21.16g)

        _tabtools_collect_render, type(raw) rowdim(_ttrow) ///
            rowlevels("`_row_levels'") coldim(_ttcol) ///
            collevels("`_col_levels'") results(cell)
        assert _N == `_nobs'
        unab _rendered_vars : _all
        local _rendered_nvars : word count `_rendered_vars'
        assert `_rendered_nvars' == `_nvars'
        restore
        local _preserved 0
    }
    local rc = _rc
    if `_preserved' capture restore
    if `"`_old_collection'"' != "" {
        capture collect set `_old_collection'
        local _collection_set_rc = _rc
    }
    if `_collection_created' capture collect drop `_collection'
    set varabbrev `_orig_varabbrev'
    if `rc' exit `rc'
end
