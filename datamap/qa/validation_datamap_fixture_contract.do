*! validation_datamap_fixture_contract.do -- canonical labelled designs and independent contents
*! Author: Timothy P Copeland, Karolinska Institutet
version 16.0
clear all
set more off
capture log close _all
log using "validation_datamap_fixture_contract.log", text replace
local pkg_dir=substr("`c(pwd)'",1,strlen("`c(pwd)'")-3)
adopath ++ "`pkg_dir'"
do _qa_fx_a7.do
do _qa_state.do
local tests 0
local pass 0
local fail 0

**# JSON metadata exact labelled friendly
local ++tests
capture noisily {
    qa_fx_a7_labelled, clear seed(37)
    tempfile output
    qa_state_snapshot, tag(dm_json)
    quietly datamap, output(`"`output'"') format(json) continuous(x) mincell(0)
    assert r(nfiles)==1 & r(nobs)==40 & r(nvars)==10
    qa_state_compare, tag(dm_json)
    python: _ds=__import__("json").loads(__import__("pathlib").Path(__import__("sfi").Macro.getLocal("output")).read_text())["datasets"][0]; _v={v["name"]:v for v in _ds["variable_metadata"]}; assert _ds["observations"]==40 and _ds["variables"]==10; assert _v["all_missing"]["missing_n"]==40 and _v["extended"]["missing_n"]==40; assert _v["x"]["missing_n"]==0; assert _v["x"]["summary"]=={} if 0>0 else _v["x"]["summary"]["mean"]==20.5
    python: _g=_v["group"]["frequencies"]; assert {q["value"]:q["count"] for q in _g}==({"1":1} if 40==1 else {"1":10,"2":10,"5":10,"9":10})

}
local outcome=_rc

if `outcome' {
    local ++fail
    display as error "FAIL: JSON metadata exact labelled friendly; rc=" `outcome'
}
else {
    local ++pass
    display as result "PASS: JSON metadata exact labelled friendly"
}

**# Missingness exact labelled friendly
local ++tests
capture noisily {
    qa_fx_a7_labelled, clear seed(37)
    global S_2 "CALLER_KEEP"
    qa_state_snapshot, tag(dm_miss)
    quietly datamvp x extended all_missing, nodrop
    assert r(N)==40 & r(N_complete)==0 & r(N_incomplete)==40
    assert r(N_vars)==3 & r(N_patterns)==1
    assert r(N_mv_total)==80
    assert r(max_miss)==2 & r(mean_miss)==2
    qa_state_compare, tag(dm_miss)

}
local outcome=_rc

if `outcome' {
    local ++fail
    display as error "FAIL: Missingness exact labelled friendly; rc=" `outcome'
}
else {
    local ++pass
    display as result "PASS: Missingness exact labelled friendly"
}

**# QC exact labelled friendly
local ++tests
capture noisily {
    qa_fx_a7_labelled, clear seed(37)
    qa_state_snapshot, tag(dm_qc)
    quietly datacheck, gatesonly expectn(40) isid(id) binary(y) allowed(group 1 2 5 9)
    assert r(N)==40 & r(n_failed)==0 & r(n_errors)==0
    assert r(n_checks)==4 & r(n_passed)==4
    qa_state_compare, tag(dm_qc)

}
local outcome=_rc

if `outcome' {
    local ++fail
    display as error "FAIL: QC exact labelled friendly; rc=" `outcome'
}
else {
    local ++pass
    display as result "PASS: QC exact labelled friendly"
}

**# JSON metadata exact labelled label_gaps
local ++tests
capture noisily {
    * expect: EXACT
    qa_fx_a7_labelled, clear seed(37) perturb(label_gaps)
    tempfile output
    qa_state_snapshot, tag(dm_json)
    quietly datamap, output(`"`output'"') format(json) continuous(x) mincell(0)
    assert r(nfiles)==1 & r(nobs)==40 & r(nvars)==10
    qa_state_compare, tag(dm_json)
    python: _ds=__import__("json").loads(__import__("pathlib").Path(__import__("sfi").Macro.getLocal("output")).read_text())["datasets"][0]; _v={v["name"]:v for v in _ds["variable_metadata"]}; assert _ds["observations"]==40 and _ds["variables"]==10; assert _v["all_missing"]["missing_n"]==40 and _v["extended"]["missing_n"]==40; assert _v["x"]["missing_n"]==0; assert _v["x"]["summary"]=={} if 0>0 else _v["x"]["summary"]["mean"]==20.5
    python: _g=_v["group"]["frequencies"]; assert {q["value"]:q["count"] for q in _g}==({"1":1} if 40==1 else {"1":10,"2":10,"5":10,"9":10})

}
local outcome=_rc

