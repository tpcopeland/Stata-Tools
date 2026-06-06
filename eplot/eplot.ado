*! eplot Version 1.2.0  2026/06/06
*! Unified effect plotting command for forest plots and coefficient plots
*! Author: Timothy P Copeland, Karolinska Institutet
*! Program class: rclass

/*
Unified syntax for effect visualization:

  From data in memory:
    eplot esvar lcivar ucivar [if] [in], [options]

  From stored estimates (single or multi-model):
    eplot [namelist], [options]

  From matrix:
    eplot matrix(matname), [options]

  From graph-ready frame:
    eplot, frame(framename) [options]

Recent additions:
  - Shared style/range/annotation helpers across plotting modes
  - Effect-axis xlabel() passthrough
  - gap() support for grouped layouts
  - Dynamic values-column margin sizing
  - Frame input for graph-ready tabtools output

See help eplot for complete documentation
*/

program define eplot, rclass
    version 16.0
    local _orig_varabbrev = c(varabbrev)
    set varabbrev off

    capture noisily {
        // Determine mode: data, estimates, matrix, or frame
        _eplot_parse_mode `0'
        local mode "`s(mode)'"

        if "`mode'" == "data" {
            _eplot_data `0'
        }
        else if "`mode'" == "estimates" {
            _eplot_estimates `0'
        }
        else if "`mode'" == "matrix" {
            _eplot_matrix `0'
        }
        else if "`mode'" == "frame" {
            _eplot_frame `0'
        }
        else {
            display as error "Could not determine eplot mode"
            exit 198
        }

        // Capture return values from subprogram before exiting block
        local _r_N = r(N)
        local _r_cmd `"`r(cmd)'"'
        local _r_nmodels = r(n_models)
        local _r_k = r(k)
        tempname _r_table
        capture matrix `_r_table' = r(table)
        local _has_table = (_rc == 0)
        tempname _r_pvalues
        capture matrix `_r_pvalues' = r(pvalues)
        local _has_pvalues = (_rc == 0)
    }
    local rc = _rc

    if `rc' == 0 {
        if "`mode'" == "estimates" {
            return scalar N = `_r_N'
            return scalar n_models = `_r_nmodels'
            return local cmd `"`_r_cmd'"'
        }
        else {
            return scalar N = `_r_N'
            return local cmd `"`_r_cmd'"'
        }
        return scalar k = `_r_k'
        if `_has_table' {
            return matrix table = `_r_table'
        }
        if `_has_pvalues' {
            return matrix pvalues = `_r_pvalues'
        }
    }

    set varabbrev `_orig_varabbrev'
    if `rc' exit `rc'
end

// =============================================================================
// Mode Detection
// =============================================================================

program define _eplot_parse_mode, sclass
    version 16.0
    local _orig_varabbrev = c(varabbrev)
    set varabbrev off
    capture noisily {
        syntax [anything] [if] [in] [, Matrix(name) FRame(name) *]

        // Matrix mode is explicit
        if "`matrix'" != "" {
            sreturn local mode "matrix"
            exit
        }

        // Frame mode is explicit
        if "`frame'" != "" {
            sreturn local mode "frame"
            exit
        }

        // If anything is empty, assume estimates mode with active estimates
        if `"`anything'"' == "" {
            sreturn local mode "estimates"
            exit
        }

        // Count tokens - data mode needs exactly 3 variables
        local nwords : word count `anything'

        if `nwords' >= 3 {
            // Check if first three tokens are numeric variables
            local w1 : word 1 of `anything'
            local w2 : word 2 of `anything'
            local w3 : word 3 of `anything'

            capture confirm numeric variable `w1' `w2' `w3'
            if _rc == 0 {
                sreturn local mode "data"
                exit
            }
        }

        // Check if it looks like estimate names
        if `nwords' == 1 & "`anything'" == "." {
            sreturn local mode "estimates"
            exit
        }

        // Try to see if these are stored estimates
        local is_est 1
        foreach name of local anything {
            if "`name'" == "." continue
            capture estimates dir `name'
            if _rc {
                local is_est 0
                continue, break
            }
        }

        if `is_est' {
            sreturn local mode "estimates"
            exit
        }

        // Default: try data mode
        sreturn local mode "data"
    }
    local rc = _rc
    set varabbrev `_orig_varabbrev'
    if `rc' exit `rc'
end

// =============================================================================
// Frame Mode: Plot from a graph-ready frame
// =============================================================================

capture program drop _eplot_frame
program define _eplot_frame, rclass
    version 16.0
    local _orig_varabbrev = c(varabbrev)
    local _orig_frame "`c(frame)'"
    local _frame_created 0
    set varabbrev off

    capture noisily {
        syntax [if] [in] , FRame(name) ///
            [ ///
            ESTimate(name) ///
            LL(name) ///
            UL(name) ///
            LABels(name) ///
            Type(name) ///
            ROWType(name) ///
            PValue(name) ///
            WEIghts(name) ///
            PI(string asis) ///
            * ///
            ]

        capture confirm frame `frame'
        if _rc {
            display as error "frame(`frame') not found"
            exit 111
        }

        if "`estimate'" == "" local estimate "estimate"
        if "`ll'" == "" local ll "ll"
        if "`ul'" == "" local ul "ul"

        if "`type'" != "" & "`rowtype'" != "" {
            display as error "specify only one of type() or rowtype()"
            exit 198
        }

        tempname _workframe
        frame copy `frame' `_workframe'
        local _frame_created 1
        frame change `_workframe'

        capture confirm numeric variable `estimate'
        if _rc {
            display as error "frame(`frame') must contain numeric variable `estimate'"
            exit 111
        }
        capture confirm numeric variable `ll'
        if _rc {
            display as error "frame(`frame') must contain numeric variable `ll'"
            exit 111
        }
        capture confirm numeric variable `ul'
        if _rc {
            display as error "frame(`frame') must contain numeric variable `ul'"
            exit 111
        }

        if "`labels'" == "" {
            capture confirm string variable label
            if _rc == 0 local labels "label"
        }
        else {
            capture confirm string variable `labels'
            if _rc {
                display as error "labels(`labels') must name a string variable in frame(`frame')"
                exit 111
            }
        }

        if "`rowtype'" != "" {
            local type "`rowtype'"
        }
        else if "`type'" == "" {
            capture confirm variable rowtype
            if _rc == 0 local type "rowtype"
            else {
                capture confirm variable type
                if _rc == 0 local type "type"
            }
        }
        if "`type'" != "" {
            capture confirm variable `type'
            if _rc {
                display as error "type(`type') must name a variable in frame(`frame')"
                exit 111
            }
        }

        if "`weights'" == "" {
            capture confirm numeric variable weight
            if _rc == 0 local weights "weight"
            else {
                capture confirm numeric variable weights
                if _rc == 0 local weights "weights"
            }
        }
        else {
            capture confirm numeric variable `weights'
            if _rc {
                display as error "weights(`weights') must name a numeric variable in frame(`frame')"
                exit 111
            }
        }

        if "`pvalue'" == "" {
            capture confirm numeric variable pvalue
            if _rc == 0 local pvalue "pvalue"
        }
        else {
            capture confirm numeric variable `pvalue'
            if _rc {
                display as error "pvalue(`pvalue') must name a numeric variable in frame(`frame')"
                exit 111
            }
        }

        local _data_opts `"`options'"'
        if "`labels'" != "" {
            local _data_opts `"labels(`labels') `_data_opts'"'
        }
        if "`type'" != "" {
            local _data_opts `"type(`type') `_data_opts'"'
        }
        if "`weights'" != "" {
            local _data_opts `"weights(`weights') `_data_opts'"'
        }
        if "`pvalue'" != "" {
            local _data_opts `"pvalue(`pvalue') `_data_opts'"'
        }
        if `"`pi'"' != "" {
            local _data_opts `"pi(`pi') `_data_opts'"'
        }

        _eplot_data `estimate' `ll' `ul' `if' `in', `_data_opts'

        local _r_N = r(N)
        local _r_k = r(k)
        local _r_cmd `"`r(cmd)'"'
        tempname _r_table
        capture matrix `_r_table' = r(table)
        local _has_table = (_rc == 0)
        tempname _r_pvalues
        capture matrix `_r_pvalues' = r(pvalues)
        local _has_pvalues = (_rc == 0)
    }
    local rc = _rc

    capture frame change `_orig_frame'
    if `_frame_created' {
        capture frame drop `_workframe'
    }

    if `rc' == 0 {
        return scalar N = `_r_N'
        return scalar k = `_r_k'
        return local cmd `"`_r_cmd'"'
        if `_has_table' {
            return matrix table = `_r_table'
        }
        if `_has_pvalues' {
            return matrix pvalues = `_r_pvalues'
        }
    }

    set varabbrev `_orig_varabbrev'
    if `rc' exit `rc'
end

// =============================================================================
// Data Mode: Plot from variables in memory
// =============================================================================

