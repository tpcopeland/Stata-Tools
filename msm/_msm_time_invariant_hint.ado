*! _msm_time_invariant_hint Version 1.2.4  2026/07/23
*! Diagnostic hint for time-invariant (baseline) treatment in msm_weight
*! Author: Timothy P Copeland, Karolinska Institutet

* Emits a targeted diagnostic when the treatment denominator model degenerates
* because treatment is held constant within person (A_t == A_{t-1} for every
* person-period). msm targets time-varying treatment; a single-point-in-time
* (baseline) treatment is perfectly predicted by its own lag, which is not an
* estimator failure but an out-of-scope design. Point the user to the documented
* alternative (teffects ipw) instead of a bare model-failure code.
*
* Usage: _msm_time_invariant_hint <treatment_varname>

program define _msm_time_invariant_hint
    version 16.0
    local _orig_varabbrev = c(varabbrev)
    set varabbrev off
    capture noisily {
        args treatvar

        noisily display as error ///
            "  Cause: treatment `treatvar' is time-invariant within person"
        noisily display as error ///
            "  (A_t == A_{t-1} in every period), so it is perfectly predicted by"
        noisily display as error ///
            "  its own lag and the IPTW denominator model degenerates."
        noisily display as error ///
            "  msm targets TIME-VARYING treatment. For a single-point-in-time"
        noisily display as error ///
            "  (baseline) treatment, use Stata's {help teffects} ipw instead."
    }
    local rc = _rc
    set varabbrev `_orig_varabbrev'
    if `rc' exit `rc'
end
