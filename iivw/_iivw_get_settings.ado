*! _iivw_get_settings Version 2.0.1  2026/07/21
*! The canonical weighting specification: the one place any consumer reads the
*! contract that iivw_weight committed.
*! Author: Timothy P Copeland, Karolinska Institutet

* Every consumer that refits, replays, or reports on the weights -- iivw_fit,
* _iivw_bs_refit, iivw_balance, iivw_exogtest -- reads the specification from
* here and nowhere else. A consumer that reconstructs part of the spec from its
* own options is describing a different estimator than the one that produced the
* weights it is reporting on.
*
* These fields exist because a spec that stores only the UNION of the raw visit
* covariates and the generated lags is not sufficient to REPLAY
* the weighting:
*
*   visit_cov_raw  the user's visit_cov() varlist, separate from the generated
*                  lag columns. Storing only their union (visit_covars) means
*                  a replay could not tell a raw covariate from a *_lag1 column
*                  and passed the precomputed lags through as if they were raw
*                  inputs -- which is exactly why the bootstrap could not
*                  regenerate lags inside a resampled subject.
*   lag_names      the generated *_lag1 columns, so a consumer can bind them
*                  without re-deriving the naming rule.
*   owned          every variable name this package owns under the contract.
*   allowmissingweights
*                  whether the user acknowledged rows that carry no weight.

program define _iivw_get_settings, rclass
    version 16.0
    local __iivw_old_varabbrev = c(varabbrev)
    set varabbrev off
    capture noisily {

    local id         : char _dta[_iivw_id]
    local time       : char _dta[_iivw_time]
    local weighttype : char _dta[_iivw_weighttype]
    local weight_var : char _dta[_iivw_weight_var]
    local prefix     : char _dta[_iivw_prefix]
    local iw_var     : char _dta[_iivw_iw_var]
    local tw_var     : char _dta[_iivw_tw_var]
    local ps_var     : char _dta[_iivw_ps_var]
    local treat      : char _dta[_iivw_treat]
    local treat_covars : char _dta[_iivw_treat_covars]
    local ps_estimand : char _dta[_iivw_ps_estimand]
    local contract_version : char _dta[_iivw_contract_version]
    local visit_covars : char _dta[_iivw_visit_covars]
    local baseevent  : char _dta[_iivw_baseevent]
    local stabcov    : char _dta[_iivw_stabcov]
    local truncate   : char _dta[_iivw_truncate]
    local truncvisit : char _dta[_iivw_truncvisit]
    local trunctreat : char _dta[_iivw_trunctreat]
    local truncfinal : char _dta[_iivw_truncfinal]
    local tv_locut   : char _dta[_iivw_tv_locut]
    local tv_hicut   : char _dta[_iivw_tv_hicut]
    local tt_locut   : char _dta[_iivw_tt_locut]
    local tt_hicut   : char _dta[_iivw_tt_hicut]
    local iw_raw_var : char _dta[_iivw_iw_raw_var]
    local tw_raw_var : char _dta[_iivw_tw_raw_var]
    local efron      : char _dta[_iivw_efron]
    local entry      : char _dta[_iivw_entry]
    local censor_mode : char _dta[_iivw_censor_mode]
    local censor_var  : char _dta[_iivw_censor_var]
    local maxfu       : char _dta[_iivw_maxfu]
    local lagvars     : char _dta[_iivw_lagvars]
    local nonconverged : char _dta[_iivw_nonconverged]
    local fit_nonconverged : char _dta[_iivw_fit_nonconverged]
    local visit_cov_raw : char _dta[_iivw_visit_cov_raw]
    local lag_names     : char _dta[_iivw_lag_names]
    local owned         : char _dta[_iivw_owned]
    local allowmissingweights : char _dta[_iivw_allowmissingweights]
    local treat_in_visit : char _dta[_iivw_treat_in_visit]
    local wsig          : char _dta[_iivw_wsig]

    if "`prefix'" == "" local prefix "_iivw_"

    return local id "`id'"
    return local time "`time'"
    return local weighttype "`weighttype'"
    return local weight_var "`weight_var'"
    return local prefix "`prefix'"
    return local iw_var "`iw_var'"
    return local tw_var "`tw_var'"
    return local ps_var "`ps_var'"
    return local treat "`treat'"
    return local treat_covars "`treat_covars'"
    return local ps_estimand "`ps_estimand'"
    return local contract_version "`contract_version'"
    return local visit_covars "`visit_covars'"
    return local baseevent "`baseevent'"
    return local stabcov "`stabcov'"
    return local truncate "`truncate'"

    * Component-specific trimming. The CUTPOINTS travel alongside the percentiles
    * because a consumer that refits the visit model cannot reproduce the analysis
    * weight from the percentiles alone -- its refit sits on a different
    * distribution, so the same percentile lands on a different number. Clipping
    * at the stored cutpoints is the only way to describe the weight the outcome
    * model actually used.
    return local truncvisit "`truncvisit'"
    return local trunctreat "`trunctreat'"
    return local truncfinal "`truncfinal'"
    return local tv_locut "`tv_locut'"
    return local tv_hicut "`tv_hicut'"
    return local tt_locut "`tt_locut'"
    return local tt_hicut "`tt_hicut'"
    return local iw_raw_var "`iw_raw_var'"
    return local tw_raw_var "`tw_raw_var'"
    return local efron "`efron'"
    return local entry "`entry'"

    * The risk-set specification. Any consumer that refits the visit-intensity
    * model must replay this, or it describes a different estimator than the one
    * that produced the weights it is reporting on.
    return local censor_mode "`censor_mode'"
    return local censor_var "`censor_var'"
    return local maxfu "`maxfu'"

    * Source variables behind the generated lag columns. Needed to give a
    * rebuilt censoring row the covariate value it actually had at the last
    * visit; see the note where iivw_weight writes this characteristic.
    return local lagvars "`lagvars'"

    * The raw visit-model covariates, kept apart from the generated lag columns.
    * A replay must pass THESE to visit_cov() and the lag SOURCES to lagvars(),
    * so that each resampled subject rebuilds its own lags. Handing the
    * precomputed *_lag1 columns to visit_cov() carries one subject's history
    * into another's, and on a terminal censoring interval it carries the value
    * from two visits back instead of the last observed one.
    return local visit_cov_raw "`visit_cov_raw'"
    return local lag_names "`lag_names'"

    * Every variable name the package owns under this contract, and the
    * signature that binds the contract to the data.
    return local owned "`owned'"
    return local wsig "`wsig'"

    * Rows that carry no final weight, deliberately accepted by the user. The
    * analysis is complete-case in that case, and every consumer should say so.
    return local allowmissingweights "`allowmissingweights'"

    * Whether treat() sits in the visit-intensity denominator. Under the supported
    * FIPTIW contract it always does; 0 means the user took the experimental
    * opt-out, and a replay that does not reproduce that opt-out would refit a
    * DIFFERENT visit model than the one the reported weights came from.
    return local treat_in_visit "`treat_in_visit'"

    * A nuisance model (visit-intensity, stabilization, or treatment) that the
    * user accepted nonconverged via allownonconverged. The weights it produced
    * do not solve their estimating equation, so a diagnostic must not issue a
    * verdict on them. Kept separate from the outcome-model stamp: the two taint
    * different things and a converged outcome fit must not clear a bad weight.
    return local nonconverged "`nonconverged'"
    return local fit_nonconverged "`fit_nonconverged'"

    }
    local rc = _rc
    set varabbrev `__iivw_old_varabbrev'
    if `rc' exit `rc'
end
