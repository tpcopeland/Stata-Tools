*! test_datamap_fixture_domains.do -- actual declared numeric preflight endpoints
*! Author: Timothy P Copeland, Karolinska Institutet
version 16.0
clear all
set more off
capture log close _all
log using test_datamap_fixture_domains.log,text replace
local pkg_dir=substr("`c(pwd)'",1,strlen("`c(pwd)'")-3)
adopath ++ "`pkg_dir'"
do _qa_fx_a7.do
do _qa_metamorphic.do
do _qa_state.do
local tests 0
local pass 0
local fail 0
capture program drop _dm_domain_json
program define _dm_domain_json
    args output
    python: _j=__import__("json").loads(__import__("pathlib").Path(__import__("sfi").Macro.getLocal("output")).read_text())["datasets"][0]; _v={v["name"]:v for v in _j["variable_metadata"]}; assert _j["observations"]==40 and _j["variables"]==10 and _v["all_missing"]["missing_n"]==40 and _v["extended"]["missing_n"]==40 and _v["x"]["missing_n"]==0
end
capture program drop _dd_domain_metadata
program define _dd_domain_metadata
    args metadata
    preserve
    quietly use `"`metadata'"', clear
    assert _N==10 & N==40 & nvars==10
    assert missing==40 & unique==0 if variable=="all_missing"
    restore
end

**# datamap maxcat lower domain
local ++tests
capture noisily {
    * expect: EXACT
    qa_fx_a7_labelled, clear seed(37) perturb(label_gaps)
    tempfile output metadata
    qa_state_snapshot, tag(dm_domain)
    qa_option_domain, command(datamap, output(`"`output'"') format(json) maxcat(@v@)) inside(1 2 100) outside(0 . 1.5) check(_dm_domain_json `"`output'"')
    assert r(n_cells)==6 & r(n_violations)==0
    qa_state_compare, tag(dm_domain)
}
local outcome=_rc
capture restore
if `outcome' {
    local ++fail
    display as error "FAIL: datamap maxcat rc=" `outcome'
}
else {
    local ++pass
    display as result "PASS: datamap maxcat"
}

**# datamap maxfreq lower domain
local ++tests
capture noisily {
    * expect: EXACT
    qa_fx_a7_labelled, clear seed(37) perturb(label_gaps)
    tempfile output metadata
    qa_state_snapshot, tag(dm_domain)
    qa_option_domain, command(datamap, output(`"`output'"') format(json) maxfreq(@v@)) inside(1 2 100) outside(0 . 1.5) check(_dm_domain_json `"`output'"')
    assert r(n_cells)==6 & r(n_violations)==0
    qa_state_compare, tag(dm_domain)
}
local outcome=_rc
capture restore
if `outcome' {
    local ++fail
    display as error "FAIL: datamap maxfreq rc=" `outcome'
}
else {
    local ++pass
    display as result "PASS: datamap maxfreq"
}

**# datamap samples lower domain
local ++tests
capture noisily {
    * expect: EXACT
    qa_fx_a7_labelled, clear seed(37) perturb(label_gaps)
    tempfile output metadata
    qa_state_snapshot, tag(dm_domain)
    qa_option_domain, command(datamap, output(`"`output'"') format(text) samples(@v@)) inside(0 1 100) outside(-1 . 1.5) check(assert r(nobs)==40 & r(nvars)==10 & r(nfiles)==1)
    assert r(n_cells)==6 & r(n_violations)==0
    qa_state_compare, tag(dm_domain)
}
local outcome=_rc
capture restore
if `outcome' {
    local ++fail
    display as error "FAIL: datamap samples rc=" `outcome'
}
else {
    local ++pass
    display as result "PASS: datamap samples"
}

**# datamap uniqcap lower domain
local ++tests
capture noisily {
    * expect: EXACT
    qa_fx_a7_labelled, clear seed(37) perturb(label_gaps)
    tempfile output metadata
    qa_state_snapshot, tag(dm_domain)
    qa_option_domain, command(datamap, output(`"`output'"') format(json) uniqcap(@v@)) inside(0 1 100) outside(-1 . 1.5) check(_dm_domain_json `"`output'"')
    assert r(n_cells)==6 & r(n_violations)==0
    qa_state_compare, tag(dm_domain)
}
local outcome=_rc
capture restore
if `outcome' {
    local ++fail
    display as error "FAIL: datamap uniqcap rc=" `outcome'
}
else {
    local ++pass
    display as result "PASS: datamap uniqcap"
}

**# datadict maxcat lower domain
local ++tests
capture noisily {
    * expect: EXACT
    qa_fx_a7_labelled, clear seed(37) perturb(label_gaps)
    tempfile output metadata
    qa_state_snapshot, tag(dm_domain)
    qa_option_domain, command(datadict, output(`"`output'"') saving(`"`metadata'"', replace) stats maxcat(@v@)) inside(1 2 100) outside(0 . 1.5) check(_dd_domain_metadata `"`metadata'"')
    assert r(n_cells)==6 & r(n_violations)==0
    qa_state_compare, tag(dm_domain)
}
local outcome=_rc
capture restore
if `outcome' {
    local ++fail
    display as error "FAIL: datadict maxcat rc=" `outcome'
}
else {
    local ++pass
    display as result "PASS: datadict maxcat"
}

