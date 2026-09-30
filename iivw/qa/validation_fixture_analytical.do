*! validation_fixture_analytical.do  2026/09/30
*! Author: Timothy P Copeland, Karolinska Institutet
*! Canonical conditional weighted Gaussian projections, not recovery.
*! A3 VISIT supplies visit/calendar/u support; explicit xcat/outcome adapters below.
*! Oracle uses raw columns plus QR/SVD least squares, never generated design/e(sample).
clear all
version 16.0
set more off
set varabbrev off
capture log close _all
log using "validation_fixture_analytical.log", text replace name(analytical)
do _iivw_qa_common.do
iivw_qa_bootstrap
do _qa_fx_a3.do

* Gaussian identity GLM minimizes weighted squared residuals. A common pweight
* normalization cancels from its point equations. Primary fetched 2026/09/30:
* https://www.stata.com/manuals/rglm.pdf PDF33-34, weighted likelihood/SSE.
* This tests outcome arithmetic conditional on independently captured fitted
* visit weights. Existing intensity/propensity oracles test construction.
python:
import numpy as np
from sfi import Data, Matrix, Macro, Missing
ANALYTICAL=None

def analytical_prepare():
    global ANALYTICAL
    raw=Data.get(['id','time','y','xcat','_iivw_weight'])
    assert all(not Missing.isMissing(v) for row in raw for v in row)
    rows=np.asarray(raw,dtype=float)
    assert np.isfinite(rows).all() and np.all(rows[:,4]>0)
    keys=[(int(i),float(t)) for i,t in rows[:,:2]]
    assert len(set(keys))==len(keys)
    kind=Macro.getLocal('kind'); degree=int(Macro.getLocal('degree'))
    base=int(Macro.getLocal('base')); interact=int(Macro.getLocal('interact'))
    t=rows[:,1]; cat=rows[:,3]; y=rows[:,2]; w=rows[:,4]
    columns=[]; names=[]
    if kind=='category':
        levels=sorted(set(cat)); used=base if base in levels else levels[0]
        for level in levels:
            if level!=used:
                columns.append((cat==level).astype(float)); names.append('_iivw_cat_xcat_'+str(int(level)))
    if kind=='timecategory':
        levels=sorted(set(t)); used=base if base in levels else levels[0]
        for index,level in enumerate([v for v in levels if v!=used],1):
            columns.append((t==level).astype(float)); names.append('_iivw_tcat_'+str(index))
    else:
        for power in range(1,degree+1):
            columns.append(t**power); names.append({1:'time',2:'_iivw_time_sq',3:'_iivw_time_cu'}[power])
    if interact:
        # Category indicators interacted with each time power, exactly as help.
        levels=sorted(set(cat)); used=base if base in levels else levels[0]
        for level in levels:
            if level!=used:
                for power in range(1,degree+1):
                    columns.append((cat==level)*t**power)
                    names.append('_iivw_ix_xcat_'+str(int(level))+'_'+{1:'time',2:'tsq',3:'tcu'}[power])
    columns.append(np.ones(len(rows))); names.append('_cons')
    X=np.column_stack(columns); A=np.sqrt(w)[:,None]*X; b=np.sqrt(w)*y
    coefficients,residuals,rank,singular=np.linalg.lstsq(A,b,rcond=None)
    assert rank==len(names), ('independent design is not full rank',kind,degree,base,rank,names)
    fitted=X@coefficients
    # Verify the score identity independently of the SVD solution transport.
    score=X.T@(w*(y-fitted))
    assert np.max(np.abs(score))/max(1,float(np.sum(w*np.abs(y))))<1e-12
    ANALYTICAL={'by_key':dict(zip(keys,fitted)),'b':dict(zip(names,coefficients)),'N':len(rows),
                'kind':kind,'degree':degree,'base':base,'interact':interact,'w':w.copy()}
    # False-green witnesses: intercept-only cannot mimic this nonconstant fit;
    # dropping the declared category adapter changes its exact projection.
    assert np.ptp(y)>1e-3
    if degree>0 or kind in ('category','timecategory'):
        assert np.ptp(fitted)>1e-3
    if kind=='category':
        simpler=np.column_stack([t**power for power in range(1,degree+1)]+[np.ones(len(rows))])
        simple_b=np.linalg.lstsq(np.sqrt(w)[:,None]*simpler,b,rcond=None)[0]
        assert np.max(np.abs(fitted-simpler@simple_b))>1e-3

def analytical_verify():
    rows=Data.get(['id','time','_draft_got','_iivw_weight'])
    assert len(rows)==ANALYTICAL['N']
    assert int(Macro.getLocal('fitted_N'))==ANALYTICAL['N']
    expected=np.asarray([ANALYTICAL['by_key'][(int(i),float(t))] for i,t,g,w in rows])
    got=np.asarray([g for i,t,g,w in rows])
    assert all(not Missing.isMissing(g) for i,t,g,w in rows) and np.isfinite(got).all()
    residual=np.abs(got-expected)/(1+np.abs(expected))
    assert np.max(residual)<1e-9,('every-row projection',ANALYTICAL['kind'],np.max(residual))
    # An injected .001 payload error must exceed the fixed arithmetic bound.
    assert np.max(np.abs(got+.001-expected)/(1+np.abs(expected)))>1e-9
    names=Macro.getLocal('b_names').split()
    values=Matrix.get(Macro.getLocal('observed_b'))[0]
    if Macro.getLocal('kind')!='collinear':
        assert len(names)==len(set(names)) and set(names)==set(ANALYTICAL['b']), ('exact coefficient schema',names,ANALYTICAL['b'])
        for name,value in zip(names,values):
            wanted=ANALYTICAL['b'][name]
            assert abs(value-wanted)/(1+abs(wanted))<1e-9,(name,value,wanted)
    print('ANALYTICAL_PROJECTION_EVERY_ROW_AND_COEFFICIENT',Macro.getLocal('op'),ANALYTICAL['kind'],ANALYTICAL['degree'],ANALYTICAL['base'],ANALYTICAL['interact'],'N',len(rows),'max_reldif',np.max(residual))
