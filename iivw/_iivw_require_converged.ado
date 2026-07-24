*! _iivw_require_converged Version 2.3.0  2026/07/23
*! Treat a nonconverged model as an estimation failure, not a warning. A model
*! that did not converge has no trustworthy coefficients, so its output must not
*! be predicted from, committed to the data, returned, or stamped as a
*! successful fit. The caller may override deliberately with allownonconverged.
*! Author: Timothy P Copeland, Karolinska Institutet
*! Program class: nclass

program define _iivw_require_converged
    version 16.0
    local __iivw_old_varabbrev = c(varabbrev)
    set varabbrev off
    capture noisily {

    syntax , MODel(string) [ALLOWNONCONVerged]

    if "`allownonconverged'" != "" {
        display as error "warning: the `model' model did not converge"
        * Callers use this branch two ways: a user-supplied allownonconverged,
        * and an internal caller that downgrades a per-group failure rather than
        * aborting a whole diagnostic. Naming the option here told users of the
        * second kind that they had specified something they had not.
        display as text  "  Estimation continues and the result is marked unusable."
        display as text  "  These estimates are not trustworthy: the optimizer never reached"
        display as text  "  a maximum, so the coefficients and standard errors do not solve"
        display as text  "  the estimating equation. The fit is stamped nonconverged and is"
        display as text  "  not usable for the automatic diagnostics."
        exit 0
    }

    display as error "the `model' model did not converge"
    display as error ""
    display as error "  Estimation is stopped. A nonconverged model's coefficients do not"
    display as error "  solve the estimating equation, so predicting from them, weighting"
    display as error "  with them, or reporting them would produce confident nonsense."
    display as error ""
    display as text  "  Check the model specification: collinear predictors, a separated"
    display as text  "  outcome, near-zero weight variance, or too few events per parameter."
    display as text  "  To proceed anyway and mark the result unusable for the automatic"
    display as text  "  diagnostics, specify allownonconverged."
    error 430

    }
    local rc = _rc
    set varabbrev `__iivw_old_varabbrev'
    if `rc' exit `rc'
end
