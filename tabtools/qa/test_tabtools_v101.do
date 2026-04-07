* test_tabtools_v101.do — Tests for tabtools v1.0.1 fixes
* Covers: frame() pre-existing rejection, path validator quote rejection,
*         RNG state preservation in _tabtools_detect_vartype
* Tests: 32

clear all
set more off
set varabbrev off

capture log close _v101
log using "test_tabtools_v101.log", replace text name(_v101)

local tabtools_dir "`c(pwd)'/.."
local output_dir "`c(pwd)'/output"
capture mkdir "`output_dir'"

adopath ++ "`tabtools_dir'"
run "`tabtools_dir'/_tabtools_common.ado"

local test_count = 0
local pass_count = 0
local fail_count = 0
local failed_tests ""

* ============================================================
**# FIX 1: frame() rejects pre-existing frames
* ============================================================

* --- 1.1 corrtab: frame() rejects existing frame ---
local ++test_count
capture noisily {
    sysuse auto, clear
    capture frame drop victim
    frame create victim
    capture corrtab price mpg weight, frame(victim)
    assert _rc == 110
}
local _test_rc = _rc
capture frame drop victim
if `_test_rc' == 0 {
    display as result "  PASS: 1.1 corrtab frame() rejects existing frame"
    local ++pass_count
}
else {
    display as error "  FAIL: 1.1 corrtab frame() rejects existing frame (rc=`_test_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 1.1"
}

* --- 1.2 corrtab: frame() succeeds when frame does not exist ---
local ++test_count
capture noisily {
    sysuse auto, clear
    capture frame drop fresh_corr
    corrtab price mpg weight, frame(fresh_corr)
    capture confirm frame fresh_corr
    assert _rc == 0
}
local _test_rc = _rc
capture frame drop fresh_corr
if `_test_rc' == 0 {
    display as result "  PASS: 1.2 corrtab frame() works for new frame"
    local ++pass_count
}
else {
    display as error "  FAIL: 1.2 corrtab frame() works for new frame (rc=`_test_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 1.2"
}

* --- 1.3 table1_tc: frame() rejects existing frame ---
local ++test_count
capture noisily {
    sysuse auto, clear
    capture frame drop victim
    frame create victim
    capture table1_tc price mpg, by(foreign) frame(victim)
    assert _rc == 110
}
local _test_rc = _rc
capture frame drop victim
if `_test_rc' == 0 {
    display as result "  PASS: 1.3 table1_tc frame() rejects existing frame"
    local ++pass_count
}
else {
    display as error "  FAIL: 1.3 table1_tc frame() rejects existing frame (rc=`_test_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 1.3"
}

* --- 1.4 table1_tc: frame() succeeds when frame does not exist ---
local ++test_count
capture noisily {
    sysuse auto, clear
    capture frame drop fresh_t1
    table1_tc price mpg, by(foreign) frame(fresh_t1)
    capture confirm frame fresh_t1
    assert _rc == 0
}
local _test_rc = _rc
capture frame drop fresh_t1
if `_test_rc' == 0 {
    display as result "  PASS: 1.4 table1_tc frame() works for new frame"
    local ++pass_count
}
else {
    display as error "  FAIL: 1.4 table1_tc frame() works for new frame (rc=`_test_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 1.4"
}

* --- 1.5 regtab: frame() rejects existing frame ---
local ++test_count
capture noisily {
    sysuse auto, clear
    collect clear
    collect: quietly regress price mpg weight
    capture frame drop victim
    frame create victim
    capture regtab, frame(victim)
    assert _rc == 110
}
local _test_rc = _rc
capture frame drop victim
if `_test_rc' == 0 {
    display as result "  PASS: 1.5 regtab frame() rejects existing frame"
    local ++pass_count
}
else {
    display as error "  FAIL: 1.5 regtab frame() rejects existing frame (rc=`_test_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 1.5"
}

