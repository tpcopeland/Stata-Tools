clear all
version 16.0
set varabbrev off

* test_iivw_exogtest.do - focused tests for iivw_exogtest
*
* Usage:
*   cd iivw/qa
*   stata-mp -b do test_iivw_exogtest.do
*   stata-mp -b do test_iivw_exogtest.do 5

args run_only
if "`run_only'" == "" local run_only = 0

**# Setup

local qa_dir "`c(pwd)'"
local base = substr("`qa_dir'", strrpos("`qa_dir'", "/") + 1, .)
if "`base'" != "qa" {
    display as error "test_iivw_exogtest.do must be run from iivw/qa"
    exit 601
}
local pkg_dir = substr("`qa_dir'", 1, strlen("`qa_dir'") - 3)

adopath ++ "`pkg_dir'"
discard
which iivw_exogtest
findfile iivw_exogtest.ado
local exog_path "`r(fn)'"
assert strpos("`exog_path'", "`pkg_dir'") == 1

local test_count = 0
local pass_count = 0
local fail_count = 0
local failed_tests ""

capture program drop _exog_independent_panel
program define _exog_independent_panel
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
    gen double marker = cos(id / 7) + rnormal(0, 0.5)
    label variable y "Outcome score"
    label variable marker "Disease marker"
end

capture program drop _exog_dependent_panel
program define _exog_dependent_panel
    version 16.0
    syntax [, NIDS(integer 120) VISITS(integer 5) SEED(integer 20260525)]

    clear
    set seed `seed'
    set obs `nids'
    gen long id = _n
    gen byte treatment = mod(id, 2)
    gen double age = 35 + mod(id, 25)
    gen byte female = mod(id, 3) == 0
    gen double subject_risk = rnormal(0, 0.7)
    expand `visits'
    bysort id: gen byte visit = _n
    gen double y = 1.5 + subject_risk + 0.25 * visit + rnormal(0, 0.20)
    bysort id (visit): gen double lag_y_internal = y[_n-1]
    gen double gap = 0
    replace gap = exp(1.2 - 0.85 * lag_y_internal + rnormal(0, 0.04)) if visit > 1
    replace gap = max(gap, 0.03) if visit > 1
    bysort id (visit): gen double months = sum(gap)
    label variable y "Outcome score"
    drop lag_y_internal gap
end

capture program drop _exog_skip_panel
program define _exog_skip_panel
    version 16.0

    _exog_dependent_panel, nids(40) visits(4) seed(20260526)
    replace treatment = (id > 32)
    drop if treatment == 1 & visit > 1
end

**# Tests

**## 1. Protocol-like visit timing does not flag endogenous timing
local ++test_count
if `run_only' == 0 | `run_only' == 1 {
    capture noisily {
        _exog_independent_panel
        iivw_exogtest y marker, id(id) time(months) ///
            adjust(age female treatment) level(99) nolog

        assert r(endogenous_flag) == 0
        assert r(n_models) == 1
        assert r(n_skipped) == 0
        assert r(N) == 480
        assert r(alpha) == 0.01
        assert "`r(lagvars)'" == "_iivw_exog_y_lag1 _iivw_exog_marker_lag1"
        matrix R = r(results)
        assert rowsof(R) == 2
        assert colsof(R) == 11
        confirm variable _iivw_exog_y_lag1
        confirm variable _iivw_exog_marker_lag1
    }
    if _rc == 0 {
        display as result "  PASS: 1 - independent timing does not flag"
        local ++pass_count
    }
    else {
        display as error "  FAIL: 1 - independent timing (error `=_rc')"
        local ++fail_count
        local failed_tests "`failed_tests' 1"
    }
}

