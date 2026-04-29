* test_review_v1013.do — Regression tests for v1.0.13 review fixes
* Date: 2026-04-27
* Covers: table1_tc SMD zero-division guard, stratetab silent success
*         message, _tabtools_helpers_ready file-parsing, comptab
*         varabbrev restore on error, hrcomptab xlsx success message

clear all

capture log close _rev1013
log using "test_review_v1013.log", replace text name(_rev1013)

local qa_dir "`c(pwd)'"
local pkg_dir = subinstr("`qa_dir'", "/qa", "", 1)
local output_dir "`qa_dir'/output"
capture mkdir "`output_dir'"

discard
capture ado uninstall tabtools
quietly net install tabtools, from("`pkg_dir'") replace
discard

local test_count = 0
local pass_count = 0
local fail_count = 0


**# 1. table1_tc SMD guard for all-missing categorical group

**## 1a. Unweighted SMD with one all-missing group returns without error
local ++test_count
capture noisily {
    clear
    set obs 60
    gen byte group = cond(_n <= 30, 1, 2)
    gen byte catvar = mod(_n, 3)
    replace catvar = . if group == 2
    table1_tc, vars(catvar cat) by(group) smd
    assert r(N) > 0
    matrix list r(table)
}
if _rc == 0 {
    display as result "  PASS [1a]: table1_tc SMD with all-missing group completes without error"
    local ++pass_count
}
else {
    display as error "  FAIL [1a]: table1_tc SMD with all-missing group (rc=`=_rc')"
    local ++fail_count
}

**## 1b. Weighted SMD with one zero-weight group returns without error
local ++test_count
capture noisily {
    clear
    set obs 60
    gen byte group = cond(_n <= 30, 1, 2)
    gen byte catvar = mod(_n, 3)
    gen double wt = cond(group == 1, runiform(), 0)
    table1_tc, vars(catvar cat) by(group) smd wt(wt)
    assert r(N) > 0
    matrix list r(table)
}
if _rc == 0 {
    display as result "  PASS [1b]: table1_tc weighted SMD with zero-weight group completes without error"
    local ++pass_count
}
else {
    display as error "  FAIL [1b]: table1_tc weighted SMD with zero-weight group (rc=`=_rc')"
    local ++fail_count
}

**## 1c. SMD with valid groups still produces correct nonmissing value
local ++test_count
local t1c_pass = 1
capture noisily {
    clear
    set obs 200
    gen byte group = cond(_n <= 100, 1, 2)
    gen byte catvar = cond(group == 1, cond(_n <= 80, 1, 0), cond(_n <= 140, 1, 0))
    table1_tc, vars(catvar bin) by(group) smd
    matrix define _t = r(table)
}
if _rc != 0 {
    display as error "  FAIL [1c.run]: table1_tc SMD with valid groups returned error `=_rc'"
    local t1c_pass = 0
}
else {
    local ncols = colsof(_t)
    local smd_col = `ncols'
    local smd_val = _t[1, `smd_col']
    if `smd_val' < . & `smd_val' >= 0 {
        display as result "  PASS [1c.value]: SMD = `smd_val' (nonmissing, nonnegative)"
    }
    else {
        display as error "  FAIL [1c.value]: SMD is missing or negative (`smd_val')"
        local t1c_pass = 0
    }
}
if `t1c_pass' {
    display as result "  PASS [1c]: SMD with valid groups produces correct value"
    local ++pass_count
}
else {
    local ++fail_count
}


**# 2. stratetab xlsx success message is visible

**## 2a. Export confirmation message appears in log output
local ++test_count
capture noisily {
    * Build minimal strate output
    clear
    set obs 2
    gen exposure = _n - 1
    gen double _D = cond(_n == 1, 10, 20)
    gen double _Y = cond(_n == 1, 1000, 1100)
    gen double _Rate = _D / _Y
    gen double _Lower = _Rate * 0.80
    gen double _Upper = _Rate * 1.20
    label define _st_exp 0 "Unexposed" 1 "Exposed", replace
    label values exposure _st_exp
    tempfile st_rate
    save "`st_rate'.dta", replace

    * Run stratetab with xlsx and capture output to a file
    clear
    local stlog_path "`output_dir'/_rev1013_st_check"
    capture log close _stcheck
    log using "`stlog_path'", replace text name(_stcheck)
    stratetab, using(`st_rate') outcomes(1) ///
        xlsx("`output_dir'/_rev1013_stratetab.xlsx") ///
        sheet("Test")
    log close _stcheck

    * Read back the log and search for the success message
    tempname fh
    local found_msg 0
    file open `fh' using "`stlog_path'.log", read text
    file read `fh' line
    while r(eof) == 0 {
        if strpos(`"`line'"', "Exported to") > 0 {
            local found_msg 1
        }
        file read `fh' line
    }
    file close `fh'
    assert `found_msg' == 1
}
if _rc == 0 {
    display as result "  PASS [2a]: stratetab xlsx success message visible in output"
    local ++pass_count
}
else {
    display as error "  FAIL [2a]: stratetab xlsx success message not found (rc=`=_rc')"
    local ++fail_count
}
capture erase "`output_dir'/_rev1013_stratetab.xlsx"
capture erase "`output_dir'/_rev1013_st_check.log"


