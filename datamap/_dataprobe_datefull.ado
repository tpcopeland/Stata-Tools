*! _dataprobe_datefull Version 1.10.6  2026/10/21
*! A date-formatted value for a gate failure message, at full precision
*! when its date does not show it exactly
*! Author: Timothy P Copeland, Karolinska Institutet
*! Program class: rclass

// _dataprobe_datefull value fmt
//
// Without the mask a failure message prints a date-formatted value in its
// format.  When that text stands for more than one value, the value
// printed alone could read as the bound it failed: a mean of 08feb1965
// plus 12 hours against an upper bound of 08feb1965 prints 08feb1965.
// The value then prints at full precision with the date beside it,
// 1865.5 (08feb1965); otherwise the date alone.  The text is exact when
// the value is the first one that prints as it: one storage step below
// (a millisecond for %tc and %tC, 1e-7 of a unit for any other date)
// prints differently.  The number is %21.0g for %tc or %tC (milliseconds
// since 1960 need 13 digits) and %14.0g otherwise, as stat() prints a
// number.  Under maskrare callers keep their month-precision text: an
// exact value would be a person's.
program define _dataprobe_datefull, rclass
    version 16.0
    args x fmt
    local f = subinstr("`fmt'", "%-", "%", 1)
    local istc = (strpos("`f'", "%tc") | strpos("`f'", "%tC")) > 0
    local nf = cond(`istc', "%21.0g", "%14.0g")
    local step = cond(`istc', 1, 1e-7)
    local d = strtrim(string(`x', "`f'"))
    local dm = strtrim(string(`x' - `step', "`f'"))
    if `"`d'"' == `"`dm'"' {
        local v = strtrim(string(`x', "`nf'"))
        return local s "`v' (`d')"
        return scalar exact = 0
    }
    else {
        return local s "`d'"
        return scalar exact = 1
    }
end
