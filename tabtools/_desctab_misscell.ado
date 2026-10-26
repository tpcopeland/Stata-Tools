*! _desctab_misscell Version 1.0.0  2026/10/20
*! Text of one desctab missingsummary cell in the level rows' cell format
*! Author: Timothy P Copeland, Karolinska Institutet
*! Program class: rclass

/*
count(#) missing observations over denom(#), the group N. The cell follows
the format of the level rows above it:
    default      n (pct)
    pctfirst(1)  pct (n)          (percent_n)
    pctonly(1)   pct              (percent; wins over percent_n, as in the
                                   level rows)
    slash(1)     n is printed as n/denom
    nhidden(1)   the count alone: a withheld N header would be released by
                 any percentage or n/N beside it
r(text) is the cell.
*/

capture program drop _desctab_misscell
program define _desctab_misscell, rclass
    version 17.0
    local _orig_varabbrev = c(varabbrev)
    set varabbrev off
    capture noisily {
        syntax , COUNT(real) DENOM(real) NFORMAT(string) PERCFORMAT(string) ///
            [PERCSIGN(string) PCTONLY(integer 0) PCTFIRST(integer 0) ///
            SLASH(integer 0) NHIDDEN(integer 0)]
        local _n = ustrregexra(string(`count', "`nformat'"), "-(?=[0.,]+\z)", "")
        if `nhidden' local _text `"`_n'"'
        else {
            _tabtools_fmt_pct, value(`count' / `denom' * 100) format(`percformat')
            local _pct `"`r(text)'`percsign'"'
            if `slash' local _n = "`_n'/" + ustrregexra(string(`denom', "`nformat'"), "-(?=[0.,]+\z)", "")
            if `pctonly' local _text `"`_pct'"'
            else if `pctfirst' local _text `"`_pct' (`_n')"'
            else local _text `"`_n' (`_pct')"'
        }
    }
    local rc = _rc
    set varabbrev `_orig_varabbrev'
    if `rc' exit `rc'
    return local text `"`_text'"'
end
