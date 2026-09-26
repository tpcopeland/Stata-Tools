* test_table1_overflow.do - table1_tc weighted sums beyond Stata's double range
* Regression suite for weighted cells that went wrong when a weighted sum,
* product or square exceeds maxdouble() (about 8.99e307), found by the
* R-tabtools port and re-probed on 2.1.11 before any fix:
*   N1  weighted mean/SD from a sum that silently skipped an overflowing
*       product (one weight of 8e307 among ones gave 0±.)
*   N2  weighted quantiles when the weight total overflows (all weights
*       8e307 gave 2 (2, 2) instead of 5.5 (3, 8))
*   N3  wtn / percent_n showed the raw record count with empty parentheses
*       when the group weight total overflows
*   N4  the ESS accumulator restarted from 0 after its sum of squared
*       weights overflowed
*   N5  ESS was missing when only (sum w)^2 overflows
*   N6  weighted SD was missing when sum(w)*(n-1) overflows
* Guard tests pin the honest missing values that must stay missing
* (unweighted squares or sums that truly overflow).
* Every expected cell is computed here from Stata's own summarize/_pctile on
* weights divided by their maximum (the statistics are scale-invariant), or
* by hand, never from table1_tc output.

clear all
set more off
set varabbrev off
version 17.0

capture log close _t1overflow
log using "test_table1_overflow.log", replace text name(_t1overflow)

local pass_count = 0
local fail_count = 0

**# Bootstrap
local qa_dir "`c(pwd)'"
local pkg_dir = regexr("`qa_dir'", "/qa$", "")

capture ado uninstall tabtools
quietly net install tabtools, from("`pkg_dir'") replace
discard
tabtools set clear

