* crossval_tabtools_published_armitage1955.do - published reproduction of the
* Cochran-Armitage trend test (crosstab, cochran)
*
* Source: Armitage P. Tests for linear trends in proportions and frequencies.
* Biometrics 1955;11(3):375-386 (_literature/tabtools, row armitage-1955).
* Table 1 (p. 375): nasal carriers of Streptococcus pyogenes by tonsil size
* among 1,398 children, carriers 19/29/24 and non-carriers 497/560/269.
* With scores -1, 0, 1 the paper reports the trend chi-squared 7.19 on 1 d.f.
* (P = 0.007, p. 378) against the 2 x 3 chi-squared 7.89 on 2 d.f. (p. 375,
* restated p. 379; Pearson's statistic is 7.885, so 7.89 is hand rounding).
* Scores 1, 2, 3 give the same statistic (the test is invariant to a shift
* of the scores).
*
* PUBLISHED: Armitage 1955 Table 1; chi2_trend 7.19, p 0.007, chi2 7.89.
* Run from tabtools/qa.

clear all
version 17.0
set more off
set varabbrev off

capture log close _xarm
log using "crossval_tabtools_published_armitage1955.log", replace text name(_xarm)

local test_count = 0
local pass_count = 0
local failed ""

local qa_dir "`c(pwd)'"
local pkg_dir = regexr("`qa_dir'", "/qa$", "")
capture ado uninstall tabtools
quietly net install tabtools, from("`pkg_dir'") replace
discard
tabtools set clear

**# PA1: Table 1 reproduces chi2_trend = 7.19 (P = 0.007) and chi2 = 7.89
local ++test_count
capture noisily {
    clear
    input byte carrier byte size int n
    1 1  19
    1 2  29
    1 3  24
    0 1 497
    0 2 560
    0 3 269
    end
    label define _xarm_c 0 "Non-carrier" 1 "Carrier"
    label values carrier _xarm_c
    label define _xarm_s 1 "+" 2 "++" 3 "+++"
    label values size _xarm_s
    quietly expand n
    assert _N == 1398
    crosstab carrier size, cochran label
    local c2t = r(chi2_trend)
    local pt = r(p_trend)
    local c2 = r(chi2)
    display as text "  PA1 crosstab: chi2_trend " %6.3f `c2t' " (paper 7.19), p_trend " %6.4f `pt' " (paper 0.007), chi2 " %6.3f `c2' " (paper 7.89)"
    * the paper prints two decimals for chi2 and three for P
    assert abs(`c2t' - 7.19) < 0.005
    assert abs(`pt' - 0.007) < 0.0005
    * the 2 x 3 total is 7.885 to three decimals; the paper's hand
    * calculation prints 7.89, so allow one unit of its last digit
    assert abs(`c2' - 7.89) < 0.01
}
if _rc == 0 {
    display as result "  PASS: PA1 Armitage 1955 Table 1 trend and total chi-squared reproduced"
    local ++pass_count
}
else {
    display as error "  FAIL: PA1 Armitage 1955 Table 1 (rc=`=_rc')"
    local failed "`failed' PA1"
}

**# Summary
local fail_count = `test_count' - `pass_count'
if `fail_count' display as error "failed:`failed'"
display as text "RESULT: crossval_tabtools_published_armitage1955 tests=`test_count' pass=`pass_count' fail=`fail_count'"
capture log close _xarm
if `fail_count' > 0 exit 1
exit 0
