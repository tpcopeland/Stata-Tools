*! setools Version 1.4.0  2026/06/15
*! Swedish Registry Toolkit for Epidemiological Cohort Studies
*! Author: Timothy P Copeland, Karolinska Institutet
*! Program class: rclass (returns results in r())

/*
Basic syntax:
  setools [, list detail category(string)]

Optional options:
  list            - Display commands as a simple list
  detail          - Show detailed information with descriptions
  category(string) - Filter by category: codes, migration, ms, all
  note            - list and detail may not be specified together

Returns:
  r(commands)     - List of all command names
  r(n_commands)   - Number of commands
  r(version)      - Package version
  r(category)     - Selected category filter
  r(display)      - Display mode used: grouped, list, or detail

See help setools for complete documentation
*/

program define setools, rclass
    version 16.0
    local _varabbrev `c(varabbrev)'
    set varabbrev off

    capture noisily {

    syntax [, List Detail Category(string)]

    // Default category is all
    if "`category'" == "" local category "all"

    // Validate category option
    local category = lower("`category'")
    if !inlist("`category'", "all", "codes", "migration", "ms") {
        display as error "category() must be: all, codes, migration, or ms"
        exit 198
    }

    if "`list'" != "" & "`detail'" != "" {
        display as error "list and detail may not be specified together"
        exit 198
    }

    // Define commands by category
    local cmd_codes "cci_se"
    local cmd_migration "migrations"
    local cmd_ms "sustainedss cdp pira"

    // Build selected list based on category
    if "`category'" == "codes" {
        local selected_cmds "`cmd_codes'"
    }
    else if "`category'" == "migration" {
        local selected_cmds "`cmd_migration'"
    }
    else if "`category'" == "ms" {
        local selected_cmds "`cmd_ms'"
    }
    else {
        local selected_cmds "`cmd_codes' `cmd_migration' `cmd_ms'"
    }

    local display "grouped"
    if "`list'" != "" local display "list"
    if "`detail'" != "" local display "detail"

    // Count commands
    local n_commands: word count `selected_cmds'

    // Display header
    display as text ""
    display as text "{hline 70}"
    display as result "setools" as text " - Swedish Registry Toolkit"
    display as text "{hline 70}"
    display as text ""

    // Display based on options
    if "`display'" == "detail" {
        // Detailed view with descriptions
        _setools_detail, category(`category')
    }
    else if "`display'" == "list" {
        // Simple list view
        display as text "Available commands (`category'):"
        display as text ""
        foreach cmd of local selected_cmds {
            display as result "  `cmd'"
        }
    }
    else {
        // Default: organized view
        if inlist("`category'", "all", "codes") {
            display as text "{bf:Registry Code Utilities}"
            display as result "  cci_se     " as text "- Swedish Charlson Comorbidity Index"
            display as text ""
        }

        if inlist("`category'", "all", "migration") {
            display as text "{bf:Migration Registry}"
            display as result "  migrations " as text "- Process migration data for exclusions/censoring"
            display as text ""
        }

        if inlist("`category'", "all", "ms") {
            display as text "{bf:MS Disability Progression}"
            display as result "  sustainedss" as text "- First sustained EDSS threshold date"
            display as result "  cdp        " as text "- Confirmed Disability Progression"
            display as result "  pira       " as text "- Progression Independent of Relapse Activity"
            display as text ""
        }

        display as text "{hline 70}"
        display as text "Total commands: " as result "`n_commands'"
        display as text ""
        display as text "Help: " as result "help setools" as text " for overview"
        display as text "      " as result "help <command>" as text " for individual command help"
    }

    // Return results
    return local commands "`selected_cmds'"
    return scalar n_commands = `n_commands'
    // VERSION-SYNC: keep this literal in step with the *! header on every bump
    return local version "1.4.0"
    return local categories "all codes migration ms"
    return local category "`category'"
    return local display "`display'"

    }
    local _rc = _rc
    set varabbrev `_varabbrev'
    if `_rc' exit `_rc'
end

// Subroutine for detailed display
cap program drop _setools_detail
program define _setools_detail, nclass
    version 16.0
    local _varabbrev `c(varabbrev)'
    set varabbrev off

    capture noisily {

    syntax , Category(string)

    if inlist("`category'", "all", "codes") {
        display as text "{bf:Registry Code Utilities}"
        display as text "  {hline 60}"
        display as result "  cci_se" as text "       Swedish Charlson Comorbidity Index."
        display as text "               Computes CCI from ICD-7 through ICD-10 codes"
        display as text "               using the Ludvigsson et al. (2021) adaptation"
        display as text "               for Swedish register-based research."
        display as text ""
    }

    if inlist("`category'", "all", "migration") {
        display as text "{bf:Migration Registry}"
        display as text "  {hline 60}"
        display as result "  migrations" as text "   Process Swedish migration registry data for cohort"
        display as text "               studies. Identifies periods of residence,"
        display as text "               generates exclusion flags for non-residents,"
        display as text "               and creates censoring dates for emigration."
        display as text "               Essential for valid person-time calculation."
        display as text ""
    }

    if inlist("`category'", "all", "ms") {
        display as text "{bf:MS Disability Progression}"
        display as text "  {hline 60}"
        display as result "  sustainedss" as text "  Compute the first sustained EDSS threshold date."
        display as text "               Finds the first date EDSS reaches a user-"
        display as text "               specified threshold and is not reversed within"
        display as text "               the confirmation window."
        display as text ""
        display as result "  cdp" as text "          Confirmed Disability Progression from baseline."
        display as text "               Standard CDP definition: 1.0 point increase"
        display as text "               if baseline EDSS 0-5.5, or 0.5 point increase"
        display as text "               if baseline EDSS > 5.5. Requires confirmation."
        display as text ""
        display as result "  pira" as text "         Progression Independent of Relapse Activity."
        display as text "               Identifies disability worsening that occurs"
        display as text "               outside of relapse windows. Key outcome for"
        display as text "               progressive MS and treatment trials."
        display as text ""
    }

    }
    local _rc = _rc
    set varabbrev `_varabbrev'
    if `_rc' exit `_rc'
end