* --- 1.6 regtab: frame() succeeds when frame does not exist ---
local ++test_count
capture noisily {
    sysuse auto, clear
    collect clear
    collect: quietly regress price mpg weight
    capture frame drop fresh_reg
    regtab, frame(fresh_reg)
    capture confirm frame fresh_reg
    assert _rc == 0
}
local _test_rc = _rc
capture frame drop fresh_reg
if `_test_rc' == 0 {
    display as result "  PASS: 1.6 regtab frame() works for new frame"
    local ++pass_count
}
else {
    display as error "  FAIL: 1.6 regtab frame() works for new frame (rc=`_test_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 1.6"
}

* --- 1.7 effecttab: frame() rejects existing frame ---
* Use from() matrix path to avoid collect export dependency
local ++test_count
capture noisily {
    sysuse auto, clear
    matrix _eff_data = (1.5, 0.8, 2.2, 0.001 \ -0.3, -0.9, 0.3, 0.330)
    matrix colnames _eff_data = estimate ci_lower ci_upper pvalue
    matrix rownames _eff_data = "Treatment" "Age"
    capture frame drop victim
    frame create victim
    capture effecttab, from(_eff_data) xlsx("`output_dir'/_test_eff_rej.xlsx") frame(victim)
    assert _rc == 110
}
local _test_rc = _rc
capture frame drop victim
capture matrix drop _eff_data
if `_test_rc' == 0 {
    display as result "  PASS: 1.7 effecttab frame() rejects existing frame"
    local ++pass_count
}
else {
    display as error "  FAIL: 1.7 effecttab frame() rejects existing frame (rc=`_test_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 1.7"
}

* --- 1.8 effecttab: frame() succeeds when frame does not exist ---
local ++test_count
capture noisily {
    matrix _eff_data2 = (1.5, 0.8, 2.2, 0.001 \ -0.3, -0.9, 0.3, 0.330)
    matrix colnames _eff_data2 = estimate ci_lower ci_upper pvalue
    matrix rownames _eff_data2 = "Treatment" "Age"
    capture frame drop fresh_eff
    effecttab, from(_eff_data2) xlsx("`output_dir'/_test_eff_frame.xlsx") frame(fresh_eff)
    capture confirm frame fresh_eff
    assert _rc == 0
}
local _test_rc = _rc
capture frame drop fresh_eff
if `_test_rc' == 0 {
    display as result "  PASS: 1.8 effecttab frame() works for new frame"
    local ++pass_count
}
else {
    display as error "  FAIL: 1.8 effecttab frame() works for new frame (rc=`_test_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 1.8"
}

* --- 1.9 comptab: frame() rejects existing frame ---
local ++test_count
capture noisily {
    sysuse auto, clear
    collect clear
    collect: quietly regress price mpg weight
    capture frame drop _ct_src1
    regtab, frame(_ct_src1) noint
    capture frame drop victim
    frame create victim
    capture comptab _ct_src1, rows(1) frame(victim)
    assert _rc == 110
}
local _test_rc = _rc
capture frame drop victim
capture frame drop _ct_src1
if `_test_rc' == 0 {
    display as result "  PASS: 1.9 comptab frame() rejects existing frame"
    local ++pass_count
}
else {
    display as error "  FAIL: 1.9 comptab frame() rejects existing frame (rc=`_test_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 1.9"
}

* --- 1.10 comptab: frame() succeeds when frame does not exist ---
local ++test_count
capture noisily {
    sysuse auto, clear
    collect clear
    collect: quietly regress price mpg weight
    capture frame drop _ct_src2
    regtab, frame(_ct_src2) noint
    capture frame drop fresh_comp
    comptab _ct_src2, rows(1) frame(fresh_comp)
    capture confirm frame fresh_comp
    assert _rc == 0
}
local _test_rc = _rc
capture frame drop fresh_comp
capture frame drop _ct_src2
if `_test_rc' == 0 {
    display as result "  PASS: 1.10 comptab frame() works for new frame"
    local ++pass_count
}
else {
    display as error "  FAIL: 1.10 comptab frame() works for new frame (rc=`_test_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 1.10"
}

