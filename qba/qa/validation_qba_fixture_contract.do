*! validation_qba_fixture_contract.do -- exact canonical-fixture recovery and hostile contracts
*! Author: Timothy P Copeland, Karolinska Institutet
* guard: expected green at pre-fix ref; fixture adoption, no package fix.
version 16.0
clear all
set more off
capture log close _all
log using "validation_qba_fixture_contract.log", text replace
local pkg_dir = substr("`c(pwd)'",1,strlen("`c(pwd)'")-3)
adopath ++ "`pkg_dir'"
do "_qa_fx_a6.do"
local tests 0
local pass 0
local fail 0

**# Outcome misclassification OR simple friendly
local ++tests
capture noisily {
    qa_fx_a6_bias, clear seed(37)
    tempname truth
    scalar `truth'=r(truth_or)
    local a=observed_n[1]
    local b=observed_n[3]
    local c=observed_n[2]
    local d=observed_n[4]
    local se=se[1]
    local sp=sp[1]
    quietly qba_misclass, a(`a') b(`b') c(`c') d(`d') seca(`se') spca(`sp') measure(OR) type(outcome)
    assert abs(r(corrected)-scalar(`truth'))<1e-12
    assert abs(r(corrected_a)-40)<1e-12 & abs(r(corrected_b)-20)<1e-12
    assert abs(r(corrected_c)-60)<1e-12 & abs(r(corrected_d)-80)<1e-12

}
if _rc {
    local ++fail
    display as error "FAIL: Outcome misclassification OR simple friendly; rc=" _rc
}
else {
    local ++pass
    display as result "PASS: Outcome misclassification OR simple friendly"
}

**# Outcome misclassification OR constantMC friendly
local ++tests
capture noisily {
    qa_fx_a6_bias, clear seed(37)
    tempname truth
    scalar `truth'=r(truth_or)
    local a=observed_n[1]
    local b=observed_n[3]
    local c=observed_n[2]
    local d=observed_n[4]
    local se=se[1]
    local sp=sp[1]
    quietly qba_misclass, a(`a') b(`b') c(`c') d(`d') seca(`se') spca(`sp') measure(OR) type(outcome) reps(100) seed(37)
    assert abs(r(corrected)-scalar(`truth'))<1e-12
    assert r(n_valid)==100 & abs(r(mean)-scalar(`truth'))<1e-12
    assert abs(r(ci_lower)-scalar(`truth'))<1e-12 & abs(r(ci_upper)-scalar(`truth'))<1e-12

}
if _rc {
    local ++fail
    display as error "FAIL: Outcome misclassification OR constantMC friendly; rc=" _rc
}
else {
    local ++pass
    display as result "PASS: Outcome misclassification OR constantMC friendly"
}

**# Outcome misclassification OR multi friendly
local ++tests
capture noisily {
    qa_fx_a6_bias, clear seed(37)
    tempname truth
    scalar `truth'=r(truth_or)
    local a=observed_n[1]
    local b=observed_n[3]
    local c=observed_n[2]
    local d=observed_n[4]
    local se=se[1]
    local sp=sp[1]
    quietly qba_multi, a(`a') b(`b') c(`c') d(`d') seca(`se') spca(`sp') measure(OR) mctype(outcome) reps(100) seed(37)
    assert abs(r(corrected)-scalar(`truth'))<1e-12
    assert r(n_valid)==100 & abs(r(mean)-scalar(`truth'))<1e-12
    assert abs(r(ci_lower)-scalar(`truth'))<1e-12 & abs(r(ci_upper)-scalar(`truth'))<1e-12

}
if _rc {
    local ++fail
    display as error "FAIL: Outcome misclassification OR multi friendly; rc=" _rc
}
else {
    local ++pass
    display as result "PASS: Outcome misclassification OR multi friendly"
}

