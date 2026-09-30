*! test_corrtab_fixture_stars.do -- explicit star counts and refusal state
*! Author: Timothy P Copeland, Karolinska Institutet
version 17
clear all
set more off
capture log close _all
log using test_corrtab_fixture_stars.log, text replace
local pkg_dir=substr("`c(pwd)'",1,strlen("`c(pwd)'")-3)
adopath ++ "`pkg_dir'"
do _qa_fx_a7.do
do _qa_state.do
program define _tt_seed_r, rclass
    args kind
    return clear
    if "`kind'"=="empty" exit
    tempname payload
    matrix `payload'=(1,-2\3,4)
    matrix rownames `payload'=First second
    matrix colnames `payload'=X y
    return scalar exact=123.125
    return scalar extended=.a
    local opaque ""
    mata: st_local("opaque",char(36)+"UNSET"+char(96)+"missing"+char(39)+char(34)+"opaque")
    return local bytes `"`macval(opaque)'"'
    return matrix payload=`payload'
end
local tests 0
local pass 0
local fail 0
python:
from pathlib import Path
from sfi import Macro
end

**# 1 significance thresholds
local ++tests
capture noisily {
    qa_fx_a7_labelled, clear seed(37)
    _tt_seed_r full
    qa_state_snapshot, tag(stars)
    * expect: EXACT
    corrtab x id, full star(0.05) frame(star_frame)
    tempname cc nn
    matrix `cc'=r(C)
    matrix `nn'=r(N)
    assert !missing(`cc'[1,2]) & abs(`cc'[1,2]-1)<1e-12 & `nn'[1,2]==40
    * Forty distinct identical pairs: Pearsonr1 with p0; every threshold
    * is passed, so the exact number of stars equals the option-list length.
    frame star_frame: assert c2[4]=="1.00*" & c3[3]=="1.00*"
    frame drop star_frame
    matrix drop `cc' `nn'
    qa_state_compare, tag(stars)
}
local outcome=_rc
capture frame drop star_frame
if `outcome' {
    local ++fail
    display as error "FAIL: 1 thresholds rc=" `outcome'
}
else {
    local ++pass
    display as result "PASS: 1 thresholds"
}

**# 2 significance thresholds
local ++tests
capture noisily {
    qa_fx_a7_labelled, clear seed(37)
    _tt_seed_r full
    qa_state_snapshot, tag(stars)
    * expect: EXACT
    corrtab x id, full star(0.01 0.05) frame(star_frame)
    tempname cc nn
    matrix `cc'=r(C)
    matrix `nn'=r(N)
    assert !missing(`cc'[1,2]) & abs(`cc'[1,2]-1)<1e-12 & `nn'[1,2]==40
    * Forty distinct identical pairs: Pearsonr1 with p0; every threshold
    * is passed, so the exact number of stars equals the option-list length.
    frame star_frame: assert c2[4]=="1.00**" & c3[3]=="1.00**"
    frame drop star_frame
    matrix drop `cc' `nn'
    qa_state_compare, tag(stars)
}
local outcome=_rc
capture frame drop star_frame
if `outcome' {
    local ++fail
    display as error "FAIL: 2 thresholds rc=" `outcome'
}
else {
    local ++pass
    display as result "PASS: 2 thresholds"
}

**# 3 significance thresholds
local ++tests
capture noisily {
    qa_fx_a7_labelled, clear seed(37)
    _tt_seed_r full
    qa_state_snapshot, tag(stars)
    * expect: EXACT
    corrtab x id, full star(0.001 0.01 0.05) frame(star_frame)
    tempname cc nn
    matrix `cc'=r(C)
    matrix `nn'=r(N)
    assert !missing(`cc'[1,2]) & abs(`cc'[1,2]-1)<1e-12 & `nn'[1,2]==40
    * Forty distinct identical pairs: Pearsonr1 with p0; every threshold
    * is passed, so the exact number of stars equals the option-list length.
    frame star_frame: assert c2[4]=="1.00***" & c3[3]=="1.00***"
    frame drop star_frame
    matrix drop `cc' `nn'
    qa_state_compare, tag(stars)
}
local outcome=_rc
capture frame drop star_frame
if `outcome' {
    local ++fail
    display as error "FAIL: 3 thresholds rc=" `outcome'
}
else {
    local ++pass
    display as result "PASS: 3 thresholds"
}

**# Refuse four threshold list
local ++tests
capture noisily {
    qa_fx_a7_labelled, clear seed(37)
    tempfile causefile
    capture log close star_cause
    log using `"`causefile'"', text replace name(star_cause)
    _tt_seed_r full
    qa_state_snapshot, tag(stars) rreturn
    * expect: REFUSED
    capture noisily corrtab x id, full star(0.1 0.2 0.3 0.4) frame(star_frame)
    local call_rc=_rc
    qa_state_compare, tag(stars)
    assert `call_rc'==198
    log close star_cause
    python: assert 'star() permits at most 3 unique thresholds' in Path(Macro.getLocal('causefile')).read_text()
}
local outcome=_rc
capture log close star_cause
capture frame drop star_frame
if `outcome' {
    local ++fail
    display as error "FAIL: refuse four rc=" `outcome'
}
else {
    local ++pass
    display as result "PASS: refuse four"
}

**# Refuse duplicate threshold list
local ++tests
capture noisily {
    qa_fx_a7_labelled, clear seed(37)
    tempfile causefile
    capture log close star_cause
    log using `"`causefile'"', text replace name(star_cause)
    _tt_seed_r full
    qa_state_snapshot, tag(stars) rreturn
    * expect: REFUSED
    capture noisily corrtab x id, full star(0.1 0.1) frame(star_frame)
    local call_rc=_rc
    qa_state_compare, tag(stars)
    assert `call_rc'==198
    log close star_cause
    python: assert 'star() thresholds must be strictly increasing' in Path(Macro.getLocal('causefile')).read_text()
}
local outcome=_rc
capture log close star_cause
capture frame drop star_frame
if `outcome' {
    local ++fail
    display as error "FAIL: refuse duplicate rc=" `outcome'
}
else {
    local ++pass
    display as result "PASS: refuse duplicate"
}

display "RESULT: test_corrtab_fixture_stars tests=`tests' pass=`pass' fail=`fail'"
log close _all
if `fail' exit 1
