*! validation_dataqa_fixture_contract.do -- exact canonical ledger/report/export and comparison drift
*! Author: Timothy P Copeland, Karolinska Institutet
version 16
clear all
set more off
capture log close _all
log using "validation_dataqa_fixture_contract.log", text replace
local pkg_dir=substr("`c(pwd)'",1,strlen("`c(pwd)'")-3)
adopath ++ "`pkg_dir'"
do _qa_fx_a7.do
do _qa_state.do
local tests 0
local pass 0
local fail 0

**# Exact gate register friendly
local ++tests
local release ""
capture noisily {
    * expect: EXACT
    qa_fx_a7_labelled, clear seed(37)
    local N=_N
    tempfile ledger md exported baseline
    quietly dataqa set ledger("`ledger'") run(fx) maskrare mincell(5)
    assert `"`r(defaults)'"'==`"maskrare mincell(5) ledger("`ledger'") run(fx)"'
    qa_state_snapshot, tag(gate_ledger)
    quietly datacheck, gatesonly isid(id) expectn(`N') allowed(group 1 2 5 9) name(canonical)
    assert r(n_checks)==3 & r(n_passed)==3 & r(n_failed)==0
    qa_state_compare, tag(gate_ledger)
    qa_state_snapshot, tag(gate_ledger)
    quietly dataqa report using "`ledger'", run(fx) markdown("`md'")
    assert r(N)==3 & r(n_rows)==1 & r(n_datasets)==1 & r(n_failed)==0 & r(n_warned)==0
    qa_state_compare, tag(gate_ledger)
    python: _text=__import__("pathlib").Path(__import__("sfi").Macro.getLocal("md")).read_text(); assert "| fx | canonical | all gates passed: allowed expectn isid | 0 violations in 3 gate entries | as declared | clean |" in _text
    qa_state_snapshot, tag(gate_ledger)
    quietly dataqa assert using "`ledger'", run(fx) expect(canonical)
    assert r(N)==3 & r(n_failed)==0
    qa_state_compare, tag(gate_ledger)
    qa_state_snapshot, tag(gate_ledger)
    quietly dataqa export using "`ledger'", run(fx) saving("`exported'") threshold(5)
    local release `"`r(saving)'"'
    assert r(N)==3 & r(n_scope_dropped)==0
    qa_state_compare, tag(gate_ledger)
    preserve
    quietly use `"`macval(release)'"', clear
    assert _N==3 & run=="fx" & dataset=="canonical" & kind=="invariant" & status=="pass"
    assert masked==1 & mincell==5
    assert n_scope==`N' if `N'>=5
    assert missing(n_scope) if `N'<5
    quietly count if family=="expectn"
    assert r(N)==1
    assert observed_num==`N' & observed=="`N'" if family=="expectn" & `N'>=5
    assert missing(observed_num) & obs_masked==1 if family=="expectn" & `N'<5
    assert observed_num==0 if inlist(family,"isid","allowed")
    * Counterfeit baseline: all three N fields differ; withholding vs0 is
    * also a declared difference, so comparison must report EXACTLY3 flags.
    quietly replace n_scope=cond(`N'<5,0,`N'/2)
    quietly save "`baseline'", replace
    restore
    qa_state_snapshot, tag(gate_ledger)
    quietly dataqa compare using "`ledger'", run(fx) baseledger("`baseline'") baseline(fx)
    assert r(n_flags)==3
    qa_state_compare, tag(gate_ledger)
    quietly dataqa set clear
    assert `"`r(defaults)'"'==""
}
local outcome=_rc
capture restore
if `"`macval(release)'"'!="" capture erase `"`macval(release)'"'
if `outcome' {
    local ++fail
    display as error "FAIL: friendly; rc=" `outcome'
}
else {
    local ++pass
    display as result "PASS: friendly"
}

