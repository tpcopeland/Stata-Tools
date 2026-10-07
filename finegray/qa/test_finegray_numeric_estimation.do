*! test_finegray_numeric_estimation Version 1.0.0  2026/10/07
*! Numeric regression pins for P008/P005/P009/P010/P003
*! Author: Timothy P Copeland, Karolinska Institutet
*
* H-tier fixtures and independent oracles:
* - 100+100 active subjects, cause counts50/25: b=-ln2,H0=.5;
*   sandwich .04, with default adjustment .04*201/200.
* - Dense direct risk-set enumeration (G=1) gives score root, sandwich,
*   Breslow masses and Schoenfeld residuals without any package scan.
* - Connected delayed-entry chain: G=2^-K,Hcomp=2^-K/61 gives retained
*   competitor weight61. Effective x0/x1 risks92/30 and cause counts10/10
*   imply b=ln(92/30),H0=20/184. Fresh survival::finegray+coxph independently
*   confirmed these identities during the 2026-10-07 audit.
* - Own-baseline consulted sets are empty despite later causes elsewhere.
* - Random weights compare the exact fit draw with materialization and the
*   dense oracle; a replayed checked draw cannot be evaluated twice.
* guard: ordinary/uniform weights, true-zero floor, nonempty diagnostics,
* and edited-weight refusals are expected green on the pre-fix baseline.

version 16.0
clear all
set processors 1
capture log close _all
log using "test_finegray_numeric_estimation.log", text replace name(_fgnumeric) nomsg
local qa_dir "`c(pwd)'"
if substr("`qa_dir'", -3, 3) != "/qa" error 198
local pkg_dir = substr("`qa_dir'", 1, strlen("`qa_dir'") - 3)
do "`qa_dir'/_finegray_qa_common.do"
_finegray_qa_bootstrap
local orig_plus "`r(orig_plus)'"
local orig_personal "`r(orig_personal)'"
local plus_dir "`r(plus_dir)'"
local personal_dir "`r(personal_dir)'"
ado dir
which finegray
which _finegray_weight_var
do "`qa_dir'/_qa_state.do"
do "`qa_dir'/_qa_lifecycle.do"
do "`qa_dir'/_qa_hostile.do"

local test_count = 0
local pass_count = 0
local fail_count = 0

capture program drop _fgnum_base
program define _fgnum_base
    version 16.0
    clear
    set obs 201
    gen long id = _n
    gen byte x = (_n > 100 & _n <= 200)
    gen byte status = 0
    replace status = 1 in 1/50
    replace status = 1 in 101/125
    gen double time = cond(status==1,1,2)
    replace time = .5 in 201
    gen double w = 1
    stset time, failure(status==1 2) id(id)
end

capture program drop _fgnum_chain
program define _fgnum_chain
    version 16.0
    syntax , STEPS(integer)
    clear
    local n = `steps' + 62
    set obs `n'
    gen long id = _n
    gen double entry = 0
    gen double time = `steps' + 3
    gen byte status = 0
    gen byte x = 0
    replace time = .5 in 2
    replace status = 2 in 2
    forvalues j = 1/`steps' {
        local row = `j' + 2
        replace entry = `j' - .25 in `row'
        replace time = `j' + .25 in `row'
        replace x = mod(`j',2) in `row'
    }
    local first = `steps' + 3
    replace entry = `steps' + 1 in `first'/`n'
    local lo1 = `first' + 30
    replace x = 1 in `lo1'/`n'
    local last0 = `first' + 9
    local last1 = `lo1' + 9
    replace status = 1 in `first'/`last0'
    replace status = 1 in `lo1'/`last1'
    replace time = `steps' + 2 if status==1
    stset time, failure(status==1 2) enter(time entry) id(id)
end

capture program drop _fgnum_random
program define _fgnum_random, rclass
    version 16.0
    clear
    set obs 300
    gen long id = _n
    gen byte x = mod(_n,2)
    gen byte status = cond(mod(_n,7)==0,2,cond(mod(_n,5)==0,1,0))
    gen double time = cond(status==2,.5,cond(status==1,1,2))
    stset time, failure(status==1 2) id(id)
    set seed 7142201
    mark draw_mark [pw=1+runiform()]
    local checkpoint `"`c(rngstate)'"'
    gen double fitw = 1+runiform()
    return local checkpoint `"`checkpoint'"'
