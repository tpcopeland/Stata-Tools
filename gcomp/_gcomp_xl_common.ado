*! _gcomp_xl_common Version 1.3.2  2026/06/25
*! Shared Excel export utility programs for gcomp package
*! Author: Timothy P Copeland, Karolinska Institutet

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
    _gcomp_xl_helpers_ready  - Verify helper bundle completeness
    _gcomp_xl_require_helpers- Require helper bundle completeness

USAGE:
    Called internally by gcomptab. Not intended for direct use.
    Callers disable variable abbreviation; helpers do not need to change it.
*/

* =============================================================================
* _gcomp_col_letter: Convert column number to Excel letter reference
* =============================================================================
* Converts 1 -> A, 2 -> B, ..., 26 -> Z, 27 -> AA, 28 -> AB, etc.
* Returns result in c_local variable 'result'

capture program drop _gcomp_col_letter
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

capture program drop _gcomp_validate_path
program _gcomp_validate_path
    version 16.0
    args filepath option_name

    local _has_bad = regexm(`"`filepath'"', "[;&|><\$\`]")
    if !`_has_bad' {
        local _has_bad = strpos(`"`filepath'"', char(34)) > 0
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

capture program drop _gcomp_xl_footnote
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

capture program drop _gcomp_xl_open
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
* _gcomp_xl_helpers_ready: Verify helper bundle completeness
* =============================================================================
* Returns rc=0 when all requested helpers are loaded; rc=111 otherwise.

capture program drop _gcomp_xl_helpers_ready
program _gcomp_xl_helpers_ready
    version 16.0
    args required

    if `"`required'"' == "" {
        local required "_gcomp_col_letter _gcomp_validate_path _gcomp_xl_footnote _gcomp_xl_open _gcomp_xl_validate_sheet _gcomp_xl_require_helpers"
    }

    foreach _prog of local required {
        capture program list `_prog'
        if _rc exit 111
    }
end

* =============================================================================
* _gcomp_xl_require_helpers: Require helper bundle completeness
* =============================================================================
* Displays a reinstall message and exits rc=111 when helpers are not loaded.

capture program drop _gcomp_xl_require_helpers
program _gcomp_xl_require_helpers
    version 16.0
    syntax [, REQUIRED(string asis) FAILMessage(string asis)]

    if `"`failmessage'"' == "" {
        local failmessage "_gcomp_xl_common.ado failed to load fully; reinstall gcomp"
    }

    capture _gcomp_xl_helpers_ready `"`required'"'
    if _rc {
        noisily display as error `"`failmessage'"'
        exit 111
    }
end

* =============================================================================
* _gcomp_xl_validate_sheet: Validate Excel sheet name
* =============================================================================

capture program drop _gcomp_xl_validate_sheet
program _gcomp_xl_validate_sheet
    version 16.0
    args sheet option_name
    if strlen("`sheet'") > 31 {
        display as error "`option_name': sheet name '`sheet'' exceeds Excel's 31-character limit"
        exit 198
    }
    local _has_bad = strpos(`"`sheet'"', ":") > 0 | ///
        strpos(`"`sheet'"', char(92)) > 0 | ///
        strpos(`"`sheet'"', "/") > 0 | ///
        strpos(`"`sheet'"', "?") > 0 | ///
        strpos(`"`sheet'"', "*") > 0 | ///
        strpos(`"`sheet'"', "[") > 0 | ///
        strpos(`"`sheet'"', "]") > 0
    if `_has_bad' {
        display as error "`option_name': sheet name contains characters not allowed by Excel (: \\ / ? * [ ])"
        exit 198
    }
end

* End of file
