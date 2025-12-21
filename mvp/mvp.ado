*! mvp Version 1.1.1  16dec2025
*! Fork of mvpatterns 2.0.0 by Jeroen Weesie (STB-61: dm91)
*! Author: Timothy P Copeland
*! Missing value pattern analysis with enhanced features

program define mvp, rclass byable(recall) sortpreserve
    version 16.0
    set varabbrev off
    set more off

    syntax [varlist] [if] [in] [, ///
        Minfreq(integer 1)      /// minimum frequency to display
        noTable                 /// suppress variable table
        SKip                    /// spaces every 5 vars
        SOrt                    /// sort vars by missingness
        noDrop                  /// keep vars with no missing
        Percent                 /// show percentages
        CUmulative              /// show cumulative freq/pct
        Ascending               /// sort patterns ascending
        MINMissing(integer -1)  /// min # missing vars in pattern
        MAXMissing(integer -1)  /// max # missing vars in pattern
        GENerate(string)        /// generate missingness indicators
        SAVE(string)            /// save patterns to file
        CORrelate               /// show tetrachoric correlations
        MONotone                /// test for monotone missingness
        Wide                    /// compact display
        noSUmmary               /// suppress summary statistics
        GRaph(string)           /// graph type: bar, patterns, matrix, correlation
        SCHeme(string)          /// graph scheme
        /// Enhanced graph options
        TItle(string asis)      /// graph title
        SUBtitle(string asis)   /// graph subtitle
        GName(string)           /// graph name for saving in memory
        GSAVing(string asis)    /// save graph to file
        noDRAW                  /// suppress graph display
        /// Bar chart options
        BARColor(string)        /// bar fill color
        HORizontal              /// horizontal bars (default for bar)
        VERtical                /// vertical bars
        /// Pattern chart options
        TOP(integer 20)         /// number of top patterns to show
        /// Matrix heatmap options
        MISSColor(string)       /// color for missing values
        OBSColor(string)        /// color for observed values
        /// Correlation heatmap options
        TEXTLabels              /// show correlation values in cells
        COLORRamp(string)       /// color ramp: bluered (default), redblue, grayscale
        /// Stratification options for graphs
        GBy(varname)            /// stratify graphs by categorical variable
        OVER(varname)           /// overlay comparison by categorical variable
        STacked                 /// show stacked bar chart
        GRoupgap(real 0)        /// gap between bar groups
        LEGendopts(string asis) /// pass-through legend options
    ]

    * Validate graph-related options require graph()
    if "`graph'" == "" {
        if "`scheme'" != "" {
            di as err "option {bf:scheme()} requires {bf:graph()} option"
            exit 198
        }
        if `"`title'"' != "" | `"`subtitle'"' != "" {
            di as err "options {bf:title()} and {bf:subtitle()} require {bf:graph()} option"
            exit 198
        }
        if "`gname'" != "" | `"`gsaving'"' != "" | "`draw'" != "" {
            di as err "options {bf:gname()}, {bf:gsaving()}, {bf:nodraw} require {bf:graph()} option"
            exit 198
        }
    }

    * Validate bar-specific options
    if "`barcolor'" != "" | "`horizontal'" != "" | "`vertical'" != "" {
        if "`graph'" == "" | ("`graph'" != "" & !strpos(lower("`graph'"), "bar") & !strpos(lower("`graph'"), "pattern")) {
            di as err "options {bf:barcolor()}, {bf:horizontal}, {bf:vertical} require graph(bar) or graph(patterns)"
            exit 198
        }
    }
    if "`horizontal'" != "" & "`vertical'" != "" {
        di as err "cannot specify both {bf:horizontal} and {bf:vertical}"
        exit 198
    }

    * Validate matrix-specific options
    if "`misscolor'" != "" | "`obscolor'" != "" {
        if "`graph'" == "" | !strpos(lower("`graph'"), "matrix") {
            di as err "options {bf:misscolor()} and {bf:obscolor()} require graph(matrix)"
            exit 198
        }
    }

    * Validate correlation-specific options
    if "`textlabels'" != "" | "`colorramp'" != "" {
        if "`graph'" == "" | lower("`graph'") != "correlation" {
            di as err "options {bf:textlabels} and {bf:colorramp()} require graph(correlation)"
            exit 198
        }
    }
    if "`colorramp'" != "" & !inlist("`colorramp'", "bluered", "redblue", "grayscale") {
        di as err "colorramp() must be one of: bluered, redblue, grayscale"
        exit 198
    }

    * Validate stratification options (gby, over, stacked)
    if "`gby'" != "" | "`over'" != "" | "`stacked'" != "" {
        if "`graph'" == "" {
            di as err "options {bf:gby()}, {bf:over()}, and {bf:stacked} require {bf:graph()} option"
            exit 198
        }
    }
    if "`gby'" != "" & "`over'" != "" {
        di as err "cannot specify both {bf:gby()} and {bf:over()}"
        exit 198
    }
    if "`stacked'" != "" {
        if "`graph'" == "" | !inlist(lower("`graph'"), "bar") {
            di as err "option {bf:stacked} requires graph(bar)"
            exit 198
        }
    }
    if "`gby'" != "" {
        capture confirm numeric variable `gby'
        if _rc != 0 {
            capture confirm string variable `gby'
            if _rc != 0 {
                di as err "gby() variable `gby' not found"
                exit 111
            }
        }
    }
    if "`over'" != "" {
        capture confirm numeric variable `over'
        if _rc != 0 {
            capture confirm string variable `over'
            if _rc != 0 {
                di as err "over() variable `over' not found"
                exit 111
            }
        }
    }
    if `groupgap' < 0 {
        di as err "groupgap() must be non-negative"
        exit 198
    }

    * Validate top() option
    if `top' < 1 {
        di as err "top() must be at least 1"
        exit 198
    }

    * Sanitize file paths (security)
    if "`save'" != "" {
        if regexm("`save'", "[;&|><\$\`]") {
            di as err "save() contains invalid characters"
            exit 198
        }
    }
    if `"`gsaving'"' != "" {
        if regexm(`"`gsaving'"', "[;&|><\$\`]") {
            di as err "gsaving() contains invalid characters"
            exit 198
        }
    }

    * Validate minmissing/maxmissing consistency
    if `minmissing' >= 0 & `maxmissing' >= 0 & `minmissing' > `maxmissing' {
        di as err "minmissing(`minmissing') cannot exceed maxmissing(`maxmissing')"
        exit 198
    }

    * Validate graph option
    local graphtype ""
    local matsample = 0
    local matsort = 0
    if "`graph'" != "" {
        local graphorig "`graph'"
        local graph = lower("`graph'")
        * Parse matrix suboptions
        if strpos("`graph'", "matrix") == 1 {
            local graphtype "matrix"
            * Extract suboptions: matrix, sample(#), sort
            local graphrest = subinstr("`graph'", "matrix", "", 1)
            local graphrest = strtrim("`graphrest'")
            if "`graphrest'" != "" {
                * Remove leading comma if present
                if substr("`graphrest'", 1, 1) == "," {
                    local graphrest = substr("`graphrest'", 2, .)
                }
                * Parse sample(#)
                if regexm("`graphrest'", "sample\(([0-9]+)\)") {
                    local matsample = regexs(1)
                }
                * Parse sort
                if strpos("`graphrest'", "sort") > 0 {
                    local matsort = 1
                }
            }
        }
        else if !inlist("`graph'", "bar", "patterns", "correlation") {
            di as err "graph() must be one of: bar, patterns, matrix, correlation"
            exit 198
        }
        else {
            local graphtype "`graph'"
        }
    }

    * Scratch variables and names
    tempvar touse g isf mv_patt mv_n ng pct cpct order
    tempname nsmall nsmallg patmat corrmat

    * Mark sample
    marksample touse, novarlist
    if "`gby'" != "" {
        markout `touse' `gby', strok
    }
    if "`over'" != "" {
        markout `touse' `over', strok
    }
    qui count if `touse'
    local N = r(N)
    if `N' == 0 {
        di as err "no observations"
        exit 2000
    }

    * Get levels of gby/over variables for graphs
    local gby_levels ""
    local gby_nlev = 0
    if "`gby'" != "" {
        qui levelsof `gby' if `touse', local(gby_levels)
        local gby_nlev : word count `gby_levels'
        if `gby_nlev' < 2 {
            di as err "gby() variable must have at least 2 levels"
            exit 198
        }
        * Get value labels if available
        local gby_vallbl : value label `gby'
    }
    local over_levels ""
    local over_nlev = 0
    if "`over'" != "" {
        qui levelsof `over' if `touse', local(over_levels)
        local over_nlev : word count `over_levels'
        if `over_nlev' < 2 {
            di as err "over() variable must have at least 2 levels"
            exit 198
        }
        * Get value labels if available
        local over_vallbl : value label `over'
    }

    * ===================================================================
    * Process variables - identify those with missing values
    * ===================================================================

    local nmvtotal = 0
    foreach v of local varlist {
        qui count if missing(`v') & `touse'
        local thismv = r(N)
        if `thismv' > 0 | "`drop'" != "" {
            local p : display %8.0f `thismv'
            local nmv `nmv' `p'
            local vlist `vlist' `v'
            local nmvtotal = `nmvtotal' + `thismv'
            * Store percent missing for bar graph
            local pct_`v' = 100 * `thismv' / `N'
        }
        else {
            local varnomv `varnomv' `v'
        }
    }
    local varlist `vlist'

    * Sort variables by missingness if requested
    if "`sort'" != "" {
        tempname sortmat
        local nv : word count `varlist'
        matrix `sortmat' = J(`nv', 2, .)
        forv i = 1/`nv' {
            local m : word `i' of `nmv'
            matrix `sortmat'[`i', 1] = `m'
            matrix `sortmat'[`i', 2] = `i'
        }
        mata: st_matrix(st_local("sortmat"), sort(st_matrix(st_local("sortmat")), -1))
        local newvarlist ""
        forv i = 1/`nv' {
            local idx = `sortmat'[`i', 2]
            local v : word `idx' of `varlist'
            local newvarlist `newvarlist' `v'
        }
        local varlist `newvarlist'
    }

    * Report variables with no missing
    if "`varnomv'" != "" {
        di as txt "{p 0 20}Variables with no missing: {res}`varnomv'{txt}{p_end}" _n
    }

    local nvar : word count `varlist'
    if `nvar' == 0 {
        di as txt "No missing values found in specified variables."
        return scalar N = `N'
        return scalar N_complete = `N'
        return scalar N_incomplete = 0
        return scalar N_patterns = 1
        return scalar N_vars = 0
        return scalar max_miss = 0
        return scalar mean_miss = 0
        return scalar N_mv_total = 0
        exit 0
    }

    * ===================================================================
    * Display variable table
    * ===================================================================

    local linesize : set linesize

    if "`table'" == "" {
        local len 14
        foreach v of local varlist {
            local vlab : var label `v'
            local len = max(`len', length(`"`vlab'"'))
        }
        
        if "`wide'" != "" {
            local vlwidth = min(`linesize'-50, `len', 30)
        }
        else {
            local vlwidth = min(`linesize'-40, `len')
        }
        local ndup = 26 + `vlwidth'

        di as txt _n "Variable     {c |} Type     Obs    Miss   %Miss   Variable label"
        di as txt "{hline 13}{c +}{hline `ndup'}"

        local i 0
        foreach v of local varlist {
            local ++i

            qui count if missing(`v') & `touse'
            local thismv = r(N)
            local pctmiss = 100 * `thismv' / `N'

            local vt : type `v'
            local vlab : var label `v'
            local vl : piece 1 `vlwidth' of `"`vlab'"'

            di as txt "{lalign 12:`v'}" "{col 14}{c |}" as res ///
                _col(16) "`:di %7s abbrev("`vt'",7)'" ///
                _col(24) %6.0fc `N'-`thismv' ///
                _col(31) %6.0fc `thismv' ///
                _col(38) %6.1f `pctmiss' ///
                _col(47) as txt `"`vl'"'

            * Rest of variable label
            local j 2
            local vl : piece `j' `vlwidth' of `"`vlab'"'
            while `"`vl'"' != "" {
                di as txt "{col 14}{c |}{col 47}`vl'"
                local ++j
                local vl : piece `j' `vlwidth' of `"`vlab'"'
            }

            * Separator line every 5 variables
            if "`skip'" != "" & `i' >= 1 & mod(`i',5) == 0 & `i' < `nvar' {
                di as txt "{hline 13}{c +}{hline `ndup'}"
            }
        }
        di as txt "{hline 13}{c BT}{hline `ndup'}"
    }

    * ===================================================================
    * Generate patterns
    * ===================================================================

    local nskip = cond("`skip'" != "", int((`nvar'-1)/5), 0)
    if `nvar' > 244 {
        di as err "too many variables (max 244)"
        exit 198
    }
    if `nvar' > 80 | 15 + `nvar' + `nskip' > `linesize' {
        if `nvar' <= 80 & 15 + `nvar' <= `linesize' {
            di as txt "(option -skip- not honored due to line width)"
            local skip
            local nskip 0
        }
        else if "`wide'" == "" {
            di as txt "(pattern display truncated; use -wide- option for compact view)"
        }
    }
    local nstr = `nvar' + `nskip'

    quietly {
        * Create pattern string and count
        gen str`nstr' `mv_patt' = "" if `touse'
        gen int `mv_n' = 0 if `touse'

        tokenize `varlist'
        forv i = 1/`nvar' {
            if "`skip'" != "" & `i' > 1 & mod(`i'-1,5) == 0 {
                replace `mv_patt' = `mv_patt' + " " if `touse'
            }
            replace `mv_patt' = `mv_patt' + cond(missing(``i''), ".", "+") if `touse'
            replace `mv_n' = `mv_n' + cond(missing(``i''), 1, 0) if `touse'
        }

        * Identify unique patterns
        bys `touse' `mv_patt': gen byte `g' = 1 if _n == 1 & `touse' == 1
        summ `g', meanonly
        replace `g' = sum(`g')
        replace `g' = . if `touse' != 1

        * Frequency per pattern
        bys `g': gen `isf' = (_n == 1) & `touse'
        bys `g': gen long `ng' = _N if `touse'

        * Apply filters
        count if `ng' < `minfreq' & `touse'
        scalar `nsmall' = r(N)
        count if `ng' < `minfreq' & `isf' & `touse'
        scalar `nsmallg' = r(N)
        replace `isf' = 0 if `ng' < `minfreq' & `isf' & `touse'

        * Filter by number of missing variables
        if `minmissing' >= 0 {
            replace `isf' = 0 if `mv_n' < `minmissing' & `isf' & `touse'
        }
        if `maxmissing' >= 0 {
            replace `isf' = 0 if `mv_n' > `maxmissing' & `isf' & `touse'
        }

        * Sort patterns
        if "`ascending'" != "" {
            gsort `ng' -`mv_n' `mv_patt'
        }
        else {
            gsort -`ng' `mv_n' `mv_patt'
        }

        * Generate percent and cumulative
        gen double `pct' = 100 * `ng' / `N' if `touse'
        gen `order' = _n if `isf'
        sort `order'
        gen double `cpct' = sum(`pct' * `isf') if `touse'
    }

    * ===================================================================
    * Display patterns
    * ===================================================================

    di ""
    if `minfreq' > 1 | `minmissing' >= 0 | `maxmissing' >= 0 {
        di as txt "Missing value patterns" _c
        if `minfreq' > 1 {
            di as txt " (freq >= `minfreq')" _c
        }
        if `minmissing' >= 0 {
            di as txt " (nmiss >= `minmissing')" _c
        }
        if `maxmissing' >= 0 {
            di as txt " (nmiss <= `maxmissing')" _c
        }
        di ""
    }
    else {
        di as txt "Missing value patterns"
    }

    * Build header
    local hdr "Pattern"
    local hdrlen = `nstr' + 2
    if `hdrlen' < 12 local hdrlen = 12
    
    local cols "Miss   Freq"
    if "`percent'" != "" {
        local cols "`cols'     Pct"
    }
    if "`cumulative'" != "" {
        local cols "`cols'  CumPct"
    }

    * Display patterns
    preserve
    qui keep if `isf'
    qui count
    local npat = r(N)

    if `npat' == 0 {
        di as txt "(no patterns match criteria)"
    }
    else {
        qui {
            rename `mv_patt' _pattern
            rename `mv_n' _miss
            rename `ng' _freq
            rename `pct' _pct
            rename `cpct' _cumpct
            format _freq %8.0fc
            format _miss %4.0f
            format _pct %7.2f
            format _cumpct %7.2f
        }

        if "`percent'" != "" & "`cumulative'" != "" {
            list _pattern _miss _freq _pct _cumpct, noobs sep(0) subvarname
        }
        else if "`percent'" != "" {
            list _pattern _miss _freq _pct, noobs sep(0) subvarname
        }
        else if "`cumulative'" != "" {
            list _pattern _miss _freq _cumpct, noobs sep(0) subvarname
        }
        else {
            list _pattern _miss _freq, noobs sep(0) subvarname
        }
    }
    restore

    * Summarize patterns not listed
    if `nsmallg' > 0 & `minfreq' > 1 {
        if `minfreq' == 2 {
            di _n as txt "Additional: {res}`=scalar(`nsmall')'" ///
                as txt " observations with unique patterns"
        }
        else {
            di _n as txt "Additional: {res}`=scalar(`nsmall')'" ///
                as txt " observations in {res}`=scalar(`nsmallg')'" ///
                as txt " patterns with freq < `minfreq'"
        }
    }

    * ===================================================================
    * Summary statistics
    * ===================================================================

    qui count if `mv_n' == 0 & `touse'
    local ncomplete = r(N)
    qui count if `mv_n' > 0 & `touse'
    local nincomplete = r(N)
    qui count if `isf'
    local npatterns = r(N)
    qui summ `mv_n' if `touse', meanonly
    local maxmiss_obs = r(max)
    local meanmiss = r(mean)

    if "`summary'" == "" {
        di _n as txt "{hline 50}"
        di as txt "Total observations:      " as res %10.0fc `N'
        di as txt "Complete cases:          " as res %10.0fc `ncomplete' ///
            as txt "  (" as res %5.1f 100*`ncomplete'/`N' as txt "%)"
        di as txt "Incomplete cases:        " as res %10.0fc `nincomplete' ///
            as txt "  (" as res %5.1f 100*`nincomplete'/`N' as txt "%)"
        di as txt "Unique patterns:         " as res %10.0fc `npatterns'
        di as txt "Variables analyzed:      " as res %10.0fc `nvar'
        di as txt "Max missing/obs:         " as res %10.0fc `maxmiss_obs'
        di as txt "Mean missing/obs:        " as res %10.2f `meanmiss'
        di as txt "{hline 50}"
    }

    * ===================================================================
    * Monotone missingness test
    * ===================================================================

    if "`monotone'" != "" {
        di _n as txt "Monotone missingness test:"
        
        * Check if pattern is monotone (once missing, all subsequent missing)
        tempvar is_mono
        qui gen byte `is_mono' = 1 if `touse'
        
        tokenize `varlist'
        forv i = 1/`nvar' {
            local j = `i' + 1
            if `j' <= `nvar' {
                qui replace `is_mono' = 0 if missing(``i'') & !missing(``j'') & `touse'
            }
        }
        
        qui count if `is_mono' == 1 & `touse'
        local nmono = r(N)
        local pctmono = 100 * `nmono' / `N'
        
        if `nmono' == `N' {
            di as txt "  Pattern is {res}monotone{txt} (100% of observations)"
            local mono_status "monotone"
        }
        else {
            di as txt "  Observations with monotone pattern: " ///
                as res %8.0fc `nmono' as txt " (" as res %5.1f `pctmono' as txt "%)"
            di as txt "  Pattern is {res}non-monotone{txt}"
            local mono_status "non-monotone"
        }
        
        return local monotone_status "`mono_status'"
        return scalar N_monotone = `nmono'
        return scalar pct_monotone = `pctmono'
    }

    * ===================================================================
    * Correlations of missingness
    * ===================================================================

    if ("`correlate'" != "" | "`graphtype'" == "correlation") & `nvar' > 1 {
        
        * Create temporary missingness indicators
        local misslist
        tokenize `varlist'
        forv i = 1/`nvar' {
            tempvar miss`i'
            qui gen byte `miss`i'' = missing(``i'') if `touse'
            local misslist `misslist' `miss`i''
        }
        
        if "`correlate'" != "" {
            di _n as txt "Tetrachoric correlations of missingness:"
            di as txt "(correlations among missingness indicators)"
        }
        
        * Try tetrachoric, fall back to pairwise if not available
        capture tetrachoric `misslist' if `touse'
        if _rc == 0 {
            * tetrachoric succeeded
            matrix `corrmat' = r(Rho)
            
            * Rename matrix rows/cols
            local rnames
            forv i = 1/`nvar' {
                local rnames `rnames' ``i''
            }
            matrix rownames `corrmat' = `rnames'
            matrix colnames `corrmat' = `rnames'

            * Use copy option to keep matrix available for graph(correlation)
            return matrix corr_miss = `corrmat', copy
        }
        else {
            * Fall back to pwcorr
            if "`correlate'" != "" {
                di as txt "(tetrachoric not available; using Pearson correlations)"
            }
            qui correlate `misslist' if `touse'
            matrix `corrmat' = r(C)

            * Rename and display
            local rnames
            forv i = 1/`nvar' {
                local rnames `rnames' ``i''
            }
            matrix rownames `corrmat' = `rnames'
            matrix colnames `corrmat' = `rnames'
            if "`correlate'" != "" {
                matrix list `corrmat', format(%6.3f) noheader
            }

            * Use copy option to keep matrix available for graph(correlation)
            return matrix corr_miss = `corrmat', copy
        }
    }

    * ===================================================================
    * Generate missingness indicators
    * ===================================================================

    if "`generate'" != "" {
        tokenize `varlist'
        forv i = 1/`nvar' {
            local vname = substr("``i''", 1, 31)
            capture drop `generate'_`vname'
            qui gen byte `generate'_`vname' = missing(``i'') if `touse'
            label var `generate'_`vname' "Missing: ``i''"
        }
        
        * Also generate pattern variable
        capture drop `generate'_pattern
        capture drop `generate'_nmiss
        qui gen str`nstr' `generate'_pattern = `mv_patt' if `touse'
        label var `generate'_pattern "Missing value pattern"
        qui gen byte `generate'_nmiss = `mv_n' if `touse'
        label var `generate'_nmiss "Number of missing values"
        
        di _n as txt "Generated variables: {res}`generate'_*"
    }

    * ===================================================================
    * Save patterns to file
    * ===================================================================

    if "`save'" != "" {
        preserve
        qui keep if `isf'
        qui keep `mv_patt' `mv_n' `ng' `pct' `cpct'
        qui rename `mv_patt' pattern
        qui rename `mv_n' nmiss
        qui rename `ng' freq
        qui rename `pct' percent
        qui rename `cpct' cumpct
        qui compress
        
        * Check if it's a frame name or filename
        if strpos("`save'", ".") > 0 | strpos("`save'", "/") > 0 | strpos("`save'", "\") > 0 {
            save "`save'", replace
            di _n as txt "Patterns saved to: {res}`save'"
        }
        else {
            * Frames require Stata 16+
            if c(stata_version) >= 16 {
                capture frame drop `save'
                frame put *, into(`save')
                di _n as txt "Patterns saved to frame: {res}`save'"
            }
            else {
                save "`save'.dta", replace
                di _n as txt "Patterns saved to: {res}`save'.dta"
                di as txt "(frames require Stata 16+)"
            }
        }
        restore
    }

    * ===================================================================
    * Graphs
    * ===================================================================

    if "`graphtype'" != "" {
        * Build common graph options
        local schemeopts = cond("`scheme'" != "", `"scheme(`scheme')"', "")
        local nameopts = cond("`gname'" != "", `"name(`gname', replace)"', "")
        local savingopts = cond(`"`gsaving'"' != "", `"saving(`gsaving')"', "")
        local drawopts = cond("`draw'" != "", "nodraw", "")

        * Set default colors if not specified
        if "`barcolor'" == "" local barcolor "navy"
        if "`misscolor'" == "" local misscolor "cranberry"
        if "`obscolor'" == "" local obscolor "navy*0.2"
        if "`colorramp'" == "" local colorramp "bluered"

        * Determine bar orientation (default horizontal for bar/patterns)
        local barcmd "graph hbar"
        local bartitle "ytitle"
        if "`vertical'" != "" {
            local barcmd "graph bar"
            local bartitle "ytitle"
        }

        * Build title/subtitle options
        local titleopts ""
        if `"`title'"' != "" {
            local titleopts `"title(`title')"'
        }
        local subtitleopts ""
        if `"`subtitle'"' != "" {
            local subtitleopts `"subtitle(`subtitle')"'
        }

        * -----------------------------------------------------------------
        * Bar chart: percent missing by variable
        * -----------------------------------------------------------------
        if "`graphtype'" == "bar" {
            preserve

            * Adjust label size based on number of variables
            local labsz "vsmall"
            if `nvar' > 30 local labsz "tiny"
            if `nvar' <= 10 local labsz "small"

            * Build legend options
            local legendopts_final ""
            if `"`legendopts'"' != "" {
                local legendopts_final `"legend(`legendopts')"'
            }

            * Handle gby() option - stratified bar chart with facets
            if "`gby'" != "" {
                qui {
                    * Calculate % missing for each variable within each gby level
                    local nrows = `nvar' * `gby_nlev'
                    clear
                    set obs `nrows'
                    gen str32 varname = ""
                    gen double pctmiss = .
                    gen int varorder = .
                    gen gbyval = .
                    gen str80 gbylabel = ""

                    local row = 1
                    tokenize `varlist'
                    foreach lev of local gby_levels {
                        forv i = 1/`nvar' {
                            replace varname = "``i''" in `row'
                            replace varorder = `i' in `row'
                            replace gbyval = `lev' in `row'
                            * Get value label if available
                            if "`gby_vallbl'" != "" {
                                local lbltxt : label `gby_vallbl' `lev'
                                replace gbylabel = "`lbltxt'" in `row'
                            }
                            else {
                                replace gbylabel = "`gby' = `lev'" in `row'
                            }
                            local ++row
                        }
                    }

                    * Now calculate actual percentages using original data
                    * First save the tempfile we just created
                    tempfile gby_tempdata
                    save `gby_tempdata', replace

                    local row = 1
                    foreach lev of local gby_levels {
                        forv i = 1/`nvar' {
                            restore, preserve
                            qui count if `gby' == `lev' & `touse'
                            local nlev = r(N)
                            qui count if missing(``i'') & `gby' == `lev' & `touse'
                            local nmisslev = r(N)
                            local pctlev = 100 * `nmisslev' / `nlev'
                            * Load tempfile, update, save back
                            use `gby_tempdata', clear
                            qui replace pctmiss = `pctlev' in `row'
                            save `gby_tempdata', replace
                            local ++row
                        }
                    }
                    * Load final tempfile for graphing (stay in preserved state)
                    use `gby_tempdata', clear
                }

                * Set default title if not specified
                local bartitle_text = cond(`"`title'"' != "", "", `"title("Missing Values by Variable and `gby'")"')

                * Draw faceted bar chart
                `barcmd' pctmiss, over(varname, sort(varorder) label(labsize(`labsz'))) ///
                    by(gbylabel, note("") `titleopts') ///
                    ytitle("Percent missing") ///
                    `bartitle_text' `subtitleopts' ///
                    blabel(bar, format(%4.1f) size(tiny)) ///
                    bar(1, color(`barcolor')) ///
                    `schemeopts' `nameopts' `savingopts' `drawopts'
            }

            * Handle over() option - grouped bar chart with overlay
            else if "`over'" != "" {
                qui {
                    * Calculate % missing for each variable within each over level
                    local nrows = `nvar' * `over_nlev'
                    clear
                    set obs `nrows'
                    gen str32 varname = ""
                    gen double pctmiss = .
                    gen int varorder = .
                    gen overval = .
                    gen str80 overlabel = ""

                    local row = 1
                    tokenize `varlist'
                    foreach lev of local over_levels {
                        forv i = 1/`nvar' {
                            replace varname = "``i''" in `row'
                            replace varorder = `i' in `row'
                            replace overval = `lev' in `row'
                            * Get value label if available
                            if "`over_vallbl'" != "" {
                                local lbltxt : label `over_vallbl' `lev'
                                replace overlabel = "`lbltxt'" in `row'
                            }
                            else {
                                replace overlabel = "`over' = `lev'" in `row'
                            }
                            local ++row
                        }
                    }

                    * Now calculate actual percentages using original data
                    * First save the tempfile we just created
                    tempfile over_tempdata
                    save `over_tempdata', replace

                    local row = 1
                    foreach lev of local over_levels {
                        forv i = 1/`nvar' {
                            restore, preserve
                            qui count if `over' == `lev' & `touse'
                            local nlev = r(N)
                            qui count if missing(``i'') & `over' == `lev' & `touse'
                            local nmisslev = r(N)
                            local pctlev = 100 * `nmisslev' / `nlev'
                            * Load tempfile, update, save back
                            use `over_tempdata', clear
                            qui replace pctmiss = `pctlev' in `row'
                            save `over_tempdata', replace
                            local ++row
                        }
                    }
                    * Load final tempfile for graphing (stay in preserved state)
                    use `over_tempdata', clear
                }

                * Set default title if not specified
                local bartitle_text = cond(`"`title'"' != "", "", `"title("Missing Values by Variable")"')

                * Build gap option
                local gapopts ""
                if `groupgap' > 0 {
                    local gapopts "gap(`groupgap')"
                }

                * Legend options for over()
                if "`legendopts_final'" == "" {
                    local legendopts_final "legend(rows(1) position(6))"
                }

                * Draw grouped bar chart with over() levels side-by-side
                `barcmd' pctmiss, over(overlabel, `gapopts') ///
                    over(varname, sort(varorder) label(labsize(`labsz'))) ///
                    ytitle("Percent missing") ///
                    `bartitle_text' ///
                    `titleopts' `subtitleopts' ///
                    blabel(bar, format(%4.1f) size(tiny)) ///
                    asyvars ///
                    `legendopts_final' ///
                    `schemeopts' `nameopts' `savingopts' `drawopts'
            }

            * Handle stacked option
            else if "`stacked'" != "" {
                qui {
                    * For stacked, we need N * nvar observations
                    * Each bar segment represents one variable's contribution
                    restore, preserve
                    keep if `touse'
                    local Nobs = _N

                    clear
                    set obs `nvar'
                    gen str32 varname = ""
                    gen double pctmiss = .
                    gen int varorder = _n

                    tokenize `varlist'
                    forv i = 1/`nvar' {
                        replace varname = "``i''" in `i'
                        replace pctmiss = `pct_``i''' in `i'
                    }
                }

                * Set default title if not specified
                local bartitle_text = cond(`"`title'"' != "", "", `"title("Missing Values by Variable (Stacked)")"')

                * Draw stacked bar chart
                `barcmd' (sum) pctmiss, over(varname, sort(varorder) label(labsize(`labsz'))) ///
                    stack ///
                    ytitle("Percent missing") ///
                    `bartitle_text' ///
                    `titleopts' `subtitleopts' ///
                    blabel(bar, format(%4.1f) size(tiny)) ///
                    bar(1, color(`barcolor')) ///
                    `schemeopts' `nameopts' `savingopts' `drawopts'
            }

            * Standard bar chart (no stratification)
            else {
                qui {
                    clear
                    set obs `nvar'
                    gen str32 varname = ""
                    gen double pctmiss = .
                    gen int varorder = _n

                    tokenize `varlist'
                    forv i = 1/`nvar' {
                        replace varname = "``i''" in `i'
                        replace pctmiss = `pct_``i''' in `i'
                    }
                }

                * Set default title if not specified
                local bartitle_text = cond(`"`title'"' != "", "", `"title("Missing Values by Variable")"')

                `barcmd' pctmiss, over(varname, sort(varorder) label(labsize(`labsz'))) ///
                    ytitle("Percent missing") ///
                    `bartitle_text' ///
                    `titleopts' `subtitleopts' ///
                    blabel(bar, format(%4.1f) size(vsmall)) ///
                    bar(1, color(`barcolor')) ///
                    `schemeopts' `nameopts' `savingopts' `drawopts'
            }

            restore
        }

        * -----------------------------------------------------------------
        * Patterns: bar chart of pattern frequencies
        * -----------------------------------------------------------------
        else if "`graphtype'" == "patterns" {
            preserve

            * Handle gby() option for patterns - faceted display
            if "`gby'" != "" {
                * Need to recalculate patterns by group
                restore, preserve
                qui keep if `touse'

                * Create pattern data by group
                tempfile patdata
                qui {
                    * Keep needed variables
                    keep `varlist' `gby'

                    * Create pattern string
                    local nskip = cond("`skip'" != "", int((`nvar'-1)/5), 0)
                    local nstr = `nvar' + `nskip'
                    gen str`nstr' _mv_patt = ""
                    gen int _mv_n = 0

                    tokenize `varlist'
                    forv i = 1/`nvar' {
                        if "`skip'" != "" & `i' > 1 & mod(`i'-1,5) == 0 {
                            replace _mv_patt = _mv_patt + " "
                        }
                        replace _mv_patt = _mv_patt + cond(missing(``i''), ".", "+")
                        replace _mv_n = _mv_n + cond(missing(``i''), 1, 0)
                    }

                    * Calculate pattern frequencies by group
                    bys `gby' _mv_patt: gen long _ng = _N
                    bys `gby' _mv_patt: gen byte _isf = (_n == 1)
                    keep if _isf

                    * Get group labels
                    gen str80 _gbylabel = ""
                    foreach lev of local gby_levels {
                        if "`gby_vallbl'" != "" {
                            local lbltxt : label `gby_vallbl' `lev'
                            replace _gbylabel = "`lbltxt'" if `gby' == `lev'
                        }
                        else {
                            replace _gbylabel = "`gby' = `lev'" if `gby' == `lev'
                        }
                    }

                    * Keep top patterns per group
                    bys `gby' (_ng _mv_n): gen int _patorder = _N - _n + 1
                    keep if _patorder <= `top'

                    * Create pattern ID
                    bys `gby' (_patorder): gen str8 _patid = "P" + string(_n)

                    * Get first pattern for note (overall most common)
                    gsort -_ng
                    local pat1 = _mv_patt[1]
                }

                * Set default title if not specified
                local pattitle_text = cond(`"`title'"' != "", "", `"title("Missing Value Patterns by `gby'")"')
                local patsubtitle_text = cond(`"`subtitle'"' != "", "", `"subtitle("(Top `top' patterns per group)")"')

                * Adjust label size
                local patlabsz "small"
                if `top' > 15 local patlabsz "vsmall"
                if `top' > 25 local patlabsz "tiny"

                * Truncate pattern note if too long
                local pat1_display = substr("`pat1'", 1, 80)
                if length("`pat1'") > 80 {
                    local pat1_display "`pat1_display'..."
                }

                * Draw faceted pattern chart
                `barcmd' _ng, over(_patid, sort(_patorder) label(labsize(`patlabsz'))) ///
                    by(_gbylabel, note("") `titleopts') ///
                    ytitle("Frequency") ///
                    `pattitle_text' `patsubtitle_text' ///
                    blabel(bar, format(%9.0fc) size(tiny)) ///
                    note("P1=`pat1_display'", size(vsmall)) ///
                    bar(1, color(`barcolor')) ///
                    `schemeopts' `nameopts' `savingopts' `drawopts'
            }

            * Standard patterns chart (no stratification)
            else {
                qui keep if `isf'
                qui count
                local npat_graph = min(r(N), `top')

                if `npat_graph' > 0 {
                    qui {
                        gsort -`ng'
                        keep in 1/`npat_graph'
                        local pat1 = `mv_patt'[1]
                        gen int patorder = _n
                        * Use wider pattern ID for better display
                        gen str8 patid = "P" + string(_n)
                    }

                    * Set default title if not specified
                    local pattitle_text = cond(`"`title'"' != "", "", `"title("Most Common Missing Value Patterns")"')
                    local patsubtitle_text = cond(`"`subtitle'"' != "", "", `"subtitle("(Top `npat_graph' patterns)")"')

                    * Adjust label size based on number of patterns
                    local patlabsz "small"
                    if `npat_graph' > 15 local patlabsz "vsmall"
                    if `npat_graph' > 25 local patlabsz "tiny"

                    * Truncate pattern note if too long (max 80 chars)
                    local pat1_display = substr("`pat1'", 1, 80)
                    if length("`pat1'") > 80 {
                        local pat1_display "`pat1_display'..."
                    }

                    `barcmd' `ng', over(patid, sort(patorder) label(labsize(`patlabsz'))) ///
                        ytitle("Frequency") ///
                        `pattitle_text' `patsubtitle_text' ///
                        `titleopts' `subtitleopts' ///
                        blabel(bar, format(%9.0fc) size(vsmall)) ///
                        note("P1=`pat1_display'", size(vsmall)) ///
                        bar(1, color(`barcolor')) ///
                        `schemeopts' `nameopts' `savingopts' `drawopts'
                }
                else {
                    di as txt "(no patterns to graph)"
                }
            }

            restore
        }

        * -----------------------------------------------------------------
        * Matrix: observation x variable missingness heatmap
        * -----------------------------------------------------------------
        else if "`graphtype'" == "matrix" {
            preserve

            * Sample if requested or if N is large
            local use_sample = 0
            if `matsample' > 0 & `matsample' < `N' {
                local use_sample = 1
                local sample_n = `matsample'
            }
            else if `N' > 500 & `matsample' == 0 {
                local use_sample = 1
                local sample_n = 500
                di as txt "(sampling 500 observations for matrix display; use graph(matrix, sample(#)) to adjust)"
            }

            qui {
                keep if `touse'

                * Sort by pattern if requested
                if `matsort' {
                    sort `mv_n' `mv_patt'
                }

                * Sample if needed
                if `use_sample' {
                    sample `sample_n', count
                }

                * Create observation ID
                gen long _obsid = _n
                local nobs = _N

                * Reshape to long format for heatmap
                tokenize `varlist'
                forv i = 1/`nvar' {
                    gen byte _m`i' = missing(``i'')
                }

                keep _obsid _m*
                reshape long _m, i(_obsid) j(_varid)

                * Create variable labels
                gen str32 _varname = ""
                forv i = 1/`nvar' {
                    replace _varname = "``i''" if _varid == `i'
                }
            }

            * Set default title if not specified
            local mattitle_text = cond(`"`title'"' != "", "", `"title("Missing Value Matrix")"')
            local matsubtitle_text = cond(`"`subtitle'"' != "", "", `"subtitle("`nobs' observations x `nvar' variables")"')

            * Dynamically size markers based on matrix dimensions
            local msize "tiny"
            if `nobs' <= 100 & `nvar' <= 20 local msize "vsmall"
            if `nobs' <= 50 & `nvar' <= 10 local msize "small"
            if `nobs' > 300 | `nvar' > 50 local msize "vtiny"

            * Adjust label size based on number of variables
            local xlabsz "tiny"
            if `nvar' <= 20 local xlabsz "vsmall"
            if `nvar' <= 10 local xlabsz "small"

            * Draw heatmap using twoway
            twoway (scatter _obsid _varid if _m == 1, ///
                    msymbol(square) msize(`msize') mcolor(`misscolor')) ///
                   (scatter _obsid _varid if _m == 0, ///
                    msymbol(square) msize(`msize') mcolor(`obscolor')), ///
                xlabel(1(1)`nvar', valuelabel angle(90) labsize(`xlabsz')) ///
                ylabel(, labsize(tiny) nogrid) ///
                ytitle("Observation") xtitle("Variable") ///
                `mattitle_text' `matsubtitle_text' ///
                `titleopts' `subtitleopts' ///
                legend(order(1 "Missing" 2 "Observed") rows(1) size(small) position(6)) ///
                plotregion(margin(zero)) ///
                `schemeopts' `nameopts' `savingopts' `drawopts'

            restore
        }

        * -----------------------------------------------------------------
        * Correlation: heatmap of missingness correlations
        * -----------------------------------------------------------------
        else if "`graphtype'" == "correlation" {
            if `nvar' <= 1 {
                di as err "correlation graph requires at least 2 variables"
                exit 198
            }

            * Extract correlation values to locals BEFORE preserve/clear
            * (clear destroys matrices, so we need to save values first)
            forv r = 1/`nvar' {
                forv c = 1/`nvar' {
                    local corrval_`r'_`c' = `corrmat'[`r',`c']
                }
            }

            preserve
            qui {
                clear
                local ncells = `nvar' * `nvar'
                set obs `ncells'
                gen int _rowid = .
                gen int _colid = .
                gen double _corr = .
                gen str10 _corr_label = ""
                local obs = 1
                forv r = 1/`nvar' {
                    forv c = 1/`nvar' {
                        replace _rowid = `r' in `obs'
                        replace _colid = `c' in `obs'
                        * Use pre-extracted correlation value
                        local corrval = `corrval_`r'_`c''
                        replace _corr = `corrval' in `obs'
                        * Format correlation label
                        if abs(`corrval') < 0.01 {
                            replace _corr_label = "" in `obs'
                        }
                        else {
                            replace _corr_label = string(`corrval', "%4.2f") in `obs'
                        }
                        local ++obs
                    }
                }

                * Create color intensity variable (0-10 scale for granularity)
                gen int _color_int = .

                * Assign colors based on ramp selection
                if "`colorramp'" == "bluered" | "`colorramp'" == "redblue" {
                    * For positive correlations (blue)
                    replace _color_int = 1 if _corr >= 0 & _corr < 0.1
                    replace _color_int = 2 if _corr >= 0.1 & _corr < 0.2
                    replace _color_int = 3 if _corr >= 0.2 & _corr < 0.3
                    replace _color_int = 4 if _corr >= 0.3 & _corr < 0.4
                    replace _color_int = 5 if _corr >= 0.4 & _corr < 0.5
                    replace _color_int = 6 if _corr >= 0.5 & _corr < 0.6
                    replace _color_int = 7 if _corr >= 0.6 & _corr < 0.7
                    replace _color_int = 8 if _corr >= 0.7 & _corr < 0.8
                    replace _color_int = 9 if _corr >= 0.8 & _corr < 0.9
                    replace _color_int = 10 if _corr >= 0.9
                    * For negative correlations (red)
                    replace _color_int = -1 if _corr < 0 & _corr >= -0.1
                    replace _color_int = -2 if _corr < -0.1 & _corr >= -0.2
                    replace _color_int = -3 if _corr < -0.2 & _corr >= -0.3
                    replace _color_int = -4 if _corr < -0.3 & _corr >= -0.4
                    replace _color_int = -5 if _corr < -0.4 & _corr >= -0.5
                    replace _color_int = -6 if _corr < -0.5 & _corr >= -0.6
                    replace _color_int = -7 if _corr < -0.6 & _corr >= -0.7
                    replace _color_int = -8 if _corr < -0.7 & _corr >= -0.8
                    replace _color_int = -9 if _corr < -0.8 & _corr >= -0.9
                    replace _color_int = -10 if _corr < -0.9
                }
                else {
                    * Grayscale: use absolute value
                    replace _color_int = round(abs(_corr) * 10)
                }
            }

            * Set default title if not specified
            local corrtitle_text = cond(`"`title'"' != "", "", `"title("Missingness Correlation Matrix")"')

            * Dynamically size markers based on matrix size
            local msize "large"
            if `nvar' > 10 local msize "medium"
            if `nvar' > 15 local msize "medsmall"
            if `nvar' > 20 local msize "small"
            if `nvar' > 30 local msize "vsmall"

            * Adjust label size based on number of variables
            local corrlabsz "small"
            if `nvar' > 15 local corrlabsz "vsmall"
            if `nvar' > 25 local corrlabsz "tiny"

            * Build twoway command based on color ramp
            if "`colorramp'" == "bluered" {
                * Positive = blue, Negative = red
                local pos_colors `"navy*0.1 navy*0.2 navy*0.3 navy*0.4 navy*0.5 navy*0.6 navy*0.7 navy*0.8 navy*0.9 navy"'
                local neg_colors `"cranberry*0.1 cranberry*0.2 cranberry*0.3 cranberry*0.4 cranberry*0.5 cranberry*0.6 cranberry*0.7 cranberry*0.8 cranberry*0.9 cranberry"'
            }
            else if "`colorramp'" == "redblue" {
                * Positive = red, Negative = blue
                local pos_colors `"cranberry*0.1 cranberry*0.2 cranberry*0.3 cranberry*0.4 cranberry*0.5 cranberry*0.6 cranberry*0.7 cranberry*0.8 cranberry*0.9 cranberry"'
                local neg_colors `"navy*0.1 navy*0.2 navy*0.3 navy*0.4 navy*0.5 navy*0.6 navy*0.7 navy*0.8 navy*0.9 navy"'
            }
            else {
                * Grayscale
                local pos_colors `"gs14 gs12 gs10 gs9 gs8 gs7 gs6 gs5 gs4 gs2"'
                local neg_colors `"gs14 gs12 gs10 gs9 gs8 gs7 gs6 gs5 gs4 gs2"'
            }

            * Build the scatter layers
            local twoway_cmd "twoway"
            forv i = 1/10 {
                local pcol : word `i' of `pos_colors'
                local twoway_cmd `"`twoway_cmd' (scatter _rowid _colid if _color_int == `i', msymbol(square) msize(`msize') mcolor(`pcol') mlcolor(none))"'
            }
            forv i = 1/10 {
                local ncol : word `i' of `neg_colors'
                local twoway_cmd `"`twoway_cmd' (scatter _rowid _colid if _color_int == -`i', msymbol(square) msize(`msize') mcolor(`ncol') mlcolor(none))"'
            }

            * Add text labels if requested
            local textlayer ""
            if "`textlabels'" != "" {
                local textlabsz "vsmall"
                if `nvar' > 10 local textlabsz "tiny"
                if `nvar' > 20 local textlabsz "half_tiny"
                local textlayer `"(scatter _rowid _colid, msymbol(none) mlabel(_corr_label) mlabposition(0) mlabsize(`textlabsz') mlabcolor(black))"'
            }

            * Build variable name labels for axes
            local xlabels ""
            local ylabels ""
            tokenize `varlist'
            forv i = 1/`nvar' {
                local xlabels `"`xlabels' `i' "``i''""'
                local ylabels `"`ylabels' `i' "``i''""'
            }

            * Execute the graph
            `twoway_cmd' `textlayer', ///
                xlabel(`xlabels', angle(45) labsize(`corrlabsz') grid) ///
                ylabel(`ylabels', angle(0) labsize(`corrlabsz') grid) ///
                xtitle("") ytitle("") ///
                `corrtitle_text' ///
                `titleopts' `subtitleopts' ///
                legend(off) ///
                aspectratio(1) ///
                plotregion(margin(zero)) ///
                note("Color intensity: stronger correlation = darker. Blue=positive, Red=negative", size(vsmall)) ///
                `schemeopts' `nameopts' `savingopts' `drawopts'

            restore
        }
    }

    * ===================================================================
    * Return values
    * ===================================================================

    return scalar N = `N'
    return scalar N_complete = `ncomplete'
    return scalar N_incomplete = `nincomplete'
    return scalar N_patterns = `npatterns'
    return scalar N_vars = `nvar'
    return scalar max_miss = `maxmiss_obs'
    return scalar mean_miss = `meanmiss'
    return scalar N_mv_total = `nmvtotal'

    return local varlist "`varlist'"
    if "`varnomv'" != "" {
        return local varlist_nomiss "`varnomv'"
    }
    if "`gby'" != "" {
        return local gby "`gby'"
        return local gby_levels "`gby_levels'"
    }
    if "`over'" != "" {
        return local over "`over'"
        return local over_levels "`over_levels'"
    }

end

exit

* Version 1.1.0 (03dec2025):
* - Added gby() option for stratified graphs by categorical variable
*   - graph(bar) gby(varname): faceted bar charts comparing missingness by group
*   - graph(patterns) gby(varname): faceted pattern charts by group
* - Added over() option for overlaid group comparison in graph(bar)
*   - Shows grouped bars with each category level side-by-side
* - Added stacked option for graph(bar) to show stacked bar visualization
* - Added groupgap() option to control spacing between bar groups
* - Added legendopts() for customizing legend in grouped charts
* - New return values: r(gby), r(gby_levels), r(over), r(over_levels)
* - Improved input validation for new options
*
* Version 1.0.1 (01dec2025):
* - Fixed nodrop option logic (was inverted)
* - Added input validation for minmissing/maxmissing consistency
* - Increased generated variable name limit from 26 to 31 characters
* - Enhanced graph options:
*   - Added title(), subtitle() for custom graph titles
*   - Added gname() to name graphs in memory
*   - Added gsaving() to save graphs to files
*   - Added nodraw to suppress graph display
*   - Added barcolor() for bar/patterns charts
*   - Added vertical/horizontal options for bar orientation
*   - Added top() to control number of patterns shown
*   - Added misscolor(), obscolor() for matrix heatmap customization
*   - Added textlabels to show correlation values in cells
*   - Added colorramp() for correlation heatmap (bluered, redblue, grayscale)
* - Improved correlation heatmap with finer color gradation (10 levels)
* - Dynamic marker/label sizing based on data dimensions
* - Better pattern note truncation for long patterns
*
* Changes from mvpatterns 2.0.0 (version 1.1.0):
* - Updated to version 14
* - Added percent option
* - Added cumulative option
* - Added ascending sort option
* - Added minmissing/maxmissing filters
* - Added generate option for missingness indicators
* - Added save option to export patterns
* - Added correlate option for tetrachoric correlations
* - Added monotone missingness test
* - Added wide display option
* - Added comprehensive summary statistics
* - Added sortpreserve to maintain original sort order
* - Expanded return values
* - Increased max variables to 244 (str244)
* - Improved formatting with thousands separators
* - Added nosummary option
* - Added graph(bar) for variable missingness bar chart
* - Added graph(patterns) for pattern frequency chart
* - Added graph(matrix) for obs x var heatmap
* - Added graph(correlation) for missingness correlation heatmap
* - Added scheme() option for graphs
