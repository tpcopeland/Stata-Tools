*! eplot Version 1.3.0  2026/09/02
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

capture program drop eplot
program define eplot, rclass
    version 16.0
    local _orig_varabbrev = c(varabbrev)
    local _dispatched 0
    local _has_results 0
    local _has_table 0
    local _has_pvalues 0
    local _r_N .
    local _r_nmodels .
    local _r_k .
    local _r_cmd ""
    return clear
    set varabbrev off

    capture noisily {
        // Determine mode: data, estimates, matrix, or frame
        _eplot_parse_mode `0'
        local mode "`s(mode)'"
        local _dispatched 1

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
    }
    local rc = _rc

    // A helper may post the analytical payload before returning a graph/save
    // error.  Capture it after the block so the public wrapper does not strand
    // results merely because an optional graph side effect failed.
    if `_dispatched' {
        capture local _r_cmd `"`r(cmd)'"'
        if _rc == 0 {
            capture local _r_N = r(N)
            if _rc == 0 {
                local _has_results 1
                if "`mode'" == "estimates" {
                    capture local _r_nmodels = r(n_models)
                    if _rc local _has_results 0
                }
                capture local _r_k = r(k)
                if _rc local _has_results 0
                tempname _r_table
                capture matrix `_r_table' = r(table)
                local _has_table = (_rc == 0)
                tempname _r_pvalues
                capture matrix `_r_pvalues' = r(pvalues)
                local _has_pvalues = (_rc == 0)
            }
        }
    }

    if `_has_results' {
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

capture program drop _eplot_parse_mode
program define _eplot_parse_mode, sclass
    version 16.0
    local _orig_varabbrev = c(varabbrev)
    set varabbrev off
    capture noisily {
        syntax [anything] [if] [in] [, Matrix(name) FRame(name) *]

        local _mode ""
        if "`matrix'" != "" {
            local _mode "matrix"
        }
        else if "`frame'" != "" {
            local _mode "frame"
        }
        else if `"`anything'"' == "" {
            local _mode "estimates"
        }
        else {
            // Data mode needs at least three leading numeric variables.
            local nwords : word count `anything'
            if `nwords' >= 3 {
                local w1 : word 1 of `anything'
                local w2 : word 2 of `anything'
                local w3 : word 3 of `anything'

                capture confirm numeric variable `w1' `w2' `w3'
                if _rc == 0 local _mode "data"
            }

            if "`_mode'" == "" {
                // Classify the remaining tokens: stored estimates vs variables.
                // "." always denotes the active estimates.
                local _all_est 1
                local _any_est 0
                local _any_var 0
                foreach name of local anything {
                    if "`name'" == "." {
                        local _any_est 1
                        continue
                    }
                    capture estimates dir `name'
                    if _rc local _all_est 0
                    else   local _any_est 1
                    capture confirm variable `name'
                    if _rc == 0 local _any_var 1
                }

                if `_all_est' {
                    local _mode "estimates"
                }
                else if `_any_est' | !`_any_var' {
                    // Route mistyped estimate names to estimates mode so the
                    // public error identifies the missing stored result.
                    local _mode "estimates"
                }
                else {
                    local _mode "data"
                }
            }
        }

        sreturn clear
        sreturn local mode "`_mode'"
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
    local _data_rc 0
    local _has_results 0
    local _has_table 0
    local _has_pvalues 0
    local _r_N .
    local _r_k .
    local _r_cmd ""
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

        capture noisily _eplot_data `estimate' `ll' `ul' `if' `in', `_data_opts'
        local _data_rc = _rc

        capture local _r_N = r(N)
        if _rc == 0 {
            capture local _r_k = r(k)
            if _rc == 0 {
                capture local _r_cmd `"`r(cmd)'"'
                if _rc == 0 {
                    local _has_results 1
                    tempname _r_table
                    capture matrix `_r_table' = r(table)
                    local _has_table = (_rc == 0)
                    tempname _r_pvalues
                    capture matrix `_r_pvalues' = r(pvalues)
                    local _has_pvalues = (_rc == 0)
                }
            }
        }
    }
    local rc = _rc

    local _cleanup_rc = 0
    capture frame change `_orig_frame'
    local _frame_change_rc = _rc
    if `_frame_change_rc' local _cleanup_rc = `_frame_change_rc'
    if `_frame_created' {
        capture frame drop `_workframe'
        local _frame_drop_rc = _rc
        if `_frame_drop_rc' & `_cleanup_rc' == 0 local _cleanup_rc = `_frame_drop_rc'
    }
    if `rc' == 0 & `_cleanup_rc' != 0 local rc = `_cleanup_rc'
    if `rc' == 0 & `_data_rc' != 0 local rc = `_data_rc'

    if `_has_results' {
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

capture program drop _eplot_data
program define _eplot_data, rclass
    version 16.0
    local _orig_varabbrev = c(varabbrev)
    local _side_rc 0
    local _has_table 0
    local _has_pvalues 0
    local _r_N .
    local _r_k .
    local _r_cmd ""
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
            XLine(string asis) ///
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
            INSIGNColor(string) ///
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

        if "`horizontal'" != "" & "`vertical'" != "" {
            display as error "horizontal and vertical may not be combined"
            exit 198
        }
        if "`sort'" != "" & `"`order'"' != "" {
            display as error "sort and order() may not be combined"
            exit 198
        }
        if "`vertical'" != "" & `"`favors'"' != "" {
            display as error "favors() requires horizontal layout"
            exit 198
        }
        if missing(`gap') | `gap' < 0 {
            display as error "gap() must be nonmissing and nonnegative"
            exit 198
        }
        if `dp' < 0 {
            display as error "dp() must be nonnegative"
            exit 198
        }
        if missing(`rescale') | `rescale' == 0 {
            display as error "rescale() must be nonmissing and nonzero"
            exit 198
        }
        if missing(`null') {
            display as error "null() must be a nonmissing number"
            exit 198
        }
        if missing(`boxscale') | `boxscale' <= 0 {
            display as error "boxscale() must be nonmissing and positive"
            exit 198
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

    // Validate every supplied row-type value inside if/in before markout can
    // remove rows whose effect or interval fields are missing.
    if "`type'" != "" {
        capture confirm numeric variable `type'
        if _rc == 0 {
            quietly count if `ifin_ok' & (missing(`type') | ///
                `type' != floor(`type') | !inrange(`type', 0, 6))
        }
        else {
            quietly count if `ifin_ok' & !( ///
                inlist(lower(strtrim(`type')), "effect", "regular", "header", "section", "missing", "reference") | ///
                inlist(lower(strtrim(`type')), "subgroup", "hetinfo", "overall", "blank"))
        }
        if r(N) > 0 {
            display as error "type() contains an unknown row type; use codes 0-6 or a documented string value"
            exit 198
        }
    }
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
            quietly gen double `rowtype' = `type'
        }
        else {
            quietly gen int `rowtype' = .
            quietly replace `rowtype' = 1 if inlist(lower(strtrim(`type')), "effect", "regular")
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

    quietly count if missing(`rowtype') | `rowtype' != floor(`rowtype') | ///
        !inrange(`rowtype', 0, 6)
    if r(N) > 0 {
        display as error "type() contains an unknown row type; use codes 0-6 or a documented string value"
        restore
        exit 198
    }

    quietly count if inlist(`rowtype', 1, 3, 5) & ///
        !missing(`lci') & !missing(`uci') & `lci' > `uci'
    if r(N) > 0 {
        display as error "lower confidence limits may not exceed upper confidence limits"
        restore
        exit 198
    }

    if "`pi'" != "" {
        tokenize `pi'
        local pi_lci_var `1'
        local pi_uci_var `2'
        quietly count if inlist(`rowtype', 1, 3, 5) & ///
            missing(`pi_lci_var') != missing(`pi_uci_var')
        if r(N) > 0 {
            display as error "prediction limits must be supplied as complete lower/upper pairs"
            restore
            exit 198
        }
        quietly count if inlist(`rowtype', 1, 3, 5) & ///
            !missing(`pi_lci_var') & `pi_lci_var' > `pi_uci_var'
        if r(N) > 0 {
            display as error "lower prediction limits may not exceed upper prediction limits"
            restore
            exit 198
        }
    }

    if "`pvalue'" != "" {
        quietly count if inlist(`rowtype', 1, 3, 5) & ///
            !missing(`pvalue') & !inrange(`pvalue', 0, 1)
        if r(N) > 0 {
            display as error "pvalue() must contain values between 0 and 1"
            restore
            exit 198
        }
    }

    // Apply rescale after validating the source interval. A negative factor
    // reverses the endpoints, so swap them to preserve the ll <= ul contract.
    if `rescale' != 1 {
        tempvar unscaled_lci
        quietly gen double `unscaled_lci' = `lci'
        quietly replace `es' = `es' * `rescale'
        if `rescale' > 0 {
            quietly replace `lci' = `lci' * `rescale'
            quietly replace `uci' = `uci' * `rescale'
        }
        else {
            quietly replace `lci' = `uci' * `rescale'
            quietly replace `uci' = `unscaled_lci' * `rescale'
        }
    }

    // Labels.  `label_str' carries the SOURCE row identity until display
    // labels are applied further below: keep()/drop(), order(), groups(), and
    // headers() all key on it, matching the estimates-mode composition rule.
    if "`labels'" != "" {
        quietly gen str244 `label_str' = `labels'
    }
    else {
        quietly gen str244 `label_str' = "Row " + string(`id')
    }

    // Apply keep/drop against the source identities
    if `"`keep'"' != "" {
        _eplot_apply_keep `label_str', keep(`keep')
    }
    if `"`drop'"' != "" {
        _eplot_apply_drop `label_str', drop(`drop')
    }
    if `"`keep'"' != "" | `"`drop'"' != "" {
        quietly count
        if r(N) == 0 {
            display as error "no rows to plot after keep/drop"
            restore
            exit 2000
        }
        quietly count if inlist(`rowtype', 1, 3, 5) & !missing(`es')
        if r(N) == 0 {
            display as error "no effect rows to plot after keep/drop"
            restore
            exit 2000
        }
        local N = _N
        quietly replace `id' = _n
    }

    // Weighted markers must map every plotted effect row to a usable box
    // size; a missing or nonpositive weight silently omits that row's marker
    // while the row remains in r(k), r(table), and its interval layer.
    if "`weights'" != "" & "`nobox'" == "" {
        quietly count if `rowtype' == 1 & !missing(`es') & ///
            (missing(`wt') | `wt' <= 0)
        if r(N) > 0 {
            display as error "weights() must be nonmissing and positive for plotted effect rows"
            restore
            exit 198
        }
    }

    // Sort by effect size if requested
    if "`sort'" != "" {
        // Sort regular effects into their original slots. Non-effect rows
        // retain their positions, including headers, pooled rows, and blanks.
        quietly count if `rowtype' == 1
        if r(N) > 1 {
            tempvar effect_rank target_pos
            tempfile sort_source effect_slots

            quietly save `sort_source'
            quietly keep if `rowtype' == 1
            quietly keep `id'
            quietly sort `id'
            quietly gen long `effect_rank' = _n
            quietly rename `id' `target_pos'
            quietly save `effect_slots'
            quietly use `sort_source', clear

            quietly sort `rowtype' `es' `id'
            quietly by `rowtype': gen long `effect_rank' = _n ///
                if `rowtype' == 1
            quietly merge m:1 `effect_rank' using `effect_slots', ///
                keep(master match) nogen
            quietly replace `target_pos' = `id' if `rowtype' != 1
            quietly sort `target_pos'
        }
    }
    else if `"`order'"' != "" {
        // Apply explicit ordering
        tempvar order_rank
        quietly gen long `order_rank' = .
        local o 0
        local _unmatched ""
        foreach coef of local order {
            local ++o
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

    // ====== Apply display labels (after selection, ordering, and grouping) ======
    // coeflabels() runs LAST so that keep()/drop(), order(), groups(), and
    // headers() all key on the unmodified source identities, exactly as in
    // estimates mode.
    if `"`coeflabels'"' != "" {
        _eplot_apply_coeflabels `label_str', coeflabels(`coeflabels')
    }

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
        quietly gen double `pi_lci' = `pi_lci_var'
        quietly gen double `pi_uci' = `pi_uci_var'
        if "`eform'" != "" {
            quietly replace `pi_lci' = exp(`pi_lci')
            quietly replace `pi_uci' = exp(`pi_uci')
        }
        if `rescale' != 1 {
            tempvar unscaled_pi_lci
            quietly gen double `unscaled_pi_lci' = `pi_lci'
            if `rescale' > 0 {
                quietly replace `pi_lci' = `pi_lci' * `rescale'
                quietly replace `pi_uci' = `pi_uci' * `rescale'
            }
            else {
                quietly replace `pi_lci' = `pi_uci' * `rescale'
                quietly replace `pi_uci' = `unscaled_pi_lci' * `rescale'
            }
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
    // The diamond encodes the confidence interval in its width, so noci must
    // route pooled rows to the interval-free marker branch below.
    local diamond_cmd ""
    if "`nodiamonds'" == "" & "`noci'" == "" {
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
        // nodiamonds or noci: draw markers (and, unless noci, CIs) for pooled
        // effects instead of diamonds
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
    if `"`xline'"' != "" local _xline_opt `"xline(`xline')"'
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
        local graphcmd `"`graphcmd', ylabel(`ylabels', angle(0) labsize(small) nogrid noticks valuelabel)"'
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
        local graphcmd `"`graphcmd' yscale(reverse noline range(`ypad_lo' `ypad_hi'))"'
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
        local _het_text "I-squared = `i2'"
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
        if "`nodiamonds'" == "" & "`noci'" == "" & "`diamond_cmd'" != "" {
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

    // Execute graph.  Keep the analytical payload available when an optional
    // graph/save side effect fails; the public wrapper propagates both.
    capture noisily `graphcmd'
    local _side_rc = _rc

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
            local ++_ri
            matrix `_rtable'[`_ri', 1] = `es'[`i']
            matrix `_rtable'[`_ri', 2] = `lci'[`i']
            matrix `_rtable'[`_ri', 3] = `uci'[`i']
            local _rnm = `label_str'[`i']
            local _rnames `"`_rnames' `"`_rnm'"'"'
        }
        capture matrix rownames `_rtable' = `_rnames'
        if _rc {
            local _generic_names ""
            forvalues _gi = 1/`_ntab' {
                local _generic_names "`_generic_names' row`_gi'"
            }
            matrix rownames `_rtable' = `_generic_names'
        }
        local _has_table 1
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
                local ++_pi
                matrix `_rpvals'[`_pi', 1] = `pvalue'[`i']
                local _pnm = `label_str'[`i']
                local _pnames `"`_pnames' `"`_pnm'"'"'
            }
            capture matrix rownames `_rpvals' = `_pnames'
            if _rc {
                local _generic_names ""
                forvalues _gi = 1/`_npv' {
                    local _generic_names "`_generic_names' row`_gi'"
                }
                matrix rownames `_rpvals' = `_generic_names'
            }
            local _has_pvalues 1
        }
    }

        local _r_N = `N'
        quietly count if `rowtype' == 1
        local _r_k = r(N)
        local _r_cmd `"`graphcmd'"'

        restore
        return scalar N = `_r_N'
        return scalar k = `_r_k'
        return local cmd `"`_r_cmd'"'
        if `_has_table' {
            return matrix table = `_rtable'
        }
        if `_has_pvalues' {
            return matrix pvalues = `_rpvals'
        }
        if `_side_rc' exit `_side_rc'
    }
    local rc = _rc
    set varabbrev `_orig_varabbrev'
    if `rc' exit `rc'
