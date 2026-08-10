*! psdash_overlap Version 1.6.3  2026/08/10
*! Propensity score overlap diagnostics
*! Author: Timothy P Copeland, Karolinska Institutet
*! Program class: rclass

/*
DESCRIPTION:
    Visualizes propensity score distribution by treatment group to assess
    overlap (positivity). Produces density plots or histograms and reports
    summary statistics on PS distribution and overlap region.

    Supports binary (0/1) and multi-group (K >= 2) treatment.

SYNTAX:
    psdash overlap [treatment] [psvar] [if] [in] [, options]

Options:
    covariates(varlist) - Covariates (for auto-detection context)
    bins(integer)       - Number of histogram bins (default: 30)
    histogram           - Use histograms instead of density plots
    bwidth(real)        - Bandwidth for kernel density (default: auto)
    nograph             - Suppress graph, display table only
    saving(string)      - Save graph to file
    scheme(string)      - Graph scheme
    graphoptions(string)- Additional twoway options
    title(string)       - Graph/output title
    name(string)        - Graph name (default: psdash_overlap)
    reference(string)   - Reference group for multi-group treatment

STORED RESULTS (binary):
    r(N)                    - Total observations
    r(N_treated)            - Treated observations
    r(N_control)            - Control observations
    r(mean_ps_treated)      - Mean PS in treated group
    r(mean_ps_control)      - Mean PS in control group
    r(min_ps_treated)       - Min PS in treated group
    r(max_ps_treated)       - Max PS in treated group
    r(min_ps_control)       - Min PS in control group
    r(max_ps_control)       - Max PS in control group
    r(overlap_lower)        - Lower bound of overlap region
    r(overlap_upper)        - Upper bound of overlap region
    r(n_outside)            - Observations outside overlap
    r(pct_outside)          - Percentage outside overlap
    r(treatment)            - Treatment variable name
    r(psvar)                - PS variable name

STORED RESULTS (multi-group):
    r(N)                    - Total observations
    r(K)                    - Number of treatment groups
    r(N_group_<lev>)        - Per-group observation count
    r(mean_ps_group_<lev>)  - Per-group mean PS
    r(min_ps_group_<lev>)   - Per-group min PS
    r(max_ps_group_<lev>)   - Per-group max PS
    r(overlap_lower)        - Lower bound of common overlap region
    r(overlap_upper)        - Upper bound of common overlap region
    r(n_outside)            - Observations outside overlap
    r(pct_outside)          - Percentage outside overlap
    r(treatment)            - Treatment variable name
    r(levels)               - Space-separated treatment levels
    r(reference)            - Reference group level
*/

