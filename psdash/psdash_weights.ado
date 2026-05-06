*! psdash_weights Version 1.0.1  2026/05/06
*! IPTW weight diagnostics - distribution, ESS, extreme weights, trimming
*! Author: Timothy P Copeland
*! Program class: rclass
*! Adapted from: iptw_diag v1.0.5

/*
DESCRIPTION:
    Comprehensive diagnostics for inverse probability of treatment weights (IPTW).
    Assesses weight distribution, calculates effective sample size, detects
    extreme weights, and provides weight trimming/stabilization utilities.

    Supports binary (0/1) and multi-group (K >= 2) treatments.

SYNTAX:
    psdash weights [treatment] [psvar] [if] [in] , [options]

    Treatment and PS can be auto-detected from teffects/logit/probit context.
    Weights are auto-generated from PS if not specified.

Options:
    wvar(varname)       - Weight variable (auto-generated from PS if omitted)
    trim(#)             - Trim weights at specified percentile (50-99.9)
    truncate(#)         - Truncate weights at maximum value
    stabilize           - Calculate stabilized weights
    generate(name)      - Name for trimmed/stabilized weight variable
    replace             - Allow replacing existing variable
    reference(string)   - Reference group for multi-group (default: lowest level)
    detail              - Show detailed percentile distribution
    graph               - Display weight distribution histogram
    saving(string)      - Save graph to file
    xlabel(numlist)     - Custom x-axis labels for graph
    scheme(string)      - Graph scheme
    graphoptions(string)- Additional graph options
    name(string)        - Graph name (default: psdash_weights)

STORED RESULTS (binary):
    r(N)            - Number of observations
    r(N_treated)    - Number in treatment group
    r(N_control)    - Number in control group
    r(mean_wt)      - Mean weight
    r(sd_wt)        - SD of weights
    r(min_wt)       - Minimum weight
    r(max_wt)       - Maximum weight
    r(cv)           - Coefficient of variation
    r(ess)          - Effective sample size
    r(ess_pct)      - ESS as percentage of N
    r(ess_treated)  - ESS for treated group
    r(ess_control)  - ESS for control group
    r(ess_pct_treated)  - ESS percentage for treated group
    r(ess_pct_control)  - ESS percentage for control group
    r(n_extreme)    - Number of extreme weights (>10)
    r(pct_extreme)  - Percentage of extreme weights
    r(p1), r(p5), r(p95), r(p99) - Percentiles
    r(wvar)         - Weight variable name, or "auto-generated" if temporary

STORED RESULTS (multi-group, additional/changed):
    r(K)                    - Number of treatment groups
    r(N_group_<lev>)        - Per-group N
    r(ess_group_<lev>)      - Per-group ESS
    r(ess_pct_group_<lev>)  - Per-group ESS percentage
    r(levels)               - Space-separated list of treatment levels
    r(reference)            - Reference group level
*/

