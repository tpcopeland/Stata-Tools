* validation_fixture_recovery.do -- canonical F/U fixture adoption (2026-09-30)
* Author: Timothy P Copeland, Karolinska Institutet
* guard: expected green at pre-fix ref; catalog adoption, not a bug-fix receipt.
version 16.0
clear all
set more off
set varabbrev off
set processors 1
capture log close _all
local qa_dir "`c(pwd)'"
local pkg_dir "`qa_dir'/.."
do "`qa_dir'/_qa_bootstrap.do"
do "`qa_dir'/_qa_fx_a1.do"

capture mata: mata drop _fx_gc_oracle()
mata:
void _fx_gc_oracle(string scalar cells, string scalar se0, string scalar se1, string scalar serd, string scalar naivepop)
{
    real matrix C, I, V
    real rowvector X, G0, G1, D
    real scalar j, aa, pp, pa, c0, c1, d0, d1
    C=st_matrix(cells); I=J(6,6,0); G0=G1=J(1,6,0)
    c0=c1=d0=d1=0
    for (j=1; j<=rows(C); j++) {
        c0=c0+(1-C[j,4])*C[j,5]; d0=d0+1-C[j,4]
        c1=c1+C[j,4]*C[j,6]; d1=d1+C[j,4]
        for (aa=0; aa<=1; aa++) {
            X=(aa,C[j,1],C[j,2],C[j,3]==2,C[j,3]==3,1)
            pp=C[j,5+aa]; pa=aa ? C[j,4] : 1-C[j,4]
            I=I+pa*pp*(1-pp)*quadcross(X,X)/rows(C)
            if (aa==0) G0=G0+pp*(1-pp)*X/rows(C)
            else G1=G1+pp*(1-pp)*X/rows(C)
        }
    }
    V=invsym(100008*I); D=G1-G0
    st_numscalar(se0,sqrt(G0*V*G0'))
    st_numscalar(se1,sqrt(G1*V*G1'))
    st_numscalar(serd,sqrt(D*V*D'))
    st_numscalar(naivepop,c1/d1-c0/d0)
}
end

local test_count 0
local pass_count 0
local fail_count 0
* Method: Daniel et al. (2011), Stata Journal 11:479-517,
* https://www.stata-journal.com/article.html?article=st0238 (fetched 2026-09-30).
* Exact SAT cells use all 1200 ids and minsim; no empirical resampling of the
* target population and no outcome-draw Monte Carlo noise at the point estimate.

**# F: saturated g-formula returns exact standardized risks
local ++test_count
capture noisily {
    qa_fx_a1_sat, clear
    tempname t0 t1 trd b
    scalar `t0' = r(truth_risk0)
    scalar `t1' = r(truth_risk1)
    scalar `trd' = r(truth_rd)
    expand 10
    replace id = _n
    expand 2
    bysort id: gen byte time = _n
    replace y = . if time == 1
    quietly gcomp y a s x2, outcome(y) idvar(id) tvar(time) eofu fixedcovariates(s x2) ///
        intvars(a) interventions(a=1, a=0) commands(a: logit, y: logit) ///
        equations(a: i.s##i.x2, y: i.a##i.s##i.x2) sim(1200) samples(2) seed(9141) minsim
    matrix `b' = e(b)
    assert colnumb(`b', "PO1") == 1 & colnumb(`b', "PO2") == 2
    assert !missing(`b'[1,1], `b'[1,2], `t0', `t1')
    assert abs(`b'[1,1]-`t1') < 1e-8
    assert abs(`b'[1,2]-`t0') < 1e-8
    assert abs((`b'[1,1]-`b'[1,2])-`trd') < 1e-8
    assert e(N_subjects) == 1200 & e(N_rows) == 2400
    tempfile book
    quietly gcomptab, doseresponse reference(2) sheet("Fixture") xlsx("`book'.xlsx")
    tempname table
    matrix `table' = r(table)
    assert rowsof(`table') == 3 & colsof(`table') == 5
    assert !missing(`table'[1,1], `table'[2,1], `table'[1,5])
    assert abs(`table'[1,1]-`t1') < 1e-8
    assert abs(`table'[2,1]-`t0') < 1e-8
    assert abs(`table'[1,5]-`trd') < 1e-8
    erase "`book'.xlsx"
}
if _rc == 0 {
    local ++pass_count
    display as result "PASS: F: saturated g-formula returns exact standardized risks"
}
else {
    local ++fail_count
    display as error "FAIL: F: saturated g-formula returns exact standardized risks (rc=`=_rc')"
}

**# F: fitted logit recovers catalog population risks
local ++test_count
capture noisily {
    qa_fx_a1_logit, clear tier(recovery) n(100008) seed(9143)
    tempname t0 t1 trd b c0 c1 cells se0 se1 serd naivepop n0 n1
    scalar `t0' = r(truth_risk0)
    scalar `t1' = r(truth_risk1)
    scalar `trd' = r(truth_rd)
    matrix `cells' = r(truth_cells)
    * Independent Fisher-information delta SE for the correctly specified
    * binomial outcome model on the balanced fixed covariate design.
    mata: _fx_gc_oracle("`cells'", "`se0'", "`se1'", "`serd'", "`naivepop'")
    quietly count if a == 0
    scalar `n0' = r(N)
    quietly count if a == 1
    scalar `n1' = r(N)
    quietly summarize y if a == 0, meanonly
    scalar `c0' = r(mean)
    quietly summarize y if a == 1, meanonly
    scalar `c1' = r(mean)
    expand 2
    bysort id: gen byte time = _n
    replace y = . if time == 1
    quietly gcomp y a x1 x2 xcat, outcome(y) idvar(id) tvar(time) eofu fixedcovariates(x1 x2 xcat) ///
        intvars(a) interventions(a=1, a=0) commands(a: logit, y: logit) ///
        equations(a: x1 x2 i.xcat, y: a x1 x2 i.xcat) sim(100008) samples(2) seed(9143) minsim
    matrix `b' = e(b)
    * Six independently derived delta SE; deterministic integration over all ids.
    assert !missing(`b'[1,1], `b'[1,2], `t0', `t1')
    assert !missing(`se0', `se1', `serd') & min(`se0', `se1', `serd') > 0
    assert abs(`b'[1,1]-`t1') < 6*`se1'
    assert abs(`b'[1,2]-`t0') < 6*`se0'
    assert abs((`b'[1,1]-`b'[1,2])-`trd') < 6*`serd'
    assert !missing(`naivepop', `c1', `c0')
    assert abs(`naivepop'-`trd') > 4*`serd'
    assert abs((`c1'-`c0')-`naivepop') < 6*sqrt(.25/`n0'+.25/`n1')
    assert abs((`b'[1,1]-`b'[1,2])-`trd') < abs((`c1'-`c0')-`trd')
    display as text "RECOVERY: logit truth0=" `t0' " truth1=" `t1' ///
        " estimate0=" `b'[1,2] " estimate1=" `b'[1,1] " SE0=" `se0' " SE1=" `se1' " SERD=" `serd' ///
        " naivepopulation=" `naivepop' " naiveobserved=" `c1'-`c0'

}
if _rc == 0 {
    local ++pass_count
    display as result "PASS: F: fitted logit recovers catalog population risks"
}
else {
    local ++fail_count
    display as error "FAIL: F: fitted logit recovers catalog population risks (rc=`=_rc')"
}


**# U: single_level recovers its canonical intervention target
local ++test_count
capture noisily {
    * expect: EXACT
    qa_fx_a1_logit, clear n(100008) seed(9143) perturb(single_level)
    assert "`r(perturb_applied)'" == "single_level"
    tempname t0 t1 trd C se0 se1 serd naivepop b
    scalar `t0' = r(truth_risk0)
    scalar `t1' = r(truth_risk1)
    scalar `trd' = r(truth_rd)
    matrix `C' = r(truth_cells)
    mata: _fx_gc_oracle("`C'", "`se0'", "`se1'", "`serd'", "`naivepop'")
    expand 2
    bysort id: gen byte time = _n
    replace y = . if time == 1
    quietly gcomp y a x1 x2 xcat, outcome(y) idvar(id) tvar(time) eofu fixedcovariates(x1 x2 xcat) ///
        intvars(a) interventions(a=1, a=0) commands(a: logit, y: logit) ///
        equations(a: x1 x2 i.xcat, y: a x1 x2 i.xcat) sim(100008) samples(2) seed(9143) minsim
    matrix `b' = e(b)
    assert e(N_subjects) == 100008 & e(N_rows) == 200016
    assert !missing(`b'[1,1], `b'[1,2], `t0', `t1', `trd', `se0', `se1', `serd')
    assert min(`se0', `se1', `serd') > 0
    assert abs(`b'[1,1]-`t1') < 6*`se1'
    assert abs(`b'[1,2]-`t0') < 6*`se0'
    assert abs((`b'[1,1]-`b'[1,2])-`trd') < 6*`serd'
    display "ORACLE single_level truth0=" %14.10f `t0' " truth1=" %14.10f `t1' " truthRD=" %14.10f `trd'
    display "ORACLE single_level se0=" %14.10f `se0' " se1=" %14.10f `se1' " seRD=" %14.10f `serd'
    matrix list `b'
}
if _rc == 0 {
    local ++pass_count
    display as result "PASS: U: single_level canonical risk recovery"
}
else {
    local ++fail_count
    display as error "FAIL: U: single_level canonical risk recovery (rc=`=_rc')"
}

**# U: near_positivity recovers its canonical intervention target
local ++test_count
capture noisily {
    * expect: EXACT
    qa_fx_a1_logit, clear n(100008) seed(9143) perturb(near_positivity)
    assert "`r(perturb_applied)'" == "near_positivity"
    tempname t0 t1 trd C se0 se1 serd naivepop b
    scalar `t0' = r(truth_risk0)
    scalar `t1' = r(truth_risk1)
    scalar `trd' = r(truth_rd)
    matrix `C' = r(truth_cells)
    mata: _fx_gc_oracle("`C'", "`se0'", "`se1'", "`serd'", "`naivepop'")
    expand 2
    bysort id: gen byte time = _n
    replace y = . if time == 1
    quietly gcomp y a x1 x2 xcat, outcome(y) idvar(id) tvar(time) eofu fixedcovariates(x1 x2 xcat) ///
        intvars(a) interventions(a=1, a=0) commands(a: logit, y: logit) ///
        equations(a: x1 x2 i.xcat, y: a x1 x2 i.xcat) sim(100008) samples(2) seed(9143) minsim
    matrix `b' = e(b)
    assert e(N_subjects) == 100008 & e(N_rows) == 200016
    assert !missing(`b'[1,1], `b'[1,2], `t0', `t1', `trd', `se0', `se1', `serd')
    assert min(`se0', `se1', `serd') > 0
    assert abs(`b'[1,1]-`t1') < 6*`se1'
    assert abs(`b'[1,2]-`t0') < 6*`se0'
    assert abs((`b'[1,1]-`b'[1,2])-`trd') < 6*`serd'
    display "ORACLE near_positivity truth0=" %14.10f `t0' " truth1=" %14.10f `t1' " truthRD=" %14.10f `trd'
    display "ORACLE near_positivity se0=" %14.10f `se0' " se1=" %14.10f `se1' " seRD=" %14.10f `serd'
    matrix list `b'
}
if _rc == 0 {
    local ++pass_count
    display as result "PASS: U: near_positivity canonical risk recovery"
}
else {
    local ++fail_count
    display as error "FAIL: U: near_positivity canonical risk recovery (rc=`=_rc')"
}
display as text "RESULT: validation_fixture_recovery tests=`test_count' pass=`pass_count' fail=`fail_count' skip=0"
capture log close _all
if `fail_count' > 0 exit 1
