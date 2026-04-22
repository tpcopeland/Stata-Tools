* test_export_failure_returns.do - Ensure key r() results survive Excel export failures
* Date: 2026-04-22
* Covers: table1_tc, crosstab, corrtab, diagtab, survtab, stratetab,
*         regtab, effecttab, comptab, hrcomptab

clear all
set more off
set varabbrev off
version 17.0

capture log close _expfail
log using "test_export_failure_returns.log", replace text name(_expfail)

local qa_dir "`c(pwd)'"
local pkg_dir = subinstr("`qa_dir'", "/qa", "", 1)
local output_dir "`qa_dir'/output"
capture mkdir "`output_dir'"
local bad_root "`output_dir'/__missing_export_dir__"

capture ado uninstall tabtools
quietly net install tabtools, from("`pkg_dir'") replace

program define _make_exportfail_strate
    syntax , BASENAME(string)
    clear
    set obs 3
    gen exposure = _n - 1
    gen _D = cond(_n == 1, 10, cond(_n == 2, 20, 30))
    gen _Y = cond(_n == 1, 1000, cond(_n == 2, 1100, 1200))
    gen _Rate = _D / _Y
    gen _Lower = _Rate * 0.8
    gen _Upper = _Rate * 1.2
    label define exportfail_exp 0 "Low" 1 "Medium" 2 "High", replace
    label values exposure exportfail_exp
    save "`basename'.dta", replace
end

local test_count = 0
local pass_count = 0
local fail_count = 0

**# Direct builders
**## table1_tc returns varlist and table after xlsx() failure
local ++test_count
capture noisily {
    sysuse auto, clear
    return clear
    capture noisily table1_tc price mpg weight, by(foreign) ///
        xlsx("`bad_root'/table1_tc.xlsx")
    local rc = _rc
    assert `rc' != 0
    assert strpos("`r(varlist)'", "price") > 0
    tempname t1
    matrix `t1' = r(table)
    assert rowsof(`t1') > 0
}
if _rc == 0 {
    display as result "  PASS: table1_tc preserves r() after export failure"
    local ++pass_count
}
else {
    display as error "  FAIL: table1_tc export-failure returns (rc=`=_rc')"
    local ++fail_count
}

