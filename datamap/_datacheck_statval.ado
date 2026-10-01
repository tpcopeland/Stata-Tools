*! _datacheck_statval Version 1.8.2  2026/10/01
*! One summary statistic of a variable over a condition, raw and masked
*! Author: Timothy P Copeland, Karolinska Institutet
*! Program class: rclass
*! ess: Kish effective sample size (sum w)^2 / sum w^2 (Kish 1965, Survey Sampling)

// Syntax: _datacheck_statval statistic var [den], cond(exp) [mask(#) fmt(%fmt)]
//
// Statistics: mean sd p1 p5 p10 p25 p50 p75 p90 p95 p99 (summarize, detail
// definitions), sum, n (nonmissing count), distinct (distinct nonmissing
// values), pmiss (share missing over all rows in cond), ess (Kish effective
// sample size of weight var), ratio (sum var / sum den over rows where both
// are nonmissing).
//
// Returns r(value) (raw), r(s) (display text under mask()), r(shown) (0
// when the display was masked), r(n) (rows contributing; for pmiss the rows
// in scope), r(nmiss) (pmiss only), r(iscount) (1 for n, distinct, and an
// integer sum), and r(defined) (0 when the statistic has no value: mean,
// sd, percentiles, ess, and ratio over no usable rows, pmiss over no rows).
//
// Masking: order statistics and the mean follow _datacheck_qshow (at least
// mask() observations at or below and at or above the value; sd needs
// mask() observations).  Counts 1..mask()-1 print as <m, and a count whose
// complement in the rows in scope, or in the nonmissing rows, is
// 1..mask()-1 as "all but <m".  pmiss
// prints "." when fewer than mask() values are missing or nonmissing.  ess and ratio print
// [suppressed] when fewer than mask() rows contribute.
program define _datacheck_statval, rclass
    version 16.0
    local _orig_varabbrev = c(varabbrev)
    set varabbrev off
    capture noisily {
        syntax anything(name=spec), COND(string) [MASK(integer 0) FMT(string)]
        gettoken st spec : spec
        gettoken v spec : spec
        gettoken den spec : spec
        if "`fmt'" == "" local fmt "%14.0g"
        tempname val
        scalar `val' = .
        local n = 0
        local nmiss = .
        local iscount = 0
        local defined = 1
        local shown = 1
        local s ""
        local isorder = inlist("`st'", "p1", "p5", "p10", "p25", "p50") | ///
            inlist("`st'", "p75", "p90", "p95", "p99")
        if "`st'" == "mean" | "`st'" == "sd" | `isorder' {
            if `isorder' quietly summarize `v' if (`cond'), detail
            else quietly summarize `v' if (`cond')
            local n = r(N)
            if `n' == 0 local defined = 0
            else if "`st'" == "mean" scalar `val' = r(mean)
            else if "`st'" == "sd" scalar `val' = r(sd)
            else scalar `val' = r(`st')
            if `defined' & !missing(scalar(`val')) {
                _datacheck_qshow `v', value(`val') mask(`mask') cond(`"`cond'"') ///
                    stat(`st') fmt(`fmt')
                local s `"`r(s)'"'
                local shown = r(shown)
            }
            else local s "."
        }
        else if "`st'" == "sum" {
            quietly summarize `v' if (`cond'), meanonly
            local n = r(N)
            scalar `val' = cond(r(N) > 0, r(sum), 0)
            local iscount = (scalar(`val') == floor(scalar(`val')))
        }
        else if "`st'" == "n" {
            quietly count if (`cond') & !missing(`v')
            local n = r(N)
            scalar `val' = r(N)
            local iscount = 1
        }
        else if "`st'" == "distinct" {
            tempvar tg
            quietly egen byte `tg' = tag(`v') if (`cond') & !missing(`v')
            quietly count if `tg' == 1
            scalar `val' = r(N)
            quietly count if (`cond') & !missing(`v')
            local n = r(N)
            local iscount = 1
        }
        else if "`st'" == "pmiss" {
            quietly count if (`cond')
            local n = r(N)
            quietly count if (`cond') & missing(`v')
            local nmiss = r(N)
            if `n' == 0 local defined = 0
            else scalar `val' = `nmiss' / `n'
        }
        else if "`st'" == "ess" {
            tempvar w2
            quietly generate double `w2' = `v'^2 if (`cond') & !missing(`v')
            quietly summarize `v' if (`cond') & !missing(`v'), meanonly
            local n = r(N)
            tempname s1
            scalar `s1' = r(sum)
            quietly summarize `w2', meanonly
            if `n' == 0 | r(sum) == 0 local defined = 0
            else scalar `val' = scalar(`s1')^2 / r(sum)
        }
        else if "`st'" == "ratio" {
            quietly summarize `v' if (`cond') & !missing(`v') & !missing(`den'), meanonly
            local n = r(N)
            tempname s1
            scalar `s1' = r(sum)
            quietly summarize `den' if (`cond') & !missing(`v') & !missing(`den'), meanonly
            if `n' == 0 | r(sum) == 0 local defined = 0
            else scalar `val' = scalar(`s1') / r(sum)
        }
        else {
            display as error "_datacheck_statval: unknown statistic `st'"
            exit 198
        }

        // display text for the statistics not handled by _datacheck_qshow
        if !inlist("`st'", "mean", "sd") & !`isorder' {
            // A count whose complement is a small cell gives that cell
            // back.  Complements are taken against the rows in scope (the
            // printed N) and against the nonmissing count (what stat(n)
            // prints): sum 990 beside n 992 reveals 2 zeros.
            quietly count if (`cond')
            local nrow = r(N)
            quietly count if (`cond') & !missing(`v')
            local nnm = r(N)
            if !`defined' | missing(scalar(`val')) local s "."
            else if `iscount' {
                if `mask' > 0 & scalar(`val') >= 1 & scalar(`val') < `mask' {
                    local s "<`mask'"
                    local shown = 0
                }
                else if `mask' > 0 & scalar(`val') >= 1 & ///
                    ((`nrow' - scalar(`val') >= 1 & `nrow' - scalar(`val') < `mask') | ///
                    (`nnm' - scalar(`val') >= 1 & `nnm' - scalar(`val') < `mask')) {
                    local s "all but <`mask'"
                    local shown = 0
                }
                else local s = strtrim(string(scalar(`val'), "%20.0f"))
            }
            else if "`st'" == "pmiss" {
                if `mask' > 0 & ((`nmiss' >= 1 & `nmiss' < `mask') | ///
                    (`n' - `nmiss' >= 1 & `n' - `nmiss' < `mask')) {
                    local s "."
                    local shown = 0
                }
                else local s = strtrim(string(scalar(`val'), "`fmt'"))
            }
            else if inlist("`st'", "ess", "ratio") {
                if `mask' > 0 & `n' < `mask' {
                    local s "[suppressed]"
                    local shown = 0
                }
                else local s = strtrim(string(scalar(`val'), "`fmt'"))
            }
            else local s = strtrim(string(scalar(`val'), "`fmt'"))
        }
    }
    local rc = _rc
    set varabbrev `_orig_varabbrev'
    if `rc' exit `rc'
    return scalar value = scalar(`val')
    return scalar n = `n'
    return scalar nmiss = `nmiss'
    return scalar iscount = `iscount'
    return scalar defined = `defined'
    return scalar shown = `shown'
    return local s `"`s'"'
end
