*! codescan_describe Version 2.0.9  2026/07/09
*! Tabulate unique codes across wide-format variables
*! Author: Timothy P Copeland, Karolinska Institutet
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
    codescan_describe varlist [if] [in] [, Top(integer 20) NODots TOSTRing SAVE(string)]

STORED RESULTS:
    r(n_unique)   - Number of unique codes found
    r(n_entries)  - Total non-empty code entries across all variables
    r(n_vars)     - Number of variables scanned
    r(varlist)    - Variables scanned
    r(top_codes)  - Matrix: frequency, percent, cumulative percent per code
    r(chapters)   - Matrix: code count, entry count per first-character chapter
*/

program define codescan_describe, rclass
    version 16.0
    local _orig_varabbrev = c(varabbrev)
    set varabbrev off
    local _did_preserve = 0
    capture noisily {

    syntax varlist [if] [in] [, Top(integer 20) NODots TOSTRing SAVE(string)]

    if `"`save'"' != "" {
        _codescan_validate_path, path(`"`save'"') context(save())
    }

    * Validate top
    if `top' < 1 {
        display as error "top() must be a positive integer"
        exit 198
    }

    * Reject a variable that appears more than once in varlist (directly or via
    * overlapping ranges like dx1-dx5 dx3-dx8). A repeated scan column would be
    * tabulated once per occurrence, double-counting its codes and entries.
    local _dupvars : list dups varlist
    if `"`_dupvars'"' != "" {
        display as error "varlist contains repeated variable(s): `_dupvars'"
        display as error "remove duplicate or overlapping scan variables"
        exit 198
    }

    * Validate string variables (before tostring, to catch missing option early).
    * strL is rejected unconditionally: the Mata tabulator reads columns with
    * st_sview(), which cannot form views onto strL variables.
    foreach var of local varlist {
        capture confirm string variable `var'
        if _rc {
            if "`tostring'" == "" {
                display as error "`var' is not a string variable"
                display as error "codescan_describe requires string variables; use tostring or the tostring option"
                exit 109
            }
        }
        else if "`: type `var''" == "strL" {
            display as error "`var' is a strL variable and cannot be scanned"
            display as error "convert it to a fixed-width string first, e.g. {bf:compress `var'} or {bf:recast str244 `var'}"
            exit 109
        }
    }

    marksample touse, novarlist

    quietly count if `touse'
    if r(N) == 0 {
        display as error "no observations"
        exit 2000
    }

    local nvars : word count `varlist'

    * Auto-convert numeric variables if tostring specified
    if "`tostring'" != "" {
        preserve
        local _did_preserve = 1
        foreach var of local varlist {
            capture confirm string variable `var'
            if _rc {
                noisily display as text "(note: converting `var' from numeric to string)"
                quietly tostring `var', replace force
            }
        }
    }

    * Tabulate via single Mata pass (hash map over all vars, no tempfile I/O)
    local _desc_scanvars "`varlist'"
    local _desc_touse "`touse'"
    local _desc_nodots "`nodots'"
    local _desc_top "`top'"
    tempname _desc_tc _desc_ch
    local _desc_tc_name "`_desc_tc'"
    local _desc_ch_name "`_desc_ch'"
    mata: _codescan_describe_tabulate()

    if "`tostring'" != "" {
        restore
        local _did_preserve = 0
    }

    local total_codes = `_desc_total_codes'
    local total_entries = `_desc_total_entries'
    local show = `_desc_show'
    local n_chapters = `_desc_n_chapters'

    if `total_codes' == 0 {
        display as text _n "codescan describe: `nvars' variable" ///
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

    * Display header
    display as text _n "codescan describe: `nvars' variable" ///
        cond(`nvars' > 1, "s", "") ", " as result `total_codes' ///
        as text " unique codes, " as result %10.0fc `total_entries' ///
        as text " total entries"

    * Display top-N codes
    display as text ""
    display as text "  Code" _col(20) %9s "Frequency" _col(32) %10s "Percent" _col(44) %10s "Cumul %"
    display as text "  {hline 52}"

    local _cum_pct = 0
    forvalues i = 1/`show' {
        local code "`_desc_code_`i''"
        local freq = `_desc_freq_`i''
        local pct = `freq' / `total_entries' * 100
        local _cum_pct = `_cum_pct' + `pct'
        display as text `"  `code'"' _col(20) as result %9.0fc `freq' ///
            _col(32) as result %9.1f `pct' as text "%" ///
            _col(44) as result %9.1f `_cum_pct' as text "%"
    }
    if `total_codes' > `top' {
        display as text "  ... (`=`total_codes' - `top'' more codes)"
    }

    * Build r(top_codes) matrix from Mata-returned locals
    tempname top_codes
    matrix `top_codes' = J(`show', 3, .)
    local _tc_rnames ""
    local _tc_cum = 0
    forvalues i = 1/`show' {
        local _tc_code "`_desc_code_`i''"
        local _tc_freq = `_desc_freq_`i''
        local _tc_pct = `_tc_freq' / `total_entries' * 100
        local _tc_cum = `_tc_cum' + `_tc_pct'
        matrix `top_codes'[`i', 1] = `_tc_freq'
        matrix `top_codes'[`i', 2] = `_tc_pct'
        matrix `top_codes'[`i', 3] = `_tc_cum'
        local _tc_rnames `"`_tc_rnames' `"`_tc_code'"'"'
    }
    matrix rownames `top_codes' = `_tc_rnames'
    matrix colnames `top_codes' = frequency percent cumul_pct

    * Chapter summary
    display as text _n "  By first character:"
    display as text "  Char" _col(12) %9s "Codes" _col(24) %9s "Entries"
    display as text "  {hline 34}"

    forvalues i = 1/`n_chapters' {
        local ch "`_desc_ch_`i''"
        local nc = `_desc_ch_codes_`i''
        local ne = `_desc_ch_entries_`i''
        display as text `"  `ch'"' _col(12) as result %9.0fc `nc' ///
            _col(24) as result %9.0fc `ne'
    }

    * Build r(chapters) matrix
    tempname chapters
    matrix `chapters' = J(`n_chapters', 2, .)
    local _ch_rnames ""
    forvalues i = 1/`n_chapters' {
        local _ch_ch "`_desc_ch_`i''"
        matrix `chapters'[`i', 1] = `_desc_ch_codes_`i''
        matrix `chapters'[`i', 2] = `_desc_ch_entries_`i''
        local _ch_rnames `"`_ch_rnames' `"`_ch_ch'"'"'
    }
    matrix rownames `chapters' = `_ch_rnames'
    matrix colnames `chapters' = codes entries

    * Draft-rule names must remain valid Stata names even when a chapter starts
    * with punctuation. strtoname() can map different punctuation to the same
    * name, so suffix collisions deterministically.
    forvalues i = 1/`n_chapters' {
        local _ch `"`_desc_ch_`i''"'
        local _rule_name = strtoname(`"chapter_`_ch'"')
        local _rule_dup = 0
        forvalues j = 1/`=`i'-1' {
            if "`_rule_name'" == "`_desc_rule_name_`j''" local _rule_dup = 1
        }
        if `_rule_dup' local _rule_name "`_rule_name'_`i'"
        local _desc_rule_name_`i' "`_rule_name'"
    }

    * Pattern suggestion
    if `n_chapters' >= 2 {
        display as text _n "  Suggested patterns:"
        local _n_suggest = min(5, `n_chapters')
        forvalues i = 1/`_n_suggest' {
            local ch "`_desc_ch_`i''"
            local nc = `_desc_ch_codes_`i''
            local ne = `_desc_ch_entries_`i''
            display as text `"    define(`_desc_rule_name_`i'' "`ch'") — `nc' codes, `ne' entries"'
        }
    }

    * Return analytical results before optional save() so r() survives side-effect failures.
    return scalar n_unique = `total_codes'
    return scalar n_entries = `total_entries'
    return scalar n_vars = `nvars'
    return local varlist "`varlist'"
    return matrix top_codes = `top_codes', copy
    return matrix chapters = `chapters', copy

    * Save draft codefile from chapter summary
    if `"`save'"' != "" {
        local _save_ext = lower(substr(`"`save'"', -4, .))
        if "`_save_ext'" != ".csv" {
            display as error "save() requires a .csv file extension"
            exit 198
        }
        preserve
        local _did_preserve = 1
        quietly {
            clear
            set obs `n_chapters'
            gen str32 name = ""
            gen str244 pattern = ""
            gen str244 exclusion = ""
            gen str80 label = ""
            forvalues i = 1/`n_chapters' {
                replace name = "`_desc_rule_name_`i''" in `i'
                replace pattern = `"`_desc_ch_`i''"' in `i'
            }
            keep name pattern exclusion label
            export delimited using `"`save'"', replace
        }
        restore
        local _did_preserve = 0
        noisily display as text ///
            `"(draft codefile saved to `save' -- edit condition names and patterns before use)"'
    }

    } // end capture noisily
    local rc = _rc
    if `_did_preserve' capture restore
    set varabbrev `_orig_varabbrev'
    if `rc' exit `rc'
