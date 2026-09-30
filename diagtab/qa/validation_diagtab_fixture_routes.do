*! validation_diagtab_fixture_routes.do -- labelled samples, exact intervals and identities
*! Author: Timothy P Copeland, Karolinska Institutet
* Wilson score formula: Stata [R] ci, Methods and formulas, fetched2026-09-30
* https://www.stata.com/manuals/rci.pdf ; independent algebra below.
version 16.0
clear all
set more off
capture log close _all
log using "validation_diagtab_fixture_routes.log", text replace
local pkg_dir=substr("`c(pwd)'",1,strlen("`c(pwd)'")-3)
adopath ++ "`pkg_dir'"
do _qa_fx_a1.do
do _qa_fx_a7.do
do _qa_hostile.do
do _qa_state.do
do _qa_metamorphic.do
local tests 0
local pass 0
local fail 0

**# LABELLED friendly
local ++tests
capture noisily {
    * expect: EXACT
    qa_fx_a7_labelled, clear seed(37)
    ereturn clear
    qa_state_snapshot, tag(diag_routes)
    * Forty enumerated id values: odd are cases, even are controls.
    * At20.5 each true and false class has10positive and10negative.
    * Case-control rank wins sum0..19=190/400, so AUC=.475.
    quietly diagtab x y, cutoff(20.5) auc level(90) digits(6)
    assert r(TP)==10 & r(FP)==10 & r(TN)==10 & r(FN)==10
    assert r(sensitivity)==.5 & r(specificity)==.5
    assert !missing(r(auc)) & abs(r(auc)-190/400)<1e-7
    local z=invnormal(.95)
    local half=`z'*sqrt(.25/20+`z'^2/(4*20^2))/(1+`z'^2/20)
    assert abs(r(sensitivity_lb)-(.5-`half'))<1e-12
    assert abs(r(sensitivity_ub)-(.5+`half'))<1e-12
    qa_state_compare, tag(diag_routes)

}
local outcome=_rc
capture frame drop fixture_result
if `outcome' {
    local ++fail
    display as error "FAIL: LABELLED friendly; rc=" `outcome'
}
else {
    local ++pass
    display as result "PASS: LABELLED friendly"
}

**# LABELLED unsorted
local ++tests
capture noisily {
    * expect: EXACT
    qa_fx_a7_labelled, clear seed(37) perturb(unsorted)
    ereturn clear
    qa_state_snapshot, tag(diag_routes)
    * Forty enumerated id values: odd are cases, even are controls.
    * At20.5 each true and false class has10positive and10negative.
    * Case-control rank wins sum0..19=190/400, so AUC=.475.
    quietly diagtab x y, cutoff(20.5) auc level(90) digits(6)
    assert r(TP)==10 & r(FP)==10 & r(TN)==10 & r(FN)==10
    assert r(sensitivity)==.5 & r(specificity)==.5
    assert !missing(r(auc)) & abs(r(auc)-190/400)<1e-7
    local z=invnormal(.95)
    local half=`z'*sqrt(.25/20+`z'^2/(4*20^2))/(1+`z'^2/20)
    assert abs(r(sensitivity_lb)-(.5-`half'))<1e-12
    assert abs(r(sensitivity_ub)-(.5+`half'))<1e-12
    qa_state_compare, tag(diag_routes)

}
local outcome=_rc
capture frame drop fixture_result
if `outcome' {
    local ++fail
    display as error "FAIL: LABELLED unsorted; rc=" `outcome'
}
else {
    local ++pass
    display as result "PASS: LABELLED unsorted"
}

**# LABELLED label_gaps
local ++tests
capture noisily {
    * expect: EXACT
    qa_fx_a7_labelled, clear seed(37) perturb(label_gaps)
    ereturn clear
    qa_state_snapshot, tag(diag_routes)
    * Forty enumerated id values: odd are cases, even are controls.
    * At20.5 each true and false class has10positive and10negative.
    * Case-control rank wins sum0..19=190/400, so AUC=.475.
    quietly diagtab x y, cutoff(20.5) auc level(90) digits(6)
    assert r(TP)==10 & r(FP)==10 & r(TN)==10 & r(FN)==10
    assert r(sensitivity)==.5 & r(specificity)==.5
    assert !missing(r(auc)) & abs(r(auc)-190/400)<1e-7
    local z=invnormal(.95)
    local half=`z'*sqrt(.25/20+`z'^2/(4*20^2))/(1+`z'^2/20)
    assert abs(r(sensitivity_lb)-(.5-`half'))<1e-12
    assert abs(r(sensitivity_ub)-(.5+`half'))<1e-12
    qa_state_compare, tag(diag_routes)

}
local outcome=_rc
capture frame drop fixture_result
if `outcome' {
    local ++fail
    display as error "FAIL: LABELLED label_gaps; rc=" `outcome'
}
else {
    local ++pass
    display as result "PASS: LABELLED label_gaps"
}

