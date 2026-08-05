* test_massdesas.do
*
* Functional tests for massdesas v1.0.2 — batch .sas7bdat to .dta conversion
*
* Sections:
*   1. Installation and dependency checks (Tests 1-3)
*   2. Error handling (Tests 4-8)
*   3. Varabbrev save/restore (Tests 9-11)
*   4. Working directory preservation (Tests 12-14)
*   5. Round-trip conversion (Tests 15-22, requires R/haven)
*   6. Data preservation and path handling (Tests 23-27)
*
* Author: Timothy P Copeland, Karolinska Institutet
* Date: 2026-03-21

clear all
set more off
version 14.0

**# Setup

**## Bootstrap
local qa_dir  "`c(pwd)'"
local pkg_dir "`qa_dir'/.."  

do "`qa_dir'/_massdesas_qa_common.do"
capture noisily _massdesas_qa_bootstrap
local bootstrap_rc = _rc
if `bootstrap_rc' {
    display as error "QA bootstrap failed (rc=`bootstrap_rc')"
    display as text "RESULT: test_massdesas tests=0 pass=0 fail=1 skip=0"
    exit `bootstrap_rc'
}

local test_count = 0
local pass_count = 0
local fail_count = 0
local failed_tests ""

* Create temp directories for testing — unique per test section
tempfile tmpbase
local testdir = substr("`tmpbase'", 1, strlen("`tmpbase'") - 4)
local emptydir "`testdir'_empty"
shell mkdir -p "`emptydir'"

* Check dependencies upfront
local has_filelist = 0
local has_fs = 0
local has_r = 0

capture which filelist
if _rc == 0 local has_filelist = 1

capture which fs
if _rc == 0 local has_fs = 1

