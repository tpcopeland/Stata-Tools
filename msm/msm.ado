*! msm Version 2.0.0  2026/10/13
*! Marginal Structural Models suite for Stata
*! Author: Timothy P Copeland, Karolinska Institutet
*! Program class: rclass (returns results in r())

/*
Basic syntax:
  msm [, list detail status]

Description:
  Displays the package overview and the companion-package map, lists the
  commands, or reports the current pipeline state.

See help msm for complete documentation
*/

program define msm, rclass
    version 16.0
    local _varabbrev = c(varabbrev)
    local _more = c(more)
    tempname _caller_r
    _return hold `_caller_r'
    set varabbrev off
    set more off

    capture noisily {

    syntax [, List Detail STATus PROTocol]

    if "`protocol'" != "" {
        display as error "msm, protocol was removed in msm 2.0.0 together with msm_protocol"
        display as error "Record the study protocol in the manuscript or a protocol document."
        exit 198
    }

    * At most one umbrella mode option may be given (audit A35): otherwise the
    * else-if dispatch silently honours one and drops the rest.
    local _n_modes = ("`list'" != "") + ("`detail'" != "") + ("`status'" != "")
    if `_n_modes' > 1 {
        display as error "specify at most one of list, detail, or status"
        exit 198
    }

    * Read the package version from this ado's canonical header so display and
    * r(version) cannot drift from the shipped source during a version bump.
    local version "unknown"
    capture findfile msm.ado
    if !_rc {
        tempname _fh
        capture file open `_fh' using "`r(fn)'", read text
        if !_rc {
            file read `_fh' _header_line
            file close `_fh'
            if regexm("`_header_line'", "Version ([0-9.]+)") {
                local version = regexs(1)
            }
        }
    }

    * Canonical public-command manifest (audit A32): the single source that
    * drives the list mode, r(commands), and release QA. The removed 1.4.x
    * commands ship as stubs (exit 199) and are listed separately.
    local all_commands "msm_prepare msm_weight msm_diagnose msm_fit msm_predict"
    local n_commands : word count `all_commands'
    local removed_commands "msm_protocol msm_validate msm_plot msm_report msm_table msm_diagtab msm_sensitivity"

    display as text ""
    display as text "{hline 70}"
    if "`status'" != "" {
        display as result "msm" as text " - Pipeline Status"
    }
    else {
        display as result "msm" as text " - Marginal Structural Models for Stata"
    }
    display as text "Version `version'"
    display as text "{hline 70}"

    if "`status'" != "" {
        _msm_pipeline_state

        local prepared = real("`_msm_state_prepared'")
        local weighted = real("`_msm_state_weighted'")
        local fitted = real("`_msm_state_fitted'")

        local prepared_label "no"
        local weighted_label "no"
        local fitted_label "no"
        if `prepared' local prepared_label "yes"
        if `weighted' local weighted_label "yes"
        if `fitted' local fitted_label "yes"

        local censor_show "(none)"
        local covariates_show "(none)"
        local baseline_show "(none)"
        local weight_vars_show "(none)"
        local fit_artifacts_show "(none)"
        if "`_msm_state_censor'" != "" local censor_show "`_msm_state_censor'"
        if "`_msm_state_covariates'" != "" local covariates_show "`_msm_state_covariates'"
        if "`_msm_state_bl_covariates'" != "" local baseline_show "`_msm_state_bl_covariates'"
        if "`_msm_state_weight_vars'" != "" local weight_vars_show "`_msm_state_weight_vars'"
        if "`_msm_state_fit_artifacts'" != "" local fit_artifacts_show "`_msm_state_fit_artifacts'"

        display as text ""
        display as text "Current pipeline state: " as result "`_msm_state_stage_label'"
        display as text "Recommended next step: " as result "`_msm_state_next_step'"
        display as text ""
        display as text "Pipeline stages:"
        display as text "  Prepared:         " as result "`prepared_label'"
        display as text "  Weighted:         " as result "`weighted_label'"
        display as text "  Fitted:           " as result "`fitted_label'"
        if "`_msm_state_model'" != "" {
            display as text "  Fitted model:     " as result "`_msm_state_model'"
        }
        if "`_msm_state_exposure'" != "" {
            display as text "  Exposure term:    " as result "`_msm_state_exposure'"
        }
        if "`_msm_state_tvcov'" != "" {
            display as text "  Time-varying cov: " as result "`_msm_state_tvcov'"
        }
        if "`_msm_state_predict_disabled'" == "1" {
            display as text "  Counterfactuals:  " as result "unavailable" ///
                as text " (continuous/time-varying exposure mode)"
        }
        display as text ""
        display as text "Mapped variables:"
        if `prepared' {
            display as text "  ID:               " as result "`_msm_state_id'"
            display as text "  Period:           " as result "`_msm_state_period'"
            display as text "  Treatment:        " as result "`_msm_state_treatment'"
            display as text "  Outcome:          " as result "`_msm_state_outcome'"
            display as text "  Censoring:        " as result "`censor_show'"
            display as text "  Covariates:       " as result "`covariates_show'"
            display as text "  Baseline covars:  " as result "`baseline_show'"
        }
        else {
            display as text "  No msm variable mapping found in the current dataset."
        }
        display as text ""
        display as text "Artifacts in the dataset:"
        display as text "  Weight variables: " as result "`weight_vars_show'"
        display as text "  Fit artifacts:    " as result "`fit_artifacts_show'"
    }
    else if "`detail'" != "" {
        _msm_overview_detail
    }
    else if "`list'" != "" {
        display as text ""
        display as text "Available commands:"
        foreach cmd of local all_commands {
            display as result "  `cmd'"
        }
    }
    else {
        display as text ""
        display as text "{bf:Estimator core}"
        display as result "  msm_prepare     " as text "- Map variables and store metadata"
        display as result "  msm_weight      " as text "- Stabilized IPTW (+ optional IPCW)"
        display as result "  msm_diagnose    " as text "- Period x history balance and positivity"
        display as result "  msm_fit         " as text "- Weighted outcome model (GLM/Cox)"
        display as result "  msm_predict     " as text "- Counterfactual risks, risk differences, CIs"
        display as text ""
        _msm_companion_map
        display as text ""
        display as text "Check state anytime: " as result "{cmd:msm, status}"
        display as text "Help:  " as result "{help msm}" as text "  for documentation"
        display as text "       " as result "{help msm_prepare}" as text "  to get started"
    }

    display as text "{hline 70}"

    return local version "`version'"
    return local commands "`all_commands'"
    return local removed "`removed_commands'"
    return scalar n_commands = `n_commands'
    if "`status'" != "" {
        return local stage "`_msm_state_stage'"
        return local next_step "`_msm_state_next_step'"
        return local model "`_msm_state_model'"
        return local id "`_msm_state_id'"
        return local period "`_msm_state_period'"
        return local treatment "`_msm_state_treatment'"
        return local outcome "`_msm_state_outcome'"
        return local censor "`_msm_state_censor'"
        return local covariates "`_msm_state_covariates'"
        return local baseline_covariates "`_msm_state_bl_covariates'"
        return scalar prepared = `prepared'
        return scalar weighted = `weighted'
        return scalar fitted = `fitted'
    }

    } /* end capture noisily */
    local _rc = _rc

    set varabbrev `_varabbrev'
    set more `_more'

    if `_rc' {
        _return restore `_caller_r'
        return add
        exit `_rc'
    }
