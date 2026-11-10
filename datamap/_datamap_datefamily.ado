*! _datamap_datefamily Version 2.0.0  2026/11/10
*! The date family of a display format: "%td daily", "%tc datetime", ...
*! Author: Timothy P Copeland, Karolinska Institutet
*! Program class: rclass

// _datamap_datefamily, format(fmt)
//   r(family)  the family code and its word, "" when fmt is not a date format:
//              %td daily (also the old %d), %tc datetime, %tC datetime (leap
//              seconds), %tw weekly, %tm monthly, %tq quarterly,
//              %th half-yearly, %ty yearly, %tb business daily, %tg generic.
//              A justification flag (%-td) is ignored.
//   r(unit)    what one unit of the format counts: days, milliseconds,
//              weeks, months, quarters, half-years, years, business days;
//              "" for %tg and for a non-date format
// The Type column of datamap's variable table (U4, 2026-11-10) and the time
// unit of a declared tsset/xtset (F2) read it, so both name a family alike.
program define _datamap_datefamily, rclass
    version 16.0
    local _orig_varabbrev = c(varabbrev)
    set varabbrev off
    capture noisily {
        syntax , [FORMAT(string)]
        local f = subinstr(`"`format'"', "%-", "%", 1)
        local fam ""
        local unit ""
        if substr(`"`f'"', 1, 3) == "%td" | (substr(`"`f'"', 1, 2) == "%d") {
            local fam "%td daily"
            local unit "days"
        }
        else if substr(`"`f'"', 1, 3) == "%tc" {
            local fam "%tc datetime"
            local unit "milliseconds"
        }
        else if substr(`"`f'"', 1, 3) == "%tC" {
            local fam "%tC datetime (leap seconds)"
            local unit "milliseconds"
        }
        else if substr(`"`f'"', 1, 3) == "%tw" {
            local fam "%tw weekly"
            local unit "weeks"
        }
        else if substr(`"`f'"', 1, 3) == "%tm" {
            local fam "%tm monthly"
            local unit "months"
        }
        else if substr(`"`f'"', 1, 3) == "%tq" {
            local fam "%tq quarterly"
            local unit "quarters"
        }
        else if substr(`"`f'"', 1, 3) == "%th" {
            local fam "%th half-yearly"
            local unit "half-years"
        }
        else if substr(`"`f'"', 1, 3) == "%ty" {
            local fam "%ty yearly"
            local unit "years"
        }
        else if substr(`"`f'"', 1, 3) == "%tb" {
            local fam "%tb business daily"
            local unit "business days"
        }
        else if substr(`"`f'"', 1, 3) == "%tg" {
            local fam "%tg generic"
        }
        else if substr(`"`f'"', 1, 2) == "%t" {
            // a %t format Stata may add later: its code, no word
            local fam = substr(`"`f'"', 1, 3)
        }
        return local family `"`fam'"'
        return local unit `"`unit'"'
    }
    local rc = _rc
    set varabbrev `_orig_varabbrev'
    if `rc' exit `rc'
end