end

mata:
real scalar _fgnum_dense_score(real matrix a, real scalar b)
{
    real colvector et, risk, r, sel
    real scalar j, d, s0, s1, out
    et = uniqrows(select(a[.,1], a[.,3] :== 1))
    r = a[.,4] :* exp(a[.,2] :* b)
    out = 0
    for (j=1; j<=rows(et); j++) {
        risk = (a[.,1] :>= et[j]) :| ((a[.,3] :== 2) :& (a[.,1] :< et[j]))
        sel = selectindex((a[.,3] :== 1) :& (a[.,1] :== et[j]))
        d = sum(a[sel,4])
        s0 = sum(select(r, risk))
        s1 = sum(select(r :* a[.,2], risk))
        out = out + sum(a[sel,4] :* a[sel,2]) - d*s1/s0
    }
    return(out)
}
void _fgnum_dense(string scalar wvar, string scalar outmat, string scalar srvar)
{
    real matrix a, out
    real colvector et, risk, r, sel, score, sr
    real scalar lo, hi, b, j, k, d, s0, s1, s2, z, info, H
    a = st_data(., ("time","x","status",wvar))
    lo=-50; hi=50
    for (k=1;k<=180;k++) {
        b=(lo+hi)/2
        if (_fgnum_dense_score(a,b)>0) lo=b
        else hi=b
    }
    b=(lo+hi)/2
    et=uniqrows(select(a[.,1],a[.,3]:==1))
    r=a[.,4]:*exp(a[.,2]:*b)
    score=J(rows(a),1,0)
    sr=J(rows(a),1,.)
    info=H=0
    for(j=1;j<=rows(et);j++) {
        risk=(a[.,1]:>=et[j]):|((a[.,3]:==2):&(a[.,1]:<et[j]))
        sel=selectindex((a[.,3]:==1):&(a[.,1]:==et[j]))
        d=sum(a[sel,4]);s0=sum(select(r,risk))
        s1=sum(select(r:*a[.,2],risk));s2=sum(select(r:*(a[.,2]:^2),risk))
        z=s1/s0;H=H+d/s0;info=info+d*(s2/s0-z^2)
        sr[sel]=a[sel,2]:-z
        score[sel]=score[sel]+a[sel,2]:-z
        score=score-exp(a[.,2]:*b):*risk:*(a[.,2]:-z):*(d/s0)
    }
    out=(b,sum((a[.,4]:*score):^2)/(info^2),H,_fgnum_dense_score(a,b))
    st_matrix(outmat,out)
    if(srvar!="")st_store(.,srvar,sr)
}
end

