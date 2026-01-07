*! _tabtools_common Version 1.0.0  2026/01/07
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
    _tabtools_format_pvalue  - Format p-values consistently across commands

USAGE:
    These programs are called internally by tabtools commands (table1_tc, regtab,
    effecttab, gformtab, stratetab, tablex). They are not intended for direct use.
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
    args filepath option_name

    * Check for shell metacharacters and command injection vectors
    if regexm("`filepath'", "[;&|><\$\`]") {
        display as error "`option_name' contains invalid characters"
        exit 198
    }
end

* =============================================================================
* _tabtools_format_pvalue: Format p-value string consistently
* =============================================================================
* Formats a numeric p-value into a display string with appropriate precision.
* - p < 0.001: returns "<0.001"
* - 0.001 <= p < 0.05: 3 decimal places
* - p >= 0.05: 2 decimal places
* Returns result in c_local variable 'result'
*
* Usage: _tabtools_format_pvalue 0.0234
*        local formatted = "`result'"   // formatted = "0.023"

program _tabtools_format_pvalue
    version 16.0
    set varabbrev off
    args pval

    local formatted = ""

    if missing(`pval') {
        local formatted = ""
    }
    else if `pval' < 0 {
        * Negative p-values shouldn't happen but safety check
        local formatted = "<0.001"
    }
    else if `pval' < 0.001 {
        local formatted = "<0.001"
    }
    else if `pval' < 0.05 {
        local formatted = string(`pval', "%5.3f")
    }
    else {
        local formatted = string(`pval', "%4.2f")
    }

    * Add leading zero if missing (e.g., .123 -> 0.123)
    if substr("`formatted'", 1, 1) == "." {
        local formatted = "0`formatted'"
    }

    c_local result "`formatted'"
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
    args num_cols

    local col_letters ""

    forvalues i = 1/`num_cols' {
        local col_letter = ""
        local temp_i = `i'

        while `temp_i' > 0 {
            local remainder = mod(`temp_i' - 1, 26)
            local col_letter = char(`remainder' + 65) + "`col_letter'"
            local temp_i = floor((`temp_i' - 1) / 26)
        }

        local col_letters = "`col_letters' `col_letter'"
    }

    * Trim leading space
    local col_letters = strtrim("`col_letters'")

    c_local result "`col_letters'"
end

* End of file
