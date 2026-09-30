* test_fixture_contract.do -- canonical F/U fixture adoption (2026-09-30)
* Author: Timothy P Copeland, Karolinska Institutet
* guard: seeded dup_key/single_period and late-save refusals are red on pre-fix 1e593bb7; other cells add coverage.
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
do "`qa_dir'/_qa_fx_a3.do"
do "`qa_dir'/_qa_state.do"
local test_count 0
local pass_count 0
local fail_count 0

**# U: unsorted preserves exact SAT intervention risks
local ++test_count
capture noisily {
    tempname b0 b1 tab0 tab1
    qa_fx_a1_sat, clear
    expand 10
    replace id = _n
    expand 2
    bysort id: gen byte time = _n
    replace y = . if time == 1
    quietly gcomp y a s x2, outcome(y) idvar(id) tvar(time) eofu fixedcovariates(s x2) ///
        intvars(a) interventions(a=1, a=0) commands(a: logit, y: logit) ///
        equations(a: i.s##i.x2, y: i.a##i.s##i.x2) sim(1200) samples(2) seed(9141) minsim
    matrix `b0' = e(b)
    tempfile book0 book1
    quietly gcomptab, doseresponse reference(2) sheet("Fixture") xlsx("`book0'.xlsx")
    matrix `tab0' = r(table)
    erase "`book0'.xlsx"
    * expect: INVARIANT
    qa_fx_a1_sat, clear perturb(unsorted)
    assert "`r(perturb_applied)'" == "unsorted"
    expand 10
    replace id = _n
    expand 2
    bysort id: gen byte time = _n
    replace y = . if time == 1
    quietly gcomp y a s x2, outcome(y) idvar(id) tvar(time) eofu fixedcovariates(s x2) ///
        intvars(a) interventions(a=1, a=0) commands(a: logit, y: logit) ///
        equations(a: i.s##i.x2, y: i.a##i.s##i.x2) sim(1200) samples(2) seed(9141) minsim
    matrix `b1' = e(b)
    quietly gcomptab, doseresponse reference(2) sheet("Fixture") xlsx("`book1'.xlsx")
    matrix `tab1' = r(table)
    erase "`book1'.xlsx"
    assert !missing(`b0'[1,1], `b1'[1,1], `b0'[1,2], `b1'[1,2])
    assert reldif(`b0'[1,1], `b1'[1,1]) < 1e-8
    assert reldif(`b0'[1,2], `b1'[1,2]) < 1e-8
    assert !missing(`tab0'[1,1], `tab1'[1,1], `tab0'[1,5], `tab1'[1,5])
    assert reldif(`tab0'[1,1], `tab1'[1,1]) < 1e-8
    assert reldif(`tab0'[1,5], `tab1'[1,5]) < 1e-8
}
if _rc == 0 {
    local ++pass_count
    display as result "PASS: U: unsorted preserves exact SAT intervention risks"
}
else {
    local ++fail_count
    display as error "FAIL: U: unsorted preserves exact SAT intervention risks (rc=`=_rc')"
}

**# U: codes_multidigit preserves exact SAT intervention risks
local ++test_count
capture noisily {
    tempname b0 b1 tab0 tab1
    qa_fx_a1_sat, clear
    expand 10
    replace id = _n
    expand 2
    bysort id: gen byte time = _n
    replace y = . if time == 1
    quietly gcomp y a s x2, outcome(y) idvar(id) tvar(time) eofu fixedcovariates(s x2) ///
        intvars(a) interventions(a=1, a=0) commands(a: logit, y: logit) ///
        equations(a: i.s##i.x2, y: i.a##i.s##i.x2) sim(1200) samples(2) seed(9141) minsim
    matrix `b0' = e(b)
    tempfile book0 book1
    quietly gcomptab, doseresponse reference(2) sheet("Fixture") xlsx("`book0'.xlsx")
    matrix `tab0' = r(table)
    erase "`book0'.xlsx"
    * expect: INVARIANT
    qa_fx_a1_sat, clear perturb(codes_multidigit)
    assert "`r(perturb_applied)'" == "codes_multidigit"
    expand 10
    replace id = _n
    expand 2
    bysort id: gen byte time = _n
    replace y = . if time == 1
    quietly gcomp y a s x2, outcome(y) idvar(id) tvar(time) eofu fixedcovariates(s x2) ///
        intvars(a) interventions(a=1, a=0) commands(a: logit, y: logit) ///
        equations(a: i.s##i.x2, y: i.a##i.s##i.x2) sim(1200) samples(2) seed(9141) minsim
    matrix `b1' = e(b)
    quietly gcomptab, doseresponse reference(2) sheet("Fixture") xlsx("`book1'.xlsx")
    matrix `tab1' = r(table)
    erase "`book1'.xlsx"
    assert !missing(`b0'[1,1], `b1'[1,1], `b0'[1,2], `b1'[1,2])
    assert reldif(`b0'[1,1], `b1'[1,1]) < 1e-8
    assert reldif(`b0'[1,2], `b1'[1,2]) < 1e-8
    assert !missing(`tab0'[1,1], `tab1'[1,1], `tab0'[1,5], `tab1'[1,5])
    assert reldif(`tab0'[1,1], `tab1'[1,1]) < 1e-8
    assert reldif(`tab0'[1,5], `tab1'[1,5]) < 1e-8
}
if _rc == 0 {
    local ++pass_count
    display as result "PASS: U: codes_multidigit preserves exact SAT intervention risks"
}
else {
    local ++fail_count
    display as error "FAIL: U: codes_multidigit preserves exact SAT intervention risks (rc=`=_rc')"
}

**# U: codes_sparse preserves exact SAT intervention risks
local ++test_count
capture noisily {
    tempname b0 b1 tab0 tab1
    qa_fx_a1_sat, clear
    expand 10
    replace id = _n
    expand 2
    bysort id: gen byte time = _n
    replace y = . if time == 1
    quietly gcomp y a s x2, outcome(y) idvar(id) tvar(time) eofu fixedcovariates(s x2) ///
        intvars(a) interventions(a=1, a=0) commands(a: logit, y: logit) ///
        equations(a: i.s##i.x2, y: i.a##i.s##i.x2) sim(1200) samples(2) seed(9141) minsim
    matrix `b0' = e(b)
    tempfile book0 book1
    quietly gcomptab, doseresponse reference(2) sheet("Fixture") xlsx("`book0'.xlsx")
    matrix `tab0' = r(table)
    erase "`book0'.xlsx"
    * expect: INVARIANT
    qa_fx_a1_sat, clear perturb(codes_sparse)
    assert "`r(perturb_applied)'" == "codes_sparse"
    expand 10
    replace id = _n
    expand 2
    bysort id: gen byte time = _n
    replace y = . if time == 1
    quietly gcomp y a s x2, outcome(y) idvar(id) tvar(time) eofu fixedcovariates(s x2) ///
        intvars(a) interventions(a=1, a=0) commands(a: logit, y: logit) ///
        equations(a: i.s##i.x2, y: i.a##i.s##i.x2) sim(1200) samples(2) seed(9141) minsim
    matrix `b1' = e(b)
    quietly gcomptab, doseresponse reference(2) sheet("Fixture") xlsx("`book1'.xlsx")
    matrix `tab1' = r(table)
    erase "`book1'.xlsx"
    assert !missing(`b0'[1,1], `b1'[1,1], `b0'[1,2], `b1'[1,2])
    assert reldif(`b0'[1,1], `b1'[1,1]) < 1e-8
    assert reldif(`b0'[1,2], `b1'[1,2]) < 1e-8
    assert !missing(`tab0'[1,1], `tab1'[1,1], `tab0'[1,5], `tab1'[1,5])
    assert reldif(`tab0'[1,1], `tab1'[1,1]) < 1e-8
    assert reldif(`tab0'[1,5], `tab1'[1,5]) < 1e-8
}
if _rc == 0 {
    local ++pass_count
    display as result "PASS: U: codes_sparse preserves exact SAT intervention risks"
}
else {
    local ++fail_count
    display as error "FAIL: U: codes_sparse preserves exact SAT intervention risks (rc=`=_rc')"
}

**# U: dup_key refuses before changing caller state
local ++test_count
capture noisily {
    qa_fx_a3_seq, clear n(1200) k(1) seed(9145)
    expand 2
    bysort id: gen byte time = _n
    replace y = . if time == 1
    quietly gcomp y a l0 l_t xcat, outcome(y) idvar(id) tvar(time) eofu fixedcovariates(l0 l_t xcat) ///
        intvars(a) interventions(a=1, a=0) commands(a: logit, y: logit) ///
        equations(a: l_t l0, y: a l_t l0 i.xcat) sim(1200) samples(2) seed(9145) minsim
    assert e(N_subjects) == 1200
    * expect: REFUSED
    qa_fx_a3_seq, clear n(1200) seed(9145) perturb(dup_key)
    quietly regress y l_t l0
    tempfile msg
    tempname lh fh
    capture log close _all
    log using "`msg'", text replace name(`lh') nomsg
    qa_state_snapshot, tag(fxdupkey)
    capture noisily gcomp y a l0 l_t xcat, outcome(y) idvar(id) tvar(period) fixedcovariates(l0 xcat) ///
        intvars(a) interventions(a=1, a=0) commands(a: logit, y: logit) ///
        equations(a: l_t l0, y: a l_t l0 i.xcat) sim(1200) samples(2) seed(9145)
    local rc = _rc
    assert `rc' == 459
    qa_state_compare, tag(fxdupkey)
    log close `lh'
    file open `fh' using "`msg'", read text
    file read `fh' line
    local cause 0
    while r(eof) == 0 {
        if strpos(`"`line'"', "uniquely identify") local cause 1
        file read `fh' line
    }
    file close `fh'
    assert `cause' == 1
}
if _rc == 0 {
    local ++pass_count
    display as result "PASS: U: dup_key refuses before changing caller state"
}
else {
    local ++fail_count
    display as error "FAIL: U: dup_key refuses before changing caller state (rc=`=_rc')"
}

**# U: single_period refuses before changing caller state
local ++test_count
capture noisily {
    qa_fx_a3_seq, clear n(1200) k(1) seed(9145)
    expand 2
    bysort id: gen byte time = _n
    replace y = . if time == 1
    quietly gcomp y a l0 l_t xcat, outcome(y) idvar(id) tvar(time) eofu fixedcovariates(l0 l_t xcat) ///
        intvars(a) interventions(a=1, a=0) commands(a: logit, y: logit) ///
        equations(a: l_t l0, y: a l_t l0 i.xcat) sim(1200) samples(2) seed(9145) minsim
    assert e(N_subjects) == 1200
    * expect: REFUSED
    qa_fx_a3_seq, clear n(1200) seed(9145) perturb(single_period)
    quietly regress y l_t l0
    tempfile msg
    tempname lh fh
    capture log close _all
    log using "`msg'", text replace name(`lh') nomsg
    qa_state_snapshot, tag(fxsingleperiod)
    capture noisily gcomp y a l0 l_t xcat, outcome(y) idvar(id) tvar(period) fixedcovariates(l0 xcat) ///
        intvars(a) interventions(a=1, a=0) commands(a: logit, y: logit) ///
        equations(a: l_t l0, y: a l_t l0 i.xcat) sim(1200) samples(2) seed(9145)
    local rc = _rc
    assert `rc' == 2000
    qa_state_compare, tag(fxsingleperiod)
    log close `lh'
    file open `fh' using "`msg'", read text
    file read `fh' line
    local cause 0
    while r(eof) == 0 {
        if strpos(`"`line'"', "at least two observed visit") local cause 1
        file read `fh' line
    }
    file close `fh'
    assert `cause' == 1
}
if _rc == 0 {
    local ++pass_count
    display as result "PASS: U: single_period refuses before changing caller state"
}
else {
    local ++fail_count
    display as error "FAIL: U: single_period refuses before changing caller state (rc=`=_rc')"
}

**# U: collinear nuisance predictors preserve fitted intervention means
local ++test_count
capture noisily {
    tempname b0 b1
    qa_fx_a1_logit, clear n(1800) seed(9147)
    expand 2
    bysort id: gen byte time = _n
    replace y = . if time == 1
    quietly gcomp y a x1 x2 xcat, outcome(y) idvar(id) tvar(time) eofu fixedcovariates(x1 x2 xcat) ///
        intvars(a) interventions(a=1, a=0) commands(a: logit, y: logit) ///
        equations(a: x1 x2 i.xcat, y: a x1 x2 i.xcat) sim(1800) samples(2) seed(9147) minsim
    matrix `b0' = e(b)
    * expect: INVARIANT
    qa_fx_a1_logit, clear n(1800) seed(9147) perturb(collinear)
    assert x3 == x1 & x4 == x1+x2
    expand 2
    bysort id: gen byte time = _n
    replace y = . if time == 1
    quietly gcomp y a x1 x2 xcat x3 x4, outcome(y) idvar(id) tvar(time) eofu fixedcovariates(x1 x2 xcat x3 x4) ///
        intvars(a) interventions(a=1, a=0) commands(a: logit, y: logit) ///
        equations(a: x1 x2 i.xcat x3 x4, y: a x1 x2 i.xcat x3 x4) sim(1800) samples(2) seed(9147) minsim
    matrix `b1' = e(b)
    assert !missing(`b0'[1,1], `b0'[1,2], `b1'[1,1], `b1'[1,2])
    assert reldif(`b0'[1,1], `b1'[1,1]) < 1e-8
    assert reldif(`b0'[1,2], `b1'[1,2]) < 1e-8
}
if _rc == 0 {
    local ++pass_count
    display as result "PASS: U: collinear nuisance predictors preserve fitted intervention means"
}
else {
    local ++fail_count
    display as error "FAIL: U: collinear nuisance predictors preserve fitted intervention means (rc=`=_rc')"
}

**# U: absent original base level preserves selected-cohort means
local ++test_count
capture noisily {
    tempname b0 b1
    qa_fx_a1_logit, clear n(1800) seed(9147)
    keep if xcat != 1
    expand 2
    bysort id: gen byte time = _n
    replace y = . if time == 1
    quietly gcomp y a x1 x2 xcat, outcome(y) idvar(id) tvar(time) eofu fixedcovariates(x1 x2 xcat) ///
        intvars(a) interventions(a=1, a=0) commands(a: logit, y: logit) ///
        equations(a: x1 x2 i.xcat, y: a x1 x2 i.xcat) sim(1200) samples(2) seed(9147) minsim
    matrix `b0' = e(b)
    * expect: INVARIANT
    qa_fx_a1_logit, clear n(1800) seed(9147) perturb(base_absent)
    assert insample == (xcat != 1)
    keep if insample
    expand 2
    bysort id: gen byte time = _n
    replace y = . if time == 1
    quietly gcomp y a x1 x2 xcat, outcome(y) idvar(id) tvar(time) eofu fixedcovariates(x1 x2 xcat) ///
        intvars(a) interventions(a=1, a=0) commands(a: logit, y: logit) ///
        equations(a: x1 x2 i.xcat, y: a x1 x2 i.xcat) sim(1200) samples(2) seed(9147) minsim
    matrix `b1' = e(b)
    assert e(N_subjects) == 1200
    assert !missing(`b0'[1,1], `b0'[1,2], `b1'[1,1], `b1'[1,2])
    assert reldif(`b0'[1,1], `b1'[1,1]) < 1e-8
    assert reldif(`b0'[1,2], `b1'[1,2]) < 1e-8
}
if _rc == 0 {
    local ++pass_count
    display as result "PASS: U: absent original base level preserves selected-cohort means"
}
else {
    local ++fail_count
    display as error "FAIL: U: absent original base level preserves selected-cohort means (rc=`=_rc')"
}

**# U: late save refusal restores RNG and foreign estimates after simulation
local ++test_count
capture noisily {
    qa_fx_a1_sat, clear
    expand 10
    replace id = _n
    expand 2
    bysort id: gen byte time = _n
    replace y = . if time == 1
    quietly gcomp y a s x2, outcome(y) idvar(id) tvar(time) eofu fixedcovariates(s x2) ///
        intvars(a) interventions(a=1, a=0) commands(a: logit, y: logit) ///
        equations(a: i.s##i.x2, y: i.a##i.s##i.x2) sim(1200) samples(2) seed(9141) minsim
    assert e(N_subjects) == 1200
    quietly regress y s x2
    * expect: REFUSED
    tempfile nonexistent msg
    tempname lh fh
    capture log close _all
    log using "`msg'", text replace name(`lh') nomsg
    qa_state_snapshot, tag(fxlatesave)
    capture noisily gcomp y a s x2, outcome(y) idvar(id) tvar(time) eofu fixedcovariates(s x2) ///
        intvars(a) interventions(a=1, a=0) commands(a: logit, y: logit) ///
        equations(a: i.s##i.x2, y: i.a##i.s##i.x2) sim(1200) samples(2) seed(9141) minsim saving("`nonexistent'/cannot-save.dta") replace
    local rc = _rc
    assert `rc' == 603
    qa_state_compare, tag(fxlatesave)
    log close `lh'
    file open `fh' using "`msg'", read text
    file read `fh' line
    local cause 0
    local simulated 0
    while r(eof) == 0 {
        if strpos(`"`line'"', "could not be opened") local cause 1
        if strpos(`"`line'"', "Fitting parametric models and simulating") local simulated 1
        file read `fh' line
    }
    file close `fh'
    assert `cause' == 1 & `simulated' == 1
}
if _rc == 0 {
    local ++pass_count
    display as result "PASS: U: late save refusal restores RNG and foreign estimates after simulation"
}
else {
    local ++fail_count
    display as error "FAIL: U: late save refusal restores RNG and foreign estimates after simulation (rc=`=_rc')"
}

**# U: duplicate-key refusal also preserves an unseeded caller stream
local ++test_count
capture noisily {
    * expect: REFUSED
    qa_fx_a3_seq, clear n(1200) seed(9145) perturb(dup_key)
    quietly regress y l_t l0
    tempfile msg
    tempname lh fh
    capture log close _all
    log using "`msg'", text replace name(`lh') nomsg
    qa_state_snapshot, tag(fxnoseed)
    capture noisily gcomp y a l0 l_t xcat, outcome(y) idvar(id) tvar(period) fixedcovariates(l0 xcat) ///
        intvars(a) interventions(a=1, a=0) commands(a: logit, y: logit) ///
        equations(a: l_t l0, y: a l_t l0 i.xcat) sim(1200) samples(2)
    local rc = _rc
    assert `rc' == 459
    qa_state_compare, tag(fxnoseed)
    log close `lh'
    file open `fh' using "`msg'", read text
    file read `fh' line
    local cause 0
    while r(eof) == 0 {
        if strpos(`"`line'"', "uniquely identify") local cause 1
        file read `fh' line
    }
    file close `fh'
    assert `cause' == 1
}
if _rc == 0 {
    local ++pass_count
    display as result "PASS: U: duplicate-key refusal also preserves an unseeded caller stream"
}
else {
    local ++fail_count
    display as error "FAIL: U: duplicate-key refusal also preserves an unseeded caller stream (rc=`=_rc')"
}

display as text "RESULT: test_fixture_contract tests=`test_count' pass=`pass_count' fail=`fail_count' skip=0"
capture log close _all
if `fail_count' > 0 exit 1
