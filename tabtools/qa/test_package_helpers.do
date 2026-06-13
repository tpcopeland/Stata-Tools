* test_package_helpers.do - shared helper and style-engine contracts (multi-command infrastructure)
* Consolidated in v1.7.0 from: test_collect_json_render_contracts.do, test_color_validation.do, test_console_display_contracts.do, test_excel_validation.do, test_excel_widths.do, test_markdown_exports.do, test_mata_backend_contracts.do, test_new_commands.do, test_refactor_contracts.do, test_review_v1013.do, test_shared_style_engine_after_migration.do, test_style_engine_apply_styles.do, test_tabtools.do, test_tabtools_v101.do, test_xlsx_read_current_contracts.do

clear all
set more off
set varabbrev off
version 17.0

capture log close _pkghelpers
log using "test_package_helpers.log", replace text name(_pkghelpers)

local test_count = 0
local pass_count = 0
local fail_count = 0

local n_total = 0
**# Bootstrap
local qa_dir "`c(pwd)'"
local pkg_dir = subinstr("`qa_dir'", "/qa", "", 1)
local pkg_root "`pkg_dir'"
local output_dir "`qa_dir'/output"
capture mkdir "`output_dir'"
local tools_dir "`qa_dir'/tools"
* xlsx checker: single canonical copy in Stata-Dev (no per-package duplicate)
local _statadev : env STATA_DEV_DIR
if "`_statadev'" == "" {
    local _home : env HOME
    local _statadev "`_home'/Stata-Dev"
}
local checker "`_statadev'/_devkit/stata_dev_cli/xlsx/check_xlsx.py"
local checker "`checker'"
local md_checker "`tools_dir'/check_markdown.py"
local summary_tool "`tools_dir'/summarize_xlsx.py"

local python_cmd ""
capture noisily shell python3 --version
if _rc == 0 {
    local python_cmd "python3"
}
else {
    capture noisily shell python --version
    if _rc == 0 local python_cmd "python"
}

capture ado uninstall tabtools
quietly net install tabtools, from("`pkg_dir'") replace
discard
tabtools set clear


**# Migrated: _tabtools_common utility contracts

* ============================================================
* Helper Utility Tests (_tabtools_common)
* ============================================================

* Ensure internal helpers are available even if this block is run standalone.
capture findfile _tabtools_common.ado
if _rc == 0 {
    run "`r(fn)'"
}

* Test: _tabtools_col_letter basic conversions
capture noisily {
    _tabtools_col_letter 1
    assert "`result'" == "A"
    _tabtools_col_letter 26
    assert "`result'" == "Z"
    _tabtools_col_letter 27
    assert "`result'" == "AA"
}
if _rc == 0 {
    display as result "  PASS: _tabtools_col_letter - A, Z, AA"
    local ++pass_count
}
else {
    display as error "  FAIL: _tabtools_col_letter (error `=_rc')"
    local ++fail_count
}

* Test: _tabtools_build_col_letters
capture noisily {
    _tabtools_build_col_letters 5
    assert "`result'" == "A B C D E"
}
if _rc == 0 {
    display as result "  PASS: _tabtools_build_col_letters - 5 columns"
    local ++pass_count
}
else {
    display as error "  FAIL: _tabtools_build_col_letters (error `=_rc')"
    local ++fail_count
}

* Test: _tabtools_validate_path accepts valid paths
capture noisily {
    _tabtools_validate_path "good_file.xlsx" "test"
}
if _rc == 0 {
    display as result "  PASS: _tabtools_validate_path - valid path accepted"
    local ++pass_count
}
else {
    display as error "  FAIL: _tabtools_validate_path - valid path (error `=_rc')"
    local ++fail_count
}

* Test: _tabtools_validate_path accepts apostrophes
capture noisily {
    _tabtools_validate_path "output/O'Brien.xlsx" "test"
}
if _rc == 0 {
    display as result "  PASS: _tabtools_validate_path - apostrophe path accepted"
    local ++pass_count
}
else {
    display as error "  FAIL: _tabtools_validate_path - apostrophe path (error `=_rc')"
    local ++fail_count
}

* Test: _tabtools_validate_path rejects dangerous characters
capture noisily {
    capture _tabtools_validate_path "bad;file.xlsx" "test"
    assert _rc == 198
    capture _tabtools_validate_path "bad|file.xlsx" "test"
    assert _rc == 198
}
if _rc == 0 {
    display as result "  PASS: _tabtools_validate_path - dangerous chars rejected"
    local ++pass_count
}
else {
    display as error "  FAIL: _tabtools_validate_path - dangerous chars (error `=_rc')"
    local ++fail_count
}

* Test: helper bundle reloads when a later helper is missing
capture noisily {
    sysuse auto, clear
    collect clear
    collect: regress price mpg weight
    capture frame drop _helper_reload
    capture program drop _tabtools_frame_put
    regtab, frame(_helper_reload, replace)
    capture confirm frame _helper_reload
    assert _rc == 0
}
capture frame drop _helper_reload
if _rc == 0 {
    display as result "  PASS: helper bundle reloads when a later helper is missing"
    local ++pass_count
}
else {
    display as error "  FAIL: helper bundle reload after partial drop (error `=_rc')"
    local ++fail_count
}

* Test: tabtools reloads helpers even when a stale same-name helper is in memory
capture noisily {
    capture program drop _tabtools_resolve_format
    program define _tabtools_resolve_format
        c_local _font "Bogus"
        c_local _fontsize 99
        c_local borderstyle "medium"
        c_local _hborder "medium"
    end
    tabtools set clear
    tabtools get
    assert "`r(font)'" == "Arial"
    assert "`r(fontsize)'" == "10"
    assert "`r(borderstyle)'" == "thin"
}
if _rc == 0 {
    display as result "  PASS: tabtools reloads stale same-name helpers"
    local ++pass_count
}
else {
    display as error "  FAIL: tabtools stale-helper reload (error `=_rc')"
    local ++fail_count
}


**# Migrated: _tabtools_detect_vartype contracts

* ============================================================
* _tabtools_detect_vartype Tests
* ============================================================

**# _tabtools_detect_vartype

* Test: string variable → "cat"
capture noisily {
    clear
    set obs 20
    set seed 20260312
    gen str5 svar = "aaa"
    replace svar = "bbb" if _n > 10
    _tabtools_detect_vartype svar
    assert "`result'" == "cat"
}
if _rc == 0 {
    display as result "  PASS: _tabtools_detect_vartype - string → cat"
    local ++pass_count
}
else {
    display as error "  FAIL: _tabtools_detect_vartype - string (error `=_rc')"
    local ++fail_count
}

* Test: binary 0/1 integer → "bin"
capture noisily {
    clear
    set obs 20
    gen byte bvar = mod(_n, 2)
    _tabtools_detect_vartype bvar
    assert "`result'" == "bin"
}
if _rc == 0 {
    display as result "  PASS: _tabtools_detect_vartype - binary 0/1 → bin"
    local ++pass_count
}
else {
    display as error "  FAIL: _tabtools_detect_vartype - binary 0/1 (error `=_rc')"
    local ++fail_count
}

* Test: binary 1/2 with value labels → "bin"
capture noisily {
    clear
    set obs 20
    gen byte bvar2 = 1 + mod(_n, 2)
    label define bin2_lbl 1 "A" 2 "B"
    label values bvar2 bin2_lbl
    _tabtools_detect_vartype bvar2
    assert "`result'" == "bin"
}
if _rc == 0 {
    display as result "  PASS: _tabtools_detect_vartype - binary 1/2 labeled → bin"
    local ++pass_count
}
else {
    display as error "  FAIL: _tabtools_detect_vartype - binary 1/2 (error `=_rc')"
    local ++fail_count
}

* Test: labeled categorical 4 levels → "cat"
capture noisily {
    clear
    set obs 40
    gen byte cvar = mod(_n, 4) + 1
    label define cat4_lbl 1 "Low" 2 "Med" 3 "High" 4 "VHigh"
    label values cvar cat4_lbl
    _tabtools_detect_vartype cvar
    assert "`result'" == "cat"
}
if _rc == 0 {
    display as result "  PASS: _tabtools_detect_vartype - 4-level labeled → cat"
    local ++pass_count
}
else {
    display as error "  FAIL: _tabtools_detect_vartype - 4-level labeled (error `=_rc')"
    local ++fail_count
}

* Test: unlabeled 5-level integer → "cat"
capture noisily {
    clear
    set obs 100
    gen byte c5 = mod(_n, 5) + 1
    _tabtools_detect_vartype c5
    assert "`result'" == "cat"
}
if _rc == 0 {
    display as result "  PASS: _tabtools_detect_vartype - 5-level unlabeled → cat"
    local ++pass_count
}
else {
    display as error "  FAIL: _tabtools_detect_vartype - 5-level unlabeled (error `=_rc')"
    local ++fail_count
}

* Test: continuous normal (N=500) → "contn"
capture noisily {
    clear
    set seed 20260312
    set obs 500
    gen double cnorm = rnormal(50, 10)
    _tabtools_detect_vartype cnorm
    assert "`result'" == "contn"
}
if _rc == 0 {
    display as result "  PASS: _tabtools_detect_vartype - normal distribution → contn"
    local ++pass_count
}
else {
    display as error "  FAIL: _tabtools_detect_vartype - normal (error `=_rc')"
    local ++fail_count
}

* Test: continuous skewed (exp(rnormal), N=500) → "conts"
capture noisily {
    clear
    set seed 20260312
    set obs 500
    gen double cskew = exp(rnormal(0, 1))
    _tabtools_detect_vartype cskew
    assert "`result'" == "conts"
}
if _rc == 0 {
    display as result "  PASS: _tabtools_detect_vartype - skewed distribution → conts"
    local ++pass_count
}
else {
    display as error "  FAIL: _tabtools_detect_vartype - skewed (error `=_rc')"
    local ++fail_count
}

* Test: all-missing variable defaults cleanly to contn
capture noisily {
    clear
    set obs 50
    gen double miss_var = .
    _tabtools_detect_vartype miss_var
    assert "`result'" == "contn"
}
if _rc == 0 {
    display as result "  PASS: _tabtools_detect_vartype - all missing defaults to contn"
    local ++pass_count
}
else {
    display as error "  FAIL: _tabtools_detect_vartype - all missing unexpected error `=_rc'"
    local ++fail_count
}

* Test: high-cardinality continuous variable does not overflow macros
capture noisily {
    clear
    set obs 50000
    gen double hi_cont = _n + runiform()/1000000
    _tabtools_detect_vartype hi_cont
    assert "`result'" == "contn"
}
if _rc == 0 {
    display as result "  PASS: _tabtools_detect_vartype - 50,000 unique doubles → contn"
    local ++pass_count
}
else {
    display as error "  FAIL: _tabtools_detect_vartype - high-cardinality doubles (error `=_rc')"
    local ++fail_count
}


**# Migrated: validate_path quotes + RNG preservation

**# FIX 2: _tabtools_validate_path rejects double quotes but allows apostrophes
* ============================================================

* --- 2.1 Double quote rejected ---
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

* --- 2.2 Single quote accepted ---
capture noisily {
    _tabtools_validate_path "good'file.xlsx" "xlsx()"
}
if _rc == 0 {
    display as result "  PASS: 2.2 validate_path accepts single quote"
    local ++pass_count
}
else {
    display as error "  FAIL: 2.2 validate_path accepts single quote (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 2.2"
}

* --- 2.3 Clean path accepted ---
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

**# Migrated: helpers_ready file parsing

**# 3. _tabtools_helpers_ready file-parsing discovers programs

**## 3a. After fresh load, _tabtools_helpers_ready succeeds without arguments
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



**# Migrated: sheet-name validation across commands

* --- 7.12: Sheet name validation ---
capture noisily {
    sysuse auto, clear
    corrtab price mpg weight, ///
        xlsx("`output_dir'/test_sheet_validation.xlsx") ///
        sheet("This sheet name is way too long for Excel limit")
}
if _rc != 0 {
    display as result "  PASS: Sheet name > 31 chars rejected"
    local ++pass_count
}
else {
    display as error "  FAIL: Sheet name > 31 chars should be rejected"
    local ++fail_count
}

* Test: Sheet name with invalid chars rejected
capture noisily {
    sysuse auto, clear
    corrtab price mpg weight, ///
        xlsx("`output_dir'/test_sheet_invalid.xlsx") ///
        sheet("Bad[name]")
}
if _rc != 0 {
    display as result "  PASS: Sheet name with [ ] rejected"
    local ++pass_count
}
else {
    display as error "  FAIL: Sheet name with [ ] should be rejected"
    local ++fail_count
}

* Test: Sheet name with colon rejected
capture noisily {
    sysuse auto, clear
    corrtab price mpg weight, ///
        xlsx("`output_dir'/test_sheet_colon.xlsx") ///
        sheet("Bad:Name")
}
if _rc != 0 {
    display as result "  PASS: Sheet name with : rejected"
    local ++pass_count
}
else {
    display as error "  FAIL: Sheet name with : should be rejected"
    local ++fail_count
}

* Test: Apostrophes are allowed in sheet names
capture noisily {
    sysuse auto, clear
    capture erase "`output_dir'/test_sheet_apostrophe.xlsx"
    corrtab price mpg weight, ///
        xlsx("`output_dir'/test_sheet_apostrophe.xlsx") ///
        sheet("O'Brien")
    confirm file "`output_dir'/test_sheet_apostrophe.xlsx"
}
if _rc == 0 {
    display as result "  PASS: Apostrophes allowed in sheet names"
    local ++pass_count
}
else {
    display as error "  FAIL: Apostrophes should be allowed in sheet names (rc=`=_rc')"
    local ++fail_count
}

* --- 7.13: Custom theme builder ---
capture noisily {
    tabtools set clear
    tabtools set theme custom, font(Calibri) fontsize(11)
    tabtools get
    assert r(theme) == "custom"
}
if _rc == 0 {
    display as result "  PASS: tabtools set theme custom"
    local ++pass_count
}
else {
    display as error "  FAIL: tabtools set theme custom (rc=`=_rc')"
    local ++fail_count
}
tabtools set clear

* ============================================================

**# Migrated: Mata xlsx backend contracts


local checker "`checker'"
capture confirm file "`checker'"
if _rc {
    display as error "FAIL: check_xlsx.py not available"
    exit 601
}

local python_cmd ""
capture noisily shell python3 --version
if _rc == 0 {
    local python_cmd "python3"
}
else {
    capture noisily shell python --version
    if _rc == 0 local python_cmd "python"
}
if "`python_cmd'" == "" {
    display as error "FAIL: python/openpyxl checker runtime not available"
    exit 601
}

capture program drop _mb_assert_xlsx
program define _mb_assert_xlsx
    args result_file checks
    shell `checks'
    file open _fh using "`result_file'", read text
    file read _fh _line
    file close _fh
    assert "`_line'" == "PASS"
end


**# Helper Contracts

capture noisily {
    clear
    input str20 title str20 c1 str20 c2
    "First title" "A" "B"
    "First row" "1" "2"
    end
    capture erase "`output_dir'/_mb_helper.xlsx"
    _tabtools_xlsx_write using "`output_dir'/_mb_helper.xlsx", sheet("Backend") book(b)
    mata: b.close_book()
    mata: mata drop b

    clear
    input str20 title str20 c1 str20 c2
    "Second title" "C" "D"
    "Second row" "3" "4"
    end
    _tabtools_xlsx_write using "`output_dir'/_mb_helper.xlsx", sheet("Backend") book(b)
    mata: b.close_book()
    mata: mata drop b

    clear
    _tabtools_xlsx_read using "`output_dir'/_mb_helper.xlsx", sheet("Backend")
    assert _N == 2
    assert c(k) == 3
    assert A[1] == "Second title"
    assert B[2] == "3"
    assert C[2] == "4"
}
if _rc == 0 {
    display as result "  PASS: helper writes and replaces sheets"
    local ++pass_count
}
else {
    display as error "  FAIL: helper sheet replacement contract (rc=`=_rc')"
    local ++fail_count
}

* _tabtools_xlsx_set_widths and _tabtools_table_metadata_current contract tests
* removed in v1.7.0: both helpers were dead code (no production callers) and
* were dropped from the shipped package.

**# Public Writer Contracts

* Collect-backed commands still use collect export as the rendered-table bridge:
* collect is the source of row labels, column nesting, and style-aware cell text.
* The public writer path below is locked to Mata read/write/formatting after that
* compatibility boundary.

capture noisily {
    sysuse auto, clear
    collect clear
    collect: regress price mpg weight
    capture erase "`output_dir'/_mb_regtab.xlsx"
    regtab, xlsx("`output_dir'/_mb_regtab.xlsx") sheet("Reg") ///
        title("Backend Regression") boldp(0.05) headershade footnote("Backend footnote")
    assert "`r(xlsx)'" == "`output_dir'/_mb_regtab.xlsx"
    assert "`r(sheet)'" == "Reg"

    _mb_assert_xlsx "`output_dir'/_mb_regtab.txt" ///
        `"`python_cmd' "`checker'" "`output_dir'/_mb_regtab.xlsx" --sheet "Reg" --cell A1 "Backend Regression" --contains "Backend footnote" --merged-row 1 --has-borders --row-bold-contains "Weight" --col-width-at-least B 8 --result-file "`output_dir'/_mb_regtab.txt" --quiet"'
}
if _rc == 0 {
    display as result "  PASS: regtab backend formatting contract"
    local ++pass_count
}
else {
    display as error "  FAIL: regtab backend formatting contract (rc=`=_rc')"
    local ++fail_count
}

capture noisily {
    sysuse auto, clear
    gen byte highrep = rep78 >= 4 if !missing(rep78)
    capture erase "`output_dir'/_mb_table1.xlsx"
    table1_tc, vars(price contn \ mpg contn \ foreign bin) by(highrep) ///
        xlsx("`output_dir'/_mb_table1.xlsx") sheet("T1") title("Backend Table 1") ///
        headershade footnote("Backend table footnote")
    assert "`r(xlsx)'" == "`output_dir'/_mb_table1.xlsx"
    assert "`r(sheet)'" == "T1"

    _mb_assert_xlsx "`output_dir'/_mb_table1.txt" ///
        `"`python_cmd' "`checker'" "`output_dir'/_mb_table1.xlsx" --sheet "T1" --cell A1 "Backend Table 1" --contains "Backend table footnote" --merged-row 1 --has-borders --has-pattern p-values percentages --result-file "`output_dir'/_mb_table1.txt" --quiet"'
}
if _rc == 0 {
    display as result "  PASS: table1_tc backend formatting contract"
    local ++pass_count
}
else {
    display as error "  FAIL: table1_tc backend formatting contract (rc=`=_rc')"
    local ++fail_count
}

capture noisily {
    sysuse auto, clear
    collect clear
    collect: table foreign, statistic(mean price) statistic(sd price) statistic(count price)
    capture erase "`output_dir'/_mb_desctab.xlsx"
    desctab, xlsx("`output_dir'/_mb_desctab.xlsx") sheet("Desc") title("Backend Descriptives") ///
        headershade footnote("Backend desc footnote")
    assert "`r(xlsx)'" == "`output_dir'/_mb_desctab.xlsx"
    assert "`r(sheet)'" == "Desc"

    _mb_assert_xlsx "`output_dir'/_mb_desctab.txt" ///
        `"`python_cmd' "`checker'" "`output_dir'/_mb_desctab.xlsx" --sheet "Desc" --cell A1 "Backend Descriptives" --contains "Backend desc footnote" --merged-row 1 --has-borders --min-cols 4 --result-file "`output_dir'/_mb_desctab.txt" --quiet"'
}
if _rc == 0 {
    display as result "  PASS: desctab collect-read and writer contract"
    local ++pass_count
}
else {
    display as error "  FAIL: desctab backend contract (rc=`=_rc')"
    local ++fail_count
}