* Check R/haven for SAS file creation. Stata's shell command does not propagate
* the child status reliably, so R itself creates the sentinel only after haven
* loads successfully.
tempfile haven_ok
capture erase "`haven_ok'"
local haven_ok_r = subinstr("`haven_ok'", "\", "/", .)
shell Rscript -e "suppressWarnings(library(haven)); file.create('`haven_ok_r'')" > /dev/null 2>&1
capture confirm file "`haven_ok'"
if _rc == 0 local has_r = 1

local has_deps = (`has_filelist' & `has_fs')

display as text "Dependencies: filelist=`has_filelist' fs=`has_fs' R/haven=`has_r'"

if !`has_deps' | !`has_r' {
    display as error "Functional QA requires filelist, fs, R, and the R package haven."
    _massdesas_qa_cleanup
    display as text "RESULT: test_massdesas tests=0 pass=0 fail=1 skip=0"
    exit 499
}

* Save original CWD
local original_cwd `"`c(pwd)'"'

* Pre-create all test data using R/haven (SAS file creation)
* Each test gets its own directory to avoid cleanup issues
local dir_t15 "`testdir'_t15"
local dir_t16 "`testdir'_t16"
local dir_t17 "`testdir'_t17"
local dir_t18 "`testdir'_t18"
local dir_t19 "`testdir'_t19"
local dir_t20 "`testdir'_t20"
local dir_t21 "`testdir'_t21"
local dir_t22 "`testdir'_t22"
local dir_t22s "`testdir'_t22/sub"
local dir_dp "`testdir'_dp"
local dir_t25 "`testdir'_t25 space"
local dir_t26 "`testdir'_t26"
local dir_t27 "`testdir'_t27"

shell mkdir -p "`dir_t15'" "`dir_t16'" "`dir_t17'" "`dir_t18'" "`dir_t19'" "`dir_t20'" "`dir_t21'" "`dir_t22'" "`dir_t22s'" "`dir_dp'" "`dir_t25'" "`dir_t26'" "`dir_t27'"

shell Rscript -e "suppressWarnings(library(haven)); write_sas(data.frame(ID=1:5, AGE=c(25,30,35,40,45), SCORE=c(88.5,92.1,76.3,81.0,95.7)), '`dir_t15'/testdata.sas7bdat')" 2>/dev/null
shell Rscript -e "suppressWarnings(library(haven)); write_sas(data.frame(ID=1:5, AGE=c(25,30,35,40,45), SCORE=c(88.5,92.1,76.3,81.0,95.7)), '`dir_t16'/testdata.sas7bdat')" 2>/dev/null
shell Rscript -e "suppressWarnings(library(haven)); write_sas(data.frame(ID=1:5, AGE=c(25,30,35,40,45), SCORE=c(88.5,92.1,76.3,81.0,95.7)), '`dir_t17'/testdata.sas7bdat')" 2>/dev/null
shell Rscript -e "suppressWarnings(library(haven)); write_sas(data.frame(ID=1:5, AGE=c(25,30,35,40,45), SCORE=c(88.5,92.1,76.3,81.0,95.7)), '`dir_t18'/testdata.sas7bdat')" 2>/dev/null
shell Rscript -e "suppressWarnings(library(haven)); write_sas(data.frame(X=c(1L,2L,3L)), '`dir_t19'/erasetest.sas7bdat')" 2>/dev/null
shell Rscript -e "suppressWarnings(library(haven)); write_sas(data.frame(X=1L), '`dir_t20'/cwd_test.sas7bdat')" 2>/dev/null
shell Rscript -e "suppressWarnings(library(haven)); write_sas(data.frame(X=1L), '`dir_t21'/va_test.sas7bdat')" 2>/dev/null
shell Rscript -e "suppressWarnings(library(haven)); write_sas(data.frame(A=c(1L,2L)), '`dir_t22'/root.sas7bdat'); write_sas(data.frame(A=c(1L,2L)), '`dir_t22'/sub/child.sas7bdat')" 2>/dev/null
shell Rscript -e "suppressWarnings(library(haven)); write_sas(data.frame(X=1L), '`dir_dp'/dp_test.sas7bdat')" 2>/dev/null
shell Rscript -e "suppressWarnings(library(haven)); write_sas(data.frame(X=c(1L,2L)), '`dir_t25'/file with spaces.sas7bdat')" 2>/dev/null
shell Rscript -e "suppressWarnings(library(haven)); write_sas(data.frame(X=c(7L,8L)), '`dir_t26'/a.sas7bdat.b.sas7bdat')" 2>/dev/null
shell Rscript -e "suppressWarnings(library(haven)); write_sas(data.frame(X=c(3L,4L)), '`dir_t27'/good.sas7bdat')" 2>/dev/null
tempname corrupt_fh
file open `corrupt_fh' using "`dir_t27'/broken.sas7bdat", write replace text
file write `corrupt_fh' "not a SAS dataset" _n
file close `corrupt_fh'

* Check if SAS test data was created
local sas_ok = 0
capture confirm file "`dir_t15'/testdata.sas7bdat"
if _rc == 0 & `has_deps' local sas_ok = 1

display as text "SAS test data created: `sas_ok'"

if !`sas_ok' {
    display as error "Functional QA could not create the required SAS fixtures."
    shell rm -rf "`testdir'_"*
    shell rm -rf "`emptydir'"
    _massdesas_qa_cleanup
    display as text "RESULT: test_massdesas tests=0 pass=0 fail=1 skip=0"
    exit 499
}

capture program drop _massdesas_qa_sthlp_render
program define _massdesas_qa_sthlp_render, rclass
    version 14.0
    syntax anything(name=files id="help files")

    local files = subinstr(`"`files'"', char(34), "", .)
    local nbad = 0
    local badfiles ""

    foreach f of local files {
        capture confirm file "`f'"
        if _rc {
            local ++nbad
            local badfiles "`badfiles' `f'"
            continue
        }

        tempfile render_log
        capture log off
        log using "`render_log'", replace text name(_qarender)
        type "`f'", smcl
        log close _qarender
        capture log on

        local hits = 0
        local nlines = 0
        tempname render_fh
        file open `render_fh' using "`render_log'", read text
        file read `render_fh' line
        while r(eof) == 0 {
            local ++nlines
            if regexm(`"`line'"', "\{(pstd|phang|pmore|pin|p_end|psee|synopt|p2col|cmd:|it:|bf:|opt |opth |helpb |hline|title:|marker |dlgtab:|break)") {
                local ++hits
            }
            file read `render_fh' line
        }
        file close `render_fh'

        if `nlines' == 0 | `hits' > 0 {
            local ++nbad
            local badfiles "`badfiles' `f'"
        }
    }

    return scalar nbad = `nbad'
    return local badfiles "`badfiles'"
end

**# Installation and dependency checks

* Test 1: Package installs successfully
local ++test_count
display as text _n "Test `test_count': Package installs and command is discoverable"

