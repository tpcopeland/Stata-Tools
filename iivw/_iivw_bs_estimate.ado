*! _iivw_bs_estimate Version 2.2.0  2026/07/23
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
         FAMily(string) LINk(string) PANELid(varname) BSid(varname) ///
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

    * Same pass-through guard as iivw_fit: a variance/resampling token in
    * geeopts()/mixedopts() must not reach the inner glm here either (IIVW-B08).
    _iivw_check_passthru, optname(geeopts)  value(`"`geeopts'"')
    _iivw_check_passthru, optname(mixedopts) value(`"`mixedopts'"')

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

        * The random intercept groups on the PANEL UNIT (the subject), which is
        * not the same thing as bootstrap's resampled-cluster id when cluster()
        * sits above the panel -- a clinic, say. Passing the clinic draw id
        * straight through made a whole clinic one random-effect group: in a
        * 8-clinic x 5-patient hierarchy, 8 groups instead of 40, moving the
        * fixed effect from 0.510 to 0.436 and the intercept SD from 1.136 to
        * 0.211.
        *
        * group(bsid, panelid) is the resampled subject: it is what idcluster()
        * would have produced had the panel been the resampling unit, and it
        * still gives a subject drawn twice two distinct groups. When cluster()
        * IS the panel id the mapping is one-to-one, so this is a no-op there --
        * which is why the common case never surfaced the bug.
        local grpvar "`panelid'"
        if "`bsid'" != "" {
            tempvar _bs_subj
            quietly egen long `_bs_subj' = group(`bsid' `panelid')
            local grpvar "`_bs_subj'"
        }

        * vce(cluster) omitted: bootstrap prefix handles clustering
        mixed `depvar' `covars' `wt_clause' if `touse' ///
            || `grpvar':, `log_opt' `mixedopts'
    }
    else {
        display as error "model() must be gee or mixed"
        error 198
    }

    * The outcome fit must have CONVERGED to count as a replicate; see
    * _iivw_require_draw_converged.ado for why, and for why a missing
    * e(converged) fails closed rather than passing.
    _iivw_require_draw_converged, model(`model')
    }
    local rc = _rc
    set varabbrev `__iivw_old_varabbrev'
    if `rc' exit `rc'
end
