*! test_datacheck_fixture_ledger_quotes.do -- actual filename bytes and unchanged ledger dispatch
*! Author: Timothy P Copeland, Karolinska Institutet
version 16.0
clear all
set more off
capture log close _all
log using test_datacheck_fixture_ledger_quotes.log, text replace
local pkg_dir=substr("`c(pwd)'",1,strlen("`c(pwd)'")-3)
adopath ++ "`pkg_dir'"
do _qa_fx_a7.do
do _qa_state.do
local tests 0
local pass 0
local fail 0

**# simple_spaces
local ++tests
local root ""
capture noisily {
    * expect: EXACT
    qa_fx_a7_files, clear seed(37) perturb(path_hostile)
    local root `"`r(root)'"'
    local ledger `"`root'/ledger spaces.dta"'
    python: from pathlib import Path; from sfi import Macro; _ld_before={str(p.relative_to(Path(Macro.getLocal("root")))):p.read_bytes() for p in Path(Macro.getLocal("root")).rglob("*") if p.is_file()}
    qa_fx_a7_labelled, clear seed(37)
    qa_state_snapshot, tag(ledger_quotes)
    quietly datacheck, gatesonly expectn(40) ledger("`ledger'", run("qa same"))
    assert r(N)==40 & r(n_checks)==1 & r(n_passed)==1 & r(n_failed)==0 & r(ledger_seq)==1
    assert `"`r(ledger)'"'==`"`macval(ledger)'"'
    qa_state_compare, tag(ledger_quotes)
    qa_state_snapshot, tag(ledger_quotes)
    quietly datacheck, gatesonly expectn(40) ledger("`ledger'", run("qa same"))
    assert r(N)==40 & r(n_checks)==1 & r(n_passed)==1 & r(n_failed)==0 & r(ledger_seq)==2
    assert `"`r(ledger)'"'==`"`macval(ledger)'"'
    qa_state_compare, tag(ledger_quotes)
    preserve
    quietly use `"`macval(ledger)'"', clear
    assert _N==2 & run=="qa same" & family=="expectn" & observed_num==40 & n_scope==40 & status=="pass"
    assert seq==_n
    restore
    python: _ld_after={str(p.relative_to(Path(Macro.getLocal("root")))):p.read_bytes() for p in Path(Macro.getLocal("root")).rglob("*") if p.is_file()}; _leaf=Path(Macro.getLocal("ledger")).name; assert set(_ld_after)-set(_ld_before)=={_leaf}; assert all(_ld_after[k]==v for k,v in _ld_before.items())
}
local outcome=_rc
capture log close ledgercause
capture restore
if `"`root'"'!="" capture noisily qa_fx_a7_cleanup, root(`"`macval(root)'"')
if `outcome' {
    local ++fail
    display as error "FAIL: simple_spaces rc=" `outcome'
}
else {
    local ++pass
    display as result "PASS: simple_spaces"
}

**# compound_spaces
local ++tests
local root ""
capture noisily {
    * expect: EXACT
    qa_fx_a7_files, clear seed(37) perturb(path_hostile)
    local root `"`r(root)'"'
    local ledger `"`root'/ledger spaces.dta"'
    python: from pathlib import Path; from sfi import Macro; _ld_before={str(p.relative_to(Path(Macro.getLocal("root")))):p.read_bytes() for p in Path(Macro.getLocal("root")).rglob("*") if p.is_file()}
    qa_fx_a7_labelled, clear seed(37)
    qa_state_snapshot, tag(ledger_quotes)
    quietly datacheck, gatesonly expectn(40) ledger(`"`macval(ledger)'"', run("qa same"))
    assert r(N)==40 & r(n_checks)==1 & r(n_passed)==1 & r(n_failed)==0 & r(ledger_seq)==1
    assert `"`r(ledger)'"'==`"`macval(ledger)'"'
    qa_state_compare, tag(ledger_quotes)
    qa_state_snapshot, tag(ledger_quotes)
    quietly datacheck, gatesonly expectn(40) ledger(`"`macval(ledger)'"', run("qa same"))
    assert r(N)==40 & r(n_checks)==1 & r(n_passed)==1 & r(n_failed)==0 & r(ledger_seq)==2
    assert `"`r(ledger)'"'==`"`macval(ledger)'"'
    qa_state_compare, tag(ledger_quotes)
    preserve
    quietly use `"`macval(ledger)'"', clear
    assert _N==2 & run=="qa same" & family=="expectn" & observed_num==40 & n_scope==40 & status=="pass"
    assert seq==_n
    restore
    python: _ld_after={str(p.relative_to(Path(Macro.getLocal("root")))):p.read_bytes() for p in Path(Macro.getLocal("root")).rglob("*") if p.is_file()}; _leaf=Path(Macro.getLocal("ledger")).name; assert set(_ld_after)-set(_ld_before)=={_leaf}; assert all(_ld_after[k]==v for k,v in _ld_before.items())
}
local outcome=_rc
capture log close ledgercause
capture restore
if `"`root'"'!="" capture noisily qa_fx_a7_cleanup, root(`"`macval(root)'"')
if `outcome' {
    local ++fail
    display as error "FAIL: compound_spaces rc=" `outcome'
}
else {
    local ++pass
    display as result "PASS: compound_spaces"
}

