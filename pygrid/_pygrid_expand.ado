*! _pygrid_expand Version 1.0.1  2026/08/30
*! Expand resolved windows into regular person-period rows
*! Author: Timothy P Copeland, Karolinska Institutet
*! Program class: rclass

program define _pygrid_expand, rclass
    version 16.0
    local _orig_varabbrev = c(varabbrev)
    set varabbrev off

    capture noisily {
        syntax , WSTART(varname numeric) WEND(varname numeric) ///
            EPISODE(varname numeric) AXIS(string) WIDTH(real) UNIT(string) ///
            PERIOD(name) STARTGEN(name) STOPGEN(name) PARTIAL(string) ///
            [ ORIGIN(varname numeric) RELGEN(name) ///
              FIRST(numlist integer max=1) LAST(numlist integer max=1) ]

        confirm new variable `period'
        confirm new variable `startgen'
        confirm new variable `stopgen'
        if "`relgen'" != "" confirm new variable `relgen'
        if "`partial'" == "flag" confirm new variable _partial

        tempvar _pfirst _plast _nperiod _sequence _nomstart _nomstop _ispartial _overlap
        tempvar _observed_start _observed_stop
        quietly generate double `_pfirst' = .
        quietly generate double `_plast' = .

        if "`axis'" == "calendar" {
            if "`unit'" == "day" {
                quietly replace `_pfirst' = floor(`wstart' / `width') * `width'
                quietly replace `_plast' = floor(`wend' / `width') * `width'
            }
            else if "`unit'" == "month" {
                quietly replace `_pfirst' = floor(mofd(`wstart') / `width') * `width'
                quietly replace `_plast' = floor(mofd(`wend') / `width') * `width'
            }
            else {
                quietly replace `_pfirst' = floor(year(`wstart') / `width') * `width'
                quietly replace `_plast' = floor(year(`wend') / `width') * `width'
            }
            quietly generate double `_nperiod' = (`_plast' - `_pfirst') / `width' + 1
        }
        else if "`axis'" == "anniversary" {
            local step = `width'
            if "`unit'" == "month" local step = `width' * 365.25 / 12
            else if "`unit'" == "year" local step = `width' * 365.25
            quietly replace `_pfirst' = floor((`wstart' - `origin') / `step') + 1
            quietly replace `_plast' = floor((`wend' - `origin') / `step') + 1
            * Invert the floored nominal boundary exactly. The raw division
            * is one bucket low when a daily date equals floor(origin+k*step).
            quietly replace `_pfirst' = `_pfirst' + 1 if ///
                `wstart' >= floor(`origin' + `_pfirst' * `step')
            quietly replace `_pfirst' = `_pfirst' - 1 if ///
                `wstart' < floor(`origin' + (`_pfirst' - 1) * `step')
            quietly replace `_plast' = `_plast' + 1 if ///
                `wend' >= floor(`origin' + `_plast' * `step')
            quietly replace `_plast' = `_plast' - 1 if ///
                `wend' < floor(`origin' + (`_plast' - 1) * `step')
            quietly generate double `_nperiod' = `_plast' - `_pfirst' + 1
        }
        else {
            quietly replace `_pfirst' = 1
            quietly replace `_plast' = 1
            quietly generate double `_nperiod' = 1
        }

        quietly count if missing(`_nperiod') | `_nperiod' < 1 | `_nperiod' != floor(`_nperiod')
        if r(N) > 0 {
            display as error "internal error: `=r(N)' window(s) resolved to an invalid period count"
            exit 459
        }

        quietly expand `_nperiod'
        quietly sort `episode'
        quietly by `episode': generate long `_sequence' = _n - 1
        quietly generate double `period' = `_pfirst' + `_sequence' * `width'

        quietly generate double `_nomstart' = .
        quietly generate double `_nomstop' = .
        if "`axis'" == "calendar" {
            if "`unit'" == "day" {
                quietly replace `_nomstart' = `period'
                quietly replace `_nomstop' = `period' + `width' - 1
                format `period' %td
            }
            else if "`unit'" == "month" {
                quietly replace `_nomstart' = dofm(`period')
                quietly replace `_nomstop' = dofm(`period' + `width') - 1
                format `period' %tm
            }
            else {
                quietly replace `_nomstart' = mdy(1, 1, `period')
                quietly replace `_nomstop' = mdy(1, 1, `period' + `width') - 1
            }
        }
        else if "`axis'" == "anniversary" {
            local step = `width'
            if "`unit'" == "month" local step = `width' * 365.25 / 12
            else if "`unit'" == "year" local step = `width' * 365.25
            quietly replace `period' = `_pfirst' + `_sequence'
            quietly replace `_nomstart' = floor(`origin' + (`period' - 1) * `step')
            quietly replace `_nomstop' = floor(`origin' + `period' * `step') - 1
        }
        else {
            quietly replace `period' = 1
            quietly replace `_nomstart' = `wstart'
            quietly replace `_nomstop' = `wend'
        }

        quietly generate double `startgen' = max(`wstart', `_nomstart')
        quietly generate double `stopgen' = min(`wend', `_nomstop')
        format `startgen' `stopgen' %td

        if "`first'" != "" quietly drop if `period' < `first'
        if "`last'" != "" quietly drop if `period' > `last'
        quietly count
        if r(N) == 0 {
            display as error "no periods remain after first()/last() restrictions"
            exit 2000
        }

        quietly generate byte `_ispartial' = (`startgen' != `_nomstart' | `stopgen' != `_nomstop')
        quietly count if `_ispartial'
        local N_partial = r(N)
        if "`partial'" == "flag" {
            quietly generate byte _partial = `_ispartial'
            label variable _partial "Observed interval is shorter than its nominal period"
        }
        else if "`partial'" == "drop" quietly drop if `_ispartial'

        quietly count
        if r(N) == 0 {
            display as error "no periods remain after partial(drop)"
            exit 2000
        }

        * first()/last() and partial(drop) intentionally reduce the window.
        * Reset the partition target to the retained contiguous contribution.
        quietly bysort `episode': egen double `_observed_start' = min(`startgen')
        quietly by `episode': egen double `_observed_stop' = max(`stopgen')
        quietly replace `wstart' = `_observed_start'
        quietly replace `wend' = `_observed_stop'

        if "`relgen'" != "" {
            quietly generate double `relgen' = .
            if "`axis'" == "calendar" {
                tempvar _origin_period
                quietly generate double `_origin_period' = .
                if "`unit'" == "day" quietly replace `_origin_period' = floor(`origin' / `width') * `width'
                else if "`unit'" == "month" quietly replace `_origin_period' = floor(mofd(`origin') / `width') * `width'
                else quietly replace `_origin_period' = floor(year(`origin') / `width') * `width'
                quietly replace `relgen' = (`period' - `_origin_period') / `width'
            }
            else if "`axis'" == "anniversary" quietly replace `relgen' = `period' - 1
            else quietly replace `relgen' = 0
        }

        quietly sort `episode' `startgen' `stopgen'
        quietly by `episode': generate byte `_overlap' = ///
            _n > 1 & `startgen' <= `stopgen'[_n - 1]
        quietly count if `_overlap'
        if r(N) > 0 {
            display as error "internal error: generated periods overlap within an input episode"
            exit 459
        }

        return scalar N_partial = `N_partial'
    }
    local rc = _rc
    set varabbrev `_orig_varabbrev'
    if `rc' exit `rc'
end
