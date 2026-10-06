* test_tabcell_v250.do - tabcell rate (incidence rate with its interval),
* tabcell np, nocount (the share alone), and digits()
*
* Oracles, each reached by a route other than tabcell's own:
*   ci(exact)    Stata's cii means <pt> <e>, poisson (Newton's method on the
*                Poisson tails, [R] ci), at levels 95, 90 and 99, including
*                zero events (its one-sided upper limit) and a tiny pt
*   ci(poisson)  strate's saved _Rate/_Lower/_Upper on stset data, and the
*                closed form rate*exp(-/+z/sqrt(e)) written out here
*   both         ratetab's r(estimates) and its printed rate cells on the
*                same events and person-time, collapsed independently
*   nocount      cii proportions <d> <n>, exact (r(lb), r(ub))
* rate-intervals.notes.md (sections 1-3) gives the formulas; the zero-event
* rule is the [R] ci technical note.

clear all
set more off
set varabbrev off
version 17.0

capture log close _tc250
log using "test_tabcell_v250.log", replace text name(_tc250)

local test_count = 0
local pass_count = 0
local fail_count = 0

local qa_dir "`c(pwd)'"
local pkg_dir = regexr("`qa_dir'", "/qa$", "")
local output_dir "`qa_dir'/output"
if "$TABTOOLS_QA_OUTPUT_DIR" != "" local output_dir "$TABTOOLS_QA_OUTPUT_DIR"
capture mkdir "`output_dir'"
capture ado uninstall tabtools
quietly net install tabtools, from("`pkg_dir'") replace
discard
quietly tabtools set clear
do "`qa_dir'/_qa_state.do"

local dash = uchar(8211)

