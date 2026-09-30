*! validation_consort_fixture_primitives.do -- exact hostile counts and resolved literal labels
*! Author: Timothy P Copeland, Karolinska Institutet
version 16.0
clear all
set more off
java set heapmax 256m
capture log close _all
log using validation_consort_fixture_primitives.log,text replace
local pkg_dir=substr("`c(pwd)'",1,strlen("`c(pwd)'")-3)
adopath ++ "`pkg_dir'"
do _qa_fx_a7.do
do _qa_hostile.do
do _qa_state.do
local tests 0
local pass 0
local fail 0

**# 32-character last-byte distinct exclusion variables
local ++tests
local root ""
capture noisily {
    * expect: EXACT
    qa_fx_a7_files, clear seed(37)
    local root `"`r(root)'"'
    local track `"`macval(root)'/track.csv"'
    local csv `"`macval(root)'/resolved.csv"'
    local image `"`macval(root)'/diagram.svg"'
    qa_hostile_names, clear
    local twins `r(long)'
    local first: word 1 of `twins'
    local second: word 2 of `twins'
    local initial=20
    local final=5
    local caption "Hostile names"
    consort init, initial(`"`caption'"') file(`"`track'"')
    consort exclude if `first'>10, label("First ten")
    assert r(n_excluded)==10 & r(n_remaining)==10
    consort exclude if `second'<-5, label("Next five")
    assert r(n_excluded)==5 & r(n_remaining)==5
    consort save, output(`"`image'"') csv(`"`csv'"') final("Final literal")
    assert r(N_initial)==`initial' & r(N_final)==`final' & r(N_excluded)==(`initial'-`final')
    python: _rows=list(__import__("csv").DictReader(open(__import__("sfi").Macro.getLocal("csv"),encoding="utf-8"))); assert any(q.get("cohort_label")==__import__("sfi").Macro.getLocal("caption") and int(q.get("n_remaining","0"))==int(__import__("sfi").Macro.getLocal("initial")) for q in _rows); assert any(q.get("cohort_label")=="Final literal" and int(q.get("n_remaining","0"))==int(__import__("sfi").Macro.getLocal("final")) for q in _rows)
    python: _svg=__import__("pathlib").Path(__import__("sfi").Macro.getLocal("image")).read_text(); assert 'Final literal' in _svg and 'EXPANDED' not in _svg

}
local outcome=_rc
capture consort clear, quiet
if `"`root'"'!="" {
    capture noisily qa_fx_a7_cleanup, root(`"`macval(root)'"')
    if _rc & !`outcome' local outcome=_rc
}
if `outcome' {
    local ++fail
    display as error "FAIL: 32-character last-byte distinct exclusion variables; rc=" `outcome'
}
else {
    local ++pass
    display as result "PASS: 32-character last-byte distinct exclusion variables"
}

**# Negative and above-maxlong distinct exclusion codes
local ++tests
local root ""
capture noisily {
    * expect: EXACT
    qa_fx_a7_files, clear seed(37)
    local root `"`r(root)'"'
    local track `"`macval(root)'/track.csv"'
    local csv `"`macval(root)'/resolved.csv"'
    local image `"`macval(root)'/diagram.svg"'
    qa_hostile_codes, clear
    local initial=15
    local final=9
    local caption "Hostile codes"
    consort init, initial(`"`caption'"') file(`"`track'"')
    consort exclude if code==3000000000, label("Exact first big code")
    assert r(n_excluded)==3 & r(n_remaining)==12
    consort exclude if code==-7, label("Exact negative code")
    assert r(n_excluded)==3 & r(n_remaining)==9
    consort save, output(`"`image'"') csv(`"`csv'"') final("Final literal")
    assert r(N_initial)==`initial' & r(N_final)==`final' & r(N_excluded)==(`initial'-`final')
    python: _rows=list(__import__("csv").DictReader(open(__import__("sfi").Macro.getLocal("csv"),encoding="utf-8"))); assert any(q.get("cohort_label")==__import__("sfi").Macro.getLocal("caption") and int(q.get("n_remaining","0"))==int(__import__("sfi").Macro.getLocal("initial")) for q in _rows); assert any(q.get("cohort_label")=="Final literal" and int(q.get("n_remaining","0"))==int(__import__("sfi").Macro.getLocal("final")) for q in _rows)
    python: _svg=__import__("pathlib").Path(__import__("sfi").Macro.getLocal("image")).read_text(); assert 'Final literal' in _svg and 'EXPANDED' not in _svg

}
local outcome=_rc
capture consort clear, quiet
if `"`root'"'!="" {
    capture noisily qa_fx_a7_cleanup, root(`"`macval(root)'"')
    if _rc & !`outcome' local outcome=_rc
}
if `outcome' {
    local ++fail
    display as error "FAIL: Negative and above-maxlong distinct exclusion codes; rc=" `outcome'
}
else {
    local ++pass
    display as result "PASS: Negative and above-maxlong distinct exclusion codes"
}

**# All-missing predictor excludes no complete rows
local ++tests
local root ""
capture noisily {
    * expect: EXACT
    qa_fx_a7_files, clear seed(37)
    local root `"`r(root)'"'
    local track `"`macval(root)'/track.csv"'
    local csv `"`macval(root)'/resolved.csv"'
    local image `"`macval(root)'/diagram.svg"'
    qa_fx_a7_labelled, clear seed(37) perturb(miss_all_column)
    local initial=40
    local final=30
    local caption "Missing predictor"
    consort init, initial(`"`caption'"') file(`"`track'"')
    consort exclude if !missing(x), label("Complete predictor")
    assert r(n_excluded)==0 & r(n_remaining)==40
    consort exclude if group==5, label("Actual ten exclusions after zero-match control")
    assert r(n_excluded)==10 & r(n_remaining)==30
    consort save, output(`"`image'"') csv(`"`csv'"') final("Final literal")
    assert r(N_initial)==`initial' & r(N_final)==`final' & r(N_excluded)==(`initial'-`final')
    python: _rows=list(__import__("csv").DictReader(open(__import__("sfi").Macro.getLocal("csv"),encoding="utf-8"))); assert any(q.get("cohort_label")==__import__("sfi").Macro.getLocal("caption") and int(q.get("n_remaining","0"))==int(__import__("sfi").Macro.getLocal("initial")) for q in _rows); assert any(q.get("cohort_label")=="Final literal" and int(q.get("n_remaining","0"))==int(__import__("sfi").Macro.getLocal("final")) for q in _rows)
    python: _svg=__import__("pathlib").Path(__import__("sfi").Macro.getLocal("image")).read_text(); assert 'Final literal' in _svg and 'EXPANDED' not in _svg

}
local outcome=_rc
capture consort clear, quiet
if `"`root'"'!="" {
    capture noisily qa_fx_a7_cleanup, root(`"`macval(root)'"')
    if _rc & !`outcome' local outcome=_rc
}
if `outcome' {
    local ++fail
    display as error "FAIL: All-missing predictor excludes no complete rows; rc=" `outcome'
}
else {
    local ++pass
    display as result "PASS: All-missing predictor excludes no complete rows"
}

**# Opaque initial QA_HS_TICKPAIR
local ++tests
local root ""
capture noisily {
    * expect: EXACT
    qa_fx_a7_files, clear seed(37)
    local root `"`r(root)'"'
    local track `"`macval(root)'/track.csv"'
    local csv `"`macval(root)'/resolved.csv"'
    local image `"`macval(root)'/diagram.svg"'
    qa_fx_a7_labelled, clear seed(37)
    qa_hostile_strings
    mata: st_local("caption",st_global("QA_HS_TICKPAIR"))
    local initial=40
    local final=30
    consort init, initial(`"`macval(caption)'"') file(`"`track'"')
    assert r(N)==40
    consort exclude if group==5, label("Exact ten exclusions")
    assert r(n_excluded)==10 & r(n_remaining)==30
    consort save, output(`"`image'"') csv(`"`csv'"') final("Final literal")
    assert r(N_initial)==`initial' & r(N_final)==`final' & r(N_excluded)==(`initial'-`final')
    python: _rows=list(__import__("csv").DictReader(open(__import__("sfi").Macro.getLocal("csv"),encoding="utf-8"))); assert any(q.get("cohort_label")==__import__("sfi").Macro.getLocal("caption") and int(q.get("n_remaining","0"))==int(__import__("sfi").Macro.getLocal("initial")) for q in _rows); assert any(q.get("cohort_label")=="Final literal" and int(q.get("n_remaining","0"))==int(__import__("sfi").Macro.getLocal("final")) for q in _rows)
    python: _svg=__import__("pathlib").Path(__import__("sfi").Macro.getLocal("image")).read_text(); assert 'Final literal' in _svg and 'EXPANDED' not in _svg

}
local outcome=_rc
capture consort clear, quiet
if `"`root'"'!="" {
    capture noisily qa_fx_a7_cleanup, root(`"`macval(root)'"')
    if _rc & !`outcome' local outcome=_rc
}
if `outcome' {
    local ++fail
    display as error "FAIL: Opaque initial QA_HS_TICKPAIR; rc=" `outcome'
}
else {
    local ++pass
    display as result "PASS: Opaque initial QA_HS_TICKPAIR"
}

**# Opaque initial QA_HS_TICK
local ++tests
local root ""
capture noisily {
    * expect: EXACT
    qa_fx_a7_files, clear seed(37)
    local root `"`r(root)'"'
    local track `"`macval(root)'/track.csv"'
    local csv `"`macval(root)'/resolved.csv"'
    local image `"`macval(root)'/diagram.svg"'
    qa_fx_a7_labelled, clear seed(37)
    qa_hostile_strings
    mata: st_local("caption",st_global("QA_HS_TICK"))
    local initial=40
    local final=30
    consort init, initial(`"`macval(caption)'"') file(`"`track'"')
    assert r(N)==40
    consort exclude if group==5, label("Exact ten exclusions")
    assert r(n_excluded)==10 & r(n_remaining)==30
    consort save, output(`"`image'"') csv(`"`csv'"') final("Final literal")
    assert r(N_initial)==`initial' & r(N_final)==`final' & r(N_excluded)==(`initial'-`final')
    python: _rows=list(__import__("csv").DictReader(open(__import__("sfi").Macro.getLocal("csv"),encoding="utf-8"))); assert any(q.get("cohort_label")==__import__("sfi").Macro.getLocal("caption") and int(q.get("n_remaining","0"))==int(__import__("sfi").Macro.getLocal("initial")) for q in _rows); assert any(q.get("cohort_label")=="Final literal" and int(q.get("n_remaining","0"))==int(__import__("sfi").Macro.getLocal("final")) for q in _rows)
    python: _svg=__import__("pathlib").Path(__import__("sfi").Macro.getLocal("image")).read_text(); assert 'Final literal' in _svg and 'EXPANDED' not in _svg

}
local outcome=_rc
capture consort clear, quiet
if `"`root'"'!="" {
    capture noisily qa_fx_a7_cleanup, root(`"`macval(root)'"')
    if _rc & !`outcome' local outcome=_rc
}
if `outcome' {
    local ++fail
    display as error "FAIL: Opaque initial QA_HS_TICK; rc=" `outcome'
}
else {
    local ++pass
    display as result "PASS: Opaque initial QA_HS_TICK"
}

**# Opaque initial QA_HS_DOLLAR
local ++tests
local root ""
capture noisily {
    * expect: EXACT
    qa_fx_a7_files, clear seed(37)
    local root `"`r(root)'"'
    local track `"`macval(root)'/track.csv"'
    local csv `"`macval(root)'/resolved.csv"'
    local image `"`macval(root)'/diagram.svg"'
    qa_fx_a7_labelled, clear seed(37)
    qa_hostile_strings
    mata: st_local("caption",st_global("QA_HS_DOLLAR"))
    local initial=40
    local final=30
    consort init, initial(`"`macval(caption)'"') file(`"`track'"')
    assert r(N)==40
    consort exclude if group==5, label("Exact ten exclusions")
    assert r(n_excluded)==10 & r(n_remaining)==30
    consort save, output(`"`image'"') csv(`"`csv'"') final("Final literal")
    assert r(N_initial)==`initial' & r(N_final)==`final' & r(N_excluded)==(`initial'-`final')
    python: _rows=list(__import__("csv").DictReader(open(__import__("sfi").Macro.getLocal("csv"),encoding="utf-8"))); assert any(q.get("cohort_label")==__import__("sfi").Macro.getLocal("caption") and int(q.get("n_remaining","0"))==int(__import__("sfi").Macro.getLocal("initial")) for q in _rows); assert any(q.get("cohort_label")=="Final literal" and int(q.get("n_remaining","0"))==int(__import__("sfi").Macro.getLocal("final")) for q in _rows)
    python: _svg=__import__("pathlib").Path(__import__("sfi").Macro.getLocal("image")).read_text(); assert 'Final literal' in _svg and 'EXPANDED' not in _svg

}
local outcome=_rc
capture consort clear, quiet
if `"`root'"'!="" {
    capture noisily qa_fx_a7_cleanup, root(`"`macval(root)'"')
    if _rc & !`outcome' local outcome=_rc
}
if `outcome' {
    local ++fail
    display as error "FAIL: Opaque initial QA_HS_DOLLAR; rc=" `outcome'
}
else {
    local ++pass
    display as result "PASS: Opaque initial QA_HS_DOLLAR"
}

**# Opaque initial QA_HS_APOS
local ++tests
local root ""
capture noisily {
    * expect: EXACT
    qa_fx_a7_files, clear seed(37)
    local root `"`r(root)'"'
    local track `"`macval(root)'/track.csv"'
    local csv `"`macval(root)'/resolved.csv"'
    local image `"`macval(root)'/diagram.svg"'
    qa_fx_a7_labelled, clear seed(37)
    qa_hostile_strings
    mata: st_local("caption",st_global("QA_HS_APOS"))
    local initial=40
    local final=30
    consort init, initial(`"`macval(caption)'"') file(`"`track'"')
    assert r(N)==40
    consort exclude if group==5, label("Exact ten exclusions")
    assert r(n_excluded)==10 & r(n_remaining)==30
    consort save, output(`"`image'"') csv(`"`csv'"') final("Final literal")
    assert r(N_initial)==`initial' & r(N_final)==`final' & r(N_excluded)==(`initial'-`final')
    python: _rows=list(__import__("csv").DictReader(open(__import__("sfi").Macro.getLocal("csv"),encoding="utf-8"))); assert any(q.get("cohort_label")==__import__("sfi").Macro.getLocal("caption") and int(q.get("n_remaining","0"))==int(__import__("sfi").Macro.getLocal("initial")) for q in _rows); assert any(q.get("cohort_label")=="Final literal" and int(q.get("n_remaining","0"))==int(__import__("sfi").Macro.getLocal("final")) for q in _rows)
    python: _svg=__import__("pathlib").Path(__import__("sfi").Macro.getLocal("image")).read_text(); assert 'Final literal' in _svg and 'EXPANDED' not in _svg

}
local outcome=_rc
capture consort clear, quiet
if `"`root'"'!="" {
    capture noisily qa_fx_a7_cleanup, root(`"`macval(root)'"')
    if _rc & !`outcome' local outcome=_rc
}
if `outcome' {
    local ++fail
    display as error "FAIL: Opaque initial QA_HS_APOS; rc=" `outcome'
}
else {
    local ++pass
    display as result "PASS: Opaque initial QA_HS_APOS"
}

**# Opaque initial QA_HS_DQ
local ++tests
local root ""
capture noisily {
    * expect: EXACT
    qa_fx_a7_files, clear seed(37)
    local root `"`r(root)'"'
    local track `"`macval(root)'/track.csv"'
    local csv `"`macval(root)'/resolved.csv"'
    local image `"`macval(root)'/diagram.svg"'
    qa_fx_a7_labelled, clear seed(37)
    qa_hostile_strings
    mata: st_local("caption",st_global("QA_HS_DQ"))
    local initial=40
    local final=30
    consort init, initial(`"`macval(caption)'"') file(`"`track'"')
    assert r(N)==40
    consort exclude if group==5, label("Exact ten exclusions")
    assert r(n_excluded)==10 & r(n_remaining)==30
    consort save, output(`"`image'"') csv(`"`csv'"') final("Final literal")
    assert r(N_initial)==`initial' & r(N_final)==`final' & r(N_excluded)==(`initial'-`final')
    python: _rows=list(__import__("csv").DictReader(open(__import__("sfi").Macro.getLocal("csv"),encoding="utf-8"))); assert any(q.get("cohort_label")==__import__("sfi").Macro.getLocal("caption") and int(q.get("n_remaining","0"))==int(__import__("sfi").Macro.getLocal("initial")) for q in _rows); assert any(q.get("cohort_label")=="Final literal" and int(q.get("n_remaining","0"))==int(__import__("sfi").Macro.getLocal("final")) for q in _rows)
    python: _svg=__import__("pathlib").Path(__import__("sfi").Macro.getLocal("image")).read_text(); assert 'Final literal' in _svg and 'EXPANDED' not in _svg

}
local outcome=_rc
capture consort clear, quiet
if `"`root'"'!="" {
    capture noisily qa_fx_a7_cleanup, root(`"`macval(root)'"')
    if _rc & !`outcome' local outcome=_rc
}
if `outcome' {
    local ++fail
    display as error "FAIL: Opaque initial QA_HS_DQ; rc=" `outcome'
}
else {
    local ++pass
    display as result "PASS: Opaque initial QA_HS_DQ"
}

**# Opaque initial QA_HS_BSLASH
local ++tests
local root ""
capture noisily {
    * expect: EXACT
    qa_fx_a7_files, clear seed(37)
    local root `"`r(root)'"'
    local track `"`macval(root)'/track.csv"'
    local csv `"`macval(root)'/resolved.csv"'
    local image `"`macval(root)'/diagram.svg"'
    qa_fx_a7_labelled, clear seed(37)
    qa_hostile_strings
    mata: st_local("caption",st_global("QA_HS_BSLASH"))
    local initial=40
    local final=30
    consort init, initial(`"`macval(caption)'"') file(`"`track'"')
    assert r(N)==40
    consort exclude if group==5, label("Exact ten exclusions")
    assert r(n_excluded)==10 & r(n_remaining)==30
    consort save, output(`"`image'"') csv(`"`csv'"') final("Final literal")
    assert r(N_initial)==`initial' & r(N_final)==`final' & r(N_excluded)==(`initial'-`final')
    python: _rows=list(__import__("csv").DictReader(open(__import__("sfi").Macro.getLocal("csv"),encoding="utf-8"))); assert any(q.get("cohort_label")==__import__("sfi").Macro.getLocal("caption") and int(q.get("n_remaining","0"))==int(__import__("sfi").Macro.getLocal("initial")) for q in _rows); assert any(q.get("cohort_label")=="Final literal" and int(q.get("n_remaining","0"))==int(__import__("sfi").Macro.getLocal("final")) for q in _rows)
    python: _svg=__import__("pathlib").Path(__import__("sfi").Macro.getLocal("image")).read_text(); assert 'Final literal' in _svg and 'EXPANDED' not in _svg

}
local outcome=_rc
capture consort clear, quiet
if `"`root'"'!="" {
    capture noisily qa_fx_a7_cleanup, root(`"`macval(root)'"')
    if _rc & !`outcome' local outcome=_rc
}
if `outcome' {
    local ++fail
    display as error "FAIL: Opaque initial QA_HS_BSLASH; rc=" `outcome'
}
else {
    local ++pass
    display as result "PASS: Opaque initial QA_HS_BSLASH"
}

**# Opaque initial QA_HS_COMMA
local ++tests
local root ""
capture noisily {
    * expect: EXACT
    qa_fx_a7_files, clear seed(37)
    local root `"`r(root)'"'
    local track `"`macval(root)'/track.csv"'
    local csv `"`macval(root)'/resolved.csv"'
    local image `"`macval(root)'/diagram.svg"'
    qa_fx_a7_labelled, clear seed(37)
    qa_hostile_strings
    mata: st_local("caption",st_global("QA_HS_COMMA"))
    local initial=40
    local final=30
    consort init, initial(`"`macval(caption)'"') file(`"`track'"')
    assert r(N)==40
    consort exclude if group==5, label("Exact ten exclusions")
    assert r(n_excluded)==10 & r(n_remaining)==30
    consort save, output(`"`image'"') csv(`"`csv'"') final("Final literal")
    assert r(N_initial)==`initial' & r(N_final)==`final' & r(N_excluded)==(`initial'-`final')
    python: _rows=list(__import__("csv").DictReader(open(__import__("sfi").Macro.getLocal("csv"),encoding="utf-8"))); assert any(q.get("cohort_label")==__import__("sfi").Macro.getLocal("caption") and int(q.get("n_remaining","0"))==int(__import__("sfi").Macro.getLocal("initial")) for q in _rows); assert any(q.get("cohort_label")=="Final literal" and int(q.get("n_remaining","0"))==int(__import__("sfi").Macro.getLocal("final")) for q in _rows)
    python: _svg=__import__("pathlib").Path(__import__("sfi").Macro.getLocal("image")).read_text(); assert 'Final literal' in _svg and 'EXPANDED' not in _svg

}
local outcome=_rc
capture consort clear, quiet
if `"`root'"'!="" {
    capture noisily qa_fx_a7_cleanup, root(`"`macval(root)'"')
    if _rc & !`outcome' local outcome=_rc
}
if `outcome' {
    local ++fail
    display as error "FAIL: Opaque initial QA_HS_COMMA; rc=" `outcome'
}
else {
    local ++pass
    display as result "PASS: Opaque initial QA_HS_COMMA"
}

**# Opaque initial QA_HS_LEAD
local ++tests
local root ""
capture noisily {
    * expect: EXACT
    qa_fx_a7_files, clear seed(37)
    local root `"`r(root)'"'
    local track `"`macval(root)'/track.csv"'
    local csv `"`macval(root)'/resolved.csv"'
    local image `"`macval(root)'/diagram.svg"'
    qa_fx_a7_labelled, clear seed(37)
    qa_hostile_strings
    mata: st_local("caption",st_global("QA_HS_LEAD"))
    local initial=40
    local final=30
    consort init, initial(`"`macval(caption)'"') file(`"`track'"')
    assert r(N)==40
    consort exclude if group==5, label("Exact ten exclusions")
    assert r(n_excluded)==10 & r(n_remaining)==30
    consort save, output(`"`image'"') csv(`"`csv'"') final("Final literal")
    assert r(N_initial)==`initial' & r(N_final)==`final' & r(N_excluded)==(`initial'-`final')
    python: _rows=list(__import__("csv").DictReader(open(__import__("sfi").Macro.getLocal("csv"),encoding="utf-8"))); assert any(q.get("cohort_label")==__import__("sfi").Macro.getLocal("caption") and int(q.get("n_remaining","0"))==int(__import__("sfi").Macro.getLocal("initial")) for q in _rows); assert any(q.get("cohort_label")=="Final literal" and int(q.get("n_remaining","0"))==int(__import__("sfi").Macro.getLocal("final")) for q in _rows)
    python: _svg=__import__("pathlib").Path(__import__("sfi").Macro.getLocal("image")).read_text(); assert 'Final literal' in _svg and 'EXPANDED' not in _svg

}
local outcome=_rc
capture consort clear, quiet
if `"`root'"'!="" {
    capture noisily qa_fx_a7_cleanup, root(`"`macval(root)'"')
    if _rc & !`outcome' local outcome=_rc
}
if `outcome' {
    local ++fail
    display as error "FAIL: Opaque initial QA_HS_LEAD; rc=" `outcome'
}
else {
    local ++pass
    display as result "PASS: Opaque initial QA_HS_LEAD"
}

**# Opaque initial QA_HS_UNICODE
local ++tests
local root ""
capture noisily {
    * expect: EXACT
    qa_fx_a7_files, clear seed(37)
    local root `"`r(root)'"'
    local track `"`macval(root)'/track.csv"'
    local csv `"`macval(root)'/resolved.csv"'
    local image `"`macval(root)'/diagram.svg"'
    qa_fx_a7_labelled, clear seed(37)
    qa_hostile_strings
    mata: st_local("caption",st_global("QA_HS_UNICODE"))
    local initial=40
    local final=30
    consort init, initial(`"`macval(caption)'"') file(`"`track'"')
    assert r(N)==40
    consort exclude if group==5, label("Exact ten exclusions")
    assert r(n_excluded)==10 & r(n_remaining)==30
    consort save, output(`"`image'"') csv(`"`csv'"') final("Final literal")
    assert r(N_initial)==`initial' & r(N_final)==`final' & r(N_excluded)==(`initial'-`final')
    python: _rows=list(__import__("csv").DictReader(open(__import__("sfi").Macro.getLocal("csv"),encoding="utf-8"))); assert any(q.get("cohort_label")==__import__("sfi").Macro.getLocal("caption") and int(q.get("n_remaining","0"))==int(__import__("sfi").Macro.getLocal("initial")) for q in _rows); assert any(q.get("cohort_label")=="Final literal" and int(q.get("n_remaining","0"))==int(__import__("sfi").Macro.getLocal("final")) for q in _rows)
    python: _svg=__import__("pathlib").Path(__import__("sfi").Macro.getLocal("image")).read_text(); assert 'Final literal' in _svg and 'EXPANDED' not in _svg

}
local outcome=_rc
capture consort clear, quiet
if `"`root'"'!="" {
    capture noisily qa_fx_a7_cleanup, root(`"`macval(root)'"')
    if _rc & !`outcome' local outcome=_rc
}
if `outcome' {
    local ++fail
    display as error "FAIL: Opaque initial QA_HS_UNICODE; rc=" `outcome'
}
else {
    local ++pass
    display as result "PASS: Opaque initial QA_HS_UNICODE"
}

display "RESULT: validation_consort_fixture_primitives tests=`tests' pass=`pass' fail=`fail'"
log close
if `fail' exit 1
