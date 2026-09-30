*! validation_qba_fixture_domains.do -- actual sensitivity/prevalence domain endpoints
*! Author: Timothy P Copeland, Karolinska Institutet
* Forward outcome-classification cells and prevalence-weighted risks derive
* independent targets. Fox2023 Methods/Table1 fetched2026-09-30:
* https://academic.oup.com/ije/article/52/5/1624/7152433
version 16.0
clear all
set more off
capture log close _all
log using validation_qba_fixture_domains.log, text replace
local pkg_dir=substr("`c(pwd)'",1,strlen("`c(pwd)'")-3)
adopath ++ "`pkg_dir'"
do _qa_fx_a6.do
do _qa_state.do
local tests 0
local pass 0
local fail 0

**# base_se .000001
local ++tests
capture noisily {
    qa_fx_a6_bias, clear seed(37) perturb(boundary_values)
    local a=40*.000001
    local b=20*.000001
    local c=100-`a'
    local d=100-`b'
    qa_state_snapshot, tag(qba_domains)
    * expect: EXACT
    quietly qba_plot, tornado a(`a') b(`b') c(`c') d(`d') type(outcome) param1(sp) range1(1 1) base_se(.000001) steps(2)
    assert r(n_missing)==0
    qa_state_compare, tag(qba_domains)
    serset
    assert r(N)==2 & r(k)==2
    preserve
    serset use, clear
    sort param_value
    assert param_value==1 & !missing(corrected)
    assert abs(corrected-8/3)<1e-8
    restore
}
local outcome=_rc
capture restore
if `outcome' {
    local ++fail
    display as error "FAIL: base_se .000001 rc=" `outcome'
}
else {
    local ++pass
    display as result "PASS: base_se .000001"
}

**# base_se .5
local ++tests
capture noisily {
    qa_fx_a6_bias, clear seed(37) perturb(boundary_values)
    local a=40*.5
    local b=20*.5
    local c=100-`a'
    local d=100-`b'
    qa_state_snapshot, tag(qba_domains)
    * expect: EXACT
    quietly qba_plot, tornado a(`a') b(`b') c(`c') d(`d') type(outcome) param1(sp) range1(1 1) base_se(.5) steps(2)
    assert r(n_missing)==0
    qa_state_compare, tag(qba_domains)
    serset
    assert r(N)==2 & r(k)==2
    preserve
    serset use, clear
    sort param_value
    assert param_value==1 & !missing(corrected)
    assert abs(corrected-8/3)<1e-8
    restore
}
local outcome=_rc
capture restore
if `outcome' {
    local ++fail
    display as error "FAIL: base_se .5 rc=" `outcome'
}
else {
    local ++pass
    display as result "PASS: base_se .5"
}

**# base_se 1
local ++tests
capture noisily {
    qa_fx_a6_bias, clear seed(37) perturb(boundary_values)
    local a=40*1
    local b=20*1
    local c=100-`a'
    local d=100-`b'
    qa_state_snapshot, tag(qba_domains)
    * expect: EXACT
    quietly qba_plot, tornado a(`a') b(`b') c(`c') d(`d') type(outcome) param1(sp) range1(1 1) base_se(1) steps(2)
    assert r(n_missing)==0
    qa_state_compare, tag(qba_domains)
    serset
    assert r(N)==2 & r(k)==2
    preserve
    serset use, clear
    sort param_value
    assert param_value==1 & !missing(corrected)
    assert abs(corrected-8/3)<1e-8
    restore
}
local outcome=_rc
capture restore
if `outcome' {
    local ++fail
    display as error "FAIL: base_se 1 rc=" `outcome'
}
else {
    local ++pass
    display as result "PASS: base_se 1"
}

**# base_se 0
local ++tests
capture noisily {
    qa_fx_a6_bias, clear seed(37) perturb(boundary_values)
    local a=40*.5
    local b=20*.5
    local c=100-`a'
    local d=100-`b'
    qa_state_snapshot, tag(qba_domains)
    * expect: REFUSED
    capture noisily qba_plot, tornado a(`a') b(`b') c(`c') d(`d') type(outcome) param1(sp) range1(1 1) base_se(0) steps(2)
    assert _rc==198
    qa_state_compare, tag(qba_domains)
}
local outcome=_rc
capture restore
if `outcome' {
    local ++fail
    display as error "FAIL: base_se 0 rc=" `outcome'
}
else {
    local ++pass
    display as result "PASS: base_se 0"
}

