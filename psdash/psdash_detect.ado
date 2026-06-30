*! psdash_detect Version 1.4.0  2026/07/01
*! Report propensity-score auto-detection without running diagnostics
*! Author: Timothy P Copeland, Karolinska Institutet
*! Program class: rclass

/*
DESCRIPTION:
    Runs the psdash auto-detection layer and reports what it found —
    treatment, PS variable(s), covariates, weights, estimand, source,
    and longitudinal contract state — without running any diagnostic
    panel. This is the transparent dry-run for the 9-mode detector
    (manual, teffects, tmle, ltmle, iivw, msm, tte, logit/probit, mlogit).

    Reachable as "psdash detect ..." or "psdash combined, dryrun".

SYNTAX:
    psdash detect [treatment] [psvar] [if] [in] [, options]

STORED RESULTS:
    r(source)        - detection source
    r(treatment)     - treatment variable
    r(psvar)         - PS variable (or "auto-generated")
    r(covariates)    - detected/supplied covariate list
    r(wvar)          - weight variable (may be empty)
    r(estimand)      - estimand (ate/att/atc)
    r(levels)        - treatment levels (multi-group)
    r(reference)     - reference group (multi-group)
    r(n_covariates)  - covariate count
    r(K)             - number of treatment groups
    r(multigroup)    - 1 if multi-group, 0 if binary
    r(longitudinal)  - 1 if longitudinal LTMLE contract, else 0
    r(id), r(period), r(regime), r(method), r(contract_version) - longitudinal only
*/

program define psdash_detect, rclass
    version 16.0
    local _vao = c(varabbrev)
    set varabbrev off

    capture noisily {

    syntax [anything] [if] [in], ///
        [COVariates(varlist numeric) ///
         Wvar(varname) ///
         ESTImand(string) ///
         REFerence(string) ///
         PSVars(varlist numeric)]

    tempvar touse ps_auto wt_auto
    mark `touse' `if' `in'  // validator-note: mark+markout pattern is equivalent to marksample

    local ref_opt ""
    if "`reference'" != "" local ref_opt "reference(`reference')"
    local psvars_opt ""
    if "`psvars'" != "" local psvars_opt "psvars(`psvars')"

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
    local longitudinal "`_psd_longitudinal'"
    local idvar "`_psd_id'"
    local period "`_psd_period'"
    local regime "`_psd_regime'"
    local multigroup "`_psd_multigroup'"
    local K = `_psd_K'
    local levels "`_psd_levels'"
    local reference_grp "`_psd_reference'"
    if "`estimand'" == "" local estimand "`_psd_estimand'"

    * Use detected covariates/weights if not explicitly provided
    if "`covariates'" == "" & "`det_covariates'" != "" local covariates "`det_covariates'"
    if "`wvar'" == "" & "`det_wvar'" != "" local wvar "`det_wvar'"
    if "`source'" == "iivw" & "`iivw_component'" == "" local iivw_component "treatment"

    local psvar_label "`psvar'"
    if "`psvar_auto'" == "1" local psvar_label "auto-generated"
    local wvar_label "`wvar'"
    if "`wvar_auto'" == "1" local wvar_label "auto-generated"
    local ncovs : word count `covariates'

    * DISPLAY REPORT
    display as text _n as result "psdash detection report" ///
        as text " (dry run — no diagnostics computed)"
    display as text "Source:        " as result "`source'"
    if "`iivw_component'" != "" {
        display as text "Weight component: " as result "treatment IPTW"
    }
    display as text "Treatment:     " as result "`treatment'"
    if "`multigroup'" != "0" {
        display as text "Type:          " as result "multi-group" ///
            as text " (`K' groups; levels: `levels')"
        display as text "Reference:     " as result "`reference_grp'"
    }
    else {
        display as text "Type:          " as result "binary"
    }
    display as text "PS variable:   " as result "`psvar_label'"
    display as text "Covariates:    " as result "`ncovs'" as text " detected/supplied"
    if "`covariates'" != "" {
        display as text "  " as result "`covariates'"
    }
    if "`wvar'" != "" {
        display as text "Weights:       " as result "`wvar_label'"
    }
    display as text "Estimand:      " as result strupper("`estimand'")
    if "`longitudinal'" == "1" {
        display as text "Longitudinal:  " as result "yes"
        if "`idvar'" != "" display as text "  ID:          " as result "`idvar'"
        if "`period'" != "" display as text "  Period:      " as result "`period'"
        if "`regime'" != "" display as text "  Regime:      " as result "`regime'"
        if "`method'" != "" display as text "  Method:      " as result "`method'"
        if "`contract_version'" != "" {
            display as text "  Contract:    " as result "`contract_version'"
        }
    }
    else {
        display as text "Longitudinal:  " as result "no"
    }
    display as text _n "Run {cmd:psdash combined} (without dryrun) to compute diagnostics."

    * RETURN
    return local source "`source'"
    return local treatment "`treatment'"
    return local psvar "`psvar_label'"
    return local covariates "`covariates'"
    return local wvar "`wvar'"
    return local estimand "`estimand'"
    return scalar n_covariates = `ncovs'
    return scalar psvar_auto = ("`psvar_auto'" == "1")
    return scalar multigroup = ("`multigroup'" != "0")
    return scalar longitudinal = ("`longitudinal'" == "1")
    if "`multigroup'" != "0" {
        return local levels "`levels'"
        return local reference "`reference_grp'"
        return scalar K = `K'
    }
    if "`iivw_component'" != "" {
        return local iivwcomponent "`iivw_component'"
    }
    if "`longitudinal'" == "1" {
        if "`idvar'" != "" return local id "`idvar'"
        if "`period'" != "" return local period "`period'"
        if "`regime'" != "" return local regime "`regime'"
        if "`method'" != "" return local method "`method'"
        if "`contract_version'" != "" return local contract_version "`contract_version'"
    }

    }
    local rc = _rc
    set varabbrev `_vao'
    if `rc' exit `rc'
end
