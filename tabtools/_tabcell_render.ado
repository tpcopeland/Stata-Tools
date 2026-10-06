*! _tabcell_render Version 2.5.4  2026/10/06
*! Vectorised cell renderer behind tabcell (scalar and generate() forms)
*! Author: Timothy P Copeland, Karolinska Institutet
*! Program class: rclass

/*
One code path renders every tabcell cell. tabcell's scalar forms post their
numbers into a one-row frame and call this program there, so r(cell) and a
generate() column can never disagree about formatting, masking or refusal.

    _tabcell_render <form> <var1> [<var2> <var3>] , touse(var) generate(newvar)
        [fmt(%fmt) sep(str) missing(str) hasmissing(0|1) pdp(#) highpdp(#)
         nformat(%fmt) pformat(%fmt) mincell(#) ci(exact|poisson) level(#)
         per(#) nocount cilimits(lbvar ubvar estvar)]

  form est : var1 = estimate, var2 = lower, var3 = upper (already on the
             reported scale)
  form p   : var1 = p-value
  form n   : var1 = count
  form np  : var1 = count, var2 = denominator; with ci(exact) the cell is
             n (pct; lo<sep>hi), the exact binomial (Clopper-Pearson)
             interval for the percentage at level(#), and cilimits() names
             three new double variables that receive the printed lower
             limit, upper limit and percentage (missing where the cell
             prints none). nocount drops the count: pct, or pct (lo<sep>hi)
             with ci(exact); a zero denominator is then non-computable, and
             a masked count prints the en dash, never its percentage
  form enp : var1 = events, var2 = total
  form iqr : var1 = median, var2 = Q1, var3 = Q3
  form rate: var1 = events, var2 = person-time; rate (lo<sep>hi) per
             per(#) with ci(exact) (exact Poisson) or ci(poisson) (log-rate
             Wald, strate), the exact limits at zero events; cilimits()
             receives lb, ub and the rate. No person-time with no events is
             non-computable; events without person-time are an error. A
             rate with 1 to mincell-1 events prints the en dash.

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
            MINCELL(integer 0) CI(string) LEVEL(real 95) CILIMITS(string) ///
            PER(real 1) NOCOUNT]
        * _ci: the exact binomial interval of form np
        local _ci = ("`ci'" == "exact" & "`form'" == "np")
        if "`form'" == "rate" & !inlist("`ci'", "exact", "poisson") {
            display as error "_tabcell_render: form rate needs ci(exact) or ci(poisson)"
            exit 198
        }
        if "`ci'" != "" & !inlist("`form'", "np", "rate") {
            display as error "_tabcell_render: ci() belongs to forms np and rate"
            exit 198
        }
        if "`form'" == "np" & !inlist("`ci'", "", "exact") {
            display as error "_tabcell_render: ci(`ci') is not supported for form np"
            exit 198
        }
        if "`nocount'" != "" & "`form'" != "np" {
            display as error "_tabcell_render: nocount belongs to form np"
            exit 198
        }
        if !(`per' > 0) | missing(`per') {
            display as error "_tabcell_render: per() must be positive"
            exit 198
        }
        * the text of a withheld value that is not a count (a rate, a share):
        * the en dash ratetab and stratetab print for a withheld rate
        local _dash = uchar(8211)
        if `"`cilimits'"' != "" & (!(`_ci' | "`form'" == "rate") | `: word count `cilimits'' != 3) {
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
            * nothing to compute: a share of a zero denominator (nocount), a
            * rate with neither events nor person-time. A count over a zero
            * total stays an error below.
            local n_zero 0
            if "`nocount'" != "" | "`form'" == "rate" {
                count if `touse' & `bad' == 0 & `v1' == 0 & `v2' == 0
                local n_zero = r(N)
                replace `bad' = 1 if `touse' & `v1' == 0 & `v2' == 0
            }
            count if `bad' == 1 & `touse'
            local n_bad = r(N)
        }
        if `n_bad' & !`hasmissing' {
            if `n_zero' {
                local _what = cond("`form'" == "rate", "no events and no person-time", "a zero denominator")
                noisily display as error "tabcell: `n_zero' cell(s) have `_what': nothing to compute"
            }
            if `n_bad' > `n_zero' noisily display as error "tabcell: `=`n_bad' - `n_zero'' cell(s) have a missing or non-finite value"
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
            if "`form'" == "rate" {
                count if `touse' & !`bad' & (`v1' < 0 | `v2' < 0)
                if r(N) {
                    noisily display as error "tabcell rate: events and person-time must be nonnegative"
                    exit 198
                }
                count if `touse' & !`bad' & `v1' > 0 & `v2' == 0
                if r(N) {
                    noisily display as error "tabcell rate: `r(N)' cell(s) have events without person-time"
                    exit 198
                }
                if "`ci'" == "exact" {
                    count if `touse' & !`bad' & `v1' != floor(`v1')
                    if r(N) {
                        noisily display as error "tabcell rate, ci(exact): the exact Poisson interval needs whole-number events; `r(N)' cell(s) are not integers"
                        exit 459
                    }
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
        * sep() enters the cells only as the value of this variable, stored
        * from Mata: never part of a command line or an expression, so it is
        * printed byte for byte (help tabtools##sep)
        tempvar _sepv
        quietly gen strL `_sepv' = ""
        mata: st_sstore(., st_local("_sepv"), J(st_nobs(), 1, st_local("sep") == "" ? ", " : st_local("sep")))
        quietly {
            if "`form'" == "est" | "`form'" == "iqr" {
                replace `generate' = strtrim(string(`v1', "`fmt'")) + " (" + ///
                    strtrim(string(`v2', "`fmt'")) + `_sepv' + ///
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
            else if "`form'" == "np" & !`_ci' & "`nocount'" != "" {
                * pct alone (the zero denominator is a bad row above)
                * stata-dev-ignore: unchecked-commit — generate() is the caller's tempvar; the caller refuses an empty sample and this program refuses bad (zero-denominator or missing) rows above, unless missing() is given
                replace `generate' = strtrim(string(100 * `v1' / `v2', "`pformat'")) ///
                    if `touse' & !`bad'
                if `mincell' > 0 {
                    replace `generate' = "`_dash'" if `touse' & !`bad' & ///
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
                if "`nocount'" != "" {
                    * pct (lo, hi): the percentage and its interval alone
                    replace `generate' = strtrim(string(100 * `v1' / `v2', "`pformat'")) + ///
                        " (" + strtrim(string(100 * `_lo', "`pformat'")) + `_sepv' + ///
                        strtrim(string(100 * `_hi', "`pformat'")) + ")" ///
                        if `touse' & !`bad'
                }
                else {
                    replace `generate' = strtrim(string(`v1', "`nformat'")) + ///
                        cond(`v2' > 0, " (" + strtrim(string(100 * `v1' / `v2', "`pformat'")) + ///
                        "; " + strtrim(string(100 * `_lo', "`pformat'")) + `_sepv' + ///
                        strtrim(string(100 * `_hi', "`pformat'")) + ")", "") ///
                        if `touse' & !`bad'
                }
                if `mincell' > 0 {
                    * nocount: the percentage and its limits would give the
                    * masked count back (pct x d), so the whole cell goes
                    local _mtxt = cond("`nocount'" != "", "`_dash'", "<`mincell'")
                    replace `generate' = "`_mtxt'" if `touse' & !`bad' & ///
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
            else if "`form'" == "rate" {
                * rate (lo, hi) per per(): ratetab's limits. Exact: the
                * Poisson limits for the count ([R] ci, Poisson mean), the
                * lower skipped (0) at zero events. poisson: strate's
                * rate*exp(-/+ z/sqrt(e)); at zero events the exact limits.
                tempvar _rt _lo _hi _show
                local _a = (1 - `level' / 100) / 2
                local _z = invnormal(1 - `_a')
                gen byte `_show' = `touse' & !`bad'
                if `mincell' > 0 replace `_show' = 0 if `v1' >= 1 & `v1' < `mincell'
                gen double `_rt' = `v1' / `v2' * `per' if `_show'
                if "`ci'" == "exact" {
                    gen double `_lo' = cond(`v1' == 0, 0, invpoissontail(`v1', `_a') / `v2' * `per') if `_show'
                    gen double `_hi' = invpoisson(`v1', `_a') / `v2' * `per' if `_show'
                }
                else {
                    gen double `_lo' = cond(`v1' == 0, 0, `_rt' * exp(-`_z' / sqrt(`v1'))) if `_show'
                    gen double `_hi' = cond(`v1' == 0, -ln(`_a') / `v2' * `per', ///
                        `_rt' * exp(`_z' / sqrt(`v1'))) if `_show'
                }
                count if `_show' & (missing(`_rt') | missing(`_lo') | missing(`_hi'))
                if r(N) {
                    noisily display as error "tabcell rate: the rate or its interval could not be computed in `r(N)' cell(s)"
                    exit 459
                }
                replace `generate' = strtrim(string(`_rt', "`fmt'")) + " (" + ///
                    strtrim(string(`_lo', "`fmt'")) + `_sepv' + ///
                    strtrim(string(`_hi', "`fmt'")) + ")" if `_show'
                if `mincell' > 0 {
                    * events, person-time and the rate give each other back:
                    * the withheld rate prints no number at all
                    replace `generate' = "`_dash'" if `touse' & !`bad' & ///
                        `v1' >= 1 & `v1' < `mincell'
                }
                if `"`cilimits'"' != "" {
                    local _cl1 : word 1 of `cilimits'
                    local _cl2 : word 2 of `cilimits'
                    local _cl3 : word 3 of `cilimits'
                    gen double `_cl1' = `_lo' if `_show'
                    gen double `_cl2' = `_hi' if `_show'
                    gen double `_cl3' = `_rt' if `_show'
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