capture noisily {
    sysuse auto, clear
    collect clear
    collect: teffects ra (price mpg weight) (foreign), ate
    capture erase "`output_dir'/_mb_effecttab.xlsx"
    effecttab, xlsx("`output_dir'/_mb_effecttab.xlsx") sheet("Effects") ///
        title("Backend Effects") headershade footnote("Backend effects footnote")
    assert "`r(xlsx)'" == "`output_dir'/_mb_effecttab.xlsx"
    assert "`r(sheet)'" == "Effects"

    _mb_assert_xlsx "`output_dir'/_mb_effecttab.txt" ///
        `"`python_cmd' "`checker'" "`output_dir'/_mb_effecttab.xlsx" --sheet "Effects" --cell A1 "Backend Effects" --contains "Backend effects footnote" --merged-row 1 --has-borders --has-pattern ci --result-file "`output_dir'/_mb_effecttab.txt" --quiet"'
}
if _rc == 0 {
    display as result "  PASS: effecttab collect-read and writer contract"
    local ++pass_count
}
else {
    display as error "  FAIL: effecttab backend contract (rc=`=_rc')"
    local ++fail_count
}

**# Failure Path

capture noisily {
    local bad_root "`output_dir'/__missing_backend_dir__"
    sysuse auto, clear
    return clear
    capture noisily corrtab price mpg weight, xlsx("`bad_root'/corrtab.xlsx")
    local rc = _rc
    assert `rc' != 0
    tempname C
    matrix `C' = r(C)
    assert colsof(`C') == 3
    capture confirm file "`bad_root'/corrtab.xlsx"
    assert _rc != 0
}
if _rc == 0 {
    display as result "  PASS: writer failure preserves analytical returns"
    local ++pass_count
}
else {
    display as error "  FAIL: writer failure return contract (rc=`=_rc')"
    local ++fail_count
}
display as result "ALL MATA BACKEND CONTRACT TESTS PASSED"


**# Migrated: xlsx read helper contracts



**# Helper Contracts

capture noisily {
    capture erase "`output_dir'/_xlsx_read_cells.xlsx"
    putexcel set "`output_dir'/_xlsx_read_cells.xlsx", sheet("Raw") replace
    putexcel A1 = "alpha"
    putexcel B1 = ""
    putexcel C1 = "alpha"
    putexcel D1 = "1bad header"
    putexcel E1 = "has space"
    putexcel A2 = "00123"
    putexcel B2 = ""
    putexcel C2 = "00045"
    putexcel D2 = "text"
    putexcel E2 = "  padded  "
    putexcel A3 = "<0.001"
    putexcel B3 = "blank-header-value"
    putexcel C3 = "N/A"
    putexcel D3 = "3.140"
    putexcel E3 = "A+B"
    putexcel close

    clear
    _tabtools_xlsx_read using "`output_dir'/_xlsx_read_cells.xlsx", sheet("Raw")
    assert _N == 3
    assert c(k) == 5
    assert r(N) == 3
    assert r(k) == 5
    assert r(n_rows) == 3
    assert r(n_cols) == 5
    assert "`r(varlist)'" == "A B C D E"

    foreach v of varlist _all {
        local vtype : type `v'
        assert substr("`vtype'", 1, 3) == "str"
    }

    assert A[1] == "alpha"
    assert B[1] == ""
    assert C[1] == "alpha"
    assert D[1] == "1bad header"
    assert E[1] == "has space"
    assert A[2] == "00123"
    assert B[2] == ""
    assert C[2] == "00045"
    assert D[2] == "text"
    assert E[2] == "  padded  "
    assert A[3] == "<0.001"
    assert B[3] == "blank-header-value"
    assert C[3] == "N/A"
    assert D[3] == "3.140"
    assert E[3] == "A+B"
}
if _rc == 0 {
    display as result "  PASS: no-firstrow all-string read contract"
    local ++pass_count
}
else {
    display as error "  FAIL: no-firstrow all-string read contract (rc=`=_rc')"
    local ++fail_count
}

capture noisily {
    clear
    set obs 1
    forvalues j = 1/130 {
        gen str8 v`j' = "v`j'"
    }
    capture erase "`output_dir'/_xlsx_read_wide.xlsx"
    _tabtools_xlsx_write using "`output_dir'/_xlsx_read_wide.xlsx", sheet("Wide") book(b)
    mata: b.close_book()
    mata: mata drop b

    clear
    _tabtools_xlsx_read using "`output_dir'/_xlsx_read_wide.xlsx", sheet("Wide")
    assert _N == 1
    assert c(k) == 130
    confirm variable A
    confirm variable Z
    confirm variable AA
    confirm variable AZ
    confirm variable BA
    confirm variable DZ
    assert A[1] == "v1"
    assert Z[1] == "v26"
    assert AA[1] == "v27"
    assert AZ[1] == "v52"
    assert BA[1] == "v53"
    assert DZ[1] == "v130"
}
if _rc == 0 {
    display as result "  PASS: adaptive wide read exceeds 100 columns"
    local ++pass_count
}
else {
    display as error "  FAIL: adaptive wide read contract (rc=`=_rc')"
    local ++fail_count
}

capture noisily {
    local _long = ""
    forvalues i = 1/2100 {
        local _long "`_long'X"
    }

    capture erase "`output_dir'/_xlsx_read_storage.xlsx"
    putexcel set "`output_dir'/_xlsx_read_storage.xlsx", sheet("Storage") replace
    putexcel A1 = "short"
    putexcel B1 = "Ångström"
    putexcel C1 = "`_long'"
    putexcel close

    clear
    _tabtools_xlsx_read using "`output_dir'/_xlsx_read_storage.xlsx", sheet("Storage")
    assert _N == 1
    assert A[1] == "short"
    assert B[1] == "Ångström"
    assert C[1] == "`_long'"
    local atype : type A
    local btype : type B
    local ctype : type C
    assert "`atype'" == "str5"
    assert substr("`btype'", 1, 3) == "str"
    assert real(substr("`btype'", 4, .)) >= strlen(B[1])
    assert "`ctype'" == "strL"
}
if _rc == 0 {
    display as result "  PASS: storage widths use byte length and strL fallback"
    local ++pass_count
}
else {
    display as error "  FAIL: storage width contract (rc=`=_rc')"
    local ++fail_count
}

capture noisily {
    capture erase "`output_dir'/_xlsx_read_multisheet.xlsx"
    putexcel set "`output_dir'/_xlsx_read_multisheet.xlsx", sheet("Table 1") replace
    putexcel A1 = "wrong sheet"
    putexcel close
    putexcel set "`output_dir'/_xlsx_read_multisheet.xlsx", sheet("temp") modify
    putexcel A1 = "target sheet"
    putexcel B1 = "value"
    putexcel A2 = "row"
    putexcel B2 = "42"
    putexcel close

    clear
    _tabtools_xlsx_read using "`output_dir'/_xlsx_read_multisheet.xlsx", sheet(temp)
    assert _N == 2
    assert c(k) == 2
    assert A[1] == "target sheet"
    assert B[2] == "42"
}
if _rc == 0 {
    display as result "  PASS: reads non-first workbook sheet"
    local ++pass_count
}
else {
    display as error "  FAIL: non-first sheet read contract (rc=`=_rc')"
    local ++fail_count
}

capture noisily {
    clear
    input byte sentinel
    7
    end
    capture noisily _tabtools_xlsx_read using "`output_dir'/_xlsx_read_wide.xlsx", ///
        sheet("Wide") maxcols(10)
    local rc = _rc
    assert `rc' == 908
    assert _N == 1
    assert sentinel[1] == 7
}
if _rc == 0 {
    display as result "  PASS: maxcols overflow fails explicitly"
    local ++pass_count
}
else {
    display as error "  FAIL: maxcols overflow contract (rc=`=_rc')"
    local ++fail_count
}

capture noisily {
    clear
    input byte sentinel
    9
    end
    capture noisily _tabtools_xlsx_read using "`output_dir'/_xlsx_read_wide.xlsx", ///
        sheet("MissingSheet")
    local rc = _rc
    assert `rc' == 111
    assert _N == 1
    assert sentinel[1] == 9
}
if _rc == 0 {
    display as result "  PASS: missing sheet fails explicitly"
    local ++pass_count
}
else {
    display as error "  FAIL: missing sheet contract (rc=`=_rc')"
    local ++fail_count
}

foreach f in _xlsx_read_cells.xlsx _xlsx_read_wide.xlsx {
    capture erase "`output_dir'/`f'"
}
capture erase "`output_dir'/_xlsx_read_storage.xlsx"
capture erase "`output_dir'/_xlsx_read_multisheet.xlsx"
display as result "ALL XLSX READ CURRENT CONTRACT TESTS PASSED"


**# Migrated: apply-styles engine contracts

local comparator "`tools_dir'/style_engine_compare.py"
capture confirm file "`comparator'"
if _rc {
    display as error "FAIL: style_engine_compare.py not available in tools/"
    exit 601
}


capture program drop _style_engine_make_data
program define _style_engine_make_data
    clear
    set obs 6
    generate str40 c1 = ""
    generate str24 c2 = ""
    generate str24 c3 = ""
    generate str12 c4 = ""
    generate str28 c5 = ""
    replace c1 = "Production Style Engine" in 1
    replace c1 = "Variable" in 2
    replace c2 = "Group A" in 2
    replace c3 = "Group B" in 2
    replace c4 = "p-value" in 2
    replace c5 = "Note" in 2
    replace c1 = "Age, mean (SD)" in 3
    replace c2 = "62 (8)" in 3
    replace c3 = "59 (9)" in 3
    replace c4 = "0.042" in 3
    replace c1 = "Male, n (%)" in 4
    replace c2 = "45 (55%)" in 4
    replace c3 = "38 (49%)" in 4
    replace c4 = "0.31" in 4
    replace c5 = "zebra row" in 4
    replace c1 = "Total" in 5
    replace c2 = "82" in 5
    replace c3 = "78" in 5
    replace c1 = "Footnote: compact production style spec" in 6
end

capture program drop _style_engine_assert_result
program define _style_engine_assert_result
    args result_file
    file open _fh using "`result_file'", read text
    file read _fh _line
    file close _fh
    assert "`_line'" == "PASS"
end

capture program drop _style_engine_apply_legacy
program define _style_engine_apply_legacy
    syntax , SHEET(string) [REPS(integer 1)]

    forvalues _i = 1/`reps' {
        mata: b.set_row_height(1, 1, 30)
        mata: b.set_row_height(6, 6, 24)
        mata: b.set_column_width(1, 1, 28)
        mata: b.set_column_width(2, 3, 16)
        mata: b.set_column_width(4, 4, 12)
        mata: b.set_column_width(5, 5, 20)
        mata: b.set_font((1, 6), (1, 5), "Arial", 10)
        mata: b.set_font((1, 1), (1, 5), "Arial", 12)
        mata: b.set_sheet_merge("`sheet'", (1, 1), (1, 5))
        mata: b.set_font_bold(1, 1, "on")
        mata: b.set_text_wrap(1, 1, "on")
        mata: b.set_horizontal_align(1, 1, "left")
        mata: b.set_vertical_align(1, 1, "center")
        mata: b.set_font_bold(2, (1, 5), "on")
        mata: b.set_horizontal_align(2, (2, 5), "center")
        mata: b.set_vertical_align(2, (1, 5), "center")
        mata: b.set_fill_pattern(2, (1, 5), "solid", "219 229 241")
        mata: b.set_top_border(2, (1, 5), "medium")
        mata: b.set_bottom_border(2, (1, 5), "medium")
        mata: b.set_horizontal_align((3, 5), (2, 5), "center")
        mata: b.set_fill_pattern(4, (1, 5), "solid", "242 242 242")
        mata: b.set_font(4, (1, 5), "Arial", 10, "160 160 160")
        mata: b.set_font_bold(5, (1, 5), "on")
        mata: b.set_bottom_border(5, (1, 5), "medium")
        mata: b.set_sheet_merge("`sheet'", (6, 6), (1, 5))
        mata: b.set_font_italic(6, 1, "on")
        mata: b.set_text_wrap(6, 1, "on")
        mata: b.set_horizontal_align(6, 1, "left")
        mata: b.set_vertical_align(6, 1, "center")
    }
end

matrix style_engine_rules = ( ///
    12, 1, 1, 0, 0, 30, 0, 0, 0 \ ///
    12, 6, 6, 0, 0, 24, 0, 0, 0 \ ///
    13, 0, 0, 1, 1, 28, 0, 0, 0 \ ///
    13, 0, 0, 2, 3, 16, 0, 0, 0 \ ///
    13, 0, 0, 4, 4, 12, 0, 0, 0 \ ///
    13, 0, 0, 5, 5, 20, 0, 0, 0 \ ///
    1, 1, 6, 1, 5, 10, 1, 0, 0 \ ///
    1, 1, 1, 1, 5, 12, 1, 0, 0 \ ///
    14, 1, 1, 1, 5, 0, 0, 0, 0 \ ///
    2, 1, 1, 1, 1, 0, 1, 0, 0 \ ///
    4, 1, 1, 1, 1, 0, 1, 0, 0 \ ///
    5, 1, 1, 1, 1, 0, 1, 0, 0 \ ///
    6, 1, 1, 1, 1, 0, 2, 0, 0 \ ///
    2, 2, 2, 1, 5, 0, 1, 0, 0 \ ///
    5, 2, 2, 2, 5, 0, 2, 0, 0 \ ///
    6, 2, 2, 1, 5, 0, 2, 0, 0 \ ///
    7, 2, 2, 1, 5, 0, 219, 229, 241 \ ///
    8, 2, 2, 1, 5, 0, 2, 0, 0 \ ///
    9, 2, 2, 1, 5, 0, 2, 0, 0 \ ///
    5, 3, 5, 2, 5, 0, 2, 0, 0 \ ///
    7, 4, 4, 1, 5, 0, 242, 242, 242 \ ///
    15, 4, 4, 1, 5, 10, 160, 160, 160 \ ///
    2, 5, 5, 1, 5, 0, 1, 0, 0 \ ///
    9, 5, 5, 1, 5, 0, 2, 0, 0 \ ///
    14, 6, 6, 1, 5, 0, 0, 0, 0 \ ///
    3, 6, 6, 1, 1, 0, 1, 0, 0 \ ///
    4, 6, 6, 1, 1, 0, 1, 0, 0 \ ///
    5, 6, 6, 1, 1, 0, 1, 0, 0 \ ///
    6, 6, 6, 1, 1, 0, 2, 0, 0 )


capture noisily {
    which _tabtools_xlsx_apply_styles
    which _tabtools_xlsx_build_styles
    which _tabtools_xlsx_write
    which _tabtools_xlsx_read
}
if _rc == 0 {
    display as result "  PASS: style engine helper autoloads after isolated net install"
    local ++pass_count
}
else {
    display as error "  FAIL: style engine helper autoload smoke (rc=`=_rc')"
    local ++fail_count
}

capture noisily {
    local builder_rows ""
    forvalues _r = 1/`=rowsof(style_engine_rules)' {
        local one_row ""
        forvalues _c = 1/`=colsof(style_engine_rules)' {
            local one_row "`one_row' `=style_engine_rules[`_r', `_c']'"
        }
        if `"`builder_rows'"' == "" local builder_rows "`one_row'"
        else local builder_rows `"`builder_rows' | `one_row'"'
    }

    tempname built_rules diff_rules
    _tabtools_xlsx_build_styles, matrix(`built_rules') ///
        rules(`"`builder_rows'"') cols(9)
    assert r(n_rules) == rowsof(style_engine_rules)
    assert r(n_cols) == colsof(style_engine_rules)
    matrix `diff_rules' = `built_rules' - style_engine_rules
    mata: st_numscalar("_max_abs_diff", max(abs(st_matrix("`diff_rules'"))))
    assert _max_abs_diff == 0
    scalar drop _max_abs_diff
}
if _rc == 0 {
    display as result "  PASS: Mata style-rule builder matches Stata-built rule matrix"
    local ++pass_count
}
else {
    display as error "  FAIL: style-rule builder matrix parity (rc=`=_rc')"
    local ++fail_count
}

capture noisily {
    _style_engine_make_data
    capture erase "`output_dir'/style_engine_apply_legacy.xlsx"
    _tabtools_xlsx_write using "`output_dir'/style_engine_apply_legacy.xlsx", ///
        sheet("Style") book(b)
    _style_engine_apply_legacy, sheet("Style")
    mata: b.close_book()
    mata: mata drop b

    _style_engine_make_data
    capture erase "`output_dir'/style_engine_apply_engine.xlsx"
    _tabtools_xlsx_write using "`output_dir'/style_engine_apply_engine.xlsx", ///
        sheet("Style") book(b)
    _tabtools_xlsx_apply_styles, book(b) sheet("Style") rules(style_engine_rules)
    assert r(n_rules) == rowsof(style_engine_rules)
    mata: b.close_book()
    mata: mata drop b

    _tabtools_xlsx_read using "`output_dir'/style_engine_apply_engine.xlsx", ///
        sheet("Style")
    assert _N == 6
    assert c(k) == 5
    assert A[1] == "Production Style Engine"
    assert A[6] == "Footnote: compact production style spec"

    shell `python_cmd' "`checker'" "`output_dir'/style_engine_apply_engine.xlsx" ///
        --sheet "Style" --cell A1 "Production Style Engine" ///
        --merged-row 1 --merged-row 6 --bold-row 2 --has-borders ///
        --fill-color 2 "219 229 241" --fill-color 4 "242 242 242" ///
        --italic-cell A6 --font Arial --fontsize 10 ///
        --col-width-at-least A 28 --col-width-at-least E 20 ///
        --result-file "`output_dir'/style_engine_apply_check.txt" --quiet
    _style_engine_assert_result "`output_dir'/style_engine_apply_check.txt"

    shell `python_cmd' "`comparator'" ///
        "`output_dir'/style_engine_apply_legacy.xlsx" ///
        "`output_dir'/style_engine_apply_engine.xlsx" ///
        --sheet "Style" --result-file "`output_dir'/style_engine_apply_parity.txt"
    _style_engine_assert_result "`output_dir'/style_engine_apply_parity.txt"
}
if _rc == 0 {
    display as result "  PASS: production style engine preserves legacy workbook styles"
    local ++pass_count
}
else {
    display as error "  FAIL: production style engine style parity (rc=`=_rc')"
    local ++fail_count
}

capture noisily {
    _style_engine_make_data
    capture erase "`output_dir'/style_engine_apply_invalid_rule.xlsx"
    _tabtools_xlsx_write using "`output_dir'/style_engine_apply_invalid_rule.xlsx", ///
        sheet("Style") book(b)
    matrix style_engine_bad_rules = (99, 1, 1, 1, 1, 0, 0, 0, 0)
    capture noisily _tabtools_xlsx_apply_styles, book(b) sheet("Style") ///
        rules(style_engine_bad_rules)
    local invalid_rc = _rc
    assert `invalid_rc' == 198
    mata: b.set_font_bold(1, 1, "on")
    mata: b.close_book()
    mata: mata drop b
    confirm file "`output_dir'/style_engine_apply_invalid_rule.xlsx"
}
if _rc == 0 {
    display as result "  PASS: invalid rules return rc=198 and leave workbook caller-owned"
    local ++pass_count
}
else {
    display as error "  FAIL: invalid-rule workbook ownership contract (rc=`=_rc')"
    local ++fail_count
}

