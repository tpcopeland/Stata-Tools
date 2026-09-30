* test_fixture_weight_policies.do -- canonical separated weighting and explicit policies
* Author: Timothy P Copeland, Karolinska Institutet
* guard: clipping/fallback is a declared changed estimator, not positivity recovery.
version 16.0
clear all
set more off
set varabbrev off
set processors 1
set seed 9180
capture log close _all
local qa_dir "`c(pwd)'"
do "`qa_dir'/_install_msm_isolated.do" "`qa_dir'/.."
do "`qa_dir'/_qa_fx_a3.do"
do "`qa_dir'/_qa_state.do"
local test_count 0
local pass_count 0
local fail_count 0

* Compare every addressable native global independently of the broad state
* publication allowance. Only the documented package UUID may differ.
mata:
_fx_weight_globals=asarray_create("string",1)
void _fx_weight_global_snapshot() {
    external transmorphic scalar _fx_weight_globals
    string colvector names
    real scalar i
    _fx_weight_globals=asarray_create("string",1)
    names=st_dir("global","macro","*")
    for (i=1;i<=rows(names);i++) {
        if (!st_isname(names[i]) | names[i]=="MSM_UUID_SEQ") continue
        asarray(_fx_weight_globals,names[i],st_global(names[i]))
    }
}
void _fx_weight_global_compare() {
    external transmorphic scalar _fx_weight_globals
    string colvector names,expected,actual
    real scalar i
    names=st_dir("global","macro","*")
    actual=J(0,1,"")
    for (i=1;i<=rows(names);i++) {
        if (!st_isname(names[i]) | names[i]=="MSM_UUID_SEQ") continue
        actual=actual\names[i]
        assert(asarray_contains(_fx_weight_globals,names[i]))
        assert(asarray(_fx_weight_globals,names[i])==st_global(names[i]))
    }
    expected=asarray_keys(_fx_weight_globals)
    assert(rows(actual)==rows(expected))
}
end

