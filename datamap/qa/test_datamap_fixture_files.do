*! test_datamap_fixture_files.do -- actual output bytes and owned-tree mutation policy
*! Author: Timothy P Copeland, Karolinska Institutet
version 16.0
clear all
set more off
capture log close _all
log using test_datamap_fixture_files.log, text replace
local pkg_dir=substr("`c(pwd)'",1,strlen("`c(pwd)'")-3)
adopath ++ "`pkg_dir'"
do _qa_fx_a7.do
do _qa_state.do
local tests 0
local pass 0
local fail 0

**# datamap path_hostile
local ++tests
local root ""
capture noisily {
    * expect: REFUSED
    qa_fx_a7_files, clear seed(37) perturb(path_hostile)
    local root `"`r(root)'"'
    local output `"`r(path_active)'"'
    local data_path `"`r(path_dta)'"'
    python: _dm_tree_before={str(p.relative_to(__import__("pathlib").Path(__import__("sfi").Macro.getLocal("root")))):p.read_bytes() for p in __import__("pathlib").Path(__import__("sfi").Macro.getLocal("root")).rglob("*") if p.is_file()}
    qa_fx_a7_labelled, clear seed(37)
    qa_state_snapshot, tag(dm_files)
    capture noisily datamap, output(`"`macval(output)'"') format(json)
    local original_rc=_rc
    assert `original_rc'==198
    qa_state_compare, tag(dm_files)
    python: from pathlib import Path; from sfi import Macro; _dm_tree_after={str(p.relative_to(Path(Macro.getLocal("root")))):p.read_bytes() for p in Path(Macro.getLocal("root")).rglob("*") if p.is_file()}; assert _dm_tree_before==_dm_tree_after
}
local outcome=_rc
capture restore
if `"`root'"'!="" capture noisily qa_fx_a7_cleanup, root(`"`macval(root)'"')
if `outcome' {
    local ++fail
    display as error "FAIL: datamap path_hostile rc=" `outcome'
}
else {
    local ++pass
    display as result "PASS: datamap path_hostile"
}

**# datamap path_noext
local ++tests
local root ""
capture noisily {
    * expect: EXACT
    qa_fx_a7_files, clear seed(37) perturb(path_noext)
    local root `"`r(root)'"'
    local output `"`r(path_active)'"'
    local data_path `"`r(path_dta)'"'
    python: _dm_tree_before={str(p.relative_to(__import__("pathlib").Path(__import__("sfi").Macro.getLocal("root")))):p.read_bytes() for p in __import__("pathlib").Path(__import__("sfi").Macro.getLocal("root")).rglob("*") if p.is_file()}
    qa_fx_a7_labelled, clear seed(37)
    qa_state_snapshot, tag(dm_files)
    quietly datamap, output(`"`macval(output)'"') format(json)
    assert r(nobs)==40 & r(nvars)==10 & r(nfiles)==1
    qa_state_compare, tag(dm_files)
    python: from pathlib import Path; from sfi import Macro; _dm_tree_after={str(p.relative_to(Path(Macro.getLocal("root")))):p.read_bytes() for p in Path(Macro.getLocal("root")).rglob("*") if p.is_file()}; import json; _j=json.loads(Path(Macro.getLocal("output")).read_text())["datasets"][0]; _v={v["name"]:v for v in _j["variable_metadata"]}; assert _j["observations"]==40 and _j["variables"]==10 and _v["x"]["missing_n"]==0 and _v["all_missing"]["missing_n"]==40; assert set(_dm_tree_before)==set(_dm_tree_after); assert [k for k in _dm_tree_before if _dm_tree_before[k]!=_dm_tree_after[k]]==["name"]
}
local outcome=_rc
capture restore
if `"`root'"'!="" capture noisily qa_fx_a7_cleanup, root(`"`macval(root)'"')
if `outcome' {
    local ++fail
    display as error "FAIL: datamap path_noext rc=" `outcome'
}
else {
    local ++pass
    display as result "PASS: datamap path_noext"
}

