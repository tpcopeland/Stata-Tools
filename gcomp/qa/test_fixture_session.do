* test_fixture_session.do -- canonical early/late gcomp refusal session boundaries
* Author: Timothy P Copeland, Karolinska Institutet
* guard: late fault occurs after native draws and reverses strict mode before error.
version 16.0
clear all
set more off
set varabbrev off
set processors 1
capture log close _all
local qa_dir "`c(pwd)'"
do "`qa_dir'/_qa_bootstrap.do"
do "`qa_dir'/_qa_fx_a1.do"
do "`qa_dir'/_qa_fx_a3.do"
do "`qa_dir'/_qa_state.do"
local test_count 0
local pass_count 0
local fail_count 0
capture program drop _fx_gc_caller_r
program define _fx_gc_caller_r, rclass
    args context
    return clear
    if "`context'"=="full" {
        tempname rm
        matrix `rm'=(17/120,49/120\11/20,1)
        mata: st_local("opaque", "literal " + char(36) + "bait " + char(96) + "tick" + char(39) + " " + char(34) + "quote" + char(34))
        return scalar foreign_s=17/120
        return local foreign_text `"`macval(opaque)'"'
        return matrix foreign_m=`rm'
    }
end
python:
from pathlib import Path
from sfi import Macro
import types,sys
def source():
    s=Path(Macro.getLocal('qa_dir')+'/../_gcomp_draw_sim.ado').read_text()
    s=s.replace('program define _gcomp_draw_sim, rclass','program define _fx_native_draw, rclass',1)
    s=s.replace('capture program drop _gcomp_draw_sim','capture program drop _fx_native_draw',1)
    Path(Macro.getLocal('native_source')).write_text(s)
    tick,quote=chr(96),chr(39)
    f='capture program drop _gcomp_draw_sim\nprogram define _gcomp_draw_sim, rclass\n'
    f+='local entry_rng '+tick+'"'+tick+'c(rngstate)'+quote+'"'+quote+'\n'
    f+='_fx_native_draw '+tick+'0'+quote+'\nreturn add\n'
    f+='mata: assert(st_global("c(rngstate)")!=st_local("entry_rng"))\n'
    f+='local altered "on"\nif "'+tick+'c(matastrict)'+quote+'"=="on" local altered "off"\n'
    f+='set matastrict '+tick+'altered'+quote+'\n'
    f+='display as error "planted gcomp after-draw strict-mode failure"\nexit 603\nend\n'
    Path(Macro.getLocal('fault_source')).write_text(f)
m=types.ModuleType('_qa_gc_session');m.source=source;sys.modules['_qa_gc_session']=m
end
foreach strict in off on {
    foreach phase in duplicate single_period late {
        foreach context in empty full {
            **# U: cold structural refusals and late actual-draw/setting faults
            * expect: REFUSED with exact caller r/e/data/order/RNG/globals/settings
            local ++test_count
            capture noisily {
                capture program drop _gcomp_draw_sim
                capture program drop _fx_native_draw
                local cause "uniquely identify"
                local expected_rc=459
                local options ""
                local callvars "y a l0 l_t xcat"
                if "`phase'"=="duplicate" {
                    qa_fx_a3_seq, clear n(1200) seed(9195) perturb(dup_key)
                    quietly regress y l_t l0
                }
                if "`phase'"=="single_period" {
                    qa_fx_a3_seq, clear n(1200) seed(9195) perturb(single_period)
                    quietly regress y l_t l0
                    local cause "at least two observed visit"
                    local expected_rc=2000
                }
                if "`phase'"!="late" local options "outcome(y) idvar(id) tvar(period) fixedcovariates(l0 xcat) intvars(a) interventions(a=1, a=0) commands(a:logit,y:logit) equations(a:l_t l0,y:a l_t l0 i.xcat) sim(1200) samples(2) seed(9195)"
                else {
                    qa_fx_a1_gauss, clear n(3600) seed(9191) perturb(unsorted)
                    quietly regress y a x1 x2 i.xcat
                    tempfile native_source fault_source
                    python: __import__('_qa_gc_session').source()
                    run "`native_source'"
                    run "`fault_source'"
                    local options "outcome(y) mediation obe control(0) exposure(a) mediator(x2) commands(x2:logit,y:regress) equations(x2:a x1 i.xcat,y:x2 a x1 i.xcat) base_confs(x1 xcat) sim(12000) samples(6) seed(9192) minsim moreMC"
                    local callvars "y x2 a x1 xcat"
                    local cause "planted gcomp after-draw"
                    local expected_rc=603
                }
                if "`context'"=="empty" ereturn clear
                set matastrict `strict'
                tempfile refusal
                capture log close fxref
                log using "`refusal'", text name(fxref)
                _fx_gc_caller_r "`context'"
                qa_state_snapshot, tag(gc_session) rreturn predict(xb stdp)
                capture noisily gcomp `callvars', `options'
                local command_rc=_rc
                qa_state_compare, tag(gc_session)
                log close fxref
                assert `command_rc'==`expected_rc'
                assert "`c(matastrict)'"=="`strict'"
                python: assert __import__('sfi').Macro.getLocal('cause') in open(__import__('sfi').Macro.getLocal('refusal'),encoding='utf-8').read()
            }
            if !_rc {
                local ++pass_count
                display as result "PASS: `strict'/`phase'/`context' strict error transaction"
            }
            else {
                local ++fail_count
                display as error "FAIL: `strict'/`phase'/`context' (rc=`=_rc')"
                capture log close fxref
            }
        }
    }
}
capture program drop _gcomp_draw_sim
capture program drop _fx_native_draw
if `fail_count'>0 {
    display "RESULT: test_fixture_session tests=`test_count' pass=`pass_count' fail=`fail_count' status=FAIL"
    capture log close _all
    exit 1
}
else {
    display "RESULT: test_fixture_session tests=`test_count' pass=`pass_count' fail=`fail_count' status=PASS"
    capture log close _all
}
