* test_codescan_install_docs.do - Installed-user documentation and artifact checks

clear all
set seed 13579
version 16.0
set varabbrev off

local test_count = 0
local pass_count = 0
local fail_count = 0

local qa_dir "`c(pwd)'"
local pkg_dir = subinstr("`qa_dir'", "/qa", "", 1)

tempfile marker
local sandbox "`marker'_dir"
local plus "`sandbox'/plus"
local personal "`sandbox'/personal"
local work "`sandbox'/work"

local old_plus "`c(sysdir_plus)'"
local old_personal "`c(sysdir_personal)'"
local old_dir "`c(pwd)'"

capture mkdir "`sandbox'"
capture mkdir "`plus'"
capture mkdir "`personal'"
capture mkdir "`work'"

sysdir set PLUS "`plus'"
sysdir set PERSONAL "`personal'"
cd "`work'"

capture program drop _load_codescan_doc_data
program define _load_codescan_doc_data
    version 16.0
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

capture program drop _load_codescan_describe_doc_data
program define _load_codescan_describe_doc_data
    version 16.0
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

* This suite deliberately does NOT use the shared QA bootstrap. It builds its
* own PLUS/PERSONAL/work sandbox above and cd's into it, because the whole
* point is to exercise the package as a freshly installed user sees it. The
* shared scaffold derives pkg_dir from c(pwd), which is the work dir by this
* line, so it would install from the wrong place. pkg_dir here was captured
* before the cd and is absolute.
capture ado uninstall codescan
quietly net install codescan, from("`pkg_dir'") replace

* Session settings captured for the hygiene check at the end of this suite.
* The expected pwd is old_dir, NOT c(pwd): this suite is already inside its
* sandbox work dir by this line and cd's back before its summary, so anchoring
* on old_dir makes the hygiene check prove that restore actually happened.
local _qa_level0 = c(level)
local _qa_va0 "`c(varabbrev)'"
local _qa_pwd0 "`old_dir'"

**# Installed package surface

local ++test_count
capture noisily {
    which codescan
    which codescan_describe
    findfile codescan.sthlp
    findfile codescan_describe.sthlp
    help codescan
    help codescan_describe
}
if _rc == 0 {
    display as result "  PASS: installed commands and help resolve"
    local ++pass_count
}
else {
    display as error "  FAIL: installed commands and help resolve (error `=_rc')"
    local ++fail_count
}


**# README and help examples as installed workflows

local ++test_count
capture noisily {
    _load_codescan_describe_doc_data
    codescan_describe dx1 dx2, top(10)
    assert r(n_unique) == 5
    assert r(n_entries) == 5
    assert r(n_vars) == 2
    matrix TC = r(top_codes)
    matrix CH = r(chapters)
    assert rowsof(TC) == 5
    assert colsof(TC) == 3
    assert rowsof(CH) == 3
    assert colsof(CH) == 2
    matrix drop TC CH
}
if _rc == 0 {
    display as result "  PASS: codescan_describe help example returns expected matrices"
    local ++pass_count
}
else {
    display as error "  FAIL: codescan_describe help example (error `=_rc')"
    local ++fail_count
}

local ++test_count
capture noisily {
    _load_codescan_describe_doc_data
    capture erase "chapter_rules.csv"
    codescan_describe dx1 dx2, save(chapter_rules.csv)
    import delimited using "chapter_rules.csv", clear varnames(1)
    confirm variable name
    confirm variable pattern
    confirm variable exclusion
    confirm variable label
    assert _N == 3
    count if name == "chapter_E" & pattern == "E" & missing(exclusion)
    assert r(N) == 1
    count if name == "chapter_I" & pattern == "I" & missing(exclusion)
    assert r(N) == 1
    count if name == "chapter_Z" & pattern == "Z" & missing(exclusion)
    assert r(N) == 1
}
if _rc == 0 {
    display as result "  PASS: codescan_describe save() export has expected content"
    local ++pass_count
}
else {
    display as error "  FAIL: codescan_describe save() export content (error `=_rc')"
    local ++fail_count
}

