*! _tabtools_common Version 1.0.3  2026/02/25
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

* End of file
