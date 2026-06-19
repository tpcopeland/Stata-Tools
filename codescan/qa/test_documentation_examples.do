* test_documentation_examples.do - README/sthlp documentation reality tests
* Date: 2026-04-17

clear all
set seed 24680
version 16.0

local test_count = 0
local pass_count = 0
local fail_count = 0

* Bootstrap: derive package root from qa/ working directory
local qa_dir "`c(pwd)'"
local pkg_dir = subinstr("`qa_dir'", "/qa", "", 1)

capture ado uninstall codescan
quietly net install codescan, from("`pkg_dir'") replace

capture program drop _load_codescan_setup
program define _load_codescan_setup
    clear
    set obs 5
    gen long pid = .
    gen str6 dx1 = ""
    gen str6 dx2 = ""
    gen str6 proc1 = ""
    gen double visit_dt = .
    gen double index_dt = .

    replace pid = 1 in 1/2
    replace pid = 2 in 3/4
    replace pid = 3 in 5

    replace dx1 = "E110" in 1
    replace dx1 = "Z00"  in 2
    replace dx1 = "I50"  in 3
    replace dx1 = "E102" in 4
    replace dx1 = "Z00"  in 5

    replace dx2 = "I10"  in 1
    replace dx2 = "E119" in 2

    replace proc1 = "XF001" in 1
    replace proc1 = "JFB10" in 3

    replace visit_dt = 21914 in 1
    replace visit_dt = 21880 in 2
    replace visit_dt = 21900 in 3
    replace visit_dt = 22020 in 4
    replace visit_dt = 21910 in 5

    replace index_dt = 21915 in 1/5
    format visit_dt index_dt %td
end

capture program drop _load_describe_setup
program define _load_describe_setup
    clear
    set obs 4
    gen str6 dx1 = ""
    gen str6 dx2 = ""

    replace dx1 = "E110" in 1
    replace dx1 = "E119" in 2
    replace dx1 = "I50"  in 3

    replace dx2 = "I10" in 1
    replace dx2 = "Z00" in 2
end

capture erase "`qa_dir'/dm_rules.csv"
capture erase "`qa_dir'/chapter_rules.csv"
capture erase "`qa_dir'/codescan_results.xlsx"
capture erase "`qa_dir'/codescan_results.dta"

* ============================================================
* README/sthlp examples for codescan
* ============================================================

local ++test_count
capture noisily {
    _load_codescan_setup
    codescan dx1 dx2, define(dm2 "E11" | htn "I1[0-35]" | chf "I50")
    assert dm2 == 1 in 1
    assert htn == 1 in 1
    assert dm2 == 1 in 2
    assert chf == 1 in 3
    assert dm2 == 0 in 4
    assert htn == 0 in 5
}
if _rc == 0 {
    display as result "  PASS: README row-level indicators example"
    local ++pass_count
}
else {
    display as error "  FAIL: README row-level indicators example (error `=_rc')"
    local ++fail_count
}

local ++test_count
capture noisily {
    clear
    input str6 dx1 str6 dx2 str6 proc1
    "E110" "I10" "XF001"
    "E102" "I14" "JFB10"
    "C77"  "C80" ""
    "AE11" "I15" "XF002"
    end

    codescan dx*, define(dm "E1[01]" | htn "I1[0-35]" | metastatic "C7[7-9]|C80")
    assert dm == 1 in 1
    assert dm == 1 in 2
    assert dm == 0 in 3
    assert dm == 0 in 4
    assert htn == 1 in 1
    assert htn == 0 in 2
    assert htn == 0 in 3
    assert htn == 1 in 4
    assert metastatic == 1 in 3

    drop dm htn metastatic
    codescan dx1-dx2, define(dm "E1[01]" | htn "I1[0-35]" | metastatic "C7[7-9]|C80") detail
    assert "`r(varlist)'" == "dx1 dx2"
    matrix VC = r(varcounts)
    assert colsof(VC) == 2
    matrix drop VC

    codescan proc1, define(mammo "XF001|XF002" | colectomy "JFB|JFH") mode(prefix)
    assert mammo == 1 in 1
    assert mammo == 1 in 4
    assert colectomy == 1 in 2
}
if _rc == 0 {
    display as result "  PASS: README beginner regex and varlist examples"
    local ++pass_count
}
else {
    display as error "  FAIL: README beginner regex and varlist examples (error `=_rc')"
    local ++fail_count
}

local ++test_count
capture noisily {
    _load_codescan_setup
    codescan dx1 dx2, id(pid) date(visit_dt) refdate(index_dt) ///
        define(dm2 "E11" | htn "I1[0-35]" | chf "I50") ///
        lookback(365) inclusive collapse alldates
    assert _N == 3
    assert dm2 == 1 if pid == 1
    assert htn == 1 if pid == 1
    assert chf == 0 if pid == 1
    assert dm2_first == 21880 if pid == 1
    assert dm2_last == 21914 if pid == 1
    assert dm2_count == 2 if pid == 1
    assert chf == 1 if pid == 2
    assert chf_first == 21900 if pid == 2
    assert dm2 == 0 if pid == 2
    assert dm2 == 0 if pid == 3
    assert htn == 0 if pid == 3
    assert chf == 0 if pid == 3
}
if _rc == 0 {
    display as result "  PASS: README collapse + window example"
    local ++pass_count
}
else {
    display as error "  FAIL: README collapse + window example (error `=_rc')"
    local ++fail_count
}

