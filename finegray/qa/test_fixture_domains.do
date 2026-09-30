*! test_fixture_domains.do -- legal controls and independent bootstrap SD
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
quietly do "_qa_state.do"
quietly do "_qa_hostile.do"
quietly do "_qa_metamorphic.do"
capture program drop _qafg_domain_check
program define _qafg_domain_check
    version 16.0
    matrix got=r(table)
    assert rowsof(got)==1 & colsof(got)==5
    assert !missing(got[1,1],got[1,2],got[1,3],got[1,4],got[1,5])
    qa_assert_equal got[1,1] 2, property("fixed legal horizon")
    qa_assert_equal got[1,2] wantPoint, property("native independently fitted CIF point") tol(1e-6)
    assert got[1,3]>0 & got[1,4]<got[1,2] & got[1,5]>got[1,2]
end
capture program drop _qafg_domain_fitcheck
program define _qafg_domain_fitcheck
    version 16.0
    assert e(converged)==1 & !missing(_b[x1],_b[x2])
    qa_assert_equal _b[x1] refB[1,1], property("legal iteration coefficient x1") tol(1e-6)
    qa_assert_equal _b[x2] refB[1,2], property("legal iteration coefficient x2") tol(1e-6)
end
capture program drop _qafg_domain_predictcheck
program define _qafg_domain_predictcheck
    version 16.0
    assert !missing(fxpred,fxpred_lci,fxpred_uci,wantAll)
    assert fxpred_lci<fxpred & fxpred_uci>fxpred
    assert abs(fxpred-wantAll)<1e-6