**## 2. Outcome-dependent visit timing is detected
local ++test_count
if `run_only' == 0 | `run_only' == 2 {
    capture noisily {
        _exog_dependent_panel
        iivw_exogtest y, id(id) time(months) adjust(age female) ///
            level(90) nolog

        assert r(endogenous_flag) == 1
        assert r(min_p) < 0.10
        assert r(joint_min_p) < 0.10
        assert r(n_models) == 1
        assert r(N) == 480
        matrix R = r(results)
        assert rowsof(R) == 1
        assert R[1,6] < 0.10
    }
    if _rc == 0 {
        display as result "  PASS: 2 - outcome-dependent timing detected"
        local ++pass_count
    }
    else {
        display as error "  FAIL: 2 - outcome-dependent timing (error `=_rc')"
        local ++fail_count
        local failed_tests "`failed_tests' 2"
    }
}

**## 3. by() fits separate models
local ++test_count
if `run_only' == 0 | `run_only' == 3 {
    capture noisily {
        _exog_dependent_panel
        iivw_exogtest y, id(id) time(months) by(treatment) ///
            adjust(age female) level(90) nolog

        assert r(n_models) == 2
        assert r(n_skipped) == 0
        assert r(N) == 480
        matrix R = r(results)
        assert rowsof(R) == 2
        assert R[1,1] == 1
        assert R[2,1] == 2
    }
    if _rc == 0 {
        display as result "  PASS: 3 - by() models"
        local ++pass_count
    }
    else {
        display as error "  FAIL: 3 - by() models (error `=_rc')"
        local ++fail_count
        local failed_tests "`failed_tests' 3"
    }
}

**## 4. Duplicate id-time combinations are rejected
local ++test_count
if `run_only' == 0 | `run_only' == 4 {
    capture noisily {
        clear
        input id months y
        1 0 10
        1 0 11
        1 1 12
        2 0 9
        2 1 10
        end
        capture noisily iivw_exogtest y, id(id) time(months) nolog
        assert _rc == 198
    }
    if _rc == 0 {
        display as result "  PASS: 4 - duplicate id-time rejected"
        local ++pass_count
    }
    else {
        display as error "  FAIL: 4 - duplicate id-time (error `=_rc')"
        local ++fail_count
        local failed_tests "`failed_tests' 4"
    }
}

**## 5. Required id() and time() options are enforced
local ++test_count
if `run_only' == 0 | `run_only' == 5 {
    capture noisily {
        _exog_dependent_panel
        capture noisily iivw_exogtest y, time(months) nolog
        assert _rc == 198

        capture noisily iivw_exogtest y, id(id) nolog
        assert _rc == 198
    }
    if _rc == 0 {
        display as result "  PASS: 5 - required options enforced"
        local ++pass_count
    }
    else {
        display as error "  FAIL: 5 - required options (error `=_rc')"
        local ++fail_count
        local failed_tests "`failed_tests' 5"
    }
}

**## 6. First observations with no lag are excluded without crashing
local ++test_count
if `run_only' == 0 | `run_only' == 6 {
    capture noisily {
        _exog_dependent_panel, nids(30) visits(2)
        iivw_exogtest y, id(id) time(months) level(90) nolog

        assert r(n_models) == 1
        assert r(N) == 30
        confirm variable _iivw_exog_y_lag1
        quietly count if missing(_iivw_exog_y_lag1)
        assert r(N) == 30
    }
    if _rc == 0 {
        display as result "  PASS: 6 - first lag missing handled"
        local ++pass_count
    }
    else {
        display as error "  FAIL: 6 - first lag missing (error `=_rc')"
        local ++fail_count
        local failed_tests "`failed_tests' 6"
    }
}

**## 7. Active estimates are preserved
local ++test_count
if `run_only' == 0 | `run_only' == 7 {
    capture noisily {
        _exog_dependent_panel
        regress y age treatment
        matrix B_before = e(b)
        local cmd_before "`e(cmd)'"

        iivw_exogtest y, id(id) time(months) adjust(age treatment) ///
            level(90) nolog

        assert "`e(cmd)'" == "`cmd_before'"
        matrix B_after = e(b)
        assert mreldif(B_before, B_after) < 1e-12
    }
    if _rc == 0 {
        display as result "  PASS: 7 - active estimates preserved"
        local ++pass_count
    }
    else {
        display as error "  FAIL: 7 - active estimates (error `=_rc')"
        local ++fail_count
        local failed_tests "`failed_tests' 7"
    }
}

