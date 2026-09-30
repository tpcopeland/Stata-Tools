* test_fixture_domains.do -- documented domain controls on exact SAT risks
* Author: Timothy P Copeland, Karolinska Institutet
* guard: seeded later-validation fingerprints are red on pre-fix 1e593bb7; domain controls add coverage.
version 16.0
clear all
set more off
set varabbrev off
set processors 1
capture log close _all
local qa_dir "`c(pwd)'"
do "`qa_dir'/_qa_bootstrap.do"
do "`qa_dir'/_qa_fx_a1.do"
do "`qa_dir'/_qa_state.do"
do "`qa_dir'/_qa_metamorphic.do"
local test_count 0
local pass_count 0
local fail_count 0

**# U: boundary_values -- documented simulations domain with strict refusals
local ++test_count
capture noisily {
    qa_fx_a1_sat, clear
    expand 10
    replace id = _n
    expand 2
    bysort id: gen byte time = _n
    replace y = . if time == 1
    quietly gcomp y a s x2, outcome(y) idvar(id) tvar(time) eofu fixedcovariates(s x2) intvars(a) interventions(a=1, a=0) commands(a: logit, y: logit) equations(a: i.s##i.x2, y: i.a##i.s##i.x2) sim(1200) samples(2) seed(9141) minsim
    tempname truthb
    matrix `truthb' = e(b)
    assert !missing(`truthb'[1,1], `truthb'[1,2])
    assert abs(`truthb'[1,1]-11/20) < 1e-8 & abs(`truthb'[1,2]-49/120) < 1e-8
    * expect: REFUSED
    qa_option_domain, command(gcomp y a s x2, outcome(y) idvar(id) tvar(time) eofu fixedcovariates(s x2) intvars(a) interventions(a=1, a=0) commands(a: logit, y: logit) equations(a: i.s##i.x2, y: i.a##i.s##i.x2) sim(@v@) samples(2) seed(9141) minsim) ///
        inside("1;1200") outside("0;-1") ///
        check(assert !missing(el(e(b),1,1),el(e(b),1,2)) & e(N_subjects)==1200)
    assert r(n_violations) == 0
    * Repeat outside cells with the complete caller fingerprint and named cause.
    quietly regress y s x2
    local fx_template "gcomp y a s x2, outcome(y) idvar(id) tvar(time) eofu fixedcovariates(s x2) intvars(a) interventions(a=1, a=0) commands(a: logit, y: logit) equations(a: i.s##i.x2, y: i.a##i.s##i.x2) sim(@v@) samples(2) seed(9141) minsim"
    local fx_values "0 -1"
    foreach v of local fx_values {
        local fx_command : subinstr local fx_template "@v@" "`v'", all
        tempfile msg
        tempname lh found
        capture log close _all
        log using "`msg'", text replace name(`lh') nomsg
        qa_state_snapshot, tag(fxdomain)
        capture noisily `fx_command'
        local fx_rc = _rc
        assert `fx_rc' == 198
        qa_state_compare, tag(fxdomain)
        log close `lh'
        mata: st_numscalar("`found'", _qa_mm_logfind("`msg'", "number of Monte Carlo simulations must be 1 or more"))
        assert `found' == 1
    }
}
if _rc == 0 {
    local ++pass_count
    display as result "PASS: U: boundary_values simulations documented domain"
}
else {
    local ++fail_count
    display as error "FAIL: U: boundary_values simulations documented domain (rc=`=_rc')"
}

**# U: boundary_values -- documented samples domain with strict refusals
local ++test_count
capture noisily {
    qa_fx_a1_sat, clear
    expand 10
    replace id = _n
    expand 2
    bysort id: gen byte time = _n
    replace y = . if time == 1
    quietly gcomp y a s x2, outcome(y) idvar(id) tvar(time) eofu fixedcovariates(s x2) intvars(a) interventions(a=1, a=0) commands(a: logit, y: logit) equations(a: i.s##i.x2, y: i.a##i.s##i.x2) sim(1200) samples(2) seed(9141) minsim
    tempname truthb
    matrix `truthb' = e(b)
    assert !missing(`truthb'[1,1], `truthb'[1,2])
    assert abs(`truthb'[1,1]-11/20) < 1e-8 & abs(`truthb'[1,2]-49/120) < 1e-8
    * expect: REFUSED
    qa_option_domain, command(gcomp y a s x2, outcome(y) idvar(id) tvar(time) eofu fixedcovariates(s x2) intvars(a) interventions(a=1, a=0) commands(a: logit, y: logit) equations(a: i.s##i.x2, y: i.a##i.s##i.x2) sim(1200) samples(@v@) seed(9141) minsim) ///
        inside("2;3") outside("1;0") ///
        check(assert !missing(el(e(b),1,1),el(e(b),1,2)) & e(N_subjects)==1200)
    assert r(n_violations) == 0
    * Repeat outside cells with the complete caller fingerprint and named cause.
    quietly regress y s x2
    local fx_template "gcomp y a s x2, outcome(y) idvar(id) tvar(time) eofu fixedcovariates(s x2) intvars(a) interventions(a=1, a=0) commands(a: logit, y: logit) equations(a: i.s##i.x2, y: i.a##i.s##i.x2) sim(1200) samples(@v@) seed(9141) minsim"
    local fx_values "1 0"
    foreach v of local fx_values {
        local fx_command : subinstr local fx_template "@v@" "`v'", all
        tempfile msg
        tempname lh found
        capture log close _all
        log using "`msg'", text replace name(`lh') nomsg
        qa_state_snapshot, tag(fxdomain)
        capture noisily `fx_command'
        local fx_rc = _rc
        assert `fx_rc' == 198
        qa_state_compare, tag(fxdomain)
        log close `lh'
        mata: st_numscalar("`found'", _qa_mm_logfind("`msg'", "number of bootstrap samples must be 2 or more"))
        assert `found' == 1
    }
}
if _rc == 0 {
    local ++pass_count
    display as result "PASS: U: boundary_values samples documented domain"
}
else {
    local ++fail_count
    display as error "FAIL: U: boundary_values samples documented domain (rc=`=_rc')"
}

**# U: boundary_values -- documented seed domain with strict refusals
local ++test_count
capture noisily {
    qa_fx_a1_sat, clear
    expand 10
    replace id = _n
    expand 2
    bysort id: gen byte time = _n
    replace y = . if time == 1
    quietly gcomp y a s x2, outcome(y) idvar(id) tvar(time) eofu fixedcovariates(s x2) intvars(a) interventions(a=1, a=0) commands(a: logit, y: logit) equations(a: i.s##i.x2, y: i.a##i.s##i.x2) sim(1200) samples(2) seed(9141) minsim
    tempname truthb
    matrix `truthb' = e(b)
    assert !missing(`truthb'[1,1], `truthb'[1,2])
    assert abs(`truthb'[1,1]-11/20) < 1e-8 & abs(`truthb'[1,2]-49/120) < 1e-8
    * expect: REFUSED
    qa_option_domain, command(gcomp y a s x2, outcome(y) idvar(id) tvar(time) eofu fixedcovariates(s x2) intvars(a) interventions(a=1, a=0) commands(a: logit, y: logit) equations(a: i.s##i.x2, y: i.a##i.s##i.x2) sim(1200) samples(2) seed(@v@) minsim) ///
        inside("9141;9142") outside("0;-1;1.5") ///
        check(assert !missing(el(e(b),1,1),el(e(b),1,2)) & e(N_subjects)==1200)
    assert r(n_violations) == 0
    * Repeat outside cells with the complete caller fingerprint and named cause.
    quietly regress y s x2
    local fx_template "gcomp y a s x2, outcome(y) idvar(id) tvar(time) eofu fixedcovariates(s x2) intvars(a) interventions(a=1, a=0) commands(a: logit, y: logit) equations(a: i.s##i.x2, y: i.a##i.s##i.x2) sim(1200) samples(2) seed(@v@) minsim"
    local fx_values "0 -1 1.5"
    foreach v of local fx_values {
        local fx_command : subinstr local fx_template "@v@" "`v'", all
        tempfile msg
        tempname lh found
        capture log close _all
        log using "`msg'", text replace name(`lh') nomsg
        qa_state_snapshot, tag(fxdomain)
        capture noisily `fx_command'
        local fx_rc = _rc
        assert `fx_rc' == 198
        qa_state_compare, tag(fxdomain)
        log close `lh'
        mata: st_numscalar("`found'", _qa_mm_logfind("`msg'", "seed() must"))
        assert `found' == 1
    }
}
if _rc == 0 {
    local ++pass_count
    display as result "PASS: U: boundary_values seed documented domain"
}
else {
    local ++fail_count
    display as error "FAIL: U: boundary_values seed documented domain (rc=`=_rc')"
}

**# U: boundary_values -- documented imp_cycles domain with strict refusals
local ++test_count
capture noisily {
    qa_fx_a1_sat, clear
    expand 10
    replace id = _n
    expand 2
    bysort id: gen byte time = _n
    replace y = . if time == 1
    quietly gcomp y a s x2, outcome(y) idvar(id) tvar(time) eofu fixedcovariates(s x2) intvars(a) interventions(a=1, a=0) commands(a: logit, y: logit) equations(a: i.s##i.x2, y: i.a##i.s##i.x2) sim(1200) samples(2) seed(9141) minsim
    tempname truthb
    matrix `truthb' = e(b)
    assert !missing(`truthb'[1,1], `truthb'[1,2])
    assert abs(`truthb'[1,1]-11/20) < 1e-8 & abs(`truthb'[1,2]-49/120) < 1e-8
    * expect: REFUSED
    qa_option_domain, command(gcomp y a s x2, outcome(y) idvar(id) tvar(time) eofu fixedcovariates(s x2) intvars(a) interventions(a=1, a=0) commands(a: logit, y: logit) equations(a: i.s##i.x2, y: i.a##i.s##i.x2) sim(1200) samples(2) seed(9141) minsim imp_cycles(@v@)) ///
        inside("1;2") outside("0;-1") ///
        check(assert !missing(el(e(b),1,1),el(e(b),1,2)) & e(N_subjects)==1200)
    assert r(n_violations) == 0
    * Repeat outside cells with the complete caller fingerprint and named cause.
    quietly regress y s x2
    local fx_template "gcomp y a s x2, outcome(y) idvar(id) tvar(time) eofu fixedcovariates(s x2) intvars(a) interventions(a=1, a=0) commands(a: logit, y: logit) equations(a: i.s##i.x2, y: i.a##i.s##i.x2) sim(1200) samples(2) seed(9141) minsim imp_cycles(@v@)"
    local fx_values "0 -1"
    foreach v of local fx_values {
        local fx_command : subinstr local fx_template "@v@" "`v'", all
        tempfile msg
        tempname lh found
        capture log close _all
        log using "`msg'", text replace name(`lh') nomsg
        qa_state_snapshot, tag(fxdomain)
        capture noisily `fx_command'
        local fx_rc = _rc
        assert `fx_rc' == 198
        qa_state_compare, tag(fxdomain)
        log close `lh'
        mata: st_numscalar("`found'", _qa_mm_logfind("`msg'", "number of imputation cycles must be 1 or more"))
        assert `found' == 1
    }
}
if _rc == 0 {
    local ++pass_count
    display as result "PASS: U: boundary_values imp_cycles documented domain"
}
else {
    local ++fail_count
    display as error "FAIL: U: boundary_values imp_cycles documented domain (rc=`=_rc')"
}

**# U: boundary_values -- documented modelstyle domain with strict refusals
local ++test_count
capture noisily {
    qa_fx_a1_sat, clear
    expand 10
    replace id = _n
    expand 2
    bysort id: gen byte time = _n
    replace y = . if time == 1
    quietly gcomp y a s x2, outcome(y) idvar(id) tvar(time) eofu fixedcovariates(s x2) intvars(a) interventions(a=1, a=0) commands(a: logit, y: logit) equations(a: i.s##i.x2, y: i.a##i.s##i.x2) sim(1200) samples(2) seed(9141) minsim
    tempname truthb
    matrix `truthb' = e(b)
    assert !missing(`truthb'[1,1], `truthb'[1,2])
    assert abs(`truthb'[1,1]-11/20) < 1e-8 & abs(`truthb'[1,2]-49/120) < 1e-8
    * expect: REFUSED
    qa_option_domain, command(gcomp y a s x2, outcome(y) idvar(id) tvar(time) eofu fixedcovariates(s x2) intvars(a) interventions(a=1, a=0) commands(a: logit, y: logit) equations(a: i.s##i.x2, y: i.a##i.s##i.x2) sim(1200) samples(2) seed(9141) minsim modelstyle(@v@)) ///
        inside("compact;native") outside("wide;bad") ///
        check(assert !missing(el(e(b),1,1),el(e(b),1,2)) & e(N_subjects)==1200)
    assert r(n_violations) == 0
    * Repeat outside cells with the complete caller fingerprint and named cause.
    quietly regress y s x2
    local fx_template "gcomp y a s x2, outcome(y) idvar(id) tvar(time) eofu fixedcovariates(s x2) intvars(a) interventions(a=1, a=0) commands(a: logit, y: logit) equations(a: i.s##i.x2, y: i.a##i.s##i.x2) sim(1200) samples(2) seed(9141) minsim modelstyle(@v@)"
    local fx_values "wide bad"
    foreach v of local fx_values {
        local fx_command : subinstr local fx_template "@v@" "`v'", all
        tempfile msg
        tempname lh found
        capture log close _all
        log using "`msg'", text replace name(`lh') nomsg
        qa_state_snapshot, tag(fxdomain)
        capture noisily `fx_command'
        local fx_rc = _rc
        assert `fx_rc' == 198
        qa_state_compare, tag(fxdomain)
        log close `lh'
        mata: st_numscalar("`found'", _qa_mm_logfind("`msg'", "modelstyle() must be compact or native"))
        assert `found' == 1
    }
}
if _rc == 0 {
    local ++pass_count
    display as result "PASS: U: boundary_values modelstyle documented domain"
}
else {
    local ++fail_count
    display as error "FAIL: U: boundary_values modelstyle documented domain (rc=`=_rc')"
}

**# U: boundary_values -- documented commands domain with strict refusals
local ++test_count
capture noisily {
    qa_fx_a1_sat, clear
    expand 10
    replace id = _n
    expand 2
    bysort id: gen byte time = _n
    replace y = . if time == 1
    quietly gcomp y a s x2, outcome(y) idvar(id) tvar(time) eofu fixedcovariates(s x2) intvars(a) interventions(a=1, a=0) commands(a: logit, y: logit) equations(a: i.s##i.x2, y: i.a##i.s##i.x2) sim(1200) samples(2) seed(9141) minsim
    tempname truthb
    matrix `truthb' = e(b)
    assert !missing(`truthb'[1,1], `truthb'[1,2])
    assert abs(`truthb'[1,1]-11/20) < 1e-8 & abs(`truthb'[1,2]-49/120) < 1e-8
    * expect: REFUSED
    qa_option_domain, command(gcomp y a s x2, outcome(y) idvar(id) tvar(time) eofu fixedcovariates(s x2) intvars(a) interventions(a=1, a=0) commands(a: logit, y: @v@) equations(a: i.s##i.x2, y: i.a##i.s##i.x2) sim(1200) samples(2) seed(9141) minsim) ///
        inside("logit;regress") outside("probit;bad") ///
        check(assert !missing(el(e(b),1,1),el(e(b),1,2)) & e(N_subjects)==1200)
    assert r(n_violations) == 0
    * Repeat outside cells with the complete caller fingerprint and named cause.
    quietly regress y s x2
    local fx_template "gcomp y a s x2, outcome(y) idvar(id) tvar(time) eofu fixedcovariates(s x2) intvars(a) interventions(a=1, a=0) commands(a: logit, y: @v@) equations(a: i.s##i.x2, y: i.a##i.s##i.x2) sim(1200) samples(2) seed(9141) minsim"
    local fx_values "probit bad"
    foreach v of local fx_values {
        local fx_command : subinstr local fx_template "@v@" "`v'", all
        tempfile msg
        tempname lh found
        capture log close _all
        log using "`msg'", text replace name(`lh') nomsg
        qa_state_snapshot, tag(fxdomain)
        capture noisily `fx_command'
        local fx_rc = _rc
        assert `fx_rc' == 198
        qa_state_compare, tag(fxdomain)
        log close `lh'
        mata: st_numscalar("`found'", _qa_mm_logfind("`msg'", "not a supported model command"))
        assert `found' == 1
    }
}
if _rc == 0 {
    local ++pass_count
    display as result "PASS: U: boundary_values commands documented domain"
}
else {
    local ++fail_count
    display as error "FAIL: U: boundary_values commands documented domain (rc=`=_rc')"
}

display "RESULT: test_fixture_domains tests=`test_count' pass=`pass_count' fail=`fail_count' skip=0"
capture log close _all
if `fail_count' > 0 exit 1