capture program drop _fx_weight_setup
program define _fx_weight_setup
    args op order
    local perturb "`op'"
    if "`order'"=="unsorted" local perturb "`perturb' unsorted"
    local option ""
    if strtrim("`perturb'")!="" local option "perturb(`perturb')"
    qa_fx_a3_seq, clear n(1600) seed(9181) `option'
    gen long fx_row=_n
    local original_sort : sortedby
    capture confirm variable sep
    if _rc gen byte sep=0
    bysort id (period): gen double fx_sep_lag=cond(_n==1,0,sep*a[_n-1])
    sort fx_row
    if "`original_sort'"!="" sort `original_sort', stable
    local dcov "l_t"
    local prep_extra ""
    local weight_extra ""
    if "`op'"=="separate(switch)" local dcov "l_t sep fx_sep_lag"
    if "`op'"=="separate(censor)" {
        local prep_extra "censor(c)"
        local weight_extra "censor_d_cov(l_t sep)"
    }
    quietly msm_prepare, id(id) period(period) treatment(a) outcome(y) covariates(`dcov') `prep_extra'
    quietly regress l_t a l0
    mata: st_global("S_15", "foreign numbered " + char(36) + "bait " + char(96) + "tick" + char(39))
    mata: st_global("_fx_123", "foreign punctuation ; "+char(34))
    c_local dcov "`dcov'"
    c_local weight_extra "`weight_extra'"
end

capture program drop _fx_weight_audit
program define _fx_weight_audit
    args op
    matrix fx_audit=r(probability_repairs)
    local repairs=r(n_probability_repairs)
    local fallback=r(n_fitfail_fallback)
    local repair_sum=0
    local cols : colnames fx_audit
    assert "`cols'"=="model period cell N n_missing n_low n_high raw_min raw_max repaired_min repaired_max"
    forvalues row=1/`=rowsof(fx_audit)' {
        local model=fx_audit[`row',1]
        local t=fx_audit[`row',2]
        local cell=fx_audit[`row',3]
        local raw "_msm_treat_den_raw"
        local used "_msm_treat_den_p"
        local decision "a"
        if `model'==2 {
            local raw "_msm_treat_num_raw"
            local used "_msm_treat_num_p"
        }
        if `model'==3 {
            local raw "_msm_cens_den_raw"
            local used "_msm_cens_den_p"
            local decision "c"
        }
        if `model'==4 {
            local raw "_msm_cens_num_raw"
            local used "_msm_cens_num_p"
            local decision "c"
        }
        quietly count if _msm_decision_risk & period==`t' & `decision'==`cell'
        assert r(N)==fx_audit[`row',4]
        quietly count if _msm_decision_risk & period==`t' & `decision'==`cell' & missing(`raw')
        assert r(N)==fx_audit[`row',5]
        quietly count if _msm_decision_risk & period==`t' & `decision'==`cell' & !missing(`raw') & `raw'<.01
        assert r(N)==fx_audit[`row',6]
        quietly count if _msm_decision_risk & period==`t' & `decision'==`cell' & !missing(`raw') & `raw'>.99
        assert r(N)==fx_audit[`row',7]
        local repair_sum=`repair_sum'+fx_audit[`row',5]+fx_audit[`row',6]+fx_audit[`row',7]
        assert !missing(`used') & inrange(`used',.01,.99) if _msm_decision_risk & period==`t' & `decision'==`cell'
        assert `used'==min(max(`raw',.01),.99) if _msm_decision_risk & period==`t' & `decision'==`cell' & !missing(`raw')
        assert `used'==cond(`decision'==1,.99,.01) if _msm_decision_risk & period==`t' & `decision'==`cell' & missing(`raw')
    }
    assert !missing(`repairs') & `repairs'==`repair_sum'
    if "`op'"!="" assert `repairs'>0
    if "`op'"=="all_treated" {
        assert `fallback'==4
        assert _msm_weight==1
    }
    * Independent cumulative stabilized treatment/censor factors.
    gen double fx_factor=1
    replace fx_factor=cond(a==1,_msm_treat_num_p/_msm_treat_den_p,(1-_msm_treat_num_p)/(1-_msm_treat_den_p)) if _msm_decision_risk
    if "`op'"=="separate(censor)" replace fx_factor=fx_factor*(1-_msm_cens_num_p)/(1-_msm_cens_den_p) if _msm_decision_risk
    bysort id (period): gen double fx_expected=exp(sum(ln(fx_factor)))
    assert !missing(_msm_weight,fx_expected) & reldif(_msm_weight,fx_expected)<1e-12
    sort fx_row
    drop fx_factor fx_expected
end

foreach order in friendly unsorted {
    **# F/U: preview returns exact resolved specification without data/estimate mutation
    * expect: INVARIANT under shuffled row order
    local ++test_count
    capture noisily {
        _fx_weight_setup "" "`order'"
        qa_state_snapshot, tag(weightpreview) predict(xb stdp)
        quietly msm_weight, preview truncate(1)
        qa_state_compare, tag(weightpreview)
        assert "`r(preview)'"=="1"
        assert "`r(treat_d_cov)'"=="l_t" & "`r(treat_d_cov_source)'"=="prepared"
        assert "`r(truncate)'"=="1 99" & "`r(fitfailure_policy)'"=="error"
        assert "`r(probability_policy)'"=="error"
        capture confirm variable _msm_weight
        assert _rc==111
    }
    if !_rc {
        local ++pass_count
        display as result "PASS: preview/`order'"
    }
    else {
        local ++fail_count
        display as error "FAIL: preview/`order' (rc=`=_rc')"
    }
    foreach op in ordinary all_treated separate(switch) separate(censor) {
        local perturb "`op'"
        if "`op'"=="ordinary" local perturb ""
        **# F/U: explicit clipping with direct probability ledger and product weights
        * expect: SHIFTED for structural operators under declared clip/fallback; no positivity claim
        local ++test_count
        capture noisily {
            _fx_weight_setup "`perturb'" "`order'"
            * Success intentionally creates package data/matrices/chars and UUID;
            * e(), native prediction, RNG/settings/order remain strict.
            qa_state_snapshot, tag(weightfit) predict(xb stdp) charns(_msm_)
            mata: _fx_weight_global_snapshot()
            quietly msm_weight, treat_d_cov(`dcov') `weight_extra' fitfailure(marginal) probpolicy(clip) clip(.01) nolog
            mata: _fx_weight_global_compare()
            qa_state_compare, tag(weightfit) allow(data matrix global label)
            assert "`r(probability_policy)'"=="clip" & "`r(fitfailure_policy)'"=="marginal"
            assert r(clip_threshold)==.01
            _fx_weight_audit "`perturb'"
        }
        if !_rc {
            local ++pass_count
            display as result "PASS: clip `op'/`order'"
        }
        else {
            local ++fail_count
            display as error "FAIL: clip `op'/`order' (rc=`=_rc')"
        }
        if "`op'"!="ordinary" {
            **# U: default policy refuses actual structural failure without caller changes
            * expect: REFUSED; no implicit marginal substitution or clipping
            local ++test_count
            capture noisily {
                _fx_weight_setup "`perturb'" "`order'"
                tempfile refusal
                capture log close fxref
                log using "`refusal'", text name(fxref)
                qa_state_snapshot, tag(weightrefusal) rreturn predict(xb stdp)
                capture noisily msm_weight, treat_d_cov(`dcov') `weight_extra' nolog
                local command_rc=_rc
                qa_state_compare, tag(weightrefusal)
                log close fxref
                local expected_rc=459
                local cause "probability(ies) are missing after estimation"
                if "`op'"=="all_treated" {
                    local expected_rc=498
                    local cause "Treatment denominator model failed"
                }
                assert `command_rc'==`expected_rc'
                python: assert __import__('sfi').Macro.getLocal('cause') in open(__import__('sfi').Macro.getLocal('refusal'),encoding='utf-8').read()
            }
            if !_rc {
                local ++pass_count
                display as result "PASS: refused `op'/`order'"
            }
            else {
                local ++fail_count
                display as error "FAIL: refused `op'/`order' (rc=`=_rc')"
                capture log close fxref
            }
        }
    }
}

python:
from pathlib import Path
from sfi import Macro
import types,sys
def save():
    source=Path(Macro.getLocal('qa_dir')+'/../_msm_own.ado').read_text()
    source=source.replace('program define _msm_own, rclass','program define _fx_native_own, rclass',1)
    Path(Macro.getLocal('native_source')).write_text(source)
    tick,quote=chr(96),chr(39)
    fault='program define _msm_own, rclass\ngettoken action rest : 0\n'
    fault+='if "'+tick+'action'+quote+'"=="claim" {\n'
    fault+='display as error "planted weighting persistence failure"\nexit 603\n}\n'
    fault+='_fx_native_own '+tick+'0'+quote+'\nreturn add\nend\n'
    Path(Macro.getLocal('fault_source')).write_text(fault)
m=types.ModuleType('_qa_msm_weight_fault');m.save=save;sys.modules['_qa_msm_weight_fault']=m
end

foreach cell in empty_success opaque_success empty_early opaque_late {
    **# U: genuine empty/opaque caller contexts and error after identifier allocation
    * expect: INVARIANT for active estimates/context; REFUSED with full state on errors
    local ++test_count
    capture noisily {
        _fx_weight_setup "" "unsorted"
        if strpos("`cell'","empty") {
            ereturn clear
            capture macro drop S_E_cmd
            global S_E_depv ""
        }
        else {
            mata: st_global("S_E_cmd", "literal " + char(36) + "bait " + char(96) + "tick" + char(39))
            global S_E_depv ""
        }
        local entry_gnames : all globals
        local dep_key "S_E_depv"
        local expected_dep_present : list dep_key in entry_gnames
        if "`cell'"=="opaque_late" {
            * Delegate native ownership checks but fail claim after UUID allocation.
            tempfile native_source fault_source
            python: __import__('_qa_msm_weight_fault').save()
            capture program drop _fx_native_own
            run "`native_source'"
            capture program drop _msm_own
            run "`fault_source'"
        }
        if strpos("`cell'","success") {
            qa_state_snapshot, tag(weightcontext) predict(xb stdp) charns(_msm_)
            mata: _fx_weight_global_snapshot()
            quietly msm_weight, treat_d_cov(l_t) nolog
            mata: _fx_weight_global_compare()
            qa_state_compare, tag(weightcontext) allow(data matrix global label)
            assert !missing(r(ess)) & r(ess)>0
            assert "`r(weight_var)'"=="_msm_weight" & r(n_probability_repairs)==0
            if "`cell'"=="empty_success" {
                local enames : e(macros)
                local escalars : e(scalars)
                local ematrices : e(matrices)
                assert "`enames'`escalars'`ematrices'"==""
            }
            else {
                mata: assert(st_global("S_E_cmd")=="literal " + char(36) + "bait " + char(96) + "tick" + char(39))
            }
            local gnames : all globals
            local key "S_E_depv"
            local actual_dep_present : list key in gnames
            assert `actual_dep_present'==`expected_dep_present'
            mata: assert(st_global("S_E_depv")=="")
        }
        else {
            tempfile refusal
            capture log close fxref
            log using "`refusal'", text name(fxref)
            qa_state_snapshot, tag(weightcontext) rreturn predict(xb stdp)
            local options "treat_d_cov(l_t) nolog"
            if "`cell'"=="empty_early" local options "`options' clip(.01)"
            capture noisily msm_weight, `options'
            local command_rc=_rc
            qa_state_compare, tag(weightcontext)
            log close fxref
            local expected_rc=603
            local cause "planted weighting persistence failure"
            if "`cell'"=="empty_early" {
                local expected_rc=198
                local cause "clip() requires probpolicy(clip)"
            }
            assert `command_rc'==`expected_rc'
            python: assert __import__('sfi').Macro.getLocal('cause') in open(__import__('sfi').Macro.getLocal('refusal'),encoding='utf-8').read()
        }
    }
    if !_rc {
        local ++pass_count
        display as result "PASS: caller context `cell'"
    }
    else {
        local ++fail_count
        display as error "FAIL: caller context `cell' (rc=`=_rc')"
        capture log close fxref
    }
    capture program drop _msm_own
    capture program drop _fx_native_own
}
do "`qa_dir'/_record_qa_result.do" test_fixture_weight_policies `test_count' `pass_count' `fail_count' 0
display "RESULT: test_fixture_weight_policies tests=`test_count' pass=`pass_count' fail=`fail_count'"
capture log close _all
if `fail_count'>0 exit 1
