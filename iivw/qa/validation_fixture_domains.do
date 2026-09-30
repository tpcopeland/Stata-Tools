*! validation_fixture_domains.do — canonical VISIT scalar domains and finite-data oracles
*! Author: Timothy P Copeland, Karolinska Institutet
version 16.0
clear all
set more off
set varabbrev off
local qa_dir "`c(pwd)'"
do _iivw_qa_common.do
iivw_qa_bootstrap
do _qa_fx_a3.do
do _qa_state.do
do _qa_metamorphic.do
capture program drop _fx_visit_domains
program define _fx_visit_domains, rclass
    version 16.0
    args op
    tempname W B D Raw Fitted
    drop if !visit
    tempfile visits
    save `visits'
    iivw_fit y, unweighted id(id) time(time) timespec(linear) nolog
    estimates store fx_naive
    iivw_weight, id(id) time(time) visit_cov(lag_y) maxfu(4) wtype(iivw) nolog
    local N=_N
    iivw_fit y, vce(fixed) timespec(linear) nolog
    estimates store fx_weighted
    matrix `B'=e(b)
    * Package help: Gaussian identity GLM with clustered SEs is independence
    * GEE. Its point equation is weighted normal equations; solve independently.
    mata: X=(st_data(.,"time"),J(st_nobs(),1,1)); Y=st_data(.,"y"); w=st_data(.,"_iivw_iw"); use=(!missing(Y):&!missing(w):&(w:>0)); X=select(X,use);Y=select(Y,use);w=select(w,use);st_matrix("`W'",(invsym(quadcross(X,w,X))*quadcross(X,w,Y))')
    mata: mata drop X Y w use
    assert mreldif(`B',`W')<1e-9
    local tests=1
    local pass=1
    local fail=0
    foreach cv in 0 100 {
        foreach esscut in .001 1 {
            local ++tests
            capture noisily {
                qa_state_snapshot, tag(visit_balance)
                iivw_balance, cvcut(`cv') essratiocut(`esscut')
                assert r(N)<=`N' & r(N)>0
                local want=cond(r(weight_cv)<`cv' | r(ess_ratio)>`esscut',"low",cond(r(weight_cv)>=.25 & r(ess_ratio)<=.8,"adequate","moderate"))
                assert "`r(leverage)'"=="`want'"
                qa_state_compare, tag(visit_balance)
                di "ORACLE VISIT `op' balance cv`cv' ess`esscut': exact threshold rule"
            }
            if _rc==0 local ++pass
            else local ++fail
        }
    }
    foreach level in 10 99.99 {
        local ++tests
        capture noisily {
            iivw_fit y, vce(fixed) timespec(linear) level(`level') nolog
            assert mreldif(e(b),`W')<1e-9
            assert e(level)==`level'
            lincom time, level(`level')
            assert reldif(r(lb),r(estimate)-invnormal(1-(1-`level'/100)/2)*r(se))<1e-10
            assert reldif(r(ub),r(estimate)+invnormal(1-(1-`level'/100)/2)*r(se))<1e-10
        }
        if _rc==0 local ++pass
        else local ++fail
    }
    local ++tests
    capture noisily {
        * expect: EXACT
        qa_option_domain, command(iivw_balance, cvcut(@v@)) inside(0;1) outside(-1;.)
    }
    local rc=_rc
    if `rc'==0 local ++pass
    else {
        local ++fail
        di as error "FAIL VISIT iivw_balance, cvcut(@v@) rc=`rc'"
    }
    local ++tests
    capture noisily {
        * expect: EXACT
        qa_option_domain, command(iivw_balance, essratiocut(@v@)) inside(.001;1) outside(0;1.001;.)
    }
    local rc=_rc
    if `rc'==0 local ++pass
    else {
        local ++fail
        di as error "FAIL VISIT iivw_balance, essratiocut(@v@) rc=`rc'"
    }
    local ++tests
    capture noisily {
        * expect: EXACT
        qa_option_domain, command(iivw_balance, balcut(@v@)) inside(.001;10) outside(0;-1;.)
    }
    local rc=_rc
    if `rc'==0 local ++pass
    else {
        local ++fail
        di as error "FAIL VISIT iivw_balance, balcut(@v@) rc=`rc'"
    }
    local ++tests
    capture noisily {
        * expect: EXACT
        qa_option_domain, command(iivw_balance, component(@v@)) inside(iiw;final) outside(bad)
    }
    local rc=_rc
    if `rc'==0 local ++pass
    else {
        local ++fail
        di as error "FAIL VISIT iivw_balance, component(@v@) rc=`rc'"
    }
    local ++tests
    capture noisily {
        * expect: EXACT
        qa_option_domain, command(iivw_balance, level(@v@)) inside(10;99.99) outside(9;100)
    }
    local rc=_rc
    if `rc'==0 local ++pass
    else {
        local ++fail
        di as error "FAIL VISIT iivw_balance, level(@v@) rc=`rc'"
    }
    local ++tests
    capture noisily {
        * expect: EXACT
        qa_option_domain, command(iivw_fit y, vce(fixed) timespec(linear) model(@v@) nolog) inside(gee) outside(bad)
    }
    local rc=_rc
    if `rc'==0 local ++pass
    else {
        local ++fail
        di as error "FAIL VISIT iivw_fit y, vce(fixed) timespec(linear) model(@v@) nolog rc=`rc'"
    }
    local ++tests
    capture noisily {
        * expect: EXACT
        qa_option_domain, command(iivw_fit y, vce(fixed) timespec(@v@) nolog) inside(linear;quadratic;cubic;none) outside(bad)
    }
    local rc=_rc
    if `rc'==0 local ++pass
    else {
        local ++fail
        di as error "FAIL VISIT iivw_fit y, vce(fixed) timespec(@v@) nolog rc=`rc'"
    }
    local ++tests
    capture noisily {
        * expect: EXACT
        qa_option_domain, command(iivw_fit y, vce(@v@) timespec(linear) nolog) inside(fixed) outside(bad)
    }
    local rc=_rc
    if `rc'==0 local ++pass
    else {
        local ++fail
        di as error "FAIL VISIT iivw_fit y, vce(@v@) timespec(linear) nolog rc=`rc'"
    }
    local ++tests
    capture noisily {
        * expect: EXACT
        qa_option_domain, command(iivw_fit y, vce(fixed) citype(@v@) timespec(linear) nolog) inside(wald) outside(bad)
    }
    local rc=_rc
    if `rc'==0 local ++pass
    else {
        local ++fail
        di as error "FAIL VISIT iivw_fit y, vce(fixed) citype(@v@) timespec(linear) nolog rc=`rc'"
    }
    local ++tests
    capture noisily {
        * expect: EXACT
        qa_option_domain, command(iivw_fit y, vce(fixed) level(@v@) timespec(linear) nolog) inside(10;99.99) outside(9;100)
    }
    local rc=_rc
    if `rc'==0 local ++pass
    else {
        local ++fail
        di as error "FAIL VISIT iivw_fit y, vce(fixed) level(@v@) timespec(linear) nolog rc=`rc'"
    }
    local ++tests
    capture noisily {
        * expect: EXACT
        qa_option_domain, command(iivw_diagnose time, unweighted(fx_naive) weighted(fx_weighted) adjusted(fx_weighted) estimand(@v@)) inside(marginal;contrast) outside(bad)
    }
    local rc=_rc
    if `rc'==0 local ++pass
    else {
        local ++fail
        di as error "FAIL VISIT iivw_diagnose time, unweighted(fx_naive) weighted(fx_weighted) adjusted(fx_weighted) estimand(@v@) rc=`rc'"
    }
    local ++tests
    capture noisily {
        * expect: EXACT
        qa_option_domain, command(iivw_diagnose time, unweighted(fx_naive) weighted(fx_weighted) adjusted(fx_weighted) exogeneity(@v@)) inside(exogenous;endogenous;unknown) outside(bad)
    }
    local rc=_rc
    if `rc'==0 local ++pass
    else {
        local ++fail
        di as error "FAIL VISIT iivw_diagnose time, unweighted(fx_naive) weighted(fx_weighted) adjusted(fx_weighted) exogeneity(@v@) rc=`rc'"
    }
    local ++tests
    capture noisily {
        * expect: EXACT
        qa_option_domain, command(iivw_diagnose time, unweighted(fx_naive) weighted(fx_weighted) adjusted(fx_weighted) level(@v@)) inside(10;99.99) outside(9;100)
    }
    local rc=_rc
    if `rc'==0 local ++pass
    else {
        local ++fail
        di as error "FAIL VISIT iivw_diagnose time, unweighted(fx_naive) weighted(fx_weighted) adjusted(fx_weighted) level(@v@) rc=`rc'"
    }
    local ++tests
    capture noisily {
        * expect: EXACT
        qa_option_domain, command(iivw_exogtest y, id(id) time(time) maxfu(4) level(@v@) nolog) inside(10;99.99) outside(9;100)
    }
    local rc=_rc
    if `rc'==0 local ++pass
    else {
        local ++fail
        di as error "FAIL VISIT iivw_exogtest y, id(id) time(time) maxfu(4) level(@v@) nolog rc=`rc'"
    }
    local ++tests
    capture noisily {
        preserve
        * VISIT has continuous clocks. A categorical fit is intentionally
        * evaluated on this explicit four-bin observed-time adapter, avoiding
        * one parameter per unique visit; population mean truth is not used.
        replace time=floor(time)
        iivw_fit y, unweighted id(id) time(time) timespec(categorical) model(gee) nolog
        predict double fitted_bin, mu
        bysort time: egen double observed_bin=mean(y)
        assert !missing(fitted_bin,observed_bin) & reldif(fitted_bin,observed_bin)<1e-8
        restore
    }
    if _rc==0 local ++pass
    else local ++fail
    local ++tests
    capture noisily {
        qa_option_domain, command(iivw_fit y, citype(@v@) timespec(linear) nolog) inside(none) outside(bad)
    }
    if _rc==0 local ++pass
    else local ++fail
    capture estimates drop fx_naive fx_weighted
    return scalar tests=`tests'
    return scalar pass=`pass'
    return scalar fail=`fail'
end
local tests=0
local pass=0
local fail=0
qa_fx_a3_visit, clear tier(unit) n(200) seed(931)
_fx_visit_domains friendly
local tests=`tests'+r(tests)
local pass=`pass'+r(pass)
local fail=`fail'+r(fail)
* expect: EXACT
qa_fx_a3_visit, clear tier(unit) n(200) seed(931) perturb(unsorted)
_fx_visit_domains unsorted
local tests=`tests'+r(tests)
local pass=`pass'+r(pass)
local fail=`fail'+r(fail)
display "RESULT: validation_fixture_domains tests=`tests' pass=`pass' fail=`fail' skip=0"
iivw_qa_sandbox_restore
if `fail'>0 exit 1
