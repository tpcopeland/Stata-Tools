* test_stratetab.do - Dedicated QA for stratetab

clear all
set more off
set varabbrev off

capture log close _stratetab
log using "test_stratetab.log", replace text name(_stratetab)

local qa_dir "`c(pwd)'"
local pkg_dir = subinstr("`qa_dir'", "/qa", "", 1)
local output_dir "`qa_dir'/output"
capture mkdir "`output_dir'"

capture ado uninstall tabtools
quietly net install tabtools, from("`pkg_dir'") replace

local test_count = 0
local pass_count = 0
local fail_count = 0

**# Helpers
program define _make_issue_strate
    syntax , BASENAME(string)
    clear
    set obs 3
    gen exposure = _n - 1
    gen _D = cond(_n == 1, 10, cond(_n == 2, 20, 30))
    gen _Y = cond(_n == 1, 1000, cond(_n == 2, 1100, 1200))
    gen _Rate = _D / _Y
    gen _Lower = _Rate * 0.8
    gen _Upper = _Rate * 1.2
    label define issue_exp 0 "Low" 1 "Medium" 2 "High", replace
    label values exposure issue_exp
    save "`basename'.dta", replace
end

**# Output Modes
**## console-only mode works without xlsx()
local ++test_count
capture noisily {
    tempfile rate1
    _make_issue_strate, basename("`rate1'")
    sysuse auto, clear
    stratetab, using("`rate1'") outcomes(1) display
    assert r(N_rows) >= 6
}
if _rc == 0 {
    display as result "  PASS: stratetab display without xlsx()"
    local ++pass_count
}
else {
    display as error "  FAIL: stratetab display without xlsx() (rc=`=_rc')"
    local ++fail_count
}

**## frame() works without xlsx()
local ++test_count
capture noisily {
    tempfile rate1
    _make_issue_strate, basename("`rate1'")
    sysuse auto, clear
    capture frame drop issue_rates
    stratetab, using("`rate1'") outcomes(1) frame(issue_rates, replace)
    assert "`r(frame)'" == "issue_rates"
    frame issue_rates: assert _N >= 6
}
if _rc == 0 {
    display as result "  PASS: stratetab frame() without xlsx()"
    local ++pass_count
}
else {
    display as error "  FAIL: stratetab frame() without xlsx() (rc=`=_rc')"
    local ++fail_count
}
capture frame drop issue_rates

**## display + frame() work together without xlsx()
local ++test_count
capture noisily {
    tempfile rate1
    _make_issue_strate, basename("`rate1'")
    sysuse auto, clear
    capture frame drop issue_rates2
    stratetab, using("`rate1'") outcomes(1) frame(issue_rates2, replace) display
    assert "`r(frame)'" == "issue_rates2"
    frame issue_rates2: assert _N >= 6
}
if _rc == 0 {
    display as result "  PASS: stratetab display + frame() without xlsx()"
    local ++pass_count
}
else {
    display as error "  FAIL: stratetab display + frame() without xlsx() (rc=`=_rc')"
    local ++fail_count
}
capture frame drop issue_rates2

**## xlsx export still works alongside frame()
local ++test_count
capture noisily {
    tempfile rate1
    _make_issue_strate, basename("`rate1'")
    local xlsx "`output_dir'/stratetab_issue.xlsx"
    capture erase "`xlsx'"
    sysuse auto, clear
    capture frame drop issue_rates3
    stratetab, using("`rate1'") outcomes(1) xlsx("`xlsx'") sheet("Rates") ///
        title("Issue Rates") frame(issue_rates3, replace) display
    confirm file "`xlsx'"
    assert "`r(frame)'" == "issue_rates3"
    frame issue_rates3: assert _N >= 6
}
if _rc == 0 {
    display as result "  PASS: stratetab xlsx + frame() + display"
    local ++pass_count
}
else {
    display as error "  FAIL: stratetab xlsx + frame() + display (rc=`=_rc')"
    local ++fail_count
}
capture frame drop issue_rates3

display as result "stratetab QA summary: `pass_count' passed, `fail_count' failed"
if `fail_count' > 0 exit 1

log close _stratetab
