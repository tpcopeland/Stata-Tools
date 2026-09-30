* test_fixture_table_refusals.do -- genuine and planted writer refusal transactions
* Author: Timothy P Copeland, Karolinska Institutet
* guard: all caller r collections are strict; late fault happens before any export.
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
local test_count 0
local pass_count 0
local fail_count 0
capture program drop _fx_writer_caller_r
program define _fx_writer_caller_r, rclass
    args kind
    return clear
    if "`kind'"=="full" {
        tempname rm
        matrix `rm'=(17/120,49/120\11/20,1)
        mata: st_local("opaque", "literal " + char(36) + "bait " + char(96) + "tick" + char(39) + " " + char(34) + "quote" + char(34))
        return scalar foreign_s=17/120
        return local foreign_text `"`macval(opaque)'"'
        return matrix foreign_m=`rm'
    }
end
foreach route in public direct {
    foreach phase in early late {
        foreach context in empty full {
            **# U: early and after-native-fit-extraction error-only transactions
            * expect: REFUSED with exact full caller state and original cause
            local ++test_count
            capture noisily {
                qa_fx_a1_gauss, clear n(3600) seed(9191) perturb(unsorted)
                quietly regress y a x1 x2 i.xcat
                estimates store fixture_writer
                run "`qa_dir'/../gcomptab.ado"
                local call "gcomptab"
                local models "models"
                if "`route'"=="direct" {
                    local call "_gcomptab_models"
                    local models ""
                }
                local opts "decimal(0) display"
                local cause "decimal()/digits() must be between 1 and 6"
                local expected_rc=198
                tempfile csv refusal
                local csv "`csv'.csv"
                if "`phase'"=="late" {
                    * Actual helper boundary after estimate extraction, held e
                    * and (direct route) temporary text frame creation.
                    tempfile fault_source
                    file open fx_fault using "`fault_source'", write text replace
                    file write fx_fault "capture program drop _gcomptab_text_export" _n
                    file write fx_fault "program define _gcomptab_text_export, rclass" _n
                    file write fx_fault "return scalar fault_marker=1" _n
                    file write fx_fault `"display as error "planted table serialization failure""' _n
                    file write fx_fault "exit 603" _n "end" _n
                    file close fx_fault
                    run "`fault_source'"
                    local opts "decimal(6) csv(`csv')"
                    local cause "planted table serialization failure"
                    local expected_rc=603
                }
                capture log close fxref
                log using "`refusal'", text name(fxref)
                _fx_writer_caller_r "`context'"
                qa_state_snapshot, tag(tablerefusal) rreturn predict(xb stdp)
                capture noisily `call', `models' usemodels(fixture_writer) keepintercept `opts'
                local command_rc=_rc
                qa_state_compare, tag(tablerefusal)
                log close fxref
                assert `command_rc'==`expected_rc'
                python: assert not __import__('pathlib').Path(__import__('sfi').Macro.getLocal('csv')).exists()
                python: assert __import__('sfi').Macro.getLocal('cause') in open(__import__('sfi').Macro.getLocal('refusal'),encoding='utf-8').read()
            }
            if !_rc {
                local ++pass_count
                display as result "PASS: `route'/`phase'/`context' full refusal transaction"
            }
            else {
                local ++fail_count
                display as error "FAIL: `route'/`phase'/`context' (rc=`=_rc')"
                capture log close fxref
            }
        }
    }
}
foreach order in friendly unsorted {
    foreach context in empty full {
        **# U: real fitted OCE output is a documented unsupported table route
        * expect: REFUSED naming unsupported OCE; no partial workbook/text export or state changes
        local ++test_count
        capture noisily {
            local perturb ""
            if "`order'"=="unsorted" local perturb "perturb(unsorted)"
            qa_fx_a1_gauss, clear n(3600) seed(9191) `perturb'
            run "`qa_dir'/../gcomptab.ado"
            quietly gcomp y x2 xcat a x1, outcome(y) mediation oce baseline(1) control(0) ///
                exposure(xcat) mediator(x2) commands(x2: logit,y: regress) ///
                equations(x2: i.xcat a x1,y: x2 i.xcat a x1) base_confs(a x1) ///
                sim(12000) samples(6) seed(9192) minsim moreMC
            assert e(N)==3600 & "`e(mediation_type)'"=="oce"
            matrix fx_oce_b=e(b)
            assert colsof(fx_oce_b)==10
            foreach term in tce_1 tce_2 nde_1 nde_2 nie_1 nie_2 pm_1 pm_2 cde_1 cde_2 {
                local j=colnumb(fx_oce_b,"`term'")
                assert !missing(`j',fx_oce_b[1,`j'])
            }
            tempfile csv md book refusal
            local csv "`csv'.csv"
            local md "`md'.md"
            local book "`book'.xlsx"
            capture log close fxref
            log using "`refusal'", text name(fxref)
            _fx_writer_caller_r "`context'"
            qa_state_snapshot, tag(ocerefusal) rreturn
            capture noisily gcomptab, xlsx("`book'") sheet("OCE") csv("`csv'") markdown("`md'")
            local command_rc=_rc
            qa_state_compare, tag(ocerefusal)
            log close fxref
            assert `command_rc'==198
            python: assert all(not __import__('pathlib').Path(__import__('sfi').Macro.getLocal(k)).exists() for k in ('csv','md','book'))
            python: assert 'gcomptab does not support oce mediation results' in open(__import__('sfi').Macro.getLocal('refusal'),encoding='utf-8').read()
        }
        if !_rc {
            local ++pass_count
            display as result "PASS: OCE/`order'/`context' named no-export refusal"
        }
        else {
            local ++fail_count
            display as error "FAIL: OCE/`order'/`context' (rc=`=_rc')"
            capture log close fxref
        }
    }
}
if `fail_count'>0 {
    display "RESULT: test_fixture_table_refusals tests=`test_count' pass=`pass_count' fail=`fail_count' status=FAIL"
    capture log close _all
    exit 1
}
else {
    display "RESULT: test_fixture_table_refusals tests=`test_count' pass=`pass_count' fail=`fail_count' status=PASS"
    capture log close _all
}
