* test_fixture_report_precision.do -- actual formatted numeric transport
* Author: Timothy P Copeland, Karolinska Institutet
* guard: fitted values are the oracle for formatting, not a new causal estimand.
version 16.0
clear all
set more off
set varabbrev off
set processors 1
set linesize 255
capture log close _all
local qa_dir "`c(pwd)'"
local pkg_dir "`qa_dir'/.."
do "`qa_dir'/_install_msm_isolated.do" "`pkg_dir'"
do "`qa_dir'/_qa_fx_a3.do"
do "`qa_dir'/_qa_state.do"
local test_count 0
local pass_count 0
local fail_count 0
python:
def checkprecision():
    import csv,math,re
    from pathlib import Path
    from sfi import Macro,Matrix
    from openpyxl import load_workbook
    B=Matrix.get('fx_precision_b')[0]; V=Matrix.get('fx_precision_V')
    names=Matrix.getColNames('fx_precision_b')
    names=[x[-1] if isinstance(x,(list,tuple)) else x.split(':')[-1] for x in names]
    digits=int(Macro.getLocal('digits')); eform=Macro.getLocal('scale')=='eform'
    bound=.500001*10**(-digits)
    rows=list(csv.reader(open(Macro.getLocal('csv'),encoding='utf-8')))
    for i,term in enumerate(names):
        if V[i][i]<=0: continue
        found=[r for r in rows if len(r)==(5 if eform else 4) and r[0]==term]
        assert len(found)==1, (term,found)
        expected=([math.exp(B[i]),math.exp(B[i]-1.959963984540054*math.sqrt(V[i][i])),math.exp(B[i]+1.959963984540054*math.sqrt(V[i][i]))] if eform else [B[i],math.sqrt(V[i][i])])
        for observed,want in zip(found[0][1:],expected):
            assert math.isfinite(float(observed)) and 'e' not in observed.lower()
            assert abs(float(observed)-want)<=bound, (term,observed,want,digits)
    w=load_workbook(Macro.getLocal('book')+'.xlsx',data_only=True)
    cells=list(w['Coefficients'].values)
    # Native numeric workbook point cells retain full precision, regardless of
    # requested text precision; no workbook string proxy is accepted.
    for i,b in enumerate(B):
        value=w['Coefficients'].cell(i+3,2).value
        assert isinstance(value,(int,float)) and math.isfinite(value)
        assert abs(value-(math.exp(b) if eform else b))<1e-10
    w.close()
    if not eform:
        lines=Path(Macro.getLocal('console')).read_text().splitlines()
        headers=[x for x in lines if x.strip().startswith('Variable') and 'Coef' in x and 'p-value' in x]
        assert len(headers)==1
        assert headers[0].index('Coef')+4==46 and headers[0].index('SE')+2==72
        rows=[x for x in lines if x[:20].strip()=='fx_positive']
        assert len(rows)==1
        j=names.index('fx_positive')
        assert abs(float(rows[0][22:46])-B[j])<=bound
        assert abs(float(rows[0][48:72])-math.sqrt(V[j][j]))<=bound
import types,sys
m=types.ModuleType('_qa_msm_precision');m.check=checkprecision;sys.modules['_qa_msm_precision']=m
end
qa_fx_a3_seq, clear n(1600) seed(9101)
quietly msm_prepare, id(id) period(period) treatment(a) outcome(y) covariates(l_t) baseline_covariates(l0)
quietly msm_weight, treat_d_cov(l_t l0) nolog
* Explicit supported exposure adapter rescales and reverses binary exposure.
* The actual fitted coefficient is positive >1 and exp(b)>1000; intercept<0.
generate double fx_positive=(1-a)/10
quietly msm_fit, model(logistic) exposure(fx_positive) period_spec(cubic) nolog
matrix fx_precision_b=e(b)
matrix fx_precision_V=e(V)
local j=colnumb(fx_precision_b,"fx_positive")
assert !missing(`j',fx_precision_b[1,`j']) & fx_precision_b[1,`j']>1
assert exp(fx_precision_b[1,`j'])>1000
assert fx_precision_b[1,colnumb(fx_precision_b,"_cons")]<0
foreach precision in default zero eight {
    foreach scale in raw eform {
        **# F/U: actual positive/negative/large transformed values at requested precision
        * expect: EXACT
        local ++test_count
        capture noisily {
            local digits=cond("`precision'"=="default",4,cond("`precision'"=="zero",0,8))
            local opt ""
            if "`precision'"!="default" local opt "decimals(`digits')"
            local transform ""
            if "`scale'"=="eform" local transform "eform"
            tempfile csv book console
            capture log close _all
            log using "`console'", text replace name(precision_console)
            qa_state_snapshot, tag(reportdisplay)
            noisily msm_report, `opt' `transform'
            qa_state_compare, tag(reportdisplay)
            log close precision_console
            qa_state_snapshot, tag(reportcsv)
            quietly msm_report, format(csv) export("`csv'") `opt' `transform' replace
            qa_state_compare, tag(reportcsv)
            qa_state_snapshot, tag(reportexcel)
            quietly msm_report, format(excel) export("`book'.xlsx") `opt' `transform' replace
            qa_state_compare, tag(reportexcel)
            python: __import__('_qa_msm_precision').check()
            erase "`csv'"
            erase "`book'.xlsx"
            erase "`console'"
        }
        local rc=_rc
        capture log close _all
        if !`rc' {
            local ++pass_count
            display as result "PASS: `precision' `scale' numeric fields/header/workbook"
        }
        else {
            local ++fail_count
            display as error "FAIL: `precision' `scale' precision (rc=`rc')"
        }
    }
}
display "RESULT: test_fixture_report_precision tests=`test_count' pass=`pass_count' fail=`fail_count' skip=0"
do "`qa_dir'/_record_qa_result.do" "test_fixture_report_precision" `test_count' `pass_count' `fail_count'
capture log close _all
if `fail_count'>0 exit 1