* --- 1.11 crosstab: frame() rejects existing frame ---
local ++test_count
capture noisily {
    sysuse auto, clear
    capture frame drop victim
    frame create victim
    capture crosstab foreign rep78, frame(victim)
    assert _rc == 110
}
local _test_rc = _rc
capture frame drop victim
if `_test_rc' == 0 {
    display as result "  PASS: 1.11 crosstab frame() rejects existing frame"
    local ++pass_count
}
else {
    display as error "  FAIL: 1.11 crosstab frame() rejects existing frame (rc=`_test_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 1.11"
}

* --- 1.12 crosstab: frame() succeeds when frame does not exist ---
local ++test_count
capture noisily {
    sysuse auto, clear
    capture frame drop fresh_cross
    crosstab foreign rep78, frame(fresh_cross)
    capture confirm frame fresh_cross
    assert _rc == 0
}
local _test_rc = _rc
capture frame drop fresh_cross
if `_test_rc' == 0 {
    display as result "  PASS: 1.12 crosstab frame() works for new frame"
    local ++pass_count
}
else {
    display as error "  FAIL: 1.12 crosstab frame() works for new frame (rc=`_test_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 1.12"
}

* --- 1.13 diagtab: frame() rejects existing frame ---
local ++test_count
capture noisily {
    clear
    set obs 200
    set seed 42
    gen gold = runiform() < 0.3
    gen test_result = runiform() < (0.8 * gold + 0.1 * (1 - gold))
    capture frame drop victim
    frame create victim
    capture diagtab test_result gold, frame(victim)
    assert _rc == 110
}
local _test_rc = _rc
capture frame drop victim
if `_test_rc' == 0 {
    display as result "  PASS: 1.13 diagtab frame() rejects existing frame"
    local ++pass_count
}
else {
    display as error "  FAIL: 1.13 diagtab frame() rejects existing frame (rc=`_test_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 1.13"
}

* --- 1.14 diagtab: frame() succeeds when frame does not exist ---
local ++test_count
capture noisily {
    clear
    set obs 200
    set seed 42
    gen gold = runiform() < 0.3
    gen test_result = runiform() < (0.8 * gold + 0.1 * (1 - gold))
    capture frame drop fresh_diag
    diagtab test_result gold, frame(fresh_diag)
    capture confirm frame fresh_diag
    assert _rc == 0
}
local _test_rc = _rc
capture frame drop fresh_diag
if `_test_rc' == 0 {
    display as result "  PASS: 1.14 diagtab frame() works for new frame"
    local ++pass_count
}
else {
    display as error "  FAIL: 1.14 diagtab frame() works for new frame (rc=`_test_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 1.14"
}

* --- 1.15 fittab: frame() rejects existing frame ---
local ++test_count
capture noisily {
    sysuse auto, clear
    quietly regress price mpg
    estimates store _ft_m1
    quietly regress price mpg weight
    estimates store _ft_m2
    capture frame drop victim
    frame create victim
    capture fittab _ft_m1 _ft_m2, frame(victim)
    assert _rc == 110
}
local _test_rc = _rc
capture frame drop victim
capture estimates drop _ft_m1 _ft_m2
if `_test_rc' == 0 {
    display as result "  PASS: 1.15 fittab frame() rejects existing frame"
    local ++pass_count
}
else {
    display as error "  FAIL: 1.15 fittab frame() rejects existing frame (rc=`_test_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 1.15"
}

