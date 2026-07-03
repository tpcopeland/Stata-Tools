*! _setools_cdp_baseline Version 1.4.1  2026/07/03
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
* alone is not a contract. Uses fixed _setools_* working columns (not tempvars)
* and drops them, so it is safe to call after dataset switching in the caller.

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

    * First EDSS within baseline window of diagnosis
    qui gen byte _setools_bl_inwin = ///
        (`datevar' >= `dxdate' & `datevar' <= `dxdate' + `baselinewindow')
    qui egen double _setools_bl_winhit = ///
        min(cond(_setools_bl_inwin, `datevar', .)), by(`idvar')
    qui egen double _setools_bl_winedss = ///
        min(cond(`datevar' == _setools_bl_winhit, `edssvar', .)), by(`idvar')
    qui replace `edssout' = _setools_bl_winedss if !missing(_setools_bl_winedss)
    qui replace `dateout' = _setools_bl_winhit if !missing(_setools_bl_winhit)
    qui drop _setools_bl_inwin _setools_bl_winhit _setools_bl_winedss

    * Otherwise earliest available measurement
    qui egen double _setools_bl_anyhit = min(`datevar'), by(`idvar')
    qui egen double _setools_bl_anyedss = ///
        min(cond(`datevar' == _setools_bl_anyhit, `edssvar', .)), by(`idvar')
    qui replace `edssout' = _setools_bl_anyedss if missing(`edssout')
    qui replace `dateout' = _setools_bl_anyhit if missing(`dateout')
    qui drop _setools_bl_anyhit _setools_bl_anyedss
end
