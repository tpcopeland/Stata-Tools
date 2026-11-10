*! _datamap_idnames Version 2.0.0  2026/11/10
*! The likely-identifier name rule shared by datamap, dataprobe and datamvp
*! Author: Timothy P Copeland, Karolinska Institutet
*! Program class: rclass

// One rule, read by every command (2.0.0, U2): a variable is a likely
// identifier when its name, in lower case, matches r(pattern).  The
// classifier's r(suggested_exclude) and its autoexclude option (datamap's
// exclude(auto)) read the pattern here, and safe (dataprobe, datamvp) reads
// r(names) for the variables it is given.  The rule reads names only: an
// identifier under another name (pnr, ssn) is not matched, and a name
// ending in "id" (paid, valid) is (over-exclusion is the safe side).
//
//   _datamap_idnames [varlist]
//       r(pattern)  the regular expression
//       r(names)    the variables of varlist it matches, in varlist order
program define _datamap_idnames, rclass
    version 16.0
    local _orig_varabbrev = c(varabbrev)
    set varabbrev off
    local names ""
    capture noisily {
        syntax [varlist(default=none)]
        local pat "id$|_id$|^id_|patient|subject|person|lopnr|identifier"
        foreach v of local varlist {
            if regexm(lower("`v'"), "`pat'") local names "`names' `v'"
        }
        local names : list retokenize names
    }
    local rc = _rc
    set varabbrev `_orig_varabbrev'
    if `rc' exit `rc'
    return local names "`names'"
    return local pattern "`pat'"
end