**# Exact gate register unsorted
local ++tests
local release ""
capture noisily {
    * expect: EXACT
    qa_fx_a7_labelled, clear seed(37) perturb(unsorted)
    local N=_N
    tempfile ledger md exported baseline
    quietly dataqa set ledger("`ledger'") run(fx) maskrare mincell(5)
    assert `"`r(defaults)'"'==`"maskrare mincell(5) ledger("`ledger'") run(fx)"'
    qa_state_snapshot, tag(gate_ledger)
    quietly datacheck, gatesonly isid(id) expectn(`N') allowed(group 1 2 5 9) name(canonical)
    assert r(n_checks)==3 & r(n_passed)==3 & r(n_failed)==0
    qa_state_compare, tag(gate_ledger)
    qa_state_snapshot, tag(gate_ledger)
    quietly dataqa report using "`ledger'", run(fx) markdown("`md'")
    assert r(N)==3 & r(n_rows)==1 & r(n_datasets)==1 & r(n_failed)==0 & r(n_warned)==0
    qa_state_compare, tag(gate_ledger)
    python: _text=__import__("pathlib").Path(__import__("sfi").Macro.getLocal("md")).read_text(); assert "| fx | canonical | all gates passed: allowed expectn isid | 0 violations in 3 gate entries | as declared | clean |" in _text
    qa_state_snapshot, tag(gate_ledger)
    quietly dataqa assert using "`ledger'", run(fx) expect(canonical)
    assert r(N)==3 & r(n_failed)==0
    qa_state_compare, tag(gate_ledger)
    qa_state_snapshot, tag(gate_ledger)
    quietly dataqa export using "`ledger'", run(fx) saving("`exported'") threshold(5)
    local release `"`r(saving)'"'
    assert r(N)==3 & r(n_scope_dropped)==0
    qa_state_compare, tag(gate_ledger)
    preserve
    quietly use `"`macval(release)'"', clear
    assert _N==3 & run=="fx" & dataset=="canonical" & kind=="invariant" & status=="pass"
    assert masked==1 & mincell==5
    assert n_scope==`N' if `N'>=5
    assert missing(n_scope) if `N'<5
    quietly count if family=="expectn"
    assert r(N)==1
    assert observed_num==`N' & observed=="`N'" if family=="expectn" & `N'>=5
    assert missing(observed_num) & obs_masked==1 if family=="expectn" & `N'<5
    assert observed_num==0 if inlist(family,"isid","allowed")
    * Counterfeit baseline: all three N fields differ; withholding vs0 is
    * also a declared difference, so comparison must report EXACTLY3 flags.
    quietly replace n_scope=cond(`N'<5,0,`N'/2)
    quietly save "`baseline'", replace
    restore
    qa_state_snapshot, tag(gate_ledger)
    quietly dataqa compare using "`ledger'", run(fx) baseledger("`baseline'") baseline(fx)
    assert r(n_flags)==3
    qa_state_compare, tag(gate_ledger)
    quietly dataqa set clear
    assert `"`r(defaults)'"'==""
}
local outcome=_rc
capture restore
if `"`macval(release)'"'!="" capture erase `"`macval(release)'"'
if `outcome' {
    local ++fail
    display as error "FAIL: unsorted; rc=" `outcome'
}
else {
    local ++pass
    display as result "PASS: unsorted"
}

