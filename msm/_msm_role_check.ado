*! _msm_role_check Version 1.2.3  2026/07/17
*! Central structural-role validator for marginal structural models
*! Author: Timothy P Copeland
*! Program class: rclass (returns results in r())

/*
Syntax:
  _msm_role_check , [ID(varname) PERiod(varname) TREATment(varname) ///
      OUTcome(varname) CENsor(varname) EXPosure(varname) ///
      PREDictors(varlist) ]

Purpose (audit A07):
  Enforce that the structural roles of an MSM specification do not overlap and
  that predictor lists do not contain their own dependent/structural variables.
  Overlapping roles let an outcome leak into a model, make a treatment
  deterministically predicted, or fit a causally meaningless model that still
  returns rc 0.

Rules enforced:
  1. The single-variable structural roles -- id, period, treatment, outcome,
     censor, exposure -- must be pairwise distinct. The same variable may not
     fill two structural roles.
  2. No predictor (predictors()) may coincide with any structural role
     variable. Predictors are confounders/covariates and must never include the
     id, period, treatment, outcome, censor, or exposure they help model.

Any violation exits 198 with a targeted message naming the two roles and the
offending variable. Callers run this after syntax parsing and before any
model-building work.
*/

program define _msm_role_check, rclass
    version 16.0
    local _orig_varabbrev = c(varabbrev)
    set varabbrev off
    capture noisily {
        syntax , [ID(varname) PERiod(varname) TREATment(varname) ///
            OUTcome(varname) CENsor(varname) EXPosure(varname) ///
            PREDictors(varlist)]

        * Assemble the structural single-variable roles that were supplied.
        local _rolenames id period treatment outcome censor exposure
        local _present ""
        foreach _r of local _rolenames {
            if "``_r''" != "" local _present "`_present' `_r'"
        }

        * Rule 1: pairwise-distinct structural roles.
        local _n : word count `_present'
        forvalues _i = 1/`_n' {
            local _ri : word `_i' of `_present'
            local _vi "``_ri''"
            local _j = `_i' + 1
            forvalues _k = `_j'/`_n' {
                local _rk : word `_k' of `_present'
                local _vk "``_rk''"
                if "`_vi'" == "`_vk'" {
                    display as error ///
                        "the same variable `_vi' cannot be both `_ri'() and `_rk'()"
                    exit 198
                }
            }
        }

        * Rule 2: predictors must not coincide with any structural role.
        if "`predictors'" != "" {
            local _preds : list retokenize predictors
            local _preds : list uniq _preds
            foreach _p of local _preds {
                foreach _r of local _present {
                    if "`_p'" == "``_r''" {
                        display as error ///
                            "predictor `_p' is the `_r' variable and cannot also be a covariate"
                        exit 198
                    }
                }
            }
        }
    }
    local rc = _rc
    set varabbrev `_orig_varabbrev'
    if `rc' exit `rc'
end
