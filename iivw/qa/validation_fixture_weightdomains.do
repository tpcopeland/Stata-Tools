*! validation_fixture_weightdomains.do — canonical visit/treatment component domains
*! Author: Timothy P Copeland, Karolinska Institutet
version 16.0
clear all
set more off
set varabbrev off
do _iivw_qa_common.do
iivw_qa_bootstrap
do _qa_fx_a3.do
do _qa_metamorphic.do
capture program drop _fx_visit_weightdomains
program define _fx_visit_weightdomains, rclass
    version 16.0
    args op
    drop if !visit
    * Explicit person-level treatment adapter: equal alternating ID pairs in each
    * canonical u stratum. The fitted finite propensity is exactly one half.
    generate byte a=mod(floor((id-1)/2),2)
    tempfile source
    generate double risk_entry=-.1
    save `source'
    local tests=0
    local pass=0
    local fail=0
    foreach wtype in iivw iptw fiptiw {
        local ++tests
        capture noisily {
            use `source', clear
            local opts ""
            if "`wtype'"!="iivw" local opts "treat(a) treat_cov(u)"
            local end "maxfu(4)"
            if "`wtype'"=="iptw" local end ""
            iivw_weight, id(id) time(time) visit_cov(lag_y) `end' wtype(`wtype') `opts' nolog
            assert r(n_ids_total)==100 & r(N_weighted)==_N
            if "`wtype'"!="iivw" {
                assert abs(r(ps_prevalence)-.5)<1e-12
                assert !missing(_iivw_ps,_iivw_tw) & abs(_iivw_ps-.5)<1e-10 & abs(_iivw_tw-1)<1e-10
            }
            if "`wtype'"=="iptw" assert abs(_iivw_weight-1)<1e-10
            else assert !missing(_iivw_weight,_iivw_iw) & abs(_iivw_weight-_iivw_iw)<1e-10
            quietly summarize _iivw_weight, meanonly
            assert abs(r(mean)-1)<1e-10
            di "ORACLE VISIT `op' `wtype': every stabilized PS/component/product row exact"
        }
        local rc=_rc
        if `rc'==0 local ++pass
        else {
            local ++fail
            di as error "FAIL VISIT weight `op' `wtype' rc=`rc'"
        }
    }
    foreach baseline in entry event {
        local ++tests
        capture noisily {
            use `source', clear
            * Baseline event needs predictable risk at the first observed time.
            * Explicitly adapt lag_y there to the observed person's u+2, without
            * borrowing any original fixture population truth for this adapter.
            bysort id (time): replace lag_y=u+2 if _n==1
            iivw_weight, id(id) time(time) visit_cov(lag_y) maxfu(4) entry(risk_entry) baseline(`baseline') nolog
            assert r(nobaseevent)==("`baseline'"=="entry")
            assert r(n_ids_weighted)==100 & r(N_weighted)==_N
            assert !missing(_iivw_weight) & _iivw_weight>0
            quietly summarize _iivw_iw, meanonly
            assert abs(r(mean)-1)<1e-10
        }
        if _rc==0 local ++pass
        else local ++fail
    }
    use `source', clear
    bysort id (time): replace lag_y=u+2 if _n==1
    local ++tests
    capture noisily {
        * expect: EXACT
        qa_option_domain, command(iivw_weight, id(id) time(time) visit_cov(lag_y) maxfu(4) wtype(@v@) treat(a) treat_cov(u) nolog) inside(iivw;fiptiw) outside(bad)
    }
    if _rc==0 local ++pass
    else local ++fail
    local ++tests
    capture noisily {
        * expect: EXACT
        qa_option_domain, command(iivw_weight, id(id) time(time) visit_cov(lag_y) maxfu(4) entry(risk_entry) baseline(@v@) nolog) inside(entry;event) outside(bad)
    }
    if _rc==0 local ++pass
    else local ++fail
    local ++tests
    capture noisily {
        * IPTW has no visit-risk process, so follow-up options are omitted.
        qa_option_domain, command(iivw_weight, id(id) time(time) wtype(@v@) treat(a) treat_cov(u) nolog) inside(iptw) outside(bad)
    }
    if _rc==0 local ++pass
    else local ++fail
    return scalar tests=`tests'
    return scalar pass=`pass'
    return scalar fail=`fail'
end
local tests=0
local pass=0
local fail=0
qa_fx_a3_visit, clear tier(unit) n(100) seed(931)
_fx_visit_weightdomains friendly
local tests=`tests'+r(tests)
local pass=`pass'+r(pass)
local fail=`fail'+r(fail)
* expect: EXACT
qa_fx_a3_visit, clear tier(unit) n(100) seed(931) perturb(unsorted)
_fx_visit_weightdomains unsorted
local tests=`tests'+r(tests)
local pass=`pass'+r(pass)
local fail=`fail'+r(fail)
display "RESULT: validation_fixture_weightdomains tests=`tests' pass=`pass' fail=`fail' skip=0"
iivw_qa_sandbox_restore
if `fail'>0 exit 1
