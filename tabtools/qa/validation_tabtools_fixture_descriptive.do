*! validation_tabtools_fixture_descriptive.do -- exact canonical mean/SD strings and sparse-column identity
*! Author: Timothy P Copeland, Karolinska Institutet
version 17.0
clear all
set more off
capture log close _all
log using "validation_tabtools_fixture_descriptive.log", text replace
local pkg_dir=substr("`c(pwd)'",1,strlen("`c(pwd)'")-3)
adopath ++ "`pkg_dir'"
do _qa_fx_a7.do
do _qa_state.do
local tests 0
local pass 0
local fail 0

**# Exact descriptive payload desctab friendly
local ++tests
capture noisily {
    * expect: EXACT
    qa_fx_a7_labelled, clear seed(37)
    tempname table truth
    matrix `truth'=r(truth_cells)
    qa_state_snapshot, tag(desc_payload)
    quietly desctab, by(group) vars(x contn %9.1f) frame(`table')
    assert `"`r(frame)'"'=="`table'"
    frame `table': assert _N==3 & factor[3]=="Exact sequence 1–40"
    forvalues j=1/4 {
        local code=`truth'[`j',1]
        frame `table': assert group_`code'[2]=="N=10"
        * Ten consecutive integers: sample variance55/6, displayed SD3.0.
        local mean=strtrim(string(`truth'[`j',6],"%9.1f"))
        frame `table': assert group_`code'[3]=="`mean'±3.0"
    }
    frame drop `table'
    qa_state_compare, tag(desc_payload)
}
local outcome=_rc
capture frame drop `table'
if `outcome' {
    local ++fail
    display as error "FAIL: desctab friendly; rc=" `outcome'
}
else {
    local ++pass
    display as result "PASS: desctab friendly"
}

**# Exact descriptive payload desctab unsorted
local ++tests
capture noisily {
    * expect: EXACT
    qa_fx_a7_labelled, clear seed(37) perturb(unsorted)
    tempname table truth
    matrix `truth'=r(truth_cells)
    qa_state_snapshot, tag(desc_payload)
    quietly desctab, by(group) vars(x contn %9.1f) frame(`table')
    assert `"`r(frame)'"'=="`table'"
    frame `table': assert _N==3 & factor[3]=="Exact sequence 1–40"
    forvalues j=1/4 {
        local code=`truth'[`j',1]
        frame `table': assert group_`code'[2]=="N=10"
        * Ten consecutive integers: sample variance55/6, displayed SD3.0.
        local mean=strtrim(string(`truth'[`j',6],"%9.1f"))
        frame `table': assert group_`code'[3]=="`mean'±3.0"
    }
    frame drop `table'
    qa_state_compare, tag(desc_payload)
}
local outcome=_rc
capture frame drop `table'
if `outcome' {
    local ++fail
    display as error "FAIL: desctab unsorted; rc=" `outcome'
}
else {
    local ++pass
    display as result "PASS: desctab unsorted"
}

**# Exact descriptive payload desctab label_gaps
local ++tests
capture noisily {
    * expect: EXACT
    qa_fx_a7_labelled, clear seed(37) perturb(label_gaps)
    tempname table truth
    matrix `truth'=r(truth_cells)
    qa_state_snapshot, tag(desc_payload)
    quietly desctab, by(group) vars(x contn %9.1f) frame(`table')
    assert `"`r(frame)'"'=="`table'"
    frame `table': assert _N==3 & factor[3]=="Exact sequence 1–40"
    forvalues j=1/4 {
        local code=`truth'[`j',1]
        frame `table': assert group_`code'[2]=="N=10"
        * Ten consecutive integers: sample variance55/6, displayed SD3.0.
        local mean=strtrim(string(`truth'[`j',6],"%9.1f"))
        frame `table': assert group_`code'[3]=="`mean'±3.0"
    }
    frame drop `table'
    qa_state_compare, tag(desc_payload)
}
local outcome=_rc
capture frame drop `table'
if `outcome' {
    local ++fail
    display as error "FAIL: desctab label_gaps; rc=" `outcome'
}
else {
    local ++pass
    display as result "PASS: desctab label_gaps"
}