**# Outcome misclassification RR simple friendly
local ++tests
capture noisily {
    qa_fx_a6_bias, clear seed(37)
    tempname truth
    scalar `truth'=r(truth_rr)
    local a=observed_n[1]
    local b=observed_n[3]
    local c=observed_n[2]
    local d=observed_n[4]
    local se=se[1]
    local sp=sp[1]
    quietly qba_misclass, a(`a') b(`b') c(`c') d(`d') seca(`se') spca(`sp') measure(RR) type(outcome)
    assert abs(r(corrected)-scalar(`truth'))<1e-12
    assert abs(r(corrected_a)-40)<1e-12 & abs(r(corrected_b)-20)<1e-12
    assert abs(r(corrected_c)-60)<1e-12 & abs(r(corrected_d)-80)<1e-12

}
if _rc {
    local ++fail
    display as error "FAIL: Outcome misclassification RR simple friendly; rc=" _rc
}
else {
    local ++pass
    display as result "PASS: Outcome misclassification RR simple friendly"
}

**# Outcome misclassification RR constantMC friendly
local ++tests
capture noisily {
    qa_fx_a6_bias, clear seed(37)
    tempname truth
    scalar `truth'=r(truth_rr)
    local a=observed_n[1]
    local b=observed_n[3]
    local c=observed_n[2]
    local d=observed_n[4]
    local se=se[1]
    local sp=sp[1]
    quietly qba_misclass, a(`a') b(`b') c(`c') d(`d') seca(`se') spca(`sp') measure(RR) type(outcome) reps(100) seed(37)
    assert abs(r(corrected)-scalar(`truth'))<1e-12
    assert r(n_valid)==100 & abs(r(mean)-scalar(`truth'))<1e-12
    assert abs(r(ci_lower)-scalar(`truth'))<1e-12 & abs(r(ci_upper)-scalar(`truth'))<1e-12

}
if _rc {
    local ++fail
    display as error "FAIL: Outcome misclassification RR constantMC friendly; rc=" _rc
}
else {
    local ++pass
    display as result "PASS: Outcome misclassification RR constantMC friendly"
}

**# Outcome misclassification RR multi friendly
local ++tests
capture noisily {
    qa_fx_a6_bias, clear seed(37)
    tempname truth
    scalar `truth'=r(truth_rr)
    local a=observed_n[1]
    local b=observed_n[3]
    local c=observed_n[2]
    local d=observed_n[4]
    local se=se[1]
    local sp=sp[1]
    quietly qba_multi, a(`a') b(`b') c(`c') d(`d') seca(`se') spca(`sp') measure(RR) mctype(outcome) reps(100) seed(37)
    assert abs(r(corrected)-scalar(`truth'))<1e-12
    assert r(n_valid)==100 & abs(r(mean)-scalar(`truth'))<1e-12
    assert abs(r(ci_lower)-scalar(`truth'))<1e-12 & abs(r(ci_upper)-scalar(`truth'))<1e-12

}
if _rc {
    local ++fail
    display as error "FAIL: Outcome misclassification RR multi friendly; rc=" _rc
}
else {
    local ++pass
    display as result "PASS: Outcome misclassification RR multi friendly"
}

**# Outcome misclassification OR simple boundary_values
local ++tests
capture noisily {
    * expect: EXACT
    qa_fx_a6_bias, clear seed(37) perturb(boundary_values)
    tempname truth
    scalar `truth'=r(truth_or)
    local a=observed_n[1]
    local b=observed_n[3]
    local c=observed_n[2]
    local d=observed_n[4]
    local se=se[1]
    local sp=sp[1]
    quietly qba_misclass, a(`a') b(`b') c(`c') d(`d') seca(`se') spca(`sp') measure(OR) type(outcome)
    assert abs(r(corrected)-scalar(`truth'))<1e-12
    assert abs(r(corrected_a)-40)<1e-12 & abs(r(corrected_b)-20)<1e-12
    assert abs(r(corrected_c)-60)<1e-12 & abs(r(corrected_d)-80)<1e-12

}
if _rc {
    local ++fail
    display as error "FAIL: Outcome misclassification OR simple boundary_values; rc=" _rc
}
else {
    local ++pass
    display as result "PASS: Outcome misclassification OR simple boundary_values"
}

