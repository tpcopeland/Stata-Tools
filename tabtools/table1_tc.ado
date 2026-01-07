*! table1_tc Version 1.0.3  05dec2025 - Descriptive Statistics Table Generator
*! Author: Tim Copeland
*! Fork of -table1_mc- version 3.5 (2024-12-19) by Mark Chatfield
*! This program generates descriptive statistics tables with formatting options
*! and can export them to Excel with automatic column width calculation

program define table1_tc, sclass
    version 16.0
    set varabbrev off

**# Syntax Definition
    syntax [if] [in] [fweight], ///
        [by(varname)]           /// Optional grouping variable
        vars(string)            /// Variables to display: varname vartype [varformat], vars delimited by \
        [ONEcol]                /// Only use 1 column to report categorical vars
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
        [sheet(string)]         /// Excel sheet name
        [title(string)]         /// Table title
        [clear]                 /// Keep resulting table in memory
        [percent_n]             /// Display as % (n) rather than n (%)
        [percsign(string asis)] /// Percent sign; default is "%"
        [NOSPACElowpercent]     /// Report e.g. (3%) rather than ( 3%)
        [extraspace]            /// Helps alignment in DOCX with non-monospaced fonts
        [pairwise123]           /// Add pairwise comparisons between groups
        [slashN]                /// Report n/N instead of n
        [total(string)]         /// Include total column ("before" or "after" group columns)
        [gurmeet]               /// Preset formatting options
        [catrowperc]            /// Report row % rather than column % for categorical vars
        [varlabplus]            /// Add data type description to variable labels
        [HEADERPerc]            /// Add percentage of total to sample size row
        [BORDERStyle(string)]   /// Border style: "default" or "thin"