* Trimmed contents of column `col' in frame `frname' on the one row whose
* trimmed factor label is `label'. Errors when the row is absent or doubled.
capture program drop _t1o_cell
program define _t1o_cell, rclass
    version 17.0
    args frname label col
    frame `frname' {
        tempvar rn
        quietly generate long `rn' = _n
        quietly count if strtrim(factor) == `"`label'"'
        if r(N) != 1 {
            display as error `"frame `frname': `r(N)' rows labelled "`label'""'
            exit 459
        }
        quietly summarize `rn' if strtrim(factor) == `"`label'"', meanonly
        local cell = strtrim(`col'[r(min)])
    }
    return local cell `"`cell'"'
end

* Assert one cell, echoing both sides on mismatch.
capture program drop _t1o_expect
program define _t1o_expect
    version 17.0
    args frname label col want
    _t1o_cell `frname' `"`label'"' `col'
    if `"`r(cell)'"' != `"`want'"' {
        display as error `"  `frname' `label' `col': got "`r(cell)'", want "`want'""'
        exit 9
    }
end

* Twenty records, x = 1..20, two arms of ten; weights in double.
capture program drop _t1o_data
program define _t1o_data
    version 17.0
    clear
    quietly set obs 20
    generate double x = _n
    generate byte g = 1 + (_n > 10)
    generate double w = 1
    generate byte b = mod(_n, 2)
    generate byte c = mod(_n, 3)
end

**# N1: weighted mean/SD with one overflowing product
* x = 3 carries w = 8e307: 3 * 8e307 overflows, so the old sum skipped it
* and printed 0±.
capture noisily {
    _t1o_data
    quietly replace w = 8e307 if x == 3
    generate double wr = w / 8e307
    quietly summarize x [aw=wr] if g == 1
    assert reldif(r(mean), 3) < 1e-12
    local want1 = string(r(mean), "%9.3f") + "±" + string(r(sd), "%9.3f")
    quietly summarize x [aw=wr] if g == 2
    local want2 = string(r(mean), "%9.3f") + "±" + string(r(sd), "%9.3f")
    table1_tc, by(g) vars(x contn %9.3f) wt(w) frame(_t1o1, replace)
    _t1o_expect _t1o1 "x" g_1 "`want1'"
    _t1o_expect _t1o1 "x" g_2 "`want2'"
}
if _rc == 0 {
    display as result "  PASS: N1 one 8e307 weight among ones gives the true weighted mean/SD"
    local ++pass_count
}
else {
    display as error "  FAIL: N1 one 8e307 weight among ones (rc=`=_rc')"
    local ++fail_count
}

* Two heavy weights in arm 1 (8e307 at x = 3, 4e307 at x = 7): both products
* and the weight total overflow. By hand the mean is (3*8 + 7*4)/12 = 13/3
* and the SD is sqrt(10/9 * (8*(3-13/3)^2 + 4*(7-13/3)^2) / 12).
capture noisily {
    _t1o_data
    quietly replace w = 8e307 if x == 3
    quietly replace w = 4e307 if x == 7
    generate double wr = w / 8e307
    local hand_sd = sqrt(10/9 * (8*(3-13/3)^2 + 4*(7-13/3)^2) / 12)
    quietly summarize x [aw=wr] if g == 1
    assert reldif(r(mean), 13/3) < 1e-9
    assert reldif(r(sd), `hand_sd') < 1e-9
    local want1 = string(13/3, "%9.3f") + "±" + string(`hand_sd', "%9.3f")
    table1_tc, by(g) vars(x contn %9.3f) wt(w) frame(_t1o2, replace)
    _t1o_expect _t1o2 "x" g_1 "`want1'"
}
if _rc == 0 {
    display as result "  PASS: N1 two overflowing weights give the hand-computed mean/SD"
    local ++pass_count
}
else {
    display as error "  FAIL: N1 two overflowing weights (rc=`=_rc')"
    local ++fail_count
}

* The same one-heavy-weight data under conts (guard: the weight total is
* finite here, so the quantile walk was already right).
capture noisily {
    _t1o_data
    quietly replace w = 8e307 if x == 3
    generate double wr = w / 8e307
    quietly _pctile x [aw=wr] if g == 1, percentiles(25 50 75)
    local want1 = string(r(r2), "%9.3f") + " (" + string(r(r1), "%9.3f") + ", " + string(r(r3), "%9.3f") + ")"
    table1_tc, by(g) vars(x conts %9.3f) wt(w) frame(_t1o3, replace)
    _t1o_expect _t1o3 "x" g_1 "`want1'"
}
if _rc == 0 {
    display as result "  PASS: N1 guard conts with one 8e307 weight matches _pctile"
    local ++pass_count
}
else {
    display as error "  FAIL: N1 guard conts with one 8e307 weight (rc=`=_rc')"
    local ++fail_count
}

**# N2: weighted quantiles when the weight total overflows
* All weights 8e307: each arm totals 8e308. Equal weights, so the quantiles
* of 1..10 and 11..20 are 5.5 (3, 8) and 15.5 (13, 18).
capture noisily {
    _t1o_data
    quietly replace w = 8e307
    generate double wr = w / 8e307
    quietly _pctile x [aw=wr] if g == 1, percentiles(25 50 75)
    assert r(r2) == 5.5 & r(r1) == 3 & r(r3) == 8
    local want1 = string(r(r2), "%9.3f") + " (" + string(r(r1), "%9.3f") + ", " + string(r(r3), "%9.3f") + ")"
    quietly _pctile x [aw=wr] if g == 2, percentiles(25 50 75)
    assert r(r2) == 15.5 & r(r1) == 13 & r(r3) == 18
    local want2 = string(r(r2), "%9.3f") + " (" + string(r(r1), "%9.3f") + ", " + string(r(r3), "%9.3f") + ")"
    table1_tc, by(g) vars(x conts %9.3f) wt(w) frame(_t1o4, replace)
    _t1o_expect _t1o4 "x" g_1 "`want1'"
    _t1o_expect _t1o4 "x" g_2 "`want2'"
}
if _rc == 0 {
    display as result "  PASS: N2 all weights 8e307 give the true medians and quartiles"
    local ++pass_count
}
else {
    display as error "  FAIL: N2 all weights 8e307 quantiles (rc=`=_rc')"
    local ++fail_count
}

* The same data under contn: mean 5.5 and SD of 1..10, and ESS = 10.
capture noisily {
    _t1o_data
    quietly replace w = 8e307
    generate double wr = w / 8e307
    quietly summarize x [aw=wr] if g == 1
    local want1 = string(r(mean), "%9.3f") + "±" + string(r(sd), "%9.3f")
    quietly summarize x if g == 1
    assert "`want1'" == string(r(mean), "%9.3f") + "±" + string(r(sd), "%9.3f")
    table1_tc, by(g) vars(x contn %9.3f) wt(w) frame(_t1o5, replace)
    _t1o_expect _t1o5 "x" g_1 "`want1'"
    _t1o_expect _t1o5 "Effective sample size" g_1 "ESS=10"
    _t1o_expect _t1o5 "Effective sample size" g_2 "ESS=10"
}
if _rc == 0 {
    display as result "  PASS: N2 all weights 8e307 under contn give mean, SD and ESS"
    local ++pass_count
}
else {
    display as error "  FAIL: N2 all weights 8e307 under contn (rc=`=_rc')"
    local ++fail_count
}

**# N3: wtn / percent_n when the group weight total overflows
* Effective count = weighted share x group N; percentages take table1_tc's
* %5.0f default.
capture program drop _t1o_catwant
program define _t1o_catwant, rclass
    version 17.0
    args cond var level pn
    tempvar ind
    quietly generate byte `ind' = (`var' == `level') if `cond'
    quietly summarize `ind' [aw=wr] if `cond'
    local pct = 100 * r(mean)
    local cnt = r(mean) * r(N)
    local ps = string(`pct', "%5.0f")
    if `pct' < 10 local ps " `ps'"
    local ns = string(`cnt', "%12.0fc")
    if "`pn'" == "" return local want "`ns' (`ps')"
    else return local want "`ps' (`ns')"
end

capture noisily {
    _t1o_data
    quietly replace w = 8e307
    generate double wr = w / 8e307
    table1_tc, by(g) vars(b bin \ c cat) wt(w) wtn total(after) frame(_t1o6, replace)
    foreach col in g_1 g_2 g_T {
        if "`col'" == "g_1" local cond "g == 1"
        if "`col'" == "g_2" local cond "g == 2"
        if "`col'" == "g_T" local cond "1"
        _t1o_catwant "`cond'" b 1
        _t1o_expect _t1o6 "b" `col' "`r(want)'"
        forvalues lv = 0/2 {
            _t1o_catwant "`cond'" c `lv'
            _t1o_expect _t1o6 "`lv'" `col' "`r(want)'"
        }
        local ess = cond("`col'" == "g_T", "20", "10")
        _t1o_expect _t1o6 "Effective sample size" `col' "ESS=`ess'"
    }
    * Hand check of one cell: arm 1 holds b = 1 at x = 1, 3, 5, 7, 9
    _t1o_expect _t1o6 "b" g_1 "5 (50)"
}
if _rc == 0 {
    display as result "  PASS: N3 wtn with all weights 8e307 gives effective counts and percentages"
    local ++pass_count
}
else {
    display as error "  FAIL: N3 wtn with all weights 8e307 (rc=`=_rc')"
    local ++fail_count
}

capture noisily {
    _t1o_data
    quietly replace w = 8e307
    generate double wr = w / 8e307
    table1_tc, by(g) vars(b bin \ c cat) wt(w) percent_n total(after) frame(_t1o7, replace)
    foreach col in g_1 g_2 g_T {
        if "`col'" == "g_1" local cond "g == 1"
        if "`col'" == "g_2" local cond "g == 2"
        if "`col'" == "g_T" local cond "1"
        _t1o_catwant "`cond'" b 1 pn
        _t1o_expect _t1o7 "b" `col' "`r(want)'"
        forvalues lv = 0/2 {
            _t1o_catwant "`cond'" c `lv' pn
            _t1o_expect _t1o7 "`lv'" `col' "`r(want)'"
        }
    }
}
if _rc == 0 {
    display as result "  PASS: N3 percent_n with all weights 8e307 gives % (effective n)"
    local ++pass_count
}
else {
    display as error "  FAIL: N3 percent_n with all weights 8e307 (rc=`=_rc')"
    local ++fail_count
}

* Guard: one 8e307 weight among ones (the weight total is finite). Arm 1's
* weighted share of b = 1 is (8e307 + 4) / (8e307 + 9), shown as 100.
capture noisily {
    _t1o_data
    quietly replace w = 8e307 if x == 3
    generate double wr = w / 8e307
    table1_tc, by(g) vars(b bin \ c cat) wt(w) wtn frame(_t1o8, replace)
    _t1o_catwant "g == 1" b 1
    _t1o_expect _t1o8 "b" g_1 "`r(want)'"
    _t1o_expect _t1o8 "b" g_1 "10 (100)"
    _t1o_expect _t1o8 "b" g_2 "5 (50)"
}
if _rc == 0 {
    display as result "  PASS: N3 guard wtn with one 8e307 weight among ones"
    local ++pass_count
}
else {
    display as error "  FAIL: N3 guard wtn with one 8e307 weight (rc=`=_rc')"
    local ++fail_count
}

**# N4: ESS accumulator after an overflow
* Arm 1 weights 9e153, 9e153, 1e153 in data order: the second squared weight
* takes the running sum past maxdouble, and the third is finite. The ESS is
* (sum w)^2 / sum w^2 = 19^2 / (81 + 81 + 1).
capture noisily {
    clear
    quietly set obs 6
    generate double x = _n
    generate byte g = 1 + (_n > 3)
    generate double w = 1
    quietly replace w = 9e153 in 1/2
    quietly replace w = 1e153 in 3
    generate double ws = w / 1e153 if g == 1
    generate double ws2 = ws^2
    quietly summarize ws
    local s1 = r(sum)
    quietly summarize ws2
    local ess = `s1'^2 / r(sum)
    assert reldif(`ess', 361/163) < 1e-12
    table1_tc, by(g) vars(x contn) wt(w) nformat(%9.4f) frame(_t1o9, replace)
    local want = "ESS=" + string(`ess', "%9.4f")
    _t1o_expect _t1o9 "Effective sample size" g_1 "`want'"
}
if _rc == 0 {
    display as result "  PASS: N4 ESS after an overflowing sum of squared weights"
    local ++pass_count
}
else {
    display as error "  FAIL: N4 ESS after an overflowing sum of squared weights (rc=`=_rc')"
    local ++fail_count
}

**# N5: ESS when only (sum w)^2 overflows
* Arm 1: x = 2..5, w = 3e153 each: sum w^2 = 3.6e307 is finite, (sum w)^2
* is not. Equal weights, so ESS = 4. Arm 2 has the same x with unit weights.
capture noisily {
    clear
    quietly set obs 8
    generate double x = mod(_n - 1, 4) + 2
    generate byte g = 1 + (_n > 4)
    generate double w = cond(g == 1, 3e153, 1)
    table1_tc, by(g) vars(x contn) wt(w) frame(_t1o10, replace)
    _t1o_expect _t1o10 "Effective sample size" g_1 "ESS=4"
    _t1o_expect _t1o10 "Effective sample size" g_2 "ESS=4"
}
if _rc == 0 {
    display as result "  PASS: N5 ESS = 4 when only (sum w)^2 overflows"
    local ++pass_count
}
else {
    display as error "  FAIL: N5 ESS when (sum w)^2 overflows (rc=`=_rc')"
    local ++fail_count
}

**# N6: weighted SD when sum(w) * (n - 1) overflows
* Arm 1: x = 1..4, w = (4e307, 1, 1, 1): sum(w) * 3 = 1.2e308. Arm 2 has the
* same x with unit weights.
capture noisily {
    clear
    quietly set obs 8
    generate double x = mod(_n - 1, 4) + 1
    generate byte g = 1 + (_n > 4)
    generate double w = cond(_n == 1, 4e307, 1)
    generate double wr = w / 4e307
    quietly summarize x [aw=wr] if g == 1
    local want = string(r(mean), "%9.3f") + "±" + string(r(sd), "%9.3f")
    assert "`want'" == "1.000±0.000"
    table1_tc, by(g) vars(x contn %9.3f) wt(w) frame(_t1o11, replace)
    _t1o_expect _t1o11 "x" g_1 "`want'"
}
if _rc == 0 {
    display as result "  PASS: N6 weighted SD when sum(w)*(n-1) overflows"
    local ++pass_count
}
else {
    display as error "  FAIL: N6 weighted SD when sum(w)*(n-1) overflows (rc=`=_rc')"
    local ++fail_count
}

**# Guards: honest missing values stay missing
* Unweighted arm 1 x = 1e200, 2e200, 3e200: the squares overflow, so the SD is
* missing while the mean (2e200) is shown.
capture noisily {
    clear
    quietly set obs 6
    generate double x = cond(_n <= 3, _n * 1e200, _n)
    generate byte g = 1 + (_n > 3)
    table1_tc, by(g) vars(x contn %10.3e) frame(_t1o12, replace)
    local want = string(2e200, "%10.3e") + "±."
    _t1o_expect _t1o12 "x" g_1 "`want'"
}
if _rc == 0 {
    display as result "  PASS: guard unweighted overflowing squares give a missing SD"
    local ++pass_count
}
else {
    display as error "  FAIL: guard unweighted overflowing squares (rc=`=_rc')"
    local ++fail_count
}

* A mean whose sum truly overflows (arm 1 x = 8e307 three times, unweighted) is a
* blank cell, never a finite number.
capture noisily {
    clear
    quietly set obs 6
    generate double x = cond(_n <= 3, 8e307, _n)
    generate byte g = 1 + (_n > 3)
    table1_tc, by(g) vars(x contn) frame(_t1o13, replace)
    _t1o_expect _t1o13 "x" g_1 ""
}
if _rc == 0 {
    display as result "  PASS: guard overflowing unweighted sum gives a blank cell"
    local ++pass_count
}
else {
    display as error "  FAIL: guard overflowing unweighted sum (rc=`=_rc')"
    local ++fail_count
}

**# Summary
local test_count = `pass_count' + `fail_count'
display ""
display as result "Results: `pass_count'/`test_count' passed, `fail_count' failed"
if `fail_count' > 0 {
    display as error "SOME TESTS FAILED"
    display "RESULT: test_table1_overflow tests=`test_count' pass=`pass_count' fail=`fail_count'"
    log close _t1overflow
    exit 1
}
display as result "ALL TESTS PASSED"
display "RESULT: test_table1_overflow tests=`test_count' pass=`pass_count' fail=`fail_count'"
log close _t1overflow
