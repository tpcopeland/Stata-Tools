* test_fixture_public.do -- canonical public pipeline and artifact payloads
* Author: Timothy P Copeland, Karolinska Institutet
* guard: catalog adoption; no source repair asserted by this suite.
version 16.0
clear all
set more off
set varabbrev off
set processors 1
capture log close _all
local qa_dir "`c(pwd)'"
local pkg_dir "`qa_dir'/.."
do "`qa_dir'/_install_msm_isolated.do" "`pkg_dir'"
do "`qa_dir'/_qa_fx_a3.do"
do "`qa_dir'/_qa_fx_a7.do"
do "`qa_dir'/_qa_state.do"
local test_count 0
local pass_count 0
local fail_count 0

python:
def _fx_msm_py_1():
    from sfi import Macro, Matrix
    from openpyxl import load_workbook
    import csv, math
    B=Matrix.get('fx_expected_b')[0]
    V=Matrix.get('fx_expected_V')
    rows=list(csv.reader(open(Macro.getLocal('csv'),encoding='utf-8')))
    assert ['Individuals','1600'] in rows
    for i,term in enumerate(Matrix.getColNames('fx_expected_b')):
        term=term[-1] if isinstance(term,(list,tuple)) else term.split(':')[-1]
        found=[r for r in rows if len(r)==4 and r[0]==term]
        if V[i][i]>0:
            assert len(found)==1 and abs(float(found[0][1])-B[i])<=5.1e-9
            assert abs(float(found[0][2])-math.sqrt(V[i][i]))<=5.1e-9
    wb=load_workbook(Macro.getLocal('table')+'.xlsx',data_only=True)
    assert set(wb.sheetnames)=={'Coefficients','Predictions','Balance','Weights','Sensitivity'}
    for i,b in enumerate(B):
        if V[i][i]>0:
            assert abs(wb['Coefficients'].cell(i+3,2).value-b)<1e-12
    wb.close()
    wb=load_workbook(Macro.getLocal('book')+'.xlsx',data_only=True)
    assert {'Summary','Coefficients'}.issubset(wb.sheetnames)
    coeff=[tuple(c.value for c in row) for row in wb['Coefficients']]
    assert any('a' in row and any(isinstance(x,(int,float)) and abs(x-B[0])<1e-12 for x in row) for row in coeff)
    wb.close()
    wb=load_workbook(Macro.getLocal('diag')+'.xlsx',data_only=True)
    ws=wb['Weight Diagnostics']
    assert ws['A3'].value=='Fixture' and ws['B3'].value=='Event'
    assert ws['D3'].value==round(float(Macro.getLocal('ess')))
    wb.close()
def _fx_msm_py_2():
    from sfi import Macro
    from pathlib import Path
    import xml.etree.ElementTree as ET
    root=ET.parse(Macro.getLocal('g')+'.svg').getroot()
    text=' '.join(root.itertext())
    assert 'Fixture '+Macro.getLocal('type') in text
    shape=[e for e in root.iter() if e.tag.rsplit('}',1)[-1] in {'polyline','path','circle','rect','line','polygon'}]
    assert len(shape)>10
import types, sys
m=types.ModuleType("_qa_msm_public")
m.check1=_fx_msm_py_1
m.check2=_fx_msm_py_2
sys.modules["_qa_msm_public"]=m
end

