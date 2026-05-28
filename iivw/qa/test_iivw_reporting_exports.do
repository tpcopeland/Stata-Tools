clear all
set more off
version 16.0
set varabbrev off

capture log close _all
tempfile test_log
log using "`test_log'", replace nomsg

local qa_dir "`c(pwd)'"
local basename = substr("`qa_dir'", strrpos("`qa_dir'", "/") + 1, .)
if "`basename'" != "qa" {
    display as error "test_iivw_reporting_exports.do must be run from iivw/qa"
    log close _all
    exit 198
}
local pkg_dir = subinstr("`qa_dir'", "/qa", "", 1)

ado dir
capture ado uninstall iivw
quietly net install iivw, from("`pkg_dir'") replace
discard

local test_count = 0
local pass_count = 0
local fail_count = 0
local failed_tests ""

capture program drop _reporting_balance_panel
program define _reporting_balance_panel
    version 16.0
    clear
    set obs 8
    gen long id = ceil(_n / 2)
    bysort id: gen byte t = _n
    gen byte x = mod(_n, 2)
    gen byte z = x == 0
    gen double _iivw_weight = cond(inlist(_n, 1, 4, 5, 8), .5, 1.5)

    char _dta[_iivw_weighted] "1"
    char _dta[_iivw_id] "id"
    char _dta[_iivw_time] "t"
    char _dta[_iivw_weight_var] "_iivw_weight"
    char _dta[_iivw_prefix] "_iivw_"
    char _dta[_iivw_weighttype] "iivw"
    char _dta[_iivw_visit_covars] "x"
end

capture program drop _reporting_diag_post
program define _reporting_diag_post, eclass
    version 16.0
    args estname b se
    tempname bmat vmat
    matrix `bmat' = (`b')
    matrix colnames `bmat' = x
    matrix `vmat' = (`se'^2)
    matrix rownames `vmat' = x
    matrix colnames `vmat' = x
    ereturn post `bmat' `vmat', obs(100)
    ereturn local cmd "regress"
    estimates store `estname'
end

capture program drop _reporting_diag_known
program define _reporting_diag_known
    version 16.0
    estimates clear
    _reporting_diag_post M_unw 0.42 0.08
    _reporting_diag_post M_wgt 0.31 0.09
    _reporting_diag_post M_adj 0.10 0.10
end

**# T1: installed export helper is available after net install

local ++test_count
capture noisily {
    which _iivw_export_table
}
if _rc == 0 {
    display as result "  PASS: T1 - installed export helper available"
    local ++pass_count
}
else {
    display as error "  FAIL: T1 - installed export helper unavailable (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' T1"
}

**# T2: iivw_balance styled workbook matches r(balance)

local ++test_count
capture noisily {
    _reporting_balance_panel
    regress x z
    local active_cmd "`e(cmd)'"
    local active_b = _b[z]

    iivw_balance z x
    matrix B0 = r(balance)
    local covars0 "`r(balance_covars)'"

    tempfile balxlsx_stub
    local balxlsx "`balxlsx_stub'.xlsx"
    capture erase "`balxlsx'"

    iivw_balance z x, xlsx("`balxlsx'") sheet(Balance) replace
    matrix B1 = r(balance)
    assert "`r(xlsx)'" == "`balxlsx'"
    assert "`r(sheet)'" == "Balance"
    assert r(decimals) == 4
    assert "`r(csv)'" == ""
    assert "`r(frame)'" == ""
    assert "`r(balance_covars)'" == "`covars0'"
    assert "`e(cmd)'" == "`active_cmd'"
    assert reldif(_b[z], `active_b') < 1e-12
    assert _N == 8

    forvalues i = 1/2 {
        forvalues j = 1/8 {
            assert reldif(B0[`i', `j'], B1[`i', `j']) < 1e-12
        }
    }

    tempfile balmark
    shell python3 "`qa_dir'/tools/check_iivw_xlsx.py" ///
        "`balxlsx'" Balance balance 2 "`balmark'"
    confirm file "`balmark'"

    import excel using "`balxlsx'", sheet("Balance") cellrange(A4:I5) clear
    assert _N == 2
    assert A[1] == "x"
    assert A[2] == "z"
    assert reldif(B[1], B0[1,1]) < 1e-12
    assert reldif(F[1], B0[1,5]) < 1e-12
}
if _rc == 0 {
    display as result "  PASS: T2 - iivw_balance styled workbook"
    local ++pass_count
}
else {
    display as error "  FAIL: T2 - iivw_balance styled workbook (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' T2"
}

**# T3: iivw_diagnose styled workbook matches r(estimates)/scalars