program define _eplot_data, rclass
    version 16.0
    local _orig_varabbrev = c(varabbrev)
    set varabbrev off
    capture noisily {
        syntax varlist(numeric min=3 max=3) [if] [in] , ///
            [ ///
            /// Data options
            LABels(varname string) ///
            WEIghts(varname numeric) ///
            Type(varname) ///
            /// Coefficient selection
            KEEP(string asis) ///
            DROP(string asis) ///
            /// Labeling
            COEFLabels(string asis) ///
            GRoups(string asis) ///
            HEADers(string asis) ///
            HEADings(string asis) ///
            GAP(real 0) ///
            /// Transform
            EFORM ///
            REScale(real 1) ///
            /// Reference lines
            XLine(numlist) ///
            XLABel(string asis) ///
            NULL(real -999) ///
            NONULL ///
            /// Confidence intervals
            NOCI ///
            CICap ///
            /// Display
            DP(integer 2) ///
            EFFect(string) ///
            VALues ///
            VFormat(string) ///
            STARs ///
            PValue(varname numeric) ///
            SIGColors ///
            SIGColor(string) ///
            INSIGColor(string) ///
            /// Layout
            HORizontal ///
            VERTical ///
            SORT ///
            ORDer(string asis) ///
            /// Prediction intervals
            PI(varlist numeric min=2 max=2) ///
            /// Favors annotation
            Favors(string asis) ///
            /// Heterogeneity stats
            I2(string) ///
            TAU2(string) ///
            Qstat(string) ///
            /// Style presets
            STYle(string) ///
            /// Box/marker options
            BOXScale(real 100) ///
            NOBOX ///
            NODIamonds ///
            MColor(string) ///
            MSymbol(string) ///
            MSize(string) ///
            CIColor(string) ///
            CIWidth(string) ///
            /// Graph options
            TItle(string asis) ///
            SUBtitle(string asis) ///
            NOTE(string asis) ///
            NAME(string) ///
            SAVing(string asis) ///
            SCHEME(string) ///
            PLOTRegion(string asis) ///
            GRAPHRegion(string asis) ///
            ASPect(string) ///
            NOCONStant ///
            * ///
            ]

        // nocons -> add _cons to drop list
        if "`noconstant'" != "" {
            local drop `"`drop' _cons"'
        }

        // ====== Style presets (apply BEFORE user overrides) ======
        if "`style'" != "" {
            _eplot_apply_style, style(`"`style'"')
            if "`values'" == "" local values "`s(values)'"
            if "`mcolor'" == "" local mcolor "`s(mcolor)'"
            if "`cicolor'" == "" local cicolor "`s(cicolor)'"
            if "`cicap'" == "" local cicap "`s(cicap)'"
            if "`msymbol'" == "" local msymbol "`s(msymbol)'"
            if "`msize'" == "" local msize "`s(msize)'"
        }

    // Parse varlist
    tokenize `varlist'
    local es_var `1'
    local lci_var `2'
    local uci_var `3'

    // Mark sample: capture if/in first, then exclude missing values
    marksample touse, novarlist
    tempvar ifin_ok
    quietly gen byte `ifin_ok' = `touse'
    markout `touse' `es_var' `lci_var' `uci_var'

    // Restore non-data rows (headers, blanks, etc.) ONLY within the if/in range
    if "`type'" != "" {
        capture confirm numeric variable `type'
        if _rc == 0 {
            quietly replace `touse' = 1 if inlist(`type', 0, 2, 4, 6) & `ifin_ok'
        }
        else {
            quietly replace `touse' = 1 ///
                if inlist(lower(strtrim(`type')), "header", "section", "missing", "reference", "hetinfo", "blank") & `ifin_ok'
        }
    }

    quietly count if `touse'
    if r(N) == 0 {
        display as error "no observations"
        exit 2000
    }
    local N = r(N)

    // Set defaults
    if "`horizontal'" == "" & "`vertical'" == "" {
        local horizontal "horizontal"
    }
    if `"`headings'"' != "" & `"`headers'"' == "" {
        local headers `"`headings'"'
    }
    if `null' == -999 {
        local null = cond("`eform'" != "", 1, 0)
    }
    if `"`effect'"' == "" {
        if "`eform'" != "" {
            local effect "Effect (95% CI)"
        }
        else {
            local effect "Estimate (95% CI)"
        }
    }
    if "`vformat'" == "" local vformat "%5.`dp'f"

    // Color defaults
    if "`mcolor'" == "" local mcolor "navy"
    if "`cicolor'" == "" local cicolor "`mcolor'"
    if "`ciwidth'" == "" local ciwidth "medium"
    if "`msymbol'" == "" local msymbol "O"
    if "`msize'" == "" local msize "medium"

    // Preserve and work on data
    preserve

    quietly keep if `touse'

    // Create working variables
    tempvar id pos es lci uci wt rowtype label_str gapflag rowspace

    // Generate row ID
    quietly gen long `id' = _n

    // Copy effect size data
    quietly gen double `es' = `es_var'
    quietly gen double `lci' = `lci_var'
    quietly gen double `uci' = `uci_var'

    // Apply eform transformation
    if "`eform'" != "" {
        quietly replace `es' = exp(`es')
        quietly replace `lci' = exp(`lci')
        quietly replace `uci' = exp(`uci')
    }

    // Apply rescale
    if `rescale' != 1 {
        quietly replace `es' = `es' * `rescale'
        quietly replace `lci' = `lci' * `rescale'
        quietly replace `uci' = `uci' * `rescale'
    }

    // Weights
    if "`weights'" != "" {
        quietly gen double `wt' = `weights'
    }
    else {
        quietly gen double `wt' = 1
    }

    // Row type
    if "`type'" != "" {
        capture confirm numeric variable `type'
        if _rc == 0 {
            quietly gen int `rowtype' = `type'
        }
        else {
            quietly gen int `rowtype' = 1
            quietly replace `rowtype' = 0 if inlist(lower(strtrim(`type')), "header", "section")
            quietly replace `rowtype' = 2 if inlist(lower(strtrim(`type')), "missing", "reference")
            quietly replace `rowtype' = 3 if lower(strtrim(`type')) == "subgroup"
            quietly replace `rowtype' = 4 if lower(strtrim(`type')) == "hetinfo"
            quietly replace `rowtype' = 5 if lower(strtrim(`type')) == "overall"
            quietly replace `rowtype' = 6 if lower(strtrim(`type')) == "blank"
        }
    }
    else {
        quietly gen int `rowtype' = 1
    }
    quietly gen byte `gapflag' = 0

    // Labels
    if "`labels'" != "" {
        quietly gen str244 `label_str' = `labels'
    }
    else {
        quietly gen str244 `label_str' = "Row " + string(`id')
    }

    // Apply custom coefficient labels
    if `"`coeflabels'"' != "" {
        _eplot_apply_coeflabels `label_str', coeflabels(`coeflabels')
    }

    // Sort by effect size if requested
    if "`sort'" != "" {
        // Only sort effect rows, keep headers/overall in place
        tempvar sort_val
        quietly gen double `sort_val' = `es' if `rowtype' == 1
        sort `sort_val' `id'
    }
    else if `"`order'"' != "" {
        // Apply explicit ordering
        tempvar order_rank
        quietly gen long `order_rank' = .
        local o 0
        local _unmatched ""
        foreach coef of local order {
            local `++o'
            quietly count if `label_str' == `"`coef'"'
            if r(N) == 0 {
                local _unmatched "`_unmatched' `coef'"
            }
            quietly replace `order_rank' = `o' if `label_str' == `"`coef'"'
        }
        if "`_unmatched'" != "" {
            display as text "(note: order() did not match:`_unmatched')"
        }
        quietly replace `order_rank' = 1000 + `id' if missing(`order_rank')
        sort `order_rank'
    }

    // Calculate positions (yscale(reverse) puts low values at top)
    quietly gen double `pos' = _n

    // Process groups - insert headers and adjust positions
    local n_groups 0
    if `"`groups'"' != "" {
        _eplot_process_groups `pos' `label_str' `rowtype' `gapflag', ///
            groups(`groups') gap(`gap')
        local n_groups = r(n_groups)
    }

    // Process headers
    if `"`headers'"' != "" {
        _eplot_process_headers `pos' `label_str' `rowtype', headers(`headers')
    }

    // Recalculate positions after any insertions
    sort `pos'
    quietly gen double `rowspace' = 1
    quietly replace `rowspace' = `gap' if `gapflag' == 1
    quietly replace `pos' = sum(`rowspace')

    // Update N to include any added header rows
    local N = _N

    // Significance coloring flag (data mode)
    tempvar _dm_sig
    tempvar _dm_star
    if "`sigcolors'" != "" {
        if "`sigcolor'" == "" local sigcolor "cranberry"
        if "`insigncolor'" == "" local insigncolor "gs10"
        quietly gen byte `_dm_sig' = 0 if `rowtype' == 1
        quietly replace `_dm_sig' = 1 if `rowtype' == 1 & ///
            ((`lci' > `null' & !missing(`lci')) | (`uci' < `null' & !missing(`uci')))
    }
    else {
        quietly gen byte `_dm_sig' = .
    }
    if "`stars'" != "" {
        if "`pvalue'" == "" {
            display as text "(note: stars requires pvalue() in data/frame mode)"
        }
        quietly gen str3 `_dm_star' = "" if inlist(`rowtype', 1, 3, 5)
        if "`pvalue'" != "" {
            quietly replace `_dm_star' = "*" ///
                if inlist(`rowtype', 1, 3, 5) & `pvalue' < 0.05 & !missing(`pvalue')
            quietly replace `_dm_star' = "**" ///
                if inlist(`rowtype', 1, 3, 5) & `pvalue' < 0.01 & !missing(`pvalue')
            quietly replace `_dm_star' = "***" ///
                if inlist(`rowtype', 1, 3, 5) & `pvalue' < 0.001 & !missing(`pvalue')
        }
    }
    else {
        quietly gen str3 `_dm_star' = ""
    }


    // Prediction intervals (data mode)
    tempvar pi_lci pi_uci
    if "`pi'" != "" {
        tokenize `pi'
        quietly gen double `pi_lci' = `1'
        quietly gen double `pi_uci' = `2'
        if "`eform'" != "" {
            quietly replace `pi_lci' = exp(`pi_lci')
            quietly replace `pi_uci' = exp(`pi_uci')
        }
        if `rescale' != 1 {
            quietly replace `pi_lci' = `pi_lci' * `rescale'
            quietly replace `pi_uci' = `pi_uci' * `rescale'
        }
}
    else {
        quietly gen double `pi_lci' = .
        quietly gen double `pi_uci' = .
    }

    // Determine plot range and effect-axis ticks
    _eplot_calc_range `lci' `uci' if inlist(`rowtype', 1, 3, 5), ///
        extralow(`pi_lci') extrahigh(`pi_uci')
    local xmin = `s(min)'
    local xmax = `s(max)'
    local xrange = `s(range)'
    local xmin_pad = `s(min_pad)'
    local xmax_pad = `s(max_pad)'

    if `"`xlabel'"' != "" {
        _eplot_effect_axis_labels, min(`xmin') max(`xmax') xlabel(`xlabel')
    }
    else {
        _eplot_effect_axis_labels, min(`xmin') max(`xmax')
    }
    local _effect_axis_opts `"`s(axisopts)'"'

    // --- Values annotation ---
    local val_cmd ""
    if "`values'" != "" & "`horizontal'" == "" {
        display as text "(note: values annotation requires horizontal layout)"
    }
    if "`values'" != "" & "`horizontal'" != "" {
        tempvar val_text val_x
        quietly gen str `val_text' = string(`es', "`vformat'") ///
            + " (" + string(`lci', "`vformat'") ///
            + ", " + string(`uci', "`vformat'") + ")" + `_dm_star' ///
            if inlist(`rowtype', 1, 3, 5) & !missing(`es')

        local val_xpos = `xmax' + 0.15 * `xrange'
        quietly gen double `val_x' = `val_xpos' if !missing(`val_text')
        _eplot_value_margin `val_text', header(`"`effect'"')
        local _val_right_margin = `s(right_margin)'

        local val_cmd `"(scatter `pos' `val_x' if !missing(`val_text'), msymbol(none) mlabel(`val_text') mlabpos(3) mlabgap(0) mlabsize(vsmall) mlabcolor(gs4))"'
    }

    // --- Build graph command ---
    local graphcmd "twoway"

    // --- Prediction interval spikes (wider, dashed, behind CIs) ---
    if "`pi'" != "" {
        quietly count if inlist(`rowtype', 1, 3, 5) & !missing(`pi_lci')
        if r(N) > 0 {
            if "`horizontal'" != "" {
                local graphcmd `"`graphcmd' (rspike `pi_lci' `pi_uci' `pos' if inlist(`rowtype', 1, 3, 5) & !missing(`pi_lci'), horizontal lcolor(gs8) lwidth(thin) lpattern(dash))"'
            }
            else {
                local graphcmd `"`graphcmd' (rspike `pi_lci' `pi_uci' `pos' if inlist(`rowtype', 1, 3, 5) & !missing(`pi_lci'), lcolor(gs8) lwidth(thin) lpattern(dash))"'
            }
        }
    }

    // --- Confidence interval spikes for regular effects ---
    local _ci_type = cond("`cicap'" != "", "rcap", "rspike")
    quietly count if `rowtype' == 1 & !missing(`es')
    if r(N) > 0 & "`noci'" == "" {
        if "`sigcolors'" != "" {
            if "`horizontal'" != "" {
                local graphcmd `"`graphcmd' (`_ci_type' `lci' `uci' `pos' if `rowtype' == 1 & `_dm_sig' == 1, horizontal lcolor(`sigcolor') lwidth(`ciwidth'))"'
                local graphcmd `"`graphcmd' (`_ci_type' `lci' `uci' `pos' if `rowtype' == 1 & `_dm_sig' == 0, horizontal lcolor(`insigncolor') lwidth(`ciwidth'))"'
            }
            else {
                local graphcmd `"`graphcmd' (`_ci_type' `lci' `uci' `pos' if `rowtype' == 1 & `_dm_sig' == 1, lcolor(`sigcolor') lwidth(`ciwidth'))"'
                local graphcmd `"`graphcmd' (`_ci_type' `lci' `uci' `pos' if `rowtype' == 1 & `_dm_sig' == 0, lcolor(`insigncolor') lwidth(`ciwidth'))"'
            }
        }
        else {
            if "`horizontal'" != "" {
                local graphcmd `"`graphcmd' (`_ci_type' `lci' `uci' `pos' if `rowtype' == 1, horizontal lcolor(`cicolor') lwidth(`ciwidth'))"'
            }
            else {
                local graphcmd `"`graphcmd' (`_ci_type' `lci' `uci' `pos' if `rowtype' == 1, lcolor(`cicolor') lwidth(`ciwidth'))"'
            }
        }
    }

    // --- Markers for regular effects ---
    quietly count if `rowtype' == 1 & !missing(`es')
    if r(N) > 0 {
        if "`sigcolors'" != "" {
            if "`nobox'" == "" & "`weights'" != "" {
                local bscale = `boxscale' / 100
                if "`horizontal'" != "" {
                    local graphcmd `"`graphcmd' (scatter `pos' `es' if `rowtype' == 1 & `_dm_sig' == 1 [aw=`wt'], msymbol(square) mcolor(`sigcolor') msize(*`bscale'))"'
                    local graphcmd `"`graphcmd' (scatter `pos' `es' if `rowtype' == 1 & `_dm_sig' == 0 [aw=`wt'], msymbol(square) mcolor(`insigncolor') msize(*`bscale'))"'
                }
                else {
                    local graphcmd `"`graphcmd' (scatter `es' `pos' if `rowtype' == 1 & `_dm_sig' == 1 [aw=`wt'], msymbol(square) mcolor(`sigcolor') msize(*`bscale'))"'
                    local graphcmd `"`graphcmd' (scatter `es' `pos' if `rowtype' == 1 & `_dm_sig' == 0 [aw=`wt'], msymbol(square) mcolor(`insigncolor') msize(*`bscale'))"'
                }
            }
            else {
                if "`horizontal'" != "" {
                    local graphcmd `"`graphcmd' (scatter `pos' `es' if `rowtype' == 1 & `_dm_sig' == 1, msymbol(`msymbol') mcolor(`sigcolor') msize(`msize'))"'
                    local graphcmd `"`graphcmd' (scatter `pos' `es' if `rowtype' == 1 & `_dm_sig' == 0, msymbol(`msymbol') mcolor(`insigncolor') msize(`msize'))"'
                }
                else {
                    local graphcmd `"`graphcmd' (scatter `es' `pos' if `rowtype' == 1 & `_dm_sig' == 1, msymbol(`msymbol') mcolor(`sigcolor') msize(`msize'))"'
                    local graphcmd `"`graphcmd' (scatter `es' `pos' if `rowtype' == 1 & `_dm_sig' == 0, msymbol(`msymbol') mcolor(`insigncolor') msize(`msize'))"'
                }
            }
        }
        else {
            if "`nobox'" == "" & "`weights'" != "" {
                local bscale = `boxscale' / 100
                if "`horizontal'" != "" {
                    local graphcmd `"`graphcmd' (scatter `pos' `es' if `rowtype' == 1 [aw=`wt'], msymbol(square) mcolor(`mcolor') msize(*`bscale'))"'
                }
                else {
                    local graphcmd `"`graphcmd' (scatter `es' `pos' if `rowtype' == 1 [aw=`wt'], msymbol(square) mcolor(`mcolor') msize(*`bscale'))"'
                }
            }
            else {
                if "`horizontal'" != "" {
                    local graphcmd `"`graphcmd' (scatter `pos' `es' if `rowtype' == 1, msymbol(`msymbol') mcolor(`mcolor') msize(`msize'))"'
                }
                else {
                    local graphcmd `"`graphcmd' (scatter `es' `pos' if `rowtype' == 1, msymbol(`msymbol') mcolor(`mcolor') msize(`msize'))"'
                }
            }
        }
    }

    // --- Diamonds for pooled effects (subgroup and overall) ---
    local diamond_cmd ""
    if "`nodiamonds'" == "" {
        quietly count if inlist(`rowtype', 3, 5) & !missing(`es')
        if r(N) > 0 {
            local diam_height = 0.3

            tempvar diam_ly2 diam_ly3
            quietly {
                gen double `diam_ly2' = `pos' + `diam_height' if inlist(`rowtype', 3, 5)
                gen double `diam_ly3' = `pos' - `diam_height' if inlist(`rowtype', 3, 5)
            }

            if "`horizontal'" != "" {
                // Overall diamond (black)
                local diamond_cmd `"`diamond_cmd' (pcspike `pos' `lci' `diam_ly2' `es' if `rowtype' == 5, lcolor(black) lwidth(medthick))"'
                local diamond_cmd `"`diamond_cmd' (pcspike `diam_ly2' `es' `pos' `uci' if `rowtype' == 5, lcolor(black) lwidth(medthick))"'
                local diamond_cmd `"`diamond_cmd' (pcspike `pos' `uci' `diam_ly3' `es' if `rowtype' == 5, lcolor(black) lwidth(medthick))"'
                local diamond_cmd `"`diamond_cmd' (pcspike `diam_ly3' `es' `pos' `lci' if `rowtype' == 5, lcolor(black) lwidth(medthick))"'

                // Subgroup diamond (maroon)
                local diamond_cmd `"`diamond_cmd' (pcspike `pos' `lci' `diam_ly2' `es' if `rowtype' == 3, lcolor(maroon) lwidth(medthick))"'
                local diamond_cmd `"`diamond_cmd' (pcspike `diam_ly2' `es' `pos' `uci' if `rowtype' == 3, lcolor(maroon) lwidth(medthick))"'
                local diamond_cmd `"`diamond_cmd' (pcspike `pos' `uci' `diam_ly3' `es' if `rowtype' == 3, lcolor(maroon) lwidth(medthick))"'
                local diamond_cmd `"`diamond_cmd' (pcspike `diam_ly3' `es' `pos' `lci' if `rowtype' == 3, lcolor(maroon) lwidth(medthick))"'
            }
            else {
                // Overall diamond (black) - vertical
                local diamond_cmd `"`diamond_cmd' (pcspike `lci' `pos' `es' `diam_ly2' if `rowtype' == 5, lcolor(black) lwidth(medthick))"'
                local diamond_cmd `"`diamond_cmd' (pcspike `es' `diam_ly2' `uci' `pos' if `rowtype' == 5, lcolor(black) lwidth(medthick))"'
                local diamond_cmd `"`diamond_cmd' (pcspike `uci' `pos' `es' `diam_ly3' if `rowtype' == 5, lcolor(black) lwidth(medthick))"'
                local diamond_cmd `"`diamond_cmd' (pcspike `es' `diam_ly3' `lci' `pos' if `rowtype' == 5, lcolor(black) lwidth(medthick))"'

                // Subgroup diamond (maroon)
                local diamond_cmd `"`diamond_cmd' (pcspike `lci' `pos' `es' `diam_ly2' if `rowtype' == 3, lcolor(maroon) lwidth(medthick))"'
                local diamond_cmd `"`diamond_cmd' (pcspike `es' `diam_ly2' `uci' `pos' if `rowtype' == 3, lcolor(maroon) lwidth(medthick))"'
                local diamond_cmd `"`diamond_cmd' (pcspike `uci' `pos' `es' `diam_ly3' if `rowtype' == 3, lcolor(maroon) lwidth(medthick))"'
                local diamond_cmd `"`diamond_cmd' (pcspike `es' `diam_ly3' `lci' `pos' if `rowtype' == 3, lcolor(maroon) lwidth(medthick))"'
            }
        }
    }
    else {
        // nodiamonds: draw markers and CIs for pooled effects instead
        quietly count if inlist(`rowtype', 3, 5) & !missing(`es')
        if r(N) > 0 {
            if "`noci'" == "" {
                if "`horizontal'" != "" {
                    if "`cicap'" != "" {
                        local diamond_cmd `"`diamond_cmd' (rcap `lci' `uci' `pos' if inlist(`rowtype', 3, 5), horizontal lcolor(`cicolor') lwidth(`ciwidth'))"'
                    }
                    else {
                        local diamond_cmd `"`diamond_cmd' (rspike `lci' `uci' `pos' if inlist(`rowtype', 3, 5), horizontal lcolor(`cicolor') lwidth(`ciwidth'))"'
                    }
                }
                else {
                    if "`cicap'" != "" {
                        local diamond_cmd `"`diamond_cmd' (rcap `lci' `uci' `pos' if inlist(`rowtype', 3, 5), lcolor(`cicolor') lwidth(`ciwidth'))"'
                    }
                    else {
                        local diamond_cmd `"`diamond_cmd' (rspike `lci' `uci' `pos' if inlist(`rowtype', 3, 5), lcolor(`cicolor') lwidth(`ciwidth'))"'
                    }
                }
            }
            if "`horizontal'" != "" {
                local diamond_cmd `"`diamond_cmd' (scatter `pos' `es' if inlist(`rowtype', 3, 5), msymbol(`msymbol') mcolor(`mcolor') msize(`msize'))"'
            }
            else {
                local diamond_cmd `"`diamond_cmd' (scatter `es' `pos' if inlist(`rowtype', 3, 5), msymbol(`msymbol') mcolor(`mcolor') msize(`msize'))"'
            }
        }
    }

    // Add diamonds to graph command
    if "`diamond_cmd'" != "" {
        local graphcmd `"`graphcmd' `diamond_cmd'"'
    }

    // Add values annotation
    if "`val_cmd'" != "" {
        local graphcmd `"`graphcmd' `val_cmd'"'
    }

    local _xline_opt ""
    if "`xline'" != "" local _xline_opt `"xline(`xline')"'
    _eplot_build_reflines, null(`null') `_xline_opt' ///
        `horizontal' `nonull'
    local refline_cmd `"`s(cmd)'"'

    // --- Y-axis labels (row labels) ---
    local ylabels ""
    forvalues i = 1/`=_N' {
        local this_pos = `pos'[`i']
        local this_label = `label_str'[`i']
        local this_type = `rowtype'[`i']

        if `this_type' == 6 continue

        // Bold for headers and overall
        if inlist(`this_type', 0, 5) {
            local this_label `"{bf:`this_label'}"'
        }

        local ylabels `"`ylabels' `this_pos' `"`this_label'"'"'
    }
    quietly summarize `pos', meanonly
    local pos_max = r(max)

    // --- Graph options ---
    local ypad_lo 0
    local ypad_hi = `pos_max' + 1
    local _xscale_max = `xmax_pad'
    if "`horizontal'" != "" {
        if "`values'" != "" {
            local _xscale_max = `val_xpos'
        }
        local graphcmd `"`graphcmd', ylabel(`ylabels', angle(0) labsize(small) nogrid valuelabel)"'
        local graphcmd `"`graphcmd' ytitle("")"'
        local graphcmd `"`graphcmd' xscale(range(`xmin_pad' `_xscale_max'))"'
        if "`values'" != "" {
            local _val_hdr_y = 0.3
            local ypad_lo = -0.2
            local graphcmd `"`graphcmd' xtitle(`"`effect'"', size(medsmall))"'
            local graphcmd `"`graphcmd' text(`_val_hdr_y' `val_xpos' `"{bf:`effect'}"', size(vsmall) placement(e) justification(left))"'
        }
        else local graphcmd `"`graphcmd' xtitle(`"`effect'"')"'
        local graphcmd `"`graphcmd' xlabel(`_effect_axis_opts')"'
        if `"`favors'"' != "" {
            local ypad_hi = `pos_max' + 2
        }
        local graphcmd `"`graphcmd' yscale(reverse range(`ypad_lo' `ypad_hi'))"'
    }
    else {
        local graphcmd `"`graphcmd', xlabel(`ylabels', angle(45) labsize(small) nogrid valuelabel)"'
        local graphcmd `"`graphcmd' xscale(range(`ypad_lo' `ypad_hi'))"'
        local graphcmd `"`graphcmd' xtitle("")"'
        local graphcmd `"`graphcmd' ytitle(`"`effect'"')"'
        local graphcmd `"`graphcmd' yscale(range(`xmin_pad' `xmax_pad'))"'
        local graphcmd `"`graphcmd' ylabel(`_effect_axis_opts')"'
    }

    // Reference lines
    if "`refline_cmd'" != "" {
        local graphcmd `"`graphcmd' `refline_cmd'"'
    }

    // Legend
    local graphcmd `"`graphcmd' legend(off)"'

    // Titles
    if `"`title'"' != "" {
        local graphcmd `"`graphcmd' title(`title')"'
    }
    if `"`subtitle'"' != "" {
        local graphcmd `"`graphcmd' subtitle(`subtitle')"'
    }
    // Build heterogeneity stats string (plain text for graph note)
    local _het_text ""
    if `"`i2'"' != "" {
        local _het_text "I-squared = `i2'%"
    }
    if `"`tau2'"' != "" {
        if `"`_het_text'"' != "" local _het_text "`_het_text', "
        local _het_text "`_het_text'tau-squared = `tau2'"
    }
    if `"`qstat'"' != "" {
        if `"`_het_text'"' != "" local _het_text "`_het_text', "
        local _het_text "`_het_text'Q = `qstat'"
    }

    if `"`note'"' != "" {
        local graphcmd `"`graphcmd' note(`note')"'
    }
    else {
        local _autonote ""
        if "`nodiamonds'" == "" & "`diamond_cmd'" != "" {
            local _autonote "Diamonds represent pooled estimates."
            if "`weights'" != "" & "`nobox'" == "" {
                local _autonote "`_autonote' Boxes proportional to study weight."
            }
        }
        if "`_het_text'" != "" {
            if "`_autonote'" != "" {
                local _autonote "`_autonote' `_het_text'"
            }
            else {
                local _autonote "`_het_text'"
            }
        }
        if "`_autonote'" != "" {
            local graphcmd `"`graphcmd' note("`_autonote'", size(vsmall) position(5))"'
        }
    }

    // Scheme
    if "`scheme'" != "" {
        local graphcmd `"`graphcmd' scheme(`scheme')"'
    }

    // Plotregion / graphregion
    local _plotregion_use `"`plotregion'"'
    if `"`_plotregion_use'"' == "" & "`horizontal'" != "" & "`values'" != "" {
        local _plotregion_use "margin(l+2 r+`_val_right_margin' t+2 b+2)"
    }
    if `"`_plotregion_use'"' != "" {
        local graphcmd `"`graphcmd' plotregion(`_plotregion_use')"'
    }
    if `"`graphregion'"' != "" {
        local graphcmd `"`graphcmd' graphregion(`graphregion')"'
    }

    // Aspect
    if "`aspect'" != "" {
        local graphcmd `"`graphcmd' aspect(`aspect')"'
    }

    // Name and saving
    if "`name'" != "" {
        local graphcmd `"`graphcmd' name(`name')"'
    }
    if `"`saving'"' != "" {
        local graphcmd `"`graphcmd' saving(`saving')"'
    }

    // Additional options
    if `"`options'"' != "" {
        local graphcmd `"`graphcmd' `options'"'
    }

    // Favors annotation (horizontal mode only)
    if `"`favors'"' != "" & "`horizontal'" != "" {
        local _fav_top = `pos_max' + 1.5
        _eplot_build_favors, favors(`favors') null(`null') ///
            min(`xmin') max(`xmax') top(`_fav_top')
        local graphcmd `"`graphcmd' `s(cmd)'"'
    }

    // Execute graph
    `graphcmd'

    // Return results
    // Build r(table) matrix from plotted data
    quietly count if inlist(`rowtype', 1, 3, 5) & !missing(`es')
    local _ntab = r(N)
    if `_ntab' > 0 {
        tempname _rtable
        matrix `_rtable' = J(`_ntab', 3, .)
        matrix colnames `_rtable' = "b" "ll" "ul"
        local _ri 0
        local _rnames ""
        forvalues i = 1/`=_N' {
            if !inlist(`rowtype'[`i'], 1, 3, 5) continue
            if missing(`es'[`i']) continue
            local `++_ri'
            matrix `_rtable'[`_ri', 1] = `es'[`i']
            matrix `_rtable'[`_ri', 2] = `lci'[`i']
            matrix `_rtable'[`_ri', 3] = `uci'[`i']
            local _rnm = `label_str'[`i']
            local _rnames `"`_rnames' `"`_rnm'"'"'
        }
        matrix rownames `_rtable' = `_rnames'
        return matrix table = `_rtable'
    }
    if "`pvalue'" != "" {
        quietly count if inlist(`rowtype', 1, 3, 5) & !missing(`es')
        local _npv = r(N)
        if `_npv' > 0 {
            tempname _rpvals
            matrix `_rpvals' = J(`_npv', 1, .)
            matrix colnames `_rpvals' = "pvalue"
            local _pi 0
            local _pnames ""
            forvalues i = 1/`=_N' {
                if !inlist(`rowtype'[`i'], 1, 3, 5) continue
                if missing(`es'[`i']) continue
                local `++_pi'
                matrix `_rpvals'[`_pi', 1] = `pvalue'[`i']
                local _pnm = `label_str'[`i']
                local _pnames `"`_pnames' `"`_pnm'"'"'
            }
            matrix rownames `_rpvals' = `_pnames'
            return matrix pvalues = `_rpvals'
        }
    }

        return scalar N = `N'
        quietly count if `rowtype' == 1
        return scalar k = r(N)
        return local cmd `"`graphcmd'"'

        restore
    }
    local rc = _rc
    set varabbrev `_orig_varabbrev'
    if `rc' exit `rc'
