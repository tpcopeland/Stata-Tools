*! test_fixture_native_globals.do 2026/09/30
*! Author: Timothy P Copeland, Karolinska Institutet
*! Reviewed canonical boundary controls; intentional e/r/RNG publication scoped separately.
version 16.0
clear all
set processors 1
capture log close _all
local qa_dir "`c(pwd)'"
do "`qa_dir'/_qa_bootstrap.do"
do "`qa_dir'/_qa_fx_a3.do"
do "`qa_dir'/_qa_fx_a1.do"
do "`qa_dir'/_qa_state.do"
mata:
_fx_count_globals=asarray_create("string",1)
void _fx_count_global_snapshot() {
    external transmorphic scalar _fx_count_globals
    string colvector names
    real scalar i
    _fx_count_globals=asarray_create("string",1)
    names=st_dir("global","macro","*")
    for(i=1;i<=rows(names);i++) {
        if (!st_isname(names[i]) | names[i]=="S_E_cmd" | names[i]=="S_E_depv") continue
        asarray(_fx_count_globals,names[i],st_global(names[i]))
    }
}
void _fx_count_global_compare() {
    external transmorphic scalar _fx_count_globals
    string colvector names,actual,old
    real scalar i,bad
    bad=0
    names=st_dir("global","macro","*");actual=J(0,1,"")
    for(i=1;i<=rows(names);i++) {
        if (!st_isname(names[i]) | names[i]=="S_E_cmd" | names[i]=="S_E_depv") continue
        actual=actual\names[i]
        if (!asarray_contains(_fx_count_globals,names[i])) {
            printf("GLOBAL_ADDED %s=%s\n",names[i],st_global(names[i]));bad=1;continue
        }
        if (asarray(_fx_count_globals,names[i])!=st_global(names[i])) {
            printf("GLOBAL_CHANGED %s: [%s] -> [%s]\n",names[i],asarray(_fx_count_globals,names[i]),st_global(names[i]));bad=1
        }
    }
    old=asarray_keys(_fx_count_globals)
    for(i=1;i<=rows(old);i++) if(!anyof(actual,old[i])) {printf("GLOBAL_REMOVED %s\n",old[i]);bad=1;}
    assert(!bad)
}
end
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

local candidates "ReS_Call ReS_i ReS_j ReS_jv ReS_jv2 ReS_Xij Res_Xi ReS_atwl ReS_str S_1 S_2 S_1_full rtmpST rVANS"
local tests 0
local pass 0
local fail 0
foreach context in absent empty opaque {
 foreach phase in poisson nbreg duplicate single_period late {
  local ++tests
  capture noisily {
   capture program drop _gcomp_draw_sim
   capture program drop _fx_native_draw
   local options ""
   local callvars "y group aux"
   local expected_rc 0
   local cause ""
   if inlist("`phase'","poisson","nbreg") {
    qa_fx_a3_traj, clear n(1200) k(3) model(poisson) seed(9231)
    if "`phase'"=="nbreg" {
     set seed 9232
     sort id period
     generate double multiplier=rgamma(2,.5)
     replace y=rpoisson(exp(eta)*multiplier)
     drop multiplier
    }
    replace y=. if period<2
    quietly regress y group if period==2
    local options "outcome(y) idvar(id) tvar(period) eofu fixedcovariates(aux) intvars(group) interventions(group=1,group=2,group=3) commands(group:mlogit,y:`phase') equations(group:aux,y:i.group) sim(1000) samples(2) seed(9233) minsim"
   }
   else if "`phase'"!="late" {
    local perturb "dup_key"
    local expected_rc 459
    local cause "uniquely identify"
    if "`phase'"=="single_period" {
     local perturb "single_period"
     local expected_rc 2000
     local cause "at least two observed visit"
    }
    if "`phase'"=="duplicate" qa_fx_a3_seq, clear n(1200) seed(9195) perturb(dup_key)
    else qa_fx_a3_seq, clear n(1200) seed(9195) perturb(single_period)
    quietly regress y l_t l0
    local callvars "y a l0 l_t xcat"
    local options "outcome(y) idvar(id) tvar(period) fixedcovariates(l0 xcat) intvars(a) interventions(a=1, a=0) commands(a:logit,y:logit) equations(a:l_t l0,y:a l_t l0 i.xcat) sim(1200) samples(2) seed(9195)"
   }
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
    local expected_rc 603
   }
   if "`context'"=="absent" macro drop `candidates'
   else {
    foreach candidate of local candidates {
     if "`context'"=="empty" mata: st_global(st_local("candidate"), "")
     else mata: st_global(st_local("candidate"), "caller opaque " + char(36) + "bait " + char(96) + "tick" + char(39) + char(34) + " punctuation [](),")
    }
   }
   tempfile cause_log
   log using "`cause_log'", text name(fxref)
   _fx_gc_caller_r full
   mata: _fx_count_global_snapshot()
   qa_state_snapshot, tag(nativeglobals) rreturn predict(xb stdp)
   capture noisily gcomp `callvars', `options'
   local command_rc=_rc
   if `expected_rc' {
    qa_state_compare, tag(nativeglobals)
   }
   else {
    qa_state_compare, tag(nativeglobals) allow(e r rng global)
    assert e(cmd)=="gcomp"
    assert !missing(el(e(b),1,1),el(e(b),1,2),el(e(b),1,3))
   }
   mata: _fx_count_global_compare()
   log close fxref
   assert `command_rc'==`expected_rc'
   if `expected_rc' python: assert __import__('sfi').Macro.getLocal('cause') in open(__import__('sfi').Macro.getLocal('cause_log'),encoding='utf-8').read()
   * Caller can next use the native reshape and NB2 commands after opaque bytes restore.
   if !`expected_rc' {
    preserve
    keep id period y
    reshape wide y, i(id) j(period)
    assert _N==1200
    reshape long y, i(id) j(period)
    assert _N==3600
    quietly nbreg y if period==2
    assert e(N)==1200 & !missing(el(e(b),1,1))
    tempvar prediction
    predict double `prediction', n
    assert `prediction'>0 & `prediction'<.
    restore
   }
  }
  if !_rc {
   local ++pass
   display "PASS: `phase'/`context' native-global boundary and next-call control"
  }
  else {
   local ++fail
   display "FAIL: `phase'/`context' (rc=`=_rc')"
   capture log close fxref
  }
 }
}
if `fail'>0 {
    display "RESULT: test_fixture_native_globals tests=`tests' pass=`pass' fail=`fail' status=FAIL"
    capture log close _all
    exit 1
}
else {
    display "RESULT: test_fixture_native_globals tests=`tests' pass=`pass' fail=`fail' status=PASS"
    capture log close _all
}
