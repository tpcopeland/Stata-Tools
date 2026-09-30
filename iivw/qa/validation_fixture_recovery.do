*! validation_fixture_recovery.do — canonical F/U numerical contract for iivw
*! Author: Timothy P Copeland, Karolinska Institutet
version 16.0
clear all
set more off
set varabbrev off
capture log close _all
log using "validation_fixture_recovery.log", replace text nomsg
local qa_dir "`c(pwd)'"
local pkg_dir = regexr("`qa_dir'", "/qa$", "")
adopath ++ "`pkg_dir'"
do "`qa_dir'/_qa_fx_a3.do"
do "`qa_dir'/_qa_state.do"
local tests=0
local pass=0
local fail=0

**# Irregular visits: analytic full-data mean, predictable intensity slope
foreach seed in 931 932 {
    foreach op in friendly unsorted miss_irrelevant {
        local ++tests
        capture noisily {
            if "`op'"=="friendly" qa_fx_a3_visit, clear tier(recovery) n(1000) seed(`seed')
            else {
                * expect: EXACT
                qa_fx_a3_visit, clear tier(recovery) n(1000) seed(`seed') perturb(`op')
            }
            tempname mean B G
            scalar `mean'=r(truth_mean)
            matrix `B'=r(truth_outcome_b)
            matrix `G'=r(truth_visit_b)
            drop if !visit
            local wanted_N=_N
            iivw_fit y, unweighted id(id) time(time) timespec(linear) nolog
            scalar naive=_b[_cons]+4*_b[time]
            estimates store fx_naive
            iivw_weight, id(id) time(time) visit_cov(lag_y) maxfu(4) wtype(iivw) nolog
            tempname VG
            matrix `VG'=r(visit_b)
            di "ORACLE iivw visit coefficient=" `VG'[1,1] " target=" `G'[1,2]
            assert abs(`VG'[1,1]-`G'[1,2])<.1
            iivw_fit y, vce(fixed) timespec(linear) nolog
            assert e(N)==`wanted_N'
            estimates store fx_weighted
            lincom _cons+4*time
            di "ORACLE iivw target=" scalar(`mean') " weighted=" r(estimate) " SE=" r(se) " naive=" scalar(naive)
            assert !missing(r(estimate),r(se)) & abs(r(estimate)-scalar(`mean'))<4*r(se)
            assert abs(scalar(naive)-scalar(`mean'))>.2
            tempname EB
            matrix `EB'=e(b)
            iivw_fit
            assert !missing(mreldif(`EB',e(b))) & mreldif(`EB',e(b))==0
            quietly summarize _iivw_iw, meanonly
            scalar target_mean=r(mean)
            iivw_balance
            assert r(N)==`wanted_N'
            assert r(n_ids)==1000
            assert !missing(r(ess)) & r(ess)>0 & r(ess)<=`wanted_N'
            iivw_exogtest y, id(id) time(time) maxfu(4) nolog
            assert r(n_models)==1 & r(n_ids)==1000
            assert r(history_association_flag)==1 & r(min_p)<.001
        }
        local case_rc=_rc
        if `case_rc'==0 local ++pass
        else {
            local ++fail
            di as error "FAIL iivw `seed' `op' rc=`case_rc'"
        }
    }
}
di "RESULT: validation_fixture_recovery tests=`tests' pass=`pass' fail=`fail' skip=0"
log close _all
if `fail'>0 exit 1
