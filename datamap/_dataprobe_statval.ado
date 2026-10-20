*! _dataprobe_statval Version 1.10.4  2026/10/21
*! One summary statistic of a variable over a condition, raw and masked
*! Author: Timothy P Copeland, Karolinska Institutet
*! Program class: rclass
*! ess: Kish effective sample size (sum w)^2 / sum w^2 (Kish 1965, Survey Sampling)

// Syntax: _dataprobe_statval statistic var [den], cond(exp) [mask(#) fmt(%fmt)]
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
// Masking: order statistics and the mean follow _dataprobe_qshow (at least
// mask() observations at or below and at or above the value; sd needs
// mask() observations).  Counts 1..mask()-1 print as <m, and a count whose
// complement in the rows in scope, or in the nonmissing rows, is
// 1..mask()-1 as "all but <m".  pmiss
// prints "." when fewer than mask() values are missing or nonmissing.  A
// sum is a value of its contributing rows, not only a count: it prints as
// [suppressed] when the nonmissing rows, the nonzero rows, or, for a
// variable with two values, the rows of either value number 1..mask()-1
// (the sum of a 0.5 flag on 3 rows is 1.5; one row's sum is its value),
// after the count rules above for an integer sum.  hide (a by() group whose
// size is withheld) prints a count of mask() or more as [suppressed].  ess and ratio print
// [suppressed] when fewer than mask() rows contribute; ess also when the
// zero or the nonzero weights number 1..mask()-1, and ratio also when fewer
// than mask() rows of v/den lie at or below it or at or above it.
program define _dataprobe_statval, rclass
    version 16.0
    local _orig_varabbrev = c(varabbrev)
    set varabbrev off
    capture noisily {
        syntax anything(name=spec), COND(string) [MASK(integer 0) FMT(string) HIDE]
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
                _dataprobe_qshow `v', value(`val') mask(`mask') cond(`"`cond'"') ///
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
            display as error "_dataprobe_statval: unknown statistic `st'"
            exit 198
        }

        // display text for the statistics not handled by _dataprobe_qshow
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
                else if `mask' > 0 & "`hide'" != "" & scalar(`val') >= `mask' {
                    // a count in a by() group whose size is withheld bounds
                    // that size (see _dataprobe_mcount)
                    local s "[suppressed]"
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
                // ess of a weight that is 0 for some rows: the ess of a 0/1
                // weight is the count of ones, so the zero and nonzero
                // weights are counts under the count rule
                else if `mask' > 0 & "`st'" == "ess" {
                    quietly count if (`cond') & !missing(`v') & `v' != 0
                    local _nz = r(N)
                    if (`_nz' >= 1 & `_nz' < `mask') | ///
                        (`n' - `_nz' >= 1 & `n' - `_nz' < `mask') {
                        local s "[suppressed]"
                        local shown = 0
                    }
                    else local s = strtrim(string(scalar(`val'), "`fmt'"))
                }
                // ratio sum(v)/sum(den) is the den-weighted mean of v/den
                // (the mean of v when den is 1): it is shown under the mean
                // rule, at least mask() rows of v/den at or below it and at
                // or above it
                else if `mask' > 0 & "`st'" == "ratio" {
                    quietly count if (`cond') & !missing(`v') & !missing(`den') & ///
                        `den' != 0 & `v' / `den' <= scalar(`val')
                    local _nle = r(N)
                    quietly count if (`cond') & !missing(`v') & !missing(`den') & ///
                        `den' != 0 & `v' / `den' >= scalar(`val')
                    if `_nle' < `mask' | r(N) < `mask' {
                        local s "[suppressed]"
                        local shown = 0
                    }
                    else local s = strtrim(string(scalar(`val'), "`fmt'"))
                }
                else local s = strtrim(string(scalar(`val'), "`fmt'"))
            }
            else local s = strtrim(string(scalar(`val'), "`fmt'"))
            // A sum is a value of its rows: shown only when the nonmissing
            // rows, the nonzero rows, and (two values) each value's rows
            // number 0 or at least mask()
            if `mask' > 0 & "`st'" == "sum" & `shown' & `defined' & !missing(scalar(`val')) {
                _dataprobe_statval_sumok `v', cond(`"`cond'"') mask(`mask')
                if !r(ok) {
                    local s "[suppressed]"
                    local shown = 0
                }
            }
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

// 1 when a sum of v over cond may be shown under mask m: the nonmissing
// rows, the nonzero rows, and, when v takes two values, the rows of each
// value number 0 or at least m.  One rule for stat(sum) here and for the
// groupstat(sum) cells, which apply it to the same counts per group.
capture program drop _dataprobe_statval_sumok
program define _dataprobe_statval_sumok, rclass
    version 16.0
    syntax varname, COND(string) MASK(integer)
    local v "`varlist'"
    local ok = 1
    quietly count if (`cond') & !missing(`v')
    local nn = r(N)
    quietly count if (`cond') & !missing(`v') & `v' != 0
    local nz = r(N)
    if (`nn' >= 1 & `nn' < `mask') | (`nz' >= 1 & `nz' < `mask') local ok = 0
    if `ok' & `nn' > 0 {
        quietly summarize `v' if (`cond'), meanonly
        tempname lo hi
        scalar `lo' = r(min)
        scalar `hi' = r(max)
        if scalar(`lo') < scalar(`hi') {
            quietly count if (`cond') & `v' == scalar(`lo')
            local nlo = r(N)
            quietly count if (`cond') & `v' == scalar(`hi')
            local nhi = r(N)
            if `nlo' + `nhi' == `nn' & (`nlo' < `mask' | `nhi' < `mask') local ok = 0
        }
    }
    return scalar ok = `ok'
end
