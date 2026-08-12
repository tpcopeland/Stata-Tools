clear all
set varabbrev off
set more off
version 16.0

capture log close _all
log using "test_comorbidity.log", replace nomsg

do "_comorbidity_qa_common.do"
_comorbidity_qa_bootstrap

local test_count = 0
local pass_count = 0
local fail_count = 0

**# Functional tests

local ++test_count
capture noisily {
    clear
    input long pid str6 dx1 str6 dx2
    1 "I21"  "I50"
    1 "E119" ""
    2 "C780" ""
    end
    comorbidity dx1 dx2, id(pid) charlson(original) collapse
    assert "`r(index)'" == "charlson"
    assert "`r(scheme)'" == "original"
    assert "`r(scorevar)'" == "charlson"
    assert r(N) == 2
    assert charlson[1] == 3
    assert charlson[2] == 6
}
if _rc == 0 {
    display as result "  PASS: Charlson original collapse"
    local ++pass_count
}
else {
    display as error "  FAIL: Charlson original collapse (error `=_rc')"
    local ++fail_count
}

local ++test_count
capture noisily {
    clear
    input long pid str6 dx1 str6 dx2
    1 "I21"  "I50"
    1 "E119" ""
    2 "C780" ""
    end
    comorbidity dx1 dx2, id(pid) charlson(quan2011) collapse
    assert charlson[1] == 2
    assert charlson[2] == 6
    matrix W = r(weights)
    assert W[rownumb(W, "mi"), 1] == 0
    assert W[rownumb(W, "chf"), 1] == 2
}
if _rc == 0 {
    display as result "  PASS: Charlson Quan 2011 collapse"
    local ++pass_count
}
else {
    display as error "  FAIL: Charlson Quan 2011 collapse (error `=_rc')"
    local ++fail_count
}

local ++test_count
capture noisily {
    clear
    input long pid str6 dx1 str6 dx2 str6 dx3
    1 "I50"  "C780" "F11"
    2 "E66"  "F32"  ""
    end
    comorbidity dx1 dx2 dx3, id(pid) elixhauser(vanwalraven) collapse
    assert elixhauser[1] == 12
    assert elixhauser[2] == -7
    matrix W = r(weights)
    assert W[rownumb(W, "chf"), 1] == 7
    assert W[rownumb(W, "metastatic"), 1] == 12
    assert W[rownumb(W, "drug"), 1] == -7
}
if _rc == 0 {
    display as result "  PASS: Elixhauser van Walraven collapse"
    local ++pass_count
}
else {
    display as error "  FAIL: Elixhauser van Walraven collapse (error `=_rc')"
    local ++fail_count
}

local ++test_count
capture noisily {
    clear
    input long pid str6 dx1 str6 dx2
    1 "I21"  "I50"
    1 "E119" ""
    2 "C780" ""
    end
    comorbidity dx1 dx2, id(pid) charlson(original) collapse generate(cmb_) band
    confirm variable cmb_score
    confirm variable cmb_mi
    assert cmb_score[1] == 3
    assert "`r(scorevar)'" == "cmb_score"
    matrix B = r(bands)
    assert B[rownumb(B, "score3_4"), 1] == 1
    assert B[rownumb(B, "score5plus"), 1] == 1
}
if _rc == 0 {
    display as result "  PASS: generate() prefix and band returns"
    local ++pass_count
}
else {
    display as error "  FAIL: generate() prefix and band returns (error `=_rc')"
    local ++fail_count
}

local ++test_count
capture noisily {
    clear
    input long pid str6 dx1 str6 dx2
    1 "I21"  "I50"
    1 "E119" ""
    2 "C780" ""
    end
    gen double cmb_score = -99
    comorbidity dx1 dx2, id(pid) charlson(original) collapse generate(cmb_) replace
    confirm variable cmb_score
    assert cmb_score[1] == 3
    assert cmb_score[2] == 6
    assert "`r(scorevar)'" == "cmb_score"
}
if _rc == 0 {
    display as result "  PASS: replace overwrites existing generated score"
    local ++pass_count
}
else {
    display as error "  FAIL: replace overwrites existing generated score (error `=_rc')"
    local ++fail_count
}

local ++test_count
capture noisily {
    clear
    input long pid str6 dx1 str6 dx2
    1 "I21"  "I50"
    1 "E119" ""
    2 "C780" ""
    end
    comorbidity dx1 dx2, id(pid) charlson(original) collapse noisily
    assert charlson[1] == 3
    assert charlson[2] == 6
    assert "`r(index)'" == "charlson"
}
if _rc == 0 {
    display as result "  PASS: noisily passthrough succeeds"
    local ++pass_count
}
else {
    display as error "  FAIL: noisily passthrough succeeds (error `=_rc')"
    local ++fail_count
}

local ++test_count
capture noisily {
    clear
    input long pid str6 dx1 str6 dx2
    1 "I21"  "I50"
    1 "E119" ""
    2 "C780" ""
    end
    comorbidity dx1 dx2, id(pid) charlson(original) merge
    assert _N == 3
    assert charlson[1] == 3
    assert charlson[2] == 3
    assert charlson[3] == 6
}
if _rc == 0 {
    display as result "  PASS: merge output shape"
    local ++pass_count
}
else {
    display as error "  FAIL: merge output shape (error `=_rc')"
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
    assert pid[1] == 1
    assert charlson[pid == 1] == 2
    assert strpos("`r(conditions)'", "mi") > 0
    assert strpos("`r(conditions)'", "chf") > 0
}
if _rc == 0 {
    display as result "  PASS: date window passthrough and r(conditions)"
    local ++pass_count
}
else {
    display as error "  FAIL: date window passthrough and r(conditions) (error `=_rc')"
    local ++fail_count
}

local ++test_count
capture noisily {
    clear
    input long pid str6 dx1 str6 dx2
    1 "C780" "C509"
    end
    comorbidity dx1 dx2, id(pid) charlson(original) collapse nohierarchy
    assert charlson[1] == 8
    assert r(hierarchy) == 0
}
if _rc == 0 {
    display as result "  PASS: nohierarchy disables supersession"
    local ++pass_count
}
else {
    display as error "  FAIL: nohierarchy disables supersession (error `=_rc')"
    local ++fail_count
}

**# Summary

_comorbidity_result test_comorbidity `test_count' `pass_count' `fail_count'
log close _all
