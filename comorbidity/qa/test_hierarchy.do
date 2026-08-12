clear all
set varabbrev off
set more off
version 16.0

capture log close _all
log using "test_hierarchy.log", replace nomsg

local test_count = 0
local pass_count = 0
local fail_count = 0

local qa_dir "`c(pwd)'"
local pkg_dir = subinstr("`qa_dir'", "/qa", "", 1)
capture ado uninstall comorbidity
do "`pkg_dir'/_comorbidity_hierarchy.ado"

**# Hierarchy rules

local ++test_count
capture noisily {
    clear
    set obs 2
    gen byte dm_comp = (_n == 1)
    gen byte dm_uncomp = 1
    gen byte metastatic = (_n == 1)
    gen byte cancer = 1
    gen byte liver_severe = (_n == 1)
    gen byte liver_mild = 1
    _comorbidity_hierarchy, index(charlson)
    assert dm_uncomp[1] == 0
    assert cancer[1] == 0
    assert liver_mild[1] == 0
    assert dm_uncomp[2] == 1
    assert cancer[2] == 1
    assert liver_mild[2] == 1
}
if _rc == 0 {
    display as result "  PASS: Charlson hierarchy"
    local ++pass_count
}
else {
    display as error "  FAIL: Charlson hierarchy (error `=_rc')"
    local ++fail_count
}

local ++test_count
capture noisily {
    clear
    set obs 1
    gen byte cmb_htn_comp = 1
    gen byte cmb_htn_uncomp = 1
    gen byte cmb_dm_comp = 1
    gen byte cmb_dm_uncomp = 1
    _comorbidity_hierarchy, index(elixhauser) prefix(cmb_)
    assert cmb_htn_uncomp[1] == 0
    assert cmb_dm_uncomp[1] == 0
}
if _rc == 0 {
    display as result "  PASS: Elixhauser prefixed hierarchy"
    local ++pass_count
}
else {
    display as error "  FAIL: Elixhauser prefixed hierarchy (error `=_rc')"
    local ++fail_count
}

**# Summary

do "`qa_dir'/_comorbidity_qa_common.do"
_comorbidity_result test_hierarchy `test_count' `pass_count' `fail_count'
log close _all