end

// =============================================================================
// Estimates Mode: Plot from stored estimates (single or multi-model)
// =============================================================================

program define _eplot_estimates, rclass
    version 16.0
    local _orig_varabbrev = c(varabbrev)
    set varabbrev off
    capture noisily {
        syntax [anything] [, ///
            /// Coefficient selection
            KEEP(string asis) ///
            DROP(string asis) ///
            REName(string asis) ///
            /// Labeling
            COEFLabels(string asis) ///
            GRoups(string asis) ///
            HEADers(string asis) ///
            HEADings(string asis) ///
            GAP(real 0) ///
            /// Transform
            EFORM ///
            REScale(real 1) ///
            /// Reference lines
            XLine(numlist) ///
            XLABel(string asis) ///
            NULL(real -999) ///
            NONULL ///
            /// Confidence intervals
            LEVel(cilevel) ///
            NOCI ///
            CICap ///
            /// Display
            DP(integer 2) ///
            EFFect(string) ///
            VALues ///
            VFormat(string) ///
            STARs ///
            SIGColors ///
            SIGColor(string) ///
            INSIGColor(string) ///
            /// Favors annotation
            Favors(string asis) ///
            /// Style presets
            STYle(string) ///
            /// Layout
            HORizontal ///
            VERTical ///
            SORT ///
            ORDer(string asis) ///
            /// Multi-model
            MODELLabels(string asis) ///
            OFFset(real 0.15) ///
            PALette(string) ///
            LEGendopts(string asis) ///
            /// Marker options
            MColor(string) ///
            MSymbol(string) ///
            MSize(string) ///
            CIColor(string) ///
            CIWidth(string) ///
            /// Graph options
            TItle(string asis) ///
            SUBtitle(string asis) ///
            NOTE(string asis) ///
            NAME(string) ///
            SAVing(string asis) ///
            SCHEME(string) ///
            PLOTRegion(string asis) ///
            GRAPHRegion(string asis) ///
            ASPect(string) ///
            NOCONStant ///
            * ///
            ]

        // nocons -> add _cons to drop list
        if "`noconstant'" != "" {
            local drop `"`drop' _cons"'
        }

        // eform -> auto-suppress constant (exp(_cons) is not meaningful)
        if "`eform'" != "" & "`noconstant'" == "" {
            // Only add if not already in drop list
            local _has_cons 0
            foreach _d of local drop {
                if "`_d'" == "_cons" local _has_cons 1
            }
            if !`_has_cons' {
                local drop `"`drop' _cons"'
                display as text "(note: constant suppressed with eform)"
            }
        }

        // ====== Style presets (apply BEFORE user overrides) ======
        if "`style'" != "" {
            _eplot_apply_style, style(`"`style'"')
            if "`values'" == "" local values "`s(values)'"
            if "`mcolor'" == "" local mcolor "`s(mcolor)'"
            if "`cicolor'" == "" local cicolor "`s(cicolor)'"
            if "`cicap'" == "" local cicap "`s(cicap)'"
            if "`msymbol'" == "" local msymbol "`s(msymbol)'"
            if "`msize'" == "" local msize "`s(msize)'"
        }

    // ====== Parse estimate list ======
    if `"`anything'"' == "" | `"`anything'"' == "." {
        local estlist "."
    }
    else {
        local estlist `"`anything'"'
    }
    local n_models : word count `estlist'

    // ====== Set defaults ======
    if "`horizontal'" == "" & "`vertical'" == "" {
        local horizontal "horizontal"
    }
    if `"`headings'"' != "" & `"`headers'"' == "" {
        local headers `"`headings'"'
    }
    if "`level'" == "" {
        local level = c(level)
    }
    if `null' == -999 {
        local null = cond("`eform'" != "", 1, 0)
    }
    if `"`effect'"' == "" {
        if "`eform'" != "" {
            // Auto-detect effect label from estimation command
            local _ecmd "`e(cmd)'"
            if inlist("`_ecmd'", "logit", "logistic", "melogit", "xtlogit", "clogit") {
                local effect "Odds Ratio (`level'% CI)"
            }
            else if inlist("`_ecmd'", "stcox", "mestreg") {
                local effect "Hazard Ratio (`level'% CI)"
            }
            else if inlist("`_ecmd'", "poisson", "nbreg", "mepoisson", "menbreg", "xtpoisson") {
                local effect "IRR (`level'% CI)"
            }
            else {
                local effect "Effect (`level'% CI)"
            }
        }
        else {
            local effect "Coefficient (`level'% CI)"
        }
    }
    if "`vformat'" == "" local vformat "%5.`dp'f"

    // Default palette for multi-model
    if "`palette'" == "" {
        local palette "navy cranberry forest_green dkorange purple teal maroon olive_teal"
    }

    // Single-model color defaults
    if "`ciwidth'" == "" local ciwidth "medium"
    if "`msymbol'" == "" local msymbol "O"
    if "`msize'" == "" {
        if `n_models' > 1 {
            local msize "medsmall"
        }
        else {
            local msize "medium"
        }
    }

    // CI critical value
    local crit = invnormal(1 - (1 - `level'/100)/2)

    // ====== Identify "." model (current estimates) ======
    local dot_idx 0
    forvalues m = 1/`n_models' {
        if "`: word `m' of `estlist''" == "." {
            local dot_idx `m'
        }
    }

    // Validate current estimates if needed
    if `dot_idx' > 0 {
        if "`e(cmd)'" == "" {
            display as error "no estimation results found"
            display as error "run a regression command first, or specify stored estimate names"
            exit 301
        }
    }

    // ====== Save and extract current estimates before any restore ======
    local had_est = ("`e(cmd)'" != "")
    if `had_est' {
        tempname __est_save
        _est hold `__est_save', copy
    }

    // Extract "." matrices before any estimates restore
    if `dot_idx' > 0 {
        tempname b_dot V_dot
        matrix `b_dot' = e(b)
        matrix `V_dot' = e(V)
    }

    // ====== Gather variable labels before preserve (for auto-labeling) ======
    // Build label map: coef_name -> human-readable label
    // Uses variable labels and factor value labels from data in memory
    local _auto_labels ""
    local _n_autolabels 0
    local _n_interactions 0
    forvalues m = 1/`n_models' {
        local est_name : word `m' of `estlist'
        if `m' == `dot_idx' {
            local _colnames : colnames `b_dot'
        }
        else {
            capture estimates restore `est_name'
            if _rc continue
            tempname _btemp
            matrix `_btemp' = e(b)
            local _colnames : colnames `_btemp'
        }
        foreach _cn of local _colnames {
            // Skip if already mapped
            local _already 0
            forvalues _ai = 1/`_n_autolabels' {
                if `"`_autokey_`_ai''"' == `"`_cn'"' {
                    local _already 1
                    continue, break
                }
            }
            if `_already' continue

            // Parse: strip equation prefix (eq:varname -> varname)
            local _basevar "`_cn'"
            if strpos("`_cn'", ":") > 0 {
                local _basevar = substr("`_cn'", strpos("`_cn'", ":") + 1, .)
            }

            // Parse factor notation: #.varname or #b.varname or c.varname
            local _facval ""
            local _purvar "`_basevar'"
            if regexm("`_basevar'", "^([0-9]+)b?\.(.+)$") {
                local _facval = regexs(1)
                local _purvar = regexs(2)
            }
            else if regexm("`_basevar'", "^[co]\.(.+)$") {
                local _purvar = regexs(1)
            }

            // Interaction terms: skip complex patterns with #
            if strpos("`_basevar'", "#") > 0 {
                local `++_n_interactions'
                continue
            }

            local _label ""
            // Factor variable: try value label first
            if "`_facval'" != "" {
                capture {
                    local _vallbl : value label `_purvar'
                    if "`_vallbl'" != "" {
                        local _label : label `_vallbl' `_facval'
                    }
                }
                // Fall back to "VarLabel = value" or "varname = value"
                if `"`_label'"' == "" | `"`_label'"' == "`_facval'" {
                    local _vl : variable label `_purvar'
                    if `"`_vl'"' != "" {
                        local _label `"`_vl' = `_facval'"'
                    }
                }
            }
            else if "`_cn'" != "_cons" {
                // Regular variable: use variable label
                capture {
                    local _label : variable label `_purvar'
                }
            }

            if `"`_label'"' != "" {
                local `++_n_autolabels'
                local _autokey_`_n_autolabels' `"`_cn'"'
                local _autoval_`_n_autolabels' `"`_label'"'
            }
        }
    }

    if `_n_interactions' > 0 {
        display as text "(note: `_n_interactions' interaction term(s) excluded from plot)"
    }

    // Restore current estimates if we moved away
    if `dot_idx' > 0 & `n_models' > 1 {
        if "`__est_save'" != "" {
            capture _est unhold `__est_save'
            _est hold `__est_save', copy
        }
    }

    // ====== Build combined dataset via postfile ======
    preserve
    clear

    tempname posthn
    tempfile postfn
    postfile `posthn' str244 coef_name double(es se lci uci) byte model_id ///
        using `postfn', replace

    forvalues m = 1/`n_models' {
        local est_name : word `m' of `estlist'

        if `m' == `dot_idx' {
            // Current estimates (already extracted)
            local k = colsof(`b_dot')
            local names : colnames `b_dot'

            forvalues i = 1/`k' {
                local nm : word `i' of `names'
                local this_se = sqrt(`V_dot'[`i', `i'])
                if `this_se' < 1e-15 continue

                local this_b = `b_dot'[1, `i']
                local this_lci = `this_b' - `crit' * `this_se'
                local this_uci = `this_b' + `crit' * `this_se'

                post `posthn' ("`nm'") (`this_b') (`this_se') ///
                    (`this_lci') (`this_uci') (`m')
            }
        }
        else {
            // Named estimate
            capture estimates restore `est_name'
            if _rc {
                postclose `posthn'
                restore
                if "`__est_save'" != "" {
                    capture _est unhold `__est_save'
                }
                display as error `"estimation results '`est_name'' not found"'
                exit 111
            }

            tempname bm Vm
            matrix `bm' = e(b)
            matrix `Vm' = e(V)

            local k = colsof(`bm')
            local names : colnames `bm'

            forvalues i = 1/`k' {
                local nm : word `i' of `names'
                local this_se = sqrt(`Vm'[`i', `i'])
                if `this_se' < 1e-15 continue

                local this_b = `bm'[1, `i']
                local this_lci = `this_b' - `crit' * `this_se'
                local this_uci = `this_b' + `crit' * `this_se'

                post `posthn' ("`nm'") (`this_b') (`this_se') ///
                    (`this_lci') (`this_uci') (`m')
            }
        }
    }

    postclose `posthn'
    use `postfn', clear

    // Restore original estimation state
    if "`__est_save'" != "" {
        capture _est unhold `__est_save'
    }

    // ====== Transform data ======

    // Apply keep/drop
    if `"`keep'"' != "" {
        _eplot_apply_keep coef_name, keep(`keep')
    }
    if `"`drop'"' != "" {
        _eplot_apply_drop coef_name, drop(`drop')
    }

    // Check we have data
    quietly count
    if r(N) == 0 {
        display as error "no coefficients to plot after keep/drop"
        restore
        exit 2000
    }

    // Apply rename (before groups/headers so group specs match renamed names)
    if `"`rename'"' != "" {
        _eplot_apply_rename coef_name, rename(`rename')
    }

    // ====== P-values (compute BEFORE eform so z = b/se is valid) ======
    if `n_models' == 1 {
        quietly gen double _pval = 2 * normal(-abs(es / se)) if se > 0 & !missing(se)
    }

    // Apply eform
    if "`eform'" != "" {
        quietly {
            replace es = exp(es)
            replace lci = exp(lci)
            replace uci = exp(uci)
        }
    }

    // Apply rescale
    if `rescale' != 1 {
        quietly {
            replace es = es * `rescale'
            replace lci = lci * `rescale'
            replace uci = uci * `rescale'
        }
    }

    // ====== Determine coefficient order ======
    gen long _orig_row = _n
    bysort coef_name (_orig_row) : gen long _first_seen = _orig_row[1]

    if "`sort'" != "" {
        // Sort by effect size (first model's value)
        bysort coef_name (_orig_row) : gen double _sort_es = es[1]
        sort _sort_es _first_seen model_id
        drop _sort_es
    }
    else if `"`order'"' != "" {
        gen long _order_rank = .
        local o 0
        local _unmatched ""
        foreach coef of local order {
            local `++o'
            quietly count if coef_name == `"`coef'"'
            if r(N) == 0 {
                local _unmatched "`_unmatched' `coef'"
            }
            quietly replace _order_rank = `o' if coef_name == `"`coef'"'
        }
        if "`_unmatched'" != "" {
            display as text "(note: order() did not match:`_unmatched')"
        }
        quietly replace _order_rank = 1000 + _first_seen if missing(_order_rank)
        sort _order_rank model_id
        drop _order_rank
    }
    else {
        sort _first_seen model_id
    }

    // ====== Assign base positions ======
    // Tag first occurrence of each coefficient
    bysort coef_name (_orig_row) : gen byte _coef_tag = (_n == 1)

    // Count unique coefficients
    quietly count if _coef_tag
    local n_coefs = r(N)

    // Create position mapping (avoid nested preserve)
    tempfile fulldata posmap
    quietly save `fulldata'

    keep if _coef_tag
    gen long _base_pos = _n
    keep coef_name _base_pos
    quietly save `posmap'

    use `fulldata', clear
    quietly merge m:1 coef_name using `posmap', nogen

    // Calculate plot positions with model offsets
    if `n_models' > 1 {
        gen double _plot_pos = _base_pos ///
            + (model_id - (`n_models' + 1) / 2) * `offset'
    }
    else {
        gen double _plot_pos = _base_pos
    }

    // ====== Process groups/headers (single-model only) ======
    // NOTE: groups/headers run BEFORE coeflabels so specs match original names
    if `n_models' == 1 {
        gen byte _rowtype = 1
        gen byte _gapflag = 0

        if `"`groups'"' != "" {
            _eplot_process_groups _base_pos coef_name _rowtype _gapflag, ///
                groups(`groups') gap(`gap')
        }
        if `"`headers'"' != "" {
            _eplot_process_headers _base_pos coef_name _rowtype, ///
                headers(`headers')
        }

        // Recalculate positions after insertions
        sort _base_pos
        gen double _rowspace = 1
        quietly replace _rowspace = `gap' if _gapflag == 1
        quietly replace _base_pos = sum(_rowspace)
        quietly replace _plot_pos = _base_pos

        // Update coef count to include headers
        local n_items = _N
    }
    else {
        gen byte _rowtype = 1
        local n_items = `n_coefs'

        // Warn if groups/headers specified in multi-model mode
        if `"`groups'"' != "" | `"`headers'"' != "" | `gap' > 0 {
            display as text "(note: groups(), headers(), and gap() are ignored " ///
                "in multi-model mode)"
        }
    }

    // ====== Auto-label from variable labels (before coeflabels override) ======
    if `_n_autolabels' > 0 {
        forvalues _ai = 1/`_n_autolabels' {
            quietly replace coef_name = `"`_autoval_`_ai''"' ///
                if coef_name == `"`_autokey_`_ai''"'
        }
    }

    // ====== Apply coefficient labels (AFTER auto-labels, overrides them) ======
    if `"`coeflabels'"' != "" {
        _eplot_apply_coeflabels coef_name, coeflabels(`coeflabels')
    }

    // ====== Significance stars (string labels from pre-eform p-values) ======
    if "`stars'" != "" & `n_models' == 1 {
        quietly gen str _star = "" if _rowtype == 1
        quietly replace _star = "*"   if _pval < 0.05   & !missing(_pval)
        quietly replace _star = "**"  if _pval < 0.01   & !missing(_pval)
        quietly replace _star = "***" if _pval < 0.001  & !missing(_pval)
    }

    // ====== Significance coloring flag ======
    if "`sigcolors'" != "" {
        if "`sigcolor'" == "" local sigcolor "cranberry"
        if "`insigncolor'" == "" local insigncolor "gs10"
        quietly gen byte _sig = 0 if _rowtype == 1
        quietly replace _sig = 1 if _rowtype == 1 & ///
            ((lci > `null' & !missing(lci)) | (uci < `null' & !missing(uci)))
    }

    // ====== Determine axis range ======
    _eplot_calc_range lci uci if _rowtype == 1
    local data_xmin = `s(min)'
    local data_xmax = `s(max)'
    local data_range = `s(range)'
    local xmin_pad = `s(min_pad)'
    local xmax_pad = `s(max_pad)'

    if `"`xlabel'"' != "" {
        _eplot_effect_axis_labels, min(`data_xmin') max(`data_xmax') ///
            xlabel(`xlabel')
    }
    else {
        _eplot_effect_axis_labels, min(`data_xmin') max(`data_xmax')
    }
    local _effect_axis_opts `"`s(axisopts)'"'

    // ====== Values annotation (single-model only) ======
    local val_cmd ""
    if "`values'" != "" & "`horizontal'" == "" {
        display as text "(note: values annotation requires horizontal layout)"
    }
    if "`values'" != "" & `n_models' == 1 & "`horizontal'" != "" {
        local _star_suf ""
        if "`stars'" != "" {
            local _star_suf `" + _star"'
        }
        gen str _val_text = string(es, "`vformat'") ///
            + " (" + string(lci, "`vformat'") ///
            + ", " + string(uci, "`vformat'") + ")" ///
            `_star_suf' ///
            if _rowtype == 1 & !missing(es)

        local val_xpos = `data_xmax' + 0.15 * `data_range'
        gen double _val_x = `val_xpos' if !missing(_val_text)
        _eplot_value_margin _val_text, header(`"`effect'"')
        local _val_right_margin = `s(right_margin)'

        local val_cmd `"(scatter _plot_pos _val_x if !missing(_val_text), msymbol(none) mlabel(_val_text) mlabpos(3) mlabgap(0) mlabsize(vsmall) mlabcolor(gs4))"'
    }

    // ====== Build graph command ======
    local graphcmd "twoway"

    if `n_models' > 1 {
        // --- Multi-model graph ---
        local _plot_elem 0
        forvalues m = 1/`n_models' {
            local mc : word `m' of `palette'
            if "`mc'" == "" local mc "navy"

            // CI lines
            if "`noci'" == "" {
                local `++_plot_elem'
                if "`horizontal'" != "" {
                    if "`cicap'" != "" {
                        local graphcmd `"`graphcmd' (rcap lci uci _plot_pos if model_id == `m' & _rowtype == 1, horizontal lcolor(`mc') lwidth(`ciwidth'))"'
                    }
                    else {
                        local graphcmd `"`graphcmd' (rspike lci uci _plot_pos if model_id == `m' & _rowtype == 1, horizontal lcolor(`mc') lwidth(`ciwidth'))"'
                    }
                }
                else {
                    if "`cicap'" != "" {
                        local graphcmd `"`graphcmd' (rcap lci uci _plot_pos if model_id == `m' & _rowtype == 1, lcolor(`mc') lwidth(`ciwidth'))"'
                    }
                    else {
                        local graphcmd `"`graphcmd' (rspike lci uci _plot_pos if model_id == `m' & _rowtype == 1, lcolor(`mc') lwidth(`ciwidth'))"'
                    }
                }
            }

            // Markers
            local `++_plot_elem'
            local _leg_idx_`m' = `_plot_elem'
            if "`horizontal'" != "" {
                local graphcmd `"`graphcmd' (scatter _plot_pos es if model_id == `m' & _rowtype == 1, msymbol(`msymbol') mcolor(`mc') msize(`msize'))"'
            }
            else {
                local graphcmd `"`graphcmd' (scatter es _plot_pos if model_id == `m' & _rowtype == 1, msymbol(`msymbol') mcolor(`mc') msize(`msize'))"'
            }
        }
    }
    else {
        // --- Single-model graph ---
        local mc = cond("`mcolor'" != "", "`mcolor'", "navy")
        local cc = cond("`cicolor'" != "", "`cicolor'", "`mc'")

        if "`sigcolors'" != "" {
            // Split into significant and non-significant plot elements
            local _ci_type = cond("`cicap'" != "", "rcap", "rspike")
            local _h_opt = cond("`horizontal'" != "", "horizontal", "")

            // CI lines
            if "`noci'" == "" {
                if "`horizontal'" != "" {
                    local graphcmd `"`graphcmd' (`_ci_type' lci uci _plot_pos if _rowtype == 1 & _sig == 1, horizontal lcolor(`sigcolor') lwidth(`ciwidth'))"'
                    local graphcmd `"`graphcmd' (`_ci_type' lci uci _plot_pos if _rowtype == 1 & _sig == 0, horizontal lcolor(`insigncolor') lwidth(`ciwidth'))"'
                }
                else {
                    local graphcmd `"`graphcmd' (`_ci_type' lci uci _plot_pos if _rowtype == 1 & _sig == 1, lcolor(`sigcolor') lwidth(`ciwidth'))"'
                    local graphcmd `"`graphcmd' (`_ci_type' lci uci _plot_pos if _rowtype == 1 & _sig == 0, lcolor(`insigncolor') lwidth(`ciwidth'))"'
                }
            }

            // Markers
            if "`horizontal'" != "" {
                local graphcmd `"`graphcmd' (scatter _plot_pos es if _rowtype == 1 & _sig == 1, msymbol(`msymbol') mcolor(`sigcolor') msize(`msize'))"'
                local graphcmd `"`graphcmd' (scatter _plot_pos es if _rowtype == 1 & _sig == 0, msymbol(`msymbol') mcolor(`insigncolor') msize(`msize'))"'
            }
            else {
                local graphcmd `"`graphcmd' (scatter es _plot_pos if _rowtype == 1 & _sig == 1, msymbol(`msymbol') mcolor(`sigcolor') msize(`msize'))"'
                local graphcmd `"`graphcmd' (scatter es _plot_pos if _rowtype == 1 & _sig == 0, msymbol(`msymbol') mcolor(`insigncolor') msize(`msize'))"'
            }
        }
        else {
            // Standard single-color plot
            // CI lines
            if "`noci'" == "" {
                if "`horizontal'" != "" {
                    if "`cicap'" != "" {
                        local graphcmd `"`graphcmd' (rcap lci uci _plot_pos if _rowtype == 1, horizontal lcolor(`cc') lwidth(`ciwidth'))"'
                    }
                    else {
                        local graphcmd `"`graphcmd' (rspike lci uci _plot_pos if _rowtype == 1, horizontal lcolor(`cc') lwidth(`ciwidth'))"'
                    }
                }
                else {
                    if "`cicap'" != "" {
                        local graphcmd `"`graphcmd' (rcap lci uci _plot_pos if _rowtype == 1, lcolor(`cc') lwidth(`ciwidth'))"'
                    }
                    else {
                        local graphcmd `"`graphcmd' (rspike lci uci _plot_pos if _rowtype == 1, lcolor(`cc') lwidth(`ciwidth'))"'
                    }
                }
            }

            // Markers
            if "`horizontal'" != "" {
                local graphcmd `"`graphcmd' (scatter _plot_pos es if _rowtype == 1, msymbol(`msymbol') mcolor(`mc') msize(`msize'))"'
            }
            else {
                local graphcmd `"`graphcmd' (scatter es _plot_pos if _rowtype == 1, msymbol(`msymbol') mcolor(`mc') msize(`msize'))"'
            }
        }
    }

    // Values annotation
    if "`val_cmd'" != "" {
        local graphcmd `"`graphcmd' `val_cmd'"'
    }

    // ====== Build y-axis labels ======
    local ylabels ""
    if `n_models' == 1 {
        // Single model: use all rows (including headers from groups)
        forvalues i = 1/`=_N' {
            local this_pos = _base_pos[`i']
            local this_label = coef_name[`i']
            local this_type = _rowtype[`i']

            if `this_type' == 6 continue

            // Bold for headers
            if `this_type' == 0 {
                local this_label `"{bf:`this_label'}"'
            }

            local ylabels `"`ylabels' `this_pos' `"`this_label'"'"'
        }
    }
    else {
        // Multi-model: use unique coefficient tags only
        forvalues i = 1/`=_N' {
            if _coef_tag[`i'] == 0 continue
            local this_pos = _base_pos[`i']
            local this_label = coef_name[`i']
            local ylabels `"`ylabels' `this_pos' `"`this_label'"'"'
        }
    }
    quietly summarize _base_pos, meanonly
    local pos_max = r(max)

    // ====== Graph options ======
    local ypad_lo = cond(`n_models' > 1, ///
        0.5 - `offset' * `n_models' / 2, 0)
    local ypad_hi = `pos_max' + 1

    local _xscale_max = `xmax_pad'
    if "`horizontal'" != "" {
        if "`values'" != "" & `n_models' == 1 {
            local _xscale_max = `val_xpos'
        }
        local graphcmd `"`graphcmd', ylabel(`ylabels', angle(0) labsize(small) nogrid noticks)"'
        local graphcmd `"`graphcmd' ytitle("") xscale(range(`xmin_pad' `_xscale_max'))"'
        if "`values'" != "" & `n_models' == 1 {
            local _val_hdr_y = 0.3
            local ypad_lo = cond(`ypad_lo' < -0.2, `ypad_lo', -0.2)
            local graphcmd `"`graphcmd' xtitle(`"`effect'"', size(medsmall))"'
            local graphcmd `"`graphcmd' text(`_val_hdr_y' `val_xpos' `"{bf:`effect'}"', size(vsmall) placement(e) justification(left))"'
        }
        else local graphcmd `"`graphcmd' xtitle(`"`effect'"')"'
        local graphcmd `"`graphcmd' xlabel(`_effect_axis_opts')"'
        if `"`favors'"' != "" {
            local ypad_hi = `pos_max' + 2
        }
        local graphcmd `"`graphcmd' yscale(reverse noline range(`ypad_lo' `ypad_hi'))"'
    }
    else {
        local graphcmd `"`graphcmd', xlabel(`ylabels', angle(45) labsize(small) nogrid)"'
        local graphcmd `"`graphcmd' xscale(range(`ypad_lo' `ypad_hi'))"'
        local graphcmd `"`graphcmd' xtitle("") ytitle(`"`effect'"') yscale(range(`xmin_pad' `xmax_pad'))"'
        local graphcmd `"`graphcmd' ylabel(`_effect_axis_opts')"'
    }

    local _xline_opt ""
    if "`xline'" != "" local _xline_opt `"xline(`xline')"'
    _eplot_build_reflines, null(`null') `_xline_opt' ///
        `horizontal' `nonull'
    local refline_cmd `"`s(cmd)'"'
    if "`refline_cmd'" != "" {
        local graphcmd `"`graphcmd' `refline_cmd'"'
    }

    // Legend
    if `n_models' > 1 {
        local leg_order ""
        forvalues m = 1/`n_models' {
            local ml : word `m' of `modellabels'
            if `"`ml'"' == "" {
                local ml : word `m' of `estlist'
            }
            local leg_idx = `_leg_idx_`m''
            local leg_order `"`leg_order' `leg_idx' `"`ml'"'"'
        }
        if `"`legendopts'"' != "" {
            local graphcmd `"`graphcmd' legend(order(`leg_order') `legendopts')"'
        }
        else {
            local graphcmd `"`graphcmd' legend(order(`leg_order') rows(1) pos(6) size(small))"'
        }
    }
    else {
        local graphcmd `"`graphcmd' legend(off)"'
    }

    // Titles
    if `"`title'"' != "" {
        local graphcmd `"`graphcmd' title(`title')"'
    }
    if `"`subtitle'"' != "" {
        local graphcmd `"`graphcmd' subtitle(`subtitle')"'
    }
    if `"`note'"' != "" {
        local graphcmd `"`graphcmd' note(`note')"'
    }

    // Scheme
    if "`scheme'" != "" {
        local graphcmd `"`graphcmd' scheme(`scheme')"'
    }

    // Plotregion / graphregion
    local _plotregion_use `"`plotregion'"'
    if `"`_plotregion_use'"' == "" & "`horizontal'" != "" & "`values'" != "" & `n_models' == 1 {
        local _plotregion_use "margin(l+2 r+`_val_right_margin' t+2 b+2)"
    }
    if `"`_plotregion_use'"' != "" {
        local graphcmd `"`graphcmd' plotregion(`_plotregion_use')"'
    }
    if `"`graphregion'"' != "" {
        local graphcmd `"`graphcmd' graphregion(`graphregion')"'
    }

    // Aspect
    if "`aspect'" != "" {
        local graphcmd `"`graphcmd' aspect(`aspect')"'
    }

    // Name and saving
    if "`name'" != "" {
        local graphcmd `"`graphcmd' name(`name')"'
    }
    if `"`saving'"' != "" {
        local graphcmd `"`graphcmd' saving(`saving')"'
    }

    // Additional options
    if `"`options'"' != "" {
        local graphcmd `"`graphcmd' `options'"'
    }

    // Favors annotation (horizontal mode only)
    if `"`favors'"' != "" & "`horizontal'" != "" {
        local _fav_top = `pos_max' + 1.5
        _eplot_build_favors, favors(`favors') null(`null') ///
            min(`data_xmin') max(`data_xmax') top(`_fav_top')
        local graphcmd `"`graphcmd' `s(cmd)'"'
    }

    // ====== Execute graph ======
    `graphcmd'

    // ====== Return results ======
    if `n_models' == 1 {
        // Single-model: k x 3 matrix (b, ll, ul)
        quietly count if _rowtype == 1
        local _ntab = r(N)
        if `_ntab' > 0 {
            tempname _rtable
            matrix `_rtable' = J(`_ntab', 3, .)
            matrix colnames `_rtable' = "b" "ll" "ul"
            local _ri 0
            local _rnames ""
            forvalues i = 1/`=_N' {
                if _rowtype[`i'] != 1 continue
                local `++_ri'
                matrix `_rtable'[`_ri', 1] = es[`i']
                matrix `_rtable'[`_ri', 2] = lci[`i']
                matrix `_rtable'[`_ri', 3] = uci[`i']
                local _rnm = coef_name[`i']
                local _rnames `"`_rnames' `"`_rnm'"'"'
            }
            matrix rownames `_rtable' = `_rnames'
            return matrix table = `_rtable'
        }
    }
    else {
        // Multi-model: k x (3 * n_models) matrix
        // Columns: b_1 ll_1 ul_1 b_2 ll_2 ul_2 ...
        quietly count if _coef_tag == 1
        local _ntab = r(N)
        if `_ntab' > 0 {
            tempname _rtable
            local _ncols = 3 * `n_models'
            matrix `_rtable' = J(`_ntab', `_ncols', .)

            // Build column names
            local _cnames ""
            forvalues m = 1/`n_models' {
                local _cnames "`_cnames' b_`m' ll_`m' ul_`m'"
            }
            matrix colnames `_rtable' = `_cnames'

            // Fill matrix: iterate over unique coefficients
            local _ri 0
            local _rnames ""
            forvalues i = 1/`=_N' {
                if _coef_tag[`i'] != 1 continue
                local `++_ri'
                local _rnm = coef_name[`i']
                local _rnames `"`_rnames' `"`_rnm'"'"'

                // Fill in values for each model
                forvalues j = `i'/`=_N' {
                    if coef_name[`j'] != `"`_rnm'"' continue
                    local _mid = model_id[`j']
                    local _col = (`_mid' - 1) * 3 + 1
                    matrix `_rtable'[`_ri', `_col'] = es[`j']
                    matrix `_rtable'[`_ri', `_col' + 1] = lci[`j']
                    matrix `_rtable'[`_ri', `_col' + 2] = uci[`j']
                }
            }
            matrix rownames `_rtable' = `_rnames'
            return matrix table = `_rtable'
        }
    }

    // Return p-values vector (estimates mode, single-model)
    if `n_models' == 1 {
        quietly count if _rowtype == 1 & !missing(_pval)
        if r(N) > 0 {
            local _npv = `_ntab'
            tempname _rpvals
            matrix `_rpvals' = J(`_npv', 1, .)
            matrix colnames `_rpvals' = "pvalue"
            local _pi 0
            local _pnames ""
            forvalues i = 1/`=_N' {
                if _rowtype[`i'] != 1 continue
                local `++_pi'
                capture {
                    matrix `_rpvals'[`_pi', 1] = _pval[`i']
                }
                local _pnm = coef_name[`i']
                local _pnames `"`_pnames' `"`_pnm'"'"'
            }
            matrix rownames `_rpvals' = `_pnames'
            return matrix pvalues = `_rpvals'
        }
    }

        return scalar N = `n_items'
        return scalar n_models = `n_models'
        quietly count if _rowtype == 1
        return scalar k = r(N)
        return local cmd `"`graphcmd'"'

        restore
    }
    local rc = _rc
    set varabbrev `_orig_varabbrev'
    if `rc' exit `rc'
end

// =============================================================================
// Matrix Mode: Plot from matrix
// =============================================================================

program define _eplot_matrix, rclass
    version 16.0
    local _orig_varabbrev = c(varabbrev)
    set varabbrev off
    capture noisily {
        syntax , Matrix(name) ///
            [ ///
            LEVel(cilevel) ///
            EFORM ///
            REScale(real 1) ///
            /// Coefficient selection
            KEEP(string asis) ///
            DROP(string asis) ///
            COEFLabels(string asis) ///
            /// Reference lines
            XLine(numlist) ///
            XLABel(string asis) ///
            NULL(real -999) ///
            NONULL ///
            NOCI ///
            CICap ///
            /// Display
            STYle(string) ///
            DP(integer 2) ///
            EFFect(string) ///
            VALues ///
            VFormat(string) ///
            SORT ///
            ORDer(string asis) ///
            SIGColors ///
            SIGColor(string) ///
            INSIGColor(string) ///
            STARS ///
            Favors(string asis) ///
            /// Layout
            HORizontal ///
            VERTical ///
            /// Markers
            MColor(string) ///
            MSymbol(string) ///
            MSize(string) ///
            CIColor(string) ///
            CIWidth(string) ///
            /// Graph options
            TItle(string asis) ///
            SUBtitle(string asis) ///
            NOTE(string asis) ///
            NAME(string) ///
            SAVing(string asis) ///
            SCHEME(string) ///
            PLOTRegion(string asis) ///
            GRAPHRegion(string asis) ///
            ASPect(string) ///
            NOCONStant ///
            * ///
            ]

        // nocons -> add _cons to drop list
        if "`noconstant'" != "" {
            local drop `"`drop' _cons"'
        }

        // eform -> auto-suppress constant (exp(_cons) is not meaningful)
        if "`eform'" != "" & "`noconstant'" == "" {
            local _has_cons 0
            foreach _d of local drop {
                if "`_d'" == "_cons" local _has_cons 1
            }
            if !`_has_cons' {
                local drop `"`drop' _cons"'
                display as text "(note: constant suppressed with eform)"
            }
        }

        // ====== Style presets (apply BEFORE user overrides) ======
        if "`style'" != "" {
            _eplot_apply_style, style(`"`style'"')
            if "`values'" == "" local values "`s(values)'"
            if "`mcolor'" == "" local mcolor "`s(mcolor)'"
            if "`cicolor'" == "" local cicolor "`s(cicolor)'"
            if "`cicap'" == "" local cicap "`s(cicap)'"
            if "`msymbol'" == "" local msymbol "`s(msymbol)'"
            if "`msize'" == "" local msize "`s(msize)'"
        }

    // Validate matrix dimensions
    local nrows = rowsof(`matrix')
    local ncols = colsof(`matrix')

    if `ncols' != 2 & `ncols' != 3 {
        display as error "matrix must have 2 columns (b, se) or 3 columns (b, lci, uci)"
        exit 198
    }

    // Set defaults
    if "`horizontal'" == "" & "`vertical'" == "" {
        local horizontal "horizontal"
    }
    if "`level'" == "" local level = c(level)
    local crit = invnormal(1 - (1 - `level'/100)/2)
    if `null' == -999 {
        local null = cond("`eform'" != "", 1, 0)
    }
    if `"`effect'"' == "" {
        if "`eform'" != "" {
            local effect "Effect (`level'% CI)"
        }
        else {
            local effect "Estimate (`level'% CI)"
        }
    }
    if "`vformat'" == "" local vformat "%5.`dp'f"
    if "`mcolor'" == "" local mcolor "navy"
    if "`cicolor'" == "" local cicolor "`mcolor'"
    if "`ciwidth'" == "" local ciwidth "medium"
    if "`msymbol'" == "" local msymbol "O"
    if "`msize'" == "" local msize "medium"

    // Get row names
    local rownames : rownames `matrix'

    // Build dataset
    preserve
    clear
    quietly set obs `nrows'

    quietly gen str244 coef_name = ""
    quietly gen double es = .
    quietly gen double se = .
    quietly gen double lci = .
    quietly gen double uci = .

    forvalues i = 1/`nrows' {
        local nm : word `i' of `rownames'
        quietly replace coef_name = "`nm'" in `i'
        quietly replace es = `matrix'[`i', 1] in `i'

        if `ncols' == 3 {
            quietly replace lci = `matrix'[`i', 2] in `i'
            quietly replace uci = `matrix'[`i', 3] in `i'
        }
        else {
            quietly replace se = `matrix'[`i', 2] in `i'
            quietly replace lci = `matrix'[`i', 1] - `crit' * `matrix'[`i', 2] in `i'
            quietly replace uci = `matrix'[`i', 1] + `crit' * `matrix'[`i', 2] in `i'
        }
    }

    // Apply keep/drop
    if `"`keep'"' != "" {
        _eplot_apply_keep coef_name, keep(`keep')
    }
    if `"`drop'"' != "" {
        _eplot_apply_drop coef_name, drop(`drop')
    }

    quietly count
    if r(N) == 0 {
        display as error "no rows to plot after keep/drop"
        restore
        exit 2000
    }
    local n_coefs = r(N)

    // Apply labels
    if `"`coeflabels'"' != "" {
        _eplot_apply_coeflabels coef_name, coeflabels(`coeflabels')
    }

    // Stars p-value computation (BEFORE eform, only for 2-col matrices with SE)
    if "`stars'" != "" & `ncols' == 2 {
        quietly gen double _pval = 2 * normal(-abs(es / se)) ///
            if se > 0 & !missing(se) & !missing(es)
    }
    else if "`stars'" != "" & `ncols' == 3 {
        display as text "(note: stars requires standard errors; not available with 3-column matrix)"
        local stars ""
    }

    // Apply eform
    if "`eform'" != "" {
        quietly {
            replace es = exp(es)
            replace lci = exp(lci)
            replace uci = exp(uci)
        }
    }

    // Apply rescale
    if `rescale' != 1 {
        quietly {
            replace es = es * `rescale'
            replace lci = lci * `rescale'
            replace uci = uci * `rescale'
        }
    }

    // Significance coloring
    if "`sigcolors'" != "" {
        if "`sigcolor'" == "" local sigcolor "cranberry"
        if "`insigncolor'" == "" local insigncolor "gs10"
        quietly gen byte _sig = 0
        quietly replace _sig = 1 if ///
            ((lci > `null' & !missing(lci)) | (uci < `null' & !missing(uci)))
    }

    // Sort/order
    gen long _orig = _n
    if "`sort'" != "" {
        sort es _orig
    }
    else if `"`order'"' != "" {
        gen long _order_rank = .
        local o 0
        local _unmatched ""
        foreach coef of local order {
            local `++o'
            quietly count if coef_name == `"`coef'"'
            if r(N) == 0 {
                local _unmatched "`_unmatched' `coef'"
            }
            quietly replace _order_rank = `o' if coef_name == `"`coef'"'
        }
        if "`_unmatched'" != "" {
            display as text "(note: order() did not match:`_unmatched')"
        }
        quietly replace _order_rank = 1000 + _orig if missing(_order_rank)
        sort _order_rank
        drop _order_rank
    }

    // Positions
    gen double _plot_pos = _n

    // Stars string generation (from pre-eform p-values)
    if "`stars'" != "" {
        quietly gen str _star = ""
        quietly replace _star = "*"   if _pval < 0.05   & !missing(_pval)
        quietly replace _star = "**"  if _pval < 0.01   & !missing(_pval)
        quietly replace _star = "***" if _pval < 0.001  & !missing(_pval)
    }

    // Axis range
    _eplot_calc_range lci uci
    local data_xmin = `s(min)'
    local data_xmax = `s(max)'
    local data_range = `s(range)'
    local xmin_pad = `s(min_pad)'
    local xmax_pad = `s(max_pad)'

    if `"`xlabel'"' != "" {
        _eplot_effect_axis_labels, min(`data_xmin') max(`data_xmax') ///
            xlabel(`xlabel')
    }
    else {
        _eplot_effect_axis_labels, min(`data_xmin') max(`data_xmax')
    }
    local _effect_axis_opts `"`s(axisopts)'"'

    // Values annotation
    local val_cmd ""
    if "`values'" != "" & "`horizontal'" == "" {
        display as text "(note: values annotation requires horizontal layout)"
    }
    if "`values'" != "" & "`horizontal'" != "" {
        local _star_suf ""
        if "`stars'" != "" {
            local _star_suf `" + _star"'
        }
        gen str _val_text = string(es, "`vformat'") ///
            + " (" + string(lci, "`vformat'") ///
            + ", " + string(uci, "`vformat'") + ")" ///
            `_star_suf'

        local val_xpos = `data_xmax' + 0.15 * `data_range'
        gen double _val_x = `val_xpos'
        _eplot_value_margin _val_text, header(`"`effect'"')
        local _val_right_margin = `s(right_margin)'

        local val_cmd `"(scatter _plot_pos _val_x, msymbol(none) mlabel(_val_text) mlabpos(3) mlabgap(0) mlabsize(vsmall) mlabcolor(gs4))"'
    }

    // Build graph
    local graphcmd "twoway"

    // CI lines
    if "`noci'" == "" {
        if "`horizontal'" != "" {
            if "`cicap'" != "" {
                local graphcmd `"`graphcmd' (rcap lci uci _plot_pos, horizontal lcolor(`cicolor') lwidth(`ciwidth'))"'
            }
            else {
                local graphcmd `"`graphcmd' (rspike lci uci _plot_pos, horizontal lcolor(`cicolor') lwidth(`ciwidth'))"'
            }
        }
        else {
            if "`cicap'" != "" {
                local graphcmd `"`graphcmd' (rcap lci uci _plot_pos, lcolor(`cicolor') lwidth(`ciwidth'))"'
            }
            else {
                local graphcmd `"`graphcmd' (rspike lci uci _plot_pos, lcolor(`cicolor') lwidth(`ciwidth'))"'
            }
        }
    }

    // Markers (with sigcolors support)
    if "`sigcolors'" != "" {
        if "`horizontal'" != "" {
            local graphcmd `"`graphcmd' (scatter _plot_pos es if _sig == 1, msymbol(`msymbol') mcolor(`sigcolor') msize(`msize'))"'
            local graphcmd `"`graphcmd' (scatter _plot_pos es if _sig == 0, msymbol(`msymbol') mcolor(`insigncolor') msize(`msize'))"'
        }
        else {
            local graphcmd `"`graphcmd' (scatter es _plot_pos if _sig == 1, msymbol(`msymbol') mcolor(`sigcolor') msize(`msize'))"'
            local graphcmd `"`graphcmd' (scatter es _plot_pos if _sig == 0, msymbol(`msymbol') mcolor(`insigncolor') msize(`msize'))"'
        }
    }
    else if "`horizontal'" != "" {
        local graphcmd `"`graphcmd' (scatter _plot_pos es, msymbol(`msymbol') mcolor(`mcolor') msize(`msize'))"'
    }
    else {
        local graphcmd `"`graphcmd' (scatter es _plot_pos, msymbol(`msymbol') mcolor(`mcolor') msize(`msize'))"'
    }

    // Values
    if "`val_cmd'" != "" {
        local graphcmd `"`graphcmd' `val_cmd'"'
    }

    // Y-axis labels
    local ylabels ""
    forvalues i = 1/`=_N' {
        local this_pos = _plot_pos[`i']
        local this_label = coef_name[`i']
        local ylabels `"`ylabels' `this_pos' `"`this_label'"'"'
    }
    quietly summarize _plot_pos, meanonly
    local pos_max = r(max)

    // Graph options
    local ypad_lo 0
    local ypad_hi = `pos_max' + 1
    local _xscale_max = `xmax_pad'
    if "`horizontal'" != "" {
        if "`values'" != "" {
            local _xscale_max = `val_xpos'
        }
        local graphcmd `"`graphcmd', ylabel(`ylabels', angle(0) labsize(small) nogrid)"'
        local graphcmd `"`graphcmd' ytitle("") xscale(range(`xmin_pad' `_xscale_max'))"'
        if "`values'" != "" {
            local _val_hdr_y = 0.3
            local ypad_lo = -0.2
            local graphcmd `"`graphcmd' xtitle(`"`effect'"', size(medsmall))"'
            local graphcmd `"`graphcmd' text(`_val_hdr_y' `val_xpos' `"{bf:`effect'}"', size(vsmall) placement(e) justification(left))"'
        }
        else local graphcmd `"`graphcmd' xtitle(`"`effect'"')"'
        local graphcmd `"`graphcmd' xlabel(`_effect_axis_opts')"'
        if `"`favors'"' != "" {
            local ypad_hi = `pos_max' + 2
        }
        local graphcmd `"`graphcmd' yscale(reverse range(`ypad_lo' `ypad_hi'))"'
    }
    else {
        local graphcmd `"`graphcmd', xlabel(`ylabels', angle(45) labsize(small) nogrid)"'
        local graphcmd `"`graphcmd' xscale(range(`ypad_lo' `ypad_hi'))"'
        local graphcmd `"`graphcmd' xtitle("") ytitle(`"`effect'"') yscale(range(`xmin_pad' `xmax_pad'))"'
        local graphcmd `"`graphcmd' ylabel(`_effect_axis_opts')"'
    }

    local _xline_opt ""
    if "`xline'" != "" local _xline_opt `"xline(`xline')"'
    _eplot_build_reflines, null(`null') `_xline_opt' ///
        `horizontal' `nonull'
    local graphcmd `"`graphcmd' `s(cmd)'"'

    // Legend off
    local graphcmd `"`graphcmd' legend(off)"'

    // Titles
    if `"`title'"' != "" local graphcmd `"`graphcmd' title(`title')"'
    if `"`subtitle'"' != "" local graphcmd `"`graphcmd' subtitle(`subtitle')"'
    if `"`note'"' != "" local graphcmd `"`graphcmd' note(`note')"'
    if "`scheme'" != "" local graphcmd `"`graphcmd' scheme(`scheme')"'
    local _plotregion_use `"`plotregion'"'
    if `"`_plotregion_use'"' == "" & "`horizontal'" != "" & "`values'" != "" {
        local _plotregion_use "margin(l+2 r+`_val_right_margin' t+2 b+2)"
    }
    if `"`_plotregion_use'"' != "" local graphcmd `"`graphcmd' plotregion(`_plotregion_use')"'
    if `"`graphregion'"' != "" local graphcmd `"`graphcmd' graphregion(`graphregion')"'
    if "`aspect'" != "" local graphcmd `"`graphcmd' aspect(`aspect')"'
    if "`name'" != "" local graphcmd `"`graphcmd' name(`name')"'
    if `"`saving'"' != "" local graphcmd `"`graphcmd' saving(`saving')"'
    if `"`options'"' != "" local graphcmd `"`graphcmd' `options'"'

    // Favors annotation (horizontal mode only)
    if `"`favors'"' != "" & "`horizontal'" != "" {
        local _fav_top = `pos_max' + 1.5
        _eplot_build_favors, favors(`favors') null(`null') ///
            min(`data_xmin') max(`data_xmax') top(`_fav_top')
        local graphcmd `"`graphcmd' `s(cmd)'"'
    }

    // Execute
    `graphcmd'

    // Return
    // Build r(table) matrix
    if `n_coefs' > 0 {
        tempname _rtable
        matrix `_rtable' = J(`n_coefs', 3, .)
        matrix colnames `_rtable' = "b" "ll" "ul"
        local _rnames ""
        forvalues i = 1/`n_coefs' {
            matrix `_rtable'[`i', 1] = es[`i']
            matrix `_rtable'[`i', 2] = lci[`i']
            matrix `_rtable'[`i', 3] = uci[`i']
            local _rnm = coef_name[`i']
            local _rnames `"`_rnames' `"`_rnm'"'"'
        }
        matrix rownames `_rtable' = `_rnames'
        return matrix table = `_rtable'
    }

        return scalar N = `n_coefs'
        return scalar k = `n_coefs'
        return local cmd `"`graphcmd'"'

        restore
    }
    local rc = _rc
    set varabbrev `_orig_varabbrev'
    if `rc' exit `rc'