* --- 1.16 fittab: frame() succeeds when frame does not exist ---
local ++test_count
capture noisily {
    sysuse auto, clear
    quietly regress price mpg
    estimates store _ft_m3
    quietly regress price mpg weight
    estimates store _ft_m4
    capture frame drop fresh_fit
    fittab _ft_m3 _ft_m4, frame(fresh_fit)
    capture confirm frame fresh_fit
    assert _rc == 0
}
local _test_rc = _rc
capture frame drop fresh_fit
capture estimates drop _ft_m3 _ft_m4
if `_test_rc' == 0 {
    display as result "  PASS: 1.16 fittab frame() works for new frame"
    local ++pass_count
}
else {
    display as error "  FAIL: 1.16 fittab frame() works for new frame (rc=`_test_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 1.16"
}

* --- 1.17 survtab: frame() rejects existing frame ---
local ++test_count
capture noisily {
    clear
    set obs 200
    set seed 99
    gen time = rexponential(5)
    gen event = runiform() < 0.6
    gen grp = runiform() < 0.5
    stset time, failure(event)
    capture frame drop victim
    frame create victim
    capture survtab, times(1 3 5) by(grp) frame(victim)
    assert _rc == 110
}
local _test_rc = _rc
capture frame drop victim
if `_test_rc' == 0 {
    display as result "  PASS: 1.17 survtab frame() rejects existing frame"
    local ++pass_count
}
else {
    display as error "  FAIL: 1.17 survtab frame() rejects existing frame (rc=`_test_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 1.17"
}

* --- 1.18 survtab: frame() succeeds when frame does not exist ---
local ++test_count
capture noisily {
    clear
    set obs 200
    set seed 99
    gen time = rexponential(5)
    gen event = runiform() < 0.6
    gen grp = runiform() < 0.5
    stset time, failure(event)
    capture frame drop fresh_surv
    survtab, times(1 3 5) by(grp) frame(fresh_surv)
    capture confirm frame fresh_surv
    assert _rc == 0
}
local _test_rc = _rc
capture frame drop fresh_surv
if `_test_rc' == 0 {
    display as result "  PASS: 1.18 survtab frame() works for new frame"
    local ++pass_count
}
else {
    display as error "  FAIL: 1.18 survtab frame() works for new frame (rc=`_test_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 1.18"
}

* --- 1.19 tablex: frame() rejects existing frame ---
local ++test_count
capture noisily {
    sysuse auto, clear
    table foreign rep78
    capture frame drop victim
    frame create victim
    capture tablex using "`output_dir'/_test_tablex_frame.xlsx", ///
        frame(victim) title("Test") replace
    assert _rc == 110
}
local _test_rc = _rc
capture frame drop victim
if `_test_rc' == 0 {
    display as result "  PASS: 1.19 tablex frame() rejects existing frame"
    local ++pass_count
}
else {
    display as error "  FAIL: 1.19 tablex frame() rejects existing frame (rc=`_test_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 1.19"
}

* --- 1.20 tablex: frame() succeeds when frame does not exist ---
local ++test_count
capture noisily {
    sysuse auto, clear
    table foreign rep78
    capture frame drop fresh_tx
    tablex using "`output_dir'/_test_tablex_frame2.xlsx", ///
        frame(fresh_tx) title("Test") replace
    capture confirm frame fresh_tx
    assert _rc == 0
}
local _test_rc = _rc
capture frame drop fresh_tx
if `_test_rc' == 0 {
    display as result "  PASS: 1.20 tablex frame() works for new frame"
    local ++pass_count
}
else {
    display as error "  FAIL: 1.20 tablex frame() works for new frame (rc=`_test_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 1.20"
}

* ============================================================
**# FIX 2: _tabtools_validate_path rejects quote characters
* ============================================================

* Reload helpers to pick up validate_path fix
capture program drop _tabtools_validate_path
capture program drop _tabtools_detect_vartype
capture program drop _tabtools_col_letter
capture program drop _tabtools_build_col_letters
capture program drop _tabtools_footnote
capture program drop _tabtools_open_file
capture program drop _tabtools_validate_sheet
capture program drop _tabtools_apply_theme
capture program drop _tabtools_resolve_format
capture program drop _tabtools_console_display
capture program drop _tabtools_frame_put
run "`tabtools_dir'/_tabtools_common.ado"