capture noisily {
    which massdesas
}
if _rc == 0 {
    display as result "  PASS"
    local ++pass_count
}
else {
    display as error "  FAIL (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' `test_count'"
}

* Test 2: Help file renders without error
local ++test_count
display as text _n "Test `test_count': Help file renders"

capture noisily {
    findfile massdesas.sthlp
    local help_file `"`r(fn)'"'
    _massdesas_qa_sthlp_render `help_file'
    assert r(nbad) == 0

    tempfile broken_help
    tempname broken_fh
    file open `broken_fh' using "`broken_help'", write replace text
    file write `broken_fh' "{smcl}" _n
    file write `broken_fh' "{title:Render probe}" _n _n
    file write `broken_fh' "{pstd}" _n
    file write `broken_fh' "A split directive: {bf:broken" _n
    file write `broken_fh' "directive} renders as literal markup." _n
    file close `broken_fh'
    _massdesas_qa_sthlp_render `broken_help'
    assert r(nbad) == 1
}
if _rc == 0 {
    display as result "  PASS"
    local ++pass_count
}
else {
    display as error "  FAIL (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' `test_count'"
}

* Test 3: Version string present in header
local ++test_count
display as text _n "Test `test_count': Installed header reports Version 1.0.2"

capture noisily {
    findfile massdesas.ado
    tempname version_fh
    file open `version_fh' using "`r(fn)'", read text
    file read `version_fh' version_header
    file close `version_fh'
    assert regexm(`"`version_header'"', "Version 1[.]0[.]2")
}
if _rc == 0 {
    display as result "  PASS"
    local ++pass_count
}
else {
    display as error "  FAIL (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' `test_count'"
}

**# Error handling

* Test 4: Nonexistent directory triggers rc=601
local ++test_count
display as text _n "Test `test_count': Nonexistent directory triggers rc=601"

capture massdesas, directory("/nonexistent/path/xyz_99999")
if _rc == 601 {
    display as result "  PASS"
    local ++pass_count
}
else {
    display as error "  FAIL (expected rc=601, got `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' `test_count'"
}

* Test 5: Empty directory (no .sas7bdat files) triggers error
local ++test_count
display as text _n "Test `test_count': Empty directory triggers error"

capture massdesas, directory("`emptydir'")
if _rc == 601 {
    display as result "  PASS (rc=`=_rc')"
    local ++pass_count
}
else {
    display as error "  FAIL (expected rc=601, got `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' `test_count'"
}

* Test 6: Default directory succeeds when the CWD contains a SAS file
local ++test_count
display as text _n "Test `test_count': No arguments converts the current directory"

local test6_cwd `"`c(pwd)'"'
capture noisily {
    cd "`dir_t15'"
    massdesas
    assert r(n_converted) == 1
    assert r(n_failed) == 0
    assert `"`r(directory)'"' == `"`dir_t15'"'
    confirm file "`dir_t15'/testdata.dta"
}
local test6_rc = _rc
capture cd `"`test6_cwd'"'
if `test6_rc' == 0 {
    display as result "  PASS"
    local ++pass_count
}
else {
    display as error "  FAIL (rc=`test6_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' `test_count'"
}

* Test 7: Invalid option rejected
local ++test_count
display as text _n "Test `test_count': Invalid option rejected"

capture massdesas, badoption
if _rc != 0 {
    display as result "  PASS (rc=`=_rc')"
    local ++pass_count
}
else {
    display as error "  FAIL (should have rejected invalid option)"
    local ++fail_count
    local failed_tests "`failed_tests' `test_count'"
}

* Test 8: Empty string directory
local ++test_count
display as text _n "Test `test_count': Empty string directory uses CWD"

capture massdesas, directory("")
if _rc == 0 | _rc == 601 | _rc == 199 {
    display as result "  PASS (rc=`=_rc')"
    local ++pass_count
}
else {
    display as error "  FAIL (unexpected rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' `test_count'"
}

**# Varabbrev save/restore

* Test 9: varabbrev ON preserved after error exit
local ++test_count
display as text _n "Test `test_count': varabbrev ON preserved after error"

set varabbrev on
capture massdesas, directory("/nonexistent/path/xyz_99999")
if "`c(varabbrev)'" == "on" {
    display as result "  PASS (varabbrev=on preserved)"
    local ++pass_count
}
else {
    display as error "  FAIL (varabbrev=`c(varabbrev)', expected on)"
    local ++fail_count
    local failed_tests "`failed_tests' `test_count'"
}

