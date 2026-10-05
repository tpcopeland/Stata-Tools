*! _tabcell_render Version 2.4.0  2026/10/05
*! Vectorised cell renderer behind tabcell (scalar and generate() forms)
*! Author: Timothy P Copeland, Karolinska Institutet
*! Program class: rclass

/*
One code path renders every tabcell cell. tabcell's scalar forms post their
numbers into a one-row frame and call this program there, so r(cell) and a
generate() column can never disagree about formatting, masking or refusal.

    _tabcell_render <form> <var1> [<var2> <var3>] , touse(var) generate(newvar)
        [fmt(%fmt) sep(str) missing(str) hasmissing(0|1) pdp(#) highpdp(#)
         nformat(%fmt) pformat(%fmt) mincell(#) ci(exact) level(#)
         cilimits(lbvar ubvar pctvar)]

  form est : var1 = estimate, var2 = lower, var3 = upper (already on the
             reported scale)
  form p   : var1 = p-value
  form n   : var1 = count
  form np  : var1 = count, var2 = denominator; with ci(exact) the cell is
             n (pct; lo<sep>hi), the exact binomial (Clopper-Pearson)
             interval for the percentage at level(#), and cilimits() names
             three new double variables that receive the printed lower
             limit, upper limit and percentage (missing where the cell
             prints none)
  form enp : var1 = events, var2 = total
  form iqr : var1 = median, var2 = Q1, var3 = Q3

Returns r(N) rendered rows, r(N_missing) rows given the missing() text.
*/

