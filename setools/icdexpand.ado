*! icdexpand Version 2.0.0  2026/01/07
*! ICD-10 code utilities for Swedish registry research
*! Part of the setools package
*!
*! Description:
*!   Utility program for working with ICD-10 codes. Provides functions to expand
*!   code patterns (wildcards, ranges), validate code format, and generate matching
*!   conditions for diagnosis variables in Swedish health registries.
*!
*! Subcommands:
*!   expand   - Expand ICD code patterns (wildcards, ranges) to full code list
*!   validate - Validate ICD-10 code format
*!   match    - Generate binary matching variable for diagnosis codes

program define icdexpand, rclass
    version 16.0
    set varabbrev off

    * Main dispatcher for ICD utilities
    gettoken subcmd 0 : 0, parse(" ,")

    * Strip any trailing comma from subcommand
    local subcmd = subinstr("`subcmd'", ",", "", .)

    if "`subcmd'" == "expand" {
        icdexpand_expand `0'
        * Propagate return values
        return local codes "`r(codes)'"
        return scalar n_codes = r(n_codes)
    }
    else if "`subcmd'" == "validate" {
        icdexpand_validate `0'
        * Propagate return values
        return scalar valid = r(valid)
        capture return local reason "`r(reason)'"
    }
    else if "`subcmd'" == "match" {
        icdexpand_match `0'
        * Propagate return values
        return local varname "`r(varname)'"
        return scalar n_matches = r(n_matches)
    }
    else if "`subcmd'" == "" {
        display as error "Subcommand required"
        display as error "Valid subcommands: expand, validate, match"
        exit 198
    }
    else {
        display as error "Unknown subcommand: `subcmd'"
        display as error "Valid subcommands: expand, validate, match"
        exit 198
    }
end