* Test 10: varabbrev OFF preserved after error exit
local ++test_count
display as text _n "Test `test_count': varabbrev OFF preserved after error"

set varabbrev off
capture massdesas, directory("/nonexistent/path/xyz_99999")
if "`c(varabbrev)'" == "off" {
    display as result "  PASS (varabbrev=off preserved)"
    local ++pass_count
}
else {
    display as error "  FAIL (varabbrev=`c(varabbrev)', expected off)"
    local ++fail_count
    local failed_tests "`failed_tests' `test_count'"
}
set varabbrev on

* Test 11: varabbrev OFF preserved after empty-dir error
local ++test_count
display as text _n "Test `test_count': varabbrev OFF preserved after empty-dir error"

set varabbrev off
capture massdesas, directory("`emptydir'")
if "`c(varabbrev)'" == "off" {
    display as result "  PASS (varabbrev=off preserved)"
    local ++pass_count
}
else {
    display as error "  FAIL (varabbrev=`c(varabbrev)', expected off)"
    local ++fail_count
    local failed_tests "`failed_tests' `test_count'"
}
set varabbrev on

**# Working directory preservation

* Test 12: CWD restored after nonexistent directory error
local ++test_count
display as text _n "Test `test_count': CWD restored after nonexistent dir error"

local pre_cwd `"`c(pwd)'"'
capture massdesas, directory("/nonexistent/path/xyz_99999")
local post_cwd `"`c(pwd)'"'
if `"`pre_cwd'"' == `"`post_cwd'"' {
    display as result "  PASS (CWD unchanged)"
    local ++pass_count
}
else {
    display as error "  FAIL (CWD changed)"
    local ++fail_count
    local failed_tests "`failed_tests' `test_count'"
    cd `"`original_cwd'"'
}

* Test 13: CWD restored after empty directory error
local ++test_count
display as text _n "Test `test_count': CWD restored after empty dir error"

local pre_cwd `"`c(pwd)'"'
capture massdesas, directory("`emptydir'")
local post_cwd `"`c(pwd)'"'
if `"`pre_cwd'"' == `"`post_cwd'"' {
    display as result "  PASS (CWD unchanged)"
    local ++pass_count
}
else {
    display as error "  FAIL (CWD changed)"
    local ++fail_count
    local failed_tests "`failed_tests' `test_count'"
    cd `"`original_cwd'"'
}

* Test 14: CWD restored after invalid option error
local ++test_count
display as text _n "Test `test_count': CWD restored after invalid option error"

local pre_cwd `"`c(pwd)'"'
capture massdesas, badoption
local post_cwd `"`c(pwd)'"'
if `"`pre_cwd'"' == `"`post_cwd'"' {
    display as result "  PASS (CWD unchanged)"
    local ++pass_count
}
else {
    display as error "  FAIL (CWD changed)"
    local ++fail_count
    local failed_tests "`failed_tests' `test_count'"
    cd `"`original_cwd'"'
}

**# Round-trip conversion

* Test 15: Basic single-file conversion
if `sas_ok' {
    local ++test_count
    display as text _n "Test `test_count': Single file conversion"

    capture noisily {
        massdesas, directory("`dir_t15'")
        assert r(n_converted) == 1
        assert r(n_failed) == 0
    }
    if _rc == 0 {
        display as result "  PASS"
        local ++pass_count
    }
    else {
        display as error "  FAIL (rc=`=_rc')"
        local ++fail_count
        local failed_tests "`failed_tests' `test_count'"
    }
}

* Test 16: Converted .dta has correct content
if `sas_ok' {
    local ++test_count
    display as text _n "Test `test_count': Converted .dta content correct"

    capture noisily {
        massdesas, directory("`dir_t16'")
        use "`dir_t16'/testdata.dta", clear
        assert _N == 5
        confirm variable ID AGE SCORE
    }
    if _rc == 0 {
        display as result "  PASS"
        local ++pass_count
    }
    else {
        display as error "  FAIL (rc=`=_rc')"
        local ++fail_count
        local failed_tests "`failed_tests' `test_count'"
    }
}

