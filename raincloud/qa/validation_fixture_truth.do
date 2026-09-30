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
    matrix cells=r(truth_cells)
    quietly raincloud x, over(group) nocloud norain name(fxcloud,replace)
    matrix got=r(stats)
    assert r(N)==40 & r(n_groups)==4 & rowsof(got)==4 & colsof(got)==8
    assert "`r(group_levels)'"=="1 2 5 9"
    forvalues j=1/4 {
        scalar avg=cells[`j',6]
        qa_assert_equal got[`j',1] 10, property("per-group rows")
        qa_assert_equal got[`j',2] avg, property("independent group mean") tol(1e-12)
        qa_assert_equal got[`j',3] sqrt(110/12), property("independent sample SD") tol(1e-12)
        qa_assert_equal got[`j',4] avg, property("independent median") tol(1e-12)
        qa_assert_equal got[`j',5] avg-2.5, property("independent 25th percentile") tol(1e-12)
        qa_assert_equal got[`j',6] avg+2.5, property("independent 75th percentile") tol(1e-12)
        qa_assert_equal got[`j',7] 5, property("independent IQR")
        assert missing(got[`j',8])
    }
}
if _rc local ++fail
else local ++pass
local ++tests
capture noisily {
    local op "unsorted"
    * expect: EXACT
    qa_fx_a7_labelled, clear tier(micro) perturb(unsorted)
    assert !missing(r(perturb_n_unsorted)) & r(perturb_n_unsorted)>0
    matrix cells=r(truth_cells)
    quietly raincloud x, over(group) nocloud norain name(fxcloud,replace)
    matrix got=r(stats)
    assert r(N)==40 & r(n_groups)==4 & rowsof(got)==4 & colsof(got)==8
    assert "`r(group_levels)'"=="1 2 5 9"
    forvalues j=1/4 {
        scalar avg=cells[`j',6]
        qa_assert_equal got[`j',1] 10, property("per-group rows")
        qa_assert_equal got[`j',2] avg, property("independent group mean") tol(1e-12)
        qa_assert_equal got[`j',3] sqrt(110/12), property("independent sample SD") tol(1e-12)
        qa_assert_equal got[`j',4] avg, property("independent median") tol(1e-12)
        qa_assert_equal got[`j',5] avg-2.5, property("independent 25th percentile") tol(1e-12)
        qa_assert_equal got[`j',6] avg+2.5, property("independent 75th percentile") tol(1e-12)
        qa_assert_equal got[`j',7] 5, property("independent IQR")
        assert missing(got[`j',8])
    }
}
if _rc local ++fail
else local ++pass
local ++tests
capture noisily {
    local op "label_gaps"
    * expect: EXACT
    qa_fx_a7_labelled, clear tier(micro) perturb(label_gaps)
    assert !missing(r(perturb_n_label_gaps)) & r(perturb_n_label_gaps)>0
    matrix cells=r(truth_cells)
    quietly raincloud x, over(group) nocloud norain name(fxcloud,replace)
    matrix got=r(stats)
    assert r(N)==40 & r(n_groups)==4 & rowsof(got)==4 & colsof(got)==8
    assert "`r(group_levels)'"=="1 2 5 9"
    forvalues j=1/4 {
        scalar avg=cells[`j',6]
        qa_assert_equal got[`j',1] 10, property("per-group rows")
        qa_assert_equal got[`j',2] avg, property("independent group mean") tol(1e-12)
        qa_assert_equal got[`j',3] sqrt(110/12), property("independent sample SD") tol(1e-12)
        qa_assert_equal got[`j',4] avg, property("independent median") tol(1e-12)
        qa_assert_equal got[`j',5] avg-2.5, property("independent 25th percentile") tol(1e-12)
        qa_assert_equal got[`j',6] avg+2.5, property("independent 75th percentile") tol(1e-12)
        qa_assert_equal got[`j',7] 5, property("independent IQR")
        assert missing(got[`j',8])
    }
}
if _rc local ++fail
else local ++pass
display "RESULT: validation_fixture_truth tests=`tests' pass=`pass' fail=`fail' skip=0"
log close
if `fail' exit 9
