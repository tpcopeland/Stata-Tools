*! validation_qba_metamorphic.do -- precise numerical payload, independent input arithmetic
*! Author: Timothy P Copeland, Karolinska Institutet
* Phase2 S1 probe; no session-hygiene or cosmetic contract claim.
version 16.0
clear all
set more off
capture log close _all
log using "validation_qba_metamorphic.log", text replace
local pkg_dir=substr("`c(pwd)'",1,strlen("`c(pwd)'")-3)
adopath ++ "`pkg_dir'"
local tests 0
local pass 0
local fail 0
do _qa_fx_a1.do
do _qa_metamorphic.do
* Scalar cell APIs have no row/list/variable/label role; those relations are
* inapplicable there. Count scaling preserves deterministic OR/RR and
* constant-draw systematic-error intervals, not sampling SE or totalerror.
* from_model consumes an actual fitted factor term: map the current native
* stripe explicitly after code/name changes, then compare its numeric payload.
capture program drop _qba_precision_factor
program define _qba_precision_factor, rclass
    version 16.0
    syntax , AVAR(varname)
    quietly levelsof `avar', local(levels)
    local base : word 1 of `levels'
    local active : word 2 of `levels'
    quietly regress y ib`base'.`avar' x1
    quietly qba_confound, from_model coef(`active'.`avar') p1(.75) p0(.25) confeffect(6)
    foreach result in observed corrected se ci_lower ci_upper {
        assert !missing(r(`result'))
    }
    assert r(se)>0
    return add
end
capture program drop _qba_precision_counts
program define _qba_precision_counts, rclass
    version 16.0
    syntax , ROUTE(string) MEASURE(string) WEIGHT(varname)
    local a : display regexr(string(1.2345678912345e-12*`weight'[1],"%21x"),"^[+]", "")
    local b : display regexr(string(.999999981*`weight'[1],"%21x"),"^[+]", "")
    local c : display regexr(string(1.2345678912345*`weight'[1],"%21x"),"^[+]", "")
    local d : display regexr(string(.99999999912345*`weight'[1],"%21x"),"^[+]", "")
    if "`route'"=="misclass" {
        quietly qba_misclass, a(`a') b(`b') c(`c') d(`d') seca(1) spca(1) type(outcome) measure(`measure')
    }
    else if "`route'"=="selection" {
        quietly qba_selection, a(`a') b(`b') c(`c') d(`d') sela(.12345678912345) selb(1) selc(1) seld(1) measure(`measure')
    }
    else {
        quietly qba_multi, a(`a') b(`b') c(`c') d(`d') seca(1) spca(1) mctype(outcome) sela(.12345678912345) selb(1) selc(1) seld(1) measure(`measure') reps(100) seed(37)
    }
    assert !missing(r(corrected)) & r(corrected)>0
    if "`route'"=="multi" {
        foreach result in mean ci_lower ci_upper n_valid {
            assert !missing(r(`result'))
        }
        assert r(n_valid)==100
    }
    return add
end

**# from_model unsorted factor numerical invariance
local ++tests
capture noisily {
    qa_fx_a1_gauss, clear seed(37)
    qa_metamorphic unsorted, command(_qba_precision_factor, avar(@var@)) var(a) returns(r(observed) r(corrected) r(se) r(ci_lower) r(ci_upper)) tol(1e-12)

}
if _rc {
    local ++fail
    display as error "FAIL: from_model unsorted factor numerical invariance; rc=" _rc
}
else {
    local ++pass
    display as result "PASS: from_model unsorted factor numerical invariance"
}

**# from_model codes_multidigit factor numerical invariance
local ++tests
capture noisily {
    qa_fx_a1_gauss, clear seed(37)
    qa_metamorphic codes_multidigit, command(_qba_precision_factor, avar(@var@)) var(a) returns(r(observed) r(corrected) r(se) r(ci_lower) r(ci_upper)) tol(1e-12)

}
if _rc {
    local ++fail
    display as error "FAIL: from_model codes_multidigit factor numerical invariance; rc=" _rc
}
else {
    local ++pass
    display as result "PASS: from_model codes_multidigit factor numerical invariance"
}

**# from_model codes_sparse factor numerical invariance
local ++tests
capture noisily {
    qa_fx_a1_gauss, clear seed(37)
    qa_metamorphic codes_sparse, command(_qba_precision_factor, avar(@var@)) var(a) returns(r(observed) r(corrected) r(se) r(ci_lower) r(ci_upper)) tol(1e-12)

}
if _rc {
    local ++fail
    display as error "FAIL: from_model codes_sparse factor numerical invariance; rc=" _rc
}
else {
    local ++pass
    display as result "PASS: from_model codes_sparse factor numerical invariance"
}

**# from_model long_names factor numerical invariance
local ++tests
capture noisily {
    qa_fx_a1_gauss, clear seed(37)
    qa_metamorphic long_names, command(_qba_precision_factor, avar(@var@)) var(a) returns(r(observed) r(corrected) r(se) r(ci_lower) r(ci_upper)) tol(1e-12)

}
if _rc {
    local ++fail
    display as error "FAIL: from_model long_names factor numerical invariance; rc=" _rc
}
else {
    local ++pass
    display as result "PASS: from_model long_names factor numerical invariance"
}

**# misclass OR deterministic count scaling
local ++tests
capture noisily {
    clear
    set obs 1
    generate double w=1
    qa_metamorphic weight_scale, command(_qba_precision_counts, route(misclass) measure(OR) weight(@w@)) weight(w) factor(1000003) returns(r(corrected)) tol(1e-12)

}
if _rc {
    local ++fail
    display as error "FAIL: misclass OR deterministic count scaling; rc=" _rc
}
else {
    local ++pass
    display as result "PASS: misclass OR deterministic count scaling"
}

**# misclass RR deterministic count scaling
local ++tests
capture noisily {
    clear
    set obs 1
    generate double w=1
    qa_metamorphic weight_scale, command(_qba_precision_counts, route(misclass) measure(RR) weight(@w@)) weight(w) factor(1000003) returns(r(corrected)) tol(1e-12)

}
if _rc {
    local ++fail
    display as error "FAIL: misclass RR deterministic count scaling; rc=" _rc
}
else {
    local ++pass
    display as result "PASS: misclass RR deterministic count scaling"
}

**# selection OR deterministic count scaling
local ++tests
capture noisily {
    clear
    set obs 1
    generate double w=1
    qa_metamorphic weight_scale, command(_qba_precision_counts, route(selection) measure(OR) weight(@w@)) weight(w) factor(1000003) returns(r(corrected)) tol(1e-12)

}
if _rc {
    local ++fail
    display as error "FAIL: selection OR deterministic count scaling; rc=" _rc
}
else {
    local ++pass
    display as result "PASS: selection OR deterministic count scaling"
}

**# selection RR deterministic count scaling
local ++tests
capture noisily {
    clear
    set obs 1
    generate double w=1
    qa_metamorphic weight_scale, command(_qba_precision_counts, route(selection) measure(RR) weight(@w@)) weight(w) factor(1000003) returns(r(corrected)) tol(1e-12)

}
if _rc {
    local ++fail
    display as error "FAIL: selection RR deterministic count scaling; rc=" _rc
}
else {
    local ++pass
    display as result "PASS: selection RR deterministic count scaling"
}

**# multi OR deterministic count scaling
local ++tests
capture noisily {
    clear
    set obs 1
    generate double w=1
    qa_metamorphic weight_scale, command(_qba_precision_counts, route(multi) measure(OR) weight(@w@)) weight(w) factor(1000003) returns(r(corrected) r(mean) r(ci_lower) r(ci_upper) r(n_valid)) tol(1e-12)

}
if _rc {
    local ++fail
    display as error "FAIL: multi OR deterministic count scaling; rc=" _rc
}
else {
    local ++pass
    display as result "PASS: multi OR deterministic count scaling"
}

**# multi RR deterministic count scaling
local ++tests
capture noisily {
    clear
    set obs 1
    generate double w=1
    qa_metamorphic weight_scale, command(_qba_precision_counts, route(multi) measure(RR) weight(@w@)) weight(w) factor(1000003) returns(r(corrected) r(mean) r(ci_lower) r(ci_upper) r(n_valid)) tol(1e-12)

}
if _rc {
    local ++fail
    display as error "FAIL: multi RR deterministic count scaling; rc=" _rc
}
else {
    local ++pass
    display as result "PASS: multi RR deterministic count scaling"
}

display "RESULT: validation_qba_metamorphic tests=`tests' pass=`pass' fail=`fail' skip=0"
log close
if `fail' exit 1
