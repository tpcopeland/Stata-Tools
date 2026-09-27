* test_codex_parity_2026_09_26.do - scale edge cases found by the R port's
* Codex audit of 2026-09-26 (findings D1 and D5)
* Regression suite, written against commit f9ffafb4 (tabtools 2.1.13) before
* any fix:
*   S1  table1_tc weighted median and IQR do not depend on the scale of the
*       weights: all-equal and unequal weights times 1e-12, 1e-100 and 1e-300
*       give the quartiles of the unscaled weights (were the mean of the two
*       smallest values, "2 (2, 2)", whenever the weight total was below
*       about 1e-9), overall and within by() groups
*   S2  automatic typing does not depend on the scale of the values: a
*       variable times 1e100, 1e200 or 1e-100 (positive or negative) gets the
*       type of the unscaled variable in the moment branch (over 5,000
*       values, where summarize's overflowing moments typed it conts) and in
*       the Shapiro-Wilk branch (2,001-5,000 values, where swilk silently
*       used no observations and a missing p typed it contn)
* Guard tests pin the unchanged behaviour: weight totals of 1 and more, and
* the types of ordinary uniform and log-normal data.
* Expected quartiles come from _pctile on weights rescaled here; expected
* types from the moments and swilk p-value of the unscaled variable, whose
* values are small enough not to overflow, and from hand-derived moments
* (a uniform has skewness 0 and kurtosis 1.8), never from table1_tc output.

clear all
set more off
set varabbrev off
version 17.0

capture log close _cxp
log using "test_codex_parity_2026_09_26.log", replace text name(_cxp)

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
capture program drop _cxp_cell
program define _cxp_cell, rclass
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
capture program drop _cxp_expect
program define _cxp_expect
    version 17.0
    args frname label col want
    _cxp_cell `frname' `"`label'"' `col'
    if `"`r(cell)'"' != `"`want'"' {
        display as error `"  `frname' `label' `col': got "`r(cell)'", want "`want'""'
        exit 9
    }
end

* "median (q1, q3)" in %9.2f from _pctile with aweights `w' on `x' `if'.
* _pctile's weighted definition is the one table1_tc documents (the mean of
* two order statistics when the cumulative weight hits the target exactly).
capture program drop _cxp_iqr
program define _cxp_iqr, rclass
    version 17.0
    syntax varname [if], w(varname)
    quietly _pctile `varlist' [aw=`w'] `if', p(25 50 75)
    local q1 = strtrim(string(r(r1), "%9.2f"))
    local q2 = strtrim(string(r(r2), "%9.2f"))
    local q3 = strtrim(string(r(r3), "%9.2f"))
    return local cell "`q2' (`q1', `q3')"
end

* The table1_tc automatic type of `var', read from the rendered cell:
* contn shows "mean±sd", conts shows "median (q1, q3)".
capture program drop _cxp_type
program define _cxp_type, rclass
    version 17.0
    args var
    table1_tc, vars(`var') frame(_cxp_t, replace)
    _cxp_cell _cxp_t "`var'" Total
    local cell `"`r(cell)'"'
    if strpos(`"`cell'"', "±") local type "contn"
    else if regexm(`"`cell'"', "^[^ ]+ \([^,]+, [^)]+\)$") local type "conts"
    else {
        display as error `"  unrecognised cell for `var': "`cell'""'
        exit 9
    }
    capture frame drop _cxp_t
    return local type "`type'"
end

**# S1: weighted quartiles at tiny weight scales
* x = 1..10 with equal weights: quartiles 3, 5.5, 8 whatever the common
* weight, by hand (the cumulative share reaches 1/2 exactly after x = 5).
foreach s in 1e-12 1e-100 1e-300 {
    capture noisily {
        clear
        quietly set obs 10
        generate double x = _n
        generate double w = `s'
        table1_tc, vars(x conts %9.2f) wt(w) frame(_cxp1, replace)
        _cxp_expect _cxp1 "x" Total "5.50 (3.00, 8.00)"
    }
    if _rc == 0 {
        display as result "  PASS: S1a equal weights of `s' give 5.50 (3.00, 8.00)"
        local ++pass_count
    }
    else {
        display as error "  FAIL: S1a equal weights of `s' (rc=`=_rc')"
        local ++fail_count
    }
}

