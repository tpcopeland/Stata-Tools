*! drest_plot Version 1.0.0  2026/03/15
*! Visualization for doubly robust estimation diagnostics
*! Author: Timothy P Copeland
*! Department of Clinical Neuroscience, Karolinska Institutet
*! Program class: rclass (returns results in r())

/*
Basic syntax:
  drest_plot [, overlap influence ite all saving(string) scheme(string) name(string)]

Requires: drest_estimate has been run

See help drest_plot for complete documentation
*/

program define drest_plot, rclass
    version 16.0
    local _vaset = c(varabbrev)
    set varabbrev off
    set more off

    syntax [, OVERlap INFLuence ITE ALL ///
              SAVing(string) SCHeme(string) Name(string)]

    * =========================================================================
    * CHECK PREREQUISITES
    * =========================================================================
    _drest_check_estimated
    _drest_get_settings

    local treatment "`_drest_treatment'"
    local estimand  "`_drest_estimand'"

    foreach v in _drest_ps _drest_mu1 _drest_mu0 _drest_if _drest_esample {
        capture confirm variable `v'
        if _rc {
            set varabbrev `_vaset'
            display as error "variable `v' not found; re-run drest_estimate"
            exit 111
        }
    }

    * Defaults
    if "`overlap'" == "" & "`influence'" == "" & "`ite'" == "" & "`all'" == "" {
        local all "all"
    }
    if "`all'" != "" {
        local overlap "overlap"
        local influence "influence"
        local ite "ite"
    }

    if "`scheme'" == "" local scheme "plotplainblind"

    local n_plots = 0

    * =========================================================================
    * OVERLAP PLOT
    * =========================================================================
    if "`overlap'" != "" {
        local ++n_plots
        local gopts `"title("Propensity Score Overlap") scheme(`scheme')"'
        if "`saving'" != "" local gopts `"`gopts' saving(`saving'_overlap, replace)"'
        if "`name'" != "" {
            local gopts `"`gopts' name(`name'_overlap, replace)"'
        }
        else {
            local gopts `"`gopts' name(drest_ps_overlap, replace)"'
        }

        capture noisily twoway (kdensity _drest_ps if _drest_esample == 1 & `treatment' == 1, ///
                lcolor(navy) lwidth(medthick)) ///
               (kdensity _drest_ps if _drest_esample == 1 & `treatment' == 0, ///
                lcolor(cranberry) lwidth(medthick) lpattern(dash)), ///
            legend(order(1 "Treated" 2 "Control") position(1) ring(0)) ///
            xtitle("Propensity Score") ytitle("Density") ///
            `gopts'
        if _rc {
            set varabbrev `_vaset'
            exit _rc
        }
    }

    * =========================================================================
    * INFLUENCE FUNCTION PLOT
    * =========================================================================
    if "`influence'" != "" {
        local ++n_plots
        local gopts2 `"title("Influence Function Distribution") scheme(`scheme')"'
        if "`saving'" != "" local gopts2 `"`gopts2' saving(`saving'_influence, replace)"'
        if "`name'" != "" {
            local gopts2 `"`gopts2' name(`name'_influence, replace)"'
        }
        else {
            local gopts2 `"`gopts2' name(drest_influence, replace)"'
        }

        capture noisily twoway (histogram _drest_if if _drest_esample == 1, ///
                color(navy%70) frequency), ///
            xtitle("Influence Function Value") ytitle("Frequency") ///
            xline(0, lcolor(red) lpattern(dash)) ///
            `gopts2'
        if _rc {
            set varabbrev `_vaset'
            exit _rc
        }
    }

    * =========================================================================
    * INDIVIDUAL TREATMENT EFFECT PLOT
    * =========================================================================
    if "`ite'" != "" {
        local ++n_plots
        local gopts3 `"title("Individual Treatment Effect Distribution") scheme(`scheme')"'
        if "`saving'" != "" local gopts3 `"`gopts3' saving(`saving'_ite, replace)"'
        if "`name'" != "" {
            local gopts3 `"`gopts3' name(`name'_ite, replace)"'
        }
        else {
            local gopts3 `"`gopts3' name(drest_ite, replace)"'
        }

        tempvar ite_var
        quietly gen double `ite_var' = _drest_mu1 - _drest_mu0 if _drest_esample == 1

        * Get the AIPW estimate for reference line
        local tau "`_drest_ate'"

        capture noisily twoway (histogram `ite_var' if _drest_esample == 1, ///
                color(navy%70) frequency), ///
            xtitle("Individual Treatment Effect (mu1 - mu0)") ytitle("Frequency") ///
            xline(`tau', lcolor(red) lpattern(dash) lwidth(medium)) ///
            note("Red line = AIPW `estimand' estimate") ///
            `gopts3'
        if _rc {
            set varabbrev `_vaset'
            exit _rc
        }
    }

    * =========================================================================
    * DISPLAY & RETURN
    * =========================================================================
    _drest_display_header "drest_plot" "Doubly Robust Plots"
    display as text "Plots generated: " as result `n_plots'
    if "`overlap'" != "" display as text "  - Propensity score overlap"
    if "`influence'" != "" display as text "  - Influence function distribution"
    if "`ite'" != "" display as text "  - Individual treatment effect"

    return scalar n_plots = `n_plots'
    return local plots "`overlap' `influence' `ite'"

    set varabbrev `_vaset'
end
