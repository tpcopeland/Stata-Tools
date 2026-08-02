*! tvtools Version 1.12.1  2026/08/02
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

    **# -------------------------------------------------------------------
    **# The command catalog: one table, three consumers
    **# -------------------------------------------------------------------
    * The category lists below are the ONLY place the command set is written
    * down. r(commands), r(n_commands), the compact view, and the detail view
    * are all derived from them, so a new command cannot appear in one place
    * and be missed in another. This used to be three parallel copies -- the
    * lists here, ten hand-padded display lines, and ten more in the detail
    * subroutine -- and the copies drifted: tvbuild's compact and detail rows
    * each carried one space more than every other row, hanging its dash a
    * column to the right in a shipped release.
    local cmd_prep   "tvbuild tvspec tvexpose tvmerge tvevent tvage tvband tvsplit tvpanel"
    local cmd_diag   "tvdiagnose"
    local cmd_weight "tvweight"

    * One short blurb per command for the compact view.
    local d_tvbuild    "Build a committed interval frame end to end"
    local d_tvspec     "Build a tvbuild specification frame"
    local d_tvexpose   "Create time-varying exposure variables"
    local d_tvmerge    "Merge multiple time-varying datasets"
    local d_tvevent    "Integrate events and competing risks"
    local d_tvage      "Expand person-level follow-up into age bands"
    local d_tvband     "Split intervals on one date-derived axis"
    local d_tvsplit    "Multi-timescale Lexis interval splitting"
    local d_tvpanel    "Build fixed-width MSM panel grid"
    local d_tvdiagnose "Diagnostic tools for TV datasets"
    local d_tvweight   "Calculate IPTW weights"

    * The long blurb for the detail view, pre-split one line per macro. The
    * lines are stored rather than wrapped at run time because this output is
    * console-only, and SMCL paragraph directives inside -display- behave
    * differently in the console and the Viewer. The renderer stops at the
    * first empty L_<cmd>_<k>, so a blurb is as long as it needs to be.
    local L_tvbuild_1    "Build a committed, analysis-ready interval frame"
    local L_tvbuild_2    "from a cohort and one or more longitudinal"
    local L_tvbuild_3    "sources. Coordinates tvexpose, tvmerge, and"
    local L_tvbuild_4    "tvevent; the recommended front door."

    local L_tvspec_1     "Build the multi-source specification frame"
    local L_tvspec_2     "tvbuild's specframe() consumes, one source per"
    local L_tvspec_3     "-tvspec add- call, instead of by hand."

    local L_tvexpose_1   "Create time-varying exposure variables for"
    local L_tvexpose_2   "survival analysis. Transforms exposure records"
    local L_tvexpose_3   "into episode format compatible with stset."

    local L_tvmerge_1    "Merge multiple time-varying exposure datasets."
    local L_tvmerge_2    "Handles overlapping time periods and validates"
    local L_tvmerge_3    "data structure integrity."

    local L_tvevent_1    "Integrate events and competing risks into"
    local L_tvevent_2    "time-varying datasets. Supports multiple event"
    local L_tvevent_3    "types and censoring."

    local L_tvage_1      "Expand one-row-per-person follow-up into"
    local L_tvage_2      "exact calendar-age bands."

    local L_tvband_1     "Split follow-up intervals along one date-derived"
    local L_tvband_2     "axis (age, calendar period, or elapsed time)."

    local L_tvsplit_1    "Multi-timescale (Lexis) splitting on age,"
    local L_tvsplit_2    "calendar, and time-since-entry simultaneously."

    local L_tvpanel_1    "Build a fixed-width, entry-anchored panel grid"
    local L_tvpanel_2    "for marginal structural models (feeds the msm"
    local L_tvpanel_3    "package)."

    local L_tvdiagnose_1 "Diagnostic tools for time-varying exposure"
    local L_tvdiagnose_2 "datasets. Checks data structure, identifies"
    local L_tvdiagnose_3 "gaps, and validates episode integrity."

    local L_tvweight_1   "Calculate inverse probability of treatment"
    local L_tvweight_2   "weights (IPTW) for time-varying confounding."

    * Category headings, keyed by category token.
    local h_prep   "Data Preparation"
    local h_diag   "Diagnostics"
    local h_weight "Weighting"

    // Build selected list based on category
    if "`category'" == "all" local shown "prep diag weight"
    else local shown "`category'"

    local selected_cmds ""
    foreach g of local shown {
        local selected_cmds "`selected_cmds' `cmd_`g''"
    }
    local selected_cmds = strtrim(stritrim("`selected_cmds'"))

    // Count commands
    local n_commands: word count `selected_cmds'

    * The name field is as wide as the longest name actually being shown, so
    * there is no padding literal left to type wrongly. Both views measure the
    * same list, so both columns move together when a command is added.
    local w = 0
    foreach c of local selected_cmds {
        local l = strlen("`c'")
        if `l' > `w' local w = `l'
    }
    local col_compact = `w' + 4
    local col_detail  = `w' + 6

    // Display header
    display as text ""
    display as text "{hline 70}"
    display as result "tvtools" as text " - Time-Varying Exposure Analysis Suite"
    display as text "{hline 70}"
    display as text ""

    // Display based on options
    if "`detail'" != "" {
        // Detailed view with descriptions
        foreach g of local shown {
            display as text "{bf:`h_`g''}"
            display as text "  {hline 60}"
            foreach c of local cmd_`g' {
                display as result "  `c'" _col(`col_detail') as text "`L_`c'_1'"
                local k = 2
                local more_lines = 1
                while `more_lines' {
                    if "`L_`c'_`k''" == "" local more_lines = 0
                    else {
                        display as text _col(`col_detail') "`L_`c'_`k''"
                        local ++k
                    }
                }
                display as text ""
            }
        }
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
        foreach g of local shown {
            display as text "{bf:`h_`g''}"
            foreach c of local cmd_`g' {
                display as result "  `c'" _col(`col_compact') as text "- `d_`c''"
            }
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