if `outcome' {
    local ++fail
    display as error "FAIL: JSON metadata exact labelled label_gaps; rc=" `outcome'
}
else {
    local ++pass
    display as result "PASS: JSON metadata exact labelled label_gaps"
}

**# Missingness exact labelled label_gaps
local ++tests
capture noisily {
    * expect: EXACT
    qa_fx_a7_labelled, clear seed(37) perturb(label_gaps)
    global S_2 "CALLER_KEEP"
    qa_state_snapshot, tag(dm_miss)
    quietly datamvp x extended all_missing, nodrop
    assert r(N)==40 & r(N_complete)==0 & r(N_incomplete)==40
    assert r(N_vars)==3 & r(N_patterns)==1
    assert r(N_mv_total)==80
    assert r(max_miss)==2 & r(mean_miss)==2
    qa_state_compare, tag(dm_miss)

}
local outcome=_rc

if `outcome' {
    local ++fail
    display as error "FAIL: Missingness exact labelled label_gaps; rc=" `outcome'
}
else {
    local ++pass
    display as result "PASS: Missingness exact labelled label_gaps"
}

**# QC exact labelled label_gaps
local ++tests
capture noisily {
    * expect: EXACT
    qa_fx_a7_labelled, clear seed(37) perturb(label_gaps)
    qa_state_snapshot, tag(dm_qc)
    quietly datacheck, gatesonly expectn(40) isid(id) binary(y) allowed(group 1 2 5 9)
    assert r(N)==40 & r(n_failed)==0 & r(n_errors)==0
    assert r(n_checks)==4 & r(n_passed)==4
    qa_state_compare, tag(dm_qc)

}
local outcome=_rc

if `outcome' {
    local ++fail
    display as error "FAIL: QC exact labelled label_gaps; rc=" `outcome'
}
else {
    local ++pass
    display as result "PASS: QC exact labelled label_gaps"
}

**# JSON metadata exact labelled miss_all_column
local ++tests
capture noisily {
    * expect: EXACT
    qa_fx_a7_labelled, clear seed(37) perturb(miss_all_column)
    tempfile output
    qa_state_snapshot, tag(dm_json)
    quietly datamap, output(`"`output'"') format(json) continuous(x) mincell(0)
    assert r(nfiles)==1 & r(nobs)==40 & r(nvars)==10
    qa_state_compare, tag(dm_json)
    python: _ds=__import__("json").loads(__import__("pathlib").Path(__import__("sfi").Macro.getLocal("output")).read_text())["datasets"][0]; _v={v["name"]:v for v in _ds["variable_metadata"]}; assert _ds["observations"]==40 and _ds["variables"]==10; assert _v["all_missing"]["missing_n"]==40 and _v["extended"]["missing_n"]==40; assert _v["x"]["missing_n"]==40; assert _v["x"]["summary"]=={} if 40>0 else _v["x"]["summary"]["mean"]==20.5
    python: _g=_v["group"]["frequencies"]; assert {q["value"]:q["count"] for q in _g}==({"1":1} if 40==1 else {"1":10,"2":10,"5":10,"9":10})

}
local outcome=_rc

if `outcome' {
    local ++fail
    display as error "FAIL: JSON metadata exact labelled miss_all_column; rc=" `outcome'
}
else {
    local ++pass
    display as result "PASS: JSON metadata exact labelled miss_all_column"
}

**# Missingness exact labelled miss_all_column
local ++tests
capture noisily {
    * expect: EXACT
    qa_fx_a7_labelled, clear seed(37) perturb(miss_all_column)
    global S_2 "CALLER_KEEP"
    qa_state_snapshot, tag(dm_miss)
    quietly datamvp x extended all_missing, nodrop
    assert r(N)==40 & r(N_complete)==0 & r(N_incomplete)==40
    assert r(N_vars)==3 & r(N_patterns)==1
    assert r(N_mv_total)==120
    assert r(max_miss)==3 & r(mean_miss)==3
    qa_state_compare, tag(dm_miss)

}
local outcome=_rc

if `outcome' {
    local ++fail
    display as error "FAIL: Missingness exact labelled miss_all_column; rc=" `outcome'
}
else {
    local ++pass
    display as result "PASS: Missingness exact labelled miss_all_column"
}

**# QC exact labelled miss_all_column
local ++tests
capture noisily {
    * expect: EXACT
    qa_fx_a7_labelled, clear seed(37) perturb(miss_all_column)
    qa_state_snapshot, tag(dm_qc)
    quietly datacheck, gatesonly expectn(40) isid(id) binary(y) allowed(group 1 2 5 9)
    assert r(N)==40 & r(n_failed)==0 & r(n_errors)==0
    assert r(n_checks)==4 & r(n_passed)==4
    qa_state_compare, tag(dm_qc)

}
local outcome=_rc