end

// =============================================================================
// Estimates Mode: Plot from stored estimates (single or multi-model)
// =============================================================================

capture program drop _eplot_estimates
program define _eplot_estimates, rclass
    version 16.0
    local _orig_varabbrev = c(varabbrev)
    local _side_rc 0
    local _has_table 0
    local _has_pvalues 0
    local _r_N .
    local _r_nmodels .
    local _r_k .
    local _r_cmd ""
    local _est_hold 0
    local _clear_est 0
    local _restore_needed 0
    local _post_open 0
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
            XLine(string asis) ///
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
            INSIGNColor(string) ///
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
            OFFset(string) ///
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
        // A preset-supplied values is tracked separately so that the
        // multi-model note below reports only options the user asked for.
        local _values_from_style 0
        if "`style'" != "" {
            _eplot_apply_style, style(`"`style'"')
            if "`values'" == "" {
                local values "`s(values)'"
                if "`values'" != "" local _values_from_style 1
            }
            if "`mcolor'" == "" local mcolor "`s(mcolor)'"
            if "`cicolor'" == "" local cicolor "`s(cicolor)'"
            if "`cicap'" == "" local cicap "`s(cicap)'"
            if "`msymbol'" == "" local msymbol "`s(msymbol)'"
            if "`msize'" == "" local msize "`s(msize)'"
        }

        if "`horizontal'" != "" & "`vertical'" != "" {
            display as error "horizontal and vertical may not be combined"
            exit 198
        }
        if "`sort'" != "" & `"`order'"' != "" {
            display as error "sort and order() may not be combined"
            exit 198
        }
        if "`vertical'" != "" & `"`favors'"' != "" {
            display as error "favors() requires horizontal layout"
            exit 198
        }
        if missing(`gap') | `gap' < 0 {
            display as error "gap() must be nonmissing and nonnegative"
            exit 198
        }
        if `dp' < 0 {
            display as error "dp() must be nonnegative"
            exit 198
        }
        if missing(`rescale') | `rescale' == 0 {
            display as error "rescale() must be nonmissing and nonzero"
            exit 198
        }
        if missing(`null') {
            display as error "null() must be a nonmissing number"
            exit 198
        }

    // ====== Parse estimate list ======
    if `"`anything'"' == "" | `"`anything'"' == "." {
        local estlist "."
    }
    else {
        local estlist `"`anything'"'
    }
    local n_models : word count `estlist'

    local _modellabels_supplied = (`"`modellabels'"' != "")
    local _palette_supplied = (`"`palette'"' != "")
    local _legendopts_supplied = (`"`legendopts'"' != "")
    local _offset_supplied = ("`offset'" != "")

    if `_offset_supplied' {
        capture confirm number `offset'
        if _rc {
            display as error "offset() must be numeric"
            exit 198
        }
        local offset = real("`offset'")
        if missing(`offset') {
            display as error "offset() must be a nonmissing number"
            exit 198
        }
    }

    if `n_models' == 1 & (`_modellabels_supplied' | `_palette_supplied' | ///
        `_legendopts_supplied' | `_offset_supplied') {
        display as error "modellabels(), palette(), legendopts(), and offset() require multiple models"
        exit 198
    }
    if `n_models' > 1 & `_modellabels_supplied' {
        local _n_modellabels : word count `modellabels'
        if `_n_modellabels' != `n_models' {
            display as error "modellabels() requires exactly one label per model"
            exit 198
        }
    }
    if `n_models' > 1 & `_palette_supplied' {
        local _n_palette : word count `palette'
        if `_n_palette' != `n_models' {
            display as error "palette() requires exactly one color per model"
            exit 198
        }
    }
    if `_offset_supplied' {
        if `offset' < 0 {
            display as error "offset() must be nonnegative"
            exit 198
        }
    }

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
    if "`vformat'" == "" local vformat "%5.`dp'f"
    if "`offset'" == "" local offset 0.15

    // Default palette for multi-model.  Beyond its cardinality the palette
    // cycles: model m uses color mod(m-1, #colors) + 1.  A user-supplied
    // palette is validated to have exactly one color per model above, so the
    // cycle is a no-op there.
    if "`palette'" == "" {
        local palette "navy cranberry forest_green dkorange purple teal maroon olive_teal"
    }
    local _n_palette_words : word count `palette'

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

    // Normal critical value for estimators that do not post residual df.
    local zcrit = invnormal(1 - (1 - `level'/100)/2)

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
        local _est_hold 1
    }
    else {
        local _clear_est 1
    }

    // Extract "." matrices before any estimates restore
    if `dot_idx' > 0 {
        tempname b_dot V_dot
        capture matrix `b_dot' = e(b)
        if _rc {
            display as error "active estimation results do not contain e(b)"
            exit 498
        }
        capture matrix `V_dot' = e(V)
        if _rc {
            display as error "active estimation results do not contain e(V)"
            exit 498
        }
        local df_dot = .
        capture local df_dot = e(df_r)
        if _rc local df_dot = .
        if !missing(`df_dot') & `df_dot' <= 0 local df_dot = .
    }

    // Auto-detect the effect label from the requested model, not from an
    // unrelated model that happened to be active when eplot was called.
    if `"`effect'"' == "" {
        if "`eform'" == "" {
            local effect "Coefficient (`level'% CI)"
        }
        else {
            local _ecmd ""
            if `n_models' == 1 {
                local est_name : word 1 of `estlist'
                if `dot_idx' == 1 {
                    local _ecmd "`e(cmd)'"
                }
                else {
                    capture estimates restore `est_name'
                    if _rc {
                        display as error `"estimation results '`est_name'' not found"'
                        exit 111
                    }
                    local _ecmd "`e(cmd)'"
                }
            }
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
    }

    // ====== Gather variable labels before preserve (for auto-labeling) ======
    // Build label map: coef_name -> human-readable label
    // Uses variable labels and factor value labels from data in memory
    local _auto_labels ""
    local _n_autolabels 0
    forvalues m = 1/`n_models' {
        local est_name : word `m' of `estlist'
        if `m' == `dot_idx' {
            _eplot_matrix_coefnames, matrix(`b_dot')
            local _colnames `"`s(names)'"'
        }
        else {
            capture estimates restore `est_name'
            if _rc continue
            tempname _btemp
            matrix `_btemp' = e(b)
            _eplot_matrix_coefnames, matrix(`_btemp')
            local _colnames `"`s(names)'"'
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
            local _eqname ""
            if strpos("`_cn'", ":") > 0 {
                local _eqname = substr("`_cn'", 1, strpos("`_cn'", ":") - 1)
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
                continue
            }

            local _label ""
            // Factor variable: try value label first
            if "`_facval'" != "" {
                capture local _vallbl : value label `_purvar'
                if _rc local _vallbl ""
                if "`_vallbl'" != "" {
                    capture local _label : label `_vallbl' `_facval'
                    if _rc local _label ""
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
                capture local _label : variable label `_purvar'
                if _rc local _label ""
            }

            if `"`_label'"' != "" {
                if "`_eqname'" != "" {
                    local _label `"`_eqname': `_label'"'
                }
                local ++_n_autolabels
                local _autokey_`_n_autolabels' `"`_cn'"'
                local _autoval_`_n_autolabels' `"`_label'"'
            }
        }
    }

    // ====== Build combined dataset via postfile ======
    preserve
    local _restore_needed 1
    clear

    tempname posthn
    tempfile postfn
    postfile `posthn' str244 coef_name double(es se lci uci df) byte model_id ///
        using `postfn', replace
    local _post_open 1

    forvalues m = 1/`n_models' {
        local est_name : word `m' of `estlist'

        if `m' == `dot_idx' {
            // Current estimates (already extracted)
            local k = colsof(`b_dot')
            _eplot_matrix_coefnames, matrix(`b_dot')
            local names `"`s(names)'"'
            local model_df = `df_dot'
            local model_crit = `zcrit'
            if !missing(`model_df') {
                local model_crit = invttail(`model_df', (1 - `level'/100) / 2)
            }

            forvalues i = 1/`k' {
                local nm : word `i' of `names'
                local this_var = `V_dot'[`i', `i']
                if missing(`this_var') | `this_var' < 0 {
                    display as error "e(V) contains an invalid variance for coefficient `nm'"
                    exit 498
                }
                local this_se = sqrt(`this_var')
                if `this_se' < 1e-15 continue

                local this_b = `b_dot'[1, `i']
                local this_lci = `this_b' - `model_crit' * `this_se'
                local this_uci = `this_b' + `model_crit' * `this_se'

                post `posthn' ("`nm'") (`this_b') (`this_se') ///
                    (`this_lci') (`this_uci') (`model_df') (`m')
            }
        }
        else {
            // Named estimate
            capture estimates restore `est_name'
            if _rc {
                display as error `"estimation results '`est_name'' not found"'
                exit 111
            }

            tempname bm Vm
            capture matrix `bm' = e(b)
            if _rc {
                display as error `"estimation results '`est_name'' do not contain e(b)"'
                exit 498
            }
            capture matrix `Vm' = e(V)
            if _rc {
                display as error `"estimation results '`est_name'' do not contain e(V)"'
                exit 498
            }
            local model_df = .
            capture local model_df = e(df_r)
            if _rc local model_df = .
            if !missing(`model_df') & `model_df' <= 0 local model_df = .
            local model_crit = `zcrit'
            if !missing(`model_df') {
                local model_crit = invttail(`model_df', (1 - `level'/100) / 2)
            }

            local k = colsof(`bm')
            _eplot_matrix_coefnames, matrix(`bm')
            local names `"`s(names)'"'

            forvalues i = 1/`k' {
                local nm : word `i' of `names'
                local this_var = `Vm'[`i', `i']
                if missing(`this_var') | `this_var' < 0 {
                    display as error `"e(V) for '`est_name'' contains an invalid variance for coefficient `nm'"'
                    exit 498
                }
                local this_se = sqrt(`this_var')
                if `this_se' < 1e-15 continue

                local this_b = `bm'[1, `i']
                local this_lci = `this_b' - `model_crit' * `this_se'
                local this_uci = `this_b' + `model_crit' * `this_se'

                post `posthn' ("`nm'") (`this_b') (`this_se') ///
                    (`this_lci') (`this_uci') (`model_df') (`m')
            }
        }
    }

    postclose `posthn'
    local _post_open 0

    // Return to the caller's dataset before unholding so the hidden e(sample)
    // marker created by _est hold is present when the estimate is restored.
    restore
    local _restore_needed 0

    // Restore original estimation state
    if `_est_hold' {
        capture _est unhold `__est_save'
        local _unhold_rc = _rc
        if `_unhold_rc' {
            display as error "could not restore the active estimation results"
            exit `_unhold_rc'
        }
        local _est_hold 0
    }
    else if `_clear_est' {
        ereturn clear
        local _clear_est 0
    }

    preserve
    local _restore_needed 1
    use `postfn', clear

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
        local _restore_needed 0
        exit 2000
    }

    // Apply rename (before groups/headers so group specs match renamed names)
    if `"`rename'"' != "" {
        _eplot_apply_rename coef_name, rename(`rename')
    }

    // ====== P-values (compute BEFORE eform) ======
    if `n_models' == 1 {
        quietly gen double _pval = .
        quietly replace _pval = 2 * normal(-abs(es / se)) ///
            if se > 0 & !missing(se) & !missing(es) & missing(df)
        quietly replace _pval = 2 * ttail(df, abs(es / se)) ///
            if se > 0 & !missing(se) & !missing(es) & !missing(df)
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
        tempvar unscaled_lci
        quietly {
            gen double `unscaled_lci' = lci
            replace es = es * `rescale'
            if `rescale' > 0 {
                replace lci = lci * `rescale'
                replace uci = uci * `rescale'
            }
            else {
                replace lci = uci * `rescale'
                replace uci = `unscaled_lci' * `rescale'
            }
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
            local ++o
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
    // Capture the display order established by the sort/order/default block
    // above: the bysort on coef_name below reorders rows alphabetically, so
    // without this _base_pos would be assigned in coefficient-name order
    // instead of the intended display order.
    gen long _disp_order = _n

    // Tag first occurrence of each coefficient
    bysort coef_name (_orig_row) : gen byte _coef_tag = (_n == 1)

    // Count unique coefficients
    quietly count if _coef_tag
    local n_coefs = r(N)

    // Create position mapping (avoid nested preserve)
    tempfile fulldata posmap
    quietly save `fulldata'

    keep if _coef_tag
    sort _disp_order
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

        // The presentation options below are single-model only.  They used to
        // be parsed and then silently discarded here; report them instead.
        local _mm_ignored ""
        if "`values'" != "" & !`_values_from_style' {
            local _mm_ignored "`_mm_ignored' values"
        }
        if "`stars'" != "" local _mm_ignored "`_mm_ignored' stars"
        if "`sigcolors'" != "" local _mm_ignored "`_mm_ignored' sigcolors"
        if `"`sigcolor'"' != "" local _mm_ignored "`_mm_ignored' sigcolor()"
        if `"`insigncolor'"' != "" local _mm_ignored "`_mm_ignored' insigncolor()"
        if `"`_mm_ignored'"' != "" {
            display as text "(note:`_mm_ignored' apply to single-model " ///
                "estimates only and are ignored in multi-model mode)"
        }
    }

    // ====== Apply coefficient labels (highest precedence) ======
    // coeflabels() is applied FIRST, while coef_name still holds the original
    // estimation names that coeflabels() keys on. The auto-label pass below
    // then only touches coefficients coeflabels() did not rename, so a
    // user-supplied label always wins over the variable-label default.
    if `"`coeflabels'"' != "" {
        _eplot_apply_coeflabels coef_name, coeflabels(`coeflabels')
    }

    // ====== Auto-label remaining coefficients from variable labels ======
    if `_n_autolabels' > 0 {
        forvalues _ai = 1/`_n_autolabels' {
            quietly replace coef_name = `"`_autoval_`_ai''"' ///
                if coef_name == `"`_autokey_`_ai''"'
        }
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
            local _pal_idx = mod(`m' - 1, `_n_palette_words') + 1
            local mc : word `_pal_idx' of `palette'
            if "`mc'" == "" local mc "navy"

            // CI lines
            if "`noci'" == "" {
                local ++_plot_elem
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
            local ++_plot_elem
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
    if `"`xline'"' != "" local _xline_opt `"xline(`xline')"'
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
    // Keep the analytical payload available when an optional graph/save side
    // effect fails; the public wrapper propagates both.
    capture noisily `graphcmd'
    local _side_rc = _rc

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
                local ++_ri
                matrix `_rtable'[`_ri', 1] = es[`i']
                matrix `_rtable'[`_ri', 2] = lci[`i']
                matrix `_rtable'[`_ri', 3] = uci[`i']
                local _rnm = coef_name[`i']
                local _rnames `"`_rnames' `"`_rnm'"'"'
            }
            capture matrix rownames `_rtable' = `_rnames'
            if _rc {
                local _generic_names ""
                forvalues _gi = 1/`_ntab' {
                    local _generic_names "`_generic_names' row`_gi'"
                }
                matrix rownames `_rtable' = `_generic_names'
            }
            local _has_table 1
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
                local ++_ri
                local _rnm = coef_name[`i']
                local _coef_pos = _base_pos[`i']
                local _rnames `"`_rnames' `"`_rnm'"'"'

                // Fill in values for each model
                forvalues j = 1/`=_N' {
                    if _base_pos[`j'] != `_coef_pos' continue
                    local _mid = model_id[`j']
                    local _col = (`_mid' - 1) * 3 + 1
                    matrix `_rtable'[`_ri', `_col'] = es[`j']
                    matrix `_rtable'[`_ri', `_col' + 1] = lci[`j']
                    matrix `_rtable'[`_ri', `_col' + 2] = uci[`j']
                }
            }
            capture matrix rownames `_rtable' = `_rnames'
            if _rc {
                local _generic_names ""
                forvalues _gi = 1/`_ntab' {
                    local _generic_names "`_generic_names' row`_gi'"
                }
                matrix rownames `_rtable' = `_generic_names'
            }
            local _has_table 1
        }
    }

    // Return p-values vector (estimates mode, single-model)
    if `n_models' == 1 {
        quietly count if _rowtype == 1 & !missing(_pval)
        if r(N) > 0 {
            local _npv = r(N)
            tempname _rpvals
            matrix `_rpvals' = J(`_npv', 1, .)
            matrix colnames `_rpvals' = "pvalue"
            local _pi 0
            local _pnames ""
            forvalues i = 1/`=_N' {
                if _rowtype[`i'] != 1 continue
                if missing(_pval[`i']) continue
                local ++_pi
                matrix `_rpvals'[`_pi', 1] = _pval[`i']
                local _pnm = coef_name[`i']
                local _pnames `"`_pnames' `"`_pnm'"'"'
            }
            capture matrix rownames `_rpvals' = `_pnames'
            if _rc {
                local _generic_names ""
                forvalues _gi = 1/`_npv' {
                    local _generic_names "`_generic_names' row`_gi'"
                }
                matrix rownames `_rpvals' = `_generic_names'
            }
            local _has_pvalues 1
        }
    }

        local _r_N = `n_items'
        local _r_nmodels = `n_models'
        local _r_k = `n_coefs'
        local _r_cmd `"`graphcmd'"'

        restore
        local _restore_needed 0
        return scalar N = `_r_N'
        return scalar n_models = `_r_nmodels'
        return scalar k = `_r_k'
        return local cmd `"`_r_cmd'"'
        if `_has_table' {
            return matrix table = `_rtable'
        }
        if `_has_pvalues' {
            return matrix pvalues = `_rpvals'
        }
        if `_side_rc' exit `_side_rc'
    }
    local rc = _rc
    local _cleanup_rc 0
    if `_post_open' {
        capture postclose `posthn'
        if _rc & !`_cleanup_rc' local _cleanup_rc = _rc
    }
    if `_restore_needed' {
        capture restore
        if _rc & !`_cleanup_rc' local _cleanup_rc = _rc
    }
    if `_est_hold' {
        capture _est unhold `__est_save'
        if _rc & !`_cleanup_rc' local _cleanup_rc = _rc
    }
    if `_clear_est' {
        capture ereturn clear
        if _rc & !`_cleanup_rc' local _cleanup_rc = _rc
    }
    set varabbrev `_orig_varabbrev'
    if !`rc' & `_cleanup_rc' local rc = `_cleanup_rc'
    if `rc' exit `rc'
