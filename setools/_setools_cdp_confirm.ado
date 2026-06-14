*! _setools_cdp_confirm Version 1.3.0  2026/06/14
*! setools internal: per-person confirmation EDSS value for a candidate date
*! Author: Timothy P Copeland, Karolinska Institutet
*! Program class: nclass

* Single source of truth for the confirmation rule shared by cdp and pira (both
* the iterative engine and the roving baseline path). Given a candidate
* progression date column, produces the per-person confirmation EDSS value that
* the caller compares against baseline + threshold.
*
* varlist : idvar edssvar datevar
* canddate()   : candidate progression date column (per person)
* confirmdays(): days after the candidate at which confirmation is assessed
* generate()   : name of the per-person confirmation EDSS column to create
* confirmtype(): sustained (default) | visit
*
*   sustained : minimum EDSS across ALL visits at/after candidate+confirmdays
*               (sustained-throughout definition).
*   visit     : EDSS at the FIRST visit occurring at least confirmdays after the
*               candidate (next-confirmed-visit definition; ignores later dips).
*
* Lower EDSS is used on same-day ties (conservative). Uses fixed _setools_cf_*
* working columns and drops them.

program define _setools_cdp_confirm, nclass
    version 16.0
    syntax varlist(min=3 max=3), CANDdate(varname) CONFirmdays(integer) ///
        GENerate(name) [CONFirmtype(string)]

    tokenize `varlist'
    local idvar `1'
    local edssvar `2'
    local datevar `3'

    if "`confirmtype'" == "" local confirmtype "sustained"

    if "`confirmtype'" == "visit" {
        * EDSS at the first visit at/after candidate+confirmdays (min on ties)
        qui gen long _setools_cf_dt = `datevar' if `datevar' >= `canddate' + `confirmdays'
        qui bysort `idvar' (_setools_cf_dt): replace _setools_cf_dt = _setools_cf_dt[1]
        qui gen double `generate' = `edssvar' if `datevar' == _setools_cf_dt
        qui bysort `idvar' (`generate'): replace `generate' = `generate'[1]
        qui drop _setools_cf_dt
    }
    else {
        * Minimum EDSS across all visits at/after candidate+confirmdays
        qui gen double _setools_cf_val = `edssvar' if `datevar' >= `canddate' + `confirmdays'
        qui egen double `generate' = min(_setools_cf_val), by(`idvar')
        qui drop _setools_cf_val
    }
end
