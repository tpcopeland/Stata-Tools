* test_excel_fidelity.do — workbook content, types, and presentation contracts

clear all
version 16.0
set more off
set varabbrev off

capture log close _all
log using "test_excel_fidelity.log", replace nomsg

do "`c(pwd)'/_psdash_bootstrap.do"
discard

global xf_test_count = 0
global xf_pass_count = 0
global xf_fail_count = 0
global xf_failed_tests ""

capture program drop _xf_result
program define _xf_result
    args test_id rc
    global xf_test_count = $xf_test_count + 1
    if `rc' == 0 {
        display as result "PASS: `test_id'"
        global xf_pass_count = $xf_pass_count + 1
    }
    else {
        display as error "FAIL: `test_id' (rc=`rc')"
        global xf_fail_count = $xf_fail_count + 1
        global xf_failed_tests "$xf_failed_tests `test_id'"
    }
end

local tools_dir "`c(pwd)'/tools"
local outdir "`_qa_sysroot'/xlsx"
capture mkdir "`outdir'"

capture program drop _xf_data
program define _xf_data
    clear
    set obs 60
    gen byte treat = _n > 30
    gen double ps = cond(treat, .55 + (_n-31)/500, .35 + (_n-1)/500)
    gen double x1 = treat + _n/100
    gen double x2 = mod(_n, 5)
    gen double wt = cond(treat, 1/ps, 1/(1-ps))
end

**# Balance export preserves all SMD/VR/KS columns as numeric cells
capture noisily {
    _xf_data
    quietly summarize x1 if treat == 1, meanonly
    local mean_treated = r(mean)
    local book "`outdir'/balance.xlsx"
    psdash balance treat ps, covariates(x1 x2) wvar(wt) xlsx("`book'")
    local result "`outdir'/balance_check.txt"
    shell python3 "`tools_dir'/check_xlsx.py" "`book'" --sheet Balance ///
        --exact-cols 11 --header-exact 2 "Covariate" "Mean (Treated)" ///
        "Mean (Control)" "SMD (Raw)" "VR (Raw)" "KS (Raw)" ///
        "Mean (T, Adj)" "Mean (C, Adj)" "SMD (Adj)" "VR (Adj)" ///
        "KS (Adj)" --cell-approx B3 `mean_treated' 1e-10 --bold-row 2 ///
        --has-borders --result-file "`result'" --quiet
    tempname fh
    file open `fh' using "`result'", read text
    file read `fh' line
    file close `fh'
    assert "`line'" == "PASS"
}
_xf_result "balance_workbook_fidelity" `=_rc'

**# Key/value exports keep numeric values numeric and style the header
capture noisily {
    _xf_data
    local book "`outdir'/weights.xlsx"
    psdash weights treat ps, wvar(wt) xlsx("`book'")
    local result "`outdir'/weights_check.txt"
    shell python3 "`tools_dir'/check_xlsx.py" "`book'" --sheet Weights ///
        --exact-cols 2 --header-exact 2 "Metric" "Value" ///
        --cell-approx B4 60 0 --bold-row 2 --has-borders ///
        --result-file "`result'" --quiet
    tempname fh
    file open `fh' using "`result'", read text
    file read `fh' line
    file close `fh'
    assert "`line'" == "PASS"
}
_xf_result "key_value_workbook_numeric_types" `=_rc'

display as text _n "RESULT: test_excel_fidelity tests=$xf_test_count pass=$xf_pass_count fail=$xf_fail_count"

_psdash_qa_cleanup
capture log close _all

if $xf_fail_count > 0 {
    display as error "Failed tests:$xf_failed_tests"
    macro drop xf_test_count xf_pass_count xf_fail_count xf_failed_tests
    exit 9
}
macro drop xf_test_count xf_pass_count xf_fail_count xf_failed_tests
