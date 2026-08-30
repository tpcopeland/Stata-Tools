*! _pygrid_pytime Version 1.0.1  2026/08/30
*! Compute person-time and verify the period partition
*! Author: Timothy P Copeland, Karolinska Institutet
*! Program class: rclass

program define _pygrid_pytime, rclass
    version 16.0
    local _orig_varabbrev = c(varabbrev)
    set varabbrev off

    capture noisily {
        syntax , START(varname numeric) STOP(varname numeric) ///
            WSTART(varname numeric) WEND(varname numeric) ///
            EPISODE(varname numeric) PYTIME(name) PYUNIT(string) ///
            INCLUSIVE(integer) AXIS(string) WIDTH(real) UNIT(string)

        confirm new variable `pytime'
        local divisor = cond("`pyunit'" == "year", 365.25, 1)
        quietly generate double `pytime' = (`stop' - `start' + `inclusive') / `divisor'

        quietly count if missing(`pytime')
        if r(N) > 0 {
            display as error "internal error: generated person-time contains missing values"
            exit 459
        }
        if `inclusive' quietly count if `pytime' <= 0
        else quietly count if `pytime' < 0
        if r(N) > 0 {
            display as error "internal error: generated person-time is outside its valid range"
            exit 459
        }

        if "`axis'" != "fixed" {
            if "`axis'" == "calendar" {
                local maxdays = `width'
                if "`unit'" == "month" local maxdays = 31 * `width'
                else if "`unit'" == "year" local maxdays = 366 * `width'
            }
            else {
                local step = `width'
                if "`unit'" == "month" local step = `width' * 365.25 / 12
                else if "`unit'" == "year" local step = `width' * 365.25
                local maxdays = ceil(`step')
            }
            local maxpy = `maxdays' / `divisor'
            quietly count if `pytime' > `maxpy' + 1e-12
            if r(N) > 0 {
                display as error "internal error: generated person-time exceeds the declared period width"
                exit 459
            }
        }

        tempvar _partsum _nrows _expected _first
        quietly bysort `episode': egen double `_partsum' = total(`pytime')
        quietly by `episode': generate long `_nrows' = _N
        quietly generate double `_expected' = ///
            (`wend' - `wstart' + `inclusive' - (1 - `inclusive') * (`_nrows' - 1)) / `divisor'
        quietly by `episode': generate byte `_first' = _n == 1
        quietly count if `_first' & ///
            (missing(`_partsum') | missing(`_expected') | abs(`_partsum' - `_expected') > 1e-9)
        if r(N) > 0 {
            display as error "internal error: person-period rows do not partition the source window"
            exit 459
        }

        quietly summarize `pytime', meanonly
        return scalar pytotal = r(sum)
        return scalar pymin = r(min)
        return scalar pymax = r(max)
    }
    local rc = _rc
    set varabbrev `_orig_varabbrev'
    if `rc' exit `rc'
end
