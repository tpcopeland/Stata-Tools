*! eplot Version 1.0.0  2026/01/09
*! Unified effect plotting command for forest plots and coefficient plots
*! Author: Timothy Copeland (Karolinska Institutet)
*! Program class: rclass

/*
Unified syntax for effect visualization:

  From data in memory:
    eplot esvar lcivar ucivar [if] [in], [options]

  From stored estimates:
    eplot [namelist], [options]

  From matrix:
    eplot matrix(matname), [options]

Required (data mode):
  esvar     - Variable containing effect sizes (point estimates)
  lcivar    - Variable containing lower confidence limits
  ucivar    - Variable containing upper confidence limits

Key options:
  labels(varname)     - Variable containing row labels
  weights(varname)    - Variable for marker sizing
  type(varname)       - Row type (1=effect, 3=subgroup, 5=overall, etc.)
  groups(spec)        - Group effects with labels
  headers(spec)       - Insert section headers
  eform               - Exponentiate (OR, HR, RR)

See help eplot for complete documentation
*/

program define eplot, rclass sortpreserve
    version 16.0
    set varabbrev off

    // Determine mode: data, estimates, or matrix
    // Check if first token looks like a varlist or estimate name
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
        return local cmd `"`r(cmd)'"'
    }
    else if "`mode'" == "matrix" {
        _eplot_matrix `0'
    }
    else {
        display as error "Could not determine eplot mode"
        exit 198
    }
end

// =============================================================================
// Mode Detection
// =============================================================================

program define _eplot_parse_mode, sclass
    // Try to figure out if user is providing data variables or estimate names

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

    // Check if it looks like estimate names (contains stored estimates)
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

    syntax varlist(numeric min=3 max=3) [if] [in] , ///
        [ ///
        /// Data options
        LABels(varname string) ///
        WEIghts(varname numeric) ///
        Type(varname) ///
        SE(varname numeric) ///
        /// Coefficient selection (for compatibility)
        KEEP(string asis) ///
        DROP(string asis) ///
        ORDER(string asis) ///
        /// Labeling
        COEFLabels(string asis) ///
        GRoups(string asis) ///
        HEADers(string asis) ///
        HEADings(string asis) ///
        /// Transform
        EFORM ///
        PERcent ///
        REScale(real 1) ///
        /// Reference lines
        XLine(numlist) ///
        NULL(real -999) ///
        NONULL ///
        /// Confidence intervals
        LEVel(cilevel) ///
        LEVels(numlist) ///
        NOCI ///
        /// Display
        NOSTATS ///
        NOWT ///
        NONames ///
        DP(integer 2) ///
        EFFect(string) ///
        FAVours(string asis) ///
        /// Layout
        LCols(varlist) ///
        RCols(varlist) ///
        SPacing(real 1.5) ///
        TEXTSize(real 100) ///
        ASText(real 50) ///
        HORizontal ///
        VERTical ///
        /// Box/marker options
        BOXScale(real 100) ///
        NOBOX ///
        NODIamonds ///
        /// Graph options
        TItle(string asis) ///
        SUBtitle(string asis) ///
        NOTE(string asis) ///
        NAME(string) ///
        SAVing(string asis) ///
        SCHEME(string) ///
        * ///
        ]

    // Parse varlist
    tokenize `varlist'
    local es_var `1'
    local lci_var `2'
    local uci_var `3'

    // Mark sample
    marksample touse
    markout `touse' `es_var' `lci_var' `uci_var', strok

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

    // Null line default
    if `null' == -999 {
        local null = cond("`eform'" != "", 1, 0)
    }

    // Effect label default
    if `"`effect'"' == "" {
        if "`eform'" != "" {
            local effect "Effect (95% CI)"
        }
        else {
            local effect "Estimate (95% CI)"
        }
    }

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

    // Apply rescale
    if `rescale' != 1 {
        quietly replace `es' = `es' * `rescale'
        quietly replace `lci' = `lci' * `rescale'
        quietly replace `uci' = `uci' * `rescale'
    }

    // Apply eform transformation
    if "`eform'" != "" {
        quietly replace `es' = exp(`es')
        quietly replace `lci' = exp(`lci')
        quietly replace `uci' = exp(`uci')
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
        // Check if numeric or string
        capture confirm numeric variable `type'
        if _rc == 0 {
            quietly gen int `rowtype' = `type'
        }
        else {
            // String type - convert
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
        // Default: all are regular effects
        quietly gen int `rowtype' = 1
    }

    // Labels
    if "`labels'" != "" {
        quietly gen str244 `label_str' = `labels'
    }
    else {
        // Generate default labels
        quietly gen str244 `label_str' = "Row " + string(`id')
    }

    // Apply custom coefficient labels
    if `"`coeflabels'"' != "" {
        _eplot_apply_coeflabels `label_str', coeflabels(`coeflabels')
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

    // Determine plot range
    quietly summarize `lci' if inlist(`rowtype', 1, 3, 5), meanonly
    local xmin = r(min)
    quietly summarize `uci' if inlist(`rowtype', 1, 3, 5), meanonly
    local xmax = r(max)

    // Add buffer
    local xrange = `xmax' - `xmin'
    local xmin = `xmin' - 0.05 * `xrange'
    local xmax = `xmax' + 0.05 * `xrange'

    // Build graph command
    local graphcmd ""

    // Determine axes based on orientation
    if "`horizontal'" != "" {
        local xax "x"
        local yax "y"
    }
    else {
        local xax "y"
        local yax "x"
    }

    // --- Confidence interval spikes for regular effects ---
    local ci_cmd ""
    quietly count if `rowtype' == 1 & !missing(`es')
    if r(N) > 0 & "`noci'" == "" {
        if "`horizontal'" != "" {
            local ci_cmd `"(rspike `lci' `uci' `pos' if `rowtype' == 1, horizontal lcolor(navy) lwidth(medium))"'
        }
        else {
            local ci_cmd `"(rspike `lci' `uci' `pos' if `rowtype' == 1, lcolor(navy) lwidth(medium))"'
        }
    }

    // --- Markers for regular effects ---
    local marker_cmd ""
    quietly count if `rowtype' == 1 & !missing(`es')
    if r(N) > 0 {
        if "`nobox'" == "" & "`weights'" != "" {
            // Weighted boxes
            tempvar boxsize
            quietly summarize `wt' if `rowtype' == 1, meanonly
            quietly gen double `boxsize' = sqrt(`wt'/r(max)) * 0.5 * (`boxscale'/100)
            if "`horizontal'" != "" {
                local marker_cmd `"(scatter `pos' `es' if `rowtype' == 1 [aw=`wt'], msymbol(square) mcolor(navy) msize(*0.8))"'
            }
            else {
                local marker_cmd `"(scatter `es' `pos' if `rowtype' == 1 [aw=`wt'], msymbol(square) mcolor(navy) msize(*0.8))"'
            }
        }
        else {
            // Unweighted markers
            if "`horizontal'" != "" {
                local marker_cmd `"(scatter `pos' `es' if `rowtype' == 1, msymbol(O) mcolor(navy) msize(medium))"'
            }
            else {
                local marker_cmd `"(scatter `es' `pos' if `rowtype' == 1, msymbol(O) mcolor(navy) msize(medium))"'
            }
        }
    }

    // --- Diamonds for pooled effects (subgroup and overall) ---
    local diamond_cmd ""
    if "`nodiamonds'" == "" {
        // Create diamond coordinates for pooled effects
        quietly count if inlist(`rowtype', 3, 5) & !missing(`es')
        if r(N) > 0 {
            local diam_height = 0.3

            // Create diamond line coordinates
            tempvar diam_lx1 diam_ly1 diam_lx2 diam_ly2

            quietly {
                // Line 1: left point to top point
                gen double `diam_lx1' = `lci' if inlist(`rowtype', 3, 5)
                gen double `diam_ly1' = `pos' if inlist(`rowtype', 3, 5)
                gen double `diam_lx2' = `es' if inlist(`rowtype', 3, 5)
                gen double `diam_ly2' = `pos' + `diam_height' if inlist(`rowtype', 3, 5)
            }

            // Draw diamonds using pcspike - draw all diamond lines at once
            // For simplicity, just draw the diamond outline for overall effects
            if "`horizontal'" != "" {
                // For horizontal: x is effect, y is position
                // Overall diamond (black) - 4 lines to form diamond
                local diamond_cmd `"`diamond_cmd' (pcspike `pos' `lci' `diam_ly2' `es' if `rowtype' == 5, lcolor(black) lwidth(medthick))"'
                local diamond_cmd `"`diamond_cmd' (pcspike `diam_ly2' `es' `pos' `uci' if `rowtype' == 5, lcolor(black) lwidth(medthick))"'
                tempvar diam_ly3
                quietly gen double `diam_ly3' = `pos' - `diam_height' if inlist(`rowtype', 3, 5)
                local diamond_cmd `"`diamond_cmd' (pcspike `pos' `uci' `diam_ly3' `es' if `rowtype' == 5, lcolor(black) lwidth(medthick))"'
                local diamond_cmd `"`diamond_cmd' (pcspike `diam_ly3' `es' `pos' `lci' if `rowtype' == 5, lcolor(black) lwidth(medthick))"'

                // Subgroup diamond (maroon)
                local diamond_cmd `"`diamond_cmd' (pcspike `pos' `lci' `diam_ly2' `es' if `rowtype' == 3, lcolor(maroon) lwidth(medthick))"'
                local diamond_cmd `"`diamond_cmd' (pcspike `diam_ly2' `es' `pos' `uci' if `rowtype' == 3, lcolor(maroon) lwidth(medthick))"'
                local diamond_cmd `"`diamond_cmd' (pcspike `pos' `uci' `diam_ly3' `es' if `rowtype' == 3, lcolor(maroon) lwidth(medthick))"'
                local diamond_cmd `"`diamond_cmd' (pcspike `diam_ly3' `es' `pos' `lci' if `rowtype' == 3, lcolor(maroon) lwidth(medthick))"'
            }
            else {
                // For vertical: y is effect, x is position
                local diamond_cmd `"`diamond_cmd' (pcspike `lci' `pos' `es' `diam_ly2' if `rowtype' == 5, lcolor(black) lwidth(medthick))"'
                local diamond_cmd `"`diamond_cmd' (pcspike `es' `diam_ly2' `uci' `pos' if `rowtype' == 5, lcolor(black) lwidth(medthick))"'
                tempvar diam_ly3
                quietly gen double `diam_ly3' = `pos' - `diam_height' if inlist(`rowtype', 3, 5)
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

    // --- Additional reference lines ---
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

        // Skip blank rows
        if `this_type' == 6 continue

        // Format: position "label"
        // Bold for headers and overall
        if inlist(`this_type', 0, 5) {
            local this_label `"{bf:`this_label'}"'
        }

        local ylabels `"`ylabels' `this_pos' `"`this_label'"'"'
    }

    // --- Build final graph command ---
    local graphcmd `"twoway"'

    // Add plot elements
    if "`ci_cmd'" != "" {
        local graphcmd `"`graphcmd' `ci_cmd'"'
    }
    if "`marker_cmd'" != "" {
        local graphcmd `"`graphcmd' `marker_cmd'"'
    }
    if "`diamond_cmd'" != "" {
        local graphcmd `"`graphcmd' `diamond_cmd'"'
    }

    // Graph options
    if "`horizontal'" != "" {
        local graphcmd `"`graphcmd', ylabel(`ylabels', angle(0) labsize(small) nogrid valuelabel)"'
        local graphcmd `"`graphcmd' yscale(reverse)"'
        local graphcmd `"`graphcmd' ytitle("")"'
        local graphcmd `"`graphcmd' xtitle(`"`effect'"')"'
    }
    else {
        local graphcmd `"`graphcmd', xlabel(`ylabels', angle(45) labsize(small) nogrid valuelabel)"'
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
// Estimates Mode: Plot from stored estimates
// =============================================================================