**# Input Validation and Option Setup

    /* Validation: Check if vars() is specified */
    if "`vars'" == "" {
        display as error "vars() option required"
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

    // If Excel file is specified, both sheet and title are required
    if `has_excel' & (!`has_sheet' | !`has_title') {
        display as error "sheet() and title() are both required when using excel()"
        error 498
    }

    // sheet() and title() only make sense with excel()
    if !`has_excel' & (`has_sheet' | `has_title') {
        display as error "sheet() and title() are only available when using excel()"
        error 498
    }

    /* Validate Excel file path for security */
    if `has_excel' {
        if regexm("`excel'", "[;&|><\$\`]") {
            display as error "excel() contains invalid characters"
            error 198
        }
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

    // borderstyle must be either 'default' or 'thin'
    if `has_borderstyle' & !inlist("`borderstyle'", "default", "thin") {
        display as error "borderstyle() must be either 'default' or 'thin'"
        error 498
    }
    
    // Default border style if not specified
    if "`borderstyle'" == "" local borderstyle "default"
        
    /* Apply gurmeet preset if specified */
    if "`gurmeet'" == "gurmeet" {
        // Preset combination of formatting options
        local percformat "%5.1f"       // Percentage format
        local percent_n "percent_n"    // Display as % (n)
        local percsign `""""'          // No percent sign
        local iqrmiddle `"",""'        // Comma between Q1 and Q3
        local sdleft `"" [±""'         // Format before SD
        local sdright `""]""'          // Format after SD
        local gsdleft `"" [×/""'       // Format before GSD
        local gsdright `""]""'         // Format after GSD
        local onecol "onecol"          // Use one column for categorical vars
        local extraspace "extraspace"  // Add extra space for alignment
    }

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

    /* Mark observations to include in analysis */
    marksample touse  // Creates indicator variable for observations that satisfy if/in conditions

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
    }
    
    /* Validate the grouping variable */
    qui su `groupnum'
    // Check that grouping variable values are non-negative
    if `r(min)' < 0 {
        display as error "by() variable must be either (i) string, or (ii) numeric and contain only non-negative integers, whether or not a value label is attached"
        error 498
    }

    // Check if grouping variable contains the reserved value 919 (used for totals)
    qui count if `groupnum' == 919 & `touse'
    if `r(N)' > 0 {
        display as error "by() variable not allowed to take the value 919 due to internal coding. Please recode to any other non-negative integer."
        error 498
    }

    // Get unique values of the grouping variable
    qui levelsof `groupnum' if `touse', local(levels)

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
    
    /* Store specific group level values for potential pairwise comparisons */
    tokenize `levels'  // Parse levels into positional parameters
    local level1 `1'   // First group level value
    local level2 `2'   // Second group level value
    local level3 `3'   // Third group level value
    
    /* Create placeholder group variable if not specified */
    if "`by'"=="" local group `groupnum'

**# Generate Sample Size Row (N)
    preserve
    qui keep if `touse'  // Keep only observations that satisfy if/in conditions
    qui drop if missing(`groupnum')  // Drop observations with missing group values
    
    /* Create total column if requested */
    if "`total'" != "" { 
        qui expand 2, gen(_copy)  // Duplicate observations for total calculation
        qui replace `groupnum' = 919 if _copy == 1   // 919 as placeholder for total
    }
    
    /* Get counts by group */
    contract `groupnum' [`weight'`exp']  // Calculate frequencies by group
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

**# Process Variables Specified in vars() Option
    gettoken arg rest : vars, parse("\")  // Parse the first variable specification
    while `"`arg'"' != "" {
        if `"`arg'"' != "\" {
            local varname   : word 1 of `arg'  // Extract variable name
            local vartype   : word 2 of `arg'  // Extract variable type
            local varformat : word 3 of `arg'  // Extract custom format (if any)
            local varformat2 : word 4 of `arg'  // Extract second format (if any)            

            /* Validate variable and type */
            confirm variable `varname'  // Check that variable exists

            // Check that variable type is valid
            if !inlist("`vartype'", "contn", "contln", "conts", "cat", "cate", "bin", "bine") {
                display as error "-`varname' `vartype'- not allowed in vars() option"
                display as error "Variables must be classified as contn, contln, conts, cat, cate, bin or bine"
                error 498
            }
            
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
                
                /* Calculate significance test */
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
                    matrix T = r(table)
                    local tstat : di %6.2f -1*T[3,2]  // t statistic
                }

                /* Calculate pairwise comparisons if requested */
                if "`pairwise123'" == "pairwise123" & `nglevels' >1 {
                    // Group 1 vs Group 2
                    qui anova `varname' `groupnum' [`weight'`exp'] if `groupnum' == `level1' | `groupnum' == `level2'
                    local p12 = Ftail(e(df_m), e(df_r), e(F))

                    // Group 2 vs Group 3
                    qui anova `varname' `groupnum' [`weight'`exp'] if `groupnum' == `level2' | `groupnum' == `level3'
                    local p23 = Ftail(e(df_m), e(df_r), e(F))

                    // Group 1 vs Group 3
                    qui anova `varname' `groupnum' [`weight'`exp'] if `groupnum' == `level1' | `groupnum' == `level3'
                    local p13 = Ftail(e(df_m), e(df_r), e(F))
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
                    qui replace `groupnum' = 919 if _copy == 1  // Mark total rows
                }
                
                // Calculate mean, SD, and count by group
                collapse (mean) mean=`varname' (sd) sd=`varname' (count) N_=`varname' ///
                    [`weight'`exp'], by(`groupnum')
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
                
                /* Add p-value, test type, and statistics */
                if `nglevels'>1 qui {
                    gen p=`p'  // Add p-value
                    
                    // Add pairwise p-values if requested
                    if "`pairwise123'" == "pairwise123" {
                        qui gen p12=`p12'  // Group 1 vs 2
                        qui gen p23=`p23'  // Group 2 vs 3 
                        qui gen p13=`p13'  // Group 1 vs 3
                    }    
                }
                
                // Add test type label based on number of groups
                if "`test'"=="test" & `nglevels'==2 gen test="Ind. t test"  
                if "`test'"=="test" & `nglevels'>2 gen test="ANOVA"
                
                // Add test statistic details if requested
                if "`statistic'"=="statistic" & `nglevels'==2 gen statistic="t(`df2')=`tstat'"
                if "`statistic'"=="statistic" & `nglevels'>2 gen statistic="F(`df1',`df2')=`f'"    
                
                /* Add sort variable and append to results */
                gen sort1=`sortorder++'  // Increment sort order
                qui append using "`resultstable'"  // Add to results table
                qui save "`resultstable'", replace  // Save updated table
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
                
                /* Calculate significance test */
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
                    matrix T = r(table)
                    local tstat : di %6.2f -1*T[3,2]  // t statistic
                }

                /* Calculate pairwise comparisons if requested */
                if "`pairwise123'" == "pairwise123" & `nglevels' >1 {
                    // Group 1 vs Group 2
                    qui anova `lvarname' `groupnum' [`weight'`exp'] if `groupnum' == `level1' | `groupnum' == `level2'
                    local p12 = Ftail(e(df_m), e(df_r), e(F))

                    // Group 2 vs Group 3
                    qui anova `lvarname' `groupnum' [`weight'`exp'] if `groupnum' == `level2' | `groupnum' == `level3'
                    local p23 = Ftail(e(df_m), e(df_r), e(F))

                    // Group 1 vs Group 3
                    qui anova `lvarname' `groupnum' [`weight'`exp'] if `groupnum' == `level1' | `groupnum' == `level3'
                    local p13 = Ftail(e(df_m), e(df_r), e(F))
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
                    qui replace `groupnum' = 919 if _copy == 1  // Mark total rows
                }
                
                // Calculate mean, SD, and count of log-transformed values by group
                collapse (mean) mean=`lvarname' (sd) sd=`lvarname' (count) N_=`lvarname' ///
                    [`weight'`exp'], by(`groupnum')
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
                
                /* Add p-value, test type, and statistics */
                if `nglevels'>1 qui {
                    gen p=`p'  // Add p-value
                    
                    // Add pairwise p-values if requested
                    if "`pairwise123'" == "pairwise123" {
                        qui gen p12=`p12'  // Group 1 vs 2
                        qui gen p23=`p23'  // Group 2 vs 3 
                        qui gen p13=`p13'  // Group 1 vs 3
                    }
                }
            
                // Add test type label based on number of groups
                if "`test'"=="test" & `nglevels'==2 gen test="Ind. t test, logged data"  
                if "`test'"=="test" & `nglevels'>2 gen test="ANOVA, logged data"
                
                // Add test statistic details if requested
                if "`statistic'"=="statistic" & `nglevels'==2 gen statistic="t(`df2')=`tstat'"
                if "`statistic'"=="statistic" & `nglevels'>2 gen statistic="F(`df1',`df2')=`f'"
                
                /* Add sort variable and append to results */
                gen sort1=`sortorder++'  // Increment sort order
                qui append using "`resultstable'"  // Add to results table
                qui save "`resultstable'", replace  // Save updated table
                restore
            }
                        
        **## Process Continuous Skewed Variables
            if "`vartype'"=="conts" {
                preserve
                qui keep if `touse'  // Keep relevant observations
                qui drop if missing(`groupnum')  // Drop observations with missing group values

                /* Expand by frequency weight for rank-based tests */
                if "`weight'"=="fweight" qui expand `exp'
                
                // Count groups with non-missing values
                qui levelsof `groupnum' if `varname'!=., local(glevels)
                local nglevels: word count `glevels'
                
                /* Calculate significance test */
                if `nglevels'>2 {
                    /* Kruskal-Wallis for >2 groups */
                    cap kwallis `varname', by(`groupnum')
                    if _rc == 0 qui kwallis `varname', by(`groupnum')
                    local p=chi2tail(r(df), r(chi2_adj))  // p-value
                    local chi2 :di %6.2f r(chi2_adj)  // Chi-square statistic
                    local df = r(df)  // Degrees of freedom
                }
                if `nglevels'==2 {
                    /* Rank-sum for 2 groups */
                    cap ranksum `varname', by(`groupnum')
                    if _rc == 0 qui ranksum `varname', by(`groupnum')
                    local z = r(z)  // z statistic
                    local p=2*normal(-abs(`z'))  // Two-sided p-value
                    local z : di %6.2f `z'  // Format z statistic
                }
                
                /* Calculate pairwise comparisons if requested */
                if "`pairwise123'" == "pairwise123" & `nglevels'>1 {
                    // Group 1 vs Group 2
                    cap ranksum `varname' if `groupnum' == `level1' | `groupnum' == `level2', by(`groupnum')                    
                    if _rc == 0 qui ranksum `varname' if `groupnum' == `level1' | `groupnum' == `level2', by(`groupnum')
                    local p12=2*normal(-abs(r(z)))    
                    
                    // Group 2 vs Group 3
                    cap ranksum `varname' if `groupnum' == `level2' | `groupnum' == `level3', by(`groupnum')
                    if _rc == 0 qui ranksum `varname' if `groupnum' == `level2' | `groupnum' == `level3', by(`groupnum')
                    local p23=2*normal(-abs(r(z)))                    
                    
                    // Group 1 vs Group 3
                    cap ranksum `varname' if `groupnum' == `level1' | `groupnum' == `level3', by(`groupnum')
                    if _rc == 0 qui ranksum `varname' if `groupnum' == `level1' | `groupnum' == `level3', by(`groupnum')
                    local p13=2*normal(-abs(r(z)))                    
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
                    qui replace `groupnum' = 919 if _copy == 1  // Mark total rows
                }                
                
                // Calculate median and IQR by group
                collapse (p50) p50=`varname' (p25) p25=`varname' ///
                    (p75) p75=`varname' (count) N_=`varname' , by(`groupnum')
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

                /* Add p-value, test type, and statistics */
                if `nglevels'>1 qui {
                    gen p=`p'  // Add p-value
                    
                    // Add pairwise p-values if requested
                    if "`pairwise123'" == "pairwise123" {
                        qui gen p12=`p12'  // Group 1 vs 2
                        qui gen p23=`p23'  // Group 2 vs 3 
                        qui gen p13=`p13'  // Group 1 vs 3
                    }
                }
                
                // Add test type label based on number of groups
                if "`test'"=="test" & `nglevels'==2 gen test="Wilcoxon rank-sum"  
                if "`test'"=="test" & `nglevels'>2 gen test="Kruskal-Wallis"
                
                // Add test statistic details if requested
                if "`statistic'"=="statistic" & `nglevels'==2 gen statistic="Z=`z'"
                if "`statistic'"=="statistic" & `nglevels'>2 gen statistic="Chi2(`df')=`chi2'"
                
                /* Add sort variable and append to results */
                gen sort1=`sortorder++'  // Increment sort order
                qui append using "`resultstable'"  // Add to results table
                qui save "`resultstable'", replace  // Save updated table
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
                
                /* Calculate significance test */
                if `nglevels'>1 & `nvlevels'>1 {
                    if "`vartype'"=="cat" {
                        // Chi-square test for standard categorical
                        qui tab `varnum' `groupnum' [`weight'`exp'], chi2 m
                        local p=r(p)  // p-value
                        local chi2 : di %6.2f r(chi2)  // Chi-square statistic
                        local df = (r(r)-1)*(r(c)-1)  // Degrees of freedom
                        
                        // Calculate pairwise chi-square tests if requested
                        if "`pairwise123'" == "pairwise123" {
                            qui tab `varnum' `groupnum' [`weight'`exp'] if `groupnum' == `level1' | `groupnum' == `level2', chi2 m
                            local p12=r(p)
                            qui tab `varnum' `groupnum' [`weight'`exp'] if `groupnum' == `level2' | `groupnum' == `level3', chi2 m
                            local p23=r(p)
                            qui tab `varnum' `groupnum' [`weight'`exp'] if `groupnum' == `level1' | `groupnum' == `level3', chi2 m
                            local p13=r(p)                        
                        }                                                
                    }
                    else {
                        // Fisher's exact test for cate type
                        qui tab `varnum' `groupnum' [`weight'`exp'], exact m
                        local p=r(p_exact)  // p-value from Fisher's exact test
                        
                        // Calculate pairwise Fisher's exact tests if requested
                        if "`pairwise123'" == "pairwise123" {
                            qui tab `varnum' `groupnum' [`weight'`exp'] if `groupnum' == `level1' | `groupnum' == `level2', exact m
                            local p12=r(p_exact)
                            qui tab `varnum' `groupnum' [`weight'`exp'] if `groupnum' == `level2' | `groupnum' == `level3', exact m
                            local p23=r(p_exact)
                            qui tab `varnum' `groupnum' [`weight'`exp'] if `groupnum' == `level1' | `groupnum' == `level3', exact m
                            local p13=r(p_exact)                                
                        }                        
                    }                
                }
                
                /* Calculate frequencies by group */
                if "`total'" != "" { 
                    qui expand 2, gen(_copy)  // Duplicate for total calculation
                    qui replace `groupnum' = 919 if _copy == 1  // Mark total rows
                }                
                qui contract `varnum' `groupnum' [`weight'`exp'], zero  // Get counts for each value and group combination
                qui egen tot=total(_freq), by(`groupnum')  // Calculate total count per group
                
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
                
                qui gen n_ = string(_freq, "`nformat'")  // Format count
                if `"`slashN'"' == "slashN" qui replace n_ = n_ + "/" + string(tot, "`nformat'")  // Show as n/N if requested
                
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
                }    
                rename tot N_
                label var N_ "N"
                
                drop _freq perc n_
                qui reshape wide n_perc _columna_ _columnb_ N_, i(`varnum') j(`groupnum')                
                rename n_perc* `groupnum'*  // Rename columns by group
                
                /* Format display of factor and level variables */
                if "`onecol'"=="" {
                    // Multi-column format (variable name in first row, levels in other rows)
                    qui gen factor="`varlab', `percfootnote2'" if _n==1  // First row gets variable name and footnote
                    if `"`varlabplus'"' == "" qui replace factor="`varlab'" if _n==1  // Simple label if varlabplus not used
                    qui gen factor_sep="`varlab'"  // For neat separation
                    qui gen level= string(`varnum')  // Store level values
                    
                    // Replace numeric levels with value labels if available
                    qui levelsof `varnum', local(levels)
                    foreach level of local levels {
                        qui replace level="`: label (`varnum') `level''" if `varnum'==`level'
                    }
                    qui replace level="Missing" if `varnum'==.  // Label for missing values
                }
                else {
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
                }

                /* Add p-value, test type, and statistics */
                qui gen cat_not_top_row = 1 if _n!=1  // Flag for rows that aren't the first row
                if `nglevels'>1 & `nvlevels'>1 {
                    qui gen p=`p' if _n==1  // Add p-value to first row only
                    
                    // Add pairwise p-values if requested
                    if "`pairwise123'" == "pairwise123" {
                        qui gen p12=`p12' if _n==1
                        qui gen p23=`p23' if _n==1
                        qui gen p13=`p13' if _n==1
                    }                    
                }    
                
                // Show N only in first row
                foreach v of var N_* {                    
                    qui replace `v' = . if _n!=1
                }                    
                
                // Add test type and statistic labels if requested
                if "`test'"=="test" & `nglevels'>1 & `nvlevels'>1 {
                    if "`vartype'"=="cat" qui gen test="Chi-square" if _n==1    
                    else qui gen test="Fisher's exact" if _n==1
                }
                if "`statistic'"=="statistic" & `nglevels'>1 & `nvlevels'>1 {
                    if "`vartype'"=="cat" qui gen statistic="Chi2(`df')=`chi2'" if _n==1
                    else qui gen statistic="N/A" if _n==1
                }                
                
                /* Add sort variables and append to results */
                gen sort1=`sortorder++'  // Primary sort by variable order
                qui gen sort2=_n  // Secondary sort preserves category order
                qui drop `varnum'
                qui append using "`resultstable'"  // Add to results table
                qui save "`resultstable'", replace  // Save updated table
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
                    exit 198
                }

                // Count groups with non-missing values
                qui levelsof `groupnum' if `varname'!=., local(glevels)
                local nglevels: word count `glevels'
                qui levelsof `varname', local(vlevels)
                local nvlevels: word count `vlevels'
                
                /* Calculate significance test */
                if "`vartype'"=="bin" & `nglevels'>1 & `nvlevels'>1 {
                    // Chi-square test for standard binary
                    qui tab `varname' `groupnum' [`weight'`exp'], chi2
                    local p=r(p)  // p-value
                    local chi2 : di %6.2f r(chi2)  // Chi-square statistic
                    local df = (r(r)-1)*(r(c)-1)  // Degrees of freedom                      
                    
                    // Calculate pairwise chi-square tests if requested
                    if "`pairwise123'" == "pairwise123" {
                        qui tab `varname' `groupnum' [`weight'`exp'] if `groupnum' == `level1' | `groupnum' == `level2', chi2
                        local p12=r(p)
                        qui tab `varname' `groupnum' [`weight'`exp'] if `groupnum' == `level2' | `groupnum' == `level3', chi2
                        local p23=r(p)
                        qui tab `varname' `groupnum' [`weight'`exp'] if `groupnum' == `level1' | `groupnum' == `level3', chi2
                        local p13=r(p)                        
                    }                                                
                }
                if "`vartype'"=="bine" & `nglevels'>1 & `nvlevels'>1 {
                    // Fisher's exact test for bine type
                    qui tab `varname' `groupnum' [`weight'`exp'], exact
                    local p=r(p_exact)  // p-value from Fisher's exact test
                    
                    // Calculate pairwise Fisher's exact tests if requested
                    if "`pairwise123'" == "pairwise123" {
                        qui tab `varname' `groupnum' [`weight'`exp'] if `groupnum' == `level1' | `groupnum' == `level2', exact
                        local p12=r(p_exact)
                        qui tab `varname' `groupnum' [`weight'`exp'] if `groupnum' == `level2' | `groupnum' == `level3', exact
                        local p23=r(p_exact)
                        qui tab `varname' `groupnum' [`weight'`exp'] if `groupnum' == `level1' | `groupnum' == `level3', exact
                        local p13=r(p_exact)                                
                    }                        
                }                
                                
                /* Calculate frequencies by group */
                if "`total'" != "" { 
                    qui expand 2, gen(_copy)  // Duplicate for total calculation
                    qui replace `groupnum' = 919 if _copy == 1  // Mark total rows
                }                
                qui contract `varname' `groupnum' [`weight'`exp'], zero  // Get counts for each value and group
                qui egen tot=total(_freq), by(`groupnum')  // Calculate total count per group
                
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
                
                qui gen n_ = string(_freq, "`nformat'")  // Format count
                if `"`slashN'"' == "slashN" qui replace n_ = n_ + "/" + string(tot, "`nformat'")  // Show as n/N if requested
                
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
                rename tot N_
                label var N_ "N"
                
                drop _freq perc n_
                qui reshape wide n_perc _columna_ _columnb_ N_, i(`varname') j(`groupnum')
                qui drop `varname'
                qui gen factor="`varlab', `percfootnote'" if _n==1  // Row label with footnote
                if `"`varlabplus'"' == "" qui replace factor="`varlab'" if _n==1  // Simple label if varlabplus not used                
                qui clonevar factor_sep=factor  // Copy for formatting
                rename n_perc* `groupnum'*  // Rename columns by group

                /* Add p-value, test type, and statistics */
                if `nglevels'>1 & `nvlevels'>1 {
                    qui gen p=`p'  // Add p-value
                    
                    // Add pairwise p-values if requested
                    if "`pairwise123'" == "pairwise123" {
                        qui gen p12=`p12'
                        qui gen p23=`p23'
                        qui gen p13=`p13'
                    }    
                }
                
                // Add test type and statistic labels if requested
                if "`test'"=="test" & `nglevels'>1 & `nvlevels'>1 {
                    if "`vartype'"=="bin" qui gen test="Chi-square"     
                    else qui gen test="Fisher's exact" 
                }
                if "`statistic'"=="statistic" & `nglevels'>1 & `nvlevels'>1 {
                    if "`vartype'"=="bin" qui gen statistic="Chi2(`df')=`chi2'"
                    else qui gen statistic="N/A"
                }                
                
                /* Add sort variable and append to results */
                gen sort1=`sortorder++'  // Increment sort order
                qui append using "`resultstable'"  // Add to results table
                qui save "`resultstable'", replace  // Save updated table
                restore
            }            
        }
        gettoken arg rest : rest, parse("\")  // Get next variable specification
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
        label define `vallab' 919 `"Total"', modify  // Add "Total" label for code 919
        local levels "`levels' 919"  // Add 919 to levels list
    }
    
    /* Apply labels to each group column */
    foreach level of local levels {
        if "`vallab'"=="" {
            // If no value label, use by-variable name and value
            lab var `groupnum'`level' "`by' = `level'"
        }
        else {
            // Use value label if available
            local lab: label `vallab' `level'
            lab var `groupnum'`level' "`lab'"
        }
    }

    /* Calculate missing counts */
    foreach i of local levels {
        cap gen cat_not_top_row = .  // Create indicator for categorical variables
        qui recode N_`i' .=0 if cat_not_top_row !=1  // Use N=0 for categorical vars
        qui su N_`i'  // Get maximum sample size for this group
        qui gen m_`i' = `r(max)' - N_`i'  // Calculate missing as max - observed
        label var m_`i' "`i' m"  // Label missing count columns
    }
    
    /* Apply variable labels */
    lab var factor "Factor "
    capture lab var level "Level"
    capture lab var test "Test"
    capture lab var statistic "Statistic"
    if `groupcount'==1 lab var `groupnum'1 "Total"  // Simplify single group label
    capture lab var _columna_919 "T _columna_"  // Label total column components
    capture lab var _columnb_919 "T _columnb_"  
    capture lab var N_919 "T N_"
    capture lab var m_919 "T m_"
    
    /* Format p-values */
    if `groupcount'>1 {
        cap gen p = .  // Create p-value variable if it doesn't exist
        
        // Format p-values according to their magnitude and specified decimal places
        qui gen pvalue=string(p, "%`=`highpdp'+2'.`highpdp'f") if !missing(p)  // Standard format for high p-values
        qui replace pvalue=string(p, "%`=`pdp'+2'.`pdp'f") if p<0.10  // More decimal places for low p-values
        
        // Handle very small p-values
        local pmin=10^-`pdp'  // Minimum p-value to show numerically
        qui replace pvalue="<" + string(`pmin', "%`=`pdp'+2'.`pdp'f") if p<`pmin'  // Show as <0.001 etc.
        
        // Add space for alignment
        qui replace pvalue=" " + pvalue if p>=`pmin' & pvalue != ""
        
        lab var pvalue "p-value"  // Label p-value column
    }
    
    /* Format pairwise comparisons if requested */
    if "`pairwise123'" == "pairwise123" {
        foreach p of var p12 p23 p13 {
            // Format each pairwise p-value with same logic as overall p-value
            qui gen `p's=string(`p', "%`=`highpdp'+2'.`highpdp'f") if !missing(`p')  // Standard format
            qui replace `p's=string(`p', "%`=`pdp'+2'.`pdp'f") if `p'<0.10  // More decimals for small p
            qui replace `p's="<" + string(`pmin', "%`=`pdp'+2'.`pdp'f") if `p'<`pmin'  // Format very small p
            qui replace `p's=" " + `p's if `p'>=`pmin' & `p's != ""  // Add space for alignment
            lab var `p's "`p'"  // Label pairwise p-value column
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
    capture drop p  // Drop raw p-value variables
    capture drop p12 p23 p13  // Drop raw pairwise p-value variables
    
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
    capture order p12s p23s p13s, after(pvalue)  // Add pairwise p-values if they exist
    capture order level, after(factor)  // Add level column for categorical variables

    /* Rename placeholder group variable or add group prefix */
    if `groupcount'==1 rename `groupnum'1 Total  // Simplify single group name
    else rename `groupnum'* `by'*  // Add by-variable name prefix to group columns
 
    if "`by'" !="" rename `by'* `by'_*  // Add underscore for clarity
    capture rename *_919 *_T  // Rename total columns (_919 to _T)
    capture rename _*_919 _*_T  // Rename total column components
    
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
        order N_T, before(m_`first')  // Reorder N columns 
        order m_T, before(_columna_`first')  // Reorder missing columns
        order _columna_T _columnb_T, last  // Move column components to end
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
            // Build list of columns to process (include T only if total option used)
            local hperc_cols "`glevels'"
            if "`total'" != "" {
                local hperc_cols "`glevels' T"
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
        /* Identify variable types present */
        gen has_bin = regexm("`vars' ", " bin ") == 1 | regexm("`vars' ", " bine ") == 1
        gen has_cat = regexm("`vars' ", " cat ") == 1 | regexm("`vars' ", " cate ") == 1
        gen has_contn = regexm("`vars' ", " contn ") == 1
        gen has_contln = regexm("`vars' ", " contln ") == 1
        gen has_conts = regexm("`vars' ", " conts ") == 1
        
        /* Calculate combined flags */
        gen has_catbin = has_cat == 1 | has_bin == 1
        
        /* Build header parts */
        local header_parts = ""
        local part_count = 0
        
        /* Add categorical description */
        if has_cat == 1 {
            if "`catrowperc'" != "" {
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
        if has_bin == 1 & (has_cat != 1 | "`catrowperc'" != "") {
            if `part_count' > 0 local header_parts = "`header_parts' or "
            
            if "`percent_n'" == "percent_n" {
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
        
        if has_contn == 1 {
            local cont_parts = "Mean (SD)"
            local cont_count = 1
        }
        
        if has_contln == 1 {
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
        
        if has_conts == 1 {
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
        
        /* Clean up temporary variables */
        drop has_*
    }

    /* Display the table */
    qui ds factor_sep _* N_* m_*, not  // Get variables to display (exclude internal ones)
    list `r(varlist)', sepby(factor_sep) noobs noheader table  // Show table with separators between variables
    drop factor_sep  // Clean up
    
    /* Generate data description string */
    qui {
        // Check which variable types are present
        local ybin = regexm("`vars' ", " bin ") == 1 | regexm("`vars' ", " bine ") == 1  // Binary variables
        local ycat = regexm("`vars' ", " cat ") == 1 | regexm("`vars' ", " cate ") == 1  // Categorical variables
        if "`ycat'" == "1" | "`ybin'" == "1" local ycatbin "1"  // Flag if any categorical/binary
        
        local ycontn = regexm("`vars' ", " contn ") == 1  // Normal continuous
        local ycontln = regexm("`vars' ", " contln ") == 1  // Log-normal continuous
        local yconts = regexm("`vars' ", " conts ") == 1  // Skewed continuous
        
        /* Build description for continuous variables */
        if "`ycontn'" == "1" & "`ycontln'" == "1" & "`yconts'" == "1" {
            local ycont "`meanSD', `gmeanSD', and median (Q1, Q3)"
        }
        else if "`ycontn'" == "1" & "`ycontln'" == "1" & "`yconts'" == "" {
            local ycont "`meanSD' or `gmeanSD'"
        }
        else if "`ycontn'" == "1" & "`ycontln'" == "" & "`yconts'" == "1" {
            local ycont "`meanSD' or median (Q1, Q3)"
        }
        else if "`ycontn'" == "" & "`ycontln'" == "1" & "`yconts'" == "1" {
            local ycont "`gmeanSD' or median (Q1, Q3)"
        }
        else if "`ycontn'" == "1" & "`ycontln'" == "" & "`yconts'" == "" {
            local ycont "`meanSD'"
        }
        else if "`ycontn'" == "" & "`ycontln'" == "1" & "`yconts'" == "" {
            local ycont "`gmeanSD'"
        }
        else if "`ycontn'" == "" & "`ycontln'" == "" & "`yconts'" == "1" {
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
        
        /* Display data description if not using varlabplus */
        if `"`varlabplus'"' == "" {
            local Dapa "Data are presented as `ymix'."
            display "`Dapa'"
        }
        sreturn local Dapa "`Dapa'"  // Return the data description
        display " "
    }

    /* Add extra space for alignment if requested */
    if `"`extraspace'"' != "" {
        // Add extra space before p-values for alignment
        qui cap replace pvalue=" " + pvalue if substr(pvalue,1,1) != "<"
        
        if "`pairwise123'" == "pairwise123" {
            foreach p of var p12s p23s p13s {
                qui cap replace `p's = " " + `p's if substr(`p's,1,1) != "<"
            }    
        }
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

**# Export to Excel if Requested
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
			if "`ycat'" == "1" {
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
			if "`ybin'" == "1" && ("`ycat'" != "1" || "`catrowperc'" != "") {
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
				
				if "`ycontn'" == "1" || "`ycontln'" == "1" || "`yconts'" == "1" {
					if "`ycontn'" == "1" {
						local header_parts = "Mean (SD)"
						local part_count = 1
					}
					if "`ycontln'" == "1" {
						if `part_count' > 0 local header_parts = "`header_parts', "
						local header_parts = "`header_parts'Geometric mean (×/GSD)"
						local part_count = `part_count' + 1
					}
					if "`yconts'" == "1" {
						if `part_count' > 0 local header_parts = "`header_parts', "
						local header_parts = "`header_parts'Median (Q1`iqrmiddle'Q3)"
						local part_count = `part_count' + 1
					}
					
					if "`ycat'" == "1" || "`ybin'" == "1" {
						if `part_count' > 0 local header_parts = "`header_parts', "
						
						if "`ycat'" == "1" && "`catrowperc'" != "" {
							local header_parts = "`header_parts'Row %"
							if "`ybin'" == "1" local header_parts = "`header_parts', Column %"
						}
						else {
							local header_parts = "`header_parts'Column %"
						}
					}
				}
				else {
					if "`ycat'" == "1" && "`catrowperc'" != "" {
						local header_parts = "Row %"
						if "`ybin'" == "1" local header_parts = "`header_parts', Column %"
					}
					else {
						local header_parts = "Column %"
					}
				}
			}
			
			/* Add continuous variable formats if present */
			if "`ycontn'" == "1" {
				if `part_count' > 0 local header_parts = "`header_parts', "
				local header_parts = "`header_parts'Mean (SD)"
				local part_count = `part_count' + 1
			}
			
			if "`ycontln'" == "1" {
				if `part_count' > 0 local header_parts = "`header_parts', "
				local header_parts = "`header_parts'Geometric mean (×/GSD)"
				local part_count = `part_count' + 1
			}
			
			if "`yconts'" == "1" {
				if `part_count' > 0 local header_parts = "`header_parts', "
				local header_parts = "`header_parts'Median (Q1`iqrmiddle'Q3)"
				local part_count = `part_count' + 1
			}
			
			/* Set header description in the table */
			replace factor = "`header_parts'" if _n == 2

            /* Export to Excel */
            export excel using "`excel'", sheet("`sheet'") sheetreplace

**# Calculate column widths based on content length

			/* Calculate column widths based on content */
			gen factor_length = length(factor)
			egen max_factor_length = max(factor_length) if !inrange(_n,2,3)
			egen max_factor2_length = max(factor_length) if inrange(_n,2,3)
			sum max_factor_length, d
			local factorwidth = `=ceil(`r(max)'*0.80)'  // Factor column width based on content
			sum max_factor2_length, d
			local factor2width = `=ceil(`r(max)'*0.80)'  // Factor column width based on content
			if `factor2width' > `=`factorwidth'*2' local factorwidth = `=`factorwidth'+((`factor2width'-`factorwidth')/2.5)'
			
			/* Ensure reasonable min/max bounds */
			if `factorwidth' < 15 local factorwidth = 15  // Minimum width
			if `factorwidth' > 60 local factorwidth = 60  // Maximum width

			/* Calculate data column width */
			local datawidth = 0
			foreach var of varlist `by'_* {
				gen `var'_length = length(`var')
				egen `var'_max = max(`var'_length)
				sum `var'_max, d
				if `r(max)' > `datawidth' local datawidth = `r(max)'
			}
			local datawidth = `=ceil(`datawidth'*0.82)'  // Data column width with adjustment factor

			/* Ensure reasonable min/max bounds */
			if `datawidth' < 12 local datawidth = 12  // Minimum width
			if `datawidth' > 30 local datawidth = 30  // Maximum width

			/* Clean up temporary variables */
			cap drop *_length *_max
            
            /*****************************************************************
            * Create function to convert column number to Excel letter reference
            *****************************************************************/
            /* Create function that handles columns beyond Z (AA, AB, etc.) */
            local colindex = 1
            local col_letters ""
            			
			qui desc
			local num_cols = `r(k)'  // Number of columns
			qui count
			local num_rows = `r(N)'  // Number of rows

            /* Build function to get Excel column letter */
            forvalues i = 1/`num_cols' {
                local col_letter = ""
                local temp_i = `i'
                
                // Convert number to Excel-style column reference (A, B, ..., Z, AA, AB, etc.)
                while `temp_i' > 0 {
                    local remainder = mod(`temp_i' - 1, 26)
                    local col_letter = char(`remainder' + 65) + "`col_letter'"
                    local temp_i = floor((`temp_i' - 1) / 26)
                }
                
                local col_letters = "`col_letters' `col_letter'"  // Store all column letters
            }
            
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
            
            /* Get letters for formatting */
            local factor_letter: word 2 of `col_letters'  // Factor column letter          
            
			local data_start_pos = 3
			
            local data_start_letter: word `data_start_pos' of `col_letters'  // First data column
            
            if `pvalue_pos' > 0 {
                local pvalue_letter: word `pvalue_pos' of `col_letters'  // p-value column letter
            }

            /*****************************************************************
            * Apply column width calculations
            *****************************************************************/
			/* Create Excel interface object in Mata */
			mata: b = xl()
			
            /* Set column widths and formats */
			mata: b.load_book("`excel'")
			mata: b.set_sheet("`sheet'")
			mata: b.set_row_height(1, 1, 30)  // Title row height
			mata: b.set_column_width(1, 1, 1)  // Make first column (title) narrow
			mata: b.set_column_width(2, 2, `factorwidth')  // Factor column width
			mata: b.set_column_width(3, `num_cols', `datawidth')  // Data column width
			mata: b.set_column_width(`pvalue_pos', `pvalue_pos',10)  // p-value column width
			mata: b.close_book()

            /*****************************************************************
            * Apply Excel formatting 
            *****************************************************************/
            putexcel set "`excel'", sheet("`sheet'") modify
			
            /* Title row formatting */
            putexcel (A1:`lastcol_letter'1), merge txtwrap left vcenter bold
            
            /* Header rows formatting */
            putexcel (`factor_letter'2:`factor_letter'3), merge hcenter vcenter txtwrap bold
            
            if `level_pos' > 0 {
                putexcel (`level_letter'2:`level_letter'3), merge hcenter vcenter txtwrap bold
            }
            
            /* Format group headers */
            local data_col = `data_start_pos'
            while `data_col' <= `num_cols' {
                if `data_col' != `pvalue_pos' {
                    local col_letter: word `data_col' of `col_letters'
                    putexcel (`col_letter'2:`col_letter'3), hcenter vcenter txtwrap bold
                }
                local data_col = `data_col' + 1
            }
            
            /* Format p-value column if it exists */
            if `pvalue_pos' > 0 {
                putexcel (`pvalue_letter'2:`pvalue_letter'3), merge hcenter vcenter txtwrap bold
            }
            
            /* Apply borders based on selected style */
            if "`borderstyle'" == "thin" {
                /* Thin borders everywhere */
                putexcel (`factor_letter'2:`lastcol_letter'2), border(top, thin)
                putexcel (`factor_letter'4:`lastcol_letter'4), border(top, thin)
                putexcel (`factor_letter'2:`factor_letter'`num_rows'), border(left, thin)
                putexcel (`factor_letter'2:`factor_letter'`num_rows'), border(right, thin)
                putexcel (`lastcol_letter'2:`lastcol_letter'`num_rows'), border(right, thin)
                putexcel (`factor_letter'`num_rows':`lastcol_letter'`num_rows'), border(bottom, thin)
            }
            else {
                /* Default mixed border style */
                putexcel (`factor_letter'2:`lastcol_letter'2), border(top, medium)
                putexcel (`factor_letter'4:`lastcol_letter'4), border(top, medium)
                putexcel (`factor_letter'2:`factor_letter'`num_rows'), border(left, medium)
                putexcel (`factor_letter'2:`factor_letter'`num_rows'), border(right, medium)
                putexcel (`lastcol_letter'2:`lastcol_letter'`num_rows'), border(right, medium)
                putexcel (`factor_letter'`num_rows':`lastcol_letter'`num_rows'), border(bottom, medium)
            }
            
            /* Add border for total column if specified */
            if "`total'" != "" {
                /* Find total column position */
                local total_col_pos = 0
                local i = 1
                foreach var of varlist * {
                    if substr("`var'", -2, 2) == "_T" {
                        local total_col_pos = `i'
                        continue, break
                    }
                    local i = `i' + 1
                }
                
                if `total_col_pos' > 0 {
                    local total_letter: word `total_col_pos' of `col_letters'  // Get total column letter
                    if "`borderstyle'" == "thin" {
                        putexcel (`total_letter'2:`total_letter'`num_rows'), border(left, thin) 
                        putexcel (`total_letter'2:`total_letter'`num_rows'), border(right, thin)
                    }
                    else {
                        putexcel (`total_letter'2:`total_letter'`num_rows'), border(left, medium) 
                        putexcel (`total_letter'2:`total_letter'`num_rows'), border(right, medium)
                    }
                }
            }
            
            /* Add border for p-value if it exists */
            if `pvalue_pos' > 0 {
                if "`borderstyle'" == "thin" {
                    putexcel (`pvalue_letter'2:`pvalue_letter'`num_rows'), border(left, thin)
                }
                else {
                    putexcel (`pvalue_letter'2:`pvalue_letter'`num_rows'), border(left, medium)
                }
            }
            
            /* Apply font to entire table */
            putexcel (A1:`lastcol_letter'`num_rows'), font(Arial, 10)
            
            /* Clear putexcel */
            putexcel clear
        }
    }

**#  Restore original data unless told not to
{
    if "`clear'"=="clear" restore, not
    else restore
}

end
