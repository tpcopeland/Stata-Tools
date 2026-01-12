*! tabtools Version 1.0.0  2026/01/08
*! Suite of table export commands for publication-ready Excel output
*! Author: Timothy P Copeland
*! Department of Clinical Neuroscience, Karolinska Institutet
*! Program class: rclass (returns results in r())

/*
Basic syntax:
  tabtools [, list detail category(string)]

Optional options:
  list            - Display commands as a simple list
  detail          - Show detailed information with descriptions
  category(string) - Filter by category: descriptive, models, rates, general, all

Returns:
  r(commands)     - List of all command names
  r(n_commands)   - Number of commands
  r(version)      - Package version

See help tabtools for complete documentation
*/

program define tabtools, rclass
    version 16.0
    set varabbrev off

    syntax [, List Detail Category(string)]

    // Default category is all
    if "`category'" == "" local category "all"

    // Validate category option
    local category = lower("`category'")
    if !inlist("`category'", "all", "descriptive", "models", "rates", "general") {
        display as error "category() must be: all, descriptive, models, rates, or general"
        exit 198
    }

    // Define commands by category
    local cmd_descriptive "table1_tc"
    local cmd_models "regtab effecttab gformtab"
    local cmd_rates "stratetab"
    local cmd_general "tablex"

    // Build selected list based on category
    if "`category'" == "descriptive" {
        local selected_cmds "`cmd_descriptive'"
    }
    else if "`category'" == "models" {
        local selected_cmds "`cmd_models'"
    }
    else if "`category'" == "rates" {
        local selected_cmds "`cmd_rates'"
    }
    else if "`category'" == "general" {
        local selected_cmds "`cmd_general'"
    }
    else {
        local selected_cmds "`cmd_descriptive' `cmd_models' `cmd_rates' `cmd_general'"
    }

    // Count commands
    local n_commands: word count `selected_cmds'

    // Display header
    display as text ""
    display as text "{hline 70}"
    display as result "tabtools" as text " - Publication-Ready Table Export Suite"
    display as text "{hline 70}"
    display as text ""

    // Display based on options
    if "`detail'" != "" {
        // Detailed view with descriptions
        _tabtools_detail, category(`category')
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
        if inlist("`category'", "all", "descriptive") {
            display as text "{bf:Descriptive Statistics}"
            display as result "  table1_tc  " as text "- Table 1 with automatic statistical tests"
            display as text ""
        }

        if inlist("`category'", "all", "models") {
            display as text "{bf:Model Results}"
            display as result "  regtab     " as text "- Regression results from any estimation command"
            display as result "  effecttab  " as text "- Treatment effects and margins results"
            display as result "  gformtab   " as text "- G-formula mediation analysis results"
            display as text ""
        }

        if inlist("`category'", "all", "rates") {
            display as text "{bf:Incidence Rates}"
            display as result "  stratetab  " as text "- Incidence rates from strate output"
            display as text ""
        }

        if inlist("`category'", "all", "general") {
            display as text "{bf:General Purpose}"
            display as result "  tablex     " as text "- Flexible table export wrapper"
            display as text ""
        }

        display as text "{hline 70}"
        display as text "Total commands: " as result "`n_commands'"
        display as text ""
        display as text "Help: " as result "help tabtools" as text " for overview"
        display as text "      " as result "help <command>" as text " for individual command help"
    }

    // Return results
    return local commands "`selected_cmds'"
    return scalar n_commands = `n_commands'
    return local version "1.0.0"
    return local categories "descriptive models rates general"
end

// Subroutine for detailed display
program define _tabtools_detail
    syntax , Category(string)

    if inlist("`category'", "all", "descriptive") {
        display as text "{bf:Descriptive Statistics}"
        display as text "  {hline 60}"
        display as result "  table1_tc" as text "    Create publication-ready Table 1 with descriptive"
        display as text "               statistics. Automatically selects appropriate"
        display as text "               tests (t-test, Wilcoxon, chi-square, Fisher's"
        display as text "               exact) based on variable type and distribution."
        display as text "               Supports continuous, categorical, and binary"
        display as text "               variables with customizable formatting."
        display as text ""
    }

    if inlist("`category'", "all", "models") {
        display as text "{bf:Model Results}"
        display as text "  {hline 60}"
        display as result "  regtab" as text "       Export regression results from any estimation"
        display as text "               command to Excel. Supports logistic, Cox, Poisson,"
        display as text "               linear, and other models. Configurable columns"
        display as text "               for coefficients, confidence intervals, p-values,"
        display as text "               and model statistics."
        display as text ""
        display as result "  effecttab" as text "    Export treatment effects and margins results."
        display as text "               Works with margins, contrast, and effect commands."
        display as text "               Formats average marginal effects, predictive"
        display as text "               margins, and interaction contrasts."
        display as text ""
        display as result "  gformtab" as text "     Export G-formula mediation analysis results."
        display as text "               Presents total, direct, and indirect effects"
        display as text "               with confidence intervals from gformula output."
        display as text "               Useful for causal mediation analysis."
        display as text ""
    }

    if inlist("`category'", "all", "rates") {
        display as text "{bf:Incidence Rates}"
        display as text "  {hline 60}"
        display as result "  stratetab" as text "    Export stratified incidence rates from strate"
        display as text "               command output. Formats person-time, events,"
        display as text "               rates, and confidence intervals. Supports"
        display as text "               rate ratios and stratified analyses."
        display as text ""
    }

    if inlist("`category'", "all", "general") {
        display as text "{bf:General Purpose}"
        display as text "  {hline 60}"
        display as result "  tablex" as text "       Flexible wrapper for exporting any Stata table"
        display as text "               to Excel. Applies consistent professional"
        display as text "               formatting: column widths, borders, fonts,"
        display as text "               merged headers, and styling. Works with"
        display as text "               matrices and stored results."
        display as text ""
    }
end
