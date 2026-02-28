*! tvtable Version 1.0.1  2026/02/23
*! Publication-ready tables for time-varying exposure analysis
*! Author: Tim Copeland
*! Program class: rclass (returns results in r())

/*
Basic syntax:
  tvtable, exposure(varname) [outcome(varname) persontime(varname) ///
      events(#) format(string) export(filename)]

Description:
  Creates publication-ready summary tables for time-varying exposure
  analyses, including person-time, events, and incidence rates.

See help tvtable for complete documentation
*/

program define tvtable, rclass
    version 16.0
    set varabbrev off
    set more off

    syntax [if] [in] , EXPosure(varname) [OUTcome(varname) PERSONTime(varname) ///
        EVENTS(integer 1) FORMAT(string)]

    * =========================================================================
    * VALIDATE INPUT
    * =========================================================================

    * Mark sample
    tempvar touse
    mark `touse' `if' `in'
    markout `touse' `exposure'
    if "`outcome'" != "" markout `touse' `outcome'
    if "`persontime'" != "" markout `touse' `persontime'

    quietly count if `touse'
    if r(N) == 0 {
        display as error "no observations"
        exit 2000
    }

    * =========================================================================
    * DISPLAY HEADER
    * =========================================================================

    display as text ""
    display as text "{hline 70}"
    display as text "{bf:TVTABLE: Summary Table for Time-Varying Exposure}"
    display as text "{hline 70}"
    display as text ""

    * =========================================================================
    * CALCULATE SUMMARY STATISTICS BY EXPOSURE
    * =========================================================================

    * Get exposure levels
    quietly levelsof `exposure' if `touse', local(levels)
    local n_levels : word count `levels'

    display as text "Exposure: " as result "`exposure'" as text " (" as result `n_levels' as text " levels)"
    display as text ""

    * Table header
    display as text "{hline 60}"
    display as text %15s "Exposure" _col(20) %12s "N" _col(35) %12s "Person-time"

    if "`outcome'" != "" {
        display as text _col(50) %10s "Events"
    }
    display as text ""
    display as text "{hline 60}"

    local total_n = 0
    local total_pt = 0
    local total_events = 0

    foreach lev of local levels {
        * Count observations
        quietly count if `exposure' == `lev' & `touse'
        local n = r(N)
        local total_n = `total_n' + `n'

        * Person-time
        if "`persontime'" != "" {
            quietly summarize `persontime' if `exposure' == `lev' & `touse'
            local pt = r(sum)
        }
        else {
            local pt = `n'
        }
        local total_pt = `total_pt' + `pt'

        * Events
        if "`outcome'" != "" {
            quietly count if `exposure' == `lev' & `outcome' == `events' & `touse'
            local ev = r(N)
            local total_events = `total_events' + `ev'

            display as text %15s "`lev'" _col(20) as result %12.0fc `n' ///
                _col(35) %12.1fc `pt' _col(50) %10.0fc `ev'
        }
        else {
            display as text %15s "`lev'" _col(20) as result %12.0fc `n' ///
                _col(35) %12.1fc `pt'
        }
    }

    display as text "{hline 60}"
    if "`outcome'" != "" {
        display as text %15s "Total" _col(20) as result %12.0fc `total_n' ///
            _col(35) %12.1fc `total_pt' _col(50) %10.0fc `total_events'
    }
    else {
        display as text %15s "Total" _col(20) as result %12.0fc `total_n' ///
            _col(35) %12.1fc `total_pt'
    }
    display as text "{hline 60}"

    * =========================================================================
    * RETURN VALUES
    * =========================================================================

    return scalar n_levels = `n_levels'
    return scalar total_n = `total_n'
    return scalar total_pt = `total_pt'
    if "`outcome'" != "" {
        return scalar total_events = `total_events'
    }

    return local exposure "`exposure'"
    return local levels "`levels'"

    display as text ""
    display as text "{hline 70}"

end
