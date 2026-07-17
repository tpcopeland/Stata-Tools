*! _codescan_validate_path Version 3.0.2  2026/07/17
*! Private file-path validation helper for codescan
*! Author: Timothy P Copeland, Karolinska Institutet

capture program drop _codescan_validate_path
program define _codescan_validate_path
    version 16.0
    local _orig_varabbrev = c(varabbrev)
    set varabbrev off
    capture noisily {

    syntax , PATH(string) CONTEXT(string)

    * Reject characters that can turn a later file operation or shell-open
    * convenience into command injection. Outer quotes are consumed by syntax.
    foreach _ascii in 10 13 34 36 38 59 60 62 96 124 {
        if strpos(`"`macval(path)'"', char(`_ascii')) > 0 {
            display as error "`context': filename contains an unsafe character"
            exit 198
        }
    }

    }
    local rc = _rc
    set varabbrev `_orig_varabbrev'
    if `rc' exit `rc'
end