* --- 2.1 Double quote rejected ---
local ++test_count
capture noisily {
    local p = "bad" + char(34) + "file.xlsx"
    capture noisily _tabtools_validate_path `"`p'"' "xlsx()"
    local _vrc = _rc
    assert `_vrc' == 198
}
if _rc == 0 {
    display as result "  PASS: 2.1 validate_path rejects double quote"
    local ++pass_count
}
else {
    display as error "  FAIL: 2.1 validate_path rejects double quote (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 2.1"
}

* --- 2.2 Single quote rejected ---
local ++test_count
capture noisily {
    capture noisily _tabtools_validate_path "bad'file.xlsx" "xlsx()"
    local _vrc = _rc
    assert `_vrc' == 198
}
if _rc == 0 {
    display as result "  PASS: 2.2 validate_path rejects single quote"
    local ++pass_count
}
else {
    display as error "  FAIL: 2.2 validate_path rejects single quote (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 2.2"
}

* --- 2.3 Clean path accepted ---
local ++test_count
capture noisily {
    _tabtools_validate_path "/tmp/clean_file.xlsx" "xlsx()"
}
if _rc == 0 {
    display as result "  PASS: 2.3 validate_path accepts clean path"
    local ++pass_count
}
else {
    display as error "  FAIL: 2.3 validate_path accepts clean path (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 2.3"
}

* --- 2.4 Semicolon still rejected (regression check) ---
local ++test_count
capture noisily {
    capture noisily _tabtools_validate_path "/tmp/bad;file.xlsx" "xlsx()"
    local _vrc = _rc
    assert `_vrc' == 198
}
if _rc == 0 {
    display as result "  PASS: 2.4 validate_path still rejects semicolon"
    local ++pass_count
}
else {
    display as error "  FAIL: 2.4 validate_path still rejects semicolon (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 2.4"
}

* --- 2.5 Pipe still rejected (regression check) ---
local ++test_count
capture noisily {
    capture noisily _tabtools_validate_path "/tmp/bad|file.xlsx" "xlsx()"
    local _vrc = _rc
    assert `_vrc' == 198
}
if _rc == 0 {
    display as result "  PASS: 2.5 validate_path still rejects pipe"
    local ++pass_count
}
else {
    display as error "  FAIL: 2.5 validate_path still rejects pipe (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 2.5"
}

* --- 2.6 Path with spaces accepted ---
local ++test_count
capture noisily {
    _tabtools_validate_path "/tmp/my file name.xlsx" "xlsx()"
}
if _rc == 0 {
    display as result "  PASS: 2.6 validate_path accepts path with spaces"
    local ++pass_count
}
else {
    display as error "  FAIL: 2.6 validate_path accepts path with spaces (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 2.6"
}

* --- 2.7 Backtick still rejected (regression check) ---
* Build path with literal backtick via char(96)
local ++test_count
capture noisily {
    local p = "/tmp/bad" + char(96) + "file.xlsx"
    capture noisily _tabtools_validate_path `"`p'"' "xlsx()"
    local _vrc = _rc
    assert `_vrc' == 198
}
if _rc == 0 {
    display as result "  PASS: 2.7 validate_path still rejects backtick"
    local ++pass_count
}
else {
    display as error "  FAIL: 2.7 validate_path still rejects backtick (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 2.7"
}

* --- 2.8 Ampersand still rejected (regression check) ---
local ++test_count
capture noisily {
    capture noisily _tabtools_validate_path "/tmp/bad&file.xlsx" "xlsx()"
    local _vrc = _rc
    assert `_vrc' == 198
}
if _rc == 0 {
    display as result "  PASS: 2.8 validate_path still rejects ampersand"
    local ++pass_count
}
else {
    display as error "  FAIL: 2.8 validate_path still rejects ampersand (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 2.8"
}