end

// =============================================================================
// Shared helpers
// =============================================================================

program define _eplot_apply_style, sclass
    version 16.0
    local _orig_varabbrev = c(varabbrev)
    set varabbrev off
    capture noisily {
        syntax, STYle(string)

        sreturn clear
        local style = lower(trim("`style'"))

        if "`style'" == "forest" {
            sreturn local values "values"
            sreturn local mcolor "navy"
        }
        else if "`style'" == "coef" {
            sreturn local cicap "cicap"
            sreturn local msymbol "O"
            sreturn local mcolor "navy"
        }
        else if "`style'" == "lancet" {
            sreturn local mcolor "cranberry"
            sreturn local cicolor "cranberry"
            sreturn local cicap "cicap"
            sreturn local msymbol "D"
            sreturn local msize "medsmall"
        }
        else if "`style'" == "jama" {
            sreturn local mcolor "black"
            sreturn local cicolor "black"
            sreturn local msymbol "S"
            sreturn local msize "small"
            sreturn local values "values"
        }
        else if "`style'" == "nejm" {
            sreturn local mcolor "dknavy"
            sreturn local cicolor "dknavy"
            sreturn local cicap "cicap"
            sreturn local msymbol "O"
            sreturn local msize "medium"
            sreturn local values "values"
        }
        else if "`style'" == "bmj" {
            sreturn local mcolor "black"
            sreturn local cicolor "black"
            sreturn local msymbol "S"
            sreturn local msize "small"
            sreturn local cicap "cicap"
            sreturn local values "values"
        }
        else {
            display as error `"style(`style') not recognized; use forest, coef, lancet, jama, nejm, or bmj"'
            exit 198
        }
    }
    local rc = _rc
    set varabbrev `_orig_varabbrev'
    if `rc' exit `rc'
