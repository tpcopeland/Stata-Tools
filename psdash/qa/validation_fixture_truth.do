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
quietly do "_qa_fx_a1.do"
quietly do "_qa_hostile.do"
local tests=0
local pass=0
local fail=0
local ++tests
capture noisily {
    local op ""
    * Friendly known-answer control
    qa_fx_a1_logit, clear n(360) seed(541)
    matrix cells=r(truth_cells)
    if "`op'"=="unsorted" {
        quietly count if id!=_n
        assert r(N)>0
    }
    if "`op'"=="codes_multidigit" {
        assert inlist(xcat,1,11,111)
        forvalues j=1/18 {
            matrix cells[`j',3]=cond(cells[`j',3]==2,11,cond(cells[`j',3]==3,111,1))
        }
    }
    generate double ps=. 
    forvalues j=1/18 {
        replace ps=cells[`j',4] if x1==cells[`j',1] & x2==cells[`j',2] & xcat==cells[`j',3]
    }
    assert !missing(ps) & ps>0 & ps<1
    generate double wantw=a/ps+(1-a)/(1-ps)
    generate double w2=wantw^2
    quietly summarize wantw, meanonly
    scalar wsum=r(sum)
    scalar wmean=r(mean)
    quietly summarize w2, meanonly
    scalar ess=wsum^2/r(sum)
    forvalues j=0/1 {
        quietly summarize wantw if a==`j', meanonly
        scalar sum`j'=r(sum)
        quietly summarize w2 if a==`j', meanonly
        scalar ess`j'=sum`j'^2/r(sum)
    }
    quietly psdash_weights a ps
    qa_assert_equal r(N) 360, property("included diagnostic rows")
    qa_assert_equal r(mean_wt) wmean, property("independent inverse probability mean") tol(1e-12)
    qa_assert_equal r(ess) ess, property("independent inverse probability ESS") tol(1e-12)
    qa_assert_equal r(ess_treated) ess1, property("treated inverse probability ESS") tol(1e-12)
    qa_assert_equal r(ess_control) ess0, property("control inverse probability ESS") tol(1e-12)
}
if _rc local ++fail
else local ++pass
local ++tests
capture noisily {
    local op "unsorted"
    * expect: EXACT
    qa_fx_a1_logit, clear n(360) seed(541) perturb(unsorted)
    assert "`r(perturb_applied)'"=="unsorted"
    matrix cells=r(truth_cells)
    if "`op'"=="unsorted" {
        quietly count if id!=_n
        assert r(N)>0
    }
    if "`op'"=="codes_multidigit" {
        assert inlist(xcat,1,11,111)
        forvalues j=1/18 {
            matrix cells[`j',3]=cond(cells[`j',3]==2,11,cond(cells[`j',3]==3,111,1))
        }
    }
    generate double ps=. 
    forvalues j=1/18 {
        replace ps=cells[`j',4] if x1==cells[`j',1] & x2==cells[`j',2] & xcat==cells[`j',3]
    }
    assert !missing(ps) & ps>0 & ps<1
    generate double wantw=a/ps+(1-a)/(1-ps)
    generate double w2=wantw^2
    quietly summarize wantw, meanonly
    scalar wsum=r(sum)
    scalar wmean=r(mean)
    quietly summarize w2, meanonly
    scalar ess=wsum^2/r(sum)
    forvalues j=0/1 {
        quietly summarize wantw if a==`j', meanonly
        scalar sum`j'=r(sum)
        quietly summarize w2 if a==`j', meanonly
        scalar ess`j'=sum`j'^2/r(sum)
    }
    quietly psdash_weights a ps
    qa_assert_equal r(N) 360, property("included diagnostic rows")
    qa_assert_equal r(mean_wt) wmean, property("independent inverse probability mean") tol(1e-12)
    qa_assert_equal r(ess) ess, property("independent inverse probability ESS") tol(1e-12)
    qa_assert_equal r(ess_treated) ess1, property("treated inverse probability ESS") tol(1e-12)
    qa_assert_equal r(ess_control) ess0, property("control inverse probability ESS") tol(1e-12)
}
if _rc local ++fail
else local ++pass
local ++tests
capture noisily {
    local op "codes_multidigit"
    * expect: EXACT
    qa_fx_a1_logit, clear n(360) seed(541) perturb(codes_multidigit)
    assert "`r(perturb_applied)'"=="codes_multidigit"
    matrix cells=r(truth_cells)
    if "`op'"=="unsorted" {
        quietly count if id!=_n
        assert r(N)>0
    }
    if "`op'"=="codes_multidigit" {
        assert inlist(xcat,1,11,111)
        forvalues j=1/18 {
            matrix cells[`j',3]=cond(cells[`j',3]==2,11,cond(cells[`j',3]==3,111,1))
        }
    }
    generate double ps=. 
    forvalues j=1/18 {
        replace ps=cells[`j',4] if x1==cells[`j',1] & x2==cells[`j',2] & xcat==cells[`j',3]
    }
    assert !missing(ps) & ps>0 & ps<1
    generate double wantw=a/ps+(1-a)/(1-ps)
    generate double w2=wantw^2
    quietly summarize wantw, meanonly
    scalar wsum=r(sum)
    scalar wmean=r(mean)
    quietly summarize w2, meanonly
    scalar ess=wsum^2/r(sum)
    forvalues j=0/1 {
        quietly summarize wantw if a==`j', meanonly
        scalar sum`j'=r(sum)
        quietly summarize w2 if a==`j', meanonly
        scalar ess`j'=sum`j'^2/r(sum)
    }
    quietly psdash_weights a ps
    qa_assert_equal r(N) 360, property("included diagnostic rows")
    qa_assert_equal r(mean_wt) wmean, property("independent inverse probability mean") tol(1e-12)
    qa_assert_equal r(ess) ess, property("independent inverse probability ESS") tol(1e-12)
    qa_assert_equal r(ess_treated) ess1, property("treated inverse probability ESS") tol(1e-12)
    qa_assert_equal r(ess_control) ess0, property("control inverse probability ESS") tol(1e-12)
}
if _rc local ++fail
else local ++pass
display "RESULT: validation_fixture_truth tests=`tests' pass=`pass' fail=`fail' skip=0"
log close
if `fail' exit 9
