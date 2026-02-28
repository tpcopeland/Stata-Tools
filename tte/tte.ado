*! tte Version 1.0.3  2026/03/01
*! Target Trial Emulation suite for Stata
*! Author: Timothy P Copeland
*! Department of Clinical Neuroscience, Karolinska Institutet
*! Program class: rclass (returns results in r())

/*
Basic syntax:
  tte [, list detail]

Description:
  Displays package overview, lists all commands with descriptions,
  and shows the typical analysis workflow.

See help tte for complete documentation
*/

program define tte, rclass
    version 16.0
    set varabbrev off
    set more off

    syntax [, List Detail]

    local version "1.0.2"
    local n_commands = 10

    * All user-facing commands
    local all_commands "tte_prepare tte_validate tte_expand tte_weight tte_fit tte_predict tte_diagnose tte_plot tte_report tte_protocol"

    display as text ""
    display as text "{hline 70}"
    display as result "tte" as text " - Target Trial Emulation for Stata"
    display as text "Version `version'"
    display as text "{hline 70}"

    if "`detail'" != "" {
        _tte_overview_detail
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
        display as text "{bf:Data Preparation}"
        display as result "  tte_prepare  " as text "- Validate and map variables for analysis"
        display as result "  tte_validate " as text "- Data quality checks and diagnostics"
        display as text ""
        display as text "{bf:Core Analysis}"
        display as result "  tte_expand   " as text "- Sequential trial expansion (clone-censor)"
        display as result "  tte_weight   " as text "- Inverse probability weights (IPTW/IPCW)"
        display as result "  tte_fit      " as text "- Outcome modeling (logistic/Cox MSM)"
        display as result "  tte_predict  " as text "- Marginal predictions with confidence intervals"
        display as text ""
        display as text "{bf:Diagnostics & Reporting}"
        display as result "  tte_diagnose " as text "- Weight diagnostics and balance assessment"
        display as result "  tte_plot     " as text "- KM curves, cumulative incidence, weight plots"
        display as result "  tte_report   " as text "- Publication-quality results tables"
        display as result "  tte_protocol " as text "- Target trial protocol table (Hernan 7-component)"
        display as text ""
        display as text "{hline 70}"
        display as text "{bf:Typical workflow:}"
        display as text ""
        display as text "  1. {cmd:tte_prepare}  " as text "Map variables, set estimand (ITT/PP/AT)"
        display as text "  2. {cmd:tte_validate}  " as text "Check data quality"
        display as text "  3. {cmd:tte_expand}   " as text "Create sequential emulated trials"
        display as text "  4. {cmd:tte_weight}   " as text "Calculate stabilized IP weights"
        display as text "  5. {cmd:tte_fit}      " as text "Fit marginal structural model"
        display as text "  6. {cmd:tte_predict}  " as text "Estimate cumulative incidence"
        display as text "  7. {cmd:tte_report}   " as text "Export publication tables"
        display as text ""
        display as text "Help:  " as result "{help tte}" as text "  for documentation"
        display as text "       " as result "{help tte_prepare}" as text "  to get started"
    }

    display as text "{hline 70}"

    return local version "`version'"
    return local commands "`all_commands'"
    return scalar n_commands = `n_commands'
end

program define _tte_overview_detail
    version 16.0
    set varabbrev off
    set more off

    display as text ""
    display as text "{bf:Data Preparation}"
    display as text "  {hline 60}"
    display as result "  tte_prepare" as text "   Map variable names, set estimand, validate"
    display as text "              data structure. Entry point for the pipeline."
    display as text "              Stores metadata for downstream commands."
    display as text ""
    display as result "  tte_validate" as text "  Comprehensive data quality checks: person-"
    display as text "              period format, gaps, treatment consistency,"
    display as text "              positivity, and missing data patterns."
    display as text ""

    display as text "{bf:Core Analysis}"
    display as text "  {hline 60}"
    display as result "  tte_expand" as text "    Clone-censor-weight expansion into sequential"
    display as text "              emulated trials. Handles ITT, PP, and AT"
    display as text "              estimands with grace period support."
    display as text ""
    display as result "  tte_weight" as text "    Stabilized inverse probability weights for"
    display as text "              treatment switching and informative censoring."
    display as text "              Logistic models with truncation support."
    display as text ""
    display as result "  tte_fit" as text "       Marginal structural model: pooled logistic"
    display as text "              regression or weighted Cox model. Flexible"
    display as text "              time specifications (linear/quadratic/ns)."
    display as text ""
    display as result "  tte_predict" as text "   Monte Carlo predictions from coefficient"
    display as text "              distribution. Cumulative incidence, survival,"
    display as text "              and risk differences with confidence intervals."
    display as text ""

    display as text "{bf:Diagnostics & Reporting}"
    display as text "  {hline 60}"
    display as result "  tte_diagnose" as text "  Weight distribution, effective sample size,"
    display as text "              covariate balance (SMD), and positivity checks."
    display as text ""
    display as result "  tte_plot" as text "      Visualization: KM curves, cumulative incidence,"
    display as text "              weight distributions, and Love plots."
    display as text ""
    display as result "  tte_report" as text "    Publication-quality tables exportable to"
    display as text "              Excel or CSV format."
    display as text ""
    display as result "  tte_protocol" as text "  Hernan 7-component protocol specification"
    display as text "              table for the methods section."
    display as text ""
end