end

program define _eplot_calc_range, sclass
    version 16.0
    local _orig_varabbrev = c(varabbrev)
    set varabbrev off
    capture noisily {
        syntax varlist(numeric min=2 max=2) [if] [in] [, ///
            EXTRALOW(varname numeric) ///
            EXTRAHIgh(varname numeric) ///
        ]

        tokenize `varlist'
        local lowvar `1'
        local highvar `2'

        quietly summarize `lowvar' `if' `in', meanonly
        if r(N) == 0 {
            display as error "no valid confidence intervals to plot"
            exit 2000
        }
        local xmin = r(min)

        quietly summarize `highvar' `if' `in', meanonly
        local xmax = r(max)

        if "`extralow'" != "" {
            quietly summarize `extralow' `if' `in', meanonly
            if r(N) > 0 & r(min) < `xmin' local xmin = r(min)
        }
        if "`extrahigh'" != "" {
            quietly summarize `extrahigh' `if' `in', meanonly
            if r(N) > 0 & r(max) > `xmax' local xmax = r(max)
        }

        local xrange = `xmax' - `xmin'
        if `xrange' == 0 {
            local xrange = abs(`xmax') * 0.1
            if `xrange' == 0 local xrange = 1
        }

        sreturn clear
        sreturn local min "`xmin'"
        sreturn local max "`xmax'"
        sreturn local range "`xrange'"
        sreturn local min_pad = string(`xmin' - 0.05 * `xrange', "%18.0g")
        sreturn local max_pad = string(`xmax' + 0.05 * `xrange', "%18.0g")
    }
    local rc = _rc
    set varabbrev `_orig_varabbrev'
    if `rc' exit `rc'
end

program define _eplot_effect_axis_labels, sclass
    version 16.0
    local _orig_varabbrev = c(varabbrev)
    set varabbrev off
    capture noisily {
        syntax, MIN(real) MAX(real) [XLABel(string asis)]

        sreturn clear
        if trim(`"`xlabel'"') != "" & `"`xlabel'"' != `""""' {
            sreturn local axisopts `"`xlabel'"'
        }
        else {
            _natscale `min' `max' 5
            sreturn local axisopts ///
                `"`r(min)'(`r(delta)')`r(max)', grid glcolor(gs12) glwidth(vthin)"'
        }
    }
    local rc = _rc
    set varabbrev `_orig_varabbrev'
    if `rc' exit `rc'
end

program define _eplot_build_reflines, sclass
    version 16.0
    local _orig_varabbrev = c(varabbrev)
    set varabbrev off
    capture noisily {
        syntax, NULL(real) [XLine(numlist) HORizontal NONULL]

        local cmd ""
        if "`nonull'" == "" {
            if "`horizontal'" != "" {
                local cmd `"xline(`null', lcolor(gs8) lpattern(dash) lwidth(thin))"'
            }
            else {
                local cmd `"yline(`null', lcolor(gs8) lpattern(dash) lwidth(thin))"'
            }
        }

        if "`xline'" != "" {
            foreach val of numlist `xline' {
                if "`horizontal'" != "" {
                    local cmd `"`cmd' xline(`val', lcolor(gs10) lpattern(shortdash))"'
                }
                else {
                    local cmd `"`cmd' yline(`val', lcolor(gs10) lpattern(shortdash))"'
                }
            }
        }

        sreturn clear
        sreturn local cmd `"`cmd'"'
    }
    local rc = _rc
    set varabbrev `_orig_varabbrev'
    if `rc' exit `rc'
