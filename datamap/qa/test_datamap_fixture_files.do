*! test_datamap_fixture_files.do -- actual output bytes and owned-tree mutation policy
*! Author: Timothy P Copeland, Karolinska Institutet
* 2026-11-10 (datamap 2.0.0): format(json) and datadict are removed.  The
* datamap path tests run on the Markdown writer (the hostile path still stops
* with 198 and leaves the tree byte-identical; the no-extension path still
* writes exactly one new file, "name"); the datadict twins are ported to the
* same writer with a continuous(x) call and r(output) asserted, and read the
* document through _qa_md.do instead of a Python substring.
version 16.0
clear all
set more off
capture log close _all
log using test_datamap_fixture_files.log, text replace
local pkg_dir=substr("`c(pwd)'",1,strlen("`c(pwd)'")-3)
capture ado uninstall datamap
quietly net install datamap, from("`pkg_dir'") force
discard
do _qa_fx_a7.do
do _qa_md.do
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
    capture noisily datamap, output(`"`macval(output)'"')
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
    quietly datamap, output(`"`macval(output)'"')
    assert r(nobs)==40 & r(nvars)==10 & r(nfiles)==1
    qa_state_compare, tag(dm_files)
    python: from pathlib import Path; from sfi import Macro; _dm_tree_after={str(p.relative_to(Path(Macro.getLocal("root")))):p.read_bytes() for p in Path(Macro.getLocal("root")).rglob("*") if p.is_file()}; assert set(_dm_tree_before)==set(_dm_tree_after); assert [k for k in _dm_tree_before if _dm_tree_before[k]!=_dm_tree_after[k]]==["name"]
    qa_md_contains using `"`macval(output)'"', needle("- Observations: 40") exact
    assert r(n)==1
    qa_md_rows using `"`macval(output)'"'
    assert r(n)==10
    qa_md_rows using `"`macval(output)'"', var(x) miss("0 (0.0%)")
    assert r(n)==1
    qa_md_rows using `"`macval(output)'"', var(all_missing) cell("All missing") miss("40 (100.0%)")
    assert r(n)==1
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

**# datamap Markdown path_hostile
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
    capture noisily datamap, output(`"`macval(output)'"') continuous(x)
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
    display as error "FAIL: datamap Markdown path_hostile rc=" `outcome'
}
else {
    local ++pass
    display as result "PASS: datamap Markdown path_hostile"
}

**# datamap Markdown path_noext
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
    quietly datamap, output(`"`macval(output)'"') continuous(x)
    assert r(nobs)==40 & r(nvars)==10 & r(nfiles)==1
    assert `"`r(output)'"'==`"`macval(output)'"'
    qa_state_compare, tag(dm_files)
    python: from pathlib import Path; from sfi import Macro; _dm_tree_after={str(p.relative_to(Path(Macro.getLocal("root")))):p.read_bytes() for p in Path(Macro.getLocal("root")).rglob("*") if p.is_file()}; assert set(_dm_tree_before)==set(_dm_tree_after); assert [k for k in _dm_tree_before if _dm_tree_before[k]!=_dm_tree_after[k]]==["name"]
    qa_md_contains using `"`macval(output)'"', needle("mean=20.50; SD=11.69;")
    assert !missing(r(n))
    assert r(n)>=1
    qa_md_rows using `"`macval(output)'"', var(all_missing) cell("All missing") miss("40 (100.0%)")
    assert r(n)==1
}
local outcome=_rc
capture restore
if `"`root'"'!="" capture noisily qa_fx_a7_cleanup, root(`"`macval(root)'"')
if `outcome' {
    local ++fail
    display as error "FAIL: datamap Markdown path_noext rc=" `outcome'
}
else {
    local ++pass
    display as result "PASS: datamap Markdown path_noext"
}

**# dataprobe path_hostile
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
    capture noisily dataprobe, gatesonly expectn(40) ledger(`"`macval(output)'"')
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
    display as error "FAIL: dataprobe path_hostile rc=" `outcome'
}
else {
    local ++pass
    display as result "PASS: dataprobe path_hostile"
}

**# dataprobe path_noext
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
    capture noisily dataprobe, gatesonly expectn(40) ledger(`"`macval(output)'"')
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
    display as error "FAIL: dataprobe path_noext rc=" `outcome'
}
else {
    local ++pass
    display as result "PASS: dataprobe path_noext"
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