**# datadict path_hostile
local ++tests
local root ""
capture noisily {
    * expect: REFUSED
    qa_fx_a7_files, clear seed(37) perturb(path_hostile)
    local root `"`r(root)'"'
    local output `"`r(path_active)'"'
    local data_path `"`r(path_dta)'"'
    python: _dm_tree_before={str(p.relative_to(__import__("pathlib").Path(__import__("sfi").Macro.getLocal("root")))):p.read_bytes() for p in __import__("pathlib").Path(__import__("sfi").Macro.getLocal("root")).rglob("*") if p.is_file()}
    qa_fx_a7_labelled, clear seed(37)
    qa_state_snapshot, tag(dm_files)
    capture noisily datadict, output(`"`macval(output)'"') stats continuous(x)
    local original_rc=_rc
    assert `original_rc'==198
    qa_state_compare, tag(dm_files)
    python: from pathlib import Path; from sfi import Macro; _dm_tree_after={str(p.relative_to(Path(Macro.getLocal("root")))):p.read_bytes() for p in Path(Macro.getLocal("root")).rglob("*") if p.is_file()}; assert _dm_tree_before==_dm_tree_after
}
local outcome=_rc
capture restore
if `"`root'"'!="" capture noisily qa_fx_a7_cleanup, root(`"`macval(root)'"')
if `outcome' {
    local ++fail
    display as error "FAIL: datadict path_hostile rc=" `outcome'
}
else {
    local ++pass
    display as result "PASS: datadict path_hostile"
}

**# datadict path_noext
local ++tests
local root ""
capture noisily {
    * expect: EXACT
    qa_fx_a7_files, clear seed(37) perturb(path_noext)
    local root `"`r(root)'"'
    local output `"`r(path_active)'"'
    local data_path `"`r(path_dta)'"'
    python: _dm_tree_before={str(p.relative_to(__import__("pathlib").Path(__import__("sfi").Macro.getLocal("root")))):p.read_bytes() for p in __import__("pathlib").Path(__import__("sfi").Macro.getLocal("root")).rglob("*") if p.is_file()}
    qa_fx_a7_labelled, clear seed(37)
    qa_state_snapshot, tag(dm_files)
    quietly datadict, output(`"`macval(output)'"') stats continuous(x)
    assert r(nobs_total)==40 & r(nvars_total)==10 & r(nfiles)==1
    assert `"`r(output)'"'==`"`macval(output)'"'
    qa_state_compare, tag(dm_files)
    python: from pathlib import Path; from sfi import Macro; _dm_tree_after={str(p.relative_to(Path(Macro.getLocal("root")))):p.read_bytes() for p in Path(Macro.getLocal("root")).rglob("*") if p.is_file()}; _txt=Path(Macro.getLocal("output")).read_text(); assert "Mean=20.50 (SD=11.69)" in _txt and "| `all_missing` |  | Numeric | All missing |" in _txt; assert set(_dm_tree_before)==set(_dm_tree_after); assert [k for k in _dm_tree_before if _dm_tree_before[k]!=_dm_tree_after[k]]==["name"]
}
local outcome=_rc
capture restore
if `"`root'"'!="" capture noisily qa_fx_a7_cleanup, root(`"`macval(root)'"')
if `outcome' {
    local ++fail
    display as error "FAIL: datadict path_noext rc=" `outcome'
}
else {
    local ++pass
    display as result "PASS: datadict path_noext"
}

**# datacheck path_hostile
local ++tests
local root ""
capture noisily {
    * expect: REFUSED
    qa_fx_a7_files, clear seed(37) perturb(path_hostile)
    local root `"`r(root)'"'
    local output `"`r(path_active)'"'
    local data_path `"`r(path_dta)'"'
    python: _dm_tree_before={str(p.relative_to(__import__("pathlib").Path(__import__("sfi").Macro.getLocal("root")))):p.read_bytes() for p in __import__("pathlib").Path(__import__("sfi").Macro.getLocal("root")).rglob("*") if p.is_file()}
    qa_fx_a7_labelled, clear seed(37)
    qa_state_snapshot, tag(dm_files)
    capture noisily datacheck, gatesonly expectn(40) ledger(`"`macval(output)'"')
    local original_rc=_rc
    assert `original_rc'==198
    qa_state_compare, tag(dm_files)
    python: from pathlib import Path; from sfi import Macro; _dm_tree_after={str(p.relative_to(Path(Macro.getLocal("root")))):p.read_bytes() for p in Path(Macro.getLocal("root")).rglob("*") if p.is_file()}; assert _dm_tree_before==_dm_tree_after
}
local outcome=_rc
capture restore
if `"`root'"'!="" capture noisily qa_fx_a7_cleanup, root(`"`macval(root)'"')
if `outcome' {
    local ++fail
    display as error "FAIL: datacheck path_hostile rc=" `outcome'
}
else {
    local ++pass
    display as result "PASS: datacheck path_hostile"
}

