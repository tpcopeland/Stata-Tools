*! _gcomp_xl_common Version 1.0.0  2026/04/08
*! Shared Excel export utility programs for gcomp package
*! Author: Timothy P Copeland

/*
DESCRIPTION:
    Common utility programs for Excel table export in the gcomp package.
    Adapted from _mlearn_xl_common.ado for self-contained distribution.

PROGRAMS INCLUDED:
    _gcomp_col_letter        - Convert column number to Excel letter
    _gcomp_validate_path     - Validate file path for dangerous characters
    _gcomp_xl_footnote       - Write a merged footnote row to an open putexcel session
    _gcomp_xl_open           - Open an xlsx file in the OS default application
    _gcomp_xl_validate_sheet - Validate Excel sheet name

USAGE:
    Called internally by gcomptab. Not intended for direct use.
    Callers set varabbrev off; helpers do not need to set it independently.
*/

* =============================================================================
* _gcomp_col_letter: Convert column number to Excel letter reference
* =============================================================================
* Converts 1 -> A, 2 -> B, ..., 26 -> Z, 27 -> AA, 28 -> AB, etc.
* Returns result in c_local variable 'result'

program _gcomp_col_letter
    version 16.0
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
* _gcomp_validate_path: Validate file path for security
* =============================================================================
* Checks for dangerous characters that could enable command injection.

program _gcomp_validate_path
    version 16.0
    args filepath option_name

    local _has_bad = regexm(`"`filepath'"', "[;&|><\$\`]")
    if !`_has_bad' {
        local _has_bad = strpos(`"`filepath'"', char(34)) > 0 | ///
                         strpos(`"`filepath'"', char(39)) > 0
    }
    if `_has_bad' {
        display as error "`option_name' contains invalid characters"
        exit 198
    }
end

* =============================================================================
* _gcomp_xl_footnote: Write a merged footnote row
* =============================================================================
* Requires putexcel to already be open. Uses smaller italic font.

program _gcomp_xl_footnote
    version 16.0
    args footnote lastcol_letter row fontname fontsize

    if `"`footnote'"' == "" exit

    if "`fontname'" == "" local fontname "Arial"
    if "`fontsize'" == "" local fontsize "10"

    local frow = `row' + 1
    local fn_fontsize = max(`fontsize' - 2, 6)

    putexcel B`frow' = `"`footnote'"'
    putexcel (B`frow':`lastcol_letter'`frow'), merge left vcenter txtwrap
    putexcel (B`frow':`lastcol_letter'`frow'), font("`fontname'", `fn_fontsize') italic
end

* =============================================================================
* _gcomp_xl_open: Open an xlsx file in the OS default application
* =============================================================================

program _gcomp_xl_open
    version 16.0
    args filepath

    if "`filepath'" == "" exit

    if "`c(os)'" == "MacOSX" {
        shell open "`filepath'" &
    }
    else if "`c(os)'" == "Windows" {
        shell start "" "`filepath'"
    }
    else {
        shell xdg-open "`filepath'" &
    }
end

* =============================================================================
* _gcomp_xl_validate_sheet: Validate Excel sheet name
* =============================================================================

program _gcomp_xl_validate_sheet
    version 16.0
    args sheet option_name
    if strlen("`sheet'") > 31 {
        display as error "`option_name': sheet name '`sheet'' exceeds Excel's 31-character limit"
        exit 198
    }
    if regexm("`sheet'", "[\\\\/\?\*\[\]]") {
        display as error "`option_name': sheet name contains characters not allowed by Excel (\ / ? * [ ])"
        exit 198
    }
end

* End of file