end

// =============================================================================
// Matrix Mode: Plot from matrix
// =============================================================================

capture program drop _eplot_matrix
program define _eplot_matrix, rclass
    version 16.0
    local _orig_varabbrev = c(varabbrev)
    local _side_rc 0
    local _has_table 0
    local _has_pvalues 0
    local _r_N .
    local _r_k .
    local _r_cmd ""
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
            XLine(string asis) ///
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
            INSIGNColor(string) ///
            STARs ///
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

    if "`horizontal'" != "" & "`vertical'" != "" {
        display as error "horizontal and vertical may not be combined"
        exit 198
    }
    if "`sort'" != "" & `"`order'"' != "" {
        display as error "sort and order() may not be combined"
        exit 198
    }
    if "`vertical'" != "" & `"`favors'"' != "" {
        display as error "favors() requires horizontal layout"
        exit 198
    }

    if `dp' < 0 {
        display as error "dp() must be nonnegative"
        exit 198
    }
    if missing(`rescale') | `rescale' == 0 {
        display as error "rescale() must be nonmissing and nonzero"
        exit 198
    }
    if missing(`null') {
        display as error "null() must be a nonmissing number"
        exit 198
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

    if `ncols' == 3 {
        quietly count if missing(es) | missing(lci) | missing(uci)
        if r(N) > 0 {
            display as error "matrix b, lower-limit, and upper-limit cells must be nonmissing"
            restore
            exit 198
        }
        quietly count if !missing(lci) & !missing(uci) & lci > uci
        if r(N) > 0 {
            display as error "matrix lower confidence limits may not exceed upper confidence limits"
            restore
            exit 198
        }
    }
    else {
        quietly count if missing(es) | missing(se)
        if r(N) > 0 {
            display as error "matrix coefficient and standard-error cells must be nonmissing"
            restore
            exit 198
        }
        quietly count if !missing(se) & se < 0
        if r(N) > 0 {
            display as error "matrix standard errors must be nonnegative"
            restore
            exit 198
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
        tempvar unscaled_lci
        quietly {
            gen double `unscaled_lci' = lci
            replace es = es * `rescale'
            if `rescale' > 0 {
                replace lci = lci * `rescale'
                replace uci = uci * `rescale'
            }
            else {
                replace lci = uci * `rescale'
                replace uci = `unscaled_lci' * `rescale'
            }
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
            local ++o
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
        local graphcmd `"`graphcmd', ylabel(`ylabels', angle(0) labsize(small) nogrid noticks)"'
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
        local graphcmd `"`graphcmd' yscale(reverse noline range(`ypad_lo' `ypad_hi'))"'
    }
    else {
        local graphcmd `"`graphcmd', xlabel(`ylabels', angle(45) labsize(small) nogrid)"'
        local graphcmd `"`graphcmd' xscale(range(`ypad_lo' `ypad_hi'))"'
        local graphcmd `"`graphcmd' xtitle("") ytitle(`"`effect'"') yscale(range(`xmin_pad' `xmax_pad'))"'
        local graphcmd `"`graphcmd' ylabel(`_effect_axis_opts')"'
    }

    local _xline_opt ""
    if `"`xline'"' != "" local _xline_opt `"xline(`xline')"'
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

    // Execute.  Keep the analytical payload available when an optional
    // graph/save side effect fails; the public wrapper propagates both.
    capture noisily `graphcmd'
    local _side_rc = _rc

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
        capture matrix rownames `_rtable' = `_rnames'
        if _rc {
            local _generic_names ""
            forvalues _gi = 1/`n_coefs' {
                local _generic_names "`_generic_names' row`_gi'"
            }
            matrix rownames `_rtable' = `_generic_names'
        }
        local _has_table 1
    }

    // Two-column matrix input supplies standard errors, so p-values are
    // available when stars is requested.  Compute them before eform() above.
    if "`stars'" != "" & `ncols' == 2 {
        quietly count if !missing(_pval)
        local _npv = r(N)
        if `_npv' > 0 {
            tempname _rpvals
            matrix `_rpvals' = J(`_npv', 1, .)
            matrix colnames `_rpvals' = "pvalue"
            local _pi 0
            local _pnames ""
            forvalues i = 1/`=_N' {
                if missing(_pval[`i']) continue
                local ++_pi
                matrix `_rpvals'[`_pi', 1] = _pval[`i']
                local _pnm = coef_name[`i']
                local _pnames `"`_pnames' `"`_pnm'"'"'
            }
            capture matrix rownames `_rpvals' = `_pnames'
            if _rc {
                local _generic_names ""
                forvalues _gi = 1/`_npv' {
                    local _generic_names "`_generic_names' row`_gi'"
                }
                matrix rownames `_rpvals' = `_generic_names'
            }
            local _has_pvalues 1
        }
    }

        local _r_N = `n_coefs'
        local _r_k = `n_coefs'
        local _r_cmd `"`graphcmd'"'

        restore
        return scalar N = `_r_N'
        return scalar k = `_r_k'
        return local cmd `"`_r_cmd'"'
        if `_has_table' {
            return matrix table = `_rtable'
        }
        if `_has_pvalues' {
            return matrix pvalues = `_rpvals'
        }
        if `_side_rc' exit `_side_rc'
    }
    local rc = _rc
    set varabbrev `_orig_varabbrev'
    if `rc' exit `rc'
