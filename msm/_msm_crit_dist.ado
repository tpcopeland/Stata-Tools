*! _msm_crit_dist Version 1.2.4  2026/07/23
*! Two-sided critical value and p-value distribution from the fit's inference
*! Author: Timothy P Copeland, Karolinska Institutet
*! Program class: rclass

* Returns the two-sided critical value for a requested confidence level using
* the inference distribution persisted by msm_fit (audit A20): weighted linear
* models use Student t with e(df_r); GLM/Cox use the normal approximation. The
* fit stores char _dta[_msm_fit_inf_dist] ("t"/"z") and _msm_fit_inf_df. When
* no valid distribution is recorded (older state, no fit), it falls back to z so
* downstream tables never crash. Callers read r(crit) for CI half-widths and
* r(dist)/r(df) to choose the matching p-value tail.
program define _msm_crit_dist, rclass
    version 16.0
    local _orig_varabbrev = c(varabbrev)
    set varabbrev off
    capture noisily {
        syntax , Level(real)

        if `level' <= 0 | `level' >= 100 {
            display as error "_msm_crit_dist: level() must be strictly between 0 and 100"
            exit 198
        }

        local _idist : char _dta[_msm_fit_inf_dist]
        local _idf   : char _dta[_msm_fit_inf_df]
        local _alpha2 = (100 - `level') / 200

        if "`_idist'" == "t" & "`_idf'" != "" & "`_idf'" != "." {
            return scalar crit = invttail(`_idf', `_alpha2')
            return scalar df   = `_idf'
            return local  dist "t"
        }
        else {
            return scalar crit = invnormal(1 - `_alpha2')
            return local  dist "z"
        }
    }
    local rc = _rc
    set varabbrev `_orig_varabbrev'
    if `rc' exit `rc'
end
