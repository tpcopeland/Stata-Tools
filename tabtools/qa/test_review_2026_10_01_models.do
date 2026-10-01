*! test_review_2026_10_01_models 2026/10/01
*! Author: Timothy P Copeland, Karolinska Institutet
version 17
clear all
set more off
set processors 1
capture log close _all
log using "test_review_2026_10_01_models.log",replace text name(_models_qa)
local pkg_dir = subinstr("`c(pwd)'", "/qa", "", .)
adopath ++ "`pkg_dir'"
do "_qa_state.do"
local pass_count 0
local fail_count 0
local test_count 0

local ++test_count
capture noisily {
clear
matrix M=(1,.5,1.5,.04)
effecttab, from(M) frame(F) eplotframe(f)
frame f: assert estimate==1
frame F: assert c1[4]=="1.00"
frame drop F f
}
if _rc {
 local ++fail_count
 display as error "FAIL: case_sensitive_effect_frames rc=" _rc
}
else {
 local ++pass_count
 display as result "PASS: case_sensitive_effect_frames"
}

local ++test_count
capture noisily {
sysuse auto,clear
collect clear
collect: regress price mpg
matrix before=e(b)
regtab, frame(R) eplotframe(r)
frame r: assert !missing(estimate)
assert !missing(mreldif(before,e(b)))
assert mreldif(before,e(b))==0
frame drop R r
}
if _rc {
 local ++fail_count
 display as error "FAIL: case_sensitive_reg_frames rc=" _rc
}
else {
 local ++pass_count
 display as result "PASS: case_sensitive_reg_frames"
}

local ++test_count
capture noisily {
sysuse auto,clear
collect clear
label variable mpg ""
label variable weight ""
label variable length ""
collect: sureg (price mpg weight) (turn mpg length)
matrix B=e(b)
regtab, eplotframe(surep) frame(sur) keepintercept
matrix T=r(table)
assert rowsof(T)==colsof(B)
frame surep: count
assert r(N)==6
frame surep: assert !missing(estimate)
local eqs : coleq B
local terms : colnames B
forvalues j=1/`=colsof(B)' {
    local eq : word `j' of `eqs'
    local eq_label : variable label `eq'
    if `"`eq_label'"' != "" local eq `"`eq_label'"'
    local term : word `j' of `terms'
    if "`term'"=="_cons" local term "Intercept"
    scalar expected=B[1,`j']
    frame surep: count if strtrim(label)=="`eq': `term'"
    assert r(N)==1
    frame surep: assert !missing(estimate,expected) if strtrim(label)=="`eq': `term'"
    frame surep: assert reldif(estimate,expected)<1e-12 if strtrim(label)=="`eq': `term'"
}
frame drop sur surep
}
if _rc {
 local ++fail_count
 display as error "FAIL: sureg_equation_identity rc=" _rc
}
else {
 local ++pass_count
 display as result "PASS: sureg_equation_identity"
}

local ++test_count
capture noisily {
clear
matrix M=(0,-1,1,.9)
effecttab, from(M) digits(2) refcat("0.00") frame(nf) eplotframe(ne)
matrix T=r(table)
assert T[1,1]==0 & T[1,2]==.9
frame ne: assert estimate==0 & ll==-1 & ul==1 & pvalue==.9 & rowtype=="effect"
frame nf: assert c2[4]=="(-1.00, 1.00)" & c3[4]=="0.90"
frame drop nf ne
}
if _rc {
 local ++fail_count
 display as error "FAIL: matrix_numeric_label rc=" _rc
}
else {
 local ++pass_count
 display as result "PASS: matrix_numeric_label"
}

local ++test_count
capture noisily {
clear
matrix M=(123456789012345,123456789012344,123456789012346,.02)
effecttab, from(M) digits(6) frame(bigf) eplotframe(bige)
frame bigf: assert c1[4]=="123456789012345.000000"
frame bigf: assert c2[4]=="(123456789012344.000000, 123456789012346.000000)"
frame bige: assert estimate==M[1,1] & ll==M[1,2] & ul==M[1,3]
frame drop bigf bige
}
if _rc {
 local ++fail_count
 display as error "FAIL: large_matrix_display rc=" _rc
}
else {
 local ++pass_count
 display as result "PASS: large_matrix_display"
}