**## 8. efron option runs through tied-time Cox path
local ++test_count
if `run_only' == 0 | `run_only' == 8 {
    capture noisily {
        _exog_dependent_panel, nids(80) visits(5)
        replace months = round(months, 0.1)
        bysort id (visit): replace months = months[_n-1] + 0.1 if visit > 1 & months <= months[_n-1]

        iivw_exogtest y, id(id) time(months) efron level(90) nolog
        assert r(n_models) == 1
        assert r(N) == 320
    }
    if _rc == 0 {
        display as result "  PASS: 8 - efron option"
        local ++pass_count
    }
    else {
        display as error "  FAIL: 8 - efron option (error `=_rc')"
        local ++fail_count
        local failed_tests "`failed_tests' 8"
    }
}

**## 9. Generated lag collision requires replace
local ++test_count
if `run_only' == 0 | `run_only' == 9 {
    capture noisily {
        _exog_dependent_panel, nids(60) visits(4)
        iivw_exogtest y, id(id) time(months) generate(ex_) level(90) nolog
        confirm variable ex_y_lag1

        capture noisily iivw_exogtest y, id(id) time(months) generate(ex_) ///
            level(90) nolog
        assert _rc == 110
        confirm variable ex_y_lag1

        iivw_exogtest y, id(id) time(months) generate(ex_) replace ///
            level(90) nolog
        assert r(n_models) == 1
        confirm variable ex_y_lag1
    }
    if _rc == 0 {
        display as result "  PASS: 9 - generated lag collision"
        local ++pass_count
    }
    else {
        display as error "  FAIL: 9 - generated lag collision (error `=_rc')"
        local ++fail_count
        local failed_tests "`failed_tests' 9"
    }
}

**## 10. Insufficient by() groups are skipped, not fatal
local ++test_count
if `run_only' == 0 | `run_only' == 10 {
    capture noisily {
        _exog_skip_panel
        iivw_exogtest y, id(id) time(months) by(treatment) ///
            adjust(age female) level(90) nolog

        assert r(n_models) == 1
        assert r(n_skipped) == 1
        assert strpos("`r(skipped_labels)'", "1") > 0
    }
    if _rc == 0 {
        display as result "  PASS: 10 - insufficient groups skipped"
        local ++pass_count
    }
    else {
        display as error "  FAIL: 10 - skipped groups (error `=_rc')"
        local ++fail_count
        local failed_tests "`failed_tests' 10"
    }
}

**## 11. xlsx() export creates a workbook and returns export metadata
local ++test_count
if `run_only' == 0 | `run_only' == 11 {
    capture noisily {
        _exog_independent_panel
        tempfile xlstub
        local xl "`xlstub'.xlsx"
        capture erase "`xl'"

        iivw_exogtest y marker, id(id) time(months) ///
            adjust(age female treatment) level(99) nolog ///
            xlsx("`xl'") sheet("Exog")

        confirm file "`xl'"
        assert "`r(xlsx)'" == "`xl'"
        assert "`r(sheet)'" == "Exog"
        assert r(decimals) == 3
        matrix R = r(results)
        assert rowsof(R) == 2
        assert colsof(R) == 11

        import excel using "`xl'", sheet("Exog") cellrange(A1:E7) allstring clear
        assert A[1] == "Exogeneity diagnostic: lagged predictors of next-visit timing (Andersen-Gill Cox, hazard ratios)"
        assert C[2] == "Overall"
        assert C[3] == "HR"
        assert D[3] == "99% CI"
        assert E[3] == "p-value"
        assert B[4] == "Outcome score (lag 1)"
        assert B[5] == "Disease marker (lag 1)"
        assert B[6] == "Joint test (all lagged predictors)"
        assert B[7] != ""
    }
    if _rc == 0 {
        display as result "  PASS: 11 - xlsx() export workbook"
        local ++pass_count
    }
    else {
        display as error "  FAIL: 11 - xlsx() export workbook (error `=_rc')"
        local ++fail_count
        local failed_tests "`failed_tests' 11"
    }
}

