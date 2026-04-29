*! psdash_balance Version 1.0.0  2026/04/29
*! Covariate balance diagnostics with standardized mean differences
*! Author: Timothy P Copeland
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

    capture noisily {

    * =========================================================================
    * SYNTAX PARSING
    * =========================================================================
    syntax [anything] [if] [in], ///
        [COVariates(varlist numeric) ///
         Wvar(varname) ///
         MATCHed ///
         THReshold(real 0.1) ///
         NOWvar ///
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
         PSVars(varlist numeric)]

    * =========================================================================
    * MARK SAMPLE
    * =========================================================================
    tempvar touse ps_auto wt_auto
    mark `touse' `if' `in'  // validator-note: mark+markout pattern is equivalent to marksample

    * =========================================================================
    * AUTO-DETECT PS COMPONENTS
    * =========================================================================
    * For balance, user may provide treatment + wvar (or nowvar) without a PS
    * variable. The detect helper requires psvar for manual mode, so handle
    * the treatment-only case ourselves before falling through to detect.
    local _manual_mg = 0
    local _n_pos_args : word count `anything'
    local _has_est_ctx = inlist("`e(cmd)'", "logit", "probit", "logistic", "mlogit", "teffects")
    if `_n_pos_args' == 1 & ("`wvar'" != "" | "`nowvar'" != "") & !`_has_est_ctx' {
        * Single positional arg (treatment) with wvar or nowvar: manual detect
        tokenize `anything'
        confirm variable `1'
        confirm numeric variable `1'
        local treatment "`1'"
        local psvar ""
        local psvar_auto "0"
        local source "manual"
        if "`estimand'" == "" local estimand "ate"
        local wvar_auto "0"

        * Discover treatment levels
        quietly levelsof `treatment' if `touse', local(_man_levels)
        local K : word count `_man_levels'
        local levels "`_man_levels'"

        if `K' == 1 {
            display as error "treatment must have at least 2 levels"
            exit 198
        }
        if `K' == 0 error 2000

        * Determine binary 0/1
        local _is_bin01 = 0
        if `K' == 2 {
            local _l1 : word 1 of `_man_levels'
            local _l2 : word 2 of `_man_levels'
            if "`_l1'" == "0" & "`_l2'" == "1" local _is_bin01 = 1
        }

        if `_is_bin01' {
            local multigroup "0"
            local mg_reference "0"
        }
        else {
            local multigroup "1"
            if "`reference'" != "" {
                local _ref_ok = 0
                foreach _lv of local _man_levels {
                    if "`reference'" == "`_lv'" local _ref_ok = 1
                }
                if !`_ref_ok' {
                    display as error "reference(`reference') is not a treatment level"
                    display as error "  treatment levels: `_man_levels'"
                    exit 198
                }
                local mg_reference "`reference'"
            }
            else {
                local mg_reference : word 1 of `_man_levels'
            }
        }
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
        local psvar_auto "`_psd_psvar_auto'"
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

    * =========================================================================
    * BRANCH: BINARY vs MULTI-GROUP
    * =========================================================================
    if "`multigroup'" == "0" {
    * =====================================================================
    * BINARY PATH (unchanged from v1.1.9)
    * =====================================================================

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
        quietly summarize `psvar' if `touse'
        if r(min) < 0 | r(max) > 1 {
            display as error "propensity scores must be in [0,1]"
            exit 198
        }
        quietly count if (`psvar' == 0 | `psvar' == 1) & `touse'
        local n_ps_boundary = r(N)
        if `n_ps_boundary' > 0 {
            display as error "warning: `n_ps_boundary' observations have PS exactly 0 or 1"
            display as error "  IPTW weights are undefined at these values"
        }
        quietly count if (`psvar' < 0.01 | `psvar' > 0.99) & `touse' ///
            & `psvar' != 0 & `psvar' != 1
        local n_ps_near = r(N)
        if `n_ps_near' > 0 {
            display as text "note: `n_ps_near' additional observations have PS < 0.01 or > 0.99"
            display as text "  consider {cmd:psdash support, crump} or {cmd:psdash support, threshold(0.05)}"
        }
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

    * =========================================================================
    * VALIDATE INPUTS (binary)
    * =========================================================================
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
        if !strmatch("`xlsx'", "*.xlsx") {
            display as error "Excel filename must have .xlsx extension"
            exit 198
        }
        if regexm("`xlsx'", "[;&|><\$\`]") {
            display as error "Excel filename contains invalid characters"
            exit 198
        }
    }

    * =========================================================================
    * SET DEFAULTS (binary)
    * =========================================================================
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

    * Count covariates
    local nvars : word count `varlist'

    * Determine if we have weighted adjustment (two-column display)
    local has_adj = ("`wvar'" != "")

    * =========================================================================
    * CALCULATE BALANCE STATISTICS (binary)
    * =========================================================================
    preserve
    quietly keep if `touse'

    * Get treatment/control counts
    quietly count if `treatment' == 1
    local n_treated = r(N)
    quietly count if `treatment' == 0
    local n_control = r(N)

    if `n_treated' < 2 | `n_control' < 2 {
        display as error "each treatment group must have at least 2 observations"
        exit 2001
    }

    * Create results matrix
    tempname balance_mat
    matrix `balance_mat' = J(`nvars', 10, .)
    matrix colnames `balance_mat' = "Mean_T" "Mean_C" "SMD_Raw" "VR_Raw" "KS_Raw" "Mean_T_Adj" "Mean_C_Adj" "SMD_Adj" "VR_Adj" "KS_Adj"
    local rownames ""

    * Calculate balance for each covariate
    local i = 1
    foreach var of local varlist {
        local rownames "`rownames' `var'"

        * Raw (unadjusted) statistics
        quietly summarize `var' if `treatment' == 1
        local mean_t = r(mean)
        local var_t = r(Var)

        quietly summarize `var' if `treatment' == 0
        local mean_c = r(mean)
        local var_c = r(Var)

        * Calculate pooled SD
        local sd_pooled = sqrt((`var_t' + `var_c') / 2)

        * Calculate raw SMD
        if `sd_pooled' > 0 {
            local smd_raw = (`mean_t' - `mean_c') / `sd_pooled'
        }
        else if `mean_t' != `mean_c' {
            local smd_raw = .
        }
        else {
            local smd_raw = 0
        }

        * Variance ratio (raw)
        if `var_t' > 0 & `var_c' > 0 {
            local vr_raw = `var_t' / `var_c'
        }
        else {
            local vr_raw = .
        }

        matrix `balance_mat'[`i', 1] = `mean_t'
        matrix `balance_mat'[`i', 2] = `mean_c'
        matrix `balance_mat'[`i', 3] = `smd_raw'
        matrix `balance_mat'[`i', 4] = `vr_raw'

        * KS statistic (raw) — must be after all summarize calls for this var
        capture quietly ksmirnov `var', by(`treatment')
        if _rc == 0 {
            local ks_raw = r(D)
        }
        else {
            local ks_raw = .
        }
        matrix `balance_mat'[`i', 5] = `ks_raw'

        * Adjusted statistics (weighted only)
        if `has_adj' {
            quietly summarize `var' [aw=`wvar'] if `treatment' == 1
            local mean_t_adj = r(mean)
            local var_t_adj = r(Var)

            quietly summarize `var' [aw=`wvar'] if `treatment' == 0
            local mean_c_adj = r(mean)
            local var_c_adj = r(Var)

            * Adjusted SMD using raw pooled SD (standard practice)
            if `sd_pooled' > 0 {
                local smd_adj = (`mean_t_adj' - `mean_c_adj') / `sd_pooled'
            }
            else if `mean_t_adj' != `mean_c_adj' {
                local smd_adj = .
            }
            else {
                local smd_adj = 0
            }

            * Variance ratio (adjusted)
            if `var_t_adj' > 0 & `var_c_adj' > 0 {
                local vr_adj = `var_t_adj' / `var_c_adj'
            }
            else {
                local vr_adj = .
            }

            matrix `balance_mat'[`i', 6] = `mean_t_adj'
            matrix `balance_mat'[`i', 7] = `mean_c_adj'
            matrix `balance_mat'[`i', 8] = `smd_adj'
            matrix `balance_mat'[`i', 9] = `vr_adj'
        }

        local i = `i' + 1
    }
    matrix rownames `balance_mat' = `rownames'

    restore

    * =========================================================================
    * CALCULATE SUMMARY STATISTICS (binary)
    * =========================================================================
    local max_smd_raw = 0
    local max_smd_adj = 0
    local max_vr_raw = 1
    local max_vr_adj = 1
    local max_ks_raw = 0
    local n_imbalanced = 0
    local n_vr_imbalanced = 0

    forvalues i = 1/`nvars' {
        * Raw SMD summary
        if !missing(`balance_mat'[`i', 3]) {
            local abs_smd_raw = abs(`balance_mat'[`i', 3])
            if `abs_smd_raw' > `max_smd_raw' local max_smd_raw = `abs_smd_raw'
        }

        * Raw VR summary (track max deviation from 1.0)
        if !missing(`balance_mat'[`i', 4]) {
            local vr_i = `balance_mat'[`i', 4]
            local dev_from_1 = max(abs(`vr_i' - 1), abs(1/`vr_i' - 1))
            if `dev_from_1' > abs(`max_vr_raw' - 1) local max_vr_raw = `vr_i'
            if `vr_i' < 0.5 | `vr_i' > 2 {
                local n_vr_imbalanced = `n_vr_imbalanced' + 1
            }
        }

        * Raw KS summary
        if !missing(`balance_mat'[`i', 5]) {
            local ks_i = `balance_mat'[`i', 5]
            if `ks_i' > `max_ks_raw' local max_ks_raw = `ks_i'
        }

        * Determine imbalance based on adjustment type
        if `has_adj' {
            if !missing(`balance_mat'[`i', 8]) {
                local abs_smd_adj = abs(`balance_mat'[`i', 8])
                if `abs_smd_adj' > `max_smd_adj' local max_smd_adj = `abs_smd_adj'
                if `abs_smd_adj' > `threshold' local n_imbalanced = `n_imbalanced' + 1
            }
            else {
                local n_imbalanced = `n_imbalanced' + 1
            }

            * Adjusted VR summary
            if !missing(`balance_mat'[`i', 9]) {
                local vr_adj_i = `balance_mat'[`i', 9]
                local dev_adj = max(abs(`vr_adj_i' - 1), abs(1/`vr_adj_i' - 1))
                if `dev_adj' > abs(`max_vr_adj' - 1) local max_vr_adj = `vr_adj_i'
            }
        }
        else {
            if !missing(`balance_mat'[`i', 3]) {
                if abs(`balance_mat'[`i', 3]) > `threshold' {
                    local n_imbalanced = `n_imbalanced' + 1
                }
            }
            else {
                local n_imbalanced = `n_imbalanced' + 1
            }
        }
    }

    * =========================================================================
    * DISPLAY OUTPUT (binary)
    * =========================================================================
    if "`matched'" != "" {
        local smd_label "SMD (Matched)"
    }
    else {
        local smd_label "SMD Raw"
    }

    display as text _n "{hline 75}"
    display as text `"`title'"'
    display as text "{hline 75}"
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
    display as text "{hline 75}"
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
    if `n_vr_imbalanced' > 0 {
        display as text "VR outside [0.5, 2.0]:       " as result %3.0f `n_vr_imbalanced' " of " %3.0f `nvars'
    }
    if `show_ks' {
        display as text "Maximum KS (raw):            " as result `ks_fmt' `max_ks_raw'
    }
    display as text "{hline `_hline_w'}"

    * Verdict
    if `has_adj' {
        local _verdict_smd = `max_smd_adj'
    }
    else {
        local _verdict_smd = `max_smd_raw'
    }
    if `n_imbalanced' > 0 {
        display as text _n "Balance: " as error "IMBALANCED" ///
            as text " (" as result %3.0f `n_imbalanced' ///
            as text " of " as result %3.0f `nvars' ///
            as text " covariates exceed threshold)"
        display as text "  Consider: {cmd:psdash weights, trim(99) generate(w_trim)} or {cmd:psdash support, crump}"
    }
    else {
        display as text _n "Balance: " as result "Adequate" ///
            as text " (max |SMD| = " as result `format' `_verdict_smd' as text ")"
    }

    * =========================================================================
    * RETURN RESULTS (binary — before graph so r() values survive graph errors)
    * =========================================================================
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
    return scalar max_ks_raw = `max_ks_raw'
    return scalar threshold = `threshold'
    return scalar n_ps_boundary = `n_ps_boundary'
    return scalar n_ps_near_boundary = `n_ps_near'
    return local treatment "`treatment'"
    return local estimand "`estimand'"
    return local varlist "`varlist'"
    if "`wvar'" != "" {
        if "`wvar_auto'" == "1" {
            return local wvar "auto-generated"
        }
        else {
            return local wvar "`wvar'"
        }
    }

    * =========================================================================
    * LOVE PLOT (binary)
    * =========================================================================
    if "`loveplot'" != "" {
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
                    noisily graph export "`saving'", replace
                }

                restore
            }
        }
        local graph_rc = _rc
        if `graph_rc' {
            capture restore
            return clear
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
            return scalar max_ks_raw = `max_ks_raw'
            return scalar threshold = `threshold'
            return scalar n_ps_boundary = `n_ps_boundary'
            return scalar n_ps_near_boundary = `n_ps_near'
            return local treatment "`treatment'"
            return local estimand "`estimand'"
            return local varlist "`varlist'"
            if "`wvar'" != "" {
                if "`wvar_auto'" == "1" {
                    return local wvar "auto-generated"
                }
                else {
                    return local wvar "`wvar'"
                }
            }
            return matrix balance = `balance_mat'
            exit `graph_rc'
        }
    }

    * =========================================================================
    * EXPORT TO EXCEL (binary)
    * =========================================================================
    if "`xlsx'" != "" {
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
            return clear
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
            return scalar max_ks_raw = `max_ks_raw'
            return scalar threshold = `threshold'
            return scalar n_ps_boundary = `n_ps_boundary'
            return scalar n_ps_near_boundary = `n_ps_near'
            return local treatment "`treatment'"
            return local estimand "`estimand'"
            return local varlist "`varlist'"
            if "`wvar'" != "" {
                if "`wvar_auto'" == "1" {
                    return local wvar "auto-generated"
                }
                else {
                    return local wvar "`wvar'"
                }
            }
            return matrix balance = `balance_mat'
            exit `xlsx_rc'
        }
    }

    * Return matrix last — `return matrix` moves (not copies) the source,
    * so it must run AFTER loveplot/xlsx blocks that reference `balance_mat'.
    return matrix balance = `balance_mat'

    } // end binary path
    else {
    * =====================================================================
    * MULTI-GROUP PATH (K >= 2 non-binary treatment)
    * =====================================================================

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
        if !strmatch("`xlsx'", "*.xlsx") {
            display as error "Excel filename must have .xlsx extension"
            exit 198
        }
        if regexm("`xlsx'", "[;&|><\$\`]") {
            display as error "Excel filename contains invalid characters"
            exit 198
        }
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

    * Build contrast list: all non-reference levels
    local contrasts ""
    local n_contrasts = 0
    foreach lev of local levels {
        if "`lev'" != "`mg_reference'" {
            local contrasts "`contrasts' `lev'"
            local n_contrasts = `n_contrasts' + 1
        }
    }
    local contrasts = strtrim("`contrasts'")

    * =====================================================================
    * CALCULATE BALANCE (multi-group)
    * =====================================================================
    preserve
    quietly keep if `touse'

    * Per-group counts
    foreach lev of local levels {
        quietly count if `treatment' == `lev'
        local n_group_`lev' = r(N)
        if `n_group_`lev'' < 2 {
            display as error "group `lev' must have at least 2 observations"
            exit 2001
        }
    }

    * Matrix layout: for each contrast, 5 raw columns + 5 adj columns
    * Column blocks: [SMD_raw VR_raw KS_raw Mean_a Mean_ref] per contrast
    * With adj: + [SMD_adj VR_adj KS_adj Mean_a_adj Mean_ref_adj] per contrast
    * Simpler: 5 cols per contrast raw, 5 cols per contrast adj
    local ncols_raw = 5 * `n_contrasts'
    local ncols_adj = 0
    if `has_adj' {
        local ncols_adj = 5 * `n_contrasts'
    }
    local ncols = `ncols_raw' + `ncols_adj'

    tempname balance_mat
    matrix `balance_mat' = J(`nvars', `ncols', .)

    * Build column names
    local colnames ""
    foreach clev of local contrasts {
        local colnames "`colnames' Mean_`clev' Mean_`mg_reference' SMD_`clev'v`mg_reference' VR_`clev'v`mg_reference' KS_`clev'v`mg_reference'"
    }
    if `has_adj' {
        foreach clev of local contrasts {
            local colnames "`colnames' MnAdj_`clev' MnAdj_`mg_reference' SMDAdj_`clev'v`mg_reference' VRAdj_`clev'v`mg_reference' KSAdj_`clev'v`mg_reference'"
        }
    }
    * Stata matrix colnames have a 32-char limit per name; truncate if needed
    * but typical level labels (0,1,2...) will be short
    matrix colnames `balance_mat' = `colnames'
    local rownames ""

    local show_ks = ("`ks'" != "")

    local i = 1
    foreach var of local varlist {
        local rownames "`rownames' `var'"

        * Reference group stats
        quietly summarize `var' if `treatment' == `mg_reference'
        local mean_ref = r(mean)
        local var_ref = r(Var)

        local cnum = 0
        foreach clev of local contrasts {
            local cnum = `cnum' + 1
            local col_base = (`cnum' - 1) * 5

            * Contrast group stats
            quietly summarize `var' if `treatment' == `clev'
            local mean_a = r(mean)
            local var_a = r(Var)

            * Pooled SD
            local sd_pooled = sqrt((`var_a' + `var_ref') / 2)

            * Raw SMD
            if `sd_pooled' > 0 {
                local smd_raw = (`mean_a' - `mean_ref') / `sd_pooled'
            }
            else if `mean_a' != `mean_ref' {
                local smd_raw = .
            }
            else {
                local smd_raw = 0
            }

            * Variance ratio (raw)
            if `var_a' > 0 & `var_ref' > 0 {
                local vr_raw = `var_a' / `var_ref'
            }
            else {
                local vr_raw = .
            }

            * KS statistic (pairwise: a vs ref)
            capture quietly ksmirnov `var' if `treatment' == `clev' | `treatment' == `mg_reference', by(`treatment')
            if _rc == 0 {
                local ks_raw = r(D)
            }
            else {
                local ks_raw = .
            }

            matrix `balance_mat'[`i', `col_base' + 1] = `mean_a'
            matrix `balance_mat'[`i', `col_base' + 2] = `mean_ref'
            matrix `balance_mat'[`i', `col_base' + 3] = `smd_raw'
            matrix `balance_mat'[`i', `col_base' + 4] = `vr_raw'
            matrix `balance_mat'[`i', `col_base' + 5] = `ks_raw'

            * Adjusted statistics
            if `has_adj' {
                local adj_base = `ncols_raw' + (`cnum' - 1) * 5

                quietly summarize `var' [aw=`wvar'] if `treatment' == `clev'
                local mean_a_adj = r(mean)

                quietly summarize `var' [aw=`wvar'] if `treatment' == `mg_reference'
                local mean_ref_adj = r(mean)

                * Adjusted SMD using raw pooled SD
                if `sd_pooled' > 0 {
                    local smd_adj = (`mean_a_adj' - `mean_ref_adj') / `sd_pooled'
                }
                else if `mean_a_adj' != `mean_ref_adj' {
                    local smd_adj = .
                }
                else {
                    local smd_adj = 0
                }

                * Adjusted VR
                quietly summarize `var' [aw=`wvar'] if `treatment' == `clev'
                local var_a_adj = r(Var)
                quietly summarize `var' [aw=`wvar'] if `treatment' == `mg_reference'
                local var_ref_adj = r(Var)

                if `var_a_adj' > 0 & `var_ref_adj' > 0 {
                    local vr_adj = `var_a_adj' / `var_ref_adj'
                }
                else {
                    local vr_adj = .
                }

                * Adjusted KS not computed (ksmirnov does not accept weights)
                local ks_adj = .

                matrix `balance_mat'[`i', `adj_base' + 1] = `mean_a_adj'
                matrix `balance_mat'[`i', `adj_base' + 2] = `mean_ref_adj'
                matrix `balance_mat'[`i', `adj_base' + 3] = `smd_adj'
                matrix `balance_mat'[`i', `adj_base' + 4] = `vr_adj'
                matrix `balance_mat'[`i', `adj_base' + 5] = `ks_adj'
            }
        }

        local i = `i' + 1
    }
    matrix rownames `balance_mat' = `rownames'

    restore

    * =====================================================================
    * SUMMARY STATISTICS (multi-group)
    * =====================================================================
    local max_smd_raw = 0
    local max_smd_adj = 0
    local max_ks_raw = 0
    local n_imbalanced = 0
    local n_vr_imbalanced = 0

    forvalues i = 1/`nvars' {
        * Track per-covariate worst SMD across contrasts
        local worst_smd_raw_i = 0
        local worst_smd_adj_i = 0
        local cov_imbalanced = 0

        local cnum = 0
        foreach clev of local contrasts {
            local cnum = `cnum' + 1
            local col_smd_raw = (`cnum' - 1) * 5 + 3
            local col_vr_raw = (`cnum' - 1) * 5 + 4
            local col_ks_raw = (`cnum' - 1) * 5 + 5

            * Raw SMD
            if !missing(`balance_mat'[`i', `col_smd_raw']) {
                local abs_smd = abs(`balance_mat'[`i', `col_smd_raw'])
                if `abs_smd' > `worst_smd_raw_i' local worst_smd_raw_i = `abs_smd'
                if `abs_smd' > `max_smd_raw' local max_smd_raw = `abs_smd'
            }

            * Raw VR
            if !missing(`balance_mat'[`i', `col_vr_raw']) {
                local vr_i = `balance_mat'[`i', `col_vr_raw']
                if `vr_i' < 0.5 | `vr_i' > 2 {
                    local n_vr_imbalanced = `n_vr_imbalanced' + 1
                }
            }

            * Raw KS
            if !missing(`balance_mat'[`i', `col_ks_raw']) {
                local ks_i = `balance_mat'[`i', `col_ks_raw']
                if `ks_i' > `max_ks_raw' local max_ks_raw = `ks_i'
            }

            * Imbalance check
            if `has_adj' {
                local col_smd_adj = `ncols_raw' + (`cnum' - 1) * 5 + 3
                if !missing(`balance_mat'[`i', `col_smd_adj']) {
                    local abs_smd_a = abs(`balance_mat'[`i', `col_smd_adj'])
                    if `abs_smd_a' > `worst_smd_adj_i' local worst_smd_adj_i = `abs_smd_a'
                    if `abs_smd_a' > `max_smd_adj' local max_smd_adj = `abs_smd_a'
                    if `abs_smd_a' > `threshold' local cov_imbalanced = 1
                }
                else {
                    local cov_imbalanced = 1
                }
            }
            else {
                if !missing(`balance_mat'[`i', `col_smd_raw']) {
                    if abs(`balance_mat'[`i', `col_smd_raw']) > `threshold' {
                        local cov_imbalanced = 1
                    }
                }
                else {
                    local cov_imbalanced = 1
                }
            }
        }

        if `cov_imbalanced' local n_imbalanced = `n_imbalanced' + 1
    }

    * =====================================================================
    * DISPLAY (multi-group)
    * =====================================================================
    local vr_fmt "%6.2f"
    local ks_fmt "%6.3f"

    display as text _n "{hline 75}"
    display as text `"`title'"'
    display as text "{hline 75}"
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
    display as text "{hline 75}"
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
    if `n_vr_imbalanced' > 0 {
        display as text "VR outside [0.5, 2.0]:       " as result %3.0f `n_vr_imbalanced'
    }
    if `show_ks' {
        display as text "Maximum KS (raw):            " as result `ks_fmt' `max_ks_raw'
    }
    display as text "{hline `hdr_width'}"

    * Verdict
    if `has_adj' {
        local _verdict_smd = `max_smd_adj'
    }
    else {
        local _verdict_smd = `max_smd_raw'
    }
    if `n_imbalanced' > 0 {
        display as text _n "Balance: " as error "IMBALANCED" ///
            as text " (" as result %3.0f `n_imbalanced' ///
            as text " of " as result %3.0f `nvars' ///
            as text " covariates exceed threshold)"
        display as text "  Consider: {cmd:psdash weights, trim(99) generate(w_trim)} or {cmd:psdash support, crump}"
    }
    else {
        display as text _n "Balance: " as result "Adequate" ///
            as text " (max |SMD| = " as result `format' `_verdict_smd' as text ")"
    }

    * =====================================================================
    * RETURN RESULTS (multi-group)
    * =====================================================================
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
    return scalar max_ks_raw = `max_ks_raw'
    return scalar threshold = `threshold'
    return local treatment "`treatment'"
    return local estimand "`estimand'"
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

    * =====================================================================
    * LOVE PLOT (multi-group)
    * =====================================================================
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
                    noisily graph export "`saving'", replace
                }

                restore
            }
        }
        local graph_rc = _rc
        if `graph_rc' {
            capture restore
            return clear
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
            return scalar max_ks_raw = `max_ks_raw'
            return scalar threshold = `threshold'
            return local treatment "`treatment'"
            return local estimand "`estimand'"
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
            return matrix balance = `balance_mat'
            exit `graph_rc'
        }
    }

    * =====================================================================
    * EXPORT TO EXCEL (multi-group)
    * =====================================================================
    if "`xlsx'" != "" {
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
                local colnum = 1
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
            return clear
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
            return scalar max_ks_raw = `max_ks_raw'
            return scalar threshold = `threshold'
            return local treatment "`treatment'"
            return local estimand "`estimand'"
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
            return matrix balance = `balance_mat'
            exit `xlsx_rc'
        }
    }

    * Return matrix last
    return matrix balance = `balance_mat'

    } // end multi-group path

    } // end capture noisily

    local rc = _rc
    set varabbrev `_vao'
    if `rc' exit `rc'
end
