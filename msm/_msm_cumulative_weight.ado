*! _msm_cumulative_weight Version 1.0.0  2026/03/03
*! Compute cumulative product of period weights via log-sum
*! Author: Timothy P Copeland

* Given a period-level weight variable and panel identifiers,
* compute the cumulative product within each individual using
* the log-sum approach for numerical stability.
*
* Arguments:
*   period_weight - variable containing period-specific weight ratios
*   id            - individual identifier
*   period        - time period variable
*   generate      - name for cumulative weight variable
*
* Returns via c_local: name of generated variable

program define _msm_cumulative_weight
    version 16.0
    set varabbrev off
    set more off

    syntax varname, id(varname) period(varname) generate(name) [replace]

    local pw "`varlist'"

    * Check output variable
    capture confirm variable `generate'
    if _rc == 0 {
        if "`replace'" == "" {
            display as error "variable `generate' already exists; use replace option"
            exit 110
        }
        quietly drop `generate'
    }

    * Compute log of period weight, handling edge cases
    tempvar _log_pw _cum_log
    quietly {
        gen double `_log_pw' = ln(`pw') if !missing(`pw') & `pw' > 0
        * For pw == 0, set log to very negative value (weight -> 0)
        replace `_log_pw' = -709 if `pw' == 0 & !missing(`pw')
        * For missing pw, leave missing (will propagate)

        * Cumulative sum of log-weights within individual
        bysort `id' (`period'): gen double `_cum_log' = sum(`_log_pw')

        * Exponentiate back
        gen double `generate' = exp(`_cum_log')
    }

    c_local _msm_cumweight_var "`generate'"
end