if `outcome' {
    local ++fail
    display as error "FAIL: QC exact labelled miss_all_column; rc=" `outcome'
}
else {
    local ++pass
    display as result "PASS: QC exact labelled miss_all_column"
}

**# JSON metadata exact labelled single_row
local ++tests
capture noisily {
    * expect: EXACT
    qa_fx_a7_labelled, clear seed(37) perturb(single_row)
    tempfile output
    qa_state_snapshot, tag(dm_json)
    quietly datamap, output(`"`output'"') format(json) continuous(x) mincell(0)
    assert r(nfiles)==1 & r(nobs)==1 & r(nvars)==10
    qa_state_compare, tag(dm_json)
    python: _ds=__import__("json").loads(__import__("pathlib").Path(__import__("sfi").Macro.getLocal("output")).read_text())["datasets"][0]; _v={v["name"]:v for v in _ds["variable_metadata"]}; assert _ds["observations"]==1 and _ds["variables"]==10; assert _v["all_missing"]["missing_n"]==1 and _v["extended"]["missing_n"]==1; assert _v["x"]["missing_n"]==0; assert _v["x"]["summary"]=={} if 0>0 else _v["x"]["summary"]["mean"]==1
    python: _g=_v["group"]["frequencies"]; assert {q["value"]:q["count"] for q in _g}==({"1":1} if 1==1 else {"1":10,"2":10,"5":10,"9":10})

}
local outcome=_rc

if `outcome' {
    local ++fail
    display as error "FAIL: JSON metadata exact labelled single_row; rc=" `outcome'
}
else {
    local ++pass
    display as result "PASS: JSON metadata exact labelled single_row"
}

**# Missingness exact labelled single_row
local ++tests
capture noisily {
    * expect: EXACT
    qa_fx_a7_labelled, clear seed(37) perturb(single_row)
    global S_2 "CALLER_KEEP"
    qa_state_snapshot, tag(dm_miss)
    quietly datamvp x extended all_missing, nodrop
    assert r(N)==1 & r(N_complete)==0 & r(N_incomplete)==1
    assert r(N_vars)==3 & r(N_patterns)==1
    assert r(N_mv_total)==2
    assert r(max_miss)==2 & r(mean_miss)==2
    qa_state_compare, tag(dm_miss)

}
local outcome=_rc

if `outcome' {
    local ++fail
    display as error "FAIL: Missingness exact labelled single_row; rc=" `outcome'
}
else {
    local ++pass
    display as result "PASS: Missingness exact labelled single_row"
}

**# QC exact labelled single_row
local ++tests
capture noisily {
    * expect: REFUSED
    qa_fx_a7_labelled, clear seed(37) perturb(single_row)
    qa_state_snapshot, tag(dm_qc)
    capture noisily datacheck, gatesonly expectn(1) isid(id) binary(y) allowed(group 1 2 5 9)
    assert _rc==9
    assert r(N)==1 & r(n_failed)==1 & r(n_errors)==1
    assert r(n_checks)==4 & r(n_passed)==3
    qa_state_compare, tag(dm_qc)

}
local outcome=_rc

if `outcome' {
    local ++fail
    display as error "FAIL: QC exact labelled single_row; rc=" `outcome'
}
else {
    local ++pass
    display as result "PASS: QC exact labelled single_row"
}

**# JSON metadata exact labelled boundary_values
local ++tests
capture noisily {
    * expect: EXACT
    qa_fx_a7_labelled, clear seed(37) perturb(boundary_values)
    tempfile output
    qa_state_snapshot, tag(dm_json)
    quietly datamap, output(`"`output'"') format(json) continuous(x) mincell(0)
    assert r(nfiles)==1 & r(nobs)==40 & r(nvars)==10
    qa_state_compare, tag(dm_json)
    python: _ds=__import__("json").loads(__import__("pathlib").Path(__import__("sfi").Macro.getLocal("output")).read_text())["datasets"][0]; _v={v["name"]:v for v in _ds["variable_metadata"]}; assert _ds["observations"]==40 and _ds["variables"]==10; assert _v["all_missing"]["missing_n"]==40 and _v["extended"]["missing_n"]==40; assert _v["x"]["missing_n"]==0; assert _v["x"]["summary"]=={} if 0>0 else _v["x"]["summary"]["mean"]==20.5
    python: _g=_v["group"]["frequencies"]; assert {q["value"]:q["count"] for q in _g}==({"1":1} if 40==1 else {"1":10,"2":10,"5":10,"9":10})

}
local outcome=_rc

if `outcome' {
    local ++fail
    display as error "FAIL: JSON metadata exact labelled boundary_values; rc=" `outcome'
}
else {
    local ++pass
    display as result "PASS: JSON metadata exact labelled boundary_values"
}

