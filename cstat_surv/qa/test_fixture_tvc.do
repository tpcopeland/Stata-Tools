*! test_fixture_tvc.do -- static-score boundary, old1.0.1 and entry-only1.0.2 are red
version 16.0
clear all
set processors 1
set varabbrev off
capture log close _all
log using "test_fixture_tvc.log", text replace
args source
if "`source'"=="" local source=regexr("`c(pwd)'","/qa$","")
adopath ++ "`source'"
quietly do "_qa_fx_a2.do"
quietly do "_qa_state.do"
quietly run "`source'/cstat_surv.ado"
local tests=0
local pass=0
local fail=0
foreach tvc in default explicit {
    foreach va in on off {
        local ++tests
        capture noisily {
            qa_fx_a2_pwexp, clear model(weibull) n(240) seed(541)
            quietly stset t, failure(d) id(id)
            quietly stcox x1 x2, nolog
            assert `"`e(texp)'"'==""
            quietly cstat_surv
            assert !missing(e(c)) & e(N)==240
            * The fixture remains unchanged. The U operator is a model
            * route with a time-varying score, checked against native scope.
            local texopt ""
            if "`tvc'"=="explicit" local texopt "texp(log(_t))"
            quietly stcox x1 x2, tvc(x1) `texopt' nolog
            assert `"`e(texp)'"'!=""
            set varabbrev `va'
            tempfile errorlog
            log using "`errorlog'.log", text replace name(tvc_error)
            summarize t
            qa_state_snapshot, tag(tvc) rreturn predict(xb)
            * expect: REFUSED
            capture noisily cstat_surv
            local rc=_rc
            capture noisily qa_state_compare, tag(tvc)
            local fp_rc=_rc
            log close tvc_error
            mata: st_local("named",strofreal(any(strpos(strlower(cat(st_local("errorlog")+".log")),"does not support time-varying coefficients"))))
            display "TVC CONTRACT `tvc' va=`va' rc=`rc' fingerprint_rc=`fp_rc' named=`named'"
            assert `rc'==498 & `fp_rc'==0 & `named'==1
        }
        if _rc local ++fail
        else local ++pass
    }
}
display "RESULT: test_fixture_tvc tests=`tests' pass=`pass' fail=`fail' skip=0"
log close
if `fail' exit 9
