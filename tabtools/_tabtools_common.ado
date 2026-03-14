*! _tabtools_common Version 1.0.4  2026/03/14
*! Shared utility programs for tabtools package
*! Author: Timothy P Copeland

/*
DESCRIPTION:
    Common utility programs shared across the tabtools suite of table export
    commands. These utilities handle Excel column letter conversion, path
    validation, and p-value formatting.

PROGRAMS INCLUDED:
    _tabtools_col_letter     - Convert column number to Excel letter (A, B, ..., Z, AA, AB, ...)
    _tabtools_validate_path  - Validate file path for dangerous characters

USAGE:
    These programs are called internally by tabtools commands (table1_tc, regtab,
    effecttab, gcomptab, stratetab, tablex). They are not intended for direct use.
*/

* =============================================================================
* _tabtools_col_letter: Convert column number to Excel letter reference
* =============================================================================
* Converts 1 -> A, 2 -> B, ..., 26 -> Z, 27 -> AA, 28 -> AB, etc.
* Returns result in c_local variable 'result'
*
* Usage: _tabtools_col_letter 3
*        local my_letter = "`result'"   // my_letter = "C"

program _tabtools_col_letter
    version 16.0
    set varabbrev off
    set more off
    args col_num

    local col_letter = ""
    local temp_num = `col_num'

    while `temp_num' > 0 {
        local remainder = mod(`temp_num' - 1, 26)
        local col_letter = char(`remainder' + 65) + "`col_letter'"
        local temp_num = floor((`temp_num' - 1) / 26)
    }

    c_local result "`col_letter'"
end

* =============================================================================
* _tabtools_validate_path: Validate file path for security
* =============================================================================
* Checks for dangerous characters that could enable command injection.
* Returns error code 198 if invalid characters found.
*
* Usage: _tabtools_validate_path "`filepath'" "xlsx()"
*        (exits with error if invalid)

program _tabtools_validate_path
    version 16.0
    set varabbrev off
    set more off
    args filepath option_name

    * Check for shell metacharacters and command injection vectors
    if regexm("`filepath'", "[;&|><\$\`]") {
        display as error "`option_name' contains invalid characters"
        exit 198
    }
end

* =============================================================================
* _tabtools_build_col_letters: Build list of Excel column letters for N columns
* =============================================================================
* Creates a space-separated list of column letters for columns 1 to N.
* Returns result in c_local variable 'result'
*
* Usage: _tabtools_build_col_letters 30
*        local letters = "`result'"   // letters = "A B C ... AA AB AC AD"

program _tabtools_build_col_letters
    version 16.0
    set varabbrev off
    set more off
    args num_cols

    local col_letters ""

    forvalues i = 1/`num_cols' {
        _tabtools_col_letter `i'
        local col_letters = "`col_letters' `result'"
    }

    * Trim leading space
    local col_letters = strtrim("`col_letters'")

    c_local result "`col_letters'"
end

* =============================================================================
* _tabtools_sparkline: Generate a sparkline PNG for a variable
* =============================================================================
* Creates a small distribution plot (kdensity, histogram, or bar chart)
* saved as a PNG file for embedding in Excel via putexcel picture().
*
* Usage: _tabtools_sparkline varname [if], type(contn) savepath("path.png")
*        [width(120) height(35) sparktype(kdensity)]

program _tabtools_sparkline
    version 16.0
    set varabbrev off
    set more off

    syntax varname [if], type(string) savepath(string) ///
        [width(integer 75) height(integer 20) sparktype(string)]

    if "`sparktype'" == "" local sparktype "kdensity"

    * preserve/restore wraps all data modifications; the outer capture block
    * ensures restore always runs even if graph generation fails
    preserve

    if `"`if'"' != "" qui keep `if'
    qui drop if missing(`varlist')

    qui count
    if r(N) < 2 {
        restore
        exit
    }

    capture {
        if inlist("`type'", "contn", "contln", "conts") {
            if "`type'" == "contln" {
                qui replace `varlist' = ln(`varlist')
                qui drop if missing(`varlist')
            }

            if "`sparktype'" == "histogram" {
                twoway histogram `varlist', ///
                    color(navy%60) lcolor(navy%80) lwidth(vthin) ///
                    scheme(plotplainblind) ///
                    xscale(off noline) yscale(off noline) ///
                    xlabel(none) ylabel(none) ///
                    legend(off) ///
                    graphregion(margin(zero) color(white)) ///
                    plotregion(margin(zero) style(none)) ///
                    title("") subtitle("") note("") caption("")
            }
            else {
                twoway kdensity `varlist', ///
                    color(navy%60) lcolor(navy) lwidth(medthin) ///
                    recast(area) ///
                    scheme(plotplainblind) ///
                    xscale(off noline) yscale(off noline) ///
                    xlabel(none) ylabel(none) ///
                    legend(off) ///
                    graphregion(margin(zero) color(white)) ///
                    plotregion(margin(zero) style(none)) ///
                    title("") subtitle("") note("") caption("")
            }
        }
        else if inlist("`type'", "cat", "cate") {
            tempvar catvar
            capture confirm numeric variable `varlist'
            if !_rc qui clonevar `catvar' = `varlist'
            else qui encode `varlist', gen(`catvar')

            contract `catvar'
            qui egen _total = total(_freq)
            qui gen _prop = _freq / _total

            twoway bar _prop `catvar', ///
                color(navy%60) lcolor(navy%80) lwidth(vthin) ///
                barwidth(0.7) ///
                scheme(plotplainblind) ///
                xscale(off noline) yscale(off noline) ///
                xlabel(none) ylabel(none) ///
                legend(off) ///
                graphregion(margin(zero) color(white)) ///
                plotregion(margin(zero) style(none)) ///
                title("") subtitle("") note("") caption("")
        }
        else if inlist("`type'", "bin", "bine") {
            contract `varlist'
            qui egen _total = total(_freq)
            qui gen _prop = _freq / _total

            twoway bar _prop `varlist', ///
                color(navy%60) lcolor(navy%80) lwidth(vthin) ///
                barwidth(0.7) ///
                scheme(plotplainblind) ///
                xscale(off noline) yscale(off noline) ///
                xlabel(none) ylabel(none) ///
                legend(off) ///
                graphregion(margin(zero) color(white)) ///
                plotregion(margin(zero) style(none)) ///
                title("") subtitle("") note("") caption("")
        }

        qui graph export "`savepath'", width(`width') height(`height') replace
        capture graph drop _all
    }

    restore
end

* End of file
