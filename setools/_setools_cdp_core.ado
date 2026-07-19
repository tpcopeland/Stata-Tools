*! _setools_cdp_core Version 1.5.1  2026/07/19
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
* baseout()            : optional baseline EDSS carried onto the event row
* confdate()/confedss(): optional confirming-assessment metadata
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
        CONFirmdays(integer) GENname(name) [THREEtier CONFirmtype(string) ///
        BASEout(name) CONFdate(name) CONFedss(name)]

    tokenize `varlist'
    local idvar `1'
    local edssvar `2'
    local datevar `3'

    if "`confirmtype'" == "" local confirmtype "sustained"

    tempvar pthresh change isprog candidate candidate_base ///
        candidate_thresh criterion okall assessment_date assessment_edss

    * Progression threshold from baseline (two- or three-tier)
    _setools_cdp_thresh `baseedss', generate(`pthresh') `threetier'

    * Change from baseline; flag measurements meeting threshold after baseline
    qui gen double `change' = `edssvar' - `baseedss'
    qui gen byte `isprog' = (`change' >= `pthresh') & ///
        (`datevar' > `basedate')

    * Iterative confirmation
    qui gen byte `okall' = 0
    qui count
    local max_cdp_iter = r(N) + 1
    local cdp_iter = 1
    local cdp_found = 0
    local converged = 1
    while `cdp_found' == 0 & `cdp_iter' <= `max_cdp_iter' {
        * Earliest remaining candidate progression date per person
        capture drop `candidate' `candidate_base' `candidate_thresh'
        qui egen long `candidate' = ///
            min(cond(`isprog' == 1, `datevar', .)), by(`idvar')

        qui count if !missing(`candidate')
        if r(N) == 0 {
            continue, break
        }

        * Freeze the reference value and threshold at the candidate event.
        * A later relapse-driven rebaseline must not retroactively change the
        * confirmation criterion for an already-observed candidate.
        qui egen double `candidate_base' = min(cond( ///
            `datevar' == `candidate', `baseedss', .)), by(`idvar')
        qui egen double `candidate_thresh' = min(cond( ///
            `datevar' == `candidate', `pthresh', .)), by(`idvar')

        * Confirmation EDSS value for the candidate (sustained or visit)
        capture drop `criterion' `assessment_date' `assessment_edss'
        _setools_cdp_confirm `idvar' `edssvar' `datevar', ///
            canddate(`candidate') confirmdays(`confirmdays') ///
            generate(`criterion') confirmtype("`confirmtype'") ///
            dateout(`assessment_date') edssout(`assessment_edss')

        capture drop `okall'
        qui gen byte `okall' = ///
            (`criterion' >= `candidate_base' + `candidate_thresh') & ///
            !missing(`criterion')

        * Persons whose candidate failed: exclude that date and retry
        qui count if `okall' == 0 & !missing(`candidate') & ///
            `datevar' == `candidate'
        local n_failed = r(N)

        if `n_failed' == 0 {
            local cdp_found = 1
        }
        else {
            qui replace `isprog' = 0 if `okall' == 0 & ///
                `datevar' == `candidate'
            local cdp_iter = `cdp_iter' + 1
        }
    }
    if `cdp_iter' > `max_cdp_iter' {
        di as error "CDP confirmation failed to converge"
        exit 430
    }

    capture confirm variable `assessment_date'
    if _rc qui gen long `assessment_date' = .
    capture confirm variable `assessment_edss'
    if _rc qui gen double `assessment_edss' = .

    * When the confirmation loop broke on a candidate-free pass (no progression
    * anywhere, or only residual flat follow-up after the last confirmed event),
    * the frozen reference/threshold columns were never created. Materialize them
    * as all-missing so the baseout()/genname() generation below yields 0 events
    * gracefully instead of referencing a nonexistent variable (r(111)).
    capture confirm variable `candidate_base'
    if _rc qui gen double `candidate_base' = .
    capture confirm variable `candidate_thresh'
    if _rc qui gen double `candidate_thresh' = .

    * CDP date is the confirmed candidate date
    qui gen long `genname' = `candidate' if `okall' == 1
    format `genname' %tdCCYY/NN/DD
    local _core_keep "`idvar' `genname'"
    if "`baseout'" != "" {
        qui gen double `baseout' = `candidate_base' if `okall' == 1
        local _core_keep "`_core_keep' `baseout'"
    }
    if "`confdate'" != "" {
        qui gen long `confdate' = `assessment_date' if `okall' == 1
        format `confdate' %tdCCYY/NN/DD
        local _core_keep "`_core_keep' `confdate'"
    }
    if "`confedss'" != "" {
        qui gen double `confedss' = `assessment_edss' if `okall' == 1
        local _core_keep "`_core_keep' `confedss'"
    }

    * One record per person with a confirmed CDP date
    qui keep `_core_keep'
    qui duplicates drop `idvar', force
    qui drop if missing(`genname')

    qui count
    return scalar N_events  = r(N)
    return scalar converged = `converged'
    return scalar iterations = `cdp_iter'
end
