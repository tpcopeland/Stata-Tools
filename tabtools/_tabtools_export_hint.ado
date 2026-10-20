*! _tabtools_export_hint Version 1.0.1  2026/10/20
*! the hint printed after a failed file export: a missing directory, or a file held open
*! Author: Timothy P Copeland, Karolinska Institutet
*! Program class: nclass

/*
A failed xlsx write (rc 603/608/610/16106, ...) has two common causes: the
target directory does not exist, or the workbook is open in another
application. This program tells them apart so the hint names the right one.

Usage: _tabtools_export_hint `"filename"' [, kind(xlsx)]
Prints one "Hint:" line as an error; returns nothing.
*/

capture program drop _tabtools_export_hint
program define _tabtools_export_hint, nclass
    version 17.0
    local _orig_varabbrev = c(varabbrev)
    set varabbrev off
    capture noisily {
        syntax anything(name=fname id="filename") [, KIND(string)]
        if `"`kind'"' == "" local kind "xlsx"
        gettoken fname : fname
        * directory part: everything up to the last / or \ (none = cwd)
        local _dir = ustrregexra(`"`fname'"', "[^/\\\\]*$", "")
        local _dir_ok 1
        if `"`_dir'"' != "" & substr(`"`_dir'"', 1, 1) != "~" {
            mata: st_local("_dir_ok", strofreal(direxists(st_local("_dir"))))
        }
        if !`_dir_ok' {
            noisily display as error `"Hint: the directory `_dir' does not exist"'
        }
        else {
            noisily display as error "Hint: ensure the `kind' file is not open in another application and the directory is writable"
        }
    }
    local rc = _rc
    set varabbrev `_orig_varabbrev'
    if `rc' exit `rc'
end

