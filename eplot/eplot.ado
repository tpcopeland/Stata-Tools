*! eplot Version 2.0.0  2026/03/13
*! Unified effect plotting command for forest plots and coefficient plots
*! Author: Timothy Copeland (Karolinska Institutet)
*! Program class: rclass

/*
Unified syntax for effect visualization:

  From data in memory:
    eplot esvar lcivar ucivar [if] [in], [options]

  From stored estimates (single or multi-model):
    eplot [namelist], [options]

  From matrix:
    eplot matrix(matname), [options]

v2.0.0 additions:
  - Multi-model comparison (estimates mode)
  - Values annotation (formatted effect text)
  - Sort/order options
  - Capped CI lines (cicap)
  - Color palette and marker customization
  - Matrix mode implementation

See help eplot for complete documentation
*/

program define eplot, rclass
    version 16.0
    local _varabbrev = c(varabbrev)
    set varabbrev off
    set more off

    // Determine mode: data, estimates, or matrix
    _eplot_parse_mode `0'
    local mode "`s(mode)'"

    if "`mode'" == "data" {
        _eplot_data `0'
        return scalar N = r(N)
        return local cmd `"`r(cmd)'"'
    }
    else if "`mode'" == "estimates" {
        _eplot_estimates `0'
        return scalar N = r(N)
        return scalar n_models = r(n_models)
        return local cmd `"`r(cmd)'"'
    }
    else if "`mode'" == "matrix" {
        _eplot_matrix `0'
        return scalar N = r(N)
        return local cmd `"`r(cmd)'"'
    }
    else {
        set varabbrev `_varabbrev'
        display as error "Could not determine eplot mode"
        exit 198
    }

    set varabbrev `_varabbrev'
end

// =============================================================================
// Mode Detection
// =============================================================================

program define _eplot_parse_mode, sclass
    syntax [anything] [if] [in] [, Matrix(name) *]

    // Matrix mode is explicit
    if "`matrix'" != "" {
        sreturn local mode "matrix"
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
end

// =============================================================================
// Data Mode: Plot from variables in memory
// =============================================================================

program define _eplot_data, rclass
    version 16.0
    set more off

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
        /// Transform
        EFORM ///
        REScale(real 1) ///
        /// Reference lines
        XLine(numlist) ///
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
        /// Layout
        HORizontal ///
        VERTical ///
        SORT ///
        ORDer(string asis) ///
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
        * ///
        ]

    // Parse varlist
    tokenize `varlist'
    local es_var `1'
    local lci_var `2'
    local uci_var `3'

    // Mark sample
    marksample touse
    markout `touse' `es_var' `lci_var' `uci_var'

    // Preserve non-data rows (headers, blanks, etc.) when type() is given
    if "`type'" != "" {
        capture confirm numeric variable `type'
        if _rc == 0 {
            quietly replace `touse' = 1 if inlist(`type', 0, 2, 4, 6)
        }
        else {
            quietly replace `touse' = 1 ///
                if inlist(`type', "header", "missing", "hetinfo", "blank")
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
    tempvar id pos es lci uci wt rowtype label_str

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
            quietly replace `rowtype' = 0 if `type' == "header"
            quietly replace `rowtype' = 2 if `type' == "missing"
            quietly replace `rowtype' = 3 if `type' == "subgroup"
            quietly replace `rowtype' = 4 if `type' == "hetinfo"
            quietly replace `rowtype' = 5 if `type' == "overall"
            quietly replace `rowtype' = 6 if `type' == "blank"
        }
    }
    else {
        quietly gen int `rowtype' = 1
    }

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
        foreach coef of local order {
            local `++o'
            quietly replace `order_rank' = `o' if `label_str' == "`coef'"
        }
        quietly replace `order_rank' = 1000 + `id' if missing(`order_rank')
        sort `order_rank'
    }

    // Calculate positions (reverse order so first obs is at top)
    quietly gen double `pos' = _N - _n + 1

    // Process groups - insert headers and adjust positions
    local n_groups 0
    if `"`groups'"' != "" {
        _eplot_process_groups `pos' `label_str' `rowtype', groups(`groups')
        local n_groups = r(n_groups)
    }

    // Process headers
    if `"`headers'"' != "" {
        _eplot_process_headers `pos' `label_str' `rowtype', headers(`headers')
    }

    // Recalculate positions after any insertions
    sort `pos'
    quietly replace `pos' = _N - _n + 1

    // Update N to include any added header rows
    local N = _N

    // Determine plot range
    quietly summarize `lci' if inlist(`rowtype', 1, 3, 5), meanonly
    if r(N) == 0 {
        display as error "no valid confidence intervals to plot"
        exit 2000
    }
    local xmin = r(min)
    quietly summarize `uci' if inlist(`rowtype', 1, 3, 5), meanonly
    local xmax = r(max)

    local xrange = `xmax' - `xmin'
    if `xrange' == 0 {
        local xrange = abs(`xmax') * 0.1
        if `xrange' == 0 local xrange = 1
    }
    local xmin_pad = `xmin' - 0.05 * `xrange'
    local xmax_pad = `xmax' + 0.05 * `xrange'

    // --- Values annotation ---
    local val_cmd ""
    if "`values'" != "" & "`horizontal'" == "" {
        display as text "(note: values annotation requires horizontal layout)"
    }
    if "`values'" != "" & "`horizontal'" != "" {
        tempvar val_text val_x
        quietly gen str `val_text' = string(`es', "`vformat'") ///
            + " (" + string(`lci', "`vformat'") ///
            + ", " + string(`uci', "`vformat'") + ")" ///
            if inlist(`rowtype', 1, 3, 5) & !missing(`es')

        local val_xpos = `xmax' + `xrange' * 0.12
        quietly gen double `val_x' = `val_xpos' if !missing(`val_text')

        local xmax_pad = `val_xpos' + `xrange' * 0.55
        local val_cmd `"(scatter `pos' `val_x' if !missing(`val_text'), msymbol(none) mlabel(`val_text') mlabpos(3) mlabsize(vsmall) mlabcolor(gs4))"'
    }

    // --- Build graph command ---
    local graphcmd "twoway"

    // --- Confidence interval spikes for regular effects ---
    quietly count if `rowtype' == 1 & !missing(`es')
    if r(N) > 0 & "`noci'" == "" {
        if "`horizontal'" != "" {
            if "`cicap'" != "" {
                local graphcmd `"`graphcmd' (rcap `lci' `uci' `pos' if `rowtype' == 1, horizontal lcolor(`cicolor') lwidth(`ciwidth'))"'
            }
            else {
                local graphcmd `"`graphcmd' (rspike `lci' `uci' `pos' if `rowtype' == 1, horizontal lcolor(`cicolor') lwidth(`ciwidth'))"'
            }
        }
        else {
            if "`cicap'" != "" {
                local graphcmd `"`graphcmd' (rcap `lci' `uci' `pos' if `rowtype' == 1, lcolor(`cicolor') lwidth(`ciwidth'))"'
            }
            else {
                local graphcmd `"`graphcmd' (rspike `lci' `uci' `pos' if `rowtype' == 1, lcolor(`cicolor') lwidth(`ciwidth'))"'
            }
        }
    }

    // --- Markers for regular effects ---
    quietly count if `rowtype' == 1 & !missing(`es')
    if r(N) > 0 {
        if "`nobox'" == "" & "`weights'" != "" {
            // Weighted boxes (scale by boxscale percentage)
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

    // Add diamonds to graph command
    if "`diamond_cmd'" != "" {
        local graphcmd `"`graphcmd' `diamond_cmd'"'
    }

    // Add values annotation
    if "`val_cmd'" != "" {
        local graphcmd `"`graphcmd' `val_cmd'"'
    }

    // --- Reference/null line ---
    local refline_cmd ""
    if "`nonull'" == "" {
        if "`horizontal'" != "" {
            local refline_cmd `"xline(`null', lcolor(gs8) lpattern(dash) lwidth(thin))"'
        }
        else {
            local refline_cmd `"yline(`null', lcolor(gs8) lpattern(dash) lwidth(thin))"'
        }
    }

    // Additional reference lines
    if "`xline'" != "" {
        foreach val of numlist `xline' {
            if "`horizontal'" != "" {
                local refline_cmd `"`refline_cmd' xline(`val', lcolor(gs10) lpattern(shortdash))"'
            }
            else {
                local refline_cmd `"`refline_cmd' yline(`val', lcolor(gs10) lpattern(shortdash))"'
            }
        }
    }

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

    // --- Graph options ---
    local ypad_lo 0
    local ypad_hi = _N + 1
    if "`horizontal'" != "" {
        local graphcmd `"`graphcmd', ylabel(`ylabels', angle(0) labsize(small) nogrid valuelabel)"'
        local graphcmd `"`graphcmd' yscale(reverse range(`ypad_lo' `ypad_hi'))"'
        local graphcmd `"`graphcmd' ytitle("")"'
        local graphcmd `"`graphcmd' xtitle(`"`effect'"')"'
        if "`values'" != "" {
            local graphcmd `"`graphcmd' xscale(range(`xmin_pad' `xmax_pad'))"'
        }
    }
    else {
        local graphcmd `"`graphcmd', xlabel(`ylabels', angle(45) labsize(small) nogrid valuelabel)"'
        local graphcmd `"`graphcmd' xscale(range(`ypad_lo' `ypad_hi'))"'
        local graphcmd `"`graphcmd' xtitle("")"'
        local graphcmd `"`graphcmd' ytitle(`"`effect'"')"'
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
    if `"`note'"' != "" {
        local graphcmd `"`graphcmd' note(`note')"'
    }

    // Scheme
    if "`scheme'" != "" {
        local graphcmd `"`graphcmd' scheme(`scheme')"'
    }

    // Plotregion / graphregion
    if `"`plotregion'"' != "" {
        local graphcmd `"`graphcmd' plotregion(`plotregion')"'
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

    // Execute graph
    `graphcmd'

    // Return results
    return scalar N = `N'
    return local cmd `"`graphcmd'"'

    restore
end

// =============================================================================
// Estimates Mode: Plot from stored estimates (single or multi-model)
// =============================================================================

program define _eplot_estimates, rclass
    version 16.0
    set more off

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
        /// Transform
        EFORM ///
        REScale(real 1) ///
        /// Reference lines
        XLine(numlist) ///
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
        * ///
        ]

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
            local effect "Effect (`level'% CI)"
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
        foreach coef of local order {
            local `++o'
            quietly replace _order_rank = `o' if coef_name == "`coef'"
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
    gen long _base_pos = _N - _n + 1
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

        if `"`groups'"' != "" {
            _eplot_process_groups _base_pos coef_name _rowtype, ///
                groups(`groups')
        }
        if `"`headers'"' != "" {
            _eplot_process_headers _base_pos coef_name _rowtype, ///
                headers(`headers')
        }

        // Recalculate positions after insertions
        sort _base_pos
        quietly replace _base_pos = _N - _n + 1
        quietly replace _plot_pos = _base_pos

        // Update coef count to include headers
        local n_items = _N
    }
    else {
        gen byte _rowtype = 1
        local n_items = `n_coefs'

        // Warn if groups/headers specified in multi-model mode
        if `"`groups'"' != "" | `"`headers'"' != "" {
            display as text "(note: groups() and headers() are ignored " ///
                "in multi-model mode)"
        }
    }

    // ====== Apply coefficient labels (AFTER groups/headers) ======
    if `"`coeflabels'"' != "" {
        _eplot_apply_coeflabels coef_name, coeflabels(`coeflabels')
    }

    // ====== Determine axis range ======
    quietly summarize lci if _rowtype == 1
    local data_xmin = r(min)
    quietly summarize uci if _rowtype == 1
    local data_xmax = r(max)

    local data_range = `data_xmax' - `data_xmin'
    if `data_range' == 0 {
        local data_range = abs(`data_xmax') * 0.1
        if `data_range' == 0 local data_range = 1
    }
    local xmin_pad = `data_xmin' - 0.05 * `data_range'
    local xmax_pad = `data_xmax' + 0.05 * `data_range'

    // ====== Values annotation (single-model only) ======
    local val_cmd ""
    if "`values'" != "" & "`horizontal'" == "" {
        display as text "(note: values annotation requires horizontal layout)"
    }
    if "`values'" != "" & `n_models' == 1 & "`horizontal'" != "" {
        gen str _val_text = string(es, "`vformat'") ///
            + " (" + string(lci, "`vformat'") ///
            + ", " + string(uci, "`vformat'") + ")" ///
            if _rowtype == 1 & !missing(es)

        local val_xpos = `data_xmax' + `data_range' * 0.12
        gen double _val_x = `val_xpos' if !missing(_val_text)

        local xmax_pad = `val_xpos' + `data_range' * 0.55
        local val_cmd `"(scatter _plot_pos _val_x if !missing(_val_text), msymbol(none) mlabel(_val_text) mlabpos(3) mlabsize(vsmall) mlabcolor(gs4))"'
    }

    // ====== Build graph command ======
    local graphcmd "twoway"

    if `n_models' > 1 {
        // --- Multi-model graph ---
        forvalues m = 1/`n_models' {
            local mc : word `m' of `palette'
            if "`mc'" == "" local mc "navy"

            // CI lines
            if "`noci'" == "" {
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
            else {
                // Need placeholder for legend numbering
                local graphcmd `"`graphcmd' (scatteri -999 -999, msymbol(none))"'
            }

            // Markers
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

    // ====== Graph options ======
    local ypad_lo = cond(`n_models' > 1, ///
        0.5 - `offset' * `n_models' / 2, 0)
    local ypad_hi = `n_items' + 1

    if "`horizontal'" != "" {
        local graphcmd `"`graphcmd', ylabel(`ylabels', angle(0) labsize(small) nogrid)"'
        local graphcmd `"`graphcmd' yscale(reverse range(`ypad_lo' `ypad_hi'))"'
        local graphcmd `"`graphcmd' ytitle("") xtitle(`"`effect'"')"'
        if "`values'" != "" & `n_models' == 1 {
            local graphcmd `"`graphcmd' xscale(range(`xmin_pad' `xmax_pad'))"'
        }
    }
    else {
        local graphcmd `"`graphcmd', xlabel(`ylabels', angle(45) labsize(small) nogrid)"'
        local graphcmd `"`graphcmd' xscale(range(`ypad_lo' `ypad_hi'))"'
        local graphcmd `"`graphcmd' xtitle("") ytitle(`"`effect'"')"'
    }

    // Reference line
    local refline_cmd ""
    if "`nonull'" == "" {
        if "`horizontal'" != "" {
            local refline_cmd `"xline(`null', lcolor(gs8) lpattern(dash) lwidth(thin))"'
        }
        else {
            local refline_cmd `"yline(`null', lcolor(gs8) lpattern(dash) lwidth(thin))"'
        }
    }
    if "`xline'" != "" {
        foreach val of numlist `xline' {
            if "`horizontal'" != "" {
                local refline_cmd `"`refline_cmd' xline(`val', lcolor(gs10) lpattern(shortdash))"'
            }
            else {
                local refline_cmd `"`refline_cmd' yline(`val', lcolor(gs10) lpattern(shortdash))"'
            }
        }
    }
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
            // Marker is at plot element 2*m
            local leg_idx = 2 * `m'
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
    if `"`plotregion'"' != "" {
        local graphcmd `"`graphcmd' plotregion(`plotregion')"'
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

    // ====== Execute graph ======
    `graphcmd'

    // ====== Return results ======
    return scalar N = `n_items'
    return scalar n_models = `n_models'
    return local cmd `"`graphcmd'"'

    restore
end

// =============================================================================
// Matrix Mode: Plot from matrix
// =============================================================================

program define _eplot_matrix, rclass
    version 16.0
    set more off

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
        NULL(real -999) ///
        NONULL ///
        NOCI ///
        CICap ///
        /// Display
        EFFect(string) ///
        VALues ///
        VFormat(string) ///
        SORT ///
        ORDer(string asis) ///
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
        * ///
        ]

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
    if "`vformat'" == "" local vformat "%5.2f"
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
            local this_se = `matrix'[`i', 2]
            quietly replace lci = `matrix'[`i', 1] - `crit' * `this_se' in `i'
            quietly replace uci = `matrix'[`i', 1] + `crit' * `this_se' in `i'
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

    // Sort/order
    gen long _orig = _n
    if "`sort'" != "" {
        sort es _orig
    }
    else if `"`order'"' != "" {
        gen long _order_rank = .
        local o 0
        foreach coef of local order {
            local `++o'
            quietly replace _order_rank = `o' if coef_name == "`coef'"
        }
        quietly replace _order_rank = 1000 + _orig if missing(_order_rank)
        sort _order_rank
        drop _order_rank
    }

    // Positions
    gen double _plot_pos = _N - _n + 1

    // Axis range
    quietly summarize lci
    local data_xmin = r(min)
    quietly summarize uci
    local data_xmax = r(max)
    local data_range = `data_xmax' - `data_xmin'
    if `data_range' == 0 {
        local data_range = abs(`data_xmax') * 0.1
        if `data_range' == 0 local data_range = 1
    }
    local xmin_pad = `data_xmin' - 0.05 * `data_range'
    local xmax_pad = `data_xmax' + 0.05 * `data_range'

    // Values annotation
    local val_cmd ""
    if "`values'" != "" & "`horizontal'" == "" {
        display as text "(note: values annotation requires horizontal layout)"
    }
    if "`values'" != "" & "`horizontal'" != "" {
        gen str _val_text = string(es, "`vformat'") ///
            + " (" + string(lci, "`vformat'") ///
            + ", " + string(uci, "`vformat'") + ")"

        local val_xpos = `data_xmax' + `data_range' * 0.12
        gen double _val_x = `val_xpos'

        local xmax_pad = `val_xpos' + `data_range' * 0.55
        local val_cmd `"(scatter _plot_pos _val_x, msymbol(none) mlabel(_val_text) mlabpos(3) mlabsize(vsmall) mlabcolor(gs4))"'
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

    // Markers
    if "`horizontal'" != "" {
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

    // Graph options
    local ypad_lo 0
    local ypad_hi = `n_coefs' + 1
    if "`horizontal'" != "" {
        local graphcmd `"`graphcmd', ylabel(`ylabels', angle(0) labsize(small) nogrid)"'
        local graphcmd `"`graphcmd' yscale(reverse range(`ypad_lo' `ypad_hi'))"'
        local graphcmd `"`graphcmd' ytitle("") xtitle(`"`effect'"')"'
        if "`values'" != "" {
            local graphcmd `"`graphcmd' xscale(range(`xmin_pad' `xmax_pad'))"'
        }
    }
    else {
        local graphcmd `"`graphcmd', xlabel(`ylabels', angle(45) labsize(small) nogrid)"'
        local graphcmd `"`graphcmd' xscale(range(`ypad_lo' `ypad_hi'))"'
        local graphcmd `"`graphcmd' xtitle("") ytitle(`"`effect'"')"'
    }

    // Reference line
    if "`nonull'" == "" {
        if "`horizontal'" != "" {
            local graphcmd `"`graphcmd' xline(`null', lcolor(gs8) lpattern(dash) lwidth(thin))"'
        }
        else {
            local graphcmd `"`graphcmd' yline(`null', lcolor(gs8) lpattern(dash) lwidth(thin))"'
        }
    }
    if "`xline'" != "" {
        foreach val of numlist `xline' {
            if "`horizontal'" != "" {
                local graphcmd `"`graphcmd' xline(`val', lcolor(gs10) lpattern(shortdash))"'
            }
            else {
                local graphcmd `"`graphcmd' yline(`val', lcolor(gs10) lpattern(shortdash))"'
            }
        }
    }

    // Legend off
    local graphcmd `"`graphcmd' legend(off)"'

    // Titles
    if `"`title'"' != "" local graphcmd `"`graphcmd' title(`title')"'
    if `"`subtitle'"' != "" local graphcmd `"`graphcmd' subtitle(`subtitle')"'
    if `"`note'"' != "" local graphcmd `"`graphcmd' note(`note')"'
    if "`scheme'" != "" local graphcmd `"`graphcmd' scheme(`scheme')"'
    if `"`plotregion'"' != "" local graphcmd `"`graphcmd' plotregion(`plotregion')"'
    if `"`graphregion'"' != "" local graphcmd `"`graphcmd' graphregion(`graphregion')"'
    if "`aspect'" != "" local graphcmd `"`graphcmd' aspect(`aspect')"'
    if "`name'" != "" local graphcmd `"`graphcmd' name(`name')"'
    if `"`saving'"' != "" local graphcmd `"`graphcmd' saving(`saving')"'
    if `"`options'"' != "" local graphcmd `"`graphcmd' `options'"'

    // Execute
    `graphcmd'

    // Return
    return scalar N = `n_coefs'
    return local cmd `"`graphcmd'"'

    restore
