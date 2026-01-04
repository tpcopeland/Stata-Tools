*! dateparse Version 1.0.1  2025/12/06
*! Date window utilities for Swedish registry cohort studies
*! Part of the setools package
*
* Description:
*   Utility program for date manipulation in cohort studies. Provides functions to
*   calculate lookback/follow-up windows, parse date strings, validate date ranges,
*   and check if dates fall within specified windows.
*
* Subcommands:
*   window    - Calculate lookback/followup window dates
*   parse     - Parse date strings to Stata date format
*   validate  - Validate date range (start before end)
*   inwindow  - Check if dates fall within window
*   filerange - Determine which year files are needed for date range
*
* Syntax for window:
*   dateparse window varname, lookback(#) | followup(#) [generate(names) replace]
*   Returns: r(startvar) r(endvar) r(lookback) r(followup)
*
* Syntax for parse:
*   dateparse parse, datestring(string) [format(string)]
*   Returns: r(date) r(datestr)
*
* Syntax for validate:
*   dateparse validate, start(string) end(string) [format(string)]
*   Returns: r(start_date) r(end_date) r(span_days) r(span_years)
*
* Syntax for inwindow:
*   dateparse inwindow varname, start(string) end(string) generate(name) [replace]
*   Returns: r(n_inwindow)
*
* Syntax for filerange:
*   dateparse filerange, index_start(string) index_end(string) [lookback(#) followup(#)]
*   Returns: r(index_start_year) r(index_end_year) r(file_start_year) r(file_end_year)
*
* Examples:
*   * Calculate lookback window
*   dateparse window indexdate, lookback(365) gen(window_start window_end)
*
*   * Parse date string
*   dateparse parse, datestring("2020-01-01") format("YMD")
*   local mydate = r(date)
*
*   * Validate date range
*   dateparse validate, start("2010-01-01") end("2020-12-31")
*
*   * Check if dates in window
*   dateparse inwindow eventdate, start(window_start) end(window_end) gen(in_window)
*
*   * Determine year file range needed
*   dateparse filerange, index_start("2010-01-01") index_end("2020-12-31") lookback(365)
*
program define dateparse, rclass
    version 16.0
    set varabbrev off
    set more off

    // Main dispatcher for date utilities
    gettoken subcmd 0 : 0, parse(" ,")

    // Strip any trailing comma from subcommand
    local subcmd = subinstr("`subcmd'", ",", "", .)

    if "`subcmd'" == "window" {
        dateparse_window `0'
        // Propagate return values
        return local startvar "`r(startvar)'"
        return local endvar "`r(endvar)'"
        return scalar lookback = r(lookback)
        return scalar followup = r(followup)
    }
    else if "`subcmd'" == "parse" {
        dateparse_parse `0'
        // Propagate return values
        return scalar date = r(date)
        return local datestr "`r(datestr)'"
    }
    else if "`subcmd'" == "validate" {
        dateparse_validate `0'
        // Propagate return values
        return scalar start_date = r(start_date)
        return scalar end_date = r(end_date)
        return scalar span_days = r(span_days)
        return scalar span_years = r(span_years)
        return local start_str "`r(start_str)'"
        return local end_str "`r(end_str)'"
    }
    else if "`subcmd'" == "inwindow" {
        dateparse_inwindow `0'
        // Propagate return values
        return scalar n_inwindow = r(n_inwindow)
    }
    else if "`subcmd'" == "filerange" {
        dateparse_filerange `0'
        // Propagate return values
        return scalar index_start_year = r(index_start_year)
        return scalar index_end_year = r(index_end_year)
        return scalar file_start_year = r(file_start_year)
        return scalar file_end_year = r(file_end_year)
        return scalar lookback_years = r(lookback_years)
        return scalar followup_years = r(followup_years)
    }
    else if "`subcmd'" == "" {
        display as error "Subcommand required"
        display as error "Valid subcommands: window, parse, validate, inwindow, filerange"
        exit 198
    }
    else {
        display as error "Unknown subcommand: `subcmd'"
        display as error "Valid subcommands: window, parse, validate, inwindow, filerange"
        exit 198
    }
end


**# dateparse_window - Calculate lookback/followup windows
program define dateparse_window, rclass
    version 16.0
    set varabbrev off

    syntax varname, ///
        [LOOKback(integer 0) ///
         FOLLowup(integer 0) ///
         GENerate(string) ///
         REPlace]

    local indexvar "`varlist'"

    // Validate that either lookback or followup is specified (but not both)
    if `lookback' == 0 & `followup' == 0 {
        display as error "Must specify either lookback() or followup()"
        exit 198
    }
    if `lookback' > 0 & `followup' > 0 {
        display as error "Cannot specify both lookback() and followup()"
        exit 198
    }

    // Confirm date variable
    capture confirm numeric variable `indexvar'
    if _rc {
        display as error "Index date variable `indexvar' must be numeric (Stata date)"
        exit 109
    }

    // Generate window variables if requested
    if "`generate'" != "" {
        tokenize "`generate'"
        local startvar "`1'"
        local endvar "`2'"

        if "`startvar'" == "" {
            display as error "generate() requires two variable names"
            exit 198
        }

        // Check if variables exist
        if "`replace'" == "" {
            capture confirm variable `startvar'
            if !_rc {
                display as error "Variable `startvar' already exists. Use replace option."
                exit 110
            }

            if "`endvar'" != "" {
                capture confirm variable `endvar'
                if !_rc {
                    display as error "Variable `endvar' already exists. Use replace option."
                    exit 110
                }
            }
        }
        else {
            capture drop `startvar'
            if "`endvar'" != "" {
                capture drop `endvar'
            }
        }

        // Generate lookback window
        if `lookback' > 0 {
            quietly generate int `startvar' = `indexvar' - `lookback'
            if "`endvar'" != "" {
                quietly generate int `endvar' = `indexvar' - 1
                label variable `endvar' "Lookback window end"
                format `endvar' %td
                return local endvar "`endvar'"
            }

            label variable `startvar' "Lookback window start"
            format `startvar' %td

            return local startvar "`startvar'"
        }

        // Generate followup window
        else if `followup' > 0 {
            quietly generate int `startvar' = `indexvar' + 1
            if "`endvar'" != "" {
                quietly generate int `endvar' = `indexvar' + `followup'
                label variable `endvar' "Followup window end"
                format `endvar' %td
                return local endvar "`endvar'"
            }

            label variable `startvar' "Followup window start"
            format `startvar' %td

            return local startvar "`startvar'"
        }
    }

    return scalar lookback = `lookback'
    return scalar followup = `followup'