* Test 17: lower option converts variable names
if `sas_ok' {
    local ++test_count
    display as text _n "Test `test_count': lower option"

    capture noisily {
        massdesas, directory("`dir_t17'") lower
        use "`dir_t17'/testdata.dta", clear
        confirm variable id age score
    }
    if _rc == 0 {
        display as result "  PASS"
        local ++pass_count
    }
    else {
        display as error "  FAIL (rc=`=_rc')"
        local ++fail_count
        local failed_tests "`failed_tests' `test_count'"
    }
}

* Test 18: Return values populated correctly
if `sas_ok' {
    local ++test_count
    display as text _n "Test `test_count': Return values"

    capture noisily {
        massdesas, directory("`dir_t18'")
        assert r(n_converted) == 1
        assert r(n_failed) == 0
        assert `"`r(directory)'"' != ""
    }
    if _rc == 0 {
        display as result "  PASS (n_converted=`r(n_converted)')"
        local ++pass_count
    }
    else {
        display as error "  FAIL (rc=`=_rc')"
        local ++fail_count
        local failed_tests "`failed_tests' `test_count'"
    }
}

* Test 19: erase option removes source files
if `sas_ok' {
    local ++test_count
    display as text _n "Test `test_count': erase option removes source files"

    capture noisily {
        massdesas, directory("`dir_t19'") erase
        capture confirm file "`dir_t19'/erasetest.sas7bdat"
        assert _rc != 0
        confirm file "`dir_t19'/erasetest.dta"
    }
    if _rc == 0 {
        display as result "  PASS"
        local ++pass_count
    }
    else {
        display as error "  FAIL (rc=`=_rc')"
        local ++fail_count
        local failed_tests "`failed_tests' `test_count'"
    }
}

* Test 20: CWD restored after successful conversion
if `sas_ok' {
    local ++test_count
    display as text _n "Test `test_count': CWD restored after successful conversion"

    local pre_cwd `"`c(pwd)'"'
    capture noisily {
        massdesas, directory("`dir_t20'")
    }
    local post_cwd `"`c(pwd)'"'
    if `"`pre_cwd'"' == `"`post_cwd'"' & _rc == 0 {
        display as result "  PASS"
        local ++pass_count
    }
    else {
        display as error "  FAIL (CWD changed or rc=`=_rc')"
        local ++fail_count
        local failed_tests "`failed_tests' `test_count'"
        cd `"`original_cwd'"'
    }
}

* Test 21: varabbrev OFF preserved after successful conversion
if `sas_ok' {
    local ++test_count
    display as text _n "Test `test_count': varabbrev OFF preserved after success"

    set varabbrev off
    capture noisily {
        massdesas, directory("`dir_t21'")
    }
    if "`c(varabbrev)'" == "off" & _rc == 0 {
        display as result "  PASS"
        local ++pass_count
    }
    else {
        display as error "  FAIL (varabbrev=`c(varabbrev)', rc=`=_rc')"
        local ++fail_count
        local failed_tests "`failed_tests' `test_count'"
    }
    set varabbrev on
}

* Test 22: Subdirectory conversion (recursive)
if `sas_ok' {
    local ++test_count
    display as text _n "Test `test_count': Recursive subdirectory conversion"

    capture noisily {
        massdesas, directory("`dir_t22'")
        assert r(n_converted) == 2
        assert r(n_failed) == 0
        confirm file "`dir_t22'/root.dta"
        confirm file "`dir_t22'/sub/child.dta"
    }
    if _rc == 0 {
        display as result "  PASS (n_converted=`r(n_converted)')"
        local ++pass_count
    }
    else {
        display as error "  FAIL (rc=`=_rc')"
        local ++fail_count
        local failed_tests "`failed_tests' `test_count'"
    }
}

**# Data preservation

* Test 23: User data preserved after a post-preserve error
local ++test_count
display as text _n "Test `test_count': User data preserved after empty-directory error"

sysuse auto, clear
generate long _qa_order = _n
local pre_N = _N
local pre_make `"`=make[1]'"'
local pre_price = price[1]
capture massdesas, directory("`emptydir'")
local test23_rc = _rc
capture noisily {
    assert `test23_rc' == 601
    assert _N == `pre_N'
    confirm variable make price _qa_order
    assert `"`=make[1]'"' == `"`pre_make'"'
    assert price[1] == `pre_price'
    assert _qa_order == _n
}
if _rc == 0 {
    display as result "  PASS"
    local ++pass_count
}
else {
    display as error "  FAIL (data or error code changed)"
    local ++fail_count
    local failed_tests "`failed_tests' `test_count'"
}