end

// =============================================================================
// Helper: Apply coefficient labels
// =============================================================================

program define _eplot_apply_coeflabels
    syntax varname, COEFLabels(string asis)

    local labelvar `varlist'

    // Parse coeflabels: coef1 = "label1" coef2 = "label2" ...
    local remaining `"`coeflabels'"'

    while `"`remaining'"' != "" {
        // Get coefficient name
        gettoken coef remaining : remaining, parse("=")
        local coef = trim("`coef'")

        // Remove the = sign
        gettoken eq remaining : remaining, parse("=")

        // Get the label (may be quoted)
        gettoken label remaining : remaining, parse(" ") bind
        local label = trim(`"`label'"')

        // Remove surrounding quotes if present
        if substr(`"`label'"', 1, 1) == `"""' {
            local label = substr(`"`label'"', 2, length(`"`label'"') - 2)
        }

        // Apply the label
        quietly replace `labelvar' = `"`label'"' if `labelvar' == "`coef'"
    }
end

// =============================================================================
// Helper: Apply keep filter
// =============================================================================

program define _eplot_apply_keep
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
end

// =============================================================================
// Helper: Apply drop filter
// =============================================================================

program define _eplot_apply_drop
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
end

// =============================================================================
// Helper: Apply rename
// =============================================================================