**# Exact descriptive payload desctab single_row
local ++tests
capture noisily {
    * expect: REFUSED
    qa_fx_a7_labelled, clear seed(37) perturb(single_row)
    tempname table truth
    matrix `truth'=r(truth_cells)
    qa_state_snapshot, tag(desc_payload)
    capture noisily desctab, by(group) vars(x contn %9.1f) frame(`table')
    assert _rc==498
    qa_state_compare, tag(desc_payload)
}
local outcome=_rc
capture frame drop `table'
if `outcome' {
    local ++fail
    display as error "FAIL: desctab single_row; rc=" `outcome'
}
else {
    local ++pass
    display as result "PASS: desctab single_row"
}

**# Exact descriptive payload desctab miss_all_column
local ++tests
capture noisily {
    * expect: EXACT
    qa_fx_a7_labelled, clear seed(37) perturb(miss_all_column)
    tempname table truth
    matrix `truth'=r(truth_cells)
    qa_state_snapshot, tag(desc_payload)
    quietly desctab, by(group) vars(x contn %9.1f) frame(`table')
    assert `"`r(frame)'"'=="`table'"
    frame `table': assert _N==3 & factor[3]=="Exact sequence 1–40"
    forvalues j=1/4 {
        local code=`truth'[`j',1]
        frame `table': assert group_`code'[2]=="N=10"
        frame `table': assert group_`code'[3]==""
    }
    frame drop `table'
    qa_state_compare, tag(desc_payload)
}
local outcome=_rc
capture frame drop `table'
if `outcome' {
    local ++fail
    display as error "FAIL: desctab miss_all_column; rc=" `outcome'
}
else {
    local ++pass
    display as result "PASS: desctab miss_all_column"
}

**# Exact descriptive payload desctab boundary_values
local ++tests
capture noisily {
    * expect: EXACT
    qa_fx_a7_labelled, clear seed(37) perturb(boundary_values)
    tempname table truth
    matrix `truth'=r(truth_cells)
    qa_state_snapshot, tag(desc_payload)
    quietly desctab, by(group) vars(x contn %9.1f) frame(`table')
    assert `"`r(frame)'"'=="`table'"
    frame `table': assert _N==3 & factor[3]=="Exact sequence 1–40"
    forvalues j=1/4 {
        local code=`truth'[`j',1]
        frame `table': assert group_`code'[2]=="N=10"
        * Ten consecutive integers: sample variance55/6, displayed SD3.0.
        local mean=strtrim(string(`truth'[`j',6],"%9.1f"))
        frame `table': assert group_`code'[3]=="`mean'±3.0"
    }
    frame drop `table'
    qa_state_compare, tag(desc_payload)
}
local outcome=_rc
capture frame drop `table'
if `outcome' {
    local ++fail
    display as error "FAIL: desctab boundary_values; rc=" `outcome'
}
else {
    local ++pass
    display as result "PASS: desctab boundary_values"
}

**# Exact descriptive payload table1_tc friendly
local ++tests
capture noisily {
    * expect: EXACT
    qa_fx_a7_labelled, clear seed(37)
    tempname table truth
    matrix `truth'=r(truth_cells)
    qa_state_snapshot, tag(desc_payload)
    quietly table1_tc, by(group) vars(x contn %9.1f) frame(`table')
    assert `"`r(frame)'"'=="`table'"
    frame `table': assert _N==3 & factor[3]=="Exact sequence 1–40"
    forvalues j=1/4 {
        local code=`truth'[`j',1]
        frame `table': assert group_`code'[2]=="N=10"
        * Ten consecutive integers: sample variance55/6, displayed SD3.0.
        local mean=strtrim(string(`truth'[`j',6],"%9.1f"))
        frame `table': assert group_`code'[3]=="`mean'±3.0"
    }
    frame drop `table'
    qa_state_compare, tag(desc_payload)
}
local outcome=_rc
capture frame drop `table'
if `outcome' {
    local ++fail
    display as error "FAIL: table1_tc friendly; rc=" `outcome'
}
else {
    local ++pass
    display as result "PASS: table1_tc friendly"
}

**# Exact descriptive payload table1_tc unsorted
local ++tests
capture noisily {
    * expect: EXACT
    qa_fx_a7_labelled, clear seed(37) perturb(unsorted)
    tempname table truth
    matrix `truth'=r(truth_cells)
    qa_state_snapshot, tag(desc_payload)
    quietly table1_tc, by(group) vars(x contn %9.1f) frame(`table')
    assert `"`r(frame)'"'=="`table'"
    frame `table': assert _N==3 & factor[3]=="Exact sequence 1–40"
    forvalues j=1/4 {
        local code=`truth'[`j',1]
        frame `table': assert group_`code'[2]=="N=10"
        * Ten consecutive integers: sample variance55/6, displayed SD3.0.
        local mean=strtrim(string(`truth'[`j',6],"%9.1f"))
        frame `table': assert group_`code'[3]=="`mean'±3.0"
    }
    frame drop `table'
    qa_state_compare, tag(desc_payload)
}
local outcome=_rc
capture frame drop `table'
if `outcome' {
    local ++fail
    display as error "FAIL: table1_tc unsorted; rc=" `outcome'
}
else {
    local ++pass
    display as result "PASS: table1_tc unsorted"
}

