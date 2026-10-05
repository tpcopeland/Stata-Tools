* test_tabcell_v231.do - tabcell n, pstyle(footnote), scale(), lincom r(p), missing(""), tabtools 2.3.1
* Oracles: hand-built strings; the lincom p-value recomputed from e(b), e(V)
* and e(df_r) by hand (2*ttail(df, |t|) or 2*normal(-|z|)); lincom's own r()
* read before tabcell runs; regtab's p text for the same p (tabcell p, table
* style) as the source of the footnote form's number.

clear all
set more off
set varabbrev off
version 17.0

capture log close _tc231
log using "test_tabcell_v231.log", replace text name(_tc231)

local qa_dir "`c(pwd)'"
local pkg_dir = regexr("`qa_dir'", "/qa$", "")
capture ado uninstall tabtools
quietly net install tabtools, from("`pkg_dir'") replace
discard

local pass_count = 0
local fail_count = 0

**# C1: tabcell n prints a count with thousands separators and masks like np
capture noisily {
    tabcell n, n(1234567)
    assert `"`r(cell)'"' == "1,234,567" & "`r(form)'" == "n" & r(missing) == 0
    tabcell n, n(12345)
    assert `"`r(cell)'"' == "12,345"
    tabcell n, n(999)
    assert `"`r(cell)'"' == "999"
    tabcell n, n(1234567) nformat(%9.0f)
    assert `"`r(cell)'"' == "1234567"
    * mincell(): 1..#-1 masked as <#, 0 and # printed (as np prints its count)
    tabcell n, n(3) mincell(5)
    assert `"`r(cell)'"' == "<5"
    tabcell np, n(3) d(40) mincell(5)
    assert `"`r(cell)'"' == "<5"
    tabcell n, n(0) mincell(5)
    assert `"`r(cell)'"' == "0"
    tabcell n, n(5) mincell(5)
    assert `"`r(cell)'"' == "5"
    tabcell n, n(1) mincell(5)
    assert `"`r(cell)'"' == "<5"
    * missing: refused, or the missing() text
    capture tabcell n, n(.)
    assert _rc == 459
    tabcell n, n(.) missing("n/a")
    assert `"`r(cell)'"' == "n/a" & r(missing) == 1
    * refusals: options of other forms, negative count, no n()
    capture tabcell n, n(3) pformat(%4.1f)
    assert _rc == 198
    capture tabcell n, n(3) d(4)
    assert _rc == 198
    capture tabcell n, n(-1)
    assert _rc == 198
    capture tabcell n
    assert _rc == 198
    capture tabcell n, n(3) scale(10)
    assert _rc == 198
    * generate(): the column equals the scalar cells
    clear
    quietly set obs 5
    gen double k = cond(_n == 1, 1234567, cond(_n == 2, 3, cond(_n == 3, 0, cond(_n == 4, ., 12))))
    tabcell n, n(k) mincell(5) missing("") generate(kc)
    assert kc[1] == "1,234,567" & kc[2] == "<5" & kc[3] == "0" & kc[4] == "" & kc[5] == "12"
    assert r(N) == 4 & r(N_missing) == 1 & "`r(form)'" == "n"
    capture confirm variable kc
    assert _rc == 0
}
if _rc == 0 {
    display as result "  PASS: C1 tabcell n: separators, mincell() masking, missing, refusals, generate()"
    local ++pass_count
}
else {
    display as error "  FAIL: C1 tabcell n (rc=`=_rc')"
    local ++fail_count
}

