*! _tabtools_st_timescale Version 2.6.2  2026/10/10
*! the calendar unit of stset analysis time, when the data say it
*! Author: Timothy P Copeland, Karolinska Institutet
*! Program class: nclass

/*
stset keeps the time variable (_dta[st_bt]) and its scale (_dta[st_bs]).
When that variable carries a date format and no scale() was given, analysis
time is in days (%td, %d) or milliseconds (%tc, %tC). Commands that label
person-time as years by default use this to say so, rather than print a
person-years header over person-days.

Usage: _tabtools_st_timescale
Returns in the caller: _st_unit ("days", "milliseconds", or "" when the data
do not say), and _st_timevar (the stset time variable).
*/

capture program drop _tabtools_st_timescale
program define _tabtools_st_timescale, nclass
    version 17.0
    local _orig_varabbrev = c(varabbrev)
    set varabbrev off
    c_local _st_unit ""
    c_local _st_timevar ""
    capture noisily {
        local _bt : char _dta[st_bt]
        local _bs : char _dta[st_bs]
        if "`_bs'" == "" local _bs 1
        capture confirm numeric variable `_bt', exact
        if !_rc & real("`_bs'") == 1 {
            local _fmt : format `_bt'
            local _fmt = subinstr("`_fmt'", "-", "", 1)
            local _unit ""
            if regexm("`_fmt'", "^%(td|d)") local _unit "days"
            else if regexm("`_fmt'", "^%t[cC]") local _unit "milliseconds"
            c_local _st_unit "`_unit'"
            c_local _st_timevar "`_bt'"
        }
    }
    local rc = _rc
    set varabbrev `_orig_varabbrev'
    if `rc' exit `rc'
end
