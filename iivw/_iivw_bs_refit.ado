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
        _iivw_baseevent _iivw_stabcov _iivw_truncate _iivw_efron _iivw_entry
    local __iivw_ci 0
    foreach c of local __iivw_csnap_names {
        local ++__iivw_ci
        local __iivw_csnap`__iivw_ci' : char _dta[`c']
    }

    capture noisily {
    syntax varlist(numeric min=1) [if] [in], ///
        NEWID(varname) TIMEvar(varname) WTYPE(string) PREFIX(string) ///
        MODel(string) ///
        [VISITcov(string) TREAT(string) TREATcov(string) ///
         STABcov(string) TRUNCate(string) EFRon NOBASEevent ///
         ENTRY(string) ///
         FAMily(string) LINk(string) ///
         GEEopts(string asis) MIXEDopts(string asis) noLOG]

    marksample touse

    local log_opt = cond("`log'" == "nolog", "nolog", "")
    local weight_var "`prefix'weight"

    * ---------------------------------------------------------------------
    * Recompute weights on the resampled panel.
    * newid() is bootstrap's idcluster() variable: it gives each resampled
    * subject a distinct id, so duplicated clusters keep a unique id-time key
    * and the Andersen-Gill visit-intensity model sees them as separate
    * subjects. lagvars() is NOT replayed: the *_lag1 variables already travel
    * with each resampled row, so they are passed through visit_cov() verbatim.
    * ---------------------------------------------------------------------
    local efron_opt = cond("`efron'" != "", "efron", "")

    if "`wtype'" == "iptw" {
        local wopts "treat(`treat') treat_cov(`treatcov')"
        if "`truncate'" != "" {
            local wopts "`wopts' truncate(`truncate')"
        }
        quietly iivw_weight, id(`newid') time(`timevar') `wopts' ///
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
        * entry() is ignored under nobaseevent, so only replay it otherwise
        if "`nobaseevent'" == "" & "`entry'" != "" {
            local wopts "`wopts' entry(`entry')"
        }
        quietly iivw_weight, id(`newid') time(`timevar') `wopts' ///
            wtype(`wtype') `efron_opt' `nobaseevent' ///
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
        mixed `depvar' `covars' [pw=`weight_var'] if `touse' ///
            || `newid':, `log_opt' `mixedopts'
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