**# Missingness exact labelled boundary_values
local ++tests
capture noisily {
    * expect: EXACT
    qa_fx_a7_labelled, clear seed(37) perturb(boundary_values)
    global S_2 "CALLER_KEEP"
    qa_state_snapshot, tag(dm_miss)
    quietly datamvp x extended all_missing, nodrop
    assert r(N)==40 & r(N_complete)==0 & r(N_incomplete)==40
    assert r(N_vars)==3 & r(N_patterns)==1
    assert r(N_mv_total)==80
    assert r(max_miss)==2 & r(mean_miss)==2
    qa_state_compare, tag(dm_miss)

}
local outcome=_rc

if `outcome' {
    local ++fail
    display as error "FAIL: Missingness exact labelled boundary_values; rc=" `outcome'
}
else {
    local ++pass
    display as result "PASS: Missingness exact labelled boundary_values"
}

**# QC exact labelled boundary_values
local ++tests
capture noisily {
    * expect: EXACT
    qa_fx_a7_labelled, clear seed(37) perturb(boundary_values)
    qa_state_snapshot, tag(dm_qc)
    quietly datacheck, gatesonly expectn(40) isid(id) binary(y) allowed(group 1 2 5 9)
    assert r(N)==40 & r(n_failed)==0 & r(n_errors)==0
    assert r(n_checks)==4 & r(n_passed)==4
    qa_state_compare, tag(dm_qc)

}
local outcome=_rc

if `outcome' {
    local ++fail
    display as error "FAIL: QC exact labelled boundary_values; rc=" `outcome'
}
else {
    local ++pass
    display as result "PASS: QC exact labelled boundary_values"
}

**# JSON metadata exact labelled unsorted
local ++tests
capture noisily {
    * expect: INVARIANT
    qa_fx_a7_labelled, clear seed(37) perturb(unsorted)
    tempfile output
    qa_state_snapshot, tag(dm_json)
    quietly datamap, output(`"`output'"') format(json) continuous(x) mincell(0)
    assert r(nfiles)==1 & r(nobs)==40 & r(nvars)==10
    qa_state_compare, tag(dm_json)
    python: _ds=__import__("json").loads(__import__("pathlib").Path(__import__("sfi").Macro.getLocal("output")).read_text())["datasets"][0]; _v={v["name"]:v for v in _ds["variable_metadata"]}; assert _ds["observations"]==40 and _ds["variables"]==10; assert _v["all_missing"]["missing_n"]==40 and _v["extended"]["missing_n"]==40; assert _v["x"]["missing_n"]==0; assert _v["x"]["summary"]=={} if 0>0 else _v["x"]["summary"]["mean"]==20.5
    python: _g=_v["group"]["frequencies"]; assert {q["value"]:q["count"] for q in _g}==({"1":1} if 40==1 else {"1":10,"2":10,"5":10,"9":10})

}
local outcome=_rc

if `outcome' {
    local ++fail
    display as error "FAIL: JSON metadata exact labelled unsorted; rc=" `outcome'
}
else {
    local ++pass
    display as result "PASS: JSON metadata exact labelled unsorted"
}

**# Missingness exact labelled unsorted
local ++tests
capture noisily {
    * expect: INVARIANT
    qa_fx_a7_labelled, clear seed(37) perturb(unsorted)
    global S_2 "CALLER_KEEP"
    qa_state_snapshot, tag(dm_miss)
    quietly datamvp x extended all_missing, nodrop
    assert r(N)==40 & r(N_complete)==0 & r(N_incomplete)==40
    assert r(N_vars)==3 & r(N_patterns)==1
    assert r(N_mv_total)==80
    assert r(max_miss)==2 & r(mean_miss)==2
    qa_state_compare, tag(dm_miss)

}
local outcome=_rc

if `outcome' {
    local ++fail
    display as error "FAIL: Missingness exact labelled unsorted; rc=" `outcome'
}
else {
    local ++pass
    display as result "PASS: Missingness exact labelled unsorted"
}

**# QC exact labelled unsorted
local ++tests
capture noisily {
    * expect: INVARIANT
    qa_fx_a7_labelled, clear seed(37) perturb(unsorted)
    qa_state_snapshot, tag(dm_qc)
    quietly datacheck, gatesonly expectn(40) isid(id) binary(y) allowed(group 1 2 5 9)
    assert r(N)==40 & r(n_failed)==0 & r(n_errors)==0
    assert r(n_checks)==4 & r(n_passed)==4
    qa_state_compare, tag(dm_qc)

}
local outcome=_rc

if `outcome' {
    local ++fail
    display as error "FAIL: QC exact labelled unsorted; rc=" `outcome'
}
else {
    local ++pass
    display as result "PASS: QC exact labelled unsorted"
}

display "RESULT: validation_datamap_fixture_contract tests=`tests' pass=`pass' fail=`fail'"
log close
if `fail' exit 1
