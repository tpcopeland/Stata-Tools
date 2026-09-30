*! test_diagtab_fixture_files.do -- actual export contents and owned hostile file trees
*! Author: Timothy P Copeland, Karolinska Institutet
version 16.0
clear all
set more off
java set heapmax 256m
capture log close _all
log using "test_diagtab_fixture_files.log", text replace
local pkg_dir=substr("`c(pwd)'",1,strlen("`c(pwd)'")-3)
adopath ++ "`pkg_dir'"
do _qa_fx_a7.do
do _qa_fx_a1.do
do _qa_state.do
local tests 0
local pass 0
local fail 0

**# Exact export friendly
local ++tests
local root ""
capture noisily {
    qa_fx_a7_files, clear seed(37) 
    local root `"`r(root)'"'
    local out `"`r(path_active)'"'
    qa_fx_a1_diag, clear tier(micro) seed(37)
    quietly diagtab score y, cutoff(3) xlsx(`"`macval(out)'"') sheet("package_summary") title("Fixture diagnostic")
    python: __import__("subprocess").run([__import__("sys").executable,"tools/check_xlsx.py",__import__("sfi").Macro.getLocal("out"),'--sheet','package_summary','--cell','A1','Fixture diagnostic','--cell','C3','21','--cell','D3','9','--cell','C4','4','--cell','D4','16','--cell','C7','84.0%'],check=True)
}
local outcome=_rc
if `"`macval(root)'"'!="" {
    capture noisily qa_fx_a7_cleanup, root(`"`macval(root)'"')
    if _rc & !`outcome' local outcome=_rc
}
if `outcome' {
    local ++fail
    display as error "FAIL: friendly; rc=" `outcome'
}
else {
    local ++pass
    display as result "PASS: friendly"
}

**# Refuse quoted hostile filename with the actual invalid-character cause
local ++tests
local root ""
capture noisily {
    * expect: REFUSED
    qa_fx_a7_files, clear seed(37) perturb(path_hostile)
    local root `"`r(root)'"'
    local out `"`r(path_active)'"'
    python: _diag_tree_before={str(p.relative_to(__import__("pathlib").Path(__import__("sfi").Macro.getLocal("root")))):p.read_bytes() for p in __import__("pathlib").Path(__import__("sfi").Macro.getLocal("root")).rglob("*") if p.is_file()}
    qa_fx_a1_diag, clear tier(micro) seed(37)
    qa_state_snapshot, tag(diag_hostile)
    tempfile cause
    log using `"`cause'"', text replace name(pathcause)
    capture noisily diagtab score y, cutoff(3) xlsx(`"`macval(out)'"') sheet("package_summary") title("Fixture diagnostic")
    local refusal=_rc
    log close pathcause
    assert `refusal'==198
    assert strpos(fileread(`"`cause'"'),"xlsx() contains invalid characters")>0
    qa_state_compare, tag(diag_hostile)
    python: assert _diag_tree_before=={str(p.relative_to(__import__("pathlib").Path(__import__("sfi").Macro.getLocal("root")))):p.read_bytes() for p in __import__("pathlib").Path(__import__("sfi").Macro.getLocal("root")).rglob("*") if p.is_file()}
}
local outcome=_rc
capture log close pathcause
if `"`macval(root)'"'!="" {
    capture noisily qa_fx_a7_cleanup, root(`"`macval(root)'"')
    if _rc & !`outcome' local outcome=_rc
}
if `outcome' {
    local ++fail
    display as error "FAIL: path_hostile; rc=" `outcome'
}
else {
    local ++pass
    display as result "PASS: path_hostile"
}

**# Refuse path_noext
local ++tests
local root ""
capture noisily {
    * expect: REFUSED
    qa_fx_a7_files, clear seed(37) perturb(path_noext)
    local root `"`r(root)'"'
    local out `"`r(path_active)'"'
    qa_fx_a1_diag, clear tier(micro) seed(37)
    qa_state_snapshot, tag(diag_noext)
    capture noisily diagtab score y, cutoff(3) xlsx(`"`macval(out)'"') sheet("package_summary") title("Fixture diagnostic")
    local refusal=_rc
    assert `refusal'==198
    qa_state_compare, tag(diag_noext)
    python: assert __import__("pathlib").Path(__import__("sfi").Macro.getLocal("out")).read_text()=="EXTENSIONLESS_KEEP\n"
}
local outcome=_rc
if `"`macval(root)'"'!="" {
    capture noisily qa_fx_a7_cleanup, root(`"`macval(root)'"')
    if _rc & !`outcome' local outcome=_rc
}
if `outcome' {
    local ++fail
    display as error "FAIL: path_noext; rc=" `outcome'
}
else {
    local ++pass
    display as result "PASS: path_noext"
}

**# Exact export stale_sheet
local ++tests
local root ""
capture noisily {
    * expect: EXACT
    qa_fx_a7_files, clear seed(37) perturb(stale_sheet)
    local root `"`r(root)'"'
    local out `"`r(path_xlsx)'"'
    qa_fx_a1_diag, clear tier(micro) seed(37)
    quietly diagtab score y, cutoff(3) xlsx(`"`macval(out)'"') sheet("package_summary") title("Fixture diagnostic")
    python: __import__("subprocess").run([__import__("sys").executable,"tools/check_xlsx.py",__import__("sfi").Macro.getLocal("out"),'--sheet','package_summary','--cell','A1','Fixture diagnostic','--cell','C3','21','--cell','D3','9','--cell','C4','4','--cell','D4','16','--cell','C7','84.0%'],check=True)
    python: __import__("subprocess").run([__import__("sys").executable,"tools/check_xlsx.py",__import__("sfi").Macro.getLocal("out"),"--sheet","user_notes","--cell","A1","USER_KEEP"],check=True)
    python: __import__("subprocess").run([__import__("sys").executable,"tools/check_xlsx.py",__import__("sfi").Macro.getLocal("out"),"--sheet","package_detail","--cell","A1","STALE_DETAIL"],check=True)
}
local outcome=_rc
if `"`macval(root)'"'!="" {
    capture noisily qa_fx_a7_cleanup, root(`"`macval(root)'"')
    if _rc & !`outcome' local outcome=_rc
}
if `outcome' {
    local ++fail
    display as error "FAIL: stale_sheet; rc=" `outcome'
}
else {
    local ++pass
    display as result "PASS: stale_sheet"
}

**# Exact Unicode and spaces-only accepted filename
local ++tests
local root ""
capture noisily {
    qa_fx_a7_files, clear seed(37) 
    local root `"`r(root)'"'
    local original `"`r(path_xlsx)'"'
    local out `"`macval(root)'/spaces Å.xlsx"'
    python: __import__("shutil").copyfile(__import__("sfi").Macro.getLocal("original"),__import__("sfi").Macro.getLocal("out"))
    local csv `"`macval(root)'/spaces Å.csv"'
    local md `"`macval(root)'/spaces Å.md"'
    qa_fx_a1_diag, clear tier(micro) seed(37)
    quietly diagtab score y, cutoff(3) excel(`"`macval(out)'"') csv(`"`macval(csv)'"') markdown(`"`macval(md)'"') sheet("package_summary") title("Fixture diagnostic")
    python: __import__("subprocess").run([__import__("sys").executable,"tools/check_xlsx.py",__import__("sfi").Macro.getLocal("out"),'--sheet','package_summary','--cell','A1','Fixture diagnostic','--cell','C3','21','--cell','D3','9','--cell','C4','4','--cell','D4','16','--cell','C7','84.0%'],check=True)
    python: __import__("subprocess").run([__import__("sys").executable,"tools/check_xlsx.py",__import__("sfi").Macro.getLocal("out"),"--sheet","user_notes","--cell","A1","USER_KEEP"],check=True)
    python: assert __import__("openpyxl").load_workbook(__import__("sfi").Macro.getLocal("original")).sheetnames==["user_notes"]

    python: _rows=list(__import__("csv").reader(open(__import__("sfi").Macro.getLocal("csv"),encoding="utf-8"))); print("DIAG_CSV_ROWS",_rows); assert _rows[0][0]=="Fixture diagnostic"; assert _rows[2][1:3]==["21","9"]; assert _rows[3][1:3]==["4","16"]
    python: _md=__import__("pathlib").Path(__import__("sfi").Macro.getLocal("md")).read_text(); print("DIAG_MD",_md); assert "Fixture diagnostic" in _md and "| 21 | 9 |" in _md and "| 4 | 16 |" in _md

}
local outcome=_rc
if `"`macval(root)'"'!="" {
    capture noisily qa_fx_a7_cleanup, root(`"`macval(root)'"')
    if _rc & !`outcome' local outcome=_rc
}
if `outcome' {
    local ++fail
    display as error "FAIL: unicode spaces; rc=" `outcome'
}
else {
    local ++pass
    display as result "PASS: unicode spaces"
}


display "RESULT: test_diagtab_fixture_files tests=`tests' pass=`pass' fail=`fail'"
log close
if `fail' exit 1
