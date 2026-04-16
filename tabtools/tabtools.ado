*! tabtools Version 1.0.4  2026/04/16
*! Suite of table export commands for publication-ready Excel output
*! Author: Timothy P Copeland
*! Department of Clinical Neuroscience, Karolinska Institutet
*! Program class: rclass (returns results in r())

/*
Basic syntax:
  tabtools [subcommand] [, list detail category(string)]

Subcommands:
  (none)           - Display available commands (default)
  set key value    - Set persistent formatting default (font, fontsize, borderstyle)
  set clear        - Clear all persistent defaults
  get              - Display current persistent defaults

Optional options (display mode):
  list             - Display commands as a simple list
  detail           - Show detailed information with descriptions
  category(string) - Filter by category: descriptive, models, rates,
                     survival, diagnostics, composite, general, all

Returns:
  r(commands)     - List of all command names
  r(n_commands)   - Number of commands
  r(version)      - Package version

See help tabtools for complete documentation
*/

program define tabtools, rclass
    version 16.0
    local _prev_varabbrev = c(varabbrev)
    set varabbrev off
    capture noisily {

    * Parse anything (subcommand) separately from options
    syntax [anything(everything)] [, List Detail Category(string) ///
        font(string) fontsize(integer 0) HEADERColor(string) ///
        ZEBRAColor(string) BORDERstyle(string)]

    * Extract first token to check for subcommands
    local subcmd ""
    if `"`anything'"' != "" {
        gettoken subcmd rest : anything
        local subcmd = lower("`subcmd'")
    }

    * =========================================================================
    * SUBCOMMAND: set
    * =========================================================================
    if "`subcmd'" == "set" {
        gettoken setkey setval : rest
        local setkey = lower(strtrim("`setkey'"))
        local setval = strtrim("`setval'")

        if "`setkey'" == "clear" {
            global TABTOOLS_FONT
            global TABTOOLS_FONTSIZE
            global TABTOOLS_BORDER
            global TABTOOLS_THEME
            global TABTOOLS_HEADERCOLOR
            global TABTOOLS_ZEBRACOLOR
            global TABTOOLS_DIGITS
            global TABTOOLS_BOLDP
            display as text "tabtools: all persistent defaults cleared"
            return local action "cleared"
        }
        else if "`setkey'" == "font" {
            if "`setval'" == "" {
                display as error "tabtools set font requires a value (e.g., tabtools set font Calibri)"
                exit 198
            }
            global TABTOOLS_FONT "`setval'"
            display as text "tabtools: default font set to " as result "`setval'"
            return local font "`setval'"
        }
        else if "`setkey'" == "fontsize" {
            if "`setval'" == "" {
                display as error "tabtools set fontsize requires a value (e.g., tabtools set fontsize 11)"
                exit 198
            }
            capture confirm integer number `setval'
            if _rc {
                display as error "fontsize must be an integer"
                exit 198
            }
            if `setval' < 6 | `setval' > 72 {
                display as error "fontsize must be between 6 and 72"
                exit 198
            }
            global TABTOOLS_FONTSIZE `setval'
            display as text "tabtools: default font size set to " as result "`setval'"
            return scalar fontsize = `setval'
        }
        else if "`setkey'" == "borderstyle" {
            if !inlist("`setval'", "default", "thin", "medium", "academic") {
                display as error "borderstyle must be: default, thin, medium, or academic"
                exit 198
            }
            global TABTOOLS_BORDER "`setval'"
            display as text "tabtools: default border style set to " as result "`setval'"
            return local borderstyle "`setval'"
        }
        else if "`setkey'" == "theme" {
            * Extract the theme name (first token before any comma)
            gettoken _theme_name _rest_opts : setval, parse(",")
            local _theme_name = strtrim("`_theme_name'")
            * Remove leading comma from rest
            local _rest_opts : subinstr local _rest_opts "," "", count(local _ncomma)
            local _rest_opts = strtrim("`_rest_opts'")
            if "`_theme_name'" == "custom" {
                * Custom theme: options parsed by outer syntax (font, fontsize, headercolor, zebracolor, borderstyle)
                if "`font'" != "" global TABTOOLS_FONT "`font'"
                if `fontsize' > 0 global TABTOOLS_FONTSIZE `fontsize'
                if "`headercolor'" != "" global TABTOOLS_HEADERCOLOR "`headercolor'"
                if "`zebracolor'" != "" global TABTOOLS_ZEBRACOLOR "`zebracolor'"
                if "`borderstyle'" != "" global TABTOOLS_BORDER "`borderstyle'"
                global TABTOOLS_THEME "custom"
                display as text "tabtools: custom theme configured"
                if "`font'" != "" display as text "  font: " as result "`font'"
                if `fontsize' > 0 display as text "  fontsize: " as result "`fontsize'"
                if "`headercolor'" != "" display as text "  headercolor: " as result "`headercolor'"
                if "`zebracolor'" != "" display as text "  zebracolor: " as result "`zebracolor'"
                if "`borderstyle'" != "" display as text "  borderstyle: " as result "`borderstyle'"
                return local theme "custom"
            }
            else {
                if !inlist("`_theme_name'", "lancet", "nejm", "bmj", "apa", "jama", "plos", "nature", "cell", "annals") {
                    display as error "theme must be: lancet, nejm, bmj, apa, jama, plos, nature, cell, annals, or custom"
                    exit 198
                }
                global TABTOOLS_THEME "`_theme_name'"
                global TABTOOLS_HEADERCOLOR ""
                global TABTOOLS_ZEBRACOLOR ""
                display as text "tabtools: default theme set to " as result "`_theme_name'"
                return local theme "`_theme_name'"
            }
        }
        else if "`setkey'" == "digits" {
            if "`setval'" == "" {
                display as error "tabtools set digits requires a value (e.g., tabtools set digits 3)"
                exit 198
            }
            capture confirm integer number `setval'
            if _rc {
                display as error "digits must be an integer"
                exit 198
            }
            if `setval' < 0 | `setval' > 6 {
                display as error "digits must be between 0 and 6"
                exit 198
            }
            global TABTOOLS_DIGITS `setval'
            display as text "tabtools: default digits set to " as result "`setval'"
            return scalar digits = `setval'
        }
        else if "`setkey'" == "boldp" {
            if "`setval'" == "" {
                display as error "tabtools set boldp requires a value (e.g., tabtools set boldp 0.05)"
                exit 198
            }
            capture confirm number `setval'
            if _rc {
                display as error "boldp must be a number"
                exit 198
            }
            if `setval' <= 0 | `setval' >= 1 {
                display as error "boldp must be between 0 and 1 (exclusive)"
                exit 198
            }
            global TABTOOLS_BOLDP `setval'
            display as text "tabtools: default boldp set to " as result "`setval'"
            return scalar boldp = `setval'
        }
        else {
            display as error `"Unknown setting "`setkey'". Valid: font, fontsize, borderstyle, theme, digits, boldp, clear"'
            exit 198
        }
    }

    * =========================================================================
    * SUBCOMMAND: get
    * =========================================================================
    else if "`subcmd'" == "get" {
        display as text ""
        display as text "{hline 50}"
        display as result "tabtools" as text " - Persistent Formatting Defaults"
        display as text "{hline 50}"
        display as text ""

        local _has_any = 0

        if "$TABTOOLS_FONT" != "" {
            display as text "  Font:        " as result "$TABTOOLS_FONT"
            local _has_any = 1
        }
        if "$TABTOOLS_FONTSIZE" != "" {
            display as text "  Font size:   " as result "$TABTOOLS_FONTSIZE"
            local _has_any = 1
        }
        if "$TABTOOLS_BORDER" != "" {
            display as text "  Border:      " as result "$TABTOOLS_BORDER"
            local _has_any = 1
        }
        if "$TABTOOLS_THEME" != "" {
            display as text "  Theme:       " as result "$TABTOOLS_THEME"
            local _has_any = 1
        }
        if "$TABTOOLS_HEADERCOLOR" != "" {
            display as text "  Header color:" as result " $TABTOOLS_HEADERCOLOR"
            local _has_any = 1
        }
        if "$TABTOOLS_ZEBRACOLOR" != "" {
            display as text "  Zebra color: " as result " $TABTOOLS_ZEBRACOLOR"
            local _has_any = 1
        }
        if "$TABTOOLS_DIGITS" != "" {
            display as text "  Digits:      " as result "$TABTOOLS_DIGITS"
            local _has_any = 1
        }
        if "$TABTOOLS_BOLDP" != "" {
            display as text "  Bold p:      " as result "$TABTOOLS_BOLDP"
            local _has_any = 1
        }

        if !`_has_any' {
            display as text "  (no defaults set — using command defaults)"
        }

        display as text ""
        display as text "  Set with: " as result "tabtools set font Calibri"
        display as text "            " as result "tabtools set fontsize 11"
        display as text "            " as result "tabtools set borderstyle thin"
        display as text "            " as result "tabtools set theme lancet"
        display as text "            " as result "tabtools set digits 3"
        display as text "            " as result "tabtools set boldp 0.05"
        display as text "  Clear:    " as result "tabtools set clear"
        display as text ""

        return local font "$TABTOOLS_FONT"
        return local fontsize "$TABTOOLS_FONTSIZE"
        return local borderstyle "$TABTOOLS_BORDER"
        return local theme "$TABTOOLS_THEME"
        return local headercolor "$TABTOOLS_HEADERCOLOR"
        return local zebracolor "$TABTOOLS_ZEBRACOLOR"
        return local digits "$TABTOOLS_DIGITS"
        return local boldp "$TABTOOLS_BOLDP"
    }

    * =========================================================================
    * DEFAULT: Display commands (original behavior)
    * =========================================================================
    else {
        * If anything was passed that isn't a subcommand, error
        if "`subcmd'" != "" {
            display as error `"Unknown subcommand "`subcmd'". Use: tabtools [set|get] or tabtools [, list detail]"'
            exit 198
        }

        // Default category is all
        if "`category'" == "" local category "all"

        // Validate category option
        local category = lower("`category'")
        if !inlist("`category'", "all", "descriptive", "models", "rates", "general", "survival", "diagnostics", "composite") {
            display as error "category() must be: all, descriptive, models, rates, survival, diagnostics, composite, or general"
            exit 198
        }

        // Define commands by category
        local cmd_descriptive "table1_tc crosstab corrtab"
        local cmd_models "regtab effecttab fittab"
        local cmd_rates "stratetab"
        local cmd_survival "survtab hrtab"
        local cmd_diagnostics "diagtab"
        local cmd_composite "comptab"
        local cmd_general "tabtools tablex"

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
        else if "`category'" == "survival" {
            local selected_cmds "`cmd_survival'"
        }
        else if "`category'" == "diagnostics" {
            local selected_cmds "`cmd_diagnostics'"
        }
        else if "`category'" == "composite" {
            local selected_cmds "`cmd_composite'"
        }
        else if "`category'" == "general" {
            local selected_cmds "`cmd_general'"
        }
        else {
            local selected_cmds "`cmd_descriptive' `cmd_models' `cmd_rates' `cmd_survival' `cmd_diagnostics' `cmd_composite' `cmd_general'"
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
                display as result "  table1_tc    " as text "- Table 1 with automatic statistical tests"
                display as result "  crosstab     " as text "- Cross-tabulation with association measures"
                display as result "  corrtab      " as text "- Correlation matrix with significance"
                display as text ""
            }

            if inlist("`category'", "all", "models") {
                display as text "{bf:Model Results}"
                display as result "  regtab       " as text "- Regression results from any estimation command"
                display as result "  effecttab    " as text "- Treatment effects and margins results"
                display as result "  fittab       " as text "- Model comparison table (AIC, BIC, C-stat)"
                display as text ""
            }

            if inlist("`category'", "all", "rates") {
                display as text "{bf:Incidence Rates}"
                display as result "  stratetab    " as text "- Incidence rates from strate output"
                display as text ""
            }

            if inlist("`category'", "all", "survival") {
                display as text "{bf:Survival Analysis}"
                display as result "  survtab      " as text "- Kaplan-Meier estimates, medians, and RMST"
                display as result "  hrtab        " as text "- Multi-panel hazard ratio table (stcox/stcrreg/finegray)"
                display as text ""
            }

            if inlist("`category'", "all", "diagnostics") {
                display as text "{bf:Diagnostic Accuracy}"
                display as result "  diagtab      " as text "- Sensitivity, specificity, PPV, NPV, ROC"
                display as text ""
            }

            if inlist("`category'", "all", "composite") {
                display as text "{bf:Composite}"
                display as result "  comptab      " as text "- Combine regtab/effecttab frames into one table"
                display as text ""
            }

            if inlist("`category'", "all", "general") {
                display as text "{bf:General Purpose}"
                display as result "  tabtools     " as text "- Suite controller and persistent defaults"
                display as result "  tablex       " as text "- Flexible table export wrapper"
                display as text ""
            }

            display as text "{hline 70}"
            display as text "Total commands: " as result "`n_commands'"
            display as text ""
            display as text "Help:     " as result "help tabtools" as text " for overview"
            display as text "          " as result "help <command>" as text " for individual command help"
            display as text "Settings: " as result "tabtools set font Calibri" as text " (persistent defaults)"
            display as text "          " as result "tabtools get" as text " (view current defaults)"
        }

        // Return results
        return local commands "`selected_cmds'"
        return scalar n_commands = `n_commands'
        return local version "1.0.4"
        return local categories "descriptive models rates survival diagnostics composite general"
    }

    } // end capture noisily
    local _rc = _rc
    set varabbrev `_prev_varabbrev'
    if `_rc' exit `_rc'
end

* Subroutine for detailed display
capture program drop _tabtools_detail
program define _tabtools_detail
    version 16.0
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
        display as result "  crosstab" as text "     Cross-tabulation with row/column percentages"
        display as text "               and association measures. Supports chi-square,"
        display as text "               Fisher's exact, odds ratios, and risk ratios."
        display as text ""
        display as result "  corrtab" as text "      Correlation matrix with significance stars or"
        display as text "               p-values. Supports Pearson and Spearman. Exports"
        display as text "               lower, upper, or full triangle to Excel."
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
        display as result "  fittab" as text "       Compare stored estimation results side-by-side"
        display as text "               with fit statistics (N, AIC, BIC, log-likelihood,"
        display as text "               C-statistic, R-squared). Highlights best-fitting"
        display as text "               model."
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

    if inlist("`category'", "all", "survival") {
        display as text "{bf:Survival Analysis}"
        display as text "  {hline 60}"
        display as result "  survtab" as text "      Export Kaplan-Meier estimates, median survival,"
        display as text "               and restricted mean survival time (RMST) to"
        display as text "               Excel. Supports multiple groups and time points."
        display as text ""
        display as result "  hrtab" as text "        Multi-panel hazard ratio table for stcox,"
        display as text "               stcrreg, and finegray with person-years and"
        display as text "               event counts."
        display as text ""
    }

    if inlist("`category'", "all", "diagnostics") {
        display as text "{bf:Diagnostic Accuracy}"
        display as text "  {hline 60}"
        display as result "  diagtab" as text "      Export sensitivity, specificity, PPV, NPV, and"
        display as text "               ROC analysis results. Supports multiple cutpoints"
        display as text "               and diagnostic tests."
        display as text ""
    }

    if inlist("`category'", "all", "composite") {
        display as text "{bf:Composite}"
        display as text "  {hline 60}"
        display as result "  comptab" as text "      Combine multiple regtab or effecttab frames"
        display as text "               into a single publication-ready table. Supports"
        display as text "               side-by-side and stacked layouts."
        display as text ""
    }

    if inlist("`category'", "all", "general") {
        display as text "{bf:General Purpose}"
        display as text "  {hline 60}"
        display as result "  tabtools" as text "     Suite controller for listing commands and"
        display as text "               managing persistent formatting defaults with"
        display as text "               {cmd:set} and {cmd:get}."
        display as text ""
        display as result "  tablex" as text "       Flexible wrapper for exporting any Stata table"
        display as text "               to Excel. Applies consistent professional"
        display as text "               formatting: column widths, borders, fonts,"
        display as text "               merged headers, and styling. Works with"
        display as text "               matrices and stored results."
        display as text ""
    }

end
