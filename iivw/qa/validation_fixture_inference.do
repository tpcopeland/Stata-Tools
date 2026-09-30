*! validation_fixture_inference.do — finite bootstrap draw/interval arithmetic and stream domains
*! Author: Timothy P Copeland, Karolinska Institutet
version 16.0
clear all
set more off
set varabbrev off
do _iivw_qa_common.do
iivw_qa_bootstrap
do _qa_fx_a3.do
do _qa_state.do
do _qa_metamorphic.do
capture program drop _fx_pool_domain
program define _fx_pool_domain
    version 16.0
    args B V draws
    tempname C
    local level=e(level)
    local kind "`e(iivw_ci_type)'"
    assert inlist(`level',80,95) & inlist("`kind'","wald-normal","percentile","basic")
    assert mreldif(e(b),`B')==0 & mreldif(e(V),`V')<1e-12
    matrix `C'=J(2,2,.)
    preserve
        use `draws', clear
        assert _N==20
        local vars y_b_time y_b_cons
        forvalues j=1/2 {
            local var : word `j' of `vars'
            sort `var'
            if `level'==95 {
                matrix `C'[1,`j']=`var'[1]
                matrix `C'[2,`j']=`var'[20]
            }
            else {
                matrix `C'[1,`j']=(`var'[2]+`var'[3])/2
                matrix `C'[2,`j']=(`var'[18]+`var'[19])/2
            }
        }
    restore
    forvalues j=1/2 {
        if "`kind'"=="basic" {
            local upper=`C'[2,`j']
            matrix `C'[2,`j']=2*`B'[1,`j']-`C'[1,`j']
            matrix `C'[1,`j']=2*`B'[1,`j']-`upper'
        }
        if "`kind'"=="wald-normal" {
            matrix `C'[1,`j']=`B'[1,`j']-invnormal(1-(1-`level'/100)/2)*sqrt(`V'[`j',`j'])
            matrix `C'[2,`j']=`B'[1,`j']+invnormal(1-(1-`level'/100)/2)*sqrt(`V'[`j',`j'])
        }
    }
    assert mreldif(e(iivw_ci),`C')<1e-12
end
capture program drop _fx_inference
program define _fx_inference, rclass
    version 16.0
    args op
    drop if !visit
    iivw_weight, id(id) time(time) visit_cov(lag_y) maxfu(4) nolog
    tempfile draws
    tempname B V P BASIC W R
    local tests=0
    local pass=0
    local fail=0
    foreach level in 80 95 {
        foreach stream in 1 32768 {
            local ++tests
            capture noisily {
                local caller_rng "`c(rng)'"
                local caller_state `"`c(rngstate)'"'
                iivw_fit y, timespec(linear) level(`level') citype(percentile) vce(bootstrap, reps(20) seed(934) fixedweights) rngstream(`stream') saving("`draws'", replace) nolog
                assert "`c(rng)'"=="`caller_rng'" & `"`c(rngstate)'"'==`"`caller_state'"'
                assert e(iivw_bs_reps_completed)==20 & e(iivw_bs_reps_failed)==0
                assert "`e(iivw_rng)'"=="mt64s" & real("`e(iivw_rngstream)'")==`stream'
                matrix `B'=e(b)
                estimates store fx_inference
                preserve
                    use `draws', clear
                    assert _N==20 & !missing(y_b_time,y_b_cons)
                    assert "`: char y_b_time[colname]'"=="time" & "`: char y_b_cons[colname]'"=="_cons"
                    mata: X=st_data(.,("y_b_time","y_b_cons"));X=X:-mean(X);st_matrix("`V'",quadcross(X,X)/19)
                    mata: mata drop X
                    matrix `P'=J(2,2,.)
                    local vars y_b_time y_b_cons
                    forvalues j=1/2 {
                        local var : word `j' of `vars'
                        sort `var'
                        if `level'==95 {
                            matrix `P'[1,`j']=`var'[1]
                            matrix `P'[2,`j']=`var'[20]
                        }
                        else {
                            * Official [D]pctile p11 default empirical inverse:
                            * integer N*p ranks average the two adjacent rows.
                            matrix `P'[1,`j']=(`var'[2]+`var'[3])/2
                            matrix `P'[2,`j']=(`var'[18]+`var'[19])/2
                        }
                    }
                restore
                matrix `BASIC'=J(2,2,.)
                matrix `W'=J(2,2,.)
                forvalues j=1/2 {
                    matrix `BASIC'[1,`j']=2*`B'[1,`j']-`P'[2,`j']
                    matrix `BASIC'[2,`j']=2*`B'[1,`j']-`P'[1,`j']
                    matrix `W'[1,`j']=`B'[1,`j']-invnormal(1-(1-`level'/100)/2)*sqrt(`V'[`j',`j'])
                    matrix `W'[2,`j']=`B'[1,`j']+invnormal(1-(1-`level'/100)/2)*sqrt(`V'[`j',`j'])
                }
                assert mreldif(e(V),`V')<1e-12 & mreldif(e(iivw_ci),`P')<1e-12
                di "ORACLE VISIT `op' bootstrap level`level' stream`stream': exact20draw V/percentile and caller generator/state"
            }
            local rc=_rc
            if `rc'==0 local ++pass
            else {
                local ++fail
                di as error "FAIL VISIT inference `op' level`level' stream`stream' rc=`rc'"
            }
            if `rc'==0 {
                foreach citype in wald percentile basic {
                    local ++tests
                    capture noisily {
                        estimates restore fx_inference
                        qa_state_snapshot, tag(inference_pool)
                        iivw_bspool using `draws', citype(`citype') level(`level') reps(20) notable
                        qa_state_compare, tag(inference_pool) allow(e)
                        local expected "`W'"
                        if "`citype'"=="percentile" local expected "`P'"
                        if "`citype'"=="basic" local expected "`BASIC'"
                        assert mreldif(e(b),`B')==0 & mreldif(e(V),`V')<1e-12
                        assert mreldif(e(iivw_ci),`expected')<1e-12
                    }
                    if _rc==0 local ++pass
                    else local ++fail
                }
            }
        }
    }
    local ++tests
    capture noisily {
        qa_option_domain, command(iivw_bspool using `draws', citype(@v@) level(95) reps(20) notable) inside(wald;percentile;basic) outside(bad) setup(estimates restore fx_inference) check(_fx_pool_domain `B' `V' `draws')
    }
    if _rc==0 local ++pass
    else local ++fail
    local ++tests
    capture noisily {
        qa_option_domain, command(iivw_bspool using `draws', citype(wald) level(@v@) reps(20) notable) inside(80;95) outside(9;100) setup(estimates restore fx_inference) check(_fx_pool_domain `B' `V' `draws')
    }
    if _rc==0 local ++pass
    else local ++fail
    local ++tests
    capture noisily {
        qa_option_domain, command(iivw_fit y, timespec(linear) vce(bootstrap, reps(20) seed(934) fixedweights) rngstream(@v@) nolog) inside(1;32768) outside(0;32769)
    }
    if _rc==0 local ++pass
    else local ++fail
    local ++tests
    capture noisily {
        qa_option_domain, command(iivw_fit y, timespec(linear) bootstrap(@v@) nolog) inside(2;20) outside(-1)
    }
    if _rc==0 local ++pass
    else local ++fail
    capture estimates drop fx_inference
    return scalar tests=`tests'
    return scalar pass=`pass'
    return scalar fail=`fail'
end
local tests=0
local pass=0
local fail=0
qa_fx_a3_visit, clear tier(unit) n(100) seed(931)
_fx_inference friendly
local tests=`tests'+r(tests)
local pass=`pass'+r(pass)
local fail=`fail'+r(fail)
* expect: EXACT
qa_fx_a3_visit, clear tier(unit) n(100) seed(931) perturb(unsorted)
_fx_inference unsorted
local tests=`tests'+r(tests)
local pass=`pass'+r(pass)
local fail=`fail'+r(fail)
display "RESULT: validation_fixture_inference tests=`tests' pass=`pass' fail=`fail' skip=0"
iivw_qa_sandbox_restore
if `fail'>0 exit 1