* ============================================================
**# FIX 3: RNG state preserved by _tabtools_detect_vartype
* ============================================================

* Helpers already reloaded above

* --- 3.1 RNG state unchanged after detect_vartype (N > 2000, triggers sampling) ---
local ++test_count
capture noisily {
    clear
    set obs 3000
    gen x = rnormal()

    set seed 24680
    scalar baseline = runiform()

    set seed 24680
    _tabtools_detect_vartype x
    scalar after_detect = runiform()

    assert baseline == after_detect
}
if _rc == 0 {
    display as result "  PASS: 3.1 RNG state preserved (N=3000, sampling path)"
    local ++pass_count
}
else {
    display as error "  FAIL: 3.1 RNG state preserved (N=3000, sampling path) (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 3.1"
}

* --- 3.2 RNG state unchanged for N <= 2000 (no sampling, control test) ---
local ++test_count
capture noisily {
    clear
    set obs 500
    gen x = rnormal()

    set seed 24680
    scalar baseline2 = runiform()

    set seed 24680
    _tabtools_detect_vartype x
    scalar after_detect2 = runiform()

    assert baseline2 == after_detect2
}
if _rc == 0 {
    display as result "  PASS: 3.2 RNG state preserved (N=500, no sampling)"
    local ++pass_count
}
else {
    display as error "  FAIL: 3.2 RNG state preserved (N=500, no sampling) (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 3.2"
}

* --- 3.3 RNG state unchanged for N > 5000 (skewness path, no sampling) ---
local ++test_count
capture noisily {
    clear
    set obs 6000
    gen x = rnormal()

    set seed 24680
    scalar baseline3 = runiform()

    set seed 24680
    _tabtools_detect_vartype x
    scalar after_detect3 = runiform()

    assert baseline3 == after_detect3
}
if _rc == 0 {
    display as result "  PASS: 3.3 RNG state preserved (N=6000, skewness path)"
    local ++pass_count
}
else {
    display as error "  FAIL: 3.3 RNG state preserved (N=6000, skewness path) (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 3.3"
}

* --- 3.4 detect_vartype still classifies correctly after RNG fix ---
local ++test_count
capture noisily {
    clear
    set obs 3000
    set seed 777
    gen x_norm = rnormal(50, 10)
    gen x_skew = rexponential(1)
    gen x_cat = floor(runiform() * 5)
    gen x_bin = runiform() < 0.4

    _tabtools_detect_vartype x_norm
    local t_norm "`result'"
    _tabtools_detect_vartype x_skew
    local t_skew "`result'"
    _tabtools_detect_vartype x_cat
    local t_cat "`result'"
    _tabtools_detect_vartype x_bin
    local t_bin "`result'"

    assert "`t_norm'" == "contn" | "`t_norm'" == "conts"
    assert "`t_skew'" == "conts"
    assert "`t_cat'" == "cat"
    assert "`t_bin'" == "bin"
}
if _rc == 0 {
    display as result "  PASS: 3.4 detect_vartype classifications still correct"
    local ++pass_count
}
else {
    display as error "  FAIL: 3.4 detect_vartype classifications still correct (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 3.4"
}

* ============================================================
**# Summary
* ============================================================

display as text ""
display as text "============================================"
display as text "  tabtools v1.0.1 Test Results"
display as text "============================================"
display as text ""
display as result "  Total:  `test_count'"
display as result "  Passed: `pass_count'"
if `fail_count' > 0 {
    display as error "  Failed: `fail_count'"
    display as error "  Failed tests: `failed_tests'"
}
else {
    display as result "  Failed: 0"
}
display as text ""

if `fail_count' == 0 {
    display as result "ALL `pass_count' TESTS PASSED"
}
else {
    display as error "`fail_count' TEST(S) FAILED"
    exit 9
}

log close _v101
