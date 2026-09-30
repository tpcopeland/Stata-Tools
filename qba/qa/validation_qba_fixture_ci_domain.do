*! validation_qba_fixture_ci_domain.do -- exact CI-limit E-values and domain refusals
*! Author: Timothy P Copeland, Karolinska Institutet
* Ding/VanderWeele primary source fetched2026-09-30, Result1 and CI illustration:
* https://arxiv.org/html/1507.03984 . Independent oracle numerically solves
* the equal-strength sharp bounding equation z*z/(2*z-1)=RR; it does not use
* the command's square-root expression. Null-containing limits have target1.
version 16.0
clear all
set more off
capture log close _all
log using validation_qba_fixture_ci_domain.log, text replace
local pkg_dir=substr("`c(pwd)'",1,strlen("`c(pwd)'")-3)
adopath ++ "`pkg_dir'"
do _qa_fx_a6.do
do _qa_state.do
local tests 0
local pass 0
local fail 0
python:
from sfi import Macro
from pathlib import Path

def _qba_equal_strength(r):
    r=max(r,1/r)
    lo,hi=1.,2*r+1
    for _ in range(120):
        z=(lo+hi)/2
        if z*z/(2*z-1)<r: lo=z
        else: hi=z
    return (lo+hi)/2

def _qba_ci_oracle():
    observed=float(Macro.getLocal('observed'))
    bound=float(Macro.getLocal('bound'))
    target=1. if (observed>=1 and bound<=1) or (observed<1 and bound>=1) else _qba_equal_strength(bound)
    Macro.setLocal('truth_ci',format(target,'.17g'))
    Macro.setLocal('truth_point',format(_qba_equal_strength(observed),'.17g'))
end

