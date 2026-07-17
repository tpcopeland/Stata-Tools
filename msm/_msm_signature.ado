*! _msm_signature Version 1.2.3  2026/07/17
*! Compute a stage input signature over the variables a stage consumed
*! Author: Timothy P Copeland
*! Program class: rclass (returns results in r())

/*
Syntax:
  _msm_signature varlist [, IFVar(varname)]

Computes a signature over exactly the variables a pipeline stage consumed, so a
later stage can prove the data still are the data that produced its input
(audit finding A02). Existence flags cannot do this: a user can edit treatment,
drop rows, or re-merge and every existence check still passes.

Uses Stata's _datasignature. Measured behaviour (2026-07-17, Stata 17/MP):
  - invariant to observation order, so a user re-sorting their own data does
    NOT falsely invalidate a valid fit (the audit asks for this explicitly);
  - ignores variables outside the varlist, so unrelated columns do not
    invalidate;
  - detects an edited value and a changed row count.

Note the public `datasignature` command does NOT accept a varlist (r 198,
verified 2026-07-17). `_datasignature` is the programmer's form that does, and
is the pattern already used in finegray and ltmle.

Options:
  IFVar(varname) - restrict the signature to rows where this indicator is 1
                   (e.g. the estimation sample)

Returns:
  r(sig)   - the signature string
  r(nvars) - number of variables signed
*/

program define _msm_signature, rclass
    version 16.0
    local _orig_varabbrev = c(varabbrev)
    set varabbrev off
    capture noisily {

        syntax varlist [, IFVar(varname)]

        local _nvars : word count `varlist'

        if "`ifvar'" != "" {
            quietly _datasignature `varlist' if `ifvar' == 1, nodefault nonames
        }
        else {
            quietly _datasignature `varlist', nodefault nonames
        }

        local _sig = r(datasignature)

        * An empty signature would compare equal to a stage that never stored
        * one, turning the freshness check into a no-op that always passes.
        if "`_sig'" == "" {
            display as error "failed to compute MSM stage signature"
            exit 459
        }

        return local sig "`_sig'"
        return scalar nvars = `_nvars'
    }
    local rc = _rc
    set varabbrev `_orig_varabbrev'
    if `rc' exit `rc'
end