**# Exact gate register label_gaps
local ++tests
local release ""
capture noisily {
    * expect: EXACT
    qa_fx_a7_labelled, clear seed(37) perturb(label_gaps)
    local N=_N
    tempfile ledger md exported baseline
    quietly dataqa set ledger("`ledger'") run(fx) maskrare mincell(5)
    assert `"`r(defaults)'"'==`"maskrare mincell(5) ledger("`ledger'") run(fx)"'
    qa_state_snapshot, tag(gate_ledger)
    quietly datacheck, gatesonly isid(id) expectn(`N') allowed(group 1 2 5 9) name(canonical)
    assert r(n_checks)==3 & r(n_passed)==3 & r(n_failed)==0
    qa_state_compare, tag(gate_ledger)
    qa_state_snapshot, tag(gate_ledger)
    quietly dataqa report using "`ledger'", run(fx) markdown("`md'")
    assert r(N)==3 & r(n_rows)==1 & r(n_datasets)==1 & r(n_failed)==0 & r(n_warned)==0
    qa_state_compare, tag(gate_ledger)
    python: _text=__import__("pathlib").Path(__import__("sfi").Macro.getLocal("md")).read_text(); assert "| fx | canonical | all gates passed: allowed expectn isid | 0 violations in 3 gate entries | as declared | clean |" in _text
    qa_state_snapshot, tag(gate_ledger)
    quietly dataqa assert using "`ledger'", run(fx) expect(canonical)
    assert r(N)==3 & r(n_failed)==0
    qa_state_compare, tag(gate_ledger)
    qa_state_snapshot, tag(gate_ledger)
    quietly dataqa export using "`ledger'", run(fx) saving("`exported'") threshold(5)
    local release `"`r(saving)'"'
    assert r(N)==3 & r(n_scope_dropped)==0
    qa_state_compare, tag(gate_ledger)
    preserve
    quietly use `"`macval(release)'"', clear
    assert _N==3 & run=="fx" & dataset=="canonical" & kind=="invariant" & status=="pass"
    assert masked==1 & mincell==5
    assert n_scope==`N' if `N'>=5
    assert missing(n_scope) if `N'<5
    quietly count if family=="expectn"
    assert r(N)==1
    assert observed_num==`N' & observed=="`N'" if family=="expectn" & `N'>=5
    assert missing(observed_num) & obs_masked==1 if family=="expectn" & `N'<5
    assert observed_num==0 if inlist(family,"isid","allowed")
    * Counterfeit baseline: all three N fields differ; withholding vs0 is
    * also a declared difference, so comparison must report EXACTLY3 flags.
    quietly replace n_scope=cond(`N'<5,0,`N'/2)
    quietly save "`baseline'", replace
    restore
    qa_state_snapshot, tag(gate_ledger)
    quietly dataqa compare using "`ledger'", run(fx) baseledger("`baseline'") baseline(fx)
    assert r(n_flags)==3
    qa_state_compare, tag(gate_ledger)
    quietly dataqa set clear
    assert `"`r(defaults)'"'==""
}
local outcome=_rc
capture restore
if `"`macval(release)'"'!="" capture erase `"`macval(release)'"'
if `outcome' {
    local ++fail
    display as error "FAIL: label_gaps; rc=" `outcome'
}
else {
    local ++pass
    display as result "PASS: label_gaps"
}

**# Exact gate register single_row
local ++tests
local release ""
capture noisily {
    * expect: EXACT
    qa_fx_a7_labelled, clear seed(37) perturb(single_row)
    local N=_N
    tempfile ledger md exported baseline
    quietly dataqa set ledger("`ledger'") run(fx) maskrare mincell(5)
    assert `"`r(defaults)'"'==`"maskrare mincell(5) ledger("`ledger'") run(fx)"'
    qa_state_snapshot, tag(gate_ledger)
    quietly datacheck, gatesonly isid(id) expectn(`N') allowed(group 1 2 5 9) name(canonical)
    assert r(n_checks)==3 & r(n_passed)==3 & r(n_failed)==0
    qa_state_compare, tag(gate_ledger)
    qa_state_snapshot, tag(gate_ledger)
    quietly dataqa report using "`ledger'", run(fx) markdown("`md'")
    assert r(N)==3 & r(n_rows)==1 & r(n_datasets)==1 & r(n_failed)==0 & r(n_warned)==0
    qa_state_compare, tag(gate_ledger)
    python: _text=__import__("pathlib").Path(__import__("sfi").Macro.getLocal("md")).read_text(); assert "| fx | canonical | all gates passed: allowed expectn isid | 0 violations in 3 gate entries | as declared | clean |" in _text
    qa_state_snapshot, tag(gate_ledger)
    quietly dataqa assert using "`ledger'", run(fx) expect(canonical)
    assert r(N)==3 & r(n_failed)==0
    qa_state_compare, tag(gate_ledger)
    qa_state_snapshot, tag(gate_ledger)
    quietly dataqa export using "`ledger'", run(fx) saving("`exported'") threshold(5)
    local release `"`r(saving)'"'
    assert r(N)==3 & r(n_scope_dropped)==0
    qa_state_compare, tag(gate_ledger)
    preserve
    quietly use `"`macval(release)'"', clear
    assert _N==3 & run=="fx" & dataset=="canonical" & kind=="invariant" & status=="pass"
    assert masked==1 & mincell==5
    assert n_scope==`N' if `N'>=5
    assert missing(n_scope) if `N'<5
    quietly count if family=="expectn"
    assert r(N)==1
    assert observed_num==`N' & observed=="`N'" if family=="expectn" & `N'>=5
    assert missing(observed_num) & obs_masked==1 if family=="expectn" & `N'<5
    assert observed_num==0 if inlist(family,"isid","allowed")
    * Counterfeit baseline: all three N fields differ; withholding vs0 is
    * also a declared difference, so comparison must report EXACTLY3 flags.
    quietly replace n_scope=cond(`N'<5,0,`N'/2)
    quietly save "`baseline'", replace
    restore
    qa_state_snapshot, tag(gate_ledger)
    quietly dataqa compare using "`ledger'", run(fx) baseledger("`baseline'") baseline(fx)
    assert r(n_flags)==3
    qa_state_compare, tag(gate_ledger)
    quietly dataqa set clear
    assert `"`r(defaults)'"'==""
}
local outcome=_rc
capture restore
if `"`macval(release)'"'!="" capture erase `"`macval(release)'"'
if `outcome' {
    local ++fail
    display as error "FAIL: single_row; rc=" `outcome'
}
else {
    local ++pass
    display as result "PASS: single_row"
}

