*! drest_predict Version 1.0.0  2026/03/15
*! Potential outcome predictions from doubly robust estimation
*! Author: Timothy P Copeland
*! Department of Clinical Neuroscience, Karolinska Institutet
*! Program class: rclass (returns results in r())

/*
Basic syntax:
  drest_predict [, mu1(name) mu0(name) ite(name) ps(name) replace]

Requires: drest_estimate has been run

See help drest_predict for complete documentation
*/

program define drest_predict, rclass
    version 16.0
    local _vaset = c(varabbrev)
    set varabbrev off
    set more off

    syntax [, MU1(name) MU0(name) ITE(name) PS(name) replace]

    * =========================================================================
    * CHECK PREREQUISITES
    * =========================================================================
    _drest_check_estimated
    _drest_get_settings

    local outcome   "`_drest_outcome'"
    local treatment "`_drest_treatment'"

    * Confirm required variables exist
    foreach v in _drest_ps _drest_mu1 _drest_mu0 _drest_esample {
        capture confirm variable `v'
        if _rc {
            set varabbrev `_vaset'
            display as error "variable `v' not found; re-run drest_estimate"
            exit 111
        }
    }

    * =========================================================================
    * SET DEFAULTS
    * =========================================================================
    local any_output = 0

    * =========================================================================
    * GENERATE REQUESTED PREDICTIONS
    * =========================================================================
    if "`mu1'" != "" {
        if "`replace'" != "" {
            capture drop `mu1'
        }
        else {
            capture confirm new variable `mu1'
            if _rc {
                set varabbrev `_vaset'
                display as error "variable `mu1' already exists; use replace option"
                exit 110
            }
        }
        quietly gen double `mu1' = _drest_mu1
        label variable `mu1' "Predicted potential outcome under treatment"
        local ++any_output
    }

    if "`mu0'" != "" {
        if "`replace'" != "" {
            capture drop `mu0'
        }
        else {
            capture confirm new variable `mu0'
            if _rc {
                set varabbrev `_vaset'
                display as error "variable `mu0' already exists; use replace option"
                exit 110
            }
        }
        quietly gen double `mu0' = _drest_mu0
        label variable `mu0' "Predicted potential outcome under control"
        local ++any_output
    }

    if "`ite'" != "" {
        if "`replace'" != "" {
            capture drop `ite'
        }
        else {
            capture confirm new variable `ite'
            if _rc {
                set varabbrev `_vaset'
                display as error "variable `ite' already exists; use replace option"
                exit 110
            }
        }
        quietly gen double `ite' = _drest_mu1 - _drest_mu0
        label variable `ite' "Individual treatment effect (mu1 - mu0)"
        local ++any_output
    }

    if "`ps'" != "" {
        if "`replace'" != "" {
            capture drop `ps'
        }
        else {
            capture confirm new variable `ps'
            if _rc {
                set varabbrev `_vaset'
                display as error "variable `ps' already exists; use replace option"
                exit 110
            }
        }
        quietly gen double `ps' = _drest_ps
        label variable `ps' "Propensity score"
        local ++any_output
    }

    * =========================================================================
    * DISPLAY
    * =========================================================================
    if `any_output' == 0 {
        display as text "No prediction variables requested."
        display as text ""
        display as text "Available options:"
        display as text "  {opt mu1(name)}  - Predicted outcome under treatment"
        display as text "  {opt mu0(name)}  - Predicted outcome under control"
        display as text "  {opt ite(name)}  - Individual treatment effect"
        display as text "  {opt ps(name)}   - Propensity score"
    }
    else {
        _drest_display_header "drest_predict" "Potential Outcome Predictions"

        if "`mu1'" != "" display as text "Created: " as result "`mu1'" as text " (potential outcome under treatment)"
        if "`mu0'" != "" display as text "Created: " as result "`mu0'" as text " (potential outcome under control)"
        if "`ite'" != "" display as text "Created: " as result "`ite'" as text " (individual treatment effect)"
        if "`ps'"  != "" display as text "Created: " as result "`ps'" as text " (propensity score)"
    }

    * =========================================================================
    * RETURN RESULTS
    * =========================================================================
    quietly count if _drest_esample == 1
    return scalar N = r(N)
    if "`mu1'" != "" return local mu1 "`mu1'"
    if "`mu0'" != "" return local mu0 "`mu0'"
    if "`ite'" != "" return local ite "`ite'"
    if "`ps'"  != "" return local ps "`ps'"

    set varabbrev `_vaset'
end