local ++test_count
capture noisily {
    _reporting_diag_known
    clear
    set obs 30
    gen double q = _n
    gen double y = 1 + 2 * q
    regress y q
    local active_cmd "`e(cmd)'"
    local active_b = _b[q]

    tempfile diagxlsx_stub
    local diagxlsx "`diagxlsx_stub'.xlsx"
    capture erase "`diagxlsx'"

    iivw_diagnose x, unweighted(M_unw) weighted(M_wgt) ///
        adjusted(M_adj) exogeneity(exogenous) true(0.10) ///
        excel("`diagxlsx'") replace
    matrix E = r(estimates)
    local sampling_gap = r(sampling_gap)
    local bias_adjusted = r(bias_adjusted)
    assert "`r(xlsx)'" == "`diagxlsx'"
    assert "`r(sheet)'" == "Diagnostics"
    assert "`r(csv)'" == ""
    assert "`r(frame)'" == ""
    assert "`e(cmd)'" == "`active_cmd'"
    assert reldif(_b[q], `active_b') < 1e-12

    tempfile diagmark
    shell python3 "`qa_dir'/tools/check_iivw_xlsx.py" ///
        "`diagxlsx'" Diagnostics diagnostics 14 "`diagmark'"
    confirm file "`diagmark'"

    import excel using "`diagxlsx'", sheet("Diagnostics") cellrange(A4:G17) clear
    assert _N == 14
    assert A[1] == "estimate"
    assert B[1] == "unweighted"
    assert reldif(C[1], E[1,1]) < 1e-12
    assert B[4] == "sampling_gap"
    assert reldif(G[4], `sampling_gap') < 1e-12
    assert B[14] == "bias_adjusted"
    assert reldif(G[14], `bias_adjusted') < 1e-12
}
if _rc == 0 {
    display as result "  PASS: T3 - iivw_diagnose styled workbook"
    local ++pass_count
}
else {
    display as error "  FAIL: T3 - iivw_diagnose styled workbook (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' T3"
}

**# T4: reporting option validation rejects non-xlsx exports

local ++test_count
capture noisily {
    _reporting_balance_panel
    tempfile b1 b2
    local badxls "`b1'.xls"
    local goodxlsx "`b1'.xlsx"
    local otherxlsx "`b2'.xlsx"

    capture noisily iivw_balance, open
    assert _rc == 198
    capture noisily iivw_balance, sheet(BalanceOnly)
    assert _rc == 198
    capture noisily iivw_balance, xlsx("`badxls'")
    assert _rc == 198
    capture noisily iivw_balance, xlsx("`goodxlsx'") excel("`otherxlsx'")
    assert _rc == 198
    capture noisily iivw_balance, decimals(2) digits(3) ///
        xlsx("`goodxlsx'") replace
    assert _rc == 198
    capture noisily iivw_balance, csv(bad_export.csv)
    assert _rc == 198
    capture noisily iivw_balance, frame(__iivw_collision)
    assert _rc == 198

    _reporting_diag_known
    capture noisily iivw_diagnose x, unweighted(M_unw) weighted(M_wgt) ///
        adjusted(M_adj) open
    assert _rc == 198
    capture noisily iivw_diagnose x, unweighted(M_unw) weighted(M_wgt) ///
        adjusted(M_adj) excel("`badxls'")
    assert _rc == 198
    capture noisily iivw_diagnose x, unweighted(M_unw) weighted(M_wgt) ///
        adjusted(M_adj) xlsx("`goodxlsx'") excel("`otherxlsx'")
    assert _rc == 198
    capture noisily iivw_diagnose x, unweighted(M_unw) weighted(M_wgt) ///
        adjusted(M_adj) decimals(2) digits(3) xlsx("`goodxlsx'") replace
    assert _rc == 198
    capture noisily iivw_diagnose x, unweighted(M_unw) weighted(M_wgt) ///
        adjusted(M_adj) csv(bad_export.csv)
    assert _rc == 198
    capture noisily iivw_diagnose x, unweighted(M_unw) weighted(M_wgt) ///
        adjusted(M_adj) frame(__diag_bad)
    assert _rc == 198
}
if _rc == 0 {
    display as result "  PASS: T4 - reporting option validation"
    local ++pass_count
}
else {
    display as error "  FAIL: T4 - reporting option validation (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' T4"
}

**# T5: balance and diagnostics can share a workbook on separate sheets

local ++test_count
capture noisily {
    tempfile bookstub
    local workbook "`bookstub'.xlsx"
    capture erase "`workbook'"

    _reporting_balance_panel
    iivw_balance, xlsx("`workbook'") sheet(Balance) replace
    assert "`r(sheet)'" == "Balance"

    _reporting_diag_known
    iivw_diagnose x, unweighted(M_unw) weighted(M_wgt) adjusted(M_adj) ///
        exogeneity(endogenous) xlsx("`workbook'") sheet(Diagnostics) replace
    assert "`r(sheet)'" == "Diagnostics"

    tempfile bookbalmark bookdiagmark
    shell python3 "`qa_dir'/tools/check_iivw_xlsx.py" ///
        "`workbook'" Balance balance 1 "`bookbalmark'"
    confirm file "`bookbalmark'"
    shell python3 "`qa_dir'/tools/check_iivw_xlsx.py" ///
        "`workbook'" Diagnostics diagnostics 10 "`bookdiagmark'"
    confirm file "`bookdiagmark'"

    import excel using "`workbook'", sheet("Balance") cellrange(A4:I4) clear
    assert _N == 1
    assert A[1] == "x"

    import excel using "`workbook'", sheet("Diagnostics") cellrange(A4:G13) clear
    assert _N == 10
    assert B[9] == "bounds_lower"
    assert reldif(G[9], 0.10) < 1e-12
    assert B[10] == "bounds_upper"
    assert reldif(G[10], 0.31) < 1e-12
}
if _rc == 0 {
    display as result "  PASS: T5 - shared workbook multi-sheet export"
    local ++pass_count
}
else {
    display as error "  FAIL: T5 - shared workbook multi-sheet export (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' T5"
}

**# Summary

display as result "Results: `pass_count'/`test_count' passed, `fail_count' failed"
if `fail_count' > 0 {
    display as error "SOME TESTS FAILED: `failed_tests'"
    display "RESULT: test_iivw_reporting_exports tests=`test_count' pass=`pass_count' fail=`fail_count'"
    log close _all
    exit 1
}

display as result "ALL TESTS PASSED"
display "RESULT: test_iivw_reporting_exports tests=`test_count' pass=`pass_count' fail=`fail_count'"
log close _all