end

program define _eplot_build_favors, sclass
    version 16.0
    local _orig_varabbrev = c(varabbrev)
    set varabbrev off
    capture noisily {
        syntax, FAVors(string asis) NULL(real) MIN(real) MAX(real) TOP(real)

        gettoken _fav_left favors : favors, bind
        gettoken _fav_right : favors, bind

        local _fav_x_left = (`min' + `null') / 2
        local _fav_x_right = (`null' + `max') / 2

        local cmd ///
            `"text(`top' `_fav_x_left' `"`_fav_left'"', size(vsmall) color(gs5) placement(c))"'
        local cmd ///
            `"`cmd' text(`top' `_fav_x_right' `"`_fav_right'"', size(vsmall) color(gs5) placement(c))"'

        sreturn clear
        sreturn local cmd `"`cmd'"'
    }
    local rc = _rc
    set varabbrev `_orig_varabbrev'
    if `rc' exit `rc'
end

program define _eplot_value_margin, sclass
    version 16.0
    local _orig_varabbrev = c(varabbrev)
    set varabbrev off
    capture noisily {
        syntax varname, HEADer(string asis) [MINimum(integer 18)]

        tempvar _val_len
        quietly gen double `_val_len' = length(`varlist') if !missing(`varlist')
        quietly summarize `_val_len', meanonly
        local maxlen = cond(r(N) > 0, r(max), 0)

        local header_len = length(`"`header'"')
        if `header_len' > `maxlen' local maxlen = `header_len'

        local right_margin = ceil(`maxlen' * 0.75 + 3)
        if `right_margin' < `minimum' local right_margin = `minimum'

        sreturn clear
        sreturn local right_margin "`right_margin'"
    }
    local rc = _rc
    set varabbrev `_orig_varabbrev'
    if `rc' exit `rc'
end

// =============================================================================
// Helper: Apply coefficient labels
// =============================================================================

program define _eplot_apply_coeflabels
    version 16.0
    local _orig_varabbrev = c(varabbrev)
    set varabbrev off
    capture noisily {
        syntax varname, COEFLabels(string asis)

        local labelvar `varlist'
        local remaining `"`coeflabels'"'

        while `"`remaining'"' != "" {
            gettoken coef remaining : remaining, parse("=")
            local coef = trim("`coef'")

            gettoken eq remaining : remaining, parse("=")

            gettoken label remaining : remaining, parse(" ") bind
            local label = trim(`"`label'"')

            if substr(`"`label'"', 1, 1) == `"""' {
                local label = substr(`"`label'"', 2, length(`"`label'"') - 2)
            }

            quietly replace `labelvar' = `"`label'"' if `labelvar' == "`coef'"
        }
    }
    local rc = _rc
    set varabbrev `_orig_varabbrev'
    if `rc' exit `rc'