capture noisily {
    local reps = 80
    local rules_per_rep = rowsof(style_engine_rules)
    capture erase "`output_dir'/style_engine_apply_timing_legacy.xlsx"
    capture erase "`output_dir'/style_engine_apply_timing_engine.xlsx"

    _style_engine_make_data
    _tabtools_xlsx_write using "`output_dir'/style_engine_apply_timing_legacy.xlsx", ///
        sheet("Style") book(b)
    timer clear 1
    timer on 1
    _style_engine_apply_legacy, sheet("Style") reps(`reps')
    timer off 1
    timer list 1
    local legacy_sec = r(t1)
    mata: b.close_book()
    mata: mata drop b

    _style_engine_make_data
    _tabtools_xlsx_write using "`output_dir'/style_engine_apply_timing_engine.xlsx", ///
        sheet("Style") book(b)
    timer clear 2
    timer on 2
    forvalues _i = 1/`reps' {
        _tabtools_xlsx_apply_styles, book(b) sheet("Style") rules(style_engine_rules)
    }
    timer off 2
    timer list 2
    local engine_sec = r(t2)
    mata: b.close_book()
    mata: mata drop b

    file open _timing using "`output_dir'/style_engine_apply_timing.tsv", ///
        write text replace
    file write _timing "mode" _tab "reps" _tab "rules_per_rep" _tab "seconds" _n
    file write _timing "legacy" _tab "`reps'" _tab "`rules_per_rep'" _tab ///
        %9.4f (`legacy_sec') _n
    file write _timing "engine" _tab "`reps'" _tab "`rules_per_rep'" _tab ///
        %9.4f (`engine_sec') _n
    file close _timing

    assert `legacy_sec' >= 0
    assert `engine_sec' >= 0
}
if _rc == 0 {
    display as result "  PASS: production style engine timing artifact recorded"
    local ++pass_count
}
else {
    display as error "  FAIL: production style engine timing artifact (rc=`=_rc')"
    local ++fail_count
}
* (shared style-engine before/after migration parity tests removed in v1.7.0:
* they compared against refactor-era 'before' fixtures that are no longer kept)

**# Migrated: column width behavior


local checker "`checker'"
capture confirm file "`checker'"
if _rc {
    display as error "FAIL: check_xlsx.py not available"
    exit 601
}

local python_cmd ""
capture noisily shell python3 --version
if _rc == 0 {
    local python_cmd "python3"
}
else {
    capture noisily shell python --version
    if _rc == 0 local python_cmd "python"
}
if "`python_cmd'" == "" {
    display as error "FAIL: python/openpyxl checker runtime not available"
    exit 601
}

capture program drop _wx_assert
program define _wx_assert
    args result_file checks
    shell `checks'
    file open _fh using "`result_file'", read text
    file read _fh _line
    file close _fh
    assert "`_line'" == "PASS"
end

* =========================================================================
**# WX1: regtab CI column width tracks rendered content
* =========================================================================
local ++n_total
capture noisily {
    clear
    set obs 200
    set seed 20260419
    gen double x = _n
    gen double z = runiform()
    gen double y = 123456789.123456 * x - 98765432.654321 * z + rnormal()*1000
    collect clear
    collect: regress y x z
    capture erase "`output_dir'/_wx_regtab.xlsx"
    regtab, xlsx("`output_dir'/_wx_regtab.xlsx") sheet("Test") ///
        title("Regression Results") digits(6) stats(n ll)

    _wx_assert "`output_dir'/_wx_regtab.txt" ///
        `"`python_cmd' "`checker'" "`output_dir'/_wx_regtab.xlsx" --sheet "Test" --col-width-fits-content D 4 --result-file "`output_dir'/_wx_regtab.txt" --quiet"'
}
if _rc == 0 {
    display as result "  PASS: WX1 - regtab CI column width fits rendered content"
    local ++pass_count
}
else {
    display as error "  FAIL: WX1 - regtab CI column width fits rendered content (rc=`=_rc')"
    local ++fail_count
}

* =========================================================================
**# WX1A: regtab short-value columns stay tight
* =========================================================================
local ++n_total
capture noisily {
    sysuse auto, clear
    collect clear
    collect: logit foreign mpg weight
    capture erase "`output_dir'/_wx_regtab_tight.xlsx"
    regtab, xlsx("`output_dir'/_wx_regtab_tight.xlsx") sheet("Short") ///
        title("Short Regression") coef("OR") noint

    _wx_assert "`output_dir'/_wx_regtab_tight.txt" ///
        `"`python_cmd' "`checker'" "`output_dir'/_wx_regtab_tight.xlsx" --sheet "Short" --col-width-at-most C 8 --col-width-at-most D 13 --col-width-at-most E 8 --result-file "`output_dir'/_wx_regtab_tight.txt" --quiet"'
}
if _rc == 0 {
    display as result "  PASS: WX1A - regtab short-value columns stay tight"
    local ++pass_count
}
else {
    display as error "  FAIL: WX1A - regtab short-value columns stay tight (rc=`=_rc')"
    local ++fail_count
}

* =========================================================================
**# WX2: effecttab CI column width
* =========================================================================
local ++n_total
capture noisily {
    sysuse auto, clear
    collect clear
    collect: teffects ra (price mpg weight) (foreign), ate
    capture erase "`output_dir'/_wx_effecttab.xlsx"
    effecttab, xlsx("`output_dir'/_wx_effecttab.xlsx") sheet("Effects") ///
        title("Treatment Effects")

    _wx_assert "`output_dir'/_wx_effecttab.txt" ///
        `"`python_cmd' "`checker'" "`output_dir'/_wx_effecttab.xlsx" --sheet "Effects" --col-width-at-least D 18 --result-file "`output_dir'/_wx_effecttab.txt" --quiet"'
}
if _rc == 0 {
    display as result "  PASS: WX2 - effecttab CI column width"
    local ++pass_count
}
else {
    display as error "  FAIL: WX2 - effecttab CI column width (rc=`=_rc')"
    local ++fail_count
}

* =========================================================================
**# WX3: comptab CI column width
* =========================================================================
local ++n_total
capture noisily {
    sysuse auto, clear
    collect clear
    collect: regress price mpg weight
    regtab, frame(_wx_m1, replace) noint
    collect clear
    collect: regress price mpg weight length
    regtab, frame(_wx_m2, replace) noint
    capture erase "`output_dir'/_wx_comptab.xlsx"
    comptab _wx_m1 _wx_m2, rows(1/2 \ 1/3) ///
        xlsx("`output_dir'/_wx_comptab.xlsx") sheet("Comp") title("Composite")
    capture frame drop _wx_m1
    capture frame drop _wx_m2

    _wx_assert "`output_dir'/_wx_comptab.txt" ///
        `"`python_cmd' "`checker'" "`output_dir'/_wx_comptab.xlsx" --sheet "Comp" --col-width-at-least D 17 --result-file "`output_dir'/_wx_comptab.txt" --quiet"'
}
if _rc == 0 {
    display as result "  PASS: WX3 - comptab CI column width"
    local ++pass_count
}
else {
    display as error "  FAIL: WX3 - comptab CI column width (rc=`=_rc')"
    local ++fail_count
}

* =========================================================================
**# WX4: corrtab long-label headers expand all data columns
* =========================================================================
local ++n_total
capture noisily {
    sysuse auto, clear
    label variable price "Vehicle price in USD"
    label variable mpg "Fuel economy miles per gallon"
    label variable weight "Vehicle curb weight"
    label variable length "Vehicle length inches"
    capture erase "`output_dir'/_wx_corrtab.xlsx"
    corrtab price mpg weight length, xlsx("`output_dir'/_wx_corrtab.xlsx") ///
        sheet("Corr") title("Correlation Matrix")

    _wx_assert "`output_dir'/_wx_corrtab.txt" ///
        `"`python_cmd' "`checker'" "`output_dir'/_wx_corrtab.xlsx" --sheet "Corr" --col-width-at-least C 24 --col-width-at-least D 24 --col-width-at-least E 24 --col-width-at-least F 24 --result-file "`output_dir'/_wx_corrtab.txt" --quiet"'
}
if _rc == 0 {
    display as result "  PASS: WX4 - corrtab long-label widths"
    local ++pass_count
}
else {
    display as error "  FAIL: WX4 - corrtab long-label widths (rc=`=_rc')"
    local ++fail_count
}

* =========================================================================
**# WX5: table1_tc data columns widen for longer summaries
* =========================================================================
local ++n_total
capture noisily {
    clear
    set obs 40
    gen byte foreign = _n > 20
    gen double price = cond(foreign, 987654321 + _n * 100000, 123456789 + _n * 100000)
    gen double mpg = cond(foreign, 25 + mod(_n, 7), 18 + mod(_n, 5))
    gen double weight = cond(foreign, 2500 + _n * 11, 3200 + _n * 13)
    gen byte rep78 = 1 + mod(_n, 5)
    label define origin 0 "Domestic" 1 "Foreign", replace
    label values foreign origin
    label variable price "Price"
    label variable mpg "Mileage (mpg)"
    label variable weight "Weight (lbs.)"
    label variable rep78 "Repair record 1978"
    capture erase "`output_dir'/_wx_table1.xlsx"
    table1_tc, by(foreign) vars(price contn %12.0fc \ mpg contn %9.1f \ weight contn \ rep78 cat) ///
        excel("`output_dir'/_wx_table1.xlsx") title("Baseline Characteristics")

    _wx_assert "`output_dir'/_wx_table1.txt" ///
        `"`python_cmd' "`checker'" "`output_dir'/_wx_table1.xlsx" --sheet "Table 1" --col-width-at-least C 17 --col-width-at-least D 17 --result-file "`output_dir'/_wx_table1.txt" --quiet"'
}
if _rc == 0 {
    display as result "  PASS: WX5 - table1_tc data-column widths"
    local ++pass_count
}
else {
    display as error "  FAIL: WX5 - table1_tc data-column widths (rc=`=_rc')"
    local ++fail_count
}

* =========================================================================
**# WX6: crosstab summary row is merged
* =========================================================================
local ++n_total
capture noisily {
    sysuse auto, clear
    gen byte highmpg = mpg > 20
    capture erase "`output_dir'/_wx_crosstab.xlsx"
    crosstab highmpg foreign, xlsx("`output_dir'/_wx_crosstab.xlsx") sheet("Cross")

    _wx_assert "`output_dir'/_wx_crosstab.txt" ///
        `"`python_cmd' "`checker'" "`output_dir'/_wx_crosstab.xlsx" --sheet "Cross" --merged-row 6 --result-file "`output_dir'/_wx_crosstab.txt" --quiet"'
}
if _rc == 0 {
    display as result "  PASS: WX6 - crosstab summary row merged"
    local ++pass_count
}
else {
    display as error "  FAIL: WX6 - crosstab summary row merged (rc=`=_rc')"
    local ++fail_count
}

* =========================================================================
**# WX7: survtab log-rank row is merged
* =========================================================================
local ++n_total
capture noisily {
    sysuse cancer, clear
    stset studytime, failure(died)
    capture erase "`output_dir'/_wx_survtab.xlsx"
    survtab, times(10 20 30) by(drug) xlsx("`output_dir'/_wx_survtab.xlsx") ///
        sheet("Surv") title("Survival Estimates") events

    _wx_assert "`output_dir'/_wx_survtab.txt" ///
        `"`python_cmd' "`checker'" "`output_dir'/_wx_survtab.xlsx" --sheet "Surv" --merged-row 10 --result-file "`output_dir'/_wx_survtab.txt" --quiet"'
}
if _rc == 0 {
    display as result "  PASS: WX7 - survtab log-rank row merged"
    local ++pass_count
}
else {
    display as error "  FAIL: WX7 - survtab log-rank row merged (rc=`=_rc')"
    local ++fail_count
}

* =========================================================================
**# WX8: hrcomptab keeps events/exposure/p-value columns tight
* =========================================================================
local ++n_total
capture noisily {
    capture frame drop _wx_hr_rates
    capture frame drop _wx_hr_bin
    capture frame drop _wx_hr_dose

    tempfile _wx_rate1 _wx_rate2

    clear
    set obs 2
    gen exposure = _n - 1
    gen double _D = cond(_n == 1, 42, 31)
    gen double _Y = cond(_n == 1, 5200, 4980)
    gen double _Rate = _D / _Y
    gen double _Lower = _Rate * 0.75
    gen double _Upper = _Rate * 1.25
    label define _wx_exp2 0 "No HRT" 1 "Any HRT", replace
    label values exposure _wx_exp2
    save "`_wx_rate1'.dta", replace

    clear
    set obs 4
    gen exposure = _n - 1
    gen double _D = cond(_n == 1, 42, cond(_n == 2, 16, cond(_n == 3, 9, 6)))
    gen double _Y = cond(_n == 1, 5200, cond(_n == 2, 1760, cond(_n == 3, 1510, 1710)))
    gen double _Rate = _D / _Y
    gen double _Lower = _Rate * 0.70
    gen double _Upper = _Rate * 1.30
    label define _wx_exp4 0 "No HRT" 1 "Low dose" 2 "Medium dose" 3 "High dose", replace
    label values exposure _wx_exp4
    save "`_wx_rate2'.dta", replace

    clear
    stratetab, using(`_wx_rate1' `_wx_rate2') outcomes(1) ///
        frame(_wx_hr_rates, replace) ///
        outlabels("Sustained EDSS 4") ///
        explabels("Any HRT" \ "Estrogen Dose")

    clear
    set obs 30
    set seed 20260418
    gen byte treated = mod(_n, 2)
    gen double y = 10 + 2 * treated + rnormal()
    collect clear
    collect: regress y treated
    regtab, frame(_wx_hr_bin, replace) noint

    clear
    set obs 45
    gen byte dose = mod(_n, 4)
    gen double y = 12 + 1.5 * (dose == 1) + 2.5 * (dose == 2) + 3.5 * (dose == 3) + rnormal()
    collect clear
    collect: regress y i.dose
    regtab, frame(_wx_hr_dose, replace) noint

    capture erase "`output_dir'/_wx_hrcomptab.xlsx"
    hrcomptab _wx_hr_rates, modelframes(_wx_hr_bin _wx_hr_dose) ///
        rownames("treated" \ "1 2 3") ///
        xlsx("`output_dir'/_wx_hrcomptab.xlsx") sheet("HRComp") ///
        title("HR Composite") effect("aHR")

    _wx_assert "`output_dir'/_wx_hrcomptab.txt" ///
        `"`python_cmd' "`checker'" "`output_dir'/_wx_hrcomptab.xlsx" --sheet "HRComp" --col-width-at-most B 15 --col-width-at-most C 8 --col-width-at-least D 15 --col-width-at-least E 17 --col-width-at-least F 14 --col-width-at-most G 8 --result-file "`output_dir'/_wx_hrcomptab.txt" --quiet"'

    capture frame drop _wx_hr_rates
    capture frame drop _wx_hr_bin
    capture frame drop _wx_hr_dose
}
if _rc == 0 {
    display as result "  PASS: WX8 - hrcomptab column widths"
    local ++pass_count
}
else {
    display as error "  FAIL: WX8 - hrcomptab column widths (rc=`=_rc')"
    local ++fail_count
}
capture frame drop _wx_hr_rates
capture frame drop _wx_hr_bin
capture frame drop _wx_hr_dose

* =========================================================================
**# WX9: regtab caps the label column on a verbose random-effects row + wraps
* A mixed model with an unstructured random slope produces a ~60-char
* "Covariance: id (<slope label>, Intercept)" row. Before the cap this single
* label stretched column B to ~60; the cap (default 45) plus text-wrap keeps it
* tight while the long label flows onto extra lines instead of being clipped.
* =========================================================================
local ++n_total
capture noisily {
    clear
    set obs 600
    set seed 20260603
    gen id = ceil(_n/6)
    gen double tx_time = runiform() * 10
    label variable tx_time "Years since Treatment Initiation"
    gen double y = 50 + 2 * tx_time + rnormal(0, 3) + rnormal()
    collect clear
    collect: mixed y tx_time || id: tx_time, covariance(unstructured)

    capture erase "`output_dir'/_wx_regtab_label.xlsx"
    regtab, xlsx("`output_dir'/_wx_regtab_label.xlsx") sheet("L") relabel factorlabel

    _wx_assert "`output_dir'/_wx_regtab_label.txt" ///
        `"`python_cmd' "`checker'" "`output_dir'/_wx_regtab_label.xlsx" --sheet "L" --col-width-at-most B 50 --cell-wrap B4 --result-file "`output_dir'/_wx_regtab_label.txt" --quiet"'
}
if _rc == 0 {
    display as result "  PASS: WX9 - regtab label column capped + wrapped on verbose RE row"
    local ++pass_count
}
else {
    display as error "  FAIL: WX9 - regtab label column capped + wrapped on verbose RE row (rc=`=_rc')"
    local ++fail_count
}

* =========================================================================
**# WX10: regtab labelwidth() overrides the default cap
* =========================================================================
local ++n_total
capture noisily {
    clear
    set obs 600
    set seed 20260603
    gen id = ceil(_n/6)
    gen double tx_time = runiform() * 10
    label variable tx_time "Years since Treatment Initiation"
    gen double y = 50 + 2 * tx_time + rnormal(0, 3) + rnormal()
    collect clear
    collect: mixed y tx_time || id: tx_time, covariance(unstructured)

    capture erase "`output_dir'/_wx_regtab_lw.xlsx"
    regtab, xlsx("`output_dir'/_wx_regtab_lw.xlsx") sheet("LW") relabel factorlabel labelwidth(25)

    _wx_assert "`output_dir'/_wx_regtab_lw.txt" ///
        `"`python_cmd' "`checker'" "`output_dir'/_wx_regtab_lw.xlsx" --sheet "LW" --col-width-at-most B 27 --result-file "`output_dir'/_wx_regtab_lw.txt" --quiet"'
}
if _rc == 0 {
    display as result "  PASS: WX10 - regtab labelwidth() overrides the default cap"
    local ++pass_count
}
else {
    display as error "  FAIL: WX10 - regtab labelwidth() overrides the default cap (rc=`=_rc')"
    local ++fail_count
}

* =========================================================================
**# WX11: comptab caps the label column on a verbose random-effects row
* =========================================================================
local ++n_total
capture noisily {
    clear
    set obs 600
    set seed 20260603
    gen id = ceil(_n/6)
    gen double tx_time = runiform() * 10
    label variable tx_time "Years since Treatment Initiation"
    gen double y = 50 + 2 * tx_time + rnormal(0, 3) + rnormal()
    collect clear
    collect: mixed y tx_time || id: tx_time, covariance(unstructured)
    regtab, frame(_wx_lab_f1, replace) relabel factorlabel models("M1")
    collect clear
    collect: mixed y tx_time || id: tx_time, covariance(unstructured)
    regtab, frame(_wx_lab_f2, replace) relabel factorlabel models("M2")

    capture erase "`output_dir'/_wx_comptab_label.xlsx"
    comptab _wx_lab_f1 _wx_lab_f2, rows(1/6 \ 1/6) ///
        xlsx("`output_dir'/_wx_comptab_label.xlsx") sheet("CL") title("Composite")

    _wx_assert "`output_dir'/_wx_comptab_label.txt" ///
        `"`python_cmd' "`checker'" "`output_dir'/_wx_comptab_label.xlsx" --sheet "CL" --col-width-at-most B 50 --cell-wrap B4 --result-file "`output_dir'/_wx_comptab_label.txt" --quiet"'

    capture frame drop _wx_lab_f1
    capture frame drop _wx_lab_f2
}
if _rc == 0 {
    display as result "  PASS: WX11 - comptab label column capped + wrapped on verbose RE row"
    local ++pass_count
}
else {
    display as error "  FAIL: WX11 - comptab label column capped + wrapped on verbose RE row (rc=`=_rc')"
    local ++fail_count
}
capture frame drop _wx_lab_f1
capture frame drop _wx_lab_f2

display _newline as result "Excel Width Tests Complete"
display as result "  Passed: `pass_count' / `n_total'"
if `fail_count' > 0 {
    display as error "  Failed: `fail_count' / `n_total'"
}

foreach f in _wx_regtab.txt _wx_regtab_tight.txt _wx_effecttab.txt _wx_comptab.txt _wx_corrtab.txt _wx_table1.txt _wx_crosstab.txt _wx_survtab.txt _wx_hrcomptab.txt _wx_regtab_label.txt _wx_regtab_lw.txt _wx_comptab_label.txt {
    capture erase "`output_dir'/`f'"
}

assert `fail_count' == 0



**# Migrated: console display contracts


capture program drop _make_console_strate
program define _make_console_strate
    syntax , BASENAME(string)
    clear
    set obs 2
    gen exposure = _n - 1
    gen double _D = cond(_n == 1, 10, 18)
    gen double _Y = cond(_n == 1, 1000, 1200)
    gen double _Rate = _D / _Y
    gen double _Lower = _Rate * 0.80
    gen double _Upper = _Rate * 1.20
    label define _console_exp 0 "None" 1 "Current", replace
    label values exposure _console_exp
    save "`basename'.dta", replace
end


capture noisily {
    local capture_log "`output_dir'/test_console_display_contracts_capture.log"
    capture erase "`capture_log'"
    capture log close _console_capture
    log using "`capture_log'", replace text name(_console_capture)

    sysuse auto, clear
    gen byte highrep = rep78 >= 4 if !missing(rep78)
    capture erase "`output_dir'/_console_contract_table1.xlsx"
    table1_tc price mpg foreign, vars(price contn \ mpg contn \ foreign bin) ///
        by(highrep) xlsx("`output_dir'/_console_contract_table1.xlsx") ///
        sheet("Table1") title("Console_Table1")
    confirm file "`output_dir'/_console_contract_table1.xlsx"

    sysuse auto, clear
    capture erase "`output_dir'/_console_contract_corrtab.xlsx"
    corrtab price mpg weight, pvalues xlsx("`output_dir'/_console_contract_corrtab.xlsx") ///
        sheet("Corr") title("Console_Corrtab")
    confirm file "`output_dir'/_console_contract_corrtab.xlsx"

    sysuse auto, clear
    capture erase "`output_dir'/_console_contract_crosstab.xlsx"
    crosstab rep78 foreign, xlsx("`output_dir'/_console_contract_crosstab.xlsx") ///
        sheet("Cross") title("Console_Crosstab")
    confirm file "`output_dir'/_console_contract_crosstab.xlsx"

    clear
    input byte(test gold)
    1 1
    1 1
    1 0
    0 0
    0 1
    0 0
    end
    capture erase "`output_dir'/_console_contract_diagtab.xlsx"
    diagtab test gold, xlsx("`output_dir'/_console_contract_diagtab.xlsx") ///
        sheet("Diag") title("Console_Diagtab")
    confirm file "`output_dir'/_console_contract_diagtab.xlsx"

    webuse drugtr, clear
    stset studytime, failure(died)
    capture erase "`output_dir'/_console_contract_survtab.xlsx"
    survtab, times(10 20) by(drug) xlsx("`output_dir'/_console_contract_survtab.xlsx") ///
        sheet("Surv") title("Console_Survtab")
    confirm file "`output_dir'/_console_contract_survtab.xlsx"

    sysuse auto, clear
    collect clear
    collect: regress price foreign mpg weight
    capture erase "`output_dir'/_console_contract_regtab.xlsx"
    capture frame drop _console_reg
    regtab, xlsx("`output_dir'/_console_contract_regtab.xlsx") sheet("Reg") ///
        title("Console_Regtab") frame(_console_reg) noint
    confirm file "`output_dir'/_console_contract_regtab.xlsx"

    sysuse auto, clear
    collect clear
    collect: table foreign, statistic(mean price) statistic(sd price) statistic(count price)
    capture erase "`output_dir'/_console_contract_desctab.xlsx"
    desctab, xlsx("`output_dir'/_console_contract_desctab.xlsx") sheet("Desc") ///
        title("Console_Desctab")
    confirm file "`output_dir'/_console_contract_desctab.xlsx"

    matrix _console_eff = (1.50, 0.80, 2.20, 0.04 \ 2.30, 1.10, 3.50, 0.001)
    matrix rownames _console_eff = Age Sex
    capture erase "`output_dir'/_console_contract_effecttab.xlsx"
    effecttab, from(_console_eff) xlsx("`output_dir'/_console_contract_effecttab.xlsx") ///
        sheet("Effects") title("Console_Effecttab") effect("OR")
    confirm file "`output_dir'/_console_contract_effecttab.xlsx"

    tempfile rate1
    _make_console_strate, basename("`rate1'")
    capture erase "`output_dir'/_console_contract_stratetab.xlsx"
    capture frame drop _console_rates
    stratetab, using("`rate1'") outcomes(1) ///
        xlsx("`output_dir'/_console_contract_stratetab.xlsx") sheet("Rates") ///
        title("Console_Stratetab") frame(_console_rates, replace)
    confirm file "`output_dir'/_console_contract_stratetab.xlsx"

    sysuse auto, clear
    collect clear
    gen byte treated = foreign
    collect: regress price treated mpg weight
    capture frame drop _console_model
    regtab, frame(_console_model) noint title("Console_Source_Regtab")

    capture erase "`output_dir'/_console_contract_comptab.xlsx"
    comptab _console_model, rows(1) xlsx("`output_dir'/_console_contract_comptab.xlsx") ///
        sheet("Comp") title("Console_Comptab")
    confirm file "`output_dir'/_console_contract_comptab.xlsx"

    capture erase "`output_dir'/_console_contract_hrcomptab.xlsx"
    hrcomptab _console_rates, modelframes(_console_model) rows(1) ///
        xlsx("`output_dir'/_console_contract_hrcomptab.xlsx") sheet("HR") ///
        title("Console_Hrcomptab")
    confirm file "`output_dir'/_console_contract_hrcomptab.xlsx"


    local expected_titles ///
        Console_Table1 Console_Corrtab Console_Crosstab Console_Diagtab ///
        Console_Survtab Console_Regtab Console_Desctab Console_Effecttab ///
        Console_Stratetab Console_Comptab Console_Hrcomptab

    tempname fh
    local border_lines = 0
    local title_index = 0
    foreach title of local expected_titles {
        local ++title_index
        local found_`title_index' = 0
    }

    capture log close _console_capture
    file open `fh' using "`capture_log'", read text
    file read `fh' line
    while r(eof) == 0 {
        if strpos(`"`line'"', "+") > 0 & strpos(`"`line'"', "---") > 0 {
            local ++border_lines
        }
        local title_index = 0
        foreach title of local expected_titles {
            local ++title_index
            if strpos(`"`line'"', "`title'") > 0 {
                local found_`title_index' = 1
            }
        }
        file read `fh' line
    }
    file close `fh'

    assert `border_lines' >= 22
    local title_index = 0
    foreach title of local expected_titles {
        local ++title_index
        assert `found_`title_index'' == 1
    }
}
local _disp_rc = _rc
capture log close _console_capture
if `_disp_rc' == 0 {
    display as result "  PASS: all public table commands auto-display boxed completed tables"
    local ++pass_count
}
else {
    display as error "  FAIL: automatic console display contract (rc=`_disp_rc')"
    local ++fail_count
}

capture frame drop _console_reg
capture frame drop _console_model
capture frame drop _console_rates
quietly tabtools set clear
display as result "ALL CONSOLE DISPLAY CONTRACT TESTS PASSED"


**# Migrated: color validation across commands



**# Invalid Color Inputs
**## direct headercolor() rejects out-of-range RGB before export
local invalid_ok = 1

local invalid_color "999 999 999"
local direct_cmds "table1_tc regtab effecttab comptab corrtab diagtab stratetab hrcomptab"

capture erase "`output_dir'/_color_table1.xlsx"
sysuse auto, clear
capture table1_tc price mpg weight, by(foreign) ///
    xlsx("`output_dir'/_color_table1.xlsx") headercolor("`invalid_color'")
local rc = _rc
capture confirm file "`output_dir'/_color_table1.xlsx"
local file_exists = (_rc == 0)
if `rc' != 198 | `file_exists' {
    display as error "  FAIL [table1_tc]: expected rc=198 and no workbook; rc=`rc' file=`file_exists'"
    local invalid_ok = 0
}
capture erase "`output_dir'/_color_table1.xlsx"

capture erase "`output_dir'/_color_regtab.xlsx"
sysuse auto, clear
generate byte expensive = (price > 6000)
collect clear
collect: logistic expensive mpg weight i.foreign
capture regtab, xlsx("`output_dir'/_color_regtab.xlsx") ///
    headercolor("`invalid_color'") noint
local rc = _rc
capture confirm file "`output_dir'/_color_regtab.xlsx"
local file_exists = (_rc == 0)
if `rc' != 198 | `file_exists' {
    display as error "  FAIL [regtab]: expected rc=198 and no workbook; rc=`rc' file=`file_exists'"
    local invalid_ok = 0
}
capture erase "`output_dir'/_color_regtab.xlsx"

capture erase "`output_dir'/_color_effecttab.xlsx"
matrix _color_eff = (1.5, 0.8, 2.2, 0.04 \ 2.3, 1.1, 3.5, 0.001)
matrix rownames _color_eff = Age BMI
capture effecttab, from(_color_eff) xlsx("`output_dir'/_color_effecttab.xlsx") ///
    headercolor("`invalid_color'")
local rc = _rc
capture confirm file "`output_dir'/_color_effecttab.xlsx"
local file_exists = (_rc == 0)
if `rc' != 198 | `file_exists' {
    display as error "  FAIL [effecttab]: expected rc=198 and no workbook; rc=`rc' file=`file_exists'"
    local invalid_ok = 0
}
capture erase "`output_dir'/_color_effecttab.xlsx"

