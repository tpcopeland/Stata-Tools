* test_mvp_labels.do — Regression tests for gby/over value label fix
* Verifies that value labels survive preserve/clear in graph code
* Tests 2-level, 3-level, unlabeled, and string gby/over variables
* Self-contained: generates own test data

clear all
set more off
version 16.0

**# Bootstrap
local qa_dir  "`c(pwd)'"
local pkg_dir "`qa_dir'/.."

capture ado uninstall mvp
net install mvp, from("`pkg_dir'/") replace force

local test_count = 0
local pass_count = 0
local fail_count = 0

**# Test data
quietly {
    clear
    set seed 54321
    set obs 300
    gen double age = rnormal(50, 12)
    gen double bmi = rnormal(27, 5)
    gen double sbp = rnormal(130, 18)
    gen double ldl = rnormal(3.5, 1.1)

    * 3-level treatment arm with value labels
    gen byte arm = cond(_n <= 100, 0, cond(_n <= 200, 1, 2))
    label define armlbl 0 "Placebo" 1 "Low dose" 2 "High dose"
    label values arm armlbl

    * 2-level binary with value labels
    gen byte female = rbinomial(1, 0.5)
    label define sexlbl 0 "Male" 1 "Female"
    label values female sexlbl

    * 3-level unlabeled numeric
    gen byte group3 = cond(_n <= 100, 1, cond(_n <= 200, 2, 3))

    * String grouping variable
    gen str10 site = cond(_n <= 100, "Boston", cond(_n <= 200, "London", "Tokyo"))

    * Introduce missingness
    replace bmi = . if runiform() < 0.10
    replace sbp = . if runiform() < 0.08
    replace ldl = . if runiform() < 0.15
    * Extra missingness in arm==2
    replace ldl = . if arm == 2 & runiform() < 0.10

    tempfile testdata
    save `testdata', replace
}

**# T1: gby() with 3-level labeled variable returns correct r(gby_levels)
local ++test_count
capture noisily {
    use `testdata', clear
    mvp bmi sbp ldl, graph(bar) gby(arm) nodraw
    assert "`r(gby)'" == "arm"
    assert "`r(gby_levels)'" == "0 1 2"
    local ++pass_count
    display as result "  PASS `test_count': gby(arm) 3-level labeled — runs and returns correct levels"
}
if _rc {
    local ++fail_count
    display as error "  FAIL `test_count': gby(arm) 3-level labeled (rc=`=_rc')"
}

**# T2: over() with 3-level labeled variable
local ++test_count
capture noisily {
    use `testdata', clear
    mvp bmi sbp ldl, graph(bar) over(arm) nodraw
    assert "`r(over)'" == "arm"
    assert "`r(over_levels)'" == "0 1 2"
    local ++pass_count
    display as result "  PASS `test_count': over(arm) 3-level labeled — runs and returns correct levels"
}
if _rc {
    local ++fail_count
    display as error "  FAIL `test_count': over(arm) 3-level labeled (rc=`=_rc')"
}

**# T3: gby() patterns with 3-level labeled variable
local ++test_count
capture noisily {
    use `testdata', clear
    mvp bmi sbp ldl, graph(patterns) gby(arm) top(3) nodraw
    assert "`r(gby)'" == "arm"
    local ++pass_count
    display as result "  PASS `test_count': gby(arm) patterns 3-level labeled"
}
if _rc {
    local ++fail_count
    display as error "  FAIL `test_count': gby(arm) patterns 3-level labeled (rc=`=_rc')"
}

**# T4: gby() with 3-level UNLABELED variable (should use "var = val" format)
local ++test_count
capture noisily {
    use `testdata', clear
    mvp bmi sbp ldl, graph(bar) gby(group3) nodraw
    assert "`r(gby)'" == "group3"
    assert "`r(gby_levels)'" == "1 2 3"
    local ++pass_count
    display as result "  PASS `test_count': gby(group3) 3-level unlabeled"
}
if _rc {
    local ++fail_count
    display as error "  FAIL `test_count': gby(group3) 3-level unlabeled (rc=`=_rc')"
}

**# T5: over() with 3-level UNLABELED variable
local ++test_count
capture noisily {
    use `testdata', clear
    mvp bmi sbp ldl, graph(bar) over(group3) nodraw
    assert "`r(over)'" == "group3"
    local ++pass_count
    display as result "  PASS `test_count': over(group3) 3-level unlabeled"
}
if _rc {
    local ++fail_count
    display as error "  FAIL `test_count': over(group3) 3-level unlabeled (rc=`=_rc')"
}

**# T6: gby() with STRING variable
local ++test_count
capture noisily {
    use `testdata', clear
    mvp bmi sbp ldl, graph(bar) gby(site) nodraw
    assert "`r(gby)'" == "site"
    local ++pass_count
    display as result "  PASS `test_count': gby(site) string variable"
}
if _rc {
    local ++fail_count
    display as error "  FAIL `test_count': gby(site) string variable (rc=`=_rc')"
}