**# datadict maxfreq lower domain
local ++tests
capture noisily {
    * expect: EXACT
    qa_fx_a7_labelled, clear seed(37) perturb(label_gaps)
    tempfile output metadata
    qa_state_snapshot, tag(dm_domain)
    qa_option_domain, command(datadict, output(`"`output'"') saving(`"`metadata'"', replace) stats maxfreq(@v@)) inside(1 2 100) outside(0 . 1.5) check(_dd_domain_metadata `"`metadata'"')
    assert r(n_cells)==6 & r(n_violations)==0
    qa_state_compare, tag(dm_domain)
}
local outcome=_rc
capture restore
if `outcome' {
    local ++fail
    display as error "FAIL: datadict maxfreq rc=" `outcome'
}
else {
    local ++pass
    display as result "PASS: datadict maxfreq"
}

**# datadict uniqcap lower domain
local ++tests
capture noisily {
    * expect: EXACT
    qa_fx_a7_labelled, clear seed(37) perturb(label_gaps)
    tempfile output metadata
    qa_state_snapshot, tag(dm_domain)
    qa_option_domain, command(datadict, output(`"`output'"') saving(`"`metadata'"', replace) stats uniqcap(@v@)) inside(0 1 100) outside(-1 . 1.5) check(_dd_domain_metadata `"`metadata'"')
    assert r(n_cells)==6 & r(n_violations)==0
    qa_state_compare, tag(dm_domain)
}
local outcome=_rc
capture restore
if `outcome' {
    local ++fail
    display as error "FAIL: datadict uniqcap rc=" `outcome'
}
else {
    local ++pass
    display as result "PASS: datadict uniqcap"
}

**# datacheck maxcat lower domain
local ++tests
capture noisily {
    * expect: EXACT
    qa_fx_a7_labelled, clear seed(37) perturb(label_gaps)
    tempfile output metadata
    qa_state_snapshot, tag(dm_domain)
    qa_option_domain, command(datacheck, gatesonly expectn(40) maxcat(@v@)) inside(1 2 100) outside(0 . 1.5) check(assert r(N)==40 & r(n_checks)==1 & r(n_passed)==1 & r(n_failed)==0)
    assert r(n_cells)==6 & r(n_violations)==0
    qa_state_compare, tag(dm_domain)
}
local outcome=_rc
capture restore
if `outcome' {
    local ++fail
    display as error "FAIL: datacheck maxcat rc=" `outcome'
}
else {
    local ++pass
    display as result "PASS: datacheck maxcat"
}

**# datacheck maxfreq lower domain
local ++tests
capture noisily {
    * expect: EXACT
    qa_fx_a7_labelled, clear seed(37) perturb(label_gaps)
    tempfile output metadata
    qa_state_snapshot, tag(dm_domain)
    qa_option_domain, command(datacheck, gatesonly expectn(40) maxfreq(@v@)) inside(1 2 100) outside(0 . 1.5) check(assert r(N)==40 & r(n_checks)==1 & r(n_passed)==1 & r(n_failed)==0)
    assert r(n_cells)==6 & r(n_violations)==0
    qa_state_compare, tag(dm_domain)
}
local outcome=_rc
capture restore
if `outcome' {
    local ++fail
    display as error "FAIL: datacheck maxfreq rc=" `outcome'
}
else {
    local ++pass
    display as result "PASS: datacheck maxfreq"
}

**# datacheck rare lower domain
local ++tests
capture noisily {
    * expect: EXACT
    qa_fx_a7_labelled, clear seed(37) perturb(label_gaps)
    tempfile output metadata
    qa_state_snapshot, tag(dm_domain)
    qa_option_domain, command(datacheck, gatesonly expectn(40) rare(@v@)) inside(0 1 100) outside(-1 . 1.5) check(assert r(N)==40 & r(n_checks)==1 & r(n_passed)==1 & r(n_failed)==0)
    assert r(n_cells)==6 & r(n_violations)==0
    qa_state_compare, tag(dm_domain)
}
local outcome=_rc
capture restore
if `outcome' {
    local ++fail
    display as error "FAIL: datacheck rare rc=" `outcome'
}
else {
    local ++pass
    display as result "PASS: datacheck rare"
}