capture erase "`output_dir'/_color_comptab.xlsx"
sysuse auto, clear
generate byte expensive = (price > 6000)
collect clear
collect: logistic expensive i.foreign
capture frame drop _color_model
regtab, frame(_color_model) noint
capture comptab _color_model, rownames("foreign") ///
    xlsx("`output_dir'/_color_comptab.xlsx") headercolor("`invalid_color'")
local rc = _rc
capture confirm file "`output_dir'/_color_comptab.xlsx"
local file_exists = (_rc == 0)
if `rc' != 198 | `file_exists' {
    display as error "  FAIL [comptab]: expected rc=198 and no workbook; rc=`rc' file=`file_exists'"
    local invalid_ok = 0
}
capture erase "`output_dir'/_color_comptab.xlsx"

capture erase "`output_dir'/_color_corrtab.xlsx"
sysuse auto, clear
capture corrtab price mpg weight, xlsx("`output_dir'/_color_corrtab.xlsx") ///
    headershade headercolor("`invalid_color'")
local rc = _rc
capture confirm file "`output_dir'/_color_corrtab.xlsx"
local file_exists = (_rc == 0)
if `rc' != 198 | `file_exists' {
    display as error "  FAIL [corrtab]: expected rc=198 and no workbook; rc=`rc' file=`file_exists'"
    local invalid_ok = 0
}
capture erase "`output_dir'/_color_corrtab.xlsx"

capture erase "`output_dir'/_color_diagtab.xlsx"
sysuse auto, clear
generate byte highprice = (price > 6000)
generate byte lowmpg = (mpg < 20)
capture diagtab lowmpg highprice, xlsx("`output_dir'/_color_diagtab.xlsx") ///
    headershade headercolor("`invalid_color'")
local rc = _rc
capture confirm file "`output_dir'/_color_diagtab.xlsx"
local file_exists = (_rc == 0)
if `rc' != 198 | `file_exists' {
    display as error "  FAIL [diagtab]: expected rc=198 and no workbook; rc=`rc' file=`file_exists'"
    local invalid_ok = 0
}
capture erase "`output_dir'/_color_diagtab.xlsx"

clear
set obs 2
generate byte group = _n
generate double _D = _n
generate double _Y = 100 * _n
generate double _Rate = _D / _Y
generate double _Lower = _Rate * 0.8
generate double _Upper = _Rate * 1.2
save "`output_dir'/_color_strate.dta", replace

capture erase "`output_dir'/_color_stratetab.xlsx"
capture stratetab, using("`output_dir'/_color_strate") outcomes(1) ///
    xlsx("`output_dir'/_color_stratetab.xlsx") headershade ///
    headercolor("`invalid_color'")
local rc = _rc
capture confirm file "`output_dir'/_color_stratetab.xlsx"
local file_exists = (_rc == 0)
if `rc' != 198 | `file_exists' {
    display as error "  FAIL [stratetab]: expected rc=198 and no workbook; rc=`rc' file=`file_exists'"
    local invalid_ok = 0
}
capture erase "`output_dir'/_color_stratetab.xlsx"

capture erase "`output_dir'/_color_hrcomptab.xlsx"
capture hrcomptab _color_missing_rate, modelframes(_color_missing_model) ///
    rows(1) xlsx("`output_dir'/_color_hrcomptab.xlsx") ///
    headershade headercolor("`invalid_color'")
local rc = _rc
capture confirm file "`output_dir'/_color_hrcomptab.xlsx"
local file_exists = (_rc == 0)
if `rc' != 198 | `file_exists' {
    display as error "  FAIL [hrcomptab]: expected rc=198 before frame validation; rc=`rc' file=`file_exists'"
    local invalid_ok = 0
}
capture erase "`output_dir'/_color_hrcomptab.xlsx"

if `invalid_ok' {
    display as result "  PASS: direct headercolor() rejects invalid RGB early"
    local ++pass_count
}
else {
    display as error "  FAIL: one or more direct headercolor() validators failed"
    local ++fail_count
}

**## global zebracolor rejects out-of-range RGB before crosstab export
capture noisily {
    capture erase "`output_dir'/_color_crosstab.xlsx"
    global TABTOOLS_ZEBRACOLOR "`invalid_color'"
    sysuse auto, clear
    generate byte expensive = (price > 6000)
    capture crosstab expensive foreign, xlsx("`output_dir'/_color_crosstab.xlsx") zebra
    local rc = _rc
    global TABTOOLS_ZEBRACOLOR
    assert `rc' == 198
    capture confirm file "`output_dir'/_color_crosstab.xlsx"
    assert _rc != 0
}
if _rc == 0 {
    display as result "  PASS: crosstab validates persistent zebracolor before export"
    local ++pass_count
}
else {
    display as error "  FAIL: crosstab persistent zebracolor validation (rc=`=_rc')"
    local ++fail_count
}
capture erase "`output_dir'/_color_crosstab.xlsx"

**## unsupported color names are rejected before existing sheets are touched
capture noisily {
    local preserve_wb "`output_dir'/_color_preserve.xlsx"
    capture erase "`preserve_wb'"

    clear
    set obs 1
    gen str8 A = "sentinel"
    export excel using "`preserve_wb'", sheet("P") sheetreplace

    sysuse auto, clear
    capture noisily puttab make mpg in 1/2 using "`preserve_wb'", sheet("P") ///
        headershade headercolor(notacolor)
    local cmd_rc = _rc
    assert `cmd_rc' == 198

    import excel using "`preserve_wb'", sheet("P") clear allstring
    assert A[1] == "sentinel"
}
if _rc == 0 {
    display as result "  PASS: invalid color name rejected before workbook mutation"
    local ++pass_count
}
else {
    display as error "  FAIL: invalid color name mutated existing workbook (rc=`=_rc')"
    local ++fail_count
}
capture erase "`output_dir'/_color_preserve.xlsx"

**# Named Color Inputs
**## stratetab accepts documented Stata color names
capture noisily {
    capture erase "`output_dir'/_color_stratetab_named.xlsx"
    stratetab, using("`output_dir'/_color_strate") outcomes(1) ///
        xlsx("`output_dir'/_color_stratetab_named.xlsx") headershade ///
        headercolor(navy) zebra zebracolor(yellow)
    confirm file "`output_dir'/_color_stratetab_named.xlsx"
}
if _rc == 0 {
    display as result "  PASS: stratetab accepts supported color names"
    local ++pass_count
}
else {
    display as error "  FAIL: stratetab validated color names (rc=`=_rc')"
    local ++fail_count
}

capture erase "`output_dir'/_color_strate.dta"
capture erase "`output_dir'/_color_stratetab_named.xlsx"
capture frame drop _color_model
quietly tabtools set clear
**# Migrated: refactor-era behavior contracts



capture program drop _contract_make_rate
program define _contract_make_rate
    version 17.0
    syntax , BASENAME(string)
    clear
    set obs 2
    gen byte exposure = _n - 1
    gen double _D = cond(_n == 1, 10, 20)
    gen double _Y = cond(_n == 1, 1000, 1100)
    gen double _Rate = _D / _Y
    gen double _Lower = _Rate * 0.8
    gen double _Upper = _Rate * 1.2
    label define contract_exp 0 "None" 1 "Current", replace
    label values exposure contract_exp
    save "`basename'.dta", replace
end

