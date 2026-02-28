*! nma Version 1.0.3  2026/02/28
*! Network Meta-Analysis suite for Stata
*! Author: Timothy P Copeland
*! Department of Clinical Neuroscience, Karolinska Institutet
*! Program class: rclass (returns results in r())

/*
Basic syntax:
  nma [, list detail]

Description:
  Displays package overview, lists all commands with descriptions,
  and shows the typical analysis workflow.

See help nma for complete documentation
*/

program define nma, rclass
    version 16.0
    set varabbrev off
    set more off

    syntax [, List Detail]

    local version "1.0.1"
    local n_commands = 9

    local all_commands "nma_setup nma_import nma_fit nma_inconsistency nma_rank nma_forest nma_map nma_compare nma_report"

    display as text ""
    display as text "{hline 70}"
    display as result "nma" as text " - Network Meta-Analysis for Stata"
    display as text "Version `version'"
    display as text "{hline 70}"

    if "`detail'" != "" {
        _nma_overview_detail
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
        display as text "{bf:Data Setup}"
        display as result "  nma_setup    " as text "- Import arm-level data (events/totals, mean/sd/n, rates)"
        display as result "  nma_import   " as text "- Import pre-computed effect sizes (log OR, HR, MD)"
        display as text ""
        display as text "{bf:Model Fitting}"
        display as result "  nma_fit      " as text "- Fit consistency model (REML/ML random effects)"
        display as text ""
        display as text "{bf:Post-Estimation}"
        display as result "  nma_rank     " as text "- Treatment rankings (SUCRA) and rankograms"
        display as result "  nma_forest   " as text "- Forest plot of treatment effects"
        display as result "  nma_map      " as text "- Network geometry visualization"
        display as result "  nma_compare  " as text "- League table of all pairwise comparisons"
        display as text ""
        display as text "{bf:Diagnostics & Reporting}"
        display as result "  nma_inconsistency " as text "- Global test + node-splitting"
        display as result "  nma_report        " as text "- Publication-quality export (Excel/CSV)"
        display as text ""
        display as text "{hline 70}"
        display as text "{bf:Typical workflow:}"
        display as text ""
        display as text "  1. {cmd:nma_setup}          " as text "Prepare arm-level summary data"
        display as text "  2. {cmd:nma_map}            " as text "Visualize network geometry"
        display as text "  3. {cmd:nma_fit}            " as text "Fit consistency model"
        display as text "  4. {cmd:nma_forest}         " as text "Forest plot of results"
        display as text "  5. {cmd:nma_rank}           " as text "Rank treatments (SUCRA)"
        display as text "  6. {cmd:nma_inconsistency}  " as text "Check for inconsistency"
        display as text "  7. {cmd:nma_compare}        " as text "League table"
        display as text "  8. {cmd:nma_report}         " as text "Export results"
        display as text ""
        display as text "Help:  " as result "{help nma}" as text "  for documentation"
        display as text "       " as result "{help nma_setup}" as text "  to get started"
    }

    display as text "{hline 70}"

    return local version "`version'"
    return local commands "`all_commands'"
    return scalar n_commands = `n_commands'
end

program define _nma_overview_detail
    version 16.0
    set varabbrev off
    set more off

    display as text ""
    display as text "{bf:Data Setup}"
    display as text "  {hline 60}"
    display as result "  nma_setup" as text "    Import arm-level summary data for NMA."
    display as text "              Supports binary (events/total), continuous"
    display as text "              (mean/sd/n), and rate (events/person-time)"
    display as text "              outcomes. Auto-detects type, computes"
    display as text "              contrasts, validates network connectivity."
    display as text ""
    display as result "  nma_import" as text "   Import pre-computed effect sizes with SEs."
    display as text "              For published data, hazard ratios from Cox"
    display as text "              models, or other pre-calculated estimates."
    display as text ""

    display as text "{bf:Model Fitting}"
    display as text "  {hline 60}"
    display as result "  nma_fit" as text "      Fit the NMA consistency model using REML"
    display as text "              (default) or ML estimation. Multivariate"
    display as text "              random-effects via Mata engine. Posts to e()."
    display as text ""

    display as text "{bf:Post-Estimation}"
    display as text "  {hline 60}"
    display as result "  nma_rank" as text "     Monte Carlo treatment rankings. SUCRA"
    display as text "              scores and cumulative rankograms."
    display as text ""
    display as result "  nma_forest" as text "   Forest plot of treatment effects vs"
    display as text "              reference. Shows CIs and evidence type."
    display as text ""
    display as result "  nma_map" as text "      Network geometry plot. Nodes sized by"
    display as text "              studies, edges weighted by precision."
    display as text ""
    display as result "  nma_compare" as text "  K x K league table of all pairwise"
    display as text "              comparisons with confidence intervals."
    display as text ""

    display as text "{bf:Diagnostics & Reporting}"
    display as text "  {hline 60}"
    display as result "  nma_inconsistency" as text ""
    display as text "              Global inconsistency test and node-splitting."
    display as text "              Node-splitting only on mixed-evidence pairs."
    display as text ""
    display as result "  nma_report" as text "   Export results to Excel or CSV."
    display as text "              Customizable sections."
    display as text ""
end