local ++test_count
capture noisily {
    _load_codescan_doc_data
    codescan dx1 dx2, define(dm2 "E11" | htn "I1[0-35]" | chf "I50")
    assert dm2 == 1 in 1
    assert htn == 1 in 1
    assert dm2 == 1 in 2
    assert chf == 1 in 3
    assert dm2 == 0 in 4
    assert htn == 0 in 5
}
if _rc == 0 {
    display as result "  PASS: README row-level example produces documented indicators"
    local ++pass_count
}
else {
    display as error "  FAIL: README row-level example (error `=_rc')"
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
    display as result "  PASS: beginner regex and varlist examples work after install"
    local ++pass_count
}
else {
    display as error "  FAIL: beginner regex and varlist installed examples (error `=_rc')"
    local ++fail_count
}

local ++test_count
capture noisily {
    _load_codescan_doc_data
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
}
if _rc == 0 {
    display as result "  PASS: README collapse/window example has documented values"
    local ++pass_count
}
else {
    display as error "  FAIL: README collapse/window example (error `=_rc')"
    local ++fail_count
}

local ++test_count
capture noisily {
    _load_codescan_doc_data
    codescan proc1, define(mammo "XF001|XF002" | colectomy "JFB|JFH") mode(prefix)
    assert mammo == 1 in 1
    assert mammo == 0 in 3
    assert colectomy == 1 in 3
    assert colectomy == 0 in 1
}
if _rc == 0 {
    display as result "  PASS: README prefix example has documented values"
    local ++pass_count
}
else {
    display as error "  FAIL: README prefix example (error `=_rc')"
    local ++fail_count
}

local ++test_count
capture noisily {
    _load_codescan_doc_data
    capture erase "dm_rules.csv"
    codescan dx1 dx2, define(dm2 "E11" | htn "I1[0-35]") save(dm_rules.csv)
    import delimited using "dm_rules.csv", clear varnames(1)
    confirm variable name
    confirm variable pattern
    confirm variable exclusion
    confirm variable label
    assert _N == 2
    count if name == "dm2" & pattern == "E11" & missing(exclusion)
    assert r(N) == 1
    count if name == "htn" & pattern == "I1[0-35]" & missing(exclusion)
    assert r(N) == 1

    _load_codescan_doc_data
    codescan dx1 dx2, codefile(dm_rules.csv)
    assert dm2 == 1 in 1
    assert htn == 1 in 1
    assert dm2 == 1 in 2
    assert htn == 0 in 5
}
if _rc == 0 {
    display as result "  PASS: save() CSV round-trip has expected content"
    local ++pass_count
}
else {
    display as error "  FAIL: save() CSV round-trip content (error `=_rc')"
    local ++fail_count
}

**# Exported artifacts

local ++test_count
capture noisily {
    _load_codescan_doc_data
    capture erase "codescan_results.csv"
    codescan dx1 dx2, define(dm2 "E11" | htn "I1[0-35]") ///
        export(codescan_results.csv) format(%9.1f)
    import delimited using "codescan_results.csv", clear varnames(1)
    confirm variable condition
    confirm variable matches
    confirm variable prevalence
    confirm variable ci_low
    confirm variable ci_high
    confirm variable pattern
    confirm variable exclusion
    assert _N == 2
    count if condition == "dm2" & matches == 2 & abs(prevalence - 40) < 1e-8 & pattern == "E11"
    assert r(N) == 1
    count if condition == "htn" & matches == 1 & abs(prevalence - 20) < 1e-8 & pattern == "I1[0-35]"
    assert r(N) == 1
    assert inrange(ci_low, 0, 100)
    assert inrange(ci_high, 0, 100)
}
if _rc == 0 {
    display as result "  PASS: export() CSV has expected installed-user content"
    local ++pass_count
}
else {
    display as error "  FAIL: export() CSV content (error `=_rc')"
    local ++fail_count
}