end
local tests=0
local pass=0
local fail=0
local ++tests
capture noisily {
    // F: conforming continuous FG DGP; native reference is computed first.
    qa_fx_a2_pwexp, clear model(finegray) n(240) seed(541)
    quietly stset t, failure(cause==1) id(id)
    quietly stcrreg x1 x2, compete(cause==2) nolog
    matrix refB=e(b)
    quietly predict double nativeBase, basecif
    quietly summarize nativeBase if t<=2, meanonly
    scalar wantPoint=r(max)
    assert !missing(wantPoint) & wantPoint>0 & wantPoint<1
    drop nativeBase
    quietly stset t, failure(d) id(id)
    quietly finegray x1 x2, compete(cause) cause(1) nolog
    _qafg_domain_fitcheck
    * expect: REFUSED (outside), EXACT (documented inside control)
    qa_option_domain, command(finegray x1 x2, compete(cause) cause(1) nolog iterate(@v@)) inside(200) outside(0) check(_qafg_domain_fitcheck)
    assert r(n_cells)==2 & r(n_violations)==0
    quietly finegray x1 x2, compete(cause) cause(1) nolog
    * expect: REFUSED (outside), EXACT (inside; actual finite curves)
    qa_option_domain, command(finegray_cif, at(x1=0 x2=0) attime(2) ci nograph level(@v@)) inside(90 99) outside(0 100) setup(finegray x1 x2, compete(cause) cause(1) nolog) check(_qafg_domain_check)
    assert r(n_cells)==4 & r(n_violations)==0
    * expect: REFUSED (outside), EXACT (minimum accepted resampling count)
    qa_option_domain, command(finegray_cif, at(x1=0 x2=0) attime(2) ci nograph bootstrap(@v@) seed(17)) inside(25) outside(-1 24) setup(finegray x1 x2, compete(cause) cause(1) nolog) check(_qafg_domain_check)
    assert r(n_cells)==3 & r(n_violations)==0
    * expect: REFUSED (outside), EXACT (both actual native seed boundaries)
    qa_option_domain, command(finegray_cif, at(x1=0 x2=0) attime(2) ci nograph bootstrap(25) seed(@v@)) inside(0 2147483647) outside(-1 2147483648) setup(finegray x1 x2, compete(cause) cause(1) nolog) check(_qafg_domain_check)
    assert r(n_cells)==4 & r(n_violations)==0
    // Direct live-estimate probes additionally prove the named validation
    // cause and the complete caller fingerprint. Helper1.1.1 preserves setup e().
    foreach axis in level bootstrap seed {
        local vals "0 100"
        local rest ""
        if "`axis'"=="bootstrap" {
            local vals "-1 24"
            local rest "seed(17)"
        }
        if "`axis'"=="seed" {
            local vals "-1 2147483648"
            local rest "bootstrap(25)"
        }
        foreach value of local vals {
            quietly finegray x1 x2, compete(cause) cause(1) nolog
            qa_state_snapshot, tag(live_domain)
            tempfile namedlog
            log using "`namedlog'.log", text replace name(domain_error)
            capture noisily finegray_cif, at(x1=0 x2=0) attime(2) ci nograph `axis'(`value') `rest'
            local refusal_rc=_rc
            log close domain_error
            qa_state_compare, tag(live_domain)
            mata: st_local("named",strofreal(any(strpos(strlower(cat(st_local("namedlog")+".log")),st_local("axis")+"()"))))
            display "LIVE_DOMAIN axis=`axis' value=`value' rc=`refusal_rc' named=`named'"
            assert `refusal_rc'==198 & `named'==1
        }
    }
}
if _rc local ++fail
else local ++pass
local ++tests
capture noisily {
    // Independent native refits of the SAME subject bootstrap draws, before candidate.
    qa_fx_a2_pwexp, clear model(finegray) n(240) seed(541)
    tempfile rows
    quietly save "`rows'"
    matrix repCIF=J(25,1,.)
    set seed 17
    forvalues rep=1/25 {
        quietly use "`rows'", clear
        quietly bsample
        generate long freshid=_n
        quietly stset t, failure(cause==1) id(freshid)
        quietly stcrreg x1 x2, compete(cause==2) nolog
        assert e(converged)==1
        quietly predict double nativeBase, basecif
        quietly summarize nativeBase if t<=2, meanonly
        assert !missing(r(max)) & r(max)>0 & r(max)<1
        matrix repCIF[`rep',1]=r(max)
    }
    mata: st_numscalar("wantBootstrapSD",sqrt(variance(st_matrix("repCIF"))))
    quietly use "`rows'", clear
    quietly stset t, failure(d) id(id)
    quietly finegray x1 x2, compete(cause) cause(1) nolog
    local rng=c(rngstate)
    quietly finegray_cif, at(x1=0 x2=0) attime(2) ci nograph bootstrap(25) seed(17)
    matrix got=r(table)
    assert r(bootstrap_requested)==25 & r(bootstrap_success)==25 & r(bootstrap_failed)==0
    assert "`r(se_method)'"=="bootstrap" & "`c(rngstate)'"=="`rng'"
    qa_assert_equal got[1,3] wantBootstrapSD, property("independent native matched-draw bootstrap SD") tol(1e-6)
    _qafg_domain_check
}
if _rc local ++fail
else local ++pass
local ++tests
capture noisily {
    // F positive controls and U domain cells consume row-specific prediction.
    qa_fx_a2_pwexp, clear model(finegray) n(240) seed(541)
    quietly stset t, failure(cause==1) id(id)
    quietly stcrreg x1 x2, compete(cause==2) nolog
    matrix refB=e(b)
    quietly predict double nativeBase, basecif
    quietly summarize nativeBase if t<=2, meanonly
    scalar wantPoint=r(max)
    generate double evaltime=2
    generate double wantAll=1-(1-wantPoint)^exp(x1*refB[1,1]+x2*refB[1,2])
    drop nativeBase
    quietly stset t, failure(d) id(id)
    quietly finegray x1 x2, compete(cause) cause(1) nolog
    * expect: REFUSED (outside), EXACT (inside, every subject profile)
    qa_option_domain, command(finegray_predict fxpred, cif timevar(evaltime) ci level(@v@)) inside(90 99) outside(0 100) setup(finegray x1 x2, compete(cause) cause(1) nolog) check(_qafg_domain_predictcheck)
    assert r(n_cells)==4 & r(n_violations)==0
    qa_option_domain, command(finegray_predict fxpred, cif timevar(evaltime) ci bootstrap(@v@) seed(17)) inside(25) outside(-1 24) setup(finegray x1 x2, compete(cause) cause(1) nolog) check(_qafg_domain_predictcheck)
    assert r(n_cells)==3 & r(n_violations)==0
    qa_option_domain, command(finegray_predict fxpred, cif timevar(evaltime) ci bootstrap(25) seed(@v@)) inside(0 2147483647) outside(-1 2147483648) setup(finegray x1 x2, compete(cause) cause(1) nolog) check(_qafg_domain_predictcheck)
    assert r(n_cells)==4 & r(n_violations)==0
    foreach axis in level bootstrap seed {
        local vals "0 100"
        local rest ""
        if "`axis'"=="bootstrap" {
            local vals "-1 24"
            local rest "seed(17)"
        }
        if "`axis'"=="seed" {
            local vals "-1 2147483648"
            local rest "bootstrap(25)"
        }
        foreach value of local vals {
            quietly finegray x1 x2, compete(cause) cause(1) nolog
            qa_state_snapshot, tag(predict_domain)
            tempfile namedlog
            log using "`namedlog'.log", text replace name(predict_error)
            capture noisily finegray_predict fxpred, cif timevar(evaltime) ci `axis'(`value') `rest'
            local refusal_rc=_rc
            log close predict_error
            qa_state_compare, tag(predict_domain)
            mata: st_local("named",strofreal(any(strpos(strlower(cat(st_local("namedlog")+".log")),st_local("axis")+"()"))))
            assert `refusal_rc'==198 & `named'==1
        }
    }
}
if _rc local ++fail
else local ++pass
display "RESULT: test_fixture_domains tests=`tests' pass=`pass' fail=`fail' skip=0"
log close
if `fail' exit 9
