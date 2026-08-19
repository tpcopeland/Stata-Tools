*! _gcomp_warn_fit_sample_loss Version 1.6.0  2026/08/19
*! Warn when a gcomp component fit omits eligible observations
*! Author: Timothy P Copeland, Karolinska Institutet
*! Program class: nclass

capture program drop _gcomp_warn_fit_sample_loss
program define _gcomp_warn_fit_sample_loss, nclass
    version 16.0
    local _orig_varabbrev = c(varabbrev)
    set varabbrev off
    capture noisily {
        syntax, VARName(name) COMMAND(name) OFFERED(integer) [VISIT(string)]
        local _fit_n = e(N)
        if `_fit_n' < `offered' {
            local _dropped = `offered' - `_fit_n'
            local _visit_label ""
            if `"`visit'"' != "" {
                local _visit_label " (t=`visit')"
            }
            noisily display as error "   Warning: `command' model for `varname'`_visit_label' used `_fit_n' of `offered' eligible observations; `_dropped' rows omitted."
            noisily display as error "       Possible causes include perfect prediction, collinearity, or missing predictor values."
        }
    }
    local rc = _rc
    set varabbrev `_orig_varabbrev'
    if `rc' exit `rc'
end
