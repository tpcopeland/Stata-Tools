*! msm Version 1.0.1  2026/03/14
*! Marginal Structural Models suite for Stata
*! Author: Timothy P Copeland
*! Department of Clinical Neuroscience, Karolinska Institutet
*! Program class: rclass (returns results in r())

/*
Basic syntax:
  msm [, list detail protocol]

Description:
  Displays package overview, lists all commands with descriptions,
  and shows the typical analysis workflow.

See help msm for complete documentation
*/

program define msm, rclass
    version 16.0
    local _varabbrev = c(varabbrev)
    local _more = c(more)
    set varabbrev off
    set more off

    capture noisily {

    syntax [, List Detail PROTocol]

    local version "1.0.0"
    local n_commands = 11

    * All user-facing commands
    local all_commands "msm_prepare msm_validate msm_weight msm_diagnose msm_fit msm_predict msm_plot msm_table msm_report msm_protocol msm_sensitivity"

    display as text ""
    display as text "{hline 70}"
    display as result "msm" as text " - Marginal Structural Models for Stata"
    display as text "Version `version'"
    display as text "{hline 70}"

    if "`protocol'" != "" {
        _msm_protocol_overview
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
        display as text "{bf:Data Preparation}"
        display as result "  msm_prepare     " as text "- Map variables and store metadata"
        display as result "  msm_validate    " as text "- Data quality checks (10 diagnostics)"
        display as text ""
        display as text "{bf:Core Engine}"
        display as result "  msm_weight      " as text "- Stabilized IPTW (+ optional IPCW)"
        display as result "  msm_fit         " as text "- Weighted outcome model (GLM/Cox)"
        display as result "  msm_predict     " as text "- Counterfactual predictions with CIs"
        display as text ""
        display as text "{bf:Diagnostics & Reporting}"
        display as result "  msm_diagnose    " as text "- Weight distribution and covariate balance"
        display as result "  msm_plot        " as text "- Weights, balance, survival, trajectory plots"
        display as result "  msm_table       " as text "- Publication-quality Excel tables"
        display as result "  msm_report      " as text "- Publication-quality results tables"
        display as result "  msm_protocol    " as text "- MSM study protocol (7 components)"
        display as result "  msm_sensitivity " as text "- E-value and confounding bounds"
        display as text ""
        display as text "{hline 70}"
        display as text "{bf:Typical workflow:}"
        display as text ""
        display as text "  0. {cmd:msm_protocol}    " as text "Document study protocol"
        display as text "  1. {cmd:msm_prepare}     " as text "Map variables"
        display as text "  2. {cmd:msm_validate}    " as text "Check data quality"
        display as text "  3. {cmd:msm_weight}      " as text "Calculate stabilized IP weights"
        display as text "  4. {cmd:msm_diagnose}    " as text "Assess weight distribution and balance"
        display as text "  5. {cmd:msm_fit}         " as text "Fit weighted outcome model"
        display as text "  6. {cmd:msm_predict}     " as text "Estimate counterfactual outcomes"
        display as text "  7. {cmd:msm_table}       " as text "Export Excel tables"
        display as text "  8. {cmd:msm_report}      " as text "Export publication tables"
        display as text "  9. {cmd:msm_sensitivity} " as text "Sensitivity analysis"
        display as text ""
        display as text "Help:  " as result "{help msm}" as text "  for documentation"
        display as text "       " as result "{help msm_prepare}" as text "  to get started"
    }

    display as text "{hline 70}"

    return local version "`version'"
    return local commands "`all_commands'"
    return scalar n_commands = `n_commands'

    } /* end capture noisily */
    local _rc = _rc

    set varabbrev `_varabbrev'
    set more `_more'

    if `_rc' exit `_rc'
end

program define _msm_protocol_overview
    version 16.0
    set varabbrev off
    set more off

    display as text ""
    display as text "{bf:MSM Study Protocol (7 Components)}"
    display as text ""
    display as text "  Adapted from Robins, Hernan & Brumback (2000)"
    display as text ""
    display as text "  {result:1. Population}"
    display as text "     Who is in the study? Inclusion/exclusion criteria."
    display as text ""
    display as text "  {result:2. Treatment strategies}"
    display as text "     What treatment regimes are being compared?"
    display as text "     Example: Always treated vs. never treated"
    display as text ""
    display as text "  {result:3. Confounders}"
    display as text "     Time-varying and baseline confounders measured."
    display as text "     Example: Biomarker (time-varying), age, sex (baseline)"
    display as text ""
    display as text "  {result:4. Outcome}"
    display as text "     What is the outcome of interest?"
    display as text "     Example: All-cause mortality"
    display as text ""
    display as text "  {result:5. Causal contrast}"
    display as text "     What causal parameter is being estimated?"
    display as text "     Example: Average treatment effect under always vs. never"
    display as text ""
    display as text "  {result:6. Weight specification}"
    display as text "     How are IP weights constructed?"
    display as text "     Example: Stabilized IPTW with 1/99 truncation"
    display as text ""
    display as text "  {result:7. Statistical analysis}"
    display as text "     What model and estimation approach?"
    display as text "     Example: Pooled logistic regression with robust SE"
    display as text ""
end

program define _msm_overview_detail
    version 16.0
    set varabbrev off
    set more off

    display as text ""
    display as text "{bf:Data Preparation}"
    display as text "  {hline 60}"
    display as result "  msm_prepare" as text "     Map variable names, validate data structure."
    display as text "                Entry point for the pipeline. Stores"
    display as text "                metadata in dataset characteristics."
    display as text ""
    display as result "  msm_validate" as text "    Comprehensive data quality checks: person-"
    display as text "                period format, gaps, treatment variation,"
    display as text "                positivity, and missing data patterns."
    display as text ""

    display as text "{bf:Core Engine}"
    display as text "  {hline 60}"
    display as result "  msm_weight" as text "      Stabilized inverse probability of treatment"
    display as text "                weights (IPTW) with optional IPCW for"
    display as text "                informative censoring. Logistic models"
    display as text "                with cumulative product via log-sum."
    display as text ""
    display as result "  msm_fit" as text "         Weighted outcome model: pooled logistic"
    display as text "                regression (GLM), linear, or Cox PH."
    display as text "                Robust/sandwich SE clustered by individual."
    display as text ""
    display as result "  msm_predict" as text "     Counterfactual predictions under always-"
    display as text "                treated vs never-treated strategies."
    display as text "                Monte Carlo CIs via Cholesky decomposition."
    display as text ""

    display as text "{bf:Diagnostics & Reporting}"
    display as text "  {hline 60}"
    display as result "  msm_diagnose" as text "    Weight distribution, effective sample size,"
    display as text "                covariate balance (SMD before/after)."
    display as text ""
    display as result "  msm_plot" as text "        Visualization: weight densities, Love plots,"
    display as text "                survival curves, treatment trajectories,"
    display as text "                and positivity assessment."
    display as text ""
    display as result "  msm_report" as text "      Publication-quality tables: analysis summary,"
    display as text "                weight diagnostics, model coefficients."
    display as text "                Export to display, CSV, or Excel."
    display as text ""
    display as result "  msm_protocol" as text "    MSM study protocol: 7-component specification"
    display as text "                adapted from Robins, Hernan & Brumback."
    display as text ""
    display as result "  msm_sensitivity" as text " E-value (VanderWeele & Ding 2017) and"
    display as text "                confounding strength bounds for"
    display as text "                unmeasured confounding assessment."
    display as text ""
end
