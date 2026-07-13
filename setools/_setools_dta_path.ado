*! _setools_dta_path Version 1.5.0  2026/07/13
*! setools internal: canonicalize an effective Stata dataset path
*! Author: Timothy P Copeland, Karolinska Institutet

program define _setools_dta_path, rclass
    version 16.0
    syntax, PATH(string)

    local _raw = strtrim(`"`path'"')
    if `"`_raw'"' == "" {
        di as error "file path may not be empty"
        exit 198
    }

    * The Unix canonicalization fallback is invoked through a quoted shell
    * argument. Reject every character that could escape or alter that command,
    * plus control characters that do not belong in a package file option.
    foreach _ascii in 9 10 13 34 36 38 59 60 62 96 124 {
        if strpos(`"`_raw'"', char(`_ascii')) {
            di as error "file path contains invalid characters"
            exit 198
        }
    }
    if "`c(os)'" != "Windows" & strpos(`"`_raw'"', char(92)) {
        di as error "file path contains invalid characters"
        exit 198
    }

    local _base `"`c(pwd)'"'
    mata: st_local("_canonical", pathresolve(st_local("_base"), st_local("_raw")))
    mata: st_local("_canonical", pathsuffix(st_local("_canonical")) == "" ? st_local("_canonical") + ".dta" : st_local("_canonical"))

    * GNU readlink -m resolves dot segments, missing final targets, and existing
    * symlinks. Mata's portable lexical result remains the fallback elsewhere.
    if "`c(os)'" != "Windows" {
        tempfile _resolved_file
        capture quietly shell readlink -m -- "`_canonical'" > "`_resolved_file'"
        if !_rc {
            tempname _resolved_handle
            capture file open `_resolved_handle' using "`_resolved_file'", ///
                read text
            if !_rc {
                file read `_resolved_handle' _resolved_line
                file close `_resolved_handle'
                if !_rc & strtrim(`"`_resolved_line'"') != "" {
                    local _canonical = strtrim(`"`_resolved_line'"')
                }
            }
        }
    }

    return local path `"`_canonical'"'
end
