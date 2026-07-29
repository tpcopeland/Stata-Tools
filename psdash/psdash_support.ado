*! psdash_support Version 1.6.1  2026/07/29
*! Common support assessment for propensity score analysis
*! Author: Timothy P Copeland, Karolinska Institutet
*! Program class: rclass

/*
DESCRIPTION:
    Assesses the common support (positivity) region for propensity score
    analysis. Identifies observations outside common support, implements
    Crump et al. (2009) optimal trimming, and generates support indicator
    variables.

    Supports binary (0/1) and multi-group (K >= 2) treatment.

SYNTAX:
    psdash support [treatment] [psvar] [if] [in] [, options]

Options:
    covariates(varlist) - Covariates (for auto-detection context)
    crump               - Apply Crump et al. (2009) optimal trimming (binary only)
    threshold(real)     - Manual PS trimming threshold (trim if ps<t or ps>1-t)
    generate(name)      - Generate indicator variable (1=in support, 0=outside)
    replace             - Allow replacing existing variable
    nograph             - Suppress graph
    saving(string)      - Save graph to file
    scheme(string)      - Graph scheme
    graphoptions(string)- Additional graph options
    title(string)       - Title
    name(string)        - Graph name (default: psdash_support)
    reference(string)   - Reference group for multi-group treatment

STORED RESULTS (binary):
    r(N)                    - Total observations
    r(N_treated)            - Treated observations
    r(N_control)            - Control observations
    r(lower_bound)          - Lower bound of common support
    r(upper_bound)          - Upper bound of common support
    r(n_outside)            - Observations outside support
    r(pct_outside)          - Percentage outside support
    r(n_outside_treated)    - Treated outside support
    r(n_outside_control)    - Control outside support
    r(trim_lower)           - Trimming lower bound (if threshold/crump)
    r(trim_upper)           - Trimming upper bound (if threshold/crump)
    r(n_trimmed)            - Observations trimmed (if threshold/crump)
    r(pct_trimmed)          - Percentage trimmed (if threshold/crump)
    r(crump_alpha)          - Crump optimal alpha (if crump)
    r(treatment)            - Treatment variable name
    r(psvar)                - PS variable name

STORED RESULTS (multi-group):
    r(N)                    - Total observations
    r(K)                    - Number of treatment groups
    r(N_group_<lev>)        - Per-group observation count
    r(lower_bound)          - Lower bound of observed-arm PS overlap
    r(upper_bound)          - Upper bound of observed-arm PS overlap
    r(n_outside)            - Total observations outside observed-arm overlap
    r(pct_outside)          - Percentage outside observed-arm overlap
    r(n_outside_group_<lev>)- Per-group outside counts
    r(min_gps)              - Smallest min_j e_j(X) over all units
    r(min_gps_group_<lev>)  - Smallest e_<lev>(X) over all units
    r(n_gps_violate)        - Units with min_j e_j(X) < gpsfloor()
    r(pct_gps_violate)      - Percentage of units below the GPS floor
    r(gps_floor)            - GPS positivity floor used
    r(trim_lower)           - Trimming floor on every GPS component (if threshold)
    r(n_trimmed)            - Observations trimmed (if threshold)
    r(pct_trimmed)          - Percentage trimmed (if threshold)
    r(treatment)            - Treatment variable name
    r(levels)               - Space-separated treatment levels
    r(reference)            - Reference group level
*/