end


**# dateparse_parse - Parse date strings to Stata dates
program define dateparse_parse, rclass
    version 16.0
    set varabbrev off

    syntax, datestring(string) [Format(string)]

    /* MAJOR BUG FIX: Change default format to YMD for Swedish data
     * WHY: Swedish registry data typically uses ISO format (YYYY-MM-DD or YYYYMMDD).
     *      Using DMY as default causes date("20250926", "DMY") to return missing
     *      because 2025 is not a valid day. This silently corrupts most dates.
     * WHAT: Change default to YMD which correctly parses Swedish registry dates.
     * ALGORITHM: Try YMD first, then attempt auto-detection for robustness */

    local datestring = trim("`datestring'")

    // Validate non-empty date string
    if "`datestring'" == "" {
        display as error "Empty date string provided"
        exit 198
    }

    // Default format is YMD for Swedish registry data (YYYY-MM-DD or YYYYMMDD)
    if "`format'" == "" {
        // Auto-detect format based on string pattern
        local len = strlen("`datestring'")

        // Check for ISO format with dashes (YYYY-MM-DD)
        if regexm("`datestring'", "^[0-9]{4}-[0-9]{2}-[0-9]{2}$") {
            local format "YMD"
        }
        // Check for compact ISO format (YYYYMMDD)
        else if regexm("`datestring'", "^[0-9]{8}$") {
            local format "YMD"
        }
        // Check for European format with slash (DD/MM/YYYY)
        else if regexm("`datestring'", "^[0-9]{2}/[0-9]{2}/[0-9]{4}$") {
            local format "DMY"
        }
        // Check for Stata text format (01jan2010)
        else if regexm("`datestring'", "^[0-9]{1,2}[a-zA-Z]{3}[0-9]{4}$") {
            local format "DMY"
        }
        // Default to YMD for Swedish data
        else {
            local format "YMD"
        }
    }

    // Try to parse as Stata date
    capture local stata_date = date("`datestring'", "`format'")

    // If that fails, try alternative formats
    if _rc | missing(`stata_date') {
        // Try YMD if we haven't already
        if "`format'" != "YMD" {
            capture local stata_date = date("`datestring'", "YMD")
        }
        // Try DMY as fallback
        if missing(`stata_date') {
            capture local stata_date = date("`datestring'", "DMY")
        }
        // Try MDY as last resort
        if missing(`stata_date') {
            capture local stata_date = date("`datestring'", "MDY")
        }
    }

    if _rc | missing(`stata_date') {
        display as error "Could not parse date: `datestring'"
        display as error "Tried formats: YMD (YYYY-MM-DD), DMY, MDY"
        display as error "Swedish registries typically use: YYYY-MM-DD or YYYYMMDD"
        exit 198
    }

    return scalar date = `stata_date'
    return local datestr "`datestring'"
