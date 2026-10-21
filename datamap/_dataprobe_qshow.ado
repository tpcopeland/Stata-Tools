*! _dataprobe_qshow Version 1.10.5  2026/10/21
*! Format one summary statistic for display, suppressed under a mask
*! Author: Timothy P Copeland, Karolinska Institutet
*! Program class: rclass

program define _dataprobe_qshow, rclass
    // Format one summary statistic of `varlist' for display.  With mask(#)
    // > 0 the value is suppressed unless at least # nonmissing observations
    // (within cond()) lie at or below it and at least # at or above it; sd
    // needs # nonmissing observations and, for a variable with two or three values,
    // # observations of each.  Dates print at month precision
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
                local _n = r(N)
                if `_n' < `mask' local shown = 0
                // a variable with two values: sd and N give back the share,
                // so the count of each value (a 0/1 flag held by 3 rows
                // printed sd .1714 beside N 100) must reach the mask
                else {
                    tempname _lo _hi
                    quietly summarize `varlist' if (`cond'), meanonly
                    scalar `_lo' = r(min)
                    scalar `_hi' = r(max)
                    quietly count if (`cond') & `varlist' == scalar(`_lo')
                    local _nlo = r(N)
                    quietly count if (`cond') & `varlist' == scalar(`_hi')
                    local _nhi = r(N)
                    if scalar(`_lo') < scalar(`_hi') & `_nlo' + `_nhi' == `_n' & ///
                        (`_nlo' < `mask' | `_nhi' < `mask') local shown = 0
                    // three values: N, the mean and the sd are three
                    // equations in the three counts (0/1/2 with 2 rows of
                    // 2: mean .52, sd .5409 beside N 100 give 48 and 2),
                    // so each value's rows must reach the mask as well
                    else if scalar(`_lo') < scalar(`_hi') {
                        quietly summarize `varlist' if (`cond') & `varlist' > scalar(`_lo') & ///
                            `varlist' < scalar(`_hi'), meanonly
                        if r(N) > 0 & r(min) == r(max) & `_nlo' + `_nhi' + r(N) == `_n' & ///
                            (`_nlo' < `mask' | `_nhi' < `mask' | r(N) < `mask') local shown = 0
                    }
                }
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