program define psdash_support, rclass
    version 16.0
    local _vao = c(varabbrev)
    set varabbrev off
    local _psdash_side_rc = 0
    local _psdash_return_mode ""

    capture noisily {

    * SYNTAX PARSING
    syntax [anything] [if] [in], ///
        [COVariates(varlist numeric) ///
         CRUMP ///
         THReshold(real -1) ///
         QTRIM(real -1) ///
         GPSFLOOR(real 0.01) ///
         GENerate(name) ///
         replace ///
         COMPare ///
         NOGraph ///
         SAVing(string) ///
         SCHeme(string) ///
         GRAPHOPTions(string asis) ///
         TItle(string) ///
         name(string) ///
         xlsx(string) ///
         sheet(string) ///
         ESTImand(string) ///
         REFerence(string) ///
         PSVars(varlist numeric)]

    if "`xlsx'" != "" {
        _psdash_validate_path, path(`"`xlsx'"') option(xlsx) extension(xlsx)
    }
    if "`sheet'" == "" local sheet "Support"

    * Validate qtrim() (quantile-based common-support bounds; binary only)
    if `qtrim' != -1 {
        if `qtrim' <= 0 | `qtrim' >= 50 {
            display as error "qtrim() must be strictly between 0 and 50"
            exit 198
        }
    }

    * Validate gpsfloor() (multi-arm practical positivity floor on min_j e_j(X))
    if `gpsfloor' <= 0 | `gpsfloor' >= 1 {
        display as error "gpsfloor() must be strictly between 0 and 1"
        exit 198
    }

    * MARK SAMPLE AND AUTO-DETECT
    tempvar touse ps_auto
    * Accept twoway-style name(x, replace) / saving(f, replace) gracefully
    _psdash_strip_replace, option(name) value(`"`name'"')
    local name `"`r(value)'"'
    _psdash_strip_replace, option(saving) value(`"`saving'"')
    local saving `"`r(value)'"'

    mark `touse' `if' `in'  // validator-note: mark+markout pattern is equivalent to marksample

    * Pass reference and psvars to detect if specified
    local ref_opt ""
    if "`reference'" != "" {
        local ref_opt "reference(`reference')"
    }
    local psvars_opt ""
    if "`psvars'" != "" {
        local psvars_opt "psvars(`psvars')"
    }

    _psdash_detect `anything' , covariates(`covariates') ///
        samplevar(`touse') estimand(`estimand') psout(`ps_auto') ///
        `ref_opt' `psvars_opt'

    local treatment "`_psd_treatment'"
    local psvar "`_psd_psvar'"
    local psvar_auto "`_psd_psvar_auto'"
    local det_wvar "`_psd_wvar'"
    local source "`_psd_source'"
    * RB-05: estimation-sample exclusion ledger (set by detect for teffects)
    local n_estimation "`_psd_n_estimation'"
    local n_excluded "`_psd_n_excluded'"
    if "`estimand'" == "" local estimand "`_psd_estimand'"
    local psvar_label "`psvar'"
    if "`psvar_auto'" == "1" local psvar_label "auto-generated"

    * Retrieve multi-group info from detect
    local multigroup "`_psd_multigroup'"
    local K = `_psd_K'
    local levels "`_psd_levels'"
    local reference_grp "`_psd_reference'"

    * Build multigroup PS mapping before markout.
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

        tempvar ps_first_level
        _psdash_mgps_map, multigroup(`multigroup') k(`K') levels(`levels') ///
            treatment(`treatment') samplevar(`touse') `_mg_psvar_opt' ///
            `_mg_det_opt' fallbackps(`ps_first_level') markout
        local mg_psvars_all "`r(mg_psvars_all)'"
        foreach lev of local levels {
            local group_ps_`lev' "`r(group_ps_`lev')'"
        }
    }
    else {
        markout `touse' `treatment' `psvar'
    }

    quietly count if `touse'
    if r(N) == 0 {
        display as error "no observations"
        exit 2000
    }
    local N = r(N)

    if "`multigroup'" == "0" {
    * BINARY PATH (unchanged from v1.1.9)

    * VALIDATE INPUTS
    capture assert inlist(`treatment', 0, 1) if `touse'
    if _rc {
        display as error "treatment must be binary (0/1)"
        exit 198
    }

    quietly tab `treatment' if `touse'
    if r(r) != 2 {
        display as error "treatment must have exactly 2 levels"
        exit 198
    }

    * Check minimum group size
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

    * Count boundary/near-boundary scores here; the verdict block below owns
    * display and machine-readable findings.
    _psdash_pscheck `psvar' if `touse', nowarn
    local n_ps_boundary = r(n_ps_boundary)
    local n_ps_near = r(n_ps_near)

    if "`crump'" != "" & `threshold' != -1 {
        display as error "cannot specify both crump and threshold()"
        exit 198
    }

    if `threshold' != -1 {
        if `threshold' <= 0 | `threshold' >= 0.5 {
            display as error "threshold() must be between 0 and 0.5"
            exit 198
        }
    }

    * Validate generate
    if "`generate'" != "" {
        foreach reserved in `treatment' `psvar' `det_wvar' _psdash_ps _psdash_wt {
            if "`generate'" == "`reserved'" {
                display as error "generate() cannot be the same as `reserved'"
                exit 198
            }
        }
        if substr("`generate'", 1, 8) == "_psdash_" {
            display as error "generate() cannot use the reserved _psdash_ prefix"
            exit 198
        }
    }
    if "`generate'" != "" & "`replace'" == "" {
        capture confirm new variable `generate'
        if _rc {
            display as error "variable `generate' already exists; use replace option"
            exit 110
        }
    }

    * Set defaults
    if "`title'" == "" local title "Common Support Assessment"
    if "`name'" == "" local name "psdash_support"

    * COMMON SUPPORT ANALYSIS
    _psdash_support_stats, treatment(`treatment') samplevar(`touse') ///
        psvar(`psvar') n(`N') qtrim(`qtrim')
    local n_treated = r(n_treated)
    local n_control = r(n_control)
    local min_ps_t = r(min_ps_t)
    local min_ps_c = r(min_ps_c)
    local max_ps_t = r(max_ps_t)
    local max_ps_c = r(max_ps_c)
    local lower_bound = r(lower_bound)
    local upper_bound = r(upper_bound)
    local n_outside = r(n_outside)
    local pct_outside = r(pct_outside)
    local n_outside_t = r(n_outside_t)
    local n_outside_c = r(n_outside_c)

    * CRUMP OPTIMAL TRIMMING
    local trim_lower = 0
    local trim_upper = 1
    local n_trimmed = 0
    local pct_trimmed = 0
    local crump_alpha = 0
    local has_trimming = 0

    if "`crump'" != "" {
        local has_trimming = 1

        * Crump et al. (2009) optimal trimming rule:
        * Find alpha that satisfies 1/(alpha*(1-alpha)) = 2*E[1/(e*(1-e))]
        * where expectation is over observations with alpha <= e <= 1-alpha
        * The helper sorts once and uses cumulative sums plus binary searches for
        * every retained interval. This preserves the original coarse/refined
        * grid while avoiding roughly 70 full-data summarize passes.
        quietly {
            _psdash_crump_alpha `psvar' if `touse'
            local best_alpha = r(alpha)

            if `best_alpha' > 0 {
                local crump_alpha = `best_alpha'
                local trim_lower = `crump_alpha'
                local trim_upper = 1 - `crump_alpha'
            }
            else {
                * Fallback to standard 0.1 threshold
                local crump_alpha = 0.1
                local trim_lower = 0.1
                local trim_upper = 0.9
                noisily display as text "note: Crump search did not converge; using alpha = 0.1"
            }

            * Count trimmed observations
            count if (`psvar' < `trim_lower' | `psvar' > `trim_upper') & `touse'
            local n_trimmed = r(N)
            local pct_trimmed = 100 * `n_trimmed' / `N'
        }
    }

    if `threshold' != -1 {
        local has_trimming = 1
        local trim_lower = `threshold'
        local trim_upper = 1 - `threshold'

        quietly {
            count if (`psvar' < `trim_lower' | `psvar' > `trim_upper') & `touse'
            local n_trimmed = r(N)
            local pct_trimmed = 100 * `n_trimmed' / `N'
        }
    }

    * RB-11: a trim that retains no analysis sample -- or that eliminates a
    * treatment arm -- destroys identifiability and is not a usable support
    * remedy. Probe S1 trimmed 100% of observations, generated an all-missing
    * indicator, and still returned "Trimmed" with rc=0. Recheck the retained
    * sample here, BEFORE the indicator is generated or a success verdict is
    * displayed, and fail closed if the estimand is no longer identifiable.
    if `has_trimming' {
        tempvar _psd_retain
        quietly gen byte `_psd_retain' = ///
            (`psvar' >= `trim_lower' & `psvar' <= `trim_upper') & `touse'
        quietly count if `_psd_retain'
        local n_retained = r(N)
        if `n_retained' == 0 {
            display as error "trimming removed every observation (`=string(`pct_trimmed',"%4.1f")'% excluded)"
            display as error "  the trim region [`=string(`trim_lower',"%5.3f")', `=string(`trim_upper',"%5.3f")'] contains no"
            display as error "  propensity scores, so no analysis sample remains. Widen the threshold"
            display as error "  or use {cmd:psdash support, crump} for a data-driven trim."
            exit 459
        }
        quietly count if `_psd_retain' & `treatment' == 1
        local n_ret_t = r(N)
        quietly count if `_psd_retain' & `treatment' == 0
        local n_ret_c = r(N)
        if `n_ret_t' == 0 | `n_ret_c' == 0 {
            display as error "trimming eliminated a treatment arm"
            display as error "  the retained sample has `n_ret_t' treated and `n_ret_c' control observation(s);"
            display as error "  a common-support region must keep both arms to remain identifiable."
            exit 459
        }
    }

    * GENERATE SUPPORT INDICATOR
    if "`generate'" != "" {
        if "`replace'" != "" {
            capture drop `generate'  // safe: capture swallows 111 if var doesn't exist
        }

        if `has_trimming' {
            quietly gen byte `generate' = ///
                (`psvar' >= `trim_lower' & `psvar' <= `trim_upper') if `touse'
            label variable `generate' "In trimmed support [`=string(`trim_lower', "%5.3f")', `=string(`trim_upper', "%5.3f")']"
        }
        else {
            quietly gen byte `generate' = ///
                (`psvar' >= `lower_bound' & `psvar' <= `upper_bound') if `touse'
            label variable `generate' "In common support [`=string(`lower_bound', "%5.3f")', `=string(`upper_bound', "%5.3f")']"
        }
    }

    * DISPLAY OUTPUT
    display as text _n `"`title'"'
    display as text "Treatment:         " as result "`treatment'"
    display as text "PS variable:       " as result "`psvar_label'"
    display as text "Observations:      " as result %10.0fc `N'
    if "`source'" != "manual" {
        display as text "Source:            " as result "`source'"
    }
    display ""

    * PS range by group
    display as text "{hline 60}"
    display as text "Propensity Score Range"
    display as text "{hline 60}"
    display as text %20s "" %15s "Treated" %15s "Control"
    display as text "{hline 60}"
    display as text %20s "N" ///
        as result %15.0fc `n_treated' %15.0fc `n_control'
    display as text %20s "Min PS" ///
        as result %15.4f `min_ps_t' %15.4f `min_ps_c'
    display as text %20s "Max PS" ///
        as result %15.4f `max_ps_t' %15.4f `max_ps_c'
    display as text "{hline 60}"
    display ""

    * Common support
    display as text "{hline 55}"
    display as text "Common Support Region"
    display as text "{hline 55}"
    if `qtrim' >= 0 {
        display as text "Method:                " as result ///
            "quantile (p`=string(`qtrim',"%3.1f")'/p`=string(100-`qtrim',"%3.1f")')"
    }
    else {
        display as text "Method:                " as result "min-max overlap (optimistic)"
    }
    display as text "Lower bound:           " as result %10.4f `lower_bound'
    display as text "Upper bound:           " as result %10.4f `upper_bound'
    display as text "Outside support:       " ///
        as result %10.0f `n_outside' as text " (" as result %5.2f `pct_outside' as text "%)"
    display as text "  Treated outside:     " as result %10.0f `n_outside_t'
    display as text "  Control outside:     " as result %10.0f `n_outside_c'
    display as text "{hline 55}"

    * Trimming results
    if `has_trimming' {
        display ""
        display as text "{hline 55}"
        if "`crump'" != "" {
            display as text "Crump et al. (2009) Optimal Trimming"
            display as text "{hline 55}"
            display as text "Optimal alpha:         " as result %10.4f `crump_alpha'
        }
        else {
            display as text "Manual Threshold Trimming"
            display as text "{hline 55}"
            display as text "Threshold:             " as result %10.4f `threshold'
        }
        display as text "Trim region:           " ///
            as result "[`=string(`trim_lower', "%5.3f")', `=string(`trim_upper', "%5.3f")']"
        display as text "Observations trimmed:  " ///
            as result %10.0f `n_trimmed' as text " (" as result %5.2f `pct_trimmed' as text "%)"
        display as text "Remaining sample:      " as result %10.0f `=`N' - `n_trimmed''
        display as text "{hline 55}"
    }

    if "`generate'" != "" {
        display as text _n "Support indicator generated: " as result "`generate'"
    }

    * Warnings (RB-01: every warning-worthy condition becomes a machine-readable
    * finding; ANY finding forces a non-Good verdict and enters r(warnings).)
    local _pf ""
    local _pfn = 0
    if `n_ps_boundary' > 0 {
        display as error "Warning: `n_ps_boundary' observation(s) have PS exactly 0 or 1."
        display as error "  Exact boundaries violate strict positivity."
        local _pf `"`_pf' | `n_ps_boundary' exact-PS-boundary positivity violation(s)"'
        local ++_pfn
    }
    if `n_ps_near' > 0 {
        display as text "Note: `n_ps_near' additional observation(s) have PS < 0.01 or > 0.99."
    }
    if `pct_outside' > 10 {
        display as error "Warning: >10% of observations outside common support."
        local _pf `"`_pf' | `=string(`pct_outside',"%4.1f")'% outside common support"'
        local ++_pfn
    }
    if `upper_bound' <= `lower_bound' {
        display as error "Warning: No common support region (upper <= lower bound)."
        local _pf `"`_pf' | no common support region (upper <= lower)"'
        local ++_pfn
    }
    local _pf = strtrim("`_pf'")
    if substr("`_pf'", 1, 1) == "|" local _pf = strtrim(substr("`_pf'", 2, .))
    local _support_findings `"`_pf'"'
    local _support_nfind = `_pfn'

    * Verdict (WARNING on ANY finding)
    if `has_trimming' {
        display as text _n "Support: " as result "Trimmed" ///
            as text " (" as result %4.1f `pct_trimmed' as text "% excluded)"
    }
    else if `_pfn' > 0 {
        display as text _n "Support: " as error "WARNING" ///
            as text " (" as result %4.1f `pct_outside' as text "% outside support; " ///
            as result `_pfn' as text " finding(s))"
        display as text "  Consider: {cmd:psdash support, crump generate(in_support)}"
    }
    else {
        display as text _n "Support: " as result "Good" ///
            as text " (" as result %4.1f `pct_outside' as text "% outside support)"
    }

    * PRE/POST-TRIMMING COMPARISON (F3, binary)
    local _has_compare = 0
    if "`compare'" != "" {
        if !`has_trimming' {
            display as text _n "note: compare requires trimming (crump or threshold()); skipped"
        }
        else {
            tempvar _tt
            quietly gen byte `_tt' = `touse' & ///
                (`psvar' >= `trim_lower' & `psvar' <= `trim_upper')
            quietly count if `_tt'
            local cmp_n_post = r(N)

            * Outside-support % recomputed on the trimmed sample
            local cmp_pct_pre = `pct_outside'
            local cmp_pct_post = .
            capture _psdash_support_stats, treatment(`treatment') ///
                samplevar(`_tt') psvar(`psvar') n(`cmp_n_post') qtrim(`qtrim')
            if _rc == 0 local cmp_pct_post = r(pct_outside)

            * ESS% pre/post from estimand IPTW weights derived from the PS
            local cmp_ess_pre = .
            local cmp_ess_post = .
            tempvar _cmpw
            quietly {
                gen double `_cmpw' = .
                if "`estimand'" == "att" {
                    replace `_cmpw' = 1 if `treatment' == 1 & `touse'
                    replace `_cmpw' = `psvar'/(1-`psvar') if `treatment' == 0 & `psvar' < 1 & `touse'
                }
                else if "`estimand'" == "atc" {
                    replace `_cmpw' = (1-`psvar')/`psvar' if `treatment' == 1 & `psvar' > 0 & `touse'
                    replace `_cmpw' = 1 if `treatment' == 0 & `touse'
                }
                else {
                    replace `_cmpw' = 1/`psvar' if `treatment' == 1 & `psvar' > 0 & `touse'
                    replace `_cmpw' = 1/(1-`psvar') if `treatment' == 0 & `psvar' < 1 & `touse'
                }
            }
            quietly count if `touse' & !missing(`_cmpw')
            local _npre = r(N)
            quietly count if `_tt' & !missing(`_cmpw')
            local _npost = r(N)
            capture _psdash_weights_stats, wvar(`_cmpw') treatment(`treatment') ///
                samplevar(`touse') n(`_npre')
            if _rc == 0 local cmp_ess_pre = r(ess_pct)
            capture _psdash_weights_stats, wvar(`_cmpw') treatment(`treatment') ///
                samplevar(`_tt') n(`_npost')
            if _rc == 0 local cmp_ess_post = r(ess_pct)

            * Max |SMD| (raw) pre/post when covariates are available
            local cmp_smd_pre = .
            local cmp_smd_post = .
            local cmp_covs "`covariates'"
            if "`cmp_covs'" == "" local cmp_covs "`_psd_covariates'"
            if "`cmp_covs'" != "" {
                capture _psdash_balance_binary `cmp_covs', treatment(`treatment') ///
                    samplevar(`touse') threshold(0.1)
                if _rc == 0 local cmp_smd_pre = r(max_smd_raw)
                capture _psdash_balance_binary `cmp_covs', treatment(`treatment') ///
                    samplevar(`_tt') threshold(0.1)
                if _rc == 0 local cmp_smd_post = r(max_smd_raw)
            }

            * Display comparison
            display as text _n "Pre/Post-Trimming Comparison"
            display as text %28s "Metric" %13s "Pre" %13s "Post"
            display as text %28s "N retained" ///
                as result %13.0fc `N' %13.0fc `cmp_n_post'
            display as text %28s "Outside support (%)" ///
                as result %13.2f `cmp_pct_pre' %13.2f `cmp_pct_post'
            if !missing(`cmp_ess_pre') {
                display as text %28s "ESS (% of N)" ///
                    as result %13.1f `cmp_ess_pre' %13.1f `cmp_ess_post'
            }
            if !missing(`cmp_smd_pre') {
                display as text %28s "Max |SMD| (raw)" ///
                    as result %13.3f `cmp_smd_pre' %13.3f `cmp_smd_post'
            }
            else {
                display as text "note: max |SMD| delta skipped (no covariates supplied/detected)"
            }
            local _has_compare = 1
        }
    }

    * GRAPH
    if "`nograph'" == "" {
        capture noisily {
            quietly {
                if "`scheme'" != "" {
                    local graphoptions `"scheme(`scheme') `graphoptions'"'
                }

                * Build xline options
                local xlines "xline(`lower_bound' `upper_bound', lcolor(gs8) lpattern(dash))"
                if `has_trimming' {
                    local xlines "`xlines' xline(`trim_lower' `trim_upper', lcolor(red) lpattern(shortdash))"
                }

                noisily twoway ///
                    (kdensity `psvar' if `touse' & `treatment' == 1, ///
                        lcolor(navy) lwidth(medthick)) ///
                    (kdensity `psvar' if `touse' & `treatment' == 0, ///
                        lcolor(cranberry) lwidth(medthick)), ///
                    legend(order(1 "Treated" 2 "Control") rows(1) position(6)) ///
                    xscale(range(0 1)) xtitle("Propensity Score") ytitle("Density") ///
                    title(`"`title'"') ///
                    `xlines' ///
                    name(`name', replace) ///
                    `graphoptions'

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
            local _xk `""Treatment" "PS variable" "Total N" "N (treated)" "N (control)" "Lower bound" "Upper bound" "Outside support (N)" "Outside support (%)" "Treated outside" "Control outside""'
            local _xv `""`treatment'" "`psvar_label'" "`N'" "`n_treated'" "`n_control'" "`=string(`lower_bound',"%6.4f")'" "`=string(`upper_bound',"%6.4f")'" "`n_outside'" "`=string(`pct_outside',"%5.2f")'" "`n_outside_t'" "`n_outside_c'""'
            if `has_trimming' {
                local _xk `"`_xk' "Trim lower" "Trim upper" "Trimmed (N)" "Trimmed (%)" "Remaining N""'
                local _xv `"`_xv' "`=string(`trim_lower',"%6.4f")'" "`=string(`trim_upper',"%6.4f")'" "`n_trimmed'" "`=string(`pct_trimmed',"%5.2f")'" "`=`N'-`n_trimmed''""'
                if "`crump'" != "" {
                    local _xk `"`_xk' "Crump alpha""'
                    local _xv `"`_xv' "`=string(`crump_alpha',"%6.4f")'""'
                }
            }
            _psdash_export_kv, xlsx("`xlsx'") sheet("`sheet'") ///
                title("`title'") keys(`_xk') vals(`_xv')
            noisily display as text _n "Support table exported to: " as result "`xlsx'"
        }
        local xlsx_rc = _rc
        if `xlsx_rc' local _psdash_side_rc = `xlsx_rc'
    }

    local _psdash_return_mode "binary"

    }
    else {
    * MULTI-GROUP PATH (K >= 2 with non-0/1 values)

    * Reject Crump for multi-group
    if "`crump'" != "" {
        display as error "crump trimming is defined for binary treatment only"
        display as error "  use {cmd:threshold()} for multi-group trimming"
        exit 198
    }

    * Reject qtrim for multi-group
    if `qtrim' != -1 {
        display as error "qtrim() is supported for binary treatment only"
        exit 198
    }

    * Pre/post-trimming comparison is binary-only
    if "`compare'" != "" {
        display as error "compare is supported for binary treatment only"
        exit 198
    }

    * Validate each group has at least 2 observations
    foreach lev of local levels {
        quietly count if `treatment' == `lev' & `touse'
        if r(N) < 2 {
            display as error "each treatment group must have at least 2 observations"
            exit 2001
        }
    }

    * Validate PS range for every supplied/generated group-specific PS column.
    foreach psv of local mg_psvars_all {
        quietly summarize `psv' if `touse'
        if r(min) < 0 | r(max) > 1 {
            display as error "propensity scores must be in [0,1]"
            exit 198
        }
    }

    tempvar obs_ps
    quietly gen double `obs_ps' = . if `touse'
    foreach lev of local levels {
        local lev_ps "`group_ps_`lev''"
        quietly replace `obs_ps' = `lev_ps' if `treatment' == `lev' & `touse'
    }

    if "`crump'" != "" & `threshold' != -1 {
        display as error "cannot specify both crump and threshold()"
        exit 198
    }

    if `threshold' != -1 {
        if `threshold' <= 0 | `threshold' >= 0.5 {
            display as error "threshold() must be between 0 and 0.5"
            exit 198
        }
    }

    * Validate generate
    if "`generate'" != "" {
        local reserved_names "`treatment' `psvar' `det_wvar' _psdash_ps _psdash_wt `mg_psvars_all'"
        local reserved_names : list uniq reserved_names
        foreach reserved of local reserved_names {
            if "`reserved'" == "" continue
            if "`generate'" == "`reserved'" {
                display as error "generate() cannot be the same as `reserved'"
                exit 198
            }
        }
        if substr("`generate'", 1, 8) == "_psdash_" {
            display as error "generate() cannot use the reserved _psdash_ prefix"
            exit 198
        }
    }
    if "`generate'" != "" & "`replace'" == "" {
        capture confirm new variable `generate'
        if _rc {
            display as error "variable `generate' already exists; use replace option"
            exit 110
        }
    }

    * Set defaults
    if "`title'" == "" local title "Common Support Assessment"
    if "`name'" == "" local name "psdash_support"

    * Get group labels
    foreach lev of local levels {
        local lbl_`lev' : label (`treatment') `lev'
        if "`lbl_`lev''" == "" local lbl_`lev' "Group `lev'"
    }

    * COMMON SUPPORT ANALYSIS
    local _mg_group_psvars ""
    foreach lev of local levels {
        local _mg_group_psvars "`_mg_group_psvars' `group_ps_`lev''"
    }
    _psdash_support_stats, treatment(`treatment') samplevar(`touse') ///
        obsps(`obs_ps') levels(`levels') grouppsvars(`_mg_group_psvars') ///
        multigroup(`multigroup') n(`N') gpsfloor(`gpsfloor')
    foreach lev of local levels {
        local n_group_`lev' = r(n_group_`lev')
        local min_ps_`lev' = r(min_ps_`lev')
        local max_ps_`lev' = r(max_ps_`lev')
        local n_outside_`lev' = r(n_outside_`lev')
        local min_gps_`lev' = r(min_gps_`lev')
    }
    local lower_bound = r(lower_bound)
    local upper_bound = r(upper_bound)
    local n_outside = r(n_outside)
    local pct_outside = r(pct_outside)
    * Full-vector GPS positivity (RB-02)
    local min_gps = r(min_gps)
    local n_gps_violate = r(n_gps_violate)
    local pct_gps_violate = r(pct_gps_violate)
    local n_ps_boundary = r(n_ps_boundary)
    local n_ps_near = r(n_ps_near)
    tempname gps_means
    matrix `gps_means' = r(gps_means)

    * THRESHOLD TRIMMING (multi-group)
    local trim_lower = 0
    local trim_upper = 1
    local n_trimmed = 0
    local pct_trimmed = 0
    local has_trimming = 0

    * min_j e_j(X) is the multi-arm support quantity for BOTH the trimmed and the
    * untrimmed indicator (RB-12), so build it unconditionally rather than only
    * inside the trimming branch.
    tempvar _psd_min_gps
    local _first_gps : word 1 of `_mg_group_psvars'
    quietly gen double `_psd_min_gps' = `_first_gps' if `touse'
    foreach _gps of local _mg_group_psvars {
        quietly replace `_psd_min_gps' = min(`_psd_min_gps', `_gps') if `touse'
    }

    if `threshold' != -1 {
        local has_trimming = 1
        local trim_lower = `threshold'
        local trim_upper = 1 - `threshold'

        quietly {
            count if `_psd_min_gps' < `trim_lower' & `touse'
            local n_trimmed = r(N)
            local pct_trimmed = 100 * `n_trimmed' / `N'
        }
    }

    * RB-11: reject a multi-group trim that empties the sample or eliminates a
    * group before generating an indicator or reporting success. Multi-group
    * threshold trimming requires every GPS component to meet the floor.
    if `has_trimming' {
        tempvar _psd_retain_mg
        quietly gen byte `_psd_retain_mg' = (`_psd_min_gps' >= `trim_lower') & `touse'
        quietly count if `_psd_retain_mg'
        if r(N) == 0 {
            display as error "trimming removed every observation (`=string(`pct_trimmed',"%4.1f")'% excluded)"
            display as error "  no unit has every GPS component >= `=string(`trim_lower',"%5.3f")'."
            exit 459
        }
        foreach lev of local levels {
            quietly count if `_psd_retain_mg' & `treatment' == `lev'
            if r(N) == 0 {
                display as error "trimming eliminated treatment group `lev'"
                display as error "  a multi-group support region must keep every arm to remain identifiable."
                exit 459
            }
        }
    }

    * GENERATE SUPPORT INDICATOR
    if "`generate'" != "" {
        if "`replace'" != "" {
            capture drop `generate'
        }

        if `has_trimming' {
            quietly gen byte `generate' = (`_psd_min_gps' >= `trim_lower') if `touse'
            label variable `generate' "All GPS components >= `=string(`trim_lower', "%5.3f")'"
        }
        else {
            * RB-12: the untrimmed multi-group indicator used to materialize the
            * observed-arm min-max rule that the panel two screens below labels
            * "informational only; NOT a valid multi-arm common-support rule" --
            * so generate() handed the user a variable built from the rule the
            * command disowns, marking GPS-positivity violators as in-support.
            * Use the panel's own primary diagnostic instead: every component of
            * the GPS vector at or above gpsfloor() (Li & Li 2019, Assumption 2).
            quietly gen byte `generate' = (`_psd_min_gps' >= `gpsfloor') if `touse'
            label variable `generate' "All GPS components >= `=string(`gpsfloor', "%5.3f")'"
        }
    }

    * DISPLAY OUTPUT
    display as text _n `"`title'"'
    display as text "Treatment:         " as result "`treatment'" as text " (`K' groups)"
    display as text "PS variable:       " as result "`psvar_label'"
    display as text "Reference group:   " as result "`reference_grp'"
    display as text "Observations:      " as result %10.0fc `N'
    if "`source'" != "manual" {
        display as text "Source:            " as result "`source'"
    }
    display ""

    * Like-for-like GPS summary: every column is one fixed e_j(X), evaluated
    * within every observed treatment group (McCaffrey et al. 2013).
    local col_width = 13
    local hline_width = 30 + `K' * `col_width'
    display as text "{hline `hline_width'}"
    display as text "Mean GPS by Observed Treatment Group"
    display as text "{hline `hline_width'}"

    display as text %20s "Observed group" %10s "N" _c
    foreach lev of local levels {
        display as text %`col_width's "e(`lbl_`lev'')" _c
    }
    display ""
    display as text "{hline `hline_width'}"

    local ridx = 0
    foreach observed_level of local levels {
        local ++ridx
        display as text %20s "`lbl_`observed_level''" ///
            as result %10.0fc `n_group_`observed_level'' _c
        forvalues cidx = 1/`K' {
            display as result %`col_width'.4f ///
                `gps_means'[`ridx', `cidx'] _c
        }
        display ""
    }
    display as text "{hline `hline_width'}"
    display ""

    * Generalized-propensity-score positivity (full vector) — the valid
    * multi-arm common-support diagnostic (Li & Li 2019, Assumption 2;
    * McCaffrey et al. 2013). Evaluates every e_j(X), not the observed-arm
    * scalar, so a near-zero probability of an UNRECEIVED arm is visible.
    display as text "{hline 55}"
    display as text "Generalized Positivity (full GPS vector)"
    display as text "{hline 55}"
    display as text "Min GPS (worst unit): " as result %12.4f `min_gps'
    display as text "Floor:               " as result %12.4f `gpsfloor'
    display as text "Below floor:         " ///
        as result %12.0f `n_gps_violate' as text " (" as result %5.2f `pct_gps_violate' as text "%)"
    foreach lev of local levels {
        display as text "  min e(`lbl_`lev''): " as result %12.4f `min_gps_`lev''
    }
    display as text "{hline 55}"
    display ""

    * Observed-arm PS overlap (informational only; NOT a valid multi-arm
    * common-support rule — it intersects arm-specific ranges of the observed-
    * arm score. Retained only as a backward-compatible descriptive return.)
    display as text "{hline 55}"
    display as text "Observed-arm PS Overlap (informational)"
    display as text "{hline 55}"
    display as text "Lower bound:           " as result %10.4f `lower_bound'
    display as text "Upper bound:           " as result %10.4f `upper_bound'
    display as text "Outside overlap:       " ///
        as result %10.0f `n_outside' as text " (" as result %5.2f `pct_outside' as text "%)"
    foreach lev of local levels {
        display as text "  `lbl_`lev'' outside: " as result %10.0f `n_outside_`lev''
    }
    display as text "{hline 55}"

    * Trimming results
    if `has_trimming' {
        display ""
        display as text "{hline 55}"
        display as text "Manual Threshold Trimming"
        display as text "{hline 55}"
        display as text "Threshold:             " as result %10.4f `threshold'
        * RB-12: multi-group trimming applies a LOWER floor to every GPS
        * component (min_j e_j >= t); there is no upper cut, so displaying a
        * two-sided "[t, 1-t]" region described a rule the code never applies.
        display as text "Trim floor:            " ///
            as result "`=string(`trim_lower', "%5.3f")'" as text " (every GPS component)"
        display as text "Observations trimmed:  " ///
            as result %10.0f `n_trimmed' as text " (" as result %5.2f `pct_trimmed' as text "%)"
        display as text "Remaining sample:      " as result %10.0f `=`N' - `n_trimmed''
        display as text "{hline 55}"
    }

    if "`generate'" != "" {
        display as text _n "Support indicator generated: " as result "`generate'"
    }

    * Warnings (RB-01: propagate every printed warning into a machine-readable
    * finding list; ANY finding forces a non-Good verdict + r(warnings).)
    local _pf ""
    local _pfn = 0
    * PRIMARY multi-arm finding: full-vector GPS positivity violation
    * (Li & Li 2019 Assumption 2). Catches a near-zero probability of an
    * unreceived arm that the observed-arm overlap rule below cannot see.
    if `n_gps_violate' > 0 {
        display as error "Warning: `n_gps_violate' observation(s) violate GPS positivity" ///
            _n "  (probability of some treatment < `=string(`gpsfloor',"%4.3f")'; min GPS = `=string(`min_gps',"%5.4f")')."
        local _pf `"`_pf' | `n_gps_violate' unit(s) below GPS positivity floor `=string(`gpsfloor',"%4.3f")' (min GPS `=string(`min_gps',"%5.4f")')"'
        local ++_pfn
    }
    if `n_ps_near' > 0 & `n_gps_violate' == 0 {
        display as text "Note: `n_ps_near' unit(s) have a GPS component < 0.01 or > 0.99."
    }
    local _pf = strtrim("`_pf'")
    if substr("`_pf'", 1, 1) == "|" local _pf = strtrim(substr("`_pf'", 2, .))
    local _support_findings `"`_pf'"'
    local _support_nfind = `_pfn'

    * Verdict (WARNING on ANY finding)
    if `has_trimming' {
        display as text _n "Support: " as result "Trimmed" ///
            as text " (" as result %4.1f `pct_trimmed' as text "% excluded)"
    }
    else if `_pfn' > 0 {
        display as text _n "Support: " as error "WARNING" ///
            as text " (" as result `_pfn' as text " finding(s))"
        display as text "  Consider: {cmd:psdash support, threshold(0.05)}"
    }
    else {
        display as text _n "Support: " as result "No GPS-floor violation" ///
            as text " (" as result %4.1f `pct_gps_violate' as text "% below " ///
            as result %5.3f `gpsfloor' as text ")"
    }

    * GRAPH
    if "`nograph'" == "" {
        local _saving_opt ""
        if `"`saving'"' != "" local _saving_opt `"saving(`"`saving'"')"'
        local _scheme_opt ""
        if "`scheme'" != "" local _scheme_opt "scheme(`scheme')"
        local _graphoptions_opt ""
        if `"`graphoptions'"' != "" {
            local _graphoptions_opt `"graphoptions(`"`graphoptions'"')"'
        }
        local _graph_floor = cond(`has_trimming', `trim_lower', `gpsfloor')

        capture noisily _psdash_mgps_graph, treatment(`treatment') ///
            samplevar(`touse') psvars(`_mg_group_psvars') levels(`levels') ///
            name(`name') gpsfloor(`_graph_floor') ///
            title(`"`title'"') `_saving_opt' `_scheme_opt' `_graphoptions_opt'
        local graph_rc = _rc
        if `graph_rc' {
            local _psdash_side_rc = `graph_rc'
        }
    }

    * EXPORT TO EXCEL (multi-group, O1)
    if "`xlsx'" != "" & `_psdash_side_rc' == 0 {
        capture noisily {
            local _xk `""Treatment" "PS variable" "Groups (K)" "Reference" "Total N""'
            local _xv `""`treatment'" "`psvar_label'" "`K'" "`reference_grp'" "`N'""'
            foreach lev of local levels {
                local _xk `"`_xk' "N (group `lev')" "Min PS (group `lev')" "Max PS (group `lev')" "Outside (group `lev')""'
                local _xv `"`_xv' "`n_group_`lev''" "`=string(`min_ps_`lev'',"%6.4f")'" "`=string(`max_ps_`lev'',"%6.4f")'" "`n_outside_`lev''""'
            }
            local _ridx = 0
            foreach observed_level of local levels {
                local ++_ridx
                local _cidx = 0
                foreach score_level of local levels {
                    local ++_cidx
                    local _xk `"`_xk' "Mean e(`score_level') | observed group `observed_level'""'
                    local _xv `"`_xv' "`=string(`gps_means'[`_ridx',`_cidx'],"%6.4f")'""'
                }
            }
            local _xk `"`_xk' "Min GPS (worst unit)" "GPS floor" "Below GPS floor (N)" "Below GPS floor (%)""'
            local _xv `"`_xv' "`=string(`min_gps',"%6.4f")'" "`=string(`gpsfloor',"%6.4f")'" "`n_gps_violate'" "`=string(`pct_gps_violate',"%5.2f")'""'
            local _xk `"`_xk' "Observed-arm overlap lower" "Observed-arm overlap upper" "Outside observed-arm overlap (N)" "Outside observed-arm overlap (%)""'
            local _xv `"`_xv' "`=string(`lower_bound',"%6.4f")'" "`=string(`upper_bound',"%6.4f")'" "`n_outside'" "`=string(`pct_outside',"%5.2f")'""'
            if `has_trimming' {
                local _xk `"`_xk' "Trim floor (every GPS component)" "Trimmed (N)" "Trimmed (%)" "Remaining N""'
                local _xv `"`_xv' "`=string(`trim_lower',"%6.4f")'" "`n_trimmed'" "`=string(`pct_trimmed',"%5.2f")'" "`=`N'-`n_trimmed''""'
            }
            _psdash_export_kv, xlsx("`xlsx'") sheet("`sheet'") ///
                title("`title'") keys(`_xk') vals(`_xv')
            noisily display as text _n "Support table exported to: " as result "`xlsx'"
        }
        local xlsx_rc = _rc
        if `xlsx_rc' local _psdash_side_rc = `xlsx_rc'
    }

    local _psdash_return_mode "multigroup"

    }

    }
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
            return scalar lower_bound = `lower_bound'
            return scalar upper_bound = `upper_bound'
            if `qtrim' != -1 return scalar qtrim = `qtrim'
            return scalar n_outside = `n_outside'
            return scalar pct_outside = `pct_outside'
            return scalar n_outside_treated = `n_outside_t'
            return scalar n_outside_control = `n_outside_c'
            if `has_trimming' {
                return scalar trim_lower = `trim_lower'
                return scalar trim_upper = `trim_upper'
                return scalar n_trimmed = `n_trimmed'
                return scalar pct_trimmed = `pct_trimmed'
                return scalar N_remaining = `N' - `n_trimmed'
                if "`crump'" != "" {
                    return scalar crump_alpha = `crump_alpha'
                }
            }
            return scalar n_ps_boundary = `n_ps_boundary'
            return scalar n_ps_near_boundary = `n_ps_near'
            return local treatment "`treatment'"
            return local psvar "`psvar_label'"
            return local estimand "`estimand'"
            return local source "`source'"
            if `_has_compare' {
                return scalar n_post = `cmp_n_post'
                return scalar pct_outside_pre = `cmp_pct_pre'
                return scalar pct_outside_post = `cmp_pct_post'
                if !missing(`cmp_ess_pre') {
                    return scalar ess_pct_pre = `cmp_ess_pre'
                    return scalar ess_pct_post = `cmp_ess_post'
                }
                if !missing(`cmp_smd_pre') {
                    return scalar max_smd_pre = `cmp_smd_pre'
                    return scalar max_smd_post = `cmp_smd_post'
                }
            }
        }
        else if "`_psdash_return_mode'" == "multigroup" {
            return scalar N = `N'
            return scalar K = `K'
            foreach lev of local levels {
                return scalar N_group_`lev' = `n_group_`lev''
                return scalar n_outside_group_`lev' = `n_outside_`lev''
                return scalar min_gps_group_`lev' = `min_gps_`lev''
            }
            return scalar lower_bound = `lower_bound'
            return scalar upper_bound = `upper_bound'
            return scalar n_outside = `n_outside'
            return scalar pct_outside = `pct_outside'
            * Full-vector GPS positivity (RB-02)
            return scalar min_gps = `min_gps'
            return scalar n_gps_violate = `n_gps_violate'
            return scalar pct_gps_violate = `pct_gps_violate'
            return scalar gps_floor = `gpsfloor'
            if `has_trimming' {
                * RB-12: multi-group trimming is a one-sided floor on every GPS
                * component. There is no upper cut, so r(trim_upper) (= 1 -
                * threshold) described a bound the code never applied and is not
                * returned here. r(trim_lower) is that floor.
                return scalar trim_lower = `trim_lower'
                return scalar n_trimmed = `n_trimmed'
                return scalar pct_trimmed = `pct_trimmed'
                return scalar N_remaining = `N' - `n_trimmed'
            }
            return scalar n_ps_boundary = `n_ps_boundary'
            return scalar n_ps_near_boundary = `n_ps_near'
            return local treatment "`treatment'"
            return local psvar "`psvar_label'"
            return local levels "`levels'"
            return local reference "`reference_grp'"
            return local estimand "`estimand'"
            return local source "`source'"
            return matrix gps_means = `gps_means'
        }
        * RB-01 unified findings surface (both modes)
        if "`_support_nfind'" == "" local _support_nfind = 0
        return scalar n_warnings = `_support_nfind'
        return local warnings `"`_support_findings'"'

        * RB-05 estimation-sample exclusion ledger (teffects only)
        if "`n_excluded'" != "" {
            return scalar n_excluded = `n_excluded'
            return scalar n_estimation = `n_estimation'
        }
    }
    if `rc' exit `rc'
end
