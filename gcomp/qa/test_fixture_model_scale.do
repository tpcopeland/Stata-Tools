* test_fixture_model_scale.do -- native parser and fitted component scales
* Author: Timothy P Copeland, Karolinska Institutet
* guard: native regress estimates supply coefficient identities; refusal state is strict.
version 16.0
clear all
set more off
set varabbrev off
set processors 1
capture log close _all
local qa_dir "`c(pwd)'"
do "`qa_dir'/_qa_bootstrap.do"
do "`qa_dir'/_qa_fx_a1.do"
do "`qa_dir'/_qa_state.do"
run "`qa_dir'/../gcomptab.ado"
local test_count 0
local pass_count 0
local fail_count 0
foreach route in public direct {
    foreach mode in default eform noeform raw raw_eform both_forward both_reverse internal unknown {
        **# F/U: affirmative, negative, default, raw precedence and genuine parse refusals
        * expect: EXACT for supported scales; REFUSED for conflicting/unknown syntax
        local ++test_count
        capture noisily {
            qa_fx_a1_gauss, clear n(3600) seed(9147)
            quietly regress y a x1 x2
            matrix fx_scale_b=e(b)
            matrix fx_scale_V=e(V)
            estimates store fixture_scale
            local call "gcomptab"
            local models "models"
            if "`route'"=="direct" {
                local call "_gcomptab_models"
                local models ""
            }
            local opt ""
            if inlist("`mode'","eform","noeform","raw") local opt "`mode'"
            if "`mode'"=="raw_eform" local opt "raw eform"
            if "`mode'"=="both_forward" local opt "eform noeform"
            if "`mode'"=="both_reverse" local opt "noeform eform"
            if "`mode'"=="internal" local opt "NOEFORM_seen"
            if "`mode'"=="unknown" local opt "unknown"
            tempfile output
            capture log close _all
            log using "`output'", text replace name(scale_case)
            qa_state_snapshot, tag(modelscale) predict(xb stdp)
            capture noisily `call', `models' usemodels(fixture_scale) keepintercept display decimal(6) `opt' title("eform noeform NOEFORM_seen unknown")
            local rc=_rc
            qa_state_compare, tag(modelscale)
            if inlist("`mode'","both_forward","both_reverse","internal","unknown") {
                assert `rc'==198
                log close scale_case
                if inlist("`mode'","both_forward","both_reverse") {
                    python: assert 'eform and noeform are mutually exclusive' in __import__('pathlib').Path(__import__('sfi').Macro.getLocal('output')).read_text()
                }
                else {
                    python: assert 'not allowed' in __import__('pathlib').Path(__import__('sfi').Macro.getLocal('output')).read_text()
                }
            }
            else {
                assert `rc'==0
                matrix fx_scale_table=r(table)
                local terms "`r(term_names)'"
                local n : word count `terms'
                assert `n'==colsof(fx_scale_b) & r(N_models)==1
                forvalues i=1/`n' {
                    local term : word `i' of `terms'
                    local j=colnumb(fx_scale_b,"`term'")
                    assert !missing(`j',fx_scale_table[`i',1],fx_scale_b[1,`j'])
                    local expected=cond("`mode'"=="eform",exp(fx_scale_b[1,`j']),fx_scale_b[1,`j'])
                    assert abs(fx_scale_table[`i',1]-`expected')<1e-12
                }
                assert !missing(mreldif(e(b),fx_scale_b)) & mreldif(e(b),fx_scale_b)==0
                assert !missing(mreldif(e(V),fx_scale_V)) & mreldif(e(V),fx_scale_V)==0
                log close scale_case
                python: assert 'eform noeform NOEFORM_seen unknown' in __import__('pathlib').Path(__import__('sfi').Macro.getLocal('output')).read_text()
            }
            erase "`output'"
            estimates drop fixture_scale
        }
        local rc=_rc
        capture log close _all
        if !`rc' {
            local ++pass_count
            display as result "PASS: `route' `mode' native scale/parser/state"
        }
        else {
            local ++fail_count
            display as error "FAIL: `route' `mode' (rc=`rc')"
        }
    }
}
if `fail_count' > 0 {
    display "RESULT: test_fixture_model_scale tests=`test_count' pass=`pass_count' fail=`fail_count' status=FAIL"
    capture log close _all
    exit 1
}
else {
    display "RESULT: test_fixture_model_scale tests=`test_count' pass=`pass_count' fail=`fail_count' status=PASS"
    capture log close _all
}
