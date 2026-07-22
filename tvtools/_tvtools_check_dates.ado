*! _tvtools_check_dates Version 1.8.0  2026/07/22
*! Validate daily-date variables and interval bounds against the suite contract
*! Author: Timothy P Copeland, Karolinska Institutet
*! Part of the tvtools package

/*
Enforces the package-wide malformed-input contract documented at
help tvtools##contracts: required dates must be numeric, must not carry
%tc/%tC datetime formats, must be finite, nonmissing, whole daily values,
and interval bounds must satisfy start <= stop.

The check runs before any calculation and never mutates the caller's data.
It reports exact counts by reason. Exit codes follow the codes these
commands already documented, so a reason stays distinguishable:

    109  a date variable is not numeric
    120  a date variable carries a %tc/%tC datetime format
    416  one or more required dates are missing
    498  a present value is not a whole day, or start > stop

Syntax:
    _tvtools_check_dates [if] [in], CMD(name) DATEs(varlist numeric) ///
        [ STARTvar(varname numeric) STOPvar(varname numeric) VERBose ]

    cmd(name)          calling command name, used in the error text
    dates(varlist)     every required daily-date variable to validate
    startvar()/stopvar() interval bounds whose order is additionally checked
    verbose            list up to five offending records

Returns (when every row is valid):
    r(n_checked)        rows validated
*/

program define _tvtools_check_dates, rclass
    version 16.0
    local orig_varabbrev = c(varabbrev)
    set varabbrev off
    local _preserved = 0

    capture noisily {
        syntax [if] [in], CMD(name) DATEs(varlist numeric) ///
            [ STARTvar(varname numeric) STOPvar(varname numeric) VERBose ]

        marksample touse, novarlist

        * --- Type and format gates run before any row-level arithmetic ----
        foreach v of local dates {
            capture confirm numeric variable `v'
            if _rc {
                display as error "Variable '`v'' must be numeric (daily date)"
                exit 109
            }
            local fmt : format `v'
            if substr("`fmt'", 1, 3) == "%tc" | substr("`fmt'", 1, 3) == "%tC" {
                display as error "Variable '`v'' has datetime format (`fmt'); `cmd' requires daily dates"
                display as error "Convert with: generate daily_`v' = dofc(`v')"
                exit 120
            }
        }

        * --- Missing values keep their own historical code (416) ----------
        tempvar bad_miss bad_frac bad_order bad_any
        quietly generate byte `bad_miss' = 0
        foreach v of local dates {
            quietly replace `bad_miss' = 1 if `touse' & missing(`v')
        }
        quietly count if `bad_miss' & `touse'
        if r(N) > 0 {
            display as error r(N) " observation(s) have missing dates in `dates'"
            exit 416
        }

        * --- Present-but-malformed values ---------------------------------
        * A nonmissing value that differs from its own floor is a fractional
        * or sub-daily quantity; the closed [start, stop] day count is then
        * undefined, so it is rejected rather than silently truncated.
        quietly generate byte `bad_frac' = 0
        foreach v of local dates {
            quietly replace `bad_frac' = 1 if `touse' & `v' != floor(`v')
        }

        quietly generate byte `bad_order' = 0
        if "`startvar'" != "" & "`stopvar'" != "" {
            quietly replace `bad_order' = 1 if `touse' & `startvar' > `stopvar'
        }

        quietly generate byte `bad_any' = `bad_frac' | `bad_order'

        quietly count if `bad_frac' & `touse'
        local n_invalid_dates = r(N)
        quietly count if `bad_order' & `touse'
        local n_invalid_order = r(N)
        quietly count if `bad_any' & `touse'
        local n_invalid = r(N)

        if `n_invalid' > 0 {
            if "`verbose'" != "" {
                display as text "First invalid records:"
                preserve
                local _preserved = 1
                quietly keep if `bad_any' & `touse'
                list `dates' in 1/`=min(5, _N)', noobs
                restore
                local _preserved = 0
            }
            else {
                display as text "  (specify verbose to list affected records)"
            }
            display as error "Malformed `cmd' input: `n_invalid' row(s)"
            display as error "  non-whole daily dates: `n_invalid_dates'; reversed bounds: `n_invalid_order'"
            display as error "Required dates must be finite, nonmissing, whole daily values with start <= stop."
            exit 498
        }

        quietly count if `touse'
        return scalar n_checked = r(N)
    }
    local rc = _rc
    if `_preserved' capture restore
    set varabbrev `orig_varabbrev'
    if `rc' exit `rc'
end
