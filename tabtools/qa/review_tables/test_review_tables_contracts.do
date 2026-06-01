* test_review_tables_contracts.do - focused review QA for table construction commands

clear all
set more off
set varabbrev off
version 17.0

capture log close _review_tables
log using "`c(tmpdir)'/test_review_tables_contracts.log", replace text name(_review_tables)

local qa_dir "`c(pwd)'"
if !regexm("`qa_dir'", "/qa$") {
    if regexm("`qa_dir'", "/qa/review_tables$") {
        local qa_dir = regexr("`qa_dir'", "/review_tables$", "")
    }
}
local pkg_dir = subinstr("`qa_dir'", "/qa", "", 1)

local orig_plus "`c(sysdir_plus)'"
local orig_personal "`c(sysdir_personal)'"
tempname install_id
local install_tag = subinstr("`install_id'", "__", "", .)
local plus_dir "`c(tmpdir)'/tabtools_review_tables_plus_`install_tag'"
local personal_dir "`c(tmpdir)'/tabtools_review_tables_personal_`install_tag'"
capture mkdir "`plus_dir'"
capture mkdir "`personal_dir'"

ado dir
sysdir set PLUS "`plus_dir'"
sysdir set PERSONAL "`personal_dir'"
discard
capture ado uninstall tabtools
quietly net install tabtools, from("`pkg_dir'") replace
discard
which table1_tc
which stratetab
which stacktab

local test_count = 0
local pass_count = 0
local fail_count = 0

capture program drop _review_strate_file
program define _review_strate_file
    syntax , BASENAME(string) [MODE(string)]
    clear
    set obs 2
    gen str20 category = cond(_n == 1, "Low", "High")
    if "`mode'" == "duplicate" replace category = "Low"
    if "`mode'" == "blank" replace category = "" in 2
    if "`mode'" == "mismatch" replace category = cond(_n == 1, "Low", "Medium")
    gen double _D = cond(_n == 1, 10, 20)
    gen double _Y = cond(_n == 1, 1000, 2000)
    gen double _Rate = _D / _Y
    gen double _Lower = _Rate * 0.8
    gen double _Upper = _Rate * 1.2
    save "`basename'.dta", replace
end

capture program drop _review_build_workbook
program define _review_build_workbook
    syntax , XLSX(string)
    clear
    set obs 3
    gen str12 label = ""
    gen str8 est = ""
    gen str12 ci = ""
    replace label = "Header" in 1
    replace est = "HR" in 1
    replace ci = "95% CI" in 1
    replace label = "A" in 2
    replace est = "1.1" in 2
    replace ci = "(0.9,1.4)" in 2
    replace label = "B" in 3
    replace est = "1.4" in 3
    replace ci = "(1.1,1.8)" in 3
    export excel "`xlsx'", sheet("Src") sheetreplace
end

**# table1_tc reserved by() names and cleanup

local ++test_count
capture noisily {
    clear
    set obs 6
    gen byte N_case = mod(_n, 2)
    gen byte m_case = mod(_n + 1, 2)
    gen double age = 40 + _n
    gen str5 marker = "keep"
    local n_before = _N
    local marker_before = marker[3]
    set varabbrev on

    capture noisily table1_tc age, by(N_case)
    local rc_n = _rc
    assert `rc_n' == 498
    assert _N == `n_before'
    assert marker[3] == "`marker_before'"
    assert c(varabbrev) == "on"

    capture noisily table1_tc age, by(m_case)
    local rc_m = _rc
    assert `rc_m' == 498
    assert _N == `n_before'
    assert marker[3] == "`marker_before'"
    assert c(varabbrev) == "on"
    set varabbrev off
}
if _rc == 0 {
    display as result "  PASS: table1_tc rejects reserved by() names and restores caller state"
    local ++pass_count
}
else {
    display as error "  FAIL: table1_tc reserved by() cleanup contract (rc=`=_rc')"
    local ++fail_count
    capture set varabbrev off
}

**# stratetab category validation preserves caller state

local ++test_count
capture noisily {
    tempfile good dup blank mismatch
    _review_strate_file, basename("`good'")
    _review_strate_file, basename("`dup'") mode(duplicate)
    _review_strate_file, basename("`blank'") mode(blank)
    _review_strate_file, basename("`mismatch'") mode(mismatch)

    clear
    set obs 4
    gen byte id = _n
    gen str6 marker = "safe"
    local n_before = _N
    set varabbrev on

    capture noisily stratetab, using("`dup'") outcomes(1) display
    assert _rc == 198
    assert _N == `n_before'
    assert marker[2] == "safe"
    assert c(varabbrev) == "on"

    capture noisily stratetab, using("`blank'") outcomes(1) display
    assert _rc == 198
    assert _N == `n_before'
    assert marker[3] == "safe"
    assert c(varabbrev) == "on"

    capture noisily stratetab, using("`good'" "`mismatch'") outcomes(2) display
    assert _rc == 198
    assert _N == `n_before'
    assert marker[4] == "safe"
    assert c(varabbrev) == "on"
    set varabbrev off
}
if _rc == 0 {
    display as result "  PASS: stratetab rejects duplicate/blank/mismatched categories and restores state"
    local ++pass_count
}
else {
    display as error "  FAIL: stratetab category validation cleanup contract (rc=`=_rc')"
    local ++fail_count
    capture set varabbrev off
}

**# stacktab frame replacement guard preserves caller state

local ++test_count
capture noisily {
    tempfile wb
    local xlsx "`wb'.xlsx"
    _review_build_workbook, xlsx("`xlsx'")

    clear
    set obs 3
    gen byte id = _n
    gen str8 marker = "original"
    capture frame drop occupied_frame
    frame create occupied_frame
    set varabbrev on

    capture noisily stacktab using "`xlsx'", ///
        blocks(sheet(Src) rows(1/2) cols(A-C)) ///
        sheet("Out") frame("occupied_frame") sheetreplace
    assert _rc == 110
    assert _N == 3
    assert marker[2] == "original"
    assert c(varabbrev) == "on"

    stacktab using "`xlsx'", ///
        blocks(sheet(Src) rows(1/2) cols(A-C)) ///
        sheet("Out") frame("occupied_frame, replace") sheetreplace
    assert "`r(frame)'" == "occupied_frame"
    frame occupied_frame: assert _N == 2
    assert _N == 3
    assert marker[1] == "original"
    assert c(varabbrev) == "on"
    set varabbrev off
}
if _rc == 0 {
    display as result "  PASS: stacktab frame replacement guard and replace path preserve state"
    local ++pass_count
}
else {
    display as error "  FAIL: stacktab frame replacement contract (rc=`=_rc')"
    local ++fail_count
    capture set varabbrev off
}
capture frame drop occupied_frame

display as result "Results: `pass_count'/`test_count' passed, `fail_count' failed"

capture ado uninstall tabtools
sysdir set PLUS "`orig_plus'"
sysdir set PERSONAL "`orig_personal'"
discard
capture shell rm -rf "`plus_dir'" "`personal_dir'"

if `fail_count' > 0 {
    display as error "SOME TESTS FAILED"
    display "RESULT: test_review_tables_contracts tests=`test_count' pass=`pass_count' fail=`fail_count'"
    log close _review_tables
    exit 1
}

display as result "ALL TESTS PASSED"
display "RESULT: test_review_tables_contracts tests=`test_count' pass=`pass_count' fail=`fail_count'"
log close _review_tables