**# C2: pstyle(footnote): p = 0.012 / p < 0.001 / p > 0.99; table style unchanged
capture noisily {
    local grid "0.0123 0.00001 0 0.05 0.5 0.9999 1 0.001 0.0004999"
    local want_fn `""p = 0.012" "p < 0.001" "p < 0.001" "p = 0.050" "p = 0.50" "p > 0.99" "p = 1.00" "p = 0.001" "p < 0.001""'
    local want_tb `""0.012" "<0.001" "<0.001" "0.050" "0.50" ">0.99" "1.00" "0.001" "<0.001""'
    local i 0
    foreach p of local grid {
        local ++i
        local wf : word `i' of `want_fn'
        local wt : word `i' of `want_tb'
        tabcell p, p(`p') pstyle(footnote)
        assert `"`r(cell)'"' == `"`wf'"'
        tabcell p, p(`p')
        assert `"`r(cell)'"' == `"`wt'"'
        tabcell p, p(`p') pstyle(table)
        assert `"`r(cell)'"' == `"`wt'"'
    }
    * pdp()/highpdp() reach the footnote form
    tabcell p, p(0.00004) pdp(4) pstyle(footnote)
    assert `"`r(cell)'"' == "p < 0.0001"
    tabcell p, p(0.25) highpdp(3) pstyle(FOOTNOTE)
    assert `"`r(cell)'"' == "p = 0.250"
    * generate(): one column, missing rows given the missing() text
    clear
    quietly set obs 3
    gen double pv = cond(_n == 1, 0.0123, cond(_n == 2, 0.00001, .))
    tabcell p, p(pv) pstyle(footnote) missing("") generate(pf)
    assert pf[1] == "p = 0.012" & pf[2] == "p < 0.001" & pf[3] == ""
    * refusals
    capture tabcell p, p(0.5) pstyle(prose)
    assert _rc == 198
    capture tabcell np, n(1) d(2) pstyle(footnote)
    assert _rc == 198
}
if _rc == 0 {
    display as result "  PASS: C2 pstyle(footnote) prose p-values over a grid; table style unchanged"
    local ++pass_count
}
else {
    display as error "  FAIL: C2 pstyle(footnote) (rc=`=_rc')"
    local ++fail_count
}

**# C3: scale() multiplies the estimate and both limits (est only)
capture noisily {
    tabcell est, b(0.0213) ll(0.0110) ul(0.0372) scale(1000) format(%5.1f)
    assert `"`r(cell)'"' == "21.3 (11.0, 37.2)"
    assert reldif(r(estimate), 21.3) < 1e-12 & reldif(r(lb), 11) < 1e-12 & reldif(r(ub), 37.2) < 1e-12
    assert r(scale) == 1000
    * b() se(): the scaled interval is b*s -/+ z*se*s
    local z = invnormal(0.975)
    tabcell est, b(0.002) se(0.0005) scale(1000) format(%6.3f)
    local lo = string(1000 * (0.002 - `z' * 0.0005), "%6.3f")
    local hi = string(1000 * (0.002 + `z' * 0.0005), "%6.3f")
    assert `"`r(cell)'"' == "2.000 (" + strtrim("`lo'") + ", " + strtrim("`hi'") + ")"
    * eform first, then scale: exp(_cons) of a Poisson model with exposure is
    * a rate per unit; times 1000 a rate per 1,000
    clear
    quietly set obs 2
    gen long d = cond(_n == 1, 12, 19)
    gen double y = cond(_n == 1, 564, 180)
    quietly poisson d, exposure(y)
    local b = _b[_cons]
    local s = _se[_cons]
    tabcell est _cons, eform scale(1000) format(%9.4f)
    assert reldif(r(estimate), 1000 * 31 / 744) < 1e-6
    assert reldif(r(lb), 1000 * exp(`b' - `z' * `s')) < 1e-12
    assert reldif(r(ub), 1000 * exp(`b' + `z' * `s')) < 1e-12
    * no scale(): no r(scale)
    tabcell est, b(1) ll(0) ul(2)
    capture confirm scalar r(scale)
    assert _rc != 0
    * generate()
    clear
    quietly set obs 2
    gen double r = cond(_n == 1, 0.0213, 0.1056)
    gen double l = cond(_n == 1, 0.0110, 0.0636)
    gen double u = cond(_n == 1, 0.0372, 0.1648)
    tabcell est, b(r) ll(l) ul(u) scale(1000) format(%5.1f) generate(rc)
    assert rc[1] == "21.3 (11.0, 37.2)" & rc[2] == "105.6 (63.6, 164.8)"
    * refusals: other forms and bad numbers
    capture tabcell p, p(0.5) scale(10)
    assert _rc == 198
    capture tabcell np, n(1) d(2) scale(10)
    assert _rc == 198
    capture tabcell iqr, median(2) q1(1) q3(3) scale(10)
    assert _rc == 198
    foreach bad in 0 -1 abc . {
        capture tabcell est, b(1) ll(0) ul(2) scale(`bad')
        assert _rc == 198
    }
}
if _rc == 0 {
    display as result "  PASS: C3 scale() on est (numbers, se(), eform, generate()); refused elsewhere"
    local ++pass_count
}
else {
    display as error "  FAIL: C3 scale() (rc=`=_rc')"
    local ++fail_count
}

**# C4: tabcell est, lincom returns r(p) and keeps lincom's results
capture noisily {
    sysuse auto, clear
    quietly regress price mpg weight
    * independent: the combination and its p-value from e(b), e(V), e(df_r)
    matrix V = e(V)
    local est = _b[mpg] + 2 * _b[weight]
    local se = sqrt(V[1,1] + 4 * V[2,2] + 4 * V[1,2])
    local df = e(df_r)
    local p_hand = 2 * ttail(`df', abs(`est' / `se'))
    quietly lincom mpg + 2*weight
    local lc_p = r(p)
    local lc_t = r(t)
    local lc_lb = r(lb)
    local lc_ub = r(ub)
    tabcell est, lincom
    assert reldif(r(p), `p_hand') < 1e-10
    assert reldif(r(p), `lc_p') < 1e-14
    assert reldif(r(se), `se') < 1e-10 & r(df) == `df'
    assert reldif(r(t), `est' / `se') < 1e-10 & reldif(r(t), `lc_t') < 1e-14
    assert reldif(r(lincom_estimate), `est') < 1e-10
    assert reldif(r(lincom_lb), `lc_lb') < 1e-14 & reldif(r(lincom_ub), `lc_ub') < 1e-14
    assert r(lincom_level) == 95
    * another level: tabcell's limits move, lincom's are kept
    quietly lincom mpg + 2*weight
    tabcell est, lincom level(80)
    assert reldif(r(lb), `est' - invttail(`df', 0.10) * `se') < 1e-10
    assert reldif(r(lincom_lb), `lc_lb') < 1e-14 & r(lincom_level) == 95 & r(level) == 80
    assert reldif(r(p), `p_hand') < 1e-10
    * a z statistic (logit), with lincom, or: r(z) and r(p) = 2*normal(-|z|)
    quietly logit foreign mpg weight
    matrix V = e(V)
    local est = _b[mpg] - _b[weight]
    local se = sqrt(V[1,1] + V[2,2] - 2 * V[1,2])
    local p_hand = 2 * normal(-abs(`est' / `se'))
    quietly lincom mpg - weight, or
    tabcell est, lincom
    assert reldif(r(p), `p_hand') < 1e-10
    assert reldif(r(z), `est' / `se') < 1e-10
    assert reldif(r(lincom_estimate), exp(`est')) < 1e-10
    * results left by tabcell itself are not read as lincom's
    capture tabcell est, lincom
    assert _rc == 301
    quietly regress price mpg weight
    quietly lincom mpg
    tabcell est, lincom scale(1000)
    capture tabcell est, lincom
    assert _rc == 301
}
if _rc == 0 {
    display as result "  PASS: C4 lincom r(p) equals the hand p-value; lincom's r() kept; own r() refused"
    local ++pass_count
}
else {
    display as error "  FAIL: C4 lincom r(p) (rc=`=_rc')"
    local ++fail_count
}

**# C5: missing("") gives an empty cell (documented behaviour)
capture noisily {
    tabcell est, b(.) ll(.) ul(.) missing("")
    assert `"`r(cell)'"' == "" & r(missing) == 1
    tabcell np, n(.) d(4) missing("")
    assert `"`r(cell)'"' == "" & r(missing) == 1
    * missing() absent still refuses
    capture tabcell est, b(.) ll(.) ul(.)
    assert _rc == 459
}
if _rc == 0 {
    display as result "  PASS: C5 missing() given as empty text prints an empty cell"
    local ++pass_count
}
else {
    display as error "  FAIL: C5 missing() (rc=`=_rc')"
    local ++fail_count
}

**# C6: the new help-file examples run as printed
capture noisily {
    tabcell p, p(0.0123) pstyle(footnote)
    assert `"`r(cell)'"' == "p = 0.012"
    tabcell n, n(12345)
    assert `"`r(cell)'"' == "12,345"
    tabcell est, b(0.0213) ll(0.0110) ul(0.0372) scale(1000) format(%5.1f)
    assert `"`r(cell)'"' == "21.3 (11.0, 37.2)"
}
if _rc == 0 {
    display as result "  PASS: C6 help examples for n, pstyle(), scale()"
    local ++pass_count
}
else {
    display as error "  FAIL: C6 help examples (rc=`=_rc')"
    local ++fail_count
}

**# C7: session hygiene: varabbrev and frames on success and error
capture noisily {
    set varabbrev on
    quietly frames dir
    local before `"`r(frames)'"'
    capture tabcell n, n(-1)
    assert c(varabbrev) == "on"
    tabcell n, n(3)
    assert c(varabbrev) == "on"
    quietly frames dir
    assert `"`r(frames)'"' == `"`before'"'
    set varabbrev off
}
if _rc == 0 {
    display as result "  PASS: C7 varabbrev restored and no frames left"
    local ++pass_count
}
else {
    display as error "  FAIL: C7 session hygiene (rc=`=_rc')"
    local ++fail_count
}
set varabbrev off

local _tc = `pass_count' + `fail_count'
display "RESULT: test_tabcell_v231 tests=`_tc' pass=`pass_count' fail=`fail_count'"
log close _tc231
if `fail_count' > 0 exit 1