* Unequal weights (2, 3, 4, 1, ...) times the same tiny constants: the
* quartiles of the unscaled weights (3, 6, 7 by hand from the cumulative
* weights 2, 5, 9, 10, 12, 15, 19 of 25).
foreach s in 1e-12 1e-100 1e-300 {
    capture noisily {
        clear
        quietly set obs 10
        generate double x = _n
        generate double w1 = 1 + mod(_n, 4)
        generate double w = `s' * w1
        _cxp_iqr x, w(w1)
        local want "`r(cell)'"
        assert "`want'" == "6.00 (3.00, 7.00)"
        table1_tc, vars(x conts %9.2f) wt(w) frame(_cxp1, replace)
        _cxp_expect _cxp1 "x" Total "`want'"
    }
    if _rc == 0 {
        display as result "  PASS: S1b unequal weights times `s' keep the unscaled quartiles"
        local ++pass_count
    }
    else {
        display as error "  FAIL: S1b unequal weights times `s' (rc=`=_rc')"
        local ++fail_count
    }
}

* Within by() groups: each arm's quartiles from its own rescaled weights.
capture noisily {
    clear
    quietly set obs 20
    generate double x = _n + mod(_n, 3)
    generate byte g = 1 + (_n > 10)
    generate double w1 = 1 + mod(_n, 4)
    generate double w = 1e-200 * w1
    _cxp_iqr x if g == 1, w(w1)
    local want1 "`r(cell)'"
    _cxp_iqr x if g == 2, w(w1)
    local want2 "`r(cell)'"
    table1_tc, by(g) vars(x conts %9.2f) wt(w) frame(_cxp1, replace)
    _cxp_expect _cxp1 "x" g_1 "`want1'"
    _cxp_expect _cxp1 "x" g_2 "`want2'"
}
if _rc == 0 {
    display as result "  PASS: S1c by() arms keep their quartiles under weights of 1e-200"
    local ++pass_count
}
else {
    display as error "  FAIL: S1c by() arms under weights of 1e-200 (rc=`=_rc')"
    local ++fail_count
}

* A weight total just below 1 whose steps are far above the old 1e-10 floor
* (ten weights of 0.1; the double sum is 0.9999999999999999): still the
* exact-hit median 5.5.
capture noisily {
    clear
    quietly set obs 10
    generate double x = _n
    generate double w = 0.1
    table1_tc, vars(x conts %9.2f) wt(w) frame(_cxp1, replace)
    _cxp_expect _cxp1 "x" Total "5.50 (3.00, 8.00)"
}
if _rc == 0 {
    display as result "  PASS: S1d ten weights of 0.1 keep the exact-hit median"
    local ++pass_count
}
else {
    display as error "  FAIL: S1d ten weights of 0.1 (rc=`=_rc')"
    local ++fail_count
}

* Guard: totals of 1 and more are unchanged (unit and 1e6-scaled weights).
foreach s in 1 1e6 {
    capture noisily {
        clear
        quietly set obs 10
        generate double x = _n
        generate double w1 = 1 + mod(_n, 4)
        generate double w = `s' * w1
        table1_tc, vars(x conts %9.2f) wt(w) frame(_cxp1, replace)
        _cxp_expect _cxp1 "x" Total "6.00 (3.00, 7.00)"
    }
    if _rc == 0 {
        display as result "  PASS: S1e guard: weights times `s' give 6.00 (3.00, 7.00)"
        local ++pass_count
    }
    else {
        display as error "  FAIL: S1e guard: weights times `s' (rc=`=_rc')"
        local ++fail_count
    }
}

**# S2: automatic typing at extreme value scales
* Moment branch (6,000 values). y = 1..6000 is uniform: skewness 0 and
* kurtosis 1.8 by hand, so |1.8 - 3| < 2 types it contn. Its scaled copies
* must follow it. summarize returns missing moments for the 1e100 and 1e200
* copies (fourth powers overflow) and for the 1e-100 copy (they underflow).
capture noisily {
    clear
    quietly set obs 6000
    generate double y = _n
    quietly summarize y, detail
    assert abs(r(skewness)) < 1e-8
    assert abs(r(kurtosis) - 1.8) < 1e-3
    _cxp_type y
    assert "`r(type)'" == "contn"
}
if _rc == 0 {
    display as result "  PASS: S2a guard: uniform 1..6000 is typed contn"
    local ++pass_count
}
else {
    display as error "  FAIL: S2a guard: uniform 1..6000 (rc=`=_rc')"
    local ++fail_count
}

