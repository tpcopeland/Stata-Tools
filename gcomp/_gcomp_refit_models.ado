*! _gcomp_refit_models Version 1.3.0  2026/06/14
*! Refit gcomp component models once on the analytic sample and est store them
*! Author: Timothy P Copeland, Karolinska Institutet
*! Program class: rclass

/*
DESCRIPTION:
    Faithful one-time refit of the per-variable parametric component models that
    gcomp simulates from. Called by gcomp (savemodels/showmodels) AFTER the
    analytic sample is finalized in memory but BEFORE the rename/reshape, so the
    fits use the same command/equation/sample gcomp used in simulation.

    For mediation, gcomp fits each model on the observed rows (if int_no==0),
    which equals the full in-memory analytic sample here, so coefficients match
    exactly. For time-varying, this refit is pooled across visits; faithful
    per-visit columns are deferred.

    Models whose predictors are not available at fit time (e.g. lagged/derived
    variables built only inside the simulation loop) are skipped gracefully and
    reported in r(skipped); they are never silently dropped.

RETURNS:
    r(n_models)         number of models successfully captured
    r(model_names)      stub_1 stub_2 ... (stored-estimate names, contiguous)
    r(model_cmds)       per-model command (logit/regress/mlogit/ologit)
    r(model_depvars)    per-model dependent variable
    r(model_eq_k)       prediction equation for captured model k
    r(skipped)          depvars of models that could not be refit
*/

capture program drop _gcomp_refit_models
program define _gcomp_refit_models, rclass
    version 16.0
    local _orig_varabbrev = c(varabbrev)
    set varabbrev off
    capture noisily {
        syntax , VARS(string) COMmands(string) EQuations(string) STUB(name) ///
            [ANALYSIS(string) Pooled]

        * Clear any prior stored estimates from this stub family
        forvalues _i = 1/50 {
            capture estimates drop `stub'_`_i'
        }

        local nvar : word count `vars'
        if `nvar' == 0 {
            return scalar n_models = 0
            return local model_names ""
            exit
        }

        * Detangle commands/equations against the simulation variable list
        _gcomp_detangle "`commands'" command "`vars'"
        forvalues i = 1/`nvar' {
            local command`i' "${S_`i'}"
        }
        _gcomp_detangle "`equations'" equation "`vars'"
        forvalues i = 1/`nvar' {
            local equation`i' "${S_`i'}"
        }
        * Clean up the detangle globals we touched
        forvalues i = 1/`nvar' {
            global S_`i'
        }

        local _kept 0
        local _names ""
        local _cmds ""
        local _depvars ""
        local _skipped ""

        forvalues i = 1/`nvar' {
            local _v   : word `i' of `vars'
            local _cmd "`command`i''"
            local _eq  "`equation`i''"

            * Skip models with no command or no equation (e.g. mediation junk slot)
            if "`_cmd'" == "" | "`_eq'" == "" {
                continue
            }
            if !inlist("`_cmd'", "logit", "regress", "mlogit", "ologit") {
                continue
            }

            * mlogit/ologit base outcome must mirror the simulation (lowest level)
            local _opts ""
            if "`_cmd'" == "mlogit" {
                quietly levelsof `_v' if `_v' < ., local(_lev)
                local _base : word 1 of `_lev'
                if "`_base'" != "" local _opts ", baseoutcome(`_base')"
            }

            * Refit on the analytic sample; skip gracefully if predictors are
            * unavailable at this stage (lagged/derived vars built in the loop).
            capture quietly `_cmd' `_v' `_eq' `_opts'
            if _rc {
                local _skipped "`_skipped' `_v'"
                continue
            }

            local ++_kept
            capture estimates drop `stub'_`_kept'
            estimates store `stub'_`_kept', title("`_v' (`_cmd')")

            local _names   "`_names' `stub'_`_kept'"
            local _cmds    "`_cmds' `_cmd'"
            local _depvars "`_depvars' `_v'"
            return local model_eq_`_kept' "`_eq'"
        }

        return scalar n_models = `_kept'
        return local model_names   "`=strtrim("`_names'")'"
        return local model_cmds    "`=strtrim("`_cmds'")'"
        return local model_depvars "`=strtrim("`_depvars'")'"
        return local skipped       "`=strtrim("`_skipped'")'"
    }
    local rc = _rc
    set varabbrev `_orig_varabbrev'
    if `rc' exit `rc'
end
