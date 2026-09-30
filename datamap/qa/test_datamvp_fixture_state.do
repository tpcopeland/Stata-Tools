*! validation_datamap_fixture_contract.do -- canonical labelled designs and independent contents
*! Author: Timothy P Copeland, Karolinska Institutet
version 16.0
clear all
set more off
capture log close _all
log using "test_datamvp_fixture_state.log", text replace
local pkg_dir=substr("`c(pwd)'",1,strlen("`c(pwd)'")-3)
adopath ++ "`pkg_dir'"
do _qa_fx_a7.do
do _qa_state.do
local tests 0
local pass 0
local fail 0

**# S_2 undefined pattern
local ++tests
capture noisily {
    * expect: INVARIANT
    qa_fx_a7_labelled, clear seed(37)
    macro drop S_2
    qa_state_snapshot, tag(mvp_s2)
    quietly datamvp x extended all_missing, nodrop
    assert r(N)==40
    qa_state_compare, tag(mvp_s2)
}
if _rc {
    local ++fail
    display as error "FAIL: S_2 undefined pattern; rc=" _rc
}
else {
    local ++pass
    display as result "PASS: S_2 undefined pattern"
}

**# S_2 undefined no_missing
local ++tests
capture noisily {
    * expect: INVARIANT
    qa_fx_a7_labelled, clear seed(37)
    macro drop S_2
    qa_state_snapshot, tag(mvp_s2)
    quietly datamvp x
    assert r(N)==40
    qa_state_compare, tag(mvp_s2)
}
if _rc {
    local ++fail
    display as error "FAIL: S_2 undefined no_missing; rc=" _rc
}
else {
    local ++pass
    display as result "PASS: S_2 undefined no_missing"
}

**# S_2 undefined early_refusal
local ++tests
capture noisily {
    * expect: REFUSED
    qa_fx_a7_labelled, clear seed(37)
    macro drop S_2
    qa_state_snapshot, tag(mvp_s2)
    capture noisily datamvp x all_missing, mincell(-1)
    assert _rc==198
    qa_state_compare, tag(mvp_s2)
}
if _rc {
    local ++fail
    display as error "FAIL: S_2 undefined early_refusal; rc=" _rc
}
else {
    local ++pass
    display as result "PASS: S_2 undefined early_refusal"
}

**# S_2 undefined late_refusal
local ++tests
capture noisily {
    * expect: REFUSED
    qa_fx_a7_labelled, clear seed(37)
    macro drop S_2
    qa_state_snapshot, tag(mvp_s2)
    capture noisily datamvp x all_missing, graph(bar) graphoptions(qa_invalid_option)
    assert _rc==198
    qa_state_compare, tag(mvp_s2)
}
if _rc {
    local ++fail
    display as error "FAIL: S_2 undefined late_refusal; rc=" _rc
}
else {
    local ++pass
    display as result "PASS: S_2 undefined late_refusal"
}

**# S_2 existing pattern
local ++tests
capture noisily {
    * expect: INVARIANT
    qa_fx_a7_labelled, clear seed(37)
    global S_2 "CALLER_KEEP"
    qa_state_snapshot, tag(mvp_s2)
    quietly datamvp x extended all_missing, nodrop
    assert r(N)==40
    qa_state_compare, tag(mvp_s2)
}
if _rc {
    local ++fail
    display as error "FAIL: S_2 existing pattern; rc=" _rc
}
else {
    local ++pass
    display as result "PASS: S_2 existing pattern"
}

**# S_2 existing no_missing
local ++tests
capture noisily {
    * expect: INVARIANT
    qa_fx_a7_labelled, clear seed(37)
    global S_2 "CALLER_KEEP"
    qa_state_snapshot, tag(mvp_s2)
    quietly datamvp x
    assert r(N)==40
    qa_state_compare, tag(mvp_s2)
}
if _rc {
    local ++fail
    display as error "FAIL: S_2 existing no_missing; rc=" _rc
}
else {
    local ++pass
    display as result "PASS: S_2 existing no_missing"
}

**# S_2 existing early_refusal
local ++tests
capture noisily {
    * expect: REFUSED
    qa_fx_a7_labelled, clear seed(37)
    global S_2 "CALLER_KEEP"
    qa_state_snapshot, tag(mvp_s2)
    capture noisily datamvp x all_missing, mincell(-1)
    assert _rc==198
    qa_state_compare, tag(mvp_s2)
}
if _rc {
    local ++fail
    display as error "FAIL: S_2 existing early_refusal; rc=" _rc
}
else {
    local ++pass
    display as result "PASS: S_2 existing early_refusal"
}

**# S_2 existing late_refusal
local ++tests
capture noisily {
    * expect: REFUSED
    qa_fx_a7_labelled, clear seed(37)
    global S_2 "CALLER_KEEP"
    qa_state_snapshot, tag(mvp_s2)
    capture noisily datamvp x all_missing, graph(bar) graphoptions(qa_invalid_option)
    assert _rc==198
    qa_state_compare, tag(mvp_s2)
}
if _rc {
    local ++fail
    display as error "FAIL: S_2 existing late_refusal; rc=" _rc
}
else {
    local ++pass
    display as result "PASS: S_2 existing late_refusal"
}
display "RESULT: test_datamvp_fixture_state tests=`tests' pass=`pass' fail=`fail'"
log close
if `fail' exit 1