capture program drop _tabcell_render
program define _tabcell_render, rclass
    version 17.0
    local _orig_varabbrev = c(varabbrev)
    set varabbrev off
    capture noisily {
        gettoken form 0 : 0
        syntax varlist(numeric min=1 max=3), TOUSE(varname) GENerate(name) ///
            [FMT(string) SEP(string) MISSING(string) HASMISSING(integer 0) ///
            PDP(integer 3) HIGHPDP(integer 2) PSTYLE(string) NFORMAT(string) PFORMAT(string) ///
            MINCELL(integer 0) CI(string) LEVEL(real 95) CILIMITS(string)]
        local _ci = ("`ci'" == "exact")
        if "`ci'" != "" & !`_ci' {
            display as error "_tabcell_render: ci(`ci') is not supported"
            exit 198
        }
        if `_ci' & "`form'" != "np" {
            display as error "_tabcell_render: ci() belongs to form np"
            exit 198
        }
        if `"`cilimits'"' != "" & (!`_ci' | `: word count `cilimits'' != 3) {
            display as error "_tabcell_render: cilimits() takes three new names and needs ci()"
            exit 198
        }
        local v1 : word 1 of `varlist'
        local v2 : word 2 of `varlist'
        local v3 : word 3 of `varlist'
        tempvar bad
        quietly {
            if "`form'" == "est" | "`form'" == "iqr" {
                gen byte `bad' = missing(`v1') | missing(`v2') | missing(`v3') if `touse'
            }
            else if "`form'" == "p" | "`form'" == "n" {
                gen byte `bad' = missing(`v1') if `touse'
            }
            else {
                gen byte `bad' = missing(`v1') | missing(`v2') if `touse'
            }
            count if `bad' == 1 & `touse'
            local n_bad = r(N)
        }
        if `n_bad' & !`hasmissing' {
            noisily display as error "tabcell: `n_bad' cell(s) have a missing or non-finite value"
            noisily display as error "a failed or non-estimable result is never printed as a number; specify missing(" ///
                `"""' "text" `"""' ") to print text instead"
            exit 459
        }
        * Content checks on the finite rows: a reversed interval, a p-value
        * outside [0, 1], a negative count or more events than the total.
        quietly {
            if "`form'" == "est" | "`form'" == "iqr" {
                count if `touse' & !`bad' & `v2' > `v3'
                if r(N) {
                    noisily display as error "tabcell: the lower limit exceeds the upper limit in `r(N)' cell(s)"
                    exit 198
                }
            }
            if "`form'" == "iqr" {
                count if `touse' & !`bad' & (`v1' < `v2' | `v1' > `v3')
                if r(N) {
                    noisily display as error "tabcell iqr: the median lies outside (Q1, Q3) in `r(N)' cell(s)"
                    exit 198
                }
            }
            if "`form'" == "p" {
                count if `touse' & !`bad' & (`v1' < 0 | `v1' > 1)
                if r(N) {
                    noisily display as error "tabcell p: `r(N)' p-value(s) lie outside [0, 1]"
                    exit 198
                }
            }
            if "`form'" == "n" {
                count if `touse' & !`bad' & `v1' < 0
                if r(N) {
                    noisily display as error "tabcell n: counts must be nonnegative"
                    exit 198
                }
            }
            if "`form'" == "np" | "`form'" == "enp" {
                count if `touse' & !`bad' & (`v1' < 0 | `v2' < 0)
                if r(N) {
                    noisily display as error "tabcell `form': counts must be nonnegative"
                    exit 198
                }
                count if `touse' & !`bad' & `v1' > `v2'
                if r(N) {
                    noisily display as error "tabcell `form': the count exceeds its total in `r(N)' cell(s)"
                    exit 198
                }
            }
            if `_ci' {
                * the binomial interval is defined for whole counts only
                count if `touse' & !`bad' & (`v1' != floor(`v1') | `v2' != floor(`v2'))
                if r(N) {
                    noisily display as error "tabcell np, ci(exact): the exact binomial interval needs whole-number counts; `r(N)' cell(s) are not integers"
                    exit 459
                }
            }
        }

        quietly gen strL `generate' = ""
        quietly {
            if "`form'" == "est" | "`form'" == "iqr" {
                replace `generate' = strtrim(string(`v1', "`fmt'")) + " (" + ///
                    strtrim(string(`v2', "`fmt'")) + `"`macval(sep)'"' + ///
                    strtrim(string(`v3', "`fmt'")) + ")" if `touse' & !`bad'
            }
            else if "`form'" == "p" {
                tempvar ptxt
                _tabtools_fmt_p `v1' if `touse' & !`bad', generate(`ptxt') ///
                    pdp(`pdp') highpdp(`highpdp')
                replace `generate' = `ptxt' if `touse' & !`bad'
                if inlist("`pstyle'", "footnote", "pfootnote") {
                    * prose form: "p = 0.012", "p < 0.001", "p > 0.99";
                    * pfootnote writes the letter as a capital: "P = 0.012"
                    local _pl = cond("`pstyle'" == "pfootnote", "P", "p")
                    replace `generate' = cond(inlist(substr(`ptxt', 1, 1), "<", ">"), ///
                        "`_pl' " + substr(`ptxt', 1, 1) + " " + substr(`ptxt', 2, .), ///
                        "`_pl' = " + `ptxt') if `touse' & !`bad'
                }
            }
            else if "`form'" == "n" {
                replace `generate' = strtrim(string(`v1', "`nformat'")) if `touse' & !`bad'
                if `mincell' > 0 {
                    replace `generate' = "<`mincell'" if `touse' & !`bad' & ///
                        `v1' >= 1 & `v1' < `mincell'
                }
            }
            else if "`form'" == "np" & !`_ci' {
                * n (%): the percentage is omitted when the denominator is 0
                replace `generate' = strtrim(string(`v1', "`nformat'")) + ///
                    cond(`v2' > 0, " (" + strtrim(string(100 * `v1' / `v2', "`pformat'")) + ")", "") ///
                    if `touse' & !`bad'
                if `mincell' > 0 {
                    replace `generate' = "<`mincell'" if `touse' & !`bad' & ///
                        `v1' >= 1 & `v1' < `mincell'
                }
            }
            else if "`form'" == "np" {
                * n (pct; lo, hi): Clopper-Pearson (1934) limits as beta
                * quantiles (Thulin 2014, eq. 4; [R] ci, Methods and
                * formulas): lo = B(a/2; n, d-n+1), hi = B(1-a/2; n+1, d-n),
                * with the tail skipped at n = 0 (lo = 0) and n = d (hi = 1)
                tempvar _lo _hi _show
                local _a = (1 - `level' / 100) / 2
                gen byte `_show' = `touse' & !`bad' & `v2' > 0
                if `mincell' > 0 replace `_show' = 0 if `v1' >= 1 & `v1' < `mincell'
                gen double `_lo' = cond(`v1' == 0, 0, invibeta(`v1', `v2' - `v1' + 1, `_a')) if `_show'
                gen double `_hi' = cond(`v1' == `v2', 1, invibetatail(`v1' + 1, `v2' - `v1', `_a')) if `_show'
                count if `_show' & (missing(`_lo') | missing(`_hi'))
                if r(N) {
                    noisily display as error "tabcell np, ci(exact): the interval could not be computed in `r(N)' cell(s)"
                    exit 459
                }
                replace `generate' = strtrim(string(`v1', "`nformat'")) + ///
                    cond(`v2' > 0, " (" + strtrim(string(100 * `v1' / `v2', "`pformat'")) + ///
                    "; " + strtrim(string(100 * `_lo', "`pformat'")) + `"`macval(sep)'"' + ///
                    strtrim(string(100 * `_hi', "`pformat'")) + ")", "") ///
                    if `touse' & !`bad'
                if `mincell' > 0 {
                    replace `generate' = "<`mincell'" if `touse' & !`bad' & ///
                        `v1' >= 1 & `v1' < `mincell'
                }
                if `"`cilimits'"' != "" {
                    local _cl1 : word 1 of `cilimits'
                    local _cl2 : word 2 of `cilimits'
                    local _cl3 : word 3 of `cilimits'
                    gen double `_cl1' = 100 * `_lo' if `_show'
                    gen double `_cl2' = 100 * `_hi' if `_show'
                    gen double `_cl3' = 100 * `v1' / `v2' if `_show'
                }
            }
            else if "`form'" == "enp" {
                replace `generate' = strtrim(string(`v1', "`nformat'")) + "/" + ///
                    strtrim(string(`v2', "`nformat'")) + ///
                    cond(`v2' > 0, " (" + strtrim(string(100 * `v1' / `v2', "`pformat'")) + ")", "") ///
                    if `touse' & !`bad'
                if `mincell' > 0 {
                    * a masked event count loses its percentage; a masked total
                    * masks the whole cell, since e/n would reveal it
                    replace `generate' = "<`mincell'/" + strtrim(string(`v2', "`nformat'")) ///
                        if `touse' & !`bad' & `v1' >= 1 & `v1' < `mincell'
                    replace `generate' = "<`mincell'" if `touse' & !`bad' & ///
                        `v2' >= 1 & `v2' < `mincell'
                }
            }
            if `hasmissing' {
                replace `generate' = `"`macval(missing)'"' if `touse' & `bad' == 1
            }
            count if `touse'
            local n_all = r(N)
        }
        return scalar N = `n_all' - `n_bad'
        return scalar N_missing = `n_bad'
    }
    local rc = _rc
    set varabbrev `_orig_varabbrev'
    if `rc' exit `rc'
end
