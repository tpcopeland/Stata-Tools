*! validation_qba_fixture_callers.do -- exact scalar-cell curve and hostile caller preservation
*! Author: Timothy P Copeland, Karolinska Institutet
* QBA plotting consumes explicit2x2 cells, not caller variables. A7/primitives
* deliberately test caller dataset/state preservation, with independent exact
* numerical curve assertions on every invocation. No caller column is passed
* off as an analytic input and no inactive setup call counts as an oracle.
version 16.0
clear all
set more off
capture log close _all
log using validation_qba_fixture_callers.log, text replace
local pkg_dir=substr("`c(pwd)'",1,strlen("`c(pwd)'")-3)
adopath ++ "`pkg_dir'"
do _qa_fx_a6.do
do _qa_fx_a7.do
do _qa_hostile.do
do _qa_state.do
local tests 0
local pass 0
local fail 0

**# scalar-cell curve with friendly caller
local ++tests
capture noisily {
    qa_fx_a6_bias, clear seed(37)
    local a=true_n[1]
    local b=true_n[3]
    local c=true_n[2]
    local d=true_n[4]
    qa_fx_a7_labelled, clear seed(37)
    qa_state_snapshot, tag(qba_caller)
    * expect: EXACT
    quietly qba_plot, tornado a(`a') b(`b') c(`c') d(`d') measure(RR) param1(p1) range1(0 .5) base_p0(0) base_rrcd(3) steps(3)
    assert r(n_missing)==0 & `"`r(plot_type)'"'=="tornado"
    qa_state_compare, tag(qba_caller)
    serset
    assert r(N)==3 & r(k)==2
    preserve
    serset use, clear
    sort param_value
    assert param_value==(_n-1)/4 & !missing(corrected)
    assert abs(corrected-2/(1+2*param_value))<1e-12
    restore
}
local outcome=_rc
capture restore
if `outcome' {
    local ++fail
    display as error "FAIL: friendly caller rc=" `outcome'
}
else {
    local ++pass
    display as result "PASS: friendly caller"
}

**# scalar-cell curve with label_gaps caller
local ++tests
capture noisily {
    qa_fx_a6_bias, clear seed(37)
    local a=true_n[1]
    local b=true_n[3]
    local c=true_n[2]
    local d=true_n[4]
    qa_fx_a7_labelled, clear seed(37) perturb(label_gaps)
    qa_state_snapshot, tag(qba_caller)
    * expect: EXACT
    quietly qba_plot, tornado a(`a') b(`b') c(`c') d(`d') measure(RR) param1(p1) range1(0 .5) base_p0(0) base_rrcd(3) steps(3)
    assert r(n_missing)==0 & `"`r(plot_type)'"'=="tornado"
    qa_state_compare, tag(qba_caller)
    serset
    assert r(N)==3 & r(k)==2
    preserve
    serset use, clear
    sort param_value
    assert param_value==(_n-1)/4 & !missing(corrected)
    assert abs(corrected-2/(1+2*param_value))<1e-12
    restore
}
local outcome=_rc
capture restore
if `outcome' {
    local ++fail
    display as error "FAIL: label_gaps caller rc=" `outcome'
}
else {
    local ++pass
    display as result "PASS: label_gaps caller"
}

**# scalar-cell curve with miss_all_column caller
local ++tests
capture noisily {
    qa_fx_a6_bias, clear seed(37)
    local a=true_n[1]
    local b=true_n[3]
    local c=true_n[2]
    local d=true_n[4]
    qa_fx_a7_labelled, clear seed(37) perturb(miss_all_column)
    qa_state_snapshot, tag(qba_caller)
    * expect: EXACT
    quietly qba_plot, tornado a(`a') b(`b') c(`c') d(`d') measure(RR) param1(p1) range1(0 .5) base_p0(0) base_rrcd(3) steps(3)
    assert r(n_missing)==0 & `"`r(plot_type)'"'=="tornado"
    qa_state_compare, tag(qba_caller)
    serset
    assert r(N)==3 & r(k)==2
    preserve
    serset use, clear
    sort param_value
    assert param_value==(_n-1)/4 & !missing(corrected)
    assert abs(corrected-2/(1+2*param_value))<1e-12
    restore
}
local outcome=_rc
capture restore
if `outcome' {
    local ++fail
    display as error "FAIL: miss_all_column caller rc=" `outcome'
}
else {
    local ++pass
    display as result "PASS: miss_all_column caller"
}

**# scalar-cell curve with single_row caller
local ++tests
capture noisily {
    qa_fx_a6_bias, clear seed(37)
    local a=true_n[1]
    local b=true_n[3]
    local c=true_n[2]
    local d=true_n[4]
    qa_fx_a7_labelled, clear seed(37) perturb(single_row)
    qa_state_snapshot, tag(qba_caller)
    * expect: EXACT
    quietly qba_plot, tornado a(`a') b(`b') c(`c') d(`d') measure(RR) param1(p1) range1(0 .5) base_p0(0) base_rrcd(3) steps(3)
    assert r(n_missing)==0 & `"`r(plot_type)'"'=="tornado"
    qa_state_compare, tag(qba_caller)
    serset
    assert r(N)==3 & r(k)==2
    preserve
    serset use, clear
    sort param_value
    assert param_value==(_n-1)/4 & !missing(corrected)
    assert abs(corrected-2/(1+2*param_value))<1e-12
    restore
}
local outcome=_rc
capture restore
if `outcome' {
    local ++fail
    display as error "FAIL: single_row caller rc=" `outcome'
}
else {
    local ++pass
    display as result "PASS: single_row caller"
}

