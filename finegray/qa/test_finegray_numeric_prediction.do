*! test_finegray_numeric_prediction Version 1.0.0 2026/10/07
*! Numerical regressions for exact-time transport and CIF arithmetic
*! Author: Timothy P Copeland, Karolinska Institutet
* P012/P014 exact doubles; P006 tiny hazard; P007 exp overflow; P019 CI saturation.
* Oracles use tied-risk-set identities or composed hazard in a log domain.
* Failing-old assertions must reach their natural public fit before comparison.
version 16.0
clear all
set processors 1
capture log close _all
log using test_finegray_numeric_prediction.log, text replace
local qa_dir "`c(pwd)'"
if substr("`qa_dir'",-3,3)!="/qa" error 198
local pkg_dir=substr("`qa_dir'",1,strlen("`qa_dir'")-3)
do "`qa_dir'/_finegray_qa_common.do"
ado dir
_finegray_qa_bootstrap
local orig_plus "`r(orig_plus)'"
local orig_personal "`r(orig_personal)'"
local plus_dir "`r(plus_dir)'"
local personal_dir "`r(personal_dir)'"
ado dir
which finegray
which finegray_predict
which _finegray_mata
findfile finegray_predict.ado
assert strpos(`"`r(fn)'"', `"`plus_dir'"')==1
do "`qa_dir'/_qa_state.do"
local test_count=0
local pass_count=0
local fail_count=0

**# N1: P012 exact attime interval selection
local ++test_count
capture noisily {
clear
set obs 20
generate long id = _n
generate byte k = mod(_n-1,10)+1
generate byte g = (_n>10)+1
generate byte status = (k<=4)
generate double x = cond(g==1, k==4 | k>=7, k<=3 | inlist(k,5,6))
generate double t = g + cond(status==0,.5,0)
stset t, failure(status) id(id)
quietly finegray x, compete(status) cause(1) tvc(x) tsplit(1.0000000000000002) tolerance(1e-12) nolog
assert e(converged)==1
assert abs(_b[tvc1:x]+ln(3))<1e-6
assert abs(_b[tvc2:x]-ln(3))<1e-6
scalar c4_b2=_b[tvc2:x]
scalar c4_b1=_b[tvc1:x]
local c4_decimal = real("1.0000000000000004")
display "C4_P012_LITERAL=" %21x 1.0000000000000004 " LOCAL=" "`c4_decimal'"
drop _all
set obs 1
generate double x = 1
generate double _t = 1.0000000000000004
finegray_predict double p_own, xb
finegray_predict double p_at, xb attime(1.0000000000000004)
finegray_predict double p_exact, xb attime(1.0000000000000002)
finegray_predict double p_before, xb attime(1)
assert !missing(p_exact,p_before)
assert abs(p_exact-c4_b1)<1e-12 & abs(p_before-c4_b1)<1e-12
display "C4_P012_EXPECT=" %21.16g c4_b2 " OWN=" %21.16g p_own[1] " AT=" %21.16g p_at[1]
assert !missing(p_own,p_at)
assert abs(p_own-c4_b2)<1e-12
assert abs(p_at-c4_b2)<1e-12
* A subnormal horizon is a valid time in the first interval; its %21x text
* (+0.0...X-3ff) is not a Stata literal, so a macro transport refused r(198).
finegray_predict double p_sub, xb attime(1e-318)
assert !missing(p_sub)
assert abs(p_sub-c4_b1)<1e-12

}
local test_rc=_rc
if `test_rc' == 0 {
    local ++pass_count
    display as result "PASS: N1"
}
else {
    local ++fail_count
    display as error "FAIL: N1 rc=`test_rc'"
}

