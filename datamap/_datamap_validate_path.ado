*! _datamap_validate_path Version 1.6.7  2026/08/19
*! Shared path guard for datamap package file options
*! Author: Timothy P Copeland, Karolinska Institutet

program define _datamap_validate_path, nclass
    version 16.0
    local _orig_varabbrev = c(varabbrev)
    set varabbrev off
    capture noisily {
        syntax anything(name=path id="path"), OPTion(string)
        local path = strtrim(`"`macval(path)'"')
        local unwrap_compound = 1
        while `unwrap_compound' {
            local unwrap_compound = 0
            local nchar = length(`"`macval(path)'"')
            if `nchar' >= 4 & substr(`"`macval(path)'"', 1, 1) == char(96) & ///
               substr(`"`macval(path)'"', 2, 1) == char(34) & ///
               substr(`"`macval(path)'"', `nchar' - 1, 1) == char(34) & ///
               substr(`"`macval(path)'"', `nchar', 1) == char(39) {
                local path = substr(`"`macval(path)'"', 3, `nchar' - 4)
                local unwrap_compound = 1
            }
        }
        local bad = 0
        foreach c in ";" "&" "|" ">" "<" "$" {
            if strpos(`"`macval(path)'"', "`c'") local bad = 1
        }
        if strpos(`"`macval(path)'"', char(96)) | ///
           strpos(`"`macval(path)'"', char(34)) local bad = 1
        if `bad' {
            display as error "illegal characters in `option' path"
            exit 198
        }
    }
    local rc = _rc
    set varabbrev `_orig_varabbrev'
    if `rc' exit `rc'
end