**# base_se 1.000001
local ++tests
capture noisily {
    qa_fx_a6_bias, clear seed(37) perturb(boundary_values)
    local a=40*.5
    local b=20*.5
    local c=100-`a'
    local d=100-`b'
    qa_state_snapshot, tag(qba_domains)
    * expect: REFUSED
    capture noisily qba_plot, tornado a(`a') b(`b') c(`c') d(`d') type(outcome) param1(sp) range1(1 1) base_se(1.000001) steps(2)
    assert _rc==198
    qa_state_compare, tag(qba_domains)
}
local outcome=_rc
capture restore
if `outcome' {
    local ++fail
    display as error "FAIL: base_se 1.000001 rc=" `outcome'
}
else {
    local ++pass
    display as result "PASS: base_se 1.000001"
}

**# base_se .
local ++tests
capture noisily {
    qa_fx_a6_bias, clear seed(37) perturb(boundary_values)
    local a=40*.5
    local b=20*.5
    local c=100-`a'
    local d=100-`b'
    qa_state_snapshot, tag(qba_domains)
    * expect: REFUSED
    capture noisily qba_plot, tornado a(`a') b(`b') c(`c') d(`d') type(outcome) param1(sp) range1(1 1) base_se(.) steps(2)
    assert _rc==198
    qa_state_compare, tag(qba_domains)
}
local outcome=_rc
capture restore
if `outcome' {
    local ++fail
    display as error "FAIL: base_se . rc=" `outcome'
}
else {
    local ++pass
    display as result "PASS: base_se ."
}

**# base_se .a
local ++tests
capture noisily {
    qa_fx_a6_bias, clear seed(37) perturb(boundary_values)
    local a=40*.5
    local b=20*.5
    local c=100-`a'
    local d=100-`b'
    qa_state_snapshot, tag(qba_domains)
    * expect: REFUSED
    capture noisily qba_plot, tornado a(`a') b(`b') c(`c') d(`d') type(outcome) param1(sp) range1(1 1) base_se(.a) steps(2)
    assert _rc==198
    qa_state_compare, tag(qba_domains)
}
local outcome=_rc
capture restore
if `outcome' {
    local ++fail
    display as error "FAIL: base_se .a rc=" `outcome'
}
else {
    local ++pass
    display as result "PASS: base_se .a"
}

**# base_p1 0
local ++tests
capture noisily {
    qa_fx_a6_bias, clear seed(37) perturb(boundary_values)
    local a=true_n[1]
    local b=true_n[3]
    local c=true_n[2]
    local d=true_n[4]
    qa_state_snapshot, tag(qba_domains)
    * expect: EXACT
    quietly qba_plot, tornado a(`a') b(`b') c(`c') d(`d') measure(RR) param1(p0) range1(0 .5) base_rrcd(3) base_p1(0) steps(3)
    assert r(n_missing)==0
    qa_state_compare, tag(qba_domains)
    serset
    assert r(N)==3 & r(k)==2
    preserve
    serset use, clear
    sort param_value
    assert param_value==(_n-1)/4 & !missing(corrected)
    assert abs(corrected-2*(1+2*param_value)/(1+2*0))<1e-12
    restore
}
local outcome=_rc
capture restore
if `outcome' {
    local ++fail
    display as error "FAIL: base_p1 0 rc=" `outcome'
}
else {
    local ++pass
    display as result "PASS: base_p1 0"
}

**# base_p1 .5
local ++tests
capture noisily {
    qa_fx_a6_bias, clear seed(37) perturb(boundary_values)
    local a=true_n[1]
    local b=true_n[3]
    local c=true_n[2]
    local d=true_n[4]
    qa_state_snapshot, tag(qba_domains)
    * expect: EXACT
    quietly qba_plot, tornado a(`a') b(`b') c(`c') d(`d') measure(RR) param1(p0) range1(0 .5) base_rrcd(3) base_p1(.5) steps(3)
    assert r(n_missing)==0
    qa_state_compare, tag(qba_domains)
    serset
    assert r(N)==3 & r(k)==2
    preserve
    serset use, clear
    sort param_value
    assert param_value==(_n-1)/4 & !missing(corrected)
    assert abs(corrected-2*(1+2*param_value)/(1+2*.5))<1e-12
    restore
}
local outcome=_rc
capture restore
if `outcome' {
    local ++fail
    display as error "FAIL: base_p1 .5 rc=" `outcome'
}
else {
    local ++pass
    display as result "PASS: base_p1 .5"
}

**# base_p1 1
local ++tests
capture noisily {
    qa_fx_a6_bias, clear seed(37) perturb(boundary_values)
    local a=true_n[1]
    local b=true_n[3]
    local c=true_n[2]
    local d=true_n[4]
    qa_state_snapshot, tag(qba_domains)
    * expect: EXACT
    quietly qba_plot, tornado a(`a') b(`b') c(`c') d(`d') measure(RR) param1(p0) range1(0 .5) base_rrcd(3) base_p1(1) steps(3)
    assert r(n_missing)==0
    qa_state_compare, tag(qba_domains)
    serset
    assert r(N)==3 & r(k)==2
    preserve
    serset use, clear
    sort param_value
    assert param_value==(_n-1)/4 & !missing(corrected)
    assert abs(corrected-2*(1+2*param_value)/(1+2*1))<1e-12
    restore
}
local outcome=_rc
capture restore
if `outcome' {
    local ++fail
    display as error "FAIL: base_p1 1 rc=" `outcome'
}
else {
    local ++pass
    display as result "PASS: base_p1 1"
}

