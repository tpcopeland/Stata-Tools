*! _iivw_bs_refit Version 2.0.1  2026/07/21
*! Bootstrap wrapper for iivw_fit, refitweights: recomputes IIW/IPTW/FIPTIW
*! weights from scratch on each resampled panel before refitting the outcome
*! model, so the bootstrap propagates weight-estimation uncertainty.
*! Author: Timothy P Copeland, Karolinska Institutet
*! Program class: eclass

program define _iivw_bs_refit, eclass
    version 16.0
    local __iivw_old_varabbrev = c(varabbrev)
    set varabbrev off

    * ---------------------------------------------------------------------
    * Snapshot the ENTIRE _iivw_ characteristic namespace.
    *
    * The iivw_weight call below rewrites the stored weighting contract with
    * this replicate's resampled (idcluster) id. Bootstrap's observed pass runs
    * on the live dataset, so without this snapshot the bogus id would leak into
    * the user's _dta characteristics.
    *
    * The pre-release build snapshotted a hand-maintained LIST of names, and it was
    * incomplete:
    * _iivw_lagvars, _iivw_wsig and _iivw_nonconverged were not on it. A probe on
    * 2026-07-14 saw _iivw_lagvars go from `x' to blank across a successful
    * `iivw_fit, bootstrap(3) refitweights' -- and _iivw_check_weighted still
    * returned 0 afterwards, because the signature it would have checked against
    * had been blanked too. The contract silently stopped describing the data and
    * the guard that exists to catch that had been erased by the same bug.
    *
    * A list you have to remember to extend is a list that will be wrong. Read
    * the names from the data instead, so a field added tomorrow is snapshotted
    * without anyone having to think about it.
    * ---------------------------------------------------------------------
    local __iivw_allchars : char _dta[]
    local __iivw_csnap_names ""
    foreach c of local __iivw_allchars {
        if substr("`c'", 1, 6) == "_iivw_" {
            local __iivw_csnap_names "`__iivw_csnap_names' `c'"
        }
    }
    local __iivw_ci 0
    foreach c of local __iivw_csnap_names {
        local ++__iivw_ci
        local __iivw_csnap`__iivw_ci' : char _dta[`c']
    }

    capture noisily {
    syntax varlist(numeric min=1) [if] [in], ///
        NEWID(varname) TIMEvar(varname) WTYPE(string) PREFIX(string) ///
        MODel(string) ///
        [PANELid(varname) OUTCOMETOUSE(varname) ///
         VISITcov(string) LAGvars(string) TREAT(string) TREATcov(string) ///
         STABcov(string) EFRon BASEline(string) ///
         TRUNCVisit(string) TRUNCTreat(string) TRUNCFinal(string) ///
         ENTRY(string) ///
         CENSor(string) MAXfu(string) ENDATLASTvisit ///
         ALLOWMISSINGWeights EXPERIMENTALNOTREATVISit ///
         FAMily(string) LINk(string) ///
         GEEopts(string asis) MIXEDopts(string asis) noLOG]

    * ---------------------------------------------------------------------
    * The RESAMPLING FRAME, captured before any varlist markout.
    *
    * bootstrap does not resample the rows matching the prefix's `if'. It runs
    * this program once on the observed data and then resamples THE e(sample)
    * THAT RUN POSTS. So the frame is whatever e(sample) says it is, and an
    * e(sample) of just the outcome rows sends every replicate back to the
    * truncated panel no matter what `if' the prefix was given.
    *
    * novarlist is the point: the frame must not be marked out on depvar or the
    * outcome covariates. A visit with a missing outcome is still a visit the
    * weight model consumed, and it has to survive into the draws.
    * ---------------------------------------------------------------------
    tempvar frame_touse
    marksample frame_touse, novarlist

    marksample touse

    * ---------------------------------------------------------------------
    * Two samples, deliberately.
    *
    * The rows handed to this program are the WEIGHT-model frame: the whole
    * resampled visit panel, including visits whose outcome is missing. Those
    * rows have to be here, because the visit-intensity model is fitted on
    * them -- a visit is an event in the counting process whether or not its
    * outcome was recorded.
    *
    * outcometouse() carries the caller's outcome-ELIGIBILITY marker (its
    * if/in, depvar, outcome covariates, cluster and time), which travels with
    * the resampled rows because it is an ordinary column. It restricts the
    * outcome fit only, and never the weight refit above it.
    *
    * Weight AVAILABILITY is deliberately not part of that marker: it is
    * recomputed per draw, so it is applied further down (markout on the
    * refitted weight) from THIS draw's weights, not frozen at the observed
    * sample's.
    * ---------------------------------------------------------------------
    if "`outcometouse'" != "" {
        quietly replace `touse' = 0 if `outcometouse' == 0 | missing(`outcometouse')
    }

    * Same pass-through guard as iivw_fit (IIVW-B08): no variance/resampling
    * token in geeopts()/mixedopts() may reach the inner glm inside a draw.
    * noirls unconditionally: this program only ever runs inside a bootstrap,
    * so the e(converged) gate below is always live. iivw_fit refuses irls
    * before it gets here; this is the second half of the same guard, for the
    * day something else calls this wrapper.
    _iivw_check_passthru, optname(geeopts)  value(`"`geeopts'"')  noirls
    _iivw_check_passthru, optname(mixedopts) value(`"`mixedopts'"') noirls

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
    *
    * DEFENSIVE ONLY under the current contract: iivw_fit refuses refitweights
    * when cluster() differs from the panel id, so the two branches below are
    * equivalent on every path that can actually reach this program today. It is
    * kept rather than collapsed because the identical construction IS live in
    * _iivw_bs_estimate, where cluster() may sit above the panel, and because
    * the day that refusal is lifted this is the behaviour that has to be here.
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
    *
    * lagvars() IS replayed, from the RAW source variables, inside each draw.
    *
    * The pre-release build did not do this: it passed the precomputed *_lag1 straight
    * through visit_cov(), on the reasoning that they travel with the resampled
    * rows anyway. They do -- but they carry the OBSERVED panel's lag structure,
    * not the resampled one, and that is wrong in two ways at once.
    *
    *   1. On a terminal censoring interval the correct lagged value is the
    *      source variable's value AT the last visit. iivw_weight builds that
    *      when it constructs the censoring row (it copies the last visit's row,
    *      then overwrites the lag column with the source value). A precomputed
    *      *_lag1 column copied onto that row instead carries the value from TWO
    *      visits back.
    *   2. Lags could never be rebuilt WITHIN a resampled subject. The bootstrap
    *      is supposed to propagate the uncertainty in the lag construction as
    *      well as in the coefficients; freezing the lags at their observed-data
    *      values removes that source of variation from every replicate.
    *
    * Passing the raw sources to lagvars() lets iivw_weight rebuild both, per
    * draw, with the same code that built the observed weights.
    *
    * The end-of-follow-up contract IS replayed. Without it
    * the replicates would refit the visit-intensity model on a truncated risk
    * set while the observed estimate used the full one -- bootstrapping a
    * different estimator than the one being reported.
    *
    * allowmissingweights is replayed too. A draw that happens to lose a row to
    * a missing covariate must not hard-error out of a bootstrap the user already
    * acknowledged would be complete-case; and if they did NOT acknowledge it,
    * the observed pass has already errored before any replicate runs.
    * ---------------------------------------------------------------------
    * The FIPTIW visit model carries treat() by construction, so a plain replay
    * reproduces it without being told. The OPT-OUT is what has to travel: a
    * replicate that silently re-added treatment while the observed pass omitted
    * it would bootstrap an estimator the user never ran.
    local efron_opt = cond("`efron'" != "", "efron", "")
    local amw_opt = cond("`allowmissingweights'" != "", "allowmissingweights", "")
    local ntv_opt = ///
        cond("`experimentalnotreatvisit'" != "", "experimentalnotreatvisit", "")

    * The trimming spec is replayed by PERCENTILE, not by the observed cutpoint.
    * A bootstrap draw is a different sample: its 99th percentile is a different
    * number, and clipping it at the OBSERVED sample's cutpoint would freeze part
    * of the estimator at its observed-data value and remove that source of
    * variation from every replicate. The estimator is "fit, then clip at the
    * pth percentile of THIS sample" -- so that is what each draw must do.
    local trim_opts ""
    if "`truncvisit'" != "" local trim_opts "`trim_opts' truncvisit(`truncvisit')"
    if "`trunctreat'" != "" local trim_opts "`trim_opts' trunctreat(`trunctreat')"
    if "`truncfinal'" != "" local trim_opts "`trim_opts' truncfinal(`truncfinal')"

    if "`wtype'" == "iptw" {
        local wopts "treat(`treat') treat_cov(`treatcov')`trim_opts'"
        quietly iivw_weight, id(`_bs_subj') time(`timevar') `wopts' ///
            wtype(iptw) generate(`prefix') replace nolog `amw_opt'
    }
    else {
        * iivw or fiptiw: visit-intensity model (+ treatment model for fiptiw)
        local wopts "visit_cov(`visitcov')"
        if "`lagvars'" != "" {
            local wopts "`wopts' lagvars(`lagvars')"
        }
        if "`treat'" != "" {
            local wopts "`wopts' treat(`treat') treat_cov(`treatcov')"
        }
        if "`stabcov'" != "" {
            local wopts "`wopts' stabcov(`stabcov')"
        }
        local wopts "`wopts'`trim_opts'"
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
            generate(`prefix') replace nolog `amw_opt' `ntv_opt'
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

    * The outcome fit must have CONVERGED to count as a replicate; see
    * _iivw_require_draw_converged.ado for why, why allownonconverged is not
    * honoured inside a draw, and why a missing e(converged) fails closed.
    _iivw_require_draw_converged, model(`model')

    * ---------------------------------------------------------------------
    * Declare the frame, not the outcome sample, as e(sample).
    *
    * This is what actually makes the resampling frame the visit panel: see
    * the novarlist note at the top. bootstrap reads e(sample) from the
    * observed evaluation and draws clusters from exactly those rows, so
    * leaving glm's e(sample) in place would hand every replicate the
    * outcome-only panel again -- which is the defect, restated.
    *
    * e(sample) here means "rows this replicate consumed", and the weight
    * model consumed the whole panel. The coefficient vector is untouched: the
    * glm above still fitted on `touse' alone. iivw_fit re-posts the
    * user-facing e(N) from the observed outcome fit, so the reported N stays
    * the number of outcome rows and does not become the panel row count.
    * ---------------------------------------------------------------------
    ereturn repost, esample(`frame_touse')

    }
    local rc = _rc

    * ---------------------------------------------------------------------
    * Restore the snapshotted weighting contract. Runs on success and on error.
    *
    * Blank the whole _iivw_ namespace FIRST, then rewrite the snapshot. Writing
    * the snapshot back on its own would restore every field that existed before
    * -- but would leave any field the replicate's iivw_weight call INVENTED
    * sitting there, describing a contract that no longer exists. Clearing first
    * makes the restoration exact in both directions: nothing lost, nothing added.
    * ---------------------------------------------------------------------
    local __iivw_nowchars : char _dta[]
    foreach c of local __iivw_nowchars {
        if substr("`c'", 1, 6) == "_iivw_" {
            char _dta[`c'] ""
        }
    }
    local __iivw_ci 0
    foreach c of local __iivw_csnap_names {
        local ++__iivw_ci
        char _dta[`c'] "`__iivw_csnap`__iivw_ci''"
    }

    set varabbrev `__iivw_old_varabbrev'
    if `rc' exit `rc'
end
