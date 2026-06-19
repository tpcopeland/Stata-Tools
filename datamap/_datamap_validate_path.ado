*! _datamap_validate_path Version 1.5.0  2026/06/19
*! Shared path guard for datamap package file options
*! Author: Timothy P Copeland, Karolinska Institutet

program define _datamap_validate_path, nclass
    version 16.0
    syntax anything(name=path id="path"), OPTion(string)
    local path = strtrim(`"`macval(path)'"')
    if substr(`"`path'"', 1, 1) == char(34) & ///
       substr(`"`path'"', length(`"`path'"'), 1) == char(34) {
        local path = substr(`"`path'"', 2, length(`"`path'"') - 2)
    }
    local path = subinstr(`"`macval(path)'"', char(34), "", .)
    local bad = 0
    foreach c in ";" "&" "|" ">" "<" "$" {
        if strpos(`"`macval(path)'"', "`c'") local bad = 1
    }
    if strpos(`"`macval(path)'"', char(96)) local bad = 1
    if `bad' {
        display as error "illegal characters in `option' path"
        exit 198
    }
end