end

cap program drop _msm_companion_map
program define _msm_companion_map
    version 16.0
    local _orig_varabbrev = c(varabbrev)
    set varabbrev off
    capture noisily {
        display as text "{bf:Tables, diagnostics, figures and E-values (companion packages)}"
        display as text "  Coefficient table    " as result "{cmd:collect: msm_fit ...} then {cmd:regtab}" as text " (tabtools)"
        display as text "  Risk-difference table" as result " {cmd:matrix RD = r(rd)} then {cmd:effecttab, from(RD)}" as text " (tabtools)"
        display as text "  Weights and balance  " as result "{cmd:psdash combined, wvar(_msm_weight)}" as text " (psdash)"
        display as text "  Risk-difference plot " as result "{cmd:msm_predict, ... frame(F)} then {cmd:eplot, frame(F)}" as text " (eplot)"
        display as text "  Treatment histories  " as result "{cmd:swimlane}" as text " (swimlane)"
        display as text "  E-value              " as result "{cmd:qba_confound, from_model ... evalue measure(HR)}" as text " (qba)"
        display as text "  Removed 1.4.x commands print their replacement: see {help msm##companions:help msm}."
    }
    local _rc = _rc
    set varabbrev `_orig_varabbrev'
    if `_rc' exit `_rc'
end

cap program drop _msm_overview_detail
program define _msm_overview_detail
    version 16.0
    local _orig_varabbrev = c(varabbrev)
    set varabbrev off
    capture noisily {
        display as text ""
        display as result "  msm_prepare" as text "     Map variable names and validate the person-period"
        display as text "                structure. Refuses duplicates, non-binary treatment,"
        display as text "                outcome and censoring, and non-integer periods."
        display as text ""
        display as result "  msm_weight" as text "      Stabilized inverse probability of treatment"
        display as text "                weights (IPTW) with optional IPCW for informative"
        display as text "                censoring; period bases, truncation, risk-set flag."
        display as text ""
        display as result "  msm_diagnose" as text "    Covariate balance within period x prior-treatment"
        display as text "                history, censoring-decision balance, and the"
        display as text "                positivity floor on the observed decision."
        display as text ""
        display as result "  msm_fit" as text "         Weighted outcome model: pooled logistic (GLM),"
        display as text "                linear, or Cox PH; SEs clustered by individual."
        display as text ""
        display as result "  msm_predict" as text "     Standardized counterfactual risks under always-"
        display as text "                and never-treated strategies, risk differences,"
        display as text "                Monte Carlo CIs, and a graph-ready frame()."
        display as text ""
        display as text "  msm, status" as text "      Inspect the current pipeline stage, mapped"
        display as text "                variables, and artifacts."
        display as text ""
        _msm_companion_map
    }
    local _rc = _rc
    set varabbrev `_orig_varabbrev'
    if `_rc' exit `_rc'
end
