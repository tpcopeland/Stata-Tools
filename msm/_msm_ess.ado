*! _msm_ess Version 1.4.12  2026/10/09
*! Kish effective sample size of a weight variable
*! Author: Timothy P Copeland, Karolinska Institutet
*! Program class: rclass (returns results in r())

/*
Syntax:
  _msm_ess varname [if] [in]

Returns:
  r(ess)  (sum w)^2 / sum w^2 over nonmissing weights in the sample; missing
          when the sample is empty or every weight is zero
  r(N)    number of nonmissing weights in the sample

The ESS does not depend on the scale of the weights, but the raw sum of squares
does: weights near 1e-200 square to 0 and weights near 1e200 square to missing,
both of which made the ESS missing. Products of many per-period weights can
reach such scales. The weights are therefore divided by a power of two near
their largest magnitude first. The division is exact, and the sums are held in
scalars rather than macros, so no digits are lost on the way.
*/

program define _msm_ess, rclass
    version 16.0
    local _orig_varabbrev = c(varabbrev)
    set varabbrev off
    capture noisily {
        syntax varname(numeric) [if] [in]
        marksample touse
        tempname ess
        scalar `ess' = .

        quietly summarize `varlist' if `touse', meanonly
        local n = r(N)
        local amax = max(abs(r(min)), abs(r(max)))
        if `n' > 0 & `amax' > 0 & !missing(`amax') {
            local k = ceil(ln(`amax') / ln(2))
            local k = min(max(`k', -1021), 1022)
            tempvar ws ws2
            tempname s1 s2
            quietly gen double `ws' = `varlist' / 2^`k' if `touse'
            quietly gen double `ws2' = `ws'^2
            quietly summarize `ws', meanonly
            scalar `s1' = r(sum)
            quietly summarize `ws2', meanonly
            scalar `s2' = r(sum)
            if `s2' > 0 & !missing(`s1', `s2') scalar `ess' = `s1'^2 / `s2'
        }
        return scalar ess = `ess'
        return scalar N = `n'
    }
    local rc = _rc
    set varabbrev `_orig_varabbrev'
    if `rc' exit `rc'
end