end


**# dateparse_validate - Validate date range
program define dateparse_validate, rclass
    version 16.0
    set varabbrev off

    syntax, start(string) end(string) [Format(string)]

    // Parse dates
    dateparse_parse, datestring(`start') format(`format')
    local start_date = r(date)

    dateparse_parse, datestring(`end') format(`format')
    local end_date = r(date)

    // Validate order
    if `start_date' > `end_date' {
        display as error "Start date (`start') is after end date (`end')"
        exit 198
    }

    // Calculate span
    local span_days = `end_date' - `start_date' + 1
    local span_years = `span_days' / 365.25

    return scalar start_date = `start_date'
    return scalar end_date = `end_date'
    return scalar span_days = `span_days'
    return scalar span_years = round(`span_years', 0.1)

    return local start_str "`start'"
    return local end_str "`end'"
end


**# dateparse_inwindow - Check if date falls in window
program define dateparse_inwindow, rclass
    version 16.0
    set varabbrev off

    syntax varname(numeric), ///
        start(string) ///
        end(string) ///
        GENerate(name) ///
        [REPlace]

    local datevar "`varlist'"

    // Check if generate variable exists
    capture confirm variable `generate'
    if !_rc & "`replace'" == "" {
        display as error "Variable `generate' already exists. Use replace option."
        exit 110
    }

    if "`replace'" != "" {
        capture drop `generate'
    }

    // Parse start and end as either variable names or date strings
    // First try as variable names
    capture confirm variable `start'
    if !_rc {
        // It's a variable
        local start_var "`start'"
    }
    else {
        // Try to parse as date string
        dateparse_parse, datestring(`start')
        local start_date = r(date)
    }

    capture confirm variable `end'
    if !_rc {
        // It's a variable
        local end_var "`end'"
    }
    else {
        // Try to parse as date string
        dateparse_parse, datestring(`end')
        local end_date = r(date)
    }

    // Generate indicator variable
    if "`start_var'" != "" & "`end_var'" != "" {
        // Both are variables
        quietly generate byte `generate' = (`datevar' >= `start_var' & `datevar' <= `end_var') if !missing(`datevar', `start_var', `end_var')
    }
    else if "`start_var'" != "" {
        // Start is variable, end is constant
        quietly generate byte `generate' = (`datevar' >= `start_var' & `datevar' <= `end_date') if !missing(`datevar', `start_var')
    }
    else if "`end_var'" != "" {
        // Start is constant, end is variable
        quietly generate byte `generate' = (`datevar' >= `start_date' & `datevar' <= `end_var') if !missing(`datevar', `end_var')
    }
    else {
        // Both are constants
        quietly generate byte `generate' = (`datevar' >= `start_date' & `datevar' <= `end_date') if !missing(`datevar')
    }

    label variable `generate' "In date window"

    // Count how many fall in window
    quietly count if `generate' == 1
    return scalar n_inwindow = r(N)
end


**# dateparse_filerange - Determine which year files are needed
program define dateparse_filerange, rclass
    version 16.0
    set varabbrev off

    syntax, ///
        index_start(string) ///
        index_end(string) ///
        [LOOKback(integer 0) ///
         FOLLowup(integer 0)]

    // Parse index dates
    dateparse_parse, datestring(`index_start')
    local idx_start = r(date)

    dateparse_parse, datestring(`index_end')
    local idx_end = r(date)

    // Calculate earliest and latest dates needed
    local earliest_date = `idx_start' - `lookback'
    local latest_date = `idx_end' + `followup'

    // Use parsed dates for year extraction
    local start_year = year(`idx_start')
    local end_year = year(`idx_end')

    local earliest_year = year(`earliest_date')
    local latest_year = year(`latest_date')

    // Adjust for lookback/followup in years
    local lookback_years = ceil(`lookback' / 365.25)
    local followup_years = ceil(`followup' / 365.25)

    local file_start_year = `start_year' - `lookback_years'
    local file_end_year = `end_year' + `followup_years'

    return scalar index_start_year = `start_year'
    return scalar index_end_year = `end_year'
    return scalar file_start_year = `file_start_year'
    return scalar file_end_year = `file_end_year'
    return scalar lookback_years = `lookback_years'
    return scalar followup_years = `followup_years'
end
