*! Executable coverage for comorbidity help and README examples
*! Author: Timothy P Copeland, Karolinska Institutet

clear all
set varabbrev off
set more off
version 16.0

capture log close _all
log using "test_documentation_examples.log", replace nomsg

do "_comorbidity_qa_common.do"
_comorbidity_qa_bootstrap

local test_count = 0
local pass_count = 0
local fail_count = 0

**# Documented workflows

local ++test_count
capture noisily {
    clear
    input long pid str6 dx1 str6 dx2
    1 "I21" "I50"
    1 "E119" ""
    2 "C780" ""
    end
    comorbidity dx1 dx2, id(pid) charlson(original) collapse band
    matrix list r(bands)
    assert charlson[1] == 3
    assert charlson[2] == 6
    matrix B = r(bands)
    assert B[rownumb(B, "score3_4"), colnumb(B, "n")] == 1
    assert B[rownumb(B, "score5plus"), colnumb(B, "n")] == 1
}
if _rc == 0 {
    display as result "  PASS: documented Charlson collapse workflow"
    local ++pass_count
}
else {
    display as error "  FAIL: documented Charlson collapse workflow (error `=_rc')"
    local ++fail_count
}

local ++test_count
capture noisily {
    clear
    input long pid str6 dx1 str6 dx2 str6 dx3
    1 "I50" "C780" "F11"
    2 "E66" "F32" ""
    end
    comorbidity dx1 dx2 dx3, id(pid) elixhauser(vanwalraven) collapse ///
        generate(elx_) band
    matrix list r(bands)
    assert elx_score[1] == 12
    assert elx_score[2] == -7
    matrix B = r(bands)
    assert B[rownumb(B, "score_negative"), colnumb(B, "n")] == 1
}
if _rc == 0 {
    display as result "  PASS: documented Elixhauser and negative-band workflow"
    local ++pass_count
}
else {
    display as error "  FAIL: documented Elixhauser workflow (error `=_rc')"
    local ++fail_count
}

local ++test_count
capture noisily {
    clear
    input long pid str6 dx1 str6 dx2
    1 "I21" "I50"
    1 "E119" ""
    2 "C780" ""
    end
    comorbidity dx1 dx2, id(pid) charlson(quan2011) merge generate(cmb_)
    assert _N == 3
    assert cmb_score[1] == 2
    assert cmb_score[2] == 2
    assert cmb_score[3] == 6
}
if _rc == 0 {
    display as result "  PASS: documented merge and generate workflow"
    local ++pass_count
}
else {
    display as error "  FAIL: documented merge workflow (error `=_rc')"
    local ++fail_count
}

local ++test_count
capture noisily {
    clear
    input long pid str6 dx1 int dxdate int refdate
    1 "I50" 21910 21915
    1 "I21" 21885 21915
    2 "I50" 21550 21915
    end
    format dxdate refdate %td
    comorbidity dx1, id(pid) charlson(original) collapse ///
        date(dxdate) refdate(refdate) lookback(30) lookforward(10) inclusive
    assert _N == 1
    assert charlson[1] == 2
}
if _rc == 0 {
    display as result "  PASS: documented date-window workflow"
    local ++pass_count
}
else {
    display as error "  FAIL: documented date-window workflow (error `=_rc')"
    local ++fail_count
}

local ++test_count
capture noisily {
    clear
    input long pid str6 dx1 str6 dx2
    1 "I21" "I50"
    2 "E119" ""
    end
    tempfile custom_codes
    preserve
    clear
    input str12 name str20 pattern double weight
    "mi" "I21|I22" 10
    "chf" "I50" 2
    "dm" "E11" 4
    end
    save "`custom_codes'.dta", replace
    restore
    comorbidity dx1 dx2, id(pid) custom("`custom_codes'.dta") collapse
    assert custom[1] == 12
    assert custom[2] == 4
}
if _rc == 0 {
    display as result "  PASS: documented custom-codefile workflow"
    local ++pass_count
}
else {
    display as error "  FAIL: documented custom-codefile workflow (error `=_rc')"
    local ++fail_count
}

local ++test_count
capture noisily {
    assert strpos(fileread("../README.md"), ///
        "raw.githubusercontent.com/tpcopeland/Stata-Tools/main/codescan") > 0
    assert strpos(fileread("../README.md"), ///
        "raw.githubusercontent.com/tpcopeland/Stata-Tools/main/comorbidity") > 0
    assert strpos(fileread("../README.md"), "ssc install codescan") == 0
    assert strpos(fileread("../README.md"), "Stata" + "-Dev") == 0
}
if _rc == 0 {
    display as result "  PASS: documented install workflow is release-safe"
    local ++pass_count
}
else {
    display as error "  FAIL: documented install workflow is release-safe (error `=_rc')"
    local ++fail_count
}

**# Summary

_comorbidity_result test_documentation_examples `test_count' `pass_count' `fail_count'
log close _all