**# N2: P014 boundary mass transport, six shifts
local ++test_count
capture noisily {
local c4_bad=0
foreach c4_shift in 0 .1 .3 .7 1.1 2.3 {
clear
set obs 200
generate long id=_n
generate byte k=mod(_n-191,10)+1 if _n>190
generate byte status=(_n<=100 | (_n>190 & k<=4))
generate double x=cond(_n<=100,_n<=51,cond(_n<=190,_n<=144,k<=3 | inlist(k,5,6)))
generate double t=cond(_n<=190,1,2)+cond(status==0,.5,0)
stset t, failure(status) id(id)
    quietly replace x=x+`c4_shift'
    quietly finegray x, compete(status) cause(1) tvc(x) tsplit(1) tolerance(1e-12) basehaz nolog
    assert e(converged)==1
    assert abs(_b[tvc1:x]-ln(51/49))<1e-6
    assert abs(_b[tvc2:x]-ln(3))<1e-6
    scalar c4_b1=_b[tvc1:x]
    generate double horizon=1
    finegray_predict double hcut, basecshazard timevar(horizon)
    scalar c4_hcut=hcut[1]
    local c4_phi=c4_hcut
    display "C4_P014_SHIFT=" `c4_shift' " MASSLOSS=" %21.16g (c4_hcut-`c4_phi')
    drop _all
    set obs 1
    generate double x=40+`c4_shift'
    generate double horizon=1
    finegray_predict double p, cif timevar(horizon)
    scalar c4_exact=1-exp(-c4_hcut*exp(c4_b1*x[1]))
    assert c4_exact>=1e-5 & c4_exact<1
    display "C4_P014_ANALYTIC=" %21.16g (1-exp(-.49*(51/49)^40))
    display "C4_P014_EXPECT=" %21.16g c4_exact " OBS=" %21.16g p[1]
    if missing(p[1]) | abs(p[1]-c4_exact)>1e-10 local ++c4_bad
}
display "C4_P014_BAD=" `c4_bad'
assert `c4_bad'==0

}
local test_rc=_rc
if `test_rc' == 0 {
    local ++pass_count
    display as result "PASS: N2"
}
else {
    local ++fail_count
    display as error "FAIL: N2 rc=`test_rc'"
}

**# N3: P006 tiny positive CIF, prediction and curve
local ++test_count
capture noisily {
clear
    set obs 200
    generate long id = _n
    generate byte x = (_n > 100)
    generate double t = 2
    replace t = 1 in 1/50
    replace t = 1 in 101/125
    generate byte status = (t == 1)
    stset t, failure(status) id(id)
    finegray x, compete(status) cause(1) nolog basehaz tolerance(1e-12)
    matrix B = e(b)
    matrix H = e(basehaz)
    assert abs(B[1,1] + ln(2)) < 1e-10
    assert abs(H[1,2] - .5) < 1e-10
    generate double h = 1
    replace x = 100 in 1
    finegray_predict double pp, cif timevar(h)
    scalar expect_row = .5*exp(100*B[1,1])
    assert !missing(pp[1]) & pp[1]>0 & abs(pp[1]/expect_row-1)<1e-8
    replace x = 0 in 1
    finegray_cif, at(x=100) attime(1) ci nograph
    matrix C = r(table)
    matrix list C
    scalar expect_cif = .5*exp(100*B[1,1])
    display "C1 expected tiny CIF=" %21.17g expect_cif " observed=" %21.17g C[1,2] " se=" %21.17g C[1,3]
    assert C[1,2] > 0
    assert abs(C[1,2]/expect_cif - 1) < 1e-8
    assert !missing(C[1,4],C[1,5]) & C[1,4]>=0 & C[1,5]<=1
    assert C[1,4]<=C[1,2] & C[1,5]>=C[1,2]
    * guard: zero mass, saturated hazard and missing score preserve their limits.
    drop _all
    set obs 4
    generate double x = cond(_n==1,100,cond(_n==2,-2000,cond(_n==3,0,.)))
    generate double h = cond(_n==3,0,1)
    finegray_predict double limits, cif timevar(h)
    assert limits[1]>0 & limits[1]<1e-25
    assert limits[2]==1 & limits[3]==0 & missing(limits[4])
}
local test_rc=_rc
if `test_rc' == 0 {
    local ++pass_count
    display as result "PASS: N3"
}
else {
    local ++fail_count
    display as error "FAIL: N3 rc=`test_rc'"
}

