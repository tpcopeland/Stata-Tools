*! _iivw_fit_p Version 4.3.1  2026/09/28
*! predict for iivw_fit: refuses generated design columns that no longer
*! belong to the fit in e(), then hands off to the underlying model's predict.
*! Author: Timothy P Copeland, Karolinska Institutet
*! Program class: nclass

* Why this exists
* ---------------
* iivw_fit builds its own design columns -- categorical-time dummies, time
* powers, splines, categorical dummies, interactions -- under names that
* depend only on position (`_iivw_tcat_1'). A later fit with `replace' can
* reuse such a name for a DIFFERENT column. Stored estimates keep their
* coefficients but not the columns, so after `estimates restore' the
* underlying glm/mixed predict read whatever the column now holds and returned
* changed predictions at rc 0 (audit F03: up to 1.019 on the audit fixture,
* and 50 previously available predictions went missing).
*
* Every column a fit generates is stamped with that fit's token, and e() records
* the token and the columns. A column that is missing, or carries another fit's
* token, means the design this estimate was fitted on is not in memory: refuse,
* rather than predict from a column whose meaning changed.

program define _iivw_fit_p
    version 16.0
    local __iivw_old_varabbrev = c(varabbrev)
    set varabbrev off
    capture noisily {
        if "`e(iivw_cmd)'" != "iivw_fit" | "`e(iivw_predict)'" == "" {
            display as error "last estimates not found"
            error 301
        }
        local __iivw_tok "`e(iivw_design_token)'"
        local __iivw_stale ""
        if "`__iivw_tok'" != "" {
            foreach __iivw_v in `e(iivw_design_vars)' {
                capture confirm variable `__iivw_v', exact
                if _rc {
                    local __iivw_stale "`__iivw_stale' `__iivw_v'(missing)"
                    continue
                }
                local __iivw_vt : char `__iivw_v'[_iivw_fit_token]
                if "`__iivw_vt'" != "`__iivw_tok'" {
                    local __iivw_stale "`__iivw_stale' `__iivw_v'"
                }
            }
        }
        if "`__iivw_stale'" != "" {
            display as error "predict: the design columns of these estimates are no longer in memory"
            display as error "  regenerated or dropped by a later iivw_fit:`__iivw_stale'"
            display as error "  the coefficients refer to the columns this fit built; predicting"
            display as error "  from columns another fit rebuilt would silently change the result."
            display as error "  Refit this model (or restore the data it was fitted on) first."
            error 459
        }
    }
    local rc = _rc
    set varabbrev `__iivw_old_varabbrev'
    if `rc' exit `rc'

    `e(iivw_predict)' `0'
end