end

// =============================================================================
// Helper: Apply keep filter
// =============================================================================

program define _eplot_apply_keep
    version 16.0
    local _orig_varabbrev = c(varabbrev)
    set varabbrev off
    capture noisily {
        syntax varname, KEEP(string asis)

        local labelvar `varlist'

        tempvar tokeep
        quietly gen byte `tokeep' = 0

        foreach pattern of local keep {
            if strpos("`pattern'", "*") > 0 | strpos("`pattern'", "?") > 0 {
                quietly replace `tokeep' = 1 if strmatch(`labelvar', "`pattern'")
            }
            else {
                quietly replace `tokeep' = 1 if `labelvar' == "`pattern'"
            }
        }

        quietly keep if `tokeep'
    }
    local rc = _rc
    set varabbrev `_orig_varabbrev'
    if `rc' exit `rc'
end

// =============================================================================
// Helper: Apply drop filter
// =============================================================================

program define _eplot_apply_drop
    version 16.0
    local _orig_varabbrev = c(varabbrev)
    set varabbrev off
    capture noisily {
        syntax varname, DROP(string asis)

        local labelvar `varlist'

        foreach pattern of local drop {
            if strpos("`pattern'", "*") > 0 | strpos("`pattern'", "?") > 0 {
                quietly drop if strmatch(`labelvar', "`pattern'")
            }
            else {
                quietly drop if `labelvar' == "`pattern'"
            }
        }
    }
    local rc = _rc
    set varabbrev `_orig_varabbrev'
    if `rc' exit `rc'