**## 12. xlsx() export with by() includes per-group joint rows
local ++test_count
if `run_only' == 0 | `run_only' == 12 {
    capture noisily {
        _exog_dependent_panel
        tempfile xlstub
        local xl "`xlstub'.xlsx"
        capture erase "`xl'"

        iivw_exogtest y, id(id) time(months) by(treatment) ///
            adjust(age female) level(90) nolog ///
            xlsx("`xl'") sheet("ByExog") decimals(2)

        confirm file "`xl'"
        assert "`r(xlsx)'" == "`xl'"
        assert "`r(sheet)'" == "ByExog"
        assert r(decimals) == 2

        import excel using "`xl'", sheet("ByExog") cellrange(A1:H6) allstring clear
        assert C[2] == "0"
        assert F[2] == "1"
        assert C[3] == "HR"
        assert D[3] == "90% CI"
        assert E[3] == "p-value"
        assert F[3] == "HR"
        assert G[3] == "90% CI"
        assert H[3] == "p-value"
        assert B[4] == "Outcome score (lag 1)"
        assert B[5] == "Joint test (all lagged predictors)"
        assert B[6] != ""
    }
    if _rc == 0 {
        display as result "  PASS: 12 - by() xlsx() export rows"
        local ++pass_count
    }
    else {
        display as error "  FAIL: 12 - by() xlsx() export rows (error `=_rc')"
        local ++fail_count
        local failed_tests "`failed_tests' 12"
    }
}

**## 13. sheet() without a workbook is a hard option error
local ++test_count
if `run_only' == 0 | `run_only' == 13 {
    capture noisily {
        _exog_dependent_panel
        * Requesting a sheet (or open) without xlsx() is a user-input
        * error and hard-fails 198, matching iivw_balance/iivw_diagnose.  Only a
        * pre-existing worksheet without replace (rc 602) is softened.
        capture noisily iivw_exogtest y, id(id) time(months) ///
            adjust(age female) level(90) nolog sheet("OnlySheet")
        assert _rc == 198
    }
    if _rc == 0 {
        display as result "  PASS: 13 - sheet() without xlsx() rejected"
        local ++pass_count
    }
    else {
        display as error "  FAIL: 13 - sheet() without xlsx() (error `=_rc')"
        local ++fail_count
        local failed_tests "`failed_tests' 13"
    }
}

**## 14. decimals() bounds are enforced before export
local ++test_count
if `run_only' == 0 | `run_only' == 14 {
    capture noisily {
        _exog_independent_panel
        tempfile xlstub
        local xl "`xlstub'.xlsx"
        capture noisily iivw_exogtest y, id(id) time(months) ///
            adjust(age female) nolog xlsx("`xl'") decimals(9)
        assert _rc == 198
        capture confirm file "`xl'"
        assert _rc != 0
    }
    if _rc == 0 {
        display as result "  PASS: 14 - decimals() bounds"
        local ++pass_count
    }
    else {
        display as error "  FAIL: 14 - decimals() bounds (error `=_rc')"
        local ++fail_count
        local failed_tests "`failed_tests' 14"
    }
}

