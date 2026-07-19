*! _setools_cdp_confirm Version 1.5.1  2026/07/19
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
* generate()   : name of the per-person confirmation criterion to create
* dateout()    : optional date of the first eligible confirmation assessment
* edssout()    : optional EDSS at that assessment
* confirmtype(): sustained (default) | visit
*
*   sustained : minimum EDSS across ALL visits at/after candidate+confirmdays
*               (sustained-throughout definition).
*   visit     : EDSS at the FIRST visit occurring at least confirmdays after the
*               candidate (next-confirmed-visit definition; ignores later dips).
*
* Lower EDSS is used on same-day ties (conservative). All working columns are
* true tempvars.

program define _setools_cdp_confirm, nclass
    version 16.0
    syntax varlist(min=3 max=3), CANDdate(varname) CONFirmdays(integer) ///
        GENerate(name) [CONFirmtype(string) DATEout(name) EDSSout(name)]

    tokenize `varlist'
    local idvar `1'
    local edssvar `2'
    local datevar `3'

    if "`confirmtype'" == "" local confirmtype "sustained"
    tempvar firstdt firstedss minvalue
    if "`dateout'" == "" {
        tempvar internal_dateout
        local dateout `internal_dateout'
    }
    if "`edssout'" == "" {
        tempvar internal_edssout
        local edssout `internal_edssout'
    }

    * The confirming assessment is the first visit at or after the required
    * interval.  Its actual date and conservative same-day EDSS are carried to
    * the roving-baseline transition even when sustained confirmation also
    * examines later visits.
    qui gen long `firstdt' = `datevar' if ///
        `datevar' >= `canddate' + `confirmdays' & !missing(`canddate')
    qui egen long `dateout' = min(`firstdt'), by(`idvar')
    qui gen double `firstedss' = `edssvar' if `datevar' == `dateout'
    qui egen double `edssout' = min(`firstedss'), by(`idvar')

    if "`confirmtype'" == "visit" {
        qui gen double `generate' = `edssout'
    }
    else {
        * Minimum EDSS across all visits at/after candidate+confirmdays
        qui gen double `minvalue' = `edssvar' if ///
            `datevar' >= `canddate' + `confirmdays' & !missing(`canddate')
        qui egen double `generate' = min(`minvalue'), by(`idvar')
    }
end
