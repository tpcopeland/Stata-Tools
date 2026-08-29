*! _finegray_weight_var Version 1.3.0  2026/08/29
*! Rebuild the fit's design-weight column from e(wexp) for post-estimation
*! Author: Timothy P Copeland, Karolinska Institutet
*! Program class: rclass (internal)

* Fills `wname' -- a tempvar name the caller has already reserved -- with the
* fit's weight expression e(wexp) evaluated over `touse', and returns the
* engine's weight-type code in r(wtype): 1 pweight, 2 fweight.  Refuses any
* other e(wtype), and refuses a weight that is missing or non-positive on a
* row of the estimation sample.
*
* THE REBUILT COLUMN IS RECONCILED AGAINST THE FIT, NOT ONLY SIGNED.
* e(datasignature) covers the VARIABLES the expression names, and _n/_N are
* refused at fit time; but a scalar, an e() or c() value, a subscript such as
* w[1] or a random draw inside the expression is not a variable, so a change
* to it -- or, for the subscript, a re-sort -- re-evaluates e(wexp) into a
* DIFFERENT column at rc 0.  Measured 2026-08-29 (independent review): the
* CIF moved 4.6e-4 for a changed scalar and 2.4e-4 for a re-sorted w[1],
* both at rc 0.  So the column is first rebuilt over e(sample) and its total
* compared with e(sum_w), the total the fit recorded over the same rows; a
* mismatch is refused r(459).  The total is order-invariant, so a plain
* re-sort of a variable weight passes, and it moves for every member of the
* class above short of a change that leaves the sum untouched to 1e-10.
*
* One place, so that finegray_cif, finegray_predict, finegray_phtest and
* _finegray_resolve_baseline agree on what the weight column IS.

program define _finegray_weight_var, rclass
    version 16.0
    local _orig_varabbrev = c(varabbrev)
    set varabbrev off
    capture noisily {
        syntax , wname(name) touse(name)

        local _wt `"`e(wtype)'"'
        if "`_wt'" == "pweight"      local _code = 1
        else if "`_wt'" == "fweight" local _code = 2
        else {
            display as error "internal error: e(wtype) is `_wt', not pweight or fweight"
            exit 498
        }

        * Reconciliation over the estimation sample, whatever `touse' the
        * caller passed (finegray_predict without ci/schoenfeld predicts over
        * the user's if/in, a subset).
        tempvar _es _chk
        quietly gen byte `_es' = e(sample)
        quietly generate double `_chk' `e(wexp)' if `_es'
        quietly count if `_es' & (missing(`_chk') | `_chk' <= 0)
        if r(N) > 0 {
            display as error "the fit's weights cannot be rebuilt from e(wexp)"
            display as error "`r(N)' estimation-sample observation(s) now carry a missing or"
            display as error "non-positive weight; re-run {bf:finegray} before this post-estimation command"
            exit 459
        }
        quietly summarize `_chk' if `_es', meanonly
        if missing(e(sum_w)) | reldif(r(sum), e(sum_w)) > 1e-10 {
            display as error "the weights rebuilt from e(wexp) do not reproduce the fit's weights"
            display as error "their total over e(sample) is " %12.0g r(sum) ///
                " where the fit recorded e(sum_w) = " %12.0g e(sum_w)
            display as error "something the weight expression reads -- a scalar, an e() or c() value,"
            display as error "a subscript such as w[1] -- has changed since the fit (or the data were"
            display as error "re-sorted under a subscript); re-run {bf:finegray} before this post-estimation command"
            exit 459
        }

        quietly generate double `wname' `e(wexp)' if `touse'
        quietly count if `touse' & (missing(`wname') | `wname' <= 0)
        if r(N) > 0 {
            display as error "the fit's weights cannot be rebuilt from e(wexp)"
            display as error "`r(N)' observation(s) in the prediction sample carry a missing or"
            display as error "non-positive weight; re-run {bf:finegray} before this post-estimation command"
            exit 459
        }
        return scalar wtype = `_code'
    }
    local rc = _rc
    set varabbrev `_orig_varabbrev'
    if `rc' exit `rc'
end
