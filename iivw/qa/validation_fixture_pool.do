*! validation_fixture_pool.do — canonical VISIT bootstrap pooling arithmetic
*! Author: Timothy P Copeland, Karolinska Institutet
version 16.0
clear all
set more off
set varabbrev off
local qa_dir "`c(pwd)'"
local pkg_dir=regexr("`qa_dir'","/qa$","")
do "`qa_dir'/_iivw_qa_common.do"
iivw_qa_bootstrap
do "`qa_dir'/_qa_fx_a3.do"
do "`qa_dir'/_qa_state.do"

capture program drop _fx_pool
program define _fx_pool, rclass
    version 16.0
    args op
    tempfile draws
    tempname B V P BASIC W
    local tests=0
    local pass=0
    local fail=0
    drop if !visit
    iivw_weight, id(id) time(time) visit_cov(lag_y) maxfu(4) wtype(iivw) nolog
    * Fixed estimated nuisance weights: this tests pooling the actual draws,
    * not joint nuisance/outcome bootstrap inference or DGP coefficient recovery.
    iivw_fit y, timespec(linear) citype(percentile) vce(bootstrap, reps(20) seed(934) fixedweights) saving("`draws'", replace) nolog
    matrix `B'=e(b)
    assert "`: colnames `B''"=="time _cons"
    assert e(iivw_bs_reps_requested)==20 & e(iivw_bs_reps_completed)==20
    assert e(iivw_bs_reps_failed)==0
    estimates store fx_pool_anchor
    preserve
        use "`draws'", clear
        assert _N==20
        assert "`: char y_b_time[colname]'"=="time"
        assert "`: char y_b_cons[colname]'"=="_cons"
        assert "`: char y_b_time[coleq]'"=="y" & "`: char y_b_cons[coleq]'"=="y"
        assert !missing(y_b_time,y_b_cons)
        * Independent centered outer-product covariance of the saved draws.
        mata: X=st_data(.,("y_b_time","y_b_cons")); X=X:-mean(X); st_matrix("`V'",quadcross(X,X)/(rows(X)-1))
        mata: mata drop X
        matrix `P'=J(2,2,.)
        local drawvars "y_b_time y_b_cons"
        forvalues j=1/2 {
            local var : word `j' of `drawvars'
            sort `var'
            matrix `P'[1,`j']=`var'[1]
            matrix `P'[2,`j']=`var'[_N]
        }
    restore
    matrix `BASIC'=J(2,2,.)
    matrix `W'=J(2,2,.)
    forvalues j=1/2 {
        matrix `BASIC'[1,`j']=2*`B'[1,`j']-`P'[2,`j']
        matrix `BASIC'[2,`j']=2*`B'[1,`j']-`P'[1,`j']
        matrix `W'[1,`j']=`B'[1,`j']-invnormal(.975)*sqrt(`V'[`j',`j'])
        matrix `W'[2,`j']=`B'[1,`j']+invnormal(.975)*sqrt(`V'[`j',`j'])
    }
    foreach citype in wald percentile basic {
        local ++tests
        capture noisily {
            estimates restore fx_pool_anchor
            qa_state_snapshot, tag(pool_state)
            iivw_bspool using "`draws'", citype(`citype') reps(20) notable
            qa_state_compare, tag(pool_state) allow(e)
            assert !missing(mreldif(e(b),`B')) & mreldif(e(b),`B')==0
            assert !missing(mreldif(e(V),`V')) & mreldif(e(V),`V')<1e-12
            assert !missing(mreldif(e(iivw_ci_percentile),`P')) & mreldif(e(iivw_ci_percentile),`P')<1e-12
            assert !missing(mreldif(e(iivw_ci_basic),`BASIC')) & mreldif(e(iivw_ci_basic),`BASIC')<1e-12
            local wanted "`W'"
            if "`citype'"=="percentile" local wanted "`P'"
            if "`citype'"=="basic" local wanted "`BASIC'"
            assert !missing(mreldif(e(iivw_ci),`wanted')) & mreldif(e(iivw_ci),`wanted')<1e-12
            assert e(iivw_bs_reps_requested)==20 & e(iivw_bs_reps_completed)==20
            assert e(iivw_bs_reps_failed)==0 & e(iivw_bs_shards)==1
            di "ORACLE VISIT `op' pool `citype': exact B, centered-draw V, all interval cells"
        }
        local case_rc=_rc
        if `case_rc'==0 local ++pass
        else {
            local ++fail
            di as error "FAIL VISIT `op' pool `citype' rc=`case_rc'"
        }
    }
    return scalar tests=`tests'
    return scalar pass=`pass'
    return scalar fail=`fail'
end

local tests=0
local pass=0
local fail=0
qa_fx_a3_visit, clear tier(unit) seed(931)
_fx_pool friendly
local tests=`tests'+r(tests)
local pass=`pass'+r(pass)
local fail=`fail'+r(fail)
* expect: EXACT
qa_fx_a3_visit, clear tier(unit) seed(931) perturb(unsorted)
_fx_pool unsorted
local tests=`tests'+r(tests)
local pass=`pass'+r(pass)
local fail=`fail'+r(fail)
display "RESULT: validation_fixture_pool tests=`tests' pass=`pass' fail=`fail' skip=0"
iivw_qa_sandbox_restore
if `fail'>0 exit 1
