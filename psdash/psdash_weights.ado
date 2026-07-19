*! psdash_weights Version 1.4.1  2026/07/07
*! IPTW weight diagnostics - distribution, ESS, extreme weights, trimming
*! Author: Timothy P Copeland, Karolinska Institutet
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
    local _psdash_side_rc = 0
    local _psdash_return_mode ""

    capture noisily {

    * SYNTAX PARSING
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
         xlsx(string) ///
         sheet(string) ///
         ESTImand(string) ///
         EXTreme(numlist min=2 max=2 >0 ascending) ///
         PSVars(varlist numeric) ///
         IIVWComponent(string)]

    if "`xlsx'" != "" {
        _psdash_validate_path, path(`"`xlsx'"') option(xlsx) extension(xlsx)
    }
    if "`sheet'" == "" local sheet "Weights"

    * Extreme-weight thresholds (absolute scale). Defaults suit stabilized weights;
    * for unstabilized ATE weights set extreme() to larger cutoffs.
    local exthi 10
    local extvhi 20
    if "`extreme'" != "" {
        gettoken exthi extvhi : extreme
        local extvhi = strtrim("`extvhi'")
    }

    if "`iivwcomponent'" != "" {
        local iivwcomponent = strlower("`iivwcomponent'")
        if !inlist("`iivwcomponent'", "treatment", "final", "visit") {
            display as error "iivwcomponent() must be treatment, final, or visit"
            exit 198
        }
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
    * For weights, user may provide treatment + wvar without a PS variable.
    * The detect helper requires psvar for manual mode, so handle the
    * treatment-only + wvar case ourselves before falling through to detect.
    local _manual_mg = 0
    local _n_pos_args : word count `anything'
    local _has_est_ctx = inlist("`e(cmd)'", "logit", "probit", "logistic", "mlogit", "teffects")
    if `_n_pos_args' == 1 & "`wvar'" != "" & !`_has_est_ctx' {
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

    local iivw_component "`_psd_iivw_component'"
    local iivw_treatment_wvar "`_psd_iivw_treatment_wvar'"
    local iivw_final_wvar "`_psd_iivw_final_wvar'"
    local iivw_visit_wvar "`_psd_iivw_visit_wvar'"

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

    if "`source'" == "iivw" & "`iivw_component'" == "" {
        local iivw_component "treatment"
    }

    if "`iivwcomponent'" != "" {
        local iivw_weighted : char _dta[_iivw_weighted]
        if "`iivw_weighted'" != "1" {
            display as error "iivwcomponent() requires current iivw_weight metadata"
            display as error "  rerun iivw_weight, or specify wvar() directly"
            exit 198
        }
        if "`iivw_treatment_wvar'" == "" {
            local iivw_treatment_wvar : char _dta[_iivw_tw_var]
        }
        if "`iivw_final_wvar'" == "" {
            local iivw_final_wvar : char _dta[_iivw_weight_var]
        }
        if "`iivw_visit_wvar'" == "" {
            local iivw_visit_wvar : char _dta[_iivw_iw_var]
        }

        if "`iivwcomponent'" == "treatment" {
            local iivw_selected_wvar "`iivw_treatment_wvar'"
            local iivw_component "treatment"
        }
        else if "`iivwcomponent'" == "final" {
            local iivw_selected_wvar "`iivw_final_wvar'"
            local iivw_component "final"
        }
        else if "`iivwcomponent'" == "visit" {
            local iivw_selected_wvar "`iivw_visit_wvar'"
            local iivw_component "visit"
        }

        if "`iivw_selected_wvar'" == "" {
            display as error "iivwcomponent(`iivwcomponent') is unavailable in the current iivw metadata"
            if "`iivwcomponent'" == "visit" {
                display as error "  visit weights are available after IIW/FIPTIW, not IPTW-only"
            }
            else if "`iivwcomponent'" == "treatment" {
                display as error "  treatment weights require iivw_weight with treat() and treat_cov()"
            }
            exit 198
        }
        confirm variable `iivw_selected_wvar'
        confirm numeric variable `iivw_selected_wvar'
        local wvar "`iivw_selected_wvar'"
        local wvar_auto "0"
    }

    * Track all multigroup PS inputs so output-name guards can protect them.
    local mg_psvars_all ""
    if "`multigroup'" != "0" {
        local _mg_det_psvars ""
        foreach lev of local levels {
            local this_ps "`_psd_ps_`lev''"
            if "`this_ps'" != "" {
                local _mg_det_psvars "`_mg_det_psvars' `this_ps'"
            }
        }
        local _mg_det_opt ""
        if "`_mg_det_psvars'" != "" {
            local _mg_det_opt "detpsvars(`_mg_det_psvars')"
        }
        local _mg_psvar_opt ""
        if "`psvar'" != "" {
            local _mg_psvar_opt "psvar(`psvar')"
        }
        _psdash_mgps_map, multigroup(`multigroup') k(`K') levels(`levels') ///
            treatment(`treatment') samplevar(`touse') `_mg_psvar_opt' ///
            `_mg_det_opt' allowempty
        local mg_psvars_all "`r(mg_psvars_all)'"
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
        _psdash_pscheck `psvar' if `touse'
        local n_ps_boundary = r(n_ps_boundary)
        local n_ps_near = r(n_ps_near)
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

    * BRANCH: BINARY vs MULTI-GROUP
    if "`multigroup'" == "0" {
    * BINARY PATH (unchanged from v1.1.9)

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
    local source_label "`source'"
    local component_label ""
    local weight_xtitle "IPTW Weight"
    local graph_title "IPTW Weight Distribution"
    if "`source'" == "iivw" | "`iivwcomponent'" != "" {
        local iivw_wtype : char _dta[_iivw_weighttype]
        local iivw_wtype = strupper("`iivw_wtype'")
        if "`iivw_component'" == "" local iivw_component "treatment"
        if "`iivw_component'" == "treatment" {
            local source_label "iivw treatment model"
            local component_label "treatment IPTW (`wvar')"
        }
        else if "`iivw_component'" == "final" {
            local source_label "iivw final analysis weight"
            local component_label "final `iivw_wtype' (`wvar')"
            local weight_xtitle "Final analysis weight"
            local graph_title "Final Analysis Weight Distribution"
        }
        else if "`iivw_component'" == "visit" {
            local source_label "iivw visit-intensity model"
            local component_label "visit-intensity IIW (`wvar')"
            local weight_xtitle "Visit-intensity weight"
            local graph_title "Visit-Intensity Weight Distribution"
            display as text "note: iivwcomponent(visit) is descriptive only; PS overlap/support do not apply"
        }
    }

    * CALCULATE WEIGHT STATISTICS (binary)
    _psdash_weights_stats, wvar(`wvar') treatment(`treatment') ///
        samplevar(`touse') n(`N') exthi(`exthi') extvhi(`extvhi')
    local mean_wt = r(mean_wt)
    local sd_wt = r(sd_wt)
    local min_wt = r(min_wt)
    local max_wt = r(max_wt)
    local p1 = r(p1)
    local p5 = r(p5)
    local p10 = r(p10)
    local p25 = r(p25)
    local p50 = r(p50)
    local p75 = r(p75)
    local p90 = r(p90)
    local p95 = r(p95)
    local p99 = r(p99)
    local cv = r(cv)
    local n_treated = r(n_treated)
    local n_control = r(n_control)
    local mean_wt_t = r(mean_wt_t)
    local sd_wt_t = r(sd_wt_t)
    local min_wt_t = r(min_wt_t)
    local max_wt_t = r(max_wt_t)
    local mean_wt_c = r(mean_wt_c)
    local sd_wt_c = r(sd_wt_c)
    local min_wt_c = r(min_wt_c)
    local max_wt_c = r(max_wt_c)
    local ess = r(ess)
    local ess_pct = r(ess_pct)
    local ess_t = r(ess_t)
    local ess_pct_t = r(ess_pct_t)
    local ess_c = r(ess_c)
    local ess_pct_c = r(ess_pct_c)
    local n_extreme = r(n_extreme)
    local pct_extreme = r(pct_extreme)
    local n_very_extreme = r(n_very_extreme)
    local max_ratio = r(max_ratio)

    * DISPLAY OUTPUT (binary)
    display as text _n "IPTW Weight Diagnostics"
    local wvar_label "`wvar'"
    if "`wvar_auto'" == "1" local wvar_label "auto-generated"
    display as text "Weight variable:   " as result "`wvar_label'"
    if "`component_label'" != "" {
        display as text "Weight component:  " as result "`component_label'"
    }
    display as text "Treatment:         " as result "`treatment'"
    display as text "Observations:      " as result %10.0fc `N'
    if "`source'" != "manual" | "`iivwcomponent'" != "" {
        display as text "Source:            " as result "`source_label'"
    }
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
    local _eh = string(`exthi')
    local _evh = string(`extvhi')
    display as text "Coefficient of Variation: " as result %8.3f `cv'
    display as text "Max / mean weight ratio:  " as result %8.2f `max_ratio'
    display as text "Weights > `_eh':             " as result %8.0f `n_extreme' ///
        as text " (" as result %5.2f `pct_extreme' as text "%)"
    display as text "Weights > `_evh':             " as result %8.0f `n_very_extreme'
    display as text "{hline 50}"

    * Warnings (RB-01: every warning-worthy condition becomes a machine-readable
    * finding; ANY finding forces a non-Acceptable verdict and enters r(warnings).)
    display ""
    local _pf ""
    local _pfn = 0
    if `ess_pct' < 50 {
        display as error "Warning: ESS is less than 50% of N. Consider trimming weights."
        local _pf `"`_pf' | overall ESS `=string(`ess_pct',"%4.1f")'% < 50%"'
        local ++_pfn
    }
    * Per-arm ESS collapse: an aggregate ESS can mask one destroyed arm (B5).
    local _min_arm_ess = min(`ess_pct_t', `ess_pct_c')
    if `_min_arm_ess' < 50 & `_min_arm_ess' < . {
        display as error "Warning: minimum per-arm ESS is `=string(`_min_arm_ess',"%4.1f")'% of N (arm collapse)."
        local _pf `"`_pf' | min per-arm ESS `=string(`_min_arm_ess',"%4.1f")'% < 50%"'
        local ++_pfn
    }
    if `cv' > 1 {
        display as error "Warning: High CV indicates substantial weight variability."
        local _pf `"`_pf' | weight CV `=string(`cv',"%5.2f")' > 1"'
        local ++_pfn
    }
    if `n_extreme' > 0 {
        display as error "Warning: `n_extreme' extreme weights detected (>`_eh')."
        local _pf `"`_pf' | `n_extreme' extreme weights > `_eh'"'
        local ++_pfn
    }
    if `max_wt' > `extvhi' {
        display as error "Warning: Maximum weight exceeds `_evh'. Consider truncation."
        local _pf `"`_pf' | max weight `=string(`max_wt',"%6.2f")' > `_evh'"'
        local ++_pfn
    }
    * Exact PS-boundary observations yield undefined weights and are silently
    * dropped from this panel's N (B6); surface them as a finding.
    if "`n_ps_boundary'" != "" {
        if `n_ps_boundary' > 0 {
            display as error "Warning: `n_ps_boundary' observation(s) at an exact PS boundary have undefined weights."
            local _pf `"`_pf' | `n_ps_boundary' exact-PS-boundary obs (undefined weight)"'
            local ++_pfn
        }
    }
    local _pf = strtrim("`_pf'")
    if substr("`_pf'", 1, 1) == "|" local _pf = strtrim(substr("`_pf'", 2, .))
    local _weights_findings `"`_pf'"'
    local _weights_nfind = `_pfn'

    * Verdict (WARNING on ANY finding, not ESS alone)
    if `_pfn' > 0 {
        display as text _n "Weights: " as error "WARNING" ///
            as text " (ESS = " as result %4.1f `ess_pct' as text "% of N; " ///
            as result `_pfn' as text " finding(s))"
        display as text "  Consider: {cmd:psdash weights, trim(99) generate(w_trim)} or {cmd:psdash weights, truncate(#) generate(w_trunc)}"
    }
    else {
        display as text _n "Weights: " as result "Acceptable" ///
            as text " (ESS = " as result %4.1f `ess_pct' as text "% of N)"
    }

    * WEIGHT TRIMMING/STABILIZATION (binary)
    if "`generate'" != "" & `trim' == 0 & `truncate' == 0 & "`stabilize'" == "" {
        display as error "generate() requires trim(), truncate(), or stabilize"
        exit 198
    }

    if "`stabilize'" != "" & "`wvar_auto'" != "1" {
        display as text "Note: stabilize multiplies the supplied weights by the marginal P(treatment);"
        display as text "      this is correct only for unstabilized inverse-probability weights (1/PS scale)."
    }
    if `trim' != 0 | `truncate' != 0 | "`stabilize'" != "" {
        _psdash_weights_modify, wvar(`wvar') treatment(`treatment') ///
            samplevar(`touse') n(`N') generate(`generate') ///
            wvarlabel("`wvar_label'") trim(`trim') truncate(`truncate') ///
            `stabilize' `replace'
        local new_mean = r(new_mean)
        local new_sd = r(new_sd)
        local new_min = r(new_min)
        local new_max = r(new_max)
        local new_cv = r(new_cv)
        local new_ess = r(new_ess)
        local new_ess_pct = r(new_ess_pct)
        local action "`r(action)'"

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

    }

    * WEIGHT DISTRIBUTION GRAPH (binary)
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
                    if `max_wt' <= 1 {
                        local xlabel "0 .25 .5 .75 1"
                    }
                    else if `max_wt' <= 2 {
                        local xlabel "0 .5 1 1.5 2"
                    }
                    else if `max_wt' <= 5 {
                        local xlabel "0 1 2 3 4 5"
                    }
                    else if `max_wt' <= 10 {
                        local xlabel "0 2 4 6 8 10"
                    }
                    else if `max_wt' <= 20 {
                        local xlabel "0 5 10 15 20"
                    }
                    else if `max_wt' <= 50 {
                        local xlabel "0 10 20 30 40 50"
                    }
                    else if `max_wt' <= 100 {
                        local xlabel "0 20 40 60 80 100"
                    }
                    else {
                        local xstep = ceil(`max_wt' / 5)
                        local xupper = `xstep' * 5
                        local xlabel "0(`xstep')`xupper'"
                    }
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
                       xtitle("`weight_xtitle'") ytitle("Frequency") ///
                       title("`graph_title'") ///
                       xlabel(`xlabel') ///
                       xline(1, lcolor(gs8) lpattern(dash)) ///
                       name(`name', replace) ///
                       `scheme_opt' `graphoptions'

                if "`saving'" != "" {
                    _psdash_graph_export, saving("`saving'")
                }
            }
        }
        local graph_rc = _rc
        if `graph_rc' {
            local _psdash_side_rc = `graph_rc'
        }
    }

    * EXPORT TO EXCEL (binary, O1)
    if "`xlsx'" != "" & `_psdash_side_rc' == 0 {
        capture noisily {
            local _xk `""Treatment" "Total N" "N (treated)" "N (control)" "Mean weight" "SD weight" "Min weight" "Max weight" "CV" "ESS" "ESS % of N" "ESS % (treated)" "ESS % (control)" "Weights > extreme (N)" "Weights > extreme (%)" "Weights > very-extreme (N)" "p1" "p5" "p95""'
            local _xv `""`treatment'" "`N'" "`n_treated'" "`n_control'" "`=string(`mean_wt',"%8.4f")'" "`=string(`sd_wt',"%8.4f")'" "`=string(`min_wt',"%8.4f")'" "`=string(`max_wt',"%8.4f")'" "`=string(`cv',"%6.3f")'" "`=string(`ess',"%8.1f")'" "`=string(`ess_pct',"%5.1f")'" "`=string(`ess_pct_t',"%5.1f")'" "`=string(`ess_pct_c',"%5.1f")'" "`n_extreme'" "`=string(`pct_extreme',"%5.2f")'" "`n_very_extreme'" "`=string(`p1',"%8.4f")'" "`=string(`p5',"%8.4f")'" "`=string(`p95',"%8.4f")'""'
            _psdash_export_kv, xlsx("`xlsx'") sheet("`sheet'") ///
                title("Weight Diagnostics") keys(`_xk') vals(`_xv')
            noisily display as text _n "Weights table exported to: " as result "`xlsx'"
        }
        local xlsx_rc = _rc
        if `xlsx_rc' local _psdash_side_rc = `xlsx_rc'
    }

    local _psdash_return_mode "binary"

    } // end binary path
    else {
    * MULTI-GROUP PATH (K >= 2 non-binary treatment)

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
    local source_label "`source'"
    local component_label ""
    local weight_xtitle "IPTW Weight"
    local graph_title "IPTW Weight Distribution (Multi-Group)"
    if "`source'" == "iivw" | "`iivwcomponent'" != "" {
        local iivw_wtype : char _dta[_iivw_weighttype]
        local iivw_wtype = strupper("`iivw_wtype'")
        if "`iivw_component'" == "" local iivw_component "treatment"
        if "`iivw_component'" == "treatment" {
            local source_label "iivw treatment model"
            local component_label "treatment IPTW (`wvar')"
        }
        else if "`iivw_component'" == "final" {
            local source_label "iivw final analysis weight"
            local component_label "final `iivw_wtype' (`wvar')"
            local weight_xtitle "Final analysis weight"
            local graph_title "Final Analysis Weight Distribution"
        }
        else if "`iivw_component'" == "visit" {
            local source_label "iivw visit-intensity model"
            local component_label "visit-intensity IIW (`wvar')"
            local weight_xtitle "Visit-intensity weight"
            local graph_title "Visit-Intensity Weight Distribution"
        }
    }

    * CALCULATE WEIGHT STATISTICS (multi-group)
    _psdash_weights_stats, wvar(`wvar') treatment(`treatment') ///
        samplevar(`touse') n(`N') levels(`levels') multigroup(`multigroup') ///
        exthi(`exthi') extvhi(`extvhi')
    local mean_wt = r(mean_wt)
    local sd_wt = r(sd_wt)
    local min_wt = r(min_wt)
    local max_wt = r(max_wt)
    local p1 = r(p1)
    local p5 = r(p5)
    local p10 = r(p10)
    local p25 = r(p25)
    local p50 = r(p50)
    local p75 = r(p75)
    local p90 = r(p90)
    local p95 = r(p95)
    local p99 = r(p99)
    local cv = r(cv)
    local ess = r(ess)
    local ess_pct = r(ess_pct)
    local n_extreme = r(n_extreme)
    local pct_extreme = r(pct_extreme)
    local n_very_extreme = r(n_very_extreme)
    local max_ratio = r(max_ratio)
    foreach lev of local levels {
        local n_group_`lev' = r(n_group_`lev')
        local mean_wt_`lev' = r(mean_wt_`lev')
        local sd_wt_`lev' = r(sd_wt_`lev')
        local min_wt_`lev' = r(min_wt_`lev')
        local max_wt_`lev' = r(max_wt_`lev')
        local ess_`lev' = r(ess_`lev')
        local ess_pct_`lev' = r(ess_pct_`lev')
    }

    * DISPLAY (multi-group)
    display as text _n "IPTW Weight Diagnostics (Multi-Group)"
    local wvar_label "`wvar'"
    if "`wvar_auto'" == "1" local wvar_label "auto-generated"
    display as text "Weight variable:   " as result "`wvar_label'"
    if "`component_label'" != "" {
        display as text "Weight component:  " as result "`component_label'"
    }
    display as text "Treatment:         " as result "`treatment'" as text " (`K' groups, ref = `mg_reference')"
    display as text "Observations:      " as result %10.0fc `N'
    if "`source'" != "manual" | "`iivwcomponent'" != "" {
        display as text "Source:            " as result "`source_label'"
    }
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
    local _eh = string(`exthi')
    local _evh = string(`extvhi')
    display as text "Coefficient of Variation: " as result %8.3f `cv'
    display as text "Max / mean weight ratio:  " as result %8.2f `max_ratio'
    display as text "Weights > `_eh':             " as result %8.0f `n_extreme' ///
        as text " (" as result %5.2f `pct_extreme' as text "%)"
    display as text "Weights > `_evh':             " as result %8.0f `n_very_extreme'
    display as text "{hline 50}"

    * Warnings (RB-01: propagate every printed warning into a machine-readable
    * finding list; ANY finding forces a non-Acceptable verdict + r(warnings).)
    display ""
    local _pf ""
    local _pfn = 0
    if `ess_pct' < 50 {
        display as error "Warning: ESS is less than 50% of N. Consider trimming weights."
        local _pf `"`_pf' | overall ESS `=string(`ess_pct',"%4.1f")'% < 50%"'
        local ++_pfn
    }
    if `cv' > 1 {
        display as error "Warning: High CV indicates substantial weight variability."
        local _pf `"`_pf' | weight CV `=string(`cv',"%5.2f")' > 1"'
        local ++_pfn
    }
    if `n_extreme' > 0 {
        display as error "Warning: `n_extreme' extreme weights detected (>`_eh')."
        local _pf `"`_pf' | `n_extreme' extreme weights > `_eh'"'
        local ++_pfn
    }
    if `max_wt' > `extvhi' {
        display as error "Warning: Maximum weight exceeds `_evh'. Consider truncation."
        local _pf `"`_pf' | max weight `=string(`max_wt',"%6.2f")' > `_evh'"'
        local ++_pfn
    }
    local _pf = strtrim("`_pf'")
    if substr("`_pf'", 1, 1) == "|" local _pf = strtrim(substr("`_pf'", 2, .))
    local _weights_findings `"`_pf'"'
    local _weights_nfind = `_pfn'

    * Verdict (WARNING on ANY finding, not ESS alone)
    if `_pfn' > 0 {
        display as text _n "Weights: " as error "WARNING" ///
            as text " (ESS = " as result %4.1f `ess_pct' as text "% of N; " ///
            as result `_pfn' as text " finding(s))"
        display as text "  Consider: {cmd:psdash weights, trim(99) generate(w_trim)} or {cmd:psdash weights, truncate(#) generate(w_trunc)}"
    }
    else {
        display as text _n "Weights: " as result "Acceptable" ///
            as text " (ESS = " as result %4.1f `ess_pct' as text "% of N)"
    }

    * WEIGHT TRIMMING/STABILIZATION (multi-group)
    if "`stabilize'" != "" & "`wvar_auto'" != "1" {
        display as text "Note: stabilize multiplies the supplied weights by the marginal P(A=a);"
        display as text "      this is correct only for unstabilized inverse-probability weights (1/GPS scale)."
    }
    if `trim' != 0 | `truncate' != 0 | "`stabilize'" != "" {
        _psdash_weights_modify, wvar(`wvar') treatment(`treatment') ///
            samplevar(`touse') n(`N') generate(`generate') ///
            wvarlabel("`wvar_label'") trim(`trim') truncate(`truncate') ///
            `stabilize' `replace' levels(`levels') multigroup(`multigroup')
        local new_mean = r(new_mean)
        local new_sd = r(new_sd)
        local new_min = r(new_min)
        local new_max = r(new_max)
        local new_cv = r(new_cv)
        local new_ess = r(new_ess)
        local new_ess_pct = r(new_ess_pct)
        local action "`r(action)'"

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

    }

    * WEIGHT DISTRIBUTION GRAPH (multi-group)
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
                    if `max_wt' <= 1 {
                        local xlabel "0 .25 .5 .75 1"
                    }
                    else if `max_wt' <= 2 {
                        local xlabel "0 .5 1 1.5 2"
                    }
                    else if `max_wt' <= 5 {
                        local xlabel "0 1 2 3 4 5"
                    }
                    else if `max_wt' <= 10 {
                        local xlabel "0 2 4 6 8 10"
                    }
                    else if `max_wt' <= 20 {
                        local xlabel "0 5 10 15 20"
                    }
                    else if `max_wt' <= 50 {
                        local xlabel "0 10 20 30 40 50"
                    }
                    else if `max_wt' <= 100 {
                        local xlabel "0 20 40 60 80 100"
                    }
                    else {
                        local xstep = ceil(`max_wt' / 5)
                        local xupper = `xstep' * 5
                        local xlabel "0(`xstep')`xupper'"
                    }
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
                    xtitle("`weight_xtitle'") ytitle("Frequency") ///
                    title("`graph_title'") ///
                    xlabel(`xlabel') ///
                    xline(1, lcolor(gs8) lpattern(dash)) ///
                    name(`name', replace) ///
                    `scheme_opt' `graphoptions'

                if "`saving'" != "" {
                    _psdash_graph_export, saving("`saving'")
                }
            }
        }
        local graph_rc = _rc
        if `graph_rc' {
            local _psdash_side_rc = `graph_rc'
        }
    }

    * EXPORT TO EXCEL (multi-group, O1)
    if "`xlsx'" != "" & `_psdash_side_rc' == 0 {
        capture noisily {
            local _xk `""Treatment" "Groups (K)" "Total N" "Mean weight" "SD weight" "Min weight" "Max weight" "CV" "ESS" "ESS % of N""'
            local _xv `""`treatment'" "`K'" "`N'" "`=string(`mean_wt',"%8.4f")'" "`=string(`sd_wt',"%8.4f")'" "`=string(`min_wt',"%8.4f")'" "`=string(`max_wt',"%8.4f")'" "`=string(`cv',"%6.3f")'" "`=string(`ess',"%8.1f")'" "`=string(`ess_pct',"%5.1f")'""'
            foreach lev of local levels {
                local _xk `"`_xk' "N (group `lev')" "ESS % (group `lev')""'
                local _xv `"`_xv' "`n_group_`lev''" "`=string(`ess_pct_`lev'',"%5.1f")'""'
            }
            local _xk `"`_xk' "Weights > extreme (N)" "Weights > extreme (%)" "Weights > very-extreme (N)""'
            local _xv `"`_xv' "`n_extreme'" "`=string(`pct_extreme',"%5.2f")'" "`n_very_extreme'""'
            _psdash_export_kv, xlsx("`xlsx'") sheet("`sheet'") ///
                title("Weight Diagnostics (Multi-Group)") keys(`_xk') vals(`_xv')
            noisily display as text _n "Weights table exported to: " as result "`xlsx'"
        }
        local xlsx_rc = _rc
        if `xlsx_rc' local _psdash_side_rc = `xlsx_rc'
    }

    local _psdash_return_mode "multigroup"

    } // end multi-group path

    }
    local rc = _rc
    set varabbrev `_vao'
    if `rc' == 0 & "`_psdash_return_mode'" != "" {
        if `_psdash_side_rc' {
            local rc = `_psdash_side_rc'
        }
        return clear
        if "`_psdash_return_mode'" == "binary" {
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
            return scalar max_ratio = `max_ratio'
            return scalar extreme_hi = `exthi'
            return scalar extreme_vhi = `extvhi'
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
            return local source "`source'"
            if "`iivw_component'" != "" {
                return local iivwcomponent "`iivw_component'"
            }
        }
        else if "`_psdash_return_mode'" == "multigroup" {
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
            return scalar max_ratio = `max_ratio'
            return scalar extreme_hi = `exthi'
            return scalar extreme_vhi = `extvhi'
            return scalar p1 = `p1'
            return scalar p5 = `p5'
            return scalar p95 = `p95'
            return scalar p99 = `p99'
            return local treatment "`treatment'"
            return local estimand "`estimand'"
            return local source "`source'"
            if "`iivw_component'" != "" {
                return local iivwcomponent "`iivw_component'"
            }
            return local levels "`levels'"
            return local reference "`mg_reference'"
            if "`wvar_auto'" == "1" {
                return local wvar "auto-generated"
            }
            else {
                return local wvar "`wvar'"
            }
        }
        * RB-01 unified findings surface (both modes)
        if "`_weights_nfind'" == "" local _weights_nfind = 0
        return scalar n_warnings = `_weights_nfind'
        return local warnings `"`_weights_findings'"'
    }
    if `rc' exit `rc'

end