local ++test_count
capture noisily {
clear
set seed 771
set obs 240
gen double x=rnormal()
gen byte y=1+mod(_n,3)
gen byte foreign=1+mod(_n,3)
label define alien 1 "AlienOne" 2 "AlienTwo" 3 "AlienThree",replace
label values foreign alien
collect clear
collect: mlogit y x, baseoutcome(1)
quietly mlogit foreign x, baseoutcome(1)
matrix before=e(b)
regtab, frame(mf) keepintercept
assert !missing(mreldif(before,e(b)))
assert mreldif(before,e(b))==0
frame mf: count if strpos(A,"Alien")
assert r(N)==0
frame drop mf
}
if _rc {
 local ++fail_count
 display as error "FAIL: foreign_numeric_equation_labels rc=" _rc
}
else {
 local ++pass_count
 display as result "PASS: foreign_numeric_equation_labels"
}

local ++test_count
capture noisily {
sysuse auto,clear
collect clear
collect: regress price mpg
matrix B1=e(b)
collect: regress turn mpg
matrix B2=e(b)
regtab, eplotframe(twoe)
frame twoe: count
assert r(N)==4
frame twoe: count if model==1 & label=="Mileage (mpg)"
assert r(N)==1
frame twoe: assert !missing(estimate,B1[1,1]) if model==1 & label=="Mileage (mpg)"
frame twoe: assert reldif(estimate,B1[1,1])<1e-12 if model==1 & label=="Mileage (mpg)"
frame twoe: assert !missing(estimate,B2[1,1]) if model==2 & label=="Mileage (mpg)"
frame twoe: assert reldif(estimate,B2[1,1])<1e-12 if model==2 & label=="Mileage (mpg)"
frame drop twoe
}
if _rc {
 local ++fail_count
 display as error "FAIL: different_single_outcomes rc=" _rc
}
else {
 local ++pass_count
 display as result "PASS: different_single_outcomes"
}

local ++test_count
capture noisily {
sysuse auto,clear
collect clear
collect: regress price mpg
scalar expected=_b[mpg]
local numericlabel=string(round(expected,.01),"%32.2f")
local numericlabel=strtrim("`numericlabel'")
regtab, refcat("`numericlabel'") frame(rnf) eplotframe(rne)
matrix T=r(table)
assert rowsof(T)==2
frame rne: count if label=="Mileage (mpg)" & rowtype=="effect" & !missing(estimate)
assert r(N)==1
frame rne: assert !missing(estimate,expected) if label=="Mileage (mpg)"
frame rne: assert reldif(estimate,expected)<1e-12 if label=="Mileage (mpg)"
frame drop rnf rne
}
if _rc {
 local ++fail_count
 display as error "FAIL: reg_numeric_label rc=" _rc
}
else {
 local ++pass_count
 display as result "PASS: reg_numeric_label"
}

local ++test_count
capture noisily {
sysuse auto,clear
collect clear
collect: regress price mpg
qa_state_snapshot,tag(regnewok) predict(xb)
regtab
qa_state_compare,tag(regnewok) allow(r global)
qa_state_snapshot,tag(regnewbad) predict(xb)
capture regtab,frame(default)
assert _rc==198
qa_state_compare,tag(regnewbad)
}
if _rc {
 local ++fail_count
 display as error "FAIL: regtab_full_state rc=" _rc
}
else {
 local ++pass_count
 display as result "PASS: regtab_full_state"
}

local ++test_count
capture noisily {
sysuse auto,clear
quietly regress price mpg
matrix M=(0,-1,1,.9)
qa_state_snapshot,tag(effnewok) predict(xb)
effecttab,from(M) refcat("0.00")
qa_state_compare,tag(effnewok) allow(r global)
qa_state_snapshot,tag(effnewbad) predict(xb)
capture effecttab,from(M) frame(default)
assert _rc==198
qa_state_compare,tag(effnewbad)
}
if _rc {
 local ++fail_count
 display as error "FAIL: effecttab_full_state rc=" _rc
}
else {
 local ++pass_count
 display as result "PASS: effecttab_full_state"
}

