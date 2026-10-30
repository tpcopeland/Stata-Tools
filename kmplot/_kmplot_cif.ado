*! _kmplot_cif Version 1.0.1  2026/10/30
*! Aalen-Johansen cumulative incidence with a competing event, for kmplot
*! Author: Timothy P Copeland, Karolinska Institutet
*! Program class: nclass

/*
Internal helper for kmplot, compete().  Not intended for direct use.

  _kmplot_cif , grpvar(varname) compvar(varname) generate(newvar)
      sall(newvar) [se(newvar) wvar(varname)]

Works on the st data in memory (one row per record, already restricted to
the analysis sample).  For each group, at every distinct exit time t_j:

  n_j  = weighted number at risk, sum of w over records with _t0 < t_j <= _t
  d1_j = weighted events of interest (_d == 1) at t_j
  d2_j = weighted competing events (compvar == 1) at t_j
  S(t_j)  = prod_{i <= j} {1 - (d1_i + d2_i) / n_i}   (all-cause KM)
  F(t_j)  = sum_{i <= j} S(t_{i-1}) d1_i / n_i        (Aalen-Johansen CIF)

Variance (se() only; unweighted or frequency-weighted data): Marubini and
Valsecchi (1995, eq. 10.12), as given by Coviello and Boggess (2004, p. 104)
and implemented in stcompet 1.0.7 (secomp):

  var F(t_j) = sum_{a <= j} [ {F(t_j) - F(t_a)}^2 d_a / {n_a (n_a - d_a)}
             + S(t_{a-1})^2 d1_a (n_a - d1_a) / n_a^3
             - 2 {F(t_j) - F(t_a)} S(t_{a-1}) d1_a / n_a^2 ],  d_a = d1_a + d2_a

The first term is dropped where n_a = d_a, as in stcompet.  The sums are
accumulated in one pass through the expansion of the squares.

Fills generate() with F, se() with its standard error and sall() with the
all-cause survivor function, each evaluated at the record's own _t.
*/

program define _kmplot_cif, nclass
    version 16.0
    local _orig_varabbrev = c(varabbrev)
    set varabbrev off
    local _cif_frame_made = 0
    tempname cfr
    capture noisily {
        syntax , GRPvar(varname) COMPvar(varname) GENerate(name) SALL(name) ///
            [SE(name) WVar(varname)]

        tempvar w lnk
        quietly gen double `w' = 1
        if "`wvar'" != "" quietly replace `w' = `wvar'

        frame put `grpvar' _t _t0 _d `compvar' `w', into(`cfr')
        local _cif_frame_made = 1
        frame `cfr' {
            quietly {
                rename `grpvar' __g
                rename `w' __w
                gen double __d1 = __w * (_d == 1)
                gen double __d2 = __w * (`compvar' == 1)
                * Stack exits (at _t) and entries (at _t0).  At risk at t is
                * the weight exiting at or after t minus the weight entering
                * at or after t.
                gen long __row = _n
                expand 2
                bysort __row: gen byte __entry = (_n == 2)
                gen double __time = cond(__entry, _t0, _t)
                gen double __nout = cond(__entry, 0, __w)
                gen double __nin = cond(__entry, __w, 0)
                replace __d1 = 0 if __entry
                replace __d2 = 0 if __entry
                collapse (sum) __nout __nin __d1 __d2, by(__g __time)
                gsort __g -__time
                by __g: gen double __n = sum(__nout) - sum(__nin)
                * Keep exit times only; entry-only times carry no jump.
                keep if __nout > 0
                sort __g __time
                gen double __dd = __d1 + __d2
                gen double __s = 1 - __dd / __n
                by __g: replace __s = __s * __s[_n - 1] if _n > 1
                by __g: gen double __sp = cond(_n == 1, 1, __s[_n - 1])
                by __g: gen double __F = sum(__sp * __d1 / __n)
                if "`se'" != "" {
                    gen double __a = cond(__n > __dd, __dd / (__n * (__n - __dd)), 0)
                    gen double __b = __sp^2 * __d1 * (__n - __d1) / __n^3
                    gen double __c = __sp * __d1 / __n^2
                    by __g: gen double __A0 = sum(__a)
                    by __g: gen double __A1 = sum(__a * __F)
                    by __g: gen double __A2 = sum(__a * __F^2)
                    by __g: gen double __B = sum(__b)
                    by __g: gen double __C0 = sum(__c)
                    by __g: gen double __C1 = sum(__c * __F)
                    gen double __v = __F^2 * __A0 - 2 * __F * __A1 + __A2 + ///
                        __B - 2 * __F * __C0 + 2 * __C1
                    replace __v = 0 if __v < 0
                    gen double __se = sqrt(__v)
                    * No standard error before the first event of interest.
                    replace __se = . if __F == 0
                }
                rename __g `grpvar'
                rename __time _t
            }
        }
        quietly frlink m:1 `grpvar' _t, frame(`cfr') generate(`lnk')
        quietly count if missing(`lnk')
        if r(N) > 0 {
            noisily display as error "compete(): internal time alignment failed"
            exit 498
        }
        quietly frget `generate' = __F, from(`lnk')
        quietly frget `sall' = __s, from(`lnk')
        if "`se'" != "" quietly frget `se' = __se, from(`lnk')
        drop `lnk'
    }
    local rc = _rc
    if `_cif_frame_made' capture frame drop `cfr'
    set varabbrev `_orig_varabbrev'
    if `rc' exit `rc'
end