**# icdexpand_expand - Expand ICD code patterns to full list
program define icdexpand_expand, rclass
    version 16.0
    syntax, pattern(string) [MAXcodes(integer 1000) NOIsily]

    * Split pattern by spaces and commas
    local pattern = trim("`pattern'")
    local codelist ""

    * Handle comma-separated patterns
    tokenize "`pattern'", parse(", ")
    local i = 1
    local max_tokens = 500
    while "``i''" != "" & `i' <= `max_tokens' {
        local thispattern = trim("``i''")

        if "`thispattern'" != "," & "`thispattern'" != "" {
            * Process this pattern
            _icdexpand_single, pattern(`thispattern')
            local codelist "`codelist' `r(codes)'"
        }
        local ++i
    }
    if `i' > `max_tokens' {
        display as error "Too many code patterns (max: `max_tokens')"
        exit 198
    }

    * Remove duplicates and clean up
    local codelist : list uniq codelist
    local codelist = trim("`codelist'")

    * Count codes
    local n_codes : word count `codelist'

    if `n_codes' > `maxcodes' {
        display as error "Expanded code list has `n_codes' codes (max: `maxcodes')"
        display as error "Pattern: `pattern'"
        display as error "Use maxcodes() option to increase limit if needed"
        exit 198
    }

    if "`noisily'" != "" {
        display as text "Expanded `n_codes' ICD-10 codes from pattern: " as result "`pattern'"
    }

    return local codes "`codelist'"
    return scalar n_codes = `n_codes'
end


**# _icdexpand_single - Expand a single pattern (internal)
program define _icdexpand_single, rclass
    version 16.0
    syntax, pattern(string)

    local pattern = trim("`pattern'")

    * Check for COMBINED range+wildcard (e.g., I60-I69*)
    * Must check this BEFORE separate wildcard/range checks
    * NOTE: For combined patterns, only get BASE codes from range (not subcodes)
    *       then apply wildcard to each base code to avoid exponential expansion
    if strpos("`pattern'", "-") > 0 & strpos("`pattern'", "*") > 0 {
        * Split on * to get range part
        local range_part = subinstr("`pattern'", "*", "", .)

        * Parse the range to get only BASE codes (no subcode expansion)
        tokenize "`range_part'", parse("-")
        local start "`1'"
        local end "`3'"

        local start = upper(trim("`start'"))
        local end = upper(trim("`end'"))

        local start_letter = substr("`start'", 1, 1)
        local start_num = real(substr("`start'", 2, .))
        local end_letter = substr("`end'", 1, 1)
        local end_num = real(substr("`end'", 2, .))

        * Validate same letter prefix
        if "`start_letter'" != "`end_letter'" {
            display as error "Range must have same letter prefix: `range_part'"
            exit 198
        }

        * Get only base codes (e.g., I60, I61, ..., I69)
        local base_codes ""
        forvalues num = `start_num'/`end_num' {
            local base_codes "`base_codes' `start_letter'`num'"
        }

        * Now expand each base code with wildcard
        local codelist ""
        foreach code of local base_codes {
            _icdexpand_wildcard, pattern(`code'*)
            local codelist "`codelist' `r(codes)'"
        }

        return local codes "`codelist'"
        exit
    }

    * Check for wildcard only (e.g., I63*)
    if strpos("`pattern'", "*") > 0 {
        _icdexpand_wildcard, pattern(`pattern')
        return local codes "`r(codes)'"
        exit
    }

    * Check for range only (e.g., E10-E14)
    if strpos("`pattern'", "-") > 0 {
        _icdexpand_range, pattern(`pattern')
        return local codes "`r(codes)'"
        exit
    }

    * No expansion needed - return as is (convert to uppercase)
    local pattern = upper("`pattern'")
    return local codes "`pattern'"
end


**# _icdexpand_wildcard - Expand wildcards like I63*
program define _icdexpand_wildcard, rclass
    version 16.0
    syntax, pattern(string)

    * Extract prefix (before *)
    local prefix = subinstr("`pattern'", "*", "", .)
    local prefix = upper(trim("`prefix'"))

    /* WILDCARD EXPANSION ALGORITHM
     * ICD-10 codes have hierarchical structure (e.g., I63 -> I63.0 -> I63.00)
     * Swedish registries may record at different levels of specificity
     *
     * This expands wildcard pattern (e.g., "I63*") to all possible variations:
     *   1. Base code (I63)
     *   2. Single-digit subcodes with decimal: I63.0 through I63.9
     *   3. Single-digit subcodes without decimal: I630 through I639 (registry format)
     *   4. Two-digit detail codes: I63.00 through I63.99 (100 codes)
     *
     * Result: Pattern "I63*" expands to ~121 unique code variants */

    local codelist "`prefix'"  // Start with base code

    * Add single-digit subcodes WITH decimal (ICD-10 standard format)
    foreach sub in 0 1 2 3 4 5 6 7 8 9 {
        local codelist "`codelist' `prefix'.`sub'"
    }

    * Add single-digit subcodes WITHOUT decimal (alternative registry format)
    foreach sub in 0 1 2 3 4 5 6 7 8 9 {
        local codelist "`codelist' `prefix'`sub'"
    }

    * Add two-digit detail codes .00-.99 (nested loop for all combinations)
    foreach sub1 in 0 1 2 3 4 5 6 7 8 9 {
        foreach sub2 in 0 1 2 3 4 5 6 7 8 9 {
            local codelist "`codelist' `prefix'.`sub1'`sub2'"
        }
    }

    return local codes "`codelist'"
end


**# _icdexpand_range - Expand ranges like E10-E14
program define _icdexpand_range, rclass
    version 16.0
    syntax, pattern(string)

    * Split on hyphen
    tokenize "`pattern'", parse("-")
    local start "`1'"
    local end "`3'"

    if "`start'" == "" | "`end'" == "" {
        display as error "Invalid range format: `pattern'"
        display as error "Expected format: E10-E14"
        exit 198
    }

    local start = upper(trim("`start'"))
    local end = upper(trim("`end'"))

    * Extract letter prefix and numbers
    local start_letter = substr("`start'", 1, 1)
    local start_num = substr("`start'", 2, .)
    local end_letter = substr("`end'", 1, 1)
    local end_num = substr("`end'", 2, .)

    * Validate same letter prefix
    if "`start_letter'" != "`end_letter'" {
        display as error "Range must have same letter prefix: `pattern'"
        display as error "Cannot expand range across letter categories"
        exit 198
    }

    * Validate letter is A-Z
    if !regexm("`start_letter'", "^[A-Z]$") {
        display as error "Invalid ICD-10 letter prefix: `start_letter'"
        exit 198
    }

    * Convert to numbers
    local start_num = real("`start_num'")
    local end_num = real("`end_num'")

    if missing(`start_num') | missing(`end_num') {
        display as error "Invalid numeric part in range: `pattern'"
        exit 198
    }

    /* NUMERIC RANGE EXPANSION ALGORITHM
     * Many conditions span consecutive ICD-10 codes (e.g., E10-E14 for all diabetes)
     *
     * This expands range notation to all codes and subcodes within that range:
     *   1. Extract letter prefix and numeric bounds (E + 10 to 14)
     *   2. Loop through all integers in range
     *   3. For each base code, generate all single-digit subcodes
     *   4. Include both decimal and non-decimal formats for registry compatibility
     *
     * Example: "E10-E14" generates:
     *   E10, E10.0-E10.9, E100-E109, E11, E11.0-E11.9, E110-E119, ..., E14.0-E14.9
     *   Total: ~105 codes (5 base codes × 21 variants each) */

    local codelist ""
    forvalues num = `start_num'/`end_num' {
        local code "`start_letter'`num'"
        local codelist "`codelist' `code'"

        * Add single-digit subcodes WITH decimal
        foreach sub in 0 1 2 3 4 5 6 7 8 9 {
            local codelist "`codelist' `code'.`sub'"
        }

        * Add single-digit subcodes WITHOUT decimal
        foreach sub in 0 1 2 3 4 5 6 7 8 9 {
            local codelist "`codelist' `code'`sub'"
        }
    }

    return local codes "`codelist'"
end


**# icdexpand_validate - Validate ICD-10 code format
program define icdexpand_validate, rclass
    version 16.0
    syntax, pattern(string) [NOIsily]

    local pattern = upper(trim("`pattern'"))
    local valid = 1
    local invalid_codes ""

    * Split by comma and space
    tokenize "`pattern'", parse(", ")
    local i = 1
    while "``i''" != "" {
        local code = trim("``i''")

        if "`code'" != "," & "`code'" != "" {
            local code_valid = 1

            * Check first character is letter (A-Z)
            local first_char = substr("`code'", 1, 1)
            if !regexm("`first_char'", "^[A-Z]$") {
                local code_valid = 0
            }

            * Check for invalid characters (only allow letters, digits, *, -, .)
            if regexm("`code'", "[^A-Z0-9*.-]") {
                local code_valid = 0
            }

            if `code_valid' == 0 {
                local valid = 0
                local invalid_codes "`invalid_codes' `code'"
            }
        }
        local ++i
    }

    if "`noisily'" != "" {
        if `valid' == 1 {
            display as text "All ICD codes valid: " as result "`pattern'"
        }
        else {
            display as error "Invalid ICD codes found: `invalid_codes'"
        }
    }

    return scalar valid = `valid'
    return local invalid_codes = trim("`invalid_codes'")