local ++test_count
capture noisily {
sysuse auto,clear
collect clear
collect: regress price mpg
scalar pair_native1=_b[mpg]
regtab, frame(pairr1) eplotframe(pairre1)
frame pairr1: local display1 : char _dta[tabtools_companion_id]
frame pairre1: local numeric1 : char _dta[tabtools_companion_id]
assert `"`display1'"' != ""
assert `"`display1'"' == `"`numeric1'"'
mata: mata clear
discard
replace price=2*price
collect clear
collect: regress price mpg
scalar pair_native2=_b[mpg]
regtab, frame(pairr2) eplotframe(pairre2)
frame pairr2: local display2 : char _dta[tabtools_companion_id]
frame pairre2: local numeric2 : char _dta[tabtools_companion_id]
assert `"`display2'"' != ""
assert `"`display2'"' == `"`numeric2'"'
assert `"`display1'"' != `"`display2'"'
assert !missing(pair_native1,pair_native2)
assert pair_native1!=pair_native2
frame pairre1: assert !missing(estimate) & reldif(estimate,pair_native1)<1e-12 if label=="Mileage (mpg)"
frame pairre2: assert !missing(estimate) & reldif(estimate,pair_native2)<1e-12 if label=="Mileage (mpg)"
frame drop pairr1 pairre1 pairr2 pairre2
}
if _rc {
 local ++fail_count
 display as error "FAIL: regtab_companion_pair_identity rc=" _rc
}
else {
 local ++pass_count
 display as result "PASS: regtab_companion_pair_identity"
}

local ++test_count
capture noisily {
matrix M=(1,0,2,.2)
effecttab, from(M) frame(paire1) eplotframe(pairep1)
frame paire1: local display1 : char _dta[tabtools_companion_id]
frame pairep1: local numeric1 : char _dta[tabtools_companion_id]
assert `"`display1'"' != ""
assert `"`display1'"' == `"`numeric1'"'
mata: mata clear
matrix M=(2,0,4,.2)
effecttab, from(M) frame(paire2) eplotframe(pairep2)
frame paire2: local display2 : char _dta[tabtools_companion_id]
frame pairep2: local numeric2 : char _dta[tabtools_companion_id]
assert `"`display2'"' != ""
assert `"`display2'"' == `"`numeric2'"'
assert `"`display1'"' != `"`display2'"'
frame pairep1: assert estimate==1 & ll==0 & ul==2 & pvalue==.2
frame pairep2: assert estimate==2 & ll==0 & ul==4 & pvalue==.2
frame drop paire1 pairep1 paire2 pairep2
}
if _rc {
 local ++fail_count
 display as error "FAIL: effecttab_companion_pair_identity rc=" _rc
}
else {
 local ++pass_count
 display as result "PASS: effecttab_companion_pair_identity"
}

local ++test_count
capture noisily {
* Load fingerprint functions again after the preceding deliberate mata clear.
do "_qa_state.do"
quietly regress price mpg
mata: st_local("sequence_before", strofreal(*findexternal("_tabtools_companion_seq")))
mata: *findexternal("_tabtools_companion_seq") = "hostile"
qa_state_snapshot,tag(pairbadtype) predict(xb)
capture _tabtools_companion_id
assert _rc==3498
qa_state_compare,tag(pairbadtype)
mata: st_local("counter_type", eltype(*findexternal("_tabtools_companion_seq")))
assert "`counter_type'"=="string"
mata: *findexternal("_tabtools_companion_seq") = J(2,2,1)
qa_state_snapshot,tag(pairbadshape) predict(xb)
capture _tabtools_companion_id
assert _rc==3498
qa_state_compare,tag(pairbadshape)
mata: st_local("counter_rows", strofreal(rows(*findexternal("_tabtools_companion_seq"))))
assert "`counter_rows'"=="2"
mata: *findexternal("_tabtools_companion_seq") = strtoreal(st_local("sequence_before"))
qa_state_snapshot,tag(pairgood) predict(xb)
_tabtools_companion_id
qa_state_compare,tag(pairgood)
assert `"`_companion_id'"' != ""
}
if _rc {
 local ++fail_count
 display as error "FAIL: companion_counter_refusal rc=" _rc
}
else {
 local ++pass_count
 display as result "PASS: companion_counter_refusal"
}

display "RESULT: test_review_2026_10_01_models tests=`test_count' pass=`pass_count' fail=`fail_count'"
capture log close _all
if `fail_count' exit 1