end

capture program drop _draft_analytical
program define _draft_analytical, rclass
    version 16.0
    args op
    drop if !visit
    * Declared numerical adapter, not catalog population truth: paired-u groups
    * and a nonzero category-by-time contribution that detects omitted design.
    generate byte xcat=mod(floor((id-1)/2),3)+1
    replace y=y+.137*xcat+.071*xcat*time
    tempfile source weighted
    save `source'
    iivw_weight, id(id) time(time) visit_cov(lag_y) maxfu(4) nolog
    save `weighted'
    local tests=0
    local pass=0
    local fail=0
    tempname observed_b
    foreach specification in none linear quadratic cubic {
        local ++tests
        capture noisily {
            use `weighted', clear
            local kind polynomial
            local degree=cond("`specification'"=="none",0,cond("`specification'"=="linear",1,cond("`specification'"=="quadratic",2,3)))
            local base=1
            local interact=0
            python: from __main__ import analytical_prepare; analytical_prepare()
            iivw_fit y, timespec(`specification') vce(fixed) nolog
            local fitted_N=e(N)
            local b_names : colnames e(b)
            matrix `observed_b'=e(b)
            predict double _draft_got, xb
            python: from __main__ import analytical_verify; analytical_verify()
        }
        local rc=_rc
        if `rc'==0 local ++pass
        else {
            local ++fail
            di as error "FAIL analytical `op' polynomial `specification' rc=`rc'"
        }
    }
    foreach base in 1 3 999 {
        foreach interact in 0 1 {
            local ++tests
            capture noisily {
                use `weighted', clear
                local kind category
                local degree=1
                local ix ""
                if `interact' local ix "interaction(xcat)"
                python: from __main__ import analytical_prepare; analytical_prepare()
                iivw_fit y xcat, categorical(xcat) basecat(`base') timespec(linear) `ix' vce(fixed) nolog
                local fitted_N=e(N)
                local b_names : colnames e(b)
                matrix `observed_b'=e(b)
                predict double _draft_got, xb
                python: from __main__ import analytical_verify; analytical_verify()
            }
            local rc=_rc
            if `rc'==0 local ++pass
            else {
                local ++fail
                di as error "FAIL analytical `op' category base`base' interaction`interact' rc=`rc'"
            }
        }
    }
    foreach base in 0 999 {
        local ++tests
        capture noisily {
            use `source', clear
            * Bounded noninteger-time adapter, applied BEFORE new weights.
            * ln(1)..ln(5) preserve the raw-double equality regression while
            * avoiding a 1503-column fit of individual stochastic visit times.
            * Preserve the caller's friendly/unsorted order after wave assignment.
            tempvar source_order wave
            generate long `source_order'=_n
            bysort id (time): generate long `wave'=_n
            keep if `wave'<=5
            replace time=ln(`wave')
            sort `source_order'
            drop `source_order' `wave'
            iivw_weight, id(id) time(time) visit_cov(lag_y) maxfu(4) nolog
            local kind timecategory
            local degree=0
            local interact=0
            python: from __main__ import analytical_prepare; analytical_prepare()
            iivw_fit y, timespec(categorical) timebasecat(`base') vce(fixed) nolog
            local fitted_N=e(N)
            local b_names : colnames e(b)
            matrix `observed_b'=e(b)
            predict double _draft_got, xb
            python: from __main__ import analytical_verify; analytical_verify()
        }
        local rc=_rc
        if `rc'==0 local ++pass
        else {
            local ++fail
            di as error "FAIL analytical `op' categorical timebase`base' rc=`rc'"
        }
    }
    local ++tests
    capture noisily {
        use `weighted', clear
        * Explicit collinear outcome-design adapter; VISIT has no collinear
        * operator. Coefficients are nonidentified, so compare exact fitted
        * values to the full-rank time/intercept projection, not an arbitrary
        * allocation between two proportional regressors.
        generate double duplicate_time=2*time
        assert duplicate_time==2*time
        local kind collinear
        local degree=1
        local base=1
        local interact=0
        python: from __main__ import analytical_prepare; analytical_prepare()
        iivw_fit y duplicate_time, timespec(linear) vce(fixed) nolog
        local fitted_N=e(N)
        local b_names : colnames e(b)
        matrix `observed_b'=e(b)
        predict double _draft_got, xb
        python: from __main__ import analytical_verify; analytical_verify()
    }
    local rc=_rc
    if `rc'==0 local ++pass
    else {
        local ++fail
        di as error "FAIL analytical `op' collinear projection rc=`rc'"
    }
    return scalar tests=`tests'
    return scalar pass=`pass'
    return scalar fail=`fail'
end
local tests=0
local pass=0
local fail=0
qa_fx_a3_visit, clear tier(unit) n(100) seed(931)
_draft_analytical friendly
local tests=`tests'+r(tests)
local pass=`pass'+r(pass)
local fail=`fail'+r(fail)
* expect: EXACT
qa_fx_a3_visit, clear tier(unit) n(100) seed(931) perturb(unsorted)
_draft_analytical unsorted
local tests=`tests'+r(tests)
local pass=`pass'+r(pass)
local fail=`fail'+r(fail)
di "RESULT: validation_fixture_analytical tests=`tests' pass=`pass' fail=`fail' skip=0"
log close analytical
iivw_qa_sandbox_restore
if `fail'>0 exit 1
