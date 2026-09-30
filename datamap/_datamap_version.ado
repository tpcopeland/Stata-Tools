*! _datamap_version Version 1.8.1  2026/09/30
*! Read a datamap command's version from its installed .ado header
*! Author: Timothy P Copeland, Karolinska Institutet
*! Program class: rclass

// The version is parsed from the "*! <cmd> Version X.Y.Z" header of the
// .ado file Stata would load, so r(version) can never drift from the code.
// atleast() compares it with a requested version, component by component.
program define _datamap_version, rclass
    version 16.0
    local _orig_varabbrev = c(varabbrev)
    set varabbrev off
    local _fh_open = 0
    tempname fh
    local ver "unknown"
    local ok = .
    local req ""
    capture noisily {
        syntax name(name=cmd) [, ATLeast(string)]
        capture findfile `cmd'.ado
        if !_rc {
            local fn `"`r(fn)'"'
            file open `fh' using `"`fn'"', read text
            local _fh_open = 1
            file read `fh' line
            local k = 0
            while r(eof) == 0 & `k' < 20 {
                if regexm(`"`macval(line)'"', "^\*! `cmd' Version ([0-9]+\.[0-9]+\.[0-9]+)") {
                    local ver = regexs(1)
                    continue, break
                }
                local ++k
                file read `fh' line
            }
            file close `fh'
            local _fh_open = 0
        }
        if `"`atleast'"' != "" {
            local req = strtrim(`"`atleast'"')
            if !regexm(`"`req'"', "^[0-9]+(\.[0-9]+)?(\.[0-9]+)?$") {
                display as error `"minversion() must be a version number such as 1.8.0; got `req'"'
                exit 198
            }
            local ok = 0
            if "`ver'" != "unknown" {
                local cmp = 0
                local va = subinstr("`ver'", ".", " ", .)
                local vb = subinstr("`req'", ".", " ", .)
                forvalues j = 1/3 {
                    local a : word `j' of `va'
                    local b : word `j' of `vb'
                    if "`a'" == "" local a 0
                    if "`b'" == "" local b 0
                    if `cmp' == 0 & `a' > `b' local cmp = 1
                    if `cmp' == 0 & `a' < `b' local cmp = -1
                }
                local ok = (`cmp' >= 0)
            }
        }
    }
    local rc = _rc
    if `_fh_open' capture file close `fh'
    set varabbrev `_orig_varabbrev'
    if `rc' exit `rc'
    return local version "`ver'"
    if "`req'" != "" {
        return scalar ok = `ok'
        return local required "`req'"
    }
end