**# R1: ci(exact) equals cii means, poisson (levels 95/90/99, e = 0, tiny pt)
local ++test_count
capture noisily {
    tempname cm clb cub
    local ncell 0
    foreach lv in 95 90 99 {
        foreach e in 0 1 2 5 12 100 1000 {
            foreach pt in 975.6 0.5 12345.678 2.5e-9 {
                quietly cii means `pt' `e', poisson level(`lv')
                scalar `cm' = r(mean)
                scalar `clb' = r(lb)
                scalar `cub' = r(ub)
                assert !missing(`cm', `clb', `cub')
                tabcell rate, e(`e') pt(`pt') per(1000) level(`lv')
                assert !missing(r(rate), r(lb), r(ub))
                assert !missing(1000 * `cm')
                assert reldif(r(rate), 1000 * `cm') < 1e-12
                assert !missing(1000 * `clb')
                assert !missing(r(lb))
                assert reldif(r(lb), 1000 * `clb') < 1e-7
                assert !missing(1000 * `cub')
                assert !missing(r(ub))
                assert reldif(r(ub), 1000 * `cub') < 1e-7
                assert r(level) == `lv' & "`r(citype)'" == "exact" & r(per) == 1000
                if `e' == 0 {
                    * the zero-event limits: 0 and -ln(a/2)/pt
                    assert r(lb) == 0
                    assert !missing(r(ub), -ln((1 - `lv' / 100) / 2) / `pt' * 1000)
                    assert reldif(r(ub), -ln((1 - `lv' / 100) / 2) / `pt' * 1000) < 1e-12
                }
                * the cell, built from cii's numbers in the default %9.1f
                local want = strtrim(string(1000 * `cm', "%9.1f")) + " (" + ///
                    strtrim(string(1000 * `clb', "%9.1f")) + ", " + ///
                    strtrim(string(1000 * `cub', "%9.1f")) + ")"
                assert `"`r(cell)'"' == `"`want'"'
                local ++ncell
            }
        }
    }
    assert `ncell' == 84
    * the tiny-pt cell printed in full with a wide format
    quietly cii means 2.5e-9 3, poisson level(90)
    scalar `cm' = r(mean)
    scalar `clb' = r(lb)
    scalar `cub' = r(ub)
    tabcell rate, e(3) pt(2.5e-9) per(1) level(90) format(%20.0fc)
    local want = strtrim(string(`cm', "%20.0fc")) + " (" + ///
        strtrim(string(`clb', "%20.0fc")) + ", " + strtrim(string(`cub', "%20.0fc")) + ")"
    assert `"`r(cell)'"' == `"`want'"'
    assert `"`r(cell)'"' == "1,200,000,000 (327,076,579, 3,101,462,611)"
    * the documented example
    tabcell rate, e(12) pt(975.6) per(1000)
    assert `"`r(cell)'"' == "12.3 (6.4, 21.5)"
}
if _rc == 0 {
    display as result "  PASS: R1 ci(exact) equals cii means, poisson over 84 cells"
    local ++pass_count
}
else {
    display as error "  FAIL: R1 exact rate limits (rc=`=_rc')"
    local ++fail_count
}

**# R2: ci(poisson) equals strate and the closed form; e = 0 takes the exact limits
local ++test_count
capture noisily {
    clear
    set seed 25010
    quietly set obs 600
    generate byte grp = 1 + mod(_n, 4)
    generate double t = rexponential(1 / (0.2 + 0.15 * grp))
    generate byte d = runiform() < 0.6
    * group 4 has a handful of events only
    replace d = 0 if grp == 4 & _n > 40
    quietly stset t, failure(d)
    foreach lv in 95 90 {
        quietly strate grp, output("`output_dir'/tc250_strate", replace) nolist level(`lv')
        preserve
        quietly use "`output_dir'/tc250_strate", clear
        sort grp
        assert _N == 4
        forvalues i = 1/4 {
            local D = _D[`i']
            tempname Y
            scalar `Y' = _Y[`i']
            tabcell rate, e(`D') pt(`=`Y'') per(1000) ci(poisson) level(`lv')
            assert !missing(r(rate), r(lb), r(ub), _Rate[`i'], _Lower[`i'], _Upper[`i'])
            assert !missing(_Rate[`i'] * 1000)
            assert reldif(r(rate), _Rate[`i'] * 1000) < 1e-10
            assert !missing(_Lower[`i'] * 1000)
            assert !missing(r(lb))
            assert reldif(r(lb), _Lower[`i'] * 1000) < 1e-10
            assert !missing(_Upper[`i'] * 1000)
            assert !missing(r(ub))
            assert reldif(r(ub), _Upper[`i'] * 1000) < 1e-10
            * closed form, written out here
            local z = invnormal(1 - (1 - `lv' / 100) / 2)
            assert !missing(r(lb), `D' / `Y' * 1000 * exp(-`z' / sqrt(`D')))
            assert reldif(r(lb), `D' / `Y' * 1000 * exp(-`z' / sqrt(`D'))) < 1e-10
            assert !missing(r(ub), `D' / `Y' * 1000 * exp(`z' / sqrt(`D')))
            assert reldif(r(ub), `D' / `Y' * 1000 * exp(`z' / sqrt(`D'))) < 1e-10
            assert "`r(citype)'" == "poisson"
        }
        restore
    }
    * no events: strate has no limits; ci(poisson) prints the exact ones
    quietly cii means 975.6 0, poisson
    tempname zub
    scalar `zub' = r(ub)
    tabcell rate, e(0) pt(975.6) per(1000) ci(poisson)
    assert r(rate) == 0 & r(lb) == 0
    assert !missing(r(ub), 1000 * `zub')
    assert reldif(r(ub), 1000 * `zub') < 1e-7
    assert `"`r(cell)'"' == "0.0 (0.0, 3.8)"
    * a non-integer count: refused by the exact interval, accepted here
    tabcell rate, e(2.5) pt(10) per(1000) ci(poisson)
    assert !missing(r(lb), 250 * exp(-invnormal(.975) / sqrt(2.5)))
    assert reldif(r(lb), 250 * exp(-invnormal(.975) / sqrt(2.5))) < 1e-12
    capture tabcell rate, e(2.5) pt(10) per(1000)
    assert _rc == 459
}
if _rc == 0 {
    display as result "  PASS: R2 ci(poisson) equals strate and the closed form"
    local ++pass_count
}
else {
    display as error "  FAIL: R2 log-rate limits (rc=`=_rc')"
    local ++fail_count
}

**# R3: the same numbers as ratetab, rates and printed cells
local ++test_count
capture noisily {
    clear
    set seed 20261005
    quietly set obs 60
    generate long id = _n
    generate byte grp = 1 + mod(_n, 4)
    generate double frail = rgamma(2, 0.5)
    quietly expand 1 + floor(runiform() * 4)
    generate double pt = 0.2 + runiform() * 2
    generate long ev = rpoisson(pt * frail * (0.4 + 0.3 * grp))
    * a group with no events
    quietly replace ev = 0 if grp == 4
    label define _tc250g 1 "Low" 2 "Mid" 3 "High" 4 "None", replace
    label values grp _tc250g
    tempfile raw
    quietly save "`raw'"
    * events and person-time per group, collapsed here, not read from ratetab
    collapse (sum) D = ev Y = pt, by(grp)
    forvalues g = 1/4 {
        local D`g' = D[`g']
        tempname Y`g'
        scalar `Y`g'' = Y[`g']
    }
    assert `D4' == 0 & `D1' > 0
    quietly use "`raw'", clear
    foreach ci in exact poisson {
        foreach lv in 95 90 {
            quietly ratetab grp, events(ev) exposure(pt) per(1000) ci(`ci') ///
                level(`lv') nosmallcells frame(_tc250r, replace)
            matrix E = r(estimates)
            assert rowsof(E) == 4
            forvalues g = 1/4 {
                assert E[`g', 4] == `D`g''
                assert !missing(E[`g', 5], `Y`g'')
                assert reldif(E[`g', 5], `Y`g'') < 1e-12
                tabcell rate, e(`D`g'') pt(`=`Y`g''') per(1000) ci(`ci') level(`lv')
                assert !missing(E[`g', 6], E[`g', 7], E[`g', 8])
                assert !missing(r(rate))
                assert reldif(r(rate), E[`g', 6]) < 1e-12
                assert !missing(r(lb))
                assert !missing(E[`g', 7])
                assert reldif(r(lb), E[`g', 7]) < 1e-12 | (r(lb) == 0 & E[`g', 7] == 0)
                assert !missing(r(ub))
                assert !missing(E[`g', 8])
                assert reldif(r(ub), E[`g', 8]) < 1e-12
                local cell`g' `"`r(cell)'"'
            }
            * the printed cells: each level row holds the tabcell text
            frame _tc250r {
                forvalues g = 1/4 {
                    quietly count if strpos(c4, `"`cell`g''"') == 1
                    assert r(N) == 1
                }
            }
        }
    }
    frame drop _tc250r
    matrix drop E
}
if _rc == 0 {
    display as result "  PASS: R3 rates, limits and cells equal ratetab (exact, poisson; 95, 90)"
    local ++pass_count
}
else {
    display as error "  FAIL: R3 ratetab parity (rc=`=_rc')"
    local ++fail_count
}

**# R4: mincell, generate(), local()/global(), refusals
local ++test_count
capture noisily {
    * masked: no number at all, r() missing, the macros hold the dash
    global TC250_G "stale"
    local lc "stale"
    tabcell rate, e(3) pt(975.6) per(1000) mincell(5) local(lc) global(TC250_G)
    assert `"`r(cell)'"' == "`dash'" & `"`lc'"' == "`dash'" & `"$TC250_G"' == "`dash'"
    assert missing(r(rate)) & missing(r(lb)) & missing(r(ub)) & r(missing) == 0
    * at the threshold and at zero: printed
    tabcell rate, e(5) pt(975.6) per(1000) mincell(5)
    assert `"`r(cell)'"' == "5.1 (1.7, 12.0)"
    tabcell rate, e(0) pt(975.6) per(1000) mincell(5)
    assert `"`r(cell)'"' == "0.0 (0.0, 3.8)"
    * the column form equals the scalar form row by row
    clear
    quietly set obs 8
    generate double e = cond(_n == 1, 0, cond(_n == 2, 3, 10 * _n))
    generate double pt = 100 * _n + 0.5
    replace pt = 0 in 8
    replace e = 0 in 8
    replace e = . in 7
    tabcell rate, e(e) pt(pt) per(1000) mincell(5) missing("n/a") generate(rc)
    assert r(N) == 6 & r(N_missing) == 2
    forvalues i = 1/6 {
        tabcell rate, e(`=e[`i']') pt(`=pt[`i']') per(1000) mincell(5)
        assert rc[`i'] == `"`r(cell)'"'
    }
    assert rc[2] == "`dash'" & rc[7] == "n/a" & rc[8] == "n/a"
    * no digit leaks from a masked row
    assert !ustrregexm(rc[2], "[0-9]")
    * column form under ci(poisson) and level(90)
    tabcell rate in 1/6, e(e) pt(pt) per(100) ci(poisson) level(90) generate(rp)
    forvalues i = 1/6 {
        tabcell rate, e(`=e[`i']') pt(`=pt[`i']') per(100) ci(poisson) level(90)
        assert rp[`i'] == `"`r(cell)'"'
    }
    * refusals
    capture tabcell rate, e(3) pt(10)
    assert _rc == 198
    capture tabcell rate, e(3) pt(10) per(0)
    assert _rc == 198
    capture tabcell rate, e(3) pt(10) per(abc)
    assert _rc == 198
    capture tabcell rate, e(3) pt(0) per(1000)
    assert _rc == 198
    capture tabcell rate, e(-1) pt(10) per(1000)
    assert _rc == 198
    capture tabcell rate, e(0) pt(0) per(1000)
    assert _rc == 459
    tabcell rate, e(0) pt(0) per(1000) missing("")
    assert `"`r(cell)'"' == "" & r(missing) == 1
    capture tabcell rate, e(3) pt(10) per(1000) ci(wald)
    assert _rc == 198
    capture tabcell rate, e(3) pt(10) per(1000) nformat(%9.0f)
    assert _rc == 198
    capture tabcell np, n(3) d(10) pt(4)
    assert _rc == 198
    capture tabcell np, n(3) d(10) ci(poisson)
    assert _rc == 198
    * a failed call clears the macro it names
    local lc "stale"
    capture tabcell rate, e(3) pt(0) per(1000) local(lc)
    assert _rc == 198 & `"`lc'"' == ""
    macro drop TC250_G
}
if _rc == 0 {
    display as result "  PASS: R4 rate mincell, generate(), local()/global(), refusals"
    local ++pass_count
}
else {
    display as error "  FAIL: R4 rate options (rc=`=_rc')"
    local ++fail_count
}

**# N1: np, nocount prints the share and its exact interval alone
local ++test_count
capture noisily {
    tempname plb pub
    foreach nd in "3 30" "0 20" "20 20" "7 1234" {
        gettoken n d : nd
        local d = strtrim("`d'")
        foreach lv in 95 90 {
            quietly cii proportions `d' `n', exact level(`lv')
            scalar `plb' = r(lb)
            scalar `pub' = r(ub)
            tabcell np, n(`n') d(`d') ci(exact) nocount level(`lv')
            assert !missing(r(lb), 100 * `plb')
            assert reldif(r(lb), 100 * `plb') < 1e-10 | (r(lb) == 0 & `plb' == 0)
            assert !missing(r(ub), 100 * `pub')
            assert reldif(r(ub), 100 * `pub') < 1e-10
            assert !missing(r(pct), 100 * `n' / `d')
            assert reldif(r(pct), 100 * `n' / `d') < 1e-12 | (r(pct) == 0 & `n' == 0)
            local want = strtrim(string(100 * `n' / `d', "%4.1f")) + " (" + ///
                strtrim(string(100 * `plb', "%4.1f")) + ", " + ///
                strtrim(string(100 * `pub', "%4.1f")) + ")"
            assert `"`r(cell)'"' == `"`want'"'
        }
    }
    tabcell np, n(3) d(30) ci(exact) nocount
    assert `"`r(cell)'"' == "10.0 (2.1, 26.5)"
    tabcell np, n(3) d(30) ci(exact) nocount sep(" to ") pformat(%5.2f)
    assert `"`r(cell)'"' == "10.00 (2.11 to 26.53)"
    * without ci(): the percentage alone
    tabcell np, n(3) d(30) nocount
    assert `"`r(cell)'"' == "10.0"
    * the count form is unchanged
    tabcell np, n(3) d(30) ci(exact)
    assert `"`r(cell)'"' == "3 (10.0; 2.1, 26.5)"
}
if _rc == 0 {
    display as result "  PASS: N1 nocount share and exact limits equal cii proportions"
    local ++pass_count
}
else {
    display as error "  FAIL: N1 nocount (rc=`=_rc')"
    local ++fail_count
}

**# N2: nocount with mincell never leaks the masked count
local ++test_count
capture noisily {
    * the percentage of a known denominator is the count: 3/30 = 10.0%
    tabcell np, n(3) d(30) ci(exact) nocount mincell(5)
    assert `"`r(cell)'"' == "`dash'"
    assert missing(r(pct)) & missing(r(lb)) & missing(r(ub))
    tabcell np, n(3) d(30) nocount mincell(5)
    assert `"`r(cell)'"' == "`dash'"
    tabcell np, n(5) d(30) nocount mincell(5)
    assert `"`r(cell)'"' == "16.7"
    tabcell np, n(0) d(30) ci(exact) nocount mincell(5)
    assert `"`r(cell)'"' == "0.0 (0.0, 11.6)"
    * zero denominator: nothing to compute
    capture tabcell np, n(0) d(0) nocount
    assert _rc == 459
    tabcell np, n(0) d(0) nocount missing("n/a")
    assert `"`r(cell)'"' == "n/a" & r(missing) == 1
    capture tabcell np, n(2) d(0) nocount
    assert _rc == 198
    * generate(): the column equals the scalar cells; masked rows hold no digit
    clear
    quietly set obs 7
    generate double n = _n - 1
    generate double d = 30
    replace d = 0 in 1
    tabcell np, n(n) d(d) ci(exact) nocount mincell(5) missing("") generate(s)
    assert r(N_missing) == 1 & s[1] == ""
    forvalues i = 2/7 {
        tabcell np, n(`=n[`i']') d(30) ci(exact) nocount mincell(5)
        assert s[`i'] == `"`r(cell)'"'
        if inrange(n[`i'], 1, 4) assert s[`i'] == "`dash'"
    }
    quietly count if inrange(n, 1, 4) & ustrregexm(s, "[0-9]")
    assert r(N) == 0
    * local() and global()
    global TC250_S "stale"
    local ls "stale"
    tabcell np, n(3) d(30) ci(exact) nocount local(ls) global(TC250_S)
    assert `"`ls'"' == "10.0 (2.1, 26.5)" & `"$TC250_S"' == "10.0 (2.1, 26.5)"
    tabcell np, n(2) d(30) ci(exact) nocount mincell(5) local(ls) global(TC250_S)
    assert `"`ls'"' == "`dash'" & `"$TC250_S"' == "`dash'"
    macro drop TC250_S
    * nocount belongs to np
    capture tabcell n, n(3) nocount
    assert _rc == 198
    capture tabcell enp, e(3) n(30) nocount
    assert _rc == 198
}
if _rc == 0 {
    display as result "  PASS: N2 nocount masking, zero denominator, generate/local/global"
    local ++pass_count
}
else {
    display as error "  FAIL: N2 nocount masking (rc=`=_rc')"
    local ++fail_count
}

**# D1: digits() is format(%9.#f) for est, iqr and rate
local ++test_count
capture noisily {
    tabcell est, b(1.23456) ll(1.01) ul(1.5) digits(3)
    assert `"`r(cell)'"' == "1.235 (1.010, 1.500)"
    tabcell iqr, median(20) q1(18) q3(25) digits(0)
    assert `"`r(cell)'"' == "20 (18, 25)"
    tabcell rate, e(12) pt(975.6) per(1000) digits(2)
    assert `"`r(cell)'"' == "12.30 (6.36, 21.49)"
    capture tabcell est, b(1) ll(0) ul(2) digits(2) format(%9.2f)
    assert _rc == 198
    capture tabcell p, p(0.04) digits(2)
    assert _rc == 198
    capture tabcell est, b(1) ll(0) ul(2) digits(11)
    assert _rc == 198
}
if _rc == 0 {
    display as result "  PASS: D1 digits()"
    local ++pass_count
}
else {
    display as error "  FAIL: D1 digits() (rc=`=_rc')"
    local ++fail_count
}

**# H1: caller state untouched on success and on refusal
local ++test_count
capture noisily {
    set varabbrev on
    sysuse auto, clear
    qa_state_snapshot, tag(tc250)
    tabcell rate, e(12) pt(975.6) per(1000) ci(poisson)
    qa_state_compare, tag(tc250)
    qa_state_snapshot, tag(tc250)
    capture tabcell rate, e(2.5) pt(10) per(1000)
    local call_rc = _rc
    qa_state_compare, tag(tc250)
    assert `call_rc' == 459
    qa_state_snapshot, tag(tc250)
    tabcell np, n(3) d(30) ci(exact) nocount mincell(5)
    qa_state_compare, tag(tc250)
    assert c(varabbrev) == "on"
}
if _rc == 0 {
    display as result "  PASS: H1 session fingerprint unchanged"
    local ++pass_count
}
else {
    display as error "  FAIL: H1 session fingerprint (rc=`=_rc')"
    local ++fail_count
}
set varabbrev off
capture label drop _tc250g

display "RESULT: test_tabcell_v250 tests=`test_count' pass=`pass_count' fail=`fail_count'"
log close _tc250
if `fail_count' > 0 exit 1
