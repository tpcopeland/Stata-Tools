*! test_comptab.do — Functional tests for comptab
*! Package: tabtools v1.0.1
*! Date: 2026-03-29

capture log close _test_comptab
log using "test_comptab.log", replace name(_test_comptab) text

local test_count = 0
local pass_count = 0
local fail_count = 0
local failed_tests ""


* === Bootstrap ===
local qa_dir  "`c(pwd)'"
local pkg_dir "`qa_dir'/.."  

capture ado uninstall tabtools
net install tabtools, from("`pkg_dir'") replace

local xlsx "/tmp/test_comptab_qa.xlsx"
capture erase "`xlsx'"

* =========================================================================
**# Setup: Create source frames for all tests
* =========================================================================
{
sysuse auto, clear

* Single-model frame (f1): 3 data rows (foreign, mpg, weight)
collect clear
collect: regress price foreign mpg weight
regtab, xlsx("`xlsx'") sheet("Setup1") frame(f1) noint

* Single-model frame with factor variable (f2): 6+ data rows
collect clear
collect: regress price i.rep78 mpg weight
regtab, xlsx("`xlsx'") sheet("Setup2") frame(f2) noint

* Multi-model frame (fm1): 2 models
collect clear
collect: regress price foreign mpg weight
collect: regress price foreign mpg weight length
regtab, xlsx("`xlsx'") sheet("SetupM1") frame(fm1) noint ///
    models("Model A \ Model B")

* Multi-model frame (fm2): 2 models with factor var
collect clear
collect: regress price i.rep78 mpg weight
collect: regress price i.rep78 mpg weight length
regtab, xlsx("`xlsx'") sheet("SetupM2") frame(fm2) noint ///
    models("Model A \ Model B")

display as result "Setup complete: frames f1, f2, fm1, fm2 created"
}

* =========================================================================
**# 1. Basic functionality
* =========================================================================
{
**## 1.1 Minimal required arguments — single frame, single row, display only
local ++test_count
capture noisily {
    comptab f1, rows(1) display
}
if _rc == 0 {
    display as result "  PASS: 1.1 Minimal args (1 frame, 1 row, display)"
    local ++pass_count
}
else {
    display as error "  FAIL: 1.1 Minimal args (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 1.1"
}

**## 1.2 Two frames, basic composite with xlsx output
local ++test_count
capture noisily {
    comptab f1 f2, rows(1 \ 1 2) xlsx("`xlsx'") sheet("T1.2")
    assert r(N_frames) == 2
    assert r(N_models) == 1
    assert r(N_rows) > 0
    assert r(N_cols) > 0
    assert "`r(sheet)'" == "T1.2"
    assert "`r(xlsx)'" == "`xlsx'"
}
if _rc == 0 {
    display as result "  PASS: 1.2 Two-frame composite with xlsx"
    local ++pass_count
}
else {
    display as error "  FAIL: 1.2 Two-frame composite (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 1.2"
}

**## 1.3 Three frames
local ++test_count
capture noisily {
    comptab f1 f2 f1, rows(1 \ 1 2 \ 2 3) xlsx("`xlsx'") sheet("T1.3")
    assert r(N_frames) == 3
}
if _rc == 0 {
    display as result "  PASS: 1.3 Three-frame composite"
    local ++pass_count
}
else {
    display as error "  FAIL: 1.3 Three-frame composite (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 1.3"
}

**## 1.4 Multi-model frames
local ++test_count
capture noisily {
    comptab fm1 fm2, rows(1 \ 1 2) xlsx("`xlsx'") sheet("T1.4")
    assert r(N_models) == 2
    assert r(N_cols) == 8
}
if _rc == 0 {
    display as result "  PASS: 1.4 Multi-model frames (2 models)"
    local ++pass_count
}
else {
    display as error "  FAIL: 1.4 Multi-model frames (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 1.4"
}
}