**# LABELLED boundary_values
local ++tests
capture noisily {
    * expect: EXACT
    qa_fx_a7_labelled, clear seed(37) perturb(boundary_values)
    ereturn clear
    qa_state_snapshot, tag(diag_routes)
    * Forty enumerated id values: odd are cases, even are controls.
    * At20.5 each true and false class has10positive and10negative.
    * Case-control rank wins sum0..19=190/400, so AUC=.475.
    quietly diagtab x y, cutoff(20.5) auc level(90) digits(6)
    assert r(TP)==10 & r(FP)==10 & r(TN)==10 & r(FN)==10
    assert r(sensitivity)==.5 & r(specificity)==.5
    assert !missing(r(auc)) & abs(r(auc)-190/400)<1e-7
    local z=invnormal(.95)
    local half=`z'*sqrt(.25/20+`z'^2/(4*20^2))/(1+`z'^2/20)
    assert abs(r(sensitivity_lb)-(.5-`half'))<1e-12
    assert abs(r(sensitivity_ub)-(.5+`half'))<1e-12
    qa_state_compare, tag(diag_routes)

}
local outcome=_rc
capture frame drop fixture_result
if `outcome' {
    local ++fail
    display as error "FAIL: LABELLED boundary_values; rc=" `outcome'
}
else {
    local ++pass
    display as result "PASS: LABELLED boundary_values"
}

**# LABELLED miss_all_column
local ++tests
capture noisily {
    * expect: REFUSED
    qa_fx_a7_labelled, clear seed(37) perturb(miss_all_column)
    ereturn clear
    qa_state_snapshot, tag(diag_routes)
    capture noisily diagtab x y, cutoff(20.5) auc level(90) digits(6)
    assert _rc==2000
    qa_state_compare, tag(diag_routes)

}
local outcome=_rc
capture frame drop fixture_result
if `outcome' {
    local ++fail
    display as error "FAIL: LABELLED miss_all_column; rc=" `outcome'
}
else {
    local ++pass
    display as result "PASS: LABELLED miss_all_column"
}

**# LABELLED single_row
local ++tests
capture noisily {
    * expect: REFUSED
    qa_fx_a7_labelled, clear seed(37) perturb(single_row)
    ereturn clear
    qa_state_snapshot, tag(diag_routes)
    capture noisily diagtab x y, cutoff(20.5) auc level(90) digits(6)
    assert _rc==198
    qa_state_compare, tag(diag_routes)

}
local outcome=_rc
capture frame drop fixture_result
if `outcome' {
    local ++fail
    display as error "FAIL: LABELLED single_row; rc=" `outcome'
}
else {
    local ++pass
    display as result "PASS: LABELLED single_row"
}

