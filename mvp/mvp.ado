*! mvp 1.1.0  28nov2025
*! Fork of mvpatterns 2.0.0 by Jeroen Weesie (STB-61: dm91)
*! Author: Timothy P Copeland
*! Missing value pattern analysis with enhanced features

program define mvp, rclass byable(recall) sortpreserve
    version 14.0

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
    ]

    * Validate scheme option
    if "`scheme'" != "" & "`graph'" == "" {
        di as err "option {bf:scheme()} requires {bf:graph()} option"
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
    qui count if `touse'
    local N = r(N)
    if `N' == 0 {
        di as err "no observations"
        exit 2000
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
        return scalar N_patterns = 1
        return scalar N_vars = 0
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
            
            return matrix corr_miss = `corrmat'
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
            
            return matrix corr_miss = `corrmat'
        }
    }

    * ===================================================================
    * Generate missingness indicators
    * ===================================================================

    if "`generate'" != "" {
        tokenize `varlist'
        forv i = 1/`nvar' {
            local vname = substr("``i''", 1, 26)
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
        local schemeopts = cond("`scheme'" != "", `"scheme(`scheme')"', "")
        
        * -----------------------------------------------------------------
        * Bar chart: percent missing by variable
        * -----------------------------------------------------------------
        if "`graphtype'" == "bar" {
            preserve
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
            
            graph hbar pctmiss, over(varname, sort(varorder) label(labsize(vsmall))) ///
                ytitle("Percent missing") ///
                title("Missing Values by Variable") ///
                blabel(bar, format(%4.1f) size(vsmall)) ///
                `schemeopts'
            
            restore
        }
        
        * -----------------------------------------------------------------
        * Patterns: bar chart of pattern frequencies
        * -----------------------------------------------------------------
        else if "`graphtype'" == "patterns" {
            preserve
            qui keep if `isf'
            qui count
            local npat_graph = min(r(N), 20)
            
            if `npat_graph' > 0 {
                qui {
                    gsort -`ng'
                    keep in 1/`npat_graph'
                    local pat1 = `mv_patt'[1]
                    gen int patorder = _n
                    gen str3 patid = "P" + string(_n)
                }
                
                graph hbar `ng', over(patid, sort(patorder) label(labsize(small))) ///
                    ytitle("Frequency") ///
                    title("Most Common Missing Value Patterns") ///
                    subtitle("(Top `npat_graph' patterns)") ///
                    blabel(bar, format(%9.0fc) size(vsmall)) ///
                    note("P1=`pat1'") ///
                    `schemeopts'
            }
            else {
                di as txt "(no patterns to graph)"
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
            
            * Draw heatmap using twoway
            twoway (scatter _obsid _varid if _m == 1, ///
                    msymbol(square) msize(tiny) mcolor(cranberry)) ///
                   (scatter _obsid _varid if _m == 0, ///
                    msymbol(square) msize(tiny) mcolor(navy*0.3)), ///
                xlabel(1(1)`nvar', valuelabel angle(90) labsize(tiny)) ///
                ylabel(, labsize(tiny) nogrid) ///
                ytitle("Observation") xtitle("Variable") ///
                title("Missing Value Matrix") ///
                subtitle("`nobs' observations x `nvar' variables") ///
                legend(order(1 "Missing" 2 "Observed") rows(1) size(small)) ///
                `schemeopts'
            
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
            
            preserve
            qui {
                clear
                local ncells = `nvar' * `nvar'
                set obs `ncells'
                gen int _rowid = .
                gen int _colid = .
                gen double _corr = .
                local obs = 1
                forv r = 1/`nvar' {
                    forv c = 1/`nvar' {
                        replace _rowid = `r' in `obs'
                        replace _colid = `c' in `obs'
                        replace _corr = `corrmat'[`r',`c'] in `obs'
                        local ++obs
                    }
                }
            }
            
            twoway (scatter _rowid _colid, ///
                    msymbol(square) msize(large) mcolor(navy*0.1) mlcolor(none)) ///
                   (scatter _rowid _colid if _corr >= 0.2 & _corr < 0.4, ///
                    msymbol(square) msize(large) mcolor(navy*0.3)) ///
                   (scatter _rowid _colid if _corr >= 0.4 & _corr < 0.6, ///
                    msymbol(square) msize(large) mcolor(navy*0.5)) ///
                   (scatter _rowid _colid if _corr >= 0.6 & _corr < 0.8, ///
                    msymbol(square) msize(large) mcolor(navy*0.7)) ///
                   (scatter _rowid _colid if _corr >= 0.8, ///
                    msymbol(square) msize(large) mcolor(navy)) ///
                   (scatter _rowid _colid if _corr < 0 & _corr >= -0.4, ///
                    msymbol(square) msize(large) mcolor(cranberry*0.3)) ///
                   (scatter _rowid _colid if _corr < -0.4 & _corr >= -0.7, ///
                    msymbol(square) msize(large) mcolor(cranberry*0.6)) ///
                   (scatter _rowid _colid if _corr < -0.7, ///
                    msymbol(square) msize(large) mcolor(cranberry)), ///
                xlabel(1(1)`nvar', angle(45) labsize(small)) ///
                ylabel(1(1)`nvar', angle(0) labsize(small)) ///
                xtitle("") ytitle("") ///
                title("Missingness Correlation Matrix") ///
                legend(order(1 "<0.2" 2 "0.2-0.4" 3 "0.4-0.6" 4 "0.6-0.8" 5 ">=0.8" ///
                       6 "neg low" 7 "neg med" 8 "neg high") ///
                       rows(1) size(vsmall) position(6)) ///
                aspectratio(1) ///
                `schemeopts'
            
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

end

exit

* Changes from mvpatterns 2.0.0:
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