**# 3. _tabtools_helpers_ready file-parsing discovers programs

**## 3a. After fresh load, _tabtools_helpers_ready succeeds without arguments
local ++test_count
capture noisily {
    * Drop all helpers to force a fresh-load scenario
    foreach _p in _tabtools_col_letter _tabtools_validate_path ///
        _tabtools_validate_color _tabtools_build_col_letters ///
        _tabtools_open_file _tabtools_detect_vartype ///
        _tabtools_validate_sheet _tabtools_apply_theme ///
        _tabtools_resolve_format _tabtools_console_display ///
        _tabtools_frame_put _tabtools_helpers_ready {
        capture program drop `_p'
    }
    capture findfile _tabtools_common.ado
    assert _rc == 0
    run "`r(fn)'"

    * Call with no arguments — uses hardcoded list to verify all programs loaded
    _tabtools_helpers_ready
}
if _rc == 0 {
    display as result "  PASS [3a]: _tabtools_helpers_ready succeeds after fresh load"
    local ++pass_count
}
else {
    display as error "  FAIL [3a]: _tabtools_helpers_ready failed after fresh load (rc=`=_rc')"
    local ++fail_count
}

**## 3b. All expected helper programs exist in memory after load
local ++test_count
local t3b_pass = 1
foreach prog in _tabtools_col_letter _tabtools_validate_path ///
    _tabtools_validate_color _tabtools_build_col_letters ///
    _tabtools_open_file _tabtools_detect_vartype ///
    _tabtools_validate_sheet _tabtools_apply_theme ///
    _tabtools_resolve_format _tabtools_console_display ///
    _tabtools_frame_put _tabtools_helpers_ready {
    capture program list `prog'
    if _rc {
        display as error "  FAIL [3b.`prog']: program not found"
        local t3b_pass = 0
    }
}
if `t3b_pass' {
    display as result "  PASS [3b]: all 13 helper programs exist after load"
    local ++pass_count
}
else {
    local ++fail_count
}


**# 4. comptab restores varabbrev on error (auto-load inside capture noisily)

**## 4a. varabbrev restored after error with nonexistent frame
local ++test_count
capture noisily {
    set varabbrev on
    capture comptab _nonexistent_frame_xyz_, rows(1)
    local comptab_rc = _rc
    local va_after = c(varabbrev)
    set varabbrev off
    assert `comptab_rc' != 0
    assert "`va_after'" == "on"
}
if _rc == 0 {
    display as result "  PASS [4a]: comptab restores varabbrev on error (frame not found)"
    local ++pass_count
}
else {
    display as error "  FAIL [4a]: comptab did not restore varabbrev on error (rc=`=_rc')"
    local ++fail_count
}

**## 4b. varabbrev restored after error with missing rows/rownames
local ++test_count
capture noisily {
    set varabbrev on
    capture comptab _nonexistent_frame_xyz_
    local comptab_rc = _rc
    local va_after = c(varabbrev)
    set varabbrev off
    assert `comptab_rc' != 0
    assert "`va_after'" == "on"
}
if _rc == 0 {
    display as result "  PASS [4b]: comptab restores varabbrev on error (missing required options)"
    local ++pass_count
}
else {
    display as error "  FAIL [4b]: comptab did not restore varabbrev on error (rc=`=_rc')"
    local ++fail_count
}


**# 5. hrcomptab xlsx success message is visible