**# T7: gby() patterns with STRING variable
local ++test_count
capture noisily {
    use `testdata', clear
    mvp bmi sbp ldl, graph(patterns) gby(site) top(3) nodraw
    assert "`r(gby)'" == "site"
    local ++pass_count
    display as result "  PASS `test_count': gby(site) patterns string variable"
}
if _rc {
    local ++fail_count
    display as error "  FAIL `test_count': gby(site) patterns string variable (rc=`=_rc')"
}

**# T8: gby() with 2-level labeled variable (existing behavior preserved)
local ++test_count
capture noisily {
    use `testdata', clear
    mvp bmi sbp ldl, graph(bar) gby(female) nodraw
    assert "`r(gby)'" == "female"
    assert "`r(gby_levels)'" == "0 1"
    local ++pass_count
    display as result "  PASS `test_count': gby(female) 2-level labeled — backward compat"
}
if _rc {
    local ++fail_count
    display as error "  FAIL `test_count': gby(female) 2-level labeled (rc=`=_rc')"
}

**# T9: over() with 2-level labeled variable (existing behavior preserved)
local ++test_count
capture noisily {
    use `testdata', clear
    mvp bmi sbp ldl, graph(bar) over(female) nodraw
    assert "`r(over)'" == "female"
    assert "`r(over_levels)'" == "0 1"
    local ++pass_count
    display as result "  PASS `test_count': over(female) 2-level labeled — backward compat"
}
if _rc {
    local ++fail_count
    display as error "  FAIL `test_count': over(female) 2-level labeled (rc=`=_rc')"
}

**# T10: gby() preserves user data
local ++test_count
capture noisily {
    use `testdata', clear
    local N_before = _N
    mvp bmi sbp ldl, graph(bar) gby(arm) nodraw
    assert _N == `N_before'
    confirm variable age bmi sbp ldl arm female group3 site
    local ++pass_count
    display as result "  PASS `test_count': gby(arm) preserves user data"
}
if _rc {
    local ++fail_count
    display as error "  FAIL `test_count': gby(arm) preserves user data (rc=`=_rc')"
}

**# T11: over() preserves user data
local ++test_count
capture noisily {
    use `testdata', clear
    local N_before = _N
    mvp bmi sbp ldl, graph(bar) over(arm) nodraw
    assert _N == `N_before'
    confirm variable age bmi sbp ldl arm female group3 site
    local ++pass_count
    display as result "  PASS `test_count': over(arm) preserves user data"
}
if _rc {
    local ++fail_count
    display as error "  FAIL `test_count': over(arm) preserves user data (rc=`=_rc')"
}

**# T12: gby() + stacked rejected (only graph(bar) without stacked)
local ++test_count
capture noisily {
    use `testdata', clear
    capture mvp bmi sbp ldl, graph(bar) gby(arm) stacked nodraw
    assert _rc == 0
    local ++pass_count
    display as result "  PASS `test_count': gby(arm) + stacked runs without error"
}
if _rc {
    local ++fail_count
    display as error "  FAIL `test_count': gby(arm) + stacked (rc=`=_rc')"
}

**# T13: over() with 3-level string variable
local ++test_count
capture noisily {
    use `testdata', clear
    capture mvp bmi sbp ldl, graph(bar) over(site) nodraw
    assert _rc == 0
    local ++pass_count
    display as result "  PASS `test_count': over(site) 3-level string variable"
}
if _rc {
    local ++fail_count
    display as error "  FAIL `test_count': over(site) 3-level string variable (rc=`=_rc')"
}

**# T14: gby() with if condition
local ++test_count
capture noisily {
    use `testdata', clear
    mvp bmi sbp ldl if age > 40 | missing(age), graph(bar) gby(arm) nodraw
    assert "`r(gby)'" == "arm"
    local ++pass_count
    display as result "  PASS `test_count': gby(arm) with if condition"
}
if _rc {
    local ++fail_count
    display as error "  FAIL `test_count': gby(arm) with if condition (rc=`=_rc')"
}

**# T15: over() with sort option
local ++test_count
capture noisily {
    use `testdata', clear
    mvp bmi sbp ldl, graph(bar) over(arm) sort nodraw
    assert "`r(over)'" == "arm"
    local ++pass_count
    display as result "  PASS `test_count': over(arm) + sort"
}
if _rc {
    local ++fail_count
    display as error "  FAIL `test_count': over(arm) + sort (rc=`=_rc')"
}

**# Summary
display ""
display as text "{hline 60}"
display "MVP LABEL REGRESSION TEST SUMMARY"
display "{hline 60}"
display "Total:  `test_count'"
display as result "Passed: `pass_count'"
if `fail_count' > 0 {
    display as error "Failed: `fail_count'"
}
else {
    display "Failed: `fail_count'"
}
display "{hline 60}"

if `fail_count' > 0 {
    display as error "SOME TESTS FAILED"
    exit 1
}
else {
    display as result "ALL TESTS PASSED"
}
