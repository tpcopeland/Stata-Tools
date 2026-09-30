*! validation_fixture_truth.do -- canonical known-answer functional/hostile adoption
* Timothy P Copeland, Karolinska Institutet
version 16.0
clear all
set processors 1
set varabbrev off
set more off
set graphics off
capture log close _all
log using "validation_fixture_truth.log", text replace
local pkgdir=regexr("`c(pwd)'","/qa$","")
adopath ++ "`pkgdir'"
quietly do "_qa_fx_a7.do"
quietly do "_qa_hostile.do"
local tests=0
local pass=0
local fail=0
local ++tests
capture noisily {
    local op ""
    * Friendly known-answer control
    qa_fx_a7_labelled, clear tier(micro)
    quietly fvgen i.group##c.x, prefix(fx_)
    local vars "`r(genvars)'"
    assert r(k_main)==4 & r(k_int)==3 & r(k_all)==7
    local n=0
    foreach v of local vars {
        local term: char `v'[fvgen_term]
        local role: char `v'[fvgen_role]
        assert regexm("`term'","^([0-9]+)[bn]*[.]group")
        local code=real(regexs(1))
        if "`role'"=="main" assert `v'==(group==`code')
        else if "`role'"=="interaction" assert `v'==(group==`code')*x
        else assert 0
        local ++n
    }
    assert `n'==6
    quietly fvgen, drop
    assert r(k_dropped)==6
    foreach v of local vars {
        capture confirm variable `v'
        assert _rc==111
    }
    assert _N==40 & x==id & inlist(group,1,2,5,9)
}
if _rc local ++fail
else local ++pass
local ++tests
capture noisily {
    local op "unsorted"
    * expect: EXACT
    qa_fx_a7_labelled, clear tier(micro) perturb(unsorted)
    assert !missing(r(perturb_n_unsorted)) & r(perturb_n_unsorted)>0
    quietly fvgen i.group##c.x, prefix(fx_)
    local vars "`r(genvars)'"
    assert r(k_main)==4 & r(k_int)==3 & r(k_all)==7
    local n=0
    foreach v of local vars {
        local term: char `v'[fvgen_term]
        local role: char `v'[fvgen_role]
        assert regexm("`term'","^([0-9]+)[bn]*[.]group")
        local code=real(regexs(1))
        if "`role'"=="main" assert `v'==(group==`code')
        else if "`role'"=="interaction" assert `v'==(group==`code')*x
        else assert 0
        local ++n
    }
    assert `n'==6
    quietly fvgen, drop
    assert r(k_dropped)==6
    foreach v of local vars {
        capture confirm variable `v'
        assert _rc==111
    }
    assert _N==40 & x==id & inlist(group,1,2,5,9)
}
if _rc local ++fail
else local ++pass
local ++tests
capture noisily {
    local op "label_gaps"
    * expect: EXACT
    qa_fx_a7_labelled, clear tier(micro) perturb(label_gaps)
    assert !missing(r(perturb_n_label_gaps)) & r(perturb_n_label_gaps)>0
    quietly fvgen i.group##c.x, prefix(fx_)
    local vars "`r(genvars)'"
    assert r(k_main)==4 & r(k_int)==3 & r(k_all)==7
    local n=0
    foreach v of local vars {
        local term: char `v'[fvgen_term]
        local role: char `v'[fvgen_role]
        assert regexm("`term'","^([0-9]+)[bn]*[.]group")
        local code=real(regexs(1))
        if "`role'"=="main" assert `v'==(group==`code')
        else if "`role'"=="interaction" assert `v'==(group==`code')*x
        else assert 0
        local ++n
    }
    assert `n'==6
    quietly fvgen, drop
    assert r(k_dropped)==6
    foreach v of local vars {
        capture confirm variable `v'
        assert _rc==111
    }
    assert _N==40 & x==id & inlist(group,1,2,5,9)
}
if _rc local ++fail
else local ++pass
display "RESULT: validation_fixture_truth tests=`tests' pass=`pass' fail=`fail' skip=0"
log close
if `fail' exit 9