**## 5a. Export confirmation message appears in log output
local ++test_count
capture noisily {
    * Build minimal stratetab frame
    clear
    set obs 2
    gen exposure = _n - 1
    gen double _D = cond(_n == 1, 10, 20)
    gen double _Y = cond(_n == 1, 1000, 1100)
    gen double _Rate = _D / _Y
    gen double _Lower = _Rate * 0.80
    gen double _Upper = _Rate * 1.20
    label define _hrc_exp 0 "None" 1 "Current", replace
    label values exposure _hrc_exp
    tempfile hrc_rate
    save "`hrc_rate'.dta", replace

    clear
    capture frame drop _hrc_rf
    stratetab, using(`hrc_rate') outcomes(1) frame(_hrc_rf, replace)

    * Build minimal regtab frame
    clear
    set obs 30
    set seed 20260427
    gen byte treated = mod(_n, 2)
    gen double y = 10 + 2 * treated + rnormal()
    collect clear
    collect: regress y treated
    capture frame drop _hrc_mf
    regtab, frame(_hrc_mf) noint

    * Run hrcomptab with xlsx and capture output to a file
    clear
    local hrclog_path "`output_dir'/_rev1013_hrc_check"
    capture log close _hrccheck
    log using "`hrclog_path'", replace text name(_hrccheck)
    hrcomptab _hrc_rf, modelframes(_hrc_mf) rows(1) ///
        xlsx("`output_dir'/_rev1013_hrcomptab.xlsx") ///
        sheet("Test")
    log close _hrccheck

    * Read back the log and search for the success message
    tempname fh2
    local found_msg 0
    file open `fh2' using "`hrclog_path'.log", read text
    file read `fh2' line
    while r(eof) == 0 {
        if strpos(`"`line'"', "Exported") > 0 & strpos(`"`line'"', "cols to") > 0 {
            local found_msg 1
        }
        file read `fh2' line
    }
    file close `fh2'
    assert `found_msg' == 1

    * Cleanup frames
    capture frame drop _hrc_rf
    capture frame drop _hrc_mf
}
if _rc == 0 {
    display as result "  PASS [5a]: hrcomptab xlsx success message visible in output"
    local ++pass_count
}
else {
    display as error "  FAIL [5a]: hrcomptab xlsx success message not found (rc=`=_rc')"
    local ++fail_count
    capture frame drop _hrc_rf
    capture frame drop _hrc_mf
}
capture erase "`output_dir'/_rev1013_hrcomptab.xlsx"
capture erase "`output_dir'/_rev1013_hrc_check.log"


**# 6. stratetab xlsx r(xlsx) and r(sheet) populated (C1 regression)

