*! test_fixture_precision.do -- storage-independent summaries and strict caller preservation
* Timothy P Copeland, Karolinska Institutet
version 17.0
clear all
set processors 1
set more off
set varabbrev off
capture log close _all
log using "test_fixture_precision.log",text replace
args source_override
local pkgdir=regexr("`c(pwd)'","/qa$","")
adopath ++ "`pkgdir'"
if `"`source_override'"'!="" adopath ++ `"`source_override'"'
quietly do "_qa_fx_a1.do"
quietly do "_qa_state.do"
local tests=0
local pass=0
local fail=0
foreach kind in byte int long float double {
    foreach variant in F U {
        local ++tests
        capture noisily {
            if "`variant'"=="F" {
                qa_fx_a1_logit,clear n(360) seed(541)
            }
            else {
                * expect: EXACT
                qa_fx_a1_logit,clear n(360) seed(541) perturb(unsorted)
            }
            recast `kind' y
            generate double modelse=1
            generate long caller_order=_n
            format y %9.3f
            label variable y "Original estimate storage"
            * Independent Bernoulli moments before candidate invocation.
            mata: X=st_data(.,("y","xcat"));W=J(3,3,.);for(j=1;j<=3;j++){z=select(X[,1],X[,2]:==j);n=rows(z);p=sum(z)/n;W[j,]=(n,p,sqrt(n*p*(1-p)/(n-1)));};st_matrix("wanted",W)
            foreach decimals in 0 6 {
                if `decimals'==0 set varabbrev on
                else set varabbrev off
                qa_state_snapshot,tag(caller)
                quietly simtab xcat,estimate(y) se(modelse) true(0) metrics(mean bias empse n) digits(`decimals') sedigits(`decimals') order(sort) plotframe(fxnumeric,replace) frame(fxrender,replace)
                qa_state_compare,tag(caller) allow(frame)
                assert "`: type y'"=="`kind'" & caller_order==_n
                frame fxnumeric:assert _N==3
                frame fxrender:assert _N==4
                forvalues j=1/3 {
                    frame fxnumeric:assert n==wanted[`j',1] & !missing(mean,bias,empse) if estimator_value==`j'
                    frame fxnumeric:assert abs(mean-wanted[`j',2])<1e-14 & abs(bias-wanted[`j',2])<1e-14 & abs(empse-wanted[`j',3])<1e-14 if estimator_value==`j'
                    frame fxrender:assert abs(real(c2)-wanted[`j',2])<=.5*10^(-`decimals')+1e-15 & abs(real(c3)-wanted[`j',2])<=.5*10^(-`decimals')+1e-15 & abs(real(c4)-wanted[`j',3])<=.5*10^(-`decimals')+1e-15 if _n==`j'+1
                }
                frame drop fxnumeric fxrender
            }
            display "STORAGE `kind' `variant': exact mean/SD, decimals0/6, caller type/values/order/state retained"
        }
        if _rc local ++fail
        else local ++pass
    }
}
display "RESULT: test_fixture_precision tests=`tests' pass=`pass' fail=`fail' skip=0"
log close
if `fail' exit 9
