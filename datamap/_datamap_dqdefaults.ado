*! _datamap_dqdefaults Version 1.8.1  2026/09/30
*! Parse the dataqa session defaults held in the global DATAMAP_DQ
*! Author: Timothy P Copeland, Karolinska Institutet
*! Program class: rclass

// DATAMAP_DQ holds the option string written by -dataqa set-.  Every
// consumer (datacheck, datamvp, dataqa) reads it through this parser, so the
// grammar is defined once.  Precedence is applied by the caller: an explicit
// option beats a session default, which beats a config() file.
program define _datamap_dqdefaults, rclass
    version 16.0
    local _orig_varabbrev = c(varabbrev)
    set varabbrev off
    local maskrare ""
    local mincell = -1
    local ledger ""
    local run ""
    local bandwarn ""
    local signature ""
    capture noisily {
        local spec `"$DATAMAP_DQ"'
        local spec = strtrim(`"`macval(spec)'"')
        if `"`macval(spec)'"' != "" {
            local 0 `", `macval(spec)'"'
            capture syntax [, MASKrare MINcell(integer -1) LEDger(string) ///
                RUN(string) BANDWARN SIGnature]
            if _rc {
                display as error "global DATAMAP_DQ is not a valid dataqa set option list; run dataqa set clear"
                exit 198
            }
            local ledger = subinstr(`"`ledger'"', char(34), "", .)
            local run = subinstr(`"`run'"', char(34), "", .)
        }
    }
    local rc = _rc
    set varabbrev `_orig_varabbrev'
    if `rc' exit `rc'
    return scalar maskrare = ("`maskrare'" != "")
    return scalar mincell = `mincell'
    return scalar bandwarn = ("`bandwarn'" != "")
    return scalar signature = ("`signature'" != "")
    return local ledger `"`ledger'"'
    return local run `"`run'"'
    return scalar active = (`"`macval(spec)'"' != "")
end