**## 15. decimals() abbreviation and default; removed digits()/excel() synonyms
local ++test_count
if `run_only' == 0 | `run_only' == 15 {
    capture noisily {
        _exog_independent_panel
        tempfile xlstub
        local xl "`xlstub'.xlsx"
        * dec() abbreviation accepted and honored
        capture confirm file "`xl'"
        if _rc == 0 erase "`xl'"
        iivw_exogtest y, id(id) time(months) adjust(age female) nolog ///
            xlsx("`xl'") dec(2) replace
        assert r(decimals) == 2
        * default remains 3
        erase "`xl'"
        iivw_exogtest y, id(id) time(months) adjust(age female) nolog ///
            xlsx("`xl'") replace
        assert r(decimals) == 3
        * v1.6.0: digits() and excel() synonyms removed; now invalid options
        capture noisily iivw_exogtest y, id(id) time(months) adjust(age female) ///
            nolog xlsx("`xl'") digits(4) replace
        assert _rc == 198
        capture noisily iivw_exogtest y, id(id) time(months) adjust(age female) ///
            nolog excel("`xl'") replace
        assert _rc == 198
        capture erase "`xl'"
    }
    if _rc == 0 {
        display as result "  PASS: 15 - decimals abbreviation; removed synonyms"
        local ++pass_count
    }
    else {
        display as error "  FAIL: 15 - decimals abbreviation; removed synonyms (error `=_rc')"
        local ++fail_count
        local failed_tests "`failed_tests' 15"
    }
}

**## 16. replace overwrites an existing worksheet (v1.5.3)
local ++test_count
if `run_only' == 0 | `run_only' == 16 {
    capture noisily {
        _exog_independent_panel
        tempfile xlstub
        local xl "`xlstub'.xlsx"
        capture erase "`xl'"

        * First write establishes the workbook and the Exog sheet
        iivw_exogtest y marker, id(id) time(months) adjust(age female) ///
            nolog xlsx("`xl'") sheet("Exog") title("First title")
        assert "`r(sheet)'" == "Exog"
        import excel using "`xl'", sheet("Exog") cellrange(A1:A1) allstring clear
        assert A[1] == "First title"

        * Re-export to the SAME existing sheet WITH replace now overwrites it
        * (regression: previously replace was not forwarded to the writer, so
        * the sheet could never be replaced)
        _exog_independent_panel
        iivw_exogtest y marker, id(id) time(months) adjust(age female) ///
            nolog xlsx("`xl'") sheet("Exog") title("Second title") replace
        assert "`r(xlsx)'" == "`xl'"
        assert "`r(sheet)'" == "Exog"
        import excel using "`xl'", sheet("Exog") cellrange(A1:A1) allstring clear
        assert A[1] == "Second title"

        * Without replace, the existing sheet is left untouched (warn-and-return)
        _exog_independent_panel
        capture noisily iivw_exogtest y marker, id(id) time(months) ///
            adjust(age female) nolog xlsx("`xl'") sheet("Exog") ///
            title("Third title")
        assert _rc == 0
        assert "`r(xlsx)'" == ""
        matrix R = r(results)
        assert rowsof(R) == 2
        import excel using "`xl'", sheet("Exog") cellrange(A1:A1) allstring clear
        assert A[1] == "Second title"
    }
    if _rc == 0 {
        display as result "  PASS: 16 - replace overwrites existing sheet"
        local ++pass_count
    }
    else {
        display as error "  FAIL: 16 - replace overwrites existing sheet (error `=_rc')"
        local ++fail_count
        local failed_tests "`failed_tests' 16"
    }
}

**# Summary

capture adopath - "`pkg_dir'"
display as result "Test Results: `pass_count'/`test_count' passed, `fail_count' failed"

if `fail_count' > 0 {
    display as error "FAILED TESTS: `failed_tests'"
    display "RESULT: test_iivw_exogtest tests=`test_count' pass=`pass_count' fail=`fail_count'"
    exit 1
}
else {
    display as result "ALL TESTS PASSED"
}

display "RESULT: test_iivw_exogtest tests=`test_count' pass=`pass_count' fail=`fail_count'"
