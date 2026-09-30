*! validation_fixture_matrix.do -- independent finite summaries and Gaussian mean recovery
* Timothy P Copeland, Karolinska Institutet
version 17.0
clear all
set processors 1
set varabbrev off
set more off
set graphics off
capture log close _all
log using "validation_fixture_matrix.log",text replace
local pkgdir=regexr("`c(pwd)'","/qa$","")
adopath ++ "`pkgdir'"
quietly do "_qa_fx_a1.do"
quietly do "_qa_fx_a7.do"
quietly do "_qa_hostile.do"
quietly do "_qa_state.do"
// Direct finite moments, computed before simtab, no reference output.
mata:
real matrix qa_sim_moments(real colvector X,real colvector G,real colvector S,real scalar theta)
{
    real colvector levels,ii,x,s
    real matrix out
    real scalar j,n,m
    levels=uniqrows(sort(G,1));out=J(rows(levels),8,.)
    for(j=1;j<=rows(levels);j++){
        ii=selectindex(G:==levels[j]);x=X[ii];s=S[ii];n=rows(x);m=sum(x)/n
        out[j,1]=n;out[j,2]=m;out[j,3]=m-theta
        if(n>1)out[j,4]=sqrt(sum((x:-m):^2)/(n-1))
        out[j,5]=sqrt(sum(s:^2)/n);out[j,6]=sum((x:-theta):^2)/n;out[j,7]=sqrt(out[j,6])
        out[j,8]=levels[j]
    }
    return(out)
}
end
capture program drop _qa_sim_compare
program define _qa_sim_compare
    version 17.0
    args estimate group theta restriction recovery
    tempvar sample
    generate byte `sample'=!missing(`estimate',`group',modelse)
    if "`restriction'"!="" replace `sample'=`sample' & insample
    mata: ii=selectindex(st_data(.,st_local("sample")));st_matrix("wanted",qa_sim_moments(st_data(ii,st_local("estimate")),st_data(ii,st_local("group")),st_data(ii,"modelse"),strtoreal(st_local("theta"))))
    quietly count if `sample'
    scalar wantedN=r(N)
    quietly simtab `group' `restriction',estimate(`estimate') se(modelse) true(`theta') minreps(2) warnreps(2) metrics(mean bias empse meanse mse rmse n) order(sort) plotframe(fxmetrics,replace)
    assert r(N_input)==wantedN & r(N_cells)==rowsof(wanted)
    frame fxmetrics:assert _N==rowsof(wanted)
    frame fxmetrics:isid estimator_value
    forvalues j=1/`=rowsof(wanted)' {
        local k=1
        foreach metric in n mean bias empse meanse mse rmse {
            scalar target=wanted[`j',`k']
            frame fxmetrics:assert missing(`metric')==missing(scalar(target)) if estimator_value==`j'
            if !missing(scalar(target)) {
                frame fxmetrics:assert !missing(`metric') & reldif(`metric',scalar(target))<1e-11 if estimator_value==`j'
            }
            local ++k
        }
        if "`recovery'"=="recovery" {
            * Independent normal DGP: mean MCSE=1/sqrt(n), not candidate SE.
            frame fxmetrics:assert abs(mean-2)<=4/sqrt(wanted[`j',1]) if estimator_value==`j'
        }
    }
    frame drop fxmetrics
end
local tests=0
local pass=0
local fail=0
foreach seed in 541 967 {
    local ++tests
    capture noisily {
        qa_fx_a1_gauss,clear n(3600) sigma(1) seed(`seed')
        generate double estimate=2+y-mu
        generate double modelse=1
        _qa_sim_compare estimate xcat 2 "" recovery
    }
    if _rc local ++fail
    else local ++pass
}
local ++tests
capture noisily {
    qa_fx_a1_logit,clear n(360) seed(541)
    generate double modelse=1
    _qa_sim_compare y xcat 0 "" ""
}
if _rc local ++fail
else local ++pass
local ++tests
capture noisily {
    * expect: EXACT
    qa_fx_a1_logit,clear n(360) seed(541) perturb(separate)
    generate double modelse=1
    _qa_sim_compare y xcat 0 "" ""
}
if _rc local ++fail
else local ++pass
local ++tests
capture noisily {
    * expect: EXACT
    qa_fx_a1_logit,clear n(360) seed(541) perturb(single_level)
    generate double modelse=1
    _qa_sim_compare y x2 0 "" ""
}
if _rc local ++fail
else local ++pass
local ++tests
capture noisily {
    * expect: EXACT
    qa_fx_a1_logit,clear n(360) seed(541) perturb(base_absent)
    generate double modelse=1
    _qa_sim_compare y xcat 0 "if insample" ""
}
if _rc local ++fail
else local ++pass
local ++tests
capture noisily {
    * expect: EXACT
    qa_fx_a1_logit,clear n(360) seed(541) perturb(codes_multidigit)
    generate double modelse=1
    _qa_sim_compare y xcat 0 "" ""
}
if _rc local ++fail
else local ++pass
local ++tests
capture noisily {
    * expect: EXACT
    qa_fx_a1_logit,clear n(360) seed(541) perturb(miss_subgroup)
    generate double modelse=1
    _qa_sim_compare x1 xcat 0 "" ""
}
if _rc local ++fail
else local ++pass
local ++tests
capture noisily {
    * expect: REFUSED
    qa_fx_a1_logit,clear n(360) seed(541) perturb(miss_all_column)
    generate double modelse=1
    tempfile errorlog
    qa_state_snapshot,tag(empty)
    log using "`errorlog'",text replace name(refusal)
    capture noisily simtab xcat,estimate(x2) se(modelse) true(0) metrics(mean n) plotframe(fxmetrics,replace)
    local gotrc=_rc
    display "SIMEMPTY rc=`gotrc'"
    log close refusal
    qa_state_compare,tag(empty)
    mata: st_local("named",strofreal(any(strpos(strlower(cat(st_local("errorlog"))),"no usable observations"))))
    assert `gotrc'==2000 & `named'==1
}
if _rc local ++fail
else local ++pass
local ++tests
capture noisily {
    * expect: EXACT
    qa_fx_a1_logit,clear n(360) seed(541) perturb(near_positivity)
    generate double modelse=1
    _qa_sim_compare y a 0 "" ""
}
if _rc local ++fail
else local ++pass
local ++tests
capture noisily {
    * expect: SHIFTED
    qa_fx_a1_logit,clear n(360) seed(541) perturb(scale_shift)
    generate double modelse=1
    _qa_sim_compare x1 xcat 0 "" ""
}
if _rc local ++fail
else local ++pass
local ++tests
capture noisily {
    * expect: EXACT
    qa_hostile_codes,clear
    generate double modelse=1
    _qa_sim_compare y code 0 "" ""
}
if _rc local ++fail
else local ++pass
local ++tests
capture noisily {
    * expect: EXACT
    qa_hostile_names,clear
    generate double modelse=1
    local targets "`r(twins)' `r(long)'"
    generate byte group=1
    foreach target of local targets {
        _qa_sim_compare `target' group 0 "" ""
    }
}
if _rc local ++fail
else local ++pass
local ++tests
capture noisily {
    * expect: EXACT
    qa_hostile_missing,clear
    generate double modelse=1
    _qa_sim_compare x group 0 "" ""
}
if _rc local ++fail
else local ++pass
local ++tests
capture noisily {
    * expect: REFUSED
    qa_fx_a7_labelled,clear tier(micro) perturb(single_row)
    generate double modelse=1
    tempfile errorlog
    qa_state_snapshot,tag(single)
    log using "`errorlog'",text replace name(refusal)
    capture noisily simtab group,estimate(x) se(modelse) true(0) metrics(mean n) plotframe(fxmetrics,replace)
    local gotrc=_rc
    log close refusal
    qa_state_compare,tag(single)
    mata: st_local("named",strofreal(any(strpos(strlower(cat(st_local("errorlog"))),"usable replication"))))
    assert `gotrc'==2001 & `named'==1
}
if _rc local ++fail
else local ++pass
display "RESULT: validation_fixture_matrix tests=`tests' pass=`pass' fail=`fail' skip=0"
log close
if `fail' exit 9