program define psdash_overlap, rclass
    version 16.0
    local _vao = c(varabbrev)
    set varabbrev off
    local _psdash_side_rc = 0
    local _psdash_return_mode ""

    capture noisily {

    * SYNTAX PARSING
    syntax [anything] [if] [in], ///
        [COVariates(varlist numeric) ///
         bins(integer 30) ///
         HISTogram ///
         BWIDth(string) ///
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
         GPSFLOOR(real 0.01) ///
         PSVars(varlist numeric)]

    * Validate gpsfloor() (multi-arm practical positivity floor on min_j e_j(X));
    * mirrors psdash support so the two panels are configured the same way.
    if `gpsfloor' <= 0 | `gpsfloor' >= 1 {
        display as error "gpsfloor() must be strictly between 0 and 1"
        exit 198
    }

    if "`xlsx'" != "" {
        _psdash_validate_path, path(`"`xlsx'"') option(xlsx) extension(xlsx)
    }
    if "`sheet'" == "" local sheet "Overlap"
    if "`bwidth'" != "" {
        capture confirm number `bwidth'
        if _rc | real("`bwidth'") <= 0 {
            display as error "bwidth() must be a positive number"
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
        * Mark out missing values
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

    * Validate histogram bins
    if `bins' <= 0 {
        display as error "bins() must be positive"
        exit 198
    }

    * Count boundary/near-boundary scores here; the panel below owns display
    * and the machine-readable warning surface.
    _psdash_pscheck `psvar' if `touse', nowarn
    local n_ps_boundary = r(n_ps_boundary)
    local n_ps_near = r(n_ps_near)

    * Set defaults
    if "`title'" == "" local title "Propensity Score Overlap"
    if "`name'" == "" local name "psdash_overlap"

    * CALCULATE OVERLAP STATISTICS
    _psdash_support_stats, treatment(`treatment') samplevar(`touse') ///
        psvar(`psvar') n(`N')
    local n_treated = r(n_treated)
    local n_control = r(n_control)
    local mean_ps_t = r(mean_ps_t)
    local mean_ps_c = r(mean_ps_c)
    local min_ps_t = r(min_ps_t)
    local min_ps_c = r(min_ps_c)
    local max_ps_t = r(max_ps_t)
    local max_ps_c = r(max_ps_c)
    local sd_ps_t = r(sd_ps_t)
    local sd_ps_c = r(sd_ps_c)
    local overlap_lower = r(overlap_lower)
    local overlap_upper = r(overlap_upper)
    local n_outside = r(n_outside)
    local pct_outside = r(pct_outside)
    local n_outside_t = r(n_outside_t)
    local n_outside_c = r(n_outside_c)

    * C-STATISTIC (AUC)
    local auc = .
    capture quietly roctab `treatment' `psvar' if `touse'
    if _rc == 0 {
        local auc = r(area)
    }

    * DISPLAY OUTPUT
    display as text _n `"`title'"'
    display as text "Treatment:         " as result "`treatment'"
    display as text "PS variable:       " as result "`psvar_label'"
    if "`source'" != "manual" {
        display as text "Source:            " as result "`source'"
    }
    display ""

    * PS distribution by group
    display as text "{hline 70}"
    display as text "Propensity Score Distribution"
    display as text "{hline 70}"
    display as text %20s "" %15s "Treated" %15s "Control"
    display as text "{hline 70}"
    display as text %20s "N" ///
        as result %15.0fc `n_treated' %15.0fc `n_control'
    display as text %20s "Mean" ///
        as result %15.4f `mean_ps_t' %15.4f `mean_ps_c'
    display as text %20s "SD" ///
        as result %15.4f `sd_ps_t' %15.4f `sd_ps_c'
    display as text %20s "Min" ///
        as result %15.4f `min_ps_t' %15.4f `min_ps_c'
    display as text %20s "Max" ///
        as result %15.4f `max_ps_t' %15.4f `max_ps_c'
    display as text "{hline 70}"
    display ""

    * Common support summary
    display as text "{hline 55}"
    display as text "Common Support Region"
    display as text "{hline 55}"
    display as text "Lower bound:           " as result %10.4f `overlap_lower'
    display as text "Upper bound:           " as result %10.4f `overlap_upper'
    display as text "Outside support:       " ///
        as result %10.0f `n_outside' as text " (" as result %5.2f `pct_outside' as text "%)"
    display as text "  Treated outside:     " as result %10.0f `n_outside_t'
    display as text "  Control outside:     " as result %10.0f `n_outside_c'
    if !missing(`auc') {
        display as text "C-statistic (AUC):     " as result %10.4f `auc'
    }
    display as text "{hline 55}"

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
        display as error "Warning: >10% of observations outside common support region."
        local _pf `"`_pf' | `=string(`pct_outside',"%4.1f")'% outside common support"'
        local ++_pfn
    }
    * AUC is orientation-sensitive: discrimination is max(AUC, 1-AUC), so a
    * reversed PS (AUC~0.02) is as much a separation signal as AUC~0.98 (B7/B8).
    if !missing(`auc') {
        local _disc = max(`auc', 1 - `auc')
        if `_disc' > 0.95 {
            display as error "Warning: near-separation (discrimination = `=string(`_disc',"%4.2f")', AUC = `=string(`auc',"%4.2f")'); verify positivity."
            local _pf `"`_pf' | near-separation (discrimination `=string(`_disc',"%4.2f")')"'
            local ++_pfn
        }
        if `auc' < 0.5 & `_disc' > 0.55 {
            display as error "Warning: PS orientation appears reversed (AUC = `=string(`auc',"%4.2f")' < 0.5); check treatment/PS mapping."
            local _pf `"`_pf' | PS orientation reversed (AUC `=string(`auc',"%4.2f")')"'
            local ++_pfn
        }
    }
    local _pf = strtrim("`_pf'")
    if substr("`_pf'", 1, 1) == "|" local _pf = strtrim(substr("`_pf'", 2, .))
    local _overlap_findings `"`_pf'"'
    local _overlap_nfind = `_pfn'

    * Verdict (WARNING on ANY finding)
    if `_pfn' > 0 {
        display as text _n "Overlap: " as error "WARNING" ///
            as text " (" as result %4.1f `pct_outside' as text "% outside support; " ///
            as result `_pfn' as text " finding(s))"
        display as text "  Consider: {cmd:psdash support, crump} or {cmd:psdash support, threshold(0.05)}"
    }
    else {
        display as text _n "Overlap: " as result "Good" ///
            as text " (" as result %4.1f `pct_outside' as text "% outside support)"
    }

    * GRAPH
    if "`nograph'" == "" {
        capture noisily {
            quietly {
                * Prepend scheme to graphoptions if specified
                if "`scheme'" != "" {
                    local graphoptions `"scheme(`scheme') `graphoptions'"'
                }

                if "`histogram'" != "" {
                    * Histogram version
                    local ps_range = max(`max_ps_t', `max_ps_c') - min(`min_ps_t', `min_ps_c')
                    if `ps_range' <= 0 local ps_range = 1
                    local bw_hist = `ps_range' / `bins'
                    if `bw_hist' <= 0 local bw_hist = 0.05

                    noisily twoway ///
                        (histogram `psvar' if `touse' & `treatment' == 1, ///
                            frequency fcolor(navy%50) lcolor(navy) width(`bw_hist')) ///
                        (histogram `psvar' if `touse' & `treatment' == 0, ///
                            frequency fcolor(cranberry%50) lcolor(cranberry) width(`bw_hist')), ///
                        legend(order(1 "Treated" 2 "Control") rows(1) position(6)) ///
                        xtitle("Propensity Score") ytitle("Frequency") ///
                        title(`"`title'"') ///
                        xline(`overlap_lower' `overlap_upper', lcolor(gs8) lpattern(dash)) ///
                        name(`name', replace) ///
                        `graphoptions'
                }
                else {
                    * Density plot version (default)
                    local bw_opt ""
                    if "`bwidth'" != "" {
                        local bw_opt "bwidth(`bwidth')"
                    }

                    noisily twoway ///
                        (kdensity `psvar' if `touse' & `treatment' == 1, ///
                            lcolor(navy) lwidth(medthick) `bw_opt') ///
                        (kdensity `psvar' if `touse' & `treatment' == 0, ///
                            lcolor(cranberry) lwidth(medthick) `bw_opt'), ///
                        legend(order(1 "Treated" 2 "Control") rows(1) position(6)) ///
                        xtitle("Propensity Score") ytitle("Density") ///
                        title(`"`title'"') ///
                        xline(`overlap_lower' `overlap_upper', lcolor(gs8) lpattern(dash)) ///
                        name(`name', replace) ///
                        `graphoptions'
                }

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
            local _xk `""Treatment" "PS variable" "Total N" "N (treated)" "N (control)" "Mean PS (treated)" "Mean PS (control)" "Min PS (treated)" "Max PS (treated)" "Min PS (control)" "Max PS (control)" "Overlap lower" "Overlap upper" "Outside support (N)" "Outside support (%)""'
            local _xv `""`treatment'" "`psvar_label'" "`N'" "`n_treated'" "`n_control'" "`=string(`mean_ps_t',"%6.4f")'" "`=string(`mean_ps_c',"%6.4f")'" "`=string(`min_ps_t',"%6.4f")'" "`=string(`max_ps_t',"%6.4f")'" "`=string(`min_ps_c',"%6.4f")'" "`=string(`max_ps_c',"%6.4f")'" "`=string(`overlap_lower',"%6.4f")'" "`=string(`overlap_upper',"%6.4f")'" "`n_outside'" "`=string(`pct_outside',"%5.2f")'""'
            if !missing(`auc') {
                local _xk `"`_xk' "C-statistic (AUC)""'
                local _xv `"`_xv' "`=string(`auc',"%6.4f")'""'
            }
            _psdash_export_kv, xlsx("`xlsx'") sheet("`sheet'") ///
                title("`title'") keys(`_xk') vals(`_xv')
            noisily display as text _n "Overlap table exported to: " as result "`xlsx'"
        }
        local xlsx_rc = _rc
        if `xlsx_rc' local _psdash_side_rc = `xlsx_rc'
    }

    local _psdash_return_mode "binary"

    }
    else {
    * MULTI-GROUP PATH (K >= 2 with non-0/1 values)

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

    * Validate histogram bins
    if `bins' <= 0 {
        display as error "bins() must be positive"
        exit 198
    }

    tempvar obs_ps
    quietly gen double `obs_ps' = . if `touse'
    foreach lev of local levels {
        local lev_ps "`group_ps_`lev''"
        quietly replace `obs_ps' = `lev_ps' if `treatment' == `lev' & `touse'
    }

    * Set defaults
    if "`title'" == "" local title "Propensity Score Overlap"
    if "`name'" == "" local name "psdash_overlap"

    * Get group labels
    foreach lev of local levels {
        local lbl_`lev' : label (`treatment') `lev'
        if "`lbl_`lev''" == "" local lbl_`lev' "Group `lev'"
    }

    * CALCULATE OVERLAP STATISTICS
    local _mg_group_psvars ""
    foreach lev of local levels {
        local _mg_group_psvars "`_mg_group_psvars' `group_ps_`lev''"
    }
    _psdash_support_stats, treatment(`treatment') samplevar(`touse') ///
        obsps(`obs_ps') levels(`levels') grouppsvars(`_mg_group_psvars') ///
        multigroup(`multigroup') n(`N') gpsfloor(`gpsfloor')
    foreach lev of local levels {
        local n_group_`lev' = r(n_group_`lev')
        local mean_ps_`lev' = r(mean_ps_`lev')
        local min_ps_`lev' = r(min_ps_`lev')
        local max_ps_`lev' = r(max_ps_`lev')
        local sd_ps_`lev' = r(sd_ps_`lev')
        local n_outside_`lev' = r(n_outside_`lev')
        local min_gps_`lev' = r(min_gps_`lev')
    }
    local overlap_lower = r(overlap_lower)
    local overlap_upper = r(overlap_upper)
    local n_outside = r(n_outside)
    local pct_outside = r(pct_outside)
    * RB-12: full-vector GPS positivity. The engine has always computed these,
    * but this panel discarded them and judged multi-arm overlap on the
    * observed-arm min-max rule alone -- so a unit with a healthy observed-arm
    * probability and a near-zero probability of an UNRECEIVED arm produced a
    * "Good" verdict on exactly the failure Li & Li (2019) Assumption 2 and
    * McCaffrey et al. (2013) exist to catch. Same diagnostic as psdash support.
    local min_gps = r(min_gps)
    local n_gps_violate = r(n_gps_violate)
    local pct_gps_violate = r(pct_gps_violate)
    local n_ps_boundary = r(n_ps_boundary)
    local n_ps_near = r(n_ps_near)
    tempname gps_means
    matrix `gps_means' = r(gps_means)

    * AUC: skip for K > 2 (roctab is binary-only)
    local auc = .

    * DISPLAY OUTPUT
    display as text _n `"`title'"'
    display as text "Treatment:         " as result "`treatment'" as text " (`K' groups)"
    display as text "PS variable:       " as result "`psvar_label'"
    display as text "Reference group:   " as result "`reference_grp'"
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
    * arm score. Same caveat psdash support prints for this table.)
    display as text "{hline 55}"
    display as text "Observed-arm PS Overlap (informational)"
    display as text "{hline 55}"
    display as text "Lower bound:           " as result %10.4f `overlap_lower'
    display as text "Upper bound:           " as result %10.4f `overlap_upper'
    display as text "Outside overlap:       " ///
        as result %10.0f `n_outside' as text " (" as result %5.2f `pct_outside' as text "%)"
    foreach lev of local levels {
        display as text "  `lbl_`lev'' outside: " as result %10.0f `n_outside_`lev''
    }
    display as text "{hline 55}"

    * Warnings (RB-01: propagate every printed warning into a machine-readable
    * finding list; ANY finding forces a non-Good verdict + r(warnings).)
    local _pf ""
    local _pfn = 0
    * PRIMARY multi-arm finding: full-vector GPS positivity violation (RB-12).
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
    local _overlap_findings `"`_pf'"'
    local _overlap_nfind = `_pfn'

    * Verdict (WARNING on ANY finding)
    if `_pfn' > 0 {
        display as text _n "Overlap: " as error "WARNING" ///
            as text " (" as result %4.1f `pct_gps_violate' as text "% below GPS floor; " ///
            as result `_pfn' as text " finding(s))"
        display as text "  Consider: {cmd:psdash support, threshold(0.05)}"
    }
    else {
        display as text _n "Overlap: " as result "No GPS-floor violation" ///
            as text " (" as result %4.1f `pct_gps_violate' as text "% below " ///
            as result %5.3f `gpsfloor' as text ")"
    }

    * GRAPH
    if "`nograph'" == "" {
        local _hist_opt ""
        if "`histogram'" != "" local _hist_opt "histogram"
        local _bwidth_opt ""
        if "`bwidth'" != "" local _bwidth_opt "bwidth(`bwidth')"
        local _saving_opt ""
        if `"`saving'"' != "" local _saving_opt `"saving(`"`saving'"')"'
        local _scheme_opt ""
        if "`scheme'" != "" local _scheme_opt "scheme(`scheme')"
        local _graphoptions_opt ""
        if `"`graphoptions'"' != "" {
            local _graphoptions_opt `"graphoptions(`"`graphoptions'"')"'
        }

        capture noisily _psdash_mgps_graph, treatment(`treatment') ///
            samplevar(`touse') psvars(`_mg_group_psvars') levels(`levels') ///
            name(`name') gpsfloor(`gpsfloor') bins(`bins') ///
            title(`"`title'"') `_hist_opt' `_bwidth_opt' `_saving_opt' ///
            `_scheme_opt' `_graphoptions_opt'
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
                local _xk `"`_xk' "N (group `lev')" "Mean PS (group `lev')" "Min PS (group `lev')" "Max PS (group `lev')""'
                local _xv `"`_xv' "`n_group_`lev''" "`=string(`mean_ps_`lev'',"%6.4f")'" "`=string(`min_ps_`lev'',"%6.4f")'" "`=string(`max_ps_`lev'',"%6.4f")'""'
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
            local _xv `"`_xv' "`=string(`overlap_lower',"%6.4f")'" "`=string(`overlap_upper',"%6.4f")'" "`n_outside'" "`=string(`pct_outside',"%5.2f")'""'
            _psdash_export_kv, xlsx("`xlsx'") sheet("`sheet'") ///
                title("`title'") keys(`_xk') vals(`_xv')
            noisily display as text _n "Overlap table exported to: " as result "`xlsx'"
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
            return scalar mean_ps_treated = `mean_ps_t'
            return scalar mean_ps_control = `mean_ps_c'
            return scalar min_ps_treated = `min_ps_t'
            return scalar max_ps_treated = `max_ps_t'
            return scalar min_ps_control = `min_ps_c'
            return scalar max_ps_control = `max_ps_c'
            return scalar overlap_lower = `overlap_lower'
            return scalar overlap_upper = `overlap_upper'
            return scalar n_outside = `n_outside'
            return scalar pct_outside = `pct_outside'
            if !missing(`auc') return scalar auc = `auc'
            return scalar n_ps_boundary = `n_ps_boundary'
            return scalar n_ps_near_boundary = `n_ps_near'
            return local treatment "`treatment'"
            return local psvar "`psvar_label'"
            return local estimand "`estimand'"
            return local source "`source'"
        }
        else if "`_psdash_return_mode'" == "multigroup" {
            return scalar N = `N'
            return scalar K = `K'
            foreach lev of local levels {
                return scalar N_group_`lev' = `n_group_`lev''
                return scalar mean_ps_group_`lev' = `mean_ps_`lev''
                return scalar min_ps_group_`lev' = `min_ps_`lev''
                return scalar max_ps_group_`lev' = `max_ps_`lev''
                return scalar min_gps_group_`lev' = `min_gps_`lev''
            }
            return scalar overlap_lower = `overlap_lower'
            return scalar overlap_upper = `overlap_upper'
            return scalar n_outside = `n_outside'
            return scalar pct_outside = `pct_outside'
            * RB-12: full-vector GPS positivity, same keys as psdash support
            return scalar min_gps = `min_gps'
            return scalar n_gps_violate = `n_gps_violate'
            return scalar pct_gps_violate = `pct_gps_violate'
            return scalar gps_floor = `gpsfloor'
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
        if "`_overlap_nfind'" == "" local _overlap_nfind = 0
        return scalar n_warnings = `_overlap_nfind'
        return local warnings `"`_overlap_findings'"'

        * RB-05 estimation-sample exclusion ledger (teffects only)
        if "`n_excluded'" != "" {
            return scalar n_excluded = `n_excluded'
            return scalar n_estimation = `n_estimation'
        }
    }
    if `rc' exit `rc'
end
