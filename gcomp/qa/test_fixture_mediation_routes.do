* test_fixture_mediation_routes.do -- canonical categorical/specific/linear mediation
* Author: Timothy P Copeland, Karolinska Institutet
* guard: conditional MC transport is distinct from estimator/inference calibration.
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
import types,sys
def check():
    import csv,math,re
    from pathlib import Path
    from sfi import Macro,Matrix
    from openpyxl import load_workbook
    b=Matrix.get('fx_route_b')[0];ci=Matrix.get('fx_route_ci');se=Matrix.get('fx_route_se')[0]
    labels=['Total Causal Effect (TCE)','Natural Direct Effect (NDE)','Natural Indirect Effect (NIE)','Proportion Mediated (PM)','Controlled Direct Effect (CDE)']
    rows=list(csv.reader(open(Macro.getLocal('csv'),encoding='utf-8')))
    md=Path(Macro.getLocal('md')).read_text(encoding='utf-8')
    book=load_workbook(Macro.getLocal('book')+'.xlsx',data_only=True)
    for j,label in enumerate(labels):
        matches=[r for r in rows if r and r[0]==label]
        assert len(matches)==1 and len(matches[0])==4
        row=matches[0]
        vals=[float(row[1]),float(row[3])]+[float(x) for x in re.findall(r'-?\d+(?:\.\d+)?',row[2])]
        expected=[b[j],se[j],ci[0][j],ci[1][j]]
        assert len(vals)==4 and all(math.isfinite(x) for x in vals+expected)
        assert all(abs(x-y)<=5.1e-7 for x,y in zip(vals,expected))
        assert label in md and f'{b[j]:.6f}' in md
        assert row[2] in md
        assert book['Effects'].cell(j+3,2).value==label
        assert abs(float(book['Effects'].cell(j+3,3).value)-b[j])<=5.1e-7
        assert book['Effects'].cell(j+3,4).value==row[2]
        assert abs(float(book['Effects'].cell(j+3,5).value)-se[j])<=5.1e-7
    book.close()
m=types.ModuleType('_qa_gc_medroutes');m.check=check;sys.modules['_qa_gc_medroutes']=m
end

* eclass publication may replace only the two legacy active-e globals;
* all other caller globals must retain exact names and opaque bytes.
mata:
_fx_gc_globals=asarray_create("string",1)
void _fx_gc_global_snapshot() {
    external transmorphic scalar _fx_gc_globals
    string colvector names
    real scalar i
    _fx_gc_globals=asarray_create("string",1)
    names=st_dir("global","macro","*")
    for(i=1;i<=rows(names);i++) {
        if (!st_isname(names[i]) | names[i]=="S_E_cmd" | names[i]=="S_E_depv") continue
        asarray(_fx_gc_globals,names[i],st_global(names[i]))
    }
}
void _fx_gc_global_compare() {
    external transmorphic scalar _fx_gc_globals
    string colvector names,actual
    real scalar i
    names=st_dir("global","macro","*");actual=J(0,1,"")
    for(i=1;i<=rows(names);i++) {
        if (!st_isname(names[i]) | names[i]=="S_E_cmd" | names[i]=="S_E_depv") continue
        actual=actual\names[i]
        assert(asarray_contains(_fx_gc_globals,names[i]))
        assert(asarray(_fx_gc_globals,names[i])==st_global(names[i]))
    }
    assert(rows(actual)==rows(asarray_keys(_fx_gc_globals)))
}
end

