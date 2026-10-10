*! _tabtools_fmt_pct Version 2.6.2  2026/10/10
*! The package's percentage display rule: a share that is neither none nor all never prints as 0 or 100
*! Author: Timothy P Copeland, Karolinska Institutet
*! Program class: rclass

/*
Every command that prints a percentage formats it through this program, so
the rule lives in one place.

For a value v with 0 < v < 100 and a fixed format %w.df or %w.dfc (or the
decimal-comma %w,df / %w,dfc, which keeps its comma in the escalated text):

    1. format at d decimals, exactly as string(v, fmt) always did
    2. if that text reads 0 or 100, add one decimal at a time, up to
       max(d, 2) decimals ("0" -> "0.3", "0.0" -> "0.04", "100" -> "99.6")
    3. if it still reads 0 or 100 at max(d, 2) decimals, print
       "<0.01" or ">99.99" (that many decimals)

Everything else -- v <= 0, v >= 100, missing, or a %g/%e/other format -- is
string(v, fmt) unchanged, so a true zero count still prints 0 and a whole
group still prints 100. Values within 1e-9 of 0 or 100 count as 0 or 100:
a weighted share whose numerator and denominator are the same sum taken in
a different order lands one ulp off 100, and that is not "not all".

Escalated text is trimmed; the unescalated text is not, so callers keep the
alignment they had.

Scalar mode:  _tabtools_fmt_pct, value(exp) format(%fmt)
              value() is an expression, evaluated into a double scalar here:
              a number passed through a macro is stored as %18.0g text and
              reparses to a different double (100*7/20000 is
              0.034999999999999996 but `=...' gives .035), which moves a
              near-tie to the other side. desctab still hands in its
              percentage as a macro (it always formatted that macro), so a
              share on such a near-tie can print one unit apart in desctab
              and crosstab/tabcell; changing that would move ordinary desctab
              ties, which this rule leaves alone.
              r(text)      the display text
              r(decimals)  decimals used when escalated or capped, else .

Variable mode: _tabtools_fmt_pct pctvar [if] [in], format(%fmt) ///
                   generate(newstrvar) [decimals(newvar)]
              decimals() is filled where the text was escalated or capped,
              missing elsewhere, so a caller can print interval limits at
              the same precision as the estimate. Rows outside the sample
              are "" (and missing).
*/

capture program drop _tabtools_fmt_pct
program define _tabtools_fmt_pct, rclass
    version 17.0
    local _orig_varabbrev = c(varabbrev)
    set varabbrev off
    capture noisily {
        syntax [varlist(numeric max=1 default=none)] [if] [in], ///
            Format(string) [VALue(string) GENerate(name) DECimals(name)]

        local _scalar = "`varlist'" == ""
        if `_scalar' {
            if `"`value'"' == "" | "`generate'`decimals'" != "" {
                display as error "_tabtools_fmt_pct: give value() alone, or a variable with generate()"
                exit 198
            }
            if `"`if'`in'"' != "" {
                display as error "_tabtools_fmt_pct: if and in need a variable"
                exit 198
            }
            tempname _sv
            scalar `_sv' = `value'
        }
        else {
            if "`generate'" == "" | `"`value'"' != "" {
                display as error "_tabtools_fmt_pct: give value() alone, or a variable with generate()"
                exit 198
            }
            confirm new variable `generate' `decimals'
        }

        * Decimals of a fixed format; anything else passes through unchanged
        local _fixed = regexm(`"`format'"', "^%-?0?[0-9]+([.,])([0-9]+)(fc|f)$")
        if `_fixed' {
            local _sep = regexs(1)
            local _d = real(regexs(2))
            local _fc = regexs(3)
            local _cap = max(`_d', 2)
            local _lo = "<" + strtrim(string(10^(-`_cap'), "%21`_sep'`_cap'f"))
            local _hi = ">" + strtrim(string(100 - 10^(-`_cap'), "%21`_sep'`_cap'f"))
        }
        local _tol = 1e-9

        if `_scalar' {
            local _text = string(`_sv', `"`format'"')
            local _dec = .
            if `_fixed' & `_sv' > `_tol' & `_sv' < 100 - `_tol' {
                forvalues _k = `=`_d' + 1'/`_cap' {
                    if inlist(real(subinstr("`_text'", ",", ".", .)), 0, 100) {
                        local _text = strtrim(string(`_sv', "%21`_sep'`_k'`_fc'"))
                        local _dec = `_k'
                    }
                }
                if inlist(real(subinstr("`_text'", ",", ".", .)), 0, 100) {
                    local _text = cond(real(subinstr("`_text'", ",", ".", .)) == 0, "`_lo'", "`_hi'")
                    local _dec = `_cap'
                }
            }
            return local text `"`_text'"'
            return scalar decimals = `_dec'
        }
        else {
            marksample touse, novarlist
            local v `varlist'
            tempvar _esc
            quietly {
                gen str32 `generate' = string(`v', `"`format'"') if `touse'
                gen byte `_esc' = 0
                if `_fixed' {
                    replace `_esc' = 1 if `touse' & `v' > `_tol' & `v' < 100 - `_tol'
                }
                if "`decimals'" != "" gen byte `decimals' = .
                if `_fixed' {
                    forvalues _k = `=`_d' + 1'/`_cap' {
                        local _need "`_esc' & inlist(real(subinstr(`generate', ",", ".", .)), 0, 100)"
                        if "`decimals'" != "" replace `decimals' = `_k' if `_need'
                        replace `generate' = strtrim(string(`v', "%21`_sep'`_k'`_fc'")) if `_need'
                    }
                    local _need "`_esc' & inlist(real(subinstr(`generate', ",", ".", .)), 0, 100)"
                    if "`decimals'" != "" replace `decimals' = `_cap' if `_need'
                    replace `generate' = cond(real(subinstr(`generate', ",", ".", .)) == 0, "`_lo'", "`_hi'") if `_need'
                }
            }
        }
    }
    local rc = _rc
    set varabbrev `_orig_varabbrev'
    if `rc' exit `rc'
end
