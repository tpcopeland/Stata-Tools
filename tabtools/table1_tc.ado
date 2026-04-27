*! table1_tc Version 1.0.11  2026/04/27 - Descriptive Statistics Table Generator
*! Author: Timothy P Copeland, Karolinska Institutet
*! Fork of -table1_mc- version 3.5 (2024-12-19) by Mark Chatfield
*! This program generates descriptive statistics tables with formatting options
*! and can export them to Excel with automatic column width calculation

program define table1_tc, rclass
    version 16.0
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
                display as error "_tabtools_common.ado failed to load fully; reinstall tabtools"
                exit 111
            }
        }
        else {
            display as error "_tabtools_common.ado not found; reinstall tabtools"
            exit 111
        }
    }

**# Syntax Definition
    syntax [varlist] [if] [in] [fweight], ///
        [by(varname)]           /// Optional grouping variable
        [vars(string)]          /// Variables to display: varname vartype [varformat], vars delimited by \
        [Format(string)]        /// Default format for continuous normal/skewed variables
        [PERCFormat(string)]    /// Default format for categorical/binary variables
        [NFormat(string)]       /// Format for counts (n and N); default is %12.0fc
        [iqrmiddle(string asis)] /// Symbol between Q1 and Q3; default is "-"
        [sdleft(string asis)]   /// Symbol before SD; default is " ("
        [sdright(string asis)]  /// Symbol after SD; default is ")"
        [gsdleft(string asis)]  /// Symbol before GSD; default is " (×/"
        [gsdright(string asis)] /// Symbol after GSD; default is ")"
        [percent]               /// Report categorical vars just as % (no N)
        [MISsing]               /// Don't exclude missing values
        [pdp(integer 3)]        /// Max decimal places in p-value < 0.1 (0-10)
        [highpdp(integer 2)]    /// Max decimal places in p-value >= 0.1 (0-10)
        [test]                  /// Include column specifying which test was used
        [STATistic]             /// Give value of test statistic
        [excel(string)]         /// Excel file to save output
        [xlsx(string)]          /// Synonym for excel()
        [sheet(string)]         /// Excel sheet name
        [title(string)]         /// Table title
        [clear]                 /// Keep resulting table in memory
        [percent_n]             /// Display as % (n) rather than n (%)
        [percsign(string asis)] /// Percent sign; default is "%"
        [NOSPACElowpercent]     /// Report e.g. (3%) rather than ( 3%)
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
        [THEme(string)]         /// Journal-style theme: lancet, nejm, bmj, apa
        [SMDThreshold(real 0.1)] /// SMD threshold for conditional formatting (0.1 default; -1 = disabled)
        [HEADERColor(string)]   /// Custom header background color (R G B)
        [ZEBRAColor(string)]    /// Custom zebra stripe color (R G B)
        [csv(string)]           /// Export data as CSV file
        [MISSINGSummary]        /// Add missing data summary row per variable
        [NOIsily]               /// Show auto-detection classification decisions
        [dots]                  /// Show progress dots per variable
        [WTCompare]             // Side-by-side crude vs weighted comparison

**# Input Validation and Option Setup

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

    /* Validation: Check if by() variable exists */
    if "`by'" != "" {
        capture confirm variable `by'
        if _rc {
            display as error "by() variable `by' not found"
            error 111
        }
    }

    /* Check if by() variable will cause naming conflicts */
    if (substr("`by'",1,2) == "N_" | substr("`by'",1,2) == "m_" | inlist("`by'", "N", "m") | ///
        inlist("`by'", "_", "_c","_co","_col","_colu","_colum","_column","_columna","_columnb")) {
        display as error "by() variable cannot start with the prefix N_ or m_, or be named N, m, _, _c, _co, _col, _colu, _colum, _column, _columna, _columnb. Please rename that variable."
        error 498  // User-defined error
    }

    /* Check if Excel options are properly specified */
    local has_excel = "`excel'" != ""  // Boolean flag for Excel option
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

    // sheet() and title() only make sense with excel()
    if !`has_excel' & (`has_sheet' | `has_title') {
        display as error "sheet() and title() are only available when using excel()"
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

    /* Validate pdp and highpdp options */
    if `pdp' < 0 | `pdp' > 10 {
        display as error "pdp() must be between 0 and 10"
        error 198
    }
    if `highpdp' < 0 | `highpdp' > 10 {
        display as error "highpdp() must be between 0 and 10"
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

    /* Validate weight option */
    if "`wt'" != "" {
        confirm numeric variable `wt'
        if "`weight'" == "fweight" {
            display as error "wt() and fweight cannot be used together"
            error 198
        }
        quietly count if `wt' < 0
        if r(N) > 0 {
            display as error "wt() variable must be non-negative"
            error 498
        }
    }
    local has_wt = "`wt'" != ""

    /* When wt() specified without wtcompare: default to percent-only for
       binary/categorical variables. In IPTW analyses, showing unweighted counts
       with weighted percentages is misleading (n/N ≠ %). Users can override
       with percent_n to see counts. wtcompare excluded: it has its own two-pass
       loop where crude columns need n(%) and the layout is already labeled. */
    if `has_wt' & "`percent_n'" == "" & "`wtcompare'" == "" {
        local percent "percent"
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
    _tabtools_resolve_format, theme(`theme') borderstyle(`borderstyle') headershade(`headershade')

    * Resolve header/zebra colors
    local _headercolor "219 229 241"
    local _zebracolor "237 242 249"
    if "$TABTOOLS_HEADERCOLOR" != "" local _headercolor "$TABTOOLS_HEADERCOLOR"
    if "$TABTOOLS_ZEBRACOLOR" != "" local _zebracolor "$TABTOOLS_ZEBRACOLOR"
    if "`headercolor'" != "" local _headercolor "`headercolor'"
    if "`zebracolor'" != "" local _zebracolor "`zebracolor'"
    _tabtools_validate_color "`_headercolor'" "headercolor()"
    _tabtools_validate_color "`_zebracolor'" "zebracolor()"

    * Initialize test tracking for methods paragraph (C5)
    local _used_ttest 0
    local _used_anova 0
    local _used_wilcoxon 0
    local _used_kw 0
    local _used_chi2 0
    local _used_fisher 0

    /* Set default formats if not specified */
    if `"`nformat'"' == "" local nformat "%12.0fc"        // Default format for counts
    if `"`percsign'"' == "" local percsign `""%""'        // Default percent sign
    if `"`iqrmiddle'"' == "" local iqrmiddle `""-""'      // Default separator for IQR
    if `"`sdleft'"' == "" local sdleft `"" (""'           // Default format before SD
    if `"`sdright'"' == "" local sdright `"")""'          // Default format after SD
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
        local percentage2 "`percentage'"
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

    /* Mark observations to include in analysis */
    marksample touse, novarlist  // Creates indicator variable for observations that satisfy if/in conditions
    if `has_wt' markout `touse' `wt'  // Exclude observations with missing weights

    /* Validate that observations remain after if/in conditions */
    quietly count if `touse'
    if r(N) == 0 {
        display as error "no observations"
        error 2000
    }

    /* Create temporary file for storing the results table */
    tempfile resultstable

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
        // Ensure long storage so total sentinel value is exact
        qui recast long `groupnum', force
    }
    
    /* Validate the grouping variable */
    qui su `groupnum'
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

    /* Check that all group values are integers */
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
        tempfile _wtc_crude_table
        local _wtc_passes "crude weighted"
    }
    else {
        local _wtc_passes "single"
    }
    local _wtc_save_sortorder = `sortorder'
    local _wtc_save_has_wt = `has_wt'
    local _wtc_save_has_smd = `has_smd'

    foreach _wtc_pass of local _wtc_passes {

    * Reset sortorder for each pass so rows align for merge
    local sortorder = `_wtc_save_sortorder'

    if `has_wtcompare' {
        if "`_wtc_pass'" == "crude" {
            local has_wt 0
            local has_smd 0
            display as text "(wtcompare: computing crude statistics...)"
        }
        else {
            local has_wt `_wtc_save_has_wt'
            local has_smd `_wtc_save_has_smd'
            display as text "(wtcompare: computing weighted statistics...)"
        }
    }