**# Outcome misclassification OR constantMC boundary_values
local ++tests
capture noisily {
    * expect: EXACT
    qa_fx_a6_bias, clear seed(37) perturb(boundary_values)
    tempname truth
    scalar `truth'=r(truth_or)
    local a=observed_n[1]
    local b=observed_n[3]
    local c=observed_n[2]
    local d=observed_n[4]
    local se=se[1]
    local sp=sp[1]
    quietly qba_misclass, a(`a') b(`b') c(`c') d(`d') seca(`se') spca(`sp') measure(OR) type(outcome) reps(100) seed(37)
    assert abs(r(corrected)-scalar(`truth'))<1e-12
    assert r(n_valid)==100 & abs(r(mean)-scalar(`truth'))<1e-12
    assert abs(r(ci_lower)-scalar(`truth'))<1e-12 & abs(r(ci_upper)-scalar(`truth'))<1e-12

}
if _rc {
    local ++fail
    display as error "FAIL: Outcome misclassification OR constantMC boundary_values; rc=" _rc
}
else {
    local ++pass
    display as result "PASS: Outcome misclassification OR constantMC boundary_values"
}

**# Outcome misclassification OR multi boundary_values
local ++tests
capture noisily {
    * expect: EXACT
    qa_fx_a6_bias, clear seed(37) perturb(boundary_values)
    tempname truth
    scalar `truth'=r(truth_or)
    local a=observed_n[1]
    local b=observed_n[3]
    local c=observed_n[2]
    local d=observed_n[4]
    local se=se[1]
    local sp=sp[1]
    quietly qba_multi, a(`a') b(`b') c(`c') d(`d') seca(`se') spca(`sp') measure(OR) mctype(outcome) reps(100) seed(37)
    assert abs(r(corrected)-scalar(`truth'))<1e-12
    assert r(n_valid)==100 & abs(r(mean)-scalar(`truth'))<1e-12
    assert abs(r(ci_lower)-scalar(`truth'))<1e-12 & abs(r(ci_upper)-scalar(`truth'))<1e-12

}
if _rc {
    local ++fail
    display as error "FAIL: Outcome misclassification OR multi boundary_values; rc=" _rc
}
else {
    local ++pass
    display as result "PASS: Outcome misclassification OR multi boundary_values"
}

**# Outcome misclassification RR simple boundary_values
local ++tests
capture noisily {
    * expect: EXACT
    qa_fx_a6_bias, clear seed(37) perturb(boundary_values)
    tempname truth
    scalar `truth'=r(truth_rr)
    local a=observed_n[1]
    local b=observed_n[3]
    local c=observed_n[2]
    local d=observed_n[4]
    local se=se[1]
    local sp=sp[1]
    quietly qba_misclass, a(`a') b(`b') c(`c') d(`d') seca(`se') spca(`sp') measure(RR) type(outcome)
    assert abs(r(corrected)-scalar(`truth'))<1e-12
    assert abs(r(corrected_a)-40)<1e-12 & abs(r(corrected_b)-20)<1e-12
    assert abs(r(corrected_c)-60)<1e-12 & abs(r(corrected_d)-80)<1e-12

}
if _rc {
    local ++fail
    display as error "FAIL: Outcome misclassification RR simple boundary_values; rc=" _rc
}
else {
    local ++pass
    display as result "PASS: Outcome misclassification RR simple boundary_values"
}

**# Outcome misclassification RR constantMC boundary_values
local ++tests
capture noisily {
    * expect: EXACT
    qa_fx_a6_bias, clear seed(37) perturb(boundary_values)
    tempname truth
    scalar `truth'=r(truth_rr)
    local a=observed_n[1]
    local b=observed_n[3]
    local c=observed_n[2]
    local d=observed_n[4]
    local se=se[1]
    local sp=sp[1]
    quietly qba_misclass, a(`a') b(`b') c(`c') d(`d') seca(`se') spca(`sp') measure(RR) type(outcome) reps(100) seed(37)
    assert abs(r(corrected)-scalar(`truth'))<1e-12
    assert r(n_valid)==100 & abs(r(mean)-scalar(`truth'))<1e-12
    assert abs(r(ci_lower)-scalar(`truth'))<1e-12 & abs(r(ci_upper)-scalar(`truth'))<1e-12

}
if _rc {
    local ++fail
    display as error "FAIL: Outcome misclassification RR constantMC boundary_values; rc=" _rc
}
else {
    local ++pass
    display as result "PASS: Outcome misclassification RR constantMC boundary_values"
}

