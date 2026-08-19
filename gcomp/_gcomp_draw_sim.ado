*! _gcomp_draw_sim Version 1.6.0  2026/08/19
*! Fit one gcomp component model and draw its simulated target
*! Author: Timothy P Copeland, Karolinska Institutet
*! Program class: rclass
*! Count-model draw: StataCorp (2025), nbreg manual, pp. 6 and 13-14

capture program drop _gcomp_draw_sim
program define _gcomp_draw_sim, rclass
    version 16.0
    local _orig_varabbrev = c(varabbrev)
    set varabbrev off
    capture noisily {
        syntax, COMMAND(name) TARGET(varname numeric) FITIF(string) ///
            DRAWIF(string) [EQUATION(string) COMMANDOPTS(string) ///
            STRUCTCONDition(string) STRUCTValue(string) CONTEXT(string) ///
            DRAWMODE(name) ERROREXPR(string) PREFILLSOURCE(varname numeric)]

        if !inlist("`command'", "regress", "logit", "mlogit", "ologit", "poisson", "nbreg") {
            noisily display as error "Error: only regress, logit, mlogit, ologit, poisson and nbreg are supported as simulation commands in gcomp."
            exit 198
        }
        if "`drawmode'" == "" local drawmode "stochastic"
        if !inlist("`drawmode'", "stochastic", "mean") {
            noisily display as error "internal error: drawmode() must be stochastic or mean"
            exit 198
        }
        if "`drawmode'" == "mean" & inlist("`command'", "mlogit", "ologit") {
            noisily display as error "internal error: mean simulation is not defined for categorical component models"
            exit 198
        }
        if `"`structcondition'"' != "" & `"`structvalue'"' == "" {
            noisily display as error "internal error: structural condition supplied without a forced value"
            exit 198
        }

        quietly `command' `target' `equation' if `fitif' `commandopts'
        local _fit_N = e(N)
        local _alpha = .
        local _rmse = .

        if "`command'" == "nbreg" {
            if "`e(dispers)'" != "mean" {
                noisily display as error "commands(): nbreg supports only the default NB2 dispersion(mean) model"
                exit 198
            }
            local _alpha = e(alpha)
            if missing(`_alpha') | `_alpha' <= 0 {
                noisily display as error "commands(): nbreg did not return a usable positive alpha for `target'"
                exit 498
            }
        }
        if "`command'" == "regress" local _rmse = e(rmse)

        if `"`structcondition'"' != "" {
            if `"`context'"' == "" local context "structural() for `target'"
            _gcomp_apply_rule, rule(`"`target'=`structvalue'"') ///
                condition(`"if missing(`target') & (`structcondition') & (`drawif')"') ///
                context(`"`context'"')
        }
        if "`prefillsource'" != "" {
            quietly replace `target' = `prefillsource' if missing(`target') & `prefillsource' < .
        }

        if inlist("`command'", "logit", "regress", "poisson", "nbreg") {
            tempvar _pred
            if inlist("`command'", "poisson", "nbreg") {
                quietly predict double `_pred', n
            }
            else {
                quietly predict double `_pred'
            }

            if "`drawmode'" == "mean" {
                quietly replace `target' = `_pred' if (`drawif') & `_pred' < .
            }
            else if "`command'" == "logit" {
                quietly replace `target' = runiform() < `_pred' if (`drawif') & `_pred' < .
            }
            else if "`command'" == "regress" {
                if `"`errorexpr'"' == "" local errorexpr "rnormal(0,1)"
                quietly replace `target' = `_pred' + `_rmse' * (`errorexpr') if (`drawif') & `_pred' < .
            }
            else if "`command'" == "poisson" | `_alpha' <= 1e-8 {
                quietly replace `target' = rpoisson(`_pred') if (`drawif') & `_pred' < .
            }
            else {
                quietly replace `target' = rpoisson(rgamma(1/`_alpha', `_pred' * `_alpha')) if (`drawif') & `_pred' < .
            }
        }
        else {
            local _maxcat = cond("`command'" == "mlogit", e(k_out), e(k_cat))
            tempname _catvals
            if "`command'" == "mlogit" matrix `_catvals' = e(out)
            else matrix `_catvals' = e(cat)

            local _probvars ""
            forvalues _cat = 1/`_maxcat' {
                tempvar _prob
                local _probvars "`_probvars' `_prob'"
            }
            quietly predict double `_probvars'

            tempvar _u _cum1 _cum2
            quietly generate double `_u' = runiform()
            quietly generate double `_cum1' = 0
            quietly generate double `_cum2' = 0
            forvalues _cat = 1/`_maxcat' {
                local _pcat : word `_cat' of `_probvars'
                local _catval = `_catvals'[1, `_cat']
                quietly replace `_cum2' = `_cum2' + `_pcat'
                quietly replace `target' = `_catval' if `_u' > `_cum1' & `_u' < `_cum2' & ///
                    `_cum1' < . & `_cum2' < . & (`drawif')
                quietly replace `_cum1' = `_cum2'
            }
        }
    }
    local rc = _rc
    set varabbrev `_orig_varabbrev'
    if `rc' exit `rc'

    return scalar fit_N = `_fit_N'
    return scalar alpha = `_alpha'
    return scalar rmse = `_rmse'
end