**# datacheck outliers lower domain
local ++tests
capture noisily {
    * expect: EXACT
    qa_fx_a7_labelled, clear seed(37) perturb(label_gaps)
    tempfile output metadata
    qa_state_snapshot, tag(dm_domain)
    qa_option_domain, command(datacheck, gatesonly expectn(40) outliers(@v@)) inside(0 1 100) outside(-1 .) check(assert r(N)==40 & r(n_checks)==1 & r(n_passed)==1 & r(n_failed)==0)
    assert r(n_cells)==5 & r(n_violations)==0
    qa_state_compare, tag(dm_domain)
}
local outcome=_rc
capture restore
if `outcome' {
    local ++fail
    display as error "FAIL: datacheck outliers rc=" `outcome'
}
else {
    local ++pass
    display as result "PASS: datacheck outliers"
}

**# datacheck mincell lower domain
local ++tests
capture noisily {
    * expect: EXACT
    qa_fx_a7_labelled, clear seed(37) perturb(label_gaps)
    tempfile output metadata
    qa_state_snapshot, tag(dm_domain)
    qa_option_domain, command(datacheck, gatesonly expectn(40) mincell(@v@)) inside(0 1 100) outside(-1 . 1.5) check(assert r(N)==40 & r(n_checks)==1 & r(n_passed)==1 & r(n_failed)==0)
    assert r(n_cells)==6 & r(n_violations)==0
    qa_state_compare, tag(dm_domain)
}
local outcome=_rc
capture restore
if `outcome' {
    local ++fail
    display as error "FAIL: datacheck mincell rc=" `outcome'
}
else {
    local ++pass
    display as result "PASS: datacheck mincell"
}

**# datamvp minfreq lower domain
local ++tests
capture noisily {
    * expect: EXACT
    qa_fx_a7_labelled, clear seed(37) perturb(label_gaps)
    tempfile output metadata
    qa_state_snapshot, tag(dm_domain)
    qa_option_domain, command(datamvp x all_missing extended, nodrop minfreq(@v@)) inside(1 2 100) outside(0 . 1.5) check(assert r(N)==40 & r(N_complete)==0 & r(N_mv_total)==80 & r(mean_miss)==2)
    assert r(n_cells)==6 & r(n_violations)==0
    qa_state_compare, tag(dm_domain)
}
local outcome=_rc
capture restore
if `outcome' {
    local ++fail
    display as error "FAIL: datamvp minfreq rc=" `outcome'
}
else {
    local ++pass
    display as result "PASS: datamvp minfreq"
}

**# datamvp top lower domain
local ++tests
capture noisily {
    * expect: EXACT
    qa_fx_a7_labelled, clear seed(37) perturb(label_gaps)
    tempfile output metadata
    qa_state_snapshot, tag(dm_domain)
    qa_option_domain, command(datamvp x all_missing extended, nodrop top(@v@)) inside(1 2 100) outside(0 . 1.5) check(assert r(N)==40 & r(N_complete)==0 & r(N_mv_total)==80 & r(mean_miss)==2)
    assert r(n_cells)==6 & r(n_violations)==0
    qa_state_compare, tag(dm_domain)
}
local outcome=_rc
capture restore
if `outcome' {
    local ++fail
    display as error "FAIL: datamvp top rc=" `outcome'
}
else {
    local ++pass
    display as result "PASS: datamvp top"
}

**# datamvp groupgap lower domain
local ++tests
capture noisily {
    * expect: EXACT
    qa_fx_a7_labelled, clear seed(37) perturb(label_gaps)
    tempfile output metadata
    qa_state_snapshot, tag(dm_domain)
    qa_option_domain, command(datamvp x all_missing extended, nodrop groupgap(@v@) graph(bar) over(group) gname(dm_domain) nodraw) inside(0 1 100) outside(-1 . .a) check(assert r(N)==40 & r(N_complete)==0 & r(N_mv_total)==80 & r(mean_miss)==2)
    assert r(n_cells)==6 & r(n_violations)==0
    qa_state_compare, tag(dm_domain)
}
local outcome=_rc
capture restore
if `outcome' {
    local ++fail
    display as error "FAIL: datamvp groupgap rc=" `outcome'
}
else {
    local ++pass
    display as result "PASS: datamvp groupgap"
}

**# datamvp mincell lower domain
local ++tests
capture noisily {
    * expect: EXACT
    qa_fx_a7_labelled, clear seed(37) perturb(label_gaps)
    tempfile output metadata
    qa_state_snapshot, tag(dm_domain)
    qa_option_domain, command(datamvp x all_missing extended, nodrop mincell(@v@)) inside(0 1 100) outside(-1 . 1.5) check(assert r(N)==40 & r(N_complete)==0 & r(N_mv_total)==80 & r(mean_miss)==2)
    assert r(n_cells)==6 & r(n_violations)==0
    qa_state_compare, tag(dm_domain)
}
local outcome=_rc
capture restore
if `outcome' {
    local ++fail
    display as error "FAIL: datamvp mincell rc=" `outcome'
}
else {
    local ++pass
    display as result "PASS: datamvp mincell"
}

display "RESULT: test_datamap_fixture_domains tests=`tests' pass=`pass' fail=`fail'"
log close
if `fail' exit 1
