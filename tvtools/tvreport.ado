*! tvreport Version 1.0.1  2026/02/23
*! Automated report generation for time-varying exposure analysis
*! Author: Tim Copeland
*! Program class: rclass (returns results in r())

/*
Basic syntax:
  tvreport, id(varname) start(varname) stop(varname) exposure(varname) ///
      [covariates(varlist) event(varname) format(string) output(filename)]

Description:
  Generates comprehensive analysis reports for time-varying exposure
  studies, including exposure patterns, balance, and preliminary analyses.

See help tvreport for complete documentation
*/

program define tvreport, rclass
    version 16.0
    set varabbrev off
    set more off

    syntax [if] [in] , ID(varname) START(varname) STOP(varname) EXPosure(varname) ///
        [COVariates(varlist) EVENT(varname) FORMAT(string)]

    * =========================================================================
    * VALIDATE INPUT
    * =========================================================================

    * Validate exposure is numeric (before markout, which fails on strings)
    capture confirm numeric variable `exposure'
    if _rc != 0 {
        display as error "exposure variable `exposure' must be numeric"
        exit 109
    }

    * Mark sample
    tempvar touse
    mark `touse' `if' `in'
    markout `touse' `id' `start' `stop' `exposure'

    quietly count if `touse'
    if r(N) == 0 {
        display as error "no observations"
        exit 2000
    }

    * Set defaults
    if "`format'" == "" local format "smcl"

    * =========================================================================
    * DISPLAY REPORT HEADER
    * =========================================================================

    display as text ""
    display as text "{hline 70}"
    display as text "{bf:TIME-VARYING EXPOSURE ANALYSIS REPORT}"
    display as text "{hline 70}"
    display as text ""
    display as text "Generated: `c(current_date)' `c(current_time)'"
    display as text ""

    * =========================================================================
    * SECTION 1: DATA OVERVIEW
    * =========================================================================

    display as text "{bf:1. DATA OVERVIEW}"
    display as text "{hline 40}"

    quietly count if `touse'
    local n_obs = r(N)

    tempvar _id_tag
    quietly egen byte `_id_tag' = tag(`id') if `touse'
    quietly count if `_id_tag' == 1
    local n_ids = r(N)

    display as text "Total observations:    " as result %12.0fc `n_obs'
    display as text "Unique individuals:    " as result %12.0fc `n_ids'

    * Person-time
    tempvar pt
    quietly gen double `pt' = `stop' - `start' + 1 if `touse'
    quietly summarize `pt' if `touse'
    local total_pt = r(sum)
    local mean_pt = r(mean)

    display as text "Total person-time:     " as result %12.0fc `total_pt' " days"
    display as text "Mean follow-up:        " as result %12.1fc `mean_pt' " days"
    display as text ""

    * =========================================================================
    * SECTION 2: EXPOSURE DISTRIBUTION
    * =========================================================================

    display as text "{bf:2. EXPOSURE DISTRIBUTION}"
    display as text "{hline 40}"

    quietly tab `exposure' if `touse'
    local n_levels = r(r)

    display as text "Exposure levels:       " as result `n_levels'
    display as text ""

    tab `exposure' if `touse', matcell(freq)

    * Person-time by exposure
    display as text ""
    display as text "Person-time by exposure:"

    quietly levelsof `exposure' if `touse', local(levels)
    foreach lev of local levels {
        quietly summarize `pt' if `exposure' == `lev' & `touse'
        local pt_lev = r(sum)
        local pct = 100 * `pt_lev' / `total_pt'
        display as text "  `exposure' = " %3.0f `lev' ": " as result %12.0fc `pt_lev' ///
            as text " days (" as result %5.1f `pct' as text "%)"
    }
    display as text ""

    * =========================================================================
    * SECTION 3: COVARIATE BALANCE (if specified)
    * =========================================================================

    if "`covariates'" != "" {
        display as text "{bf:3. COVARIATE BALANCE}"
        display as text "{hline 40}"

        capture tvbalance `covariates' if `touse', exposure(`exposure')
        if _rc == 0 {
            display as text ""
        }
        else {
            display as text "Balance check failed - check tvbalance command"
            display as text ""
        }
    }
    else {
        display as text "{bf:3. COVARIATE BALANCE}"
        display as text "{hline 40}"
        display as text "(No covariates specified)"
        display as text ""
    }

    * =========================================================================
    * SECTION 4: EVENTS (if specified)
    * =========================================================================

    if "`event'" != "" {
        display as text "{bf:4. EVENT SUMMARY}"
        display as text "{hline 40}"

        quietly count if `event' == 1 & `touse'
        local n_events = r(N)

        display as text "Total events:          " as result `n_events'

        * Events by exposure
        display as text ""
        display as text "Events by exposure:"

        foreach lev of local levels {
            quietly count if `exposure' == `lev' & `event' == 1 & `touse'
            local ev_lev = r(N)
            quietly summarize `pt' if `exposure' == `lev' & `touse'
            local pt_lev = r(sum)
            local rate = 1000 * `ev_lev' / (`pt_lev' / 365.25)

            display as text "  `exposure' = " %3.0f `lev' ": " as result %6.0f `ev_lev' ///
                as text " events, rate = " as result %6.2f `rate' as text " per 1000 PY"
        }
        display as text ""
    }

    * =========================================================================
    * SECTION 5: RECOMMENDATIONS
    * =========================================================================

    display as text "{bf:5. ANALYSIS RECOMMENDATIONS}"
    display as text "{hline 40}"
    display as text ""
    display as text "1. Check for positivity violations (extreme propensity scores)"
    display as text "2. Assess covariate balance; consider weighting if SMD > 0.1"
    display as text "3. Run sensitivity analyses for unmeasured confounding"
    display as text "4. Consider competing risks if applicable"
    display as text ""

    * =========================================================================
    * RETURN VALUES
    * =========================================================================

    return scalar n_obs = `n_obs'
    return scalar n_ids = `n_ids'
    return scalar total_pt = `total_pt'
    return scalar n_levels = `n_levels'
    if "`event'" != "" {
        return scalar n_events = `n_events'
    }

    return local id "`id'"
    return local start "`start'"
    return local stop "`stop'"
    return local exposure "`exposure'"

    display as text "{hline 70}"
    display as text "Report generated by tvreport v1.0.1"
    display as text "{hline 70}"

end