**# N4: P007 finite hazard despite exp(xb) overflow
local ++test_count
capture noisily {
clear
set seed 762401
set obs 200
gen double id = _n
gen double z = 2*runiform()-1
gen double time = 1-ln(runiform())*exp(-z)
gen double event = cond(mod(_n,5)==0,0,cond(mod(_n,4)==0,2,1))
gen double w = 1
replace time = .1 in 1
replace event = 1 in 1
replace w = 1e-12 in 1
gen double x = z
stset time, failure(event) id(id)
capture noisily finegray x [pweight=w], compete(event) cause(1) nolog
local centeredrc = _rc
display "C2_P02_CENTERED_RC=" `centeredrc'
assert `centeredrc' == 0
if `centeredrc' == 0 {
    assert e(converged)==1 & !missing(_b[x]) & abs(_b[x])>1e-8
    scalar C2bcenter = _b[x]
    display "C2_P02_CENTER_B=" %21.17g C2bcenter
    if !missing(C2bcenter) & abs(C2bcenter)>1e-8 & e(converged)==1 {
        scalar C2origin = 680/C2bcenter
        replace x = z+C2origin
        capture noisily finegray x [pweight=w], compete(event) cause(1) nolog
        local shiftedrc = _rc
        display "C2_P02_SHIFTED_RC=" `shiftedrc'
        assert `shiftedrc' == 0
if `shiftedrc' == 0 {
            display "C2_P02_SHIFTED_CONVERGED=" e(converged)
            assert e(converged)==1 & !missing(_b[x]) & abs(_b[x])>1e-8
            scalar C2bshift = _b[x]
            display "C2_P02_SHIFT_B=" %21.17g C2bshift
            gen double C2lpfit = x*C2bshift
            quietly summarize C2lpfit
            display "C2_P02_TRAINING_XB_MIN=" %21.17g r(min)
            display "C2_P02_TRAINING_XB_MAX=" %21.17g r(max)
            gen double h = .1
            capture noisily finegray_predict double H0, basecshazard timevar(h)
            local hrc = _rc
            display "C2_P02_H0_RC=" `hrc'
            assert `hrc' == 0 & !missing(H0[1]) & H0[1]>0
            if `hrc' == 0 & !missing(C2bshift) & abs(C2bshift)>1e-8 & e(converged)==1 {
                scalar C2profile = 710/C2bshift
                scalar C2h0 = H0[1]
                display "C2_P02_H0=" %21.17g C2h0
                if !missing(C2h0) & C2h0>0 {
                    scalar C2lambda = exp(ln(C2h0)+C2bshift*C2profile)
                    scalar C2expected = 1-exp(-C2lambda)
                    assert !missing(C2expected) & C2expected>0 & C2expected<1
                    display "C2_P02_NONTRIVIAL_ORACLE=" (!missing(C2expected) & C2expected>0 & C2expected<1)
                    local xp : display %21x C2profile
                    display "C2_P02_PROFILE=" %21.17g C2profile
                    display "C2_P02_LAMBDA=" %21.17g C2lambda
                    display "C2_P02_EXPECTED_CIF=" %21.17g C2expected
                    capture noisily finegray_cif, at(x=`xp') attime(.1) nograph
                    local cifrc = _rc
                    display "C2_P02_CURVE_RC=" `cifrc'
                    assert `cifrc' == 0
                    if `cifrc' == 0 {
                        matrix C2curve = r(table)
                        assert !missing(C2curve[1,2],C2expected) & abs(C2curve[1,2]-C2expected)<1e-10
                        matrix list C2curve, format(%21.17g)
                    }
                    replace x = C2profile in 1
                    capture noisily finegray_predict double F, cif timevar(h)
                    local predrc = _rc
                    display "C2_P02_PREDICT_RC=" `predrc'
                    assert `predrc' == 0
                    if `predrc' == 0 {
                        display "C2_P02_PREDICT_CIF=" %21.17g F[1]
                        assert !missing(F[1], C2expected) & reldif(F[1],C2expected)<1e-10
                        display "C2_P02_ORACLE_ASSERT_RC=" _rc
                    }
                }
            }
        }
    }
}

}
local test_rc=_rc
if `test_rc' == 0 {
    local ++pass_count
    display as result "PASS: N4"
}
else {
    local ++fail_count
    display as error "FAIL: N4 rc=`test_rc'"
}

