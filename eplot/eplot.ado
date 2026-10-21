*! eplot Version 1.0.1  2026/10/20
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
  - logscale: logarithmic effect axis with multiplicative padding
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
    // results merely because an optional graph side effect failed.  Test for
    // each result by name: r(N) of an absent result evaluates to missing and
    // matrix X = r(name) of an absent matrix succeeds, so capture alone
    // would forward phantom results on error paths.
    if `_dispatched' {
        local _rsc : r(scalars)
        local _rmc : r(macros)
        local _rmt : r(matrices)
        local _need_sc "N k"
        if "`mode'" == "estimates" local _need_sc "N k n_models"
        local _miss_sc : list _need_sc - _rsc
        if "`_miss_sc'" == "" & `: list posof "cmd" in _rmc' {
            local _has_results 1
            local _r_cmd `"`r(cmd)'"'
            local _r_N = r(N)
            local _r_k = r(k)
            if "`mode'" == "estimates" local _r_nmodels = r(n_models)
            if `: list posof "table" in _rmt' {
                tempname _r_table
                matrix `_r_table' = r(table)
                local _has_table 1
            }
            if `: list posof "pvalues" in _rmt' {
                tempname _r_pvalues
                matrix `_r_pvalues' = r(pvalues)
                local _has_pvalues 1
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

    // The sclass helpers' s() results are internal: eplot posts r() only.
    sreturn clear
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
        // An in range belongs to the frame() source, so frame mode is decided
        // before syntax checks the range against the caller's dataset.
        local _input `"`0'"'
        capture syntax [anything(everything)] [, Matrix(name) FRame(name) *]
        local _frame_first = (_rc == 0 & "`frame'" != "" & "`matrix'" == "")
        local 0 `"`_input'"'
        if !`_frame_first' {
            syntax [anything] [if] [in] [, Matrix(name) FRame(name) *]
        }

        // matrix() and frame() each name the input; with both, frame() would
        // otherwise reach twoway as an unknown option after the plot is
        // computed.
        if "`matrix'" != "" & "`frame'" != "" {
            display as error "matrix() and frame() may not be combined"
            exit 198
        }

        local _mode ""
        if `_frame_first' {
            local _mode "frame"
        }
        else if "`matrix'" != "" {
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
                if _rc == 0 {
                    local _mode "data"
                    // Data mode takes precedence (documented), but a call
                    // whose names are all stored estimates too is named, so
                    // the choice is never silent.
                    local _clash 1
                    foreach _w in `w1' `w2' `w3' {
                        capture estimates dir `_w'
                        if _rc local _clash 0
                    }
                    if `_clash' {
                        display as text "(note: `w1' `w2' `w3' are numeric variables and also stored estimates;"
                        display as text "  plotted as data, as {bf:Mode detection} in {help eplot} describes)"
                    }
                }
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
    local _fa_global 0
    local _data_rc 0
    local _data_ran 0
    set varabbrev off

    capture noisily {
        // Copy and enter the source frame before the full parse: syntax checks
        // an in range against the current dataset, which must be the source.
        local _input `"`0'"'
        syntax [anything(everything)] , FRame(name) [*]
        capture confirm frame `frame'
        if _rc {
            display as error "frame(`frame') not found"
            exit 111
        }
        // export() into the source frame would replace the input mid-run.
        local 0 `", `options'"'
        capture syntax [, EXPort(string) *]
        if _rc == 0 & `"`export'"' != "" {
            gettoken _expfr : export, parse(",")
            if strtrim(`"`_expfr'"') == "`frame'" {
                display as error "export() may not name the frame() source"
                exit 198
            }
            // The work frame is current from here on, so the caller's
            // frame is checked now.
            if strtrim(`"`_expfr'"') == "`_orig_frame'" {
                display as error "export() may not name the current frame"
                exit 198
            }
        }
        tempname _workframe
        frame copy `frame' `_workframe'
        local _frame_created 1
        frame change `_workframe'
        // A characteristic copied from the source frame claims nothing.
        char _dta[_eplot_frameauto]

        local 0 `"`_input'"'
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

        if "`estimate'" == "" local estimate "estimate"
        if "`ll'" == "" local ll "ll"
        if "`ul'" == "" local ul "ul"

        if "`type'" != "" & "`rowtype'" != "" {
            display as error "specify only one of type() or rowtype()"
            exit 198
        }

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
            // An auto-detected column the user never named may turn out to
            // be something else; data mode then ignores it with a note.
            if "`type'" != "" local _frame_auto "`_frame_auto' type"
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
            if "`weights'" != "" local _frame_auto "`_frame_auto' weights"
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
        // The frame columns used without being named reach data mode
        // through a characteristic of eplot's own work frame, keyed to a
        // token made for this call and held in a global that is cleared on
        // every exit, so a characteristic set by hand never matches.
        if "`_frame_auto'" != "" {
            tempname _fa_tok
            local _fa_tok "`_fa_tok'_`=subinstr("`c(current_time)'", ":", "", .)'_`=strlen(`"`macval(_input)'"')'"
            global EPLOT_FRAMEAUTO_TOKEN "`_fa_tok'"
            local _fa_global 1
            char _dta[_eplot_frameauto] `"`_fa_tok' `_frame_auto'"'
        }
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

        local _data_ran 1
        capture noisily _eplot_data `estimate' `ll' `ul' `if' `in', `_data_opts'
        local _data_rc = _rc
    }
    local rc = _rc
    if `_fa_global' global EPLOT_FRAMEAUTO_TOKEN

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

    // Forward what the data-mode helper posted (a failed rclass program
    // posts only what it returned before failing, and nothing otherwise);
    // the frame commands above leave r() untouched.  The public wrapper
    // gates on the complete result set.  Before _eplot_data runs, r() is
    // the caller's and must not be forwarded.
    if `_data_ran' return add

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
            LOGScale ///
            REScale(real 1) ///
            /// Reference lines
            XLine(string asis) ///
            XLABel(string asis) ///
            NULL(string) ///
            NONULL ///
            /// Confidence intervals
            LEVel(string) ///
            NOCI ///
            CICap ///
            /// Display
            DP(integer 2) ///
            EFFect(string) ///
            VALues ///
            VFormat(string) ///
            VGap(real 0.15) ///
            VSize(string) ///
            VColor(string) ///
            VTItle(string) ///
            VMISSing(string asis) ///
            LABSIZE(string) ///
            NOGRid ///
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
            HETrow ///
            /// Style presets
            STYle(string) ///
            /// Box/marker options
            BOXScale(real 100) ///
            NOBOX ///
            NODIamonds ///
            DIAMONDColor(string asis) ///
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
            EXPort(string) ///
            * ///
            ]

        // nocons -> drop _cons.  An automatic drop is optional: unlike a
        // name the user wrote in drop(), it may match nothing.
        local _auto_drop ""
        if "`noconstant'" != "" local _auto_drop "_cons"

        // Each color option must name exactly one valid color: twoway draws
        // the default color at rc=0 for a list or an unknown name.
        foreach _copt in mcolor cicolor sigcolor insigncolor vcolor {
            if `"``_copt''"' != "" {
                _eplot_check_color, option(`_copt') spec(``_copt'')
            }
        }
        if "`sigcolors'" == "" & (`"`sigcolor'"' != "" | `"`insigncolor'"' != "") {
            display as error "sigcolor() and insigncolor() require sigcolors"
            exit 198
        }
        // msymbol() must be one valid symbol: twoway ignores extra symbols
        // and draws the default for an unknown name at rc=0.
        if `"`msymbol'"' != "" {
            _eplot_check_symbol, option(msymbol) max(1) spec(`msymbol')
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
        // Past 20 places string() leaves fixed notation (exponent text, and
        // from 30 places "1 (1, 2)"), so no wider range can be honoured.
        if `dp' < 0 | `dp' > 20 {
            display as error "dp() must be an integer between 0 and 20"
            exit 198
        }
        _eplot_check_gstyles, msize(`msize') ciwidth(`ciwidth') scheme(`scheme')
        if missing(`rescale') | `rescale' == 0 {
            display as error "rescale() must be nonmissing and nonzero"
            exit 198
        }
        // null(#[, line_options]): the options restyle the null line.
        local _null_opts ""
        if `"`null'"' != "" {
            gettoken null _null_rest : null, parse(",")
            local null = strtrim(`"`null'"')
            if `"`_null_rest'"' != "" {
                gettoken _comma _null_opts : _null_rest, parse(",")
                local _null_opts = strtrim(`"`_null_opts'"')
            }
            capture confirm number `null'
            if _rc {
                display as error "null() must be a nonmissing number, optionally followed by line options"
                exit 198
            }
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

    // Auto-detected frame() columns (set by _eplot_frame on its work frame).
    local frameauto ""
    local _fa : char _dta[_eplot_frameauto]
    if `"`_fa'"' != "" {
        gettoken _fa_frame _fa_list : _fa
        // Honoured only with the token of the frame() call in progress.
        if `"$EPLOT_FRAMEAUTO_TOKEN"' != "" & "`_fa_frame'" == `"$EPLOT_FRAMEAUTO_TOKEN"' {
            local frameauto "`_fa_list'"
            char _dta[_eplot_frameauto]
        }
    }

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
        if r(N) > 0 & `: list posof "type" in frameauto' {
            // frame() picked up a column named type or rowtype that the
            // user never named; it is not a row type, so it is ignored.
            display as text "(note: frame variable `type' is not a valid row type and is ignored; name it in type() to use it)"
            local type ""
        }
        else if r(N) > 0 {
            display as error "type() contains an unknown row type; use codes 0-6 or a documented string value"
            exit 198
        }
    }
    // Effect rows (no type(), or type 1, 3, 5) need an estimate and both
    // limits.  Limits come in pairs, as pi() limits do: a row with exactly
    // one limit is refused.  A row with no estimate or no interval is left
    // out of the plot, and a note names it so a study never vanishes from
    // a forest plot unannounced.
    tempvar _excl
    quietly gen byte `_excl' = `ifin_ok' & ///
        (missing(`es_var') | missing(`lci_var') | missing(`uci_var'))
    if "`type'" != "" {
        capture confirm numeric variable `type'
        if _rc == 0 {
            quietly replace `_excl' = 0 if inlist(`type', 0, 2, 4, 6)
        }
        else {
            quietly replace `_excl' = 0 ///
                if inlist(lower(strtrim(`type')), "header", "section", "missing", "reference", "hetinfo", "blank")
        }
    }
    quietly count if `_excl' & missing(`lci_var') != missing(`uci_var')
    if r(N) > 0 {
        _eplot_excluded_list `_excl' & missing(`lci_var') != missing(`uci_var'), ///
            labels(`labels') error
        exit 198
    }
    quietly count if `_excl'
    if r(N) > 0 {
        _eplot_excluded_list `_excl', labels(`labels')
    }
    markout `touse' `es_var' `lci_var' `uci_var'

    // An estimate outside its own interval is drawn as given but named: it is
    // usually a variable passed in the wrong position.
    tempvar _outside
    quietly gen byte `_outside' = `touse' & !missing(`es_var') & ///
        (`es_var' < `lci_var' | `es_var' > `uci_var')
    if "`type'" != "" {
        capture confirm numeric variable `type'
        if _rc == 0 {
            quietly replace `_outside' = 0 if !inlist(`type', 1, 3, 5)
        }
        else {
            quietly replace `_outside' = 0 if !inlist(lower(strtrim(`type')), ///
                "effect", "regular", "subgroup", "overall")
        }
    }
    quietly count if `_outside'
    if r(N) > 0 {
        _eplot_excluded_list `_outside', labels(`labels') outside
    }

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
    if `"`null'"' == "" {
        // A logarithmic effect axis is a ratio axis: 0 is not on it, so the
        // no-effect reference belongs at 1 whether or not eform was requested.
        local null = cond("`eform'" != "" | "`logscale'" != "", 1, 0)
    }
    if `"`options'"' != "" _eplot_guard_scale, `options'
    // Every xline() is eplot's: syntax binds the first, a repeat would pass
    // through to twoway unvalidated and outside the range, so all are
    // collected, each keeping its own line options and label().
    _eplot_collect_xlines, first(`xline') options(`options')
    local _xline_specs `"`s(specs)'"'
    local _xline_pos "`s(positions)'"
    local options `"`s(options)'"'
    // export(frame[, replace]) writes the plotted rows to a frame; checked
    // here so a name clash fails before any work is done.
    local _exp_frame ""
    local _exp_replace ""
    if `"`export'"' != "" {
        _eplot_parse_export, spec(`export')
        local _exp_frame "`s(frame)'"
        local _exp_replace "`s(replace)'"
    }
    if `"`_null_opts'"' != "" & "`nonull'" != "" {
        display as text "(note: null() line options have no effect with nonull)"
    }
    if "`logscale'" != "" & "`nonull'" == "" & `null' <= 0 {
        display as error ///
            "null(`null') cannot be drawn on a logarithmic axis; specify a positive null() or nonull"
        exit 198
    }
    // effect("text", atnull) centres the title on the null; effect()
    // strips the label's quotes, so the suboption is a trailing ", atnull".
    local _eff_atnull ""
    if regexm(`"`effect'"', "^(.*),[ ]*atnull[ ]*$") {
        local effect = strtrim(regexs(1))
        local _eff_atnull "atnull"
    }
    // The limits are supplied, so level() only labels them: it sets the
    // "#% CI" text of the default title and does not change any interval.
    // LEVel(cilevel) would fill in c(level); the supplied limits are 95%
    // unless level() says otherwise.
    local _lvl "95"
    if `"`level'"' != "" {
        capture confirm number `level'
        if _rc == 0 capture assert inrange(`level', 10, 99.99)
        if _rc {
            display as error "level() must be a number between 10 and 99.99"
            exit 198
        }
        local _lvl = strtrim(`"`level'"')
    }
    local _eff_default 0
    if `"`effect'"' == "" {
        local _eff_default 1
        if "`eform'" != "" {
            local effect "Effect (`_lvl'% CI)"
        }
        else {
            local effect "Estimate (`_lvl'% CI)"
        }
    }
    // With values the column header carries the interval text, so a default
    // axis title drops its " (#% CI)" suffix rather than repeat the header.
    if `_eff_default' & "`values'" != "" & "`horizontal'" != "" & ///
        `"`vtitle'"' == "" {
        local vtitle `"`effect'"'
        local effect = regexr(`"`effect'"', " \([0-9.]+% CI\)$", "")
    }
    // The width leaves room for the decimals and an integer part of up to
    // twenty digits: a fixed width below dp()+2 is not a valid format, and
    // string() switches a value too wide for its format to %g.
    if "`vformat'" == "" local vformat "%`=`dp' + 22'.`dp'f"
    // string() returns "" for a nonnumeric format, which would blank every
    // value at rc=0.
    capture confirm numeric format `vformat'
    // Date, time, and hexadecimal formats are numeric to Stata but print an
    // effect as a date or bit pattern.
    if _rc == 0 & !regexm(`"`vformat'"', "^%-?~?0?[0-9]*([.,][0-9]+)?[fge]c?$") local _rc_vf 198
    if _rc | "`_rc_vf'" != "" {
        display as error "vformat() must be a valid numeric display format (%f, %g, or %e)"
        exit 198
    }
    // Values-column and row-label text.  *# sizes resolve against eplot's
    // defaults (vsmall values, small labels), not the scheme's.
    if "`vcolor'" == "" local vcolor "gs4"
    // An RGB triplet must be quoted before it enters mlabcolor(), or twoway
    // reads a list and draws the default color.
    if `: word count `vcolor'' > 1 local vcolor `""`vcolor'""'
    if `"`vsize'"' == "" local vsize "vsmall"
    _eplot_check_textsize, option(vsize) spec(`vsize') default(2.0833)
    local vsize "`s(spec)'"
    local _vscale = `s(val)' / 2.0833
    if `"`labsize'"' == "" local labsize "small"
    _eplot_check_textsize, option(labsize) spec(`labsize') default(2.777)
    local labsize "`s(spec)'"
    // vmissing() is parsed asis so vmissing("") can blank the text.
    local _vmiss_text "Not estimated"
    if `"`vmissing'"' != "" {
        local _vm = strtrim(`"`vmissing'"')
        if substr(`"`_vm'"', 1, 1) == char(34) | ///
            substr(`"`_vm'"', 1, 2) == char(96) + char(34) {
            gettoken _vm _vm_rest : _vm
            if strtrim(`"`_vm_rest'"') != "" {
                display as error "vmissing() takes one string"
                exit 198
            }
        }
        local _vmiss_text `"`_vm'"'
    }

    // Color defaults
    if "`mcolor'" == "" local mcolor "navy"
    if "`cicolor'" == "" local cicolor "`mcolor'"
    if "`ciwidth'" == "" local ciwidth "medium"
    if "`msymbol'" == "" local msymbol "O"
    if "`msize'" == "" local msize "medium"

    // Preserve and work on data
    preserve

    // Default labels name the observation in the dataset (or frame), as
    // the missing-row note does, not its position within if/in.
    tempvar obsno
    quietly gen long `obsno' = _n
    quietly keep if `touse'

    // Create working variables
    tempvar id pos es lci uci wt rowtype label_str gapflag rowspace

    // Generate row ID
    quietly gen long `id' = _n

    // Copy effect size data
    quietly gen double `es' = `es_var'
    quietly gen double `lci' = `lci_var'
    quietly gen double `uci' = `uci_var'

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
    // Every row-type value was validated inside if/in before markout, and
    // the string mapping above covers each accepted spelling.

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
    // rescale() acts on the estimation scale: with eform it runs before the
    // exponentiation, so rescale(10) plots exp(10*b), the ratio per 10 units.
    // exp() preserves order, so the interval check above on the supplied
    // limits holds for the exponentiated ones.
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
    if "`eform'" != "" {
        quietly replace `es' = exp(`es')
        quietly replace `lci' = exp(`lci')
        quietly replace `uci' = exp(`uci')
    }

    // Labels.  `label_str' carries the SOURCE row identity until display
    // labels are applied further below: keep()/drop(), order(), groups(), and
    // headers() all key on it, matching the estimates-mode composition rule.
    if "`labels'" != "" {
        quietly gen str244 `label_str' = `labels'
    }
    else {
        quietly gen str244 `label_str' = "Row " + string(`obsno')
    }

    // Apply keep/drop against the source identities
    // Rows removed by keep() still count as matched for drop().
    local _known ""
    if `"`keep'"' != "" & `"`drop'"' != "" {
        quietly levelsof `label_str', local(_known)
    }
    if `"`keep'"' != "" {
        _eplot_apply_keep `label_str', keep(`keep')
    }
    if `"`drop'"' != "" | "`_auto_drop'" != "" {
        _eplot_apply_drop `label_str', drop(`drop') optional(`_auto_drop') ///
            known(`_known')
    }
    if `"`keep'"' != "" | `"`drop'"' != "" | "`_auto_drop'" != "" {
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
        if r(N) > 0 & `: list posof "weights" in frameauto' {
            // An auto-detected frame column the user never named: plain
            // markers instead of an error about an option not typed.
            display as text "(note: frame variable `weights' is not a usable weight for every effect row and is ignored; name it in weights() to use it)"
            local weights ""
            quietly replace `wt' = 1
        }
        else if r(N) > 0 {
            display as error "weights() must be nonmissing and positive for plotted effect rows"
            restore
            exit 198
        }
    }

    // sort is applied after groups()/headers() rows exist, so it can
    // keep each effect within its own block (see _eplot_block_sort); sort
    // and order() are mutually exclusive.
    if `"`order'"' != "" {
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
        // A name order() cannot match is an error, as in keep() and drop():
        // a typo would otherwise leave the row where it was.
        if "`_unmatched'" != "" {
            display as error "order() did not match:`_unmatched'"
            restore
            exit 198
        }
        quietly replace `order_rank' = 1000 + `id' if missing(`order_rank')
        // Rows sharing a label share a rank; `id' keeps them in input order.
        sort `order_rank' `id'
    }

    // Calculate positions (yscale(reverse) puts low values at top)
    quietly gen double `pos' = _n

    // Process groups - insert headers and adjust positions
    local n_groups 0
    tempvar grp_id
    quietly gen long `grp_id' = 0
    if `"`groups'"' != "" {
        _eplot_process_groups `pos' `label_str' `rowtype' `gapflag', ///
            groups(`groups') gap(`gap') grpvar(`grp_id')
        local n_groups = r(n_groups)
    }

    // Process headers
    if `"`headers'"' != "" {
        _eplot_process_headers `pos' `label_str' `rowtype', headers(`headers')
    }
    quietly replace `grp_id' = 0 if missing(`grp_id')

    if "`sort'" != "" {
        _eplot_block_sort `pos' `rowtype' `es' `grp_id'
    }

    // hetrow: the heterogeneity statistics as a text row under the last
    // overall (type 5) row, or under the last row, instead of in the note.
    if "`hetrow'" != "" {
        // I² and τ² keep the row short: it is a row label and sets the
        // width of the label column.
        local _het_row `""'
        if `"`i2'"' != "" local _het_row `"I`=uchar(178)' = `i2'"'
        if `"`tau2'"' != "" {
            if `"`_het_row'"' != "" local _het_row `"`_het_row', "'
            local _het_row `"`_het_row'`=uchar(964)'`=uchar(178)' = `tau2'"'
        }
        if `"`qstat'"' != "" {
            if `"`_het_row'"' != "" local _het_row `"`_het_row', "'
            local _het_row `"`_het_row'Q = `qstat'"'
        }
        if `"`_het_row'"' == "" {
            display as error "hetrow requires i2(), tau2(), or qstat()"
            restore
            exit 198
        }
        quietly summarize `pos' if `rowtype' == 5, meanonly
        local _het_pos = r(max)
        if missing(`_het_pos') {
            quietly summarize `pos', meanonly
            local _het_pos = r(max)
        }
        local _het_n = _N + 1
        quietly set obs `_het_n'
        quietly replace `pos' = `_het_pos' + 0.5 in `_het_n'
        quietly replace `label_str' = `"`_het_row'"' in `_het_n'
        quietly replace `rowtype' = 4 in `_het_n'
        quietly replace `gapflag' = 0 in `_het_n'
        quietly replace `wt' = 1 in `_het_n'
    }

    // Recalculate positions after any insertions.  Rows inserted at one
    // position (a groups() header and a headers() header, or two headers)
    // keep the order in which they were added.
    sort `pos', stable
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
        if "`eform'" != "" {
            quietly replace `pi_lci' = exp(`pi_lci')
            quietly replace `pi_uci' = exp(`pi_uci')
        }
    }
    else {
        quietly gen double `pi_lci' = .
        quietly gen double `pi_uci' = .
    }

    // Determine plot range and effect-axis ticks.  favors() labels read
    // away from the null, so the range then includes it; noci ranges on the
    // point estimates, since no interval is drawn.
    local _rng_incl ""
    if `"`favors'"' != "" & "`horizontal'" != "" & "`nonull'" == "" {
        local _rng_incl "include(`null')"
    }
    local _rng_lo `lci'
    local _rng_hi `uci'
    if "`noci'" != "" {
        local _rng_lo `es'
        local _rng_hi `es'
    }
    _eplot_calc_range `_rng_lo' `_rng_hi' if inlist(`rowtype', 1, 3, 5), ///
        extralow(`pi_lci') extrahigh(`pi_uci') point(`es') `_rng_incl' `logscale'
    local xmin = `s(min)'
    local xmax = `s(max)'
    local xrange = `s(range)'
    local lnrange = `s(lnrange)'
    local xmin_pad = `s(min_pad)'
    local xmax_pad = `s(max_pad)'

    _eplot_axis_range, min(`xmin') max(`xmax') ///
        minpad(`xmin_pad') maxpad(`xmax_pad') null(`null') ///
        xlabel(`xlabel') xlinepos(`_xline_pos') `logscale' `nogrid' ///
        `nonull' `values' `horizontal'

    // --- Values annotation ---
    local val_cmd ""
    if "`values'" != "" & "`horizontal'" == "" {
        display as text "(note: values annotation requires horizontal layout)"
    }
    if `"`vtitle'"' == "" local vtitle `"`effect'"'
    if "`values'" != "" & "`horizontal'" != "" {
        tempvar val_text val_x
        _eplot_value_text `val_text' if inlist(`rowtype', 1, 3, 5) & ///
            !missing(`es'), vars(`es' `lci' `uci') format(`vformat') ///
            suffix(`_dm_star')

        // Type 2 (missing/excluded) rows state that no estimate exists.  A
        // string type of "reference" also maps to 2 but is a reference
        // category, which is not "not estimated", so it stays blank.
        if `"`_vmiss_text'"' != "" {
            tempvar _vm_row
            quietly gen byte `_vm_row' = (`rowtype' == 2)
            if "`type'" != "" {
                capture confirm string variable `type'
                if _rc == 0 {
                    quietly replace `_vm_row' = 0 ///
                        if lower(strtrim(`type')) == "reference"
                }
            }
            quietly replace `val_text' = `"`_vmiss_text'"' if `_vm_row' == 1
        }

        _eplot_value_anchor, min(`xmin') max(`xmax') null(`null') gap(`vgap') ///
            axisopts(`"`_effect_axis_opts'"') xline(`_xline_pos') `nonull' `logscale'
        local val_xpos = `s(xpos)'
        quietly gen double `val_x' = `val_xpos' if !missing(`val_text')
        _eplot_value_margin `val_text', header(`"`vtitle'"') scale(`_vscale') ///
            passthru(`"`options'"')
        local _val_right_margin = `s(right_margin)'

        local val_cmd `"(scatter `pos' `val_x' if !missing(`val_text'), msymbol(none) mlabel(`val_text') mlabpos(3) mlabgap(0) mlabsize(`vsize') mlabcolor(`vcolor'))"'
    }

    // --- Build graph command ---
    // An RGB color reaches this point unquoted ("0 128 0" parsed as a plain
    // string), and twoway reads mcolor(0 128 0) as a list and draws black.
    // Re-quote any multi-word color before it enters the graph command.
    foreach _c in mcolor cicolor sigcolor insigncolor vcolor {
        local _nw : word count ``_c''
        if `_nw' > 1 local `_c' `""``_c''""'
    }
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
    tempvar wanchor
    quietly gen byte `wanchor' = 0
    local _wanchor_layers 0
    quietly count if `rowtype' == 1 & !missing(`es')
    if r(N) > 0 {
        if "`sigcolors'" != "" {
            if "`nobox'" == "" & "`weights'" != "" {
                local bscale = `boxscale' / 100
                // twoway scales weighted markers by each layer's own weight
                // range, so splitting the boxes into significant and
                // non-significant layers would draw equal weights at unequal
                // sizes.  Two anchor rows carrying the overall minimum and
                // maximum weight, with missing coordinates (never drawn and
                // outside the axis range), join both layers so they share
                // one scale.  They are added just before the graph runs.
                local _wanchor_layers 1
                if "`horizontal'" != "" {
                    local graphcmd `"`graphcmd' (scatter `pos' `es' if (`rowtype' == 1 & `_dm_sig' == 1) | `wanchor' == 1 [aw=`wt'], msymbol(square) mcolor(`sigcolor') msize(*`bscale'))"'
                    local graphcmd `"`graphcmd' (scatter `pos' `es' if (`rowtype' == 1 & `_dm_sig' == 0) | `wanchor' == 1 [aw=`wt'], msymbol(square) mcolor(`insigncolor') msize(*`bscale'))"'
                }
                else {
                    local graphcmd `"`graphcmd' (scatter `es' `pos' if (`rowtype' == 1 & `_dm_sig' == 1) | `wanchor' == 1 [aw=`wt'], msymbol(square) mcolor(`sigcolor') msize(*`bscale'))"'
                    local graphcmd `"`graphcmd' (scatter `es' `pos' if (`rowtype' == 1 & `_dm_sig' == 0) | `wanchor' == 1 [aw=`wt'], msymbol(square) mcolor(`insigncolor') msize(*`bscale'))"'
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
    // diamondcolor(overall [subgroup]): default black and maroon; one color
    // serves both.
    local _dcol_o "black"
    local _dcol_s "maroon"
    if `"`diamondcolor'"' != "" {
        // gettoken strips the quotes of an RGB triplet; it is checked bare
        // and requoted for lcolor().
        local _dc_rest `"`diamondcolor'"'
        gettoken _dc1 _dc_rest : _dc_rest
        gettoken _dc2 _dc_rest : _dc_rest
        if strtrim(`"`_dc_rest'"') != "" {
            display as error "diamondcolor() takes one or two colors: overall [subgroup]"
            restore
            exit 198
        }
        foreach _dc in _dc1 _dc2 {
            if `"``_dc''"' == "" continue
            capture _eplot_check_color, option(diamondcolor) spec(``_dc'')
            if _rc {
                display as error `"diamondcolor() must name valid colors, not {bf:``_dc''}"'
                restore
                exit 198
            }
            if strpos(`"``_dc''"', " ") local `_dc' `""``_dc''""'
        }
        local _dcol_o `"`_dc1'"'
        local _dcol_s `"`_dc1'"'
        if `"`_dc2'"' != "" local _dcol_s `"`_dc2'"'
    }
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
                // Overall diamond
                local diamond_cmd `"`diamond_cmd' (pcspike `pos' `lci' `diam_ly2' `es' if `rowtype' == 5, lcolor(`_dcol_o') lwidth(medthick))"'
                local diamond_cmd `"`diamond_cmd' (pcspike `diam_ly2' `es' `pos' `uci' if `rowtype' == 5, lcolor(`_dcol_o') lwidth(medthick))"'
                local diamond_cmd `"`diamond_cmd' (pcspike `pos' `uci' `diam_ly3' `es' if `rowtype' == 5, lcolor(`_dcol_o') lwidth(medthick))"'
                local diamond_cmd `"`diamond_cmd' (pcspike `diam_ly3' `es' `pos' `lci' if `rowtype' == 5, lcolor(`_dcol_o') lwidth(medthick))"'

                // Subgroup diamond
                local diamond_cmd `"`diamond_cmd' (pcspike `pos' `lci' `diam_ly2' `es' if `rowtype' == 3, lcolor(`_dcol_s') lwidth(medthick))"'
                local diamond_cmd `"`diamond_cmd' (pcspike `diam_ly2' `es' `pos' `uci' if `rowtype' == 3, lcolor(`_dcol_s') lwidth(medthick))"'
                local diamond_cmd `"`diamond_cmd' (pcspike `pos' `uci' `diam_ly3' `es' if `rowtype' == 3, lcolor(`_dcol_s') lwidth(medthick))"'
                local diamond_cmd `"`diamond_cmd' (pcspike `diam_ly3' `es' `pos' `lci' if `rowtype' == 3, lcolor(`_dcol_s') lwidth(medthick))"'
            }
            else {
                // Overall diamond - vertical
                local diamond_cmd `"`diamond_cmd' (pcspike `lci' `pos' `es' `diam_ly2' if `rowtype' == 5, lcolor(`_dcol_o') lwidth(medthick))"'
                local diamond_cmd `"`diamond_cmd' (pcspike `es' `diam_ly2' `uci' `pos' if `rowtype' == 5, lcolor(`_dcol_o') lwidth(medthick))"'
                local diamond_cmd `"`diamond_cmd' (pcspike `uci' `pos' `es' `diam_ly3' if `rowtype' == 5, lcolor(`_dcol_o') lwidth(medthick))"'
                local diamond_cmd `"`diamond_cmd' (pcspike `es' `diam_ly3' `lci' `pos' if `rowtype' == 5, lcolor(`_dcol_o') lwidth(medthick))"'

                // Subgroup diamond
                local diamond_cmd `"`diamond_cmd' (pcspike `lci' `pos' `es' `diam_ly2' if `rowtype' == 3, lcolor(`_dcol_s') lwidth(medthick))"'
                local diamond_cmd `"`diamond_cmd' (pcspike `es' `diam_ly2' `uci' `pos' if `rowtype' == 3, lcolor(`_dcol_s') lwidth(medthick))"'
                local diamond_cmd `"`diamond_cmd' (pcspike `uci' `pos' `es' `diam_ly3' if `rowtype' == 3, lcolor(`_dcol_s') lwidth(medthick))"'
                local diamond_cmd `"`diamond_cmd' (pcspike `es' `diam_ly3' `lci' `pos' if `rowtype' == 3, lcolor(`_dcol_s') lwidth(medthick))"'
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
    if `"`diamond_cmd'"' != "" {
        local graphcmd `"`graphcmd' `diamond_cmd'"'
    }

    // Add values annotation
    if `"`val_cmd'"' != "" {
        local graphcmd `"`graphcmd' `val_cmd'"'
    }

    // Labelled reference lines put their text at the top of the plot,
    // opposite the favors() text (horizontal), or beside the first row.
    // A values header owns the top row, so the labels sit a row above it.
    _eplot_reflines_all, specs(`_xline_specs') null(`null') ///
        nullopts(`_null_opts') lo(`xmin_pad') hi(`xmax_pad') ///
        `horizontal' `_refl_nonull' `logscale' ///
        labpos(`=cond("`horizontal'" != "", cond("`values'" != "", -0.45, 0.3), 0.05)')

    // --- Y-axis labels (row labels); headers and overall in bold ---
    _eplot_ylabels, pos(`pos') label(`label_str') rowtype(`rowtype') bold(0 5)

    _eplot_favors_layout, favors(`favors') null(`null') ///
        minpad(`xmin_pad') maxpad(`xmax_pad') posmax(`pos_max') ///
        axisopts(`"`_effect_axis_opts'"') `logscale' scheme(`scheme') ///
        `horizontal'

    // --- Graph options ---
    local ypad_lo 0
    local _has_vals = ("`horizontal'" != "" & "`values'" != "")
    _eplot_title_axisline, null(`null') lo(`xmin_pad') hi(`xmax_pad') ///
        posmax(`pos_max') hasvals(`_has_vals') valxpos(`val_xpos') ///
        text(`"`effect'"') `_eff_atnull' `horizontal' `logscale' ///
        passthru(`options') xlabspec(`xlabel') plotregion(`plotregion') ///
        favinside(`_fav_inside') reserve(`_fav_reserve') ///
        titletop(`_fav_titletop')
    local graphcmd `"`graphcmd'`_title_plots'"'
    _eplot_axes_opts, ylabels(`ylabels') labsize(`labsize') valuelabel ///
        `horizontal' `logscale' lo(`xmin_pad') hi(`xmax_pad') ///
        xscalemax(`_xscale_max') ypadlo(`ypad_lo') ypadhi(`ypad_hi') ///
        hasvals(`_has_vals') axisdrawn(`_axis_drawn') ///
        titleopts(`_eff_title_opts') axisopts(`_effect_axis_opts') ///
        valxpos(`val_xpos') vtitle(`"`vtitle'"') vsize(`vsize') ///
        refltext(`=`"`refline_text'"' != ""')
    local graphcmd `"`graphcmd'`_axes_opts'"'

    // Reference lines
    if `"`refline_cmd'"' != "" {
        local graphcmd `"`graphcmd' `refline_cmd'"'
    }
    if `"`refline_text'"' != "" {
        local graphcmd `"`graphcmd' `refline_text'"'
    }

    // Legend
    local graphcmd `"`graphcmd' legend(off)"'

    // Titles
    // With a values column the plot region runs on under the column, so a
    // title centred on it would sit off to the right; it is centred on the
    // whole graph instead.  span comes first: title options merge, so the
    // user's title() suboptions still apply.
    local _tspan ""
    if `_has_vals' local _tspan " title(, span)"
    local _sspan ""
    if `_has_vals' local _sspan " subtitle(, span)"
    if `"`title'"' != "" {
        local graphcmd `"`graphcmd'`_tspan' title(`title')"'
    }
    if `"`subtitle'"' != "" {
        local graphcmd `"`graphcmd'`_sspan' subtitle(`subtitle')"'
    }
    // Build heterogeneity stats string (plain text for graph note); hetrow
    // has already placed it as a row.
    local _het_text `""'
    if "`hetrow'" == "" & `"`i2'"' != "" {
        local _het_text `"I-squared = `i2'"'
    }
    if "`hetrow'" == "" & `"`tau2'"' != "" {
        if `"`_het_text'"' != "" local _het_text `"`_het_text', "'
        local _het_text `"`_het_text'tau-squared = `tau2'"'
    }
    if "`hetrow'" == "" & `"`qstat'"' != "" {
        if `"`_het_text'"' != "" local _het_text `"`_het_text', "'
        local _het_text `"`_het_text'Q = `qstat'"'
    }

    if `"`note'"' != "" {
        local graphcmd `"`graphcmd' note(`note')"'
    }
    else {
        local _autonote ""
        if "`nodiamonds'" == "" & "`noci'" == "" & `"`diamond_cmd'"' != "" {
            local _autonote "Diamonds represent pooled estimates."
            if "`weights'" != "" & "`nobox'" == "" {
                local _autonote "`_autonote' Boxes proportional to study weight."
            }
        }
        if `"`_het_text'"' != "" {
            if `"`_autonote'"' != "" {
                local _autonote `"`_autonote' `_het_text'"'
            }
            else {
                local _autonote `"`_het_text'"'
            }
        }
        if `"`_autonote'"' != "" {
            local graphcmd `"`graphcmd' note(`"`_autonote'"', size(vsmall) position(5))"'
        }
    }

    // Scheme, regions, name/saving, pass-through options, favors text
    _eplot_plotregion_use, plotregion(`plotregion') prmargin(`_pr_margin') ///
        prrest(`_pr_rest') hasvals(`_has_vals') axisdrawn(`_axis_drawn') ///
        favbelow(`_fav_below') valmargin(`_val_right_margin') `horizontal'
    _eplot_graph_tail, scheme(`scheme') plotregion(`_plotregion_use') ///
        graphregion(`graphregion') aspect(`aspect') name(`name') ///
        saving(`saving') passthru(`options') after(`_eff_title_after') ///
        axisdrawn(`_axis_drawn') favors(`favors_cmd')
    local graphcmd `"`graphcmd'`_graph_tail'"'

    // export(): the plotted rows, in display order, as a frame that
    // eplot, frame() reads back.
    if "`_exp_frame'" != "" {
        local _exp_vars "`label_str' `es' `lci' `uci' `rowtype' `wt' `pos'"
        local _exp_names "label estimate ll ul type weight pos"
        if "`pvalue'" != "" {
            local _exp_vars "`_exp_vars' `pvalue'"
            local _exp_names "`_exp_names' pvalue"
        }
        if `"`val_cmd'"' != "" {
            local _exp_vars "`_exp_vars' `val_text'"
            local _exp_names "`_exp_names' values"
        }
        _eplot_export `_exp_vars', into(`_exp_frame') ///
            names(`_exp_names') `_exp_replace'
    }

    // Shared weight-scale anchors for split weighted-box layers (see above).
    // Rows with missing coordinates stay in each layer's serset, where they
    // set the weight range, but are neither drawn nor used for the axes.
    local _n_before_anchor = _N
    if `_wanchor_layers' {
        quietly summarize `wt' if `rowtype' == 1 & !missing(`es'), meanonly
        tempname _wmin _wmax
        scalar `_wmin' = r(min)
        scalar `_wmax' = r(max)
        quietly set obs `=`_n_before_anchor' + 2'
        quietly replace `wanchor' = 1 in `=`_n_before_anchor' + 1'/l
        quietly replace `wt' = `_wmin' in `=`_n_before_anchor' + 1'
        quietly replace `wt' = `_wmax' in `=`_n_before_anchor' + 2'
    }

    // Execute graph.  Keep the analytical payload available when an optional
    // graph/save side effect fails; the public wrapper propagates both.
    capture noisily `graphcmd'
    local _side_rc = _rc
    if `_wanchor_layers' {
        quietly drop if `wanchor' == 1
    }

    // Return results
    // Build r(table) matrix from plotted data
    quietly count if inlist(`rowtype', 1, 3, 5) & !missing(`es')
    local _ntab = r(N)
    // A Stata matrix holds at most c(max_matdim) rows; past that the plot,
    // r(N), r(k), and r(cmd) are still returned, without the matrices.
    local _mat_ok = (`_ntab' <= c(max_matdim))
    if !`_mat_ok' {
        display as text "(note: r(table) and r(pvalues) are not returned: `_ntab' rows exceed the `c(max_matdim)'-row matrix limit)"
    }
    if `_ntab' > 0 & `_mat_ok' {
        tempname _rtable
        matrix `_rtable' = J(`_ntab', 3, .)
        matrix colnames `_rtable' = "b" "ll" "ul"
        local _ri 0
        forvalues i = 1/`=_N' {
            if !inlist(`rowtype'[`i'], 1, 3, 5) continue
            if missing(`es'[`i']) continue
            local ++_ri
            matrix `_rtable'[`_ri', 1] = `es'[`i']
            matrix `_rtable'[`_ri', 2] = `lci'[`i']
            matrix `_rtable'[`_ri', 3] = `uci'[`i']
        }
        _eplot_rowstripe `_rtable' if inlist(`rowtype', 1, 3, 5) & !missing(`es'), ///
            namevar(`label_str')
        local _has_table 1
    }
    if "`pvalue'" != "" & `_mat_ok' {
        quietly count if inlist(`rowtype', 1, 3, 5) & !missing(`es')
        local _npv = r(N)
        if `_npv' > 0 {
            tempname _rpvals
            matrix `_rpvals' = J(`_npv', 1, .)
            matrix colnames `_rpvals' = "pvalue"
            local _pi 0
            forvalues i = 1/`=_N' {
                if !inlist(`rowtype'[`i'], 1, 3, 5) continue
                if missing(`es'[`i']) continue
                local ++_pi
                matrix `_rpvals'[`_pi', 1] = `pvalue'[`i']
            }
            _eplot_rowstripe `_rpvals' if inlist(`rowtype', 1, 3, 5) & !missing(`es'), ///
                namevar(`label_str')
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
// stata-dev-ignore: return_class_match — ereturn clear only empties the e() that restoring a named model left when no results were active
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
            LOGScale ///
            REScale(real 1) ///
            /// Reference lines
            XLine(string asis) ///
            XLABel(string asis) ///
            NULL(string) ///
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
            VGap(real 0.15) ///
            VSize(string) ///
            VColor(string) ///
            VTItle(string) ///
            LABSIZE(string) ///
            NOGRid ///
            STARs ///
            SIGColors ///
            SIGColor(string) ///
            INSIGNColor(string) ///
            /// Reference categories
            BASElevels ///
            VREFerence(string) ///
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
            PALette(string asis) ///
            LEGendopts(string asis) ///
            /// Marker options
            MColor(string asis) ///
            MSymbol(string) ///
            MSize(string) ///
            CIColor(string asis) ///
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
            EXPort(string) ///
            * ///
            ]

        // nocons -> drop _cons.  An automatic drop is optional: unlike a
        // name the user wrote in drop(), it may match nothing.
        local _auto_drop ""
        if "`noconstant'" != "" local _auto_drop "_cons"

        // eform -> auto-suppress constant (exp(_cons) is not meaningful).
        // The note is printed after keep(), and only if a constant is dropped.
        local _eform_cons 0
        if "`eform'" != "" & "`noconstant'" == "" {
            // Only add if not already in drop list
            local _has_cons 0
            foreach _d of local drop {
                if "`_d'" == "_cons" local _has_cons 1
            }
            if !`_has_cons' {
                local _auto_drop "_cons"
                local _eform_cons 1
            }
        }

        // Track explicitly supplied single-model presentation options before
        // a style preset can contribute its own defaults.
        local _values_supplied = ("`values'" != "")
        local _stars_supplied = ("`stars'" != "")
        local _sigcolors_supplied = ("`sigcolors'" != "")
        local _sigcolor_supplied = (`"`sigcolor'"' != "")
        local _insigncolor_supplied = (`"`insigncolor'"' != "")
        // Color options are parsed asis so a multi-model list may quote RGB
        // triplets ("255 0 0" "0 0 255").  A single color is unquoted here,
        // exactly as a plain string option would have been.
        local _mcolor_user `"`mcolor'"'
        local _cicolor_user `"`cicolor'"'
        foreach _copt in mcolor cicolor palette {
            local _nw : word count ``_copt''
            if `_nw' == 1 local `_copt' : word 1 of ``_copt''
        }
        local _mcolor_supplied = (`"`mcolor'"' != "")
        local _cicolor_supplied = (`"`cicolor'"' != "")

        // ====== Style presets (apply BEFORE user overrides) ======
        if "`style'" != "" {
            _eplot_apply_style, style(`"`style'"')
            if "`values'" == "" {
                local values "`s(values)'"
            }
            if `"`mcolor'"' == "" local mcolor "`s(mcolor)'"
            if `"`cicolor'"' == "" local cicolor "`s(cicolor)'"
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
        // Past 20 places string() leaves fixed notation (exponent text, and
        // from 30 places "1 (1, 2)"), so no wider range can be honoured.
        if `dp' < 0 | `dp' > 20 {
            display as error "dp() must be an integer between 0 and 20"
            exit 198
        }
        _eplot_check_gstyles, msize(`msize') ciwidth(`ciwidth') scheme(`scheme')
        if missing(`rescale') | `rescale' == 0 {
            display as error "rescale() must be nonmissing and nonzero"
            exit 198
        }
        // null(#[, line_options]): the options restyle the null line.
        local _null_opts ""
        if `"`null'"' != "" {
            gettoken null _null_rest : null, parse(",")
            local null = strtrim(`"`null'"')
            if `"`_null_rest'"' != "" {
                gettoken _comma _null_opts : _null_rest, parse(",")
                local _null_opts = strtrim(`"`_null_opts'"')
            }
            capture confirm number `null'
            if _rc {
                display as error "null() must be a nonmissing number, optionally followed by line options"
                exit 198
            }
        }

    // ====== Parse estimate list ======
    if `"`anything'"' == "" | `"`anything'"' == "." {
        local estlist "."
    }
    else {
        local estlist `"`anything'"'
    }
    local n_models : word count `estlist'

    if `n_models' > 1 {
        local _mm_invalid ""
        if `_values_supplied' local _mm_invalid "`_mm_invalid' values"
        if `vgap' != 0.15 local _mm_invalid "`_mm_invalid' vgap()"
        if `"`vsize'"' != "" local _mm_invalid "`_mm_invalid' vsize()"
        if `"`vcolor'"' != "" local _mm_invalid "`_mm_invalid' vcolor()"
        if `"`vtitle'"' != "" local _mm_invalid "`_mm_invalid' vtitle()"
        if `_stars_supplied' local _mm_invalid "`_mm_invalid' stars"
        if `_sigcolors_supplied' local _mm_invalid "`_mm_invalid' sigcolors"
        if `_sigcolor_supplied' local _mm_invalid "`_mm_invalid' sigcolor()"
        if `_insigncolor_supplied' local _mm_invalid "`_mm_invalid' insigncolor()"
        if "`baselevels'" != "" local _mm_invalid "`_mm_invalid' baselevels"
        if `"`vreference'"' != "" local _mm_invalid "`_mm_invalid' vreference()"
        if "`_mm_invalid'" != "" {
            display as error "`_mm_invalid' may be used only with single-model estimates"
            exit 198
        }
    }

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
    // Multi-model mcolor()/cicolor(): one color applies to every model (as
    // msymbol() and msize() do); a list gives one color per model (as
    // palette() does).  palette() and mcolor() would both set the per-model
    // marker colors, and the loser would be silently discarded, so the
    // combination is refused.  Colors from a style() preset are defaults and
    // yield to the palette; only explicitly supplied colors are used here.
    if `n_models' == 1 {
        foreach _copt in mcolor cicolor sigcolor insigncolor vcolor {
            if `"``_copt''"' != "" {
                _eplot_check_color, option(`_copt') spec(``_copt'')
            }
        }
        if "`sigcolors'" == "" & (`"`sigcolor'"' != "" | `"`insigncolor'"' != "") {
            display as error "sigcolor() and insigncolor() require sigcolors"
            exit 198
        }
        if `"`msymbol'"' != "" {
            _eplot_check_symbol, option(msymbol) max(1) spec(`msymbol')
        }
    }
    else {
        // Every element of a per-model color list must itself be one color.
        foreach _copt in mcolor cicolor palette {
            if "`_copt'" == "palette" & !`_palette_supplied' continue
            if "`_copt'" != "palette" & !`_`_copt'_supplied' continue
            local _clist `"`_`_copt'_user'"'
            if "`_copt'" == "palette" local _clist `"`palette'"'
            foreach _c of local _clist {
                _eplot_check_color, option(`_copt') spec(`_c')
            }
        }
    }
    if `n_models' > 1 {
        if `_palette_supplied' & `_mcolor_supplied' {
            display as error "palette() and mcolor() may not be combined with multiple models; each sets the per-model marker colors"
            exit 198
        }
        foreach _copt in mcolor cicolor {
            if !`_`_copt'_supplied' continue
            local _n_c : word count `_`_copt'_user'
            if `_n_c' != 1 & `_n_c' != `n_models' {
                display as error "`_copt'() with multiple models requires one color or exactly one color per model (`n_models'); quote RGB triplets"
                exit 198
            }
        }
        // msymbol() follows the mcolor() rule: one symbol for every model or
        // exactly one per model, so models can differ by shape as well as
        // color (greyscale print, color-vision deficiency).
        local _n_ms : word count `msymbol'
        if `_n_ms' > 1 & `_n_ms' != `n_models' {
            display as error "msymbol() with multiple models requires one symbol or exactly one symbol per model (`n_models')"
            exit 198
        }
        if `"`msymbol'"' != "" {
            _eplot_check_symbol, option(msymbol) max(`n_models') spec(`msymbol')
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
    if `"`null'"' == "" {
        // A logarithmic effect axis is a ratio axis: 0 is not on it, so the
        // no-effect reference belongs at 1 whether or not eform was requested.
        local null = cond("`eform'" != "" | "`logscale'" != "", 1, 0)
    }
    if `"`options'"' != "" _eplot_guard_scale, `options'
    // Every xline() is eplot's: syntax binds the first, a repeat would pass
    // through to twoway unvalidated and outside the range, so all are
    // collected, each keeping its own line options and label().
    _eplot_collect_xlines, first(`xline') options(`options')
    local _xline_specs `"`s(specs)'"'
    local _xline_pos "`s(positions)'"
    local options `"`s(options)'"'
    // export(frame[, replace]) writes the plotted rows to a frame; checked
    // here so a name clash fails before any work is done.
    local _exp_frame ""
    local _exp_replace ""
    if `"`export'"' != "" {
        _eplot_parse_export, spec(`export')
        local _exp_frame "`s(frame)'"
        local _exp_replace "`s(replace)'"
    }
    if `"`_null_opts'"' != "" & "`nonull'" != "" {
        display as text "(note: null() line options have no effect with nonull)"
    }
    if `"`vreference'"' != "" & "`baselevels'" == "" {
        display as error "vreference() requires baselevels"
        exit 198
    }
    if "`logscale'" != "" & "`nonull'" == "" & `null' <= 0 {
        display as error ///
            "null(`null') cannot be drawn on a logarithmic axis; specify a positive null() or nonull"
        exit 198
    }
    if `"`vformat'"' != "" {
        capture confirm numeric format `vformat'
        // Date, time, and hexadecimal formats are numeric to Stata but print
        // an effect as a date or bit pattern.
        if _rc == 0 & !regexm(`"`vformat'"', "^%-?~?0?[0-9]*([.,][0-9]+)?[fge]c?$") local _rc_vf 198
        if _rc | "`_rc_vf'" != "" {
            display as error "vformat() must be a valid numeric display format (%f, %g, or %e)"
            exit 198
        }
    }
    // The width leaves room for the decimals and an integer part of up to
    // twenty digits: a fixed width below dp()+2 is not a valid format, and
    // string() switches a value too wide for its format to %g.
    if "`vformat'" == "" local vformat "%`=`dp' + 22'.`dp'f"
    // Values-column and row-label text.  *# sizes resolve against eplot's
    // defaults (vsmall values, small labels), not the scheme's.
    if "`vcolor'" == "" local vcolor "gs4"
    // An RGB triplet must be quoted before it enters mlabcolor(), or twoway
    // reads a list and draws the default color.
    if `: word count `vcolor'' > 1 local vcolor `""`vcolor'""'
    if `"`vsize'"' == "" local vsize "vsmall"
    _eplot_check_textsize, option(vsize) spec(`vsize') default(2.0833)
    local vsize "`s(spec)'"
    local _vscale = `s(val)' / 2.0833
    if `"`labsize'"' == "" local labsize "small"
    _eplot_check_textsize, option(labsize) spec(`labsize') default(2.777)
    local labsize "`s(spec)'"
    // The default spacing between models shrinks so one coefficient's
    // models never span more than 0.6 of a row: at 0.15 seven models filled
    // 0.9 rows and ran into the next coefficient's block.
    if "`offset'" == "" {
        local offset 0.15
        if `n_models' > 1 local offset = min(0.15, 0.6 / (`n_models' - 1))
    }
    else if `n_models' > 1 & (`n_models' - 1) * `offset' >= 0.9 {
        display as text "(note: offset(`offset') spreads `n_models' models over " ///
            string((`n_models' - 1) * `offset', "%4.2f") " rows; neighbouring coefficients may overlap)"
    }

    // Default palette for multi-model.  Beyond its cardinality the palette
    // cycles: model m uses color mod(m-1, #colors) + 1.  A user-supplied
    // palette is validated to have exactly one color per model above, so the
    // cycle is a no-op there.
    if `"`palette'"' == "" {
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
    // Critical values, estimates, and limits travel in scalars and matrix
    // cells, never through decimal locals, so r(table) reproduces e(b).
    tempname zcrit _se_i _df_i _crit_i _lo_i _hi_i
    scalar `zcrit' = invnormal(1 - (1 - `level'/100)/2)

    // ====== Identify "." model (current estimates) ======
    local dot_idx 0
    forvalues m = 1/`n_models' {
        if "`: word `m' of `estlist''" == "." {
            local dot_idx `m'
        }
    }

    // Active results are identified by e(b) as well as e(cmd): ereturn post
    // leaves e(cmd) empty, and those results must be neither refused nor
    // cleared by the restore of a named model below.
    capture confirm matrix e(b)
    local had_est = (!_rc | "`e(cmd)'" != "")

    // Validate current estimates if needed
    if `dot_idx' > 0 {
        if !`had_est' {
            display as error "no estimation results found"
            display as error "run a regression command first, or specify stored estimate names"
            exit 301
        }
    }

    // ====== Save and extract current estimates before any restore ======
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
        tempname b_dot V_dot dfv_dot
        // matrix X = e(b) succeeds with a 0 x 0 matrix when e(b) is
        // absent, so existence must be confirmed explicitly.
        capture confirm matrix e(b)
        if _rc {
            display as error "active estimation results do not contain e(b)"
            if "`e(mi)'" == "mi" {
                display as error "specify {bf:mi estimate, post} to post the combined estimates"
            }
            exit 498
        }
        capture confirm matrix e(V)
        if _rc {
            display as error "active estimation results do not contain e(V)"
            exit 498
        }
        matrix `b_dot' = e(b)
        matrix `V_dot' = e(V)
        local _keform_dot "`e(k_eform)'"
        // Columns past _nfix_dot are not effects: variance components that
        // mixed and the meqr* commands post in equations of their own, or
        // trailing ancillary equations (see _eplot_fixed_cut).
        _eplot_fixed_cut, matrix(`b_dot')
        local _nfix_dot = `s(nfix)'
        local _nfix_kind_dot "`s(kind)'"
        // proportion's limits are not b +/- t*se (logit by default).
        local _prop_dot 0
        if "`e(cmd)'" == "proportion" {
            tempname _pll_dot _pul_dot
            _eplot_prop_limits, b(`b_dot') level(`level') ll(`_pll_dot') ul(`_pul_dot')
            local _prop_dot 1
        }
        _eplot_coef_df, b(`b_dot') df(`dfv_dot') v(`V_dot')
    }

    // Auto-detect the effect label from the requested model, not from an
    // unrelated model that happened to be active when eplot was called.
    // effect("text", atnull) centres the title on the null; effect()
    // strips the label's quotes, so the suboption is a trailing ", atnull".
    local _eff_atnull ""
    if regexm(`"`effect'"', "^(.*),[ ]*atnull[ ]*$") {
        local effect = strtrim(regexs(1))
        local _eff_atnull "atnull"
    }
    local _eff_default 0
    if `"`effect'"' == "" {
        local _eff_default 1
        if "`eform'" == "" {
            local effect "Coefficient (`level'% CI)"
        }
        else {
            local _ecmd ""
            local _efrm2 ""
            if `n_models' == 1 {
                local est_name : word 1 of `estlist'
                if `dot_idx' != 1 {
                    capture estimates restore `est_name'
                    if _rc {
                        display as error `"estimation results '`est_name'' not found"'
                        exit 111
                    }
                }
                local _ecmd "`e(cmd)'"
                local _efrm2 "`e(frm2)'"
                local _elink "`e(linkt)'"
                local _efam "`e(varfunct)'"
                local _eeform `"`e(eform)'"'
                // stcox posts e(cmd)=cox, streg posts the distribution name,
                // and the me* commands post meglm or gsem; the user-facing
                // command is in e(cmd2).
                if inlist("`_ecmd'", "cox", "meglm", "gsem") | "`e(cmd2)'" == "streg" {
                    if "`e(cmd2)'" != "" local _ecmd "`e(cmd2)'"
                }
            }
            // Each title is the name Stata gives the exponentiated column
            // of that command's own table.
            local _bin = inlist("`_efam'", "Bernoulli", "Binomial")
            local _cnt = inlist("`_efam'", "Poisson", "Neg. Binomial")
            if inlist("`_ecmd'", "logit", "logistic", "melogit", "xtlogit", "clogit") | ///
                inlist("`_ecmd'", "ologit", "meologit", "xtologit") | ///
                ("`_ecmd'" == "glm" & "`_elink'" == "Logit" & `_bin') {
                local effect "Odds Ratio (`level'% CI)"
            }
            else if "`_ecmd'" == "stcox" | ///
                (inlist("`_ecmd'", "streg", "mestreg") & "`_efrm2'" == "hazard") {
                // Parametric survival models are hazard ratios only in the
                // proportional-hazards metric; the AFT metric is a time ratio.
                local effect "Hazard Ratio (`level'% CI)"
            }
            else if inlist("`_ecmd'", "streg", "mestreg") & "`_efrm2'" == "time" {
                local effect "Time Ratio (`level'% CI)"
            }
            else if inlist("`_ecmd'", "poisson", "nbreg", "mepoisson", "menbreg", "xtpoisson") | ///
                inlist("`_ecmd'", "zip", "tpoisson", "tnbreg", "gnbreg") | ///
                ("`_ecmd'" == "glm" & "`_elink'" == "Log" & `_cnt') {
                local effect "IRR (`level'% CI)"
            }
            else if "`_ecmd'" == "glm" & "`_elink'" == "Log" & `_bin' {
                local effect "Risk Ratio (`level'% CI)"
            }
            else if "`_ecmd'" == "mlogit" {
                local effect "RRR (`level'% CI)"
            }
            else if "`_ecmd'" == "stcrreg" {
                local effect "SHR (`level'% CI)"
            }
            else if regexm(`"`_eeform'"', "^eform\((.+)\)$") {
                // binreg posts its column name, e.g. eform(Risk ratio).
                local effect = strproper(regexs(1)) + " (`level'% CI)"
            }
            else {
                local effect "Effect (`level'% CI)"
            }
        }
    }
    // With values the column header carries the interval text, so a default
    // axis title drops its " (#% CI)" suffix rather than repeat the header.
    if `_eff_default' & "`values'" != "" & "`horizontal'" != "" & ///
        `"`vtitle'"' == "" & `n_models' == 1 {
        local vtitle `"`effect'"'
        local effect = regexr(`"`effect'"', " \([0-9.]+% CI\)$", "")
    }

    // ====== Gather variable labels before preserve (for auto-labeling) ======
    // Build label map: coef_name -> human-readable label
    // Uses variable labels and factor value labels from data in memory
    local _auto_labels ""
    local _n_autolabels 0
    // rename() targets are labelled from their own variables even when no
    // plotted model has that coefficient.
    local _rn_targets ""
    if `"`rename'"' != "" {
        local _rn_rest `"`rename'"'
        while `"`_rn_rest'"' != "" {
            gettoken _rn_old _rn_rest : _rn_rest, parse("=")
            gettoken _rn_eq _rn_rest : _rn_rest, parse("=")
            gettoken _rn_new _rn_rest : _rn_rest, parse(" ") bind
            if strtrim(`"`_rn_eq'"') != "=" continue, break
            local _rn_new = strtrim(`"`_rn_new'"')
            if regexm(`"`_rn_new'"', "^[A-Za-z0-9_.:#]+$") {
                local _rn_targets `"`_rn_targets' `_rn_new'"'
            }
        }
    }
    forvalues m = 1/`n_models' {
        local est_name : word `m' of `estlist'
        if `m' == `dot_idx' {
            _eplot_matrix_coefnames, matrix(`b_dot') nfix(`_nfix_dot')
            local _colnames `"`s(names)'"'
        }
        else {
            capture estimates restore `est_name'
            if _rc continue
            tempname _btemp
            matrix `_btemp' = e(b)
            _eplot_fixed_cut, matrix(`_btemp')
            local _nfix_l = `s(nfix)'
            _eplot_matrix_coefnames, matrix(`_btemp') nfix(`_nfix_l')
            local _colnames `"`s(names)'"'
        }
        local _colnames `"`_colnames' `_rn_targets'"'
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
            // margins, post names a level "#bn." (no base level).
            if regexm("`_basevar'", "^([0-9]+)(bn|b)?\.(.+)$") {
                local _facval = regexs(1)
                local _purvar = regexs(3)
            }
            else if regexm("`_basevar'", "^[co]\.(.+)$") {
                local _purvar = regexs(1)
            }

            // Interaction terms: skip complex patterns with #
            if strpos("`_basevar'", "#") > 0 {
                continue
            }

            // Labels are read in Mata with ` and $ written as {c 96} and
            // {c 36}: a macro holding them would be expanded again on every
            // use (and once more when the graph is drawn), so `x' and $x
            // would vanish and a lone ` would fail with r(132).  The codes
            // draw the characters exactly.
            local _label ""
            // Factor variable: try value label first
            if "`_facval'" != "" {
                capture local _vallbl : value label `_purvar'
                if _rc local _vallbl ""
                if "`_vallbl'" != "" {
                    local _label ""
                    capture mata: st_local("_label", ///
                        subinstr(subinstr(st_vlmap("`_vallbl'", `_facval'), char(96), "{c 96}"), char(36), "{c 36}"))
                    if _rc local _label ""
                }
                // Fall back to "VarLabel = value" or "varname = value"
                if `"`_label'"' == "" | `"`_label'"' == "`_facval'" {
                    local _vl ""
                    capture mata: st_local("_vl", ///
                        subinstr(subinstr(st_varlabel("`_purvar'"), char(96), "{c 96}"), char(36), "{c 36}"))
                    if _rc local _vl ""
                    if `"`_vl'"' != "" {
                        local _label `"`_vl' = `_facval'"'
                    }
                }
            }
            else if "`_cn'" != "_cons" {
                // Regular variable: use variable label
                capture mata: st_local("_label", ///
                    subinstr(subinstr(st_varlabel("`_purvar'"), char(96), "{c 96}"), char(36), "{c 36}"))
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
    quietly postfile `posthn' str244 coef_name double(es se lci uci df) byte model_id ///
        byte isbase str244 _coef_full using `postfn', replace
    local _post_open 1

    // Free parameters in the "/" equation (cutpoints, variances, ln_p,
    // lnalpha, ...) are not effects: Stata reports them on their own
    // metric, without a test, so they are never plotted.  Under eform only
    // the equations Stata itself exponentiates are kept: the first
    // e(k_eform) equations (default 1), as [R] ml display documents.
    local _n_anc 0
    local _n_aux 0
    local _n_vc 0
    local _n_noneform 0
    local _zero_names ""
    // Every coefficient of every model, before keep() or any omission, so a
    // drop() term that names one is never an error.
    local _known ""

    forvalues m = 1/`n_models' {
        local est_name : word `m' of `estlist'

        if `m' == `dot_idx' {
            // Current estimates (already extracted)
            local k = colsof(`b_dot')
            _eplot_matrix_coefnames, matrix(`b_dot') nfix(`_nfix_dot')
            local names `"`s(names)'"'
            local _fnames : colfullnames `b_dot'
            local _known `"`_known' `names' `_fnames'"'
            _eplot_eform_eqs, matrix(`b_dot') keform(`_keform_dot')
            local _eqs `"`s(eqs)'"'
            local _eform_eqs `"`s(eform_eqs)'"'
            // Equations with at least one estimated coefficient.  mlogit's
            // base-outcome equation has none, so baselevels gives it no
            // reference rows (Stata shows it as "(base outcome)").
            local _esteqs ""
            forvalues i = 1/`k' {
                if `V_dot'[`i', `i'] > 0 & !missing(`V_dot'[`i', `i']) {
                    local _esteqs `"`_esteqs' `: word `i' of `_eqs''"'
                }
            }
            local _esteqs : list uniq _esteqs

            forvalues i = 1/`k' {
                local nm : word `i' of `names'
                local _fn : word `i' of `_fnames'
                local _eq_i : word `i' of `_eqs'
                local this_var = `V_dot'[`i', `i']
                if "`_eq_i'" == "/" {
                    if `this_var' > 0 & !missing(`this_var') local ++_n_anc
                    continue
                }
                if `i' > `_nfix_dot' {
                    if "`_nfix_kind_dot'" == "anc" local ++_n_aux
                    else local ++_n_vc
                    continue
                }
                if "`eform'" != "" & !`: list _eq_i in _eform_eqs' {
                    if `this_var' > 0 & !missing(`this_var') local ++_n_noneform
                    continue
                }
                if missing(`this_var') | `this_var' < 0 {
                    display as error "e(V) contains an invalid variance for coefficient `nm'"
                    exit 498
                }
                // A small but positive variance is a real estimate (e.g. a
                // coefficient on a variable measured in large units).
                // Omitted and base-level terms carry exactly zero variance.  With
                // baselevels a factor's base level ("#b.var", not an interaction) is
                // kept as a reference row with no estimate.
                if `this_var' == 0 {
                    if "`baselevels'" != "" & regexm("`nm'", "(^|:)[0-9]+b\.[^#]+$") & ///
                        `: list _eq_i in _esteqs' {
                        post `posthn' ("`nm'") (.) (.) (.) (.) (.) (`m') (1) ("`_fn'")
                    }
                    else if !regexm("`nm'", "(^|[:#])[0-9]*c?(b|o|bo|ob)\.") {
                        // Not an omitted or base term: a coefficient
                        // constrained to a fixed value has no interval.
                        local _zero_names "`_zero_names' `nm'"
                    }
                    continue
                }
                scalar `_se_i' = sqrt(`V_dot'[`i', `i'])
                scalar `_df_i' = `dfv_dot'[1, `i']
                scalar `_crit_i' = `zcrit'
                if !missing(`_df_i') {
                    scalar `_crit_i' = invttail(`_df_i', (1 - `level'/100) / 2)
                }

                scalar `_lo_i' = `b_dot'[1, `i'] - `_crit_i' * `_se_i'
                scalar `_hi_i' = `b_dot'[1, `i'] + `_crit_i' * `_se_i'
                if `_prop_dot' {
                    scalar `_lo_i' = `_pll_dot'[1, `i']
                    scalar `_hi_i' = `_pul_dot'[1, `i']
                    if missing(`_lo_i') | missing(`_hi_i') {
                        display as error "proportion reports no confidence interval for `nm'"
                        exit 498
                    }
                }
                post `posthn' ("`nm'") (`b_dot'[1, `i']) (`_se_i') ///
                    (`_lo_i') (`_hi_i') (`_df_i') (`m') (0) ("`_fn'")
            }
        }
        else {
            // Named estimate
            capture estimates restore `est_name'
            if _rc {
                display as error `"estimation results '`est_name'' not found"'
                exit 111
            }

            tempname bm Vm dfvm
            capture confirm matrix e(b)
            if _rc {
                display as error `"estimation results '`est_name'' do not contain e(b)"'
                if "`e(mi)'" == "mi" {
                    display as error "specify {bf:mi estimate, post} before storing the combined estimates"
                }
                exit 498
            }
            capture confirm matrix e(V)
            if _rc {
                display as error `"estimation results '`est_name'' do not contain e(V)"'
                exit 498
            }
            matrix `bm' = e(b)
            matrix `Vm' = e(V)
            _eplot_coef_df, b(`bm') df(`dfvm') v(`Vm')
            _eplot_fixed_cut, matrix(`bm')
            local _nfix = `s(nfix)'
            local _nfix_kind "`s(kind)'"
            local _prop_m 0
            if "`e(cmd)'" == "proportion" {
                tempname _pll_m _pul_m
                _eplot_prop_limits, b(`bm') level(`level') ll(`_pll_m') ul(`_pul_m')
                local _prop_m 1
            }

            local k = colsof(`bm')
            _eplot_matrix_coefnames, matrix(`bm') nfix(`_nfix')
            local names `"`s(names)'"'
            local _fnames : colfullnames `bm'
            local _known `"`_known' `names' `_fnames'"'
            _eplot_eform_eqs, matrix(`bm') keform(`e(k_eform)')
            local _eqs `"`s(eqs)'"'
            local _eform_eqs `"`s(eform_eqs)'"'
            // Equations with at least one estimated coefficient.  mlogit's
            // base-outcome equation has none, so baselevels gives it no
            // reference rows (Stata shows it as "(base outcome)").
            local _esteqs ""
            forvalues i = 1/`k' {
                if `Vm'[`i', `i'] > 0 & !missing(`Vm'[`i', `i']) {
                    local _esteqs `"`_esteqs' `: word `i' of `_eqs''"'
                }
            }
            local _esteqs : list uniq _esteqs

            forvalues i = 1/`k' {
                local nm : word `i' of `names'
                local _fn : word `i' of `_fnames'
                local _eq_i : word `i' of `_eqs'
                local this_var = `Vm'[`i', `i']
                if "`_eq_i'" == "/" {
                    if `this_var' > 0 & !missing(`this_var') local ++_n_anc
                    continue
                }
                if `i' > `_nfix' {
                    if "`_nfix_kind'" == "anc" local ++_n_aux
                    else local ++_n_vc
                    continue
                }
                if "`eform'" != "" & !`: list _eq_i in _eform_eqs' {
                    if `this_var' > 0 & !missing(`this_var') local ++_n_noneform
                    continue
                }
                if missing(`this_var') | `this_var' < 0 {
                    display as error `"e(V) for '`est_name'' contains an invalid variance for coefficient `nm'"'
                    exit 498
                }
                // Omitted and base-level terms carry exactly zero variance.  With
                // baselevels a factor's base level ("#b.var", not an interaction) is
                // kept as a reference row with no estimate.
                if `this_var' == 0 {
                    if "`baselevels'" != "" & regexm("`nm'", "(^|:)[0-9]+b\.[^#]+$") & ///
                        `: list _eq_i in _esteqs' {
                        post `posthn' ("`nm'") (.) (.) (.) (.) (.) (`m') (1) ("`_fn'")
                    }
                    else if !regexm("`nm'", "(^|[:#])[0-9]*c?(b|o|bo|ob)\.") {
                        // Not an omitted or base term: a coefficient
                        // constrained to a fixed value has no interval.
                        local _zero_names "`_zero_names' `nm'"
                    }
                    continue
                }
                scalar `_se_i' = sqrt(`Vm'[`i', `i'])
                scalar `_df_i' = `dfvm'[1, `i']
                scalar `_crit_i' = `zcrit'
                if !missing(`_df_i') {
                    scalar `_crit_i' = invttail(`_df_i', (1 - `level'/100) / 2)
                }

                scalar `_lo_i' = `bm'[1, `i'] - `_crit_i' * `_se_i'
                scalar `_hi_i' = `bm'[1, `i'] + `_crit_i' * `_se_i'
                if `_prop_m' {
                    scalar `_lo_i' = `_pll_m'[1, `i']
                    scalar `_hi_i' = `_pul_m'[1, `i']
                    if missing(`_lo_i') | missing(`_hi_i') {
                        display as error "proportion reports no confidence interval for `nm'"
                        exit 498
                    }
                }
                post `posthn' ("`nm'") (`bm'[1, `i']) (`_se_i') ///
                    (`_lo_i') (`_hi_i') (`_df_i') (`m') (0) ("`_fn'")
            }
        }
    }

    postclose `posthn'
    local _post_open 0
    if `_n_anc' > 0 {
        display as text "(note: `_n_anc' ancillary parameter(s) in equation / omitted)"
    }
    if `_n_vc' > 0 {
        display as text "(note: `_n_vc' variance-component parameter(s) omitted)"
    }
    if `_n_aux' > 0 {
        display as text "(note: `_n_aux' ancillary parameter(s) omitted)"
    }
    if `_n_noneform' > 0 {
        display as text "(note: `_n_noneform' parameter(s) outside the exponentiated equation(s) omitted with eform)"
    }
    local _zero_names : list uniq _zero_names
    if "`_zero_names'" != "" {
        display as text "(note: zero-variance (constrained) coefficient(s) omitted: `=strtrim("`_zero_names'")')"
    }

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
    // The full eq:name identity, so keep()/drop() can select eq:coef even
    // when the plotted name carries no equation prefix.
    local coef_full "_coef_full"

    // ====== Transform data ======

    // Apply keep/drop
    if `"`keep'"' != "" {
        _eplot_apply_keep coef_name, keep(`keep') fullname(`coef_full')
    }
    if `_eform_cons' {
        quietly count if coef_name == "_cons" | substr(coef_name, -6, .) == ":_cons"
        if r(N) > 0 display as text "(note: constant suppressed with eform)"
    }
    if `"`drop'"' != "" | "`_auto_drop'" != "" {
        _eplot_apply_drop coef_name, drop(`drop') optional(`_auto_drop') ///
            fullname(`coef_full') known(`_known')
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
        // rename() may align coefficients across models, but two
        // coefficients of one model on one row would plot as a single effect.
        tempvar _rn_dup _rn_row
        quietly gen long `_rn_row' = _n
        quietly bysort coef_name model_id : gen byte `_rn_dup' = (_N > 1)
        sort `_rn_row'
        quietly count if `_rn_dup'
        if r(N) > 0 {
            quietly levelsof coef_name if `_rn_dup', local(_rn_dupnames) clean
            display as error `"rename() maps more than one coefficient of the same model to: `_rn_dupnames'"'
            exit 198
        }
        drop `_rn_dup' `_rn_row'
    }
    // Labels are matched on this immutable post-rename identity, so a label
    // that equals another coefficient's name is never relabelled.
    tempvar coef_key
    quietly gen str244 `coef_key' = coef_name

    // ====== P-values (compute BEFORE eform) ======
    if `n_models' == 1 {
        quietly gen double _pval = .
        quietly replace _pval = 2 * normal(-abs(es / se)) ///
            if se > 0 & !missing(se) & !missing(es) & missing(df)
        quietly replace _pval = 2 * ttail(df, abs(es / se)) ///
            if se > 0 & !missing(se) & !missing(es) & !missing(df)
    }

    // Apply rescale on the estimation scale, then eform: rescale(10) with
    // eform plots exp(10*b), the ratio per 10 units.
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

    // Apply eform
    if "`eform'" != "" {
        quietly {
            replace es = exp(es)
            replace lci = exp(lci)
            replace uci = exp(uci)
        }
    }

    // ====== Determine coefficient order ======
    gen long _orig_row = _n
    bysort coef_name (_orig_row) : gen long _first_seen = _orig_row[1]

    if "`sort'" != "" & `n_models' > 1 {
        // Sort by effect size (first model's value).  A single model sorts
        // after groups()/headers() rows exist, within blocks.
        bysort coef_name (_orig_row) : gen double _sort_es = es[1]
        sort _sort_es _first_seen model_id
        drop _sort_es
    }
    else if `"`order'"' != "" {
        quietly gen long _order_rank = .
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
        // A name order() cannot match is an error, as in keep() and drop():
        // a typo would otherwise leave the row where it was.
        if "`_unmatched'" != "" {
            display as error "order() did not match:`_unmatched'"
            exit 198
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
    quietly count if _coef_tag & !isbase
    local n_estimated = r(N)

    // Create position mapping (avoid nested preserve)
    tempfile fulldata posmap
    quietly save `fulldata'

    quietly keep if _coef_tag
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
        quietly replace _rowtype = 2 if isbase
        gen byte _gapflag = 0
        tempvar grp_id
        quietly gen long `grp_id' = 0

        if `"`groups'"' != "" {
            _eplot_process_groups _base_pos coef_name _rowtype _gapflag, ///
                groups(`groups') gap(`gap') grpvar(`grp_id')
        }
        if `"`headers'"' != "" {
            _eplot_process_headers _base_pos coef_name _rowtype, ///
                headers(`headers')
        }
        quietly replace `grp_id' = 0 if missing(`grp_id')
        if "`sort'" != "" {
            // A base-level reference row sorts at its null value (1 under
            // eform, else 0) so it stays among its factor's effects.
            tempvar _sk
            quietly gen double `_sk' = es
            quietly replace `_sk' = cond("`eform'" != "", 1, 0) if isbase
            _eplot_block_sort _base_pos _rowtype `_sk' `grp_id' isbase
        }

        // Recalculate positions after insertions; rows inserted at one
        // position keep the order in which they were added.
        sort _base_pos, stable
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
        // The merge above leaves rows in coefficient-name order; r(table)
        // follows display order, as in single-model mode.
        sort _base_pos model_id

        // Warn if groups/headers specified in multi-model mode
        if `"`groups'"' != "" | `"`headers'"' != "" | `gap' > 0 {
            display as text "(note: groups(), headers(), and gap() are ignored " ///
                "in multi-model mode)"
        }

    }

    // ====== Auto-label coefficients from variable labels ======
    // Both label passes key on the immutable post-rename identity, never on
    // coef_name, so a label equal to another coefficient's name is not
    // matched again.  coeflabels() runs second, so a user-supplied label
    // always wins over the variable-label default.  Header rows inserted by
    // groups()/headers() have an empty key and are never relabelled.
    if `_n_autolabels' > 0 {
        forvalues _ai = 1/`_n_autolabels' {
            quietly replace coef_name = `"`_autoval_`_ai''"' ///
                if `coef_key' == `"`_autokey_`_ai''"'
        }
    }

    // ====== Apply coefficient labels (highest precedence) ======
    if `"`coeflabels'"' != "" {
        _eplot_apply_coeflabels coef_name, coeflabels(`coeflabels') key(`coef_key')
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
    local _ls_opt ""
    if "`logscale'" != "" local _ls_opt "logscale"
    // favors() labels read away from the null, so the range then includes
    // it; noci ranges on the point estimates, since no interval is drawn.
    if `"`favors'"' != "" & "`horizontal'" != "" & "`nonull'" == "" {
        local _ls_opt "`_ls_opt' include(`null')"
    }
    local _rng_vars "lci uci"
    if "`noci'" != "" local _rng_vars "es es"
    _eplot_calc_range `_rng_vars' if _rowtype == 1, `_ls_opt'
    local data_xmin = `s(min)'
    local data_xmax = `s(max)'
    local data_range = `s(range)'
    local lnrange = `s(lnrange)'
    local xmin_pad = `s(min_pad)'
    local xmax_pad = `s(max_pad)'

    _eplot_axis_range, min(`data_xmin') max(`data_xmax') ///
        minpad(`xmin_pad') maxpad(`xmax_pad') null(`null') ///
        xlabel(`xlabel') xlinepos(`_xline_pos') `logscale' `nogrid' ///
        `nonull' `values' `horizontal'

    // ====== Values annotation (single-model only) ======
    local val_cmd ""
    if "`values'" != "" & "`horizontal'" == "" {
        display as text "(note: values annotation requires horizontal layout)"
    }
    if `"`vtitle'"' == "" local vtitle `"`effect'"'
    if "`values'" != "" & `n_models' == 1 & "`horizontal'" != "" {
        local _star_suf ""
        if "`stars'" != "" local _star_suf "suffix(_star)"
        _eplot_value_text _val_text if _rowtype == 1 & !missing(es), ///
            vars(es lci uci) format(`vformat') `_star_suf'
        if "`baselevels'" != "" {
            local _vref `"`vreference'"'
            if `"`_vref'"' == "" {
                local _vref = string(cond("`eform'" != "", 1, 0), "`vformat'") + " (reference)"
            }
            quietly replace _val_text = `"`_vref'"' if _rowtype == 2 & isbase
        }

        _eplot_value_anchor, min(`data_xmin') max(`data_xmax') null(`null') gap(`vgap') ///
            axisopts(`"`_effect_axis_opts'"') xline(`_xline_pos') `nonull' `logscale'
        local val_xpos = `s(xpos)'
        quietly gen double _val_x = `val_xpos' if !missing(_val_text)
        _eplot_value_margin _val_text, header(`"`vtitle'"') scale(`_vscale') ///
            passthru(`"`options'"')
        local _val_right_margin = `s(right_margin)'

        local val_cmd `"(scatter _plot_pos _val_x if !missing(_val_text), msymbol(none) mlabel(_val_text) mlabpos(3) mlabgap(0) mlabsize(`vsize') mlabcolor(`vcolor'))"'
    }

    // ====== Build graph command ======
    // An RGB color reaches this point unquoted ("0 128 0" parsed as a plain
    // string), and twoway reads mcolor(0 128 0) as a list and draws black.
    // Re-quote any multi-word color before it enters the graph command.
    foreach _c in mcolor cicolor sigcolor insigncolor vcolor {
        local _nw : word count ``_c''
        if `_nw' > 1 local `_c' `""``_c''""'
    }
    local graphcmd "twoway"

    if `n_models' > 1 {
        // --- Multi-model graph ---
        local _plot_elem 0
        forvalues m = 1/`n_models' {
            local _pal_idx = mod(`m' - 1, `_n_palette_words') + 1
            local mc : word `_pal_idx' of `palette'
            if "`mc'" == "" local mc "navy"
            if `_mcolor_supplied' {
                local _n_c : word count `_mcolor_user'
                local mc : word `=cond(`_n_c' == 1, 1, `m')' of `_mcolor_user'
            }
            // CI color defaults to the model's marker color, as cicolor()
            // defaults to mcolor() in single-model plots.
            local cc `"`mc'"'
            if `_cicolor_supplied' {
                local _n_c : word count `_cicolor_user'
                local cc : word `=cond(`_n_c' == 1, 1, `m')' of `_cicolor_user'
            }
            foreach _c in mc cc {
                local _nw : word count ``_c''
                if `_nw' > 1 local `_c' `""``_c''""'
            }

            // CI lines
            if "`noci'" == "" {
                local ++_plot_elem
                if "`horizontal'" != "" {
                    if "`cicap'" != "" {
                        local graphcmd `"`graphcmd' (rcap lci uci _plot_pos if model_id == `m' & _rowtype == 1, horizontal lcolor(`cc') lwidth(`ciwidth'))"'
                    }
                    else {
                        local graphcmd `"`graphcmd' (rspike lci uci _plot_pos if model_id == `m' & _rowtype == 1, horizontal lcolor(`cc') lwidth(`ciwidth'))"'
                    }
                }
                else {
                    if "`cicap'" != "" {
                        local graphcmd `"`graphcmd' (rcap lci uci _plot_pos if model_id == `m' & _rowtype == 1, lcolor(`cc') lwidth(`ciwidth'))"'
                    }
                    else {
                        local graphcmd `"`graphcmd' (rspike lci uci _plot_pos if model_id == `m' & _rowtype == 1, lcolor(`cc') lwidth(`ciwidth'))"'
                    }
                }
            }

            // Markers
            local _n_ms : word count `msymbol'
            local ms : word `=cond(`_n_ms' == 1, 1, `m')' of `msymbol'
            local ++_plot_elem
            local _leg_idx_`m' = `_plot_elem'
            if "`horizontal'" != "" {
                local graphcmd `"`graphcmd' (scatter _plot_pos es if model_id == `m' & _rowtype == 1, msymbol(`ms') mcolor(`mc') msize(`msize'))"'
            }
            else {
                local graphcmd `"`graphcmd' (scatter es _plot_pos if model_id == `m' & _rowtype == 1, msymbol(`ms') mcolor(`mc') msize(`msize'))"'
            }
        }
    }
    else {
        // --- Single-model graph ---
        local mc `"`mcolor'"'
        if `"`mc'"' == "" local mc "navy"
        local cc `"`cicolor'"'
        if `"`cc'"' == "" local cc `"`mc'"'

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
    if `"`val_cmd'"' != "" {
        local graphcmd `"`graphcmd' `val_cmd'"'
    }

    // ====== Build y-axis labels ======
    if `n_models' == 1 {
        // Single model: use all rows (including headers from groups)
        _eplot_ylabels, pos(_base_pos) label(coef_name) ///
            rowtype(_rowtype) bold(0)
    }
    else {
        // Multi-model: use unique coefficient tags only
        _eplot_ylabels, pos(_base_pos) label(coef_name) tag(_coef_tag)
    }

    // ====== Graph options ======
    local ypad_lo = cond(`n_models' > 1, ///
        0.5 - `offset' * `n_models' / 2, 0)

    // Labelled reference lines put their text at the top of the plot,
    // opposite the favors() text (horizontal), or beside the first row.
    // A values header owns the top row, so the labels sit a row above it.
    _eplot_reflines_all, specs(`_xline_specs') null(`null') ///
        nullopts(`_null_opts') lo(`xmin_pad') hi(`xmax_pad') ///
        `horizontal' `_refl_nonull' `logscale' ///
        labpos(`=cond("`horizontal'" != "", cond("`values'" != "" & `n_models' == 1, -0.45, 0.3), `ypad_lo' + 0.05)')

    _eplot_favors_layout, favors(`favors') null(`null') ///
        minpad(`xmin_pad') maxpad(`xmax_pad') posmax(`pos_max') ///
        axisopts(`"`_effect_axis_opts'"') `logscale' scheme(`scheme') ///
        `horizontal'

    local _has_vals = ("`horizontal'" != "" & "`values'" != "" & `n_models' == 1)
    _eplot_title_axisline, null(`null') lo(`xmin_pad') hi(`xmax_pad') ///
        posmax(`pos_max') hasvals(`_has_vals') valxpos(`val_xpos') ///
        text(`"`effect'"') `_eff_atnull' `horizontal' `logscale' ///
        passthru(`options') xlabspec(`xlabel') plotregion(`plotregion') ///
        favinside(`_fav_inside') reserve(`_fav_reserve') ///
        titletop(`_fav_titletop')
    local graphcmd `"`graphcmd'`_title_plots'"'
    _eplot_axes_opts, ylabels(`ylabels') labsize(`labsize') ///
        `horizontal' `logscale' lo(`xmin_pad') hi(`xmax_pad') ///
        xscalemax(`_xscale_max') ypadlo(`ypad_lo') ypadhi(`ypad_hi') ///
        hasvals(`_has_vals') axisdrawn(`_axis_drawn') ///
        titleopts(`_eff_title_opts') axisopts(`_effect_axis_opts') ///
        valxpos(`val_xpos') vtitle(`"`vtitle'"') vsize(`vsize') ///
        refltext(`=`"`refline_text'"' != ""')
    local graphcmd `"`graphcmd'`_axes_opts'"'

    if `"`refline_cmd'"' != "" {
        local graphcmd `"`graphcmd' `refline_cmd'"'
    }
    if `"`refline_text'"' != "" {
        local graphcmd `"`graphcmd' `refline_text'"'
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
    // With a values column the plot region runs on under the column, so a
    // title centred on it would sit off to the right; it is centred on the
    // whole graph instead.  span comes first: title options merge, so the
    // user's title() suboptions still apply.
    local _tspan ""
    if `_has_vals' local _tspan " title(, span)"
    local _sspan ""
    if `_has_vals' local _sspan " subtitle(, span)"
    if `"`title'"' != "" {
        local graphcmd `"`graphcmd'`_tspan' title(`title')"'
    }
    if `"`subtitle'"' != "" {
        local graphcmd `"`graphcmd'`_sspan' subtitle(`subtitle')"'
    }
    if `"`note'"' != "" {
        local graphcmd `"`graphcmd' note(`note')"'
    }

    // Scheme, regions, name/saving, pass-through options, favors text
    _eplot_plotregion_use, plotregion(`plotregion') prmargin(`_pr_margin') ///
        prrest(`_pr_rest') hasvals(`_has_vals') axisdrawn(`_axis_drawn') ///
        favbelow(`_fav_below') valmargin(`_val_right_margin') `horizontal'
    _eplot_graph_tail, scheme(`scheme') plotregion(`_plotregion_use') ///
        graphregion(`graphregion') aspect(`aspect') name(`name') ///
        saving(`saving') passthru(`options') after(`_eff_title_after') ///
        axisdrawn(`_axis_drawn') favors(`favors_cmd')
    local graphcmd `"`graphcmd'`_graph_tail'"'

    // export(): the plotted rows, in display order, as a frame.
    if "`_exp_frame'" != "" {
        local _exp_vars "coef_name es lci uci _rowtype _plot_pos model_id"
        local _exp_names "label estimate ll ul type pos model_id"
        capture confirm variable _pval
        if _rc == 0 {
            local _exp_vars "`_exp_vars' _pval"
            local _exp_names "`_exp_names' pvalue"
        }
        capture confirm variable _val_text
        if _rc == 0 {
            local _exp_vars "`_exp_vars' _val_text"
            local _exp_names "`_exp_names' values"
        }
        _eplot_export `_exp_vars', into(`_exp_frame') ///
            names(`_exp_names') `_exp_replace'
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
            forvalues i = 1/`=_N' {
                if _rowtype[`i'] != 1 continue
                local ++_ri
                matrix `_rtable'[`_ri', 1] = es[`i']
                matrix `_rtable'[`_ri', 2] = lci[`i']
                matrix `_rtable'[`_ri', 3] = uci[`i']
            }
            _eplot_rowstripe `_rtable' if _rowtype == 1, namevar(coef_name)
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

            // Fill matrix in one pass: _base_pos numbers the unique
            // coefficients 1..k in display order, so it is the row index.
            forvalues j = 1/`=_N' {
                local _ri = _base_pos[`j']
                local _col = (model_id[`j'] - 1) * 3 + 1
                matrix `_rtable'[`_ri', `_col'] = es[`j']
                matrix `_rtable'[`_ri', `_col' + 1] = lci[`j']
                matrix `_rtable'[`_ri', `_col' + 2] = uci[`j']
            }
            _eplot_rowstripe `_rtable' if _coef_tag == 1, namevar(coef_name) ///
                index(_base_pos)
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
            forvalues i = 1/`=_N' {
                if _rowtype[`i'] != 1 continue
                if missing(_pval[`i']) continue
                local ++_pi
                matrix `_rpvals'[`_pi', 1] = _pval[`i']
            }
            _eplot_rowstripe `_rpvals' if _rowtype == 1 & !missing(_pval), ///
                namevar(coef_name)
            local _has_pvalues 1
        }
    }

        local _r_N = `n_items'
        local _r_nmodels = `n_models'
        local _r_k = `n_estimated'
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
            LOGScale ///
            REScale(real 1) ///
            /// Coefficient selection
            KEEP(string asis) ///
            DROP(string asis) ///
            COEFLabels(string asis) ///
            /// Reference lines
            XLine(string asis) ///
            XLABel(string asis) ///
            NULL(string) ///
            NONULL ///
            NOCI ///
            CICap ///
            /// Display
            STYle(string) ///
            DP(integer 2) ///
            EFFect(string) ///
            VALues ///
            VFormat(string) ///
            VGap(real 0.15) ///
            VSize(string) ///
            VColor(string) ///
            VTItle(string) ///
            LABSIZE(string) ///
            NOGRid ///
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
            EXPort(string) ///
            * ///
            ]

        // nocons -> drop _cons.  An automatic drop is optional: unlike a
        // name the user wrote in drop(), it may match nothing.
        local _auto_drop ""
        if "`noconstant'" != "" local _auto_drop "_cons"

        // eform -> auto-suppress constant (exp(_cons) is not meaningful).
        // The note is printed after keep(), and only if a constant is dropped.
        local _eform_cons 0
        if "`eform'" != "" & "`noconstant'" == "" {
            local _has_cons 0
            foreach _d of local drop {
                if "`_d'" == "_cons" local _has_cons 1
            }
            if !`_has_cons' {
                local _auto_drop "_cons"
                local _eform_cons 1
            }
        }

        // Each color option must name exactly one valid color: twoway draws
        // the default color at rc=0 for a list or an unknown name.
        foreach _copt in mcolor cicolor sigcolor insigncolor vcolor {
            if `"``_copt''"' != "" {
                _eplot_check_color, option(`_copt') spec(``_copt'')
            }
        }
        if "`sigcolors'" == "" & (`"`sigcolor'"' != "" | `"`insigncolor'"' != "") {
            display as error "sigcolor() and insigncolor() require sigcolors"
            exit 198
        }
        // msymbol() must be one valid symbol: twoway ignores extra symbols
        // and draws the default for an unknown name at rc=0.
        if `"`msymbol'"' != "" {
            _eplot_check_symbol, option(msymbol) max(1) spec(`msymbol')
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

    if `dp' < 0 | `dp' > 20 {
        display as error "dp() must be an integer between 0 and 20"
        exit 198
    }
    _eplot_check_gstyles, msize(`msize') ciwidth(`ciwidth') scheme(`scheme')
    if missing(`rescale') | `rescale' == 0 {
        display as error "rescale() must be nonmissing and nonzero"
        exit 198
    }
    // null(#[, line_options]): the options restyle the null line.
    local _null_opts ""
    if `"`null'"' != "" {
        gettoken null _null_rest : null, parse(",")
        local null = strtrim(`"`null'"')
        if `"`_null_rest'"' != "" {
            gettoken _comma _null_opts : _null_rest, parse(",")
            local _null_opts = strtrim(`"`_null_opts'"')
        }
        capture confirm number `null'
        if _rc {
            display as error "null() must be a nonmissing number, optionally followed by line options"
            exit 198
        }
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
    tempname crit
    scalar `crit' = invnormal(1 - (1 - `level'/100)/2)
    if `"`null'"' == "" {
        // A logarithmic effect axis is a ratio axis: 0 is not on it, so the
        // no-effect reference belongs at 1 whether or not eform was requested.
        local null = cond("`eform'" != "" | "`logscale'" != "", 1, 0)
    }
    if `"`options'"' != "" _eplot_guard_scale, `options'
    // Every xline() is eplot's: syntax binds the first, a repeat would pass
    // through to twoway unvalidated and outside the range, so all are
    // collected, each keeping its own line options and label().
    _eplot_collect_xlines, first(`xline') options(`options')
    local _xline_specs `"`s(specs)'"'
    local _xline_pos "`s(positions)'"
    local options `"`s(options)'"'
    // export(frame[, replace]) writes the plotted rows to a frame; checked
    // here so a name clash fails before any work is done.
    local _exp_frame ""
    local _exp_replace ""
    if `"`export'"' != "" {
        _eplot_parse_export, spec(`export')
        local _exp_frame "`s(frame)'"
        local _exp_replace "`s(replace)'"
    }
    if `"`_null_opts'"' != "" & "`nonull'" != "" {
        display as text "(note: null() line options have no effect with nonull)"
    }
    if "`logscale'" != "" & "`nonull'" == "" & `null' <= 0 {
        display as error ///
            "null(`null') cannot be drawn on a logarithmic axis; specify a positive null() or nonull"
        exit 198
    }
    // effect("text", atnull) centres the title on the null; effect()
    // strips the label's quotes, so the suboption is a trailing ", atnull".
    local _eff_atnull ""
    if regexm(`"`effect'"', "^(.*),[ ]*atnull[ ]*$") {
        local effect = strtrim(regexs(1))
        local _eff_atnull "atnull"
    }
    local _eff_default 0
    if `"`effect'"' == "" {
        local _eff_default 1
        if "`eform'" != "" {
            local effect "Effect (`level'% CI)"
        }
        else {
            local effect "Estimate (`level'% CI)"
        }
    }
    // With values the column header carries the interval text, so a default
    // axis title drops its " (#% CI)" suffix rather than repeat the header.
    if `_eff_default' & "`values'" != "" & "`horizontal'" != "" & ///
        `"`vtitle'"' == "" {
        local vtitle `"`effect'"'
        local effect = regexr(`"`effect'"', " \([0-9.]+% CI\)$", "")
    }
    if `"`vformat'"' != "" {
        capture confirm numeric format `vformat'
        // Date, time, and hexadecimal formats are numeric to Stata but print
        // an effect as a date or bit pattern.
        if _rc == 0 & !regexm(`"`vformat'"', "^%-?~?0?[0-9]*([.,][0-9]+)?[fge]c?$") local _rc_vf 198
        if _rc | "`_rc_vf'" != "" {
            display as error "vformat() must be a valid numeric display format (%f, %g, or %e)"
            exit 198
        }
    }
    // The width leaves room for the decimals and an integer part of up to
    // twenty digits: a fixed width below dp()+2 is not a valid format, and
    // string() switches a value too wide for its format to %g.
    if "`vformat'" == "" local vformat "%`=`dp' + 22'.`dp'f"
    // Values-column and row-label text.  *# sizes resolve against eplot's
    // defaults (vsmall values, small labels), not the scheme's.
    if "`vcolor'" == "" local vcolor "gs4"
    // An RGB triplet must be quoted before it enters mlabcolor(), or twoway
    // reads a list and draws the default color.
    if `: word count `vcolor'' > 1 local vcolor `""`vcolor'""'
    if `"`vsize'"' == "" local vsize "vsmall"
    _eplot_check_textsize, option(vsize) spec(`vsize') default(2.0833)
    local vsize "`s(spec)'"
    local _vscale = `s(val)' / 2.0833
    if `"`labsize'"' == "" local labsize "small"
    _eplot_check_textsize, option(labsize) spec(`labsize') default(2.777)
    local labsize "`s(spec)'"
    if "`mcolor'" == "" local mcolor "navy"
    if "`cicolor'" == "" local cicolor "`mcolor'"
    if "`ciwidth'" == "" local ciwidth "medium"
    if "`msymbol'" == "" local msymbol "O"
    if "`msize'" == "" local msize "medium"

    // Build dataset
    preserve
    clear
    quietly set obs `nrows'

    quietly gen str244 coef_name = ""
    quietly gen double es = .
    quietly gen double se = .
    quietly gen double lci = .
    quietly gen double uci = .

    tempvar coef_eq stripe_row stripe_dup
    quietly gen str244 `coef_eq' = ""

    // Row labels come straight from the matrix stripe, one row at a time.
    // Splitting the rownames list into words would shift every label after a
    // name that contains a space onto the wrong effect.
    mata: st_sstore(., ("`coef_eq'", "coef_name"), st_matrixrowstripe("`matrix'"))
    // The full eq:name identity, so keep()/drop() select eq:coef whether
    // or not the plotted name keeps its equation prefix.
    tempvar coef_full
    quietly gen str244 `coef_full' = cond(!inlist(`coef_eq', "", "_"), ///
        `coef_eq' + ":" + coef_name, coef_name)

    // As in estimates mode, repeated row names keep their equation prefix so
    // distinct effects (e.g. the same covariate in two equations) remain
    // distinguishable and selectable as eq:name.
    quietly {
        gen long `stripe_row' = _n
        bysort coef_name: gen byte `stripe_dup' = (_N > 1)
        sort `stripe_row'
        count if `stripe_dup'
    }
    if r(N) > 0 {
        quietly replace coef_name = `coef_eq' + ":" + coef_name if `coef_eq' != ""
    }
    drop `stripe_row' `stripe_dup'

    forvalues i = 1/`nrows' {
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

    // Rows in the "/" equation are ancillary parameters on their own
    // metric (e.g. cutpoints or variances from a transposed r(table)), and
    // _diparm# rows are transformed ancillary parameters (alpha, sigma_u,
    // rho); Stata never exponentiates either.
    if "`eform'" != "" {
        quietly count if `coef_eq' == "/" | regexm(`coef_eq', "^_diparm[0-9]*$")
        if r(N) > 0 {
            display as text "(note: `r(N)' ancillary parameter(s) in equation / or _diparm omitted with eform)"
            quietly drop if `coef_eq' == "/" | regexm(`coef_eq', "^_diparm[0-9]*$")
        }
    }
    drop `coef_eq'

    // Rows removed by keep() still count as matched for drop().
    local _known ""
    if `"`keep'"' != "" & `"`drop'"' != "" {
        quietly levelsof coef_name, local(_known)
        quietly levelsof `coef_full', local(_kfull)
        local _known `"`_known' `_kfull'"'
    }
    // Apply keep/drop
    if `"`keep'"' != "" {
        _eplot_apply_keep coef_name, keep(`keep') fullname(`coef_full')
    }
    if `_eform_cons' {
        quietly count if coef_name == "_cons" | substr(coef_name, -6, .) == ":_cons"
        if r(N) > 0 display as text "(note: constant suppressed with eform)"
    }
    if `"`drop'"' != "" | "`_auto_drop'" != "" {
        _eplot_apply_drop coef_name, drop(`drop') optional(`_auto_drop') ///
            fullname(`coef_full') known(`_known')
    }

    quietly count
    if r(N) == 0 {
        display as error "no rows to plot after keep/drop"
        restore
        exit 2000
    }
    local n_coefs = r(N)

    // Stars p-value computation (BEFORE eform, only for 2-col matrices with SE)
    if "`stars'" != "" & `ncols' == 2 {
        quietly gen double _pval = 2 * normal(-abs(es / se)) ///
            if se > 0 & !missing(se) & !missing(es)
    }
    else if "`stars'" != "" & `ncols' == 3 {
        display as text "(note: stars requires standard errors; not available with 3-column matrix)"
        local stars ""
    }

    // Apply rescale on the estimation scale, then eform: rescale(10) with
    // eform plots exp(10*b), the ratio per 10 units.
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

    // Apply eform
    if "`eform'" != "" {
        quietly {
            replace es = exp(es)
            replace lci = exp(lci)
            replace uci = exp(uci)
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
        quietly gen long _order_rank = .
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
        // A name order() cannot match is an error, as in keep() and drop():
        // a typo would otherwise leave the row where it was.
        if "`_unmatched'" != "" {
            display as error "order() did not match:`_unmatched'"
            restore
            exit 198
        }
        quietly replace _order_rank = 1000 + _orig if missing(_order_rank)
        sort _order_rank
        drop _order_rank
    }

    // Display labels run LAST, after keep()/drop() and order(), so every
    // selection keys on the original row names, as in estimates mode.
    if `"`coeflabels'"' != "" {
        _eplot_apply_coeflabels coef_name, coeflabels(`coeflabels')
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
    local _ls_opt ""
    if "`logscale'" != "" local _ls_opt ", logscale"
    // A 3-column matrix supplies its own limits, so the point estimate may
    // lie outside them.  favors() labels read away from the null, so the
    // range then includes it; noci ranges on the point estimates.
    local _rng_incl ""
    if `"`favors'"' != "" & "`horizontal'" != "" & "`nonull'" == "" {
        local _rng_incl "include(`null')"
    }
    local _rng_vars "lci uci"
    if "`noci'" != "" local _rng_vars "es es"
    _eplot_calc_range `_rng_vars', point(es) `_rng_incl' `logscale'
    local data_xmin = `s(min)'
    local data_xmax = `s(max)'
    local data_range = `s(range)'
    local lnrange = `s(lnrange)'
    local xmin_pad = `s(min_pad)'
    local xmax_pad = `s(max_pad)'

    _eplot_axis_range, min(`data_xmin') max(`data_xmax') ///
        minpad(`xmin_pad') maxpad(`xmax_pad') null(`null') ///
        xlabel(`xlabel') xlinepos(`_xline_pos') `logscale' `nogrid' ///
        `nonull' `values' `horizontal'

    // Values annotation
    local val_cmd ""
    if "`values'" != "" & "`horizontal'" == "" {
        display as text "(note: values annotation requires horizontal layout)"
    }
    if `"`vtitle'"' == "" local vtitle `"`effect'"'
    if "`values'" != "" & "`horizontal'" != "" {
        local _star_suf ""
        if "`stars'" != "" local _star_suf "suffix(_star)"
        _eplot_value_text _val_text, vars(es lci uci) format(`vformat') ///
            `_star_suf'

        _eplot_value_anchor, min(`data_xmin') max(`data_xmax') null(`null') gap(`vgap') ///
            axisopts(`"`_effect_axis_opts'"') xline(`_xline_pos') `nonull' `logscale'
        local val_xpos = `s(xpos)'
        gen double _val_x = `val_xpos'
        _eplot_value_margin _val_text, header(`"`vtitle'"') scale(`_vscale') ///
            passthru(`"`options'"')
        local _val_right_margin = `s(right_margin)'

        local val_cmd `"(scatter _plot_pos _val_x, msymbol(none) mlabel(_val_text) mlabpos(3) mlabgap(0) mlabsize(`vsize') mlabcolor(`vcolor'))"'
    }

    // Build graph
    // An RGB color reaches this point unquoted ("0 128 0" parsed as a plain
    // string), and twoway reads mcolor(0 128 0) as a list and draws black.
    // Re-quote any multi-word color before it enters the graph command.
    foreach _c in mcolor cicolor sigcolor insigncolor vcolor {
        local _nw : word count ``_c''
        if `_nw' > 1 local `_c' `""``_c''""'
    }
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
    if `"`val_cmd'"' != "" {
        local graphcmd `"`graphcmd' `val_cmd'"'
    }

    // Y-axis labels
    _eplot_ylabels, pos(_plot_pos) label(coef_name)

    // Graph options
    local ypad_lo 0

    // Labelled reference lines put their text at the top of the plot,
    // opposite the favors() text (horizontal), or beside the first row.
    // A values header owns the top row, so the labels sit a row above it.
    _eplot_reflines_all, specs(`_xline_specs') null(`null') ///
        nullopts(`_null_opts') lo(`xmin_pad') hi(`xmax_pad') ///
        `horizontal' `_refl_nonull' `logscale' ///
        labpos(`=cond("`horizontal'" != "", cond("`values'" != "", -0.45, 0.3), 0.05)')

    _eplot_favors_layout, favors(`favors') null(`null') ///
        minpad(`xmin_pad') maxpad(`xmax_pad') posmax(`pos_max') ///
        axisopts(`"`_effect_axis_opts'"') `logscale' scheme(`scheme') ///
        `horizontal'

    local _has_vals = ("`horizontal'" != "" & "`values'" != "")
    _eplot_title_axisline, null(`null') lo(`xmin_pad') hi(`xmax_pad') ///
        posmax(`pos_max') hasvals(`_has_vals') valxpos(`val_xpos') ///
        text(`"`effect'"') `_eff_atnull' `horizontal' `logscale' ///
        passthru(`options') xlabspec(`xlabel') plotregion(`plotregion') ///
        favinside(`_fav_inside') reserve(`_fav_reserve') ///
        titletop(`_fav_titletop')
    local graphcmd `"`graphcmd'`_title_plots'"'
    _eplot_axes_opts, ylabels(`ylabels') labsize(`labsize') ///
        `horizontal' `logscale' lo(`xmin_pad') hi(`xmax_pad') ///
        xscalemax(`_xscale_max') ypadlo(`ypad_lo') ypadhi(`ypad_hi') ///
        hasvals(`_has_vals') axisdrawn(`_axis_drawn') ///
        titleopts(`_eff_title_opts') axisopts(`_effect_axis_opts') ///
        valxpos(`val_xpos') vtitle(`"`vtitle'"') vsize(`vsize') ///
        refltext(`=`"`refline_text'"' != ""')
    local graphcmd `"`graphcmd'`_axes_opts'"'

    local graphcmd `"`graphcmd' `refline_cmd'"'
    if `"`refline_text'"' != "" {
        local graphcmd `"`graphcmd' `refline_text'"'
    }

    // Legend off
    local graphcmd `"`graphcmd' legend(off)"'

    // Titles
    // With a values column the plot region runs on under the column, so a
    // title centred on it would sit off to the right; it is centred on the
    // whole graph instead.  span comes first: title options merge, so the
    // user's title() suboptions still apply.
    local _tspan ""
    if `_has_vals' local _tspan " title(, span)"
    local _sspan ""
    if `_has_vals' local _sspan " subtitle(, span)"
    if `"`title'"' != "" local graphcmd `"`graphcmd'`_tspan' title(`title')"'
    if `"`subtitle'"' != "" local graphcmd `"`graphcmd'`_sspan' subtitle(`subtitle')"'
    if `"`note'"' != "" local graphcmd `"`graphcmd' note(`note')"'

    _eplot_plotregion_use, plotregion(`plotregion') prmargin(`_pr_margin') ///
        prrest(`_pr_rest') hasvals(`_has_vals') axisdrawn(`_axis_drawn') ///
        favbelow(`_fav_below') valmargin(`_val_right_margin') `horizontal'
    _eplot_graph_tail, scheme(`scheme') plotregion(`_plotregion_use') ///
        graphregion(`graphregion') aspect(`aspect') name(`name') ///
        saving(`saving') passthru(`options') after(`_eff_title_after') ///
        axisdrawn(`_axis_drawn') favors(`favors_cmd')
    local graphcmd `"`graphcmd'`_graph_tail'"'

    // export(): the plotted rows, in display order, as a frame.
    if "`_exp_frame'" != "" {
        local _exp_vars "coef_name es lci uci _plot_pos"
        local _exp_names "label estimate ll ul pos"
        // pvalue when r(pvalues) is returned (stars with standard errors).
        capture confirm variable _pval
        if _rc == 0 {
            local _exp_vars "`_exp_vars' _pval"
            local _exp_names "`_exp_names' pvalue"
        }
        capture confirm variable _val_text
        if _rc == 0 {
            local _exp_vars "`_exp_vars' _val_text"
            local _exp_names "`_exp_names' values"
        }
        _eplot_export `_exp_vars', into(`_exp_frame') ///
            names(`_exp_names') `_exp_replace'
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
        forvalues i = 1/`n_coefs' {
            matrix `_rtable'[`i', 1] = es[`i']
            matrix `_rtable'[`i', 2] = lci[`i']
            matrix `_rtable'[`i', 3] = uci[`i']
        }
        _eplot_rowstripe `_rtable' in 1/`n_coefs', namevar(coef_name)
        local _has_table 1
    }

    // Two-column matrix input supplies standard errors, so p-values are
    // available when stars is requested.  Compute them before eform() above.
    // One row per r(table) row, missing where a row has no standard error,
    // so the two matrices align row by row as in the other modes.
    if "`stars'" != "" & `ncols' == 2 {
        quietly count if !missing(_pval)
        if r(N) > 0 & `n_coefs' > 0 {
            tempname _rpvals
            matrix `_rpvals' = J(`n_coefs', 1, .)
            matrix colnames `_rpvals' = "pvalue"
            forvalues i = 1/`n_coefs' {
                matrix `_rpvals'[`i', 1] = _pval[`i']
            }
            _eplot_rowstripe `_rpvals' in 1/`n_coefs', namevar(coef_name)
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

capture program drop _eplot_label_text
program define _eplot_label_text
    // Put row i of a string variable into the caller's local macname as
    // graph text.  Graph text is macro-expanded again when it is drawn, so
    // a ` or $ in a label would be expanded (`x' and $x vanish, a lone `
    // fails with r(132)), and "' would close the compound quote around the
    // label.  {c 96}, {c 36} and {c 39} draw those characters exactly.
    // Braces are left alone when they balance, so markup such as {it:...}
    // still works; an unbalanced brace ("A}B") would close a {bf:...}
    // wrapper early, so then every brace is drawn as {c 123} or {c 125}.
    version 16.0
    args macname var obs
    local _src `"_st_sdata(`obs', st_varindex("`var'"))"'
    mata: st_local("_bb", strofreal( ///
        min((0, runningsum((ascii(`_src') :== 123) - (ascii(`_src') :== 125)))) < 0 | ///
        sum((ascii(`_src') :== 123) - (ascii(`_src') :== 125)) != 0))
    if `_bb' {
        mata: st_local("t", subinstr(subinstr(subinstr(subinstr(subinstr( ///
            subinstr(subinstr(`_src', "{", char(1)), "}", char(2)), ///
            char(96), "{c 96}"), char(36), "{c 36}"), char(39), "{c 39}"), ///
            char(1), "{c 123}"), char(2), "{c 125}"))
    }
    else {
        mata: st_local("t", subinstr(subinstr(subinstr(`_src', ///
            char(96), "{c 96}"), char(36), "{c 36}"), char(39), "{c 39}"))
    }
    c_local `macname' `"`t'"'
end

// -----------------------------------------------------------------------------
// Graph-assembly helpers shared by data, estimates, and matrix modes.  Each
// returns into fixed caller locals with c_local, not s(): the sreturn state
// left by the sclass helpers they call is then exactly what the modes left
// before these were factored out.  Numeric values pass as strings, so the
// caller sees the same text it would have computed itself.
// -----------------------------------------------------------------------------

capture program drop _eplot_axis_range
program define _eplot_axis_range, nclass
    // Effect-axis ticks, the padded range widened to every labelled tick,
    // and whether the null line can be drawn.  Sets the caller's locals
    // _effect_axis_opts, xmin_pad, xmax_pad, and _refl_nonull.
    version 16.0
    local _orig_varabbrev = c(varabbrev)
    set varabbrev off
    capture noisily {
        syntax, MIN(string) MAX(string) MINPad(string) MAXPad(string) ///
            NULL(string) [XLABel(string asis) XLINEPos(string) LOGScale ///
            NOGRid NONULL VALues HORizontal]

        if `"`xlabel'"' != "" {
            _eplot_effect_axis_labels, min(`min') max(`max') ///
                xlabel(`xlabel') `logscale' `nogrid'
        }
        else {
            _eplot_effect_axis_labels, min(`min') max(`max') `logscale' `nogrid' ///
                `=cond("`nonull'" == "", "null(`null')", "")'
        }
        local _axisopts `"`s(axisopts)'"'
        // The effect range must reach every labelled tick.  twoway widens a
        // linear axis to its labels, but on a log axis a tick outside range()
        // is drawn off the axis or dropped at rc=0, so eplot widens it itself.
        _eplot_tick_range, spec(`"`_axisopts'"') `logscale' ///
            xline(`xlinepos')
        if "`s(min)'" != "" {
            if `s(min)' < `minpad' local minpad = `s(min)'
            if `s(max)' > `maxpad' local maxpad = `s(max)'
        }
        // The null line is not added to the range (a plot whose intervals all
        // exclude it keeps its data range), so say when it cannot be drawn.
        // A values column already extends the right end past a null above the
        // data.  twoway does not clip an xline() to range(), so an off-range
        // null line is not emitted at all.
        local _refl_nonull "`nonull'"
        if "`nonull'" == "" & (`null' < `minpad' | (`null' > `maxpad' & ///
            !("`values'" != "" & "`horizontal'" != ""))) {
            display as text "(note: the null line at `null' lies outside the plotted range and is not drawn; include it in xlabel() or xline(), or specify nonull)"
            local _refl_nonull "nonull"
        }
        c_local _effect_axis_opts `"`_axisopts'"'
        c_local xmin_pad `minpad'
        c_local xmax_pad `maxpad'
        c_local _refl_nonull `_refl_nonull'
    }
    local rc = _rc
    set varabbrev `_orig_varabbrev'
    if `rc' exit `rc'
end

capture program drop _eplot_ylabels
program define _eplot_ylabels, nclass
    // Category-axis labels as "pos `"text"'" pairs.  Text comes through
    // _eplot_label_text, so a label is never macro-expanded again.  With
    // rowtype(), blank rows (type 6) get no label and the types in bold()
    // are set in bold; with tag(), only rows whose tag is nonzero are
    // labelled.  Sets the caller's locals ylabels and pos_max.
    version 16.0
    local _orig_varabbrev = c(varabbrev)
    set varabbrev off
    capture noisily {
        syntax, POS(varname) LABel(varname) [ROWType(varname) ///
            BOLD(numlist integer) TAG(varname)]

        local ylabels ""
        // The labels travel in one macro inside the graph command; past
        // c(macrolen) Stata fails with "line too long" deep in the build.
        // The running length (not strlen() of the growing list, which would
        // cost quadratic time) leaves room for the rest of the command.
        local _len 0
        local _cap = c(macrolen) - 65536
        forvalues i = 1/`=_N' {
            if "`tag'" != "" {
                if `tag'[`i'] == 0 continue
            }
            local this_pos = `pos'[`i']
            _eplot_label_text this_label `label' `i'
            if "`rowtype'" != "" {
                local this_type = `rowtype'[`i']
                if `this_type' == 6 continue
                if `: list posof "`this_type'" in bold' {
                    // Graph text does not nest tags: a brace inside
                    // {bf:...} (a {c #} code or the label's own) closes it
                    // early, so such text is set bold with the {bf} switch.
                    if strpos(`"`this_label'"', "{") | strpos(`"`this_label'"', "}") {
                        local this_label `"{bf}`this_label'"'
                    }
                    else local this_label `"{bf:`this_label'}"'
                }
            }
            local _len = `_len' + strlen(`"`this_label'"') + strlen("`this_pos'") + 6
            if `_len' > `_cap' {
                display as error "too many rows to label: the axis labels of `=_N' rows exceed Stata's macro length limit (c(macrolen) = `c(macrolen)')"
                display as error "plot fewer rows, or raise the limit with {help set_maxvar:set maxvar}"
                exit 920
            }
            local ylabels `"`ylabels' `this_pos' `"`this_label'"'"'
        }
        quietly summarize `pos', meanonly
        local pos_max = r(max)
        c_local ylabels `"`ylabels'"'
        c_local pos_max `pos_max'
    }
    local rc = _rc
    set varabbrev `_orig_varabbrev'
    if `rc' exit `rc'
end

capture program drop _eplot_reflines_all
program define _eplot_reflines_all, nclass
    // Reference lines: one _eplot_build_reflines pass per xline()
    // specification, the null line from the first pass only.  Labelled
    // lines put their text at labpos().  Sets the caller's locals
    // refline_cmd and refline_text.
    version 16.0
    local _orig_varabbrev = c(varabbrev)
    set varabbrev off
    capture noisily {
        syntax, NULL(string) LO(string) HI(string) LABPos(string) ///
            [SPECs(string asis) NULLopts(string asis) HORizontal NONULL ///
            LOGScale]

        local refline_cmd ""
        local refline_text ""
        local _refl_null "`nonull'"
        local _xs_rest `"`specs'"'
        local _xs_more 1
        while `_xs_more' {
            gettoken _xs _xs_rest : _xs_rest
            local _xline_opt ""
            if `"`_xs'"' != "" local _xline_opt `"xline(`_xs')"'
            local _null_style ""
            if `"`nullopts'"' != "" local _null_style `"nullopts(`nullopts')"'
            _eplot_build_reflines, null(`null') `_xline_opt' `_null_style' ///
                lo(`lo') hi(`hi') ///
                `horizontal' `_refl_null' `logscale' ///
                labpos(`labpos')
            if `"`s(cmd)'"' != "" {
                if `"`refline_cmd'"' != "" local refline_cmd `"`refline_cmd' `s(cmd)'"'
                else local refline_cmd `"`s(cmd)'"'
            }
            if `"`s(textcmd)'"' != "" {
                if `"`refline_text'"' != "" local refline_text `"`refline_text' `s(textcmd)'"'
                else local refline_text `"`s(textcmd)'"'
            }
            local _refl_null "nonull"
            if `"`_xs_rest'"' == "" local _xs_more 0
        }
        c_local refline_cmd `"`refline_cmd'"'
        c_local refline_text `"`refline_text'"'
    }
    local rc = _rc
    set varabbrev `_orig_varabbrev'
    if `rc' exit `rc'
end

capture program drop _eplot_favors_layout
program define _eplot_favors_layout, nclass
    // favors() annotation (horizontal layout only), built before the axes
    // because only labels drawn inside the plot need the extra bottom row.
    // Sets the caller's locals favors_cmd, _fav_inside, _fav_below,
    // _fav_reserve, and _fav_titletop.
    version 16.0
    local _orig_varabbrev = c(varabbrev)
    set varabbrev off
    capture noisily {
        syntax, NULL(string) MINPad(string) MAXPad(string) POSMax(string) ///
            [FAVors(string asis) AXISopts(string asis) LOGScale ///
            SCHeme(string) HORizontal]

        local favors_cmd ""
        local _fav_inside 0
        local _fav_below 0
        local _fav_reserve 0
        local _fav_titletop 0
        if `"`favors'"' != "" & "`horizontal'" != "" {
            local _fav_top = `posmax' + 1.5
            _eplot_build_favors, favors(`favors') null(`null') ///
                minpad(`minpad') maxpad(`maxpad') ///
                axisopts(`axisopts') top(`_fav_top') `logscale' ///
                bottom(`=`posmax' + 1') scheme(`scheme')
            local favors_cmd `"`s(cmd)'"'
            local _fav_inside = `s(inside)'
            local _fav_below = `s(below)'
            if `_fav_below' {
                local _fav_reserve = `s(reserve)'
                local _fav_titletop = `s(titletop)'
            }
        }
        c_local favors_cmd `"`favors_cmd'"'
        c_local _fav_inside `_fav_inside'
        c_local _fav_below `_fav_below'
        c_local _fav_reserve `_fav_reserve'
        c_local _fav_titletop `_fav_titletop'
    }
    local rc = _rc
    set varabbrev `_orig_varabbrev'
    if `rc' exit `rc'
end

capture program drop _eplot_title_axisline
program define _eplot_title_axisline, nclass
    // The top of the category axis, the effect-axis title (centred on the
    // plot region or, with atnull, on the null), and the axis line eplot
    // draws itself when a values column extends the x range, stopping it at
    // the end of the effect range.  Sets the caller's locals _xscale_max,
    // ypad_hi, _eff_title_opts, _eff_title_after, _axis_drawn, _pr_margin,
    // _pr_rest, and _title_plots (plot layers to append to the command).
    version 16.0
    local _orig_varabbrev = c(varabbrev)
    set varabbrev off
    capture noisily {
        syntax, NULL(string) LO(string) HI(string) POSMax(string) ///
            HASVals(integer) [VALXpos(string) TEXT(string asis) ATNULL ///
            HORizontal LOGScale PASSthru(string asis) PLOTRegion(string asis) ///
            FAVInside(integer 0) RESERVE(string) TITLETop(string) ///
            XLABSpec(string asis)]

        local _xscale_max = `hi'
        if `hasvals' local _xscale_max = `valxpos'
        // With a values column the x range runs on past the effect axis, so
        // the effect title is centred on the visible axis, lo() to hi(), not
        // on the plot region (a geometric midpoint on a log scale).
        local _centeropt ""
        if `hasvals' & "`horizontal'" != "" & "`atnull'" == "" {
            if "`logscale'" != "" & `lo' > 0 & `hi' > 0 {
                local _mid = exp((ln(`lo') + ln(`hi')) / 2)
            }
            else local _mid = (`lo' + `hi') / 2
            local _centeropt "center(`=string(`_mid', "%18.0g")')"
        }
        local ypad_hi = `posmax' + 1
        if "`horizontal'" != "" & `favinside' local ypad_hi = `posmax' + 2
        _eplot_effect_title, null(`null') lo(`lo') ///
            hi(`=cond("`horizontal'" != "", `_xscale_max', `hi')') ///
            at(`posmax') text(`text') ///
            size(`=cond(`hasvals', "medsmall", "")') ///
            `atnull' `horizontal' `logscale' passthru(`passthru') ///
            reserve(`reserve') `_centeropt' xlabspec(`xlabspec') ///
            bottom(`=`posmax' + 1') titletop(`titletop')
        local _eff_title_opts `"`s(opts)'"'
        local _eff_title_after `"`s(after)'"'
        local _title_plots `" `s(plot)'"'
        local _axis_drawn 0
        _eplot_plotregion, spec(`plotregion')
        local _pr_margin `"`s(margin)'"'
        local _pr_rest `"`s(rest)'"'
        if `hasvals' & `"`_pr_margin'"' == "" {
            _eplot_axis_line, lo(`lo') hi(`hi') y(`ypad_hi') ///
                passthru(`passthru')
            if `"`s(plot)'"' != "" {
                local _title_plots `"`_title_plots' `s(plot)'"'
                local _axis_drawn 1
            }
        }
        c_local _xscale_max `_xscale_max'
        c_local ypad_hi `ypad_hi'
        c_local _eff_title_opts `"`_eff_title_opts'"'
        c_local _eff_title_after `"`_eff_title_after'"'
        c_local _axis_drawn `_axis_drawn'
        c_local _pr_margin `"`_pr_margin'"'
        c_local _pr_rest `"`_pr_rest'"'
        c_local _title_plots `"`_title_plots'"'
    }
    local rc = _rc
    set varabbrev `_orig_varabbrev'
    if `rc' exit `rc'
end

capture program drop _eplot_axes_opts
program define _eplot_axes_opts, nclass
    // The axis options that open the twoway option list: category labels,
    // both scales, the values-column header, the effect title, and the
    // effect-axis ticks.  The category axis runs from ypadlo() to ypadhi();
    // a values header or labelled reference line lowers its start.  Sets the
    // caller's local _axes_opts, which begins with the comma.
    version 16.0
    local _orig_varabbrev = c(varabbrev)
    set varabbrev off
    capture noisily {
        syntax, LO(string) HI(string) XSCALEMax(string) YPADLo(string) ///
            YPADHi(string) HASVals(integer) AXISDrawn(integer) ///
            REFLText(integer) [YLABels(string asis) LABSize(string) ///
            VALUELabel HORizontal LOGScale TITLEopts(string asis) ///
            AXISopts(string asis) VALXpos(string) VTItle(string) VSize(string)]

        local _logopt ""
        if "`logscale'" != "" local _logopt "log "
        local _vl ""
        if "`valuelabel'" != "" local _vl " valuelabel"
        if "`horizontal'" != "" {
            local _opts `", ylabel(`ylabels', angle(0) labsize(`labsize') nogrid noticks`_vl')"'
            local _opts `"`_opts' ytitle("") xscale(`_logopt'range(`lo' `xscalemax'))"'
            if `axisdrawn' local _opts `"`_opts' xscale(noline)"'
            if `hasvals' {
                // An unbalanced brace would close the {bf:...} wrapper early.
                mata: st_local("_bb", strofreal( ///
                    min((0, runningsum((ascii(st_local("vtitle")) :== 123) - (ascii(st_local("vtitle")) :== 125)))) < 0 | ///
                    sum((ascii(st_local("vtitle")) :== 123) - (ascii(st_local("vtitle")) :== 125)) != 0))
                if `_bb' {
                    mata: st_local("vtitle", subinstr(subinstr(subinstr(subinstr( ///
                        st_local("vtitle"), "{", char(1)), "}", char(2)), ///
                        char(1), "{c 123}"), char(2), "{c 125}"))
                }
                local _val_hdr_y = 0.3
                local ypadlo = cond(`ypadlo' < -0.2, `ypadlo', -0.2)
                local _vbf `"{bf:`vtitle'}"'
                if strpos(`"`vtitle'"', "{") | strpos(`"`vtitle'"', "}") {
                    local _vbf `"{bf}`vtitle'"'
                }
                local _opts `"`_opts' text(`_val_hdr_y' `valxpos' `"`_vbf'"', size(`vsize') placement(e) justification(left))"'
            }
            local _opts `"`_opts' `titleopts'"'
            local _opts `"`_opts' xlabel(`axisopts')"'
            local _lab_lo = cond(`hasvals', -0.85, -0.2)
            if `refltext' & `ypadlo' > `_lab_lo' local ypadlo = `_lab_lo'
            local _opts `"`_opts' yscale(reverse noline range(`ypadlo' `ypadhi'))"'
        }
        else {
            local _opts `", xlabel(`ylabels', angle(45) labsize(`labsize') nogrid`_vl')"'
            local _opts `"`_opts' xscale(range(`ypadlo' `ypadhi'))"'
            local _opts `"`_opts' xtitle("") `titleopts' yscale(`_logopt'range(`lo' `hi'))"'
            local _opts `"`_opts' ylabel(`axisopts')"'
        }
        c_local _axes_opts `"`_opts'"'
    }
    local rc = _rc
    set varabbrev `_orig_varabbrev'
    if `rc' exit `rc'
end

capture program drop _eplot_plotregion_use
program define _eplot_plotregion_use, nclass
    // The plotregion() eplot emits.  A values column needs a right margin;
    // a user plotregion() is merged with it, which it would otherwise
    // replace, clipping the column.  favors(, below) hangs its text from the
    // bottom edge of the plot region, so the axis must run along that edge.
    // Sets the caller's local _plotregion_use.
    version 16.0
    local _orig_varabbrev = c(varabbrev)
    set varabbrev off
    capture noisily {
        syntax, HASVals(integer) AXISDrawn(integer) FAVBelow(integer) ///
            [PLOTRegion(string asis) PRMargin(string asis) ///
            PRRest(string asis) VALMargin(string) HORizontal]

        local _use `"`plotregion'"'
        if `"`_use'"' == "" & `hasvals' {
            local _use "margin(l+2 r+`valmargin' t+2 b+2)"
            if `axisdrawn' local _use "margin(l+2 r+`valmargin' t+2 b=0)"
        }
        else if `"`_use'"' != "" & "`horizontal'" != "" & `hasvals' {
            if `"`prmargin'"' == "" {
                local _pr_m "l+2 r+`valmargin' t+2 b+2"
                if `axisdrawn' local _pr_m "l+2 r+`valmargin' t+2 b=0"
            }
            else {
                local _pr_m `"`prmargin'"'
                local _pr_explicit 1
                local _pr_has_r 0
                foreach _tok of local prmargin {
                    if !regexm(`"`_tok'"', "^[lrtb][-+=][0-9]*\.?[0-9]+$") local _pr_explicit 0
                    if substr(`"`_tok'"', 1, 1) == "r" local _pr_has_r 1
                }
                if `_pr_explicit' & !`_pr_has_r' {
                    local _pr_m `"`prmargin' r+`valmargin'"'
                }
                else {
                    display as text "(note: plotregion(margin()) replaces the values-column margin; widen its right side if the column is clipped)"
                }
            }
            local _use `"margin(`_pr_m') `prrest'"'
        }
        if `favbelow' {
            _eplot_pr_nobottom, spec(`_use') user(`prmargin')
            local _use `"`s(spec)'"'
        }
        c_local _plotregion_use `"`_use'"'
    }
    local rc = _rc
    set varabbrev `_orig_varabbrev'
    if `rc' exit `rc'
end

capture program drop _eplot_graph_tail
program define _eplot_graph_tail, nclass
    // The options that close the twoway command, in a fixed order: scheme,
    // regions, aspect, name, saving, pass-through options, the effect title
    // pieces that must follow them, eplot's axis noline (after any
    // passed-through xscale() line style that would turn the native line
    // back on), and the favors() text.  Sets the caller's local _graph_tail.
    version 16.0
    local _orig_varabbrev = c(varabbrev)
    set varabbrev off
    capture noisily {
        syntax, AXISDrawn(integer) [SCHeme(string) PLOTRegion(string asis) ///
            GRAPHRegion(string asis) ASPect(string) NAME(string) ///
            SAVing(string asis) PASSthru(string asis) AFTER(string asis) ///
            FAVors(string asis)]

        local _tail ""
        if "`scheme'" != "" local _tail `"`_tail' scheme(`scheme')"'
        if `"`plotregion'"' != "" local _tail `"`_tail' plotregion(`plotregion')"'
        if `"`graphregion'"' != "" local _tail `"`_tail' graphregion(`graphregion')"'
        if "`aspect'" != "" local _tail `"`_tail' aspect(`aspect')"'
        if "`name'" != "" local _tail `"`_tail' name(`name')"'
        if `"`saving'"' != "" local _tail `"`_tail' saving(`saving')"'
        if `"`passthru'"' != "" local _tail `"`_tail' `passthru'"'
        if `"`after'"' != "" local _tail `"`_tail' `after'"'
        if `axisdrawn' local _tail `"`_tail' xscale(noline)"'
        if `"`favors'"' != "" local _tail `"`_tail' `favors'"'
        c_local _graph_tail `"`_tail'"'
    }
    local rc = _rc
    set varabbrev `_orig_varabbrev'
    if `rc' exit `rc'
end

capture program drop _eplot_rowstripe
program define _eplot_rowstripe, nclass
    // Row names of a returned matrix from a string variable, one row at a
    // time, in data order (or in the order of index() when given).  Each
    // name is read in Mata and passed with macval(), so ` and $ are kept as
    // typed; a name Stata cannot store in a stripe (a "." read as an
    // operator, more than 32 characters, an empty label) becomes row# for
    // that row only, where a single failure used to rename every row.  A
    // name is stored exactly as matrix rownames would store it ("eq:name"
    // sets the equation).
    version 16.0
    local _orig_varabbrev = c(varabbrev)
    set varabbrev off
    capture noisily {
        syntax name(name=mat) [if] [in], NAMEvar(varname string) ///
            [INDex(varname numeric)]
        marksample sel, novarlist
        quietly count if `sel'
        if r(N) != rowsof(`mat') {
            display as error "_eplot_rowstripe: `r(N)' names for `=rowsof(`mat')' rows"
            exit 459
        }
        tempname one
        tempvar req rnm
        matrix `one' = J(1, 1, .)
        quietly gen str244 `req' = ""
        quietly gen str244 `rnm' = ""
        local k 0
        forvalues i = 1/`=_N' {
            if !`sel'[`i'] continue
            local ++k
            mata: st_local("nm", _st_sdata(`i', st_varindex("`namevar'")))
            capture matrix rownames `one' = `"`macval(nm)'"'
            if _rc | `"`macval(nm)'"' == "" matrix rownames `one' = row`k'
            mata: st_sstore(`i', st_varindex("`req'"), st_matrixrowstripe("`one'")[1, 1])
            mata: st_sstore(`i', st_varindex("`rnm'"), st_matrixrowstripe("`one'")[1, 2])
        }
        if "`index'" != "" {
            mata: st_matrixrowstripe("`mat'", ///
                st_sdata(., ("`req'", "`rnm'"), "`sel'")[order(st_data(., "`index'", "`sel'"), 1), .])
        }
        else {
            mata: st_matrixrowstripe("`mat'", st_sdata(., ("`req'", "`rnm'"), "`sel'"))
        }
    }
    local rc = _rc
    set varabbrev `_orig_varabbrev'
    if `rc' exit `rc'
end

capture program drop _eplot_excluded_list
program define _eplot_excluded_list, nclass
    // Name the rows an expression selects: the labels() text, else the
    // observation number; at most five, then a count of the rest.  Labels
    // are user text, so they are read in Mata and carried with macval(),
    // never re-expanded (a lone ` or a $name must print as typed).
    version 16.0
    syntax anything(name=cond everything) [, LABels(string) ERRor OUTside]
    tempvar _sel
    quietly gen byte `_sel' = (`cond')
    quietly count if `_sel'
    local N = r(N)
    local list ""
    local shown 0
    forvalues i = 1/`=_N' {
        if !`_sel'[`i'] continue
        if `shown' == 5 continue, break
        local item ""
        if "`labels'" != "" {
            mata: st_local("item", strtrim(_st_sdata(`i', st_varindex("`labels'"))))
        }
        if `"`macval(item)'"' == "" local item "obs `i'"
        // Braced: a one-line if re-expands its command after macval().
        if `shown' {
            local list `"`macval(list)', `macval(item)'"'
        }
        else {
            local list `"`macval(item)'"'
        }
        local ++shown
    }
    if `N' > `shown' {
        local list `"`macval(list)', and `=`N' - `shown'' more"'
    }
    if "`error'" != "" {
        display as error "confidence limits must be supplied as complete lower/upper pairs;"
        display as error `"`N' effect row(s) have exactly one missing limit: `macval(list)'"'
    }
    else if "`outside'" != "" {
        display as text `"(note: `N' row(s) have an estimate outside their own interval: `macval(list)';"'
        display as text "  check the order of esvar, lcivar, and ucivar)"
    }
    else {
        display as text `"(note: `N' row(s) not plotted because the estimate or the interval is missing: `macval(list)';"'
        display as text "  give them type() code 2 to show them as labelled rows, with vmissing() text)"
    }
end

capture program drop _eplot_matrix_coefnames
program define _eplot_matrix_coefnames, sclass
    version 16.0
    local _orig_varabbrev = c(varabbrev)
    set varabbrev off
    capture noisily {
        syntax, Matrix(name) [NFIX(string)]

        // NFIX(#) < colsof(): only the first # columns are effects (the
        // fixed part of mixed), so only they decide whether names need their
        // equation prefix; the remaining columns keep their full names.
        local k = colsof(`matrix')
        local nf = real("`nfix'")
        if missing(`nf') | `nf' >= `k' | `nf' < 1 local nf = `k'
        tempname _sub
        matrix `_sub' = `matrix'[1, 1..`nf']
        local names : colnames `_sub'
        local unique_names : list uniq names
        local n_names : word count `names'
        local n_unique : word count `unique_names'
        if `n_unique' < `n_names' {
            local names : colfullnames `_sub'
        }
        if `nf' < `k' {
            local _full : colfullnames `matrix'
            forvalues j = `=`nf' + 1'/`k' {
                local names `"`names' `: word `j' of `_full''"'
            }
        }

        sreturn clear
        sreturn local names `"`names'"'
    }
    local rc = _rc
    set varabbrev `_orig_varabbrev'
    if `rc' exit `rc'
end

// Validate that SPEC is exactly one Stata colorstyle ([G-4] colorstyle): a
// named style (a color-<name>.style file on the adopath, or none, bg,
// background, fg, foreground), "# # #" RGB, "# # # #" CMYK, or "hsv # # #",
// each optionally followed by *# intensity and/or %# opacity; a bare *# or
// %# is also valid.  twoway does not refuse anything else: a list or an
// unknown name only prints "named style ... not found" and draws the default
// color at rc=0, so eplot refuses it here with r(198).
// msize() and ciwidth() must each be one size ([G-4] markersizestyle,
// [G-4] linewidthstyle): a named style with a symbolsize-/linewidth-<name>
// .style file on the adopath, a number, *#, or # with a pt, in, cm, or rs
// unit; scheme() must name a scheme-<name>.scheme file.  twoway refuses
// none of these: an unknown name or a list prints a note and draws the
// default at rc=0, and an unknown scheme falls back to s2color.
capture program drop _eplot_check_gstyles
program define _eplot_check_gstyles, nclass
    version 16.0
    local _orig_varabbrev = c(varabbrev)
    set varabbrev off
    capture noisily {
        syntax [, MSIZE(string) CIWIDTH(string) SCHEME(string)]
        foreach _o in msize ciwidth {
            local v = strtrim(`"``_o''"')
            if `"`v'"' == "" continue
            local _cls = cond("`_o'" == "msize", "symbolsize", "linewidth")
            // [G-4] size: #, #pt, #in, #cm, #rs, or *#, with # any
            // nonnegative number Stata reads (1., .5, 1e1); or a named style
            // installed as <class>-<name>.style (12-pt is one).
            local _ok 0
            local _num `"`v'"'
            if substr(`"`_num'"', 1, 1) == "*" local _num = substr(`"`_num'"', 2, .)
            if inlist(substr(`"`_num'"', -2, .), "pt", "in", "cm", "rs") & ///
                substr(`"`v'"', 1, 1) != "*" {
                local _num = substr(`"`_num'"', 1, strlen(`"`_num'"') - 2)
            }
            // One token (1 pt is a size and a stray word to twoway) and a
            // finite value (1e400 reads as missing).
            capture confirm number `_num'
            if _rc == 0 & strpos(`"`v'"', " ") == 0 {
                if real(`"`_num'"') >= 0 & !missing(real(`"`_num'"')) local _ok 1
            }
            if !`_ok' & regexm(`"`v'"', "^[A-Za-z0-9_][A-Za-z0-9_-]*$") {
                capture findfile `_cls'-`v'.style
                if _rc == 0 local _ok 1
            }
            if !`_ok' {
                display as error `"`_o'() must be one valid size, not {bf:`macval(v)'}"'
                display as error "use a size name (e.g. small, medium, thick), a number, *#, or #pt"
                exit 198
            }
        }
        local v = strtrim(`"`scheme'"')
        if `"`v'"' != "" {
            local _ok 0
            if regexm(`"`v'"', "^[A-Za-z_][A-Za-z0-9_]*$") {
                capture findfile scheme-`v'.scheme
                if _rc == 0 local _ok 1
            }
            if !`_ok' {
                display as error `"scheme `macval(v)' not found"'
                exit 198
            }
        }
    }
    local rc = _rc
    set varabbrev `_orig_varabbrev'
    if `rc' exit `rc'
end

capture program drop _eplot_check_color
program define _eplot_check_color, nclass
    version 16.0
    local _orig_varabbrev = c(varabbrev)
    set varabbrev off
    capture noisily {
        syntax , OPTion(name) [SPEC(string asis)]

        local v = strtrim(`"`spec'"')
        local _len = length(`"`v'"')
        if `_len' >= 2 & substr(`"`v'"', 1, 1) == `"""' & ///
            substr(`"`v'"', `_len', 1) == `"""' {
            local v = strtrim(substr(`"`v'"', 2, `_len' - 2))
        }
        local _ok 0
        if strpos(`"`v'"', `"""') == 0 {
            if regexm(`"`v'"', "^(.*)%[0-9]*\.?[0-9]+$") local v = strtrim(regexs(1))
            if regexm(`"`v'"', "^(.*)\*[0-9]*\.?[0-9]+$") local v = strtrim(regexs(1))
            local _n : word count `v'
            if `_n' == 0 {
                local _ok 1
            }
            else if `_n' == 1 {
                if inlist(`"`v'"', "none", "bg", "background", "fg", "foreground") {
                    local _ok 1
                }
                else if regexm(`"`v'"', "^[A-Za-z_][A-Za-z0-9_]*$") {
                    capture findfile color-`v'.style
                    if _rc == 0 local _ok 1
                }
            }
            else if inlist(`_n', 3, 4) {
                // [G-4] colorstyle: RGB is three integers 0-255; CMYK is
                // four integers 0-255 or four proportions 0-1; HSV is a hue
                // 0-360 and a saturation and value 0-1.  twoway draws the
                // default color for anything else (256 0 0, 1e2 0 0).
                local _first : word 1 of `v'
                local _hsv = (`_n' == 4 & `"`_first'"' == "hsv")
                local _from = cond(`_hsv', 2, 1)
                local _ok 1
                local _allint 1
                local _allprop 1
                forvalues _w = `_from'/`_n' {
                    local _t : word `_w' of `v'
                    if !regexm(`"`_t'"', "^[0-9]*\.?[0-9]+$") {
                        local _ok 0
                        continue
                    }
                    local _x = real(`"`_t'"')
                    if !regexm(`"`_t'"', "^[0-9]+$") | `_x' > 255 local _allint 0
                    if `_x' > 1 local _allprop 0
                    if `_hsv' {
                        if `_w' == 2 & `_x' > 360 local _ok 0
                        if `_w' > 2 & `_x' > 1 local _ok 0
                    }
                }
                if `_ok' & !`_hsv' {
                    if `_n' == 3 & !`_allint' local _ok 0
                    if `_n' == 4 & !`_allint' & !`_allprop' local _ok 0
                }
            }
        }
        if !`_ok' {
            display as error `"`option'() must be one valid color, not {bf:`macval(spec)'}"'
            display as error "use a color name (e.g. navy, navy*.5, navy%50) or a quoted RGB triplet such as " `"""' "0 128 0" `"""'
            exit 198
        }
    }
    local rc = _rc
    set varabbrev `_orig_varabbrev'
    if `rc' exit `rc'
end

// Validate SPEC as a list of at most MAX(#) Stata symbolstyles ([G-4]
// symbolstyle): a synonym from the [G-4] table (O D T S + X A a | V o d s t
// x v Oh Dh Th Sh oh dh th sh p i) or a named style with a
// symbol-<name>.style file on the adopath (circle, smx, point, none, ...).
// twoway does not refuse anything else: an unknown name only prints "named
// style ... not found" and draws the default symbol at rc=0, and extra
// symbols in a list for one scatter series are ignored, so eplot refuses
// both here with r(198), as _eplot_check_color does for colors.  Names are
// case-sensitive, as in twoway.  Stylelist shorthands (".", "=", "..") are
// refused: eplot draws each series itself and has its own default.
capture program drop _eplot_check_symbol
program define _eplot_check_symbol, nclass
    version 16.0
    local _orig_varabbrev = c(varabbrev)
    set varabbrev off
    capture noisily {
        syntax , OPTion(name) MAX(integer) [SPEC(string asis)]

        local _n : word count `spec'
        if `_n' == 0 {
            display as error "`option'() is empty; omit it for the default symbol"
            exit 198
        }
        if `_n' > `max' {
            if `max' == 1 {
                display as error `"`option'() must be one symbol, not {bf:`macval(spec)'}"'
                display as error "one symbol per model is allowed only with several stored estimates"
            }
            else {
                display as error "`option'() with multiple models requires one symbol or exactly one symbol per model (`max')"
            }
            exit 198
        }
        local _syn "O D T S + X A a | V o d s t x v Oh Dh Th Sh oh dh th sh p i"
        foreach _s of local spec {
            local _ok 0
            if `: list _s in _syn' local _ok 1
            else if regexm(`"`_s'"', "^[A-Za-z_][A-Za-z0-9_]*$") {
                capture findfile symbol-`_s'.style
                if _rc == 0 local _ok 1
            }
            if !`_ok' {
                display as error `"`option'(): {bf:`macval(_s)'} is not a marker symbol"'
                display as error "use a symbolstyle such as O, D, T, S, Oh, circle, or diamond_hollow; see {help symbolstyle}"
                exit 198
            }
        }
    }
    local rc = _rc
    set varabbrev `_orig_varabbrev'
    if `rc' exit `rc'
end

// Degrees of freedom for each coefficient of the ACTIVE estimation results,
// stored in the 1 x k matrix named by df() (missing = normal reference).
// Stata's own r(table) uses parameter-specific df when the estimator posts
// them: e(df_mi) after mi estimate, post ([MI] mi estimate: "significance
// levels and confidence intervals ... are based on degrees of freedom that
// is specific to each coefficient") and e(df) after mixed, dfmethod().  A
// vector is used only when its column stripe is identical to e(b)'s;
// otherwise the model-wide e(df_r) applies to every coefficient.
// With v(), the variance matrix named there is replaced by e(V_df) when it
// exists with e(b)'s stripe: after mixed, dfmethod(kroger) the
// Kenward-Roger df pair with the adjusted e(V_df), not e(V), and Stata's
// r(table) uses e(V_df) ([ME] mixed, Stored results).
capture program drop _eplot_coef_df
program define _eplot_coef_df, nclass
    version 16.0
    local _orig_varabbrev = c(varabbrev)
    set varabbrev off
    capture noisily {
        syntax, B(name) DF(name) [V(name)]

        local k = colsof(`b')
        local _bnames : colfullnames `b'
        if "`v'" != "" {
            capture confirm matrix e(V_df)
            if _rc == 0 {
                tempname _vdf
                matrix `_vdf' = e(V_df)
                local _vr : rowfullnames `_vdf'
                local _vc : colfullnames `_vdf'
                if `"`_vr'"' == `"`_bnames'"' & `"`_vc'"' == `"`_bnames'"' {
                    matrix `v' = `_vdf'
                }
            }
        }
        local _found 0
        foreach _cand in df_mi df {
            capture confirm matrix e(`_cand')
            if _rc continue
            tempname _cm
            matrix `_cm' = e(`_cand')
            // Identity, not shape: the stripe must equal e(b)'s exactly.
            local _cnames : colfullnames `_cm'
            if `"`_cnames'"' != `"`_bnames'"' continue
            matrix `df' = `_cm'[1, 1...]
            local _found 1
            continue, break
        }
        if !`_found' {
            matrix `df' = J(1, `k', e(df_r))
        }
        forvalues i = 1/`k' {
            if !missing(`df'[1, `i']) & `df'[1, `i'] <= 0 {
                matrix `df'[1, `i'] = .
            }
        }
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
            POINT(varname numeric) ///
            INCLude(string) ///
            LOGScale ///
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
        // A user-supplied point estimate may lie outside its own interval;
        // the axis must still reach it (and a log axis must reject it if it
        // is nonpositive).
        if "`point'" != "" {
            quietly summarize `point' `if' `in', meanonly
            if r(N) > 0 & r(min) < `xmin' local xmin = r(min)
            if r(N) > 0 & r(max) > `xmax' local xmax = r(max)
        }

        // include() adds the null for favors(), whose labels read away from
        // it.  When the data sit on one side, a quarter of the span is kept
        // beyond the null so the label for the empty side has room.
        if "`include'" != "" {
            if `include' <= `xmin' | `include' >= `xmax' {
                local _side = cond(`include' <= `xmin', -1, 1)
                if `include' < `xmin' local xmin = `include'
                if `include' > `xmax' local xmax = `include'
                if "`logscale'" != "" & `xmin' > 0 & `include' > 0 {
                    local _q = 0.25 * (ln(`xmax') - ln(`xmin'))
                    if `_side' < 0 local xmin = exp(ln(`include') - `_q')
                    else local xmax = exp(ln(`include') + `_q')
                }
                else {
                    local _q = 0.25 * (`xmax' - `xmin')
                    if `_side' < 0 local xmin = `include' - `_q'
                    else local xmax = `include' + `_q'
                }
            }
        }

        local xrange = `xmax' - `xmin'
        if `xrange' == 0 {
            local xrange = abs(`xmax') * 0.1
            if `xrange' == 0 local xrange = 1
        }

        // Linear padding is wrong for a logarithmic axis: on a ratio scale
        // xmin - 0.05*range routinely lands at or below zero, and twoway then
        // squeezes every marker against the axis edge at rc=0 rather than
        // refusing the range.  Pad multiplicatively so both limits stay
        // positive and the pad is 5% of the plotted range in log units.
        local lnrange = .
        if "`logscale'" != "" {
            if `xmin' <= 0 | missing(`xmin') {
                display as error ///
                    "logscale requires strictly positive values; the smallest plotted value is `xmin'"
                exit 198
            }
            local _lnmin = ln(`xmin')
            local _lnmax = ln(`xmax')
            local lnrange = `_lnmax' - `_lnmin'
            if `lnrange' == 0 {
                local lnrange = abs(`_lnmax') * 0.1
                if `lnrange' == 0 local lnrange = ln(2)
            }
            local _min_pad = exp(`_lnmin' - 0.05 * `lnrange')
            local _max_pad = exp(`_lnmax' + 0.05 * `lnrange')
        }
        else {
            local _min_pad = `xmin' - 0.05 * `xrange'
            local _max_pad = `xmax' + 0.05 * `xrange'
        }

        sreturn clear
        sreturn local min "`xmin'"
        sreturn local max "`xmax'"
        sreturn local range "`xrange'"
        sreturn local lnrange "`lnrange'"
        sreturn local min_pad = string(`_min_pad', "%18.0g")
        sreturn local max_pad = string(`_max_pad', "%18.0g")
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
        syntax, MIN(real) MAX(real) [XLABel(string asis) LOGScale NOGRid ///
            NULL(string)]

        local _ticks ""
        local _grid ""
        local _top_nogrid "`nogrid'"
        if trim(`"`xlabel'"') != "" & `"`xlabel'"' != `""""' {
            local _ticks `"`xlabel'"'
            // A user xlabel() replaces eplot's own grid, but the scheme's
            // grid would still draw behind the rows; suppress it unless the
            // user's suboptions ask for one.
            gettoken _xl_ticks _xl_rest : xlabel, parse(",")
            // xlabel(, grid): gettoken returns the leading comma as the
            // token, so the suboptions are everything after it.
            if `"`_xl_ticks'"' == "," {
                local _xl_rest `", `_xl_rest'"'
                local _xl_ticks ""
            }
            local _xl_grid 0
            local _xl_nogrid 0
            if `"`_xl_rest'"' != "" {
                local 0 `"`_xl_rest'"'
                // syntax reads GRID and NOGRID as one on/off pair, so each
                // spelling is detected in its own parse.
                capture syntax [, GRID *]
                if _rc == 0 local _xl_grid = ("`grid'" != "")
                local 0 `"`_xl_rest'"'
                capture syntax [, noGRID *]
                if _rc == 0 local _xl_nogrid = ("`grid'" == "nogrid")
            }
            if `_xl_grid' & "`_top_nogrid'" != "" {
                display as error "nogrid may not be combined with xlabel(..., grid)"
                exit 198
            }
            if !`_xl_grid' & !`_xl_nogrid' {
                if `"`_xl_rest'"' == "" local _grid ", nogrid"
                else local _grid " nogrid"
            }
        }
        else {
            // A linear tick lattice is unusable on a log axis: floor(min/delta)
            // is 0 whenever the range starts below one delta, and an xlabel at
            // 0 drags the log axis onto a value it cannot show.
            if "`logscale'" != "" {
                _eplot_log_ticks, min(`min') max(`max') null(`null')
                local _ticks `"`s(ticks)'"'
            }
            if `"`_ticks'"' == "" {
                // Package-owned 1/2/5 scaling avoids reliance on Stata's
                // undocumented _natscale command while retaining readable ticks.
                local _span = `max' - `min'
                if missing(`_span') | `_span' <= 0 {
                    local _span = max(abs(`max'), 1)
                }
                local _raw = `_span' / 5
                local _power = floor(log10(`_raw'))
                local _base = 10^`_power'
                local _fraction = `_raw' / `_base'
                if `_fraction' <= 1 {
                    local _nice = 1
                }
                else if `_fraction' <= 2 {
                    local _nice = 2
                }
                else if `_fraction' <= 5 {
                    local _nice = 5
                }
                else {
                    local _nice = 10
                }
                local _delta = `_nice' * `_base'
                local _axis_min = floor(`min' / `_delta') * `_delta'
                local _axis_max = ceil(`max' / `_delta') * `_delta'
                if `_axis_min' == `_axis_max' local _axis_max = `_axis_min' + `_delta'
                // The linear fallback must still stay positive on a log axis.
                if "`logscale'" != "" & `_axis_min' <= 0 local _axis_min = `min'
                local _min_text = string(`_axis_min', "%18.0g")
                local _delta_text = string(`_delta', "%18.0g")
                local _max_text = string(`_axis_max', "%18.0g")
                local _ticks `"`_min_text'(`_delta_text')`_max_text'"'
            }
            local _grid ", grid glcolor(gs12) glwidth(vthin)"
            if "`_top_nogrid'" != "" local _grid ", nogrid"
        }
        sreturn clear
        sreturn local axisopts `"`_ticks'`_grid'"'
    }
    local rc = _rc
    set varabbrev `_orig_varabbrev'
    if `rc' exit `rc'
end

capture program drop _eplot_log_ticks
program define _eplot_log_ticks, sclass
    version 16.0
    local _orig_varabbrev = c(varabbrev)
    set varabbrev off
    capture noisily {
        syntax, MIN(real) MAX(real) [NULL(string)]

        local _out ""
        local _lo = `min'
        local _hi = `max'
        // Below a 3-fold spread, ticks at null*r^k for the smallest ratio r
        // giving 4-9 ticks are symmetric about the null on the log axis,
        // where a linear lattice (0.8, 1, 1.2) is not.
        if "`null'" != "" & `_lo' > 0 & `_hi' > 0 & !missing(`_lo', `_hi') & ///
            `_hi' / `_lo' < 3 {
            // Only a null inside the data: the lattice must not widen the
            // axis to reach it.
            if `null' >= `_lo' & `null' <= `_hi' {
                foreach _r in 1.1 1.25 1.5 2 {
                    local _k0 = min(0, floor(ln(`_lo' / `null') / ln(`_r') + 1e-9))
                    local _k1 = max(0, ceil(ln(`_hi' / `null') / ln(`_r') - 1e-9))
                    local _n = `_k1' - `_k0' + 1
                    if `_n' >= 4 & `_n' <= 9 {
                        forvalues _k = `_k0'/`_k1' {
                            local _v = `null' * `_r'^`_k'
                            local _vt = string(`_v', "%18.0g")
                            local _lab = strtrim(string(`_v', "%5.3g"))
                            if substr("`_lab'", 1, 1) == "." local _lab "0`_lab'"
                            local _out `"`_out' `_vt' "`_lab'""'
                        }
                        continue, break
                    }
                }
            }
        }
        // Below a 3-fold spread a log axis is visually linear and a decade
        // lattice would label a range far wider than the data; the caller
        // falls back to linear ticks, which are still positive and valid.
        if `_lo' > 0 & `_hi' > 0 & !missing(`_lo', `_hi') & `_hi' / `_lo' >= 3 {
            // Decade lattices ordered by density.  The first whose tick count
            // reads well on an effect axis wins.
            forvalues _try = 1/3 {
                if `_try' == 1 {
                    local _mant "1 2 5"
                    local _min_n 4
                    local _max_n 9
                }
                else if `_try' == 2 {
                    local _mant "1 1.5 2 3 5 7"
                    local _min_n 4
                    local _max_n 12
                }
                else {
                    local _mant "1"
                    local _min_n 2
                    local _max_n 12
                }

                local _cands ""
                local _p0 = floor(log10(`_lo')) - 1
                local _p1 = ceil(log10(`_hi')) + 1
                forvalues _p = `_p0'/`_p1' {
                    foreach _m of local _mant {
                        local _val = string(`_m' * 10^(`_p'), "%12.0g")
                        local _cands `"`_cands' `_val'"'
                    }
                }
                local _nc : word count `_cands'

                // Widen to the enclosing lattice points so a labelled tick sits
                // at or outside each end of the plotted data.
                local _a 1
                forvalues _i = 1/`_nc' {
                    local _v : word `_i' of `_cands'
                    if `_v' <= `_lo' * (1 + 1e-9) local _a = `_i'
                }
                local _b = `_nc'
                forvalues _i = `_nc'(-1)`_a' {
                    local _v : word `_i' of `_cands'
                    if `_v' >= `_hi' * (1 - 1e-9) local _b = `_i'
                }
                local _n = `_b' - `_a' + 1

                if `_n' >= `_min_n' & `_n' <= `_max_n' {
                    local _out ""
                    forvalues _i = `_a'/`_b' {
                        local _v : word `_i' of `_cands'
                        local _lab "`_v'"
                        if substr("`_lab'", 1, 1) == "." local _lab "0`_lab'"
                        local _out `"`_out' `_v' "`_lab'""'
                    }
                    continue, break
                }
            }
            // Beyond twelve decades no lattice above fits: label every k-th
            // decade (at most twelve ticks) rather than fall through to a
            // linear lattice, which a log axis cannot show.
            if `"`_out'"' == "" {
                local _p0 = floor(log10(`_lo') + 1e-9)
                local _p1 = ceil(log10(`_hi') - 1e-9)
                local _step = max(1, ceil((`_p1' - `_p0') / 11))
                local _p1 = `_p0' + ceil((`_p1' - `_p0') / `_step') * `_step'
                forvalues _p = `_p0'(`_step')`_p1' {
                    local _v = string(10^(`_p'), "%12.0g")
                    local _lab "`_v'"
                    if abs(`_p') > 4 local _lab = "1e" + cond(`_p' < 0, "-", "+") + string(abs(`_p'))
                    if substr("`_lab'", 1, 1) == "." local _lab "0`_lab'"
                    local _out `"`_out' `_v' "`_lab'""'
                }
            }
        }

        sreturn clear
        sreturn local ticks `"`_out'"'
    }
    local rc = _rc
    set varabbrev `_orig_varabbrev'
    if `rc' exit `rc'
end

capture program drop _eplot_guard_scale
program define _eplot_guard_scale, nclass
    version 16.0
    local _orig_varabbrev = c(varabbrev)
    set varabbrev off
    capture noisily {
        // eplot owns the geometry of both axes: it always emits its own
        // xscale()/yscale() with range() (and log/reverse).  Scale options are
        // merged-implicit, so a user copy placed after eplot's is merged into
        // it: style suboptions (lcolor(), lwidth(), fextend, line, ...) pass
        // through, but a geometry suboption would silently override a range
        // eplot computed, so it is refused.  syntax binds only the first
        // occurrence of a repeated option, so every occurrence is checked.
        local _rest `"`0'"'
        local _more 1
        while `_more' {
            local 0 `"`_rest'"'
            capture syntax [, XSCale(string asis) YSCale(string asis) *]
            if _rc | (`"`xscale'"' == "" & `"`yscale'"' == "") {
                local _more 0
                continue
            }
            local _rest `", `options'"'
            foreach _ax in xscale yscale {
                if `"``_ax''"' == "" continue
                // syntax swallows the opposite spelling of an on/off option
                // without reporting it (LOG accepts nolog as a no-op, noLOG
                // accepts log), so parse once per spelling.
                local 0 `", ``_ax''"'
                // twoway accepts range() abbreviated to r(), so match it too.
                capture syntax [, Range(string asis) LOG REVerse ///
                    AXis(string asis) *]
                if _rc {
                    display as error "`_ax'(``_ax'') is not a valid axis scale specification"
                    exit 198
                }
                local _bad ""
                if `"`range'"' != "" local _bad "`_bad' range()"
                if "`log'" != "" local _bad "`_bad' log"
                if "`reverse'" != "" local _bad "`_bad' reverse"
                if `"`axis'"' != "" local _bad "`_bad' axis()"
                local 0 `", ``_ax''"'
                capture syntax [, noLOG noREVerse *]
                if _rc == 0 {
                    if "`log'" == "nolog" local _bad "`_bad' nolog"
                    if "`reverse'" == "noreverse" local _bad "`_bad' noreverse"
                }
                if "`_bad'" != "" {
                    display as error ///
                        "`_ax'() may carry axis style suboptions only;`_bad' not allowed"
                    display as error ///
                        "eplot sets the axis range itself; use logscale for a logarithmic effect axis"
                    exit 198
                }
            }
        }
    }
    local rc = _rc
    set varabbrev `_orig_varabbrev'
    if `rc' exit `rc'
end

capture program drop _eplot_collect_xlines
program define _eplot_collect_xlines, sclass
    version 16.0
    local _orig_varabbrev = c(varabbrev)
    set varabbrev off
    capture noisily {
        // Gathers the bound xline() and every repeat left in the pass-through
        // options: s(specs) holds one compound-quoted spec per occurrence,
        // s(positions) every numeric position (for the axis range), and
        // s(options) the pass-through options without them.
        syntax [, FIRST(string asis) OPTions(string asis)]
        local specs ""
        local positions ""
        local _rest `"`options'"'
        local _cur `"`first'"'
        local _more 1
        while `_more' {
            if `"`_cur'"' != "" {
                local specs `"`specs' `"`_cur'"'"'
                gettoken _pos : _cur, parse(",")
                if `"`_pos'"' != "," {
                    capture numlist `"`_pos'"'
                    if _rc == 0 local positions "`positions' `r(numlist)'"
                }
            }
            local 0 `", `_rest'"'
            capture syntax [, XLine(string asis) *]
            if _rc | `"`xline'"' == "" {
                local _more 0
                continue
            }
            local _cur `"`xline'"'
            local _rest `"`options'"'
        }
        sreturn clear
        sreturn local specs `"`specs'"'
        sreturn local positions = strtrim("`positions'")
        sreturn local options `"`_rest'"'
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
        syntax, NULL(real) [XLine(string asis) HORizontal NONULL LOGScale ///
            LABPos(real 0.3) NULLopts(string asis) LO(string) HI(string)]

        local cmd ""
        local textcmd ""
        if "`nonull'" == "" {
            local _nstyle "lcolor(gs8) lpattern(dash) lwidth(thin)"
            if `"`nullopts'"' != "" local _nstyle `"`nullopts'"'
            if "`horizontal'" != "" {
                local cmd `"xline(`null', `_nstyle')"'
            }
            else {
                local cmd `"yline(`null', `_nstyle')"'
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
            // label() is eplot's own suboption (one string per position); the
            // remaining suboptions are the line style passed to twoway.
            local _xl_labels ""
            local _xl_has_label 0
            if `"`_xl_supp'"' != "" {
                local 0 `", `_xl_supp'"'
                capture syntax [, LABel(string asis) *]
                if _rc == 0 & `"`label'"' != "" {
                    local _xl_labels `"`label'"'
                    local _xl_has_label 1
                    local _xl_supp `"`options'"'
                }
            }
            // label(text ... [, size() color() placement()]): the text
            // runs to the first comma outside quotes.
            local _lab_size "vsmall"
            local _lab_color "gs5"
            local _lab_place "auto"
            if `_xl_has_label' {
                local _work `"`_xl_labels'"'
                // Scan token by token: a leading quoted string would end a
                // single gettoken at its closing quote, not at the comma.
                local _xl_labels ""
                local _lab_rest ""
                local _scan `"`_work'"'
                while `"`_scan'"' != "" {
                    gettoken _tok _scan : _scan, parse(", ") bind quotes
                    if `"`_tok'"' == "," {
                        local _lab_rest `"`_scan'"'
                        local _scan ""
                    }
                    else local _xl_labels `"`_xl_labels' `_tok'"'
                }
                if `"`_lab_rest'"' == "" local _xl_labels `"`_work'"'
                if `"`_lab_rest'"' != "" {
                    local 0 `", `_lab_rest'"'
                    capture syntax [, SIze(string) COLor(string asis) ///
                        PLACEment(string)]
                    // Not label suboptions: an unquoted label with a comma.
                    if _rc {
                        local _xl_labels `"`_work'"'
                        local size ""
                        local color ""
                        local placement ""
                    }
                    if `"`size'"' != "" {
                        capture _eplot_check_textsize, option(size) spec(`"`size'"') default(1)
                        if _rc {
                            display as error `"xline() label() size() must be one valid text size, not {bf:`size'}"'
                            exit 198
                        }
                        local _lab_size `"`s(spec)'"'
                    }
                    if `"`color'"' != "" {
                        capture _eplot_check_color, option(color) spec(`color')
                        if _rc {
                            display as error `"xline() label() color() must be one valid color, not {bf:`macval(color)'}"'
                            exit 198
                        }
                        local _lab_color `"`color'"'
                    }
                    if `"`placement'"' != "" {
                        local placement = lower(strtrim(`"`placement'"'))
                        if !inlist(`"`placement'"', "auto", "e", "w", "ne", "nw", "se", "sw", "c") {
                            display as error "xline() label() placement() must be auto, e, w, ne, nw, se, sw, or c"
                            exit 198
                        }
                        local _lab_place `"`placement'"'
                    }
                }
                local _xl_labels = strtrim(`"`_xl_labels'"')
                if `"`_xl_labels'"' == "" {
                    display as error "xline() label() requires text"
                    exit 198
                }
            }
            if `"`_xl_supp'"' == "" local _xl_supp "lcolor(gs10) lpattern(shortdash)"
            capture noisily numlist "`_xl_pos'"
            local _numlist_rc = _rc
            if `_numlist_rc' == 0 {
                local _xl_values "`r(numlist)'"
                local _n_vals : word count `_xl_values'
                if `_xl_has_label' {
                    local _n_labs : word count `_xl_labels'
                    // One line position takes the whole text as its label,
                    // so label(Women at 18-39) need not be quoted.
                    if `_n_vals' == 1 & `_n_labs' > 1 & ///
                        substr(trim(`"`_xl_labels'"'), 1, 1) != char(34) & ///
                        substr(trim(`"`_xl_labels'"'), 1, 2) != "`" + char(34) {
                        local _xl_labels `"`"`_xl_labels'"'"'
                        local _n_labs 1
                    }
                    if `_n_labs' != `_n_vals' {
                        display as error ///
                            "xline() label() requires one label per line position (`_n_vals')"
                        exit 198
                    }
                }
                local _i 0
                foreach val of local _xl_values {
                    local ++_i
                    if "`logscale'" != "" & `val' <= 0 {
                        display as error ///
                            "xline(`val') cannot be drawn on a logarithmic axis"
                        exit 198
                    }
                    if "`horizontal'" != "" {
                        local cmd `"`cmd' xline(`val', `_xl_supp')"'
                    }
                    else {
                        local cmd `"`cmd' yline(`val', `_xl_supp')"'
                    }
                    if `_xl_has_label' {
                        local _lab : word `_i' of `_xl_labels'
                        if trim(`"`_lab'"') == "" continue
                        // The label sits beside the line at the plot edge
                        // opposite the favors() text, starting just past
                        // the line so the line does not run through it.
                        // A line in the right half of the effect range takes
                        // its label on the left, so the text stays inside
                        // the plot region.
                        if "`horizontal'" != "" {
                            local _pl "`_lab_place'"
                            if "`_pl'" == "auto" {
                                local _pl "e"
                                if "`lo'" != "" & "`hi'" != "" {
                                    if "`logscale'" != "" & `lo' > 0 & `hi' > 0 {
                                        local _mid = exp((ln(`lo') + ln(`hi')) / 2)
                                    }
                                    else local _mid = (`lo' + `hi') / 2
                                    if `val' > `_mid' local _pl "w"
                                }
                            }
                            local _mg ""
                            if inlist("`_pl'", "e", "ne", "se") local _mg " margin(l+1)"
                            if inlist("`_pl'", "w", "nw", "sw") local _mg " margin(r+1)"
                            local textcmd `"`textcmd' text(`labpos' `val' `"`_lab'"', size(`_lab_size') color(`_lab_color') placement(`_pl')`_mg')"'
                        }
                        else {
                            local _pl "`_lab_place'"
                            if "`_pl'" == "auto" local _pl "ne"
                            local textcmd `"`textcmd' text(`val' `labpos' `"`_lab'"', size(`_lab_size') color(`_lab_color') placement(`_pl'))"'
                        }
                    }
                }
            }
        }

        if `_numlist_rc' == 0 {
            sreturn clear
            sreturn local cmd `"`cmd'"'
            sreturn local textcmd `"`textcmd'"'
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
        syntax, FAVors(string asis) NULL(real) TOP(real) ///
            MINPad(real) MAXPad(real) [AXISopts(string asis) LOGScale ///
            BOTTom(real -1) SCHeme(string)]

        // Labels run up to the first comma outside quotes; suboptions follow.
        local _fav_labels ""
        local _fav_rest ""
        local _work `"`favors'"'
        while `"`_work'"' != "" {
            gettoken _tok _work : _work, parse(", ") bind quotes
            if `"`_tok'"' == "," {
                local _fav_rest `", `_work'"'
                local _work ""
            }
            else local _fav_labels `"`_fav_labels' `_tok'"'
        }
        gettoken _fav_left _fav_labels : _fav_labels, bind
        gettoken _fav_right _fav_labels : _fav_labels, bind

        local _left_check = trim(subinstr(`"`_fav_left'"', char(34), "", .))
        local _right_check = trim(subinstr(`"`_fav_right'"', char(34), "", .))
        if `"`_left_check'"' == "" | `"`_right_check'"' == "" | ///
            trim(`"`_fav_labels'"') != "" {
            display as error "favors() requires exactly two nonempty labels"
            exit 198
        }

        // Placement suboptions follow a comma: below puts the labels under
        // the axis tick labels, ends aligns them with the axis ends, and
        // arrows adds direction arrows pointing away from the null.  size()
        // and color() style the text; gap() spaces the labels from the null.
        local 0 `"`_fav_rest'"'
        capture syntax [, BELow ENDs ARRows SIze(string) COLor(string asis) ///
            GAP(string)]
        if _rc {
            display as error "favors() suboptions are below, ends, arrows, size(), color(), and gap()"
            exit 198
        }
        if "`below'" != "" & "`ends'" != "" {
            display as error "favors() suboptions below and ends may not be combined"
            exit 198
        }
        if `"`gap'"' != "" & "`ends'" != "" {
            display as error "favors() suboption gap() may not be combined with ends"
            exit 198
        }
        // gap() is a margin in relative size units, or *# times the default.
        local _gap 1.5
        if `"`gap'"' != "" {
            local gap = strtrim(`"`gap'"')
            if !regexm(`"`gap'"', "^\*?[0-9]*\.?[0-9]+$") {
                display as error `"favors() gap() must be a nonnegative size such as 2 or *2, not {bf:`gap'}"'
                exit 198
            }
            if substr(`"`gap'"', 1, 1) == "*" {
                local _gap = `_gap' * real(substr(`"`gap'"', 2, .))
            }
            else local _gap = real(`"`gap'"')
        }
        if `"`size'"' != "" {
            capture _eplot_check_textsize, option(size) spec(`"`size'"') default(1)
            if _rc {
                display as error `"favors() size() must be one valid text size, not {bf:`size'}"'
                exit 198
            }
            local size `"`s(spec)'"'
        }
        if `"`color'"' != "" {
            capture _eplot_check_color, option(color) spec(`color')
            if _rc {
                display as error `"favors() color() must be one valid color, not {bf:`macval(color)'}"'
                exit 198
            }
        }
        else local color "gs5"

        // The text matches the effect-axis tick labels: an explicit
        // xlabel(, labsize()) is reused, otherwise the scheme's tick_label
        // style applies.  size() overrides both.
        local _ax = strtrim(`"`axisopts'"')
        if substr(`"`_ax'"', 1, 1) == char(34) | ///
            substr(`"`_ax'"', 1, 2) == char(96) + char(34) {
            gettoken _ax : _ax
        }
        local _favsize `"`size'"'
        local _ticksize ""
        gettoken _ax_ticks _ax_rest : _ax, parse(",")
        if `"`_ax_ticks'"' == "," local _ax_rest `", `_ax_rest'"'
        if `"`_ax_rest'"' != "" {
            local 0 `"`_ax_rest'"'
            capture syntax [, LABSize(string) *]
            if _rc == 0 local _ticksize `"`labsize'"'
        }
        if `"`size'"' == "" local size `"`_ticksize'"'

        local _fav_left = trim(`"`_fav_left'"')
        local _fav_right = trim(`"`_fav_right'"')
        if substr(`"`_fav_left'"', 1, 1) == char(34) {
            local _fav_left : word 1 of `_fav_left'
        }
        if substr(`"`_fav_right'"', 1, 1) == char(34) {
            local _fav_right : word 1 of `_fav_right'
        }
        if "`arrows'" != "" {
            local _fav_left `"`=uchar(8592)' `_fav_left'"'
            local _fav_right `"`_fav_right' `=uchar(8594)'"'
        }

        // Each label reads outward from the null: the left label's right
        // edge and the right label's left edge sit gap() from it, whatever
        // the text length, the tick span, or the size of the graph (the gap
        // is in relative size units, which graph combine scales with the
        // text).  A null at or beyond either end of the labelled tick span
        // (the padded axis range without numeric ticks) leaves no room on
        // one side, so the labels move to the axis ends.
        local _lo = `minpad'
        local _hi = `maxpad'
        _eplot_tick_range, spec(`axisopts') `logscale'
        if "`s(min)'" != "" {
            if `s(min)' < `s(max)' {
                local _lo = `s(min)'
                local _hi = `s(max)'
            }
        }
        if "`ends'" == "" & (`null' <= `_lo' | `null' >= `_hi') {
            display as text ///
                "(note: null(`null') is not inside the labelled effect axis; favors() labels placed at the axis ends)"
            local ends "ends"
            local below ""
        }
        if "`below'" != "" & `bottom' < 0 {
            display as error "favors(, below) needs the bottom of the plot region"
            exit 198
        }

        // twoway's axis labels are always centred on their position, so
        // below draws the labels as added text hung from the bottom edge of
        // the plot region (a plot region with no bottom margin, where the
        // axis line runs), which twoway does not clip.  The top margin steps
        // past the tick, the tick-to-label gap, the tick labels, and a gap,
        // all in the relative units the scheme draws the axis in.  Labels of
        // unknown height would be overprinted, so the row then moves into
        // the plot.
        local _reserve 0
        local _titletop 0
        if "`below'" != "" {
            local _ml ""
            if strpos(`"`_ax_ticks'"', char(34) + " " + char(34)) local _ml "multiline"
            _eplot_favors_metrics, scheme(`"`scheme'"') axisrest(`"`_ax_rest'"') ///
                favsize(`"`_favsize'"') `_ml'
            if !`s(ok)' {
                display as text ///
                    `"(note: favors(, below) cannot measure the effect axis with `s(why)'; favors() labels placed inside the plot)"'
                local below ""
            }
            else {
                local _drop = `s(tick)' + `s(tickgap)' + `s(label)' + 1
                local _titletop = `_drop' + `s(favlabel)' + 1
                local _reserve = `s(favlabel)' + 2
            }
        }

        local _tstyle "tstyle(tick_label)"
        if `"`size'"' != "" local _tstyle `"`_tstyle' size(`size')"'
        local _n = string(`null', "%18.0g")
        local _g = string(`_gap', "%18.0g")
        local cmd ""
        if "`ends'" != "" {
            // Anchor each label at its axis end, reading inward.
            local cmd ///
                `"text(`top' `minpad' `"`_fav_left'"', `_tstyle' color(`color') placement(e))"'
            local cmd ///
                `"`cmd' text(`top' `maxpad' `"`_fav_right'"', `_tstyle' color(`color') placement(w))"'
        }
        else if "`below'" != "" {
            local _t = string(`_drop', "%9.4f")
            local _b = string(`bottom', "%18.0g")
            local cmd ///
                `"text(`_b' `_n' `"`_fav_left'"', `_tstyle' color(`color') placement(sw) margin(t=`_t' r=`_g' l=0 b=0))"'
            local cmd ///
                `"`cmd' text(`_b' `_n' `"`_fav_right'"', `_tstyle' color(`color') placement(se) margin(t=`_t' l=`_g' r=0 b=0))"'
        }
        else {
            // A row inside the plot, with the null line running between the
            // labels.  The text carries no opaque box: added text is drawn
            // over every line, a box reaching the null would blank it there,
            // and bmargin() does not move added text.
            local cmd ///
                `"text(`top' `_n' `"`_fav_left'"', `_tstyle' color(`color') placement(w) margin(r=`_g' l=0 t=0 b=0))"'
            local cmd ///
                `"`cmd' text(`top' `_n' `"`_fav_right'"', `_tstyle' color(`color') placement(e) margin(l=`_g' r=0 t=0 b=0))"'
        }

        sreturn clear
        sreturn local cmd `"`cmd'"'
        sreturn local inside = ("`below'" == "")
        sreturn local below = ("`below'" != "")
        sreturn local reserve = string(`_reserve', "%9.4f")
        sreturn local titletop = string(`_titletop', "%9.4f")
    }
    local rc = _rc
    set varabbrev `_orig_varabbrev'
    if `rc' exit `rc'
end

capture program drop _eplot_favors_metrics
program define _eplot_favors_metrics, sclass
    version 16.0
    local _orig_varabbrev = c(varabbrev)
    set varabbrev off
    local _gname ""
    capture noisily {
        // Sizes of the effect axis below the plot region, in relative size
        // units: the outward part of a major tick, the tick-to-label gap, the
        // tick-label height, and the favors() text height.  They come from
        // the scheme the graph uses (loaded by a nodraw graph), overridden
        // by the xlabel() suboptions after the comma.  The fallbacks are
        // s2color's.
        syntax [, SCHeme(string) AXISrest(string asis) FAVsize(string) ///
            MULTIline]
        local _tick "tiny"
        local _gap "half_tiny"
        local _label "medsmall"
        local _pos "outside"
        if `"`scheme'"' == "" local scheme `"`c(scheme)'"'
        tempname _gname
        capture quietly twoway scatteri 0 0, nodraw name(`_gname') ///
            scheme(`scheme')
        if _rc == 0 {
            foreach _k in tick tickgap tick_label {
                local _v `"`.__SCHEME.gsize.`_k''"'
                if `"`_v'"' != "" {
                    if "`_k'" == "tick" local _tick `"`_v'"'
                    if "`_k'" == "tickgap" local _gap `"`_v'"'
                    if "`_k'" == "tick_label" local _label `"`_v'"'
                }
            }
            local _v `"`.__SCHEME.tickposition.axis_tick'"'
            if `"`_v'"' != "" local _pos `"`_v'"'
        }
        // s(ok) 0 says the axis cannot be measured: rotated or multi-line
        // tick labels, or a size in absolute units, whose height in
        // relative units depends on the graph's size.
        local _ok 1
        local _why ""
        if "`multiline'" != "" {
            local _ok 0
            local _why "multi-line tick labels"
        }
        _eplot_gsize, spec(`"`_tick'"') default(1.3888)
        local _tick = `s(val)'
        _eplot_gsize, spec(`"`_gap'"') default(0.6944)
        local _gap = `s(val)'
        _eplot_gsize, spec(`"`_label'"') default(3.4722)
        local _label = `s(val)'

        local _noticks 0
        // asis keeps a caller's compound quotes, which syntax would reject.
        local axisrest = strtrim(`"`axisrest'"')
        if substr(`"`axisrest'"', 1, 2) == char(96) + char(34) {
            gettoken axisrest : axisrest
        }
        if `"`axisrest'"' != "" {
            local 0 `"`axisrest'"'
            capture syntax [, LABSize(string) LABGap(string) TLength(string) ///
                TPosition(string) NOTICKs ANGle(string) *]
            if _rc == 0 {
                local angle = lower(strtrim(`"`angle'"'))
                // 0 or horizontal (any abbreviation) leaves labels level.
                local _level = inlist(`"`angle'"', "", "0") | ///
                    (`"`angle'"' != "" & ///
                    substr("horizontal", 1, length(`"`angle'"')) == `"`angle'"')
                if !`_level' {
                    local _ok 0
                    local _why "rotated tick labels"
                }
                if `"`labsize'"' != "" {
                    _eplot_gsize, spec(`"`labsize'"') default(`_label')
                    local _label = `s(val)'
                    if !`s(ok)' {
                        local _ok 0
                        local _why "xlabel(, labsize(`labsize'))"
                    }
                }
                if `"`labgap'"' != "" {
                    _eplot_gsize, spec(`"`labgap'"') default(`_gap')
                    local _gap = `s(val)'
                    if !`s(ok)' {
                        local _ok 0
                        local _why "xlabel(, labgap(`labgap'))"
                    }
                }
                if `"`tlength'"' != "" {
                    _eplot_gsize, spec(`"`tlength'"') default(`_tick')
                    local _tick = `s(val)'
                    if !`s(ok)' {
                        local _ok 0
                        local _why "xlabel(, tlength(`tlength'))"
                    }
                }
                if `"`tposition'"' != "" local _pos `"`tposition'"'
                if "`noticks'" != "" local _noticks 1
            }
        }
        local _pos = lower(strtrim(`"`_pos'"'))
        if `_noticks' | substr(`"`_pos'"', 1, 1) == "i" local _tick 0
        else if substr(`"`_pos'"', 1, 1) == "c" local _tick = `_tick' / 2

        local _fav = `_label'
        if `"`favsize'"' != "" {
            _eplot_gsize, spec(`"`favsize'"') default(`_label')
            local _fav = `s(val)'
            if !`s(ok)' {
                local _ok 0
                local _why "favors(, size(`favsize'))"
            }
        }

        sreturn clear
        sreturn local tick = `_tick'
        sreturn local tickgap = `_gap'
        sreturn local label = `_label'
        sreturn local favlabel = `_fav'
        sreturn local ok = `_ok'
        sreturn local why `"`_why'"'
    }
    local rc = _rc
    if "`_gname'" != "" capture graph drop `_gname'
    set varabbrev `_orig_varabbrev'
    if `rc' exit `rc'
end

capture program drop _eplot_gsize
program define _eplot_gsize, sclass
    version 16.0
    local _orig_varabbrev = c(varabbrev)
    set varabbrev off
    capture noisily {
        // A size style (named or numeric) in relative size units; *# scales
        // the default.  Anything else, such as an absolute unit (whose
        // relative size depends on the graph's size), returns the default
        // with s(ok) 0.
        syntax, DEFault(real) [SPEC(string)]
        local spec = strtrim(`"`spec'"')
        local val = `default'
        local ok 1
        if `"`spec'"' != "" {
            local ok 0
            if substr(`"`spec'"', 1, 1) == "*" {
                local _m = real(substr(`"`spec'"', 2, .))
                if !missing(`_m') {
                    local val = `default' * `_m'
                    local ok 1
                }
            }
            else if !missing(real(`"`spec'"')) {
                local val = real(`"`spec'"')
                local ok 1
            }
            else {
                tempname _sz
                capture findfile `"gsize-`spec'.style"'
                if _rc == 0 capture .`_sz' = .gsize.new, style(`spec')
                if _rc == 0 {
                    capture local _v = `.`_sz'.val'
                    if _rc == 0 & !missing(`_v') {
                        local val = `_v'
                        local ok 1
                    }
                }
            }
        }
        sreturn local val = `val'
        sreturn local ok = `ok'
    }
    local rc = _rc
    set varabbrev `_orig_varabbrev'
    if `rc' exit `rc'
end

capture program drop _eplot_effect_title
program define _eplot_effect_title, sclass
    version 16.0
    local _orig_varabbrev = c(varabbrev)
    set varabbrev off
    capture noisily {
        // Effect-axis title.  By default twoway centres it on the plot
        // region; atnull writes it as the only label of a second effect axis
        // placed on the same side as the first, so it sits on the null.  The
        // second axis carries the first axis's range and log setting, and an
        // invisible point at the null creates it.  reserve() is the height
        // of favors(, below) text hung under the tick labels, which the
        // title steps over; an atnull title is then hung from the same
        // edge, at bottom(), titletop() below it.
        // center() is the midpoint of the visible effect axis when a values
        // column extends the x range past it: the title is then hung there
        // the same way as an atnull title, since twoway would centre it on
        // the whole plot region, values column included.  A passed-through
        // xtitle() text is then moved there too and blanked on the native
        // title by s(after).
        syntax, NULL(real) LO(real) HI(real) AT(real) ///
            [TEXT(string asis) SIze(string) ATNULL HORizontal LOGScale ///
            PASSthru(string asis) RESERVE(real 0) ///
            BOTTom(real 0) TITLETop(real 0) CENTer(real -999) ///
            XLABSpec(string asis)]

        local _ax = cond("`horizontal'" != "", "x", "y")
        local _sizeopt ""
        if `"`size'"' != "" local _sizeopt `", size(`size')"'
        local _r = string(`reserve', "%9.4f")
        if `reserve' > 0 {
            // An empty title would take no room, so a blank one holds it.
            local _tt `"`text'"'
            gettoken _tt : _tt
            if strtrim(`"`_tt'"') == "" local text `"" ""'
            if `"`size'"' != "" local _sizeopt `", size(`size') margin(t+`_r')"'
            else local _sizeopt `", margin(t+`_r')"'
        }
        local opts `"`_ax'title(`text'`_sizeopt')"'
        local plot ""

        if "`atnull'" != "" & (`null' < `lo' | `null' > `hi') {
            display as text ///
                "(note: null(`null') lies outside the effect axis; effect(, atnull) ignored and the title centred)"
            local atnull ""
        }
        local _centre 0
        if "`atnull'" == "" & `center' != -999 & "`horizontal'" != "" {
            // The centred title is the label of a second x axis and carries
            // only a passed-through xtitle()'s text, size(), and color().
            // Everything else leaves twoway's own title in place: nothing to
            // centre (no effect() or xtitle() text); xtitle("") suppressing
            // it; other xtitle() suboptions (placement, orientation, margin,
            // ...), which the user set to control it; a user axis(2), which
            // the second axis would collide with; xscale(alt), which moves
            // the axis and its title to the top; and xscale(off), which
            // hides both.
            local _tt `"`text'"'
            gettoken _tt : _tt
            local _blank = (strtrim(`"`_tt'"') == "")
            local _native 0
            local _why ""
            // eplot's own xlabel() is not passed through.
            if regexm(`"`passthru' `xlabspec'"', "axis[(][ ]*2[ ]*[)]") local _native 1
            local 0 `", `passthru'"'
            capture syntax [, XTItle(string asis) *]
            if _rc local _native 1
            else if `"`xtitle'"' != "" {
                // A repeated xtitle() is merged by twoway; it is left to it.
                local _xt1 `"`xtitle'"'
                local 0 `", `options'"'
                capture syntax [, XTItle(string asis) *]
                if _rc | `"`xtitle'"' != "" {
                    local _native 1
                    local _why "a repeated xtitle()"
                }
                local xtitle `"`_xt1'"'
                _parse comma _ptext _prest : xtitle
                local _ptext = strtrim(`"`_ptext'"')
                if `"`_ptext'"' == `""""' local _native 1
                else if `"`_ptext'"' != "" local _blank 0
                local 0 `"`_prest'"'
                capture syntax [, SIze(string) COLor(string asis)]
                if _rc & `"`_why'"' == "" {
                    local _native 1
                    local _why "xtitle() options other than size() and color()"
                }
            }
            // xscale() may be repeated; any one of them asking for alt or off.
            local _rest `", `passthru'"'
            local _more 1
            while `_more' & !`_native' {
                local 0 `"`_rest'"'
                capture syntax [, XSCale(string asis) *]
                if _rc | `"`xscale'"' == "" {
                    local _more 0
                    continue
                }
                local _rest `", `options'"'
                local 0 `", `xscale'"'
                capture syntax [, ALT OFF *]
                if _rc == 0 & "`alt'`off'" != "" local _native 1
            }
            if `"`_why'"' != "" {
                display as text ///
                    "(note: `_why' `=cond(substr("`_why'", 1, 2) == "a ", "leaves", "leave")' the axis title to twoway, centred on the plot region, which runs on under the values column)"
            }
            if `_blank' | `_native' local center = -999
        }
        if "`atnull'" == "" & `center' != -999 & "`horizontal'" != "" {
            local atnull "atnull"
            local null = `center'
            local _centre 1
        }
        local _user_text 0
        if "`atnull'" != "" {
            // The title's size and color still come from a passed-through
            // xtitle() (ytitle() when vertical); its text comes from effect(),
            // or, when centring, from that xtitle() if it gives any.
            local _tsize `"`size'"'
            local _tcolor ""
            local _tcol ""
            local 0 `", `passthru'"'
            capture syntax [, XTItle(string asis) YTItle(string asis) *]
            if _rc == 0 {
                local _t `"``_ax'title'"'
                if `"`_t'"' != "" {
                    // _parse comma keeps the text's quotes, so several
                    // quoted lines survive.
                    _parse comma _ttext _trest : _t
                    local _ttext = strtrim(`"`_ttext'"')
                    if !inlist(`"`_ttext'"', "", `""""') & `_centre' {
                        if substr(`"`_ttext'"', 1, 1) == char(34) | ///
                            substr(`"`_ttext'"', 1, 2) == char(96) + char(34) {
                            local text `"`_ttext'"'
                        }
                        else local text `"`"`_ttext'"'"'
                        local _user_text 1
                    }
                    else if !inlist(`"`_ttext'"', "", `""""') {
                        display as error ///
                            "`_ax'title() text may not be combined with effect(, atnull); put the title in effect()"
                        exit 198
                    }
                    local 0 `"`_trest'"'
                    capture syntax [, SIze(string) COLor(string asis) *]
                    if _rc == 0 {
                        if `"`size'"' != "" local _tsize `"`size'"'
                        if `"`color'"' != "" {
                            local _tcolor `" labcolor(`color')"'
                            local _tcol `" color(`color')"'
                        }
                    }
                }
            }
            local _labsize ""
            if `"`_tsize'"' != "" local _labsize `" labsize(`_tsize')"'
            local _log ""
            if "`logscale'" != "" local _log "log "
            local _n = string(`null', "%18.0g")
            local _a = string(`at', "%18.0g")
            local _lo = string(`lo', "%18.0g")
            local _hi = string(`hi', "%18.0g")
            if "`horizontal'" != "" {
                local plot `"(scatteri `_a' `_n', msymbol(none) xaxis(2))"'
                local _angle ""
            }
            else {
                local plot `"(scatteri `_n' `_a', msymbol(none) yaxis(2))"'
                local _angle " angle(90)"
            }
            // An axis label takes several lines only inside compound quotes.
            local _lab `"`text'"'
            local _nlines : word count `text'
            if `_nlines' > 1 local _lab `"`"`text'"'"'
            local opts `"`_ax'title("") `_ax'title("", axis(2)) `_ax'scale(axis(2) `_log'range(`_lo' `_hi') noline alt) `_ax'label(`_n' `_lab', axis(2) noticks nogrid`_angle' labstyle(axis_title)`_labsize'`_tcolor' labgap(*6))"'
            if `reserve' > 0 {
                // Under favors(, below) a second axis would stack under the
                // tick labels, beneath the hung favors row, at a distance
                // twoway sets.  The title is hung from the plot-region edge
                // too, a 1-unit gap under that row, and a blank title in its
                // size holds the room.
                local _ts ""
                if `"`_tsize'"' != "" local _ts `" size(`_tsize')"'
                local _b = string(`bottom', "%18.0g")
                local _m = string(`titletop', "%9.4f")
                local plot ""
                local opts `"xtitle(" ",`_ts' margin(t+`_r')) text(`_b' `_n' `text', tstyle(axis_title)`_ts'`_tcol' placement(s) margin(t=`_m' l=0 r=0 b=0))"'
            }
        }

        // A passed-through xtitle("") comes after these options and would
        // drop the blank title holding the room for favors(, below), so
        // s(after) restores it after the passed-through options.
        local after ""
        if `reserve' > 0 & "`horizontal'" != "" {
            local 0 `", `passthru'"'
            capture syntax [, XTItle(string asis) *]
            if _rc == 0 & `"`xtitle'"' != "" {
                gettoken _ptext : xtitle, parse(",")
                if `"`_ptext'"' != "," {
                    gettoken _ptext : _ptext
                    if strtrim(`"`_ptext'"') == "" {
                        local after `"xtitle(" ", margin(t+`_r'))"'
                    }
                }
            }
        }

        // A centred title that took its text from a passed-through xtitle()
        // blanks that xtitle(), which follows these options, on the native
        // title (keeping the room favors(, below) needs).
        if `_user_text' {
            if `reserve' > 0 {
                local _ts ""
                if `"`_tsize'"' != "" local _ts `" size(`_tsize')"'
                local after `"xtitle(" ",`_ts' margin(t+`_r'))"'
            }
            else local after `"xtitle("")"'
        }

        sreturn clear
        sreturn local opts `"`opts'"'
        sreturn local plot `"`plot'"'
        sreturn local after `"`after'"'
    }
    local rc = _rc
    set varabbrev `_orig_varabbrev'
    if `rc' exit `rc'
end

capture program drop _eplot_axis_line
program define _eplot_axis_line, sclass
    version 16.0
    local _orig_varabbrev = c(varabbrev)
    set varabbrev off
    capture noisily {
        // With a values column the x range runs on to the column, so the
        // axis line would underline it.  eplot draws the line itself from
        // the axis start to the end of the effect range, at the bottom edge
        // of a plot region with no bottom margin.  Line styling passed in
        // xscale() is forwarded; noline, line, or off leaves the axis alone.
        syntax, LO(real) HI(real) Y(real) [PASSthru(string asis)]

        local _style ""
        local _skip 0
        local _rest `", `passthru'"'
        local _more 1
        while `_more' {
            local 0 `"`_rest'"'
            capture syntax [, XSCale(string asis) *]
            if _rc | `"`xscale'"' == "" {
                local _more 0
                continue
            }
            local _rest `", `options'"'
            local 0 `", `xscale'"'
            // twoway accepts these down to two letters (lc(), lw(), ...).
            capture syntax [, LStyle(string) LColor(string asis) ///
                LWidth(string) LPattern(string) LINE OFF *]
            if _rc continue
            if "`line'`off'" != "" local _skip 1
            foreach _o in lstyle lcolor lwidth lpattern {
                if `"``_o''"' != "" local _style `"`_style' `_o'(``_o'')"'
            }
            local 0 `", `xscale'"'
            capture syntax [, noLINE *]
            if _rc == 0 & "`line'" == "noline" local _skip 1
        }

        sreturn clear
        if !`_skip' {
            local _y = string(`y', "%18.0g")
            local _lo = string(`lo', "%18.0g")
            local _hi = string(`hi', "%18.0g")
            sreturn local plot `"(pci `_y' `_lo' `_y' `_hi', lstyle(axisline)`_style')"'
        }
    }
    local rc = _rc
    set varabbrev `_orig_varabbrev'
    if `rc' exit `rc'
end

capture program drop _eplot_pr_nobottom
program define _eplot_pr_nobottom, sclass
    version 16.0
    local _orig_varabbrev = c(varabbrev)
    set varabbrev off
    capture noisily {
        // Sets the bottom plot-region margin of a plotregion() spec to zero,
        // after any margin eplot or the user gave; says so when a user
        // margin may have set the bottom.
        syntax [, SPEC(string asis) USER(string asis)]
        _eplot_plotregion, spec(`spec')
        local _m `"`s(margin)'"'
        local _rest `"`s(rest)'"'
        if `"`user'"' != "" {
            local _sides 1
            foreach _tok of local user {
                if !regexm(`"`_tok'"', "^[lrt][-+=][0-9]*\.?[0-9]+$") local _sides 0
            }
            if !`_sides' {
                display as text "(note: favors(, below) sets the bottom plot-region margin to 0)"
            }
        }
        // A named margin cannot be mixed with side edits, so each one is
        // written out as its four sides first.
        local _out ""
        foreach _tok of local _m {
            if regexm(`"`_tok'"', "^[lrtb][-+=][0-9]*\.?[0-9]+$") | ///
                !missing(real(`"`_tok'"')) {
                local _out `"`_out' `_tok'"'
                continue
            }
            capture findfile `"margin-`_tok'.style"'
            if _rc {
                local _out `"`_out' `_tok'"'
                continue
            }
            tempname _ms
            .`_ms' = .margin.new, style(`_tok')
            local _out `"`_out' l=`.`_ms'.left' r=`.`_ms'.right' t=`.`_ms'.top' b=`.`_ms'.bottom'"'
        }
        local _m = strtrim(`"`_out' b=0"')
        sreturn clear
        sreturn local spec `"margin(`_m') `_rest'"'
    }
    local rc = _rc
    set varabbrev `_orig_varabbrev'
    if `rc' exit `rc'
end

capture program drop _eplot_plotregion
program define _eplot_plotregion, sclass
    version 16.0
    local _orig_varabbrev = c(varabbrev)
    set varabbrev off
    capture noisily {
        // Splits a user plotregion() into its margin() and everything else.
        syntax [, SPEC(string asis)]
        local margin ""
        local rest `"`spec'"'
        if `"`spec'"' != "" {
            local 0 `", `spec'"'
            capture syntax [, Margin(string) *]
            if _rc == 0 {
                local rest `"`options'"'
            }
            else local margin ""
        }
        sreturn clear
        sreturn local margin `"`margin'"'
        sreturn local rest `"`rest'"'
    }
    local rc = _rc
    set varabbrev `_orig_varabbrev'
    if `rc' exit `rc'
end

capture program drop _eplot_parse_export
program define _eplot_parse_export, sclass
    version 16.0
    local _orig_varabbrev = c(varabbrev)
    set varabbrev off
    capture noisily {
        syntax, SPEC(string)
        gettoken _fr _rest : spec, parse(",")
        local _fr = strtrim(`"`_fr'"')
        // confirm name checks only the first word of a list.
        capture confirm name `_fr'
        if _rc | `"`_fr'"' == "" | `: word count `_fr'' != 1 {
            display as error `"export() requires a frame name, not {bf:`_fr'}"'
            exit 198
        }
        local replace ""
        if `"`_rest'"' != "" {
            gettoken _comma _rest : _rest, parse(",")
            local 0 `", `_rest'"'
            capture syntax [, REPLACE]
            if _rc {
                display as error "export() takes one suboption, replace"
                exit 198
            }
        }
        if "`_fr'" == "`c(frame)'" {
            display as error "export() may not name the current frame"
            exit 198
        }
        capture confirm frame `_fr'
        if _rc == 0 & "`replace'" == "" {
            display as error "frame `_fr' already exists; specify export(`_fr', replace)"
            exit 110
        }
        sreturn clear
        sreturn local frame "`_fr'"
        sreturn local replace "`replace'"
    }
    local rc = _rc
    set varabbrev `_orig_varabbrev'
    if `rc' exit `rc'
end

capture program drop _eplot_export
program define _eplot_export, nclass
    version 16.0
    local _orig_varabbrev = c(varabbrev)
    set varabbrev off
    capture noisily {
        // Copies the working variables to a new frame under public names.
        // A two-step rename keeps a source name equal to a target name from
        // colliding.
        syntax varlist, INTO(name) NAMES(namelist) [REPLACE]
        local _nv : word count `varlist'
        local _nn : word count `names'
        if `_nv' != `_nn' {
            display as error "_eplot_export: varlist and names() differ in length"
            exit 198
        }
        if "`replace'" != "" capture frame drop `into'
        frame put `varlist', into(`into')
        local _tmp ""
        forvalues _i = 1/`_nv' {
            local _tmp "`_tmp' __eplot_x`_i'"
        }
        frame `into' {
            rename (`varlist') (`_tmp')
            rename (`_tmp') (`names')
            sort pos
            // Labels read from variable and value labels carry ` and $ as
            // {c 96} and {c 36} (see _eplot_estimates); the frame holds the
            // text as drawn.
            capture confirm string variable label
            if _rc == 0 {
                quietly replace label = subinstr(subinstr(label, ///
                    "{c 96}", char(96), .), "{c 36}", char(36), .)
            }
        }
    }
    local rc = _rc
    set varabbrev `_orig_varabbrev'
    if `rc' exit `rc'
end

capture program drop _eplot_value_text
program define _eplot_value_text, nclass
    version 16.0
    local _orig_varabbrev = c(varabbrev)
    set varabbrev off
    capture noisily {
        // The values-column text "b (ll, ul)[stars]", built the same way in
        // every mode.  A fixed (%f) format with d decimals rounds each cell
        // half away from zero on its decimal value first: string() alone
        // rounds a binary tie to even (12.5 -> "12" at %#.0f), and
        // round(x, 0.01) misses decimal ties such as 2.675, whose binary
        // value lies just below the tie.  |x|*10^d is split into integer and
        // fraction, and a fraction within a few units of double precision of
        // .5 counts as the tie.  The estimate and both limits round alike, a
        // value that rounds to zero prints unsigned (never "-0.00"), and when
        // any cell of a row is too wide for the format (string() then
        // switches it to exponent notation) all three cells of that row use
        // exponent notation.  Other formats (%g, %e) go to string() as given.
        syntax newvarname [if], Vars(varlist numeric min=3 max=3) ///
            Format(string) [SUFfix(varname string)]
        marksample touse, novarlist
        tokenize `vars'
        local _d ""
        if regexm(`"`format'"', "^%-?~?0?[0-9]*[.,]([0-9]+)fc?$") {
            local _d = real(regexs(1))
            tempname _sc
            scalar `_sc' = 10^`_d'
        }
        local _cells ""
        tempvar _sx _fl _anyexp
        forvalues _j = 1/3 {
            tempvar _c`_j' _r`_j'
            if "`_d'" != "" {
                quietly gen double `_sx' = abs(``_j'') * `_sc' if `touse'
                quietly gen double `_fl' = floor(`_sx')
                quietly replace `_fl' = `_fl' + 1 if !missing(`_sx') & ///
                    `_sx' - `_fl' >= 0.5 - min(16 * c(epsdouble) * `_sx', 1e-6)
                quietly gen double `_r`_j'' = cond(``_j'' < 0, -1, 1) * `_fl' / `_sc' if `touse'
                drop `_sx' `_fl'
            }
            else {
                quietly gen double `_r`_j'' = ``_j'' if `touse'
            }
            quietly gen str `_c`_j'' = string(`_r`_j'', "`format'") if `touse'
        }
        if "`_d'" != "" {
            quietly gen byte `_anyexp' = regexm(`_c1', "e[-+]") | ///
                regexm(`_c2', "e[-+]") | regexm(`_c3', "e[-+]")
            // Exponent text shows each value itself: the rounding above is
            // to `_d' decimals, which would print a small limit as 0.00e+00.
            forvalues _j = 1/3 {
                quietly replace `_c`_j'' = string(``_j'', "%`=`_d' + 7'.`_d'e") ///
                    if `_anyexp' & `touse'
            }
        }
        forvalues _j = 1/3 {
            // A left-justified format pads on the right.
            quietly replace `_c`_j'' = strtrim(`_c`_j'')
            quietly replace `_c`_j'' = substr(`_c`_j'', 2, .) ///
                if regexm(`_c`_j'', "^-0([.,]0*)?$")
        }
        local _suf ""
        if "`suffix'" != "" local _suf "+ `suffix'"
        quietly gen str `varlist' = `_c1' + " (" + `_c2' + ", " + `_c3' + ")" ///
            `_suf' if `touse'
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
        syntax varname, HEADer(string asis) [MINimum(integer 18) SCale(real 1) ///
            PASSthru(string asis)]
        // The header arrives as one quoted string.
        gettoken header : header

        // The column must hold its widest text.  Widths are in em from the
        // advance widths of the graph font (Helvetica/Arial metrics, which
        // Stata's default Liberation Sans shares), rounded up to each class's
        // widest glyph: @ 1.02, W M m w 1, & .667, other uppercase .78,
        // digits and other lowercase .556, space . , : .278, ( ) - .333, +
        // .584, % .889, * .389, any non-ASCII character (CJK is full width)
        // 1, anything else .6; the bold header 10% wider.  Text
        // size and margins are both percentages of the graph's smaller
        // dimension, so a width of w em at size s takes w*s margin units;
        // scale() is the values text size relative to vsmall (2.0833).  A
        // flat 0.75 units per character clipped long or large text at the
        // right edge of the graph.
        if missing(`scale') | `scale' <= 0 local scale 1
        tempvar _w
        _eplot_text_em `varlist', generate(`_w')
        quietly summarize `_w', meanonly
        local maxem = cond(r(N) > 0, r(max), 0)
        tempvar _hdr
        quietly gen str244 `_hdr' = `"`macval(header)'"' in 1
        tempvar _hw
        _eplot_text_em `_hdr' in 1, generate(`_hw')
        local hdrem = `_hw'[1] * 1.1
        if missing(`hdrem') local hdrem 0
        if `hdrem' > `maxem' local maxem = `hdrem'
        local right_margin = ceil(`maxem' * 2.0833 * `scale' + 1)
        if `right_margin' < `minimum' local right_margin = `minimum'
        // The column may take at most half of the graph's width (margins are
        // in units of the smaller dimension; 5.5 x 4 inches unless xsize()
        // or ysize() is passed through).  A wider column squeezed the plot
        // region to nothing (r+134 with a long vtitle() at vsize(large)), so
        // it is capped and the text may run past the edge, with a note.
        local _xs 5.5
        local _ys 4
        if regexm(`"`passthru'"', "(^|[ ,])xsize?\(([0-9]*\.?[0-9]+)\)") local _xs = regexs(2)
        if regexm(`"`passthru'"', "(^|[ ,])ysize?\(([0-9]*\.?[0-9]+)\)") local _ys = regexs(2)
        local _cap = floor(0.5 * 100 * `_xs' / min(`_xs', `_ys'))
        if `right_margin' > `_cap' {
            display as text "(note: the values column needs more than half the graph width and may be cut off;"
            display as text "  use a smaller vsize(), a shorter vtitle() or vformat(), or a wider graph with xsize())"
            local right_margin = `_cap'
        }

        sreturn clear
        sreturn local right_margin "`right_margin'"
    }
    local rc = _rc
    set varabbrev `_orig_varabbrev'
    if `rc' exit `rc'
end

// Width of each string in em (see _eplot_value_margin for the metrics).
capture program drop _eplot_text_em
program define _eplot_text_em, nclass
    version 16.0
    local _orig_varabbrev = c(varabbrev)
    set varabbrev off
    capture noisily {
        syntax varname(string) [if] [in], GENerate(name)
        marksample touse, strok
        quietly gen double `generate' = 0 if `touse'
        local _rest `"ustrlen(`varlist')"'
        foreach _cw in "[@]|1.02" "[WMmw]|1" "[&]|.667" "[0-9a-lnoq-vx-z]|.556" ///
            "[A-LN-VX-Z]|.78" "[ .,:]|.278" "[()-]|.333" "[+]|.584" "[%]|.889" ///
            "[*]|.389" "[^\x00-\x7F]|1" {
            gettoken _cls _wt : _cw, parse("|")
            local _wt = substr(`"`_wt'"', 2, .)
            local _n `"(ustrlen(`varlist') - ustrlen(ustrregexra(`varlist', "`_cls'", "")))"'
            quietly replace `generate' = `generate' + `_wt' * `_n' if `touse'
            local _rest `"`_rest' - `_n'"'
        }
        quietly replace `generate' = `generate' + .6 * (`_rest') if `touse'
    }
    local rc = _rc
    set varabbrev `_orig_varabbrev'
    if `rc' exit `rc'
end

capture program drop _eplot_value_anchor
program define _eplot_value_anchor, sclass
    version 16.0
    local _orig_varabbrev = c(varabbrev)
    set varabbrev off
    capture noisily {
        syntax, MIN(real) MAX(real) NULL(real) GAP(real) [AXISopts(string asis) ///
            XLine(string asis) NONULL LOGScale]

        if missing(`gap') | `gap' < 0 {
            display as error "vgap() must be nonmissing and nonnegative"
            exit 198
        }
        // The values column starts right of everything drawn across the
        // effect axis: the widest interval, the null line when it is drawn,
        // and the last labelled tick. Anchoring on the interval alone put the
        // column on the null line whenever every interval sat left of it.
        local _right = `max'
        if "`nonull'" == "" & `null' > `_right' local _right = `null'
        _eplot_tick_range, spec(`axisopts') `logscale' xline(`xline')
        if "`s(max)'" != "" {
            if `s(max)' > `_right' local _right = `s(max)'
        }

        if "`logscale'" != "" {
            local _span = ln(`_right' / `min')
            if missing(`_span') | `_span' <= 0 local _span = ln(2)
            local _xpos = `_right' * exp(`gap' * `_span')
        }
        else {
            local _span = `_right' - `min'
            if missing(`_span') | `_span' <= 0 local _span = max(abs(`_right'), 1)
            local _xpos = `_right' + `gap' * `_span'
        }

        sreturn clear
        sreturn local xpos = string(`_xpos', "%18.0g")
    }
    local rc = _rc
    set varabbrev `_orig_varabbrev'
    if `rc' exit `rc'
end

// Numeric extent of an axis-label spec ("ticks [, suboptions]", optionally
// wrapped in quotes): s(min) and s(max) of the tick positions, empty when no
// position is numeric.  Quoted tokens are tick labels, not positions, and
// everything after the first unquoted comma is suboptions.  Under logscale
// a nonpositive tick cannot be drawn and is refused.  xline() positions,
// when given, also count toward the range.
capture program drop _eplot_tick_range
program define _eplot_tick_range, sclass
    version 16.0
    local _orig_varabbrev = c(varabbrev)
    set varabbrev off
    capture noisily {
        syntax [, SPEC(string asis) LOGScale XLine(string asis)]

        local _s = strtrim(`"`spec'"')
        if substr(`"`_s'"', 1, 1) == char(34) | ///
            substr(`"`_s'"', 1, 2) == char(96) + char(34) {
            gettoken _s : _s
        }
        local _min .
        local _max .
        local _rest `"`_s'"'
        while `"`_rest'"' != "" {
            gettoken _tok _rest : _rest, parse(", ") quotes
            if `"`_tok'"' == "," continue, break
            if strtrim(`"`_tok'"') == "" continue
            if inlist(substr(`"`_tok'"', 1, 1), char(34), char(96)) continue
            capture numlist `"`_tok'"'
            if _rc continue
            foreach _v of numlist `r(numlist)' {
                if "`logscale'" != "" & `_v' <= 0 {
                    display as error ///
                        "xlabel() tick `_v' cannot be drawn on a logarithmic axis"
                    exit 198
                }
                if missing(`_min') | `_v' < `_min' local _min = `_v'
                if missing(`_max') | `_v' > `_max' local _max = `_v'
            }
        }
        // An xline() drawn outside range() lands off the plot region at
        // rc=0, so the range must also reach every requested position.
        // Nonpositive positions on a log axis are refused by
        // _eplot_build_reflines and are skipped here.
        local _refs ""
        if `"`xline'"' != "" {
            gettoken _xl_pos : xline, parse(",")
            if `"`_xl_pos'"' != "," {
                capture numlist `"`_xl_pos'"'
                if _rc == 0 local _refs "`_refs' `r(numlist)'"
            }
        }
        foreach _v of local _refs {
            capture confirm number `_v'
            if _rc continue
            if "`logscale'" != "" & `_v' <= 0 continue
            if missing(`_min') | `_v' < `_min' local _min = `_v'
            if missing(`_max') | `_v' > `_max' local _max = `_v'
        }
        sreturn clear
        if !missing(`_min') {
            sreturn local min = string(`_min', "%18.0g")
            sreturn local max = string(`_max', "%18.0g")
        }
    }
    local rc = _rc
    set varabbrev `_orig_varabbrev'
    if `rc' exit `rc'
end

// Validate that SPEC is one Stata textsizestyle ([G-4] textsizestyle): a
// named style (a gsize-<name>.style file on the adopath), a nonnegative
// relative size # or #rs, an absolute #pt, #in, or #cm, or *# relative to
// eplot's own DEFAULT size.  twoway prints "named style ... not found" for an
// unknown name and draws its default at rc=0, so eplot refuses it here.
// s(spec) is the size to emit (*# is resolved against DEFAULT, because a *#
// in mlabsize() or labsize() would scale the scheme default instead).
// s(val) is the approximate relative size used to widen the values margin;
// absolute units assume the default 4-inch graph height, on which 8pt is
// relative size 2.777 (gsize-small.style).
capture program drop _eplot_check_textsize
program define _eplot_check_textsize, sclass
    version 16.0
    local _orig_varabbrev = c(varabbrev)
    local _fh_open 0
    set varabbrev off
    capture noisily {
        syntax , OPTion(name) SPEC(string) DEFault(real)

        local v = lower(strtrim(`"`spec'"'))
        local _val .
        local _emit `"`v'"'
        if regexm(`"`v'"', "^\*([0-9]*\.?[0-9]+)$") {
            local _val = `default' * real(regexs(1))
            local _emit = string(`_val', "%9.4g")
        }
        else if regexm(`"`v'"', "^([0-9]*\.?[0-9]+)(rs|pt|in|cm)?$") {
            // regexs() of an unmatched optional group prints an error at
            // rc=0, so the unit is read as whatever follows the number.
            local _numtxt = regexs(1)
            local _num = real(`"`_numtxt'"')
            local _unit = substr(`"`v'"', strlen(`"`_numtxt'"') + 1, .)
            if inlist("`_unit'", "", "rs") local _val = `_num'
            else if "`_unit'" == "pt" local _val = `_num' * 2.777 / 8
            else if "`_unit'" == "in" local _val = `_num' * 72 * 2.777 / 8
            else if "`_unit'" == "cm" local _val = `_num' * 72 / 2.54 * 2.777 / 8
        }
        else if regexm(`"`v'"', "^[a-z_][a-z0-9_]*$") {
            capture findfile gsize-`v'.style
            if _rc == 0 {
                tempname _fh
                file open `_fh' using `"`r(fn)'"', read text
                local _fh_open 1
                file read `_fh' _line
                while r(eof) == 0 {
                    if regexm(`"`_line'"', "^[ ]*set[ ]+val[ ]+([0-9]*\.?[0-9]+)") {
                        local _val = real(regexs(1))
                    }
                    file read `_fh' _line
                }
                file close `_fh'
                local _fh_open 0
                // A named style without a readable size still exists; only
                // the margin estimate falls back to eplot's default.
                if missing(`_val') local _val = `default'
            }
        }
        if missing(`_val') {
            display as error `"`option'() must be one valid text size, not {bf:`macval(spec)'}"'
            display as error "use a size name (e.g. vsmall, small, medium), a number, *#, or #pt"
            exit 198
        }
        sreturn clear
        sreturn local spec `"`_emit'"'
        sreturn local val = string(`_val', "%9.4g")
    }
    local rc = _rc
    if `_fh_open' capture file close `_fh'
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
        syntax varname, COEFLabels(string asis) [KEY(varname)]

        local labelvar `varlist'
        local remaining `"`coeflabels'"'

        // Match on an immutable copy of the names, never on the variable
        // being relabelled: a label that equals another coefficient's name
        // must not be matched by a later specification.
        if "`key'" == "" {
            tempvar key
            quietly clonevar `key' = `labelvar'
        }

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

            quietly count if `key' == "`coef'"
            if r(N) == 0 {
                display as error `"coeflabels() coefficient '`coef'' not found"'
                exit 198
            }

            quietly replace `labelvar' = `"`label'"' if `key' == "`coef'"
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
        syntax varname, KEEP(string asis) [FULLname(varname string)]
        if "`fullname'" != "" local fullname "fullname(`fullname')"
        _eplot_select `varlist', mode(keep) terms(`keep') `fullname'
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
        syntax varname [, DROP(string asis) OPTional(string) ///
            FULLname(varname string) KNOWN(string asis)]
        if "`fullname'" != "" local fullname "fullname(`fullname')"
        _eplot_select `varlist', mode(drop) terms(`drop') ///
            optional(`optional') `fullname' known(`known')
    }
    local rc = _rc
    set varabbrev `_orig_varabbrev'
    if `rc' exit `rc'
end

// =============================================================================
// Helper: keep()/drop() selection, one matcher for both
// =============================================================================
// A name or pattern is matched against the plotted name, the name without its
// equation prefix, and (with fullname()) the full eq:name.  Each keep() term
// must match a row, or the command exits r(198) naming it: a typo would
// otherwise select rows silently.  A drop() term must match a row or a name
// in known() (the model's full coefficient set, or the rows before keep(), so
// a term already removed by keep() or omitted as a constrained coefficient is
// not an error).  _cons is exempt in drop(), as are optional() terms (the
// automatic constant drop of noconstant and eform): a model without a
// constant is not an error.

capture program drop _eplot_select
program define _eplot_select, nclass
    version 16.0
    local _orig_varabbrev = c(varabbrev)
    set varabbrev off
    capture noisily {
        syntax varname, MODE(string) [TERMS(string asis) OPTional(string) ///
            FULLname(varname string) KNOWN(string asis)]

        local labelvar `varlist'

        tempvar sel hit basename
        quietly gen byte `sel' = 0
        quietly gen byte `hit' = 0
        quietly gen str244 `basename' = `labelvar'
        quietly replace `basename' = substr(`labelvar', strpos(`labelvar', ":") + 1, .) ///
            if strpos(`labelvar', ":") > 0
        if "`fullname'" == "" local fullname `labelvar'

        local _unmatched ""
        local _n_req : word count `terms'
        local _all `"`terms' `optional'"'
        local _w 0
        foreach pattern of local _all {
            local ++_w
            local _wild = strpos(`"`pattern'"', "*") > 0 | strpos(`"`pattern'"', "?") > 0
            if `_wild' {
                quietly replace `hit' = strmatch(`labelvar', `"`pattern'"') | ///
                    strmatch(`basename', `"`pattern'"') | strmatch(`fullname', `"`pattern'"')
            }
            else {
                quietly replace `hit' = `labelvar' == `"`pattern'"' | ///
                    `basename' == `"`pattern'"' | `fullname' == `"`pattern'"'
            }
            quietly count if `hit'
            local _found = r(N) > 0
            if !`_found' & "`mode'" == "drop" {
                if `_w' > `_n_req' | `"`pattern'"' == "_cons" local _found 1
            }
            if !`_found' & "`mode'" == "drop" {
                foreach _k of local known {
                    local _kb `"`_k'"'
                    if strpos(`"`_k'"', ":") > 0 {
                        local _kb = substr(`"`_k'"', strpos(`"`_k'"', ":") + 1, .)
                    }
                    // The name without omitted/base operators, as a user
                    // writes it: o.c2 -> c2, 1b.rep78 -> 1.rep78,
                    // co.mpg -> c.mpg.
                    local _kn = ustrregexra(`"`_kb'"', "([0-9]+)(bn|bo|ob|b|o|n)\.", "\$1.")
                    local _kn = ustrregexra(`"`_kn'"', "(^|#)(o|b)\.", "\$1")
                    local _kn = ustrregexra(`"`_kn'"', "(^|#)c(o|b)\.", "\$1c.")
                    if `_wild' {
                        if strmatch(`"`_k'"', `"`pattern'"') | ///
                            strmatch(`"`_kb'"', `"`pattern'"') | ///
                            strmatch(`"`_kn'"', `"`pattern'"') local _found 1
                    }
                    else if `"`_k'"' == `"`pattern'"' | `"`_kb'"' == `"`pattern'"' | ///
                        `"`_kn'"' == `"`pattern'"' {
                        local _found 1
                    }
                    if `_found' continue, break
                }
            }
            if !`_found' local _unmatched `"`_unmatched' `pattern'"'
            quietly replace `sel' = 1 if `hit'
        }
        if `"`_unmatched'"' != "" {
            display as error `"`mode'() did not match:`_unmatched'"'
            exit 198
        }

        if "`mode'" == "keep" quietly keep if `sel'
        else quietly drop if `sel'
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
        // All renames apply at once against the ORIGINAL names, so a swap
        // (a=b b=a) and a chain (a=b b=c) mean what they say.  Each old
        // name must exist and may be renamed only once.  Two different
        // originals may share a new name (aligning models); the caller
        // refuses two coefficients of one model on one row.
        syntax varname, REName(string asis)

        local labelvar `varlist'
        local remaining `"`rename'"'
        tempvar orig
        quietly clonevar `orig' = `labelvar'
        local _seen ""

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

            quietly count if `orig' == "`oldname'"
            if r(N) == 0 {
                display as error `"rename() coefficient '`oldname'' not found"'
                exit 198
            }
            if `: list oldname in _seen' {
                display as error `"rename() renames coefficient '`oldname'' more than once"'
                exit 198
            }
            local _seen `"`_seen' `oldname'"'

            quietly replace `labelvar' = `"`newname'"' if `orig' == "`oldname'"
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
        // groups(coefs = "label" ...): the members of each group are moved
        // together, in display order, to the position of the group's first
        // member in display order, and the header goes directly above them.
        // Rows outside every group keep their order.  A coefficient may
        // belong to one group only.  With gap(), a blank row follows every
        // group except the last one displayed.  posvar must hold distinct
        // display positions; it is renumbered 1..N before the header and
        // gap rows are added.
        syntax varlist(min=4 max=4), GRoups(string asis) [GAP(real 0) ///
            GRPvar(varname numeric)]

        tokenize `varlist'
        local posvar `1'
        local labelvar `2'
        local typevar `3'
        local gapflagvar `4'

        local remaining `"`groups'"'
        local n_groups 0
        local group_coefs ""
        local _all_members ""

        if missing(`gap') | `gap' < 0 {
            display as error "gap() must be nonmissing and nonnegative"
            exit 198
        }

        // Pass 1: parse and validate every group.
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
                    // Members are kept as quoted list elements, so a label
                    // with spaces ("Study A") stays one member.
                    local _gc_q `"`"`group_coef'"'"'
                    if `: list _gc_q in _all_members' {
                        display as error `"groups() lists coefficient '`group_coef'' in more than one group"'
                        exit 198
                    }
                    local _all_members `"`_all_members' `_gc_q'"'
                }

                local ++n_groups
                local _gmem_`n_groups' `"`group_coefs'"'
                local _glab_`n_groups' `"`label'"'
                local group_coefs ""
            }
            else {
                local group_coefs `"`group_coefs' `"`token'"'"'
            }
        }

        if trim(`"`group_coefs'"') != "" {
            display as error "groups() requires each coefficient list to be followed by = label"
            exit 198
        }

        // Pass 2: gather each group's members at its first member.
        tempvar key gid ord
        quietly gen double `key' = `posvar'
        quietly gen long `gid' = 0
        quietly gen long `ord' = _n
        forvalues g = 1/`n_groups' {
            foreach group_coef of local _gmem_`g' {
                quietly replace `gid' = `g' if `labelvar' == `"`group_coef'"'
            }
            quietly summarize `posvar' if `gid' == `g', meanonly
            quietly replace `key' = r(min) if `gid' == `g'
        }
        sort `key' `posvar' `ord'
        quietly replace `posvar' = _n
        if "`grpvar'" != "" {
            quietly replace `grpvar' = `gid' if `gid' > 0 // stata-dev-ignore: unchecked-commit — grpvar is the caller's tempvar
        }

        // Pass 3: a header above each group and, with gap(), a blank row
        // after every group but the last one displayed.
        local _last_first = -1
        local _last_g 0
        forvalues g = 1/`n_groups' {
            quietly summarize `posvar' if `gid' == `g', meanonly
            local _first_`g' = r(min)
            local _lastpos_`g' = r(max)
            if r(min) > `_last_first' {
                local _last_first = r(min)
                local _last_g `g'
            }
        }
        forvalues g = 1/`n_groups' {
            local newN = _N + 1
            quietly set obs `newN'
            quietly replace `posvar' = `_first_`g'' - 0.5 in `newN'
            quietly replace `labelvar' = `"`_glab_`g''"' in `newN'
            quietly replace `typevar' = 0 in `newN'
            quietly replace `gapflagvar' = 0 in `newN'

            // The gap sits between the group and the next row's header
            // (at its first member - 0.5), so the two never tie.
            if `gap' > 0 & `g' != `_last_g' {
                local newN = _N + 1
                quietly set obs `newN'
                quietly replace `posvar' = `_lastpos_`g'' + 0.25 in `newN'
                quietly replace `labelvar' = "" in `newN'
                quietly replace `typevar' = 6 in `newN'
                quietly replace `gapflagvar' = 1 in `newN'
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

capture program drop _eplot_block_sort
program define _eplot_block_sort, nclass
    version 16.0
    local _orig_varabbrev = c(varabbrev)
    set varabbrev off
    capture noisily {
        // sort orders effect rows (type 1) by their estimate within blocks:
        // a block is the run of rows between structural rows (headers,
        // pooled, het-info, and blank rows, including those inserted by
        // groups()/headers()), split further by groups() membership.  Each
        // block keeps its own row slots, so a row never moves under another
        // block's header.  Without structure this is a plain global sort.
        // An optional fifth variable marks extra movable rows (base-level
        // reference rows, which sort at the value in esvar).
        syntax varlist(min=4 max=5)
        tokenize `varlist'
        local posvar `1'
        local typevar `2'
        local esvar `3'
        local grpvar `4'
        local movevar `5'

        tempvar ord blk is1 rank slot
        tempfile slots
        quietly gen long `ord' = _n
        sort `posvar' `ord'
        quietly gen long `blk' = sum(inlist(`typevar', 0, 3, 4, 5, 6))
        quietly gen byte `is1' = (`typevar' == 1)
        if "`movevar'" != "" quietly replace `is1' = 1 if `movevar' == 1
        sort `blk' `grpvar' `is1' `posvar' `ord'
        quietly by `blk' `grpvar' `is1': gen long `rank' = _n
        quietly gen double `slot' = `posvar'
        preserve
        quietly keep if `is1'
        quietly keep `blk' `grpvar' `rank' `slot'
        quietly save `slots'
        restore
        drop `rank' `slot'
        sort `blk' `grpvar' `is1' `esvar' `posvar' `ord'
        quietly by `blk' `grpvar' `is1': gen long `rank' = _n
        quietly merge m:1 `blk' `grpvar' `rank' using `slots', ///
            keep(master match) nogenerate
        // Every effect row must receive a slot of its own block.
        quietly count if `is1' & missing(`slot')
        if r(N) > 0 {
            display as error "sort could not place `r(N)' effect row(s)"
            exit 459
        }
        quietly replace `posvar' = `slot' if `is1'
        sort `posvar' `ord'
        drop `ord' `blk' `is1' `rank' `slot'
    }
    local rc = _rc
    set varabbrev `_orig_varabbrev'
    if `rc' exit `rc'
end

capture program drop _eplot_process_headers
program define _eplot_process_headers, nclass
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
            // Above the first row with that label: the mean put a header
            // between duplicate rows (or tied it with the first of two).
            quietly summarize `posvar' if `labelvar' == `"`ref'"', meanonly
            local header_pos = r(min) - 0.5

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

// =============================================================================
// Helper: proportion's confidence limits, from Stata's own table
// =============================================================================
// proportion reports logit-transformed limits by default and, with
// citype(), Wilson, exact, Jeffreys, Agresti-Coull, or Wald limits ([R]
// proportion, Methods and formulas); none is b +/- t*se except Wald, and the
// others need counts that e() does not hold.  Replaying the active results
// at level() yields the table Stata itself prints.  The replay does not
// remember citype() (e() does not store it), so a citype() in e(cmdline) is
// forwarded.  The replayed b row must equal e(b), or nothing is read.
capture program drop _eplot_prop_limits
program define _eplot_prop_limits, nclass
    version 16.0
    local _orig_varabbrev = c(varabbrev)
    set varabbrev off
    capture noisily {
        syntax, B(name) LEVel(real) LL(name) UL(name)
        local _ct ""
        if regexm(`"`e(cmdline)'"', "citype\(([^)]*)\)") {
            local _ct `"citype(`=regexs(1)')"'
        }
        quietly proportion, level(`level') `_ct'
        tempname T
        matrix `T' = r(table)
        local _rb = rownumb(`T', "b")
        local _rl = rownumb(`T', "ll")
        local _ru = rownumb(`T', "ul")
        local _ok = !missing(`_rb') & !missing(`_rl') & !missing(`_ru')
        if `_ok' local _ok = colsof(`T') == colsof(`b')
        if `_ok' {
            tempname _tb
            matrix `_tb' = `T'[`_rb', 1...]
            local _ok = mreldif(`_tb', `b') < 1e-12
        }
        if !`_ok' {
            display as error "could not read the confidence limits of proportion from its coefficient table"
            exit 498
        }
        matrix `ll' = `T'[`_rl', 1...]
        matrix `ul' = `T'[`_ru', 1...]
    }
    local rc = _rc
    set varabbrev `_orig_varabbrev'
    if `rc' exit `rc'
end

// =============================================================================
// Helper: how many leading columns of e(b) are effects
// =============================================================================
// s(nfix) is the number of leading e(b) columns that are effects ("." when
// all are) and s(kind) what follows them: "vc" for the variance components
// that mixed, xtmixed, and the meqr*/xtme* commands post in equations of
// their own after the e(k_f) fixed effects ([ME] mixed; their e(k_f) counts
// parameters, whereas meglm's counts equations, so it is not used there),
// and "anc" for trailing ancillary equations that are not named "/": [R] ml
// display shows the last e(k_aux) equations as /name ancillary parameters
// (intreg's lnsigma, frontier's lnsig2v and lnsig2u, xtologit's cutpoints
// and sigma2_u), and xtreg, mle shows sigma_u and sigma_e that way without
// posting e(k_aux).  Each "/" column is one equation, as e(k_eq) counts
// them; when e(k_eq) is posted and disagrees, nothing is cut.  Must run
// while the model's results are active.
capture program drop _eplot_fixed_cut
program define _eplot_fixed_cut, sclass
    version 16.0
    local _orig_varabbrev = c(varabbrev)
    set varabbrev off
    capture noisily {
        syntax, Matrix(name)
        local k = colsof(`matrix')
        local nfix .
        local kind ""
        if inlist("`e(cmd)'", "mixed", "xtmixed", "meqrlogit", ///
            "meqrpoisson", "xtmelogit", "xtmepoisson") {
            capture confirm integer number `e(k_f)'
            if !_rc {
                if `e(k_f)' >= 1 & `e(k_f)' < `k' {
                    local nfix = `e(k_f)'
                    local kind "vc"
                }
            }
        }
        else {
            local eqs : coleq `matrix'
            local nu 0
            local prev ""
            forvalues j = 1/`k' {
                local e : word `j' of `eqs'
                if "`e'" == "/" | "`e'" != "`prev'" {
                    local ++nu
                    local ufirst_`nu' = `j'
                    local uname_`nu' "`e'"
                }
                local prev "`e'"
            }
            local naux .
            capture confirm integer number `e(k_aux)'
            if !_rc local naux = `e(k_aux)'
            else if "`e(cmd)'" == "xtreg" & "`e(model)'" == "ml" & `nu' >= 3 {
                if "`uname_`=`nu'-1''" == "sigma_u" & "`uname_`nu''" == "sigma_e" {
                    local naux 2
                }
            }
            local keq_ok 1
            capture confirm integer number `e(k_eq)'
            if !_rc {
                if `e(k_eq)' != `nu' local keq_ok 0
            }
            if !missing(`naux') & `keq_ok' {
                if `naux' >= 1 & `naux' < `nu' {
                    forvalues u = `=`nu' - `naux' + 1'/`nu' {
                        if "`uname_`u''" != "/" {
                            local nfix = `ufirst_`u'' - 1
                            local kind "anc"
                            continue, break
                        }
                    }
                }
            }
        }
        sreturn clear
        sreturn local nfix "`nfix'"
        sreturn local kind "`kind'"
    }
    local rc = _rc
    set varabbrev `_orig_varabbrev'
    if `rc' exit `rc'
end

// =============================================================================
// Helper: Equations of e(b) and the equations eform exponentiates
// =============================================================================
// s(eqs) holds one equation name per column ("_" when there is none).
// s(eform_eqs) holds the first KEFORM distinct equations other than "/", in
// stripe order: [R] ml display applies an eform option to the first
// e(k_eform) equations, and to the first equation when e(k_eform) is unset.

capture program drop _eplot_eform_eqs
program define _eplot_eform_eqs, sclass
    version 16.0
    local _orig_varabbrev = c(varabbrev)
    set varabbrev off
    capture noisily {
        syntax, Matrix(name) [KEFORM(string)]

        local k_eform = real("`keform'")
        if missing(`k_eform') | `k_eform' < 1 local k_eform 1

        local eqs : coleq `matrix'
        local distinct : list uniq eqs
        local slash "/"
        local distinct : list distinct - slash
        local eform_eqs ""
        local n_distinct : word count `distinct'
        forvalues j = 1/`=min(`k_eform', `n_distinct')' {
            local eform_eqs "`eform_eqs' `: word `j' of `distinct''"
        }

        sreturn clear
        sreturn local eqs `"`eqs'"'
        sreturn local eform_eqs `"`eform_eqs'"'
    }
    local rc = _rc
    set varabbrev `_orig_varabbrev'
    if `rc' exit `rc'
end

// End of eplot.ado