foreach seed in 9191 9193 {
    foreach route in oce specific linexp {
        foreach order in friendly unsorted {
            **# F/U: categorical, selected contrast and continuous linear exposure
            * expect: INVARIANT for native fitted coefficients and exact CDE under shuffled rows; MC recovery within derived reference scales
            local ++test_count
            capture noisily {
                local perturb ""
                if "`order'"=="unsorted" local perturb "perturb(unsorted)"
                qa_fx_a1_gauss, clear n(3600) seed(`seed') `perturb'
                matrix fx_truth_b=r(truth_b)
                matrix fx_truth_v=r(truth_v)
                assert r(truth_v_available)==1
                * x2 is balanced independently in all a/x1/xcat cells. The
                * canonical structural mean is 1+2a+.5x1-x2+.25cat2-.25cat3.
                * Thus cat2-vs1=.25, cat3-vs1=-.25, a unit x1 shift=.5;
                * every natural indirect effect is zero.
                quietly regress y x2 i.xcat a x1
                matrix fx_route_native=e(b)
                if "`order'"=="friendly" matrix fx_native_`route'_`seed'=fx_route_native
                else {
                    assert !missing(mreldif(fx_native_`route'_`seed',fx_route_native))
                    assert mreldif(fx_native_`route'_`seed',fx_route_native)<1e-12
                }
                local jm=colnumb(fx_route_native,"x2")
                local mc_scale=abs(fx_route_native[1,`jm'])/sqrt(12000)
                assert !missing(`mc_scale') & `mc_scale'>0
                local exposure "xcat"
                local model "i.xcat a x1"
                local confs "a x1"
                local opts "oce baseline(1)"
                local terms "2.xcat 3.xcat"
                if "`route'"=="specific" {
                    local opts "specific baseline(1) alternative(3)"
                    local terms "3.xcat"
                }
                if "`route'"=="linexp" {
                    local exposure "x1"
                    local model "x1 a i.xcat"
                    local confs "a xcat"
                    local opts "linexp"
                    local terms "x1"
                }
                * Component sampling oracle uses the canonical known sigma=1
                * covariance, rather than the candidate's bootstrap covariance.
                foreach term of local terms {
                    local j=colnumb(fx_route_native,"`term'")
                    local k=colnumb(fx_truth_b,"`term'")
                    local sampling_scale=sqrt(fx_truth_v[`k',`k'])
                    assert !missing(`j',`k',`sampling_scale') & `sampling_scale'>0
                    assert abs(fx_route_native[1,`j']-fx_truth_b[1,`k'])<6*`sampling_scale'
                }
                local strict "off"
                if `seed'==9193 local strict "on"
                set matastrict `strict'
                mata: st_global("S_15", "foreign numbered " + char(36) + "bait " + char(96) + "tick" + char(39))
                mata: st_global("_fx_123", "foreign punctuation ; " + char(34))
                qa_state_snapshot, tag(medroutefit)
                mata: _fx_gc_global_snapshot()
                quietly gcomp y x2 `exposure' `confs', outcome(y) mediation `opts' control(0) ///
                    exposure(`exposure') mediator(x2) commands(x2: logit,y: regress) ///
                    equations(x2: `model',y: x2 `model') base_confs(`confs') ///
                    sim(12000) samples(6) seed(9192) minsim moreMC
                mata: _fx_gc_global_compare()
                qa_state_compare, tag(medroutefit) allow(e rng global)
                assert "`c(matastrict)'"=="`strict'"
                assert e(N)==3600 & e(MC_sims)==12000
                assert e(bootstrap_requested)==6 & e(bootstrap_attempted)==6
                assert e(bootstrap_successful)==6 & e(bootstrap_failed)==0
                assert "`e(mediation_type)'"=="`route'"
                matrix fx_route_b=e(b)
                matrix fx_route_se=e(se)
                local index=0
                foreach term of local terms {
                    local ++index
                    local suffix ""
                    if "`route'"=="oce" local suffix "_`index'"
                    local j=colnumb(fx_route_native,"`term'")
                    local k=colnumb(fx_truth_b,"`term'")
                    local direct=fx_route_native[1,`j']
                    local target=fx_truth_b[1,`k']
                    local sampling_scale=sqrt(fx_truth_v[`k',`k'])
                    foreach effect in tce nde nie pm cde {
                        local c=colnumb(fx_route_b,"`effect'`suffix'")
                        assert !missing(`c',fx_route_b[1,`c'],e(`effect'`suffix'))
                        assert fx_route_b[1,`c']==e(`effect'`suffix')
                    }
                    assert abs(e(cde`suffix')-`direct')<1e-10
                    assert abs(e(tce`suffix')-`direct')<6*`mc_scale'
                    assert abs(e(nde`suffix')-`direct')<6*`mc_scale'
                    assert abs(e(nie`suffix'))<6*`mc_scale'
                    assert abs(e(tce`suffix')-`target')<6*(`mc_scale'+`sampling_scale')
                    assert abs(e(tce`suffix')-e(nde`suffix')-e(nie`suffix'))<1e-12
                    assert abs(e(pm`suffix')-e(nie`suffix')/e(tce`suffix'))<1e-12
                }
                if "`route'"!="oce" {
                    foreach ci in normal percentile bc {
                        * These checks transport the requested bootstrap CI;
                        * six resamples do not establish interval calibration.
                        matrix fx_route_ci=e(ci_`ci')
                        assert rowsof(fx_route_ci)==2 & colsof(fx_route_ci)==5
                        tempfile csv md book
                        local csv "`csv'.csv"
                        local md "`md'.md"
                        qa_state_snapshot, tag(medroutewriter)
                        quietly gcomptab, xlsx("`book'.xlsx") sheet("Effects") ci(`ci') decimal(6) csv("`csv'") markdown("`md'")
                        qa_state_compare, tag(medroutewriter)
                        assert r(N_effects)==5 & r(has_cde)==1 & "`r(ci)'"=="`ci'"
                        python: __import__('_qa_gc_medroutes').check()
                        erase "`csv'"
                        erase "`md'"
                        erase "`book'.xlsx"
                    }
                }
            }
            if !_rc {
                local ++pass_count
                display as result "PASS: `route'/`order'/`seed' fitted/known targets and writer routes"
            }
            else {
                local ++fail_count
                display as error "FAIL: `route'/`order'/`seed' (rc=`=_rc')"
            }
        }
    }
}
if `fail_count'>0 {
    display "RESULT: test_fixture_mediation_routes tests=`test_count' pass=`pass_count' fail=`fail_count' status=FAIL"
    capture log close _all
    exit 1
}
else {
    display "RESULT: test_fixture_mediation_routes tests=`test_count' pass=`pass_count' fail=`fail_count' status=PASS"
    capture log close _all
}
