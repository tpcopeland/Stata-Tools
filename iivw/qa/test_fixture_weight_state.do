*! test_fixture_weight_state.do — native nuisance-fit state and late transaction rollback
*! Author: Timothy P Copeland, Karolinska Institutet
version 16.0
clear all
set more off
set varabbrev off
do _iivw_qa_common.do
iivw_qa_bootstrap
local pkg_dir=regexr("`c(pwd)'","/qa$","")
do _qa_fx_a3.do
do _qa_state.do
do _qa_metamorphic.do
* Bytewise copy of the actual source; one explicit late error after commit.
* The fault confirms the owned IW/final-weight columns exist before refusal.
capture mata: mata drop _fx_weight_fault_copy()
mata:
void _fx_weight_fault_copy(string scalar src,string scalar dst)
{
    real scalar fi,fo
    string matrix line
    fi=fopen(src,"r");fo=fopen(dst,"w")
    while(1) {
        line=fget(fi)
        if(rows(line)==0) break
        fput(fo,line)
        if(line=="    _iivw_weight_signature") {
            fput(fo,"    confirm variable _iivw_iw _iivw_weight")
            fput(fo,"    display as error " + char(34)+"INJECTED late owned-weight fault"+char(34))
            fput(fo,"    error 498")
        }
    }
    fclose(fi);fclose(fo)
}
end
tempfile broken
mata: _fx_weight_fault_copy(st_local("pkg_dir")+"/iivw_weight.ado",st_local("broken"))
capture program drop _fx_weight_state
program define _fx_weight_state, rclass
    version 16.0
    args op broken
    drop if !visit
    generate byte a=mod(floor((id-1)/2),2)
    tempfile original
    save `original'
    local tests=0
    local pass=0
    local fail=0
    tempname Raw
    unab origvars : _all
    mata: st_matrix("`Raw'",st_data(.,tokens(st_local("origvars"))))
    foreach status in absent present present_empty native {
        foreach route in success refusal {
            local ++tests
            capture noisily {
                use `original', clear
                capture macro drop S_1 S_2
                if "`status'"=="present" {
                    foreach key in S_1 S_2 {
                        mata: st_global(st_local("key"),char(36)+"OPAQUE"+char(34)+char(96)+"native"+char(39))
                    }
                }
                if "`status'"=="present_empty" {
                    global S_1 ""
                    global S_2 ""
                    mata: assert(sum(st_dir("global","macro","*"):=="S_1")==0)
                }
                if "`status'"=="native" ttest y==0
                if "`route'"=="success" {
                    qa_state_snapshot, tag(weight_state) charns(_iivw_)
                    iivw_weight, id(id) time(time) visit_cov(lag_y) maxfu(4) wtype(fiptiw) treat(a) treat_cov(u) nolog
                    assert r(N_weighted)==_N & r(n_ids_weighted)==100
                    assert abs(r(ps_prevalence)-.5)<1e-12
                    assert !missing(_iivw_ps,_iivw_tw,_iivw_weight,_iivw_iw)
                    assert abs(_iivw_ps-.5)<1e-10 & abs(_iivw_tw-1)<1e-10 & abs(_iivw_weight-_iivw_iw)<1e-10
                    qa_state_compare, tag(weight_state) allow(data)
                    unab nowvars : _all
                    local retained : list nowvars & origvars
                    assert "`retained'"=="`origvars'"
                    mata: assert(all(vec(st_data(.,tokens(st_local("origvars"))):==st_matrix("`Raw'"))))
                }
                else {
                    replace a=mod(id,2)
                    * Genuine perfect separation in the person-level PS model.
                    assert a==(u>0)
                    qa_state_snapshot, tag(weight_state)
                    tempfile cause
                    log using `cause', text name(weight_cause) replace
                    capture noisily iivw_weight, id(id) time(time) visit_cov(lag_y) maxfu(4) wtype(fiptiw) treat(a) treat_cov(u) nolog
                    local call_rc=_rc
                    log close weight_cause
                    assert `call_rc'==2000
                    mata: assert(_qa_mm_logfind(st_local("cause"),"treatment model failed; no weights created"))
                    mata: assert(!_qa_mm_logfind(st_local("cause"),"ROLLBACK FAILED"))
                    qa_state_compare, tag(weight_state)
                }
                use `original', clear
                quietly summarize y, meanonly
                local wantN=r(N)
                local wantmean=r(mean)
                ttest y==0
                assert r(N_1)==`wantN' & reldif(r(mu_1),`wantmean')<1e-12
                assert $S_1==`wantN' & reldif(real("$S_2"),`wantmean')<1e-12
                di "ORACLE VISIT weight `op' `status' `route': exact caller state and next native mean"
            }
            local rc=_rc
            if `rc'==0 local ++pass
            else {
                local ++fail
                di as error "FAIL VISIT weight state `op' `status' `route' rc=`rc'"
            }
        }
    }
    local ++tests
    capture noisily {
        use `original', clear
        capture program drop iivw_weight
        run `broken'
        qa_state_snapshot, tag(weight_late)
        tempfile cause
        log using `cause', text name(weight_cause) replace
        capture noisily iivw_weight, id(id) time(time) visit_cov(lag_y) maxfu(4) wtype(iivw) nolog
        local call_rc=_rc
        log close weight_cause
        assert `call_rc'==498
        mata: assert(_qa_mm_logfind(st_local("cause"),"INJECTED late owned-weight fault"))
        mata: assert(!_qa_mm_logfind(st_local("cause"),"ROLLBACK FAILED"))
        qa_state_compare, tag(weight_late)
        capture confirm variable _iivw_iw
        assert _rc==111
        capture confirm variable _iivw_weight
        assert _rc==111
        cf _all using `original', all
        di "ORACLE VISIT weight `op' late fault: owned columns were present, dropped, original input exact"
    }
    if _rc==0 local ++pass
    else local ++fail
    capture program drop iivw_weight
    return scalar tests=`tests'
    return scalar pass=`pass'
    return scalar fail=`fail'
end
local tests=0
local pass=0
local fail=0
qa_fx_a3_visit, clear tier(unit) n(100) seed(931)
_fx_weight_state friendly `broken'
local tests=`tests'+r(tests)
local pass=`pass'+r(pass)
local fail=`fail'+r(fail)
* expect: EXACT
qa_fx_a3_visit, clear tier(unit) n(100) seed(931) perturb(unsorted)
_fx_weight_state unsorted `broken'
local tests=`tests'+r(tests)
local pass=`pass'+r(pass)
local fail=`fail'+r(fail)
display "RESULT: test_fixture_weight_state tests=`tests' pass=`pass' fail=`fail' skip=0"
iivw_qa_sandbox_restore
if `fail'>0 exit 1