**# base_p1 -.000001
local ++tests
capture noisily {
    qa_fx_a6_bias, clear seed(37) perturb(boundary_values)
    local a=true_n[1]
    local b=true_n[3]
    local c=true_n[2]
    local d=true_n[4]
    qa_state_snapshot, tag(qba_domains)
    * expect: REFUSED
    capture noisily qba_plot, tornado a(`a') b(`b') c(`c') d(`d') measure(RR) param1(p0) range1(0 .5) base_rrcd(3) base_p1(-.000001) steps(3)
    assert _rc==198
    qa_state_compare, tag(qba_domains)
}
local outcome=_rc
capture restore
if `outcome' {
    local ++fail
    display as error "FAIL: base_p1 -.000001 rc=" `outcome'
}
else {
    local ++pass
    display as result "PASS: base_p1 -.000001"
}

**# base_p1 1.000001
local ++tests
capture noisily {
    qa_fx_a6_bias, clear seed(37) perturb(boundary_values)
    local a=true_n[1]
    local b=true_n[3]
    local c=true_n[2]
    local d=true_n[4]
    qa_state_snapshot, tag(qba_domains)
    * expect: REFUSED
    capture noisily qba_plot, tornado a(`a') b(`b') c(`c') d(`d') measure(RR) param1(p0) range1(0 .5) base_rrcd(3) base_p1(1.000001) steps(3)
    assert _rc==198
    qa_state_compare, tag(qba_domains)
}
local outcome=_rc
capture restore
if `outcome' {
    local ++fail
    display as error "FAIL: base_p1 1.000001 rc=" `outcome'
}
else {
    local ++pass
    display as result "PASS: base_p1 1.000001"
}

**# base_p1 .
local ++tests
capture noisily {
    qa_fx_a6_bias, clear seed(37) perturb(boundary_values)
    local a=true_n[1]
    local b=true_n[3]
    local c=true_n[2]
    local d=true_n[4]
    qa_state_snapshot, tag(qba_domains)
    * expect: REFUSED
    capture noisily qba_plot, tornado a(`a') b(`b') c(`c') d(`d') measure(RR) param1(p0) range1(0 .5) base_rrcd(3) base_p1(.) steps(3)
    assert _rc==198
    qa_state_compare, tag(qba_domains)
}
local outcome=_rc
capture restore
if `outcome' {
    local ++fail
    display as error "FAIL: base_p1 . rc=" `outcome'
}
else {
    local ++pass
    display as result "PASS: base_p1 ."
}

**# base_p1 .a
local ++tests
capture noisily {
    qa_fx_a6_bias, clear seed(37) perturb(boundary_values)
    local a=true_n[1]
    local b=true_n[3]
    local c=true_n[2]
    local d=true_n[4]
    qa_state_snapshot, tag(qba_domains)
    * expect: REFUSED
    capture noisily qba_plot, tornado a(`a') b(`b') c(`c') d(`d') measure(RR) param1(p0) range1(0 .5) base_rrcd(3) base_p1(.a) steps(3)
    assert _rc==198
    qa_state_compare, tag(qba_domains)
}
local outcome=_rc
capture restore
if `outcome' {
    local ++fail
    display as error "FAIL: base_p1 .a rc=" `outcome'
}
else {
    local ++pass
    display as result "PASS: base_p1 .a"
}

display "RESULT: validation_qba_fixture_domains tests=`tests' pass=`pass' fail=`fail'"
log close
if `fail' exit 1
