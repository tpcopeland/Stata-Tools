clear all
set varabbrev off
set more off
version 16.0

capture log close _all
log using "validation_comorbidity.log", replace nomsg

do "_comorbidity_qa_common.do"
_comorbidity_qa_bootstrap

local test_count = 0
local pass_count = 0
local fail_count = 0

**# Known-answer validation

local ++test_count
capture noisily {
    clear
    input long pid str6 dx1 str6 dx2 str6 dx3 str6 dx4 str6 dx5
    1 "I21" "I50" "E119" "C780" "C509"
    end
    comorbidity dx1 dx2 dx3 dx4 dx5, id(pid) charlson(original) collapse
    assert charlson[1] == 9
    assert cancer[1] == 0
    assert metastatic[1] == 1
    matrix W = r(weights)
    assert W[rownumb(W, "mi"), 1] == 1
    assert W[rownumb(W, "metastatic"), 1] == 6
}
if _rc == 0 {
    display as result "  PASS: Charlson original known answer with hierarchy"
    local ++pass_count
}
else {
    display as error "  FAIL: Charlson original known answer (error `=_rc')"
    local ++fail_count
}

local ++test_count
capture noisily {
    clear
    input long pid str6 dx1 str6 dx2 str6 dx3 str6 dx4 str6 dx5
    1 "I21" "I50" "E119" "C780" "C509"
    end
    comorbidity dx1 dx2 dx3 dx4 dx5, id(pid) charlson(quan2011) collapse
    assert charlson[1] == 8
    matrix W = r(weights)
    assert W[rownumb(W, "mi"), 1] == 0
    assert W[rownumb(W, "chf"), 1] == 2
    assert W[rownumb(W, "dm_uncomp"), 1] == 0
}
if _rc == 0 {
    display as result "  PASS: Charlson Quan 2011 known answer"
    local ++pass_count
}
else {
    display as error "  FAIL: Charlson Quan 2011 known answer (error `=_rc')"
    local ++fail_count
}

local ++test_count
capture noisily {
    clear
    input long pid str6 dx1 str6 dx2 str6 dx3 str6 dx4
    1 "I50" "C780" "F11" "E66"
    end
    comorbidity dx1 dx2 dx3 dx4, id(pid) elixhauser(vanwalraven) collapse
    assert elixhauser[1] == 8
    matrix W = r(weights)
    assert W[rownumb(W, "chf"), 1] == 7
    assert W[rownumb(W, "metastatic"), 1] == 12
    assert W[rownumb(W, "drug"), 1] == -7
    assert W[rownumb(W, "obesity"), 1] == -4
}
if _rc == 0 {
    display as result "  PASS: Elixhauser van Walraven known answer"
    local ++pass_count
}
else {
    display as error "  FAIL: Elixhauser van Walraven known answer (error `=_rc')"
    local ++fail_count
}

local ++test_count
capture noisily {
    clear
    input long pid str6 dx1 str6 dx2
    1 "I21" "I50"
    2 "E119" ""
    end
    tempfile cf
    preserve
    clear
    input str12 name str20 pattern double weight
    "mi" "I21|I22" 10
    "chf" "I50" 2
    "dm" "E11" 4
    end
    save "`cf'.dta", replace
    restore
    comorbidity dx1 dx2, id(pid) custom("`cf'.dta") collapse
    assert custom[1] == 12
    assert custom[2] == 4
}
if _rc == 0 {
    display as result "  PASS: custom weighted codefile known answer"
    local ++pass_count
}
else {
    display as error "  FAIL: custom weighted codefile known answer (error `=_rc')"
    local ++fail_count
}

**# Summary

_comorbidity_result validation_comorbidity `test_count' `pass_count' `fail_count'
log close _all