**# simple_unicode
local ++tests
local root ""
capture noisily {
    * expect: EXACT
    qa_fx_a7_files, clear seed(37) perturb(path_hostile)
    local root `"`r(root)'"'
    local ledger `"`root'/ledger Å.dta"'
    python: from pathlib import Path; from sfi import Macro; _ld_before={str(p.relative_to(Path(Macro.getLocal("root")))):p.read_bytes() for p in Path(Macro.getLocal("root")).rglob("*") if p.is_file()}
    qa_fx_a7_labelled, clear seed(37)
    qa_state_snapshot, tag(ledger_quotes)
    quietly datacheck, gatesonly expectn(40) ledger("`ledger'", run("qa same"))
    assert r(N)==40 & r(n_checks)==1 & r(n_passed)==1 & r(n_failed)==0 & r(ledger_seq)==1
    assert `"`r(ledger)'"'==`"`macval(ledger)'"'
    qa_state_compare, tag(ledger_quotes)
    qa_state_snapshot, tag(ledger_quotes)
    quietly datacheck, gatesonly expectn(40) ledger("`ledger'", run("qa same"))
    assert r(N)==40 & r(n_checks)==1 & r(n_passed)==1 & r(n_failed)==0 & r(ledger_seq)==2
    assert `"`r(ledger)'"'==`"`macval(ledger)'"'
    qa_state_compare, tag(ledger_quotes)
    preserve
    quietly use `"`macval(ledger)'"', clear
    assert _N==2 & run=="qa same" & family=="expectn" & observed_num==40 & n_scope==40 & status=="pass"
    assert seq==_n
    restore
    python: _ld_after={str(p.relative_to(Path(Macro.getLocal("root")))):p.read_bytes() for p in Path(Macro.getLocal("root")).rglob("*") if p.is_file()}; _leaf=Path(Macro.getLocal("ledger")).name; assert set(_ld_after)-set(_ld_before)=={_leaf}; assert all(_ld_after[k]==v for k,v in _ld_before.items())
}
local outcome=_rc
capture log close ledgercause
capture restore
if `"`root'"'!="" capture noisily qa_fx_a7_cleanup, root(`"`macval(root)'"')
if `outcome' {
    local ++fail
    display as error "FAIL: simple_unicode rc=" `outcome'
}
else {
    local ++pass
    display as result "PASS: simple_unicode"
}

**# compound_unicode
local ++tests
local root ""
capture noisily {
    * expect: EXACT
    qa_fx_a7_files, clear seed(37) perturb(path_hostile)
    local root `"`r(root)'"'
    local ledger `"`root'/ledger Å.dta"'
    python: from pathlib import Path; from sfi import Macro; _ld_before={str(p.relative_to(Path(Macro.getLocal("root")))):p.read_bytes() for p in Path(Macro.getLocal("root")).rglob("*") if p.is_file()}
    qa_fx_a7_labelled, clear seed(37)
    qa_state_snapshot, tag(ledger_quotes)
    quietly datacheck, gatesonly expectn(40) ledger(`"`macval(ledger)'"', run("qa same"))
    assert r(N)==40 & r(n_checks)==1 & r(n_passed)==1 & r(n_failed)==0 & r(ledger_seq)==1
    assert `"`r(ledger)'"'==`"`macval(ledger)'"'
    qa_state_compare, tag(ledger_quotes)
    qa_state_snapshot, tag(ledger_quotes)
    quietly datacheck, gatesonly expectn(40) ledger(`"`macval(ledger)'"', run("qa same"))
    assert r(N)==40 & r(n_checks)==1 & r(n_passed)==1 & r(n_failed)==0 & r(ledger_seq)==2
    assert `"`r(ledger)'"'==`"`macval(ledger)'"'
    qa_state_compare, tag(ledger_quotes)
    preserve
    quietly use `"`macval(ledger)'"', clear
    assert _N==2 & run=="qa same" & family=="expectn" & observed_num==40 & n_scope==40 & status=="pass"
    assert seq==_n
    restore
    python: _ld_after={str(p.relative_to(Path(Macro.getLocal("root")))):p.read_bytes() for p in Path(Macro.getLocal("root")).rglob("*") if p.is_file()}; _leaf=Path(Macro.getLocal("ledger")).name; assert set(_ld_after)-set(_ld_before)=={_leaf}; assert all(_ld_after[k]==v for k,v in _ld_before.items())
}
local outcome=_rc
capture log close ledgercause
capture restore
if `"`root'"'!="" capture noisily qa_fx_a7_cleanup, root(`"`macval(root)'"')
if `outcome' {
    local ++fail
    display as error "FAIL: compound_unicode rc=" `outcome'
}
else {
    local ++pass
    display as result "PASS: compound_unicode"
}

