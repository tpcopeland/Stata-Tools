*! _setools_cdp_baseline Version 1.5.0  2026/07/13
*! setools internal: per-person baseline EDSS and baseline date columns
*! Author: Timothy P Copeland, Karolinska Institutet
*! Program class: nclass

* Single source of truth for baseline EDSS determination shared by cdp and
* pira. Operates on diagnosis-level data already reduced to the relevant rows
* (missing EDSS/date dropped) and sorted by id date edss.
*
* varlist : idvar edssvar datevar
* dxdate()        : diagnosis-date variable
* baselinewindow(): days from diagnosis for the in-window baseline search
* edssout()/dateout(): names of the baseline EDSS / baseline date columns to create
*
* Rule: first EDSS within baselinewindow of diagnosis; if none, earliest
* available measurement. Lower EDSS is used on same-day ties because sort order
* alone is not a contract. All working columns are true tempvars.

program define _setools_cdp_baseline, nclass
    version 16.0
    syntax varlist(min=3 max=3), DXdate(varname) BASElinewindow(integer) ///
        EDSSout(name) DATEout(name)

    tokenize `varlist'
    local idvar `1'
    local edssvar `2'
    local datevar `3'

    qui gen double `edssout' = .
    qui gen long `dateout' = .
    tempvar inwin winhit winedss anyhit anyedss

    * First EDSS within baseline window of diagnosis
    qui gen byte `inwin' = ///
        (`datevar' >= `dxdate' & `datevar' <= `dxdate' + `baselinewindow')
    qui egen double `winhit' = ///
        min(cond(`inwin', `datevar', .)), by(`idvar')
    qui egen double `winedss' = ///
        min(cond(`datevar' == `winhit', `edssvar', .)), by(`idvar')
    qui replace `edssout' = `winedss' if !missing(`winedss')
    qui replace `dateout' = `winhit' if !missing(`winhit')

    * Otherwise earliest available measurement
    qui egen double `anyhit' = min(`datevar'), by(`idvar')
    qui egen double `anyedss' = ///
        min(cond(`datevar' == `anyhit', `edssvar', .)), by(`idvar')
    qui replace `edssout' = `anyedss' if missing(`edssout')
    qui replace `dateout' = `anyhit' if missing(`dateout')
end
