*! _iivw_bs_estimate Version 1.0.0  2026/03/12
*! Bootstrap wrapper for iivw_fit: applies pweights inside the estimation
*! call so Stata's bootstrap prefix does not strip them.
*! Author: Timothy P Copeland

program define _iivw_bs_estimate, eclass
    version 16.0
    set varabbrev off
    syntax varlist(numeric min=2) [if] [in], ///
        WEIGHTvar(varname) MODel(string) ///
        [FAMily(string) LINk(string) PANELid(varname) ///
         GEEopts(string asis) MIXEDopts(string asis) noLOG]

    marksample touse
    gettoken depvar covars : varlist

    local log_opt = cond("`log'" == "nolog", "nolog", "")

    if "`model'" == "gee" {
        local glm_family "family(`family')"
        local glm_link ""
        if "`link'" != "" local glm_link "link(`link')"
        glm `depvar' `covars' [pw=`weightvar'] if `touse', ///
            `glm_family' `glm_link' `log_opt' `geeopts'
    }
    else if "`model'" == "mixed" {
        mixed `depvar' `covars' [pw=`weightvar'] if `touse' ///
            || `panelid':, `log_opt' `mixedopts'
    }
end