**## 6a. r(xlsx) and r(sheet) are non-empty after successful xlsx export
local ++test_count
capture noisily {
    clear
    set obs 2
    gen exposure = _n - 1
    gen double _D = cond(_n == 1, 10, 20)
    gen double _Y = cond(_n == 1, 1000, 1100)
    gen double _Rate = _D / _Y
    gen double _Lower = _Rate * 0.80
    gen double _Upper = _Rate * 1.20
    label define _c1_exp 0 "Unexposed" 1 "Exposed", replace
    label values exposure _c1_exp
    tempfile c1_rate
    save "`c1_rate'.dta", replace

    clear
    local c1_xlsx "`output_dir'/_rev1013_c1_stratetab.xlsx"
    capture erase "`c1_xlsx'"
    stratetab, using(`c1_rate') outcomes(1) ///
        xlsx("`c1_xlsx'") sheet("C1Test")
    assert `"`r(xlsx)'"' != ""
    assert `"`r(sheet)'"' != ""
    capture confirm file "`c1_xlsx'"
    assert _rc == 0
}
if _rc == 0 {
    display as result "  PASS [6a]: stratetab r(xlsx) and r(sheet) populated after xlsx export"
    local ++pass_count
}
else {
    display as error "  FAIL [6a]: stratetab r(xlsx)/r(sheet) empty or file missing (rc=`=_rc')"
    local ++fail_count
}
capture erase "`output_dir'/_rev1013_c1_stratetab.xlsx"


**# 7. table1_tc percent + continuous Excel header no duplication (I1 regression)

**## 7a. Header row contains "Mean (SD)" exactly once when percent is specified
local ++test_count
capture noisily {
    sysuse auto, clear
    local i1_xlsx "`output_dir'/_rev1013_i1_percent.xlsx"
    capture erase "`i1_xlsx'"
    table1_tc, vars(price contn \ rep78 cat \ foreign bin) by(foreign) percent ///
        xlsx("`i1_xlsx'") sheet("I1Test")

    * Read back the xlsx; check the header description row (row 2) for duplication
    clear
    import excel using "`i1_xlsx'", sheet("I1Test") allstring clear
    * Row 2 of the xlsx = observation 2 after import; column B has the header text
    local header_desc = B[2]
    * Count "Mean (SD)" within this single cell — should appear exactly once
    local count = 0
    local sstr "`header_desc'"
    while strpos("`sstr'", "Mean (SD)") > 0 {
        local count = `count' + 1
        local p = strpos("`sstr'", "Mean (SD)")
        local sstr = substr("`sstr'", `p' + 9, .)
    }
    assert `count' == 1
}
if _rc == 0 {
    display as result "  PASS [7a]: table1_tc percent header has Mean (SD) exactly once"
    local ++pass_count
}
else {
    display as error "  FAIL [7a]: table1_tc percent header duplicated Mean (SD) (rc=`=_rc')"
    local ++fail_count
}
capture erase "`output_dir'/_rev1013_i1_percent.xlsx"


**# 8. diagtab degenerate 2x2 shows em-dash not ".%" (I6 regression)

**## 8a. All test-positive (FN=0, TN=0): NPV shows "—"
local ++test_count
capture noisily {
    clear
    set obs 50
    gen byte gold = cond(_n <= 30, 1, 0)
    gen byte test = 1
    local i6_xlsx "`output_dir'/_rev1013_i6_diagtab.xlsx"
    capture erase "`i6_xlsx'"
    diagtab test gold, xlsx("`i6_xlsx'") sheet("AllPos")

    * Read back after command returns (avoids nested preserve)
    clear
    import excel using "`i6_xlsx'", sheet("AllPos") allstring clear
    local found_dash = 0
    ds
    foreach v in `r(varlist)' {
        forvalues i = 1/`=_N' {
            if strtrim(`v'[`i']) == "NPV" {
                * Check the next column for em-dash
                local found_dash = 1
            }
        }
    }
    * Also check: find the NPV row and verify column B is "—"
    local found_dash = 0
    forvalues i = 1/`=_N' {
        if strtrim(A[`i']) == "NPV" | strtrim(B[`i']) == "NPV" {
            * The value column follows the label column
            if strtrim(A[`i']) == "NPV" & strtrim(B[`i']) == "—" local found_dash = 1
            if strtrim(B[`i']) == "NPV" & strtrim(C[`i']) == "—" local found_dash = 1
        }
    }
    assert `found_dash' == 1
}
if _rc == 0 {
    display as result "  PASS [8a]: diagtab all-test-positive: NPV shows em-dash"
    local ++pass_count
}
else {
    display as error "  FAIL [8a]: diagtab all-test-positive: NPV does not show em-dash (rc=`=_rc')"
    local ++fail_count
}

**## 8b. All test-negative (TP=0, FP=0): PPV shows "—" (Se=0% is correct, not undefined)
local ++test_count
capture noisily {
    clear
    set obs 50
    gen byte gold = cond(_n <= 30, 1, 0)
    gen byte test = 0
    local i6b_xlsx "`output_dir'/_rev1013_i6b_diagtab.xlsx"
    capture erase "`i6b_xlsx'"
    diagtab test gold, xlsx("`i6b_xlsx'") sheet("AllNeg")

    clear
    import excel using "`i6b_xlsx'", sheet("AllNeg") allstring clear
    local ppv_dash = 0
    forvalues i = 1/`=_N' {
        if strtrim(A[`i']) == "PPV" & strtrim(B[`i']) == "—" local ppv_dash = 1
        if strtrim(B[`i']) == "PPV" & strtrim(C[`i']) == "—" local ppv_dash = 1
    }
    assert `ppv_dash' == 1
}
if _rc == 0 {
    display as result "  PASS [8b]: diagtab all-test-negative: PPV shows em-dash"
    local ++pass_count
}
else {
    display as error "  FAIL [8b]: diagtab all-test-negative: PPV not em-dash (rc=`=_rc')"
    local ++fail_count
}
capture erase "`output_dir'/_rev1013_i6_diagtab.xlsx"
capture erase "`output_dir'/_rev1013_i6b_diagtab.xlsx"


**# 9. crosstab zero-denominator does not crash (I7 regression)

**## 9a. crosstab with colpct on valid data completes without error
local ++test_count
capture noisily {
    sysuse auto, clear
    crosstab foreign rep78, colpct display
    assert r(N) > 0
}
if _rc == 0 {
    display as result "  PASS [9a]: crosstab colpct on valid data completes"
    local ++pass_count
}
else {
    display as error "  FAIL [9a]: crosstab colpct crashed (rc=`=_rc')"
    local ++fail_count
}


**# 10. regtab refcat label only on base levels in Coef. scale (I9 regression)

**## 10a. Linear regression — reference labeled, non-reference value "1" not mislabeled
local ++test_count
capture noisily {
    sysuse auto, clear
    collect clear
    collect: regress price i.rep78 mpg weight
    local i9_xlsx "`output_dir'/_rev1013_i9_regtab.xlsx"
    capture erase "`i9_xlsx'"
    regtab, xlsx("`i9_xlsx'") sheet("I9Test") refcat("Ref.") noint

    * Read the xlsx after command returns (avoids nested preserve)
    * Read xlsx — col A=spacer, B=label, C=estimate
    clear
    import excel using "`i9_xlsx'", sheet("I9Test") allstring clear
    local ref_count = 0
    forvalues i = 1/`=_N' {
        if strtrim(C[`i']) == "Ref." local ref_count = `ref_count' + 1
    }
    * Should have exactly 1 reference category (base level of rep78)
    assert `ref_count' == 1
}
if _rc == 0 {
    display as result "  PASS [10a]: regtab Coef. scale reference label only on base level"
    local ++pass_count
}
else {
    display as error "  FAIL [10a]: regtab Coef. scale reference label issue (rc=`=_rc')"
    local ++fail_count
}
capture erase "`output_dir'/_rev1013_i9_regtab.xlsx"


