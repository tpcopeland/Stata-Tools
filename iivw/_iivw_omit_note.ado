*! _iivw_omit_note Version 1.0.1  2026/10/30
*! Name the terms a nuisance model omitted, after a fit run quietly
*! Author: Timothy P Copeland, Karolinska Institutet
*! Program class: nclass

* iivw_weight fits its visit-intensity, stabilization and treatment models
* quietly under nolog, which also hides the estimator's own "omitted because of
* collinearity" notes. An omitted covariate changes the model the weights come
* from, so it is a warning the user must still see. The caller invokes this
* with a noisily prefix right after the fit; under a refit bootstrap the whole
* iivw_weight call is quieted by its caller, so nothing prints per replicate.

program define _iivw_omit_note, nclass
    version 16.0
    local __iivw_old_varabbrev = c(varabbrev)
    set varabbrev off
    capture noisily {

    syntax , MODel(string)

    tempname b om
    matrix `b' = e(b)
    quietly _ms_omit_info `b'
    if r(k_omit) > 0 {
        matrix `om' = r(omit)
        local names : colnames `b'
        local omitted ""
        forvalues j = 1/`=colsof(`b')' {
            if `om'[1, `j'] {
                local nm : word `j' of `names'
                local nm = regexr("`nm'", "^o\.", "")
                local omitted "`omitted' `nm'"
            }
        }
        local omitted : list retokenize omitted
        display as text "note: the `model' model omitted " ///
            as result "`omitted'" as text " (collinear or no variation);"
        display as text "  the weights come from the model without it"
    }

    }
    local rc = _rc
    set varabbrev `__iivw_old_varabbrev'
    if `rc' exit `rc'
end