program define _eplot_estimates, rclass
    version 16.0

    syntax [anything] [, ///
        /// Coefficient selection
        KEEP(string asis) ///
        DROP(string asis) ///
        ORDER(string asis) ///
        REName(string asis) ///
        /// Labeling
        COEFLabels(string asis) ///
        GRoups(string asis) ///
        HEADers(string asis) ///
        HEADings(string asis) ///
        EQLabels(string asis) ///
        /// Transform
        EFORM ///
        PERcent ///
        REScale(real 1) ///
        /// Reference lines
        XLine(numlist) ///
        NULL(real -999) ///
        NONULL ///
        /// Confidence intervals
        LEVel(cilevel) ///
        NOCI ///
        /// Display
        DP(integer 2) ///
        EFFect(string) ///
        /// Layout
        HORizontal ///
        VERTical ///
        /// Graph options
        TItle(string asis) ///
        SUBtitle(string asis) ///
        NOTE(string asis) ///
        NAME(string) ///
        SAVing(string asis) ///
        SCHEME(string) ///
        * ///
        ]

    // Default to current estimates
    if `"`anything'"' == "" | `"`anything'"' == "." {
        local anything "."
    }

    // Set defaults
    if "`horizontal'" == "" & "`vertical'" == "" {
        local horizontal "horizontal"
    }
    if `"`headings'"' != "" & `"`headers'"' == "" {
        local headers `"`headings'"'
    }
    if "`level'" == "" {
        local level = c(level)
    }

    // Null line default
    if `null' == -999 {
        local null = cond("`eform'" != "", 1, 0)
    }

    // Effect label default
    if `"`effect'"' == "" {
        if "`eform'" != "" {
            local effect "Effect (`level'% CI)"
        }
        else {
            local effect "Coefficient (`level'% CI)"
        }
    }

    // Get estimates
    if "`anything'" == "." {
        // Use current estimates
        tempname b V
        matrix `b' = e(b)
        matrix `V' = e(V)
    }
    else {
        // Use stored estimates
        tempname ecurrent
        _est hold `ecurrent', restore nullok

        quietly estimates restore `anything'

        tempname b V
        matrix `b' = e(b)
        matrix `V' = e(V)

        _est unhold `ecurrent'
    }

    // Get coefficient names
    local names : colnames `b'
    local eqs : coleq `b'
    local k = colsof(`b')

    // Calculate confidence intervals
    local crit = invnormal(1 - (1 - `level'/100)/2)

    // Create temporary dataset
    preserve
    clear
    quietly set obs `k'

    tempvar id coef se lci uci pos label_str rowtype

    quietly gen long `id' = _n
    quietly gen str244 `label_str' = ""
    quietly gen double `coef' = .
    quietly gen double `se' = .
    quietly gen double `lci' = .
    quietly gen double `uci' = .
    quietly gen int `rowtype' = 1

    // Fill in data
    forvalues i = 1/`k' {
        local nm : word `i' of `names'
        local eq : word `i' of `eqs'

        quietly replace `label_str' = "`nm'" in `i'
        quietly replace `coef' = `b'[1, `i'] in `i'
        quietly replace `se' = sqrt(`V'[`i', `i']) in `i'
        quietly replace `lci' = `coef' - `crit' * `se' in `i'
        quietly replace `uci' = `coef' + `crit' * `se' in `i'
    }

    // Apply keep/drop
    if `"`keep'"' != "" {
        _eplot_apply_keep `label_str', keep(`keep')
    }
    if `"`drop'"' != "" {
        _eplot_apply_drop `label_str', drop(`drop')
    }

    // Check we have observations left
    quietly count
    if r(N) == 0 {
        display as error "no coefficients to plot after keep/drop"
        exit 2000
    }

    // Apply rename
    if `"`rename'"' != "" {
        _eplot_apply_rename `label_str', rename(`rename')
    }

    // Apply custom labels
    if `"`coeflabels'"' != "" {
        _eplot_apply_coeflabels `label_str', coeflabels(`coeflabels')
    }

    // Apply rescale
    if `rescale' != 1 {
        quietly replace `coef' = `coef' * `rescale'
        quietly replace `lci' = `lci' * `rescale'
        quietly replace `uci' = `uci' * `rescale'
    }

    // Apply eform transformation
    if "`eform'" != "" {
        quietly replace `coef' = exp(`coef')
        quietly replace `lci' = exp(`lci')
        quietly replace `uci' = exp(`uci')
    }

    // Calculate positions
    quietly gen double `pos' = _N - _n + 1

    // Process groups
    if `"`groups'"' != "" {
        _eplot_process_groups `pos' `label_str' `rowtype', groups(`groups')
    }

    // Process headers
    if `"`headers'"' != "" {
        _eplot_process_headers `pos' `label_str' `rowtype', headers(`headers')
    }

    // Recalculate positions
    sort `pos'
    quietly replace `pos' = _N - _n + 1

    // Build graph
    local N = _N

    // Reference line
    local refline_cmd ""
    if "`nonull'" == "" {
        if "`horizontal'" != "" {
            local refline_cmd `"xline(`null', lcolor(gs8) lpattern(dash))"'
        }
        else {
            local refline_cmd `"yline(`null', lcolor(gs8) lpattern(dash))"'
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

    // Y-axis labels
    local ylabels ""
    forvalues i = 1/`N' {
        local this_pos = `pos'[`i']
        local this_label = `label_str'[`i']
        local this_type = `rowtype'[`i']

        if `this_type' == 6 continue

        if inlist(`this_type', 0, 5) {
            local this_label `"{bf:`this_label'}"'
        }

        local ylabels `"`ylabels' `this_pos' `"`this_label'"'"'
    }

    // Build graph command
    if "`horizontal'" != "" {
        if "`noci'" == "" {
            local graphcmd `"twoway (rspike `lci' `uci' `pos' if `rowtype' == 1, horizontal lcolor(navy) lwidth(medium))"'
            local graphcmd `"`graphcmd' (scatter `pos' `coef' if `rowtype' == 1, msymbol(O) mcolor(navy) msize(medium))"'
        }
        else {
            local graphcmd `"twoway (scatter `pos' `coef' if `rowtype' == 1, msymbol(O) mcolor(navy) msize(medium))"'
        }
        local graphcmd `"`graphcmd', ylabel(`ylabels', angle(0) labsize(small) nogrid)"'
        local graphcmd `"`graphcmd' yscale(reverse) ytitle("") xtitle(`"`effect'"')"'
    }
    else {
        if "`noci'" == "" {
            local graphcmd `"twoway (rspike `lci' `uci' `pos' if `rowtype' == 1, lcolor(navy) lwidth(medium))"'
            local graphcmd `"`graphcmd' (scatter `coef' `pos' if `rowtype' == 1, msymbol(O) mcolor(navy) msize(medium))"'
        }
        else {
            local graphcmd `"twoway (scatter `coef' `pos' if `rowtype' == 1, msymbol(O) mcolor(navy) msize(medium))"'
        }
        local graphcmd `"`graphcmd', xlabel(`ylabels', angle(45) labsize(small) nogrid)"'
        local graphcmd `"`graphcmd' xtitle("") ytitle(`"`effect'"')"'
    }

    // Reference lines
    if "`refline_cmd'" != "" {
        local graphcmd `"`graphcmd' `refline_cmd'"'
    }

    // Legend off
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

    // Execute
    `graphcmd'

    // Return
    return scalar N = `N'
    return local cmd `"`graphcmd'"'

    restore
end

// =============================================================================
// Matrix Mode: Plot from matrix
// =============================================================================

program define _eplot_matrix, rclass
    version 16.0

    syntax , Matrix(name) [ * ]

    display as error "Matrix mode not yet implemented in version 1.0"
    display as text "Please use data mode or estimates mode"
    exit 199
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

    // Parse keep list
    foreach pattern of local keep {
        // Handle wildcards
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

    // Parse drop list
    foreach pattern of local drop {
        // Handle wildcards
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

    // Parse rename: old1 = new1 old2 = new2 ...
    local remaining `"`rename'"'

    while `"`remaining'"' != "" {
        // Get old name
        gettoken oldname remaining : remaining, parse("=")
        local oldname = trim("`oldname'")

        // Remove the = sign
        gettoken eq remaining : remaining, parse("=")

        // Get new name
        gettoken newname remaining : remaining, parse(" ") bind
        local newname = trim(`"`newname'"')

        // Remove quotes if present
        if substr(`"`newname'"', 1, 1) == `"""' {
            local newname = substr(`"`newname'"', 2, length(`"`newname'"') - 2)
        }

        // Apply
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

    // Parse groups: coef1 coef2 = "Group Label" coef3 coef4 = "Group 2" ...
    local remaining `"`groups'"'
    local n_groups 0

    while `"`remaining'"' != "" {
        local `++n_groups'
        local group_coefs ""

        // Collect coefficients until we hit =
        while 1 {
            gettoken token remaining : remaining, parse("=") bind
            local token = trim("`token'")

            if "`token'" == "=" {
                break
            }
            if "`token'" == "" {
                continue, break
            }

            local group_coefs `group_coefs' `token'
        }

        // Get the label
        gettoken label remaining : remaining, parse(" ") bind
        local label = trim(`"`label'"')

        // Remove quotes
        if substr(`"`label'"', 1, 1) == `"""' {
            local label = substr(`"`label'"', 2, length(`"`label'"') - 2)
        }

        // Find position for group header (before first coefficient in group)
        local first_coef : word 1 of `group_coefs'
        quietly summarize `posvar' if `labelvar' == "`first_coef'", meanonly
        if r(N) > 0 {
            local header_pos = r(mean) + 0.5

            // Insert header row
            local newN = _N + 1
            quietly set obs `newN'
            quietly replace `posvar' = `header_pos' in `newN'
            quietly replace `labelvar' = "`label'" in `newN'
            quietly replace `typevar' = 0 in `newN'
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

    // Parse headers: before(coef1) = "Header" before(coef2) = "Header 2" ...
    // Or simpler: coef1 = "Header" (header appears before coef1)
    local remaining `"`headers'"'

    while `"`remaining'"' != "" {
        // Get coefficient reference
        gettoken ref remaining : remaining, parse("=") bind
        local ref = trim("`ref'")

        // Check for before() syntax
        if substr("`ref'", 1, 7) == "before(" {
            local ref = substr("`ref'", 8, length("`ref'") - 8)
        }

        // Remove = sign
        gettoken eq remaining : remaining, parse("=")

        // Get label
        gettoken label remaining : remaining, parse(" ") bind
        local label = trim(`"`label'"')

        // Remove quotes
        if substr(`"`label'"', 1, 1) == `"""' {
            local label = substr(`"`label'"', 2, length(`"`label'"') - 2)
        }

        // Find position
        quietly summarize `posvar' if `labelvar' == "`ref'", meanonly
        if r(N) > 0 {
            local header_pos = r(mean) + 0.5

            // Insert header row
            local newN = _N + 1
            quietly set obs `newN'
            quietly replace `posvar' = `header_pos' in `newN'
            quietly replace `labelvar' = "`label'" in `newN'
            quietly replace `typevar' = 0 in `newN'
        }
    }
end

// End of eplot.ado