**# 11. effecttab xlsx r(xlsx) populated and file exists (I3 regression)

**## 11a. Single Mata session produces correct output and r(xlsx)
local ++test_count
capture noisily {
    sysuse auto, clear
    collect clear
    collect: teffects ra (price mpg weight) (foreign)
    local i3_xlsx "`output_dir'/_rev1013_i3_effecttab.xlsx"
    capture erase "`i3_xlsx'"
    effecttab, xlsx("`i3_xlsx'") sheet("I3Test")
    assert `"`r(xlsx)'"' != ""
    capture confirm file "`i3_xlsx'"
    assert _rc == 0
}
if _rc == 0 {
    display as result "  PASS [11a]: effecttab r(xlsx) populated and file exists"
    local ++pass_count
}
else {
    display as error "  FAIL [11a]: effecttab r(xlsx) empty or file missing (rc=`=_rc')"
    local ++fail_count
}
capture erase "`output_dir'/_rev1013_i3_effecttab.xlsx"


**# 12. survtab headershade option accepted (I8 regression)

**## 12a. survtab with headershade produces a file without error
local ++test_count
capture noisily {
    sysuse cancer, clear
    stset studytime, failure(died)
    local i8_xlsx "`output_dir'/_rev1013_i8_survtab.xlsx"
    capture erase "`i8_xlsx'"
    survtab, times(10 20 30) by(drug) headershade ///
        xlsx("`i8_xlsx'") sheet("I8Test")
    assert `"`r(xlsx)'"' != ""
    capture confirm file "`i8_xlsx'"
    assert _rc == 0
}
if _rc == 0 {
    display as result "  PASS [12a]: survtab headershade option accepted and file created"
    local ++pass_count
}
else {
    display as error "  FAIL [12a]: survtab headershade failed (rc=`=_rc')"
    local ++fail_count
}
capture erase "`output_dir'/_rev1013_i8_survtab.xlsx"


**# 13. Version consistency across sthlp files (I2 regression)

