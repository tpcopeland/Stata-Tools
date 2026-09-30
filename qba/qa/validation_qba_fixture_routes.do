*! validation_qba_fixture_routes.do -- exact forward-cell adapters and public bias routes
*! Author: Timothy P Copeland, Karolinska Institutet
* Fox et al. (2023), doi:10.1093/ije/dyad053, Methods/Table1, fetched
* 2026-09-30: https://academic.oup.com/ije/article/52/5/1624/7152433
* Point-mass simulation intervals cover systematic error only, not total error.
* Sequential examples are explicit ordered probability adapters plus a separate
* confounding factor, not a claimed joint latent-confounder DGP.
version 16.0
clear all
set more off
capture log close _all
log using "validation_qba_fixture_routes.log", text replace
local pkg_dir=substr("`c(pwd)'",1,strlen("`c(pwd)'")-3)
adopath ++ "`pkg_dir'"
do _qa_fx_a6.do
do _qa_fx_a1.do
do _qa_state.do
local tests 0
local pass 0
local fail 0

**# Exposure OR simple friendly
local ++tests
capture noisily {
    * expect: EXACT
    qa_fx_a6_bias, clear seed(37)
    ereturn clear
    local se=se[1]
    local sp=sp[1]
    local ta=true_n[1]
    local tb=true_n[3]
    local tc=true_n[2]
    local td=true_n[4]
    local target=(`ta' * `td' / (`tb' * `tc'))/1
    * Forward exposure classification separately within cases and noncases.
    local a=`se'*`ta'+(1-`sp')*`tb'
    local b=(1-`se')*`ta'+`sp'*`tb'
    local c=`se'*`tc'+(1-`sp')*`td'
    local d=(1-`se')*`tc'+`sp'*`td'
    qa_state_snapshot, tag(qba_route)
    quietly qba_misclass, a(`a') b(`b') c(`c') d(`d') seca(`se') spca(`sp') secb(`se') spcb(`sp') type(exposure) measure(OR) level(90)
    assert !missing(r(corrected)) & abs(r(corrected)-`target')<1e-12
    assert abs(r(corrected_a)-`ta')<1e-12 & abs(r(corrected_b)-`tb')<1e-12
    assert abs(r(corrected_c)-`tc')<1e-12 & abs(r(corrected_d)-`td')<1e-12
    qa_state_compare, tag(qba_route)

}
if _rc {
    local ++fail
    display as error "FAIL: Exposure OR simple friendly; rc=" _rc
}
else {
    local ++pass
    display as result "PASS: Exposure OR simple friendly"
}

**# Exposure OR pointmass friendly
local ++tests
capture noisily {
    * expect: EXACT
    qa_fx_a6_bias, clear seed(37)
    ereturn clear
    local se=se[1]
    local sp=sp[1]
    local ta=true_n[1]
    local tb=true_n[3]
    local tc=true_n[2]
    local td=true_n[4]
    local target=(`ta' * `td' / (`tb' * `tc'))/1
    * Forward exposure classification separately within cases and noncases.
    local a=`se'*`ta'+(1-`sp')*`tb'
    local b=(1-`se')*`ta'+`sp'*`tb'
    local c=`se'*`tc'+(1-`sp')*`td'
    local d=(1-`se')*`tc'+`sp'*`td'
    qa_state_snapshot, tag(qba_route)
    quietly qba_misclass, a(`a') b(`b') c(`c') d(`d') seca(`se') spca(`sp') secb(`se') spcb(`sp') type(exposure) measure(OR) level(90) reps(100) seed(37) corr(1)
    assert !missing(r(corrected)) & abs(r(corrected)-`target')<1e-12
    assert r(n_valid)==100 & r(reps)==100
    assert !missing(r(mean),r(sd),r(ci_lower),r(ci_upper))
    assert abs(r(mean)-`target')<1e-12 & abs(r(sd))<1e-12
    assert abs(r(ci_lower)-`target')<1e-12 & abs(r(ci_upper)-`target')<1e-12
    qa_state_compare, tag(qba_route) allow(rng)

}
if _rc {
    local ++fail
    display as error "FAIL: Exposure OR pointmass friendly; rc=" _rc
}
else {
    local ++pass
    display as result "PASS: Exposure OR pointmass friendly"
}

**# Exposure RR simple friendly
local ++tests
capture noisily {
    * expect: EXACT
    qa_fx_a6_bias, clear seed(37)
    ereturn clear
    local se=se[1]
    local sp=sp[1]
    local ta=true_n[1]
    local tb=true_n[3]
    local tc=true_n[2]
    local td=true_n[4]
    local target=((`ta'/(`ta'+`tc'))/(`tb'/(`tb'+`td')))/1
    * Forward exposure classification separately within cases and noncases.
    local a=`se'*`ta'+(1-`sp')*`tb'
    local b=(1-`se')*`ta'+`sp'*`tb'
    local c=`se'*`tc'+(1-`sp')*`td'
    local d=(1-`se')*`tc'+`sp'*`td'
    qa_state_snapshot, tag(qba_route)
    quietly qba_misclass, a(`a') b(`b') c(`c') d(`d') seca(`se') spca(`sp') secb(`se') spcb(`sp') type(exposure) measure(RR) level(90)
    assert !missing(r(corrected)) & abs(r(corrected)-`target')<1e-12
    assert abs(r(corrected_a)-`ta')<1e-12 & abs(r(corrected_b)-`tb')<1e-12
    assert abs(r(corrected_c)-`tc')<1e-12 & abs(r(corrected_d)-`td')<1e-12
    qa_state_compare, tag(qba_route)

}
if _rc {
    local ++fail
    display as error "FAIL: Exposure RR simple friendly; rc=" _rc
}
else {
    local ++pass
    display as result "PASS: Exposure RR simple friendly"
}

**# Exposure RR pointmass friendly
local ++tests
capture noisily {
    * expect: EXACT
    qa_fx_a6_bias, clear seed(37)
    ereturn clear
    local se=se[1]
    local sp=sp[1]
    local ta=true_n[1]
    local tb=true_n[3]
    local tc=true_n[2]
    local td=true_n[4]
    local target=((`ta'/(`ta'+`tc'))/(`tb'/(`tb'+`td')))/1
    * Forward exposure classification separately within cases and noncases.
    local a=`se'*`ta'+(1-`sp')*`tb'
    local b=(1-`se')*`ta'+`sp'*`tb'
    local c=`se'*`tc'+(1-`sp')*`td'
    local d=(1-`se')*`tc'+`sp'*`td'
    qa_state_snapshot, tag(qba_route)
    quietly qba_misclass, a(`a') b(`b') c(`c') d(`d') seca(`se') spca(`sp') secb(`se') spcb(`sp') type(exposure) measure(RR) level(90) reps(100) seed(37) corr(1)
    assert !missing(r(corrected)) & abs(r(corrected)-`target')<1e-12
    assert r(n_valid)==100 & r(reps)==100
    assert !missing(r(mean),r(sd),r(ci_lower),r(ci_upper))
    assert abs(r(mean)-`target')<1e-12 & abs(r(sd))<1e-12
    assert abs(r(ci_lower)-`target')<1e-12 & abs(r(ci_upper)-`target')<1e-12
    qa_state_compare, tag(qba_route) allow(rng)

}
if _rc {
    local ++fail
    display as error "FAIL: Exposure RR pointmass friendly; rc=" _rc
}
else {
    local ++pass
    display as result "PASS: Exposure RR pointmass friendly"
}

**# Joint OR misclass selection friendly
local ++tests
capture noisily {
    * expect: EXACT
    qa_fx_a6_bias, clear seed(37)
    ereturn clear
    local se=se[1]
    local sp=sp[1]
    local ta=true_n[1]
    local tb=true_n[3]
    local tc=true_n[2]
    local td=true_n[4]
    local target=(`ta' * `td' / (`tb' * `tc'))/1.5
    * Forward inclusion then outcome classification (reverse of correction).
    local a=`se'*(.5*`ta')+(1-`sp')*`tc'
    local c=(1-`se')*(.5*`ta')+`sp'*`tc'
    local b=`se'*`tb'+(1-`sp')*`td'
    local d=(1-`se')*`tb'+`sp'*`td'
    qa_state_snapshot, tag(qba_route)
    quietly qba_multi, a(`a') b(`b') c(`c') d(`d') seca(`se') spca(`sp') secb(`se') spcb(`sp') corr(-1) mctype(outcome) sela(.5) selb(1) selc(1) seld(1) p1(.5) p0(`=1/6') rrcd(3) order(misclass selection) measure(OR) reps(100) seed(37) level(90)
    assert !missing(r(corrected)) & abs(r(corrected)-`target')<1e-12
    assert r(n_valid)==100 & r(reps)==100
    assert !missing(r(mean),r(sd),r(ci_lower),r(ci_upper))
    assert abs(r(mean)-`target')<1e-12 & abs(r(sd))<1e-12
    assert abs(r(ci_lower)-`target')<1e-12 & abs(r(ci_upper)-`target')<1e-12
    assert r(n_biases)==3 & r(n_draw_invalid)==0 & r(corr)==-1
    qa_state_compare, tag(qba_route) allow(rng)

}
if _rc {
    local ++fail
    display as error "FAIL: Joint OR misclass selection friendly; rc=" _rc
}
else {
    local ++pass
    display as result "PASS: Joint OR misclass selection friendly"
}

**# Joint OR selection misclass friendly
local ++tests
capture noisily {
    * expect: EXACT
    qa_fx_a6_bias, clear seed(37)
    ereturn clear
    local se=se[1]
    local sp=sp[1]
    local ta=true_n[1]
    local tb=true_n[3]
    local tc=true_n[2]
    local td=true_n[4]
    local target=(`ta' * `td' / (`tb' * `tc'))/1.5
    * Forward outcome classification then inclusion.
    local a=.5*(`se'*`ta'+(1-`sp')*`tc')
    local c=(1-`se')*`ta'+`sp'*`tc'
    local b=`se'*`tb'+(1-`sp')*`td'
    local d=(1-`se')*`tb'+`sp'*`td'
    qa_state_snapshot, tag(qba_route)
    quietly qba_multi, a(`a') b(`b') c(`c') d(`d') seca(`se') spca(`sp') secb(`se') spcb(`sp') corr(-1) mctype(outcome) sela(.5) selb(1) selc(1) seld(1) p1(.5) p0(`=1/6') rrcd(3) order(selection misclass) measure(OR) reps(100) seed(37) level(90)
    assert !missing(r(corrected)) & abs(r(corrected)-`target')<1e-12
    assert r(n_valid)==100 & r(reps)==100
    assert !missing(r(mean),r(sd),r(ci_lower),r(ci_upper))
    assert abs(r(mean)-`target')<1e-12 & abs(r(sd))<1e-12
    assert abs(r(ci_lower)-`target')<1e-12 & abs(r(ci_upper)-`target')<1e-12
    assert r(n_biases)==3 & r(n_draw_invalid)==0 & r(corr)==-1
    qa_state_compare, tag(qba_route) allow(rng)

}
if _rc {
    local ++fail
    display as error "FAIL: Joint OR selection misclass friendly; rc=" _rc
}
else {
    local ++pass
    display as result "PASS: Joint OR selection misclass friendly"
}

**# Joint RR misclass selection friendly
local ++tests
capture noisily {
    * expect: EXACT
    qa_fx_a6_bias, clear seed(37)
    ereturn clear
    local se=se[1]
    local sp=sp[1]
    local ta=true_n[1]
    local tb=true_n[3]
    local tc=true_n[2]
    local td=true_n[4]
    local target=((`ta'/(`ta'+`tc'))/(`tb'/(`tb'+`td')))/1.5
    * Forward inclusion then outcome classification (reverse of correction).
    local a=`se'*(.5*`ta')+(1-`sp')*`tc'
    local c=(1-`se')*(.5*`ta')+`sp'*`tc'
    local b=`se'*`tb'+(1-`sp')*`td'
    local d=(1-`se')*`tb'+`sp'*`td'
    qa_state_snapshot, tag(qba_route)
    quietly qba_multi, a(`a') b(`b') c(`c') d(`d') seca(`se') spca(`sp') secb(`se') spcb(`sp') corr(-1) mctype(outcome) sela(.5) selb(1) selc(1) seld(1) p1(.5) p0(`=1/6') rrcd(3) order(misclass selection) measure(RR) reps(100) seed(37) level(90)
    assert !missing(r(corrected)) & abs(r(corrected)-`target')<1e-12
    assert r(n_valid)==100 & r(reps)==100
    assert !missing(r(mean),r(sd),r(ci_lower),r(ci_upper))
    assert abs(r(mean)-`target')<1e-12 & abs(r(sd))<1e-12
    assert abs(r(ci_lower)-`target')<1e-12 & abs(r(ci_upper)-`target')<1e-12
    assert r(n_biases)==3 & r(n_draw_invalid)==0 & r(corr)==-1
    qa_state_compare, tag(qba_route) allow(rng)

}
if _rc {
    local ++fail
    display as error "FAIL: Joint RR misclass selection friendly; rc=" _rc
}
else {
    local ++pass
    display as result "PASS: Joint RR misclass selection friendly"
}

**# Joint RR selection misclass friendly
local ++tests
capture noisily {
    * expect: EXACT
    qa_fx_a6_bias, clear seed(37)
    ereturn clear
    local se=se[1]
    local sp=sp[1]
    local ta=true_n[1]
    local tb=true_n[3]
    local tc=true_n[2]
    local td=true_n[4]
    local target=((`ta'/(`ta'+`tc'))/(`tb'/(`tb'+`td')))/1.5
    * Forward outcome classification then inclusion.
    local a=.5*(`se'*`ta'+(1-`sp')*`tc')
    local c=(1-`se')*`ta'+`sp'*`tc'
    local b=`se'*`tb'+(1-`sp')*`td'
    local d=(1-`se')*`tb'+`sp'*`td'
    qa_state_snapshot, tag(qba_route)
    quietly qba_multi, a(`a') b(`b') c(`c') d(`d') seca(`se') spca(`sp') secb(`se') spcb(`sp') corr(-1) mctype(outcome) sela(.5) selb(1) selc(1) seld(1) p1(.5) p0(`=1/6') rrcd(3) order(selection misclass) measure(RR) reps(100) seed(37) level(90)
    assert !missing(r(corrected)) & abs(r(corrected)-`target')<1e-12
    assert r(n_valid)==100 & r(reps)==100
    assert !missing(r(mean),r(sd),r(ci_lower),r(ci_upper))
    assert abs(r(mean)-`target')<1e-12 & abs(r(sd))<1e-12
    assert abs(r(ci_lower)-`target')<1e-12 & abs(r(ci_upper)-`target')<1e-12
    assert r(n_biases)==3 & r(n_draw_invalid)==0 & r(corr)==-1
    qa_state_compare, tag(qba_route) allow(rng)

}
if _rc {
    local ++fail
    display as error "FAIL: Joint RR selection misclass friendly; rc=" _rc
}
else {
    local ++pass
    display as result "PASS: Joint RR selection misclass friendly"
}

**# Selection OR simple friendly
local ++tests
capture noisily {
    * expect: EXACT
    qa_fx_a6_bias, clear seed(37)
    ereturn clear
    local se=se[1]
    local sp=sp[1]
    local ta=true_n[1]
    local tb=true_n[3]
    local tc=true_n[2]
    local td=true_n[4]
    local target=(`ta' * `td' / (`tb' * `tc'))/1
    local sela=.5
    local a=`sela'*`ta'
    local b=`tb'
    local c=`tc'
    local d=`td'
    qa_state_snapshot, tag(qba_route)
    quietly qba_selection, a(`a') b(`b') c(`c') d(`d') sela(`sela') selb(1) selc(1) seld(1) measure(OR) level(90)
    assert !missing(r(corrected)) & abs(r(corrected)-`target')<1e-12
    qa_state_compare, tag(qba_route)

}
if _rc {
    local ++fail
    display as error "FAIL: Selection OR simple friendly; rc=" _rc
}
else {
    local ++pass
    display as result "PASS: Selection OR simple friendly"
}

**# Selection OR pointmass friendly
local ++tests
capture noisily {
    * expect: EXACT
    qa_fx_a6_bias, clear seed(37)
    ereturn clear
    local se=se[1]
    local sp=sp[1]
    local ta=true_n[1]
    local tb=true_n[3]
    local tc=true_n[2]
    local td=true_n[4]
    local target=(`ta' * `td' / (`tb' * `tc'))/1
    local sela=.5
    local a=`sela'*`ta'
    local b=`tb'
    local c=`tc'
    local d=`td'
    qa_state_snapshot, tag(qba_route)
    quietly qba_selection, a(`a') b(`b') c(`c') d(`d') sela(`sela') selb(1) selc(1) seld(1) measure(OR) level(90) reps(100) seed(37)
    assert !missing(r(corrected)) & abs(r(corrected)-`target')<1e-12
    assert r(n_valid)==100 & r(reps)==100
    assert !missing(r(mean),r(sd),r(ci_lower),r(ci_upper))
    assert abs(r(mean)-`target')<1e-12 & abs(r(sd))<1e-12
    assert abs(r(ci_lower)-`target')<1e-12 & abs(r(ci_upper)-`target')<1e-12
    qa_state_compare, tag(qba_route) allow(rng)

}
if _rc {
    local ++fail
    display as error "FAIL: Selection OR pointmass friendly; rc=" _rc
}
else {
    local ++pass
    display as result "PASS: Selection OR pointmass friendly"
}

**# Selection RR simple friendly
local ++tests
capture noisily {
    * expect: EXACT
    qa_fx_a6_bias, clear seed(37)
    ereturn clear
    local se=se[1]
    local sp=sp[1]
    local ta=true_n[1]
    local tb=true_n[3]
    local tc=true_n[2]
    local td=true_n[4]
    local target=((`ta'/(`ta'+`tc'))/(`tb'/(`tb'+`td')))/1
    local sela=.5
    local a=`sela'*`ta'
    local b=`tb'
    local c=`tc'
    local d=`td'
    qa_state_snapshot, tag(qba_route)
    quietly qba_selection, a(`a') b(`b') c(`c') d(`d') sela(`sela') selb(1) selc(1) seld(1) measure(RR) level(90)
    assert !missing(r(corrected)) & abs(r(corrected)-`target')<1e-12
    qa_state_compare, tag(qba_route)

}
if _rc {
    local ++fail
    display as error "FAIL: Selection RR simple friendly; rc=" _rc
}
else {
    local ++pass
    display as result "PASS: Selection RR simple friendly"
}

**# Selection RR pointmass friendly
local ++tests
capture noisily {
    * expect: EXACT
    qa_fx_a6_bias, clear seed(37)
    ereturn clear
    local se=se[1]
    local sp=sp[1]
    local ta=true_n[1]
    local tb=true_n[3]
    local tc=true_n[2]
    local td=true_n[4]
    local target=((`ta'/(`ta'+`tc'))/(`tb'/(`tb'+`td')))/1
    local sela=.5
    local a=`sela'*`ta'
    local b=`tb'
    local c=`tc'
    local d=`td'
    qa_state_snapshot, tag(qba_route)
    quietly qba_selection, a(`a') b(`b') c(`c') d(`d') sela(`sela') selb(1) selc(1) seld(1) measure(RR) level(90) reps(100) seed(37)
    assert !missing(r(corrected)) & abs(r(corrected)-`target')<1e-12
    assert r(n_valid)==100 & r(reps)==100
    assert !missing(r(mean),r(sd),r(ci_lower),r(ci_upper))
    assert abs(r(mean)-`target')<1e-12 & abs(r(sd))<1e-12
    assert abs(r(ci_lower)-`target')<1e-12 & abs(r(ci_upper)-`target')<1e-12
    qa_state_compare, tag(qba_route) allow(rng)

}
if _rc {
    local ++fail
    display as error "FAIL: Selection RR pointmass friendly; rc=" _rc
}
else {
    local ++pass
    display as result "PASS: Selection RR pointmass friendly"
}

**# Confounding RR pointmass friendly
local ++tests
capture noisily {
    * expect: EXACT
    qa_fx_a6_bias, clear seed(37)
    ereturn clear
    local se=se[1]
    local sp=sp[1]
    local p1=p_u1[1]
    local p0=p_u0[1]
    * Independently enumerate weighted relative risks in each exposure group.
    local target=2*(`p0'*3+(1-`p0'))/(`p1'*3+(1-`p1'))
    qa_state_snapshot, tag(qba_route)
    quietly qba_confound, estimate(2) measure(RR) p1(`p1') p0(`p0') rrcd(3) level(90) reps(100) seed(37)
    assert !missing(r(corrected)) & abs(r(corrected)-`target')<1e-12
    assert r(n_valid)==100 & r(reps)==100
    assert !missing(r(mean),r(sd),r(ci_lower),r(ci_upper))
    assert abs(r(mean)-`target')<1e-12 & abs(r(sd))<1e-12
    assert abs(r(ci_lower)-`target')<1e-12 & abs(r(ci_upper)-`target')<1e-12
    qa_state_compare, tag(qba_route) allow(rng)

}
if _rc {
    local ++fail
    display as error "FAIL: Confounding RR pointmass friendly; rc=" _rc
}
else {
    local ++pass
    display as result "PASS: Confounding RR pointmass friendly"
}

**# Confounding OR pointmass friendly
local ++tests
capture noisily {
    * expect: EXACT
    qa_fx_a6_bias, clear seed(37)
    ereturn clear
    local se=se[1]
    local sp=sp[1]
    local p1=p_u1[1]
    local p0=p_u0[1]
    * Independently enumerate weighted relative risks in each exposure group.
    local target=2*(`p0'*3+(1-`p0'))/(`p1'*3+(1-`p1'))
    qa_state_snapshot, tag(qba_route)
    quietly qba_confound, estimate(2) measure(OR) p1(`p1') p0(`p0') rrcd(3) level(90) reps(100) seed(37)
    assert !missing(r(corrected)) & abs(r(corrected)-`target')<1e-12
    assert r(n_valid)==100 & r(reps)==100
    assert !missing(r(mean),r(sd),r(ci_lower),r(ci_upper))
    assert abs(r(mean)-`target')<1e-12 & abs(r(sd))<1e-12
    assert abs(r(ci_lower)-`target')<1e-12 & abs(r(ci_upper)-`target')<1e-12
    qa_state_compare, tag(qba_route) allow(rng)

}
if _rc {
    local ++fail
    display as error "FAIL: Confounding OR pointmass friendly; rc=" _rc
}
else {
    local ++pass
    display as result "PASS: Confounding OR pointmass friendly"
}

**# Confounding HR pointmass friendly
local ++tests
capture noisily {
    * expect: EXACT
    qa_fx_a6_bias, clear seed(37)
    ereturn clear
    local se=se[1]
    local sp=sp[1]
    local p1=p_u1[1]
    local p0=p_u0[1]
    * Independently enumerate weighted relative risks in each exposure group.
    local target=2*(`p0'*3+(1-`p0'))/(`p1'*3+(1-`p1'))
    qa_state_snapshot, tag(qba_route)
    quietly qba_confound, estimate(2) measure(HR) p1(`p1') p0(`p0') rrcd(3) level(90) reps(100) seed(37)
    assert !missing(r(corrected)) & abs(r(corrected)-`target')<1e-12
    assert r(n_valid)==100 & r(reps)==100
    assert !missing(r(mean),r(sd),r(ci_lower),r(ci_upper))
    assert abs(r(mean)-`target')<1e-12 & abs(r(sd))<1e-12
    assert abs(r(ci_lower)-`target')<1e-12 & abs(r(ci_upper)-`target')<1e-12
    qa_state_compare, tag(qba_route) allow(rng)

}
if _rc {
    local ++fail
    display as error "FAIL: Confounding HR pointmass friendly; rc=" _rc
}
else {
    local ++pass
    display as result "PASS: Confounding HR pointmass friendly"
}

**# Confounding IRR pointmass friendly
local ++tests
capture noisily {
    * expect: EXACT
    qa_fx_a6_bias, clear seed(37)
    ereturn clear
    local se=se[1]
    local sp=sp[1]
    local p1=p_u1[1]
    local p0=p_u0[1]
    * Independently enumerate weighted relative risks in each exposure group.
    local target=2*(`p0'*3+(1-`p0'))/(`p1'*3+(1-`p1'))
    qa_state_snapshot, tag(qba_route)
    quietly qba_confound, estimate(2) measure(IRR) p1(`p1') p0(`p0') rrcd(3) level(90) reps(100) seed(37)
    assert !missing(r(corrected)) & abs(r(corrected)-`target')<1e-12
    assert r(n_valid)==100 & r(reps)==100
    assert !missing(r(mean),r(sd),r(ci_lower),r(ci_upper))
    assert abs(r(mean)-`target')<1e-12 & abs(r(sd))<1e-12
    assert abs(r(ci_lower)-`target')<1e-12 & abs(r(ci_upper)-`target')<1e-12
    qa_state_compare, tag(qba_route) allow(rng)

}
if _rc {
    local ++fail
    display as error "FAIL: Confounding IRR pointmass friendly; rc=" _rc
}
else {
    local ++pass
    display as result "PASS: Confounding IRR pointmass friendly"
}

**# Exposure OR simple boundary_values
local ++tests
capture noisily {
    * expect: EXACT
    qa_fx_a6_bias, clear seed(37) perturb(boundary_values)
    ereturn clear
    local se=se[1]
    local sp=sp[1]
    local ta=true_n[1]
    local tb=true_n[3]
    local tc=true_n[2]
    local td=true_n[4]
    local target=(`ta' * `td' / (`tb' * `tc'))/1
    * Forward exposure classification separately within cases and noncases.
    local a=`se'*`ta'+(1-`sp')*`tb'
    local b=(1-`se')*`ta'+`sp'*`tb'
    local c=`se'*`tc'+(1-`sp')*`td'
    local d=(1-`se')*`tc'+`sp'*`td'
    qa_state_snapshot, tag(qba_route)
    quietly qba_misclass, a(`a') b(`b') c(`c') d(`d') seca(`se') spca(`sp') secb(`se') spcb(`sp') type(exposure) measure(OR) level(90)
    assert !missing(r(corrected)) & abs(r(corrected)-`target')<1e-12
    assert abs(r(corrected_a)-`ta')<1e-12 & abs(r(corrected_b)-`tb')<1e-12
    assert abs(r(corrected_c)-`tc')<1e-12 & abs(r(corrected_d)-`td')<1e-12
    qa_state_compare, tag(qba_route)

}
if _rc {
    local ++fail
    display as error "FAIL: Exposure OR simple boundary_values; rc=" _rc
}
else {
    local ++pass
    display as result "PASS: Exposure OR simple boundary_values"
}

**# Exposure OR pointmass boundary_values
local ++tests
capture noisily {
    * expect: EXACT
    qa_fx_a6_bias, clear seed(37) perturb(boundary_values)
    ereturn clear
    local se=se[1]
    local sp=sp[1]
    local ta=true_n[1]
    local tb=true_n[3]
    local tc=true_n[2]
    local td=true_n[4]
    local target=(`ta' * `td' / (`tb' * `tc'))/1
    * Forward exposure classification separately within cases and noncases.
    local a=`se'*`ta'+(1-`sp')*`tb'
    local b=(1-`se')*`ta'+`sp'*`tb'
    local c=`se'*`tc'+(1-`sp')*`td'
    local d=(1-`se')*`tc'+`sp'*`td'
    qa_state_snapshot, tag(qba_route)
    quietly qba_misclass, a(`a') b(`b') c(`c') d(`d') seca(`se') spca(`sp') secb(`se') spcb(`sp') type(exposure) measure(OR) level(90) reps(100) seed(37) corr(1)
    assert !missing(r(corrected)) & abs(r(corrected)-`target')<1e-12
    assert r(n_valid)==100 & r(reps)==100
    assert !missing(r(mean),r(sd),r(ci_lower),r(ci_upper))
    assert abs(r(mean)-`target')<1e-12 & abs(r(sd))<1e-12
    assert abs(r(ci_lower)-`target')<1e-12 & abs(r(ci_upper)-`target')<1e-12
    qa_state_compare, tag(qba_route) allow(rng)

}
if _rc {
    local ++fail
    display as error "FAIL: Exposure OR pointmass boundary_values; rc=" _rc
}
else {
    local ++pass
    display as result "PASS: Exposure OR pointmass boundary_values"
}

**# Exposure RR simple boundary_values
local ++tests
capture noisily {
    * expect: EXACT
    qa_fx_a6_bias, clear seed(37) perturb(boundary_values)
    ereturn clear
    local se=se[1]
    local sp=sp[1]
    local ta=true_n[1]
    local tb=true_n[3]
    local tc=true_n[2]
    local td=true_n[4]
    local target=((`ta'/(`ta'+`tc'))/(`tb'/(`tb'+`td')))/1
    * Forward exposure classification separately within cases and noncases.
    local a=`se'*`ta'+(1-`sp')*`tb'
    local b=(1-`se')*`ta'+`sp'*`tb'
    local c=`se'*`tc'+(1-`sp')*`td'
    local d=(1-`se')*`tc'+`sp'*`td'
    qa_state_snapshot, tag(qba_route)
    quietly qba_misclass, a(`a') b(`b') c(`c') d(`d') seca(`se') spca(`sp') secb(`se') spcb(`sp') type(exposure) measure(RR) level(90)
    assert !missing(r(corrected)) & abs(r(corrected)-`target')<1e-12
    assert abs(r(corrected_a)-`ta')<1e-12 & abs(r(corrected_b)-`tb')<1e-12
    assert abs(r(corrected_c)-`tc')<1e-12 & abs(r(corrected_d)-`td')<1e-12
    qa_state_compare, tag(qba_route)

}
if _rc {
    local ++fail
    display as error "FAIL: Exposure RR simple boundary_values; rc=" _rc
}
else {
    local ++pass
    display as result "PASS: Exposure RR simple boundary_values"
}

**# Exposure RR pointmass boundary_values
local ++tests
capture noisily {
    * expect: EXACT
    qa_fx_a6_bias, clear seed(37) perturb(boundary_values)
    ereturn clear
    local se=se[1]
    local sp=sp[1]
    local ta=true_n[1]
    local tb=true_n[3]
    local tc=true_n[2]
    local td=true_n[4]
    local target=((`ta'/(`ta'+`tc'))/(`tb'/(`tb'+`td')))/1
    * Forward exposure classification separately within cases and noncases.
    local a=`se'*`ta'+(1-`sp')*`tb'
    local b=(1-`se')*`ta'+`sp'*`tb'
    local c=`se'*`tc'+(1-`sp')*`td'
    local d=(1-`se')*`tc'+`sp'*`td'
    qa_state_snapshot, tag(qba_route)
    quietly qba_misclass, a(`a') b(`b') c(`c') d(`d') seca(`se') spca(`sp') secb(`se') spcb(`sp') type(exposure) measure(RR) level(90) reps(100) seed(37) corr(1)
    assert !missing(r(corrected)) & abs(r(corrected)-`target')<1e-12
    assert r(n_valid)==100 & r(reps)==100
    assert !missing(r(mean),r(sd),r(ci_lower),r(ci_upper))
    assert abs(r(mean)-`target')<1e-12 & abs(r(sd))<1e-12
    assert abs(r(ci_lower)-`target')<1e-12 & abs(r(ci_upper)-`target')<1e-12
    qa_state_compare, tag(qba_route) allow(rng)

}
if _rc {
    local ++fail
    display as error "FAIL: Exposure RR pointmass boundary_values; rc=" _rc
}
else {
    local ++pass
    display as result "PASS: Exposure RR pointmass boundary_values"
}

**# Joint OR misclass selection boundary_values
local ++tests
capture noisily {
    * expect: EXACT
    qa_fx_a6_bias, clear seed(37) perturb(boundary_values)
    ereturn clear
    local se=se[1]
    local sp=sp[1]
    local ta=true_n[1]
    local tb=true_n[3]
    local tc=true_n[2]
    local td=true_n[4]
    local target=(`ta' * `td' / (`tb' * `tc'))/1.5
    * Forward inclusion then outcome classification (reverse of correction).
    local a=`se'*(.5*`ta')+(1-`sp')*`tc'
    local c=(1-`se')*(.5*`ta')+`sp'*`tc'
    local b=`se'*`tb'+(1-`sp')*`td'
    local d=(1-`se')*`tb'+`sp'*`td'
    qa_state_snapshot, tag(qba_route)
    quietly qba_multi, a(`a') b(`b') c(`c') d(`d') seca(`se') spca(`sp') secb(`se') spcb(`sp') corr(-1) mctype(outcome) sela(.5) selb(1) selc(1) seld(1) p1(.5) p0(`=1/6') rrcd(3) order(misclass selection) measure(OR) reps(100) seed(37) level(90)
    assert !missing(r(corrected)) & abs(r(corrected)-`target')<1e-12
    assert r(n_valid)==100 & r(reps)==100
    assert !missing(r(mean),r(sd),r(ci_lower),r(ci_upper))
    assert abs(r(mean)-`target')<1e-12 & abs(r(sd))<1e-12
    assert abs(r(ci_lower)-`target')<1e-12 & abs(r(ci_upper)-`target')<1e-12
    assert r(n_biases)==3 & r(n_draw_invalid)==0 & r(corr)==-1
    qa_state_compare, tag(qba_route) allow(rng)

}
if _rc {
    local ++fail
    display as error "FAIL: Joint OR misclass selection boundary_values; rc=" _rc
}
else {
    local ++pass
    display as result "PASS: Joint OR misclass selection boundary_values"
}

**# Joint OR selection misclass boundary_values
local ++tests
capture noisily {
    * expect: EXACT
    qa_fx_a6_bias, clear seed(37) perturb(boundary_values)
    ereturn clear
    local se=se[1]
    local sp=sp[1]
    local ta=true_n[1]
    local tb=true_n[3]
    local tc=true_n[2]
    local td=true_n[4]
    local target=(`ta' * `td' / (`tb' * `tc'))/1.5
    * Forward outcome classification then inclusion.
    local a=.5*(`se'*`ta'+(1-`sp')*`tc')
    local c=(1-`se')*`ta'+`sp'*`tc'
    local b=`se'*`tb'+(1-`sp')*`td'
    local d=(1-`se')*`tb'+`sp'*`td'
    qa_state_snapshot, tag(qba_route)
    quietly qba_multi, a(`a') b(`b') c(`c') d(`d') seca(`se') spca(`sp') secb(`se') spcb(`sp') corr(-1) mctype(outcome) sela(.5) selb(1) selc(1) seld(1) p1(.5) p0(`=1/6') rrcd(3) order(selection misclass) measure(OR) reps(100) seed(37) level(90)
    assert !missing(r(corrected)) & abs(r(corrected)-`target')<1e-12
    assert r(n_valid)==100 & r(reps)==100
    assert !missing(r(mean),r(sd),r(ci_lower),r(ci_upper))
    assert abs(r(mean)-`target')<1e-12 & abs(r(sd))<1e-12
    assert abs(r(ci_lower)-`target')<1e-12 & abs(r(ci_upper)-`target')<1e-12
    assert r(n_biases)==3 & r(n_draw_invalid)==0 & r(corr)==-1
    qa_state_compare, tag(qba_route) allow(rng)

}
if _rc {
    local ++fail
    display as error "FAIL: Joint OR selection misclass boundary_values; rc=" _rc
}
else {
    local ++pass
    display as result "PASS: Joint OR selection misclass boundary_values"
}

**# Joint RR misclass selection boundary_values
local ++tests
capture noisily {
    * expect: EXACT
    qa_fx_a6_bias, clear seed(37) perturb(boundary_values)
    ereturn clear
    local se=se[1]
    local sp=sp[1]
    local ta=true_n[1]
    local tb=true_n[3]
    local tc=true_n[2]
    local td=true_n[4]
    local target=((`ta'/(`ta'+`tc'))/(`tb'/(`tb'+`td')))/1.5
    * Forward inclusion then outcome classification (reverse of correction).
    local a=`se'*(.5*`ta')+(1-`sp')*`tc'
    local c=(1-`se')*(.5*`ta')+`sp'*`tc'
    local b=`se'*`tb'+(1-`sp')*`td'
    local d=(1-`se')*`tb'+`sp'*`td'
    qa_state_snapshot, tag(qba_route)
    quietly qba_multi, a(`a') b(`b') c(`c') d(`d') seca(`se') spca(`sp') secb(`se') spcb(`sp') corr(-1) mctype(outcome) sela(.5) selb(1) selc(1) seld(1) p1(.5) p0(`=1/6') rrcd(3) order(misclass selection) measure(RR) reps(100) seed(37) level(90)
    assert !missing(r(corrected)) & abs(r(corrected)-`target')<1e-12
    assert r(n_valid)==100 & r(reps)==100
    assert !missing(r(mean),r(sd),r(ci_lower),r(ci_upper))
    assert abs(r(mean)-`target')<1e-12 & abs(r(sd))<1e-12
    assert abs(r(ci_lower)-`target')<1e-12 & abs(r(ci_upper)-`target')<1e-12
    assert r(n_biases)==3 & r(n_draw_invalid)==0 & r(corr)==-1
    qa_state_compare, tag(qba_route) allow(rng)

}
if _rc {
    local ++fail
    display as error "FAIL: Joint RR misclass selection boundary_values; rc=" _rc
}
else {
    local ++pass
    display as result "PASS: Joint RR misclass selection boundary_values"
}

**# Joint RR selection misclass boundary_values
local ++tests
capture noisily {
    * expect: EXACT
    qa_fx_a6_bias, clear seed(37) perturb(boundary_values)
    ereturn clear
    local se=se[1]
    local sp=sp[1]
    local ta=true_n[1]
    local tb=true_n[3]
    local tc=true_n[2]
    local td=true_n[4]
    local target=((`ta'/(`ta'+`tc'))/(`tb'/(`tb'+`td')))/1.5
    * Forward outcome classification then inclusion.
    local a=.5*(`se'*`ta'+(1-`sp')*`tc')
    local c=(1-`se')*`ta'+`sp'*`tc'
    local b=`se'*`tb'+(1-`sp')*`td'
    local d=(1-`se')*`tb'+`sp'*`td'
    qa_state_snapshot, tag(qba_route)
    quietly qba_multi, a(`a') b(`b') c(`c') d(`d') seca(`se') spca(`sp') secb(`se') spcb(`sp') corr(-1) mctype(outcome) sela(.5) selb(1) selc(1) seld(1) p1(.5) p0(`=1/6') rrcd(3) order(selection misclass) measure(RR) reps(100) seed(37) level(90)
    assert !missing(r(corrected)) & abs(r(corrected)-`target')<1e-12
    assert r(n_valid)==100 & r(reps)==100
    assert !missing(r(mean),r(sd),r(ci_lower),r(ci_upper))
    assert abs(r(mean)-`target')<1e-12 & abs(r(sd))<1e-12
    assert abs(r(ci_lower)-`target')<1e-12 & abs(r(ci_upper)-`target')<1e-12
    assert r(n_biases)==3 & r(n_draw_invalid)==0 & r(corr)==-1
    qa_state_compare, tag(qba_route) allow(rng)

}
if _rc {
    local ++fail
    display as error "FAIL: Joint RR selection misclass boundary_values; rc=" _rc
}
else {
    local ++pass
    display as result "PASS: Joint RR selection misclass boundary_values"
}

**# Selection OR simple boundary_values
local ++tests
capture noisily {
    * expect: EXACT
    qa_fx_a6_bias, clear seed(37) perturb(boundary_values)
    ereturn clear
    local se=se[1]
    local sp=sp[1]
    local ta=true_n[1]
    local tb=true_n[3]
    local tc=true_n[2]
    local td=true_n[4]
    local target=(`ta' * `td' / (`tb' * `tc'))/1
    local sela=.5
    local sela=1
    local a=`sela'*`ta'
    local b=`tb'
    local c=`tc'
    local d=`td'
    qa_state_snapshot, tag(qba_route)
    quietly qba_selection, a(`a') b(`b') c(`c') d(`d') sela(`sela') selb(1) selc(1) seld(1) measure(OR) level(90)
    assert !missing(r(corrected)) & abs(r(corrected)-`target')<1e-12
    qa_state_compare, tag(qba_route)

}
if _rc {
    local ++fail
    display as error "FAIL: Selection OR simple boundary_values; rc=" _rc
}
else {
    local ++pass
    display as result "PASS: Selection OR simple boundary_values"
}

**# Selection OR pointmass boundary_values
local ++tests
capture noisily {
    * expect: EXACT
    qa_fx_a6_bias, clear seed(37) perturb(boundary_values)
    ereturn clear
    local se=se[1]
    local sp=sp[1]
    local ta=true_n[1]
    local tb=true_n[3]
    local tc=true_n[2]
    local td=true_n[4]
    local target=(`ta' * `td' / (`tb' * `tc'))/1
    local sela=.5
    local sela=1
    local a=`sela'*`ta'
    local b=`tb'
    local c=`tc'
    local d=`td'
    qa_state_snapshot, tag(qba_route)
    quietly qba_selection, a(`a') b(`b') c(`c') d(`d') sela(`sela') selb(1) selc(1) seld(1) measure(OR) level(90) reps(100) seed(37)
    assert !missing(r(corrected)) & abs(r(corrected)-`target')<1e-12
    assert r(n_valid)==100 & r(reps)==100
    assert !missing(r(mean),r(sd),r(ci_lower),r(ci_upper))
    assert abs(r(mean)-`target')<1e-12 & abs(r(sd))<1e-12
    assert abs(r(ci_lower)-`target')<1e-12 & abs(r(ci_upper)-`target')<1e-12
    qa_state_compare, tag(qba_route) allow(rng)

}
if _rc {
    local ++fail
    display as error "FAIL: Selection OR pointmass boundary_values; rc=" _rc
}
else {
    local ++pass
    display as result "PASS: Selection OR pointmass boundary_values"
}

**# Selection RR simple boundary_values
local ++tests
capture noisily {
    * expect: EXACT
    qa_fx_a6_bias, clear seed(37) perturb(boundary_values)
    ereturn clear
    local se=se[1]
    local sp=sp[1]
    local ta=true_n[1]
    local tb=true_n[3]
    local tc=true_n[2]
    local td=true_n[4]
    local target=((`ta'/(`ta'+`tc'))/(`tb'/(`tb'+`td')))/1
    local sela=.5
    local sela=1
    local a=`sela'*`ta'
    local b=`tb'
    local c=`tc'
    local d=`td'
    qa_state_snapshot, tag(qba_route)
    quietly qba_selection, a(`a') b(`b') c(`c') d(`d') sela(`sela') selb(1) selc(1) seld(1) measure(RR) level(90)
    assert !missing(r(corrected)) & abs(r(corrected)-`target')<1e-12
    qa_state_compare, tag(qba_route)

}
if _rc {
    local ++fail
    display as error "FAIL: Selection RR simple boundary_values; rc=" _rc
}
else {
    local ++pass
    display as result "PASS: Selection RR simple boundary_values"
}

**# Selection RR pointmass boundary_values
local ++tests
capture noisily {
    * expect: EXACT
    qa_fx_a6_bias, clear seed(37) perturb(boundary_values)
    ereturn clear
    local se=se[1]
    local sp=sp[1]
    local ta=true_n[1]
    local tb=true_n[3]
    local tc=true_n[2]
    local td=true_n[4]
    local target=((`ta'/(`ta'+`tc'))/(`tb'/(`tb'+`td')))/1
    local sela=.5
    local sela=1
    local a=`sela'*`ta'
    local b=`tb'
    local c=`tc'
    local d=`td'
    qa_state_snapshot, tag(qba_route)
    quietly qba_selection, a(`a') b(`b') c(`c') d(`d') sela(`sela') selb(1) selc(1) seld(1) measure(RR) level(90) reps(100) seed(37)
    assert !missing(r(corrected)) & abs(r(corrected)-`target')<1e-12
    assert r(n_valid)==100 & r(reps)==100
    assert !missing(r(mean),r(sd),r(ci_lower),r(ci_upper))
    assert abs(r(mean)-`target')<1e-12 & abs(r(sd))<1e-12
    assert abs(r(ci_lower)-`target')<1e-12 & abs(r(ci_upper)-`target')<1e-12
    qa_state_compare, tag(qba_route) allow(rng)

}
if _rc {
    local ++fail
    display as error "FAIL: Selection RR pointmass boundary_values; rc=" _rc
}
else {
    local ++pass
    display as result "PASS: Selection RR pointmass boundary_values"
}

**# Confounding RR pointmass boundary_values
local ++tests
capture noisily {
    * expect: EXACT
    qa_fx_a6_bias, clear seed(37) perturb(boundary_values)
    ereturn clear
    local se=se[1]
    local sp=sp[1]
    local p1=p_u1[1]
    local p0=p_u0[1]
    local p1=1
    local p0=0
    * Independently enumerate weighted relative risks in each exposure group.
    local target=2*(`p0'*3+(1-`p0'))/(`p1'*3+(1-`p1'))
    qa_state_snapshot, tag(qba_route)
    quietly qba_confound, estimate(2) measure(RR) p1(`p1') p0(`p0') rrcd(3) level(90) reps(100) seed(37)
    assert !missing(r(corrected)) & abs(r(corrected)-`target')<1e-12
    assert r(n_valid)==100 & r(reps)==100
    assert !missing(r(mean),r(sd),r(ci_lower),r(ci_upper))
    assert abs(r(mean)-`target')<1e-12 & abs(r(sd))<1e-12
    assert abs(r(ci_lower)-`target')<1e-12 & abs(r(ci_upper)-`target')<1e-12
    qa_state_compare, tag(qba_route) allow(rng)

}
if _rc {
    local ++fail
    display as error "FAIL: Confounding RR pointmass boundary_values; rc=" _rc
}
else {
    local ++pass
    display as result "PASS: Confounding RR pointmass boundary_values"
}

**# Confounding OR pointmass boundary_values
local ++tests
capture noisily {
    * expect: EXACT
    qa_fx_a6_bias, clear seed(37) perturb(boundary_values)
    ereturn clear
    local se=se[1]
    local sp=sp[1]
    local p1=p_u1[1]
    local p0=p_u0[1]
    local p1=1
    local p0=0
    * Independently enumerate weighted relative risks in each exposure group.
    local target=2*(`p0'*3+(1-`p0'))/(`p1'*3+(1-`p1'))
    qa_state_snapshot, tag(qba_route)
    quietly qba_confound, estimate(2) measure(OR) p1(`p1') p0(`p0') rrcd(3) level(90) reps(100) seed(37)
    assert !missing(r(corrected)) & abs(r(corrected)-`target')<1e-12
    assert r(n_valid)==100 & r(reps)==100
    assert !missing(r(mean),r(sd),r(ci_lower),r(ci_upper))
    assert abs(r(mean)-`target')<1e-12 & abs(r(sd))<1e-12
    assert abs(r(ci_lower)-`target')<1e-12 & abs(r(ci_upper)-`target')<1e-12
    qa_state_compare, tag(qba_route) allow(rng)

}
if _rc {
    local ++fail
    display as error "FAIL: Confounding OR pointmass boundary_values; rc=" _rc
}
else {
    local ++pass
    display as result "PASS: Confounding OR pointmass boundary_values"
}

**# Confounding HR pointmass boundary_values
local ++tests
capture noisily {
    * expect: EXACT
    qa_fx_a6_bias, clear seed(37) perturb(boundary_values)
    ereturn clear
    local se=se[1]
    local sp=sp[1]
    local p1=p_u1[1]
    local p0=p_u0[1]
    local p1=1
    local p0=0
    * Independently enumerate weighted relative risks in each exposure group.
    local target=2*(`p0'*3+(1-`p0'))/(`p1'*3+(1-`p1'))
    qa_state_snapshot, tag(qba_route)
    quietly qba_confound, estimate(2) measure(HR) p1(`p1') p0(`p0') rrcd(3) level(90) reps(100) seed(37)
    assert !missing(r(corrected)) & abs(r(corrected)-`target')<1e-12
    assert r(n_valid)==100 & r(reps)==100
    assert !missing(r(mean),r(sd),r(ci_lower),r(ci_upper))
    assert abs(r(mean)-`target')<1e-12 & abs(r(sd))<1e-12
    assert abs(r(ci_lower)-`target')<1e-12 & abs(r(ci_upper)-`target')<1e-12
    qa_state_compare, tag(qba_route) allow(rng)

}
if _rc {
    local ++fail
    display as error "FAIL: Confounding HR pointmass boundary_values; rc=" _rc
}
else {
    local ++pass
    display as result "PASS: Confounding HR pointmass boundary_values"
}

**# Confounding IRR pointmass boundary_values
local ++tests
capture noisily {
    * expect: EXACT
    qa_fx_a6_bias, clear seed(37) perturb(boundary_values)
    ereturn clear
    local se=se[1]
    local sp=sp[1]
    local p1=p_u1[1]
    local p0=p_u0[1]
    local p1=1
    local p0=0
    * Independently enumerate weighted relative risks in each exposure group.
    local target=2*(`p0'*3+(1-`p0'))/(`p1'*3+(1-`p1'))
    qa_state_snapshot, tag(qba_route)
    quietly qba_confound, estimate(2) measure(IRR) p1(`p1') p0(`p0') rrcd(3) level(90) reps(100) seed(37)
    assert !missing(r(corrected)) & abs(r(corrected)-`target')<1e-12
    assert r(n_valid)==100 & r(reps)==100
    assert !missing(r(mean),r(sd),r(ci_lower),r(ci_upper))
    assert abs(r(mean)-`target')<1e-12 & abs(r(sd))<1e-12
    assert abs(r(ci_lower)-`target')<1e-12 & abs(r(ci_upper)-`target')<1e-12
    qa_state_compare, tag(qba_route) allow(rng)

}
if _rc {
    local ++fail
    display as error "FAIL: Confounding IRR pointmass boundary_values; rc=" _rc
}
else {
    local ++pass
    display as result "PASS: Confounding IRR pointmass boundary_values"
}

**# Linear from_model friendly
local ++tests
capture noisily {
    * expect: EXACT
    qa_fx_a1_gauss, clear seed(37)
    * Conditional mean adapter, not population truth asserted on noisy y.
    quietly regress mu a x1 x2 i.xcat
    assert abs(_b[a]-2)<1e-12
    local target=2-(.5-1/6)*3
    qa_state_snapshot, tag(qba_route)
    quietly qba_confound, from_model coef(a) confeffect(3) p1(.5) p0(`=1/6') level(90)
    assert !missing(r(corrected)) & abs(r(corrected)-`target')<1e-12
    assert abs(r(observed)-2)<1e-12 & `"`r(measure)'"'=="coefficient"
    qa_state_compare, tag(qba_route)

}
if _rc {
    local ++fail
    display as error "FAIL: Linear from_model friendly; rc=" _rc
}
else {
    local ++pass
    display as result "PASS: Linear from_model friendly"
}

**# Linear from_model unsorted
local ++tests
capture noisily {
    * expect: EXACT
    qa_fx_a1_gauss, clear seed(37) perturb(unsorted)
    * Conditional mean adapter, not population truth asserted on noisy y.
    quietly regress mu a x1 x2 i.xcat
    assert abs(_b[a]-2)<1e-12
    local target=2-(.5-1/6)*3
    qa_state_snapshot, tag(qba_route)
    quietly qba_confound, from_model coef(a) confeffect(3) p1(.5) p0(`=1/6') level(90)
    assert !missing(r(corrected)) & abs(r(corrected)-`target')<1e-12
    assert abs(r(observed)-2)<1e-12 & `"`r(measure)'"'=="coefficient"
    qa_state_compare, tag(qba_route)

}
if _rc {
    local ++fail
    display as error "FAIL: Linear from_model unsorted; rc=" _rc
}
else {
    local ++pass
    display as result "PASS: Linear from_model unsorted"
}

display as result "RESULT: validation_qba_fixture_routes tests=`tests' pass=`pass' fail=`fail'"
log close
if `fail' exit 1
