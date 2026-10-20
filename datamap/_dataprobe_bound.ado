*! _dataprobe_bound Version 1.10.4  2026/10/21
*! Parse a range bound (number, date literal, or date string) for a variable
*! Author: Timothy P Copeland, Karolinska Institutet
*! Program class: rclass

program define _dataprobe_bound, rclass
    version 16.0
    local _orig_varabbrev = c(varabbrev)
    set varabbrev off
    capture noisily {
        gettoken v raw : 0
        local raw = trim(`"`raw'"')
        if `"`raw'"' == "" {
            display as error "empty range bound"
            exit 198
        }
        // an expression is evaluated in an empty frame: with the data
        // visible, a bound such as ub*1 evaluated as the first observation
        tempname val _ef
        local _bare `raw'
        local _bare = subinstr(`"`_bare'"', char(34), "", .)
        local vfmt : format `v'
        local vfmt = lower(subinstr("`vfmt'", "%-", "%", 1))
        local isdate = (substr("`vfmt'", 1, 2) == "%t" | substr("`vfmt'", 1, 2) == "%d")
        // A bare variable name would evaluate as its first observation.
        capture confirm variable `_bare', exact
        if !_rc & `: word count `_bare'' == 1 {
            display as error `"range bound `_bare' for `v' names a variable; give a number or a date"'
            exit 198
        }
        // A plain number is taken as written.  For a date variable a date
        // string is parsed before any expression evaluation, because
        // 2020-01-01 and 2020/01/01 are also valid arithmetic (2018, 2020).
        // "+ 0" forces a numeric evaluation: a bare date string such as
        // 01jan2020 would otherwise become a string scalar.
        local _rc_eval = 1
        // a bound written . is missing for every variable: it read as
        // missing for a number and was a parse error for a date, so stat()
        // took an upper bound of . as open for one and refused it for the
        // other.  Each caller decides what a missing bound means.
        if `"`_bare'"' == "." {
            scalar `val' = .
            local _rc_eval = 0
        }
        else if real(`"`_bare'"') < . {
            scalar `val' = real(`"`_bare'"')
            local _rc_eval = 0
        }
        else if !`isdate' | strpos(`"`_bare'"', "(") {
            _dataprobe_bound_eval `val' `_ef' `"`_bare'"'
            local _rc_eval = r(rc)
        }
        if `_rc_eval' {
            local clean `"`_bare'"'
            if strpos("`vfmt'", "%tc") | strpos("`vfmt'", "%tC") {
                scalar `val' = clock(`"`clean'"', "DMYhms")
                if missing(`val') scalar `val' = clock(`"`clean'"', "DMY")
                if missing(`val') scalar `val' = clock(`"`clean'"', "YMDhms")
                if missing(`val') scalar `val' = clock(`"`clean'"', "YMD")
            }
            else if strpos("`vfmt'", "%tm") {
                scalar `val' = monthly(`"`clean'"', "YM")
            }
            else if strpos("`vfmt'", "%tq") {
                scalar `val' = quarterly(`"`clean'"', "YQ")
            }
            else if strpos("`vfmt'", "%tw") {
                scalar `val' = weekly(`"`clean'"', "YW")
            }
            else if strpos("`vfmt'", "%th") {
                scalar `val' = halfyearly(`"`clean'"', "YH")
            }
            else if strpos("`vfmt'", "%ty") {
                scalar `val' = yearly(`"`clean'"', "Y")
            }
            else {
                scalar `val' = daily(`"`clean'"', "DMY")
                if missing(`val') scalar `val' = daily(`"`clean'"', "YMD")
                if missing(`val') scalar `val' = daily(`"`clean'"', "MDY")
            }
            // not a date string: an expression such as 21915 + 1
            if missing(`val') & `isdate' & !strpos(`"`_bare'"', "(") {
                _dataprobe_bound_eval `val' `_ef' `"`_bare'"'
                if r(rc) scalar `val' = .
            }
            if missing(`val') {
                display as error `"could not parse range bound `_bare' for `v'"'
                display as error "a bound is a number, a date, or an expression of constants; it cannot refer to a variable"
                exit 198
            }
        }
    }
    local rc = _rc
    set varabbrev `_orig_varabbrev'
    if `rc' exit `rc'
    // the scalar, not a macro copy: a decimal round trip keeps only 16
    // digits and can move a bound off a value the data holds
    return scalar value = scalar(`val')
end

// Evaluate a bound expression with no data visible, so a variable name in it
// is an error rather than its first observation.  Returns r(rc).
capture program drop _dataprobe_bound_eval
local _drop_rc = _rc
if !inlist(`_drop_rc', 0, 111) exit `_drop_rc'
program define _dataprobe_bound_eval, rclass
    version 16.0
    args val fr expr
    frame create `fr'
    frame `fr': capture scalar `val' = (`expr') + 0
    local rc = _rc
    capture frame drop `fr'
    return scalar rc = `rc'
end
