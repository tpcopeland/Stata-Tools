*! setools Version 1.4.0  2026/02/18
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
  category(string) - Filter by category: codes, dates, migration, ms, all

Returns:
  r(commands)     - List of all command names
  r(n_commands)   - Number of commands
  r(version)      - Package version

See help setools for complete documentation
*/

program define setools, rclass
    version 16.0
    set varabbrev off

    syntax [, List Detail Category(string)]

    // Default category is all
    if "`category'" == "" local category "all"

    // Validate category option
    local category = lower("`category'")
    if !inlist("`category'", "all", "codes", "dates", "migration", "ms") {
        display as error "category() must be: all, codes, dates, migration, or ms"
        exit 198
    }

    // Define commands by category
    local cmd_codes "icdexpand procmatch cci_se"
    local cmd_dates "dateparse covarclose"
    local cmd_migration "migrations"
    local cmd_ms "sustainedss cdp pira"

    // Build selected list based on category
    if "`category'" == "codes" {
        local selected_cmds "`cmd_codes'"
    }
    else if "`category'" == "dates" {
        local selected_cmds "`cmd_dates'"
    }
    else if "`category'" == "migration" {
        local selected_cmds "`cmd_migration'"
    }
    else if "`category'" == "ms" {
        local selected_cmds "`cmd_ms'"
    }
    else {
        local selected_cmds "`cmd_codes' `cmd_dates' `cmd_migration' `cmd_ms'"
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
            display as result "  icdexpand  " as text "- ICD-10 code expansion and matching"
            display as result "  procmatch  " as text "- KVA procedure code matching"
            display as result "  cci_se     " as text "- Swedish Charlson Comorbidity Index"
            display as text ""
        }

        if inlist("`category'", "all", "dates") {
            display as text "{bf:Date & Covariate Utilities}"
            display as result "  dateparse  " as text "- Date parsing for cohort studies"
            display as result "  covarclose " as text "- Extract values closest to index date"
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
    return local version "1.4.0"
    return local categories "codes dates migration ms"
end

// Subroutine for detailed display
program define _setools_detail
    syntax , Category(string)

    if inlist("`category'", "all", "codes") {
        display as text "{bf:Registry Code Utilities}"
        display as text "  {hline 60}"
        display as result "  icdexpand" as text "    ICD-10 code utilities for Swedish registry research."
        display as text "               Expands code ranges (e.g., G35-G37), matches"
        display as text "               diagnoses in patient/cause-of-death registers,"
        display as text "               handles wildcards (G35*), and supports both"
        display as text "               3-character and full codes."
        display as text ""
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

    if inlist("`category'", "all", "dates") {
        display as text "{bf:Date & Covariate Utilities}"
        display as text "  {hline 60}"
        display as result "  dateparse" as text "    Date utilities for Swedish registry cohort studies."
        display as text "               Parses various date formats, calculates study"
        display as text "               windows, and handles censoring dates (death,"
        display as text "               emigration, study end)."
        display as text ""
        display as result "  covarclose" as text "   Extract covariate values closest to index date."
        display as text "               Finds nearest measurement within specified"
        display as text "               window (before, after, or both). Useful for"
        display as text "               lab values, BMI, blood pressure, etc."
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
        display as text "               if baseline EDSS 0-5.0, or 0.5 point increase"
        display as text "               if baseline EDSS >= 5.5. Requires confirmation."
        display as text ""
        display as result "  pira" as text "         Progression Independent of Relapse Activity."
        display as text "               Identifies disability worsening that occurs"
        display as text "               outside of relapse windows. Key outcome for"
        display as text "               progressive MS and treatment trials."
        display as text ""
    }
end