**# N5: P019 finite cloglog endpoint limits, both public paths
local ++test_count
capture noisily {
clear
input double time byte status double x
1   1 -1
1   1  1
2   1 -1
2   1  1
3   1 -1
3   1  1
1.5 2 -1
1.5 2  1
2.5 2 -1
2.5 2  1
4   0 -1
4   0  1
.5  0 -10000
.5  0  10000
end
gen long id = _n
stset time, failure(status) id(id)
finegray x, compete(status) cause(1) nolog
matrix list e(b)
assert abs(_b[x]) < 1e-12
finegray_cif, at(x=10000) attime(3) ci nograph
matrix C = r(table)
assert !missing(C[1,2],C[1,3],C[1,4],C[1,5])
assert abs(C[1,2]-(1-exp(-37/60)))<1e-10 & C[1,4]==0 & C[1,5]==1
generate double horizon=3
finegray_predict double pp, cif ci timevar(horizon)
assert !missing(pp,pp_lci,pp_uci) if abs(x)==10000
assert abs(pp-(1-exp(-37/60)))<1e-10 & pp_lci==0 & pp_uci==1 if abs(x)==10000

}
local test_rc=_rc
if `test_rc' == 0 {
    local ++pass_count
    display as result "PASS: N5"
}
else {
    local ++fail_count
    display as error "FAIL: N5 rc=`test_rc'"
}
**# N6: TVC shifted origin, cached and rebuilt baseline routes
local ++test_count
capture noisily {
    clear
    set seed 657021
    set obs 300
    generate double z=rnormal()
    generate double u=-ln(runiform())
    generate double te=cond(u<=.3*exp(-.5*z),u/(.3*exp(-.5*z)),1+(u-.3*exp(-.5*z))/(.6*exp(.8*z)))
    generate double t=min(te,4)
    generate byte cause=cond(te<4,1,0)
    generate double x=z
    stset t, failure(cause==1)
    tempfile dat
    save `dat'
    foreach shift in 0 350 700 {
        use `dat',clear
        replace x=z+`shift'
        quietly finegray x, compete(cause) cause(1) tvc(x) tsplit(1) basehaz nolog
        assert e(converged)==1
        finegray_predict double posted, cif
        quietly finegray x, compete(cause) cause(1) tvc(x) tsplit(1) nolog
        assert e(converged)==1
        matrix B=e(b)
        finegray_predict double cached, cif
        * No competing events or censoring before 4. Independently sum exact
        * event-risk-set increments on the centered covariate scale.
        mata: Z=st_data(.,"z");tt=st_data(.,"t");cc=st_data(.,"cause");beta=st_matrix("B");ev=select(tt,cc:==1);ev=uniqrows(sort(ev,1));out=J(rows(tt),1,0);for(k=1;k<=rows(ev);k++){j=(ev[k]<=1 ? 1 : 2);risk=select(Z,tt:>=ev[k]);den=sum(exp(risk:*beta[j]));dn=sum((tt:==ev[k]):*(cc:==1));for(i=1;i<=rows(tt);i++){if(tt[i]>=ev[k])out[i]=out[i]+dn*exp(Z[i]*beta[j])/den;}};st_addvar("double","oracle");st_store(.,"oracle",1:-exp(-out))
        assert !missing(posted,cached,oracle) & abs(posted-oracle)<1e-10 & abs(cached-oracle)<1e-10
        local profile : display %21x x[1]
        local horizon : display %21x t[1]
        finegray_cif, at(x=`profile') attime(`horizon') nograph
        matrix curve=r(table)
        assert !missing(curve[1,2],oracle[1]) & abs(curve[1,2]-oracle[1])<1e-10
        mata: _finegray_bh_cache = J(0,2,.)
        mata: _finegray_bh_key = ""
        finegray_predict double rebuilt, cif
        assert !missing(rebuilt,oracle) & abs(rebuilt-oracle)<1e-10
    }
}
local test_rc=_rc
if `test_rc'==0 {
    local ++pass_count
    display as result "PASS: N6"
}
else {
    local ++fail_count
    display as error "FAIL: N6 rc=`test_rc'"
}

