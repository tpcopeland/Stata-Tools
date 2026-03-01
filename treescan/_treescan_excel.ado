*! _treescan_excel Version 1.4.0  2026/03/01
*! Shared utility programs for treescan Excel export
*! Author: Tim Copeland, Karolinska Institutet

/*
DESCRIPTION:
    Common utility programs for treescan Excel export.
    Handles column letter conversion, path validation.

PROGRAMS INCLUDED:
    _treescan_col_letter       - Convert column number to Excel letter
    _treescan_build_col_letters - Build letter list for N columns
    _treescan_validate_path    - Validate file path for dangerous characters
*/

* =============================================================================
* _treescan_col_letter: Convert column number to Excel letter reference
* =============================================================================
* Converts 1 -> A, 2 -> B, ..., 26 -> Z, 27 -> AA, 28 -> AB, etc.
* Returns result in c_local variable 'result'

program _treescan_col_letter
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
* _treescan_build_col_letters: Build list of Excel column letters for N columns
* =============================================================================
* Returns result in c_local variable 'result'

program _treescan_build_col_letters
    version 16.0
    set varabbrev off
    set more off
    args num_cols

    local col_letters ""

    forvalues i = 1/`num_cols' {
        _treescan_col_letter `i'
        local col_letters = "`col_letters' `result'"
    }

    local col_letters = strtrim("`col_letters'")

    c_local result "`col_letters'"
end

* =============================================================================
* _treescan_validate_path: Validate file path for security
* =============================================================================
* Checks for dangerous characters that could enable command injection.

program _treescan_validate_path
    version 16.0
    set varabbrev off
    set more off
    args filepath option_name

    if regexm("`filepath'", "[;&|><\$\`]") {
        display as error "`option_name' contains invalid characters"
        exit 198
    }
end

* End of file