local ++test_count
capture noisily {
    _load_codescan_setup
    codescan proc1, define(mammo "XF001|XF002" | colectomy "JFB|JFH") mode(prefix)
    assert mammo == 1 in 1
    assert mammo == 0 in 3
    assert colectomy == 1 in 3
    assert colectomy == 0 in 1
}
if _rc == 0 {
    display as result "  PASS: README prefix example"
    local ++pass_count
}
else {
    display as error "  FAIL: README prefix example (error `=_rc')"
    local ++fail_count
}

local ++test_count
capture noisily {
    _load_codescan_setup
    capture erase "`qa_dir'/codescan_results.xlsx"
    capture erase "`qa_dir'/codescan_results.dta"
    codescan dx1 dx2, define(dm2 "E11" | htn "I1[0-35]") id(pid) collapse ///
        export(codescan_results.xlsx) ///
        saving(codescan_results.dta, replace) ///
        format(%9.2f)

    confirm file "`qa_dir'/codescan_results.xlsx"
    confirm file "`qa_dir'/codescan_results.dta"

    preserve
    use "`qa_dir'/codescan_results.dta", clear
    assert _N == 3
    assert dm2 == 1 if pid == 1
    assert htn == 1 if pid == 1
    assert dm2 == 0 if pid == 2
    assert htn == 0 if pid == 2
    restore

    preserve
    import excel using "`qa_dir'/codescan_results.xlsx", firstrow clear
    confirm variable condition
    confirm variable matches
    confirm variable prevalence
    assert _N == 2
    sort condition
    assert matches == 1 if condition == "dm2"
    assert matches == 1 if condition == "htn"
    assert abs(prevalence - 33.33) < 0.01 if inlist(condition, "dm2", "htn")
    restore
}
if _rc == 0 {
    display as result "  PASS: README export + saving example"
    local ++pass_count
}
else {
    display as error "  FAIL: README export + saving example (error `=_rc')"
    local ++fail_count
}

* ============================================================
* README/sthlp examples for codescan_describe
* ============================================================

local ++test_count
capture noisily {
    _load_describe_setup
    codescan_describe dx1 dx2, top(10)
    assert r(n_unique) == 5
    assert r(n_entries) == 5
    assert r(n_vars) == 2
    matrix TC = r(top_codes)
    assert rowsof(TC) == 5
    assert colsof(TC) == 3
    matrix drop TC
}
if _rc == 0 {
    display as result "  PASS: codescan_describe top(10) example"
    local ++pass_count
}
else {
    display as error "  FAIL: codescan_describe top(10) example (error `=_rc')"
    local ++fail_count
}

local ++test_count
capture noisily {
    _load_describe_setup
    capture erase "`qa_dir'/chapter_rules.csv"
    codescan_describe dx1 dx2, save(chapter_rules.csv)
    confirm file "`qa_dir'/chapter_rules.csv"
    import delimited using "`qa_dir'/chapter_rules.csv", clear
    confirm variable name
    confirm variable pattern
    confirm variable exclusion
    confirm variable label
    count
    assert r(N) == 3
    count if name == "chapter_E" & pattern == "E"
    assert r(N) == 1
}
if _rc == 0 {
    display as result "  PASS: codescan_describe save() example"
    local ++pass_count
}
else {
    display as error "  FAIL: codescan_describe save() example (error `=_rc')"
    local ++fail_count
}

* Regression: help Example 5 / README Example 7 run verbatim. The save() run
* leaves dm2/htn in memory; the codefile re-run on the SAME data must succeed
* (with the documented `replace`) and reproduce identical indicators. Without
* `replace` this stopped with r(110) "variable dm2 already exists".
local ++test_count
capture noisily {
    _load_codescan_setup
    capture erase "`qa_dir'/dm_rules.csv"
    codescan dx1 dx2, define(dm2 "E11" | htn "I1[0-35]") save(dm_rules.csv)
    confirm file "`qa_dir'/dm_rules.csv"
    * Capture the define()-pass indicators before re-running from the codefile
    tempvar dm2_def htn_def
    gen `dm2_def' = dm2
    gen `htn_def' = htn
    * Verbatim documented second line (same in-memory data, no reload)
    codescan dx1 dx2, codefile(dm_rules.csv) replace
    assert dm2 == `dm2_def'
    assert htn == `htn_def'
    capture erase "`qa_dir'/dm_rules.csv"
}
if _rc == 0 {
    display as result "  PASS: save() then codefile() reuse example (Example 5/7)"
    local ++pass_count
}
else {
    display as error "  FAIL: save() then codefile() reuse example (error `=_rc')"
    local ++fail_count
}

display ""
display as result "RESULT: test_documentation_examples tests=`test_count' pass=`pass_count' fail=`fail_count'"
display as result "Test Results: `pass_count'/`test_count' passed, `fail_count' failed"

if `fail_count' > 0 {
    display as error "SOME TESTS FAILED"
    exit 1
}
else {
    display as result "ALL TESTS PASSED"
}