program define psdash_weights, rclass
    version 16.0
    local _vao = c(varabbrev)
    set varabbrev off

    capture noisily {

    * =========================================================================
    * SYNTAX PARSING
    * =========================================================================
    syntax [anything] [if] [in], ///
        [Wvar(varname) ///
         TRIM(real 0) ///
         TRUNCate(real 0) ///
         STABilize ///
         GENerate(name) ///
         replace ///
         REFerence(string) ///
         DETail ///
         GRaph ///
         SAVing(string) ///
         xlabel(numlist) ///
         SCHeme(string) ///
         GRAPHOPTions(string asis) ///
         name(string) ///
         ESTImand(string) ///
         PSVars(varlist numeric)]

    * =========================================================================
    * MARK SAMPLE
    * =========================================================================
    tempvar touse ps_auto wt_auto
    mark `touse' `if' `in'

    * =========================================================================
    * AUTO-DETECT PS COMPONENTS
    * =========================================================================
    * For weights, user may provide treatment + wvar without a PS variable.
    * The detect helper requires psvar for manual mode, so handle the
    * treatment-only + wvar case ourselves before falling through to detect.
    local _manual_mg = 0
    local _n_pos_args : word count `anything'
    local _has_est_ctx = inlist("`e(cmd)'", "logit", "probit", "logistic", "mlogit", "teffects")
    if `_n_pos_args' == 1 & "`wvar'" != "" & !`_has_est_ctx' {
        * Single positional arg (treatment) with explicit wvar: manual detect
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
    else if `_n_pos_args' == 0 & "`wvar'" != "" {
        * No positional args but wvar specified: need estimation context
        * Fall through to _psdash_detect which handles e(cmd) detection
        local _manual_mg = 0
    }

    local psvars_opt ""
    if "`psvars'" != "" {
        local psvars_opt "psvars(`psvars')"
    }

    if !`_manual_mg' {
        _psdash_detect `anything' , wvar(`wvar') samplevar(`touse') ///
            estimand(`estimand') psout(`ps_auto') wout(`wt_auto') getwvar ///
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

    * Use detected weights or auto-generate from PS
    if "`wvar'" == "" & "`_psd_wvar'" != "" {
        local wvar "`_psd_wvar'"
        local wvar_auto "`_psd_wvar_auto'"
    }
    else if "`wvar'" == "" & "`psvar'" != "" & "`multigroup'" == "0" {
        * Auto-generate IPTW weights from PS (binary only; multi-group requires wvar)
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

    * Track all multigroup PS inputs so output-name guards can protect them.
    local mg_psvars_all ""
    if "`multigroup'" != "0" {
        foreach lev of local levels {
            local this_ps "`_psd_ps_`lev''"
            if "`this_ps'" != "" {
                local mg_psvars_all "`mg_psvars_all' `this_ps'"
            }
        }
        if "`mg_psvars_all'" == "" & "`psvar'" != "" {
            local mg_psvars_all "`psvar'"
        }
        local mg_psvars_all : list uniq mg_psvars_all
    }

    if "`wvar'" == "" {
        display as error "weight variable required"
        display as error "  specify wvar() or provide a propensity score variable"
        exit 198
    }

    * Restrict PS diagnostics to rows with nonmissing treatment and PS.
    markout `touse' `treatment'
    if "`psvar'" != "" markout `touse' `psvar'

    * Positivity warnings (when PS is available, binary only)
    local n_ps_boundary = 0
    local n_ps_near = 0
    if "`psvar'" != "" & "`multigroup'" == "0" {
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

    * Mark out missing weights after PS diagnostics have been computed on
    * the intended PS sample.
    markout `touse' `wvar'

    quietly count if `touse'
    if r(N) == 0 {
        display as error "no observations"
        exit 2000
    }
    local N = r(N)

    * =========================================================================
    * BRANCH: BINARY vs MULTI-GROUP
    * =========================================================================
    if "`multigroup'" == "0" {
    * =====================================================================
    * BINARY PATH (unchanged from v1.1.9)
    * =====================================================================

    * Validate treatment is binary
    capture assert inlist(`treatment', 0, 1) if `touse'
    if _rc {
        display as error "treatment must be binary (0/1)"
        exit 198
    }

    * Validate both treatment groups present with minimum size
    quietly count if `treatment' == 1 & `touse'
    if r(N) < 2 {
        display as error "each treatment group must have at least 2 observations"
        exit 2001
    }
    quietly count if `treatment' == 0 & `touse'
    if r(N) < 2 {
        display as error "each treatment group must have at least 2 observations"
        exit 2001
    }

    * Check weights are non-negative. Individual zero weights are valid for
    * boundary PS in ATT/ATC, but each group needs positive total weight.
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

    * Validate trim percentile
    if `trim' != 0 {
        if `trim' < 50 | `trim' > 99.9 {
            display as error "trim() must be between 50 and 99.9"
            exit 198
        }
    }

    * Validate truncate value
    if `truncate' != 0 {
        if `truncate' <= 0 {
            display as error "truncate() must be positive"
            exit 198
        }
    }

    * Check for conflicting modification options
    if `trim' != 0 & `truncate' != 0 {
        display as error "cannot specify both trim() and truncate()"
        exit 198
    }
    if "`stabilize'" != "" & (`trim' != 0 | `truncate' != 0) {
        display as error "cannot combine stabilize with trim() or truncate()"
        exit 198
    }

    * Validate generate is provided when modification requested
    if (`trim' != 0 | `truncate' != 0 | "`stabilize'" != "") & "`generate'" == "" {
        display as error "generate() required with trim(), truncate(), or stabilize"
        exit 198
    }

    * Prevent generate from overwriting input variables
    if "`generate'" != "" & (`trim' != 0 | `truncate' != 0 | "`stabilize'" != "") {
        if "`generate'" == "`wvar'" {
            display as error "generate() cannot be the same as the weight variable"
            exit 198
        }
        if "`generate'" == "`treatment'" {
            display as error "generate() cannot be the same as the treatment variable"
            exit 198
        }
        if "`generate'" == "`psvar'" {
            display as error "generate() cannot be the same as the propensity score variable"
            exit 198
        }
        if substr("`generate'", 1, 8) == "_psdash_" {
            display as error "generate() cannot use the reserved _psdash_ prefix"
            exit 198
        }
    }

    * Validate generate variable name
    if "`generate'" != "" & "`replace'" == "" ///
        & (`trim' != 0 | `truncate' != 0 | "`stabilize'" != "") {
        capture confirm new variable `generate'
        if _rc {
            display as error "variable `generate' already exists; use replace option"
            exit 110
        }
    }

    * Set defaults
    if "`name'" == "" local name "psdash_weights"

    * =========================================================================
    * CALCULATE WEIGHT STATISTICS (binary)
    * =========================================================================
    quietly {
        * Overall weight statistics
        summarize `wvar' if `touse', detail
        local mean_wt = r(mean)
        local sd_wt = r(sd)
        local min_wt = r(min)
        local max_wt = r(max)
        local p1 = r(p1)
        local p5 = r(p5)
        local p10 = r(p10)
        local p25 = r(p25)
        local p50 = r(p50)
        local p75 = r(p75)
        local p90 = r(p90)
        local p95 = r(p95)
        local p99 = r(p99)

        * Coefficient of variation
        local cv = `sd_wt' / `mean_wt'

        * Statistics by treatment group
        summarize `wvar' if `touse' & `treatment' == 1, detail
        local mean_wt_t = r(mean)
        local sd_wt_t = r(sd)
        local min_wt_t = r(min)
        local max_wt_t = r(max)
        local n_treated = r(N)

        summarize `wvar' if `touse' & `treatment' == 0, detail
        local mean_wt_c = r(mean)
        local sd_wt_c = r(sd)
        local min_wt_c = r(min)
        local max_wt_c = r(max)
        local n_control = r(N)

        * Effective Sample Size: ESS = (sum w)^2 / sum(w^2)
        tempvar wt_sq
        gen double `wt_sq' = `wvar'^2 if `touse'

        * Overall ESS
        summarize `wvar' if `touse'
        local sum_wt = r(sum)
        summarize `wt_sq' if `touse'
        local sum_wt_sq = r(sum)
        local ess = (`sum_wt'^2) / `sum_wt_sq'
        local ess_pct = 100 * `ess' / `N'

        * ESS by treatment group
        summarize `wvar' if `touse' & `treatment' == 1
        local sum_wt_t = r(sum)
        summarize `wt_sq' if `touse' & `treatment' == 1
        local sum_wt_sq_t = r(sum)
        local ess_t = (`sum_wt_t'^2) / `sum_wt_sq_t'
        local ess_pct_t = 100 * `ess_t' / `n_treated'

        summarize `wvar' if `touse' & `treatment' == 0
        local sum_wt_c = r(sum)
        summarize `wt_sq' if `touse' & `treatment' == 0
        local sum_wt_sq_c = r(sum)
        local ess_c = (`sum_wt_c'^2) / `sum_wt_sq_c'
        local ess_pct_c = 100 * `ess_c' / `n_control'

        drop `wt_sq'

        * Extreme weights
        count if `wvar' > 10 & `touse'
        local n_extreme = r(N)
        local pct_extreme = 100 * `n_extreme' / `N'

        count if `wvar' > 20 & `touse'
        local n_very_extreme = r(N)
    }

    * =========================================================================
    * DISPLAY OUTPUT (binary)
    * =========================================================================
    display as text _n "{hline 70}"
    display as text "IPTW Weight Diagnostics"
    display as text "{hline 70}"
    local wvar_label "`wvar'"
    if "`wvar_auto'" == "1" local wvar_label "auto-generated"
    display as text "Weight variable:   " as result "`wvar_label'"
    display as text "Treatment:         " as result "`treatment'"
    display as text "Observations:      " as result %10.0fc `N'
    if "`source'" != "manual" {
        display as text "Source:            " as result "`source'"
    }
    display as text "{hline 70}"
    display ""

    * Weight distribution summary
    display as text "{hline 70}"
    display as text "Weight Distribution Summary"
    display as text "{hline 70}"
    display as text %25s "" %15s "Overall" %15s "Treated" %15s "Control"
    display as text "{hline 70}"
    display as text %25s "N" ///
        as result %15.0fc `N' %15.0fc `n_treated' %15.0fc `n_control'
    display as text %25s "Mean" ///
        as result %15.3f `mean_wt' %15.3f `mean_wt_t' %15.3f `mean_wt_c'
    display as text %25s "SD" ///
        as result %15.3f `sd_wt' %15.3f `sd_wt_t' %15.3f `sd_wt_c'
    display as text %25s "Min" ///
        as result %15.3f `min_wt' %15.3f `min_wt_t' %15.3f `min_wt_c'
    display as text %25s "Max" ///
        as result %15.3f `max_wt' %15.3f `max_wt_t' %15.3f `max_wt_c'
    display as text "{hline 70}"
    display ""

    * Percentile distribution
    if "`detail'" != "" {
        display as text "{hline 50}"
        display as text "Percentile Distribution (Overall)"
        display as text "{hline 50}"
        display as text %15s "Percentile" %15s "Weight"
        display as text "{hline 50}"
        display as text %15s "1%" as result %15.3f `p1'
        display as text %15s "5%" as result %15.3f `p5'
        display as text %15s "10%" as result %15.3f `p10'
        display as text %15s "25%" as result %15.3f `p25'
        display as text %15s "50% (median)" as result %15.3f `p50'
        display as text %15s "75%" as result %15.3f `p75'
        display as text %15s "90%" as result %15.3f `p90'
        display as text %15s "95%" as result %15.3f `p95'
        display as text %15s "99%" as result %15.3f `p99'
        display as text "{hline 50}"
        display ""
    }

    * Effective sample size
    display as text "{hline 70}"
    display as text "Effective Sample Size (ESS)"
    display as text "{hline 70}"
    display as text %25s "" %15s "Overall" %15s "Treated" %15s "Control"
    display as text "{hline 70}"
    display as text %25s "ESS" ///
        as result %15.1f `ess' %15.1f `ess_t' %15.1f `ess_c'
    display as text %25s "ESS % of N" ///
        as result %14.1f `ess_pct' "%" %14.1f `ess_pct_t' "%" %14.1f `ess_pct_c' "%"
    display as text "{hline 70}"
    display ""

    * Extreme weights
    display as text "{hline 50}"
    display as text "Extreme Weight Detection"
    display as text "{hline 50}"
    display as text "Coefficient of Variation: " as result %8.3f `cv'
    display as text "Weights > 10:             " as result %8.0f `n_extreme' ///
        as text " (" as result %5.2f `pct_extreme' as text "%)"
    display as text "Weights > 20:             " as result %8.0f `n_very_extreme'
    display as text "{hline 50}"

    * Warnings
    display ""
    if `ess_pct' < 50 {
        display as error "Warning: ESS is less than 50% of N. Consider trimming weights."
    }
    if `cv' > 1 {
        display as error "Warning: High CV indicates substantial weight variability."
    }
    if `n_extreme' > 0 {
        display as error "Warning: `n_extreme' extreme weights detected (>10)."
    }
    if `max_wt' > 20 {
        display as error "Warning: Maximum weight exceeds 20. Consider truncation."
    }

    * Verdict
    if `ess_pct' < 50 {
        display as text _n "Weights: " as error "WARNING" ///
            as text " (ESS = " as result %4.1f `ess_pct' as text "% of N)"
        display as text "  Consider: {cmd:psdash weights, trim(99) generate(w_trim)} or {cmd:psdash weights, truncate(#) generate(w_trunc)}"
    }
    else {
        display as text _n "Weights: " as result "Acceptable" ///
            as text " (ESS = " as result %4.1f `ess_pct' as text "% of N)"
    }

    * =========================================================================
    * WEIGHT TRIMMING/STABILIZATION (binary)
    * =========================================================================
    if "`generate'" != "" & `trim' == 0 & `truncate' == 0 & "`stabilize'" == "" {
        display as error "generate() requires trim(), truncate(), or stabilize"
        exit 198
    }

    if `trim' != 0 | `truncate' != 0 | "`stabilize'" != "" {
        quietly {
            if "`replace'" != "" {
                capture drop `generate'  // safe: capture swallows 111 if var doesn't exist
            }

            if `trim' != 0 {
                _pctile `wvar' if `touse', p(`trim')
                local trim_val = r(r1)
                gen double `generate' = min(`wvar', `trim_val') if `touse'
                label variable `generate' "`wvar_label' trimmed at p`trim'"
                local action "Trimmed at p`trim' (cutoff: `=string(`trim_val', "%6.3f")')"
            }
            else if `truncate' != 0 {
                gen double `generate' = min(`wvar', `truncate') if `touse'
                label variable `generate' "`wvar_label' truncated at `truncate'"
                local action "Truncated at `truncate'"
            }
            else if "`stabilize'" != "" {
                summarize `treatment' if `touse'
                local p_treat = r(mean)

                gen double `generate' = cond(`treatment' == 1, ///
                    `p_treat' * `wvar', (1 - `p_treat') * `wvar') if `touse'
                label variable `generate' "`wvar_label' stabilized"
                local action "Stabilized (P(T=1) = `=string(`p_treat', "%6.3f")')"
            }

            * Report new weight statistics
            summarize `generate' if `touse', detail
            local new_mean = r(mean)
            local new_sd = r(sd)
            local new_min = r(min)
            local new_max = r(max)
            local new_cv = `new_sd' / `new_mean'

            * New ESS
            tempvar new_wt_sq
            gen double `new_wt_sq' = `generate'^2 if `touse'
            summarize `generate' if `touse'
            local new_sum_wt = r(sum)
            summarize `new_wt_sq' if `touse'
            local new_sum_wt_sq = r(sum)
            local new_ess = (`new_sum_wt'^2) / `new_sum_wt_sq'
            local new_ess_pct = 100 * `new_ess' / `N'
            drop `new_wt_sq'
        }

        display ""
        display as text "{hline 70}"
        display as text "Modified Weight Statistics: `generate'"
        display as text "`action'"
        display as text "{hline 70}"
        display as text %25s "Statistic" %15s "Original" %15s "Modified"
        display as text "{hline 70}"
        display as text %25s "Mean" ///
            as result %15.3f `mean_wt' %15.3f `new_mean'
        display as text %25s "SD" ///
            as result %15.3f `sd_wt' %15.3f `new_sd'
        display as text %25s "Max" ///
            as result %15.3f `max_wt' %15.3f `new_max'
        display as text %25s "CV" ///
            as result %15.3f `cv' %15.3f `new_cv'
        display as text %25s "ESS" ///
            as result %15.1f `ess' %15.1f `new_ess'
        display as text %25s "ESS % of N" ///
            as result %14.1f `ess_pct' "%" %14.1f `new_ess_pct' "%"
        display as text "{hline 70}"

        return scalar new_mean = `new_mean'
        return scalar new_sd = `new_sd'
        return scalar new_min = `new_min'
        return scalar new_max = `new_max'
        return scalar new_cv = `new_cv'
        return scalar new_ess = `new_ess'
        return scalar new_ess_pct = `new_ess_pct'
        return local generate "`generate'"
    }

    * =========================================================================
    * RETURN RESULTS (binary — before graph so r() values survive graph errors)
    * =========================================================================
    return scalar N = `N'
    return scalar N_treated = `n_treated'
    return scalar N_control = `n_control'
    return scalar mean_wt = `mean_wt'
    return scalar sd_wt = `sd_wt'
    return scalar min_wt = `min_wt'
    return scalar max_wt = `max_wt'
    return scalar cv = `cv'
    return scalar ess = `ess'
    return scalar ess_pct = `ess_pct'
    return scalar ess_treated = `ess_t'
    return scalar ess_control = `ess_c'
    return scalar ess_pct_treated = `ess_pct_t'
    return scalar ess_pct_control = `ess_pct_c'
    return scalar n_extreme = `n_extreme'
    return scalar pct_extreme = `pct_extreme'
    return scalar p1 = `p1'
    return scalar p5 = `p5'
    return scalar p95 = `p95'
    return scalar p99 = `p99'
    if "`psvar'" != "" {
        return scalar n_ps_boundary = `n_ps_boundary'
        return scalar n_ps_near_boundary = `n_ps_near'
    }
    if "`wvar_auto'" == "1" {
        return local wvar "auto-generated"
    }
    else {
        return local wvar "`wvar'"
    }
    return local treatment "`treatment'"
    return local estimand "`estimand'"

    * =========================================================================
    * WEIGHT DISTRIBUTION GRAPH (binary)
    * =========================================================================
    if "`graph'" == "" {
        if "`saving'" != "" {
            display as text "note: saving() ignored without graph option"
        }
        if "`xlabel'" != "" {
            display as text "note: xlabel() ignored without graph option"
        }
    }

    if "`graph'" != "" {
        capture noisily {
            quietly {
                if "`xlabel'" == "" {
                    local xlabel "0 2 5 10 15 20"
                }

                local scheme_opt ""
                if "`scheme'" != "" {
                    local scheme_opt "scheme(`scheme')"
                }

                local bw = (`max_wt' - `min_wt') / min(20, ceil(sqrt(`N')))
                if `bw' <= 0 {
                    local bw = 1
                }

                noisily twoway (histogram `wvar' if `touse' & `treatment' == 1, ///
                           frequency fcolor(navy%50) lcolor(navy) width(`bw')) ///
                       (histogram `wvar' if `touse' & `treatment' == 0, ///
                           frequency fcolor(cranberry%50) lcolor(cranberry) width(`bw')), ///
                       legend(order(1 "Treated" 2 "Control") rows(1) position(6)) ///
                       xtitle("IPTW Weight") ytitle("Frequency") ///
                       title("IPTW Weight Distribution") ///
                       xlabel(`xlabel') ///
                       xline(1, lcolor(gs8) lpattern(dash)) ///
                       name(`name', replace) ///
                       `scheme_opt' `graphoptions'

                if "`saving'" != "" {
                    noisily graph export "`saving'", replace
                }
            }
        }
        local graph_rc = _rc
        if `graph_rc' {
            return clear
            if "`generate'" != "" {
                return scalar new_mean = `new_mean'
                return scalar new_sd = `new_sd'
                return scalar new_min = `new_min'
                return scalar new_max = `new_max'
                return scalar new_cv = `new_cv'
                return scalar new_ess = `new_ess'
                return scalar new_ess_pct = `new_ess_pct'
                return local generate "`generate'"
            }
            return scalar N = `N'
            return scalar N_treated = `n_treated'
            return scalar N_control = `n_control'
            return scalar mean_wt = `mean_wt'
            return scalar sd_wt = `sd_wt'
            return scalar min_wt = `min_wt'
            return scalar max_wt = `max_wt'
            return scalar cv = `cv'
            return scalar ess = `ess'
            return scalar ess_pct = `ess_pct'
            return scalar ess_treated = `ess_t'
            return scalar ess_control = `ess_c'
            return scalar ess_pct_treated = `ess_pct_t'
            return scalar ess_pct_control = `ess_pct_c'
            return scalar n_extreme = `n_extreme'
            return scalar pct_extreme = `pct_extreme'
            return scalar p1 = `p1'
            return scalar p5 = `p5'
            return scalar p95 = `p95'
            return scalar p99 = `p99'
            if "`psvar'" != "" {
                return scalar n_ps_boundary = `n_ps_boundary'
                return scalar n_ps_near_boundary = `n_ps_near'
            }
            if "`wvar_auto'" == "1" {
                return local wvar "auto-generated"
            }
            else {
                return local wvar "`wvar'"
            }
            return local treatment "`treatment'"
            return local estimand "`estimand'"
            exit `graph_rc'
        }
    }

    } // end binary path
    else {
    * =====================================================================
    * MULTI-GROUP PATH (K >= 2 non-binary treatment)
    * =====================================================================

    * Validate both weights and all groups
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
        quietly count if `treatment' == `lev' & `touse'
        if r(N) < 2 {
            display as error "group `lev' must have at least 2 observations"
            exit 2001
        }
        quietly summarize `wvar' if `touse' & `treatment' == `lev'
        if r(sum) <= 0 {
            display as error "group `lev' must have positive total weight"
            exit 198
        }
    }

    * Validate trim percentile
    if `trim' != 0 {
        if `trim' < 50 | `trim' > 99.9 {
            display as error "trim() must be between 50 and 99.9"
            exit 198
        }
    }

    * Validate truncate value
    if `truncate' != 0 {
        if `truncate' <= 0 {
            display as error "truncate() must be positive"
            exit 198
        }
    }

    * Check for conflicting modification options
    if `trim' != 0 & `truncate' != 0 {
        display as error "cannot specify both trim() and truncate()"
        exit 198
    }
    if "`stabilize'" != "" & (`trim' != 0 | `truncate' != 0) {
        display as error "cannot combine stabilize with trim() or truncate()"
        exit 198
    }

    * Validate generate
    if (`trim' != 0 | `truncate' != 0 | "`stabilize'" != "") & "`generate'" == "" {
        display as error "generate() required with trim(), truncate(), or stabilize"
        exit 198
    }

    if "`generate'" != "" & (`trim' != 0 | `truncate' != 0 | "`stabilize'" != "") {
        local reserved_names "`wvar' `treatment' `mg_psvars_all'"
        local reserved_names : list uniq reserved_names
        foreach reserved of local reserved_names {
            if "`reserved'" == "" continue
            if "`generate'" == "`reserved'" {
                if "`reserved'" == "`wvar'" {
                    display as error "generate() cannot be the same as the weight variable"
                }
                else if "`reserved'" == "`treatment'" {
                    display as error "generate() cannot be the same as the treatment variable"
                }
                else {
                    display as error "generate() cannot be the same as `reserved'"
                }
                exit 198
            }
        }
        if substr("`generate'", 1, 8) == "_psdash_" {
            display as error "generate() cannot use the reserved _psdash_ prefix"
            exit 198
        }
    }

    if "`generate'" != "" & "`replace'" == "" ///
        & (`trim' != 0 | `truncate' != 0 | "`stabilize'" != "") {
        capture confirm new variable `generate'
        if _rc {
            display as error "variable `generate' already exists; use replace option"
            exit 110
        }
    }

    if "`generate'" != "" & `trim' == 0 & `truncate' == 0 & "`stabilize'" == "" {
        display as error "generate() requires trim(), truncate(), or stabilize"
        exit 198
    }

    if "`name'" == "" local name "psdash_weights"

    * =====================================================================
    * CALCULATE WEIGHT STATISTICS (multi-group)
    * =====================================================================
    quietly {
        * Overall weight statistics
        summarize `wvar' if `touse', detail
        local mean_wt = r(mean)
        local sd_wt = r(sd)
        local min_wt = r(min)
        local max_wt = r(max)
        local p1 = r(p1)
        local p5 = r(p5)
        local p10 = r(p10)
        local p25 = r(p25)
        local p50 = r(p50)
        local p75 = r(p75)
        local p90 = r(p90)
        local p95 = r(p95)
        local p99 = r(p99)

        local cv = `sd_wt' / `mean_wt'

        * Per-group statistics
        foreach lev of local levels {
            summarize `wvar' if `touse' & `treatment' == `lev', detail
            local mean_wt_`lev' = r(mean)
            local sd_wt_`lev' = r(sd)
            local min_wt_`lev' = r(min)
            local max_wt_`lev' = r(max)
            local n_group_`lev' = r(N)
        }

        * ESS overall
        tempvar wt_sq
        gen double `wt_sq' = `wvar'^2 if `touse'

        summarize `wvar' if `touse'
        local sum_wt = r(sum)
        summarize `wt_sq' if `touse'
        local sum_wt_sq = r(sum)
        local ess = (`sum_wt'^2) / `sum_wt_sq'
        local ess_pct = 100 * `ess' / `N'

        * ESS per group
        foreach lev of local levels {
            summarize `wvar' if `touse' & `treatment' == `lev'
            local sum_wt_`lev' = r(sum)
            summarize `wt_sq' if `touse' & `treatment' == `lev'
            local sum_wtsq_`lev' = r(sum)
            local ess_`lev' = (`sum_wt_`lev''^2) / `sum_wtsq_`lev''
            local ess_pct_`lev' = 100 * `ess_`lev'' / `n_group_`lev''
        }

        drop `wt_sq'

        * Extreme weights
        count if `wvar' > 10 & `touse'
        local n_extreme = r(N)
        local pct_extreme = 100 * `n_extreme' / `N'

        count if `wvar' > 20 & `touse'
        local n_very_extreme = r(N)
    }

    * =====================================================================
    * DISPLAY (multi-group)
    * =====================================================================
    display as text _n "{hline 70}"
    display as text "IPTW Weight Diagnostics (Multi-Group)"
    display as text "{hline 70}"
    local wvar_label "`wvar'"
    if "`wvar_auto'" == "1" local wvar_label "auto-generated"
    display as text "Weight variable:   " as result "`wvar_label'"
    display as text "Treatment:         " as result "`treatment'" as text " (`K' groups, ref = `mg_reference')"
    display as text "Observations:      " as result %10.0fc `N'
    if "`source'" != "manual" {
        display as text "Source:            " as result "`source'"
    }
    display as text "{hline 70}"
    display ""

    * Dynamic column width: Overall + one column per group
    * Column width = 15 chars each
    local tbl_width = 25 + 15 + 15 * `K'
    local tbl_width = min(`tbl_width', 120)

    * Weight distribution summary
    display as text "{hline `tbl_width'}"
    display as text "Weight Distribution Summary"
    display as text "{hline `tbl_width'}"

    * Header row
    display as text %25s "" %15s "Overall" _c
    foreach lev of local levels {
        * Try to get value labels
        local lbl_`lev' "Group `lev'"
        local vallbl : value label `treatment'
        if "`vallbl'" != "" {
            local lbl_`lev' : label `vallbl' `lev'
        }
        display as text %15s "`lbl_`lev''" _c
    }
    display ""
    display as text "{hline `tbl_width'}"

    * N row
    display as text %25s "N" as result %15.0fc `N' _c
    foreach lev of local levels {
        display as result %15.0fc `n_group_`lev'' _c
    }
    display ""

    * Mean row
    display as text %25s "Mean" as result %15.3f `mean_wt' _c
    foreach lev of local levels {
        display as result %15.3f `mean_wt_`lev'' _c
    }
    display ""

    * SD row
    display as text %25s "SD" as result %15.3f `sd_wt' _c
    foreach lev of local levels {
        display as result %15.3f `sd_wt_`lev'' _c
    }
    display ""

    * Min row
    display as text %25s "Min" as result %15.3f `min_wt' _c
    foreach lev of local levels {
        display as result %15.3f `min_wt_`lev'' _c
    }
    display ""

    * Max row
    display as text %25s "Max" as result %15.3f `max_wt' _c
    foreach lev of local levels {
        display as result %15.3f `max_wt_`lev'' _c
    }
    display ""
    display as text "{hline `tbl_width'}"
    display ""

    * Percentile distribution
    if "`detail'" != "" {
        display as text "{hline 50}"
        display as text "Percentile Distribution (Overall)"
        display as text "{hline 50}"
        display as text %15s "Percentile" %15s "Weight"
        display as text "{hline 50}"
        display as text %15s "1%" as result %15.3f `p1'
        display as text %15s "5%" as result %15.3f `p5'
        display as text %15s "10%" as result %15.3f `p10'
        display as text %15s "25%" as result %15.3f `p25'
        display as text %15s "50% (median)" as result %15.3f `p50'
        display as text %15s "75%" as result %15.3f `p75'
        display as text %15s "90%" as result %15.3f `p90'
        display as text %15s "95%" as result %15.3f `p95'
        display as text %15s "99%" as result %15.3f `p99'
        display as text "{hline 50}"
        display ""
    }

    * Effective sample size
    display as text "{hline `tbl_width'}"
    display as text "Effective Sample Size (ESS)"
    display as text "{hline `tbl_width'}"

    display as text %25s "" %15s "Overall" _c
    foreach lev of local levels {
        display as text %15s "`lbl_`lev''" _c
    }
    display ""
    display as text "{hline `tbl_width'}"

    display as text %25s "ESS" as result %15.1f `ess' _c
    foreach lev of local levels {
        display as result %15.1f `ess_`lev'' _c
    }
    display ""

    display as text %25s "ESS % of N" as result %14.1f `ess_pct' "%" _c
    foreach lev of local levels {
        display as result %14.1f `ess_pct_`lev'' "%" _c
    }
    display ""
    display as text "{hline `tbl_width'}"
    display ""

    * Extreme weights
    display as text "{hline 50}"
    display as text "Extreme Weight Detection"
    display as text "{hline 50}"
    display as text "Coefficient of Variation: " as result %8.3f `cv'
    display as text "Weights > 10:             " as result %8.0f `n_extreme' ///
        as text " (" as result %5.2f `pct_extreme' as text "%)"
    display as text "Weights > 20:             " as result %8.0f `n_very_extreme'
    display as text "{hline 50}"

    * Warnings
    display ""
    if `ess_pct' < 50 {
        display as error "Warning: ESS is less than 50% of N. Consider trimming weights."
    }
    if `cv' > 1 {
        display as error "Warning: High CV indicates substantial weight variability."
    }
    if `n_extreme' > 0 {
        display as error "Warning: `n_extreme' extreme weights detected (>10)."
    }
    if `max_wt' > 20 {
        display as error "Warning: Maximum weight exceeds 20. Consider truncation."
    }

    * Verdict
    if `ess_pct' < 50 {
        display as text _n "Weights: " as error "WARNING" ///
            as text " (ESS = " as result %4.1f `ess_pct' as text "% of N)"
        display as text "  Consider: {cmd:psdash weights, trim(99) generate(w_trim)} or {cmd:psdash weights, truncate(#) generate(w_trunc)}"
    }
    else {
        display as text _n "Weights: " as result "Acceptable" ///
            as text " (ESS = " as result %4.1f `ess_pct' as text "% of N)"
    }

    * =====================================================================
    * WEIGHT TRIMMING/STABILIZATION (multi-group)
    * =====================================================================
    if `trim' != 0 | `truncate' != 0 | "`stabilize'" != "" {
        quietly {
            if "`replace'" != "" {
                capture drop `generate'
            }

            if `trim' != 0 {
                _pctile `wvar' if `touse', p(`trim')
                local trim_val = r(r1)
                gen double `generate' = min(`wvar', `trim_val') if `touse'
                label variable `generate' "`wvar_label' trimmed at p`trim'"
                local action "Trimmed at p`trim' (cutoff: `=string(`trim_val', "%6.3f")')"
            }
            else if `truncate' != 0 {
                gen double `generate' = min(`wvar', `truncate') if `touse'
                label variable `generate' "`wvar_label' truncated at `truncate'"
                local action "Truncated at `truncate'"
            }
            else if "`stabilize'" != "" {
                * Multi-group stabilization: multiply by P(A=a) for each group
                gen double `generate' = . if `touse'
                foreach lev of local levels {
                    count if `treatment' == `lev' & `touse'
                    local p_`lev' = r(N) / `N'
                    replace `generate' = `p_`lev'' * `wvar' ///
                        if `treatment' == `lev' & `touse'
                }
                label variable `generate' "`wvar_label' stabilized"

                * Build action string
                local action "Stabilized ("
                local first = 1
                foreach lev of local levels {
                    if `first' {
                        local action "`action'P(A=`lev') = `=string(`p_`lev'', "%6.3f")'"
                        local first = 0
                    }
                    else {
                        local action "`action', P(A=`lev') = `=string(`p_`lev'', "%6.3f")'"
                    }
                }
                local action "`action')"
            }

            * Report new weight statistics
            summarize `generate' if `touse', detail
            local new_mean = r(mean)
            local new_sd = r(sd)
            local new_min = r(min)
            local new_max = r(max)
            local new_cv = `new_sd' / `new_mean'

            * New ESS
            tempvar new_wt_sq
            gen double `new_wt_sq' = `generate'^2 if `touse'
            summarize `generate' if `touse'
            local new_sum_wt = r(sum)
            summarize `new_wt_sq' if `touse'
            local new_sum_wt_sq = r(sum)
            local new_ess = (`new_sum_wt'^2) / `new_sum_wt_sq'
            local new_ess_pct = 100 * `new_ess' / `N'
            drop `new_wt_sq'
        }

        display ""
        display as text "{hline 70}"
        display as text "Modified Weight Statistics: `generate'"
        display as text "`action'"
        display as text "{hline 70}"
        display as text %25s "Statistic" %15s "Original" %15s "Modified"
        display as text "{hline 70}"
        display as text %25s "Mean" ///
            as result %15.3f `mean_wt' %15.3f `new_mean'
        display as text %25s "SD" ///
            as result %15.3f `sd_wt' %15.3f `new_sd'
        display as text %25s "Max" ///
            as result %15.3f `max_wt' %15.3f `new_max'
        display as text %25s "CV" ///
            as result %15.3f `cv' %15.3f `new_cv'
        display as text %25s "ESS" ///
            as result %15.1f `ess' %15.1f `new_ess'
        display as text %25s "ESS % of N" ///
            as result %14.1f `ess_pct' "%" %14.1f `new_ess_pct' "%"
        display as text "{hline 70}"

        return scalar new_mean = `new_mean'
        return scalar new_sd = `new_sd'
        return scalar new_min = `new_min'
        return scalar new_max = `new_max'
        return scalar new_cv = `new_cv'
        return scalar new_ess = `new_ess'
        return scalar new_ess_pct = `new_ess_pct'
        return local generate "`generate'"
    }

    * =====================================================================
    * RETURN RESULTS (multi-group)
    * =====================================================================
    return scalar N = `N'
    return scalar K = `K'
    foreach lev of local levels {
        return scalar N_group_`lev' = `n_group_`lev''
        return scalar ess_group_`lev' = `ess_`lev''
        return scalar ess_pct_group_`lev' = `ess_pct_`lev''
    }
    return scalar mean_wt = `mean_wt'
    return scalar sd_wt = `sd_wt'
    return scalar min_wt = `min_wt'
    return scalar max_wt = `max_wt'
    return scalar cv = `cv'
    return scalar ess = `ess'
    return scalar ess_pct = `ess_pct'
    return scalar n_extreme = `n_extreme'
    return scalar pct_extreme = `pct_extreme'
    return scalar p1 = `p1'
    return scalar p5 = `p5'
    return scalar p95 = `p95'
    return scalar p99 = `p99'
    return local treatment "`treatment'"
    return local estimand "`estimand'"
    return local levels "`levels'"
    return local reference "`mg_reference'"
    if "`wvar_auto'" == "1" {
        return local wvar "auto-generated"
    }
    else {
        return local wvar "`wvar'"
    }

    * =====================================================================
    * WEIGHT DISTRIBUTION GRAPH (multi-group)
    * =====================================================================
    if "`graph'" == "" {
        if "`saving'" != "" {
            display as text "note: saving() ignored without graph option"
        }
        if "`xlabel'" != "" {
            display as text "note: xlabel() ignored without graph option"
        }
    }

    if "`graph'" != "" {
        capture noisily {
            quietly {
                if "`xlabel'" == "" {
                    local xlabel "0 2 5 10 15 20"
                }

                local scheme_opt ""
                if "`scheme'" != "" {
                    local scheme_opt "scheme(`scheme')"
                }

                local bw = (`max_wt' - `min_wt') / min(20, ceil(sqrt(`N')))
                if `bw' <= 0 {
                    local bw = 1
                }

                * Build overlaid histograms for K groups
                local color_list "navy cranberry forest_green dkorange purple teal maroon olive"
                local plot_cmd ""
                local legend_order ""
                local gnum = 0
                foreach lev of local levels {
                    local gnum = `gnum' + 1
                    local col : word `gnum' of `color_list'
                    local lab "`lbl_`lev''"
                    local plot_cmd `"`plot_cmd' (histogram `wvar' if `touse' & `treatment' == `lev', frequency fcolor(`col'%50) lcolor(`col') width(`bw'))"'
                    local legend_order `"`legend_order' `gnum' "`lab'""'
                }

                noisily twoway `plot_cmd', ///
                    legend(order(`legend_order') rows(1) position(6)) ///
                    xtitle("IPTW Weight") ytitle("Frequency") ///
                    title("IPTW Weight Distribution (Multi-Group)") ///
                    xlabel(`xlabel') ///
                    xline(1, lcolor(gs8) lpattern(dash)) ///
                    name(`name', replace) ///
                    `scheme_opt' `graphoptions'

                if "`saving'" != "" {
                    noisily graph export "`saving'", replace
                }
            }
        }
        local graph_rc = _rc
        if `graph_rc' {
            return clear
            if "`generate'" != "" {
                return scalar new_mean = `new_mean'
                return scalar new_sd = `new_sd'
                return scalar new_min = `new_min'
                return scalar new_max = `new_max'
                return scalar new_cv = `new_cv'
                return scalar new_ess = `new_ess'
                return scalar new_ess_pct = `new_ess_pct'
                return local generate "`generate'"
            }
            return scalar N = `N'
            return scalar K = `K'
            foreach lev of local levels {
                return scalar N_group_`lev' = `n_group_`lev''
                return scalar ess_group_`lev' = `ess_`lev''
                return scalar ess_pct_group_`lev' = `ess_pct_`lev''
            }
            return scalar mean_wt = `mean_wt'
            return scalar sd_wt = `sd_wt'
            return scalar min_wt = `min_wt'
            return scalar max_wt = `max_wt'
            return scalar cv = `cv'
            return scalar ess = `ess'
            return scalar ess_pct = `ess_pct'
            return scalar n_extreme = `n_extreme'
            return scalar pct_extreme = `pct_extreme'
            return scalar p1 = `p1'
            return scalar p5 = `p5'
            return scalar p95 = `p95'
            return scalar p99 = `p99'
            return local treatment "`treatment'"
            return local estimand "`estimand'"
            return local levels "`levels'"
            return local reference "`mg_reference'"
            if "`wvar_auto'" == "1" {
                return local wvar "auto-generated"
            }
            else {
                return local wvar "`wvar'"
            }
            exit `graph_rc'
        }
    }

    } // end multi-group path

    }
    local rc = _rc
    set varabbrev `_vao'
    if `rc' exit `rc'

end