**# risk 0.000001
local ++tests
capture noisily {
    qa_fx_a6_bias, clear seed(37)
    local observed=(true_n[1]/(true_n[1]+true_n[2]))/(true_n[3]/(true_n[3]+true_n[4]))
    local bound 0.000001
    python: _qba_ci_oracle()
    qa_state_snapshot, tag(qba_ci)
    * expect: EXACT
    quietly qba_confound, estimate(`observed') measure(RR) evalue ci_bound(0.000001)
    assert !missing(r(evalue),r(evalue_ci),r(evalue_rr))
    assert abs(r(evalue)-`truth_point')<1e-11
    assert abs(r(evalue_ci)-`truth_ci')<1e-11
    assert abs(r(evalue_rr)-`observed')<1e-14 & `"`r(evalue_conv)'"'=="none"
    qa_state_compare, tag(qba_ci)
}
local outcome=_rc
capture log close qba_cicause
if `outcome' {
    local ++fail
    display as error "FAIL: risk 0.000001 rc=" `outcome'
}
else {
    local ++pass
    display as result "PASS: risk 0.000001"
}

**# risk .5
local ++tests
capture noisily {
    qa_fx_a6_bias, clear seed(37)
    local observed=(true_n[1]/(true_n[1]+true_n[2]))/(true_n[3]/(true_n[3]+true_n[4]))
    local bound .5
    python: _qba_ci_oracle()
    qa_state_snapshot, tag(qba_ci)
    * expect: EXACT
    quietly qba_confound, estimate(`observed') measure(RR) evalue ci_bound(.5)
    assert !missing(r(evalue),r(evalue_ci),r(evalue_rr))
    assert abs(r(evalue)-`truth_point')<1e-11
    assert abs(r(evalue_ci)-`truth_ci')<1e-11
    assert abs(r(evalue_rr)-`observed')<1e-14 & `"`r(evalue_conv)'"'=="none"
    qa_state_compare, tag(qba_ci)
}
local outcome=_rc
capture log close qba_cicause
if `outcome' {
    local ++fail
    display as error "FAIL: risk .5 rc=" `outcome'
}
else {
    local ++pass
    display as result "PASS: risk .5"
}

**# risk 1
local ++tests
capture noisily {
    qa_fx_a6_bias, clear seed(37)
    local observed=(true_n[1]/(true_n[1]+true_n[2]))/(true_n[3]/(true_n[3]+true_n[4]))
    local bound 1
    python: _qba_ci_oracle()
    qa_state_snapshot, tag(qba_ci)
    * expect: EXACT
    quietly qba_confound, estimate(`observed') measure(RR) evalue ci_bound(1)
    assert !missing(r(evalue),r(evalue_ci),r(evalue_rr))
    assert abs(r(evalue)-`truth_point')<1e-11
    assert abs(r(evalue_ci)-`truth_ci')<1e-11
    assert abs(r(evalue_rr)-`observed')<1e-14 & `"`r(evalue_conv)'"'=="none"
    qa_state_compare, tag(qba_ci)
}
local outcome=_rc
capture log close qba_cicause
if `outcome' {
    local ++fail
    display as error "FAIL: risk 1 rc=" `outcome'
}
else {
    local ++pass
    display as result "PASS: risk 1"
}

**# risk 1.1
local ++tests
capture noisily {
    qa_fx_a6_bias, clear seed(37)
    local observed=(true_n[1]/(true_n[1]+true_n[2]))/(true_n[3]/(true_n[3]+true_n[4]))
    local bound 1.1
    python: _qba_ci_oracle()
    qa_state_snapshot, tag(qba_ci)
    * expect: EXACT
    quietly qba_confound, estimate(`observed') measure(RR) evalue ci_bound(1.1)
    assert !missing(r(evalue),r(evalue_ci),r(evalue_rr))
    assert abs(r(evalue)-`truth_point')<1e-11
    assert abs(r(evalue_ci)-`truth_ci')<1e-11
    assert abs(r(evalue_rr)-`observed')<1e-14 & `"`r(evalue_conv)'"'=="none"
    qa_state_compare, tag(qba_ci)
}
local outcome=_rc
capture log close qba_cicause
if `outcome' {
    local ++fail
    display as error "FAIL: risk 1.1 rc=" `outcome'
}
else {
    local ++pass
    display as result "PASS: risk 1.1"
}

**# risk 100
local ++tests
capture noisily {
    qa_fx_a6_bias, clear seed(37)
    local observed=(true_n[1]/(true_n[1]+true_n[2]))/(true_n[3]/(true_n[3]+true_n[4]))
    local bound 100
    python: _qba_ci_oracle()
    qa_state_snapshot, tag(qba_ci)
    * expect: EXACT
    quietly qba_confound, estimate(`observed') measure(RR) evalue ci_bound(100)
    assert !missing(r(evalue),r(evalue_ci),r(evalue_rr))
    assert abs(r(evalue)-`truth_point')<1e-11
    assert abs(r(evalue_ci)-`truth_ci')<1e-11
    assert abs(r(evalue_rr)-`observed')<1e-14 & `"`r(evalue_conv)'"'=="none"
    qa_state_compare, tag(qba_ci)
}
local outcome=_rc
capture log close qba_cicause
if `outcome' {
    local ++fail
    display as error "FAIL: risk 100 rc=" `outcome'
}
else {
    local ++pass
    display as result "PASS: risk 100"
}

**# risk 0
local ++tests
capture noisily {
    qa_fx_a6_bias, clear seed(37)
    local observed=(true_n[1]/(true_n[1]+true_n[2]))/(true_n[3]/(true_n[3]+true_n[4]))
    local bound 0
    qa_state_snapshot, tag(qba_ci)
    * expect: REFUSED
    tempfile causefile
    capture log close qba_cicause
    log using `"`causefile'"', text replace name(qba_cicause)
    capture noisily qba_confound, estimate(`observed') measure(RR) evalue ci_bound(0)
    local call_rc=_rc
    log close qba_cicause
    assert `call_rc'==198
    python: assert 'ci_bound() must be > 0' in Path(Macro.getLocal("causefile")).read_text()
    qa_state_compare, tag(qba_ci)
}
local outcome=_rc
capture log close qba_cicause
if `outcome' {
    local ++fail
    display as error "FAIL: risk 0 rc=" `outcome'
}
else {
    local ++pass
    display as result "PASS: risk 0"
}

**# risk -1
local ++tests
capture noisily {
    qa_fx_a6_bias, clear seed(37)
    local observed=(true_n[1]/(true_n[1]+true_n[2]))/(true_n[3]/(true_n[3]+true_n[4]))
    local bound -1
    qa_state_snapshot, tag(qba_ci)
    * expect: REFUSED
    tempfile causefile
    capture log close qba_cicause
    log using `"`causefile'"', text replace name(qba_cicause)
    capture noisily qba_confound, estimate(`observed') measure(RR) evalue ci_bound(-1)
    local call_rc=_rc
    log close qba_cicause
    assert `call_rc'==198
    python: assert 'ci_bound() must be > 0' in Path(Macro.getLocal("causefile")).read_text()
    qa_state_compare, tag(qba_ci)
}
local outcome=_rc
capture log close qba_cicause
if `outcome' {
    local ++fail
    display as error "FAIL: risk -1 rc=" `outcome'
}
else {
    local ++pass
    display as result "PASS: risk -1"
}

**# risk .
local ++tests
capture noisily {
    qa_fx_a6_bias, clear seed(37)
    local observed=(true_n[1]/(true_n[1]+true_n[2]))/(true_n[3]/(true_n[3]+true_n[4]))
    local bound .
    qa_state_snapshot, tag(qba_ci)
    * expect: REFUSED
    tempfile causefile
    capture log close qba_cicause
    log using `"`causefile'"', text replace name(qba_cicause)
    capture noisily qba_confound, estimate(`observed') measure(RR) evalue ci_bound(.)
    local call_rc=_rc
    log close qba_cicause
    assert `call_rc'==198
    python: assert 'ci_bound() must be > 0' in Path(Macro.getLocal("causefile")).read_text()
    qa_state_compare, tag(qba_ci)
}
local outcome=_rc
capture log close qba_cicause
if `outcome' {
    local ++fail
    display as error "FAIL: risk . rc=" `outcome'
}
else {
    local ++pass
    display as result "PASS: risk ."
}

**# risk .a
local ++tests
capture noisily {
    qa_fx_a6_bias, clear seed(37)
    local observed=(true_n[1]/(true_n[1]+true_n[2]))/(true_n[3]/(true_n[3]+true_n[4]))
    local bound .a
    qa_state_snapshot, tag(qba_ci)
    * expect: REFUSED
    tempfile causefile
    capture log close qba_cicause
    log using `"`causefile'"', text replace name(qba_cicause)
    capture noisily qba_confound, estimate(`observed') measure(RR) evalue ci_bound(.a)
    local call_rc=_rc
    log close qba_cicause
    assert `call_rc'==198
    python: assert 'ci_bound() must be > 0' in Path(Macro.getLocal("causefile")).read_text()
    qa_state_compare, tag(qba_ci)
}
local outcome=_rc
capture log close qba_cicause
if `outcome' {
    local ++fail
    display as error "FAIL: risk .a rc=" `outcome'
}
else {
    local ++pass
    display as result "PASS: risk .a"
}

**# protective .8
local ++tests
capture noisily {
    qa_fx_a6_bias, clear seed(37)
    local observed=(true_n[1]/(true_n[1]+true_n[2]))/(true_n[3]/(true_n[3]+true_n[4]))
    local observed=1/`observed'
    local bound .8
    python: _qba_ci_oracle()
    qa_state_snapshot, tag(qba_ci)
    * expect: EXACT
    quietly qba_confound, estimate(`observed') measure(RR) evalue ci_bound(.8)
    assert !missing(r(evalue),r(evalue_ci),r(evalue_rr))
    assert abs(r(evalue)-`truth_point')<1e-11
    assert abs(r(evalue_ci)-`truth_ci')<1e-11
    assert abs(r(evalue_rr)-`observed')<1e-14 & `"`r(evalue_conv)'"'=="none"
    qa_state_compare, tag(qba_ci)
}
local outcome=_rc
capture log close qba_cicause
if `outcome' {
    local ++fail
    display as error "FAIL: protective .8 rc=" `outcome'
}
else {
    local ++pass
    display as result "PASS: protective .8"
}

**# protective 1
local ++tests
capture noisily {
    qa_fx_a6_bias, clear seed(37)
    local observed=(true_n[1]/(true_n[1]+true_n[2]))/(true_n[3]/(true_n[3]+true_n[4]))
    local observed=1/`observed'
    local bound 1
    python: _qba_ci_oracle()
    qa_state_snapshot, tag(qba_ci)
    * expect: EXACT
    quietly qba_confound, estimate(`observed') measure(RR) evalue ci_bound(1)
    assert !missing(r(evalue),r(evalue_ci),r(evalue_rr))
    assert abs(r(evalue)-`truth_point')<1e-11
    assert abs(r(evalue_ci)-`truth_ci')<1e-11
    assert abs(r(evalue_rr)-`observed')<1e-14 & `"`r(evalue_conv)'"'=="none"
    qa_state_compare, tag(qba_ci)
}
local outcome=_rc
capture log close qba_cicause
if `outcome' {
    local ++fail
    display as error "FAIL: protective 1 rc=" `outcome'
}
else {
    local ++pass
    display as result "PASS: protective 1"
}

**# protective 1.2
local ++tests
capture noisily {
    qa_fx_a6_bias, clear seed(37)
    local observed=(true_n[1]/(true_n[1]+true_n[2]))/(true_n[3]/(true_n[3]+true_n[4]))
    local observed=1/`observed'
    local bound 1.2
    python: _qba_ci_oracle()
    qa_state_snapshot, tag(qba_ci)
    * expect: EXACT
    quietly qba_confound, estimate(`observed') measure(RR) evalue ci_bound(1.2)
    assert !missing(r(evalue),r(evalue_ci),r(evalue_rr))
    assert abs(r(evalue)-`truth_point')<1e-11
    assert abs(r(evalue_ci)-`truth_ci')<1e-11
    assert abs(r(evalue_rr)-`observed')<1e-14 & `"`r(evalue_conv)'"'=="none"
    qa_state_compare, tag(qba_ci)
}
local outcome=_rc
capture log close qba_cicause
if `outcome' {
    local ++fail
    display as error "FAIL: protective 1.2 rc=" `outcome'
}
else {
    local ++pass
    display as result "PASS: protective 1.2"
}

**# without_evalue 1.1
local ++tests
capture noisily {
    qa_fx_a6_bias, clear seed(37)
    local observed=(true_n[1]/(true_n[1]+true_n[2]))/(true_n[3]/(true_n[3]+true_n[4]))
    local bound 1.1
    qa_state_snapshot, tag(qba_ci)
    * expect: REFUSED
    tempfile causefile
    capture log close qba_cicause
    log using `"`causefile'"', text replace name(qba_cicause)
    capture noisily qba_confound, estimate(`observed') measure(RR) ci_bound(1.1)
    local call_rc=_rc
    log close qba_cicause
    assert `call_rc'==198
    python: assert 'ci_bound() requires evalue' in Path(Macro.getLocal("causefile")).read_text()
    qa_state_compare, tag(qba_ci)
}
local outcome=_rc
capture log close qba_cicause
if `outcome' {
    local ++fail
    display as error "FAIL: without_evalue 1.1 rc=" `outcome'
}
else {
    local ++pass
    display as result "PASS: without_evalue 1.1"
}

display "RESULT: validation_qba_fixture_ci_domain tests=`tests' pass=`pass' fail=`fail'"
log close
if `fail' exit 1