* =========================================================================
**# 2. Option tests
* =========================================================================
{
**## 2.1 title()
local ++test_count
capture noisily {
    comptab f1 f2, rows(1 \ 1) xlsx("`xlsx'") sheet("T2.1") ///
        title("Table 3. My Composite")
}
if _rc == 0 {
    display as result "  PASS: 2.1 title() option"
    local ++pass_count
}
else {
    display as error "  FAIL: 2.1 title() (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 2.1"
}

**## 2.2 compact mode
local ++test_count
capture noisily {
    comptab f1 f2, rows(1 \ 1 2) compact xlsx("`xlsx'") sheet("T2.2")
    * Compact: 3 cols per model → 2 cols per model, so single model = 4 cols total
    assert r(N_cols) == 4
}
if _rc == 0 {
    display as result "  PASS: 2.2 compact mode (cols reduced)"
    local ++pass_count
}
else {
    display as error "  FAIL: 2.2 compact mode (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 2.2"
}

**## 2.3 compact mode with multi-model
local ++test_count
capture noisily {
    comptab fm1 fm2, rows(1 \ 1) compact xlsx("`xlsx'") sheet("T2.3")
    * 2 models × 2 cols + title + A = 6 total
    assert r(N_cols) == 6
}
if _rc == 0 {
    display as result "  PASS: 2.3 compact + multi-model"
    local ++pass_count
}
else {
    display as error "  FAIL: 2.3 compact + multi-model (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 2.3"
}

**## 2.4 section() option
local ++test_count
capture noisily {
    comptab f1 f2, rows(1 \ 1 2) ///
        section("Binary" \ "Categories") ///
        xlsx("`xlsx'") sheet("T2.4")
    * 2 headers + 2 section rows + 1 + 2 data rows + title = rows
    * title + model_labels + col_headers + section1 + 1data + section2 + 2data = 8
    assert r(N_rows) == 8
}
if _rc == 0 {
    display as result "  PASS: 2.4 section() adds section rows"
    local ++pass_count
}
else {
    display as error "  FAIL: 2.4 section() (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 2.4"
}

**## 2.5 relabel() option
local ++test_count
capture noisily {
    comptab f1 f2, rows(1 \ 1) relabel(2 "Renamed Row") ///
        xlsx("`xlsx'") sheet("T2.5") frame(_test_relabel)
    * Check the relabeled row in the frame
    frame _test_relabel {
        * Data row 2 = dataset row 4 (title=1, model=2, hdr=3, data=4+)
        assert A[5] == "Renamed Row"
    }
    capture frame drop _test_relabel
}
if _rc == 0 {
    display as result "  PASS: 2.5 relabel() renames row"
    local ++pass_count
}
else {
    display as error "  FAIL: 2.5 relabel() (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 2.5"
}

**## 2.6 separator() option
local ++test_count
capture noisily {
    comptab f1 f2, rows(1 2 \ 1 2) separator(3) ///
        xlsx("`xlsx'") sheet("T2.6")
}
if _rc == 0 {
    display as result "  PASS: 2.6 separator() option"
    local ++pass_count
}
else {
    display as error "  FAIL: 2.6 separator() (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 2.6"
}

**## 2.7 footnote() option
local ++test_count
capture noisily {
    comptab f1 f2, rows(1 \ 1) xlsx("`xlsx'") sheet("T2.7") ///
        footnote("Note: All models adjusted for age and sex.")
}
if _rc == 0 {
    display as result "  PASS: 2.7 footnote() option"
    local ++pass_count
}
else {
    display as error "  FAIL: 2.7 footnote() (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 2.7"
}

**## 2.8 theme() option — all four themes
local _t28_pass = 1
local ++test_count
foreach thm in lancet nejm bmj apa {
    capture noisily {
        comptab f1 f2, rows(1 \ 1) xlsx("`xlsx'") sheet("T2.8_`thm'") theme(`thm')
    }
    if _rc != 0 {
        display as error "  FAIL [2.8.`thm']: theme(`thm') failed (error `=_rc')"
        local _t28_pass = 0
    }
}
if `_t28_pass' {
    display as result "  PASS: 2.8 All four themes (lancet/nejm/bmj/apa)"
    local ++pass_count
}
else {
    local ++fail_count
    local failed_tests "`failed_tests' 2.8"
}

**## 2.9 borderstyle() option
local _t29_pass = 1
local ++test_count
foreach bs in thin medium academic {
    capture noisily {
        comptab f1 f2, rows(1 \ 1) xlsx("`xlsx'") sheet("T2.9_`bs'") borderstyle(`bs')
    }
    if _rc != 0 {
        display as error "  FAIL [2.9.`bs']: borderstyle(`bs') error `=_rc'"
        local _t29_pass = 0
    }
}
if `_t29_pass' {
    display as result "  PASS: 2.9 All three borderstyles"
    local ++pass_count
}
else {
    local ++fail_count
    local failed_tests "`failed_tests' 2.9"
}

**## 2.10 boldp() option
local ++test_count
capture noisily {
    comptab f1 f2, rows(1 \ 1 2) xlsx("`xlsx'") sheet("T2.10") boldp(0.05)
}
if _rc == 0 {
    display as result "  PASS: 2.10 boldp() option"
    local ++pass_count
}
else {
    display as error "  FAIL: 2.10 boldp() (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 2.10"
}

**## 2.11 highlight() option
local ++test_count
capture noisily {
    comptab f1 f2, rows(1 \ 1 2) xlsx("`xlsx'") sheet("T2.11") highlight(0.05)
}
if _rc == 0 {
    display as result "  PASS: 2.11 highlight() option"
    local ++pass_count
}
else {
    display as error "  FAIL: 2.11 highlight() (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 2.11"
}

**## 2.12 zebra option
local ++test_count
capture noisily {
    comptab f1 f2, rows(1 2 \ 1 2) xlsx("`xlsx'") sheet("T2.12") zebra
}
if _rc == 0 {
    display as result "  PASS: 2.12 zebra option"
    local ++pass_count
}
else {
    display as error "  FAIL: 2.12 zebra (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 2.12"
}

**## 2.13 frame() output option
local ++test_count
capture noisily {
    capture frame drop _test_frame
    comptab f1 f2, rows(1 \ 1) frame(_test_frame) display
    frame _test_frame {
        assert _N > 0
    }
    capture frame drop _test_frame
}
if _rc == 0 {
    display as result "  PASS: 2.13 frame() output"
    local ++pass_count
}
else {
    display as error "  FAIL: 2.13 frame() (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 2.13"
}

**## 2.14 csv() output option
local ++test_count
capture noisily {
    local csv_path "/tmp/test_comptab_qa.csv"
    capture erase "`csv_path'"
    comptab f1 f2, rows(1 \ 1) csv("`csv_path'") display
    capture confirm file "`csv_path'"
    assert _rc == 0
    capture erase "`csv_path'"
}
if _rc == 0 {
    display as result "  PASS: 2.14 csv() output"
    local ++pass_count
}
else {
    display as error "  FAIL: 2.14 csv() (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 2.14"
}

**## 2.15 excel() synonym for xlsx()
local ++test_count
capture noisily {
    comptab f1 f2, rows(1 \ 1) excel("`xlsx'") sheet("T2.15")
    assert "`r(xlsx)'" == "`xlsx'"
}
if _rc == 0 {
    display as result "  PASS: 2.15 excel() synonym"
    local ++pass_count
}
else {
    display as error "  FAIL: 2.15 excel() synonym (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 2.15"
}

**## 2.16 display option with xlsx
local ++test_count
capture noisily {
    comptab f1 f2, rows(1 \ 1) xlsx("`xlsx'") sheet("T2.16") display
}
if _rc == 0 {
    display as result "  PASS: 2.16 display + xlsx (both)"
    local ++pass_count
}
else {
    display as error "  FAIL: 2.16 display + xlsx (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 2.16"
}

**## 2.17 Combined options: compact + section + footnote + theme
local ++test_count
capture noisily {
    comptab fm1 fm2, rows(1 \ 1 2) compact ///
        section("Main" \ "Factor") ///
        footnote("Note: Combined test.") ///
        theme(lancet) boldp(0.05) ///
        xlsx("`xlsx'") sheet("T2.17") ///
        title("Kitchen Sink Test")
}
if _rc == 0 {
    display as result "  PASS: 2.17 Combined options (compact+section+footnote+theme+boldp)"
    local ++pass_count
}
else {
    display as error "  FAIL: 2.17 Combined options (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 2.17"
}
}

* =========================================================================
**# 3. Error handling
* =========================================================================
{
**## 3.1 Missing rows() option
local ++test_count
capture noisily comptab f1
if _rc == 198 {
    display as result "  PASS: 3.1 Missing rows() → rc 198"
    local ++pass_count
}
else {
    display as error "  FAIL: 3.1 Missing rows() (expected 198, got `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 3.1"
}

**## 3.2 Frame not found
local ++test_count
capture noisily comptab nonexistent_frame, rows(1)
if _rc == 111 {
    display as result "  PASS: 3.2 Nonexistent frame → rc 111"
    local ++pass_count
}
else {
    display as error "  FAIL: 3.2 Nonexistent frame (expected 111, got `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 3.2"
}

**## 3.3 Row out of range (too high)
local ++test_count
capture noisily comptab f1, rows(99)
if _rc == 198 {
    display as result "  PASS: 3.3 Row out of range → rc 198"
    local ++pass_count
}
else {
    display as error "  FAIL: 3.3 Row out of range (expected 198, got `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 3.3"
}

**## 3.4 Row out of range (zero)
local ++test_count
capture noisily comptab f1, rows(0)
if _rc != 0 {
    display as result "  PASS: 3.4 Row 0 → error"
    local ++pass_count
}
else {
    display as error "  FAIL: 3.4 Row 0 should error"
    local ++fail_count
    local failed_tests "`failed_tests' 3.4"
}

**## 3.5 Mismatched rows/frames count
local ++test_count
capture noisily comptab f1 f2, rows(1)
if _rc == 198 {
    display as result "  PASS: 3.5 rows() count mismatch → rc 198"
    local ++pass_count
}
else {
    display as error "  FAIL: 3.5 rows() mismatch (expected 198, got `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 3.5"
}

**## 3.6 Column mismatch (single vs multi-model frames)
local ++test_count
capture noisily comptab f1 fm1, rows(1 \ 1)
if _rc == 198 {
    display as result "  PASS: 3.6 Column mismatch → rc 198"
    local ++pass_count
}
else {
    display as error "  FAIL: 3.6 Column mismatch (expected 198, got `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 3.6"
}

**## 3.7 Invalid borderstyle
local ++test_count
capture noisily comptab f1, rows(1) borderstyle(fancy) display
if _rc == 198 {
    display as result "  PASS: 3.7 Invalid borderstyle → rc 198"
    local ++pass_count
}
else {
    display as error "  FAIL: 3.7 Invalid borderstyle (expected 198, got `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 3.7"
}

**## 3.8 Invalid highlight (out of range)
local ++test_count
capture noisily comptab f1, rows(1) highlight(2) display
if _rc == 198 {
    display as result "  PASS: 3.8 highlight(2) → rc 198"
    local ++pass_count
}
else {
    display as error "  FAIL: 3.8 highlight(2) (expected 198, got `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 3.8"
}

**## 3.9 Invalid boldp (out of range)
local ++test_count
capture noisily comptab f1, rows(1) boldp(0) display
if _rc == 198 {
    display as result "  PASS: 3.9 boldp(0) → rc 198"
    local ++pass_count
}
else {
    display as error "  FAIL: 3.9 boldp(0) (expected 198, got `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 3.9"
}

**## 3.10 xlsx without .xlsx extension
local ++test_count
capture noisily comptab f1, rows(1) xlsx("/tmp/bad.csv") sheet("T")
if _rc == 198 {
    display as result "  PASS: 3.10 Missing .xlsx extension → rc 198"
    local ++pass_count
}
else {
    display as error "  FAIL: 3.10 Missing .xlsx (expected 198, got `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 3.10"
}

**## 3.11 section() count mismatch
local ++test_count
capture noisily comptab f1 f2, rows(1 \ 1) section("Only One") display
if _rc == 198 {
    display as result "  PASS: 3.11 section() count mismatch → rc 198"
    local ++pass_count
}
else {
    display as error "  FAIL: 3.11 section() mismatch (expected 198, got `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 3.11"
}

**## 3.12 relabel() out of range
local ++test_count
capture noisily comptab f1, rows(1) relabel(99 "Bad") display
if _rc == 198 {
    display as result "  PASS: 3.12 relabel() out of range → rc 198"
    local ++pass_count
}
else {
    display as error "  FAIL: 3.12 relabel() out of range (expected 198, got `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 3.12"
}

**## 3.13 relabel() unpaired (odd number of args)
local ++test_count
capture noisily comptab f1, rows(1) relabel(1) display
if _rc == 198 {
    display as result "  PASS: 3.13 relabel() unpaired → rc 198"
    local ++pass_count
}
else {
    display as error "  FAIL: 3.13 relabel() unpaired (expected 198, got `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 3.13"
}
}

* =========================================================================
**# 4. Return values
* =========================================================================
{
**## 4.1 All r() values present and valid
local _t41_pass = 1
local ++test_count
capture noisily {
    comptab fm1 fm2, rows(1 2 \ 1 2 3) xlsx("`xlsx'") sheet("T4.1") ///
        title("Return Values Test") frame(_test_rv)
}
if _rc != 0 {
    display as error "  FAIL [4.1.run]: command failed (error `=_rc')"
    local _t41_pass = 0
}
else {
    if r(N_rows) >= 8 {
        display as result "  PASS [4.1.rows]: N_rows = `=r(N_rows)'"
    }
    else {
        display as error "  FAIL [4.1.rows]: N_rows = `=r(N_rows)', expected >= 8"
        local _t41_pass = 0
    }
    if r(N_cols) == 8 {
        display as result "  PASS [4.1.cols]: N_cols = 8 (title + A + 6 data)"
    }
    else {
        display as error "  FAIL [4.1.cols]: N_cols = `=r(N_cols)', expected 8"
        local _t41_pass = 0
    }
    if r(N_models) == 2 {
        display as result "  PASS [4.1.models]: N_models = 2"
    }
    else {
        display as error "  FAIL [4.1.models]: N_models = `=r(N_models)', expected 2"
        local _t41_pass = 0
    }
    if r(N_frames) == 2 {
        display as result "  PASS [4.1.frames]: N_frames = 2"
    }
    else {
        display as error "  FAIL [4.1.frames]: N_frames = `=r(N_frames)', expected 2"
        local _t41_pass = 0
    }
    if "`r(xlsx)'" == "`xlsx'" {
        display as result "  PASS [4.1.xlsx]: xlsx path correct"
    }
    else {
        display as error "  FAIL [4.1.xlsx]: xlsx path mismatch"
        local _t41_pass = 0
    }
    if "`r(sheet)'" == "T4.1" {
        display as result "  PASS [4.1.sheet]: sheet name correct"
    }
    else {
        display as error "  FAIL [4.1.sheet]: sheet = `r(sheet)', expected T4.1"
        local _t41_pass = 0
    }
    if "`r(frame)'" == "_test_rv" {
        display as result "  PASS [4.1.frame]: frame name correct"
    }
    else {
        display as error "  FAIL [4.1.frame]: frame = `r(frame)', expected _test_rv"
        local _t41_pass = 0
    }
}
if `_t41_pass' {
    local ++pass_count
}
else {
    local ++fail_count
    local failed_tests "`failed_tests' 4.1"
}
capture frame drop _test_rv

**## 4.2 No r(xlsx) when display-only
local ++test_count
capture noisily {
    comptab f1, rows(1) display
    assert "`r(xlsx)'" == ""
    assert "`r(sheet)'" == "Composite"
}
if _rc == 0 {
    display as result "  PASS: 4.2 Display-only: no r(xlsx), default sheet"
    local ++pass_count
}
else {
    display as error "  FAIL: 4.2 Display-only returns (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 4.2"
}
}

* =========================================================================
**# 5. Data preservation
* =========================================================================
{
**## 5.1 User data unchanged after comptab
local ++test_count
capture noisily {
    sysuse auto, clear
    local orig_N = _N
    local orig_k = c(k)
    local orig_sort : sortedby

    comptab f1 f2, rows(1 \ 1 2) xlsx("`xlsx'") sheet("T5.1")

    assert _N == `orig_N'
    assert c(k) == `orig_k'
    local new_sort : sortedby
    assert "`new_sort'" == "`orig_sort'"

    * Spot check a value
    assert price[1] == 4099
    assert make[1] == "AMC Concord"
}
if _rc == 0 {
    display as result "  PASS: 5.1 User data preserved (_N, k, sort, values)"
    local ++pass_count
}
else {
    display as error "  FAIL: 5.1 Data preservation (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 5.1"
}

**## 5.2 User data preserved on error path
local ++test_count
capture noisily {
    sysuse auto, clear
    local orig_N = _N

    capture noisily comptab nonexistent_frame, rows(1)

    assert _N == `orig_N'
    assert price[1] == 4099
}
if _rc == 0 {
    display as result "  PASS: 5.2 Data preserved on error path"
    local ++pass_count
}
else {
    display as error "  FAIL: 5.2 Data preservation on error (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 5.2"
}
}

* =========================================================================
**# 6. Varabbrev restore
* =========================================================================
{
**## 6.1 Varabbrev restored on success
local ++test_count
capture noisily {
    set varabbrev on
    comptab f1, rows(1) display
    assert c(varabbrev) == "on"

    set varabbrev off
    comptab f1, rows(1) display
    assert c(varabbrev) == "off"

    set varabbrev on
}
if _rc == 0 {
    display as result "  PASS: 6.1 Varabbrev restored on success"
    local ++pass_count
}
else {
    display as error "  FAIL: 6.1 Varabbrev restore (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 6.1"
}

**## 6.2 Varabbrev restored on error
local ++test_count
capture noisily {
    set varabbrev on
    capture noisily comptab nonexistent, rows(1)
    assert c(varabbrev) == "on"

    set varabbrev off
    capture noisily comptab nonexistent, rows(1)
    assert c(varabbrev) == "off"

    set varabbrev on
}
if _rc == 0 {
    display as result "  PASS: 6.2 Varabbrev restored on error"
    local ++pass_count
}
else {
    display as error "  FAIL: 6.2 Varabbrev restore on error (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 6.2"
}
}

* =========================================================================
**# 7. Row count invariants
* =========================================================================
{
**## 7.1 Row count = title + 2 headers + sum of requested data rows
local ++test_count
capture noisily {
    comptab f1 f2, rows(1 2 \ 1 2 3) xlsx("`xlsx'") sheet("T7.1")
    * Expected: title(1) + model_labels(1) + col_headers(1) + data(2+3) = 8
    assert r(N_rows) == 8
}
if _rc == 0 {
    display as result "  PASS: 7.1 Row count = 3 + data rows (no sections)"
    local ++pass_count
}
else {
    display as error "  FAIL: 7.1 Row count (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 7.1"
}

**## 7.2 Row count with sections
local ++test_count
capture noisily {
    comptab f1 f2, rows(1 2 \ 1 2 3) ///
        section("S1" \ "S2") ///
        xlsx("`xlsx'") sheet("T7.2")
    * Expected: title(1) + headers(2) + section1(1) + data1(2) + section2(1) + data2(3) = 10
    assert r(N_rows) == 10
}
if _rc == 0 {
    display as result "  PASS: 7.2 Row count with sections = 3 + sections + data"
    local ++pass_count
}
else {
    display as error "  FAIL: 7.2 Row count with sections (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 7.2"
}

**## 7.3 Compact mode doesn't change row count
local ++test_count
capture noisily {
    comptab f1 f2, rows(1 2 \ 1 2 3) compact xlsx("`xlsx'") sheet("T7.3")
    assert r(N_rows) == 8
}
if _rc == 0 {
    display as result "  PASS: 7.3 Compact doesn't change row count"
    local ++pass_count
}
else {
    display as error "  FAIL: 7.3 Compact row count (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 7.3"
}
}

* =========================================================================
**# 8. Excel output validation
* =========================================================================
{
**## 8.1 Basic structure validation
local ++test_count
capture noisily {
    comptab f1 f2, rows(1 \ 1 2) xlsx("`xlsx'") sheet("T8.1") ///
        title("Structure Test")

}
if _rc == 0 {
    display as result "  PASS: 8.1 Excel structure validation"
    local ++pass_count
}
else {
    display as error "  FAIL: 8.1 Excel structure (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 8.1"
}

**## 8.2 Compact Excel validation
local ++test_count
capture noisily {
    comptab f1 f2, rows(1 \ 1 2) compact xlsx("`xlsx'") sheet("T8.2") ///
        title("Compact Structure")

}
if _rc == 0 {
    display as result "  PASS: 8.2 Compact Excel (4 cols)"
    local ++pass_count
}
else {
    display as error "  FAIL: 8.2 Compact Excel (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 8.2"
}
}

* =========================================================================
**# 9. Package installation & helper auto-loading
* =========================================================================
{
**## 9.1 comptab discoverable after net install
local ++test_count
capture noisily {
    which comptab
}
if _rc == 0 {
    display as result "  PASS: 9.1 comptab discoverable via which"
    local ++pass_count
}
else {
    display as error "  FAIL: 9.1 comptab not found (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 9.1"
}

**## 9.2 Helper auto-loading works after fresh install
local ++test_count
capture noisily {
    * comptab uses _tabtools_validate_path from _tabtools_common
    * If helper doesn't auto-load, this will fail
    comptab f1, rows(1) xlsx("`xlsx'") sheet("T9.2")
}
if _rc == 0 {
    display as result "  PASS: 9.2 Helper auto-load works after install"
    local ++pass_count
}
else {
    display as error "  FAIL: 9.2 Helper auto-load failed (error `=_rc')"
    display as error "        Check: _tabtools_common.ado in .pkg?"
    local ++fail_count
    local failed_tests "`failed_tests' 9.2"
}
}

* =========================================================================
**# 10. Frame content validation
* =========================================================================
{
**## 10.1 Frame has correct structure
local _t101_pass = 1
local ++test_count
capture noisily {
    capture frame drop _test_struct
    comptab f1 f2, rows(1 \ 1 2) frame(_test_struct) display
}
if _rc != 0 {
    display as error "  FAIL [10.1.run]: command failed"
    local _t101_pass = 0
}
else {
    frame _test_struct {
        * Should have: title, A, c1, c2, c3
        capture confirm variable title
        if _rc != 0 {
            display as error "  FAIL [10.1.title]: missing title variable"
            local _t101_pass = 0
        }
        capture confirm variable A
        if _rc != 0 {
            display as error "  FAIL [10.1.A]: missing A variable"
            local _t101_pass = 0
        }
        capture confirm variable c1
        if _rc != 0 {
            display as error "  FAIL [10.1.c1]: missing c1 variable"
            local _t101_pass = 0
        }
        * Row 3 = column headers (A may be empty but c1 should have a label)
        if c1[3] != "" {
            display as result "  PASS [10.1.hdr]: row 3 has column header in c1"
        }
        else {
            display as error "  FAIL [10.1.hdr]: row 3 c1 empty"
            local _t101_pass = 0
        }
    }
}
if `_t101_pass' {
    display as result "  PASS: 10.1 Frame structure correct"
    local ++pass_count
}
else {
    local ++fail_count
    local failed_tests "`failed_tests' 10.1"
}
capture frame drop _test_struct

**## 10.2 Compact frame has fewer columns
local ++test_count
capture noisily {
    capture frame drop _test_compact
    capture frame drop _test_normal
    comptab f1 f2, rows(1 \ 1) frame(_test_normal) display
    comptab f1 f2, rows(1 \ 1) compact frame(_test_compact) display
    frame _test_normal {
        local normal_k = c(k)
    }
    frame _test_compact {
        local compact_k = c(k)
    }
    assert `compact_k' < `normal_k'
    capture frame drop _test_compact
    capture frame drop _test_normal
}
if _rc == 0 {
    display as result "  PASS: 10.2 Compact frame has fewer columns"
    local ++pass_count
}
else {
    display as error "  FAIL: 10.2 Compact column count (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 10.2"
}

**## 10.3 Section labels appear in frame
local ++test_count
capture noisily {
    capture frame drop _test_sec
    comptab f1 f2, rows(1 \ 1) section("Alpha" \ "Beta") frame(_test_sec) display
    frame _test_sec {
        * Row 4 = first section header ("Alpha")
        * Row 5 = first data row
        * Row 6 = second section header ("Beta")
        assert A[4] == "Alpha"
        assert A[6] == "Beta"
    }
    capture frame drop _test_sec
}
if _rc == 0 {
    display as result "  PASS: 10.3 Section labels in frame"
    local ++pass_count
}
else {
    display as error "  FAIL: 10.3 Section labels (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 10.3"
}
}

* =========================================================================
**# Summary
* =========================================================================
display as text ""
display as text _dup(60) "="
display as text "TEST SUMMARY: comptab"
display as text _dup(60) "="
display as text "Total tests: `test_count'"
display as result "  Passed:  `pass_count'"
if `fail_count' > 0 {
    display as error "  Failed:  `fail_count'"
    display as error "  Failed tests: `failed_tests'"
}
else {
    display as text "  Failed:  0"
}
display as text _dup(60) "="

if `fail_count' == 0 {
    display as result "ALL TESTS PASSED"
}
else {
    display as error "`fail_count' TEST(S) FAILED"
    exit 9
}

capture erase "`xlsx'"
capture erase "/tmp/_comptab_check.txt"

log close _test_comptab
