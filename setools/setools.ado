*! setools Version 1.0.0  2026/04/08
*! Swedish Registry Toolkit for Epidemiological Cohort Studies
*! Author: Timothy P Copeland
*! Department of Clinical Neuroscience, Karolinska Institutet
*! Program class: rclass (returns results in r())

/*
Basic syntax:
  setools [, list detail category(string)]

Optional options:
  list            - Display commands as a simple list
  detail          - Show detailed information with descriptions
  category(string) - Filter by category: codes, migration, ms, all

Returns:
  r(commands)     - List of all command names
  r(n_commands)   - Number of commands
  r(version)      - Package version

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

    // Define commands by category
    local cmd_codes "procmatch cci_se"
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

    // Count commands
    local n_commands: word count `selected_cmds'

    // Display header
    display as text ""
    display as text "{hline 70}"
    display as result "setools" as text " - Swedish Registry Toolkit"
    display as text "{hline 70}"
    display as text ""

    // Display based on options
    if "`detail'" != "" {
        // Detailed view with descriptions
        _setools_detail, category(`category')
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
        if inlist("`category'", "all", "codes") {
            display as text "{bf:Registry Code Utilities}"
            display as result "  procmatch  " as text "- KVA procedure code matching"
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
            display as result "  sustainedss" as text "- Sustained EDSS progression date"
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
    return local version "1.4.7"
    return local categories "codes migration ms"

    }
    local _rc = _rc
    set varabbrev `_varabbrev'
    if `_rc' exit `_rc'
end

// Subroutine for detailed display
program define _setools_detail
    syntax , Category(string)

    if inlist("`category'", "all", "codes") {
        display as text "{bf:Registry Code Utilities}"
        display as text "  {hline 60}"
        display as result "  procmatch" as text "    Procedure code matching for Swedish registries."
        display as text "               Matches KVA procedure codes in surgical and"
        display as text "               intervention registers. Supports wildcards"
        display as text "               and code ranges."
        display as text ""
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
        display as result "  sustainedss" as text "  Compute sustained EDSS progression date for MS"
        display as text "               research. Requires confirmation at specified"
        display as text "               interval (typically 3-6 months). Handles"
        display as text "               baseline roving and relapse exclusions."
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
end
