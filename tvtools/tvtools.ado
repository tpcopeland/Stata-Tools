*! tvtools Version 1.4.0  2025/12/26
*! A suite of commands for time-varying exposure analysis
*! Author: Timothy P Copeland
*! Department of Clinical Neuroscience, Karolinska Institutet
*! Program class: rclass (returns results in r())

/*
Basic syntax:
  tvtools [, list detail category(string)]

Optional options:
  list            - Display commands as a simple list
  detail          - Show detailed information with descriptions
  category(string) - Filter by category: prep, diag, weight, special, report, all

Returns:
  r(commands)     - List of all command names
  r(n_commands)   - Number of commands
  r(version)      - Package version

See help tvtools for complete documentation
*/

program define tvtools, rclass
    version 16.0
    set varabbrev off

    syntax [, List Detail Category(string)]

    // Default category is all
    if "`category'" == "" local category "all"

    // Validate category option
    local category = lower("`category'")
    if !inlist("`category'", "all", "prep", "diag", "weight", "special", "report") {
        display as error "category() must be: all, prep, diag, weight, special, or report"
        exit 198
    }

    // Define commands by category
    local cmd_prep "tvexpose tvmerge tvevent tvcalendar tvage"
    local cmd_diag "tvdiagnose tvplot tvbalance"
    local cmd_weight "tvweight tvestimate tvdml"
    local cmd_special "tvtrial tvsensitivity tvpass"
    local cmd_report "tvtable tvreport tvpipeline"

    // Build selected list based on category
    if "`category'" == "prep" {
        local selected_cmds "`cmd_prep'"
    }
    else if "`category'" == "diag" {
        local selected_cmds "`cmd_diag'"
    }
    else if "`category'" == "weight" {
        local selected_cmds "`cmd_weight'"
    }
    else if "`category'" == "special" {
        local selected_cmds "`cmd_special'"
    }
    else if "`category'" == "report" {
        local selected_cmds "`cmd_report'"
    }
    else {
        local selected_cmds "`cmd_prep' `cmd_diag' `cmd_weight' `cmd_special' `cmd_report'"
    }

    // Count commands
    local n_commands: word count `selected_cmds'

    // Display header
    display as text ""
    display as text "{hline 70}"
    display as result "tvtools" as text " - Time-Varying Exposure Analysis Suite"
    display as text "{hline 70}"
    display as text ""

    // Display based on options
    if "`detail'" != "" {
        // Detailed view with descriptions
        _tvtools_detail, category(`category')
    }
    else if "`list'" != "" {
        // Simple list view
        display as text "Available commands (`category'):"
        display as text ""
        foreach cmd of local selected_cmds {
            display as result "  `cmd'"
        }
    }
    else {
        // Default: organized view
        if inlist("`category'", "all", "prep") {
            display as text "{bf:Data Preparation}"
            display as result "  tvexpose   " as text "- Create time-varying exposure variables"
            display as result "  tvmerge    " as text "- Merge multiple time-varying datasets"
            display as result "  tvevent    " as text "- Integrate events and competing risks"
            display as result "  tvcalendar " as text "- Merge calendar-time external factors"
            display as result "  tvage      " as text "- Add time-varying age to stset data"
            display as text ""
        }

        if inlist("`category'", "all", "diag") {
            display as text "{bf:Diagnostics & Visualization}"
            display as result "  tvdiagnose " as text "- Diagnostic tools for TV datasets"
            display as result "  tvplot     " as text "- Visualization tools for TV data"
            display as result "  tvbalance  " as text "- Balance diagnostics for TV exposures"
            display as text ""
        }

        if inlist("`category'", "all", "weight") {
            display as text "{bf:Weighting & Estimation}"
            display as result "  tvweight   " as text "- Calculate IPTW weights"
            display as result "  tvestimate " as text "- G-estimation for structural models"
            display as result "  tvdml      " as text "- Double/Debiased ML for causal inference"
            display as text ""
        }

        if inlist("`category'", "all", "special") {
            display as text "{bf:Special Applications}"
            display as result "  tvtrial    " as text "- Target trial emulation"
            display as result "  tvsensitivity " as text "- Sensitivity analysis"
            display as result "  tvpass     " as text "- PASS/PAES workflow support"
            display as text ""
        }

        if inlist("`category'", "all", "report") {
            display as text "{bf:Reporting & Workflow}"
            display as result "  tvtable    " as text "- Publication-ready summary tables"
            display as result "  tvreport   " as text "- Automated analysis reports"
            display as result "  tvpipeline " as text "- Complete workflow automation"
            display as text ""
        }

        display as text "{hline 70}"
        display as text "Total commands: " as result "`n_commands'"
        display as text ""
        display as text "Help: " as result "help tvtools" as text " for workflow guide"
        display as text "      " as result "help <command>" as text " for individual command help"
    }

    // Return results
    return local commands "`selected_cmds'"
    return scalar n_commands = `n_commands'
    return local version "1.4.0"
    return local categories "prep diag weight special report"
end

// Subroutine for detailed display
program define _tvtools_detail
    syntax , Category(string)

    if inlist("`category'", "all", "prep") {
        display as text "{bf:Data Preparation}"
        display as text "  {hline 60}"
        display as result "  tvexpose" as text "     Create time-varying exposure variables for"
        display as text "               survival analysis. Transforms exposure records"
        display as text "               into episode format compatible with stset."
        display as text ""
        display as result "  tvmerge" as text "      Merge multiple time-varying exposure datasets."
        display as text "               Handles overlapping time periods and validates"
        display as text "               data structure integrity."
        display as text ""
        display as result "  tvevent" as text "      Integrate events and competing risks into"
        display as text "               time-varying datasets. Supports multiple event"
        display as text "               types and censoring."
        display as text ""
        display as result "  tvcalendar" as text "   Merge calendar-time external factors like"
        display as text "               policy periods, seasons, or secular trends."
        display as text ""
        display as result "  tvage" as text "        Add time-varying age to stset data. Updates"
        display as text "               age as analysis time progresses."
        display as text ""
    }

    if inlist("`category'", "all", "diag") {
        display as text "{bf:Diagnostics & Visualization}"
        display as text "  {hline 60}"
        display as result "  tvdiagnose" as text "   Diagnostic tools for time-varying exposure"
        display as text "               datasets. Checks data structure, identifies"
        display as text "               gaps, and validates episode integrity."
        display as text ""
        display as result "  tvplot" as text "       Visualization tools for time-varying data."
        display as text "               Exposure timelines, Kaplan-Meier curves, and"
        display as text "               covariate trajectories."
        display as text ""
        display as result "  tvbalance" as text "    Balance diagnostics for time-varying exposures."
        display as text "               SMDs and covariate balance over time."
        display as text ""
    }

    if inlist("`category'", "all", "weight") {
        display as text "{bf:Weighting & Estimation}"
        display as text "  {hline 60}"
        display as result "  tvweight" as text "     Calculate inverse probability of treatment"
        display as text "               weights (IPTW) for time-varying confounding."
        display as text ""
        display as result "  tvestimate" as text "   G-estimation for structural nested models."
        display as text "               Handles time-varying treatments and confounders."
        display as text ""
        display as result "  tvdml" as text "        Double/Debiased Machine Learning for causal"
        display as text "               inference with high-dimensional confounders."
        display as text ""
    }

    if inlist("`category'", "all", "special") {
        display as text "{bf:Special Applications}"
        display as text "  {hline 60}"
        display as result "  tvtrial" as text "      Target trial emulation for observational data."
        display as text "               Clone-censor-weight approach for per-protocol."
        display as text ""
        display as result "  tvsensitivity" as text " Sensitivity analysis for unmeasured confounding."
        display as text "               E-values and bias-adjusted estimates."
        display as text ""
        display as result "  tvpass" as text "       Post-authorization study (PASS/PAES) workflow"
        display as text "               support for regulatory submissions."
        display as text ""
    }

    if inlist("`category'", "all", "report") {
        display as text "{bf:Reporting & Workflow}"
        display as text "  {hline 60}"
        display as result "  tvtable" as text "      Publication-ready summary tables for TV analyses."
        display as text "               Person-time, events, rates by exposure."
        display as text ""
        display as result "  tvreport" as text "     Automated analysis report generation."
        display as text "               Comprehensive output for documentation."
        display as text ""
        display as result "  tvpipeline" as text "   Complete workflow automation. Chains multiple"
        display as text "               tvtools commands for reproducible analysis."
        display as text ""
    }
end