**# datacheck path_noext
local ++tests
local root ""
capture noisily {
    * expect: REFUSED
    qa_fx_a7_files, clear seed(37) perturb(path_noext)
    local root `"`r(root)'"'
    local output `"`r(path_active)'"'
    local data_path `"`r(path_dta)'"'
    python: _dm_tree_before={str(p.relative_to(__import__("pathlib").Path(__import__("sfi").Macro.getLocal("root")))):p.read_bytes() for p in __import__("pathlib").Path(__import__("sfi").Macro.getLocal("root")).rglob("*") if p.is_file()}
    qa_fx_a7_labelled, clear seed(37)
    qa_state_snapshot, tag(dm_files)
    capture noisily datacheck, gatesonly expectn(40) ledger(`"`macval(output)'"')
    local original_rc=_rc
    assert `original_rc'==610
    qa_state_compare, tag(dm_files)
    python: from pathlib import Path; from sfi import Macro; _dm_tree_after={str(p.relative_to(Path(Macro.getLocal("root")))):p.read_bytes() for p in Path(Macro.getLocal("root")).rglob("*") if p.is_file()}; assert _dm_tree_before==_dm_tree_after
}
local outcome=_rc
capture restore
if `"`root'"'!="" capture noisily qa_fx_a7_cleanup, root(`"`macval(root)'"')
if `outcome' {
    local ++fail
    display as error "FAIL: datacheck path_noext rc=" `outcome'
}
else {
    local ++pass
    display as result "PASS: datacheck path_noext"
}

**# datamvp path_hostile
local ++tests
local root ""
capture noisily {
    * expect: REFUSED
    qa_fx_a7_files, clear seed(37) perturb(path_hostile)
    local root `"`r(root)'"'
    local output `"`r(path_active)'"'
    local data_path `"`r(path_dta)'"'
    python: _dm_tree_before={str(p.relative_to(__import__("pathlib").Path(__import__("sfi").Macro.getLocal("root")))):p.read_bytes() for p in __import__("pathlib").Path(__import__("sfi").Macro.getLocal("root")).rglob("*") if p.is_file()}
    qa_fx_a7_labelled, clear seed(37)
    qa_state_snapshot, tag(dm_files)
    capture noisily datamvp x all_missing extended, nodrop save(`"`macval(output)'"')
    local original_rc=_rc
    assert `original_rc'==198
    qa_state_compare, tag(dm_files)
    python: from pathlib import Path; from sfi import Macro; _dm_tree_after={str(p.relative_to(Path(Macro.getLocal("root")))):p.read_bytes() for p in Path(Macro.getLocal("root")).rglob("*") if p.is_file()}; assert _dm_tree_before==_dm_tree_after
}
local outcome=_rc
capture restore
if `"`root'"'!="" capture noisily qa_fx_a7_cleanup, root(`"`macval(root)'"')
if `outcome' {
    local ++fail
    display as error "FAIL: datamvp path_hostile rc=" `outcome'
}
else {
    local ++pass
    display as result "PASS: datamvp path_hostile"
}

**# datamvp path_noext
local ++tests
local root ""
capture noisily {
    * expect: EXACT
    qa_fx_a7_files, clear seed(37) perturb(path_noext)
    local root `"`r(root)'"'
    local output `"`r(path_active)'"'
    local data_path `"`r(path_dta)'"'
    python: _dm_tree_before={str(p.relative_to(__import__("pathlib").Path(__import__("sfi").Macro.getLocal("root")))):p.read_bytes() for p in __import__("pathlib").Path(__import__("sfi").Macro.getLocal("root")).rglob("*") if p.is_file()}
    qa_fx_a7_labelled, clear seed(37)
    qa_state_snapshot, tag(dm_files)
    quietly datamvp x all_missing extended, nodrop save(`"`macval(output)'"')
    assert r(N)==40 & r(N_patterns)==1 & r(N_mv_total)==80
    preserve
    quietly use `"`data_path'"', clear
    assert _N==1 & pattern=="+.." & nmiss==2 & freq==40 & percent==100 & cumpct==100
    restore
    qa_state_compare, tag(dm_files)
    python: from pathlib import Path; from sfi import Macro; _dm_tree_after={str(p.relative_to(Path(Macro.getLocal("root")))):p.read_bytes() for p in Path(Macro.getLocal("root")).rglob("*") if p.is_file()}; assert set(_dm_tree_before)==set(_dm_tree_after); assert [k for k in _dm_tree_before if _dm_tree_before[k]!=_dm_tree_after[k]]==["name.dta"]
}
local outcome=_rc
capture restore
if `"`root'"'!="" capture noisily qa_fx_a7_cleanup, root(`"`macval(root)'"')
if `outcome' {
    local ++fail
    display as error "FAIL: datamvp path_noext rc=" `outcome'
}
else {
    local ++pass
    display as result "PASS: datamvp path_noext"
}

display "RESULT: test_datamap_fixture_files tests=`tests' pass=`pass' fail=`fail'"
log close
if `fail' exit 1
