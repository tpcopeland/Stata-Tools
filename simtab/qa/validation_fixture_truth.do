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
    generate double modelse=2
    quietly simtab group, estimate(x) se(modelse) true(20.5) metrics(mean bias empse meanse mse rmse n) order(sort) plotframe(fxmetrics,replace)
    assert r(N_cells)==4 & r(N_input)==40
    frame fxmetrics: assert _N==4
    frame fxmetrics: isid estimator_value
    forvalues j=1/4 {
        scalar avg=cells[`j',6]
        scalar bias=avg-20.5
        scalar mse=bias^2+99/12
        frame fxmetrics: assert n==10 & !missing(mean,bias,empse,meanse,mse,rmse) if estimator_value==`j'
        frame fxmetrics: assert abs(mean-scalar(avg))<1e-12 & abs(bias-scalar(bias))<1e-12 if estimator_value==`j'
        frame fxmetrics: assert abs(empse-sqrt(110/12))<1e-12 & meanse==2 if estimator_value==`j'
        frame fxmetrics: assert abs(mse-scalar(mse))<1e-12 & abs(rmse-sqrt(scalar(mse)))<1e-12 if estimator_value==`j'
    }
    frame drop fxmetrics
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
    generate double modelse=2
    quietly simtab group, estimate(x) se(modelse) true(20.5) metrics(mean bias empse meanse mse rmse n) order(sort) plotframe(fxmetrics,replace)
    assert r(N_cells)==4 & r(N_input)==40
    frame fxmetrics: assert _N==4
    frame fxmetrics: isid estimator_value
    forvalues j=1/4 {
        scalar avg=cells[`j',6]
        scalar bias=avg-20.5
        scalar mse=bias^2+99/12
        frame fxmetrics: assert n==10 & !missing(mean,bias,empse,meanse,mse,rmse) if estimator_value==`j'
        frame fxmetrics: assert abs(mean-scalar(avg))<1e-12 & abs(bias-scalar(bias))<1e-12 if estimator_value==`j'
        frame fxmetrics: assert abs(empse-sqrt(110/12))<1e-12 & meanse==2 if estimator_value==`j'
        frame fxmetrics: assert abs(mse-scalar(mse))<1e-12 & abs(rmse-sqrt(scalar(mse)))<1e-12 if estimator_value==`j'
    }
    frame drop fxmetrics
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
    generate double modelse=2
    quietly simtab group, estimate(x) se(modelse) true(20.5) metrics(mean bias empse meanse mse rmse n) order(sort) plotframe(fxmetrics,replace)
    assert r(N_cells)==4 & r(N_input)==40
    frame fxmetrics: assert _N==4
    frame fxmetrics: isid estimator_value
    forvalues j=1/4 {
        scalar avg=cells[`j',6]
        scalar bias=avg-20.5
        scalar mse=bias^2+99/12
        frame fxmetrics: assert n==10 & !missing(mean,bias,empse,meanse,mse,rmse) if estimator_value==`j'
        frame fxmetrics: assert abs(mean-scalar(avg))<1e-12 & abs(bias-scalar(bias))<1e-12 if estimator_value==`j'
        frame fxmetrics: assert abs(empse-sqrt(110/12))<1e-12 & meanse==2 if estimator_value==`j'
        frame fxmetrics: assert abs(mse-scalar(mse))<1e-12 & abs(rmse-sqrt(scalar(mse)))<1e-12 if estimator_value==`j'
    }
    frame drop fxmetrics
}
if _rc local ++fail
else local ++pass
display "RESULT: validation_fixture_truth tests=`tests' pass=`pass' fail=`fail' skip=0"
log close
if `fail' exit 9