end


**# icdexpand_match - Generate matching condition for diagnosis variables
*  Rewritten in v2.0 to use efficient set-based operations instead of
*  looping through expanded codes. Uses inrange() for ranges and
*  substr() for prefix matching.
program define icdexpand_match, rclass
    version 16.0
    syntax, codes(string) dxvars(varlist) [GENerate(name) REPlace NOIsily]

    * Generate variable name if not specified
    if "`generate'" == "" {
        local generate "_icd_match"
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
    label variable `generate' "ICD match: `codes'"

    * Parse patterns and apply efficient matching
    * Handle comma-separated patterns
    local pattern = trim("`codes'")
    tokenize "`pattern'", parse(", ")
    local i = 1
    local n_patterns = 0

    while "``i''" != "" {
        local thispattern = upper(trim("``i''"))

        if "`thispattern'" != "," & "`thispattern'" != "" {
            local ++n_patterns

            * Determine pattern type and apply efficient matching
            local has_range = (strpos("`thispattern'", "-") > 0)
            local has_wild = (strpos("`thispattern'", "*") > 0)

            if `has_range' & `has_wild' {
                * Combined range+wildcard (e.g., I60-I69*)
                * Extract range part (remove *)
                local range_part = subinstr("`thispattern'", "*", "", .)
                tokenize "`range_part'", parse("-")
                local start = upper(trim("`1'"))
                local end = upper(trim("`3'"))
                local prefixlen = length("`start'")

                foreach dxvar of varlist `dxvars' {
                    quietly replace `generate' = 1 if ///
                        inrange(substr(upper(`dxvar'), 1, `prefixlen'), "`start'", "`end'")
                }
            }
            else if `has_range' {
                * Range only (e.g., E10-E14)
                tokenize "`thispattern'", parse("-")
                local start = upper(trim("`1'"))
                local end = upper(trim("`3'"))
                local prefixlen = length("`start'")

                foreach dxvar of varlist `dxvars' {
                    quietly replace `generate' = 1 if ///
                        inrange(substr(upper(`dxvar'), 1, `prefixlen'), "`start'", "`end'")
                }
            }
            else if `has_wild' {
                * Wildcard only (e.g., I63*)
                local prefix = subinstr("`thispattern'", "*", "", .)
                local prefixlen = length("`prefix'")

                foreach dxvar of varlist `dxvars' {
                    quietly replace `generate' = 1 if ///
                        substr(upper(`dxvar'), 1, `prefixlen') == "`prefix'"
                }
            }
            else {
                * Exact match
                foreach dxvar of varlist `dxvars' {
                    quietly replace `generate' = 1 if upper(`dxvar') == "`thispattern'"
                }
            }
        }
        local ++i
    }

    * Report results
    quietly count if `generate' == 1
    local n_matches = r(N)

    if "`noisily'" != "" {
        display as text "Created variable " as result "`generate'" as text " with " as result `n_matches' as text " matches"
        display as text "Matched " as result `n_patterns' as text " pattern(s) across " as result `: word count `dxvars'' as text " diagnosis variable(s)"
    }

    return local varname "`generate'"
    return scalar n_patterns = `n_patterns'
    return scalar n_matches = `n_matches'
end
