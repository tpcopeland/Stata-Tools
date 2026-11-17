*! _psdash_validate_sheet Version 1.9.1  2026/11/17
*! Validate a user-supplied Excel worksheet name before any computation
*! Author: Timothy P Copeland, Karolinska Institutet
*! Program class: nclass
*! Internal helper

* Excel refuses a worksheet name longer than 31 bytes, containing any of
* : \ / ? * [ ] , beginning or ending with an apostrophe, or named History;
* a double quote additionally breaks the putexcel/xl() call. Caught here,
* the error arrives before the command prints or computes anything instead
* of after the console tables, as a late r(603)/r(691).
* Call as: _psdash_validate_sheet, sheet(`"`sheet'"') [option(name)]
program define _psdash_validate_sheet, nclass
    version 16.0
    local _vao = c(varabbrev)
    set varabbrev off
    capture noisily {
        syntax , SHEET(string) [OPTion(name)]
        if "`option'" == "" local option "sheet"

        * putexcel enforces the 31 limit in bytes, so a non-ASCII name of
        * fewer than 31 characters can still be too long.
        if strlen(`"`sheet'"') > 31 {
            display as error "`option'() must be at most 31 bytes (an Excel worksheet name limit;"
            display as error "  a non-ASCII character takes 2 to 4 bytes)"
            exit 198
        }
        local _bad 0
        foreach _c in ":" "\" "/" "?" "*" "[" "]" {
            if strpos(`"`sheet'"', "`_c'") local _bad 1
        }
        if strpos(`"`sheet'"', char(34)) local _bad 1
        if `_bad' {
            display as error `"`option'() cannot contain any of : \ / ? * [ ] or a double quote"'
            exit 198
        }
        if substr(`"`sheet'"', 1, 1) == "'" | substr(`"`sheet'"', -1, 1) == "'" {
            display as error "`option'() cannot begin or end with an apostrophe"
            exit 198
        }
        if lower(`"`sheet'"') == "history" {
            display as error "`option'() cannot be History (a name Excel reserves)"
            exit 198
        }
    }
    local rc = _rc
    set varabbrev `_vao'
    if `rc' == 0 return clear
    if `rc' exit `rc'
end
