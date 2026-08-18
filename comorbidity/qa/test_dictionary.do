clear all
set varabbrev off
set more off
version 16.0

capture log close _all
log using "test_dictionary.log", replace nomsg

local test_count = 0
local pass_count = 0
local fail_count = 0

local qa_dir "`c(pwd)'"
local pkg_dir = regexr("`qa_dir'", "/qa$", "")
capture ado uninstall comorbidity
do "`pkg_dir'/_comorbidity_dictionary.ado"

**# Dictionary shape

local ++test_count
capture noisily {
    tempfile d
    _comorbidity_dictionary, index(charlson) target("`d'.dta")
    preserve
    use "`d'.dta", clear
    count
    assert r(N) == 17
    confirm string variable name
    confirm string variable pattern
    confirm string variable label
    restore
}
if _rc == 0 {
    display as result "  PASS: Charlson dictionary has 17 rows and required columns"
    local ++pass_count
}
else {
    display as error "  FAIL: Charlson dictionary shape (error `=_rc')"
    local ++fail_count
}

local ++test_count
capture noisily {
    tempfile d
    _comorbidity_dictionary, index(elixhauser_vw) target("`d'.dta")
    preserve
    use "`d'.dta", clear
    count
    assert r(N) == 31
    assert name[1] == "chf"
    assert name[31] == "depression"
    restore
}
if _rc == 0 {
    display as result "  PASS: Elixhauser van Walraven dictionary has 31 rows"
    local ++pass_count
}
else {
    display as error "  FAIL: Elixhauser dictionary shape (error `=_rc')"
    local ++fail_count
}

local ++test_count
capture noisily {
    tempfile d
    capture _comorbidity_dictionary, index(elixhauser_ahrq) target("`d'.dta")
    assert _rc == 198
}
if _rc == 0 {
    display as result "  PASS: AHRQ dictionary is explicitly guarded"
    local ++pass_count
}
else {
    display as error "  FAIL: AHRQ dictionary guard (error `=_rc')"
    local ++fail_count
}

**# Summary

do "`qa_dir'/_comorbidity_qa_common.do"
_comorbidity_result test_dictionary `test_count' `pass_count' `fail_count'
log close _all
