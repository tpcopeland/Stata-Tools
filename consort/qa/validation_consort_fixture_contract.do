*! validation_consort_fixture_contract.do -- canonical labelled designs and independent contents
*! Author: Timothy P Copeland, Karolinska Institutet
version 16.0
clear all
set more off
capture log close _all
log using "validation_consort_fixture_contract.log", text replace
local pkg_dir=substr("`c(pwd)'",1,strlen("`c(pwd)'")-3)
adopath ++ "`pkg_dir'"
do _qa_fx_a7.do
do _qa_state.do
local tests 0
local pass 0
local fail 0
java set heapmax 256m

**# Population and resolved exports friendly
local ++tests
capture noisily {
    local root ""
    qa_fx_a7_files, clear seed(37)
    local root `"`r(root)'"'
    local track `"`macval(root)'/track.csv"'
    local csv `"`macval(root)'/resolved.csv"'
    local image `"`macval(root)'/diagram.svg"'
    qa_fx_a7_labelled, clear seed(37)
    consort init, initial("Eligible Å") file(`"`macval(track)'"')
    assert r(N)==40
    consort exclude if group==5, label("Excluded five") remaining("Remaining Å")
    assert r(n_excluded)==10 & r(n_remaining)==30 & _N==30
    consort save, output(`"`macval(image)'"') csv(`"`macval(csv)'"') final("Final Å")
    assert r(N_initial)==40 & r(N_final)==30 & r(N_excluded)==10
    python: _rows=list(__import__("csv").DictReader(open(__import__("sfi").Macro.getLocal("csv"),encoding="utf-8"))); print("CONSORT_RESOLVED",_rows); assert any(q.get("cohort_label")=="Eligible Å" and int(q.get("n_remaining","0"))==40 for q in _rows); assert any(q.get("cohort_label")=="Final Å" and int(q.get("n_remaining","0"))==30 for q in _rows)
    python: _svg=__import__("pathlib").Path(__import__("sfi").Macro.getLocal("image")).read_text(); assert "Eligible Å" in _svg and "Final Å" in _svg

}
local outcome=_rc
capture consort clear, quiet
if `"`macval(root)'"'!="" {
    capture noisily qa_fx_a7_cleanup, root(`"`macval(root)'"')
    if _rc & !`outcome' local outcome=_rc
}
if `outcome' {
    local ++fail
    display as error "FAIL: Population and resolved exports friendly; rc=" `outcome'
}
else {
    local ++pass
    display as result "PASS: Population and resolved exports friendly"
}

**# Population and resolved exports label_gaps
local ++tests
capture noisily {
    local root ""
    qa_fx_a7_files, clear seed(37)
    local root `"`r(root)'"'
    local track `"`macval(root)'/track.csv"'
    local csv `"`macval(root)'/resolved.csv"'
    local image `"`macval(root)'/diagram.svg"'
    * expect: EXACT
    qa_fx_a7_labelled, clear seed(37) perturb(label_gaps)
    consort init, initial("Eligible Å") file(`"`macval(track)'"')
    assert r(N)==40
    consort exclude if group==5, label("Excluded five") remaining("Remaining Å")
    assert r(n_excluded)==10 & r(n_remaining)==30 & _N==30
    consort save, output(`"`macval(image)'"') csv(`"`macval(csv)'"') final("Final Å")
    assert r(N_initial)==40 & r(N_final)==30 & r(N_excluded)==10
    python: _rows=list(__import__("csv").DictReader(open(__import__("sfi").Macro.getLocal("csv"),encoding="utf-8"))); print("CONSORT_RESOLVED",_rows); assert any(q.get("cohort_label")=="Eligible Å" and int(q.get("n_remaining","0"))==40 for q in _rows); assert any(q.get("cohort_label")=="Final Å" and int(q.get("n_remaining","0"))==30 for q in _rows)
    python: _svg=__import__("pathlib").Path(__import__("sfi").Macro.getLocal("image")).read_text(); assert "Eligible Å" in _svg and "Final Å" in _svg

}
local outcome=_rc
capture consort clear, quiet
if `"`macval(root)'"'!="" {
    capture noisily qa_fx_a7_cleanup, root(`"`macval(root)'"')
    if _rc & !`outcome' local outcome=_rc
}
if `outcome' {
    local ++fail
    display as error "FAIL: Population and resolved exports label_gaps; rc=" `outcome'
}
else {
    local ++pass
    display as result "PASS: Population and resolved exports label_gaps"
}

**# Population and resolved exports single_row
local ++tests
capture noisily {
    local root ""
    qa_fx_a7_files, clear seed(37)
    local root `"`r(root)'"'
    local track `"`macval(root)'/track.csv"'
    local csv `"`macval(root)'/resolved.csv"'
    local image `"`macval(root)'/diagram.svg"'
    * expect: EXACT
    qa_fx_a7_labelled, clear seed(37) perturb(single_row)
    consort init, initial("Eligible Å") file(`"`macval(track)'"')
    assert r(N)==1
    consort exclude if group==5, label("Excluded five") remaining("Remaining Å")
    assert r(n_excluded)==0 & r(n_remaining)==1 & _N==1
    * expect: REFUSED
    qa_state_snapshot, tag(con_single)
    capture noisily consort save, output(`"`macval(image)'"') csv(`"`macval(csv)'"') final("Final Å")
    assert _rc==198
    qa_state_compare, tag(con_single)
    python: assert list(__import__("csv").reader(open(__import__("sfi").Macro.getLocal("track"),encoding="utf-8")))==[["label","n","remaining"],["Eligible Å","1",""]]
    python: assert not __import__("pathlib").Path(__import__("sfi").Macro.getLocal("image")).exists() and not __import__("pathlib").Path(__import__("sfi").Macro.getLocal("csv")).exists()

}
local outcome=_rc
capture consort clear, quiet
if `"`macval(root)'"'!="" {
    capture noisily qa_fx_a7_cleanup, root(`"`macval(root)'"')
    if _rc & !`outcome' local outcome=_rc
}
if `outcome' {
    local ++fail
    display as error "FAIL: Population and resolved exports single_row; rc=" `outcome'
}
else {
    local ++pass
    display as result "PASS: Population and resolved exports single_row"
}

**# Population and resolved exports unsorted
local ++tests
capture noisily {
    local root ""
    qa_fx_a7_files, clear seed(37)
    local root `"`r(root)'"'
    local track `"`macval(root)'/track.csv"'
    local csv `"`macval(root)'/resolved.csv"'
    local image `"`macval(root)'/diagram.svg"'
    * expect: INVARIANT
    qa_fx_a7_labelled, clear seed(37) perturb(unsorted)
    consort init, initial("Eligible Å") file(`"`macval(track)'"')
    assert r(N)==40
    consort exclude if group==5, label("Excluded five") remaining("Remaining Å")
    assert r(n_excluded)==10 & r(n_remaining)==30 & _N==30
    consort save, output(`"`macval(image)'"') csv(`"`macval(csv)'"') final("Final Å")
    assert r(N_initial)==40 & r(N_final)==30 & r(N_excluded)==10
    python: _rows=list(__import__("csv").DictReader(open(__import__("sfi").Macro.getLocal("csv"),encoding="utf-8"))); print("CONSORT_RESOLVED",_rows); assert any(q.get("cohort_label")=="Eligible Å" and int(q.get("n_remaining","0"))==40 for q in _rows); assert any(q.get("cohort_label")=="Final Å" and int(q.get("n_remaining","0"))==30 for q in _rows)
    python: _svg=__import__("pathlib").Path(__import__("sfi").Macro.getLocal("image")).read_text(); assert "Eligible Å" in _svg and "Final Å" in _svg

}
local outcome=_rc
capture consort clear, quiet
if `"`macval(root)'"'!="" {
    capture noisily qa_fx_a7_cleanup, root(`"`macval(root)'"')
    if _rc & !`outcome' local outcome=_rc
}
if `outcome' {
    local ++fail
    display as error "FAIL: Population and resolved exports unsorted; rc=" `outcome'
}
else {
    local ++pass
    display as result "PASS: Population and resolved exports unsorted"
}

display "RESULT: validation_consort_fixture_contract tests=`tests' pass=`pass' fail=`fail'"
log close
if `fail' exit 1
