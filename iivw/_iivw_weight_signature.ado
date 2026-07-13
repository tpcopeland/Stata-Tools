*! _iivw_weight_signature Version 2.0.0  2026/07/13
*! Sort-invariant fingerprint binding stored weights to the data they describe
*! Author: Timothy P Copeland, Karolinska Institutet
*! Program class: rclass

* Why this exists
* ---------------
* The weight contract used to be a characteristic plus "does the column still
* exist". Nothing stopped a user from dropping rows, editing a covariate, or
* overwriting the weight column between iivw_weight and iivw_fit -- the stored
* specification silently stopped describing the data, and the fit ran anyway
* on weights that no longer belonged to it. rc 0, wrong answer.
*
* This is a fingerprint, NOT a cryptographic hash: distinct datasets can in
* principle collide. It is built to catch accident (an edit, a drop, a merge, a
* re-weight), not to withstand an adversary.
*
* It is deliberately built ONLY from sums, so it is invariant to row order: a
* harmless `sort' or `gsort' between weighting and fitting must not trip it.
* The cross terms sum(w*t), sum(w*k) and sum(w*x_j) are what bind each weight
* to the row it was computed for -- without them, permuting the weight column
* against the key would leave sum(w) and sum(w^2) unchanged and pass.

program define _iivw_weight_signature, rclass
    version 16.0
    local __iivw_old_varabbrev = c(varabbrev)
    set varabbrev off
    capture noisily {

    syntax , ID(varname) TIME(varname numeric) WVar(varname numeric) ///
        [COVars(varlist numeric)]

    * group() rather than the raw id: it accepts a string id, and it numbers by
    * sorted id value, so it does not depend on the row order either.
    tempvar k
    quietly egen long `k' = group(`id')

    tempvar w2 wt wk
    quietly generate double `w2' = `wvar' * `wvar'
    quietly generate double `wt' = `wvar' * `time'
    quietly generate double `wk' = `wvar' * `k'

    quietly count if !missing(`k', `time', `wvar')
    local __iivw_n = r(N)

    quietly levelsof `k', local(__iivw_lv)
    local __iivw_nid : word count `__iivw_lv'

    * %21x is Stata's exact hexadecimal float format: a signature written with
    * %10.0g would round away the very edits it is meant to detect.
    local __iivw_parts ""
    foreach __iivw_v in `wvar' `w2' `wt' `wk' {
        quietly summarize `__iivw_v', meanonly
        local __iivw_parts "`__iivw_parts'|`=string(r(sum), "%21x")'"
    }

    * Bind the construction inputs too. The weights are a deterministic function
    * of the visit covariates, so an edited covariate with an unedited weight
    * column is exactly the stale state this guard is for; sum(w*x_j) moves when
    * x_j does.
    foreach __iivw_x of local covars {
        tempvar wx
        quietly generate double `wx' = `wvar' * `__iivw_x'
        quietly summarize `wx', meanonly
        local __iivw_parts "`__iivw_parts'|`=string(r(sum), "%21x")'"
        drop `wx'
    }

    return local signature "`__iivw_n'|`__iivw_nid'|`wvar'`__iivw_parts'"

    }
    local rc = _rc
    set varabbrev `__iivw_old_varabbrev'
    if `rc' exit `rc'
end
