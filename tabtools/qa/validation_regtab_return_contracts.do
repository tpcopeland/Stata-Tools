*! validation_regtab_return_contracts 2026/10/01
*! Author: Timothy P Copeland, Karolinska Institutet
version 17
clear all
set more off
set processors 1
capture log close _all
log using "validation_regtab_return_contracts.log",replace text name(_models_qa)
local pkg_dir = subinstr("`c(pwd)'", "/qa", "", .)
adopath ++ "`pkg_dir'"
local tests 0
local pass 0
local fail 0

local ++tests
capture noisily {
    sysuse auto,clear
    collect clear
    collect: regress price mpg weight
    scalar expected_r2_a=e(r2_a)
    scalar expected_rmse=e(rmse)
    scalar expected_F=e(F)
    matrix before=e(b)
    regtab, stats(r2_a rmse F)
    assert !missing(r(r2_a_1),expected_r2_a,r(rmse_1),expected_rmse,r(F_1),expected_F)
    assert reldif(r(r2_a_1),expected_r2_a)<1e-12
    assert reldif(r(rmse_1),expected_rmse)<1e-12
    assert reldif(r(F_1),expected_F)<1e-12
    assert !missing(mreldif(before,e(b)))
    assert mreldif(before,e(b))==0
}
if _rc {
    local ++fail
    display as error "FAIL: OLS return parity rc=" _rc
}
else {
    local ++pass
    display "PASS: OLS return parity"
}

local ++tests
capture noisily {
    clear
    set seed 6607
    set obs 160
    gen double x=rnormal()
    gen double t=exp(-.4*x)*(-ln(runiform()))
    gen byte d=mod(_n,4)!=0
    stset t,failure(d)
    collect clear
    collect: stcox x
    scalar expected_events=e(N_fail)
    regtab, stats(events)
    assert !missing(r(events_1),expected_events)
    assert r(events_1)==expected_events
}
if _rc {
    local ++fail
    display as error "FAIL: Cox event parity rc=" _rc
}
else {
    local ++pass
    display "PASS: Cox event parity"
}

local ++tests
capture noisily {
    clear
    set seed 9193
    set obs 160
    gen double x=rnormal()
    gen double y=.8*x+rnormal()
    replace x=. if mod(_n,7)==0
    mi set mlong
    mi register imputed x
    mi register regular y
    mi impute regress x y,add(5) rseed(2391)
    collect clear
    collect: mi estimate,post: regress y x
    scalar expected_mi_m=e(M_mi)
    scalar expected_fmi=e(fmi_max_mi)
    regtab, stats(mi_m fmi)
    assert !missing(r(mi_m_1),expected_mi_m,r(fmi_1),expected_fmi)
    assert r(mi_m_1)==expected_mi_m
    assert reldif(r(fmi_1),expected_fmi)<1e-12
}
if _rc {
    local ++fail
    display as error "FAIL: MI return parity rc=" _rc
}
else {
    local ++pass
    display "PASS: MI return parity"
}
display "RESULT: validation_regtab_return_contracts tests=`tests' pass=`pass' fail=`fail'"
capture log close _all
if `fail' exit 1
