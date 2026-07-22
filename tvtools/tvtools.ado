*! tvtools Version 1.8.0  2026/07/22
*! A suite of commands for time-varying exposure analysis
*! Author: Timothy P Copeland, Karolinska Institutet
*! Department of Clinical Neuroscience, Karolinska Institutet
*! Program class: rclass (returns results in r())

/*
Basic syntax:
  tvtools [, list detail category(string)]

Optional options:
  list            - Display commands as a simple list
  detail          - Show detailed information with descriptions
  category(string) - Filter by category: prep, diag, weight, all

Returns:
  r(commands)     - List of all command names
  r(n_commands)   - Number of commands
  r(version)      - Package version

See help tvtools for complete documentation
*/

program define tvtools, rclass
    version 16.0
    local orig_varabbrev = c(varabbrev)
    local orig_more = c(more)
    set varabbrev off
    set more off

    capture noisily {

    syntax [, List Detail Category(string)]

    // Default category is all
    if "`category'" == "" local category "all"

    // Validate category option
    local category = lower("`category'")
    if !inlist("`category'", "all", "prep", "diag", "weight") {
        display as error "category() must be: all, prep, diag, or weight"
        exit 198
    }

    // Define commands by category
    local cmd_prep "tvexpose tvmerge tvevent tvage tvband tvsplit tvpanel"
    local cmd_diag "tvdiagnose"
    local cmd_weight "tvweight"

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
    else {
        local selected_cmds "`cmd_prep' `cmd_diag' `cmd_weight'"
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
            display as result "  tvage      " as text "- Expand person-level follow-up into age bands"
            display as result "  tvband     " as text "- Split intervals on one date-derived axis"
            display as result "  tvsplit    " as text "- Multi-timescale Lexis interval splitting"
            display as result "  tvpanel    " as text "- Build fixed-width MSM panel grid"
            display as text ""
        }

        if inlist("`category'", "all", "diag") {
            display as text "{bf:Diagnostics}"
            display as result "  tvdiagnose " as text "- Diagnostic tools for TV datasets"
            display as text ""
        }

        if inlist("`category'", "all", "weight") {
            display as text "{bf:Weighting}"
            display as result "  tvweight   " as text "- Calculate IPTW weights"
            display as text ""
        }

        display as text "{hline 70}"
        display as text "Total commands: " as result "`n_commands'"
        display as text ""
        display as text "Help: " as result "help tvtools" as text " for workflow guide"
        display as text "      " as result "help <command>" as text " for individual command help"
    }

    // Return results
    * Derive version from the *! header so the literal cannot drift on a bump
    local version "unknown"
    capture findfile tvtools.ado
    if !_rc {
        tempname _fh
        capture file open `_fh' using "`r(fn)'", read text
        if !_rc {
            file read `_fh' _header_line
            file close `_fh'
            if regexm("`_header_line'", "Version ([0-9.]+)") local version = regexs(1)
        }
    }

    return local commands "`selected_cmds'"
    return scalar n_commands = `n_commands'
    return local version "`version'"
    return local categories "prep diag weight"

    } // end capture noisily
    local rc = _rc

    set varabbrev `orig_varabbrev'
    set more `orig_more'

    if `rc' {
        exit `rc'
    }
end

// Subroutine for detailed display
capture program drop _tvtools_detail
program define _tvtools_detail
    version 16.0
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
        display as result "  tvage" as text "        Expand one-row-per-person follow-up into"
        display as text "               exact calendar-age bands."
        display as text ""
        display as result "  tvband" as text "       Split follow-up intervals along one date-derived"
        display as text "               axis (age, calendar period, or elapsed time)."
        display as text ""
        display as result "  tvsplit" as text "      Multi-timescale (Lexis) splitting on age,"
        display as text "               calendar, and time-since-entry simultaneously."
        display as text ""
        display as result "  tvpanel" as text "      Build a fixed-width, entry-anchored panel grid"
        display as text "               for marginal structural models (feeds the msm"
        display as text "               package)."
        display as text ""
    }

    if inlist("`category'", "all", "diag") {
        display as text "{bf:Diagnostics}"
        display as text "  {hline 60}"
        display as result "  tvdiagnose" as text "   Diagnostic tools for time-varying exposure"
        display as text "               datasets. Checks data structure, identifies"
        display as text "               gaps, and validates episode integrity."
        display as text ""
    }

    if inlist("`category'", "all", "weight") {
        display as text "{bf:Weighting}"
        display as text "  {hline 60}"
        display as result "  tvweight" as text "     Calculate inverse probability of treatment"
        display as text "               weights (IPTW) for time-varying confounding."
        display as text ""
    }
end
