*! psdash_balance Version 1.4.1  2026/07/07
*! Covariate balance diagnostics with standardized mean differences
*! Author: Timothy P Copeland, Karolinska Institutet
*! Program class: rclass
*! Adapted from: balancetab v1.1.3

/*
DESCRIPTION:
    Calculates and displays covariate balance diagnostics for propensity score
    analysis. Computes standardized mean differences (SMD) before and after
    weighting, generates Love plots, and exports balance tables.

    Supports binary (0/1) and multi-group (K >= 2) treatments. For multi-group,
    balance is assessed pairwise: each non-reference group vs the reference group.

SYNTAX:
    psdash balance [treatment] [psvar] [if] [in] , [options]

    Treatment and PS can be auto-detected from teffects/logit/probit context.

Options:
    covariates(varlist) - Covariates to assess balance for (auto-detected if omitted)
    wvar(varname)       - Weight variable (auto-generated from PS if omitted)
    matched             - Indicates data has been matched
    threshold(real)     - SMD threshold for imbalance (default: 0.1)
    nowvar              - Skip weight auto-generation from PS
    reference(string)   - Reference group for multi-group (default: lowest level)
    xlsx(string)        - Export balance table to Excel
    sheet(string)       - Excel sheet name (default: "Balance")
    loveplot            - Generate Love plot
    saving(string)      - Save Love plot to file
    scheme(string)      - Graph scheme
    graphoptions(string)- Additional twoway options for Love plot
    format(string)      - Display format for SMD (default: %6.3f)
    title(string)       - Title for output/plot
    name(string)        - Graph name (default: psdash_balance)

STORED RESULTS (binary):
    r(N)            - Total number of observations
    r(N_treated)    - Number in treatment group
    r(N_control)    - Number in control group
    r(max_smd_raw)  - Maximum SMD before adjustment
    r(max_smd_adj)  - Maximum SMD after adjustment (wvar only)
    r(n_imbalanced) - Number of covariates exceeding threshold
    r(threshold)    - Threshold used
    r(balance)      - Matrix of balance statistics
    r(treatment)    - Treatment variable name
    r(varlist)      - Covariates assessed
    r(wvar)         - Weight variable (if specified; "auto-generated" if temporary)

STORED RESULTS (multi-group, additional/changed):
    r(K)                - Number of treatment groups
    r(N_group_<lev>)    - Per-group N
    r(levels)           - Space-separated list of treatment levels
    r(reference)        - Reference group level
*/

