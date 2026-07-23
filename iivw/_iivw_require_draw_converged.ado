*! _iivw_require_draw_converged Version 2.2.1  2026/07/23
*! Reject a nonconverged outcome fit inside a bootstrap replicate. Shared by
*! _iivw_bs_estimate (fixed-weight draws) and _iivw_bs_refit (refit draws).
*! Author: Timothy P Copeland, Karolinska Institutet
*! Program class: nclass

* Why this exists
* ---------------
* glm and mixed both return a numeric coefficient vector after printing
* "convergence not achieved". bootstrap has no way to tell that apart from a
* real fit: it sees numbers, books the draw as completed, and folds a
* non-solution of the estimating equation into the variance. An adversarial
* binomial model capped at one iteration printed four nonconvergence messages
* and still returned rc=0 with 3 completed / 0 failed replicates.
*
* Failing here is what makes the package's failed-replicate accounting mean
* something. It gates the observed evaluation too -- bootstrap runs the wrapper
* once on the real data before it starts resampling.
*
* allownonconverged is deliberately NOT honoured here. That option exists so a
* user can look at a warning and decide; a replicate has no user reading it,
* and an interval built from fits nobody inspected is not the thing the option
* was for. Nuisance-model nonconvergence is still governed by iivw_weight's
* own gate, and the user-facing single fit by _iivw_require_converged.
*
* WHY THIS IS ONE HELPER AND NOT TWO INLINE COPIES
* -----------------------------------------------
* The two wrappers carried textually identical copies of this check. A review
* on 2026-07-21 found the copies had already begun to diverge in their comment
* text, and this package has been bitten before by a helper duplicated into two
* files where each copy grew a guard the other lacked. One definition, two
* callers.
*
* WHAT `missing(e(converged))' MEANS -- AND DOES NOT MEAN
* ------------------------------------------------------
* A missing e(converged) fails closed: `. == 0' is false, so testing only
* `== 0' would wave through exactly the paths nobody anticipated.
*
* But "fails closed" is not the same as "cannot happen". glm under its DEFAULT
* ML optimizer sets e(converged); glm under `irls' does NOT set it at all, even
* on a perfectly converged fit (verified 2026-07-21: a clean gaussian
* `glm y x, irls' leaves e(converged) missing). An earlier build's comment here
* claimed "both engines set it", which was false as written, and the
* consequence was that `iivw_fit ..., bootstrap(5) geeopts(irls)' died at
* r(430) reporting nonconvergence of a model that had converged.
*
* That path is now refused at parse time by _iivw_check_passthru's noirls
* option, with a message that names the real reason, so this gate no longer
* has to carry a case it cannot describe accurately. This note stays because
* the next engine or pass-through option that omits e(converged) will land
* here first, and the right repair is another parse-time refusal -- not
* loosening this test.

program define _iivw_require_draw_converged
    version 16.0
    local __iivw_old_varabbrev = c(varabbrev)
    set varabbrev off
    capture noisily {

    syntax [, MODel(string)]

    local _conv = e(converged)
    if missing(`_conv') | `_conv' == 0 {
        display as error "outcome model did not converge in this bootstrap replicate"
        if "`model'" != "" {
            display as error "  engine: `model'"
        }
        error 430
    }

    }
    local rc = _rc
    set varabbrev `__iivw_old_varabbrev'
    if `rc' exit `rc'
end
