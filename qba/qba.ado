*! qba Version 1.1.2  2026/08/09
*! Quantitative Bias Analysis toolkit for epidemiologic data
*! Author: Timothy P Copeland, Karolinska Institutet
*! Program class: rclass

/*
Main dispatcher for the QBA package. Displays available commands
and package information.

See help qba for complete documentation.
*/

capture program drop qba
program define qba, rclass
    version 16.0
    local _saved_varabbrev = c(varabbrev)
    set varabbrev off
    capture noisily {

    syntax [, Version]

    * Read the version from this file's own *! header so the displayed and
    * returned version cannot drift from it on a bump.
    local _pkgver ""
    local _pkgdate ""
    capture findfile qba.ado
    if _rc == 0 {
        tempname _fh
        capture file open `_fh' using "`r(fn)'", read text
        if _rc == 0 {
            file read `_fh' _line
            file close `_fh'
            if regexm(`"`_line'"', "Version ([0-9]+\.[0-9]+\.[0-9]+) +([0-9/-]+)") {
                local _pkgver = regexs(1)
                local _pkgdate = subinstr(regexs(2), "/", "-", .)
            }
        }
    }
    if "`_pkgver'" == "" {
        display as error "could not read the package version from qba.ado; reinstall qba"
        exit 111
    }

    display as text "{bf:qba} - Quantitative Bias Analysis for Epidemiologic Data"
	    display as text "Version `_pkgver' (`_pkgdate')"
    display as text "{bf:Available commands:}"
    display as text "  {bf:{help qba_misclass}} - Misclassification bias analysis"
    display as text "      Corrects 2x2 tables for exposure or outcome"
    display as text "      misclassification (nondifferential or differential)"
    display as text "  {bf:{help qba_selection}} - Selection bias analysis"
    display as text "      Corrects 2x2 tables using selection probabilities"
    display as text "  {bf:{help qba_confound}} - Unmeasured confounding analysis"
    display as text "      Corrects estimates for unmeasured confounders"
    display as text "      with optional E-value computation"
    display as text "  {bf:{help qba_multi}} - Multi-bias analysis"
    display as text "      Chains multiple bias corrections in one"
    display as text "      Monte Carlo simulation framework"
	    display as text "  {bf:{help qba_plot}} - Visualization"
	    display as text "      Tornado, distribution, and tipping point plots"
    display as text "{bf:Analysis modes:}"
    display as text "  - qba_misclass, qba_selection, and qba_confound support"
	    display as text "    simple fixed-parameter and probabilistic Monte Carlo analysis"
	    display as text "  - qba_multi is Monte Carlo only"
    display as text "Based on: Lash TL, Fox MP, Fink AK. Applying Quantitative"
    display as text "Bias Analysis to Epidemiologic Data. 2nd ed. Springer; 2021."

	    return local version "`_pkgver'"
    return local commands "qba_misclass qba_selection qba_confound qba_multi qba_plot"

    }
    local rc = _rc
    set varabbrev `_saved_varabbrev'
    if `rc' exit `rc'
end
