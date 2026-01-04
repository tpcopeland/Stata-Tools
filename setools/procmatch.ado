*! procmatch Version 1.0.1  2025/12/31
*! Procedure code matching for Swedish registry research
*! Part of the setools package
*!
*! Description:
*!   Utility program for working with KVÅ (Klassifikation av vårdåtgärder)
*!   procedure codes in Swedish health registries. Provides pattern matching
*!   and first-occurrence extraction for procedure variables.
*!
*! Subcommands:
*!   match    - Generate binary matching variable for procedure codes
*!   first    - Extract first occurrence date of matching procedures

program define procmatch, rclass
    version 16.0
    set varabbrev off

    * Main dispatcher for procedure utilities
    gettoken subcmd 0 : 0, parse(" ,")

    * Strip any trailing comma from subcommand
    local subcmd = subinstr("`subcmd'", ",", "", .)

    if "`subcmd'" == "match" {
        procmatch_match `0'
        * Propagate return values
        return local varname "`r(varname)'"
        return scalar n_matched = r(n_matched)
    }
    else if "`subcmd'" == "first" {
        procmatch_first `0'
        * Propagate return values
        capture return local varname "`r(varname)'"
        capture return local datevar "`r(datevar)'"
        capture return scalar n_matched = r(n_matched)
    }
    else if "`subcmd'" == "" {
        display as error "Subcommand required"
        display as error "Valid subcommands: match, first"
        exit 198
    }
    else {
        display as error "Unknown subcommand: `subcmd'"
        display as error "Valid subcommands: match, first"
        exit 198
    }
end


**# procmatch_match - Generate matching condition for procedure variables
program define procmatch_match, rclass
    version 16.0
    syntax, codes(string) procvars(varlist) [GENerate(name) REPlace PREfix NOIsily]

    * Clean up codes - allow comma or space separation
    local codes = subinstr("`codes'", ",", " ", .)
    local codes = trim(itrim("`codes'"))

    * Convert to uppercase
    local codes_upper ""
    foreach code of local codes {
        local codes_upper "`codes_upper' `=upper("`code'")'"
    }
    local codes_upper = trim("`codes_upper'")

    local n_codes : word count `codes_upper'

    if `n_codes' == 0 {
        display as error "No valid codes specified"
        exit 198
    }

    * Generate variable name if not specified
    if "`generate'" == "" {
        local generate "_proc_match"
    }

    * Check if variable exists
    capture confirm variable `generate'
    if !_rc & "`replace'" == "" {
        display as error "Variable `generate' already exists. Use replace option."
        exit 110
    }

    * Create matching variable
    if "`replace'" != "" {
        capture drop `generate'
    }

    quietly generate byte `generate' = 0
    label variable `generate' "Procedure match: `codes'"

    * For each procedure variable, check for matches
    foreach procvar of varlist `procvars' {

        * Create uppercase version for case-insensitive matching
        tempvar procvar_upper
        quietly gen str `procvar_upper' = upper(`procvar')

        * Match using prefix (first N characters) or exact match
        foreach code of local codes_upper {
            local codelen = strlen("`code'")

            if "`prefix'" != "" {
                * Prefix matching - match if procedure starts with code
                quietly replace `generate' = 1 if substr(`procvar_upper', 1, `codelen') == "`code'"
            }
            else {
                * Exact matching
                quietly replace `generate' = 1 if `procvar_upper' == "`code'"
            }
        }

        * Clean up temp variable
        capture drop `procvar_upper'
    }

    * Report results
    quietly count if `generate' == 1
    local n_matches = r(N)

    if "`noisily'" != "" {
        display as text "Created variable " as result "`generate'" as text " with " as result `n_matches' as text " matches"
        display as text "Searched " as result `n_codes' as text " procedure codes across " as result `: word count `procvars'' as text " procedure variables"
    }

    return local varname "`generate'"
    return local codes "`codes_upper'"
    return scalar n_codes = `n_codes'
    return scalar n_matches = `n_matches'
end


**# procmatch_first - Extract first occurrence date of matching procedures
program define procmatch_first, rclass
    version 16.0
    syntax, codes(string) procvars(varlist) datevar(varname) IDvar(varname) ///
        [GENerate(name) GENDatevar(name) REPlace PREfix NOIsily]

    * Clean up codes - allow comma or space separation
    local codes = subinstr("`codes'", ",", " ", .)
    local codes = trim(itrim("`codes'"))

    * Convert to uppercase
    local codes_upper ""
    foreach code of local codes {
        local codes_upper "`codes_upper' `=upper("`code'")'"
    }
    local codes_upper = trim("`codes_upper'")

    local n_codes : word count `codes_upper'

    if `n_codes' == 0 {
        display as error "No valid codes specified"
        exit 198
    }

    * Generate variable names if not specified
    if "`generate'" == "" {
        local generate "_proc_ever"
    }
    if "`gendatevar'" == "" {
        local gendatevar "_proc_first_dt"
    }

    * Check if variables exist
    capture confirm variable `generate'
    if !_rc & "`replace'" == "" {
        display as error "Variable `generate' already exists. Use replace option."
        exit 110
    }
    capture confirm variable `gendatevar'
    if !_rc & "`replace'" == "" {
        display as error "Variable `gendatevar' already exists. Use replace option."
        exit 110
    }

    * Create matching variable for this row
    tempvar row_match
    quietly generate byte `row_match' = 0

    * For each procedure variable, check for matches
    foreach procvar of varlist `procvars' {

        * Create uppercase version for case-insensitive matching
        tempvar procvar_upper
        quietly gen str `procvar_upper' = upper(`procvar')

        * Match using prefix (first N characters) or exact match
        foreach code of local codes_upper {
            local codelen = strlen("`code'")

            if "`prefix'" != "" {
                * Prefix matching
                quietly replace `row_match' = 1 if substr(`procvar_upper', 1, `codelen') == "`code'"
            }
            else {
                * Exact matching
                quietly replace `row_match' = 1 if `procvar_upper' == "`code'"
            }
        }

        capture drop `procvar_upper'
    }

    * Find first occurrence date per person
    tempvar first_dt_temp
    quietly egen `first_dt_temp' = min(cond(`row_match' == 1, `datevar', .)), by(`idvar')

    * Create or replace output variables
    if "`replace'" != "" {
        capture drop `generate'
        capture drop `gendatevar'
    }

    * Generate ever-had indicator
    quietly gen byte `generate' = (`first_dt_temp' != .)
    label variable `generate' "Ever had procedure: `codes'"

    * Generate first date
    quietly gen long `gendatevar' = `first_dt_temp'
    format `gendatevar' %tdCCYY/NN/DD
    label variable `gendatevar' "First date of procedure: `codes'"

    * Report results
    quietly count if `generate' == 1
    local n_ever = r(N)

    * Count unique persons
    tempvar id_tag
    quietly egen `id_tag' = tag(`idvar')
    quietly count if `id_tag' == 1 & `generate' == 1
    local n_persons = r(N)

    if "`noisily'" != "" {
        display as text "Created variables " as result "`generate'" as text " and " as result "`gendatevar'"
        display as text "  Persons with procedure: " as result `n_persons'
        display as text "  Total matching records: " as result `n_ever'
    }

    return local varname "`generate'"
    return local datevarname "`gendatevar'"
    return local codes "`codes_upper'"
    return scalar n_codes = `n_codes'
    return scalar n_persons = `n_persons'
    return scalar n_matches = `n_ever'
end
