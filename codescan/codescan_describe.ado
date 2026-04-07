*! codescan_describe Version 1.0.0  2026/04/08
*! Tabulate unique codes across wide-format variables
*! Author: Timothy P Copeland
*! Program class: rclass (returns results in r())
*! Requires: Stata 16.0+

/*
DESCRIPTION:
    Exploratory complement to codescan. Tabulates the unique codes present
    across wide-format code variables (dx1-dx30, proc1-proc20, etc.),
    showing the top-N codes by frequency and a chapter summary grouped by
    first character. Answers "what codes are in my data?" before defining
    conditions for scanning.

SYNTAX:
    codescan_describe varlist [if] [in] [, Top(integer 20) NODots TOSTRing]

STORED RESULTS:
    r(n_unique)   - Number of unique codes found
    r(n_entries)  - Total non-empty code entries across all variables
    r(n_vars)     - Number of variables scanned
    r(varlist)    - Variables scanned
*/

program define codescan_describe, rclass
    version 16.0
    local _orig_varabbrev = c(varabbrev)
    set varabbrev off
    capture noisily {

    syntax varlist [if] [in] [, Top(integer 20) NODots TOSTRing SAVE(string)]

    * Validate top
    if `top' < 1 {
        display as error "top() must be a positive integer"
        exit 198
    }

    * Validate string variables (before tostring, to catch missing option early)
    if "`tostring'" == "" {
        foreach var of local varlist {
            capture confirm string variable `var'
            if _rc {
                display as error "`var' is not a string variable"
                display as error "codescan_describe requires string variables; use tostring or the tostring option"
                exit 109
            }
        }
    }

    marksample touse, novarlist

    quietly count if `touse'
    if r(N) == 0 {
        display as error "no observations"
        exit 2000
    }

    local nvars : word count `varlist'

    preserve

    * Auto-convert numeric variables if tostring specified (after preserve)
    if "`tostring'" != "" {
        foreach var of local varlist {
            capture confirm string variable `var'
            if _rc {
                noisily display as text "(note: converting `var' from numeric to string)"
                quietly tostring `var', replace force
            }
        }
    }
    quietly {
        keep if `touse'

        * Accumulate code frequencies variable-by-variable (avoids reshape explosion)
        local total_entries = 0
        tempfile _source _combined
        save `_source'
        local first = 1

        foreach var of local varlist {
            use `var' using `_source', clear
            rename `var' _code_

            if "`nodots'" != "" {
                replace _code_ = subinstr(_code_, ".", "", .)
            }

            drop if _code_ == "" | missing(_code_)
            count
            local total_entries = `total_entries' + r(N)

            if r(N) > 0 {
                contract _code_, freq(_freq)
                if `first' {
                    save `_combined', replace
                    local first = 0
                }
                else {
                    append using `_combined'
                    collapse (sum) _freq, by(_code_)
                    save `_combined', replace
                }
            }
        }

        if `first' {
            * No codes found at all
            restore
            noisily display as text _n "codescan describe: `nvars' variable" ///
                cond(`nvars' > 1, "s", "") ", 0 unique codes, 0 total entries"
            return scalar n_unique = 0
            return scalar n_entries = 0
            return scalar n_vars = `nvars'
            return local varlist "`varlist'"
            tempname _empty_tc _empty_ch
            matrix `_empty_tc' = J(1, 3, 0)
            matrix colnames `_empty_tc' = frequency percent cumul_pct
            matrix rownames `_empty_tc' = none
            matrix `_empty_ch' = J(1, 2, 0)
            matrix colnames `_empty_ch' = codes entries
            matrix rownames `_empty_ch' = none
            return matrix top_codes = `_empty_tc'
            return matrix chapters = `_empty_ch'
            exit
        }

        * Load accumulated frequencies
        use `_combined', clear
        gsort -_freq _code_
        count
        local total_codes = r(N)

        * Chapter summary (group by first character)
        gen str1 _chapter = substr(_code_, 1, 1)
    }

    * Display header
    display as text _n "codescan describe: `nvars' variable" ///
        cond(`nvars' > 1, "s", "") ", " as result `total_codes' ///
        as text " unique codes, " as result %10.0fc `total_entries' ///
        as text " total entries"

    * Display top-N codes (O5: with cumulative percent)
    display as text ""
    display as text "  Code" _col(20) %9s "Frequency" _col(32) %10s "Percent" _col(44) %10s "Cumul %"
    display as text "  {hline 52}"

    local show = min(`top', `total_codes')
    local _cum_pct = 0
    forvalues i = 1/`show' {
        local code = _code_[`i']
        local freq = _freq[`i']
        local pct = `freq' / `total_entries' * 100
        local _cum_pct = `_cum_pct' + `pct'
        display as text "  `code'" _col(20) as result %9.0fc `freq' ///
            _col(32) as result %9.1f `pct' as text "%" ///
            _col(44) as result %9.1f `_cum_pct' as text "%"
    }
    if `total_codes' > `top' {
        display as text "  ... (`=`total_codes' - `top'' more codes)"
    }

    * O4: Build r(top_codes) matrix before collapse destroys the data
    tempname top_codes
    matrix `top_codes' = J(`show', 3, .)
    local _tc_rnames ""
    local _tc_cum = 0
    forvalues i = 1/`show' {
        local _tc_code = _code_[`i']
        local _tc_freq = _freq[`i']
        local _tc_pct = `_tc_freq' / `total_entries' * 100
        local _tc_cum = `_tc_cum' + `_tc_pct'
        matrix `top_codes'[`i', 1] = `_tc_freq'
        matrix `top_codes'[`i', 2] = `_tc_pct'
        matrix `top_codes'[`i', 3] = `_tc_cum'
        local _tc_rnames `"`_tc_rnames' `_tc_code'"'
    }
    local _tc_rnames = trim(`"`_tc_rnames'"')
    matrix rownames `top_codes' = `_tc_rnames'
    matrix colnames `top_codes' = frequency percent cumul_pct

    * Chapter summary — collapse in place (outer preserve protects original data)
    display as text _n "  By first character:"
    display as text "  Char" _col(12) %9s "Codes" _col(24) %9s "Entries"
    display as text "  {hline 34}"

    quietly {
        collapse (count) _n_codes=_freq (sum) _n_entries=_freq, by(_chapter)
        gsort -_n_entries
        local n_chapters = _N
    }

    forvalues i = 1/`n_chapters' {
        local ch = _chapter[`i']
        local nc = _n_codes[`i']
        local ne = _n_entries[`i']
        display as text "  `ch'" _col(12) as result %9.0fc `nc' ///
            _col(24) as result %9.0fc `ne'
    }

    * O4: Build r(chapters) matrix
    tempname chapters
    matrix `chapters' = J(`n_chapters', 2, .)
    local _ch_rnames ""
    forvalues i = 1/`n_chapters' {
        local _ch_ch = _chapter[`i']
        matrix `chapters'[`i', 1] = _n_codes[`i']
        matrix `chapters'[`i', 2] = _n_entries[`i']
        local _ch_rnames "`_ch_rnames' `_ch_ch'"
    }
    local _ch_rnames = trim("`_ch_rnames'")
    matrix rownames `chapters' = `_ch_rnames'
    matrix colnames `chapters' = codes entries

    * O4: Pattern suggestion — suggest define() patterns for top chapters
    if `n_chapters' >= 2 {
        display as text _n "  Suggested patterns:"
        local _n_suggest = min(5, `n_chapters')
        forvalues i = 1/`_n_suggest' {
            local ch = _chapter[`i']
            local nc = _n_codes[`i']
            local ne = _n_entries[`i']
            display as text `"    define(chapter_`ch' "`ch'") — `nc' codes, `ne' entries"'
        }
    }

    * I3: Save draft codefile from chapter summary
    if `"`save'"' != "" {
        local _save_ext = lower(substr(`"`save'"', -4, .))
        if "`_save_ext'" != ".csv" {
            display as error "save() requires a .csv file extension"
            exit 198
        }
        * Data currently has: _chapter, _n_codes, _n_entries (from collapse)
        quietly {
            gen str32 name = "chapter_" + _chapter
            gen str244 pattern = _chapter
            gen str244 exclusion = ""
            gen str80 label = ""
            keep name pattern exclusion label
            export delimited using `"`save'"', replace
        }
        noisily display as text ///
            `"(draft codefile saved to `save' -- edit condition names and patterns before use)"'
    }

    * Return results (from locals captured before collapse)
    return scalar n_unique = `total_codes'
    return scalar n_entries = `total_entries'
    return scalar n_vars = `nvars'
    return local varlist "`varlist'"
    return matrix top_codes = `top_codes'
    return matrix chapters = `chapters'

    restore  // back to original data

    } // end capture noisily
    local rc = _rc
    if `rc' {
        capture restore
    }
    set varabbrev `_orig_varabbrev'
    if `rc' exit `rc'
end
