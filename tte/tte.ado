*! tte Version 1.1.0  2026/03/15
*! Target Trial Emulation suite for Stata
*! Author: Timothy P Copeland
*! Author: Tania F Reza
*! Department of Clinical Neuroscience, Karolinska Institutet
*! Department of Global Public Health, Karolinska Institutet
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
    local _vaset = c(varabbrev)
    set varabbrev off
    set more off

    syntax [, List Detail PROTocol]

    local version "1.1.0"
    local n_commands = 11

    * All user-facing commands
    local all_commands "tte_prepare tte_validate tte_expand tte_weight tte_fit tte_predict tte_diagnose tte_plot tte_report tte_protocol tte_calibrate"

    display as text ""
    display as text "{hline 70}"
    display as result "tte" as text " - Target Trial Emulation for Stata"
    display as text "Version `version'"
    display as text "{hline 70}"

    if "`protocol'" != "" {
        _tte_protocol_overview
    }
    else if "`detail'" != "" {
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
        display as result "  tte_protocol " as text "- Target trial protocol table (Hernán 7-component)"
        display as result "  tte_calibrate" as text "- Negative control outcome calibration"
        display as text ""
        display as text "{hline 70}"
        display as text "{bf:Typical workflow:}"
        display as text ""
        display as text "  0. {cmd:tte_protocol} " as text "Define target trial (Hernán 7-component)"
        display as text "  1. {cmd:tte_prepare}  " as text "Map variables, set estimand (ITT/PP/AT)"
        display as text "  2. {cmd:tte_validate}  " as text "Check data quality"
        display as text "  3. {cmd:tte_expand}   " as text "Create sequential emulated trials"
        display as text "  4. {cmd:tte_weight}   " as text "Calculate stabilized IP weights"
        display as text "  5. {cmd:tte_fit}      " as text "Fit marginal structural model"
        display as text "  6. {cmd:tte_predict}  " as text "Estimate cumulative incidence"
        display as text "  7. {cmd:tte_report}   " as text "Export publication tables"
        display as text "     {cmd:tte_protocol, auto} " as text "Auto-generate protocol from metadata"
        display as text ""
        display as text "Help:  " as result "{help tte}" as text "  for documentation"
        display as text "       " as result "{help tte_prepare}" as text "  to get started"
    }

    display as text "{hline 70}"

    return local version "`version'"
    return local commands "`all_commands'"
    return scalar n_commands = `n_commands'

    set varabbrev `_vaset'
end

program define _tte_protocol_overview
    version 16.0
    set varabbrev off
    set more off

    display as text ""
    display as text "{bf:Hernán & Robins (2016) 7-Component Framework}"
    display as text ""
    display as text "  Every target trial emulation must specify:"
    display as text ""
    display as text "  {result:1. Eligibility criteria}"
    display as text "     Who is eligible to enter the trial at each time point?"
    display as text "     Example: Age >= 18, no prior outcome event, >= 1 year follow-up"
    display as text ""
    display as text "  {result:2. Treatment strategies}"
    display as text "     What treatments are being compared?"
    display as text "     Example: Initiate drug A vs. do not initiate drug A"
    display as text ""
    display as text "  {result:3. Treatment assignment}"
    display as text "     How is treatment assigned in the observational data?"
    display as text "     Example: Patients assigned at each eligible period based on"
    display as text "     physician decision (emulates randomization at baseline)"
    display as text ""
    display as text "  {result:4. Start of follow-up (time zero)}"
    display as text "     When does follow-up begin for each emulated trial?"
    display as text "     Example: Start of each eligible period (eligibility = assignment)"
    display as text ""
    display as text "  {result:5. Outcome}"
    display as text "     What is the outcome of interest?"
    display as text "     Example: All-cause mortality within 5 years"
    display as text ""
    display as text "  {result:6. Causal contrast}"
    display as text "     ITT (intention-to-treat) or PP (per-protocol)?"
    display as text "     ITT: analyze as initially assigned regardless of switching"
    display as text "     PP: censor at deviation, reweight with IPTW"
    display as text ""
    display as text "  {result:7. Statistical analysis}"
    display as text "     What model and estimation approach?"
    display as text "     Example: Pooled logistic regression with robust SE,"
    display as text "     clustered by individual, adjusted for confounders"
    display as text ""
    display as text "{hline 70}"
    display as text "{bf:Document your protocol with} {cmd:tte_protocol}:"
    display as text ""
    display as text `"  {cmd:tte_protocol, eligibility("Age >= 18, no prior event")}"'
    display as text `"      {cmd:treatment("Initiate drug vs no drug")}"'
    display as text `"      {cmd:assignment("At each eligible period")}"'
    display as text `"      {cmd:followup_start("Start of eligible period")}"'
    display as text `"      {cmd:outcome("All-cause mortality")}"'
    display as text `"      {cmd:causal_contrast("Per-protocol effect")}"'
    display as text `"      {cmd:analysis("Pooled logistic with IPCW")}"'
    display as text `"      {cmd:export(protocol.xlsx) format(excel) replace}"'
    display as text ""
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
    display as result "  tte_protocol" as text "  Hernán 7-component protocol specification"
    display as text "              table for the methods section."
    display as text ""
    display as result "  tte_calibrate" as text " Negative control outcome calibration using"
    display as text "              empirical null distribution (Schuemie 2014)."
    display as text ""
end
