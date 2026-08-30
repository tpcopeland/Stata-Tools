*! _msm_validate_path Version 1.4.8  2026/08/30
*! Reject file paths that are unsafe to interpolate into a shell command
*! Author: Timothy P Copeland, Karolinska Institutet

program define _msm_validate_path, nclass
    version 16.0
    local _orig_varabbrev = c(varabbrev)
    set varabbrev off
    capture noisily {
        syntax , PATH(string) [CONTEXT(string)]

        if `"`context'"' == "" local context "file path"
        local _unsafe = 0
        * Double-quoted shell arguments still expand $, backticks, and Windows
        * environment syntax. Reject those plus command separators, redirects,
        * escape/control characters, while allowing an ordinary apostrophe.
        foreach _code in 33 34 36 37 38 59 60 62 94 96 124 127 {
            if strpos(`"`macval(path)'"', char(`_code')) > 0 {
                local _unsafe = 1
            }
        }
        forvalues _code = 1/31 {
            if strpos(`"`macval(path)'"', char(`_code')) > 0 {
                local _unsafe = 1
            }
        }
        if `_unsafe' {
            display as error ///
                "`context' may not contain shell metacharacters or quote characters"
            exit 198
        }
    }
    local _rc = _rc
    set varabbrev `_orig_varabbrev'
    if `_rc' exit `_rc'
end
