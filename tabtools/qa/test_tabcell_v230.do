* test_tabcell_v230.do - tabcell (F1, R2, P1), tabtools 2.3.0
* Oracles: Stata's own r(table), lincom/nlcom r(), invnormal/invttail by hand,
* hand-built strings, and regtab's printed p-value text for the same p (the
* p rule's authority). Every option: happy path, refusal, known answer.

clear all
set more off
set varabbrev off
version 17.0

capture log close _tc230
log using "test_tabcell_v230.log", replace text name(_tc230)

local qa_dir "`c(pwd)'"
local pkg_dir = regexr("`qa_dir'", "/qa$", "")
capture ado uninstall tabtools
quietly net install tabtools, from("`pkg_dir'") replace
discard

local pass_count = 0
local fail_count = 0

capture program drop _tc_clear_r
program define _tc_clear_r, rclass
    version 17.0
end

capture program drop _tc_post
program define _tc_post, eclass
    version 17.0
    args bval
    tempname B V
    matrix `B' = (`bval')
    matrix colnames `B' = x
    matrix `V' = (1)
    matrix colnames `V' = x
    matrix rownames `V' = x
    ereturn post `B' `V', obs(100) depname(y)
    ereturn local cmd "tc_post"
end

**# T1: e() source equals r(table), t interval (regress) and level()
capture noisily {
    sysuse auto, clear
    quietly regress price mpg weight
    matrix T = r(table)
    local want = strtrim(string(T[1,1], "%9.2f")) + " (" + strtrim(string(T[5,1], "%9.2f")) + ", " + strtrim(string(T[6,1], "%9.2f")) + ")"
    tabcell est mpg
    assert `"`r(cell)'"' == `"`want'"'
    assert !missing(r(lb), T[5,1], r(ub), T[6,1])
    assert reldif(r(lb), T[5,1]) < 1e-12 & reldif(r(ub), T[6,1]) < 1e-12
    assert r(level) == 95 & "`r(source)'" == "e()" & r(missing) == 0
    * level(90) by hand with the t quantile
    local q = invttail(e(df_r), 0.05)
    local lo = _b[mpg] - `q' * _se[mpg]
    tabcell est mpg, level(90)
    assert !missing(r(lb), `lo')
    assert reldif(r(lb), `lo') < 1e-12 & r(level) == 90
}
if _rc == 0 {
    display as result "  PASS: T1 e() source equals r(table); level(90) uses invttail"
    local ++pass_count
}
else {
    display as error "  FAIL: T1 e() source (rc=`=_rc')"
    local ++fail_count
}

**# T2: eform equals logit, or r(table) (normal interval)
capture noisily {
    sysuse auto, clear
    quietly logit foreign mpg, or
    matrix T = r(table)
    local want = strtrim(string(T[1,1], "%4.2f")) + " (" + strtrim(string(T[5,1], "%4.2f")) + " to " + strtrim(string(T[6,1], "%4.2f")) + ")"
    quietly logit foreign mpg
    tabcell est mpg, eform format(%4.2f) sep(" to ")
    assert `"`r(cell)'"' == `"`want'"'
    assert !missing(r(estimate), exp(_b[mpg]))
    assert reldif(r(estimate), exp(_b[mpg])) < 1e-12
}
if _rc == 0 {
    display as result "  PASS: T2 eform equals logit, or; sep() reaches the cell"
    local ++pass_count
}
else {
    display as error "  FAIL: T2 eform (rc=`=_rc')"
    local ++fail_count
}

**# T3: lincom (stored limits; recomputed at another level), nlcom
capture noisily {
    sysuse auto, clear
    quietly regress price mpg weight
    quietly lincom mpg + 2*weight
    local lb = r(lb)
    local ub = r(ub)
    local est = r(estimate)
    local se = r(se)
    local df = r(df)
    tabcell est, lincom format(%12.4f)
    assert `"`r(cell)'"' == strtrim(string(`est', "%12.4f")) + " (" + strtrim(string(`lb', "%12.4f")) + ", " + strtrim(string(`ub', "%12.4f")) + ")"
    assert "`r(source)'" == "lincom"
    quietly lincom mpg + 2*weight
    tabcell est, lincom level(80)
    assert !missing(r(lb), `est' - invttail(`df', 0.10) * `se')
    assert reldif(r(lb), `est' - invttail(`df', 0.10) * `se') < 1e-12
    quietly logit foreign mpg
    quietly nlcom (rr: exp(_b[mpg])) (k: _b[mpg] * 2)
    matrix NB = r(b)
    matrix NV = r(V)
    tabcell est k, nlcom
    assert !missing(r(estimate), NB[1,2])
    assert reldif(r(estimate), NB[1,2]) < 1e-12
    assert !missing(r(ub), NB[1,2] + invnormal(.975) * sqrt(NV[2,2]))
    assert reldif(r(ub), NB[1,2] + invnormal(.975) * sqrt(NV[2,2])) < 1e-12
    _tc_clear_r
    capture tabcell est, lincom
    assert _rc == 301
    capture tabcell est, nlcom
    assert _rc == 301
}
if _rc == 0 {
    display as result "  PASS: T3 lincom and nlcom sources; absent results refused (301)"
    local ++pass_count
}
else {
    display as error "  FAIL: T3 lincom/nlcom (rc=`=_rc')"
    local ++fail_count
}

**# T4: matrix() rows by name and number; cols(); explicit numbers; b() se()
capture noisily {
    sysuse auto, clear
    quietly regress price mpg weight
    tabcell est mpg
    local viae `"`r(cell)'"'
    quietly regress price mpg weight
    tabcell est, matrix(r(table)' mpg)
    assert `"`r(cell)'"' == `"`viae'"'
    matrix M = (1, 9, 9, 9, 0.5, 2.25 \ 3, 9, 9, 9, 2, 4)
    tabcell est, matrix(M 2) cols(1 5 6) format(%3.1f)
    assert `"`r(cell)'"' == "3.0 (2.0, 4.0)"
    capture tabcell est, matrix(M 2)
    assert _rc == 111
    capture tabcell est, matrix(M 3) cols(1 5 6)
    assert _rc == 111
    capture tabcell est, matrix(M 1) cols(1 5 7)
    assert _rc == 198
    tabcell est, b(1.5) ll(1.1) ul(2)
    assert `"`r(cell)'"' == "1.50 (1.10, 2.00)"
    tabcell est, b(0.2) se(0.1) eform format(%5.3f)
    local want = strtrim(string(exp(0.2), "%5.3f")) + " (" + strtrim(string(exp(0.2 - invnormal(.975) * 0.1), "%5.3f")) + ", " + strtrim(string(exp(0.2 + invnormal(.975) * 0.1), "%5.3f")) + ")"
    assert `"`r(cell)'"' == `"`want'"'
}
if _rc == 0 {
    display as result "  PASS: T4 matrix(), cols(), b() ll() ul(), b() se() eform"
    local ++pass_count
}
else {
    display as error "  FAIL: T4 matrix/explicit (rc=`=_rc')"
    local ++fail_count
}

**# T5: cformat() thousands separators; format()/cformat() synonyms
capture noisily {
    tabcell est, b(1234.4) ll(1000) ul(2000.6) cformat(%12.0fc) sep(" to ")
    assert `"`r(cell)'"' == "1,234 (1,000 to 2,001)"
    tabcell est, b(1234.4) ll(1000) ul(2000.6) format(%12.0fc) sep(" to ")
    assert `"`r(cell)'"' == "1,234 (1,000 to 2,001)"
    capture tabcell est, b(1) ll(0) ul(2) format(%4.2f) cformat(%4.2f)
    assert _rc == 198
    foreach f in %td %tc %s %9s {
        capture tabcell est, b(1) ll(0) ul(2) format(`f')
        assert _rc == 198
    }
}
if _rc == 0 {
    display as result "  PASS: T5 cformat(%12.0fc); string/date formats and both synonyms refused"
    local ++pass_count
}
else {
    display as error "  FAIL: T5 formats (rc=`=_rc')"
    local ++fail_count
}

**# T6: R2 refusal of missing / non-estimable estimates, missing() text
capture noisily {
    sysuse auto, clear
    quietly regress price i.rep78
    capture tabcell est 1b.rep78
    assert _rc == 459
    tabcell est 1b.rep78, missing("–")
    assert `"`r(cell)'"' == "–" & r(missing) == 1
    capture tabcell est, b(.) ll(1) ul(2)
    assert _rc == 459
    capture tabcell est, b(1) ll(.a) ul(2)
    assert _rc == 459
    tabcell est, b(.) ll(.) ul(.) missing(did not converge)
    assert `"`r(cell)'"' == "did not converge"
    tabcell est, b(.) ll(.) ul(.) missing("Fit failed; see the log")
    assert `"`r(cell)'"' == "Fit failed; see the log"
    * exp() overflow is non-finite, not a number
    capture tabcell est, b(800) ll(1) ul(900) eform
    assert _rc == 459
    capture tabcell est, b(1) ll(2) ul(0)
    assert _rc == 198
    capture tabcell est nosuchvar
    assert _rc == 111
    ereturn clear
    capture tabcell est mpg
    assert _rc == 301
}
if _rc == 0 {
    display as result "  PASS: T6 R2: base level, missing, overflow refused (459); missing() prints text"
    local ++pass_count
}
else {
    display as error "  FAIL: T6 R2 refusals (rc=`=_rc')"
    local ++fail_count
}

**# T7: option ownership and source counting refusals
capture noisily {
    sysuse auto, clear
    quietly regress price mpg
    matrix T = r(table)
    foreach cmd in "tabcell est" "tabcell est mpg, lincom" "tabcell est mpg, b(1) ll(0) ul(2)" ///
        "tabcell p, p(0.5) eform" "tabcell np, n(1) d(2) sep(x)" "tabcell iqr, median(1) q1(0) q3(2) mincell(5)" ///
        "tabcell est mpg, pdp(4)" "tabcell xyz" "tabcell p" "tabcell np, n(1)" "tabcell est, b(1) ll(0)" ///
        "tabcell est, b(price) ll(1) ul(2)" "tabcell p, p(0.5) generate(x) n(2)" "tabcell est mpg in 1/3" ///
        "tabcell est, b(1) ll(0) ul(2) level(90)" "tabcell est, matrix(T' mpg) level(90)" {
        capture `cmd'
        if _rc != 198 display as error `"  `cmd' gave rc=`=_rc'"'
        assert _rc == 198
    }
}
if _rc == 0 {
    display as result "  PASS: T7 options outside their form and miscounted sources are refused (198)"
    local ++pass_count
}
else {
    display as error "  FAIL: T7 option ownership (rc=`=_rc')"
    local ++fail_count
}

**# T8: p rule parity with regtab over a grid of p-values (brief section 3)
capture noisily {
    local grid "0.05 0.0499 0.001 0.00099 1e-10 0.1 0.0999 0.5 0.995 0.99 0.2 1"
    foreach dp in "3 2" "4 3" "2 1" {
        local pdp : word 1 of `dp'
        local hpdp : word 2 of `dp'
        foreach p of local grid {
            clear
            local b = invnormal(1 - `p' / 2)
            collect clear
            quietly collect: _tc_post `b'
            quietly regtab, frame(_tcp, replace) eplotframe(_tcpe, replace) pdp(`pdp') highpdp(`hpdp') noint
            frame _tcp: local regtab_p = strtrim(c3[4])
            frame _tcpe: local pz = pvalue[1]
            tabcell p, p(`pz') pdp(`pdp') highpdp(`hpdp')
            if `"`r(cell)'"' != `"`regtab_p'"' display as error "  p=`p' pdp=`pdp': tabcell `r(cell)' regtab `regtab_p'"
            assert `"`r(cell)'"' == `"`regtab_p'"'
            * and from the exact two-sided p of the same z
            tabcell p, p(2 * normal(-abs(`b'))) pdp(`pdp') highpdp(`hpdp')
            assert `"`r(cell)'"' == `"`regtab_p'"'
        }
    }
    tabcell p, p(0.0499)
    assert "`r(cell)'" == "0.050"
    tabcell p, p(1e-10)
    assert "`r(cell)'" == "<0.001"
    tabcell p, p(1)
    assert "`r(cell)'" == "1.00"
    tabcell p, p(0.995)
    assert "`r(cell)'" == ">0.99"
    capture tabcell p, p(1.2)
    assert _rc == 198
    capture tabcell p, p(-0.1)
    assert _rc == 198
    capture tabcell p, p(.)
    assert _rc == 459
    capture tabcell p, p(0.5) pdp(11)
    assert _rc == 198
    frame drop _tcp
    frame drop _tcpe
}
if _rc == 0 {
    display as result "  PASS: T8 tabcell p equals regtab's printed p over a 12-point grid at three pdp/highpdp settings"
    local ++pass_count
}
else {
    display as error "  FAIL: T8 p parity with regtab (rc=`=_rc')"
    local ++fail_count
}

**# T9: np, enp, iqr known answers, mincell masking, refusals
capture noisily {
    tabcell np, n(13) d(40)
    assert "`r(cell)'" == "13 (32.5)"
    tabcell np, n(1234) d(5000) pformat(%5.2f)
    assert "`r(cell)'" == "1,234 (24.68)"
    tabcell np, n(0) d(0)
    assert "`r(cell)'" == "0"
    tabcell np, n(3) d(40) mincell(5)
    assert "`r(cell)'" == "<5"
    tabcell np, n(0) d(40) mincell(5)
    assert "`r(cell)'" == "0 (0.0)"
    tabcell np, n(5) d(40) mincell(5)
    assert "`r(cell)'" == "5 (12.5)"
    tabcell enp, e(12) n(74)
    assert "`r(cell)'" == "12/74 (16.2)"
    tabcell enp, e(3) n(40) mincell(5)
    assert "`r(cell)'" == "<5/40"
    tabcell enp, e(3) n(4) mincell(5)
    assert "`r(cell)'" == "<5"
    tabcell iqr, median(20) q1(18) q3(25.26) format(%5.1f)
    assert "`r(cell)'" == "20.0 (18.0, 25.3)"
    capture tabcell np, n(41) d(40)
    assert _rc == 198
    capture tabcell enp, e(-1) n(40)
    assert _rc == 198
    capture tabcell iqr, median(30) q1(18) q3(25)
    assert _rc == 198
    capture tabcell np, n(.) d(40)
    assert _rc == 459
    tabcell np, n(.) d(40) missing("n/a")
    assert "`r(cell)'" == "n/a"
    capture tabcell np, n(1) d(2) mincell(-1)
    assert _rc == 198
}
if _rc == 0 {
    display as result "  PASS: T9 np/enp/iqr known answers, mincell <#, refusals"
    local ++pass_count
}
else {
    display as error "  FAIL: T9 np/enp/iqr (rc=`=_rc')"
    local ++fail_count
}

**# T10: generate() equals the scalar form row by row; if/in; missing rows
capture noisily {
    sysuse auto, clear
    gen double lo = price * 0.9
    gen double hi = price * 1.1
    replace hi = . in 5
    capture tabcell est, b(price) ll(lo) ul(hi) generate(cell)
    assert _rc == 459
    capture confirm variable cell
    assert _rc
    tabcell est, b(price) ll(lo) ul(hi) generate(cell) format(%9.0fc) sep(" to ") missing("Not estimated")
    assert r(N) == 73 & r(N_missing) == 1 & "`r(varname)'" == "cell"
    assert cell[5] == "Not estimated"
    forvalues i = 1/`=_N' {
        if `i' == 5 continue
        * expressions, not macro-expanded numbers, so no precision is lost
        tabcell est, b(price[`i']) ll(lo[`i']) ul(hi[`i']) format(%9.0fc) sep(" to ")
        assert `"`r(cell)'"' == cell[`i']
    }
    gen n = round(price / 100)
    tabcell np if foreign, n(n) d(200) mincell(40) generate(np_cell)
    assert np_cell == "" if !foreign
    assert np_cell == "<40" if foreign & n >= 1 & n < 40
    count if foreign & n >= 40
    assert !missing(r(N)) & r(N) > 0
    assert np_cell == strtrim(string(n, "%12.0fc")) + " (" + strtrim(string(100 * n / 200, "%4.1f")) + ")" if foreign & n >= 40
    gen double pp = 1 / (_n + 1)
    tabcell p, p(pp) generate(p_cell)
    forvalues i = 1/5 {
        tabcell p, p(pp[`i'])
        assert `"`r(cell)'"' == p_cell[`i']
    }
    capture tabcell p, p(pp) generate(p_cell)
    assert _rc == 110
    capture tabcell p if price < 0, p(pp) generate(p_none)
    assert _rc == 2000
    * scalar forms never write data
    datasignature
    local sig `"`r(datasignature)'"'
    tabcell est, b(1) ll(0) ul(2)
    tabcell np, n(1) d(2)
    datasignature
    assert `"`r(datasignature)'"' == `"`sig'"'
}
if _rc == 0 {
    display as result "  PASS: T10 generate() equals the scalar form; if/in; refusals; scalar forms write nothing"
    local ++pass_count
}
else {
    display as error "  FAIL: T10 generate() (rc=`=_rc')"
    local ++fail_count
}

**# T11: session hygiene: varabbrev and frames on success and error
capture noisily {
    set varabbrev on
    quietly frames dir
    local before `"`r(frames)'"'
    capture tabcell est, b(.) ll(1) ul(2)
    assert c(varabbrev) == "on"
    tabcell est, b(1) ll(0) ul(2)
    assert c(varabbrev) == "on"
    quietly frames dir
    assert `"`r(frames)'"' == `"`before'"'
    set varabbrev off
}
if _rc == 0 {
    display as result "  PASS: T11 varabbrev restored and no frames left on success and error"
    local ++pass_count
}
else {
    display as error "  FAIL: T11 session hygiene (rc=`=_rc')"
    local ++fail_count
}
set varabbrev off

local _tc = `pass_count' + `fail_count'
display "RESULT: test_tabcell_v230 tests=`_tc' pass=`pass_count' fail=`fail_count'"
log close _tc230
if `fail_count' > 0 exit 1
