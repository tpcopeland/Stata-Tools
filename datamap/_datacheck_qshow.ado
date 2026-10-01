*! _datacheck_qshow Version 1.8.2  2026/10/01
*! Format one summary statistic for display, suppressed under a mask
*! Author: Timothy P Copeland, Karolinska Institutet
*! Program class: rclass

program define _datacheck_qshow, rclass
    // Format one summary statistic of `varlist' for display.  With mask(#)
    // > 0 the value is suppressed unless at least # nonmissing observations
    // (within cond()) lie at or below it and at least # at or above it; sd
    // needs # nonmissing observations.  Dates print at month precision
    // under masking and in their own format otherwise.
    version 16.0
    local _orig_varabbrev = c(varabbrev)
    set varabbrev off
    capture noisily {
        syntax varname, VALue(name) MASK(integer) [COND(string) STAT(string) FMT(string)]
        if `"`cond'"' == "" local cond "1"
        if "`fmt'" == "" local fmt "%10.4g"
        local shown = 1
        if `mask' > 0 & !missing(scalar(`value')) {
            if "`stat'" == "sd" {
                quietly count if (`cond') & !missing(`varlist')
                if r(N) < `mask' local shown = 0
            }
            else {
                quietly count if (`cond') & !missing(`varlist') & `varlist' <= scalar(`value')
                if r(N) < `mask' local shown = 0
                quietly count if (`cond') & !missing(`varlist') & `varlist' >= scalar(`value')
                if r(N) < `mask' local shown = 0
            }
        }
        local vf : format `varlist'
        local vf = subinstr("`vf'", "%-", "%", 1)
        local isdate = (substr("`vf'", 1, 2) == "%t" | substr("`vf'", 1, 2) == "%d")
        if !`shown' local s "[suppressed]"
        else if missing(scalar(`value')) local s "."
        else if `isdate' & "`stat'" != "sd" {
            if `mask' > 0 & (strpos("`vf'", "%td") | substr("`vf'", 1, 2) == "%d") {
                local s = string(scalar(`value'), "%tdCCYY-NN")
            }
            else if `mask' > 0 & (strpos("`vf'", "%tc") | strpos("`vf'", "%tC")) {
                local s = string(dofc(scalar(`value')), "%tdCCYY-NN")
            }
            else local s = strtrim(string(scalar(`value'), "`vf'"))
        }
        else local s = strtrim(string(scalar(`value'), "`fmt'"))
    }
    local rc = _rc
    set varabbrev `_orig_varabbrev'
    if `rc' exit `rc'
    return scalar shown = `shown'
    return local s `"`s'"'
end