program define _eplot_apply_rename
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
end

// =============================================================================
// Helper: Process groups
// =============================================================================

program define _eplot_process_groups, rclass
    syntax varlist(min=3 max=3), GRoups(string asis)

    tokenize `varlist'
    local posvar `1'
    local labelvar `2'
    local typevar `3'

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

            quietly count if `labelvar' == `"`first_coef'"'
            if r(N) > 0 {
                quietly summarize `posvar' if `labelvar' == `"`first_coef'"', meanonly
                local header_pos = r(mean) + 0.5

                local newN = _N + 1
                quietly set obs `newN'
                quietly replace `posvar' = `header_pos' in `newN'
                quietly replace `labelvar' = `"`label'"' in `newN'
                quietly replace `typevar' = 0 in `newN'
            }

            local group_coefs ""
        }
        else {
            local group_coefs `"`group_coefs' `token'"'
        }
    }

    return scalar n_groups = `n_groups'
end

// =============================================================================
// Helper: Process headers
// =============================================================================

program define _eplot_process_headers, rclass
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
            local header_pos = r(mean) + 0.5

            local newN = _N + 1
            quietly set obs `newN'
            quietly replace `posvar' = `header_pos' in `newN'
            quietly replace `labelvar' = `"`label'"' in `newN'
            quietly replace `typevar' = 0 in `newN'
        }
    }
end

// End of eplot.ado
