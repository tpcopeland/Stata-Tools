* Focused regression tests for tabtools issue fixes

clear all

local qa_dir "`c(pwd)'"
local pkg_dir = subinstr("`qa_dir'", "/qa", "", 1)

capture ado uninstall tabtools
quietly net install tabtools, from("`pkg_dir'") replace

local output_dir "`qa_dir'/output_issue_regressions"
capture mkdir "`output_dir'"

local test_count = 0
local pass_count = 0
local fail_count = 0
local failed_tests ""

* Test 1: stratetab supports console-only mode without xlsx()
local ++test_count
capture noisily {
    tempfile rate1
    clear
    set obs 3
    gen exposure = _n - 1
    gen _D = cond(_n == 1, 10, cond(_n == 2, 20, 30))
    gen _Y = cond(_n == 1, 1000, cond(_n == 2, 1100, 1200))
    gen _Rate = _D / _Y
    gen _Lower = _Rate * 0.8
    gen _Upper = _Rate * 1.2
    label define issue_exp 0 "Low" 1 "Medium" 2 "High"
    label values exposure issue_exp
    save "`rate1'.dta", replace

    sysuse auto, clear
    stratetab, using("`rate1'") outcomes(1) display
    assert r(N_rows) >= 6
    capture erase "`rate1'.dta"
}
if _rc == 0 {
    display as result "  PASS: stratetab display without xlsx()"
    local ++pass_count
}
else {
    display as error "  FAIL: stratetab display without xlsx() (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 1"
}

* Test 2: stratetab supports frame() without xlsx()
local ++test_count
capture noisily {
    tempfile rate1
    clear
    set obs 3
    gen exposure = _n - 1
    gen _D = cond(_n == 1, 15, cond(_n == 2, 25, 35))
    gen _Y = cond(_n == 1, 900, cond(_n == 2, 1000, 1100))
    gen _Rate = _D / _Y
    gen _Lower = _Rate * 0.8
    gen _Upper = _Rate * 1.2
    label define issue_exp2 0 "Low" 1 "Medium" 2 "High"
    label values exposure issue_exp2
    save "`rate1'.dta", replace

    sysuse auto, clear
    capture frame drop issue_rates
    stratetab, using("`rate1'") outcomes(1) frame(issue_rates, replace)
    assert r(frame) == "issue_rates"
    frame issue_rates: assert _N >= 6
    capture erase "`rate1'.dta"
}
if _rc == 0 {
    display as result "  PASS: stratetab frame() without xlsx()"
    local ++pass_count
}
else {
    display as error "  FAIL: stratetab frame() without xlsx() (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 2"
}
capture frame drop issue_rates

* Test 3: stratetab supports display + frame() together without xlsx()
local ++test_count
capture noisily {
    tempfile rate1
    clear
    set obs 3
    gen exposure = _n - 1
    gen _D = cond(_n == 1, 12, cond(_n == 2, 22, 32))
    gen _Y = cond(_n == 1, 950, cond(_n == 2, 1050, 1150))
    gen _Rate = _D / _Y
    gen _Lower = _Rate * 0.8
    gen _Upper = _Rate * 1.2
    label define issue_exp3 0 "Low" 1 "Medium" 2 "High"
    label values exposure issue_exp3
    save "`rate1'.dta", replace

    sysuse auto, clear
    capture frame drop issue_rates2
    stratetab, using("`rate1'") outcomes(1) frame(issue_rates2, replace) display
    assert r(frame) == "issue_rates2"
    frame issue_rates2: assert _N >= 6
    capture erase "`rate1'.dta"
}
if _rc == 0 {
    display as result "  PASS: stratetab display + frame() without xlsx()"
    local ++pass_count
}
else {
    display as error "  FAIL: stratetab display + frame() without xlsx() (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 3"
}
capture frame drop issue_rates2

* Test 4: stratetab rejects open without xlsx()
local ++test_count
capture noisily {
    tempfile rate1
    clear
    set obs 3
    gen exposure = _n - 1
    gen _D = cond(_n == 1, 12, cond(_n == 2, 22, 32))
    gen _Y = cond(_n == 1, 950, cond(_n == 2, 1050, 1150))
    gen _Rate = _D / _Y
    gen _Lower = _Rate * 0.8
    gen _Upper = _Rate * 1.2
    label define issue_exp4 0 "Low" 1 "Medium" 2 "High"
    label values exposure issue_exp4
    save "`rate1'.dta", replace

    sysuse auto, clear
    capture stratetab, using("`rate1'") outcomes(1) open
    assert _rc == 198
    capture erase "`rate1'.dta"
}
if _rc == 0 {
    display as result "  PASS: stratetab open requires xlsx()"
    local ++pass_count
}
else {
    display as error "  FAIL: stratetab open requires xlsx() (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 4"
}

* Test 5: crosstab validates boldp() bounds
local ++test_count
capture noisily {
    clear
    input exposure outcome
    0 0
    0 1
    1 0
    1 1
    end
    capture crosstab exposure outcome, boldp(1)
    assert _rc == 198
}
if _rc == 0 {
    display as result "  PASS: crosstab rejects invalid boldp()"
    local ++pass_count
}
else {
    display as error "  FAIL: crosstab rejects invalid boldp() (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 5"
}

* Test 6: survtab validates highlight() bounds
local ++test_count
capture noisily {
    clear
    set obs 20
    gen byte group = (_n > 10)
    gen double time = _n
    gen byte event = (_n <= 10)
    stset time, failure(event)
    capture survtab, times(1 2 3) by(group) highlight(0)
    assert _rc == 198
}
if _rc == 0 {
    display as result "  PASS: survtab rejects invalid highlight()"
    local ++pass_count
}
else {
    display as error "  FAIL: survtab rejects invalid highlight() (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 6"
}

display ""
display as result "=== tabtools issue regression tests: `pass_count' passed, `fail_count' failed out of `test_count' ==="
if `fail_count' > 0 {
    display as error "Failed tests:`failed_tests'"
    exit 1
}
