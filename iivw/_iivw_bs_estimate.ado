*! _iivw_bs_estimate Version 1.0.1  2026/10/30
*! Bootstrap wrapper for iivw_fit: applies pweights inside the estimation
*! call so Stata's bootstrap prefix does not strip them.
*! Author: Timothy P Copeland, Karolinska Institutet

program define _iivw_bs_estimate, eclass
    version 16.0
    local __iivw_old_varabbrev = c(varabbrev)
    set varabbrev off
    capture noisily {
    syntax varlist(numeric min=1) [if] [in], ///
        [WEIGHTvar(varname) ///
         FAMily(string) LINk(string) ///
         GEEopts(string asis) noLOG]

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

    * Same pass-through guard as iivw_fit: a variance/resampling token in
    * geeopts() must not reach the inner glm here either (IIVW-B08).
    _iivw_check_passthru, optname(geeopts)  value(`"`geeopts'"')

    local log_opt = cond("`log'" == "nolog", "nolog", "")
    local wt_clause ""
    if "`weightvar'" != "" local wt_clause "[pw=`weightvar']"

    local glm_family "family(`family')"
    local glm_link ""
    if "`link'" != "" local glm_link "link(`link')"
    * vce(cluster) omitted: bootstrap prefix handles clustering
    glm `depvar' `covars' `wt_clause' if `touse', ///
        `glm_family' `glm_link' `log_opt' `geeopts'

    * The outcome fit must have CONVERGED to count as a replicate; see
    * _iivw_require_draw_converged.ado for why, and for why a missing
    * e(converged) fails closed rather than passing.
    _iivw_require_draw_converged, model(glm)
    }
    local rc = _rc
    set varabbrev `__iivw_old_varabbrev'
    if `rc' exit `rc'
end