**# N7: Exact boundary mass on two baseline strata
* guard: strata-specific boundary lookup retains the same interval tie rule.
local ++test_count
capture noisily {
    clear
    set obs 200
    generate byte k=mod(_n-191,10)+1 if _n>190
    generate byte status=(_n<=100 | (_n>190 & k<=4))
    generate double x=cond(_n<=100,_n<=51,cond(_n<=190,_n<=144,k<=3 | inlist(k,5,6)))+1.1
    generate double t=cond(_n<=190,1,2)+cond(status==0,.5,0)
    generate long original=_n
    expand 2
    bysort original: generate byte bs=_n
    generate long id=_n
    stset t, failure(status) id(id)
    quietly finegray x, compete(status) cause(1) tvc(x) tsplit(1) bstrata(bs) basehaz nolog
    assert e(converged)==1
    assert abs(_b[tvc1:x]-ln(51/49))<1e-6
    assert abs(_b[tvc2:x]-ln(3))<1e-6
    * Two identical strata: score1=102-200*logistic(b1), score2=6-8*logistic(b2).
    * Default tolerance reaches the optimum; 1e-12 stalls honestly on an ll
    * rounding floor (decrement2.50e-12), so this guard uses the supported default.
    scalar score1=102-200*invlogit(_b[tvc1:x])
    scalar score2=6-8*invlogit(_b[tvc2:x])
    scalar decrement=score1^2/(200*invlogit(_b[tvc1:x])*(1-invlogit(_b[tvc1:x])))+score2^2/(8*invlogit(_b[tvc2:x])*(1-invlogit(_b[tvc2:x])))
    assert !missing(decrement) & decrement<1e-12
    scalar slope=_b[tvc1:x]
    generate double horizon=1
    finegray_predict double hc, basecshazard timevar(horizon)
    generate double want=1-exp(-hc*exp(slope*41.1))
    replace x=41.1
    finegray_predict double pp,cif timevar(horizon)
    assert !missing(pp,want) & abs(pp-want)<1e-10
}
local test_rc=_rc
if `test_rc'==0 {
    local ++pass_count
    display as result "PASS: N7"
}
else {
    local ++fail_count
    display as error "FAIL: N7 rc=`test_rc'"
}

**# N9: Single baseline stratum code7, cold Mata reload and unknown refusal
* guard: a compact baseline still retains the actual numeric stratum identity.
local ++test_count
capture noisily {
    clear
    set obs 200
    generate byte k=mod(_n-191,10)+1 if _n>190
    generate byte status=(_n<=100 | (_n>190 & k<=4))
    generate double x=cond(_n<=100,_n<=51,cond(_n<=190,_n<=144,k<=3 | inlist(k,5,6)))+1.1
    generate double t=cond(_n<=190,1,2)+cond(status==0,.5,0)
    generate long original=_n
    expand 2
    generate byte bs=7
    generate long id=_n
    stset t, failure(status) id(id)
    quietly finegray x, compete(status) cause(1) tvc(x) tsplit(1) bstrata(bs) basehaz tolerance(1e-12) nolog
    assert e(converged)==1
    assert abs(_b[tvc1:x]-ln(51/49))<1e-6
    scalar slope=_b[tvc1:x]
    generate double horizon=1
    finegray_predict double hc, basecshazard timevar(horizon)
    generate double want=1-exp(-hc*exp(slope*41.1))
    mata: mata clear
    replace x=41.1
    finegray_predict double pp,cif timevar(horizon)
    assert !missing(pp,want) & abs(pp-want)<1e-10
    replace bs=8
    capture finegray_predict double unknown, cif timevar(horizon)
    assert _rc==459
    capture confirm variable unknown
    assert _rc==111
    do "`qa_dir'/_qa_state.do"
}
local test_rc=_rc
if `test_rc'==0 {
    local ++pass_count
    display as result "PASS: N9"
}
else {
    local ++fail_count
    display as error "FAIL: N9 rc=`test_rc'"
}
* Load fingerprint functions even when the cold-Mata numerical assertion failed.
do "`qa_dir'/_qa_state.do"

