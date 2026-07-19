*! psdash_support Version 1.4.1  2026/07/07
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
    r(lower_bound)          - Lower bound of common support
    r(upper_bound)          - Upper bound of common support
    r(n_outside)            - Total observations outside support
    r(pct_outside)          - Percentage outside support
    r(n_outside_group_<lev>)- Per-group outside counts
    r(trim_lower)           - Trimming lower bound (if threshold)
    r(trim_upper)           - Trimming upper bound (if threshold)
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

    * Positivity warnings
    _psdash_pscheck `psvar' if `touse'
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
        * Grid search over alpha in [0.01, 0.49]

        quietly {
            tempvar inv_var_ps
            gen double `inv_var_ps' = 1 / (`psvar' * (1 - `psvar')) if `touse'

            local best_alpha = 0
            local best_diff = .

            * Coarse grid over [0.01, 0.49] at 0.01, then refine to 0.001 around
            * the coarse minimum so the reported alpha is not pinned to a 1% step.
            forvalues a_int = 1/49 {
                local alpha = `a_int' / 100

                * LHS: 1 / (alpha * (1 - alpha))
                local lhs = 1 / (`alpha' * (1 - `alpha'))

                * RHS: 2 * E[1/(e*(1-e))] for e in [alpha, 1-alpha]
                local upper_a = 1 - `alpha'
                summarize `inv_var_ps' if `psvar' >= `alpha' & `psvar' <= `upper_a' & `touse'
                if r(N) > 0 {
                    local rhs = 2 * r(mean)

                    local diff = abs(`lhs' - `rhs')
                    if `diff' < `best_diff' {
                        local best_diff = `diff'
                        local best_alpha = `alpha'
                    }
                }
            }

            if `best_alpha' > 0 {
                local _lo = round(100 * (`best_alpha' - 0.01))
                local _hi = round(100 * (`best_alpha' + 0.01))
                if `_lo' < 1 local _lo = 1
                if `_hi' > 49 local _hi = 49
                forvalues a_int = `=`_lo'*10'/`=`_hi'*10' {
                    local alpha = `a_int' / 1000
                    if `alpha' <= 0 | `alpha' >= 0.5 continue
                    local lhs = 1 / (`alpha' * (1 - `alpha'))
                    local upper_a = 1 - `alpha'
                    summarize `inv_var_ps' if `psvar' >= `alpha' & `psvar' <= `upper_a' & `touse'
                    if r(N) > 0 {
                        local rhs = 2 * r(mean)
                        local diff = abs(`lhs' - `rhs')
                        if `diff' < `best_diff' {
                            local best_diff = `diff'
                            local best_alpha = `alpha'
                        }
                    }
                }
            }

            drop `inv_var_ps'

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
                    xtitle("Propensity Score") ytitle("Density") ///
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

    * Positivity warnings are based on the probability of each observation's
    * observed treatment group.
    _psdash_pscheck `obs_ps' if `touse', advice({cmd:psdash support, threshold(0.05)})
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
        multigroup(`multigroup') n(`N')
    foreach lev of local levels {
        local n_group_`lev' = r(n_group_`lev')
        local min_ps_`lev' = r(min_ps_`lev')
        local max_ps_`lev' = r(max_ps_`lev')
        local n_outside_`lev' = r(n_outside_`lev')
    }
    local lower_bound = r(lower_bound)
    local upper_bound = r(upper_bound)
    local n_outside = r(n_outside)
    local pct_outside = r(pct_outside)

    * THRESHOLD TRIMMING (multi-group)
    local trim_lower = 0
    local trim_upper = 1
    local n_trimmed = 0
    local pct_trimmed = 0
    local has_trimming = 0

    if `threshold' != -1 {
        local has_trimming = 1
        local trim_lower = `threshold'
        local trim_upper = 1 - `threshold'

        quietly {
            count if (`obs_ps' < `trim_lower' | `obs_ps' > `trim_upper') & `touse'
            local n_trimmed = r(N)
            local pct_trimmed = 100 * `n_trimmed' / `N'
        }
    }

    * GENERATE SUPPORT INDICATOR
    if "`generate'" != "" {
        if "`replace'" != "" {
            capture drop `generate'
        }

        if `has_trimming' {
            quietly gen byte `generate' = ///
                (`obs_ps' >= `trim_lower' & `obs_ps' <= `trim_upper') if `touse'
            label variable `generate' "In trimmed support [`=string(`trim_lower', "%5.3f")', `=string(`trim_upper', "%5.3f")']"
        }
        else {
            quietly gen byte `generate' = ///
                (`obs_ps' >= `lower_bound' & `obs_ps' <= `upper_bound') if `touse'
            label variable `generate' "In common support [`=string(`lower_bound', "%5.3f")', `=string(`upper_bound', "%5.3f")']"
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

    * PS range by group — dynamic columns
    local col_width = 13
    local hline_width = 20 + `K' * `col_width'
    display as text "{hline `hline_width'}"
    display as text "Propensity Score Range"
    display as text "{hline `hline_width'}"

    * Header row
    display as text %20s "" _c
    foreach lev of local levels {
        display as text %`col_width's "`lbl_`lev''" _c
    }
    display ""
    display as text "{hline `hline_width'}"

    * N row
    display as text %20s "N" _c
    foreach lev of local levels {
        display as result %`col_width'.0fc `n_group_`lev'' _c
    }
    display ""

    * Min PS row
    display as text %20s "Min PS" _c
    foreach lev of local levels {
        display as result %`col_width'.4f `min_ps_`lev'' _c
    }
    display ""

    * Max PS row
    display as text %20s "Max PS" _c
    foreach lev of local levels {
        display as result %`col_width'.4f `max_ps_`lev'' _c
    }
    display ""
    display as text "{hline `hline_width'}"
    display ""

    * Common support
    display as text "{hline 55}"
    display as text "Common Support Region"
    display as text "{hline 55}"
    display as text "Lower bound:           " as result %10.4f `lower_bound'
    display as text "Upper bound:           " as result %10.4f `upper_bound'
    display as text "Outside support:       " ///
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

    * Warnings (RB-01: propagate every printed warning into a machine-readable
    * finding list; ANY finding forces a non-Good verdict + r(warnings).)
    local _pf ""
    local _pfn = 0
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
        display as text "  Consider: {cmd:psdash support, threshold(0.05)}"
    }
    else {
        display as text _n "Support: " as result "Good" ///
            as text " (" as result %4.1f `pct_outside' as text "% outside support)"
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

                local color_list "navy cranberry forest_green dkorange purple teal maroon olive"
                local plot_cmd ""
                local legend_order ""
                local gnum = 0

                foreach lev of local levels {
                    local gnum = `gnum' + 1
                    local col : word `gnum' of `color_list'
                    if "`col'" == "" local col "gs`gnum'"
                    local lab "`lbl_`lev''"
                    local lev_ps "`group_ps_`lev''"
                    local plot_cmd `"`plot_cmd' (kdensity `lev_ps' if `touse' & `treatment' == `lev', lcolor(`col') lwidth(medthick))"'
                    local legend_order `"`legend_order' `gnum' "`lab'""'
                }

                noisily twoway `plot_cmd', ///
                    legend(order(`legend_order') rows(1) position(6)) ///
                    xtitle("Propensity Score") ytitle("Density") ///
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

    * EXPORT TO EXCEL (multi-group, O1)
    if "`xlsx'" != "" & `_psdash_side_rc' == 0 {
        capture noisily {
            local _xk `""Treatment" "PS variable" "Groups (K)" "Reference" "Total N""'
            local _xv `""`treatment'" "`psvar_label'" "`K'" "`reference_grp'" "`N'""'
            foreach lev of local levels {
                local _xk `"`_xk' "N (group `lev')" "Min PS (group `lev')" "Max PS (group `lev')" "Outside (group `lev')""'
                local _xv `"`_xv' "`n_group_`lev''" "`=string(`min_ps_`lev'',"%6.4f")'" "`=string(`max_ps_`lev'',"%6.4f")'" "`n_outside_`lev''""'
            }
            local _xk `"`_xk' "Lower bound" "Upper bound" "Outside support (N)" "Outside support (%)""'
            local _xv `"`_xv' "`=string(`lower_bound',"%6.4f")'" "`=string(`upper_bound',"%6.4f")'" "`n_outside'" "`=string(`pct_outside',"%5.2f")'""'
            if `has_trimming' {
                local _xk `"`_xk' "Trim lower" "Trim upper" "Trimmed (N)" "Trimmed (%)" "Remaining N""'
                local _xv `"`_xv' "`=string(`trim_lower',"%6.4f")'" "`=string(`trim_upper',"%6.4f")'" "`n_trimmed'" "`=string(`pct_trimmed',"%5.2f")'" "`=`N'-`n_trimmed''""'
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
            }
            return scalar lower_bound = `lower_bound'
            return scalar upper_bound = `upper_bound'
            return scalar n_outside = `n_outside'
            return scalar pct_outside = `pct_outside'
            if `has_trimming' {
                return scalar trim_lower = `trim_lower'
                return scalar trim_upper = `trim_upper'
                return scalar n_trimmed = `n_trimmed'
                return scalar pct_trimmed = `pct_trimmed'
            }
            return scalar n_ps_boundary = `n_ps_boundary'
            return scalar n_ps_near_boundary = `n_ps_near'
            return local treatment "`treatment'"
            return local psvar "`psvar_label'"
            return local levels "`levels'"
            return local reference "`reference_grp'"
            return local estimand "`estimand'"
            return local source "`source'"
        }
        * RB-01 unified findings surface (both modes)
        if "`_support_nfind'" == "" local _support_nfind = 0
        return scalar n_warnings = `_support_nfind'
        return local warnings `"`_support_findings'"'
    }
    if `rc' exit `rc'
end