program define psdash_balance, rclass
    version 16.0
    local _vao = c(varabbrev)
    set varabbrev off
    local _psdash_side_rc = 0
    local _psdash_return_mode ""

    capture noisily {

    * SYNTAX PARSING
    syntax [anything] [if] [in], ///
        [COVariates(varlist numeric) ///
         Wvar(varname) ///
         MATCHed ///
         THReshold(real 0.1) ///
         NOWvar ///
         NOWeights ///
         REFerence(string) ///
         xlsx(string) ///
         sheet(string) ///
         LOVEplot ///
         SAVing(string) ///
         SCHeme(string) ///
         GRAPHOPTions(string asis) ///
         Format(string) ///
         TItle(string) ///
         name(string) ///
         KS ///
         ESTImand(string) ///
         SMDMatrix(name) ///
         STRATegies(string) ///
         DISTribution(varlist numeric) ///
         VRBounds(numlist min=2 max=2 >0 ascending) ///
         PSVars(varlist numeric)]

    if "`noweights'" != "" {
        local nowvar "nowvar"
    }

    * Variance-ratio imbalance bounds (default [0.5, 2.0]); configurable via vrbounds()
    local vrlo 0.5
    local vrhi 2
    if "`vrbounds'" != "" {
        gettoken vrlo vrhi : vrbounds
        local vrhi = strtrim("`vrhi'")
    }

    * MARK SAMPLE
    tempvar touse ps_auto wt_auto
    * Accept twoway-style name(x, replace) / saving(f, replace) gracefully
    _psdash_strip_replace, option(name) value(`"`name'"')
    local name `"`r(value)'"'
    _psdash_strip_replace, option(saving) value(`"`saving'"')
    local saving `"`r(value)'"'

    mark `touse' `if' `in'  // validator-note: mark+markout pattern is equivalent to marksample

    * AUTO-DETECT PS COMPONENTS
    * For balance, user may provide treatment + wvar (or nowvar) without a PS
    * variable. The detect helper requires psvar for manual mode, so handle
    * the treatment-only case ourselves before falling through to detect.
    local _manual_mg = 0
    local _n_pos_args : word count `anything'
    local _has_est_ctx = inlist("`e(cmd)'", "logit", "probit", "logistic", "mlogit", "teffects")
    if `_n_pos_args' == 1 & ("`wvar'" != "" | "`nowvar'" != "") & !`_has_est_ctx' {
        local ref_manual_opt ""
        if "`reference'" != "" local ref_manual_opt "reference(`reference')"
        local estimand_manual_opt ""
        if "`estimand'" != "" local estimand_manual_opt "estimand(`estimand')"
        _psdash_manual_detect `anything' if `touse', ///
            `ref_manual_opt' `estimand_manual_opt'
        local treatment "`r(treatment)'"
        local psvar ""
        local source "`r(source)'"
        local estimand "`r(estimand)'"
        local wvar_auto "0"
        local multigroup "`r(multigroup)'"
        local K = r(K)
        local levels "`r(levels)'"
        local mg_reference "`r(reference)'"
        local _manual_mg = 1
    }

    local psvars_opt ""
    if "`psvars'" != "" {
        local psvars_opt "psvars(`psvars')"
    }

    if !`_manual_mg' {
        _psdash_detect `anything' , covariates(`covariates') wvar(`wvar') ///
            samplevar(`touse') estimand(`estimand') ///
            psout(`ps_auto') wout(`wt_auto') getwvar ///
            reference(`reference') `psvars_opt'

        local treatment "`_psd_treatment'"
        local psvar "`_psd_psvar'"
        local source "`_psd_source'"
        if "`estimand'" == "" local estimand "`_psd_estimand'"
        local wvar_auto "0"

        * Pick up multi-group detection results
        local multigroup "`_psd_multigroup'"
        if "`multigroup'" == "" local multigroup "0"
        local K = real("`_psd_K'")
        if missing(`K') local K = 2
        local levels "`_psd_levels'"
        local mg_reference "`_psd_reference'"
    }

    * Use detected covariates if not explicitly provided
    if "`covariates'" == "" & "`_psd_covariates'" != "" {
        local covariates "`_psd_covariates'"
    }

    * Use detected weights if not explicitly provided and not suppressed
    if "`wvar'" == "" & "`_psd_wvar'" != "" & "`nowvar'" == "" & "`matched'" == "" {
        local wvar "`_psd_wvar'"
        local wvar_auto "`_psd_wvar_auto'"
    }

    * BRANCH: BINARY vs MULTI-GROUP
    if "`multigroup'" == "0" {
    * BINARY PATH (unchanged from v1.1.9)

    * Auto-generate IPTW weights from PS if no weights available
    if "`wvar'" == "" & "`psvar'" != "" & "`nowvar'" == "" & "`matched'" == "" {
        quietly {
            gen double `wt_auto' = .
            if "`estimand'" == "ate" {
                replace `wt_auto' = 1 / `psvar' ///
                    if `treatment' == 1 & `psvar' > 0 & `touse'
                replace `wt_auto' = 1 / (1 - `psvar') ///
                    if `treatment' == 0 & `psvar' < 1 & `touse'
            }
            else if "`estimand'" == "att" {
                replace `wt_auto' = 1 ///
                    if `treatment' == 1 & `touse'
                replace `wt_auto' = `psvar' / (1 - `psvar') ///
                    if `treatment' == 0 & `psvar' < 1 & `touse'
            }
            else if "`estimand'" == "atc" {
                replace `wt_auto' = (1 - `psvar') / `psvar' ///
                    if `treatment' == 1 & `psvar' > 0 & `touse'
                replace `wt_auto' = 1 ///
                    if `treatment' == 0 & `touse'
            }
        }
        local wvar "`wt_auto'"
        local wvar_auto "1"
    }

    * Restrict PS diagnostics to the nonmissing PS sample before marking out
    * auto-generated weights; boundary PS values can make weights missing.
    markout `touse' `treatment'
    if "`psvar'" != "" markout `touse' `psvar'

    * Positivity warnings (when PS is available)
    local n_ps_boundary = 0
    local n_ps_near = 0
    if "`psvar'" != "" {
        _psdash_pscheck `psvar' if `touse'
        local n_ps_boundary = r(n_ps_boundary)
        local n_ps_near = r(n_ps_near)
    }

    if "`wvar'" != "" markout `touse' `wvar'

    * Covariates are required for balance assessment
    if "`covariates'" == "" {
        display as error "covariates() required for balance assessment"
        display as error "  specify covariates or run after an estimation command"
        exit 198
    }

    quietly count if `touse'
    if r(N) == 0 {
        display as error "no observations"
        exit 2000
    }
    local N = r(N)

    * Use covariates as the working varlist
    local varlist "`covariates'"

    * VALIDATE INPUTS (binary)
    * Check wvar and matched are mutually exclusive
    if "`wvar'" != "" & "`matched'" != "" {
        display as error "wvar() and matched are mutually exclusive"
        exit 198
    }

    * Validate treatment is binary
    capture assert inlist(`treatment', 0, 1) if `touse'
    if _rc {
        display as error "treatment must be binary (0/1)"
        exit 198
    }

    * Check for variation in treatment
    quietly tab `treatment' if `touse'
    if r(r) != 2 {
        display as error "treatment must have exactly 2 levels"
        exit 198
    }

    * Validate weights if specified
    if "`wvar'" != "" {
        quietly summarize `wvar' if `touse'
        if r(min) < 0 {
            display as error "weights cannot be negative"
            exit 198
        }
        if r(sum) <= 0 {
            display as error "weights must have positive total weight"
            exit 198
        }
        quietly summarize `wvar' if `touse' & `treatment' == 1
        if r(sum) <= 0 {
            display as error "treated observations must have positive total weight"
            exit 198
        }
        quietly summarize `wvar' if `touse' & `treatment' == 0
        if r(sum) <= 0 {
            display as error "control observations must have positive total weight"
            exit 198
        }
    }

    * Validate threshold
    if `threshold' <= 0 {
        display as error "threshold() must be positive"
        exit 198
    }

    * Validate Excel options
    if "`xlsx'" != "" {
        _psdash_validate_path, path(`"`xlsx'"') option(xlsx) extension(xlsx)
    }

    * Validate strategies()/distribution() (F2/F1, binary path)
    local strategies = lower(strtrim("`strategies'"))
    if "`strategies'" != "" {
        if "`psvar'" == "" {
            display as error "strategies() requires a propensity score variable"
            exit 198
        }
        foreach s of local strategies {
            if !inlist("`s'", "raw", "ate", "att", "atc") {
                display as error "strategies() must be a subset of: raw ate att atc"
                exit 198
            }
        }
        local strategies : list uniq strategies
    }
    if "`distribution'" != "" {
        foreach dv of local distribution {
            local _dvok : list dv in varlist
            if !`_dvok' {
                display as error "distribution() variable `dv' is not among the assessed covariates"
                exit 198
            }
        }
    }

    * SET DEFAULTS (binary)
    if "`format'" == "" local format "%6.3f"
    capture confirm format `format'
    if _rc {
        display as error "format() must be a valid Stata display format"
        exit 198
    }
    local format_lc = lower("`format'")
    if substr("`format_lc'", 1, 2) == "%t" | regexm("`format_lc'", "s$") {
        display as error "format() must be a numeric display format"
        exit 198
    }
    if "`sheet'" == "" local sheet "Balance"
    if "`title'" == "" local title "Covariate Balance Assessment"
    if "`name'" == "" local name "psdash_balance"
    local _graphopts0 "`graphoptions'"

    * Count covariates
    local nvars : word count `varlist'

    * Determine if we have weighted adjustment (two-column display)
    local has_adj = ("`wvar'" != "")

    local wvar_opt ""
    if "`wvar'" != "" local wvar_opt "wvar(`wvar')"
    _psdash_balance_binary `varlist', treatment(`treatment') samplevar(`touse') ///
        threshold(`threshold') `wvar_opt' vrlo(`vrlo') vrhi(`vrhi')
    tempname balance_mat
    matrix `balance_mat' = r(balance)
    local n_treated = r(n_treated)
    local n_control = r(n_control)
    local max_smd_raw = r(max_smd_raw)
    local max_smd_adj = r(max_smd_adj)
    local max_vr_raw = r(max_vr_raw)
    local max_vr_adj = r(max_vr_adj)
    local max_ks_raw = r(max_ks_raw)
    local max_ks_adj = r(max_ks_adj)
    local n_imbalanced = r(n_imbalanced)
    local n_vr_imbalanced = r(n_vr_imbalanced)
    local n_binary_vr = r(n_binary_vr)
    local vr_na_vars "`r(vr_na_vars)'"

    * DISPLAY OUTPUT (binary)
    if "`matched'" != "" {
        local smd_label "SMD (Matched)"
    }
    else {
        local smd_label "SMD Raw"
    }

    display as text _n `"`title'"'
    display as text "Treatment:     " as result "`treatment'"
    display as text "Estimand:      " as result strupper("`estimand'")
    display as text "N (treated):   " as result %10.0fc `n_treated'
    display as text "N (control):   " as result %10.0fc `n_control'
    if "`wvar'" != "" {
        local wvar_label "`wvar'"
        if "`wvar_auto'" == "1" local wvar_label "auto-generated"
        display as text "Weights:       " as result "`wvar_label'"
    }
    if "`matched'" != "" {
        display as text "Matched:       " as result "Yes"
    }
    if "`source'" != "manual" {
        display as text "Source:        " as result "`source'"
    }
    display as text "Threshold:     " as result %6.3f `threshold'
    display _newline

    * Display balance table header
    local vr_fmt "%6.2f"
    local ks_fmt "%6.3f"
    local show_ks = ("`ks'" != "")
    if `has_adj' {
        if `show_ks' {
            display as text "{hline 96}"
            display as text %20s "Covariate" " {c |}" ///
                %9s "SMD Raw" %8s "VR Raw" %8s "KS" ///
                %9s "SMD Adj" %8s "VR Adj" %12s "Status"
            display as text "{hline 96}"
        }
        else {
            display as text "{hline 87}"
            display as text %20s "Covariate" " {c |}" ///
                %9s "SMD Raw" %8s "VR Raw" %9s "SMD Adj" %8s "VR Adj" %12s "Status"
            display as text "{hline 87}"
        }
    }
    else {
        if `show_ks' {
            display as text "{hline 72}"
            display as text %20s "Covariate" " {c |}" ///
                %9s "`smd_label'" %8s "VR" %8s "KS" %12s "Status"
            display as text "{hline 72}"
        }
        else {
            display as text "{hline 63}"
            display as text %20s "Covariate" " {c |}" ///
                %9s "`smd_label'" %8s "VR" %12s "Status"
            display as text "{hline 63}"
        }
    }

    * Display each covariate
    local i = 1
    foreach var of local varlist {
        local smd_raw = `balance_mat'[`i', 3]
        local vr_raw_i = `balance_mat'[`i', 4]
        local ks_raw_i = `balance_mat'[`i', 5]

        if `has_adj' {
            local smd_adj = `balance_mat'[`i', 8]
            local vr_adj_i = `balance_mat'[`i', 9]
            local smd_check = `smd_adj'
        }
        else {
            local smd_check = `smd_raw'
        }

        * Determine balance status
        if missing(`smd_check') {
            local status "UNDEFINED"
            local status_color "as error"
        }
        else if abs(`smd_check') <= `threshold' {
            local status "Balanced"
            local status_color "as result"
        }
        else {
            local status "IMBALANCED"
            local status_color "as error"
        }

        local varname = abbrev("`var'", 20)

        if `has_adj' {
            if `show_ks' {
                display as text %20s "`varname'" " {c |}" ///
                    as result `format' `smd_raw' ///
                    as result `vr_fmt' `vr_raw_i' ///
                    as result `ks_fmt' `ks_raw_i' ///
                    as result `format' `smd_adj' ///
                    as result `vr_fmt' `vr_adj_i' ///
                    `status_color' %12s "`status'"
            }
            else {
                display as text %20s "`varname'" " {c |}" ///
                    as result `format' `smd_raw' ///
                    as result `vr_fmt' `vr_raw_i' ///
                    as result `format' `smd_adj' ///
                    as result `vr_fmt' `vr_adj_i' ///
                    `status_color' %12s "`status'"
            }
        }
        else {
            if `show_ks' {
                display as text %20s "`varname'" " {c |}" ///
                    as result `format' `smd_raw' ///
                    as result `vr_fmt' `vr_raw_i' ///
                    as result `ks_fmt' `ks_raw_i' ///
                    `status_color' %12s "`status'"
            }
            else {
                display as text %20s "`varname'" " {c |}" ///
                    as result `format' `smd_raw' ///
                    as result `vr_fmt' `vr_raw_i' ///
                    `status_color' %12s "`status'"
            }
        }

        local i = `i' + 1
    }

    local _hline_w = cond(`has_adj', cond(`show_ks', 96, 87), cond(`show_ks', 72, 63))
    display as text "{hline `_hline_w'}"

    * Summary
    display _newline
    if `has_adj' {
        display as text "Maximum |SMD| (raw):      " as result `format' `max_smd_raw'
        display as text "Maximum |SMD| (adjusted): " as result `format' `max_smd_adj'
        display as text "Maximum VR (raw):         " as result `vr_fmt' `max_vr_raw'
        display as text "Maximum VR (adjusted):    " as result `vr_fmt' `max_vr_adj'
    }
    else if "`matched'" != "" {
        display as text "Maximum |SMD| (matched):  " as result `format' `max_smd_raw'
        display as text "Maximum VR (matched):     " as result `vr_fmt' `max_vr_raw'
    }
    else {
        display as text "Maximum |SMD| (raw):      " as result `format' `max_smd_raw'
        display as text "Maximum VR (raw):         " as result `vr_fmt' `max_vr_raw'
    }
    display as text "Covariates > SMD threshold:  " as result %3.0f `n_imbalanced' " of " %3.0f `nvars'
    local _vrb "[`=string(`vrlo',"%3.1f")', `=string(`vrhi',"%3.1f")']"
    if `n_vr_imbalanced' > 0 {
        display as text "VR outside `_vrb':       " as result %3.0f `n_vr_imbalanced' " of " %3.0f `nvars'
    }
    if `show_ks' {
        display as text "Maximum KS (raw):            " as result `ks_fmt' `max_ks_raw'
        if `has_adj' {
            display as text "Maximum KS (adjusted):       " as result `ks_fmt' `max_ks_adj'
        }
    }
    display as text "{hline `_hline_w'}"
    if "`vr_na_vars'" != "" {
        display as text "Note: variance ratio is not a meaningful balance diagnostic for" ///
            " binary covariate(s): `vr_na_vars'"
        display as text "      (VR for a two-level covariate is determined by the SMD; excluded from the VR count)."
    }

    * Verdict (RB-01: SMD *and* VR imbalance are findings; ANY finding forces an
    * IMBALANCED verdict and enters r(warnings). KS remains informational -- it
    * has no accepted universal threshold -- pending the RB-08 status rule.)
    if `has_adj' {
        local _verdict_smd = `max_smd_adj'
    }
    else {
        local _verdict_smd = `max_smd_raw'
    }
    local _pf ""
    local _pfn = 0
    if `n_imbalanced' > 0 {
        local _pf `"`_pf' | `n_imbalanced' of `nvars' covariate(s) exceed the SMD threshold"'
        local ++_pfn
    }
    if `n_vr_imbalanced' > 0 {
        local _pf `"`_pf' | `n_vr_imbalanced' variance-ratio imbalance(s) (max VR = `=string(cond(`has_adj',`max_vr_adj',`max_vr_raw'),"%5.2f")')"'
        local ++_pfn
    }
    local _pf = strtrim("`_pf'")
    if substr("`_pf'", 1, 1) == "|" local _pf = strtrim(substr("`_pf'", 2, .))
    local _balance_findings `"`_pf'"'
    local _balance_nfind = `_pfn'
    if `_pfn' > 0 {
        display as text _n "Balance: " as error "IMBALANCED" ///
            as text " (" as result %3.0f `_pfn' as text " finding(s); " ///
            as result %3.0f `n_imbalanced' as text " SMD, " ///
            as result %3.0f `n_vr_imbalanced' as text " VR)"
        display as text "  Consider: {cmd:psdash weights, trim(99) generate(w_trim)} or {cmd:psdash support, crump}"
    }
    else {
        display as text _n "Balance: " as result "Adequate" ///
            as text " (max |SMD| = " as result `format' `_verdict_smd' as text ")"
    }

    * LOVE PLOT (binary) — standard raw/adjusted; superseded by strategies() overlay
    if "`loveplot'" != "" & "`strategies'" == "" {
        capture noisily {
            quietly {
                preserve

                clear
                set obs `nvars'
                gen str80 covariate = ""
                gen double smd_raw = .
                gen double smd_adj = .
                gen order = _n

                local i = 1
                foreach var of local varlist {
                    replace covariate = "`var'" in `i'
                    replace smd_raw = `balance_mat'[`i', 3] in `i'
                    if `has_adj' {
                        replace smd_adj = `balance_mat'[`i', 8] in `i'
                    }
                    local i = `i' + 1
                }

                * Sort by absolute raw SMD (most imbalanced at top of plot)
                gen double abs_smd_raw = abs(smd_raw)
                gsort +abs_smd_raw
                replace order = _n

                * Build value labels for Y-axis (drop first to avoid stale entries from prior calls)
                cap label drop orderlab
                forvalues j = 1/`nvars' {
                    local covname = covariate[`j']
                    label define orderlab `j' "`covname'", add
                }
                label values order orderlab

                * Prepend scheme to graphoptions if specified
                if "`scheme'" != "" {
                    local graphoptions `"scheme(`scheme') `graphoptions'"'
                }

                * Compute dynamic x-axis range
                summarize smd_raw
                local xmax = max(abs(r(min)), abs(r(max)), `threshold') * 1.1
                local xmax = max(`xmax', 0.5)
                local xmax = ceil(`xmax' * 4) / 4
                if `has_adj' {
                    summarize smd_adj
                    local xmax2 = max(abs(r(min)), abs(r(max))) * 1.1
                    local xmax = max(`xmax', `xmax2')
                    local xmax = ceil(`xmax' * 4) / 4
                }
                local xstep = cond(`xmax' <= 1, 0.25, cond(`xmax' <= 5, 0.5, cond(`xmax' <= 20, 5, 10)))

                * Generate plot
                local plotopts "xline(-`threshold' `threshold', lcolor(red) lpattern(dash))"
                local plotopts "`plotopts' xline(0, lcolor(gs8) lpattern(solid))"
                local plotopts "`plotopts' ylabel(1(1)`nvars', valuelabel angle(0) labsize(small))"
                local plotopts "`plotopts' xlabel(-`xmax'(`xstep')`xmax')"
                local plotopts "`plotopts' ytitle("") xtitle("Standardized Mean Difference")"
                local plotopts `"`plotopts' title(`"`title'"')"'

                if `has_adj' {
                    local plotopts "`plotopts' legend(order(1 "Unadjusted" 2 "Adjusted") rows(1) position(6))"
                    noisily twoway (scatter order smd_raw, msymbol(circle) mcolor(navy)) ///
                           (scatter order smd_adj, msymbol(diamond) mcolor(cranberry)), ///
                           `plotopts' `graphoptions' name(`name', replace)
                }
                else {
                    noisily twoway (scatter order smd_raw, msymbol(circle) mcolor(navy)), ///
                           `plotopts' `graphoptions' legend(off) name(`name', replace)
                }

                if "`saving'" != "" {
                    _psdash_graph_export, saving("`saving'")
                }

                restore
            }
        }
        local graph_rc = _rc
        if `graph_rc' {
            capture restore
            local _psdash_side_rc = `graph_rc'
        }
    }

    * MULTI-STRATEGY LOVE PLOT OVERLAY (F2, binary)
    if "`strategies'" != "" & `_psdash_side_rc' == 0 {
        capture noisily {
            local nstrat : word count `strategies'
            tempname smd_strat _bs
            matrix `smd_strat' = J(`nvars', `nstrat', .)
            tempvar wt_s
            local sidx = 0
            local strat_labels ""
            foreach s of local strategies {
                local sidx = `sidx' + 1
                if "`s'" == "raw" {
                    forvalues i = 1/`nvars' {
                        matrix `smd_strat'[`i', `sidx'] = `balance_mat'[`i', 3]
                    }
                    local strat_labels `"`strat_labels' `sidx' "Unadjusted""'
                }
                else {
                    quietly {
                        capture drop `wt_s'
                        gen double `wt_s' = .
                        if "`s'" == "ate" {
                            replace `wt_s' = 1/`psvar' if `treatment'==1 & `psvar'>0 & `touse'
                            replace `wt_s' = 1/(1-`psvar') if `treatment'==0 & `psvar'<1 & `touse'
                        }
                        else if "`s'" == "att" {
                            replace `wt_s' = 1 if `treatment'==1 & `touse'
                            replace `wt_s' = `psvar'/(1-`psvar') if `treatment'==0 & `psvar'<1 & `touse'
                        }
                        else if "`s'" == "atc" {
                            replace `wt_s' = (1-`psvar')/`psvar' if `treatment'==1 & `psvar'>0 & `touse'
                            replace `wt_s' = 1 if `treatment'==0 & `touse'
                        }
                    }
                    _psdash_balance_binary `varlist', treatment(`treatment') ///
                        samplevar(`touse') threshold(`threshold') wvar(`wt_s')
                    matrix `_bs' = r(balance)
                    forvalues i = 1/`nvars' {
                        matrix `smd_strat'[`i', `sidx'] = `_bs'[`i', 8]
                    }
                    local slab = strupper("`s'")
                    local strat_labels `"`strat_labels' `sidx' "`slab'""'
                }
            }

            quietly {
                preserve
                clear
                set obs `nvars'
                gen str80 covariate = ""
                forvalues s = 1/`nstrat' {
                    gen double smd_`s' = .
                }
                forvalues i = 1/`nvars' {
                    local cv : word `i' of `varlist'
                    replace covariate = "`cv'" in `i'
                    forvalues s = 1/`nstrat' {
                        replace smd_`s' = `smd_strat'[`i', `s'] in `i'
                    }
                }
                gen double abs_smd_max = 0
                forvalues s = 1/`nstrat' {
                    replace abs_smd_max = max(abs_smd_max, abs(smd_`s'))
                }
                gen order = _n
                gsort +abs_smd_max
                replace order = _n
                cap label drop orderlab
                forvalues j = 1/`nvars' {
                    local covname = covariate[`j']
                    label define orderlab `j' "`covname'", add
                }
                label values order orderlab

                local _go "`_graphopts0'"
                if "`scheme'" != "" local _go `"scheme(`scheme') `_go'"'

                summarize abs_smd_max
                local xmax = max(r(max), `threshold') * 1.1
                local xmax = max(`xmax', 0.5)
                local xmax = ceil(`xmax' * 4) / 4
                local xstep = cond(`xmax' <= 1, 0.25, cond(`xmax' <= 5, 0.5, cond(`xmax' <= 20, 5, 10)))

                local color_list "navy cranberry forest_green dkorange purple teal maroon olive"
                local symbol_list "circle diamond triangle square plus X smcircle smsquare"
                local plot_cmd ""
                forvalues s = 1/`nstrat' {
                    local col : word `s' of `color_list'
                    local sym : word `s' of `symbol_list'
                    local plot_cmd `"`plot_cmd' (scatter order smd_`s', msymbol(`sym') mcolor(`col'))"'
                }

                local plotopts "xline(-`threshold' `threshold', lcolor(red) lpattern(dash))"
                local plotopts "`plotopts' xline(0, lcolor(gs8) lpattern(solid))"
                local plotopts "`plotopts' ylabel(1(1)`nvars', valuelabel angle(0) labsize(small))"
                local plotopts "`plotopts' xlabel(-`xmax'(`xstep')`xmax')"
                local plotopts "`plotopts' ytitle("") xtitle("Standardized Mean Difference")"
                local plotopts `"`plotopts' title(`"`title'"')"'
                local plotopts `"`plotopts' legend(order(`strat_labels') rows(1) position(6))"'

                noisily twoway `plot_cmd', `plotopts' `_go' name(`name', replace)

                if "`saving'" != "" {
                    _psdash_graph_export, saving("`saving'")
                }
                restore
            }
        }
        local graph_rc = _rc
        if `graph_rc' {
            capture restore
            local _psdash_side_rc = `graph_rc'
        }
    }

    * DISTRIBUTIONAL BALANCE PLOT (F1, binary)
    if "`distribution'" != "" & `_psdash_side_rc' == 0 {
        capture noisily {
            quietly {
                local _other_graph = ("`loveplot'" != "" | "`strategies'" != "")
                local _go "`_graphopts0'"
                if "`scheme'" != "" local _go `"scheme(`scheme') `_go'"'
                local _dist_names ""
                local _dk = 0
                foreach dv of local distribution {
                    local _dk = `_dk' + 1
                    local _gname "`name'_dist`_dk'"
                    if `has_adj' {
                        noisily twoway ///
                            (kdensity `dv' if `treatment'==1 & `touse', lcolor(navy) lpattern(solid)) ///
                            (kdensity `dv' if `treatment'==0 & `touse', lcolor(cranberry) lpattern(solid)) ///
                            (kdensity `dv' [aw=`wvar'] if `treatment'==1 & `touse', lcolor(navy) lpattern(dash)) ///
                            (kdensity `dv' [aw=`wvar'] if `treatment'==0 & `touse', lcolor(cranberry) lpattern(dash)), ///
                            legend(order(1 "Treated (raw)" 2 "Control (raw)" ///
                                3 "Treated (wtd)" 4 "Control (wtd)") size(vsmall) rows(2) position(6)) ///
                            xtitle("`dv'") ytitle("Density") title("`dv'", size(medium)) ///
                            name(`_gname', replace) `_go'
                    }
                    else {
                        noisily twoway ///
                            (kdensity `dv' if `treatment'==1 & `touse', lcolor(navy)) ///
                            (kdensity `dv' if `treatment'==0 & `touse', lcolor(cranberry)), ///
                            legend(order(1 "Treated" 2 "Control") size(small) rows(1) position(6)) ///
                            xtitle("`dv'") ytitle("Density") title("`dv'", size(medium)) ///
                            name(`_gname', replace) `_go'
                    }
                    local _dist_names "`_dist_names' `_gname'"
                }
                local _ndist : word count `_dist_names'
                if `_ndist' > 1 {
                    graph combine `_dist_names', name(`name'_dist, replace) ///
                        title(`"`title' — covariate distributions"')
                }
                if "`saving'" != "" & !`_other_graph' {
                    _psdash_graph_export, saving("`saving'")
                }
            }
        }
        local graph_rc = _rc
        if `graph_rc' {
            local _psdash_side_rc = `graph_rc'
        }
    }

    * EXPORT TO EXCEL (binary)
    if "`xlsx'" != "" & `_psdash_side_rc' == 0 {
        capture noisily {
            quietly {
                preserve

                clear
                set obs `=`nvars' + 3'

                gen str80 A = ""
                gen str20 B = ""
                gen str20 C = ""
                gen str20 D = ""
                gen str20 E = ""
                gen str20 F = ""
                gen str20 G = ""
                gen str20 H = ""
                gen str20 I = ""

                replace A = `"`title'"' in 1

                replace A = "Covariate" in 2
                replace B = "Mean (Treated)" in 2
                replace C = "Mean (Control)" in 2
                if `has_adj' {
                    replace D = "SMD (Raw)" in 2
                    replace E = "VR (Raw)" in 2
                    replace F = "Mean (T, Adj)" in 2
                    replace G = "Mean (C, Adj)" in 2
                    replace H = "SMD (Adj)" in 2
                    replace I = "VR (Adj)" in 2
                }
                else if "`matched'" != "" {
                    replace D = "SMD (Matched)" in 2
                    replace E = "VR" in 2
                }
                else {
                    replace D = "SMD (Raw)" in 2
                    replace E = "VR" in 2
                }

                local vr_fmt_xl "%6.2f"
                local i = 1
                foreach var of local varlist {
                    local row = `i' + 2
                    replace A = "`var'" in `row'
                    replace B = string(`balance_mat'[`i', 1], "`format'") in `row'
                    replace C = string(`balance_mat'[`i', 2], "`format'") in `row'
                    replace D = string(`balance_mat'[`i', 3], "`format'") in `row'
                    replace E = string(`balance_mat'[`i', 4], "`vr_fmt_xl'") in `row'
                    if `has_adj' {
                        replace F = string(`balance_mat'[`i', 6], "`format'") in `row'
                        replace G = string(`balance_mat'[`i', 7], "`format'") in `row'
                        replace H = string(`balance_mat'[`i', 8], "`format'") in `row'
                        replace I = string(`balance_mat'[`i', 9], "`vr_fmt_xl'") in `row'
                    }
                    local i = `i' + 1
                }

                local sumrow = `nvars' + 3
                replace A = "Max |SMD|" in `sumrow'
                replace D = string(`max_smd_raw', "`format'") in `sumrow'
                if `has_adj' {
                    replace H = string(`max_smd_adj', "`format'") in `sumrow'
                }

                if !`has_adj' {
                    drop F G H I
                }

                noisily export excel using "`xlsx'", sheet("`sheet'") sheetreplace

                restore

                noisily display as text _n "Balance table exported to: " as result "`xlsx'"
            }
        }
        local xlsx_rc = _rc
        if `xlsx_rc' {
            capture restore
            local _psdash_side_rc = `xlsx_rc'
        }
    }

    local _psdash_return_mode "binary"

    } // end binary path
    else {
    * MULTI-GROUP PATH (K >= 2 non-binary treatment)

    * Mark out missing treatment
    markout `touse' `treatment'

    * Covariates are required for balance assessment
    if "`covariates'" == "" {
        display as error "covariates() required for balance assessment"
        display as error "  specify covariates or run after an estimation command"
        exit 198
    }

    if "`wvar'" != "" markout `touse' `wvar'

    quietly count if `touse'
    if r(N) == 0 {
        display as error "no observations"
        exit 2000
    }
    local N = r(N)

    local varlist "`covariates'"

    * Validate wvar and matched are mutually exclusive
    if "`wvar'" != "" & "`matched'" != "" {
        display as error "wvar() and matched are mutually exclusive"
        exit 198
    }

    * Validate threshold
    if `threshold' <= 0 {
        display as error "threshold() must be positive"
        exit 198
    }

    * Validate Excel options
    if "`xlsx'" != "" {
        _psdash_validate_path, path(`"`xlsx'"') option(xlsx) extension(xlsx)
    }

    * Set defaults
    if "`format'" == "" local format "%6.3f"
    capture confirm format `format'
    if _rc {
        display as error "format() must be a valid Stata display format"
        exit 198
    }
    local format_lc = lower("`format'")
    if substr("`format_lc'", 1, 2) == "%t" | regexm("`format_lc'", "s$") {
        display as error "format() must be a numeric display format"
        exit 198
    }
    if "`sheet'" == "" local sheet "Balance"
    if "`title'" == "" local title "Covariate Balance Assessment (Multi-Group)"
    if "`name'" == "" local name "psdash_balance"

    * strategies()/distribution() overlays are defined for binary treatment only
    if "`strategies'" != "" {
        display as error "strategies() is supported for binary treatment only"
        exit 198
    }
    if "`distribution'" != "" {
        display as error "distribution() is supported for binary treatment only"
        exit 198
    }

    local nvars : word count `varlist'
    local has_adj = ("`wvar'" != "")

    * Validate weights if specified
    if "`wvar'" != "" {
        quietly summarize `wvar' if `touse'
        if r(min) < 0 {
            display as error "weights cannot be negative"
            exit 198
        }
        if r(sum) <= 0 {
            display as error "weights must have positive total weight"
            exit 198
        }
        foreach lev of local levels {
            quietly summarize `wvar' if `touse' & `treatment' == `lev'
            if r(sum) <= 0 {
                display as error "group `lev' must have positive total weight"
                exit 198
            }
        }
    }

    local wvar_opt ""
    if "`wvar'" != "" local wvar_opt "wvar(`wvar')"
    _psdash_balance_multigroup `varlist', treatment(`treatment') samplevar(`touse') ///
        levels(`levels') reference(`mg_reference') threshold(`threshold') `wvar_opt' ///
        vrlo(`vrlo') vrhi(`vrhi')
    tempname balance_mat
    matrix `balance_mat' = r(balance)
    local contrasts "`r(contrasts)'"
    local n_contrasts = r(n_contrasts)
    local ncols_raw = r(ncols_raw)
    local ncols = r(ncols)
    foreach lev of local levels {
        local n_group_`lev' = r(n_group_`lev')
    }
    local max_smd_raw = r(max_smd_raw)
    local max_smd_adj = r(max_smd_adj)
    local max_ks_raw = r(max_ks_raw)
    local max_ks_adj = r(max_ks_adj)
    local n_binary_vr = r(n_binary_vr)
    local vr_na_vars "`r(vr_na_vars)'"
    local n_imbalanced = r(n_imbalanced)
    local n_vr_imbalanced = r(n_vr_imbalanced)
    local show_ks = ("`ks'" != "")

    * DISPLAY (multi-group)
    local vr_fmt "%6.2f"
    local ks_fmt "%6.3f"

    display as text _n `"`title'"'
    display as text "Treatment:     " as result "`treatment'" as text " (`K' groups, ref = `mg_reference')"
    display as text "Estimand:      " as result strupper("`estimand'")
    foreach lev of local levels {
        * Try to get a value label for this level
        local lbl_`lev' "`lev'"
        local vallbl : value label `treatment'
        if "`vallbl'" != "" {
            local lbl_`lev' : label `vallbl' `lev'
        }
        display as text "N (Group `lbl_`lev''):" _col(16) as result %10.0fc `n_group_`lev''
    }
    if "`wvar'" != "" {
        local wvar_label "`wvar'"
        if "`wvar_auto'" == "1" local wvar_label "auto-generated"
        display as text "Weights:       " as result "`wvar_label'"
    }
    if "`matched'" != "" {
        display as text "Matched:       " as result "Yes"
    }
    if "`source'" != "manual" {
        display as text "Source:        " as result "`source'"
    }
    display as text "Threshold:     " as result %6.3f `threshold'
    display _newline

    * Build display header dynamically
    * For each contrast: SMD avR, VR avR (and optionally KS)
    * Plus Status column
    local hdr_width = 20 + 1  // covariate + separator
    foreach clev of local contrasts {
        local hdr_width = `hdr_width' + 9 + 8  // SMD + VR per contrast
        if `show_ks' local hdr_width = `hdr_width' + 8
    }
    if `has_adj' {
        foreach clev of local contrasts {
            local hdr_width = `hdr_width' + 9 + 8
        }
    }
    local hdr_width = `hdr_width' + 12  // Status

    display as text "{hline `hdr_width'}"

    * Header line 1
    local hdr_line ""
    local hdr_line `"`hdr_line'%20s "Covariate" " {c |}""'

    foreach clev of local contrasts {
        if `has_adj' {
            local hdr_line `"`hdr_line' %9s "SMD `clev'v`mg_reference'" %8s "VR""'
            if `show_ks' local hdr_line `"`hdr_line' %8s "KS""'
        }
        else {
            local hdr_line `"`hdr_line' %9s "SMD `clev'v`mg_reference'" %8s "VR""'
            if `show_ks' local hdr_line `"`hdr_line' %8s "KS""'
        }
    }
    if `has_adj' {
        foreach clev of local contrasts {
            local hdr_line `"`hdr_line' %9s "Adj `clev'v`mg_reference'" %8s "VR""'
        }
    }
    local hdr_line `"`hdr_line' %12s "Status""'
    display as text `hdr_line'
    display as text "{hline `hdr_width'}"

    * Display each covariate
    local i = 1
    foreach var of local varlist {
        local varname = abbrev("`var'", 20)
        local row_line ""
        local row_line `"as text %20s "`varname'" " {c |}""'

        * Determine status: IMBALANCED if any contrast exceeds threshold
        local cov_imbalanced = 0
        local cnum = 0
        foreach clev of local contrasts {
            local cnum = `cnum' + 1
            local col_smd_raw = (`cnum' - 1) * 5 + 3
            local col_vr_raw = (`cnum' - 1) * 5 + 4
            local col_ks_raw = (`cnum' - 1) * 5 + 5

            local smd_raw_v = `balance_mat'[`i', `col_smd_raw']
            local vr_raw_v = `balance_mat'[`i', `col_vr_raw']
            local ks_raw_v = `balance_mat'[`i', `col_ks_raw']

            local row_line `"`row_line' as result `format' `smd_raw_v' as result `vr_fmt' `vr_raw_v'"'
            if `show_ks' {
                local row_line `"`row_line' as result `ks_fmt' `ks_raw_v'"'
            }

            if `has_adj' {
                local col_smd_adj = `ncols_raw' + (`cnum' - 1) * 5 + 3
                if !missing(`balance_mat'[`i', `col_smd_adj']) {
                    if abs(`balance_mat'[`i', `col_smd_adj']) > `threshold' {
                        local cov_imbalanced = 1
                    }
                }
                else {
                    local cov_imbalanced = 1
                }
            }
            else {
                if !missing(`smd_raw_v') {
                    if abs(`smd_raw_v') > `threshold' local cov_imbalanced = 1
                }
                else {
                    local cov_imbalanced = 1
                }
            }
        }

        if `has_adj' {
            local cnum = 0
            foreach clev of local contrasts {
                local cnum = `cnum' + 1
                local adj_smd_col = `ncols_raw' + (`cnum' - 1) * 5 + 3
                local adj_vr_col = `ncols_raw' + (`cnum' - 1) * 5 + 4
                local smd_adj_v = `balance_mat'[`i', `adj_smd_col']
                local vr_adj_v = `balance_mat'[`i', `adj_vr_col']
                local row_line `"`row_line' as result `format' `smd_adj_v' as result `vr_fmt' `vr_adj_v'"'
            }
        }

        if `cov_imbalanced' {
            local row_line `"`row_line' as error %12s "IMBALANCED""'
        }
        else {
            local row_line `"`row_line' as result %12s "Balanced""'
        }

        display `row_line'
        local i = `i' + 1
    }

    display as text "{hline `hdr_width'}"

    * Summary
    display _newline
    if `has_adj' {
        display as text "Maximum |SMD| (raw):      " as result `format' `max_smd_raw'
        display as text "Maximum |SMD| (adjusted): " as result `format' `max_smd_adj'
    }
    else if "`matched'" != "" {
        display as text "Maximum |SMD| (matched):  " as result `format' `max_smd_raw'
    }
    else {
        display as text "Maximum |SMD| (raw):      " as result `format' `max_smd_raw'
    }
    display as text "Covariates > SMD threshold:  " as result %3.0f `n_imbalanced' " of " %3.0f `nvars'
    local _vrb "[`=string(`vrlo',"%3.1f")', `=string(`vrhi',"%3.1f")']"
    if `n_vr_imbalanced' > 0 {
        display as text "VR outside `_vrb':       " as result %3.0f `n_vr_imbalanced'
    }
    if `show_ks' {
        display as text "Maximum KS (raw):            " as result `ks_fmt' `max_ks_raw'
        if `has_adj' {
            display as text "Maximum KS (adjusted):       " as result `ks_fmt' `max_ks_adj'
        }
    }
    display as text "{hline `hdr_width'}"
    if "`vr_na_vars'" != "" {
        display as text "Note: variance ratio is not a meaningful balance diagnostic for" ///
            " binary covariate(s): `vr_na_vars'"
    }

    * Verdict (RB-01: SMD *and* VR imbalance are findings; ANY finding forces an
    * IMBALANCED verdict and enters r(warnings). KS remains informational -- it
    * has no accepted universal threshold -- pending the RB-08 status rule.)
    if `has_adj' {
        local _verdict_smd = `max_smd_adj'
    }
    else {
        local _verdict_smd = `max_smd_raw'
    }
    local _pf ""
    local _pfn = 0
    if `n_imbalanced' > 0 {
        local _pf `"`_pf' | `n_imbalanced' of `nvars' covariate(s) exceed the SMD threshold"'
        local ++_pfn
    }
    if `n_vr_imbalanced' > 0 {
        local _pf `"`_pf' | `n_vr_imbalanced' variance-ratio imbalance(s) (max VR = `=string(cond(`has_adj',`max_vr_adj',`max_vr_raw'),"%5.2f")')"'
        local ++_pfn
    }
    local _pf = strtrim("`_pf'")
    if substr("`_pf'", 1, 1) == "|" local _pf = strtrim(substr("`_pf'", 2, .))
    local _balance_findings `"`_pf'"'
    local _balance_nfind = `_pfn'
    if `_pfn' > 0 {
        display as text _n "Balance: " as error "IMBALANCED" ///
            as text " (" as result %3.0f `_pfn' as text " finding(s); " ///
            as result %3.0f `n_imbalanced' as text " SMD, " ///
            as result %3.0f `n_vr_imbalanced' as text " VR)"
        display as text "  Consider: {cmd:psdash weights, trim(99) generate(w_trim)} or {cmd:psdash support, crump}"
    }
    else {
        display as text _n "Balance: " as result "Adequate" ///
            as text " (max |SMD| = " as result `format' `_verdict_smd' as text ")"
    }

    * LOVE PLOT (multi-group)
    if "`loveplot'" != "" {
        capture noisily {
            quietly {
                preserve

                clear
                set obs `nvars'
                gen str80 covariate = ""
                gen order = _n

                * Create one SMD variable per contrast
                local cnum = 0
                foreach clev of local contrasts {
                    local cnum = `cnum' + 1
                    gen double smd_`cnum' = .
                }

                local i = 1
                foreach var of local varlist {
                    replace covariate = "`var'" in `i'
                    local cnum = 0
                    foreach clev of local contrasts {
                        local cnum = `cnum' + 1
                        local col_smd = (`cnum' - 1) * 5 + 3
                        if `has_adj' {
                            local col_smd = `ncols_raw' + (`cnum' - 1) * 5 + 3
                        }
                        replace smd_`cnum' = `balance_mat'[`i', `col_smd'] in `i'
                    }
                    local i = `i' + 1
                }

                * Sort by max absolute SMD across contrasts
                gen double abs_smd_max = 0
                local cnum = 0
                foreach clev of local contrasts {
                    local cnum = `cnum' + 1
                    replace abs_smd_max = max(abs_smd_max, abs(smd_`cnum'))
                }
                gsort +abs_smd_max
                replace order = _n

                cap label drop orderlab
                forvalues j = 1/`nvars' {
                    local covname = covariate[`j']
                    label define orderlab `j' "`covname'", add
                }
                label values order orderlab

                if "`scheme'" != "" {
                    local graphoptions `"scheme(`scheme') `graphoptions'"'
                }

                * Compute dynamic x-axis range
                local xmax = `threshold' * 1.1
                local cnum = 0
                foreach clev of local contrasts {
                    local cnum = `cnum' + 1
                    summarize smd_`cnum'
                    local xm = max(abs(r(min)), abs(r(max))) * 1.1
                    if `xm' > `xmax' local xmax = `xm'
                }
                local xmax = max(`xmax', 0.5)
                local xmax = ceil(`xmax' * 4) / 4
                local xstep = cond(`xmax' <= 1, 0.25, cond(`xmax' <= 5, 0.5, cond(`xmax' <= 20, 5, 10)))

                * Build plot command with one series per contrast
                local color_list "navy cranberry forest_green dkorange purple teal maroon olive"
                local symbol_list "circle diamond triangle square plus X smcircle smsquare"
                local plot_cmd ""
                local legend_order ""
                local cnum = 0
                foreach clev of local contrasts {
                    local cnum = `cnum' + 1
                    local col : word `cnum' of `color_list'
                    local sym : word `cnum' of `symbol_list'
                    local lbl "`clev' vs `mg_reference'"
                    local plot_cmd `"`plot_cmd' (scatter order smd_`cnum', msymbol(`sym') mcolor(`col'))"'
                    local legend_order `"`legend_order' `cnum' "`lbl'""'
                }

                local plotopts "xline(-`threshold' `threshold', lcolor(red) lpattern(dash))"
                local plotopts "`plotopts' xline(0, lcolor(gs8) lpattern(solid))"
                local plotopts "`plotopts' ylabel(1(1)`nvars', valuelabel angle(0) labsize(small))"
                local plotopts "`plotopts' xlabel(-`xmax'(`xstep')`xmax')"
                local plotopts "`plotopts' ytitle("") xtitle("Standardized Mean Difference")"
                local plotopts `"`plotopts' title(`"`title'"')"'
                local plotopts `"`plotopts' legend(order(`legend_order') rows(1) position(6))"'

                noisily twoway `plot_cmd', ///
                    `plotopts' `graphoptions' name(`name', replace)

                if "`saving'" != "" {
                    _psdash_graph_export, saving("`saving'")
                }

                restore
            }
        }
        local graph_rc = _rc
        if `graph_rc' {
            capture restore
            local _psdash_side_rc = `graph_rc'
        }
    }

    * EXPORT TO EXCEL (multi-group)
    if "`xlsx'" != "" & `_psdash_side_rc' == 0 {
        capture noisily {
            quietly {
                preserve

                * Determine number of data columns
                local xl_ncols = 1  // covariate name
                foreach clev of local contrasts {
                    local xl_ncols = `xl_ncols' + 3  // SMD, VR, KS per contrast
                }
                if `has_adj' {
                    foreach clev of local contrasts {
                        local xl_ncols = `xl_ncols' + 2  // SMD_adj, VR_adj
                    }
                }

                clear
                set obs `=`nvars' + 3'

                * Generate string columns dynamically
                gen str80 col_1 = ""
                local max_xl_col = `xl_ncols'
                forvalues c = 2/`max_xl_col' {
                    gen str20 col_`c' = ""
                }

                replace col_1 = `"`title'"' in 1

                * Header row
                replace col_1 = "Covariate" in 2
                local c = 1
                foreach clev of local contrasts {
                    local c = `c' + 1
                    replace col_`c' = "SMD `clev'v`mg_reference'" in 2
                    local c = `c' + 1
                    replace col_`c' = "VR `clev'v`mg_reference'" in 2
                    local c = `c' + 1
                    replace col_`c' = "KS `clev'v`mg_reference'" in 2
                }
                if `has_adj' {
                    foreach clev of local contrasts {
                        local c = `c' + 1
                        replace col_`c' = "SMD Adj `clev'v`mg_reference'" in 2
                        local c = `c' + 1
                        replace col_`c' = "VR Adj `clev'v`mg_reference'" in 2
                    }
                }

                * Data rows
                local vr_fmt_xl "%6.2f"
                local i = 1
                foreach var of local varlist {
                    local row = `i' + 2
                    replace col_1 = "`var'" in `row'
                    local c = 1
                    local cnum = 0
                    foreach clev of local contrasts {
                        local cnum = `cnum' + 1
                        local col_smd = (`cnum' - 1) * 5 + 3
                        local col_vr = (`cnum' - 1) * 5 + 4
                        local col_ks = (`cnum' - 1) * 5 + 5
                        local c = `c' + 1
                        replace col_`c' = string(`balance_mat'[`i', `col_smd'], "`format'") in `row'
                        local c = `c' + 1
                        replace col_`c' = string(`balance_mat'[`i', `col_vr'], "`vr_fmt_xl'") in `row'
                        local c = `c' + 1
                        replace col_`c' = string(`balance_mat'[`i', `col_ks'], "`ks_fmt'") in `row'
                    }
                    if `has_adj' {
                        local cnum = 0
                        foreach clev of local contrasts {
                            local cnum = `cnum' + 1
                            local adj_smd = `ncols_raw' + (`cnum' - 1) * 5 + 3
                            local adj_vr = `ncols_raw' + (`cnum' - 1) * 5 + 4
                            local c = `c' + 1
                            replace col_`c' = string(`balance_mat'[`i', `adj_smd'], "`format'") in `row'
                            local c = `c' + 1
                            replace col_`c' = string(`balance_mat'[`i', `adj_vr'], "`vr_fmt_xl'") in `row'
                        }
                    }
                    local i = `i' + 1
                }

                * Summary row
                local sumrow = `nvars' + 3
                replace col_1 = "Max |SMD|" in `sumrow'
                local c = 2
                replace col_`c' = string(`max_smd_raw', "`format'") in `sumrow'

                noisily export excel using "`xlsx'", sheet("`sheet'") sheetreplace

                restore

                noisily display as text _n "Balance table exported to: " as result "`xlsx'"
            }
        }
        local xlsx_rc = _rc
        if `xlsx_rc' {
            capture restore
            local _psdash_side_rc = `xlsx_rc'
        }
    }

    local _psdash_return_mode "multigroup"

    } // end multi-group path

    } // end capture noisily

    local rc = _rc
    set varabbrev `_vao'
    if `rc' == 0 & "`_psdash_return_mode'" != "" {
        if `_psdash_side_rc' {
            local rc = `_psdash_side_rc'
        }
        return clear
        if "`_psdash_return_mode'" == "binary" {
            return scalar N = `N'
            return scalar N_treated = `n_treated'
            return scalar N_control = `n_control'
            return scalar max_smd_raw = `max_smd_raw'
            return scalar max_vr_raw = `max_vr_raw'
            if `has_adj' {
                return scalar max_smd_adj = `max_smd_adj'
                return scalar max_vr_adj = `max_vr_adj'
            }
            return scalar n_imbalanced = `n_imbalanced'
            return scalar n_vr_imbalanced = `n_vr_imbalanced'
            return scalar n_binary_vr = `n_binary_vr'
            return scalar max_ks_raw = `max_ks_raw'
            if `has_adj' return scalar max_ks_adj = `max_ks_adj'
            return scalar threshold = `threshold'
            return scalar n_ps_boundary = `n_ps_boundary'
            return scalar n_ps_near_boundary = `n_ps_near'
            if "`vr_na_vars'" != "" return local vr_na_vars "`vr_na_vars'"
            return local treatment "`treatment'"
            return local estimand "`estimand'"
            return local source "`source'"
            return local varlist "`varlist'"
            if "`wvar'" != "" {
                if "`wvar_auto'" == "1" {
                    return local wvar "auto-generated"
                }
                else {
                    return local wvar "`wvar'"
                }
            }
            * SMD matrix keyed by covariate, consumable by puttab/table1_tc (I1)
            tempname _smd_out
            if `has_adj' {
                matrix `_smd_out' = `balance_mat'[1..., 3], `balance_mat'[1..., 8]
                matrix colnames `_smd_out' = SMD_unadj SMD_adj
            }
            else {
                matrix `_smd_out' = `balance_mat'[1..., 3]
                matrix colnames `_smd_out' = SMD_unadj
            }
            if "`smdmatrix'" != "" matrix `smdmatrix' = `_smd_out'
            return matrix smd = `_smd_out'
            return matrix balance = `balance_mat'
        }
        else if "`_psdash_return_mode'" == "multigroup" {
            return scalar N = `N'
            return scalar K = `K'
            foreach lev of local levels {
                return scalar N_group_`lev' = `n_group_`lev''
            }
            return scalar max_smd_raw = `max_smd_raw'
            if `has_adj' {
                return scalar max_smd_adj = `max_smd_adj'
            }
            return scalar n_imbalanced = `n_imbalanced'
            return scalar n_vr_imbalanced = `n_vr_imbalanced'
            return scalar n_binary_vr = `n_binary_vr'
            return scalar max_ks_raw = `max_ks_raw'
            if `has_adj' return scalar max_ks_adj = `max_ks_adj'
            return scalar threshold = `threshold'
            if "`vr_na_vars'" != "" return local vr_na_vars "`vr_na_vars'"
            return local treatment "`treatment'"
            return local estimand "`estimand'"
            return local source "`source'"
            return local varlist "`varlist'"
            return local levels "`levels'"
            return local reference "`mg_reference'"
            if "`wvar'" != "" {
                if "`wvar_auto'" == "1" {
                    return local wvar "auto-generated"
                }
                else {
                    return local wvar "`wvar'"
                }
            }
            * Per-contrast SMD matrix consumable by puttab/table1_tc (I1)
            tempname _smd_out
            local _smd_ncols = `n_contrasts'
            if `has_adj' local _smd_ncols = `_smd_ncols' * 2
            matrix `_smd_out' = J(`nvars', `_smd_ncols', .)
            forvalues i = 1/`nvars' {
                local cnum = 0
                local outc = 0
                foreach clev of local contrasts {
                    local cnum = `cnum' + 1
                    local outc = `outc' + 1
                    matrix `_smd_out'[`i', `outc'] = `balance_mat'[`i', `=(`cnum'-1)*5+3']
                }
                if `has_adj' {
                    local cnum = 0
                    foreach clev of local contrasts {
                        local cnum = `cnum' + 1
                        local outc = `outc' + 1
                        matrix `_smd_out'[`i', `outc'] = `balance_mat'[`i', `=`ncols_raw'+(`cnum'-1)*5+3']
                    }
                }
            }
            local _smd_cnames ""
            foreach clev of local contrasts {
                local _smd_cnames "`_smd_cnames' SMD_`clev'v`mg_reference'"
            }
            if `has_adj' {
                foreach clev of local contrasts {
                    local _smd_cnames "`_smd_cnames' SMDadj_`clev'v`mg_reference'"
                }
            }
            matrix colnames `_smd_out' = `_smd_cnames'
            local _balrn : rownames `balance_mat'
            matrix rownames `_smd_out' = `_balrn'
            if "`smdmatrix'" != "" matrix `smdmatrix' = `_smd_out'
            return matrix smd = `_smd_out'
            return matrix balance = `balance_mat'
        }
        * RB-01 unified findings surface (both modes)
        if "`_balance_nfind'" == "" local _balance_nfind = 0
        return scalar n_warnings = `_balance_nfind'
        return local warnings `"`_balance_findings'"'
    }
    if `rc' exit `rc'
end
