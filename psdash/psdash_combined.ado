*! psdash_combined Version 1.0.1  2026/05/06
*! Combined propensity score diagnostics dashboard
*! Author: Timothy P Copeland
*! Program class: rclass

/*
DESCRIPTION:
    Runs all psdash diagnostic subcommands and combines their output
    into a unified dashboard with a combined graph panel.

    Supports binary (0/1) and multi-group (K >= 2) treatment.

SYNTAX:
    psdash combined [treatment] [psvar] [if] [in] [, options]

Options:
    covariates(varlist) - Covariates for balance assessment
    wvar(varname)       - Weight variable
    threshold(real)     - SMD threshold for balance (default: 0.1)
    nooverlap           - Skip overlap panel
    nobalance           - Skip balance panel
    noweights           - Skip weights panel
    nosupport           - Skip support panel
    saving(string)      - Save combined graph
    scheme(string)      - Graph scheme
    title(string)       - Dashboard title
    reference(string)   - Reference group for multi-group treatment
*/

program define psdash_combined, rclass
    version 16.0
    local _vao = c(varabbrev)
    set varabbrev off
    local _psdash_side_rc = 0

    capture noisily {

    * SYNTAX PARSING
    syntax [anything] [if] [in], ///
        [COVariates(varlist numeric) ///
         Wvar(varname) ///
         THReshold(real 0.1) ///
         NOOverlap ///
         NOBalance ///
         NOWeights ///
         NOSupport ///
         SAVing(string) ///
         SCHeme(string) ///
         TItle(string) ///
         ESTImand(string) ///
         REFerence(string) ///
         PSVars(varlist numeric)]

    * MARK SAMPLE AND AUTO-DETECT
    tempvar touse ps_auto wt_auto
    mark `touse' `if' `in'

    * Pass reference and psvars to detect if specified
    local ref_opt ""
    if "`reference'" != "" {
        local ref_opt "reference(`reference')"
    }
    local psvars_opt ""
    if "`psvars'" != "" {
        local psvars_opt "psvars(`psvars')"
    }

    _psdash_detect `anything' , covariates(`covariates') wvar(`wvar') ///
        samplevar(`touse') estimand(`estimand') ///
        psout(`ps_auto') wout(`wt_auto') getwvar `ref_opt' `psvars_opt'

    local treatment "`_psd_treatment'"
    local psvar "`_psd_psvar'"
    local psvar_auto "`_psd_psvar_auto'"
    local det_covariates "`_psd_covariates'"
    local det_wvar "`_psd_wvar'"
    local wvar_auto "`_psd_wvar_auto'"
    local source "`_psd_source'"
    if "`estimand'" == "" local estimand "`_psd_estimand'"
    local psvar_label "`psvar'"
    if "`psvar_auto'" == "1" local psvar_label "auto-generated"

    * Retrieve multi-group info from detect
    local multigroup "`_psd_multigroup'"
    local K = `_psd_K'
    local levels "`_psd_levels'"
    local reference_grp "`_psd_reference'"

    local combined_psvars ""
    if "`multigroup'" != "0" {
        foreach lev of local levels {
            local this_ps "`_psd_ps_`lev''"
            if "`this_ps'" != "" {
                local combined_psvars "`combined_psvars' `this_ps'"
            }
        }
        if "`combined_psvars'" == "" & "`psvars'" != "" {
            local combined_psvars "`psvars'"
        }
        local combined_psvars : list uniq combined_psvars
    }

    * Use detected covariates if not explicitly provided
    if "`covariates'" == "" & "`det_covariates'" != "" {
        local covariates "`det_covariates'"
    }

    * Use detected weights if not explicitly provided
    if "`wvar'" == "" & "`det_wvar'" != "" {
        local wvar "`det_wvar'"
    }

    if "`multigroup'" != "0" & "`combined_psvars'" != "" {
        markout `touse' `treatment' `combined_psvars'
    }
    else {
        markout `touse' `treatment' `psvar'
    }

    quietly count if `touse'
    if r(N) == 0 {
        display as error "no observations"
        exit 2000
    }

    * Set defaults
    if "`title'" == "" local title "Propensity Score Diagnostics Dashboard"

    * Build scheme option for subcommands
    local scheme_opt ""
    if "`scheme'" != "" {
        local scheme_opt "scheme(`scheme')"
    }

    * Build reference option for subcommands
    local ref_subcmd_opt ""
    if "`reference'" != "" {
        local ref_subcmd_opt "reference(`reference')"
    }

    * Build psvars option for subcommands
    local psvars_subcmd_opt ""
    if "`combined_psvars'" != "" {
        local psvars_subcmd_opt "psvars(`combined_psvars')"
    }
    else if "`psvars'" != "" {
        local psvars_subcmd_opt "psvars(`psvars')"
    }

    * Build if/in for subcommands from touse
    * (pass treatment and psvar explicitly so subcommands don't re-detect)

    * DISPLAY HEADER
    display as text _n as result `"`title'"'
    display as text "Treatment:     " as result "`treatment'"
    if "`multigroup'" != "0" {
        display as text "Groups:        " as result "`K'" as text " (levels: `levels')"
        display as text "Reference:     " as result "`reference_grp'"
    }
    display as text "PS variable:   " as result "`psvar_label'"
    if "`covariates'" != "" {
        local ncovs : word count `covariates'
        display as text "Covariates:    " as result "`ncovs'"
    }
    if "`wvar'" != "" {
        local wvar_label "`wvar'"
        if "`wvar_auto'" == "1" local wvar_label "auto-generated"
        display as text "Weights:       " as result "`wvar_label'"
    }
    display as text "Estimand:      " as result strupper("`estimand'")
    display as text "Source:        " as result "`source'"

    * Track which graphs to combine and verdict status
    local graph_list ""
    local verdict_warnings ""

    * OVERLAP PANEL
    if "`nooverlap'" == "" {
        display as text _n "{bf:=== OVERLAP DIAGNOSTICS ===}"
        psdash_overlap `treatment' `psvar' `if' `in', ///
            name(psdash_c_overlap) `scheme_opt' ///
            title("PS Overlap") estimand(`estimand') ///
            `ref_subcmd_opt' `psvars_subcmd_opt'
        local graph_list "`graph_list' psdash_c_overlap"
        if r(pct_outside) > 10 {
            local verdict_warnings "`verdict_warnings' overlap"
        }
        return add
    }

    * BALANCE PANEL
    if "`nobalance'" == "" & "`covariates'" != "" {
        display as text _n "{bf:=== BALANCE DIAGNOSTICS ===}"
        local wvar_opt ""
        if "`wvar'" != "" local wvar_opt "wvar(`wvar')"
        psdash_balance `treatment' `psvar' `if' `in', ///
            covariates(`covariates') `wvar_opt' ///
            threshold(`threshold') loveplot ///
            name(psdash_c_balance) `scheme_opt' ///
            title("Covariate Balance") estimand(`estimand') ///
            `ref_subcmd_opt' `psvars_subcmd_opt'
        local graph_list "`graph_list' psdash_c_balance"
        if r(n_imbalanced) > 0 {
            local verdict_warnings "`verdict_warnings' balance"
        }
        return add
    }
    else if "`nobalance'" == "" & "`covariates'" == "" {
        display as text _n "note: balance panel skipped (no covariates detected)"
    }

    * WEIGHTS PANEL
    if "`noweights'" == "" {
        display as text _n "{bf:=== WEIGHT DIAGNOSTICS ===}"
        local wvar_opt ""
        if "`wvar'" != "" local wvar_opt "wvar(`wvar')"
        psdash_weights `treatment' `psvar' `if' `in', ///
            `wvar_opt' graph ///
            name(psdash_c_weights) `scheme_opt' estimand(`estimand') ///
            `ref_subcmd_opt' `psvars_subcmd_opt'
        local graph_list "`graph_list' psdash_c_weights"
        if r(ess_pct) < 50 {
            local verdict_warnings "`verdict_warnings' weights"
        }
        return add
    }

    * SUPPORT PANEL
    if "`nosupport'" == "" {
        display as text _n "{bf:=== COMMON SUPPORT ASSESSMENT ===}"
        psdash_support `treatment' `psvar' `if' `in', ///
            name(psdash_c_support) `scheme_opt' ///
            title("Common Support") estimand(`estimand') ///
            `ref_subcmd_opt' `psvars_subcmd_opt'
        local graph_list "`graph_list' psdash_c_support"
        if r(pct_outside) > 10 {
            local verdict_warnings "`verdict_warnings' support"
        }
        return add
    }

    * COMBINE GRAPHS
    local ngraphs : word count `graph_list'

    if `ngraphs' > 0 {
        capture noisily {
            * Determine layout
            if `ngraphs' <= 2 {
                local layout "rows(1)"
            }
            else {
                local layout "rows(2)"
            }

            local combine_scheme ""
            if "`scheme'" != "" {
                local combine_scheme "scheme(`scheme')"
            }

            graph combine `graph_list', ///
                `layout' ///
                title(`"`title'"') ///
                name(psdash_combined, replace) ///
                `combine_scheme'

            if "`saving'" != "" {
                _psdash_graph_export, saving("`saving'")
            }
        }
        local graph_rc = _rc
        if `graph_rc' {
            local _psdash_side_rc = `graph_rc'
        }
    }

    * Overall verdict
    local verdict_warnings = strtrim("`verdict_warnings'")
    if "`verdict_warnings'" == "" {
        display as text "Overall: " as result "PASS"
    }
    else {
        display as text "Overall: " as error "CAUTION" ///
            as text " — see " as result "`verdict_warnings'"
        display as text "  Consider: rerun failing panels individually for targeted diagnostics"
    }

    * Store shared return values
    return local treatment "`treatment'"
    return local psvar "`psvar_label'"
    return local estimand "`estimand'"
    return local source "`source'"
    if "`multigroup'" != "0" {
        return local levels "`levels'"
        return local reference "`reference_grp'"
        return scalar K = `K'
    }

    }
    local rc = _rc
    set varabbrev `_vao'
    if `rc' == 0 & `_psdash_side_rc' {
        local rc = `_psdash_side_rc'
    }
    if `rc' exit `rc'
end