**## crosstab returns table and N after xlsx() failure
local ++test_count
capture noisily {
    clear
    input byte outcome byte exposure int freq
    0 0 40
    0 1 20
    1 0 10
    1 1 30
    end
    expand freq
    return clear
    capture noisily crosstab outcome exposure, ///
        xlsx("`bad_root'/crosstab.xlsx")
    local rc = _rc
    assert `rc' != 0
    assert r(N) == 100
    tempname ct
    matrix `ct' = r(table)
    assert rowsof(`ct') > 0
}
if _rc == 0 {
    display as result "  PASS: crosstab preserves r() after export failure"
    local ++pass_count
}
else {
    display as error "  FAIL: crosstab export-failure returns (rc=`=_rc')"
    local ++fail_count
}

**## corrtab returns correlation matrices after xlsx() failure
local ++test_count
capture noisily {
    sysuse auto, clear
    return clear
    capture noisily corrtab price mpg weight, ///
        xlsx("`bad_root'/corrtab.xlsx")
    local rc = _rc
    assert `rc' != 0
    tempname C N
    matrix `C' = r(C)
    matrix `N' = r(N)
    assert colsof(`C') == 3
    assert `N'[1,1] > 0
}
if _rc == 0 {
    display as result "  PASS: corrtab preserves r() after export failure"
    local ++pass_count
}
else {
    display as error "  FAIL: corrtab export-failure returns (rc=`=_rc')"
    local ++fail_count
}

**## diagtab returns scalar diagnostics after xlsx() failure
local ++test_count
capture noisily {
    sysuse auto, clear
    gen byte expensive = price > 6000 if !missing(price)
    gen byte heavy = weight > 3000 if !missing(weight)
    return clear
    capture noisily diagtab heavy expensive, ///
        xlsx("`bad_root'/diagtab.xlsx")
    local rc = _rc
    assert `rc' != 0
    assert r(sensitivity) >= 0 & r(sensitivity) <= 1
    assert r(specificity) >= 0 & r(specificity) <= 1
}
if _rc == 0 {
    display as result "  PASS: diagtab preserves r() after export failure"
    local ++pass_count
}
else {
    display as error "  FAIL: diagtab export-failure returns (rc=`=_rc')"
    local ++fail_count
}

**## survtab returns survival table after xlsx() failure
local ++test_count
capture noisily {
    webuse drugtr, clear
    stset studytime, failure(died)
    return clear
    capture noisily survtab, times(10 20) by(drug) ///
        xlsx("`bad_root'/survtab.xlsx")
    local rc = _rc
    assert `rc' != 0
    assert r(N_rows) > 0
    tempname st
    matrix `st' = r(table)
    assert rowsof(`st') > 0
}
if _rc == 0 {
    display as result "  PASS: survtab preserves r() after export failure"
    local ++pass_count
}
else {
    display as error "  FAIL: survtab export-failure returns (rc=`=_rc')"
    local ++fail_count
}

**## stratetab returns rate matrices after xlsx() failure
local ++test_count
capture noisily {
    tempfile rate1
    _make_exportfail_strate, basename("`rate1'")
    clear
    return clear
    capture noisily stratetab, using("`rate1'") outcomes(1) ///
        xlsx("`bad_root'/stratetab.xlsx")
    local rc = _rc
    capture confirm file "`bad_root'/stratetab.xlsx"
    assert _rc != 0
    assert r(N_rows) >= 6
    tempname rt
    matrix `rt' = r(rates)
    assert rowsof(`rt') > 0
    assert `"`r(xlsx)'"' == ""
}
if _rc == 0 {
    display as result "  PASS: stratetab preserves r() after export failure"
    local ++pass_count
}
else {
    display as error "  FAIL: stratetab export-failure returns (rc=`=_rc')"
    local ++fail_count
}

**# Collect-based builders
**## regtab returns table and model counts after xlsx() failure
local ++test_count
capture noisily {
    sysuse auto, clear
    collect clear
    collect: regress price mpg weight
    return clear
    capture noisily regtab, xlsx("`bad_root'/regtab.xlsx")
    local rc = _rc
    assert `rc' != 0
    assert r(N_models) == 1
    tempname rg
    matrix `rg' = r(table)
    assert rowsof(`rg') > 0
}
if _rc == 0 {
    display as result "  PASS: regtab preserves r() after export failure"
    local ++pass_count
}
else {
    display as error "  FAIL: regtab export-failure returns (rc=`=_rc')"
    local ++fail_count
}

**## effecttab returns table and detected type after xlsx() failure
local ++test_count
capture noisily {
    sysuse auto, clear
    quietly regress price mpg weight
    collect clear
    collect: margins, dydx(mpg weight)
    return clear
    capture noisily effecttab, type(margins) ///
        xlsx("`bad_root'/effecttab.xlsx")
    local rc = _rc
    assert `rc' != 0
    assert "`r(type)'" == "margins"
    tempname ef
    matrix `ef' = r(table)
    assert rowsof(`ef') > 0
}
if _rc == 0 {
    display as result "  PASS: effecttab preserves r() after export failure"
    local ++pass_count
}
else {
    display as error "  FAIL: effecttab export-failure returns (rc=`=_rc')"
    local ++fail_count
}

**## comptab returns composite dimensions after xlsx() failure
local ++test_count
capture noisily {
    capture frame drop ef_comp1
    capture frame drop ef_comp2

    sysuse auto, clear
    collect clear
    collect: regress price mpg
    regtab, frame(ef_comp1, replace)

    collect clear
    collect: regress price weight
    regtab, frame(ef_comp2, replace)

    return clear
    capture noisily comptab ef_comp1 ef_comp2, rows(1 \ 1) ///
        xlsx("`bad_root'/comptab.xlsx")
    local rc = _rc
    assert `rc' != 0
    assert r(N_frames) == 2
    assert r(N_rows) > 0
}
if _rc == 0 {
    display as result "  PASS: comptab preserves r() after export failure"
    local ++pass_count
}
else {
    display as error "  FAIL: comptab export-failure returns (rc=`=_rc')"
    local ++fail_count
}
capture frame drop ef_comp1
capture frame drop ef_comp2

**## hrcomptab returns scaffold metadata after xlsx() failure
local ++test_count
capture noisily {
    capture frame drop ef_rates
    capture frame drop ef_model

    tempfile rate1
    _make_exportfail_strate, basename("`rate1'")
    clear
    stratetab, using("`rate1'") outcomes(1) frame(ef_rates, replace)

    sysuse auto, clear
    collect clear
    collect: logistic foreign mpg weight
    regtab, frame(ef_model, replace) coef(OR)

    return clear
    capture noisily hrcomptab ef_rates, modelframes(ef_model) rows(1 2) ///
        xlsx("`bad_root'/hrcomptab.xlsx")
    local rc = _rc
    assert `rc' != 0
    assert r(N_outcomes) == 1
    assert r(N_modelframes) == 1
    assert r(N_rows) > 0
}
if _rc == 0 {
    display as result "  PASS: hrcomptab preserves r() after export failure"
    local ++pass_count
}
else {
    display as error "  FAIL: hrcomptab export-failure returns (rc=`=_rc')"
    local ++fail_count
}
capture frame drop ef_rates
capture frame drop ef_model

display as result "export-failure QA summary: `pass_count' passed, `fail_count' failed"
if `fail_count' > 0 exit 1

log close _expfail
