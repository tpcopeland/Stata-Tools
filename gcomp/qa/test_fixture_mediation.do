* test_fixture_mediation.do -- canonical zero-mediated Gaussian target and exports
* Author: Timothy P Copeland, Karolinska Institutet
* guard: target2/0 follows balanced A1-GAUSS; fitted transport and population recovery are distinct.
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
python:
def checkmediation():
    import csv,math
    from sfi import Macro,Matrix
    from openpyxl import load_workbook
    from pathlib import Path
    B=Matrix.get('fx_mediation_b')[0]
    labels=['Total Causal Effect (TCE)','Natural Direct Effect (NDE)','Natural Indirect Effect (NIE)','Proportion Mediated (PM)','Controlled Direct Effect (CDE)']
    rows=list(csv.reader(open(Macro.getLocal('csv'),encoding='utf-8')))
    md=Path(Macro.getLocal('md')).read_text(encoding='utf-8')
    w=load_workbook(Macro.getLocal('book')+'.xlsx',data_only=True)
    for i,label in enumerate(labels):
        found=[r for r in rows if r and r[0]==label]
        assert len(found)==1 and math.isfinite(float(found[0][1]))
        assert abs(float(found[0][1])-B[i])<=5.1e-7
        assert label in md and f'{B[i]:.6f}' in md
        assert w['Mediation'].cell(i+3,2).value==label
        assert abs(float(w['Mediation'].cell(i+3,3).value)-B[i])<=5.1e-7
    w.close()
import types,sys
m=types.ModuleType('_qa_gc_med');m.check=checkmediation;sys.modules['_qa_gc_med']=m
end
capture program drop _fx_gauss_mediation
program define _fx_gauss_mediation
    args op seed
    local perturb ""
    if "`op'"!="" local perturb "perturb(`op')"
    qa_fx_a1_gauss, clear n(3600) seed(9151) `perturb'
    matrix fx_med_truth_b=r(truth_b)
    matrix fx_med_truth_v=r(truth_v)
    assert r(truth_v_available)==1
    local ta=colnumb(fx_med_truth_b,"a")
    local truth=fx_med_truth_b[1,`ta']
    local recovery_se=sqrt(fx_med_truth_v[`ta',`ta'])
    * x2 is balanced Bernoulli(.5) independently of a in every x1/xcat cell.
    * Declaring it a no-effect mediator preserves the canonical structural mean:
    * Y(a,m)=1+2a+.5x1-m+.25I(cat2)-.25I(cat3)+epsilon.
    * Thus TCE=NDE=CDE=2 and NIE=PM=0 by direct substitution.
    local caller_sorted : sortedby
    generate long fx_order=_n
    bysort a x1 xcat: egen double fx_mmean=mean(x2)
    assert fx_mmean==.5
    sort fx_order
    drop fx_mmean fx_order
    if "`caller_sorted'"!="" sort `caller_sorted', stable
    quietly regress y a x1 x2 i.xcat
    matrix fx_med_native=e(b)
    local ja=colnumb(fx_med_native,"a")
    local jm=colnumb(fx_med_native,"x2")
    local direct=fx_med_native[1,`ja']
    local mediator=fx_med_native[1,`jm']
    assert !missing(`truth',`direct',`mediator',`recovery_se') & `recovery_se'>0
    assert abs(`direct'-`truth')<6*`recovery_se'
    quietly gcomp y x2 a x1 xcat, outcome(y) mediation obe control(0) exposure(a) mediator(x2) ///
        commands(x2: logit,y: regress) equations(x2: a x1 i.xcat,y: x2 a x1 i.xcat) ///
        base_confs(x1 xcat) sim(12000) samples(2) seed(`seed') minsim moreMC savemodels
    assert e(N)==3600 & e(MC_sims)==12000 & e(N_models)==2
    matrix fx_mediation_b=e(b)
    assert colsof(fx_mediation_b)==5
    * Baselines are copied identically to each world (engine base_confs block);
    * minsim takes conditional outcome means. Only mediator Bernoulli draws
    * remain. Cauchy-Schwarz bounds Var(Mbar1-Mbar0)<=1/MC, without presuming
    * independent worlds; conditional MC SE is |fitted mediator beta|/sqrt(MC).
    local mc_se=abs(`mediator')/sqrt(e(MC_sims))
    assert !missing(`mc_se',e(tce),e(nde),e(nie),e(pm),e(cde)) & `mc_se'>0
    assert abs(e(cde)-`direct')<1e-10
    assert abs(e(tce)-`direct')<6*`mc_se'
    assert abs(e(nde)-`direct')<6*`mc_se'
    assert abs(e(nie))<6*`mc_se'
    assert abs(e(tce)-`truth')<6*(`recovery_se'+`mc_se')
    assert abs(e(nde)-`truth')<6*(`recovery_se'+`mc_se')
    assert abs(e(pm)-e(nie)/e(tce))<1e-12
    assert abs(e(tce)-e(nde)-e(nie))<1e-12
    display "ORACLE op=`op' seed=`seed' native=" %12.8f `direct' " truth=" %12.8f `truth' " recoverySE=" %12.8f `recovery_se' " MCSE=" %12.8f `mc_se'
    tempfile csv md book
    local csv "`csv'.csv"
    local md "`md'.md"
    qa_state_snapshot, tag(medwriter)
    quietly gcomptab, xlsx("`book'.xlsx") sheet("Mediation") ci(normal) decimal(6) csv("`csv'") markdown("`md'")
    qa_state_compare, tag(medwriter)
    assert r(N_effects)==5 & r(has_cde)==1
    foreach effect in tce nde nie pm cde {
        local j=colnumb(fx_mediation_b,"`effect'")
        assert !missing(r(`effect'),fx_mediation_b[1,`j'])
        assert abs(r(`effect')-fx_mediation_b[1,`j'])<1e-12
    }
    python: __import__('_qa_gc_med').check()
    erase "`csv'"
    erase "`md'"
    erase "`book'.xlsx"
end
foreach op in friendly unsorted {
    **# F/U: canonical OBE/CDE population recovery and actual mediation writer payloads
    * expect: INVARIANT for unsorted target/fitted coefficient, MC means within derived bounds
    local ++test_count
    capture noisily {
        local perturb ""
        if "`op'"=="unsorted" local perturb "unsorted"
        forvalues seed=9152/9154 {
            _fx_gauss_mediation "`perturb'" `seed'
        }
        if "`op'"=="friendly" matrix fx_med_friendly=fx_med_native
        else {
            assert !missing(mreldif(fx_med_friendly,fx_med_native))
            assert mreldif(fx_med_friendly,fx_med_native)<1e-12
        }
    }
    if !_rc {
        local ++pass_count
        display as result "PASS: `op' Gaussian mediation recovery/all sinks"
    }
    else {
        local ++fail_count
        display as error "FAIL: `op' Gaussian mediation (rc=`=_rc')"
    }
}
if `fail_count'>0 {
    display "RESULT: test_fixture_mediation tests=`test_count' pass=`pass_count' fail=`fail_count' status=FAIL"
    capture log close _all
    exit 1
}
else {
    display "RESULT: test_fixture_mediation tests=`test_count' pass=`pass_count' fail=`fail_count' status=PASS"
    capture log close _all
}
