*! datamvp Version 1.8.1  2026/09/30
*! Fork of mvpatterns 2.0.0 by Jeroen Weesie (STB-61: dm91)
*! Author: Timothy P Copeland, Karolinska Institutet
*! Missing value pattern analysis with enhanced features

program define datamvp, rclass byable(recall) sortpreserve
    version 16.0
    local _legacy_globals : all globals
    foreach g in S_1 S_2 S_FN S_FNDATE S_1_full ReS_Call ReS_j ReS_jv ///
        ReS_jv2 ReS_i ReS_Xij Res_Xi ReS_atwl ReS_str rVANS rtmpST {
        local _had_`g' : list g in _legacy_globals
        mata: st_local("_old_" + st_local("g"), st_global(st_local("g")))
        if `"`macval(_old_`g')'"' != "" local _had_`g' = 1
    }

    local _uservarabbrev `c(varabbrev)'
    local _nomask_explicit = regexm(" " + lower(`"`macval(0)'"') + " ", "[ ,]nomask(r|ra|rar|rare)?[ ,]")
    local _return_ready = 0
    local _owned_preserved = 0
    local _return_has_missby = 0
    local _anymask = 0
    local _vmask = 0
    local _npooled = 0
    local _return_has_monotone = 0
    local _return_has_corr = 0
    set varabbrev off
    capture noisily {

    syntax [varlist] [if] [in] [, ///
        Minfreq(integer 1)      /// minimum frequency to display
        noTable                 /// suppress variable table
        SKip                    /// spaces every 5 vars
        SOrt                    /// sort vars by missingness
        noDrop                  /// keep vars with no missing
        Percent                 /// show percentages
        CUmulative              /// show cumulative freq/pct
        Ascending               /// sort patterns ascending
        MINMissing(integer -999999999)  /// min # missing vars in pattern
        MAXMissing(integer -999999999)  /// max # missing vars in pattern
        GENerate(name)          /// generate missingness indicators
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
        TOP(integer -999999999) /// number of top patterns to show
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
        GROUPgap(real -999999999) /// gap between bar groups
        LEGendopts(string asis) /// pass-through legend options
        GRAPHOPTions(string asis) /// additional twoway options
        /// Small-cell control and missingness by group
        MINCell(integer -999999999) /// mask counts below #
        MASKrare                /// mask counts below mincell() (default 5)
        BYTable(varname)        /// percent missing by group
    ]

    * Session defaults from dataqa set: explicit option > session default
    // an explicit nomaskrare turns the session masking off, mincell() included
    if `"$DATAMAP_DQ"' != "" & !`_nomask_explicit' {
        _datamap_dqdefaults
        if r(maskrare) & "`maskrare'" == "" local maskrare "maskrare"
        if `mincell' == -999999999 & r(mincell) >= 0 local mincell = r(mincell)
    }
    if `mincell' == -999999999 local mincell = 0
    if `mincell' < 0 {
        di as err "mincell() must be non-negative"
        exit 198
    }
    * Mask threshold m: mincell() when given, 5 under maskrare alone.  With
    * m > 0 no count from 1 to m-1 is printed, and no percentage or
    * complement from which one could be recovered.
    local _m = `mincell'
    if "`maskrare'" != "" & `_m' == 0 local _m = 5

    mata: st_local("title", _datamvp_graph_text(st_local("title")))
    mata: st_local("subtitle", _datamvp_graph_text(st_local("subtitle")))

    local _user_minmissing = (`minmissing' != -999999999)
    local _user_maxmissing = (`maxmissing' != -999999999)
    local _user_top = (`top' != -999999999)
    local _user_groupgap = (`groupgap' != -999999999)
    local _user_legendopts = (`"`legendopts'"' != "")

    if `minfreq' < 1 {
        di as err "minfreq() must be at least 1"
        exit 198
    }
    if `_user_minmissing' & `minmissing' < 0 {
        di as err "minmissing() must be non-negative"
        exit 198
    }
    if `_user_maxmissing' & `maxmissing' < 0 {
        di as err "maxmissing() must be non-negative"
        exit 198
    }
    if !`_user_minmissing' local minmissing = -1
    if !`_user_maxmissing' local maxmissing = -1
    if !`_user_top' local top = 20
    if !`_user_groupgap' local groupgap = 0

    * Validate graph-related options require graph()
    if "`graph'" == "" {
        if "`scheme'" != "" {
            di as err "option {bf:scheme()} requires {bf:graph()} option"
            exit 198
        }
        if `"`macval(title)'"' != "" | `"`macval(subtitle)'"' != "" {
            di as err "options {bf:title()} and {bf:subtitle()} require {bf:graph()} option"
            exit 198
        }
        if "`gname'" != "" | `"`gsaving'"' != "" | "`draw'" != "" {
            di as err "options {bf:gname()}, {bf:gsaving()}, {bf:nodraw} require {bf:graph()} option"
            exit 198
        }
        if `"`graphoptions'"' != "" {
            di as err "option {bf:graphoptions()} requires {bf:graph()} option"
            exit 198
        }
        if `_user_groupgap' | `_user_legendopts' {
            di as err "options {bf:groupgap()} and {bf:legendopts()} require {bf:graph()} option"
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
    if `groupgap' < 0 | missing(`groupgap') {
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
        local graphorig `"`graph'"'
        local graph = lower(strtrim(`"`graph'"'))
        gettoken graphhead graphrest : graph, parse(",")
        local graphhead = strtrim("`graphhead'")
        * Parse matrix suboptions strictly: matrix, sample(#) sort
        if "`graphhead'" == "matrix" {
            local graphtype "matrix"
            local graphrest = strtrim("`graphrest'")
            if "`graphrest'" != "" {
                if substr("`graphrest'", 1, 1) != "," {
                    di as err "graph(matrix) suboptions must follow a comma"
                    exit 198
                }
                local graphrest = strtrim(substr("`graphrest'", 2, .))
                if "`graphrest'" == "" | strpos("`graphrest'", ",") > 0 {
                    di as err "invalid graph(matrix) suboptions"
                    exit 198
                }
                local seen_sample = 0
                local seen_sort = 0
                while "`graphrest'" != "" {
                    gettoken graphopt graphrest : graphrest
                    local graphopt = strtrim("`graphopt'")
                    if regexm("`graphopt'", "^sample\(([0-9]+)\)$") {
                        if `seen_sample' {
                            di as err "sample() may be specified only once in graph(matrix)"
                            exit 198
                        }
                        local matsample = real(regexs(1))
                        if `matsample' < 1 {
                            di as err "graph(matrix) sample() must be positive"
                            exit 198
                        }
                        local seen_sample = 1
                    }
                    else if "`graphopt'" == "sort" {
                        if `seen_sort' {
                            di as err "sort may be specified only once in graph(matrix)"
                            exit 198
                        }
                        local matsort = 1
                        local seen_sort = 1
                    }
                    else {
                        di as err "graph(matrix) suboption `graphopt' not recognized"
                        di as err "Valid suboptions: sample(#) sort"
                        exit 198
                    }
                }
            }
        }
        else if "`graphrest'" != "" | !inlist("`graphhead'", "bar", "patterns", "correlation") {
            di as err "graph() must be one of: bar, patterns, matrix, correlation"
            exit 198
        }
        else {
            local graphtype "`graphhead'"
        }
    }

    * graph(matrix) plots one row per observation: no mask can apply to it
    if "`graphtype'" == "matrix" & `_m' > 0 {
        di as err "graph(matrix) plots individual observations and is not available under masking"
        di as err "drop maskrare and mincell(), or type nomaskrare to override a session default"
        exit 198
    }

    * Validate gby/over compatibility with graph type
    if "`over'" != "" & "`graphtype'" != "bar" & "`graphtype'" != "" {
        di as err "option {bf:over()} requires graph(bar)"
        exit 198
    }
    if "`gby'" != "" & "`graphtype'" != "" {
        if !inlist("`graphtype'", "bar", "patterns") {
            di as err "option {bf:gby()} requires graph(bar) or graph(patterns)"
            exit 198
        }
    }
    if `_user_top' & "`graphtype'" != "patterns" & "`graphtype'" != "" {
        di as err "option {bf:top()} applies to the pattern table and graph(patterns); not to graph(`graphtype')"
        exit 198
    }
    * Patterns shown in the table: top() when given, 20 under masking,
    * otherwise all.  The rest are pooled into one final row.
    local tabtop = .
    if `_user_top' local tabtop = `top'
    else if `_m' > 0 local tabtop = 20
    if "`bytable'" != "" {
        capture confirm variable `bytable'
        if _rc {
            di as err "bytable() variable `bytable' not found"
            exit 111
        }
    }
    if (`_user_groupgap' | `_user_legendopts') & ///
        ("`graphtype'" != "bar" | "`over'" == "") {
        di as err "options {bf:groupgap()} and {bf:legendopts()} require graph(bar) with over()"
        exit 198
    }

    * Scratch variables and names
    tempvar touse grpseq isf mv_patt mv_n ng patpct cpct order
    tempname nsmall nsmallg corrmat

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
    local gby_isstr = 0
    if "`gby'" != "" {
        capture confirm string variable `gby'
        if _rc == 0 local gby_isstr = 1
        qui levelsof `gby' if `touse', local(gby_levels)
        local gby_nlev : word count `gby_levels'
        // Level k of `gby_levels' is group k: compare on this index, never on
        // the level text.  A float level such as 0.1 travels through levelsof
        // as .1000000014901161, which no float value equals, so every bar
        // came out missing.  group() and levelsof share the same sort order.
        tempvar gby_grp
        qui egen long `gby_grp' = group(`gby') if `touse'
        if `gby_nlev' < 2 {
            di as err "gby() variable must have at least 2 levels"
            exit 198
        }
        * Get value labels if available
        local gby_vallbl : value label `gby'
        * Pre-extract label texts (labels are lost after preserve/clear in graph code)
        local _gbi = 0
        foreach _lev of local gby_levels {
            local ++_gbi
            if "`gby_vallbl'" != "" {
                local _gby_lt_`_gbi' : label `gby_vallbl' `_lev'
            }
            else if `gby_isstr' {
                local _gby_lt_`_gbi' `"`macval(_lev)'"'
            }
            else {
                local _gby_lt_`_gbi' "`gby' = `_lev'"
            }
            mata: st_local("_gby_gt_`_gbi'", ///
                _datamvp_graph_text(st_local("_gby_lt_`_gbi'")))
        }
    }
    local over_levels ""
    local over_nlev = 0
    local over_isstr = 0
    if "`over'" != "" {
        capture confirm string variable `over'
        if _rc == 0 local over_isstr = 1
        qui levelsof `over' if `touse', local(over_levels)
        local over_nlev : word count `over_levels'
        // See gby(): compare on the group index, not the level text.
        tempvar over_grp
        qui egen long `over_grp' = group(`over') if `touse'
        if `over_nlev' < 2 {
            di as err "over() variable must have at least 2 levels"
            exit 198
        }
        * Get value labels if available
        local over_vallbl : value label `over'
        * Pre-extract label texts
        local _ovi = 0
        foreach _lev of local over_levels {
            local ++_ovi
            if "`over_vallbl'" != "" {
                local _over_lt_`_ovi' : label `over_vallbl' `_lev'
            }
            else if `over_isstr' {
                local _over_lt_`_ovi' `"`macval(_lev)'"'
            }
            else {
                local _over_lt_`_ovi' "`over' = `_lev'"
            }
            mata: st_local("_over_gt_`_ovi'", ///
                _datamvp_graph_text(st_local("_over_lt_`_ovi'")))
        }
    }

    * ===================================================================
    * Process variables - identify those with missing values
    * ===================================================================

    local nmvtotal = 0
    local origvarlist "`varlist'"
    local pctlist ""
    foreach v of local varlist {
        qui count if missing(`v') & `touse'
        local thismv = r(N)
        if `thismv' > 0 | "`drop'" != "" {
            local p : display %8.0f `thismv'
            local nmv `nmv' `p'
            local vlist `vlist' `v'
            local nmvtotal = `nmvtotal' + `thismv'
            * Store percent missing for bar graph, parallel to `vlist'
            * (a `pct_<varname>' local would overflow the 31-char macro-name
            * limit for long variable names and error r(198))
            local pctlist `pctlist' `=100 * `thismv' / `N''
        }
        else {
            local varnomv `varnomv' `v'
        }
    }
    local varlist `vlist'

    * Sort variables by missingness if requested
    if "`sort'" != "" & "`varlist'" != "" {
        tempname sortmat
        local nv : word count `varlist'
        matrix `sortmat' = J(`nv', 2, .)
        forv i = 1/`nv' {
            local m : word `i' of `nmv'
            matrix `sortmat'[`i', 1] = `m'
            matrix `sortmat'[`i', 2] = `i'
        }
        // Break ties on input position: Mata sort() is not stable, so equal
        // missing counts came out in arbitrary order (and the order drives
        // the pattern strings and the monotone test).
        mata: st_matrix(st_local("sortmat"), sort(st_matrix(st_local("sortmat")), (-1, 2)))
        local newvarlist ""
        local newpctlist ""
        forv i = 1/`nv' {
            local idx = `sortmat'[`i', 2]
            local v : word `idx' of `varlist'
            local newvarlist `newvarlist' `v'
            local p : word `idx' of `pctlist'
            local newpctlist `newpctlist' `p'
        }
        local varlist `newvarlist'
        local pctlist `newpctlist'
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
        return scalar N_patterns_pooled = 0
        return scalar mincell = `_m'
        return scalar maskrare = ("`maskrare'" != "")
        return scalar masked = 0
        if "`origvarlist'" != "" {
            return local varlist_nomiss "`origvarlist'"
        }
        // A clean -exit 0- here would leave the capture block WITHOUT reaching
        // the post-block restore (capture only intercepts errors), leaking
        // -set varabbrev off- to the user; restore before exiting.
    foreach g in S_1 S_2 S_FN S_FNDATE S_1_full ReS_Call ReS_j ReS_jv ///
        ReS_jv2 ReS_i ReS_Xij Res_Xi ReS_atwl ReS_str rVANS rtmpST {
        if `_had_`g'' mata: st_global(st_local("g"), st_local("_old_" + st_local("g")))
        else macro drop `g'
    }
        set varabbrev `_uservarabbrev'
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
            local len = max(`len', length(`"`macval(vlab)'"'))
        }
        
        if "`wide'" != "" {
            local vlwidth = min(`linesize'-50, `len', 30)
        }
        else {
            local vlwidth = min(`linesize'-40, `len')
        }
        * Obs and Miss are sized from the largest count and always use
        * comma format; the rule spans the whole table.
        local cw = max(5, length(strtrim(string(`N', "%20.0fc"))))
        local c_obs = 24
        local c_miss = `c_obs' + `cw' + 2
        local c_pct = `c_miss' + `cw' + 1
        local c_lab = `c_pct' + 8
        local vlwidth = max(1, min(`vlwidth', `linesize' - `c_lab' - 1))
        local ndup = `c_lab' - 14 + `vlwidth'

        di as txt _n "Variable     {c |} Type" _col(`c_obs') %`cw's "Obs" ///
            _col(`c_miss') %`cw's "Miss" _col(`c_pct') %6s "%Miss" ///
            _col(`c_lab') "Variable label"
        di as txt "{hline 13}{c +}{hline `ndup'}"

        local i 0
        foreach v of local varlist {
            local ++i

            qui count if missing(`v') & `touse'
            local thismv = r(N)
            local nobsv = `N' - `thismv'
            local s_obs = strtrim(string(`nobsv', "%20.0fc"))
            local s_miss = strtrim(string(`thismv', "%20.0fc"))
            local s_pct = strtrim(string(100 * `thismv' / `N', "%6.1f"))
            if `_m' > 0 {
                // a small Miss (or a small Obs) is masked, and the other
                // count and the percentage are withheld because N minus
                // either would recover it
                if `thismv' >= 1 & `thismv' < `_m' {
                    local s_miss "<`_m'"
                    if `nobsv' >= 1 local s_obs "."
                    local s_pct "."
                    local _anymask = 1
                    local _vmask = 1
                }
                else if `nobsv' >= 1 & `nobsv' < `_m' {
                    // a zero Miss stays 0: it reveals nothing about N
                    local s_obs "<`_m'"
                    if `thismv' >= 1 {
                        local s_miss "."
                        local s_pct "."
                    }
                    local _anymask = 1
                    local _vmask = 1
                }
            }

            local vt : type `v'
            local vlab : var label `v'
            local vl : piece 1 `vlwidth' of `"`macval(vlab)'"'

            di as txt "{lalign 12:`v'}" "{col 14}{c |}" as res ///
                _col(16) "`:di %7s abbrev("`vt'",7)'" ///
                _col(`c_obs') %`cw's "`s_obs'" ///
                _col(`c_miss') %`cw's "`s_miss'" ///
                _col(`c_pct') %6s "`s_pct'" ///
                _col(`c_lab') as txt `"`macval(vl)'"'

            * Rest of variable label
            local j 2
            local vl : piece `j' `vlwidth' of `"`macval(vlab)'"'
            while `"`macval(vl)'"' != "" {
                di as txt "{col 14}{c |}{col `c_lab'}" `"`macval(vl)'"'
                local ++j
                local vl : piece `j' `vlwidth' of `"`macval(vlab)'"'
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
        bys `touse' `mv_patt': gen byte `grpseq' = 1 if _n == 1 & `touse' == 1
        replace `grpseq' = sum(`grpseq')
        replace `grpseq' = . if `touse' != 1

        * Frequency per pattern
        bys `grpseq': gen `isf' = (_n == 1) & `touse'
        bys `grpseq': gen long `ng' = _N if `touse'

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
        gen double `patpct' = 100 * `ng' / `N' if `touse'
        gen long `order' = _n if `isf'
        sort `order'
        gen double `cpct' = sum(`patpct' * `isf') if `touse'
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

    * Display patterns
    preserve
    local _owned_preserved = 1
    qui keep if `isf'
    qui count
    local npat = r(N)

    if `npat' == 0 {
        di as txt "(no patterns match criteria)"
    }
    else {
        qui {
            keep `mv_patt' `mv_n' `ng' `patpct' `cpct' `order'
            rename `mv_patt' _pattern
            rename `mv_n' _miss
            rename `ng' _freq
            rename `patpct' _pct
            rename `cpct' _cumpct
            format _freq %8.0fc
            format _miss %4.0f
            format _pct %7.2f
            format _cumpct %7.2f
        }

        * Pool the patterns below the mask and beyond tabtop into one final
        * row.  Without pooling the table is listed exactly as before.
        if `_m' > 0 | `tabtop' < . {
            qui gen byte _pool = 0
            if `_m' > 0 qui replace _pool = 1 if _freq < `_m'
            local _bytop = 0
            if `tabtop' < . {
                qui gen long _ord = _n
                qui gsort -_freq _ord
                qui count if _n > `tabtop' & !_pool
                local _bytop = r(N)
                qui replace _pool = 1 if _n > `tabtop'
                qui sort _ord
                qui drop _ord
            }
            // Secondary suppression: a pooled total below m would be N minus
            // the shown patterns, so the smallest shown pattern joins the
            // pool until the pooled total is at least m.
            local _pulled = 0
            if `_m' > 0 {
                qui summarize _freq if _pool, meanonly
                local _pf = r(sum)
                while `_pf' >= 1 & `_pf' < `_m' {
                    qui count if !_pool
                    if r(N) == 0 continue, break
                    qui summarize _freq if !_pool, meanonly
                    local _mn = r(min)
                    qui gen byte _cand = !_pool & _freq == `_mn'
                    qui replace _pool = 1 if _cand & sum(_cand) == 1
                    qui drop _cand
                    local ++_pulled
                    qui summarize _freq if _pool, meanonly
                    local _pf = r(sum)
                }
            }
            qui count if _pool
            local _npooled = r(N)
            // graph(patterns) draws only the patterns this table shows
            if `_m' > 0 {
                qui levelsof `order' if !_pool, local(_shownord)
            }
        }
        local _plab ""
        if `_npooled' > 0 | `_m' > 0 {
            local _pfreq = 0
            if `_npooled' > 0 {
                qui summarize _freq if _pool, meanonly
                local _pfreq = r(sum)
                qui drop if _pool
            }
            qui drop _pool
            local _nk = _N
            qui gen str20 _fs = strtrim(string(_freq, "%12.0fc"))
            qui gen str12 _ps = strtrim(string(_pct, "%7.2f"))
            qui gen double _c = sum(_pct)
            qui gen str12 _cs = strtrim(string(_c, "%7.2f"))
            if `_npooled' > 0 {
                qui set obs `=`_nk' + 1'
                if `_m' > 0 & `_bytop' == 0 & `_pulled' == 0 local _plab "other patterns (each <`_m')"
                else if `_m' > 0 & `_bytop' == 0 local _plab "other patterns (<`_m', or pooled with them)"
                else if `_m' > 0 local _plab "other patterns (beyond top `tabtop' or <`_m')"
                else local _plab "other patterns (beyond top `tabtop')"
                qui replace _pattern = "`_plab'" in L
                local _ppct = 100 * `_pfreq' / `N'
                if `_m' > 0 & `_pfreq' >= 1 & `_pfreq' < `_m' {
                    // the pooled total is itself a small cell; its share and
                    // the cumulative share after it would recover it
                    qui replace _fs = "<`_m'" in L
                    qui replace _ps = "." in L
                    qui replace _cs = "." in L
                    local _anymask = 1
                }
                else {
                    qui replace _fs = strtrim(string(`_pfreq', "%12.0fc")) in L
                    qui replace _ps = strtrim(string(`_ppct', "%7.2f")) in L
                    qui replace _cs = strtrim(string(_c[`_nk'] + `_ppct', "%7.2f")) in L
                    if `_nk' == 0 qui replace _cs = strtrim(string(`_ppct', "%7.2f")) in L
                }
                if `_m' > 0 local _anymask = 1
            }
            qui drop _freq _pct _cumpct _c
            rename _fs _freq
            rename _ps _pct
            rename _cs _cumpct
            format _freq %12s
            format _pct %8s
            format _cumpct %8s
            local _pw = max(8, `: strlen local _plab')
            format _pattern %-`_pw's
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
    local _owned_preserved = 0

    * Summarize patterns not listed
    if `nsmallg' > 0 & `minfreq' > 1 {
        local _nss = strtrim(string(scalar(`nsmall'), "%20.0fc"))
        if `_m' > 0 & scalar(`nsmall') >= 1 & scalar(`nsmall') < `_m' {
            local _nss "<`_m'"
            local _anymask = 1
        }
        if `minfreq' == 2 {
            di _n as txt "Additional: {res}`_nss'" ///
                as txt " observations with unique patterns"
        }
        else {
            di _n as txt "Additional: {res}`_nss'" ///
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
        local s_N = strtrim(string(`N', "%20.0fc"))
        local s_cc = strtrim(string(`ncomplete', "%20.0fc"))
        local s_ic = strtrim(string(`nincomplete', "%20.0fc"))
        local s_ccp = strtrim(string(100*`ncomplete'/`N', "%5.1f"))
        local s_icp = strtrim(string(100*`nincomplete'/`N', "%5.1f"))
        local s_max = strtrim(string(`maxmiss_obs', "%20.0fc"))
        if `_m' > 0 {
            if `N' < `_m' {
                local s_N "<`_m'"
                local _anymask = 1
            }
            // complete + incomplete = N: when either is small, both are
            // withheld, with their percentages; a zero count stays 0
            if (`ncomplete' >= 1 & `ncomplete' < `_m') | (`nincomplete' >= 1 & `nincomplete' < `_m') {
                local _z = (`ncomplete' == 0 | `nincomplete' == 0)
                local s_cc = cond(`ncomplete' >= 1 & `ncomplete' < `_m', "<`_m'", cond(`ncomplete' == 0, "0", "[suppressed]"))
                local s_ic = cond(`nincomplete' >= 1 & `nincomplete' < `_m', "<`_m'", cond(`nincomplete' == 0, "0", "[suppressed]"))
                if !`_z' {
                    local s_ccp "."
                    local s_icp "."
                }
                local _anymask = 1
            }
            // the maximum is shown only when enough observations share it
            qui count if `mv_n' == `maxmiss_obs' & `touse'
            if r(N) < `_m' {
                local s_max "[suppressed]"
                local _anymask = 1
            }
        }
        di _n as txt "{hline 50}"
        di as txt "Total observations:      " as res %10s "`s_N'"
        // a withheld share is left out, never printed as ".%"
        if "`s_ccp'" == "." di as txt "Complete cases:          " as res %10s "`s_cc'"
        else di as txt "Complete cases:          " as res %10s "`s_cc'" ///
            as txt "  (" as res %5s "`s_ccp'" as txt "%)"
        if "`s_icp'" == "." di as txt "Incomplete cases:        " as res %10s "`s_ic'"
        else di as txt "Incomplete cases:        " as res %10s "`s_ic'" ///
            as txt "  (" as res %5s "`s_icp'" as txt "%)"
        di as txt "Unique patterns:         " as res %10.0fc `npatterns'
        di as txt "Variables analyzed:      " as res %10.0fc `nvar'
        di as txt "Max missing/obs:         " as res %10s "`s_max'"
        // mean x N is the total of missing cells: beside the other
        // variables' shown Miss counts it recovers a masked one
        local s_mean = strtrim(string(`meanmiss', "%10.2f"))
        if `_m' > 0 & `_vmask' {
            local s_mean "[suppressed]"
            local _anymask = 1
        }
        di as txt "Mean missing/obs:        " as res %10s "`s_mean'"
        if `_npooled' > 0 {
            di as txt "Patterns pooled:         " as res %10.0fc `_npooled'
        }
        if `_m' > 0 di as txt "(counts below `_m' masked)"
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
            local s_mono = strtrim(string(`nmono', "%20.0fc"))
            local s_mpct = strtrim(string(`pctmono', "%5.1f"))
            if `_m' > 0 & `nmono' >= 1 & (`nmono' < `_m' | `N' - `nmono' < `_m') {
                local s_mono = cond(`nmono' >= 1 & `nmono' < `_m', "<`_m'", "all but <`_m'")
                local s_mpct "."
                local _anymask = 1
            }
            if "`s_mpct'" == "." di as txt "  Observations with monotone pattern: " as res "`s_mono'"
            else di as txt "  Observations with monotone pattern: " ///
                as res "`s_mono'" as txt " (" as res "`s_mpct'" as txt "%)"
            di as txt "  Pattern is {res}non-monotone{txt}"
            local mono_status "non-monotone"
        }
        
            local _return_has_monotone = 1
    }

    * ===================================================================
    * Correlations of missingness
    * ===================================================================

    if ("`correlate'" != "" | "`graphtype'" == "correlation") & `nvar' <= 1 {
        if "`correlate'" != "" {
            di as txt "(correlate requires at least 2 variables with missing values; skipped)"
        }
    }
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
        
        * Try tetrachoric; retain its failure code before Pearson fallback
        capture tetrachoric `misslist' if `touse'
        local tetra_rc = _rc
        if `tetra_rc' == 0 {
            * tetrachoric succeeded
            matrix `corrmat' = r(Rho)
            
            * Rename matrix rows/cols
            local rnames
            forv i = 1/`nvar' {
                local rnames `rnames' ``i''
            }
            matrix rownames `corrmat' = `rnames'
            matrix colnames `corrmat' = `rnames'
            if "`correlate'" != "" {
                matrix list `corrmat', format(%6.3f) noheader
            }

            local _return_has_corr = 1
        }
        else {
            * Fall back to pwcorr
            if "`correlate'" != "" {
                di as txt "(tetrachoric failed (rc=`tetra_rc'); using Pearson correlations)"
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

            local _return_has_corr = 1
        }
    }

    * ===================================================================
    * Missingness by group: bytable()
    * ===================================================================

    tempname MB
    if "`bytable'" != "" {
        tempvar _bt
        qui gen byte `_bt' = `touse' & !missing(`bytable')
        qui count if `_bt'
        if r(N) == 0 {
            di as err "bytable(): no observations with nonmissing `bytable'"
            exit 2000
        }
        * one computation of missingness by group for the whole package:
        * datacheck groupstat(pmiss ...) reads the same helper
        _datamap_missby `varlist', by(`bytable') touse(`_bt')
        local G = r(G)
        forvalues k = 1/`G' {
            local _bl`k' `"`r(lab`k')'"'
        }
        tempname _NM _PM _NG
        matrix `_NM' = r(nmiss)
        matrix `_PM' = r(pmiss)
        matrix `_NG' = r(ngroup)
        matrix `MB' = J(`nvar', `G' + 2, .)
        local _cn ""
        forvalues k = 1/`G' {
            local _cn "`_cn' g`k'"
        }
        matrix colnames `MB' = `_cn' maxdiff ratio
        matrix rownames `MB' = `varlist'
        forvalues i = 1/`nvar' {
            local _hi = .
            local _lo = .
            local _shi = .
            local _slo = .
            local _nshown = 0
            forvalues k = 1/`G' {
                local _p = 100 * `_PM'[`i', `k']
                matrix `MB'[`i', `k'] = `_p'
                local _hi = cond(missing(`_hi'), `_p', max(`_hi', `_p'))
                local _lo = cond(missing(`_lo'), `_p', min(`_lo', `_p'))
                // shown cells: a group of at least m rows whose missing
                // count and complement are both zero or at least m
                local _nk = `_NG'[1, `k']
                local _mk = `_NM'[`i', `k']
                local _sh = 1
                if `_m' > 0 {
                    if `_nk' < `_m' local _sh = 0
                    if (`_mk' >= 1 & `_mk' < `_m') | (`_nk' - `_mk' >= 1 & `_nk' - `_mk' < `_m') local _sh = 0
                }
                local _show`i'_`k' = `_sh'
                if `_sh' {
                    local ++_nshown
                    local _shi = cond(missing(`_shi'), `_p', max(`_shi', `_p'))
                    local _slo = cond(missing(`_slo'), `_p', min(`_slo', `_p'))
                }
                else local _anymask = 1
            }
            matrix `MB'[`i', `G' + 1] = `_hi' - `_lo'
            matrix `MB'[`i', `G' + 2] = cond(`_lo' > 0, `_hi' / `_lo', .)
            local _sd`i' "."
            local _sr`i' "."
            // a difference needs two shown groups; one cell compares nothing
            if `_nshown' >= 2 {
                local _sd`i' = strtrim(string(`_shi' - `_slo', "%6.1f"))
                if `_slo' > 0 local _sr`i' = strtrim(string(`_shi' / `_slo', "%6.2f"))
            }
        }
        * display: variables by groups, in blocks that fit the line
        di _n as txt "Percent missing by `bytable'"
        local _per = max(1, floor((`linesize' - 14 - 20) / 9))
        local _k0 = 1
        while `_k0' <= `G' {
            local _k1 = min(`G', `_k0' + `_per' - 1)
            local _last = (`_k1' == `G')
            local _hdr ""
            forvalues k = `_k0'/`_k1' {
                local _t = abbrev(`"`_bl`k''"', 8)
                local _hdr `"`_hdr' as txt %9s `"`_t'"'"'
            }
            if `_last' local _hdr `"`_hdr' as txt %10s "Max diff" %9s "Hi/Lo""'
            di as txt "{lalign 12:Variable}" "{col 14}{c |}" `_hdr'
            forvalues i = 1/`nvar' {
                local v : word `i' of `varlist'
                local _line ""
                forvalues k = `_k0'/`_k1' {
                    local _c "."
                    if `_show`i'_`k'' local _c = strtrim(string(`MB'[`i', `k'], "%6.1f"))
                    local _line `"`_line' as res %9s "`_c'""'
                }
                if `_last' local _line `"`_line' as res %10s "`_sd`i''" %9s "`_sr`i''""'
                di as txt "{lalign 12:`=abbrev("`v'", 12)'}" "{col 14}{c |}" `_line'
            }
            local _k0 = `_k1' + 1
        }
        if `_m' > 0 di as txt "(cells from groups or counts below `_m' shown as .)"
        local _return_has_missby = 1
    }

    * The analytical payload is now complete.  Optional generate/save/graph
    * failures must not strand it, so all returns are posted at the gate below.
    local _return_ready = 1

    * ===================================================================
    * Generate missingness indicators
    * ===================================================================

    if "`generate'" != "" {
        if length("`generate'") > 23 {
            di as err "generate() stub too long (max 23 characters)"
            exit 198
        }
        local maxvlen = 32 - length("`generate'") - 1
        local _gennames ""
        tokenize `varlist'
        forv i = 1/`nvar' {
            local source_name "``i''"
            local vname = substr("`source_name'", 1, `maxvlen')
            local outname "`generate'_`vname'"
            if inlist("`outname'", "`generate'_pattern", "`generate'_nmiss") {
                di as err "generate() output for `source_name' conflicts with reserved summary name `outname'"
                exit 198
            }
            local collision_index = 1
            while `: list outname in _gennames' {
                local ++collision_index
                local tag "_`i'"
                if `collision_index' > 2 local tag "_`i'_`collision_index'"
                local vname = substr("`source_name'", 1, `maxvlen' - length("`tag'")) + "`tag'"
                local outname "`generate'_`vname'"
            }
            capture confirm new variable `outname'
            if _rc {
                local genrc = _rc
                di as err "generate() target `outname' already exists"
                exit `genrc'
            }
            local _gennames "`_gennames' `outname'"
            local _genname_`i' "`outname'"
        }

        foreach outname in `generate'_pattern `generate'_nmiss {
            capture confirm new variable `outname'
            if _rc {
                local genrc = _rc
                di as err "generate() target `outname' already exists"
                exit `genrc'
            }
        }

        * Every target has passed preflight; generation is now atomic.
        tokenize `varlist'
        forv i = 1/`nvar' {
            local outname "`_genname_`i''"
            qui gen byte `outname' = missing(``i'') if `touse'
            label var `outname' "Missing: ``i''"
        }
        qui gen str`nstr' `generate'_pattern = `mv_patt' if `touse'
        label var `generate'_pattern "Missing value pattern"
        qui gen int `generate'_nmiss = `mv_n' if `touse'
        label var `generate'_nmiss "Number of missing values"
        
        di _n as txt "Generated variables: {res}`generate'_*"
    }

    * ===================================================================
    * Save patterns to file
    * ===================================================================

    if "`save'" != "" {
        preserve
        local _owned_preserved = 1
        qui keep if `isf'
        qui keep `mv_patt' `mv_n' `ng' `patpct' `cpct'
        qui rename `mv_patt' pattern
        qui rename `mv_n' nmiss
        qui rename `ng' freq
        qui rename `patpct' percent
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
                local _drop_save_frame_rc = _rc
                if `_drop_save_frame_rc' != 0 & `_drop_save_frame_rc' != 111 {
                    exit `_drop_save_frame_rc'
                }
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
        local _owned_preserved = 0
    }

    * ===================================================================
    * Graphs
    * ===================================================================

    if "`graphtype'" != "" {
        * Graph inputs below are derived data, not the caller's native file.
        macro drop S_FN S_FNDATE

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
        if `"`macval(title)'"' != "" {
            local titleopts `"title(`"`macval(title)'"')"'
        }
        local subtitleopts ""
        if `"`macval(subtitle)'"' != "" {
            local subtitleopts `"subtitle(`"`macval(subtitle)'"')"'
        }

        * -----------------------------------------------------------------
        * Bar chart: percent missing by variable
        * -----------------------------------------------------------------
        if "`graphtype'" == "bar" {
            preserve
            local _owned_preserved = 1

            * Under masking a bar is withheld when its missing count or the
            * complement is from 1 to m-1 (the rule of the variable table);
            * with gby() or over() the group size below m withholds it too
            local _gmask ""
            local _ngmask = 0
            local _nbar = 1
            if `_m' > 0 & "`gby'" == "" & "`over'" == "" {
                tokenize `varlist'
                forv i = 1/`nvar' {
                    qui count if missing(``i'') & `touse'
                    local _gk = (r(N) >= 1 & r(N) < `_m') | (`N' - r(N) >= 1 & `N' - r(N) < `_m')
                    local _gmask `_gmask' `_gk'
                    local _ngmask = `_ngmask' + `_gk'
                }
            }

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
                    gen int gbyid = .
                    tempname gby_graph_label

                    local row = 1
                    local _gbi = 0
                    tokenize `varlist'
                    foreach lev of local gby_levels {
                        local ++_gbi
                        mata: st_vlmodify(st_local("gby_graph_label"), ///
                            `_gbi', st_local("_gby_gt_`_gbi'"))
                        forv i = 1/`nvar' {
                            replace varname = "``i''" in `row'
                            replace varorder = `i' in `row'
                            replace gbyid = `_gbi' in `row'
                            local ++row
                        }
                    }
                    label values gbyid `gby_graph_label'

                    * Now calculate actual percentages using original data
                    * First save the tempfile we just created
                    tempfile gby_tempdata
                    save `gby_tempdata', replace

                    local row = 1
                    forvalues _gk = 1/`gby_nlev' {
                        forv i = 1/`nvar' {
                            restore, preserve
                            qui count if `gby_grp' == `_gk' & `touse'
                            local nlev = r(N)
                            qui count if missing(``i'') & `gby_grp' == `_gk' & `touse'
                            local nmisslev = r(N)
                            local pctlev = 100 * `nmisslev' / `nlev'
                            if `_m' > 0 & (`nlev' < `_m' | ///
                                (`nmisslev' >= 1 & `nmisslev' < `_m') | ///
                                (`nlev' - `nmisslev' >= 1 & `nlev' - `nmisslev' < `_m')) {
                                local pctlev = .
                                local ++_ngmask
                            }
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
                local bartitle_text = cond(`"`macval(title)'"' != "", "", `"title("Missing Values by Variable and `gby'")"')

                * Draw faceted bar chart
                if `_ngmask' > 0 {
                    quietly count if !missing(pctmiss)
                    local _nbar = r(N)
                }
                if `_ngmask' > 0 & `_nbar' == 0 {
                    di as txt "(graph not drawn: every bar comes from a count below `_m')"
                }
                else {
                    `barcmd' pctmiss, over(varname, sort(varorder) label(labsize(`labsz'))) ///
                        by(gbyid, note("") `macval(titleopts)' ///
                            `macval(subtitleopts)') ///
                        ytitle("Percent missing") ///
                        `bartitle_text' ///
                        blabel(bar, format(%4.1f) size(tiny)) ///
                        bar(1, color(`barcolor')) ///
                        `schemeopts' `nameopts' `savingopts' `drawopts' `graphoptions'
                    if `_ngmask' > 0 di as txt "(graph: `_ngmask' bar(s) from counts below `_m' withheld)"
                }
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
                    gen int overid = .
                    tempname over_graph_label

                    local row = 1
                    local _ovi = 0
                    tokenize `varlist'
                    foreach lev of local over_levels {
                        local ++_ovi
                        mata: st_vlmodify(st_local("over_graph_label"), ///
                            `_ovi', st_local("_over_gt_`_ovi'"))
                        forv i = 1/`nvar' {
                            replace varname = "``i''" in `row'
                            replace varorder = `i' in `row'
                            replace overid = `_ovi' in `row'
                            local ++row
                        }
                    }
                    label values overid `over_graph_label'

                    * Now calculate actual percentages using original data
                    * First save the tempfile we just created
                    tempfile over_tempdata
                    save `over_tempdata', replace

                    local row = 1
                    forvalues _ok = 1/`over_nlev' {
                        forv i = 1/`nvar' {
                            restore, preserve
                            qui count if `over_grp' == `_ok' & `touse'
                            local nlev = r(N)
                            qui count if missing(``i'') & `over_grp' == `_ok' & `touse'
                            local nmisslev = r(N)
                            local pctlev = 100 * `nmisslev' / `nlev'
                            if `_m' > 0 & (`nlev' < `_m' | ///
                                (`nmisslev' >= 1 & `nmisslev' < `_m') | ///
                                (`nlev' - `nmisslev' >= 1 & `nlev' - `nmisslev' < `_m')) {
                                local pctlev = .
                                local ++_ngmask
                            }
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
                local bartitle_text = cond(`"`macval(title)'"' != "", "", `"title("Missing Values by Variable")"')

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
                if `_ngmask' > 0 {
                    quietly count if !missing(pctmiss)
                    local _nbar = r(N)
                }
                if `_ngmask' > 0 & `_nbar' == 0 {
                    di as txt "(graph not drawn: every bar comes from a count below `_m')"
                }
                else {
                    `barcmd' pctmiss, over(overid, `gapopts') ///
                        over(varname, sort(varorder) label(labsize(`labsz'))) ///
                        ytitle("Percent missing") ///
                        `bartitle_text' ///
                        `macval(titleopts)' `macval(subtitleopts)' ///
                        blabel(bar, format(%4.1f) size(tiny)) ///
                        asyvars ///
                        `legendopts_final' ///
                        `schemeopts' `nameopts' `savingopts' `drawopts' `graphoptions'
                    if `_ngmask' > 0 di as txt "(graph: `_ngmask' bar(s) from counts below `_m' withheld)"
                }
            }

            * Handle stacked option — each variable is a separate bar segment
            else if "`stacked'" != "" {
                qui {
                    clear
                    set obs 1
                    gen str1 grp = " "

                    tokenize `varlist'
                    forv i = 1/`nvar' {
                        local _p : word `i' of `pctlist'
                        if `_m' > 0 {
                            if `: word `i' of `_gmask'' local _p = .
                        }
                        gen double pct`i' = `_p'
                        label var pct`i' "``i''"
                    }
                }

                * Set default title if not specified
                local bartitle_text = cond(`"`macval(title)'"' != "", "", `"title("Missing Values by Variable (Stacked)")"')

                * Build bar color options for each variable
                local baropts ""
                local ncolors : word count navy cranberry dkgreen orange teal purple olive magenta brown dkorange
                local colorlist "navy cranberry dkgreen orange teal purple olive magenta brown dkorange"
                forv i = 1/`nvar' {
                    local ci = mod(`i'-1, `ncolors') + 1
                    local thiscolor : word `ci' of `colorlist'
                    local baropts `"`baropts' bar(`i', color(`thiscolor'))"'
                }

                * Draw stacked bar chart with each variable as a segment
                if `_ngmask' > 0 {
                    local _nbar = `nvar' - `_ngmask'
                }
                if `_ngmask' > 0 & `_nbar' == 0 {
                    di as txt "(graph not drawn: every bar comes from a count below `_m')"
                }
                else {
                    `barcmd' (asis) pct1-pct`nvar', ///
                        over(grp) stack ///
                        ytitle("Percent missing") ///
                        `bartitle_text' ///
                        `macval(titleopts)' `macval(subtitleopts)' ///
                        legend(rows(2) position(6) size(vsmall)) ///
                        `baropts' ///
                        `schemeopts' `nameopts' `savingopts' `drawopts' `graphoptions'
                    if `_ngmask' > 0 di as txt "(graph: `_ngmask' bar(s) from counts below `_m' withheld)"
                }
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
                        local _p : word `i' of `pctlist'
                        if `_m' > 0 {
                            if `: word `i' of `_gmask'' local _p = .
                        }
                        replace varname = "``i''" in `i'
                        replace pctmiss = `_p' in `i'
                    }
                }

                * Set default title if not specified
                local bartitle_text = cond(`"`macval(title)'"' != "", "", `"title("Missing Values by Variable")"')

                if `_ngmask' > 0 {
                    quietly count if !missing(pctmiss)
                    local _nbar = r(N)
                }
                if `_ngmask' > 0 & `_nbar' == 0 {
                    di as txt "(graph not drawn: every bar comes from a count below `_m')"
                }
                else {
                    `barcmd' pctmiss, over(varname, sort(varorder) label(labsize(`labsz'))) ///
                        ytitle("Percent missing") ///
                        `bartitle_text' ///
                        `macval(titleopts)' `macval(subtitleopts)' ///
                        blabel(bar, format(%4.1f) size(vsmall)) ///
                        bar(1, color(`barcolor')) ///
                        `schemeopts' `nameopts' `savingopts' `drawopts' `graphoptions'
                    if `_ngmask' > 0 di as txt "(graph: `_ngmask' bar(s) from counts below `_m' withheld)"
                }
            }

            restore
            local _owned_preserved = 0
        }

        * -----------------------------------------------------------------
        * Patterns: bar chart of pattern frequencies
        * -----------------------------------------------------------------
        else if "`graphtype'" == "patterns" {
            preserve
            local _owned_preserved = 1

            * Handle gby() option for patterns - faceted display
            if "`gby'" != "" {
                * Need to recalculate patterns by group
                restore, preserve
                qui keep if `touse'

                * Create pattern data by group
                qui {
                    * Keep needed variables
                    keep `varlist' `gby' `gby_grp'

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
                    // under masking a group's pattern below m is not drawn
                    count if _ng < `_m'
                    local _npwh = r(N)
                    drop if _ng < `_m'

                    * Get group labels (use pre-extracted texts)
                    gen int _gbyid = .
                    tempname pattern_gby_label
                    local _gbi = 0
                    foreach lev of local gby_levels {
                        local ++_gbi
                        replace _gbyid = `_gbi' if `gby_grp' == `_gbi'
                        mata: st_vlmodify(st_local("pattern_gby_label"), ///
                            `_gbi', st_local("_gby_gt_`_gbi'"))
                    }
                    label values _gbyid `pattern_gby_label'

                    * Keep top patterns per group
                    bys `gby' (_ng _mv_n): gen int _patorder = _N - _n + 1
                    keep if _patorder <= `top'

                    * Create pattern ID
                    bys `gby' (_patorder): gen str8 _patid = "P" + string(_n)

                    * Get first pattern for note (overall most common)
                    gsort -_ng
                    local pat1 = _mv_patt[1]
                }

                * Put graph-level titles inside by() so facet labels remain visible.
                local patby_titleopts `"`macval(titleopts)'"'
                if `"`macval(title)'"' == "" {
                    local patby_titleopts `"title("Missing Value Patterns by `gby'")"'
                }
                local patby_subtitleopts `"`macval(subtitleopts)'"'
                if `"`macval(subtitle)'"' == "" {
                    local patby_subtitleopts `"subtitle("(Top `top' patterns per group)")"'
                }

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
                if _N == 0 {
                    di as txt "(graph not drawn: every pattern has a frequency below `_m' in its group)"
                }
                else {
                    `barcmd' _ng, over(_patid, sort(_patorder) label(labsize(`patlabsz'))) ///
                        by(_gbyid, note("") `macval(patby_titleopts)' ///
                            `macval(patby_subtitleopts)') ///
                        ytitle("Frequency") ///
                        blabel(bar, format(%9.0fc) size(tiny)) ///
                        note("P1=`pat1_display'", size(vsmall)) ///
                        bar(1, color(`barcolor')) ///
                        `schemeopts' `nameopts' `savingopts' `drawopts' `graphoptions'
                }
                if `_npwh' > 0 di as txt "(graph: `_npwh' group pattern(s) with a frequency below `_m' withheld)"
            }

            * Standard patterns chart (no stratification)
            else {
                qui keep if `isf'
                // under masking only the patterns the table shows are drawn:
                // a pattern pooled for secondary suppression would recover
                // the pooled small total
                local _npwh = 0
                if `_m' > 0 {
                    tempvar _shown
                    qui gen byte `_shown' = 0
                    foreach _k of local _shownord {
                        qui replace `_shown' = 1 if `order' == `_k'
                    }
                    qui count if !`_shown'
                    local _npwh = r(N)
                    qui keep if `_shown'
                }
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
                    local pattitle_text = cond(`"`macval(title)'"' != "", "", `"title("Most Common Missing Value Patterns")"')
                    local patsubtitle_text = cond(`"`macval(subtitle)'"' != "", "", `"subtitle("(Top `npat_graph' patterns)")"')

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
                        `macval(titleopts)' `macval(subtitleopts)' ///
                        blabel(bar, format(%9.0fc) size(vsmall)) ///
                        note("P1=`pat1_display'", size(vsmall)) ///
                        bar(1, color(`barcolor')) ///
                        `schemeopts' `nameopts' `savingopts' `drawopts' `graphoptions'
                }
                else {
                    di as txt "(no patterns to graph)"
                }
                if `_npwh' > 0 di as txt "(graph: `_npwh' pattern(s) pooled in the table withheld)"
            }

            restore
            local _owned_preserved = 0
        }

        * -----------------------------------------------------------------
        * Matrix: observation x variable missingness heatmap
        * -----------------------------------------------------------------
        else if "`graphtype'" == "matrix" {
            preserve
            local _owned_preserved = 1

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

            tempvar obsid missflag varid
            // tempname: a fixed name collided with a user label _varlab (r(180))
            tempname varaxis_label
            qui {
                keep if `touse'

                * Sort by pattern if requested
                if `matsort' {
                    sort `mv_n' `mv_patt'
                }

                * Sample if needed
                if `use_sample' {
                    // the display sample must not move the caller's RNG
                    local _rngstate = c(rngstate)
                    sample `sample_n', count
                    set rngstate `_rngstate'
                }

                * Create observation ID
                gen long `obsid' = _n
                local nobs = _N

                * Reshape to long format for heatmap
                tokenize `varlist'
                forv i = 1/`nvar' {
                    gen byte `missflag'`i' = missing(``i'')
                }

                keep `obsid' `missflag'*
                reshape long `missflag', i(`obsid') j(`varid')

                * Create value labels for variable axis
                forv i = 1/`nvar' {
                    label define `varaxis_label' `i' "``i''", add
                }
                label values `varid' `varaxis_label'
            }

            * Set default title if not specified
            local mattitle_text = cond(`"`macval(title)'"' != "", "", `"title("Missing Value Matrix")"')
            local matsubtitle_text = cond(`"`macval(subtitle)'"' != "", "", `"subtitle("`nobs' observations x `nvar' variables")"')

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
            twoway (scatter `obsid' `varid' if `missflag' == 1, ///
                    msymbol(square) msize(`msize') mcolor(`misscolor')) ///
                   (scatter `obsid' `varid' if `missflag' == 0, ///
                    msymbol(square) msize(`msize') mcolor(`obscolor')), ///
                xlabel(1(1)`nvar', valuelabel angle(90) labsize(`xlabsz')) ///
                ylabel(, labsize(tiny) nogrid) ///
                ytitle("Observation") xtitle("Variable") ///
                `mattitle_text' `matsubtitle_text' ///
                `macval(titleopts)' `macval(subtitleopts)' ///
                legend(order(1 "Missing" 2 "Observed") rows(1) size(small) position(6)) ///
                plotregion(margin(zero)) ///
                `schemeopts' `nameopts' `savingopts' `drawopts' `graphoptions'

            restore
            local _owned_preserved = 0
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
            local _owned_preserved = 1
            tempvar rowid colid corr corrlabel colorint
            qui {
                clear
                local ncells = `nvar' * `nvar'
                set obs `ncells'
                gen int `rowid' = .
                gen int `colid' = .
                gen double `corr' = .
                gen str10 `corrlabel' = ""
                local obs = 1
                forv r = 1/`nvar' {
                    forv c = 1/`nvar' {
                        replace `rowid' = `r' in `obs'
                        replace `colid' = `c' in `obs'
                        * Use pre-extracted correlation value
                        local corrval = `corrval_`r'_`c''
                        replace `corr' = `corrval' in `obs'
                        * Format correlation label
                        if abs(`corrval') < 0.01 {
                            replace `corrlabel' = "" in `obs'
                        }
                        else {
                            replace `corrlabel' = string(`corrval', "%4.2f") in `obs'
                        }
                        local ++obs
                    }
                }

                * Create color intensity variable (0-10 scale for granularity)
                gen int `colorint' = .

                * Handle missing correlations (set to 0 = neutral)
                replace `colorint' = 0 if missing(`corr')
                replace `corrlabel' = "" if missing(`corr')

                * Assign colors based on ramp selection
                if "`colorramp'" == "bluered" | "`colorramp'" == "redblue" {
                    * For positive correlations (blue)
                    replace `colorint' = 1 if `corr' >= 0 & `corr' < 0.1 & !missing(`corr')
                    replace `colorint' = 2 if `corr' >= 0.1 & `corr' < 0.2
                    replace `colorint' = 3 if `corr' >= 0.2 & `corr' < 0.3
                    replace `colorint' = 4 if `corr' >= 0.3 & `corr' < 0.4
                    replace `colorint' = 5 if `corr' >= 0.4 & `corr' < 0.5
                    replace `colorint' = 6 if `corr' >= 0.5 & `corr' < 0.6
                    replace `colorint' = 7 if `corr' >= 0.6 & `corr' < 0.7
                    replace `colorint' = 8 if `corr' >= 0.7 & `corr' < 0.8
                    replace `colorint' = 9 if `corr' >= 0.8 & `corr' < 0.9
                    replace `colorint' = 10 if `corr' >= 0.9 & !missing(`corr')
                    * For negative correlations (red)
                    replace `colorint' = -1 if `corr' < 0 & `corr' >= -0.1
                    replace `colorint' = -2 if `corr' < -0.1 & `corr' >= -0.2
                    replace `colorint' = -3 if `corr' < -0.2 & `corr' >= -0.3
                    replace `colorint' = -4 if `corr' < -0.3 & `corr' >= -0.4
                    replace `colorint' = -5 if `corr' < -0.4 & `corr' >= -0.5
                    replace `colorint' = -6 if `corr' < -0.5 & `corr' >= -0.6
                    replace `colorint' = -7 if `corr' < -0.6 & `corr' >= -0.7
                    replace `colorint' = -8 if `corr' < -0.7 & `corr' >= -0.8
                    replace `colorint' = -9 if `corr' < -0.8 & `corr' >= -0.9
                    replace `colorint' = -10 if `corr' < -0.9
                }
                else {
                    * Grayscale: use absolute value
                    replace `colorint' = round(abs(`corr') * 10) if !missing(`corr')
                }
            }

            * Set default title if not specified
            local corrtitle_text = cond(`"`macval(title)'"' != "", "", `"title("Missingness Correlation Matrix")"')

            * Build color note based on colorramp
            if "`colorramp'" == "bluered" {
                local corrnote `"note("Color intensity: stronger correlation = darker. Blue=positive, Red=negative", size(vsmall))"'
            }
            else if "`colorramp'" == "redblue" {
                local corrnote `"note("Color intensity: stronger correlation = darker. Red=positive, Blue=negative", size(vsmall))"'
            }
            else {
                local corrnote `"note("Color intensity: stronger correlation = darker", size(vsmall))"'
            }

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
                local twoway_cmd `"`twoway_cmd' (scatter `rowid' `colid' if `colorint' == `i', msymbol(square) msize(`msize') mcolor(`pcol') mlcolor(none))"'
            }
            forv i = 1/10 {
                local ncol : word `i' of `neg_colors'
                local twoway_cmd `"`twoway_cmd' (scatter `rowid' `colid' if `colorint' == -`i', msymbol(square) msize(`msize') mcolor(`ncol') mlcolor(none))"'
            }

            * Add text labels if requested
            local textlayer ""
            if "`textlabels'" != "" {
                local textlabsz "vsmall"
                if `nvar' > 10 local textlabsz "tiny"
                if `nvar' > 20 local textlabsz "half_tiny"
                local textlayer `"(scatter `rowid' `colid', msymbol(none) mlabel(`corrlabel') mlabposition(0) mlabsize(`textlabsz') mlabcolor(black))"'
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
                `macval(titleopts)' `macval(subtitleopts)' ///
                legend(off) ///
                aspectratio(1) ///
                plotregion(margin(zero)) ///
                `corrnote' ///
                `schemeopts' `nameopts' `savingopts' `drawopts' `graphoptions'

            restore
            local _owned_preserved = 0
        }
    }

    } // end capture noisily
    local rc = _rc
    local _owned_restore_rc = 0
    if `_owned_preserved' {
        capture restore
        local _owned_restore_rc = _rc
        if `_owned_restore_rc' {
            di as err "datamvp: caller data rollback failed (rc `_owned_restore_rc')"
            if !`rc' local rc = `_owned_restore_rc'
        }
    }
    foreach g in S_1 S_2 S_FN S_FNDATE S_1_full ReS_Call ReS_j ReS_jv ///
        ReS_jv2 ReS_i ReS_Xij Res_Xi ReS_atwl ReS_str rVANS rtmpST {
        if `_had_`g'' mata: st_global(st_local("g"), st_local("_old_" + st_local("g")))
        else macro drop `g'
    }
    set varabbrev `_uservarabbrev'
    if `_return_ready' {
        return clear
        return scalar N = `N'
        return scalar N_complete = `ncomplete'
        return scalar N_incomplete = `nincomplete'
        return scalar N_patterns = `npatterns'
        return scalar N_vars = `nvar'
        return scalar max_miss = `maxmiss_obs'
        return scalar mean_miss = `meanmiss'
        return scalar N_mv_total = `nmvtotal'
        return scalar N_patterns_pooled = `_npooled'
        return scalar mincell = `_m'
        return scalar maskrare = ("`maskrare'" != "")
        return scalar masked = `_anymask'
        return local varlist "`varlist'"
        if "`varnomv'" != "" return local varlist_nomiss "`varnomv'"
        if `_return_has_missby' {
            return local bytable "`bytable'"
            return matrix miss_by = `MB'
        }
        if "`gby'" != "" {
            return local gby "`gby'"
            return local gby_levels "`gby_levels'"
        }
        if "`over'" != "" {
            return local over "`over'"
            return local over_levels "`over_levels'"
        }
        if `_return_has_monotone' {
            return local monotone_status "`mono_status'"
            return scalar N_monotone = `nmono'
            return scalar pct_monotone = `pctmono'
        }
        if `_return_has_corr' return matrix corr_miss = `corrmat'
    }
    if `rc' exit `rc'
end

capture mata: mata drop _datamvp_graph_text()
mata:
string scalar _datamvp_graph_text(string scalar text)
{
    real scalar nchar

    nchar = strlen(text)
    while (nchar >= 4 & substr(text, 1, 2) == char(96) + char(34) &
        substr(text, nchar - 1, 2) == char(34) + char(39)) {
        text = substr(text, 3, nchar - 4)
        nchar = strlen(text)
    }
    text = subinstr(text, char(36), "{char 36}")
    text = subinstr(text, char(96), "{char 96}")
    text = subinstr(text, char(34), "{char 34}")
    return(text)
}
end

exit

* Version 1.5.1 (08jul2026):
* - Fixed r(198) crash on variable names >=28 chars (per-variable pct local
*   keyed by name overflowed the 31-char macro-name limit; now parallel list)
* - Fixed generate() silently overwriting one indicator when two long names
*   truncated to the same stub
* - Fixed set varabbrev off leaking to the user on the no-missing-values exit
*   path (clean exit 0 inside capture bypassed the restore)
*
* Version 1.2.1 (21mar2026):
* - Fixed varabbrev unconditionally set to on (now saves/restores user setting)
* - Fixed string gby()/over() crashes in graph code (unquoted string comparison)
* - Fixed missing correlations shown as darkest positive in correlation heatmap
* - Fixed sthlp generate() abbreviation (g: -> gen:) and nodraw (nodr: -> nodraw)
* - Removed dead summ code
*
* Version 1.2.0 (19mar2026):
* - Fixed gby()/over() crash with string variables in graph(bar) (removed dead gbyval/overval)
* - Fixed matrix heatmap x-axis showing numbers instead of variable names (added value labels)
* - Fixed correlate option not displaying tetrachoric matrix (was header-only)
* - Fixed stacked option producing no visual effect (reimplemented with multi-variable segments)
* - Fixed generate() creating variable names exceeding 32-char limit
* - Fixed early exit not returning r(varlist_nomiss) when no missing values
* - Added validation: over() requires graph(bar), gby() requires graph(bar) or graph(patterns)
*
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
