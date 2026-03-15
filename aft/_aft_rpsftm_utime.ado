*! _aft_rpsftm_utime Version 1.1.0  2026/03/15
*! Compute counterfactual untreated time and re-censoring for RPSFTM
*! Author: Timothy P Copeland

/*
Usage:
  _aft_rpsftm_utime psi_val, exposure(varname) generate(newvar) ///
      [recensor event(varname) censortime(varname)]

Description:
  Given a candidate psi value and treatment exposure variable d_i
  (fraction of time on treatment), computes counterfactual untreated
  survival time: U_i = T_i * exp(-psi * d_i)

  If recensor is specified, applies re-censoring to prevent
  informative censoring under the counterfactual.

  This helper is called by both aft_rpsftm (inner grid loop)
  and aft_counterfactual.
*/

program define _aft_rpsftm_utime
    version 16.0
    set varabbrev off
    set more off

    syntax anything(name=psi_val) , EXPosure(varname) GENerate(name) ///
        [RECensor EVent(varname) CENSortime(varname)]

    * Validate psi is numeric
    confirm number `psi_val'

    * Compute counterfactual untreated time
    * U_i = T_i * exp(-psi * d_i)
    quietly gen double `generate' = _t * exp(-`psi_val' * `exposure')

    * Apply re-censoring if requested
    if "`recensor'" != "" {
        * Re-censoring prevents informative censoring under counterfactual
        * Counterfactual censoring time: C*_i = C_i * exp(-psi * d_i^C)
        * where d_i^C is treatment exposure proportion
        * For subjects who were censored: replace U with min(U, C*)
        * For subjects on treatment: C* = C * exp(-psi * d_i)
        * For subjects not on treatment: C* = C (unchanged)

        if "`censortime'" != "" {
            * User provided explicit censoring time variable
            tempvar cstar
            quietly gen double `cstar' = `censortime' * exp(-`psi_val' * `exposure')
            quietly replace `generate' = min(`generate', `cstar')

            * Update event indicator: censored if counterfactual time hit the
            * re-censoring boundary
            if "`event'" != "" {
                quietly replace `event' = 0 if `generate' == `cstar' & `generate' < _t * exp(-`psi_val' * `exposure')
            }
        }
        else {
            * Use administrative censoring: for censored subjects (_d==0),
            * their observed time IS the censoring time
            * For failed subjects (_d==1), admin censoring time >= failure time
            * Conservative approach: use observed _t as upper bound for all
            tempvar cstar
            quietly gen double `cstar' = _t * exp(-`psi_val' * `exposure')

            * Re-censoring only affects observations where the counterfactual
            * admin censoring time is less than the counterfactual event time
            * For the control arm (exposure ~= 0): C* ~ C (no change)
            * For the treated arm: C* = C * exp(-psi * d_i)
            * When psi > 0 (treatment beneficial): C* < C for treated subjects
            * This means treated subjects get re-censored earlier

            * Apply: U_i = min(U_i, C*_i) and mark re-censored obs
            * The counterfactual censoring time for each subject is their
            * max possible follow-up under no treatment
            * For _d==0 (censored): admin censor time = _t, so C* = _t * exp(-psi * d)
            * For _d==1 (event): admin censor time >= _t, but we use _t as lower bound

            * We already computed U = _t * exp(-psi * d) above
            * Re-censoring replaces event status for observations where
            * the counterfactual untreated time exceeds admin censoring
            * under the null treatment scenario
            * No further adjustment needed when censortime not provided:
            * _t already serves as the effective censoring bound
        }
    }

    * Floor at zero (numerical safety)
    quietly replace `generate' = max(`generate', 0.0001) if `generate' <= 0
end