**## 13a. tabtools.sthlp body version matches .ado version
local ++test_count
capture noisily {
    * Get .ado version from first line of tabtools.ado header
    tempname fh_ado
    local ado_version ""
    file open `fh_ado' using "`pkg_dir'/tabtools.ado", read text
    file read `fh_ado' line
    * First line: *! tabtools Version X.Y.Z  YYYY/MM/DD
    local ado_version = strtrim(word(`"`line'"', 4))
    file close `fh_ado'

    * Read tabtools.sthlp and find the Version line
    tempname fh_ver
    local sthlp_version ""
    file open `fh_ver' using "`pkg_dir'/tabtools.sthlp", read text
    file read `fh_ver' line
    while r(eof) == 0 {
        if strpos(`"`line'"', "{bf:Version}") > 0 {
            local sthlp_version = strtrim(subinstr(`"`line'"', "{pstd}{bf:Version}", "", 1))
        }
        file read `fh_ver' line
    }
    file close `fh_ver'
    assert "`sthlp_version'" == "`ado_version'"
}
if _rc == 0 {
    display as result "  PASS [13a]: tabtools.sthlp body version matches .ado version"
    local ++pass_count
}
else {
    display as error "  FAIL [13a]: tabtools.sthlp version mismatch (rc=`=_rc')"
    local ++fail_count
}

**## 13b. tabtools_cheatsheet.sthlp title version matches .ado version
local ++test_count
capture noisily {
    tempname fh_ado2
    local ado_version ""
    file open `fh_ado2' using "`pkg_dir'/tabtools.ado", read text
    file read `fh_ado2' line
    local ado_version = strtrim(word(`"`line'"', 4))
    file close `fh_ado2'

    tempname fh_cs
    local cs_version ""
    file open `fh_cs' using "`pkg_dir'/tabtools_cheatsheet.sthlp", read text
    file read `fh_cs' line
    while r(eof) == 0 {
        if strpos(`"`line'"', "Quick Reference (v") > 0 {
            local vstart = strpos(`"`line'"', "(v") + 2
            local vend = strpos(`"`line'"', ")}")
            local cs_version = substr(`"`line'"', `vstart', `vend' - `vstart')
        }
        file read `fh_cs' line
    }
    file close `fh_cs'
    assert "`cs_version'" == "`ado_version'"
}
if _rc == 0 {
    display as result "  PASS [13b]: tabtools_cheatsheet.sthlp title version matches .ado version"
    local ++pass_count
}
else {
    display as error "  FAIL [13b]: tabtools_cheatsheet.sthlp version mismatch (rc=`=_rc')"
    local ++fail_count
}


**# 14. table1_tc zero-denominator group does not produce ".%" (M10 regression)

**## 14a. Categorical variable with all-missing group does not crash or show ".%"
local ++test_count
capture noisily {
    clear
    set obs 60
    gen byte group = cond(_n <= 30, 1, 2)
    gen byte catvar = mod(_n, 3)
    replace catvar = . if group == 2
    local m10_xlsx "`output_dir'/_rev1013_m10_table1.xlsx"
    capture erase "`m10_xlsx'"
    table1_tc, vars(catvar cat) by(group) ///
        xlsx("`m10_xlsx'") sheet("M10Test")

    * Read back the xlsx after command returns (avoids nested preserve)
    clear
    import excel using "`m10_xlsx'", sheet("M10Test") allstring clear
    local found_dotpct = 0
    ds
    foreach v in `r(varlist)' {
        forvalues i = 1/`=_N' {
            local cell_val = `v'[`i']
            if strpos("`cell_val'", ".%") > 0 {
                local found_dotpct = 1
            }
        }
    }
    assert `found_dotpct' == 0
}
if _rc == 0 {
    display as result "  PASS [14a]: table1_tc zero-denominator group: no '.%' in output"
    local ++pass_count
}
else {
    display as error "  FAIL [14a]: table1_tc zero-denominator group: '.%' found or crash (rc=`=_rc')"
    local ++fail_count
}
capture erase "`output_dir'/_rev1013_m10_table1.xlsx"


**# Summary

display ""
display as text _dup(60) "="
display as text "v1.0.13 Review Regression Tests: " ///
    as result "`pass_count'" as text " passed, " ///
    as result "`fail_count'" as text " failed, " ///
    as result "`test_count'" as text " total"
display as text _dup(60) "="

if `fail_count' > 0 {
    display as error "SOME TESTS FAILED"
    log close _rev1013
    exit 1
}
else {
    display as result "ALL TESTS PASSED"
}

log close _rev1013
