*! psdash_combined Version 1.3.0  2026/06/14
*! Combined propensity score diagnostics dashboard
*! Author: Timothy P Copeland, Karolinska Institutet
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
         OVERLAPmax(real 10) ///
         ESSmin(real 50) ///
         IMBALmax(integer 0) ///
         NOOverlap ///
         NOBalance ///
         NOWeights ///
         NOSupport ///
         DRYrun ///
         REPort(string) ///
         SAVing(string) ///
         SCHeme(string) ///
         TItle(string) ///
         ESTImand(string) ///
         REFerence(string) ///
         PSVars(varlist numeric)]

    * Validate verdict-threshold options (U2)
    if `overlapmax' < 0 | `overlapmax' > 100 {
        display as error "overlapmax() must be between 0 and 100"
        exit 198
    }
    if `essmin' < 0 | `essmin' > 100 {
        display as error "essmin() must be between 0 and 100"
        exit 198
    }
    if `imbalmax' < 0 {
        display as error "imbalmax() must be non-negative"
        exit 198
    }
    if `"`report'"' != "" {
        _psdash_validate_path, path(`"`report'"') option(report) extension(xlsx)
    }

    * MARK SAMPLE AND AUTO-DETECT
    tempvar touse ps_auto wt_auto
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

    * DRY RUN — report auto-detection and exit without running panels (U1)
    if "`dryrun'" != "" {
        psdash_detect `anything' `if' `in', covariates(`covariates') ///
            wvar(`wvar') estimand(`estimand') `ref_opt' `psvars_opt'
        return add
        set varabbrev `_vao'   // exit below bypasses the post-block restore
        exit
    }

    _psdash_detect `anything' , covariates(`covariates') wvar(`wvar') ///
        samplevar(`touse') estimand(`estimand') ///
        psout(`ps_auto') wout(`wt_auto') getwvar ///
        allowlongitudinal `ref_opt' `psvars_opt'

    local treatment "`_psd_treatment'"
    local psvar "`_psd_psvar'"
    local psvar_auto "`_psd_psvar_auto'"
    local det_covariates "`_psd_covariates'"
    local det_wvar "`_psd_wvar'"
    local wvar_auto "`_psd_wvar_auto'"
    local source "`_psd_source'"
    local method "`_psd_method'"
    local contract_version "`_psd_contract_version'"
    local iivw_component "`_psd_iivw_component'"
    local iivw_treatment_wvar "`_psd_iivw_treatment_wvar'"
    local iivw_final_wvar "`_psd_iivw_final_wvar'"
    local iivw_visit_wvar "`_psd_iivw_visit_wvar'"
    local longitudinal "`_psd_longitudinal'"
    local idvar "`_psd_id'"
    local period "`_psd_period'"
    local regime "`_psd_regime'"
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
    if "`source'" == "iivw" & "`iivw_component'" == "" {
        local iivw_component "treatment"
    }

    if "`longitudinal'" == "1" {
        if "`title'" == "" local title "Longitudinal Propensity Score Diagnostics"
        local id_opt ""
        if "`idvar'" != "" local id_opt `"id("`idvar'")"'
        local method_opt ""
        if "`method'" != "" local method_opt `"method("`method'")"'
        local contract_opt ""
        if "`contract_version'" != "" {
            local contract_opt `"contract("`contract_version'")"'
        }
        local regime_opt ""
        if "`regime'" != "" local regime_opt `"regime("`regime'")"'
        local source_opt ""
        if "`source'" != "" local source_opt `"source("`source'")"'
        _psdash_ltmle_diagnostics, treatment(`treatment') ///
            period(`period') psvar("`psvar'") wvar("`wvar'") ///
            samplevar(`touse') `id_opt' ///
            estimand(`"`estimand'"') `regime_opt' ///
            `method_opt' `contract_opt' `source_opt' ///
            title(`"`title'"')
        return add
        return local treatment "`treatment'"
        return local psvar "`psvar'"
        return local wvar "`wvar'"
        return local estimand "`estimand'"
        return local source "`source'"
        return local method "`method'"
        return local contract_version "`contract_version'"
        return local id "`idvar'"
        return local period "`period'"
        return local regime "`regime'"
        return scalar longitudinal = 1
        set varabbrev `_vao'   // exit below bypasses the post-block restore
        exit
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

    * Build per-panel report() pass-through (O2): one workbook, one sheet/panel
    local rep_overlap ""
    local rep_balance ""
    local rep_weights ""
    local rep_support ""
    if `"`report'"' != "" {
        local rep_overlap `"xlsx("`report'") sheet(Overlap)"'
        local rep_balance `"xlsx("`report'") sheet(Balance)"'
        local rep_weights `"xlsx("`report'") sheet(Weights)"'
        local rep_support `"xlsx("`report'") sheet(Support)"'
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
    local source_label "`source'"
    local component_label ""
    if "`source'" == "iivw" {
        local source_label "iivw treatment model"
        local component_label "treatment IPTW (`wvar')"
    }
    display as text "Source:        " as result "`source_label'"
    if "`component_label'" != "" {
        display as text "Weight component: " as result "`component_label'"
    }

    * Track which graphs to combine and verdict status
    local graph_list ""
    local verdict_warnings ""

    * OVERLAP PANEL
    if "`nooverlap'" == "" {
        display as text _n "{bf:=== OVERLAP DIAGNOSTICS ===}"
        psdash_overlap `treatment' `psvar' `if' `in', ///
            name(psdash_c_overlap) `scheme_opt' ///
            title("PS Overlap") estimand(`estimand') ///
            `ref_subcmd_opt' `psvars_subcmd_opt' `rep_overlap'
        local graph_list "`graph_list' psdash_c_overlap"
        if r(pct_outside) > `overlapmax' {
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
            `ref_subcmd_opt' `psvars_subcmd_opt' `rep_balance'
        local graph_list "`graph_list' psdash_c_balance"
        if r(n_imbalanced) > `imbalmax' {
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
            `ref_subcmd_opt' `psvars_subcmd_opt' `rep_weights'
        local graph_list "`graph_list' psdash_c_weights"
        if r(ess_pct) < `essmin' {
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
            `ref_subcmd_opt' `psvars_subcmd_opt' `rep_support'
        local graph_list "`graph_list' psdash_c_support"
        if r(pct_outside) > `overlapmax' {
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
    local n_warnings : word count `verdict_warnings'
    if "`verdict_warnings'" == "" {
        local verdict "PASS"
        display as text "Overall: " as result "PASS"
    }
    else {
        local verdict "CAUTION"
        display as text "Overall: " as error "CAUTION" ///
            as text " — see " as result "`verdict_warnings'"
        display as text "  Consider: rerun failing panels individually for targeted diagnostics"
    }

    * REPORT WORKBOOK summary sheet (O2)
    if `"`report'"' != "" & `_psdash_side_rc' == 0 {
        capture noisily {
            local _rk `""Treatment" "PS variable" "Estimand" "Source" "Verdict" "Warnings (N)" "Warnings" "overlapmax" "essmin" "imbalmax""'
            local _rv `""`treatment'" "`psvar_label'" "`=strupper("`estimand'")'" "`source'" "`verdict'" "`n_warnings'" "`verdict_warnings'" "`overlapmax'" "`essmin'" "`imbalmax'""'
            _psdash_export_kv, xlsx("`report'") sheet("Summary") ///
                title("Propensity Score Diagnostics — Summary") keys(`_rk') vals(`_rv')
        }
        local _rep_rc = _rc
        if `_rep_rc' {
            local _psdash_side_rc = `_rep_rc'
        }
        else {
            display as text _n "Report workbook written to: " as result "`report'"
        }
    }

    * Store shared return values
    return local verdict "`verdict'"
    return scalar n_warnings = `n_warnings'
    return local warnings "`verdict_warnings'"
    if `"`report'"' != "" {
        return local report "`report'"
    }
    return scalar overlapmax = `overlapmax'
    return scalar essmin = `essmin'
    return scalar imbalmax = `imbalmax'
    return local treatment "`treatment'"
    return local psvar "`psvar_label'"
    return local wvar "`wvar'"
    return local estimand "`estimand'"
    return local source "`source'"
    if "`iivw_component'" != "" {
        return local iivwcomponent "`iivw_component'"
    }
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