capture program drop _fx_msm_public
program define _fx_msm_public
    args op
    local perturb ""
    if "`op'" != "" local perturb "perturb(`op')"
    qa_fx_a3_seq, clear n(1600) seed(9101) `perturb'
    gen long fx_row = _n
    quietly msm, list
    assert r(n_commands) == 12
    assert strpos("`r(commands)'", "msm_diagtab") > 0
    quietly msm, detail
    assert r(n_commands) == 12
    quietly msm, status
    assert r(prepared) == 0 & r(fitted) == 0
    quietly msm_prepare, id(id) period(period) treatment(a) outcome(y) covariates(l_t) baseline_covariates(l0)
    quietly msm, status
    assert r(prepared) == 1 & r(weighted) == 0
    assert "`r(id)'" == "id" & "`r(stage)'" == "prepared"
    quietly msm_validate
    assert r(n_errors) == 0
    quietly msm_weight, treat_d_cov(l_t l0) nolog
    quietly summarize _msm_weight, meanonly
    local sw = r(sum)
    gen double fx_w2 = _msm_weight^2
    quietly summarize fx_w2, meanonly
    local ess = `sw'^2/r(sum)
    capture frame drop fxdiag
    quietly msm_diagnose, balance_covariates(l_t l0) accumulate(fxdiag) contrast("Fixture") outcome("Event")
    assert !missing(r(ess),`ess') & reldif(r(ess),`ess') < 1e-10
    matrix fx_expected_balance = r(balance)
    matrix fx_expected_balance = fx_expected_balance[1...,1..2]
    frame fxdiag: assert !missing(ess) & reldif(ess,`ess') < 1e-10
    quietly msm_fit, model(logistic) period_spec(cubic) nolog
    matrix fx_expected_b = e(b)
    matrix fx_expected_V = e(V)
    quietly msm_predict, times(1 3) difference samples(20) seed(9122)
    matrix fx_expected_predictions = r(predictions)
    assert rowsof(fx_expected_predictions) == 2
    quietly msm_sensitivity, evalue orapprox
    local or = exp(fx_expected_b[1,colnumb(fx_expected_b,"a")])
    local rr = cond(`or'<1,1/`or',`or')
    * VanderWeele & Ding (2017): reciprocal protective RR then RR+sqrt(RR*(RR-1)).
    * orapprox explicitly selects the documented direct-OR input, not an RR claim.
    assert !missing(r(evalue_point)) & abs(r(evalue_point)-(`rr'+sqrt(`rr'*(`rr'-1)))) < 1e-10
    local ev = r(evalue_point)
    quietly msm, status
    assert r(prepared) == 1 & r(weighted) == 1 & r(fitted) == 1
    assert r(prediction_saved) == 1 & r(balance_saved) == 1 & r(diagnostics_saved) == 1 & r(sensitivity_saved) == 1
    assert "`r(model)'" == "logistic"
    tempfile csv book table diag
    quietly msm_report
    assert "`r(format)'" == "display"
    quietly msm_report, format(csv) export("`csv'") decimals(8) replace
    quietly msm_report, format(excel) export("`book'.xlsx") decimals(8) replace
    quietly msm_table, xlsx("`table'.xlsx") all decimals(8) replace
    quietly msm_diagtab, frame(fxdiag) xlsx("`diag'.xlsx") decimals(8) replace
    python: __import__("_qa_msm_public").check1()
    preserve
    collapse (mean) fx_prop=a, by(period)
    mkmat period fx_prop, matrix(fx_expected_prop)
    restore
    * Independent sample reconstruction retains exact canonical subject histories.
    local trajectory_rng = c(rngstate)
    preserve
    keep id period a
    set seed 9122
    bysort id: gen byte fx_tag=(_n==1)
    gen double fx_draw=runiform() if fx_tag
    sort fx_draw
    gen byte fx_selected=(_n<=3) & fx_tag
    bysort id: egen byte fx_subject=max(fx_selected)
    keep if fx_subject
    sort id period
    mkmat id period a, matrix(fx_expected_trajectory)
    restore
    quietly set rngstate `trajectory_rng'
    foreach type in weights balance survival trajectory positivity {
        tempfile g
        local opt ""
        if "`type'" == "balance" local opt "covariates(l_t l0)"
        if "`type'" == "survival" local opt "times(1 3) samples(20) seed(9122)"
        if "`type'" == "trajectory" local opt "n_sample(3) seed(9122)"
        quietly msm_plot, type(`type') `opt' title("Fixture `type'") saving("`g'.gph") replace
        assert "`r(plot_type)'" == "`type'"
        if "`type'" == "balance" {
            assert !missing(mreldif(r(balance),fx_expected_balance))
            assert mreldif(r(balance),fx_expected_balance) < 1e-10
        }
        graph use "`g'.gph"
        * Stata sersets carry the numeric series actually rendered (official
        * serset manual fetched2026-09-30), not a success marker or file proxy.
        preserve
        serset use, clear
        if "`type'"=="survival" {
            assert _N==2
            forvalues i=1/2 {
                assert time[`i']==fx_expected_predictions[`i',1]
                assert !missing(ci_never[`i'],ci_always[`i'])
                assert abs(ci_never[`i']-fx_expected_predictions[`i',2])<1e-12
                assert abs(ci_always[`i']-fx_expected_predictions[`i',5])<1e-12
            }
        }
        if "`type'"=="positivity" {
            assert _N==4
            forvalues i=1/4 {
                assert period[`i']==fx_expected_prop[`i',1]
                assert !missing(treat_prob[`i'])
                * collapse default float output has at most one float ulp.
                assert treat_prob[`i']==float(fx_expected_prop[`i',2])
            }
        }
        if "`type'"=="trajectory" {
            restore
            forvalues panel=0/2 {
                serset set `panel'
                preserve
                serset use, clear
                assert _N==4 & inlist(a,0,1) & inrange(period,0,3)
                isid period
                sort period
                forvalues i=1/4 {
                    local j=4*`panel'+`i'
                    assert period[`i']==fx_expected_trajectory[`j',2]
                    assert a[`i']==fx_expected_trajectory[`j',3]
                }
                restore
            }
            preserve
        }
        if "`type'"=="balance" {
            assert _N==2 & !missing(smd_uw,smd_w)
            forvalues i=1/2 {
                local j=3-plot_order[`i']
                assert abs(smd_uw[`i']-abs(fx_expected_balance[`j',1]))<1e-12
                assert abs(smd_w[`i']-abs(fx_expected_balance[`j',2]))<1e-12
            }
        }
        if "`type'"=="weights" {
            assert !missing(_msm_weight) & _msm_weight>0
            quietly summarize _msm_weight, meanonly
            assert !missing(r(N)) & r(N)>1600
        }
        restore
        graph export "`g'.svg", as(svg) replace
    python: __import__("_qa_msm_public").check2()
        erase "`g'.gph"
        erase "`g'.svg"
    }
    assert fx_row == _n
    matrix fx_public_b = fx_expected_b
    matrix fx_public_pred = fx_expected_predictions
    erase "`csv'"
    erase "`book'.xlsx"
    erase "`table'.xlsx"
    erase "`diag'.xlsx"
    frame drop fxdiag
end

**# F: canonical panel public readers, plots and numeric export payloads
local ++test_count
capture noisily _fx_msm_public
if !_rc {
    local ++pass_count
    matrix fx_f_b = fx_public_b
    matrix fx_f_pred = fx_public_pred
    display as result "PASS: F canonical public pipeline/artifacts"
}
else {
    local ++fail_count
    display as error "FAIL: F canonical public pipeline/artifacts (rc=`=_rc')"
}

**# U: unsorted canonical panel retains public reader and export values
* expect: INVARIANT
local ++test_count
capture noisily {
    _fx_msm_public unsorted
    assert !missing(mreldif(fx_f_b,fx_public_b)) & mreldif(fx_f_b,fx_public_b)<1e-10
    assert !missing(fx_f_pred[1,2],fx_public_pred[1,2],fx_f_pred[2,5],fx_public_pred[2,5])
    assert reldif(fx_f_pred[1,2],fx_public_pred[1,2])<1e-10
    assert reldif(fx_f_pred[2,5],fx_public_pred[2,5])<1e-10
}
if !_rc {
    local ++pass_count
    display as result "PASS: U unsorted public pipeline/artifacts"
}
else {
    local ++fail_count
    display as error "FAIL: U unsorted public pipeline/artifacts (rc=`=_rc')"
}

display "RESULT: test_fixture_public tests=`test_count' pass=`pass_count' fail=`fail_count' skip=0"
do "`qa_dir'/_record_qa_result.do" "test_fixture_public" `test_count' `pass_count' `fail_count'
capture log close _all
if `fail_count' > 0 exit 1
