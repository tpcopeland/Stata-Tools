*! psdash_combined Version 1.9.0  2026/10/29
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
    supportgraph        - Binary: show the support density panel instead of
                          the Diagnostic Summary scorecard (earlier layout)
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
        [COVariates(varlist numeric fv) ///
         Wvar(varname) ///
         THReshold(real 0.1) ///
         OVERLAPmax(real 10) ///
         ESSmin(real 50) ///
         IMBALmax(integer 0) ///
         NOOverlap ///
         NOBalance ///
         NOWeights ///
         NOSupport ///
         SUPPORTGraph ///
         DRYrun ///
         REPort(string) ///
         SAVing(string) ///
         SCHeme(string) ///
         TItle(string) ///
         ESTImand(string) ///
         REFerence(string) ///
         GPSFLOOR(real 0.01) ///
         PSVars(varlist numeric)]

    * RB-12: the multi-arm practical-positivity floor is now used by BOTH the
    * overlap and support panels, so the dashboard has to be able to set it;
    * previously it was reachable only by calling psdash support directly.
    if `gpsfloor' <= 0 | `gpsfloor' >= 1 {
        display as error "gpsfloor() must be strictly between 0 and 1"
        exit 198
    }
    local gpsfloor_subcmd_opt "gpsfloor(`gpsfloor')"

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
    * Accept twoway-style saving(f, replace) gracefully
    _psdash_strip_replace, option(saving) value(`"`saving'"')
    local saving `"`r(value)'"'

    mark `touse' `if' `in'  // validator-note: mark+markout pattern is equivalent to marksample
    quietly count if `touse'
    local N_requested = r(N)

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

    * Only the weights panel needs a weight at dashboard scope. Balance can
    * generate and validate its own weight after overlap/support have inspected
    * the full PS sample.
    local _getwvar_opt ""
    if "`noweights'" == "" local _getwvar_opt "getwvar"
    _psdash_detect `anything' , covariates(`covariates') wvar(`wvar') ///
        samplevar(`touse') estimand(`estimand') ///
        psout(`ps_auto') wout(`wt_auto') `_getwvar_opt' ///
        allowlongitudinal `ref_opt' `psvars_opt'

    local treatment "`_psd_treatment'"
    local psvar "`_psd_psvar'"
    local psvar_auto "`_psd_psvar_auto'"
    local det_covariates "`_psd_covariates'"
    local det_wvar "`_psd_wvar'"
    local wvar_auto "`_psd_wvar_auto'"
    local source "`_psd_source'"
    * RB-05: estimation-sample exclusion ledger (set by detect for teffects)
    local n_estimation "`_psd_n_estimation'"
    local n_excluded "`_psd_n_excluded'"
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
    local riskvar "`_psd_riskvar'"
    local weight_role "`_psd_weight_role'"
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
        if "`nooverlap'`nobalance'`noweights'`nosupport'`supportgraph'" != "" | ///
                `"`report'"' != "" | `"`saving'"' != "" | ///
                `"`scheme'"' != "" | `threshold' != 0.1 | ///
                `overlapmax' != 10 | `essmin' != 50 | ///
                `imbalmax' != 0 | `gpsfloor' != 0.01 {
            display as error "cross-sectional panel and output options are unavailable for longitudinal diagnostics"
            display as error "  omit panel suppression, supportgraph, report(), saving(), scheme(), and custom thresholds"
            exit 198
        }
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
        local risk_opt ""
        if "`riskvar'" != "" local risk_opt `"riskvar("`riskvar'")"'
        local wrole_opt ""
        if "`weight_role'" != "" local wrole_opt `"weightrole("`weight_role'")"'
        _psdash_ltmle_diagnostics, treatment(`treatment') ///
            period(`period') psvar("`psvar'") wvar("`wvar'") ///
            samplevar(`touse') `id_opt' ///
            estimand(`"`estimand'"') `regime_opt' ///
            `method_opt' `contract_opt' `source_opt' ///
            `risk_opt' `wrole_opt' title(`"`title'"')
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
    if "`covariates'" != "" {
        fvrevar `covariates' if `touse'
        local _combined_covvars "`r(varlist)'"
        markout `touse' `_combined_covvars'
    }

    * A generated weight is not part of the overlap/support sample. When the
    * weights panel was requested, however, undefined own-arm weights are a
    * hard failure and must be found before any dashboard panel runs.
    if "`wvar_auto'" == "1" & "`noweights'" == "" {
        quietly count if `touse' & missing(`wvar')
        local _n_wt_undefined = r(N)
        if `_n_wt_undefined' > 0 {
            display as error "`_n_wt_undefined' observation(s) have an undefined propensity-based weight"
            display as error "  the requested dashboard cannot diagnose weights on a reduced sample"
            exit 459
        }
    }
    if "`wvar'" != "" & "`wvar_auto'" != "1" & ///
            ("`noweights'" == "" | ("`nobalance'" == "" & "`covariates'" != "")) {
        markout `touse' `wvar'
    }

    quietly count if `touse'
    if r(N) == 0 {
        display as error "no observations"
        exit 2000
    }
    local N_analysis = r(N)
    local N_common_excluded = `N_requested' - `N_analysis'

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
    local compact_subcmd_opt ""
    if "`multigroup'" != "0" local compact_subcmd_opt "compact"

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
    * RB-01 unified findings aggregation: every panel finding is collected here,
    * and ANY finding (or zero executed panels) forces a non-PASS verdict.
    local _all_findings ""
    local _total_nfind = 0
    local _panels_run = 0
    * Binary dashboards replace the support density (a near-copy of the overlap
    * density) with a Diagnostic Summary scorecard unless supportgraph is
    * given. The support analysis always runs; only its graph is dropped. With
    * nooverlap the support graph takes the overlap slot so the bounds stay
    * visible. Scorecard rows (_sc_*) are built from each panel's r(), captured
    * before any later command can clobber it.
    local _sc_show = ("`multigroup'" == "0" & "`supportgraph'" == "")
    if "`multigroup'" != "0" & "`supportgraph'" != "" & "`nosupport'" == "" {
        display as text "note: supportgraph ignored: the multi-group dashboard always draws the support panel"
    }
    local _sc_rows ""
    local _sc_support_graph = 1
    if `_sc_show' & "`nooverlap'" == "" local _sc_support_graph = 0

    * OVERLAP PANEL
    if "`nooverlap'" == "" {
        local _nf0 = `_total_nfind'
        local _sc_ft ""
        display as text _n "{bf:=== OVERLAP DIAGNOSTICS ===}"
        local _panel_cmd `"psdash_overlap `treatment' `psvar' if `touse', name(psdash_c_overlap) _panel `scheme_opt' title("PS Overlap") estimand(`estimand') `ref_subcmd_opt' `psvars_subcmd_opt' `gpsfloor_subcmd_opt' `compact_subcmd_opt'"'
        capture noisily `_panel_cmd' `rep_overlap'
        local _panel_rc = _rc
        if `_panel_rc' {
            if `"`rep_overlap'"' == "" exit `_panel_rc'
            * Recompute without the workbook to distinguish export failure from
            * an analytical error and retain this panel's complete payload.
            `_panel_cmd'
            if `_psdash_side_rc' == 0 local _psdash_side_rc = `_panel_rc'
        }
        local graph_list "`graph_list' psdash_c_overlap"
        local _pw = r(n_warnings)
        local _pwt `"`r(warnings)'"'
        local _pct = r(pct_outside)
        local _sc_nout = r(n_outside)
        local _sc_n = r(N)
        if "`_pw'" == "" local _pw = 0
        * The combined threshold replaces the panel's built-in 10% cutoff.
        * Preserve every other panel finding (boundaries, orientation, GPS
        * positivity), but do not let the default cutoff override overlapmax().
        if "`multigroup'" == "0" & `_pct' > 10 {
            local _needle `"`=string(`_pct',"%4.1f")'% outside common support"'
            local _pw = max(0, `_pw' - 1)
            if `"`_pwt'"' == `"`_needle'"' local _pwt ""
            else {
                local _pwt = subinstr(`"`_pwt'"', `"`_needle' | "', "", 1)
                local _pwt = subinstr(`"`_pwt'"', `" | `_needle'"', "", 1)
            }
        }
        if `_pw' > 0 {
            local verdict_warnings "`verdict_warnings' overlap"
            local _all_findings `"`_all_findings' [overlap] `_pwt'"'
            local _total_nfind = `_total_nfind' + `_pw'
            local _sc_ft `"`_pwt'"'
        }
        if "`multigroup'" == "0" & `_pct' > `overlapmax' {
            local verdict_warnings "`verdict_warnings' overlap"
            local _all_findings `"`_all_findings' [overlap] `=string(`_pct',"%4.1f")'% outside > overlapmax(`overlapmax')"'
            local _total_nfind = `_total_nfind' + 1
            local _sc_ft `"`_sc_ft' | `=string(`_pct',"%4.1f")'% outside > overlapmax(`overlapmax')"'
        }
        local _panels_run = `_panels_run' + 1
        if `_sc_show' {
            local _sc_l1 "`=strtrim(string(`_pct', "%5.2f"))'% outside common support"
            local _sc_l2 "`_sc_nout' of `_sc_n' obs (overlapmax `overlapmax'%)"
            local _sc_rows `"`_sc_rows' row`=`_panels_run''(`"Overlap"' `"`=`_total_nfind' - `_nf0''"' `"`_sc_l1'"' `"`_sc_l2'"' `"`_sc_ft'"')"'
        }
        return add
    }

    * BALANCE PANEL
    if "`nobalance'" == "" & "`covariates'" != "" {
        local _nf0 = `_total_nfind'
        local _sc_ft ""
        display as text _n "{bf:=== BALANCE DIAGNOSTICS ===}"
        local wvar_opt ""
        if "`wvar'" != "" local wvar_opt "wvar(`wvar')"
        local _panel_cmd `"psdash_balance `treatment' `psvar' if `touse', covariates(`covariates') `wvar_opt' threshold(`threshold') loveplot name(psdash_c_balance) _panel `scheme_opt' title("Covariate Balance") estimand(`estimand') `ref_subcmd_opt' `psvars_subcmd_opt'"'
        capture noisily `_panel_cmd' `rep_balance'
        local _panel_rc = _rc
        if `_panel_rc' {
            if `"`rep_balance'"' == "" exit `_panel_rc'
            * Recompute without the workbook to distinguish export failure from
            * an analytical error and retain this panel's complete payload.
            `_panel_cmd'
            if `_psdash_side_rc' == 0 local _psdash_side_rc = `_panel_rc'
        }
        local graph_list "`graph_list' psdash_c_balance"
        local _pw = r(n_warnings)
        local _pwt `"`r(warnings)'"'
        local _nimb = r(n_imbalanced)
        local _sc_smd_raw = r(max_smd_raw)
        local _sc_smd_adj = r(max_smd_adj)
        local _panel_vars `"`r(varlist)'"'
        local _nvars : word count `_panel_vars'
        if "`_pw'" == "" local _pw = 0
        * imbalmax() replaces the panel's default zero-tolerance SMD rule;
        * variance-ratio and exact-boundary findings remain non-overridable.
        if `_nimb' > 0 {
            local _needle `"`_nimb' of `_nvars' covariate(s) exceed the SMD threshold"'
            local _pw = max(0, `_pw' - 1)
            if `"`_pwt'"' == `"`_needle'"' local _pwt ""
            else {
                local _pwt = subinstr(`"`_pwt'"', `"`_needle' | "', "", 1)
                local _pwt = subinstr(`"`_pwt'"', `" | `_needle'"', "", 1)
            }
        }
        if `_pw' > 0 {
            local verdict_warnings "`verdict_warnings' balance"
            local _all_findings `"`_all_findings' [balance] `_pwt'"'
            local _total_nfind = `_total_nfind' + `_pw'
            local _sc_ft `"`_pwt'"'
        }
        if `_nimb' > `imbalmax' {
            local verdict_warnings "`verdict_warnings' balance"
            local _all_findings `"`_all_findings' [balance] `_nimb' covariate(s) > imbalmax(`imbalmax')"'
            local _total_nfind = `_total_nfind' + 1
            local _sc_ft `"`_sc_ft' | `_nimb' covariate(s) > imbalmax(`imbalmax')"'
        }
        local _panels_run = `_panels_run' + 1
        if `_sc_show' {
            * Same labels and %6.3f format as the panel's console summary.
            local _sc_l1 "max |SMD| `=strtrim(string(`_sc_smd_raw', "%6.3f"))' raw"
            if !missing(`_sc_smd_adj') {
                local _sc_l1 "`_sc_l1', `=strtrim(string(`_sc_smd_adj', "%6.3f"))' adjusted"
            }
            * Threshold as the balance panel's band key prints it: leading
            * zero, the user's decimals kept (0.1, 0.125).
            local _sc_thr = strtrim(string(abs(`threshold'), "%10.0g"))
            if substr("`_sc_thr'", 1, 1) == "." local _sc_thr "0`_sc_thr'"
            local _sc_l2 "`_nimb' of `_nvars' covariates > `_sc_thr' (imbalmax `imbalmax')"
            local _sc_rows `"`_sc_rows' row`=`_panels_run''(`"Balance"' `"`=`_total_nfind' - `_nf0''"' `"`_sc_l1'"' `"`_sc_l2'"' `"`_sc_ft'"')"'
        }
        return add
    }
    else if "`nobalance'" == "" & "`covariates'" == "" {
        display as text _n "note: balance panel skipped (no covariates detected)"
    }

    * WEIGHTS PANEL
    if "`noweights'" == "" {
        local _nf0 = `_total_nfind'
        local _sc_ft ""
        display as text _n "{bf:=== WEIGHT DIAGNOSTICS ===}"
        local wvar_opt ""
        if "`wvar'" != "" local wvar_opt "wvar(`wvar')"
        local _panel_cmd `"psdash_weights `treatment' `psvar' if `touse', `wvar_opt' graph name(psdash_c_weights) _panel `scheme_opt' estimand(`estimand') `ref_subcmd_opt' `psvars_subcmd_opt' `compact_subcmd_opt'"'
        capture noisily `_panel_cmd' `rep_weights'
        local _panel_rc = _rc
        if `_panel_rc' {
            if `"`rep_weights'"' == "" exit `_panel_rc'
            * Recompute without the workbook to distinguish export failure from
            * an analytical error and retain this panel's complete payload.
            `_panel_cmd'
            if `_psdash_side_rc' == 0 local _psdash_side_rc = `_panel_rc'
        }
        local graph_list "`graph_list' psdash_c_weights"
        local _pw = r(n_warnings)
        local _pwt `"`r(warnings)'"'
        local _ess = r(ess_pct)
        local _sc_essn = r(ess)
        local _sc_ess_t = r(ess_pct_treated)
        local _sc_ess_c = r(ess_pct_control)
        local _sc_maxw = r(max_wt)
        if "`_pw'" == "" local _pw = 0
        * essmin() replaces only the panel's overall-ESS cutoff. Per-arm ESS,
        * CV, extreme-weight, dominance, and positivity findings still apply.
        if `_ess' < 50 {
            local _needle `"overall ESS `=string(`_ess',"%4.1f")'% < 50%"'
            local _pw = max(0, `_pw' - 1)
            if `"`_pwt'"' == `"`_needle'"' local _pwt ""
            else {
                local _pwt = subinstr(`"`_pwt'"', `"`_needle' | "', "", 1)
                local _pwt = subinstr(`"`_pwt'"', `" | `_needle'"', "", 1)
            }
        }
        if `_pw' > 0 {
            local verdict_warnings "`verdict_warnings' weights"
            local _all_findings `"`_all_findings' [weights] `_pwt'"'
            local _total_nfind = `_total_nfind' + `_pw'
            local _sc_ft `"`_pwt'"'
        }
        if `_ess' < `essmin' {
            local verdict_warnings "`verdict_warnings' weights"
            local _all_findings `"`_all_findings' [weights] ESS `=string(`_ess',"%4.1f")'% < essmin(`essmin')"'
            local _total_nfind = `_total_nfind' + 1
            local _sc_ft `"`_sc_ft' | ESS `=string(`_ess',"%4.1f")'% < essmin(`essmin')"'
        }
        local _panels_run = `_panels_run' + 1
        if `_sc_show' {
            local _sc_l1 "ESS `=strtrim(string(`_sc_essn', "%12.1f"))', `=strtrim(string(`_ess', "%6.1f"))'% of N (essmin `essmin'%)"
            local _sc_arm "treated"
            local _sc_armpct = `_sc_ess_t'
            if `_sc_ess_c' < `_sc_ess_t' {
                local _sc_arm "control"
                local _sc_armpct = `_sc_ess_c'
            }
            local _sc_l2 "min arm ESS `=strtrim(string(`_sc_armpct', "%6.1f"))'% (`_sc_arm'); max weight `=strtrim(string(`_sc_maxw', "%12.3f"))'"
            local _sc_rows `"`_sc_rows' row`=`_panels_run''(`"Weights"' `"`=`_total_nfind' - `_nf0''"' `"`_sc_l1'"' `"`_sc_l2'"' `"`_sc_ft'"')"'
        }
        return add
    }

    * SUPPORT PANEL
    if "`nosupport'" == "" {
        local _nf0 = `_total_nfind'
        local _sc_ft ""
        display as text _n "{bf:=== COMMON SUPPORT ASSESSMENT ===}"
        local _sup_graph_opt `"name(psdash_c_support) _panel `scheme_opt' title("Common Support")"'
        * title() also heads the panel's console output, so keep it without the graph.
        if !`_sc_support_graph' local _sup_graph_opt `"nograph title("Common Support")"'
        local _panel_cmd `"psdash_support `treatment' `psvar' if `touse', `_sup_graph_opt' estimand(`estimand') `ref_subcmd_opt' `psvars_subcmd_opt' `gpsfloor_subcmd_opt' `compact_subcmd_opt'"'
        capture noisily `_panel_cmd' `rep_support'
        local _panel_rc = _rc
        if `_panel_rc' {
            if `"`rep_support'"' == "" exit `_panel_rc'
            * Recompute without the workbook to distinguish export failure from
            * an analytical error and retain this panel's complete payload.
            `_panel_cmd'
            if `_psdash_side_rc' == 0 local _psdash_side_rc = `_panel_rc'
        }
        if `_sc_support_graph' {
            * With nooverlap the binary support density takes the overlap slot.
            if `_sc_show' local graph_list "psdash_c_support `graph_list'"
            else local graph_list "`graph_list' psdash_c_support"
        }
        local _pw = r(n_warnings)
        local _pwt `"`r(warnings)'"'
        local _pct = r(pct_outside)
        local _sc_nout = r(n_outside)
        local _sc_n = r(N)
        local _sc_lb = r(lower_bound)
        local _sc_ub = r(upper_bound)
        if "`_pw'" == "" local _pw = 0
        * As for overlap, overlapmax() replaces the binary panel's built-in
        * 10% cutoff. Multi-group verdicts use full-vector GPS positivity;
        * their observed-arm min/max overlap is descriptive only.
        if "`multigroup'" == "0" & `_pct' > 10 {
            local _needle `"`=string(`_pct',"%4.1f")'% outside common support"'
            local _pw = max(0, `_pw' - 1)
            if `"`_pwt'"' == `"`_needle'"' local _pwt ""
            else {
                local _pwt = subinstr(`"`_pwt'"', `"`_needle' | "', "", 1)
                local _pwt = subinstr(`"`_pwt'"', `" | `_needle'"', "", 1)
            }
        }
        if `_pw' > 0 {
            local verdict_warnings "`verdict_warnings' support"
            local _all_findings `"`_all_findings' [support] `_pwt'"'
            local _total_nfind = `_total_nfind' + `_pw'
            local _sc_ft `"`_pwt'"'
        }
        if "`multigroup'" == "0" & `_pct' > `overlapmax' {
            local verdict_warnings "`verdict_warnings' support"
            local _all_findings `"`_all_findings' [support] `=string(`_pct',"%4.1f")'% outside > overlapmax(`overlapmax')"'
            local _total_nfind = `_total_nfind' + 1
            local _sc_ft `"`_sc_ft' | `=string(`_pct',"%4.1f")'% outside > overlapmax(`overlapmax')"'
        }
        local _panels_run = `_panels_run' + 1
        if `_sc_show' {
            local _sc_l1 "`=`_sc_n' - `_sc_nout'' of `_sc_n' inside support (`=strtrim(string(100 * (`_sc_n' - `_sc_nout') / `_sc_n', "%6.2f"))'%)"
            local _sc_l2 "bounds [`=strtrim(string(`_sc_lb', "%10.4f"))', `=strtrim(string(`_sc_ub', "%10.4f"))']"
            local _sc_rows `"`_sc_rows' row`=`_panels_run''(`"Support"' `"`=`_total_nfind' - `_nf0''"' `"`_sc_l1'"' `"`_sc_l2'"' `"`_sc_ft'"')"'
        }
        return add
    }

    * Overall verdict (RB-01 binary policy: ANY finding across any panel -> FAIL;
    * PASS only when every executed panel is clean). Decided once, before the
    * combine, so the Diagnostic Summary scorecard and r(verdict) read the same
    * value; the console lines below still print after the graph is built.
    local verdict_warnings = strtrim("`verdict_warnings'")
    local verdict_warnings : list uniq verdict_warnings
    local _all_findings = strtrim("`_all_findings'")
    local n_warnings = `_total_nfind'
    if `_total_nfind' == 0 local verdict "PASS"
    else local verdict "FAIL"

    * COMBINE GRAPHS
    local ngraphs : word count `graph_list'

    if `ngraphs' > 0 & `_psdash_side_rc' == 0 {
        capture noisily {
            local combine_scheme ""
            if "`scheme'" != "" {
                local combine_scheme "scheme(`scheme')"
            }

            if `_sc_show' {
                _psdash_c_summary_graph, name(psdash_c_summary) ///
                    verdict(`verdict') nfindings(`_total_nfind') ///
                    npanels(`_panels_run') cellrows(`=cond(`ngraphs' <= 1, 1, 2)') ///
                    scheme(`scheme') `_sc_rows'
                local graph_list "`graph_list' psdash_c_summary"
                local ngraphs : word count `graph_list'
            }

            * Determine layout
            if `ngraphs' <= 2 {
                local layout "rows(1)"
            }
            else {
                local layout "rows(2)"
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

    * Zero-panel guard (RB-12/V1): a verdict requires evidence. If every panel was
    * suppressed, there is nothing to verdict -- error rather than return PASS.
    if `_panels_run' == 0 {
        display as error "No diagnostic panel executed; a verdict requires at least one of"
        display as error "overlap/balance/weights/support to run. Remove a no* option."
        exit 198
    }

    if "`verdict'" == "PASS" {
        display as text _n "Overall: " as result "PASS" ///
            as text " (" as result `_panels_run' as text " panel(s), 0 findings)"
    }
    else {
        display as text _n "Overall: " as text "{err}FAIL{txt}" ///
            as text " (" as result `_total_nfind' as text " finding(s) across " ///
            as result `_panels_run' as text " panel(s): " as result "`verdict_warnings'" as text ")"
        display as text `"  Findings: `_all_findings'"'
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

    * Store shared return values (RB-01: r(verdict)/r(warnings)/r(n_warnings) all
    * derive from the same aggregated findings object)
    return local verdict "`verdict'"
    return scalar n_warnings = `n_warnings'
    return local warnings `"`_all_findings'"'
    return scalar n_panels = `_panels_run'
    return local warning_panels "`verdict_warnings'"
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
    return scalar N_requested = `N_requested'
    return scalar N_analysis = `N_analysis'
    return scalar n_common_excluded = `N_common_excluded'
    * RB-05 estimation-sample exclusion ledger (teffects only)
    if "`n_excluded'" != "" {
        return scalar n_excluded = `n_excluded'
        return scalar n_estimation = `n_estimation'
    }
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

* File-private helper: Diagnostic Summary scorecard panel for the binary
* dashboard. A twoway graph with no axes stating the overall verdict and one row
* per executed panel. Every number arrives pre-formatted from psdash_combined,
* so the scorecard repeats exactly what the console and r() report; this helper
* decides nothing and computes nothing.
*   rowN() = "Panel" "#findings" "metric line 1" ["metric line 2" ["findings"]]
capture program drop _psdash_c_summary_graph
program define _psdash_c_summary_graph, nclass
    version 16.0
    local _vao = c(varabbrev)
    set varabbrev off
    capture noisily {
        syntax , NAME(name) VERDict(string) NFINDings(integer) ///
            NPANels(integer) [CELLrows(integer 2) SCHeme(string) TItle(string asis) ///
            ROW1(string asis) ROW2(string asis) ROW3(string asis) ///
            ROW4(string asis)]

        if !inlist("`verdict'", "PASS", "FAIL") {
            display as error "_psdash_c_summary_graph: verdict() must be PASS or FAIL"
            exit 198
        }
        if `"`title'"' == "" local title `""Diagnostic Summary""'

        * Accessible status colours on a white background (WCAG contrast
        * >= 4.5:1); the words PASS/FAIL and OK/Flag carry the meaning too.
        local c_ok "26 127 55"
        local c_bad "180 35 24"

        * Parse rows first: the layout is line-based (a row is 2 or 3 lines).
        local nrows = 0
        local nlines = 0
        forvalues i = 1/4 {
            if `"`row`i''"' == "" continue
            local ++nrows
            local spec `"`row`i''"'
            gettoken r_name`nrows' spec : spec
            gettoken r_nf`nrows' spec : spec
            gettoken r_l1`nrows' spec : spec
            gettoken r_l2`nrows' spec : spec
            gettoken lf spec : spec
            confirm integer number `r_nf`nrows''
            * Findings arrive " | "-separated, as in r(warnings); show them
            * "; "-separated, wrapped onto at most two lines of the cell.
            local lf = strtrim(`"`lf'"')
            if usubstr(`"`lf'"', 1, 2) == "| " local lf = usubstr(`"`lf'"', 3, .)
            local lf = subinstr(`"`lf'"', " | ", "; ", .)
            local r_lf`nrows' `"`lf'"'
        }

        * Vertical positions are offsets from the top in units of a 2x2
        * dashboard cell; a rows(1) dashboard (cellrows(1)) has cells about
        * twice as tall, so offsets are halved to keep the same on-screen
        * spacing, packed under the title.
        local k = cond(`cellrows' == 1, 0.5, 1)

        local txt ""
        * Headline: the verdict word alone, so it equals r(verdict) exactly.
        local vcol = cond("`verdict'" == "PASS", "`c_ok'", "`c_bad'")
        local txt `"`txt' text(`=100 - 7 * `k'' 50 "{bf:`verdict'}", size(vlarge) color("`vcol'") placement(c))"'
        local fword = cond(`nfindings' == 1, "finding", "findings")
        local pword = cond(`npanels' == 1, "panel", "panels")
        local txt `"`txt' text(`=100 - 19 * `k'' 50 "`nfindings' `fword' across `npanels' `pword'", size(small) placement(c))"'

        * Rows share the band from y = 74 down to y = 0; each row gets its
        * lines plus a gap, so flagged rows grow and clean rows stay compact.
        * Findings wrap at a word boundary onto up to two red lines; text
        * beyond that ends in "..." (r(warnings) holds the full list). When
        * every row is flagged the pitch would fall below what small text
        * needs (about 5.5 units in a 2x2 cell): step the text down one size
        * and tighten the gaps; if even then two finding lines per row do not
        * fit (about 4.6 units for vsmall text), each finding keeps one line.
        local nsize "medsmall"
        local tsize "small"
        local gapf = 0.8
        local maxch = 50
        local maxlf = 2
        forvalues pass = 1/3 {
            local nlines = 0
            forvalues i = 1/`nrows' {
                local rest `"`r_lf`i''"'
                local nl = 0
                while `"`rest'"' != "" & `nl' < `maxlf' {
                    local ++nl
                    if ustrlen(`"`rest'"') <= `maxch' {
                        local w_`i'_`nl' `"`rest'"'
                        local rest ""
                    }
                    else {
                        local cut = 0
                        forvalues c = `maxch'(-1)2 {
                            if usubstr(`"`rest'"', `c', 1) == " " {
                                local cut = `c'
                                continue, break
                            }
                        }
                        if `cut' == 0 local cut = `maxch'
                        local w_`i'_`nl' = strtrim(usubstr(`"`rest'"', 1, `cut'))
                        local rest = strtrim(usubstr(`"`rest'"', `cut' + 1, .))
                    }
                }
                if `"`rest'"' != "" {
                    local last `"`w_`i'_`nl''"'
                    if ustrlen(`"`last'"') > `maxch' - 3 {
                        local last = strtrim(usubstr(`"`last'"', 1, `maxch' - 3))
                    }
                    local w_`i'_`nl' `"`last'..."'
                }
                local w_n`i' = `nl'
                local nlines = `nlines' + 1 + (`"`r_l2`i''"' != "") + `nl'
            }
            local d = 74 / max(`nlines' + `gapf' * `nrows', 1)
            if `pass' == 1 {
                local d = min(7, `d')
                if `d' >= 5.5 continue, break
                local nsize "small"
                local tsize "vsmall"
                local gapf = 0.5
                local maxch = 58
            }
            else if `pass' == 2 {
                if `d' >= 4.6 continue, break
                local maxlf = 1
            }
        }
        * y is the offset from the top; 100 - k*y is the plot coordinate.
        local y = 26
        local seps ""
        forvalues i = 1/`nrows' {
            local seps "`seps' `=100 - `k' * `y''"
            local y = `y' + `gapf' * `d' / 2 + 0.5 * `d'
            local scol = cond(`r_nf`i'' == 0, "`c_ok'", "`c_bad'")
            local sword = cond(`r_nf`i'' == 0, "OK", "Flag")
            local txt `"`txt' text(`=100 - `k' * `y'' 1 "{bf:`r_name`i''}", size(`nsize') placement(e) justification(left))"'
            local txt `"`txt' text(`=100 - `k' * `y'' 99 "{bf:`sword'}", size(`nsize') color("`scol'") placement(w) justification(right))"'
            local txt `"`txt' text(`=100 - `k' * `y'' 21 `"`r_l1`i''"', size(`tsize') placement(e) justification(left))"'
            if `"`r_l2`i''"' != "" {
                local y = `y' + `d'
                local txt `"`txt' text(`=100 - `k' * `y'' 21 `"`r_l2`i''"', size(`tsize') placement(e) justification(left))"'
            }
            forvalues j = 1/`w_n`i'' {
                local y = `y' + `d'
                local txt `"`txt' text(`=100 - `k' * `y'' 21 `"`w_`i'_`j''"', size(`tsize') color("`c_bad'") placement(e) justification(left))"'
            }
            local y = `y' + 0.5 * `d' + `gapf' * `d' / 2
        }

        local scheme_opt ""
        if "`scheme'" != "" local scheme_opt "scheme(`scheme')"

        twoway (scatteri 0 0 100 100, msymbol(none)), ///
            `txt' ///
            yline(`seps', lcolor(gs13) lwidth(thin) lpattern(solid)) ///
            xscale(off range(0 100)) yscale(off range(0 100)) ///
            xlabel(none, nogrid) ylabel(none, nogrid) ///
            xtitle("") ytitle("") legend(off) ///
            plotregion(margin(zero) style(none)) ///
            title(`title') ///
            name(`name', replace) `scheme_opt'
    }
    local rc = _rc
    set varabbrev `_vao'
    if `rc' exit `rc'
end
