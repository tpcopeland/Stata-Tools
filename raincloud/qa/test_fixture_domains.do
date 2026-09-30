*! test_fixture_domains.do -- independent summaries and bandwidth; named full-state boundaries
* Timothy P Copeland, Karolinska Institutet
version 16.0
clear all
set processors 1
set varabbrev off
set more off
set graphics off
capture log close _all
log using "test_fixture_domains.log",text replace
local pkgdir=regexr("`c(pwd)'","/qa$","")
adopath ++ "`pkgdir'"
quietly do "_qa_fx_a7.do"
quietly do "_qa_hostile.do"
quietly do "_qa_state.do"
quietly do "_qa_metamorphic.do"
// [R] kdensity pp9-10 fetched30Sep2026: h=.9min(sd,IQR/1.349)n^(-1/5).
// https://www.stata.com/manuals/rkdensity.pdf . Canonical x=1..40.
capture program drop _qa_rain_domain_check
program define _qa_rain_domain_check
    version 16.0
    tempname out
    matrix `out'=r(stats)
    assert r(N)==40 & r(n_groups)==1 & rowsof(`out')==1 & colsof(`out')==8
    assert `out'[1,1]==40 & `out'[1,2]==20.5 & `out'[1,4]==20.5
    assert `out'[1,5]==10.5 & `out'[1,6]==30.5 & `out'[1,7]==20
    qa_assert_equal `out'[1,3] sqrt(410/3),property("independent domain sample SD") tol(1e-11)
    assert !missing(`out'[1,8]) & `out'[1,8]>0
    if "$QA_RAIN_AXIS"!="bandwidth" qa_assert_equal `out'[1,8] .9*min(sqrt(410/3),20/1.349)*40^(-.2),property("independent native bandwidth formula") tol(1e-10)
end
capture program drop _qa_rain_domains
program define _qa_rain_domains
    version 16.0
    quietly raincloud x, norain name(fxdomain,replace)
    global QA_RAIN_AXIS "initial"
    _qa_rain_domain_check
    global QA_RAIN_AXIS "bandwidth"
    * expect: REFUSED (outside); numeric inside controls precede candidate use.
    qa_option_domain, command(raincloud x, norain name(fxdomain,replace) bandwidth(@v@)) inside(0 1 2) outside(-1 .) check(_qa_rain_domain_check)
    assert r(n_cells)==5 & r(n_violations)==0
    global QA_RAIN_AXIS "n"
    * expect: REFUSED (outside); numeric inside controls precede candidate use.
    qa_option_domain, command(raincloud x, norain name(fxdomain,replace) n(@v@)) inside(10 37) outside(9) check(_qa_rain_domain_check)
    assert r(n_cells)==3 & r(n_violations)==0
    global QA_RAIN_AXIS "opacity"
    * expect: REFUSED (outside); numeric inside controls precede candidate use.
    qa_option_domain, command(raincloud x, norain name(fxdomain,replace) opacity(@v@)) inside(0 100) outside(-1 101) check(_qa_rain_domain_check)
    assert r(n_cells)==4 & r(n_violations)==0
    global QA_RAIN_AXIS "cloudwidth"
    * expect: REFUSED (outside); numeric inside controls precede candidate use.
    qa_option_domain, command(raincloud x, norain name(fxdomain,replace) cloudwidth(@v@)) inside(.01 1) outside(0 -1) check(_qa_rain_domain_check)
    assert r(n_cells)==4 & r(n_violations)==0
    global QA_RAIN_AXIS "jitter"
    * expect: REFUSED (outside); numeric inside controls precede candidate use.
    qa_option_domain, command(raincloud x, norain name(fxdomain,replace) jitter(@v@)) inside(0 1) outside(-.1 1.1) check(_qa_rain_domain_check)
    assert r(n_cells)==4 & r(n_violations)==0
    global QA_RAIN_AXIS "seed"
    * expect: REFUSED (outside); numeric inside controls precede candidate use.
    qa_option_domain, command(raincloud x, norain name(fxdomain,replace) seed(@v@)) inside(-1 0 2147483647) outside(-2 .) check(_qa_rain_domain_check)
    assert r(n_cells)==5 & r(n_violations)==0
    global QA_RAIN_AXIS "boxwidth"
    * expect: REFUSED (outside); numeric inside controls precede candidate use.
    qa_option_domain, command(raincloud x, norain name(fxdomain,replace) boxwidth(@v@)) inside(.01 1) outside(0 -1) check(_qa_rain_domain_check)
    assert r(n_cells)==4 & r(n_violations)==0
    global QA_RAIN_AXIS "gap"
    * expect: REFUSED (outside); numeric inside controls precede candidate use.
    qa_option_domain, command(raincloud x, norain name(fxdomain,replace) gap(@v@)) inside(.01 2) outside(0 -1) check(_qa_rain_domain_check)
    assert r(n_cells)==4 & r(n_violations)==0
    foreach h in 0 1 2 {
        quietly raincloud x, norain bandwidth(`h') name(fxdomain,replace)
        matrix point=r(stats)
        scalar expected=cond(`h'==0,.9*min(sqrt(410/3),20/1.349)*40^(-.2),`h')
        qa_assert_equal point[1,8] expected,property("consumed explicit/default bandwidth") tol(1e-10)
    }
    foreach axis in bandwidth n opacity cloudwidth jitter seed boxwidth gap {
        local value=-1
        if "`axis'"=="n" local value=9
        if "`axis'"=="jitter" local value=1.1
        if "`axis'"=="seed" local value=-2
        if inlist("`axis'","cloudwidth","boxwidth","gap") local value=0
        qa_state_snapshot,tag(boundary)
        tempfile errorlog
        log using "`errorlog'",text replace name(refusal)
        capture noisily raincloud x, norain name(fxdomain,replace) `axis'(`value')
        local gotrc=_rc
        log close refusal
        qa_state_compare,tag(boundary)
        mata: st_local("named",strofreal(any(strpos(strlower(cat(st_local("errorlog"))),st_local("axis")+"()"))))
        assert `gotrc'==198 & `named'==1
    }
end
local tests=0
local pass=0
local fail=0
local ++tests
capture noisily {
    qa_fx_a7_labelled,clear tier(micro)
    _qa_rain_domains
}
if _rc local ++fail
else local ++pass
local ++tests
capture noisily {
    * expect: INVARIANT (permuted rows retain the exact summaries/bandwidth).
    qa_fx_a7_labelled,clear tier(micro) perturb(unsorted)
    _qa_rain_domains
}
if _rc local ++fail
else local ++pass
display "RESULT: test_fixture_domains tests=`tests' pass=`pass' fail=`fail' skip=0"
log close
if `fail' exit 9