local ++test_count
capture noisily {
    _load_codescan_doc_data
    capture erase "codescan_results.xlsx"
    capture erase "codescan_results.dta"
    codescan dx1 dx2, define(dm2 "E11" | htn "I1[0-35]") id(pid) collapse ///
        export(codescan_results.xlsx) ///
        saving(codescan_results.dta, replace) ///
        format(%9.2f)

    preserve
    use "codescan_results.dta", clear
    assert _N == 3
    assert dm2 == 1 if pid == 1
    assert htn == 1 if pid == 1
    assert dm2 == 0 if pid == 2
    assert htn == 0 if pid == 2
    assert dm2 == 0 if pid == 3
    assert htn == 0 if pid == 3
    restore

    preserve
    import excel using "codescan_results.xlsx", firstrow clear
    confirm variable condition
    confirm variable matches
    confirm variable prevalence
    confirm variable ci_low
    confirm variable ci_high
    assert _N == 2
    count if condition == "dm2" & matches == 1 & abs(prevalence - 33.33) < 0.01
    assert r(N) == 1
    count if condition == "htn" & matches == 1 & abs(prevalence - 33.33) < 0.01
    assert r(N) == 1
    restore
}
if _rc == 0 {
    display as result "  PASS: export() XLSX and saving() DTA have expected content"
    local ++pass_count
}
else {
    display as error "  FAIL: export() XLSX/saving() DTA content (error `=_rc')"
    local ++fail_count
}

local ++test_count
capture noisily {
    _load_codescan_doc_data
    capture erase "codescan_cooc.xlsx"
    codescan dx1 dx2, define(dm2 "E11" | htn "I1[0-35]") cooccurrence ///
        export(codescan_cooc.xlsx) format(%9.0f)

    import excel using "codescan_cooc.xlsx", sheet("cooccurrence") firstrow clear
    confirm variable condition
    confirm variable dm2
    confirm variable htn
    assert _N == 2
    count if condition == "dm2" & dm2 == 2 & htn == 1
    assert r(N) == 1
    count if condition == "htn" & dm2 == 1 & htn == 1
    assert r(N) == 1
}
if _rc == 0 {
    display as result "  PASS: export() XLSX cooccurrence sheet has expected content"
    local ++pass_count
}
else {
    display as error "  FAIL: export() XLSX cooccurrence content (error `=_rc')"
    local ++fail_count
}

**# Cleanup and summary

cd "`old_dir'"
sysdir set PLUS "`old_plus'"
sysdir set PERSONAL "`old_personal'"
capture shell rm -rf "`sandbox'"

display ""

**# Settings hygiene

* This suite must not leak a session setting to whatever runs next.
local ++test_count
capture noisily {
    assert c(level) == `_qa_level0'
    assert "`c(varabbrev)'" == "`_qa_va0'"
    assert "`c(pwd)'" == "`_qa_pwd0'"
}
if _rc == 0 {
    display as result "  PASS: no session setting leaked"
    local ++pass_count
}
else {
    display as error "  FAIL: session setting leaked (error `=_rc')"
    local ++fail_count
}


global CODESCAN_QA_RESULT_NAME "test_codescan_install_docs"
global CODESCAN_QA_RESULT_TESTS "`test_count'"
global CODESCAN_QA_RESULT_PASS "`pass_count'"
global CODESCAN_QA_RESULT_FAIL "`fail_count'"
display as result "RESULT: test_codescan_install_docs tests=`test_count' pass=`pass_count' fail=`fail_count'"
display as result "Test Results: `pass_count'/`test_count' passed, `fail_count' failed"

if `fail_count' > 0 {
    display as error "SOME TESTS FAILED"
    exit 1
}
else {
    display as result "ALL TESTS PASSED"
}