**# N8: Predictor and curve preserve caller state on success and error
* guard: new numeric helper paths preserve the existing state contract.
local ++test_count
capture noisily {
    clear
    set obs 200
    generate long id=_n
    generate byte x=(_n>100)
    generate double t=cond(_n<=50 | inrange(_n,101,125),1,2)
    generate byte status=(t==1)
    stset t, failure(status) id(id)
    quietly finegray x, compete(status) cause(1) basehaz tolerance(1e-12) nolog
    scalar cifv=17
    matrix _CI=(71,72)
    qa_state_snapshot, tag(predok)
    finegray_predict double pp,cif
    qa_state_compare, tag(predok) allow(data r)
    qa_state_snapshot, tag(prederr)
    capture finegray_predict double bad,cif attime(1)
    assert _rc==198
    qa_state_compare, tag(prederr) allow(r)
    qa_state_snapshot, tag(curveok)
    finegray_cif,at(x=1) attime(1) ci nograph
    qa_state_compare, tag(curveok) allow(r)
    qa_state_snapshot, tag(curveerr)
    capture finegray_cif,at(x=1) attime(1) ci level(101) nograph
    assert _rc==198
    qa_state_compare, tag(curveerr) allow(r)
}
local test_rc=_rc
if `test_rc'==0 {
    local ++pass_count
    display as result "PASS: N8"
}
else {
    local ++fail_count
    display as error "FAIL: N8 rc=`test_rc'"
}

**# N10: Legacy resident marker reloads at baseline and residual first calls
* A legacy resident engine has _finegray_mata_ok() but lacks numeric readiness.
* Removing only numeric readiness reproduces that public loader boundary.
local ++test_count
capture noisily {
    clear
    set obs 200
    generate long id=_n
    generate byte x=(_n>100)
    generate double t=cond(_n<=50 | inrange(_n,101,125),1,2)
    generate byte status=(t==1)
    stset t, failure(status) id(id)
    quietly finegray x, compete(status) cause(1) basehaz tolerance(1e-12) nolog
    assert e(converged)==1 & abs(_b[x]+ln(2))<1e-10
    mata: qa_numeric_user=(17,23)
    capture mata: mata drop _finegray_numeric_ok()
    mata: _finegray_mata_ok()
    qa_state_snapshot, tag(warmbase)
    finegray_predict double hh, basecshazard
    qa_state_compare, tag(warmbase) allow(data r)
    assert !missing(hh) & abs(hh-.5)<1e-10
    mata: _finegray_numeric_ok()
    mata: assert(all(qa_numeric_user :== (17,23)))
    capture mata: mata drop _finegray_numeric_ok()
    mata: _finegray_mata_ok()
    qa_state_snapshot, tag(warmsch)
    finegray_predict double sch, schoenfeld
    qa_state_compare, tag(warmsch) allow(data r)
    assert !missing(sch) & abs(sch-(x-1/3))<1e-10 if status==1
    assert missing(sch) if status==0
    mata: _finegray_numeric_ok()
    mata: assert(all(qa_numeric_user :== (17,23)))
    mata: mata drop qa_numeric_user
}
local test_rc=_rc
if `test_rc'==0 {
    local ++pass_count
    display as result "PASS: N10"
}
else {
    local ++fail_count
    display as error "FAIL: N10 rc=`test_rc'"
}

sysdir set PLUS "`orig_plus'"
sysdir set PERSONAL "`orig_personal'"
discard
capture shell rm -rf "`plus_dir'" "`personal_dir'"
display as result "RESULT: test_finegray_numeric_prediction tests=`test_count' pass=`pass_count' fail=`fail_count'"
log close
if `fail_count' exit 1
