*! _iivw_bs_estimate Version 1.0.2  2026/04/26
*! Bootstrap wrapper for iivw_fit: applies pweights inside the estimation
*! call so Stata's bootstrap prefix does not strip them.
*! Author: Timothy P Copeland

program define _iivw_bs_estimate, eclass
    version 16.0
    local __iivw_old_varabbrev = c(varabbrev)
    set varabbrev off
    capture noisily {
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
        * vce(cluster) omitted: bootstrap prefix handles clustering
        glm `depvar' `covars' [pw=`weightvar'] if `touse', ///
            `glm_family' `glm_link' `log_opt' `geeopts'
    }
    else if "`model'" == "mixed" {
        * vce(cluster) omitted: bootstrap prefix handles clustering
        mixed `depvar' `covars' [pw=`weightvar'] if `touse' ///
            || `panelid':, `log_opt' `mixedopts'
    }
    else {
        display as error "model() must be gee or mixed"
        error 198
    }
    }
    local rc = _rc
    set varabbrev `__iivw_old_varabbrev'
    if `rc' exit `rc'
end
