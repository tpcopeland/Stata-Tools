*! test_fixture_cold_workbook.do -- cold strict settings, actual workbook moments and named refusal
* Timothy P Copeland, Karolinska Institutet
version 17.0
set processors 1
set more off
capture log close _all
log using "test_fixture_cold_workbook.log",text replace
local pkgdir=regexr("`c(pwd)'","/qa$","")
adopath ++ "`pkgdir'"
local tests=0
local pass=0
local fail=0
foreach strict in off on {
    foreach route in success refusal {
        local ++tests
        capture noisily {
            clear all
            quietly do "_qa_fx_a1.do"
            quietly do "_qa_state.do"
            qa_fx_a1_logit,clear n(360) seed(541)
            generate double modelse=1
            * Independent finite Bernoulli moments before calling simtab.
            mata: X=st_data(.,("y","xcat"));W=J(3,3,.);for(j=1;j<=3;j++){z=select(X[,1],X[,2]:==j);n=rows(z);p=sum(z)/n;W[j,]=(n,p,sqrt(n*p*(1-p)/(n-1)));};st_matrix("wanted",W)
            mata: mata set matastrict `strict'
            tempfile book refusal
            log using "`refusal'",text replace name(refusal)
            qa_state_snapshot,tag(cold)
            local sheet "Truth"
            if "`route'"=="refusal" local sheet "Bad/Sheet"
            capture noisily simtab xcat,estimate(y) se(modelse) true(0) metrics(mean bias empse n) digits(6) sedigits(6) order(sort) xlsx("`book'.xlsx") sheet("`sheet'")
            local candidate_rc=_rc
            log close refusal
            qa_state_compare,tag(cold)
            assert "`c(matastrict)'"=="`strict'"
            if "`route'"=="success" {
                assert `candidate_rc'==0
                frame create fxbook
                frame fxbook:import excel using "`book'.xlsx",sheet("Truth") allstring clear
                frame fxbook:assert _N==4
                forvalues j=1/3 {
                    frame fxbook:assert A=="" & real(B)==`j' & abs(real(C)-wanted[`j',2])<=.5e-6+1e-15 & abs(real(D)-wanted[`j',2])<=.5e-6+1e-15 & abs(real(E)-wanted[`j',3])<=.5e-6+1e-15 & real(F)==wanted[`j',1] if _n==`j'+1
                }
                frame drop fxbook
                erase "`book'.xlsx"
            }
            else {
                assert `candidate_rc'==198
                mata: st_local("named",strofreal(any(strpos(strlower(cat(st_local("refusal"))),"sheet name contains characters not allowed by excel"))))
                assert `named'==1
                capture confirm file "`book'.xlsx"
                assert _rc==601
            }
            * Native Mata work still functions after either cold compilation path.
            mata: assert(sum((1,2,3))==6)
            assert "`c(matastrict)'"=="`strict'"
            display "COLD strict=`strict' `route': original rc/state retained; actual workbook moments or named198; next native Mata exact"
        }
        if _rc local ++fail
        else local ++pass
    }
}
display "RESULT: test_fixture_cold_workbook tests=`tests' pass=`pass' fail=`fail' skip=0"
log close
if `fail' exit 9