foreach s in 1e100 1e200 -1e100 1e-100 {
    capture noisily {
        clear
        quietly set obs 6000
        generate double x = _n * `s'
        _cxp_type x
        assert "`r(type)'" == "contn"
    }
    if _rc == 0 {
        display as result "  PASS: S2b uniform 1..6000 times `s' is typed contn"
        local ++pass_count
    }
    else {
        display as error "  FAIL: S2b uniform 1..6000 times `s' (rc=`=_rc')"
        local ++fail_count
    }
}

* A right-skewed variable (log-normal, skewness well above 1) stays conts at
* every scale.
foreach s in 1 1e150 1e-150 {
    capture noisily {
        clear
        quietly set obs 6000
        set seed 20260926
        generate double y = exp(rnormal())
        quietly summarize y, detail
        assert r(skewness) > 1
        generate double x = y * `s'
        _cxp_type x
        assert "`r(type)'" == "conts"
    }
    if _rc == 0 {
        display as result "  PASS: S2c log-normal times `s' is typed conts"
        local ++pass_count
    }
    else {
        display as error "  FAIL: S2c log-normal times `s' (rc=`=_rc')"
        local ++fail_count
    }
}

* Shapiro-Wilk branch (3,000 values; the helper tests a reproducible
* 2,000-row subsample). y = 1..3000 is uniform and swilk rejects normality
* on it, so it is conts; its scaled copies must follow it. swilk itself
* reports 0 observations and a missing p for the 1e100 copy.
capture noisily {
    clear
    quietly set obs 3000
    generate double y = _n
    quietly swilk y
    assert r(p) < 0.05
    _cxp_type y
    assert "`r(type)'" == "conts"
}
if _rc == 0 {
    display as result "  PASS: S2d guard: uniform 1..3000 is typed conts (swilk p < 0.05)"
    local ++pass_count
}
else {
    display as error "  FAIL: S2d guard: uniform 1..3000 (rc=`=_rc')"
    local ++fail_count
}

foreach s in 1e100 1e200 -1e100 1e-100 {
    capture noisily {
        clear
        quietly set obs 3000
        generate double x = _n * `s'
        _cxp_type x
        assert "`r(type)'" == "conts"
    }
    if _rc == 0 {
        display as result "  PASS: S2e uniform 1..3000 times `s' is typed conts"
        local ++pass_count
    }
    else {
        display as error "  FAIL: S2e uniform 1..3000 times `s' (rc=`=_rc')"
        local ++fail_count
    }
}

* Normal data in the Shapiro-Wilk branch stay contn at every scale (exact
* normal quantiles, so swilk's p is near 1 without depending on a seed).
foreach s in 1 1e150 1e-150 {
    capture noisily {
        clear
        quietly set obs 1500
        generate double y = invnormal((_n - 0.5) / 1500)
        quietly swilk y
        assert r(p) >= 0.05
        generate double x = y * `s'
        _cxp_type x
        assert "`r(type)'" == "contn"
    }
    if _rc == 0 {
        display as result "  PASS: S2f normal sample times `s' is typed contn"
        local ++pass_count
    }
    else {
        display as error "  FAIL: S2f normal sample times `s' (rc=`=_rc')"
        local ++fail_count
    }
}

**# Summary
capture frame drop _cxp1
capture frame drop _cxp_t
local test_count = `pass_count' + `fail_count'
display ""
display as result "Results: `pass_count'/`test_count' passed, `fail_count' failed"
if `fail_count' > 0 {
    display as error "SOME TESTS FAILED"
    display "RESULT: test_codex_parity_2026_09_26 tests=`test_count' pass=`pass_count' fail=`fail_count'"
    log close _cxp
    exit 1
}
display as result "ALL TESTS PASSED"
display "RESULT: test_codex_parity_2026_09_26 tests=`test_count' pass=`pass_count' fail=`fail_count'"
log close _cxp