**# quote_directory
local ++tests
local root ""
capture noisily {
    * expect: REFUSED
    qa_fx_a7_files, clear seed(37) perturb(path_hostile)
    local root `"`r(root)'"'
    local ledger `"`root'/ledger spaces.dta"'
    python: from sfi import Macro; Macro.setLocal("ledger",Macro.getLocal("root")+'/spaces "quotes" Å/ledger.dta')
    python: from pathlib import Path; from sfi import Macro; _ld_before={str(p.relative_to(Path(Macro.getLocal("root")))):p.read_bytes() for p in Path(Macro.getLocal("root")).rglob("*") if p.is_file()}
    qa_fx_a7_labelled, clear seed(37)
    qa_state_snapshot, tag(ledger_quotes)
    tempfile cause
    log using "`cause'", name(ledgercause) text replace
    capture noisily datacheck, gatesonly expectn(40) ledger(`"`macval(ledger)'"', run("qa same"))
    local original_rc=_rc
    log close ledgercause
    assert `original_rc'==198
    qa_state_compare, tag(ledger_quotes)
    python: assert "illegal characters in ledger() path" in Path(Macro.getLocal("cause")).read_text(); assert _ld_before=={str(p.relative_to(Path(Macro.getLocal("root")))):p.read_bytes() for p in Path(Macro.getLocal("root")).rglob("*") if p.is_file()}
}
local outcome=_rc
capture log close ledgercause
capture restore
if `"`root'"'!="" capture noisily qa_fx_a7_cleanup, root(`"`macval(root)'"')
if `outcome' {
    local ++fail
    display as error "FAIL: quote_directory rc=" `outcome'
}
else {
    local ++pass
    display as result "PASS: quote_directory"
}

**# quote_leaf
local ++tests
local root ""
capture noisily {
    * expect: REFUSED
    qa_fx_a7_files, clear seed(37) perturb(path_hostile)
    local root `"`r(root)'"'
    local ledger `"`root'/ledger spaces.dta"'
    python: from sfi import Macro; Macro.setLocal("ledger",Macro.getLocal("root")+'/ledger "literal" Å.dta')
    python: from pathlib import Path; from sfi import Macro; _ld_before={str(p.relative_to(Path(Macro.getLocal("root")))):p.read_bytes() for p in Path(Macro.getLocal("root")).rglob("*") if p.is_file()}
    qa_fx_a7_labelled, clear seed(37)
    qa_state_snapshot, tag(ledger_quotes)
    tempfile cause
    log using "`cause'", name(ledgercause) text replace
    capture noisily datacheck, gatesonly expectn(40) ledger(`"`macval(ledger)'"', run("qa same"))
    local original_rc=_rc
    log close ledgercause
    assert `original_rc'==198
    qa_state_compare, tag(ledger_quotes)
    python: assert "illegal characters in ledger() path" in Path(Macro.getLocal("cause")).read_text(); assert _ld_before=={str(p.relative_to(Path(Macro.getLocal("root")))):p.read_bytes() for p in Path(Macro.getLocal("root")).rglob("*") if p.is_file()}
}
local outcome=_rc
capture log close ledgercause
capture restore
if `"`root'"'!="" capture noisily qa_fx_a7_cleanup, root(`"`macval(root)'"')
if `outcome' {
    local ++fail
    display as error "FAIL: quote_leaf rc=" `outcome'
}
else {
    local ++pass
    display as result "PASS: quote_leaf"
}

**# bad_suboption
local ++tests
local root ""
capture noisily {
    * expect: REFUSED
    qa_fx_a7_files, clear seed(37) perturb(path_hostile)
    local root `"`r(root)'"'
    local ledger `"`root'/ledger spaces.dta"'
    python: from pathlib import Path; from sfi import Macro; _ld_before={str(p.relative_to(Path(Macro.getLocal("root")))):p.read_bytes() for p in Path(Macro.getLocal("root")).rglob("*") if p.is_file()}
    qa_fx_a7_labelled, clear seed(37)
    qa_state_snapshot, tag(ledger_quotes)
    tempfile cause
    log using "`cause'", name(ledgercause) text replace
    capture noisily datacheck, gatesonly expectn(40) ledger(`"`macval(ledger)'"', not_an_option)
    local original_rc=_rc
    log close ledgercause
    assert `original_rc'==198
    qa_state_compare, tag(ledger_quotes)
    python: assert "the only suboption is run(string)" in Path(Macro.getLocal("cause")).read_text(); assert _ld_before=={str(p.relative_to(Path(Macro.getLocal("root")))):p.read_bytes() for p in Path(Macro.getLocal("root")).rglob("*") if p.is_file()}
}
local outcome=_rc
capture log close ledgercause
capture restore
if `"`root'"'!="" capture noisily qa_fx_a7_cleanup, root(`"`macval(root)'"')
if `outcome' {
    local ++fail
    display as error "FAIL: bad_suboption rc=" `outcome'
}
else {
    local ++pass
    display as result "PASS: bad_suboption"
}

display "RESULT: test_datacheck_fixture_ledger_quotes tests=`tests' pass=`pass' fail=`fail'"
log close
if `fail' exit 1