**# Exact descriptive payload table1_tc label_gaps
local ++tests
capture noisily {
    * expect: EXACT
    qa_fx_a7_labelled, clear seed(37) perturb(label_gaps)
    tempname table truth
    matrix `truth'=r(truth_cells)
    qa_state_snapshot, tag(desc_payload)
    quietly table1_tc, by(group) vars(x contn %9.1f) frame(`table')
    assert `"`r(frame)'"'=="`table'"
    frame `table': assert _N==3 & factor[3]=="Exact sequence 1–40"
    forvalues j=1/4 {
        local code=`truth'[`j',1]
        frame `table': assert group_`code'[2]=="N=10"
        * Ten consecutive integers: sample variance55/6, displayed SD3.0.
        local mean=strtrim(string(`truth'[`j',6],"%9.1f"))
        frame `table': assert group_`code'[3]=="`mean'±3.0"
    }
    frame drop `table'
    qa_state_compare, tag(desc_payload)
}
local outcome=_rc
capture frame drop `table'
if `outcome' {
    local ++fail
    display as error "FAIL: table1_tc label_gaps; rc=" `outcome'
}
else {
    local ++pass
    display as result "PASS: table1_tc label_gaps"
}

**# Exact descriptive payload table1_tc single_row
local ++tests
capture noisily {
    * expect: REFUSED
    qa_fx_a7_labelled, clear seed(37) perturb(single_row)
    tempname table truth
    matrix `truth'=r(truth_cells)
    qa_state_snapshot, tag(desc_payload)
    capture noisily table1_tc, by(group) vars(x contn %9.1f) frame(`table')
    assert _rc==498
    qa_state_compare, tag(desc_payload)
}
local outcome=_rc
capture frame drop `table'
if `outcome' {
    local ++fail
    display as error "FAIL: table1_tc single_row; rc=" `outcome'
}
else {
    local ++pass
    display as result "PASS: table1_tc single_row"
}

**# Exact descriptive payload table1_tc miss_all_column
local ++tests
capture noisily {
    * expect: EXACT
    qa_fx_a7_labelled, clear seed(37) perturb(miss_all_column)
    tempname table truth
    matrix `truth'=r(truth_cells)
    qa_state_snapshot, tag(desc_payload)
    quietly table1_tc, by(group) vars(x contn %9.1f) frame(`table')
    assert `"`r(frame)'"'=="`table'"
    frame `table': assert _N==3 & factor[3]=="Exact sequence 1–40"
    forvalues j=1/4 {
        local code=`truth'[`j',1]
        frame `table': assert group_`code'[2]=="N=10"
        frame `table': assert group_`code'[3]==""
    }
    frame drop `table'
    qa_state_compare, tag(desc_payload)
}
local outcome=_rc
capture frame drop `table'
if `outcome' {
    local ++fail
    display as error "FAIL: table1_tc miss_all_column; rc=" `outcome'
}
else {
    local ++pass
    display as result "PASS: table1_tc miss_all_column"
}

**# Exact descriptive payload table1_tc boundary_values
local ++tests
capture noisily {
    * expect: EXACT
    qa_fx_a7_labelled, clear seed(37) perturb(boundary_values)
    tempname table truth
    matrix `truth'=r(truth_cells)
    qa_state_snapshot, tag(desc_payload)
    quietly table1_tc, by(group) vars(x contn %9.1f) frame(`table')
    assert `"`r(frame)'"'=="`table'"
    frame `table': assert _N==3 & factor[3]=="Exact sequence 1–40"
    forvalues j=1/4 {
        local code=`truth'[`j',1]
        frame `table': assert group_`code'[2]=="N=10"
        * Ten consecutive integers: sample variance55/6, displayed SD3.0.
        local mean=strtrim(string(`truth'[`j',6],"%9.1f"))
        frame `table': assert group_`code'[3]=="`mean'±3.0"
    }
    frame drop `table'
    qa_state_compare, tag(desc_payload)
}
local outcome=_rc
capture frame drop `table'
if `outcome' {
    local ++fail
    display as error "FAIL: table1_tc boundary_values; rc=" `outcome'
}
else {
    local ++pass
    display as result "PASS: table1_tc boundary_values"
}

display "RESULT: validation_tabtools_fixture_descriptive tests=`tests' pass=`pass' fail=`fail'"
log close
if `fail' exit 1