**# Outcome misclassification RR multi boundary_values
local ++tests
capture noisily {
    * expect: EXACT
    qa_fx_a6_bias, clear seed(37) perturb(boundary_values)
    tempname truth
    scalar `truth'=r(truth_rr)
    local a=observed_n[1]
    local b=observed_n[3]
    local c=observed_n[2]
    local d=observed_n[4]
    local se=se[1]
    local sp=sp[1]
    quietly qba_multi, a(`a') b(`b') c(`c') d(`d') seca(`se') spca(`sp') measure(RR) mctype(outcome) reps(100) seed(37)
    assert abs(r(corrected)-scalar(`truth'))<1e-12
    assert r(n_valid)==100 & abs(r(mean)-scalar(`truth'))<1e-12
    assert abs(r(ci_lower)-scalar(`truth'))<1e-12 & abs(r(ci_upper)-scalar(`truth'))<1e-12

}
if _rc {
    local ++fail
    display as error "FAIL: Outcome misclassification RR multi boundary_values; rc=" _rc
}
else {
    local ++pass
    display as result "PASS: Outcome misclassification RR multi boundary_values"
}

**# Selection simple
local ++tests
capture noisily {
    qa_fx_a6_bias, clear seed(37)
    tempname truth
    scalar `truth'=r(truth_selection_or)
    local a=selection_n[1]
    local b=selection_n[3]
    local c=selection_n[2]
    local d=selection_n[4]
    quietly qba_selection, a(`a') b(`b') c(`c') d(`d') sela(.5) selb(1) selc(1) seld(1) measure(OR) 
    assert abs(r(corrected)-scalar(`truth'))<1e-12

}
if _rc {
    local ++fail
    display as error "FAIL: Selection simple; rc=" _rc
}
else {
    local ++pass
    display as result "PASS: Selection simple"
}

**# Selection constantMC
local ++tests
capture noisily {
    qa_fx_a6_bias, clear seed(37)
    tempname truth
    scalar `truth'=r(truth_selection_or)
    local a=selection_n[1]
    local b=selection_n[3]
    local c=selection_n[2]
    local d=selection_n[4]
    quietly qba_selection, a(`a') b(`b') c(`c') d(`d') sela(.5) selb(1) selc(1) seld(1) measure(OR) reps(100) seed(37)
    assert abs(r(corrected)-scalar(`truth'))<1e-12

}
if _rc {
    local ++fail
    display as error "FAIL: Selection constantMC; rc=" _rc
}
else {
    local ++pass
    display as result "PASS: Selection constantMC"
}

**# Selection multi
local ++tests
capture noisily {
    qa_fx_a6_bias, clear seed(37)
    tempname truth
    scalar `truth'=r(truth_selection_or)
    local a=selection_n[1]
    local b=selection_n[3]
    local c=selection_n[2]
    local d=selection_n[4]
    quietly qba_multi, a(`a') b(`b') c(`c') d(`d') sela(.5) selb(1) selc(1) seld(1) measure(OR) reps(100) seed(37)
    assert abs(r(corrected)-scalar(`truth'))<1e-12

}
if _rc {
    local ++fail
    display as error "FAIL: Selection multi; rc=" _rc
}
else {
    local ++pass
    display as result "PASS: Selection multi"
}

**# Confounding simple
local ++tests
capture noisily {
    qa_fx_a6_bias, clear seed(37)
    tempname truth
    scalar `truth'=r(truth_confounding_rr)
    quietly qba_confound, estimate(2) measure(RR) p1(.5) p0(`=1/6') rrcd(3) 
    assert abs(r(corrected)-scalar(`truth'))<1e-12

}
if _rc {
    local ++fail
    display as error "FAIL: Confounding simple; rc=" _rc
}
else {
    local ++pass
    display as result "PASS: Confounding simple"
}

**# Confounding constantMC
local ++tests
capture noisily {
    qa_fx_a6_bias, clear seed(37)
    tempname truth
    scalar `truth'=r(truth_confounding_rr)
    quietly qba_confound, estimate(2) measure(RR) p1(.5) p0(`=1/6') rrcd(3) reps(100) seed(37)
    assert abs(r(corrected)-scalar(`truth'))<1e-12

}
if _rc {
    local ++fail
    display as error "FAIL: Confounding constantMC; rc=" _rc
}
else {
    local ++pass
    display as result "PASS: Confounding constantMC"
}

display "RESULT: validation_qba_fixture_contract tests=`tests' pass=`pass' fail=`fail'"
log close
if `fail' exit 1