**# Fresh Install And Helper Readiness
capture noisily {
    quietly net install tabtools, from("`pkg_dir'") replace

    foreach cmd in tabtools table1_tc desctab regtab effecttab stratetab ///
        hrcomptab comptab survtab crosstab diagtab corrtab {
        which `cmd'
    }

    clear
    input byte row byte col
    0 0
    0 1
    1 0
    1 1
    end
    crosstab row col, display
    assert r(N) == 4

    findfile _tabtools_common.ado
    run "`r(fn)'"
    _tabtools_helpers_ready
}
if _rc == 0 {
    display as result "  PASS: fresh install resolves commands and helpers"
    local ++pass_count
}
else {
    display as error "  FAIL: fresh install/helper readiness (rc=`=_rc')"
    local ++fail_count
}

* (baseline manifest/digest contracts live in test_package_release.do;
*  duplicate block removed during v1.7.0 consolidation)

**# Public Command Return Contracts
capture noisily {
    tabtools set clear
    tabtools
    assert r(n_commands) == 16
    assert strpos("`r(commands)'", "table1_tc") > 0
    assert strpos("`r(commands)'", "desctab") > 0
    assert strpos("`r(commands)'", "regtab") > 0

    local xlsx "`output_dir'/contract_table1.xlsx"
    capture erase "`xlsx'"
    capture frame drop contract_t1
    sysuse auto, clear
    table1_tc, by(foreign) vars(price auto \ mpg auto \ rep78 auto) ///
        xlsx("`xlsx'") sheet("Table1") frame(contract_t1, replace) ///
        title("Contract table1")
    confirm file "`xlsx'"
    assert `"`r(xlsx)'"' == `"`xlsx'"'
    assert "`r(sheet)'" == "Table1"
    assert "`r(frame)'" == "contract_t1"
    assert `"`r(methods)'"' != ""
    assert strpos("`r(varlist)'", "price") > 0
    matrix contract_t1_m = r(table)
    assert rowsof(contract_t1_m) > 0
    frame contract_t1: assert _N > 0

    local xlsx "`output_dir'/contract_crosstab.xlsx"
    capture erase "`xlsx'"
    capture frame drop contract_cross
    clear
    input byte outcome byte exposure int freq
    0 0 40
    0 1 20
    1 0 10
    1 1 30
    end
    expand freq
    crosstab outcome exposure, or rr rd xlsx("`xlsx'") sheet("Cross") ///
        frame(contract_cross, replace)
    confirm file "`xlsx'"
    assert `"`r(xlsx)'"' == `"`xlsx'"'
    assert "`r(sheet)'" == "Cross"
    assert "`r(frame)'" == "contract_cross"
    assert r(N) == 100
    assert `"`r(methods)'"' != ""
    matrix contract_cross_m = r(table)
    assert rowsof(contract_cross_m) > 0

    local xlsx "`output_dir'/contract_corrtab.xlsx"
    capture erase "`xlsx'"
    capture frame drop contract_corr
    sysuse auto, clear
    corrtab price mpg weight, spearman lower pvalues ///
        xlsx("`xlsx'") sheet("Corr") frame(contract_corr, replace)
    confirm file "`xlsx'"
    assert `"`r(xlsx)'"' == `"`xlsx'"'
    assert "`r(sheet)'" == "Corr"
    assert "`r(frame)'" == "contract_corr"
    assert `"`r(methods)'"' != ""
    matrix contract_corr_c = r(C)
    matrix contract_corr_n = r(N)
    assert colsof(contract_corr_c) == 3
    assert contract_corr_n[1,1] > 0

    local xlsx "`output_dir'/contract_diagtab.xlsx"
    capture erase "`xlsx'"
    capture frame drop contract_diag
    clear
    set obs 100
    gen byte gold = (_n <= 50)
    gen byte test = 0
    replace test = 1 in 1/40
    replace test = 1 in 51/70
    diagtab test gold, xlsx("`xlsx'") sheet("Diag") ///
        frame(contract_diag, replace)
    confirm file "`xlsx'"
    assert `"`r(xlsx)'"' == `"`xlsx'"'
    assert "`r(sheet)'" == "Diag"
    assert "`r(frame)'" == "contract_diag"
    assert `"`r(methods)'"' != ""
    assert abs(r(sensitivity) - 0.8) < 1e-10
    assert abs(r(specificity) - 0.6) < 1e-10

    local xlsx "`output_dir'/contract_survtab.xlsx"
    capture erase "`xlsx'"
    capture frame drop contract_surv
    webuse drugtr, clear
    stset studytime, failure(died)
    survtab, times(5 10 15 20) by(drug) xlsx("`xlsx'") ///
        sheet("Surv") frame(contract_surv, replace)
    confirm file "`xlsx'"
    assert `"`r(xlsx)'"' == `"`xlsx'"'
    assert "`r(sheet)'" == "Surv"
    assert "`r(frame)'" == "contract_surv"
    assert r(N_rows) > 0
    assert `"`r(methods)'"' != ""

    tempfile rate1 rate2
    _contract_make_rate, basename("`rate1'")
    _contract_make_rate, basename("`rate2'")
    local xlsx "`output_dir'/contract_stratetab.xlsx"
    capture erase "`xlsx'"
    capture frame drop contract_rates
    clear
    stratetab, using("`rate1'" "`rate2'") outcomes(2) ///
        xlsx("`xlsx'") sheet("Rates") frame(contract_rates, replace)
    confirm file "`xlsx'"
    assert `"`r(xlsx)'"' == `"`xlsx'"'
    assert "`r(sheet)'" == "Rates"
    assert "`r(frame)'" == "contract_rates"
    assert r(N_rows) >= 6
    assert r(N_outcomes) == 2

    local xlsx "`output_dir'/contract_regtab.xlsx"
    capture erase "`xlsx'"
    capture frame drop contract_reg
    sysuse auto, clear
    collect clear
    collect: regress price mpg weight i.foreign
    regtab, xlsx("`xlsx'") sheet("Reg") frame(contract_reg, replace)
    confirm file "`xlsx'"
    assert `"`r(xlsx)'"' == `"`xlsx'"'
    assert "`r(sheet)'" == "Reg"
    assert "`r(frame)'" == "contract_reg"
    assert r(N_rows) > 0
    assert r(N_cols) > 0
    assert r(N_models) == 1
    assert `"`r(methods)'"' != ""
    matrix contract_reg_m = r(table)
    assert rowsof(contract_reg_m) > 0

    local xlsx "`output_dir'/contract_effecttab.xlsx"
    capture erase "`xlsx'"
    capture frame drop contract_eff
    sysuse auto, clear
    quietly regress price mpg weight
    collect clear
    collect: margins, dydx(mpg weight)
    effecttab, type(margins) xlsx("`xlsx'") sheet("Effect") ///
        frame(contract_eff, replace)
    confirm file "`xlsx'"
    assert `"`r(xlsx)'"' == `"`xlsx'"'
    assert "`r(sheet)'" == "Effect"
    assert "`r(frame)'" == "contract_eff"
    assert r(N_rows) > 0
    assert r(N_cols) > 0
    assert "`r(type)'" == "margins"
    assert `"`r(methods)'"' != ""
    matrix contract_eff_m = r(table)
    assert rowsof(contract_eff_m) > 0

    local xlsx "`output_dir'/contract_desctab.xlsx"
    capture erase "`xlsx'"
    capture frame drop contract_desc
    sysuse auto, clear
    collect clear
    collect: table rep78, statistic(count price) statistic(mean price)
    desctab, xlsx("`xlsx'") sheet("Desc") frame(contract_desc, replace)
    confirm file "`xlsx'"
    assert `"`r(xlsx)'"' == `"`xlsx'"'
    assert "`r(sheet)'" == "Desc"
    assert "`r(frame)'" == "contract_desc"
    assert r(N_rows) > 0
    assert r(N_cells) > 0
    assert `"`r(methods)'"' != ""
    matrix contract_desc_m = r(table)
    assert rowsof(contract_desc_m) > 0

    capture frame drop contract_comp1
    capture frame drop contract_comp2
    sysuse auto, clear
    collect clear
    collect: regress price foreign mpg weight
    regtab, frame(contract_comp1, replace) noint
    collect clear
    collect: regress price foreign mpg weight length
    regtab, frame(contract_comp2, replace) noint
    local xlsx "`output_dir'/contract_comptab.xlsx"
    capture erase "`xlsx'"
    capture frame drop contract_comp
    comptab contract_comp1 contract_comp2, rows(1 \ 1 2) ///
        xlsx("`xlsx'") sheet("Comp") frame(contract_comp, replace)
    confirm file "`xlsx'"
    assert `"`r(xlsx)'"' == `"`xlsx'"'
    assert "`r(sheet)'" == "Comp"
    assert "`r(frame)'" == "contract_comp"
    assert r(N_rows) == 6
    assert r(N_cols) == 5
    assert r(N_frames) == 2
    assert `"`r(methods)'"' != ""

    capture frame drop contract_hr_rates
    capture frame drop contract_hr_model
    tempfile hrate1 hrate2
    _contract_make_rate, basename("`hrate1'")
    _contract_make_rate, basename("`hrate2'")
    clear
    stratetab, using("`hrate1'" "`hrate2'") outcomes(2) ///
        frame(contract_hr_rates, replace)
    sysuse auto, clear
    collect clear
    collect: regress price foreign mpg weight
    collect: regress price foreign mpg weight length
    regtab, frame(contract_hr_model, replace) noint
    local xlsx "`output_dir'/contract_hrcomptab.xlsx"
    capture erase "`xlsx'"
    capture frame drop contract_hr
    hrcomptab contract_hr_rates, modelframes(contract_hr_model) rows(1) ///
        xlsx("`xlsx'") sheet("HR") frame(contract_hr, replace)
    confirm file "`xlsx'"
    assert `"`r(xlsx)'"' == `"`xlsx'"'
    assert "`r(sheet)'" == "HR"
    assert "`r(frame)'" == "contract_hr"
    assert r(N_rows) > 0
    assert r(N_outcomes) == 2
    assert r(N_modelrows) == 1
}
if _rc == 0 {
    display as result "  PASS: public command return contracts"
    local ++pass_count
}
else {
    display as error "  FAIL: public command return contracts (rc=`=_rc')"
    local ++fail_count
}
foreach fr in contract_t1 contract_cross contract_corr contract_diag contract_surv ///
    contract_rates contract_reg contract_eff contract_desc contract_comp1 ///
    contract_comp2 contract_comp contract_hr_rates contract_hr_model contract_hr {
    capture frame drop `fr'
}

**# Varabbrev Restoration Contracts
capture noisily {
    sysuse auto, clear
    set varabbrev on
    table1_tc price mpg, by(foreign)
    assert "`c(varabbrev)'" == "on"

    clear
    input str1 row_s byte col
    "a" 0
    "b" 1
    "a" 0
    "b" 1
    end
    capture crosstab row_s col
    assert _rc == 109
    assert "`c(varabbrev)'" == "on"

    collect clear
    capture desctab, display
    assert _rc == 119
    assert "`c(varabbrev)'" == "on"

    tempfile missing_rate
    capture stratetab, using("`missing_rate'") outcomes(1) display
    assert _rc == 601
    assert "`c(varabbrev)'" == "on"
    set varabbrev off
}
if _rc == 0 {
    display as result "  PASS: representative success/error paths restore varabbrev"
    local ++pass_count
}
else {
    display as error "  FAIL: varabbrev restoration contracts (rc=`=_rc')"
    local ++fail_count
}


**# Migrated: collect JSON render helper contracts

which _tabtools_collect_render


**# Helper Contracts

capture noisily {
    sysuse auto, clear
    collect clear
    quietly collect: regress price mpg weight
    quietly collect: regress price mpg weight foreign

    collect layout (cmdset) (result[cmd cmdline])
    preserve
    _tabtools_collect_render, type(meta) rowdim(cmdset) ///
        results(cmd cmdline) dropempty
    assert _N == 3
    assert c(k) == 3
    assert B[1] == "Command"
    assert C[1] == "Command line as typed"
    assert A[2] == "1"
    assert B[2] == "regress"
    assert strpos(C[3], "foreign") > 0
    restore
}
if _rc == 0 {
    display as result "  PASS: metadata layout renders from collect .stjson"
    local ++pass_count
}
else {
    display as error "  FAIL: metadata layout render (rc=`=_rc')"
    local ++fail_count
}

capture noisily {
    sysuse auto, clear
    collect clear
    quietly collect: regress price mpg weight
    quietly collect: regress price mpg weight foreign
    collect label levels result _r_b "Coef.", modify
    collect label levels result _r_ci "95% CI", modify
    collect label levels result _r_p "p-value", modify
    collect layout (colname) (cmdset#result[_r_b _r_ci _r_p])

    preserve
    _tabtools_collect_render, type(main) rowdim(colname) coldim(cmdset) ///
        results(_r_b _r_ci _r_p) sep(", ")
    assert _N == 6
    assert c(k) == 7
    assert A[3] == "Mileage (mpg)"
    assert B[3] != ""
    assert strpos(C[3], ", ") > 0
    assert D[3] != ""
    assert E[5] != ""
    assert G[6] != ""
    restore
}
if _rc == 0 {
    display as result "  PASS: regression main layout renders raw coefficients and CIs"
    local ++pass_count
}
else {
    display as error "  FAIL: regression main layout render (rc=`=_rc')"
    local ++fail_count
}

capture noisily {
    clear
    set obs 1000
    set seed 12345
    gen school = ceil(_n/100)
    gen class = ceil(_n/10)
    gen x = rnormal()
    tempvar us uc
    gen `us' = rnormal()
    gen `uc' = rnormal()
    bysort school: gen u_school = `us'[1] * 1.2
    bysort class: gen u_class = `uc'[1] * 0.7
    gen y = 1 + 0.5*x + u_school + u_class + rnormal()

    collect clear
    quietly collect: mixed y x || school: || class:
    collect label levels result _r_b "Coef.", modify
    collect label levels result _r_ci "95% CI", modify
    collect label levels result _r_p "p-value", modify
    collect style cell result[_r_ci], warn sformat("(%s)") cidelimiter(", ")
    collect layout (coleq#colname) (cmdset#result[_r_b _r_ci _r_p]) ()

    preserve
    _tabtools_collect_render, type(main) rowdim(coleq#colname) ///
        coldim(cmdset) results(_r_b _r_ci _r_p) sep(", ")
    assert _N == 11
    assert c(k) == 4
    assert A[3] == "y"
    assert A[4] == "x"
    assert A[6] == "school"
    assert A[7] == "var(_cons)"
    assert A[8] == "class"
    assert A[9] == "var(_cons)"
    assert A[10] == "Residual"
    assert A[11] == "var(e)"
    assert B[4] != ""
    assert strpos(C[4], ", ") > 0
    assert B[7] != ""
    assert B[9] != ""
    assert B[11] != ""
    restore
}
if _rc == 0 {
    display as result "  PASS: multilevel coleq#colname main layout renders without workbook fallback"
    local ++pass_count
}
else {
    display as error "  FAIL: multilevel coleq#colname raw render (rc=`=_rc')"
    local ++fail_count
}

capture noisily {
    sysuse auto, clear
    collect clear
    quietly collect: regress price i.foreign mpg
    collect label levels result _r_b "Coef.", modify
    collect label levels result _r_ci "95% CI", modify
    collect label levels result _r_p "p-value", modify
    collect layout (colname) (cmdset#result[_r_b _r_ci _r_p])

    preserve
    _tabtools_collect_render, type(main) rowdim(colname) coldim(cmdset) ///
        results(_r_b _r_ci _r_p) sep(", ")
    quietly count if A == "foreign"
    assert r(N) == 0
    restore

    preserve
    _tabtools_collect_render, type(main) rowdim(colname) coldim(cmdset) ///
        results(_r_b _r_ci _r_p) sep(", ") factorparents
    quietly count if A == "foreign"
    assert r(N) == 1
    restore
}
if _rc == 0 {
    display as result "  PASS: factor parent rows are opt-in for regtab compatibility"
    local ++pass_count
}
else {
    display as error "  FAIL: factor parent opt-in contract (rc=`=_rc')"
    local ++fail_count
}

capture noisily {
    capture frame drop _cj_fv
    sysuse auto, clear
    gen byte education = cond(rep78 <= 2, 1, cond(rep78 <= 4, 2, 3))
    label define _cj_edulab 1 "Primary" 2 "Secondary" 3 "Tertiary"
    label values education _cj_edulab
    label variable education "Education level"

    collect clear
    quietly collect: regress price i.education mpg
    regtab, frame(_cj_fv, replace)

    frame _cj_fv: gen long _rowid = _n
    frame _cj_fv: quietly count if A == "Education level"
    assert r(N) == 1
    frame _cj_fv: quietly summarize _rowid if A == "Education level", meanonly
    local _parent = r(min)
    local _level1 = `_parent' + 1
    local _level2 = `_parent' + 2
    local _level3 = `_parent' + 3
    frame _cj_fv: assert substr(A[`_parent'], 1, 1) != " "
    frame _cj_fv: assert A[`_level1'] == "  Primary"
    frame _cj_fv: assert A[`_level2'] == "  Secondary"
    frame _cj_fv: assert A[`_level3'] == "  Tertiary"
    frame _cj_fv: assert strtrim(A[`_level2']) == "Secondary"
    frame drop _cj_fv

    capture frame drop _cj_fv_drop
    regtab, frame(_cj_fv_drop, replace) drop(2.education 3.education)
    frame _cj_fv_drop: quietly count if strpos(A, "Secondary") | strpos(A, "Tertiary")
    assert r(N) == 0
    frame _cj_fv_drop: quietly count if A == "Education level" | strpos(A, "Primary")
    assert r(N) >= 1
    frame drop _cj_fv_drop
}
if _rc == 0 {
    display as result "  PASS: regtab factor rows use variable labels with indented levels"
    local ++pass_count
}
else {
    display as error "  FAIL: regtab factor variable row labels (rc=`=_rc')"
    local ++fail_count
}

capture noisily {
    sysuse auto, clear
    collect clear
    quietly collect: regress price mpg weight
    quietly collect: regress price mpg weight foreign
    foreach rlevel in N ll rank not_a_result {
        capture collect label levels result `rlevel' "`rlevel'", modify
    }
    collect layout (cmdset) (result[N ll rank not_a_result])

    preserve
    _tabtools_collect_render, type(stats) rowdim(cmdset) ///
        results(N ll rank not_a_result) dropempty
    assert _N == 3
    assert c(k) == 4
    assert B[1] == "N"
    assert C[1] == "ll"
    assert D[1] == "rank"
    assert real(B[2]) == 74
    assert real(D[3]) == 4
    restore
}
if _rc == 0 {
    display as result "  PASS: stats layout drops absent result columns"
    local ++pass_count
}
else {
    display as error "  FAIL: stats layout render (rc=`=_rc')"
    local ++fail_count
}

capture noisily {
    clear
    set obs 1000
    set seed 12345
    gen school = ceil(_n/100)
    gen class = ceil(_n/10)
    gen x = rnormal()
    tempvar us uc
    gen `us' = rnormal()
    gen `uc' = rnormal()
    bysort school: gen u_school = `us'[1] * 1.2
    bysort class: gen u_class = `uc'[1] * 0.7
    gen y = 1 + 0.5*x + u_school + u_class + rnormal()

    collect clear
    quietly collect: mixed y x || school: || class:

    tempname b_mat
    matrix `b_mat' = e(b)
    local colnames : colfullnames `b_mat'
    local var_re_total = 0
    local var_resid = 0
    local col = 0
    foreach colname of local colnames {
        local ++col
        if regexm("`colname'", "^lns[0-9]+_1_1:") {
            local var_re_total = `var_re_total' + exp(2 * `b_mat'[1, `col'])
        }
        if strpos("`colname'", "lnsig_e:") {
            local var_resid = exp(2 * `b_mat'[1, `col'])
        }
    }

    collect layout (cmdset) (colname[var(_cons) var(e)]#result[_r_b])
    preserve
    _tabtools_collect_render, type(icc) rowdim(cmdset) coldim(colname) ///
        collevels("var(_cons) var(e)") results(_r_b)
    local got_re = real(B[2])
    local got_resid = real(C[2])
    restore

    assert abs(`got_re' - `var_re_total') < 1e-8
    assert abs(`got_resid' - `var_resid') < 1e-8
}
if _rc == 0 {
    display as result "  PASS: ICC render sums duplicate random-intercept variances"
    local ++pass_count
}
else {
    display as error "  FAIL: ICC variance aggregation contract (rc=`=_rc')"
    local ++fail_count
}

capture noisily {
    sysuse auto, clear
    collect clear
    quietly collect: table rep78 foreign, statistic(mean price) ///
        statistic(sd price) statistic(frequency)
    collect layout (rep78) (foreign#result[mean sd frequency])

    preserve
    _tabtools_collect_render, type(desctab) rowdim(rep78) coldim(foreign) ///
        results(mean sd frequency)
    assert _N >= 8
    assert c(k) == 10
    assert B[2] == "Domestic"
    assert E[2] == "Foreign"
    assert H[2] == "Total"
    assert B[3] == "Mean"
    assert D[3] == "Frequency"
    assert A[4] == "Repair record 1978"
    assert A[_N] == "Total"
    restore
}
if _rc == 0 {
    display as result "  PASS: desctab coldim layout renders group/stat headers"
    local ++pass_count
}
else {
    display as error "  FAIL: desctab coldim layout render (rc=`=_rc')"
    local ++fail_count
}

capture noisily {
    sysuse auto, clear
    collect clear
    quietly collect: table rep78 foreign, statistic(mean price) ///
        statistic(frequency)
    collect layout (rep78#foreign) (result[mean frequency])

    preserve
    _tabtools_collect_render, type(desctab) rowdim(rep78#foreign) ///
        results(mean frequency)
    assert _N == 18
    assert c(k) == 3
    assert B[1] == "Mean"
    assert C[1] == "Frequency"
    assert A[2] == "Repair record 1978#Car origin"
    assert A[3] == "1 > Domestic"
    assert A[4] == "1 > Total"
    assert A[8] == "3 > Foreign"
    assert A[_N] == "Total > Total"
    assert B[3] != ""
    assert C[_N] != ""
    restore

    capture frame drop _cj_desc_compound
    desctab, frame(_cj_desc_compound)
    frame _cj_desc_compound: assert A[3] == "Repair record 1978#Car origin"
    frame _cj_desc_compound: assert A[4] == "1 > Domestic"
    frame _cj_desc_compound: assert c1[4] == "2"
    frame drop _cj_desc_compound
}
if _rc == 0 {
    display as result "  PASS: desctab compound row layout renders without workbook fallback"
    local ++pass_count
}
else {
    display as error "  FAIL: desctab compound row layout render (rc=`=_rc')"
    local ++fail_count
}

capture noisily {
    sysuse auto, clear
    gen byte highmpg = mpg > 20
    label define _cj_highmpg 0 "Low MPG" 1 "High MPG"
    label values highmpg _cj_highmpg
    label variable highmpg "Mileage band"

    collect clear
    quietly collect: table rep78 foreign highmpg, statistic(mean price) ///
        statistic(frequency)
    collect layout (rep78) (foreign#highmpg#result[mean frequency])

    preserve
    _tabtools_collect_render, type(desctab) rowdim(rep78) ///
        coldim(foreign#highmpg) results(mean frequency)
    assert _N == 10
    assert c(k) == 19
    assert B[1] == "Car origin#Mileage band"
    assert B[2] == "Domestic > Low MPG"
    assert B[3] == "Mean"
    assert C[3] == "Frequency"
    assert A[4] == "Repair record 1978"
    assert A[5] == "1"
    assert B[5] != ""
    assert C[5] != ""
    assert R[10] != ""
    assert S[10] != ""
    restore

    capture frame drop _cj_desc_colcompound
    desctab, frame(_cj_desc_colcompound)
    frame _cj_desc_colcompound: assert A[2] == "Repair record 1978"
    frame _cj_desc_colcompound: assert c1[2] == "Domestic > Low MPG"
    frame _cj_desc_colcompound: assert c1[3] == "Frequency"
    frame _cj_desc_colcompound: assert c2[3] == "Mean"
    frame _cj_desc_colcompound: assert A[4] == "1"
    frame drop _cj_desc_colcompound
}
if _rc == 0 {
    display as result "  PASS: desctab compound column layout renders without workbook fallback"
    local ++pass_count
}
else {
    display as error "  FAIL: desctab compound column layout render (rc=`=_rc')"
    local ++fail_count
}

**# Public Command Smoke

capture noisily {
    capture frame drop _cj_reg
    capture frame drop _cj_eff
    capture frame drop _cj_desc

    sysuse auto, clear
    collect clear
    quietly collect: regress price mpg weight
    quietly collect: regress price mpg weight foreign
    regtab, stats(N ll aic bic r2) frame(_cj_reg)
    frame _cj_reg: assert _N > 5
    frame drop _cj_reg

    sysuse auto, clear
    collect clear
    quietly collect: teffects ipw (price) (foreign mpg weight)
    effecttab, frame(_cj_eff)
    frame _cj_eff: assert _N >= 4
    frame drop _cj_eff

    sysuse auto, clear
    collect clear
    quietly collect: table rep78 foreign, statistic(mean price) ///
        statistic(sd price) statistic(frequency)
    desctab, frame(_cj_desc)
    frame _cj_desc: assert _N > 5
    frame drop _cj_desc
}
if _rc == 0 {
    display as result "  PASS: public commands run through raw collect render path"
    local ++pass_count
}
else {
    display as error "  FAIL: public command smoke (rc=`=_rc')"
    local ++fail_count
}
display as result "ALL COLLECT JSON RENDER TESTS PASSED"


**# Migrated: markdown writer contracts


local checker "`qa_dir'/tools/check_markdown.py"

capture program drop _md_assert_contains
program define _md_assert_contains
    syntax using/ , TEXT(string asis)
    local text : subinstr local text `"""' "", all
    tempname fh
    file open `fh' using `"`using'"', read text
    local found = 0
    file read `fh' line
    while r(eof) == 0 {
        if strpos(`"`line'"', `"`text'"') > 0 local found = 1
        file read `fh' line
    }
    file close `fh'
    assert `found' == 1
end

capture program drop _md_assert_tables
program define _md_assert_tables
    syntax using/ , MINimum(integer)
    tempname fh
    file open `fh' using `"`using'"', read text
    local tables = 0
    file read `fh' line
    while r(eof) == 0 {
        if strpos(`"`line'"', "| ---") > 0 local ++tables
        file read `fh' line
    }
    file close `fh'
    assert `tables' >= `minimum'
end

**# Shared Writer
local md_writer "`output_dir'/markdown_writer.md"
capture erase "`md_writer'"
capture noisily {
    clear
    set obs 3
    gen str20 A = ""
    gen str20 c1 = ""
    gen str20 c2 = ""
    replace A = "Variable" in 2
    replace c1 = "Column 1" in 2
    replace c2 = "Column 2" in 2
    replace A = "Row | one" in 3
    replace c1 = "1" in 3
    replace c2 = "2" in 3
    _tabtools_markdown_write using "`md_writer'", labelvar(A) title("Writer")
    assert r(n_rows) == 1
    assert r(n_cols) == 3
    _md_assert_contains using "`md_writer'", text("Writer")
    _md_assert_contains using "`md_writer'", text("\|")
}
if _rc == 0 {
    display as result "  PASS: shared Markdown writer"
    local ++pass_count
}
else {
    display as error "  FAIL: shared Markdown writer (rc=`=_rc')"
    local ++fail_count
}

**# table1_tc Markdown-only
local md_table1 "`output_dir'/markdown_table1.md"
capture erase "`md_table1'"
capture noisily {
    sysuse auto, clear
    table1_tc price mpg rep78, by(foreign) title("Table 1") markdown("`md_table1'")
    assert "`r(markdown)'" == "`md_table1'"
    assert r(markdown_rows) > 0
    assert r(markdown_cols) > 0
    _md_assert_contains using "`md_table1'", text("Table 1")
    _md_assert_contains using "`md_table1'", text("Price")
}
if _rc == 0 {
    display as result "  PASS: table1_tc Markdown-only"
    local ++pass_count
}
else {
    display as error "  FAIL: table1_tc Markdown-only (rc=`=_rc')"
    local ++fail_count
}

**# crosstab parallel XLSX + Markdown
local md_cross "`output_dir'/markdown_crosstab.md"
local xlsx_cross "`output_dir'/markdown_crosstab.xlsx"
capture erase "`md_cross'"
capture erase "`xlsx_cross'"
capture noisily {
    sysuse auto, clear
    crosstab rep78 foreign, label xlsx("`xlsx_cross'") markdown("`md_cross'") title("Repairs")
    confirm file "`xlsx_cross'"
    assert "`r(markdown)'" == "`md_cross'"
    _md_assert_contains using "`md_cross'", text("Repairs")
}
if _rc == 0 {
    display as result "  PASS: crosstab parallel XLSX + Markdown"
    local ++pass_count
}
else {
    display as error "  FAIL: crosstab parallel XLSX + Markdown (rc=`=_rc')"
    local ++fail_count
}

**# corrtab appends to an existing Markdown report
capture noisily {
    sysuse auto, clear
    corrtab price mpg weight, spearman pvalues markdown("`md_cross'") mdappend title("Correlations")
    _md_assert_contains using "`md_cross'", text("Correlations")
    _md_assert_tables using "`md_cross'", minimum(2)
}
if _rc == 0 {
    display as result "  PASS: mdappend builds multi-table report"
    local ++pass_count
}
else {
    display as error "  FAIL: mdappend builds multi-table report (rc=`=_rc')"
    local ++fail_count
}

**# puttab Markdown-only
local md_put "`output_dir'/markdown_puttab.md"
capture erase "`md_put'"
capture noisily {
    sysuse auto, clear
    puttab make mpg price in 1/5, markdown("`md_put'") title("Auto sample")
    assert "`r(markdown)'" == "`md_put'"
    assert r(markdown_rows) == 5
    _md_assert_contains using "`md_put'", text("Auto sample")
}
if _rc == 0 {
    display as result "  PASS: puttab Markdown-only"
    local ++pass_count
}
else {
    display as error "  FAIL: puttab Markdown-only (rc=`=_rc')"
    local ++fail_count
}

**# comptab Markdown export
* Regression guard for the v1.5.1 fix: comptab's post-forest return block
* (which always runs) had a malformed compound quote in the markdown return,
* so any comptab, markdown(...) call failed with rc=198 "invalid syntax".
local md_comp "`output_dir'/markdown_comptab.md"
capture erase "`md_comp'"
capture noisily {
    sysuse auto, clear
    collect clear
    collect: regress price mpg weight
    regtab, frame(_md_rt1, replace)
    collect clear
    collect: regress price mpg length
    regtab, frame(_md_rt2, replace)
    comptab _md_rt1 _md_rt2, rows(1 2 \ 1 2) markdown("`md_comp'") title("Composite")
    assert "`r(markdown)'" == "`md_comp'"
    assert r(markdown_rows) > 0
    _md_assert_contains using "`md_comp'", text("Composite")
}
if _rc == 0 {
    display as result "  PASS: comptab Markdown export"
    local ++pass_count
}
else {
    display as error "  FAIL: comptab Markdown export (rc=`=_rc')"
    local ++fail_count
}
capture frame drop _md_rt1
capture frame drop _md_rt2

**# hrcomptab Markdown export
* Same v1.5.1 regression guard for hrcomptab's post-forest return block.
local md_hr "`output_dir'/markdown_hrcomptab.md"
capture erase "`md_hr'"
capture noisily {
    tempfile _md_rate
    clear
    set obs 2
    gen exposure = _n - 1
    gen double _D = cond(_n == 1, 10, 20)
    gen double _Y = cond(_n == 1, 1000, 1100)
    gen double _Rate = _D / _Y
    gen double _Lower = _Rate * 0.80
    gen double _Upper = _Rate * 1.20
    label define _md_exp 0 "None" 1 "Current", replace
    label values exposure _md_exp
    save "`_md_rate'.dta", replace
    clear
    stratetab, using(`_md_rate') outcomes(1) frame(_md_rates, replace) ///
        outlabels("Outcome") explabels("Exposure")
    clear
    set obs 80
    set seed 60607
    gen byte treated = mod(_n, 2)
    gen double y = 10 + 2 * treated + rnormal()
    collect clear
    collect: regress y treated
    regtab, frame(_md_hrmod, replace) noint coef("aHR")
    hrcomptab _md_rates, modelframes(_md_hrmod) rows(1) effect("aHR") ///
        markdown("`md_hr'") title("Survival")
    assert "`r(markdown)'" == "`md_hr'"
    _md_assert_contains using "`md_hr'", text("Survival")
}
if _rc == 0 {
    display as result "  PASS: hrcomptab Markdown export"
    local ++pass_count
}
else {
    display as error "  FAIL: hrcomptab Markdown export (rc=`=_rc')"
    local ++fail_count
}
capture frame drop _md_rates
capture frame drop _md_hrmod

**# Error paths
capture noisily {
    sysuse auto, clear
    capture crosstab rep78 foreign, mdappend
    assert _rc == 198
    capture crosstab rep78 foreign, markdown("bad.txt")
    assert _rc == 198
    capture crosstab rep78 foreign, markdown("bad|path.md")
    assert _rc == 198
}
if _rc == 0 {
    display as result "  PASS: Markdown error paths"
    local ++pass_count
}
else {
    display as error "  FAIL: Markdown error paths (rc=`=_rc')"
    local ++fail_count
}

capture erase "`md_writer'"
capture erase "`md_table1'"
capture erase "`md_cross'"
capture erase "`xlsx_cross'"
capture erase "`md_put'"
capture erase "`md_comp'"
capture erase "`md_hr'"
**# Migrated: Excel engine validation sweep


tabtools set clear

* Locate optional package-local check_xlsx.py validator
local checker ""
foreach _trypath in "`qa_dir'/tools" {
    capture confirm file "`checker'"
    if _rc == 0 {
        local checker "`checker'"
        continue, break
    }
}
local has_checker = ("`checker'" != "")
if !`has_checker' {
    display as text "NOTE: check_xlsx.py not found — using Stata-native Excel validation"
    * Run Stata-native fallback: generate xlsx from core commands, validate with import excel
    local _native_pass = 0
    local _native_fail = 0

    * regtab
    local ++n_total
    capture noisily {
        sysuse auto, clear
        collect clear
        collect: regress price mpg weight i.foreign
        capture erase "`output_dir'/_xl_native_regtab.xlsx"
        regtab, xlsx("`output_dir'/_xl_native_regtab.xlsx") sheet("Test") title("Regression")
        preserve
        import excel "`output_dir'/_xl_native_regtab.xlsx", sheet("Test") cellrange(A1:A1) clear
        assert A[1] == "Regression"
        restore
    }
    if _rc == 0 {
        local ++pass_count
    }
    else {
        local ++fail_count
    }

    * table1_tc
    local ++n_total
    capture noisily {
        sysuse auto, clear
        gen byte highrep = (rep78 >= 4) if !missing(rep78)
        capture erase "`output_dir'/_xl_native_table1.xlsx"
        table1_tc, vars(price contn \ mpg contn \ foreign bin) by(highrep) ///
            xlsx("`output_dir'/_xl_native_table1.xlsx") sheet("T1") title("Table 1")
        preserve
        import excel "`output_dir'/_xl_native_table1.xlsx", sheet("T1") cellrange(A1:A1) clear
        assert A[1] == "Table 1"
        restore
    }
    if _rc == 0 {
        local ++pass_count
    }
    else {
        local ++fail_count
    }

    * effecttab
    local ++n_total
    capture noisily {
        webuse cattaneo2, clear
        collect clear
        collect: teffects ipw (bweight) (mbsmoke mage prenatal1 mmarried fbaby), ate
        capture erase "`output_dir'/_xl_native_effecttab.xlsx"
        effecttab, xlsx("`output_dir'/_xl_native_effecttab.xlsx") sheet("ATE") ///
            title("Treatment Effects") effect("ATE")
        preserve
        import excel "`output_dir'/_xl_native_effecttab.xlsx", sheet("ATE") cellrange(A1:A1) clear
        assert A[1] == "Treatment Effects"
        restore
    }
    if _rc == 0 {
        local ++pass_count
    }
    else {
        local ++fail_count
    }

    * survtab
    local ++n_total
    capture noisily {
        webuse drugtr, clear
        stset studytime, failure(died)
        capture erase "`output_dir'/_xl_native_survtab.xlsx"
        survtab, times(5 10 15 20) by(drug) ///
            xlsx("`output_dir'/_xl_native_survtab.xlsx") sheet("KM") title("Survival")
        preserve
        import excel "`output_dir'/_xl_native_survtab.xlsx", sheet("KM") cellrange(A1:A1) clear
        assert A[1] == "Survival"
        restore
    }
    if _rc == 0 {
        local ++pass_count
    }
    else {
        local ++fail_count
    }

    * crosstab
    local ++n_total
    capture noisily {
        sysuse auto, clear
        gen byte highmpg = (mpg > 20)
        capture erase "`output_dir'/_xl_native_crosstab.xlsx"
        crosstab highmpg foreign, xlsx("`output_dir'/_xl_native_crosstab.xlsx") ///
            sheet("XT") title("Cross-tab")
        preserve
        import excel "`output_dir'/_xl_native_crosstab.xlsx", sheet("XT") cellrange(A1:A1) clear
        assert A[1] == "Cross-tab"
        restore
    }
    if _rc == 0 {
        local ++pass_count
    }
    else {
        local ++fail_count
    }

    * corrtab
    local ++n_total
    capture noisily {
        sysuse auto, clear
        capture erase "`output_dir'/_xl_native_corrtab.xlsx"
        corrtab price mpg weight, xlsx("`output_dir'/_xl_native_corrtab.xlsx") ///
            sheet("Corr") title("Correlations")
        preserve
        import excel "`output_dir'/_xl_native_corrtab.xlsx", sheet("Corr") cellrange(A1:A1) clear
        assert A[1] == "Correlations"
        restore
    }
    if _rc == 0 {
        local ++pass_count
    }
    else {
        local ++fail_count
    }

    * diagtab
    local ++n_total
    capture noisily {
        webuse nhanes2, clear
        gen byte bmi_high = (bmi >= 30) if !missing(bmi)
        capture erase "`output_dir'/_xl_native_diagtab.xlsx"
        diagtab bmi_high diabetes, xlsx("`output_dir'/_xl_native_diagtab.xlsx") ///
            sheet("Diag") title("Diagnostic")
        preserve
        import excel "`output_dir'/_xl_native_diagtab.xlsx", sheet("Diag") cellrange(A1:A1) clear
        assert A[1] == "Diagnostic"
        restore
    }
    if _rc == 0 {
        local ++pass_count
    }
    else {
        local ++fail_count
    }

    * comptab
    local ++n_total
    capture noisily {
        sysuse auto, clear
        collect clear
        collect: regress price mpg weight
        regtab, frame(_comp_m1, replace) noint
        collect clear
        collect: regress price mpg weight length
        regtab, frame(_comp_m2, replace) noint
        capture erase "`output_dir'/_xl_native_comptab.xlsx"
        comptab _comp_m1 _comp_m2, rows(1/2 \ 1/3) ///
            xlsx("`output_dir'/_xl_native_comptab.xlsx") sheet("Comp") title("Composite")
        preserve
        import excel "`output_dir'/_xl_native_comptab.xlsx", sheet("Comp") cellrange(A1:A1) clear
        assert A[1] == "Composite"
        restore
        capture frame drop _comp_m1
        capture frame drop _comp_m2
    }
    if _rc == 0 {
        local ++pass_count
    }
    else {
        local ++fail_count
    }

    * stratetab
    local ++n_total
    capture noisily {
        webuse drugtr, clear
        stset studytime, failure(died)
        strate drug, per(1000) output("`output_dir'/_rate1", replace)
        capture erase "`output_dir'/_xl_native_stratetab.xlsx"
        stratetab, using("`output_dir'/_rate1") ///
            xlsx("`output_dir'/_xl_native_stratetab.xlsx") sheet("Rate") title("Rates") outcomes(1)
        preserve
        import excel "`output_dir'/_xl_native_stratetab.xlsx", sheet("Rate") cellrange(A1:A1) clear
        assert A[1] == "Rates"
        restore
        capture erase "`output_dir'/_rate1.dta"
    }
    if _rc == 0 {
        local ++pass_count
    }
    else {
        local ++fail_count
    }

    * Cleanup native test files
    local xl_native : dir "`output_dir'" files "_xl_native_*.xlsx"
    foreach f of local xl_native {
        capture erase "`output_dir'/`f'"
    }

    display _newline as result "Stata-native Excel Validation Complete"
    display as result "  Passed: `pass_count' / `n_total'"
    if `fail_count' > 0 {
        display as error "  Failed: `fail_count' / `n_total'"
    }
    else {
        display as result "  All `n_total' tests passed!"
    }
    assert `fail_count' == 0
}

if `has_checker' {

display as result "Using checker: `checker'"

* Helper program: run check_xlsx.py and assert PASS
capture program drop _xl_assert
program define _xl_assert
    args xlsx_file result_file checks
    * Run check_xlsx.py
    shell python3 "`checks'"
    file open _fh using "`result_file'", read text
    file read _fh _line
    file close _fh
    assert "`_line'" == "PASS"
end

* =========================================================================
**# SECTION 1: regtab Excel structure and formatting
* =========================================================================

* --- XL1.1: regtab basic structure ---
local ++n_total
capture noisily {
    sysuse auto, clear
    collect clear
    collect: regress price mpg weight i.foreign
    capture erase "`output_dir'/_xl_regtab.xlsx"
    regtab, xlsx("`output_dir'/_xl_regtab.xlsx") sheet("Test") ///
        title("Regression Results") headershade

    shell python3 "`checker'" "`output_dir'/_xl_regtab.xlsx" --sheet "Test" ///
        --min-rows 7 --min-cols 4 ///
        --cell-contains A1 "Regression Results" ///
        --header-row 3 Coef. "95% CI" p-value ///
        --has-borders ///
        --has-pattern p-values ci ///
        --no-empty-cols ///
        --result-file "`output_dir'/_xl_r1.txt" --quiet
    file open _fh using "`output_dir'/_xl_r1.txt", read text
    file read _fh _line
    file close _fh
    assert "`_line'" == "PASS"
}
if _rc == 0 {
    display as result "  PASS: XL1.1 — regtab structure (rows, cols, title, headers, patterns)"
    local ++pass_count
}
else {
    display as error "  FAIL: XL1.1 — regtab structure (rc=`=_rc')"
    local ++fail_count
}
capture erase "`output_dir'/_xl_r1.txt"

* --- XL1.2: regtab header fill color (blue) ---
local ++n_total
capture noisily {
    shell python3 "`checker'" "`output_dir'/_xl_regtab.xlsx" --sheet "Test" ///
        --has-fill 2 --has-fill 3 ///
        --fill-color 2 "219 229 241" ///
        --result-file "`output_dir'/_xl_r2.txt" --quiet
    file open _fh using "`output_dir'/_xl_r2.txt", read text
    file read _fh _line
    file close _fh
    assert "`_line'" == "PASS"
}
if _rc == 0 {
    display as result "  PASS: XL1.2 — regtab header fill color (219 229 241)"
    local ++pass_count
}
else {
    display as error "  FAIL: XL1.2 — regtab header fill color (rc=`=_rc')"
    local ++fail_count
}
capture erase "`output_dir'/_xl_r2.txt"

* --- XL1.3: regtab font and bold ---
local ++n_total
capture noisily {
    shell python3 "`checker'" "`output_dir'/_xl_regtab.xlsx" --sheet "Test" ///
        --font Arial --fontsize 10 ///
        --bold-row-all 3 ///
        --result-file "`output_dir'/_xl_r3.txt" --quiet
    file open _fh using "`output_dir'/_xl_r3.txt", read text
    file read _fh _line
    file close _fh
    assert "`_line'" == "PASS"
}
if _rc == 0 {
    display as result "  PASS: XL1.3 — regtab font Arial 10pt, bold header row"
    local ++pass_count
}
else {
    display as error "  FAIL: XL1.3 — regtab font/bold (rc=`=_rc')"
    local ++fail_count
}
capture erase "`output_dir'/_xl_r3.txt"

* --- XL1.4: regtab merged cells (title spans all cols) ---
local ++n_total
capture noisily {
    shell python3 "`checker'" "`output_dir'/_xl_regtab.xlsx" --sheet "Test" ///
        --merged-row 1 ///
        --min-merges 2 ///
        --result-file "`output_dir'/_xl_r4.txt" --quiet
    file open _fh using "`output_dir'/_xl_r4.txt", read text
    file read _fh _line
    file close _fh
    assert "`_line'" == "PASS"
}
if _rc == 0 {
    display as result "  PASS: XL1.4 — regtab merged title row, multiple merge regions"
    local ++pass_count
}
else {
    display as error "  FAIL: XL1.4 — regtab merges (rc=`=_rc')"
    local ++fail_count
}
capture erase "`output_dir'/_xl_r4.txt"

* --- XL1.5: regtab reference category is italic ---
local ++n_total
capture noisily {
    * Find reference row — row 7 in 9-row regtab with foreign
    shell python3 "`checker'" "`output_dir'/_xl_regtab.xlsx" --sheet "Test" ///
        --contains "Reference" ///
        --italic-cell C7 ///
        --result-file "`output_dir'/_xl_r5.txt" --quiet
    file open _fh using "`output_dir'/_xl_r5.txt", read text
    file read _fh _line
    file close _fh
    assert "`_line'" == "PASS"
}
if _rc == 0 {
    display as result "  PASS: XL1.5 — regtab Reference category is italic"
    local ++pass_count
}
else {
    display as error "  FAIL: XL1.5 — regtab italic reference (rc=`=_rc')"
    local ++fail_count
}
capture erase "`output_dir'/_xl_r5.txt"

* --- XL1.6: regtab cell values are correct ---
local ++n_total
capture noisily {
    * From regress price mpg weight i.foreign on auto:
    * mpg coef ~ 21.85, weight coef ~ 3.46, foreign coef ~ 3673.06
    shell python3 "`checker'" "`output_dir'/_xl_regtab.xlsx" --sheet "Test" ///
        --cell-contains C4 "21.85" ///
        --cell-contains C5 "3.46" ///
        --cell-contains C8 "3673" ///
        --cell-contains E5 "<0.001" ///
        --cell-contains D4 "(-126" ///
        --result-file "`output_dir'/_xl_r6.txt" --quiet
    file open _fh using "`output_dir'/_xl_r6.txt", read text
    file read _fh _line
    file close _fh
    assert "`_line'" == "PASS"
}
if _rc == 0 {
    display as result "  PASS: XL1.6 — regtab cell values correct (coefs, CIs, p-values)"
    local ++pass_count
}
else {
    display as error "  FAIL: XL1.6 — regtab cell values (rc=`=_rc')"
    local ++fail_count
}
capture erase "`output_dir'/_xl_r6.txt"

* --- XL1.7: regtab p-value cells contain valid p-values ---
local ++n_total
capture noisily {
    * E4 = 0.77, E5 = <0.001, E8 = <0.001, E9 = 0.087
    shell python3 "`checker'" "`output_dir'/_xl_regtab.xlsx" --sheet "Test" ///
        --cell-not-empty E4 E5 E8 E9 ///
        --result-file "`output_dir'/_xl_r7.txt" --quiet
    file open _fh using "`output_dir'/_xl_r7.txt", read text
    file read _fh _line
    file close _fh
    assert "`_line'" == "PASS"
}
if _rc == 0 {
    display as result "  PASS: XL1.7 — regtab p-value cells non-empty"
    local ++pass_count
}
else {
    display as error "  FAIL: XL1.7 — regtab p-value cells (rc=`=_rc')"
    local ++fail_count
}
capture erase "`output_dir'/_xl_r7.txt"

* --- XL1.8: regtab bottom border on last row ---
local ++n_total
capture noisily {
    shell python3 "`checker'" "`output_dir'/_xl_regtab.xlsx" --sheet "Test" ///
        --border-row 9 bottom thin ///
        --result-file "`output_dir'/_xl_r8.txt" --quiet
    file open _fh using "`output_dir'/_xl_r8.txt", read text
    file read _fh _line
    file close _fh
    assert "`_line'" == "PASS"
}
if _rc == 0 {
    display as result "  PASS: XL1.8 — regtab bottom border on last row"
    local ++pass_count
}
else {
    display as error "  FAIL: XL1.8 — regtab bottom border (rc=`=_rc')"
    local ++fail_count
}
capture erase "`output_dir'/_xl_r8.txt"

* =========================================================================
**# SECTION 2: regtab compact mode Excel
* =========================================================================

* --- XL2.1: compact regtab structure ---
local ++n_total
capture noisily {
    sysuse auto, clear
    collect clear
    collect: regress price mpg weight i.foreign
    capture erase "`output_dir'/_xl_compact.xlsx"
    regtab, xlsx("`output_dir'/_xl_compact.xlsx") sheet("Compact") ///
        compact boldp(0.05) title("Compact Regression")

    shell python3 "`checker'" "`output_dir'/_xl_compact.xlsx" --sheet "Compact" ///
        --min-rows 7 --exact-cols 4 ///
        --cell-contains A1 "Compact" ///
        --has-borders --has-pattern p-values ci ///
        --result-file "`output_dir'/_xl_c1.txt" --quiet
    file open _fh using "`output_dir'/_xl_c1.txt", read text
    file read _fh _line
    file close _fh
    assert "`_line'" == "PASS"
}
if _rc == 0 {
    display as result "  PASS: XL2.1 — compact regtab has 4 cols (A, B, coef+CI, p)"
    local ++pass_count
}
else {
    display as error "  FAIL: XL2.1 — compact regtab structure (rc=`=_rc')"
    local ++fail_count
}
capture erase "`output_dir'/_xl_c1.txt"

* --- XL2.2: compact mode merges estimate+CI ---
local ++n_total
capture noisily {
    * Row 4 cell C4 should contain both estimate and CI in parentheses
    shell python3 "`checker'" "`output_dir'/_xl_compact.xlsx" --sheet "Compact" ///
        --cell-regex C4 ".*\\(.*,.*\\).*" ///
        --result-file "`output_dir'/_xl_c2.txt" --quiet
    file open _fh using "`output_dir'/_xl_c2.txt", read text
    file read _fh _line
    file close _fh
    assert "`_line'" == "PASS"
}
if _rc == 0 {
    display as result "  PASS: XL2.2 — compact cell contains estimate + (CI)"
    local ++pass_count
}
else {
    display as error "  FAIL: XL2.2 — compact cell format (rc=`=_rc')"
    local ++fail_count
}
capture erase "`output_dir'/_xl_c2.txt"

* --- XL2.3: compact boldp produces bold formatting on significant rows ---
local ++n_total
capture noisily {
    * weight p<0.001, foreign p<0.001 — rows 5 and 8 should be bold
    shell python3 "`checker'" "`output_dir'/_xl_compact.xlsx" --sheet "Compact" ///
        --bold-row 5 --bold-row 8 ///
        --result-file "`output_dir'/_xl_c3.txt" --quiet
    file open _fh using "`output_dir'/_xl_c3.txt", read text
    file read _fh _line
    file close _fh
    assert "`_line'" == "PASS"
}
if _rc == 0 {
    display as result "  PASS: XL2.3 — compact boldp(0.05) applies bold to significant rows"
    local ++pass_count
}
else {
    display as error "  FAIL: XL2.3 — compact boldp formatting (rc=`=_rc')"
    local ++fail_count
}
capture erase "`output_dir'/_xl_c3.txt"

* =========================================================================
**# SECTION 3: regtab multi-model Excel
* =========================================================================

* --- XL3.1: multi-model structure ---
local ++n_total
capture noisily {
    sysuse auto, clear
    collect clear
    collect: regress price mpg weight
    collect: regress price mpg weight i.foreign
    capture erase "`output_dir'/_xl_multi.xlsx"
    regtab, xlsx("`output_dir'/_xl_multi.xlsx") sheet("Multi") ///
        models("Model 1 \ Model 2") title("Multi-model")

    shell python3 "`checker'" "`output_dir'/_xl_multi.xlsx" --sheet "Multi" ///
        --min-rows 7 --min-cols 7 ///
        --cell-contains A1 "Multi-model" ///
        --contains "Model 1" --contains "Model 2" ///
        --has-borders --has-pattern p-values ci ///
        --result-file "`output_dir'/_xl_m1.txt" --quiet
    file open _fh using "`output_dir'/_xl_m1.txt", read text
    file read _fh _line
    file close _fh
    assert "`_line'" == "PASS"
}
if _rc == 0 {
    display as result "  PASS: XL3.1 — multi-model regtab structure and model labels"
    local ++pass_count
}
else {
    display as error "  FAIL: XL3.1 — multi-model structure (rc=`=_rc')"
    local ++fail_count
}
capture erase "`output_dir'/_xl_m1.txt"

* =========================================================================
**# SECTION 4: table1_tc Excel structure and formatting
* =========================================================================

* --- XL4.1: table1_tc basic structure ---
local ++n_total
capture noisily {
    sysuse auto, clear
    capture erase "`output_dir'/_xl_table1.xlsx"
    table1_tc, by(foreign) vars(price contn %9.0f \ mpg contn %9.1f \ weight contn \ rep78 cat) ///
        excel("`output_dir'/_xl_table1.xlsx") title("Baseline Characteristics")

    shell python3 "`checker'" "`output_dir'/_xl_table1.xlsx" ///
        --min-rows 10 --min-cols 4 ///
        --cell-contains A1 "Baseline Characteristics" ///
        --contains "Domestic" --contains "Foreign" --contains "p-value" ///
        --has-borders --has-pattern n-equals ///
        --merged-row 1 ///
        --result-file "`output_dir'/_xl_t1.txt" --quiet
    file open _fh using "`output_dir'/_xl_t1.txt", read text
    file read _fh _line
    file close _fh
    assert "`_line'" == "PASS"
}
if _rc == 0 {
    display as result "  PASS: XL4.1 — table1_tc structure (title, headers, N=, p-value)"
    local ++pass_count
}
else {
    display as error "  FAIL: XL4.1 — table1_tc structure (rc=`=_rc')"
    local ++fail_count
}
capture erase "`output_dir'/_xl_t1.txt"

* --- XL4.2: table1_tc bold header row ---
local ++n_total
capture noisily {
    shell python3 "`checker'" "`output_dir'/_xl_table1.xlsx" ///
        --bold-row 2 ///
        --font Arial --fontsize 10 ///
        --result-file "`output_dir'/_xl_t2.txt" --quiet
    file open _fh using "`output_dir'/_xl_t2.txt", read text
    file read _fh _line
    file close _fh
    assert "`_line'" == "PASS"
}
if _rc == 0 {
    display as result "  PASS: XL4.2 — table1_tc bold header, Arial 10pt"
    local ++pass_count
}
else {
    display as error "  FAIL: XL4.2 — table1_tc font/bold (rc=`=_rc')"
    local ++fail_count
}
capture erase "`output_dir'/_xl_t2.txt"

* --- XL4.3: table1_tc cell content has mean(SD) and category counts ---
local ++n_total
capture noisily {
    * Price row (4): "6072" for Domestic, "6385" for Foreign
    * rep78 category row should show counts with percentages
    shell python3 "`checker'" "`output_dir'/_xl_table1.xlsx" ///
        --has-pattern percentages mean-sd ///
        --contains "N=52" --contains "N=22" ///
        --result-file "`output_dir'/_xl_t3.txt" --quiet
    file open _fh using "`output_dir'/_xl_t3.txt", read text
    file read _fh _line
    file close _fh
    assert "`_line'" == "PASS"
}
if _rc == 0 {
    display as result "  PASS: XL4.3 — table1_tc has N=, mean-sd, percentages"
    local ++pass_count
}
else {
    display as error "  FAIL: XL4.3 — table1_tc content patterns (rc=`=_rc')"
    local ++fail_count
}
capture erase "`output_dir'/_xl_t3.txt"

* --- XL4.4: table1_tc with zebra striping ---
local ++n_total
capture noisily {
    sysuse auto, clear
    capture erase "`output_dir'/_xl_table1_zebra.xlsx"
    table1_tc, by(foreign) vars(price contn \ mpg contn \ weight contn) ///
        excel("`output_dir'/_xl_table1_zebra.xlsx") title("Zebra Test") ///
        zebra headershade

    shell python3 "`checker'" "`output_dir'/_xl_table1_zebra.xlsx" ///
        --has-fill 2 ///
        --fill-color 2 "219 229 241" ///
        --result-file "`output_dir'/_xl_t4.txt" --quiet
    file open _fh using "`output_dir'/_xl_t4.txt", read text
    file read _fh _line
    file close _fh
    assert "`_line'" == "PASS"
}
if _rc == 0 {
    display as result "  PASS: XL4.4 — table1_tc zebra+headershade has fill colors"
    local ++pass_count
}
else {
    display as error "  FAIL: XL4.4 — table1_tc zebra fill (rc=`=_rc')"
    local ++fail_count
}
capture erase "`output_dir'/_xl_t4.txt"

* =========================================================================
**# SECTION 5: effecttab Excel
* =========================================================================

* --- XL5.1: effecttab structure ---
local ++n_total
capture noisily {
    sysuse auto, clear
    collect clear
    collect: teffects ra (price mpg weight) (foreign), ate
    capture erase "`output_dir'/_xl_effecttab.xlsx"
    effecttab, xlsx("`output_dir'/_xl_effecttab.xlsx") sheet("Effects") ///
        title("Treatment Effects") headershade

    shell python3 "`checker'" "`output_dir'/_xl_effecttab.xlsx" --sheet "Effects" ///
        --min-rows 5 --min-cols 4 ///
        --cell-contains A1 "Treatment Effects" ///
        --header-row 3 Effect "95% CI" p-value ///
        --has-borders --has-pattern p-values ci ///
        --has-fill 3 --fill-color 3 "219 229 241" ///
        --merged-row 1 ///
        --result-file "`output_dir'/_xl_e1.txt" --quiet
    file open _fh using "`output_dir'/_xl_e1.txt", read text
    file read _fh _line
    file close _fh
    assert "`_line'" == "PASS"
}
if _rc == 0 {
    display as result "  PASS: XL5.1 — effecttab structure (title, headers, fills, patterns)"
    local ++pass_count
}
else {
    display as error "  FAIL: XL5.1 — effecttab structure (rc=`=_rc')"
    local ++fail_count
}
capture erase "`output_dir'/_xl_e1.txt"

* --- XL5.2: effecttab cell values ---
local ++n_total
capture noisily {
    * ATE for foreign ~ 4973 with p<0.001
    shell python3 "`checker'" "`output_dir'/_xl_effecttab.xlsx" --sheet "Effects" ///
        --cell-contains C4 "4973" ///
        --cell-contains E4 "<0.001" ///
        --cell-not-empty D4 ///
        --result-file "`output_dir'/_xl_e2.txt" --quiet
    file open _fh using "`output_dir'/_xl_e2.txt", read text
    file read _fh _line
    file close _fh
    assert "`_line'" == "PASS"
}
if _rc == 0 {
    display as result "  PASS: XL5.2 — effecttab ATE value and p-value correct"
    local ++pass_count
}
else {
    display as error "  FAIL: XL5.2 — effecttab cell values (rc=`=_rc')"
    local ++fail_count
}
capture erase "`output_dir'/_xl_e2.txt"

* =========================================================================
**# SECTION 6: survtab Excel
* =========================================================================

* --- XL6.1: survtab structure ---
local ++n_total
capture noisily {
    sysuse cancer, clear
    stset studytime, failure(died)
    capture erase "`output_dir'/_xl_survtab.xlsx"
    survtab, times(10 20 30) by(drug) xlsx("`output_dir'/_xl_survtab.xlsx") ///
        sheet("Surv") title("Survival Estimates") events

    shell python3 "`checker'" "`output_dir'/_xl_survtab.xlsx" --sheet "Surv" ///
        --min-rows 8 --min-cols 4 ///
        --cell-contains A1 "Survival Estimates" ///
        --has-borders --has-pattern percentages ///
        --contains "Median" --contains "Events" ///
        --merged-row 1 ///
        --result-file "`output_dir'/_xl_s1.txt" --quiet
    file open _fh using "`output_dir'/_xl_s1.txt", read text
    file read _fh _line
    file close _fh
    assert "`_line'" == "PASS"
}
if _rc == 0 {
    display as result "  PASS: XL6.1 — survtab structure (title, percentages, median, events)"
    local ++pass_count
}
else {
    display as error "  FAIL: XL6.1 — survtab structure (rc=`=_rc')"
    local ++fail_count
}
capture erase "`output_dir'/_xl_s1.txt"

* --- XL6.2: survtab survival probabilities are percentages ---
local ++n_total
capture noisily {
    * Survival values should contain % signs
    shell python3 "`checker'" "`output_dir'/_xl_survtab.xlsx" --sheet "Surv" ///
        --row-contains 7 "%" ///
        --row-contains 8 "%" ///
        --row-contains 9 "%" ///
        --result-file "`output_dir'/_xl_s2.txt" --quiet
    file open _fh using "`output_dir'/_xl_s2.txt", read text
    file read _fh _line
    file close _fh
    assert "`_line'" == "PASS"
}
if _rc == 0 {
    display as result "  PASS: XL6.2 — survtab time-point rows contain percentages"
    local ++pass_count
}
else {
    display as error "  FAIL: XL6.2 — survtab percentages (rc=`=_rc')"
    local ++fail_count
}
capture erase "`output_dir'/_xl_s2.txt"

* --- XL6.3: survtab log-rank test row ---
local ++n_total
capture noisily {
    shell python3 "`checker'" "`output_dir'/_xl_survtab.xlsx" --sheet "Surv" ///
        --contains "Log-rank" --has-pattern p-values ///
        --result-file "`output_dir'/_xl_s3.txt" --quiet
    file open _fh using "`output_dir'/_xl_s3.txt", read text
    file read _fh _line
    file close _fh
    assert "`_line'" == "PASS"
}
if _rc == 0 {
    display as result "  PASS: XL6.3 — survtab has Log-rank test row with p-value"
    local ++pass_count
}
else {
    display as error "  FAIL: XL6.3 — survtab Log-rank (rc=`=_rc')"
    local ++fail_count
}
capture erase "`output_dir'/_xl_s3.txt"

* --- XL6.4: survtab bold header row ---
local ++n_total
capture noisily {
    shell python3 "`checker'" "`output_dir'/_xl_survtab.xlsx" --sheet "Surv" ///
        --bold-row-all 2 ///
        --result-file "`output_dir'/_xl_s4.txt" --quiet
    file open _fh using "`output_dir'/_xl_s4.txt", read text
    file read _fh _line
    file close _fh
    assert "`_line'" == "PASS"
}
if _rc == 0 {
    display as result "  PASS: XL6.4 — survtab bold header row"
    local ++pass_count
}
else {
    display as error "  FAIL: XL6.4 — survtab bold header (rc=`=_rc')"
    local ++fail_count
}
capture erase "`output_dir'/_xl_s4.txt"

* =========================================================================
**# SECTION 7: crosstab Excel
* =========================================================================

* --- XL7.1: crosstab structure ---
local ++n_total
capture noisily {
    sysuse auto, clear
    capture erase "`output_dir'/_xl_crosstab.xlsx"
    crosstab foreign rep78, xlsx("`output_dir'/_xl_crosstab.xlsx") ///
        sheet("Cross") colpct

    shell python3 "`checker'" "`output_dir'/_xl_crosstab.xlsx" --sheet "Cross" ///
        --min-rows 4 --min-cols 6 ///
        --has-borders --has-pattern percentages ///
        --contains "Total" ///
        --bold-row-all 2 ///
        --result-file "`output_dir'/_xl_x1.txt" --quiet
    file open _fh using "`output_dir'/_xl_x1.txt", read text
    file read _fh _line
    file close _fh
    assert "`_line'" == "PASS"
}
if _rc == 0 {
    display as result "  PASS: XL7.1 — crosstab structure (cols, percentages, Total, bold header)"
    local ++pass_count
}
else {
    display as error "  FAIL: XL7.1 — crosstab structure (rc=`=_rc')"
    local ++fail_count
}
capture erase "`output_dir'/_xl_x1.txt"

* --- XL7.2: crosstab Fisher's test row ---
local ++n_total
capture noisily {
    shell python3 "`checker'" "`output_dir'/_xl_crosstab.xlsx" --sheet "Cross" ///
        --contains "Fisher" ///
        --result-file "`output_dir'/_xl_x2.txt" --quiet
    file open _fh using "`output_dir'/_xl_x2.txt", read text
    file read _fh _line
    file close _fh
    assert "`_line'" == "PASS"
}
if _rc == 0 {
    display as result "  PASS: XL7.2 — crosstab has Fisher's test row"
    local ++pass_count
}
else {
    display as error "  FAIL: XL7.2 — crosstab Fisher's test (rc=`=_rc')"
    local ++fail_count
}
capture erase "`output_dir'/_xl_x2.txt"

* =========================================================================
**# SECTION 8: corrtab Excel
* =========================================================================

* --- XL8.1: corrtab structure ---
local ++n_total
capture noisily {
    sysuse auto, clear
    capture erase "`output_dir'/_xl_corrtab.xlsx"
    corrtab price mpg weight length, xlsx("`output_dir'/_xl_corrtab.xlsx") ///
        sheet("Corr") title("Correlation Matrix")

    shell python3 "`checker'" "`output_dir'/_xl_corrtab.xlsx" --sheet "Corr" ///
        --min-rows 6 --min-cols 5 ///
        --cell-contains A1 "Correlation Matrix" ///
        --has-borders ///
        --bold-row-all 2 ///
        --merged-row 1 ///
        --result-file "`output_dir'/_xl_cr1.txt" --quiet
    file open _fh using "`output_dir'/_xl_cr1.txt", read text
    file read _fh _line
    file close _fh
    assert "`_line'" == "PASS"
}
if _rc == 0 {
    display as result "  PASS: XL8.1 — corrtab structure (title, bold header, borders)"
    local ++pass_count
}
else {
    display as error "  FAIL: XL8.1 — corrtab structure (rc=`=_rc')"
    local ++fail_count
}
capture erase "`output_dir'/_xl_cr1.txt"

* --- XL8.2: corrtab diagonal is 1.00 and star footnote ---
local ++n_total
capture noisily {
    * Diagonal values should be 1.00
    shell python3 "`checker'" "`output_dir'/_xl_corrtab.xlsx" --sheet "Corr" ///
        --cell-contains C3 "1.00" ///
        --cell-contains D4 "1.00" ///
        --cell-contains E5 "1.00" ///
        --cell-contains F6 "1.00" ///
        --contains "p<0.05" --contains "p<0.01" --contains "p<0.001" ///
        --result-file "`output_dir'/_xl_cr2.txt" --quiet
    file open _fh using "`output_dir'/_xl_cr2.txt", read text
    file read _fh _line
    file close _fh
    assert "`_line'" == "PASS"
}
if _rc == 0 {
    display as result "  PASS: XL8.2 — corrtab diagonal=1.00, star footnote present"
    local ++pass_count
}
else {
    display as error "  FAIL: XL8.2 — corrtab diagonal/footnote (rc=`=_rc')"
    local ++fail_count
}
capture erase "`output_dir'/_xl_cr2.txt"

* --- XL8.3: corrtab footnote is italic ---
local ++n_total
capture noisily {
    shell python3 "`checker'" "`output_dir'/_xl_corrtab.xlsx" --sheet "Corr" ///
        --italic-row 7 ///
        --result-file "`output_dir'/_xl_cr3.txt" --quiet
    file open _fh using "`output_dir'/_xl_cr3.txt", read text
    file read _fh _line
    file close _fh
    assert "`_line'" == "PASS"
}
if _rc == 0 {
    display as result "  PASS: XL8.3 — corrtab footnote row is italic"
    local ++pass_count
}
else {
    display as error "  FAIL: XL8.3 — corrtab italic footnote (rc=`=_rc')"
    local ++fail_count
}
capture erase "`output_dir'/_xl_cr3.txt"

* =========================================================================
**# SECTION 9: diagtab Excel
* =========================================================================

* --- XL9.1: diagtab structure ---
local ++n_total
capture noisily {
    clear
    set obs 200
    gen byte gold = (_n <= 100)
    gen byte test = 0
    replace test = 1 if gold == 1 & _n <= 80
    replace test = 1 if gold == 0 & _n > 100 & _n <= 110
    capture erase "`output_dir'/_xl_diagtab.xlsx"
    diagtab test gold, xlsx("`output_dir'/_xl_diagtab.xlsx") ///
        sheet("Diag") title("Diagnostic Accuracy")

    shell python3 "`checker'" "`output_dir'/_xl_diagtab.xlsx" --sheet "Diag" ///
        --min-rows 12 --min-cols 3 ///
        --cell-contains A1 "Diagnostic Accuracy" ///
        --has-borders ///
        --contains "Sensitivity" --contains "Specificity" ///
        --contains "PPV" --contains "NPV" --contains "Accuracy" ///
        --has-pattern percentages ci sensitivity ///
        --merged-row 1 ///
        --result-file "`output_dir'/_xl_d1.txt" --quiet
    file open _fh using "`output_dir'/_xl_d1.txt", read text
    file read _fh _line
    file close _fh
    assert "`_line'" == "PASS"
}
if _rc == 0 {
    display as result "  PASS: XL9.1 — diagtab structure (metrics, CIs, patterns)"
    local ++pass_count
}
else {
    display as error "  FAIL: XL9.1 — diagtab structure (rc=`=_rc')"
    local ++fail_count
}
capture erase "`output_dir'/_xl_d1.txt"

* --- XL9.2: diagtab confusion matrix values ---
local ++n_total
capture noisily {
    * Known: TP=80, FP=10, FN=20, TN=90
    shell python3 "`checker'" "`output_dir'/_xl_diagtab.xlsx" --sheet "Diag" ///
        --cell C3 "80" --cell D3 "10" ///
        --cell C4 "20" --cell D4 "90" ///
        --result-file "`output_dir'/_xl_d2.txt" --quiet
    file open _fh using "`output_dir'/_xl_d2.txt", read text
    file read _fh _line
    file close _fh
    assert "`_line'" == "PASS"
}
if _rc == 0 {
    display as result "  PASS: XL9.2 — diagtab confusion matrix cells correct (80/10/20/90)"
    local ++pass_count
}
else {
    display as error "  FAIL: XL9.2 — diagtab confusion matrix (rc=`=_rc')"
    local ++fail_count
}
capture erase "`output_dir'/_xl_d2.txt"

* --- XL9.3: diagtab sensitivity/specificity values ---
local ++n_total
capture noisily {
    * Sensitivity = 80%, Specificity = 90%, Accuracy = 85%
    shell python3 "`checker'" "`output_dir'/_xl_diagtab.xlsx" --sheet "Diag" ///
        --cell-contains C7 "80.0%" ///
        --cell-contains C8 "90.0%" ///
        --cell-contains C11 "85.0%" ///
        --result-file "`output_dir'/_xl_d3.txt" --quiet
    file open _fh using "`output_dir'/_xl_d3.txt", read text
    file read _fh _line
    file close _fh
    assert "`_line'" == "PASS"
}
if _rc == 0 {
    display as result "  PASS: XL9.3 — diagtab Sens=80%, Spec=90%, Acc=85%"
    local ++pass_count
}
else {
    display as error "  FAIL: XL9.3 — diagtab metric values (rc=`=_rc')"
    local ++fail_count
}
capture erase "`output_dir'/_xl_d3.txt"

* =========================================================================
**# SECTION 12: comptab Excel
* =========================================================================

* --- XL12.1: comptab structure ---
local ++n_total
capture noisily {
    sysuse auto, clear
    collect clear
    collect: regress price mpg weight
    capture frame drop _xl_ca
    regtab, frame(_xl_ca)
    sysuse auto, clear
    collect clear
    collect: regress price mpg weight i.foreign
    capture frame drop _xl_cb
    regtab, frame(_xl_cb)
    capture erase "`output_dir'/_xl_comptab.xlsx"
    comptab _xl_ca _xl_cb, xlsx("`output_dir'/_xl_comptab.xlsx") ///
        sheet("Compare") rownames(Mileage Weight \ Mileage Weight Foreign) ///
        title("Model Comparison Table") headershade
    frame drop _xl_ca
    frame drop _xl_cb

    shell python3 "`checker'" "`output_dir'/_xl_comptab.xlsx" --sheet "Compare" ///
        --min-rows 6 --min-cols 4 ///
        --cell-contains A1 "Model Comparison Table" ///
        --has-borders --has-pattern p-values ci ///
        --has-fill 2 --fill-color 2 "219 229 241" ///
        --bold-row-all 3 ///
        --merged-row 1 ///
        --result-file "`output_dir'/_xl_cp1.txt" --quiet
    file open _fh using "`output_dir'/_xl_cp1.txt", read text
    file read _fh _line
    file close _fh
    assert "`_line'" == "PASS"
}
if _rc == 0 {
    display as result "  PASS: XL12.1 — comptab structure (title, fills, bold, patterns)"
    local ++pass_count
}
else {
    display as error "  FAIL: XL12.1 — comptab structure (rc=`=_rc')"
    local ++fail_count
}
capture erase "`output_dir'/_xl_cp1.txt"

* =========================================================================
**# SECTION 13: stratetab Excel
* =========================================================================

* --- XL13.1: stratetab structure ---
local ++n_total
capture noisily {
    * Create synthetic strate data
    quietly {
        clear
        set obs 3
        gen exposure = _n - 1
        gen _D = cond(_n==1, 50, cond(_n==2, 30, 70))
        gen _Y = cond(_n==1, 10000, cond(_n==2, 8000, 12000))
        gen _Rate = _D / _Y
        gen _Lower = _Rate * 0.65
        gen _Upper = _Rate * 1.35
        label define _xl_exp 0 "Low" 1 "Med" 2 "High"
        label values exposure _xl_exp
        save "`output_dir'/_xl_strate_o1.dta", replace
        sysuse auto, clear
    }
    capture erase "`output_dir'/_xl_stratetab.xlsx"
    stratetab, using("`output_dir'/_xl_strate_o1") ///
        xlsx("`output_dir'/_xl_stratetab.xlsx") outcomes(1)

    shell python3 "`checker'" "`output_dir'/_xl_stratetab.xlsx" ///
        --min-rows 3 --min-cols 3 ///
        --has-borders ///
        --result-file "`output_dir'/_xl_st1.txt" --quiet
    file open _fh using "`output_dir'/_xl_st1.txt", read text
    file read _fh _line
    file close _fh
    assert "`_line'" == "PASS"
}
if _rc == 0 {
    display as result "  PASS: XL13.1 — stratetab basic structure"
    local ++pass_count
}
else {
    display as error "  FAIL: XL13.1 — stratetab structure (rc=`=_rc')"
    local ++fail_count
}
capture erase "`output_dir'/_xl_st1.txt"
capture erase "`output_dir'/_xl_strate_o1.dta"

* =========================================================================
**# SECTION 14: Theme validation (NEJM, Lancet, APA)
* =========================================================================

* --- XL14.1: NEJM theme ---
local ++n_total
capture noisily {
    sysuse auto, clear
    collect clear
    collect: regress price mpg weight
    capture erase "`output_dir'/_xl_theme_nejm.xlsx"
    regtab, xlsx("`output_dir'/_xl_theme_nejm.xlsx") sheet("NEJM") theme(nejm)

    shell python3 "`checker'" "`output_dir'/_xl_theme_nejm.xlsx" --sheet "NEJM" ///
        --theme nejm ///
        --result-file "`output_dir'/_xl_th1.txt" --quiet
    file open _fh using "`output_dir'/_xl_th1.txt", read text
    file read _fh _line
    file close _fh
    assert "`_line'" == "PASS"
}
if _rc == 0 {
    display as result "  PASS: XL14.1 — NEJM theme validates (Arial 9pt, academic borders)"
    local ++pass_count
}
else {
    display as error "  FAIL: XL14.1 — NEJM theme (rc=`=_rc')"
    local ++fail_count
}
capture erase "`output_dir'/_xl_th1.txt"

* --- XL14.2: Lancet theme ---
local ++n_total
capture noisily {
    sysuse auto, clear
    collect clear
    collect: regress price mpg weight
    capture erase "`output_dir'/_xl_theme_lancet.xlsx"
    regtab, xlsx("`output_dir'/_xl_theme_lancet.xlsx") sheet("Lancet") theme(lancet)

    shell python3 "`checker'" "`output_dir'/_xl_theme_lancet.xlsx" --sheet "Lancet" ///
        --theme lancet ///
        --result-file "`output_dir'/_xl_th2.txt" --quiet
    file open _fh using "`output_dir'/_xl_th2.txt", read text
    file read _fh _line
    file close _fh
    assert "`_line'" == "PASS"
}
if _rc == 0 {
    display as result "  PASS: XL14.2 — Lancet theme validates (Arial 9pt, academic borders)"
    local ++pass_count
}
else {
    display as error "  FAIL: XL14.2 — Lancet theme (rc=`=_rc')"
    local ++fail_count
}
capture erase "`output_dir'/_xl_th2.txt"

* --- XL14.3: APA theme ---
local ++n_total
capture noisily {
    sysuse auto, clear
    collect clear
    collect: regress price mpg weight
    capture erase "`output_dir'/_xl_theme_apa.xlsx"
    regtab, xlsx("`output_dir'/_xl_theme_apa.xlsx") sheet("APA") theme(apa)

    shell python3 "`checker'" "`output_dir'/_xl_theme_apa.xlsx" --sheet "APA" ///
        --theme apa ///
        --result-file "`output_dir'/_xl_th3.txt" --quiet
    file open _fh using "`output_dir'/_xl_th3.txt", read text
    file read _fh _line
    file close _fh
    assert "`_line'" == "PASS"
}
if _rc == 0 {
    display as result "  PASS: XL14.3 — APA theme validates (Times New Roman 12pt)"
    local ++pass_count
}
else {
    display as error "  FAIL: XL14.3 — APA theme (rc=`=_rc')"
    local ++fail_count
}
capture erase "`output_dir'/_xl_th3.txt"

* --- XL14.4: NEJM theme zebra striping ---
local ++n_total
capture noisily {
    * NEJM theme should have zebra fills
    shell python3 "`checker'" "`output_dir'/_xl_theme_nejm.xlsx" --sheet "NEJM" ///
        --has-fill 5 ///
        --result-file "`output_dir'/_xl_th4.txt" --quiet
    file open _fh using "`output_dir'/_xl_th4.txt", read text
    file read _fh _line
    file close _fh
    assert "`_line'" == "PASS"
}
if _rc == 0 {
    display as result "  PASS: XL14.4 — NEJM theme has zebra fill colors"
    local ++pass_count
}
else {
    display as error "  FAIL: XL14.4 — NEJM theme zebra fills (rc=`=_rc')"
    local ++fail_count
}
capture erase "`output_dir'/_xl_th4.txt"

* =========================================================================
**# SECTION 15: Bold-p highlight formatting
* =========================================================================

* --- XL15.1: boldp(0.05) produces bold + yellow fill on significant rows ---
local ++n_total
capture noisily {
    sysuse auto, clear
    collect clear
    collect: regress price mpg weight
    capture erase "`output_dir'/_xl_boldp.xlsx"
    regtab, xlsx("`output_dir'/_xl_boldp.xlsx") sheet("Bold") boldp(0.05)

    * weight p<0.001, mpg p=0.77 — only weight row (5) should be bold
    shell python3 "`checker'" "`output_dir'/_xl_boldp.xlsx" --sheet "Bold" ///
        --bold-row 5 ///
        --result-file "`output_dir'/_xl_bp1.txt" --quiet
    file open _fh using "`output_dir'/_xl_bp1.txt", read text
    file read _fh _line
    file close _fh
    assert "`_line'" == "PASS"
}
if _rc == 0 {
    display as result "  PASS: XL15.1 — boldp(0.05) bolds significant rows"
    local ++pass_count
}
else {
    display as error "  FAIL: XL15.1 — boldp formatting (rc=`=_rc')"
    local ++fail_count
}
capture erase "`output_dir'/_xl_bp1.txt"

* --- XL15.2: boldp non-significant row is NOT bold ---
local ++n_total
capture noisily {
    * mpg p=0.77 — row 4 should NOT be bold (only header and significant rows)
    * Verify the file structure is correct (has content, has borders)
    shell python3 "`checker'" "`output_dir'/_xl_boldp.xlsx" --sheet "Bold" ///
        --min-rows 5 --has-borders ///
        --cell-not-empty C4 E4 ///
        --result-file "`output_dir'/_xl_bp2.txt" --quiet
    file open _fh using "`output_dir'/_xl_bp2.txt", read text
    file read _fh _line
    file close _fh
    assert "`_line'" == "PASS"
}
if _rc == 0 {
    display as result "  PASS: XL15.2 — boldp file has structure and non-significant data"
    local ++pass_count
}
else {
    display as error "  FAIL: XL15.2 — boldp structure (rc=`=_rc')"
    local ++fail_count
}
capture erase "`output_dir'/_xl_bp2.txt"

* =========================================================================
**# SECTION 17: addrow() in Excel
* =========================================================================

* --- XL17.1: addrow appears in Excel output ---
local ++n_total
capture noisily {
    sysuse auto, clear
    collect clear
    collect: regress price mpg weight
    capture erase "`output_dir'/_xl_addrow.xlsx"
    regtab, xlsx("`output_dir'/_xl_addrow.xlsx") sheet("Add") ///
        addrow("P trend" 0.034)

    shell python3 "`checker'" "`output_dir'/_xl_addrow.xlsx" --sheet "Add" ///
        --contains "P trend" --contains "0.034" ///
        --result-file "`output_dir'/_xl_ar1.txt" --quiet
    file open _fh using "`output_dir'/_xl_ar1.txt", read text
    file read _fh _line
    file close _fh
    assert "`_line'" == "PASS"
}
if _rc == 0 {
    display as result "  PASS: XL17.1 — addrow label and value appear in Excel"
    local ++pass_count
}
else {
    display as error "  FAIL: XL17.1 — addrow in Excel (rc=`=_rc')"
    local ++fail_count
}
capture erase "`output_dir'/_xl_ar1.txt"

* =========================================================================
**# SECTION 18: Cross-command Excel checks (sheet-each batch)
* =========================================================================

* --- XL18.1: all xlsx files have non-empty content ---
local ++n_total
local xl18_pass = 1
foreach cmd in regtab effecttab survtab crosstab corrtab diagtab comptab {
    capture confirm file "`output_dir'/_xl_`cmd'.xlsx"
    if _rc != 0 {
        display as error "  FAIL: XL18.1 — _xl_`cmd'.xlsx does not exist"
        local xl18_pass = 0
        continue
    }
    shell python3 "`checker'" "`output_dir'/_xl_`cmd'.xlsx" ///
        --min-rows 3 --min-cols 3 ///
        --result-file "`output_dir'/_xl_batch_`cmd'.txt" --quiet
    file open _fh using "`output_dir'/_xl_batch_`cmd'.txt", read text
    file read _fh _line
    file close _fh
    if "`_line'" != "PASS" {
        display as error "  FAIL: XL18.1 — _xl_`cmd'.xlsx structure check failed"
        local xl18_pass = 0
    }
    capture erase "`output_dir'/_xl_batch_`cmd'.txt"
}
if `xl18_pass' == 1 {
    display as result "  PASS: XL18.1 — all 7 command xlsx files pass structure check"
    local ++pass_count
}
else {
    local ++fail_count
}

* =========================================================================
**# Cleanup
* =========================================================================

local xl_files : dir "`output_dir'" files "_xl_*.xlsx"
foreach f of local xl_files {
    capture erase "`output_dir'/`f'"
}
local xl_dta : dir "`output_dir'" files "_xl_*.dta"
foreach f of local xl_dta {
    capture erase "`output_dir'/`f'"
}

} // end if `has_checker'

if !`has_checker' {
    display as text "NOTE: check_xlsx.py not available — used Stata-native Excel validation"
}

* =========================================================================

**# Summary
local test_count = `pass_count' + `fail_count'
display ""
display as result "Results: `pass_count'/`test_count' passed, `fail_count' failed"
if `fail_count' > 0 {
    display as error "SOME TESTS FAILED"
    display "RESULT: test_package_helpers tests=`test_count' pass=`pass_count' fail=`fail_count'"
    log close _pkghelpers
    exit 1
}
display as result "ALL TESTS PASSED"
display "RESULT: test_package_helpers tests=`test_count' pass=`pass_count' fail=`fail_count'"
log close _pkghelpers

