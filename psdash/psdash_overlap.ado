*! psdash_overlap Version 1.3.0  2026/06/14
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
         BWIDth(real 0) ///
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
    if "`sheet'" == "" local sheet "Overlap"

    * MARK SAMPLE AND AUTO-DETECT
    tempvar touse ps_auto
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

    * Positivity warnings
    _psdash_pscheck `psvar' if `touse'
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

    if `pct_outside' > 10 {
        display as error "Warning: >10% of observations outside common support region."
    }
    if !missing(`auc') & `auc' > 0.95 {
        display as error "Warning: AUC > 0.95 may indicate overfit or strong separation; verify positivity."
    }

    * Verdict
    if `pct_outside' > 10 {
        display as text _n "Overlap: " as error "WARNING" ///
            as text " (" as result %4.1f `pct_outside' as text "% outside support)"
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
                    if `bwidth' > 0 {
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

    * Positivity warnings are based on the probability of each observation's
    * observed treatment group.
    _psdash_pscheck `obs_ps' if `touse', advice({cmd:psdash support, threshold(0.05)})
    local n_ps_boundary = r(n_ps_boundary)
    local n_ps_near = r(n_ps_near)

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
        multigroup(`multigroup') n(`N')
    foreach lev of local levels {
        local n_group_`lev' = r(n_group_`lev')
        local mean_ps_`lev' = r(mean_ps_`lev')
        local min_ps_`lev' = r(min_ps_`lev')
        local max_ps_`lev' = r(max_ps_`lev')
        local sd_ps_`lev' = r(sd_ps_`lev')
        local n_outside_`lev' = r(n_outside_`lev')
    }
    local overlap_lower = r(overlap_lower)
    local overlap_upper = r(overlap_upper)
    local n_outside = r(n_outside)
    local pct_outside = r(pct_outside)

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

    * PS distribution by group — dynamic columns
    local col_width = 13
    local hline_width = 20 + `K' * `col_width'
    display as text "{hline `hline_width'}"
    display as text "Propensity Score Distribution"
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

    * Mean row
    display as text %20s "Mean" _c
    foreach lev of local levels {
        display as result %`col_width'.4f `mean_ps_`lev'' _c
    }
    display ""

    * SD row
    display as text %20s "SD" _c
    foreach lev of local levels {
        display as result %`col_width'.4f `sd_ps_`lev'' _c
    }
    display ""

    * Min row
    display as text %20s "Min" _c
    foreach lev of local levels {
        display as result %`col_width'.4f `min_ps_`lev'' _c
    }
    display ""

    * Max row
    display as text %20s "Max" _c
    foreach lev of local levels {
        display as result %`col_width'.4f `max_ps_`lev'' _c
    }
    display ""
    display as text "{hline `hline_width'}"
    display ""

    * Common support summary
    display as text "{hline 55}"
    display as text "Common Support Region"
    display as text "{hline 55}"
    display as text "Lower bound:           " as result %10.4f `overlap_lower'
    display as text "Upper bound:           " as result %10.4f `overlap_upper'
    display as text "Outside support:       " ///
        as result %10.0f `n_outside' as text " (" as result %5.2f `pct_outside' as text "%)"
    foreach lev of local levels {
        display as text "  `lbl_`lev'' outside: " as result %10.0f `n_outside_`lev''
    }
    display as text "{hline 55}"

    if `pct_outside' > 10 {
        display as error "Warning: >10% of observations outside common support region."
    }

    * Verdict
    if `pct_outside' > 10 {
        display as text _n "Overlap: " as error "WARNING" ///
            as text " (" as result %4.1f `pct_outside' as text "% outside support)"
        display as text "  Consider: {cmd:psdash support, threshold(0.05)}"
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

                local color_list "navy cranberry forest_green dkorange purple teal maroon olive"
                local plot_cmd ""
                local legend_order ""
                local gnum = 0

                if "`histogram'" != "" {
                    * Histogram version — compute bin width
                    local ps_global_min = 1
                    local ps_global_max = 0
                    foreach lev of local levels {
                        if `min_ps_`lev'' < `ps_global_min' local ps_global_min = `min_ps_`lev''
                        if `max_ps_`lev'' > `ps_global_max' local ps_global_max = `max_ps_`lev''
                    }
                    local ps_range = `ps_global_max' - `ps_global_min'
                    if `ps_range' <= 0 local ps_range = 1
                    local bw_hist = `ps_range' / `bins'
                    if `bw_hist' <= 0 local bw_hist = 0.05

                    foreach lev of local levels {
                        local gnum = `gnum' + 1
                        local col : word `gnum' of `color_list'
                        if "`col'" == "" local col "gs`gnum'"
                        local lab "`lbl_`lev''"
                        local lev_ps "`group_ps_`lev''"
                        local plot_cmd `"`plot_cmd' (histogram `lev_ps' if `touse' & `treatment' == `lev', frequency fcolor(`col'%50) lcolor(`col') width(`bw_hist'))"'
                        local legend_order `"`legend_order' `gnum' "`lab'""'
                    }

                    noisily twoway `plot_cmd', ///
                        legend(order(`legend_order') rows(1) position(6)) ///
                        xtitle("Propensity Score") ytitle("Frequency") ///
                        title(`"`title'"') ///
                        xline(`overlap_lower' `overlap_upper', lcolor(gs8) lpattern(dash)) ///
                        name(`name', replace) ///
                        `graphoptions'
                }
                else {
                    * Density plot version (default)
                    local bw_opt ""
                    if `bwidth' > 0 {
                        local bw_opt "bwidth(`bwidth')"
                    }

                    foreach lev of local levels {
                        local gnum = `gnum' + 1
                        local col : word `gnum' of `color_list'
                        if "`col'" == "" local col "gs`gnum'"
                        local lab "`lbl_`lev''"
                        local lev_ps "`group_ps_`lev''"
                        local plot_cmd `"`plot_cmd' (kdensity `lev_ps' if `touse' & `treatment' == `lev', lcolor(`col') lwidth(medthick) `bw_opt')"'
                        local legend_order `"`legend_order' `gnum' "`lab'""'
                    }

                    noisily twoway `plot_cmd', ///
                        legend(order(`legend_order') rows(1) position(6)) ///
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

    * EXPORT TO EXCEL (multi-group, O1)
    if "`xlsx'" != "" & `_psdash_side_rc' == 0 {
        capture noisily {
            local _xk `""Treatment" "PS variable" "Groups (K)" "Reference" "Total N""'
            local _xv `""`treatment'" "`psvar_label'" "`K'" "`reference_grp'" "`N'""'
            foreach lev of local levels {
                local _xk `"`_xk' "N (group `lev')" "Mean PS (group `lev')" "Min PS (group `lev')" "Max PS (group `lev')""'
                local _xv `"`_xv' "`n_group_`lev''" "`=string(`mean_ps_`lev'',"%6.4f")'" "`=string(`min_ps_`lev'',"%6.4f")'" "`=string(`max_ps_`lev'',"%6.4f")'""'
            }
            local _xk `"`_xk' "Overlap lower" "Overlap upper" "Outside support (N)" "Outside support (%)""'
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
            }
            return scalar overlap_lower = `overlap_lower'
            return scalar overlap_upper = `overlap_upper'
            return scalar n_outside = `n_outside'
            return scalar pct_outside = `pct_outside'
            return scalar n_ps_boundary = `n_ps_boundary'
            return scalar n_ps_near_boundary = `n_ps_near'
            return local treatment "`treatment'"
            return local psvar "`psvar_label'"
            return local levels "`levels'"
            return local reference "`reference_grp'"
            return local estimand "`estimand'"
            return local source "`source'"
        }
    }
    if `rc' exit `rc'
end