end

// =============================================================================
// Helper: Apply rename
// =============================================================================

program define _eplot_apply_rename
    version 16.0
    local _orig_varabbrev = c(varabbrev)
    set varabbrev off
    capture noisily {
        syntax varname, REName(string asis)

        local labelvar `varlist'
        local remaining `"`rename'"'

        while `"`remaining'"' != "" {
            gettoken oldname remaining : remaining, parse("=")
            local oldname = trim("`oldname'")

            gettoken eq remaining : remaining, parse("=")

            gettoken newname remaining : remaining, parse(" ") bind
            local newname = trim(`"`newname'"')

            if substr(`"`newname'"', 1, 1) == `"""' {
                local newname = substr(`"`newname'"', 2, length(`"`newname'"') - 2)
            }

            quietly replace `labelvar' = `"`newname'"' if `labelvar' == "`oldname'"
        }
    }
    local rc = _rc
    set varabbrev `_orig_varabbrev'
    if `rc' exit `rc'
end

// =============================================================================
// Helper: Process groups
// =============================================================================

program define _eplot_process_groups, rclass
    version 16.0
    local _orig_varabbrev = c(varabbrev)
    set varabbrev off
    capture noisily {
        syntax varlist(min=4 max=4), GRoups(string asis) [GAP(real 0)]

        tokenize `varlist'
        local posvar `1'
        local labelvar `2'
        local typevar `3'
        local gapflagvar `4'

        local remaining `"`groups'"'
        local n_groups 0
        local group_coefs ""

        while `"`remaining'"' != "" {
            gettoken token remaining : remaining, bind
            local token = trim(`"`token'"')

            if `"`token'"' == "" {
                continue
            }

            if `"`token'"' == "=" {
                gettoken label remaining : remaining, bind
                local label = trim(`"`label'"')

                if substr(`"`label'"', 1, 1) == `"""' {
                    local labellen = length(`"`label'"')
                    local label = substr(`"`label'"', 2, `labellen' - 2)
                }

                local `++n_groups'
                local first_coef : word 1 of `group_coefs'
                local n_group_coefs : word count `group_coefs'
                local last_coef : word `n_group_coefs' of `group_coefs'

                quietly count if `labelvar' == `"`first_coef'"'
                if r(N) > 0 {
                    quietly summarize `posvar' if `labelvar' == `"`first_coef'"', meanonly
                    local header_pos = r(mean) - 0.5

                    local newN = _N + 1
                    quietly set obs `newN'
                    quietly replace `posvar' = `header_pos' in `newN'
                    quietly replace `labelvar' = `"`label'"' in `newN'
                    quietly replace `typevar' = 0 in `newN'
                    quietly replace `gapflagvar' = 0 in `newN'
                }

                if `gap' > 0 & trim(`"`remaining'"') != "" {
                    quietly count if `labelvar' == `"`last_coef'"'
                    if r(N) > 0 {
                        quietly summarize `posvar' if `labelvar' == `"`last_coef'"', meanonly
                        local gap_pos = r(mean) + 0.5

                        local newN = _N + 1
                        quietly set obs `newN'
                        quietly replace `posvar' = `gap_pos' in `newN'
                        quietly replace `labelvar' = "" in `newN'
                        quietly replace `typevar' = 6 in `newN'
                        quietly replace `gapflagvar' = 1 in `newN'
                    }
                }

                local group_coefs ""
            }
            else {
                local group_coefs `"`group_coefs' `token'"'
            }
        }

        return scalar n_groups = `n_groups'
    }
    local rc = _rc
    set varabbrev `_orig_varabbrev'
    if `rc' exit `rc'
end

// =============================================================================
// Helper: Process headers
// =============================================================================

program define _eplot_process_headers, rclass
    version 16.0
    local _orig_varabbrev = c(varabbrev)
    set varabbrev off
    capture noisily {
        syntax varlist(min=3 max=3), HEADers(string asis)

        tokenize `varlist'
        local posvar `1'
        local labelvar `2'
        local typevar `3'

        local remaining `"`headers'"'

        while `"`remaining'"' != "" {
            gettoken ref remaining : remaining, parse("=") bind
            local ref = trim("`ref'")

            if substr("`ref'", 1, 7) == "before(" {
                local ref = substr("`ref'", 8, length("`ref'") - 8)
            }

            gettoken eq remaining : remaining, parse("=")

            gettoken label remaining : remaining, parse(" ") bind
            local label = trim(`"`label'"')

            if substr(`"`label'"', 1, 1) == `"""' {
                local label = substr(`"`label'"', 2, length(`"`label'"') - 2)
            }

            quietly count if `labelvar' == `"`ref'"'
            if r(N) > 0 {
                quietly summarize `posvar' if `labelvar' == `"`ref'"', meanonly
                local header_pos = r(mean) - 0.5

                local newN = _N + 1
                quietly set obs `newN'
                quietly replace `posvar' = `header_pos' in `newN'
                quietly replace `labelvar' = `"`label'"' in `newN'
                quietly replace `typevar' = 0 in `newN'
            }
        }
    }
    local rc = _rc
    set varabbrev `_orig_varabbrev'
    if `rc' exit `rc'
end

// End of eplot.ado
