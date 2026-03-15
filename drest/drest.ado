*! drest Version 1.0.0  2026/03/15
*! Doubly Robust Estimation for Stata
*! Author: Timothy P Copeland
*! Department of Clinical Neuroscience, Karolinska Institutet
*! Program class: rclass (returns results in r())

/*
Basic syntax:
  drest [, list detail]

Description:
  Displays package overview, lists all commands with descriptions,
  and shows the typical analysis workflow for doubly robust
  estimation.

See help drest for complete documentation
*/

program define drest, rclass
    version 16.0
    local _vaset = c(varabbrev)
    set varabbrev off
    set more off

    syntax [, List Detail]

    local version "1.0.0"
    local n_commands = 11

    local all_commands "drest_estimate drest_crossfit drest_tmle drest_ltmle drest_diagnose drest_compare drest_predict drest_bootstrap drest_plot drest_report drest_sensitivity"

    display as text ""
    display as text "{hline 70}"
    display as result "drest" as text " - Doubly Robust Estimation for Stata"
    display as text "Version `version'"
    display as text "{hline 70}"

    if "`detail'" != "" {
        _drest_overview_detail
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
        display as text "{bf:Estimation}"
        display as result "  drest_estimate  " as text "- AIPW doubly robust estimation (ATE/ATT/ATC)"
        display as result "  drest_crossfit  " as text "- Cross-fitted AIPW (DML-style, K-fold)"
        display as result "  drest_tmle      " as text "- Targeted minimum loss-based estimation"
        display as result "  drest_ltmle     " as text "- Longitudinal TMLE (time-varying treatments)"
        display as text ""
        display as text "{bf:Diagnostics & Comparison}"
        display as result "  drest_diagnose  " as text "- Overlap, propensity, influence, balance"
        display as result "  drest_compare   " as text "- Side-by-side IPTW vs g-comp vs AIPW"
        display as result "  drest_sensitivity" as text " - E-value sensitivity analysis"
        display as text ""
        display as text "{bf:Post-estimation}"
        display as result "  drest_predict   " as text "- Potential outcome predictions"
        display as result "  drest_bootstrap " as text "- Bootstrap inference"
        display as text ""
        display as text "{bf:Output}"
        display as result "  drest_plot      " as text "- Overlap, influence, treatment effect plots"
        display as result "  drest_report    " as text "- Excel/display tables"
        display as text ""
        display as text "{hline 70}"
        display as text "{bf:Typical workflow:}"
        display as text ""
        display as text "  1. {cmd:drest_estimate} x1 x2, outcome(y) treatment(a)"
        display as text "  2. {cmd:drest_diagnose}, overlap balance"
        display as text "  3. {cmd:drest_compare} x1 x2, outcome(y) treatment(a) graph"
        display as text "  4. {cmd:drest_plot}, overlap influence"
        display as text "  5. {cmd:drest_report}, excel(results.xlsx)"
        display as text "  6. {cmd:drest_sensitivity}, evalue"
        display as text ""
        display as text "Help:  " as result "{help drest}" as text "  for documentation"
        display as text "       " as result "{help drest_estimate}" as text "  to get started"
    }

    display as text "{hline 70}"

    return local version "`version'"
    return local commands "`all_commands'"
    return scalar n_commands = `n_commands'

    set varabbrev `_vaset'
end

program define _drest_overview_detail
    version 16.0
    set varabbrev off
    set more off

    display as text ""
    display as text "{bf:Estimation}"
    display as text "  {hline 60}"
    display as result "  drest_estimate" as text "  Augmented inverse probability weighting."
    display as text "                Fits separate treatment and outcome models,"
    display as text "                computes AIPW pseudo-outcomes, and returns"
    display as text "                influence-function-based standard errors."
    display as text "                Supports ATE, ATT, and ATC estimands."
    display as text ""

    display as result "  drest_crossfit" as text " Cross-fitted (sample-split) AIPW. Trains"
    display as text "                nuisance models on held-out folds to avoid"
    display as text "                overfitting bias. DML-style estimation."
    display as text ""
    display as result "  drest_tmle" as text "     Targeted Minimum Loss-Based Estimation."
    display as text "                Updates initial predictions via a targeting"
    display as text "                step that solves the efficient influence"
    display as text "                function equation. Respects model bounds."
    display as text "                Optional cross-fitting via crossfit suboption."
    display as text ""
    display as result "  drest_ltmle" as text "    Longitudinal TMLE for time-varying treatments."
    display as text "                Sequential regression backward from final"
    display as text "                period with per-period targeting. Supports"
    display as text "                censoring adjustment and tte integration."
    display as text ""

    display as text "{bf:Diagnostics & Comparison}"
    display as text "  {hline 60}"
    display as result "  drest_diagnose" as text " Propensity score overlap assessment,"
    display as text "                influence function diagnostics, covariate"
    display as text "                balance before/after weighting, and effective"
    display as text "                sample size calculation."
    display as text ""
    display as result "  drest_compare" as text "  Fits IPTW, g-computation, and AIPW on"
    display as text "                the same data and displays side-by-side"
    display as text "                results for comparison."
    display as text ""
    display as result "  drest_sensitivity" as text " E-value sensitivity analysis for"
    display as text "                unmeasured confounding (VanderWeele & Ding)."
    display as text ""

    display as text "{bf:Post-estimation}"
    display as text "  {hline 60}"
    display as result "  drest_predict" as text "  Predicted potential outcomes under each"
    display as text "                treatment arm, individual treatment effects,"
    display as text "                and propensity scores."
    display as text ""
    display as result "  drest_bootstrap" as text " Non-parametric bootstrap inference."
    display as text "                Re-fits both nuisance models per replicate."
    display as text ""

    display as text "{bf:Output}"
    display as text "  {hline 60}"
    display as result "  drest_plot" as text "     Propensity score overlap histograms,"
    display as text "                influence function distribution, and"
    display as text "                treatment effect visualization."
    display as text ""
    display as result "  drest_report" as text "   Summary tables in display or Excel format."
    display as text ""
end