**# Exact gate register miss_all_column
local ++tests
local release ""
capture noisily {
    * expect: EXACT
    qa_fx_a7_labelled, clear seed(37) perturb(miss_all_column)
    local N=_N
    tempfile ledger md exported baseline
    quietly dataqa set ledger("`ledger'") run(fx) maskrare mincell(5)
    assert `"`r(defaults)'"'==`"maskrare mincell(5) ledger("`ledger'") run(fx)"'
    qa_state_snapshot, tag(gate_ledger)
    quietly datacheck, gatesonly isid(id) expectn(`N') allowed(group 1 2 5 9) name(canonical)
    assert r(n_checks)==3 & r(n_passed)==3 & r(n_failed)==0
    qa_state_compare, tag(gate_ledger)
    qa_state_snapshot, tag(gate_ledger)
    quietly dataqa report using "`ledger'", run(fx) markdown("`md'")
    assert r(N)==3 & r(n_rows)==1 & r(n_datasets)==1 & r(n_failed)==0 & r(n_warned)==0
    qa_state_compare, tag(gate_ledger)
    python: _text=__import__("pathlib").Path(__import__("sfi").Macro.getLocal("md")).read_text(); assert "| fx | canonical | all gates passed: allowed expectn isid | 0 violations in 3 gate entries | as declared | clean |" in _text
    qa_state_snapshot, tag(gate_ledger)
    quietly dataqa assert using "`ledger'", run(fx) expect(canonical)
    assert r(N)==3 & r(n_failed)==0
    qa_state_compare, tag(gate_ledger)
    qa_state_snapshot, tag(gate_ledger)
    quietly dataqa export using "`ledger'", run(fx) saving("`exported'") threshold(5)
    local release `"`r(saving)'"'
    assert r(N)==3 & r(n_scope_dropped)==0
    qa_state_compare, tag(gate_ledger)
    preserve
    quietly use `"`macval(release)'"', clear
    assert _N==3 & run=="fx" & dataset=="canonical" & kind=="invariant" & status=="pass"
    assert masked==1 & mincell==5
    assert n_scope==`N' if `N'>=5
    assert missing(n_scope) if `N'<5
    quietly count if family=="expectn"
    assert r(N)==1
    assert observed_num==`N' & observed=="`N'" if family=="expectn" & `N'>=5
    assert missing(observed_num) & obs_masked==1 if family=="expectn" & `N'<5
    assert observed_num==0 if inlist(family,"isid","allowed")
    * Counterfeit baseline: all three N fields differ; withholding vs0 is
    * also a declared difference, so comparison must report EXACTLY3 flags.
    quietly replace n_scope=cond(`N'<5,0,`N'/2)
    quietly save "`baseline'", replace
    restore
    qa_state_snapshot, tag(gate_ledger)
    quietly dataqa compare using "`ledger'", run(fx) baseledger("`baseline'") baseline(fx)
    assert r(n_flags)==3
    qa_state_compare, tag(gate_ledger)
    quietly dataqa set clear
    assert `"`r(defaults)'"'==""
}
local outcome=_rc
capture restore
if `"`macval(release)'"'!="" capture erase `"`macval(release)'"'
if `outcome' {
    local ++fail
    display as error "FAIL: miss_all_column; rc=" `outcome'
}
else {
    local ++pass
    display as result "PASS: miss_all_column"
}