**# Boundary level10 digits0
local ++tests
capture noisily {
    * expect: EXACT
    qa_fx_a7_labelled, clear seed(37) perturb(boundary_values)
    * Cutoff3 is TP21/FN4,TN16/FP9 in the exact diagnostic fixture.
    local z=invnormal(1-(1-10/100)/2)
    local center=(.5+`z'^2/40)/(1+`z'^2/20)
    local half=`z'*sqrt(.25/20+`z'^2/(4*20^2))/(1+`z'^2/20)
    qa_state_snapshot, tag(diag_routes)
    quietly diagtab x y, cutoff(20.5) level(10) digits(0) wilson
    assert r(TP)==10 & r(FN)==10 & r(TN)==10 & r(FP)==10
    assert abs(r(sensitivity_lb)-(`center'-`half'))<1e-12
    assert abs(r(sensitivity_ub)-(`center'+`half'))<1e-12
    assert abs(r(sensitivity)-.5)<1e-14
    qa_state_compare, tag(diag_routes)

}
local outcome=_rc
capture frame drop fixture_result
if `outcome' {
    local ++fail
    display as error "FAIL: Boundary level10 digits0; rc=" `outcome'
}
else {
    local ++pass
    display as result "PASS: Boundary level10 digits0"
}

**# Boundary level99 digits6
local ++tests
capture noisily {
    * expect: EXACT
    qa_fx_a7_labelled, clear seed(37) perturb(boundary_values)
    * Cutoff3 is TP21/FN4,TN16/FP9 in the exact diagnostic fixture.
    local z=invnormal(1-(1-99/100)/2)
    local center=(.5+`z'^2/40)/(1+`z'^2/20)
    local half=`z'*sqrt(.25/20+`z'^2/(4*20^2))/(1+`z'^2/20)
    qa_state_snapshot, tag(diag_routes)
    quietly diagtab x y, cutoff(20.5) level(99) digits(6) wilson
    assert r(TP)==10 & r(FN)==10 & r(TN)==10 & r(FP)==10
    assert abs(r(sensitivity_lb)-(`center'-`half'))<1e-12
    assert abs(r(sensitivity_ub)-(`center'+`half'))<1e-12
    assert abs(r(sensitivity)-.5)<1e-14
    qa_state_compare, tag(diag_routes)

}
local outcome=_rc
capture frame drop fixture_result
if `outcome' {
    local ++fail
    display as error "FAIL: Boundary level99 digits6; rc=" `outcome'
}
else {
    local ++pass
    display as result "PASS: Boundary level99 digits6"
}

**# Exact 32-character variable twins
local ++tests
capture noisily {
    * expect: EXACT
    qa_hostile_names, clear
    local twins `r(long)'
    local rating: word 1 of `twins'
    local reference: word 2 of `twins'
    qa_fx_a1_diag, clear tier(micro) seed(37) names(score=`rating' y=`reference')
    qa_state_snapshot, tag(diag_routes)
    quietly diagtab `rating' `reference', cutoff(3)
    assert r(TP)==21 & r(FP)==9 & r(TN)==16 & r(FN)==4
    assert abs(r(sensitivity)-21/25)<1e-14
    qa_state_compare, tag(diag_routes)

}
local outcome=_rc
capture frame drop fixture_result
if `outcome' {
    local ++fail
    display as error "FAIL: Exact 32-character variable twins; rc=" `outcome'
}
else {
    local ++pass
    display as result "PASS: Exact 32-character variable twins"
}

**# Nonbinary negative and above-maxlong gold categories
local ++tests
capture noisily {
    * expect: REFUSED
    qa_hostile_codes, clear
    qa_state_snapshot, tag(diag_routes)
    capture noisily diagtab y code, cutoff(10)
    assert _rc==198
    qa_state_compare, tag(diag_routes)

}
local outcome=_rc
capture frame drop fixture_result
if `outcome' {
    local ++fail
    display as error "FAIL: Nonbinary negative and above-maxlong gold categories; rc=" `outcome'
}
else {
    local ++pass
    display as result "PASS: Nonbinary negative and above-maxlong gold categories"
}

**# Named long_names metamorphic identity
local ++tests
capture noisily {
    * expect: INVARIANT
    qa_fx_a1_diag, clear tier(micro) seed(37)
    quietly diagtab score y, cutoff(3)
    assert r(TP)==21 & r(FP)==9 & r(TN)==16 & r(FN)==4
    qa_metamorphic long_names, var(score) command(diagtab @var@ y, cutoff(3)) returns(r(TP) r(FP) r(TN) r(FN) r(sensitivity) r(specificity))
    assert r(n_items)==6 & r(maxreldif)==0

}
local outcome=_rc
capture frame drop fixture_result
if `outcome' {
    local ++fail
    display as error "FAIL: Named long_names metamorphic identity; rc=" `outcome'
}
else {
    local ++pass
    display as result "PASS: Named long_names metamorphic identity"
}

**# Opaque hostile title corpus actual frame contents
local ++tests
capture noisily {
    * expect: EXACT
    qa_hostile_strings
    local corpus `r(names)'
    foreach corpus_name of local corpus {
        qa_fx_a7_labelled, clear seed(37)
        qa_hostile_strings
        mata: st_local("caption",st_global(st_local("corpus_name")))
        qa_state_snapshot, tag(diag_strings)
        quietly diagtab x y, cutoff(20.5) title(`"`macval(caption)'"') frame(fixture_result)
        assert r(TP)==10 & r(FP)==10 & r(TN)==10 & r(FN)==10
        frame fixture_result: mata: assert(st_sdata(1,"title")==st_local("caption"))
        frame drop fixture_result
        qa_state_compare, tag(diag_strings)
    }

}
local outcome=_rc
capture frame drop fixture_result
if `outcome' {
    local ++fail
    display as error "FAIL: Opaque hostile title corpus actual frame contents; rc=" `outcome'
}
else {
    local ++pass
    display as result "PASS: Opaque hostile title corpus actual frame contents"
}

display as result "RESULT: validation_diagtab_fixture_routes tests=`tests' pass=`pass' fail=`fail'"
log close
if `fail' exit 1