end

// =============================================================================
// Shared helpers
// =============================================================================

capture program drop _eplot_matrix_coefnames
program define _eplot_matrix_coefnames, sclass
    version 16.0
    local _orig_varabbrev = c(varabbrev)
    set varabbrev off
    capture noisily {
        syntax, Matrix(name)

        local names : colnames `matrix'
        local unique_names : list uniq names
        local n_names : word count `names'
        local n_unique : word count `unique_names'
        if `n_unique' < `n_names' {
            local names : colfullnames `matrix'
        }

        sreturn clear
        sreturn local names `"`names'"'
    }
    local rc = _rc
    set varabbrev `_orig_varabbrev'
    if `rc' exit `rc'
end

capture program drop _eplot_apply_style
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

capture program drop _eplot_calc_range
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

capture program drop _eplot_effect_axis_labels
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
            // _natscale is an undocumented Stata internal (used by graph) that
            // returns "nice" axis ticks in r(min)/r(delta)/r(max), matching
            // Stata's native axis labelling.
            capture _natscale `min' `max' 5
            if _rc == 0 {
                sreturn local axisopts ///
                    `"`r(min)'(`r(delta)')`r(max)', grid glcolor(gs12) glwidth(vthin)"'
            }
            else {
                // The internal is undocumented, so fall back to an even
                // five-interval split if a future Stata major removes it.
                local _span = `max' - `min'
                if missing(`_span') | `_span' <= 0 {
                    local _span = max(abs(`max'), 1)
                }
                local _delta = `_span' / 5
                sreturn local axisopts ///
                    `"`min'(`_delta')`max', grid glcolor(gs12) glwidth(vthin)"'
            }
        }
    }
    local rc = _rc
    set varabbrev `_orig_varabbrev'
    if `rc' exit `rc'
end

capture program drop _eplot_build_reflines
program define _eplot_build_reflines, sclass
    version 16.0
    local _orig_varabbrev = c(varabbrev)
    local _numlist_rc 0
    set varabbrev off
    capture noisily {
        syntax, NULL(real) [XLine(string asis) HORizontal NONULL]

        local cmd ""
        if "`nonull'" == "" {
            if "`horizontal'" != "" {
                local cmd `"xline(`null', lcolor(gs8) lpattern(dash) lwidth(thin))"'
            }
            else {
                local cmd `"yline(`null', lcolor(gs8) lpattern(dash) lwidth(thin))"'
            }
        }

        // xline() accepts "numlist [, line_options]": bare positions get eplot's
        // default reference-line style; a user suboption clause is honored as-is.
        if `"`xline'"' != "" {
            gettoken _xl_pos _xl_rest : xline, parse(",")
            local _xl_supp ""
            if `"`_xl_rest'"' != "" {
                gettoken _xl_comma _xl_supp : _xl_rest, parse(",")
            }
            if `"`_xl_supp'"' == "" local _xl_supp "lcolor(gs10) lpattern(shortdash)"
            capture noisily numlist "`_xl_pos'"
            local _numlist_rc = _rc
            if `_numlist_rc' == 0 {
                local _xl_values "`r(numlist)'"
                foreach val of local _xl_values {
                    if "`horizontal'" != "" {
                        local cmd `"`cmd' xline(`val', `_xl_supp')"'
                    }
                    else {
                        local cmd `"`cmd' yline(`val', `_xl_supp')"'
                    }
                }
            }
        }

        if `_numlist_rc' == 0 {
            sreturn clear
            sreturn local cmd `"`cmd'"'
        }
    }
    local rc = _rc
    if `rc' == 0 & `_numlist_rc' != 0 local rc = `_numlist_rc'
    set varabbrev `_orig_varabbrev'
    if `rc' exit `rc'
end

capture program drop _eplot_build_favors
program define _eplot_build_favors, sclass
    version 16.0
    local _orig_varabbrev = c(varabbrev)
    set varabbrev off
    capture noisily {
        syntax, FAVors(string asis) NULL(real) MIN(real) MAX(real) TOP(real)

        gettoken _fav_left favors : favors, bind
        gettoken _fav_right favors : favors, bind

        local _left_check = trim(subinstr(`"`_fav_left'"', char(34), "", .))
        local _right_check = trim(subinstr(`"`_fav_right'"', char(34), "", .))
        local _fav_rest = trim(`"`favors'"')
        if `"`_left_check'"' == "" | `"`_right_check'"' == "" | ///
            `"`_fav_rest'"' != "" {
            display as error "favors() requires exactly two nonempty labels"
            exit 198
        }

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

capture program drop _eplot_value_margin
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

capture program drop _eplot_apply_coeflabels
program define _eplot_apply_coeflabels, nclass
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
            local eq = trim("`eq'")

            gettoken label remaining : remaining, parse(" ") bind
            local label = trim(`"`label'"')

            if "`coef'" == "" | "`eq'" != "=" | `"`label'"' == "" {
                display as error "coeflabels() requires coefficient = nonempty label specifications"
                exit 198
            }

            if substr(`"`label'"', 1, 1) == `"""' {
                local label = substr(`"`label'"', 2, length(`"`label'"') - 2)
            }

            if `"`label'"' == "" {
                display as error "coeflabels() labels may not be empty"
                exit 198
            }

            quietly count if `labelvar' == "`coef'"
            if r(N) == 0 {
                display as error `"coeflabels() coefficient '`coef'' not found"'
                exit 198
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

capture program drop _eplot_apply_keep
program define _eplot_apply_keep, nclass
    version 16.0
    local _orig_varabbrev = c(varabbrev)
    set varabbrev off
    capture noisily {
        syntax varname, KEEP(string asis)

        local labelvar `varlist'

        tempvar tokeep basename
        quietly gen byte `tokeep' = 0
        quietly gen str244 `basename' = `labelvar'
        quietly replace `basename' = substr(`labelvar', strpos(`labelvar', ":") + 1, .) ///
            if strpos(`labelvar', ":") > 0

        foreach pattern of local keep {
            if strpos("`pattern'", "*") > 0 | strpos("`pattern'", "?") > 0 {
                quietly replace `tokeep' = 1 if ///
                    strmatch(`labelvar', "`pattern'") | strmatch(`basename', "`pattern'")
            }
            else {
                quietly replace `tokeep' = 1 if ///
                    `labelvar' == "`pattern'" | `basename' == "`pattern'"
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

capture program drop _eplot_apply_drop
program define _eplot_apply_drop, nclass
    version 16.0
    local _orig_varabbrev = c(varabbrev)
    set varabbrev off
    capture noisily {
        syntax varname, DROP(string asis)

        local labelvar `varlist'

        tempvar basename
        quietly gen str244 `basename' = `labelvar'
        quietly replace `basename' = substr(`labelvar', strpos(`labelvar', ":") + 1, .) ///
            if strpos(`labelvar', ":") > 0

        foreach pattern of local drop {
            if strpos("`pattern'", "*") > 0 | strpos("`pattern'", "?") > 0 {
                quietly drop if ///
                    strmatch(`labelvar', "`pattern'") | strmatch(`basename', "`pattern'")
            }
            else {
                quietly drop if ///
                    `labelvar' == "`pattern'" | `basename' == "`pattern'"
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

capture program drop _eplot_apply_rename
program define _eplot_apply_rename, nclass
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
            local eq = trim("`eq'")

            gettoken newname remaining : remaining, parse(" ") bind
            local newname = trim(`"`newname'"')

            if "`oldname'" == "" | "`eq'" != "=" | `"`newname'"' == "" {
                display as error "rename() requires oldname = nonempty newname specifications"
                exit 198
            }

            if substr(`"`newname'"', 1, 1) == `"""' {
                local newname = substr(`"`newname'"', 2, length(`"`newname'"') - 2)
            }

            if `"`newname'"' == "" {
                display as error "rename() names may not be empty"
                exit 198
            }

            quietly count if `labelvar' == "`oldname'"
            if r(N) == 0 {
                display as error `"rename() coefficient '`oldname'' not found"'
                exit 198
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

capture program drop _eplot_process_groups
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

        if missing(`gap') | `gap' < 0 {
            display as error "gap() must be nonmissing and nonnegative"
            exit 198
        }

        while `"`remaining'"' != "" {
            gettoken token remaining : remaining, bind
            local token = trim(`"`token'"')

            if `"`token'"' == "" {
                continue
            }

            if `"`token'"' == "=" {
                gettoken label remaining : remaining, bind
                local label = trim(`"`label'"')

                if trim(`"`group_coefs'"') == "" | `"`label'"' == "" {
                    display as error "groups() requires coefficient list = nonempty label specifications"
                    exit 198
                }

                if substr(`"`label'"', 1, 1) == `"""' {
                    local labellen = length(`"`label'"')
                    local label = substr(`"`label'"', 2, `labellen' - 2)
                }

                if `"`label'"' == "" {
                    display as error "groups() labels may not be empty"
                    exit 198
                }

                foreach group_coef of local group_coefs {
                    quietly count if `labelvar' == `"`group_coef'"'
                    if r(N) == 0 {
                        display as error `"groups() coefficient '`group_coef'' not found"'
                        exit 198
                    }
                }

                local ++n_groups
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

        if trim(`"`group_coefs'"') != "" {
            display as error "groups() requires each coefficient list to be followed by = label"
            exit 198
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

capture program drop _eplot_process_headers
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
            local eq = trim("`eq'")

            gettoken label remaining : remaining, parse(" ") bind
            local label = trim(`"`label'"')

            if "`ref'" == "" | "`eq'" != "=" | `"`label'"' == "" {
                display as error "headers() requires coefficient = nonempty label specifications"
                exit 198
            }

            if substr(`"`label'"', 1, 1) == `"""' {
                local label = substr(`"`label'"', 2, length(`"`label'"') - 2)
            }

            if `"`label'"' == "" {
                display as error "headers() labels may not be empty"
                exit 198
            }

            quietly count if `labelvar' == `"`ref'"'
            if r(N) == 0 {
                display as error `"headers() coefficient '`ref'' not found"'
                exit 198
            }
            quietly summarize `posvar' if `labelvar' == `"`ref'"', meanonly
            local header_pos = r(mean) - 0.5

            local newN = _N + 1
            quietly set obs `newN'
            quietly replace `posvar' = `header_pos' in `newN'
            quietly replace `labelvar' = `"`label'"' in `newN'
            quietly replace `typevar' = 0 in `newN'
        }
    }
    local rc = _rc
    set varabbrev `_orig_varabbrev'
    if `rc' exit `rc'
end

// End of eplot.ado
