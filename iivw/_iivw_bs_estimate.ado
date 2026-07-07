*! _iivw_bs_estimate Version 1.9.3  2026/07/07
*! Bootstrap wrapper for iivw_fit: applies pweights inside the estimation
*! call so Stata's bootstrap prefix does not strip them.
*! Author: Timothy P Copeland, Karolinska Institutet

program define _iivw_bs_estimate, eclass
    version 16.0
    local __iivw_old_varabbrev = c(varabbrev)
    set varabbrev off
    capture noisily {
    syntax varlist(numeric min=1) [if] [in], ///
        MODel(string) ///
        [WEIGHTvar(varname) ///
         FAMily(string) LINk(string) PANELid(varname) ///
         GEEopts(string asis) MIXEDopts(string asis) noLOG]

    marksample touse
    if "`weightvar'" != "" {
        markout `touse' `weightvar'
    }
    quietly count if `touse'
    if r(N) == 0 {
        display as error "no observations"
        error 2000
    }
    gettoken depvar covars : varlist

    local log_opt = cond("`log'" == "nolog", "nolog", "")
    local wt_clause ""
    if "`weightvar'" != "" local wt_clause "[pw=`weightvar']"

    if "`model'" == "gee" {
        local glm_family "family(`family')"
        local glm_link ""
        if "`link'" != "" local glm_link "link(`link')"
        * vce(cluster) omitted: bootstrap prefix handles clustering
        glm `depvar' `covars' `wt_clause' if `touse', ///
            `glm_family' `glm_link' `log_opt' `geeopts'
    }
    else if "`model'" == "mixed" {
        if "`panelid'" == "" {
            display as error "panelid() required with model(mixed)"
            error 198
        }
        * vce(cluster) omitted: bootstrap prefix handles clustering
        mixed `depvar' `covars' `wt_clause' if `touse' ///
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
