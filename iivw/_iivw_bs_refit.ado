*! _iivw_bs_refit Version 1.9.7  2026/07/13
*! Bootstrap wrapper for iivw_fit, refitweights: recomputes IIW/IPTW/FIPTIW
*! weights from scratch on each resampled panel before refitting the outcome
*! model, so the bootstrap propagates weight-estimation uncertainty.
*! Author: Timothy P Copeland, Karolinska Institutet
*! Program class: eclass

program define _iivw_bs_refit, eclass
    version 16.0
    local __iivw_old_varabbrev = c(varabbrev)
    set varabbrev off

    * The iivw_weight call below rewrites the stored weighting contract with
    * this replicate's resampled (idcluster) id. Bootstrap's observed pass runs
    * on the live dataset, so without this snapshot the bogus id would leak into
    * the user's _dta characteristics. Snapshot before any work; restore in the
    * cleanup zone so the contract survives on both success and error.
    local __iivw_csnap_names _iivw_weighted _iivw_id _iivw_time ///
        _iivw_weighttype _iivw_weight_var _iivw_prefix _iivw_iw_var ///
        _iivw_tw_var _iivw_ps_var _iivw_treat _iivw_treat_covars ///
        _iivw_ps_estimand _iivw_contract_version _iivw_visit_covars ///
        _iivw_baseevent _iivw_stabcov _iivw_truncate _iivw_efron _iivw_entry ///
        _iivw_censor_mode _iivw_censor_var _iivw_maxfu
    local __iivw_ci 0
    foreach c of local __iivw_csnap_names {
        local ++__iivw_ci
        local __iivw_csnap`__iivw_ci' : char _dta[`c']
    }

    capture noisily {
    syntax varlist(numeric min=1) [if] [in], ///
        NEWID(varname) TIMEvar(varname) WTYPE(string) PREFIX(string) ///
        MODel(string) ///
        [PANELid(varname) ///
         VISITcov(string) TREAT(string) TREATcov(string) ///
         STABcov(string) TRUNCate(string) EFRon BASEline(string) ///
         ENTRY(string) ///
         CENSor(string) MAXfu(string) ENDATLASTvisit ///
         FAMily(string) LINk(string) ///
         GEEopts(string asis) MIXEDopts(string asis) noLOG]

    marksample touse

    local log_opt = cond("`log'" == "nolog", "nolog", "")
    local weight_var "`prefix'weight"

    * ---------------------------------------------------------------------
    * The resampled subject.
    *
    * newid() is bootstrap's idcluster() variable: a distinct id per resampled
    * CLUSTER. When cluster() is the panel id that is also the resampled
    * subject, and passing it through was fine. When cluster() sits above the
    * panel -- a clinic -- it is not: iivw_weight was handed the clinic draw as
    * id(), so an entire clinic became one subject in the visit-intensity
    * counting process, its patients' visits interleaved into a single
    * recurrent-event history.
    *
    * group(newid, panelid) is the resampled subject in both cases: unique per
    * (draw, patient), so a clinic drawn twice still yields two distinct copies
    * of each of its patients. When cluster() IS the panel the mapping is
    * one-to-one with newid, which is why the common case never showed the bug.
    * ---------------------------------------------------------------------
    tempvar _bs_subj
    if "`panelid'" != "" {
        quietly egen long `_bs_subj' = group(`newid' `panelid')
    }
    else {
        quietly gen long `_bs_subj' = `newid'
    }

    * ---------------------------------------------------------------------
    * Recompute weights on the resampled panel.
    * lagvars() is NOT replayed: the *_lag1 variables already travel with each
    * resampled row, so they are passed through visit_cov() verbatim.
    *
    * The end-of-follow-up contract IS replayed. Without it the replicates would
    * refit the visit-intensity model on a truncated risk set while the observed
    * estimate used the full one -- bootstrapping a different estimator than the
    * one being reported.
    * ---------------------------------------------------------------------
    local efron_opt = cond("`efron'" != "", "efron", "")

    if "`wtype'" == "iptw" {
        local wopts "treat(`treat') treat_cov(`treatcov')"
        if "`truncate'" != "" {
            local wopts "`wopts' truncate(`truncate')"
        }
        quietly iivw_weight, id(`_bs_subj') time(`timevar') `wopts' ///
            wtype(iptw) generate(`prefix') replace nolog
    }
    else {
        * iivw or fiptiw: visit-intensity model (+ treatment model for fiptiw)
        local wopts "visit_cov(`visitcov')"
        if "`treat'" != "" {
            local wopts "`wopts' treat(`treat') treat_cov(`treatcov')"
        }
        if "`stabcov'" != "" {
            local wopts "`wopts' stabcov(`stabcov')"
        }
        if "`truncate'" != "" {
            local wopts "`wopts' truncate(`truncate')"
        }
        * entry() is ignored when the baseline visit is study entry
        if "`baseline'" == "event" & "`entry'" != "" {
            local wopts "`wopts' entry(`entry')"
        }
        if "`censor'" != "" {
            local wopts "`wopts' censor(`censor')"
        }
        else if "`maxfu'" != "" {
            local wopts "`wopts' maxfu(`maxfu')"
        }
        else {
            local wopts "`wopts' endatlastvisit"
        }
        local base_opt = cond("`baseline'" != "", "baseline(`baseline')", "")
        quietly iivw_weight, id(`_bs_subj') time(`timevar') `wopts' ///
            wtype(`wtype') `efron_opt' `base_opt' ///
            generate(`prefix') replace nolog
    }

    * Drop rows with a missing recomputed weight from this replicate's fit
    markout `touse' `weight_var'
    quietly count if `touse'
    if r(N) == 0 {
        display as error "no observations with valid weights in bootstrap replicate"
        error 2000
    }

    * ---------------------------------------------------------------------
    * Refit the outcome model with the freshly recomputed weights.
    * vce(cluster) is omitted because the bootstrap prefix supplies the
    * cluster resampling and resulting variance.
    * ---------------------------------------------------------------------
    gettoken depvar covars : varlist

    if "`model'" == "gee" {
        local glm_family "family(`family')"
        local glm_link ""
        if "`link'" != "" local glm_link "link(`link')"
        glm `depvar' `covars' [pw=`weight_var'] if `touse', ///
            `glm_family' `glm_link' `log_opt' `geeopts'
    }
    else if "`model'" == "mixed" {
        * The random intercept groups on the resampled SUBJECT, not the
        * resampled cluster -- see the group(newid, panelid) note above.
        mixed `depvar' `covars' [pw=`weight_var'] if `touse' ///
            || `_bs_subj':, `log_opt' `mixedopts'
    }
    else {
        display as error "model() must be gee or mixed"
        error 198
    }

    }
    local rc = _rc

    * Restore the snapshotted weighting contract (runs on success and error)
    local __iivw_ci 0
    foreach c of local __iivw_csnap_names {
        local ++__iivw_ci
        char _dta[`c'] "`__iivw_csnap`__iivw_ci''"
    }

    set varabbrev `__iivw_old_varabbrev'
    if `rc' exit `rc'
end
