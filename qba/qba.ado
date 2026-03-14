*! qba Version 1.0.0  2026/03/13
*! Quantitative Bias Analysis toolkit for epidemiologic data
*! Author: Timothy P Copeland
*! Department of Clinical Neuroscience, Karolinska Institutet
*! Program class: rclass

/*
Main dispatcher for the QBA package. Displays available commands
and package information.

See help qba for complete documentation.
*/

capture program drop qba
program define qba, rclass
    version 16.0
    set varabbrev off

    syntax [, Version]

    display as text ""
    display as text "{bf:qba} - Quantitative Bias Analysis for Epidemiologic Data"
    display as text "{hline 60}"
    display as text ""
    display as text "Version 1.0.0 (2026-03-13)"
    display as text ""
    display as text "{bf:Available commands:}"
    display as text ""
    display as text "  {bf:{help qba_misclass}} - Misclassification bias analysis"
    display as text "      Corrects 2x2 tables for exposure or outcome"
    display as text "      misclassification (nondifferential or differential)"
    display as text ""
    display as text "  {bf:{help qba_selection}} - Selection bias analysis"
    display as text "      Corrects 2x2 tables using selection probabilities"
    display as text ""
    display as text "  {bf:{help qba_confound}} - Unmeasured confounding analysis"
    display as text "      Corrects estimates for unmeasured confounders"
    display as text "      with optional E-value computation"
    display as text ""
    display as text "  {bf:{help qba_multi}} - Multi-bias analysis"
    display as text "      Chains multiple bias corrections in one"
    display as text "      Monte Carlo simulation framework"
    display as text ""
    display as text "  {bf:{help qba_plot}} - Visualization"
    display as text "      Tornado, distribution, and tipping point plots"
    display as text ""
    display as text "{bf:All commands support:}"
    display as text "  - Simple (fixed parameter) bias analysis"
    display as text "  - Probabilistic (Monte Carlo) bias analysis"
    display as text "  - Multiple distribution families for parameters"
    display as text ""
    display as text "Based on: Lash TL, Fox MP, Fink AK. Applying Quantitative"
    display as text "Bias Analysis to Epidemiologic Data. 2nd ed. Springer; 2021."
    display as text "{hline 60}"

    return local version "1.0.0"
    return local commands "qba_misclass qba_selection qba_confound qba_multi qba_plot"
end
