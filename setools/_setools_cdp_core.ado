*! _setools_cdp_core Version 1.4.0  2026/06/15
*! setools internal: confirmed disability progression engine (non-roving)
*! Author: Timothy P Copeland, Karolinska Institutet
*! Program class: rclass

* Shared confirmed-disability-progression engine for cdp (standard baseline)
* and pira. Operates on diagnosis-level EDSS data already reduced to relevant
* rows and sorted by id date edss, with per-row baseline EDSS / baseline date
* columns supplied by _setools_cdp_baseline (and possibly re-baselined by the
* caller). Reduces the data in memory to one row per person carrying the
* confirmed CDP date in genname(), dropping persons with no confirmed event.
*
* varlist : idvar edssvar datevar
* baseedss()/basedate(): baseline EDSS / baseline date columns (per row)
* confirmdays()        : confirmation interval in days
* genname()            : name of the CDP date column to create
* threetier            : use the three-tier threshold rule (default two-tier)
* confirmtype()        : sustained (default) | visit
*
* Iterative confirmation: try each candidate progression date per person in
* order; if a candidate fails confirmation, exclude it and try the next.
*
* Returns: r(N_events), r(converged), r(iterations).

program define _setools_cdp_core, rclass
    version 16.0
    syntax varlist(min=3 max=3), BASEedss(varname) BASEdate(varname) ///
        CONFirmdays(integer) GENname(name) [THREEtier CONFirmtype(string)]

    tokenize `varlist'
    local idvar `1'
    local edssvar `2'
    local datevar `3'

    if "`confirmtype'" == "" local confirmtype "sustained"

    * Progression threshold from baseline (two- or three-tier)
    _setools_cdp_thresh `baseedss', generate(_setools_pthresh) `threetier'

    * Change from baseline; flag measurements meeting threshold after baseline
    qui gen double _setools_chg = `edssvar' - `baseedss'
    qui gen byte _setools_isprog = (_setools_chg >= _setools_pthresh) & ///
        (`datevar' > `basedate')

    * Iterative confirmation
    qui gen byte _setools_okall = 0
    local max_cdp_iter = 100
    local cdp_iter = 1
    local cdp_found = 0
    local converged = 1
    while `cdp_found' == 0 & `cdp_iter' <= `max_cdp_iter' {
        * Earliest remaining candidate progression date per person
        capture drop _setools_cand
        qui egen long _setools_cand = min(cond(_setools_isprog == 1, `datevar', .)), by(`idvar')

        qui count if !missing(_setools_cand)
        if r(N) == 0 {
            continue, break
        }

        * Confirmation EDSS value for the candidate (sustained or visit)
        capture drop _setools_confval
        _setools_cdp_confirm `idvar' `edssvar' `datevar', ///
            canddate(_setools_cand) confirmdays(`confirmdays') ///
            generate(_setools_confval) confirmtype("`confirmtype'")

        capture drop _setools_okall
        qui gen byte _setools_okall = ///
            (_setools_confval >= `baseedss' + _setools_pthresh) & !missing(_setools_confval)

        * Persons whose candidate failed: exclude that date and retry
        qui count if _setools_okall == 0 & !missing(_setools_cand) & `datevar' == _setools_cand
        local n_failed = r(N)

        if `n_failed' == 0 {
            local cdp_found = 1
        }
        else {
            qui replace _setools_isprog = 0 if _setools_okall == 0 & `datevar' == _setools_cand
            local cdp_iter = `cdp_iter' + 1
        }

        qui drop _setools_confval
    }
    if `cdp_found' == 0 & `cdp_iter' > `max_cdp_iter' {
        local converged = 0
        local cdp_iter = `max_cdp_iter'
        di as text "Warning: CDP confirmation did not converge within `max_cdp_iter' iterations"
    }

    * CDP date is the confirmed candidate date
    qui gen long `genname' = _setools_cand if _setools_okall == 1
    format `genname' %tdCCYY/NN/DD

    * One record per person with a confirmed CDP date
    qui keep `idvar' `genname'
    qui duplicates drop `idvar', force
    qui drop if missing(`genname')

    qui count
    return scalar N_events  = r(N)
    return scalar converged = `converged'
    return scalar iterations = `cdp_iter'
end
