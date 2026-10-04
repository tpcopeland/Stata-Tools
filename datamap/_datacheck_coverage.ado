*! _datacheck_coverage Version 1.9.0  2026/10/03
*! datacheck coverage(): delivered-file date coverage (a band family)
*! Author: Timothy P Copeland, Karolinska Institutet
*! Program class: rclass

// Spec: datevar lo hi, gap(# | none) [tail(#) years endq(#)]
//
// datevar is a daily (%td) date; lo and hi are bounds (numbers or date
// literals) and gap() is the delivery lag in days.  gap() is required and
// has no default, so an unsourced expectation stops the run.  gap(none) is
// a typed declaration that the plan sources no lag: late_end and early_start
// are then not tested, post no row and never count as passes.  endq(#), with
// 0 < # < 0.5, tests early_start on the #-quantile and late_end on the
// (1-#)-quantile (_pctile's default definition) instead of the raw minimum
// and maximum; gap(none) with endq() is an error.  Checks:
//   outside      the share of dates outside [lo, hi] is at most tail() (default 0)
//   late_end     the last date is at least hi - gap (a truncated delivery fails)
//   early_start  the first date is at most lo + gap
//   year_gap     (years) no calendar year between the first and last date is empty
// Under maskrare the printed extremes are p1 and p99 at month precision.
program define _datacheck_coverage, rclass
    version 16.0
    local _orig_varabbrev = c(varabbrev)
    set varabbrev off
    local nfail = 0
    local anymask = 0
    local vars ""
    capture noisily {
        syntax , SPEC(string) [PARSEonly RF(name) KIND(string) GRP(string) ///
            PFX(string) MASK(integer 0) NSCOPE(real 0)]
        local head `"`spec'"'
        local opts ""
        local cp = strpos(`"`spec'"', ",")
        if `cp' {
            local head = strtrim(substr(`"`spec'"', 1, `cp' - 1))
            local opts = substr(`"`spec'"', `cp' + 1, .)
        }
        if `: word count `head'' != 3 {
            display as error `"coverage() spec must be "datevar lo hi, gap(# | none) [tail(#) years endq(#)]": `spec'"'
            exit 198
        }
        local dv : word 1 of `head'
        local lo : word 2 of `head'
        local hi : word 3 of `head'
        unab dv : `dv', max(1)
        capture confirm numeric variable `dv'
        if _rc {
            display as error "coverage(): `dv' is not numeric"
            exit 109
        }
        local vf : format `dv'
        local vf = subinstr("`vf'", "%-", "%", 1)
        if !(substr("`vf'", 1, 3) == "%td" | substr("`vf'", 1, 2) == "%d") {
            // another date unit needs a conversion, not a display format
            local tl = substr("`vf'", 3, 1)
            if substr("`vf'", 1, 2) == "%t" {
                local cv = cond(strpos("cCmqwhyb", "`tl'") > 0, "; convert it to a daily date with dof`tl'()", "")
                display as error "coverage(): `dv' has a %t`tl' format, not a daily (%td) date`cv'"
            }
            else display as error "coverage(): `dv' must be a daily (%td) date; give it a daily date display format, e.g. format `dv' %td"
            exit 198
        }
        local 0 `", `opts'"'
        capture syntax , GAP(string) [TAIL(real 0) YEARS ENDQ(string)]
        if _rc {
            display as error "coverage(): gap() is required, with the delivery lag in days from the plan; tail() and years are optional"
            exit 198
        }
        local gapnone = (strlower(strtrim(`"`gap'"')) == "none")
        if `gapnone' local gap = 0
        else {
            capture confirm number `gap'
            if _rc {
                display as error "coverage(): gap() is required, with the delivery lag in days from the plan, or gap(none); tail() and years are optional"
                exit 198
            }
        }
        if `gap' < 0 | missing(`gap') | `tail' < 0 | `tail' > 1 {
            display as error "coverage(): gap() must be non-negative and tail() a share between 0 and 1"
            exit 198
        }
        local useq = 0
        if `"`endq'"' != "" {
            capture confirm number `endq'
            if _rc {
                display as error "coverage(): endq() must be a number strictly between 0 and 0.5"
                exit 198
            }
            if `endq' <= 0 | `endq' >= 0.5 {
                display as error "coverage(): endq() must lie strictly between 0 and 0.5"
                exit 198
            }
            if `gapnone' {
                display as error "coverage(): gap(none) tests no end checks, so it cannot be combined with endq()"
                exit 198
            }
            local useq = 1
        }
        // bounds stay in scalars: a decimal round trip through a macro could
        // move a value sitting on a bound to the other side
        tempname LO HI
        _datacheck_bound `dv' `"`lo'"'
        scalar `LO' = r(value)
        _datacheck_bound `dv' `"`hi'"'
        scalar `HI' = r(value)
        local lo_num "`LO'"
        local hi_num "`HI'"
        if `lo_num' > `hi_num' {
            display as error `"coverage(): lower bound exceeds upper bound: `spec'"'
            exit 198
        }
        local vars "`dv'"
        if "`parseonly'" == "" {
            local lotxt = strtrim(string(`lo_num', "%td"))
            local hitxt = strtrim(string(`hi_num', "%td"))
            local gtxt = strtrim(string(`gap', "%12.0g"))
            tempname qlo qhi
            quietly summarize `dv', detail
            local n = r(N)
            local dmin = r(min)
            local dmax = r(max)
            tempname q1 q99
            scalar `q1' = r(p1)
            scalar `q99' = r(p99)
            if `mask' > 0 {
                _datacheck_qshow `dv', value(`q1') mask(`mask') stat(p1)
                local firsttxt "p1 `r(s)'"
                _datacheck_qshow `dv', value(`q99') mask(`mask') stat(p99)
                local lasttxt "p99 `r(s)'"
            }
            else {
                local firsttxt = strtrim(string(`dmin', "%td"))
                local lasttxt = strtrim(string(`dmax', "%td"))
            }
            local emin = `dmin'
            local emax = `dmax'
            if `useq' & `n' > 0 {
                // _pctile's default definition; missing dates are ignored
                quietly _pctile `dv', percentiles(`=100 * `endq'' `=100 * (1 - `endq')')
                scalar `qlo' = r(r1)
                scalar `qhi' = r(r2)
                local pplo = strtrim(string(100 * `endq', "%9.4g"))
                local pphi = strtrim(string(100 * (1 - `endq'), "%9.4g"))
                local emin = `qlo'
                local emax = `qhi'
                if `mask' > 0 {
                    _datacheck_qshow `dv', value(`qlo') mask(`mask') stat(p`pplo')
                    local firsttxt "p`pplo' `r(s)'"
                    _datacheck_qshow `dv', value(`qhi') mask(`mask') stat(p`pphi')
                    local lasttxt "p`pphi' `r(s)'"
                }
                else {
                    local firsttxt = "p`pplo' " + strtrim(string(`emin', "%td"))
                    local lasttxt = "p`pphi' " + strtrim(string(`emax', "%td"))
                }
            }
            local checks "outside late_end early_start"
            if `gapnone' {
                local checks "outside"
                display as text "coverage(`dv'): late_end and early_start not declared (gap(none))"
            }
            if "`years'" != "" local checks "`checks' year_gap"
            foreach ck of local checks {
                local onum = .
                local mins = .
                local om = 0
                if `n' == 0 {
                    local ok = 0
                    local obs "no nonmissing dates"
                    local exp "nonmissing dates"
                    local msg `"`pfx'coverage(`ck'): `dv' has no nonmissing dates"'
                }
                else if "`ck'" == "outside" {
                    quietly count if !missing(`dv') & (`dv' < `lo_num' | `dv' > `hi_num')
                    local nout = r(N)
                    local ok = (`nout' / `n' <= `tail')
                    _datacheck_mshare `nout' `n' `mask'
                    local ocnt "`r(cnt)'"
                    local opct "`r(pcttxt)'"
                    local om = r(masked)
                    if !`om' & `nout' >= 1 local mins = `nout'
                    if !`om' local onum = `nout' / `n'
                    local ttxt = strtrim(string(100 * `tail', "%9.2g"))
                    // a masked share is left out: the count says what can be said
                    local oshr = cond(`om', "", " (`opct')")
                    local obs "`ocnt' dates`oshr' outside"
                    local exp "at most `ttxt'% outside [`lotxt', `hitxt']"
                    local msg `"`pfx'coverage(`ck'): `ocnt' of `dv' dates`oshr' outside [`lotxt', `hitxt'], tail allows `ttxt'%"'
                }
                else if "`ck'" == "late_end" {
                    local cut = `hi_num' - `gap'
                    local ok = (`emax' >= `cut')
                    local cuttxt = strtrim(string(`cut', "%td"))
                    local obs "last `lasttxt'"
                    local exp "last date >= `hitxt' - `gtxt' days (`cuttxt')"
                    if `useq' local exp "`exp', tested on the p`pphi' (endq(`endq'))"
                    if `ok' local msg `"`pfx'coverage(`ck'): `dv' reaches `cuttxt' (last `lasttxt')"'
                    else local msg `"`pfx'coverage(`ck'): `dv' ends before `cuttxt' = `hitxt' - `gtxt' days (last `lasttxt'); truncated delivery?"'
                }
                else if "`ck'" == "early_start" {
                    local cut = `lo_num' + `gap'
                    local ok = (`emin' <= `cut')
                    local cuttxt = strtrim(string(`cut', "%td"))
                    local obs "first `firsttxt'"
                    local exp "first date <= `lotxt' + `gtxt' days (`cuttxt')"
                    if `useq' local exp "`exp', tested on the p`pplo' (endq(`endq'))"
                    if `ok' local msg `"`pfx'coverage(`ck'): `dv' starts by `cuttxt' (first `firsttxt')"'
                    else local msg `"`pfx'coverage(`ck'): `dv' starts after `cuttxt' = `lotxt' + `gtxt' days (first `firsttxt')"'
                }
                else {
                    local y0 = year(`dmin')
                    local y1 = year(`dmax')
                    local empty ""
                    tempvar yy
                    quietly generate int `yy' = year(`dv') if !missing(`dv')
                    forvalues y = `y0'/`y1' {
                        quietly count if `yy' == `y'
                        if r(N) == 0 local empty "`empty' `y'"
                    }
                    quietly drop `yy'
                    local empty = strtrim("`empty'")
                    local ne : word count `empty'
                    local ok = (`ne' == 0)
                    local onum = `ne'
                    local obs = cond(`ok', "no empty year", "no rows in `empty'")
                    local exp "every calendar year between the first and last date has rows"
                    if `ok' local msg `"`pfx'coverage(`ck'): `dv' has rows in every calendar year it spans"'
                    else local msg `"`pfx'coverage(`ck'): `dv' has no rows in `empty'"'
                }
                if `om' local anymask = 1
                if !`ok' local ++nfail
                frame post `rf' ("coverage") ("`kind'") (`ok') ("`ck'") ("`dv'") ///
                    (`"`macval(grp)'"') (`"`obs'"') (`onum') (`"`exp'"') ///
                    (`nscope') ("") (`"`macval(msg)'"') (`mins') (`om')
            }
        }
    }
    local rc = _rc
    set varabbrev `_orig_varabbrev'
    if `rc' exit `rc'
    return local vars "`vars'"
    return scalar nfail = `nfail'
    return scalar masked = `anymask'
end