**## inactive pweight 1e12
local ++test_count
capture noisily {
    _fgnum_base
    replace w = 1e12 in 201
    tempname rawsum
    quietly summarize w, meanonly
    scalar `rawsum'=r(sum)
    * expect: EQUAL -- beta, sandwich, baseline and CIF are representable.
    finegray x [pw=w], compete(status) cause(1) nolog basehaz
    assert e(converged)==1
    assert !missing(_b[x],e(V)[1,1],e(ll),e(ll_0),e(basehaz)[1,2])
    assert abs(_b[x]+ln(2))<1e-8
    assert abs(e(V)[1,1]-(.04*201/200))<1e-8
    assert abs(e(basehaz)[1,2]-.5)<1e-8
    assert abs(e(ll)-(25*(-ln(2))-75*ln(150)))<1e-7
    assert abs(e(ll_0)+75*ln(200))<1e-7
    assert e(N)==201 & e(N_fail)==75 & e(N_compete)==0 & e(N_cens)==126
    assert e(sample)==1
    assert w==1 if id!=201
    assert w==1e12 if id==201
    assert !missing(e(sum_w))
    assert abs(e(sum_w)-(1e12+200))<.01
    assert e(sum_w)==`rawsum'
    assert `"`e(wsig)'"'!="" & `"`e(rowsig)'"'!=""
    assert e(wsig_n)==201 & e(rowsig_n)==201
    assert `"`e(wexp)'"'=="= w"
    tempname C0 C1
    finegray_cif, at(x=0) attime(1) ci nograph
    matrix `C0'=r(table)
    finegray_cif, at(x=1) attime(1) ci nograph
    matrix `C1'=r(table)
    assert !missing(`C0'[1,2],`C1'[1,2])
    assert abs(`C0'[1,2]-(1-exp(-.5)))<1e-8
    assert abs(`C1'[1,2]-(1-exp(-.25)))<1e-8
    gen double evaltime=1
    * Force the package loader to refresh while preserving the independent
    * dense oracle and the vendored QA state helpers in this session.
    capture mata: mata drop _finegray_numeric_ok()
    predict double cold_cif, cif timevar(evaltime)
    assert !missing(cold_cif)
    assert abs(cold_cif-(1-exp(-.5)))<1e-8 if x==0
    assert abs(cold_cif-(1-exp(-.25)))<1e-8 if x==1
}
local test_rc = _rc
if `test_rc' == 0 {
    local ++pass_count
    display as result "PASS: inactive pweight 1e12"
}
else {
    local ++fail_count
    display as error "FAIL: inactive pweight 1e12 (rc=`test_rc')"
}

**## inactive pweight 1e17
local ++test_count
capture noisily {
    _fgnum_base
    replace w = 1e17 in 201
    tempname rawsum
    quietly summarize w, meanonly
    scalar `rawsum'=r(sum)
    * expect: EQUAL -- beta, sandwich, baseline and CIF are representable.
    finegray x [pw=w], compete(status) cause(1) nolog basehaz noadjust
    assert e(converged)==1
    assert !missing(_b[x],e(V)[1,1],e(ll),e(ll_0),e(basehaz)[1,2])
    assert abs(_b[x]+ln(2))<1e-8
    assert abs(e(V)[1,1]-(.04))<1e-8
    assert abs(e(basehaz)[1,2]-.5)<1e-8
    assert abs(e(ll)-(25*(-ln(2))-75*ln(150)))<1e-7
    assert abs(e(ll_0)+75*ln(200))<1e-7
    assert e(N)==201 & e(N_fail)==75 & e(N_compete)==0 & e(N_cens)==126
    assert e(sample)==1
    assert w==1 if id!=201
    assert w==1e17 if id==201
    assert !missing(e(sum_w))
    assert e(sum_w)==`rawsum'
    assert `"`e(wsig)'"'!="" & `"`e(rowsig)'"'!=""
    assert e(wsig_n)==201 & e(rowsig_n)==201
    assert `"`e(wexp)'"'=="= w"
    tempname C0 C1
    finegray_cif, at(x=0) attime(1) ci nograph
    matrix `C0'=r(table)
    finegray_cif, at(x=1) attime(1) ci nograph
    matrix `C1'=r(table)
    assert !missing(`C0'[1,2],`C1'[1,2])
    assert abs(`C0'[1,2]-(1-exp(-.5)))<1e-8
    assert abs(`C1'[1,2]-(1-exp(-.25)))<1e-8
    gen double evaltime=1
    capture mata: mata drop _finegray_numeric_ok()
    predict double cold_cif, cif timevar(evaltime)
    assert !missing(cold_cif)
    assert abs(cold_cif-(1-exp(-.5)))<1e-8 if x==0
    assert abs(cold_cif-(1-exp(-.25)))<1e-8 if x==1
}
local test_rc = _rc
if `test_rc' == 0 {
    local ++pass_count
    display as result "PASS: inactive pweight 1e17"
}
else {
    local ++fail_count
    display as error "FAIL: inactive pweight 1e17 (rc=`test_rc')"
}

**## uniform pweight preservation
local ++test_count
capture noisily {
    _fgnum_base
    finegray x, compete(status) cause(1) nolog
    tempname B V ll ll0
    matrix `B'=e(b)
    matrix `V'=e(V)
    scalar `ll'=e(ll)
    scalar `ll0'=e(ll_0)
    finegray x [pw=w], compete(status) cause(1) nolog
    assert !missing(mreldif(`B',e(b)),mreldif(`V',e(V)))
    assert !matmissing(`B') & !matmissing(`V') & !matmissing(e(b)) & !matmissing(e(V))
    assert mreldif(`B',e(b))==0 & mreldif(`V',e(V))==0
    assert e(ll)==`ll' & e(ll_0)==`ll0'
    assert abs(_b[x]+ln(2))<1e-8
    * A large common scale on truly participating rows remains supported.
    replace w=1e17 if time>=1
    finegray x [pw=w], compete(status) cause(1) nolog basehaz
    assert e(converged)==1 & e(N)==201 & e(N_fail)==75 & e(sample)==1
    assert !matmissing(e(b)) & !matmissing(e(V)) & !missing(e(basehaz)[1,2])
    assert mreldif(e(b),`B')<1e-12 & mreldif(e(V),`V')<1e-12
    assert abs(e(basehaz)[1,2]-.5)<1e-8
    assert w==1e17 if time>=1
    assert w==1 if time<1
    assert e(N)==201 & e(sample)==1
}
local test_rc = _rc
if `test_rc' == 0 {
    local ++pass_count
    display as result "PASS: uniform pweight preservation"
}
else {
    local ++fail_count
    display as error "FAIL: uniform pweight preservation (rc=`test_rc')"
}

**## heterogeneous small event weights
local ++test_count
capture noisily {
    _fgnum_base
    replace w=1e-12 if status==1
    replace w=1 in 201
    tempname D B
    mata: _fgnum_dense("w","`D'","")
    finegray x [pw=w], compete(status) cause(1) nolog basehaz noadjust
    assert e(converged)==1
    assert !missing(_b[x],e(V)[1,1],e(basehaz)[1,2],`D'[1,1],`D'[1,2],`D'[1,3])
    assert abs(_b[x]-ln((50+50e-12)/(2*(75+25e-12))))<1e-8
    assert abs(_b[x]-`D'[1,1])<1e-8
    assert abs(e(V)[1,1]-`D'[1,2])<1e-8
    assert abs(e(basehaz)[1,2]-`D'[1,3])<1e-20
    assert e(N)==201 & e(N_fail)==75 & e(sample)==1
}
local test_rc = _rc
if `test_rc' == 0 {
    local ++pass_count
    display as result "PASS: heterogeneous small event weights"
}
else {
    local ++fail_count
    display as error "FAIL: heterogeneous small event weights (rc=`test_rc')"
}

**## tied causes retained competitor dense control
local ++test_count
capture noisily {
    _fgnum_base
    replace time=.5 in 51/60
    replace status=2 in 51/60
    replace time=1 in 201
    replace status=2 in 201
    replace time=1.5 in 1/20
    replace w=1+mod(id,5)
    replace w=1000 in 51
    stset time, failure(status==1 2) id(id)
    gen double oracle_sr=.
    tempname D
    mata: _fgnum_dense("w","`D'","oracle_sr")
    finegray x [pw=w], compete(status) cause(1) nolog basehaz noadjust
    assert e(converged)==1
    assert !missing(_b[x],e(V)[1,1],e(basehaz)[rowsof(e(basehaz)),2],`D'[1,1],`D'[1,2],`D'[1,3])
    assert abs(_b[x]-`D'[1,1])<1e-8
    assert abs(e(V)[1,1]-`D'[1,2])<1e-8
    assert abs(e(basehaz)[rowsof(e(basehaz)),2]-`D'[1,3])<1e-8
    assert e(N_compete)==11 & e(N_fail)==75 & e(N)==201 & e(sample)==1
    predict double sr, schoenfeld
    assert !missing(sr,oracle_sr) if status==1
    assert abs(sr-oracle_sr)<1e-8 if status==1
    assert missing(sr) if status!=1
    finegray_cif, at(x=0) attime(1.5) ci nograph
    assert !missing(r(table)[1,2])
    assert abs(r(table)[1,2]-(1-exp(-`D'[1,3])))<1e-8
}
local test_rc = _rc
if `test_rc' == 0 {
    local ++pass_count
    display as result "PASS: tied causes retained competitor dense control"
}
else {
    local ++fail_count
    display as error "FAIL: tied causes retained competitor dense control (rc=`test_rc')"
}

**## positive delayed entry K30
local ++test_count
capture noisily {
    _fgnum_chain, steps(30)
    finegray x, compete(status) cause(1) nolog basehaz
    assert e(converged)==1
    assert !missing(_b[x],e(basehaz)[1,2],e(min_weight_prob),e(max_lt_weight))
    assert abs(_b[x]-ln(92/30))<1e-8
    assert abs(e(basehaz)[1,2]-20/184)<1e-8
    assert abs(e(max_lt_weight)-61)<1e-8
    assert abs(e(min_weight_prob)/(2^(-30)/61)-1)<1e-10
    assert e(N)==92 & e(N_fail)==20 & e(N_compete)==1
    assert e(N_G_trunc)==0 & e(N_lt_prehole)==0
    assert e(sample)==1
    finegray_cif, at(x=0) attime(32) ci nograph
    assert !missing(r(table)[1,2])
    assert abs(r(table)[1,2]-(1-exp(-20/184)))<1e-8
    replace entry=entry*13
    replace time=time*13
    stset time, failure(status==1 2) enter(time entry) id(id)
    finegray x, compete(status) cause(1) nolog
    assert e(converged)==1
    assert !missing(_b[x])
    assert abs(_b[x]-ln(92/30))<1e-8
}
local test_rc = _rc
if `test_rc' == 0 {
    local ++pass_count
    display as result "PASS: positive delayed entry K30"
}
else {
    local ++fail_count
    display as error "FAIL: positive delayed entry K30 (rc=`test_rc')"
}

**## positive delayed entry K50
local ++test_count
capture noisily {
    _fgnum_chain, steps(50)
    finegray x, compete(status) cause(1) nolog basehaz
    assert e(converged)==1
    assert !missing(_b[x],e(basehaz)[1,2],e(min_weight_prob),e(max_lt_weight))
    assert abs(_b[x]-ln(92/30))<1e-8
    assert abs(e(basehaz)[1,2]-20/184)<1e-8
    assert abs(e(max_lt_weight)-61)<1e-8
    assert abs(e(min_weight_prob)/(2^(-50)/61)-1)<1e-10
    assert e(N)==112 & e(N_fail)==20 & e(N_compete)==1
    assert e(N_G_trunc)==0 & e(N_lt_prehole)==0
    assert e(sample)==1
    finegray_cif, at(x=0) attime(52) ci nograph
    assert !missing(r(table)[1,2])
    assert abs(r(table)[1,2]-(1-exp(-20/184)))<1e-8
    replace entry=entry*13
    replace time=time*13
    stset time, failure(status==1 2) enter(time entry) id(id)
    finegray x, compete(status) cause(1) nolog
    assert e(converged)==1
    assert !missing(_b[x])
    assert abs(_b[x]-ln(92/30))<1e-8
}
local test_rc = _rc
if `test_rc' == 0 {
    local ++pass_count
    display as result "PASS: positive delayed entry K50"
}
else {
    local ++fail_count
    display as error "FAIL: positive delayed entry K50 (rc=`test_rc')"
}

**## own baseline empty diagnostics with nonempty control
local ++test_count
capture noisily {
    clear
    set obs 200
    gen long id=_n
    gen byte group=(_n>100)
    gen byte x=mod(_n,2)
    gen byte status=0
    replace status=1 in 1/20
    replace status=1 in 101/120
    replace status=2 in 21/40
    gen double time=cond(group==0,cond(status==1,1,cond(status==2,2,3)),cond(status==1,5,6))
    stset time, failure(status==1 2) id(id)
    finegray x, compete(status) cause(1) strata(group) bstrata(group) nolog
    assert e(converged)==1 & abs(_b[x])<1e-10
    assert missing(e(min_weight_prob)) & missing(e(max_lt_weight))
    assert e(N_prob_warn)==0 & e(N_weight_warn)==0 & e(N_G_trunc)==0
    assert e(N_weight_strata)==2 & e(N)==200 & e(sample)==1
    finegray x, compete(status) cause(1) strata(group) nolog
    assert !missing(e(min_weight_prob),e(max_lt_weight))
    assert e(min_weight_prob)==1e-10 & e(max_lt_weight)==1e-10
    assert e(N_G_trunc)==20
}
local test_rc = _rc
if `test_rc' == 0 {
    local ++pass_count
    display as result "PASS: own baseline empty diagnostics with nonempty control"
}
else {
    local ++fail_count
    display as error "FAIL: own baseline empty diagnostics with nonempty control (rc=`test_rc')"
}

**## legitimate multicell LT consultation control
local ++test_count
capture noisily {
    clear
    set obs 200
    gen long id=_n
    gen byte group=(_n>100)
    gen byte x=mod(_n,2)
    gen byte status=cond(mod(_n,5)==0,1,0)
    gen double time=cond(status==1,1,2)
    gen double entry=.25
    stset time, failure(status==1 2) enter(time entry) id(id)
    finegray x, compete(status) cause(1) strata(group) truncstrata(group) nolog
    assert e(converged)==1 & abs(_b[x])<1e-10
    assert !missing(e(min_weight_prob),e(max_lt_weight))
    assert abs(e(min_weight_prob)-1)<1e-12 & abs(e(max_lt_weight)-1)<1e-12
    assert e(N_prob_warn)==0 & e(N_weight_warn)==0 & e(N_G_trunc)==0
    assert e(N_weight_strata)==2
}
local test_rc = _rc
if `test_rc' == 0 {
    local ++pass_count
    display as result "PASS: legitimate multicell LT consultation control"
}
else {
    local ++fail_count
    display as error "FAIL: legitimate multicell LT consultation control (rc=`test_rc')"
}

**## random checked column reused once
local ++test_count
capture noisily {
    _fgnum_random
    local checkpoint `"`r(checkpoint)'"'
    tempname D B V T S
    mata: _fgnum_dense("fitw","`D'","")
    finegray x [pw=fitw], compete(status) cause(1) nolog
    matrix `B'=e(b)
    matrix `V'=e(V)
    local fixed_sig `"`e(wsig)'"'
    scalar `S'=e(sum_w)
    finegray_cif, at(x=0) attime(1) ci nograph
    matrix `T'=r(table)
    assert !missing(`T'[1,2],`D'[1,3])
    assert abs(`T'[1,2]-(1-exp(-`D'[1,3])))<1e-8
    set seed 7142201
    finegray x [pw=1+runiform()+0*fitw], compete(status) cause(1) nolog
    assert `"`e(wsig)'"'==`"`fixed_sig'"'
    assert e(sum_w)==`S'
    assert !matmissing(e(b)) & !matmissing(e(V)) & !matmissing(`B') & !matmissing(`V')
    assert mreldif(e(b),`B')<1e-12 & mreldif(e(V),`V')<1e-12
    set rngstate `checkpoint'
    finegray_cif, at(x=0) attime(1) ci nograph
    assert !matmissing(r(table)) & !matmissing(`T')
    assert mreldif(r(table),`T')<1e-10
    assert !missing(r(table)[1,2])
    assert abs(r(table)[1,2]-(1-exp(-`D'[1,3])))<1e-8
    set seed 91271
    capture noisily finegray_cif, at(x=0) attime(1) ci nograph
    local refused=_rc
    assert `refused'==459
    assert !matmissing(e(b)) & mreldif(e(b),`B')<1e-12
}
local test_rc = _rc
if `test_rc' == 0 {
    local ++pass_count
    display as result "PASS: random checked column reused once"
}
else {
    local ++fail_count
    display as error "FAIL: random checked column reused once (rc=`test_rc')"
}

**## unchanged data and scalar weightswap refusal
local ++test_count
capture noisily {
    _fgnum_base
    scalar _fgnum_k=2
    finegray x [pw=cond(id==201,2,cond(x==0,scalar(_fgnum_k),4-scalar(_fgnum_k)))], compete(status) cause(1) nolog
    assert e(sum_w)==402
    tempname B
    matrix `B'=e(b)
    local sig `"`e(wsig)'"'
    scalar _fgnum_k=1
    assert 2+100*scalar(_fgnum_k)+100*(4-scalar(_fgnum_k))==402
    capture noisily finegray_cif, at(x=0) attime(1) ci nograph
    local refused=_rc
    assert `refused'==459
    assert `"`e(wsig)'"'==`"`sig'"'
    assert !matmissing(e(b)) & !matmissing(`B')
    assert mreldif(e(b),`B')==0
    assert w==1 & e(sample)==1
    scalar drop _fgnum_k
}
local test_rc = _rc
if `test_rc' == 0 {
    local ++pass_count
    display as result "PASS: unchanged data and scalar weightswap refusal"
}
else {
    local ++fail_count
    display as error "FAIL: unchanged data and scalar weightswap refusal (rc=`test_rc')"
}

**## positive survivor underflow public refusal
local ++test_count
capture noisily {
    _fgnum_chain, steps(1100)
    * expect: REFUSED 430 -- a strictly positive product limit is unrepresentable.
    capture noisily finegray x, compete(status) cause(1) nolog
    local refused=_rc
    assert `refused'==430
    assert _N==1162
    assert status==2 if id==2
    assert time==.5 if id==2
    assert entry==0 if id==1 | id==2
}
local test_rc = _rc
if `test_rc' == 0 {
    local ++pass_count
    display as result "PASS: positive survivor underflow public refusal"
}
else {
    local ++fail_count
    display as error "FAIL: positive survivor underflow public refusal (rc=`test_rc')"
}

**## joint product numeric guard and mapped normalizer control
local ++test_count
capture noisily {
    _fgnum_chain, steps(600)
    gen double Gtiny=1e-300
    tempname kap
    * The individual G/H factors are positive and finite, their product is not.
    capture mata: _finegray_A_at_times(st_data(.,"_t"),st_data(.,"Gtiny"),J(st_nobs(),1,1),st_data(.,"_t0"),J(st_nobs(),1,1),1,1,.6)
    local refused=_rc
    assert `refused'==430
    * (1/n)/H remains representable when 1/H is not. Full cell n=1000.
    mata: h=J(1000,1,1);h[1]=1e-309;st_numscalar("`kap'",_finegray_lt_normalizer(J(1000,1,1),1,h))
    assert !missing(`kap')
    assert abs(`kap'/1e306-1)<1e-12
    capture mata: _finegray_lt_normalizer(1,1,1e-309)
    local refused=_rc
    assert `refused'==430
}
local test_rc = _rc
if `test_rc' == 0 {
    local ++pass_count
    display as result "PASS: joint product numeric guard and mapped normalizer control"
}
else {
    local ++fail_count
    display as error "FAIL: joint product numeric guard and mapped normalizer control (rc=`test_rc')"
}

**## true zero floor and postestimation state controls
local ++test_count
capture noisily {
    _fgnum_base
    finegray x [pw=w], compete(status) cause(1) nolog
    local ll=e(ll)
    qa_state_snapshot, tag(fgnum_cif) rreturn
    finegray_cif, at(x=0) attime(1) ci nograph
    qa_state_compare, tag(fgnum_cif) allow(r)
    assert !missing(e(ll)) & abs(e(ll)-`ll')<1e-12
    qa_state_snapshot, tag(fgnum_error) rreturn
    capture noisily finegray_cif, at(x=0) attime(-1) ci nograph
    local refused=_rc
    assert `refused'==198
    qa_state_compare, tag(fgnum_error) allow(r)
    tempname Z
    mata: st_matrix("`Z'",_finegray_km_censor_single((1,2)',(1,0)',0,(1,0)',(0,0)'))
    assert `Z'[1,1]==1 & `Z'[2,1]==1e-10
    qa_hostile_times
    assert !missing(r(before),r(jump),r(after))
    assert r(before)<r(jump) & r(jump)<r(after)
}
local test_rc = _rc
if `test_rc' == 0 {
    local ++pass_count
    display as result "PASS: true zero floor and postestimation state controls"
}
else {
    local ++fail_count
    display as error "FAIL: true zero floor and postestimation state controls (rc=`test_rc')"
}

**# Result and cleanup
sysdir set PLUS "`orig_plus'"
sysdir set PERSONAL "`orig_personal'"
capture shell rm -rf "`plus_dir'" "`personal_dir'"
display as result "RESULT: test_finegray_numeric_estimation tests=`test_count' pass=`pass_count' fail=`fail_count'"
log close _fgnumeric
if `fail_count'>0 exit 1
exit 0
