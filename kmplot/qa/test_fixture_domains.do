*! test_fixture_domains.do -- canonical legal controls and named/full-state refusals
* Timothy P Copeland, Karolinska Institutet
version 16.0
clear all
set processors 1
set varabbrev off
set more off
set graphics off
capture log close _all
log using "test_fixture_domains.log", text replace
local pkgdir=regexr("`c(pwd)'","/qa$","")
adopath ++ "`pkgdir'"
quietly do "_qa_fx_a2.do"
quietly do "_qa_hostile.do"
quietly do "_qa_state.do"
quietly do "_qa_metamorphic.do"
capture program drop _qakm_domain_check
program define _qakm_domain_check
    version 16.0
    scalar level_used=r(level)
    matrix L=r(landmarks)
    display "KM_DOMAIN N=" r(N) " groups=" r(n_groups) " rows=" rowsof(L) " cols=" colsof(L)
    matrix list L
    assert r(N)==24 & r(n_groups)==2 & rowsof(L)==2 & colsof(L)==5
    forvalues a=0/1 {
        local tr=`a'*5+2
        local row=`a'+1
        scalar S=T[`tr',7]
        scalar Y=T[`tr',3]
        scalar D=T[`tr',4]+T[`tr',5]
        scalar GW=D/(Y*(Y-D))
        scalar Z=invnormal(1-(100-level_used)/200)
        scalar lo=exp(-exp(ln(-ln(S))+Z*sqrt(GW)/abs(ln(S))))
        scalar hi=exp(-exp(ln(-ln(S))-Z*sqrt(GW)/abs(ln(S))))
        assert L[`row',1]==`row' & L[`row',2]==1
        qa_assert_equal L[`row',3] S, property("enumerated legal-domain KM point") tol(1e-12)
        qa_assert_equal L[`row',4] lo, property("independent legal-level Greenwood lower") tol(1e-11)
        qa_assert_equal L[`row',5] hi, property("independent legal-level Greenwood upper") tol(1e-11)
    }
end
local tests=0
local pass=0
local fail=0
local ++tests
capture noisily {
    * Friendly independent life-table control
    qa_fx_a2_lifetable, clear tier(micro) 
    matrix T=r(truth_table)
    quietly stset t, failure(d) id(id)
    quietly kmplot, by(x1) ci landmark(1) name(fxdom,replace)
    _qakm_domain_check
    * expect: REFUSED (outside), EXACT (independent numeric inside control)
    qa_option_domain, command(kmplot, by(x1) ci landmark(1) name(fxdom,replace) level(@v@)) inside(90 99) outside(0 100) check(_qakm_domain_check)
    assert r(n_cells)==4 & r(n_violations)==0
    qa_option_domain, command(kmplot, by(x1) ci landmark(1) name(fxdom,replace) ciopacity(@v@)) inside(0 100) outside(-1 101) check(_qakm_domain_check)
    assert r(n_cells)==4 & r(n_violations)==0
    qa_option_domain, command(kmplot, by(x1) ci landmark(1) censor name(fxdom,replace) censorthin(@v@)) inside(1 3) outside(0) check(_qakm_domain_check)
    assert r(n_cells)==3 & r(n_violations)==0
    qa_option_domain, command(kmplot, by(x1) ci landmark(1) risktable timepoints(1) name(fxdom,replace) riskheight(@v@)) inside(1 80) outside(0 81) check(_qakm_domain_check)
    assert r(n_cells)==4 & r(n_violations)==0
    foreach axis in level ciopacity censorthin riskheight {
        local value=0
        local extra ""
        if "`axis'"=="ciopacity" local value=-1
        if "`axis'"=="censorthin" local extra "censor"
        if "`axis'"=="riskheight" local extra "risktable timepoints(1)"
        qa_state_snapshot, tag(domain)
        tempfile namedlog
        log using "`namedlog'.log", text replace name(domain_error)
        capture noisily kmplot, by(x1) ci landmark(1) name(fxdom,replace) `extra' `axis'(`value')
        local refusal_rc=_rc
        log close domain_error
        qa_state_compare, tag(domain)
        mata: st_local("named",strofreal(any(strpos(strlower(cat(st_local("namedlog")+".log")),st_local("axis")+"()"))))
        assert `refusal_rc'==198 & `named'==1
    }
}
if _rc local ++fail
else local ++pass
local ++tests
capture noisily {
    * expect: INVARIANT (unsorted)
    qa_fx_a2_lifetable, clear tier(micro) perturb(unsorted)
    matrix T=r(truth_table)
    quietly stset t, failure(d) id(id)
    quietly kmplot, by(x1) ci landmark(1) name(fxdom,replace)
    _qakm_domain_check
    * expect: REFUSED (outside), EXACT (independent numeric inside control)
    qa_option_domain, command(kmplot, by(x1) ci landmark(1) name(fxdom,replace) level(@v@)) inside(90 99) outside(0 100) check(_qakm_domain_check)
    assert r(n_cells)==4 & r(n_violations)==0
    qa_option_domain, command(kmplot, by(x1) ci landmark(1) name(fxdom,replace) ciopacity(@v@)) inside(0 100) outside(-1 101) check(_qakm_domain_check)
    assert r(n_cells)==4 & r(n_violations)==0
    qa_option_domain, command(kmplot, by(x1) ci landmark(1) censor name(fxdom,replace) censorthin(@v@)) inside(1 3) outside(0) check(_qakm_domain_check)
    assert r(n_cells)==3 & r(n_violations)==0
    qa_option_domain, command(kmplot, by(x1) ci landmark(1) risktable timepoints(1) name(fxdom,replace) riskheight(@v@)) inside(1 80) outside(0 81) check(_qakm_domain_check)
    assert r(n_cells)==4 & r(n_violations)==0
    foreach axis in level ciopacity censorthin riskheight {
        local value=0
        local extra ""
        if "`axis'"=="ciopacity" local value=-1
        if "`axis'"=="censorthin" local extra "censor"
        if "`axis'"=="riskheight" local extra "risktable timepoints(1)"
        qa_state_snapshot, tag(domain)
        tempfile namedlog
        log using "`namedlog'.log", text replace name(domain_error)
        capture noisily kmplot, by(x1) ci landmark(1) name(fxdom,replace) `extra' `axis'(`value')
        local refusal_rc=_rc
        log close domain_error
        qa_state_compare, tag(domain)
        mata: st_local("named",strofreal(any(strpos(strlower(cat(st_local("namedlog")+".log")),st_local("axis")+"()"))))
        assert `refusal_rc'==198 & `named'==1
    }
}
if _rc local ++fail
else local ++pass
display "RESULT: test_fixture_domains tests=`tests' pass=`pass' fail=`fail' skip=0"
log close
if `fail' exit 9
