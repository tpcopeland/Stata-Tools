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
do "`qa_dir'/_install_msm_isolated.do" "`pkg_dir'"
do "`qa_dir'/_qa_fx_a3.do"

capture mata: mata drop _fx_msm_oracle()
mata:
void _fx_msm_oracle(string scalar truth0, string scalar truth1, string scalar se0, string scalar se1, string scalar serd, string scalar naivepop)
{
    real scalar z, c, l, aa, q, pl, pa, py, v0, v1, r0, r1, n0, n1, d0, d1
    r0=st_numscalar(truth0); r1=st_numscalar(truth1)
    v0=v1=n0=n1=d0=d1=0
    for (z=0;z<=1;z++) for (c=1;c<=3;c++) for (l=0;l<=1;l++) {
        pl=1/(1+exp(.5-z))
        q=(l ? pl : 1-pl)/6
        pa=1/(1+exp(.3-.8*l-.4*z))
        for (aa=0;aa<=1;aa++) {
            py=1/(1+exp(3+.7*aa-.9*l-.5*z-.3*(c==2)-.5*(c==3)))
            if (aa==0) {
                v0=v0+q*(py*(1-py)+(py-r0)^2)/(1-pa)
                n0=n0+q*(1-pa)*py; d0=d0+q*(1-pa)
            }
            else {
                v1=v1+q*(py*(1-py)+(py-r1)^2)/pa
                n1=n1+q*pa*py; d1=d1+q*pa
            }
        }
    }
    st_numscalar(se0,sqrt(v0/100000))
    st_numscalar(se1,sqrt(v1/100000))
    st_numscalar(serd,sqrt((v0+v1)/100000))
    st_numscalar(naivepop,n1/d1-n0/d0)
}
end

local test_count 0
local pass_count 0
local fail_count 0

**# F: single-decision IPW recovers enumerated intervention risks
local ++test_count
capture noisily {
    qa_fx_a3_seq, clear n(100000) k(1) seed(9103)
    tempname truth0 truth1 truthrd crude0 crude1 se0 se1 serd naivepop n0 n1
    scalar `truth0' = r(truth_risk0)
    scalar `truth1' = r(truth_risk1)
    scalar `truthrd' = r(truth_rd)
    * Independent oracle-weight ratio-estimator influence variance. Correctly
    * estimated propensity scores project out their score component; this
    * known-propensity variance supplies a conservative recovery envelope.
    mata: _fx_msm_oracle("`truth0'", "`truth1'", "`se0'", "`se1'", "`serd'", "`naivepop'")
    quietly count if a == 0
    scalar `n0' = r(N)
    quietly count if a == 1
    scalar `n1' = r(N)
    quietly summarize y if a == 0, meanonly
    scalar `crude0' = r(mean)
    quietly summarize y if a == 1, meanonly
    scalar `crude1' = r(mean)
    quietly msm_prepare, id(id) period(period) treatment(a) outcome(y) covariates(l_t) baseline_covariates(l0)
    quietly msm_weight, treat_d_cov(l_t l0) nolog
    quietly msm_fit, model(logistic) period_spec(none) nolog
    quietly msm_predict, times(0) difference samples(20) seed(9103)
    * Six oracle-weight influence SE; no history or MC truth approximation.
    tempname p
    matrix `p' = r(predictions)
    assert !missing(`p'[1,2], `p'[1,5], `truth0', `truth1')
    assert !missing(`se0', `se1', `serd') & min(`se0', `se1', `serd') > 0
    assert abs(`p'[1,2]-`truth0') < 6*`se0'
    assert abs(`p'[1,5]-`truth1') < 6*`se1'
    assert abs(r(rd_0)-`truthrd') < 6*`serd'
    assert !missing(`naivepop', `crude1', `crude0')
    assert abs(`naivepop'-`truthrd') > 4*`serd'
    assert abs((`crude1'-`crude0')-`naivepop') < 6*sqrt(.25/`n0'+.25/`n1')
    assert abs(r(rd_0)-`truthrd') < abs((`crude1'-`crude0')-`truthrd')
    display as text "RECOVERY: seq-k1 truth0=" `truth0' " truth1=" `truth1' ///
        " estimate0=" `p'[1,2] " estimate1=" `p'[1,5] " SE0=" `se0' " SE1=" `se1' " SERD=" `serd' ///
        " naivepopulation=" `naivepop' " naiveobserved=" `crude1'-`crude0'

}
if _rc == 0 {
    local ++pass_count
    display as result "PASS: F: single-decision IPW recovers enumerated intervention risks"
}
else {
    local ++fail_count
    display as error "FAIL: F: single-decision IPW recovers enumerated intervention risks (rc=`=_rc')"
}

do "`qa_dir'/_record_qa_result.do" validation_fixture_recovery `test_count' `pass_count' `fail_count' 0
display as text "RESULT: validation_fixture_recovery tests=`test_count' pass=`pass_count' fail=`fail_count' skip=0"
capture log close _all
if `fail_count' > 0 exit 1
