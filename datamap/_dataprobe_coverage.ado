*! _dataprobe_coverage Version 2.0.0  2026/11/10
*! dataprobe coverage(): delivered-file date coverage (a band family)
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
//
// 2.1.0 (F8, P2):
//   unit(date | year | yyyymmdd)  the unit the values are in, declared
//       instead of read from the display format, which is never changed.
//       Without it the variable must carry a daily format, as before.
//       unit(date) is a day count (Stata's %td scale, 01jan0100 to
//       31dec9999); unit(year) an integer calendar year 100-9999, with lo,
//       hi and gap() in years; unit(yyyymmdd) an 8-digit number such as
//       20200131 (long or double; a float cannot hold 8 digits), read as a
//       daily date, with lo and hi given as YYYYMMDD numbers or dates.  A
//       nonmissing value that is not valid in the unit (month 13, day 32,
//       30 February, year 1.5) fails every declared check, with the masked
//       count of such values and no value printed.
//   sides  the outside row also shows the dates before lo and after hi,
//       each count masked against the outside count; withheld when the
//       outside count itself is masked.  r(outside_low) and
//       r(outside_high) are returned (raw) whether or not sides is given.
//   dropoff(#)  0 < # <= 100: the check dropoff fails a year whose dates
//       inside [lo, hi] number fewer than #% of the median of up to 5
//       complete calendar years immediately before it (a year is complete
//       when [lo, hi] holds all of it).  Every year with at least 3 such
//       years before it is tested, through the year of hi.  A partial final
//       year (hi before 31 December) is prorated: its threshold is
//       multiplied by the share of that year's days inside [lo, hi].  A
//       count at exactly #% passes.  A year whose reference median is 0 is
//       not tested and is named as such; the check fails when no year is
//       tested.  Counts are never printed: the row names the years.  Bounds
//       that leave no testable year are r(198).
//   year_gap and dropoff count the rows per year in one tabulate pass.
program define _dataprobe_coverage, rclass
    version 16.0
    local _orig_varabbrev = c(varabbrev)
    set varabbrev off
    local nfail = 0
    local anymask = 0
    local vars ""
    local n_lo = .
    local n_hi = .
    local n_drop = .
    local sides ""
    capture noisily {
        syntax , SPEC(string) [PARSEonly RF(name) KIND(string) GRP(string) ///
            PFX(string) MASK(integer 0) NSCOPE(real 0) EXCLuded]
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
        // unit() is read first, so a declared unit lifts the format gate;
        // the full option parse below keeps its error order
        local unit ""
        local 0 `", `opts'"'
        capture syntax , [UNIT(string) *]
        if !_rc local unit = strlower(strtrim(`"`unit'"'))
        if `"`unit'"' != "" & !inlist(`"`unit'"', "date", "year", "yyyymmdd") {
            display as error "coverage(): unit() must be date, year, or yyyymmdd"
            exit 198
        }
        local isdaily = (substr("`vf'", 1, 3) == "%td" | substr("`vf'", 1, 2) == "%d")
        if "`unit'" != "" & substr("`vf'", 1, 2) == "%t" & !`isdaily' & ///
            !("`unit'" == "year" & substr("`vf'", 1, 3) == "%ty") {
            local tl = substr("`vf'", 3, 1)
            display as error "coverage(): `dv' has a %t`tl' format, which contradicts unit(`unit')"
            exit 198
        }
        if "`unit'" != "" & "`unit'" != "date" & `isdaily' {
            display as error "coverage(): `dv' has a daily (%td) format, which contradicts unit(`unit'); use unit(date) or no unit()"
            exit 198
        }
        if "`unit'" == "yyyymmdd" & "`: type `dv''" == "float" {
            display as error "coverage(): unit(yyyymmdd) needs a long or double variable; a float holds only 7 digits exactly, so `dv' may already be rounded"
            exit 198
        }
        if "`unit'" == "" & !`isdaily' {
            // another date unit needs a conversion, not a display format
            local tl = substr("`vf'", 3, 1)
            if substr("`vf'", 1, 2) == "%t" {
                local cv = cond(strpos("cCmqwhyb", "`tl'") > 0, "; convert it to a daily date with dof`tl'()", "")
                display as error "coverage(): `dv' has a %t`tl' format, not a daily (%td) date`cv'"
            }
            else {
                display as error "coverage(): `dv' must be a daily (%td) date; give it a daily date display format, e.g. format `dv' %td"
                display as error "  or declare the unit its values are in: unit(date), unit(year), or unit(yyyymmdd)"
            }
            exit 198
        }
        local 0 `", `opts'"'
        capture syntax , GAP(string) [TAIL(real 0) SIDES YEARS DROPoff(string) ENDQ(string) UNIT(string)]
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
        local unit = strlower(strtrim(`"`unit'"'))
        local dpct = .
        if `"`dropoff'"' != "" {
            capture confirm number `dropoff'
            if _rc {
                display as error "coverage(): dropoff() must be a percentage greater than 0 and at most 100"
                exit 198
            }
            if `dropoff' <= 0 | `dropoff' > 100 {
                display as error "coverage(): dropoff() must be a percentage greater than 0 and at most 100"
                exit 198
            }
            local dpct = `dropoff'
        }
        // the values on the scale the checks use: the variable itself, or a
        // daily (or yearly) copy in a temporary variable; the variable's own
        // format and values are never changed.  ninv counts nonmissing
        // values that are not valid in the declared unit.
        local cvar "`dv'"
        local dfmt "%td"
        local gunit "days"
        local ninv = 0
        if "`unit'" == "year" {
            local dfmt "%ty"
            local gunit "years"
        }
        if "`unit'" != "" & !("`unit'" == "date" & `isdaily') {
            tempvar cvar
            if "`unit'" == "yyyymmdd" {
                quietly generate double `cvar' = mdy(mod(floor(`dv' / 100), 100), mod(`dv', 100), ///
                    floor(`dv' / 10000)) if !missing(`dv') & `dv' == floor(`dv') & ///
                    `dv' >= 1000101 & `dv' <= 99991231
            }
            else quietly generate double `cvar' = `dv'
            format `cvar' `dfmt'
        }
        if "`unit'" != "" & "`parseonly'" == "" {
            if "`unit'" == "yyyymmdd" quietly count if !missing(`dv') & missing(`cvar')
            else if "`unit'" == "year" {
                quietly count if !missing(`dv') & (`dv' != floor(`dv') | `dv' < 100 | `dv' > 9999)
            }
            else quietly count if !missing(`dv') & (`dv' < -679350 | `dv' > 2936549)
            local ninv = r(N)
        }
        // bounds stay in scalars: a decimal round trip through a macro could
        // move a value sitting on a bound to the other side
        tempname LO HI
        foreach _b in lo hi {
            local _bu = upper("`_b'")
            local _braw = strtrim(subinstr(`"``_b''"', char(34), "", .))
            if "`unit'" == "yyyymmdd" & real(`"`_braw'"') < . {
                // a plain number is a YYYYMMDD bound, read as the values are
                local _bv = real(`"`_braw'"')
                scalar ``_bu'' = .
                if `_bv' == floor(`_bv') & `_bv' >= 1000101 & `_bv' <= 99991231 {
                    scalar ``_bu'' = mdy(mod(floor(`_bv' / 100), 100), mod(`_bv', 100), floor(`_bv' / 10000))
                }
                if missing(``_bu'') {
                    display as error `"coverage(): bound `_braw' is not a valid YYYYMMDD date under unit(yyyymmdd): `spec'"'
                    exit 198
                }
            }
            else {
                _dataprobe_bound `cvar' `"``_b''"'
                scalar ``_bu'' = r(value)
            }
        }
        local lo_num "`LO'"
        local hi_num "`HI'"
        if missing(`lo_num') {
            display as error `"coverage(): lower bound is missing; give a date: `spec'"'
            exit 198
        }
        if missing(`hi_num') {
            display as error `"coverage(): upper bound is missing; give a date: `spec'"'
            exit 198
        }
        if `lo_num' > `hi_num' {
            display as error `"coverage(): lower bound exceeds upper bound: `spec'"'
            exit 198
        }
        // dropoff(): the tested years and their reference years follow from
        // lo and hi alone, so a window too short to test stops at parse time
        if `dpct' < . {
            if "`unit'" == "year" {
                local Y0 = ceil(`lo_num')
                local Y1 = floor(`hi_num')
            }
            else {
                local Y0 = year(`lo_num')
                local Y1 = year(`hi_num')
            }
            // complete years: [lo, hi] holds all of the year
            local Yc0 = `Y0'
            local Yc1 = `Y1'
            local ddays = .
            // the final year's share of days as numerator / denominator, so
            // the threshold test stays in integer arithmetic
            local dsnum = 1
            local dsden = 1
            if "`unit'" != "year" {
                if mdy(1, 1, `Y0') < `lo_num' local Yc0 = `Y0' + 1
                if mdy(12, 31, `Y1') > `hi_num' {
                    local Yc1 = `Y1' - 1
                    local ddays = floor(`hi_num') - mdy(1, 1, `Y1') + 1
                    local dsnum = `ddays'
                    local dsden = mdy(12, 31, `Y1') - mdy(1, 1, `Y1') + 1
                }
            }
            local Yt0 = `Yc0' + 3
            if missing(`Y0') | missing(`Y1') | `Yt0' > `Y1' {
                display as error `"coverage(): dropoff() needs at least 3 complete calendar years inside [lo, hi] before a tested year: `spec'"'
                exit 198
            }
        }
        local vars "`dv'"
        if "`parseonly'" == "" {
            local lotxt = strtrim(string(`lo_num', "`dfmt'"))
            local hitxt = strtrim(string(`hi_num', "`dfmt'"))
            local gtxt = strtrim(string(`gap', "%12.0g"))
            tempname qlo qhi
            quietly summarize `cvar', detail
            local n = r(N)
            local dmin = r(min)
            local dmax = r(max)
            tempname q1 q99
            scalar `q1' = r(p1)
            scalar `q99' = r(p99)
            if `mask' > 0 {
                _dataprobe_qshow `cvar', value(`q1') mask(`mask') stat(p1)
                local firsttxt "p1 `r(s)'"
                _dataprobe_qshow `cvar', value(`q99') mask(`mask') stat(p99)
                local lasttxt "p99 `r(s)'"
            }
            else {
                local firsttxt = strtrim(string(`dmin', "`dfmt'"))
                local lasttxt = strtrim(string(`dmax', "`dfmt'"))
            }
            local emin = `dmin'
            local emax = `dmax'
            if `useq' & `n' > 0 {
                // _pctile's default definition; missing dates are ignored
                quietly _pctile `cvar', percentiles(`=100 * `endq'' `=100 * (1 - `endq')')
                scalar `qlo' = r(r1)
                scalar `qhi' = r(r2)
                local pplo = strtrim(string(100 * `endq', "%9.4g"))
                local pphi = strtrim(string(100 * (1 - `endq'), "%9.4g"))
                local emin = `qlo'
                local emax = `qhi'
                if `mask' > 0 {
                    _dataprobe_qshow `cvar', value(`qlo') mask(`mask') stat(p`pplo')
                    local firsttxt "p`pplo' `r(s)'"
                    _dataprobe_qshow `cvar', value(`qhi') mask(`mask') stat(p`pphi')
                    local lasttxt "p`pphi' `r(s)'"
                }
                else {
                    local firsttxt = "p`pplo' " + strtrim(string(`emin', "`dfmt'"))
                    local lasttxt = "p`pphi' " + strtrim(string(`emax', "`dfmt'"))
                }
            }
            // exclude(): the first and last dates are contents of the
            // variable, withheld as inrange() withholds its extremes
            if "`excluded'" != "" {
                local firsttxt "[excluded]"
                local lasttxt "[excluded]"
            }
            local checks "outside late_end early_start"
            if `gapnone' {
                local checks "outside"
                display as text "coverage(`dv'): late_end and early_start not declared (gap(none))"
            }
            if "`years'" != "" local checks "`checks' year_gap"
            if `dpct' < . local checks "`checks' dropoff"
            // a year as the checks count it
            local yexp = cond("`unit'" == "year", "`cvar'", "year(`cvar')")
            if `ninv' > 0 {
                quietly count if !missing(`dv')
                _dataprobe_mcount `ninv' `mask' `r(N)'
                local invs "`r(s)'"
                local invm = r(masked)
                local ulab = cond("`unit'" == "yyyymmdd", "a YYYYMMDD calendar date", ///
                    cond("`unit'" == "year", "a whole year from 100 to 9999", ///
                    "a day count from 01jan0100 to 31dec9999"))
            }
            foreach ck of local checks {
                local onum = .
                local mins = .
                local om = 0
                if `ninv' > 0 {
                    // fail closed: no check runs on values the unit cannot
                    // read, and none of them is printed
                    local ok = 0
                    local om = `invm'
                    if !`om' local mins = `ninv'
                    local obs "`invs' values not valid in unit(`unit')"
                    local exp "every value `ulab'"
                    local msg `"`pfx'coverage(`ck'): `invs' of `dv' values are not `ulab' (unit(`unit')); not tested"'
                }
                else if `n' == 0 {
                    local ok = 0
                    local obs "no nonmissing dates"
                    local exp "nonmissing dates"
                    local msg `"`pfx'coverage(`ck'): `dv' has no nonmissing dates"'
                }
                else if "`ck'" == "outside" {
                    // the two sides counted apart (2.1.0, F8); their sum
                    // is the outside count, as one count gave it before
                    quietly count if !missing(`cvar') & `cvar' < `lo_num'
                    local n_lo = r(N)
                    quietly count if !missing(`cvar') & `cvar' > `hi_num'
                    local n_hi = r(N)
                    local nout = `n_lo' + `n_hi'
                    local ok = (`nout' / `n' <= `tail')
                    _dataprobe_mshare `nout' `n' `mask'
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
                    if "`sides'" != "" {
                        // each side is masked against the outside count it
                        // adds up to, so a small side withholds the other
                        // ("all but <m"); a masked outside count withholds
                        // both.  The extremes outside are never printed.
                        if `om' local stxt "sides withheld"
                        else {
                            _dataprobe_mcount `n_lo' `mask' `nout'
                            local slo "`r(s)'"
                            local sm1 = r(masked)
                            _dataprobe_mcount `n_hi' `mask' `nout'
                            local shi "`r(s)'"
                            local sm2 = r(masked)
                            if `sm1' | `sm2' {
                                local om = 1
                                local onum = .
                            }
                            if !`sm1' & `n_lo' >= 1 local mins = min(`mins', `n_lo')
                            if !`sm2' & `n_hi' >= 1 local mins = min(`mins', `n_hi')
                            local stxt "`slo' before `lotxt', `shi' after `hitxt'"
                        }
                        local obs "`ocnt' dates`oshr' outside (`stxt')"
                        local msg `"`pfx'coverage(`ck'): `ocnt' of `dv' dates`oshr' outside [`lotxt', `hitxt'] (`stxt'), tail allows `ttxt'%"'
                    }
                }
                else if "`ck'" == "late_end" {
                    local cut = `hi_num' - `gap'
                    local ok = (`emax' >= `cut')
                    local cuttxt = strtrim(string(`cut', "`dfmt'"))
                    local obs "last `lasttxt'"
                    local exp "last date >= `hitxt' - `gtxt' `gunit' (`cuttxt')"
                    if `useq' local exp "`exp', tested on the p`pphi' (endq(`endq'))"
                    // a failure without the mask: the last date at full
                    // precision beside it (12:00 on the cut day prints as
                    // the cut day)
                    if !`ok' & `mask' == 0 & "`excluded'" == "" {
                        _dataprobe_datefull `=regexr(string(`emax', "%21x"), "^[+]", "")' `dfmt'
                        local lasttxt `"`r(s)'"'
                        if `useq' local lasttxt `"p`pphi' `lasttxt'"'
                        local obs "last `lasttxt'"
                    }
                    if `ok' local msg `"`pfx'coverage(`ck'): `dv' reaches `cuttxt' (last `lasttxt')"'
                    else local msg `"`pfx'coverage(`ck'): `dv' ends before `cuttxt' = `hitxt' - `gtxt' `gunit' (last `lasttxt'); truncated delivery?"'
                }
                else if "`ck'" == "early_start" {
                    local cut = `lo_num' + `gap'
                    local ok = (`emin' <= `cut')
                    local cuttxt = strtrim(string(`cut', "`dfmt'"))
                    local obs "first `firsttxt'"
                    local exp "first date <= `lotxt' + `gtxt' `gunit' (`cuttxt')"
                    if `useq' local exp "`exp', tested on the p`pplo' (endq(`endq'))"
                    if !`ok' & `mask' == 0 & "`excluded'" == "" {
                        _dataprobe_datefull `=regexr(string(`emin', "%21x"), "^[+]", "")' `dfmt'
                        local firsttxt `"`r(s)'"'
                        if `useq' local firsttxt `"p`pplo' `firsttxt'"'
                        local obs "first `firsttxt'"
                    }
                    if `ok' local msg `"`pfx'coverage(`ck'): `dv' starts by `cuttxt' (first `firsttxt')"'
                    else local msg `"`pfx'coverage(`ck'): `dv' starts after `cuttxt' = `lotxt' + `gtxt' `gunit' (first `firsttxt')"'
                }
                else if "`ck'" == "year_gap" {
                    local y0 = cond("`unit'" == "year", `dmin', year(`dmin'))
                    local y1 = cond("`unit'" == "year", `dmax', year(`dmax'))
                    local empty ""
                    tempvar yy
                    tempname YR
                    quietly generate int `yy' = `yexp' if !missing(`cvar')
                    // the years present in one tabulate pass (2.1.0, P2),
                    // not a count per year
                    quietly tabulate `yy', matrow(`YR')
                    forvalues i = 1/`=rowsof(`YR')' {
                        local _h`=`YR'[`i', 1]' = 1
                    }
                    forvalues y = `y0'/`y1' {
                        if "`_h`y''" == "" local empty "`empty' `y'"
                    }
                    quietly drop `yy'
                    local empty = strtrim("`empty'")
                    local ne : word count `empty'
                    local ok = (`ne' == 0)
                    local onum = `ne'
                    // exclude(): the count of empty years, not which ones
                    if "`excluded'" != "" & !`ok' local empty "`ne' year(s) ([excluded])"
                    local obs = cond(`ok', "no empty year", "no rows in `empty'")
                    local exp "every calendar year between the first and last date has rows"
                    if `ok' local msg `"`pfx'coverage(`ck'): `dv' has rows in every calendar year it spans"'
                    else local msg `"`pfx'coverage(`ck'): `dv' has no rows in `empty'"'
                }
                else {
                    // dropoff: the rows per year inside [lo, hi], one pass
                    forvalues y = `Y0'/`Y1' {
                        local _w`y' = 0
                    }
                    tempvar yw
                    tempname WR WC REF MED
                    quietly generate int `yw' = `yexp' if !missing(`cvar') & ///
                        `cvar' >= `lo_num' & `cvar' <= `hi_num'
                    quietly count if !missing(`yw')
                    if r(N) > 0 {
                        quietly tabulate `yw', matrow(`WR') matcell(`WC')
                        forvalues i = 1/`=rowsof(`WR')' {
                            local _w`=`WR'[`i', 1]' = `WC'[`i', 1]
                        }
                    }
                    quietly drop `yw'
                    local low ""
                    local nref0 ""
                    forvalues y = `Yt0'/`Y1' {
                        local r0 = max(`Yc0', `y' - 5)
                        local r1 = min(`Yc1', `y' - 1)
                        matrix `REF' = J(1, `r1' - `r0' + 1, .)
                        forvalues t = `r0'/`r1' {
                            matrix `REF'[1, `t' - `r0' + 1] = `_w`t''
                        }
                        mata: st_numscalar("`MED'", mean((sort(st_matrix("`REF'")', 1))[(floor((cols(st_matrix("`REF'")) + 1) / 2), ceil((cols(st_matrix("`REF'")) + 1) / 2))]))
                        // a reference median of 0 gives no threshold: the
                        // year is not tested (early_start and year_gap
                        // report the empty reference years)
                        if scalar(`MED') == 0 {
                            local nref0 "`nref0' `y'"
                            continue
                        }
                        // count < # / 100 * median * share, multiplied out
                        // so the count side is an integer; the relative
                        // 1e-12 absorbs the binary rounding of a decimal #,
                        // so a count at exactly #% is never below it
                        local _fn = cond(`y' == `Y1', `dsnum', 1)
                        local _fd = cond(`y' == `Y1', `dsden', 1)
                        if 100 * `_w`y'' * `_fd' < `dpct' * scalar(`MED') * `_fn' * (1 - 1e-12) {
                            local low "`low' `y'"
                        }
                    }
                    local low = strtrim("`low'")
                    local nref0 = strtrim("`nref0'")
                    local n_drop : word count `low'
                    local n_ref0 : word count `nref0'
                    local n_test = `Y1' - `Yt0' + 1 - `n_ref0'
                    // fail closed: a run in which no year had a reference
                    // median above 0 tested nothing
                    local ok = (`n_drop' == 0 & `n_test' > 0)
                    local onum = `n_drop'
                    local dtxt = strtrim(string(`dpct', "%9.4g"))
                    // exclude(): the count of years, not which ones
                    if "`excluded'" != "" & `n_drop' > 0 local low "`n_drop' year(s) ([excluded])"
                    if "`excluded'" != "" & `n_ref0' > 0 local nref0 "`n_ref0' year(s) ([excluded])"
                    local obs = cond(`n_drop' == 0, "no year below `dtxt'% of its reference median", ///
                        "below `dtxt'% of the reference median in `low'")
                    if `n_test' == 0 local obs "no year tested"
                    if `n_ref0' > 0 local obs "`obs'; not tested (reference median 0): `nref0'"
                    local exp "each year `Yt0'-`Y1' has at least `dtxt'% of the median rows of the up to 5 complete years before it"
                    if `ddays' < . local exp "`exp' (`Y1' prorated to its `ddays' days inside the window)"
                    if `n_test' == 0 local msg `"`pfx'coverage(`ck'): `dv' has no rows in the reference years of any year `Yt0'-`Y1'; not tested"'
                    else if `ok' local msg `"`pfx'coverage(`ck'): `dv' has no year below `dtxt'% of its reference median, `Yt0'-`Y1'"'
                    else local msg `"`pfx'coverage(`ck'): `dv' falls below `dtxt'% of the median of the years before it in `low'"'
                    if `n_test' > 0 & `n_ref0' > 0 local msg `"`msg' (not tested, reference median 0: `nref0')"'
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
    // 2.1.0 (F8): raw, as every dataprobe stored result
    return scalar outside_low = `n_lo'
    return scalar outside_high = `n_hi'
    return scalar dropoff_n = `n_drop'
    return scalar sides = ("`sides'" != "")
end
