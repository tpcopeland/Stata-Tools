*! _pyattach_join Version 1.0.1  2026/08/30
*! Compute the regular pygrid bucket for event dates
*! Author: Timothy P Copeland, Karolinska Institutet
*! Program class: nclass

program define _pyattach_join
    version 16.0
    local _orig_varabbrev = c(varabbrev)
    set varabbrev off

    capture noisily {
        syntax , DATE(varname numeric) BUCKET(name) AXIS(string) ///
            WIDTH(real) UNIT(string) [ ORIGIN(varname numeric) ]

        confirm new variable `bucket'
        quietly generate double `bucket' = .
        if "`axis'" == "calendar" {
            if "`unit'" == "day" quietly replace `bucket' = floor(`date' / `width') * `width'
            else if "`unit'" == "month" quietly replace `bucket' = floor(mofd(`date') / `width') * `width'
            else quietly replace `bucket' = floor(year(`date') / `width') * `width'
        }
        else if "`axis'" == "anniversary" {
            if "`origin'" == "" {
                display as error "internal error: anniversary bucket requires origin()"
                exit 459
            }
            local step = `width'
            if "`unit'" == "month" local step = `width' * 365.25 / 12
            else if "`unit'" == "year" local step = `width' * 365.25
            quietly replace `bucket' = floor((`date' - `origin') / `step') + 1
            * floor() on nominal daily-date boundaries makes the inverse
            * formula one bucket low on some exact boundary dates.
            quietly replace `bucket' = `bucket' + 1 if ///
                `date' >= floor(`origin' + `bucket' * `step')
            quietly replace `bucket' = `bucket' - 1 if ///
                `date' < floor(`origin' + (`bucket' - 1) * `step')
        }
        else quietly replace `bucket' = 1
    }
    local rc = _rc
    set varabbrev `_orig_varabbrev'
    if `rc' exit `rc'
end