**# scalar-cell curve with long_names caller
local ++tests
capture noisily {
    qa_fx_a6_bias, clear seed(37)
    local a=true_n[1]
    local b=true_n[3]
    local c=true_n[2]
    local d=true_n[4]
    qa_hostile_names, clear
    qa_state_snapshot, tag(qba_caller)
    * expect: EXACT
    quietly qba_plot, tornado a(`a') b(`b') c(`c') d(`d') measure(RR) param1(p1) range1(0 .5) base_p0(0) base_rrcd(3) steps(3)
    assert r(n_missing)==0 & `"`r(plot_type)'"'=="tornado"
    qa_state_compare, tag(qba_caller)
    serset
    assert r(N)==3 & r(k)==2
    preserve
    serset use, clear
    sort param_value
    assert param_value==(_n-1)/4 & !missing(corrected)
    assert abs(corrected-2/(1+2*param_value))<1e-12
    restore
}
local outcome=_rc
capture restore
if `outcome' {
    local ++fail
    display as error "FAIL: long_names caller rc=" `outcome'
}
else {
    local ++pass
    display as result "PASS: long_names caller"
}

**# scalar-cell curve with codes_negative caller
local ++tests
capture noisily {
    qa_fx_a6_bias, clear seed(37)
    local a=true_n[1]
    local b=true_n[3]
    local c=true_n[2]
    local d=true_n[4]
    qa_hostile_codes, clear
    qa_state_snapshot, tag(qba_caller)
    * expect: EXACT
    quietly qba_plot, tornado a(`a') b(`b') c(`c') d(`d') measure(RR) param1(p1) range1(0 .5) base_p0(0) base_rrcd(3) steps(3)
    assert r(n_missing)==0 & `"`r(plot_type)'"'=="tornado"
    qa_state_compare, tag(qba_caller)
    serset
    assert r(N)==3 & r(k)==2
    preserve
    serset use, clear
    sort param_value
    assert param_value==(_n-1)/4 & !missing(corrected)
    assert abs(corrected-2/(1+2*param_value))<1e-12
    restore
}
local outcome=_rc
capture restore
if `outcome' {
    local ++fail
    display as error "FAIL: codes_negative caller rc=" `outcome'
}
else {
    local ++pass
    display as result "PASS: codes_negative caller"
}

**# scalar-cell curve with codes_big caller
local ++tests
capture noisily {
    qa_fx_a6_bias, clear seed(37)
    local a=true_n[1]
    local b=true_n[3]
    local c=true_n[2]
    local d=true_n[4]
    qa_hostile_codes, clear
    qa_state_snapshot, tag(qba_caller)
    * expect: EXACT
    quietly qba_plot, tornado a(`a') b(`b') c(`c') d(`d') measure(RR) param1(p1) range1(0 .5) base_p0(0) base_rrcd(3) steps(3)
    assert r(n_missing)==0 & `"`r(plot_type)'"'=="tornado"
    qa_state_compare, tag(qba_caller)
    serset
    assert r(N)==3 & r(k)==2
    preserve
    serset use, clear
    sort param_value
    assert param_value==(_n-1)/4 & !missing(corrected)
    assert abs(corrected-2/(1+2*param_value))<1e-12
    restore
}
local outcome=_rc
capture restore
if `outcome' {
    local ++fail
    display as error "FAIL: codes_big caller rc=" `outcome'
}
else {
    local ++pass
    display as result "PASS: codes_big caller"
}

**# scalar-cell curve with string_hostile caller
local ++tests
capture noisily {
    qa_fx_a6_bias, clear seed(37)
    local a=true_n[1]
    local b=true_n[3]
    local c=true_n[2]
    local d=true_n[4]
    qa_fx_a7_labelled, clear seed(37)
    qa_hostile_strings
    local corpus `r(names)'
    generate strL caption=""
    local i 0
    foreach g of local corpus {
        local ++i
        mata: st_sstore(strtoreal(st_local("i")),"caption",st_global(st_local("g")))
    }
    qa_state_snapshot, tag(qba_caller)
    * expect: EXACT
    quietly qba_plot, tornado a(`a') b(`b') c(`c') d(`d') measure(RR) param1(p1) range1(0 .5) base_p0(0) base_rrcd(3) steps(3)
    assert r(n_missing)==0 & `"`r(plot_type)'"'=="tornado"
    qa_state_compare, tag(qba_caller)
    serset
    assert r(N)==3 & r(k)==2
    preserve
    serset use, clear
    sort param_value
    assert param_value==(_n-1)/4 & !missing(corrected)
    assert abs(corrected-2/(1+2*param_value))<1e-12
    restore
}
local outcome=_rc
capture restore
if `outcome' {
    local ++fail
    display as error "FAIL: string_hostile caller rc=" `outcome'
}
else {
    local ++pass
    display as result "PASS: string_hostile caller"
}

display "RESULT: validation_qba_fixture_callers tests=`tests' pass=`pass' fail=`fail'"
log close
if `fail' exit 1