**# Exact gate register boundary_values
local ++tests
local release ""
capture noisily {
    * expect: EXACT
    qa_fx_a7_labelled, clear seed(37) perturb(boundary_values)
    local N=_N
    tempfile ledger md exported baseline
    quietly dataqa set ledger("`ledger'") run(fx) maskrare mincell(5)
    assert `"`r(defaults)'"'==`"maskrare mincell(5) ledger("`ledger'") run(fx)"'
    qa_state_snapshot, tag(gate_ledger)
    quietly datacheck, gatesonly isid(id) expectn(`N') allowed(group 1 2 5 9) name(canonical)
    assert r(n_checks)==3 & r(n_passed)==3 & r(n_failed)==0
    qa_state_compare, tag(gate_ledger)
    qa_state_snapshot, tag(gate_ledger)
    quietly dataqa report using "`ledger'", run(fx) markdown("`md'")
    assert r(N)==3 & r(n_rows)==1 & r(n_datasets)==1 & r(n_failed)==0 & r(n_warned)==0
    qa_state_compare, tag(gate_ledger)
    python: _text=__import__("pathlib").Path(__import__("sfi").Macro.getLocal("md")).read_text(); assert "| fx | canonical | all gates passed: allowed expectn isid | 0 violations in 3 gate entries | as declared | clean |" in _text
    qa_state_snapshot, tag(gate_ledger)
    quietly dataqa assert using "`ledger'", run(fx) expect(canonical)
    assert r(N)==3 & r(n_failed)==0
    qa_state_compare, tag(gate_ledger)
    qa_state_snapshot, tag(gate_ledger)
    quietly dataqa export using "`ledger'", run(fx) saving("`exported'") threshold(5)
    local release `"`r(saving)'"'
    assert r(N)==3 & r(n_scope_dropped)==0
    qa_state_compare, tag(gate_ledger)
    preserve
    quietly use `"`macval(release)'"', clear
    assert _N==3 & run=="fx" & dataset=="canonical" & kind=="invariant" & status=="pass"
    assert masked==1 & mincell==5
    assert n_scope==`N' if `N'>=5
    assert missing(n_scope) if `N'<5
    quietly count if family=="expectn"
    assert r(N)==1
    assert observed_num==`N' & observed=="`N'" if family=="expectn" & `N'>=5
    assert missing(observed_num) & obs_masked==1 if family=="expectn" & `N'<5
    assert observed_num==0 if inlist(family,"isid","allowed")
    * Counterfeit baseline: all three N fields differ; withholding vs0 is
    * also a declared difference, so comparison must report EXACTLY3 flags.
    quietly replace n_scope=cond(`N'<5,0,`N'/2)
    quietly save "`baseline'", replace
    restore
    qa_state_snapshot, tag(gate_ledger)
    quietly dataqa compare using "`ledger'", run(fx) baseledger("`baseline'") baseline(fx)
    assert r(n_flags)==3
    qa_state_compare, tag(gate_ledger)
    quietly dataqa set clear
    assert `"`r(defaults)'"'==""
}
local outcome=_rc
capture restore
if `"`macval(release)'"'!="" capture erase `"`macval(release)'"'
if `outcome' {
    local ++fail
    display as error "FAIL: boundary_values; rc=" `outcome'
}
else {
    local ++pass
    display as result "PASS: boundary_values"
}

display "RESULT: validation_dataqa_fixture_contract tests=`tests' pass=`pass' fail=`fail'"
log close
if `fail' exit 1