* Test 24: User data preserved after successful conversion
if `sas_ok' {
    local ++test_count
    display as text _n "Test `test_count': User data preserved after success"

    sysuse auto, clear
    generate long _qa_order = _n
    local pre_N = _N
    local pre_make `"`=make[1]'"'
    local pre_price = price[1]
    capture noisily massdesas, directory("`dir_dp'")
    local test24_rc = _rc
    capture noisily {
        assert `test24_rc' == 0
        assert _N == `pre_N'
        confirm variable make price _qa_order
        assert `"`=make[1]'"' == `"`pre_make'"'
        assert price[1] == `pre_price'
        assert _qa_order == _n
    }
    if _rc == 0 {
        display as result "  PASS"
        local ++pass_count
    }
    else {
        display as error "  FAIL (_N=`=_N' expected `pre_N', rc=`=_rc')"
        local ++fail_count
        local failed_tests "`failed_tests' `test_count'"
    }
}

* Test 25: Directory paths and filenames containing spaces
local ++test_count
display as text _n "Test `test_count': Spaces in directory path and filename"

capture noisily {
    massdesas, directory("`dir_t25'")
    assert r(n_converted) == 1
    assert r(n_failed) == 0
    confirm file "`dir_t25'/file with spaces.dta"
    use "`dir_t25'/file with spaces.dta", clear
    assert _N == 2
    assert X[2] == 2
}
if _rc == 0 {
    display as result "  PASS"
    local ++pass_count
}
else {
    display as error "  FAIL (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' `test_count'"
}

* Test 26: Only the final .sas7bdat suffix is replaced
local ++test_count
display as text _n "Test `test_count': Repeated extension text preserves the full basename"

capture noisily {
    clear
    set obs 1
    generate long sentinel = 999
    save "`dir_t26'/a.dta", replace
    massdesas, directory("`dir_t26'")
    assert r(n_converted) == 1
    assert r(n_failed) == 0
    confirm file "`dir_t26'/a.sas7bdat.b.dta"
    use "`dir_t26'/a.sas7bdat.b.dta", clear
    assert _N == 2
    assert X[1] == 7
    assert X[2] == 8
    use "`dir_t26'/a.dta", clear
    confirm variable sentinel
    assert sentinel[1] == 999
}
if _rc == 0 {
    display as result "  PASS"
    local ++pass_count
}
else {
    display as error "  FAIL (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' `test_count'"
}

* Test 27: A corrupt file is counted, retained, and does not stop valid siblings
local ++test_count
display as text _n "Test `test_count': Mixed valid and corrupt SAS files"

capture noisily {
    massdesas, directory("`dir_t27'") erase
    assert r(n_converted) == 1
    assert r(n_failed) == 1
    confirm file "`dir_t27'/good.dta"
    capture confirm file "`dir_t27'/good.sas7bdat"
    assert _rc != 0
    confirm file "`dir_t27'/broken.sas7bdat"
    capture confirm file "`dir_t27'/broken.dta"
    assert _rc != 0
    use "`dir_t27'/good.dta", clear
    assert _N == 2
    assert X[1] == 3
    assert X[2] == 4
}
if _rc == 0 {
    display as result "  PASS"
    local ++pass_count
}
else {
    display as error "  FAIL (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' `test_count'"
}

**# Cleanup
shell rm -rf "`testdir'_"*
shell rm -rf "`emptydir'"
cd `"`original_cwd'"'
_massdesas_qa_cleanup

**# Summary
display as text "MASSDESAS FUNCTIONAL TEST SUMMARY (v1.0.2)"
display as text "Total tests:  `test_count'"
display as result "Passed:       `pass_count'"
if `fail_count' > 0 {
    display as error "Failed:       `fail_count'"
    display as error "Failed tests:`failed_tests'"
}
else {
    display as text "Failed:       `fail_count'"
}
display as text "Testing completed: `c(current_date)' `c(current_time)'"

if `fail_count' > 0 {
    display as error "Some tests FAILED."
    display as text "RESULT: test_massdesas tests=`test_count' pass=`pass_count' fail=`fail_count' skip=0"
    exit 1
}
else {
    display as result "All tests PASSED!"
}
display as text "RESULT: test_massdesas tests=`test_count' pass=`pass_count' fail=`fail_count' skip=0"
