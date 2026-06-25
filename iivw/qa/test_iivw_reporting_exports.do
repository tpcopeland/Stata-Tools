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

capture program drop _reporting_exog_panel
program define _reporting_exog_panel
    version 16.0
    syntax [, NIDS(integer 120) VISITS(integer 5) SEED(integer 20260524)]

    clear
    set seed `seed'
    set obs `=`nids' * `visits''
    gen long id = ceil(_n / `visits')
    bysort id: gen byte visit = _n
    gen byte treatment = mod(id, 2)
    gen double age = 35 + mod(id, 25)
    gen byte female = mod(id, 3) == 0
    gen double months = (visit - 1) * 3 + runiform() * 0.20
    replace months = 0 if visit == 1
    gen double y = 10 + sin(id / 5) + 0.1 * visit + rnormal(0, 0.7)
    label variable y "Outcome score"
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

    iivw_balance z x, xlsx("`balxlsx'") sheet(Balance) replace ///
        footnote("Custom balance footnote")
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

    import excel using "`balxlsx'", sheet("Balance") clear allstring
    assert _N == 6
    assert A[1] == "IIVW balance diagnostic"
    assert C[2] == "Means"
    assert F[2] == "Balance"
    assert I[2] == "Counts"
    assert B[3] == "Covariate"
    assert C[3] == "Unweighted mean"
    assert G[3] == "|SMD|"
    assert H[3] == "Modeled"
    assert B[4] == "x"
    assert B[5] == "z"
    assert B[6] == "Custom balance footnote"
    assert abs(real(C[4]) - B0[1,1]) < 0.0001
    assert abs(real(G[4]) - B0[1,5]) < 0.0001
    assert H[4] == "Yes"
    assert H[5] == "No"
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
        xlsx("`diagxlsx'") replace
    matrix E = r(estimates)
    matrix D = r(decomp)
    matrix Bm = r(bias)
    local sampling_gap = D[1,1]
    local bias_adjusted = Bm[4,1]
    assert "`r(xlsx)'" == "`diagxlsx'"
    assert "`r(sheet)'" == "Diagnostics"
    assert "`r(csv)'" == ""
    assert "`r(frame)'" == ""
    assert "`e(cmd)'" == "`active_cmd'"
    assert reldif(_b[q], `active_b') < 1e-12

    tempfile diagmark
    shell python3 "`qa_dir'/tools/check_iivw_xlsx.py" ///
        "`diagxlsx'" Diagnostics diagnostics 15 "`diagmark'"
    confirm file "`diagmark'"

    import excel using "`diagxlsx'", sheet("Diagnostics") clear allstring
    * 5-column layout (A-E): value sits in column C beneath a "Diagnostic
    * values" divider row (Excel row 7), pushing the value rows down one.
    assert _N == 19
    assert A[1] == "IIVW diagnostic decomposition"
    assert C[2] == "Model estimates"
    assert B[3] == "Quantity"
    assert C[3] == "Estimate"
    assert E[3] == "95% CI"
    assert B[4] == "Unweighted"
    assert abs(real(C[4]) - E[1,1]) < 0.0001
    assert C[7] == "Diagnostic values"
    assert B[7] == ""
    assert B[8] == "Sampling gap"
    assert abs(real(C[8]) - `sampling_gap') < 0.0001
    assert B[18] == "Adjusted bias"
    assert abs(real(C[18]) - `bias_adjusted') < 0.0001
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
    capture noisily iivw_balance, decimals(-1)
    assert _rc == 198
    capture noisily iivw_balance, csv(bad_export.csv)
    assert _rc == 198
    capture noisily iivw_balance, frame(__iivw_collision)
    assert _rc == 198
    * v1.6.0: excel() and digits() synonyms removed; now invalid options
    capture noisily iivw_balance, excel("`otherxlsx'")
    assert _rc == 198
    capture noisily iivw_balance, xlsx("`goodxlsx'") digits(3) replace
    assert _rc == 198

    _reporting_exog_panel
    capture noisily iivw_exogtest y, id(id) time(months) open nolog
    assert _rc == 198
    _reporting_exog_panel
    capture noisily iivw_exogtest y, id(id) time(months) ///
        sheet(ExogOnly) nolog
    assert _rc == 198
    _reporting_exog_panel
    capture noisily iivw_exogtest y, id(id) time(months) ///
        xlsx("`badxls'") nolog
    assert _rc == 198
    _reporting_exog_panel
    capture noisily iivw_exogtest y, id(id) time(months) ///
        xlsx("`goodxlsx'") decimals(-1) nolog
    assert _rc == 198

    _reporting_diag_known
    capture noisily iivw_diagnose x, unweighted(M_unw) weighted(M_wgt) ///
        adjusted(M_adj) open
    assert _rc == 198
    capture noisily iivw_diagnose x, unweighted(M_unw) weighted(M_wgt) ///
        adjusted(M_adj) xlsx("`badxls'")
    assert _rc == 198
    capture noisily iivw_diagnose x, unweighted(M_unw) weighted(M_wgt) ///
        adjusted(M_adj) decimals(-1)
    assert _rc == 198
    capture noisily iivw_diagnose x, unweighted(M_unw) weighted(M_wgt) ///
        adjusted(M_adj) csv(bad_export.csv)
    assert _rc == 198
    capture noisily iivw_diagnose x, unweighted(M_unw) weighted(M_wgt) ///
        adjusted(M_adj) frame(__diag_bad)
    assert _rc == 198
    * v1.6.0: excel() and digits() synonyms removed; now invalid options
    capture noisily iivw_diagnose x, unweighted(M_unw) weighted(M_wgt) ///
        adjusted(M_adj) excel("`otherxlsx'")
    assert _rc == 198
    capture noisily iivw_diagnose x, unweighted(M_unw) weighted(M_wgt) ///
        adjusted(M_adj) xlsx("`goodxlsx'") digits(3) replace
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

    _reporting_exog_panel
    iivw_exogtest y, id(id) time(months) adjust(age female treatment) ///
        xlsx("`workbook'") sheet(Exogeneity) replace nolog
    assert "`r(sheet)'" == "Exogeneity"

    _reporting_diag_known
    iivw_diagnose x, unweighted(M_unw) weighted(M_wgt) adjusted(M_adj) ///
        exogeneity(endogenous) xlsx("`workbook'") sheet(Diagnostics) replace
    assert "`r(sheet)'" == "Diagnostics"

    tempfile bookbalmark bookexogmark bookdiagmark
    shell python3 "`qa_dir'/tools/check_iivw_xlsx.py" ///
        "`workbook'" Balance balance 1 "`bookbalmark'"
    confirm file "`bookbalmark'"
    shell python3 "`qa_dir'/tools/check_iivw_xlsx.py" ///
        "`workbook'" Exogeneity exogeneity 2 "`bookexogmark'"
    confirm file "`bookexogmark'"
    shell python3 "`qa_dir'/tools/check_iivw_xlsx.py" ///
        "`workbook'" Diagnostics diagnostics 11 "`bookdiagmark'"
    confirm file "`bookdiagmark'"

    import excel using "`workbook'", sheet("Balance") clear allstring
    assert _N == 5
    assert B[4] == "x"

    import excel using "`workbook'", sheet("Exogeneity") clear allstring
    assert A[1] == "Exogeneity diagnostic: lagged predictors of next-visit timing (Andersen-Gill Cox, hazard ratios)"
    assert C[2] == "Overall"
    assert C[3] == "HR"
    assert B[4] == "Outcome score (lag 1)"
    assert B[5] == "Joint test (all lagged predictors)"

    import excel using "`workbook'", sheet("Diagnostics") clear allstring
    * No true(): divider row at 7 shifts the bound rows down one; value in C.
    assert _N == 15
    assert B[13] == "Lower bound"
    assert abs(real(C[13]) - 0.10) < 0.0001
    assert B[14] == "Upper bound"
    assert abs(real(C[14]) - 0.31) < 0.0001
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

**# T6: iivw_diagnose export header honors level()

local ++test_count
capture noisily {
    tempfile lvlstub
    local lvlxlsx "`lvlstub'.xlsx"
    capture erase "`lvlxlsx'"

    _reporting_diag_known
    iivw_diagnose x, unweighted(M_unw) weighted(M_wgt) adjusted(M_adj) ///
        level(90) xlsx("`lvlxlsx'") replace
    assert "`r(sheet)'" == "Diagnostics"

    import excel using "`lvlxlsx'", sheet("Diagnostics") clear allstring
    assert E[3] == "90% CI"
}
if _rc == 0 {
    display as result "  PASS: T6 - iivw_diagnose export honors level()"
    local ++pass_count
}
else {
    display as error "  FAIL: T6 - diagnose export level() header (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' T6"
}

**# T7: existing sheets are protected without replace (warn-and-return)

local ++test_count
capture noisily {
    tempfile protectstub
    local protectxlsx "`protectstub'.xlsx"
    capture erase "`protectxlsx'"

    _reporting_balance_panel
    iivw_balance, xlsx("`protectxlsx'") sheet(Balance) replace ///
        title("Original balance")

    * New contract (v1.5.3): exporting to an existing worksheet without replace
    * does not error.  The export is skipped with a warning, the sheet is left
    * untouched, no export metadata is returned, and the diagnostic results
    * still survive in r().
    _reporting_balance_panel
    capture noisily iivw_balance, xlsx("`protectxlsx'") sheet(Balance) ///
        title("Overwrite attempt")
    assert _rc == 0
    assert "`r(xlsx)'" == ""
    assert "`r(sheet)'" == ""
    assert "`r(leverage)'" != ""
    matrix _b_survive = r(balance)
    assert rowsof(_b_survive) >= 1

    import excel using "`protectxlsx'", sheet("Balance") clear allstring
    assert A[1] == "Original balance"

    _reporting_diag_known
    iivw_diagnose x, unweighted(M_unw) weighted(M_wgt) adjusted(M_adj) ///
        xlsx("`protectxlsx'") sheet(Diagnostics) replace

    * iivw_diagnose follows the same warn-and-return contract
    _reporting_diag_known
    capture noisily iivw_diagnose x, unweighted(M_unw) weighted(M_wgt) ///
        adjusted(M_adj) xlsx("`protectxlsx'") sheet(Diagnostics) ///
        title("Diag overwrite attempt")
    assert _rc == 0
    assert "`r(xlsx)'" == ""
    matrix Dsoft = r(decomp)
    assert Dsoft[1,1] < .

    _reporting_balance_panel
    iivw_balance, xlsx("`protectxlsx'") sheet(Balance) replace ///
        title("Replacement balance")

    import excel using "`protectxlsx'", sheet("Balance") clear allstring
    assert A[1] == "Replacement balance"

    import excel using "`protectxlsx'", sheet("Diagnostics") clear allstring
    assert A[1] == "IIVW diagnostic decomposition"
    assert B[13] == "Lower bound"
}
if _rc == 0 {
    display as result "  PASS: T7 - existing sheets protected without replace"
    local ++pass_count
}
else {
    display as error "  FAIL: T7 - existing sheet protection (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' T7"
}

**# T8: default export renders the thin house grid (frame + group separators) with no header shade

local ++test_count
capture noisily {
    _reporting_diag_known
    tempfile gridstub
    local gridxlsx "`gridstub'.xlsx"
    capture erase "`gridxlsx'"
    iivw_diagnose x, unweighted(M_unw) weighted(M_wgt) adjusted(M_adj) ///
        xlsx("`gridxlsx'") sheet(Grid) replace
    tempfile gridmark
    shell python3 "`qa_dir'/tools/check_iivw_style.py" ///
        "`gridxlsx'" Grid thin 0 0 "`gridmark'"
    confirm file "`gridmark'"
}
if _rc == 0 {
    display as result "  PASS: T8 - default thin house grid, no shade"
    local ++pass_count
}
else {
    display as error "  FAIL: T8 - default thin full grid (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' T8"
}

**# T9: borderstyle(academic) renders three rules, no vertical grid

local ++test_count
capture noisily {
    _reporting_diag_known
    tempfile acstub
    local acxlsx "`acstub'.xlsx"
    capture erase "`acxlsx'"
    iivw_diagnose x, unweighted(M_unw) weighted(M_wgt) adjusted(M_adj) ///
        xlsx("`acxlsx'") sheet(Academic) replace borderstyle(academic)
    tempfile acmark
    shell python3 "`qa_dir'/tools/check_iivw_style.py" ///
        "`acxlsx'" Academic academic 0 0 "`acmark'"
    confirm file "`acmark'"
}
if _rc == 0 {
    display as result "  PASS: T9 - borderstyle(academic) three-rule layout"
    local ++pass_count
}
else {
    display as error "  FAIL: T9 - borderstyle(academic) (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' T9"
}

**# T10: headershade + zebra + custom colors render fills atop the grid

local ++test_count
capture noisily {
    _reporting_diag_known
    tempfile shstub
    local shxlsx "`shstub'.xlsx"
    capture erase "`shxlsx'"
    iivw_diagnose x, unweighted(M_unw) weighted(M_wgt) adjusted(M_adj) ///
        xlsx("`shxlsx'") sheet(Shaded) replace ///
        headershade zebra headercolor("200 200 200") zebracolor("240 240 240")
    tempfile shmark
    shell python3 "`qa_dir'/tools/check_iivw_style.py" ///
        "`shxlsx'" Shaded thin 1 1 "`shmark'"
    confirm file "`shmark'"
}
if _rc == 0 {
    display as result "  PASS: T10 - headershade + zebra + custom colors"
    local ++pass_count
}
else {
    display as error "  FAIL: T10 - headershade/zebra (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' T10"
}

**# T11: theme() preset applies its border scheme (apa -> academic)

local ++test_count
capture noisily {
    _reporting_diag_known
    tempfile thstub
    local thxlsx "`thstub'.xlsx"
    capture erase "`thxlsx'"
    iivw_diagnose x, unweighted(M_unw) weighted(M_wgt) adjusted(M_adj) ///
        xlsx("`thxlsx'") sheet(Apa) replace theme(apa)
    tempfile thmark
    shell python3 "`qa_dir'/tools/check_iivw_style.py" ///
        "`thxlsx'" Apa academic 0 0 "`thmark'"
    confirm file "`thmark'"
}
if _rc == 0 {
    display as result "  PASS: T11 - theme(apa) academic preset"
    local ++pass_count
}
else {
    display as error "  FAIL: T11 - theme(apa) (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' T11"
}

**# T12: invalid style options are rejected (rc 198) across all three commands

local ++test_count
capture noisily {
    tempfile vstub
    local vxlsx "`vstub'.xlsx"
    capture erase "`vxlsx'"

    _reporting_balance_panel
    capture noisily iivw_balance, xlsx("`vxlsx'") replace borderstyle(fancy)
    assert _rc == 198
    capture noisily iivw_balance, xlsx("`vxlsx'") replace theme(bogus)
    assert _rc == 198
    capture noisily iivw_balance, xlsx("`vxlsx'") replace headercolor("300 0 0")
    assert _rc == 198
    capture noisily iivw_balance, xlsx("`vxlsx'") replace zebracolor("1 2")
    assert _rc == 198
    * non-numeric RGB tokens must give the clean rc 198, not "var not found" rc 199
    capture noisily iivw_balance, xlsx("`vxlsx'") replace headercolor("blue grn red")
    assert _rc == 198
    capture noisily iivw_balance, xlsx("`vxlsx'") replace zebracolor("a b c")
    assert _rc == 198

    _reporting_diag_known
    capture noisily iivw_diagnose x, unweighted(M_unw) weighted(M_wgt) ///
        adjusted(M_adj) xlsx("`vxlsx'") replace borderstyle(fancy)
    assert _rc == 198
    capture noisily iivw_diagnose x, unweighted(M_unw) weighted(M_wgt) ///
        adjusted(M_adj) xlsx("`vxlsx'") replace headercolor("0 0 999")
    assert _rc == 198
    capture noisily iivw_diagnose x, unweighted(M_unw) weighted(M_wgt) ///
        adjusted(M_adj) xlsx("`vxlsx'") replace zebracolor("x y z")
    assert _rc == 198

    _reporting_exog_panel
    capture noisily iivw_exogtest y, id(id) time(months) nolog ///
        xlsx("`vxlsx'") replace borderstyle(fancy)
    assert _rc == 198
    _reporting_exog_panel
    capture noisily iivw_exogtest y, id(id) time(months) nolog ///
        xlsx("`vxlsx'") replace headercolor("0 0 999")
    assert _rc == 198
    _reporting_exog_panel
    capture noisily iivw_exogtest y, id(id) time(months) nolog ///
        xlsx("`vxlsx'") replace zebracolor("x y z")
    assert _rc == 198
}
if _rc == 0 {
    display as result "  PASS: T12 - invalid style options rejected"
    local ++pass_count
}
else {
    display as error "  FAIL: T12 - invalid style options (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' T12"
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