end

* =============================================================================
* MATA: Single-pass hash-map tabulation (replaces foreach/contract/append loop)
* =============================================================================

mata:
void _codescan_describe_tabulate()
{
    string rowvector scanvars
    string colvector col
    real colvector   touse
    string scalar    touse_name, val, ch
    real scalar      N, nvars, i, j, total_entries, strip_dots, top_n, show
    real scalar      n_unique, n_chapters, si, ci
    real rowvector   cv, prev

    scanvars   = tokens(st_local("_desc_scanvars"))
    touse_name = st_local("_desc_touse")
    strip_dots = (st_local("_desc_nodots") != "")
    top_n      = strtoreal(st_local("_desc_top"))
    nvars      = cols(scanvars)
    N          = st_nobs()
    touse      = st_data(., touse_name)

    transmorphic freq_map
    freq_map = asarray_create()
    asarray_notfound(freq_map, 0)

    total_entries = 0

    for (j = 1; j <= nvars; j++) {
        st_sview(col, ., scanvars[j])

        for (i = 1; i <= N; i++) {
            if (!touse[i]) continue
            val = col[i]
            if (val == "" || val == ".") continue
            if (strip_dots) {
                val = subinstr(val, ".", "", .)
                if (val == "") continue
            }
            asarray(freq_map, val, asarray(freq_map, val) + 1)
            total_entries = total_entries + 1
        }
    }

    string colvector keys
    keys = asarray_keys(freq_map)
    n_unique = rows(keys)

    st_local("_desc_total_entries", strofreal(total_entries))
    st_local("_desc_total_codes", strofreal(n_unique))

    if (n_unique == 0) {
        st_local("_desc_show", "0")
        st_local("_desc_n_chapters", "0")
        return
    }

    // Build frequency vector and sort descending
    real colvector freqs
    freqs = J(n_unique, 1, 0)
    for (i = 1; i <= n_unique; i++) {
        freqs[i] = asarray(freq_map, keys[i])
    }
    real colvector sort_idx
    sort_idx = order(-freqs, 1)

    // Return top-N codes via locals
    show = (top_n < n_unique ? top_n : n_unique)
    st_local("_desc_show", strofreal(show))
    for (i = 1; i <= show; i++) {
        si = sort_idx[i]
        st_local("_desc_code_" + strofreal(i), keys[si])
        st_local("_desc_freq_" + strofreal(i), strofreal(freqs[si]))
    }

    // Chapter summary: group by first character
    transmorphic ch_map
    ch_map = asarray_create()
    asarray_notfound(ch_map, J(1, 2, 0))

    for (i = 1; i <= n_unique; i++) {
        ch = usubstr(keys[i], 1, 1)
        prev = asarray(ch_map, ch)
        asarray(ch_map, ch, (prev[1] + 1, prev[2] + freqs[i]))
    }

    string colvector ch_keys
    ch_keys = asarray_keys(ch_map)
    n_chapters = rows(ch_keys)
    st_local("_desc_n_chapters", strofreal(n_chapters))

    // Sort chapters by entries descending
    real colvector ch_entries
    ch_entries = J(n_chapters, 1, 0)
    for (i = 1; i <= n_chapters; i++) {
        cv = asarray(ch_map, ch_keys[i])
        ch_entries[i] = cv[2]
    }
    real colvector ch_sort
    ch_sort = order(-ch_entries, 1)

    for (i = 1; i <= n_chapters; i++) {
        ci = ch_sort[i]
        cv = asarray(ch_map, ch_keys[ci])
        st_local("_desc_ch_" + strofreal(i), ch_keys[ci])
        st_local("_desc_ch_codes_" + strofreal(i), strofreal(cv[1]))
        st_local("_desc_ch_entries_" + strofreal(i), strofreal(cv[2]))
    }
}
end