**# Generate Sample Size Row (N)
    preserve
    qui keep if `touse'  // Keep only observations that satisfy if/in conditions
    qui drop if missing(`groupnum')  // Drop observations with missing group values
    
    /* Create total column if requested */
    if "`total'" != "" { 
        qui expand 2, gen(_copy)  // Duplicate observations for total calculation
        qui replace `groupnum' = `_total_code' if _copy == 1   // sentinel as placeholder for total
    }
    
    /* Get counts by group (unweighted N when using wt()) */
    if `has_wt' contract `groupnum'
    else contract `groupnum' [`weight'`exp']
    gen factor="N"  // Label for the row
    gen factor_sep="N" // For neat output formatting
    
    /* Format the sample size display */
    qui gen n= "N=" + string(_freq, "`nformat'")  // Format as "N=xxx"
    rename _freq N_  // Rename frequency variable
    
    /* Reshape to wide format for display */
    qui reshape wide n N_, i(factor) j(`groupnum')  // Create separate columns for each group
    rename n* `groupnum'*  // Rename to match group values
    
    /* Add sort variable and save */
    gen sort1=`sortorder++'  // Assign sort order
    qui save "`resultstable'", replace  // Save initial table
    restore

    /* Add ESS row when wt() specified — Kish's formula: ESS = (Σwi)² / Σwi² */
    if `has_wt' {
        preserve
        qui keep if `touse'
        qui drop if missing(`groupnum')
        if "`total'" != "" {
            qui expand 2, gen(_copy)
            qui replace `groupnum' = `_total_code' if _copy == 1
        }
        qui gen double _wt_val = `wt'
        qui gen double _wt_sq = _wt_val^2
        qui collapse (sum) _sum_w=_wt_val (sum) _sum_w2=_wt_sq, by(`groupnum')
        qui gen double _ess = (_sum_w^2) / _sum_w2
        qui gen factor = "Effective sample size"
        qui gen factor_sep = "ESS"
        qui gen n = "ESS=" + string(_ess, "`nformat'")
        qui gen N_ = .
        qui keep `groupnum' factor factor_sep n N_
        qui reshape wide n N_, i(factor) j(`groupnum')
        rename n* `groupnum'*
        qui gen sort1 = `sortorder++'
        qui append using "`resultstable'"
        qui save "`resultstable'", replace
        restore
    }

    * wtcompare crude pass: skip sortorder ahead to account for missing ESS row
    if `has_wtcompare' & !`has_wt' & `_wtc_save_has_wt' {
        local sortorder = `sortorder' + 1
    }

**# Process Variables Specified in vars() Option
    local _processed_varlist ""
    local _resolved_has_bin 0
    local _resolved_has_cat 0
    local _resolved_has_contn 0
    local _resolved_has_contln 0
    local _resolved_has_conts 0
    if "`dots'" != "" display as text "Processing variables: " _continue
    gettoken arg rest : vars, parse("\")  // Parse the first variable specification
    while `"`arg'"' != "" {
        if `"`arg'"' != "\" {
            * Reset test statistics to prevent stale values leaking between variables
            local p .
            local chi2 .
            local df .
            local z .
            local tstat .
            local f .
            local df1 .
            local df2 .
            local _smd_val .

            local varname   : word 1 of `arg'  // Extract variable name
            local vartype   : word 2 of `arg'  // Extract variable type
            local varformat : word 3 of `arg'  // Extract custom format (if any)
            local varformat2 : word 4 of `arg'  // Extract second format (if any)

            /* Validate variable and type */
            confirm variable `varname'  // Check that variable exists
            local _processed_varlist "`_processed_varlist' `varname'"

            // Auto-detect variable type if "auto" or omitted
            if "`vartype'" == "auto" | "`vartype'" == "" {
                _tabtools_detect_vartype `varname'
                local vartype "`result'"
                if "`noisily'" != "" noisily display as text "  `varname' classified as `vartype' (N unique = `result_nuniq')"
                if "`dots'" != "" display as text "(auto: `varname' → `vartype') " _continue
            }

            // Check that variable type is valid
            if !inlist("`vartype'", "contn", "contln", "conts", "cat", "cate", "bin", "bine") {
                display as error "-`varname' `vartype'- not allowed in vars() option"
                display as error "Variables must be classified as contn, contln, conts, cat, cate, bin or bine"
                error 498
            }
            if inlist("`vartype'", "bin", "bine") local _resolved_has_bin 1
            if inlist("`vartype'", "cat", "cate") local _resolved_has_cat 1
            if "`vartype'" == "contn" local _resolved_has_contn 1
            if "`vartype'" == "contln" local _resolved_has_contln 1
            if "`vartype'" == "conts" local _resolved_has_conts 1
            
            /* Get variable label or use name if no label exists */
            local varlab: variable label `varname'
            if "`varlab'"=="" local varlab `varname'  // Use variable name if no label
    
        **## Process Continuous Normal Variables
            if "`vartype'"=="contn" {
                preserve
                qui keep if `touse'  // Keep relevant observations
                qui drop if missing(`groupnum')  // Drop observations with missing group values
                                
                // Count groups with non-missing values for this variable
                qui levelsof `groupnum' if `varname'!=., local(glevels)
                local nglevels: word count `glevels'

                /* Calculate significance test (suppressed when wt() specified) */
                if !`has_wt' {
                    if `nglevels'>=2 {
                        // ANOVA for >1 group
                        qui anova `varname' `groupnum' [`weight'`exp']
                        // Use Ftail() for numerical stability - equivalent to 1-F() but more robust
                        local p = Ftail(e(df_m), e(df_r), e(F))
                        local f : di %6.2f e(F)  // F statistic
                        local df1 = e(df_m)  // Degrees of freedom (numerator)
                        local df2 = e(df_r)  // Degrees of freedom (denominator)
                    }
                    if `nglevels'==2 {
                        // t-test for exactly 2 groups
                        qui regress `varname' ib(first).`groupnum' [`weight'`exp']
                        tempname Tmat
                        matrix `Tmat' = r(table)
                        local tstat : di %6.2f -1*`Tmat'[3,2]  // t statistic
                    }

                    * Track tests used (C5)
                    if `nglevels' == 2 local _used_ttest 1
                    if `nglevels' > 2 local _used_anova 1
                }

                /* Compute SMD if requested (F1) */
                local _smd_val .
                if `has_smd' & `nglevels' >= 2 {
                    if `has_wt' {
                        qui su `varname' [aw=`wt'] if `groupnum' == `level1'
                        local _smd_m1 = r(mean)
                        local _smd_s1 = r(sd)
                        qui su `varname' [aw=`wt'] if `groupnum' == `level2'
                        local _smd_m2 = r(mean)
                        local _smd_s2 = r(sd)
                        local _smd_poolsd = sqrt((`_smd_s1'^2 + `_smd_s2'^2) / 2)
                    }
                    else {
                        qui su `varname' if `groupnum' == `level1'
                        local _smd_m1 = r(mean)
                        local _smd_s1 = r(sd)
                        local _smd_n1 = r(N)
                        qui su `varname' if `groupnum' == `level2'
                        local _smd_m2 = r(mean)
                        local _smd_s2 = r(sd)
                        local _smd_n2 = r(N)
                        local _smd_poolsd = sqrt(((`_smd_n1'-1)*`_smd_s1'^2 + (`_smd_n2'-1)*`_smd_s2'^2) / (`_smd_n1'+`_smd_n2'-2))
                    }
                    if `_smd_poolsd' > 0 local _smd_val = (`_smd_m1' - `_smd_m2') / `_smd_poolsd'
                }

                /* Set display format */
                if "`varformat'"=="" {
                    // If no custom format, use either the format option or the variable's own format
                    if "`format'"=="" local varformat: format `varname'
                    else local varformat `format'
                }

                /* Calculate statistics by group */
                if "`total'" != "" {
                    qui expand 2, gen(_copy)  // Duplicate for total calculation
                    qui replace `groupnum' = `_total_code' if _copy == 1  // Mark total rows
                }

                // Calculate mean, SD, and count by group
                if `has_wt' {
                    collapse (mean) mean=`varname' (sd) sd=`varname' (count) N_=`varname' ///
                        [aw=`wt'], by(`groupnum')
                }
                else {
                    collapse (mean) mean=`varname' (sd) sd=`varname' (count) N_=`varname' ///
                        [`weight'`exp'], by(`groupnum')
                }
                format N_ %8.0g

                /* Format results for display */
                qui gen _columna_ = string(mean, "`varformat'")  // Format mean
                if "`varformat2'"!="" local varformat "`varformat2'"  // Use second format for SD if specified
                qui gen sd_ = string(sd, "`varformat'")  // Format SD
                qui gen _columnb_ = `sdleft' + sd_ + `sdright'  // Format SD with symbols
                qui replace _columna_ = "" if mean ==.  // Blank if missing
                qui replace _columnb_ = "" if mean ==.  // Blank if missing
                qui gen mean_sd = _columna_ + _columnb_  // Combine mean and SD
                
                /* Apply labels */
                label var _columna_ "columna"
                label var _columnb_ "columnb"
                label var N_ "N"

                // Create row label with variable name and stats type
                qui gen factor="`varlab', `meanSD'"
                if `"`varlabplus'"' == "" qui replace factor="`varlab'"  // Simplified if varlabplus not specified
                qui clonevar factor_sep=factor  // Copy for formatting
                
                /* Reshape for display */
                keep factor* `groupnum' mean_sd _columna_ _columnb_ N_
                qui reshape wide mean_sd _columna_ _columnb_ N_, i(factor) j(`groupnum')
                rename mean_sd* `groupnum'*  // Rename columns by group
                
                /* Add p-value, test type, and statistics (skipped when weighted) */
                if `nglevels'>1 & !`has_wt' qui {
                    gen p=`p'
                }

                // Add SMD if requested
                if `has_smd' qui gen smd_val = `_smd_val'

                // Add test type label based on number of groups
                if "`test'"=="test" & `nglevels'==2 & !`has_wt' gen test="Ind. t test"
                if "`test'"=="test" & `nglevels'>2 & !`has_wt' gen test="ANOVA"

                // Add test statistic details if requested
                if "`statistic'"=="statistic" & `nglevels'==2 & !`has_wt' gen statistic="t(`df2')=`tstat'"
                if "`statistic'"=="statistic" & `nglevels'>2 & !`has_wt' gen statistic="F(`df1',`df2')=`f'"

                /* Add sort variable and append to results */
                gen sort1=`sortorder++'
                qui append using "`resultstable'"
                qui save "`resultstable'", replace
                if "`dots'" != "" noisily display as text "." _continue
                restore
            }

        **## Process Continuous Log-Normal Variables
            if "`vartype'"=="contln" {
                preserve
                qui keep if `touse'  // Keep relevant observations
                qui drop if missing(`groupnum')  // Drop observations with missing group values
                qui drop if `varname' <=0  // Drop values that would give missing after log transform
                
                // Create log-transformed variable
                tempvar lvarname
                qui gen `lvarname' = log(`varname')
                
                // Count groups with non-missing values
                qui levelsof `groupnum' if `lvarname'!=., local(glevels)
                local nglevels: word count `glevels'

                /* Calculate significance test (suppressed when wt() specified) */
                if !`has_wt' {
                    if `nglevels'>=2 {
                        // ANOVA on log-transformed values
                        qui anova `lvarname' `groupnum' [`weight'`exp']
                        // Use Ftail() for numerical stability - equivalent to 1-F() but more robust
                        local p = Ftail(e(df_m), e(df_r), e(F))
                        local f : di %6.2f e(F)  // F statistic
                        local df1 = e(df_m)  // Degrees of freedom (numerator)
                        local df2 = e(df_r)  // Degrees of freedom (denominator)
                    }
                    if `nglevels'==2 {
                        // t-test for exactly 2 groups
                        qui regress `lvarname' ib(first).`groupnum' [`weight'`exp']
                        tempname Tmat
                        matrix `Tmat' = r(table)
                        local tstat : di %6.2f -1*`Tmat'[3,2]  // t statistic
                    }

                    * Track tests used (C5)
                    if `nglevels' == 2 local _used_ttest 1
                    if `nglevels' > 2 local _used_anova 1
                }

                /* Compute SMD if requested (F1) — on log-transformed values */
                local _smd_val .
                if `has_smd' & `nglevels' >= 2 {
                    if `has_wt' {
                        qui su `lvarname' [aw=`wt'] if `groupnum' == `level1'
                        local _smd_m1 = r(mean)
                        local _smd_s1 = r(sd)
                        qui su `lvarname' [aw=`wt'] if `groupnum' == `level2'
                        local _smd_m2 = r(mean)
                        local _smd_s2 = r(sd)
                        local _smd_poolsd = sqrt((`_smd_s1'^2 + `_smd_s2'^2) / 2)
                    }
                    else {
                        qui su `lvarname' if `groupnum' == `level1'
                        local _smd_m1 = r(mean)
                        local _smd_s1 = r(sd)
                        local _smd_n1 = r(N)
                        qui su `lvarname' if `groupnum' == `level2'
                        local _smd_m2 = r(mean)
                        local _smd_s2 = r(sd)
                        local _smd_n2 = r(N)
                        local _smd_poolsd = sqrt(((`_smd_n1'-1)*`_smd_s1'^2 + (`_smd_n2'-1)*`_smd_s2'^2) / (`_smd_n1'+`_smd_n2'-2))
                    }
                    if `_smd_poolsd' > 0 local _smd_val = (`_smd_m1' - `_smd_m2') / `_smd_poolsd'
                }

                /* Set display format */
                if "`varformat'"=="" {
                    // If no custom format, use either the format option or the variable's own format
                    if "`format'"=="" local varformat: format `varname'
                    else local varformat `format'
                }

                /* Calculate statistics by group */
                if "`total'" != "" {
                    qui expand 2, gen(_copy)  // Duplicate for total calculation
                    qui replace `groupnum' = `_total_code' if _copy == 1  // Mark total rows
                }

                // Calculate mean, SD, and count of log-transformed values by group
                if `has_wt' {
                    collapse (mean) mean=`lvarname' (sd) sd=`lvarname' (count) N_=`lvarname' ///
                        [aw=`wt'], by(`groupnum')
                }
                else {
                    collapse (mean) mean=`lvarname' (sd) sd=`lvarname' (count) N_=`lvarname' ///
                        [`weight'`exp'], by(`groupnum')
                }
                format N_ %8.0g
                
                /* Back-transform from log scale and format results */
                qui replace mean = exp(mean)  // Back-transform mean (geometric mean)
                qui replace sd = exp(sd)      // Back-transform SD (geometric SD)
                qui gen _columna_ = string(mean, "`varformat'")  // Format geometric mean
                if "`varformat2'"!="" local varformat "`varformat2'"  // Use second format for GSD if specified
                qui gen sd_ = string(sd, "`varformat'")  // Format GSD                                              
                qui gen _columnb_ = `gsdleft' + sd_ + `gsdright'  // Format GSD with symbols
                qui replace _columna_ = "" if mean ==.  // Blank if missing
                qui replace _columnb_ = "" if mean ==.  // Blank if missing
                qui gen mean_sd = _columna_ + _columnb_  // Combine geometric mean and GSD
                
                /* Apply labels */
                label var _columna_ "columna"
                label var _columnb_ "columnb"
                label var N_ "N"

                // Create row label with variable name and stats type
                qui gen factor="`varlab', `gmeanSD'"
                if `"`varlabplus'"' == "" qui replace factor="`varlab'"  // Simplified if varlabplus not specified
                qui clonevar factor_sep=factor  // Copy for formatting
                
                /* Reshape for display */
                keep factor* `groupnum' mean_sd _columna_ _columnb_ N_
                qui reshape wide mean_sd _columna_ _columnb_ N_, i(factor) j(`groupnum')
                rename mean_sd* `groupnum'*  // Rename columns by group
                
                /* Add p-value, test type, and statistics (skipped when weighted) */
                if `nglevels'>1 & !`has_wt' qui {
                    gen p=`p'
                }

                if `has_smd' qui gen smd_val = `_smd_val'

                // Add test type label based on number of groups
                if "`test'"=="test" & `nglevels'==2 & !`has_wt' gen test="Ind. t test, logged data"
                if "`test'"=="test" & `nglevels'>2 & !`has_wt' gen test="ANOVA, logged data"

                // Add test statistic details if requested
                if "`statistic'"=="statistic" & `nglevels'==2 & !`has_wt' gen statistic="t(`df2')=`tstat'"
                if "`statistic'"=="statistic" & `nglevels'>2 & !`has_wt' gen statistic="F(`df1',`df2')=`f'"

                /* Add sort variable and append to results */
                gen sort1=`sortorder++'
                qui append using "`resultstable'"
                qui save "`resultstable'", replace
                if "`dots'" != "" noisily display as text "." _continue
                restore
            }
                        
        **## Process Continuous Skewed Variables
            if "`vartype'"=="conts" {
                preserve
                qui keep if `touse'  // Keep relevant observations
                qui drop if missing(`groupnum')  // Drop observations with missing group values

                /* Expand by frequency weight for rank-based tests (not needed with wt()) */
                if "`weight'"=="fweight" & !`has_wt' qui expand `exp'

                // Count groups with non-missing values
                qui levelsof `groupnum' if `varname'!=., local(glevels)
                local nglevels: word count `glevels'

                /* Calculate significance test (suppressed when wt() specified) */
                if !`has_wt' {
                    if `nglevels'>2 {
                        /* Kruskal-Wallis for >2 groups */
                        capture qui kwallis `varname', by(`groupnum')
                        if _rc == 0 {
                            local p=chi2tail(r(df), r(chi2_adj))  // p-value
                            local chi2 :di %6.2f r(chi2_adj)  // Chi-square statistic
                            local df = r(df)  // Degrees of freedom
                        }
                    }
                    if `nglevels'==2 {
                        /* Rank-sum for 2 groups */
                        capture qui ranksum `varname', by(`groupnum')
                        if _rc == 0 {
                            local z = r(z)  // z statistic
                            local p=2*normal(-abs(`z'))  // Two-sided p-value
                            local z : di %6.2f `z'  // Format z statistic
                        }
                    }

                    * Track tests used (C5)
                    if `nglevels' == 2 local _used_wilcoxon 1
                    if `nglevels' > 2 local _used_kw 1
                }

                /* Compute SMD if requested (F1) — on raw values for skewed vars */
                local _smd_val .
                if `has_smd' & `nglevels' >= 2 {
                    if `has_wt' {
                        qui su `varname' [aw=`wt'] if `groupnum' == `level1'
                        local _smd_m1 = r(mean)
                        local _smd_s1 = r(sd)
                        qui su `varname' [aw=`wt'] if `groupnum' == `level2'
                        local _smd_m2 = r(mean)
                        local _smd_s2 = r(sd)
                        local _smd_poolsd = sqrt((`_smd_s1'^2 + `_smd_s2'^2) / 2)
                    }
                    else {
                        qui su `varname' if `groupnum' == `level1'
                        local _smd_m1 = r(mean)
                        local _smd_s1 = r(sd)
                        local _smd_n1 = r(N)
                        qui su `varname' if `groupnum' == `level2'
                        local _smd_m2 = r(mean)
                        local _smd_s2 = r(sd)
                        local _smd_n2 = r(N)
                        local _smd_poolsd = sqrt(((`_smd_n1'-1)*`_smd_s1'^2 + (`_smd_n2'-1)*`_smd_s2'^2) / (`_smd_n1'+`_smd_n2'-2))
                    }
                    if `_smd_poolsd' > 0 local _smd_val = (`_smd_m1' - `_smd_m2') / `_smd_poolsd'
                }

                /* Set display format */
                if "`varformat'"=="" {
                    // If no custom format, use either the format option or the variable's own format
                    if "`format'"=="" local varformat: format `varname'
                    else local varformat `format'
                }

                /* Calculate statistics by group */
                if "`total'" != "" {
                    qui expand 2, gen(_copy)  // Duplicate for total calculation
                    qui replace `groupnum' = `_total_code' if _copy == 1  // Mark total rows
                }

                // Calculate median and IQR by group
                if `has_wt' {
                    collapse (p50) p50=`varname' (p25) p25=`varname' ///
                        (p75) p75=`varname' (count) N_=`varname' [aw=`wt'], by(`groupnum')
                }
                else {
                    collapse (p50) p50=`varname' (p25) p25=`varname' ///
                        (p75) p75=`varname' (count) N_=`varname' , by(`groupnum')
                }
                format N_ %8.0g
                
                /* Format results for display */
                qui gen _columna_ = string(p50, "`varformat'")  // Format median
                if "`varformat2'"!="" local varformat "`varformat2'"  // Use second format for quartiles if specified
                // Format IQR with symbols
                qui gen _columnb_ = "(" + string(p25, "`varformat'") + `iqrmiddle' + string(p75, "`varformat'") + ")"
                qui gen median_iqr = _columna_ + " " + _columnb_  // Combine median and IQR
                qui replace _columna_ = "" if p50 ==.  // Blank if missing
                qui replace _columnb_ = "" if p50 ==.  // Blank if missing
                qui replace median_iqr = "" if p50 ==.  // Blank if missing

                /* Apply labels */
                label var _columna_ "columna"
                label var _columnb_ "columnb"
                label var N_ "N"
                
                // Create row label with variable name and stats type
                qui gen factor="`varlab', median (Q1, Q3)"
                if `"`varlabplus'"' == "" qui replace factor="`varlab'"  // Simplified if varlabplus not specified
                qui clonevar factor_sep=factor  // Copy for formatting
                
                /* Reshape for display */
                keep factor* `groupnum' median_iqr _columna_ _columnb_ N_
                qui reshape wide median_iqr _columna_ _columnb_ N_, i(factor) j(`groupnum')
                rename median_iqr* `groupnum'*  // Rename columns by group

                /* Add p-value, test type, and statistics (skipped when weighted) */
                if `nglevels'>1 & !`has_wt' qui {
                    gen p=`p'
                }

                if `has_smd' qui gen smd_val = `_smd_val'

                // Add test type label based on number of groups
                if "`test'"=="test" & `nglevels'==2 & !`has_wt' gen test="Wilcoxon rank-sum"
                if "`test'"=="test" & `nglevels'>2 & !`has_wt' gen test="Kruskal-Wallis"

                // Add test statistic details if requested
                if "`statistic'"=="statistic" & `nglevels'==2 & !`has_wt' gen statistic="Z=`z'"
                if "`statistic'"=="statistic" & `nglevels'>2 & !`has_wt' gen statistic="Chi2(`df')=`chi2'"

                /* Add sort variable and append to results */
                gen sort1=`sortorder++'
                qui append using "`resultstable'"
                qui save "`resultstable'", replace
                if "`dots'" != "" noisily display as text "." _continue
                restore
            }
            
        **## Process Categorical Variables
            if "`vartype'"=="cat" | "`vartype'"=="cate" {
                preserve
                qui keep if `touse'  // Keep relevant observations
                qui drop if missing(`groupnum')  // Drop observations with missing group values
                if "`missing'"!="missing" qui drop if missing(`varname')  // Drop observations with missing values unless missing option specified
                
                // Check if observations remain after filtering
                qui count
                if r(N)==0 {
                    display as error "no categories for `varname' ... cannot tabulate"
                    exit 198
                }

                /* Ensure categorical variable is numeric */
                tempvar varnum
                capture confirm numeric variable `varname'
                if !_rc qui clonevar `varnum'=`varname'  // Keep as is if numeric
                else qui encode `varname', gen(`varnum')  // Encode if string
                
                // Count groups and variable levels
                qui levelsof `groupnum', local(glevels)
                local nglevels: word count `glevels'
                qui levelsof `varnum', local(vlevels)
                local nvlevels: word count `vlevels'                    
                
                // Add missing as another level if requested
                if "`missing'"=="missing" {
                    qui count if `varnum'==.
                    if r(N)!=0 local nvlevels = `nvlevels'+1
                }                
                
                /* Calculate significance test (suppressed when wt() specified) */
                if `nglevels'>1 & `nvlevels'>1 & !`has_wt' {
                    if "`vartype'"=="cat" {
                        // Chi-square test for standard categorical
                        qui tab `varnum' `groupnum' [`weight'`exp'], chi2 m
                        local p=r(p)  // p-value
                        local chi2 : di %6.2f r(chi2)  // Chi-square statistic
                        local df = (r(r)-1)*(r(c)-1)  // Degrees of freedom

                        * Track tests used (C5)
                        local _used_chi2 1
                    }
                    else {
                        // Fisher's exact test for cate type
                        qui tab `varnum' `groupnum' [`weight'`exp'], exact m
                        local p=r(p_exact)

                        * Track tests used (C5)
                        local _used_fisher 1
                    }

                    /* Compute SMD for categorical vars — Austin (2009) variance-ratio approach */
                    if `has_smd' & `nglevels' >= 2 {
                        local _smd_ssq 0
                        qui levelsof `varnum', local(_cat_lvls)
                        foreach _clv of local _cat_lvls {
                            qui su `varnum' if `groupnum' == `level1'
                            local _smd_n1 = r(N)
                            qui count if `varnum' == `_clv' & `groupnum' == `level1'
                            local _smd_p1 = r(N) / `_smd_n1'
                            qui su `varnum' if `groupnum' == `level2'
                            local _smd_n2 = r(N)
                            qui count if `varnum' == `_clv' & `groupnum' == `level2'
                            local _smd_p2 = r(N) / `_smd_n2'
                            local _smd_pavg = (`_smd_p1' + `_smd_p2') / 2
                            local _smd_denom = sqrt(`_smd_pavg' * (1 - `_smd_pavg'))
                            if `_smd_denom' > 0 {
                                local _smd_ssq = `_smd_ssq' + ((`_smd_p1' - `_smd_p2') / `_smd_denom')^2
                            }
                        }
                        local _smd_val = sqrt(`_smd_ssq')
                    }
                }

                /* Compute weighted SMD for categorical vars when wt() is active */
                if `has_wt' & `has_smd' & `nglevels' >= 2 {
                    local _smd_val .
                    local _smd_ssq 0
                    qui levelsof `varnum', local(_cat_lvls)
                    foreach _clv of local _cat_lvls {
                        * Weighted proportions via sum of weights
                        qui su `wt' if `groupnum' == `level1'
                        local _smd_wtot1 = r(sum)
                        qui su `wt' if `varnum' == `_clv' & `groupnum' == `level1'
                        local _smd_p1 = r(sum) / `_smd_wtot1'
                        qui su `wt' if `groupnum' == `level2'
                        local _smd_wtot2 = r(sum)
                        qui su `wt' if `varnum' == `_clv' & `groupnum' == `level2'
                        local _smd_p2 = r(sum) / `_smd_wtot2'
                        local _smd_pavg = (`_smd_p1' + `_smd_p2') / 2
                        local _smd_denom = sqrt(`_smd_pavg' * (1 - `_smd_pavg'))
                        if `_smd_denom' > 0 {
                            local _smd_ssq = `_smd_ssq' + ((`_smd_p1' - `_smd_p2') / `_smd_denom')^2
                        }
                    }
                    local _smd_val = sqrt(`_smd_ssq')
                }

                /* Calculate frequencies by group */
                if "`total'" != "" {
                    qui expand 2, gen(_copy)  // Duplicate for total calculation
                    qui replace `groupnum' = `_total_code' if _copy == 1  // Mark total rows
                }
                if `has_wt' {
                    // Weighted frequencies: sum weights per cell, count observations
                    gen double _wt_val = `wt'
                    collapse (sum) _freq=_wt_val (count) _uwn=_wt_val, by(`varnum' `groupnum')
                    fillin `varnum' `groupnum'
                    qui replace _freq = 0 if _fillin
                    qui replace _uwn = 0 if _fillin
                    drop _fillin
                    qui egen tot = total(_freq), by(`groupnum')
                    qui egen _uwn_grp = total(_uwn), by(`groupnum')
                }
                else {
                    qui contract `varnum' `groupnum' [`weight'`exp'], zero
                    qui egen tot=total(_freq), by(`groupnum')
                }
                
                /* Calculate row percentages if requested */
                if "`catrowperc'" != "" {
                    tempvar tot_alt coltot
                    qui egen `tot_alt' = total(_freq), by(`varnum')  // Total by variable level (row)
                    if "`total'" != "" qui replace `tot_alt' = `tot_alt'/2  // Adjust for duplicated data
                    qui gen `coltot' = tot  // Store original totals
                    qui replace tot = `tot_alt'  // Use row totals instead
                }
                
                /* Set percentage format */
                if "`varformat'"=="" {
                    if "`percformat'"=="" {
                        // Choose format based on totals
                        sum tot, meanonly
                        if r(max)<100 local varformat "%3.0f"  // Small samples
                        else local varformat "%5.1f"  // Larger samples
                    }
                    else local varformat `percformat'  // Use specified format
                }                

                /* Format results for display */
                qui gen perc=string(100*_freq/tot, "`varformat'")  // Calculate and format percentage
                
                /* Add leading space for percentages <10% for alignment */
                if `"`nospacelowpercent'"' == "" & `"`extraspace'"' == "" {
                    // Add space for single-digit percentages for alignment
                    qui replace perc= " " + perc if 100*_freq/tot < 10 & perc!="10" & perc!="10.0" & perc!="10.00"
                }
                if `"`nospacelowpercent'"' == "" & `"`extraspace'"' != "" {
                    // Add extra space with extraspace option
                    qui replace perc= "  " + perc if 100*_freq/tot < 10 & perc!="10" & perc!="10.0" & perc!="10.00"
                }
                
                qui replace perc= perc + `percsign'  // Add percent sign

                // Format count: use unweighted n when wt() specified
                if `has_wt' {
                    qui gen n_ = string(_uwn, "`nformat'")
                    if `"`slashN'"' == "slashN" qui replace n_ = n_ + "/" + string(_uwn_grp, "`nformat'")
                }
                else {
                    qui gen n_ = string(_freq, "`nformat'")
                    if `"`slashN'"' == "slashN" qui replace n_ = n_ + "/" + string(tot, "`nformat'")
                }

                /* Format display based on options */
                if "`percent_n'"=="" & "`percent'"=="" {
                    // Standard format: n (%)
                    qui gen _columna_ = n_
                    qui gen _columnb_ = "(" + perc + ")"
                }
                else qui gen _columna_ = perc  // % first if percent_n specified

                if "`percent_n'"=="percent_n" & "`percent'"=="" qui gen _columnb_ = "(" + n_ + ")"  // Format as % (n)
                if "`percent'"=="percent" qui gen _columnb_ = ""  // Show percentage only

                qui gen n_perc = _columna_ + " " + _columnb_  // Combine n and %

                label var _columna_ "columna"
                label var _columnb_ "columnb"

                /* Restore total if using row percentages */
                if "`catrowperc'" != "" {
                    qui replace tot = `coltot'  // Restore original column totals
                    drop `coltot'
                    capture drop `tot_alt'  // Drop row-total tempvar to prevent it leaking into reshape
                }
                if `has_wt' {
                    drop tot _uwn
                    rename _uwn_grp N_
                }
                else {
                    rename tot N_
                }
                label var N_ "N"

                drop _freq perc n_
                qui reshape wide n_perc _columna_ _columnb_ N_, i(`varnum') j(`groupnum')
                rename n_perc* `groupnum'*  // Rename columns by group
                
                /* Format display of factor and level variables */
                    /* Add new observation for variable name and p-value */
                    qui set obs `=_N + 1'
                    tempvar reorder
                    qui gen `reorder'=1 in L  // Flag new observation
                    sort `reorder' `varnum'  // Sort to put it at the top
                    drop `reorder'

                    // Copy N values to first row
                    foreach v of var N_* {
                        qui replace `v' = `v'[_n+1] if _n==1
                    }

                    // Format labels for single column display
                    qui gen factor="`varlab', `percfootnote2'" if _n==1  // First row gets variable name and footnote
                    if `"`varlabplus'"' == "" qui replace factor="`varlab'" if _n==1  // Simple label if varlabplus not used
                    qui replace factor="   " + string(`varnum') if _n!=1  // Indent levels with numeric value
                    qui gen factor_sep="`varlab'"  // For neat separation

                    // Replace numeric levels with value labels if available
                    qui levelsof `varnum', local(levels)
                    foreach level of local levels {
                        qui replace factor="   `: label (`varnum') `level''" if `varnum'==`level'
                    }
                    qui replace factor="   Missing" if `varnum'==. & _n!=1  // Label for missing values

                /* Add p-value, test type, and statistics (skipped when weighted) */
                qui gen cat_not_top_row = 1 if _n!=1
                if `nglevels'>1 & `nvlevels'>1 & !`has_wt' {
                    qui gen p=`p' if _n==1
                }

                if `has_smd' qui gen smd_val = `_smd_val' if _n==1

                // Show N only in first row
                foreach v of var N_* {
                    qui replace `v' = . if _n!=1
                }

                // Add test type and statistic labels if requested
                if "`test'"=="test" & `nglevels'>1 & `nvlevels'>1 & !`has_wt' {
                    if "`vartype'"=="cat" qui gen test="Chi-square" if _n==1
                    else qui gen test="Fisher's exact" if _n==1
                }
                if "`statistic'"=="statistic" & `nglevels'>1 & `nvlevels'>1 & !`has_wt' {
                    if "`vartype'"=="cat" qui gen statistic="Chi2(`df')=`chi2'" if _n==1
                    else qui gen statistic="N/A" if _n==1
                }                
                
                /* Add sort variables and append to results */
                gen sort1=`sortorder++'
                qui gen sort2=_n
                qui drop `varnum'
                qui append using "`resultstable'"
                qui save "`resultstable'", replace
                if "`dots'" != "" noisily display as text "." _continue
                restore
            }
    
        **## Process Binary Variables
            if "`vartype'"=="bin" | "`vartype'"=="bine" {
                preserve
                qui keep if `touse'  // Keep relevant observations
                qui drop if missing(`groupnum') | missing(`varname')  // Drop observations with missing values
                
                qui count
                if r(N)==0 {
                    display as error "no categories for `varname' ... cannot tabulate"
                    exit 198
                }

                /* Verify variable is truly binary (0/1) */
                capture assert `varname'==0 | `varname'==1
                if _rc {
                    display as error "binary variable `varname' must be 0 (negative) or 1 (positive)"
                    display as error "Did you mean {it:cat}? Use vars(`varname' cat) for categorical"
                    exit 198
                }

                // Count groups with non-missing values
                qui levelsof `groupnum' if `varname'!=., local(glevels)
                local nglevels: word count `glevels'
                qui levelsof `varname', local(vlevels)
                local nvlevels: word count `vlevels'
                
                /* Calculate significance test (suppressed when wt() specified) */
                if !`has_wt' {
                    if "`vartype'"=="bin" & `nglevels'>1 & `nvlevels'>1 {
                        // Chi-square test for standard binary
                        qui tab `varname' `groupnum' [`weight'`exp'], chi2
                        local p=r(p)  // p-value
                        local chi2 : di %6.2f r(chi2)  // Chi-square statistic
                        local df = (r(r)-1)*(r(c)-1)  // Degrees of freedom

                        * Track tests used (C5)
                        local _used_chi2 1
                    }
                    if "`vartype'"=="bine" & `nglevels'>1 & `nvlevels'>1 {
                        // Fisher's exact test for bine type
                        qui tab `varname' `groupnum' [`weight'`exp'], exact
                        local p=r(p_exact)

                        * Track tests used (C5)
                        local _used_fisher 1
                    }

                    /* Compute SMD for binary vars (F1) */
                    if `has_smd' & `nglevels' >= 2 {
                        qui su `varname' if `groupnum' == `level1'
                        local _smd_p1 = r(mean)
                        qui su `varname' if `groupnum' == `level2'
                        local _smd_p2 = r(mean)
                        local _smd_denom = sqrt((`_smd_p1'*(1-`_smd_p1') + `_smd_p2'*(1-`_smd_p2')) / 2)
                        if `_smd_denom' > 0 local _smd_val = (`_smd_p1' - `_smd_p2') / `_smd_denom'
                    }
                }

                /* Compute weighted SMD for binary vars when wt() is active */
                if `has_wt' & `has_smd' & `nglevels' >= 2 {
                    local _smd_val .
                    qui su `varname' [aw=`wt'] if `groupnum' == `level1'
                    local _smd_p1 = r(mean)
                    qui su `varname' [aw=`wt'] if `groupnum' == `level2'
                    local _smd_p2 = r(mean)
                    local _smd_denom = sqrt((`_smd_p1'*(1-`_smd_p1') + `_smd_p2'*(1-`_smd_p2')) / 2)
                    if `_smd_denom' > 0 local _smd_val = (`_smd_p1' - `_smd_p2') / `_smd_denom'
                }

                /* Calculate frequencies by group */
                if "`total'" != "" {
                    qui expand 2, gen(_copy)  // Duplicate for total calculation
                    qui replace `groupnum' = `_total_code' if _copy == 1  // Mark total rows
                }
                if `has_wt' {
                    // Weighted frequencies: sum weights per cell, count observations
                    gen double _wt_val = `wt'
                    collapse (sum) _freq=_wt_val (count) _uwn=_wt_val, by(`varname' `groupnum')
                    fillin `varname' `groupnum'
                    qui replace _freq = 0 if _fillin
                    qui replace _uwn = 0 if _fillin
                    drop _fillin
                    qui egen tot = total(_freq), by(`groupnum')
                    qui egen _uwn_grp = total(_uwn), by(`groupnum')
                }
                else {
                    qui contract `varname' `groupnum' [`weight'`exp'], zero
                    qui egen tot=total(_freq), by(`groupnum')
                }

                /* Set percentage format */
                if "`varformat'"=="" {
                    if "`percformat'"=="" {
                        // Choose format based on totals
                        sum tot, meanonly
                        if r(max)<100 local varformat "%3.0f"  // Small samples
                        else local varformat "%5.1f"  // Larger samples
                    }
                    else local varformat `percformat'  // Use specified format
                }

                /* Keep only the positive (=1) category */
                qui count if `varname'==1
                if r(N) > 0 qui keep if `varname'==1  // Keep only positive cases
                if r(N) == 0 qui replace _freq = 0 if _freq > 0  // Handle case where no positives exist

                /* Format results for display */
                qui gen perc=string(100*_freq/tot, "`varformat'")  // Calculate and format percentage

                /* Add leading space for percentages <10% for alignment */
                if "`nospacelowpercent'" == "" {
                    // Add space for single-digit percentages for alignment
                    qui replace perc= " " + perc if 100*_freq/tot < 10 & perc!="10" & perc!="10.0" & perc!="10.00"
                }

                qui replace perc= perc + `percsign'  // Add percent sign

                // Format count: use unweighted n when wt() specified
                if `has_wt' {
                    qui gen n_ = string(_uwn, "`nformat'")
                    if `"`slashN'"' == "slashN" qui replace n_ = n_ + "/" + string(_uwn_grp, "`nformat'")
                }
                else {
                    qui gen n_ = string(_freq, "`nformat'")
                    if `"`slashN'"' == "slashN" qui replace n_ = n_ + "/" + string(tot, "`nformat'")
                }

                /* Format display based on options */
                if "`percent_n'"=="" & "`percent'"=="" {
                    // Standard format: n (%)
                    qui gen _columna_ = n_
                    qui gen _columnb_ = "(" + perc + ")"
                }
                else qui gen _columna_ = perc  // % first if percent_n specified

                if "`percent_n'"=="percent_n" & "`percent'"=="" qui gen _columnb_ = "(" + n_ + ")"  // Format as % (n)
                if "`percent'"=="percent" qui gen _columnb_ = ""  // Show percentage only

                qui gen n_perc = _columna_ + " " + _columnb_  // Combine n and %

                label var _columna_ "columna"
                label var _columnb_ "columnb"
                if `has_wt' {
                    drop tot _uwn
                    rename _uwn_grp N_
                }
                else {
                    rename tot N_
                }
                label var N_ "N"

                drop _freq perc n_
                qui reshape wide n_perc _columna_ _columnb_ N_, i(`varname') j(`groupnum')
                qui drop `varname'
                qui gen factor="`varlab', `percfootnote'" if _n==1  // Row label with footnote
                if `"`varlabplus'"' == "" qui replace factor="`varlab'" if _n==1  // Simple label if varlabplus not used                
                qui clonevar factor_sep=factor  // Copy for formatting
                rename n_perc* `groupnum'*  // Rename columns by group

                /* Add p-value, test type, and statistics (skipped when weighted) */
                if `nglevels'>1 & `nvlevels'>1 & !`has_wt' {
                    qui gen p=`p'
                }

                if `has_smd' qui gen smd_val = `_smd_val'

                // Add test type and statistic labels if requested
                if "`test'"=="test" & `nglevels'>1 & `nvlevels'>1 & !`has_wt' {
                    if "`vartype'"=="bin" qui gen test="Chi-square"
                    else qui gen test="Fisher's exact"
                }
                if "`statistic'"=="statistic" & `nglevels'>1 & `nvlevels'>1 & !`has_wt' {
                    if "`vartype'"=="bin" qui gen statistic="Chi2(`df')=`chi2'"
                    else qui gen statistic="N/A"
                }

                /* Add sort variable and append to results */
                gen sort1=`sortorder++'
                qui append using "`resultstable'"
                qui save "`resultstable'", replace
                if "`dots'" != "" noisily display as text "." _continue
                restore
            }            
        }
        gettoken arg rest : rest, parse("\")  // Get next variable specification
    }
    if "`dots'" != "" display ""

    * wtcompare: save crude pass results and close the two-pass loop
    if `has_wtcompare' & "`_wtc_pass'" == "crude" {
        qui {
            preserve
            use "`resultstable'", clear
            save "`_wtc_crude_table'", replace
            restore
        }
    }

    } // end foreach _wtc_pass

    * Restore has_wt and has_smd after two-pass loop
    local has_wt `_wtc_save_has_wt'
    local has_smd `_wtc_save_has_smd'

    * wtcompare: merge crude columns into the weighted resultstable
    if `has_wtcompare' {
        qui {
            * Load crude results and rename group columns with _cr_ prefix
            preserve
            use "`_wtc_crude_table'", clear

            * Build full list of group levels including total sentinel
            local _wtc_merge_levels "`_group_levels'"
            if "`total'" != "" local _wtc_merge_levels "`_wtc_merge_levels' `_total_code'"

            foreach lv of local _wtc_merge_levels {
                capture rename `groupnum'`lv' _cr_`lv'
                capture rename _columna_`lv' _cr_columna_`lv'
                capture rename _columnb_`lv' _cr_columnb_`lv'
                capture rename N_`lv' _cr_N_`lv'
            }

            * Keep only crude group columns and merge keys
            capture confirm variable sort2
            if _rc gen sort2 = 0
            keep sort1 sort2 _cr_*

            tempfile _wtc_cr_renamed
            save "`_wtc_cr_renamed'", replace
            restore

            * Merge crude columns into the weighted resultstable
            preserve
            use "`resultstable'", clear

            * Ensure sort2 exists in both for safe merge
            capture confirm variable sort2
            if _rc gen sort2 = 0
            save "`resultstable'", replace

            use "`_wtc_cr_renamed'", clear
            capture confirm variable sort2
            if _rc gen sort2 = 0
            save "`_wtc_cr_renamed'", replace

            use "`resultstable'", clear
            merge 1:1 sort1 sort2 using "`_wtc_cr_renamed'", nogenerate

            save "`resultstable'", replace
            restore
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
    qui use "`resultstable'", clear

    /* Restore value labels if available */
    capture do "`labels'"
    
    /* Set up total column label */
    if "`total'" != "" { 
        if "`vallab'"=="" local vallab "beatles"  // Create arbitrary label name if none exists
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
                qui replace factor = "  Missing" in `_new'
                qui replace factor_sep = factor_sep[`_obs'] in `_new'
                capture replace sort1 = sort1[`_obs'] in `_new'
                capture replace sort2 = 9999 in `_new'
                foreach _lv of local levels {
                    local _mval = m_`_lv'[`_obs']
                    if !missing(`_mval') & `_mval' > 0 {
                        local _mpct = string(`_mval' / `_max_n_`_lv'' * 100, "%5.1f")
                        local _mstr = string(`_mval', "`nformat'") + " (" + "`_mpct'" + "%)"
                        qui replace `groupnum'`_lv' = "`_mstr'" in `_new'
                    }
                    else {
                        qui replace `groupnum'`_lv' = "0" in `_new'
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
    
    /* Format p-values (skipped when wt() specified) */
    if `groupcount'>1 & !`has_wt' {
        cap gen p = .  // Create p-value variable if it doesn't exist
        
        // Format p-values according to their magnitude and specified decimal places
        qui gen pvalue=string(p, "%`=`highpdp'+2'.`highpdp'f") if !missing(p)  // Standard format for high p-values
        qui replace pvalue=string(p, "%`=`pdp'+2'.`pdp'f") if p<0.10  // More decimal places for low p-values

        // Cap p-values so they never display as 1.00
        local pmax = 1 - 10^(-`highpdp')
        qui replace pvalue=string(`pmax', "%`=`highpdp'+2'.`highpdp'f") if p>`pmax' & !missing(p)

        // Handle very small p-values
        local pmin=10^-`pdp'  // Minimum p-value to show numerically
        qui replace pvalue="<" + string(`pmin', "%`=`pdp'+2'.`pdp'f") if p<`pmin'  // Show as <0.001 etc.
        
        // Add space for alignment
        qui replace pvalue=" " + pvalue if p>=`pmin' & pvalue != ""
        
        lab var pvalue "p-value"  // Label p-value column
    }
    
    /* Format SMD column if present */
    if `has_smd' {
        capture confirm variable smd_val
        if !_rc {
            qui gen smd_str = string(abs(smd_val), "%5.3f") if !missing(smd_val)
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
        if "`var'" != "level" capture replace `var'="`: var lab `var''" in `newN'
    }
    qui replace sort1=0 in `newN'  // Set sort order to ensure header is first

    /* Sort rows and drop unneeded variables */
    sort sort*  // Sort by primary and secondary sort variables

    drop sort*  // Remove sort variables
    * Preserve raw numeric p-values for boldp/highlight formatting
    capture gen double _p_raw = p
    capture drop p  // Drop raw p-value variable
    * Preserve raw SMD values for conditional formatting (O2)
    capture gen double _smd_raw = abs(smd_val)
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
                local _wtc_suffixes "`_wtc_suffixes' `lv'"
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
                local _wtc_lab "`by' = `sfx'"
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
        capture order smd_str, last

        * Update header row values to match new labels
        foreach sfx of local _wtc_suffixes {
            capture replace Cr_`sfx' = "`: var lab Cr_`sfx''" if _n == 1
            capture replace Wt_`sfx' = "`: var lab Wt_`sfx''" if _n == 1
        }
    }

    /* Position total column if requested */
    if "`total'" == "before" {
        tokenize `levels'
        local first `1'
        cap order `by'_T, before(`by'_`first')  // Move total before first group
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

    /* Format N and missing counts */
    format `nformat' N_* m_*  // Apply count format to N and m columns
    capture su cat_not_top_row  // Check if categorical variables exist
    cap drop cat_not_top_row  // Remove helper variable
    qui replace factor = "" if factor == "N"  // Clean up factor labels
    qui replace factor = " " if factor == "Factor "  // Clean up header
    
    /* Add percentages to header if requested */
    if "`headerperc'" != "" {
        qui {
            // Build list of renamed group columns to process.
            local hperc_cols ""
            foreach gl of local levels {
                if "`gl'" == "`_total_code'" {
                    local hperc_cols "`hperc_cols' T"
                }
                else {
                    local hperc_cols "`hperc_cols' `gl'"
                }
            }

            // Process each group column (including total if present)
            foreach gl in `hperc_cols' {
                replace `by'_`gl' = subinstr(`by'_`gl',"N=","",.)  // Remove N= prefix
                gen `by'_`gl'2 = subinstr(`by'_`gl',",","",.)  // Clean up for conversion
                destring `by'_`gl'2, replace force  // Convert to numeric
            }

            // Calculate total denominator (sum of all groups) if total column not present
            if "`total'" == "" {
                capture egen `by'_T2 = rowtotal(`by'_*2) if inlist(_n,2)  // Sum all groups for denominator
            }

            // Add percentage of total to each group label
            foreach gl in `hperc_cols' {
                capture replace `by'_`gl' = `by'_`gl' + " " + "(" + string(round(`by'_`gl'2/`by'_T2,0.001)*100,"%9.1f") + `percsign' + ")" if inlist(_n,2)
                capture drop `by'_`gl'2
            }

            if "`total'" == "" {
                capture drop `by'_T2
            }

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
        
        if `_resolved_has_contn' {
            local cont_parts = "Mean (SD)"
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
        replace factor = "`header_parts'" if _n == 2
    }
    local _descriptor_row_text `"`header_parts'"'

    /* Display the table */
    qui ds factor_sep _* N_* m_*, not
    list `r(varlist)', sepby(factor_sep) noobs noheader table  // Show table with separators between variables
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
            local ycont "`meanSD' or `gmeanSD'"
        }
        else if "`ycontn'" == "1" & "`ycontln'" != "1" & "`yconts'" == "1" {
            local ycont "`meanSD' or median (Q1, Q3)"
        }
        else if "`ycontn'" != "1" & "`ycontln'" == "1" & "`yconts'" == "1" {
            local ycont "`gmeanSD' or median (Q1, Q3)"
        }
        else if "`ycontn'" == "1" & "`ycontln'" != "1" & "`yconts'" != "1" {
            local ycont "`meanSD'"
        }
        else if "`ycontn'" != "1" & "`ycontln'" == "1" & "`yconts'" != "1" {
            local ycont "`gmeanSD'"
        }
        else if "`ycontn'" != "1" & "`ycontln'" != "1" & "`yconts'" == "1" {
            local ycont "median (Q1, Q3)"
        }
        
        /* Build complete description with both continuous and categorical */
        if "`ycont'" != "" & "`ycatbin'" !="" {
            local ymix "`ycont' for continuous measures, and `percfootnote' for categorical measures"
        }
        else if "`ycont'" != "" & "`ycatbin'" =="" {
            local ymix "`ycont'"
        }
        else if "`ycont'" == "" & "`ycatbin'" !="" {
            local ymix "`percfootnote'"
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
        else {
            local Dapa "Data are presented as `ymix'."
        }
        if `"`varlabplus'"' == "" {
            display "`Dapa'"
        }
        return local Dapa "`Dapa'"
        display " "

        /* Build extended methods paragraph (C5) */
        if "`by'" != "" & !`has_wt' {

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
            local _methods "`_methods' `Dapa'"
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
    capture confirm variable _p_raw
    local _has_praw = !_rc
    capture confirm variable _smd_raw
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
                        capture {
                            local _pval = _p_raw[`_obs']
                            if `_pval' < . matrix `_rtable'[`_rt_r', `_rt_c'] = `_pval'
                        }
                    }
                    if `_has_smdraw' {
                        local _rt_c = `_rt_c' + 1
                        capture {
                            local _sval = _smd_raw[`_obs']
                            if `_sval' < . matrix `_rtable'[`_rt_r', `_rt_c'] = `_sval'
                        }
                    }
                    * Clean variable name for row label
                    local _rname = subinstr("`_fval'", ".", "_", .)
                    local _rname = subinstr("`_rname'", " ", "_", .)
                    local _rname = subinstr("`_rname'", ",", "", .)
                    local _rname = substr("`_rname'", 1, 32)
                    if "`_rname'" == "" local _rname "row`_rt_r'"
                    local _rt_rnames "`_rt_rnames' `_rname'"
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

    local _xlsx_ok 0
    if "`excel'" != "" {
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
            replace title = "`title'" if _n == 1  // Set title text
            
            /* Add p-value header */
            capture replace pvalue = "p-value" if _n == 2  // Label p-value column
            capture replace pvalue = "" if _n == 3  // Clear row 3
			
			/* Create column format headers based on variable types */
			local header_parts = ""
			local part_count = 0
			
			/* Get clean version of iqrmiddle for header */
			local iqrmiddle = substr(`"`iqrmiddle'"', 2, length(`"`iqrmiddle'"') - 2)

			/* Add categorical formats if present */
			if `_resolved_has_cat' {
				if `part_count' > 0 local header_parts = "`header_parts', "
				
				if "`catrowperc'" != "" {
					if "`percent_n'" == "percent_n" {
						local header_parts = "`header_parts'Row % (No.)"
					} 
					else {
						local header_parts = "`header_parts'No. (Row %)"
					}
				}
				else {
					if "`percent_n'" == "percent_n" {
						local header_parts = "`header_parts'Column % (No.)"
					}
					else {
						local header_parts = "`header_parts'No. (Column %)"
					}
				}
				local part_count = `part_count' + 1
			}
			
			/* Add binary format if present and different from categorical */
			if `_resolved_has_bin' & (!`_resolved_has_cat' | "`catrowperc'" != "") {
				if `part_count' > 0 local header_parts = "`header_parts', "
				
				if "`percent_n'" == "percent_n" {
					local header_parts = "`header_parts'Column % (No.)"
				}
				else {
					local header_parts = "`header_parts'No. (Column %)"
				}
			}
			
			/* Override format description if percent option specified */
			if "`percent'" == "percent" {
				local header_parts = ""
				local part_count = 0
				
				if `_resolved_has_contn' | `_resolved_has_contln' | `_resolved_has_conts' {
					if `_resolved_has_contn' {
						local header_parts = "Mean (SD)"
						local part_count = 1
					}
					if `_resolved_has_contln' {
						if `part_count' > 0 local header_parts = "`header_parts', "
						local header_parts = "`header_parts'Geometric mean (×/GSD)"
						local part_count = `part_count' + 1
					}
					if `_resolved_has_conts' {
						if `part_count' > 0 local header_parts = "`header_parts', "
						local header_parts = "`header_parts'Median (Q1`iqrmiddle'Q3)"
						local part_count = `part_count' + 1
					}
					
					if `_resolved_has_cat' | `_resolved_has_bin' {
						if `part_count' > 0 local header_parts = "`header_parts', "
						
						if `_resolved_has_cat' & "`catrowperc'" != "" {
							local header_parts = "`header_parts'Row %"
							if `_resolved_has_bin' local header_parts = "`header_parts', Column %"
						}
						else {
							local header_parts = "`header_parts'Column %"
						}
					}
				}
				else {
					if `_resolved_has_cat' & "`catrowperc'" != "" {
						local header_parts = "Row %"
						if `_resolved_has_bin' local header_parts = "`header_parts', Column %"
					}
					else {
						local header_parts = "Column %"
					}
				}
			}
			
			/* Add continuous variable formats if present */
			if `_resolved_has_contn' {
				if `part_count' > 0 local header_parts = "`header_parts', "
				local header_parts = "`header_parts'Mean (SD)"
				local part_count = `part_count' + 1
			}
			
			if `_resolved_has_contln' {
				if `part_count' > 0 local header_parts = "`header_parts', "
				local header_parts = "`header_parts'Geometric mean (×/GSD)"
				local part_count = `part_count' + 1
			}
			
			if `_resolved_has_conts' {
				if `part_count' > 0 local header_parts = "`header_parts', "
				local header_parts = "`header_parts'Median (Q1`iqrmiddle'Q3)"
				local part_count = `part_count' + 1
			}
			
			/* Set header description in the table */
			replace factor = "`header_parts'" if _n == 2

            /* Export to Excel — exclude internal columns */
            capture confirm variable _p_raw
            if !_rc {
                mata: _p_raw_save = st_data(., "_p_raw")
                drop _p_raw
            }
            capture confirm variable _smd_raw
            if !_rc {
                mata: _smd_raw_save = st_data(., "_smd_raw")
                drop _smd_raw
            }
            * Safety: drop any surviving internal variables before export
            * (catrowperc + slashN can leave N_* or _uwn* columns)
            capture drop N_*
            capture drop _columna_*
            capture drop _columnb_*
            capture drop m_*
            capture drop _uwn*
            export excel using "`excel'", sheet("`sheet'") sheetreplace
            capture {
                gen double _p_raw = .
                mata: st_store(., "_p_raw", _p_raw_save)
                mata: mata drop _p_raw_save
            }
            capture {
                gen double _smd_raw = .
                mata: st_store(., "_smd_raw", _smd_raw_save)
                mata: mata drop _smd_raw_save
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
						local _data_cols "`_data_cols' `var'"
					}
				}
				else {
					foreach var of varlist `by'_* {
						local _data_cols "`_data_cols' `var'"
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
            * Build Excel column letter references
            *****************************************************************/
			qui desc
			local num_cols = `r(k)'  // Number of columns
			* Exclude internal columns from column count (not exported to Excel)
			capture confirm variable _p_raw
			if !_rc local num_cols = `num_cols' - 1
			capture confirm variable _smd_raw
			if !_rc local num_cols = `num_cols' - 1
			qui count
			local num_rows = `r(N)'  // Number of rows

            _tabtools_build_col_letters `num_cols'
            local col_letters = "`result'"
            
            /* Extract important column letters */
            local col1_letter: word 1 of `col_letters'  // First column
            local col2_letter: word 2 of `col_letters'  // Second column
            local lastcol_letter: word `num_cols' of `col_letters'  // Last column
            
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

            /* Get level_letter from level_pos */
            if `level_pos' > 0 {
                local level_letter: word `level_pos' of `col_letters'
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

            /* Get letters for formatting */
            local factor_letter: word 2 of `col_letters'  // Factor column letter

			local data_start_pos = 3

            local data_start_letter: word `data_start_pos' of `col_letters'  // First data column

            if `pvalue_pos' > 0 {
                local pvalue_letter: word `pvalue_pos' of `col_letters'  // p-value column letter
            }
            if `test_pos' > 0 {
                local test_letter: word `test_pos' of `col_letters'
            }
            if `statistic_pos' > 0 {
                local statistic_letter: word `statistic_pos' of `col_letters'
            }
            if `smd_pos' > 0 {
                local smd_letter: word `smd_pos' of `col_letters'
            }

            /*****************************************************************
            * Apply all Excel formatting in a single Mata xl() session
            *****************************************************************/

            * Pre-extract p-value and SMD data for conditional formatting
            if `has_boldp' | `has_highlight' {
                if `pvalue_pos' > 0 {
                    forvalues _br = 4/`num_rows' {
                        capture local _pval_`_br' = _p_raw[`_br']
                        if _rc local _pval_`_br' = .
                    }
                }
            }
            if `smd_pos' > 0 & `smdthreshold' > 0 {
                forvalues _sr = 4/`num_rows' {
                    capture local _sval_`_sr' = _smd_raw[`_sr']
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
                mata: b = xl()
                mata: b.load_book("`excel'")
                mata: b.set_sheet("`sheet'")

                * Column widths and row heights
                mata: b.set_row_height(1, 1, 30)
                local _hdr_len = strlen(`"`header_parts'"')
                if `_hdr_len' > `factorwidth' * 1.2 {
                    local _hdr_lines = ceil(`_hdr_len' / (`factorwidth' * 1.2))
                    local _hdr_height = `_hdr_lines' * 15
                    mata: b.set_row_height(2, 2, `_hdr_height')
                }
                mata: b.set_column_width(1, 1, 1)
                mata: b.set_column_width(2, 2, `factorwidth')
                forvalues _wc = 3/`num_cols' {
                    mata: b.set_column_width(`_wc', `_wc', `datawidth')
                }
                if `pvalue_pos' > 0 {
                    mata: b.set_column_width(`pvalue_pos', `pvalue_pos', 10)
                }
                if `test_pos' > 0 {
                    mata: b.set_column_width(`test_pos', `test_pos', `_test_width')
                }
                if `statistic_pos' > 0 {
                    mata: b.set_column_width(`statistic_pos', `statistic_pos', `_stat_width')
                }
                if `smd_pos' > 0 {
                    mata: b.set_column_width(`smd_pos', `smd_pos', 8)
                }

                * Font for entire table (single row-range call)
                mata: b.set_font((1,`num_rows'), (1,`num_cols'), "`_font'", `_fontsize')
                mata: b.set_font((1,1), (1,`num_cols'), "`_font'", `=`_fontsize'+2')

                * Title row: merge + format
                mata: b.set_sheet_merge("`sheet'", (1,1), (1,`num_cols'))
                mata: b.set_text_wrap(1, 1, "on")
                mata: b.set_horizontal_align(1, 1, "left")
                mata: b.set_vertical_align(1, 1, "center")
                mata: b.set_font_bold(1, 1, "on")

                * Header rows: merge factor column across rows 2-3
                mata: b.set_sheet_merge("`sheet'", (2,3), (2,2))
                mata: b.set_horizontal_align((2,3), 2, "center")
                mata: b.set_vertical_align((2,3), 2, "center")
                mata: b.set_text_wrap((2,3), 2, "on")
                mata: b.set_font_bold((2,3), 2, "on")

                * Level column header merge (if exists)
                if `level_pos' > 0 {
                    mata: b.set_sheet_merge("`sheet'", (2,3), (`level_pos',`level_pos'))
                    mata: b.set_horizontal_align((2,3), `level_pos', "center")
                    mata: b.set_vertical_align((2,3), `level_pos', "center")
                    mata: b.set_text_wrap((2,3), `level_pos', "on")
                    mata: b.set_font_bold((2,3), `level_pos', "on")
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
                        mata: b.set_horizontal_align((2,3), `data_col', "center")
                        mata: b.set_vertical_align((2,3), `data_col', "center")
                        mata: b.set_text_wrap((2,3), `data_col', "on")
                        mata: b.set_font_bold((2,3), `data_col', "on")
                    }
                    local data_col = `data_col' + 1
                }

                * P-value column header merge
                if `pvalue_pos' > 0 {
                    mata: b.set_sheet_merge("`sheet'", (2,3), (`pvalue_pos',`pvalue_pos'))
                    mata: b.set_horizontal_align((2,3), `pvalue_pos', "center")
                    mata: b.set_vertical_align((2,3), `pvalue_pos', "center")
                    mata: b.set_text_wrap((2,3), `pvalue_pos', "on")
                    mata: b.set_font_bold((2,3), `pvalue_pos', "on")
                }

                * Test, statistic, SMD column header merges
                if `test_pos' > 0 {
                    mata: b.set_sheet_merge("`sheet'", (2,3), (`test_pos',`test_pos'))
                    mata: b.set_horizontal_align((2,3), `test_pos', "center")
                    mata: b.set_vertical_align((2,3), `test_pos', "center")
                    mata: b.set_text_wrap((2,3), `test_pos', "on")
                    mata: b.set_font_bold((2,3), `test_pos', "on")
                }
                if `statistic_pos' > 0 {
                    mata: b.set_sheet_merge("`sheet'", (2,3), (`statistic_pos',`statistic_pos'))
                    mata: b.set_horizontal_align((2,3), `statistic_pos', "center")
                    mata: b.set_vertical_align((2,3), `statistic_pos', "center")
                    mata: b.set_text_wrap((2,3), `statistic_pos', "on")
                    mata: b.set_font_bold((2,3), `statistic_pos', "on")
                }
                if `smd_pos' > 0 {
                    mata: b.set_sheet_merge("`sheet'", (2,3), (`smd_pos',`smd_pos'))
                    mata: b.set_horizontal_align((2,3), `smd_pos', "center")
                    mata: b.set_vertical_align((2,3), `smd_pos', "center")
                    mata: b.set_text_wrap((2,3), `smd_pos', "on")
                    mata: b.set_font_bold((2,3), `smd_pos', "on")
                }

                * Horizontal borders
                mata: b.set_top_border(2, (2,`num_cols'), "`_hborder'")
                mata: b.set_top_border(4, (2,`num_cols'), "`_hborder'")
                mata: b.set_bottom_border(`num_rows', (2,`num_cols'), "`_hborder'")

                * Vertical borders (skip for academic)
                if "`borderstyle'" != "academic" {
                    mata: b.set_left_border((2,`num_rows'), 2, "`_hborder'")
                    mata: b.set_right_border((2,`num_rows'), 2, "`_hborder'")
                    mata: b.set_right_border((2,`num_rows'), `num_cols', "`_hborder'")
                }

                * Total column borders
                if `total_col_pos' > 0 {
                    mata: b.set_left_border((2,`num_rows'), `total_col_pos', "`_hborder'")
                    mata: b.set_right_border((2,`num_rows'), `total_col_pos', "`_hborder'")
                }

                * P-value column left border
                if `pvalue_pos' > 0 & "`borderstyle'" != "academic" {
                    mata: b.set_left_border((2,`num_rows'), `pvalue_pos', "`_hborder'")
                }

                * Test/statistic/SMD column left borders
                if `test_pos' > 0 & "`borderstyle'" != "academic" {
                    mata: b.set_left_border((2,`num_rows'), `test_pos', "`_hborder'")
                }
                if `statistic_pos' > 0 & "`borderstyle'" != "academic" {
                    mata: b.set_left_border((2,`num_rows'), `statistic_pos', "`_hborder'")
                }
                if `smd_pos' > 0 & "`borderstyle'" != "academic" {
                    mata: b.set_left_border((2,`num_rows'), `smd_pos', "`_hborder'")
                }

                * Header background
                if "`headershade'" != "" {
                    mata: b.set_fill_pattern((2,3), (2,`num_cols'), "solid", "`_headercolor'")
                }

                * Center-align data columns
                if `num_rows' >= 4 {
                    mata: b.set_horizontal_align((4,`num_rows'), (`data_start_pos',`num_cols'), "center")
                }

                * Zebra striping
                if "`zebra'" != "" {
                    forvalues _zr = 5(2)`num_rows' {
                        mata: b.set_fill_pattern(`_zr', (2,`num_cols'), "solid", "`_zebracolor'")
                    }
                }

                * Bold significant p-values
                if `has_boldp' & `pvalue_pos' > 0 {
                    forvalues _br = 4/`num_rows' {
                        if `_pval_`_br'' < . & `_pval_`_br'' < `boldp' {
                            mata: b.set_font_bold(`_br', `pvalue_pos', "on")
                        }
                    }
                }

                * Highlight significant rows
                if `has_highlight' & `pvalue_pos' > 0 {
                    forvalues _hr = 4/`num_rows' {
                        if `_pval_`_hr'' < . & `_pval_`_hr'' < `highlight' {
                            mata: b.set_fill_pattern(`_hr', (2,`num_cols'), "solid", "255 255 204")
                        }
                    }
                }

                * SMD conditional formatting
                if `smd_pos' > 0 & `smdthreshold' > 0 {
                    forvalues _sr = 4/`num_rows' {
                        if `_sval_`_sr'' < . & `_sval_`_sr'' > `smdthreshold' {
                            mata: b.set_font_bold(`_sr', `smd_pos', "on")
                            mata: b.set_fill_pattern(`_sr', `smd_pos', "solid", "255 235 205")
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

            /* Clean up temporary p-value and SMD variables */
            capture drop _p_raw
            capture drop _smd_raw

            capture confirm file "`excel'"
            if _rc {
                noisily display as error "Export command succeeded but file not found"
                restore
                exit 601
            }
            local _xlsx_ok 1

        }
    }

    /* Keep internal raw columns out of public outputs */
    capture drop _p_raw
    capture drop _smd_raw

    * CSV export (F2)
    if "`csv'" != "" {
        _tabtools_validate_path "`csv'" "csv()"
        export delimited using "`csv'", replace
        display as text "CSV exported to `csv'"
    }

**#  Store output in frame if requested (I5)
    if `"`frame'"' != "" {
        _tabtools_frame_put `"`frame'"'
        local frame "`_frame_name'"
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

    /* Open file if requested (W3) */
    if "`open'" != "" & `_xlsx_ok' {
        _tabtools_open_file "`excel'"
    }

    capture mata: mata drop _p_raw_save
    capture mata: mata drop _smd_raw_save

    } // end capture noisily
    local _rc = _rc
    set varabbrev `_orig_varabbrev'
    if `_rc' exit `_rc'
end
